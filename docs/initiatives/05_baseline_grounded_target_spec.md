# Initiative #5 — Ground the observable success bar in the user's actual baseline numbers (coach-parity stage: Intervention; milestone M16). The change is surgical and lives almost entirely in one pure producer: PrimaryFocusMemory.buildSuccessCriterion already computes priorAverage (the user's real pre-prescription metric average) at Noum/PrimaryFocusMemory.swift:1412 but throws it away — criterionSummary (1435) only receives the rounded threshold + window, so every user on the same goal hears the identical boilerplate ("3 or fewer fillers per rep across 2 reps"). The fix: thread priorAverage AND its sample depth (priorValues.count) into criterionSummary so it interpolates the real figure as tracking-toward language ("your recent reps averaged ~4.2 fillers — let's hold to 3 or fewer across 2 reps") ONLY when >=3 prior reps exist; below that, return today's exact generic string verbatim. Because the single CoachSuccessCriterion.summary field is the ONLY thing that surfaces, the coach-lens "one coherent read" is satisfied automatically — the same string already flows to the chat-coach context, the intervention-cycle context, the visible CaseReviewCard, and the next-practice blueprint target. A tiny bounded baseline snapshot (priorAverage + sampleDepth) is persisted on CoachSuccessCriterion so the figure is stable across rebuilds and auditable. No new store/engine/screen/routing; extends the named owner PrimaryFocusMemory.activeIntervention prescription path exactly as the roadmap directs. Mirrors initiative #1's discipline (docs/initiatives/01_adaptation_loop_spec.md): a pure named gate constant with an asserted boundary, a bounded decode-safe defaulted new field, association/tracking-toward language never causal, no claim below its evidence floor.

Generated: 2026-06-01

> Implementation-ready spec, code-grounded. readyToImplement: false — until predecessor gate + open-question sign-off.

## Ground-truth checks (verified against real code)

- **MISSING / CORRECTED** — State owner updateActiveInterventionFromRecommendation exists (cited by roadmap first-step + this brief)
    _grep across Noum/ NoumTests/ *.swift returns ZERO hits for updateActiveInterventionFromRecommendation. The real prescription path is activeIntervention(pending:outcomes:sessions:previous:now:calendar:) at Noum/PrimaryFocusMemory.swift:1302, which calls enrichWithCase(...) at :1321, which calls buildSuccessCriterion(...) at :1335/:1397, which calls criterionSummary(...) at :1431/:1435. The roadmap explicitly warned at least one cited field name may be wrong — this is it._
- **MISSING / CORRECTED** — Field/surface targetLine exists
    _grep -rn targetLine across Noum/ NoumTests/ *.swift returns ZERO hits. No such symbol anywhere. The qualitative observable target is CoachCaseFile.observableTarget (PrimaryFocusMemory.swift:827), sourced from intervention.target (free-text marker, e.g. 'One clean final sentence') at :839 — NOT from the numeric bar._
- **MISSING / CORRECTED** — Field/surface successLine exists
    _grep -rn successLine across Noum/ NoumTests/ *.swift returns ZERO hits. The success-bar string the user actually hears is CoachSuccessCriterion.summary (PrimaryFocusMemory.swift:133), surfaced via CoachCaseFile.successMeasure (:828) which is built by successMeasureSummary(:953) from criterion.summary(:955)._
- OK — criterionSummary is the function that builds the user-facing success-bar string and is the correct edit site
    _Noum/PrimaryFocusMemory.swift:1435 private static func criterionSummary(metric:threshold:window:) -> String. Exactly ONE caller: buildSuccessCriterion at :1431. Switches on metric to emit the bar string._
- OK — priorAverage is already computed in buildSuccessCriterion and is the user's real baseline figure
    _Noum/PrimaryFocusMemory.swift:1411-1414: let priorValues = Array(values.dropFirst(window)); let priorAverage = priorValues.isEmpty ? nil : priorValues.reduce(0,+)/Double(priorValues.count). values come from followedRepValues (1383-1395, sorted date-desc, limit 8). It is the pre-prescription average the threshold is already derived from (:1419-1423) but never surfaced._
- OK — buildSuccessCriterion has a single caller (the prescription path) so the change is contained
    _grep buildSuccessCriterion: only Noum/PrimaryFocusMemory.swift:1335 (caller, inside enrichWithCase) and :1397 (definition). enrichWithCase is called only from activeIntervention(:1313)._
