#!/usr/bin/env bash
set -euo pipefail

project="${NOUM_FIREBASE_PROJECT:-noum-d0b6f}"
region="${NOUM_FUNCTIONS_REGION:-europe-west2}"
operations_email="${NOUM_OPERATIONS_EMAIL:-noumsupport@gmail.com}"

for command in gcloud python3 curl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command" >&2
    exit 2
  fi
done

if [[ -z "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)" ]]; then
  echo "An active gcloud identity is required." >&2
  exit 2
fi
project_number="$(gcloud projects describe "$project" --format='value(projectNumber)')"

work="$(mktemp -d "${TMPDIR:-/tmp}/noum-cloud-operations.XXXXXX")"
trap 'rm -rf "$work"' EXIT INT TERM

gcloud firestore databases describe \
  --project="$project" \
  --database='(default)' \
  --format=json > "$work/database.json"
gcloud firestore backups schedules list \
  --project="$project" \
  --database='(default)' \
  --format=json > "$work/backups.json"
gcloud logging metrics list \
  --project="$project" \
  --format=json > "$work/metrics.json"
gcloud monitoring policies list \
  --project="$project" \
  --format=json > "$work/policies.json"
gcloud alpha monitoring channels list \
  --project="$project" \
  --format=json > "$work/channels.json"
gcloud functions list \
  --v2 \
  --project="$project" \
  --regions="$region" \
  --format=json > "$work/functions.json"
gcloud secrets get-iam-policy DEEPGRAM_MANAGEMENT_KEY \
  --project="$project" \
  --format=json > "$work/deepgram-secret-iam.json"
gcloud projects get-iam-policy "$project" \
  --format=json > "$work/project-iam.json"

python3 - "$work" "$project" "$operations_email" "$project_number" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
project = sys.argv[2]
operations_email = sys.argv[3]
project_number = sys.argv[4]
failures: list[str] = []
passes: list[str] = []


def load(name: str):
    return json.loads((root / name).read_text(encoding="utf-8"))


def check(condition: bool, label: str) -> None:
    (passes if condition else failures).append(label)


database = load("database.json")
check(
    database.get("pointInTimeRecoveryEnablement")
    == "POINT_IN_TIME_RECOVERY_ENABLED",
    "Firestore point-in-time recovery is enabled",
)
check(
    database.get("deleteProtectionState") == "DELETE_PROTECTION_ENABLED",
    "Firestore deletion protection is enabled",
)
check(
    database.get("versionRetentionPeriod") == "604800s",
    "Firestore keeps seven days of recoverable versions",
)

backups = load("backups.json")
check(
    any(
        "dailyRecurrence" in item and item.get("retention") == "604800s"
        for item in backups
    ),
    "A daily Firestore backup with seven-day retention exists",
)

required_metrics = {
    "noum_account_deletion_failures",
    "noum_app_check_rejections",
    "noum_function_http_5xx",
    "noum_transcription_token_failures",
    "noum_transcription_tokens_issued",
}
metric_names = {item.get("name") for item in load("metrics.json")}
check(
    required_metrics.issubset(metric_names),
    "Release log-based metrics are installed",
)

required_policies = {
    "Noum: account deletion failure",
    "Noum: App Check rejection spike",
    "Noum: function 5xx spike",
    "Noum: transcription token failures",
    "Noum: transcription token volume spike",
}
policies = load("policies.json")
enabled_policies = {
    item.get("displayName")
    for item in policies
    if item.get("enabled") and item.get("notificationChannels")
}
check(
    required_policies.issubset(enabled_policies),
    "Release alert policies are enabled and routed",
)

channels = load("channels.json")
check(
    any(
        item.get("enabled")
        and item.get("type") == "email"
        and (item.get("labels") or {}).get("email_address")
        == operations_email
        for item in channels
    ),
    "The monitored operations email channel is enabled",
)

expected_functions = {
    "coachChat": f"noum-coach-runtime@{project}.iam.gserviceaccount.com",
    "coachChatAvailability":
        f"noum-coach-runtime@{project}.iam.gserviceaccount.com",
    "transcriptionToken":
        f"noum-transcription-runtime@{project}.iam.gserviceaccount.com",
    "deleteAccount":
        f"noum-account-runtime@{project}.iam.gserviceaccount.com",
}
functions = {}
for item in load("functions.json"):
    name = (item.get("name") or "").rsplit("/", 1)[-1]
    functions[name] = item
for name, identity in expected_functions.items():
    item = functions.get(name) or {}
    check(
        item.get("state") == "ACTIVE"
        and (item.get("serviceConfig") or {}).get("serviceAccountEmail")
        == identity,
        f"{name} is active under its dedicated runtime identity",
    )

secret_policy = load("deepgram-secret-iam.json")
secret_accessors = {
    member
    for binding in secret_policy.get("bindings", [])
    if binding.get("role") == "roles/secretmanager.secretAccessor"
    for member in binding.get("members", [])
}
check(
    secret_accessors
    == {
        "serviceAccount:"
        f"noum-transcription-runtime@{project}.iam.gserviceaccount.com"
    },
    "Only the transcription runtime can read the Deepgram secret",
)

project_policy = load("project-iam.json")
default_compute = (
    f"serviceAccount:{project_number}-compute@developer.gserviceaccount.com"
)
dangerous_default_roles = {
    binding.get("role")
    for binding in project_policy.get("bindings", [])
    if default_compute in binding.get("members", [])
    and binding.get("role") in {"roles/editor", "roles/aiplatform.user"}
}
check(
    not dangerous_default_roles,
    "The default compute identity has no Editor or Vertex AI role",
)

for label in passes:
    print(f"PASS: {label}")
for label in failures:
    print(f"FAIL: {label}")

print(f"Cloud operations readiness: {len(passes)}/{len(passes) + len(failures)}")
if failures:
    raise SystemExit(1)
PY

"$(cd "$(dirname "$0")" && pwd)/release-live-privacy-probe.sh"

for function_name in transcriptionToken deleteAccount; do
  uri="$(gcloud functions describe "$function_name" \
    --v2 \
    --project="$project" \
    --region="$region" \
    --format='value(serviceConfig.uri)')"
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --request POST \
    --header 'content-type: application/json' \
    --data '{"data":{"schemaVersion":1}}' \
    --connect-timeout 10 \
    --max-time 30 \
    "$uri")"
  if [[ "$status" != "401" ]]; then
    echo "$function_name accepted an unauthenticated request (HTTP $status)." >&2
    exit 1
  fi
  echo "PASS: $function_name rejects unauthenticated requests"
done

echo "Live cloud operations probe passed."
