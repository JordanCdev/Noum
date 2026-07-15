import Foundation

// MARK: - Transparent memory & trajectory (user-facing)
//
// This is the USER-VISIBLE read of what Ask Noum currently knows — distinct
// from `UserTrajectorySnapshot` (`UserTrajectoryCache.swift`), which is the
// internal, denser context blob `CoachContextBuilder` feeds the model. That
// type stays owned by the reply pipeline; this one exists so the UI can show,
// verify, and let the user manage exactly what personalization is in play,
// without ever inventing evidence the app doesn't actually have.

struct MemoryTrajectorySnapshot: Equatable {
    var activeGoals: [String]
    var recentReps: [MemoryRepEvidence]
    var trendSignals: [MemoryTrendSignal]
    /// Days since the most-recent practice rep. `nil` only when there is no
    /// rep history at all — never a fabricated 0.
    var evidenceFreshnessDays: Int?
    /// Reuses the existing baseline evidence ladder (`BaselineEngine.swift`)
    /// rather than inventing a parallel confidence scale.
    var confidence: BaselineConfidence
    /// The "Using in this answer" line — the honest, bounded, coach-voice
    /// summary of what's driving personalization right now.
    var userVisibility: String
    /// True when the most-recent rep is older than `TrajectorySummaryBuilder
    /// .stalenessThresholdDays`. The pill/view must say so rather than imply
    /// the coach is drawing on something current.
    var isStale: Bool

    static let empty = MemoryTrajectorySnapshot(
        activeGoals: [],
        recentReps: [],
        trendSignals: [],
        evidenceFreshnessDays: nil,
        confidence: .insufficient,
        userVisibility: TrajectorySummaryBuilder.notEnoughYetLine,
        isStale: false
    )
}

struct MemoryRepEvidence: Equatable, Identifiable {
    var id = UUID()
    var modeLabel: String
    var summaryLine: String
    var daysAgo: Int
    var isRated: Bool
}

struct MemoryTrendSignal: Equatable, Identifiable {
    var id = UUID()
    var metricLabel: String
    var direction: TrendDirection
    var deltaLine: String
    var exampleEvidenceLine: String?
}

/// Pure builder — no store access, no singletons. Every caller passes the
/// state it already reads (profile, baseline, sessions, coach memory), which
/// keeps this testable without touching persistence and keeps the "no
/// overclaim" contract enforceable in unit tests.
enum TrajectorySummaryBuilder {
    /// Below this many reps, a week-over-week delta is noise, not a trend —
    /// mirrors `UserTrajectoryCache`'s evidence-floor pattern of refusing to
    /// speak with confidence on thin history.
    static let minimumSessionsForTrend = 3
    /// A rep older than this reads as stale; the "Using" line must flag it
    /// rather than silently imply the coach is drawing on something current.
    static let stalenessThresholdDays = 21
    static let notEnoughYetLine = "Not enough yet — practice a few reps and set a goal, and Noum will show what it's using here."

    static func build(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        coachMemory: CoachMemory?,
        now: Date
    ) -> MemoryTrajectorySnapshot {
        let eligibleSessions = PracticeProgressEligibility.eligibleSessions(in: sessions)
        guard profile != nil || !eligibleSessions.isEmpty else { return .empty }

        let sorted = eligibleSessions.sorted { $0.date > $1.date }
        let caseFile = coachMemory?.caseFile
        let freshnessDays = sorted.first.map { daysBetween($0.date, now) }
        let isStale = freshnessDays.map { $0 > stalenessThresholdDays } ?? false

        let goals = activeGoalLines(profile: profile, caseFile: caseFile)
        let recentReps = recentRepEvidence(from: sorted, now: now)
        let trends = weeklyTrendSignals(from: sorted, now: now)

        return MemoryTrajectorySnapshot(
            activeGoals: goals,
            recentReps: recentReps,
            trendSignals: trends,
            evidenceFreshnessDays: freshnessDays,
            confidence: baseline.overallConfidence,
            userVisibility: usingLine(
                profile: profile,
                caseFile: caseFile,
                recentRepCount: recentReps.count,
                isStale: isStale,
                freshnessDays: freshnessDays
            ),
            isStale: isStale
        )
    }

    // MARK: - Goals

