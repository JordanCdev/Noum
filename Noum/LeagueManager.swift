import Foundation
import Combine
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - League tier

/// Speaking-rating tier. Membership is derived from rating, not earned by
/// rank within a league — rating moves continuously with practice, so a
/// week's worth of climbing naturally promotes you. Vision says "climbing
/// a rung at week's end"; in practice that rung is your rating delta over
/// the week, surfaced via `LeagueManager.weeklyDelta`.
enum LeagueTier: String, CaseIterable, Codable, Identifiable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bronze:   return "Bronze"
        case .silver:   return "Silver"
        case .gold:     return "Gold"
        case .platinum: return "Platinum"
        case .diamond:  return "Diamond"
        }
    }

    var ratingFloor: Int {
        switch self {
        case .bronze:   return 100
        case .silver:   return 300
        case .gold:     return 500
        case .platinum: return 700
        case .diamond:  return 850
        }
    }

    var ratingCeiling: Int {
        switch self {
        case .bronze:   return 299
        case .silver:   return 499
        case .gold:     return 699
        case .platinum: return 849
        case .diamond:  return 1000
        }
    }

    var nextTier: LeagueTier? {
        switch self {
        case .bronze:   return .silver
        case .silver:   return .gold
        case .gold:     return .platinum
        case .platinum: return .diamond
        case .diamond:  return nil
        }
    }

    /// Brand-significant tier tint. Used on profile, league, and any rank
    /// surface where the tier needs to read at a glance.
    #if canImport(SwiftUI)
    var tint: Color {
        switch self {
        case .bronze:   return Color(red: 0.65, green: 0.42, blue: 0.20)
        case .silver:   return Color(red: 0.60, green: 0.62, blue: 0.66)
        case .gold:     return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .platinum: return Color(red: 0.39, green: 0.55, blue: 0.78)
        case .diamond:  return Color(red: 0.36, green: 0.78, blue: 0.78)
        }
    }
    #endif

    static func tier(for rating: Int) -> LeagueTier {
        switch rating {
        case ..<300:    return .bronze
        case 300..<500: return .silver
        case 500..<700: return .gold
        case 700..<850: return .platinum
        default:        return .diamond
        }
    }
}

// MARK: - Tier Promotion

/// Captures a tier-up event so the home screen can celebrate it on next
/// open. Codable so it survives across launches — a rating bump
/// mid-session shouldn't get swallowed by a sudden app close.
struct TierPromotion: Codable, Equatable, Identifiable {
    let previousTier: LeagueTier
    let newTier: LeagueTier
    let date: Date

    /// The new tier's raw value is enough to identify the event for
    /// SwiftUI's `fullScreenCover(item:)` — only one promotion is
    /// pending at a time per account.
    var id: String { newTier.rawValue }
}

// MARK: - League Manager

#if canImport(SwiftUI)

