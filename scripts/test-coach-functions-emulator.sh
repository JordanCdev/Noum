#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

# Compatibility entry point. Keep one release-owned emulator contract so this
# older command cannot drift to a mutable CLI or the production project name.
exec "$repo_root/scripts/release-functions-emulator.sh" "$@"
