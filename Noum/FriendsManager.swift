import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Friend Model

struct NoumFriend: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var addedAt: Date
    var addedVia: AddMethod
    /// Auth-system ID of the friend's account. Required for backend peer
    /// stat lookup — without it, the friend stays in "Awaiting sync" state
    /// because there's nothing to query. Optional so legacy friends added
    /// before the M2 release decode cleanly.
    var accountID: String?
    var pairID: String?
    /// Present only for links produced by the reciprocal friendship callable.
    /// Legacy client-authored account IDs decode as local contacts and cannot
    /// become social authority by surviving an app update.
    var connectionSchemaVersion: Int?

    /// Cached peer stats — populated by backend sync when available.
    /// All optional so existing friends decode cleanly when the fields are absent.
    /// `nil` is the honest "we don't know yet" signal — leaderboard treats it
    /// as "Awaiting sync", not as zero.
    var lastKnownRating: Int?
    var lastKnownPeakRating: Int?
    var lastKnownStreak: Int?
    var lastKnownRepsThisWeek: Int?
    var lastSyncedAt: Date?

    enum AddMethod: String, Codable, Sendable {
        case invite
        case qrCode
        case contacts
        case manual
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, addedAt, addedVia, accountID, pairID, connectionSchemaVersion
        case lastKnownRating, lastKnownPeakRating, lastKnownStreak, lastKnownRepsThisWeek, lastSyncedAt
    }

    init(
        id: UUID,
        displayName: String,
        addedAt: Date,
        addedVia: AddMethod,
        accountID: String? = nil,
        pairID: String? = nil,
        connectionSchemaVersion: Int? = nil,
        lastKnownRating: Int? = nil,
        lastKnownPeakRating: Int? = nil,
        lastKnownStreak: Int? = nil,
        lastKnownRepsThisWeek: Int? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.addedAt = addedAt
        self.addedVia = addedVia
        self.accountID = accountID
        self.pairID = pairID
        self.connectionSchemaVersion = connectionSchemaVersion
        self.lastKnownRating = lastKnownRating
        self.lastKnownPeakRating = lastKnownPeakRating
        self.lastKnownStreak = lastKnownStreak
        self.lastKnownRepsThisWeek = lastKnownRepsThisWeek
        self.lastSyncedAt = lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.addedAt = try c.decode(Date.self, forKey: .addedAt)
        self.addedVia = try c.decode(AddMethod.self, forKey: .addedVia)
        self.accountID = try c.decodeIfPresent(String.self, forKey: .accountID)
        self.pairID = try c.decodeIfPresent(String.self, forKey: .pairID)
        self.connectionSchemaVersion = try c.decodeIfPresent(Int.self, forKey: .connectionSchemaVersion)
        self.lastKnownRating = try c.decodeIfPresent(Int.self, forKey: .lastKnownRating)
        self.lastKnownPeakRating = try c.decodeIfPresent(Int.self, forKey: .lastKnownPeakRating)
        self.lastKnownStreak = try c.decodeIfPresent(Int.self, forKey: .lastKnownStreak)
        self.lastKnownRepsThisWeek = try c.decodeIfPresent(Int.self, forKey: .lastKnownRepsThisWeek)
        self.lastSyncedAt = try c.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }

    /// Short initials for avatar
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var isServerLinked: Bool {
        addedVia == .invite
            && connectionSchemaVersion == ListFriendLinksRequest.currentSchemaVersion
            && accountID?.isEmpty == false
            && pairID.flatMap(UUID.init(uuidString:)) != nil
    }
}

struct FriendsAccountDataSnapshot: Codable, Equatable, Sendable {
    let friends: [NoumFriend]
}

// MARK: - Friends Manager (local persistence)

#if canImport(SwiftUI)

@MainActor
final class FriendsManager: ObservableObject {
    static let shared = FriendsManager()

    @Published private(set) var friends: [NoumFriend] = []
    @Published private(set) var isRefreshingPeerStats = false
    @Published private(set) var connectionOperation: FriendConnectionOperation?
    @Published private(set) var activeInvite: FriendInviteAuthorityResult?
    @Published private(set) var connectionErrorMessage: String?

    private let storageKey = "NoumFriendsList"

    /// Throttle peer-stat refreshes — repeated taps on the leaderboard or
    /// rapid scene re-entries shouldn't burn quota.
    private static let refreshThrottle: TimeInterval = 60

    private var lastRefreshAttempt: Date?
    private var lastLinkRefreshAttempt: Date?
    private var activeAccountID: String?
    private var accountGeneration: UInt64 = 0
    private var isSessionActive = true

