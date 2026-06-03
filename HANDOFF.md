# HANDOFF — M24 deferred slate (round 36): the round-33 second-cycle pushback marker now drives a small "2nd cycle" history badge on the Profile-tab `CaseReviewCard`'s "Last shift" row, closing the THIRD surface on the second-cycle predicate. Round 34 closed the post-rep `RevisedReadCard`; round 35 closed the chat-seed lead; round 36 closes the long-term coaching record. Pure visual addition gated on `CoachCourseChange.documentsSecondCyclePushback`; no new state, no schema bump.

## Scope

Round 35 split the chat-seed lead on `documentsSecondCyclePushback`, so a user who tapped the round-30 follow-up chip row with `.rejected` typed "Picking up the case file — I flagged the rebuilt read as off too." into Ask Noum on the rep where the second-cycle entry folded in. The honest gap round 35 left open on the **Profile-tab `CaseReviewCard`** history surface: the "Last shift" row reads off `memory.adaptationLog?.last.reason` literally, so a first-cycle pushback ("User reported the prior hypothesis did not match...") and a second-cycle pushback ("...did not match... (after a prior pushback rebuild); revising the read.") render identically at a glance — the parenthetical is buried in the reason text, not surfaced as a discrete history qualifier. A user opening Profile after pushing back twice in a row reads the same row register they would after pushing back once.

Round 36 picks up step #13 from the round-35 "Future moves" list:

> **`CaseReviewCard` second-cycle history badge.** Carried forward from
> round 34. The Profile-tab `CaseReviewCard` lists adaptation entries as
> long-term history. With round 33's marker, the card could surface a
> small "2nd cycle" badge on entries whose `documentsSecondCyclePushback`
> returns true. Pure visual work; the predicate is already on every
> entry. Hold for real-device QA.

Round 36 lands the badge with brand-voice-compliant copy ("2nd cycle" — no exclamation, no "Let's", no "we", no apology) and pins it with eight new tests in a new `@MainActor @Suite("CaseReviewSecondCycleBadgeTests")` suite. The badge surface is a small capsule sitting inline beside the existing "Last shift" eyebrow label, tinted with `AppColor.pro.opacity(0.10)` on the fill and `AppColor.pro.opacity(0.32)` on the stroke — the SAME `AppColor.pro` register the round-34 `RevisedReadCard` uses on its REVISED READ eyebrow + outer stroke + shadow, so the post-rep card (round 34) and the long-term history surface (round 36) read with one visual identity on the cycle distinction.

The mechanism is a pair of pure additions on `CaseReviewCard`:

- `static let secondCycleBadgeLabel = "2nd cycle"` — pure constant pinned by a brand-voice test. Mirror of `RevisedReadCard.secondCycleHeadlineCopy`'s `static let` pattern so a copy edit lands in one place and is locked by tests.
- `static func showsSecondCycleBadge(for change: CoachCourseChange) -> Bool` — pure predicate dispatching to `change.documentsSecondCyclePushback`. Static + pure so tests pin it without standing up a SwiftUI view, mirror of the round-F4a `hasUnacknowledgedHypothesis(in:)` / `acknowledgedEcho(for:)` lift on the same struct. Single-expression body so a copy edit on the predicate ripples to the badge surface in one place.

The view layer is intentionally thin: a new private `lastShiftRow(_ latest: CoachCourseChange) -> some View` factored out of the existing inline `caseRow(...)` call. Identical to the prior `caseRow("arrow.triangle.branch", "Last shift", latest.reason)` shape on a first-cycle entry; the only divergence is a `Text(Self.secondCycleBadgeLabel)` capsule wrapped in `HStack(spacing: 6)` beside the eyebrow label, gated on `Self.showsSecondCycleBadge(for: latest)`. The original `caseRow(icon:label:text:)` is preserved verbatim — only the "Last shift" call site routes through the new private function.

User brief, unchanged round to round: "continue from the existing TO-DO, ensure working towards getting the app towards the vision plan, and all round A+, make my dream I had come true too, ensure working on the redesign branch too (very important)."

Translation, this round:

