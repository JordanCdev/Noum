#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/NoumDerivedData}"
SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-/tmp/NoumSourcePackages}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
SCHEME="${SCHEME:-Noum}"

if ! xcrun simctl list devices >/dev/null 2>&1; then
    echo "CoreSimulator is unavailable. Open Xcode or Simulator and try again." >&2
    exit 1
fi

mkdir -p "$DERIVED_DATA_PATH" "$SOURCE_PACKAGES_PATH"

cd "$ROOT_DIR"

xcodebuild test \
    -project Noum.xcodeproj \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH"
