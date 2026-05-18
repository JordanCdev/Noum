# Noum scheduled cloud routines

Six prompts, one per scheduled cloud agent. Anchored to **M14 — Open the Loop** (the active milestone: TestFlight prep) and the existing grading systems (BaselineEngine 0–10, RatingEngine ELO 100–1000, League tiers Bronze→Diamond, Path nodes, Mode Mastery).

## How these slots fit

| Time | Slot name | Routine | Why this slot |
|---|---|---|---|
| 09:00 | Run 1 | Vision drift audit | Morning: read overnight work, surface drift |
| 13:00 | Run 2 | Refactor backlog grinder | Mid-day: long-running code work, large file extraction |
| 17:00 | General | Coach voice copy audit | Late afternoon: read-heavy quality pass |
| 21:00 | Night | Localization migration | Evening: pure copy work, low-risk batched commits |
| 01:00 | Night 2 | Test coverage scan | Overnight: produces test stubs for morning local fill-in |
| 05:00 | Night 3 | Mid-session goal-aware HUD (M5 stub) | Pre-dawn: focused code change, flagged for visual verification |

## Universal contract (every routine respects this)

Every cloud routine:
1. **Detects Linux** at start. If not Darwin, accepts no iOS Simulator / no `xcodebuild`. Plans accordingly.
2. **Reads first**: `CLAUDE.md`, `docs/VISION.md`, `docs/CURRENT_STATE.md`, latest `.screenshots/<date>_*/HANDOFF.md`, the routine-specific files listed in its own prompt.
3. **Writes a HANDOFF.md** at the end into `.screenshots/<YYYY-MM-DD>_<routine-slug>/HANDOFF.md` (no PNGs — Linux can't capture). The HANDOFF.md commits to git so the next local run reads it.
4. **Honors brand rules** strictly: no illustration, no characters as mascots, no melodic music, no "Let's", no emoji in copy, no exclamations (except celebration overlays — none on cloud), no shame-on-regression copy.
5. **Honors voice**: trusted speaking coach who heard your last five reps. Specific, warm, never chirpy.
6. **Commits to a branch** — never directly to `main` or `Redesign`. Branch name: `cloud/<routine-slug>-<YYYY-MM-DD>`. Pushes the branch (if remote available). Does NOT open a PR automatically — that's Jordan's call.
7. **Surfaces under "Surfaces needing visual verification"** in HANDOFF.md anything that touched UI. The next local session reads this and prioritizes screenshot capture.
8. **Stops if confused** — pushes back per CLAUDE.md if the request conflicts with architecture / VISION / brand. Doesn't ship hacks.

## How to install

Per routine: paste the prompt body into the routine on claude.ai's scheduled-tasks UI (or whatever Jordan uses to manage them). Title each routine after the file (`Vision drift audit`, etc.). Set the cron / time as listed above.
