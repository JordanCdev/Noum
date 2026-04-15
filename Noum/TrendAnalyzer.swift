import Foundation

// MARK: - Skill Snapshot

/// A snapshot of skill-relevant metrics from a single session.
/// One is recorded per session and stored in the trend store.
struct SkillSnapshot: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let date: Date
    let fillerCount: Int
    let duration: TimeInterval
    let wordCount: Int
    let wpm: Double
    let score: Int
    let categoryRatings: [String: String]   // dimension name → FeedbackRating.rawValue
    let drillCompleted: CompletedDrillRef?

    struct CompletedDrillRef: Codable {
        let variationId: String
        let skillArea: SkillArea
        let succeeded: Bool
    }

    init(
        sessionId: UUID,
        date: Date = Date(),
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        wpm: Double,
        score: Int,
        categoryRatings: [String: String] = [:],
        drillCompleted: CompletedDrillRef? = nil
    ) {
        self.id = UUID()
        self.sessionId = sessionId
        self.date = date
        self.fillerCount = fillerCount
        self.duration = duration
        self.wordCount = wordCount
        self.wpm = wpm
        self.score = score
        self.categoryRatings = categoryRatings
        self.drillCompleted = drillCompleted
    }
}

// MARK: - Skill Trend Store

/// Persists skill snapshots across sessions for trend analysis.
class SkillTrendStore: ObservableObject {
    static let shared = SkillTrendStore()

    @Published var snapshots: [SkillSnapshot] = []

    private let storageKey = "skillTrendSnapshots"

    private init() {
        load()
    }

    func record(_ snapshot: SkillSnapshot) {
        snapshots.insert(snapshot, at: 0)
        if snapshots.count > 30 { snapshots = Array(snapshots.prefix(30)) }
        save()
    }

    /// Build a snapshot from raw session data and record it.
    func recordFromSession(
        sessionId: UUID,
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        score: Int,
        categoryRatings: [String: String] = [:],
        drillCompleted: SkillSnapshot.CompletedDrillRef? = nil
    ) {
        let wpm = duration > 0 ? Double(wordCount) / duration * 60.0 : 0
        let snapshot = SkillSnapshot(
            sessionId: sessionId,
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            wpm: wpm,
            score: score,
            categoryRatings: categoryRatings,
            drillCompleted: drillCompleted
        )
        record(snapshot)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SkillSnapshot].self, from: data) else { return }
        snapshots = decoded
    }
}

// MARK: - Trend Direction & Level

enum TrendDirection: String, Codable {
    case improving
    case stable
    case declining
    case newIssue       // Wasn't a problem before, now it is
    case resolved       // Was a problem, no longer is
}

enum TrendConfidence: String, Codable {
    case low            // <3 sessions of data
    case medium         // 3-7 sessions
    case high           // 8+ sessions
}

enum SkillLevel: String, Codable, Comparable {
    case weak
    case developing
    case solid
    case strong

