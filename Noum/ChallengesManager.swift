import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Challenge Model (daily/weekly/streak; social is legacy)

struct SpeakingChallenge2: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var category: Category
    var goal: Int
    var current: Int
    var reward: Reward
    var startDate: Date
    var endDate: Date
    var isCompleted: Bool

    enum Category: String, Codable, CaseIterable, Identifiable {
        case daily
        case weekly
        case streak
        case social

        var id: String { rawValue }

        var label: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .streak: return "Streak"
            case .social: return "Social"
            }
        }

        var icon: String {
            switch self {
            case .daily: return "sun.max.fill"
            case .weekly: return "calendar"
            case .streak: return "flame.fill"
            case .social: return "person.2.fill"
            }
        }

        var tint: Color {
            switch self {
            case .daily: return .orange
            case .weekly: return .blue
            case .streak: return .red
            case .social: return .purple
            }
        }
    }

    struct Reward: Codable, Equatable {
        var xp: Int
        var badge: String?
    }

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(current) / Double(goal))
    }

    var progressLabel: String {
        "\(current)/\(goal)"
    }

    var isExpired: Bool {
        Date() > endDate
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
    }
}

// MARK: - Async Challenge Model (friend-vs-friend)

struct AsyncChallenge: Codable, Identifiable, Equatable {
    let id: UUID
    let prompt: String
    let createdAt: Date
    let expiresAt: Date

    // Participants
    let creatorID: UUID
    let creatorName: String
    var creatorAccountID: String? = nil
    let opponentID: UUID
    let opponentName: String
    var opponentAccountID: String? = nil

    // Results
    var creatorScore: Int?
    var creatorDuration: TimeInterval?
    var creatorSummary: String?
    var opponentScore: Int?
    var opponentDuration: TimeInterval?
    var opponentSummary: String?

    // Reactions (lightweight peer feedback)
    var creatorReaction: Reaction?
    var opponentReaction: Reaction?

    enum Reaction: String, Codable, CaseIterable, Identifiable {
        case fire = "🔥"
        case clap = "👏"
        case strong = "💪"
        case mindBlown = "🤯"
        case trophy = "🏆"
        case heart = "❤️"

        var id: String { rawValue }
    }

    var isExpired: Bool { Date() > expiresAt }

    var creatorHasPlayed: Bool { creatorScore != nil }
    var opponentHasPlayed: Bool { opponentScore != nil }
    var bothHavePlayed: Bool { creatorHasPlayed && opponentHasPlayed }
    var creatorParticipantID: String {
        guard let creatorAccountID, !creatorAccountID.isEmpty else { return creatorID.uuidString }
        return creatorAccountID
    }
    var opponentParticipantID: String {
        guard let opponentAccountID, !opponentAccountID.isEmpty else { return opponentID.uuidString }
        return opponentAccountID
    }
    var participantIDs: [String] {
        [creatorParticipantID, opponentParticipantID, creatorID.uuidString, opponentID.uuidString]
            .reduce(into: [String]()) { ids, id in
                guard !ids.contains(id) else { return }
                ids.append(id)
            }
    }

    /// Status from the perspective of a given user ID
    func status(forUser userID: UUID) -> Status {
        status(forParticipantID: userID.uuidString)
    }

    /// Status from the perspective of a durable account or legacy UUID ID.
    func status(forParticipantID participantID: String) -> Status {
        let isCreator = isCreatorPerspective(participantID: participantID)
        let myPlayed = isCreator ? creatorHasPlayed : opponentHasPlayed
        let theirPlayed = isCreator ? opponentHasPlayed : creatorHasPlayed

        if isExpired && !bothHavePlayed { return .expired }
        if bothHavePlayed { return .complete }
        if myPlayed && !theirPlayed { return .waitingForOpponent }
        if !myPlayed && theirPlayed { return .yourTurn }
        return .pending
    }

    enum Status {
        case pending       // Neither has played
        case yourTurn      // Opponent played, you haven't
        case waitingForOpponent // You played, opponent hasn't
        case complete      // Both played
        case expired       // Time ran out

        var label: String {
            switch self {
            case .pending: return "New challenge"
            case .yourTurn: return "Your turn"
            case .waitingForOpponent: return "Waiting..."
            case .complete: return "Complete"
            case .expired: return "Expired"
            }
        }

