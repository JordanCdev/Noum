import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - LessonProgress

struct LessonProgress: Codable, Equatable {
    let lessonID: String
    /// 0–5. 0 = never attempted. 1 = first pass. 5 = mastered.
    var crownLevel: Int
    var lastCompletedAt: Date?
    var totalAttempts: Int

    static func empty(lessonID: String) -> LessonProgress {
        LessonProgress(lessonID: lessonID, crownLevel: 0, lastCompletedAt: nil, totalAttempts: 0)
    }
}

// MARK: - LessonStore

#if canImport(SwiftUI)

/// Per-account persistence for lesson outcomes. Owns the crown levels and
/// the "you just unlocked / levelled up a lesson" celebration trigger.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class LessonStore: ObservableObject {
    static let shared = LessonStore()

    @Published private(set) var progress: [String: LessonProgress] = [:]
    @Published private(set) var pendingCelebration: LessonCelebration?

    static let crownCap: Int = 5

    private let storageKeyPrefix = "noum.lessons.progress."

    private init() {
        load()
    }

    // MARK: - Public API

    func progress(for lessonID: String) -> LessonProgress {
        progress[lessonID] ?? .empty(lessonID: lessonID)
    }

    func crownLevel(for lessonID: String) -> Int {
        progress(for: lessonID).crownLevel
    }

    /// True when the user has at least one crown on this lesson.
    func isUnlocked(_ lessonID: String) -> Bool {
        crownLevel(for: lessonID) > 0
    }

    /// Total crowns earned across all lessons. Used as a top-line stat
    /// alongside XP / rank.
    var totalCrowns: Int {
        progress.values.map(\.crownLevel).reduce(0, +)
    }

    /// "Your next lesson" recommendation. Logic:
    /// 1. Lessons never opened (crown 0) — pick first by catalog order.
    /// 2. Otherwise — lowest crown that hasn't hit the cap, ties broken
    ///    by catalog order (so the user works the curriculum).
    /// 3. Returns nil only when every lesson is mastered.
    var nextRecommendedLesson: Lesson? {
        let untouched = LessonsCatalog.all.first(where: { crownLevel(for: $0.id) == 0 })
        if let untouched { return untouched }
        return LessonsCatalog.all
            .filter { crownLevel(for: $0.id) < Self.crownCap }
            .min(by: { crownLevel(for: $0.id) < crownLevel(for: $1.id) })
    }

    /// Apply a lesson outcome. Raises crown level if passed. Fires a
    /// celebration the first time a lesson is unlocked or when a level-up
    /// crosses a milestone (1, 3, 5).
    func apply(outcome: LessonOutcome) {
        var current = progress(for: outcome.lessonID)
        let priorCrown = current.crownLevel
        current.totalAttempts += 1
        current.lastCompletedAt = Date()

        if outcome.passed {
            current.crownLevel = min(Self.crownCap, current.crownLevel + 1)
        }

        progress[outcome.lessonID] = current
        persist()

        let didLevelUp = current.crownLevel > priorCrown
        let didUnlock = priorCrown == 0 && current.crownLevel > 0
        let didMaster = current.crownLevel == Self.crownCap && priorCrown != Self.crownCap

        guard didLevelUp else { return }

        let kind: LessonCelebration.Kind
        if didMaster { kind = .mastered }
        else if didUnlock { kind = .unlocked }
        else { kind = .levelUp }

        pendingCelebration = LessonCelebration(
            lessonID: outcome.lessonID,
            kind: kind,
            crownLevel: current.crownLevel
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
    let crownLevel: Int

    enum Kind {
        case unlocked   // first crown earned
        case levelUp    // 2nd, 3rd, 4th crown
        case mastered   // 5th crown — the cap

        var headline: String {
            switch self {
            case .unlocked: return "Lesson cleared"
            case .levelUp:  return "Crown earned"
            case .mastered: return "Lesson mastered"
            }
        }
    }
}
