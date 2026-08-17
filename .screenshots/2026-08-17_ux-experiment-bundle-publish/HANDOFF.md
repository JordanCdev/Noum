# Run: 2026-08-17 · branch:ux-experiment · HEAD 59b0a47cd · publish the bundled V3 UX experiment with honest native evidence

## Mode
light

## Changes shipped (this run)
- `Noum/FastLaneOnboardingView.swift:230` — keep choice presentation in scope for the button's accessibility metadata.
- `Noum/PracticeModeSelectionView.swift:1155` — mark the stored `ViewBuilder` content closure as escaping.
- `Noum/SummaryView.swift:1372` — keep the animated dismissal action `Void`-returning.
- `Noum/TimedPracticeView.swift:4701` and `Noum/TranscriptPracticeLoop.swift:1550` — remove preview-only writes to the read-only Reduce Motion environment value.
- `Noum/TranscriptPracticeLoop.swift:1379` — return the comparison rung's opaque view explicitly.
- `NoumTests/V3OnboardingShellTests.swift:3` — import the app module so the bundled tests compile.
- `docs/UX_EXPERIMENT_V3_HANDOFF.md:225` and `docs/CURRENT_STATE.md:50` — record the Mac-native build result and the still-red unit gate.

## Screenshots
- `01_home_top.png` — Today tab, one-rep mission and coach recommendation.
- `01_train_top.png` — Practice tab, recommendation-first mode picker.
- `01_review_top.png` — Progress tab, honest first-rep empty state.
- `01_profile_top.png` — You/Profile tab, current coach read and coaching library.
- `01_settings_top.png` — Settings destination within the You tab.

All five PNGs were opened and visually inspected. Each deep link reached the expected destination; no capture was blank, stuck on launch, or showing a crash.

## VISION gap
The top-level surfaces now read as one calm coaching system with a single recommendation and restrained semantic graphics, matching `docs/VISION.md`. The Profile capture exposes a product-truth mismatch: it says **No verified reps yet** while the coach-read card ends with **Based on your latest rep.** That attribution should fail closed until a qualifying rep exists. The light sweep also does not prove dark mode, Accessibility XXXL, Reduce Motion, or the in-rep and earned-proof states.

## Next steps to reach desired state
1. Repair the no-evidence Profile attribution in `ProfileView.swift` using the existing evidence owner; do not manufacture a latest-rep claim.
2. Resolve the 24 failing `NoumTests` contracts recorded in `docs/UX_EXPERIMENT_V3_HANDOFF.md` and rerun the full serialized target.
3. Run a clean Release build and the required detailed accessibility, speech, reward, and interruption passes on the same source commit.

## Regressions checked
- Today deep link — `01_home_top.png` — mission, accepted target, primary rep action, and Today selection render coherently.
- Practice deep link — `01_train_top.png` — recommendation, progressive catalogue, and Practice selection render coherently.
- Progress deep link — `01_review_top.png` — empty state and Progress selection render; no fake progress is shown.
- Profile deep link — `01_profile_top.png` — destination and library render, with the latest-rep attribution mismatch noted above.
- Settings deep link — `01_settings_top.png` — privacy/practice controls render within the You navigation context.

## Surfaces needing visual verification (cloud → local queue)
- Dark mode, Accessibility XXXL, Reduce Motion, VoiceOver, and compact-device layouts.
- Spoken-rep recording, processing, Summary, verified reward, permission recovery, and interruption/background states.
- Populated Progress and Profile states with real source-bound evidence.

## For next run
- **If cloud**: classify and repair the 24 deterministic unit failures without weakening coach reliability or evidence gates.
- **If local**: rerun the serialized unit suite, then use detailed screenshot mode for the repaired commit and complete the physical speech/accessibility pass.
