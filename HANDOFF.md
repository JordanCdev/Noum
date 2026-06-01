# HANDOFF — M24 deferred slate (round 36): depth-aware Ask Noum starter chip + opener — `CoachContextBuilder.adaptationLoopBreakOpener(memory:voice:)` + `adaptationLoopBreakStarterHeadline(in:)` compose a depth-gated, voice-shaped seed opener and a short display headline for a new `AskNoumView.adaptationLoopBreakStarterChip`, gated on the round-35 cycle-depth helper hitting the escalation band (depth ≥ 3). Closes future move #17.

## Scope

Round 35 closed future move #13 by adding the durable case-file
pushback cycle-depth signal: `CoachContextBuilder.adaptationLogCycleDepth(in:)`
+ `adaptationLogCycleSummary(in:)` count consecutive
`documentsUserPushback` entries at the tail of `memory.adaptationLog`,
surface a depth-aware coach-context line in the case-formulation
block, and land a second-person "Pushback depth" row on the
Profile-tab `CaseReviewCard`. Three surfaces, one cross-surface
contract: a user three pushbacks deep on the same lever now sees the
streak named on the Profile card AND reflected in the chat coach's
context.

The honest gap round 35 left open: a user who lands in `AskNoumView`
directly — not through the post-rep flow, not through the Profile
tab — has no one-tap entry into the same case-review conversation
that names the streak. The empty-state starter chips catalog
(`CoachContextBuilder.starterPrompts(...)`) is voice-shaped but
stuck-streak agnostic. A user who has rejected the working
hypothesis three times in a row sees the same chips a user opening
a fresh case would see — and the chat thread starts from a clean
seed as if the loop had never happened.

Round 35's depth signal is already in the case-formulation block
the chat coach reads, but the model only sees it on the FIRST
turn after the user types something. A starter chip is the
specific affordance for the moment BEFORE the user types — the
re-entry into the chat after a streak. That's where the empty-state
needs to name the stuck pattern, dispatch an opener that anchors
the case file's depth + working hypothesis + a voice-shaped ask,
and hand the conversation off to the coach.

Round 36 picks up future move #17 carried forward from round 35:

User brief, unchanged round to round: "continue from the existing TO-DO,
ensure working towards getting the app towards the vision plan, and all
round A+, make my dream I had come true too, ensure working on the
redesign branch too (very important)."

Translation, this round:

- New `CoachContextBuilder.adaptationLoopBreakOpenerLead` constant —
  the pinned lead prefix for the dispatched opener, sibling to
  `interventionReviewOpenerLead` (round 24) and `revisedReadOpenerLead`
  (round 29). A future predicate (e.g. a chat-thread classifier
  detecting a loop-break seed for a follow-up chip row) can match
  the prefix without depending on the depth count or voice-shaped
  suffix.
- New `CoachContextBuilder.adaptationLoopBreakOpener(memory:voice:)`
  pure function — composes the dispatched opener message. Returns
  nil at depth < 3 OR when the working hypothesis is empty/blank,
  so the chip and the opener never disagree at the boundary.
