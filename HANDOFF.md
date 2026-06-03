# HANDOFF — M24 deferred slate (round 37): case-anchored amplification on the active intervention — a new `CoachContextBuilder` predicate + context-line helper detects the pushback-then-confirm-in-recency case state and surfaces ONE additional INTERVENTION CYCLE line telling the chat coach to treat follow-on evidence as case-anchored, not exploratory. Pure-context surface, no engine state change, no schema bump, no view changes.

## Scope

Round 36 closed the THIRD surface on the second-cycle predicate (the `CaseReviewCard` history badge). The honest gap round 36 left open on the **active intervention** carrying surface: when a user confirms a rebuilt working hypothesis with `.confirmed` AFTER themselves pushing back on the prior read (the pushback-then-confirm pattern), the chat coach should treat follow-on evidence on the carrying intervention as case-anchored — the user has now BOTH adapted away from the original read AND ratified the rebuilt one, so the operating hypothesis carries the user's own confirmation, not just the engine's inference. Without an explicit signal, the model speaks to follow-on evidence as exploratory and may re-open the original read.

Round 37 picks up step #10 from the round-36 "Future moves" list (called out as "the next-most-aligned coach-parity gap" after rounds 34–36):

> **`.confirmed` confidence amplification on the active intervention.**
> Carried forward from round 27, called out by round 32. After rounds
> 34–36's split-the-cycle work, this becomes the next-most-aligned
> coach-parity gap: when a user confirms a rebuilt working hypothesis with
> `.confirmed`, the active intervention's confidence should amplify
> proportionally so the engine treats follow-on evidence as case-anchored,
> not exploratory. Pure-logic work on `CoachMemory.activeIntervention`
> (no new schema, no view changes) — read
> `hypothesisAcknowledgement.confidence == .confirmed` + a recency window
> inside the rebuild path, raise the carrying intervention's evidence
> confidence one tier when the predicate fires (and the prior rebuild was
> itself a user-driven cycle). Mirror of round 33's reading on a different
> field.

Round 37 lands the predicate, the context-line helper, and the context-block surfacing with brand-voice-compliant copy (no exclamation, no "Let's", no "we", no "sorry") and pins it with twenty-seven new tests in a new `@MainActor @Suite("CaseAnchoredAmplificationTests")` suite. The surfacing is the LIGHTEST possible: ONE additional INTERVENTION CYCLE line, appended INSIDE the active-intervention block, telling the chat coach to treat follow-on evidence as case-anchored, not exploratory.

Defensive scoping (intentional restraint vs. the future-moves text):

- **Pure context surface, not engine state change.** The future-moves text reads "raise the carrying intervention's evidence confidence one tier". An engine-level `reviewStatus` lift would cascade through the post-rep `InterventionReviewPromptCard`, the Profile-tab `CaseReviewCard.interventionRow`, the AI prompt generator, and the post-rep summary — none of which can be QA'd without a real device. Round 37 keeps the impact bounded to the chat coach's context block, the SAME surface rounds 30–35 fan out across, so the new signal is testable in isolation and reversible if real-conversation evidence shows the line as off.
- **Recency-gated.** A confirmation lodged within the last 14 days amplifies; beyond that, the round-32 rebuild-verdict block carries the verdict signal without the case-anchored amplification clause. A stale confirmation does not amplify today's follow-on evidence indefinitely — the case may have aged enough that the original confirmation no longer anchors today's read.
- **Mutually compatible with round 32, not overlapping.** Round 32 fires on every `.confirmed`/`.uncertain`/`.rejected` rebuild-verdict regardless of cycle history. Round 37 is a STRICTER subset of round 32 on the `.confirmed` branch — round 37 implies round 32, but round 32 does not imply round 37. Both lines coexist on a confirmed-rebuild-in-recency chat reply: round 32 names the verdict event; round 37 names the durable case-anchoring state.

The mechanism is a pair of pure additions on `CoachContextBuilder`:

