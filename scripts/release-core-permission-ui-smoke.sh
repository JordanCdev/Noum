#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
runner_temp="${RUNNER_TEMP:-/tmp}"
derived_data="${DERIVED_DATA_PATH:-$runner_temp/NoumCorePermissionDerivedData}"
source_packages="${SOURCE_PACKAGES_PATH:-$runner_temp/NoumSourcePackages}"
destination="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2}"

for required in \
  "$repo_root/Noum/Info.plist" \
  "$repo_root/Noum/GoogleService-Info.plist"; do
  if [[ ! -s "$required" ]]; then
    echo "Required UI-smoke plist is missing: ${required#$repo_root/}" >&2
    exit 2
  fi
done

mkdir -p "$derived_data" "$source_packages"
cd "$repo_root"

# Release-critical journeys are intentionally serialized. These owners use
# process-wide account, permission, and session stores; parallel simulator
# shards would make a green run less trustworthy, not faster in a useful way.
xcodebuild test -quiet \
  -project Noum.xcodeproj \
  -scheme Noum \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$source_packages" \
  -only-testing:NoumUITests/NoumUITests/testFirstRunCreatesAccountThenTimedHarnessReachesFirstVerdict \
  -only-testing:NoumUITests/GoalOutcomeLoopUITests/testTranscriptLadderPractisesOneStepRewriteFromSummary \
  -only-testing:NoumUITests/HomePracticePathPolishUITests/testFillerControlMicrophoneDenialOffersSettingsNotStart \
  -only-testing:NoumUITests/HomePracticePathPolishUITests/testPaceMicrophoneDenialOffersSettingsNotStart \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  ONLY_ACTIVE_ARCH=YES
