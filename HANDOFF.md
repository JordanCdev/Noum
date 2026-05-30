# HANDOFF — M24 deferred slate (round 26): hypothesis acknowledgement chip row on `AskNoumView` — records the user's one-tap verdict on the working hypothesis after the coach replies to a case-review opener

## Scope

Round 25 closed both surfaces of the case-review cadence prompt:
`SummaryView`'s `InterventionReviewPromptCard` (round 24) and
`AskNoumView`'s empty-state `caseReviewStarterChip` (round 25).
Whichever surface the user lands on, the same
`CoachContextBuilder.interventionReviewOpener` text is dispatched
into the Ask Noum thread, and the coach replies in voice with the
case scaffolding in scope.

The honest gap that left open: the coach asked "keep going, adapt,
or replace?" and the model received a reply — but the durable case
file never recorded the user's verdict on the working hypothesis.
A human coach jots down "user confirmed read" or "user pushed
back" at the end of a session; Noum did not. The next session's
coach reply could not honestly tell whether the user agreed with
the hypothesis or just kept typing. Coach-parity stage #4
(Adaptation) explicitly calls for that signal: per
`docs/VISION.md`, the case formulation must carry an "explicit,
revisable case formulation with hypothesis, intervention, success
criterion, review cadence, and reason for changing course." Round
26 ships the reason-for-changing-course primitive.

Round 26 picks up step #1 from the round-25 "Future moves" list:

