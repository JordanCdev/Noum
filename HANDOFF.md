# HANDOFF — M24 deferred slate (round 21): lift crossing-detection into `IMHistorySummary.toneDrillCrossing`

## Scope

Round 20 (the prior HANDOFF) closed "Future move" #1 — surfaced the
SOLVED win on the hero score card itself (not only in the post-rep
coach note prose) via a quiet IM-tinted capsule between the score ring
and the headline. Round 20's own "Future moves" list rolled the top
item forward:

> **Lift the crossing-detection helper into `IMHistorySummary`.** The
> "resolved now AND not resolved before" predicate now lives in two
> places — `PracticeSessionFinalizer.recordPostRepCoachNote` (note)
> and `SummaryView.heroToneDrillResolvedRibbon` (ribbon). Both must
> agree forever. A small static helper
> `IMHistorySummary.toneDrillCrossing(in:scenario:)` returning the
> crossed `IMToneDrillResolved?` would collapse both surfaces through
> one tested point — exactly the same hygiene move round 17 made for
> the `SummaryLookingAheadRouter`. Pure refactor, no UI surface, no
> device QA required. Could ship next round.

This push closes that item. The artifact a user can hold once compiled
is unchanged behaviorally — the same SOLVED ribbon on the hero card
and the same SOLVED-headlined sentence in the post-rep coach note
light up on the same crossing rep, exactly as round 20 shipped. What
changes is the *contract*: the with-vs-without-this-rep predicate now
lives in **one** tested place — `IMHistorySummary.toneDrillCrossing(
in:scenario:currentRepId:)` — instead of being repeated by two call
sites that must stay in lockstep. Pure refactor + 6 tests locking the
positive crossing path, the "already-solved-before stays quiet"
negative, the relapse-then-reclear positive, the stale-id defensive
negative, and order-independence across both call sites.

User brief, unchanged round to round: "continue from the existing
TO-DO, ensure working towards getting the app towards the vision
plan, and all round A+, make my dream I had come true too, ensure
working on the redesign branch too (very important)."

Translation, this round:

- Round 20 surfaced the SOLVED win in two coach surfaces — the prose
  note (round 14) and the hero ribbon (round 20). Both surfaces ran
  the same with-vs-without-this-rep comparison locally: the finalizer
  used `allSessions.filter { $0.id != session.id }`, the SummaryView
  used `Array(sessions.dropFirst())`. Two implementations of the same
  predicate; same primitive (`IMHistorySummary.toneDrillResolved(
  from:scenario:)`); two places one of them could silently drift if a
  copy-paste refactor touched only one. That kind of duplication is
  exactly what round 17 pulled out of the "Looking ahead" launch
  destination logic via `SummaryLookingAheadRouter`.
- The refactor lifts the comparison into a single static helper on
  `IMHistorySummary`. Both call sites become one-liner calls. The
  ordering difference (`filter { $0.id != id }` vs `dropFirst()`)
  collapses into one id-based filter the helper owns, so the
  SummaryView (store prepends the just-finalized rep) and the
  finalizer (`allSessions` is in insertion order) both pass arbitrary
  orderings without thinking about it.
- The helper keeps every other contract identical: the same
  `IMHistorySummary.toneDrillResolved(from:scenario:)` reads the
  before-and-after windows, the same `IMToneDrillResolved` value
  bubbles up unchanged, the same nil-when-no-crossing honesty
  contract holds. Nothing the user sees changes — but the next agent
  who wants to change *how* a crossing is detected (e.g. raise the
  hold bar, widen the window) only has to change one function and
  re-run one test struct.

## What shipped

### Track 1 — `IMHistorySummary.toneDrillCrossing` (`IMHistorySummary.swift`)

`Noum/IMHistorySummary.swift`:

- New static helper
  `toneDrillCrossing(in:scenario:currentRepId:matchRateThreshold:
  holdRate:)`. Placed immediately after the cross-scenario
  `toneDrillResolved(from:)` (line ~682) so the read primitives sit
  together — single-scenario `toneDrillResolved`, cross-scenario
  `toneDrillResolved`, then the crossing helper that composes both
  into a single-rep contract.
