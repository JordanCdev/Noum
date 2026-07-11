import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - LessonProgress

struct LessonProgress: Codable, Equatable {
    let lessonID: String
    /// 0-5. 0 = never attempted. 1 = first pass. 5 = mastered.
    var practicePassCount: Int
    var lastCompletedAt: Date?
    /// The last successful pass that counted toward spaced retention. Added
    /// after launch; legacy records infer this from `lastCompletedAt`.
    var lastPassedAt: Date?
    var totalAttempts: Int

    init(
        lessonID: String,
        practicePassCount: Int,
        lastCompletedAt: Date?,
        totalAttempts: Int,
        lastPassedAt: Date? = nil
    ) {
        self.lessonID = lessonID
        self.practicePassCount = practicePassCount
        self.lastCompletedAt = lastCompletedAt
        self.lastPassedAt = lastPassedAt
        self.totalAttempts = totalAttempts
    }

    static func empty(lessonID: String) -> LessonProgress {
        LessonProgress(lessonID: lessonID, practicePassCount: 0, lastCompletedAt: nil, totalAttempts: 0)
    }

    enum CodingKeys: String, CodingKey {
        case lessonID
        case practicePassCount
        case legacyCrownLevel = "crownLevel"
        case lastCompletedAt
        case lastPassedAt
        case totalAttempts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lessonID = try container.decode(String.self, forKey: .lessonID)
        if let passCount = try container.decodeIfPresent(Int.self, forKey: .practicePassCount) {
            practicePassCount = passCount
        } else {
            practicePassCount = try container.decodeIfPresent(Int.self, forKey: .legacyCrownLevel) ?? 0
        }
        lastCompletedAt = try container.decodeIfPresent(Date.self, forKey: .lastCompletedAt)
        lastPassedAt = try container.decodeIfPresent(Date.self, forKey: .lastPassedAt)
            ?? (practicePassCount > 0 ? lastCompletedAt : nil)
        totalAttempts = try container.decodeIfPresent(Int.self, forKey: .totalAttempts) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lessonID, forKey: .lessonID)
        try container.encode(practicePassCount, forKey: .practicePassCount)
        try container.encodeIfPresent(lastCompletedAt, forKey: .lastCompletedAt)
        try container.encodeIfPresent(lastPassedAt, forKey: .lastPassedAt)
        try container.encode(totalAttempts, forKey: .totalAttempts)
    }
}

// MARK: - Retention schedule

enum LessonReviewState: Equatable {
    case new
    case ready(dueAt: Date)
    case waiting(dueAt: Date)
}

/// A deliberately modest expanding schedule. It does not claim to find an
/// individually optimal interval; it prevents same-session repetition from
/// being presented as durable learning and gives the curriculum a clear
/// revisit rhythm.
enum LessonReviewSchedule {
    static let day: TimeInterval = 86_400
    static let intervals: [TimeInterval] = [
        0,
        day,
        3 * day,
        7 * day,
        14 * day,
        30 * day
    ]

    static func state(for progress: LessonProgress, now: Date = Date()) -> LessonReviewState {
        guard progress.practicePassCount > 0 else { return .new }
        let anchor = progress.lastPassedAt ?? progress.lastCompletedAt
        guard let anchor else { return .ready(dueAt: now) }
        let index = min(progress.practicePassCount, intervals.count - 1)
        let dueAt = anchor.addingTimeInterval(intervals[index])
        return dueAt <= now ? .ready(dueAt: dueAt) : .waiting(dueAt: dueAt)
    }

    static func canCountAnotherPass(for progress: LessonProgress, now: Date = Date()) -> Bool {
        switch state(for: progress, now: now) {
        case .new, .ready: return true
        case .waiting: return false
        }
    }

    static func dueDate(for progress: LessonProgress) -> Date? {
        guard progress.practicePassCount > 0 else { return nil }
        guard let anchor = progress.lastPassedAt ?? progress.lastCompletedAt else { return nil }
        let index = min(progress.practicePassCount, intervals.count - 1)
        return anchor.addingTimeInterval(intervals[index])
    }
}

struct LessonProgressUpdate: Equatable {
    let outcomePassed: Bool
    let didAdvanceRetention: Bool
    let didCompleteMaintenanceReview: Bool