> 1. **Record user confirmation / rejection of the working
>    hypothesis.** Carry forward from the 2026-05-29 HANDOFF
>    (step #3). The post-review reply from the coach should be
>    followed by a single-tap acknowledgement that updates
>    `CoachMemory.workingHypothesis` confidence. Requires a
>    PrimaryFocusMemory addition + a small Ask Noum response chip
>    surface — bigger lift than round 24/25, but the natural
>    follow-on now that BOTH entry surfaces honour the review
>    cadence.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- A small `CoachHypothesisConfidence` enum carries three explicit
  branches: `.confirmed`, `.uncertain`, `.rejected`. The user
  picks one with a tap; the verdict lands in
  `CoachMemory.hypothesisAcknowledgement` (a new optional
  Codable field — backward-compat decode via `decodeIfPresent`).
  The next coach reply receives a `CASE FORMULATION` line
  carrying the verdict + a per-branch next-move instruction so
  the model knows whether to reinforce, probe, or adapt.
- The chip row lives in `AskNoumView`, rendered between the
  coach reply and the deterministic / AI follow-up chips, on a
  pure-function predicate (`CoachContextBuilder.shouldShow
  HypothesisAcknowledgement(messages:)`) — true when the most-
  recent message is a non-pending coach reply AND the user turn
  that triggered it begins with the `interventionReviewOpener`
  lead. Voice-shaped chip labels (six voice branches + nil)
  match the user's coaching voice without changing the
  underlying enum value.
- The ack carries a `hypothesisSnapshot` so a later memory
  rebuild that rewrites the working hypothesis can detect the
  drift and re-prompt the user (`CoachHypothesisAcknowledgement
  .appliesTo(currentHypothesis:)`). The context builder reads
  the same predicate so the model never sees a stale verdict
  carried into a different read.
- The redesign-branch invariant: this is a `Redesign`-branch
  push per the user brief. The work lands directly on
  `Redesign`, preserving the round-by-round loop on the
  redesign lineage that has been the home of rounds 11–25.

## What shipped

### Track 1 — `CoachHypothesisConfidence` + `CoachHypothesisAcknowledgement` + persistence (`PrimaryFocusMemory.swift`)

- `CoachHypothesisConfidence: String, Codable, Equatable` enum
  with three cases (`.confirmed`, `.uncertain`, `.rejected`).
  Two computed copy helpers:
  - `contextLabel` — coach-context phrase the AI sees in the
    user-context block (e.g. `"user confirmed the working
    hypothesis matches what they see"`).
  - `nextMoveInstruction` — concrete instruction for the next
    coach reply (e.g. `"Reinforce the working hypothesis and
    tie the next prescription back to it."`).
- `CoachHypothesisAcknowledgement: Codable, Equatable` struct
  carrying `confidence`, `hypothesisSnapshot: String`, and
  `acknowledgedAt: Date`. The snapshot is the working
  hypothesis text at acknowledgement time so a memory rebuild
  that rewrites the hypothesis can detect drift via
  `appliesTo(currentHypothesis:)`.
- `CoachMemory.hypothesisAcknowledgement: CoachHypothesisAcknowledgement?`
  new optional field. CodingKey added; init memberwise param
  added (defaulted nil for source compat); custom decoder uses
  `decodeIfPresent` so memories persisted before round 26
  decode without breaking.
- `CoachMemoryEngine.build(...)` carries the previous ack
  forward iff its snapshot matches the freshly-built
  `workingHypothesis` — same "same prescription preserves the
  case spine" pattern the round-23 `successCriterion` / round-
  23 `reviewDueAt` carries already use. A hypothesis rewrite
  drops the ack so the user is re-prompted next time the chip
  row would render.
- `CoachMemoryStore.noteHypothesisAcknowledgement(_:at:)`
  mutation — captures the verdict + snapshot, persists, and
  publishes. No-op when there is no current memory or no
  current `workingHypothesis` (defensive — the chip row never
  renders without one, but the store still guards).

### Track 2 — Pure helpers + context line (`CoachContextBuilder.swift`)

- `CoachContextBuilder.interventionReviewOpenerLead: String`
  static constant. Pinned at `"Time to review the active
  case:"` — the lead prefix on every
  `interventionReviewOpener` so the predicate that decides
  chip-row eligibility stays in lockstep with the opener
  generator across future copy edits.
- `CoachContextBuilder.HypothesisAcknowledgementChip: Equatable`
  nested struct — `confidence: CoachHypothesisConfidence`,
  `label: String` (UI display), `dispatchText: String`
  (voice-shaped user turn dispatched on tap).
- `CoachContextBuilder.shouldShowHypothesisAcknowledgement(messages:)`
  predicate — pure function of `[CoachMessage]`. True when:
  1. Last message is a non-pending coach reply (non-empty text).
  2. The user turn that triggered it has
     `hasPrefix(interventionReviewOpenerLead)`.
  No `AskNoumStore` mock required.
- `CoachContextBuilder.hypothesisAcknowledgementChips(for:)`
  voice-shaped catalog returning 3 chips per voice (7 voices
  including nil). Pinned voice register: authoritative reads
  as verdict ("Yes — that's the read"), warm reads as
  agreement ("That fits how I see it"), concise reads as
  single-token ("Matches" / "Unsure" / "Adapt"), etc.
- New context line in `coachCaseFormulationLines(memory:)` —
  emitted under the `CASE FORMULATION (current hypothesis;
  revise with evidence)` section when memory carries a
  `hypothesisAcknowledgement` AND
  `ack.appliesTo(currentHypothesis: memory.workingHypothesis)`
  returns true. The line carries the `contextLabel` (what the
  user said) plus the `nextMoveInstruction` (what the coach
  should do next).

### Track 3 — `hypothesisAckRow` in `AskNoumView` (`AskNoumView.swift`)

- One new `@ViewBuilder` `hypothesisAckRow` rendered between
  the last message row and the existing follow-up chip row in
  the scroll view (`id("hypothesisAck")`). Composite
  eligibility (`shouldShowHypothesisAck` computed property):
  1. `CoachContextBuilder.shouldShowHypothesisAcknowledgement(messages:)`
     — the chat-shape check.
  2. `coachMemoryStore.currentMemory?.workingHypothesis` is
     non-empty — nothing to acknowledge otherwise.
  3. No applied ack already — a fresh ack on the same
     hypothesis would be redundant; the snapshot guard
     re-enables the row on hypothesis drift.
- Three chips rendered in `FlowLayout` (same wrap pattern the
  existing follow-up chip row uses). Brand-purple tinted
  background + heavier stroke — distinct visual register from
  the lighter follow-up chips so the user reads it as a
  verdict surface, not a "keep talking" suggestion. SF Symbol
  glyph per confidence: `checkmark.circle` / `questionmark.circle`
  / `arrow.triangle.2.circlepath`.
- On tap: `recordHypothesisAck(chip)` calls
  `coachMemoryStore.noteHypothesisAcknowledgement(chip.confidence)`
  to land the verdict in case-file storage immediately, then
  dispatches `chip.dispatchText` as a user turn via the
  existing `send(_:)` path. The chat surface reads
  continuously (chip tap = real reply) and the next coach
  reply carries the verdict in its context block.

### Track 4 — `HypothesisAcknowledgementTests` (`NoumTests/NoumTests.swift`)

New `@Suite("HypothesisAcknowledgementTests")` struct covering:

- **Predicate (5 tests):** happy path; coach reply pending;
  last message is user turn; user turn is organic question
  (not the opener lead); empty messages array.
- **Chip catalog (4 tests):** chip count == 3 per voice; chip
  dispatch text + labels never empty; banned-phrase scan (no
  "!", no "Let's", no urgency); authoritative voice uses
  verdict register; concise voice uses one-word labels.
- **Snapshot guard (4 tests):** exact match; whitespace-
  trimmed match; hypothesis drift; nil/empty current
  hypothesis.
- **Store mutation + persistence (3 tests):** persists +
  reloads via UserDefaults round-trip; no-op without a
  current `workingHypothesis`; overwrites prior verdict
  rather than appending a history.
- **User-context surfacing (2 tests):** surfaces the line
  when the ack applies to the current hypothesis; drops the
  line when the snapshot has drifted.
- **Backward-compat decode (1 test):** legacy JSON without
  the new field decodes cleanly with `hypothesisAcknowledgement
  == nil`.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "compare response across multiple attempts and either
  reinforce, vary, or replace the intervention with an
  explained rationale." The case file now records the user's
  explicit verdict on the read, not just the coach's. A
  rejected ack is the "reason for changing course" the case
  formulation needs.
- **Pillar #5 (Personalized coaching).** A real coach asks
  "does that sound right?" after sharing a read; the round-26
  chip row delivers a structured back-channel for exactly
  that question, with a verdict palette that covers the full
  confirm / uncertain / reject space rather than collapsing
  the user's response to silence.
- **Pillar #4 (Believable progress).** A coach who quotes a
  verdict the user has given lands more credibly than one
  who keeps re-explaining the same hypothesis. The context
  line lets the model do the former.
- **Anti-overclaim:** the ack record is the user's own
  report — the context label is explicit ("user said …",
  "user confirmed …") so the model never treats the verdict
  as measured evidence. The hypothesis line itself stays
  framed as a tentative working read.
- **Anti-goal alignment (no "hearts-and-lives gating").** The
  chip row never blocks the input bar or the regular
  follow-up chips; if the user ignores it and types a
  question instead, the row stays in place for the next
  reply and the user keeps the floor.

### Branch + redesign-alignment notes

- All four tracks land on `Redesign`, the redesign-lineage
  branch the rolling M24 deferred-slate work has been
  shipping on since round 11. The user brief explicitly calls
  this out: "ensure working on the redesign branch too (very
  important)." Round 26 preserves the round-by-round loop on
  the redesign lineage.
