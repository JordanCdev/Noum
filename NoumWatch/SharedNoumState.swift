import Foundation

// MARK: - Shared Noum State (App Group mirror)
//
// Watch-side copy of the iPhone app's snapshot reader. Same shape, same
// suite name, same key — the watch reads what the phone has written
// (or stale `.empty` until the phone has been opened at least once
// after install).
//
// Mirrors `Noum/SharedNoumState.swift` exactly so the watch stays in
// lock-step with the iOS app's daily-rhythm contract: streak, reps
// today, goal, freezes, weekly reps, rating, updated-at.
//
// Pure value type. No writes happen on the watch — the watch is a
// glance surface only; authoritative writes still come from the iOS
// app's StreakFreezeManager / DailyGoalManager / PracticeSessionStore.

struct SharedNoumState: Codable, Equatable {
    /// Streak the user actually sees on home (freezes applied).
    let currentStreak: Int
    /// Reps logged today (sessions + drill completions).
    let repsToday: Int
    /// User's daily target (1–3).
    let goalReps: Int
    /// 0 or 1.
    let freezesAvailable: Int
    /// Reps in the trailing 7 days.
    let weeklyReps: Int
    /// Latest rating value (100–1000).
    let rating: Int
    /// Last-updated timestamp. Drives "stale" badging on the glance.
    let updatedAt: Date

    static let empty = SharedNoumState(
        currentStreak: 0,
        repsToday: 0,
        goalReps: 1,
        freezesAvailable: 0,
        weeklyReps: 0,
        rating: 400,
        updatedAt: .distantPast
    )

    // MARK: - App Group plumbing

    /// Stable suite name. Must match the iOS app + widget extension
    /// exactly, otherwise the watch will only ever see `.empty`.
    static let appGroupID = "group.com.jordancoaten.noum"

    private static let storageKey = "noum.sharedState.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Read

    /// Read the latest snapshot. Always returns a value — `.empty` if
    /// nothing has been written yet (first install, or before the iOS
    /// app has run once).
    static func read() -> SharedNoumState {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SharedNoumState.self, from: data) else {
            return .empty
        }
        return decoded
    }
}
