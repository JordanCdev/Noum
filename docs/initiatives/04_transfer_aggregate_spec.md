# Initiative #4 — Aggregate Big Moment outcomes into a tentative cross-event transfer read (coach-parity stages: Transfer real-world + Case formulation; target M18). Add ONE pure, bounded, unit-testable reducer `BigMomentTransferTrend.build(from:now:)` living in Noum/BigMomentStore.swift beside `recentOutcomeReports`, mirroring the discipline of the shipped `CoachReflectionPattern` (Noum/PrimaryFocusMemory.swift:331-420) — a pure static reducer over an existing array with named thresholds and a forming/repeated confidence enum. It groups the store's existing `outcomeReports` by `BigMomentCategory` (the 'moment kind') over a bounded recent window, counts perceived-response direction (derived from the existing `ReportedAudienceResponse` + `ReportedMomentOutcome`), and only when >=3 outcomes of the SAME kind share a dominant direction emits a tentative, association-only, self-report-framed per-kind trend line. Wired onto all coaching surfaces that already carry transfer (coach-lens coherence): the per-turn REAL-WORLD TRANSFER block (CoachContextBuilder.userContext, augmenting the flat emission at :312-319), the durable case-file `transferRead` (CoachCaseFile.build at PrimaryFocusMemory.swift:843), and — gated on user confirmation, never auto-written — the durable case file. Below the >=3-same-kind floor, each outcome stays the single self-report the flat block already prints; nothing aggregated is claimed and nothing is persisted.

Generated: 2026-06-01

> Implementation-ready spec, code-grounded. readyToImplement: false — until predecessor gate + open-question sign-off.

## Ground-truth checks (verified against real code)

- OK — State owner BigMomentStore exists at the cited path with the outcome array to reduce over
    _Noum/BigMomentStore.swift:181 `final class BigMomentStore: ObservableObject`; `@Published private(set) var outcomeReports: [BigMomentOutcomeReport]` :186; `static let outcomeReportCap = 12` :194; `func recentOutcomeReports(limit: Int = 2)` :276_
- OK — Roadmap-cited 'recentOutcomeReports at line 276' — line number correct, but cited default and 'flat list' framing need the real cap
    _`recentOutcomeReports(limit: Int = 2)` is at Noum/BigMomentStore.swift:276 exactly; it returns `Array(outcomeReports.prefix(limit))` :278 with default 2 — confirming the per-turn surface only ever sees the newest 2, which is why an aggregate must read the full `outcomeReports` (capped 12, :194)_
- **MISSING / CORRECTED** — Roadmap-cited perceived-response field naming: 'perceived-response direction' / example copy '2 better-than-expected, 1 as-expected' — THE LITERAL FIELD VALUES DO NOT EXIST
    _There is NO better/as-expected axis anywhere. The real types are `enum ReportedMomentOutcome { case wentWell, mixed, fellShort }` (Noum/BigMomentStore.swift:82-104) and `enum ReportedAudienceResponse { case engaged, unclear, resistant }` (:109-131). The 'perceived response' the roadmap means is `BigMomentOutcomeReport.audienceResponse: ReportedAudienceResponse` (:141). The aggregate must group on these real enums; the roadmap's example copy string must be discarded._
- OK — 'moment kind' to group by exists on the report
    _`BigMomentOutcomeReport.category: BigMomentCategory` (Noum/BigMomentStore.swift:139); `enum BigMomentCategory: String, Codable, CaseIterable` with presentation/interview/review/conversation/publicSpeaking/other (:8-53) and a `.displayName` for sentence-embeddable copy (:43-52). 'kind' == `category`._
- OK — Each report carries a timestamp for bounded-recent-window ordering
    _`BigMomentOutcomeReport.recordedAt: Date` (Noum/BigMomentStore.swift:143); store inserts newest-first via `updated.insert(report, at: 0)` (:296)._
- OK — recordOutcome dedupes by moment, so per-kind grouping aggregates DISTINCT moments (no double-count of one re-reported moment)
    _`recordOutcome` does `var updated = outcomeReports.filter { $0.momentID != moment.id }` then inserts at 0 (Noum/BigMomentStore.swift:295-297) — at most one report per momentID. So N>=3 of a kind = 3 distinct real events, which is exactly the honest-threshold intent._
