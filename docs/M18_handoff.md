# M18 — Sudden Death rework — Handoff

_Last updated: 2026-05-22 · branch `Redesign` · base HEAD `dd3489f` (mechanic) + `7434b7c` (result screen)_

This doc is self-contained. Read top-to-bottom before continuing M18 follow-ups or starting M19 implementation.

---

## TL;DR

Jordan smoke-tested M17 on the booted iPhone 17 sim and surfaced two real Sudden Death problems: (1) the prompt was being cut off mid-readout because TTS finished but the card collapsed too early, and (2) the mode name "Rushed Start" leaking into the post-rep title felt confusing and stat-blocky rather than dopamine-rich. He also asked for the mode to BE what its name promises — "if a user says a filler word just once the session ends" — true zero-tolerance.

**All three landed across two parallel agent tracks (`sd-mechanic` + `sd-result`) in one orchestrated team run, plus a follow-up M19 fix pass for the residual prompt-cutoff that the first track only partially closed.**

---

## Commits accumulated

```
dd3489f M18 — Sudden Death mechanic: TTS gating, zero-filler-tolerance, live word counter
7434b7c M18 — Sudden Death result screen: contextual header + high score + share
8bff781 M19 fix — SpeechRecognizer crash guard + cloud TTS prompt cutoff   (follow-up to M18 Track A)
```

All three on `origin/Redesign` as of push at 2026-05-22.

---

## User feedback items (verbatim quotes) → status

| # | User quote | Status | Commit |
| --- | --- | --- | --- |
| 1 | "On Sudden Death, prompt should never be interrupted, just let the prompt complete then start a timer" | ✅ | `dd3489f` (TTS gating via `pendingUserWaitingRound`) + `8bff781` (residual cloud-TTS path fix) |
| 2 | "the mode is called sudden death for a reason, its meant to be if user says a filler word just once the session ends" | ✅ | `dd3489f` (filler tolerance hard-coded to 0 across all rounds × difficulties) |
| 3 | "the minimum word limit thing still isnt clear enough" | ✅ | `dd3489f` (live `N/10 words` counter chip during `.userTurnActive` + light haptic on threshold cross) |
| 4 | "the title doesnt make sense" (post-rep "Rushed Start") | ✅ | `7434b7c` (contextual header — "New Best · N rounds" / "Clean Run · N rounds" / "Eliminated · Round N"; mode/difficulty demoted to subtitle) |
| 5 | "need more gamefied need more dopamine need more social aspect, need some scoring like high score" | ✅ | `7434b7c` (new `SuddenDeathHighScoreStore` + NEW HIGH! badge + number-roll-up animation 0→final over 0.6s respecting reduce-motion + real `UIActivityViewController` share button + hierarchical XP chip) |

---

## Architecture changes

### State ownership

- **New `Noum/SuddenDeathHighScoreStore.swift`** — `ObservableObject` with `static let shared`. Per-account UserDefaults key `suddenDeath.bestRounds.<difficulty>.<accountID>`. `bestRounds(difficulty:) -> Int`, `recordRun(roundsSurvived:difficulty:) -> Bool` (returns true if new best). Same per-account scoping pattern as `RatingStore` / `AchievementStore`.

### Pure-function logic / engine

- **`Noum/PressureTimerEngine.swift`** — `PressureRoundConfig.config(for:difficulty:)` now hard-codes `fillerTolerance: 0` across all 8 rounds × 3 difficulties. `SuddenDeathDifficulty.fillerToleranceShift` removed (no longer varies). Difficulty subtitles updated to match new meaning ("Wider start window. More time per round." / "Tight start window. Less time per round." — no longer mention filler tolerance).
- **`RoundOutcome.fillerOverload.label`** changed from "Filler Spike" → "Filler — instant elimination".
- **`pendingUserWaitingRound: Int?` published property + `confirmBeginUserWaiting()` method** — phase transition from `.npcTurn → .userTurnWaiting` now gates on a confirmation signal from the view; engine sets `pendingUserWaitingRound`, view calls `confirmBeginUserWaiting()` after TTS `didFinish`.

### UI

- **`Noum/SuddenDeathPracticeView.swift`**:
  - `onChange(of: engine.pendingUserWaitingRound)` triggers either immediate unblock (if TTS already done) or waits for `ttsDelegate.onFinish` (local TTS) / cloud-TTS duration estimate (cloud path)
  - `npcCard(expanded:)` derivation: `(!isUserTurn || isSpeakingPrompt) && roundOutcome == nil` — card stays expanded visually while TTS is mid-utterance
  - `wordCounter` view: `N/10 words` capsule appearing only during `.userTurnActive`, secondary → accent → primary color progression as user approaches threshold, `checkmark.circle` icon at/after threshold
  - `UIImpactFeedbackGenerator(style: .light)` fires once per round on the exact frame `wordCount` crosses `minimumWords` (state: `wordThresholdHapticFired`, reset on `.npcTurn` phase change)
  - npcCard collapsed `lineLimit` bumped 2 → 3 as gating-failure safety net (`8bff781`)
- **`Noum/SuddenDeathResultView.swift` (NEW, 318 LOC)** — extracted from inline `resultScreen` in SuddenDeathPracticeView (lines 905-1029 previously). Receives `result: PressureSessionResult`, `highScoreStore: SuddenDeathHighScoreStore`, `onRetry: () -> Void`, `onSeeFullSummary: () -> Void`.
  - Contextual header logic in `headerCopy(for:)`: result outcome → human header. "New Best · N rounds" overrides when high score beaten.
  - Number-roll-up `@State var animatedRounds: Int = 0` driven by `withAnimation(.easeOut(duration: 0.6))` on `.onAppear`; reduce-motion path shortcuts to final value
  - "Share" button presents `UIActivityViewController` via `UIViewControllerRepresentable` wrapper; plain-text snippet ("Just survived 5 rounds in Noum Sudden Death with zero filler words.") — no fake-social fabrication
  - XP chip: `.title3.weight(.bold)` (was `.caption.weight(.bold)` 12pt previously) + 8pt vertical padding

