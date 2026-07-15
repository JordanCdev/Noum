import Foundation

/// What the coach recommends after a turn — mirrors "reinforce, vary, or
/// replace" (VISION coach-parity stage 4, Adaptation) applied inside a
/// single roleplay run instead of across sessions.
enum RoleplayRetryMode: String, Codable {
    /// Weak response at the floor of the ladder — repeat the SAME objection
    /// rather than escalate; the user hasn't cleared the easy version yet.
    case sameObjectionSlower
    /// Middling response — stay at this pressure level, but move to a fresh
    /// objection so the user isn't just re-answering a question they've now
    /// rehearsed.
    case sameLevelNewObjection
    /// Strong response with room to climb the ladder.
    case levelUp
    /// Weak response above the floor — drop a rung to rebuild the base
    /// skill before pushing harder.
    case levelDown
}

/// The per-turn record required by the roadmap's data contract. `RoleplayStore`
/// persists these; `RoleplayEngine` produces them.
struct RoleplayTurnResult: Codable, Equatable {
    var scenarioId: String
    var pressureLevel: RoleplayPressureLevel
    var objectionType: RoleplayObjectionType
    var objectionId: String
    var responseQuality: Double
    var recommendedRetryMode: RoleplayRetryMode
}

/// Pure turn logic for the pressure-ladder roleplay: which objection comes
/// next, how a spoken/typed response scores against the scenario's rubric,
/// and what the engine recommends for the following turn. No I/O, no
/// networking, no singletons — everything here is a static function over
/// plain values so it can be exhaustively unit tested.
///
/// Persona dialogue is authored per pressure rung in `RoleplayCatalog`
/// rather than generated live: `AINPCChatService` (the existing NPC-chat
/// service) was evaluated for reuse, but its public API is hard-coupled to
/// `IMConversationSetup` (a fixed 4-case IM-Mode scenario/tone domain) —
/// routing new personas through it would mean editing that shared file or
/// misrepresenting the persona as an IM Mode scenario it isn't. Curated,
/// in-voice objection text keeps the ladder deterministic, offline-capable,
/// and directly testable.
enum RoleplayEngine {
    // MARK: Objection selection

    /// Picks the next objection at `pressureLevel` for `scenario`, excluding
    /// any ID already in `usedIDs` when a fresh one is available. Falls back
    /// to reusing the level's pool only once every objection at that level
    /// has already been used — this is what keeps the same drill from
    /// recurring across unrelated roleplays: `usedIDs` is tracked
    /// account-wide (see `RoleplayStore.usedObjectionIDs`), not reset per
    /// session, and every objection ID is globally unique across the whole
    /// catalog.
    static func nextObjection(
        for scenario: RoleplayScenario,
        pressureLevel: RoleplayPressureLevel,
        excluding usedIDs: Set<String>
    ) -> RoleplayObjection? {
        let pool = scenario.objections(at: pressureLevel)
        guard !pool.isEmpty else { return nil }
        let fresh = pool.filter { !usedIDs.contains($0.id) }
        return (fresh.isEmpty ? pool : fresh).first
    }

    /// Resolves the objection promised by the retry recommendation. A floor-
    /// level rebuild must preserve the exact objection the user just heard;
    /// every other mode follows the normal fresh-selection contract at the
    /// already-resolved next pressure level.
    static func nextObjection(
        after retryMode: RoleplayRetryMode,
        currentObjection: RoleplayObjection,
        for scenario: RoleplayScenario,
        pressureLevel: RoleplayPressureLevel,
        excluding usedIDs: Set<String>
    ) -> RoleplayObjection? {
        if retryMode == .sameObjectionSlower {
            return currentObjection
        }
        return nextObjection(
            for: scenario,
            pressureLevel: pressureLevel,
            excluding: usedIDs
        )
    }

    // MARK: Response scoring

    // Roleplay turns do not retain finalized duration, so they cannot apply
    // the shared quantity-qualified fillers-per-minute contract honestly.
    // Keep filler evidence out of pressure-ladder scoring until that durable
    // measurement contract exists.
    struct ResponseSignals: Equatable {
        var wordCount: Int
        var hedgeCount: Int
        var hasEarlyDirectAnswer: Bool
        var evidenceMarkerCount: Int
        var acknowledgementMarkerCount: Int
        var ownershipMarkerCount: Int
        var actionMarkerCount: Int
        var questionSignalCount: Int
    }

