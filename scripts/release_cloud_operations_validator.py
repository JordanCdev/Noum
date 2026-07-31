#!/usr/bin/env python3
"""Validate Noum's callable source contract and captured cloud inventory."""

from __future__ import annotations

import argparse
import hashlib
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
    "GROWTH_RUNTIME_SERVICE_ACCOUNT": "noum-growth-runtime",
    "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT":
        "noum-appstore-notifications-runtime",
    "SOCIAL_RUNTIME_SERVICE_ACCOUNT": "noum-social-runtime",
}

EXPECTED_CALLABLES = {
    "coachChatAvailability": "COACH_RUNTIME_SERVICE_ACCOUNT",
    "coachChat": "COACH_RUNTIME_SERVICE_ACCOUNT",
    "coachChatV2": "COACH_RUNTIME_SERVICE_ACCOUNT",
    "transcriptionToken": "TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT",
    "beginCompetitiveObservation": "TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT",
    "completeCompetitiveObservation": "TRANSCRIPTION_RUNTIME_SERVICE_ACCOUNT",
    "getPeerProfile": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "listLeagueMembers": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "createFriendInvite": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "acceptFriendInvite": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "listFriendLinks": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "removeFriendLink": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "recordPeerSession": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "createChallenge": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "submitChallengeResult": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "setChallengeReaction": "SOCIAL_RUNTIME_SERVICE_ACCOUNT",
    "syncRecommendationState": "RECOMMENDATION_RUNTIME_SERVICE_ACCOUNT",
    "recordGrowthAggregate": "GROWTH_RUNTIME_SERVICE_ACCOUNT",
    "deleteAccount": "ACCOUNT_RUNTIME_SERVICE_ACCOUNT",
}
EXPECTED_SCHEDULED_FUNCTIONS = {
    "reconcileAccountDeletionTombstones": "ACCOUNT_RUNTIME_SERVICE_ACCOUNT",
}
EXPECTED_HTTP_FUNCTIONS = {
    "appStoreServerNotificationsV2":
        "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT",
    "appStoreServerNotificationsV2Sandbox":
        "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT",
}
EXPECTED_FUNCTIONS = {
    **EXPECTED_CALLABLES,
    **EXPECTED_SCHEDULED_FUNCTIONS,
    **EXPECTED_HTTP_FUNCTIONS,
}

