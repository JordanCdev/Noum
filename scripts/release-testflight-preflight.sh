#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "TestFlight preflight requires macOS with Xcode and Apple signing tools." >&2
  exit 2
fi

for required_tool in xcodebuild xcrun security; do
  if ! command -v "$required_tool" >/dev/null 2>&1; then
    echo "TestFlight preflight cannot run: missing $required_tool." >&2
    exit 2
  fi
done

exec python3 "$repo_root/scripts/release_testflight_preflight.py" "$@"
