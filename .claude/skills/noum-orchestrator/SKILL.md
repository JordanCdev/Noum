---
name: noum-orchestrator
description: Splits a Noum macro feature or M15 phase set into isolated parallel worker bundles bound to Git worktrees. Reads docs/M15_handoff.md for phase-specific briefs; carries the architectural layer + file-ownership map internally. Trigger when starting two-or-more concurrent agent runs on this 78k-LoC iOS codebase.
---

# noum-orchestrator

When the user wants to run two or more Claude agents concurrently on Noum, this skill decomposes the work into isolated tracks that won't step on each other. Output: copy-pasteable worker bundle per track + a single bash script that creates the worktrees + a sequential merge plan.

This skill does NOT spawn agents itself. It produces the briefs + worktree commands the user (or the orchestrating agent) then invokes via `Agent(isolation: "worktree", run_in_background: true, …)`.

## Invocation

```
/noum-orchestrator <phase set or feature description>
```

Examples:
- `/noum-orchestrator phases 3 and 4` — split the two pending M15 phases recommended for parallel execution
- `/noum-orchestrator phase 1b, 3, 4` — three-way parallel (only if no collisions)
- `/noum-orchestrator everything pending in M15 except phase 2`
- `/noum-orchestrator new feature: Voice Replay surface that lets the user replay their best rep with the coach's analysis`

If invoked without arguments: read `docs/M15_handoff.md`, list the PENDING phases, recommend a safe parallel set per the doc's `Sequencing recommendation`, ask the user to confirm.

## Required reading (every invocation)

1. `docs/M15_handoff.md` — current phase definitions, status, owned files, sequencing rules
2. `docs/CURRENT_STATE.md` — anything that landed since the handoff was written
3. `docs/VISION.md` § Anti-goals — never violate
4. `CLAUDE.md` (repo root) — required response structure
5. `.claude/skills/noum-design/SKILL.md` — voice rules so worker bundles inherit them

If any are missing, stop and report.

---

## Noum's architectural layers (carried internally)

Every file in `Noum/` belongs to exactly one of seven layers. Tracks must stay inside one or two layers max.

### 1 — State ownership (singletons)
`ObservableObject` with `static let shared`, per-account `UserDefaults` + Keychain account ID. Examples: `AuthManager`, `ProfileManager`, `PracticeSessionStore`, `CoachingProfileStore`, `BaselineStore`, `RatingStore`, `PathProgressManager`, `LeagueManager`, `StreakFreezeManager`, `ClutchWordStore`, `AchievementStore`, `AskNoumStore`, `ProofMomentArchive`.
**Track rule:** one agent owns one new store at a time.

### 2 — AI services (actors)
Stateful-by-request services wrapping `AIProvider` (OpenAI / DeepSeek / Gemini). Examples: `AIInsightsService`, `AICoachChatService`, `ProofMomentService`, `AINPCChatService`, `AIHomeRecommendationService`, `GoalParaphraseService`, `GrammarFeedbackService`.
**Track rule:** one new service per track.

### 3 — UI views (SwiftUI)
View structs, one per surface. Examples: `ContentView`, `HomeCoachCard`, `AskNoumView`, `SummaryView`, `ProfileView`, `SettingsView`, `PathJourneyView`, every `*Card.swift` and `*View.swift`.
**Track rule:** one agent owns one new view file. Navigation pushes come from parents; parallel tracks must not modify `AppDestination` simultaneously.

### 4 — Pure-function logic
Stateless helpers, no `@Published`, no I/O. Examples: `CoachContextBuilder`, `PracticeEvaluator`, `TrendAnalyzer`, `DrillEngineV2`, `RewardEngine`, `RatingEngine`, `BaselineEngine`, `EloquenceEngine`, `MilestoneCopy`, `VoiceMetricsRead`, every `*Engine.swift`.
**Track rule:** new files safe in parallel; modifying existing is single-track.

### 5 — Tests
Single `NoumTests/NoumTests.swift` (~5000 lines). Every agent appends test structs at the end.
**Track rule:** parallel-safe — conflicts on this file are mechanical (keep both sides of `<<<<<<<` since structs are independent).

### 6 — Design tokens
`Noum/DesignSystem.swift`, `Noum/Typography.swift`, `Noum/Resources/Fonts/`, `Noum/Resources/Localizable.xcstrings`, `Noum/Resources/Assets.xcassets/`.
**Track rule:** modifications to `DesignSystem.swift` / `Typography.swift` are single-agent, serialised. `Localizable.xcstrings` additions safe in parallel as long as keys don't collide.

### 7 — Navigation + connective tissue (COLLISION ZONE)
The few files where everything threads through. Touching these in parallel is the #1 cause of bad merges.

