# Baseline Map And Signup Motivation Handoff

- Branch: `ux-overhaul`
- Date: 2026-06-22
- Mode: light tab sweep plus focused profile baseline-map UI capture.

## What Changed

- Added a `BaselineCoachMap` read model that turns the existing `CommunicationBaseline` into coach-facing dimensions: filler control, pace control, structure, clarity, composure, and vocal range.
- Added a Profile evidence card with baseline formation progress, radar-style evidence coverage, active measured reads, goal-gap progress, and the user's original signup motivation when available.
- Kept gap-to-goal restrained: it only appears when the existing measured-distance logic has enough evidence.
- Added signup-memory context to Ask Noum so the coach can occasionally reconnect practice to what the user wrote at signup, without quoting it every turn or inventing emotions.
- Restored two prompt-contract guardrails around compact Ask Noum replies and non-template visible labels.
- Fixed the Profile evidence toggle accessibility identifier so UI tests can address it reliably.

## Screenshots

- `01-home.png` - seeded Home top.
- `02-train.png` - seeded Train top.
- `03-review.png` - seeded Review top.
- `04-profile.png` - seeded Profile top.
- `05-settings.png` - seeded Settings top.
- `06-profile-baseline-map.png` - focused expanded Profile evidence capture showing the baseline map and goal gap.

## Verification

- Passed: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData/Noum-baseline-map -only-testing:NoumTests/BaselineCoachMapTests -only-testing:NoumTests/GoalProgressTests -only-testing:NoumTests/CoachContextBuilderTests`
- Passed: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData/Noum-baseline-map -only-testing:NoumUITests/ScreenshotTour/testCaptureProfileBaselineMapOnly -resultBundlePath /private/tmp/noum-baseline-map-profile-20260622-2242.xcresult`
- Passed: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData/Noum-baseline-map -only-testing:NoumUITests/NoumUITests/testProfileEvidenceDisclosureStaysCoachEvidenceOnly -resultBundlePath /private/tmp/noum-profile-evidence-regression-20260622-2246.xcresult`
- Passed: `git diff --check`
- Passed: manual visual inspection of `06-profile-baseline-map.png`; changed the established counter from `12/10` to `12 reps` after the first visual pass.

## Notes

- The radar prioritizes evidence coverage first, then overlays current measured score only where the baseline has enough signal. This avoids pretending thin data is stable.
- The signup memory is intentionally available to the coach context and Profile evidence, not pushed as a daily modal. It should feel like a human coach remembering why the work matters.
- Full app regression was not run; this handoff records focused coverage for the baseline/profile/coaching-context surfaces touched here.
