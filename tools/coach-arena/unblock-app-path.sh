#!/usr/bin/env bash
# Refresh the local Swift app-path evidence chain for Ask Noum readiness.
#
# This script intentionally does not create launch-evidence sidecars. It only
# refreshes the local app-path dump and reports from the real Swift XCTest bridge.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
cd "$repo_root"

dump_dir="${NOUM_COACH_EVAL_DUMP_DIR:-/private/tmp/noum-coach-eval}"
derived_data="${NOUM_COACH_DERIVED_DATA:-/private/tmp/noum-derived-data-apppath}"
spm_dir="${NOUM_COACH_SPM_DIR:-/private/tmp/noum-spm-apppath}"
destination="${NOUM_COACH_XCODE_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

mkdir -p "$dump_dir" "$derived_data" "$spm_dir"

./tools/coach-arena/run.sh app-path-source "$dump_dir"

NOUM_COACH_EVAL_DUMP_DIR="$dump_dir" xcodebuild test \
  -quiet \
  -project Noum.xcodeproj \
  -scheme Noum \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$spm_dir" \
  -only-testing:NoumTests/CoachChatConversationArtifactDumpXCTest

./tools/coach-arena/run.sh app-path "$dump_dir/coach-chat-conversation-app-path-eval-v1.json"
./tools/coach-arena/run.sh app-path-preflight "$dump_dir" --no-fail
./tools/coach-arena/run.sh readiness --dump-dir "$dump_dir" --no-fail
