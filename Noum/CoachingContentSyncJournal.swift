import Foundation

/// Stable identity for one backend-owned coaching document. The durable
/// journal stores only this metadata; profile/session content remains owned by
/// its existing account-scoped store and is resolved again immediately before
/// transport.
enum CoachingContentDocumentID: Codable, Hashable, Sendable {
    case profile
    case progression
    case session(UUID)

    private enum CodingKeys: String, CodingKey {
        case kind
        case sessionID
    }

    private enum Kind: String, Codable {
        case profile
        case progression
        case session
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .profile:
            self = .profile
        case .progression:
            self = .progression
        case .session:
            self = .session(
                try container.decode(UUID.self, forKey: .sessionID)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .profile:
            try container.encode(Kind.profile, forKey: .kind)
        case .progression:
            try container.encode(Kind.progression, forKey: .kind)
        case .session(let sessionID):
            try container.encode(Kind.session, forKey: .kind)
            try container.encode(sessionID, forKey: .sessionID)
        }
    }

    fileprivate var sortKey: String {
        switch self {
        case .profile:
            return "0-profile"
        case .progression:
            return "1-progression"
        case .session(let sessionID):
            return "2-session-\(sessionID.uuidString.lowercased())"
        }
    }
}

struct PendingCoachingContentMutation: Codable, Equatable, Sendable {
    let documentID: CoachingContentDocumentID
    let revision: UInt64
    let mutationID: UUID
}

struct CoachingContentPendingSnapshot: Equatable, Sendable {
    let documentIDs: Set<CoachingContentDocumentID>

    static let empty = CoachingContentPendingSnapshot(documentIDs: [])

    var isEmpty: Bool { documentIDs.isEmpty }
    var hasProfile: Bool { documentIDs.contains(.profile) }
    var hasProgression: Bool { documentIDs.contains(.progression) }

    var sessionIDs: Set<UUID> {
        Set(documentIDs.compactMap { documentID in
            guard case .session(let sessionID) = documentID else { return nil }
            return sessionID
        })
    }
}

enum CoachingContentSyncJournalStatus: Equatable, Sendable {
    case clean
    case pending(CoachingContentPendingSnapshot)
    /// Existing bytes could not be decoded under the checked-in schema. Do not
    /// overwrite them or treat the account as remotely authoritative.
    case unreadable
}

/// Thread-safe because store mutations must record retry intent synchronously,
/// before launching unstructured work toward `BackendSyncManager`'s actor.
/// All content remains in the existing stores; this journal is only an ordered,
/// account-scoped list of document identities and exact acknowledgement tokens.
final class CoachingContentSyncJournal: @unchecked Sendable {
    static let storageKeyPrefix = "coachingContent.syncJournal."

    private struct State: Codable, Equatable {
        static let schemaVersion = 1

        let schemaVersion: Int
        var nextRevision: UInt64
        var pending: [PendingCoachingContentMutation]

        static let empty = State(
            schemaVersion: schemaVersion,
            nextRevision: 0,
            pending: []
        )

        var isValid: Bool {
            guard schemaVersion == Self.schemaVersion else { return false }
            let documentIDs = pending.map(\.documentID)
            let mutationIDs = pending.map(\.mutationID)
            let revisions = pending.map(\.revision)
            return Set(documentIDs).count == documentIDs.count
                && Set(mutationIDs).count == mutationIDs.count
                && Set(revisions).count == revisions.count
                && revisions.allSatisfy { $0 > 0 && $0 <= nextRevision }
        }
    }

    private enum Lookup {
        case missing
        case state(State)
        case unreadable
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func status(for accountID: String) -> CoachingContentSyncJournalStatus {
        withLock {
            switch load(accountID: accountID) {
            case .missing:
                return .clean
            case .unreadable:
                return .unreadable
            case .state(let state):
                guard !state.pending.isEmpty else { return .clean }
                return .pending(CoachingContentPendingSnapshot(
                    documentIDs: Set(state.pending.map(\.documentID))
                ))
            }
        }
    }

