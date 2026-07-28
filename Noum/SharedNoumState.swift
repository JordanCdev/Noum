import Foundation

// MARK: - Shared Noum State (App Group mirror)
//
// Tiny snapshot of the user's daily-rhythm state — streak, reps today,
// goal, freezes, weekly reps — that lives in App Group UserDefaults so
// that:
//  - the **widget extension** can render the lock-screen surface without
//    a full app launch,
//  - **notification copy** can pull the user's actual numbers when it
//    fires (neutral evening rhythm copy that names the real streak count),
//  - **Live Activity** has a stable read source for "session in progress".
//
// Pure value type — no @Published, no actor. Read by writing the whole
// snapshot at once, atomically, whenever an authoritative source updates
// (StreakFreezeManager, DailyGoalManager, PracticeSessionStore).
//
// **App Group setup**: the entitlement key is `group.uk.co.otherpath.noum`.
// The main app needs `com.apple.security.application-groups` set to that
// value, and so does the widget extension. Until both are in place, the
// `SharedNoumState` writes fall back to the app's standard UserDefaults
// transparently — the app keeps working, the widget just sees stale data.

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
    /// Last-updated timestamp. Drives "stale" badging on the widget.
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

    /// Stable suite name. The widget extension reads from the same suite.
    /// If the App Group entitlement isn't present (e.g. simulator with
    /// no entitlements yet), `UserDefaults(suiteName:)` returns nil; we
    /// fall through to `.standard` so the app stays functional.
    static let appGroupID = "group.uk.co.otherpath.noum"

    private static let storageKey = "noum.sharedState.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Read / write

    /// Read the latest snapshot. Always returns a value — `.empty` if
    /// nothing has been written yet.
    static func read() -> SharedNoumState {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(SharedNoumState.self, from: data) else {
            return .empty
        }
        return decoded
    }

    /// Write a fresh snapshot. Idempotent — no diffing, the snapshot is
    /// small enough that a full overwrite is cheap.
    static func write(_ snapshot: SharedNoumState) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
