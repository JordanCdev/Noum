# HANDOFF — M24 deferred slate (round 41): TONE-DRILL SOLVED freshness window for the chat-coach context — the chat coach now names a closed tone-drill win within the recency window AND structurally moves on once the win ages out, instead of parroting the same closed gap on every reply for months. Pure-context surface, no engine state change, no schema bump, no view changes. New `CoachContextBuilder.toneDrillSolvedRecencyDays` constant + `toneDrillSolvedIsFresh(_:now:)` pure predicate; existing TONE-DRILL SOLVED section in `userContext` now gates on the predicate, anchored against the user's most-recent practice rep.

## Scope

`IMHistorySummary.toneDrillResolved(from:)` returns the resolved read FOREVER once a scenario crosses the drill bar. The engine self-clears only on a real relapse below the threshold, which is correct for the recommendation engine (a once-solved drill should not be re-prescribed out of nowhere). But surfaced verbatim into the chat-coach context block since round 13, it has meant the chat coach reads the same TONE-DRILL SOLVED section on every reply for months after the crossing — beating a dead horse on a win the user closed weeks ago, exactly the register a human coach moves past.

That is a real coach-parity gap on stage #3 (Intervention) and stage #4 (Adaptation). A human coach who watched a user close a tone gap would name the win, hold it for a few sessions while the user banks the new pattern, then move on to the next target — exactly the in-context guidance the SOLVED line itself has carried since round 13 ("name the win once and point them at the next target rather than re-prescribing the solved drill"). But the in-context guidance is a soft prompt to the model; the structural backstop has been missing.

Round 41 closes the gap with the LIGHTEST possible surface: a new pure constant + pure predicate on `CoachContextBuilder`, plus a one-clause additive gate on the existing `if let resolved = IMHistorySummary.toneDrillResolved(from: sessions)` block in `userContext`. Past the recency window, the section drops entirely — the chat coach has no SOLVED context to reference and so the model can no longer parrot a months-old win even if it wanted to.

Defensive scoping (intentional restraint, same shape as rounds 37–40):

- **Pure context surface, not engine state change.** No engine-level change to `toneDrillResolved` or the recommendation blueprint (the recommendation engine still self-clears only on a real relapse — the persistence-of-victory contract is preserved). Round 41 keeps the impact bounded to the chat coach's context block, the same surface rounds 30–40 fan out across, so the new gate is testable in isolation and reversible if real-conversation evidence shows the window as too tight or too generous.
- **Recency-anchored against the user's own cadence, not wall-clock.** The anchor is `sessions.lazy.map(\.date).max()` — the user's most-recent practice rep, not `Date()`. This makes the predicate pure and intrinsically test-stable (tests construct sessions with known dates and never depend on the system clock), and it reads as the semantically right thing: "fresh relative to the user's cadence." A user who's actively practicing other scenarios deserves to see the win named for longer than a user who hasn't practiced at all in a month — the gate is about the chat coach moving with the user's training, not the wall clock.
- **Cross-surface symmetry with round 38.** The new `toneDrillSolvedRecencyDays = 14` mirrors the `repeatedPushbackRecencyDays = 14` constant exactly by deliberate cross-surface symmetry — "win is fresh enough to name" and "pushback verdict is fresh enough to dampen" share the same coach-parity ramp on stage #3 (Intervention) and #4 (Adaptation). A single number is easier for a future round to tune than two parallel constants, and a cross-surface-constants test pins the equality so a future tune of one forces consideration of whether to tune the other too.
- **Inclusive 14-day boundary.** A win at exactly 14 days old still surfaces; a win 14 days + 1 second old drops. Same shape as rounds 38/39/40's identical recency-pin contracts. Pinned by both halves of the boundary (`predicateFiresAtExactRecencyBoundary` + `predicateDropsJustBeyondRecencyBoundary` + a structural userContext boundary test that pins both halves end-to-end), so a future tune of the constant doesn't silently drift the boundary by a day on one half.
- **Defensive negative-elapsed guard.** A `now` that pre-dates `lastEvaluatedDate` is a bad anchor; the predicate refuses to fire rather than returning true on a mathematically-fresh-but-impossible state. Pinned by `predicateDropsWhenNowPredatesLastEvaluatedDate` so a future caller that passes a stale `now` doesn't silently re-surface a dropped win.
- **Per-scenario gate, not a global SOLVED-off switch.** The freshness gate applies to the single resolved scenario `toneDrillResolved(from:)` returns (the freshest win across all scenarios per the existing sort). A drill in flight in one scenario (TRAJECTORY) and a recently-resolved win in another (SOLVED) can — and should — both surface, exactly as round 13 designed. The freshness gate ONLY drops the SOLVED line when the freshest win itself is stale; it never drops a TRAJECTORY line, and it never blocks a fresh SOLVED in scenario A just because scenario B carries a trajectory.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure working towards getting the app towards the vision plan, and all round A+, make my dream I had come true too, ensure working on the redesign branch too (very important)."

