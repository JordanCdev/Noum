# Routine 2 — Refactor backlog grinder (Run 2, 13:00 daily)

## Slot
Run 2, 13:00 local time.

## Purpose
Grind one item per day from the known refactor backlog. Highest-value target: `Noum/Noum/PracticeSupport.swift` is 7800+ lines (named technical debt in `docs/CURRENT_STATE.md`). Extract one manager/struct per day into its own file.

## Prompt

```
You're a focused refactor agent. Pick ONE refactor target per run, ship it on a branch, commit, push. Don't try to refactor everything.

You're running on Linux. No iOS Simulator. No `xcodebuild` for verification — your changes must be Swift-correct by reading, not by compiling. Be conservative: extractions over rewrites, mechanical moves over re-architectures.

## Required reading (every run, in order)

1. `CLAUDE.md`
2. `docs/CURRENT_STATE.md` — especially the "Known issues / debt" and "Conventions to preserve" sections
3. `docs/VISION.md` anti-goals
4. The current `PracticeSupport.swift` table of contents (`grep -n "^// MARK:\\|^extension\\|^final class\\|^struct \\|^enum " Noum/Noum/PracticeSupport.swift`) to pick the next extraction target
5. The most recent `.routines/02_*_HANDOFF.md` from cloud — what was extracted last time

## Today's target — pick this way

1. Run `git log --oneline Noum/Noum/PracticeSupport.swift | head -20` to see recent activity. If anything was extracted in the last 7 days, pick a different chunk (don't fight your past-self).
2. Look for the lowest-risk extractable unit:
   - A standalone `final class FooManager: ObservableObject` with no fileprivate dependencies on other types in the file → highest priority
   - A `struct Foo` data model that's referenced from many call sites → also good
   - Avoid: anything `fileprivate` (would need careful API surface design), anything in a tight extension chain (would need follow-up file edits)
3. The chosen extraction must compile (Swift syntactically + with imports) without any other file changes.

## What to do

1. Create new file `Noum/Noum/<ExtractedThing>.swift` with:
   - Identical file header style to existing Noum files (`//  <Name>.swift\n//  Noum\n//`)
   - The extracted class/struct/enum + any `fileprivate` helpers it uniquely uses
   - Required imports (Foundation, SwiftUI as needed)
   - A one-sentence comment noting WHY this was extracted (file size pressure)
2. Delete the original lines from `PracticeSupport.swift`.
3. Re-run `wc -l Noum/Noum/PracticeSupport.swift` — note before/after in the HANDOFF.
4. Update `docs/CURRENT_STATE.md` if `PracticeSupport.swift` is referenced as a 7800-line file — adjust the number.
5. Commit on branch `cloud/refactor-extract-<name>-<YYYY-MM-DD>`. Push.

## Brand + engineering rules

- The extraction must preserve every existing convention: singleton pattern (`final class X: ObservableObject` + `static let shared`), per-account UserDefaults, ObservableObject + @Published, no @Observable migration.
- Never change behavior. This is a pure mechanical move.
- If you can't extract anything cleanly, the HANDOFF says so — and proposes a follow-up refactor that COULD enable extraction next week.

## Write HANDOFF.md at `.screenshots/<YYYY-MM-DD>_refactor-grinder/HANDOFF.md`

Sections required:
- What was extracted (name + old line count → new file line count)
- `PracticeSupport.swift` line count before/after
- Surfaces needing visual verification (extraction is read-equivalent, but flag every screen that depends on the extracted type so a local session can re-screenshot to confirm no regression)
- Branch name + commit SHA

## Don't
- Don't add features.
- Don't rewrite logic.
- Don't open PRs.
- Don't extract anything with non-trivial dependencies on `fileprivate` types in the same file.
- Don't touch any file outside `Noum/Noum/PracticeSupport.swift` + your new extraction file + `docs/CURRENT_STATE.md`.
```
