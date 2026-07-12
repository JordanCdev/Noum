# Run: 2026-07-12 · branch:ux-overhaul · HEAD b9258cb7 · M26 credible goal-outcome loop

## Mode
light

## Changes shipped (this run)
- `Noum/GoalRubric.swift` — qualitative outcome/evidence/movement projection.
- `Noum/GoalRubricStore.swift` — explicit normalized rubric for every speaking style.
- `Noum/GoalOutcomeCard.swift` — shared Summary, Review, and Profile outcome surface.
- `Noum/PracticeSupport.swift` — optional goal intervention metadata and bounded follow-up result.
- `LocalSpeechProvider.swift` — consent-safe on-device transcription and pre-stream cloud fallback.
- `Noum/FlowObservability.swift` — account-scoped transformation KPI derivation and bounded lifecycle events.
- `ProfileView.swift` — one-time three-rep qualitative outcome question with 44-point controls.
- `Noum/PracticeSupport.swift` — deferred profile capture now starts at durable session finalization, independent of Summary presentation.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab.
- `01_review_top.png` — Review tab.
- `01_profile_top.png` — Profile tab.
- `01_settings_top.png` — Settings tab.
- `02_summary_follow_up.png` — completed prescribed Timed rep showing the bounded early-improvement follow-up read.

## VISION gap
The visible outcome loop now names evidence strength and a next target without a false 0–100 identity score. Profile also captures whether users feel movement after three reps without introducing third-party analytics. Real-world validation and reliable prosody/breathing/emphasis sensing remain outside this milestone.

## Next steps to reach desired state
1. Capture Summary, session-detail, and lower Profile outcome cards with seeded M26-specific UI states.
2. Run the auto-guided first-rep matrix on a signed physical device before enabling its default-off release flag.
3. Validate on-device speech accuracy and airplane-mode completion on supported locales.

## Regressions checked
- Five tab tops — refreshed light screenshots — expected destinations rendered with no blank or crash state; Home correctly shows the first-rep welcome on erased state.
- Goal/offline/activation/KPI focused suites — passed, including account export/deletion inventory and bounded-ring pressure.
- Full unit suite — 3,689 tests in 391 suites passed.
- First-run UI proofs — erased-simulator cloud decline, provider failure recovery, interruption/relaunch persistence, injected first-verdict loop, and deferred profile capture passed.
- Transformation question UI proof — one-shot behavior and 44-point controls passed.
- Full goal loop UI proof — Summary prescription → Timed rep → persisted outcome → returned early-improvement read passed after the final disclosure/deferred-capture changes; the Summary disclosure target was raised from 26 to 44 points.
- Final Release simulator build — succeeded.

## Surfaces needing visual verification
- Historical session-detail goal outcome card on a physical device.
- Dynamic Type, VoiceOver order, and reduced-motion behavior on the new card.
- Auto-guided first rep on physical device.

## For next run
- **If cloud**: extend deterministic outcome and Codable regression coverage.
- **If local**: capture seeded Summary/session-detail/Profile outcome cards and complete the signed-device permission/consent/interruption matrix.