- OK — CoachContextBuilder has the flat recentOutcomeReports emission to augment — but roadmap line number '~1509' is WRONG
    _The REAL-WORLD TRANSFER block is at Noum/CoachContextBuilder.swift:312-319 (`if !recentMomentOutcomes.isEmpty { ... lines.append("REAL-WORLD TRANSFER") ... for report in recentMomentOutcomes.prefix(2) { lines.append("- \(report.coachContextLine)") } ... }`), NOT line 1509. The param is `recentMomentOutcomes: [BigMomentOutcomeReport] = []` at :234._
- OK — CoachCaseFile exists and ALREADY has the durable transfer field the roadmap wants 'a confirmed recurring read to populate'
    _`struct CoachCaseFile: Codable, Equatable` (Noum/PrimaryFocusMemory.swift:821); `var transferRead: String?` :831; built from `memory.lastTransferReview?.reportedOutcomeLine` :843 — TODAY a SINGLE most-recent report, not an aggregate. This is precisely the flat surface to deepen. CoachCaseFile uses synthesized Codable (no custom init(from:)), so a new optional sibling field is automatically decode-safe._
- OK — CoachCaseFile is rendered into context (the case-file transfer surface)
    _`coachCaseFileLines` at Noum/CoachContextBuilder.swift:2198-2200: `if let transfer = caseFile.transferRead { lines.append("- Transfer read: \(transfer) User-reported; not proof of causation.") }`._
- OK — A SECOND case-formulation transfer surface exists (so coherence requires touching both reads or consciously scoping)
    _`coachCaseFormulationLines` at Noum/CoachContextBuilder.swift:2247-2249 prints `Transfer case update:` from `memory.lastTransferReview.reportedOutcomeLine`. This is the single-event review line; it stays as-is (single most-recent event) and the new aggregate rides the `transferRead` durable field, so they do not contradict._
- OK — The data path that builds CoachCaseFile currently receives only ONE transfer report, so the build path must be extended to see the array
    _SessionFinalizer.swift:254 passes `latestTransferReport: BigMomentStore.shared.recentOutcomeReports(limit: 1).first` into `CoachMemoryStore.refresh` (PrimaryFocusMemory.swift:1621, param :1632) -> `CoachMemoryEngine.build` (:970, param `latestTransferReport: BigMomentOutcomeReport? = nil` :982) -> `memory.lastTransferReview = latestTransferReport.map { CoachTransferReview(report: $0) }` :1141 -> `CoachCaseFile.build(from: memory, now:)` :1147/:835. To populate an aggregate durable read, build() needs the trend, which needs the full reports array threaded in (new defaulted param) — NOT the single report._
- OK — CoachReflectionPattern is the exact in-house mirror for a pure bounded self-report reducer with named thresholds + forming/repeated confidence
    _Noum/PrimaryFocusMemory.swift:331-420: `static let minimumSampleSize = 3`, `minimumDominantCount = 2`, `dominanceRatio = 0.5`; `static func build(from:windowSize:) -> CoachReflectionPattern?`; `enum CoachReflectionPatternConfidence { case forming, repeated }` (:314); `var reportedLine` (:391). This is the shape to clone for the transfer trend._
- OK — userContext caller count forces a defaulted new parameter
    _`grep -c 'CoachContextBuilder.userContext('` = 63 call sites across app + tests. New emission must reuse the already-passed data or add a defaulted param; chosen design reuses the store's outcomeReports via a new defaulted `momentTransferTrend:`/`recentMomentOutcomes` path so all 63 sites compile._
- OK — CoachMemory persists with decodeIfPresent for every optional (back-compat pattern to follow for any new memory field)
    _Noum/PrimaryFocusMemory.swift:779-812 custom `init(from:)` uses `decodeIfPresent` for caseFile, lastTransferReview, reflectionPattern, etc. If a structured trend is added to CoachMemory it must follow this; but the chosen design adds NO new CoachMemory stored field (the trend is recomputed at build), so no CoachMemory CodingKeys change is required._
- OK — No symbol collision for the proposed new type names
    _grep for `BigMomentTransferTrend|TransferReadSummary|TransferTrend|CrossEventTransfer|MomentOutcomeSummary|recurringTransfer` across all *.swift returns nothing (exit 1, no matches)._
- OK — systemPrompt already carries the association-not-proof rule for REAL-WORLD TRANSFER, so no new system rule is strictly required (optional reinforcement only)
    _Noum/CoachContextBuilder.swift:86 rule 9: 'When REAL-WORLD TRANSFER is present, it is the user's report ... never call it objective proof or claim a drill caused the result.' Asserted by NoumTests.swift:9933-9938._
