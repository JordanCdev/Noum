#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
runner_temp="${RUNNER_TEMP:-/tmp}"
derived_data="${DERIVED_DATA_PATH:-$runner_temp/NoumBetaFeedbackDerivedData}"
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

# Intentionally one source-bound journey, not the full screenshot/a11y tour.
# This catches Settings routing, Dynamic SwiftUI discovery, text entry, and
# the disabled-to-enabled send contract within a short release shard.
xcodebuild test -quiet \
  -project Noum.xcodeproj \
  -scheme Noum \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$source_packages" \
  -only-testing:NoumUITests/BetaFeedbackUITests/testSettingsBetaFeedbackRouteShowsRedactedReport \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES
