import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Feedback Request Status

enum FeedbackRequestStatus: String, Codable {
    case pending     // Sent, no response yet
    case responded   // At least one response received
    case archived    // User dismissed/archived
}

// MARK: - Stored Feedback Request

struct StoredFeedbackRequest: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let sessionId: UUID?
    let recipientName: String   // Friend name or "External"
    let transcript: String
    let score: Int
    let headline: String
    let prompt: String?
    let mode: PracticeMode
    let requestNote: String
    var status: FeedbackRequestStatus
    var responses: [StoredFeedbackResponse]
}

// MARK: - Stored Feedback Response

struct StoredFeedbackResponse: Codable, Identifiable {
    let id: UUID
    let respondedAt: Date
    let responderName: String
    let textFeedback: String
    let dimensionRatings: [String: String]  // dimension -> "good" / "ok" / "couldImprove"

    init(
        responderName: String,
        textFeedback: String,
        dimensionRatings: [String: String] = [:]
    ) {
        self.id = UUID()
        self.respondedAt = Date()
        self.responderName = responderName
        self.textFeedback = textFeedback
        self.dimensionRatings = dimensionRatings
    }
}

/// Versioned account export wraps this value in `AccountDataRegistry`'s
/// participant envelope. Keeping the raw feedback records together here makes
/// transcript-bearing data explicit and independently testable.
struct FeedbackRequestsAccountDataSnapshot: Codable {
    let requests: [StoredFeedbackRequest]
}

// MARK: - Feedback Request Manager

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class FeedbackRequestManager: ObservableObject {
    static let shared = FeedbackRequestManager()

    @Published private(set) var requests: [StoredFeedbackRequest] = []

    /// Requests that haven't been responded to yet.
    var pendingRequests: [StoredFeedbackRequest] {
        requests.filter { $0.status == .pending }
    }

    /// Requests with at least one response.
    var respondedRequests: [StoredFeedbackRequest] {
        requests.filter { $0.status == .responded }
    }

    /// Total unread response count for badge display.
    var unreadCount: Int {
        respondedRequests.count
    }

    private static let legacyStorageKey = "noum_feedback_requests"
    private static let storagePrefix = "noum_feedback_requests."

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        self.accountIDProvider = accountIDProvider ?? {
            KeychainHelper.load(key: "NoumAccountID")
        }
        reloadForCurrentAccount()
    }

    // MARK: - Account Lifecycle

    /// Reload only the records owned by the active Noum identity. The legacy
    /// unscoped archive is claimed once by the first established account, then
    /// removed so it can never surface for a later account.
    func reloadForCurrentAccount() {
        guard let accountID = currentAccountID else {
            requests = []
            return
        }
        migrateLegacyDataIfNeeded(to: accountID)
        requests = Self.load(
            from: defaults,
            key: Self.storageKey(for: accountID)
        )
    }

    /// Clear observable state while preserving the signed-out account's data.
    func endSession() {
        requests = []
    }

    func exportSnapshot(for accountID: String) -> FeedbackRequestsAccountDataSnapshot {
        FeedbackRequestsAccountDataSnapshot(requests: Self.load(
            from: defaults,
            key: Self.storageKey(for: accountID)
        ))
    }

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: Self.storageKey(for: accountID))
        if currentAccountID == accountID {
            // A legacy blob that survived an interrupted migration belongs to
            // the current account. Removing it prevents deletion followed by
            // an account switch from resurrecting private transcripts.
            defaults.removeObject(forKey: Self.legacyStorageKey)
            requests = []
        }
    }

    // MARK: - Create Request

    /// Create a new feedback request for a friend.
    func createRequest(
        sessionId: UUID? = nil,
        recipientName: String,
        transcript: String,
        score: Int,
        headline: String,
        prompt: String?,
        mode: PracticeMode,
        requestNote: String
    ) -> StoredFeedbackRequest {
        let request = StoredFeedbackRequest(
            id: UUID(),
            createdAt: Date(),
            sessionId: sessionId,
            recipientName: recipientName,
            transcript: transcript,
            score: score,
            headline: headline,
            prompt: prompt,
            mode: mode,
            requestNote: requestNote,
            status: .pending,
            responses: []
        )
        requests.insert(request, at: 0)
        save()
        return request
    }

    // MARK: - Record Response

    /// Add a response to a feedback request.
    func addResponse(
        requestId: UUID,
        responderName: String,
        textFeedback: String,
        dimensionRatings: [String: String] = [:]
    ) {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }
        let response = StoredFeedbackResponse(
            responderName: responderName,
            textFeedback: textFeedback,
            dimensionRatings: dimensionRatings
        )
        requests[index].responses.append(response)
        requests[index].status = .responded
        save()
    }

    // MARK: - Status Management

    func archive(requestId: UUID) {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }
        requests[index].status = .archived
        save()
    }

    func delete(requestId: UUID) {
        requests.removeAll { $0.id == requestId }
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let accountID = currentAccountID,
              let data = try? JSONEncoder().encode(requests) else { return }
        defaults.set(data, forKey: Self.storageKey(for: accountID))
    }

    private var currentAccountID: String? {
        guard let accountID = accountIDProvider(), !accountID.isEmpty else {
            return nil
        }
        return accountID
    }

    private func migrateLegacyDataIfNeeded(to accountID: String) {
        guard let legacyData = defaults.data(forKey: Self.legacyStorageKey) else {
            return
        }

        let scopedKey = Self.storageKey(for: accountID)
        if defaults.data(forKey: scopedKey) == nil,
           (try? JSONDecoder().decode(
               [StoredFeedbackRequest].self,
               from: legacyData
           )) != nil {
            defaults.set(legacyData, forKey: scopedKey)
        }

        // Remove even malformed or superseded legacy data. Leaving a global
        // transcript archive behind would allow a later identity to claim it.
        defaults.removeObject(forKey: Self.legacyStorageKey)
    }

    private static func storageKey(for accountID: String) -> String {
        "\(storagePrefix)\(accountID)"
    }

    private static func load(
        from defaults: UserDefaults,
        key: String
    ) -> [StoredFeedbackRequest] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(
                  [StoredFeedbackRequest].self,
                  from: data
              ) else {
            return []
        }
        return decoded
    }
}
#endif
