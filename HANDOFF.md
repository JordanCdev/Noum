# HANDOFF — M24 deferred slate (round 33): the second-cycle pushback is now recorded on the durable adaptation entry the engine writes, AND surfaced in the chat-coach user-context block in BOTH the round-31 fresh window and the generic "Last course change" else-arm — so the model still sees the repeated-adapt signal on every chat turn AFTER round 32's chip-row ack ages out of memory, not just inside the window where the ack happens to be carried.

## Scope

Round 32 carried the round-30 chip-row verdict into the chat-coach user-context block as a `rebuildVerdictContextLines` pair whenever the user had lodged a `confirmed` / `uncertain` / `rejected` verdict on the rebuilt working hypothesis. The honest gap that left open: **once the engine rebuilds memory after the next followed rep, the carried ack's `appliesTo(currentHypothesis:)` returns false against the freshly-rewritten hypothesis, so `noteHypothesisAcknowledgement` is dropped AND `droppedRejectedAck` fires in `CoachMemoryEngine.build(...)` — appending a fresh `CoachCourseChange`.** That new entry's `reason` text reads identically to a first-cycle pushback. The model loses the "this is the second pushback cycle" signal the moment the verdict lifecycle closes, even though the persistent record now carries two consecutive pushback entries in `adaptationLog`.

Round 33 picks up step #11 from the round-32 "Future moves" list:

> **Adaptation-log entry on a round-32 `.rejected` rebuild verdict.**
> Promoted from round-30 step #12 and made specific by round 32.
> A `.rejected` rebuild verdict surfaces as a "second pushback" in
> context. The natural next step: on the next memory rebuild,
> `CoachMemoryEngine.build(...)` could detect the dropped
> `.rejected` rebuild-verdict ack (same shape as the round-27
> `droppedRejectedAck` arm, but tagged to the rebuilt hypothesis)
> and append a fresh `CoachCourseChange` with the rebuild as the
> prior and the next read as the revised. Closes the rejection-
> rebuild-rejection-rebuild chain in the engine, so the
> adaptation log carries the full lineage, not just the first
> cycle.

The framing in the round-32 note focused on the engine-side append (which the existing round-27 `droppedRejectedAck` arm already does, end-to-end). The honest gap round 33 closes is **distinguishing first-cycle from second-cycle pushback in the recorded `reason` text**, so the case-spine carries the cycle lineage as readable structure — not just a count of entries — AND so the chat-coach context can surface the second-cycle signal even after round 32 goes dark.

The mechanism is a single marker phrase the engine embeds when the previous bounded log's `.last` entry was itself a user pushback rebuild. Two pure-function predicates layer cleanly:

- `documentsUserPushback` (round 28) — first-cycle marker; matches ANY pushback entry, first cycle or second.
- `documentsSecondCyclePushback` (round 33) — second-cycle marker; matches ONLY when the engine also recorded "this pushback followed a prior pushback".

The chat-coach context reads the second predicate to swap round-31's case-state and coach-move copy for second-cycle phrasing (`"Case file shifted again"`, `"Coach move on the second rebuild cycle: do not re-prescribe the same intervention unchanged"`) AND to append a one-sentence `"Repeated-adapt note:"` follow-up when the generic else-arm fires (the case where the change has aged out of round-31's `isFresh` window AND no ack is carried for round 32). The model sees the second-cycle signal on every chat turn between rebuilds, regardless of which of the three tiers fires.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure working towards getting the app towards the vision plan, and all round A+, make my dream I had come true too, ensure working on the redesign branch too (very important)."

Translation, this round:

- New `CoachCourseChange.secondCyclePushbackMarker` constant — the canonical phrase `"after a prior pushback rebuild"` written into `reason` as a parenthetical by `CoachMemoryEngine.build(...)`'s ack-driven arms. Placed alongside the existing `userPushbackMarker` so a future reader sees the two coordinated markers together.
- New `CoachCourseChange.documentsSecondCyclePushback` computed property — pure-function read of the persisted `reason`; returns true iff the marker phrase is present. Codable round-trips identically (entries persisted before round 33 simply read `false` on this predicate; the existing `documentsUserPushback` predicate is unchanged on those entries).
- `CoachMemoryEngine.build(...)`'s ack-driven append logic now embeds the second-cycle marker on BOTH the `(prior?, ack?)` and `(nil, ack?)` switch arms whenever `previous?.adaptationLog?.last?.documentsUserPushback == true`. The first-cycle marker (`userPushbackMarker`) is preserved verbatim INSIDE the new reason, so existing predicates (including round 32's `rebuildVerdictPair` gate, round 31's `freshRevisedReadChange` gate, and the round-28 `RevisedReadCard` gate in `SummaryView`) all continue firing on second-cycle entries.
- `CoachContextBuilder.freshRevisedReadContextLines(memory:)` branches on the new predicate: a second-cycle change emits a distinct two-line block (`"Case file shifted again …"` + `"Coach move on the second rebuild cycle: …"`) instead of the existing first-cycle pair. Three anti-overclaim rails surface in the second-cycle coach-move line: do not re-prescribe identical work, ask one focused discriminating question, do not strengthen either prior read until the user weighs in.
- `CoachContextBuilder.interventionCycleLines(...)`'s generic else-arm now appends a single follow-up `"Repeated-adapt note: …"` line when `change.documentsSecondCyclePushback` is true. That keeps the second-cycle signal in context AFTER round 31's freshness window has closed AND round 32's ack is no longer carried — the durability gap round 32 left behind.
- Three-tier precedence (round 32 → round 31 → generic) is unchanged. Round 33 only changes WHAT copy the lower tiers emit when the latest change is a second-cycle pushback. No new branch, no reordering, no new memory field.
- The redesign-branch invariant: this is a `Redesign`-branch push per the user brief. The work lands directly on `Redesign`, preserving the round-by-round loop on the redesign lineage that has been the home of rounds 11–32.

## What shipped

### Track 1 — `CoachCourseChange.secondCyclePushbackMarker` + `.documentsSecondCyclePushback` (`PrimaryFocusMemory.swift`)

- New `static let secondCyclePushbackMarker = "after a prior pushback rebuild"` placed immediately below `userPushbackMarker` so the two coordinated phrases sit together. Doc comment explains: the engine embeds this as a parenthetical INSIDE the existing first-cycle reason so `documentsUserPushback` and `documentsSecondCyclePushback` layer rather than mutually exclude.
- New `var documentsSecondCyclePushback: Bool` placed immediately below `documentsUserPushback`. Pure function of the persisted `reason` — `range(of:options:)` lookup against the marker, case-insensitive (same convention as `documentsUserPushback` and `documentsVoiceChange`).
- No new storage, no new Codable keys, no schema bump. Entries persisted before round 33 read `false` on the new predicate and behave identically to today.
- Doc comments cite the round-31 + round-32 + round-28 `RevisedReadCard` gates that depend on `documentsUserPushback` so a future reader understands why the first-cycle marker stays embedded verbatim in the new reason.

### Track 2 — `CoachMemoryEngine.build(...)` embeds the marker on the ack arms (`PrimaryFocusMemory.swift`)

- Inside the `if priorLeverShift != nil || droppedRejectedAck != nil` block, a single-expression `priorEntryWasPushback` predicate reads `previous?.adaptationLog?.last?.documentsUserPushback == true`. The marker tail is computed once: `secondCycleTag = " (\(CoachCourseChange.secondCyclePushbackMarker))"` when the predicate fires AND `droppedRejectedAck != nil`, empty string otherwise.
- The two ack-driven switch arms — `(prior?, ack?)` and `(nil, ack?)` — interpolate the tail INSIDE the first-cycle reason text, keeping the leading clause unchanged so `documentsUserPushback` matches both first-cycle and second-cycle entries.
- The `(prior?, nil)` engine-only arm and the `(nil, nil)` defensive arm are explicitly unchanged. The second-cycle signal is ack-driven only; an engine-only lever shift today is not a "second user pushback" even when the previous log entry was a pushback rebuild.
- Comment block ahead of the predicate names the orthogonality contract and the surfaces that gate on the layered predicates (round 31 `freshRevisedReadContextLines`, the generic else-arm follow-up).
- No interaction with `successCriterion`, `criterionStatus`, `reviewDueAt`, or any case-spine field — round 33 reads adaptation history only.
- No interaction with `hypothesisAcknowledgement` carry-forward — `appliesTo(currentHypothesis:)` still gates the carry, unchanged.

