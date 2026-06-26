# Baseline Readout Refinement

## Product intent

The prior baseline graph/readout felt too technical and visually heavy for a premium communication coach. This pass turns it into a coach-style diagnosis: a short headline, one priority sentence, two evidence metrics, and compact signal tiles.

## Changes

- Replaced the dense baseline graph/list presentation in `ProfileView.swift` with a calmer `Baseline readout` card.
- Added coach-facing summary copy from `BaselineCoachMap`: headline plus a priority line grounded in the weakest measured dimension or the next evidence gap.
- Reworked the dimension display into compact tiles with soft state labels: `Strong`, `Working`, `Focus`, and `Needs signal`.
- Simplified the goal-gap treatment so it motivates without looking like another graph.
- Added unit coverage for the new coach headline, weakest-gap priority, evidence-gap fallback, and state-label thresholds.

## Screenshots

- Final verified capture: `.screenshots/2026-06-26_baseline-readout-refinement/02_profile_baseline_readout_final.png`
- Light sweep:
  - `01_home_top.png` — Home tab
  - `01_train_top.png` — Train tab
  - `01_review_top.png` — Review tab
  - `01_profile_top.png` — Profile tab
  - `01_settings_top.png` — Settings tab

## Verification

- `git diff --check -- ProfileView.swift Noum/BaselineEngine.swift NoumTests/NoumTests.swift`
- `DEVELOPER_DIR=/Users/jordan/Downloads/Xcode-beta.app/Contents/Developer xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath .derived-data/setup-polish -only-testing:NoumTests/BaselineCoachMapTests`
- `DEVELOPER_DIR=/Users/jordan/Downloads/Xcode-beta.app/Contents/Developer xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath .derived-data/setup-polish -only-testing:NoumUITests/ScreenshotTour/testCaptureProfileBaselineMapOnly -resultBundlePath /tmp/noum-baseline-readout-v8.xcresult`
- Noum screenshots mode: `light`. Captured and visually checked the five tab tops on the booted iPhone 17 simulator.

All three passed. The first UI capture attempt on an iPhone 17 Pro simulator failed before the app ran because Xcode could not clone/install to that device set; the retry on the stable iPhone 17 simulator passed and produced the attached screenshot.

## Remaining risks

- Only the focused profile-baseline UI test was rerun for this pass, not the full screenshot tour.
- The lower goal-gap section sits below the first fold in the captured state; a future profile-bottom capture should verify that section in full.
- Multiple dimensions can still show `Focus` at once when evidence supports it. That is honest, but future polish could make one recommended priority more visually dominant.
