# HANDOFF — M24 deferred slate (round 30): the `AskNoumView` now surfaces a voice-shaped follow-up chip row below the coach's reply to the round-29 `revisedReadOpener` seed, closing the chat-surface adaptation loop so the user can lock the rebuild in, refine it, or push back again — without typing.

## Scope

Round 29 landed `CoachContextBuilder.revisedReadOpener(workingHypothesis:voice:)` and the
`SummaryView.talkToNoumOpener` gate that routes the post-rep `TalkToNoumCTACard` through
it when the same rep is showing `RevisedReadCard`. The rebuild seed lands in the chat
thread named in first-person ("Picking up the case file — I flagged the prior read as
off."), the body quotes the revised working hypothesis, and the voice-shaped ask invites
the coach to pick up the case file. Round 29's twelve opener tests pin the contract.

The honest gap that left open: when the coach reply lands, the user has nowhere to record
where they land on the rebuild without typing a free-text reply. Either:

- The user types ("yes, stick with it" / "I'd add X" / "still not quite there") — but
  that's a one-off conversational turn, not a durable case-file signal. The next
  `CoachCourseChange` decision has to re-infer the user's stance from chat tone.
- The user closes the thread and moves on — and the rebuild's verdict is silently lost.
  The round-29 work surfaced the user's pushback as a durable adaptation entry, but the
  user's verdict on the *rebuilt* read drops on the floor the moment the chat thread
  goes idle.

The round-26 `hypothesisAckRow` already solves this exact problem for the case-review
opener (`interventionReviewOpener`). Three one-tap chips — confirmed / uncertain /
rejected — let the user lodge a verdict on the working hypothesis without typing. The
ack lands in durable `CoachMemory.hypothesisAcknowledgement` storage, the chat thread
stays continuous (the chip text dispatches as a real user turn), and the next coach
reply lands with the user's verdict reflected in the user-context block.

Round 30 picks up step #11 from the round-29 "Future moves" list:

> **Revised-read follow-up chip row on `AskNoumView`.** After the coach replies to a
> `revisedReadOpener` (the new round-29 dispatched seed), the user could be offered
> a one-tap follow-up — "Here's what I'd add", "Stick with the new read", or "Try a
> third angle" — that lands as a durable signal on the case file. Mirror of the
> round-26 `shouldShowHypothesisAcknowledgement` predicate: detect that the most-
> recent user turn begins with `revisedReadOpenerLead` and that the coach has
> answered, then surface a voice-mapped chip row. Pure-helper lift on
> `CoachContextBuilder` and a new render block in `AskNoumView`. The round-29 lead
> constant is already in place for the predicate to match against — no further
> engine work needed.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure
working towards getting the app towards the vision plan, and all round A+, make my
dream I had come true too, ensure working on the redesign branch too (very
important)."

Translation, this round:

- A new pure function `CoachContextBuilder.shouldShowRevisedReadFollowUp(messages:)`
  mirrors `shouldShowHypothesisAcknowledgement(messages:)` exactly — same predicate
  shape, only the lead constant differs (`revisedReadOpenerLead` instead of
  `interventionReviewOpenerLead`). The two predicates are mutually exclusive at the
  chat-shape level: a single user turn can only begin with one opener lead.
- A new pure function `CoachContextBuilder.revisedReadFollowUpChips(for:)` returns
  the voice-shaped chip catalog. Seven branches (`.authoritative`, `.warm`,
  `.concise`, `.persuasive`, `.executive`, `.storytelling`, `nil`). Three chips per
  branch (`.confirmed`, `.uncertain`, `.rejected`) — same `HypothesisAcknowledgementChip`
  type the round-26 catalog returns. Labels and dispatch text are tuned to the
  rebuild context — "Lock the new read in" / "Here's what I'd add" / "Try a third
  angle" for the authoritative voice — not a copy-paste of the round-26 verdict
  palette ("Yes — that's the read" / "Not sure yet" / "Off — adapt the read").
- `AskNoumView` gains a `revisedReadFollowUpRow` view block, placed in the body
  immediately after the round-26 `hypothesisAckRow`. The two rows sit back-to-back;
  only one will ever render for a given coach reply because the underlying
  predicates are mutually exclusive. The chip-tap path reuses the existing
  `recordHypothesisAck(_:)` function — both rows write the verdict to
  `CoachMemoryStore.noteHypothesisAcknowledgement(_:)` and dispatch the chip's
  voice-shaped text as a real user turn. One storage home for both surfaces.
- The row header reads "Where does the new read land?" — distinct from the
  round-26 row's "Does this read match?". The framing names the rebuild context
  ("the new read") so the user knows the verdict is on the revised hypothesis,
  not the original.
- The redesign-branch invariant: this is a `Redesign`-branch push per the user
  brief. The work lands directly on `Redesign`, preserving the round-by-round loop
  on the redesign lineage that has been the home of rounds 11–29.

## What shipped

### Track 1 — `CoachContextBuilder.shouldShowRevisedReadFollowUp(messages:)` + chip catalog (`CoachContextBuilder.swift`)

- New `static func shouldShowRevisedReadFollowUp(messages: [CoachMessage]) -> Bool`.
  Pure-function mirror of `shouldShowHypothesisAcknowledgement(messages:)`. Same
  guard structure:
  - Most-recent message must be a non-pending coach reply with non-empty text.
  - The prior user turn (last `.user` message before the coach reply) must begin
    with `revisedReadOpenerLead` ("Picking up the case file — I flagged the prior
    read as off." — pinned on `CoachContextBuilder` since round 29).
  - Empty message arrays return false.
  - User turn at the tail returns false (the conversation has moved on).
- New `static func revisedReadFollowUpChips(for voice: SpeakingStyleGoal?) -> [HypothesisAcknowledgementChip]`.
  Seven voice branches, three chips per branch, all carrying the same
  `CoachHypothesisConfidence` enum. Voice-shape mapping:
  - `.authoritative` → "Lock the new read in" / "Here's what I'd add" / "Try a third angle"
  - `.warm` → "This one fits" / "I'd add to it" / "Still not quite there"
  - `.concise` → "Stick" / "Add" / "Reframe" (one-token labels, mirror of round-26
    "Matches / Unsure / Adapt")
  - `.persuasive` → "I'll make this case" / "I'd refine the claim" / "Argue a third angle"
  - `.executive` → "Approve the rebuild" / "Amend — one addition" / "Reject — try again"
  - `.storytelling` → "That's the chapter" / "Add a scene" / "A different chapter"
  - `nil` → "Stick with the new read" / "Here's what I'd add" / "Try a different read"
- Brand-voice compliant — no exclamation, no "Let's" in chip labels, no urgency
  framing. The chips are a verdict surface, not a CTA chorus.
- Section comment block placed between the round-26 hypothesis-ack chips section
  and the per-voice starter-prompts section. Same MARK convention as round 26's
  block. No reordering of existing code.

### Track 2 — `AskNoumView.revisedReadFollowUpRow` + body integration (`AskNoumView.swift`)

- New `@ViewBuilder private var revisedReadFollowUpRow: some View`. Mirror of the
  round-26 `hypothesisAckRow` view shape:
  - Caps row header "Where does the new read land?" (distinct from round-26's
    "Does this read match?") — the framing names the rebuild context so the user
    knows the verdict is on the revised hypothesis.
  - `FlowLayout` of voice-shaped chips reusing the round-26 chip glyph palette
    (`checkmark.circle` / `questionmark.circle` / `arrow.triangle.2.circlepath`)
    via the existing `ackChipGlyph(for:)` helper.
  - Accessibility identifier `askNoum.revisedReadFollowUp.<confidence>` so UI
    tests can target the new row without disturbing the round-26
    `askNoum.hypothesisAck.<confidence>` identifiers.
  - Tap calls `recordHypothesisAck(_:)` — the same function the round-26 row uses.
    One write path: `CoachMemoryStore.noteHypothesisAcknowledgement(_:)` persists
    the verdict, `send(_:)` dispatches the chip's voice-shaped text as a real
    user turn.
- New `private var shouldShowRevisedReadFollowUp: Bool` eligibility composite.
  Same shape as round-26's `shouldShowHypothesisAck`:
  - Chat-shape predicate from `CoachContextBuilder` covers the lead-prefix check.
  - Memory check ensures `workingHypothesis` is non-empty.
  - `CoachHypothesisAcknowledgement.appliesTo` snapshot guard suppresses the row
    once the user has lodged a verdict on the currently-carried (rebuilt)
    hypothesis. A subsequent memory rebuild rewrites the hypothesis and drops
    the ack via `appliesTo`, which re-enables the row.
- New `private var revisedReadFollowUpChips` thin wrapper around the catalog
  helper, mirror of round-26's `hypothesisAckChips`.
- Body integration: the new `revisedReadFollowUpRow` sits immediately after the
  existing `hypothesisAckRow` in the `body` ScrollView block. Both have stable
  `.id()` anchors (`hypothesisAck` and `revisedReadFollowUp`) so scrolling
  doesn't lose position when the chip row appears.
- No layout change on the round-26 row. No new state. No new bindings.

### Track 3 — `RevisedReadFollowUpTests` suite (`NoumTests/NoumTests.swift`)

New top-level `@Suite("RevisedReadFollowUpTests")` at the end of the file (after
the round-29 `RevisedReadOpenerTests`). Fifteen `@Test` methods pin both the
predicate contract and the chip catalog:

- **Predicate happy path (2 tests):**
  - `shouldShowReturnsTrueWhenCoachRepliedToRevisedReadOpener` — full round-29
    composed opener as the user turn, non-pending coach reply at the tail. Row
    eligible.
  - `shouldShowReturnsTrueWhenUserTurnStartsWithLeadEvenIfRestDiffers` — prefix-
    match contract; a future copy edit to the body or ask should not break
    detection.
- **Predicate negative paths (5 tests):**
  - `shouldShowReturnsFalseWhenLastMessageIsUserTurn` — conversation moved on.
  - `shouldShowReturnsFalseWhenCoachReplyIsPending` — typing dots guard.
  - `shouldShowReturnsFalseWhenUserTurnIsOrganicQuestion` — opener filter.
  - `shouldShowReturnsFalseWhenUserTurnIsCaseReviewOpener` — cross-predicate
    exclusion; the round-26 lead must not trigger the round-30 row.
  - `shouldShowReturnsFalseOnEmptyMessages` — empty array.
- **Cross-predicate mutual exclusion (1 test):**
  - `revisedReadAndHypothesisAckPredicatesAreMutuallyExclusive` — exhaustive
    matrix across three cases (revised-read opener, case-review opener, organic
    question). Locks the UI-layer assumption that the two chip rows can sit
    back-to-back without a tiebreaker.
- **Chip catalog shape (3 tests):**
  - `chipCatalogIsThreeChipsPerVoice` — three branches per voice, full
    confidence palette.
  - `chipDispatchTextIsNeverEmpty` — defensive against blank user bubbles.
  - `chipLabelsAvoidBannedPhrasings` — brand-voice scan (no `!`, no "Let's" in
    labels, no urgency words). Note: dispatch text may contain "let's" in the
    warm voice as a thread-internal aside, but the user-facing label stays flat.
- **Voice-shape sanity (5 tests, one per non-trivial branch + nil):**
  - `authoritativeVoiceUsesDecisionRegister` — "Lock the new read in" not "This
    one fits".
  - `warmVoiceUsesCollaborativeRegister` — "This one fits" not "Lock".
  - `conciseVoiceUsesOneWordLabels` — "Stick / Add / Reframe".
  - `executiveVoiceUsesApprovalRegister` — "Approve the rebuild / Reject — try
    again".
  - `storytellingVoiceUsesChapterMetaphor` — "chapter" / "scene" framing.
  - `nilVoiceProducesVoiceNeutralLabels` — defensive against a half-onboarded
    user landing the rebuild seed.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the case
  formulation needs a "reason for changing course" AND a way to confirm a
  rebuild has landed before the next adaptation cycle fires. Round 29 closed
  the seed half (chat thread names the user's pushback). Round 30 closes the
  verdict half (chat thread records whether the rebuild stuck, needs refining,
  or needs another adaptation). The `.rejected` verdict on a rebuild is now
  a structured signal the next `CoachCourseChange` decision can read; the
  `.confirmed` verdict locks the rebuild in without forcing another
  `InterventionReviewPromptCard` cadence to fire.
- **Pillar #5 (Personalized coaching).** A human coach who rebuilt their read
  at the user's pushback would not move on without asking "does this new read
  land?" — they'd want the user's verdict on the *revised* hypothesis, not
  just the original. Round 26 added that mechanism for the case-review surface;
  round 30 extends the same mechanism to the rebuild surface so the coach's
  ask reaches the user on EVERY adaptation cycle, not only the first one.
- **Pillar #4 (Believable progress).** The chip catalog reads as a continuation
  of the round-26 verdict palette in shape — three branches, voice-shaped
  labels, same `CoachHypothesisConfidence` enum — so the user's experience of
  "lodge a verdict on the coach's read" stays continuous across both surfaces.
  No new vocabulary to learn.
- **Anti-overclaim.** The chip dispatch text mirrors the round-26 restraint:
  "Lock the new read in" not "You nailed this read"; "Try a third angle" not
  "You were wrong to rebuild". The user records *their* verdict; the coach
  doesn't claim correctness.
- **Anti-goal alignment (no hearts-and-lives gating).** The chip row doesn't
  block, punish, or celebrate. It is a quiet verdict surface; tap or scroll
  past — both are valid.

### Branch + redesign-alignment notes

- All three tracks land on `Redesign`, the redesign-lineage branch the rolling
  M24 deferred-slate work has been shipping on since round 11. The user brief
  explicitly calls this out: "ensure working on the redesign branch too (very
  important)." Round 30 preserves the round-by-round loop on the redesign
  lineage.
- Round 30 does not change the round-29 `revisedReadOpener` function, does not
  change the round-29 `talkToNoumOpener` gate, does not change the round-28
  `RevisedReadCard` view, does not change the round-27 engine restructure,
  does not change the round-26 chip catalog, does not change the round-26
  hypothesis-ack row, and does not change the round-24 / round-25
  `InterventionReviewPromptCard` surface. The round-29 12 opener tests + round-
  28 5 copy tests + round-26 19 ack tests all remain unchanged; the round-30
  15 follow-up tests sit alongside them.

## Future moves

(Updated priority list — round-30 closed the round-29 step #11; the rest
roll forward, plus one new note from round 30.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on
   `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving
   with celebration timing. Worth a dedicated refactor pass with proper visual
   QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from
   rounds 19–29. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from
   rounds 20–29. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.** Carried
   forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward from
   round 22.
7. **Tier-change observation symmetry to other surfaces that read
   `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
8. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore`
   mutates while AskNoumView is mounted.** Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26. Note for
   round 30: any voice-tuned glyph work that lands on round-26's chip row
   should be lifted into the shared `ackChipGlyph(for:)` helper so the
   round-30 row picks up the same per-voice glyph mapping.
10. **`.confirmed` confidence amplification on the active intervention.**
    Carried forward from round 27. Flip side of rejection-becomes-course-
    change: a `.confirmed` ack on a held hypothesis could nudge
    `CoachIntervention.criterionStatus` toward "met" or extend the
    `reviewDueAt` cadence. The natural follow-on to the round-27/28/29/30
    rejection lineage — and round 30 makes this more valuable, because BOTH
    rows now write `.confirmed` acks to the same store; a single amplification
    helper would lift verdicts from both surfaces.
11. **Carry the revised-read context into the chat-coach context block.** From
    round 29. The `CoachContextBuilder.buildContextBlock(...)` user-block could
    surface the fresh adaptation entry ("Case file just shifted: user flagged
    the prior read; new working hypothesis is X") when the latest
    `CoachCourseChange` is both `documentsUserPushback` and `isFresh`. The
    model would then know the case state on EVERY chat turn through the next
    rep, not only on the seed message that opened the thread. Pure-function
    lift on the existing context-block builder; gate on the same
    `freshRevisedReadChange` predicate the summary card and the round-29
    opener already read.
12. **Reflect the revised-read follow-up verdict in the next user-context
    block.** New note from round 30. After the user lands a verdict on the
    rebuild via the round-30 chip row, the next user-context block could
    surface a one-line summary line ("User accepted the rebuilt read on
    <date>; treat as the operating hypothesis") so the model knows whether
    the rebuilt read is the live one or the user is still pushing back.
    Mirror of the round-26 hypothesis-ack reflection in the existing
    builder, but tagged to the *rebuild* verdict for analytic purposes (so a
    future trend view can distinguish "user accepted the first read" from
    "user accepted the rebuilt read").
13. **Adaptation-log entry on a round-30 `.rejected` verdict.** New note from
    round 30. A `.rejected` verdict on a rebuilt read is functionally
    equivalent to the round-27 trigger — the user is pushing back on the
    coach's read again, this time on the revised one. The natural next step:
    record a fresh `CoachCourseChange` adaptation-log entry on the second
    rejection, with the rebuilt hypothesis as the prior and the next rebuild
    as the revised. Closes the loop on the rejection-rebuild-rejection-rebuild
    chain so the case file captures the full adaptation history, not just
    the first cycle.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this
round was compiled or run — not the app, not the test suite. The changes are:

- One new `static func shouldShowRevisedReadFollowUp(messages:)` + one new
  `static func revisedReadFollowUpChips(for:)` on `CoachContextBuilder`
  (`CoachContextBuilder.swift`), placed inside the existing struct
  immediately after `hypothesisAcknowledgementChips(for:)` and before the
  per-voice starter-prompts section. Self-contained — no new imports, no
  new dependencies, no new types (reuses `HypothesisAcknowledgementChip`
  and `CoachHypothesisConfidence`).
- One new `@ViewBuilder private var revisedReadFollowUpRow` + supporting
  `shouldShowRevisedReadFollowUp` composite + `revisedReadFollowUpChips`
  wrapper on `AskNoumView` (`AskNoumView.swift`), placed immediately
  after `recordHypothesisAck(_:)` and before `followUpRow(chips:)`. One
  body-integration edit: two new lines after `hypothesisAckRow` in the
  ScrollView block.
- One new `@Suite("RevisedReadFollowUpTests")` at the end of
  `NoumTests/NoumTests.swift` with fifteen `@Test` methods. The suite is
  plain `struct`, `@MainActor` (mirror of `HypothesisAcknowledgementTests`
  attribute, defensive against any future `MainActor`-only reads in
  `CoachContextBuilder`).

All checks the next agent should run on a real build host:

1. `swift test --filter RevisedReadFollowUpTests` — the new round-30 15
   follow-up tests should all pass.
2. `swift test --filter RevisedReadOpenerTests` — the round-29 12 opener
   tests should still pass. No round-29 surface was changed.
3. `swift test --filter RevisedReadCardTests` — the round-28 5 copy-generator
   tests should still pass. No round-28 surface was changed.
4. `swift test --filter CoachMemoryEngineTests` — the round-28 6 predicate
   tests + the pre-28 suite should still pass.
5. `swift test --filter HypothesisAcknowledgementTests` — the round-26 tests
   (19 total) should still pass. No round-26 chip surface, predicate, or
   store mutation was changed.
6. `swift test --filter InterventionReviewPromptTests` — the round-24 +
   round-25 tests (26 total) should still pass.
7. `swift test --filter CoachMemoryStoreTests` — the existing memory-store
   tests should still pass.
8. `swift test --filter CoachReadCardDailyBudgetHintTests` — round-23 tests
   should still pass.
9. `swift test --filter AIRateLimiterPublicationTests` — round-22 tests
   should still pass.
10. `swift test --filter IMToneDrillCrossingTests` — round-21 helper tests
    should still pass.
11. `swift test --filter HeroScoreCardToneDrillRibbonContractTests` —
    round-20 ribbon-contract tests should still pass.
12. `swift test --filter LookingAheadCardStartCTAContractTests` — round-19
    launch-CTA tests should still pass.
13. Boot the app on simulator, seed a `CoachMemory.activeIntervention`
    with a working hypothesis, open Ask Noum via the round-24
    `InterventionReviewPromptCard` or the round-25 empty-state chip,
    wait for the coach reply, tap the **Adapt / rejected** ack chip.
    Then finish a new rep where either the lever changes OR the
    hypothesis text rewrites (e.g. `evidenceCount` crosses a
    `BaselineConfidence` threshold). On the post-rep summary, confirm
    `RevisedReadCard` renders (round-28 contract). Now tap **Talk to
    Noum** on the `TalkToNoumCTACard` below. Confirm in the chat thread:
    - The user-turn seed is the round-29 revised-read opener.
    - The coach reply lands case-anchored.
    - **NEW (round 30):** Below the coach reply, the
      `revisedReadFollowUpRow` renders with the header "WHERE DOES THE
      NEW READ LAND?" and three voice-shaped chips. The chips read as
      verdicts on the rebuilt hypothesis (not the original).
    - Tap **Stick with the new read** (or voice-equivalent). Confirm:
      - The chip text dispatches as a real user turn in the thread.
      - The follow-up chip row disappears (`appliesTo` snapshot guard
        on the new `CoachHypothesisAcknowledgement`).
      - The coach replies again (model picks up the verdict from the
        user-context block on the next turn).
    - Open the case-file viewer (or Settings → Coach Memory). Confirm
      the latest `hypothesisAcknowledgement` carries `.confirmed`
      tagged to the REBUILT hypothesis snapshot.
    - Repeat the test with **Here's what I'd add** (`.uncertain`) and
      **Try a third angle** (`.rejected`). Confirm each verdict lands
      with the correct enum value tagged to the rebuilt snapshot.
    - Send a new organic message in the same thread. Confirm the chip
      row stays hidden (predicate: prior user turn is no longer the
      revised-read opener).
14. Switch the speaking-style goal in Settings to each of the seven
    branches (`.authoritative`, `.warm`, `.concise`, `.persuasive`,
    `.executive`, `.storytelling`, `nil`). Re-trigger the rebuild +
    chip row flow. Confirm the chip labels shift per voice (e.g.
    `.concise` shows single-token labels "Stick / Add / Reframe";
    `.executive` shows "Approve the rebuild / Amend — one addition /
    Reject — try again"). Locks the voice-mapping contract end-to-end.