### Track 3 — `CoachContextBuilder.freshRevisedReadContextLines(memory:)` second-cycle branch (`CoachContextBuilder.swift`)

- New conditional at the head of the two-line emission: `if change.documentsSecondCyclePushback { return [secondCycleCaseState, secondCycleCoachMove] }`.
- Second-cycle case-state line: `"Case file shifted again: the user has now flagged the prior read as off across two consecutive rebuild cycles; the working hypothesis above is the new read(<basis>)."`. Reads "shifted again" instead of "just shifted" — the model is told this is a repeated adapt, not a first-time pushback.
- Second-cycle coach-move line: `"Coach move on the second rebuild cycle: do not re-prescribe the same intervention unchanged. Acknowledge the repeated adapt explicitly, ask one focused question that would discriminate between this new read and the two it just replaced, and avoid strengthening either prior read."`. Three anti-overclaim rails — do not re-prescribe, do not strengthen either prior read, ask one focused discriminating question — match the brand-voice rules (no exclamation, no "Let's", no hype).
- First-cycle copy preserved for non-marker entries: the original return values surface unchanged when the predicate is false, locking the no-regression contract.
- Basis tail composition (`basisTail = " (\(basis))"` when non-empty) reused across both branches — the parenthetical evidence basis surfaces on both first-cycle and second-cycle case-state lines.

### Track 4 — `interventionCycleLines` generic-arm second-cycle note (`CoachContextBuilder.swift`)

- The existing `else if let change = memory.adaptationLog?.last { lines.append("- Last course change: ...") }` arm now also checks `change.documentsSecondCyclePushback` and appends a one-sentence `"- Repeated-adapt note: the latest course change is a second-cycle pushback — the prior course change was also a user pushback rebuild, so the model should treat the new read as the SECOND adapt, not the first. Avoid re-prescribing identical work and avoid strengthening either prior read until the user weighs in on the new one."` follow-up when the predicate fires.
- The note surfaces ONLY when round 32 is dark (no ack carried) AND round 31 is dark (the change has aged out of `isFresh`) — i.e., when the durability gap the generic else-arm covers is exactly the window where the model would otherwise lose the second-cycle signal entirely. Round 31/32 second-cycle copy already names the cycle in their fresh windows; the note is the rep-boundary survival path.
- The `prefix(9)` cap holds. Max intervention lines = 5; the generic arm now emits up to 2 lines (generic line + note); 5 + 2 = 7 < 9.
- Comment block on the conditional cites the same three-tier precedence the round-32 comment block established, and names the round-33 durability rationale: the verdict on the rebuilt read survives the round-30 ack lifecycle in the persistent record via the marker, AND the chat-coach context now surfaces that durability via the note.

### Track 5 — `CoachMemoryEngineTests` second-cycle coverage (`NoumTests/NoumTests.swift`)

Six new `@Test` methods slotted into the existing `CoachMemoryEngineTests` suite, immediately after `freshlyBuiltMemoryMarksRejectedAckEntryAsFreshAndPushback` (the round-28 end-to-end pin):

- **Predicate (3 tests):**
  - `courseChangeDocumentsSecondCyclePushbackWhenMarkerEmbedded` — pure predicate happy path; both layered predicates return true.
  - `courseChangeDoesNotDocumentSecondCycleWithoutMarker` — first-cycle reason returns true on `documentsUserPushback`, false on `documentsSecondCyclePushback` (orthogonality contract).
  - `courseChangeDoesNotDocumentSecondCycleForEngineOnlyShift` — engine-only reason returns false on both. Locks the "ack-driven only" rule.