- `static let caseAnchoredAmplificationRecencyDays: Int = 14` — pure constant pinned by a brand-voice-style test. Tunes the recency horizon to the same window the post-rep follow-ups already use, so the signal stays live across roughly two weeks of practice before expiring. Lifted as a constant so a future tuning round lands in one place.
- `static func caseAnchoredAmplificationApplies(in memory: CoachMemory, now: Date) -> Bool` — pure predicate dispatching on five gates: (1) `.confirmed` ack carried, (2) ack `appliesTo` current hypothesis, (3) ack within recency window, (4) latest adaptation entry `documentsUserPushback`, (5) ack timestamp `>= changedAt` (ack post-dates the rebuild). All five are pure reads on memory fields the engine already writes — no new persisted state, no schema bump.
- `static func caseAnchoredAmplificationContextLine(memory: CoachMemory, now: Date) -> String?` — pure context-line helper. Returns ONE additional INTERVENTION CYCLE line when the predicate fires AND `memory.activeIntervention != nil`; returns `nil` otherwise. The line is the LIGHTEST possible surface that signals case anchoring: it names both halves of the pushback-then-confirm pattern AND tells the model to treat follow-on evidence as case-anchored, not exploratory.

The wiring layer is intentionally thin: `interventionCycleLines` now appends the amplification line at the END of the active-intervention block (after `reviewDueAt`), so the new line reads as the natural closing qualifier on the existing five-line intervention block.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure working towards getting the app towards the vision plan, and all round A+, make my dream I had come true too, ensure working on the redesign branch too (very important)."

Translation, this round:

- New `CoachContextBuilder.caseAnchoredAmplificationRecencyDays: Int = 14` constant — the recency horizon for the predicate, pinned by a regression-protection test. Placed in a dedicated `MARK: - Case-anchored amplification (round 37 — future moves #10)` block immediately after the round-32 `rebuildVerdictContextLines` block so a future reader sees the round-32 verdict surface and the round-37 amplification surface as one coherent block — the layered design is documented in the inline comments, not just in code.
- New `CoachContextBuilder.caseAnchoredAmplificationApplies(in:now:)` static predicate — pure dispatch on the five gates. Same shape as `rebuildVerdictPair(in:)` (pure read of memory fields, no UI dependency) so the chat context, the post-rep summary, and any future surface can read the same predicate without duplicating the gate.
- New `CoachContextBuilder.caseAnchoredAmplificationContextLine(memory:now:)` static helper — pure context-line helper. Returns the amplification line when the predicate fires AND an active intervention exists; returns `nil` otherwise. Restraint pin: a future round that surfaces case-anchored copy OUTSIDE the active-intervention block must build a different helper rather than overload this one.
- Wiring update in `CoachContextBuilder.interventionCycleLines(...)` — the amplification line is appended at the END of the active-intervention block (right after `reviewDueAt`). The 9-line cap on `interventionCycleLines` is unaffected (worst case: 5 base intervention lines + 1 amplification + 2 round-32 verdict lines = 8, under cap).
- New `CaseAnchoredAmplificationTests` suite (27 `@Test` methods + 7 private fixture helpers — same canonical hypothesis + pushback/engine-only shape as `RebuildVerdictContextTests`) — pins the pure constant, the pure predicate on every branch (happy path, `.uncertain`/`.rejected` dark, no ack, snapshot stale, missing hypothesis, outside recency window, exact recency boundary, engine-only latest change, nil/empty log, ack pre-dates rebuild, ack-at-rebuild-time boundary, mixed history reads `.last` only), the pure context-line helper (fires when predicate + active intervention; dark when no intervention; dark when predicate dark; behavioural contract on the line text), brand-voice compliance, FOUR cross-surface contracts with `rebuildVerdictPair` (round 37 implies round 32 on `.confirmed`; round 32 alone fires without round 37 on `.uncertain`/`.rejected`/outside-recency), and THREE userContext integration tests (full pipeline surfaces the line; missing active intervention drops the line but keeps round 32; round 32 and round 37 layer cleanly on the happy path).
- The redesign-branch invariant: this is a `Redesign`-branch push per the user brief. Round 37 preserves the round-by-round loop on the redesign lineage that has been the home of rounds 11–36.

