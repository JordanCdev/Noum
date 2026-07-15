# Run: 2026-07-15 · branch:ux-overhaul · HEAD 8e7af9d9 · Pace completion integrity

## Mode

light

## Changes shipped (this run)

- `Noum/PaceTrainingEngine.swift` — adds one pure completion disposition that combines the established terminal recording gate with the shared three-word / three-finite-second progress floor while preserving the live sampled result.
- `Noum/PaceTrainingView.swift` — awaits terminal finalization before result/XP, awards eligible XP once, returns thin speech to setup with restrained retry guidance, and retains the recognizer error path for unusable capture.
- `NoumTests/PaceTrainingCompletionIntegrityTests.swift` — covers boundary, terminal-transcript ownership, exact eligible result/XP, unusable receipts, and source ordering.
- `NoumUITests/HomePracticePathPolishUITests.swift` — renders insufficient and eligible terminal fixtures, including Accessibility XXXL, no-result/no-XP, and accessible exit-action checks.

## Screenshots

- `01_home_top.png` — Home tab, top of view
- `01_train_top.png` — Train tab, top of view
- `01_review_top.png` — Review tab, top of view
- `01_profile_top.png` — Profile tab, top of view
- `01_settings_top.png` — Settings tab, top of view
- `pace_eligible_result.png` — existing earned Pace result with exact +40 XP and visible Go Again / Done actions
- `pace_insufficient_speech_axxxl.png` — thin-speech retry state at Accessibility XXXL with no result or XP

## VISION gap

The touched boundary now protects believable progress: a one- or two-word
fragment cannot become a scored Pace run, while eligible live samples are not
rewritten from late provider text. This does not make standalone Pace part of
the observe/adapt loop. It still has no durable `PracticeSession`, drill,
recommendation-outcome, or comparable-response attribution, and simulator
fixtures cannot prove microphone/provider timing or coaching effectiveness.

## Next steps to reach desired state

1. Define and approve a durable standalone Pace attribution contract, including backend schema and mixed-client compatibility, before routing adaptive prescriptions there.
2. Run real microphone completion on a signed physical TestFlight build, including terminal-provider delay, interruption, VoiceOver, and Reduce Motion evidence.
3. Obtain the five required external artifacts; local simulator work cannot raise the production gate.

## Regressions checked

- Pace engine, existing result scoring, and new completion integrity — 34/34 tests across three suites.
- Insufficient terminal evidence — rendered UI pass at Accessibility XXXL; no result or XP and retry remains accessible.
- Eligible terminal evidence — rendered UI pass; exact +40 result and both exit actions accessible.
- Home, Train, Review, Profile, and Settings deep links — five light-sweep frames — no launch, route, or top-level layout regression.
- Complete unit target was not rerun at `8e7af9d9`; the latest complete target remains 4,188 unique tests / 4,205 device executions at `5987636f`.

## Surfaces needing visual verification (cloud → local queue)

- Signed physical-device microphone finalization, late provider receipt, interruption/retry, VoiceOver announcement order, and Reduce Motion remain unverified.

## For next run

- **If cloud**: freshly re-rank remaining local requirements; do not infer that standalone Pace routing is authorized.
- **If local**: prioritize authorized physical TestFlight evidence or a product/schema decision for Pace attribution; do not count simulator fixtures as production proof.
