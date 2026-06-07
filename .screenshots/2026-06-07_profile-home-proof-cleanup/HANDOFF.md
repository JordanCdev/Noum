# Run: 2026-06-07 · branch:ux-overhaul · HEAD 8196894 · Profile/Home proof cleanup

## Mode Used

light

Both screenshot mode files were temporarily switched from `off` to `light` for this pass, then restored to `off` after capture:

- `.agents/skills/noum-screenshots/.mode`
- `.claude/skills/noum-screenshots/.mode`

## Changes Shipped This Run

- `ProfileView.swift` — current baseline already contains the Figma-directed Profile proof layout: Growth Library first, History second, no default Evidence header, and supporting evidence demoted.
- `Noum/ContentView.swift` — removed retired Home dashboard card builders and the older parallel Home recommendation fallback they kept alive.
- `Noum/ContentView.swift` — Home recommendation telemetry now falls back to the shared `RecommendationBiasContextBuilder` blueprint instead of a second handcrafted heuristic.
- `Noum/SessionHistoryView.swift` — Review now renders at most one `Worth a replay` surface, chosen by a single `SessionHistoryReviewSurface` selector.
- `Noum/SessionHistoryView.swift` — the Review log keeps the first three session rows first, then inserts the selected replay surface above the fold before the remaining archive rows.
- `NoumTests/NoumTests.swift` — added selector tests for no-signal, targeted-practice fallback, and recent-rep priority.

## Screenshots

- `01_home_top.png`
- `02_train_top.png`
- `03_review_top.png` — before the Review insertion patch.
- `04_profile_top.png`
- `05_settings_top.png`
- `06_review_after_worth_replay.png` — after the Review insertion patch.
- `07_train_after_compact_pills.png`, `08_train_after_content_width_pills.png`, `09_train_final_compact_pills.png` — exploratory Train compact-pill attempts. The code was backed out because the screenshot proved no meaningful viewport improvement at this size.

## VISION Gap

The app is closer to the proposed Figma direction: Home is now strongly aligned with the "one coach, one move" mockup, Profile leads with identity/rating/coach proof instead of a dashboard, and Review now surfaces a concrete replay prompt before the user falls into the full archive. Remaining gaps: Train still has a bulky single card with a large empty lower viewport, Settings is still dense, and this pass only captured the current seeded state rather than cold/beginner/returning variants.

## Next Steps To Reach Desired State

1. Capture cold, beginner, and returning seeded states so the Home/Profile gating claims are proven across evidence depth.
2. Review Ask Noum empty/live states for read-evidence-move shape and weak-evidence copy.
3. Continue Iteration 5 by checking whether the Practice picker still over-explains alternate modes after the Coach Pick hero.
4. Tighten Train's first viewport: keep the Coach Pick hero, but reduce dead space and make the next value/proof visible sooner.

## Regressions Checked

- `NoumTests/HomeSignalGateTests` — passed.
- `NoumTests/HomeSignalGateEdgeTests` — passed.
- `NoumTests/ProfileCollapseContractTests` — passed.
- `NoumUITests/NoumUITests/testHomeScreenAndPrimaryNavigation` — passed.
- `NoumTests/SessionHistoryRowPreviewTests` — passed after Review selector/list-flow patch.
- `NoumTests/ReviewSurfaceCopyTests` — passed after Review selector/list-flow patch.
- `NoumTests/PracticeModeRowExpansionTests` — passed during the Train compacting experiment, which was subsequently backed out after screenshots showed no real visual win.
- `git diff --check` — still needs rerun after the latest Review patch and handoff update.

## Surfaces Needing Visual Verification

- Home top: coach hero, compact Path row, no retired dashboard card creep.
- Profile top/mid: proof-first rows, History row, supporting evidence disclosure weight.
- Practice picker: Coach Pick hero and "Other ways to practice" disclosure.
- Ask Noum: empty state, live/typed first reply, weak-evidence wording.
- Seeded state matrix: cold 0-rep, beginner, improving, plateaued.

## For Next Run

- If local: run the detailed screenshot tour or seeded-state sweep next.
- If cloud: continue code-level Ask/Profile/Practice tightening without claiming multi-state visual approval.