## What shipped

### Track 1 — `CoachContextBuilder.caseAnchoredAmplificationRecencyDays` constant (`Noum/CoachContextBuilder.swift`)

- New `static let caseAnchoredAmplificationRecencyDays: Int = 14`. Tuned to the same horizon as the post-rep follow-up window so the signal stays live across roughly two weeks of practice before expiring. Doc comment cites the cross-surface contract with the round-32 rebuild-verdict block (which has no recency gate) so a future reader understands the recency window is the structural distinction between the two surfaces.
- Pinned by `recencyWindowIsCalmCoachingHorizon`: locks the constant at 14, so a copy edit that drifts the window has to update this test deliberately.

### Track 2 — `CoachContextBuilder.caseAnchoredAmplificationApplies(in:now:)` predicate (`Noum/CoachContextBuilder.swift`)

- New `static func caseAnchoredAmplificationApplies(in memory: CoachMemory, now: Date) -> Bool` — pure dispatch on five gates:
  1. `memory.hypothesisAcknowledgement?.confidence == .confirmed`
  2. `ack.appliesTo(currentHypothesis: memory.workingHypothesis)`
  3. `now.timeIntervalSince(ack.acknowledgedAt) <= caseAnchoredAmplificationRecencyDays * 86400`
  4. `memory.adaptationLog?.last?.documentsUserPushback == true`
  5. `ack.acknowledgedAt >= lastChange.changedAt`
- All five are pure reads on memory fields the engine already writes. Memories persisted before round 37 read `false` on the predicate automatically — no schema bump, no migration.
- Pinned by fourteen predicate tests (happy path, uncertain ack, rejected ack, no ack, snapshot stale, missing hypothesis, outside recency, exact recency boundary, engine-only latest change, nil log, empty log, ack pre-dates rebuild, ack-at-rebuild-time boundary, mixed history `.last` read).

### Track 3 — `CoachContextBuilder.caseAnchoredAmplificationContextLine(memory:now:)` helper (`Noum/CoachContextBuilder.swift`)

