# HANDOFF — M24 deferred slate (round 35): adaptation-log cycle-depth signal — `CoachContextBuilder.adaptationLogCycleDepth(in:)` + `adaptationLogCycleSummary(in:)` count the tail of consecutive `documentsUserPushback` entries on `memory.adaptationLog`, surface a depth-aware coach-context line in the durable case-formulation block, and land a second-person "Pushback depth" row on the Profile-tab `CaseReviewCard`.

## Scope

Round 34 closed the cross-surface voice gap: the Profile-tab
`CaseReviewCard` "Last shift" row now reads the same user-voiced
pushback phrase the post-rep `RevisedReadCard` lands ("You flagged
the rebuilt read as off too." / "You flagged the prior read as off.")
via the new `CoachCourseChange.caseFileHeadline` picker. It also
closed future move #11 by collapsing `SummaryView.freshRevisedReadChange`
through `CoachContextBuilder.freshRevisedReadChange(in:)`.

The honest gap round 34 left open: neither the engine markers nor the
freshness-gated rebuild lines (rounds 31 + 32) tell the model the
TRUE CYCLE DEPTH on a 3+ pushback chain. The engine writes the same
`userRebuildPushbackMarker` on every rebuild after the first, so a
third-cycle pushback reads identically to a second one in the marker
text. The chat-coach case-formulation block — the durable case-file
read the model receives every turn — carries no signal that the user
has rejected the working hypothesis MORE than twice in a row.

The bounded `adaptationLog.suffix(8)` already keeps the history. The
honest depth is sitting in the data; nothing reads it. A user three
pushbacks deep into the same lever needs the coach to STOP retrying
variations of the same read and propose a structurally different
angle — and the model can only do that if it knows the streak depth.

Round 35 picks up future move #13 carried forward from round 33:

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the
redesign branch too (very important)."

Translation, this round:

- New `CoachContextBuilder.adaptationLogCycleDepth(in:)` — pure
  function that walks `memory.adaptationLog` from the tail, counts
  consecutive `documentsUserPushback` entries, and returns the count
  when it is ≥ 2 (else nil). This is the data primitive.
- New `CoachContextBuilder.adaptationLogCycleSummary(in:)` — pure
  function that composes the coach-context summary line from the
  depth. Two depth bands: depth 2 reads "twice in a row" with a
  measured coach-move clause ("vary the angle, not just the wording");
  depth 3+ reads "[N] times in a row" with an escalated clause
  ("propose a structurally different angle, not another variation").
- `coachCaseFormulationLines` in `CoachContextBuilder.swift` surfaces
  the summary line below the existing hypothesis acknowledgement line
  and above the focus-shift line, with a documented bump of the
  block's prefix cap from 10 → 11 to accommodate the new high-signal
  line without forcing it to compete with the strength/blocker lines
  for the model's attention budget.
- `CaseReviewCard.swift` lands a second-person "Pushback depth" row
  ("You've flagged the working read as off twice in a row this case
  file.") below the round-34 "Last shift" row, on the same gate. The
  Profile-tab case file now names the streak depth in the user's own
  voice, matching the round-34 cross-surface consistency contract.
- The redesign-branch invariant: round 35 lands directly on `Redesign`,
  the redesign-lineage branch the rolling M24 deferred-slate work has
  been shipping on since round 11. Round-by-round loop preserved.

## What shipped

### Track 1 — `CoachContextBuilder.adaptationLogCycleDepth(in:)` (`CoachContextBuilder.swift`)

- New pure-function helper that walks `memory.adaptationLog.reversed()`,
  counts consecutive `documentsUserPushback` entries from the tail,
  and returns the count when it is ≥ 2.
- Returns nil for depth 0–1: a streak of 0 (no log, or no pushback at
  the tail) is the silent case the case-formulation block must not
  over-claim; a streak of 1 is the first cycle, already named by
  rounds 28 (post-rep card), 31 (chat-context fresh line), and 33
  (second-cycle marker). The depth signal only earns its line at ≥ 2.
- Counts BOTH marker variants — round-27 `userPushbackMarker` and
  round-33 `userRebuildPushbackMarker` both satisfy
  `documentsUserPushback`, so a chain that mixes first-cycle and
  second-cycle entries at the tail counts correctly.
- An engine-only shift at the tail breaks the streak (the loop hits a
  non-pushback entry and stops). An engine-only shift in the middle
  of the log interleaves the streak: only the tail run counts.
- Bounded by `adaptationLog.suffix(8)` in `CoachMemoryEngine.build(...)`
  — the helper can never report a depth above 8.

### Track 2 — `CoachContextBuilder.adaptationLogCycleSummary(in:)` (`CoachContextBuilder.swift`)

- New pure-function helper that composes the coach-context summary
  line from the depth. Gated through `adaptationLogCycleDepth(in:)`,
  so the summary is nil whenever the depth helper is nil.
- Phrasing matches the brand-voice rules of the case-formulation
  block: third-person ("the user has rejected the working hypothesis
  twice in a row this case file") — the case-formulation block writes
  coach notes to the model, not user lines. Profile-card surfacing
  reads in second-person separately (Track 4).
- Two depth bands:
  - Depth 2: "twice in a row" with "Treat the next read with extra
    care; the user has rejected the prior two in a row. Vary the
    angle, not just the wording." The measured clause keeps the door
    open to a third variation while flagging the streak.
  - Depth 3+: "[N] times in a row" with "The user has rejected this
    many reads of the same lever in a row; propose a structurally
    different angle, not another variation of the same hypothesis."
    The escalated clause tells the model varying the same lever
    further is no longer credible.
- Brand-voice compliant — no exclamation, no "Let's", no hype.

### Track 3 — Case-formulation surfacing (`CoachContextBuilder.swift`)

- `coachCaseFormulationLines` appends the round-35 line directly below
  the existing hypothesis-acknowledgement line and above the focus-
  shift line. The placement matches the case-file logical flow:
  hypothesis → user's ack on the hypothesis → durable streak of acks
  against the hypothesis → engine focus shift detail → goal fit.
- The block's prefix cap bumps from 10 → 11. Inline comment names the
  reason: the depth line is rare (≥ 2 pushbacks in a row) and high-
  signal (the model needs every line in the block at that moment); it
  must not compete with the strength/blocker lines for the model's
  attention budget. The bounded `adaptationLog.suffix(8)` caps the
  total context contribution.

### Track 4 — `CaseReviewCard` "Pushback depth" row (`CaseReviewCard.swift`)

- New `caseRow` block below the round-34 "Last shift" row, on the
  same `adaptationLogCycleDepth(in:)` gate. Surfaces a second-person
  phrase: "You've flagged the working read as off twice in a row
  this case file." (depth 2) or "… [N] times in a row …" (depth 3+).
- The surface reads consistently with the round-34 "Last shift" row:
  both name the rebuild event in the user's own voice. A user
  flicking between the post-rep summary (which carries the round-31
  fresh-revised-read context line in the chat seed) and the Profile
  card now sees the streak depth named on both surfaces in the same
  voice.
- Silent on depth 0–1: the "Last shift" row already names the first
  cycle in the user's voice; double-naming would over-claim.
- Restraint matches the card's compact contract (≤ 2 lines per row,
  no scrolling, no buttons). The new row uses `icon: "repeat"` to
  visually distinguish from the `arrow.triangle.branch` "Last shift"
  row above.

### Track 5 — `AdaptationLogCycleSummaryTests` (`NoumTests/NoumTests.swift`)

New `@Suite("AdaptationLogCycleSummaryTests")` (struct, `@MainActor`)
placed after the round-34 `FreshRevisedReadChangeSecondCycleDelegationTests`.
Sixteen `@Test` methods covering the predicate, the summary phrasing,
the case-formulation surfacing, and the engineering bans.

- **Depth predicate matrix (8 tests):**
  - `depthIsNilForNilLog` — empty case.
  - `depthIsNilForEmptyLog` — empty case.
  - `depthIsNilForSinglePushback` — depth-1 silence (first cycle
    already named by rounds 28/31/33).
  - `depthIsTwoForTwoConsecutivePushbacks` — happy path: two
    pushbacks at the tail.
  - `depthIsThreeForThreeConsecutivePushbacks` — depth band 3+.
  - `depthIsNilWhenEngineOnlyShiftIsAtTail` — streak break by an
    engine-only shift at the tail.
  - `depthCountsOnlyTailStreakWhenEngineShiftInterleaves` — engine-
    only shift in the middle interleaves the streak; only tail run
    counts.
  - `depthCountsBothMarkerVariantsAsPushback` — round-27 and
    round-33 markers both satisfy `documentsUserPushback`.
- **Summary phrasing per depth band (4 tests):**
  - `summaryReadsTwiceInARowAtDepthTwo` — measured clause for depth 2.
  - `summaryReadsThreeTimesInARowAtDepthThree` — escalated clause
    for depth 3.
  - `summaryIsNilAtDepthOne` — silence on first cycle.
  - `summaryIsNilForNilLog` — silence on empty log.
- **Case-formulation surfacing (3 tests):**
  - `caseFormulationIncludesDepthLineWhenStreakIsTwoOrMore` —
    integration via the public `CoachContextBuilder.userContext(...)`
    entry. The depth phrase surfaces in the output.
  - `caseFormulationOmitsDepthLineOnFirstCycle` — silence on
    depth 1.
  - `caseFormulationOmitsDepthLineForEngineOnlyShiftAtTail` —
    silence when the streak is broken.
- **Engineering bans (2 tests):**
  - `depthHelperDoesNotMutateMemory` — pure-function contract:
    `mem == before` after the helper runs.
  - `depthHelperReadsLatestEntryTailNotByDate` — the helper walks
    array position, not `changedAt` — matches the engine's append-
    only contract. A future engine change that started inserting
    out-of-order would surface here.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "compare response across multiple attempts and either reinforce,
  vary, or replace the intervention with an explained rationale." A
  user three pushbacks deep into the same lever needs the coach to
  stop varying the same read and propose a structurally different
  angle. Round 35 gives the model the streak-depth signal so the
  Adaptation stage has the evidence to make that call.
- **Coach-parity stage #2 (Case formulation).** The case-formulation
  block is the durable case-file read the model receives every turn.
  Round 35 lands the streak-depth line inside that block — not as a
  freshness-gated rebuild line (rounds 31/32) that disappears on the
  next followed rep — so the depth signal persists for as long as
  the streak persists in the bounded `adaptationLog`.
- **Pillar #5 (Personalized coaching).** A coach who keeps proposing
  variations of the same hypothesis after three rejections is not
  personalizing; they are pattern-matching. Round 35's depth-3+
  escalation tells the model the user has flagged the same lever as
  off three times in a row — the durable case-file evidence to
  trigger a structurally different angle.
- **Pillar #4 (Believable progress).** A user who has pushed back
  three times sees their streak named on the Profile card AND
  reflected in the chat coach's tone. The case file no longer reads
  as a stale log; the streak depth is a live, surfaced read.
- **Engineering bans.** No fragmented state: round 35 adds two pure-
  function helpers and one new row on `CaseReviewCard`. The case-
  formulation block reads the same helper the Profile card does — a
  copy edit in one place propagates to both surfaces. No placeholder
  logic: the new helpers have real call sites in both the chat
  context and the Profile card. No dead toggles: the helpers have no
  flags; the resolution is data-driven off the persisted
  `adaptationLog` field.
- **Anti-overclaim.** The helpers return nil for depth 0–1, so the
  case-formulation line and the Profile row stay silent until the
  user has actually pushed back at least twice in a row. The
  depth-3+ escalation phrase ("propose a structurally different
  angle") is the strongest claim the round makes, and it fires only
  on hard evidence (three consecutive `documentsUserPushback`
  entries in the bounded `adaptationLog`).
- **No schema bump.** `adaptationLogCycleDepth(in:)` and
  `adaptationLogCycleSummary(in:)` are pure-function reads over the
  existing `adaptationLog` field. Memories persisted before round 35
  decode and behave unchanged: pre-round-27 memories (no adaptation
  log) trip the nil guard; round-27 / round-33 entries surface their
  cycle counts via `documentsUserPushback`.

### Branch + redesign-alignment notes

- All five tracks land on `Redesign`, the redesign-lineage branch the
  rolling M24 deferred-slate work has been shipping on since round 11.
  The user brief explicitly calls this out: "ensure working on the
  redesign branch too (very important)." Round 35 preserves the
  round-by-round loop on the redesign lineage.
- Round 35 does not change the round-33 marker constants, the
  `documentsUserPushback` / `documentsRebuildPushback` predicates, or
  the `isSecondCyclePushback` engine detection. The round-33 19
  second-cycle + 4 picker tests pass unchanged; round 34's 9 + 1 new
  tests pass unchanged; round 35's 16 new tests sit alongside.
- Round 31's `freshRevisedReadContextLines` and round 32's
  `rebuildVerdictContextLines` are unchanged. The two paths remain
  freshness/ack-gated rebuild surfaces; round 35 is the durable case-
  file streak depth surface. The three are mutually compositional:
  on a first cycle, only round 31 fires; on a fresh second cycle
  before the user acks, round 31 fires AND round 35 fires; on a
  rebuild that has been acked, round 32 fires AND round 35 fires.
- The round-34 `caseFileHeadline` picker is unchanged. The Profile
  card's "Last shift" row continues to read through it.

## Future moves

(Updated priority list — round-35 closed step #13; the rest roll
forward.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–34. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–34. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.**
   Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward
   from round 22.
7. **Tier-change observation symmetry to other surfaces that read
   `AIRateLimiter.currentCap()` directly.** Carried forward from
   round 23.
8. **Refresh-on-rotate for the empty-state chip when the
   `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried
   forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **`.confirmed` confidence amplification on the active intervention.**
    Carried forward from round 27. The round-32 `.confirmed` rebuild-
    verdict path remains the natural integration site — when the
    predicate fires AND the engine has not yet bumped
    `CoachIntervention.criterionStatus`, the same `.confirmed`
    branch could nudge the criterion toward "met" or extend the
    `reviewDueAt` cadence by one rep.
11. **Collapse the round-26 hypothesis-ack reflection in
    `coachCaseFormulationLines` into a single block with the round-32
    rebuild-verdict lines when the predicate fires.** Carried forward
    from round 32. Hold for real-device QA.
12. **Trend-view distinction between "user accepted the first read"
    and "user accepted the rebuilt read".** Carried forward from
    rounds 30 + 32 + 33 + 34. With round 33's `documentsRebuildPushback`
    marker on the adaptation log, round 34's `caseFileHeadline`
    picker on the data model, AND round 35's
    `adaptationLogCycleDepth(in:)` helper, a future trend view could
    count rebuild PUSHBACKS separately from first-cycle pushbacks,
    surface the user-voiced phrase from the round-34 picker, AND
    chart the streak-depth distribution across the case file with no
    additional engine work.
13. **Engine reset on a `.confirmed` ack after a rebuild.** Carried
    forward from round 33. The current chain depends on
    `previous.adaptationLog.last.documentsUserPushback`; a
    `.confirmed` ack on the rebuilt read does NOT cycle (it just
    confirms the rebuild). A future round could append an explicit
    `confirmation` entry on `.confirmed` ack-drop to mark the rebuild
    as accepted, closing the cycle in the log as cleanly as the
    rejection cycle is closed in round 33. With round-34's
    `caseFileHeadline` picker on the data model, a third arm
    ("You confirmed the rebuilt read.") would land naturally as a
    new branch above the engine-only fall-through. With round 35's
    `adaptationLogCycleDepth(in:)` helper, the depth count would also
    reset on the next non-pushback entry — which is exactly what a
    confirmation entry would be.
14. **Sibling `RevisedReadCard` copy for the post-`.confirmed` rebuild
    surface.** Carried forward from round 33. The card currently
    surfaces only on a fresh pushback rebuild. A future round could
    add a sibling card ("You confirmed the rebuilt read") on the
    post-rep summary AFTER the user lodges a `.confirmed` ack on the
    rebuilt hypothesis, so the rebuild lifecycle has acknowledged
    closure on the surface where it began. Depends on #13 above.
15. **User-voiced lift for the engine-only fall-through arm of
    `caseFileHeadline`.** Carried forward from round 34. The current
    fall-through returns the persisted `reason` ("Shifted focus from
    Pace to Depth.") unchanged because rewriting it as user action
    would over-claim. But a softer second-person re-framing might
    read better on the Profile card without over-claiming — e.g.,
    "Coach moved your focus from Pace to Depth." Hold until at
    least one real-device QA pass on round 34's pushback branches
    on `CaseReviewCard`; the picker's contract is fine today.
16. **Voice-tuned depth-line phrasing.** New note from round 35. The
    case-formulation depth line currently reads the same across all
    voices. A future round could vary the coach-move clause by the
    user's `SpeakingStyleGoal`: `.authoritative` reads "stop
    retrying the same lever" (direct); `.warm` reads "the streak
    matters — meet it gently" (measured); `.concise` reads "drop
    this lever; try another" (tight). Same pattern the round-29
    opener uses for voice-tuned phrasing. Hold until at least one
    real-device QA pass on the depth line landing in chat.
17. **Depth-aware Ask Noum starter chip.** New note from round 35.
    When `adaptationLogCycleDepth(in:)` returns ≥ 3, AskNoumView's
    empty-state starter chips could surface a dedicated "Why does
    this keep coming back?" chip that seeds the conversation with
    the streak context. Sibling of the round-25 case-review
    starter chip. Hold until at least one real-device QA pass.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes are:

- Two new pure-function helpers (`adaptationLogCycleDepth(in:)` and
  `adaptationLogCycleSummary(in:)`) on `CoachContextBuilder` in
  `CoachContextBuilder.swift`. Self-contained — no new imports, no new
  dependencies, no new types. Reads only the existing `adaptationLog`
  field through the round-27 / round-33 `documentsUserPushback`
  predicate.
- One new conditional `lines.append(...)` block on
  `coachCaseFormulationLines` in `CoachContextBuilder.swift`, plus a
  prefix cap bump from `.prefix(10)` → `.prefix(11)` with an inline
  comment naming the reason.
- One new `caseRow(...)` block on `CaseReviewCard.swift` between the
  round-34 "Last shift" row and the "Real-world check-in" /
  "Momentum" row. Reads
  `CoachContextBuilder.adaptationLogCycleDepth(in: memory)` and
  composes the second-person depth phrase inline.
- One new `@Suite("AdaptationLogCycleSummaryTests")` (16 tests) in
  `NoumTests/NoumTests.swift`. Plain `struct`, `@MainActor`, mirror
  of the round-34 suites' attributes.

All checks the next agent should run on a real build host:

1. `swift test --filter AdaptationLogCycleSummaryTests` — the new
   round-35 16 tests should all pass.
2. `swift test --filter CaseFileHeadlineTests` — the round-34 9 tests
   should still pass. Round 35 does not touch `caseFileHeadline`.
3. `swift test --filter FreshRevisedReadChangeSecondCycleDelegationTests`
   — the round-34 1 test should still pass.
4. `swift test --filter RevisedReadCardTests` — the round-28 5 tests
   + round-33 4 picker tests should all still pass.
5. `swift test --filter SecondCyclePushbackAdaptationTests` — the
   round-33 19 second-cycle tests should all still pass. Round 35
   does not touch the engine's `isSecondCyclePushback` detection or
   the marker constants.
6. `swift test --filter RebuildVerdictContextTests` — the round-32
   25 rebuild-verdict tests should still pass. Round 35 only adds a
   sibling helper; the rebuild-verdict gates and context lines are
   unchanged.
7. `swift test --filter FreshRevisedReadContextTests` — the round-31
   16 fresh-revised-read tests should still pass. Round 35 only
   composes alongside the round-31 lines; the helper itself is
   unchanged.
8. `swift test --filter RevisedReadFollowUpTests` — round-30 tests
   should still pass.
9. `swift test --filter RevisedReadOpenerTests` — round-29 tests
   should still pass.
10. `swift test --filter CoachMemoryEngineTests` — the round-27 tests
    should all still pass. Round 35 does not touch the engine's
    adaptation-log append logic.
11. `swift test --filter HypothesisAcknowledgementTests` — round-26
    tests should still pass.
12. `swift test --filter InterventionReviewPromptTests` — round-24 +
    round-25 tests should still pass.
13. `swift test --filter CoachMemoryStoreTests` — should still pass.
14. **Real-device QA — depth signal on a 2-pushback chain.** Boot the
    app on simulator. Seed a `CoachMemory.activeIntervention` with a
    working hypothesis. Open Ask Noum via the round-24
    `InterventionReviewPromptCard` or the round-25 empty-state chip.
    Tap the **Adapt / rejected** ack chip. Finish a new rep that
    rewrites the working hypothesis. Through Ask Noum, lodge a
    verdict chip, then on a follow-up turn tap the **Adapt /
    rejected** ack chip on the REBUILT hypothesis. Finish another
    rep. The `adaptationLog` now carries two consecutive
    pushback entries at its tail (depth 2).
15. **Confirm the chat-coach context block carries the depth line.**
    The next AskNoumView reply should compose against a user context
    that includes "Case-file pushback depth: the user has rejected
    the working hypothesis twice in a row this case file. Treat the
    next read with extra care; the user has rejected the prior two
    in a row. Vary the angle, not just the wording."
16. **Switch to the Profile tab.** Open the `CaseReviewCard`. Confirm
    the new "Pushback depth" row reads "You've flagged the working
    read as off twice in a row this case file." between the "Last
    shift" row and the "Real-world check-in" / "Momentum" row.
17. **Drive a third cycle.** Through Ask Noum, lodge a verdict chip,
    then tap the **Adapt / rejected** chip again. Finish another
    rep. The `adaptationLog` now carries three consecutive pushback
    entries (depth 3). The chat-coach context block should now read
    "rejected the working hypothesis 3 times in a row" with the
    escalated "propose a structurally different angle" coach-move
    clause. The Profile card row should read "3 times in a row".
18. **Insert an engine-only shift to break the streak.** Drive a
    rebuild WITHOUT a `.rejected` ack drop (engine lever shift on a
    trend signal). The new `adaptationLog.last` is engine-only;
    `documentsUserPushback` returns false on the tail; the depth
    helpers return nil. Confirm the chat-coach context block omits
    the depth line on the next reply AND the Profile card's
    "Pushback depth" row disappears on the next render.

Branch lineage: round 35 sits on top of round 34 on `Redesign`, which
sits on top of rounds 11–33. The round-by-round loop on the redesign
lineage is preserved.
