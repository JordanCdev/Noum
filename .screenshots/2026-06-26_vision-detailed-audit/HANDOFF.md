# Run: 2026-06-26 · branch:ux-overhaul · HEAD 5ef0ae6 · Review graph trust polish + setup visual cleanup

## Mode
detailed

## Changes shipped (this run)
- `Noum/ProgressionCharts.swift` — Review/Profile progression chart now separates raw observations from the coaching trend: low-evidence histories render calm dots only, evidence-rich histories render a smoothed trend line with raw dots still visible.
- `Noum/ProgressionCharts.swift` — bounded metrics use their real domain (`Score` = 0...10, `Pitch` = 0...1) so the chart no longer exaggerates ordinary movement by auto-zooming the axis.
- `Noum/ProgressionCharts.swift` — chart read copy now uses recent-block movement once enough evidence exists, aligning the headline/body with the `7d shift` stat instead of contradicting it with first-to-latest copy.
- `Noum/ProgressionCharts.swift` — Pace reads now use the shared `ConversationalPaceBand` target band, so a slow-but-improving pace says "Closer, still slow" instead of a vague "up" warning.
- `Noum/ProgressionCharts.swift` — low-evidence histories now replace the sparse plot with a quiet evidence track (`6/8`, "2 more measured reps...") so early Review reads feel intentional rather than graph-broken. The duplicate stat row is hidden until enough evidence exists.
- `Noum/ReviewInsightCards.swift` — coach-read caption now says "Uses your newest measured reps" instead of exposing an internal 8-rep trend window that could visually conflict with the chart's 30-day count.
- `Noum/AhCounterView.swift` — setup prep guidance is now one compact "Noum listens live" row, removing the chip stack that collided with the fixed Start CTA on iPhone 17.
- `Noum/IMPracticeView.swift` — IM setup scenario cards use taller, calmer vertical rows so descriptions and metadata chips no longer feel clipped inside a compact card.
- `NoumTests/ProgressionChartsPresentationTests.swift` — added presentation contracts for smoothed samples, raw-dot preservation, evidence-floor trend gating, baseline-progress state, recent-block reads, and full-scale score domains.
- `NoumTests/ReviewExperienceTests.swift` — added coach-read caption contracts so the Review stack avoids page-wide-history language and visible window math.

## Screenshots
- `07-review-top.png` — before/trigger state from the first detailed audit: 24-rep graph drew every raw point as a jagged line and said "Score is down 1.0" while the visible 7d shift was `+2.1`.
- `26-review-top-final-score-scale.png` — direct simulator check of the low-evidence state: baseline now renders observation dots, not a cliff line.
- `27-review-top-tour-final.png` — final detailed UI-test tour screenshot: 24-rep graph now shows a smoother trend line, raw dots, and "Moving the right way" copy aligned to the recent block.
- `30-review-baseline-meter-caption-final.png` — final direct simulator check: low-evidence Review now shows a baseline meter instead of an awkward sparse chart, and the coach-read caption no longer conflicts with the visible 30-day count.
- `31-review-evidence-track.png` — direct simulator check after the second graph pass: the low-evidence panel is now a restrained evidence track with inline Latest/Trend context, not a chunky meter.
- `32-tour-review-top-evidence-track.png` — exported tour attachment confirming the Review top state uses the same calmer evidence-track visual.
- `34-tour-im-conversation-setup-polished.png` — exported tour attachment confirming IM setup scenario rows are readable and no longer truncate their core descriptions.
- `35-tour-mode-picker-polished.png` — exported tour attachment confirming the mode picker defaults to one clear coach pick with "Other ways to practice" collapsed.
- `36-ah-counter-setup-compact-final.png` — fresh simulator screenshot after reinstalling the latest build; Ah-Counter setup has no CTA overlap and the prep card stays fully visible.
- `38-review-pace-target-band.png` — fresh simulator screenshot after reinstalling the latest Debug build; Pace now reads "Closer, still slow" and names the 110–150 WPM band while keeping the positive 7d shift green.

## VISION Gap
VISION pillar 4 says progress must be believable, not fake gamification. The old chart made noisy rep-to-rep speech data look like a chaotic stock ticker, then paired it with contradictory copy. That damaged trust: a coach should help the user see the signal in the noise without hiding the observations.

