# Run: 2026-07-14 · branch:ux-overhaul · HEAD 47cbab5f · preserve Speech Project execution

## Mode

light

## Changes shipped (this run)

- `Noum/AppShellView.swift:90` — resolves known `noum://projects/<id>` links into a typed project destination.
- `Noum/TimedPracticeView.swift:141` — keeps standard Timed timing unchanged while prepared speeches use their catalog range and remain user-ended.
- `Noum/TimedPracticeView.swift:1092` — renders the selected project's title, focus, timing, and coaching cue in the established focused-practice scaffold.
- `Noum/PracticeSupport.swift:372` — reuses the existing evaluator with a project duration contract instead of creating a second scoring system.
- `NoumTests/ProductionReadinessOverhaulTests.swift:65` — locks routing, curated prompts, ordinary Timed behavior, and honest project duration assessment.
- `NoumUITests/FocusedPracticeSetupUITests.swift:134` — proves the real Ice Breaker route retains identity, exposes Begin, and hides the tab bar.

## Screenshots

- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, top of view.
- `01_review_top.png` — Review tab, top of view.
- `01_profile_top.png` — Profile tab, top of view.
- `01_settings_top.png` — Settings tab, top of view.
- `02_ice_breaker_setup.png` — Ice Breaker resolved into Timed with the four-to-six-minute contract.

## VISION gap

The project browser now leads to a coherent guided speech instead of a generic
short Timed rep. Project identity is not yet persisted as longitudinal
completion/progress state, and the adaptive next-action engine deliberately
does not prescribe Projects. Those remain product and measurement decisions,
not claims earned by this routing repair.

## Next steps to reach desired state

1. Decide whether project completion should become part of the existing session model and export/deletion contract before adding any progress UI.
2. Decide whether Speech Projects belong in the adaptive prescription domain; if so, expand routing and exposure measurement atomically rather than adding a parallel recommendation owner.
3. Validate the project setup and a full four-to-six-minute rep on a physical TestFlight device as part of the existing external evidence workflow.

## Regressions checked

- Five primary tab tops — `01_*_top.png` — rendered the expected screen.
- Ice Breaker setup — `02_ice_breaker_setup.png` — correct title, focus, four-minute minimum, six-minute target, coaching cue, and begin action.
- Standard Timed timing — unit contract — existing 60/90/120/150 thresholds and automatic stop preserved.
- Full `NoumTests` regression — clean `47cbab5f` result bundle — 3,946 tests across 411 suites, zero failures or skips.
- Unsigned optimized Release simulator build — clean `47cbab5f` — succeeded.

## Surfaces needing visual verification (cloud → local queue)

- A complete prepared-speech run through live recording and Summary on a physical device.
- Dynamic in-rep timing zones after four, five, and six minutes.

## For next run

- **If cloud**: audit the existing session/export schema for a safe optional project identity without implementing it absent a product decision.
- **If local**: exercise Ice Breaker end-to-end on TestFlight and attach the required physical-device evidence through the release workflow.
