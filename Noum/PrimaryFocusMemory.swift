import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Primary Focus Memory
//
// Persists the last-known `TrendAnalyzer.primaryFocus(...)` result per
// account so we can detect when the coach's recommended focus area has
// shifted since the user last opened the app. A shift is surfaced in
// `AIWeeklyInsightCard` and the weekly digest notification copy — the
// lowest-cost / highest-trust signal that the coach is adapting.

struct FocusShiftEvent {
    let from: SkillArea
    let to: SkillArea
    let detectedAt: Date
}

enum PrimaryFocusMemory {

    private static func key(for accountID: String) -> String {
        "lastPrimaryFocus.\(accountID)"
    }

    // MARK: - Persist

    static func save(_ focus: SkillArea, for accountID: String) {
        UserDefaults.standard.set(focus.rawValue, forKey: key(for: accountID))
    }

    // MARK: - Detect shift

    /// Returns a `FocusShiftEvent` when `current` differs from the persisted
    /// last focus. Persists `current` before returning so the next call
    /// starts from the updated baseline. Returns nil on first run (no prior)
    /// or when the focus is unchanged.
    @discardableResult
    static func detectShift(
        current: SkillArea,
        accountID: String
    ) -> FocusShiftEvent? {
        let storedRaw = UserDefaults.standard.string(forKey: key(for: accountID))
        let prior = storedRaw.flatMap { SkillArea(rawValue: $0) }
        save(current, for: accountID)
        guard let prior, prior != current else { return nil }
        return FocusShiftEvent(from: prior, to: current, detectedAt: Date())
    }

    // MARK: - Read (without mutating)

    static func lastFocus(for accountID: String) -> SkillArea? {
        UserDefaults.standard.string(forKey: key(for: accountID))
            .flatMap { SkillArea(rawValue: $0) }
    }
}

// MARK: - Coach Memory
//
// PrimaryFocusMemory is intentionally tiny: last focus in, shift event out.
// CoachMemory is the richer "professional coach's working read" layered on
// the same product idea. It persists the current formulation per account so
// Ask Noum can say "my read has shifted" instead of re-deriving a fresh,
// stateless hypothesis on every chat turn.

enum CoachMemoryGoalFit: String, Codable, Equatable {
    case aligned
    case offGoal
    case noVoice
    case noLever
}

struct CoachMemory: Codable, Equatable {
    var updatedAt: Date
    var lastSessionID: UUID?
    var evidenceCount: Int
    var evidenceConfidence: BaselineConfidence
    var voice: SpeakingStyleGoal?
    var statedGoalSummary: String?
    var currentLever: SkillArea?
    var currentLeverConfidence: TrendConfidence?
    var currentLeverBasis: String?
    var previousLever: SkillArea?
    var focusShiftedAt: Date?
    var goalFit: CoachMemoryGoalFit
    var strengths: [String]
    var blockers: [String]
    var lastIntentLabel: String?
    var planWeekIndex: Int?
    var planFocus: SkillArea?
    var planMode: PracticeMode?
}

