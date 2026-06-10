#!/usr/bin/env bash
# Verify the Deepgram key endpoint is no longer leaking, and that any key it
# vends is properly scoped + short-lived. Read-only. Never prints secret key
# material. Cleans up temp files. Run AFTER rotating + deploying the backend fix
# (and run it BEFORE, too — pre-fix it will show the leak so you can confirm it's real).
#
# Usage:
#   BACKEND_BASE_URL=https://... ./scripts/verify_deepgram_endpoint.sh
# Optional authenticated probe (once the backend requires it):
#   BACKEND_API_KEY=... NOUM_ACCOUNT_ID=... NOUM_AUTH_PROVIDER=apple ./scripts/verify_deepgram_endpoint.sh
#
# The robust signal is step 1 (unauthenticated probe must be non-200). Step 2's
# scope inspection depends on Deepgram's auth/token endpoint behaviour — treat it
# as best-effort and confirm against current Deepgram docs.
set -euo pipefail

# Always shred temp response files, even on early exit / Ctrl-C — they hold key material.
trap 'rm -f /tmp/dg_unauth.json /tmp/dg_auth.json 2>/dev/null || true' EXIT INT TERM

BASE="${BACKEND_BASE_URL:-}"
if [[ -z "$BASE" ]]; then
  PLIST="$(cd "$(dirname "$0")/.." && pwd)/Noum/BackendConfig.plist"
  if [[ -f "$PLIST" ]]; then
    BASE="$(/usr/libexec/PlistBuddy -c 'Print :BACKEND_BASE_URL' "$PLIST" 2>/dev/null || true)"
  fi
fi
[[ -z "$BASE" ]] && { echo "Set BACKEND_BASE_URL (or populate Noum/BackendConfig.plist)"; exit 2; }
EP="${BASE%/}/v1/transcribe/deepgram-key"
echo "Endpoint: $EP"

extract_key() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("apiKey",""))' "$1" 2>/dev/null || true; }

# Flag two things a correct response must NOT do: leak unexpected secret fields, or vend an
# already-expired key. Never prints key material.
validate_response() {
  python3 - "$1" <<'PY' 2>/dev/null || true
import json,sys,datetime
try:
    d=json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit
expected={"apiKey","expiresAt","expiration"}
leaked=[k for k in d if k not in expected]
if leaked:
    print("   PROBLEM: response leaks unexpected fields:", leaked)
exp=d.get("expiresAt") or d.get("expiration")
if exp:
    try:
        t=datetime.datetime.fromisoformat(exp.replace("Z","+00:00"))
        now=datetime.datetime.now(datetime.timezone.utc)
        if t <= now:
            print("   PROBLEM: key is already expired:", exp)
        else:
            print("   expiry OK:", exp)
    except Exception:
        print("   (could not parse expiresAt:", exp, ")")
else:
    print("   PROBLEM: no expiresAt in response (client requires it)")
PY
}

check_scope() {
  local key="$1"
  [[ -z "$key" ]] && { echo "   (no apiKey field in response)"; return; }
  local resp; resp=$(curl -s https://api.deepgram.com/v1/auth/token -H "Authorization: Token $key" || true)
  python3 - "$resp" <<'PY'
import json,sys
try:
    d=json.loads(sys.argv[1])
except Exception:
    print("   (could not parse auth/token response)"); raise SystemExit
scopes=d.get("scopes") or d.get("scope") or []
print("   scopes:", scopes)
over=[s for s in scopes if any(t in s for t in ("account","keys","owner","admin")) or s=="member"]
if any(s=="usage:write" for s in scopes) and not over:
    print("   OK: scoped to usage:write only")
else:
    print("   PROBLEM: over-privileged scope(s):", over or scopes)
PY
}

echo
echo "== 1. Unauthenticated probe (must NOT be 200 after the fix) =="
code=$(curl -s -o /tmp/dg_unauth.json -w '%{http_code}' -H 'X-Noum-Account-ID: probe-unauth' "$EP" || true)
echo "HTTP $code"
if [[ "$code" == "200" ]]; then
  echo "STILL LEAKING — endpoint returned 200 to an unauthenticated caller."
  echo "   Inspecting the leaked key's scope (pre-fix diagnostic):"
  check_scope "$(extract_key /tmp/dg_unauth.json)"
  validate_response /tmp/dg_unauth.json
else
  echo "Unauthenticated caller rejected."
fi

if [[ -n "${BACKEND_API_KEY:-}" ]]; then
  echo
  echo "== 2. Authenticated probe =="
  hdrs=(-H "X-Noum-API-Key: ${BACKEND_API_KEY}")
  [[ -n "${NOUM_ACCOUNT_ID:-}" ]] && hdrs+=(-H "X-Noum-Account-ID: ${NOUM_ACCOUNT_ID}")
  [[ -n "${NOUM_AUTH_PROVIDER:-}" ]] && hdrs+=(-H "X-Noum-Auth-Provider: ${NOUM_AUTH_PROVIDER}")
  code=$(curl -s -o /tmp/dg_auth.json -w '%{http_code}' "${hdrs[@]}" "$EP" || true)
  echo "HTTP $code"
  if [[ "$code" == "200" ]]; then
    check_scope "$(extract_key /tmp/dg_auth.json)"
    validate_response /tmp/dg_auth.json
  fi
fi

echo
echo "Pass criteria: step 1 = non-200; authenticated key (step 2) = usage:write only, with a short expiry."