- New `CaseReviewCard.secondCycleBadgeLabel` constant — the short calm history qualifier. Placed alongside the new predicate in a dedicated `MARK: - Second-cycle history badge (round 36)` block immediately above the existing F4a acknowledgement helpers so a future reader sees the round-36 surface as a coherent pure-helper pair, not scattered visual code.
- New `CaseReviewCard.showsSecondCycleBadge(for:)` static func — pure dispatch on `change.documentsSecondCyclePushback`. Same shape as `RevisedReadCard.headlineCopy(for:)` (round 34) and `CoachContextBuilder.revisedReadOpener(for:workingHypothesis:voice:)` (round 35); the THREE second-cycle surfaces now share one predicate-shape and one pure-helper register.
- New private `CaseReviewCard.lastShiftRow(_:)` — factored from the prior inline `caseRow(...)` call. Routes through `showsSecondCycleBadge(for:)` to decide whether to render the capsule. Uses `Spacing` / `Typography` / `AppColor` tokens consistently with the rest of the card; the capsule has explicit accessibility label ("Second adapt cycle") + identifier (`"profile.caseReview.lastShift.secondCycleBadge"`) so a future VoiceOver QA pass + UI test can read the surface.
- Inline call-site swap in `CaseReviewCard.body` — the existing three-line inline `caseRow("arrow.triangle.branch", "Last shift", latest.reason)` collapses to `lastShiftRow(latest)`. No call sites of the prior `caseRow(icon:label:text:)` change; the function signature is preserved verbatim.
- New `CaseReviewSecondCycleBadgeTests` suite (8 `@Test` methods + 2 private fixture helpers — same canonical reason shapes as the round-34 `RevisedReadCardTests` fixture, the round-33 engine fixture, and the round-35 `RevisedReadOpenerTests` fixture) — pins the pure constant, the pure predicate (second-cycle entry, first-cycle entry, engine-only lever shift, voice-change entry — four discriminating shapes), the brand-voice contract on the badge label, and TWO cross-surface contracts: the badge predicate must agree with the round-34 post-rep card's `headlineCopy(for:)` second-cycle gate AND the round-35 chat-seed `revisedReadOpener(for:...)` second-cycle lead prefix-match. Cross-surface contracts protect a future copy edit on any one surface from silently desyncing the three surfaces.
- The redesign-branch invariant: this is a `Redesign`-branch push per the user brief. Round 36 preserves the round-by-round loop on the redesign lineage that has been the home of rounds 11–35.

## What shipped

### Track 1 — `CaseReviewCard.secondCycleBadgeLabel` constant (`Noum/CaseReviewCard.swift`)

- New `static let secondCycleBadgeLabel = "2nd cycle"`. Calm, short — scans alongside the existing "Last shift" eyebrow label without crowding the five-section case spine. Doc comment cites the cross-surface contract with `RevisedReadCard.secondCycleHeadlineCopy` (round 34, post-rep card) and `CoachContextBuilder.revisedReadOpenerSecondCycleLead` (round 35, chat seed) — three coordinated visual registers on one predicate.
- Brand-voice locked by `secondCycleBadgeLabelIsBrandVoiceCompliant`: no `!`, no `"Let's"` / `"let's"`, no `" we "`, no `"sorry"`. Mirrors the round-34 + round-35 brand-voice rules.

### Track 2 — `CaseReviewCard.showsSecondCycleBadge(for:)` predicate (`Noum/CaseReviewCard.swift`)

- New `static func showsSecondCycleBadge(for change: CoachCourseChange) -> Bool` — pure dispatch on `change.documentsSecondCyclePushback`. Single-expression body; a copy edit on the round-33 marker constant in `CoachCourseChange.secondCyclePushbackMarker` ripples to the badge surface in one place.
- Same `static func` shape as `RevisedReadCard.headlineCopy(for:)` (round 34) and `CoachContextBuilder.revisedReadOpener(for:workingHypothesis:voice:)` (round 35) — the three second-cycle surfaces gate on the same predicate using the same call shape.
- Pinned end-to-end by four predicate tests (second-cycle entry, first-cycle entry, engine-only lever shift, voice-change entry) — the four discriminating shapes the persistent `CoachCourseChange.reason` field can take. Memories persisted before round 33 read `false` on the predicate and surface no badge automatically; no schema bump, no migration.

### Track 3 — `CaseReviewCard.lastShiftRow(_:)` row composer (`Noum/CaseReviewCard.swift`)

