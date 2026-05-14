import Foundation

// MARK: - Next Action

/// The single unified recommendation produced after every session.
/// Represents the ONE thing the user should do next, with reasoning.
struct NextAction {
    let primary: ActionRecommendation      // The one thing to do
    let secondary: ActionRecommendation?   // Optional alternative
    let reasoning: String                  // Why this was chosen
    let confidenceLevel: BaselineConfidence // How much data backs this recommendation
}

/// A specific recommended action.
enum ActionRecommendation: Equatable {
    /// A targeted drill for a specific skill area.
    case drill(DrillRecommendationV2)
    /// Practice again in a specific mode (general improvement).
    case practiceMode(PracticeMode, reason: String)
    /// Expose to pressure — user is strong casually but hasn't been tested under pressure.
    case pressureExposure(PracticeMode, reason: String)
    /// Another rep to stabilize a recently improved skill.
    case stabilizingRep(PracticeMode, reason: String)
    /// Confidence rebuilding — user's performance dipped and needs a win.
    case confidenceRebuilding(DrillRecommendationV2)

    var displayTitle: String {
        switch self {
        case .drill(let rec): return rec.title
        case .practiceMode(let mode, _): return "\(mode.displayLabel) Practice"
        case .pressureExposure(let mode, _): return "\(mode.displayLabel) — Pressure Mode"
        case .stabilizingRep(let mode, _): return "\(mode.displayLabel) — Consolidation"
        case .confidenceRebuilding(let rec): return rec.title
        }
    }

    var displayReason: String {
        switch self {
        case .drill(let rec): return rec.reason
        case .practiceMode(_, let reason): return reason
        case .pressureExposure(_, let reason): return reason
        case .stabilizingRep(_, let reason): return reason
        case .confidenceRebuilding(let rec): return rec.reason
        }
    }

    static func == (lhs: ActionRecommendation, rhs: ActionRecommendation) -> Bool {
        lhs.displayTitle == rhs.displayTitle
    }
}

// MARK: - Persisted Last Action

/// Lightweight snapshot of the last NextAction for display on the home screen.
struct LastNextActionSnapshot: Codable {
    let title: String
    let reasoning: String
    let confidence: String
    let date: Date

    private static let key = "lastNextActionSnapshot"

    static func save(_ action: NextAction) {
        let snapshot = LastNextActionSnapshot(
            title: action.primary.displayTitle,
            reasoning: action.reasoning,
            confidence: action.confidenceLevel.label,
            date: Date()
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> LastNextActionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(LastNextActionSnapshot.self, from: data) else {
            return nil
        }
        // Only show if less than 7 days old
        guard Date().timeIntervalSince(snapshot.date) < 7 * 86400 else { return nil }
        return snapshot
    }
}

// MARK: - Input Bundle

/// All the data the decision engine considers.
struct NextActionInput {
    let fillerCount: Int
    let duration: TimeInterval
    let wordCount: Int
    let wpm: Double
    let score: Int
    let categoryRatings: [String: String]
    let mode: PracticeMode
    let pressureLevel: PressureLevel

    let baseline: CommunicationBaseline
    let pressureProfile: PressureProfile
    let trends: [SkillTrend]
    let drillHistory: [DrillHistoryStore.Entry]

    let sessionCount: Int
    let streakDays: Int
    let styleGoal: String?
}

// MARK: - Next Action Engine

/// The unified decision engine. After every session, it produces ONE strategic recommendation.
///
/// Decision priority (highest → lowest):
/// 1. Severe session issue (fillers ≥ 10, duration < 8s, WPM > 200)
/// 2. Persistent blocker (same issue for 10+ sessions)
/// 3. Pressure gap (strong casually but untested under pressure)
/// 4. Declining trend with high confidence
/// 5. New issue detected
/// 6. Improving trend (reinforcing rep)
/// 7. Stable + strong (stretch challenge)
/// 8. Default (TrendAnalyzer primary focus)
enum NextActionEngine {

