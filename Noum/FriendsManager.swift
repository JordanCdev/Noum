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

    enum AddMethod: String, Codable {
        case invite
        case qrCode
        case contacts
        case manual
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

    private let storageKey = "NoumFriendsList"

    private init() {
        friends = Self.loadFriends()
    }

    func addFriend(_ friend: NoumFriend) {
        guard !friends.contains(where: { $0.id == friend.id }) else { return }
        friends.insert(friend, at: 0)
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
        friends.removeAll { $0.id == id }
        persist()
    }

    var friendCount: Int { friends.count }

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