    static let hedgePhrases: [String] = ["i think", "i guess", "maybe", "not sure", "kind of", "sort of", "probably"]
    static let evidenceMarkers: [String] = ["because", "for example", "specifically", "last quarter", "last month", "the data", "%"]
    static let acknowledgementMarkers: [String] = [
        "i hear", "i understand", "it sounds like", "what i'm hearing",
        "what i hear", "i can see", "that makes sense", "you're saying",
        "you are saying"
    ]
    static let ownershipMarkers: [String] = [
        "i was wrong", "i should have", "my part", "i interrupted",
        "i dismissed", "i'm sorry", "i am sorry", "i take responsibility"
    ]
    static let actionMarkers: [String] = [
        "next time", "from now on", "i will", "i'll", "could you",
        "can we", "i propose", "the next step", "instead", "going forward"
    ]
    static let questionStarters: [String] = [
        "what", "how", "why", "when", "where", "who", "which",
        "could", "would", "can", "do", "did", "is", "are"
    ]

    static func analyze(_ response: String) -> ResponseSignals {
        let normalized = response.lowercased()
        let words = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !words.isEmpty else {
            return ResponseSignals(
                wordCount: 0,
                hedgeCount: 0,
                hasEarlyDirectAnswer: false,
                evidenceMarkerCount: 0,
                acknowledgementMarkerCount: 0,
                ownershipMarkerCount: 0,
                actionMarkerCount: 0,
                questionSignalCount: 0
            )
        }

        let hedgeCount = hedgePhrases.reduce(into: 0) { count, phrase in
            if normalized.contains(phrase) { count += 1 }
        }

        let leadingWords = words.prefix(6).joined(separator: " ")
        let opensWithHedge = hedgePhrases.contains { leadingWords.contains($0) }
        let hasEarlyDirectAnswer = !opensWithHedge && words.count >= 3

        let evidenceMarkerCount = evidenceMarkers.reduce(into: 0) { count, marker in
            if normalized.contains(marker) { count += 1 }
        }
        let acknowledgementMarkerCount = acknowledgementMarkers.reduce(into: 0) { count, marker in
            if normalized.contains(marker) { count += 1 }
        }
        let ownershipMarkerCount = ownershipMarkers.reduce(into: 0) { count, marker in
            if normalized.contains(marker) { count += 1 }
        }
        let actionMarkerCount = actionMarkers.reduce(into: 0) { count, marker in
            if normalized.contains(marker) { count += 1 }
        }
        let punctuationQuestions = response.filter { $0 == "?" }.count
        let starterQuestions = questionStarters.reduce(into: 0) { count, starter in
            let padded = " " + normalized + " "
            if normalized.hasPrefix(starter + " ") || padded.contains(" \(starter) ") {
                count += 1
            }
        }

        return ResponseSignals(
            wordCount: words.count,
            hedgeCount: hedgeCount,
            hasEarlyDirectAnswer: hasEarlyDirectAnswer,
            evidenceMarkerCount: evidenceMarkerCount,
            acknowledgementMarkerCount: acknowledgementMarkerCount,
            ownershipMarkerCount: ownershipMarkerCount,
            actionMarkerCount: actionMarkerCount,
            questionSignalCount: max(punctuationQuestions, starterQuestions)
        )
    }

    struct AxisScores: Equatable {
        var directness: Double
        var evidence: Double
        var composure: Double
        var listening: Double
        var ownership: Double
        var constructiveness: Double
        var inquiry: Double
    }

    static func axisScores(for signals: ResponseSignals) -> AxisScores {
        guard signals.wordCount > 0 else {
            return AxisScores(
                directness: 0,
                evidence: 0,
                composure: 0,
                listening: 0,
                ownership: 0,
                constructiveness: 0,
                inquiry: 0
            )
        }

        var directness = signals.hasEarlyDirectAnswer ? 0.75 : 0.35
        if signals.wordCount < 5 { directness -= 0.25 }
        directness = clamp(directness)

        var evidence = Double(signals.evidenceMarkerCount) * 0.3
        if signals.wordCount >= 10 { evidence += 0.2 }
        evidence = clamp(evidence)

        var composure = 1.0
        composure -= min(0.5, Double(signals.hedgeCount) * 0.2)
        composure = clamp(composure)

        var listening = Double(signals.acknowledgementMarkerCount) * 0.4
        listening += min(0.35, Double(signals.questionSignalCount) * 0.2)
        if signals.wordCount >= 8 { listening += 0.15 }
        listening = clamp(listening)

        var ownership = Double(signals.ownershipMarkerCount) * 0.4
        if signals.wordCount >= 8 { ownership += 0.15 }
        ownership = clamp(ownership)

        var constructiveness = Double(signals.actionMarkerCount) * 0.35
        if signals.hasEarlyDirectAnswer { constructiveness += 0.2 }
        if signals.wordCount >= 10 { constructiveness += 0.15 }
        constructiveness = clamp(constructiveness)

        var inquiry = Double(signals.questionSignalCount) * 0.35
        if signals.acknowledgementMarkerCount > 0 { inquiry += 0.2 }
        inquiry = clamp(inquiry)

        return AxisScores(
            directness: directness,
            evidence: evidence,
            composure: composure,
            listening: listening,
            ownership: ownership,
            constructiveness: constructiveness,
            inquiry: inquiry
        )
    }

