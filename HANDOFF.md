# HANDOFF — M24 deferred slate (round 39): case-anchored continuation through engine refinement — the durability complement to round 37's case-anchored amplification on the `.confirmed` branch. Pure-context surface, no engine state change, no schema bump, no view changes. New `CoachContextBuilder` predicate + context-line helper detects the (confirmed-rebuild + engine-only-refinement-on-top) state and surfaces ONE additional INTERVENTION CYCLE line telling the chat coach that the active intervention's read remains the user's previously-ratified rebuild and the engine has refined within that anchor, not replaced it.

## Scope

Round 37 lifted the `.confirmed`-branch case-anchored amplification onto the active intervention. Round 38 lifted the `.rejected`-branch dampening onto the same surface. Both predicates require the LATEST adaptation entry to document a user pushback (gate 4 in both); the round 37 amplification line goes dark the moment an engine-only refinement (a quiet lever adjustment the engine writes without a user pushback) lands on top of the user's confirmed rebuild — even though the user's ratification snapshot still applies to the working hypothesis and sits well within the 14-day recency window. The chat coach loses the case-anchoring signal on the first follow-on engine refinement.

That is a real coach-parity gap on stage #2 (Case formulation) and stage #4 (Adaptation). A human coach who heard a user ratify "pace is the focus" would not abandon that anchor the moment they noticed a small drift in the same direction; they would name the drift AS a refinement of the user-anchored read, not as a departure from it.

Round 39 closes the gap with the LIGHTEST possible surface: a new pure predicate + context-line helper on `CoachContextBuilder` that detects the (confirmed-rebuild + engine-only-refinement-on-top + ack-still-applies + within-recency) state and emits ONE additional INTERVENTION CYCLE line. Mutually exclusive with BOTH rounds 37 and 38 at the predicate level — orthogonal gates flip — so at most ONE of the three case-state lines (round 37 amplify / round 38 dampen / round 39 continue) fires per chat reply.

Defensive scoping (intentional restraint, same shape as rounds 37/38):

