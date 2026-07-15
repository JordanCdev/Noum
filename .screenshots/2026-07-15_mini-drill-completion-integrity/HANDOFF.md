# Run: 2026-07-15 · branch:ux-overhaul · HEAD 3969c817 · require terminal speech before mini-drill progress

## Mode

light

## Changes shipped (this run)

- `Noum/DrillSystem.swift` — added one pure terminal/quantity disposition for mini-drills and a truthful 28-word PREP evaluation.
- `Noum/MiniDrillView.swift` — standard/framework drills now withhold outcomes for thin speech and retry from Ready.
- `BeatTheBrakeView.swift`, `LandThePauseView.swift`, `PREPStackView.swift` — replaced fire-and-forget capture, wall-clock duration substitution, and fixed completion delays with awaited readiness/finalization while preserving live metric ownership.
- `Noum/SummaryView.swift` — revalidates outcome quantity and deduplicates outcome IDs before history, XP, rewards, or baseline writes.
- `Noum/MiniDrillResultView.swift` — resolves the staged entrance immediately when Reduce Motion is enabled.
- `NoumTests/SpeechSessionIntegrityTests.swift` — covers receipt/quantity boundaries, all four routed lifecycles, PREP 27/28 words, and Summary reward ordering.
- `docs/CURRENT_STATE.md`, `docs/DEVELOPMENT_PLAN.md`, `docs/RESEARCH_IMPLEMENTATION_AUDIT.md` — correct the earlier generic-only mini-drill claim and retain the external NO-GO.

## Screenshots

- `01_home_top.png` — seeded Home tab, top of view
- `01_train_top.png` — seeded Train tab and recommended-rep card
- `01_review_top.png` — seeded Review tab and progress story
- `01_profile_top.png` — seeded Profile tab and coaching focus
- `01_settings_top.png` — seeded Settings tab

The first unseeded capture attempt correctly exposed an account/bootstrap error
and was discarded. The retained frames were relaunched with the established
deterministic UI seed and visually inspected. No frame forces the changed
mini-drill completion branches.

## VISION gap

Noum now refuses to turn interim, unusable, or materially thin speech into a
mini-drill reward, which strengthens believable progress and coaching trust.
The simulator still does not prove provider timing, microphone interruptions,
historical invalid drill-history provenance, professional calibration, or
longitudinal communication benefit. The current production verdict remains
NO-GO at 18/100 with 0/5 external artifacts.

## Next steps to reach desired state

1. Add deterministic rendered fixtures for insufficient and eligible mini-drill completion, including Accessibility XXXL and Reduce Motion.
2. Run microphone interruption/finalization cases on a signed physical device or TestFlight build.
3. Decide whether pre-integrity `DrillHistoryStore` rows require a conservative migration; the current schema cannot distinguish historical thin speech.
4. Collect the five independently sourced external readiness artifacts rather than awarding local work release points.

## Regressions checked

- Home top — `01_home_top.png` — seeded shell renders without regression.
- Train top — `01_train_top.png` — recommendation and practice-library hierarchy remain readable.
- Review top — `01_review_top.png` — recent movement and saved-history entry remain coherent.
- Profile top — `01_profile_top.png` — rating, coaching focus, and reflection remain readable.
- Settings top — `01_settings_top.png` — practice controls remain readable and reachable.
- Mini-drill terminal integrity — 28/28 focused unit/source-contract tests pass.
- Complete unsigned simulator unit target — 4,183 tests across 426 suites pass with zero failures.

## Surfaces needing visual verification (cloud → local queue)

- Standard/framework insufficient-speech Ready state.
- Beat the Brake insufficient-speech Ready state and eligible result.
- Land the Pause insufficient-speech Ready state and eligible result.
- PREP Stack 27-word incomplete result versus 28-word success.

## For next run

- **If cloud**: audit the historical drill-history migration decision and extend pure/source contracts only.
- **If local**: add and capture deterministic insufficient/eligible mini-drill UI fixtures before claiming rendered completion coverage.
