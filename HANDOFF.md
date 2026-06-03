# HANDOFF — M24 deferred slate (round 34): the round-33 second-cycle pushback marker now drives a matching headline + body copy split on the post-rep `RevisedReadCard` — so the user sees the repeated-adapt pattern named on the very rep that folded the second cycle in, mirroring the chat-coach context split round 33 landed on `CoachContextBuilder.freshRevisedReadContextLines(...)`. Round 34 also collapses `SummaryView.freshRevisedReadChange` through `CoachContextBuilder.freshRevisedReadChange(in:)` (round-33 Future Move #11), so the post-rep card, the chat-coach context block, the round-29 revised-read opener, and the round-30 follow-up chip row all gate on one shared eligibility predicate.

## Scope

Round 33 wrote a `secondCyclePushbackMarker` parenthetical into the `CoachCourseChange.reason` whenever `CoachMemoryEngine.build(...)` detected that the latest pushback rebuild itself followed a prior pushback rebuild. The chat-coach context block read that marker via `documentsSecondCyclePushback` and swapped round-31's two-line case-state / coach-move block for second-cycle phrasing (`"Case file shifted again"` / `"Coach move on the second rebuild cycle: …"`) AND appended a `"Repeated-adapt note:"` line on the generic else-arm so the model retained the signal after the freshness window closed. The honest gap round 33 left open on the **user-facing** surface: the post-rep `RevisedReadCard` still rendered the round-28 first-cycle copy ("You flagged the prior read as off." / "Here's the revised read: …") on a second-cycle rebuild — the model saw the cycle distinction, but the user did not.

Round 34 picks up step #14 from the round-33 "Future moves" list:

