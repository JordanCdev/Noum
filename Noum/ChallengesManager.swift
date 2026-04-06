import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Challenge Model (daily/weekly/streak/social)

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
    let opponentID: UUID
    let opponentName: String

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

    /// Status from the perspective of a given user ID
    func status(forUser userID: UUID) -> Status {
        let isCreator = userID == creatorID
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
        userID == creatorID ? opponentName : creatorName
    }

    /// Get the winner from the perspective of the user
    func result(forUser userID: UUID) -> ChallengeResult? {
        guard let cs = creatorScore, let os = opponentScore else { return nil }
        let isCreator = userID == creatorID
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
            case .won: return "You won!"
            case .lost: return "They won"
            case .tied: return "It's a tie"
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

    func recordSocialAction() {
        for index in activeChallenges.indices {
            var challenge = activeChallenges[index]
            guard challenge.category == .social && !challenge.isCompleted else { continue }

            challenge.current += 1
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
        activeChallenges.removeAll { $0.isExpired && !$0.isCompleted }

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
        if !activeCategories.contains(.social) {
            activeChallenges.append(generateChallenge(category: .social))
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
                id: UUID(), title: "Grow Your Circle", description: "Add a friend to your speaking network",
                category: .social, goal: 1, current: 0,
                reward: .init(xp: 75, badge: "person.2.fill"),
                startDate: now, endDate: calendar.date(byAdding: .day, value: 14, to: now)!,
                isCompleted: false
            )
        }
    }

    // MARK: - Async Friend Challenges

    /// Create a new async challenge with a friend. Both get the same prompt.
    @discardableResult
    func createAsyncChallenge(opponentID: UUID, opponentName: String) -> AsyncChallenge {
        let challenge = AsyncChallenge(
            id: UUID(),
            prompt: PracticeTopics.random(),
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            creatorID: currentUserID,
            creatorName: currentUserName,
            opponentID: opponentID,
            opponentName: opponentName
        )
        asyncChallenges.insert(challenge, at: 0)
        persistAsync()
        return challenge
    }

    /// Record the current user's score after completing an async challenge
    func recordAsyncResult(challengeID: UUID, score: Int, duration: TimeInterval, summary: String?) {
        guard let index = asyncChallenges.firstIndex(where: { $0.id == challengeID }) else { return }
        let isCreator = asyncChallenges[index].creatorID == currentUserID

        if isCreator {
            asyncChallenges[index].creatorScore = score
            asyncChallenges[index].creatorDuration = duration
            asyncChallenges[index].creatorSummary = summary
        } else {
            asyncChallenges[index].opponentScore = score
            asyncChallenges[index].opponentDuration = duration
            asyncChallenges[index].opponentSummary = summary
        }

        // Simulate opponent response (local-first MVP — later replaced by server sync)
        if !asyncChallenges[index].bothHavePlayed {
            simulateOpponentResponse(challengeID: challengeID)
        }

        persistAsync()
    }

    /// Add a reaction to a completed challenge
    func addReaction(challengeID: UUID, reaction: AsyncChallenge.Reaction) {
        guard let index = asyncChallenges.firstIndex(where: { $0.id == challengeID }) else { return }
        let isCreator = asyncChallenges[index].creatorID == currentUserID

        if isCreator {
            asyncChallenges[index].creatorReaction = reaction
        } else {
            asyncChallenges[index].opponentReaction = reaction
        }
        persistAsync()
    }

    /// Simulate the opponent's response (for local-only MVP)
    private func simulateOpponentResponse(challengeID: UUID) {
        guard let index = asyncChallenges.firstIndex(where: { $0.id == challengeID }) else { return }
        let isCreator = asyncChallenges[index].creatorID == currentUserID

        // Simulate after a brief delay to feel async
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 2...5)))
            await MainActor.run {
                guard let idx = asyncChallenges.firstIndex(where: { $0.id == challengeID }) else { return }
                let simScore = Int.random(in: 45...92)
                let simDuration = TimeInterval.random(in: 40...110)

                if isCreator {
                    asyncChallenges[idx].opponentScore = simScore
                    asyncChallenges[idx].opponentDuration = simDuration
                    asyncChallenges[idx].opponentSummary = "Solid impromptu response with good structure."
                    // Random reaction from opponent
                    asyncChallenges[idx].opponentReaction = AsyncChallenge.Reaction.allCases.randomElement()
                } else {
                    asyncChallenges[idx].creatorScore = simScore
                    asyncChallenges[idx].creatorDuration = simDuration
                    asyncChallenges[idx].creatorSummary = "Good pacing with clear opening and close."
                    asyncChallenges[idx].creatorReaction = AsyncChallenge.Reaction.allCases.randomElement()
                }
                persistAsync()
            }
        }
    }

    /// Active async challenges (not expired, not both completed)
    var activeAsyncChallenges: [AsyncChallenge] {
        asyncChallenges.filter { !$0.isExpired || $0.bothHavePlayed }
    }

    /// Challenges waiting for the current user's response
    var pendingAsyncChallenges: [AsyncChallenge] {
        let uid = currentUserID
        return asyncChallenges.filter {
            let status = $0.status(forUser: uid)
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