enum CoachMemoryEngine {
    static func build(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        trends: [SkillTrend],
        forwardPlan: ForwardPlan?,
        previous: CoachMemory?,
        lastSessionID: UUID?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachMemory? {
        let cutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? .distantPast
        let recentSessionCount = sessions.filter { $0.date >= cutoff }.count
        let maxTrendWindow = trends.map(\.windowSize).max() ?? 0
        let evidenceCount = [recentSessionCount, baseline.qualifyingSessionCount, maxTrendWindow].max() ?? 0
        guard evidenceCount > 0 else { return nil }

        let evidenceConfidence = max(
            baseline.overallConfidence,
            BaselineConfidence.from(sessionCount: evidenceCount)
        )

        let lever = selectLever(profile: profile, baseline: baseline, trends: trends)
        let voice = profile?.speakingStyleGoal
        let currentLever = lever?.area
        let goalFit: CoachMemoryGoalFit = {
            guard let currentLever else { return .noLever }
            guard let voice else { return .noVoice }
            return voice.aligns(with: currentLever) ? .aligned : .offGoal
        }()

        let previousLever: SkillArea?
        let focusShiftedAt: Date?
        if let prior = previous?.currentLever,
           let currentLever,
           prior != currentLever {
            previousLever = prior
            focusShiftedAt = now
        } else {
            previousLever = previous?.previousLever
            focusShiftedAt = previous?.focusShiftedAt
        }

        let currentWeek = forwardPlan?.currentWeek(now: now, calendar: calendar)

        return CoachMemory(
            updatedAt: now,
            lastSessionID: lastSessionID,
            evidenceCount: evidenceCount,
            evidenceConfidence: evidenceConfidence,
            voice: voice,
            statedGoalSummary: statedGoalSummary(from: profile),
            currentLever: currentLever,
            currentLeverConfidence: lever?.confidence,
            currentLeverBasis: lever?.basis,
            previousLever: previousLever,
            focusShiftedAt: focusShiftedAt,
            goalFit: goalFit,
            strengths: Array(baseline.topStrengths.prefix(3)),
            blockers: Array(baseline.persistentBlockers.prefix(3)),
            lastIntentLabel: latestIntentLabel(from: sessions),
            planWeekIndex: currentWeek?.weekIndex,
            planFocus: currentWeek?.focusSkillArea,
            planMode: currentWeek?.suggestedMode
        )
    }

    private struct LeverSelection {
        let area: SkillArea
        let confidence: TrendConfidence?
        let basis: String
    }

    private static func selectLever(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        trends: [SkillTrend]
    ) -> LeverSelection? {
        if let trend = strongestTrendLever(from: trends, profile: profile) {
            return LeverSelection(
                area: trend.skillArea,
                confidence: trend.confidence,
                basis: trendBasis(trend)
            )
        }

        if let blocker = baseline.persistentBlockers.first,
           let area = skillArea(fromBlocker: blocker) {
            return LeverSelection(
                area: area,
                confidence: nil,
                basis: "persistent blocker in the rolling baseline"
            )
        }

        if let voice = profile?.speakingStyleGoal {
            return LeverSelection(
                area: voice.primaryAlignedSkillArea,
                confidence: nil,
                basis: "stated voice goal while evidence is still forming"
            )
        }

        return nil
    }

    private static func strongestTrendLever(
        from trends: [SkillTrend],
        profile: CoachingProfile?
    ) -> SkillTrend? {
        let scored = trends.compactMap { trend -> (trend: SkillTrend, score: Int)? in
            let score = scoreTrend(trend, profile: profile)
            guard score > 0 else { return nil }
            return (trend, score)
        }
        return scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.trend.windowSize != rhs.trend.windowSize {
                return lhs.trend.windowSize > rhs.trend.windowSize
            }
            return lhs.trend.skillArea.displayName < rhs.trend.skillArea.displayName
        }.first?.trend
    }

    private static func scoreTrend(_ trend: SkillTrend, profile: CoachingProfile?) -> Int {
        guard trend.confidence != .low,
              trend.direction != .resolved,
              trend.currentLevel != .strong else { return 0 }

        var score: Int
        switch trend.direction {
        case .declining: score = 100
        case .newIssue: score = 90
        case .stable: score = trend.currentLevel <= .developing ? 75 : 25
        case .improving: score = trend.currentLevel <= .developing ? 60 : 20
        case .resolved: score = 0
        }

        switch trend.currentLevel {
        case .weak: score += 25
        case .developing: score += 15
        case .solid: score += 4
        case .strong: break
        }

        switch trend.confidence {
        case .high: score += 10
        case .medium: score += 4
        case .low: break
        }

        if profile?.speakingStyleGoal.aligns(with: trend.skillArea) == true {
            score += 8
        }

        return score >= 50 ? score : 0
    }

