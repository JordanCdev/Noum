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
        let isMemoryHandoff = TurnDepthClassifier.isMemoryHandoff(userQuestion.lowercased())
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
            turnDepth: turnDepth,
            isMemoryHandoff: isMemoryHandoff
        )
        let preferredProofTest = preferredProofTest(
            for: userQuestion,
            turnDepth: turnDepth
        )
        let focusLabel = preferredDimensionID.flatMap { id in
            rubric.rubric.dimensions.first { $0.id == id }?.label
        }
        let directVerdict = isMemoryHandoff
            ? memoryHandoffVerdict(previousCoachReply: previousCoachReply)
            : verdict(
                depth: turnDepth,
                mechanics: weightedMechanics,
                goalReadiness: goalReadiness,
                coverage: trajectory.evidenceCoverage,
                rubricName: rubric.rubric.displayName,
                focusDimensionID: preferredDimensionID,
                focusLabel: focusLabel,
                repairFocus: repairFocus,
                trajectory: trajectory
            )
        let evidence = evidenceLines(
            from: trajectory,
            limit: evidenceLimit(for: turnDepth),
            repairFocus: repairFocus,
            turnDepth: turnDepth,
            isMemoryHandoff: isMemoryHandoff,
            previousCoachReply: previousCoachReply
        )
        let missing = missingEvidence(from: scores, trajectory: trajectory, depth: turnDepth)
        let proofTest = isMemoryHandoff
            ? memoryHandoffProofTest(previousCoachReply: previousCoachReply)
            : nextProofTest(
                userQuestion: userQuestion,
                turnDepth: turnDepth,
                trajectory: trajectory,
                from: scores,
                rubric: rubric.rubric,
                surface: surface,
                preferredDimensionID: preferredDimensionID,
                preferredProofTest: preferredProofTest,
                repairFocus: repairFocus,
                recentProofTests: recentProofTests
            )

        return CoachAssessment(
            turnDepth: turnDepth,
            surface: surface,
            questionRestatement: restatement(for: userQuestion, depth: turnDepth),
            directVerdict: directVerdict,
            confidence: confidence(
                coverage: trajectory.evidenceCoverage,
                mechanics: weightedMechanics,
                scores: scores,
                depth: turnDepth
            ),
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
        repairFocus: String?,
        trajectory: UserTrajectorySnapshot
    ) -> String {
        switch depth {
        case .quickMove:
            return quickMoveVerdict(
                for: focusDimensionID,
                focusLabel: focusLabel,
                trajectory: trajectory
            )
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
        for dimensionID: String?,
        focusLabel: String?,
        trajectory: UserTrajectorySnapshot
    ) -> String {
        guard let dimensionID else {
            return trajectorySpecificQuickMoveVerdict(focusLabel: focusLabel, trajectory: trajectory)
        }
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
            return "Pressure is the next lever: repeat the same answer under a timer and protect the sentence where it leaks."
        case "salience":
            return "Salience is the next lever: add one concrete detail, then return to the ask."
        default:
            return trajectorySpecificQuickMoveVerdict(focusLabel: focusLabel, trajectory: trajectory)
        }
    }

    private static func trajectorySpecificQuickMoveVerdict(
        focusLabel: String?,
        trajectory: UserTrajectorySnapshot
    ) -> String {
        if let intervention = trajectory.activeInterventionState,
           let target = nonEmpty(intervention.target) ?? nonEmpty(intervention.title) {
            let targetPhrase = statementFragment(target)
            if intervention.followedRepCount > 0 {
                return "Stay with the active intervention: \(targetPhrase), then judge that same target again."
            }
            return "Start with the active intervention: \(targetPhrase), then judge that one target."
        }

        if let summary = trajectory.coachCaseSummary,
           let nextMove = nonEmpty(summary.nextCoachMove) {
            return "Use the case file's next move: \(statementFragment(nextMove))."
        }

        if let summary = trajectory.coachCaseSummary,
           let focus = nonEmpty(summary.focus) {
            return "The next useful move should stay on \(focus.lowercased()): change one observable sentence, then compare it."
        }

        if let pack = trajectory.latestRepEvidencePack {
            let mode = shortModeName(pack.mode)
            if pack.fillerCount > 0 {
                let noun = pack.fillerCount == 1 ? "filler" : "fillers"
                return "Use the latest \(mode) rep: replace one of the \(pack.fillerCount) \(noun) with a silent beat, then compare the sentence."
            }
            if let excerpt = pack.transcriptExcerpt?.lowercased(),
               containsAny(excerpt, ["recommend", "recommendation", "decision", "my answer", "i would"]) {
                return "Use the latest \(mode) rep: keep the verdict first and change only the close."
            }
            return "Use the latest \(mode) rep as the sample: change one sentence, then compare it with the original."
        }

        if let focusLabel {
            return "The next useful move is \(focusLabel.lowercased()): test one observable change, not a new plan."
        }
        return "The next useful move is narrow: test one observable change, not a new plan."
    }

    private static func evidenceLines(
        from trajectory: UserTrajectorySnapshot,
        limit: Int,
        repairFocus: String?,
        turnDepth: CoachTurnDepth,
        isMemoryHandoff: Bool,
        previousCoachReply: String?
    ) -> [String] {
        var lines: [String] = []
        if turnDepth == .trustRepair,
           let repairFocus {
            lines.append("trust repair signal: \(repairFocus)")
        }
        if isMemoryHandoff,
           let line = memoryHandoffEvidenceLine(previousCoachReply: previousCoachReply) {
            lines.append(line)
        }
        if let pack = trajectory.latestRepEvidencePack {
            lines.append(contentsOf: pack.evidenceLines)
        }
        if let summary = trajectory.coachCaseSummary {
            if let line = caseSummaryLine(from: summary) {
                lines.append(line)
            }
        }
        if let intervention = trajectory.activeInterventionState,
           let line = activeInterventionLine(from: intervention) {
            lines.append(line)
        }
        lines.append(contentsOf: trajectory.trendLines)
        return Array(unique(lines).prefix(limit))
    }

    private static func evidenceLimit(for depth: CoachTurnDepth) -> Int {
        switch depth {
        case .quickMove:
            return 2
        case .groundedRead:
            return 4
        case .deepAssessment, .trustRepair:
            return 8
        }
    }

    private static func caseSummaryLine(from summary: CoachCaseSummary) -> String? {
        var parts: [String] = []
        appendCasePart(&parts, label: "hypothesis", value: summary.hypothesis)
        appendCasePart(&parts, label: "focus", value: summary.focus)
        appendCasePart(&parts, label: "evidence", value: summary.evidenceSummary)
        appendCasePart(&parts, label: "next move", value: summary.nextCoachMove)
        guard !parts.isEmpty else { return nil }
        return "case summary: \(parts.joined(separator: "; "))"
    }

    private static func activeInterventionLine(from intervention: ActiveInterventionState) -> String? {
        var parts: [String] = []
        let title = intervention.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            parts.append(title)
        }
        appendCasePart(&parts, label: "target", value: intervention.target)
        parts.append("followed reps: \(intervention.followedRepCount)")
        appendCasePart(&parts, label: "review", value: intervention.reviewStatus)
        guard !parts.isEmpty else { return nil }
        return "active intervention: \(parts.joined(separator: "; "))"
    }

    private static func appendCasePart(
        _ parts: inout [String],
        label: String,
        value: String?
    ) {
        guard let value else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        parts.append("\(label): \(trimmed)")
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nonEmpty(_ value: String) -> String? {
        nonEmpty(Optional(value))
    }

    private static func statementFragment(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
    }

    private static func memoryHandoffVerdict(previousCoachReply: String?) -> String {
        if previousCoachReplyContainsDisagreementSetup(previousCoachReply) {
            return "Use this memory as a testable hypothesis only: disagreement may be getting softened by setup."
        }
        return "Use this memory as a testable hypothesis only, not a label."
    }

    private static func memoryHandoffEvidenceLine(previousCoachReply: String?) -> String? {
        guard let previousCoachReply,
              !previousCoachReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if previousCoachReplyContainsDisagreementSetup(previousCoachReply) {
            return "conversation hypothesis: disagreement may be getting softened by setup"
        }
        let first = previousCoachReply
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first, !first.isEmpty else { return nil }
        return "prior coach read: \(first)"
    }

    private static func memoryHandoffProofTest(previousCoachReply: String?) -> String {
        if previousCoachReplyContainsDisagreementSetup(previousCoachReply) {
            return "Keep it if two pressure reps show the point arrives late; drop it if verdict-first solves it."
        }
        return "Keep it only if two more reps show the same pattern; drop it if the targeted rep solves it."
    }

    private static func previousCoachReplyContainsDisagreementSetup(_ previousCoachReply: String?) -> Bool {
        guard let previousCoachReply else { return false }
        let lower = previousCoachReply.lowercased()
        return lower.contains("disagreement") &&
            (lower.contains("setup") || lower.contains("arrived after"))
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
        userQuestion: String,
        turnDepth: CoachTurnDepth,
        trajectory: UserTrajectorySnapshot,
        from scores: [RubricScore],
        rubric: GoalRubric,
        surface: CoachReplySurface,
        preferredDimensionID: String?,
        preferredProofTest: String?,
        repairFocus: String?,
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
        if let preferredProofTest,
           !preferredProofTest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !recentKeys.contains(proofTestKey(preferredProofTest)) {
            return surface == .live ? liveVersion(of: preferredProofTest) : preferredProofTest
        }
        for candidate in contextualProofTestCandidates(
            userQuestion: userQuestion,
            turnDepth: turnDepth,
            trajectory: trajectory,
            preferredDimensionID: preferredDimensionID,
            repairFocus: repairFocus
        ) {
            let rendered = surface == .live ? liveVersion(of: candidate) : candidate
            if !recentKeys.contains(proofTestKey(rendered)) {
                return rendered
            }
        }
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

    private static func contextualProofTestCandidates(
        userQuestion: String,
        turnDepth: CoachTurnDepth,
        trajectory: UserTrajectorySnapshot,
        preferredDimensionID: String?,
        repairFocus: String?
    ) -> [String] {
        let lower = userQuestion.lowercased()
        var candidates: [String] = []

        if turnDepth == .trustRepair {
            if containsAny(lower, ["not informative", "not helpful", "missed the point", "doesn't answer", "does not answer"]) {
                candidates.append("Answer the actual question in sentence one, then give one grounded next move.")
            }
            if containsAny(lower, ["too much writing", "too long", "less writing", "shorter", "get to the point"]) {
                candidates.append("Rewrite the answer in two sentences: the read first, the move second.")
            }
            if containsAny(lower, ["repeating yourself", "same thing again", "said that already", "already said that"]) {
                candidates.append("Advance the read: keep the prior target, but change the proof to the next observable sentence.")
            }
            if containsAny(lower, ["it's not easy", "its not easy", "not that easy", "harder than that", "easier said"]) {
                candidates.append("Make the pressure visible: run the same answer once with a timer and name where it breaks.")
            }
            if let repairFocus,
               !repairFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                candidates.append("Repair this turn first: name that \(repairFocus), then give one signal and one move.")
            }
        }

        if containsAny(lower, ["give me examples", "example of me", "examples from", "quote what", "quote me"]) {
            candidates.append("Use one verified session example, name the behavior it shows, then run that behavior once cleaner.")
        }
        if containsAny(lower, [
            "how far", "ready", "readiness", "overall", "where do i stand",
            "authoritative", "authority", "am i there"
        ]) {
            candidates.append("Run one stakes-style pressure proof: verdict first, one reason, clean stop, then compare it with a normal rep.")
        }
        if containsAny(lower, ["outcome", "cause", "caused", "landed better", "room seemed", "audience"]) {
            candidates.append("Log the outcome as a field note, then repeat one pressure rep and check the same observable target.")
        }
        if isPressureFillerQuestion(lower) {
            candidates.append(pressureFillerProofTest(from: trajectory))
        }
        if containsAny(lower, ["interview", "answer questions", "tell me about yourself"]) {
            candidates.append("Answer one interview prompt with the recommendation first, one example, then a clean stop.")
        }
        if containsAny(lower, ["leadership", "board", "executive", "update tomorrow", "status update"]) {
            candidates.append("Give the update as decision, one business reason, and the ask in under 45 seconds.")
        }
        if containsAny(lower, ["disagree", "disagreement", "conflict", "difficult conversation", "defensive"]) {
            candidates.append("Say the disagreement in sentence one, add one calm reason, then stop before reassuring.")
        }
        if containsAny(lower, ["networking", "introducing myself", "intro"]) {
            candidates.append("Run a 30-second intro: role, one memorable detail, then one handoff question.")
        }
        if containsAny(lower, ["sales", "pitch", "customer", "client concern"]) {
            candidates.append("Give the customer problem, one proof point, and the ask without adding a second example.")
        }
        if containsAny(lower, ["presentation", "flat", "energy", "emphasis", "nerves", "nervous"]) {
            candidates.append("Open the presentation answer with the point, hold one beat, then give one proof.")
        }
        if containsAny(lower, ["panic", "blank", "freeze", "barge", "interrupt", "under fire"]) {
            candidates.append("Run the same prompt under a timer and protect only sentence one from setup.")
        }
        if containsAny(lower, ["semantic", "like as a comparison", "meant it as a comparison", "prompt echo"]) {
            candidates.append("Replay the sentence and keep the word only if it adds meaning; cut the hedge if it buys time.")
        }
        if containsAny(lower, ["filler", "fillers", " um", " uh", " ah", "say like"]) {
            candidates.append("Run one answer and separate semantic words from filler words before cutting anything.")
        }
        if containsAny(lower, ["conviction", "convincing", "timid", "timidity", "weak"]) {
            candidates.append("Make one plain recommendation with no maybe/probably, then stop before explaining twice.")
        }
        if containsAny(lower, ["ramble", "overexplain", "over-explain", "too much context"]) {
            candidates.append("Run one answer with verdict, one reason, and a hard stop before the second example.")
        }

        if let pack = trajectory.latestRepEvidencePack {
            let mode = shortModeName(pack.mode)
            switch preferredDimensionID {
            case "controlled_pacing":
                if let wpm = pack.wordsPerMinute, wpm > 175 {
                    candidates.append("Repeat the latest \(mode) rep one beat slower: verdict, beat, one reason, stop.")
                } else {
                    candidates.append("Repeat the latest \(mode) rep with one silent beat after sentence one.")
                }
            case "hedge_control":
                if pack.fillerCount > 0 {
                    candidates.append("Replay the latest \(mode) rep and replace the first filler or hedge with the direct verb.")
                } else {
                    candidates.append("Replay the latest \(mode) rep and remove one softening word before the recommendation.")
                }
            case "clean_close":
                candidates.append("Replay the latest \(mode) rep and make the final sentence the ask, then stop.")
            case "verdict_first":
                candidates.append("Replay the latest \(mode) rep with the answer in sentence one before any setup.")
            case "pressure_stability":
                candidates.append("Run the latest \(mode) topic under a 60-second pressure timer and keep sentence one intact.")
            case "salience":
                candidates.append("Replay the latest \(mode) rep with one concrete detail after the verdict, then return to the ask.")
            default:
                break
            }
        }

        return unique(candidates)
    }

    private static func shortModeName(_ mode: String) -> String {
        let trimmed = mode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "practice" }
        let lower = trimmed.lowercased()
        if lower.contains("timed") { return "Timed" }
        if lower.contains("pressure") || lower.contains("sudden") { return "pressure" }
        if lower.contains("ah") { return "Ah-Counter" }
        if lower.contains("im") || lower.contains("interaction") { return "conversation" }
        if lower.contains("free") { return "free practice" }
        return trimmed
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
            return "Repeat it under a 60-second pressure timer and keep the verdict first."
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

    private static func confidence(
        coverage: Double,
        mechanics: Double,
        scores: [RubricScore],
        depth: CoachTurnDepth
    ) -> Double {
        // Thin coverage pins confidence to the floor regardless of mechanics:
        // you cannot be confident about an overall read without evidence breadth.
        // (Weak evidence → low confidence — see assessmentConfidenceMovesWithEvidenceCoverage.)
        if coverage < 0.15 {
            return 0.20
        }

        let scoreValues = scores.map(\.score)
        let weakest = scoreValues.min() ?? mechanics
        let strongest = scoreValues.max() ?? mechanics
        let spread = max(0, strongest - weakest)
        let evidenceBreadth = scoreValues.isEmpty
            ? 0
            : Double(scoreValues.filter { $0 >= 0.55 }.count) / Double(scoreValues.count)
        let depthCap: Double
        let depthAdjustment: Double
        switch depth {
        case .quickMove:
            depthCap = 0.74
            depthAdjustment = 0.04
        case .groundedRead:
            depthCap = 0.76
            depthAdjustment = 0.00
        case .trustRepair:
            depthCap = 0.70
            depthAdjustment = 0.07
        case .deepAssessment:
            depthCap = 0.82
            depthAdjustment = 0.03
        }

        let raw = coverage * 0.40 +
            mechanics * 0.30 +
            weakest * 0.15 +
            evidenceBreadth * 0.15 -
            spread * 0.04 +
            depthAdjustment
        let bounded = min(depthCap, max(0.20, raw))
        return (bounded * 100).rounded() / 100
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
        if containsAny(lower, ["repeating yourself", "same thing again", "said that already", "already said that"]) {
            return "I repeated the same coaching move instead of advancing the read"
        }
        if containsAny(lower, ["it's not easy", "its not easy", "not that easy", "easier said than done", "harder than that"]) {
            return "I made the move sound easier than it feels under pressure"
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

    private static func preferredProofTest(
        for userQuestion: String,
        turnDepth: CoachTurnDepth
    ) -> String? {
        guard turnDepth == .trustRepair else { return nil }
        let lower = userQuestion.lowercased()
        if containsAny(lower, ["markdown", "tts", "format", "**"]) {
            return "Repair the same answer in plain speech: no markdown, one specific read, one move."
        }
        if containsAny(lower, ["generic", "generic ai", "ai tips", "ai wrapper", "assistant wrapper"]) {
            return "Use one user-specific signal first, then prescribe exactly one coach move."
        }
        if containsAny(lower, ["cold", "robotic", "not human", "low eq", "not high eq"]) {
            return "Rewrite the read with one human acknowledgement and one user-specific signal."
        }
        if containsAny(lower, ["it's not easy", "its not easy", "not that easy", "harder than that", "easier said"]) {
            return "Test a smaller version in the next rep: say only the disagreement and one calm reason, then stop before defending it."
        }
        return nil
    }

    private static func preferredProofDimensionID(
        for userQuestion: String,
        scores: [RubricScore],
        turnDepth: CoachTurnDepth,
        isMemoryHandoff: Bool = false
    ) -> String? {
        if isMemoryHandoff {
            return nil
        }
        let lower = userQuestion.lowercased()
        if turnDepth == .trustRepair {
            if containsAny(lower, ["it's not easy", "its not easy", "not that easy", "harder than that", "easier said"]) {
                return "pressure_stability"
            }
            if containsAny(lower, ["repeating yourself", "same thing again", "said that already", "already said that"]) {
                return "clean_close"
            }
            if containsAny(lower, ["too much writing", "too long", "get to the point", "not informative", "not helpful", "missed the point", "answered what"]) {
                return "verdict_first"
            }
            if containsAny(lower, ["robotic", "cold", "generic", "ai tips", "ai wrapper", "tts", "markdown", "format"]) {
                return "controlled_pacing"
            }
            return "verdict_first"
        }
        if turnDepth == .deepAssessment,
           containsAny(lower, [
            "how far", "ready", "readiness", "overall", "stand overall",
            "authoritative", "authority", "board", "executive"
           ]) {
            return "pressure_stability"
        }
        if isPressureFillerQuestion(lower) {
            return "pressure_stability"
        }
        if containsAny(lower, ["slow", "pace", "rushing", "too fast", "unsure", "pause", "breath"]) {
            return "controlled_pacing"
        }
        if containsAny(lower, [
            "presentation", "flat", "energy", "emphasis", "nerves",
            "nervous", "confidence", "confident", "panic"
        ]) {
            return "controlled_pacing"
        }
        if containsAny(lower, [
            "ending", "close", "closing", "ask", "stop", "land",
            "leadership", "update tomorrow", "board", "executive",
            "overexplain", "over-explain"
        ]) {
            return "clean_close"
        }
        if containsAny(lower, ["quote what", "give me an example", "example of me"]) {
            return "salience"
        }
        if containsAny(lower, [
            "opening", "start", "first sentence", "verdict", "point first",
            "lead with", "headline", "opener", "interview", "conversation tonight", "difficult conversation",
            "disagree", "disagreement", "defensive", "evasive", "direct",
            "actually say", "quote", "said that", "real question"
        ]) {
            return "verdict_first"
        }
        if containsAny(lower, [
            "filler", "fillers", "um", "uh", "ah", "hedge", "maybe",
            "probably", "kind of", "sort of", "conviction", "convincing",
            "semantic", "comparison", "prompt made me repeat", "prompt echo",
            "timid", "timidity"
        ]) {
            return "hedge_control"
        }
        if containsAny(lower, [
            "pressure", "stakes", "timer", "under fire", "interrupt",
            "real room", "room seemed", "did the drill cause", "cause that",
            "caused", "outcome", "landed better", "this week felt harder"
        ]) {
            return "pressure_stability"
        }
        if containsAny(lower, [
            "depth", "example", "memorable", "stick", "story", "salience",
            "boring", "networking", "introducing myself", "intro", "sales",
            "pitch", "customer", "loses people", "not like me", "my phrase",
            "claim", "reason", "weak"
        ]) {
            return "salience"
        }

        // Broad distance-to-goal questions should still be governed by the
        // weakest observed dimension, especially pressure evidence. Tactical
        // turns get no forced fallback here so the sorted weakest score below
        // remains the last-resort source of truth.
        if turnDepth == .deepAssessment {
            return nil
        }
        if turnDepth == .quickMove,
           let tacticalID = weakestTacticalEvidenceDimensionID(from: scores) {
            return tacticalID
        }
        return scores.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID < $1.dimensionID
        }.first?.dimensionID
    }

    private static func isPressureFillerQuestion(_ lower: String) -> Bool {
        let pressureContext = containsAny(lower, [
            "pressure", "stakes", "timer", "timed", "under fire", "real room"
        ])
        let fillerContext = containsAny(lower, [
            "filler", "fillers", " um", " uh", " ah",
            "saying um", "saying uh", "saying ah", "say like"
        ])
        let semanticDisambiguation = containsAny(lower, [
            "semantic", "comparison", "meant it as a comparison",
            "prompt echo", "prompt made me repeat"
        ])
        return pressureContext && fillerContext && !semanticDisambiguation
    }

    private static func pressureFillerProofTest(from trajectory: UserTrajectorySnapshot) -> String {
        let fillerCount = trajectory.latestRepEvidencePack?.fillerCount
        let countPhrase: String
        if let fillerCount, fillerCount > 0 {
            let noun = fillerCount == 1 ? "filler" : "fillers"
            countPhrase = " with \(fillerCount) \(noun)"
        } else {
            countPhrase = ""
        }
        return "Repeat the latest pressure rep\(countPhrase): replace the filler urge with one silent beat before the final sentence, then finish the ask."
    }

    private static func weakestTacticalEvidenceDimensionID(from scores: [RubricScore]) -> String? {
        scores
            .filter { $0.dimensionID != "pressure_stability" && $0.score < 0.55 }
            .sorted {
                if $0.score != $1.score { return $0.score < $1.score }
                return $0.dimensionID < $1.dimensionID
            }
            .first?.dimensionID
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
