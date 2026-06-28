import Foundation

// MARK: - Deterministic coach reasoning pass

enum CoachReasoningPass {

    static func assess(
        turnDepth: CoachTurnDepth,
        userQuestion: String,
        trajectory: UserTrajectorySnapshot,
        rubric: ActiveGoalRubric,
        surface: CoachReplySurface,
        recentProofTests: [String] = [],
        previousCoachReply: String? = nil
    ) -> CoachAssessment {
        let repairFocus = repairFocus(
            for: userQuestion,
            previousCoachReply: previousCoachReply,
            turnDepth: turnDepth
        )
        let scores = rubric.rubric.dimensions.map { dimension in
            score(dimension: dimension, trajectory: trajectory)
        }
        let weightedMechanics = weightedScore(scores: scores, rubric: rubric.rubric)
        let goalReadiness = goalReadinessScore(scores: scores, coverage: trajectory.evidenceCoverage)
        let preferredDimensionID = preferredProofDimensionID(
            for: userQuestion,
            scores: scores,
            turnDepth: turnDepth
        )
        let focusLabel = preferredDimensionID.flatMap { id in
            rubric.rubric.dimensions.first { $0.id == id }?.label
        }
        let directVerdict = verdict(
            depth: turnDepth,
            mechanics: weightedMechanics,
            goalReadiness: goalReadiness,
            coverage: trajectory.evidenceCoverage,
            rubricName: rubric.rubric.displayName,
            focusDimensionID: preferredDimensionID,
            focusLabel: focusLabel,
            repairFocus: repairFocus
        )
        let evidence = evidenceLines(
            from: trajectory,
            limit: turnDepth == .deepAssessment ? 4 : 2,
            repairFocus: repairFocus,
            turnDepth: turnDepth
        )
        let missing = missingEvidence(from: scores, trajectory: trajectory, depth: turnDepth)
        let proofTest = nextProofTest(
            from: scores,
            rubric: rubric.rubric,
            surface: surface,
            preferredDimensionID: preferredDimensionID,
            recentProofTests: recentProofTests
        )

        return CoachAssessment(
            turnDepth: turnDepth,
            surface: surface,
            questionRestatement: restatement(for: userQuestion, depth: turnDepth),
            directVerdict: directVerdict,
            confidence: confidence(coverage: trajectory.evidenceCoverage, mechanics: weightedMechanics, depth: turnDepth),
            evidenceUsed: evidence,
            rubricScores: scores,
            missingEvidence: missing,
            nextProofTest: proofTest,
            responseMode: responseMode(depth: turnDepth, surface: surface),
            toneMode: toneMode(depth: turnDepth, repairFocus: repairFocus),
            repairFocus: repairFocus
        )
    }

    private static func score(
        dimension: RubricDimension,
        trajectory: UserTrajectorySnapshot
    ) -> RubricScore {
        let pack = trajectory.latestRepEvidencePack
        let transcript = (pack?.transcriptExcerpt ?? "").lowercased()
        let fillerCount = pack?.fillerCount ?? 0
        let wpm = pack?.wordsPerMinute
        let score = pack?.score
        let sessionCount = trajectory.sessionCount

        let raw: Double
        let evidence: [String]
        switch dimension.id {
        case "verdict_first":
            let hasVerdict = containsAny(transcript, [
                "recommend", "recommendation", "decision", "the answer",
                "my answer", "the point", "i would", "we should"
            ])
            raw = hasVerdict ? 0.72 : (score.map { Double($0) / 12.0 } ?? 0.35)
            evidence = hasVerdict ? ["latest transcript appears to lead with a decision word"] : ["no clear verdict-first proof in the available excerpt"]
        case "hedge_control":
            let hedgeHits = countOccurrences(in: transcript, needles: [
                "maybe", "probably", "kind of", "sort of", "just", "i think"
            ])
            raw = max(0.20, min(0.92, 0.88 - Double(hedgeHits) * 0.16 - Double(fillerCount) * 0.03))
            evidence = ["latest rep had \(fillerCount) fillers and \(hedgeHits) hedge markers in the available excerpt"]
        case "clean_close":
            let trailing = transcript.hasSuffix("yeah") || transcript.hasSuffix("so") || transcript.hasSuffix("um") || transcript.hasSuffix("uh")
            raw = trailing ? 0.35 : (score.map { min(0.82, Double($0) / 10.0) } ?? 0.48)
            evidence = trailing ? ["available excerpt suggests a soft trailing close"] : ["no trailing close problem visible in the available excerpt"]
        case "pressure_stability":
            let hasPressureEvidence = trajectory.recentSessionLines.contains {
                let lower = $0.lowercased()
                return lower.contains("sudden") || lower.contains("pressure") || lower.contains("ah-counter")
            }
            raw = hasPressureEvidence ? min(0.78, 0.45 + Double(sessionCount) / 20.0) : min(0.55, Double(sessionCount) / 18.0)
            evidence = hasPressureEvidence ? ["recent history includes a pressure-style rep"] : ["no explicit pressure-mode proof in the current evidence pack"]
        case "controlled_pacing":
            if let wpm {
                let paceScore = wpm < 105 ? 0.48 : (wpm > 175 ? 0.50 : 0.76)
                raw = max(0.25, paceScore - Double(fillerCount) * 0.025)
                evidence = ["latest pace estimate \(wpm) WPM with \(fillerCount) fillers"]
            } else {
                raw = 0.42
                evidence = ["no reliable pace estimate in the latest evidence pack"]
            }
        case "salience":
            let hasSalience = containsAny(transcript, ["because", "so ", "therefore", "means", "matters"])
            raw = hasSalience ? 0.64 : 0.38
            evidence = hasSalience ? ["available excerpt has a reason or implication marker"] : ["no memorable point or implication proof in the available excerpt"]
        default:
            raw = 0.45
            evidence = ["no dimension-specific evidence available"]
        }

        let confidence = min(0.90, max(0.20, trajectory.evidenceCoverage))
        return RubricScore(
            dimensionID: dimension.id,
            label: dimension.label,
            score: min(1.0, max(0.0, raw)),
            confidence: confidence,
            evidence: evidence,
            missingEvidence: raw >= 0.70 ? nil : dimension.missingIfAbsent
        )
    }

