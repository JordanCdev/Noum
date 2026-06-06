# Initiative #2 — Fold the user's upcoming real-world moment into the durable CoachCaseFile (coach-parity stages: Case formulation + Transfer; milestone M16). Add a bounded, optional, decode-safe upcoming-moment field to the durable case spine so the coach's persistent read knows what the user is preparing for, surfaced as soon as one future scheduled moment exists (not a hypothesis), framed strictly as "the kind of skill this moment tends to need," dropped automatically once the date passes (it then flows through the existing transfer-review path). Mirrors the shipped lastTransferReview wiring exactly: raw value threaded INTO CoachMemoryEngine.build from the call sites that already read BigMomentStore.shared; CoachCaseFile.build reads it off CoachMemory; one tentative line appended to coachCaseFileLines. Where logic exists (soonest-future selection, daysUntil bounding, moment->focus derivation) it is a pure, unit-testable mapping with named thresholds — no new store/engine/screen/routing.

Generated: 2026-06-01

> Implementation-ready spec, code-grounded. readyToImplement: false — until predecessor gate + open-question sign-off.

## Ground-truth checks (verified against real code)

- OK — CoachCaseFile struct exists and is the durable case spine
    _Noum/PrimaryFocusMemory.swift:821 `struct CoachCaseFile: Codable, Equatable {` with fields hypothesis/focus/evidenceSummary/activeIntervention/observableTarget/successMeasure/reviewDueAt/subjectivePattern/transferRead/nextMove/nextQuestion (:822-833)_
- OK — CoachCaseFile.build(from:now:) exists with the cited signature
    _Noum/PrimaryFocusMemory.swift:835 `static func build(from memory: CoachMemory, now: Date) -> CoachCaseFile?`_
- **MISSING / CORRECTED** — CoachCaseFile.build takes BigMomentStore and selects the soonest future entry inside build (AS THE ROADMAP STATES)
    _FALSE as written. build's only parameters are (from memory: CoachMemory, now: Date) (:835). It is a PURE transform over CoachMemory and never references BigMomentStore; its own doc comment (:815-820) states it 'composes existing owners rather than owning raw history' and that BigMomentStore owns transfer check-ins. The moment must be threaded IN via CoachMemory, mirroring lastTransferReview — NOT read from the store inside build. Roadmap first-step instruction is architecturally wrong and is corrected in this spec._
- **MISSING / CORRECTED** — CoachUpcomingMoment type already exists (the cited new field type)
    _grep for CoachUpcomingMoment/UpcomingMoment/upcomingMoment across all *.swift returns NONE — this is the NEW type to create. No symbol collision._
- OK — lastTransferReview wiring exists end-to-end and is the correct mirror target
    _Field on CoachMemory at PrimaryFocusMemory.swift:683 (`var lastTransferReview: CoachTransferReview?`), defaulted init arg :721, CodingKey :774, decodeIfPresent :807, set in CoachMemoryEngine.build at :1141 (`memory.lastTransferReview = latestTransferReport.map { CoachTransferReview(report: $0) } ?? previous?.lastTransferReview`), read in CoachCaseFile.build at :843 (`let transferRead = memory.lastTransferReview?.reportedOutcomeLine`). This is the exact pattern to replicate._
- OK — CoachMemoryEngine.build accepts a latestTransferReport param threaded from the store (the injection point to mirror)
    _Noum/PrimaryFocusMemory.swift:982 `latestTransferReport: BigMomentOutcomeReport? = nil` (defaulted); CoachMemoryStore.refresh also threads it at :1632; passed through at :1648._
- OK — Production call site reads BigMomentStore.shared and threads it into refresh
    _Noum/SessionFinalizer.swift:254 `latestTransferReport: BigMomentStore.shared.recentOutcomeReports(limit: 1).first` inside CoachMemoryStore.shared.refresh(...) (:243-255). This is where `upcomingMoment:` source must be added._
- OK — BigMomentStore owns the active scheduled moment and exposes nonisolated daysUntil
    _Noum/BigMomentStore.swift:184 `@Published private(set) var activeMoment: BigMoment?`; :256 `nonisolated static func daysUntil(_ moment: BigMoment) -> Int?` (returns nil for nil-date, negative once passed). NOTE: store holds a SINGLE activeMoment + a past `archive` (:185) + outcomeReports (:186) — there is NO list of multiple future moments. 'Soonest future moment' = activeMoment when its date is nil OR >= today._
- OK — BigMoment carries title, category, optional date
    _Noum/BigMomentStore.swift:55-75 `struct BigMoment: Codable, Identifiable, Equatable` with `var title`, `var date: Date?`, `var category: BigMomentCategory`._
- OK — BigMomentCategory has a sentence-embeddable displayName for tentative copy
    _Noum/BigMomentStore.swift:43-52 `var displayName` (e.g. 'presentation','interview','performance review'); designed for running-sentence coach copy per its doc comment (:38-42)._
- OK — coachCaseFileLines is the durable case-file emission and is where one tentative line is appended
    _Noum/CoachContextBuilder.swift:2171 `private static func coachCaseFileLines(memory:) -> [String]`, gated `guard let caseFile = memory.caseFile`, emits hypothesis/evidence/intervention/target/measure/review/subjectivePattern/transferRead/nextMove lines, caps `Array(lines.prefix(10))` (:2203). ROADMAP CITED ~line 2160 — actual is 2171 (off by ~11)._
- OK — Header 'COACH CASE FILE (durable strategy)' precedes the case-file lines
    _Noum/CoachContextBuilder.swift:483 `lines.append("COACH CASE FILE (durable strategy)")` then :484 `lines.append(contentsOf: caseFileLines)`, inside `if !caseFileLines.isEmpty` (:481). New line surfaces only when the block already shows._
- OK — There are FIVE CoachCaseFile.build call sites, not one — partial rebuilds must preserve the moment
    _Noum/PrimaryFocusMemory.swift:1147 (full build), and partial-update rebuilds at :1666, :1684, :1708 (noteHypothesisAcknowledgement-style), :1720 (noteTransferOutcome). All four partials call build(from: memory,...) where memory == currentMemory, so any durable field must LIVE ON CoachMemory to survive them — exactly how lastTransferReview persists. Confirms the field belongs on CoachMemory, recomputed-fresh inside build._
- OK — SkillArea enum exists with the cases needed for moment->focus derivation
    _Noum/DrillSystem.swift:10 `enum SkillArea: String, Codable, CaseIterable, Identifiable` cases fillerReduction/openingStrength/closingStrength/paceControl/structure/answerDevelopment/conciseSpeaking/pauseUsage/vocalEmphasis/confidence (:11-20). NOT in PracticeSupport.swift. No existing BigMomentCategory->SkillArea mapping — the derivation is new._
- OK — CoachMemory carries NO raw BigMoment today (so the new field is genuinely additive)
    _grep BigMoment in PrimaryFocusMemory.swift shows only CoachTransferReview.category (:221) and the latestTransferReport params — no raw BigMoment is stored on CoachMemory. Adding one is net-new._
- OK — No test pins the exact case-file line count or prefix(10), so appending one line is safe
    _grep prefix(10)/caseFileLines.count/COACH CASE FILE in NoumTests.swift returns only the substring assertion at :5822 (`ctx.contains("COACH CASE FILE (durable strategy)")`). No count assertion to break._
- OK — Existing CoachCaseFile.build test + decode-safety test + context-surfacing test exist to mirror
    _NoumTests/NoumTests.swift:10773 `buildCreatesDurableCaseFileFromHypothesisInterventionAndReflectionPattern`; :10808 `caseFieldsDecodeMemoryPersistedBeforeCaseFile` (LegacyMemory decode, asserts new keys nil incl. :10861 lastTransferReview==nil, :10862 caseFile==nil); :5785 `userContextSurfacesDurableCoachCaseFile`; :5830 `userContextSurfacesTransferReviewAsAUserOwnedCaseAction`._
- OK — CaseReviewCard is a USER-FACING surface that renders case state (coherence consideration)
    _Noum/CaseReviewCard.swift:263 `transferSummary` builds a user-facing line from memory.lastTransferReview directly (:264-279); it reads CoachMemory fields, not caseFile.upcomingMoment. So the durable case-file READ surfaces to the LLM via coachCaseFileLines; CaseReviewCard renders its own summaries. Documented as a coherence surface to keep aligned, not a required edit for this slice._
- OK — Per-turn context already surfaces the active moment with daysUntil + a 0...60 gate (the read this initiative makes DURABLE)
    _Noum/CoachContextBuilder.swift:305 and starterPrompts :1536-1537 `let days = BigMomentStore.daysUntil(moment); if days >= 0 && days <= 60`. Confirms the roadmap's framing: the forward moment exists at per-turn context but never reaches the durable case spine. This initiative bridges it._
## New types / fields

NEW VALUE TYPE — in Noum/PrimaryFocusMemory.swift, immediately before `struct CoachCaseFile` (~:815, beside CoachTransferReview at :218 to share the file region; keep it Codable+Equatable for CoachCaseFile/CoachMemory conformance):

```swift
/// A bounded, forward-looking snapshot of the single soonest upcoming
/// scheduled moment, folded into the durable case file. `BigMomentStore`
/// remains the owner of the scheduled moment; this is only the case file's
/// current forward-awareness read. NOT a prediction and NOT a hypothesis:
/// it is the user's own scheduled event. `daysUntil` is recomputed on every
/// `CoachCaseFile.build` against that build's `now`, so it never goes stale
/// and the moment drops automatically once its date passes.
struct CoachUpcomingMoment: Codable, Equatable {
    var title: String                 // bounded to 80 chars at construction
    var category: BigMomentCategory   // reuse existing enum (BigMomentStore.swift:8)
    var daysUntil: Int?               // nil when the moment has no scheduled date
    var derivedFocus: SkillArea?      // "the kind of skill this moment tends to need" — association only, never a claim

    static let titleCharacterLimit = 80
    static let forwardHorizonDays = 60   // mirror the existing per-turn moment gate (CoachContextBuilder.swift:1537)

    /// Pure constructor. Returns nil when the moment is undated-and-we-require-a-date? — NO:
    /// an undated future moment is still valid (daysUntil == nil). Returns nil ONLY when the
    /// moment's date is in the PAST (daysUntil != nil && daysUntil! < 0) or beyond the horizon
    /// (daysUntil! > forwardHorizonDays). This is where the "drop once the date passes" rule lives.
    init?(moment: BigMoment, now: Date, calendar: Calendar = .current) {
        let days: Int?
        if let date = moment.date {
            let today = calendar.startOfDay(for: now)
            let target = calendar.startOfDay(for: date)
            days = calendar.dateComponents([.day], from: today, to: target).day
        } else {
            days = nil
        }
        if let d = days, (d < 0 || d > Self.forwardHorizonDays) { return nil }  // past OR beyond horizon -> drop
        let trimmed = moment.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.title = String(trimmed.prefix(Self.titleCharacterLimit))
        self.category = moment.category
        self.daysUntil = days
        self.derivedFocus = CoachUpcomingMoment.focus(for: moment.category)
    }

    /// Moment-kind -> the skill that kind of moment TENDS to need. Association only.
    /// Conservative: returns nil for ambiguous kinds (.conversation, .other) so the line
    /// degrades to category-only and never asserts a focus the data can't support.
    static func focus(for category: BigMomentCategory) -> SkillArea? {
        switch category {
        case .presentation:   return .structure
        case .interview:      return .answerDevelopment
        case .review:         return .closingStrength
        case .publicSpeaking: return .openingStrength
        case .conversation:   return nil
        case .other:          return nil
        }
    }

    /// Tentative, never-predictive context line. Mirrors the transferRead register
    /// (CoachContextBuilder.swift:2198-2200) — bounded, explicitly framed.
    var contextLine: String {
        let when: String
        if let d = daysUntil {
            when = d == 0 ? "today" : "in \(d) day\(d == 1 ? "" : "s")"
        } else {
            when = "coming up (no date set)"
        }
        var line = "Upcoming moment: the user has a \(category.displayName) \"\(title)\" \(when)."
        if let focus = derivedFocus {
            line += " The kind of skill this moment tends to need is \(focus.displayName.lowercased()); treat as the moment's typical demand, not a prediction the user will struggle."
        } else {
            line += " Frame any prep as forward awareness, not a prediction about how it will go."
        }
        return line
    }
}
```

