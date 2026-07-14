#!/usr/bin/env python3
"""Validate Noum's callable source contract and captured cloud inventory."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


PRODUCTION_PROJECT = "noum-d0b6f"
PRODUCTION_REGION = "europe-west2"

RUNTIME_IDENTITIES = {
    "COACH_RUNTIME_SERVICE_ACCOUNT": "noum-coach-runtime",
    "TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT": "noum-transcription-runtime",
    "ACCOUNT_RUNTIME_SERVICE_ACCOUNT": "noum-account-runtime",
    "RECOMMENDATION_RUNTIME_SERVICE_ACCOUNT": "noum-recommendation-runtime",
    "SOCIAL_RUNTIME_SERVICE_ACCOUNT": "noum-social-runtime",
}

EXPECTED_CALLABLES = {
    "coachChatAvailability": "COACH_RUNTIME_SERVICE_ACCOUNT",
    "coachChat": "COACH_RUNTIME_SERVICE_ACCOUNT",
    "transcriptionToken": "TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT",
    "getPeerProfile": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "listLeagueMembers": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "recordPeerSession": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "createChallenge": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "submitChallengeResult": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "setChallengeReaction": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "syncRecommendationState": "RECOMMENDATION_RUNTIME_SERVICE_ACCOUNT",
    "deleteAccount": "ACCOUNT_RUNTIME_SERVICE_ACCOUNT",
}

BROAD_RUNTIME_ROLES = {"roles/owner", "roles/editor"}
VERTEX_RUNTIME_ROLE = "roles/aiplatform.user"
CALLABLE_PATTERN = re.compile(
    r"^export const (?P<name>[A-Za-z][A-Za-z0-9]*) = onCall\(",
    re.MULTILINE,
)


class ContractError(RuntimeError):
    """One or more fail-closed release-contract violations."""

    def __init__(self, failures: list[str]):
        super().__init__("\n".join(failures))
        self.failures = failures


def runtime_email(constant: str, project: str = PRODUCTION_PROJECT) -> str:
    """Return the exact service-account email for one source constant."""
    return f"{RUNTIME_IDENTITIES[constant]}@{project}.iam.gserviceaccount.com"


def _call_block(source: str, match: re.Match[str]) -> str:
    """Return one complete onCall expression using a small lexical scanner."""
    start = match.end() - 1
    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False
    index = start
    while index < len(source):
        character = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""

        if line_comment:
            if character == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment:
            if character == "*" and following == "/":
                block_comment = False
                index += 2
            else:
                index += 1
            continue
        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            index += 1
            continue
        if character == "/" and following == "/":
            line_comment = True
            index += 2
            continue
        if character == "/" and following == "*":
            block_comment = True
            index += 2
            continue
        if character in {"'", '"', "`"}:
            quote = character
            index += 1
            continue
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return source[match.start() : index + 1]
        index += 1
    raise ContractError([f"{match.group('name')} has an unterminated onCall expression."])


def validate_source_contract(source: str) -> list[str]:
    """Require exact callable, App Check, trusted-caller, and identity wiring."""
    failures: list[str] = []
    matches = list(CALLABLE_PATTERN.finditer(source))
    names = [match.group("name") for match in matches]
    actual = set(names)
    expected = set(EXPECTED_CALLABLES)
    duplicates = sorted(name for name in actual if names.count(name) > 1)
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    if duplicates:
        failures.append("Duplicate callable exports: " + ", ".join(duplicates))
    if missing:
        failures.append("Missing callable exports: " + ", ".join(missing))
    if unexpected:
        failures.append("Unexpected callable exports: " + ", ".join(unexpected))

    for constant in RUNTIME_IDENTITIES:
        expression = re.compile(
            rf"const\s+{re.escape(constant)}\s*=\s*\"([^\"]+)\"\s*;"
        )
        match = expression.search(source)
        expected_email = runtime_email(constant)
        if match is None or match.group(1) != expected_email:
            failures.append(
                f"{constant} must equal the production identity {expected_email}."
            )

    for match in matches:
        name = match.group("name")
        expected_constant = EXPECTED_CALLABLES.get(name)
        if expected_constant is None:
            continue
        block = _call_block(source, match)
        if not re.search(r"\benforceAppCheck\s*:\s*true\b", block):
            failures.append(f"{name} must enforce App Check in its onCall options.")
        service_account = re.search(
            r"\bserviceAccount\s*:\s*([A-Z][A-Z0-9_]*)\b", block
        )
        if service_account is None or service_account.group(1) != expected_constant:
            failures.append(
                f"{name} must use {expected_constant}, not "
                f"{service_account.group(1) if service_account else 'an absent identity'}."
            )
        if not re.search(
            r"\bassertTrustedCaller\(\s*request\.auth\s*,\s*request\.app\s*\)",
            block,
        ):
            failures.append(f"{name} must call the shared trusted-caller boundary.")

    if failures:
        raise ContractError(failures)
    return [
        f"Source exports exactly {len(EXPECTED_CALLABLES)} reviewed callables",
        "Every callable enforces App Check and the shared trusted-caller boundary",
        "Every callable uses its reviewed dedicated runtime identity",
    ]


def _require_list(value: Any, label: str) -> list[Any]:
    if not isinstance(value, list):
        raise ContractError([f"{label} must be a JSON array."])
    return value


def _function_coordinates(item: dict[str, Any]) -> tuple[str, str, str]:
    full_name = item.get("name")
    if not isinstance(full_name, str):
        return "", "", ""
    match = re.fullmatch(
        r"projects/(?P<project>[^/]+)/locations/(?P<region>[^/]+)/"
        r"functions/(?P<name>[^/]+)",
        full_name,
    )
    if match is None:
        return "", "", ""
    return match.group("name"), match.group("project"), match.group("region")


def validate_cloud_snapshot(
    *,
    functions: Any,
    project_policy: Any,
    secret_policy: Any,
    project: str,
    region: str,
    project_number: str,
) -> list[str]:
    """Validate captured deployed functions and relevant IAM boundaries."""
    failures: list[str] = []
    if project != PRODUCTION_PROJECT:
        failures.append(f"Snapshot project must be {PRODUCTION_PROJECT}.")
    if region != PRODUCTION_REGION:
        failures.append(f"Snapshot region must be {PRODUCTION_REGION}.")
    if not re.fullmatch(r"[0-9]+", project_number):
        failures.append("Snapshot project number must contain only digits.")

    function_items = _require_list(functions, "functions.json")
    deployed: dict[str, tuple[dict[str, Any], str, str]] = {}
    malformed_names = 0
    for raw_item in function_items:
        if not isinstance(raw_item, dict):
            malformed_names += 1
            continue
        name, deployed_project, deployed_region = _function_coordinates(raw_item)
        if not name or name in deployed:
            malformed_names += 1
            continue
        deployed[name] = (raw_item, deployed_project, deployed_region)
    if malformed_names:
        failures.append("Functions inventory contains malformed or duplicate names.")

    actual = set(deployed)
    expected = set(EXPECTED_CALLABLES)
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    if missing:
        failures.append("Missing deployed callables: " + ", ".join(missing))
    if unexpected:
        failures.append("Unexpected deployed callables: " + ", ".join(unexpected))

    for name, constant in EXPECTED_CALLABLES.items():
        entry = deployed.get(name)
        if entry is None:
            continue
        item, deployed_project, deployed_region = entry
        if deployed_project != project:
            failures.append(
                f"{name} belongs to {deployed_project or 'an unknown project'}, "
                f"not {project}."
            )
        if deployed_region != region:
            failures.append(
                f"{name} is deployed in {deployed_region or 'an unknown region'}, "
                f"not {region}."
            )
        if item.get("state") != "ACTIVE":
            failures.append(f"{name} is not ACTIVE.")
        service_config = item.get("serviceConfig")
        actual_identity = (
            service_config.get("serviceAccountEmail")
            if isinstance(service_config, dict)
            else None
        )
        expected_identity = runtime_email(constant, project)
        if actual_identity != expected_identity:
            failures.append(
                f"{name} uses {actual_identity or 'no runtime identity'}, "
                f"not {expected_identity}."
            )

    if not isinstance(project_policy, dict):
        raise ContractError(["project-iam.json must be a JSON object."])
    bindings = _require_list(project_policy.get("bindings", []), "IAM bindings")
    runtime_members = {
        f"serviceAccount:{runtime_email(constant, project)}": constant
        for constant in RUNTIME_IDENTITIES
    }
    coach_member = (
        "serviceAccount:"
        + runtime_email("COACH_RUNTIME_SERVICE_ACCOUNT", project)
    )
    for binding in bindings:
        if not isinstance(binding, dict):
            continue
        role = binding.get("role")
        members = binding.get("members")
        if not isinstance(role, str) or not isinstance(members, list):
            continue
        for member in members:
            if not isinstance(member, str) or member not in runtime_members:
                continue
            if role in BROAD_RUNTIME_ROLES:
                failures.append(
                    f"{runtime_email(runtime_members[member], project)} has broad role {role}."
                )
            if role == VERTEX_RUNTIME_ROLE and member != coach_member:
                failures.append(
                    f"{runtime_email(runtime_members[member], project)} has unauthorized "
                    f"Vertex role {role}."
                )

    if project_number:
        default_compute = (
            f"serviceAccount:{project_number}-compute@developer.gserviceaccount.com"
        )
        default_roles = set()
        for binding in bindings:
            if not isinstance(binding, dict):
                continue
            members = binding.get("members")
            if (
                isinstance(members, list)
                and default_compute in members
                and binding.get("role") in {"roles/editor", VERTEX_RUNTIME_ROLE}
            ):
                default_roles.add(binding.get("role"))
        if default_roles:
            failures.append(
                "The default compute identity retains Editor or Vertex AI access."
            )
        appspot = f"serviceAccount:{project}@appspot.gserviceaccount.com"
        if any(
            isinstance(binding, dict)
            and binding.get("role") == "roles/editor"
            and isinstance(binding.get("members"), list)
            and appspot in binding["members"]
            for binding in bindings
        ):
            failures.append("The default App Engine identity retains Editor access.")

    if not isinstance(secret_policy, dict):
        raise ContractError(["deepgram-secret-iam.json must be a JSON object."])
    secret_bindings = _require_list(
        secret_policy.get("bindings", []), "Secret IAM bindings"
    )
    secret_accessors: set[str] = set()
    for binding in secret_bindings:
        if not isinstance(binding, dict) or (
            binding.get("role") != "roles/secretmanager.secretAccessor"
        ):
            continue
        members = binding.get("members")
        if not isinstance(members, list):
            failures.append("Secret accessor members must be a JSON array.")
            continue
        secret_accessors.update(
            member for member in members if isinstance(member, str)
        )
    expected_secret_accessor = {
        "serviceAccount:"
        + runtime_email("TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT", project)
    }
    if secret_accessors != expected_secret_accessor:
        failures.append(
            "The Deepgram secret must be readable only by the transcription runtime."
        )

    if failures:
        raise ContractError(failures)
    return [
        f"All {len(EXPECTED_CALLABLES)} reviewed callables are ACTIVE in {region}",
        "Every callable uses its reviewed dedicated runtime identity",
        "Dedicated runtimes have no Owner/Editor grants or unauthorized Vertex access",
        "Only the transcription runtime can read the Deepgram secret",
        "Default compute identities retain no reviewed broad role",
    ]


def _load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ContractError([f"Unable to read valid JSON from {path.name}: {error}"]) from error


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-contract", type=Path)
    parser.add_argument("--snapshot-dir", type=Path)
    parser.add_argument("--project", default=PRODUCTION_PROJECT)
    parser.add_argument("--region", default=PRODUCTION_REGION)
    parser.add_argument("--project-number", default="")
    parser.add_argument("--print-callable-names", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.print_callable_names:
        print(" ".join(EXPECTED_CALLABLES))
        return 0
    if args.source_contract is None and args.snapshot_dir is None:
        raise ContractError(["Pass --source-contract or --snapshot-dir."])

    passes: list[str] = []
    if args.source_contract is not None:
        try:
            source = args.source_contract.read_text(encoding="utf-8")
        except OSError as error:
            raise ContractError(
                [f"Unable to read callable source: {error}"]
            ) from error
        passes.extend(validate_source_contract(source))
    if args.snapshot_dir is not None:
        passes.extend(validate_cloud_snapshot(
            functions=_load_json(args.snapshot_dir / "functions.json"),
            project_policy=_load_json(args.snapshot_dir / "project-iam.json"),
            secret_policy=_load_json(args.snapshot_dir / "deepgram-secret-iam.json"),
            project=args.project,
            region=args.region,
            project_number=args.project_number,
        ))
    for label in passes:
        print(f"PASS: {label}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ContractError as error:
        for failure in error.failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
