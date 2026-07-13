# Run: 2026-07-14 · branch:ux-overhaul · HEAD 936b32aa · active-week Phrase Bank execution

## Mode

light

## Changes shipped (this run)

- `Noum/HomeCoachCard.swift` — the restrained cohesive Home still hides the generic plan arc, but now mounts one valid explicitly assigned current-week phrase action.
- `Noum/DevSeedData.swift` + `Noum/NoumApp.swift` — a DEBUG-only fixture writes through the real account-scoped Phrase Bank and Forward Plan owners after hydration.
- `Noum/TimedPracticeView.swift` + `NoumUITests/GoalOutcomeLoopUITests.swift` — stable rendered prompt observation and exact Home-to-Timed UI coverage.

## Screenshots

- `01_home_top.png` — Home tab, populated immersive state; no layout regression at the top of the restrained Home.
- `01_train_top.png` — Train tab and coherent Timed recommendation.
- `01_review_top.png` — Review tab and recent evidence hierarchy.
- `01_profile_top.png` — Profile tab and coaching evidence hierarchy.
- `01_settings_top.png` — Settings tab and practice controls.
- `active-week-phrase-timed-prompt.png` — retained passing UI-test attachment showing the exact saved line in Timed's thinking phase.

## VISION gap

The saved rewrite now becomes a visible weekly action and exact practice prompt without another state owner, reinforcing personalized coaching and replay motivation. This local rendered path still does not prove that users improve, that a professional coach agrees with the intervention, or that account persistence behaves correctly on physical/TestFlight devices.

## Next steps to reach desired state

1. Add rendered Prep unavailable-mode fallback coverage around `Noum/PrepSessionView.swift` without weakening its planned-mode readiness identity.
2. Collect the required physical-device/TestFlight release run and attachment-backed external evidence described in `docs/PRODUCTION_EVIDENCE_COLLECTION.md`.

## Regressions checked

- Home top — `01_home_top.png` — immersive hierarchy and Ask Noum row remain coherent.
- Five-tab shell — `01_*.png` — all expected top-level destinations rendered.
- Exact phrase delivery — `active-week-phrase-timed-prompt.png` — saved line rendered intact in the focused Timed phase.

## Surfaces needing visual verification (cloud → local queue)

- The assigned phrase row itself below the immersive Home fold on a physical device.
- Physical-device Dynamic Type, VoiceOver, reduced motion, and account relaunch persistence.

## For next run

- **If cloud**: audit remaining external-evidence provenance and Prep fallback assertions without claiming device proof.
- **If local**: capture the assigned Home phrase row and the Prep locked-mode fallback on a physical/TestFlight build.
