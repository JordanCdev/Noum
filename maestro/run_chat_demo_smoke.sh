#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:-booted}"
APP_ID="${NOUM_APP_ID:-com.jordancoaten.noum}"

if ! command -v maestro >/dev/null 2>&1; then
  echo "maestro is not installed or not on PATH" >&2
  exit 127
fi

if ! xcrun simctl list devices booted | grep -q "(Booted)"; then
  echo "No booted iOS simulator found" >&2
  exit 1
fi

launch_for_flow() {
  local force_flag="$1"
  xcrun simctl terminate "$DEVICE" "$APP_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$DEVICE" "$APP_ID" \
    UI_TESTING \
    UI_TESTING_SEED_FORCE \
    "$force_flag" \
    -DeepLink \
    noum://ask/type >/dev/null
}

cd "$ROOT_DIR"

launch_for_flow UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY
maestro test maestro/chat_smoke.yaml

launch_for_flow UI_TESTING_CHAT_FORCE_NOTICE
maestro test maestro/chat_reject_smoke.yaml
