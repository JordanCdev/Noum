---
name: noum-orchestrator
description: Runs 2-5 Noum parallel agents end-to-end via Codex Agent Teams (https://code.Codex.com/docs/en/agent-teams). Spawns the team in this session, pre-stages each worktree with gitignored build plists + safe-op permission settings, monitors task completion via the shared task list, and integrates results sequentially. Reads docs/M15_handoff.md for phase briefs; carries the architectural layer + file-ownership map internally. Trigger for any 2+ concurrent agent run on this 78k-LoC iOS codebase.
---

# noum-orchestrator

This skill runs 2-5 parallel Codex agents on Noum using the official **Agent Teams** mechanism (Codex v2.1.32+). The user sits back; the lead session (you) creates the team, the teammates work concurrently in their own worktrees with their own context windows, and you integrate when they finish.

Reference: `https://code.Codex.com/docs/en/agent-teams`

## Default path — Agent Teams

### Prerequisite — enable the feature flag

Agent Teams is experimental and gated behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Check first:

```bash
echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-unset}"
```

If unset, write it into `~/.Codex/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

The user has to restart their `Codex` session for the env var to take effect. Tell them.

### Step 1 — Pre-stage worktrees (you do this in your main session)

For each track, create a locked worktree and copy the gitignored build-required plists in. These are **all four** of them — missing any causes a build or runtime crash:

```bash
set -e
cd /Users/jordan/src/GitHub/Noum
BASE=$(git rev-parse Redesign)

for slug in <slug-1> <slug-2>; do
  git worktree add --lock .Codex/worktrees/agent-$slug -b agent-$slug "$BASE"
  for plist in Info.plist GoogleService-Info.plist AIConfig.plist BackendConfig.plist; do
    cp Noum/$plist .Codex/worktrees/agent-$slug/Noum/$plist
  done
done
```

**Why all four:**
- `Info.plist` — main app plist; without it, `xcodebuild` fails at the Plist phase
- `GoogleService-Info.plist` — Firebase config; without it, `+[FIRApp configure]` throws and the test sim crashes on launch (SIGABRT in FirebaseBootstrap)
- `AIConfig.plist` — AI provider API keys; without it, AI surfaces silently fall through to template fallback (the agent thinks it works but AI-backed paths are dead)
- `BackendConfig.plist` — backend endpoints; without it, optional backend sync fails silently

Mention all four in every prompt so the agent can re-copy if a clean-build wiped them.

### Step 2 — Write per-worktree permission settings

For each worktree, write `.Codex/settings.local.json` so teammates auto-approve safe operations and refuse risky ones. **This step is mandatory** — without it teammates pause on every Write and the user babysits.

```json
{
  "$schema": "https://json.schemastore.org/Codex-settings.json",
  "permissions": {
    "allow": [
      "Read", "Write", "Edit", "Glob", "Grep",
      "Bash(xcodebuild *)",
      "Bash(git status*)", "Bash(git diff*)", "Bash(git log*)",
      "Bash(git show*)", "Bash(git add*)",
      "Bash(grep *)", "Bash(find *)", "Bash(ls *)",
      "Bash(cat *)", "Bash(wc *)", "Bash(echo *)",
      "Bash(xcrun simctl list*)", "Bash(xcrun simctl boot*)",
      "Bash(xcrun xcresulttool *)",
      "Bash(cp *)", "Bash(mkdir *)"
    ],
    "deny": [
      "Bash(git push*)", "Bash(git commit*)",
      "Bash(git reset --hard*)", "Bash(git checkout *)",
      "Bash(rm -rf*)", "Bash(npm *)", "Bash(brew *)"
    ]
  }
}
```

### Step 3 — Spawn the team

You, the lead, request the team in natural language. Don't fabricate teammate names mid-thought; assign predictable names you can reference later. Example for M15 Phases 3 + 4:

> Create an agent team with 2 teammates, one named `phase3` and one named `phase4`.
>
> **phase3** works in `/Users/jordan/src/GitHub/Noum/.Codex/worktrees/agent-m15-phase3`. Their task: M15 Phase 3 — Mode literacy. Brief is in `docs/M15_handoff.md` § "Phase 3". They own `Noum/PracticeModeSelectionView.swift`. Touch `NoumTests/NoumTests.swift` to append a `PracticeModeRowExpansionTests` struct. Forbidden: every other file. Build with `-derivedDataPath .build`. Stage but do not commit. Report Implemented / Partially / Blocked / Assumptions / Verification / Risks at the end.
>
> **phase4** works in `/Users/jordan/src/GitHub/Noum/.Codex/worktrees/agent-m15-phase4`. Their task: M15 Phase 4 — Home discipline. Brief in `docs/M15_handoff.md` § "Phase 4". They own `Noum/HomeSignalGate.swift` (create). Touch `Noum/ContentView.swift` (home block only, single track this session), `Noum/SettingsView.swift` (one toggle), `NoumTests/NoumTests.swift` (append `HomeSignalGateTests`). Forbidden: all other connective-tissue files. Same build + report contract as phase3.
>
> Use Sonnet for both teammates. Do not require plan approval — both phases are concrete and pre-briefed. Wait for both to finish before any synthesis.

The team config lands in `~/.Codex/teams/<team-name>/config.json` and tasks in `~/.Codex/tasks/<team-name>/`. Both auto-managed; do not edit by hand.

### Step 4 — Monitor (passive)

The team's shared task list shows progress. Press **Shift+Down** to cycle teammates in in-process mode. Press **Ctrl+T** to toggle the task list. Teammates auto-notify you when idle.

Do NOT pre-emptively poll or check on them — the runtime delivers messages automatically. Just sit until they report done.

### Step 5 — Integrate on completion

When all teammates have completed their tasks:

1. `cd /Users/jordan/src/GitHub/Noum`
2. Confirm `git status` clean on `Redesign`.
3. For each teammate in spawn order:
   - `git -C .Codex/worktrees/agent-<slug> status` — see staged work
   - `git -C .Codex/worktrees/agent-<slug> commit -m "<phase title>"` — make the commit in the worktree
   - `git cherry-pick agent-<slug>` from main worktree
   - Resolve `NoumTests/NoumTests.swift` conflict if any (keep both sides of `<<<<<<<` — independent test structs)
   - `xcodebuild build -derivedDataPath .build` → green
4. Update `docs/CURRENT_STATE.md` in one final commit summarising all phases
5. **Clean up the team:** tell the lead "Clean up the team" — this removes shared resources. Then:
   - `git worktree unlock .Codex/worktrees/agent-<slug>`
   - `git worktree remove --force .Codex/worktrees/agent-<slug>`
   - `git branch -d agent-<slug>` (`-d` not `-D`; should succeed)
6. **STOP** and ask the user to authorise `git push origin Redesign`. Don't push unprompted — even at the end of a clean orchestration.

## Fallback path — static bundles only

When the Agent Teams feature flag is off and the user doesn't want to enable it, OR when running pre-v2.1.32 Codex, fall back to producing copy-pasteable worker bundles + a bash bootstrap script + a merge plan. They open separate terminal tabs, paste prompts, ferry results back. Strictly worse than the Agent Teams path. Use only when explicitly requested.

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
4. `AGENTS.md` (repo root) — required response structure
5. `.Codex/skills/noum-design/SKILL.md` — voice rules so worker bundles inherit them

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

## Writing the isolated prompt (used by both default and fallback paths)

Whether you're spawning teammates via Agent Teams (default) or producing static bundles (fallback), each track's prompt body must include:

1. **AGENTS.md mandate.** "Follow the response structure: Scope / Product goal / Existing patterns / Root causes / Risks / Plan before any implementation. Verification output: Implemented / Partially / Blocked / Assumptions / Verification / Risks before final."
2. **Goal in one paragraph** — quoted directly from the corresponding phase in `docs/M15_handoff.md`. Don't paraphrase.
3. **File paths with line numbers** — pulled from the phase brief.
4. **What NOT to change** — the `Forbidden:` list. "If you find you need to touch a Forbidden file, stop and report. Do not silently expand scope."
5. **Brand voice reminder.** "Coach voice: direct, second person, no chirpy filler, no exclamation marks, no emoji. See `.Codex/skills/noum-design/SKILL.md`."
6. **Worktree hygiene.** "If `Noum/Info.plist`, `Noum/GoogleService-Info.plist`, `Noum/AIConfig.plist`, or `Noum/BackendConfig.plist` is missing, re-copy: `for f in Info.plist GoogleService-Info.plist AIConfig.plist BackendConfig.plist; do cp /Users/jordan/src/GitHub/Noum/Noum/$f Noum/$f; done`."
7. **Validation command.** "Run `xcodebuild build -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' -configuration Debug -derivedDataPath .build` before reporting complete."
8. **Disposition.** "Stage changes but do not commit. Leave the worktree clean for human review + sequential rebase."
9. **Verification stub.** "Before final response, provide the AGENTS.md verification block."

## Collision check (always)

For every pair of proposed tracks, verify the `Owns:` + `Touches:` sets don't overlap on a file in the layer-7 collision zone:

- Two tracks both modifying `ContentView.swift` → **REJECT**. Merge one into the other or run serially.
- Both modifying `NoumTests/NoumTests.swift` → **OK** (append-at-end; mechanical conflict resolution).
- Both modifying `CURRENT_STATE.md` → **OK** (single final pass).
- Both modifying `PracticeSupport.swift` → **REJECT** (`AppDestination` collisions).

If the user has explicitly opted into a known-serial pair (e.g. M15 Phase 1b + Phase 2 per `docs/M15_handoff.md` § Sequencing recommendation), warn clearly. Don't refuse — they may know something the doc doesn't.

## Failure handling

If any teammate fails (compile error, blocked on Forbidden file, model error):

- Read their final report. The agent should follow AGENTS.md verification format — the `Blocked:` field tells you what stopped them.
- If the failure is isolated, integrate the others and report the failed track separately to the user.
- If the failure is structural (the orchestration plan was wrong), abort all in-flight integration and report.

If a teammate expanded scope into a Forbidden file:
- `git -C <worktree> diff` to see what they touched outside their `Owns:`/`Touches:` set
- Selectively stage only the intended changes (`git checkout -p`) and discard the rest
- Report the scope violation to the user so the next orchestration tightens the brief

If the FIRApp.configure() / Firebase crash hits the test sim: `Noum/GoogleService-Info.plist` was missing from the worktree. Copy it in (and the other three plists), then have the agent retry `xcodebuild build`.

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
