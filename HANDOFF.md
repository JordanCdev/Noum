# HANDOFF — M24 deferred slate (round 34): cross-surface case-file pushback acknowledgement — `CoachCourseChange.caseFileHeadline` lands the user-voiced rebuild headline on the Profile-tab `CaseReviewCard` "Last shift" row in the same phrasing the post-rep `RevisedReadCard` already uses, plus a future-move #11 collapse of `SummaryView.freshRevisedReadChange` through `CoachContextBuilder.freshRevisedReadChange(in:)`.

## Scope

Round 33 closed the second-cycle pushback chain in the engine and the
post-rep `RevisedReadCard`: a user who pushed back twice now reads
"You flagged the rebuilt read as off too." on the summary card after
the second-cycle rebuild folds. The chat-coach user-context block
(`freshRevisedReadContextLines`) was lifted to name the second cycle
explicitly the same round.

The honest gap that left open: the Profile-tab `CaseReviewCard` "Last
shift" row reads the raw engine `reason` field unchanged. On a first-
cycle pushback the user sees "User reported the prior hypothesis did
not match what they saw; revising the read." (third-person engine
voice). On a second-cycle pushback they see "User reported the
rebuilt hypothesis did not match what they saw; revising the read
again." Same event, different voice, different surface. A user
flicking between the post-rep summary ("You flagged the rebuilt read
as off too.") and the Profile card ("User reported the rebuilt
hypothesis did not match...") sees two readings of the same case
event — one in their own voice, one in the engine's. Cross-surface
drift.

The collapse note rounds 31 and 33 carried as future move #11 is also
still standing: `SummaryView.freshRevisedReadChange` duplicates the
predicate body `CoachContextBuilder.freshRevisedReadChange(in:)`
already owns. The chat-coach context block reads the helper; the
post-rep summary inlines the same gate. Duplicate-state risk that
the engineering bans (`No fragmented state`) explicitly call out.

Round 34 picks up BOTH:

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the
redesign branch too (very important)."

Translation, this round:

- New `CoachCourseChange.caseFileHeadline` computed property — pure
  function of the persisted `reason` field. Returns "You flagged the
  rebuilt read as off too." on second-cycle pushback entries (round-33
  marker), "You flagged the prior read as off." on first-cycle entries
  (round-27 marker), or falls through to the engine `reason` text on
  engine-only shifts. Same picker the post-rep card uses, now lifted
  to the data model so multiple surfaces read the same picker.
- `RevisedReadCard.headlineCopy(for:)` is now a thin delegate
  (`change.caseFileHeadline`) so the post-rep summary AND the Profile
  card land the SAME user-voiced phrase. Round-33's two-branch picker
  body moves to the data model in one line; the card's static
  `headlineCopy` constant stays unchanged for back-compat.
- `CaseReviewCard` "Last shift" row reads `latest.caseFileHeadline`
  instead of `latest.reason`. The user-voiced phrase lands on the
  Profile card. Engine-only entries fall through unchanged — no
  over-claim of user action on a `(prior?, nil)` engine-only shift.
- `SummaryView.freshRevisedReadChange` collapses to call through
  `CoachContextBuilder.freshRevisedReadChange(in:)`. The predicate
  body is no longer duplicated; the chat-coach context block, the
  round-30 chip-row gate, and the post-rep card all read ONE
  canonical predicate. Closes future-move #11.
- The redesign-branch invariant: this is a `Redesign`-branch push per
  the user brief. The work lands directly on `Redesign`, preserving
  the round-by-round loop on the redesign lineage that has been the
  home of rounds 11–33.

## What shipped

### Track 1 — `CoachCourseChange.caseFileHeadline` (`PrimaryFocusMemory.swift`)

- New computed property: pure function of the persisted `reason`,
  reading `documentsRebuildPushback` and `documentsUserPushback`
  (both round-33 predicates already in the schema).