    private init() {
        activeAccountID = Self.persistedAccountID
        friends = Self.loadFriends(accountID: activeAccountID ?? "guest")
    }

    enum FriendConnectionOperation: Equatable, Sendable {
        case creatingInvite
        case acceptingInvite
        case refreshing
        case removing(UUID)
    }

    func addFriend(_ friend: NoumFriend) {
        guard isSessionActive, activeAccountID != nil else { return }
        guard !friend.isServerLinked,
              !friends.contains(where: { $0.id == friend.id }) else { return }
        var localContact = friend
        localContact.accountID = nil
        localContact.pairID = nil
        localContact.connectionSchemaVersion = nil
        if localContact.addedVia == .invite {
            localContact.addedVia = .manual
        }
        friends.insert(localContact, at: 0)
        persist()
    }

    func addFriend(name: String, method: NoumFriend.AddMethod = .manual) {
        let friend = NoumFriend(
            id: UUID(),
            displayName: name,
            addedAt: Date(),
            addedVia: method
        )
        addFriend(friend)
    }

    func removeFriend(id: UUID) {
        guard isSessionActive, activeAccountID != nil else { return }
        // Reciprocal links must be removed server-first through
        // `removeConnection(id:)`; this local path is for practice contacts.
        guard friends.first(where: { $0.id == id })?.isServerLinked != true else { return }
        friends.removeAll { $0.id == id }
        persist()
    }

    var friendCount: Int { friends.count }

    // MARK: - Peer stat refresh

    /// Friends that have an `accountID` and so can be looked up server-side.
    /// Used as the gate for refresh + leaderboard "Awaiting sync" copy.
    var addressableFriendCount: Int {
        friends.filter(\.isServerLinked).count
    }

    /// Best-effort fetch of friend public profiles from the backend. Updates
    /// `lastKnown*` fields in place. Throttled so rapid view re-entry is cheap.
    /// `force: true` bypasses the throttle (e.g., pull-to-refresh).
    func refreshPeerStats(force: Bool = false) async {
        guard SocialReleaseCapabilities.friendProfiles.isAvailable,
              let context = captureOperationContext() else {
            isRefreshingPeerStats = false
            return
        }
        if !force, let last = lastRefreshAttempt,
           Date().timeIntervalSince(last) < Self.refreshThrottle { return }
        let targets = friends.filter(\.isServerLinked)
        guard !targets.isEmpty else { return }
        lastRefreshAttempt = Date()
        isRefreshingPeerStats = true
        defer {
            if isOperationContextCurrent(context) {
                isRefreshingPeerStats = false
            }
        }

        var fetched: [String: PublicProfileSnapshot] = [:]
        await withTaskGroup(of: PublicProfileSnapshot?.self) { group in
            for friend in targets {
                guard let accountID = friend.accountID else { continue }
                group.addTask {
                    try? await BackendSyncManager.shared.fetchPeerProfile(accountID: accountID)
                }
            }
            for await snapshot in group {
                if let snapshot { fetched[snapshot.accountID] = snapshot }
            }
        }
        guard isOperationContextCurrent(context) else { return }
        guard !fetched.isEmpty else { return }

        var didChange = false
        for index in friends.indices {
            guard let accountID = friends[index].accountID,
                  let snapshot = fetched[accountID] else { continue }
            friends[index].lastKnownRating = snapshot.rating
            friends[index].lastKnownPeakRating = snapshot.peakRating
            friends[index].lastKnownStreak = snapshot.currentStreak
            friends[index].lastKnownRepsThisWeek = snapshot.weeklyReps
            friends[index].lastSyncedAt = snapshot.updatedAt
            didChange = true
        }
        if didChange { persist(context: context) }
    }

    // MARK: - Reciprocal connection lifecycle

    var isManagingConnections: Bool { connectionOperation != nil }

    func createConnectionInvite(displayName: String) async {
        guard let context = beginConnectionOperation(.creatingInvite) else { return }
        defer { finishConnectionOperation(.creatingInvite, context: context) }
        do {
            let invite = try await BackendSyncManager.shared.createFriendInvite(
                displayName: displayName,
                accountID: context.accountID
            )
            guard isOperationContextCurrent(context) else { return }
            activeInvite = invite
            connectionErrorMessage = nil
        } catch {
            recordConnectionFailure(error, context: context)
        }
    }

    func acceptConnectionInvite(token: String, displayName: String) async {
        guard let context = beginConnectionOperation(.acceptingInvite) else { return }
        defer { finishConnectionOperation(.acceptingInvite, context: context) }
        do {
            let link = try await BackendSyncManager.shared.acceptFriendInvite(
                inviteToken: token,
                displayName: displayName,
                accountID: context.accountID
            )
            guard isOperationContextCurrent(context) else { return }
            friends = Self.mergingAcceptedLink(link, into: friends)
            activeInvite = nil
            connectionErrorMessage = nil
            persist(context: context)
        } catch {
            recordConnectionFailure(error, context: context)
        }
    }