- New `static func caseAnchoredAmplificationContextLine(memory: CoachMemory, now: Date) -> String?` — pure helper. Returns ONE context line (`"- Case-anchored amplification: the user has both pushed back on the original read AND confirmed the rebuilt working hypothesis above; treat follow-on evidence on the active intervention as case-anchored, not exploratory. Speak with conviction on the carrying read; do not re-open the original."`) when the predicate fires AND an active intervention exists; returns `nil` otherwise.
- Brand-voice compliant: no `!`, no `"Let's"`/`"let's"`, no `" we "`, no `"sorry"`. Mirrors the round-32/33/34/35/36 brand-voice rules so the case-anchoring copy reads in the same register as the rest of the case-spine surfaces.
- Pinned by four helper tests (fires on happy path; dark when no active intervention; dark when predicate dark; behavioural contract on the line text — names BOTH halves of the pushback-then-confirm pattern AND the case-anchored treatment instruction AND the speak-with-conviction clause AND the don't-re-open instruction) + a brand-voice test.

### Track 4 — wiring in `CoachContextBuilder.interventionCycleLines(...)` (`Noum/CoachContextBuilder.swift`)

- The amplification line is appended at the END of the active-intervention block (right after `reviewDueAt`), inside the existing `if includeActiveIntervention, let intervention = memory.activeIntervention { ... }` guard. Anchored against `memory.updatedAt` as the time origin (same anchor round 31 uses for `isFresh`) so the predicate is pure and locked by tests without standing up a real wall clock.
- The 9-line cap on `interventionCycleLines` is unaffected (worst case: 5 base intervention lines + 1 amplification + 2 round-32 verdict lines = 8, under cap). The three-tier course-change surface (round 32 → round 31 → generic) is preserved verbatim.

### Track 5 — `CaseAnchoredAmplificationTests` suite (`NoumTests/NoumTests.swift`)

Twenty-two new `@Test` methods inside a new `@MainActor @Suite("CaseAnchoredAmplificationTests")` suite, slotted immediately after the existing `RebuildVerdictContextTests` suite (line 28980 → new suite ends around line 29380 → preserved `SecondCyclePushbackContextTests` follows). Seven private fixture helpers (`rebuiltHypothesis`, `pushbackChange`, `engineOnlyChange`, `ack`, `sampleIntervention`, `memory`, `sampleProfile`) mirror the round-32 `RebuildVerdictContextTests` fixtures so the two suites that gate on the rebuild-then-confirm shape share the same canonical fixture register.

- **Pure constant (1 test):**
  - `recencyWindowIsCalmCoachingHorizon` — pure constant pin: `14`.
- **Pure predicate (14 tests):**
  - `predicateFiresWhenConfirmedAckPostDatesPushbackRebuildWithinWindow` — happy path on all five gates open.
  - `predicateDarkOnUncertainAck` — no-regression contract; `.uncertain` does not amplify.
  - `predicateDarkOnRejectedAck` — no-regression contract; `.rejected` (second pushback) does not amplify.
  - `predicateDarkWhenNoAckCarried` — no-regression contract; the round-31 window does not amplify.
  - `predicateDarkWhenAckSnapshotNoLongerApplies` — same case-spine contract as `rebuildVerdictPair`; stale snapshot drops.
  - `predicateDarkWhenWorkingHypothesisIsNil` — defensive pin.
  - `predicateDarkWhenAckIsOutsideRecencyWindow` — defensive pin on stale confirmation (15 days past).
  - `predicateFiresAtExactRecencyBoundary` — edge case at exactly 14 days past; inclusive boundary.
  - `predicateDarkWhenLatestChangeIsEngineOnly` — defensive pin; an engine-only shift followed by `.confirmed` does not amplify.
  - `predicateDarkOnNilAdaptationLog` — defensive pin.
  - `predicateDarkOnEmptyAdaptationLog` — defensive pin.
  - `predicateDarkWhenAckPreDatesRebuild` — same ordering contract as `rebuildVerdictPair`; stale ack drops.
  - `predicateFiresWhenAckExactlyAtRebuildTime` — edge case at `acknowledgedAt == changedAt`; inclusive boundary.
  - `predicateReadsLatestChangeOnly` — mixed history (earlier pushback, latest engine-only shift); predicate reads `.last` only.
- **Pure context-line helper (4 tests):**
  - `contextLineFiresWhenPredicateAndActiveInterventionPresent` — happy path on the helper's return shape.
  - `contextLineDarkWhenNoActiveIntervention` — defensive pin; restraint rail against amplifying without a carrying intervention.
  - `contextLineDarkWhenPredicateDark` — sanity pin.
  - `contextLineNamesCaseAnchoredStateAndTreatmentOfFollowOnEvidence` — behavioural contract on the line text.
- **Brand voice (1 test):**
  - `contextLineIsBrandVoiceCompliant` — pins `!`, `"Let's"`, `" we "`, `"sorry"` absence on the line.
- **Cross-surface contract (4 tests):**
  - `round37IsStricterSubsetOfRound32OnConfirmedBranch` — locks the implication direction: round 37 → round 32 on `.confirmed`.
  - `round32CanFireWithoutRound37WhenAckIsUncertain` — reverse direction; round 32 does not imply round 37.
  - `round32CanFireWithoutRound37WhenAckIsRejected` — reverse direction; the second-pushback signal does not amplify.
  - `round32FiresOutsideRecencyButRound37Drops` — locks the recency-gate distinction.
- **userContext integration (3 tests):**
  - `userContextSurfacesAmplificationLineInInterventionCycle` — full pipeline carries the line through the INTERVENTION CYCLE block.
  - `userContextDoesNotSurfaceAmplificationWhenNoActiveIntervention` — pipeline drops the amplification line but keeps the round-32 verdict line (since `rebuildVerdictContextLines` does NOT depend on an active intervention).
  - `userContextLayersRound32AndRound37LinesOnHappyPath` — locks the layered design end-to-end; both lines coexist.

### Vision alignment

- **Coach-parity stage #2 (Case formulation).** Per `docs/VISION.md`: the case formulation must carry "what improvement would look like before the user starts" + an explicit, revisable read of the user's confirmation state. Rounds 26–36 lifted the user's pushback and verdict into bounded coach memory across the engine, the post-rep card, the chat seed, the chat-coach context block, and the long-term Profile-tab history. Round 37 closes the missing **active-intervention** surface: the chat coach now reads the case-anchored state on every reply for two weeks after the user confirms a rebuilt read.
- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the case formulation needs the reason for changing course AND the durable signal that the new course is operating with the user's confirmation. Rounds 27–36 named the rebuild + cycle distinction; round 37 names the durable case-anchoring state that follows when the user RATIFIES the rebuild. The chat coach can now speak to follow-on evidence with conviction rather than re-opening the original read.
- **Coach-parity stage #5 (Adaptation, anti-overclaim).** The amplification line is gated on five honest signals (confirmed ack, snapshot applies, within recency, prior rebuild was user-driven, ack post-dates rebuild). Engine-only lever shifts followed by a passive confirmation do NOT satisfy the predicate — the user must have BOTH pushed back AND confirmed. The line says nothing about whether the case-anchored read is correct, helpful, or final; it names the case-anchored state on the predicate the engine already records.
- **Pillar #5 (Personalized coaching).** Round 37 + round 32 now form one cross-surface lift on the rebuild-then-confirm pattern: round 32 names the verdict event; round 37 names the durable case-anchoring state the verdict establishes for the carrying intervention. The chat coach hears the case anchoring on every reply for two weeks after the user confirms the rebuild.
- **Pillar #4 (Believable progress).** The amplification line is evidence-anchored — it cites the user's own pushback AND confirmation as the basis for the case-anchored read, not an inference. The chat coach can now speak with conviction WITHOUT the model fabricating a confidence claim.
- **Anti-overclaim.** No engine state mutation, no `reviewStatus` lift, no schema bump, no migration. The amplification is a calm pure-context surface that signals case anchoring; the persisted intervention's review status, success criterion, and review cadence are preserved verbatim. A future round can escalate to engine-level amplification once real-conversation evidence shows the context surface as insufficient.
- **Engineering bans.** No placeholder logic. No dead toggles. No fragmented state — the new predicate READS the existing `memory.hypothesisAcknowledgement`, `memory.workingHypothesis`, and `memory.adaptationLog` fields. No new storage, no schema bump, no migration, no new view inputs. Memories persisted before round 37 read `false` on the predicate and surface no amplification line automatically. Pure-function lift on pure-function inputs. The existing `rebuildVerdictPair`, `rebuildVerdictContextLines`, `freshRevisedReadChange`, `freshRevisedReadContextLines`, `coachCaseFormulationLines`, and `interventionCycleLines` paths are preserved verbatim (`interventionCycleLines` ONLY appends a new optional line at the end of the active-intervention block — no other modifications).

### Branch + redesign-alignment notes

- All five tracks land on `Redesign`, the redesign-lineage branch the rolling M24 deferred-slate work has been shipping on since round 11. The user brief explicitly calls this out: "ensure working on the redesign branch too (very important)." Round 37 preserves the round-by-round loop on the redesign lineage.
- Round 37 does not change the round-36 `CaseReviewCard.secondCycleBadgeLabel` / `showsSecondCycleBadge(for:)` / `lastShiftRow(_:)`, does not change the round-35 `revisedReadOpenerSecondCycleLead` / `secondCycleRevisedReadOpener(...)` / `revisedReadOpener(for:workingHypothesis:voice:)` router, does not change the round-34 `RevisedReadCard.headlineCopy(for:)` / `secondCycleHeadlineCopy` / `bodyCopy(for:workingHypothesis:)` / `secondCycleBodyCopy(workingHypothesis:)` router, does not change the round-33 `secondCyclePushbackMarker` constant or `documentsSecondCyclePushback` predicate, does not change the round-33 `freshRevisedReadContextLines` second-cycle branch, does not change the round-32 `rebuildVerdictPair` / `rebuildVerdictContextLines`, does not change the round-31 `freshRevisedReadChange(in:)` helper, does not change the round-30 chip-row catalog or follow-up predicate, does not change the round-29 first-cycle composer, does not change the round-28 first-cycle copy, does not change the round-27 engine restructure, does not change the round-26 chip catalog or hypothesis-ack row, and does not change the round-24 / round-25 `InterventionReviewPromptCard` surface. The round-36 8 `CaseReviewSecondCycleBadgeTests`, the round-35 12 + 5 RevisedReadOpener + RevisedReadFollowUp tests, the round-34 14 RevisedReadCard tests, the round-33 6 engine + 6 context-builder tests, the round-32 25 rebuild-verdict tests, the round-31 16 fresh revised-read tests, the round-30 15 follow-up tests, the round-29 13 opener tests, the round-28 5 copy tests, and the round-26 19 ack tests all remain unchanged; the round-37 27 `CaseAnchoredAmplificationTests` sit alongside them.

## Future moves

(Updated priority list — round 37 closed round-36 step #10. The rest roll forward, plus one new note from round 37.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving with celebration timing. Worth a dedicated refactor pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from rounds 19–36. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from rounds 20–36. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.** Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward from round 22.
7. **Tier-change observation symmetry to other surfaces that read `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
8. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **Engine-level case-anchored amplification (post-round-37 escalation).** Carried forward from round 37 as a future move. If real-conversation evidence shows the round-37 context-line signal is insufficient, escalate to an engine-level `reviewStatus` lift on the `CoachIntervention` carrying the confirmed rebuild — same predicate, broader surface. Mirror of the round-19 → round-26 → round-36 surface-by-surface lift pattern. Pure-logic work but with downstream impact on the post-rep `InterventionReviewPromptCard`, the Profile-tab `CaseReviewCard.interventionRow`, the AI prompt generator's `INTERVENTION CYCLE` block, and the post-rep summary — none of which can be QA'd without a real device. Restraint pin: do NOT escalate until real-conversation evidence shows the context-line surface as insufficient.
11. **Collapse the round-26 hypothesis-ack reflection in `coachCaseFormulationLines` into a single block with the round-32 rebuild-verdict lines when the predicate fires.** Carried forward from round 32. Hold for real-device QA.
12. **Trend-view distinction between "user accepted the first read", "user accepted the rebuilt read", "user accepted the rebuilt read AFTER pushing back", and "user pushed back twice".** From round 30's step #11 + round 32's step #14 + round 33 + round 36, made richer by round 37. Round 37 strengthens the case further: the predicate now drives the engine, the post-rep card, the chat-coach context block (both the rebuild-verdict layer AND the case-anchored amplification layer), the chat seed, the long-term Profile-tab history badge, AND the active-intervention amplification surface. A future analytics surface inherits SIX distinct signal points instead of one.
13. **Second-cycle ask register on the opener.** Note from round 35. The voice-shaped ask is currently cycle-agnostic by design. A future round, after real-device QA on second-cycle conversations, may want a cycle-aware ask register. Restraint pin: do NOT split the ask until real conversations show the cycle-agnostic ask reads as off; the simpler shared mapping is the better default.
14. **`CaseReviewCard` adaptation-log fuller history surface.** Note from round 36. A future round could lift the entire bounded adaptation log into an expandable surface (one row per entry, each carrying the same second-cycle badge when its `documentsSecondCyclePushback` fires). Restraint pin: do NOT lift until real-device QA confirms users want the lineage exposed.
15. **`CaseReviewCard` case-anchored badge.** New note from round 37. The Profile-tab `CaseReviewCard.interventionRow` could read off the same round-37 predicate to surface a small "case-anchored" capsule beside the "Active intervention" eyebrow when the predicate fires — same shape as the round-36 second-cycle badge on the `CaseReviewCard.lastShiftRow`. The predicate is already lifted on `CoachContextBuilder.caseAnchoredAmplificationApplies(in:now:)`; the badge would be a pure visual addition gated on the same call. Restraint pin: hold for real-device QA — the active-intervention block's eyebrow is currently a calm single-row register, and the case-anchored read is best validated in chat conversation before duplicating to the long-term history surface.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this round was compiled or run — not the app, not the test suite. The changes are:

- One new `static let caseAnchoredAmplificationRecencyDays: Int = 14`, one new `static func caseAnchoredAmplificationApplies(in:now:) -> Bool`, and one new `static func caseAnchoredAmplificationContextLine(memory:now:) -> String?` on `CoachContextBuilder` in `Noum/CoachContextBuilder.swift`. Single-expression / single-statement bodies; pure functions of existing persisted fields.
- One additive call site in `CoachContextBuilder.interventionCycleLines(...)`: a `if let amplificationLine = caseAnchoredAmplificationContextLine(memory: memory, now: memory.updatedAt) { lines.append(amplificationLine) }` block inside the existing active-intervention `if` block. Every other line in the function is preserved verbatim.
- Twenty-two new `@Test` methods inside a new `@MainActor @Suite("CaseAnchoredAmplificationTests")` suite and seven new private fixture helpers, in `NoumTests/NoumTests.swift`. Slotted immediately after the existing `RebuildVerdictContextTests` suite (around line 28980) so the round-32 + round-37 cross-surface contract reads as one block in the test file.

All checks the next agent should run on a real build host:

1. `swift test --filter CaseAnchoredAmplificationTests` — the new round-37 27 tests should all pass.
2. `swift test --filter RebuildVerdictContextTests` — round-32's 25 tests should still pass (the round-37 cross-surface contract tests read through `rebuildVerdictPair(in:)` but do not modify it).
3. `swift test --filter RevisedReadCardTests` — round-34's 14 tests should still pass.
4. `swift test --filter CaseReviewSecondCycleBadgeTests` — round-36's 8 tests should still pass.
5. `swift test --filter RevisedReadOpenerTests` — the round-29 13 + round-35 12 tests should still pass.
6. `swift test --filter RevisedReadFollowUpTests` — the round-30 15 + round-35 5 tests should still pass.
7. `swift test --filter SecondCyclePushbackContextTests` — round-33's 6 context-builder tests should still pass.
8. `swift test --filter CoachMemoryEngineTests` — round-33's engine tests + the older engine tests should all pass.
9. `swift test --filter FreshRevisedReadContextTests` — round-31's 16 tests should still pass.
10. `swift test --filter HypothesisAcknowledgementTests` — round-26's 19 tests should still pass.
11. `swift test --filter CoachMemoryStoreTests` — the existing memory-store tests should still pass.
12. Boot the app on simulator, drive a session through the round-26 hypothesis-ack chip (`.rejected`) so the engine appends a first-cycle pushback entry. Finish a rep so memory rebuilds. Drive the round-30 follow-up chip row (`.confirmed`) on the rebuilt read. The chat coach's user-context block should now carry BOTH the round-32 "Case file rebuild verdict: ... confirmed verdict ..." line AND the round-37 "Case-anchored amplification: ..." line in the INTERVENTION CYCLE block.
13. Drive another rep so memory rebuilds again. The ack should carry forward (the working hypothesis still applies), so the round-37 amplification line should still surface on every chat reply.
14. Wait 14+ days (or fast-forward `now`) and verify the amplification line drops while the round-32 verdict line persists — the recency gate distinction.
15. Drive a `.rejected` follow-up chip on the rebuilt read instead. Verify the round-37 amplification line does NOT surface (the `.rejected` branch is the second-pushback signal, not the case-anchored signal), and the existing round-32 "second pushback" line + round-33 second-cycle markers still fire on the next memory rebuild.
16. Confirm the round-36 `CaseReviewCard` "Last shift" row's second-cycle badge, the round-34 post-rep `RevisedReadCard` second-cycle copy, the round-35 chat seed second-cycle copy, and all five rounds' cross-surface contracts are preserved verbatim.