- OK — Existing tests lock the current flat-block copy that must remain intact
    _NoumTests.swift:9908-9931 `userReportedTransferOutcomeAppearsWithProvenanceGuard` asserts 'REAL-WORLD TRANSFER', 'the user reported it went well', 'not objective evidence'; NoumTests.swift:5830-5861 asserts the single-event 'Transfer case update' line. The augment must be ADDITIVE so both still pass._
- **MISSING / CORRECTED** — There is currently NO confirmation/persistence path that writes an AGGREGATE transfer read into the case file (so the 'confirmed before written' gate is net-new and must be designed, not reused wholesale)
    _The only `transferRead =` assignment is PrimaryFocusMemory.swift:843 off the single `lastTransferReview`. The existing confirm/reject machinery is hypothesis-only: `CoachHypothesisAcknowledgement` / `CoachHypothesisConfidence{confirmed,uncertain,rejected}` (:437-455) and `memory.hypothesisAcknowledgement` (:657). No transfer-specific acknowledgement exists._
## New types / fields

// =====================================================================
// 1) NEW PURE REDUCER + VALUE TYPE — Noum/BigMomentStore.swift
//    Inserted just AFTER `recentOutcomeReports(limit:)` (:279) as a pure
//    nonisolated static reducer (NOT a @MainActor method), so it is unit-
//    testable off-main like CoachReflectionPattern.build. Lives outside the
//    @MainActor class as a free struct, or as a `nonisolated static` on the
//    store; free struct preferred to mirror CoachReflectionPattern.
// =====================================================================

/// Direction of the user's PERCEIVED real-world reception for one moment,
/// derived from the two existing self-report axes. Deliberately three-valued
/// and self-report-only: this is the user's read of the room, never a
/// measured outcome.
enum PerceivedTransferDirection: String, Codable, Equatable {
    case positive   // wentWell AND/OR engaged, with no resistance
    case mixed      // genuinely mixed / hard-to-read
    case negative   // fellShort AND/OR resistant

    // Pure mapping from the two existing enums. Conservative: any resistance
    // OR fellShort pulls to .negative unless clearly offset; engaged+wentWell
    // is the only clean .positive. Everything else is .mixed (the honest
    // "we can't call it" bucket). Asserted exhaustively in tests.
    static func from(outcome: ReportedMomentOutcome,
                     audience: ReportedAudienceResponse) -> PerceivedTransferDirection {
        switch (outcome, audience) {
        case (.wentWell, .engaged):              return .positive
        case (.fellShort, _), (_, .resistant):   return .negative
        default:                                 return .mixed
        }
    }
}

/// A bounded, tentative cross-event transfer read for ONE moment kind. This
/// is NOT a measured outcome and NOT a diagnosis: it is a count of the user's
/// own self-reports across distinct real events of the same category, surfaced
/// only past an honest recurrence floor, always association-not-causation.
/// Mirrors CoachReflectionPattern (PrimaryFocusMemory.swift:331) in shape.
struct BigMomentKindTransferRead: Codable, Equatable {
    let category: BigMomentCategory
    let dominantDirection: PerceivedTransferDirection
    let dominantCount: Int          // events sharing the dominant direction
    let sampleSize: Int             // total distinct events of this kind in window
    let positiveCount: Int
    let mixedCount: Int
    let negativeCount: Int

    // One tentative, self-report-framed, association-only line. Reads e.g.
    // "Across the user's last 3 interviews, their own read of the room was
    //  2 positive, 1 mixed (self-reported reception, not a measured outcome)."
    var coachContextLine: String { /* see Evidence model for exact copy */ }
}

/// The full cross-event transfer read: at most one BigMomentKindTransferRead
/// per qualifying kind, plus the strongest single recurring read for the
/// durable case file. Pure reducer; no store mutation, no persistence here.
struct BigMomentTransferTrend: Codable, Equatable {
    // Named thresholds — every boundary asserted by a test (mirror
    // CoachReflectionPattern :332-335 + roadmap honest-evidence threshold).
    static let recurrenceFloor      = 3   // >=3 same-kind events before ANY trend
    static let minDominantCount     = 2   // dominant direction must hold >=2
    static let dominanceRatio       = 0.5 // dominant must be >= half the kind's events
    static let recentWindowCap      = 12  // == BigMomentStore.outcomeReportCap (:194)
    static let confidentRecurrence  = 4   // >=4 same-direction => stronger ("repeated") tone

