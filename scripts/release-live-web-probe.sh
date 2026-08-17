#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
verifier="$repo_root/scripts/privacy_body_verifier.py"
target="${1:-active}"

firebase_origin="https://noum-d0b6f.web.app"
custom_origin="https://noum.app"

case "$target" in
  active)
    active_target="$(
      python3 "$verifier" \
        --print-active-hosting-target "$repo_root/Noum/NoumWebURLs.swift"
    )" || exit 2
    case "$active_target" in
      firebase)
        origins=("$firebase_origin")
        ;;
      custom)
        origins=("$custom_origin")
        ;;
      *)
        echo "Active Hosting target is invalid." >&2
        exit 2
        ;;
    esac
    ;;
  firebase)
    origins=("$firebase_origin")
    ;;
  custom)
    origins=("$custom_origin")
    ;;
  both)
    origins=("$firebase_origin" "$custom_origin")
    ;;
  *)
    echo "Live web probe target must be active, firebase, custom, or both." >&2
    exit 2
    ;;
esac

pages=(
  "homepage|/|index.html"
  "privacy|/privacy|privacy.html"
  "support|/support|support.html"
  "coaching-method|/how-noum-coaches|how-noum-coaches.html"
)

probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/noum-live-web.XXXXXX")"
response="$probe_dir/response"
metadata="$probe_dir/metadata"
cleanup() {
  rm -f "$response" "$metadata"
  rmdir "$probe_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

max_body_bytes="$(python3 "$verifier" --print-max-body-bytes)"
transport_limit="$((max_body_bytes + 1))"

for origin in "${origins[@]}"; do
  for page in "${pages[@]}"; do
    IFS='|' read -r page_id route source_file <<< "$page"
    requested_url="${origin}${route}"
    : > "$response"
    : > "$metadata"

    if ! curl --silent --show-error \
      --proto '=https' \
      --tlsv1.2 \
      --compressed \
      --connect-timeout 10 \
      --max-time 30 \
      --max-filesize "$transport_limit" \
      --output "$response" \
      --write-out '%{http_code}\n%{url_effective}\n%{content_type}\n%{num_redirects}\n' \
      "$requested_url" > "$metadata"; then
      echo "Live $page_id transport or size-bound check failed for $origin." >&2
      exit 1
    fi

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
      --page-id "$page_id" \
      --expected-body "$repo_root/public/$source_file" \
      --observed-body "$response" \
      --requested-url "$requested_url" \
      --final-url "$final_url" \
      --status "$http_status" \
      --content-type "$content_type" \
      --redirect-count "$redirect_count"
  done
done

echo "Live web exact-body verification passed for target: $target."