    private static func clamp(_ value: Double, _ lower: Double = 0, _ upper: Double = 1) -> Double {
        min(upper, max(lower, value))
    }

    private static func axisValue(for label: String, in axes: AxisScores) -> Double? {
        switch label {
        case "Directness": return axes.directness
        case "Evidence": return axes.evidence
        case "Composure": return axes.composure
        case "Listening": return axes.listening
        case "Ownership": return axes.ownership
        case "Constructiveness": return axes.constructiveness
        case "Inquiry": return axes.inquiry
        default: return nil
        }
    }

    // MARK: Structured first value

    /// Projects a written rehearsal onto content/structure dimensions only.
    /// This path deliberately does not call `axisScores(for:)`: that spoken
    /// roleplay projection includes filler ratio and composure, neither of
    /// which can be inferred honestly from typed text.
    ///
    /// The result carries no numeric score and the response is never retained.
    /// Callers may persist only `result.metadata` through `FirstValueReceipt`.
    static func evaluateStructuredFirstValue(
        response: String,
        prompt: StructuredFirstValuePrompt
    ) -> StructuredFirstValueResult? {
        let signals = analyze(response)
        guard signals.wordCount >= 8 else { return nil }
        guard prompt.rubric.count >= 2 else { return nil }

        let values = structuredAxisValues(for: signals)
        let ranked = prompt.rubric.enumerated().map { index, axis in
            (index: index, axis: axis, value: values[axis] ?? 0)
        }
        // Preserve authored rubric order on ties so the result is deterministic
        // across launches and platforms.
        let strength = ranked.max {
            if $0.value == $1.value { return $0.index > $1.index }
            return $0.value < $1.value
        }!
        let next = ranked.min {
            if $0.value == $1.value { return $0.index < $1.index }
            return $0.value < $1.value
        }!

        return StructuredFirstValueResult(
            promptID: prompt.id,
            wordCount: signals.wordCount,
            strengthAxis: strength.axis,
            nextAxis: next.axis,
            strength: structuredStrengthCopy(for: strength.axis),
            nextMove: structuredNextMoveCopy(for: next.axis)
        )
    }

    private static func structuredAxisValues(
        for signals: ResponseSignals
    ) -> [StructuredFirstValueAxis: Double] {
        var directness = signals.hasEarlyDirectAnswer ? 0.75 : 0.35
        if signals.wordCount < 10 { directness -= 0.10 }

        var evidence = Double(signals.evidenceMarkerCount) * 0.30
        if signals.wordCount >= 10 { evidence += 0.20 }

        var listening = Double(signals.acknowledgementMarkerCount) * 0.40
        listening += min(0.35, Double(signals.questionSignalCount) * 0.20)
        if signals.wordCount >= 8 { listening += 0.15 }

        var ownership = Double(signals.ownershipMarkerCount) * 0.40
        if signals.wordCount >= 8 { ownership += 0.15 }

        var constructiveness = Double(signals.actionMarkerCount) * 0.35
        if signals.hasEarlyDirectAnswer { constructiveness += 0.20 }
        if signals.wordCount >= 10 { constructiveness += 0.15 }

        var inquiry = Double(signals.questionSignalCount) * 0.35
        if signals.acknowledgementMarkerCount > 0 { inquiry += 0.20 }

        return [
            .directness: clamp(directness),
            .evidence: clamp(evidence),
            .listening: clamp(listening),
            .ownership: clamp(ownership),
            .constructiveness: clamp(constructiveness),
            .inquiry: clamp(inquiry),
        ]
    }

    private static func structuredStrengthCopy(for axis: StructuredFirstValueAxis) -> String {
        switch axis {
        case .directness:
            return "Your main point appears early, so the response is easy to follow."
        case .evidence:
            return "You support the point with a reason or concrete detail."
        case .listening:
            return "You acknowledge what the other person shared before moving forward."
        case .ownership:
            return "You name your part clearly instead of avoiding the decision."
        case .constructiveness:
            return "You turn the response toward a useful next step."
        case .inquiry:
            return "Your question creates room for the other person to respond."
        }
    }

