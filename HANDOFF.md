# HANDOFF — M24 deferred slate (round 27): a `.rejected` hypothesis acknowledgement is folded into `CoachMemory.adaptationLog` as a documented `CoachCourseChange` — the case file now carries the user's own pushback as the reason for changing course

## Scope

Round 26 closed the round-25 "Future moves" step #1 — the user
can now tap "confirmed / uncertain / rejected" on the working
hypothesis after the coach replies to a case-review opener, and
the verdict lands in durable `CoachMemory.hypothesisAcknowledgement`
with the hypothesis snapshot beside it.

The honest gap that left open: when the user lodged a *rejection*
("the working hypothesis does not match what I see"), the next
memory rebuild noticed the drift (the snapshot guard) and silently
dropped the ack — and if the lever / hypothesis text changed at
the same rebuild, the engine's existing `CoachCourseChange`
appended a *neutral* "Shifted focus from X to Y" entry, with no
record that the user themselves had asked the case to change. A
human coach would write "user pushed back on the read"; round 26
let Noum forget that.

Round 27 picks up step #1 from the round-26 "Future moves" list:

> 1. **Adaptation log entry on a `.rejected` ack.** A natural
>    follow-on now that the user can lodge a rejection: when
>    `CoachMemory.hypothesisAcknowledgement.confidence ==
>    .rejected`, the next `CoachMemoryEngine.build(...)` pass
>    could append a `CoachCourseChange` to the adaptation log
>    so the bounded case-change record carries the user's
>    pushback as the documented reason rather than the engine
>    silently inferring one. Pure-function lift on
>    `CoachMemoryEngine`; no new UI surface.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- `CoachMemoryEngine.build(...)` now hoists
  `newWorkingHypothesis` once at the top of the rebuild so both
  the adaptation-log decision and the final `CoachMemory` carry
  the same text without re-computing the clause.
