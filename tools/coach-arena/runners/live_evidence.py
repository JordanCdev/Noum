#!/usr/bin/env python3
"""Fail-closed producer for the canonical live-provider readiness artifact.

The Swift live harness remains the only producer of provider replies. This
wrapper gives operators one safe publication path: run the harness in an
isolated directory (or consume an explicitly attested capture), validate the
unchanged readiness contract and live provenance, then atomically promote the
JSON. A failed or partial run never touches the last published artifact.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import coach_arena
import readiness_gate


ARENA_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ARENA_ROOT.parents[1]
DEFAULT_DUMP_DIR = Path(
    os.environ.get("NOUM_COACH_EVAL_DUMP_DIR", "/private/tmp/noum-coach-eval")
)
ARTIFACT_NAME = "coach-live-eval-v1.json"
ATTESTATION_SCHEMA = "coach-live-capture-attestation-v1"
PRODUCER = "NoumTests/CoachLiveEvaluationTests.liveGeminiRepliesClearFixtureRubric"
LIVE_CREDENTIAL_KEYS = (
    "GOOGLE_AGENT_PLATFORM_API_KEY",
    "GOOGLE_CLOUD_AGENT_PLATFORM_API_KEY",
    "VERTEX_AI_API_KEY",
    "GEMINI_API_KEY",
    "ANTHROPIC_API_KEY",
    "OPENAI_API_KEY",
    "DEEPSEEK_API_KEY",
)
class LiveEvidenceError(RuntimeError):
    """Expected operator or evidence failure, safe to print without a traceback."""


def trimmed(value):
    return value.strip() if isinstance(value, str) and value.strip() else None


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def read_json_bytes(path):
    try:
        raw = Path(path).read_bytes()
    except OSError as error:
        raise LiveEvidenceError(f"cannot read live capture {path}: {error}") from error
    try:
        payload = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise LiveEvidenceError(f"live capture is not valid UTF-8 JSON: {path}: {error}") from error
    if not isinstance(payload, dict):
        raise LiveEvidenceError("live capture root must be a JSON object")
    return raw, payload


def read_source_expectations(dump_dir, require_current_checkout=True):
    dump_dir = Path(dump_dir)
    names = readiness_gate.SOURCE_SIDECARS
    values = {}
    for name in names:
        path = dump_dir / name
        try:
            value = path.read_text(encoding="utf-8").strip()
        except OSError as error:
            raise LiveEvidenceError(f"missing source sidecar {path}: {error}") from error
        if not value:
            raise LiveEvidenceError(f"source sidecar is empty: {path}")
        values[name] = value

    if require_current_checkout:
        preflight = coach_arena.app_path_regeneration_preflight(dump_dir)
        if not preflight.get("passes"):
            blockers = ", ".join(preflight.get("blockers") or ["unknown preflight failure"])
            raise LiveEvidenceError(
                "app-path source preflight failed; refresh the app-path evidence first: " + blockers
            )
        current_commit = coach_arena.current_git_commit(short=True)
        current_fingerprint = coach_arena.coach_source_fingerprint()
        if values["source-git-commit.txt"] != current_commit:
            raise LiveEvidenceError(
                "source-git-commit.txt is not the exact current checkout "
                f"({values['source-git-commit.txt']} != {current_commit})"
            )
        if values["source-coach-fingerprint.txt"] != current_fingerprint:
            raise LiveEvidenceError(
                "source-coach-fingerprint.txt is not the exact current coach source"
            )
    return values


def attestation_failures(attestation, capture_digest, payload, source_expectations):
    if not isinstance(attestation, dict):
        return ["captureAttestationMalformed"]
    expected = {
        "schemaVersion": ATTESTATION_SCHEMA,
        "executionMode": "liveProviderProductionPath",
        "producer": PRODUCER,
        "candidateSource": "providerNetworkResponse",
        "fixturePreset": "readiness",
        "longFormPreset": "required",
        "usesReplayResponses": False,
        "usesFixtureResponses": False,
        "usesTemplateResponses": False,
        "captureSHA256": capture_digest,
        "sourceGitCommit": source_expectations.get("source-git-commit.txt"),
        "sourceCoachFingerprint": source_expectations.get("source-coach-fingerprint.txt"),
    }
    failures = [
        f"captureAttestationMismatch={key}"
        for key, value in expected.items()
        if attestation.get(key) != value
    ]
    if trimmed(attestation.get("runID")) is None:
        failures.append("captureAttestationRunIDMissing")
    captured_at = trimmed(attestation.get("capturedAt"))
    if captured_at is None:
        failures.append("captureAttestationTimestampMissing")
    else:
        try:
            parsed = dt.datetime.fromisoformat(captured_at.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                failures.append("captureAttestationTimestampMissingTimezone")
        except ValueError:
            failures.append("captureAttestationTimestampInvalid")
    if attestation.get("sourceGitCommit") != payload.get("sourceGitCommit"):
        failures.append("captureAttestationPayloadCommitMismatch")
    if attestation.get("sourceCoachFingerprint") != payload.get("sourceCoachFingerprint"):
        failures.append("captureAttestationPayloadFingerprintMismatch")
    return failures


def artifact_contract_failures(payload, source_expectations):
    requirement = readiness_gate.EVIDENCE_REQUIREMENTS["noLiveProviderTranscriptSweep"]
    failures = []
    if payload.get("schemaVersion") != requirement["expectedSchemaVersion"]:
        failures.append("schemaVersionMismatch")
    # The Swift capture is validated before atomic_publish adds the canonical
    # publication provenance. Readiness requires that field on the promoted
    # artifact, but the pre-publication candidate must not be expected to forge it.
    capture_required_keys = [
        key for key in requirement["requiredTopLevelKeys"]
        if key != "liveEvidenceProvenance"
    ]
    missing = [key for key in capture_required_keys if key not in payload]
    if missing:
        failures.append("missingTopLevelKeys=" + ",".join(missing))
    failures.extend(
        readiness_gate.live_provider_sweep_contract_failures(
            payload,
            source_expectations=source_expectations,
            require_published_provenance=False,
        )
    )
    return list(dict.fromkeys(failures))


def validate_capture(capture_path, attestation, source_expectations):
    raw, payload = read_json_bytes(capture_path)
    digest = sha256_bytes(raw)
    failures = artifact_contract_failures(payload, source_expectations)
    failures.extend(
        attestation_failures(
            attestation,
            capture_digest=digest,
            payload=payload,
            source_expectations=source_expectations,
        )
    )
    failures = list(dict.fromkeys(failures))
    if failures:
        raise LiveEvidenceError("live capture rejected: " + "; ".join(failures))
    return payload, digest


def atomic_publish(payload, attestation, capture_digest, destination):
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    published = copy.deepcopy(payload)
    published["liveEvidenceProvenance"] = {
        "schemaVersion": ATTESTATION_SCHEMA,
        "producer": attestation["producer"],
        "executionMode": attestation["executionMode"],
        "candidateSource": attestation["candidateSource"],
        "runID": attestation["runID"],
        "capturedAt": attestation["capturedAt"],
        "captureSHA256": capture_digest,
        "usesReplayResponses": False,
        "usesFixtureResponses": False,
        "usesTemplateResponses": False,
    }
    encoded = (json.dumps(published, indent=2, sort_keys=True) + "\n").encode("utf-8")
    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.",
        suffix=".tmp",
        dir=destination.parent,
    )
    try:
        with os.fdopen(file_descriptor, "wb") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, destination)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise
    return destination


def configured_live_credentials(environment):
    configured = []
    for key in LIVE_CREDENTIAL_KEYS:
        value = trimmed(environment.get(key))
        if value and value.lower() not in {
            "placeholder", "replace-me", "test", "none", "todo", "tbd"
        }:
            configured.append(key)
    return configured


def make_live_attestation(capture_path, source_expectations):
    raw, _ = read_json_bytes(capture_path)
    captured_at = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
    return {
        "schemaVersion": ATTESTATION_SCHEMA,
        "executionMode": "liveProviderProductionPath",
        "producer": PRODUCER,
        "candidateSource": "providerNetworkResponse",
        "fixturePreset": "readiness",
        "longFormPreset": "required",
        "usesReplayResponses": False,
        "usesFixtureResponses": False,
        "usesTemplateResponses": False,
        "captureSHA256": sha256_bytes(raw),
        "sourceGitCommit": source_expectations["source-git-commit.txt"],
        "sourceCoachFingerprint": source_expectations["source-coach-fingerprint.txt"],
        "runID": "live-" + captured_at.replace(":", "-").replace(".", "-"),
        "capturedAt": captured_at,
    }


def run_swift_live_capture(args, source_expectations, staging_dir):
    configured = configured_live_credentials(os.environ)
    if not configured:
        raise LiveEvidenceError(
            "no explicitly exported live-provider credential is configured; "
            "the canonical artifact was not touched"
        )
    if not args.allow_live_network:
        raise LiveEvidenceError(
            "live network execution can spend provider quota; rerun with "
            "--allow-live-network after confirming the exported credentials"
        )

    staging_dir = Path(staging_dir)
    markdown_path = staging_dir / "coach-live-eval-v1.md"
    capture_path = staging_dir / ARTIFACT_NAME
    for sidecar_name, value in source_expectations.items():
        (staging_dir / sidecar_name).write_text(value + "\n", encoding="utf-8")

    environment = os.environ.copy()
    test_environment = {
        "NOUM_LIVE_AI_EVAL": "1",
        "NOUM_LIVE_AI_FIXTURES": "readiness",
        "NOUM_LIVE_AI_LONG_FORM": "required",
        "NOUM_LIVE_AI_PROVIDER_CHAIN": "production",
        "NOUM_COACH_EVAL_DUMP_DIR": str(staging_dir),
        "NOUM_LIVE_AI_EVAL_OUTPUT": str(markdown_path),
        "NOUM_SOURCE_GIT_COMMIT": source_expectations["source-git-commit.txt"],
        "NOUM_SOURCE_COACH_FINGERPRINT": source_expectations["source-coach-fingerprint.txt"],
        "SIMCTL_CHILD_NOUM_COACH_EVAL_DUMP_DIR": str(staging_dir),
        "SIMCTL_CHILD_NOUM_SOURCE_GIT_COMMIT": source_expectations["source-git-commit.txt"],
        "SIMCTL_CHILD_NOUM_SOURCE_COACH_FINGERPRINT": source_expectations["source-coach-fingerprint.txt"],
    }
    environment.update(test_environment)
    # xcodebuild normally forwards its environment to XCTest. Mirror the
    # runtime selectors and explicitly exported secrets through simctl too so
    # the behavior remains deterministic across Xcode runner versions.
    for key, value in test_environment.items():
        if not key.startswith("SIMCTL_CHILD_"):
            environment[f"SIMCTL_CHILD_{key}"] = value
    for key in LIVE_CREDENTIAL_KEYS:
        if trimmed(environment.get(key)):
            environment[f"SIMCTL_CHILD_{key}"] = environment[key]
    command = [
        args.xcodebuild,
        "test",
        "-project", str(REPO_ROOT / "Noum.xcodeproj"),
        "-scheme", "Noum",
        "-destination", args.destination,
        "-derivedDataPath", str(args.derived_data),
        "-only-testing:NoumTests/CoachLiveEvaluationTests",
        "OTHER_SWIFT_FLAGS=$(inherited) -D NOUM_LIVE_AI_EVAL_READINESS",
    ]
    result = subprocess.run(command, cwd=REPO_ROOT, env=environment, check=False)
    if result.returncode != 0:
        raise LiveEvidenceError(
            f"Swift live-provider sweep failed with exit {result.returncode}; "
            "the staged partial capture was discarded"
        )
    if not capture_path.is_file():
        raise LiveEvidenceError(
            "Swift live-provider sweep exited successfully but emitted no JSON capture"
        )
    return capture_path, make_live_attestation(capture_path, source_expectations)


def load_attestation(path):
    try:
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise LiveEvidenceError(f"cannot read capture attestation {path}: {error}") from error
    if not isinstance(payload, dict):
        raise LiveEvidenceError("capture attestation root must be a JSON object")
    return payload


def build_parser():
    parser = argparse.ArgumentParser(
        description=(
            "Run or consume a real production-path provider sweep and atomically "
            "publish coach-live-eval-v1.json only when every readiness row passes."
        )
    )
    parser.add_argument("--capture", help="explicit real live capture JSON to validate")
    parser.add_argument(
        "--attestation",
        help="required coach-live-capture-attestation-v1 JSON for --capture",
    )
    parser.add_argument("--dump-dir", default=str(DEFAULT_DUMP_DIR))
    parser.add_argument("--output", help="published artifact path; defaults inside --dump-dir")
    parser.add_argument(
        "--allow-live-network",
        action="store_true",
        help="explicitly authorize provider requests and quota use",
    )
    parser.add_argument(
        "--destination",
        default=os.environ.get(
            "NOUM_COACH_XCODE_DESTINATION",
            "platform=iOS Simulator,name=iPhone 17",
        ),
    )
    parser.add_argument(
        "--derived-data",
        type=Path,
        default=Path("/private/tmp/NoumCoachLiveEvidenceDerivedData"),
    )
    parser.add_argument("--xcodebuild", default="xcodebuild")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if args.attestation and not args.capture:
        raise LiveEvidenceError("--attestation is valid only with --capture")
    if args.capture and not args.attestation:
        raise LiveEvidenceError(
            "--capture requires an explicit --attestation; unproven captures cannot be live evidence"
        )
    if args.capture and args.allow_live_network:
        raise LiveEvidenceError("--allow-live-network is not used when consuming a capture")

    dump_dir = Path(args.dump_dir).resolve()
    destination = Path(args.output).resolve() if args.output else dump_dir / ARTIFACT_NAME

    # Credential authorization is checked before source preflight so a normal
    # no-key invocation remains fast and cannot start Xcode or touch artifacts.
    if not args.capture:
        configured = configured_live_credentials(os.environ)
        if not configured:
            raise LiveEvidenceError(
                "no explicitly exported live-provider credential is configured; "
                "the canonical artifact was not touched"
            )
        if not args.allow_live_network:
            raise LiveEvidenceError(
                "live network execution can spend provider quota; rerun with "
                "--allow-live-network after confirming the exported credentials"
            )

    source_expectations = read_source_expectations(dump_dir)
    if args.capture:
        capture_path = Path(args.capture).resolve()
        attestation = load_attestation(args.attestation)
        payload, digest = validate_capture(
            capture_path,
            attestation,
            source_expectations,
        )
    else:
        dump_dir.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            prefix=".coach-live-evidence-",
            dir=dump_dir,
        ) as staging:
            capture_path, attestation = run_swift_live_capture(
                args,
                source_expectations,
                staging,
            )
            payload, digest = validate_capture(
                capture_path,
                attestation,
                source_expectations,
            )
            published = atomic_publish(payload, attestation, digest, destination)
            print(f"Published validated live-provider evidence: {published}")
            return 0

    published = atomic_publish(payload, attestation, digest, destination)
    print(f"Published validated live-provider evidence: {published}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except LiveEvidenceError as error:
        print(f"live-evidence: {error}", file=sys.stderr)
        sys.exit(1)
