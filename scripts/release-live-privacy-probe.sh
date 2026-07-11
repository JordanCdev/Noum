#!/usr/bin/env bash
set -euo pipefail

url="${1:-https://noum-d0b6f.web.app/privacy}"
if [[ "$url" != https://* ]]; then
  echo "Privacy probe requires an HTTPS URL." >&2
  exit 2
fi

response="$(mktemp "${TMPDIR:-/tmp}/noum-live-privacy.XXXXXX")"
headers="$(mktemp "${TMPDIR:-/tmp}/noum-live-privacy-headers.XXXXXX")"
trap 'rm -f "$response" "$headers"' EXIT INT TERM

curl --fail --silent --show-error --location \
  --proto '=https' \
  --tlsv1.2 \
  --connect-timeout 10 \
  --max-time 30 \
  --dump-header "$headers" \
  --output "$response" \
  "$url"

grep -qi '^content-type:.*text/html' "$headers"
grep -q '<h1>Privacy Policy</h1>' "$response"
grep -q 'Your Cloud Processing Choice' "$response"
grep -q 'noumsupport@gmail.com' "$response"

echo "Live privacy policy probe passed."