    private static func verdict(
        depth: CoachTurnDepth,
        mechanics: Double,
        goalReadiness: Double,
        coverage: Double,
        rubricName: String,
        focusDimensionID: String?,
        focusLabel: String?,
        repairFocus: String?
    ) -> String {
        switch depth {
        case .quickMove:
            if let focusDimensionID {
                return quickMoveVerdict(for: focusDimensionID, focusLabel: focusLabel)
            }
            return "The next useful move is narrow: test one observable change, not a new plan."
        case .groundedRead:
            if let focusLabel {
                return "The grounded read should stay local to \(focusLabel.lowercased()) in the latest evidence."
            }
            return "The grounded read is local to the latest evidence, not a verdict on the whole goal."
        case .trustRepair:
            if repairFocus != nil {
                return "The repair is to name the miss first, then answer with one useful move."
            }
            return "The prior answer needs repair: it should answer the real question before offering advice."
        case .deepAssessment:
            if coverage < 0.35 {
                return "I do not have enough evidence for an overall \(rubricName.lowercased()) verdict yet."
            }
            if mechanics >= 0.68 && goalReadiness < 0.62 {
                return "You are closer mechanically than you are to fully sounding authoritative."
            }
            if goalReadiness >= 0.72 && coverage >= 0.70 {
                return "You are approaching the \(rubricName.lowercased()) standard, but it still needs pressure proof."
            }
            return "You have useful pieces, but the full \(rubricName.lowercased()) standard is not proven yet."
        }
    }

    private static func quickMoveVerdict(
        for dimensionID: String,
        focusLabel: String?
    ) -> String {
        switch dimensionID {
        case "controlled_pacing":
            return "Pacing is the next lever: add one deliberate beat before the reason, then judge the same answer."
        case "clean_close":
            return "The ending is the next lever: make the final sentence the ask or decision, then stop."
        case "verdict_first":
            return "The opening is the next lever: put the verdict in sentence one, then prove it once."
        case "hedge_control":
            return "Directness is the next lever: replace one hedge with a plain recommendation."
        case "pressure_stability":
            return "Pressure is the next lever: repeat the same answer under a timer and protect sentence one."
        case "salience":
            return "Salience is the next lever: add one concrete detail, then return to the ask."
        default:
            if let focusLabel {
                return "The next useful move is \(focusLabel.lowercased()): test one observable change, not a new plan."
            }
            return "The next useful move is narrow: test one observable change, not a new plan."
        }
    }

    private static func evidenceLines(
        from trajectory: UserTrajectorySnapshot,
        limit: Int,
        repairFocus: String?,
        turnDepth: CoachTurnDepth
    ) -> [String] {
        var lines: [String] = []
        if turnDepth == .trustRepair,
           let repairFocus {
            lines.append("trust repair signal: \(repairFocus)")
        }
        if let pack = trajectory.latestRepEvidencePack {
            lines.append(contentsOf: pack.evidenceLines)
        }
        lines.append(contentsOf: trajectory.trendLines)
        if let summary = trajectory.coachCaseSummary {
            if let focus = summary.focus { lines.append("case focus: \(focus)") }
            if let evidence = summary.evidenceSummary { lines.append("case evidence: \(evidence)") }
        }
        return Array(lines.prefix(limit))
    }