        var tint: Color {
            switch self {
            case .pending: return .blue
            case .yourTurn: return .orange
            case .waitingForOpponent: return .secondary
            case .complete: return .green
            case .expired: return .secondary
            }
        }
    }

    /// Get the friend's name from the perspective of a given user
    func opponentName(forUser userID: UUID) -> String {
        opponentName(forParticipantID: userID.uuidString)
    }

    /// Get the friend's name from the perspective of a durable account or legacy UUID ID.
    func opponentName(forParticipantID participantID: String) -> String {
        isCreatorPerspective(participantID: participantID) ? opponentName : creatorName
    }

    /// Get the winner from the perspective of the user
    func result(forUser userID: UUID) -> ChallengeResult? {
        result(forParticipantID: userID.uuidString)
    }

    /// Get the winner from the perspective of a durable account or legacy UUID ID.
    func result(forParticipantID participantID: String) -> ChallengeResult? {
        guard let cs = creatorScore, let os = opponentScore else { return nil }
        let isCreator = isCreatorPerspective(participantID: participantID)
        let myScore = isCreator ? cs : os
        let theirScore = isCreator ? os : cs
        if myScore > theirScore { return .won }
        if theirScore > myScore { return .lost }
        return .tied
    }

    enum ChallengeResult {
        case won, lost, tied

        var label: String {
            switch self {
            case .won: return "You won."
            case .lost: return "They won."
            case .tied: return "It's a tie."
            }
        }

        var icon: String {
            switch self {
            case .won: return "trophy.fill"
            case .lost: return "hand.thumbsup"
            case .tied: return "equal.circle.fill"
            }
        }
    }

    func isCreatorPerspective(participantID: String) -> Bool {
        if participantID == creatorParticipantID || participantID == creatorID.uuidString { return true }
        if participantID == opponentParticipantID || participantID == opponentID.uuidString { return false }
        return true
    }
}

// MARK: - Challenges Manager

#if canImport(SwiftUI)

@MainActor
final class ChallengesManager: ObservableObject {
    static let shared = ChallengesManager()

    // Daily/weekly/streak challenges
    @Published private(set) var activeChallenges: [SpeakingChallenge2] = []
    @Published private(set) var completedChallenges: [SpeakingChallenge2] = []

    // Async friend challenges
    @Published private(set) var asyncChallenges: [AsyncChallenge] = []

    private let storageKey = "NoumChallenges"
    private let completedKey = "NoumCompletedChallenges"
    private let asyncKey = "NoumAsyncChallenges"

    private init() {
        activeChallenges = Self.load(key: "NoumChallenges")
        completedChallenges = Self.load(key: "NoumCompletedChallenges")
        asyncChallenges = Self.loadAsync()
        refreshChallengesIfNeeded()
    }

    // MARK: - Current User ID (local reference)

    private var currentUserID: UUID {
        if let idString = KeychainHelper.load(key: "NoumAccountID"),
           let uuid = UUID(uuidString: idString) {
            return uuid
        }
        return UUID()
    }

    private var currentParticipantID: String {
        KeychainHelper.load(key: "NoumAccountID") ?? currentUserID.uuidString
    }

    private var currentUserName: String {
        AuthManager.shared.currentAccountName ?? "You"
    }

    // MARK: - Session Progress

    func recordSession(mode: PracticeMode, fillerCount: Int, duration: TimeInterval) {
        for index in activeChallenges.indices {
            var challenge = activeChallenges[index]
            guard !challenge.isCompleted && !challenge.isExpired else { continue }

            switch challenge.category {
            case .daily, .weekly:
                challenge.current += 1
            case .streak:
                challenge.current += 1
            case .social:
                continue
            }

            if challenge.current >= challenge.goal {
                challenge.isCompleted = true
                completedChallenges.insert(challenge, at: 0)
            }

            activeChallenges[index] = challenge
        }

        persistActive()
        persistCompleted()
    }

    // MARK: - Challenge Generation

    private func refreshChallengesIfNeeded() {
        activeChallenges.removeAll { challenge in
            challenge.category == .social || (challenge.isExpired && !challenge.isCompleted)
        }

        let activeCategories = Set(activeChallenges.filter { !$0.isCompleted }.map(\.category))

        if !activeCategories.contains(.daily) {
            activeChallenges.append(generateChallenge(category: .daily))
        }
        if !activeCategories.contains(.weekly) {
            activeChallenges.append(generateChallenge(category: .weekly))
        }
        if !activeCategories.contains(.streak) {
            activeChallenges.append(generateChallenge(category: .streak))
        }

        persistActive()
    }