- Round 26 does not change the dispatched
  `interventionReviewOpener` text or the
  `CoachIntervention.isReviewDue(at:)` predicate from rounds
  24–25, so the existing 26-test suite for those layers
  remains unchanged. The new round-26 suite is additive.

## Future moves

(Updated priority list — round-26 closed the round-25 step #1;
the rest roll forward, plus new notes from round 26.)

1. **Adaptation log entry on a `.rejected` ack.** A natural
   follow-on now that the user can lodge a rejection: when
   `CoachMemory.hypothesisAcknowledgement.confidence ==
   .rejected`, the next `CoachMemoryEngine.build(...)` pass
   could append a `CoachCourseChange` to the adaptation log
   so the bounded case-change record carries the user's
   pushback as the documented reason rather than the engine
   silently inferring one. Pure-function lift on
   `CoachMemoryEngine`; no new UI surface.
2. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
3. **`coachNoteRevealed` cleanup.** Still risky — animation
   chain interleaving with celebration timing. Worth a
   dedicated refactor pass with proper visual QA (and a real
   device).
4. **Visual polish pass on the round-19 launch CTA.** Carried
   forward from rounds 19–25. Pure visual work, not
   destination logic.
5. **Visual polish pass on the round-20 SOLVED ribbon.**
   Carried forward from rounds 20–25. Pure visual work, not
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
10. **Voice-tuned ack-chip glyphs.** New note from round 26.
    The three SF Symbols (`checkmark.circle`,
    `questionmark.circle`, `arrow.triangle.2.circlepath`) are
    voice-independent. A future visual-polish round could
    explore whether the authoritative voice's `.rejected`
    glyph should read more like "veto" rather than
    "re-cycle" — but the durable case-file data is the
    priority, not glyph variants.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so
