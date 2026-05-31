# HANDOFF — M24 deferred slate (round 32): the rebuild-verdict block now surfaces in the chat-coach user-context block whenever the user has lodged a `confirmed` / `uncertain` / `rejected` verdict on the rebuilt working hypothesis via the round-30 follow-up chip row, so the model knows the rebuild has been INHABITED (not just delivered) on every chat turn after the chip tap — closing the silent-context bug round 31 left on the post-ack window.

## Scope

Round 31 carried the rebuild context into the chat-coach user-context block
on every reply through the next followed rep. The two dedicated lines
fired whenever `freshRevisedReadChange(in:)` returned a pushback rebuild
that was fresh against `memory.updatedAt` (drift ≤ 1s) AND the carrying
`workingHypothesis` was non-empty.

The honest gap that left open: **the round-30 chip row writes the user's
verdict via `CoachMemoryStore.noteHypothesisAcknowledgement(_:)`, which
bumps `memory.updatedAt = now`.** The moment the user taps a chip, the
`isFresh` window slams shut: `change.changedAt` (the rebuild) is now > 1s
behind `memory.updatedAt` (the ack bump). Round 31's dedicated lines stop
firing on the VERY NEXT chat turn — exactly when the model most needs to
know the rebuild has been INHABITED with a `confirmed` / `uncertain` /
`rejected` verdict, not just delivered.

