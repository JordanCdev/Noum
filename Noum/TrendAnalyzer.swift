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
    /// Pauses per minute for this session, or nil if word timings weren't
    /// captured. Lets the trend analyzer pick up pause progress without
    /// re-reading the transcript.
    let pauseRate: Double?
    /// Pitch monotone score for this session, or nil if pitch wasn't reliable
    /// (silent rep, mic outside vocal range, fewer than 10 voiced windows).
    /// 0=varied, 1=flat. Lets the trend analyzer surface vocal-variety drift
    /// without re-reading the audio.
    let pitchMonotone: Double?
    /// Fraction of this session's pauses that were filled with a disfluency,
    /// 0…1. nil when the session emitted zero pauses (≥ 0.5s gaps) — a
    /// zero-pause rep can't honestly contribute a calmness reading, so the
    /// trend analyzer skips it rather than treat an empty session as
    /// "perfectly calm".
    let pauseFilledRatio: Double?

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
        drillCompleted: CompletedDrillRef? = nil,
        pauseRate: Double? = nil,
        pitchMonotone: Double? = nil,
        pauseFilledRatio: Double? = nil
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
        self.pauseRate = pauseRate
        self.pitchMonotone = pitchMonotone
        self.pauseFilledRatio = pauseFilledRatio
    }

    enum CodingKeys: String, CodingKey {
        case id, sessionId, date, fillerCount, duration, wordCount, wpm
        case score, categoryRatings, drillCompleted, pauseRate, pitchMonotone
        case pauseFilledRatio
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sessionId = try c.decode(UUID.self, forKey: .sessionId)
        date = try c.decode(Date.self, forKey: .date)
        fillerCount = try c.decode(Int.self, forKey: .fillerCount)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        wordCount = try c.decode(Int.self, forKey: .wordCount)
        wpm = try c.decode(Double.self, forKey: .wpm)
        score = try c.decode(Int.self, forKey: .score)
        categoryRatings = try c.decodeIfPresent([String: String].self, forKey: .categoryRatings) ?? [:]
        drillCompleted = try c.decodeIfPresent(CompletedDrillRef.self, forKey: .drillCompleted)
        pauseRate = try c.decodeIfPresent(Double.self, forKey: .pauseRate)
        pitchMonotone = try c.decodeIfPresent(Double.self, forKey: .pitchMonotone)
        pauseFilledRatio = try c.decodeIfPresent(Double.self, forKey: .pauseFilledRatio)
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
        drillCompleted: SkillSnapshot.CompletedDrillRef? = nil,
        pauseRate: Double? = nil,
        pitchMonotone: Double? = nil,
        pauseFilledRatio: Double? = nil
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
            drillCompleted: drillCompleted,
            pauseRate: pauseRate,
            pitchMonotone: pitchMonotone,
            pauseFilledRatio: pauseFilledRatio
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
        if let pauseTrend = analyzePause(snapshots) {
            trends.append(pauseTrend)
        }
        if let pitchTrend = analyzePitch(snapshots) {
            trends.append(pitchTrend)
        }

        return trends
    }

    /// Pitch monotone trend across snapshots that captured a reliable
    /// reading. Maps to `vocalEmphasis` (the closest existing skill area —
    /// pitch variation is one of the levers vocal emphasis pulls). Returns
    /// nil when too few snapshots have pitch data, so day-1 reps don't
    /// produce noisy "improving from nothing" signals.
    static func analyzePitch(_ snapshots: [SkillSnapshot]) -> SkillTrend? {
        let withPitch = snapshots.filter { $0.pitchMonotone != nil }
        guard withPitch.count >= 3 else { return nil }

        let recent = Array(withPitch.prefix(3))
        let previous = Array(withPitch.dropFirst(3).prefix(3))

        let recentAvg = recent.compactMap(\.pitchMonotone).reduce(0, +) / Double(max(1, recent.count))
        let prevAvg = previous.isEmpty
            ? recentAvg
            : previous.compactMap(\.pitchMonotone).reduce(0, +) / Double(previous.count)
        // Lower monotone score = more varied = improvement.
        let delta = recentAvg - prevAvg

        let direction: TrendDirection
        if previous.isEmpty {
            direction = .stable
        } else if delta <= -0.10 {
            direction = .improving
        } else if delta >= 0.10 {
            direction = .declining
        } else if prevAvg < 0.45 && recentAvg > 0.70 {
            direction = .newIssue
        } else if prevAvg > 0.70 && recentAvg < 0.45 {
            direction = .resolved
        } else {
            direction = .stable
        }

        let level: SkillLevel
        if recentAvg <= 0.30 { level = .strong }
        else if recentAvg <= 0.55 { level = .solid }
        else if recentAvg <= 0.75 { level = .developing }
        else { level = .weak }

        let confidence: TrendConfidence = withPitch.count >= 8 ? .high
            : (withPitch.count >= 4 ? .medium : .low)

        let deltaText: String? = {
            guard !previous.isEmpty, abs(delta) >= 0.05 else { return nil }
            // Express variation in the user's language (varied vs flat).
            let direction = delta < 0 ? "more varied" : "flatter"
            return "\(String(format: "%.2f", abs(delta))) \(direction) vs prior"
        }()

        return SkillTrend(
            skillArea: .vocalEmphasis,
            direction: direction,
            confidence: confidence,
            windowSize: withPitch.count,
            currentLevel: level,
            recentDelta: deltaText
        )
    }

    /// Pause-rate trend across the snapshots that captured pause data.
    /// Returns nil when too few snapshots have pauseRate to read a trend
    /// (avoids noisy "improving from nothing" signals on day-1 reps).
    static func analyzePause(_ snapshots: [SkillSnapshot]) -> SkillTrend? {
        let withPauses = snapshots.filter { $0.pauseRate != nil }
        guard withPauses.count >= 3 else { return nil }

        // Compare the latest 3 reps with the next-3-back to detect direction.
        let recent = Array(withPauses.prefix(3))
        let previous = Array(withPauses.dropFirst(3).prefix(3))

        let recentAvg = recent.compactMap(\.pauseRate).reduce(0, +) / Double(max(1, recent.count))
        let prevAvg = previous.isEmpty
            ? recentAvg
            : previous.compactMap(\.pauseRate).reduce(0, +) / Double(previous.count)
        let delta = recentAvg - prevAvg

        let direction: TrendDirection
        if previous.isEmpty {
            direction = .stable
        } else if delta >= 0.4 {
            // More pauses per minute = more deliberate delivery.
            direction = .improving
        } else if delta <= -0.4 {
            direction = .declining
        } else {
            direction = .stable
        }

        let level: SkillLevel
        if recentAvg >= 4.0 { level = .strong }
        else if recentAvg >= 2.5 { level = .solid }
        else if recentAvg >= 1.0 { level = .developing }
        else { level = .weak }

        let confidence: TrendConfidence = withPauses.count >= 8 ? .high
            : (withPauses.count >= 4 ? .medium : .low)

        let deltaText: String? = {
            guard !previous.isEmpty, abs(delta) >= 0.2 else { return nil }
            let sign = delta > 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", delta))/min vs prior"
        }()

        return SkillTrend(
            skillArea: .pauseUsage,
            direction: direction,
            confidence: confidence,
            windowSize: withPauses.count,
            currentLevel: level,
            recentDelta: deltaText
        )
    }

    /// Find the single highest-leverage focus area for the next drill.
    ///
    /// `styleGoal` (optional) lets the picker prefer skills aligned with the
    /// user's chosen voice when otherwise-equivalent candidates are tied. The
    /// bonus is intentionally small (+10) so it can break ties between
    /// equal-priority trends and tip near-ties between adjacent tiers, but
    /// never overrides a declining-high-confidence (100), weak-stable (90),
    /// or new-issue (80) trend on an off-goal skill. The picker stays
    /// urgency-first.
    static func primaryFocus(
        trends: [SkillTrend],
        currentSessionSnapshot: SkillSnapshot?,
        recentDrills: [DrillHistoryStore.Entry],
        styleGoal: SpeakingStyleGoal? = nil
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

            // Goal-alignment tiebreaker. Small (+10) by design: breaks ties
            // between equal-priority candidates and tips near-ties at the
            // bottom of the ladder (developing → developing+aligned). The
            // gap between urgent tiers (declining 100, weak-stable 90,
            // new-issue 80) and lower tiers is large enough that this bias
            // never demotes an urgent off-goal trend.
            if let styleGoal, styleGoal.aligns(with: trend.skillArea), priority > 0 {
                priority += 10
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

        // No urgent signal anywhere. When the user has stated a voice goal,
        // pick the canonical most-direct lever for that voice rather than the
        // generic `.structure` default — keeps day-one users with a goal on
        // a goal-grounded path from their first drill.
        if let styleGoal {
            return styleGoal.primaryAlignedSkillArea
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
