#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
probe="$repo_root/scripts/release-cloud-operations-probe.sh"
stub_directory="$(mktemp -d "${TMPDIR:-/tmp}/noum-cloud-probe-test.XXXXXX")"
trap 'rm -rf "$stub_directory"' EXIT INT TERM

false_binary="/usr/bin/false"
if [[ ! -x "$false_binary" ]]; then
  false_binary="/bin/false"
fi
for command in gcloud python3 curl; do
  ln -s "$false_binary" "$stub_directory/$command"
done

run_probe() {
  env -i \
    HOME="${HOME:-/tmp}" \
    PATH="$stub_directory:/usr/bin:/bin" \
    "$@" \
    "$probe" 2>&1
}

assert_rejected_override() {
  local expected="$1"
  shift
  local output
  local status
  if output="$(run_probe "$@")"; then
    echo "Expected the production-contract override to fail." >&2
    exit 1
  else
    status=$?
  fi
  if [[ "$status" -ne 2 || "$output" != *"$expected"* ]]; then
    echo "Override failed without the expected fail-closed diagnostic." >&2
    exit 1
  fi
}

assert_rejected_override \
  "pinned to Firebase project noum-d0b6f" \
  NOUM_FIREBASE_PROJECT=lookalike-project
assert_rejected_override \
  "pinned to Functions region europe-west2" \
  NOUM_FUNCTIONS_REGION=us-central1
assert_rejected_override \
  "pinned to the production operations channel" \
  NOUM_OPERATIONS_EMAIL=alternate@example.invalid

# The exact production defaults pass contract validation, then stop at the
# inert gcloud stub. This proves the test itself cannot contact cloud services.
output=""
status=0
if output="$(run_probe)"; then
  echo "Expected the inert gcloud stub to stop the probe." >&2
  exit 1
else
  status=$?
fi
if [[ "$status" -ne 2 ||
      "$output" != *"Production Firebase contract: project=noum-d0b6f region=europe-west2"* ||
      "$output" != *"An active gcloud identity is required."* ]]; then
  echo "Production defaults did not reach the credential-presence guard." >&2
  exit 1
fi

echo "Cloud operations production-contract tests passed."
