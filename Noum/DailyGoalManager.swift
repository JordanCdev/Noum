import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(Combine)
import Combine
#endif

/// Tracks the user's daily rep target and progress toward it.
///
/// "Rep" here means anything that counts as a piece of speaking practice:
/// - A finalized `PracticeSession` (Timed, Sudden Death, Ah-Counter, IM)
/// - A Cut the Crutch round, recorded directly via `recordDrillCompletion()`
///
/// The goal is per-account, persists across launches, and defaults to 1 rep/day.
/// We deliberately keep the range small (1–3) — speaking practice has a low
/// realistic ceiling, and inflated targets either get ignored or cheapen the rep.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class DailyGoalManager: ObservableObject {
    static let shared = DailyGoalManager()

    // MARK: Published State

    /// User-chosen daily target. Default 1.
    @Published var goalReps: Int {
        didSet {
            let clamped = max(1, min(maxGoalReps, goalReps))
            if clamped != goalReps {
                goalReps = clamped
                return
            }
            persistGoal()
        }
    }

    /// How many reps the user has logged today (sessions + drill completions).
    @Published private(set) var repsToday: Int = 0

    /// Set when the user crosses the goal threshold today, for one-shot celebration.
    /// Consumers clear it via `consumeGoalCelebration()` after rendering.
    @Published private(set) var pendingGoalCelebration: Bool = false

    // MARK: Constants

    let maxGoalReps: Int = 3
    let minGoalReps: Int = 1

    // MARK: Storage

    private let goalKeyPrefix = "noum.dailyGoal.reps."
    private let drillCompletionsKeyPrefix = "noum.dailyGoal.drillCompletions."
    private let lastCelebrationDayKeyPrefix = "noum.dailyGoal.lastCelebrationDay."

    /// Cap on persisted drill completions. Keeps the array small; we only
    /// ever look at "today" so anything older is dead weight.
    private let drillCompletionsCap: Int = 50

    private var drillCompletions: [Date] = []
    private var lastCelebrationDayKey: String = ""
    private var sessionsSubscription: AnyCancellable?

    // MARK: Init

    private init() {
        let stored = UserDefaults.standard.object(forKey: Self.staticGoalKey()) as? Int
        self.goalReps = stored.map { max(1, min(3, $0)) } ?? 1
        loadDrillCompletions()
        loadLastCelebrationDay()
        recompute()
        observeSessionStore()
    }

    // MARK: - Account-aware key resolution

    /// Resolves the per-account UserDefaults key. Falls back to a guest scope
    /// when no account is signed in so the value persists across guest sessions.
    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private static func staticGoalKey() -> String {
        "noum.dailyGoal.reps." + currentAccountID()
    }

    private var goalKey: String { goalKeyPrefix + Self.currentAccountID() }
    private var drillCompletionsKey: String { drillCompletionsKeyPrefix + Self.currentAccountID() }
    private var lastCelebrationKey: String { lastCelebrationDayKeyPrefix + Self.currentAccountID() }

    // MARK: - Public API

    /// Called by Cut the Crutch (and any future drill that should count toward
    /// the daily target). Records a completion at the given date and recomputes.
    func recordDrillCompletion(at date: Date = Date()) {
        drillCompletions.append(date)
        // Trim anything older than 60 days — covers the streak walk window plus
        // a buffer for clock skew. We only ever ask about "today" but a wider
        // window protects the streak calculation.
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        drillCompletions = drillCompletions.filter { $0 >= cutoff }
        if drillCompletions.count > drillCompletionsCap {
            drillCompletions = Array(drillCompletions.suffix(drillCompletionsCap))
        }
        persistDrillCompletions()
        recompute()
        presentCelebrationForCompletedRep(at: date)
        // Drill completions feed the streak too — keep StreakFreezeManager in sync.
        StreakFreezeManager.shared.recompute()
    }

    /// Called by the shared session finalizer after a real speech-backed rep
    /// has been appended. Celebration is tied to this explicit user event,
    /// never to hydration, account reload, or merely returning to Home.
    func recordSessionCompletion(at date: Date) {
        recompute()
        presentCelebrationForCompletedRep(at: date)
    }

    /// Recomputes `repsToday` from PracticeSessionStore + tracked drill completions.
    /// Safe to call as often as needed; idempotent.
    func recompute() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()

        let sessionRepsToday = PracticeSessionStore.shared.sessions
            .filter { $0.date >= todayStart && $0.date < nextDayStart }
            .count

        let drillRepsToday = drillCompletions
            .filter { $0 >= todayStart && $0 < nextDayStart }
            .count

        let total = sessionRepsToday + drillRepsToday
        repsToday = total

        // Mirror to App Group so the widget + notifications can read it.
        SharedNoumStateMirror.refresh()
    }

    /// View calls this once after rendering the celebration so it doesn't fire again.
    func consumeGoalCelebration() {
        pendingGoalCelebration = false
    }

    /// Called when account state changes — wipes per-account derived state and
    /// re-reads. Mirrors the lifecycle hooks used by other stores.
    func reloadForCurrentAccount() {
        let stored = UserDefaults.standard.object(forKey: goalKey) as? Int
        goalReps = stored.map { max(minGoalReps, min(maxGoalReps, $0)) } ?? minGoalReps
        loadDrillCompletions()
        loadLastCelebrationDay()
        recompute()
    }

    // MARK: - Derived

    var progress: Double {
        guard goalReps > 0 else { return 0 }
        return min(1.0, Double(repsToday) / Double(goalReps))
    }

    var hasReachedGoal: Bool {
        repsToday >= goalReps
    }

    var statusLabel: String {
        if hasReachedGoal {
            return "Today's done"
        }
        return "\(repsToday) of \(goalReps) today"
    }

    // MARK: - Private

    private func observeSessionStore() {
        sessionsSubscription = PracticeSessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
    }

    private func presentCelebrationForCompletedRep(at date: Date) {
        let calendar = Calendar.current
        let todayKey = dayKeyString(for: Date(), calendar: calendar)
        let completionDayKey = dayKeyString(for: date, calendar: calendar)
        guard DailyGoalCelebrationPolicy.shouldPresent(
            source: .completedRep,
            completionDayKey: completionDayKey,
            todayKey: todayKey,
            repsToday: repsToday,
            goalReps: goalReps,
            lastCelebrationDayKey: lastCelebrationDayKey
        ) else { return }
        lastCelebrationDayKey = todayKey
        UserDefaults.standard.set(todayKey, forKey: lastCelebrationKey)
        pendingGoalCelebration = true
        CoachHaptic.skillLevelUp()
    }

    private func dayKeyString(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func persistGoal() {
        UserDefaults.standard.set(goalReps, forKey: goalKey)
    }

    private func loadDrillCompletions() {
        guard let data = UserDefaults.standard.data(forKey: drillCompletionsKey),
              let decoded = try? JSONDecoder().decode([Date].self, from: data) else {
            drillCompletions = []
            return
        }
        drillCompletions = decoded
    }

    private func persistDrillCompletions() {
        guard let data = try? JSONEncoder().encode(drillCompletions) else { return }
        UserDefaults.standard.set(data, forKey: drillCompletionsKey)
    }

    private func loadLastCelebrationDay() {
        lastCelebrationDayKey = UserDefaults.standard.string(forKey: lastCelebrationKey) ?? ""
    }
}

enum DailyGoalCelebrationSource: Equatable {
    case hydration
    case completedRep
}

/// Pure event gate for the daily-goal acknowledgement. A stored session may
/// make today's goal true during launch hydration, but only a rep completed in
/// the active user flow is allowed to present an interruption.
enum DailyGoalCelebrationPolicy {
    static func shouldPresent(
        source: DailyGoalCelebrationSource,
        completionDayKey: String,
        todayKey: String,
        repsToday: Int,
        goalReps: Int,
        lastCelebrationDayKey: String
    ) -> Bool {
        source == .completedRep
            && completionDayKey == todayKey
            && repsToday >= goalReps
            && lastCelebrationDayKey != todayKey
    }
}
