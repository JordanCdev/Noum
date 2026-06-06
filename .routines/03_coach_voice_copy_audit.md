# Routine 3 — Coach voice copy audit (General, 17:00 daily)

## Slot
General, 17:00 local time.

## Purpose
Late-afternoon read-heavy quality pass. Scan every user-facing string in the app for voice violations (per `.claude/skills/noum-design/README.md` voice rules) and either fix them directly (small) or propose fixes (large).

## Prompt

```
You're the coach-voice copy auditor. Your job is to walk Noum's user-facing strings and find every place the voice slips — then fix the small ones, propose the big ones.

Running on Linux. Read-heavy, low-risk writes (copy only). No iOS Simulator.

## Required reading (every run)

1. `.claude/skills/noum-design/README.md` — full "CONTENT FUNDAMENTALS" + "Voice rules" + "Examples lifted from production" sections. This is the rubric.
2. `CLAUDE.md`
3. `docs/VISION.md` anti-goals (especially "no shallow gamification", "never punish-shame")
4. Memory file `never_punish_shame.md`
5. The last 7 `.audits/<date>_voice_audit.md` if they exist (don't re-flag stuff that's already on the punch list)

## Voice rubric (concise from the README)

- Second person, imperative-leaning ("Push a sharper rep" not "Time to push a rep")
- "Noum" as a character; never "we" / "our app" / "the system"
- Concrete targets, not vibes (numbers: `<150 WPM`, `3 reps`, `+88 to Platinum`)
- Speaking vocab: rep, drill, opening, pacing, composure, filler, pressure, clean rep, push, lean into
- No "Let's"
- No "Great job!"
- No emoji in copy (SF Symbols ≠ emoji ✅)
- No exclamation marks except in celebration overlays
- Sentence case body; Title Case + uppercase + tracking 0.8 for micro-labels only
- Never punish-shame on regression — frame the next clean rep

## What to scan

Grep targets (run in this order, dedupe results):
1. `grep -rn '"' Noum/Noum/*.swift | grep -v "//.*\"" | grep -v "let .*Key = " | grep -v "case .* = \"" | grep -E '"(Let'\''s|Great|Awesome|Amazing|Perfect|Wow|Yay|Oops|Sorry|Almost|Don'\''t worry|No worries)" '` — known anti-patterns
2. `grep -rn '"' Noum/Noum/*.swift | grep -E '"[^"]{1,160}!"' | grep -v "//.*\"" ` — exclamation marks
3. `grep -rnE '"[^"]*[😀-🙏🌀-🗿✨🎉]"' Noum/Noum/*.swift` — emoji in strings
4. The 4 main user-facing surfaces of CURRENT_STATE.md — Home, Profile, Review (Session History), Settings. Read every string they render that's a literal in the view file.

## Output: split fix vs propose

For each violation, decide:
- **Small fix (apply directly)**: a single-string change with no behavioral or layout impact (e.g. drop an exclamation, swap "Let's start" → "Begin", swap "our app" → "Noum"). Fix in place, commit.
- **Large propose (note only)**: a multi-string change or one that touches structure (e.g. an entire empty-state needs to be rewritten because it's structurally chirpy). Don't fix; write the violation + a proposed rewrite in the HANDOFF.

## Write HANDOFF.md at `.screenshots/<YYYY-MM-DD>_voice-audit/HANDOFF.md`

Sections:
- Strings fixed (file:line → before → after) — table format
- Strings proposed (file:line → why violates → proposed rewrite) — table format
- Surfaces needing visual verification (every screen that's been touched needs a screenshot pass in the next local run)
- Branch name + commit SHA

## Commit policy
- Commit fixes on `cloud/voice-audit-<YYYY-MM-DD>`. Push.
- One commit per file changed. Conventional commit message: `voice: tighten <surface> copy`.

## Don't
- Don't refactor.
- Don't change layout.
- Don't ship anything that risks user-visible regression beyond copy.
- Don't fix more than ~15 strings in one run. Volume violates "small fix only" discipline.
- Don't propose copy that breaks against existing grading vocabulary (no inventing tier names, no fake metrics).
```
