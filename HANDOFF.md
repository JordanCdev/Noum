# HANDOFF — M24 deferred slate (round 29): the post-rep `TalkToNoumCTACard` no longer dispatches a generic `sessionOpener` on the rep where `RevisedReadCard` is showing — the chat seed now names the user's pushback, quotes the coach's revised read, and invites the coach to pick up the case file.

## Scope

Round 28 landed `RevisedReadCard` on the post-rep `SummaryView` —
when the rebuild folds a `.rejected` ack into the case file, the
user themselves sees "you flagged the prior read as off; here's the
revised one." The visual acknowledgement is in place.

The honest gap that left open: on the same rep, a tap on the
existing `TalkToNoumCTACard` (a few rows below the new card) still
dispatches `CoachContextBuilder.sessionOpener(...)` — the generic
"Just finished a Timed rep — 60s, 3 fillers, 8/10. Give me your
read." seed. The chat thread starts as if the user had never
tapped `.rejected`. The case-file turn that `RevisedReadCard`
named on the summary drops on the floor the instant the user opens
the conversation. The Ask Noum thread loses continuity with the
card the user just saw.

Round 29 picks up step #11 from the round-28 "Future moves" list:

> **Reflect the revised read in the post-rep AI coach
> conversation seed.** The `RevisedReadCard` surfaces the user-
> pushback line as a visual acknowledgement, but a tap on the
> existing `TalkToNoumCTACard` still dispatches the generic
> `sessionAnchoredOpener` rather than a revised-read-aware opener
> ("you flagged the prior read; here's where my updated read sits
> — anything to add?"). Pure-function lift on `CoachContextBuilder`
> similar to `interventionReviewOpener`. Would only fire when the
> same `freshRevisedReadChange` gate is true, so the conversation
> opener stays case-anchored on the rep that drove the rebuild.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- A new pure function `CoachContextBuilder.revisedReadOpener(
  workingHypothesis:voice:)` composes the case-anchored seed.
  Shape mirrors `sessionOpener` and `interventionReviewOpener`
  exactly — short fact-lead + voice-mapped ask. The lead is a
  static constant (`revisedReadOpenerLead`) so a future predicate
  (e.g. a chat-thread classifier that fires a revised-read
  follow-up chip row, mirror of the round-26
  `shouldShowHypothesisAcknowledgement` predicate) can match the
  prefix without composing the full opener.
- `SummaryView` gains a `talkToNoumOpener` computed property that
  routes between the two openers — revised-read opener when
  `freshRevisedReadChange != nil`, generic `sessionAnchoredOpener`
  otherwise. Both `TalkToNoumCTACard` call sites (IM/PREP path
  and TIMED / Ah-Counter / Sudden Death path) now dispatch
  `talkToNoumOpener` instead of `sessionAnchoredOpener`. The gate
  logic lives in one home; the call sites stay identical to each
  other.
- The opener body trims and strips a trailing period from
  `workingHypothesis` the same way `RevisedReadCard.bodyCopy(
  workingHypothesis:)` does, so the same hypothesis text reads as
  a single sentence on both surfaces (card and chat seed). A nil
  or whitespace-only hypothesis falls back to a "still forming"
  line so the seed never reads "The revised read you're holding
  is: ." to the model.
- The opener is user-voice, first-person ("I flagged"), matching
  every other dispatched opener — `sessionOpener` ("Just
  finished..."), `interventionReviewOpener` ("Time to review..."),
  the hypothesis ack chips ("Yes — that's the read"). The user is
  the one typing the message; perspective stays continuous.
- The redesign-branch invariant: this is a `Redesign`-branch push
  per the user brief. The work lands directly on `Redesign`,
  preserving the round-by-round loop on the redesign lineage that
  has been the home of rounds 11–28.

## What shipped

### Track 1 — `CoachContextBuilder.revisedReadOpener(...)` (`CoachContextBuilder.swift`)

- New `static let revisedReadOpenerLead`
  (`"Picking up the case file — I flagged the prior read as off."`).
  Lifted as a constant on `CoachContextBuilder` so the predicate
  surface and the opener composition share the lead phrase in one
  place. Same pattern as `interventionReviewOpenerLead` (round 26,
  used by `shouldShowHypothesisAcknowledgement`).
- New `static func revisedReadOpener(workingHypothesis:voice:)
  -> String`. Pure function — no store reads, no `Date`
  dependencies. Returns the three-sentence composition:
  lead + body + voice-mapped ask, joined by single spaces.
- Body composition:
  - `workingHypothesis` is non-nil and non-blank →
    `"The revised read you're holding is: <stripped hypothesis>."`
    where `<stripped hypothesis>` has the trailing period removed
    if present, so the wrapper's terminal `.` is the only one in
    the sentence. Same strip pattern as
    `RevisedReadCard.bodyCopy(workingHypothesis:)`.
  - `workingHypothesis` nil or whitespace-only →
    `"The revised read is still forming."`. The seed still reads
    as a coherent case-anchored opener; the model isn't asked
    "is: ." with an empty noun.
- Voice mapping (seven branches — `.authoritative`, `.warm`,
  `.concise`, `.persuasive`, `.executive`, `.storytelling`, `nil`):
  - `.authoritative` → "Where does the read land now?"
  - `.warm` → "What does this open up?"
  - `.concise` → "Where does this go?"
  - `.persuasive` → "Make the case for the new read."
  - `.executive` → "Brief me on what shifted."
  - `.storytelling` → "What chapter does this start?"
  - `nil` → "Where does this go from here?"
- Brand-voice compliant — no exclamation, no "Let's", no urgency
  framing, no celebration. The coach is being asked to pick up a
  case file the user has already named.

### Track 2 — `SummaryView.talkToNoumOpener` gate + CTA wiring (`SummaryView.swift`)

- New `talkToNoumOpener: String` private computed property,
  placed immediately after `sessionAnchoredOpener`. Walks the
  same `freshRevisedReadChange` gate the `RevisedReadCard` reads
  — when non-nil it returns
  `CoachContextBuilder.revisedReadOpener(...)`, otherwise it
  falls through to `sessionAnchoredOpener`. One home for the
  routing decision.
- Both `TalkToNoumCTACard.onAskNoum` closures now dispatch
  `onAskNoumAboutRep?(talkToNoumOpener)` instead of
  `onAskNoumAboutRep?(sessionAnchoredOpener)`. The two call sites
  (IM/PREP path at line 650 and TIMED / Ah-Counter / Sudden Death
  path at line 765) stay identical to each other; the routing
  decision is invisible at the call site.
- No layout change. No new component. The `TalkToNoumCTACard`
  visual contract is unchanged — only the seed text it dispatches
  on tap shifts when the gate is hot.

### Track 3 — `RevisedReadOpenerTests` suite (`NoumTests/NoumTests.swift`)

New top-level `@Suite("RevisedReadOpenerTests")` at the end of the
file (after the round-28 `RevisedReadCardTests`). Twelve `@Test`
methods pin the pure-function contract:

- **Lead constant + composition contract (2 tests):**
  - `openerLeadNamesUserPushbackInFirstPerson` — pins the lead
    constant verbatim. Locks the first-person framing that
    matches every other dispatched opener.
  - `openerStartsWithTheLeadConstant` — pins the prefix-match
    contract a future classifier predicate would read.
- **Body composition (4 tests):**
  - `openerBodyQuotesRevisedHypothesisInline` — names the
    revised working hypothesis verbatim.
  - `openerBodyStripsTrailingPeriodToAvoidDoubleStop` — locks the
    strip-trailing-period contract; mirrors the same test in
    `RevisedReadCardTests` so card and seed never diverge.
  - `openerBodyFallsBackWhenNoHypothesis` — nil hypothesis takes
    the "still forming" fallback.
  - `openerBodyFallsBackWhenHypothesisIsBlank` — whitespace-only
    hypothesis takes the same fallback.
- **Voice mapping (7 tests, one per voice branch + nil):**
  - `openerAskByVoiceAuthoritative`, `…Warm`, `…Concise`,
    `…Persuasive`, `…Executive`, `…Storytelling`, `openerAskWhenVoiceIsNil`.
    Each pins the suffix of the composed opener so a future copy
    edit on any one ask forces the test to follow.
- **End-to-end composition (2 tests):**
  - `openerComposesLeadBodyAndAskWithSingleSpaces` — locks the
    exact composed string for a `.concise` voice + present
    hypothesis. Asserts no double spaces, no newlines.
  - `openerFallbackComposesLeadAndFallbackBodyWithAsk` — same
    lock for the nil-hypothesis fallback with a `.warm` voice.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  the case formulation needs a "reason for changing course." Round
  27 landed the adaptation-log entry. Round 28 surfaced it as a
  visual acknowledgement on the post-rep summary. Round 29 closes
  the loop by making the chat thread continuous with the card —
  when the user opens Ask Noum from the same rep, the seed names
  the same pushback, quotes the same revised hypothesis, and the
  conversation starts where the card left off. The user does not
  re-enter the case from a generic rep summary.
- **Pillar #5 (Personalized coaching).** A coach who silently
  revises a read without naming the pushback breaks the coaching
  contract on the SUMMARY surface (round 28 fix). A coach whose
  chat seed forgets the pushback the instant the user opens the
  conversation breaks the same contract on the CHAT surface
  (round 29 fix). Both surfaces now name the user's action.
- **Pillar #4 (Believable progress).** The body quotes the actual
  revised `workingHypothesis` — the same clause the card carries,
  the same one `CaseReviewCard` surfaces under "Working read",
  the same one the coach context block reads. Continuous voice
  across all four surfaces.
- **Anti-overclaim.** The seed never claims the prior read was
  *wrong* — it says the user *flagged* it as off. Same restraint
  pattern the round-27 `evidenceBasis`, the round-28 card
  headline, and the existing adaptation-log copy carry.
- **Anti-goal alignment (no hearts-and-lives gating).** The
  opener doesn't block, punish, or celebrate. It is a quiet
  case-anchored seed; the chat loop continues unchanged.

### Branch + redesign-alignment notes

- All three tracks land on `Redesign`, the redesign-lineage branch
  the rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." Round 29
  preserves the round-by-round loop on the redesign lineage.
- Round 29 does not change the round-28 `RevisedReadCard` view,
  does not change the round-28 `freshRevisedReadChange` predicate,
  does not change the round-27 engine restructure, does not change
  the round-26 chip catalog, and does not change the round-24 /
  round-25 `InterventionReviewPromptCard` surface. The round-28
  6 engine-predicate tests + 5 copy tests remain unchanged; the
  round-29 12 opener tests sit alongside them.

## Future moves

(Updated priority list — round-29 closed the round-28 step #11;
the rest roll forward, plus one new note from round 29.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried
   forward from rounds 19–28. Pure visual work, not destination
   logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–28. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.**
   Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried
   forward from round 22.
7. **Tier-change observation symmetry to other surfaces that read
   `AIRateLimiter.currentCap()` directly.** Carried forward from
   round 23.
8. **Refresh-on-rotate for the empty-state chip when the
   `CoachMemoryStore` mutates while AskNoumView is mounted.**
   Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **`.confirmed` confidence amplification on the active
    intervention.** Carried forward from round 27. Flip side of
    rejection-becomes-course-change: a `.confirmed` ack on a held
    hypothesis could nudge `CoachIntervention.criterionStatus`
    toward "met" or extend the `reviewDueAt` cadence. The natural
    follow-on to the round-27/28/29 rejection lineage.
11. **Revised-read follow-up chip row on `AskNoumView`.** New note
    from round 29. After the coach replies to a
    `revisedReadOpener` (the new round-29 dispatched seed), the
    user could be offered a one-tap follow-up — "Here's what I'd
    add", "Stick with the new read", or "Try a third angle" — that
    lands as a durable signal on the case file. Mirror of the
    round-26 `shouldShowHypothesisAcknowledgement` predicate:
    detect that the most-recent user turn begins with
    `revisedReadOpenerLead` and that the coach has answered, then
    surface a voice-mapped chip row. Pure-helper lift on
    `CoachContextBuilder` and a new render block in `AskNoumView`.
    The round-29 lead constant is already in place for the
    predicate to match against — no further engine work needed.
12. **Carry the revised-read context into the chat-coach context
    block.** Also new from round 29. The
    `CoachContextBuilder.buildContextBlock(...)` user-block could
    surface the fresh adaptation entry ("Case file just shifted:
    user flagged the prior read; new working hypothesis is X")
    when the latest `CoachCourseChange` is both
    `documentsUserPushback` and `isFresh`. The model would then
    know the case state on EVERY chat turn through the next rep,
    not only on the seed message that opened the thread. Pure-
    function lift on the existing context-block builder; gate on
    the same `freshRevisedReadChange` predicate the summary card
    and the round-29 opener already read.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so
nothing in this round was compiled or run — not the app, not the
test suite. The changes are:

- One new `static let` constant + one new `static func` on
  `CoachContextBuilder` (`CoachContextBuilder.swift`), placed
  inside the existing struct immediately after
  `interventionReviewStarterHeadline(for:)` and before the
  hypothesis-acknowledgement-chips section. Self-contained — no
  new imports, no new dependencies.
- One new `talkToNoumOpener` private computed property on
  `SummaryView` (`SummaryView.swift`), placed immediately after
  `sessionAnchoredOpener`. Two call-site edits: line 650 and
  line 765 swap `sessionAnchoredOpener` for `talkToNoumOpener`.
  No other layout change, no new state, no new bindings.
- One new `@Suite("RevisedReadOpenerTests")` at the end of
  `NoumTests/NoumTests.swift` with twelve `@Test` methods. The
  suite is plain `struct`, no `@MainActor` (the function under
  test is a pure static function with no UI dependencies).

All checks the next agent should run on a real build host:

1. `swift test --filter RevisedReadOpenerTests` — the new
   round-29 12 opener tests should all pass.
2. `swift test --filter RevisedReadCardTests` — the round-28
   5 copy-generator tests should still pass. No round-28
   surface was changed.
3. `swift test --filter CoachMemoryEngineTests` — the round-28
   6 predicate tests + the pre-28 suite should still pass.
4. `swift test --filter HypothesisAcknowledgementTests` — the
   round-26 tests (19 total) should still pass.
5. `swift test --filter InterventionReviewPromptTests` — the
   round-24 + round-25 tests (26 total) should still pass.
6. `swift test --filter CoachMemoryStoreTests` — the existing
   memory-store tests should still pass.
7. `swift test --filter CoachReadCardDailyBudgetHintTests` —
   round-23 tests should still pass.
8. `swift test --filter AIRateLimiterPublicationTests` — round-22
   tests should still pass.
9. `swift test --filter IMToneDrillCrossingTests` — round-21
   helper tests should still pass.
10. `swift test --filter HeroScoreCardToneDrillRibbonContractTests`
    — round-20 ribbon-contract tests should still pass.
11. `swift test --filter LookingAheadCardStartCTAContractTests` —
    round-19 launch-CTA tests should still pass.
12. Boot the app on simulator, seed a
    `CoachMemory.activeIntervention` with a working hypothesis,
    open Ask Noum via the round-24 `InterventionReviewPromptCard`
    or the round-25 empty-state chip, wait for the coach reply,
    tap the **Adapt / rejected** ack chip. Then finish a new rep
    where either the lever changes OR the hypothesis text rewrites
    (e.g. `evidenceCount` crosses a `BaselineConfidence` threshold).
    On the post-rep summary, confirm `RevisedReadCard` renders
    (round-28 contract). Now tap **Talk to Noum** on the
    `TalkToNoumCTACard` below. Confirm in the chat thread:
    - The user-turn seed reads "Picking up the case file — I
      flagged the prior read as off. The revised read you're
      holding is: <hypothesis>. <voice-shaped ask>" — three
      discrete sentences, single-space joined.
    - The voice-shaped ask matches the current
      `coachingProfileStore.profile?.speakingStyleGoal`.
    - The coach reply lands case-anchored (mentions the revised
      read, not a generic rep verdict).
    - Finish another rep WITHOUT a fresh `.rejected` ack — open
      Ask Noum from the `TalkToNoumCTACard` again — the seed
      MUST be the generic `sessionOpener` ("Just finished a
      Timed rep — ...") because `freshRevisedReadChange` is now
      nil. The revised-read opener is one-shot per pushback.
    - Repeat with a `.confirmed` or `.uncertain` ack across a
      hypothesis rewrite — the `TalkToNoumCTACard` MUST dispatch
      the generic `sessionOpener` (the adaptation-log entry is
      either absent or doesn't carry the pushback marker, so the
      gate falls).
