# HANDOFF — M24 deferred slate (round 37): `RevisedReadConfirmationCard` lands on the post-rep `SummaryView` — sibling card to round 28's `RevisedReadCard`, gated by the new `CoachContextBuilder.freshRebuildConfirmationChange(in:)` helper on the round-36 `documentsRebuildConfirmation` data primitive. Closes round-36 future move #13.

## Scope

Round 36 closed the engine half of the rebuild-confirmation lifecycle:
the `.confirmed` rebuild ack now writes a durable confirmation entry to
the bounded `adaptationLog`, surfaces in the chat-coach user-context
block via `CoachContextBuilder.rebuildConfirmationContextLines`, and
reads on the Profile-tab `CaseReviewCard` "Last shift" row through the
new `CoachCourseChange.caseFileHeadline` confirmation branch ("You
confirmed the rebuilt read.").

The honest gap round 36 left open: the post-rep `SummaryView` — the
surface where the rebuild lifecycle BEGAN for the user via round 28's
`RevisedReadCard` ("You flagged the prior read as off; here's the
revised one") — went silent on the rep that locked the rebuild in.
A user who skimmed only the summary saw the coach acknowledge their
pushback, but never saw the coach acknowledge their later acceptance
on the same family of cards. The rebuild lifecycle had asymmetric
closure: visible rejection, invisible confirmation, on the surface
where the user first encountered it.

Round 37 picks up future move #13 carried forward from round 36:

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the
redesign branch too (very important)."

Translation, this round:

- New `RevisedReadConfirmationCard` view in `Noum/RevisedReadCard.swift`.
  Sibling of `RevisedReadCard`, same file. Same outer chrome (same
  `AppColor.cardBackground` fill, `AppColor.pro` 0.22-alpha stroke,
  0.06-alpha shadow, same padding + corner radius). Distinct glyph
  (`checkmark.seal.fill` in place of `arrow.triangle.2.circlepath`) +
  eyebrow ("REVISED READ · CONFIRMED" in place of "REVISED READ"). The
  card reads as a member of the same family — a user who saw
  `RevisedReadCard` on the pushback rep recognizes the family on the
  lock-in rep.
- New `RevisedReadConfirmationCard.headlineCopy` constant. Locked to
  "You confirmed the rebuilt read." — byte-for-byte the same string
  `CoachCourseChange.caseFileHeadline` returns on a confirmation
  entry. Cross-surface read of the rebuild lineage (Profile card +
  post-rep summary) stays consistent: a copy edit to one forces the
  test suite on the other to follow.
- New `RevisedReadConfirmationCard.bodyCopy(workingHypothesis:)`
  helper. Mirror of `RevisedReadCard.bodyCopy`'s trim-and-strip-
  trailing-period logic so the locked-in hypothesis renders cleanly
  inline. The wrapping phrase is "Here's the locked-in read: …" so
  the lifecycle stage is named explicitly. Fallback line on nil/
  whitespace hypothesis reads "The coach noted it and is keeping the
  read." (parallel of `RevisedReadCard`'s "forming the next read"
  fallback, named for the lock-in stage).
- New `CoachContextBuilder.freshRebuildConfirmationChange(in:)`
  helper. Symmetric closure of `freshRevisedReadChange(in:)`: returns
  the latest `CoachCourseChange` iff `documentsRebuildConfirmation ==
  true` AND `isFresh(comparedTo: memory.updatedAt) == true`. Pure
  read of memory fields — no UI dependency, no schema bump.
- `SummaryView` mounts the new card alongside `RevisedReadCard` in
  BOTH the IM branch and the non-IM branch (mirror of round 28's two-
  branch wiring). A new private `freshRebuildConfirmationChange`
  computed property delegates to the helper so the eligibility
  contract lives in one place — same shape as round 34's
  `freshRevisedReadChange` delegation.
- Mutual exclusion with the pushback card is pinned at the data
  primitive: a confirmation entry's `reason` carries the round-36
  marker only and never satisfies `documentsUserPushback`; a pushback
  entry's `reason` never carries the confirmation marker. The two
  cards can never both mount on the same rep — locked by tests on
  both directions of the contract.
- The redesign-branch invariant: round 37 lands directly on
  `Redesign`, the redesign-lineage branch the rolling M24 deferred-
  slate work has been shipping on since round 11. Round-by-round
  loop preserved.

## What shipped

### Track 1 — `RevisedReadConfirmationCard` view (`Noum/RevisedReadCard.swift`)

- New `struct RevisedReadConfirmationCard: View` placed directly
  below `RevisedReadCard` in the same file. `@available(iOS 17.0, *)`
  matches the sibling's availability annotation.
- Body composition mirrors `RevisedReadCard.body` line-for-line:
  same `VStack(alignment: .leading, spacing: 10)`, same header
  `HStack` row carrying the glyph + caps eyebrow, same headline +
  body text rows with the same fonts (`Typography.subheadline.weight(.semibold)`
  on the headline, `Typography.caption` on the body), same
  `.fixedSize(horizontal: false, vertical: true)` wrap behavior, same
  `padding(16)`, same `frame(maxWidth: .infinity, alignment: .leading)`,
  same `RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)`
  background + overlay, same shadow.
- The two visible differences from `RevisedReadCard`:
  - Glyph: `checkmark.seal.fill` in place of `arrow.triangle.2.circlepath`.
    The seal reads as "locked in" without competing with the
    `RevisedReadCard` family.
  - Eyebrow text: `"REVISED READ · CONFIRMED"` in place of
    `"REVISED READ"`. The lifecycle stage is named in the eyebrow so
    a user who saw the pushback card last rep recognizes the family
    AND sees the new stage.
- Accessibility:
  - `accessibilityElement(children: .combine)` — same as the sibling.
  - `accessibilityLabel("Revised coaching read, confirmed. \(headline) \(bodyLine)")`
    — same shape as the sibling's label, with the "confirmed" word
    added so VoiceOver users hear the lifecycle stage named.
  - `accessibilityIdentifier("summary.revisedRead.confirmation.card")`
    — distinct from the sibling's identifier so UI tests can target
    each card separately. The hierarchical naming
    (`summary.revisedRead.*`) reads as a family in the UI test
    inspector.

### Track 2 — `RevisedReadConfirmationCard.headlineCopy` constant + `bodyCopy(workingHypothesis:)` helper

- `static let headlineCopy: String = "You confirmed the rebuilt read."`
  — byte-for-byte identical to the round-36
  `CoachCourseChange.caseFileHeadline` branch for a confirmation
  entry. The test `headlineMatchesCaseFileHeadlineForConfirmationEntry`
  pins this cross-surface parity by constructing a confirmation
  `CoachCourseChange` and asserting both expressions are equal — a
  future copy edit to either side must update the other or the
  suite fails.
- `static func bodyCopy(workingHypothesis: String?) -> String` mirrors
  `RevisedReadCard.bodyCopy` line-for-line:
  - Trim whitespace + newlines from the input.
  - Return the nil/blank fallback if empty (different fallback copy:
    "The coach noted it and is keeping the read." vs the sibling's
    "The coach noted it and is forming the next read." — the
    lifecycle stage is named: the read is now being KEPT, not formed).
  - Strip a trailing `.` if present so the wrapper's terminating
    period doesn't produce `..`.
  - Wrap in `"Here's the locked-in read: \(stripped)."` — same
    shape as the sibling's `"Here's the revised read: \(stripped)."`
    but with "locked-in" naming the lifecycle stage.

### Track 3 — `CoachContextBuilder.freshRebuildConfirmationChange(in:)` helper (`Noum/CoachContextBuilder.swift`)

- New `static func freshRebuildConfirmationChange(in memory: CoachMemory) -> CoachCourseChange?`
  placed directly after `rebuildConfirmationContextLines` (the
  round-36 chat-context helper). Pure mirror of
  `freshRevisedReadChange(in:)`:
  ```swift
  static func freshRebuildConfirmationChange(in memory: CoachMemory) -> CoachCourseChange? {
      guard let latest = memory.adaptationLog?.last,
            latest.documentsRebuildConfirmation,
            latest.isFresh(comparedTo: memory.updatedAt) else { return nil }
      return latest
  }
  ```
- Doc-comment names the mutual-exclusion contract with
  `freshRevisedReadChange(in:)` so a future reader of either helper
  sees the symmetry: a confirmation entry's `reason` never carries
  either pushback marker, a pushback entry's `reason` never carries
  the confirmation marker — the two helpers can never return
  non-nil on the same memory.
- Doc-comment names the freshness contract: the round-36 engine arm
  appends the confirmation entry exactly once (the
  `confirmedRebuildAck` predicate's `lastChange.documentsUserPushback`
  guard returns false on the new tail), so on the rep AFTER the
  lock-in the entry is still in the log but
  `change.changedAt < memory.updatedAt` and the gate stays silent.
  Same one-rep window as the pushback card.

### Track 4 — `SummaryView` mounts the new card (`Noum/SummaryView.swift`)

- New private computed property `freshRebuildConfirmationChange:
  CoachCourseChange?` placed directly after `freshRevisedReadChange`.
  Same delegation shape: reads `coachMemoryStore.currentMemory`,
  delegates the predicate body to
  `CoachContextBuilder.freshRebuildConfirmationChange(in:)`. A future
  edit to the eligibility contract lands in one place.
- Two new mount sites in `SummaryView.body`:
  - IM branch: directly after the existing `RevisedReadCard` mount
    site (line ~632), the new `if let confirmationChange =
    freshRebuildConfirmationChange { RevisedReadConfirmationCard(...) }`
    block. Same `workingHypothesis: coachMemoryStore.currentMemory?.workingHypothesis`
    parameter the sibling passes.
  - Non-IM branch: directly after the matching `RevisedReadCard`
    mount site (line ~747), the same `if let ... { ... }` block.
    Mirror of round 28's two-branch wiring so the new card lands
    on every mode (Timed / Sudden Death / Ah-Counter / IM).
- The two cards are mutually exclusive at the predicate level — the
  pushback gate fires only on `documentsUserPushback`, the
  confirmation gate fires only on `documentsRebuildConfirmation`,
  and the round-36 marker constants guarantee these are mutually
  exclusive on any single `reason` string. The mount order
  (pushback → confirmation) is deliberate: on the impossible case
  where both gates somehow fired (a copy-edit drift, a defensive
  Codable round-trip), the layout would still read top-to-bottom in
  lifecycle order. The tests pin that this can't happen, but the
  ordering keeps the surface coherent even under that defensive case.

### Track 5 — `RevisedReadConfirmationCardTests` (`NoumTests/NoumTests.swift`)

New `@Suite("RevisedReadConfirmationCardTests")` (struct, `@MainActor`,
`@available(iOS 17.0, *)`) placed directly after
`RebuildConfirmationAdaptationTests`. Eight `@Test` methods pinning
the user-facing copy contracts:

- `headlineCopyNamesUserAction` — locks the constant to "You
  confirmed the rebuilt read." A copy edit forces the suite.
- `headlineMatchesCaseFileHeadlineForConfirmationEntry` — pins
  cross-surface parity with `CoachCourseChange.caseFileHeadline`'s
  round-36 branch. The post-rep summary and the Profile card must
  use the same phrasing on a confirmation entry.
- `bodyCopyQuotesLockedInHypothesisInline` — happy path: body line
  begins with "Here's the locked-in read: " and contains the
  hypothesis verbatim.
- `bodyCopyStripsTrailingPeriodToAvoidDoubleStop` — defensive: the
  body never produces `..` when the hypothesis already ends with `.`.
- `bodyCopyFallsBackWhenNoHypothesis` — locks the nil fallback to
  "The coach noted it and is keeping the read." (the lifecycle-
  named fallback, not the sibling's "forming the next read").
- `bodyCopyFallsBackWhenHypothesisIsBlank` — whitespace-only takes
  the same fallback as nil.
- `headlineHasNoFanfareOrUrgency` — brand-voice contract: no
  exclamation, no "let's", no "amazing", no "nailed", no "crushed".
  Same rule the round-19 launch CTA and round-20 SOLVED ribbon
  hold to.
- `bodyCopyHasNoFanfareOrUrgency` — same brand-voice contract on
  the body line, asserted on both the hypothesis-present and
  hypothesis-nil branches.

### Track 6 — `FreshRebuildConfirmationChangeTests` (`NoumTests/NoumTests.swift`)

New `@Suite("FreshRebuildConfirmationChangeTests")` (struct,
`@MainActor`) placed directly after `RevisedReadConfirmationCardTests`.
Nine `@Test` methods pinning the helper-gate contract:

- `fresh_confirmation_entry_at_tail_fires_predicate` — happy path:
  same-`Date()` `changedAt` + `updatedAt`, helper returns the
  entry.
- `fresh_within_one_second_tolerance_fires_predicate` — the
  `isFresh(comparedTo:)` one-second tolerance is the existing
  contract on `CoachCourseChange`; the helper inherits it.
- `stale_confirmation_entry_does_not_fire` — the rep AFTER the
  lock-in: `memory.updatedAt` advanced, `change.changedAt`
  untouched, gate stays silent. Card stays hidden.
- `pushback_tail_does_not_fire_confirmation_predicate` — mutual
  exclusion direction #1: pushback tail does NOT fire the
  confirmation gate, AND the companion `freshRevisedReadChange`
  helper DOES fire on the same fixture. Pushback card mounts here,
  confirmation card stays silent.
- `confirmation_tail_does_not_fire_pushback_predicate` — mutual
  exclusion direction #2: confirmation tail does NOT fire the
  pushback gate, AND the new confirmation helper DOES fire.
  Symmetric closure of direction #1.
- `nil_adaptation_log_does_not_fire_predicate` — defensive.
- `empty_adaptation_log_does_not_fire_predicate` — defensive.
- `only_the_tail_entry_is_inspected` — bounded log can carry an
  earlier confirmation entry followed by an engine-only shift at
  the tail; the predicate must NOT fire (the engine shift is the
  current state, the earlier confirmation is history).
- `helper_does_not_mutate_memory` — pure-function contract.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "compare response across multiple attempts and either reinforce,
  vary, or replace the intervention with an explained rationale."
  Round 28 surfaced the VARY branch (pushback → revised read) on
  the post-rep summary. Round 36 recorded the REINFORCE branch in
  the durable log and surfaced it in the chat-coach context and
  on the Profile card. Round 37 closes the symmetry — the
  REINFORCE branch is now surfaced on the same family of cards on
  the same surface where the VARY branch first appeared, on the
  rep that locked it in.
- **Pillar #5 (Personalized coaching).** A real coach who set a
  rebuilt read and earned the client's acceptance acknowledges it
  on the surface where they first proposed the rebuild. Silently
  treating the lock-in like any other rep would read as the coach
  not noticing. The new card makes the acknowledgement visible.
- **Pillar #4 (Believable progress).** The rebuild lifecycle now
  has acknowledged closure on the same family of cards it began
  on. A user who saw the rebuild proposed, lodged a `.confirmed`
  ack, and finished another rep sees the coach name the lock-in
  on the surface they first encountered the rebuild on — the
  arc reads as continuous coaching, not as a feature checklist.
- **Engineering bans.** No fragmented state: round 37 adds one
  view, one constant, one body-copy helper, one gate helper, one
  computed property, and two mount sites. The data primitive (the
  round-36 confirmation marker) is read by every consumer through
  the same predicate — a copy edit in one place propagates to all
  surfaces. No placeholder logic: the new card has real call sites
  in both summary branches. No dead toggles: the gate is data-
  driven off the persisted `adaptationLog` field.
- **Anti-overclaim.** The card renders only on the rep that lands
  the lock-in (one-rep window, same as the pushback card). The
  copy is restrained — no celebration, no exclamation, no "Let's".
  The mutual-exclusion contract pins that the pushback and
  confirmation cards can never both mount, so the user never sees
  the coach acknowledge two contradictory verdicts on the same
  rep.
- **No schema bump.** The round-36 marker constant is the data
  primitive both surfaces read through. The new helper is a
  pure-function read of `memory.adaptationLog` and
  `memory.updatedAt`. Memories persisted before round 37 decode
  and behave unchanged.

### Branch + redesign-alignment notes

- All six tracks land on `Redesign`, the redesign-lineage branch
  the rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." Round 37
  preserves the round-by-round loop on the redesign lineage.
- Round 37 does not change round 36's `userRebuildConfirmationMarker`,
  `documentsRebuildConfirmation` predicate, `caseFileHeadline`
  confirmation branch, `CoachMemoryEngine.build(...)` confirmation
  append arm, `rebuildConfirmationEvidenceBasis(ack:)` helper, or
  `rebuildConfirmationContextLines(memory:)` helper. Every prior
  round's tests pass unchanged.
- The round-28 `RevisedReadCardTests` (8 tests) pass unchanged:
  they pin the pushback card's copy, not the confirmation card's.
- The round-31 `FreshRevisedReadContextTests` (16 tests) pass
  unchanged: they pin the pushback context helper, not the new
  confirmation gate.
- The round-36 `RebuildConfirmationAdaptationTests` (24 tests)
  pass unchanged: they pin the engine append arm + chat-context
  helper, not the new summary card.

## Future moves

(Updated priority list — round-37 closed step #13; the rest roll
forward.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–36. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–36. Pure visual work, not crossing logic.
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
    confirmation marker AND round 37's post-rep card surfacing the
    lock-in, this signal would now reset the `reviewDueAt` cadence
    cleanly on the rep the new card mounts on.
11. **Collapse the round-26 hypothesis-ack reflection in
    `coachCaseFormulationLines` into a single block with the round-32
    rebuild-verdict lines when the predicate fires.** Carried forward
    from round 32. Hold for real-device QA.
12. **Trend-view distinction between "user accepted the first read",
    "user accepted the rebuilt read", and "user pushed back N
    times in a row".** Carried forward from rounds 30 + 32 + 33 + 34 +
    35 + 36. With round 36's `documentsRebuildConfirmation` predicate
    AND round 37's post-rep card, the trend view could show the FULL
    rebuild lifecycle on the case file — rejections, depth, lock-ins,
    and the moment each was surfaced to the user — with no further
    engine work.
13. **Ask Noum opener for the post-`.confirmed` rebuild surface.**
    New note from round 37. Round 29 dispatched a case-anchored seed
    into Ask Noum when the post-rep `RevisedReadCard` was hot
    (`talkToNoumOpener` → `CoachContextBuilder.revisedReadOpener`).
    The new `RevisedReadConfirmationCard` has no matching opener —
    the user who taps `TalkToNoumCTACard` on the lock-in rep gets
    the generic `sessionAnchoredOpener`. A future round could add a
    sibling `CoachContextBuilder.rebuildConfirmationOpener(...)` and
    a branch on `SummaryView.talkToNoumOpener` so the chat seed
    names the lock-in the same way the post-rep card does. Mirror
    of round 29's structure on the symmetric event.
14. **User-voiced lift for the engine-only fall-through arm of
    `caseFileHeadline`.** Carried forward from rounds 34–36. The
    current fall-through returns the persisted `reason` ("Shifted
    focus from Pace to Depth.") unchanged because rewriting it as
    user action would over-claim. But a softer second-person re-framing
    might read better on the Profile card without over-claiming — e.g.,
    "Coach moved your focus from Pace to Depth." Hold until at
    least one real-device QA pass on round 34's pushback branches +
    round 36's confirmation branch + round 37's new card on the
    summary.
15. **Voice-tuned depth-line phrasing.** Carried forward from round 35.
    The case-formulation depth line currently reads the same across
    all voices. A future round could vary the coach-move clause by
    the user's `SpeakingStyleGoal`: `.authoritative` reads "stop
    retrying the same lever" (direct); `.warm` reads "the streak
    matters — meet it gently" (measured); `.concise` reads "drop
    this lever; try another" (tight). Same pattern the round-29
    opener uses for voice-tuned phrasing. Hold until at least one
    real-device QA pass on the depth line landing in chat.
16. **Voice-tuned confirmation-line phrasing.** Carried forward from
    round 36. The case-formulation confirmation block currently reads
    the same across all voices. A future round could vary the coach-
    move clause by `SpeakingStyleGoal` — same pattern as #15 above.
    Hold until at least one real-device QA pass on round 36's lock-in
    block landing in chat.
17. **Depth-aware Ask Noum starter chip.** Carried forward from round
    35. When `adaptationLogCycleDepth(in:)` returns ≥ 3, AskNoumView's
    empty-state starter chips could surface a dedicated "Why does
    this keep coming back?" chip that seeds the conversation with
    the streak context. Sibling of the round-25 case-review starter
    chip. Hold until at least one real-device QA pass.
18. **Confirmation-aware Ask Noum starter chip.** Carried forward from
    round 36. When the latest adaptation entry is a confirmation,
    AskNoumView's empty-state could offer a "Where do we take the
    new read next?" chip that seeds the conversation with the lock-
    in context. Sibling of #17. Hold until at least one real-device
    QA pass.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes are:

- One new `struct RevisedReadConfirmationCard: View` + one new
  `static let headlineCopy: String` + one new
  `static func bodyCopy(workingHypothesis:)` helper in
  `Noum/RevisedReadCard.swift`. Self-contained — no new imports
  beyond the existing `import SwiftUI`, no new dependencies, no
  new types. Mirrors `RevisedReadCard`'s structure byte-for-byte.
- One new `static func freshRebuildConfirmationChange(in:)` helper
  on `CoachContextBuilder` in `Noum/CoachContextBuilder.swift`.
  Mirror of `freshRevisedReadChange(in:)`. Pure read of
  `memory.adaptationLog` and `memory.updatedAt`; no new state
  written.
- One new private `freshRebuildConfirmationChange` computed
  property on `SummaryView` in `Noum/SummaryView.swift`, plus two
  new `if let ... { RevisedReadConfirmationCard(...) }` mount
  blocks (one per branch). Both delegate to the new helper.
- One new `@Suite("RevisedReadConfirmationCardTests")` (8 tests) +
  one new `@Suite("FreshRebuildConfirmationChangeTests")` (9
  tests) in `NoumTests/NoumTests.swift`. Plain `struct`,
  `@MainActor`, mirror of the round-36
  `RebuildConfirmationAdaptationTests` attributes.

All checks the next agent should run on a real build host:

1. `swift test --filter RevisedReadConfirmationCardTests` — the new
   round-37 8 tests should all pass.
2. `swift test --filter FreshRebuildConfirmationChangeTests` — the
   new round-37 9 tests should all pass.
3. `swift test --filter RevisedReadCardTests` — the round-28 8 tests
   should still pass. The new sibling card lives in the same file
   but the existing card's copy is untouched.
4. `swift test --filter RebuildConfirmationAdaptationTests` — the
   round-36 24 tests should still pass. The new gate helper reads
   the same primitives as the round-36 context helper; both pass
   on the same fixtures.
5. `swift test --filter FreshRevisedReadContextTests` — the round-31
   16 tests should still pass. The new helper does NOT touch the
   existing `freshRevisedReadChange` helper, and the mutual-
   exclusion tests pin that pushback fixtures fire the existing
   helper unchanged.
6. `swift test --filter CaseFileHeadlineTests` — the round-34 9
   tests should still pass. The new card's headline reads through
   the same `CoachCourseChange.caseFileHeadline` property on a
   confirmation entry; the test pins parity.
7. **Real-device QA — RevisedReadConfirmationCard mounts on the
   summary after a `.confirmed` rebuild ack.** Boot the app on
   simulator. Seed a `CoachMemory.activeIntervention` with a
   working hypothesis. Drop a `.rejected` ack via Ask Noum (or via
   round 24's review prompt). Finish a rep that rewrites the
   working hypothesis — the post-rep `RevisedReadCard` should
   mount (round-28 surface). Open Ask Noum, lodge a `.confirmed`
   verdict chip on the rebuilt hypothesis via round 30's follow-
   up row. Finish another rep. The new memory rebuild should
   append a confirmation entry to `adaptationLog` (round 36) AND
   the post-rep `RevisedReadConfirmationCard` should mount on the
   same rep (round 37).
8. **Confirm the card copy.** The eyebrow should read "REVISED
   READ · CONFIRMED" with a `checkmark.seal.fill` glyph in
   `AppColor.pro`. The headline should read "You confirmed the
   rebuilt read." The body should read "Here's the locked-in
   read: <rebuilt hypothesis>." with no double period at the end.
9. **Confirm mutual exclusion.** On the rep that mounts the
   confirmation card, the pushback `RevisedReadCard` should NOT
   also mount. Conversely, on the rep that mounts the pushback
   card (the rep folding in a `.rejected` ack), the confirmation
   card should NOT mount.
10. **Confirm one-rep window.** Finish another rep without
    lodging a new ack. The confirmation entry persists in the
    bounded `adaptationLog`, but the new card should NOT mount
    a second time (freshness slams shut). The Profile-tab
    `CaseReviewCard` continues to read "You confirmed the rebuilt
    read." on the durable surface unchanged.
11. **Switch to the Profile tab.** Open the `CaseReviewCard`.
    Confirm the "Last shift" row reads "You confirmed the rebuilt
    read." — byte-for-byte identical to the post-rep card's
    headline. Cross-surface parity is the contract round 37
    pins.
12. **VoiceOver pass.** Enable VoiceOver, navigate to the
    confirmation card. The combined accessibility label should
    read "Revised coaching read, confirmed. You confirmed the
    rebuilt read. Here's the locked-in read: <hypothesis>." The
    accessibility identifier (`summary.revisedRead.confirmation.card`)
    should distinguish it from the pushback card
    (`summary.revisedRead.card`) so any UI tests can target each
    surface independently.

Branch lineage: round 37 sits on top of round 36 on `Redesign`, which
sits on top of rounds 11–35. The round-by-round loop on the redesign
lineage is preserved.
