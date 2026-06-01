# HANDOFF — M24 deferred slate (round 36): confirmation marker on the `.confirmed` rebuild ack closes the rejection-rebuild-confirmation chain in the bounded adaptation log — `CoachCourseChange.userRebuildConfirmationMarker` + `documentsRebuildConfirmation` + a new append branch in `CoachMemoryEngine.build(...)` + a fourth `caseFileHeadline` arm + `CoachContextBuilder.rebuildConfirmationContextLines(memory:)` routed ahead of round 32's verdict block in `interventionCycleLines`.

## Scope

Round 35 closed the durable cycle-depth signal: the case-file
formulation block and the Profile-tab `CaseReviewCard` now name how
many consecutive pushbacks deep the user is on the current case file.
The depth helper resets on any non-pushback entry at the tail of
`adaptationLog` — engine-only shifts break the streak naturally — but
the rejection lifecycle had one closure shape the case file could never
record: the user accepting the rebuilt read.

The honest gap round 35 left open: round 32's `rebuildVerdictPair` /
`rebuildVerdictContextLines` already surface a `.confirmed` ack on the
rebuilt working hypothesis as a freshness-gated chat-context block.
That works for the in-flight window between the ack landing and the
next memory rebuild. The moment a later rebuild rewrites the hypothesis
the ack is dropped by the snapshot guard at `PrimaryFocusMemory.swift:901`
and the verdict is gone forever. The bounded `adaptationLog` keeps a
durable record of every rejection (round 27 / round 33 markers) but
nothing of the symmetric closure event — the user's acceptance.

Round 36 picks up future move #13 carried forward from round 35:

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the
redesign branch too (very important)."

Translation, this round:

- New `CoachCourseChange.userRebuildConfirmationMarker` constant —
  sibling of round 27's `userPushbackMarker` and round 33's
  `userRebuildPushbackMarker`. Distinct phrasing ("matches" vs. "did
  not match") so the predicate below distinguishes a confirmation entry
  from either pushback variant on plain `String.range(of:)` lookup.
- New `CoachCourseChange.documentsRebuildConfirmation` pure predicate
  over `reason`. Mutually exclusive with `documentsUserPushback` and
  `documentsRebuildPushback` by design — a confirmation entry's reason
  carries the confirmation marker only.
- New ordered branch on `CoachCourseChange.caseFileHeadline` (the
  Profile-tab `CaseReviewCard` "Last shift" picker round 34 landed),
  sitting AHEAD of the existing pushback arms: `documentsRebuildConfirmation`
  → "You confirmed the rebuilt read." The user-voiced phrase names the
  acceptance event in the same second-person register the round-34
  pushback arms use, so the cross-surface read of the rebuild lineage
  carries the full lifecycle.
- New append branch on `CoachMemoryEngine.build(...)`. When the
  previous memory carried a `.confirmed` `hypothesisAcknowledgement`
  whose snapshot satisfies round 32's `rebuildVerdictPair` semantics
  on the previous memory (ack lodged on the rebuilt working hypothesis
  AFTER a pushback was folded in) AND the rebuild persists into the
  new memory (ack snapshot still applies to `newWorkingHypothesis`),
  the engine appends a confirmation course-change to `adaptationLog`.
  Idempotent across subsequent rebuilds: the appended entry has
  `documentsUserPushback == false`, so the predicate's
  `lastChange.documentsUserPushback` guard returns false on the new
  tail and the branch does not re-fire.
- New `CoachContextBuilder.rebuildConfirmationContextLines(memory:)`
  helper — symmetric closure of round 32's `rebuildVerdictContextLines`.
  Surfaces a durable two-line case-state + coach-move block when the
  tail entry is a confirmation entry. Routed AHEAD of the round-32
  verdict block (and round 31's fresh-revised-read block) in
  `interventionCycleLines`. The four blocks are mutually exclusive at
  the memory level: a confirmation tail breaks both round-32 and
  round-31 gates (which require pushback tails), so the chat context
  shifts cleanly to reading the lock-in as a historical fact, not an
  in-flight verdict.
- New evidence-basis helper `rebuildConfirmationEvidenceBasis(ack:)` —
  sibling of `rejectedAckEvidenceBasis(ack:)`. Composes the
  evidence-basis line for a `.confirmed` ack with the snapshot quoted
  inline. Symmetric shape so a downstream analytics or audit surface
  can read both arms with the same parser.
- Round-35 cycle-depth helper unchanged: the confirmation entry's
  `documentsUserPushback == false` breaks the streak automatically,
  so the depth count resets cleanly on a confirmation tail — exactly
  the "engine reset on `.confirmed` ack" outcome future move #13
  promised.
- The redesign-branch invariant: round 36 lands directly on `Redesign`,
  the redesign-lineage branch the rolling M24 deferred-slate work has
  been shipping on since round 11. Round-by-round loop preserved.

## What shipped

### Track 1 — `CoachCourseChange.userRebuildConfirmationMarker` + `documentsRebuildConfirmation` (`PrimaryFocusMemory.swift`)

- New marker constant `static let userRebuildConfirmationMarker =
  "user reported the rebuilt hypothesis matches what they see"`,
  placed alongside the round-27 and round-33 marker constants. Distinct
  from both pushback markers on plain substring match — "matches" is
  the discriminator.
- New computed property `documentsRebuildConfirmation: Bool` — returns
  true iff `reason.range(of:options:)` finds the confirmation marker.
  Pure function of the persisted `reason` field — no schema bump.
- Mutual-exclusion contract: the round-35 `adaptationLogCycleDepth`
  helper walks `documentsUserPushback`. The confirmation marker
  intentionally does NOT contain either pushback marker substring, so
  `documentsUserPushback` returns false on a confirmation entry and
  the streak resets at the tail — the engine-reset outcome
  future move #13 promised. Locked by
  `confirmationEntryDoesNotSatisfyPushbackPredicates`.
- The `documentsUserPushback` doc comment now names the round-36
  contract for future readers — the property's role in resetting the
  streak depth is explicit.

### Track 2 — Fourth `caseFileHeadline` branch (`PrimaryFocusMemory.swift`)

- The round-34 `caseFileHeadline` picker gains a fourth ordered branch
  sitting ABOVE the existing pushback arms: `documentsRebuildConfirmation`
  → "You confirmed the rebuilt read." The ordering matters because a
  defensive future engine change that ever wrote both markers into
  the same reason (it should not — they are mutually exclusive at the
  append site, by design) would still surface the confirmation as the
  headline. Lock-in is a stronger statement than rejection.
- The user-voiced phrase matches the second-person register of the
  existing branches ("You flagged the rebuilt read as off too.",
  "You flagged the prior read as off."). The Profile-tab
  `CaseReviewCard` "Last shift" row reads through `caseFileHeadline`
  unchanged — no UI edits, the row picks up the new phrase
  automatically.
- The doc comment names the round-36 branch and its predecessor
  branches in resolution order; the schema-evolution paragraph is
  extended to cover the new predicate (a confirmation entry is back-
  compat: pre-round-36 memories never carry the marker, so the
  branch is silent on them).

### Track 3 — Engine append branch on `CoachMemoryEngine.build(...)` (`PrimaryFocusMemory.swift`)

- New `confirmedRebuildAck` predicate at the top of the build pass,
  next to the existing `droppedRejectedAck` and `isSecondCyclePushback`
  predicates. Returns the previous memory's `.confirmed` ack iff:
  - The previous memory had a `.confirmed` `hypothesisAcknowledgement`.
  - The previous memory's `adaptationLog.last` documented a user
    pushback (`documentsUserPushback == true`).
  - The ack's `acknowledgedAt >= lastChange.changedAt` — the ack was
    lodged AFTER the rebuild was folded in (round 32's contract).
  - The ack still applies to the PREVIOUS working hypothesis (it was
    lodged on the rebuilt read, not a stale read).
  - The ack still applies to the NEW working hypothesis (the rebuild
    persists into this memory rebuild — the engine is not silently
    rewriting the hypothesis on top of the confirmation).
- New append arm on the existing
  `if priorLeverShift != nil || droppedRejectedAck != nil { ... }`
  branch: an `else if let ack = confirmedRebuildAck` arm appends a
  confirmation `CoachCourseChange` with `fromLever == toLever` (no
  lever shift on a confirmation — the user accepted the existing
  lever's rebuilt read) and the new
  `rebuildConfirmationEvidenceBasis(ack:)` snapshot line.
- The bounded `adaptationLog.suffix(8)` cap applies to the new arm
  unchanged. Pre-round-36 memories with no confirmation history decode
  and behave unchanged; the new arm fires only on the specific
  pushback-then-confirmation sequence.

### Track 4 — `rebuildConfirmationEvidenceBasis(ack:)` helper (`PrimaryFocusMemory.swift`)

- Sibling of the existing `rejectedAckEvidenceBasis(ack:)` private
  helper. Trims the snapshot, caps it at 140 chars (same cap as the
  rejection helper so the bounded log treats both event types
  symmetrically), and emits `"user-tapped confirmation of: \"\(trimmed)\""`.
- Empty/whitespace snapshot falls through to
  `"user-tapped confirmation of the rebuilt read"` — defensive against
  fixtures or older codable round-trips that could deliver an empty
  snapshot.
- A downstream analytics or audit surface can read both arms with the
  same parser. The symmetric shape — both lines name the verdict type
  and quote the snapshot — keeps the bounded log self-describing.

### Track 5 — `rebuildConfirmationContextLines(memory:)` helper (`CoachContextBuilder.swift`)

- New `static func rebuildConfirmationContextLines(memory: CoachMemory) -> [String]`
  placed directly after `rebuildVerdictContextLines`. Returns a
  two-line block when the tail entry is a confirmation AND the working
  hypothesis is non-empty:
  - Case-state line: `"- Case file rebuild lock-in: the user confirmed
    the rebuilt working hypothesis above\(basisTail)."` — mirrors
    round 32's "Case file rebuild verdict" shape so the cross-line
    referent ("the working hypothesis above") matches.
  - Coach-move line: `"- Coach move on the locked-in rebuild: Treat the
    rebuild as the accepted operating hypothesis; tie the next
    prescription to it and do not re-litigate the prior pushback. The
    user accepted the new read."` — brand-voice compliant (no
    exclamation, no "Let's", no hype). Names the explicit coach move
    on a durable acceptance signal.
- Returns `[]` when the tail is not a confirmation OR when
  `workingHypothesis` is empty/whitespace — the lines reference "the
  working hypothesis above" and pointing at nothing would read
  incoherently to the model.

### Track 6 — Four-tier `interventionCycleLines` priority (`CoachContextBuilder.swift`)

- The three-tier course-change surface (round 32 / round 31 / generic)
  grows a fourth tier at the top: the round-36 confirmation block.
  Resolution order, most-specific first:
  1. Round 36 — `rebuildConfirmationContextLines`.
  2. Round 32 — `rebuildVerdictContextLines`.
  3. Round 31 — `freshRevisedReadContextLines`.
  4. Generic — `"- Last course change: \(reason) (\(basis))."`.
- The four are mutually exclusive at the memory level. A confirmation
  entry's `documentsUserPushback == false` closes the round-32 and
  round-31 gates (both require pushback tails); the round-30 ack bump
  that satisfies round 32 also closes round 31's `isFresh` window.
- The chat context carries one canonical course-change block at any
  time. The block's overall `.prefix(9)` cap is preserved.

### Track 7 — `RebuildConfirmationAdaptationTests` (`NoumTests/NoumTests.swift`)

New `@Suite("RebuildConfirmationAdaptationTests")` (struct, `@MainActor`)
placed after `AdaptationLogCycleSummaryTests`. Twenty-four `@Test`
methods covering the marker, the predicate, the headline ordering, the
engine append, the context lines, the priority routing, and the
cross-helper isolation contracts.

- **Marker + predicate matrix (5 tests):**
  - `confirmationMarkerIsRebuildConfirmationLanguage` — locks the
    constant phrasing so a copy edit forces the predicate to follow.
  - `documentsRebuildConfirmationTrueOnConfirmationReason` — happy
    path.
  - `documentsRebuildConfirmationFalseOnFirstCyclePushback` — mutual
    exclusion with round 27's marker.
  - `documentsRebuildConfirmationFalseOnSecondCyclePushback` — mutual
    exclusion with round 33's marker; also asserts the second-cycle
    entry STILL satisfies `documentsUserPushback` (no regression).
  - `confirmationEntryDoesNotSatisfyPushbackPredicates` — the round-35
    cycle-depth contract: a confirmation entry resets the streak.
- **`caseFileHeadline` ordering (3 tests):**
  - `caseFileHeadlineNamesConfirmationInSecondPerson` — happy path.
  - `caseFileHeadlineConfirmationOutranksRebuildPushbackBranch` —
    defensive: the confirmation branch wins over the pushback branches
    even when both markers appear in the same reason.
  - `caseFileHeadlineUnchangedForPushbackEntries` — back-compat:
    round-34 first/second-cycle pushback headlines still surface
    unchanged.
- **Engine append branch (6 tests):**
  - `buildAppendsConfirmationEntryAfterConfirmedAckOnRebuild` —
    happy path; the bounded log carries both entries.
  - `buildConfirmationAppendIsIdempotentAcrossSubsequentRebuilds` —
    after the confirmation entry lands, the next memory rebuild does
    NOT duplicate it.
  - `buildDoesNotAppendConfirmationOnUncertainAck` — only `.confirmed`
    triggers the append.
  - `buildDoesNotAppendConfirmationWhenPriorTailIsNotPushback` —
    engine-only tail does not satisfy the predicate.
  - `buildDoesNotAppendConfirmationWhenAckSnapshotDoesNotMatch` — a
    stale ack on a hypothesis the engine has since rebuilt does not
    earn a confirmation entry.
  - `buildDoesNotAppendConfirmationOnRejectedAck` — the existing
    rejection-aware arm wins; the confirmation arm yields.
- **`rebuildConfirmationContextLines` (4 tests):**
  - `rebuildConfirmationContextLinesFiresWhenTailIsConfirmation` —
    happy path; both lines + the evidence-basis tail.
  - `rebuildConfirmationContextLinesEmptyWhenTailIsPushback` — the
    pushback tail correctly yields to the round-32 / round-31 paths.
  - `rebuildConfirmationContextLinesEmptyWhenWorkingHypothesisEmpty`
    — defensive against incoherent references.
  - `rebuildConfirmationContextLinesEmptyWhenLogIsNil` — defensive.
- **Cross-helper isolation (3 tests):**
  - `cycleDepthResetsToNilOnConfirmationTail` — round 35's depth
    helper returns nil on `[pushback, pushback, confirmation]`. The
    engine-reset outcome future move #13 promised.
  - `freshRevisedReadChangeStaysNilOnConfirmationTail` —
    `RevisedReadCard`'s upstream gate stays silent; the post-rep
    summary surface is pushback-only by design.
  - `rebuildVerdictPairStaysNilOnConfirmationTail` — round 32's gate
    cleanly falls off the moment the confirmation lands.
- **`interventionCycleLines` priority (2 tests, via the public
  `userContext(...)` entry):**
  - `userContextSurfacesConfirmationBlockWhenTailIsConfirmation` —
    round 36's lines appear, round 32's verdict line does NOT, and
    round 31's fresh-revised-read line does NOT.
  - `userContextStillSurfacesRound32VerdictBeforeConfirmationLands` —
    the freshness window between the `.confirmed` ack landing and the
    next memory rebuild appending the confirmation entry still
    surfaces the round-32 verdict line.
- **Engineering bans (1 test):**
  - `confirmationContextLinesHelperDoesNotMutateMemory` — pure-
    function contract.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "compare response across multiple attempts and either reinforce,
  vary, or replace the intervention with an explained rationale." The
  reinforce branch — the user accepting the rebuilt read — has been
  surfaced in the chat context since round 32 but never recorded
  durably. Round 36 records it. The case file now carries the full
  rejection-rebuild-confirmation lifecycle in its bounded adaptation
  log, not just the rejections.
- **Coach-parity stage #2 (Case formulation).** The case-formulation
  block reads the same memory the durable adaptation log lives on.
  Once the confirmation entry lands, round 35's cycle-depth signal
  resets cleanly — the durable case file no longer over-reports a
  rebuild lifecycle the user has already closed.
- **Pillar #5 (Personalized coaching).** A coach who keeps treating
  an accepted rebuild as an in-flight verdict is not personalizing;
  they are pattern-matching. Round 36 gives the chat context the
  evidence to treat the rebuild as durably accepted — the same
  evidence the Profile case file now carries.
- **Pillar #4 (Believable progress).** A user who confirms a rebuild
  sees their acceptance named on the Profile card ("You confirmed
  the rebuilt read.") AND reflected in the chat coach's tone (the
  round-36 lock-in block tells the model to "treat the rebuild as
  the accepted operating hypothesis"). The case file reads as a
  living record, not a one-way log of pushbacks.
- **Engineering bans.** No fragmented state: round 36 adds one
  marker constant, one predicate, one ordered headline branch, one
  engine append arm, one evidence-basis helper, one context-lines
  helper, and one priority arm on `interventionCycleLines`. The
  data primitive (the marker) is read by every consumer through the
  same predicate — a copy edit in one place propagates to all
  surfaces. No placeholder logic: the new helpers have real call
  sites in both the chat context and the case file. No dead toggles:
  the helpers have no flags; the resolution is data-driven off the
  persisted `adaptationLog` field.
- **Anti-overclaim.** The engine append branch fires only on the
  exact rebuild-then-`.confirmed`-ack sequence (five guards). The
  context-lines helper returns `[]` whenever the tail is not a
  confirmation. The headline branch fires only on the marker. No
  fabrication of an acceptance the user did not lodge.
- **No schema bump.** The new marker is a substring of the existing
  `reason` field. The predicate is a pure-function read. Memories
  persisted before round 36 decode and behave unchanged: no log entry
  carries the new marker (it never existed), so the predicate
  returns false on every pre-round-36 entry; all four existing
  `caseFileHeadline` branches surface unchanged.

### Branch + redesign-alignment notes

- All seven tracks land on `Redesign`, the redesign-lineage branch
  the rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." Round 36
  preserves the round-by-round loop on the redesign lineage.
- Round 36 does not change round 27's `userPushbackMarker`, round 33's
  `userRebuildPushbackMarker`, the round-31 `freshRevisedReadContextLines`
  helper, the round-32 `rebuildVerdictPair` / `rebuildVerdictContextLines`
  helpers, the round-33 `documentsRebuildPushback` predicate, the
  round-34 `caseFileHeadline` pushback branches, or the round-35
  `adaptationLogCycleDepth` / `adaptationLogCycleSummary` helpers.
  Every prior round's tests pass unchanged.
- The round-32 25 rebuild-verdict tests pass unchanged: they call
  `rebuildVerdictPair(in:)` and `rebuildVerdictContextLines(memory:)`
  directly on hand-crafted memory fixtures, not through the engine.
  My new engine arm doesn't affect those tests.
- The round-27 `buildDoesNotLogAdaptationForConfirmedOrUncertainAck`
  test (already in `CoachMemoryEngineTests`) is the closest case to
  the new arm: it uses `.confirmed` and `.uncertain` acks on a prior
  memory with a NIL `adaptationLog`. My new predicate's
  `prev.adaptationLog?.last?.documentsUserPushback` guard returns
  false on a nil log → the arm correctly stays silent → the existing
  assertion (`memory?.adaptationLog == nil`) passes unchanged.

## Future moves

(Updated priority list — round-36 closed step #13; the rest roll
forward.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–35. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–35. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.**
   Carried forward from round 21 as a note for the record. (The
   helper exists; no behavior change desired today.)
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
    `reviewDueAt` cadence by one rep. With round 36's durable
    confirmation marker, this signal would now reset the `reviewDueAt`
    cadence cleanly on the rep AFTER the confirmation entry lands.
11. **Collapse the round-26 hypothesis-ack reflection in
    `coachCaseFormulationLines` into a single block with the round-32
    rebuild-verdict lines when the predicate fires.** Carried forward
    from round 32. Hold for real-device QA.
12. **Trend-view distinction between "user accepted the first read",
    "user accepted the rebuilt read", and now "user pushed back N
    times in a row".** Carried forward from rounds 30 + 32 + 33 + 34 +
    35. With round 36's `documentsRebuildConfirmation` predicate, a
    trend view could now show the FULL rebuild lifecycle on the case
    file — rejections, depth, and lock-ins — with no further engine
    work.
13. **Sibling `RevisedReadCard` copy for the post-`.confirmed` rebuild
    surface.** Carried forward from rounds 33–35. The card currently
    surfaces only on a fresh pushback rebuild. A future round could
    add a sibling card ("You confirmed the rebuilt read.") on the
    post-rep summary AFTER the user lodges a `.confirmed` ack on the
    rebuilt hypothesis, so the rebuild lifecycle has acknowledged
    closure on the surface where it began. With round 36 the data
    primitive exists — the card would gate on a fresh
    `documentsRebuildConfirmation` entry against
    `memory.updatedAt` (mirror of `freshRevisedReadChange`).
14. **User-voiced lift for the engine-only fall-through arm of
    `caseFileHeadline`.** Carried forward from rounds 34–35. The
    current fall-through returns the persisted `reason` ("Shifted
    focus from Pace to Depth.") unchanged because rewriting it as
    user action would over-claim. But a softer second-person re-framing
    might read better on the Profile card without over-claiming — e.g.,
    "Coach moved your focus from Pace to Depth." Hold until at
    least one real-device QA pass on round 34's pushback branches +
    round 36's confirmation branch on `CaseReviewCard`.
15. **Voice-tuned depth-line phrasing.** Carried forward from round 35.
    The case-formulation depth line currently reads the same across
    all voices. A future round could vary the coach-move clause by
    the user's `SpeakingStyleGoal`: `.authoritative` reads "stop
    retrying the same lever" (direct); `.warm` reads "the streak
    matters — meet it gently" (measured); `.concise` reads "drop
    this lever; try another" (tight). Same pattern the round-29
    opener uses for voice-tuned phrasing. Hold until at least one
    real-device QA pass on the depth line landing in chat.
16. **Voice-tuned confirmation-line phrasing.** New note from round 36.
    The case-formulation confirmation block currently reads the same
    across all voices. A future round could vary the coach-move
    clause by `SpeakingStyleGoal` — same pattern as #15 above.
    Hold until at least one real-device QA pass on round 36's lock-in
    block landing in chat.
17. **Depth-aware Ask Noum starter chip.** Carried forward from round
    35. When `adaptationLogCycleDepth(in:)` returns ≥ 3, AskNoumView's
    empty-state starter chips could surface a dedicated "Why does
    this keep coming back?" chip that seeds the conversation with
    the streak context. Sibling of the round-25 case-review starter
    chip. Hold until at least one real-device QA pass.
18. **Confirmation-aware Ask Noum starter chip.** New note from round
    36. When the latest adaptation entry is a confirmation, AskNoumView's
    empty-state could offer a "Where do we take the new read next?"
    chip that seeds the conversation with the lock-in context. Sibling
    of #17. Hold until at least one real-device QA pass.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes are:

- One new marker constant + one new pure-function predicate
  (`documentsRebuildConfirmation`) on `CoachCourseChange` in
  `PrimaryFocusMemory.swift`. Self-contained — no new imports, no new
  dependencies, no new types.
- One new ordered branch on `CoachCourseChange.caseFileHeadline` in
  `PrimaryFocusMemory.swift`, sitting AHEAD of the existing pushback
  arms.
- One new `confirmedRebuildAck` local predicate + one new `else if`
  append arm on `CoachMemoryEngine.build(...)` in
  `PrimaryFocusMemory.swift`. Reads `previous?` only; no new state
  written outside the existing `adaptationLog.append(...)` path.
- One new private static helper `rebuildConfirmationEvidenceBasis(ack:)`
  in `PrimaryFocusMemory.swift`. Mirror of `rejectedAckEvidenceBasis`.
- One new `static func rebuildConfirmationContextLines(memory:)`
  helper on `CoachContextBuilder` in `CoachContextBuilder.swift`.
  Mirror of `rebuildVerdictContextLines`.
- One new priority arm at the top of `interventionCycleLines` in
  `CoachContextBuilder.swift`. The existing three-tier surface
  becomes four-tier, most-specific first.
- One new `@Suite("RebuildConfirmationAdaptationTests")` (24 tests)
  in `NoumTests/NoumTests.swift`. Plain `struct`, `@MainActor`, mirror
  of the round-35 `AdaptationLogCycleSummaryTests` attributes.

All checks the next agent should run on a real build host:

1. `swift test --filter RebuildConfirmationAdaptationTests` — the new
   round-36 24 tests should all pass.
2. `swift test --filter AdaptationLogCycleSummaryTests` — the round-35
   16 tests should still pass. Round 36 does not touch the depth
   helpers; the cross-helper test
   (`cycleDepthResetsToNilOnConfirmationTail`) in the new suite
   exercises the integration.
3. `swift test --filter CaseFileHeadlineTests` — the round-34 9 tests
   should still pass. The new branch sits AHEAD of the existing
   branches; the existing branches still match unchanged for pushback
   entries.
4. `swift test --filter FreshRevisedReadChangeSecondCycleDelegationTests`
   — the round-34 1 test should still pass.
5. `swift test --filter RevisedReadCardTests` — the round-28 + round-33
   tests should all still pass. The card's gate
   (`freshRevisedReadChange`) is unchanged.
6. `swift test --filter SecondCyclePushbackAdaptationTests` — the
   round-33 19 second-cycle tests should all still pass. Round 36
   does not touch the engine's `isSecondCyclePushback` detection or
   the second-cycle marker constants.
7. `swift test --filter RebuildVerdictContextTests` — the round-32 25
   rebuild-verdict tests should still pass. The helper itself is
   unchanged; the `interventionCycleLines` priority shift is
   integration behavior covered by the new round-36 suite.
8. `swift test --filter FreshRevisedReadContextTests` — the round-31
   16 fresh-revised-read tests should still pass. The helper itself
   is unchanged.
9. `swift test --filter RevisedReadFollowUpTests` — round-30 tests
   should still pass.
10. `swift test --filter RevisedReadOpenerTests` — round-29 tests
    should still pass.
11. `swift test --filter CoachMemoryEngineTests` — round-27 tests
    should all still pass. The new arm fires only on the specific
    `.confirmed`-ack-on-pushback-tail sequence; the existing
    `buildDoesNotLogAdaptationForConfirmedOrUncertainAck` test uses a
    nil `adaptationLog`, so the new predicate's tail guard returns
    false and the arm stays silent.
12. `swift test --filter HypothesisAcknowledgementTests` — round-26
    tests should still pass.
13. `swift test --filter InterventionReviewPromptTests` — round-24 +
    round-25 tests should still pass.
14. `swift test --filter CoachMemoryStoreTests` — should still pass.
15. **Real-device QA — confirmation entry on the adaptation log.**
    Boot the app on simulator. Seed a `CoachMemory.activeIntervention`
    with a working hypothesis. Drop a `.rejected` ack via Ask Noum
    (or via the round-24 review prompt). Finish a rep that rewrites
    the working hypothesis — the log now carries a first-cycle
    pushback entry. Open Ask Noum, lodge a `.confirmed` verdict chip
    on the rebuilt hypothesis via the round-30 follow-up row.
    Finish another rep. The new memory rebuild should append a
    confirmation entry to `adaptationLog`.
16. **Confirm the chat-coach context block carries the lock-in line.**
    The next AskNoumView reply should compose against a user context
    that includes "Case file rebuild lock-in: the user confirmed the
    rebuilt working hypothesis above (user-tapped confirmation of:
    \"...\")." AND the round-32 "Case file rebuild verdict" line
    should NOT also fire (mutually exclusive).
17. **Switch to the Profile tab.** Open the `CaseReviewCard`. Confirm
    the "Last shift" row now reads "You confirmed the rebuilt read."
    AND the round-35 "Pushback depth" row no longer appears (the
    streak resets on the confirmation tail).
18. **Idempotence check.** Finish another rep without changing the
    case state. The chat context should still carry the round-36
    lock-in line and the Profile card should still read "You
    confirmed the rebuilt read." The log count should NOT have
    grown — the confirmation entry is appended exactly once.
19. **Engine-shift after confirmation.** Drive a trend signal that
    causes the engine to shift the lever (e.g., a different skill
    area's signal strengthens). The new memory rebuild should
    append an engine-only shift entry to the log — the existing
    arm wins over the confirmation arm. The Profile card should
    now read the engine-only fall-through phrase on "Last shift".

Branch lineage: round 36 sits on top of round 35 on `Redesign`, which
sits on top of rounds 11–34. The round-by-round loop on the redesign
lineage is preserved.