- New private `func lastShiftRow(_ latest: CoachCourseChange) -> some View`. Mirrors the existing `caseRow(icon:label:text:)` HStack/VStack/Image/Text shape so the row maintains the card's spacing rhythm verbatim on a first-cycle entry.
- When `Self.showsSecondCycleBadge(for: latest)` returns true, the eyebrow `Text("Last shift")` sits inside an `HStack(spacing: 6)` with a `Text(Self.secondCycleBadgeLabel)` capsule on its right. The capsule uses:
  - `Typography.micro.weight(.semibold)` font — same micro register as the eyebrow label, so visual weight reads as a qualifier on the label, not a competing surface.
  - `AppColor.pro` foreground; `AppColor.pro.opacity(0.10)` capsule fill; `AppColor.pro.opacity(0.32)` capsule stroke (`lineWidth: 1`). Same accent-on-tint pattern as the round-34 `RevisedReadCard` REVISED READ eyebrow + outer stroke + shadow (`AppColor.pro.opacity(0.22)`).
  - Explicit accessibility label `"Second adapt cycle"` so VoiceOver names the surface in full words (the visible `"2nd cycle"` reads as an abbreviation in the UI but a sentence in VoiceOver).
  - Explicit accessibility identifier `"profile.caseReview.lastShift.secondCycleBadge"` for a future UI test pass.
- The prior `caseRow(icon: "arrow.triangle.branch", label: "Last shift", text: latest.reason)` inline call site in `CaseReviewCard.body` collapses to `lastShiftRow(latest)`. The `caseRow(icon:label:text:)` function and every other call site (`interventionRow`, "Real-world check-in", "Momentum", "Last reflection", "Your verdict") are preserved verbatim.

### Track 4 — `CaseReviewSecondCycleBadgeTests` suite (`NoumTests/NoumTests.swift`)

Eight new `@Test` methods inside a new `@MainActor @Suite("CaseReviewSecondCycleBadgeTests")` suite, slotted immediately after the existing `RevisedReadCardTests` suite (line 27007 → new suite ends at line 27190 → preserved round-29 `RevisedReadOpenerTests` follows). Two private fixture helpers (`secondCyclePushbackChange()`, `firstCyclePushbackChange()`) mirror the round-34 `RevisedReadCardTests` and round-35 `RevisedReadOpenerTests` fixtures so the four suites that gate on the second-cycle reason shape (engine tests, post-rep card tests, opener tests, badge tests) all share the same canonical shape.

- **Pure constant (1 test):**
  - `secondCycleBadgeLabelIsCalmShortHistoryTag` — pure constant pin: `"2nd cycle"`.
- **Pure predicate (4 tests):**
  - `showsBadgeTrueWhenChangeCarriesSecondCycleMarker` — happy path on the second-cycle branch; predicate fires.
  - `showsBadgeFalseOnFirstCyclePushbackEntry` — no-regression contract; a first-cycle entry surfaces no badge.
  - `showsBadgeFalseOnEngineLeverShiftEntry` — defensive pin on an engine-only lever shift (no user pushback, no marker).
  - `showsBadgeFalseOnVoiceChangeEntry` — defensive pin on a voice-change entry (carries `voiceChangeMarker` but NOT `secondCyclePushbackMarker`).
- **Brand voice (1 test):**
  - `secondCycleBadgeLabelIsBrandVoiceCompliant` — pins `!`, `"Let's"`, `" we "`, `"sorry"` absence on the label.
- **Cross-surface contract (2 tests):**
  - `badgePredicateMatchesPostRepCardSecondCycleGate` — locks `CaseReviewCard.showsSecondCycleBadge(for:)` equality with `RevisedReadCard.headlineCopy(for:)`'s second-cycle gate on both a second-cycle and a first-cycle entry. A future copy edit that desyncs the two surfaces fails this test.
  - `badgePredicateMatchesChatSeedSecondCycleGate` — locks `CaseReviewCard.showsSecondCycleBadge(for:)` equality with `CoachContextBuilder.revisedReadOpener(for:workingHypothesis:voice:)`'s second-cycle lead prefix-match on both a second-cycle and a first-cycle entry. A future copy edit that desyncs the three surfaces fails this test.

### Vision alignment

