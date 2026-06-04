# HANDOFF — M24 deferred slate (round 38): under-repeated-pushback dampening on the active intervention — the `.rejected`-branch mirror of round 37's case-anchored amplification. Pure-context surface, no engine state change, no schema bump, no view changes. New `CoachContextBuilder` predicate + context-line helper detects the pushback-then-reject-in-recency case state and surfaces ONE additional INTERVENTION CYCLE line telling the chat coach to slow down on follow-on reads, ask a focused discriminating question, and not re-prescribe the same intervention unchanged.

## Scope

Round 37 closed the FOURTH surface on the rebuild-then-confirm pattern (`CaseReviewCard` history badge → `RevisedReadCard` headline split → chat-seed lead split → chat-coach `caseAnchoredAmplification` line) — the `.confirmed` branch of the rebuild-verdict chip row, surfaced on the active intervention. The honest gap round 37 left open on the **`.rejected`** branch: when a user lodges a no-fit verdict on a rebuilt working hypothesis AFTER themselves pushing back on the prior read (the pushback-then-reject pattern), the chat coach should treat the active intervention as under repeated pushback — the user has now BOTH adapted away from the original read AND signalled the rebuilt one is also off, so the operating intervention is operating against TWO rejected reads in a row, not one. Without an explicit signal, the model speaks to follow-on reads as exploratory and may re-prescribe the same intervention against the next read.

Round 38 closes the symmetric coach-parity gap on the opposite confidence branch. The future-moves list from round 37 carries this as the natural mirror — round 37 named "the case file's hypothesis carries the user's own ratification, not just the engine's inference"; round 38 names "the active intervention is operating against the user's repeated pushback, not just the engine's last rebuild". The two are the symmetric anchors on the `.confirmed`/`.rejected` rebuild-verdict pair.

Round 38 lands the predicate, the context-line helper, the wiring after the round-37 amplification call, and pins it with thirty-one new tests in a new `@MainActor @Suite("InterventionUnderRepeatedPushbackTests")` suite. The surfacing is the LIGHTEST possible: ONE additional INTERVENTION CYCLE line, appended INSIDE the active-intervention block at the same call site as the round-37 amplification (mutually exclusive with it at the predicate level — confirmed XOR rejected ack — so the worst-case line count is unchanged from round 37).

Defensive scoping (intentional restraint, same shape as round 37):

- **Pure context surface, not engine state change.** A `.rejected`-branch engine-level lift (e.g. cancelling the active intervention or downgrading its `reviewStatus` to `adaptBeforeRepeating`) would cascade through the post-rep `InterventionReviewPromptCard`, the Profile-tab `CaseReviewCard.interventionRow`, the AI prompt generator, and the post-rep summary — none of which can be QA'd without a real device. Round 38 keeps the impact bounded to the chat coach's context block, the SAME surface rounds 30–37 fan out across, so the new signal is testable in isolation and reversible if real-conversation evidence shows the line as off.
- **Recency-gated, pinned to round 37.** The user's rejection within the last 14 days dampens; beyond that, the round-32 rebuild-verdict block carries the verdict signal without the dampening clause. The round-38 recency constant is pinned EQUAL to the round-37 amplification constant by a cross-surface test (`recencyWindowEqualsRound37AmplificationWindow`), so the two windows close on the same day after the verdict. Coaching parity stays symmetric on the two branches.
- **Mutually compatible with round 32, not overlapping.** Round 32 fires on every `.confirmed`/`.uncertain`/`.rejected` rebuild-verdict regardless of cycle history. Round 38 is a STRICTER subset of round 32 on the `.rejected` branch — round 38 implies round 32, but round 32 does not imply round 38 (round 32 fires on confirmed/uncertain acks too, and on rejections lodged outside the recency window). Both lines coexist on a rejected-rebuild-in-recency chat reply: round 32 names the verdict event; round 38 names the durable under-pushback state.
- **Mutually exclusive with round 37 at the predicate level.** The two predicates gate on `ack.confidence == .confirmed` (round 37) vs `ack.confidence == .rejected` (round 38). `confidence` is a single enum case at any point in time, so the two surfaces cannot BOTH fire on the same reply — pinned end-to-end by `userContextNeverSurfacesBothRound37AndRound38OnSameReply` (the rendered context carries one and only one of the two lines on every state).
- **Sequential with round 33, not overlapping.** Round 33's `freshRevisedReadContextLines` second-cycle branch fires AFTER the next engine rebuild folds the second-cycle pushback into the adaptation log (the chip-row ack is dropped). Round 38 fires BEFORE that rebuild — the chip-row ack is still carried. The two surfaces are sequential on the timeline (round 38 → engine rebuild → round 33), both naming the under-pushback state in their own window without duplicating it.