    private static func activeGoalLines(profile: CoachingProfile?, caseFile: CoachCaseFile?) -> [String] {
        var lines: [String] = []
        if let hypothesis = caseFile?.hypothesis, !hypothesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(hypothesis)
        } else if let focus = caseFile?.focus {
            lines.append("Current focus: \(focus.displayName.lowercased()).")
        }
        if let profile {
            lines.append(profile.displayableGoal)
        }
        return lines
    }

    private static func goalClause(profile: CoachingProfile?, caseFile: CoachCaseFile?) -> String? {
        if let focus = caseFile?.focus {
            return "your \(focus.displayName.lowercased()) focus"
        }
        if let profile {
            return "your goal to \(profile.primaryGoal.title.lowercased())"
        }
        return nil
    }

    // MARK: - Recent reps

    private static func recentRepEvidence(from sorted: [PracticeSession], now: Date) -> [MemoryRepEvidence] {
        sorted.prefix(3).map { session in
            let score = session.score.map { "\($0)/10" } ?? "no score"
            let duration = Int(session.duration.rounded())
            return MemoryRepEvidence(
                modeLabel: session.mode.displayLabel,
                summaryLine: "\(session.mode.displayLabel): \(score), \(session.fillerWordCount) fillers, \(duration)s",
                daysAgo: daysBetween(session.date, now),
                isRated: session.isRated
            )
        }
    }

    // MARK: - Weekly trend signals

    private static func weeklyTrendSignals(from sorted: [PracticeSession], now: Date) -> [MemoryTrendSignal] {
        guard sorted.count >= minimumSessionsForTrend else { return [] }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        guard let previousWeekAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else {
            return []
        }

        let currentKey = weekKey(for: now, calendar: calendar)
        let previousKey = weekKey(for: previousWeekAnchor, calendar: calendar)

        let currentWeek = sorted.filter { weekKey(for: $0.date, calendar: calendar) == currentKey }
        let previousWeek = sorted.filter { weekKey(for: $0.date, calendar: calendar) == previousKey }

        guard !currentWeek.isEmpty, !previousWeek.isEmpty else { return [] }

        var signals: [MemoryTrendSignal] = []
        let scoreExample = exampleLine(from: currentWeek)
        let currentFillerSessions = quantityQualifiedSessions(in: currentWeek)
        let previousFillerSessions = quantityQualifiedSessions(in: previousWeek)
        if currentFillerSessions.count >= 2,
           previousFillerSessions.count >= 2,
           let fillerSignal = trendSignal(
               metricLabel: "Filler rate",
               current: average(fillerRates(in: currentFillerSessions)),
               previous: average(fillerRates(in: previousFillerSessions)),
               lowerIsBetter: true,
               formatter: { String(format: "%.1f/min", $0) },
               exampleEvidence: fillerExampleLine(from: currentFillerSessions)
           ) {
            signals.append(fillerSignal)
        }

        let currentScores = currentWeek.compactMap(\.score).map(Double.init)
        let previousScores = previousWeek.compactMap(\.score).map(Double.init)
        if !currentScores.isEmpty, !previousScores.isEmpty,
           let scoreSignal = trendSignal(
               metricLabel: "Score",
               current: average(currentScores),
               previous: average(previousScores),
               lowerIsBetter: false,
               formatter: { String(format: "%.1f/10", $0) },
               exampleEvidence: scoreExample
           ) {
            signals.append(scoreSignal)
        }

        return signals
    }

    private static func weekKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
    }

    private static func trendSignal(
        metricLabel: String,
        current: Double,
        previous: Double,
        lowerIsBetter: Bool,
        formatter: (Double) -> String,
        exampleEvidence: String?
    ) -> MemoryTrendSignal? {
        let delta = current - previous
        let epsilon = 0.05
        guard abs(delta) > epsilon else {
            return MemoryTrendSignal(
                metricLabel: metricLabel,
                direction: .stable,
                deltaLine: "\(formatter(previous)) to \(formatter(current)), holding steady",
                exampleEvidenceLine: exampleEvidence
            )
        }
        // `rawArrow` is the literal numeric direction; `direction` is the value
        // judgement (which differs per metric — fewer fillers is an improvement,
        // a higher score is). Keeping them separate mirrors the existing
        // `goodWhenUp` convention in `IMScenarioDetailView`'s trend chips.
        let rawArrow = delta > 0 ? "up" : "down"
        let improved = lowerIsBetter ? delta < 0 : delta > 0
        let direction: TrendDirection = improved ? .improving : .declining
        return MemoryTrendSignal(
            metricLabel: metricLabel,
            direction: direction,
            deltaLine: "\(formatter(previous)) to \(formatter(current)), \(rawArrow) \(formatter(abs(delta)))",
            exampleEvidenceLine: exampleEvidence
        )
    }

    private static func exampleLine(from week: [PracticeSession]) -> String? {
        guard let example = week.max(by: { $0.date < $1.date }) else { return nil }
        let score = example.score.map { "\($0)/10" } ?? "no score"
        return "Example: \(example.mode.displayLabel) rep, \(score), \(example.fillerWordCount) fillers across \(Int(example.duration.rounded()))s."
    }

    private static func quantityQualifiedSessions(
        in sessions: [PracticeSession]
    ) -> [PracticeSession] {
        sessions.filter {
            SessionQualifier.meetsQuantityFloor(
                duration: $0.duration,
                wordCount: $0.wordCount
            )
        }
    }

    private static func fillerRates(in sessions: [PracticeSession]) -> [Double] {
        sessions.compactMap {
            FillerBurden(
                fillerCount: $0.fillerWordCount,
                duration: $0.duration
            ).ratePerMinute
        }
    }

    private static func fillerExampleLine(from week: [PracticeSession]) -> String? {
        guard let example = week.max(by: { $0.date < $1.date }),
              let rate = FillerBurden(
                  fillerCount: example.fillerWordCount,
                  duration: example.duration
              ).ratePerMinute else { return nil }
        return "Example: \(example.mode.displayLabel) rep, \(example.fillerWordCount) fillers across \(Int(example.duration.rounded()))s (\(String(format: "%.1f", rate))/min)."
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - "Using in this answer"

    private static func usingLine(
        profile: CoachingProfile?,
        caseFile: CoachCaseFile?,
        recentRepCount: Int,
        isStale: Bool,
        freshnessDays: Int?
    ) -> String {
        let repCount = min(recentRepCount, 2)
        let repClause: String? = switch repCount {
        case 0: nil
        case 1: "your last rep"
        default: "your last \(repCount) reps"
        }

        var clauses: [String] = []
        if let goal = goalClause(profile: profile, caseFile: caseFile) {
            clauses.append(goal)
        }
        if let repClause {
            clauses.append(repClause)
        }

        guard !clauses.isEmpty else { return notEnoughYetLine }

        var line = "Based on " + clauses.joined(separator: " and ") + "."
        if isStale, let freshnessDays {
            line += " Your most recent rep was \(freshnessDays) days ago — this may be out of date."
        }
        return line
    }

    private static func daysBetween(_ date: Date, _ now: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        return max(0, days)
    }
}