    static func recommend(input: NextActionInput) -> NextAction {
        let confidence = input.baseline.overallConfidence

        // --- Priority 1: Severe session issue ---
        if let severe = checkSevereIssue(input: input) {
            return NextAction(
                primary: severe,
                secondary: fallbackDrill(input: input),
                reasoning: "This session had a significant issue that should be addressed immediately.",
                confidenceLevel: .stable // Severe issues don't need baseline confidence
            )
        }

        // --- Priority 2: Persistent blocker ---
        if confidence >= .moderate, let blocker = checkPersistentBlocker(input: input) {
            return NextAction(
                primary: blocker,
                secondary: nil,
                reasoning: "This has been a persistent pattern across many sessions — focused work here has the highest leverage.",
                confidenceLevel: confidence
            )
        }

        // --- Priority 3: Pressure gap ---
        if confidence >= .moderate, let pressureAction = checkPressureGap(input: input) {
            return NextAction(
                primary: pressureAction,
                secondary: standardDrill(input: input),
                reasoning: "Your casual performance is strong, but pressure situations reveal a gap worth closing.",
                confidenceLevel: confidence
            )
        }

        // --- Priority 4: Declining trend ---
        if let declining = checkDecliningTrend(input: input) {
            return NextAction(
                primary: declining,
                secondary: nil,
                reasoning: ConfidencePhrasing.frame("A skill that was strong is slipping — a focused drill can reverse this before it becomes a pattern.", confidence: confidence),
                confidenceLevel: confidence
            )
        }

        // --- Priority 5: New issue ---
        if let newIssue = checkNewIssue(input: input) {
            return NextAction(
                primary: newIssue,
                secondary: nil,
                reasoning: "This issue just appeared — catching it early prevents it from becoming a habit.",
                confidenceLevel: confidence
            )
        }

        // --- Priority 6: Improving trend ---
        if let reinforcing = checkImprovingTrend(input: input) {
            return NextAction(
                primary: reinforcing,
                secondary: stretchChallenge(input: input),
                reasoning: ConfidencePhrasing.frame("You're making progress — one more rep can lock it in.", confidence: confidence),
                confidenceLevel: confidence
            )
        }

        // --- Priority 7: Stable + strong ---
        if input.score >= 7, let stretch = stretchChallenge(input: input) {
            return NextAction(
                primary: stretch,
                secondary: standardDrill(input: input),
                reasoning: "Solid performance — time to push your edge.",
                confidenceLevel: confidence
            )
        }

        // --- Priority 8: Default ---
        let defaultDrill = standardDrill(input: input)
        return NextAction(
            primary: defaultDrill ?? .practiceMode(.timed, reason: "Keep building your baseline with another practice session."),
            secondary: nil,
            reasoning: "Continued practice builds your baseline and reveals where to focus next.",
            confidenceLevel: confidence
        )
    }

    // MARK: - Priority Checks

    /// Priority 1: Severe session issues that need immediate correction.
    private static func checkSevereIssue(input: NextActionInput) -> ActionRecommendation? {
        if input.fillerCount >= 10 {
            if let drill = selectDrill(for: .fillerReduction, input: input) {
                return .drill(drill)
            }
        }
        if input.duration < 8 && input.wordCount > 0 {
            if let drill = selectDrill(for: .answerDevelopment, input: input) {
                return .drill(drill)
            }
        }
        if input.wpm > 200 {
            if let drill = selectDrill(for: .paceControl, input: input) {
                return .drill(drill)
            }
        }
        return nil
    }

    /// Priority 2: Issues that have persisted for 10+ sessions.
    private static func checkPersistentBlocker(input: NextActionInput) -> ActionRecommendation? {
        let blockers = input.baseline.persistentBlockers
        guard !blockers.isEmpty else { return nil }

        // Map blocker names back to skill areas
        // Keys must match exactly what BaselineEngine.identifyBlockers() produces
        let blockerToSkill: [String: SkillArea] = [
            "Filler words": .fillerReduction,
            "Pace control": .paceControl,
            "Opening strength": .openingStrength,
            "Structure": .structure,
            "Hedging language": .confidence,
        ]

        for blocker in blockers {
            if let skillArea = blockerToSkill[blocker],
               let drill = selectDrill(for: skillArea, input: input) {
                // For persistent blockers, suggest a deeper approach
                return .confidenceRebuilding(drill)
            }
        }
        return nil
    }

    /// Priority 3: Strong casually but untested or weak under pressure.
    private static func checkPressureGap(input: NextActionInput) -> ActionRecommendation? {
        guard let resilience = input.pressureProfile.pressureResilience,
              resilience < 0.6 else { return nil }

        // Only suggest pressure exposure if user has enough casual data and is doing well casually
        guard input.baseline.qualifyingSessionCount >= 8,
              input.baseline.averageScore.isReliable,
              input.baseline.averageScore.value >= 6.0 else { return nil }

        // Don't suggest pressure exposure if the user just did a high-pressure session
        guard input.pressureLevel < .elevated else { return nil }

        let mode: PracticeMode = input.mode == .suddenDeath ? .timed : .suddenDeath
        return .pressureExposure(mode, reason: "Your casual delivery is solid — testing it under pressure will reveal your next growth edge.")
    }

