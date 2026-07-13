# Run: 2026-07-13 · branch:ux-overhaul · HEAD 5237db86 · permissionless first value without fake speech evidence

## Mode
light

## Changes shipped (this run)
- `Noum/FastLaneOnboardingView.swift` — two real choices, one offline written rehearsal, a structure-only result, and explicit spoken/explore exits.
- `Noum/FirstRunOnboardingManager.swift` — account-scoped draft/receipt and root policy without a second full-onboarding truth.
- `Noum/PracticeSupport.swift` — existing `CoachingProfileStore` owns verified draft persistence, account isolation, profile promotion, and cleanup.
- `Noum/RoleplayEngine.swift` — typed evaluation is restricted to content/structure axes and excludes speech-only delivery claims.
- `Noum/NoumApp.swift` and `Noum/CoachingOnboardingView.swift` — production root routing, prefilled full setup, and existing consent/Timed upgrade.
- `Noum/ContentView.swift` — one quiet Home card resumes deferred coaching setup.
- `Noum/FlowObservability.swift` — first value, first spoken rep, and structured-to-live upgrade remain separate content-free reads.

## Screenshots
- `01_home_top.png` — populated Home tab baseline; rendered correctly.
- `02_train_top.png` — Train tab baseline; rendered correctly.
- `03_review_top.png` — Review tab baseline; rendered correctly.
- `04_profile_top.png` — Profile tab baseline; rendered correctly.
- `05_settings_top.png` — Settings tab baseline; rendered correctly.
- `focus_structure_only_result.png` — first-value result with one strength, one next move, evidence boundary, and two restrained exits; visually verified.
- `focus_home_setup_resume.png` — cold Home after Explore, showing spoken-first-rep truth and one quiet setup-resume card; visually verified.

## VISION gap
The local experience now reaches useful value without permissions while preserving Noum's trust rule that written evidence cannot masquerade as spoken delivery evidence. The remaining gap is not another UI system: signed-device timing/permission behavior, experiment assignment, professional calibration, real-user longitudinal transfer, and physical TestFlight proof are still required before production efficacy claims.

## Next steps to reach desired state
1. Run the fast-lane and structured-to-live paths on a signed physical device, covering microphone denied/granted, cloud allow/decline, interruption, relaunch, Dynamic Type, VoiceOver, and Reduce Motion.
2. Resolve live-provider capacity/account failures and produce a fresh zero-refusal current-source sweep.
3. Make an explicit privacy/product decision before assigning activation experiments or aggregating population funnels.
4. Collect preregistered professional-calibration and real-user transfer evidence; retain mixed, negative, and adverse outcomes.

## Regressions checked
- Five-tab populated shell — `01_home_top.png` through `05_settings_top.png` — no launch, navigation, clipping, or blank-state regression.
- Structured result — `focus_structure_only_result.png` — no speech score, filler, pace, pause, tone, or composure claim.
- Explore path — `focus_home_setup_resume.png` — Home remains calm; setup continuation is visible without becoming a competing dashboard.
- Spoken upgrade — UI automation passes prefilled setup, cloud decline, and the existing local-capable Timed destination.
- Legacy first run — five onboarding/value-loop UI tests pass.
- Full unit sweep — 3,826/3,832 pass in one clean-simulator process; the same six unrelated coach/privacy tests pass when isolated, exposing pre-existing shared-process order dependence rather than a deterministic fast-lane failure.
- Release simulator build — passed at product HEAD `5237db86`.
- Canonical evidence refresh — 109 app-path traces and 50/50 scored fixtures pass at 79.76 average; JS runner 119/119 and Python runner 95/95 pass. Readiness remains an honest NO-GO at 18/100 because five external evidence rows are missing/stale.

## Surfaces needing visual verification (cloud → local queue)
- Physical-device keyboard/Dynamic Type behavior on the written rehearsal.
- VoiceOver reading order for choices, result cards, and Home resume card.
- Real iOS microphone and cloud-processing permission prompts during the structured-to-live upgrade.

## For next run
- **If cloud**: inspect experiment/privacy design and prepare preregistration materials; do not claim device or cohort evidence.
- **If local**: run the signed-device permission/consent matrix and capture the live-upgrade transition at large Dynamic Type.