    private static func missingEvidence(
        from scores: [RubricScore],
        trajectory: UserTrajectorySnapshot,
        depth: CoachTurnDepth
    ) -> [String] {
        guard depth == .deepAssessment || depth == .trustRepair else {
            return []
        }
        let dimensionGaps = scores
            .filter { $0.score < 0.68 }
            .compactMap(\.missingEvidence)

        // The two cardinal honesty disclosures — the coverage floor and the
        // unproven-under-pressure gap — must never be evicted by dimension-
        // specific gaps. On a weak rep that fails three-plus dimensions at once,
        // the old `.append` + `.prefix(3)` quietly dropped the pressure
        // disclosure exactly when stakes-readiness mattered most, letting the
        // read imply more readiness than the evidence supports. Order the
        // disclosures the coach must always surface ahead of the rest, then cap.
        var priority: [String] = []
        if trajectory.evidenceCoverage < 0.70 {
            priority.append("Need repeated evidence across more than one clean rep before calling the user close overall.")
        }
        let pressureGaps = dimensionGaps.filter { $0.lowercased().contains("pressure") }
        let otherGaps = dimensionGaps.filter { !$0.lowercased().contains("pressure") }
        if pressureGaps.isEmpty && !priority.contains(where: { $0.lowercased().contains("pressure") }) {
            priority.append("Need pressure-mode evidence before treating the goal as ready for real stakes.")
        }
        return Array(unique(priority + pressureGaps + otherGaps).prefix(3))
    }

