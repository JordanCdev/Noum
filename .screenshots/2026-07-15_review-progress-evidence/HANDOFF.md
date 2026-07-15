# Run: 2026-07-15 · branch:ux-overhaul · HEAD cb5f0327 · Review progress-evidence integrity

## Mode

light

## Changes shipped (this run)

- `Noum/ReviewHighlightsEngine.swift:52` — highlight evidence and every direct selector reject Review-only captures.
- `Noum/ReviewInsightCards.swift:185` — story depth and latest-rep navigation use progress-eligible history.
- `Noum/ProgressionCharts.swift:19` — one pure 30-day scored-session projection owns the chart threshold.
- `Noum/SessionHistoryView.swift:160` — raw history stays visible while evidence-bearing Review surfaces use the eligible projection.

## Screenshots

- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, recommended rep and library.
- `01_review_top.png` — Review tab, valid seeded story/highlights and collapsed progress disclosure.
- `01_profile_top.png` — Profile tab, coaching focus and reality check.
- `01_settings_top.png` — Settings tab, top of Practice section.

## VISION gap

Review now preserves the desired believable-progress boundary in local logic: weak saved evidence remains inspectable but cannot strengthen story, highlight, or chart claims. The light sweep contains seven valid seeded reps, so it verifies the ordinary Review shell only; it does not visually prove the mixed invalid-history branch or real-user coaching accuracy.

## Next steps to reach desired state

1. Add or reuse a deterministic rendered mixed-history fixture in `NoumUITests` so two eligible rows plus Review-only rows visibly retain the forming chart state and eligible latest-rep target.
2. Correct terminal Roleplay guidance in `Noum/RoleplayView.swift` so the fourth-turn completion cannot promise an unavailable next attempt.
3. Collect the five required external artifacts before changing the production-readiness verdict.

## Regressions checked

- Five-tab top-level navigation — all five screenshots — expected tab selected and content rendered.
- Review valid-evidence shell — `01_review_top.png` — story, highlights, All reps, and progress disclosure remain composed without a blank chart region.
- Profile evidence shell — `01_profile_top.png` — existing progress-eligibility composition remains intact.

## Surfaces needing visual verification (cloud → local queue)

- Review with only Review-only rows: no story/highlights and honest forming progress state.
- Review with two eligible scored rows plus newer Review-only rows: eligible latest-rep navigation and forming chart state.
- Expanded chart with three eligible scored rows plus Review-only saved history.

## For next run

- **If cloud**: audit the terminal Roleplay guidance state and its pure presentation seam without claiming rendered proof.
- **If local**: add the mixed-history Review UI fixture and capture story/latest-rep/forming-chart states.
