#!/usr/bin/env bash
# Fail-closed, unauthenticated containment check for Noum's legacy AWS backend.
#
# This probe intentionally sends no credential, never downloads or prints a
# response body, and never calls a provider API. It proves only that each
# documented legacy route rejects an unverified caller or is disabled. Provider
# credential revocation and usage/billing review require separate, redacted
# operator evidence.
#
# Usage:
#   BACKEND_BASE_URL=https://... ./scripts/verify_deepgram_endpoint.sh
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

configuration_error() {
  echo "$SCRIPT_NAME: $1" >&2
  exit 2
}

command -v curl >/dev/null 2>&1 || configuration_error "curl is required"

BASE="${BACKEND_BASE_URL:-}"
if [[ -z "$BASE" ]]; then
  PLIST="$(cd "$(dirname "$0")/.." && pwd)/Noum/BackendConfig.plist"
  if [[ -f "$PLIST" ]]; then
    BASE="$(/usr/libexec/PlistBuddy -c 'Print :BACKEND_BASE_URL' "$PLIST" 2>/dev/null || true)"
  fi
fi

[[ -n "$BASE" ]] || configuration_error \
  "set BACKEND_BASE_URL or populate Noum/BackendConfig.plist"

# This gate is production-facing. Refuse plaintext, URL credentials, query
# strings, fragments, whitespace, and control characters before curl sees the
# value. In particular, never echo a rejected value: it may itself contain a
# secret.
[[ "$BASE" == https://* ]] || configuration_error \
  "BACKEND_BASE_URL must use HTTPS"
if [[ "$BASE" == *"@"* || "$BASE" == *"?"* || "$BASE" == *"#"* ||
      "$BASE" =~ [[:space:]] ]]; then
  configuration_error \
    "BACKEND_BASE_URL must not contain credentials, query, fragment, or whitespace"
fi
BASE="${BASE%/}"

# Refuse an operator's old authenticated-probe environment rather than silently
# implying those credentials were used. This containment check must remain
# unauthenticated and status-only.
if [[ -n "${BACKEND_API_KEY:-}" ]]; then
  configuration_error \
    "BACKEND_API_KEY must be unset; this gate never sends credentials"
fi

verification_status=0

is_protective_status() {
  case "$1" in
    401|403|404|410) return 0 ;;
    *) return 1 ;;
  esac
}

probe_route() {
  local method="$1"
  local path="$2"
  local code
  local -a curl_args=(
    --disable
    --silent
    --show-error
    --output /dev/null
    --write-out '%{http_code}'
    --connect-timeout 10
    --max-time 20
    --proto '=https'
    --tlsv1.2
    --request "$method"
    --header 'X-Noum-Account-ID: probe-unauthenticated'
    --header 'X-Noum-Auth-Provider: apple'
  )

  if [[ "$method" == "POST" ]]; then
    curl_args+=(--header 'Content-Type: application/json' --data-binary '{}')
  fi

  if ! code="$(curl "${curl_args[@]}" "$BASE$path")"; then
    echo "$method $path -> FAIL (transport or TLS error)" >&2
    verification_status=1
    return
  fi

  # A malformed write-out value could include a response body if curl or a test
  # double were misconfigured. Do not reflect it into logs.
  if [[ ! "$code" =~ ^[0-9]{3}$ ]]; then
    echo "$method $path -> FAIL (no trustworthy HTTP status)" >&2
    verification_status=1
    return
  fi

  echo "$method $path -> HTTP $code"
  if ! is_protective_status "$code"; then
    echo "  FAIL: expected 401/403 (protected) or 404/410 (disabled)." >&2
    verification_status=1
  fi
}

echo "Legacy transcription credential containment probe"
echo "No credentials are sent and no response bodies are retained."

# Both credential-vending routes and every sibling route documented in the
# incident review must reject the forged account header. A 2xx, redirect, 4xx
# validation response, rate limit, 5xx, or transport failure is not closure.
probe_route GET  /v1/transcribe/deepgram-key
probe_route GET  /v1/transcribe/credentials
probe_route POST /v1/im/context
probe_route POST /v1/tts/im
probe_route POST /v1/im/reply

echo
if (( verification_status != 0 )); then
  echo "FAIL CLOSED: legacy-route containment is not proven." >&2
  echo "Do not mark the credential incident closed or release externally." >&2
  exit 1
fi

echo "PASS: every documented legacy route rejected the unverified caller or is disabled."
echo "Separate evidence is still required for credential revocation and provider usage/billing review."