    static func < (lhs: SkillLevel, rhs: SkillLevel) -> Bool {
        let order: [SkillLevel] = [.weak, .developing, .solid, .strong]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - Skill Trend

/// Describes the trend of a single skill area across recent sessions.
struct SkillTrend: Identifiable {
    let id: String
    let skillArea: SkillArea
    let direction: TrendDirection
    let confidence: TrendConfidence
    let windowSize: Int
    let currentLevel: SkillLevel
    let recentDelta: String?            // e.g., "3 fewer fillers than 5 sessions ago"

    init(
        skillArea: SkillArea,
        direction: TrendDirection,
        confidence: TrendConfidence,
        windowSize: Int,
        currentLevel: SkillLevel,
        recentDelta: String? = nil
    ) {
        self.id = skillArea.rawValue
        self.skillArea = skillArea
        self.direction = direction
        self.confidence = confidence
        self.windowSize = windowSize
        self.currentLevel = currentLevel
        self.recentDelta = recentDelta
    }
}

// MARK: - Trend Analyzer

/// Analyzes skill trends across recent sessions and picks the highest-leverage focus area.
enum TrendAnalyzer {

    /// Analyze all skill areas across recent snapshots.
    static func analyze(snapshots: [SkillSnapshot]) -> [SkillTrend] {
        guard !snapshots.isEmpty else { return [] }

        var trends: [SkillTrend] = []

        trends.append(analyzeFillers(snapshots))
        trends.append(analyzePace(snapshots))
        trends.append(analyzeCategory("Opening", skillArea: .openingStrength, snapshots: snapshots))
        trends.append(analyzeCategory("Close", skillArea: .closingStrength, snapshots: snapshots))
        trends.append(analyzeCategory("Structure", skillArea: .structure, snapshots: snapshots))
        trends.append(analyzeCategory("Depth", skillArea: .answerDevelopment, snapshots: snapshots))
        trends.append(analyzeCategory("Clarity", skillArea: .conciseSpeaking, snapshots: snapshots))
        trends.append(analyzeDuration(snapshots))

        return trends
    }

    /// Find the single highest-leverage focus area for the next drill.
    static func primaryFocus(
        trends: [SkillTrend],
        currentSessionSnapshot: SkillSnapshot?,
        recentDrills: [DrillHistoryStore.Entry]
    ) -> SkillArea {
        // Count how many consecutive sessions the same skill was the focus
        let recentFocusAreas = recentDrills.prefix(4).map(\.skillArea)
        let staleFocusArea: SkillArea? = {
            guard recentFocusAreas.count >= 4 else { return nil }
            let first = recentFocusAreas.first!
            return recentFocusAreas.allSatisfy({ $0 == first }) ? first : nil
        }()

        // Priority scoring
        struct ScoredArea {
            let skillArea: SkillArea
            let priority: Int
        }

        var scored: [ScoredArea] = []

        for trend in trends {
            var priority = 0

            // Declining skill with high confidence — urgent
            if trend.direction == .declining && trend.confidence == .high {
                priority = 100
            }
            // Weak and stable — persistent problem, high leverage
            else if trend.currentLevel == .weak && trend.direction == .stable {
                priority = 90
            }
            // New issue — just appeared
            else if trend.direction == .newIssue {
                priority = 80
            }
            // Weak but improving — keep the momentum
            else if trend.currentLevel == .weak && trend.direction == .improving {
                priority = 70
            }
            // Developing — not weak but not solid
            else if trend.currentLevel == .developing {
                priority = 50
            }
            // Solid — low priority
            else if trend.currentLevel == .solid {
                priority = 20
            }
            // Strong — skip
            else if trend.currentLevel == .strong {
                priority = 0
            }
            // Default
            else {
                priority = 40
            }

            // Penalize stale focus
            if trend.skillArea == staleFocusArea && trend.currentLevel >= .developing {
                priority = max(priority - 50, 0)
            }

            scored.append(ScoredArea(skillArea: trend.skillArea, priority: priority))
        }

        // Fall back to the current session's weakest signal if no trend data is strong
        if let best = scored.max(by: { $0.priority < $1.priority }), best.priority > 0 {
            return best.skillArea
        }

        // Final fallback: use current session metrics
        if let snapshot = currentSessionSnapshot {
            if snapshot.fillerCount >= 3 { return .fillerReduction }
            if snapshot.wpm > 160 { return .paceControl }
            if snapshot.duration < 15 { return .answerDevelopment }
        }

        return .structure
    }

    /// Generate a trend context string for the drill recommendation.
    static func trendContext(for skillArea: SkillArea, trends: [SkillTrend]) -> String? {
        guard let trend = trends.first(where: { $0.skillArea == skillArea }) else { return nil }

        switch trend.direction {
        case .newIssue:
            return "This is new — your \(skillArea.displayName.lowercased()) hasn't been a problem before, but it slipped this session."
        case .declining:
            return "Your \(skillArea.displayName.lowercased()) has been slipping over recent sessions. Worth focused attention."
        case .stable where trend.currentLevel == .weak:
            return "Your \(skillArea.displayName.lowercased()) has been inconsistent across recent sessions. This is your biggest opportunity."
        case .improving where trend.currentLevel == .weak:
            if let delta = trend.recentDelta {
                return "\(delta) One more push and this stops being an issue."
            }
            return "Your \(skillArea.displayName.lowercased()) is heading in the right direction. Keep the momentum going."
        case .improving:
            return "Your \(skillArea.displayName.lowercased()) is getting stronger. Good time to push it to the next level."
        case .resolved:
            return "Your \(skillArea.displayName.lowercased()) has stabilized. Shifting focus to where you can grow most."
        case .stable:
            return nil
        }
    }

    // MARK: - Private Analysis Helpers

    private static func analyzeFillers(_ snapshots: [SkillSnapshot]) -> SkillTrend {
        let window = Array(snapshots.prefix(8))
        let confidence = trendConfidence(window.count)

        let current = window.first?.fillerCount ?? 0
        let recentAvg = window.prefix(3).map(\.fillerCount).average
        let olderAvg = window.dropFirst(3).map(\.fillerCount).average

        let level: SkillLevel
        if recentAvg <= 1 { level = .strong }
        else if recentAvg <= 3 { level = .solid }
        else if recentAvg <= 5 { level = .developing }
        else { level = .weak }

        let direction: TrendDirection
        let delta: String?

        if window.count < 3 {
            direction = current >= 5 ? .stable : .stable
            delta = nil
        } else if olderAvg > 0 && recentAvg < olderAvg * 0.7 {
            let diff = Int(olderAvg - recentAvg)
            direction = .improving
            delta = "Your filler count dropped by ~\(diff) compared to earlier sessions."
        } else if olderAvg > 0 && recentAvg > olderAvg * 1.3 {
            direction = .declining
            delta = nil
        } else if olderAvg <= 2 && recentAvg >= 4 {
            direction = .newIssue
            delta = nil
        } else {
            direction = .stable
            delta = nil
        }

        return SkillTrend(
            skillArea: .fillerReduction,
            direction: direction,
            confidence: confidence,
            windowSize: window.count,
            currentLevel: level,
            recentDelta: delta
        )
    }

    private static func analyzePace(_ snapshots: [SkillSnapshot]) -> SkillTrend {
        let window = Array(snapshots.prefix(8))
        let confidence = trendConfidence(window.count)

        let recentWPMs = window.prefix(3).map(\.wpm)
        let olderWPMs = window.dropFirst(3).map(\.wpm)
        let recentAvg = recentWPMs.average
        let olderAvg = olderWPMs.average

        let level: SkillLevel
        if recentAvg >= 110 && recentAvg <= 150 { level = .strong }
        else if recentAvg >= 100 && recentAvg <= 160 { level = .solid }
        else if recentAvg >= 90 && recentAvg <= 170 { level = .developing }
        else { level = .weak }

        let direction: TrendDirection
        if window.count < 3 {
            direction = .stable
        } else if level == .weak && olderAvg >= 100 && olderAvg <= 160 {
            direction = .newIssue
        } else if abs(recentAvg - olderAvg) < 10 {
            direction = .stable
        } else {
            // Is it getting closer to the ideal range (120-140)?
            let recentDistFromIdeal = abs(recentAvg - 130)
            let olderDistFromIdeal = abs(olderAvg - 130)
            direction = recentDistFromIdeal < olderDistFromIdeal ? .improving : .declining
        }

        return SkillTrend(
            skillArea: .paceControl,
            direction: direction,
            confidence: confidence,
            windowSize: window.count,
            currentLevel: level
        )
    }

    private static func analyzeCategory(
        _ dimension: String,
        skillArea: SkillArea,
        snapshots: [SkillSnapshot]
    ) -> SkillTrend {
        let window = Array(snapshots.prefix(8))
        let confidence = trendConfidence(window.count)

        let ratings = window.compactMap { $0.categoryRatings[dimension] }
        guard !ratings.isEmpty else {
            return SkillTrend(skillArea: skillArea, direction: .stable, confidence: .low, windowSize: 0, currentLevel: .developing)
        }

        let scores = ratings.map { ratingToScore($0) }
        let recentScores = Array(scores.prefix(3))
        let olderScores = Array(scores.dropFirst(3))

        let recentAvg = recentScores.average
        let olderAvg = olderScores.isEmpty ? recentAvg : olderScores.average

        let level: SkillLevel
        if recentAvg >= 2.5 { level = .strong }
        else if recentAvg >= 1.8 { level = .solid }
        else if recentAvg >= 1.0 { level = .developing }
        else { level = .weak }

        let direction: TrendDirection
        if scores.count < 3 {
            direction = .stable
        } else if recentAvg > olderAvg + 0.4 {
            direction = .improving
        } else if recentAvg < olderAvg - 0.4 {
            direction = .declining
        } else if olderAvg >= 2.0 && recentAvg < 1.0 {
            direction = .newIssue
        } else if olderAvg < 1.0 && recentAvg >= 2.0 {
            direction = .resolved
        } else {
            direction = .stable
        }

        return SkillTrend(
            skillArea: skillArea,
            direction: direction,
            confidence: confidence,
            windowSize: window.count,
            currentLevel: level
        )
    }

    private static func analyzeDuration(_ snapshots: [SkillSnapshot]) -> SkillTrend {
        let window = Array(snapshots.prefix(8))
        let confidence = trendConfidence(window.count)

        let recentDurations = window.prefix(3).map(\.duration)
        let recentAvg = recentDurations.average

        let level: SkillLevel
        if recentAvg >= 30 && recentAvg <= 120 { level = .strong }
        else if recentAvg >= 20 && recentAvg <= 150 { level = .solid }
        else if recentAvg >= 10 { level = .developing }
        else { level = .weak }

        // Duration maps to answerDevelopment (too short) or conciseSpeaking (too long)
        // We'll report on the shorter side since that's more actionable
        let skillArea: SkillArea = recentAvg < 20 ? .answerDevelopment : .conciseSpeaking

        return SkillTrend(
            skillArea: skillArea,
            direction: .stable,
            confidence: confidence,
            windowSize: window.count,
            currentLevel: level
        )
    }

    private static func trendConfidence(_ count: Int) -> TrendConfidence {
        if count >= 8 { return .high }
        if count >= 3 { return .medium }
        return .low
    }

    private static func ratingToScore(_ rating: String) -> Double {
        switch rating {
        case "Good": return 3.0
        case "OK": return 2.0
        case "Could improve": return 1.0
        default: return 2.0
        }
    }
}

// MARK: - Array Helpers

private extension Array where Element == Int {
    var average: Double {
        guard !isEmpty else { return 0 }
        return Double(reduce(0, +)) / Double(count)
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

private extension ArraySlice where Element == Int {
    var average: Double {
        guard !isEmpty else { return 0 }
        return Double(reduce(0, +)) / Double(count)
    }
}

private extension ArraySlice where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
