import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Friend Model

struct NoumFriend: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var addedAt: Date
    var addedVia: AddMethod
    /// Auth-system ID of the friend's account. Required for backend peer
    /// stat lookup — without it, the friend stays in "Awaiting sync" state
    /// because there's nothing to query. Optional so legacy friends added
    /// before the M2 release decode cleanly.
    var accountID: String?

    /// Cached peer stats — populated by backend sync when available.
    /// All optional so existing friends decode cleanly when the fields are absent.
    /// `nil` is the honest "we don't know yet" signal — leaderboard treats it
    /// as "Awaiting sync", not as zero.
    var lastKnownRating: Int?
    var lastKnownStreak: Int?
    var lastKnownRepsThisWeek: Int?
    var lastSyncedAt: Date?

    enum AddMethod: String, Codable {
        case invite
        case qrCode
        case contacts
        case manual
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, addedAt, addedVia, accountID
        case lastKnownRating, lastKnownStreak, lastKnownRepsThisWeek, lastSyncedAt
    }

    init(
        id: UUID,
        displayName: String,
        addedAt: Date,
        addedVia: AddMethod,
        accountID: String? = nil,
        lastKnownRating: Int? = nil,
        lastKnownStreak: Int? = nil,
        lastKnownRepsThisWeek: Int? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.addedAt = addedAt
        self.addedVia = addedVia
        self.accountID = accountID
        self.lastKnownRating = lastKnownRating
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
        self.lastKnownRating = try c.decodeIfPresent(Int.self, forKey: .lastKnownRating)
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
}

// MARK: - Friends Manager (local persistence)

#if canImport(SwiftUI)

@MainActor
final class FriendsManager: ObservableObject {
    static let shared = FriendsManager()

    @Published private(set) var friends: [NoumFriend] = []
    @Published private(set) var isRefreshingPeerStats = false

    private let storageKey = "NoumFriendsList"

    /// Throttle peer-stat refreshes — repeated taps on the leaderboard or
    /// rapid scene re-entries shouldn't burn quota.
    private static let refreshThrottle: TimeInterval = 60

    private var lastRefreshAttempt: Date?

    private init() {
        friends = Self.loadFriends()
    }

    func addFriend(_ friend: NoumFriend) {
        guard !friends.contains(where: { $0.id == friend.id }) else { return }
        if let accountID = friend.accountID,
           friends.contains(where: { $0.accountID == accountID }) {
            return
        }
        friends.insert(friend, at: 0)
        persist()
    }

    func addFriend(name: String, method: NoumFriend.AddMethod = .manual, accountID: String? = nil) {
        let friend = NoumFriend(
            id: UUID(),
            displayName: name,
            addedAt: Date(),
            addedVia: method,
            accountID: accountID
        )
        addFriend(friend)
    }

    func removeFriend(id: UUID) {
        friends.removeAll { $0.id == id }
        persist()
    }

    var friendCount: Int { friends.count }

    // MARK: - Peer stat refresh

    /// Friends that have an `accountID` and so can be looked up server-side.
    /// Used as the gate for refresh + leaderboard "Awaiting sync" copy.
    var addressableFriendCount: Int {
        friends.filter { $0.accountID != nil }.count
    }

    /// Best-effort fetch of friend public profiles from the backend. Updates
    /// `lastKnown*` fields in place. Throttled so rapid view re-entry is cheap.
    /// `force: true` bypasses the throttle (e.g., pull-to-refresh).
    func refreshPeerStats(force: Bool = false) async {
        if !force, let last = lastRefreshAttempt,
           Date().timeIntervalSince(last) < Self.refreshThrottle { return }
        let targets = friends.filter { $0.accountID != nil }
        guard !targets.isEmpty else { return }
        lastRefreshAttempt = Date()
        isRefreshingPeerStats = true
        defer { isRefreshingPeerStats = false }

        var fetched: [String: PublicProfileSnapshot] = [:]
        await withTaskGroup(of: PublicProfileSnapshot?.self) { group in
            for friend in targets {
                guard let accountID = friend.accountID else { continue }
                group.addTask {
                    await BackendSyncManager.shared.fetchPublicProfile(accountID: accountID)
                }
            }
            for await snapshot in group {
                if let snapshot { fetched[snapshot.accountID] = snapshot }
            }
        }
        guard !fetched.isEmpty else { return }

        var didChange = false
        for index in friends.indices {
            guard let accountID = friends[index].accountID,
                  let snapshot = fetched[accountID] else { continue }
            friends[index].lastKnownRating = snapshot.rating
            friends[index].lastKnownStreak = snapshot.currentStreak
            friends[index].lastKnownRepsThisWeek = snapshot.weeklyReps
            friends[index].lastSyncedAt = snapshot.updatedAt
            didChange = true
        }
        if didChange { persist() }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(friends) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func loadFriends() -> [NoumFriend] {
        guard let data = UserDefaults.standard.data(forKey: "NoumFriendsList"),
              let friends = try? JSONDecoder().decode([NoumFriend].self, from: data) else {
            return []
        }
        return friends
    }
}

#endif