- `Noum/ContentView.swift` — Home composition, navigation destinations, deep link router, overlay stack
- `Noum/PracticeSupport.swift` — `AppDestination` enum, `SpeakingStyleGoal`, `CoachingProfile`, `AIProvider`, `PracticeMode`
- `Noum/NoumApp.swift` — app launch, scene phase, launch arg parsing
- `Noum/SummaryView.swift` — post-rep chain (personal-best → level-up → progression)
- `docs/CURRENT_STATE.md` — always conflicts; orchestrator's final pass updates after all tracks merge

**Track rule:** single-agent only per session. If two tracks need to modify `ContentView.swift`, one must own the edits and the other expose a callback.

---

## Common track templates

When splitting a new feature (not an M15 phase), reach for these shapes first.

### Template A — new AI surface
- **Owns (create):** `Noum/<Name>Service.swift`, `Noum/<Name>Store.swift`, `Noum/<Name>View.swift`, `Noum/<Name>ContextBuilder.swift` (if non-trivial)
- **Touches:** `ContentView.swift` (destination + entry card), `PracticeSupport.swift` (`AppDestination` case), `NoumTests/NoumTests.swift` (append)
- **Forbidden:** any other AI service, any other view file
- **Reference:** Ask Noum (`AskNoumStore` + `AICoachChatService` + `CoachContextBuilder` + `AskNoumView`)

### Template B — new Home card
- **Owns (create):** `Noum/<Name>Card.swift`
- **Touches:** `ContentView.swift` (insert into home `VStack`, increment `cardEntrance` indexes below)
- **Forbidden:** other card files, any practice view
- **Reference:** `VoiceMetricsCard`, `askNoumPromoCard`

### Template C — new practice mode
- **Owns (create):** `Noum/<Name>PracticeView.swift`, `Noum/<Name>SetupView.swift`
- **Touches:** `PracticeModeSelectionView.swift`, `PracticeSupport.swift` (`PracticeMode` enum), `ContentView.swift` (destination), `SummaryView.swift` (if mode-specific branch needed)
- **Forbidden:** other practice views, other home cards
- **Reference:** `CutTheCrutchView` + Mode picker entry

### Template D — celebration / overlay
- **Owns (create):** `Noum/<Name>Celebration.swift`
- **Touches:** `ContentView.swift` (overlay stack), `<TriggerStore>.swift` (pending flag), `SummaryView.swift` (if post-session)
- **Forbidden:** other celebration files
- **Reference:** `PathNodeCelebration`, `PersonalBestCelebrationScreen`. Invariant: fire on upward only — never punish-shame regression.

### Template E — passive surface upgrade
- **Touches:** the specific view file(s) being upgraded
- **Forbidden:** any state / service / navigation file
- **Reference:** the M14 "supporting hero" pass (Lessons / Sessions / Speech Projects)

### Template F — coach-voice audit
- **Touches:** many files at the string-literal level only
- **Forbidden:** structural changes, new files
- **Reference:** the M14 "7 exclamations dropped" pass

---

## How the skill runs

### Step 1 — Confirm scope
Echo: "Splitting `<input>` into `<N>` parallel tracks. Each track owns a worktree at `.claude/worktrees/agent-<slug>/`, branch `agent-<slug>`. Final integration is sequential rebase into `Redesign`."

If the user gave a feature description (not phase numbers), do the architectural breakdown — pick 2–4 of the templates above, name each track.

### Step 2 — Collision check
For every pair of proposed tracks, verify the `Owns:` + `Touches:` sets don't overlap on a file in the layer-7 collision zone.

- Two tracks both modifying `ContentView.swift` → **REJECT**. Merge one into the other or run serially.
- Both modifying `NoumTests/NoumTests.swift` → **OK** (append-at-end; mechanical conflict resolution).
- Both modifying `CURRENT_STATE.md` → **OK** (single final pass).
- Both modifying `PracticeSupport.swift` → **REJECT** (`AppDestination` collisions).

If the user has explicitly opted into a known-serial pair (e.g. M15 Phase 1b + Phase 2 per `docs/M15_handoff.md` § Sequencing recommendation), warn clearly before producing bundles. Don't refuse — they may know something the doc doesn't.

### Step 3 — Generate per-track bundles

For each track, output a Markdown block with six fields:

```markdown
## Track <N>: <human-friendly title>

**Branch:** `agent-<slug>`
**Worktree:** `.claude/worktrees/agent-<slug>`
**Base:** `Redesign` at `<short SHA>` (current HEAD)

**Owns (create):**
- `Noum/<File>.swift` — <one-line purpose>

**Touches (modify, single-track in this session):**
- `Noum/<File>.swift` — <what changes>

**Forbidden (other tracks own these):**
- `Noum/<File>.swift`

**Context files (read first):**
- `CLAUDE.md`
- `docs/VISION.md`
- `docs/M15_handoff.md` § <relevant section, exact heading>
- <specific Swift files the worker should study>

**Isolated prompt** (drop into a fresh agent):

> <self-contained 400–700 word brief — see Step 4>
```