    var earnsXP: Bool { didAdvanceRetention || didCompleteMaintenanceReview }
}

enum LessonRecommendationEngine {
    static func recommendedLesson(
        catalog: [Lesson],
        progressByID: [String: LessonProgress],
        now: Date = Date()
    ) -> Lesson? {
        let progress: (Lesson) -> LessonProgress = { lesson in
            progressByID[lesson.id] ?? .empty(lessonID: lesson.id)
        }

        let due = catalog.filter { lesson in
            guard progress(lesson).practicePassCount > 0 else { return false }
            if case .ready = LessonReviewSchedule.state(for: progress(lesson), now: now) { return true }
            return false
        }
        if let oldestDue = due.min(by: {
            (LessonReviewSchedule.dueDate(for: progress($0)) ?? .distantPast)
                < (LessonReviewSchedule.dueDate(for: progress($1)) ?? .distantPast)
        }) {
            return oldestDue
        }

        return catalog.first(where: { progress($0).practicePassCount == 0 })
    }
}

struct LessonProgressPresentation: Equatable {
    static let masteryPassCap: Int = 5

    let completedPasses: Int

    init(completedPasses: Int) {
        self.completedPasses = min(Self.masteryPassCap, max(0, completedPasses))
    }

    var fractionText: String {
        "\(completedPasses)/\(Self.masteryPassCap)"
    }

    var accessibilityLabel: String {
        "\(completedPasses) of \(Self.masteryPassCap) spaced practice rounds complete"
    }

    func lessonSummaryLine(title: String) -> String {
        if completedPasses >= Self.masteryPassCap {
            return "You've completed five spaced rounds of \(title)."
        }
        if completedPasses == 1 {
            return "First round complete. Revisit it after a little time has passed."
        }
        return "\(completedPasses) of \(Self.masteryPassCap) spaced rounds on \(title)."
    }

    func celebrationLine(for kind: LessonCelebration.Kind) -> String {
        switch kind {
        case .unlocked:
            return "First round complete. Use the move live before you revisit it."
        case .levelUp:
            return "\(completedPasses) of \(Self.masteryPassCap) spaced rounds."
        case .mastered:
            return "Five spaced rounds complete. Keep using the move in live conversations."
        }
    }

    static func aggregateValue(totalCompleted: Int, lessonCount: Int) -> String {
        "\(totalCompleted)/\(lessonCount * masteryPassCap)"
    }
}

struct LessonReviewPresentation: Equatable {
    let progress: LessonProgress
    let now: Date
    let calendar: Calendar

    init(progress: LessonProgress, now: Date = Date(), calendar: Calendar = .current) {
        self.progress = progress
        self.now = now
        self.calendar = calendar
    }

    var rowLabel: String {
        switch LessonReviewSchedule.state(for: progress, now: now) {
        case .new:
            return "New"
        case .ready:
            return "Ready to revisit"
        case .waiting(let dueAt):
            let days = max(1, calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: dueAt)
            ).day ?? 1)
            let prefix = "\(progress.practicePassCount) spaced \(progress.practicePassCount == 1 ? "round" : "rounds")"
            return days == 1 ? "\(prefix) · Review tomorrow" : "\(prefix) · Review in \(days) days"
        }
    }
}

// MARK: - LessonStore

#if canImport(SwiftUI)

