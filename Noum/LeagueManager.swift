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
enum LeagueTier: String, CaseIterable, Codable, Identifiable, Sendable {
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

enum LeaguePlacementPresentation {
    static func title(tier: LeagueTier, rating: SpeakingRating) -> String {
        rating.hasRatedEvidence ? "\(tier.title) peer group" : "Peer comparison pending"
    }

    static func tierTitle(tier: LeagueTier, rating: SpeakingRating) -> String {
        rating.hasRatedEvidence ? tier.title : "Placement pending"
    }

    static func subtitle(tier: LeagueTier, rating: SpeakingRating) -> String {
        guard rating.hasRatedEvidence else {
            return "One rated rep creates a fair comparison baseline."
        }
        if let next = tier.nextTier {
            let toNext = max(0, next.ratingFloor - rating.overall)
            return "\(toNext) rating points to \(next.title)."
        }
        return "You are in the highest comparison group."
    }

    static func fullScreenSubtitle(tier: LeagueTier, rating: SpeakingRating) -> String {
        guard rating.hasRatedEvidence else {
            return "Complete one rated rep first. Your peer comparison will then use real rating evidence."
        }
        if let next = tier.nextTier {
            let toNext = max(0, next.ratingFloor - rating.overall)
            return "\(toNext) rating points to \(next.title)."
        }
        return "You are in the highest comparison group."
    }

    static func ratingValue(for rating: SpeakingRating) -> String {
        rating.hasRatedEvidence ? "\(rating.overall)" : "—"
    }
}

enum LeagueActivityPresentation {
    static func weeklyActivityValue(sessionCount: Int, dailyChallengeClaims: Int) -> String {
        if sessionCount > 0 {
            return "\(sessionCount) rep\(sessionCount == 1 ? "" : "s")"
        }
        if dailyChallengeClaims > 0 {
            return dailyChallengeClaims == 1 ? "1 daily" : "\(dailyChallengeClaims) dailies"
        }
        return "—"
    }

    static func weeklySessionCount(from sessions: [PracticeSession], now: Date, calendar: Calendar = isoCalendar()) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessions.filter { week.contains($0.date) }.count
    }

    private static func isoCalendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        return calendar
    }
}

// MARK: - Tier Promotion

/// Captures a tier-up event so the home screen can celebrate it on next
/// open. Codable so it survives across launches — a rating bump
/// mid-session shouldn't get swallowed by a sudden app close.
struct TierPromotion: Codable, Equatable, Identifiable, Sendable {
    let previousTier: LeagueTier
    let newTier: LeagueTier
    let date: Date

    /// The new tier's raw value is enough to identify the event for
    /// SwiftUI's `fullScreenCover(item:)` — only one promotion is
    /// pending at a time per account.
    var id: String { newTier.rawValue }
}

/// A peer/public rating that disagrees with the on-device coaching rating is
/// evidence of a reconciliation problem, not permission to overwrite either
/// side silently. Social views use the server envelope; coaching continues to
/// use `RatingStore` until an explicit migration is designed.
struct PeerRatingDivergence: Equatable, Sendable {
    let localRating: Int
    let serverRating: Int
    let observedAt: Date
}

struct PeerSessionSyncFailure: Equatable, Identifiable, Sendable {
    let sessionID: UUID
    let message: String
    let isRetryable: Bool

    var id: UUID { sessionID }
}

/// Account-owned league state included in export and deletion parity.
/// Transient peer rows and callable errors are intentionally absent; they are
/// server reads, not durable local user data.
struct LeagueAccountDataSnapshot: Codable, Equatable, Sendable {
    let lastSeenTier: LeagueTier?
    let lastSeenTierInitialized: Bool
    let pendingPromotion: TierPromotion?
    let dailyChallengeISOWeek: String?
    let dailyChallengeCompletions: Int
}

// MARK: - League Manager

#if canImport(SwiftUI)