    let perKind: [BigMomentKindTransferRead]   // only kinds clearing recurrenceFloor
    let strongestRead: BigMomentKindTransferRead?  // candidate for the durable case file

    /// PURE. Groups by category over the most-recent `recentWindowCap` reports,
    /// counts PerceivedTransferDirection per kind, and emits a kind read only
    /// when sampleSize >= recurrenceFloor AND a dominant direction clears
    /// minDominantCount + dominanceRatio. Returns nil when nothing qualifies
    /// (true below-floor / cold-start). Sorts internally by recordedAt desc so
    /// it is order-independent given distinct timestamps.
    static func build(from reports: [BigMomentOutcomeReport],
                      now: Date = Date()) -> BigMomentTransferTrend?
}

// =====================================================================
// 2) BigMomentStore — bounded computed accessor (the roadmap's "first step":
//    "alongside recentOutcomeReports add a pure computed summary")
//    Inserted right after recentOutcomeReports (:279).
// =====================================================================
extension BigMomentStore {
    /// Bounded computed cross-event transfer read over the existing
    /// `outcomeReports`. Pure read; no new stored state. nil until a kind
    /// clears the recurrence floor.
    func transferTrend(now: Date = Date()) -> BigMomentTransferTrend? {
        BigMomentTransferTrend.build(from: outcomeReports, now: now)
    }
}

// =====================================================================
// 3) CoachCaseFile — NEW durable structured field (decode-safe, defaulted).
//    CoachCaseFile uses SYNTHESIZED Codable, so an Optional sibling is
//    automatically decode-safe (missing key -> nil). Keep `transferRead`
//    (:831) as the single-event rendered line for back-compat.
// =====================================================================
struct CoachCaseFile { // (additions only)
    // ... existing fields including `var transferRead: String?` (:831) ...

    /// Durable cross-event transfer read — populated ONLY by a user-CONFIRMED
    /// recurring read (see Evidence model). Optional + defaulted nil so every
    /// existing persisted case file decodes unchanged. Distinct from
    /// `transferRead` (the latest single self-report line) by design.
    var confirmedTransferTrend: BigMomentKindTransferRead? = nil
}

// =====================================================================
// 4) CoachContextBuilder.userContext — NEW defaulted param so all 63 callers
//    compile. The aggregate is computed by the caller (BigMomentStore.transferTrend)
//    and passed in, keeping userContext a pure value-transform.
// =====================================================================
// add to the signature (after recentMomentOutcomes :234):
//   momentTransferTrend: BigMomentTransferTrend? = nil

// =====================================================================
// 5) Data-path threading for the DURABLE confirmed read (no new CoachMemory
//    STORED field — the trend is recomputed at build; only a CONFIRMED read
//    is carried). Two defaulted params, mirroring latestTransferReport:
//      CoachMemoryEngine.build(..., transferTrend: BigMomentTransferTrend? = nil,
//                                   confirmedTransferTrend: BigMomentKindTransferRead? = nil)
//      CoachMemoryStore.refresh(... same two defaulted params ...)
//    SessionFinalizer passes BigMomentStore.shared.transferTrend() and the
//    persisted confirmed read (see wiringEdits / Evidence model for the gate).

## Wiring edits

