#!/usr/bin/env bash
# Refresh the complete local Ask Noum evidence chain from the current checkout.
# External reviewer, beta-user, TestFlight, and launch sidecars are never
# synthesized here; when present, the Swift manifest and Python gate validate
# them in place.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
cd "$repo_root"

dump_dir="${NOUM_COACH_EVAL_DUMP_DIR:-/private/tmp/noum-coach-eval}"
derived_data="${NOUM_COACH_DERIVED_DATA:-/private/tmp/noum-derived-data-evidence}"
destination="${NOUM_COACH_XCODE_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

mkdir -p "$dump_dir" "$derived_data"

./tools/coach-arena/run.sh app-path-source "$dump_dir"

NOUM_COACH_EVAL_DUMP_DIR="$dump_dir" xcodebuild test \
  -quiet \
  -project Noum.xcodeproj \
  -scheme Noum \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:NoumTests/CoachChatConversationArtifactDumpXCTest

./tools/coach-arena/run.sh app-path "$dump_dir/coach-chat-conversation-app-path-eval-v1.json"
./tools/coach-arena/run.sh app-path-preflight "$dump_dir"
./tools/coach-arena/run.sh readiness \
  --dump-dir "$dump_dir" \
  --repo-root "$repo_root" \
  "$@"