### Step 4 — Write the isolated prompt

Each prompt averages 400–700 words and must include:

1. **CLAUDE.md mandate.** "Follow the response structure: Scope / Product goal / Existing patterns / Root causes / Risks / Plan before any implementation. Verification output: Implemented / Partially / Blocked / Assumptions / Verification / Risks before final."

2. **Goal in one paragraph** — quoted directly from the corresponding phase in `docs/M15_handoff.md`. Don't paraphrase.

3. **File paths with line numbers** — pulled from the phase brief.

4. **What NOT to change** — the `Forbidden:` list. "If you find you need to touch a Forbidden file, stop and report. Do not silently expand scope."

5. **Brand voice reminder.** "Coach voice: direct, second person, no chirpy filler, no exclamation marks, no emoji. See `.claude/skills/noum-design/SKILL.md`."

6. **Worktree hygiene.** "Your worktree may be missing `Noum/Info.plist` (gitignored but required for `xcodebuild`). Copy it from the primary checkout: `cp /Users/jordan/src/GitHub/Noum/Noum/Info.plist <worktree>/Noum/Info.plist`."

7. **Validation command.** "Run `xcodebuild build -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -configuration Debug` before reporting complete."

8. **Disposition.** "Stage changes but do not commit. Leave the worktree clean for human review + sequential rebase."

9. **Verification stub.** "Before final response, provide the CLAUDE.md verification block."

### Step 5 — Worktree bootstrap script

After all bundles, output one bash block:

```bash
# Bootstrap parallel worktrees for the tracks above.
set -e
cd /Users/jordan/src/GitHub/Noum

# Capture current Redesign HEAD so every track starts from the same base.
BASE=$(git rev-parse Redesign)
echo "Base commit: $BASE"

# One worktree per track. --lock prevents accidental clobbering.
git worktree add --lock .claude/worktrees/agent-<slug-1> -b agent-<slug-1> "$BASE"
git worktree add --lock .claude/worktrees/agent-<slug-2> -b agent-<slug-2> "$BASE"

# Copy gitignored-but-required Info.plist into each worktree so xcodebuild works.
cp Noum/Info.plist .claude/worktrees/agent-<slug-1>/Noum/Info.plist
cp Noum/Info.plist .claude/worktrees/agent-<slug-2>/Noum/Info.plist

echo "Worktrees created:"
git worktree list
echo ""
echo "Spawn agents against these paths."
```

### Step 6 — Merge plan

End with a numbered plan the user runs after all agents finish:

```markdown
## Merge plan (after all agents finish)

Sequential, not parallel.

1. `cd /Users/jordan/src/GitHub/Noum`
2. Confirm `git status` is clean on `Redesign`.
3. For each track in order (Track 1 → Track N):
   - `git diff Redesign..agent-<slug>` — sanity-check
   - `git cherry-pick agent-<slug>` (or `--no-commit` if you want to inspect)
   - Resolve conflicts (typically `NoumTests/NoumTests.swift` — keep both sides of every `<<<<<<<`)
   - `xcodebuild build` → green
4. Update `docs/CURRENT_STATE.md` in one final commit summarising all phases
5. Cleanup:
   - `git worktree unlock .claude/worktrees/agent-<slug>` (if locked)
   - `git worktree remove --force .claude/worktrees/agent-<slug>`
   - `git branch -d agent-<slug>` (`-d` not `-D` — should succeed since commits are on `Redesign`)
6. `git push origin Redesign`
```

## Edge cases

- **Feature not in M15.** Skill still works: do the architectural-layer split using templates A–F. Write each track's brief inline (no handoff section to quote).
- **5+ tracks requested.** Refuse: "Past 4 concurrent agents the orchestration cost dwarfs the parallelism win. Pick the 3 highest-leverage; run the rest serially."
- **Two tracks both adding an `AppDestination` case.** **REJECT.** Merge them or sequence them. Only one track per session may touch `PracticeSupport.swift`.
- **Stale base.** If the user lands a commit on `Redesign` mid-run, the merge plan should warn: "`git diff agent-<slug>..Redesign` will show drift; manually copy the agent's unique changes and discard the cherry-pick."
- **`Noum/Info.plist` missing in worktree.** Bootstrap script copies it. Mention this in every isolated prompt too.

## What to refuse

- Tracks that both edit `ContentView.swift` non-trivially
- Tracks that violate VISION.md anti-goals (shallow gamification, streak shaming, hearts-and-lives, noisy productivity patterns)
- Refactors of state ownership in parallel — one agent owns one new `*Store.swift` at a time
- Modifications to `DesignSystem.swift` or `Typography.swift` in parallel — single-track always

## Output length contract

Clean orchestration of 3 tracks runs ~1200–1800 words: intro (50) + 3 track bundles (300 each) + bootstrap (150) + merge plan (200). If output exceeds 2500 words, collapse the briefs.