- **Coach-parity stage #4 (Adaptation).** Per `docs/VISION.md`: the case formulation needs "the reason for changing course" carried as active coaching state, not buried in a log. Rounds 27–35 lifted the user pushback into a `CoachCourseChange` entry, then surfaced the rebuild and the user's verdict across the post-rep summary, the chat seed, the follow-up chip row, the chat-coach user-context block, the engine, AND named the second-cycle cycle on the post-rep card and chat seed. Round 36 closes the THIRD surface that names the cycle distinction: the long-term Profile-tab coaching record. A user who has pushed back twice in a row now sees the cycle qualifier the moment they open Profile, not only on the rep where the second-cycle entry folded in.
- **Coach-parity stage #5 (Adaptation, anti-overclaim).** The badge is a calm qualifier on an existing row — the underlying reason text is preserved verbatim, so the user can still read the engine's own explanation in full. The badge adds discriminating signal without inventing a new narrative; the predicate it reads is the same one the engine wrote.
- **Pillar #5 (Personalized coaching).** Round 36 + round 35 + round 34 + round 33 now form one cross-surface lift on the second-cycle marker: the engine records it, the chat-coach context block reads it, the post-rep card reads it, the chat seed reads it, AND the long-term Profile-tab history reads it. A user who has pushed back twice in a row reads the coach naming the repeated adapt across every surface where the cycle distinction can surface. The redesign-branch coaching voice speaks with one register from card to chat to model to history.
- **Pillar #4 (Believable progress).** Round 36's badge preserves the round-29 + round-34 evidence-anchored register — the reason text below the eyebrow still reads as the engine's own explanation, not a generic plan-change ping. The cycle distinction lives in the badge, not in the loss of evidence anchoring.
- **Anti-overclaim.** The badge is a small inline capsule, not a row, not a CTA, not a celebration, not a "you're improving" claim. The card's five-section spine is preserved verbatim; the second-cycle distinction is a qualifier on an existing row. The badge says nothing about whether the second-cycle pushback was justified, helpful, or a problem — it names the cycle, period. A real coach's notebook entry would carry the same calm qualifier.
- **Engineering bans.** No placeholder logic. No dead toggles. No fragmented state — the new predicate READS the existing `change.documentsSecondCyclePushback` field. No new storage, no schema bump, no migration, no new view inputs. Memories persisted before round 33 read `false` on the predicate and surface no badge automatically. Pure-function lift on pure-function inputs. The existing `caseRow(icon:label:text:)`, `interventionRow(_:)`, `momentumSummary`, `transferSummary`, `acknowledgementSection`, F4a `hasUnacknowledgedHypothesis(in:)`, F4a `acknowledgedEcho(for:)`, and S2 `chosenVoiceRegisterLabel` paths are preserved verbatim.

### Branch + redesign-alignment notes

- All four tracks land on `Redesign`, the redesign-lineage branch the rolling M24 deferred-slate work has been shipping on since round 11. The user brief explicitly calls this out: "ensure working on the redesign branch too (very important)." Round 36 preserves the round-by-round loop on the redesign lineage.
- Round 36 does not change the round-35 `revisedReadOpenerSecondCycleLead` / `secondCycleRevisedReadOpener(...)` / `revisedReadOpener(for:workingHypothesis:voice:)` router, does not change the round-34 `RevisedReadCard.headlineCopy(for:)` / `secondCycleHeadlineCopy` / `bodyCopy(for:workingHypothesis:)` / `secondCycleBodyCopy(workingHypothesis:)` router, does not change the round-33 `secondCyclePushbackMarker` constant or `documentsSecondCyclePushback` predicate, does not change the round-33 `freshRevisedReadContextLines` second-cycle branch, does not change the round-32 `rebuildVerdictPair` / `rebuildVerdictContextLines`, does not change the round-31 `freshRevisedReadChange(in:)` helper, does not change the round-30 chip-row catalog or follow-up predicate, does not change the round-29 first-cycle composer, does not change the round-28 first-cycle copy, does not change the round-27 engine restructure, does not change the round-26 chip catalog or hypothesis-ack row, and does not change the round-24 / round-25 `InterventionReviewPromptCard` surface. The round-35 12 + 5 RevisedReadOpener + RevisedReadFollowUp tests, the round-34 14 RevisedReadCard tests, the round-33 6 engine + 6 context-builder tests, the round-32 25 rebuild-verdict tests, the round-31 16 fresh revised-read tests, the round-30 15 follow-up tests, the round-29 13 opener tests, the round-28 5 copy tests, and the round-26 19 ack tests all remain unchanged; the round-36 8 `CaseReviewSecondCycleBadgeTests` sit alongside them.
- The round-33 chat-coach context second-cycle copy reads "Case file shifted again" / "second rebuild cycle"; the round-34 post-rep card second-cycle copy reads "rebuilt read as off too" / "next read" / "one focused question"; the round-35 chat seed second-cycle copy reads "I flagged the rebuilt read as off too" / "next read"; the round-36 history badge reads simply "2nd cycle". The user-typed verdict (round 35), the user-facing card headline (round 34), and the user-facing history qualifier (round 36) now share register without redundancy: the badge is the shortest possible calm tag; the card and the seed expand the same qualifier into a fuller sentence; the chat-coach context block speaks to the model in a slightly different register. A future round can collapse the three user-facing surfaces' verb registers further, but only after a real-device QA pass.