Translation, this round:

- New `CoachContextBuilder.toneDrillSolvedRecencyDays: Int = 14` static constant — placed in a dedicated `MARK: - Tone-drill solved freshness window (round 41)` block immediately after the existing `toneDrillResolvedLines(for:)` helper so the round-13 + round-41 surfaces read as one coherent block in the file.
- New `CoachContextBuilder.toneDrillSolvedIsFresh(_:now:)` static predicate — pure check that `now.timeIntervalSince(resolved.lastEvaluatedDate)` is in `[0, toneDrillSolvedRecencyDays * 86_400]`. Defensive negative-elapsed guard rules out a stale `now`.
- One additive gate in the existing TONE-DRILL SOLVED block of `CoachContextBuilder.userContext`: the `if let resolved = IMHistorySummary.toneDrillResolved(from: sessions)` line now also requires (a) `sessions.lazy.map(\.date).max()` to be non-nil (always true when `resolved` is non-nil, since the SOLVED scenario itself contributed a session to `sessions`) AND (b) `toneDrillSolvedIsFresh(resolved, now: <that max date>)` to return true. Every other line in the block is preserved verbatim.
- New `@MainActor @Suite("ToneDrillSolvedFreshnessTests")` test suite (11 `@Test` methods + 2 private fixture helpers — one for the predicate, one for the userContext integration) — slotted immediately after the existing `ToneDrillResolvedContextTests` suite so the round-13 + round-41 surfaces read as one block in the test file. Pins the pure predicate on every branch, the userContext integration on fresh/stale/boundary states, the cross-surface contract that a fresh SOLVED + active TRAJECTORY in another scenario both still surface, AND the cross-surface-constants symmetry with `repeatedPushbackRecencyDays`.
- The redesign-branch invariant: this is a `Redesign`-branch push per the user brief. Round 41 preserves the round-by-round loop on the redesign lineage that has been the home of rounds 11–40.

## What shipped

### Track 1 — `CoachContextBuilder.toneDrillSolvedRecencyDays` constant + `toneDrillSolvedIsFresh(_:now:)` predicate (`Noum/CoachContextBuilder.swift`)

- New `static let toneDrillSolvedRecencyDays: Int = 14` — explicit `Int` to match the existing `repeatedPushbackRecencyDays: Int = 14` declaration shape; the test suite pins both constants equal so a future tune of one forces consideration of the other.
- New `static func toneDrillSolvedIsFresh(_ resolved: IMToneDrillResolved, now: Date) -> Bool` — pure predicate. Guards `elapsed >= 0` then checks `elapsed <= TimeInterval(toneDrillSolvedRecencyDays * 24 * 60 * 60)` (matches the round-38 `recencyInterval` shape).
- Pinned by SIX predicate tests (`predicateFiresWhenNowEqualsLastEvaluatedDate`, `predicateFiresWithinTheRecencyWindow`, `predicateFiresAtExactRecencyBoundary`, `predicateDropsJustBeyondRecencyBoundary`, `predicateDropsOutsideRecencyWindow`, `predicateDropsWhenNowPredatesLastEvaluatedDate`).

### Track 2 — gate on the existing TONE-DRILL SOLVED block in `userContext` (`Noum/CoachContextBuilder.swift`)

- The `if let resolved = IMHistorySummary.toneDrillResolved(from: sessions)` block now also requires `sessions.lazy.map(\.date).max()` to be non-nil AND `toneDrillSolvedIsFresh(resolved, now: <that max date>)` to return true. The header line ("TONE-DRILL SOLVED (a past tone gap the user has closed)") and the two-line `toneDrillResolvedLines(for:)` payload are preserved verbatim — only the entry condition changed.
- Anchored against `sessions.lazy.map(\.date).max()` — the user's most-recent practice rep — so the predicate is pure, intrinsically test-stable, and reads as "fresh relative to the user's cadence." A user actively practicing other scenarios deserves the win named for longer; a user who's stopped practicing entirely sees the win age out at 14 days flat.

### Track 3 — `ToneDrillSolvedFreshnessTests` suite (`NoumTests/NoumTests.swift`)