### `SuddenDeathPracticeView.swift` shrinkage

The inline result screen (lines 905-1029 + helpers) was 141 LOC. It's now a 9-line call to `SuddenDeathResultView(...)`. `resultStat(...)` + `roundOutcomeRowLabel(...)` helpers moved into the new view file.

### Tests appended (17 new cases)

**`SuddenDeathMechanicTests` — 11 cases** in `NoumTests/NoumTests.swift`:
- `fillerToleranceIsAlwaysZeroRegardlessOfDifficultyOrRound` (all 8 rounds × 3 difficulties)
- `difficultyOnlyAffectsStartWindowNotFillerTolerance`
- `wordCountBelowMinimumDoesNotMeetThreshold` / `wordCountAtMinimumMeetsThreshold` / `minimumWordCountIsConsistentAcrossAllRoundsAndDifficulties`
- `fillerOverloadLabelMatchesInstantEliminationMechanic` / `survivedLabelUnchanged` / `tooShortLabelUnchanged` / `timeoutBeforeStartLabelUnchanged`
- `easySubtitleDoesNotMentionFiller` / `hardSubtitleDoesNotMentionFiller`

**`SuddenDeathHighScoreStoreTests` — 6 cases**:
- `noRunRecordedReturnsZero`
- `recordRunReturnsTrueOnFirstRecord` / `recordRunReturnsFalseOnTieOrLower` / `recordRunReturnsTrueOnStrictImprovement`
- (per-account isolation + auth-wipe contract tests)

All 17 pass in ~27s on iPhone 17 sim per agent reports.

---

## Files added or substantially modified

### New files (2)
- `Noum/SuddenDeathHighScoreStore.swift` — 41 LOC
- `Noum/SuddenDeathResultView.swift` — 318 LOC

### Modified files
- `Noum/SuddenDeathPracticeView.swift` — TTS gating, live word counter, prompt-card expansion derivation, light haptic on threshold cross, npcCard collapsed line limit bump, inline result screen replaced with new view consumer
- `Noum/PressureTimerEngine.swift` — `pendingUserWaitingRound` + `confirmBeginUserWaiting()`, hard-zero filler tolerance, difficulty subtitle copy, RoundOutcome label
- `Noum/SpeechRecognizerViewModel.swift` — `.allowBluetooth` session option, defensive guard for 0-channel inputFormat (throws typed `AudioStreamError.invalidInputFormat` instead of crashing in `installTap`)

---

## Known follow-ups (deferred)

- **Cleaner cloud-TTS completion signal.** `8bff781` uses a duration estimate (0.55s/word × 0.85 rate + 0.5s overhead, floor 1.5s) to know when cloud-TTS audio actually finishes. The architecturally cleaner fix is `@Published isPlaying` on `IMMessageSpeaker` driven by `AVAudioPlayerDelegate.audioPlayerDidFinishPlaying(_:successfully:)`. That fix requires touching `PracticeSupport.swift` (forbidden in the fix-track brief). Schedule for a future M18.x or pull into M20 when `PracticeSupport.swift` is unlocked.
- **Live word counter visual tuning.** Current visual is calm/restrained per the brief (no arcade noise during the rep — arcade energy reserved for the result screen). If user feedback wants it more prominent, the path is bigger font scale + accent-color background fill, not motion.
- **Number-roll-up timing.** Currently 0.6s ease-out. May feel too slow at small numbers (1-3 rounds) or too fast at larger (10+). Tunable in `SuddenDeathResultView.onAppear` if user feedback warrants.

---

## Orchestration learnings (transcribe to memory for future sessions)

This session ran a **2-track parallel team with line-range carving on the same file**. Both `sd-mechanic` and `sd-result` needed to modify `SuddenDeathPracticeView.swift`, but only at disjoint line ranges (Track A: lines 1-902; Track B: lines 903-1029). The orchestrator skill rejects parallel writes to the same file in the collision zone, but this case was carved cleanly because the line ranges were textually disjoint with stable surrounding context.

**Pattern for future use:** When two tracks both NEED to modify the same large file, check whether their edits are in textually disjoint regions. If yes, carve by explicit line range in each brief ("You may edit lines 1-902 only"). Cherry-pick order: structural-extract track FIRST (Track B's diff: -141 lines, +12 lines), then localized-edits track (Track A's edits in earlier sections naturally compose because their line numbers haven't shifted).

The mechanical NoumTests.swift conflict (both tracks append-at-end) was resolved by keeping both sides of `<<<<<<<` — independent test structs concatenate without semantic interaction.

---

## How to continue in a fresh session

1. **Smoke** — booted sim has the latest build installed; tap Train → Sudden Death → Begin. Verify:
   - Prompt reads fully before timer starts (no mid-readout cutoff)
   - `N/10 words` counter visible during user turn with soft haptic on cross
   - One "uh"/"um" → instant elimination (no second chances at any difficulty)
   - Result screen: contextual header (not "Rushed Start"), animated rounds count, NEW HIGH! badge if applicable, share button works
2. **Pending push** — all M18 + M19 fix commits already on `origin/Redesign` as of 2026-05-22. Confirm with `git log origin/Redesign..Redesign --oneline`.
3. **M19 next** — `docs/M19_strategy.md` is the canonical roadmap for what comes next (Big Moment intake → Forward Plan → Session Intent → Monthly Letter → Situational Prep). Implementation of M19 Phase 1 (Big Moment) was kicked off in the session immediately following the M18 push.