    /// Reconciles reciprocal membership from one complete server list. Manual
    /// practice contacts remain untouched, while stale server-linked rows are
    /// removed and unchanged links retain their cached public statistics.
    func refreshFriendLinks(force: Bool = false) async {
        guard SocialReleaseCapabilities.friendConnections.isAvailable else {
            connectionErrorMessage = SocialReleaseCapabilities.friendConnections.message
            return
        }
        if !force, let lastLinkRefreshAttempt,
           Date().timeIntervalSince(lastLinkRefreshAttempt) < Self.refreshThrottle {
            return
        }
        guard let context = beginConnectionOperation(.refreshing) else { return }
        lastLinkRefreshAttempt = Date()
        defer { finishConnectionOperation(.refreshing, context: context) }
        do {
            let links = try await BackendSyncManager.shared.listFriendLinks(
                limit: 50,
                accountID: context.accountID
            )
            guard isOperationContextCurrent(context) else { return }
            friends = Self.reconcilingServerLinks(cached: friends, remote: links)
            connectionErrorMessage = nil
            persist(context: context)
        } catch {
            recordConnectionFailure(error, context: context)
        }
    }

    /// Removes server membership before local state. A failed or stale
    /// response therefore cannot silently hide a still-connected account.
    func removeConnection(id: UUID) async {
        guard let friend = friends.first(where: { $0.id == id }),
              friend.isServerLinked,
              let friendAccountID = friend.accountID,
              let persistedPairID = friend.pairID,
              let pairID = UUID(uuidString: persistedPairID),
              let context = beginConnectionOperation(.removing(id)) else { return }
        defer { finishConnectionOperation(.removing(id), context: context) }
        do {
            let result = try await BackendSyncManager.shared.removeFriendLink(
                pairID: pairID,
                friendAccountID: friendAccountID,
                accountID: context.accountID
            )
            guard isOperationContextCurrent(context),
                  result.pairID == pairID,
                  result.friendAccountID == friendAccountID else { return }
            friends = Self.removingConfirmedServerLink(
                id: id,
                accountID: friendAccountID,
                pairID: pairID,
                from: friends
            )
            connectionErrorMessage = nil
            persist(context: context)
        } catch {
            recordConnectionFailure(error, context: context)
        }
    }

    func clearConnectionError() {
        connectionErrorMessage = nil
    }

    static func reconcilingServerLinks(
        cached: [NoumFriend],
        remote: [FriendAuthorityLink]
    ) -> [NoumFriend] {
        let localContacts = cached.filter { !$0.isServerLinked }
        var existing: [UUID: NoumFriend] = [:]
        for friend in cached {
            guard friend.isServerLinked,
                  let pairID = friend.pairID.flatMap(UUID.init(uuidString:)) else { continue }
            existing[pairID] = friend
        }
        let linked = remote.map { link -> NoumFriend in
            if var retained = existing[link.pairID], retained.accountID == link.accountID {
                retained.displayName = link.displayName
                retained.addedAt = link.linkedAt
                return retained
            }
            return serverFriend(from: link)
        }
        return linked + localContacts
    }

    static func removingConfirmedServerLink(
        id: UUID,
        accountID: String,
        pairID: UUID,
        from cached: [NoumFriend]
    ) -> [NoumFriend] {
        cached.filter {
            !($0.id == id
                && $0.accountID == accountID
                && $0.pairID.flatMap(UUID.init(uuidString:)) == pairID)
        }
    }

    static func mergingAcceptedLink(
        _ link: FriendAuthorityLink,
        into cached: [NoumFriend]
    ) -> [NoumFriend] {
        let existing = cached.first {
            $0.isServerLinked
                && $0.pairID.flatMap(UUID.init(uuidString:)) == link.pairID
                && $0.accountID == link.accountID
        }
        var remaining = cached.filter {
            !($0.isServerLinked && ($0.accountID == link.accountID || $0.pairID.flatMap(UUID.init(uuidString:)) == link.pairID))
        }
        if var existing {
            existing.displayName = link.displayName
            existing.addedAt = link.linkedAt
            remaining.insert(existing, at: 0)
        } else {
            remaining.insert(serverFriend(from: link), at: 0)
        }
        return remaining
    }

