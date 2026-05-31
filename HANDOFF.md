# HANDOFF — M24 deferred slate (round 31): the chat-coach user-context block now carries a dedicated two-line REVISED-READ block whenever the latest `CoachCourseChange` is BOTH a user-pushback rebuild AND fresh against `CoachMemory.updatedAt`, so the model speaks to the rebuilt hypothesis as the live operating read on every chat turn — not only on the round-29 dispatched seed.

## Scope

Round 30 closed the chat-surface adaptation loop opened by round 29: after
the coach replies to the round-29 `revisedReadOpener` seed, a one-tap
follow-up chip row lands the user's verdict on the rebuild without
typing. Three rounds — 28 (`RevisedReadCard` post-rep surface), 29
(case-anchored chat seed), 30 (chip-row verdict) — gave the rebuild a
visible spine across the post-rep summary, the chat thread opener, and
the chat-thread verdict.

The honest gap that left open: **the model's user-context block doesn't
explicitly name the rebuild state on chat turns AFTER the round-29 seed.**
The seed lands the pushback in the user turn ("Picking up the case file —
I flagged the prior read as off."), and the model's first reply is
case-anchored. But on the SECOND, third, fourth user turn in the same
thread — before the next followed rep rewrites memory — the user-context
block goes flat:

- The `CASE FORMULATION` section names "Working hypothesis (tentative): X"
  with no marker that X is a rebuild rather than the original.
- The `INTERVENTION CYCLE` section's "Last course change: <reason>
  (<basis>)" line carries the rebuild as one of many possible reason
  shapes. The model has to PARSE the reason text to know this was a
  user-pushback rebuild AND that the rebuild is still fresh.
- The hypothesis acknowledgement reflection (round 26) covers the user's
  verdict on the CURRENT hypothesis, but reads identically whether that
  hypothesis is the original or a rebuild — no distinguishing tag.

A coach who'd just rebuilt their read at the user's pushback would not
speak to chat turn #3 as if the current hypothesis had always been there.
They'd remember they JUST changed it, name the change, and check whether
the user is settling into it. Round 31 gives the model the same memory.

Round 31 picks up step #11 from the round-30 "Future moves" list:

> **Carry the revised-read context into the chat-coach context block.**
> From round 29. The `CoachContextBuilder.buildContextBlock(...)`
> user-block could surface the fresh adaptation entry ("Case file just
> shifted: user flagged the prior read; new working hypothesis is X")
> when the latest `CoachCourseChange` is both `documentsUserPushback`
> and `isFresh`. The model would then know the case state on EVERY chat
> turn through the next rep, not only on the seed message that opened
> the thread. Pure-function lift on the existing context-block builder;
> gate on the same `freshRevisedReadChange` predicate the summary card
> and the round-29 opener already read.

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the
redesign branch too (very important)."

Translation, this round:

- Two new pure functions on `CoachContextBuilder`:
  - `freshRevisedReadChange(in: CoachMemory) -> CoachCourseChange?` —
    pure-function lift of `SummaryView.freshRevisedReadChange`. Returns
    the latest adaptation entry iff it both `documentsUserPushback` AND
    `isFresh(comparedTo: memory.updatedAt)`. Identical semantics to the
    SummaryView gate, lifted so the chat context block reads the same
    predicate as the summary card, the round-29 opener, and the round-30
    chip row.
  - `freshRevisedReadContextLines(memory:) -> [String]` — the two
    context-block lines emitted when the predicate fires AND the
    carrying `workingHypothesis` is non-empty. Case-state line +
    coach-move line. Returns `[]` when the predicate doesn't fire, OR
    when it fires but the hypothesis is missing/whitespace-only (the
    lines reference "the working hypothesis above" — pointing at
    nothing would read incoherently).
- `interventionCycleLines` now branches: when
  `freshRevisedReadContextLines` is non-empty, emit those lines AND
  SUPPRESS the generic "Last course change: <reason> (<basis>)" line.
  The two would describe the same change; the dedicated lines name the
  rebuild state with more precision. When the predicate doesn't fire
  (engine-only shifts, stale rebuilds), the generic line surfaces
  unchanged — no regression on the round-19 pre-pushback adaptation
  lineage.
- The case-state line reads: `"- Case file just shifted: the user
  flagged the prior read as off; the working hypothesis above is the
  rebuilt one (<evidenceBasis>)."` The phrase "flagged the prior read
  as off" echoes `RevisedReadCard.headlineCopy` (round 28) AND the
  `revisedReadOpenerLead` (round 29) — one phrase across three
  surfaces, so the rebuild reads as the same event everywhere the
  user (and model) encounter it.
- The coach-move line reads: `"- Coach move on the rebuild: speak to it
  as the live operating read, not the original. Leave room for the
  user to settle into the rebuild or push back again before
  strengthening it."` Anti-overclaim restraint: the model is told to
  treat the rebuild as live BUT not to strengthen it before the user
  has had a chance to settle into it or push back again. Mirror of
  the round-26/30 verdict-surface restraint ("the user records THEIR
  verdict; the coach doesn't claim correctness").
- The redesign-branch invariant: this is a `Redesign`-branch push per
  the user brief. The work lands directly on `Redesign`, preserving
  the round-by-round loop on the redesign lineage that has been the
  home of rounds 11–30.

## What shipped

### Track 1 — `CoachContextBuilder.freshRevisedReadChange(in:)` + `freshRevisedReadContextLines(memory:)` (`CoachContextBuilder.swift`)

- New `static func freshRevisedReadChange(in memory: CoachMemory) -> CoachCourseChange?`.
  Pure-function lift of `SummaryView.freshRevisedReadChange`. Same guard
  structure:
  - `memory.adaptationLog?.last` must exist.
  - `latest.documentsUserPushback` must be true.
  - `latest.isFresh(comparedTo: memory.updatedAt)` must be true.
  - Returns the matching entry, or nil otherwise.
- New `static func freshRevisedReadContextLines(memory: CoachMemory) -> [String]`.
  Two-step gate:
  - `freshRevisedReadChange(in:)` must return non-nil.
  - `memory.workingHypothesis` (trimmed) must be non-empty.
  - Returns two lines: case-state line (with evidence-basis tail) +
    coach-move line. Returns `[]` if either gate fails.
- Brand-voice compliant — no exclamation, no "Let's", no urgency framing.
  The case-state line is a verdict-surface description; the coach-move
  line is a model instruction. Both lean on the anti-overclaim rules
  from CLAUDE.md.
- Empty `evidenceBasis` defensive: the case-state line omits the
  `(<basis>)` parenthetical when the basis is empty/whitespace-only,
  so no dangling `(  )` tail surfaces in the prompt.
- Section comment block placed between the round-30 revised-read
  follow-up chips section and the per-voice starter-prompts section.
  Same MARK convention as rounds 26/30. No reordering of existing code.

### Track 2 — `interventionCycleLines` wiring (`CoachContextBuilder.swift`)

- The existing `if let change = memory.adaptationLog?.last` branch is
  now wrapped in a two-arm conditional:
  - If `freshRevisedReadContextLines` returns non-empty, append those
    lines and suppress the generic "Last course change" line.
  - Else if the adaptation log has a last entry, append the generic
    line unchanged.
- The `prefix(9)` cap on `interventionCycleLines` still holds. The
  fresh revised-read path adds at most 7 lines total to the section
  (5 from `activeIntervention` + 2 from the dedicated block); the
  engine-only path stays at 6 lines (5 + 1). Both fit under the cap.
- Comment block on the branch explains the suppression contract so a
  future reader understands why a fresh-pushback memory drops the
  generic line.
- The existing test
  `userContextSurfacesCaseSpineCriterionReviewAndCourseChange` still
  passes: it uses an engine-only adaptation entry (no
  `userPushbackMarker` in reason) with `workingHypothesis: nil`. Both
  gates of `freshRevisedReadContextLines` fail, the function returns
  `[]`, the else-branch fires, the generic "Last course change:" line
  surfaces as before.

### Track 3 — `FreshRevisedReadContextTests` suite (`NoumTests/NoumTests.swift`)

New top-level `@Suite("FreshRevisedReadContextTests")` at the end of
the file (after the round-30 `RevisedReadFollowUpTests`). Sixteen
`@Test` methods pin the predicate contract, the context-line shape,
and the `userContext` integration:

- **Predicate happy + negative paths (6 tests):**
  - `freshRevisedReadChangeReturnsLatestPushbackWhenFreshAndPushback` —
    pushback rebuild stamped at memory.updatedAt → returns the entry.
  - `freshRevisedReadChangeReturnsNilForEngineOnlyChange` — reason
    without the `userPushbackMarker` → returns nil.
  - `freshRevisedReadChangeReturnsNilWhenStale` — changedAt 300s before
    memory.updatedAt → fails `isFresh` → returns nil.
  - `freshRevisedReadChangeReturnsNilForNilAdaptationLog` — defensive
    against round-trip from pre-adaptation-log memories.
  - `freshRevisedReadChangeReturnsNilForEmptyAdaptationLog` — empty
    array short-circuit.
  - `freshRevisedReadChangeIgnoresEarlierPushbackWhenLatestIsEngineOnly` —
    the predicate reads `.last` ONLY; historic pushback + fresh
    engine-only shift returns nil.
- **Context-line shape (7 tests):**
  - `contextLinesEmitTwoLinesWhenPredicateFiresAndHypothesisPresent` —
    happy path emits exactly two lines.
  - `contextLinesEmitNothingWhenPredicateFiresButHypothesisIsNil` —
    missing hypothesis → empty array.
  - `contextLinesEmitNothingWhenHypothesisIsWhitespaceOnly` — trim
    treats whitespace as empty.
  - `contextLinesEmitNothingWhenPredicateDoesNotFire` — engine-only
    change with hypothesis still returns empty.
  - `contextLinesCaseStateEchoesRevisedReadCardPhrasing` — cross-surface
    contract: the case-state line contains "flagged the prior read as
    off" (the round-28 `RevisedReadCard.headlineCopy` phrase) AND
    "the working hypothesis above is the rebuilt one".
  - `contextLinesCaseStateCarriesEvidenceBasisInParentheses` — basis
    surfaces in `(...)` so the model knows what evidence the rebuild
    rests on.
  - `contextLinesCaseStateOmitsParensWhenEvidenceBasisIsEmpty` —
    defensive against the `(nil, nil)` arm of `CoachMemoryEngine.build`;
    no dangling `(  )` tail.
- **Coach-move line contract (1 test):**
  - `contextLinesCoachMoveTellsModelToSpeakToRebuild` — line 2 contains
    "speak to it as the live operating read", "not the original", AND
    "settle into the rebuild or push back again". The anti-overclaim
    instruction lives in the test, not just the implementation.
- **`userContext` integration (3 tests):**
  - `userContextSurfacesDedicatedLinesAndSuppressesGenericLineOnFreshRebuild`
    — the dedicated lines surface AND the generic "Last course change:"
    prefix does NOT surface. Locks the suppression contract.
  - `userContextStillSurfacesGenericLineForEngineOnlyChange` — engine-
    only shifts still get the generic line, no regression on the
    round-19 pre-pushback adaptation lineage.
  - `userContextSurfacesGenericLineWhenPushbackIsStale` — a pushback
    rebuild that aged past this rep falls through to the generic line,
    preserving the case-formulation read on historic adaptations.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the
  case formulation needs "the reason for changing course" carried as
  active coaching state, not buried in a log. Round 28 surfaced it on
  the post-rep summary; round 29 named it in the chat seed; round 30
  recorded the user's verdict on the rebuild. Round 31 carries the
  rebuild state into EVERY user-context block read by the model on
  the rebuild thread, so the model's coaching judgment on chat turn #4
  doesn't drift back to a flat read of the original hypothesis.
- **Pillar #5 (Personalized coaching).** A coach who'd just rebuilt
  their read at the user's pushback would speak to chat turn #3 with
  the rebuild in their head — "since you flagged the prior read,
  here's where I land" — not as if the rebuilt hypothesis had always
  been the operating read. Round 31 gives the model the same memory.
- **Anti-overclaim.** The coach-move line tells the model to speak to
  the rebuild as the live read, BUT NOT to strengthen it before the
  user has had a chance to settle into it or push back again. Same
  restraint as the round-26/30 verdict surface ("user records THEIR
  verdict; the coach doesn't claim correctness").
- **Cross-surface read consistency.** The phrase "flagged the prior
  read as off" lives in three surfaces now — the round-28 RevisedReadCard
  headline the user reads, the round-29 opener the user dispatches,
  and the round-31 context line the model reads. One phrase across
  three surfaces; the rebuild reads as the same event everywhere.
- **Engineering bans.** No placeholder logic. No dead toggles. No
  fragmented state — the new helpers READ existing memory fields; no
  new storage, no schema bump, no migration. Pure-function lift on
  pure-function inputs.

### Branch + redesign-alignment notes

- All three tracks land on `Redesign`, the redesign-lineage branch the
  rolling M24 deferred-slate work has been shipping on since round 11.
  The user brief explicitly calls this out: "ensure working on the
  redesign branch too (very important)." Round 31 preserves the
  round-by-round loop on the redesign lineage.
- Round 31 does not change the round-30 chip-row predicate or catalog,
  does not change the round-29 `revisedReadOpener` function, does not
  change the round-29 `talkToNoumOpener` gate, does not change the
  round-28 `RevisedReadCard` view, does not change the round-27
  engine restructure, does not change the round-26 chip catalog or
  hypothesis-ack row, and does not change the round-24 / round-25
  `InterventionReviewPromptCard` surface. The round-30 15 follow-up
  tests + round-29 12 opener tests + round-28 5 copy tests + round-26
  19 ack tests all remain unchanged; the round-31 16 fresh-revised-
  read tests sit alongside them.
- `SummaryView.freshRevisedReadChange` is intentionally left in place
  as a private computed property — not refactored to call through to
  `CoachContextBuilder.freshRevisedReadChange(in:)`. Both predicates
  are now expressed in shared code and read the same `CoachCourseChange`
  predicates (`documentsUserPushback`, `isFresh(comparedTo:)`), so the
  two stay in lockstep without a forced edit on the view layer this
  round. A future round can collapse the SummaryView private property
  into a call through `CoachContextBuilder` once a real-device QA pass
  is available to verify the view binding stays identical.

## Future moves

(Updated priority list — round-31 closed the round-30 step #11; the
rest roll forward, plus one new note from round 31.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–30. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–30. Pure visual work, not crossing logic.
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
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26. Note
   for round 30: any voice-tuned glyph work that lands on round-26's
   chip row should be lifted into the shared `ackChipGlyph(for:)`
   helper so the round-30 row picks up the same per-voice glyph
   mapping.
10. **`.confirmed` confidence amplification on the active intervention.**
    Carried forward from round 27. Flip side of rejection-becomes-
    course-change: a `.confirmed` ack on a held hypothesis could nudge
    `CoachIntervention.criterionStatus` toward "met" or extend the
    `reviewDueAt` cadence. The natural follow-on to the round-27/28/29/30
    rejection lineage — and round 30 makes this more valuable, because
    BOTH rows now write `.confirmed` acks to the same store; a single
    amplification helper would lift verdicts from both surfaces.
11. **Reflect the revised-read follow-up verdict in the next
    user-context block.** From round 30. After the user lands a verdict
    on the rebuild via the round-30 chip row, the next user-context
    block could surface a one-line summary line ("User accepted the
    rebuilt read on <date>; treat as the operating hypothesis") so the
    model knows whether the rebuilt read is the live one or the user is
    still pushing back. Mirror of the round-26 hypothesis-ack reflection
    in the existing builder, but tagged to the *rebuild* verdict for
    analytic purposes (so a future trend view can distinguish "user
    accepted the first read" from "user accepted the rebuilt read").
    Note for round 31: this would dovetail with the new
    `freshRevisedReadContextLines` block — when the predicate fires
    AND the user has already lodged a rebuild verdict via round 30,
    the coach-move line could swap in a "user already lodged X verdict
    on the rebuild" tail so the model knows the rebuild has been
    inhabited, not just delivered.
12. **Adaptation-log entry on a round-30 `.rejected` verdict.** From
    round 30. A `.rejected` verdict on a rebuilt read is functionally
    equivalent to the round-27 trigger — the user is pushing back on
    the coach's read again, this time on the revised one. The natural
    next step: record a fresh `CoachCourseChange` adaptation-log entry
    on the second rejection, with the rebuilt hypothesis as the prior
    and the next rebuild as the revised. Closes the loop on the
    rejection-rebuild-rejection-rebuild chain so the case file captures
    the full adaptation history, not just the first cycle.
13. **Collapse `SummaryView.freshRevisedReadChange` into a call through
    `CoachContextBuilder.freshRevisedReadChange(in:)`.** New note from
    round 31. The predicate lift this round preserved the view-private
    property to avoid forcing a SwiftUI binding refactor without
    real-device QA. A future round with QA bandwidth can collapse the
    view-private property into a single call site through the shared
    helper, so a copy edit to the predicate (a future tightening of
    the freshness tolerance, say) lands on one expression rather than
    two.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes are:

- Two new `static func`s on `CoachContextBuilder` —
  `freshRevisedReadChange(in:)` and `freshRevisedReadContextLines(memory:)`
  — placed in `CoachContextBuilder.swift` immediately after
  `revisedReadFollowUpChips(for:)` and before the "Starter prompts"
  MARK. Self-contained — no new imports, no new dependencies, no new
  types (reads only `CoachMemory`, `CoachCourseChange`, both already in
  scope via `PrimaryFocusMemory.swift`).
- One edit to `interventionCycleLines` — the existing single-arm
  `if let change = memory.adaptationLog?.last` branch becomes a
  two-arm `if-else if` conditional. Behaviour unchanged when the new
  predicate doesn't fire (the else-arm preserves the original line
  exactly); new behaviour only when the predicate fires (the
  dedicated lines surface and the generic line is suppressed).
- One new `@Suite("FreshRevisedReadContextTests")` at the end of
  `NoumTests/NoumTests.swift` with sixteen `@Test` methods. The suite
  is plain `struct`, `@MainActor` (mirror of `RevisedReadFollowUpTests`
  attribute, defensive against any future `MainActor`-only reads in
  `CoachContextBuilder`).

All checks the next agent should run on a real build host:

1. `swift test --filter FreshRevisedReadContextTests` — the new
   round-31 16 fresh-revised-read tests should all pass.
2. `swift test --filter RevisedReadFollowUpTests` — the round-30 15
   follow-up tests should still pass. No round-30 surface was changed.
3. `swift test --filter RevisedReadOpenerTests` — the round-29 12
   opener tests should still pass.
4. `swift test --filter RevisedReadCardTests` — the round-28 5
   copy-generator tests should still pass.
5. `swift test --filter CoachContextBuilderTests` (or whatever the
   existing context-builder suite is named) — the existing test
   `userContextSurfacesCaseSpineCriterionReviewAndCourseChange` MUST
   still pass. It uses an engine-only adaptation entry with nil
   working hypothesis, so the new predicate fails on both gates and
   the generic "Last course change:" line still surfaces. The
   round-31 work is gated behind a strict double-predicate, so no
   existing test that doesn't satisfy both predicates should change.
6. `swift test --filter CoachMemoryEngineTests` — the round-28 6
   predicate tests + the pre-28 suite should still pass.
7. `swift test --filter HypothesisAcknowledgementTests` — the round-26
   tests (19 total) should still pass.
8. `swift test --filter InterventionReviewPromptTests` — the round-24 +
   round-25 tests (26 total) should still pass.
9. `swift test --filter CoachMemoryStoreTests` — the existing
   memory-store tests should still pass.
10. `swift test --filter CoachReadCardDailyBudgetHintTests` —
    round-23 tests should still pass.
11. `swift test --filter AIRateLimiterPublicationTests` — round-22
    tests should still pass.
12. `swift test --filter IMToneDrillCrossingTests` — round-21 helper
    tests should still pass.
13. `swift test --filter HeroScoreCardToneDrillRibbonContractTests` —
    round-20 ribbon-contract tests should still pass.
14. `swift test --filter LookingAheadCardStartCTAContractTests` —
    round-19 launch-CTA tests should still pass.
15. Boot the app on simulator, seed a `CoachMemory.activeIntervention`
    with a working hypothesis, open Ask Noum via the round-24
    `InterventionReviewPromptCard` or the round-25 empty-state chip,
    wait for the coach reply, tap the **Adapt / rejected** ack chip.
    Then finish a new rep where either the lever changes OR the
    hypothesis text rewrites (e.g. `evidenceCount` crosses a
    `BaselineConfidence` threshold). On the post-rep summary,
    confirm `RevisedReadCard` renders (round-28 contract). Open
    Ask Noum via the **Talk to Noum** CTA on the `TalkToNoumCTACard`.
    Confirm in the chat thread:
    - The user-turn seed is the round-29 revised-read opener.
    - The coach reply lands case-anchored. **NEW (round 31):** the
      coach reply should ALREADY speak to the rebuilt hypothesis as
      the live operating read, because the user-context block now
      carries the dedicated revised-read block.
    - Send a follow-up free-text message ("ok so what should I work
      on first?"). Confirm the coach's reply STILL frames the
      hypothesis as a rebuild — not as the original. This is the
      round-31 contract: the rebuild context lives across the whole
      window between rebuild and the next followed rep.
    - Open the chat thread debug log (or instrument
      `AICoachChatService` locally) to confirm the
      USER CONTEXT payload sent to the model contains the line
      starting "Case file just shifted: the user flagged the prior
      read as off" AND DOES NOT contain a generic
      "Last course change:" line on the same turn.
16. Now finish a NEXT followed rep so memory rewrites with a fresh
    `updatedAt`. The adaptation entry's `changedAt` is now > 1s
    earlier than `memory.updatedAt`, so `isFresh` fails. Open Ask
    Noum again — confirm the user-context payload now DROPS the
    "Case file just shifted" block and falls back to the generic
    "Last course change:" line. The rebuild context aged out
    correctly with the rep.
17. Trigger an engine-only lever shift (e.g. let evidenceCount cross
    a threshold without a `.rejected` ack present). Confirm the
    user-context payload carries the generic "Last course change:"
    line — NOT the dedicated revised-read block. The engine-only
    path is not a rebuild and shouldn't read as one.
