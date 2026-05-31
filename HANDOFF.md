# HANDOFF — M24 deferred slate (round 28): the user-pushback line lands in the post-rep `SummaryView` — when the rebuild folds a `.rejected` ack into the case file, the user themselves sees "you flagged the prior read as off; here's the revised one."

## Scope

Round 27 closed the round-26 step #1 — when the user lodged a
`.rejected` acknowledgement on the working hypothesis and the next
memory rebuild silently dropped the ack via the snapshot guard, the
engine now appends a `CoachCourseChange` to the adaptation log whose
`reason` carries the user-reported pushback ("user reported the
prior hypothesis did not match") and whose `evidenceBasis` quotes
the user's own snapshot. The bounded case-file history now carries
the user's pushback rather than a silent engine inference.

The honest gap that left open: the chat-coach context block already
reads the latest adaptation entry through `coachAdaptationLogLine`
("Last course change: …"), and the Profile-tab `CaseReviewCard`
already surfaces `adaptationLog.last.reason` under "Last shift" —
but the post-rep `SummaryView` does NOT yet show the user
themselves "the coach noticed your pushback and revised the read."
The user taps `.rejected` in Ask Noum, finishes their next rep, and
the summary screen acts as if nothing happened — even though the
case file has just been rewritten as a direct consequence of their
verdict. A human coach would say "okay, you flagged the prior read
as off — here's the revised one"; round 27 left that turn off the
post-rep surface.

Round 28 picks up step #1 from the round-27 "Future moves" list:

> 1. **Surface the user-pushback line in the post-rep summary.**
>    The adaptation log now carries the rejection, and the
>    `coachAdaptationLogLine` already surfaces "Last course
>    change: ..." in the coach context block, but the post-rep
>    SummaryView does not yet show this to the user themselves
>    ("you flagged the prior read as off; here's the revised
>    one"). Pure UI lift, no new state — the data is already in
>    `CoachMemoryStore.shared.currentMemory?.adaptationLog?.last`.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- `CoachCourseChange` gains two pure-function derived properties.
  `documentsUserPushback` matches the engine's lifted marker phrase
  (`"user reported the prior hypothesis did not match"`) so the
  predicate stays locked to the engine's `(prior?, ack?)` /
  `(nil, ack?)` switch arms — both write the marker into `reason`.
  `isFresh(comparedTo memoryUpdatedAt:)` answers "was this entry
  appended on the rebuild that produced the carrying memory?" with
  a 1-second tolerance so the same-`now` stamp in
  `CoachMemoryEngine.build(...)` reads as fresh while a carried-
  forward entry from an earlier rebuild reads as stale. Both
  predicates are pure functions of fields already on the persisted
  shape — no Codable schema bump.
- A new `RevisedReadCard` view (`RevisedReadCard.swift`) renders
  the post-rep surface. Eyebrow: "REVISED READ". Headline: the
  user-action clause ("You flagged the prior read as off."). Body:
  "Here's the revised read: <workingHypothesis>", with the trailing
  period of the hypothesis clause stripped so the line never reads
  as two sentences ending in one. Restrained — no CTA (the
  `TalkToNoumCTACard` already routes the user into Ask Noum with
  the session-anchored opener a few rows below). Brand-voice
  compliant: no exclamation, no "Let's", no urgency framing. Mirror
  of the `InterventionReviewPromptCard` register so the user reads
  it as a continuation of the same coach voice.
- `SummaryView` gains `freshRevisedReadChange: CoachCourseChange?`,
  a private computed property that walks
  `coachMemoryStore.currentMemory?.adaptationLog?.last`, runs both
  derived predicates, and returns the entry iff both gates hold.
  Mirror of the existing `activeReviewDueIntervention` pattern —
  one home for the eligibility logic, the view is a thin reader.
- The card lands at both render sites — the IM/PREP path and the
  TIMED / Ah-Counter / Sudden Death path — immediately above the
  existing `InterventionReviewPromptCard`. The two coach-voice
  cards now cluster (revised read + review prompt) so the user
  reads the case-file turn in one visual beat before the
  `TalkToNoumCTACard`.
- The redesign-branch invariant: this is a `Redesign`-branch push
  per the user brief. The work lands directly on `Redesign`,
  preserving the round-by-round loop on the redesign lineage that
  has been the home of rounds 11–27.

## What shipped

### Track 1 — `CoachCourseChange` derived predicates (`PrimaryFocusMemory.swift`)

- New `static let userPushbackMarker` constant
  (`"user reported the prior hypothesis did not match"`). Lifted as
  a constant on `CoachCourseChange` so the engine's
  `(prior?, ack?)` / `(nil, ack?)` switch-arm `reason` copy and the
  `documentsUserPushback` predicate share the marker phrase in one
  place. A future copy edit in the engine forces the predicate to
  follow.
- New `documentsUserPushback: Bool` computed property. Pure
  function of `reason`; case-insensitive `range(of:)` match against
  the marker. Returns true on both the user-only `(nil, ack?)` arm
  ("User reported the prior hypothesis did not match what they
  saw; revising the read.") and the combined `(prior?, ack?)` arm
  ("Shifted focus from X to Y after the user reported the prior
  hypothesis did not match what they saw."). Returns false on the
  engine-only `(prior?, nil)` arm ("Shifted focus from X to Y.").
- New `isFresh(comparedTo memoryUpdatedAt:) -> Bool` predicate.
  `abs(changedAt.timeIntervalSince(memoryUpdatedAt)) <= 1.0`. Both
  `CoachCourseChange.changedAt` and `CoachMemory.updatedAt` are
  written from the same `now` in `CoachMemoryEngine.build(...)`, so
  equality holds across Codable round-trips. The 1-second tolerance
  is defensive against test fixtures that pass slightly-different
  `Date` instances (sub-millisecond precision differences). On
  every subsequent rep the entry persists in the bounded history
  but `isFresh` returns false — the card stays hidden after one
  rep, the long-term history surface is the Profile-tab
  `CaseReviewCard`.

### Track 2 — `RevisedReadCard` post-rep surface (`RevisedReadCard.swift`, new file)

- `struct RevisedReadCard: View` mirrors the existing
  `InterventionReviewPromptCard` shape: purple eyebrow + outer
  stroke + soft shadow. `AppColor.pro` accent so the card reads
  as a coach-voice surface (same accent as the review prompt and
  the `CoachReadCard` eyebrow).
- Two static pure-function copy generators so the strings can be
  locked by tests without standing up a SwiftUI view.
  `headlineCopy` is a constant; `bodyCopy(workingHypothesis:)`
  takes the memory's current hypothesis and returns
  `"Here's the revised read: <trimmed hypothesis>."` with the
  trailing `.` of the hypothesis stripped first so the line ends
  with exactly one period.
- Defensive fallbacks: a nil or whitespace-only `workingHypothesis`
  falls back to `"The coach noted it and is forming the next read."`
  so the card never renders an empty or `"Here's the revised
  read: ."` line. The store's persistence path always trims, but
  the Codable boundary could deliver a bad value; the fallback is
  unreachable in practice.
- No CTA, no countdown, no badge. The existing `TalkToNoumCTACard`
  sits a few rows below in the same `VStack` and already routes
  the user into Ask Noum with the session-anchored opener if they
  want to discuss the revised read in voice. Keeping the card
  read-only honours the restraint rules (`CaseReviewCard` is also
  read-only).
- Accessibility: card-level label combines headline + body so a
  screen reader reads the line as one continuous sentence. Identifier
  `summary.revisedRead.card` so a UI test can locate the surface
  without scraping the rendered text.

### Track 3 — `SummaryView` wiring (`SummaryView.swift`)

- New `freshRevisedReadChange: CoachCourseChange?` private computed
  property. Walks `coachMemoryStore.currentMemory?.adaptationLog
  ?.last`; returns the entry iff `documentsUserPushback` is true
  AND `isFresh(comparedTo: memory.updatedAt)` is true. Mirror of
  the existing `activeReviewDueIntervention` pattern — the view
  reads the property, the eligibility logic lives once.
- Card wired into both render sites:
  - IM/PREP path (line ~632): rendered immediately above
    `InterventionReviewPromptCard` when both surfaces fire on the
    same rep (rare but legal — a `.rejected` ack on a hypothesis
    whose intervention also reaches review cadence). The user
    reads the revised read first ("here's the new read"), then
    the review prompt ("let's verify it").
  - TIMED / Ah-Counter / Sudden Death path (line ~747): same
    placement immediately above `InterventionReviewPromptCard`.
- No state changes. The card mounts when `freshRevisedReadChange`
  becomes non-nil, unmounts on the next rep (when `isFresh`
  flips). The post-rep summary is rebuilt per rep; the eligibility
  check runs on every paint cycle.

### Track 4 — `CoachMemoryEngineTests` round-28 predicate suite (`NoumTests/NoumTests.swift`)

Six new `@Test` methods land in the existing `CoachMemoryEngineTests`
suite (immediately after the round-27 `buildTrimsLongRejectedSnapshotInEvidenceBasis`,
before the private helper functions). Independent fixtures — no
helpers borrowed from the round-27 suite.

- **`courseChangeDocumentsUserPushbackOnRejectionAck`.** The
  `(nil, ack?)` switch arm — user pushback rewrote the hypothesis
  text inside the same lever. Asserts `documentsUserPushback ==
  true`.
- **`courseChangeDocumentsUserPushbackOnCombinedShiftAndRejection`.**
  The `(prior?, ack?)` arm — both lever shifted AND the user
  rejected the prior hypothesis. Asserts `documentsUserPushback ==
  true` so the post-rep card fires on the combined branch too.
- **`courseChangeDoesNotDocumentUserPushbackOnEngineOnlyShift`.**
  The `(prior?, nil)` arm — engine inference only. Asserts
  `documentsUserPushback == false`. Pins the contract that the
  post-rep card never surfaces on a silent engine-inferred shift —
  only when the user themselves drove the change.
- **`courseChangeIsFreshWhenStampedAtMemoryUpdate`.** A change
  whose `changedAt == memory.updatedAt` (same `now`) reads as fresh.
- **`courseChangeIsNotFreshAcrossMultipleSessions`.** A change
  whose `changedAt` is 1000 seconds before `memory.updatedAt` (a
  carried-forward entry on a later rebuild) reads as stale.
- **`freshlyBuiltMemoryMarksRejectedAckEntryAsFreshAndPushback`.**
  End-to-end pin: a real `CoachMemoryEngine.build(...)` pass that
  folds a `.rejected` ack into a course-change entry produces an
  entry whose `documentsUserPushback == true` AND whose
  `isFresh(comparedTo: memory.updatedAt) == true`. Locks the
  contract the `RevisedReadCard` eligibility gate reads on the
  post-rep summary; if a future engine restructure shifts the
  `now` stamp on either side, this test catches it.

### Track 5 — `RevisedReadCardTests` copy suite (`NoumTests/NoumTests.swift`)

New top-level `@Suite("RevisedReadCardTests")` at the end of the
file. Five `@Test` methods pin the static pure-function copy:

- **`headlineCopyNamesUserAction`.** Asserts the headline reads
  `"You flagged the prior read as off."`. Pins the user-action
  clause so the card lands as an acknowledgement, not a generic
  "your plan changed" notification.
- **`bodyCopyQuotesRevisedHypothesisInline`.** Asserts the body
  begins with `"Here's the revised read: "` and contains the
  revised hypothesis text inline. Names what the coach updated to.
- **`bodyCopyStripsTrailingPeriodToAvoidDoubleStop`.** Asserts the
  body never contains `".."` (which would mean both periods landed
  side-by-side) and still ends with exactly one period.
  `workingHypothesis(lever:evidenceConfidence:)` always emits a
  clause ending with `.`; the card's wrapper adds another. The
  strip step keeps the line a single readable sentence.
- **`bodyCopyFallsBackWhenNoHypothesis`.** Asserts a nil hypothesis
  produces the fallback `"The coach noted it and is forming the
  next read."`.
- **`bodyCopyFallsBackWhenHypothesisIsBlank`.** Asserts a
  whitespace-only hypothesis takes the same fallback as nil so the
  card never renders `"Here's the revised read: ."`.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  the case formulation needs a "reason for changing course." Round
  27 landed the adaptation-log entry. Round 28 closes the loop by
  surfacing it to the user on the rep that drove the rebuild. The
  user sees that their pushback became case-file history, not a
  transient tap that disappeared into the void. A real coach
  acknowledges when the client pushes back ("okay, you flagged
  that — here's the revised read"); the post-rep card now lands
  that turn.
- **Pillar #5 (Personalized coaching).** A coach who silently
  revises a read without naming the pushback breaks the coaching
  contract. The card names the user's action ("You flagged the
  prior read as off.") so the revised read reads as a response to
  the user, not a system-driven plan change.
- **Pillar #4 (Believable progress).** The body quotes the actual
  revised `workingHypothesis` — the same clause the coach context
  block carries, the same one `CaseReviewCard` surfaces under
  "Working read". The user reads continuous voice across surfaces.
- **Anti-overclaim.** The card never claims the prior read was
  *wrong* — it says the user *flagged* it as off. Same restraint
  pattern the round-27 `evidenceBasis` carries ("user-tapped
  rejection of: …" rather than "the prior hypothesis was
  incorrect").
- **Anti-goal alignment (no hearts-and-lives gating).** The card
  doesn't block, punish, or celebrate. It's a quiet
  acknowledgement; the practice loop continues unchanged.

### Branch + redesign-alignment notes

- All five tracks land on `Redesign`, the redesign-lineage branch
  the rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." Round 28
  preserves the round-by-round loop on the redesign lineage.
- Round 28 does not change the round-27 engine restructure (the
  hoisted `newWorkingHypothesis`, `droppedRejectedAck`,
  `priorLeverShift` locals stay exactly as they were), does not
  change the round-26 chip catalog or `appliesTo(...)` guard, and
  does not change the round-24 / round-25 `InterventionReviewPromptCard`
  surface. The round-27 5-test additions remain unchanged; the
  round-28 6 engine-predicate tests + 5 copy tests sit alongside
  them. The existing 26-test review suite, 19-test ack suite,
  CoachMemoryStore tests, daily-budget tests, AIRateLimiter tests,
  IM-tone-drill tests, hero ribbon contract tests, and looking-ahead
  CTA contract tests all remain untouched.

## Future moves

(Updated priority list — round-28 closed the round-27 step #1; the
rest roll forward, plus a new note from round 28.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still
   blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried
   forward from rounds 19–27. Pure visual work, not destination
   logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from rounds 20–27. Pure visual work, not crossing logic.
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
    toward "met" or extend the `reviewDueAt` cadence.
11. **Reflect the revised read in the post-rep AI coach
    conversation seed.** New note from round 28. The
    `RevisedReadCard` surfaces the user-pushback line as a visual
    acknowledgement, but a tap on the existing `TalkToNoumCTACard`
    still dispatches the generic `sessionAnchoredOpener` rather
    than a revised-read-aware opener ("you flagged the prior read;
    here's where my updated read sits — anything to add?"). Pure-
    function lift on `CoachContextBuilder` similar to
    `interventionReviewOpener`. Would only fire when the same
    `freshRevisedReadChange` gate is true, so the conversation
    opener stays case-anchored on the rep that drove the rebuild.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so
nothing in this round was compiled or run — not the app, not the
test suite. The changes are:

- Two new derived properties on `CoachCourseChange`
  (PrimaryFocusMemory.swift), placed inside the existing struct
  next to the existing stored fields. The `userPushbackMarker`
  constant is a static let alongside.
- One new file `RevisedReadCard.swift` containing the
  `RevisedReadCard` SwiftUI view + two static copy generators.
  Same `#if canImport(SwiftUI)` / `@available(iOS 17.0, *)` /
  `AppColor.pro` / `Typography.captionSmall` / `CornerRadius.medium`
  conventions as the sibling `InterventionReviewPromptCard.swift`.
  The Xcode project uses `fileSystemSynchronizedGroups` so a new
  file in `Noum/` is automatically picked up — no project.pbxproj
  edit required.
- One new computed property + two new `RevisedReadCard(...)` call
  sites in SummaryView.swift. Both call sites land immediately
  above the existing `InterventionReviewPromptCard` conditional —
  no other layout changed.
- Six new `@Test` methods in `CoachMemoryEngineTests`, inserted
  after the existing `buildTrimsLongRejectedSnapshotInEvidenceBasis`
  test, before the private `ahCounterSession` helper.
- One new `@Suite("RevisedReadCardTests")` at the end of the file
  with five `@Test` methods. Marked `@available(iOS 17.0, *)` and
  `@MainActor` to match the view's annotations.

All checks the next agent should run on a real build host:

1. `swift test --filter CoachMemoryEngineTests` — the new round-28
   6 predicate tests should all pass, and the pre-28 tests (including
   the round-27 adaptation-log additions and the rest of the suite)
   should still pass.
2. `swift test --filter RevisedReadCardTests` — the new round-28
   5 copy-generator tests should all pass.
3. `swift test --filter HypothesisAcknowledgementTests` — the
   round-26 tests (19 total) should still pass. No round-26
   surface was changed.
4. `swift test --filter InterventionReviewPromptTests` — the
   round-24 + round-25 tests (26 total) should still pass.
5. `swift test --filter CoachMemoryStoreTests` — the existing
   memory-store tests should still pass (no schema change on
   `CoachCourseChange`).
6. `swift test --filter CoachReadCardDailyBudgetHintTests` —
   round-23 tests should still pass.
7. `swift test --filter AIRateLimiterPublicationTests` — round-22
   tests should still pass.
8. `swift test --filter IMToneDrillCrossingTests` — round-21
   helper tests should still pass.
9. `swift test --filter HeroScoreCardToneDrillRibbonContractTests`
   — round-20 ribbon-contract tests should still pass.
10. `swift test --filter LookingAheadCardStartCTAContractTests` —
    round-19 launch-CTA tests should still pass.
11. Boot the app on simulator, seed a
    `CoachMemory.activeIntervention` with a working hypothesis,
    open Ask Noum via the round-24 `InterventionReviewPromptCard`
    or the round-25 empty-state chip, wait for the coach reply,
    tap the **Adapt / rejected** ack chip. Then finish a new rep
    where either the lever changes OR the hypothesis text rewrites
    (e.g. `evidenceCount` crosses a `BaselineConfidence` threshold).
    Confirm on the post-rep summary screen:
    - `RevisedReadCard` renders immediately above
      `InterventionReviewPromptCard` (or alone if no review is
      due), with the purple-pro eyebrow + headline + body.
    - Headline reads "You flagged the prior read as off."
    - Body reads "Here's the revised read: <new hypothesis>."
      (single trailing period, no double dots).
    - Open Profile → `CaseReviewCard` "Last shift" row carries the
      same `reason` text the engine wrote.
    - Finish another rep WITHOUT a fresh `.rejected` ack — the
      `RevisedReadCard` must NOT re-render (the carried-forward
      entry is no longer fresh).
    - Repeat with a `.confirmed` or `.uncertain` ack across a
      hypothesis rewrite — the `RevisedReadCard` must NOT render
      (the entry is dropped by the snapshot guard but no
      adaptation-log entry is appended; `documentsUserPushback`
      stays false on whatever last entry exists).