## Future moves

(Updated priority list — round 36 closed round-35 step #13. The rest roll forward, plus one new note from round 36.)

1. **Peer Sudden Death scores via `FriendsManager`.** Still blocked on `PublicProfileSnapshot` schema work.
2. **`coachNoteRevealed` cleanup.** Still risky — animation chain interleaving with celebration timing. Worth a dedicated refactor pass with proper visual QA (and a real device).
3. **Visual polish pass on the round-19 launch CTA.** Carried forward from rounds 19–35. Pure visual work, not destination logic.
4. **Visual polish pass on the round-20 SOLVED ribbon.** Carried forward from rounds 20–35. Pure visual work, not crossing logic.
5. **Extend the crossing helper to the chat-coach context line.** Carried forward from round 21 as a note for the record.
6. **Day-rollover refresh for long-mounted observers.** Carried forward from round 22.
7. **Tier-change observation symmetry to other surfaces that read `AIRateLimiter.currentCap()` directly.** Carried forward from round 23.
8. **Refresh-on-rotate for the empty-state chip when the `CoachMemoryStore` mutates while AskNoumView is mounted.** Carried forward from round 25.
9. **Voice-tuned ack-chip glyphs.** Carried forward from round 26.
10. **`.confirmed` confidence amplification on the active intervention.** Carried forward from round 27, called out by round 32. After rounds 34–36's split-the-cycle work, this becomes the next-most-aligned coach-parity gap: when a user confirms a rebuilt working hypothesis with `.confirmed`, the active intervention's confidence should amplify proportionally so the engine treats follow-on evidence as case-anchored, not exploratory. Pure-logic work on `CoachMemory.activeIntervention` (no new schema, no view changes) — read `hypothesisAcknowledgement.confidence == .confirmed` + a recency window inside the rebuild path, raise the carrying intervention's evidence confidence one tier when the predicate fires (and the prior rebuild was itself a user-driven cycle). Mirror of round 33's reading on a different field.
11. **Collapse the round-26 hypothesis-ack reflection in `coachCaseFormulationLines` into a single block with the round-32 rebuild-verdict lines when the predicate fires.** Carried forward from round 32. Hold for real-device QA.
12. **Trend-view distinction between "user accepted the first read", "user accepted the rebuilt read", and "user pushed back twice".** From round 30's step #11 + round 32's step #14, made richer by round 33 + round 36. Round 36 strengthens the case further: the predicate now drives the engine, the post-rep card, the chat-coach context block, the chat seed, AND the long-term Profile-tab history badge — a future analytics surface inherits FIVE distinct signal points instead of one.
13. **Second-cycle ask register on the opener.** Note from round 35. The voice-shaped ask is currently cycle-agnostic by design (lifted into the shared `revisedReadOpenerAsk(for:)` helper). A future round, after real-device QA on second-cycle conversations, may want a cycle-aware ask register — e.g. `.authoritative` second-cycle: "Walk me through the second pushback before I rebuild." Mirror of the round-33 context-block coach-move split on the ask surface. Restraint pin: do NOT split the ask until real conversations show the cycle-agnostic ask reads as off; the simpler shared mapping is the better default.
14. **`CaseReviewCard` adaptation-log fuller history surface.** New note from round 36. The "Last shift" row reads off `memory.adaptationLog?.last` — the single latest entry. With round 36's badge on that row, a future round could lift the entire bounded adaptation log into an expandable surface (one row per entry, each carrying the same second-cycle badge when its `documentsSecondCyclePushback` fires) so the user can scroll their full case-history lineage instead of only the latest move. Restraint pin: do NOT lift until real-device QA confirms users want the lineage exposed; the current single-row register is intentionally restrained ("the coach's notebook, not a dashboard"). When the lineage IS lifted, the same `Self.showsSecondCycleBadge(for:)` predicate applies row-by-row with zero new logic.

## Build-host limitation (honest note for the next agent)

This environment has **no Xcode and no Swift toolchain**, so nothing in this round was compiled or run — not the app, not the test suite. The changes are:

- One new `static let secondCycleBadgeLabel: String` and one new `static func showsSecondCycleBadge(for change: CoachCourseChange) -> Bool` on `CaseReviewCard` in `Noum/CaseReviewCard.swift`. Both single-expression / one-line bodies; pure functions of an existing persisted field.
- One new private `func lastShiftRow(_ latest: CoachCourseChange) -> some View` on `CaseReviewCard`. Mirrors the prior `caseRow(icon: "arrow.triangle.branch", label: "Last shift", text: latest.reason)` inline call site, adding an `HStack(spacing: 6) { Text("Last shift") if Self.showsSecondCycleBadge(for: latest) { capsule } }` around the eyebrow when the predicate fires.
- One inline call-site swap inside `CaseReviewCard.body`: `caseRow(icon: "arrow.triangle.branch", label: "Last shift", text: latest.reason)` collapses to `lastShiftRow(latest)`. Every other call site of `caseRow(icon:label:text:)` is preserved verbatim.
- Eight new `@Test` methods inside a new `@MainActor @Suite("CaseReviewSecondCycleBadgeTests")` suite and two new private fixture helpers, in `NoumTests/NoumTests.swift`. Slotted immediately after the existing `RevisedReadCardTests` suite (around line 27007) so the round-34 + round-36 cross-surface contract reads as one block in the test file.

All checks the next agent should run on a real build host:

1. `swift test --filter CaseReviewSecondCycleBadgeTests` — the new round-36 8 tests should all pass.
2. `swift test --filter RevisedReadCardTests` — round-34's 14 tests should still pass (the round-36 cross-surface contract test reads through `RevisedReadCard.headlineCopy(for:)` and `RevisedReadCard.secondCycleHeadlineCopy` but does not modify them).
3. `swift test --filter RevisedReadOpenerTests` — the round-29 13 + round-35 12 tests should still pass (the round-36 cross-surface contract test reads through `CoachContextBuilder.revisedReadOpener(for:workingHypothesis:voice:)` and `CoachContextBuilder.revisedReadOpenerSecondCycleLead` but does not modify them).
4. `swift test --filter RevisedReadFollowUpTests` — the round-30 15 + round-35 5 tests should still pass.
5. `swift test --filter SecondCyclePushbackContextTests` — round-33's 6 context-builder tests should still pass.
6. `swift test --filter CoachMemoryEngineTests` — round-33's engine tests + the older engine tests should all pass.
7. `swift test --filter RebuildVerdictContextTests` — round-32's 25 tests should still pass.
8. `swift test --filter FreshRevisedReadContextTests` — round-31's 16 tests should still pass.
9. `swift test --filter HypothesisAcknowledgementTests` — round-26's 19 tests (incl. the round-F4a CaseReviewCard ack-section tests) should still pass.
10. `swift test --filter CoachMemoryStoreTests` — the existing memory-store tests should still pass.
11. Boot the app on simulator, drive a session through the round-26 hypothesis-ack chip (`.rejected`) so the engine appends a first-cycle pushback entry. Finish a rep so memory rebuilds. Open Profile and confirm `CaseReviewCard` renders the "Last shift" row with the first-cycle reason text and NO badge (the round-29 first-cycle behaviour, preserved verbatim).
12. Drive the round-30 follow-up chip row (`.rejected`) on the rebuilt read. Finish another rep so memory rebuilds again: the engine now writes a second-cycle pushback entry (`documentsSecondCyclePushback == true`). Open Profile and confirm `CaseReviewCard` renders the "Last shift" row with the second-cycle reason text AND a small "2nd cycle" purple capsule sitting inline beside the "LAST SHIFT" eyebrow. The capsule should not overflow the row width on the smallest-supported iPhone width; if it does on a real device, the badge label can be shortened or the capsule wrapped on its own line.
13. Trigger an engine-only lever shift after a second-cycle entry sits in history. Confirm `CaseReviewCard`'s "Last shift" row now reads the engine reason text (the next entry, not the second-cycle entry) and surfaces NO badge — the predicate gates on the LATEST entry only, so a fresh engine shift collapses the badge automatically.
14. VoiceOver pass on the badge: confirm the capsule reads as "Second adapt cycle" (the accessibility label), not as the literal "2nd cycle" abbreviation. The visible UI keeps the short form; the spoken UI expands it.
15. Confirm the round-34 post-rep `RevisedReadCard` and the round-35 chat seed still render the second-cycle copy on the same rep — the three surfaces should all surface the cycle distinction at once.