    @discardableResult
    func enqueue(
        _ documentID: CoachingContentDocumentID,
        accountID: String
    ) -> PendingCoachingContentMutation? {
        enqueue([documentID], accountID: accountID).first
    }

    /// Records a whole snapshot atomically. Repeated document identities are
    /// coalesced before revisions are assigned, and every replaced entry gets a
    /// new mutation ID so an older completion can never clear newer work.
    @discardableResult
    func enqueue(
        _ documentIDs: [CoachingContentDocumentID],
        accountID: String
    ) -> [PendingCoachingContentMutation] {
        withLock {
            let normalizedAccountID = accountID.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !normalizedAccountID.isEmpty else { return [] }

            let originalData = defaults.data(
                forKey: Self.storageKey(for: normalizedAccountID)
            )
            var state: State
            switch load(accountID: normalizedAccountID) {
            case .missing:
                state = .empty
            case .state(let existing):
                state = existing
            case .unreadable:
                return []
            }

            let unique = Set(documentIDs).sorted { $0.sortKey < $1.sortKey }
            guard !unique.isEmpty,
                  UInt64(unique.count) <= UInt64.max - state.nextRevision else {
                return []
            }

            var enqueued: [PendingCoachingContentMutation] = []
            for documentID in unique {
                state.nextRevision += 1
                let mutation = PendingCoachingContentMutation(
                    documentID: documentID,
                    revision: state.nextRevision,
                    mutationID: UUID()
                )
                state.pending.removeAll { $0.documentID == documentID }
                state.pending.append(mutation)
                enqueued.append(mutation)
            }
            state.pending.sort { $0.revision < $1.revision }
            guard persist(
                state,
                accountID: normalizedAccountID,
                restoring: originalData
            ) else {
                return []
            }
            return enqueued
        }
    }

    func pendingMutations(
        for accountID: String,
        excluding attemptedMutationIDs: Set<UUID> = []
    ) -> [PendingCoachingContentMutation]? {
        withLock {
            switch load(accountID: accountID) {
            case .missing:
                return []
            case .unreadable:
                return nil
            case .state(let state):
                return state.pending
                    .filter { !attemptedMutationIDs.contains($0.mutationID) }
                    .sorted { $0.revision < $1.revision }
            }
        }
    }

    /// Clears only the exact mutation still pending. A newer mutation for the
    /// same document survives an older transport completion.
    @discardableResult
    func acknowledge(
        _ mutation: PendingCoachingContentMutation,
        accountID: String
    ) -> Bool {
        withLock {
            let originalData = defaults.data(
                forKey: Self.storageKey(for: accountID)
            )
            guard case .state(var state) = load(accountID: accountID),
                  let index = state.pending.firstIndex(where: {
                      $0.documentID == mutation.documentID
                          && $0.revision == mutation.revision
                          && $0.mutationID == mutation.mutationID
                  }) else {
                return false
            }
            state.pending.remove(at: index)
            return persist(
                state,
                accountID: accountID,
                restoring: originalData
            )
        }
    }

    private static func storageKey(for accountID: String) -> String {
        storageKeyPrefix + accountID
    }

    private func load(accountID: String) -> Lookup {
        let normalizedAccountID = accountID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedAccountID.isEmpty else { return .unreadable }
        guard let data = defaults.data(
            forKey: Self.storageKey(for: normalizedAccountID)
        ) else {
            return .missing
        }
        guard let state = try? JSONDecoder().decode(State.self, from: data),
              state.isValid else {
            return .unreadable
        }
        return .state(state)
    }

    private func persist(
        _ state: State,
        accountID: String,
        restoring originalData: Data?
    ) -> Bool {
        guard state.isValid,
              let data = try? JSONEncoder().encode(state) else { return false }
        let key = Self.storageKey(for: accountID)
        defaults.set(data, forKey: key)
        guard defaults.data(forKey: key) == data else {
            if let originalData {
                defaults.set(originalData, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            return false
        }
        return true
    }

    private func withLock<T>(_ operation: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}