Eleven new `@Test` methods inside a new `@MainActor @Suite("ToneDrillSolvedFreshnessTests")` suite, slotted immediately after the existing `ToneDrillResolvedContextTests` suite (the existing `PostRepCoachNoteToneTrajectoryTests` block follows). Two private fixture helpers (`imSession(scenario:targetTone:actualTone:daysOffset:)` mirroring the existing `ToneDrillResolvedContextTests` helper, and `resolvedFixture(daysSinceBase:)` for the predicate tests).

- **Pure predicate — happy path (2 tests):**
  - `predicateFiresWhenNowEqualsLastEvaluatedDate` — zero elapsed time → fresh by definition.
  - `predicateFiresWithinTheRecencyWindow` — 7 days elapsed → comfortably inside the 14-day window.
- **Pure predicate — boundary (2 tests):**
  - `predicateFiresAtExactRecencyBoundary` — inclusive 14-day boundary mirrors rounds 38/39/40's identical recency-pin shape.
  - `predicateDropsJustBeyondRecencyBoundary` — 14 days + 1 second → drops. The exact strict-greater-than boundary contract.
- **Pure predicate — outside (1 test):**
  - `predicateDropsOutsideRecencyWindow` — 30 days elapsed → well past the window.
- **Pure predicate — defensive (1 test):**
  - `predicateDropsWhenNowPredatesLastEvaluatedDate` — a `now` that pre-dates `lastEvaluatedDate` returns false. Defensive pin so a future caller that passes a stale `now` doesn't silently re-surface a dropped win.
- **userContext integration (3 tests):**
  - `userContextSurfacesSolvedWhenLastEvaluatedRepIsFresh` — full pipeline carries the SOLVED section when the SOLVED scenario's most-recent rep IS the user's most-recent rep (zero elapsed).
  - `userContextDropsSolvedWhenLastEvaluatedRepIsStale` — SOLVED scenario last evaluated 30+ days before the anchor (most-recent rep is in a different scenario) drops the section; the engine still considers it resolved, but the chat coach moves on.
  - `userContextLayersFreshSolvedOverActiveTrajectoryInOtherScenario` — round 13's TRAJECTORY-and-SOLVED coexistence contract is preserved across the freshness gate: a fresh SOLVED in one scenario surfaces alongside an active TRAJECTORY in another.
- **userContext integration — boundary (1 test):**
  - `userContextDropsSolvedAtExactRecencyBoundaryWhenAnchorMovesPast` — boundary contract end-to-end. SOLVED scenario evaluated up to `daysOffset -14`; anchor on the boundary (a workUpdate rep at `daysOffset 0`) fires the section; moving the anchor 1 day past (workUpdate at `daysOffset 1`) drops it. Pinning both halves of the boundary structurally so a future tune of the constant doesn't silently drift the boundary by a day on one half.
- **Cross-surface-constants symmetry (1 test):**
  - `recencyWindowConstantMatchesRound38PushbackWindow` — pins `toneDrillSolvedRecencyDays == repeatedPushbackRecencyDays`. A future round that tunes one forces consideration of whether to tune the other.

### Vision alignment

- **Coach-parity stage #3 (Intervention) — "prescribe a drill for a reason, name the observable target, and define what improvement would look like before the user starts."** Per `docs/VISION.md`. Round 41 strengthens the Intervention closure: the chat coach can name the closed gap, hold it for the window, then structurally move on to the NEXT target instead of being structurally anchored to the closed one. The "name the win once and point them at the next target" guidance the SOLVED line itself has carried since round 13 now has a structural backstop — the in-context guidance was the soft prompt; the freshness gate is the hard rail.
- **Coach-parity stage #4 (Adaptation) — "compare response across multiple attempts and either reinforce, vary, or replace the intervention with an explained rationale."** Round 41 closes the Adaptation feedback loop on the time axis: a once-prescribed drill that the user has BANKED for 14+ days drops out of the chat-coach context entirely so the coach naturally adapts toward the current target rather than rehearsing the closed-but-still-resolved one.
- **Pillar #5 (Personalized coaching).** A coach who keeps referencing a closed win on every conversation reply for months reads as a coach who isn't keeping up with the user. Round 41 makes the chat-coach context cadence-aware on the win surface, the same way it has been on the case-state matrix (rounds 38/40 via `repeatedPushbackRecencyDays`).
- **Pillar #4 (Believable progress).** The win is real evidence (the user's own reps closed the gap) and the coach can still name it — within the window — exactly as it did before round 41. Past the window, the win does not disappear from the user-facing surfaces (the hero ribbon, the post-rep coach note prose, the recommendation engine's persistence-of-victory contract — all preserved verbatim). The change is ONLY which surface the chat coach reads from on every reply.
- **Pillar #3 (Conversational intelligence).** The chat-coach context that surfaces SOLVED is the same surface that surfaces TRAJECTORY, the rep-recents, the user's stated goal, the case formulation, the active intervention, and the rebuild-verdict matrix. Round 41 keeps the SOLVED line in register with the rest of the surfaces — they all gate honestly on what is fresh enough to inform the current chat reply.
- **Anti-overclaim.** No engine state mutation, no claim that the drill caused the win, no claim that the user's win is invalidated by the gate, no schema bump, no migration. The freshness gate ONLY narrows the chat-coach context surface; every other surface the win flows through (hero ribbon, post-rep note, recommendation engine, TRAJECTORY engine self-clearing on relapse) is preserved verbatim.
- **Engineering bans.** No placeholder logic. No dead toggles. No fragmented state — the new predicate READS only the existing `IMToneDrillResolved.lastEvaluatedDate` field. No new storage, no schema bump, no migration, no new view inputs. Memories persisted before round 41 read correctly through the predicate automatically. Pure-function lift on pure-function inputs. The existing `toneDrillResolvedLines(for:)`, `toneDrillResolved(from:)`, `toneDrillResolved(from:scenario:)`, `toneDrillCrossing(in:scenario:currentRepId:)`, and `userContext` paths are preserved verbatim (the TONE-DRILL SOLVED block in `userContext` ONLY gains a freshness clause on its entry condition — every other line is byte-identical to round 40).