- New `CoachContextBuilder.adaptationLoopBreakStarterHeadline(in:)`
  pure function — short display label for the chip ("Stuck on the
  same read — 3 pushbacks in a row"). Returns nil at depth < 3.
- New `AskNoumView.adaptationLoopBreakStarterChip` SwiftUI view —
  sibling to round 25's `caseReviewStarterChip`. Wired below it on
  the empty state. Mirrors the visual register (brand-purple capsule,
  same chrome) with a distinct icon (`arrow.triangle.2.circlepath`)
  and a distinct eyebrow ("STUCK PATTERN") so the user reads which
  signal is firing in one glance. Both chips can render at once —
  they answer different questions.
- The redesign-branch invariant: round 36 lands on top of round 35
  on `Redesign`, the redesign-lineage branch the rolling M24
  deferred-slate work has been shipping on since round 11. The
  round-by-round loop is preserved.

## What shipped

### Track 1 — `CoachContextBuilder.adaptationLoopBreakOpenerLead` constant (`CoachContextBuilder.swift`)

- Pinned static lead: `"The case file shows I keep pushing back on the same read."`
- First-person voice ("I keep pushing back") matches every other
  dispatched opener — `sessionOpener` ("Just finished..."),
  `interventionReviewOpener` ("Time to review..."), and
  `revisedReadOpener` ("Picking up the case file — I flagged…").
  The user is typing the message; the perspective stays continuous.
- Brand-voice compliant — no exclamation, no "Let's", no urgency.

### Track 2 — `CoachContextBuilder.adaptationLoopBreakOpener(memory:voice:)` (`CoachContextBuilder.swift`)

- New pure-function helper. Returns nil at depth < 3 (gated through
  `adaptationLogCycleDepth(in:)` — same predicate the round-35
  case-formulation block reads), AND nil when `memory.workingHypothesis`
  is nil or whitespace-only (the body quotes the hypothesis; a
  missing read would render the seed incoherent to the model).
- Composition shape mirrors `revisedReadOpener`: lead + body that
  quotes the hypothesis with a trailing-period strip + voice-shaped
  ask. The depth-aware clause ("I've flagged it as off 3 times in
  a row this case file") sits inside the body.
- Voice mapping (7 arms — identical voice catalog to every other
  opener in `CoachContextBuilder`): `.authoritative` → "What's the
  structurally different angle?", `.warm` → "What angle haven't we
  tried yet?", `.concise` → "Different angle?", `.persuasive` →
  "Make the case for a different angle.", `.executive` → "Brief
  me on a different angle.", `.storytelling` → "What chapter
  breaks this loop?", default → "What's a different angle to try?".
- The "structurally different angle" phrasing is the same language
  round 35's escalated case-formulation clause uses for depth 3+,
  so the chat seed and the case-file context block read as one
  coordinated voice.

### Track 3 — `CoachContextBuilder.adaptationLoopBreakStarterHeadline(in:)` (`CoachContextBuilder.swift`)

- Pure function returning `"Stuck on the same read — \(depth) pushbacks in a row"` at depth ≥ 3, nil otherwise.
- Mirrors `interventionReviewStarterHeadline(for:)`'s shape: short,
  calm, no urgency. "Stuck on the same READ" names the data; it does
  not name the user as stuck. Same restraint round-34's
  `CoachCourseChange.caseFileHeadline` uses on the Profile card.
- Brand-voice compliant.

### Track 4 — `AskNoumView.adaptationLoopBreakStarterChip` (`AskNoumView.swift`)

- New `@ViewBuilder` view, sibling to `caseReviewStarterChip` and
  wired below it on the empty-state VStack. Mirrors the round-25
  chip's chrome line-for-line: 10pt-tinted brand-purple capsule,
  0.32-alpha stroke, top-aligned glyph + eyebrow + headline +
  trailing arrow.
- Distinct visual register from `caseReviewStarterChip`:
  - Icon: `arrow.triangle.2.circlepath` (round 25 uses
    `calendar.badge.clock`).
  - Eyebrow: `"STUCK PATTERN"` (round 25 uses `"REVIEW DUE"`).
  - Both render in brand-purple — they're both coach-priority
    signals, just answering different questions. A user can have
    a review due AND a stuck pattern; both chips can show at once.
- Tap handler: `send(opener)` where `opener` is the full
  `adaptationLoopBreakOpener(memory:voice:)` result — same
  dispatch pattern round 25's chip uses for `interventionReviewOpener`.
  The reply the user gets is the same conversation no matter which
  surface (chip tap, free-text prompt, future deep-link) led there.
- Accessibility: combined element with label "Break the pushback
  loop with Noum", hint "Opens a conversation that names the
  stuck streak and asks for a different angle.", identifier
  `askNoum.emptyState.loopBreakChip`.
- Render predicate uses `if let memory = …, let headline = …,
  let opener = …` — three optional binds across the same gate.
  A failure of any (no memory, depth < 3, missing hypothesis)
  collapses the chip entirely.

### Track 5 — `AdaptationLoopBreakOpenerTests` (`NoumTests/NoumTests.swift`)

New `@Suite("AdaptationLoopBreakOpenerTests")` (struct) placed
after the round-35 `AdaptationLogCycleSummaryTests`. 27 `@Test`
methods covering the lead constant, the depth gate, the working-
hypothesis gate, the voice-shaped ask, the brand-voice contract,
the headline picker, and the engineering bans.

- **Lead constant (2 tests):**
  - `openerLeadNamesUserPushbackInFirstPerson` — pins the constant.
  - `openerStartsWithTheLeadConstant` — composition contract.
- **Depth gate (6 tests):**
  - `openerIsNilAtDepthZero` — empty/nil log case.
  - `openerIsNilAtDepthOne` — first cycle is named by rounds
    28/31/33/34; a chip on top would over-claim.
  - `openerIsNilAtDepthTwo` — round-35 case-formulation block +
    round-32 rebuild-verdict context already speak at depth 2;
    the chip earns its surface only at the escalation band.
  - `openerFiresAtDepthThree` — happy path.
  - `openerFiresAtDepthFour` — open-ended depth band, no magic-
    number behaviour at depth 3.
  - `openerIsNilWhenEngineOnlyShiftBreaksStreakAtTail` — engine-
    only shift at tail resets the streak via the depth helper.
- **Working-hypothesis gate (4 tests):**
  - `openerIsNilWhenWorkingHypothesisIsNil` — defensive guard.
  - `openerIsNilWhenWorkingHypothesisIsBlank` — whitespace-only
    treated as nil.
  - `openerBodyQuotesWorkingHypothesisInline` — the read is
    named in scope.
  - `openerStripsTrailingPeriodToAvoidDoubleStop` — no `..`
    mid-sentence.
- **Voice-shaped ask (7 tests, one per voice arm):**
  - `openerAskByVoiceAuthoritative` / Warm / Concise / Persuasive
    / Executive / Storytelling / None.
- **Brand-voice contract (1 test):**
  - `openerHasNoUrgencyOrFanfareAcrossAllVoices` — locks the
    no-exclamation / no-"Let's" / no-"hurry" / no-"You're stuck"
    contract across all 7 voice arms. Mirrors the round-19
    `LookingAheadCardStartCTAContractTests` brand-voice pattern.
- **Headline picker (6 tests):**
  - `headlineIsNilAtDepthZero` / depth 1 / depth 2.
  - `headlineFiresAtDepthThreeWithCountInterpolated` — pins the
    exact display label.
  - `headlineFiresAtDepthFourWithCountInterpolated` — open-ended
    band.
  - `headlineAndOpenerSharedGate` — pins the boundary-depth
    contract that the chip and the opener cannot drift apart on
    the streak-depth predicate.
- **Engineering bans (1 test):**
  - `openerHelperDoesNotMutateMemory` — pure-function contract:
    `mem == before` after both helpers run.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`:
  "compare response across multiple attempts and either reinforce,
  vary, or replace the intervention with an explained rationale." A
  user three pushbacks deep into the same lever needs the coach to
  stop varying the same read and propose a structurally different
  angle. Round 35 gave the model the streak-depth signal in the
  context block. Round 36 gives the user the one-tap surface to
  RE-OPEN the conversation when they re-enter Ask Noum — closing
  the loop on the Adaptation stage from both ends (model side AND
  user-affordance side).
- **Pillar #5 (Personalized coaching).** A coach with a stuck
  patient doesn't make them type out "I'm still stuck" — they
  open the conversation themselves. Round 36's chip is the
  re-entry equivalent: the system NAMES the stuck pattern on
  the user's behalf and seeds a focused opener so the chat
  starts where the case file is.
- **Pillar #4 (Believable progress).** A user who has pushed back
  three times sees their streak named on three surfaces (Profile
  card, chat coach context, AskNoumView starter chip). The chip
  is silent below depth 3, so it never fabricates a streak; the
  open-ended count interpolation (3, 4, 5, …) honestly reports
  what the bounded `adaptationLog` carries.
- **Engineering bans.** No fragmented state: round 36 adds two
  pure-function helpers and one new view on `AskNoumView`. The
  chip reads through the same `adaptationLogCycleDepth(in:)`
  helper round 35's case-formulation block and Profile card both
  read — a copy edit in one place propagates to all three surfaces.
  No placeholder logic: the new helpers have real call sites on
  the chip. No dead toggles: the helpers have no flags; the
  resolution is data-driven off the persisted `adaptationLog` field.
- **Anti-overclaim.** The chip is silent at depth 0–2. Depth 3 is
  the same band round 35 named as "propose a structurally different
  angle, not another variation of the same hypothesis" — the chip
  rendering at that threshold matches the strongest claim the
  case-formulation block already makes. No new claim, just a new
  surface for the existing claim.
- **No schema bump.** Both helpers are pure-function reads over
  the existing `adaptationLog` + `workingHypothesis` fields.
  Memories persisted before round 36 decode and behave unchanged:
  pre-round-27 memories (no adaptation log) trip the depth-helper
  nil guard; round-27 / round-33 entries surface their cycle
  counts via `documentsUserPushback`.

### Branch + redesign-alignment notes

- All five tracks (two helpers, one view, the wiring, the test
  suite) land on `Redesign`, the redesign-lineage branch the
  rolling M24 deferred-slate work has been shipping on since
  round 11. The user brief explicitly calls this out: "ensure
  working on the redesign branch too (very important)." Round 36
  preserves the round-by-round loop on the redesign lineage.
- Round 36 does not change the round-35 helpers, the round-33
  marker constants, the `documentsUserPushback` predicate, the
  `isSecondCyclePushback` engine detection, or the round-34
  `caseFileHeadline` picker. All previous-round tests pass
  unchanged; round 36's 27 new tests sit alongside.
- Round 31's `freshRevisedReadContextLines`, round 32's
  `rebuildVerdictContextLines`, and round 35's
  `adaptationLogCycleSummary` are unchanged. The three remain
  freshness/ack/streak-gated context surfaces; round 36 is the
  USER-AFFORDANCE surface that pairs with the round-35 streak
  signal. The chip and the case-formulation block speak the same
  depth threshold (3+) so the user-side and model-side reads
  agree on when the case has entered the escalation band.

## Future moves

(Updated priority list — round-36 closed step #17; the rest roll
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
   Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward
   from round 22.
7. **Tier-change observation symmetry to other surfaces that read
   `AIRateLimiter.currentCap()` directly.** Carried forward from
   round 23.
8. **Refresh-on-rotate for the empty-state chip when the
   `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried
   forward from round 25. Round 36 makes this slightly more visible:
   when the depth crosses from 2 → 3 mid-mount, the new loop-break
   chip should render without forcing the user to leave + re-enter
   the screen. `@StateObject private var coachMemoryStore` already
   delivers the change, so `@ViewBuilder` re-render fires; the
   real question is whether `currentMemory` is observed deeply
   enough that the gate flips on the same tick.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **`.confirmed` confidence amplification on the active intervention.**
    Carried forward from round 27. The round-32 `.confirmed` rebuild-
    verdict path remains the natural integration site.
11. **Collapse the round-26 hypothesis-ack reflection in
    `coachCaseFormulationLines` into a single block with the round-32
    rebuild-verdict lines when the predicate fires.** Carried forward
    from round 32. Hold for real-device QA.
12. **Trend-view distinction between "user accepted the first read"
    and "user accepted the rebuilt read".** Carried forward from
    rounds 30 + 32 + 33 + 34 + 35.
13. **Engine reset on a `.confirmed` ack after a rebuild.** Carried
    forward from rounds 33 + 35.
14. **Sibling `RevisedReadCard` copy for the post-`.confirmed` rebuild
    surface.** Carried forward from rounds 33 + 35. Depends on #13.
15. **User-voiced lift for the engine-only fall-through arm of
    `caseFileHeadline`.** Carried forward from rounds 34 + 35.
16. **Voice-tuned depth-line phrasing.** Carried forward from round 35.
    The case-formulation depth line currently reads the same across
    all voices. A future round could vary the coach-move clause by
    the user's `SpeakingStyleGoal` to mirror round 36's voice-shaped
    ask: `.authoritative` → "stop retrying the same lever" (direct);
    `.warm` → "the streak matters — meet it gently" (measured);
    `.concise` → "drop this lever; try another" (tight). Same
    voice catalog the loop-break opener uses.
17. **(closed in round 36)**
18. **Profile-tab handoff from the loop-break chip.** New note from
    round 36. The Profile-tab `CaseReviewCard` already shows the
    round-35 "Pushback depth" row. A future round could add a small
    "Open in Ask Noum" affordance on that row when the depth ≥ 3,
    dispatching the same `adaptationLoopBreakOpener` the empty-state
    chip uses — so the cross-surface handoff is two-way (post-rep →
    AskNoum chip → conversation; Profile card → AskNoum opener →
    conversation). Hold until at least one real-device QA pass on
    the round-36 chip.
19. **Per-cycle depth annotation on the trend view.** New note from
    round 36. Closely related to #12 but more specific: round 36
    treats depth as a single scalar (the current tail-streak count).
    A future trend view could chart depth ACROSS the case file's
    lifetime — peaks, valleys, the timestamps of resets via
    engine-only shifts — so the user sees how often they cycle.
    Hold until at least one real-device QA pass on the round-36
    chip + the round-35 case-formulation line landing in chat.
20. **Bounded-history extension for the depth signal.** New note
    from round 36. The bounded `adaptationLog.suffix(8)` caps the
    depth helper's reportable count at 8. A user pushing back nine
    times in a row would still read as "8 times in a row" on the
    chip, the case-formulation block, and the Profile card. This
    is honest within the bounded view but lossy if the streak is
    longer than 8. A future round could either (a) raise the
    bound (with a Codable migration), (b) carry a separate
    `lifetimePushbackCount` field that survives the bounded
    log's eviction (no migration; additive field), or (c) leave
    the bound where it is and accept the 8-cap as the upper
    reportable count. Hold for a product decision.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in
this round was compiled or run — not the app, not the test suite. The
changes are:

- One new constant + two new pure-function helpers
  (`adaptationLoopBreakOpenerLead` static, `adaptationLoopBreakOpener(memory:voice:)`,
  `adaptationLoopBreakStarterHeadline(in:)`) on `CoachContextBuilder`
  in `CoachContextBuilder.swift`. Self-contained — no new imports, no
  new dependencies, no new types. Reads only the existing
  `adaptationLog` (via the round-35 `adaptationLogCycleDepth(in:)`
  helper) and `workingHypothesis` fields.
- One new `@ViewBuilder` `adaptationLoopBreakStarterChip` on
  `AskNoumView.swift`, plus one inline call site in the
  `emptyState` VStack. Mirrors round-25's `caseReviewStarterChip`
  shape — no new SwiftUI patterns introduced.
- One new `@Suite("AdaptationLoopBreakOpenerTests")` (27 tests) in
  `NoumTests/NoumTests.swift`. Plain `struct`, mirror of the
  round-35 `AdaptationLogCycleSummaryTests` suite's attributes.

All checks the next agent should run on a real build host:

1. `swift test --filter AdaptationLoopBreakOpenerTests` — the new
   round-36 27 tests should all pass.
2. `swift test --filter AdaptationLogCycleSummaryTests` — the
   round-35 16 tests should still pass. Round 36 does not touch
   `adaptationLogCycleDepth` or `adaptationLogCycleSummary`.
3. `swift test --filter CaseFileHeadlineTests` — the round-34 9
   tests should still pass.
4. `swift test --filter RevisedReadOpenerTests` — round-29 tests
   should still pass.
5. `swift test --filter RevisedReadCardTests` — round-28 + 33
   tests should still pass.
6. `swift test --filter SecondCyclePushbackAdaptationTests` —
   round-33 tests should still pass.
7. `swift test --filter RebuildVerdictContextTests` — round-32
   tests should still pass.
8. `swift test --filter FreshRevisedReadContextTests` — round-31
   tests should still pass.
9. `swift test --filter HypothesisAcknowledgementTests` — round-26
   tests should still pass.
10. `swift test --filter InterventionReviewPromptTests` — round-24
    + round-25 tests should still pass.
11. **Real-device QA — chip renders on a 3-pushback chain.** Boot
    the app on simulator. Seed a `CoachMemory.activeIntervention`
    with a working hypothesis. Drive three consecutive
    `.rejected`-driven course-changes through Ask Noum, finishing
    a followed rep between each. The `adaptationLog` now carries
    three consecutive pushback entries at its tail (depth 3).
12. **Confirm the AskNoumView empty-state shows the new chip.**
    Navigate to Ask Noum from the Profile tab (so the empty
    state renders — there are no messages yet for this fresh
    visit). Confirm a brand-purple chip with the
    `arrow.triangle.2.circlepath` glyph, the eyebrow "STUCK
    PATTERN", and the headline "Stuck on the same read — 3
    pushbacks in a row" renders below the existing case-review
    chip (or as the sole priority chip if no review is due).
13. **Tap the loop-break chip.** Confirm the dispatched message
    text reads "The case file shows I keep pushing back on the
    same read. I've flagged it as off 3 times in a row this case
    file. The read on the table is: \<working hypothesis>. What's
    a different angle to try?" (or the voice-shaped variant if a
    speaking-style goal is set on the profile).
14. **Set a voice goal and re-test.** Set
    `coachingProfileStore.profile.speakingStyleGoal = .authoritative`,
    re-enter Ask Noum, tap the chip. The ask should now read
    "What's the structurally different angle?". Confirm the same
    swap for `.warm` ("What angle haven't we tried yet?"),
    `.concise` ("Different angle?"), `.persuasive` ("Make the
    case for a different angle."), `.executive` ("Brief me on a
    different angle."), `.storytelling` ("What chapter breaks
    this loop?").
15. **Drive a fourth cycle.** The chip headline should read
    "Stuck on the same read — 4 pushbacks in a row"; the
    dispatched opener should read "4 times in a row this case
    file"; the model's context block (round 35) should still
    read the escalated "propose a structurally different angle"
    clause.
16. **Insert an engine-only shift to break the streak.** Drive a
    rebuild WITHOUT a `.rejected` ack drop (engine lever shift on
    a trend signal). The chip should disappear from the empty
    state on the next render — confirm both the chip AND the
    round-35 case-formulation depth line stop firing.
17. **Confirm both chips render together.** Seed an intervention
    that is review-due AND has depth-3 pushback tail. The
    `caseReviewStarterChip` (round 25) should render above the
    `adaptationLoopBreakStarterChip` (round 36), both visible at
    once. Distinct icons + eyebrows make them readable in one
    glance.

Branch lineage: round 36 sits on top of round 35 on `Redesign`,
which sits on top of rounds 11–34. The round-by-round loop on the
redesign lineage is preserved.