    private func generateChallenge(category: SpeakingChallenge2.Category) -> SpeakingChallenge2 {
        let calendar = Calendar.current
        let now = Date()

        switch category {
        case .daily:
            let templates: [(String, String, Int, Int)] = [
                ("Daily Rep", "Complete a practice session today", 1, 25),
                ("Double Down", "Complete 2 sessions today", 2, 50),
                ("Morning Speaker", "Complete a session today", 1, 30),
            ]
            let template = templates.randomElement()!
            return SpeakingChallenge2(
                id: UUID(), title: template.0, description: template.1,
                category: .daily, goal: template.2, current: 0,
                reward: .init(xp: template.3),
                startDate: now, endDate: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!,
                isCompleted: false
            )

        case .weekly:
            let templates: [(String, String, Int, Int)] = [
                ("Week Warrior", "Complete 5 sessions this week", 5, 150),
                ("Consistency Check", "Practice 4 days this week", 4, 120),
                ("Weekly Push", "Complete 7 sessions this week", 7, 200),
            ]
            let template = templates.randomElement()!
            return SpeakingChallenge2(
                id: UUID(), title: template.0, description: template.1,
                category: .weekly, goal: template.2, current: 0,
                reward: .init(xp: template.3),
                startDate: now, endDate: calendar.date(byAdding: .weekOfYear, value: 1, to: now)!,
                isCompleted: false
            )

        case .streak:
            return SpeakingChallenge2(
                id: UUID(), title: "3-Day Streak", description: "Practice 3 days in a row",
                category: .streak, goal: 3, current: 0,
                reward: .init(xp: 100, badge: "flame.fill"),
                startDate: now, endDate: calendar.date(byAdding: .day, value: 7, to: now)!,
                isCompleted: false
            )

        case .social:
            return SpeakingChallenge2(
                id: UUID(), title: "Linked Speak-off", description: "Complete a scored speak-off with a linked Noum friend",
                category: .social, goal: 1, current: 0,
                reward: .init(xp: 75, badge: "person.2.fill"),
                startDate: now, endDate: calendar.date(byAdding: .day, value: 14, to: now)!,
                isCompleted: false
            )
        }
    }

    // MARK: - Async Friend Challenges

    /// Create a new async challenge with a friend. Both get the same prompt.
    /// The challenge is mirrored to the backend so the opponent can pick it
    /// up on their device.
    @discardableResult
    func createAsyncChallenge(opponentID: UUID, opponentName: String, opponentAccountID: String? = nil) -> AsyncChallenge {
        let creatorID = currentUserID
        let creatorAccountID = KeychainHelper.load(key: "NoumAccountID") ?? creatorID.uuidString
        let challenge = AsyncChallenge(
            id: UUID(),
            prompt: PracticeTopics.random(),
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            creatorID: creatorID,
            creatorName: currentUserName,
            creatorAccountID: creatorAccountID,
            opponentID: opponentID,
            opponentName: opponentName,
            opponentAccountID: opponentAccountID
        )
        asyncChallenges.insert(challenge, at: 0)
        persistAsync()
        Task { await BackendSyncManager.shared.syncAsyncChallenge(challenge) }
        return challenge
    }

    /// Record the current user's score after completing an async challenge.
    /// Writes the local cache and pushes the slice the user is allowed to
    /// edit (their own fields) to the backend. The other side stays nil until
    /// a real opponent submission arrives through `refreshFromBackend()`.
    func recordAsyncResult(challengeID: UUID, score: Int, duration: TimeInterval, summary: String?) {
        guard let index = asyncChallenges.firstIndex(where: { $0.id == challengeID }) else { return }
        let isCreator = asyncChallenges[index].isCreatorPerspective(participantID: currentParticipantID)

        if isCreator {
            asyncChallenges[index].creatorScore = score
            asyncChallenges[index].creatorDuration = duration
            asyncChallenges[index].creatorSummary = summary
        } else {
            asyncChallenges[index].opponentScore = score
            asyncChallenges[index].opponentDuration = duration
            asyncChallenges[index].opponentSummary = summary
        }

        let updated = asyncChallenges[index]
        persistAsync()
        Task { await BackendSyncManager.shared.syncAsyncChallenge(updated) }

        // No opponent fabrication: a real rep must never be resolved against a
        // generated opponent score. The challenge stays honestly pending until
        // real Firestore data arrives via refreshFromBackend().
    }

