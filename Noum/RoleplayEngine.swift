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

    // MARK: Response scoring

    struct ResponseSignals: Equatable {
        var wordCount: Int
        var fillerRatio: Double
        var hedgeCount: Int
        var hasEarlyDirectAnswer: Bool
        var evidenceMarkerCount: Int
    }

    static let fillerWords: Set<String> = ["um", "uh", "like", "basically", "actually", "literally", "sort", "kind"]
    static let hedgePhrases: [String] = ["i think", "i guess", "maybe", "not sure", "kind of", "sort of", "probably"]
    static let evidenceMarkers: [String] = ["because", "for example", "specifically", "last quarter", "last month", "the data", "%"]

    static func analyze(_ response: String) -> ResponseSignals {
        let normalized = response.lowercased()
        let words = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !words.isEmpty else {
            return ResponseSignals(wordCount: 0, fillerRatio: 0, hedgeCount: 0, hasEarlyDirectAnswer: false, evidenceMarkerCount: 0)
        }

        let fillerCount = words.filter { fillerWords.contains($0) }.count
        let fillerRatio = Double(fillerCount) / Double(words.count)

        let hedgeCount = hedgePhrases.reduce(into: 0) { count, phrase in
            if normalized.contains(phrase) { count += 1 }
        }

        let leadingWords = words.prefix(6).joined(separator: " ")
        let opensWithHedge = hedgePhrases.contains { leadingWords.contains($0) }
        let hasEarlyDirectAnswer = !opensWithHedge && words.count >= 3

        let evidenceMarkerCount = evidenceMarkers.reduce(into: 0) { count, marker in
            if normalized.contains(marker) { count += 1 }
        }

        return ResponseSignals(
            wordCount: words.count,
            fillerRatio: fillerRatio,
            hedgeCount: hedgeCount,
            hasEarlyDirectAnswer: hasEarlyDirectAnswer,
            evidenceMarkerCount: evidenceMarkerCount
        )
    }

    struct AxisScores: Equatable {
        var directness: Double
        var evidence: Double
        var composure: Double
    }

    static func axisScores(for signals: ResponseSignals) -> AxisScores {
        guard signals.wordCount > 0 else {
            return AxisScores(directness: 0, evidence: 0, composure: 0)
        }

        var directness = signals.hasEarlyDirectAnswer ? 0.75 : 0.35
        if signals.wordCount < 5 { directness -= 0.25 }
        directness -= min(0.3, signals.fillerRatio * 2)
        directness = clamp(directness)

        var evidence = Double(signals.evidenceMarkerCount) * 0.3
        if signals.wordCount >= 10 { evidence += 0.2 }
        evidence = clamp(evidence)

        var composure = 1.0
        composure -= min(0.5, Double(signals.hedgeCount) * 0.2)
        composure -= min(0.3, signals.fillerRatio * 1.5)
        composure = clamp(composure)

        return AxisScores(directness: directness, evidence: evidence, composure: composure)
    }

    private static func clamp(_ value: Double, _ lower: Double = 0, _ upper: Double = 1) -> Double {
        min(upper, max(lower, value))
    }

    private static func axisValue(for label: String, in axes: AxisScores) -> Double? {
        switch label {
        case "Directness": return axes.directness
        case "Evidence": return axes.evidence
        case "Composure": return axes.composure
        default: return nil
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
