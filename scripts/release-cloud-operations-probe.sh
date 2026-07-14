#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
runtime_validator="$repo_root/scripts/release_cloud_operations_validator.py"
readonly production_project="noum-d0b6f"
readonly production_region="europe-west2"
readonly production_operations_email="noumsupport@gmail.com"

project="${NOUM_FIREBASE_PROJECT:-$production_project}"
region="${NOUM_FUNCTIONS_REGION:-$production_region}"
operations_email="${NOUM_OPERATIONS_EMAIL:-$production_operations_email}"

# This command produces release evidence, so an environment override must not
# let a correctly configured lookalike project stand in for production.
if [[ "$project" != "$production_project" ]]; then
  echo "Cloud operations probe is pinned to Firebase project $production_project." >&2
  exit 2
fi
if [[ "$region" != "$production_region" ]]; then
  echo "Cloud operations probe is pinned to Functions region $production_region." >&2
  exit 2
fi
if [[ "$operations_email" != "$production_operations_email" ]]; then
  echo "Cloud operations probe is pinned to the production operations channel." >&2
  exit 2
fi

for command in gcloud python3 curl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command" >&2
    exit 2
  fi
done

python3 "$runtime_validator" \
  --source-contract "$repo_root/functions/src/index.ts"

echo "Production Firebase contract: project=$project region=$region operations=$operations_email"
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

python3 - "$work" "$project" "$operations_email" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
project = sys.argv[2]
operations_email = sys.argv[3]
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

for label in passes:
    print(f"PASS: {label}")
for label in failures:
    print(f"FAIL: {label}")

print(f"Cloud operations readiness: {len(passes)}/{len(passes) + len(failures)}")
if failures:
    raise SystemExit(1)
PY

python3 "$runtime_validator" \
  --snapshot-dir "$work" \
  --project "$project" \
  --region "$region" \
  --project-number "$project_number"

"$(cd "$(dirname "$0")" && pwd)/release-live-privacy-probe.sh"

callable_names="$(python3 "$runtime_validator" --print-callable-names)"
for function_name in $callable_names; do
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

echo "Live cloud operations probe passed for Firebase project $project."