/// Per-account persistence for lesson outcomes. Owns lesson practice-pass
/// progress and the "you just cleared / strengthened a lesson" celebration
/// trigger.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class LessonStore: ObservableObject {
    static let shared = LessonStore()

    @Published private(set) var progress: [String: LessonProgress] = [:]
    @Published private(set) var pendingCelebration: LessonCelebration?

    static let masteryPassCap: Int = LessonProgressPresentation.masteryPassCap

    private let storageKeyPrefix = "noum.lessons.progress."

    private init() {
        load()
    }

    // MARK: - Public API

    func progress(for lessonID: String) -> LessonProgress {
        progress[lessonID] ?? .empty(lessonID: lessonID)
    }

    func practicePassCount(for lessonID: String) -> Int {
        progress(for: lessonID).practicePassCount
    }

    /// True when the user has at least one successful pass on this lesson.
    func isCleared(_ lessonID: String) -> Bool {
        practicePassCount(for: lessonID) > 0
    }

    /// Total successful passes across all lessons. Used as a curriculum
    /// progress signal alongside real practice history.
    var totalPracticePasses: Int {
        progress.values.map(\.practicePassCount).reduce(0, +)
    }

    /// "Your next lesson" recommendation. Logic:
    /// 1. Lessons never opened (0 passes) — pick first by catalog order.
    /// 2. Otherwise — lowest pass count that hasn't hit the cap, ties broken
    ///    by catalog order (so the user works the curriculum).
    /// 3. Returns nil only when every lesson is mastered.
    var nextRecommendedLesson: Lesson? {
        nextRecommendedLesson(at: Date())
    }

    func nextRecommendedLesson(at now: Date) -> Lesson? {
        LessonRecommendationEngine.recommendedLesson(
            catalog: LessonsCatalog.all,
            progressByID: progress,
            now: now
        )
    }

    func reviewState(for lessonID: String, now: Date = Date()) -> LessonReviewState {
        LessonReviewSchedule.state(for: progress(for: lessonID), now: now)
    }

    var reviewsReadyCount: Int {
        LessonsCatalog.all.filter { lesson in
            if case .ready = LessonReviewSchedule.state(for: progress(for: lesson.id)) { return true }
            return false
        }.count
    }

    /// Apply a lesson outcome. Raises practice-pass progress if passed. Fires
    /// a celebration the first time a lesson is cleared or when progress
    /// crosses a milestone (1, 3, 5).
    @discardableResult
    func apply(outcome: LessonOutcome, now: Date = Date()) -> LessonProgressUpdate {
        var current = progress(for: outcome.lessonID)
        let priorPassCount = current.practicePassCount
        let canCountAnotherPass = LessonReviewSchedule.canCountAnotherPass(for: current, now: now)
        current.totalAttempts += 1
        current.lastCompletedAt = now

        var didAdvanceRetention = false
        var didCompleteMaintenanceReview = false

        if outcome.passed && canCountAnotherPass {
            current.lastPassedAt = now
            if current.practicePassCount < Self.masteryPassCap {
                current.practicePassCount += 1
                didAdvanceRetention = true
            } else {
                didCompleteMaintenanceReview = true
            }
        }

        progress[outcome.lessonID] = current
        persist()

        let didLevelUp = current.practicePassCount > priorPassCount
        let didUnlock = priorPassCount == 0 && current.practicePassCount > 0
        let didMaster = current.practicePassCount == Self.masteryPassCap && priorPassCount != Self.masteryPassCap

        guard didLevelUp else {
            return LessonProgressUpdate(
                outcomePassed: outcome.passed,
                didAdvanceRetention: didAdvanceRetention,
                didCompleteMaintenanceReview: didCompleteMaintenanceReview
            )
        }

        let kind: LessonCelebration.Kind
        if didMaster { kind = .mastered }
        else if didUnlock { kind = .unlocked }
        else { kind = .levelUp }

        pendingCelebration = LessonCelebration(
            lessonID: outcome.lessonID,
            kind: kind,
            practicePassCount: current.practicePassCount
        )
        return LessonProgressUpdate(
            outcomePassed: outcome.passed,
            didAdvanceRetention: didAdvanceRetention,
            didCompleteMaintenanceReview: didCompleteMaintenanceReview
        )
    }

    func consumeCelebration() {
        pendingCelebration = nil
    }

    func reloadForCurrentAccount() {
        load()
    }

    // MARK: - Persistence

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private var storageKey: String {
        storageKeyPrefix + Self.currentAccountID()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: LessonProgress].self, from: data) else {
            progress = [:]
            return
        }
        progress = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

#endif

// MARK: - LessonCelebration

struct LessonCelebration: Equatable {
    let lessonID: String
    let kind: Kind
    let practicePassCount: Int

    enum Kind {
        case unlocked
        case levelUp
        case mastered

        var headline: String {
            switch self {
        case .unlocked: return "Lesson cleared"
            case .levelUp:  return "Practice retained"
            case .mastered: return "Five spaced rounds complete"
            }
        }
    }
}
