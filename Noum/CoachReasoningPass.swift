import Foundation

// MARK: - Deterministic coach reasoning pass

enum CoachReasoningPass {

    static func assess(
        turnDepth: CoachTurnDepth,
        userQuestion: String,
        trajectory: UserTrajectorySnapshot,
        rubric: ActiveGoalRubric,
        surface: CoachReplySurface
    ) -> CoachAssessment {
        let scores = rubric.rubric.dimensions.map { dimension in
            score(dimension: dimension, trajectory: trajectory)
        }
        let weightedMechanics = weightedScore(scores: scores, rubric: rubric.rubric)
        let goalReadiness = goalReadinessScore(scores: scores, coverage: trajectory.evidenceCoverage)
        let directVerdict = verdict(
            depth: turnDepth,
            mechanics: weightedMechanics,
            goalReadiness: goalReadiness,
            coverage: trajectory.evidenceCoverage,
            rubricName: rubric.rubric.displayName
        )
        let evidence = evidenceLines(from: trajectory, limit: turnDepth == .deepAssessment ? 4 : 2)
        let missing = missingEvidence(from: scores, trajectory: trajectory, depth: turnDepth)
        let proofTest = nextProofTest(from: scores, rubric: rubric.rubric, surface: surface)

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
            responseMode: responseMode(depth: turnDepth, surface: surface)
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
        rubricName: String
    ) -> String {
        switch depth {
        case .quickMove:
            return "The next useful move is narrow: test one observable change, not a new plan."
        case .groundedRead:
            return "The grounded read is local to the latest evidence, not a verdict on the whole goal."
        case .trustRepair:
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

    private static func evidenceLines(
        from trajectory: UserTrajectorySnapshot,
        limit: Int
    ) -> [String] {
        var lines: [String] = []
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
        var missing = scores
            .filter { $0.score < 0.68 }
            .compactMap(\.missingEvidence)
        if trajectory.evidenceCoverage < 0.70 {
            missing.insert("Need repeated evidence across more than one clean rep before calling the user close overall.", at: 0)
        }
        if !missing.contains(where: { $0.lowercased().contains("pressure") }) {
            missing.append("Need pressure-mode evidence before treating the goal as ready for real stakes.")
        }
        return Array(unique(missing).prefix(3))
    }

    private static func nextProofTest(
        from scores: [RubricScore],
        rubric: GoalRubric,
        surface: CoachReplySurface
    ) -> String {
        let weakestID = scores.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID < $1.dimensionID
        }.first?.dimensionID
        let dimension = rubric.dimensions.first { $0.id == weakestID } ?? rubric.dimensions[0]
        if surface == .live {
            return liveVersion(of: dimension.proofTest)
        }
        return dimension.proofTest
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