This run keeps the honest raw points once trend evidence exists but changes the early visual story to a baseline-building read. Weak evidence stays tentative ("Baseline forming") and shows progress toward the first real trend; stronger evidence uses recent-block movement rather than overclaiming from a single first/latest comparison.

The follow-up setup polish serves the same pillar: the app should feel composed while users are deciding what to practice. The mode picker now has one primary path, Ah-Counter no longer fights the Start CTA, and IM setup presents choices like a coach offering rehearsals rather than a noisy menu.

## Next Steps To Reach Desired State
1. `Noum/ProgressionCharts.swift` — consider a similarly careful target/healthy-zone read for pauses later, but only once the coaching model has enough evidence to avoid fake "ideal zone" claims.
2. `NoumUITests/ScreenshotTour.swift` — the tour is still the right regression path for broad visual coverage, but the current full-tour run stalled after exporting attachments. Keep the focused UI test as a faster gate and rerun the full tour once the simulator runner is stable.
3. `ReviewExperience` — continue checking lower Review cards for copy/evidence consistency; the top chart metric states have now had a targeted local sweep.

## Regressions Checked
- Focused unit tests: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath .derived-data/progression-graph -only-testing:NoumTests/ProgressionChartsPresentationTests` — passed.
- Focused follow-up tests: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .derived-data/review-evidence-window -only-testing:NoumTests/ProgressionChartsPresentationTests -only-testing:NoumTests/ReviewCoachReadTests` — passed.
- Detailed UI tour: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -derivedDataPath .derived-data/progression-graph -only-testing:NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces -resultBundlePath /private/tmp/noum-tour-graph-final-1108.xcresult` — passed.
- Visual checks: `27-review-top-tour-final.png` confirms the 24-rep chart is materially calmer and the trend/copy agree; `30-review-baseline-meter-caption-final.png` confirms the low-evidence state no longer looks like a broken graph.
- Current follow-up diff check: `git diff --check -- Noum/ProgressionCharts.swift NoumTests/ProgressionChartsPresentationTests.swift Noum/AhCounterView.swift Noum/IMPracticeView.swift` — passed.
- Current follow-up focused tests: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .derived-data/setup-polish -only-testing:NoumTests/ProgressionChartsPresentationTests -only-testing:NoumTests/ReviewCoachReadTests` — passed.
- Current follow-up build: `xcodebuild build -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .derived-data/setup-polish` — passed.
- Current follow-up focused UI test: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .derived-data/setup-polish -only-testing:NoumUITests/NoumUITests/testPracticeModesOpenAvailableScreens` — passed.
- Current follow-up detailed tour attempt: `xcodebuild test ... -only-testing:NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces -resultBundlePath /tmp/noum-tour-review-polish-20260626-1208.xcresult` — interrupted after exporting 219 attachments when the UI test runner stalled in launch/teardown. Useful attachments were copied into this folder and inspected, but this run is not a green full-tour pass.
- Current follow-up visual checks: `31-review-evidence-track.png`, `32-tour-review-top-evidence-track.png`, `34-tour-im-conversation-setup-polished.png`, `35-tour-mode-picker-polished.png`, and `36-ah-counter-setup-compact-final.png` were inspected.
- Pace target-band follow-up diff check: `git diff --check -- Noum/ProgressionCharts.swift NoumTests/ProgressionChartsPresentationTests.swift` — passed.
- Pace target-band focused tests: `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .derived-data/setup-polish -only-testing:NoumTests/ProgressionChartsPresentationTests` — passed.
- Pace target-band visual check: `38-review-pace-target-band.png` was inspected after installing `/Users/jordan/src/GitHub/Noum/.derived-data/setup-polish/Build/Products/Debug-iphonesimulator/Noum.app` into the visible iPhone 17 simulator.

## Surfaces Needing Visual Verification
- Full detailed screenshot tour should be rerun to completion on a stable simulator runner. The focused chart and practice-navigation checks passed, and the relevant visual attachments were inspected, but the broad tour did not finish cleanly.

## For Next Run
- **If cloud**: inspect the remaining Review lower cards for copy/evidence consistency and propose logic-only fixes without simulator dependency.
- **If local**: rerun the detailed tour once the simulator runner stops stalling; then continue lower Review-card and Profile/Ask Noum visual QA.
