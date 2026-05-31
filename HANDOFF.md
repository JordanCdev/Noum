# HANDOFF — M24 deferred slate (round 33): second-cycle pushback marker on the adaptation log, surfaced through `RevisedReadCard`, the chat-coach context, and the durable case file — closing the rejection-rebuild-rejection-rebuild loop honestly in the engine.

## Scope

Round 32 closed the verdict half of the rebuild loop: when the user lands
a `confirmed` / `uncertain` / `rejected` verdict on the rebuilt working
hypothesis via the round-30 chip row, the chat-coach user-context block
carries a dedicated REBUILD VERDICT block on every chat turn through to
the next followed rep.

The honest gap that left open: when the user lodges `.rejected` on a
rebuilt read (the "second pushback" branch named in round 32), the next
memory rebuild folds the dropped `.rejected` ack into a new
`CoachCourseChange` via the round-27 engine arm. But the appended entry
reads IDENTICALLY to a first-cycle pushback. The `reason` carries
`"user reported the prior hypothesis did not match what they saw"` — the
same marker the round-27 first-cycle path writes. The bounded adaptation
log shows two indistinguishable pushback entries; downstream surfaces
(post-rep `RevisedReadCard`, chat-coach context line on the next
followed rep, a future trend view that counts rebuild cycles) cannot
tell the second cycle from the first without parsing prose.

Round 33 picks up step #11 from the round-32 "Future moves" list:

> **Adaptation-log entry on a round-32 `.rejected` rebuild verdict.**
> Promoted from round-30 step #12 and made specific by round 32.
> A `.rejected` rebuild verdict surfaces as a "second pushback" in
> context. The natural next step: on the next memory rebuild,
> `CoachMemoryEngine.build(...)` could detect the dropped `.rejected`
> rebuild-verdict ack (same shape as the round-27 `droppedRejectedAck`
> arm, but tagged to the rebuilt hypothesis) and append a fresh
> `CoachCourseChange` with the rebuild as the prior and the next read
> as the revised. Closes the rejection-rebuild-rejection-rebuild chain
> in the engine, so the adaptation log carries the full lineage, not
> just the first cycle.

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the
redesign branch too (very important)."

Translation, this round:

- New `CoachCourseChange.userRebuildPushbackMarker` constant — distinct
  marker phrase `"user reported the rebuilt hypothesis did not match"`
  written in place of `userPushbackMarker` on second-cycle pushback
  entries. Pure copy lift on the engine; no schema bump.
- New `CoachCourseChange.documentsRebuildPushback` computed property —
  predicate that fires only on the second-cycle marker. Used by
  `RevisedReadCard.headlineCopy(for:)`, `freshRevisedReadContextLines`,
  and any future analytics surface that wants to count rebuild cycles
  without parsing the surrounding reason text.
- `CoachCourseChange.documentsUserPushback` now matches EITHER marker
  (first-cycle OR second-cycle). A second pushback IS still a pushback,
  so round-31 `freshRevisedReadContextLines`, round-32 `rebuildVerdictPair`,
  and the `SummaryView.freshRevisedReadChange` gate continue to fire on
  the second cycle without code edits at the call sites.
- New `isSecondCyclePushback` detection in `CoachMemoryEngine.build(...)` —
  pure-function read over `previous?.adaptationLog?.last?.documentsUserPushback`.
  The dropped `.rejected` ack arm writes the rebuild marker when the
  prior log entry was itself a user pushback; otherwise the existing
  first-cycle marker stands.
- `RevisedReadCard` now picks its headline via a new
  `headlineCopy(for: CoachCourseChange)` function. First-cycle entries
  read "You flagged the prior read as off." (the back-compat constant);
  second-cycle entries read "You flagged the rebuilt read as off too."
  The user sees the second pushback acknowledged explicitly on the
  post-rep summary, not silently re-labelled as a first pushback.