    private static func serverFriend(from link: FriendAuthorityLink) -> NoumFriend {
        NoumFriend(
            id: UUID(),
            displayName: link.displayName,
            addedAt: link.linkedAt,
            addedVia: .invite,
            accountID: link.accountID,
            pairID: link.pairID.uuidString,
            connectionSchemaVersion: ListFriendLinksRequest.currentSchemaVersion
        )
    }

    // MARK: - Persistence

    private func persist(context: SocialAccountOperationContext? = nil) {
        guard isSessionActive,
              let activeAccountID,
              context.map(isOperationContextCurrent) ?? true else { return }
        guard let data = try? JSONEncoder().encode(friends) else { return }
        UserDefaults.standard.set(data, forKey: Self.accountKey(
            base: storageKey,
            accountID: activeAccountID
        ))
    }

    private static var persistedAccountID: String {
        KeychainHelper.load(key: "NoumAccountID") ?? "guest"
    }

    nonisolated static func accountKey(base: String, accountID: String) -> String {
        "\(base).\(accountID)"
    }

    private static func loadFriends(accountID: String) -> [NoumFriend] {
        let key = accountKey(base: "NoumFriendsList", accountID: accountID)
        if accountID != "guest",
           UserDefaults.standard.data(forKey: key) == nil,
           let legacy = UserDefaults.standard.data(forKey: "NoumFriendsList") {
            UserDefaults.standard.set(legacy, forKey: key)
            UserDefaults.standard.removeObject(forKey: "NoumFriendsList")
        }
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NoumFriend].self, from: data) else {
            return []
        }
        return decoded.map { friend in
            guard friend.isServerLinked else {
                var local = friend
                local.accountID = nil
                local.pairID = nil
                local.connectionSchemaVersion = nil
                if local.addedVia == .invite { local.addedVia = .manual }
                return local
            }
            return friend
        }
    }

    func reloadForCurrentAccount() {
        accountGeneration &+= 1
        activeAccountID = Self.persistedAccountID
        isSessionActive = true
        friends = Self.loadFriends(accountID: activeAccountID ?? "guest")
        isRefreshingPeerStats = false
        lastRefreshAttempt = nil
        lastLinkRefreshAttempt = nil
        connectionOperation = nil
        activeInvite = nil
        connectionErrorMessage = nil
    }

    func endSession() {
        accountGeneration &+= 1
        activeAccountID = nil
        isSessionActive = false
        friends = []
        isRefreshingPeerStats = false
        lastRefreshAttempt = nil
        lastLinkRefreshAttempt = nil
        connectionOperation = nil
        activeInvite = nil
        connectionErrorMessage = nil
    }

    func exportSnapshot(for accountID: String) -> FriendsAccountDataSnapshot {
        FriendsAccountDataSnapshot(friends: Self.loadFriends(accountID: accountID))
    }

    func deleteAllData(for accountID: String) {
        UserDefaults.standard.removeObject(forKey: Self.accountKey(
            base: storageKey,
            accountID: accountID
        ))
        if Self.persistedAccountID == accountID {
            endSession()
        }
    }

    private func captureOperationContext() -> SocialAccountOperationContext? {
        guard isSessionActive,
              let activeAccountID,
              AuthManager.shared.currentAccountID == activeAccountID else { return nil }
        return SocialAccountOperationContext(
            accountID: activeAccountID,
            generation: accountGeneration
        )
    }

    private func isOperationContextCurrent(_ context: SocialAccountOperationContext) -> Bool {
        isSessionActive
            && context.matches(accountID: activeAccountID, generation: accountGeneration)
            && AuthManager.shared.currentAccountID == context.accountID
    }

    private func beginConnectionOperation(
        _ operation: FriendConnectionOperation
    ) -> SocialAccountOperationContext? {
        guard SocialReleaseCapabilities.friendConnections.isAvailable else {
            connectionErrorMessage = SocialReleaseCapabilities.friendConnections.message
            return nil
        }
        guard connectionOperation == nil, let context = captureOperationContext() else {
            return nil
        }
        connectionOperation = operation
        connectionErrorMessage = nil
        return context
    }

    private func finishConnectionOperation(
        _ operation: FriendConnectionOperation,
        context: SocialAccountOperationContext
    ) {
        guard isOperationContextCurrent(context), connectionOperation == operation else { return }
        connectionOperation = nil
    }

    private func recordConnectionFailure(
        _ error: Error,
        context: SocialAccountOperationContext
    ) {
        guard isOperationContextCurrent(context) else { return }
        let message = (error as? LocalizedError)?.errorDescription
            ?? SocialAuthorityError.serviceUnavailable.errorDescription
            ?? "Connection sync is unavailable right now."
        connectionErrorMessage = String(message.prefix(240))
    }
}

#endif
