# Baseline Readout Polish

Date: 2026-06-26
Mode: targeted profile capture, using the Noum screenshots flow in light mode as the baseline.

## Product Intent

The previous baseline radar/spider graph looked technical, noisy, and easy to misread. This pass replaces it with a coach-readable baseline readout: each dimension shows whether Noum has enough evidence, what the current measured value is, and the relative quality bar without pretending thin evidence is a confident verdict.

## Changed

- Replaced the Profile baseline radar graph with a vertical signal readout.
- Renamed visible and accessibility copy from "Baseline map" to "Baseline readout".
- Changed row status language from positive-sounding readiness to evidence language: Needs reps, Early, Forming, Mapped.
- Changed the bar fill to represent current score when measured, not evidence volume.
- Added concrete composure value labels such as hedges/min and pauses/min instead of a vague "forming" fallback.
- Updated the focused screenshot UI test so it opens the baseline readout and scrolls to the card body.

## Screenshots

- `01_profile_top.png` - profile top, before opening the evidence row.
- `03_profile_baseline_readout_body.png` - intermediate body capture before final label polish.
- `04_profile_baseline_readout_quality.png` - intermediate capture after score-bar semantics changed.
- `05_profile_baseline_readout_final.png` - final inspected capture.

## Verification

- `git diff --check -- ProfileView.swift Noum/BaselineEngine.swift Noum/Resources/Localizable.xcstrings NoumUITests/ScreenshotTour.swift`
- `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath .derived-data/setup-polish -only-testing:NoumTests/BaselineCoachMapTests`
- `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath .derived-data/setup-polish -only-testing:NoumUITests/ScreenshotTour/testCaptureProfileBaselineMapOnly -resultBundlePath /tmp/noum-baseline-readout-v4.xcresult`
- Final screenshot inspected manually: `.screenshots/2026-06-26_baseline-readout-polish/05_profile_baseline_readout_final.png`

## Notes

This was a targeted fix for the graph complaint, not a full app-wide visual sweep. The card is taller than one viewport, so the final screenshot confirms the problematic graph area and top set of rows; the lower goal-gap/motivation sections should still be included in a later full detailed screenshot sweep.
