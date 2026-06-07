# Run: 2026-06-07 · branch:ux-overhaul · HEAD 661290b · Train picker prescription-line pass

## Mode
`off` (read from `.agents/skills/noum-screenshots/.mode` and `.claude/skills/noum-screenshots/.mode`)

Screenshots were skipped because the project screenshot mode is currently off. Do not infer final visual quality from this handoff alone; run a light capture next time screenshot mode is enabled.

## Changes Shipped (This Run)
- `Noum/PracticeModeSelectionView.swift` — collapsed the recommended rep's Target + Focus evidence from two stacked pills into one compact prescription line.
- `Noum/PracticeModeSelectionView.swift` — reduced the Coach Pick hero's visual weight: tighter spacing, smaller reason copy, tighter padding, lighter shadow.
- `NoumTests/NoumTests.swift` — added tests for the prescription-line helper, including empty and duplicate signal suppression.

## Screenshots
- None captured in this run because screenshot mode is `off`.
- Previous relevant baseline: `.screenshots/2026-06-07_profile-home-proof-cleanup/09_train_final_compact_pills.png`, where the Train hero still showed stacked Target/Focus pills and left a large dead lower viewport.

## VISION Gap
The Train picker is now closer to Iteration 5: one recommended rep, one Begin action, one visible escape. It still is not the full curriculum-spine redesign: Lessons, Speech Projects, drill catalog demotion, and pace-threshold reconciliation remain future work.

## Next Steps To Reach Desired State
1. Capture `noum://train` after enabling screenshot mode and compare against `09_train_final_compact_pills.png`.
2. Continue Iteration 5 by moving Lessons/Speech Projects out of the default rep-picker path and behind a quieter skill-training entry.
3. Reconcile the duplicated pace thresholds before expanding Pace Training copy further.

## Regressions Checked
- Focused Xcode tests passed: `PracticeModeRowExpansionTests` and `PracticeModePrescriptionCopyTests`.
- Build compiled through `PracticeModeSelectionView.swift`; routing code was intentionally left untouched.

## Surfaces Needing Visual Verification
- Train top after the compact prescription line.
- Expanded "Other ways to practice" state after the hero spacing change.

## For Next Run
- If cloud: continue with logic/testable work; do not attempt simulator screenshots.
- If local: enable light screenshots or manually capture Train top before making the next picker/Profile pass.
