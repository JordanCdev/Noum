# Run: 2026-07-13 · branch:ux-overhaul · HEAD 62833410 · research-loop production closure

## Mode

light

## Changes shipped (this run)

- `Noum/NextActionEngine.swift:63` — projects the finalizer-owned decision into the Summary's single drill or full-rep action.
- `Noum/SessionHistoryView.swift:471` — makes historical launches replay-only and removes adaptive-acceptance semantics.
- `Noum/PhrasePracticeIntent.swift:7` and `Noum/SummaryView.swift:1216` — turn a sanitized saved phrase into the existing one-shot Timed prompt handoff.
- `Noum/AIRewriteService.swift:120` — blocks unsupported locales before English rewrite heuristics, provider resolution, or transport.
- `tools/coach-arena/runners/readiness_gate.py:163` — requires the cohort-truthful v3 longitudinal evidence contract.

## Screenshots

- `01_home_top.png` — Home tab, active stakeholder-review plan.
- `01_train_top.png` — Train tab and recommended Filler Control rep.
- `01_review_top.png` — Review tab, recent movement and saved-rep entry.
- `01_profile_top.png` — Profile tab, evidence-bounded rating and coaching focus.
- `01_settings_top.png` — Settings tab, practice controls and language entry.
- `focus_rewrite_card.png` — on-device rewrite, intensity, save, and Phrase Bank affordances; the single Summary prescription is visible immediately above it.
- `focus_phrase_bank_practice.png` — saved phrase row with the new restrained `Practice phrase` action.
- `focus_goal_follow_up.png` — completed prescribed rep and evidence-only goal movement with no competing goal CTA.

## VISION gap

The five primary tabs remain cohesive and readable, and focused UI-test captures now prove the practiceable Phrase Bank row plus the evidence-only goal follow-up. The prescribed Summary launch also completed end to end, although the focused attachment shows only the lower edge of its card. Historical-detail replay still lacks a dedicated capture. VISION production readiness remains gated on a healthy live-provider sweep, professional calibration, a preregistered real-user cohort, physical TestFlight QA, and operational launch evidence.

## Next steps to reach desired state

1. Capture full drill/full-rep Summary variants and historical detail through focused UI-test attachments or extend `NoumUITests/ScreenshotTour.swift` with those surfaces.
2. Run the physical-device TestFlight matrix in `docs/PRODUCTION_READINESS_RUNBOOK.md`.
3. Collect the registered cohort artifact `coach-real-user-transfer-outcomes-v3.json` without omitting mixed, regressed, or adverse rows.

## Regressions checked

- Integrated focused unit/integration run — 155/155 tests passed across 10 suites.
- Readiness runner — 95/95 Python tests passed.
- End-to-end loops — 3/3 UI tests passed for prescribed follow-up, Phrase Bank practice, and first verdict.
- Release configuration — simulator build completed successfully.
- Canonical evidence refresh — current source passed local app-path, score/coverage, real-pipeline, trace-quality, and source-freshness gates after resetting the dedicated evidence simulator; launch readiness remains correctly NO-GO at 18/100.
- Home top — `01_home_top.png` — plan hero and tab shell render without launch regression.
- Train top — `01_train_top.png` — recommended rep remains clear and singular.
- Review top — `01_review_top.png` — movement card and history entry render without duplicate action noise.
- Profile top — `01_profile_top.png` — evidence and focus hierarchy remains legible.
- Settings top — `01_settings_top.png` — locale and practice controls render normally.
- Phrase Bank practice — `focus_phrase_bank_practice.png` — action is visually restrained, readable, and separated from swipe-delete semantics.
- Goal follow-up — `focus_goal_follow_up.png` — milestone evidence remains qualitative and contains no second prescription CTA.

## Surfaces needing visual verification (cloud → local queue)

- Full-frame finalized full-rep and drill variants of `SummaryPrescriptionActionCard`.
- Historical session detail `Repeat this rep` action, including IM setup replay.
- Reduce Motion behavior for the changed Summary action surface.

## For next run

- **If cloud**: extend deterministic UI coverage and audit accessibility identifiers without claiming visual proof.
- **If local**: capture full Summary variants and historical replay, then run the physical TestFlight checklist.