- **Engine emit (3 tests):**
  - `buildEmbedsSecondCycleMarkerOnAckOnlyArmWhenPriorEntryWasPushback` — `(nil, ack?)` arm with a prior pushback entry. New entry surfaces with both predicates true AND the first-cycle marker preserved verbatim.
  - `buildEmbedsSecondCycleMarkerOnCombinedShiftArmWhenPriorEntryWasPushback` — `(prior?, ack?)` arm with a prior pushback entry. New entry surfaces with the shift clause AND the second-cycle parenthetical AND the first-cycle marker.
  - `buildDoesNotTagSecondCycleWhenPriorEntryWasEngineOnlyShift` — defensive: today's pushback that follows an engine-only shift is the FIRST cycle of user pushback, even though the log is non-empty.
  - `buildDoesNotTagSecondCycleOnEngineOnlyShiftEvenAfterPriorPushback` — the other half of the orthogonality contract: engine-only lever shift today + prior pushback log → still not tagged. Tag is ack-driven only.

### Track 6 — `SecondCyclePushbackContextTests` top-level suite (`NoumTests/NoumTests.swift`)

New `@Suite("SecondCyclePushbackContextTests")` placed immediately after `RebuildVerdictContextTests` (round 32's suite) and before the `IMConversationEvaluationContractTests` block. Plain `struct`, `@MainActor` (mirror of `RebuildVerdictContextTests` attribute, defensive against any future `MainActor`-only reads in `CoachContextBuilder`).

Six `@Test` methods pin the context-line copy and the three-tier precedence on second-cycle entries:

- **`freshRevisedReadContextLines` copy swap (2 tests):**
  - `freshRevisedReadLinesSurfaceSecondCycleCopyWhenMarkerEmbedded` — round-31 path on a second-cycle entry: case-state line names "shifted again" + "two consecutive rebuild cycles"; coach-move line names "second rebuild cycle" + anti-re-prescribe + anti-strengthen rails. First-cycle copy must NOT also surface (single canonical block per cycle).
  - `freshRevisedReadLinesStayFirstCycleCopyWhenMarkerAbsent` — round-31 path on a first-cycle entry: original copy unchanged. Locks the no-regression contract.
- **`userContext` three-tier integration (4 tests):**
  - `userContextSurfacesSecondCycleCopyOnFreshSecondCycleRebuild` — round 31 fires on a fresh second-cycle entry with no ack. Round 32 dark, generic dark, first-cycle copy dark.
  - `userContextSurfacesGenericLineWithRepeatedAdaptNoteAfterFreshnessExpires` — the **durability headline contract**: round 31 has aged out, round 32 has no ack, generic line carries the recorded reason AND the new round-33 "Repeated-adapt note:" follow-up surfaces because the marker is in the persisted `reason`. The model still sees the second-cycle signal on every chat turn after both the freshness window AND the chip-row ack have closed.
  - `userContextGenericLineHasNoRepeatedAdaptNoteOnFirstCyclePushback` — defensive: an aged-out first-cycle entry surfaces the bare generic line, no repeated-adapt note. The note fires only when the marker is present.
  - `userContextRebuildVerdictBlockStillFiresOnSecondCyclePushbackWithFreshAck` — three-tier precedence preserved end-to-end: a second-cycle entry that still carries an ack routes to round 32, which is unchanged. Round 31's second-cycle copy AND the generic-arm note both stay dark on that turn.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the case formulation needs "the reason for changing course" carried as active coaching state, not buried in a log. Round 27 lifted user pushback into a `CoachCourseChange` entry. Rounds 28–32 surfaced the rebuild and the user's verdict on it across the post-rep summary, the chat seed, the follow-up chip row, and the chat-coach user-context block. Round 33 lifts the SECOND-cycle pushback into the persistent record AND the chat-coach context, so the model can speak to the repeated-adapt pattern as durable structure — not as a transient signal tied to round 30's ack lifecycle.
- **Coach-parity stage #5 (Adaptation, anti-overclaim).** A human coach who'd watched the user push back twice in a row would name the repeated pattern explicitly ("you've now pushed back on the read twice — let me ask one focused question instead of prescribing again"). Round 33's coach-move copy gives the model the same register, with explicit anti-re-prescribe, anti-strengthen-either-prior, and ask-one-focused-discriminating-question rails. The model can't quietly retry the rebuilt read as if the user had not weighed in.
- **Pillar #5 (Personalized coaching).** The chat-coach context now carries the second-cycle signal across all three of round-31's fresh window, round-32's ack-in-memory window, AND the generic else-arm post-rep-boundary window. The model speaks to a user who pushed back twice in a row consistently across every chat turn between rebuilds, not just inside the windows where ephemeral state happens to be carried.
- **Anti-overclaim.** Round 33's coach-move copy explicitly forbids re-prescribing the same intervention unchanged AND strengthening either prior read until the user weighs in on the new one. Three anti-overclaim rails in the second-cycle line; one anti-strengthen rail in the round-31 first-cycle line; one anti-relitigation rail in the round-32 `.confirmed` rebuild-verdict instruction. Each cycle name forces its own anti-overclaim register.
- **Engineering bans.** No placeholder logic. No dead toggles. No fragmented state — the new helpers READ existing memory fields (`adaptationLog`, persistent `reason`). No new storage, no schema bump, no migration. Pure-function lift on pure-function inputs. Memories persisted before round 33 decode identically and behave identically until a second consecutive user pushback rebuild lands in `adaptationLog`.

### Branch + redesign-alignment notes

- All six tracks land on `Redesign`, the redesign-lineage branch the rolling M24 deferred-slate work has been shipping on since round 11. The user brief explicitly calls this out: "ensure working on the redesign branch too (very important)." Round 33 preserves the round-by-round loop on the redesign lineage.
- Round 33 does not change the round-32 `rebuildVerdictPair` or `rebuildVerdictContextLines` predicates, does not change the round-31 `freshRevisedReadChange` predicate (only the copy `freshRevisedReadContextLines` emits when the marker is present), does not change the round-30 chip-row predicate or catalog, does not change the round-29 `revisedReadOpener` function, does not change the round-29 `talkToNoumOpener` gate, does not change the round-28 `RevisedReadCard` view, does not change the round-27 engine restructure (only widens the reason text on the ack arms), does not change the round-26 chip catalog or hypothesis-ack row, and does not change the round-24 / round-25 `InterventionReviewPromptCard` surface. The round-32 25 rebuild-verdict tests + round-31 16 fresh revised-read tests + round-30 15 follow-up tests + round-29 12 opener tests + round-28 5 copy tests + round-26 19 ack tests + the round-27 engine pins all remain unchanged; the round-33 6 engine tests + 6 context-builder tests sit alongside them.
- The round-32 rebuild-verdict block on a `.rejected` ack still reads "second pushback" (round 32's `rebuildVerdictLabel`). When that same ack ages out AND the freshly-appended entry is a second-cycle pushback, the round-33 chat-coach copy reads "second rebuild cycle" — they're complementary phrasings for two different windows of the same lifecycle. A future round can collapse them into one shared label, but only after a real-device QA pass to verify model behaviour under each register.

## Future moves

(Updated priority list — round-33 closed round-32 step #11; the rest roll forward, plus one new note from round 33.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving with celebration timing. Worth a dedicated refactor pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from rounds 19–32. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from rounds 20–32. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.** Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward from round 22.
7. **Tier-change observation symmetry to other surfaces that read `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
8. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **`.confirmed` confidence amplification on the active intervention.** Carried forward from round 27, called out by round 32. The round-32 `.confirmed` rebuild-verdict path remains the natural integration site — when the predicate fires AND the engine has not yet bumped `CoachIntervention.criterionStatus`, the same `.confirmed` branch could nudge the criterion toward "met" or extend the `reviewDueAt` cadence by one rep. Round 32 surfaces the verdict in CONTEXT; round-27 follow-on would let it AMPLIFY the intervention as well.
11. **Collapse `SummaryView.freshRevisedReadChange` into a call through `CoachContextBuilder.freshRevisedReadChange(in:)`.** Carried forward from round 31. With round 33's second-cycle copy split inside `freshRevisedReadContextLines`, the summary card's post-rep header would benefit from the same first/second-cycle distinction — a future round can lift the header text through the same predicate.
12. **Collapse the round-26 hypothesis-ack reflection in `coachCaseFormulationLines` into a single block with the round-32 rebuild-verdict lines when the predicate fires.** Carried forward from round 32. Hold for real-device QA.
13. **Trend-view distinction between "user accepted the first read", "user accepted the rebuilt read", and "user pushed back twice".** From round 30's step #11 + round 32's step #14, made richer by round 33. Round 33 surfaces the second-cycle pushback in CONTEXT (the model's read) AND in the PERSISTENT record (`documentsSecondCyclePushback`). A future analytics surface could use the same predicate to count second-cycle pushback events separately from first-cycle ones, so a future insights view can show the user "you've revised your coach's read twice this month" — durable feedback on the Adaptation loop without overclaiming the second cycle as a problem (it can equally be a healthy iteration pattern).
14. **`SummaryView.RevisedReadCard` second-cycle header.** New note from round 33. The post-rep card currently shows a single rebuild header copy; with round 33's marker on the persisted entry, the card could read the predicate and surface a second-cycle header ("You flagged the rebuilt read off too — let's discriminate") on the rep where the second-cycle entry was just folded in. Mirror of the round-33 context-builder split, on the post-rep summary surface. Hold for real-device QA so the visual register can be tuned alongside the copy.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this round was compiled or run — not the app, not the test suite. The changes are:

- One new `static let` and one new computed property on `CoachCourseChange` in `PrimaryFocusMemory.swift`, placed immediately after `userPushbackMarker` and `documentsUserPushback` respectively. Self-contained — no new imports, no new dependencies, no new types.
- One edit to `CoachMemoryEngine.build(...)` inside the existing `if priorLeverShift != nil || droppedRejectedAck != nil` block: a single-expression `priorEntryWasPushback` predicate, a single-expression `secondCycleTag` string, and a one-character `\(secondCycleTag)` interpolation inside two existing switch-arm reason templates. Behaviour unchanged when the predicate is false (the tag is empty string); new behaviour only when the predicate fires.
- One edit to `CoachContextBuilder.freshRevisedReadContextLines(memory:)` in `CoachContextBuilder.swift`: a single `if change.documentsSecondCyclePushback { return [...] }` head guard. First-cycle return values are unchanged below it.
- One edit to `CoachContextBuilder.interventionCycleLines(...)`'s generic else-arm: a single `if change.documentsSecondCyclePushback { lines.append(...) }` follow-up after the existing generic-line append. The bare generic-line path is unchanged.
- Six new `@Test` methods inside `CoachMemoryEngineTests` and one new top-level `@Suite("SecondCyclePushbackContextTests")` (six `@Test` methods) in `NoumTests/NoumTests.swift`. The suite is plain `struct`, `@MainActor` (mirror of `RebuildVerdictContextTests`, defensive against any future `MainActor`-only reads in `CoachContextBuilder`).

All checks the next agent should run on a real build host:

1. `swift test --filter SecondCyclePushbackContextTests` — the new round-33 6 context-builder tests should all pass.
2. `swift test --filter CoachMemoryEngineTests` — the existing engine tests + the new round-33 6 engine tests should all pass. The previously-pinned tests (`buildLogsCourseChangeWhenRejectedAckIsDroppedByHypothesisRevise`, `buildLogsSingleCourseChangeWhenLeverShiftAndRejectedAckCoincide`, `buildDoesNotDoubleLogRejectedAckWhenHypothesisHolds`, `buildDoesNotLogAdaptationForConfirmedOrUncertainAck`, `freshlyBuiltMemoryMarksRejectedAckEntryAsFreshAndPushback`) all set `previous?.adaptationLog == nil`, so `priorEntryWasPushback` is false → `secondCycleTag` is empty → reason text matches the pre-round-33 strings exactly.
3. `swift test --filter RebuildVerdictContextTests` — round-32's 25 tests should still pass. Round 33 does not touch `rebuildVerdictPair` or `rebuildVerdictContextLines`; the round-32 fixtures all use first-cycle pushback reasons (no marker), so the round-33 changes are transparent to those tests.
4. `swift test --filter FreshRevisedReadContextTests` — round-31's 16 tests should still pass. The round-31 fixtures all use first-cycle pushback reasons, so `documentsSecondCyclePushback` is false → first-cycle copy path is taken → unchanged.
5. `swift test --filter RevisedReadFollowUpTests` — round-30's 15 tests should still pass.
6. `swift test --filter RevisedReadOpenerTests` — round-29's 12 tests should still pass.
7. `swift test --filter RevisedReadCardTests` — round-28's 5 copy tests should still pass.
8. `swift test --filter CoachContextBuilderBigMomentTests` — the existing `userContextSurfacesCaseSpineCriterionReviewAndCourseChange` test uses an engine-only adaptation entry. Round 33's predicate returns false on engine-only entries; the generic line surfaces unchanged with no repeated-adapt note appended. Test must still pass.
9. `swift test --filter HypothesisAcknowledgementTests` — round-26's 19 tests should still pass.
10. `swift test --filter CoachMemoryStoreTests` — the existing memory-store tests should still pass. No `noteHypothesisAcknowledgement` behaviour was changed.
11. Boot the app on simulator, seed a `CoachMemory.activeIntervention` with a working hypothesis, open Ask Noum via the round-24 `InterventionReviewPromptCard` or the round-25 empty-state chip, wait for the coach reply, tap the **Adapt / rejected** ack chip on H1 (the original hypothesis). Then finish a new rep where the lever changes OR the hypothesis text rewrites. On the post-rep summary, confirm `RevisedReadCard` renders (round-28 contract). Open Ask Noum via the **Talk to Noum** CTA. Tap the **Lock the new read in / .rejected** chip on the round-30 follow-up row (the user's second pushback, lodged on H2 = the rebuilt read).
12. Finish ANOTHER followed rep so memory rebuilds: `previous?.hypothesisAcknowledgement` = `.rejected` on H2; `previous?.adaptationLog.last?.documentsUserPushback` = true (the first-cycle entry from step 11). The new memory rebuild produces H3 with `appliesTo(H3) == false` on the carried ack, so `droppedRejectedAck` fires AND `priorEntryWasPushback` is true → the engine writes the second-cycle marker. Open Ask Noum; confirm the chat-coach debug log carries:
    - The `INTERVENTION CYCLE` block now reads `"Case file shifted again: the user has now flagged the prior read as off across two consecutive rebuild cycles ..."` AND the coach-move line names `"second rebuild cycle"` + the three anti-overclaim rails.
    - The legacy first-cycle copy (`"Case file just shifted:"`) does NOT also surface.
    - The round-32 verdict block (`"Case file rebuild verdict:"`) does NOT surface (the ack was dropped on this rebuild).
13. Finish one more followed rep so the second-cycle change ages out of `isFresh`. Open Ask Noum; confirm:
    - The generic `"- Last course change: ... (after a prior pushback rebuild) (<basis>)."` line surfaces.
    - The `"- Repeated-adapt note: ..."` follow-up surfaces below it.
    - Round 31 + round 32 both dark.
14. Trigger an engine-only lever shift after a second-cycle entry sits in history. Confirm the new course-change reason reads as engine-only (no markers) AND that `documentsSecondCyclePushback` returns false on the new entry → the repeated-adapt note does NOT fire on this turn. The note is ack-driven only; an engine-only shift today is not a third user-pushback cycle.
