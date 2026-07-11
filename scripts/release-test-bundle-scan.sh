#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
scanner="$repo_root/scripts/release-scan-app-bundle.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/noum-bundle-scan.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT INT TERM

make_clean_bundle() {
  local path="$1/Noum.app"
  mkdir -p "$path/Resources"
  printf '%s\n' 'Firebase public client config: AIza000000000000000000000000000000000' \
    > "$path/GoogleService-Info.plist"
  printf '%s\n' 'ordinary application content' > "$path/Noum"
  printf '%s\n' "$path"
}

expect_failure() {
  local label="$1"
  local bundle="$2"
  local output="$fixture_root/$label.output"
  if "$scanner" "$bundle" >"$output" 2>&1; then
    echo "Bundle scanner unexpectedly accepted fixture: $label" >&2
    exit 1
  fi
  if ! grep -q "$label" "$output"; then
    echo "Bundle scanner did not report expected category: $label" >&2
    exit 1
  fi
}

clean_bundle="$(make_clean_bundle "$fixture_root/clean")"
"$scanner" "$clean_bundle" >/dev/null

forbidden_bundle="$(make_clean_bundle "$fixture_root/forbidden")"
printf '%s\n' 'placeholder' > "$forbidden_bundle/Resources/AIConfig.plist"
expect_failure "forbidden config" "$forbidden_bundle"

secret_bundle="$(make_clean_bundle "$fixture_root/secret")"
secret_fixture="sk-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
printf '%s\n' "$secret_fixture" > "$secret_bundle/Resources/credential.txt"
expect_failure "OpenAI or Anthropic key" "$secret_bundle"
if grep -R -q "$secret_fixture" "$fixture_root"/*.output; then
  echo "Bundle scanner exposed matched credential material." >&2
  exit 1
fi

provider_bundle="$(make_clean_bundle "$fixture_root/provider-secret")"
provider_fixture="deepgram-management-fixture-000000"
printf '%s\n' "DEEPGRAM_API_KEY=$provider_fixture" \
  > "$provider_bundle/Resources/provider.env"
expect_failure "provider secret assignment" "$provider_bundle"
if grep -R -q "$provider_fixture" "$fixture_root"/*.output; then
  echo "Bundle scanner exposed matched provider credential material." >&2
  exit 1
fi

# Compiled string tables often place unrelated strings on either side of a NUL.
# A provider variable name without an assignment must not fail the build.
adjacent_bundle="$(make_clean_bundle "$fixture_root/compiled-adjacency")"
printf 'DEEPGRAM_API_KEY\0ordinaryapplicationcontentwithlength\0' \
  > "$adjacent_bundle/Noum"
"$scanner" "$adjacent_bundle" >/dev/null

private_key_bundle="$(make_clean_bundle "$fixture_root/private-key")"
printf '%s\n' '-----BEGIN PRIVATE KEY-----' \
  > "$private_key_bundle/Resources/key.pem"
expect_failure "private key" "$private_key_bundle"

echo "Bundle scanner fixtures passed."