- OK — CoachSuccessCriterion is a plain synthesized-Codable struct, so a new stored property must be Optional+defaulted for decode safety
    _Noum/PrimaryFocusMemory.swift:128-148: struct CoachSuccessCriterion: Codable, Equatable with metric/comparator/threshold/evaluationWindow/summary and NO custom CodingKeys or init(from:). CoachIntervention (:539) already uses this exact pattern: successCriterion/criterionStatus/reviewDueAt are `= nil` defaulted optionals (:550-552) with a doc comment (:536-538) saying memories persisted before the case file decode unchanged._
- OK — The success-bar string surfaces on ALL coaching surfaces via the single criterion.summary field (coach-lens auto-satisfied)
    _Surface 1 (visible card): CaseReviewCard.swift:168 Text(criterion.summary). Surface 2 (chat-coach + case-file context): CoachContextBuilder.swift:2186-2190 emits observableTarget + successMeasure (successMeasure = successMeasureSummary -> criterion.summary). Surface 3 (intervention-cycle context): CoachContextBuilder.swift:2284-2286 lines.append('- Success criterion: (criterion.summary)...'). Surface 4 (next-practice blueprint): PracticeSupport.swift:7643-7645 RecommendationBiasEngine returns intervention.successCriterion?.summary as the blueprint target fallback. All four read the SAME stored field._
- OK — caseEvaluationWindow (the window dropped before computing priorAverage) = 2, which is BELOW the 3-5 evidence floor — so the numeric gate must count priorValues.count, not reuse evaluationWindow
    _Noum/PrimaryFocusMemory.swift:1300 private static let caseEvaluationWindow = 2. priorValues = values.dropFirst(2) (:1411), so priorAverage becomes non-nil with as few as 3 followed reps total — but a *numeric personalized* bar needs >=3 PRIOR reps per the roadmap floor. The gate is priorValues.count >= numericGroundingMinReps, independent of evaluationWindow._
- OK — The BaselineConfidence ladder to mirror exists with the named 3-5 boundary
    _Noum/BaselineEngine.swift:101-133: enum BaselineConfidence { insufficient=0 (0-2), tentative=1 (3-4), moderate=2 (5-9), established=3, stable=4 }; from(sessionCount:) at :112-120; isReliable: self >= .moderate at :132. The roadmap's '~3-5 recent reps' maps to: tentative begins at 3 (the floor we adopt), reliable at 5. We mirror the 3-rep floor, not isReliable's 5, because the roadmap says 'at least ~3-5'._
- OK — caseMetric only ever yields .fillersPerRep or .sessionScore via this path (never .durationSeconds), so numeric copy must cover those two; durationSeconds branch is reachable only if metric were set otherwise
    _Noum/PrimaryFocusMemory.swift:1360-1370 caseMetric returns (.fillersPerRep,.atMost) when ahCounter or haystack contains 'filler', else (.sessionScore,.atLeast). Never .durationSeconds. metricValue (:1372-1380) maps fillersPerRep->session.fillerWordCount (Int), sessionScore->session.score (Int?), durationSeconds->session.duration._
- OK — The decisive end-to-end test that exercises the real producer has only 2 prior reps, so it falls to the generic string and stays green
    _NoumTests/NoumTests.swift:11057-11088 buildAttachesFillerSuccessCriterionWithStatusFromFollowedReps: 4 ahCounterSessions fillers [1,2,5,5]; priorValues = dropFirst(2) = [5,5], count 2 < 3 floor -> generic. Asserts threshold==4 (:11084) and criterionStatus==.met (:11086) — neither touches summary text, so unaffected._
- OK — Locked tests that assert the EXACT current generic summary strings construct CoachSuccessCriterion directly (bypassing criterionSummary), so they are immune to the producer change
    _NoumTests/NoumTests.swift:5651-5656 + assert :5686 ('3 or fewer fillers per rep across 2 reps'); :16352-16357 + assert :16372 ('1 or fewer fillers per rep across 2 reps'); CoachSuccessCriterionTests :11640-11674 builds criteria with summary:'test'. All construct the struct literally; none call criterionSummary/buildSuccessCriterion. The only end-to-end assertion (:10802) is .contains('score of'), which the numeric copy also satisfies (the bar still names 'score of N or higher')._
- OK — Initiative #1 shipped artifacts exist and are the discipline template to mirror
    _Noum/PracticeSupport.swift:6297 struct RecommendationAdaptationVerdict, :6320 enum RecommendationAdaptationAnalyzer with named thresholds (minMovementRepsToAdapt=3 at :6322, replaceRecentLevelCeiling=-0.5 at :6342); NoumTests/NoumTests.swift:10273 @Suite RecommendationAdaptationAnalyzerTests. Confirms the pure-reducer + named-asserted-threshold + decode-safe-defaulted-field pattern is the house style._