### Branch + redesign-alignment notes

- All three tracks land on `Redesign`, the redesign-lineage branch the rolling M24 deferred-slate work has been shipping on since round 11. The user brief explicitly calls this out: "ensure working on the redesign branch too (very important)." Round 41 preserves the round-by-round loop on the redesign lineage.
- Round 41 does not change any of the round-40 / round-39 / round-38 / round-37 / round-36 / round-35 / round-34 / round-33 / round-32 / round-31 / round-30 / round-29 / round-28 / round-27 / round-26 surfaces; every prior suite remains unchanged; the round-41 11 `ToneDrillSolvedFreshnessTests` sit alongside them.
- The existing 4 `ToneDrillResolvedContextTests` are preserved verbatim — round 41 is purely additive on the test side. The boundary-day fixtures in the existing tests sit comfortably within the new freshness window (most-recent rep is at `daysOffset -1`, SOLVED scenario's `lastEvaluatedDate` is also at `daysOffset -1`, elapsed = 0), so no existing test changed.

## Future moves

(Updated priority list — round 41 closed the chat-coach repetition gap on the TONE-DRILL SOLVED surface. The rest roll forward, plus one new note from round 41.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving with celebration timing. Worth a dedicated refactor pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from rounds 19–40. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from rounds 20–40. Pure visual work, not crossing logic.
5. **Day-rollover refresh for long-mounted observers.** Carried forward from round 22.
6. **Tier-change observation symmetry to other surfaces that read `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
7. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried forward from round 25.
8. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
9. **Engine-level case-anchored amplification (post-round-37 escalation).** Carried forward from round 37 as a future move. Restraint pin: hold until real-conversation evidence calls for engine-level escalation.
10. **Engine-level under-repeated-pushback dampening (post-round-38 escalation).** Carried forward from round 38. Restraint pin: hold for real-conversation evidence.
11. **Engine-level case-anchored continuation (post-round-39 escalation).** Carried forward from round 39. Restraint pin: hold for real-conversation evidence.
12. **Engine-level under-pushback continuation dampening (post-round-40 escalation).** Carried forward from round 40. Restraint pin: hold for real-conversation evidence.
13. **Collapse the round-26 hypothesis-ack reflection in `coachCaseFormulationLines` into a single block with the round-32 rebuild-verdict lines when the predicate fires.** Carried forward from round 32. Hold for real-device QA.
14. **Trend-view distinction across the rebuild-verdict / case-state matrix surfaces.** Carried forward from rounds 30–40. Pure visual work; hold for real-device QA.
15. **Second-cycle ask register on the opener.** Note from round 35. Restraint pin: hold until real conversations show the cycle-agnostic ask reads as off.
16. **`CaseReviewCard` adaptation-log fuller history surface.** Note from round 36. Hold for real-device QA.
17. **`CaseReviewCard` case-anchored badge.** Note from round 37. Hold for real-device QA.
18. **`CaseReviewCard` under-pushback badge.** Note from round 38. Hold for real-device QA.
19. **`CaseReviewCard` case-anchored continuation badge.** Note from round 39. Hold for real-device QA.
20. **`CaseReviewCard` under-pushback continuation badge.** Note from round 40. Hold for real-device QA.
21. **Mirror the TONE-DRILL SOLVED freshness window onto the TONE-DRILL TRAJECTORY surface for stale ACTIVE drills.** New note from round 41. The TRAJECTORY surface fires whenever `toneDrillSignal(from:)` returns a sub-40% scenario with ≥4 evaluated reps. There is no recency gate on the latest-evaluated rep, so a scenario the user practiced 60 days ago, never returned to, and is now below the bar would surface a TRAJECTORY line on every chat reply forever. Mirror the round-41 freshness window onto TRAJECTORY: drop the TRAJECTORY section when the latest evaluated rep in the prescribed scenario is past `toneDrillSolvedRecencyDays` from the user's most-recent rep — same anchor, same window, same `Int` constant. The recommendation engine would still prescribe the drill on the next IM launch (it should — the gap is real), but the chat coach would not re-issue the trajectory commentary on a long-stale read. Hold for real-device QA OR drive in a future round once the round-41 symmetric shape lands clean. Restraint pin: do not drop TRAJECTORY on a scenario the user practiced recently but in a different mode — the cadence anchor is whole-history-most-recent, not scenario-scoped.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this round was compiled or run — not the app, not the test suite. The changes are:

- One new `static let toneDrillSolvedRecencyDays: Int = 14` and one new `static func toneDrillSolvedIsFresh(_:now:) -> Bool` on `CoachContextBuilder` in `Noum/CoachContextBuilder.swift`. Single-expression / multi-statement bodies; pure functions of the existing `IMToneDrillResolved.lastEvaluatedDate` field. No new constants beyond the recency-window one.
- One additive gate on the existing TONE-DRILL SOLVED entry condition in `CoachContextBuilder.userContext(...)`: the `if let resolved = IMHistorySummary.toneDrillResolved(from: sessions) { ... }` block now also requires `let mostRecentRepDate = sessions.lazy.map(\.date).max()` and `toneDrillSolvedIsFresh(resolved, now: mostRecentRepDate)`. Every other line in the block — the header, the helper call, the appended lines — is preserved verbatim.
- Eleven new `@Test` methods inside a new `@MainActor @Suite("ToneDrillSolvedFreshnessTests")` suite and two new private fixture helpers, in `NoumTests/NoumTests.swift`. Slotted immediately after the existing `ToneDrillResolvedContextTests` suite so the round-13 + round-41 surfaces read as one block in the test file.

All checks the next agent should run on a real build host:

1. `swift test --filter ToneDrillSolvedFreshnessTests` — the new round-41 11 tests should all pass.
2. `swift test --filter ToneDrillResolvedContextTests` — round-13's 4 tests should still pass verbatim (the boundary-day fixtures sit comfortably within the new freshness window).
3. `swift test --filter ToneDrillTrajectoryContextTests` — round-12's 5 tests should still pass.
4. `swift test --filter IMToneDrillResolvedTests` — round-13/14's primitive tests should still pass.
5. `swift test --filter InterventionUnderPushbackContinuationTests` — round-40's 29 tests should still pass (round-41 shares the recency-window number but is on a different surface).
6. `swift test --filter CaseAnchoredContinuationTests` — round-39's 28 tests should still pass.
7. `swift test --filter CaseAnchoredAmplificationTests` — round-37's 27 tests should still pass.
8. `swift test --filter InterventionUnderRepeatedPushbackTests` — round-38's 32 tests should still pass.
9. `swift test --filter RebuildVerdictContextTests` — round-32's 25 tests should still pass.
10. `swift test --filter FreshRevisedReadContextTests` — round-31's 16 tests should still pass.
11. Boot the app on simulator and drive an IM scenario from sub-40% (3+ reps) through to holding above 60% (3+ reps) so the engine resolves it. The chat coach's user-context block should carry the round-13 TONE-DRILL SOLVED section, and pulling the SOLVED log on a chat reply within 14 days of the crossing should show the section present.
12. Wait 14+ days (or fast-forward the most-recent rep's date in dev tools), then trigger another chat reply WITHOUT practicing the SOLVED scenario in the interim. The TONE-DRILL SOLVED section should now drop from the chat-coach context block, while the hero ribbon (round 20), post-rep note (round 14), and recommendation engine state remain unchanged.
13. Confirm the round-13 TRAJECTORY-and-SOLVED coexistence: a TRAJECTORY in scenario A + a fresh SOLVED in scenario B both surface; a TRAJECTORY in scenario A + a STALE SOLVED in scenario B surfaces only TRAJECTORY.
14. Confirm the round-26 hypothesis-ack chip, round-32 rebuild-verdict line, round-37/38/39/40 case-state matrix, and round-31 fresh-revised-read context block are all preserved verbatim.
