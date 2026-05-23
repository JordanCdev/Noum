# HANDOFF — M24 deferred slate: Voice-change retroactive read + Sudden Death in History

## Scope

The previous push shipped **M24 Tracks 2 + 3** (commit `c7dd4b1`) —
Summary dedupe + Sudden Death `SuddenDeathRunHistoryStore` + Recent
Runs card on the Result screen — and listed five concrete "Future
moves" at the bottom of its HANDOFF. This session picks up two of
those that are both vision-aligned and shippable end-to-end without
backend or schema work:

- **Track A — Voice-change retroactive read** (`HANDOFF.md` future
  move #6): when the user changes their `speakingStyleGoal`,
  regenerate the most-recent `PostRepCoachNote` in the new voice so
  the persistent Ask Noum chat coach reads the LIVE voice on its
  very next reply, not the stale one the rep was recorded in. This
  is the £130/hr coach actually adapting — `docs/VISION.md` pillar
  #5 (Personalized coaching).

- **Track B — Sudden Death runs reachable from History**
  (`HANDOFF.md` future move #2): the existing History tab filters
  generic `PracticeSession` rows by mode, but the rich Sudden Death
  engine-specific stats (rounds survived, clean-run count, per-
  difficulty best) live in the separate `SuddenDeathRunHistoryStore`
  and were only visible on the per-run Result screen. This track
  surfaces those stats on the History surface when the user filters
  to Sudden Death — `docs/VISION.md` pillar #4 (Believable
  progress).

User brief: "continue from the existing TO-DO, ensure working
towards getting the app towards the vision plan, and all round A+,
make my dream I had come true too, ensure working on the redesign
branch too (very important)."

Translation: pick the most user-facing items off the deferred list,
respect the vision anti-goals (no fake gamification, no fabricated
trend, honest data only), and ship on `Redesign`.

The remaining three "Future moves" from the prior HANDOFF are
deferred again for explicit reasons: friends Sudden Death scores
require `PublicProfileSnapshot` schema work + backend changes;
`coachNoteRevealed` cleanup carries a known regression risk on the
celebration timing chain (the prior HANDOFF's own "Risks" section
flagged it — "left alone for safety"); AI generation gating is
engineering hygiene not user-facing.

## What shipped

### Track A — Voice-change retroactive read

The persistent Ask Noum chat coach reads the most-recent
`PostRepCoachNote` via `CoachContextBuilder.userContext`'s LAST REP
NOTE section. Before this push, that note was permanently locked in
whatever voice was active at the time of the rep — so a user who
finished a rep on `authoritative` then switched to `warm` in
onboarding would still see the chat coach quoting the
authoritative-voice line as if it were the live voice, until they
finished another rep. The voice the user actually chose was being
silently ignored on every chat reply in the window between the
voice change and the next rep.

This track closes that gap.

#### Move 1 — `PracticeSessionFinalizer.regenerationInput(...)` (NEW pure helper)

```swift
nonisolated static func regenerationInput(
    from session: PracticeSession,
    newVoice: SpeakingStyleGoal?,
    baseline: CommunicationBaseline,
    bigMoment: BigMoment?,
    bigMomentDaysUntil: Int?
) -> PostRepCoachNoteInput
```

Pure function. Builds the same `PostRepCoachNoteInput` shape the
`recordPostRepCoachNote` finalize path constructs, but takes the
session as a parameter and the voice as a parameter (rather than
reading from live stores), so it can be unit-tested without
provider stubs. Session metrics carry through unchanged
(`sessionID`, `mode`, `score`, `fillerCount`, `duration`,
`wordCount`, `intentLabel`); baseline + BigMoment flow in from the
caller. Baseline confidence is mapped to `Optional` the same way
the finalize path does — insufficient confidence → `nil`, so the
deterministic priority chain skips the comparison branch instead
of citing a baseline that doesn't exist yet.

#### Move 2 — `PracticeSessionFinalizer.regenerateMostRecentNoteIfVoiceChanged(newVoice:)` (NEW)

```swift
@MainActor
static func regenerateMostRecentNoteIfVoiceChanged(newVoice: SpeakingStyleGoal?)
```

Three guards before doing any work:

1. `PostRepCoachNoteStore.shared.latestNote()` returns nil → no
   note has been recorded yet (cold-start account), no regen
   needed.
2. The latest note's `voice` already matches the new voice → the
   onboarding "Save" was tapped with no actual voice change
   (idempotent — the user could re-save the same profile and we
   shouldn't burn an AI call on it).
3. The originating session no longer exists in
   `PracticeSessionStore.shared.sessions` → defensive against a
   user who deleted their last session from History between the
   note being written and the voice change. Never invent a note
   for a session that no longer exists.

When all three guards pass, the function:

- Reads the live `BaselineStore.shared.baseline` and
  `BigMomentStore.shared.activeMoment` (+ days until) as the
  context for the regen.
- Builds the input via `regenerationInput(...)` with the new
  voice.
- Writes the deterministic note **synchronously** via
  `PostRepCoachNoteStore.shared.record(_:)`. The store's
  pre-existing dedupe-by-sessionID contract means this REPLACES
  the prior record rather than stacking — the latest note for
  that sessionID is now in the new voice on the very next paint
  cycle of `AskNoumView`.
- Spawns a detached `Task` to fire the AI upgrade — same shape as
  the finalize path — that re-records only when the upgrade is
  actually AI-backed. Network failure, missing provider, non-
  English locale → no second write, the deterministic note
  stands.

#### Move 3 — `CoachingProfileStore.save(_:)` voice-change hook

```swift
let previousVoice = self.profile?.speakingStyleGoal
self.profile = profile
// ... existing save body ...
if let previousVoice, previousVoice != profile.speakingStyleGoal {
    PracticeSessionFinalizer.regenerateMostRecentNoteIfVoiceChanged(
        newVoice: profile.speakingStyleGoal
    )
}
```

Snapshot the prior voice BEFORE mutating `self.profile` so we have
the comparison point. Initial profile capture (`previousVoice ==
nil`) deliberately does NOT trigger a regen — a fresh account has
no rep history to regenerate against, and the next finalize will
produce the first note in the chosen voice naturally.

The only call site for `CoachingProfileStore.save(_:)` is
`CoachingOnboardingView` (verified by `grep`), so the regen fires
exactly when the user goes through the voice-selection step of
onboarding. Voice changes from any future Settings surface that
calls `save(_:)` will also pick this up automatically — single
hook.

### Track B — Sudden Death runs reachable from History

The History tab (`SessionHistoryView`) reads `PracticeSession`
rows from `PracticeSessionStore.shared.sessions` and filters them
by mode. A Sudden Death rep does write a `PracticeSession` (with
`mode: .suddenDeath`) so the existing rows DO render — but only
through the generic `PracticeSession` lens (transcript snippet,
score, fillers). The Sudden Death-specific signals — rounds
survived, clean-run count, per-difficulty best — live in
`SuddenDeathRunHistoryStore.shared.runs` and were only visible on
the per-run Result screen. This track surfaces them on History.

#### Move 1 — `Noum/SuddenDeathHistorySummary.swift` (NEW pure helper)

```swift
struct SuddenDeathDifficultyBreakdown: Equatable, Identifiable {
    let difficulty: SuddenDeathDifficulty
    let runCount: Int
    let bestRounds: Int
    let averageRounds: Double  // rounded to 1dp
    let cleanRunCount: Int     // totalFillers == 0
    let lastPlayed: Date
    var id: SuddenDeathDifficulty { difficulty }
}

enum SuddenDeathHistorySummary {
    static func breakdowns(from runs: [SuddenDeathRunRecord]) -> [SuddenDeathDifficultyBreakdown]
    static func totalRunCount(from runs: [SuddenDeathRunRecord]) -> Int
    static func mostRecentDate(from runs: [SuddenDeathRunRecord]) -> Date?
}
```

Pure. Groups runs by difficulty, computes best (max
`roundsSurvived`), average (1dp), clean count (`totalFillers ==
0`), and the most-recent `completedAt`. Sorts by `lastPlayed`
descending — the difficulty the user touched last lands on top,
not whichever difficulty alphabetizes first. Empty input → empty
output (the consumer self-hides on empty).

#### Move 2 — `Noum/SuddenDeathHistoryBreakdownCard.swift` (NEW)

SwiftUI hero card. Header reads "Sudden Death history" with the
mode glyph + "12 runs · Last run 3 days ago" subtitle. One row per
difficulty (only those the user has played — no zero-row rows for
unplayed difficulties), each carrying three stat columns: **best**
(peak rounds), **avg** (mean rounds, 1dp), **clean** (zero-filler
run count).

Hero chrome matches the existing History surface treatment
(mode-tinted radial wash + tint border + soft shadow) so the card
reads as a hero surface rather than a list row.

Self-hides on cold start when `breakdowns.isEmpty` (no SD runs
yet) — rendering "0 runs" would be visual noise for a user who
hasn't touched the mode. Accessibility: each row exposes a
combined label ("Hard: 5 runs, best 8, average 6.4 rounds, 2 clean
runs") for VoiceOver.

#### Move 3 — `SessionHistoryView` integration

- New `@StateObject private var suddenDeathRunHistoryStore =
  SuddenDeathRunHistoryStore.shared` so the card re-paints when
  the store publishes after a new run lands.
- New section between the mode filter chips and the session list
  header:
  ```swift
  if selectedModeFilter == .suddenDeath {
      SuddenDeathHistoryBreakdownCard(runs: suddenDeathRunHistoryStore.runs)
          .padding(.horizontal, Spacing.screenH)
          .padding(.bottom, 16)
  }
  ```

  The "All" filter and every other mode filter stay unchanged — the
  card only renders inside the SD filter context so users browsing
  other modes don't see Sudden Death noise. Single-condition gate;
  the card's own `breakdowns.isEmpty` check covers the cold-start
  case.

## What did NOT change

- **No new modes, screens, or notifications.** Track A is a single
  function + a 5-line hook. Track B is two new files + a 15-line
  integration in the existing History view.
- **No backend.** Both tracks read live stores already wired
  through `AuthManager`'s reload/endSession/wipe lifecycle.
- **No XP, no streak, no celebration on the breakdown card.**
  Track B is read-only history. Vision anti-goal (fake unlocks)
  respected.
- **No automatic AI regen on every profile save** — Track A's
  guard chain only fires the regen on an actual voice change, not
  on a same-voice re-save. The deterministic write is the cheap
  path; the AI upgrade is the bandwidth-aware path.
- **No friends scores.** Same reason as the prior HANDOFF —
  `PublicProfileSnapshot` schema change is backend work outside
  this push's scope.
- **No `coachNoteRevealed` cleanup.** The prior HANDOFF's "Risks"
  section explicitly flagged this as "left alone for safety"
  because the animation chain interleaves with other reveal
  timings. Touching it for a no-visible-change cleanup is the
  wrong risk/reward.

## Risks

1. **Voice-change regen fires off-thread relative to the AI
   upgrade Task spawned by the original finalize.** If a user
   finishes a rep, the AI upgrade Task is already in flight; then
   changes their voice; the regen kicks off a second deterministic
   write + second AI upgrade Task. If the original upgrade lands
   AFTER the regen's deterministic write, the store could briefly
   reflect the OLD-voice AI text (because the original Task only
   writes `if upgraded.isAIBacked`). The regen's own AI upgrade
   will eventually overwrite. Worst-case window: a few seconds
   where the chat coach quotes the old-voice AI line instead of
   the new-voice deterministic line. Acceptable given the regen's
   primary value is convergence to the new voice; the deterministic
   write is the safety net.

2. **Track A consumes the live `BaselineStore` + `BigMomentStore`
   state at regen time**, which may differ from the state at
   original rep time. For a user whose baseline has shifted since
   the rep, the regenerated note's metric sentence could read
   differently from a hypothetical "original-voice + original-
   baseline" reconstruction. The deterministic priority chain is
   mostly session-derived (fillerCount, score, duration), so this
   only matters in edge cases where the filler comparison branch
   would fire on one baseline but not the other. Acceptable —
   "current voice on this rep with current context" is the honest
   read.

3. **The breakdown card on History only reads from
   `SuddenDeathRunHistoryStore`, not the `SuddenDeathHighScoreStore`.**
   Both stores are written from the same `recordRun` call site in
   `SuddenDeathResultView.resolveHighScore` so they can't drift in
   practice, but if a future code path writes to the high-score
   store without writing to the run history store, the card's
   "best" stat could lag the actual peak.

4. **The breakdown card's average-rounds value is recomputed on
   every paint** via the `breakdowns` computed property. With a
   60-run cap and three difficulties, that's a trivial cost (a few
   `Dictionary(grouping:)` + reduce ops); not worth memoizing.
   Worth flagging if the cap is ever raised significantly.

5. **The breakdown card uses `Date.formatted(.relative(...))` for
   the "Last run" subtitle**, which allocates an internal
   `RelativeDateTimeFormatter`-equivalent on every paint. Same
   minor allocation cost as `SuddenDeathRecentRunsCard` — the
   History screen isn't a hot-render surface, so acceptable.

## Verification

### Implemented (compiler-locked, source-only)

- `PracticeSessionFinalizer.regenerationInput(...)` pure helper +
  `regenerateMostRecentNoteIfVoiceChanged(newVoice:)`
  orchestration (8 tests in `PostRepCoachNoteRegenerationInputTests`).
- `CoachingProfileStore.save(_:)` voice-change hook (exercised
  through the store-level replacement contract in
  `PostRepCoachNoteStoreRegenerationTests` — 3 tests).
- `SuddenDeathHistorySummary.breakdowns` /
  `totalRunCount` / `mostRecentDate` pure helpers (8 tests in
  `SuddenDeathHistorySummaryTests`).
- `SuddenDeathHistoryBreakdownCard` view — composes pure helper
  output into the hero card chrome. Visual QA on device required.
- `SessionHistoryView` integration — single `if
  selectedModeFilter == .suddenDeath` gate; cold-start hide is
  enforced by the card itself.

### Blocked / needs visual QA on device

No Swift toolchain in this container. Visual QA wants a build:

1. **Track A — Voice-change regen visible to Ask Noum** — finish a
   rep on the current voice, open Ask Noum and confirm the coach
   reads the rep in that voice. Go to Settings → Coaching, switch
   the voice, return to Ask Noum, send a message, confirm the
   coach now quotes the SAME rep in the new voice. The store's
   `latestNote()` should reflect the new voice between the two
   chat sessions without requiring a fresh rep.
2. **Track A — Cold-start no-op** — a fresh account with no reps
   yet completing onboarding and choosing a voice should NOT
   crash, NOT generate a phantom note, and NOT write anything to
   `PostRepCoachNoteStore` (the `latestNote() == nil` guard).
3. **Track A — Same-voice re-save no-op** — open onboarding (or
   the Settings voice picker), tap Save with the same voice
   selected, confirm no second AI call fires (the `latest.voice
   == newVoice` guard).
4. **Track A — Deleted-session defensive path** — finish a rep,
   delete the session from History, change voice in
   onboarding/settings; the regen should silently no-op (the
   `sessions.first(where:)` guard) and no crash should fire.
5. **Track B — Cold-start hide** — fresh account selecting the
   Sudden Death filter in History should see no breakdown card
   (the `breakdowns.isEmpty` check). Other filters should never
   render the card.
6. **Track B — One-difficulty render** — finish a Sudden Death run
   on Medium, open History, filter to Sudden Death, confirm the
   card renders a single Medium row with best/avg/clean stats
   matching the result.
7. **Track B — Three-difficulty sort** — finish runs on Easy →
   Hard → Medium in that order, filter to Sudden Death, confirm
   rows are sorted Medium / Hard / Easy (most-recently-played
   first).
8. **Track B — Filter clear** — switch from Sudden Death to "All"
   filter, confirm the breakdown card disappears (only renders
   inside the SD-filter scope).
9. **Track B — Auth wipe** — sign out, sign into a fresh account;
   the new account's History under the SD filter should show no
   breakdown card (the run history store wipes per-account via
   the prior session's AuthManager wiring).

### Assumptions

- `CoachingProfileStore.save(_:)` is the single mutating entry
  point for the active profile. Verified by `grep` — only
  `CoachingOnboardingView` calls it. `replaceFromRemote(_:for:)`
  is a separate path (remote sync) that does NOT trigger the
  voice-change regen because the remote write isn't user-driven;
  if a future remote-sync flow needs the regen, it can be added
  explicitly.
- `PracticeSessionStore.shared.sessions` contains the originating
  session for the latest PostRepCoachNote (true at finalize time;
  only the user explicitly deleting the session breaks this — the
  defensive guard handles it).
- `SuddenDeathRunHistoryStore.shared.runs` is published via
  `@Published` so the `@StateObject` on the History view re-
  paints when a new run lands (verified — the store's
  `@Published private(set) var runs` was set by the prior push).
- `AppColor.modeSuddenDeath` exists in `DesignSystem.swift` —
  confirmed via `grep` (used in `OnboardingHeroView`,
  `SettingsView`, `PracticeModeSelectionView`,
  `SuddenDeathRecentRunsCard`).

### What was checked

- `grep`'d every call site for `CoachingProfileStore.save` —
  single call site in `CoachingOnboardingView`. The hook is
  reached on every user-driven voice change without touching any
  other code path.
- `grep`'d `speakingStyleGoal:` assignments across the project —
  onboarding is the only mutating path; `DevSeedData` seeds
  per-profile via the dev-only `replaceForDebug(_:)` which
  bypasses `save(_:)` (correct — seeded data shouldn't trigger
  AI regens).
- Re-read `PostRepCoachNoteStore.record(_:)` — confirmed the
  sessionID dedupe replaces in place + the sort-by-generatedAt
  pulls the regenerated note to the front of `notes`, so
  `latestNote()` reads the new-voice line.
- Re-read `PostRepCoachNoteService.deterministicNote(input:)` —
  confirmed the persona switch reaches every sentence selector
  via `CoachPersona.persona(for:)`, so the regen's new voice
  actually flows through to phrasing.
- Re-read `SuddenDeathRunHistoryStore` — confirmed `runs` is
  `@Published` and ordered newest-first; the breakdown helper
  doesn't depend on input order (Dictionary grouping is
  order-agnostic).
- `grep`'d `selectedModeFilter` in `SessionHistoryView` —
  confirmed it's the single source of truth for the active
  filter; the new conditional render uses the same identifier
  the existing chips and section title already read.

## Files modified

- `Noum/SuddenDeathHistorySummary.swift` — NEW. Pure breakdown
  helper.
- `Noum/SuddenDeathHistoryBreakdownCard.swift` — NEW. SwiftUI
  hero card.
- `Noum/PracticeSupport.swift` —
  `CoachingProfileStore.save(_:)` voice-change hook +
  `PracticeSessionFinalizer.regenerationInput(...)` pure helper
  + `PracticeSessionFinalizer.regenerateMostRecentNoteIfVoiceChanged(newVoice:)`.
- `Noum/SessionHistoryView.swift` — `@StateObject
  suddenDeathRunHistoryStore` + SD-filter conditional render of
  the breakdown card.
- `NoumTests/NoumTests.swift` — 19 new tests across 3 suites:
  `SuddenDeathHistorySummaryTests` (8),
  `PostRepCoachNoteRegenerationInputTests` (8),
  `PostRepCoachNoteStoreRegenerationTests` (3).
- `HANDOFF.md` — this file.

## Branch

`Redesign` — committed and pushed per the user's brief.

Closes two of the five "Future moves" from the M24 Tracks 2 + 3
HANDOFF. The remaining three (friends Sudden Death scores,
`coachNoteRevealed` cleanup, AI generation gating) stay deferred
for the reasons noted in **Scope** above.

The artifact a user can now hold:

1. **Their coach actually changes voice.** Change your speaking
   style goal in onboarding; the next time you open Ask Noum, the
   coach quotes your last rep in the NEW voice — not the voice
   you'd already moved on from. The £130/hr coach pivots to where
   you are now, not where you were on your last rep.
2. **Their Sudden Death track record is visible from History.**
   Filter History to Sudden Death; the per-difficulty best /
   average / clean-run stats land at the top, sourced from the
   engine's own write path. Believable progress, no narrative.

Both moves are vision-aligned on the personalization (#5) and
believable-progress (#4) pillars of `docs/VISION.md`.

## Future moves

(Carried over from the prior HANDOFF, unchanged in priority order:)

1. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated
   refactor pass with proper visual QA, not a drive-by.
3. **AI generation gating** (carried over from M24 Track 1).
   Gate `PostRepCoachNoteService.generate` AI path behind a
   Premium flag or per-day rate limit so a heavy user doesn't
   burn 30+ AI calls a day. The voice-change regen this push
   landed can ALSO burn an AI call on every voice switch — if
   a user is exploring voices in onboarding, that could be
   several calls in quick succession. Gating + simple debounce
   would address both at once.
4. **`SuddenDeathRunHistoryStore` history export.** A "Share my
   run history" affordance on the Result screen — plain-text
   table of last 10 runs. Anti-goal-compliant; just data the user
   can paste anywhere.
5. **History-tab integration — full per-difficulty drill-down.**
   This push surfaces the per-difficulty summary on History; a
   deeper drill-down (tap a difficulty row → see every run at
   that difficulty, mirroring `SuddenDeathRecentRunsCard`'s list
   shape but unbounded) would be the natural next step. Pure
   navigation work; no new persistence.
6. **Mode-specific stat surfaces for History.** Once the SD
   pattern is proven, Ah-Counter, IM, and Timed could each carry
   their own mode-specific stat surface (Ah-Counter: filler-rate
   trend; IM: trust/tension averages; Timed: WPM distribution).
   The `SuddenDeathHistorySummary` shape generalises naturally.