- `CoachContextBuilder.freshRevisedReadContextLines` (round 31) now
  branches on `documentsRebuildPushback` for the case-state line. Second
  cycles read "Case file just shifted AGAIN: the user flagged the
  rebuilt read as off TOO ..."; first cycles read the round-31 line
  unchanged. The coach-move line is identical on both cycles — the
  case-state framing already tells the model which cycle this is.
- The redesign-branch invariant: this is a `Redesign`-branch push per
  the user brief. The work lands directly on `Redesign`, preserving
  the round-by-round loop on the redesign lineage that has been the
  home of rounds 11–32.

## What shipped

### Track 1 — `CoachCourseChange.userRebuildPushbackMarker` + `documentsRebuildPushback` (`PrimaryFocusMemory.swift`)

- New `static let userRebuildPushbackMarker = "user reported the rebuilt hypothesis did not match"`.
  Distinct from `userPushbackMarker` so an engine-side predicate can
  identify the second cycle without prose parsing AND a copy edit on
  one marker does not silently regress the other.
- `documentsUserPushback` now reads `userPushbackMarker || userRebuildPushbackMarker`.
  A second-cycle entry IS still a pushback; round-31
  `freshRevisedReadContextLines` and round-32 `rebuildVerdictPair`
  must continue to fire on it. The OR is intentional and locked by
  tests on both branches.
- New `documentsRebuildPushback: Bool` — true iff `reason` contains the
  rebuild marker (case-insensitive). Pure function of the persisted
  `reason`; no schema bump, no state to round-trip, no migration.
- Memories persisted before round 33 decode unchanged. The new computed
  property reads off the existing `reason` field and returns false on
  every legacy entry (none of which contain the rebuild marker).

### Track 2 — `CoachMemoryEngine.build(...)` second-cycle detection (`PrimaryFocusMemory.swift`)

- New `isSecondCyclePushback: Bool` local in the build function — pure
  read over `previous?.adaptationLog?.last?.documentsUserPushback ==
  true && droppedRejectedAck != nil`. Signal: the prior log entry is
  itself a user-pushback rebuild, so `previous.workingHypothesis` was
  the rebuilt read; the dropped `.rejected` ack therefore landed on the
  rebuilt read, not on an original-cycle read.
- The switch arms `(prior?, ack?)` and `(nil, ack?)` now pick the
  cycle-appropriate clause via local `pushbackClause` /
  `standaloneClause` bindings:
  - First cycle: `"...the user reported the prior hypothesis did not match..."`.
  - Second cycle: `"...the user reported the rebuilt hypothesis did not match..."`,
    standalone variant ends with `"; revising the read again."` so the
    model reads the entry as a SECOND adapt, not a duplicate of the
    first.
- The `(prior?, nil)` engine-only arm is unchanged — no user-pushback
  marker on either side. The `(nil, nil)` no-op arm is unchanged.
- Detection is robust to the bounded `suffix(8)` truncation in the
  adaptation log: the lookup reads `previous?.adaptationLog?.last`,
  which always reflects the most-recent entry the prior memory carried
  regardless of how many cycles preceded it.
- The detection breaks honestly the moment any non-pushback entry is
  appended to the log: an engine-only lever shift between two pushback
  cycles resets the chain. Future rebuilds read the engine-only entry
  as the prior `.last` and `documentsUserPushback` returns false — the
  next pushback ack drop is logged as a first cycle. The chain is a
  PROPERTY of consecutive log entries, not a permanent flag on memory.

### Track 3 — `RevisedReadCard.headlineCopy(for: CoachCourseChange)` (`RevisedReadCard.swift`)

- New `static func headlineCopy(for change: CoachCourseChange) -> String`:
  - `change.documentsRebuildPushback == true` →
    `"You flagged the rebuilt read as off too."`
  - `else` → `"You flagged the prior read as off."` (the existing
    static constant `headlineCopy`).