BROAD_RUNTIME_ROLES = {"roles/owner", "roles/editor"}
VERTEX_RUNTIME_ROLE = "roles/aiplatform.user"
APP_STORE_RUNTIME_ALLOWED_PROJECT_ROLES = {"roles/datastore.user"}
SECRET_DATA_ROLES = {
    "roles/secretmanager.admin",
    "roles/secretmanager.secretAccessor",
}
APPLE_SERVER_LIBRARY_SPEC = "^3.1.0"
APPLE_SERVER_LIBRARY_VERSION = "3.1.0"
APPLE_SERVER_LIBRARY_RESOLVED = (
    "https://registry.npmjs.org/@apple/app-store-server-library/-/"
    "app-store-server-library-3.1.0.tgz"
)
APPLE_SERVER_LIBRARY_INTEGRITY = (
    "sha512-d26SICRz8BwCV2qPR0BSXBMxmw0NEvJLwsdREcBmCrus8NmyHw2XgOOP0fiFjcct"
    "Pn/JXtmSDuGVnaHe+dqO+A=="
)
APP_STORE_NOTIFICATION_PHASES = {
    "pre-enable": ("false", "false"),
    "sandbox-enabled": ("false", "true"),
    "production-enabled": ("true", "true"),
}
CALLABLE_PATTERN = re.compile(
    r"^export const (?P<name>[A-Za-z][A-Za-z0-9]*) = onCall\(",
    re.MULTILINE,
)
SCHEDULE_PATTERN = re.compile(
    r"^export const (?P<name>[A-Za-z][A-Za-z0-9]*) = onSchedule\(",
    re.MULTILINE,
)
HTTP_PATTERN = re.compile(
    r"^export const (?P<name>[A-Za-z][A-Za-z0-9]*) = onRequest\(",
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


def _trigger_block(source: str, match: re.Match[str]) -> str:
    """Return one complete function expression using a small lexical scanner."""
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
    raise ContractError([f"{match.group('name')} has an unterminated trigger expression."])


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
        block = _trigger_block(source, match)
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

    schedule_matches = list(SCHEDULE_PATTERN.finditer(source))
    schedule_names = [match.group("name") for match in schedule_matches]
    actual_schedules = set(schedule_names)
    expected_schedules = set(EXPECTED_SCHEDULED_FUNCTIONS)
    duplicate_schedules = sorted(
        name for name in actual_schedules if schedule_names.count(name) > 1
    )
    missing_schedules = sorted(expected_schedules - actual_schedules)
    unexpected_schedules = sorted(actual_schedules - expected_schedules)
    if duplicate_schedules:
        failures.append(
            "Duplicate scheduled exports: " + ", ".join(duplicate_schedules)
        )
    if missing_schedules:
        failures.append(
            "Missing scheduled exports: " + ", ".join(missing_schedules)
        )
    if unexpected_schedules:
        failures.append(
            "Unexpected scheduled exports: " + ", ".join(unexpected_schedules)
        )
    for match in schedule_matches:
        name = match.group("name")
        expected_constant = EXPECTED_SCHEDULED_FUNCTIONS.get(name)
        if expected_constant is None:
            continue
        block = _trigger_block(source, match)
        service_account = re.search(
            r"\bserviceAccount\s*:\s*([A-Z][A-Z0-9_]*)\b", block
        )
        if service_account is None or service_account.group(1) != expected_constant:
            failures.append(
                f"{name} must use {expected_constant}, not "
                f"{service_account.group(1) if service_account else 'an absent identity'}."
            )
        if not re.search(r'\bschedule\s*:\s*"every 15 minutes"', block):
            failures.append(f"{name} must retain the reviewed 15-minute schedule.")

    http_matches = list(HTTP_PATTERN.finditer(source))
    http_names = [match.group("name") for match in http_matches]
    actual_http = set(http_names)
    expected_http = set(EXPECTED_HTTP_FUNCTIONS)
    duplicate_http = sorted(
        name for name in actual_http if http_names.count(name) > 1
    )
    missing_http = sorted(expected_http - actual_http)
    unexpected_http = sorted(actual_http - expected_http)
    if duplicate_http:
        failures.append(
            "Duplicate public HTTP exports: " + ", ".join(duplicate_http)
        )
    if missing_http:
        failures.append(
            "Missing public HTTP exports: " + ", ".join(missing_http)
        )
    if unexpected_http:
        failures.append(
            "Unexpected public HTTP exports: " + ", ".join(unexpected_http)
        )
    for match in http_matches:
        name = match.group("name")
        expected_constant = EXPECTED_HTTP_FUNCTIONS.get(name)
        if expected_constant is None:
            continue
        block = _trigger_block(source, match)
        service_account = re.search(
            r"\bserviceAccount\s*:\s*([A-Z][A-Z0-9_]*)\b", block
        )
        if service_account is None or service_account.group(1) != expected_constant:
            failures.append(
                f"{name} must use {expected_constant}, not "
                f"{service_account.group(1) if service_account else 'an absent identity'}."
            )
        if not re.search(r'\binvoker\s*:\s*"public"', block):
            failures.append(f"{name} must retain Apple's public HTTPS admission.")
        if not re.search(
            r"\bsecrets\s*:\s*\[\s*appStoreRootCertificates\s*\]", block
        ):
            failures.append(
                f"{name} must mount only the reviewed Apple root secret."
            )
        if "handleAppStoreServerNotification(" not in block:
            failures.append(
                f"{name} must call the shared verified notification handler."
            )

    if failures:
        raise ContractError(failures)
    return [
        f"Source exports exactly {len(EXPECTED_CALLABLES)} reviewed callables",
        f"Source exports exactly {len(EXPECTED_SCHEDULED_FUNCTIONS)} "
        "server-only schedule",
        f"Source exports exactly {len(EXPECTED_HTTP_FUNCTIONS)} "
        "verified Apple HTTP receivers",
        "Every callable enforces App Check and the shared trusted-caller boundary",
        "Every public Apple receiver mounts the reviewed root secret and handler",
        "Every function uses its reviewed dedicated runtime identity",
    ]


def validate_app_store_verifier_contract(
    source: str,
    package_lock_text: str,
) -> list[str]:
    """Bind release evidence to the reviewed Apple verifier and npm artifact."""
    failures: list[str] = []
    required_patterns = (
        (
            r'from\s+"@apple/app-store-server-library"',
            "The verifier must import Apple's official server library.",
        ),
        (
            r"new\s+SignedDataVerifier\(\s*"
            r"configuration\.rootCertificates\s*,\s*true\s*,\s*"
            r"configuration\.environment\s*,\s*"
            r"configuration\.bundleID\s*,\s*"
            r"configuration\.appAppleID\s*\)",
            "SignedDataVerifier must retain online checks and exact app identity inputs.",
        ),
        (
            r'APP_STORE_NOTIFICATION_BUNDLE_ID\s*=\s*"uk\.co\.otherpath\.noum"',
            "The verifier must retain Noum's exact production bundle ID.",
        ),
        (
            r'monthly\s*:\s*"com\.noum\.pro\.monthly"',
            "The verifier must retain Noum's exact monthly StoreKit product.",
        ),
        (
            r'annual\s*:\s*"com\.noum\.pro\.annual"',
            "The verifier must retain Noum's exact annual StoreKit product.",
        ),
        (
            r"APP_STORE_NOTIFICATION_PRODUCT_ID_ALLOWLIST\s*=\s*"
            r"new\s+Set<string>\(\s*Object\.values\("
            r"APP_STORE_NOTIFICATION_PRODUCT_IDS\)\s*\)",
            "The verifier must derive its product allowlist from the reviewed IDs.",
        ),
        (
            r"APP_STORE_NOTIFICATION_MARKER_RETENTION_MILLISECONDS\s*=\s*"
            r"400\s*\*\s*DAY_MILLISECONDS",
            "Replay markers must retain the reviewed 400-day lifetime.",
        ),
        (
            r"payload\.data\.bundleId\s*!==\s*config\.bundleID",
            "The verified envelope must enforce the exact bundle ID.",
        ),
        (
            r"payload\.data\.environment\s*!==\s*config\.environment",
            "The verified envelope must enforce the exact environment.",
        ),
        (
            r"payload\.data\.appAppleId\s*!==\s*config\.appAppleID",
            "The production envelope must enforce the numeric App Apple ID.",
        ),
        (
            r"transaction\.bundleId\s*!==\s*config\.bundleID",
            "Nested transactions must enforce the exact bundle ID.",
        ),
        (
            r"transaction\.environment\s*!==\s*config\.environment",
            "Nested transactions must enforce the exact environment.",
        ),
        (
            r"renewal\.environment\s*!==\s*config\.environment",
            "Nested renewals must enforce the exact environment.",
        ),
        (
            r"return\s+error\.retryable\s*\?\s*503\s*:\s*204",
            "Permanent invalid payloads must receive a 2xx no-write acknowledgement.",
        ),
    )
    for pattern, failure in required_patterns:
        if re.search(pattern, source, re.MULTILINE) is None:
            failures.append(failure)

    ordered_snippets = (
        "verifier.verifyAndDecodeNotification(signedPayload)",
        "validateVerifiedEnvelope(payload, config, nowMilliseconds)",
        "verifier.verifyAndDecodeTransaction(",
        "validateTransactionIdentity(transaction, config)",
        "verifier.verifyAndDecodeRenewalInfo(",
        "validateRenewalIdentity(renewal, config)",
        "TRANSACTION_REQUIRED_TYPES.has(payload.notificationType",
        "eventCounts: lifecycleEventCounts(",
    )
    positions = [source.find(snippet) for snippet in ordered_snippets]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        failures.append(
            "Outer verification, app validation, every present nested JWS, required "
            "proof checks, and lifecycle projection must retain the reviewed order."
        )
    if source.count("VerificationStatus.RETRYABLE_VERIFICATION_FAILURE") < 2:
        failures.append(
            "Outer and nested online verification failures must both preserve retryability."
        )
    if not re.search(
        r"if\s*\(payload\.data\.signedTransactionInfo\)\s*\{[\s\S]*?"
        r"verifyAndDecodeTransaction\(\s*payload\.data\.signedTransactionInfo",
        source,
    ):
        failures.append("Every present nested transaction JWS must be verified.")
    if not re.search(
        r"if\s*\(payload\.data\.signedRenewalInfo\)\s*\{[\s\S]*?"
        r"verifyAndDecodeRenewalInfo\(\s*payload\.data\.signedRenewalInfo",
        source,
    ):
        failures.append("Every present nested renewal JWS must be verified.")

    try:
        package_lock = json.loads(package_lock_text)
    except json.JSONDecodeError as error:
        raise ContractError([f"Functions package lock is not valid JSON: {error}"]) from error
    if not isinstance(package_lock, dict):
        failures.append("Functions package lock must be a JSON object.")
        packages: dict[str, Any] = {}
    else:
        packages_value = package_lock.get("packages")
        packages = packages_value if isinstance(packages_value, dict) else {}
        if package_lock.get("lockfileVersion") != 3:
            failures.append("Functions package lock must retain lockfileVersion 3.")
    root = packages.get("")
    root_dependencies = root.get("dependencies") if isinstance(root, dict) else None
    if not isinstance(root_dependencies, dict) or root_dependencies.get(
        "@apple/app-store-server-library"
    ) != APPLE_SERVER_LIBRARY_SPEC:
        failures.append(
            "The root package lock must retain the reviewed Apple library specification."
        )
    locked = packages.get("node_modules/@apple/app-store-server-library")
    if not isinstance(locked, dict):
        failures.append("The reviewed Apple server library is absent from package-lock.json.")
    else:
        expected_fields = {
            "version": APPLE_SERVER_LIBRARY_VERSION,
            "resolved": APPLE_SERVER_LIBRARY_RESOLVED,
            "integrity": APPLE_SERVER_LIBRARY_INTEGRITY,
        }
        for field, expected in expected_fields.items():
            if locked.get(field) != expected:
                failures.append(
                    f"The Apple server library {field} must equal the reviewed value."
                )

    if failures:
        raise ContractError(failures)
    source_digest = hashlib.sha256(source.encode("utf-8")).hexdigest()
    lock_digest = hashlib.sha256(package_lock_text.encode("utf-8")).hexdigest()
    return [
        f"Apple verifier source SHA-256: {source_digest}",
        f"Functions package-lock SHA-256: {lock_digest}",
        f"Apple server library is locked to {APPLE_SERVER_LIBRARY_VERSION}",
        "Apple verifier retains online checks and exact bundle/app/product/environment binding",
        "Outer and every present nested Apple JWS verify before bounded projection",
        "Permanent invalid notifications acknowledge 204 while retryable failures use 503",
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
    app_store_secret_policy: Any,
    app_store_effective_policy: Any,
    ttl_policies: Any,
    project: str,
    region: str,
    project_number: str,
    app_store_app_apple_id: str,
    app_store_notification_phase: str,
) -> list[str]:
    """Validate captured deployed functions and relevant IAM boundaries."""
    failures: list[str] = []
    if project != PRODUCTION_PROJECT:
        failures.append(f"Snapshot project must be {PRODUCTION_PROJECT}.")
    if region != PRODUCTION_REGION:
        failures.append(f"Snapshot region must be {PRODUCTION_REGION}.")
    if not re.fullmatch(r"[0-9]+", project_number):
        failures.append("Snapshot project number must contain only digits.")
    if not re.fullmatch(r"[1-9][0-9]*", app_store_app_apple_id):
        failures.append("App Apple ID must be an explicit positive integer.")
    phase_values = APP_STORE_NOTIFICATION_PHASES.get(
        app_store_notification_phase
    )
    if phase_values is None:
        failures.append("App Store notification phase is not reviewed.")
        phase_values = ("invalid", "invalid")

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
    expected = set(EXPECTED_FUNCTIONS)
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    if missing:
        failures.append("Missing deployed functions: " + ", ".join(missing))
    if unexpected:
        failures.append("Unexpected deployed functions: " + ", ".join(unexpected))

    for name, constant in EXPECTED_FUNCTIONS.items():
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

    production_enabled, sandbox_enabled = phase_values
    endpoint_parameters = {
        "appStoreServerNotificationsV2": (
            "APP_STORE_PRODUCTION_NOTIFICATIONS_ENABLED",
            production_enabled,
        ),
        "appStoreServerNotificationsV2Sandbox": (
            "APP_STORE_SANDBOX_NOTIFICATIONS_ENABLED",
            sandbox_enabled,
        ),
    }
    for name, (enable_key, expected_enabled) in endpoint_parameters.items():
        entry = deployed.get(name)
        if entry is None:
            continue
        service_config = entry[0].get("serviceConfig")
        if not isinstance(service_config, dict):
            continue
        environment = service_config.get("environmentVariables")
        if not isinstance(environment, dict):
            failures.append(f"{name} has no readable parameter snapshot.")
        else:
            if environment.get("APP_STORE_APP_APPLE_ID") != app_store_app_apple_id:
                failures.append(
                    f"{name} does not retain the exact App Apple ID readback."
                )
            if environment.get(enable_key) != expected_enabled:
                failures.append(
                    f"{name} is not {app_store_notification_phase} for {enable_key}."
                )
        secret_environment = service_config.get("secretEnvironmentVariables")
        if not isinstance(secret_environment, list) or len(secret_environment) != 1:
            failures.append(
                f"{name} must mount exactly one reviewed Apple root secret."
            )
        else:
            secret = secret_environment[0]
            if not isinstance(secret, dict) or (
                secret.get("key") != "APP_STORE_ROOT_CERTIFICATES_BASE64"
                or secret.get("secret") != "APP_STORE_ROOT_CERTIFICATES_BASE64"
            ):
                failures.append(
                    f"{name} does not mount the exact Apple root secret readback."
                )

    ttl_items = _require_list(ttl_policies, "firestore-ttls.json")
    expected_ttl_name = (
        f"projects/{project}/databases/(default)/collectionGroups/"
        "_appStoreNotificationMarkers/fields/expiresAt"
    )
    active_marker_ttls = [
        item
        for item in ttl_items
        if isinstance(item, dict)
        and item.get("name") == expected_ttl_name
        and isinstance(item.get("ttlConfig"), dict)
        and item["ttlConfig"].get("state") == "ACTIVE"
    ]
    if len(active_marker_ttls) != 1:
        failures.append(
            "The App Store replay marker expiresAt TTL must exist exactly once and be ACTIVE."
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
    app_store_member = (
        "serviceAccount:"
        + runtime_email(
            "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT", project
        )
    )
    app_store_project_roles: set[str] = set()
    for binding in bindings:
        if not isinstance(binding, dict):
            continue
        role = binding.get("role")
        members = binding.get("members")
        if not isinstance(role, str) or not isinstance(members, list):
            continue
        if app_store_member in members:
            app_store_project_roles.add(role)
        if role in SECRET_DATA_ROLES and members:
            failures.append(
                f"Project-level secret data role {role} must not bypass "
                "resource-level secret isolation."
            )
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
    if app_store_project_roles != APP_STORE_RUNTIME_ALLOWED_PROJECT_ROLES:
        failures.append(
            "The App Store notifications runtime project roles must equal "
            "roles/datastore.user exactly."
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

    if not isinstance(app_store_secret_policy, dict):
        raise ContractError([
            "appstore-root-secret-iam.json must be a JSON object."
        ])
    app_store_secret_bindings = _require_list(
        app_store_secret_policy.get("bindings", []),
        "App Store root secret IAM bindings",
    )
    app_store_secret_accessors: set[str] = set()
    for binding in app_store_secret_bindings:
        if not isinstance(binding, dict):
            failures.append("App Store root secret binding must be an object.")
            continue
        role = binding.get("role")
        members = binding.get("members")
        if not isinstance(members, list):
            failures.append(
                "App Store root secret IAM members must be a JSON array."
            )
            continue
        if role != "roles/secretmanager.secretAccessor":
            if members:
                failures.append(
                    "The Apple root secret may contain only the reviewed "
                    "secretAccessor binding."
                )
            continue
        app_store_secret_accessors.update(
            member for member in members if isinstance(member, str)
        )
    expected_app_store_secret_accessor = {
        "serviceAccount:" + runtime_email(
            "APP_STORE_NOTIFICATIONS_RUNTIME_SERVICE_ACCOUNT", project
        )
    }
    if app_store_secret_accessors != expected_app_store_secret_accessor:
        failures.append(
            "The Apple root secret must be readable only by the App Store "
            "notifications runtime."
        )

    expected_secret_name = (
        "//secretmanager.googleapis.com/projects/"
        f"{project_number}/secrets/APP_STORE_ROOT_CERTIFICATES_BASE64"
    )
    if not isinstance(app_store_effective_policy, dict):
        raise ContractError([
            "appstore-root-secret-effective-iam.json must be a JSON object."
        ])
    policy_results = _require_list(
        app_store_effective_policy.get("policyResults", []),
        "App Store root effective IAM policy results",
    )
    if len(policy_results) != 1 or not isinstance(policy_results[0], dict):
        failures.append(
            "The Apple root secret must have exactly one effective IAM result."
        )
        effective_result: dict[str, Any] = {}
    else:
        effective_result = policy_results[0]
    if effective_result.get("fullResourceName") != expected_secret_name:
        failures.append(
            "The effective IAM snapshot does not target the exact Apple root secret."
        )
    effective_policies = effective_result.get("policies", [])
    if not isinstance(effective_policies, list):
        failures.append("Apple root effective IAM policies must be a JSON array.")
        effective_policies = []
    effective_runtime_roles: set[str] = set()
    local_secret_policy_count = 0
    for policy_info in effective_policies:
        if not isinstance(policy_info, dict):
            failures.append("Apple root effective IAM policy entry is malformed.")
            continue
        attached_resource = policy_info.get("attachedResource")
        policy = policy_info.get("policy")
        if not isinstance(attached_resource, str) or not isinstance(policy, dict):
            failures.append("Apple root effective IAM policy entry is incomplete.")
            continue
        if attached_resource == expected_secret_name:
            local_secret_policy_count += 1
        effective_bindings = policy.get("bindings", [])
        if not isinstance(effective_bindings, list):
            failures.append("Apple root effective IAM bindings must be a JSON array.")
            continue
        for binding in effective_bindings:
            if not isinstance(binding, dict):
                failures.append("Apple root effective IAM binding is malformed.")
                continue
            role = binding.get("role")
            members = binding.get("members")
            if not isinstance(role, str) or not isinstance(members, list):
                failures.append("Apple root effective IAM binding is incomplete.")
                continue
            if app_store_member in members:
                effective_runtime_roles.add(role)
            if (
                attached_resource != expected_secret_name
                and role in SECRET_DATA_ROLES
                and members
            ):
                failures.append(
                    f"Inherited secret data role {role} bypasses Apple root "
                    "secret isolation."
                )
    if local_secret_policy_count != 1:
        failures.append(
            "The effective IAM snapshot must include the exact secret-local policy once."
        )
    expected_effective_runtime_roles = {
        "roles/datastore.user",
        "roles/secretmanager.secretAccessor",
    }
    if effective_runtime_roles != expected_effective_runtime_roles:
        failures.append(
            "The App Store notifications runtime effective roles must equal "
            "datastore.user plus secretAccessor exactly."
        )

    if failures:
        raise ContractError(failures)
    return [
        f"All {len(EXPECTED_FUNCTIONS)} reviewed functions are ACTIVE in {region}",
        "Every function uses its reviewed dedicated runtime identity",
        "Dedicated runtimes have no Owner/Editor grants or unauthorized Vertex access",
        "Only the transcription runtime can read the Deepgram secret",
        "App Store runtime project/effective roles match the exact allowlist",
        "Apple root secret has no project, inherited, or resource-level role bypass",
        "App Store endpoint App ID, secret, and enable-phase readbacks are exact",
        "App Store replay marker expiresAt TTL is ACTIVE",
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
    parser.add_argument("--app-store-contract", type=Path)
    parser.add_argument("--functions-lockfile", type=Path)
    parser.add_argument("--snapshot-dir", type=Path)
    parser.add_argument("--project", default=PRODUCTION_PROJECT)
    parser.add_argument("--region", default=PRODUCTION_REGION)
    parser.add_argument("--project-number", default="")
    parser.add_argument("--app-store-app-apple-id", default="")
    parser.add_argument(
        "--app-store-notification-phase",
        choices=tuple(APP_STORE_NOTIFICATION_PHASES),
    )
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
        if args.app_store_contract is None or args.functions_lockfile is None:
            raise ContractError([
                "--source-contract requires --app-store-contract and "
                "--functions-lockfile."
            ])
        try:
            source = args.source_contract.read_text(encoding="utf-8")
            app_store_source = args.app_store_contract.read_text(encoding="utf-8")
            functions_lockfile = args.functions_lockfile.read_text(encoding="utf-8")
        except OSError as error:
            raise ContractError(
                [f"Unable to read release source contract: {error}"]
            ) from error
        passes.extend(validate_source_contract(source))
        passes.extend(validate_app_store_verifier_contract(
            app_store_source,
            functions_lockfile,
        ))
    if args.snapshot_dir is not None:
        if not args.app_store_app_apple_id or (
            args.app_store_notification_phase is None
        ):
            raise ContractError([
                "--snapshot-dir requires --app-store-app-apple-id and "
                "--app-store-notification-phase."
            ])
        passes.extend(validate_cloud_snapshot(
            functions=_load_json(args.snapshot_dir / "functions.json"),
            project_policy=_load_json(args.snapshot_dir / "project-iam.json"),
            secret_policy=_load_json(args.snapshot_dir / "deepgram-secret-iam.json"),
            app_store_secret_policy=_load_json(
                args.snapshot_dir / "appstore-root-secret-iam.json"
            ),
            app_store_effective_policy=_load_json(
                args.snapshot_dir / "appstore-root-secret-effective-iam.json"
            ),
            ttl_policies=_load_json(args.snapshot_dir / "firestore-ttls.json"),
            project=args.project,
            region=args.region,
            project_number=args.project_number,
            app_store_app_apple_id=args.app_store_app_apple_id,
            app_store_notification_phase=args.app_store_notification_phase,
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
