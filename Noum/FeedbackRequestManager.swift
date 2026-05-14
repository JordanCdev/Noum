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

    private let storageKey = "noum_feedback_requests"

    private init() {
        load()
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
        if let data = try? JSONEncoder().encode(requests) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StoredFeedbackRequest].self, from: data) else { return }
        requests = decoded
    }
}
#endif