The mechanism is a pair of pure additions on `CoachContextBuilder`, structurally identical to round 37:

- `static let repeatedPushbackRecencyDays: Int = 14` — pure constant pinned by a brand-voice-style test AND by an equality test against `caseAnchoredAmplificationRecencyDays`. Lifted as a constant so a future tuning round lands in both windows together.
- `static func interventionUnderRepeatedPushbackApplies(in memory: CoachMemory, now: Date) -> Bool` — pure predicate dispatching on five gates: (1) `.rejected` ack carried, (2) ack `appliesTo` current hypothesis, (3) ack within recency window, (4) latest adaptation entry `documentsUserPushback`, (5) ack timestamp `>= changedAt` (ack post-dates the rebuild). All five are pure reads on memory fields the engine already writes — no new persisted state, no schema bump.
- `static func interventionUnderRepeatedPushbackContextLine(memory: CoachMemory, now: Date) -> String?` — pure context-line helper. Returns ONE additional INTERVENTION CYCLE line when the predicate fires AND `memory.activeIntervention != nil`; returns `nil` otherwise. The line is the LIGHTEST possible surface that signals the dampening state: it names both halves of the pushback-then-reject pattern AND tells the model to slow down, ask a discriminating question, and not re-prescribe the same intervention unchanged.

The wiring layer is intentionally thin: `interventionCycleLines` now appends the dampening line at the END of the active-intervention block (right after the round-37 amplification call), so the new line reads as the natural closing qualifier when the user's verdict has been `.rejected` instead of `.confirmed`.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure working towards getting the app towards the vision plan, and all round A+, make my dream I had come true too, ensure working on the redesign branch too (very important)."

Translation, this round:

- New `CoachContextBuilder.repeatedPushbackRecencyDays: Int = 14` constant — the recency horizon for the round-38 predicate, pinned by a regression-protection test AND by a cross-surface equality test against the round-37 constant. Placed in a dedicated `MARK: - Intervention under repeated pushback (round 38 — round-37 mirror on the .rejected branch)` block immediately after the round-37 `caseAnchoredAmplification` block so a future reader sees the `.confirmed`/`.rejected` symmetric pair as one coherent block — the layered design is documented in the inline comments, not just in code.
- New `CoachContextBuilder.interventionUnderRepeatedPushbackApplies(in:now:)` static predicate — pure dispatch on the five gates, exact mirror of the round-37 predicate on the `.rejected` branch.
- New `CoachContextBuilder.interventionUnderRepeatedPushbackContextLine(memory:now:)` static helper — pure context-line helper. Returns the dampening line when the predicate fires AND an active intervention exists; returns `nil` otherwise. Restraint pin: a future round that surfaces under-pushback copy OUTSIDE the active-intervention block must build a different helper rather than overload this one.
- Wiring update in `CoachContextBuilder.interventionCycleLines(...)` — the dampening line is appended at the END of the active-intervention block (right after the round-37 amplification call). The 9-line cap is unaffected (worst case stays at 8: 5 base intervention lines + 1 round-37-or-38 line + 2 round-32 verdict lines — round 37 and round 38 cannot both fire on the same reply).
- New `InterventionUnderRepeatedPushbackTests` suite (32 `@Test` methods + 7 private fixture helpers — same canonical hypothesis + pushback/engine-only shape as `CaseAnchoredAmplificationTests`) — pins the pure constants (2 tests: pure value + equality with round 37), the pure predicate on every branch (14 tests: happy path, `.confirmed`/`.uncertain` dark, no ack, snapshot stale, missing hypothesis, outside recency, exact recency boundary, engine-only latest change, nil/empty log, ack pre-dates rebuild, ack-at-rebuild-time boundary, mixed history `.last` read), the pure context-line helper (4 tests: fires when predicate + active intervention; dark when no intervention; dark when predicate dark; behavioural contract on the line text), brand-voice compliance (1 test, with shame-adjacent absence pins added to round-37's standard rails), FOUR cross-surface contracts with `rebuildVerdictPair` (round 38 implies round 32 on `.rejected`; round 32 alone fires without round 38 on `.confirmed`/`.uncertain`/outside-recency), THREE mutual-exclusion contracts with round 37 (`confirmed`/`rejected`/`uncertain` states each pinning the predicate pair), and FOUR userContext integration tests (full pipeline surfaces the dampening line; missing active intervention drops the dampening line but keeps round 32; round 32 and round 38 layer cleanly on the happy path; end-to-end pin that the rendered context never carries BOTH round-37 and round-38 lines on the same reply).
- The redesign-branch invariant: this is a `Redesign`-branch push per the user brief. Round 38 preserves the round-by-round loop on the redesign lineage that has been the home of rounds 11–37.

## What shipped

### Track 1 — `CoachContextBuilder.repeatedPushbackRecencyDays` constant (`Noum/CoachContextBuilder.swift`)

- New `static let repeatedPushbackRecencyDays: Int = 14`. Tuned to the same horizon as the round-37 amplification window so case-anchoring and under-pushback close on the same day after the verdict. Doc comment cites the cross-surface symmetry with the round-37 constant so a future reader understands the two recency windows are coordinated, not independently tunable.
- Pinned by `recencyWindowMatchesRound37Horizon` (pure value pin: `14`) AND by `recencyWindowEqualsRound37AmplificationWindow` (symmetry pin: `== caseAnchoredAmplificationRecencyDays`). A future copy edit that drifts one window without the other fails the symmetry test deliberately.

### Track 2 — `CoachContextBuilder.interventionUnderRepeatedPushbackApplies(in:now:)` predicate (`Noum/CoachContextBuilder.swift`)

- New `static func interventionUnderRepeatedPushbackApplies(in memory: CoachMemory, now: Date) -> Bool` — pure dispatch on five gates, exact mirror of round 37 on the `.rejected` branch:
  1. `memory.hypothesisAcknowledgement?.confidence == .rejected`
  2. `ack.appliesTo(currentHypothesis: memory.workingHypothesis)`
  3. `now.timeIntervalSince(ack.acknowledgedAt) <= repeatedPushbackRecencyDays * 86400`
  4. `memory.adaptationLog?.last?.documentsUserPushback == true`
  5. `ack.acknowledgedAt >= lastChange.changedAt`
- All five are pure reads on memory fields the engine already writes. Memories persisted before round 38 read `false` on the predicate automatically — no schema bump, no migration.
- Pinned by fourteen predicate tests (happy path, confirmed ack, uncertain ack, no ack, snapshot stale, missing hypothesis, outside recency, exact recency boundary, engine-only latest change, nil log, empty log, ack pre-dates rebuild, ack-at-rebuild-time boundary, mixed history `.last` read).

### Track 3 — `CoachContextBuilder.interventionUnderRepeatedPushbackContextLine(memory:now:)` helper (`Noum/CoachContextBuilder.swift`)

- New `static func interventionUnderRepeatedPushbackContextLine(memory: CoachMemory, now: Date) -> String?` — pure helper. Returns ONE context line (`"- Intervention under repeated pushback: the user has both pushed back on the original read AND lodged a no-fit verdict on the rebuilt working hypothesis above; treat the active intervention as under repeated pushback. Slow down on follow-on reads, ask one focused question that would discriminate the next read from the two the user has rejected, and do not re-prescribe the same intervention unchanged."`) when the predicate fires AND an active intervention exists; returns `nil` otherwise.
- Brand-voice compliant: no `!`, no `"Let's"`/`"let's"`, no `" we "`, no `"sorry"`. Shame-adjacent words (`"failed"`/`"failure"`/`"wrong"`) are also pinned absent so the rejection reads as the user steering the coach, not as a punitive state. Mirrors the round-32/33/34/35/36/37 brand-voice rules so the dampening copy reads in the same register as the rest of the case-spine surfaces.
- Pinned by four helper tests (fires on happy path; dark when no active intervention; dark when predicate dark; behavioural contract on the line text — names BOTH halves of the pushback-then-reject pattern AND the under-pushback treatment instruction AND the slow-down clause AND the discriminating-question clause AND the don't-re-prescribe instruction) + a brand-voice test (with three additional shame-adjacent absence pins on top of round-37's standard rails).

### Track 4 — wiring in `CoachContextBuilder.interventionCycleLines(...)` (`Noum/CoachContextBuilder.swift`)

- The dampening line is appended at the END of the active-intervention block (right after the round-37 amplification call), inside the existing `if includeActiveIntervention, let intervention = memory.activeIntervention { ... }` guard. Anchored against `memory.updatedAt` as the time origin (same anchor round 31 uses for `isFresh` and round 37 uses for its predicate) so the predicate is pure and locked by tests without standing up a real wall clock.
- The 9-line cap on `interventionCycleLines` is unaffected. The worst case stays at 8 because round 37 and round 38 are mutually exclusive at the predicate level: 5 base intervention lines + (1 round-37-or-38 line) + 2 round-32 verdict lines = 8, under cap. The three-tier course-change surface (round 32 → round 31 → generic) is preserved verbatim.

### Track 5 — `InterventionUnderRepeatedPushbackTests` suite (`NoumTests/NoumTests.swift`)

Thirty-two new `@Test` methods inside a new `@MainActor @Suite("InterventionUnderRepeatedPushbackTests")` suite, slotted immediately after the existing `CaseAnchoredAmplificationTests` suite (preserved `SecondCyclePushbackContextTests` follows). Seven private fixture helpers (`rebuiltHypothesis`, `pushbackChange`, `engineOnlyChange`, `ack`, `sampleIntervention`, `memory`, `sampleProfile`) mirror the round-37 `CaseAnchoredAmplificationTests` fixtures so the two symmetric suites that gate on the rebuild-then-verdict shape share the same canonical fixture register.

- **Pure constant (2 tests):**
  - `recencyWindowMatchesRound37Horizon` — pure value pin: `14`.
  - `recencyWindowEqualsRound37AmplificationWindow` — cross-surface symmetry pin: equality with `caseAnchoredAmplificationRecencyDays`.
- **Pure predicate (14 tests):**
  - `predicateFiresWhenRejectedAckPostDatesPushbackRebuildWithinWindow` — happy path on all five gates open.
  - `predicateDarkOnConfirmedAck` — no-regression contract; `.confirmed` (round-37 territory) does not dampen.
  - `predicateDarkOnUncertainAck` — no-regression contract; `.uncertain` (round-32 territory) does not dampen.
  - `predicateDarkWhenNoAckCarried` — no-regression contract; the round-31 window does not dampen.
  - `predicateDarkWhenAckSnapshotNoLongerApplies` — same case-spine contract as `rebuildVerdictPair` and round 37; stale snapshot drops.
  - `predicateDarkWhenWorkingHypothesisIsNil` — defensive pin.
  - `predicateDarkWhenAckIsOutsideRecencyWindow` — defensive pin on stale rejection (15 days past).
  - `predicateFiresAtExactRecencyBoundary` — edge case at exactly 14 days past; inclusive boundary, mirrors round 37.
  - `predicateDarkWhenLatestChangeIsEngineOnly` — defensive pin; an engine-only shift followed by `.rejected` does not dampen (the user did not push back on the prior read).
  - `predicateDarkOnNilAdaptationLog` — defensive pin.
  - `predicateDarkOnEmptyAdaptationLog` — defensive pin.
  - `predicateDarkWhenAckPreDatesRebuild` — same ordering contract as `rebuildVerdictPair` and round 37; stale ack drops.
  - `predicateFiresWhenAckExactlyAtRebuildTime` — edge case at `acknowledgedAt == changedAt`; inclusive boundary.
  - `predicateReadsLatestChangeOnly` — mixed history (earlier pushback, latest engine-only shift); predicate reads `.last` only.
- **Pure context-line helper (4 tests):**
  - `contextLineFiresWhenPredicateAndActiveInterventionPresent` — happy path on the helper's return shape.
  - `contextLineDarkWhenNoActiveIntervention` — defensive pin; restraint rail against dampening without a carrying intervention.
  - `contextLineDarkWhenPredicateDark` — sanity pin.
  - `contextLineNamesUnderPushbackStateAndDampeningInstruction` — behavioural contract on the line text.
- **Brand voice (1 test):**
  - `contextLineIsBrandVoiceCompliant` — pins `!`, `"Let's"`, `" we "`, `"sorry"`, `"failed"`, `"failure"`, `"wrong"` absence on the line. The three shame-adjacent additions are NEW relative to round-37's standard rails — round 38's signal is on a rejection event, so the calm/non-punitive framing is held more aggressively.
- **Cross-surface contract with round 32 (4 tests):**
  - `round38IsStricterSubsetOfRound32OnRejectedBranch` — locks the implication direction: round 38 → round 32 on `.rejected`.
  - `round32CanFireWithoutRound38WhenAckIsConfirmed` — reverse direction; round 32 does not imply round 38.
  - `round32CanFireWithoutRound38WhenAckIsUncertain` — reverse direction; `.uncertain` does not dampen.
  - `round32FiresOutsideRecencyButRound38Drops` — locks the recency-gate distinction.
- **Mutual exclusion with round 37 (3 tests):**
  - `round37AndRound38AreMutuallyExclusiveOnConfirmedAck` — `.confirmed` fires round 37, round 38 is dark.
  - `round37AndRound38AreMutuallyExclusiveOnRejectedAck` — `.rejected` fires round 38, round 37 is dark.
  - `round37AndRound38BothDarkOnUncertainAck` — `.uncertain` belongs to neither; both predicates dark together.
- **userContext integration (4 tests):**
  - `userContextSurfacesUnderPushbackLineInInterventionCycle` — full pipeline carries the line through the INTERVENTION CYCLE block.
  - `userContextDoesNotSurfaceUnderPushbackWhenNoActiveIntervention` — pipeline drops the dampening line but keeps the round-32 verdict line (since `rebuildVerdictContextLines` does NOT depend on an active intervention).
  - `userContextLayersRound32AndRound38LinesOnHappyPath` — locks the layered design end-to-end; both lines coexist.
  - `userContextNeverSurfacesBothRound37AndRound38OnSameReply` — end-to-end pin: the rendered context carries at most one of the two intervention-cycle additions on any chat reply.

### Vision alignment

- **Coach-parity stage #2 (Case formulation).** Per `docs/VISION.md`: the case formulation must carry "what improvement would look like before the user starts" + an explicit, revisable read of the user's confirmation state. Rounds 26–37 lifted the user's pushback and verdict into bounded coach memory across the engine, the post-rep card, the chat seed, the chat-coach context block, the long-term Profile-tab history, and the active-intervention amplification surface. Round 38 closes the symmetric `.rejected` branch: the chat coach now reads the under-repeated-pushback state on every reply for two weeks after the user rejects a rebuilt read.
- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the case formulation needs the reason for changing course AND the durable signal that the new course is operating against the user's repeated pushback. Rounds 27–37 named the rebuild + cycle distinction; round 38 names the durable under-pushback state that follows when the user REJECTS the rebuild. The chat coach can now dampen and seek a discriminating angle rather than re-prescribing the same intervention against another rejected read.
- **Coach-parity stage #5 (Adaptation, anti-overclaim).** The dampening line is gated on five honest signals (rejected ack, snapshot applies, within recency, prior rebuild was user-driven, ack post-dates rebuild). Engine-only lever shifts followed by a passive rejection do NOT satisfy the predicate — the user must have BOTH pushed back AND rejected. The line says nothing about whether the dampening is correct, helpful, or final; it names the under-pushback state on the predicate the engine already records.
- **Pillar #5 (Personalized coaching).** Rounds 32, 37, and 38 now form one cross-surface lift on the rebuild-then-verdict pattern: round 32 names the verdict event; round 37 names the durable case-anchoring state the `.confirmed` verdict establishes; round 38 names the durable under-pushback state the `.rejected` verdict establishes. The chat coach hears the coach-parity-grade signal on every reply for two weeks after the user lodges either verdict.
- **Pillar #4 (Believable progress).** The dampening line is evidence-anchored — it cites the user's own pushback AND rejection as the basis for the under-pushback state, not an inference. The chat coach can now slow down and discriminate WITHOUT the model fabricating a "we're still figuring this out" hedge.
- **Anti-overclaim.** No engine state mutation, no `reviewStatus` lift, no schema bump, no migration. The dampening is a calm pure-context surface that signals the under-pushback state; the persisted intervention's review status, success criterion, and review cadence are preserved verbatim. A future round can escalate to engine-level dampening (cancel-and-replace the active intervention; downgrade `reviewStatus` to `adaptBeforeRepeating`) once real-conversation evidence shows the context surface as insufficient.
- **Engineering bans.** No placeholder logic. No dead toggles. No fragmented state — the new predicate READS the existing `memory.hypothesisAcknowledgement`, `memory.workingHypothesis`, and `memory.adaptationLog` fields. No new storage, no schema bump, no migration, no new view inputs. Memories persisted before round 38 read `false` on the predicate and surface no dampening line automatically. Pure-function lift on pure-function inputs. The existing `caseAnchoredAmplificationApplies`, `caseAnchoredAmplificationContextLine`, `rebuildVerdictPair`, `rebuildVerdictContextLines`, `freshRevisedReadChange`, `freshRevisedReadContextLines`, `coachCaseFormulationLines`, and `interventionCycleLines` paths are preserved verbatim (`interventionCycleLines` ONLY appends a new optional line at the end of the active-intervention block — no other modifications).

### Branch + redesign-alignment notes

- All five tracks land on `Redesign`, the redesign-lineage branch the rolling M24 deferred-slate work has been shipping on since round 11. The user brief explicitly calls this out: "ensure working on the redesign branch too (very important)." Round 38 preserves the round-by-round loop on the redesign lineage.
- Round 38 does not change any of the round-37 / round-36 / round-35 / round-34 / round-33 / round-32 / round-31 / round-30 / round-29 / round-28 / round-27 / round-26 surfaces; every prior suite (round-37 27 `CaseAnchoredAmplificationTests`, round-36 8 `CaseReviewSecondCycleBadgeTests`, round-35 12 + 5 RevisedReadOpener + RevisedReadFollowUp tests, round-34 14 RevisedReadCard tests, round-33 6 engine + 6 context-builder tests, round-32 25 rebuild-verdict tests, round-31 16 fresh revised-read tests, round-30 15 follow-up tests, round-29 13 opener tests, round-28 5 copy tests, and round-26 19 ack tests) remains unchanged; the round-38 32 `InterventionUnderRepeatedPushbackTests` sit alongside them.

## Future moves

(Updated priority list — round 38 closed the `.rejected`-branch symmetric gap that round 37 left open after closing the `.confirmed` branch. The rest roll forward, plus one new note from round 38.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving with celebration timing. Worth a dedicated refactor pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from rounds 19–37. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from rounds 20–37. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.** Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward from round 22.
7. **Tier-change observation symmetry to other surfaces that read `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
8. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **Engine-level case-anchored amplification (post-round-37 escalation).** Carried forward from round 37 as a future move. If real-conversation evidence shows the round-37 context-line signal is insufficient, escalate to an engine-level `reviewStatus` lift on the `CoachIntervention` carrying the confirmed rebuild — same predicate, broader surface. Restraint pin: do NOT escalate until real-conversation evidence shows the context-line surface as insufficient.
11. **Engine-level under-repeated-pushback dampening (post-round-38 escalation).** New note from round 38, mirror of #10 on the `.rejected` branch. If real-conversation evidence shows the round-38 context-line signal is insufficient, escalate to an engine-level lift on the `CoachIntervention` carrying the rejected rebuild — downgrade `reviewStatus` to `adaptBeforeRepeating`, or cancel-and-replace the active intervention with a discriminating-mode prescription. Same predicate as round 38; broader surface. Downstream impact on the post-rep `InterventionReviewPromptCard`, the Profile-tab `CaseReviewCard.interventionRow`, the AI prompt generator's `INTERVENTION CYCLE` block, and the post-rep summary — none of which can be QA'd without a real device. Restraint pin: do NOT escalate until real-conversation evidence shows the context-line surface as insufficient.
12. **Collapse the round-26 hypothesis-ack reflection in `coachCaseFormulationLines` into a single block with the round-32 rebuild-verdict lines when the predicate fires.** Carried forward from round 32. Hold for real-device QA.
13. **Trend-view distinction between "user accepted the first read", "user accepted the rebuilt read", "user accepted the rebuilt read AFTER pushing back", "user pushed back twice", and "user pushed back twice and the dampening line surfaced".** From round 30's step #11 + round 32's step #14 + round 33 + round 36 + round 37, made richer by round 38. Round 38 strengthens the case further: the rebuild-verdict pair now drives SEVEN distinct signal points (engine, post-rep card, chat-coach context block on confirmed branch, chat-coach context block on rejected branch, chat seed, long-term Profile-tab history badge, active-intervention amplification AND dampening surfaces). A future analytics surface inherits SEVEN distinct signal points instead of one.
14. **Second-cycle ask register on the opener.** Note from round 35. The voice-shaped ask is currently cycle-agnostic by design. A future round, after real-device QA on second-cycle conversations, may want a cycle-aware ask register. Restraint pin: do NOT split the ask until real conversations show the cycle-agnostic ask reads as off; the simpler shared mapping is the better default.
15. **`CaseReviewCard` adaptation-log fuller history surface.** Note from round 36. A future round could lift the entire bounded adaptation log into an expandable surface (one row per entry, each carrying the same second-cycle badge when its `documentsSecondCyclePushback` fires). Restraint pin: do NOT lift until real-device QA confirms users want the lineage exposed.
16. **`CaseReviewCard` case-anchored badge.** Note from round 37, the symmetric mirror of round-36's second-cycle badge. The Profile-tab `CaseReviewCard.interventionRow` could read off the round-37 `caseAnchoredAmplificationApplies(in:now:)` predicate to surface a small "case-anchored" capsule beside the "Active intervention" eyebrow when the predicate fires. Restraint pin: hold for real-device QA — the active-intervention block's eyebrow is currently a calm single-row register, and the case-anchored read is best validated in chat conversation before duplicating to the long-term history surface.
17. **`CaseReviewCard` under-pushback badge.** New note from round 38, the symmetric mirror of #16 on the `.rejected` branch. The Profile-tab `CaseReviewCard.interventionRow` could surface a small "under pushback" capsule (or a "Slow down" qualifier) beside the "Active intervention" eyebrow when `interventionUnderRepeatedPushbackApplies(in:now:)` fires. The predicate is already lifted; the badge would be a pure visual addition gated on the same call. Restraint pin: same as #16 — hold for real-device QA. A `.rejected`-state visual qualifier on the long-term history surface is even more delicate than the `.confirmed` mirror because a dampening glyph alongside the active-intervention name could read as an indictment rather than as calm case state. The chat-coach context block is the right surface to validate this signal first.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this round was compiled or run — not the app, not the test suite. The changes are:

- One new `static let repeatedPushbackRecencyDays: Int = 14`, one new `static func interventionUnderRepeatedPushbackApplies(in:now:) -> Bool`, and one new `static func interventionUnderRepeatedPushbackContextLine(memory:now:) -> String?` on `CoachContextBuilder` in `Noum/CoachContextBuilder.swift`. Single-expression / single-statement bodies; pure functions of existing persisted fields.
- One additive call site in `CoachContextBuilder.interventionCycleLines(...)`: a `if let repeatedPushbackLine = interventionUnderRepeatedPushbackContextLine(memory: memory, now: memory.updatedAt) { lines.append(repeatedPushbackLine) }` block placed inside the existing active-intervention `if` block, immediately after the round-37 amplification call. Every other line in the function is preserved verbatim.
- Thirty-two new `@Test` methods inside a new `@MainActor @Suite("InterventionUnderRepeatedPushbackTests")` suite and seven new private fixture helpers, in `NoumTests/NoumTests.swift`. Slotted immediately after the existing `CaseAnchoredAmplificationTests` suite so the round-37 + round-38 symmetric pair reads as one block in the test file.

All checks the next agent should run on a real build host:

1. `swift test --filter InterventionUnderRepeatedPushbackTests` — the new round-38 32 tests should all pass.
2. `swift test --filter CaseAnchoredAmplificationTests` — round-37's 27 tests should still pass (round-38 reads round-37's `caseAnchoredAmplificationApplies` / `caseAnchoredAmplificationRecencyDays` but does not modify them).
3. `swift test --filter RebuildVerdictContextTests` — round-32's 25 tests should still pass (the round-38 cross-surface contract tests read through `rebuildVerdictPair(in:)` but do not modify it).
4. `swift test --filter RevisedReadCardTests` — round-34's 14 tests should still pass.
5. `swift test --filter CaseReviewSecondCycleBadgeTests` — round-36's 8 tests should still pass.
6. `swift test --filter RevisedReadOpenerTests` — the round-29 13 + round-35 12 tests should still pass.
7. `swift test --filter RevisedReadFollowUpTests` — the round-30 15 + round-35 5 tests should still pass.
8. `swift test --filter SecondCyclePushbackContextTests` — round-33's 6 context-builder tests should still pass.
9. `swift test --filter CoachMemoryEngineTests` — round-33's engine tests + the older engine tests should all pass.
10. `swift test --filter FreshRevisedReadContextTests` — round-31's 16 tests should still pass.
11. `swift test --filter HypothesisAcknowledgementTests` — round-26's 19 tests should still pass.
12. `swift test --filter CoachMemoryStoreTests` — the existing memory-store tests should still pass.
13. Boot the app on simulator, drive a session through the round-26 hypothesis-ack chip (`.rejected`) so the engine appends a first-cycle pushback entry. Finish a rep so memory rebuilds. Drive the round-30 follow-up chip row (`.rejected`) on the rebuilt read. The chat coach's user-context block should now carry BOTH the round-32 "Case file rebuild verdict: ... no-fit verdict ..." line AND the round-38 "Intervention under repeated pushback: ..." line in the INTERVENTION CYCLE block.
14. Drive another rep so memory rebuilds again. The ack should carry forward (the working hypothesis still applies), so the round-38 dampening line should still surface on every chat reply.
15. Wait 14+ days (or fast-forward `now`) and verify the dampening line drops while the round-32 verdict line persists — the recency gate distinction.
16. Drive a `.confirmed` follow-up chip on the rebuilt read instead. Verify the round-37 amplification line surfaces and the round-38 dampening line does NOT — mutual exclusion at the predicate level.
17. Drive a `.uncertain` follow-up chip on the rebuilt read. Verify NEITHER round-37 NOR round-38 surfaces (the round-32 "still settling" instruction handles the uncertain branch alone).
18. Confirm the round-36 `CaseReviewCard` "Last shift" row's second-cycle badge, the round-34 post-rep `RevisedReadCard` second-cycle copy, the round-35 chat seed second-cycle copy, the round-37 case-anchored amplification line, and all six rounds' cross-surface contracts are preserved verbatim.
