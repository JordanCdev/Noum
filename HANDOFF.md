# HANDOFF — M24 deferred slate (round 40): under-pushback continuation through engine refinement — the dampening-durability complement to round 38 on the `.rejected` branch, structurally symmetric to round 39 on the `.confirmed` branch. Pure-context surface, no engine state change, no schema bump, no view changes. New `CoachContextBuilder` predicate + context-line helper detects the (rejected-rebuild + engine-only-refinement-on-top) state and surfaces ONE additional INTERVENTION CYCLE line telling the chat coach that the active intervention remains under the user's standing no-fit verdict — the engine has refined within that constraint, not closed it.

## Scope

Round 38 lifted the under-repeated-pushback dampening line onto the active intervention on the `.rejected` branch. Round 39 lifted the case-anchored continuation through engine refinement on the `.confirmed` branch — the durability complement to round 37 that survives the first engine-only refinement on top of a confirmed rebuild. Round 40 closes the symmetric durability gap on the `.rejected` branch: when the engine writes an engine-only refinement on top of a rejected rebuild, round 38's predicate drops AND the chat coach loses the under-pushback dampening signal, even though the user's rejection snapshot still applies to the working hypothesis and sits well within the recency window.

That is a real coach-parity gap on stage #4 (Adaptation) and stage #2 (Case formulation). A human coach who heard a user reject the rebuilt read would NOT silently treat the case as settled the moment they noticed a quiet engine lever drift; they would treat the user's rejection as the dominant signal, and name the drift AS a refinement OPERATING WITHIN the standing no-fit verdict, not as a resolution of it.

Round 40 closes the gap with the LIGHTEST possible surface: a new pure predicate + context-line helper on `CoachContextBuilder` that detects the (rejected-rebuild + engine-only-refinement-on-top + rejection-still-applies + within-recency) state and emits ONE additional INTERVENTION CYCLE line. Mutually exclusive with rounds 37, 38, AND 39 at the predicate level — at most ONE of the FOUR case-state lines (round 37 amplify / round 38 dampen / round 39 continue / round 40 under-pushback continue) fires per chat reply.