- Body:
  ```swift
  guard sessions.contains(where: { $0.id == currentRepId }) else { return nil }
  guard let resolvedNow = toneDrillResolved(
      from: sessions, scenario: scenario, ...
  ) else { return nil }
  let priorSessions = sessions.filter { $0.id != currentRepId }
  guard toneDrillResolved(
      from: priorSessions, scenario: scenario, ...
  ) == nil else { return nil }
  return resolvedNow
  ```
  Same `resolvedNow != nil && resolvedBefore == nil` shape both call
  sites used; the id-filter strips the just-finished rep by id
  instead of by position, so callers don't have to think about
  whether their session list is store-prepended or finalizer-appended.
- Same default threshold + hold-rate parameters as
  `toneDrillResolved(from:scenario:)` so a future call site that
  wants to swap the bars (e.g. a stricter SOLVED gate for an opt-in
  "high-confidence wins only" mode) gets the same API surface.
- Doc-comment names the contract explicitly:
  - **Why it exists** — two coach surfaces (post-rep note, hero
    ribbon) must light up on exactly one rep; routing both through
    one primitive makes that enforceable.
  - **What `sessions` must contain** — the just-finished rep
    (otherwise resolved-now and resolved-before are the same read).
  - **The four nil cases** — scenario hasn't crossed, scenario was
    already across, stale id (defensive: never invent a victory from
    a phantom rep), and the inherited "below the bar" cases the
    underlying `toneDrillResolved` already gates.

### Track 2 — finalizer call site through the helper (`PracticeSupport.swift`)

`Noum/PracticeSupport.swift`:

- `recordPostRepCoachNote` (line ~6628). Replaces the inline 4-line
  predicate (priorSessions filter + two `toneDrillResolved` calls +
  the `resolvedNow != nil && resolvedBefore == nil` gate) with a
  single `IMHistorySummary.toneDrillCrossing(in: allSessions,
  scenario: scenario, currentRepId: session.id)` call. Output
  unchanged: the same `imToneResolved` / `imToneResolvedScenarioTitle`
  / `imToneResolvedToneTitle` triple feeds the same
  `PostRepCoachNoteInput` constructor (line ~6649) the same way.
- Comment above the call updated to name the round-21 contract and
  point at the helper so the next reader doesn't have to re-derive
  why the comparison-by-id is correct.
- No behavior change. The post-rep note still headlines the SOLVED
  sentence on exactly the crossing rep, and stays quiet on every
  rep after.

### Track 3 — SummaryView ribbon call site through the helper (`SummaryView.swift`)

`Noum/SummaryView.swift`:

- `heroToneDrillResolvedRibbon` (line ~380). Replaces the inline
  4-line predicate (dropFirst priorSessions + two `toneDrillResolved`
  calls + the resolved-now / resolved-before guard) with a single
  `IMHistorySummary.toneDrillCrossing(in: sessionStore.sessions,
  scenario: scenario, currentRepId: currentRepId)` call. The view
  still resolves the just-finalized rep's id as
  `sessionStore.sessions.first?.id` (the store prepends), so the
  store-ordered list and the id are consistent at the call site, but
  the helper does the actual with-vs-without comparison.
- Doc-comment updated to name the round-21 contract: routes through
  the same primitive the post-rep coach-note uses, so the ribbon and
  the note can never drift apart.
- No behavior change. The SOLVED ribbon still renders on exactly the
  crossing rep, in IM purple-blue, just above the headline; the
  ribbon still doesn't render on non-IM reps, on already-resolved
  scenarios, or when IM Mode is unavailable.

### Track 4 — tests (`NoumTests/NoumTests.swift`)

6 new tests in a new `IMToneDrillCrossingTests` struct beneath
`IMToneDrillResolvedTests`:

- `crossingFiresOnTheRepThatClosesTheGap` — positive path. Five reps
  below the bar + a sixth rep that lands the tone. Calling the helper
  with the sixth rep's id returns the resolved read. Locks the
  primary positive: the helper *does* surface the crossing when the
  current rep is the one that pushed the scenario over.
- `crossingStaysQuietWhenAlreadyResolvedBefore` — the
  never-double-celebrate contract. Six reps that crossed + a
  seventh rep that also lands. Both resolved-now AND resolved-before
  are non-nil (sanity asserts pinned). Helper returns nil — the
  win was named on rep 6, rep 7 stays quiet.
- `crossingFiresAgainOnRelapseThenReclear` — honesty contract: a
  scenario that crossed, relapsed across three reps below the hold
  bar, then re-cleared with a tenth rep, reads as a *new* crossing.
  The user did genuinely re-close the gap; the helper surfaces it
  the same way the round-13 primitive does. Sanity asserts that the
  resolved-before reads nil (the relapse window pushed the latest
  3-rep window back below 60% hold) and resolved-now reads non-nil.
- `crossingNilWhenScenarioNeverCrossed` — primary negative. A
  scenario still firmly below the drill bar. Helper returns nil —
  the recommendation engine still owns this scenario, the SOLVED
  surfaces stay quiet.
- `crossingNilOnStaleRepId` — defensive contract. The same six-rep
  crossing history (whose cross-history resolved read is non-nil)
  but called with a freshly-generated `UUID()` that doesn't match
  any session. Helper returns nil — it never invents a victory from
  a phantom rep. Pinned with a sanity assert that the raw read IS
  resolved, so the stale-id gate is what's keeping the helper quiet.
- `crossingIsOrderIndependentAcrossCallSites` — the central refactor
  invariant. Build the same crossing history two ways: finalizer
  ordering (`priorReps + [crossingRep]`, insertion order) and store
  ordering (`[crossingRep] + priorReps`, latest-prepended). Both
  callers pass the *same* `currentRepId`. The helper returns the
  *same* `IMToneDrillResolved` value for both orderings (the equality
  pin reads `finalizerCrossing == storeCrossing`, exercising
  `IMToneDrillResolved`'s existing Equatable conformance — confirmed
  via `grep` of `PracticeSupport.swift:7191`). This is the test that
  guarantees the SummaryView and the finalizer route through the
  same primitive and produce the same answer.

### Vision alignment

- **Pillar #4 (Believable progress).** A SOLVED ribbon and a SOLVED
  prose headline that occasionally drift apart — different rep, or
  one fires and the other doesn't — is exactly the kind of credibility
  hole that erodes the user's trust in the rest of the coach voice.
  Routing both through one tested primitive makes drift impossible by
  construction, not by convention.
- **Pillar #5 (Personalized coaching).** A human coach who pushed you
  on your calm tone in Difficult Conversation for two weeks doesn't
  acknowledge the win twice — once in the chip, once in the prose,
  with subtly different timing. The single-source-of-truth helper
  keeps the two coach voices aligned on the same rep.
- **Coach-parity stage #4 (Adaptation).** The "explained rationale"
  for moving on from a drill IS the SOLVED moment. Centralizing the
  predicate makes the rationale auditable: one function, six tests,
  one place to change the bar if longitudinal usage shows the 60%
  hold rate is too lenient or too strict.
- **Round-17 hygiene precedent.** Same shape as the
  `SummaryLookingAheadRouter` lift round 17 did for the post-rep
  "Looking ahead" launch destination. Two surfaces that had to agree
  forever → one tested router both routed through. Round 21 applies
  the same template to the crossing-detection predicate.

### Branch + redesign-alignment notes

- All four edits land on `Redesign`, the redesign-lineage branch the
  rolling M24 deferred-slate work has been shipping on since round 11.
  The user brief explicitly calls this out: "ensure working on the
  redesign branch too (very important)." This round preserves the
  round-by-round loop on the redesign lineage. The draft PR tracking
  the redesign work into `main` picks up this round's changes
  automatically.
- The branch the agent runs on (`claude/clever-hypatia-lUbpe`) is
  merged forward into `Redesign` so the round-21 work lands on
  `Redesign` directly. No fork in the lineage.

## Future moves

(Updated priority list — round-20 "Future move" #1 closed this round;
the rest roll forward, plus one new item that drops out of the
refactor:)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked
   on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain
   interleaving with celebration timing. Worth a dedicated refactor
   pass with proper visual QA (and a real device).
3. **Rate-limiter live refresh.** Make `AIRateLimiter` an
   `ObservableObject` so the Settings AI-usage card AND the
   `CoachReadCard` daily-budget hint refresh mid-view. Low priority.
4. **Visual polish pass on the round-19 launch CTA.** Carried forward
   from rounds 19–20. Pure visual work, not destination logic — the
   router stays the single source of truth either way.
5. **Visual polish pass on the round-20 SOLVED ribbon.** Carried
   forward from round 20. The current capsule is the minimum-viable
   shape: IM-tinted, quiet, in register with the existing "Toward
   your <voice>" chip. A real-device read may want the capsule to
   grow into a full-width strip across the score ring, or stay a
   chip but gain a one-shot pulse animation on first render. Pure
   visual work, not crossing logic — the round-21 helper stays the
   single source of truth either way.
6. **NEW — extend the crossing helper to the chat-coach context
   line.** `CoachContextBuilder.toneDrillResolvedLines(for:)` (line
   ~679 of `CoachContextBuilder.swift`) currently calls the
   cross-scenario `IMHistorySummary.toneDrillResolved(from:)` — it
   reads "a scenario is currently solved", not "the just-finished
   rep crossed". For Ask Noum that's correct (the chat coach should
   know about all standing wins). But if a future chat-coach
   surface ever wants to read *only* "fresh crossings from this
   session", the helper is there to route through. Note for the
   record, not an action item.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing
in this round was compiled or run — not the app, not the test suite.
The changes are a pure refactor of the round-20 predicate into the
round-13 helper file:

- `IMHistorySummary.toneDrillCrossing` is a 12-line static helper
  composed of two calls to the existing `toneDrillResolved(
  from:scenario:)` (round 13) + one id-based filter + four guards.
  No new dependencies, no new types, no new storage. The
  `IMToneDrillResolved` return type is unchanged; the
  `IMConversationScenario` / `PracticeSession` parameter types are
  unchanged; the optional `matchRateThreshold` / `holdRate`
  parameters default to the same `toneDrillMatchRateThreshold` /
  `toneDrillResolvedHoldRate` constants the underlying
  `toneDrillResolved(from:scenario:)` uses.
- `PracticeSupport.swift:6628`-style call site collapses 11 lines of
  inline predicate into one helper call. The `imToneResolved` /
  `imToneResolvedScenarioTitle` / `imToneResolvedToneTitle` triple
  the `PostRepCoachNoteInput` constructor consumes is built the same
  way (same `scenario.title` and `crossed.targetTone.title`
  derivations) — verified by re-reading the constructor call at
  line ~6649 (no diff there).
- `SummaryView.swift:380`-style call site collapses 14 lines of
  inline predicate into one helper call. The view's existing
  `IMModeAvailability.isAvailable` guard, the `imConversationDetails
  != nil` guard, and the `if #available(iOS 17.0, *)` guard stay
  unchanged — those are presentation-layer gates the card needs, not
  crossing-detection logic.
- `IMToneDrillCrossingTests` (6 tests) mirror the
  `IMToneDrillResolvedTests` pattern byte-for-byte: same `imSession`
  builder, same `baseDate`, same scenario / tone constructions.
  The new `crossingIsOrderIndependentAcrossCallSites` test exercises
  `IMToneDrillResolved`'s Equatable conformance — confirmed via
  `grep "struct IMToneDrillResolved"` of `PracticeSupport.swift`
  (line 7191: `struct IMToneDrillResolved: Equatable`).

All checks the next agent should run on a real build host:

1. `swift test --filter IMToneDrillCrossingTests` — the 6 new tests
   should all pass.
2. `swift test --filter IMToneDrillResolvedTests` — the 12 existing
   crossing-primitive tests should still pass (the underlying
   `toneDrillResolved(from:scenario:)` is unchanged this round).
3. `swift test --filter PostRepCoachNoteToneResolvedTests` — the 5
   existing post-rep note crossing-contract tests should still pass
   (the finalizer's `imToneResolved` output is unchanged; only the
   internal computation routes through the helper).
4. `swift test --filter HeroScoreCardToneDrillRibbonContractTests` —
   the 6 round-20 ribbon-contract tests should still pass (the
   SummaryView's `heroToneDrillResolvedRibbon` output is unchanged;
   only the internal computation routes through the helper).
5. `swift test --filter LookingAheadCardStartCTAContractTests` — the
   6 round-19 launch-CTA tests should still pass (no card change
   this round).
6. Boot the app on simulator, run 6+ IM reps in the same scenario
   (e.g. Difficult Conversation with `Calm` tone), the first 3
   missing the tone, the latest 3 landing it. Confirm:
   - The SOLVED ribbon renders on the crossing rep's summary, just
     above the headline, in IM purple-blue.
   - The post-rep coach note on the same crossing rep also headlines
     the SOLVED sentence — both surfaces light up on the same rep,
     neither alone.
   - The ribbon does NOT render on the next rep after the crossing
     (the helper's "before == nil" gate keeps it quiet).
   - The ribbon does NOT render on non-IM reps (Timed / Sudden
     Death / Ah-Counter).
   - VoiceOver still reads "Solved · Calm tone in Difficult
     Conversation" (single combined label, no icon double-read).
