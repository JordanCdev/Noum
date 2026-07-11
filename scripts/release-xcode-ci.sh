#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
runner_temp="${RUNNER_TEMP:-/tmp}"
derived_data="${DERIVED_DATA_PATH:-$runner_temp/NoumDerivedData}"
source_packages="${SOURCE_PACKAGES_PATH:-$runner_temp/NoumSourcePackages}"
destination="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2}"

for required in \
  "$repo_root/Noum/Info.plist" \
  "$repo_root/Noum/GoogleService-Info.plist"; do
  if [[ ! -s "$required" ]]; then
    echo "Required CI plist is missing: ${required#$repo_root/}" >&2
    exit 2
  fi
done

mkdir -p "$derived_data" "$source_packages"
cd "$repo_root"

xcodebuild build -quiet \
  -project Noum.xcodeproj \
  -scheme Noum \
  -configuration Release \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$source_packages" \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES

app_bundle="$(find "$derived_data/Build/Products/Release-iphonesimulator" \
  -maxdepth 1 -type d -name 'Noum.app' -print -quit)"
if [[ -z "$app_bundle" ]]; then
  echo "Release build did not produce Noum.app." >&2
  exit 1
fi
"$repo_root/scripts/release-scan-app-bundle.sh" "$app_bundle"

xcodebuild test -quiet \
  -project Noum.xcodeproj \
  -scheme Noum \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$source_packages" \
  -only-testing:NoumTests \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES
