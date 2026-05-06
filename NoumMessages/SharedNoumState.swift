import Foundation

// MARK: - Shared Noum State (App Group mirror)
//
// Duplicate copy compiled into the iMessage app extension. The main app
// owns the canonical struct in `Noum/Noum/SharedNoumState.swift`. Keep
// the shape identical: the App Group + storage key are the contract
// between writer (app) and reader (extension).
//
// The iMessage extension is read-only — it only renders the current
// snapshot into a "challenge a friend" card.

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
    /// Last-updated timestamp.
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

    static let appGroupID = "group.com.jordancoaten.noum"

    private static let storageKey = "noum.sharedState.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Read the latest snapshot. Always returns a value — `.empty` if
    /// nothing has been written yet.
    static func read() -> SharedNoumState {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SharedNoumState.self, from: data) else {
            return .empty
        }
        return decoded
    }
}
