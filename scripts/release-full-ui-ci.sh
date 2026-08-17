#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
runner_temp="${RUNNER_TEMP:-/tmp}"
derived_data="${DERIVED_DATA_PATH:-$runner_temp/NoumFullUIDerivedData}"
source_packages="${SOURCE_PACKAGES_PATH:-$runner_temp/NoumSourcePackages}"
result_bundle="${RESULT_BUNDLE_PATH:-$runner_temp/NoumFullUI.xcresult}"
destination="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2}"

for required in \
  "$repo_root/Noum/Info.plist" \
  "$repo_root/Noum/GoogleService-Info.plist"; do
  if [[ ! -s "$required" ]]; then
    echo "Required full-UI plist is missing: ${required#$repo_root/}" >&2
    exit 2
  fi
done

if [[ -e "$result_bundle" ]]; then
  echo "Full-UI result bundle path already exists: $result_bundle" >&2
  exit 2
fi

mkdir -p "$derived_data" "$source_packages" "$(dirname "$result_bundle")"
cd "$repo_root"

# The target owns process-wide account, permission, audio, and session state.
# One simulator worker keeps the release signal deterministic and ensures the
# selector covers the complete target rather than a curated method list.
xcodebuild test -quiet \
  -project Noum.xcodeproj \
  -scheme Noum \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$source_packages" \
  -resultBundlePath "$result_bundle" \
  -only-testing:NoumUITests \
  -parallel-testing-enabled NO \
  -maximum-parallel-testing-workers 1 \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  ONLY_ACTIVE_ARCH=YES

xcrun xcresulttool get test-results summary \
  --path "$result_bundle" \
  --format json \
  | python3 "$repo_root/scripts/release_xcresult_gate.py" \
      "$repo_root/NoumUITests"