NEW FIELD ON CoachMemory — in Noum/PrimaryFocusMemory.swift, beside lastTransferReview (:683). Store the RAW BigMoment (not CoachUpcomingMoment) so daysUntil is recomputed fresh on every build path and stays accurate across the 5 build call sites — exactly as the raw report flows for transfer:

```swift
// The single soonest upcoming scheduled moment the user is preparing for.
// Optional for backward compat (older persisted memories decode without
// this key). Stored as the raw BigMoment; daysUntil/derivedFocus are derived
// fresh in CoachCaseFile.build against `now`, so the forward read never goes
// stale and drops automatically once the date passes.
var upcomingBigMoment: BigMoment?
```

Plus the four mechanical Codable additions (every one mirrors lastTransferReview):
- defaulted memberwise init arg (~:721): `upcomingBigMoment: BigMoment? = nil,` + `self.upcomingBigMoment = upcomingBigMoment` (~:753)
- CodingKey (~:774): add `upcomingBigMoment` to the `case lastTransferReview` line group
- decode (~:807): `upcomingBigMoment = try c.decodeIfPresent(BigMoment.self, forKey: .upcomingBigMoment)`

NEW FIELD ON CoachCaseFile — in Noum/PrimaryFocusMemory.swift beside transferRead (:831). This is the durable, bounded read the surfaces consume:

```swift
var upcomingMoment: CoachUpcomingMoment?
```
(CoachCaseFile uses a synthesized memberwise init — `CoachUpcomingMoment` being Codable+Equatable keeps CoachCaseFile's auto Codable/Equatable conformance; add `upcomingMoment: upcomingMoment` to the CoachCaseFile(...) call inside build at :854-867 and to the test fixture at NoumTests.swift:5786.)

BACK-COMPAT / DECODE SAFETY: every new stored field is optional + decodeIfPresent (CoachMemory.upcomingBigMoment) or lives only on the non-persisted-in-isolation CoachCaseFile (which is itself decodeIfPresent at :801 and already tested nil-on-legacy at :10862). CoachUpcomingMoment is bounded (title prefix 80, horizon 60). No non-optional field added anywhere. All existing CoachMemory/CoachCaseFile call sites compile unchanged because every new init arg is defaulted.

## Wiring edits

- **Noum/PrimaryFocusMemory.swift** @ ~:815, immediately before `struct CoachCaseFile` (and beside CoachTransferReview :218) — Add the new `struct CoachUpcomingMoment: Codable, Equatable` (full signature in newTypesOrFields), including its failing init (past/beyond-horizon -> nil), `focus(for:)` mapping, and `contextLine`.
- **Noum/PrimaryFocusMemory.swift** @ :683 (beside lastTransferReview) + init :721/:753 + CodingKeys :774 + decode :807 — Add `var upcomingBigMoment: BigMoment?` to CoachMemory with the four mechanical Codable additions, each mirroring lastTransferReview exactly (defaulted init arg, self-assign, CodingKey, decodeIfPresent).
- **Noum/PrimaryFocusMemory.swift** @ :831 (beside transferRead) + build's CoachCaseFile(...) construction :854-867 — Add `var upcomingMoment: CoachUpcomingMoment?` to CoachCaseFile. Inside build (after the `let transferRead = ...` line at :843) add: `let upcomingMoment = memory.upcomingBigMoment.flatMap { CoachUpcomingMoment(moment: $0, now: now) }`. Pass `upcomingMoment: upcomingMoment` into the CoachCaseFile(...) initializer. CRITICAL: derive it from `memory.upcomingBigMoment` (already on memory), NOT from BigMomentStore — build stays pure. Do NOT add upcomingMoment to the `guard hypothesis != nil || ...` early-return at :845-851: an upcoming moment ALONE should not manufacture a case file out of nothing (matches the existing rule that transferRead does count toward presence but the moment is forward-only context; if product wants the moment alone to seed a case file, that is open question 1).
- **Noum/PrimaryFocusMemory.swift** @ CoachMemoryEngine.build, param list :982 + assignment near :1141 — Add defaulted param `upcomingBigMoment: BigMoment? = nil,` (beside `latestTransferReport:`). After the `memory.lastTransferReview = ...` line (:1141-1142) add: `memory.upcomingBigMoment = upcomingBigMoment ?? previous?.upcomingBigMoment` — the SAME `?? previous?` fallback lastTransferReview uses, so partial finalize calls that don't re-pass the moment preserve it. This must be set BEFORE :1147 `memory.caseFile = CoachCaseFile.build(...)`.
- **Noum/PrimaryFocusMemory.swift** @ CoachMemoryStore.refresh, param list :1632 + pass-through :1648 — Add defaulted param `upcomingBigMoment: BigMoment? = nil,` and forward it: `upcomingBigMoment: upcomingBigMoment,` into the CoachMemoryEngine.build(...) call (beside `latestTransferReport:`).
- **Noum/SessionFinalizer.swift** @ the CoachMemoryStore.shared.refresh(...) call, :243-255 (add beside :254) — Add `upcomingBigMoment: BigMomentStore.shared.activeMoment` to the refresh call. This is the ONLY production source read — the store is read here and the raw value threaded in, keeping CoachMemoryEngine/CoachCaseFile singleton-free and test-injectable (identical discipline to `latestTransferReport: BigMomentStore.shared.recentOutcomeReports(limit:1).first` on the line above).
- **Noum/CoachContextBuilder.swift** @ coachCaseFileLines, after the transferRead emission :2198-2200 and before the nextMove line :2201 — Append the durable forward-awareness line under the existing COACH CASE FILE header: `if let upcoming = caseFile.upcomingMoment { lines.append("- " + upcoming.contextLine) }`. Placed before the `Array(lines.prefix(10))` cap (:2203) and after transferRead so the ordering reads diagnosis -> intervention -> transfer(past) -> upcoming(future) -> next move. No new section/header; surfaces only when the case-file block already shows (gated by :2174 guard + :481).

## Evidence & copy model

EVIDENCE FLOOR — fundamentally different from initiative #1. A user-entered scheduled moment is the user's OWN event, not an inferred pattern, so there is NO multi-rep / confidence ladder: surface it as soon as ONE future moment exists. The discipline is in BOUNDING and FRAMING, not gating.

PRESENCE RULES (all enforced in CoachUpcomingMoment.init? so the surface can never violate them):
- Exactly ONE moment ever: sourced from BigMomentStore.activeMoment (the store holds a single active moment), so 'bounded to the single soonest' is structurally guaranteed — no selection/sort needed today. (Documented as such; if BigMomentStore later holds multiple, add a `min(by: daysUntil)` selector at the SessionFinalizer source, never inside build.)
- DROP once the date passes: init? returns nil when `daysUntil < 0`. The moment then flows through the existing transfer path (BigMomentStore.archiveExpiredIfNeeded -> outcomeReports -> lastTransferReview), so a passed moment becomes a past-outcome read, never lingering as a stale 'upcoming'. Recomputed fresh on every build via `now`, so even without a finalize the next rebuild self-corrects.
- BEYOND-HORIZON suppression: init? returns nil when `daysUntil > 60`, mirroring the existing per-turn gate (CoachContextBuilder.swift:1537 `days <= 60`) so the durable read and the per-turn read agree on visibility.
- UNDATED moment is valid: daysUntil == nil is allowed and surfaces as 'coming up (no date set)'.

COPY RULES (asserted in tests):
- NEVER a prediction about how the moment will GO. Banned tokens asserted absent: 'will struggle', 'will go well', 'predict', 'expect to', 'likely to fail', 'cause'.
- The moment->focus link is ASSOCIATION ONLY: copy is fixed as 'The kind of skill this moment tends to need is X; treat as the moment's typical demand, not a prediction the user will struggle.' — never 'you need to work on X for this' and never 'this moment requires X'.
- Conservative focus: .conversation and .other derive NO focus (focus(for:) returns nil); the line degrades to category + timing only, so an ambiguous moment never asserts a skill the kind doesn't reliably imply.
- The moment NEVER strengthens a psychological hypothesis: it is stored on its own field, read into its own line, and contributes NOTHING to evidenceCount, currentLever selection, or any verdict. (Verified: CoachMemoryEngine.build computes lever/evidence at :997/:989 entirely upstream of where upcomingBigMoment is set at :1141.)
- Tentative register matches the neighbouring transferRead line ('User-reported; not proof of causation.' :2199): the forward line carries an explicit 'not a prediction' qualifier in the same position.

WHAT STAYS UNPERSISTED-AS-DERIVED: daysUntil and derivedFocus are NEVER persisted as frozen values — only the raw BigMoment is stored on CoachMemory; the bounded CoachUpcomingMoment (with its time-relative daysUntil) is recomputed in build every time. This is the mechanism that makes 'drop once the date passes' automatic and prevents a stale '3 days out' from surviving a week.

## Coherence surfaces (coach-lens: one read everywhere)

COACH-LENS: one coherent forward read everywhere the case file speaks. The durable read is authored once in CoachUpcomingMoment.contextLine and CoachCaseFile.upcomingMoment, then must read consistently across:

1. CHAT COACH (Ask Noum) — Noum/CoachContextBuilder.swift:2171 coachCaseFileLines, the new line under 'COACH CASE FILE (durable strategy)' (:483). PRIMARY surface; this is the durable spine the roadmap targets. (REQUIRED EDIT.)

2. PER-TURN CONTEXT alignment — the existing transient moment read at CoachContextBuilder.swift:305 and starterPrompts :1536-1537 already uses BigMomentStore.daysUntil with a 0...60 gate. The new durable line MUST use the same 60-day horizon (CoachUpcomingMoment.forwardHorizonDays = 60) and the same daysUntil math so the coach never shows the moment in one place and hides it in another. (ENFORCED by sharing the constant + calendar math; no separate edit, but the test matrix pins horizon parity.)

3. FORWARD PLAN — Noum/ForwardPlanService.swift + ForwardPlanCoordinator.swift:35-36 already read BigMomentStore.shared.activeMoment + daysUntil for plan copy. No edit required for this slice (the plan already knows the moment), BUT flagged as a coherence surface: the case-file's derivedFocus and the forward plan's focus should not contradict. Documented as open question 2 (do not silently diverge).

4. POST-REP COACH NOTE — Noum/PostRepCoachNoteService.swift:924-958 already emits 'Your {event} is {n} days out' style lines off daysUntil with a `<= 14` gate. Coherence requirement: the durable case line and the post-rep note describe the SAME moment with consistent day-count framing. The post-rep note's 14-day urgency window is a deliberately tighter sub-window of the 60-day awareness horizon — documented, not contradictory.

5. CASE REVIEW CARD (user-facing) — Noum/CaseReviewCard.swift renders transferSummary/momentum from memory directly (:263). The durable upcoming read is currently LLM-context only (coachCaseFileLines). For full coach-lens parity the card could later render the upcoming moment, but that is a UI addition beyond this data-bridge slice; flagged so the read stays alignable. NOT a required edit for initiative #2 (the roadmap scopes this initiative to the durable case + one context line).

The single-authorship rule (contextLine on the value type) is what guarantees coherence: any surface that adopts the durable read calls the same property, so the judgment reads identically wherever it appears.

## Test matrix

- **build_populatesUpcomingMoment_fromDatedFutureActiveMoment** — asserts: caseFile?.upcomingMoment != nil; .title == "Board update"; .category == .presentation; .daysUntil == 3; .derivedFocus == .structure
- **build_droppsUpcomingMoment_oncePastDate** — asserts: caseFile?.upcomingMoment == nil — the 'drop once the date passes' rule (init? returns nil for daysUntil<0)
- **build_suppressesUpcomingMoment_beyondHorizon** — asserts: caseFile?.upcomingMoment == nil (daysUntil 61 > forwardHorizonDays 60); companion at now+60d -> non-nil, daysUntil==60 (boundary holds)
- **build_undatedMoment_surfacesWithNilDaysUntil** — asserts: caseFile?.upcomingMoment != nil; .daysUntil == nil; .derivedFocus == .answerDevelopment; contextLine contains 'coming up (no date set)'
- **build_today_daysUntilZero_copyReadsToday** — asserts: .daysUntil == 0; contextLine contains 'today'; never 'in 0 days'
- **derivedFocus_ambiguousCategory_nil_andCopyDegrades** — asserts: .derivedFocus == nil for both; contextLine does NOT name a skill; contains 'forward awareness, not a prediction'
- **derivedFocus_mappingIsExhaustiveAndAssociative** — asserts: presentation->.structure, interview->.answerDevelopment, review->.closingStrength, publicSpeaking->.openingStrength, conversation->nil, other->nil
- **contextLine_neverPredictive_alwaysTentative** — asserts: BOTH contain neither 'will struggle' nor 'will go' nor 'predict' nor 'expect' nor 'cause'; the focus variant contains 'tends to need' and 'not a prediction the user will struggle'
- **title_boundedTo80Chars** — asserts: .title.count <= 80; trimmed
- **emptyTitle_returnsNilMoment** — asserts: CoachUpcomingMoment(moment:now:) == nil; build -> caseFile?.upcomingMoment == nil
- **build_noUpcomingMoment_caseFileStillBuildsFromOtherFields** — asserts: caseFile != nil; caseFile?.upcomingMoment == nil — the moment is purely additive, never required for case-file presence
- **upcomingMomentAlone_doesNotManufactureCaseFile** — asserts: CoachCaseFile.build returns nil (the :845-851 guard is intentionally NOT relaxed for the moment) — locks the open-question-1 decision; flip only if product overrides
- **engineBuild_threadsUpcomingMoment_endToEnd** — asserts: memory?.upcomingBigMoment != nil; memory?.caseFile?.upcomingMoment?.daysUntil == 5 — proves the full thread from engine param to case file
- **engineBuild_preservesUpcomingMoment_acrossPartialRebuild** — asserts: memory?.upcomingBigMoment != nil (preserved via `?? previous?.upcomingBigMoment`) — mirrors lastTransferReview persistence; companion: noteTransferOutcome-style partial rebuild keeps the moment
- **decode_legacyMemoryWithoutUpcomingMoment_isNil** — asserts: decoded.upcomingBigMoment == nil; decoded.caseFile == nil (alongside existing :10861-10862 asserts) — decode-safety / back-compat
- **decode_roundTrip_upcomingMomentSurvives** — asserts: decoded.upcomingBigMoment == original; and a CoachCaseFile with upcomingMoment round-trips equal
- **daysUntil_recomputedFresh_notStale** — asserts: second build daysUntil == 1 (recomputed against new now), proving daysUntil is never a frozen persisted value
- **userContext_surfacesUpcomingLine_underCaseFileHeader** — asserts: ctx.contains('COACH CASE FILE (durable strategy)'); ctx.contains('Upcoming moment:'); ctx.contains('in 3 days'); ctx.contains('Board update'); ctx does NOT contain 'will struggle'/'predict'
- **userContext_noUpcomingMoment_noLineEmitted** — asserts: ctx does NOT contain 'Upcoming moment:' — append-and-omit, no placeholder below the (presence) floor
- **horizonParity_durableLineAndPerTurnGate_agree** — asserts: +60d: durable line present; +61d: durable line absent — same boundary as CoachContextBuilder.swift:1537, locking coach-lens visibility parity

## Risks

PRIMARY (roadmap-named, low): copy that implies a PREDICTION or a moment->focus link that hardens into a claim. Mitigated by: fixed tentative copy with explicit 'not a prediction' qualifier, association-only focus framing ('tends to need'), conservative nil-focus for ambiguous kinds, and tests 6/8/18 asserting banned predictive tokens absent. The moment contributes NOTHING to evidenceCount/lever/verdict (verified upstream-of-assignment at build), so it can never strengthen a psychological hypothesis.

ARCHITECTURE (the decisive correction): the roadmap's literal instruction ('in CoachCaseFile.build select the soonest future BigMomentStore entry') would break the purity contract of CoachCaseFile.build (a CoachMemory->CoachCaseFile transform that must never reach a @MainActor singleton; doc comment :815-820). Following it verbatim would also make build non-testable off-main-actor and couple the case spine to BigMomentStore.shared. CORRECTED: raw moment threaded in via CoachMemory from SessionFinalizer:254 (the existing store-reading site), exactly mirroring lastTransferReport. If this correction is rejected, readyToImplement is false.

STALENESS (mitigated): a frozen daysUntil would lie after a few days. Mitigated by storing only the raw BigMoment and recomputing daysUntil/derivedFocus every build against `now` (test 17), so the read self-corrects on the next rebuild and drops automatically once passed (test 2).

FIVE BUILD CALL SITES: missing the `?? previous?.upcomingBigMoment` fallback would silently drop the moment on partial rebuilds (noteTransferOutcome etc. at :1666-1720). Mitigated by setting it on CoachMemory with the same fallback lastTransferReview uses (test 14).

COHERENCE DRIFT: the durable case line vs the existing per-turn moment line (:1537), forward plan (:35-36), and post-rep note (:924-958) could disagree on visibility/day-count. Mitigated by sharing forwardHorizonDays=60 and the same daysUntil calendar math (test 20). The post-rep 14-day window is a deliberate tighter sub-window, documented as such.

DOUBLE-SURFACING (minor): the moment now appears in BOTH the per-turn context block AND the durable case-file block of the same prompt. This is intentional (transient urgency vs durable strategy), matches how lastTransferReview also appears in both coachCaseFileLines and coachCaseFormulationLines (:2199 + :2247), and the framings differ (timing nudge vs forward-awareness for case formulation). Flagged for review in case the LLM finds it redundant.

## Open questions

- Should an upcoming moment ALONE (no hypothesis/focus/intervention/transfer) be allowed to seed a case file? This spec keeps the existing :845-851 presence guard UNCHANGED (moment is forward context, not a reason a case exists), locked by test 12. A professional coach arguably WOULD open a working note the moment a real event is scheduled — if product agrees, relax the guard to include `upcomingMoment != nil` and update test 12. Defaulting to the conservative no.
- ForwardPlanService/ForwardPlanCoordinator (:35-36) and PostRepCoachNoteService (:924-958) already read the same activeMoment for their own copy. Should derivedFocus be unified so the case-file's 'kind of skill this moment needs' cannot contradict the forward plan's focus for the same moment? Recommend a follow-up that has both read CoachUpcomingMoment.focus(for:) — out of scope for this data-bridge slice but the coherence risk is real.
- Should CaseReviewCard (user-facing, :263) render the upcoming moment so the durable read is visible to the USER, not just the LLM? The roadmap scopes initiative #2 to the durable case + one context line, so this spec leaves the card unchanged — but full coach-lens parity (one read on every surface) would eventually surface it in the card. Confirm deferral.
- derivedFocus mapping (presentation->structure, interview->answerDevelopment, review->closingStrength, publicSpeaking->openingStrength) is a reasonable-but-untuned association. Validate against real coaching judgment / the existing SpeakingChallenge.recommendedPriority mapping (PracticeSupport.swift:411) before treating it as settled; it is intentionally conservative (nil for conversation/other).
- forwardHorizonDays = 60 mirrors the existing per-turn gate (:1537). The post-rep note uses 14 days for urgency. Confirm 60 is the right DURABLE-awareness horizon for the case file (long enough that the coach can time interventions to a deadline, not so long the line is noise) — tunable, no telemetry yet.

