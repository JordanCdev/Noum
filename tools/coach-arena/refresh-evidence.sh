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
source_packages="${NOUM_COACH_SPM_DIR:-$repo_root/.build/fast-lane-release/SourcePackages}"
if [[ -z "${NOUM_COACH_XCODE_DESTINATION:-}" ||
      "${NOUM_COACH_DISPOSABLE_SIMULATOR:-}" != "1" ]]; then
  echo "Coach Arena app-path evidence can replace the installed app and mutate simulator account state." >&2
  echo "Set NOUM_COACH_XCODE_DESTINATION to a disposable simulator and NOUM_COACH_DISPOSABLE_SIMULATOR=1." >&2
  exit 2
fi
destination_pattern='^platform=iOS Simulator,id=[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
if [[ ! "$NOUM_COACH_XCODE_DESTINATION" =~ $destination_pattern ]]; then
  echo "NOUM_COACH_XCODE_DESTINATION must name one simulator by exact UDID; name-only destinations are unsafe." >&2
  exit 2
fi
destination="$NOUM_COACH_XCODE_DESTINATION"
source "$script_dir/simulator-evidence-environment.sh"

trap noum_coach_simulator_environment_exit_trap EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

mkdir -p "$dump_dir" "$derived_data"
if [[ ! -d "$source_packages/checkouts" ]]; then
  echo "Missing populated offline Swift package cache: $source_packages/checkouts" >&2
  echo "Set NOUM_COACH_SPM_DIR to an existing SourcePackages directory." >&2
  exit 2
fi

./tools/coach-arena/run.sh app-path-source "$dump_dir"

noum_coach_install_simulator_environment "$destination" "$dump_dir"
destination="platform=iOS Simulator,id=$NOUM_COACH_SIMULATOR_UDID"

env \
  -u COACH_ARENA_LLM_JUDGE_CMD \
  -u ANTHROPIC_API_KEY \
  -u GEMINI_API_KEY \
  -u OPENAI_API_KEY \
  -u DEEPSEEK_API_KEY \
  NOUM_COACH_EVAL_DUMP_DIR="$dump_dir" \
  NOUM_SOURCE_GIT_COMMIT="$NOUM_COACH_SOURCE_GIT_COMMIT" \
  NOUM_SOURCE_COACH_FINGERPRINT="$NOUM_COACH_SOURCE_COACH_FINGERPRINT" \
  SIMCTL_CHILD_NOUM_COACH_EVAL_DUMP_DIR="$dump_dir" \
  SIMCTL_CHILD_NOUM_SOURCE_GIT_COMMIT="$NOUM_COACH_SOURCE_GIT_COMMIT" \
  SIMCTL_CHILD_NOUM_SOURCE_COACH_FINGERPRINT="$NOUM_COACH_SOURCE_COACH_FINGERPRINT" \
  xcodebuild test \
  -quiet \
  -project Noum.xcodeproj \
  -scheme Noum \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$source_packages" \
  -disableAutomaticPackageResolution \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  -only-testing:NoumTests/CoachChatConversationArtifactDumpXCTest \
  ONLY_ACTIVE_ARCH=YES

noum_coach_simulator_environment_cleanup

env -u COACH_ARENA_LLM_JUDGE_CMD \
  ./tools/coach-arena/run.sh app-path "$dump_dir/coach-chat-conversation-app-path-eval-v1.json"
./tools/coach-arena/run.sh app-path-preflight "$dump_dir"
./tools/coach-arena/run.sh readiness \
  --dump-dir "$dump_dir" \
  --repo-root "$repo_root" \
  "$@"