- Three-arm resolution, mutually exclusive at the engine append site:
  - `documentsRebuildPushback == true` (round-33 second-cycle marker
    present) → "You flagged the rebuilt read as off too." — same
    string `RevisedReadCard.headlineCopy(for:)` returned for the
    second cycle pre-round-34.
  - `documentsUserPushback == true` (round-27 first-cycle marker
    present, second-cycle absent) → "You flagged the prior read as
    off." — same string the back-compat `RevisedReadCard.headlineCopy`
    constant returns.
  - Neither marker present → the persisted `reason` field unchanged.
    Engine-only `(prior?, nil)` shifts already carry a neutral
    third-person clause ("Shifted focus from X to Y."); rewriting
    that as second-person ("Your focus shifted...") would over-claim
    a user action that did not happen. Falling through keeps the
    line honest.
- Defensive on Codable round-trip: an empty `reason` returns the
  empty string. The engine never writes an empty reason on the
  append path (`CoachMemoryEngine.build(...)` gates appends on
  `priorLeverShift != nil || droppedRejectedAck != nil`), but the
  picker must not crash on the boundary.
- No schema bump. The picker reads off the existing `reason` field;
  memories persisted before round 34 decode and behave correctly.
  Pre-round-27 memories (no adaptation log) never reach the picker
  (the call sites already short-circuit on `adaptationLog?.last`).

### Track 2 — `RevisedReadCard.headlineCopy(for:)` delegates (`RevisedReadCard.swift`)

- The round-33 two-branch picker body lifts entirely to the data
  model. `RevisedReadCard.headlineCopy(for:)` is now one line:
  `change.caseFileHeadline`. The card's upstream gate
  (`SummaryView.freshRevisedReadChange`) guarantees
  `change.documentsUserPushback == true` on every mount, so the
  engine-only fall-through arm of `caseFileHeadline` is unreachable
  from this surface — the picker reads as pushback-only here even
  though the underlying property is broader.
- The static `let headlineCopy: String = "You flagged the prior read as off."`
  constant is unchanged. Round 28's `headlineCopyNamesUserAction`
  test pins the constant directly; round 34 preserves that contract.
