#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
verifier="$repo_root/scripts/privacy_body_verifier.py"
expected_body="$repo_root/public/privacy.html"
url="${1:-https://noum-d0b6f.web.app/privacy}"
if [[ "$url" != https://* ]]; then
  echo "Privacy probe requires an HTTPS URL." >&2
  exit 2
fi

response="$(mktemp "${TMPDIR:-/tmp}/noum-live-privacy.XXXXXX")"
metadata="$(mktemp "${TMPDIR:-/tmp}/noum-live-privacy-metadata.XXXXXX")"
trap 'rm -f "$response" "$metadata"' EXIT INT TERM

max_body_bytes="$(python3 "$verifier" --print-max-body-bytes)"

curl --silent --show-error \
  --proto '=https' \
  --tlsv1.2 \
  --compressed \
  --connect-timeout 10 \
  --max-time 30 \
  --max-filesize "$max_body_bytes" \
  --output "$response" \
  --write-out '%{http_code}\n%{url_effective}\n%{content_type}\n%{num_redirects}\n' \
  "$url" > "$metadata"

http_status=""
final_url=""
content_type=""
redirect_count=""
{
  IFS= read -r http_status
  IFS= read -r final_url
  IFS= read -r content_type
  IFS= read -r redirect_count
} < "$metadata"

python3 "$verifier" \
  --expected-body "$expected_body" \
  --observed-body "$response" \
  --requested-url "$url" \
  --final-url "$final_url" \
  --status "$http_status" \
  --content-type "$content_type" \
  --redirect-count "$redirect_count"
