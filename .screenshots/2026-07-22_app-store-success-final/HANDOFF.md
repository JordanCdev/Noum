# Run: 2026-07-22 · branch:ux-overhaul · HEAD 6f0d803522 · App Store success system

## Mode
light, plus focused first-week, paywall, and Summary UI-test captures

## Changes shipped (this run)
- `Noum/AutoGuidedFirstRep.swift`, `Noum/ContentView.swift`, `Noum/SummaryView.swift` — explicit 30-second Day-0 spoken proof, exact-session Summary recovery, and no pre-proof paywall.
- `Noum/FirstWeekCoachingContract.swift`, `Noum/NotificationManager.swift` — one Day-0-to-Day-7 coaching contract anchored to the first qualifying spoken baseline, including step-specific notifications and a durable first-week read.
- `Noum/GrowthObservability.swift`, `Noum/BackendSyncManager.swift`, `functions/src/growthAggregate.ts` — content-free activation, retention, commercial, cohort, and AI-cost aggregates.
- `Noum/PremiumManager.swift`, `functions/src/appStoreServerNotifications.ts` — StoreKit-authoritative trial/paywall/lifecycle handling and fail-closed App Store notification ingestion for the exact launch products.
- `AppStore/`, `public/`, `Noum/AppReviewPrompt.swift` — controlled listing package, trust/support/privacy pages, contextual review policy, CPP/PPO briefs, and preview storyboard.

## Screenshots
- `01_home_top.png` — Home with the current real-world preparation and first-week read entry.
- `02_train_top.png` — coach-built recommended rep with the full library collapsed behind **Choose for myself**.
- `03_review_top.png` — evidence-scaled recent movement and one next focus.
- `04_profile_top.png` — bounded baseline, current coaching focus, and real-world check-in.
- `05_settings_top.png` — Settings top.
- `06_first_week_read_top.png`, `07_first_week_read_details.png` — durable first-week read failing closed where a comparison or quote is not supportable.
- `08_paywall_top.png`, `09_paywall_details.png` — contextual paywall and its honest StoreKit-unavailable fallback on this simulator runtime.
- `10_summary_top.png`, `11_summary_mid.png`, `12_summary_bottom.png` — one verified quote, restrained observation, inline progress receipt, and prescribed next rep.

## VISION gap
The local journey now supports Noum's evidence-led promise: prove value through the user's own words, keep uncertainty visible, prescribe one next action, and make the first week coherent. The code cannot establish professional-coach calibration, real-world transfer, D1/D7 retention, storefront conversion, contribution margin, or production operations; those remain evidence gates rather than UI claims.

## Next steps to reach desired state
1. Complete `docs/MANUAL_LAUNCH_ACTIONS.md`: deploy reviewed web/Functions/rules, configure App Store Connect products/trial/URLs/CPP/PPO, and produce a signed TestFlight archive.
2. Run the physical-device sandbox lifecycle and accessibility/interruption/offline matrix.
3. Complete live-provider evaluation, three-person blinded professional review, and the four-week beta before acquisition spend.

## Regressions checked
- Fresh install → written value → explicit spoken rep → Summary → contextual paywall — signed UI test passed.
- First-week read, paywall fallback, and Summary — focused UI tests passed 3/3 and every exported PNG was inspected.
- Five tab roots — deep links rendered the expected root; no blank, crash, or stuck splash capture.

## Surfaces needing visual verification (cloud → local queue)
- Real App Store products, eligible seven-day annual trial dates/copy, and purchase lifecycle on a physical sandbox/TestFlight device.
- Large Dynamic Type, VoiceOver, reduced motion, notification opens, microphone interruptions, and offline recovery on physical hardware.
- Final App Store screenshots and preview after storefront configuration.

## For next run
- **If cloud**: review aggregate reconciliation and launch documentation; do not claim live URLs or StoreKit evidence.
- **If local**: capture the real storefront paywall and complete the signed physical-device matrix.
