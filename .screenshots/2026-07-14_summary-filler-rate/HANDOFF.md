# Run: 2026-07-14 · branch:ux-overhaul · HEAD dbafb01b · Normalize public filler comparisons

## Mode
light

## Changes shipped (this run)
- `Noum/BaselineEngine.swift:1024` — added the shared quantity-, confidence-, schema-, and fixture-qualified filler-rate comparison with two-prior and 0.5/min movement floors.
- `Noum/SummaryFillerPresentation.swift:3` — made one pure presentation read own Summary tone, delta, fallback insight, and VoiceOver wording.
- `Noum/SummaryView.swift:491` — replaced raw-count hero/detail comparisons with fillers-per-minute against repeated qualified history.
- `Noum/PracticeSupport.swift:8710` — aligned normal evaluator insights with the same strict comparison contract.
- `Noum/PracticeSupport.swift:11349` — normalized Profile/Review planning and made historical Review rows compare only with earlier evidence.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `02_train_top.png` — Train tab, practice mode picker.
- `03_review_top.png` — Review tab, one-rep evidence state.
- `04_profile_top.png` — Profile tab, one-rep coaching state.
- `05_settings_top.png` — Settings tab, top of view.

## VISION gap
Summary, evaluator, Profile, and Review now avoid treating unequal-length raw filler counts as progress or regression. The light sweep verifies the fresh build launches and the five tab tops remain coherent, but it does not exercise an after-rep Summary with two qualified priors. That exact visual state still needs a deterministic seeded Summary capture before its `/min` badge, warning color, and VoiceOver output are visually/accessibility proven on-device.

## Next steps to reach desired state
1. Extend `NoumUITests/ScreenshotTour.swift` with a deterministic qualified-history Summary fixture covering improving, steady, worsening, and insufficient-evidence filler states.
2. Normalize direct filler-question evidence in `Noum/CoachContextBuilder.swift`, then rerun its exact prompt/corpus tests because those strings are evaluation-bound.
3. Obtain the five external production-readiness artifacts; local tests and simulator screenshots cannot substitute for them.

## Regressions checked
- Home top — `01_home_top.png` — expected one-rep light-evidence state; no blank, crash, or navigation regression.
- Train top — `02_train_top.png` — recommendation and practice library render; no regression observed.
- Review top — `03_review_top.png` — one-rep evidence language remains appropriately tentative; no regression observed.
- Profile top — `04_profile_top.png` — latest-rep coaching state renders without layout regression.
- Settings top — `05_settings_top.png` — controls and tab chrome render without regression.

## Surfaces needing visual verification (cloud → local queue)
- Qualified-history Summary hero and expanded comparison row, including fillers/minute delta formatting.
- Summary VoiceOver output for insufficient, improving, steady, and worsening evidence.
- Historical Review detail with two earlier qualified reps and a newer rep present.

## For next run
- **If cloud**: audit and implement the corpus-tested `CoachContextBuilder` filler-question normalization without claiming external readiness.
- **If local**: add and capture the deterministic Summary fixture, then inspect the `/min` badge at standard and accessibility text sizes.