/// Owns the user's weekly league state. The bucket is derived from
/// `(tier, ISO-week)` so every user in the same tier+week sees the same
/// peer list — no server-side matching needed.
///
/// Sync responsibility:
/// - Reconcile the server-authored public profile returned after a real rep.
/// - When the league view is shown (or pull-to-refresh), fetch the top 20
///   members of the server-authorized current bucket.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class LeagueManager: ObservableObject {
    static let shared = LeagueManager()

    @Published private(set) var members: [PublicProfileSnapshot] = []
    @Published private(set) var tier: LeagueTier = .bronze
    @Published private(set) var bucketKey: String = ""
    @Published private(set) var lastFetchedAt: Date?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var authoritativeSelfProfile: PublicProfileSnapshot?
    @Published private(set) var ratingDivergence: PeerRatingDivergence?
    @Published private(set) var peerSyncFailure: PeerSessionSyncFailure?
    @Published private(set) var isRetryingPeerSync: Bool = false
    /// Tier-promotion event waiting to be celebrated. Set when the user's
    /// rating crosses up into a new tier; cleared once the home screen
    /// has shown the celebration overlay. Persisted across launches so a
    /// promotion mid-session shows on next app open, not silently.
    @Published var pendingPromotion: TierPromotion?

    /// Daily-challenge claims inside the current ISO week. Bumped by
    /// `recordDailyChallengeCompletion(_:)` whenever the user claims a
    /// daily challenge. Surfaces can read this alongside the
    /// session-derived `weeklyReps` to show a complete picture of the
    /// user's weekly activity; persisted per-account and zeroed on the
    /// week boundary so an old week's count never carries over.
    @Published private(set) var weeklyDailyChallengeCompletions: Int = 0

    nonisolated static let lastSeenTierKey = "league.lastSeenTier"
    nonisolated static let lastSeenTierInitializedKey = "league.lastSeenTierInitialized"
    nonisolated static let pendingPromotionKey = "league.pendingPromotion"
    nonisolated static let dailyChallengeWeekKey = "league.dailyChallenges.isoWeek"
    nonisolated static let dailyChallengeCountKey = "league.dailyChallenges.count"

    nonisolated static let accountDataKeyBases = [
        lastSeenTierKey,
        lastSeenTierInitializedKey,
        pendingPromotionKey,
        dailyChallengeWeekKey,
        dailyChallengeCountKey,
    ]

    private static let refreshThrottle: TimeInterval = 60
    private var lastFetchAttempt: Date?
    private var sessionsSubscription: AnyCancellable?
    private var ratingSubscription: AnyCancellable?
    private var isSessionActive = true
    private var activeAccountID: String?
    private var accountGeneration: UInt64 = 0

    private init() {
        activeAccountID = Self.persistedAccountID
        Self.migrateLegacyDataIfNeeded(
            accountID: activeAccountID ?? "guest",
            defaults: .standard
        )
        loadPendingPromotion()
        loadWeeklyDailyChallengeCompletions()
        recomputeTierAndBucket()
        observeStateChanges()
    }

    // MARK: - Public API

    /// Pure promotion-celebration predicate (unit-testable without RatingStore /
    /// UserDefaults / the rest of the manager). A promotion celebration may fire
    /// ONLY when:
    ///   - the last-seen tier has been initialized (NOT first launch — a fresh
    ///     install with a seeded mid-tier rating must never claim an unearned
    ///     "Promoted to Silver" on open), AND
    ///   - the rating carries real rated evidence (no celebration off the
    ///     default placeholder rating), AND
    ///   - the new tier is strictly ABOVE the last-seen tier (a rating dip
    ///     re-tiers silently — never shame a regression).
    /// This is the single source of truth for the league_promotion_guard
    /// invariant; `recomputeTierAndBucket` defers to it.
    nonisolated static func shouldCelebratePromotion(
        isInitialized: Bool,
        hasRatedEvidence: Bool,
        lastSeenFloor: Int,
        newFloor: Int
    ) -> Bool {
        isInitialized && hasRatedEvidence && newFloor > lastSeenFloor
    }

    /// Deterministic account key used by lifecycle, export, deletion, and the
    /// account-data registry. Keeping it testable avoids exercising the
    /// process-wide singleton or Keychain in isolation tests.
    nonisolated static func accountKey(base: String, accountID: String) -> String {
        "\(base).\(accountID)"
    }

    /// Claims the five pre-registry global values for the first real account
    /// that loads them. Existing scoped values win; legacy values are still
    /// removed so they cannot migrate into a later account.
    @discardableResult
    nonisolated static func migrateLegacyDataIfNeeded(
        accountID: String,
        defaults: UserDefaults
    ) -> Set<String> {
        guard !accountID.isEmpty, accountID != "guest" else { return [] }
        var removedLegacyKeys: Set<String> = []
        for base in accountDataKeyBases {
            guard let legacyValue = defaults.object(forKey: base) else { continue }
            let target = accountKey(base: base, accountID: accountID)
            if defaults.object(forKey: target) == nil {
                defaults.set(legacyValue, forKey: target)
            }
            defaults.removeObject(forKey: base)
            removedLegacyKeys.insert(base)
        }
        return removedLegacyKeys
    }

    /// Pure defaults-backed snapshot loader used by export and focused tests.
    /// It never falls back to another account or to the old global keys.
    nonisolated static func persistedSnapshot(
        for accountID: String,
        defaults: UserDefaults
    ) -> LeagueAccountDataSnapshot {
        func key(_ base: String) -> String {
            accountKey(base: base, accountID: accountID)
        }

        let tier = defaults.string(forKey: key(lastSeenTierKey))
            .flatMap(LeagueTier.init(rawValue:))
        let promotion = defaults.data(forKey: key(pendingPromotionKey))
            .flatMap { try? JSONDecoder().decode(TierPromotion.self, from: $0) }
        return LeagueAccountDataSnapshot(
            lastSeenTier: tier,
            lastSeenTierInitialized: defaults.bool(forKey: key(lastSeenTierInitializedKey)),
            pendingPromotion: promotion,
            dailyChallengeISOWeek: defaults.string(forKey: key(dailyChallengeWeekKey)),
            dailyChallengeCompletions: max(0, defaults.integer(forKey: key(dailyChallengeCountKey)))
        )
    }

    nonisolated static func deletePersistedData(
        for accountID: String,
        defaults: UserDefaults
    ) {
        for base in accountDataKeyBases {
            defaults.removeObject(forKey: accountKey(base: base, accountID: accountID))
        }
    }

    /// Recompute the tier/bucket from the current rating. Called when the
    /// user's rating changes or a new ISO week starts. Detects upward
    /// tier crossings and queues a promotion celebration.
    func recomputeTierAndBucket() {
        guard isSessionActive, let activeAccountID else { return }
        let rating = RatingStore.shared.rating
        let localTier = LeagueTier.tier(for: rating.overall)

        // Drop an envelope from a prior signed-in account before deriving any
        // social bucket. Account switches must never display the previous
        // user's server-authored placement.
        if let profile = authoritativeSelfProfile,
           profile.accountID != activeAccountID {
            authoritativeSelfProfile = nil
            ratingDivergence = nil
            peerSyncFailure = nil
        }

        let authoritativeTier = authoritativeSelfProfile?.leagueTier
            .flatMap(LeagueTier.init(rawValue:))
        let newTier = authoritativeTier ?? localTier
        // Without a server envelope, keep the local coaching tier available
        // for non-social presentation but do not issue a peer query derived
        // from client-authored rating state.
        let newBucket: String = {
            guard let authoritativeTier,
                  let profile = authoritativeSelfProfile,
                  Self.isoWeekKey(for: profile.updatedAt) == Self.isoWeekKey(for: Date()) else {
                return ""
            }
            return Self.bucketKey(for: authoritativeTier, on: profile.updatedAt)
        }()
        let bucketChanged = newBucket != bucketKey

        // First-ever launch: stamp the user's current tier without
        // queuing a celebration. Otherwise every new install with a
        // mid-tier seeded rating would trigger "Promoted to Silver" on
        // open, which is a lie (they didn't earn it just now).
        if !UserDefaults.standard.bool(forKey: scopedKey(Self.lastSeenTierInitializedKey)) {
            persistLastSeenTier(localTier)
            UserDefaults.standard.set(true, forKey: scopedKey(Self.lastSeenTierInitializedKey))
        } else if rating.hasRatedEvidence {
            // Detect promotion: only fire on upward crossings, never on
            // demotion (downward changes happen quietly so we don't
            // shame a user whose rating dipped).
            let lastSeen = lastSeenTier()
            if Self.shouldCelebratePromotion(
                isInitialized: true,
                hasRatedEvidence: rating.hasRatedEvidence,
                lastSeenFloor: lastSeen.ratingFloor,
                newFloor: localTier.ratingFloor
            ) {
                queuePromotion(from: lastSeen, to: localTier)
            }
            persistLastSeenTier(localTier)
        } else {
            // The visible UI says placement is pending, so the state owner
            // must also avoid silently treating the default 400 as an earned
            // weekly bucket. Keep the last-seen tier stamped for future
            // promotion comparisons, but do not join or fetch a bucket yet.
            persistLastSeenTier(localTier)
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
        guard isSessionActive, activeAccountID != nil else { return }
        pendingPromotion = nil
        UserDefaults.standard.removeObject(forKey: scopedKey(Self.pendingPromotionKey))
    }

    /// Record that the user claimed a daily challenge. Counts toward the
    /// current ISO week's daily-challenge tally so a user who engages with
    /// the daily rhythm — even without running a full rated session —
    /// shows up as active in their league. Auto-resets on the week
    /// boundary; no manual rollover needed.
    ///
    /// Intentionally NOT a rating mutator: daily challenges are
    /// supplemental engagement, not a backdoor for rating climb. The
    /// rating bump pathway stays inside `RatingStore.recordRatedSession`
    /// so the climb still represents real rated reps. The weekly counter
    /// is a presence signal for league surfaces.
    func recordDailyChallengeCompletion(_ kind: DailyChallengeKind) {
        guard isSessionActive, activeAccountID != nil else { return }
        let nowWeekKey = Self.isoWeekKey(for: Date())
        let storedWeek = UserDefaults.standard.string(
            forKey: scopedKey(Self.dailyChallengeWeekKey)
        ) ?? ""
        if storedWeek != nowWeekKey {
            // New week — zero the counter before adding this claim.
            UserDefaults.standard.set(
                nowWeekKey,
                forKey: scopedKey(Self.dailyChallengeWeekKey)
            )
            weeklyDailyChallengeCompletions = 0
        }
        weeklyDailyChallengeCompletions += 1
        UserDefaults.standard.set(
            weeklyDailyChallengeCompletions,
            forKey: scopedKey(Self.dailyChallengeCountKey)
        )

        // Trigger a tier+bucket recompute so any rating mutation that
        // landed alongside this claim (rating store updates ripple to
        // this manager via the subscription, but we keep the
        // recompute synchronous so the next read is always fresh).
        recomputeTierAndBucket()

        _ = kind  // reserved for future kind-specific weighting; the
                  // counter today treats all kinds as one engagement
                  // unit because the league signal is presence, not
                  // difficulty-of-claim.
    }

    /// Reload every account-owned league value after AuthManager has switched
    /// the Keychain account ID. Transient server reads are cleared first so
    /// neither persisted nor in-memory state can cross the account boundary.
    func reloadForCurrentAccount() {
        let accountID = Self.persistedAccountID
        Self.migrateLegacyDataIfNeeded(accountID: accountID, defaults: .standard)
        clearTransientState()
        accountGeneration &+= 1
        activeAccountID = accountID
        isSessionActive = true
        loadPendingPromotion()
        loadWeeklyDailyChallengeCompletions()
        recomputeTierAndBucket()
    }

    /// Clear in-memory state without writing defaults. The inactive guard
    /// prevents RatingStore/PracticeSessionStore publisher emissions during an
    /// account switch from recreating old-account values after teardown.
    func endSession() {
        accountGeneration &+= 1
        isSessionActive = false
        activeAccountID = nil
        clearTransientState()
        tier = .bronze
        bucketKey = ""
        pendingPromotion = nil
        weeklyDailyChallengeCompletions = 0
    }

    func exportSnapshot(for accountID: String) -> LeagueAccountDataSnapshot {
        Self.persistedSnapshot(for: accountID, defaults: .standard)
    }

    func deleteAllData(for accountID: String) {
        Self.deletePersistedData(for: accountID, defaults: .standard)
        if Self.persistedAccountID == accountID {
            endSession()
        }
    }

    /// Compatibility entry point for the daily challenge owner. Full account
    /// switches should use `reloadForCurrentAccount()` through the registry.
    func reloadDailyChallengeCompletionsForCurrentAccount() {
        loadWeeklyDailyChallengeCompletions()
    }

    #if DEBUG
    /// Stamp the current tier as last-seen and clear any queued promotion
    /// without triggering a celebration. Used by the screenshot tour after
    /// seed injection so the promotion overlay doesn't cover Home on every
    /// fresh launch (the seed's rating change crosses tiers vs. baseline).
    func suppressCelebrationsForTesting() {
        guard isSessionActive, activeAccountID != nil else { return }
        pendingPromotion = nil
        UserDefaults.standard.removeObject(forKey: scopedKey(Self.pendingPromotionKey))
        persistLastSeenTier(tier)
        UserDefaults.standard.set(
            true,
            forKey: scopedKey(Self.lastSeenTierInitializedKey)
        )
    }
    #endif

    private func queuePromotion(from previous: LeagueTier, to next: LeagueTier) {
        let promotion = TierPromotion(previousTier: previous, newTier: next, date: Date())
        pendingPromotion = promotion
        if let data = try? JSONEncoder().encode(promotion) {
            UserDefaults.standard.set(data, forKey: scopedKey(Self.pendingPromotionKey))
        }
    }

    private func lastSeenTier() -> LeagueTier {
        guard let raw = UserDefaults.standard.string(
            forKey: scopedKey(Self.lastSeenTierKey)
        ),
              let tier = LeagueTier(rawValue: raw) else {
            return .bronze
        }
        return tier
    }

    private func persistLastSeenTier(_ tier: LeagueTier) {
        UserDefaults.standard.set(tier.rawValue, forKey: scopedKey(Self.lastSeenTierKey))
    }

    private func loadPendingPromotion() {
        guard let data = UserDefaults.standard.data(
            forKey: scopedKey(Self.pendingPromotionKey)
        ),
              let promotion = try? JSONDecoder().decode(TierPromotion.self, from: data) else {
            pendingPromotion = nil
            return
        }
        pendingPromotion = promotion
    }

    /// Reconcile a callable-produced profile into the social surface. The
    /// server envelope becomes the self row and bucket authority, while a
    /// differing local rating is recorded rather than overwritten.
    func reconcileAuthoritativeProfile(
        _ profile: PublicProfileSnapshot,
        context: SocialAccountOperationContext? = nil
    ) {
        guard isSessionActive,
              let activeAccountID,
              profile.accountID == activeAccountID,
              AuthManager.shared.currentAccountID == activeAccountID,
              context.map(isSocialOperationContextCurrent) ?? true else { return }

        authoritativeSelfProfile = profile
        let localRating = RatingStore.shared.rating
        if localRating.hasRatedEvidence, localRating.overall != profile.rating {
            ratingDivergence = PeerRatingDivergence(
                localRating: localRating.overall,
                serverRating: profile.rating,
                observedAt: Date()
            )
        } else {
            ratingDivergence = nil
        }
        peerSyncFailure = nil
        recomputeTierAndBucket()

        members.removeAll { $0.accountID == profile.accountID }
        members.append(profile)
        members.sort {
            if $0.rating == $1.rating { return $0.updatedAt > $1.updatedAt }
            return $0.rating > $1.rating
        }
    }

    func recordPeerSyncFailure(
        sessionID: UUID,
        message: String,
        isRetryable: Bool = true,
        context: SocialAccountOperationContext? = nil
    ) {
        guard isSessionActive,
              context.map(isSocialOperationContextCurrent) ?? true else { return }
        peerSyncFailure = PeerSessionSyncFailure(
            sessionID: sessionID,
            message: message,
            isRetryable: isRetryable
        )
    }

    /// Retry uses the same stored session ID, so the callable's replay guard
    /// returns `processed: false` after a lost response instead of applying a
    /// second rating/league mutation.
    @discardableResult
    func retryPeerSync() async -> Bool {
        guard SocialReleaseCapabilities.peerProgress.isAvailable else {
            peerSyncFailure = nil
            return false
        }
        guard let context = captureSocialOperationContext(),
              !isRetryingPeerSync,
              let failure = peerSyncFailure,
              let session = PracticeSessionStore.shared.sessions.first(where: { $0.id == failure.sessionID }),
              let providerRawValue = AuthManager.shared.currentAuthProviderRawValue else {
            return false
        }
        let displayName = AuthManager.shared.currentAccountName ?? "Speaker"
        isRetryingPeerSync = true
        defer {
            if isSocialOperationContextCurrent(context) {
                isRetryingPeerSync = false
            }
        }
        do {
            let result = try await BackendSyncManager.shared.recordPeerSession(
                session: session,
                accountID: context.accountID,
                providerRawValue: providerRawValue,
                displayName: displayName
            )
            guard isSocialOperationContextCurrent(context) else { return false }
            reconcileAuthoritativeProfile(result.profile, context: context)
            return true
        } catch {
            guard isSocialOperationContextCurrent(context) else { return false }
            let authorityError = error as? SocialAuthorityError
            recordPeerSyncFailure(
                sessionID: failure.sessionID,
                message: error.localizedDescription,
                isRetryable: authorityError?.isRetryable ?? true,
                context: context
            )
            return false
        }
    }

    /// Compatibility alias for older account-switch call sites. Registry
    /// ownership now uses the explicit `endSession`/`reloadForCurrentAccount`
    /// pair so persisted account state is reloaded at the correct phase.
    func resetForAccountTransition() {
        endSession()
    }

    /// Refresh the visible top-20 of the current bucket. Throttled.
    /// `force: true` bypasses the throttle (pull-to-refresh).
    func refreshMembers(force: Bool = false) async {
        guard SocialReleaseCapabilities.peerProgress.isAvailable,
              let context = captureSocialOperationContext() else {
            isLoading = false
            return
        }
        if !force, let last = lastFetchAttempt,
           Date().timeIntervalSince(last) < Self.refreshThrottle { return }
        lastFetchAttempt = Date()
        isLoading = true
        defer {
            if isSocialOperationContextCurrent(context) {
                isLoading = false
            }
        }
        do {
            let result = try await BackendSyncManager.shared.fetchLeagueMembers(limit: 20)
            guard isSocialOperationContextCurrent(context) else { return }
            if let selfProfile = result.members.first(where: { $0.accountID == context.accountID }) {
                reconcileAuthoritativeProfile(selfProfile, context: context)
            }
            bucketKey = result.bucket
            members = result.members.sorted {
                if $0.rating == $1.rating { return $0.updatedAt > $1.updatedAt }
                return $0.rating > $1.rating
            }
            lastFetchedAt = Date()
        } catch {
            // Preserve the last authoritative page. Capability and transport
            // failures must not turn into client-authored league state.
        }
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
        let socialRating = authoritativeSelfProfile?.rating ?? RatingStore.shared.rating.overall
        return max(0, next.ratingFloor - socialRating)
    }

    // MARK: - Internals

    func captureSocialOperationContext() -> SocialAccountOperationContext? {
        guard isSessionActive,
              let activeAccountID,
              AuthManager.shared.currentAccountID == activeAccountID else { return nil }
        return SocialAccountOperationContext(
            accountID: activeAccountID,
            generation: accountGeneration
        )
    }

    func isSocialOperationContextCurrent(_ context: SocialAccountOperationContext) -> Bool {
        isSessionActive
            && context.matches(accountID: activeAccountID, generation: accountGeneration)
            && AuthManager.shared.currentAccountID == context.accountID
    }

    private static var persistedAccountID: String {
        KeychainHelper.load(key: "NoumAccountID") ?? "guest"
    }

    private func scopedKey(_ base: String) -> String {
        Self.accountKey(base: base, accountID: activeAccountID ?? "guest")
    }

    private func clearTransientState() {
        members = []
        authoritativeSelfProfile = nil
        ratingDivergence = nil
        peerSyncFailure = nil
        lastFetchedAt = nil
        lastFetchAttempt = nil
        isLoading = false
        isRetryingPeerSync = false
    }

    private func observeStateChanges() {
        // Re-evaluate tier when the user's rating changes during a session.
        ratingSubscription = RatingStore.shared.$rating
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recomputeTierAndBucket() }
        sessionsSubscription = PracticeSessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recomputeTierAndBucket() }
    }

    nonisolated static func bucketKey(for tier: LeagueTier, on date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let week = String(format: "W%02d", comps.weekOfYear ?? 0)
        let year = comps.yearForWeekOfYear ?? 0
        return "\(tier.rawValue)_\(year)-\(week)"
    }

    nonisolated static func bucketKey(for tier: LeagueTier, rating: SpeakingRating, on date: Date) -> String {
        guard rating.hasRatedEvidence else { return "" }
        return bucketKey(for: tier, on: date)
    }

    /// ISO-week-of-year key used to scope the weekly daily-challenge
    /// counter. Shape: "2026-W21" — purely a comparison string, never
    /// surfaced in copy.
    nonisolated static func isoWeekKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let week = String(format: "W%02d", comps.weekOfYear ?? 0)
        let year = comps.yearForWeekOfYear ?? 0
        return "\(year)-\(week)"
    }

    private func loadWeeklyDailyChallengeCompletions() {
        let nowWeekKey = Self.isoWeekKey(for: Date())
        let storedWeek = UserDefaults.standard.string(
            forKey: scopedKey(Self.dailyChallengeWeekKey)
        ) ?? ""
        if storedWeek == nowWeekKey {
            weeklyDailyChallengeCompletions = max(
                0,
                UserDefaults.standard.integer(forKey: scopedKey(Self.dailyChallengeCountKey))
            )
        } else {
            // Stale or absent — clear the persisted count without writing
            // a fresh zero (it'll be written on the next claim).
            weeklyDailyChallengeCompletions = 0
        }
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

// MARK: - Peak rating entry

/// A single row on the peak-rating wall: one bucket peer's all-time peak
/// rating + when they achieved it. Sourced from the existing league
/// `members/` documents (`PublicProfileSnapshot.peakRating`) — never
/// transcript text, never goal copy. Matches VISION anti-goals: leagues
/// surface aggregates, never words a user said.
struct PeakRatingEntry: Identifiable, Equatable {
    let accountID: String
    let displayName: String?
    let peakRating: Double
    let achievedAt: Date

    var id: String { accountID }
}

// MARK: - Peak ratings query

@available(iOS 17.0, macOS 12.0, *)
extension LeagueManager {
    /// Top peak ratings inside the user's current league bucket, ordered by
    /// `peakRating` descending. Reads the same server-authorized callable page
    /// that `refreshMembers` uses. Returns at most `limit` rows.
    ///
    /// Bucket scoping: same `(tier, ISO-year-week)` key as the existing
    /// league surface, so a user only ever sees peers in their tier this
    /// week. Cross-tier comparison is intentionally absent — the league
    /// is the comparison frame.
    ///
    /// Trade-off: the underlying `fetchLeagueMembers` orders server-side
    /// by `rating` desc and caps at 20. We re-sort the page client-side
    /// by `peakRating`. A bucket-mate whose current rating is below top-20
    /// but whose peak is high may be missed; acceptable for v1 and avoids
    /// a Firestore composite index. Bumpable when usage proves it out.
    func peakRatingsInBucket(limit: Int = 5) async -> [PeakRatingEntry] {
        guard SocialReleaseCapabilities.peerProgress.isAvailable,
              let context = captureSocialOperationContext() else { return [] }
        do {
            let result = try await BackendSyncManager.shared.fetchLeagueMembers(limit: 20)
            guard isSocialOperationContextCurrent(context) else { return [] }
            let entries = result.members.map { snapshot in
                PeakRatingEntry(
                    accountID: snapshot.accountID,
                    displayName: snapshot.displayName.isEmpty ? nil : snapshot.displayName,
                    peakRating: Double(snapshot.peakRating),
                    achievedAt: snapshot.updatedAt
                )
            }
            return Array(
                entries
                    .sorted { $0.peakRating > $1.peakRating }
                    .prefix(limit)
            )
        } catch {
            return []
        }
    }
}

#endif