- **Pure context surface, not engine state change.** No engine-level amplification (e.g. extending the active intervention's `reviewDueAt`, lifting its `reviewStatus`). Round 39 keeps the impact bounded to the chat coach's context block — the same surface rounds 30–38 fan out across — so the new signal is testable in isolation and reversible if real-conversation evidence shows the line as off.
- **Recency-gated, pinned to rounds 37/38.** The user's confirmation within the round-37 recency window dampens; beyond that, the carrying intervention may have aged enough that today's engine-only refinements are no longer a continuation of the ratified read — the chat coach should fall back to the generic "Last course change" line. Round 39 reads the SAME constant (`caseAnchoredAmplificationRecencyDays`) as rounds 37/38 by deliberate cross-surface symmetry — all three windows close on the same day after the verdict.
- **Mutually exclusive with round 37 on the latest-entry-nature gate.** Round 37 requires `last.documentsUserPushback == true`; round 39 requires `last.documentsUserPushback == false`. `documentsUserPushback` is a single boolean at any point in time, so the two surfaces cannot BOTH fire on the same reply — pinned end-to-end by `userContextNeverSurfacesBothRound37AndRound39OnSameReply`.
- **Mutually exclusive with round 38 on the ack-confidence gate.** Round 38 requires `.rejected` ack AND `last.documentsUserPushback == true`. Round 39 requires `.confirmed` ack AND `last.documentsUserPushback == false`. Two orthogonal gates flip — round 39 is dark whenever round 38 fires and vice versa. Pinned by `userContextNeverSurfacesBothRound38AndRound39OnSameReply`.
- **Cross-surface contract with round 32.** Round 32 requires the LATEST entry to document a user pushback; round 39 requires it NOT to. So round 32 is DARK whenever round 39 fires — by construction. That is the point: round 32 names the rebuild-verdict EVENT (which fired on the prior user pushback rebuild and surfaced in the chat coach's context at that time); round 39 names the DURABLE case-anchoring state that survives the subsequent engine refinement, after round 32 has gone dark. The two are sequential on the timeline: pushback rebuild → round 32 + round 37 fire → engine refinement → round 32 + round 37 go dark, round 39 fires.
- **Cross-surface contract with round 31.** Round 31 (`freshRevisedReadContextLines`) also requires the LATEST entry to document a user pushback, so round 31 is dark whenever round 39 fires. The generic "Last course change" else-arm in `interventionCycleLines` is what surfaces the engine refinement as a course change; round 39 layers ON TOP of that line as the durable case-anchoring signal. The two layer cleanly: the generic line names the engine refinement; round 39 frames the active intervention's read as the user's previously-ratified rebuild that the engine has refined.

The mechanism is a pair of pure additions on `CoachContextBuilder`, structurally similar to round 37/38:

- `static func caseAnchoredContinuationApplies(in memory: CoachMemory, now: Date) -> Bool` — pure predicate dispatching on FIVE gates: (1) `.confirmed` ack carried, (2) ack `appliesTo` current hypothesis, (3) ack within recency window (reading `caseAnchoredAmplificationRecencyDays`), (4) latest adaptation entry is engine-only (`!documentsUserPushback`) AND post-dates the ack (`changedAt >= acknowledgedAt`), (5) there exists a prior user-pushback entry in the log pre-dating the ack (`documentsUserPushback && changedAt <= acknowledgedAt`). All five are pure reads on memory fields the engine already writes — no new persisted state, no schema bump.
- `static func caseAnchoredContinuationContextLine(memory: CoachMemory, now: Date) -> String?` — pure context-line helper. Returns ONE additional INTERVENTION CYCLE line when the predicate fires AND `memory.activeIntervention != nil`; returns `nil` otherwise. The line is the LIGHTEST possible surface: it names the engine refinement AND the user's previously-confirmed rebuild AND tells the model how to resolve the natural tension between two surfaces on the same reply (frame the refinement as complementing the ratified read, not departing from it).

The wiring layer is intentionally thin: `interventionCycleLines` now appends the continuation line at the END of the active-intervention block (right after the round-38 dampening call), so the new line reads as the natural closing qualifier when the latest entry is an engine refinement on top of the user's ratified rebuild.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure working towards getting the app towards the vision plan, and all round A+, make my dream I had come true too, ensure working on the redesign branch too (very important)."

Translation, this round:

- New `CoachContextBuilder.caseAnchoredContinuationApplies(in:now:)` static predicate — pure dispatch on the five gates. Placed in a dedicated `MARK: - Case-anchored continuation through engine refinement (round 39 — durability for round 37)` block immediately after the round-38 `interventionUnderRepeatedPushback` block so a future reader sees the round-37/38/39 case-state triplet (amplify / dampen / continue) as one coherent series.
- New `CoachContextBuilder.caseAnchoredContinuationContextLine(memory:now:)` static helper — pure context-line helper. Returns the continuation line when the predicate fires AND an active intervention exists; returns `nil` otherwise. Restraint pin: a future round that surfaces continuation copy OUTSIDE the active-intervention block must build a different helper rather than overload this one.
- Wiring update in `CoachContextBuilder.interventionCycleLines(...)` — the continuation line is appended at the END of the active-intervention block (right after the round-38 dampening call). The 9-line cap is unaffected (worst case stays at 8 because rounds 37, 38, and 39 are pairwise mutually exclusive at the predicate level — at most one of the three fires per reply).
- New `CaseAnchoredContinuationTests` suite (28 `@Test` methods + 7 private fixture helpers + 1 canonical-state factory — same canonical hypothesis + pushback shape as `CaseAnchoredAmplificationTests` / `InterventionUnderRepeatedPushbackTests`, with a NEW `engineOnlyChange` fixture whose `reason` does not contain the `userPushbackMarker` so `documentsUserPushback` returns false automatically) — pins the pure predicate on every branch, the pure helper, brand-voice compliance, mutual exclusion with rounds 37 and 38, cross-surface contracts with rounds 31 and 32, AND userContext integration tests covering the layered design (round 39 + generic "Last course change" coexist on the same reply; round 32 and round 31 are dark by construction).
- The redesign-branch invariant: this is a `Redesign`-branch push per the user brief. Round 39 preserves the round-by-round loop on the redesign lineage that has been the home of rounds 11–38.

## What shipped

### Track 1 — `CoachContextBuilder.caseAnchoredContinuationApplies(in:now:)` predicate (`Noum/CoachContextBuilder.swift`)

- New `static func caseAnchoredContinuationApplies(in memory: CoachMemory, now: Date) -> Bool` — pure dispatch on five gates:
  1. `memory.hypothesisAcknowledgement?.confidence == .confirmed`
  2. `ack.appliesTo(currentHypothesis: memory.workingHypothesis)`
  3. `now.timeIntervalSince(ack.acknowledgedAt) <= caseAnchoredAmplificationRecencyDays * 86400` — reuses the round-37 constant by deliberate cross-surface symmetry; no new constant.
  4. `memory.adaptationLog?.last?.documentsUserPushback == false` AND `lastChange.changedAt >= ack.acknowledgedAt` — the engine refinement post-dates the user's ratification.
  5. `memory.adaptationLog?.contains(where: { $0.documentsUserPushback && $0.changedAt <= ack.acknowledgedAt }) == true` — the structural anchor gate: there exists a USER-DRIVEN rebuild in the log pre-dating the ack.
- All five gates are pure reads on memory fields the engine already writes. Memories persisted before round 39 read `false` on the predicate automatically — no schema bump, no migration.
- Pinned by FIFTEEN predicate tests covering: happy path on canonical state, all three dark ack confidences (`.uncertain`/`.rejected`/no ack), snapshot stale, missing hypothesis, outside recency, exact recency boundary, latest-is-user-pushback dark, refinement-pre-dates-ack dark, refinement-at-ack-boundary inclusive, no-prior-user-pushback dark, nil/empty log, multiple-engine-refinements-after-ack happy path.

### Track 2 — `CoachContextBuilder.caseAnchoredContinuationContextLine(memory:now:)` helper (`Noum/CoachContextBuilder.swift`)

- New `static func caseAnchoredContinuationContextLine(memory: CoachMemory, now: Date) -> String?` — pure helper. Returns ONE context line (`"- Case-anchored continuation: the latest course change is an engine-only refinement applied on top of the user's previously-confirmed rebuild (still within the recency window); the active intervention's read remains the ratified rebuild, not a fresh exploration. Speak with quiet conviction on the carrying read. If you reference the latest course change, name how it complements the ratified read rather than replacing it; do not re-open the original."`) when the predicate fires AND an active intervention exists; returns `nil` otherwise.
- Brand-voice compliant: no `!`, no `"Let's"`/`"let's"`, no `" we "`, no `"sorry"`. Shame-adjacent words (`"failed"`/`"failure"`/`"wrong"`) are also pinned absent so the continuation reads as the user's anchor being carried forward, not as a punitive or hedging state. Mirrors the round-37/38 brand-voice rules so the continuation copy reads in the same register as the rest of the case-spine surfaces.
- Pinned by four helper tests (fires on happy path; dark when no active intervention; dark when predicate dark; behavioural contract on the line text — names BOTH halves of the continuation state AND the model's how-to-resolve-the-tension instruction) + a brand-voice test.

### Track 3 — wiring in `CoachContextBuilder.interventionCycleLines(...)` (`Noum/CoachContextBuilder.swift`)

- The continuation line is appended at the END of the active-intervention block (right after the round-38 dampening call), inside the existing `if includeActiveIntervention, let intervention = memory.activeIntervention { ... }` guard. Anchored against `memory.updatedAt` as the time origin (same anchor rounds 31, 37, 38 use) so the predicate is pure and locked by tests without standing up a real wall clock.
- The 9-line cap on `interventionCycleLines` is unaffected. The worst case stays at 8 because rounds 37, 38, and 39 are pairwise mutually exclusive at the predicate level. AND in the round-39 firing state, round 32 is dark BY CONSTRUCTION (round 32 requires `last.documentsUserPushback`, round 39 requires `!last.documentsUserPushback`), so the worst case in the round-39 branch is 6 lines (5 base intervention lines + 1 round-39 line), well under cap.

### Track 4 — `CaseAnchoredContinuationTests` suite (`NoumTests/NoumTests.swift`)

Twenty-eight new `@Test` methods inside a new `@MainActor @Suite("CaseAnchoredContinuationTests")` suite, slotted immediately after the existing `InterventionUnderRepeatedPushbackTests` suite (preserved `SecondCyclePushbackContextTests` follows). Seven private fixture helpers + 1 canonical-state factory (`rebuiltHypothesis`, `pushbackChange`, `engineOnlyChange`, `ack`, `sampleIntervention`, `memory`, `sampleProfile`, `canonicalContinuationState`) mirror the round-37/38 fixtures so the three symmetric suites that gate on the rebuild-then-verdict + engine-refinement shape share the same canonical fixture register.

- **Pure predicate — happy path (1 test):**
  - `predicateFiresOnCanonicalContinuationState` — pushback → confirmed → engine refinement, all five gates open.
- **Pure predicate — ack-confidence dark (3 tests):**
  - `predicateDarkOnUncertainAck` — `.uncertain` does not continue.
  - `predicateDarkOnRejectedAck` — `.rejected` does not continue (round 38 territory).
  - `predicateDarkWhenNoAckCarried` — no ack, no continuation.
- **Pure predicate — snapshot/applies dark (2 tests):**
  - `predicateDarkWhenAckSnapshotNoLongerApplies` — stale snapshot drops.
  - `predicateDarkWhenWorkingHypothesisIsNil` — defensive pin.
- **Pure predicate — recency (2 tests):**
  - `predicateDarkWhenAckIsOutsideRecencyWindow` — 15-day stale rejection drops.
  - `predicateFiresAtExactRecencyBoundary` — inclusive 14-day boundary mirrors rounds 37/38.
- **Pure predicate — latest-entry-nature dark (3 tests):**
  - `predicateDarkWhenLatestEntryIsUserPushback` — round 37 territory, round 39 drops.
  - `predicateDarkWhenLatestEngineRefinementPreDatesAck` — refinement before ack is round 37 territory.
  - `predicateFiresAtExactAckEqualsRefinementBoundary` — inclusive boundary on the `>= ack` ordering.
- **Pure predicate — prior-pushback gate (4 tests):**
  - `predicateDarkWhenNoPriorUserPushbackInLog` — `.confirmed` on engine-only baseline does NOT continue.
  - `predicateDarkOnNilAdaptationLog` — defensive pin.
  - `predicateDarkOnEmptyAdaptationLog` — defensive pin.
  - `predicateFiresWithMultipleEngineRefinementsAfterAck` — realistic multi-refinement happy path.
- **Pure context-line helper (4 tests):**
  - `contextLineFiresWhenPredicateAndActiveInterventionPresent` — happy path on the helper's return shape.
  - `contextLineDarkWhenNoActiveIntervention` — defensive pin; restraint rail against continuation copy without a carrying intervention.
  - `contextLineDarkWhenPredicateDark` — sanity pin.
  - `contextLineNamesEngineRefinementAndRatifiedAnchor` — behavioural contract on the line text.
- **Brand voice (1 test):**
  - `contextLineIsBrandVoiceCompliant` — pins `!`, `"Let's"`, `" we "`, `"sorry"`, `"failed"`, `"failure"`, `"wrong"` absence on the line.
- **Mutual exclusion (2 tests):**
  - `round37AndRound39AreMutuallyExclusiveOnLatestEntryNature` — branch A: latest pushback → round 37 may fire, round 39 dark. Branch B: latest engine refinement on prior pushback → round 39 fires, round 37 dark.
  - `round38AndRound39AreMutuallyExclusiveOnAckConfidence` — branch A: `.rejected` → round 38, round 39 dark. Branch B: `.confirmed` + engine-on-top → round 39, round 38 dark.
- **Cross-surface contracts (2 tests):**
  - `round32IsDarkWheneverRound39Fires` — structural pin on `rebuildVerdictPair(in:)` returning nil whenever round 39 fires.
  - `round31IsDarkWheneverRound39Fires` — structural pin on `freshRevisedReadChange(in:)` returning nil whenever round 39 fires.
- **userContext integration (4 tests):**
  - `userContextSurfacesContinuationLineInInterventionCycle` — full pipeline carries the line through the INTERVENTION CYCLE block.
  - `userContextDoesNotSurfaceContinuationWhenNoActiveIntervention` — pipeline drops the continuation line when no carrying intervention.
  - `userContextNeverSurfacesBothRound37AndRound39OnSameReply` — end-to-end mutual-exclusion pin on the latest-entry-nature axis.
  - `userContextNeverSurfacesBothRound38AndRound39OnSameReply` — end-to-end mutual-exclusion pin on the ack-confidence axis.
  - `userContextLayersContinuationOverGenericLastCourseChange` — locks the layered design end-to-end: round 39 + generic "Last course change" coexist; round 32 verdict line is dark.

### Vision alignment

- **Coach-parity stage #2 (Case formulation).** Per `docs/VISION.md`: the case formulation must retain "a concise, revisable understanding of the user's goal, blockers, strengths, pressure triggers, subjective experience, confidence and avoidance patterns, and upcoming moments". Round 37 lifted the user's confirmation into the chat-coach context block; round 39 ensures that lift SURVIVES the first engine-only refinement — the case formulation's ratified anchor remains visible to the chat coach across multiple chat replies even as the engine fine-tunes within the anchor.
- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the case formulation needs the durable signal that the new course is operating on the user's confirmed read. Rounds 27–38 named the rebuild + ratification + the durable case-anchoring on the user-pushback-rebuild surface; round 39 closes the symmetric durability gap on the engine-only-refinement surface — the chat coach no longer loses the case-anchoring signal the moment the engine refines.
- **Coach-parity stage #5 (Adaptation, anti-overclaim).** The continuation line is gated on five honest signals (confirmed ack, snapshot applies, within recency, engine-only refinement that POST-DATES the ack, prior user-pushback entry that PRE-DATES the ack). Engine-only refinements that pre-date the ack do NOT satisfy the predicate (round 37 territory). Engine-only baselines with no prior user pushback do NOT satisfy the predicate. The line says nothing about whether the continuation is correct, helpful, or final; it names the durable case-anchoring state on the predicate the engine already records.
- **Pillar #5 (Personalized coaching).** Rounds 32, 37, 38, and 39 now form one cross-surface lift on the rebuild-then-verdict pattern AND its engine-refinement durability: round 32 names the verdict event; round 37 names the durable case-anchoring state the `.confirmed` verdict establishes (while the latest entry is the user pushback); round 38 names the durable under-pushback state the `.rejected` verdict establishes (while the latest entry is the user pushback); round 39 names the durable case-anchoring state that survives the first engine refinement on top of the confirmed rebuild. The chat coach hears the coach-parity-grade signal on every reply for two weeks after the user lodges either verdict, AND that signal survives the first engine refinement.
- **Pillar #4 (Believable progress).** The continuation line is evidence-anchored — it cites the user's own confirmation AS WELL AS the engine's refinement as the basis for the continuation state, not an inference. The chat coach can name the engine refinement as a complement to the ratified read WITHOUT the model fabricating a "we're still figuring this out" hedge AND WITHOUT abandoning the user's anchor.
- **Anti-overclaim.** No engine state mutation, no `reviewStatus` lift, no schema bump, no migration. The continuation is a calm pure-context surface that signals the durable case-anchoring state; the persisted intervention's review status, success criterion, and review cadence are preserved verbatim. A future round can escalate to engine-level continuation (extending the active intervention's `reviewDueAt`; coalescing the engine-only refinement into the carrying intervention's lever sequence) once real-conversation evidence shows the context surface as insufficient.
- **Engineering bans.** No placeholder logic. No dead toggles. No fragmented state — the new predicate READS the existing `memory.hypothesisAcknowledgement`, `memory.workingHypothesis`, and `memory.adaptationLog` fields. No new storage, no schema bump, no migration, no new view inputs. Memories persisted before round 39 read `false` on the predicate and surface no continuation line automatically. Pure-function lift on pure-function inputs. The existing `caseAnchoredAmplificationApplies`, `caseAnchoredAmplificationContextLine`, `interventionUnderRepeatedPushbackApplies`, `interventionUnderRepeatedPushbackContextLine`, `rebuildVerdictPair`, `rebuildVerdictContextLines`, `freshRevisedReadChange`, `freshRevisedReadContextLines`, `coachCaseFormulationLines`, and `interventionCycleLines` paths are preserved verbatim (`interventionCycleLines` ONLY appends a new optional line at the end of the active-intervention block — no other modifications).

### Branch + redesign-alignment notes

- All four tracks land on `Redesign`, the redesign-lineage branch the rolling M24 deferred-slate work has been shipping on since round 11. The user brief explicitly calls this out: "ensure working on the redesign branch too (very important)." Round 39 preserves the round-by-round loop on the redesign lineage.
- Round 39 does not change any of the round-38 / round-37 / round-36 / round-35 / round-34 / round-33 / round-32 / round-31 / round-30 / round-29 / round-28 / round-27 / round-26 surfaces; every prior suite remains unchanged; the round-39 28 `CaseAnchoredContinuationTests` sit alongside them.

## Future moves

(Updated priority list — round 39 closed the case-anchored continuation gap that round 37 left open after its first-engine-refinement durability ceiling. The rest roll forward, plus one new note from round 39.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving with celebration timing. Worth a dedicated refactor pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from rounds 19–38. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from rounds 20–38. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.** Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward from round 22.
7. **Tier-change observation symmetry to other surfaces that read `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
8. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **Engine-level case-anchored amplification (post-round-37 escalation).** Carried forward from round 37 as a future move.
11. **Engine-level under-repeated-pushback dampening (post-round-38 escalation).** Carried forward from round 38 as a future move.
12. **Engine-level case-anchored continuation (post-round-39 escalation).** New note from round 39. If real-conversation evidence shows the round-39 context-line signal is insufficient, escalate to an engine-level continuation: extend the active intervention's `reviewDueAt` when the round-39 predicate fires (the engine's refinement is operating on a ratified read; the review can age out a little further). Same predicate as round 39; broader surface. Downstream impact on the post-rep `InterventionReviewPromptCard`, the Profile-tab `CaseReviewCard.interventionRow`, the AI prompt generator's `INTERVENTION CYCLE` block, and the post-rep summary — none of which can be QA'd without a real device. Restraint pin: do NOT escalate until real-conversation evidence shows the context-line surface as insufficient.
13. **Collapse the round-26 hypothesis-ack reflection in `coachCaseFormulationLines` into a single block with the round-32 rebuild-verdict lines when the predicate fires.** Carried forward from round 32. Hold for real-device QA.
14. **Trend-view distinction between "user accepted the first read", "user accepted the rebuilt read", "user accepted the rebuilt read AFTER pushing back", "user pushed back twice", "user pushed back twice and the dampening line surfaced", AND "engine refined within a user-ratified frame and the continuation line surfaced".** From round 30's step #11 + round 32's step #14 + round 33 + round 36 + round 37 + round 38, made richer by round 39. Round 39 strengthens the case further: the rebuild-verdict pair + engine-refinement durability now drives EIGHT distinct signal points (engine, post-rep card, chat-coach context block on confirmed branch, chat-coach context block on rejected branch, chat-coach context block on confirmed + engine-refined branch, chat seed, long-term Profile-tab history badge, active-intervention amplification + dampening + continuation surfaces).
15. **Second-cycle ask register on the opener.** Note from round 35. Restraint pin: hold until real conversations show the cycle-agnostic ask reads as off.
16. **`CaseReviewCard` adaptation-log fuller history surface.** Note from round 36. Hold for real-device QA.
17. **`CaseReviewCard` case-anchored badge.** Note from round 37. Hold for real-device QA.
18. **`CaseReviewCard` under-pushback badge.** Note from round 38. Hold for real-device QA.
19. **`CaseReviewCard` case-anchored continuation badge.** New note from round 39, the symmetric mirror of #17/#18 on the engine-refinement-durability branch. The Profile-tab `CaseReviewCard.interventionRow` could surface a small "continuation" capsule (or a "refined within anchor" qualifier) beside the "Active intervention" eyebrow when `caseAnchoredContinuationApplies(in:now:)` fires. The predicate is already lifted; the badge would be a pure visual addition gated on the same call. Restraint pin: hold for real-device QA — the active-intervention block's eyebrow is currently a calm single-row register, and the case-anchored continuation read is best validated in chat conversation before duplicating to the long-term history surface.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this round was compiled or run — not the app, not the test suite. The changes are:

- One new `static func caseAnchoredContinuationApplies(in:now:) -> Bool` and one new `static func caseAnchoredContinuationContextLine(memory:now:) -> String?` on `CoachContextBuilder` in `Noum/CoachContextBuilder.swift`. Single-expression / multi-statement bodies; pure functions of existing persisted fields. No new constants (the round-37 `caseAnchoredAmplificationRecencyDays` is reused by deliberate cross-surface symmetry).
- One additive call site in `CoachContextBuilder.interventionCycleLines(...)`: a `if let continuationLine = caseAnchoredContinuationContextLine(memory: memory, now: memory.updatedAt) { lines.append(continuationLine) }` block placed inside the existing active-intervention `if` block, immediately after the round-38 dampening call. Every other line in the function is preserved verbatim.
- Twenty-eight new `@Test` methods inside a new `@MainActor @Suite("CaseAnchoredContinuationTests")` suite and seven new private fixture helpers + 1 canonical-state factory, in `NoumTests/NoumTests.swift`. Slotted immediately after the existing `InterventionUnderRepeatedPushbackTests` suite so the round-37/38/39 case-state triplet reads as one block in the test file.

All checks the next agent should run on a real build host:

1. `swift test --filter CaseAnchoredContinuationTests` — the new round-39 28 tests should all pass.
2. `swift test --filter CaseAnchoredAmplificationTests` — round-37's 27 tests should still pass (round-39 reads round-37's constant but does not modify it).
3. `swift test --filter InterventionUnderRepeatedPushbackTests` — round-38's 32 tests should still pass.
4. `swift test --filter RebuildVerdictContextTests` — round-32's 25 tests should still pass (round 32 is dark by construction whenever round 39 fires; round 39's tests pin this).
5. `swift test --filter RevisedReadCardTests` — round-34's 14 tests should still pass.
6. `swift test --filter CaseReviewSecondCycleBadgeTests` — round-36's 8 tests should still pass.
7. `swift test --filter RevisedReadOpenerTests` — the round-29 + round-35 tests should still pass.
8. `swift test --filter RevisedReadFollowUpTests` — the round-30 + round-35 tests should still pass.
9. `swift test --filter SecondCyclePushbackContextTests` — round-33's 6 context-builder tests should still pass.
10. `swift test --filter CoachMemoryEngineTests` — round-33's engine tests + the older engine tests should all pass.
11. `swift test --filter FreshRevisedReadContextTests` — round-31's 16 tests should still pass.
12. `swift test --filter HypothesisAcknowledgementTests` — round-26's 19 tests should still pass.
13. `swift test --filter CoachMemoryStoreTests` — the existing memory-store tests should still pass.
14. Boot the app on simulator, drive a session through the round-26 hypothesis-ack chip (`.confirmed`) so the engine sets a `.confirmed` ack on the rebuilt working hypothesis. Drive another rep so memory rebuilds and the engine writes an engine-only refinement (no user pushback). The chat coach's user-context block should now carry the round-39 "Case-anchored continuation: ..." line in the INTERVENTION CYCLE block, alongside the generic "Last course change: ..." line. The round-32 verdict line and round-37 amplification line should BOTH be dark on this reply.
15. Wait 14+ days (or fast-forward `now`) and verify the continuation line drops while the engine refinement still surfaces through the generic line — the recency gate distinction.
16. Drive a `.uncertain` follow-up chip instead. Verify NEITHER round 37 NOR round 39 surfaces (the `.uncertain` ack is round 32's territory alone).
17. Drive a `.rejected` follow-up chip instead. Verify the round-38 dampening line surfaces and the round-39 continuation line does NOT — mutual exclusion at the predicate level on the ack-confidence axis.
18. Confirm the round-36 `CaseReviewCard` "Last shift" row's second-cycle badge, the round-34 post-rep `RevisedReadCard` second-cycle copy, the round-35 chat seed second-cycle copy, the round-37 case-anchored amplification line, the round-38 under-repeated-pushback dampening line, and all seven rounds' cross-surface contracts are preserved verbatim.