    /// Priority 4: A skill that was strong is now declining.
    private static func checkDecliningTrend(input: NextActionInput) -> ActionRecommendation? {
        let declining = input.trends.filter { $0.direction == .declining }
        guard !declining.isEmpty else { return nil }

        // Pick the most important declining trend
        let priorityOrder: [SkillArea] = [
            .fillerReduction, .paceControl, .structure,
            .openingStrength, .closingStrength, .answerDevelopment,
            .confidence, .conciseSpeaking
        ]

        for area in priorityOrder {
            if declining.contains(where: { $0.skillArea == area }) {
                if let drill = selectDrill(for: area, input: input) {
                    return .drill(drill)
                }
            }
        }
        return nil
    }

    /// Priority 5: A new issue just appeared.
    private static func checkNewIssue(input: NextActionInput) -> ActionRecommendation? {
        let newIssues = input.trends.filter { $0.direction == .newIssue }
        guard !newIssues.isEmpty else { return nil }

        if let first = newIssues.first, let drill = selectDrill(for: first.skillArea, input: input) {
            return .drill(drill)
        }
        return nil
    }

    /// Priority 6: A skill is improving — reinforce with a stabilizing rep.
    private static func checkImprovingTrend(input: NextActionInput) -> ActionRecommendation? {
        let improving = input.trends.filter { $0.direction == .improving }
        guard !improving.isEmpty else { return nil }

        // If the improving area matches a recent drill, suggest another rep
        if let recentDrillArea = input.drillHistory.first?.skillArea,
           improving.contains(where: { $0.skillArea == recentDrillArea }) {
            return .stabilizingRep(input.mode, reason: "Your \(recentDrillArea.displayName.lowercased()) is improving — another rep will solidify the gains.")
        }

        // Otherwise suggest a drill for the improving area
        if let first = improving.first, let drill = selectDrill(for: first.skillArea, input: input) {
            return .drill(drill)
        }
        return nil
    }

    // MARK: - Helpers

    /// Select a drill from the catalog for a given skill area.
    private static func selectDrill(for area: SkillArea, input: NextActionInput) -> DrillRecommendationV2? {
        return DrillEngineV2.recommend(
            fillerCount: input.fillerCount,
            duration: input.duration,
            wordCount: input.wordCount,
            score: input.score,
            feedbackCategories: input.categoryRatings.map { (dimension: $0.key, rating: $0.value) },
            targetArea: area
        )
    }

    /// A standard drill recommendation using DrillEngineV2.
    private static func standardDrill(input: NextActionInput) -> ActionRecommendation? {
        let rec = DrillEngineV2.recommend(
            fillerCount: input.fillerCount,
            duration: input.duration,
            wordCount: input.wordCount,
            score: input.score,
            feedbackCategories: input.categoryRatings.map { (dimension: $0.key, rating: $0.value) }
        )
        return .drill(rec)
    }

    /// A fallback drill recommendation when the primary action is severe.
    private static func fallbackDrill(input: NextActionInput) -> ActionRecommendation? {
        if input.score >= 5 {
            return .practiceMode(.timed, reason: "Or just practice again — the habit itself is valuable.")
        }
        return nil
    }

    /// A stretch challenge for users who are performing well.
    private static func stretchChallenge(input: NextActionInput) -> ActionRecommendation? {
        // If they haven't tried sudden death much, suggest it
        let recentSuddenDeath = input.drillHistory.filter { $0.skillArea == .fillerReduction }.count
        if recentSuddenDeath < 3 && input.fillerCount <= 2 {
            return .pressureExposure(.suddenDeath, reason: "Your filler control is strong — test it under sudden death pressure.")
        }

        // If the session was in timed mode, suggest IM mode
        if input.mode == .timed && input.score >= 7 {
            return .practiceMode(.imConversation, reason: "You're performing well in timed mode — try an IM conversation for a different challenge.")
        }

        // Otherwise suggest pressure mode
        if input.pressureLevel < .elevated {
            return .pressureExposure(input.mode, reason: "Turn on pressure mode for your next session to push your edge.")
        }

        return nil
    }
}