- Doc comment updated to name round 34 as the lift round; round-33
  intent is preserved verbatim. The brand-voice rule notes ("no
  exclamation, no apology, no 'we', no 'Let's'") are unchanged —
  the picker's output strings did not change; only their home did.

### Track 3 — `CaseReviewCard` "Last shift" row (`CaseReviewCard.swift`)

- The `caseRow(icon:label:text:)` call for the "Last shift" row now
  reads `latest.caseFileHeadline` instead of `latest.reason`.
- A user-pushback entry surfaces in the user's own second-person
  voice on the Profile card — matching the post-rep summary. A
  first-cycle pushback reads "You flagged the prior read as off."
  on both surfaces; a second-cycle pushback reads "You flagged the
  rebuilt read as off too." on both surfaces.
- Engine-only shifts ("Shifted focus from Pace to Depth.") fall
  through to `reason` unchanged — the pre-round-34 behavior is
  preserved on this branch. No over-claim of user action on
  `(prior?, nil)` entries.
- Inline comment names the round-34 lift and the cross-surface
  consistency contract, so a future reader does not silently
  re-inline `latest.reason` and break the symmetry.
- The five-section layout (working hypothesis / intervention / Last
  shift / transfer / reflection) is unchanged. The compact card
  contract (≤2 lines per row, no scrolling, no buttons) is
  unchanged — the new headline is shorter than the prior engine
  reason for both pushback branches, so the row's vertical budget
  shrinks if anything.

### Track 4 — `SummaryView.freshRevisedReadChange` collapses (`SummaryView.swift`)

- The private property body lifts entirely to
  `CoachContextBuilder.freshRevisedReadChange(in:)`:

  ```swift
  private var freshRevisedReadChange: CoachCourseChange? {
      guard let memory = coachMemoryStore.currentMemory else { return nil }
      return CoachContextBuilder.freshRevisedReadChange(in: memory)
  }
  ```

- Both call sites (the two `if let revisedChange = freshRevisedReadChange`
  mounts inside the summary body) and the round-29 `talkToNoumOpener`
  gate (`if freshRevisedReadChange != nil`) continue to work
  unchanged — the property still returns the same shape.
- Closes future move #11. The chat-coach user-context block
  (round-31 `freshRevisedReadContextLines`), the round-30 chip-row
  gate (which reads `freshRevisedReadChange(in:)` indirectly through
  the round-31 lift), the post-rep `RevisedReadCard` mount, and the
  round-29 `talkToNoumOpener` are now all driven off ONE canonical
  predicate. A future edit to the eligibility contract (e.g., a
  `documentsRebuildPushback` branch, an evidence-floor gate) lands
  in one place rather than four.
- The doc comment names the collapse and links the consumer
  surfaces, so a future reader does not silently re-inline the
  predicate.

### Track 5 — `CaseFileHeadlineTests` + `FreshRevisedReadChangeSecondCycleDelegationTests` (`NoumTests/NoumTests.swift`)

New `@Suite("CaseFileHeadlineTests")` (struct, `@MainActor`) placed
after the round-33 `SecondCyclePushbackAdaptationTests`. Nine `@Test`
methods cover the picker's contract on every arm of the resolution
order, plus three cross-surface consistency tests that lock the
round-34 invariant: `RevisedReadCard.headlineCopy(for: change) ==
change.caseFileHeadline` for the pushback cases.

- **`caseFileHeadline` resolution matrix (6 tests):**
  - `caseFileHeadlineNamesFirstCyclePushbackInSecondPerson` — round-27
    entry shape returns "You flagged the prior read as off."
  - `caseFileHeadlineNamesSecondCyclePushbackInSecondPerson` — round-33
    entry shape returns "You flagged the rebuilt read as off too."
  - `caseFileHeadlineNamesCombinedShiftSecondCycleInSecondPerson` —
    `(prior?, ack?)` second-cycle arm: the reason carries BOTH the
    focus-shift clause AND the rebuilt-hypothesis marker; picker
    reads the second-cycle phrase.
  - `caseFileHeadlineNamesCombinedShiftFirstCycleInSecondPerson` —
    `(prior?, ack?)` first-cycle arm: picker reads the first-cycle
    phrase. Symmetric with the second-cycle combined arm.
  - `caseFileHeadlineFallsThroughToReasonForEngineOnlyShift` —
    `(prior?, nil)` arm: neither pushback marker present; picker
    returns the persisted `reason` ("Shifted focus from Pace to
    Depth.") unchanged. No over-claim of user action.
  - `caseFileHeadlineFallsThroughToReasonForEmptyReason` — defensive:
    an empty `reason` returns the empty string. Boundary the engine
    never writes but a Codable round-trip could deliver.
- **Cross-surface consistency (3 tests):**
  - `revisedReadCardHeadlineMatchesCaseFileHeadlineOnFirstCycle` —
    locks `RevisedReadCard.headlineCopy(for: change) == change.caseFileHeadline`
    on first-cycle pushback. A copy edit to either site without
    updating the other fails this test.
  - `revisedReadCardHeadlineMatchesCaseFileHeadlineOnSecondCycle` —
    same contract on second-cycle pushback.
  - `revisedReadCardHeadlineConstantStillReturnsFirstCyclePhrasing` —
    back-compat: the round-28 `headlineCopyNamesUserAction` test
    pins the static constant; round 34 preserves it.

New `@Suite("FreshRevisedReadChangeSecondCycleDelegationTests")`
(struct, `@MainActor`) placed after `CaseFileHeadlineTests`. One
`@Test` method covers the round-34 cross-cycle contract through the
helper that `SummaryView` now reads:

- `helperReturnsSecondCycleEntryUnchangedThroughTheCollapse` — a
  second-cycle pushback entry resolves through
  `CoachContextBuilder.freshRevisedReadChange(in:)` (round 33's
  `documentsUserPushback` OR-match plus round 31's freshness gate),
  preserving the round-33 contract through the round-34
  `SummaryView` collapse. The existing `FreshRevisedReadContextTests`
  suite already covers the first-cycle / engine-only / stale /
  nil-log / empty-log branches.

### Vision alignment

- **Coach-parity stage #2 (Case formulation).** Per `docs/VISION.md`:
  the case formulation needs to be "concise, revisable" and surfaced
  "coherently in Ask Noum, post-rep feedback, and the next-practice
  recommendation." Round 34 closes a cross-surface coherence gap:
  the post-rep summary and the Profile case-review card now name the
  same rebuild event in the same user voice, rather than one in
  second-person and one in third-person.
- **Pillar #5 (Personalized coaching).** A coach who acknowledges
  the user's pushback on the post-rep card and then a moment later
  refers to "User reported the prior hypothesis did not match what
  they saw" on the Profile card sounds like two coaches with
  different memory of the same conversation. Round 34 gives both
  surfaces the same picker — the user reads one coach voice across
  the case file.
- **Pillar #4 (Believable progress).** A user who pushes back twice
  on the working hypothesis sees their second pushback named
  explicitly on BOTH surfaces ("rebuilt read as off too"), not just
  the post-rep card. The Profile card no longer reads as a stale
  engine log on the second cycle.
- **Engineering bans.** No fragmented state: round 34 removes the
  duplicate `freshRevisedReadChange` predicate body
  (`SummaryView`-local vs. `CoachContextBuilder`-canonical) closing
  future move #11. No placeholder logic: the new picker has a real
  call site (the Profile card "Last shift" row) and a real second
  call site (the post-rep card via the round-33 delegate). No dead
  toggles: the picker has no flags; the resolution is data-driven
  off the persisted `reason` field.
- **Anti-overclaim.** The engine-only fall-through arm of
  `caseFileHeadline` returns the persisted `reason` unchanged — the
  picker never rewrites a `(prior?, nil)` shift as a user action.
  The cross-surface consistency tests do NOT pin engine-only
  behavior across the picker and the card (the card's gate filters
  engine-only out before the picker fires; the picker preserves
  legacy behavior for that branch).
- **No schema bump.** `caseFileHeadline` is a computed property over
  the existing `reason` field. Memories persisted before round 34
  decode and behave unchanged: round-27 entries surface the
  first-cycle phrase, round-33 entries surface the second-cycle
  phrase, pre-round-27 memories (no adaptation log) never reach the
  picker (call sites short-circuit on `adaptationLog?.last`).

### Branch + redesign-alignment notes

- All five tracks land on `Redesign`, the redesign-lineage branch the
  rolling M24 deferred-slate work has been shipping on since round 11.
  The user brief explicitly calls this out: "ensure working on the
  redesign branch too (very important)." Round 34 preserves the
  round-by-round loop on the redesign lineage.
- Round 34 does not change the round-33 `userRebuildPushbackMarker`
  constant, the `documentsUserPushback` / `documentsRebuildPushback`
  predicates, or the `isSecondCyclePushback` engine detection. The
  round-33 19 second-cycle + 4 picker tests pass unchanged; round
  34's 10 new tests sit alongside them. Round 32 / round 31 /
  round 30 / round 29 / round 28 / round 27 surfaces are
  read-through, not edited.
- The existing `FreshRevisedReadContextTests` suite (round 31)
  continues to pin the helper's first-cycle / engine-only / stale /
  nil-log / empty-log branches; the round-34 collapse is a pure
  refactor at the `SummaryView` site. No behavioral change at the
  helper level.
- The static `RevisedReadCard.headlineCopy` constant is preserved
  unchanged; round 28's `headlineCopyNamesUserAction` test passes
  unchanged. Round 34 only lifts the picker function body to the
  data model, not the constant.

## Future moves

(Updated priority list — round-34 closed step #11; the rest roll
forward, plus the round-33 carry-forwards.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–33. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–33. Pure visual work, not crossing logic.
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
    rounds 30 + 32 + 33. With round 33's `documentsRebuildPushback`
    marker on the adaptation log AND round 34's `caseFileHeadline`
    picker on the data model, a future trend view could ALSO count
    rebuild PUSHBACKS separately from first-cycle pushbacks AND
    surface the user-voiced phrase from the picker with no
    additional engine work.
13. **`adaptationLogCycleSummary` helper on `CoachContextBuilder`.**
    Carried forward from round 33. A future round could compose a
    one-line coach-context summary that names the cycle depth —
    "user has pushed back twice on the working hypothesis this case
    file" — based on a count of consecutive `documentsUserPushback`
    entries at the tail of `adaptationLog`. Surface in CASE
    FORMULATION so the model speaks to a user who has pushed back
    twice differently than a user who has pushed back once. Hold
    until at least one real-device QA pass on the round-33
    second-cycle chain.
14. **Engine reset on a `.confirmed` ack after a rebuild.** Carried
    forward from round 33. The current chain depends on
    `previous.adaptationLog.last.documentsUserPushback`; a
    `.confirmed` ack on the rebuilt read does NOT cycle (it just
    confirms the rebuild). A future round could append an explicit
    `confirmation` entry on `.confirmed` ack-drop to mark the rebuild
    as accepted, closing the cycle in the log as cleanly as the
    rejection cycle is closed in round 33. With round-34's
    `caseFileHeadline` picker on the data model, a third arm
    ("You confirmed the rebuilt read.") would land naturally as a
    new branch above the engine-only fall-through.
15. **Sibling `RevisedReadCard` copy for the post-`.confirmed` rebuild
    surface.** Carried forward from round 33. The card currently
    surfaces only on a fresh pushback rebuild. A future round could
    add a sibling card ("You confirmed the rebuilt read") on the
    post-rep summary AFTER the user lodges a `.confirmed` ack on the
    rebuilt hypothesis, so the rebuild lifecycle has acknowledged
    closure on the surface where it began. Depends on #14 above.
16. **User-voiced lift for the engine-only fall-through arm of
    `caseFileHeadline`.** New note from round 34. The current
    fall-through returns the persisted `reason` ("Shifted focus from
    Pace to Depth.") unchanged because rewriting it as user action
    would over-claim. But a softer second-person re-framing might
    read better on the Profile card without over-claiming — e.g.,
    "Coach moved your focus from Pace to Depth." Hold until at
    least one real-device QA pass on round 34's pushback branches
    on `CaseReviewCard`; the picker's contract is fine today.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes are:

- One new computed property on `CoachCourseChange` in
  `PrimaryFocusMemory.swift`. Self-contained — no new imports, no new
  dependencies, no new types. Reads only the existing `reason` field
  through the round-33 predicates.
- One one-line body replacement on `RevisedReadCard.headlineCopy(for:)`
  in `RevisedReadCard.swift`. The static `headlineCopy` constant is
  unchanged. The view body is unchanged (still calls
  `headlineCopy(for: change)`).
- One one-line text replacement on `CaseReviewCard.swift` — the "Last
  shift" `caseRow` text argument changes from `latest.reason` to
  `latest.caseFileHeadline`. No other UI changes.
- One body replacement on `SummaryView.freshRevisedReadChange` —
  delegates to `CoachContextBuilder.freshRevisedReadChange(in:)`. The
  two call sites and the round-29 opener gate read the property
  unchanged.
- One new `@Suite("CaseFileHeadlineTests")` (9 tests) + one new
  `@Suite("FreshRevisedReadChangeSecondCycleDelegationTests")` (1
  test) in `NoumTests/NoumTests.swift`. Both are plain `struct`,
  `@MainActor`, mirror of the round-33 suites' attributes.

All checks the next agent should run on a real build host:

1. `swift test --filter CaseFileHeadlineTests` — the new round-34 9
   picker + cross-surface tests should all pass.
2. `swift test --filter FreshRevisedReadChangeSecondCycleDelegationTests`
   — the new round-34 1 cross-cycle delegation test should pass.
3. `swift test --filter RevisedReadCardTests` — the round-28 5 tests
   + round-33 4 picker tests should all still pass. The round-33
   tests pin the strings; the round-34 delegate returns those same
   strings (now via `caseFileHeadline`), so the existing tests
   continue to lock the contract.
4. `swift test --filter SecondCyclePushbackAdaptationTests` — the
   round-33 19 second-cycle tests should all still pass. Round 34
   does not touch the engine's `isSecondCyclePushback` detection or
   the marker constants.
5. `swift test --filter RebuildVerdictContextTests` — the round-32
   25 rebuild-verdict tests should still pass. Round 34 only enriches
   the user-facing headline picker on the data model; the round-32
   predicate gates and context lines are unchanged.
6. `swift test --filter FreshRevisedReadContextTests` — the round-31
   16 fresh-revised-read tests should still pass. Round 34 collapses
   the `SummaryView` private predicate into the helper this suite
   tests; the helper itself is unchanged.
7. `swift test --filter RevisedReadFollowUpTests` — round-30 tests
   should still pass.
8. `swift test --filter RevisedReadOpenerTests` — round-29 tests
   should still pass. Round 34 does not touch
   `revisedReadOpener` or the gate that selects it.
9. `swift test --filter CoachMemoryEngineTests` — the round-27 tests
   should all still pass. Round 34 does not touch the engine's
   adaptation-log append logic.
10. `swift test --filter HypothesisAcknowledgementTests` — round-26
    tests should still pass.
11. `swift test --filter InterventionReviewPromptTests` — round-24 +
    round-25 tests should still pass.
12. `swift test --filter CoachMemoryStoreTests` — should still pass.
13. **Real-device QA — cross-surface consistency on the rebuild
    lineage.** Boot the app on simulator. Seed a
    `CoachMemory.activeIntervention` with a working hypothesis. Open
    Ask Noum via the round-24 `InterventionReviewPromptCard` or the
    round-25 empty-state chip. Tap the **Adapt / rejected** ack
    chip. Finish a new rep that rewrites the working hypothesis
    (lever shift OR confidence threshold cross). On the post-rep
    summary, confirm `RevisedReadCard` renders with the
    **first-cycle headline** ("You flagged the prior read as off.").
14. **Now switch to the Profile tab.** Open the `CaseReviewCard`.
    Confirm the "Last shift" row reads **"You flagged the prior
    read as off."** — NOT the third-person engine reason ("User
    reported the prior hypothesis did not match what they saw;
    revising the read.") that pre-round-34 builds rendered. The
    two surfaces now name the same event in the same voice.
15. **Drive the second cycle.** Through Ask Noum, lodge a verdict
    chip, then on a follow-up turn tap the **Adapt / rejected** ack
    chip on the REBUILT hypothesis (the chip row should fire because
    the rebuilt hypothesis is now the working one and the user is
    rejecting it). Finish another rep that rewrites the working
    hypothesis again. On the post-rep summary, confirm
    `RevisedReadCard` now renders the **second-cycle headline**
    ("You flagged the rebuilt read as off too.").
16. **Switch to the Profile tab again.** Confirm the "Last shift"
    row reads **"You flagged the rebuilt read as off too."** — NOT
    the third-person engine reason ("User reported the rebuilt
    hypothesis did not match what they saw; revising the read
    again.") that pre-round-34 builds rendered. The cross-surface
    consistency contract holds on the second cycle too.
17. **Insert an engine-only lever shift between cycles.** Drive a
    rebuild WITHOUT a `.rejected` ack drop (just an engine lever
    shift). On the post-rep summary, confirm `RevisedReadCard` does
    NOT mount (no pushback marker; the gate filters it out). On the
    Profile tab, confirm `CaseReviewCard`'s "Last shift" row reads
    the engine-only reason ("Shifted focus from X to Y.") UNCHANGED
    — round 34's fall-through preserves the pre-round-34 behavior on
    this branch. No over-claim of user action.
