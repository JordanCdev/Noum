import Foundation

// MARK: - Shared Noum State Mirror
//
// Single function that snapshots the user's daily-rhythm state from the
// authoritative in-app stores and writes it to App Group UserDefaults so
// the widget extension + notification copy + Live Activity can read it.
//
// Called by StreakFreezeManager.recompute(), DailyGoalManager.recordRep(),
// PracticeSessionStore session-add — i.e. anywhere streak / goal / weekly
// reps could change.
//
// `@MainActor` because all the source stores are MainActor-isolated.

#if canImport(SwiftUI)
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 12.0, *)
enum SharedNoumStateMirror {
    /// Async-defers the actual mirror so the call site can be inside a
    /// store's `init` / `recompute()` without re-entering the singleton
    /// dispatch_once that's still running on the same thread. The deferred
    /// closure reads from already-fully-initialised `.shared`s.
    static func refresh() {
        DispatchQueue.main.async {
            performRefresh()
        }
    }

    private static func performRefresh() {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyReps = PracticeSessionStore.shared.sessions
            .filter { $0.date >= weekAgo }
            .count

        let streak = StreakFreezeManager.shared.currentStreak
        let goal = DailyGoalManager.shared.goalReps
        let repsToday = DailyGoalManager.shared.repsToday
        let freezes = StreakFreezeManager.shared.freezesAvailable
        let rating = RatingStore.shared.rating.overall

        let snapshot = SharedNoumState(
            currentStreak: streak,
            repsToday: repsToday,
            goalReps: goal,
            freezesAvailable: freezes,
            weeklyReps: weeklyReps,
            rating: rating,
            updatedAt: Date()
        )
        SharedNoumState.write(snapshot)
    }
}
#endif