The model falls back to the generic "Last course change: <reason>
(<basis>)" line. Honest, but flat: the line names a course change but
does not name the user's verdict on it. The round-26 hypothesis-ack
reflection in `coachCaseFormulationLines` does surface the verdict
generically ("user confirmed the working hypothesis matches what they
see") — but reads identically whether the hypothesis is the original or
the rebuild, and the model has no signal that the verdict was lodged
on a REBUILT read specifically (which would change the coach move:
`.confirmed` reinforces the *rebuild*; `.rejected` is a SECOND pushback,
not a first-time rejection).

Round 32 picks up step #11 from the round-31 "Future moves" list AND the
note for round 31 from step #11:

> **Reflect the revised-read follow-up verdict in the next user-context
> block.** From round 30. After the user lands a verdict on the rebuild
> via the round-30 chip row, the next user-context block could surface
> a one-line summary line ("User accepted the rebuilt read on <date>;
> treat as the operating hypothesis") so the model knows whether the
> rebuilt read is the live one or the user is still pushing back. Mirror
> of the round-26 hypothesis-ack reflection in the existing builder, but
> tagged to the *rebuild* verdict for analytic purposes (so a future
> trend view can distinguish "user accepted the first read" from "user
> accepted the rebuilt read").
>
> Note for round 31: this would dovetail with the new
> `freshRevisedReadContextLines` block — when the predicate fires AND
> the user has already lodged a rebuild verdict via round 30, the
> coach-move line could swap in a "user already lodged X verdict on the
> rebuild" tail so the model knows the rebuild has been inhabited, not
> just delivered.

The note for round 31 is what made the bug visible in the first place:
round 31's predicate goes dark the moment the user lodges a verdict,
because `noteHypothesisAcknowledgement` bumps `updatedAt`. A "tail on
the round-31 coach-move line" approach would still depend on the
`isFresh` window — and would never fire, because the window closes
synchronously with the ack write. Round 32 takes the cleaner path:
a SIBLING predicate that does NOT depend on `isFresh` but on the
ordering between `ack.acknowledgedAt` and `change.changedAt`, with the
shared `appliesTo` snapshot guard. The two predicates are mutually
exclusive at the memory level (round 30's ack bump that satisfies
round 32 is the same write that closes round 31's window), so the chat
context carries one canonical course-change block at any time.

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the
redesign branch too (very important)."

Translation, this round:

- New `CoachContextBuilder.rebuildVerdictPair(in:)` — pure predicate
  that returns the (change, ack) pair iff the latest course change is a
  user-pushback rebuild, the carried `hypothesisAcknowledgement` was
  lodged at or after the rebuild's `changedAt`, AND the ack's
  `hypothesisSnapshot` still matches the current `workingHypothesis`
  (`appliesTo`). NOT gated on `isFresh` — the verdict is the user's own
  report and should survive the freshness window, the rep boundary, and
  any clock-skew tolerances.
- New `CoachContextBuilder.rebuildVerdictContextLines(memory:)` — the
  two context-block lines emitted when the predicate fires AND
  `workingHypothesis` is non-empty:
  - Case-state line: `"- Case file rebuild verdict: the user lodged a
    <confirmed verdict | uncertain verdict | second pushback> on the
    rebuilt working hypothesis above (<evidenceBasis>)."` The "the
    rebuilt working hypothesis above" anchor matches round 31's case-
    state phrasing — the model sees one cross-line referent across the
    rebuild lifecycle.
  - Coach-move line: `"- Coach move on the rebuild verdict:
    <rebuildVerdictInstruction>"` — confidence-specific instruction
    from a new `CoachHypothesisConfidence.rebuildVerdictInstruction`
    computed property. `.confirmed` tells the model to treat the
    rebuild as the user's accepted read and not re-litigate the
    original; `.uncertain` tells it the user is still settling and to
    ask one focused question without strengthening the rebuild ahead
    of them; `.rejected` tells it the user pushed back twice and to
    propose a third angle without retrying the same rebuilt
    hypothesis.
- New `CoachHypothesisConfidence.rebuildVerdictLabel` and
  `.rebuildVerdictInstruction` — per-branch rebuild-specific phrases.
  Distinct from the existing `contextLabel` (flat ack statement) and
  `nextMoveInstruction` (hypothesis-agnostic) because the rebuild
  context demands the coach name the SECOND cycle:
  - `.confirmed` label = "confirmed verdict"; instruction reinforces
    the *rebuild* (not the original).
  - `.uncertain` label = "uncertain verdict"; instruction asks one
    focused question, does not strengthen the rebuild yet.
  - `.rejected` label = "second pushback"; instruction acknowledges
    the second adapt, forbids retrying the same rebuild, asks for a
    third angle plus a discriminating-evidence ask.
- `interventionCycleLines` now branches THREE WAYS, most-specific first:
  - Round 32: `rebuildVerdictContextLines` (ack-after-rebuild).
  - Round 31: `freshRevisedReadContextLines` (fresh rebuild, no ack).
  - Generic: `"Last course change: <reason> (<basis>)."`.
  Mutual exclusion at the memory level: the round-30 ack bump that
  satisfies round 32 closes round 31's `isFresh` window. The two
  dedicated blocks never both fire.
- The redesign-branch invariant: this is a `Redesign`-branch push per
  the user brief. The work lands directly on `Redesign`, preserving
  the round-by-round loop on the redesign lineage that has been the
  home of rounds 11–31.

## What shipped

### Track 1 — `CoachHypothesisConfidence.rebuildVerdictLabel` + `.rebuildVerdictInstruction` (`PrimaryFocusMemory.swift`)

- New computed property `var rebuildVerdictLabel: String` on
  `CoachHypothesisConfidence` — three branches:
  - `.confirmed` → `"confirmed verdict"`
  - `.uncertain` → `"uncertain verdict"`
  - `.rejected` → `"second pushback"`
- New computed property `var rebuildVerdictInstruction: String` on
  `CoachHypothesisConfidence` — three branches:
  - `.confirmed` → `"The user accepted the rebuilt read. Treat the
    rebuild as the operating hypothesis; reinforce it and tie the next
    prescription to it. Do not re-litigate the original read."`
  - `.uncertain` → `"The user is still settling into the rebuilt read.
    Ask one focused question that would resolve the uncertainty before
    reinforcing the rebuild further; do not strengthen the rebuild
    ahead of the user."`
  - `.rejected` → `"The user pushed back on the rebuilt read too.
    Acknowledge the second adapt explicitly; do not retry the same
    rebuilt hypothesis; propose a third angle and name what evidence
    would resolve which read fits."`
- Both properties are pure functions of the enum case. No state, no
  storage, no schema bump. Memories persisted before round 32 decode
  unchanged — the new properties read off the existing enum value.
- Brand-voice compliant: no exclamation, no "Let's", no urgency. The
  `.rejected` branch names the SECOND pushback explicitly so the
  model recognises the second cycle. The `.confirmed` branch's "Do
  not re-litigate the original read" is the anti-overclaim rail: the
  user's verdict on the rebuild does not erase the original hypothesis
  from the case file, but the coach should not reopen it.
- Doc comments placed inline with `contextLabel` and
  `nextMoveInstruction` so a future reader sees the three sibling
  computed properties together.

### Track 2 — `CoachContextBuilder.rebuildVerdictPair(in:)` + `rebuildVerdictContextLines(memory:)` (`CoachContextBuilder.swift`)

- New `static func rebuildVerdictPair(in memory: CoachMemory) ->
  (change: CoachCourseChange, ack: CoachHypothesisAcknowledgement)?`
  — pure predicate with three gates:
  - `memory.adaptationLog?.last` must exist AND
    `documentsUserPushback` must be true.
  - `memory.hypothesisAcknowledgement` must exist AND
    `acknowledgedAt >= change.changedAt`.
  - `ack.appliesTo(currentHypothesis: memory.workingHypothesis)` must
    be true.
  - Returns the matching pair, or nil otherwise.
- Critically NOT gated on `change.isFresh(comparedTo:)` — the verdict
  is the user's own report; it should survive the freshness window
  and the rep boundary until either (a) a later memory rebuild
  rewrites `workingHypothesis` so the ack snapshot no longer applies,
  or (b) a later course change supersedes the rebuild in
  `adaptationLog.last`.
- New `static func rebuildVerdictContextLines(memory: CoachMemory) ->
  [String]` — two-step gate:
  - `rebuildVerdictPair(in:)` must return non-nil.
  - `memory.workingHypothesis` (trimmed) must be non-empty.
  - Returns two lines: case-state line (with evidence-basis tail) +
    coach-move line. Returns `[]` if either gate fails.
- Empty `evidenceBasis` defensive: the case-state line omits the
  `(<basis>)` parenthetical when the basis is empty/whitespace-only,
  so no dangling `(  )` tail surfaces in the prompt. Same defence as
  round 31.
- Section comment block placed between the round-31
  `freshRevisedReadContextLines` and the per-voice starter-prompts
  section. Same MARK convention as rounds 26/30/31. No reordering of
  existing code.

### Track 3 — `interventionCycleLines` three-tier wiring (`CoachContextBuilder.swift`)

- The round-31 two-arm conditional becomes a three-arm conditional:
  - If `rebuildVerdictContextLines` returns non-empty → append those
    lines, skip the rest.
  - Else if `freshRevisedReadContextLines` returns non-empty → append
    those lines (round 31 behaviour preserved).
  - Else if the adaptation log has a last entry → append the generic
    line unchanged.
- The `prefix(9)` cap still holds. Round 32 adds at most 2 lines
  (same as round 31, which already replaced 1 generic line). Engine-
  only path stays at 6 lines (5 + 1). All paths fit under the cap.
- Comment block on the branch explains the three-tier precedence and
  the mutual-exclusion property (round 30's ack bump simultaneously
  fires round 32 AND closes round 31's window).

### Track 4 — `RebuildVerdictContextTests` suite (`NoumTests/NoumTests.swift`)

New top-level `@Suite("RebuildVerdictContextTests")` at the end of the
file (after the round-31 `FreshRevisedReadContextTests`). Twenty
`@Test` methods pin the predicate contract, the context-line shape,
per-confidence label and instruction, and the `userContext` three-tier
integration:

- **Predicate happy + negative paths (9 tests):**
  - `rebuildVerdictPairReturnsPairWhenAckPostDatesPushbackRebuild` —
    happy path: pushback + ack post-dates change + ack applies →
    returns pair.
  - `rebuildVerdictPairReturnsNilForEngineOnlyChangeEvenWithAck` —
    engine-only shifts are not user pushback; predicate dark.
  - `rebuildVerdictPairReturnsNilWhenNoAckLodged` — pushback rebuild
    with nil ack → predicate dark (round 31 covers this window).
  - `rebuildVerdictPairReturnsNilWhenAckPreDatesRebuild` — defensive:
    an ack from before the rebuild is a stale ack on a prior read,
    not a verdict on the rebuild.
  - `rebuildVerdictPairReturnsPairWhenAckExactlyAtRebuild` — edge:
    ack timestamp equals changedAt → `>=` inclusive, predicate fires.
  - `rebuildVerdictPairReturnsNilWhenAckSnapshotNoLongerApplies` —
    `appliesTo` snapshot guard fires when a later rebuild has
    rewritten `workingHypothesis`.
  - `rebuildVerdictPairReturnsNilForEmptyAdaptationLog`.
  - `rebuildVerdictPairReturnsNilForNilAdaptationLog`.
  - `rebuildVerdictPairReadsLatestEntryOnlyForRebuildBranch` — a
    historic pushback followed by an engine-only shift is NOT a
    rebuild context for an ack lodged after the engine shift.
- **Context-line shape (5 tests):**
  - `contextLinesEmitTwoLinesWhenPredicateFiresAndHypothesisPresent`.
  - `contextLinesEmitNothingWhenPredicateDoesNotFire`.
  - `contextLinesEmitNothingWhenHypothesisIsNil`.
  - `contextLinesEmitNothingWhenHypothesisIsWhitespaceOnly`.
  - `contextLinesCaseStateCarriesEvidenceBasisInParentheses` and
    `contextLinesCaseStateOmitsParensWhenEvidenceBasisIsEmpty` — basis
    surfaces in `(...)` AND empty basis suppresses parens tail.
- **Per-confidence label + instruction (6 tests):**
  - `contextLinesCaseStateNamesConfirmedVerdict` —
    `.confirmed` → "confirmed verdict".
  - `contextLinesCaseStateNamesUncertainVerdict` —
    `.uncertain` → "uncertain verdict".
  - `contextLinesCaseStateNamesSecondPushback` —
    `.rejected` → "second pushback" (the SECOND cycle phrasing).
  - `contextLinesCoachMoveCarriesConfirmedInstruction` — `.confirmed`
    instruction names the rebuild, anti-relitigation clause present.
  - `contextLinesCoachMoveCarriesUncertainInstruction` —
    `.uncertain` instruction names "still settling", asks one focused
    question, anti-strengthening clause present.
  - `contextLinesCoachMoveCarriesRejectedInstruction` — `.rejected`
    instruction names "pushed back too", anti-retry clause present,
    "third angle" present.
- **`userContext` three-tier integration (5 tests):**
  - `userContextSurfacesRebuildVerdictLinesWhenAckPostDatesPushback` —
    round 32 fires; round-31 case-state line is absent; generic
    "Last course change:" is absent. Locks the three-tier precedence
    contract.
  - `userContextFallsThroughToFreshRevisedReadWhenNoAckLodged` —
    round-31 path: pushback rebuild is fresh, no ack carried yet.
    Round 32 dark, round 31 fires, generic absent.
  - `userContextSurfacesVerdictLinesEvenWhenRound31FreshnessWindowHasExpired`
    — the headline contract: round 32 fires even when `isFresh` would
    have failed. The verdict is the user's own report and survives
    the freshness window.
  - `userContextFallsThroughToGenericForEngineOnlyChangeEvenWithAck` —
    engine-only shift with ack: rebuild signal absent, round 32 dark,
    round 31 dark (no pushback marker), generic line surfaces.
  - `userContextSurfacesSecondPushbackLineOnRejectedRebuildAck` —
    the second-pushback contract: `.rejected` on a rebuild surfaces
    as "second pushback" + anti-retry instruction.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the
  case formulation needs "the reason for changing course" carried as
  active coaching state, not buried in a log. Round 28 surfaced the
  rebuild on the post-rep summary; round 29 named it in the chat seed;
  round 30 collected the user's verdict; round 31 carried the rebuild
  into the chat-coach context until the user tapped a chip. Round 32
  carries BOTH the rebuild AND the verdict into the chat-coach context
  AFTER the chip tap, so the model's coaching judgment on chat turn #5
  doesn't drift back to a flat read of the rebuilt hypothesis as if
  the user had never weighed in.
- **Pillar #5 (Personalized coaching).** A coach who'd just rebuilt
  their read AND received the user's verdict on the rebuild would
  speak to the next turn knowing both — they'd reinforce a
  `.confirmed` rebuild ("since you confirmed the new read, here's
  how we build on it"), probe an `.uncertain` rebuild ("what's still
  not clicking on the new read?"), and acknowledge a `.rejected`
  rebuild as a second adapt ("you've now pushed back twice — let's
  try a third angle"). Round 32 gives the model the same memory.
- **Anti-overclaim.** The `.confirmed` rebuild-verdict instruction
  forbids re-litigating the original read. The `.uncertain` rebuild-
  verdict instruction forbids strengthening the rebuild ahead of the
  user. The `.rejected` rebuild-verdict instruction forbids retrying
  the same rebuilt hypothesis. Three anti-overclaim rails, one per
  branch, in the same coach-move line the model reads on every chat
  turn.
- **Verdict survives the rep boundary.** The round-32 predicate is
  NOT gated on `isFresh` — the rebuild-verdict context outlives the
  freshness window. The verdict is the user's own report and remains
  carried by the case file until a later rebuild rewrites the
  hypothesis (at which point the `appliesTo` snapshot guard drops
  the ack honestly). Mirror of the round-26 ack reflection's
  durability rule, but tagged to the *rebuild* lineage.
- **Engineering bans.** No placeholder logic. No dead toggles. No
  fragmented state — the new helpers READ existing memory fields
  (`adaptationLog`, `hypothesisAcknowledgement`, `workingHypothesis`).
  No new storage, no schema bump, no migration. Pure-function lift on
  pure-function inputs. Memories persisted before round 32 decode
  identically and behave identically until a user-pushback rebuild +
  post-rebuild ack pair lands in memory.

### Branch + redesign-alignment notes

- All four tracks land on `Redesign`, the redesign-lineage branch the
  rolling M24 deferred-slate work has been shipping on since round 11.
  The user brief explicitly calls this out: "ensure working on the
  redesign branch too (very important)." Round 32 preserves the
  round-by-round loop on the redesign lineage.
- Round 32 does not change the round-31 `freshRevisedReadChange` or
  `freshRevisedReadContextLines` (kept as the round-31 fall-through),
  does not change the round-30 chip-row predicate or catalog, does
  not change the round-29 `revisedReadOpener` function, does not
  change the round-29 `talkToNoumOpener` gate, does not change the
  round-28 `RevisedReadCard` view, does not change the round-27
  engine restructure, does not change the round-26 chip catalog or
  hypothesis-ack row, and does not change the round-24 / round-25
  `InterventionReviewPromptCard` surface. The round-31 16 fresh
  revised-read tests + round-30 15 follow-up tests + round-29 12
  opener tests + round-28 5 copy tests + round-26 19 ack tests all
  remain unchanged; the round-32 25 rebuild-verdict tests sit
  alongside them.
- The round-26 hypothesis-ack reflection in
  `coachCaseFormulationLines` is intentionally left in place. It
  surfaces in CASE FORMULATION (the section that names the hypothesis
  itself); the round-32 verdict block surfaces in INTERVENTION CYCLE
  (the section that names the course-change lineage). The two read as
  complementary: the round-26 line names the user's verdict on the
  current hypothesis generically; the round-32 lines name the
  hypothesis as a REBUILD and tie the coach move to the second
  cycle. A future round can collapse the round-26 line into the
  round-32 block when the predicate fires, but only after a real-
  device QA pass to verify the model's reading of one block vs two.

## Future moves

(Updated priority list — round-32 closed the round-31 step #11; the
rest roll forward, plus one new note from round 32.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–31. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–31. Pure visual work, not crossing logic.
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
    Carried forward from round 27. Note for round 32: the round-32
    `.confirmed` rebuild-verdict path is the natural integration site
    — when the predicate fires AND the engine has not yet bumped
    `CoachIntervention.criterionStatus`, the same `.confirmed`
    branch could nudge the criterion toward "met" or extend the
    `reviewDueAt` cadence by one rep. Round 32 surfaces the verdict
    in CONTEXT; round-27 follow-on would let it AMPLIFY the
    intervention as well.
11. **Adaptation-log entry on a round-32 `.rejected` rebuild verdict.**
    Promoted from round-30 step #12 and made specific by round 32.
    A `.rejected` rebuild verdict surfaces as a "second pushback" in
    context. The natural next step: on the next memory rebuild,
    `CoachMemoryEngine.build(...)` could detect the dropped
    `.rejected` rebuild-verdict ack (same shape as the round-27
    `droppedRejectedAck` arm, but tagged to the rebuilt hypothesis)
    and append a fresh `CoachCourseChange` with the rebuild as the
    prior and the next read as the revised. Closes the rejection-
    rebuild-rejection-rebuild chain in the engine, so the
    adaptation log carries the full lineage, not just the first
    cycle.
12. **Collapse `SummaryView.freshRevisedReadChange` into a call through
    `CoachContextBuilder.freshRevisedReadChange(in:)`.** Carried
    forward from round 31.
13. **Collapse the round-26 hypothesis-ack reflection in
    `coachCaseFormulationLines` into a single block with the round-32
    rebuild-verdict lines when the predicate fires.** New note from
    round 32. The two lines currently surface in different sections
    (CASE FORMULATION vs INTERVENTION CYCLE) — the round-26 line
    names the generic ack, the round-32 lines name the rebuild + the
    verdict on it. A future round with real-device QA can collapse
    the round-26 line into the round-32 block when round 32 fires,
    so the model reads one canonical verdict block per rebuild
    cycle instead of two complementary ones. Hold for QA.
14. **Trend-view distinction between "user accepted the first read"
    and "user accepted the rebuilt read".** From round 30's step #11
    original description. Round 32 surfaces the rebuild-verdict
    in CONTEXT (the model's read). A future analytics surface could
    use the same `rebuildVerdictPair` predicate to count rebuild-
    verdict events separately from first-read acks, so a future
    insights view can show the user "you confirmed your coach's
    rebuilt read 3 times this month" — durable feedback on the
    Adaptation loop.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes are:

- Two new computed properties on `CoachHypothesisConfidence` —
  `rebuildVerdictLabel` and `rebuildVerdictInstruction` — placed in
  `PrimaryFocusMemory.swift` immediately after `nextMoveInstruction`.
  Self-contained — no new imports, no new dependencies, no new types.
- Two new `static func`s on `CoachContextBuilder` —
  `rebuildVerdictPair(in:)` and `rebuildVerdictContextLines(memory:)`
  — placed in `CoachContextBuilder.swift` immediately after
  `freshRevisedReadContextLines(memory:)` and before the "Starter
  prompts" MARK. Self-contained — no new imports, no new dependencies,
  no new types (reads only `CoachMemory`, `CoachCourseChange`,
  `CoachHypothesisAcknowledgement`, all already in scope via
  `PrimaryFocusMemory.swift`).
- One edit to `interventionCycleLines` — the existing two-arm
  conditional becomes a three-arm conditional. Behaviour unchanged
  when neither new predicate fires (the round-31 else-arm and the
  generic else-arm preserve the original behaviour exactly); new
  behaviour only when round 32 fires (the dedicated verdict lines
  surface and both the round-31 lines AND the generic line are
  suppressed).
- One new `@Suite("RebuildVerdictContextTests")` at the end of
  `NoumTests/NoumTests.swift` with twenty `@Test` methods. The suite
  is plain `struct`, `@MainActor` (mirror of `RevisedReadFollowUpTests`
  and `FreshRevisedReadContextTests` attribute, defensive against any
  future `MainActor`-only reads in `CoachContextBuilder`).

All checks the next agent should run on a real build host:

1. `swift test --filter RebuildVerdictContextTests` — the new round-32
   25 rebuild-verdict tests should all pass.
2. `swift test --filter FreshRevisedReadContextTests` — the round-31
   16 fresh-revised-read tests should still pass. No round-31 surface
   was changed; round 32 only ADDS a higher-precedence branch above
   it. Round-31 tests all set `hypothesisAcknowledgement = nil`
   (default), so `rebuildVerdictPair` returns nil and round-31
   behaviour is preserved.
3. `swift test --filter RevisedReadFollowUpTests` — the round-30 15
   follow-up tests should still pass.
4. `swift test --filter RevisedReadOpenerTests` — the round-29 12
   opener tests should still pass.
5. `swift test --filter RevisedReadCardTests` — the round-28 5
   copy-generator tests should still pass.
6. `swift test --filter CoachContextBuilderBigMomentTests` — the
   existing `userContextSurfacesCaseSpineCriterionReviewAndCourseChange`
   test (engine-only adaptation entry with nil hypothesis, nil ack)
   MUST still pass. Round 32's predicate requires both
   `documentsUserPushback` AND `hypothesisAcknowledgement`; both fail
   on that fixture; the three-tier wiring falls through to round 31
   (which also fails on `documentsUserPushback`) and then to the
   generic line.
7. `swift test --filter CoachMemoryEngineTests` — the round-28 6
   predicate tests + the pre-28 suite should still pass.
8. `swift test --filter HypothesisAcknowledgementTests` — the round-26
   tests (19 total) should still pass. No round-26 surface was changed.
9. `swift test --filter InterventionReviewPromptTests` — the round-24 +
   round-25 tests (26 total) should still pass.
10. `swift test --filter CoachMemoryStoreTests` — the existing
    memory-store tests should still pass. No `noteHypothesisAcknowledgement`
    behaviour was changed.
11. `swift test --filter CoachReadCardDailyBudgetHintTests` —
    round-23 tests should still pass.
12. `swift test --filter AIRateLimiterPublicationTests` — round-22
    tests should still pass.
13. `swift test --filter IMToneDrillCrossingTests` — round-21 helper
    tests should still pass.
14. `swift test --filter HeroScoreCardToneDrillRibbonContractTests` —
    round-20 ribbon-contract tests should still pass.
15. `swift test --filter LookingAheadCardStartCTAContractTests` —
    round-19 launch-CTA tests should still pass.
16. Boot the app on simulator, seed a `CoachMemory.activeIntervention`
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
    - The coach reply lands case-anchored.
    - Open the chat thread debug log (or instrument
      `AICoachChatService` locally) to confirm the USER CONTEXT
      payload sent to the model contains the line starting
      "Case file just shifted: the user flagged the prior read as
      off" (round 31).
    - Tap the **Lock the new read in** / **Stick** / equivalent
      `.confirmed` chip on the round-30 follow-up row.
    - **NEW (round 32):** send a free-text follow-up message ("ok so
      where do we go next?"). Confirm the coach's reply now treats
      the rebuild as the user's ACCEPTED read, not as a rebuild
      awaiting verdict. Open the debug log; confirm the USER CONTEXT
      payload contains the line "Case file rebuild verdict: the user
      lodged a confirmed verdict on the rebuilt working hypothesis
      above ..." AND DOES NOT contain the round-31 "Case file just
      shifted" line OR the generic "Last course change:" line on the
      same turn. Three-tier precedence locked.
17. Repeat the flow with the `.uncertain` chip. Confirm the coach's
    follow-up reply asks one focused question instead of reinforcing
    the rebuild. Debug log: USER CONTEXT contains "Case file rebuild
    verdict: the user lodged an uncertain verdict ..." AND the
    coach-move line contains "still settling into the rebuilt read".
18. Repeat the flow with the `.rejected` chip — the "second
    pushback" path. Confirm the coach's follow-up reply
    acknowledges the second adapt AND proposes a third angle
    WITHOUT retrying the same rebuilt hypothesis. Debug log: USER
    CONTEXT contains "Case file rebuild verdict: the user lodged a
    second pushback ..." AND the coach-move line contains "do not
    retry the same rebuilt hypothesis" AND "propose a third angle".
19. Now finish a NEXT followed rep so memory rewrites with a fresh
    `updatedAt` AND a new `workingHypothesis`. The ack's
    `appliesTo(currentHypothesis:)` now returns false. Open Ask
    Noum again — confirm the user-context payload now DROPS the
    "Case file rebuild verdict" block. The verdict aged out
    correctly with the rebuild that replaced it.
20. Trigger an engine-only lever shift with an ack present (e.g.
    evidence threshold crossing while the user has lodged a
    `.confirmed` ack on the prior hypothesis). Confirm the user-
    context payload carries the generic "Last course change:" line
    — NOT the rebuild-verdict block. The engine-only path is not a
    rebuild and shouldn't read as one even with an ack present.