    private static func structuredNextMoveCopy(for axis: StructuredFirstValueAxis) -> String {
        switch axis {
        case .directness:
            return "Lead with one clear answer before adding context."
        case .evidence:
            return "Add one specific fact, example, or reason that supports the point."
        case .listening:
            return "Name what you heard before offering your response."
        case .ownership:
            return "State your part and what you would change next time."
        case .constructiveness:
            return "Finish with one practical action or next step."
        case .inquiry:
            return "End with one genuine question that invites a useful answer."
        }
    }

    /// Weighted score in 0...1 over `rubric`'s criteria. A rubric criterion
    /// whose label doesn't match a known axis contributes a neutral 0.5
    /// rather than crashing — keeps this robust to future rubric axes
    /// without silently mis-scoring.
    static func score(response: String, rubric: [RoleplayRubricCriterion]) -> Double {
        let axes = axisScores(for: analyze(response))
        let totalWeight = rubric.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }
        let weighted = rubric.reduce(0.0) { partial, criterion in
            partial + (axisValue(for: criterion.label, in: axes) ?? 0.5) * criterion.weight
        }
        return clamp(weighted / totalWeight)
    }

    // MARK: Feedback

    /// One strength, one gap — never more, matching the roadmap's
    /// "one strength, one gap, one next attempt" contract. Never punishes an
    /// empty/near-empty response with a shaming line; it names the miss
    /// plainly and moves on.
    static func feedback(response: String, rubric: [RoleplayRubricCriterion]) -> (strength: String, gap: String) {
        guard !rubric.isEmpty else {
            return ("You stayed in the exchange.", "Give a clearer answer next time.")
        }
        let signals = analyze(response)
        guard signals.wordCount > 0 else {
            return (
                "You stayed in the conversation.",
                "No answer landed that turn — try responding to the objection directly next attempt."
            )
        }

        let axes = axisScores(for: signals)
        let scored = rubric.map { criterion -> (RoleplayRubricCriterion, Double) in
            (criterion, axisValue(for: criterion.label, in: axes) ?? 0.5)
        }
        guard let strongest = scored.max(by: { $0.1 < $1.1 }),
              let weakest = scored.min(by: { $0.1 < $1.1 }) else {
            return ("You stayed in the exchange.", "Give a clearer answer next time.")
        }

        let strength = strongest.1 >= 0.6
            ? strongest.0.strongSignalHint
            : "You stayed in the exchange without shutting down."
        let gap = weakest.0.lowSignalHint
        return (strength, gap)
    }

    // MARK: Retry mode

    static let strongResponseThreshold = 0.75
    static let adequateResponseThreshold = 0.45

    /// What the engine recommends for the NEXT turn given this turn's
    /// `quality` and the `currentLevel`. Mirrors "reinforce, vary, or
    /// replace" rather than a flat pass/fail: a strong response climbs the
    /// ladder, a weak one at the floor repeats (not punished by dropping
    /// further), a weak one above the floor steps back down.
    static func retryMode(afterQuality quality: Double, currentLevel: RoleplayPressureLevel) -> RoleplayRetryMode {
        if quality >= strongResponseThreshold {
            return currentLevel.next != nil ? .levelUp : .sameLevelNewObjection
        }
        if quality >= adequateResponseThreshold {
            return .sameLevelNewObjection
        }
        return currentLevel == .easy ? .sameObjectionSlower : .levelDown
    }

    /// Applies a `RoleplayRetryMode` to `currentLevel`, producing the
    /// pressure level the next turn should run at.
    static func nextLevel(after retryMode: RoleplayRetryMode, currentLevel: RoleplayPressureLevel) -> RoleplayPressureLevel {
        switch retryMode {
        case .levelUp:
            return currentLevel.next ?? currentLevel
        case .levelDown:
            return currentLevel.previous ?? currentLevel
        case .sameObjectionSlower, .sameLevelNewObjection:
            return currentLevel
        }
    }

    // MARK: Turn composition

    /// Composes a full `RoleplayTurnResult` for one turn — the shape the
    /// data contract requires, ready for `RoleplayStore` to persist.
    static func evaluateTurn(
        scenario: RoleplayScenario,
        objection: RoleplayObjection,
        response: String
    ) -> RoleplayTurnResult {
        let quality = score(response: response, rubric: scenario.rubric)
        let retry = retryMode(afterQuality: quality, currentLevel: objection.pressureLevel)
        return RoleplayTurnResult(
            scenarioId: scenario.scenarioId,
            pressureLevel: objection.pressureLevel,
            objectionType: objection.type,
            objectionId: objection.id,
            responseQuality: quality,
            recommendedRetryMode: retry
        )
    }
}