nothing in this round was compiled or run — not the app, not
the test suite. The changes are:

- One new top-level enum + struct on `PrimaryFocusMemory.swift`,
  inserted between `CoachReflectionReview` and
  `CoachIntervention`. No file-system-synchronised group
  changes required (the file already lives in `Noum/`).
- One new optional field on `CoachMemory` + matching memberwise
  init param + CodingKey + decodeIfPresent line. Same pattern
  the round-24 `lastReflectionReview` and round-23
  `lastTransferReview` additions used.
- One new mutation method on `CoachMemoryStore` mirroring the
  existing `noteReflection(_:)` / `noteTransferOutcome(_:)`
  shape.
- One new static constant + nested struct + two pure static
  funcs on `CoachContextBuilder`. The constant + the predicate
  + the chip catalog are pure and testable without standing up
  any store.
- One new context line in `coachCaseFormulationLines(memory:)`,
  gated on the new ack's `appliesTo` predicate so a stale ack
  on a rewritten hypothesis never surfaces in the user-context
  block.
- One new `@ViewBuilder` + 3 helper properties on `AskNoumView`,
  plus one conditional insert in the scroll-view VStack and
  one new private mutation method. Uses design tokens already
  in scope on the same view.
- New test suite covering predicate, chip catalog, snapshot
  guard, store mutation, context-line surfacing, and
  backward-compat decode. Independent fixtures — no helpers
  borrowed from existing suites.

All checks the next agent should run on a real build host:

1. `swift test --filter HypothesisAcknowledgementTests` —
   the new round-26 tests (19 total in the struct) should
   all pass.
2. `swift test --filter InterventionReviewPromptTests` — the
   round-24 + round-25 tests (26 total) should still pass.
3. `swift test --filter CoachMemoryStoreTests` — the existing
   memory-store tests should still pass with the new
   optional field present in the JSON round-trip.
4. `swift test --filter CoachReadCardDailyBudgetHintTests` —
   the round-23 tests should still pass.
5. `swift test --filter AIRateLimiterPublicationTests` — the
   round-22 tests should still pass.
6. `swift test --filter IMToneDrillCrossingTests` — the
   round-21 helper tests should still pass.
7. `swift test --filter HeroScoreCardToneDrillRibbonContractTests`
   — the round-20 ribbon-contract tests should still pass.
8. `swift test --filter LookingAheadCardStartCTAContractTests`
   — the round-19 launch-CTA tests should still pass.
9. Boot the app on simulator, seed a
   `CoachMemory.activeIntervention` and a non-empty
   `CoachMemory.workingHypothesis` where `followedRepCount ==
   minimumFollowedRepsForReview` and `reviewDueAt` is a past
   date. From the post-rep summary, tap "Review with coach"
   on `InterventionReviewPromptCard`. Wait for the coach reply
   to land. Confirm:
   - The hypothesis ack-chip row renders below the coach
     reply, above the existing follow-up chip row.
   - The eyebrow reads "DOES THIS READ MATCH?" in brand-
     purple.
   - Three chips render: confirmed glyph + label, uncertain
     glyph + label, rejected glyph + label.
   - Tap any chip → the dispatched user turn lands as a real
     bubble, the durable
     `CoachMemoryStore.shared.currentMemory?.hypothesisAcknowledgement`
     is populated with the matching `confidence`, and the
     chip row disappears.
   - On the next reply, the coach replies in voice — for
     `.rejected`, the reply should acknowledge the adapt;
     for `.confirmed`, it should reinforce the read; for
     `.uncertain`, it should ask one focused question.
   - Repeat the test from the AskNoumView empty-state chip
     (round 25). The chip row should render identically
     after the coach replies.
   - Rebuild the memory with a different `workingHypothesis`
     phrasing. Confirm the ack drops from the memory (the
     snapshot guard) and the chip row re-renders next time.
