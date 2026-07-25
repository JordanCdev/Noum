import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(Combine)
import Combine
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - Streak first-sight policy

// MARK: - Streak Freeze Manager

/// Streak protection — one freeze auto-earned per ISO week, automatically
/// consumed when a missed day would otherwise break the streak.
///
/// Design principles:
/// - **Don't punish a miss**, but reward consistency. A single skipped day
///   shouldn't undo two weeks of work.
/// - **One freeze, automatic.** No premium gate, no in-game currency, no
///   "spend gems to recover".
/// - **Maximum 1 freeze held.** Banking freezes turns the mechanic into a
///   gameable cushion. We want it to feel like a single forgiveness, not
///   a license to skip.
/// - **Rolls forward indefinitely.** If the user used theirs this week, they
///   simply don't have one until next ISO week starts.
///
/// The manager is the source of truth for the **displayed streak** — i.e. the
/// streak the user sees, with freezes applied. Every user-facing streak
/// number (Home status line, Profile stat, streak milestones, achievement
/// progress, retention challenge labels, personal bests) MUST read
/// `currentStreak` here. `PracticeSession.calculateStreak` is the raw
/// history calc and is reserved for model inputs only (baseline pressure
/// classification, NextAction heuristics) — never for a number the user
/// reads, or the streak looks like a bug the first time a freeze fires.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class StreakFreezeManager: ObservableObject {
    static let shared = StreakFreezeManager()

    // MARK: Published

    /// 0 or 1. We never bank more than one.
    @Published private(set) var freezesAvailable: Int = 0

    /// Streak as the user sees it — with freezes applied. Recomputed whenever
    /// PracticeSessionStore changes or `recompute()` is called.
    @Published private(set) var currentStreak: Int = 0

    /// Set true the moment a freeze was just consumed today, for one-shot UI nudge.
    /// Cleared via `consumeFreezeNudge()` after the view renders the message.
    @Published private(set) var freezeJustConsumedToday: Bool = false

    // MARK: Storage

    private let availableKeyPrefix = "noum.streakFreeze.available."
    private let lastEarnedWeekKeyPrefix = "noum.streakFreeze.lastEarnedWeek."
    private let consumedDatesKeyPrefix = "noum.streakFreeze.consumedDates."

    private var lastEarnedWeekKey: String = ""
    private var consumedDates: [Date] = []
    private var sessionsSubscription: AnyCancellable?

    private init() {
        load()
        replenishIfNewWeek()
        recompute()
        observeSessions()
    }

    // MARK: - Account scoping

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private var availableKey: String { availableKeyPrefix + Self.currentAccountID() }
    private var lastEarnedKey: String { lastEarnedWeekKeyPrefix + Self.currentAccountID() }
    private var consumedKey: String { consumedDatesKeyPrefix + Self.currentAccountID() }

    // MARK: - Public API

    func reloadForCurrentAccount() {
        load()
        replenishIfNewWeek()
        recompute()
    }

    /// Marks the freeze-just-consumed nudge as seen.
    func consumeFreezeNudge() {
        freezeJustConsumedToday = false
    }

    /// Recompute `currentStreak`, applying a freeze if today is missed and one
    /// is available. Called automatically when PracticeSessionStore changes;
    /// callable manually after `DailyGoalManager.recordDrillCompletion()` to
    /// reflect drill activity in the streak.
    func recompute() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let sessions = PracticeSessionStore.shared.progressEligibleSessions
        let drillDates = recentDrillDates()

        let practiceDays = Set(
            sessions.map { calendar.startOfDay(for: $0.date) }
                + drillDates.map { calendar.startOfDay(for: $0) }
        )
        let savedDays = Set(consumedDates.map { calendar.startOfDay(for: $0) })

        var cursor = today
        var count = 0
        var freezesUsable = freezesAvailable
        var newlyConsumed = false
        var localConsumedDates = consumedDates

        while true {
            if practiceDays.contains(cursor) || savedDays.contains(cursor) {
                count += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
                continue
            }

            // Missed day. Today's miss can be saved by a freeze iff the user has
            // practiced at least one prior day — we don't gift a streak from zero.
            let priorDay = calendar.date(byAdding: .day, value: -1, to: cursor)
            let hasPriorPractice = priorDay.map { practiceDays.contains($0) || savedDays.contains($0) } ?? false

            if cursor == today && freezesUsable > 0 && hasPriorPractice {
                freezesUsable -= 1
                let already = localConsumedDates.contains(where: { calendar.isDate($0, inSameDayAs: cursor) })
                if !already {
                    localConsumedDates.append(cursor)
                    newlyConsumed = true
                }
                count += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
                continue
            }

            break
        }

        if newlyConsumed {
            freezesAvailable = freezesUsable
            consumedDates = localConsumedDates
            freezeJustConsumedToday = true
            persist()
            CoachHaptic.trendBreakthrough()
        }

        currentStreak = count
        SharedNoumStateMirror.refresh()
        // Lock-screen / home-screen app-icon badge mirrors the streak so
        // the user sees their own number without opening the app. Set to
        // 0 (clears the badge) when streak is 0 so we never advertise a
        // streak that doesn't exist.
        applyAppIconBadge(streak: count)
    }

    /// Best-effort: the modern API requires notification authorization,
    /// so we route through `UNUserNotificationCenter.setBadgeCount` and
    /// silently skip when the user hasn't granted permission. Falls back
    /// to the deprecated `UIApplication` setter on builds that need it.
    private func applyAppIconBadge(streak: Int) {
        #if canImport(UserNotifications)
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                _ = try? await center.setBadgeCount(streak)
            default:
                break
            }
        }
        #endif
    }

    // MARK: - Internals

    private func observeSessions() {
        sessionsSubscription = PracticeSessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
    }

    /// Replenishes the freeze if we've crossed into a new ISO week.
    private func replenishIfNewWeek() {
        let currentWeek = Self.isoWeekKey(for: Date())
        if lastEarnedWeekKey != currentWeek {
            lastEarnedWeekKey = currentWeek
            UserDefaults.standard.set(currentWeek, forKey: lastEarnedKey)
            if freezesAvailable < 1 {
                freezesAvailable = 1
            }
            persist()
        }
    }

    private func recentDrillDates() -> [Date] {
        let key = "noum.dailyGoal.drillCompletions." + Self.currentAccountID()
        guard let data = UserDefaults.standard.data(forKey: key),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else {
            return []
        }
        return dates
    }

    private static func isoWeekKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(comps.yearForWeekOfYear ?? 0)-W\(comps.weekOfYear ?? 0)"
    }

    private func load() {
        let defaults = UserDefaults.standard
        freezesAvailable = max(0, min(1, defaults.integer(forKey: availableKey)))
        lastEarnedWeekKey = defaults.string(forKey: lastEarnedKey) ?? ""

        if let data = defaults.data(forKey: consumedKey),
           let decoded = try? JSONDecoder().decode([Date].self, from: data) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
            consumedDates = decoded.filter { $0 >= cutoff }
        } else {
            consumedDates = []
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(freezesAvailable, forKey: availableKey)
        defaults.set(lastEarnedWeekKey, forKey: lastEarnedKey)
        if let data = try? JSONEncoder().encode(consumedDates) {
            defaults.set(data, forKey: consumedKey)
        }
    }
}