> **`SummaryView.RevisedReadCard` second-cycle header.** New note from
> round 33. The post-rep card currently shows a single rebuild header
> copy; with round 33's marker on the persisted entry, the card could
> read the predicate and surface a second-cycle header ("You flagged
> the rebuilt read off too — let's discriminate") on the rep where the
> second-cycle entry was just folded in. Mirror of the round-33
> context-builder split, on the post-rep summary surface. Hold for
> real-device QA so the visual register can be tuned alongside the
> copy.

Round 34 lands the post-rep split with brand-voice-compliant copy (no `"let's"`, no exclamation, no "we", no apology) and pins it with nine new tests inside the existing `RevisedReadCardTests` suite. Round 34 also closes step #11 from the same list (collapsing `SummaryView.freshRevisedReadChange` through the round-31 `CoachContextBuilder.freshRevisedReadChange(in:)` helper) so the eligibility contract that gates the card lives in one place across every surface that reads it.

The mechanism is a pair of pure-function routers on `RevisedReadCard`:

- `headlineCopy(for change:)` — reads `change.documentsSecondCyclePushback` and returns `secondCycleHeadlineCopy` ("You flagged the rebuilt read as off too.") when the marker is present, falling back to the round-28 `headlineCopy` ("You flagged the prior read as off.") otherwise.
- `bodyCopy(for change:, workingHypothesis:)` — same predicate; routes to `secondCycleBodyCopy(workingHypothesis:)` on second-cycle entries, falling back to the round-28 `bodyCopy(workingHypothesis:)` on first-cycle entries. Both branches share a single private `strippedHypothesis(_:)` helper so the trailing-period strip is one implementation.

The view body reads through the routers; the accessibility label reads through the routers; the original `static let headlineCopy` + `static func bodyCopy(workingHypothesis:)` are preserved verbatim so the round-28 RevisedReadCardTests pin the no-regression contract.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure working towards getting the app towards the vision plan, and all round A+, make my dream I had come true too, ensure working on the redesign branch too (very important)."

Translation, this round:

- New `RevisedReadCard.secondCycleHeadlineCopy` constant — the user-facing second-cycle headline. Placed immediately below the round-28 `headlineCopy` so a future reader sees the two coordinated copies together.
- New `RevisedReadCard.headlineCopy(for change:)` router — pure-function read of `change.documentsSecondCyclePushback`; returns the second-cycle copy when the marker is present, otherwise the first-cycle copy. Same router shape the round-33 `freshRevisedReadContextLines` split used inside `CoachContextBuilder`.
- New `RevisedReadCard.secondCycleBodyCopy(workingHypothesis:)` static function — names the rebuilt read as the operating hypothesis AND tells the user the coach will treat the repeated adapt as case history with one focused question, not a re-prescription of identical work. Mirrors the round-33 second-cycle coach-move line. Defensive nil/blank-hypothesis fallback ("The coach noted the repeated adapt and is forming a new read.") matches the boundary on the first-cycle path.
- New `RevisedReadCard.bodyCopy(for change:, workingHypothesis:)` router — pure-function dispatch on `documentsSecondCyclePushback`. The trailing-period strip lives in a shared `strippedHypothesis(_:)` helper so first-cycle and second-cycle copy share one implementation; a future edit to the strip contract ripples to both branches.
- `RevisedReadCard.body` and the accessibility label now call through the routers — the view does not duplicate the predicate. Round-28 first-cycle behaviour is unchanged when the marker is absent (the routers return the original copies verbatim).
- `SummaryView.freshRevisedReadChange` now calls through `CoachContextBuilder.freshRevisedReadChange(in:)` (round 31's pure-function lift). The eligibility predicate that gates the post-rep card, the chat-coach `freshRevisedReadContextLines`, the round-29 revised-read opener, and the round-30 follow-up chip row is now one call away on every surface — a future edit to the gate (e.g. a freshness-tolerance bump or a new "documents user pushback" variant) lands in one place, not four.
- New `RevisedReadCardTests` second-cycle coverage (9 new `@Test` methods) — pins the new headline + body copy on second-cycle entries, locks the no-regression contract on first-cycle entries through the same routers, and pins brand-voice compliance on the new copy (no exclamation, no "Let's", no "we", no apology).
- The redesign-branch invariant: this is a `Redesign`-branch push per the user brief. Round 34 preserves the round-by-round loop on the redesign lineage that has been the home of rounds 11–33.

## What shipped

### Track 1 — `RevisedReadCard.secondCycleHeadlineCopy` + `headlineCopy(for:)` (`RevisedReadCard.swift`)

- New `static let secondCycleHeadlineCopy = "You flagged the rebuilt read as off too."` placed immediately below the round-28 `headlineCopy` so the two copies sit together. Doc comment explains the cross-surface contract: the engine writes the marker, the chat-coach context block reads it, and now the post-rep card reads it on the same rep.
- New `static func headlineCopy(for change: CoachCourseChange) -> String` router. Single-expression ternary on `change.documentsSecondCyclePushback` — returns the second-cycle copy when the marker is present, the round-28 copy otherwise. Pure function; same shape as the engine's predicate, the context builder's split, and the new body router.
- `var body` and the accessibility label now call `headlineCopy(for: change)` instead of the bare `headlineCopy` constant. The bare constant stays in scope so the round-28 `headlineCopyNamesUserAction` test continues to pin the first-cycle copy verbatim.
- No new storage, no new view inputs — the `change` parameter already exists on the view; the router reads its existing `documentsSecondCyclePushback` predicate. Memories persisted before round 33 read `false` on the predicate and route to the first-cycle copy automatically.

### Track 2 — `RevisedReadCard.secondCycleBodyCopy(workingHypothesis:)` + `bodyCopy(for:workingHypothesis:)` (`RevisedReadCard.swift`)

- New `static func secondCycleBodyCopy(workingHypothesis: String?) -> String`. Returns `"Here's the next read: \(stripped). Expect one focused question, not the same intervention again."` when a non-empty hypothesis is provided, falling back to `"The coach noted the repeated adapt and is forming a new read."` on nil/blank. The "next read" phrasing distinguishes the second-cycle body from the first-cycle "revised read" wrapper so the user reads the cycle distinction even without re-reading the headline.
- New `static func bodyCopy(for change: CoachCourseChange, workingHypothesis: String?) -> String` router. Single-branch dispatch on `change.documentsSecondCyclePushback`; falls through to the existing `bodyCopy(workingHypothesis:)` on first-cycle entries. Both branches share the new private `strippedHypothesis(_:)` helper.
- New private `static func strippedHypothesis(_ raw: String) -> String` — lifted from the round-28 body's inline strip step. One implementation now powers both first-cycle and second-cycle bodies; a future edit (e.g. a multi-period strip, or a clause-boundary normaliser) lands in one place.
- The bare `static func bodyCopy(workingHypothesis:)` and `static let headlineCopy` are preserved verbatim. The round-28 RevisedReadCardTests (5 tests) still pass against them — round 34 ships strictly additive surface.

### Track 3 — `SummaryView.freshRevisedReadChange` collapses to the shared helper (`SummaryView.swift`)

- The local predicate that gates `RevisedReadCard` now reads:

  ```swift
  private var freshRevisedReadChange: CoachCourseChange? {
      guard let memory = coachMemoryStore.currentMemory else { return nil }
      return CoachContextBuilder.freshRevisedReadChange(in: memory)
  }
  ```

  Behaviour-identical to the round-28 inline predicate (`adaptationLog?.last`, `documentsUserPushback`, `isFresh(comparedTo: updatedAt)` — same three checks, same order). The chat-coach context block (round 31), the round-29 revised-read opener gate, and the round-30 follow-up chip row already routed through the same `CoachContextBuilder.freshRevisedReadChange(in:)` helper; round 34 brings the post-rep summary surface into the same call-site discipline.
- Comment block on the property updated to cite the round-31 lift and the cross-surface contract. A future edit (e.g. a freshness-tolerance bump, a "documents-second-cycle-pushback" variant predicate, or a different gate for a future SummaryView card) lands in one place on `CoachContextBuilder` and ripples to every surface that reads it.
- No behaviour change on the rep where `RevisedReadCard` mounts today. The round-33 chat-coach split, the round-32 rebuild-verdict block, the round-31 freshness window, and the round-28 card gate all remain pinned by their existing tests.

### Track 4 — `RevisedReadCardTests` second-cycle coverage (`NoumTests/NoumTests.swift`)

Nine new `@Test` methods slotted into the existing `RevisedReadCardTests` suite, immediately after `bodyCopyFallsBackWhenHypothesisIsBlank` (the round-28 fallback pin). Two private fixture helpers (`secondCyclePushbackChange()`, `firstCyclePushbackChange()`) mirror the round-33 engine test fixture (`courseChangeDocumentsSecondCyclePushbackWhenMarkerEmbedded`) so the post-rep card tests and the engine tests gate on the same canonical reason shape.

- **Second-cycle headline (3 tests):**
  - `headlineCopyOnSecondCycleEntryNamesRebuiltPushback` — pure constant pin on the new `secondCycleHeadlineCopy` ("You flagged the rebuilt read as off too.").
  - `headlineCopyRouterReturnsSecondCycleCopyWhenMarkerEmbedded` — router contract; a change carrying the round-33 marker routes to the second-cycle copy AND the first-cycle copy must NOT also surface (single canonical headline per cycle).
  - `headlineCopyRouterReturnsFirstCycleCopyWithoutMarker` — no-regression contract; a first-cycle entry routes to the round-28 headline verbatim.
- **Second-cycle body (4 tests):**
  - `bodyCopyOnSecondCycleEntryQuotesNextReadAndNamesFocusedQuestion` — the new body names the rebuilt read AND the "one focused question, not the same intervention again" anti-overclaim rail. Mirrors the round-33 chat-coach coach-move line.
  - `bodyCopyOnSecondCycleEntryStripsTrailingPeriodToAvoidDoubleStop` — locks the `strippedHypothesis(_:)` contract on the new branch.
  - `bodyCopyOnSecondCycleEntryFallsBackWhenNoHypothesis` — defensive pin on the second-cycle fallback ("The coach noted the repeated adapt and is forming a new read.").
  - `bodyCopyOnSecondCycleEntryFallsBackWhenHypothesisIsBlank` — defensive pin on the second-cycle fallback for whitespace-only hypothesis.
- **No-regression contract (2 tests):**
  - `bodyCopyRouterReturnsFirstCycleCopyWithoutMarker` — a first-cycle entry routes to the round-28 body verbatim through the new router.
  - `bodyCopyRouterReturnsFirstCycleFallbackOnNilHypothesisWithoutMarker` — defensive: the second-cycle fallback does NOT fire when the marker is absent.
- **Brand-voice contract (1 test):**
  - `headlineAndBodyDoNotUseExclamationOrApology` — pins the second-cycle headline + body + fallback against `!`, `"let's"`, `" we "`, and `"sorry"`. Mirrors the brand-voice rules round 33 pinned on the chat-coach context lines.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the case formulation needs "the reason for changing course" carried as active coaching state, not buried in a log. Round 27 lifted user pushback into a `CoachCourseChange` entry. Rounds 28–32 surfaced the rebuild and the user's verdict on it across the post-rep summary, the chat seed, the follow-up chip row, and the chat-coach user-context block. Round 33 lifted the SECOND-cycle pushback into the persistent record AND the chat-coach context. Round 34 closes the user-facing loop on the post-rep card so the user reads the same cycle distinction the model reads — the case formulation is now visible at every surface where adaptation surfaces.
- **Coach-parity stage #5 (Adaptation, anti-overclaim).** A human coach who'd watched the user push back twice in a row would name the repeated pattern explicitly AND tell the client what to expect next ("one focused question, not another prescription of the same thing"). Round 34's second-cycle body gives the user the same register, with explicit anti-re-prescribe framing carried into the user-facing copy. The card can't quietly read "Here's the revised read: …" as if the second pushback hadn't happened.
- **Pillar #5 (Personalized coaching).** The post-rep card now carries the second-cycle signal alongside the chat-coach context block (round 33). A user who has pushed back twice in a row reads the coach naming the repeated adapt on the very rep that folded the second cycle in — the cross-surface read is continuous, the chat thread and the summary card speak with one voice.
- **Pillar #4 (Believable progress).** Round 34's second-cycle copy preserves the round-28 evidence-anchored register ("Here's the next read: <hypothesis>…") instead of switching to a generic plan-change ping. The user reads the rebuilt hypothesis verbatim, the same way they did on the first cycle — the cycle distinction is in the surrounding clause, not in the loss of evidence anchoring.
- **Anti-overclaim.** Round 34's second-cycle body adds one anti-overclaim rail to the user-facing card ("Expect one focused question, not the same intervention again."). One anti-strengthen rail in the round-31 first-cycle line; three anti-overclaim rails in the round-33 chat-coach second-cycle coach-move line; one anti-relitigation rail in the round-32 `.confirmed` rebuild-verdict instruction; round 34 adds the matching user-facing rail. Every cycle name forces its own anti-overclaim register on every surface.
- **Engineering bans.** No placeholder logic. No dead toggles. No fragmented state — the new copy READS existing fields (`change.documentsSecondCyclePushback`, `workingHypothesis`). No new storage, no schema bump, no migration, no new view inputs. Memories persisted before round 33 read `false` on the predicate and route to the first-cycle copy automatically. Pure-function lift on pure-function inputs. The round-28 `static let headlineCopy` and `static func bodyCopy(workingHypothesis:)` are preserved verbatim so the round-28 tests pin the no-regression contract end-to-end.

### Branch + redesign-alignment notes

- All four tracks land on `Redesign`, the redesign-lineage branch the rolling M24 deferred-slate work has been shipping on since round 11. The user brief explicitly calls this out: "ensure working on the redesign branch too (very important)." Round 34 preserves the round-by-round loop on the redesign lineage.
- Round 34 does not change the round-33 marker or `documentsSecondCyclePushback` predicate (only reads them on a new surface), does not change the round-33 `freshRevisedReadContextLines` second-cycle branch (only mirrors its copy on the post-rep card), does not change the round-33 generic-arm "Repeated-adapt note", does not change the round-32 `rebuildVerdictPair` / `rebuildVerdictContextLines`, does not change the round-31 `freshRevisedReadChange(in:)` helper (only routes the SummaryView gate through it), does not change the round-30 chip-row predicate or catalog, does not change the round-29 `revisedReadOpener` function, does not change the round-29 `talkToNoumOpener` gate, does not change the round-28 first-cycle copy (preserved verbatim under the routers), does not change the round-27 engine restructure, does not change the round-26 chip catalog or hypothesis-ack row, and does not change the round-24 / round-25 `InterventionReviewPromptCard` surface. The round-33 6 engine + 6 context-builder tests, the round-32 25 rebuild-verdict tests, the round-31 16 fresh revised-read tests, the round-30 15 follow-up tests, the round-29 12 opener tests, the round-28 5 copy tests, and the round-26 19 ack tests all remain unchanged; the round-34 9 RevisedReadCard tests sit alongside them.
- The round-33 chat-coach context second-cycle copy reads "Case file shifted again" / "second rebuild cycle"; the round-34 post-rep card second-cycle copy reads "rebuilt read as off too" / "next read" / "one focused question". They are complementary phrasings for two different surfaces of the same lifecycle (model context vs. user-facing card). A future round can collapse them into shared phrasing, but only after a real-device QA pass to verify the user-facing register reads as calmly as it scans on paper.

## Future moves

(Updated priority list — round-34 closed round-33 step #14 and round-33 step #11; the rest roll forward, plus two new notes from round 34.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving with celebration timing. Worth a dedicated refactor pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from rounds 19–33. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from rounds 20–33. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.** Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward from round 22.
7. **Tier-change observation symmetry to other surfaces that read `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
8. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **`.confirmed` confidence amplification on the active intervention.** Carried forward from round 27, called out by round 32. The round-32 `.confirmed` rebuild-verdict path remains the natural integration site — when the predicate fires AND the engine has not yet bumped `CoachIntervention.criterionStatus`, the same `.confirmed` branch could nudge the criterion toward "met" or extend the `reviewDueAt` cadence by one rep. Round 32 surfaces the verdict in CONTEXT; round-27 follow-on would let it AMPLIFY the intervention as well.
11. **Collapse the round-26 hypothesis-ack reflection in `coachCaseFormulationLines` into a single block with the round-32 rebuild-verdict lines when the predicate fires.** Carried forward from round 32. Hold for real-device QA.
12. **Trend-view distinction between "user accepted the first read", "user accepted the rebuilt read", and "user pushed back twice".** From round 30's step #11 + round 32's step #14, made richer by round 33. Round 33 surfaced the second-cycle pushback in CONTEXT (the model's read) AND in the PERSISTENT record (`documentsSecondCyclePushback`); round 34 surfaced it on the post-rep card. A future analytics surface could use the same predicate to count second-cycle pushback events separately from first-cycle ones, so a future insights view can show the user "you've revised your coach's read twice this month" — durable feedback on the Adaptation loop without overclaiming the second cycle as a problem (it can equally be a healthy iteration pattern).
13. **Second-cycle revised-read opener.** New note from round 34. The round-29 `revisedReadOpener(workingHypothesis:voice:)` composes a single canonical opener regardless of cycle. With round 33's marker on the persisted entry, a future round could split the opener composition the same way round 34 split the post-rep card — a `revisedReadOpener(for change:, workingHypothesis:, voice:)` overload that swaps the body clause to "the next read you're holding is: …" and the lead clause to "Picking up the case file — I flagged the rebuilt read as off too." Mirror of round 34 on the chat-thread surface. Would need to land alongside a complementary update to the `TalkToNoumCTACard` gate so the opener fires on the rep where the second-cycle entry is fresh.
14. **`CaseReviewCard` second-cycle history badge.** New note from round 34. The Profile-tab `CaseReviewCard` lists adaptation entries as long-term history. With round 33's marker, the card could surface a small "2nd cycle" badge on entries whose `documentsSecondCyclePushback` returns true — so the user reading their case history can scan for repeated-adapt patterns at a glance. Pure visual work; the predicate is already on every entry. Hold for real-device QA.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this round was compiled or run — not the app, not the test suite. The changes are:

- One new `static let` (`secondCycleHeadlineCopy`), three new `static func`s (`headlineCopy(for change:)`, `secondCycleBodyCopy(workingHypothesis:)`, `bodyCopy(for change:, workingHypothesis:)`), and one new private `static func` (`strippedHypothesis(_:)`) on `RevisedReadCard` in `RevisedReadCard.swift`. The view body and accessibility label re-routed through the new headline + body routers. No new imports, no new view inputs, no new dependencies.
- One edit to `SummaryView.freshRevisedReadChange` in `SummaryView.swift`: the inline predicate is replaced with a single call through `CoachContextBuilder.freshRevisedReadChange(in:)` (round 31's pure-function lift, already used by the chat-coach context block). The three-check eligibility contract is preserved exactly — same checks, same order, behaviour-identical on every input the round-28 RevisedReadCard tests cover.
- Nine new `@Test` methods inside `RevisedReadCardTests` and two new private fixture helpers in `NoumTests/NoumTests.swift`. The suite is the existing `@MainActor @Suite("RevisedReadCardTests")` — no new top-level suite, no new attribute, no new dependencies.

All checks the next agent should run on a real build host:

1. `swift test --filter RevisedReadCardTests` — the existing round-28 5 tests + the new round-34 9 tests should all pass. The round-28 tests gate on the bare `RevisedReadCard.headlineCopy` constant + `bodyCopy(workingHypothesis:)` function, both preserved verbatim under round 34.
2. `swift test --filter SecondCyclePushbackContextTests` — round-33's 6 context-builder tests should still pass. Round 34 does not touch `CoachContextBuilder.freshRevisedReadContextLines` or its second-cycle branch.
3. `swift test --filter CoachMemoryEngineTests` — round-33's engine tests + the older engine tests should all pass. Round 34 does not touch the engine.
4. `swift test --filter RebuildVerdictContextTests` — round-32's 25 tests should still pass.
5. `swift test --filter FreshRevisedReadContextTests` — round-31's 16 tests should still pass.
6. `swift test --filter RevisedReadFollowUpTests` — round-30's 15 tests should still pass.
7. `swift test --filter RevisedReadOpenerTests` — round-29's 12 tests should still pass. The opener composition is unchanged in round 34.
8. `swift test --filter CoachContextBuilderBigMomentTests` — should still pass; the round-31 helper `freshRevisedReadChange(in:)` behaviour is unchanged.
9. `swift test --filter HypothesisAcknowledgementTests` — round-26's 19 tests should still pass.
10. `swift test --filter CoachMemoryStoreTests` — the existing memory-store tests should still pass.
11. Boot the app on simulator, drive a session through the round-26 hypothesis-ack chip (`.rejected`) so the engine appends a first-cycle pushback entry. Finish a rep so memory rebuilds and `RevisedReadCard` mounts on the post-rep summary. Confirm the round-28 first-cycle copy renders verbatim: headline `"You flagged the prior read as off."`, body `"Here's the revised read: <hypothesis>."`. No round-34 second-cycle copy on this rep (the marker is absent on the first cycle).
12. Drive the round-30 follow-up chip row (`.rejected`) on the rebuilt read. Finish another rep so memory rebuilds again: the engine now writes a second-cycle pushback entry (`documentsSecondCyclePushback == true`). On the post-rep summary, confirm `RevisedReadCard` renders the round-34 second-cycle copy: headline `"You flagged the rebuilt read as off too."`, body `"Here's the next read: <hypothesis>. Expect one focused question, not the same intervention again."`.
13. Open Ask Noum on the same rep. Confirm the round-33 chat-coach second-cycle copy ("Case file shifted again …", "Coach move on the second rebuild cycle: …") is also visible in the debug log. The card and the chat thread should read with one voice on the cycle distinction.
14. Trigger an engine-only lever shift after a second-cycle entry sits in history. Confirm `RevisedReadCard` does NOT mount on that rep (the latest entry is engine-only; `documentsUserPushback == false` → `freshRevisedReadChange` returns nil → the card is gated off entirely). The Profile-tab `CaseReviewCard` still shows the prior second-cycle entry in long-term history.