/// Owns the user's weekly league state. The bucket is derived from
/// `(tier, ISO-week)` so every user in the same tier+week sees the same
/// peer list — no server-side matching needed.
///
/// Sync responsibility:
/// - When the user's rating, streak, or weekly reps change, write a public
///   profile snapshot AND a league member doc for the current bucket.
/// - When the league view is shown (or pull-to-refresh), fetch the top 20
///   members of the current bucket.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class LeagueManager: ObservableObject {
    static let shared = LeagueManager()

    @Published private(set) var members: [PublicProfileSnapshot] = []
    @Published private(set) var tier: LeagueTier = .bronze
    @Published private(set) var bucketKey: String = ""
    @Published private(set) var lastFetchedAt: Date?
    @Published private(set) var isLoading: Bool = false
    /// Tier-promotion event waiting to be celebrated. Set when the user's
    /// rating crosses up into a new tier; cleared once the home screen
    /// has shown the celebration overlay. Persisted across launches so a
    /// promotion mid-session shows on next app open, not silently.
    @Published var pendingPromotion: TierPromotion?

    private let lastSeenTierKey = "league.lastSeenTier"
    private let lastSeenTierInitializedKey = "league.lastSeenTierInitialized"
    private let pendingPromotionKey = "league.pendingPromotion"

    private static let refreshThrottle: TimeInterval = 60
    private var lastFetchAttempt: Date?
    private var sessionsSubscription: AnyCancellable?
    private var ratingSubscription: AnyCancellable?

    private init() {
        loadPendingPromotion()
        recomputeTierAndBucket()
        observeStateChanges()
    }

    // MARK: - Public API

    /// Recompute the tier/bucket from the current rating. Called when the
    /// user's rating changes or a new ISO week starts. Detects upward
    /// tier crossings and queues a promotion celebration.
    func recomputeTierAndBucket() {
        let newTier = LeagueTier.tier(for: RatingStore.shared.rating.overall)
        let newBucket = Self.bucketKey(for: newTier, on: Date())
        let bucketChanged = newBucket != bucketKey

        // First-ever launch: stamp the user's current tier without
        // queuing a celebration. Otherwise every new install with a
        // mid-tier seeded rating would trigger "Promoted to Silver" on
        // open, which is a lie (they didn't earn it just now).
        if !UserDefaults.standard.bool(forKey: lastSeenTierInitializedKey) {
            persistLastSeenTier(newTier)
            UserDefaults.standard.set(true, forKey: lastSeenTierInitializedKey)
        } else {
            // Detect promotion: only fire on upward crossings, never on
            // demotion (downward changes happen quietly so we don't
            // shame a user whose rating dipped).
            let lastSeen = lastSeenTier()
            if newTier.ratingFloor > lastSeen.ratingFloor {
                queuePromotion(from: lastSeen, to: newTier)
            }
            persistLastSeenTier(newTier)
        }

        tier = newTier
        bucketKey = newBucket
        if bucketChanged {
            members = []
            lastFetchedAt = nil
        }
    }

    /// Mark the pending promotion as consumed. Called by the home screen
    /// once the celebration overlay has been shown and dismissed.
    func consumePendingPromotion() {
        pendingPromotion = nil
        UserDefaults.standard.removeObject(forKey: pendingPromotionKey)
    }

    #if DEBUG
    /// Stamp the current tier as last-seen and clear any queued promotion
    /// without triggering a celebration. Used by the screenshot tour after
    /// seed injection so the promotion overlay doesn't cover Home on every
    /// fresh launch (the seed's rating change crosses tiers vs. baseline).
    func suppressCelebrationsForTesting() {
        pendingPromotion = nil
        UserDefaults.standard.removeObject(forKey: pendingPromotionKey)
        persistLastSeenTier(tier)
        UserDefaults.standard.set(true, forKey: lastSeenTierInitializedKey)
    }
    #endif

    private func queuePromotion(from previous: LeagueTier, to next: LeagueTier) {
        let promotion = TierPromotion(previousTier: previous, newTier: next, date: Date())
        pendingPromotion = promotion
        if let data = try? JSONEncoder().encode(promotion) {
            UserDefaults.standard.set(data, forKey: pendingPromotionKey)
        }
    }

    private func lastSeenTier() -> LeagueTier {
        guard let raw = UserDefaults.standard.string(forKey: lastSeenTierKey),
              let tier = LeagueTier(rawValue: raw) else {
            return .bronze
        }
        return tier
    }

    private func persistLastSeenTier(_ tier: LeagueTier) {
        UserDefaults.standard.set(tier.rawValue, forKey: lastSeenTierKey)
    }

    private func loadPendingPromotion() {
        guard let data = UserDefaults.standard.data(forKey: pendingPromotionKey),
              let promotion = try? JSONDecoder().decode(TierPromotion.self, from: data) else {
            return
        }
        pendingPromotion = promotion
    }

    /// Write the user's membership in the current bucket. Caller passes in
    /// the public-profile snapshot so we don't duplicate "what fields go
    /// public" logic — `PublicProfileBuilder` is the single source.
    func syncSelf(snapshot: PublicProfileSnapshot) async {
        recomputeTierAndBucket()
        guard !bucketKey.isEmpty else { return }
        await BackendSyncManager.shared.syncLeagueMember(snapshot: snapshot, bucket: bucketKey)
    }

    /// Refresh the visible top-20 of the current bucket. Throttled.
    /// `force: true` bypasses the throttle (pull-to-refresh).
    func refreshMembers(force: Bool = false) async {
        if !force, let last = lastFetchAttempt,
           Date().timeIntervalSince(last) < Self.refreshThrottle { return }
        recomputeTierAndBucket()
        guard !bucketKey.isEmpty else { return }
        lastFetchAttempt = Date()
        isLoading = true
        defer { isLoading = false }
        let fetched = await BackendSyncManager.shared.fetchLeagueMembers(bucket: bucketKey, limit: 20)
        members = fetched
        lastFetchedAt = Date()
    }

    /// User's position within the visible bucket members (1-indexed).
    /// Returns nil if the user isn't in the snapshot — happens before first
    /// sync or if the bucket has no members yet.
    func currentRank(accountID: String) -> Int? {
        guard let index = members.firstIndex(where: { $0.accountID == accountID }) else { return nil }
        return index + 1
    }

    /// Time interval until the current ISO week ends (next Monday 00:00 local).
    /// Used in the "league resets in X" copy.
    var timeUntilReset: TimeInterval {
        Self.endOfWeek(from: Date()).timeIntervalSince(Date())
    }

    /// Human label like "Resets in 3 days" / "Resets tomorrow" / "Resets today".
    var resetCopy: String {
        let interval = timeUntilReset
        let days = Int(interval / 86_400)
        if days >= 2 { return "Resets in \(days) days" }
        if days == 1 { return "Resets tomorrow" }
        let hours = max(0, Int(interval / 3_600))
        if hours >= 2 { return "Resets in \(hours) hours" }
        return "Resets today"
    }

    /// Rating headroom to next tier. Nil if at the top.
    var ratingToNextTier: Int? {
        guard let next = tier.nextTier else { return nil }
        return max(0, next.ratingFloor - RatingStore.shared.rating.overall)
    }

    // MARK: - Internals

    private func observeStateChanges() {
        // Re-evaluate tier when the user's rating changes during a session.
        ratingSubscription = RatingStore.shared.$rating
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recomputeTierAndBucket() }
        sessionsSubscription = PracticeSessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recomputeTierAndBucket() }
    }

    static func bucketKey(for tier: LeagueTier, on date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let week = String(format: "W%02d", comps.weekOfYear ?? 0)
        let year = comps.yearForWeekOfYear ?? 0
        return "\(tier.rawValue)_\(year)-\(week)"
    }

    static func endOfWeek(from date: Date) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        guard
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date)
        else {
            return date.addingTimeInterval(86_400)
        }
        return weekInterval.end
    }
}

// MARK: - Public profile builder

/// Pure function: pulls the current user's stats into a public snapshot
/// suitable for `profiles_public/{accountID}` and league member docs.
/// Lives outside the manager so the same shape can be assembled from
/// `SessionFinalizer` without going through any singleton.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
enum PublicProfileBuilder {
    static func build(accountID: String, displayName: String) -> PublicProfileSnapshot {
        let rating = RatingStore.shared.rating
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyReps = PracticeSessionStore.shared.sessions.filter { $0.date >= weekAgo }.count
        let streak = StreakFreezeManager.shared.currentStreak
        let tier = LeagueTier.tier(for: rating.overall)

        return PublicProfileSnapshot(
            accountID: accountID,
            displayName: displayName,
            rating: rating.overall,
            peakRating: rating.peakRating,
            currentStreak: streak,
            weeklyReps: weeklyReps,
            weeklyDelta: rating.weeklyDelta,
            leagueTier: tier.rawValue,
            updatedAt: Date()
        )
    }
}

#endif