- OK — PracticeSession field types used by the metric path
    _Noum/SpeechRecognizerViewModel.swift:623-643: fillerWordCount: Int (:626), duration: TimeInterval (:627), date: Date (:628), mode: PracticeMode (:629), score: Int? (:631). Confirms numeric figures are an Int count (fillers) or Int score (1-10)._
## New types / fields

No new top-level type. ONE new bounded, decode-safe, defaulted stored property on the existing CoachSuccessCriterion struct (PrimaryFocusMemory.swift:128), plus a refactor of criterionSummary's signature.

(1) New persisted baseline snapshot field on CoachSuccessCriterion (append AFTER `var summary: String` at :133, keeping synthesized Codable; Optional+default makes pre-existing JSON decode unchanged exactly like successCriterion/criterionStatus/reviewDueAt on CoachIntervention):

    /// The user's own pre-prescription baseline for this criterion's metric,
    /// captured when the bar was set. Optional + nil-defaulted so criteria
    /// persisted before baseline grounding decode unchanged (synthesized
    /// Codable uses decodeIfPresent for optionals). nil means "thin sample —
    /// the bar uses generic copy". Bounded by construction (a metric average +
    /// a small Int count); no unbounded text.
    var baselineSnapshot: BaselineSnapshot? = nil

    struct BaselineSnapshot: Codable, Equatable {
        /// The averaged pre-prescription metric value (fillers/rep or score).
        var priorAverage: Double
        /// How many prior reps the average is over — the honest sample depth.
        /// Numeric personalized copy is emitted ONLY when this is >= the named
        /// floor; below it the snapshot is not even constructed (stays nil).
        var sampleDepth: Int
    }

