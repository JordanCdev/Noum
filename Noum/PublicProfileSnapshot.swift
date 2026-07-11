import Foundation

/// Tiny, public-readable subset of a user's profile state. This is the *only*
/// shape that ever gets read by another user — friends pulling each other's
/// stats, league members ranking each other.
///
/// Privacy contract:
/// - `displayName` is the user's account name (already chosen for sharing).
/// - All numeric stats are aggregates; no raw transcripts, no goal text, no
///   recordings.
/// - `accountID` is included so the receiver can confirm provenance and
///   correlate with the friend graph.
///
/// Firestore home: `profiles_public/{accountID}`. Read by anyone signed in;
/// only server-authority callables may write the document.
struct PublicProfileSnapshot: Codable, Equatable, Identifiable, Sendable {
    let accountID: String
    let displayName: String
    let rating: Int
    let peakRating: Int
    let currentStreak: Int
    let weeklyReps: Int
    let weeklyDelta: Int
    let leagueTier: String?
    let updatedAt: Date

    var id: String { accountID }

    /// True when the snapshot is older than the staleness window. Caller
    /// decides what to do with it (show as stale, refetch, hide).
    func isStale(threshold: TimeInterval = 60 * 60 * 24) -> Bool {
        Date().timeIntervalSince(updatedAt) > threshold
    }

    static func empty(accountID: String, displayName: String) -> PublicProfileSnapshot {
        PublicProfileSnapshot(
            accountID: accountID,
            displayName: displayName,
            rating: 400,
            peakRating: 400,
            currentStreak: 0,
            weeklyReps: 0,
            weeklyDelta: 0,
            leagueTier: nil,
            updatedAt: Date()
        )
    }
}