    private static func trendBasis(_ trend: SkillTrend) -> String {
        let core: String
        switch trend.direction {
        case .declining:
            core = "declining trend"
        case .newIssue:
            core = "new issue in recent reps"
        case .stable:
            core = "stable at \(trend.currentLevel.rawValue)"
        case .improving:
            core = "improving but still \(trend.currentLevel.rawValue)"
        case .resolved:
            core = "recently resolved"
        }

        if let delta = trend.recentDelta?.trimmingCharacters(in: .whitespacesAndNewlines),
           !delta.isEmpty {
            return "\(core); \(delta)"
        }
        return core
    }

    private static func skillArea(fromBlocker blocker: String) -> SkillArea? {
        let normalized = blocker.lowercased()
        if normalized.contains("filler") { return .fillerReduction }
        if normalized.contains("opening") { return .openingStrength }
        if normalized.contains("closing") || normalized.contains("close") { return .closingStrength }
        if normalized.contains("pace") || normalized.contains("rush") { return .paceControl }
        if normalized.contains("structure") || normalized.contains("rambl") { return .structure }
        if normalized.contains("depth") || normalized.contains("answer") { return .answerDevelopment }
        if normalized.contains("clarity") || normalized.contains("concise") { return .conciseSpeaking }
        if normalized.contains("pause") { return .pauseUsage }
        if normalized.contains("emphasis") || normalized.contains("vocal") { return .vocalEmphasis }
        if normalized.contains("confidence") || normalized.contains("freez") { return .confidence }
        return nil
    }

    private static func latestIntentLabel(from sessions: [PracticeSession]) -> String? {
        sessions
            .sorted { $0.date > $1.date }
            .compactMap { $0.intentLabel?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func statedGoalSummary(from profile: CoachingProfile?) -> String? {
        guard let profile else { return nil }
        let candidates = [
            profile.paraphrasedGoal,
            profile.personalGoalReference,
            profile.successVisionReference,
            profile.whyNowReference,
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

#if canImport(Combine)
@MainActor
final class CoachMemoryStore: ObservableObject {
    static let shared = CoachMemoryStore()

    @Published private(set) var currentMemory: CoachMemory?

    private static let storagePrefix = "coachMemory."

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        self.accountIDProvider = accountIDProvider ?? { KeychainHelper.load(key: "NoumAccountID") }
        loadFromDisk()
    }

    func reloadForCurrentAccount() {
        loadFromDisk()
    }

    func endSession() {
        currentMemory = nil
    }

    func refresh(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        trends: [SkillTrend],
        forwardPlan: ForwardPlan?,
        lastSessionID: UUID?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard let memory = CoachMemoryEngine.build(
            profile: profile,
            baseline: baseline,
            sessions: sessions,
            trends: trends,
            forwardPlan: forwardPlan,
            previous: currentMemory,
            lastSessionID: lastSessionID,
            now: now,
            calendar: calendar
        ) else { return }
        currentMemory = memory
        persist(memory)
    }

    func replaceForTesting(_ memory: CoachMemory?) {
        currentMemory = memory
        guard let accountID = accountIDProvider() else { return }
        if let memory {
            persist(memory)
        } else {
            defaults.removeObject(forKey: storageKey(for: accountID))
        }
    }

    func clearAll() {
        guard let accountID = accountIDProvider() else {
            currentMemory = nil
            return
        }
        currentMemory = nil
        defaults.removeObject(forKey: storageKey(for: accountID))
    }

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: storageKey(for: accountID))
        if accountIDProvider() == accountID {
            currentMemory = nil
        }
    }

    private func persist(_ memory: CoachMemory) {
        guard let accountID = accountIDProvider(),
              let data = try? JSONEncoder().encode(memory) else { return }
        defaults.set(data, forKey: storageKey(for: accountID))
    }

    private func loadFromDisk() {
        guard let accountID = accountIDProvider(),
              let data = defaults.data(forKey: storageKey(for: accountID)),
              let decoded = try? JSONDecoder().decode(CoachMemory.self, from: data) else {
            currentMemory = nil
            return
        }
        currentMemory = decoded
    }

    private func storageKey(for accountID: String) -> String {
        "\(Self.storagePrefix)\(accountID)"
    }
}
#endif
