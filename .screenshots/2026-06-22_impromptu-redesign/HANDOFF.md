# Impromptu Redesign Handoff

- Branch: `ux-overhaul`
- Head: `c9e5cd9`
- Date: 2026-06-22
- Mode: focused UI-test capture for the Timed / Impromptu setup surface.

## What Changed

- Replaced the old Classic / Coach choice and horizontal theme chip rail with a default-first Impromptu entry.
- Moved controls into a gear-driven settings surface so users can start immediately.
- Kept free settings lightweight: prep countdown, prompt visibility, timer display, prompt pool.
- Converted Pro tools into locked rows that open the existing upgrade screen instead of duplicating mode cards.
- Wired Ask Noum launch suggestions to arm quick start before navigating to the suggested practice mode.

## Screenshots

- `14-timed-setup.png` - default start surface.
- `14b-timed-settings.png` - settings opened from the gear.
- `14c-timed-settings-tools.png` - scrolled settings showing locked Coach Tools.

## Verification

- Passed: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData/Noum-impromptu-redesign -only-testing:NoumUITests/ScreenshotTour/testCaptureTimedSetupOnly -resultBundlePath /tmp/noum-impromptu-focused-12.xcresult`
- Passed: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData/Noum-impromptu-redesign -only-testing:NoumTests/AskNoumModeSuggestionTests`
- Passed: `git diff --check`
- Passed: static scan for removed setup selectors/state in `TimedPracticeView.swift`.

## Notes

- The full screenshot tour was attempted earlier and failed outside this surface when the app/simulator stopped during Review capture, so this handoff records the focused passing baseline for the touched flow.
- The locked Pro rows now assert that the upgrade screen appears via `paywall.root`.
- Remaining product work is the in-rep experience itself; this pass focused on the setup/entry friction and Ask Noum handoff.
