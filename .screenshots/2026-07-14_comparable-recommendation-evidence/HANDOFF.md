# Run: 2026-07-14 · branch:ux-overhaul · HEAD f1d6ec72 · comparable recommendation evidence

## Mode
light

## Changes shipped (this run)
- `Noum/PracticeSupport.swift` — recommendation outcomes now compare bounded, same-demand recent reps, normalize fillers by minute, judge the prescribed metric, and fail closed without compatible provenance.
- `Noum/SpeechRecognizerViewModel.swift` — practice sessions persist a metric-evaluator epoch so unlike historical measurements cannot be averaged.
- `Noum/GoalRubric.swift` and `Noum/FlowObservability.swift` — goal movement and KPI projections ignore legacy or unknown comparison schemas.
- `Noum/SettingsView.swift` — recommendation diagnostics identify filler-rate deltas and retain one-decimal direction/magnitude.

## Screenshots
- `01_home_top.png` — Home tab, seeded top state.
- `01_train_top.png` — Train tab, recommended Filler Control rep.
- `01_review_top.png` — Review tab, recent-movement projection.
- `01_profile_top.png` — Profile tab, selected voice target and current focus.
- `01_settings_top.png` — Settings tab, top practice controls.

The first unseeded sweep stopped at the fail-closed account-save screen. The final retained frames were recaptured with the repository's deterministic `UI_TESTING_SEED_FORCE` profile and visually checked. The changed DEBUG recommendation-diagnostics card is below the light sweep's Settings viewport and remains covered by focused source tests rather than this top-frame capture.

## VISION gap
Recommendation learning is now more believable because outcome claims require comparable, normalized, metric-specific evidence. Exact practice demand is still only partially persisted: Timed/Sudden Death difficulty and Speech Project identity are not yet available to the comparison engine, so it deliberately withholds narrower claims it cannot prove.

## Next steps to reach desired state
1. Move the Home/Train synchronous `prescription.shown` write ahead of tap-time capability fallback so a shown-but-now-unavailable recommendation remains in the denominator.
2. Persist the remaining practice-demand identity needed for exact comparisons, especially difficulty and Speech Project identity.
3. Bring `PrimaryFocusMemory.followedRepValues` onto the same accepted-prescription and normalized-filler evidence contract.

## Regressions checked
- Home top — `01_home_top.png` — rendered seeded plan, primary action, Ask Noum entry, and tab shell.
- Train top — `01_train_top.png` — rendered the coherent Filler Control recommendation and practice library.
- Review top — `01_review_top.png` — rendered recent movement and saved-rep entry points.
- Profile top — `01_profile_top.png` — rendered selected voice, rating, current focus, and qualitative check-in.
- Settings top — `01_settings_top.png` — rendered practice controls and tab shell; lower DEBUG diagnostics not in viewport.

## Surfaces needing visual verification (cloud → local queue)
- Lower Settings recommendation-diagnostics card with fractional positive and negative filler-rate examples.
- Home/Train tap-time capability-loss fallback denominator once implemented.

## For next run
- **If cloud**: audit persisted difficulty/project identity and recommendation-store write serialization.
- **If local**: capture the lower Settings diagnostics and a rendered capability-loss fallback route.