    /// Add a reaction to a completed challenge. Synced server-side.
    func addReaction(challengeID: UUID, reaction: AsyncChallenge.Reaction) {
        guard let index = asyncChallenges.firstIndex(where: { $0.id == challengeID }) else { return }
        let isCreator = asyncChallenges[index].isCreatorPerspective(participantID: currentParticipantID)

        if isCreator {
            asyncChallenges[index].creatorReaction = reaction
        } else {
            asyncChallenges[index].opponentReaction = reaction
        }
        let updated = asyncChallenges[index]
        persistAsync()
        Task { await BackendSyncManager.shared.syncAsyncChallenge(updated) }
    }

    /// Pull challenges where the current user is a participant. Used at
    /// app launch and when the social profile screen appears, so the
    /// opponent's submission and reactions show up without a round-trip.
    func refreshFromBackend() async {
        let participantID = currentParticipantID
        let remote = await BackendSyncManager.shared.fetchAsyncChallenges(forParticipant: participantID)
        guard !remote.isEmpty else { return }

        // Merge: server-side wins for fields already set there. Local wins
        // for fields not yet known to the backend (e.g. user just played and
        // the network is still in flight).
        var merged: [UUID: AsyncChallenge] = [:]
        for local in asyncChallenges { merged[local.id] = local }
        for remoteChallenge in remote {
            if var existing = merged[remoteChallenge.id] {
                existing.creatorScore = remoteChallenge.creatorScore ?? existing.creatorScore
                existing.creatorDuration = remoteChallenge.creatorDuration ?? existing.creatorDuration
                existing.creatorSummary = remoteChallenge.creatorSummary ?? existing.creatorSummary
                existing.creatorReaction = remoteChallenge.creatorReaction ?? existing.creatorReaction
                existing.opponentScore = remoteChallenge.opponentScore ?? existing.opponentScore
                existing.opponentDuration = remoteChallenge.opponentDuration ?? existing.opponentDuration
                existing.opponentSummary = remoteChallenge.opponentSummary ?? existing.opponentSummary
                existing.opponentReaction = remoteChallenge.opponentReaction ?? existing.opponentReaction
                merged[remoteChallenge.id] = existing
            } else {
                merged[remoteChallenge.id] = remoteChallenge
            }
        }
        asyncChallenges = merged.values.sorted { $0.createdAt > $1.createdAt }
        persistAsync()
    }

    /// Active async challenges (not expired, not both completed)
    var activeAsyncChallenges: [AsyncChallenge] {
        asyncChallenges.filter { !$0.isExpired || $0.bothHavePlayed }
    }

    /// Challenges waiting for the current user's response
    var pendingAsyncChallenges: [AsyncChallenge] {
        let participantID = currentParticipantID
        return asyncChallenges.filter {
            let status = $0.status(forParticipantID: participantID)
            return status == .pending || status == .yourTurn
        }
    }

    /// Completed async challenges
    var completedAsyncChallenges: [AsyncChallenge] {
        asyncChallenges.filter { $0.bothHavePlayed }
    }

    // MARK: - Persistence

    private func persistActive() {
        guard let data = try? JSONEncoder().encode(activeChallenges) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func persistCompleted() {
        guard let data = try? JSONEncoder().encode(completedChallenges) else { return }
        UserDefaults.standard.set(data, forKey: completedKey)
    }

    private func persistAsync() {
        guard let data = try? JSONEncoder().encode(asyncChallenges) else { return }
        UserDefaults.standard.set(data, forKey: asyncKey)
    }

    private static func load(key: String) -> [SpeakingChallenge2] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let challenges = try? JSONDecoder().decode([SpeakingChallenge2].self, from: data) else {
            return []
        }
        return challenges
    }

    private static func loadAsync() -> [AsyncChallenge] {
        guard let data = UserDefaults.standard.data(forKey: "NoumAsyncChallenges"),
              let challenges = try? JSONDecoder().decode([AsyncChallenge].self, from: data) else {
            return []
        }
        return challenges
    }
}

#endif
