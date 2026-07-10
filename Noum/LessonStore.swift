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
    var totalAttempts: Int

    init(
        lessonID: String,
        practicePassCount: Int,
        lastCompletedAt: Date?,
        totalAttempts: Int
    ) {
        self.lessonID = lessonID
        self.practicePassCount = practicePassCount
        self.lastCompletedAt = lastCompletedAt
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
        totalAttempts = try container.decodeIfPresent(Int.self, forKey: .totalAttempts) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lessonID, forKey: .lessonID)
        try container.encode(practicePassCount, forKey: .practicePassCount)
        try container.encodeIfPresent(lastCompletedAt, forKey: .lastCompletedAt)
        try container.encode(totalAttempts, forKey: .totalAttempts)
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
        "\(completedPasses) of \(Self.masteryPassCap) practice passes complete"
    }

    func lessonSummaryLine(title: String) -> String {
        if completedPasses >= Self.masteryPassCap {
            return "You've completed all five passes of \(title)."
        }
        if completedPasses == 1 {
            return "First practice pass complete. Four more passes to complete."
        }
        return "\(completedPasses) of \(Self.masteryPassCap) practice passes on \(title)."
    }

    func celebrationLine(for kind: LessonCelebration.Kind) -> String {
        switch kind {
        case .unlocked:
            return "First practice pass complete. Four more passes to complete."
        case .levelUp:
            return "\(completedPasses) of \(Self.masteryPassCap) practice passes."
        case .mastered:
            return "All five practice passes complete. Keep using the technique in live reps."
        }
    }

    static func aggregateValue(totalCompleted: Int, lessonCount: Int) -> String {
        "\(totalCompleted)/\(lessonCount * masteryPassCap)"
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
        let untouched = LessonsCatalog.all.first(where: { practicePassCount(for: $0.id) == 0 })
        if let untouched { return untouched }
        return LessonsCatalog.all
            .filter { practicePassCount(for: $0.id) < Self.masteryPassCap }
            .min(by: { practicePassCount(for: $0.id) < practicePassCount(for: $1.id) })
    }

    /// Apply a lesson outcome. Raises practice-pass progress if passed. Fires
    /// a celebration the first time a lesson is cleared or when progress
    /// crosses a milestone (1, 3, 5).
    func apply(outcome: LessonOutcome) {
        var current = progress(for: outcome.lessonID)
        let priorPassCount = current.practicePassCount
        current.totalAttempts += 1
        current.lastCompletedAt = Date()

        if outcome.passed {
            current.practicePassCount = min(Self.masteryPassCap, current.practicePassCount + 1)
        }

        progress[outcome.lessonID] = current
        persist()

        let didLevelUp = current.practicePassCount > priorPassCount
        let didUnlock = priorPassCount == 0 && current.practicePassCount > 0
        let didMaster = current.practicePassCount == Self.masteryPassCap && priorPassCount != Self.masteryPassCap

        guard didLevelUp else { return }

        let kind: LessonCelebration.Kind
        if didMaster { kind = .mastered }
        else if didUnlock { kind = .unlocked }
        else { kind = .levelUp }

        pendingCelebration = LessonCelebration(
            lessonID: outcome.lessonID,
            kind: kind,
            practicePassCount: current.practicePassCount
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
            case .levelUp:  return "Practice pass added"
            case .mastered: return "Five passes complete"
            }
        }
    }
}