- **Noum/BigMomentStore.swift** @ Top-level types, after BigMomentOutcomeReport (:176) and before `@MainActor final class BigMomentStore` (:181) — beside the other model enums — Add `enum PerceivedTransferDirection` + `struct BigMomentKindTransferRead` + `struct BigMomentTransferTrend` (signatures in newTypesOrFields). All pure/nonisolated. `BigMomentTransferTrend.recentWindowCap` must equal `BigMomentStore.outcomeReportCap` (:194) — reference it directly, do not duplicate the literal.
- **Noum/BigMomentStore.swift** @ Inside the class, immediately after `recentOutcomeReports(limit:)` (:276-279) — Add the bounded computed accessor `func transferTrend(now: Date = Date()) -> BigMomentTransferTrend? { BigMomentTransferTrend.build(from: outcomeReports, now: now) }`. Pure read over existing `outcomeReports`; no new @Published state, no persistence.
- **Noum/CoachContextBuilder.swift** @ userContext signature, after `recentMomentOutcomes: [BigMomentOutcomeReport] = []` (:234) — Add defaulted param `momentTransferTrend: BigMomentTransferTrend? = nil`. All 63 call sites compile unchanged.
- **Noum/CoachContextBuilder.swift** @ Inside the `if !recentMomentOutcomes.isEmpty { ... }` REAL-WORLD TRANSFER block, between the per-report loop (:316) and the provenance line (:318) — AUGMENT (not replace) the flat emission: `if let trend = momentTransferTrend { for kindRead in trend.perKind { lines.append("- \(kindRead.coachContextLine)") } }`. The existing per-report lines (:315-316) and the provenance guard (:318) stay verbatim so locked test :9927-9930 still passes. The aggregate lines appear ONLY when a kind cleared the >=3 floor; below floor, only the single self-reports print (today's behavior).
- **Noum/AskNoumView.swift** @ The userContext call at :1188-1207, right after `recentMomentOutcomes: bigMomentStore.recentOutcomeReports(limit: 2)` (:1198) — Pass `momentTransferTrend: bigMomentStore.transferTrend()` so the per-turn chat coach carries the aggregate. (This is the live chat surface — coach-lens coherence requires it.)
- **Noum/PrimaryFocusMemory.swift** @ `struct CoachCaseFile` field list, after `var transferRead: String?` (:831) — Add `var confirmedTransferTrend: BigMomentKindTransferRead? = nil`. Synthesized Codable makes it decode-safe (missing key -> nil).
- **Noum/PrimaryFocusMemory.swift** @ `CoachCaseFile.build(from:now:)` (:835-867) — Add a `confirmedTransferTrend` param threaded from CoachMemory (see below) OR read `memory.confirmedTransferTrend`. Populate the new field ONLY from a user-confirmed read; the OR-guard at :845-851 gains `|| confirmedTransferTrend != nil` so a confirmed trend alone can keep the case file alive. The single-event `transferRead` (:843) is UNCHANGED.
- **Noum/PrimaryFocusMemory.swift** @ `CoachContextBuilder.coachCaseFileLines` (:2198-2200), right after the existing `transferRead` line — Emit the durable aggregate when confirmed: `if let t = caseFile.confirmedTransferTrend { lines.append("- Confirmed transfer trend: \(t.coachContextLine) User-confirmed self-report pattern; association, not proof of causation.") }`. This is the durable case-file surface.
- **Noum/PrimaryFocusMemory.swift** @ `CoachMemoryEngine.build` signature (:970-985) and `CoachMemoryStore.refresh` signature (:1621-1635) — Add two defaulted params to BOTH: `transferTrend: BigMomentTransferTrend? = nil` (for the tentative per-turn read if you prefer building it here instead of in the view) and `confirmedTransferTrend: BigMomentKindTransferRead? = nil` (the user-confirmed durable read). All existing call sites compile (defaulted). `refresh` forwards both to `build` exactly like `latestTransferReport` (:1648).
- **Noum/SessionFinalizer.swift** @ The `CoachMemoryStore.shared.refresh(...)` call (:243-255), right after `latestTransferReport:` (:254) — Pass `confirmedTransferTrend: <persisted confirmed read>`. The confirmed read is loaded from a small persisted store value (see Evidence model — minimal persistence on BigMomentStore or CoachMemory) so it survives across finalizes. Do NOT auto-populate from `BigMomentStore.shared.transferTrend()` here — the durable write requires explicit user confirmation.
- **NoumTests/NoumTests.swift** @ New `@Suite` beside BigMomentTransferStoreTests (:9706) and CoachReflectionPattern tests (:5752) — Add `BigMomentTransferTrendTests` (reducer matrix, see testMatrix) + extend the userContext transfer suite (:9908) with an aggregate-line context test + a below-floor silence test. Reuse the `BigMomentOutcomeReport(moment:outcome:audienceResponse:note:recordedAt:)` initializer (:145-168); pass distinct `recordedAt` for window/order cases (the init already accepts `recordedAt`, no factory bump needed).

## Evidence & copy model

HONEST FLOOR (mirrors roadmap initiative #4 + CoachReflectionPattern :332-335).

TENTATIVE vs CONFIDENT:
- 0..2 same-kind events => NO aggregate. The existing flat block already prints each as a single self-report (`coachContextLine`, BigMomentStore.swift:171-175 -> 'the user reported it went well; the audience or counterpart seemed engaged'). `BigMomentTransferTrend.build` returns nil; nothing aggregated is emitted. This is the silence-below-floor honesty rule.
- >=3 same-kind events with a dominant PerceivedTransferDirection clearing minDominantCount(2) AND dominanceRatio(0.5) => a TENTATIVE per-kind line in the per-turn REAL-WORLD TRANSFER block. Tone 'forming': 'their own read leaned ...'.
- >=4 same-direction => stronger ('repeated') tone, still association-only.

DIRECTION DERIVATION: PerceivedTransferDirection.from(outcome:audience:) is conservative — only (wentWell, engaged) is .positive; any fellShort OR resistant is .negative; all else .mixed. This avoids over-reading 'positive' transfer from ambiguous self-reports. Asserted exhaustively (9 input combinations).

WINDOW: most-recent `recentWindowCap`(=12, == outcomeReportCap) reports, sorted by recordedAt desc, so older events beyond the store cap can never inflate a trend. Because recordOutcome dedupes by momentID (:295), each counted event is a DISTINCT real moment.

ASSOCIATION-NEVER-CAUSATION + SELF-REPORT COPY RULES (every emitting line must satisfy, asserted in tests):
- MUST contain a self-report frame: 'their own read' / 'self-reported reception' / 'the user reported'.
- MUST contain the count and sample ('across the user's last N <kind>s').
- MUST contain a not-measured disclaimer ('not a measured outcome' / 'not objective evidence').
- MUST NOT contain: 'caused', 'because', 'proves', 'improved their interviews', 'guarantee', or any phrasing implying the practice produced the real-world result, or that the reception is an objective fact.
- The per-kind line uses `category.displayName` pluralized ('interviews', 'presentations', 'difficult conversations').
Example (forming): 'Across the user’s last 3 interviews, their own read of the room leaned positive (2 positive, 1 mixed) — self-reported reception, not a measured outcome.'

DURABLE CASE-FILE WRITE (the strict gate — roadmap: 'confirmed with the user before it is written into the case file'):
- `CoachCaseFile.confirmedTransferTrend` is populated ONLY after explicit user confirmation, NEVER auto-written from the computed trend. There is currently NO transfer-confirmation mechanism (groundTruth: only hypothesis acks exist), so this needs a minimal confirm signal. RECOMMENDED minimal design that EXTENDS owners and adds no new store: persist the user-confirmed `BigMomentKindTransferRead` (category + the snapshot it confirmed) on BigMomentStore via a new bounded persisted value (a single `confirmedTransferTrend` written through the existing UserDefaults plumbing at :327-331), surfaced by a one-tap confirm chip on the existing BigMomentOutcomeInlineCard / a coach-question reply — mirroring how `CoachHypothesisAcknowledgement` is captured. SessionFinalizer then threads that persisted confirmed read into `refresh -> build` so it lands on the durable case file. UNTIL confirmed, the trend lives ONLY in the per-turn tentative context lines and is NOT persisted anywhere. (The exact confirm-UI gesture is an open question; the data contract above is the load-bearing part and is what the durable write depends on.)
- A confirmed read is invalidated if its category's direction flips on fresh evidence (recompute on build; if the live trend’s dominant direction for that kind no longer matches the confirmed snapshot, drop the durable field and re-ask) — no stale durable claim, mirroring the hypothesis-ack snapshot guard (`appliesTo(currentHypothesis:)`, :871-875,:1131-1133).

WHAT STAYS UNPERSISTED: the tentative per-turn aggregate (recomputed each turn from `outcomeReports`); nothing aggregated touches CoachMemory's stored fields, so no CoachMemory CodingKeys change and no new memory decode-safety surface.

## Coherence surfaces (coach-lens: one read everywhere)

The cross-event transfer read is ONE judgment; coach-lens coherence requires it read the same on every surface that already carries transfer. Surfaces and how:

1. CHAT COACH (per-turn, tentative) — Noum/CoachContextBuilder.swift:312-319 REAL-WORLD TRANSFER block, augmented with `momentTransferTrend.perKind` lines, fed from AskNoumView.swift:1198 via the new `bigMomentStore.transferTrend()`. Tentative, self-report-framed, surfaces at >=3 same-kind. (live chat)

2. POST-REP / SESSION context — the SAME `userContext` builder is the single entry point for all assembled coach context (SessionFinalizer-built coach note, post-rep coaching), so the augmented block (#1) automatically gives post-rep the identical tentative line. No separate edit; coherence is structural.

3. DURABLE CASE FILE (confirmed only) — CoachCaseFile.confirmedTransferTrend, rendered at CoachContextBuilder.swift coachCaseFileLines (after :2200) as 'Confirmed transfer trend: ...'. This is the ONLY surface where the read is stated as a durable pattern, and ONLY after user confirmation. The wording is the SAME `BigMomentKindTransferRead.coachContextLine`, prefixed 'Confirmed', so the durable read never says something different from the tentative one — it is the same read, now confirmed.

4. SINGLE-EVENT REVIEW (unchanged, must not contradict) — coachCaseFormulationLines 'Transfer case update' (:2247-2249) and coachCaseFileLines 'Transfer read' (:2198-2200) keep describing the latest SINGLE event. The aggregate is additive and clearly labelled cross-event/'across your last N', so a reader never confuses the single most-recent self-report with the recurring pattern. Both coexist; neither overstates.

NON-SURFACES (deliberately): the leaderboard/proof surfaces never receive it (self-report, never published); no new meter card (editorial line in the existing transfer block, honoring the no-vanity-dashboard anti-goal).

## Test matrix

- **coldStart_noReports_returnsNil** — asserts: == nil; and build(from:) with 2 interview reports also == nil (below recurrenceFloor 3); BigMomentStore.transferTrend() == nil
- **belowRecurrenceFloor_twoSameKind_noTrendLine** — asserts: build == nil; perKind empty; userContext with these (limit-2 flat) still prints the two single self-report lines and NO 'across the user' aggregate line (the existing locked behavior at :9927-9930 is preserved)
- **exactlyThreeSameKind_dominantPositive_emitsForming** — asserts: perKind has one .interview read; dominantDirection == .positive; dominantCount == 2; sampleSize == 3; positiveCount==2,mixedCount==1; coachContextLine contains 'last 3 interviews' + 'their own read' + 'not a measured outcome'; does NOT contain 'caused'/'proves'/'improved'
- **threeSameKind_noDominantDirection_returnsNilForKind** — asserts: dominanceRatio(0.5) fails (max count 1 of 3) -> this kind NOT emitted; if it is the only kind, build == nil. Locks the 'a trend needs a real majority' rule
- **perceivedDirectionMapping_allNineCombinations** — asserts: (wentWell,engaged)==.positive; every (fellShort,*) and (*,resistant)==.negative; all remaining (e.g. (wentWell,unclear),(mixed,engaged),(mixed,unclear))==.mixed. Exhaustive lock on the polarity map
- **confidentRecurrence_fourSameDirection_strongerTone** — asserts: dominantCount==4, sampleSize==4; coachContextLine uses the >=4 'repeated' stronger phrasing yet still association-only (no 'caused'/'proves'); displayName pluralizes to 'presentations'
- **perKindIsolation_notGlobalAggregate** — asserts: perKind has TWO reads; interview dominant==.negative(3), conversation dominant==.positive(3); the two never merge; strongestRead is one of them deterministically (e.g. larger dominantCount, tie-broken by recordedAt)
- **windowCap_olderBeyond12_excluded** — asserts: only most-recent 12 evaluated -> dominant leans .positive (6 positive vs 6 negative within window? choose newest 6 positive + 6 of the negatives) — assert the build only ever counts <=12 and the stale oldest-3 negatives cannot flip the read; precise counts asserted against recentWindowCap
- **orderIndependence_givenRecordedAt** — asserts: identical BigMomentTransferTrend (Equatable) across all orderings — reducer sorts by recordedAt internally
- **decodeSafety_caseFileWithoutConfirmedTrend_decodesToNil** — asserts: decoded.confirmedTransferTrend == nil; decoded.transferRead unchanged; mirrors NoumTests.swift:10861 legacy-decode discipline
- **durableWrite_onlyOnConfirmation_notAutoPopulated** — asserts: resulting caseFile.confirmedTransferTrend == nil (computed trend alone NEVER auto-writes the durable field); when confirmedTransferTrend IS passed, caseFile.confirmedTransferTrend is populated
- **confirmedTrend_invalidatedWhenDirectionFlips** — asserts: build drops/refreshes the durable field (confirmedTransferTrend not stated as .positive against contradicting evidence) — no stale durable claim
- **userContext_aggregateLineAppearsUnderTransferHeader_atFloor** — asserts: ctx contains 'REAL-WORLD TRANSFER'; contains the aggregate 'last 3 interviews' line with self-report + not-measured framing; existing single-report lines still present; ctx does NOT contain 'caused'/'objective proof'
- **userContext_belowFloor_noAggregateLine** — asserts: ctx contains the two single self-report lines but NO 'across the user' aggregate; locked-behavior :9927-9930 intact
- **coachCaseFileLines_rendersConfirmedTrend** — asserts: context contains 'Confirmed transfer trend:' + the read line + 'association, not proof of causation'; absent when confirmedTransferTrend nil
- **associationLanguage_noCausalClaim_everyEmittingBranch** — asserts: every line contains a count + self-report frame + not-measured disclaimer; NONE contains {caused, because, proves, guarantee, 'improved their'}; the single most-important copy-safety lock (mirrors initiative #1 test 20)

## Risks

SELF-REPORT READS AS OBJECTIVE: perceived audience response is subjective; aggregating it can read as a measured real-world outcome. Mitigation: every emitting line carries an explicit self-report frame + 'not a measured outcome' disclaimer, the conservative PerceivedTransferDirection map, and the systemPrompt rule 9 (:86) already forbidding 'objective proof'. Asserted by associationLanguage test.

SMALL-SAMPLE FRAGILITY: per-kind windows are tiny (cap 12 split across 6 categories), so a 'trend' rests on 3 events. Mitigation: >=3-same-kind floor + >=2 dominant + 0.5 ratio; below floor only single self-reports print. OPEN: with the 12-report cap split across kinds it is unverified whether any kind reaches 3 in real usage — confident/durable transfer reads may be rare in practice (telemetry needed; the tentative loop still adds nothing false below floor).

OVER-EAGER DURABLE WRITE: writing the trend into the case file without consent would harden a subjective pattern into a 'fact'. Mitigation: confirmedTransferTrend is NEVER auto-populated; it requires an explicit user confirm signal and is invalidated on direction flip. The confirm GESTURE is net-new (no transfer-ack exists today) — this is the main design-completeness risk.

DIRECTION MAP BIAS: collapsing two 3-valued axes (outcome x audience) into one 3-valued direction loses nuance; the conservative map may under-call positives or over-call mixed. Mitigation: exhaustively asserted 9-combination test so the policy is auditable and tunable, not emergent.

PROVENANCE-LINE DRIFT / LOCKED-TEST REGRESSION: augmenting the REAL-WORLD TRANSFER block must stay additive or it trips :9927-9930 and :5858-5860. Mitigation: insert between the loop and the provenance line; both existing tests asserted still green in matrix.

BACK-COMPAT: new CoachCaseFile field is Optional + defaulted (synthesized Codable decode-safe); userContext + build + refresh params all defaulted (63 + 18-style call sites compile). No CoachMemory CodingKeys change because no new STORED memory field is added.

## Open questions

- DURABLE-WRITE CONFIRM GESTURE (load-bearing, needs product decision): no transfer-confirmation mechanism exists today (only CoachHypothesisAcknowledgement, PrimaryFocusMemory.swift:437-455/:657). The durable `confirmedTransferTrend` write depends on a user confirm signal. Recommended: a one-tap confirm chip on the existing BigMomentOutcomeInlineCard OR a coach-question reply, persisted through BigMomentStore's existing UserDefaults plumbing (:327-331) as a bounded value, then threaded via SessionFinalizer (:254) -> refresh -> build. Confirm this is acceptable vs deferring the durable write to a #4b follow-up and shipping ONLY the tentative per-turn aggregate first.
- ROADMAP COPY/FIELD MISMATCH (must resolve before writing copy): roadmap initiative #4 example ('2 better-than-expected, 1 as-expected') references a perceived-response axis that DOES NOT EXIST. The real axes are ReportedMomentOutcome{wentWell,mixed,fellShort} + ReportedAudienceResponse{engaged,unclear,resistant}. Confirm the PerceivedTransferDirection{positive,mixed,negative} derivation (and its conservative map) is the intended semantics for 'perceived-response direction'.
- WINDOW/CAP for the aggregate: should the trend window equal outcomeReportCap(12) or be smaller/recency-weighted? With 6 categories and a 12-report global cap, a kind rarely reaches 3. Confirm 12 (full available history) is right, or whether the store cap should rise for transfer depth.
- TENTATIVE-vs-DURABLE TONE STEP: is >=4-same-direction the right bar for the 'repeated' (stronger) tone, mirroring CoachReflectionPattern's count>=3 && window>=4 repeated rule (:376)? The transfer window is sparser, so 4 may be too high to ever reach.
- STRONGEST-READ TIE-BREAK across kinds: when two kinds both qualify, which becomes the durable candidate? Proposed: larger dominantCount, then most-recent recordedAt. Confirm this matches coach intent (most-evidenced vs most-recent kind).