    private static func nextProofTest(
        from scores: [RubricScore],
        rubric: GoalRubric,
        surface: CoachReplySurface,
        preferredDimensionID: String?,
        recentProofTests: [String]
    ) -> String {
        let sortedIDs = scores.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID < $1.dimensionID
        }.map(\.dimensionID)
        let orderedIDs: [String]
        if let preferredDimensionID {
            orderedIDs = [preferredDimensionID] + sortedIDs.filter { $0 != preferredDimensionID }
        } else {
            orderedIDs = sortedIDs
        }
        let recentKeys = Set(recentProofTests.map(proofTestKey).filter { !$0.isEmpty })
        for id in orderedIDs {
            guard let dimension = rubric.dimensions.first(where: { $0.id == id }) else { continue }
            for candidate in proofTestCandidates(for: dimension, surface: surface) where !recentKeys.contains(proofTestKey(candidate)) {
                return candidate
            }
        }
        let fallbackID = orderedIDs.first ?? rubric.dimensions[0].id
        let fallbackDimension = rubric.dimensions.first { $0.id == fallbackID } ?? rubric.dimensions[0]
        return proofTestCandidates(for: fallbackDimension, surface: surface).first ?? fallbackDimension.proofTest
    }

    private static func proofTestCandidates(
        for dimension: RubricDimension,
        surface: CoachReplySurface
    ) -> [String] {
        let candidates: [String]
        switch dimension.id {
        case "verdict_first":
            candidates = [
                dimension.proofTest,
                "Run a 45-second answer with the recommendation first, then give exactly one proof point.",
                "Open the next rep with the decision before any context."
            ]
        case "hedge_control":
            candidates = [
                dimension.proofTest,
                "Replay the answer once and replace one hedge with a direct recommendation.",
                "Record one rep and turn the first maybe/probably into a plain verb."
            ]
        case "clean_close":
            candidates = [
                dimension.proofTest,
                "End the next rep on the exact ask, then stop before adding a summary.",
                "Make the final sentence the ask or decision, then leave the silence there."
            ]
        case "pressure_stability":
            candidates = [
                dimension.proofTest,
                "Repeat the prompt with a timer and keep the first sentence as the answer, not setup.",
                "Run the same prompt under pressure and check whether the close stays decisive."
            ]
        case "controlled_pacing":
            candidates = [
                dimension.proofTest,
                "Run the next rep with a one-beat pause before the reason and no restart.",
                "Place one silent beat after the verdict, then finish the reason in one sentence."
            ]
        case "salience":
            candidates = [
                dimension.proofTest,
                "Use one specific detail that makes the point memorable, then return to the ask.",
                "Add one concrete example after the verdict, then stop before a second example."
            ]
        default:
            candidates = [dimension.proofTest]
        }
        return candidates.map { surface == .live ? liveVersion(of: $0) : $0 }
    }

    private static func proofTestKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func liveVersion(of test: String) -> String {
        if test.lowercased().contains("75-second") {
            return "Do one 60-second answer: verdict first, one reason, clean stop."
        }
        if test.lowercased().contains("60-90") {
            return "Repeat it under a 60-second timer and keep the verdict first."
        }
        return test
    }

    private static func weightedScore(scores: [RubricScore], rubric: GoalRubric) -> Double {
        guard !scores.isEmpty else { return 0 }
        let totalWeight = scores.reduce(0.0) { partial, score in
            partial + (rubric.defaultWeights[score.dimensionID] ?? 0.10)
        }
        guard totalWeight > 0 else { return 0 }
        return scores.reduce(0.0) { partial, score in
            partial + score.score * (rubric.defaultWeights[score.dimensionID] ?? 0.10)
        } / totalWeight
    }

    private static func goalReadinessScore(scores: [RubricScore], coverage: Double) -> Double {
        guard !scores.isEmpty else { return 0 }
        let average = scores.map(\.score).reduce(0, +) / Double(scores.count)
        return min(average, coverage)
    }

    private static func confidence(coverage: Double, mechanics: Double, depth: CoachTurnDepth) -> Double {
        let depthCap: Double = depth == .deepAssessment ? 0.82 : 0.72
        return min(depthCap, max(0.20, coverage * 0.80 + mechanics * 0.20))
    }

    private static func responseMode(depth: CoachTurnDepth, surface: CoachReplySurface) -> CoachAssessment.ResponseMode {
        if surface == .live { return .immediateOnly }
        switch depth {
        case .deepAssessment, .trustRepair:
            return .expandable
        case .quickMove, .groundedRead:
            return .immediateOnly
        }
    }

    private static func toneMode(
        depth: CoachTurnDepth,
        repairFocus: String?
    ) -> CoachAssessment.ToneMode {
        switch depth {
        case .trustRepair:
            return .repair
        case .deepAssessment:
            return .challenge
        case .groundedRead:
            return .explain
        case .quickMove:
            return repairFocus == nil ? .prescribe : .validate
        }
    }

    private static func repairFocus(
        for userQuestion: String,
        previousCoachReply: String?,
        turnDepth: CoachTurnDepth
    ) -> String? {
        guard turnDepth == .trustRepair else { return nil }
        let lower = userQuestion.lowercased()
        let previous = previousCoachReply?.lowercased() ?? ""
        if containsAny(lower, ["cold", "robotic", "not human", "low eq", "not high eq"]) {
            return "I sounded cold instead of giving a human coach read"
        }
        if containsAny(lower, ["too much writing", "too long", "less writing", "shorter", "get to the point", "straight to the point"]) {
            return "I used too much writing before the useful read"
        }
        if containsAny(lower, ["not informative", "not helpful", "not useful", "missed the point", "doesn't answer", "does not answer"]) {
            return "I missed the actual question before prescribing"
        }
        if containsAny(lower, ["generic", "generic ai", "generic tips"]) ||
            containsAny(previous, ["keep practicing", "practice more", "communicate clearly", "be clear and concise"]) {
            return "I leaned on generic advice instead of evidence"
        }
        if TurnDepthClassifier.isSoftPushback(lower) {
            return "there is friction underneath the polite pushback"
        }
        return "the prior answer did not earn trust before prescribing"
    }

    private static func preferredProofDimensionID(
        for userQuestion: String,
        scores: [RubricScore],
        turnDepth: CoachTurnDepth
    ) -> String? {
        let lower = userQuestion.lowercased()
        if containsAny(lower, ["slow", "pace", "rushing", "too fast", "unsure", "pause", "breath"]) {
            return "controlled_pacing"
        }
        if containsAny(lower, ["ending", "close", "closing", "ask", "stop", "land"]) {
            return "clean_close"
        }
        if containsAny(lower, ["opening", "start", "first sentence", "verdict", "point first", "lead with", "headline"]) {
            return "verdict_first"
        }
        if containsAny(lower, ["filler", "fillers", "um", "uh", "ah", "hedge", "maybe", "probably", "kind of", "sort of"]) {
            return "hedge_control"
        }
        if containsAny(lower, ["pressure", "stakes", "timer", "under fire", "interrupt", "real room"]) {
            return "pressure_stability"
        }
        if containsAny(lower, ["depth", "example", "memorable", "stick", "story", "salience", "boring"]) {
            return "salience"
        }

        // Broad distance-to-goal questions should still be governed by the
        // weakest observed dimension, especially pressure evidence. Tactical
        // turns get no forced fallback here so the sorted weakest score below
        // remains the last-resort source of truth.
        if turnDepth == .deepAssessment {
            return nil
        }
        return scores.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID < $1.dimensionID
        }.first?.dimensionID
    }

    private static func restatement(for question: String, depth: CoachTurnDepth) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        switch depth {
        case .quickMove: return "What should I do next?"
        case .groundedRead: return "What happened in that rep?"
        case .deepAssessment: return "How far off am I from my goal?"
        case .trustRepair: return "That was not helpful."
        }
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static func countOccurrences(in value: String, needles: [String]) -> Int {
        needles.reduce(0) { count, needle in
            count + (value.contains(needle) ? 1 : 0)
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values {
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(value)
        }
        return output
    }
}
