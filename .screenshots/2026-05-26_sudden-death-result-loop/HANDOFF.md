# Run: 2026-05-26 | branch:Redesign | HEAD 9295edb | Sudden Death result loop correction

## Mode
off

## Changes shipped (this run)
- `Noum/PressureTimerEngine.swift:195` - centralised completed-tier totals so an immediate filler-ending tier records its triggering filler, words, and duration once.
- `Noum/SuddenDeathPracticeView.swift:404` - removed the manual difficulty selection surface; new plays use the existing automatic pressure ramp.
- `Noum/SuddenDeathResultView.swift:45` - replaced rating/filler tiles with tier, survival time, and best; bounded the run path; switched the result icon to a neutral game marker.
- `Noum/SuddenDeathRecentRunsCard.swift:43` - removed redundant filler counts and `/10` ratings from recent attempts.
- `Noum/SuddenDeathHistoryExport.swift:86` - aligned shared run history to tier/cleared/outcome rather than rating columns.
- `NoumTests/NoumTests.swift:1671` - added round-total contract tests and a game-facing history-export contract test.

## Screenshots
- None captured. Screenshot mode is `off`.

## VISION Gap
This pass moves Sudden Death toward fair pressure training and believable progress: its game loop now exposes actual survival and best-run evidence, while detailed coaching stays in Summary. It does not yet provide a validated game points model or a measured word-choice/structure bonus; those must be based on real communication signals rather than decorative multipliers.

## Next Steps To Reach Desired State
1. Define a transparent Sudden Death points contract backed by measured signals such as time survived, tiers cleared, structure, and deliberate wording in `Noum/PressureTimerEngine.swift`.
2. Decide whether historical Easy/Medium/Hard runs should migrate into a single automatic-progression record in `Noum/SuddenDeathRunHistoryStore.swift` and `Noum/SuddenDeathHighScoreStore.swift`.
3. Add a deterministic result-screen UI-test entry point so long-tier layouts and the filler-ending result can be screenshot verified.

## Regressions Checked
- `git diff --check` - passed.
- Focused `xcodebuild test` reached app compilation and exposed one new SwiftUI return error; that error was corrected in `SuddenDeathResultView.swift`.
- The post-fix test rerun could not execute because the Codex usage allowance expired while requesting simulator access.

## Surfaces Needing Visual Verification
- Sudden Death setup screen without the difficulty selector.
- Sudden Death result after a filler-ending first tier.
- Sudden Death result after a long run with collapsed earlier tiers and recent attempts visible.

## For Next Run
- **If cloud**: run static review and extend pure scoring/history tests without simulator work.
- **If local**: set screenshot mode to `light` or `detailed`, rerun the focused simulator tests, and capture the redesigned Sudden Death result states.