(2) New named gate constant on PrimaryFocusMemory (beside caseEvaluationWindow at :1300), with an asserted boundary test (mirrors initiative #1's minMovementRepsToAdapt=3):

    /// Minimum prior reps (in the criterion's own metric/mode) before the
    /// success bar interpolates the user's real number. Mirrors the
    /// BaselineConfidence.tentative floor (BaselineEngine.swift:103, 3 sessions)
    /// and the roadmap's "~3-5 recent reps" gate. Below this the bar keeps the
    /// existing generic copy verbatim. Counts PRIOR reps (values.dropFirst(
    /// caseEvaluationWindow)), so it is strictly stricter than caseEvaluationWindow=2.
    private static let numericGroundingMinReps = 3

(3) criterionSummary signature change (add the optional snapshot; back-compatible — the durationSeconds arm and both generic arms are preserved):

    private static func criterionSummary(
        metric: CoachCaseMetric,
        threshold: Double,
        window: Int,
        baseline: CoachSuccessCriterion.BaselineSnapshot? = nil   // nil => existing generic copy
    ) -> String

(4) buildSuccessCriterion (:1397) constructs the snapshot only above the floor and passes it through:

    let snapshot: CoachSuccessCriterion.BaselineSnapshot? =
        (priorAverage != nil && priorValues.count >= numericGroundingMinReps)
            ? CoachSuccessCriterion.BaselineSnapshot(priorAverage: priorAverage!, sampleDepth: priorValues.count)
            : nil
    return CoachSuccessCriterion(
        metric: metric, comparator: comparator, threshold: threshold,
        evaluationWindow: window,
        summary: criterionSummary(metric: metric, threshold: threshold, window: window, baseline: snapshot),
        baselineSnapshot: snapshot
    )

No other type changes. The Double->display rounding inside criterionSummary should format priorAverage to one decimal for fillers (e.g. "~4.2") and a whole number / one-decimal for score, bounded to the metric's natural range (fillers >= 0, score 0...10) so a noisy average can never print an absurd figure.

## Wiring edits

- **Noum/PrimaryFocusMemory.swift** @ struct CoachSuccessCriterion, after `var summary: String` (:133) — Add the nested `struct BaselineSnapshot: Codable, Equatable { var priorAverage: Double; var sampleDepth: Int }` and the `var baselineSnapshot: BaselineSnapshot? = nil` stored property with the decode-safety doc comment. Keep synthesized Codable (no CodingKeys). Equatable is auto-derived. This is the ONLY schema change; mirrors the optional-defaulted case-spine fields on CoachIntervention (:550-552).
- **Noum/PrimaryFocusMemory.swift** @ beside `private static let caseEvaluationWindow = 2` (:1300) — Add `private static let numericGroundingMinReps = 3` with the doc comment anchoring it to BaselineConfidence.tentative (BaselineEngine.swift:103) and the roadmap floor.
- **Noum/PrimaryFocusMemory.swift** @ buildSuccessCriterion body, between priorAverage computation (:1412-1414) and the CoachSuccessCriterion(...) return (:1426-1432) — Construct `snapshot` only when `priorAverage != nil && priorValues.count >= numericGroundingMinReps`; pass `baseline: snapshot` into criterionSummary and `baselineSnapshot: snapshot` into the CoachSuccessCriterion initializer. No change to the existing threshold math (:1416-1424) or the metric/comparator (:1404).
- **Noum/PrimaryFocusMemory.swift** @ criterionSummary signature + body (:1435-1451) — Add the `baseline: CoachSuccessCriterion.BaselineSnapshot? = nil` parameter. When baseline == nil: return the EXISTING generic strings byte-for-byte (the current switch bodies, unchanged). When baseline != nil: prepend a tracking-toward clause naming the real figure, e.g. fillers -> 'your recent reps averaged ~\(fmt(avg)) fillers — hold to \(count) or fewer per rep across \(reps)'; score -> 'your recent reps averaged \(fmt(avg)) — aim for \(count) or higher across \(reps)'. Never causal; the figure is the user's own number, framed as where they are, not what the drill did. Format avg to one decimal, clamp to metric range.
- **Noum/PrimaryFocusMemory.swift** @ enrichWithCase carry-forward branch (:1331-1343) — NO code change required, but note: when isSamePrescription carries the PREVIOUS criterion (:1332-1333), it now also carries the previous baselineSnapshot for free (it's part of the struct). This is correct — the bar (and its grounding figure) is defined once at prescription and held stable across rebuilds, matching the existing 'defined once rather than re-derived' contract (:1317-1320). Verify in a test that a carried criterion keeps its numeric copy.
- **NoumTests/NoumTests.swift** @ new @Suite beside CoachSuccessCriterionTests (:11640) or inside the CoachMemoryEngine build suite — Add the BaselineGroundedSuccessCriterionTests suite (matrix below). Reuse the existing ahCounterSession (:11562) and session (:11589) factories; add a small helper that builds N ahCounterSessions with given filler values at descending dates to control priorValues.count precisely across the 2/3/5-rep boundary.

## Evidence & copy model

FLOOR (honest gate): A numeric, personalized bar is emitted ONLY when priorValues.count >= numericGroundingMinReps (=3), where priorValues = values.dropFirst(caseEvaluationWindow=2) — i.e. >=3 PRIOR reps in the criterion's own (metric, mode) beyond the 2 reps the bar is judged against, so >=5 followed reps total in that metric before a number appears. This is strictly stricter than the existing priorAverage!=nil condition (which needs only 1 prior rep) and mirrors the BaselineConfidence.tentative floor (3 qualifying sessions, BaselineEngine.swift:103). Rationale for choosing 3 over isReliable's 5: the roadmap says '~3-5 recent reps' and 'specificity MAY strengthen as reps accumulate'; 3 is the conservative entry, and sampleDepth is persisted so a later follow-up could escalate wording at 5+ without another schema change.

BELOW THE FLOOR: priorValues.count in {0,1,2} -> baselineSnapshot stays nil -> criterionSummary returns the EXISTING generic string verbatim (no behavior change; all current tests green). This includes the decisive buildAttachesFiller... test (priorValues.count==2).

COPY RULES (tracking-toward, never causal — mirrors anti-goals 'No causation language' and initiative #1's association-only register):
- The figure is framed as the user's CURRENT position, never as a drill effect: 'your recent reps averaged ~4.2 fillers — hold to 3 or fewer across 2 reps'. NEVER 'this drill brought you from 4.2', NEVER 'because', 'caused', 'improved by'.
- Bar specificity is bounded: print the threshold the existing math already produces (one-better rounding); the only new text is the user's averaged starting figure + a 'hold to / aim for' verb. No new precise sub-rep claims ('under 4%') are invented off thin data — the gate guarantees >=3 prior reps before any number.
- Status framing is unchanged: criterionStatus (met/notYetMet/pending) continues to flow from CoachCriterionStatus.contextLabel and is appended by successMeasureSummary(:957) / CoachContextBuilder(:2285). The numeric bar describes the target; the status describes tracking — together they are 'tracking toward / not yet tracking toward', exactly the roadmap's required register.
- Number formatting clamps to the metric's natural range (fillers >= 0; score 0...10) and one decimal, so a noisy/outlier average can never print a negative or out-of-range figure.

WHAT STAYS UNPERSISTED / BOUNDED: baselineSnapshot carries ONLY (Double priorAverage, Int sampleDepth) — no transcript, no per-rep array, no PII. It is captured at prescription and held stable (carried forward on same-prescription rebuilds), so the figure never silently drifts rep-to-rep. The qualitative observableTarget (intervention.target) is untouched — it remains the free-text marker; only the measurable bar (criterion.summary) gains the number.

## Coherence surfaces (coach-lens: one read everywhere)

Because the change is confined to the single CoachSuccessCriterion.summary field (and its persisted baselineSnapshot), the coach-lens 'ONE coherent read across every surface' is satisfied STRUCTURALLY — every surface already reads that one field, so they update in lockstep with zero per-surface edits:

1. Visible UI — CaseReviewCard.swift:168 `Text(criterion.summary)`. The user sees the same baseline-grounded bar on the case-review card they hear in chat. No edit needed; it renders whatever summary holds.

2. Chat-coach + case-file context — CoachContextBuilder.swift:2189-2190 emits `- Success measure: (caseFile.successMeasure)`, where successMeasure = PrimaryFocusMemory.successMeasureSummary(:953-959) = criterion.summary + status tail. No edit needed.

3. Intervention-cycle context — CoachContextBuilder.swift:2284-2286 emits `- Success criterion: (criterion.summary)(statusTail)` directly. No edit needed. (Note: surfaces 2 and 3 both fire in the same prompt build but under different headers — CASE FILE vs INTERVENTION CYCLE — both now carry the identical grounded figure, which is the desired single read, not a contradiction.)

4. Next-practice blueprint — PracticeSupport.swift:7643-7645 returns `intervention.successCriterion?.summary` as the blueprint target when intervention.target is absent. The next prescribed rep's success line is the same grounded bar. No edit needed (the locked test :16372 uses a thin-baseline literal criterion, so it keeps generic copy and stays green).

The ONLY producer touched is criterionSummary; the four consumers are deliberately left untouched so coherence is enforced by construction rather than by replicating logic across surfaces (the exact failure mode initiative #1 guarded against with its 'one read everywhere' coach-lens resolution). Verification obligation: one context test must assert that when a >=3-prior-rep memory is built end-to-end, BOTH the CoachContextBuilder 'Success measure' line AND the 'Success criterion' line contain the same averaged figure substring.

## Test matrix

- **thinBaseline_twoPriorReps_keepsGenericString** — asserts: successCriterion.summary == '3 or fewer fillers per rep across 2 reps' (or current exact generic for threshold 4 -> '4 or fewer fillers per rep across 2 reps'); successCriterion.baselineSnapshot == nil; threshold==4 and criterionStatus==.met still hold (regression guard on the pre-existing assertions).
- **populatedBaseline_threePriorReps_emitsNumericPersonalizedBar** — asserts: baselineSnapshot != nil; baselineSnapshot.sampleDepth==3; baselineSnapshot.priorAverage==5.0; summary contains 'averaged' AND '~5' (or '5.0') AND 'fillers' AND the threshold count; summary does NOT contain 'because'/'caused'/'improved'/'failed'.
- **floorBoundary_exactlyThreePriorReps_isThresholdNotTwo** — asserts: count 2 -> baselineSnapshot==nil & generic; count 3 -> baselineSnapshot!=nil & numeric. Locks numericGroundingMinReps==3 as the exact boundary (mirrors initiative #1's exactlyThreeMovingReps boundary discipline).
- **scoreMetric_populatedBaseline_emitsAimForFigure** — asserts: summary contains 'averaged' AND '5' AND ('aim for' or 'or higher') AND the threshold; never causal tokens; still contains 'score of' substring so the existing :10802 contains-check style stays satisfiable.
- **numericFigureClampedToMetricRange** — asserts: printed figure is within [0, inf) for fillers and [0,10] for score; one-decimal format; no negative or >10 printed even with outlier reps.
- **decodeSafety_criterionPersistedBeforeSnapshot_decodesWithNilSnapshot** — asserts: decode succeeds; baselineSnapshot == nil; summary/threshold/etc round-trip equal. Proves the new optional field is back-compatible (synthesized Codable + Optional default).
- **carriedForwardCriterion_keepsNumericCopyAndSnapshot** — asserts: B.activeIntervention.successCriterion === carried (same summary string AND same baselineSnapshot) — the bar is defined once and held stable (locks the :1332-1333 carry-forward path doesn't drop the snapshot or recompute a weaker bar).
- **newPrescription_recomputesBaselineFromCurrentHistory** — asserts: B builds a fresh criterion whose baselineSnapshot reflects the NEW prescription's history, not A's. Proves the recompute branch (:1335) populates the snapshot correctly.
- **coherence_allSurfacesCarrySameFigure** — asserts: the context string contains the averaged-figure substring under BOTH 'Success measure:' (CASE FILE) AND 'Success criterion:' (INTERVENTION CYCLE), and that substring equals what CaseReviewCard would show (criterion.summary). Locks the single-read coherence guarantee.
- **associationLanguage_noCausalClaim_numericBranches** — asserts: each contains a count/figure AND a 'hold to'/'aim for' verb; NONE contains any of {because, caused, improved, failed, proves, guarantee, thanks to, due to the drill}. The single most important copy-safety lock, mirroring initiative #1 test 20.
- **existingLockedGenericTests_unbroken** — asserts: all pass unchanged — they construct CoachSuccessCriterion literally (bypassing criterionSummary), so the producer change cannot affect them; documents that no existing assertion is invalidated.

## Risks

RISK 1 (primary, named by roadmap): A precise figure off a thin/noisy sample reads as fake certainty. Mitigation: numericGroundingMinReps=3 PRIOR reps (>=5 total) gate with verbatim generic fallback; figure clamped to metric range + one decimal; tracking-toward not causal framing. RISK 2: priorAverage already feeds the threshold math (:1419-1423), so surfacing it could feel circular ('averaged 5, aim for 4' is exactly the -1 rule). This is acceptable and honest — a real coach states the starting number AND the one-better target — but the copy must not imply the target is arbitrary; 'one better than where you are' is the implicit, defensible logic. RISK 3 (data density, mirrors initiative #1 open Q1): followedRepValues caps at limit:8 (:1388) and filters to a single (metric,mode); it is unverified in production how often a real user reaches >=5 same-mode reps before the bar is set, so the numeric path may fire rarely early on. Acceptable — graceful generic fallback means the feature is never wrong, only sometimes generic; sampleDepth is persisted for a future telemetry check. RISK 4: caseMetric never yields .durationSeconds via this path, so the durationSeconds arm of criterionSummary stays generic-only; leaving its numeric branch unimplemented is correct (no dead 'complete' copy), but a code comment should note it. RISK 5: the figure is captured once and carried forward on same-prescription rebuilds — if the user's baseline genuinely shifts mid-intervention the displayed starting number can lag; this matches the existing 'defined once' contract for threshold/window and is the intended stable-bar behavior, not a bug. RISK 6 (regression): two CoachContextBuilder emission paths (CASE FILE :2189 + INTERVENTION CYCLE :2286) now both carry the figure in one prompt; confirm via the coherence test this reads as one consistent bar, not a doubled/contradictory claim.

## Open questions

- Floor value: adopt 3 (BaselineConfidence.tentative entry) or 5 (isReliable / BaselineConfidence.moderate)? The roadmap says '~3-5'. Spec proposes 3 as the conservative entry with sampleDepth persisted so wording could escalate at 5+ later. Confirm Jordan wants the number to appear at 3 reps, or prefers the stricter 5-rep reliable bar before ANY figure shows.
- Wording escalation: should the copy strengthen as sampleDepth grows (e.g. tentative '~around 5' at 3-4 reps vs firmer 'averaging 5.0' at 5+)? Persisting sampleDepth enables this without a schema change; out of scope for the first step but worth a decision.
- durationSeconds numeric copy: caseMetric never produces it today, so its numeric branch is intentionally left generic. Confirm acceptable to leave a documented gap rather than implement unreachable copy (engineering-bans forbids dead 'complete' logic, so generic is the honest default).
- Figure-vs-threshold circularity: because priorAverage drives the threshold (one-better rounding), the bar will read 'averaged N, hold to N-1'. Confirm this transparent logic is the desired coach voice and not perceived as the target being trivially derived.
- Should the next-practice blueprint (PracticeSupport.swift:7643) ALSO surface the figure when intervention.target IS present (currently summary is only the fallback)? Out of scope — observableTarget is the qualitative marker by design — but flag for coherence review.