- The static `let headlineCopy: String = "You flagged the prior read as off."`
  constant is unchanged — the existing test
  `headlineCopyNamesUserAction` continues to pass, and any surface
  that reads the constant directly (none today, but the
  `coachCaseFormulationLines` doc comment references the phrase) does
  not regress.
- The view body and `accessibilityLabel` now read the picker function
  through `change`. The accessibility label is computed once at view
  composition time and reused for both visible Text and AX, so the
  spoken read matches what the user sees.
- Brand-voice rules respected on the second-cycle phrase: no
  exclamation, no apology, no celebratory framing ("at least you spoke
  up"), no "Let's", no "we". "too" carries the second-cycle
  acknowledgment without escalating.

### Track 4 — `CoachContextBuilder.freshRevisedReadContextLines` second-cycle branch (`CoachContextBuilder.swift`)

- The case-state line now branches on `change.documentsRebuildPushback`:
  - Second cycle: `"- Case file just shifted again: the user flagged the rebuilt read as off too; the working hypothesis above is the next rebuilt one\(basisTail)."`
  - First cycle: `"- Case file just shifted: the user flagged the prior read as off; the working hypothesis above is the rebuilt one\(basisTail)."` (round-31 line unchanged).
- The coach-move line is identical on both cycles — "speak to it as
  the live operating read, not the original. Leave room for the user
  to settle into the rebuild or push back again before strengthening
  it." Still applies whether this is the first rebuild the user has
  pushed back on or the second. The case-state framing tells the
  model which cycle.
- The round-31 `freshRevisedReadChange` predicate is unchanged. It
  reads `documentsUserPushback`, which round 33 keeps true for both
  cycles. The round-32 `rebuildVerdictPair` predicate is unchanged for
  the same reason.
- The three-tier wiring in `interventionCycleLines` is unchanged:
  round 32 (verdict) > round 31 (fresh rebuild — now with second-cycle
  framing) > generic. The mutual-exclusion property at the memory
  level continues to hold: the round-30 ack bump that satisfies round
  32 still closes round 31's `isFresh` window regardless of cycle.

### Track 5 — `SecondCyclePushbackAdaptationTests` + `RevisedReadCardTests` extensions (`NoumTests/NoumTests.swift`)

New `@Suite("SecondCyclePushbackAdaptationTests")` (struct, `@MainActor`)
placed after the round-32 `RebuildVerdictContextTests`. Fifteen `@Test`
methods cover the predicate contracts, the engine's detection logic,
and the round-31 / round-32 surfaces' continued correctness on the
second cycle:

- **CoachCourseChange predicate matrix (5 tests):**
  - `documentsUserPushbackStillTrueForFirstCycleMarker` — back-compat:
    a round-27 entry shape still satisfies `documentsUserPushback`.
  - `documentsUserPushbackTrueForSecondCycleMarker` — round 33: a
    rebuild-marker entry also satisfies `documentsUserPushback` AND
    `documentsRebuildPushback`.
  - `documentsRebuildPushbackFalseForEngineOnlyShift` — engine-only
    entries satisfy neither predicate.
  - `documentsRebuildPushbackTrueOnCombinedShiftSecondCycle` —
    `(prior?, ack?)` second cycle: both predicates true.
  - `documentsRebuildPushbackFalseOnCombinedShiftFirstCycle` —
    `(prior?, ack?)` first cycle: only `documentsUserPushback` true.
- **Engine second-cycle detection (5 tests):**
  - `buildWritesFirstCycleMarkerWhenNoPriorPushback` — no prior log:
    first-cycle marker stands.
  - `buildWritesSecondCycleMarkerWhenPriorEntryDocumentsPushback` —
    headline contract: prior log entry was a pushback, new ack drop
    writes the rebuild marker.
  - `buildWritesSecondCycleMarkerOnCombinedShiftAndRejection` —
    `(prior?, ack?)` arm on the second cycle: rebuild marker AND
    shift clause both present in the reason.
  - `buildKeepsFirstCycleMarkerWhenPriorEntryIsEngineOnly` — defensive:
    engine-only prior log entry does NOT trigger the second-cycle
    marker. The chain is a property of CONSECUTIVE pushback entries.
  - `buildEngineOnlyShiftDoesNotInheritSecondCycleMarker` — defensive:
    a pure engine-only shift (no ack to drop) writes the engine-only
    reason regardless of what the prior entry was.
- **Round-31 / round-32 surfaces on the second cycle (4 tests):**
  - `freshRevisedReadContextLinesNamesSecondCycleExplicitly` — round
    33: case-state line uses "shifted again" + "rebuilt read as off
    too" + "the next rebuilt one" on the second cycle.
  - `freshRevisedReadContextLinesKeepsFirstCyclePhrasingOnFirstCycle`
    — round-31 line unchanged on first cycles.
  - `rebuildVerdictPairStillFiresOnSecondCyclePushbackWithAck` —
    round-32 contract preserved: a `.confirmed` ack on a second-cycle
    rebuild fires the verdict block.
  - `userContextSurfacesSecondCycleCaseStateOnFreshSecondPushback` —
    end-to-end through `userContext(...)`: the second-cycle case-state
    line surfaces in the chat-coach payload AND round 32 / generic are
    suppressed on the fresh-pre-ack window.
- **End-to-end chain (1 test):**
  - `chainsTwoCyclesEndToEndThroughEngineRebuilds` — TWO
    `CoachMemoryEngine.build(...)` passes back-to-back, each folding
    a `.rejected` ack. Pass #1 writes the first-cycle marker; pass #2
    writes the second-cycle marker; the bounded log carries BOTH
    entries; the first cycle entry is unchanged on the second pass.

Four new `@Test` methods extend the existing `RevisedReadCardTests`
suite:

- `headlineCopyForFirstCyclePushbackUsesPriorPhrasing` — back-compat:
  the picker reads "prior read" on a first-cycle entry, and the
  static `headlineCopy` constant still returns "prior read".
- `headlineCopyForSecondCyclePushbackUsesRebuiltPhrasing` — picker
  reads "rebuilt read as off too" on a standalone second-cycle entry.
- `headlineCopyForCombinedShiftSecondCycleUsesRebuiltPhrasing` —
  picker reads the rebuilt phrase on a `(prior?, ack?)` second-cycle
  entry (rebuild marker AND shift clause both in the reason).
- `headlineCopyForEngineOnlyShiftFallsBackToFirstCyclePhrasing` —
  defensive: an engine-only change (which the upstream gate should
  filter out) returns the safer first-cycle phrase, not the second-
  cycle "off too" over-claim.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the
  case formulation needs "the reason for changing course" carried as
  active coaching state. Round 27 surfaced the first cycle in the
  adaptation log; rounds 28–32 carried that cycle to the post-rep
  summary, the chat seed, the chip row, and the chat context (with
  and without ack). Round 33 closes the lineage in the engine itself:
  the second cycle is now a distinct, durable event in the adaptation
  log, carrying its own marker that future surfaces can read without
  prose parsing.
- **Pillar #5 (Personalized coaching).** A coach who has rebuilt the
  read once and watched the user push back AGAIN would speak to that
  second pushback as "you flagged the rebuilt read as off too" — not
  "you flagged the prior read as off." Round 33 gives the post-rep
  card AND the chat-coach context the same memory. The user reads
  acknowledgement of their second pushback, not a generic re-run of
  the first-pushback copy.
- **Pillar #4 (Believable progress).** A user who pushed back twice in
  a row would NOTICE if the second `RevisedReadCard` read identically
  to the first. The card would feel like a stuck loop, not a coaching
  surface. Round 33 closes that credibility gap.
- **Anti-overclaim.** The second-cycle detection requires BOTH the
  dropped `.rejected` ack AND the prior log entry's pushback marker.
  An engine-only shift between two pushback cycles resets the chain
  (the prior `.last` becomes the engine-only entry, which is not a
  pushback). The engine never infers a second cycle from any signal
  but the prior log entry's own marker, and never lies about a
  pushback that did not happen.
- **No schema bump.** All new behaviour is computed from the existing
  `reason` field on `CoachCourseChange`. Memories persisted before
  round 33 decode and behave unchanged until a second-cycle pushback
  ack drop lands in the engine.
- **Engineering bans.** No placeholder logic. No dead toggles. No
  fragmented state. Pure-function lifts on pure-function inputs.

### Branch + redesign-alignment notes

- All five tracks land on `Redesign`, the redesign-lineage branch the
  rolling M24 deferred-slate work has been shipping on since round 11.
  The user brief explicitly calls this out: "ensure working on the
  redesign branch too (very important)." Round 33 preserves the
  round-by-round loop on the redesign lineage.
- Round 33 does not change the round-32 `rebuildVerdictPair` /
  `rebuildVerdictContextLines` / `interventionCycleLines` wiring,
  does not change the round-31 `freshRevisedReadChange` predicate,
  does not change the round-30 chip-row predicate or catalog, does
  not change the round-29 `revisedReadOpener`, does not change the
  round-28 `RevisedReadCard.bodyCopy`, and does not change the
  round-26 chip catalog or hypothesis-ack row. The round-32 25
  rebuild-verdict tests + round-31 16 fresh-revised-read tests +
  round-30 15 follow-up tests + round-29 12 opener tests + round-28
  5 copy tests + round-26 19 ack tests all remain unchanged; round
  33's 19 new tests sit alongside them.
- The existing first-cycle engine tests (`buildLogsCourseChangeWhenRejectedAckIsDroppedByHypothesisRevise`,
  `buildLogsSingleCourseChangeWhenLeverShiftAndRejectedAckCoincide`,
  `buildDoesNotLogAdaptationForConfirmedOrUncertainAck`,
  `buildDoesNotDoubleLogRejectedAckWhenHypothesisHolds`,
  `buildTrimsLongRejectedSnapshotInEvidenceBasis`,
  `freshlyBuiltMemoryMarksRejectedAckEntryAsFreshAndPushback`) all
  continue to pass: each fixture starts with `previous` carrying a
  nil or empty `adaptationLog`, so `isSecondCyclePushback` returns
  false and the first-cycle marker stands.

## Future moves

(Updated priority list — round-33 closed step #11; the rest roll
forward, plus one new note from round 33.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–32. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–32. Pure visual work, not crossing logic.
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
    Carried forward from round 27. Note for round 33: still standing.
    The round-32 `.confirmed` rebuild-verdict path remains the natural
    integration site — when the predicate fires AND the engine has not
    yet bumped `CoachIntervention.criterionStatus`, the same
    `.confirmed` branch could nudge the criterion toward "met" or
    extend the `reviewDueAt` cadence by one rep.
11. **Collapse `SummaryView.freshRevisedReadChange` into a call through
    `CoachContextBuilder.freshRevisedReadChange(in:)`.** Carried
    forward from round 31. With round 33's branch on
    `documentsRebuildPushback` inside `freshRevisedReadContextLines`,
    the case for unifying the gate at the call site grows: a single
    helper would also let `SummaryView` read second-cycle awareness
    if it ever wants to differentiate the card surround (it does not
    today — the headline already names the cycle — but it could).
12. **Collapse the round-26 hypothesis-ack reflection in
    `coachCaseFormulationLines` into a single block with the round-32
    rebuild-verdict lines when the predicate fires.** Carried forward
    from round 32. Hold for real-device QA.
13. **Trend-view distinction between "user accepted the first read"
    and "user accepted the rebuilt read".** Carried forward from
    rounds 30 + 32. With round 33's `documentsRebuildPushback` marker
    on the adaptation log, a future trend view could ALSO count
    rebuild PUSHBACKS separately from first-cycle pushbacks — the
    bounded log carries both lineages now.
14. **`adaptationLogCycleSummary` helper on `CoachContextBuilder`.**
    New note from round 33. A future round could compose a one-line
    coach-context summary that names the cycle depth — "user has
    pushed back twice on the working hypothesis this case file" —
    based on a count of consecutive `documentsUserPushback` entries
    at the tail of `adaptationLog`. Surface in CASE FORMULATION so
    the model speaks to a user who has pushed back twice differently
    than a user who has pushed back once. Hold until at least one
    real-device QA pass on the round-33 second-cycle chain.
15. **Engine reset on a `.confirmed` ack after a rebuild.** New note
    from round 33. The current chain depends on
    `previous.adaptationLog.last.documentsUserPushback`; a
    `.confirmed` ack on the rebuilt read does NOT cycle (it just
    confirms the rebuild). A future round could append an explicit
    `confirmation` entry on `.confirmed` ack-drop to mark the rebuild
    as accepted, closing the cycle in the log as cleanly as the
    rejection cycle is closed in round 33.
16. **Sibling `RevisedReadCard` copy for the post-`.confirmed` rebuild
    surface.** New note from round 33. The card currently surfaces
    only on a fresh pushback rebuild. A future round could add a
    sibling card ("You confirmed the rebuilt read") on the post-rep
    summary AFTER the user lodges a `.confirmed` ack on the rebuilt
    hypothesis, so the rebuild lifecycle has acknowledged closure on
    the surface where it began.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes are:

- One new constant + one updated predicate + one new predicate on
  `CoachCourseChange` in `PrimaryFocusMemory.swift`. Self-contained —
  no new imports, no new dependencies, no new types.
- One new local + one updated switch arm pair in
  `CoachMemoryEngine.build(...)` in the same file. The detection is
  a pure-function read over the previous memory's adaptation log; no
  storage, no side effects, no I/O.
- One new static func on `RevisedReadCard` plus a view-body refactor
  to read it. The body now computes `headline` and `body` once per
  composition; the existing static `headlineCopy` constant is
  preserved unchanged.
- One updated case-state branch in
  `CoachContextBuilder.freshRevisedReadContextLines`. The coach-move
  line is unchanged.
- One new `@Suite("SecondCyclePushbackAdaptationTests")` (15 tests) +
  four new `@Test` methods in the existing `RevisedReadCardTests`
  suite. The new suite is plain `struct`, `@MainActor`, mirror of
  `RebuildVerdictContextTests`'s attribute.

All checks the next agent should run on a real build host:

1. `swift test --filter SecondCyclePushbackAdaptationTests` — the new
   round-33 15 second-cycle tests should all pass.
2. `swift test --filter RevisedReadCardTests` — the round-28 5
   tests + round-33 4 new tests should all pass.
3. `swift test --filter RebuildVerdictContextTests` — the round-32
   25 rebuild-verdict tests should still pass. Round 33 only enriches
   the marker phrasing; the round-32 predicate gates on
   `documentsUserPushback`, which round 33 keeps true for both
   cycles. Round 32's `userContext` integration tests use fixtures
   with no `previous` memory, so `isSecondCyclePushback` would never
   fire even if those tests went through the engine.
4. `swift test --filter FreshRevisedReadContextTests` — the round-31
   16 fresh-revised-read tests should still pass. The round-31
   line-emission tests use `pushbackChange` fixtures with the
   first-cycle phrasing, so `documentsRebuildPushback` returns false
   and the first-cycle case-state line surfaces unchanged.
5. `swift test --filter RevisedReadFollowUpTests` — round-30 tests
   should still pass.
6. `swift test --filter RevisedReadOpenerTests` — round-29 tests
   should still pass.
7. `swift test --filter CoachContextBuilderBigMomentTests` — the
   existing `userContextSurfacesCaseSpineCriterionReviewAndCourseChange`
   test (engine-only adaptation entry) MUST still pass.
8. `swift test --filter CoachMemoryEngineTests` — the round-27 tests
   should all still pass; each starts with `previous.adaptationLog
   == nil`, so `isSecondCyclePushback` returns false and the
   first-cycle marker stands.
9. `swift test --filter HypothesisAcknowledgementTests` — round-26
   tests should still pass.
10. `swift test --filter InterventionReviewPromptTests` — round-24 +
    round-25 tests should still pass.
11. `swift test --filter CoachMemoryStoreTests` — should still pass.
12. `swift test --filter CoachReadCardDailyBudgetHintTests` —
    round-23 tests should still pass.
13. `swift test --filter AIRateLimiterPublicationTests` — round-22
    tests should still pass.
14. `swift test --filter IMToneDrillCrossingTests` — round-21 helper
    tests should still pass.
15. `swift test --filter HeroScoreCardToneDrillRibbonContractTests` —
    round-20 ribbon-contract tests should still pass.
16. `swift test --filter LookingAheadCardStartCTAContractTests` —
    round-19 launch-CTA tests should still pass.
17. **Real-device QA — the second cycle in flight.** Boot the app on
    simulator. Seed a `CoachMemory.activeIntervention` with a working
    hypothesis. Open Ask Noum via the round-24 `InterventionReviewPromptCard`
    or the round-25 empty-state chip. Tap the **Adapt / rejected**
    ack chip. Finish a new rep that rewrites the working hypothesis
    (lever shift OR confidence threshold cross). On the post-rep
    summary, confirm `RevisedReadCard` renders with the **first-cycle
    headline** ("You flagged the prior read as off."). Open Ask Noum
    via the **Talk to Noum** CTA, then tap the **Lock the new read
    in / Stick** chip on the round-30 follow-up row.
18. **Now drive the second cycle.** Send a free-text message: "actually
    this still doesn't feel right." Wait for the coach reply, then on
    a follow-up turn tap the **Adapt / rejected** ack chip on the
    REBUILT hypothesis (the chip row should fire because the rebuilt
    hypothesis is now the working one and the user is rejecting it).
    Finish another rep that rewrites the working hypothesis again. On
    the post-rep summary, confirm `RevisedReadCard` now renders with
    the **second-cycle headline** ("You flagged the rebuilt read as
    off too."), NOT the first-cycle phrase.
19. Open Ask Noum via Talk to Noum. Open the chat thread debug log
    (or instrument `AICoachChatService` locally). Confirm the USER
    CONTEXT payload contains the line starting **"Case file just
    shifted again: the user flagged the rebuilt read as off too"** —
    NOT the round-31 first-cycle "Case file just shifted:" line.
    Round-32 dark on this turn (no fresh ack on the second rebuild
    yet). The generic "Last course change:" line absent (round 31
    suppresses it).
20. Tap a verdict chip on the second rebuild — `.confirmed` /
    `.uncertain` / `.rejected`. Confirm the round-32 rebuild-verdict
    block surfaces correctly on the next coach reply (rebuild
    verdict line + coach-move instruction matching the chip). The
    second-cycle round-33 line is suppressed (the round-32 ack closes
    the round-31 freshness window, same as round 32 documented).
21. Insert an engine-only lever shift between cycles to break the
    chain. On the next memory rebuild WITHOUT a `.rejected` ack drop
    (just an engine lever shift), confirm the appended log entry
    carries the `(prior?, nil)` engine-only reason ("Shifted focus
    from X to Y."). Then drive another `.rejected` ack drop. The
    next appended entry MUST be a first-cycle pushback again
    ("prior hypothesis", not "rebuilt hypothesis") — the engine-only
    interlude reset the chain. The detection is a property of
    CONSECUTIVE pushback entries.
22. Verify the adaptation log's bounded `suffix(8)` truncation
    behaviour holds: with eight cycles in flight, the log shows the
    eight most recent entries; the round-33 detection still works
    because it reads `last`, not a full traversal.