- A pure-function `droppedRejectedAck` predicate fires when the
  previous memory's `hypothesisAcknowledgement.confidence ==
  .rejected` AND `ack.appliesTo(currentHypothesis:
  newWorkingHypothesis) == false` — i.e. the snapshot guard would
  drop the ack on this rebuild. That is the moment the user's
  pushback becomes case-file history rather than transient state.
- The `CoachCourseChange` append now reads from a 2×2 switch
  over `(priorLeverShift, droppedRejectedAck)`:
  - `(prior?, ack?)` — both signals fire. `reason` carries BOTH
    "Shifted focus from X to Y" AND "user reported the prior
    hypothesis did not match"; the documented reason is the user's
    report, not the engine inference.
  - `(prior?, nil)` — engine inference only (same shape as the
    round-pre-27 code path). Reason: "Shifted focus from X to Y."
  - `(nil, ack?)` — user-only revise (hypothesis text rewrote
    inside the same lever). Reason: "User reported the prior
    hypothesis did not match what they saw; revising the read."
  - `(nil, nil)` — unreachable in practice; defaulted to empty
    strings so the compiler can prove exhaustiveness without a
    `default` arm.
- `rejectedAckEvidenceBasis(ack:)` carries the user's own quoted
  snapshot as the evidence basis, truncated to ≤140 chars with a
  trailing ellipsis so a long hypothesis text still reads as a
  single skimmable clause in the coach-context block.
- Memory built unchanged for `.confirmed` / `.uncertain` acks:
  the snapshot guard still drops them on hypothesis drift, but
  the adaptation log stays clean — only the *rejection* branch
  documents a course change, because only rejection is the
  user-reported reason for changing course.
- The redesign-branch invariant: this is a `Redesign`-branch
  push per the user brief. The work lands directly on
  `Redesign`, preserving the round-by-round loop on the
  redesign lineage that has been the home of rounds 11–26.

## What shipped

### Track 1 — `CoachMemoryEngine.build(...)` rejection-aware course log (`PrimaryFocusMemory.swift`)

- New local `newWorkingHypothesis: String?` hoisted above the
  adaptation-log branch — same clause the final `CoachMemory`
  carries, with one call instead of two.
- New local `droppedRejectedAck: CoachHypothesisAcknowledgement?`
  computed once: non-nil iff the previous memory's ack is
  `.rejected` AND `appliesTo(currentHypothesis: newWorkingHypothesis)`
  returns false. The snapshot guard is the source of truth — the
  log fires exactly when the ack would be silently dropped.
- New local `priorLeverShift: SkillArea?` carries the prior lever
  iff it changed this rebuild. Same predicate the pre-27 code
  used inline, lifted so it can be combined with the rejection
  signal in a single switch.
- `previousLever` + `focusShiftedAt` still move only on a lever
  shift — `focusShiftedAt` stays scoped to lever changes, so a
  hypothesis-text revise inside the same lever doesn't pretend
  the user shifted focus. The adaptation log is the case-file
  history; `focusShiftedAt` is the in-memory "current lever
  landed at" timestamp.
- Single `CoachCourseChange` append per build pass — the
  `(prior?, ack?)` branch never produces two competing entries.
  The bounded `Array(adaptationLog.suffix(8))` cap is unchanged.

### Track 2 — `rejectedAckEvidenceBasis(ack:)` (`PrimaryFocusMemory.swift`)

- Private static helper that produces the `evidenceBasis` string
  for a user-pushback course change. Strips whitespace, truncates
  at 140 chars with a trailing `…` when the snapshot would
  otherwise dominate the adaptation-log line in the
  coach-context block.
- Defensive: an empty / whitespace-only snapshot falls back to
  `"user-tapped rejection on the prior read"` so the documented
  reason still surfaces a recognisable phrase rather than an
  empty-quotes line. The `CoachMemoryStore.noteHypothesisAcknowledgement`
  guard already refuses to persist an empty snapshot, so this
  path is unreachable in practice; the fallback is for the
  Codable-decoded boundary (a manually-crafted JSON that bypassed
  the store).

### Track 3 — `CoachMemoryEngineTests` rejected-ack adaptation log suite (`NoumTests/NoumTests.swift`)

Five new `@Test` methods land in the existing
`CoachMemoryEngineTests` suite (immediately after the round-pre-27
`buildAppendsAdaptationLogEntryOnFocusShift` /
`buildCarriesAdaptationLogForwardWhenFocusHolds` pair). Independent
fixtures — no helpers borrowed from the round-26 suite.

- **`buildLogsCourseChangeWhenRejectedAckIsDroppedByHypothesisRevise`.**
  Same lever (`.paceControl`), hypothesis text rewrites because
  the `evidenceCount` lifts from 2-session "tentative" to
  10-session "established". Asserts: one course-change entry,
  reason contains "User reported the prior hypothesis did not
  match", `evidenceBasis` carries the snapshot text, `fromLever
  == toLever == .paceControl`, ack is dropped post-build.
- **`buildLogsSingleCourseChangeWhenLeverShiftAndRejectedAckCoincide`.**
  Both signals fire: `.paceControl` → `.answerDevelopment` AND a
  `.rejected` ack on the prior hypothesis. Asserts: exactly ONE
  log entry, reason contains BOTH "Shifted focus from Pace to
  Depth" AND "user reported the prior hypothesis did not match",
  `evidenceBasis` is the user-pushback quote (not the engine's
  trend basis), ack is dropped post-build.
- **`buildDoesNotLogAdaptationForConfirmedOrUncertainAck`.**
  Same hypothesis-rewrite fixture as the first test, but the ack
  confidence is `.confirmed` / `.uncertain`. Asserts: the ack is
  still dropped by the snapshot guard, but the adaptation log
  stays `nil` — only `.rejected` documents a course change.
- **`buildDoesNotDoubleLogRejectedAckWhenHypothesisHolds`.**
  Fixture sized so `evidenceCount` lands at 3 → `.tentative` so
  the build produces the same "may be ... verify" hypothesis
  text the snapshot mirrors. Asserts: workingHypothesis matches
  the fixture text, adaptation log stays `nil`, ack persists
  with `.rejected` (the user has not yet re-evaluated). Pins the
  "no balloon on every rebuild" contract.
- **`buildTrimsLongRejectedSnapshotInEvidenceBasis`.**
  Snapshot is ~3× the 140-char cap. Asserts: `evidenceBasis`
  contains the trailing `…`, total length stays under 200 chars
  (cap + the `"user-tapped rejection of: \"…\""` lead).

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  the case formulation needs a "reason for changing course."
  Round 26 captured the user's verdict on the current
  hypothesis; round 27 turns a rejection into a durable line in
  the case-file history. The next session's coach can now read
  "Last course change: User reported the prior hypothesis did
  not match" and adapt the read in voice, instead of silently
  forgetting the pushback.
- **Pillar #5 (Personalized coaching).** A human coach jots down
  "user pushed back on the read" at the end of a session. The
  adaptation log is where Noum carries that note now. Without
  this lift the engine's silent inference would dominate the
  case file even when the user disagreed.
- **Pillar #4 (Believable progress).** A coach who can quote the
  user's own past pushback when explaining a revised read lands
  more credibly than one who pretends to invent the new read
  from telemetry. The context line already surfaces the latest
  entry (the existing `coachAdaptationLogLine`).
- **Anti-overclaim.** The `evidenceBasis` carries the user's own
  hypothesis snapshot in quotes — never the engine's paraphrase
  of "what the user meant". The reason copy never claims the
  hypothesis was *wrong*; it says the user *reported* it didn't
  match. Same restraint pattern the `lastReflectionReview`
  context line uses.
- **Anti-goal alignment (no hearts-and-lives gating).** A
  rejection still doesn't block anything — it doesn't lock the
  current intervention, it doesn't punish the user with a copy
  shame, it doesn't force the case into a new lever. It updates
  the durable case-file history and lets the next coach reply
  carry an honest revised read.

### Branch + redesign-alignment notes

- All three tracks land on `Redesign`, the redesign-lineage
  branch the rolling M24 deferred-slate work has been shipping
  on since round 11. The user brief explicitly calls this out:
  "ensure working on the redesign branch too (very important)."
  Round 27 preserves the round-by-round loop on the redesign
  lineage.
- Round 27 does not change the round-26 chip catalog, the
  `CoachContextBuilder.shouldShowHypothesisAcknowledgement(messages:)`
  predicate, the `CoachHypothesisAcknowledgement.appliesTo(...)`
  guard, or the `CoachMemoryStore.noteHypothesisAcknowledgement(_:)`
  mutation. The round-26 19-test suite remains unchanged. The
  round-27 5-test additions live inside the existing
  `CoachMemoryEngineTests` suite next to the pre-27
  adaptation-log tests.

## Future moves

(Updated priority list — round-27 closed the round-26 step #1;
the rest roll forward, plus new notes from round 27.)

1. **Surface the user-pushback line in the post-rep summary.**
   The adaptation log now carries the rejection, and the
   `coachAdaptationLogLine` already surfaces "Last course
   change: ..." in the coach context block, but the post-rep
   SummaryView does not yet show this to the user themselves
   ("you flagged the prior read as off; here's the revised
   one"). Pure UI lift, no new state — the data is already in
   `CoachMemoryStore.shared.currentMemory?.adaptationLog?.last`.
2. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation
   chain interleaving with celebration timing. Worth a
   dedicated refactor pass with proper visual QA (and a real
   device).
4. **Visual polish pass on the round-19 launch CTA.** Carried
   forward from rounds 19–26. Pure visual work, not destination
   logic.
5. **Visual polish pass on the round-20 SOLVED ribbon.**
   Carried forward from rounds 20–26. Pure visual work, not
   crossing logic.
6. **Extend the crossing helper to the chat-coach context
   line.** Carried forward from round 21 as a note for the
   record.
7. **Day-rollover refresh for long-mounted observers.**
   Carried forward from round 22.
8. **Tier-change observation symmetry to other surfaces that
   read `AIRateLimiter.currentCap()` directly.** Carried
   forward from round 23.
9. **Refresh-on-rotate for the empty-state chip when the
   `CoachMemoryStore` mutates while AskNoumView is mounted.**
   Carried forward from round 25.
10. **Voice-tuned ack-chip glyphs.** Carried forward from
    round 26.
11. **`.confirmed` confidence amplification on the active
    intervention.** New note from round 27. The flip side of
    rejection-becomes-course-change: a `.confirmed` ack on a
    held hypothesis could nudge
    `CoachIntervention.criterionStatus` toward "met" or
    extend the `reviewDueAt` cadence, since the user has
    independently endorsed the working read. Pure-function
    lift on `CoachMemoryEngine` similar to this round; would
    pair well with a round-of-evidence floor so the
    confirmation doesn't lift the cadence on a single
    enthusiastic tap.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so
nothing in this round was compiled or run — not the app, not
the test suite. The changes are:

- One restructure of `CoachMemoryEngine.build(...)`
  adaptation-log branch (PrimaryFocusMemory.swift). The
  hoisted `newWorkingHypothesis`, `droppedRejectedAck`, and
  `priorLeverShift` locals replace the previous inline
  `if let prior = previous?.currentLever ... { ... }` block
  with an exhaustive switch over `(priorLeverShift,
  droppedRejectedAck)`. Same `CoachCourseChange` shape as
  before; same `Array(adaptationLog.suffix(8))` bounded cap.
- One new private static helper (`rejectedAckEvidenceBasis`)
  on `CoachMemoryEngine`, placed next to the existing
  `workingHypothesis(lever:evidenceConfidence:)` private
  static.
- One line removed: the second `workingHypothesis(...)` call
  inside the `CoachMemory(...)` initialiser is now
  `newWorkingHypothesis` (reuses the hoisted local).
- Five new `@Test` methods in `CoachMemoryEngineTests`,
  inserted after the existing
  `buildAppendsAdaptationLogEntryOnFocusShift` /
  `buildCarriesAdaptationLogForwardWhenFocusHolds` pair, using
  the suite's existing `session()` / `profile(voice:)`
  helpers.

All checks the next agent should run on a real build host:

1. `swift test --filter CoachMemoryEngineTests` — the new
   round-27 tests (5 added; total 7 adaptation-log tests
   including the round-pre-27 pair) should all pass, and the
   pre-27 tests should still pass with the restructured branch.
2. `swift test --filter HypothesisAcknowledgementTests` — the
   round-26 tests (19 total in the struct) should still pass.
   No round-26 surface was changed.
3. `swift test --filter InterventionReviewPromptTests` — the
   round-24 + round-25 tests (26 total) should still pass.
4. `swift test --filter CoachMemoryStoreTests` — the existing
   memory-store tests should still pass with the new optional
   field present in the JSON round-trip.
5. `swift test --filter CoachReadCardDailyBudgetHintTests` —
   the round-23 tests should still pass.
6. `swift test --filter AIRateLimiterPublicationTests` — the
   round-22 tests should still pass.
7. `swift test --filter IMToneDrillCrossingTests` — the
   round-21 helper tests should still pass.
8. `swift test --filter HeroScoreCardToneDrillRibbonContractTests`
   — the round-20 ribbon-contract tests should still pass.
9. `swift test --filter LookingAheadCardStartCTAContractTests`
   — the round-19 launch-CTA tests should still pass.
10. Boot the app on simulator, seed a
    `CoachMemory.activeIntervention` with a working hypothesis
    and a non-empty followed-rep count, tap "Review with coach"
    on `InterventionReviewPromptCard`, wait for the coach reply,
    tap the **Adapt / rejected** chip. Confirm:
    - The chip dispatches a user reply (the round-26 contract).
    - `CoachMemoryStore.shared.currentMemory?.hypothesisAcknowledgement?.confidence`
      is `.rejected`.
    - `adaptationLog` is unchanged (no new entry yet — the
      ack still applies to the current hypothesis).
    - Finish a new rep where the lever changes OR where the
      hypothesis text rewrites (e.g. evidence-count crosses a
      `BaselineConfidence` threshold), triggering a
      `CoachMemoryEngine.build(...)` pass. Confirm
      `adaptationLog.last.reason` contains "user reported the
      prior hypothesis did not match" and `evidenceBasis`
      carries the quoted snapshot text.
    - The next AI coach reply (via `AskNoumView`) reads as
      voice-shaped acknowledgement of the adapt + a revised
      read, with the existing `coachAdaptationLogLine` ("Last
      course change: ...") surfacing the user-pushback reason.
    - Repeat with a `.confirmed` / `.uncertain` ack across a
      hypothesis rewrite — the ack still drops by the snapshot
      guard, but the adaptation log stays unchanged (the
      `.rejected`-only contract).