The four predicates now form one closed 2×2 matrix on (ack confidence) × (latest entry's nature):

```
                | latest = pushback     | latest = engine-only         |
--------------- | --------------------- | ---------------------------- |
.confirmed ack  | round 37 (amplify)    | round 39 (continuation)      |
.rejected ack   | round 38 (dampen)     | round 40 (under-pushback     |
                |                       |             continuation)    |
```

Defensive scoping (intentional restraint, same shape as rounds 37/38/39):

- **Pure context surface, not engine state change.** No engine-level dampening (e.g. extending the active intervention's `reviewDueAt`, downgrading its `reviewStatus`). Round 40 keeps the impact bounded to the chat coach's context block — the same surface rounds 30–39 fan out across — so the new signal is testable in isolation and reversible if real-conversation evidence shows the line as off.
- **Recency-gated, pinned to round 38.** The user's rejection within the round-38 recency window dampens; beyond that, the carrying intervention may have aged enough that today's engine-only refinements are no longer operating within a standing no-fit verdict — the chat coach should fall back to the generic "Last course change" line. Round 40 reads the SAME constant (`repeatedPushbackRecencyDays`) as round 38 by deliberate cross-surface symmetry — both `.rejected`-branch windows close on the same day after the verdict.
- **Mutually exclusive with round 38 on the latest-entry-nature gate.** Round 38 requires `last.documentsUserPushback == true`; round 40 requires `last.documentsUserPushback == false`. `documentsUserPushback` is a single boolean at any point in time, so the two surfaces cannot BOTH fire on the same reply — pinned end-to-end by `userContextNeverSurfacesBothRound38AndRound40OnSameReply`.
- **Mutually exclusive with round 39 on the ack-confidence gate.** Round 39 requires `.confirmed` ack; round 40 requires `.rejected` ack. `confidence` is a single enum case at any point in time, so the two predicates cannot both fire on the same memory. Pinned by `userContextNeverSurfacesBothRound39AndRound40OnSameReply`.
- **Mutually exclusive with round 37 on TWO axes** (ack confidence AND latest-entry nature). Two orthogonal gates flip. Pinned by `userContextNeverSurfacesBothRound37AndRound40OnSameReply`.
- **Cross-surface contract with round 32.** Round 32 requires the LATEST entry to document a user pushback; round 40 requires it NOT to. So round 32 is DARK whenever round 40 fires — by construction. That is the point: round 32 names the rebuild-verdict EVENT (which fired on the prior user pushback rebuild and surfaced in the chat coach's context at that time); round 40 names the DURABLE under-pushback state that survives the subsequent engine refinement, after round 32 has gone dark. The two are sequential on the timeline: pushback rebuild → `.rejected` ack → round 32 + round 38 fire → engine refinement → round 32 + round 38 go dark, round 40 fires.
- **Cross-surface contract with round 31.** Round 31 (`freshRevisedReadContextLines`) also requires the LATEST entry to document a user pushback, so round 31 is dark whenever round 40 fires. The generic "Last course change" else-arm in `interventionCycleLines` is what surfaces the engine refinement as a course change; round 40 layers ON TOP of that line as the durable under-pushback signal. The two layer cleanly: the generic line names the engine refinement; round 40 frames the active intervention as still under the user's standing no-fit verdict, which the engine has refined WITHIN, not resolved.

The mechanism is a pair of pure additions on `CoachContextBuilder`, structurally similar to round 39:

- `static func interventionUnderPushbackContinuationApplies(in memory: CoachMemory, now: Date) -> Bool` — pure predicate dispatching on FIVE gates: (1) `.rejected` ack carried, (2) ack `appliesTo` current hypothesis, (3) ack within recency window (reading `repeatedPushbackRecencyDays`), (4) latest adaptation entry is engine-only (`!documentsUserPushback`) AND post-dates the ack (`changedAt >= acknowledgedAt`), (5) there exists a prior user-pushback entry in the log pre-dating the ack (`documentsUserPushback && changedAt <= acknowledgedAt`). All five are pure reads on memory fields the engine already writes — no new persisted state, no schema bump.
- `static func interventionUnderPushbackContinuationContextLine(memory: CoachMemory, now: Date) -> String?` — pure context-line helper. Returns ONE additional INTERVENTION CYCLE line when the predicate fires AND `memory.activeIntervention != nil`; returns `nil` otherwise. The line is the LIGHTEST possible surface: it names the engine refinement AND the user's previously-rejected rebuild AND tells the model how to resolve the natural tension between two surfaces on the same reply (frame the refinement as operating within the standing no-fit verdict, not closing it; continue to dampen).

The wiring layer is intentionally thin: `interventionCycleLines` now appends the under-pushback continuation line at the END of the active-intervention block (right after the round-39 continuation call), so the new line reads as the natural closing qualifier when the latest entry is an engine refinement on top of the user's rejected rebuild.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure working towards getting the app towards the vision plan, and all round A+, make my dream I had come true too, ensure working on the redesign branch too (very important)."

Translation, this round:

- New `CoachContextBuilder.interventionUnderPushbackContinuationApplies(in:now:)` static predicate — pure dispatch on the five gates. Placed in a dedicated `MARK: - Under-pushback continuation through engine refinement (round 40 — durability for round 38)` block immediately after the round-39 `caseAnchoredContinuation` block so a future reader sees the round-37/38/39/40 case-state quadruplet as one coherent series.
- New `CoachContextBuilder.interventionUnderPushbackContinuationContextLine(memory:now:)` static helper — pure context-line helper. Returns the under-pushback continuation line when the predicate fires AND an active intervention exists; returns `nil` otherwise. Restraint pin: a future round that surfaces under-pushback continuation copy OUTSIDE the active-intervention block must build a different helper rather than overload this one.
- Wiring update in `CoachContextBuilder.interventionCycleLines(...)` — the under-pushback continuation line is appended at the END of the active-intervention block (right after the round-39 continuation call). The 9-line cap is unaffected (worst case stays at 8 because rounds 37, 38, 39, and 40 are pairwise mutually exclusive at the predicate level — at most one of the four fires per reply; AND in the round-40 firing state, round 32 is dark by construction, so the worst case in the round-40 branch is 6).
- New `InterventionUnderPushbackContinuationTests` suite (29 `@Test` methods + 7 private fixture helpers + 1 canonical-state factory — same canonical hypothesis + pushback shape as `CaseAnchoredAmplificationTests` / `InterventionUnderRepeatedPushbackTests` / `CaseAnchoredContinuationTests`, with the same `engineOnlyChange` fixture shape) — pins the pure predicate on every branch, the pure helper, brand-voice compliance, mutual exclusion with rounds 37, 38, AND 39, cross-surface contracts with rounds 31 and 32, AND userContext integration tests covering the layered design (round 40 + generic "Last course change" coexist on the same reply; round 32 and round 31 are dark by construction).
- The redesign-branch invariant: this is a `Redesign`-branch push per the user brief. Round 40 preserves the round-by-round loop on the redesign lineage that has been the home of rounds 11–39.

## What shipped

### Track 1 — `CoachContextBuilder.interventionUnderPushbackContinuationApplies(in:now:)` predicate (`Noum/CoachContextBuilder.swift`)

- New `static func interventionUnderPushbackContinuationApplies(in memory: CoachMemory, now: Date) -> Bool` — pure dispatch on five gates:
  1. `memory.hypothesisAcknowledgement?.confidence == .rejected`
  2. `ack.appliesTo(currentHypothesis: memory.workingHypothesis)`
  3. `now.timeIntervalSince(ack.acknowledgedAt) <= repeatedPushbackRecencyDays * 86400` — reuses the round-38 constant by deliberate cross-surface symmetry; no new constant.
  4. `memory.adaptationLog?.last?.documentsUserPushback == false` AND `lastChange.changedAt >= ack.acknowledgedAt` — the engine refinement post-dates the user's rejection.
  5. `memory.adaptationLog?.contains(where: { $0.documentsUserPushback && $0.changedAt <= ack.acknowledgedAt }) == true` — the structural anchor gate: there exists a USER-DRIVEN rebuild in the log pre-dating the ack.
- All five gates are pure reads on memory fields the engine already writes. Memories persisted before round 40 read `false` on the predicate automatically — no schema bump, no migration.
- Pinned by FIFTEEN predicate tests covering: happy path on canonical state, all three dark ack confidences (`.uncertain`/`.confirmed`/no ack), snapshot stale, missing hypothesis, outside recency, exact recency boundary, latest-is-user-pushback dark, refinement-pre-dates-ack dark, refinement-at-ack-boundary inclusive, no-prior-user-pushback dark, nil/empty log, multiple-engine-refinements-after-ack happy path.

### Track 2 — `CoachContextBuilder.interventionUnderPushbackContinuationContextLine(memory:now:)` helper (`Noum/CoachContextBuilder.swift`)

- New `static func interventionUnderPushbackContinuationContextLine(memory: CoachMemory, now: Date) -> String?` — pure helper. Returns ONE context line (`"- Intervention still under pushback: the latest course change is an engine-only refinement applied on top of the user's previously-rejected rebuild (still within the recency window); the active intervention remains under the user's no-fit verdict — the engine has refined within that constraint, not resolved it. Continue to slow down on follow-on reads, keep the one focused discriminating question on the table, and do not re-prescribe the same intervention unchanged. If you reference the latest course change, name how it operates within the standing no-fit verdict rather than closing it."`) when the predicate fires AND an active intervention exists; returns `nil` otherwise.
- Brand-voice compliant: no `!`, no `"Let's"`/`"let's"`, no `" we "`, no `"sorry"`. Shame-adjacent words (`"failed"`/`"failure"`/`"wrong"`) are also pinned absent so the under-pushback continuation reads as the user's standing verdict being respected, not as a punitive state. Mirrors the round-37/38/39 brand-voice rules so the under-pushback continuation copy reads in the same register as the rest of the case-spine surfaces.
- Pinned by four helper tests (fires on happy path; dark when no active intervention; dark when predicate dark; behavioural contract on the line text — names BOTH halves of the under-pushback continuation state AND the model's how-to-resolve-the-tension instruction) + a brand-voice test.

### Track 3 — wiring in `CoachContextBuilder.interventionCycleLines(...)` (`Noum/CoachContextBuilder.swift`)

- The under-pushback continuation line is appended at the END of the active-intervention block (right after the round-39 continuation call), inside the existing `if includeActiveIntervention, let intervention = memory.activeIntervention { ... }` guard. Anchored against `memory.updatedAt` as the time origin (same anchor rounds 31, 37, 38, 39 use) so the predicate is pure and locked by tests without standing up a real wall clock.
- The 9-line cap on `interventionCycleLines` is unaffected. The worst case stays at 8 because rounds 37, 38, 39, and 40 are pairwise mutually exclusive at the predicate level. AND in the round-40 firing state, round 32 is dark BY CONSTRUCTION (round 32 requires `last.documentsUserPushback`, round 40 requires `!last.documentsUserPushback`), so the worst case in the round-40 branch is 6 lines (5 base intervention lines + 1 round-40 line), well under cap.

### Track 4 — `InterventionUnderPushbackContinuationTests` suite (`NoumTests/NoumTests.swift`)

Twenty-nine new `@Test` methods inside a new `@MainActor @Suite("InterventionUnderPushbackContinuationTests")` suite, slotted immediately after the existing `CaseAnchoredContinuationTests` suite (preserved `SecondCyclePushbackContextTests` follows). Seven private fixture helpers + 1 canonical-state factory (`rebuiltHypothesis`, `pushbackChange`, `engineOnlyChange`, `ack`, `sampleIntervention`, `memory`, `sampleProfile`, `canonicalUnderPushbackContinuationState`) mirror the round-37/38/39 fixtures so the four symmetric suites that gate on the rebuild-then-verdict + engine-refinement shape share the same canonical fixture register.

- **Pure predicate — happy path (1 test):**
  - `predicateFiresOnCanonicalUnderPushbackContinuationState` — pushback → rejected → engine refinement, all five gates open.
- **Pure predicate — ack-confidence dark (3 tests):**
  - `predicateDarkOnUncertainAck` — `.uncertain` does not dampen.
  - `predicateDarkOnConfirmedAck` — `.confirmed` does not dampen (round 39 territory).
  - `predicateDarkWhenNoAckCarried` — no ack, no dampening.
- **Pure predicate — snapshot/applies dark (2 tests):**
  - `predicateDarkWhenAckSnapshotNoLongerApplies` — stale snapshot drops.
  - `predicateDarkWhenWorkingHypothesisIsNil` — defensive pin.
- **Pure predicate — recency (2 tests):**
  - `predicateDarkWhenAckIsOutsideRecencyWindow` — 15-day stale rejection drops.
  - `predicateFiresAtExactRecencyBoundary` — inclusive 14-day boundary mirrors rounds 38/39.
- **Pure predicate — latest-entry-nature dark (3 tests):**
  - `predicateDarkWhenLatestEntryIsUserPushback` — round 38 territory, round 40 drops.
  - `predicateDarkWhenLatestEngineRefinementPreDatesAck` — refinement before ack is round 38 territory.
  - `predicateFiresAtExactAckEqualsRefinementBoundary` — inclusive boundary on the `>= ack` ordering.
- **Pure predicate — prior-pushback gate (4 tests):**
  - `predicateDarkWhenNoPriorUserPushbackInLog` — `.rejected` on engine-only baseline does NOT dampen.
  - `predicateDarkOnNilAdaptationLog` — defensive pin.
  - `predicateDarkOnEmptyAdaptationLog` — defensive pin.
  - `predicateFiresWithMultipleEngineRefinementsAfterAck` — realistic multi-refinement happy path.
- **Pure context-line helper (4 tests):**
  - `contextLineFiresWhenPredicateAndActiveInterventionPresent` — happy path on the helper's return shape.
  - `contextLineDarkWhenNoActiveIntervention` — defensive pin; restraint rail against under-pushback continuation copy without a carrying intervention.
  - `contextLineDarkWhenPredicateDark` — sanity pin.
  - `contextLineNamesEngineRefinementAndRejectedRebuild` — behavioural contract on the line text.
- **Brand voice (1 test):**
  - `contextLineIsBrandVoiceCompliant` — pins `!`, `"Let's"`, `" we "`, `"sorry"`, `"failed"`, `"failure"`, `"wrong"` absence on the line.
- **Mutual exclusion (3 tests):**
  - `round37AndRound40AreMutuallyExclusive` — TWO orthogonal axes flip: ack confidence AND latest-entry nature.
  - `round38AndRound40AreMutuallyExclusiveOnLatestEntryNature` — branch A: latest pushback → round 38 may fire, round 40 dark. Branch B: latest engine refinement on prior pushback → round 40 fires, round 38 dark.
  - `round39AndRound40AreMutuallyExclusiveOnAckConfidence` — branch A: `.confirmed` + engine-on-top → round 39, round 40 dark. Branch B: `.rejected` + engine-on-top → round 40, round 39 dark.
- **Cross-surface contracts (2 tests):**
  - `round32IsDarkWheneverRound40Fires` — structural pin on `rebuildVerdictPair(in:)` returning nil whenever round 40 fires.
  - `round31IsDarkWheneverRound40Fires` — structural pin on `freshRevisedReadChange(in:)` returning nil whenever round 40 fires.
- **userContext integration (5 tests):**
  - `userContextSurfacesUnderPushbackContinuationLineInInterventionCycle` — full pipeline carries the line through the INTERVENTION CYCLE block.
  - `userContextDoesNotSurfaceUnderPushbackContinuationWhenNoActiveIntervention` — pipeline drops the under-pushback continuation line when no carrying intervention.
  - `userContextNeverSurfacesBothRound38AndRound40OnSameReply` — end-to-end mutual-exclusion pin on the latest-entry-nature axis.
  - `userContextNeverSurfacesBothRound39AndRound40OnSameReply` — end-to-end mutual-exclusion pin on the ack-confidence axis.
  - `userContextNeverSurfacesBothRound37AndRound40OnSameReply` — end-to-end mutual-exclusion pin across BOTH axes.
  - `userContextLayersUnderPushbackContinuationOverGenericLastCourseChange` — locks the layered design end-to-end: round 40 + generic "Last course change" coexist; round 32 verdict line is dark.

### Vision alignment

- **Coach-parity stage #2 (Case formulation).** Per `docs/VISION.md`: the case formulation must retain "a concise, revisable understanding of the user's goal, blockers, strengths, pressure triggers, subjective experience, confidence and avoidance patterns, and upcoming moments". Round 38 lifted the user's rejection into the chat-coach context block; round 40 ensures that lift SURVIVES the first engine-only refinement — the case formulation's standing no-fit verdict remains visible to the chat coach across multiple chat replies even as the engine fine-tunes within the constraint.
- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the case formulation needs the durable signal that the new course is operating under the user's standing no-fit verdict. Rounds 27–39 named the rebuild + ratification + the durable case-anchoring on the user-pushback-rebuild surface and its `.confirmed` durability complement; round 40 closes the symmetric durability gap on the `.rejected` engine-only-refinement surface — the chat coach no longer loses the under-pushback signal the moment the engine refines.
- **Coach-parity stage #5 (Adaptation, anti-overclaim).** The under-pushback continuation line is gated on five honest signals (rejected ack, snapshot applies, within recency, engine-only refinement that POST-DATES the ack, prior user-pushback entry that PRE-DATES the ack). Engine-only refinements that pre-date the ack do NOT satisfy the predicate (round 38 territory). Engine-only baselines with no prior user pushback do NOT satisfy the predicate. The line says nothing about whether the rejection is correct, helpful, or final; it names the durable under-pushback state on the predicate the engine already records.
- **Pillar #5 (Personalized coaching).** Rounds 32, 37, 38, 39, and 40 now form one cross-surface lift on the rebuild-then-verdict pattern AND its engine-refinement durability: round 32 names the verdict event; round 37 names the durable case-anchoring state the `.confirmed` verdict establishes (while the latest entry is the user pushback); round 38 names the durable under-pushback state the `.rejected` verdict establishes (while the latest entry is the user pushback); round 39 names the durable case-anchoring state that survives the first engine refinement on top of the confirmed rebuild; round 40 names the durable under-pushback state that survives the first engine refinement on top of the rejected rebuild. The chat coach hears the coach-parity-grade signal on every reply for two weeks after the user lodges either verdict, AND that signal survives the first engine refinement on BOTH branches.
- **Pillar #4 (Believable progress).** The under-pushback continuation line is evidence-anchored — it cites the user's own rejection AS WELL AS the engine's refinement as the basis for the under-pushback state, not an inference. The chat coach can name the engine refinement as operating within the standing no-fit verdict WITHOUT the model fabricating a "we've now resolved it" close AND WITHOUT abandoning the user's rejection.
- **Anti-overclaim.** No engine state mutation, no `reviewStatus` change, no schema bump, no migration. The under-pushback continuation is a calm pure-context surface that signals the durable dampening state; the persisted intervention's review status, success criterion, and review cadence are preserved verbatim. A future round can escalate to engine-level dampening (extending the active intervention's `reviewDueAt`; coalescing the engine-only refinement into the carrying intervention's lever sequence with a no-fit qualifier) once real-conversation evidence shows the context surface as insufficient.
- **Engineering bans.** No placeholder logic. No dead toggles. No fragmented state — the new predicate READS the existing `memory.hypothesisAcknowledgement`, `memory.workingHypothesis`, and `memory.adaptationLog` fields. No new storage, no schema bump, no migration, no new view inputs. Memories persisted before round 40 read `false` on the predicate and surface no under-pushback continuation line automatically. Pure-function lift on pure-function inputs. The existing `caseAnchoredAmplificationApplies`, `caseAnchoredAmplificationContextLine`, `interventionUnderRepeatedPushbackApplies`, `interventionUnderRepeatedPushbackContextLine`, `caseAnchoredContinuationApplies`, `caseAnchoredContinuationContextLine`, `rebuildVerdictPair`, `rebuildVerdictContextLines`, `freshRevisedReadChange`, `freshRevisedReadContextLines`, `coachCaseFormulationLines`, and `interventionCycleLines` paths are preserved verbatim (`interventionCycleLines` ONLY appends a new optional line at the end of the active-intervention block — no other modifications).

### Branch + redesign-alignment notes

- All four tracks land on `Redesign`, the redesign-lineage branch the rolling M24 deferred-slate work has been shipping on since round 11. The user brief explicitly calls this out: "ensure working on the redesign branch too (very important)." Round 40 preserves the round-by-round loop on the redesign lineage.
- Round 40 does not change any of the round-39 / round-38 / round-37 / round-36 / round-35 / round-34 / round-33 / round-32 / round-31 / round-30 / round-29 / round-28 / round-27 / round-26 surfaces; every prior suite remains unchanged; the round-40 29 `InterventionUnderPushbackContinuationTests` sit alongside them.
- The four case-state predicates (37/38/39/40) now form one closed 2×2 matrix on (ack confidence) × (latest entry's nature). Future work on the case-state surface should extend the matrix (e.g. by adding an `.uncertain`-branch dampening row when real-conversation evidence calls for it) rather than reshuffle the cells.

## Future moves

(Updated priority list — round 40 closed the under-pushback continuation gap that round 38 left open after its first-engine-refinement durability ceiling. The case-state 2×2 matrix on (ack confidence) × (latest entry's nature) is now closed. The rest roll forward, plus one new note from round 40.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving with celebration timing. Worth a dedicated refactor pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from rounds 19–39. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from rounds 20–39. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.** Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward from round 22.
7. **Tier-change observation symmetry to other surfaces that read `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
8. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **Engine-level case-anchored amplification (post-round-37 escalation).** Carried forward from round 37 as a future move.
11. **Engine-level under-repeated-pushback dampening (post-round-38 escalation).** Carried forward from round 38 as a future move.
12. **Engine-level case-anchored continuation (post-round-39 escalation).** Carried forward from round 39 as a future move.
13. **Engine-level under-pushback continuation dampening (post-round-40 escalation).** New note from round 40. If real-conversation evidence shows the round-40 context-line signal is insufficient, escalate to an engine-level dampening: extend the active intervention's `reviewDueAt` when the round-40 predicate fires (the engine's refinement is operating under a standing no-fit verdict; the review should wait for the user to weigh in again rather than aging out on the engine's quiet drift). Same predicate as round 40; broader surface. Downstream impact on the post-rep `InterventionReviewPromptCard`, the Profile-tab `CaseReviewCard.interventionRow`, the AI prompt generator's `INTERVENTION CYCLE` block, and the post-rep summary — none of which can be QA'd without a real device. Restraint pin: do NOT escalate until real-conversation evidence shows the context-line surface as insufficient.
14. **Collapse the round-26 hypothesis-ack reflection in `coachCaseFormulationLines` into a single block with the round-32 rebuild-verdict lines when the predicate fires.** Carried forward from round 32. Hold for real-device QA.
15. **Trend-view distinction between "user accepted the first read", "user accepted the rebuilt read", "user accepted the rebuilt read AFTER pushing back", "user pushed back twice", "user pushed back twice and the dampening line surfaced", "engine refined within a user-ratified frame and the continuation line surfaced", AND "engine refined within a user-rejected frame and the under-pushback continuation line surfaced".** From round 30's step #11 + round 32's step #14 + round 33 + round 36 + round 37 + round 38 + round 39, made richer by round 40. Round 40 strengthens the case further: the rebuild-verdict pair + engine-refinement durability now drives NINE distinct signal points (engine, post-rep card, chat-coach context block on confirmed branch, chat-coach context block on rejected branch, chat-coach context block on confirmed + engine-refined branch, chat-coach context block on rejected + engine-refined branch, chat seed, long-term Profile-tab history badge, active-intervention amplification + dampening + continuation + under-pushback-continuation surfaces).
16. **Second-cycle ask register on the opener.** Note from round 35. Restraint pin: hold until real conversations show the cycle-agnostic ask reads as off.
17. **`CaseReviewCard` adaptation-log fuller history surface.** Note from round 36. Hold for real-device QA.
18. **`CaseReviewCard` case-anchored badge.** Note from round 37. Hold for real-device QA.
19. **`CaseReviewCard` under-pushback badge.** Note from round 38. Hold for real-device QA.
20. **`CaseReviewCard` case-anchored continuation badge.** Note from round 39. Hold for real-device QA.
21. **`CaseReviewCard` under-pushback continuation badge.** New note from round 40, the symmetric mirror of #20 on the engine-refinement-durability branch of the `.rejected` axis. The Profile-tab `CaseReviewCard.interventionRow` could surface a small "still under pushback" capsule (or a "refined within no-fit verdict" qualifier) beside the "Active intervention" eyebrow when `interventionUnderPushbackContinuationApplies(in:now:)` fires. The predicate is already lifted; the badge would be a pure visual addition gated on the same call. Restraint pin: hold for real-device QA — the active-intervention block's eyebrow is currently a calm single-row register, and the under-pushback continuation read is best validated in chat conversation before duplicating to the long-term history surface.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this round was compiled or run — not the app, not the test suite. The changes are:

- One new `static func interventionUnderPushbackContinuationApplies(in:now:) -> Bool` and one new `static func interventionUnderPushbackContinuationContextLine(memory:now:) -> String?` on `CoachContextBuilder` in `Noum/CoachContextBuilder.swift`. Single-expression / multi-statement bodies; pure functions of existing persisted fields. No new constants (the round-38 `repeatedPushbackRecencyDays` is reused by deliberate cross-surface symmetry).
- One additive call site in `CoachContextBuilder.interventionCycleLines(...)`: a `if let underPushbackContinuationLine = interventionUnderPushbackContinuationContextLine(memory: memory, now: memory.updatedAt) { lines.append(underPushbackContinuationLine) }` block placed inside the existing active-intervention `if` block, immediately after the round-39 continuation call. Every other line in the function is preserved verbatim.
- Twenty-nine new `@Test` methods inside a new `@MainActor @Suite("InterventionUnderPushbackContinuationTests")` suite and seven new private fixture helpers + 1 canonical-state factory, in `NoumTests/NoumTests.swift`. Slotted immediately after the existing `CaseAnchoredContinuationTests` suite so the round-37/38/39/40 case-state quadruplet reads as one block in the test file.

All checks the next agent should run on a real build host:

1. `swift test --filter InterventionUnderPushbackContinuationTests` — the new round-40 29 tests should all pass.
2. `swift test --filter CaseAnchoredContinuationTests` — round-39's 28 tests should still pass.
3. `swift test --filter CaseAnchoredAmplificationTests` — round-37's 27 tests should still pass.
4. `swift test --filter InterventionUnderRepeatedPushbackTests` — round-38's 32 tests should still pass (round-40 reads round-38's constant but does not modify it).
5. `swift test --filter RebuildVerdictContextTests` — round-32's 25 tests should still pass (round 32 is dark by construction whenever round 40 fires; round 40's tests pin this).
6. `swift test --filter RevisedReadCardTests` — round-34's 14 tests should still pass.
7. `swift test --filter CaseReviewSecondCycleBadgeTests` — round-36's 8 tests should still pass.
8. `swift test --filter RevisedReadOpenerTests` — the round-29 + round-35 tests should still pass.
9. `swift test --filter RevisedReadFollowUpTests` — the round-30 + round-35 tests should still pass.
10. `swift test --filter SecondCyclePushbackContextTests` — round-33's 6 context-builder tests should still pass.
11. `swift test --filter CoachMemoryEngineTests` — round-33's engine tests + the older engine tests should all pass.
12. `swift test --filter FreshRevisedReadContextTests` — round-31's 16 tests should still pass.
13. `swift test --filter HypothesisAcknowledgementTests` — round-26's 19 tests should still pass.
14. `swift test --filter CoachMemoryStoreTests` — the existing memory-store tests should still pass.
15. Boot the app on simulator, drive a session through the round-26 hypothesis-ack chip (`.rejected`) so the engine sets a `.rejected` ack on the rebuilt working hypothesis. Drive another rep so memory rebuilds and the engine writes an engine-only refinement (no user pushback). The chat coach's user-context block should now carry the round-40 "Intervention still under pushback: ..." line in the INTERVENTION CYCLE block, alongside the generic "Last course change: ..." line. The round-32 verdict line and round-38 dampening line should BOTH be dark on this reply.
16. Wait 14+ days (or fast-forward `now`) and verify the under-pushback continuation line drops while the engine refinement still surfaces through the generic line — the recency gate distinction.
17. Drive a `.uncertain` follow-up chip instead. Verify NEITHER round 38 NOR round 40 surfaces (the `.uncertain` ack is round 32's territory alone).
18. Drive a `.confirmed` follow-up chip instead. Verify the round-39 case-anchored continuation line surfaces and the round-40 under-pushback continuation line does NOT — mutual exclusion at the predicate level on the ack-confidence axis.
19. Confirm the round-36 `CaseReviewCard` "Last shift" row's second-cycle badge, the round-34 post-rep `RevisedReadCard` second-cycle copy, the round-35 chat seed second-cycle copy, the round-37 case-anchored amplification line, the round-38 under-repeated-pushback dampening line, the round-39 case-anchored continuation line, and all eight rounds' cross-surface contracts are preserved verbatim.
