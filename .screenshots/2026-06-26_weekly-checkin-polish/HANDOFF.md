# Weekly Check-In Polish

## Product intent

VISION says Noum needs the user's inner experience, but that evidence must feel human and self-reported, not like a diagnostic form. The previous weekly check-in had the right architecture but opened as a plain form with several fields. This pass makes the surface feel closer to a coach asking one useful question.

## Changes

- `Noum/WeeklyCheckInCard.swift` — extracted `WeeklyCheckInCopy` and `WeeklyCheckInPrompt` so the coaching language is testable instead of scattered through the view.
- `Noum/WeeklyCheckInCard.swift` — changed the profile entry to "Your weekly read" with a lighter value prop.
- `Noum/WeeklyCheckInCard.swift` — changed the sheet headline to "What should Noum know?", added a "No score. No diagnosis." self-report note, and rewrote field/chip prompts to be warmer and more optional.
- `NoumTests/NoumTests.swift` — added `WeeklyCheckInCopyTests` to pin self-report framing, persisted field IDs, short prompt copy, and avoidance of performance-review language.

## Screenshots

- `01_weekly_checkin_sheet_final.png` — focused UI-test capture of the polished sheet.

## VISION gap

This supports pillar 5, personalized coaching, and coach-parity stage 2, case formulation. A coach needs to know what felt difficult, where it showed up outside practice, and what the user avoided saying. The UI now frames those answers as the user's words, not as a score or diagnosis.

## Verification

- `git diff --check -- Noum/WeeklyCheckInCard.swift NoumTests/NoumTests.swift` — passed.
- `DEVELOPER_DIR=/Users/jordan/Downloads/Xcode-beta.app/Contents/Developer xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath .derived-data/setup-polish -only-testing:NoumTests/WeeklyCheckInCopyTests -only-testing:NoumTests/CoachCheckInStoreTests` — passed.
- `DEVELOPER_DIR=/Users/jordan/Downloads/Xcode-beta.app/Contents/Developer xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath .derived-data/setup-polish -only-testing:NoumUITests/ScreenshotTour/testCaptureWeeklyCheckInSheetOnly -resultBundlePath /tmp/noum-weekly-checkin-polish.xcresult` — passed.
- Exported the UI-test attachment and visually inspected `01_weekly_checkin_sheet_final.png`.

## Remaining risks

- The lower sheet content is below the first captured fold. The focused test proves the sheet opens and the above-fold copy fits; a manual scroll capture would be useful before final TestFlight QA.
- The check-in still opens as a sheet from Profile. That is acceptable because it is user-initiated and cadence-gated, but future work could also surface the same question inside Ask Noum when the user is already talking to the coach.
