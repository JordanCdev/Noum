# Run: 2026-07-15 · branch:ux-overhaul · HEAD 8ec313c9 · Profile progress evidence excludes Review-only captures

## Mode
light

## Changes shipped (this run)
- `ProfileView.swift:1397` — preserves raw saved-session history while introducing the canonical progress-eligible Profile projection.
- `ProfileView.swift:1492` — routes coaching, readiness, transformation, goal, plan, retention, session-count, and filler evidence through eligible sessions.
- `NoumTests/PathUnlockCelebrationIntegrityTests.swift:83` — proves invalid saved rows leave Profile evidence cold.
- `NoumTests/PathUnlockCelebrationIntegrityTests.swift:317` — pins raw History and eligible coaching to separate owners.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, practice library top.
- `01_review_top.png` — Review tab, seeded story/highlights and All Reps.
- `01_profile_top.png` — Profile tab, seeded Coach Read and transformation prompt.
- `01_settings_top.png` — Settings tab, practice controls.

## VISION gap
Profile now respects the research boundary that weak evidence must not strengthen coaching certainty, while Review-only rows remain inspectable. The light seed contains eligible history, so these frames prove only top-level rendering. They do not prove a mixed eligible/Review-only account, the hidden transformation-question branch, filler evidence exclusion, or physical-device behavior. Review's own story/highlight/chart projections still consume raw history at this source boundary and can overstate longitudinal evidence.

## Next steps to reach desired state
1. Filter `Noum/ReviewHighlightsEngine.swift` and `Noum/ReviewInsightCards.swift` defensively through `PracticeProgressEligibility` while retaining raw rows in `Noum/SessionHistoryView.swift`.
2. Align `SessionHistoryView`'s development-chart gate with the eligible points already required by `Noum/ProgressionCharts.swift`.
3. Add a deterministic mixed-history rendered fixture before claiming visual proof of the Profile boundary.

## Regressions checked
- Home top — `01_home_top.png` — rendered; no launch or shell regression.
- Train top — `01_train_top.png` — rendered; no recommendation-card or library regression.
- Review top — `01_review_top.png` — rendered; exposes the next raw longitudinal-projection gap rather than proving it closed.
- Profile top — `01_profile_top.png` — rendered; Coach Read, transformation prompt, and Library remain visually coherent for eligible seeded data.
- Settings top — `01_settings_top.png` — rendered; no top-level layout regression.

## Surfaces needing visual verification (cloud → local queue)
- Profile with four saved Review-only rows and zero eligible rows.
- Profile with mixed raw/eligible history: raw All Reps count preserved, evidence caption/count eligible-only.
- Review story/highlights/chart after the same mixed-history boundary is implemented.
- VoiceOver, Reduce Motion, and physical TestFlight behavior.

## For next run
- **If cloud**: implement and test the pure Review story/highlight/chart eligibility boundary without creating UI-only fixture state.
- **If local**: add or use a deterministic mixed-history seed and capture Profile plus Review before/after states.
