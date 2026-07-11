import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Challenge Model (daily/weekly/streak; social is legacy)

struct SpeakingChallenge2: Codable, Identifiable, Equatable, Sendable {
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

    enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
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

    struct Reward: Codable, Equatable, Sendable {
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

struct AsyncChallenge: Codable, Identifiable, Equatable, Sendable {
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

    enum Reaction: String, Codable, CaseIterable, Identifiable, Sendable {
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

struct ChallengesAccountDataSnapshot: Codable, Equatable, Sendable {
    let active: [SpeakingChallenge2]
    let completed: [SpeakingChallenge2]
    let asyncChallenges: [AsyncChallenge]
    let armedRep: ArmedAsyncChallengeRep?
}

struct ArmedAsyncChallengeRep: Codable, Equatable, Sendable {
    let challengeID: UUID
    let prompt: String
    let armedAt: Date
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
    @Published private(set) var pendingAuthorityIntent: AsyncChallengeAuthorityIntent?
    @Published private(set) var lastAuthorityFailure: AsyncChallengeAuthorityFailure?
    @Published private(set) var armedRep: ArmedAsyncChallengeRep?

    private let storageKey = "NoumChallenges"
    private let completedKey = "NoumCompletedChallenges"
    private let asyncKey = "NoumAsyncChallenges"
    private let armedRepKey = "NoumAsyncChallengeArmedRep"

    private init() {
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? "guest"
        Self.migrateLegacyDataIfNeeded(accountID: accountID)
        activeChallenges = Self.load(key: Self.accountKey(base: "NoumChallenges", accountID: accountID))
        completedChallenges = Self.load(key: Self.accountKey(base: "NoumCompletedChallenges", accountID: accountID))
        asyncChallenges = Self.loadAsync(key: Self.accountKey(base: "NoumAsyncChallenges", accountID: accountID))
        armedRep = Self.loadArmedRep(key: Self.accountKey(base: "NoumAsyncChallengeArmedRep", accountID: accountID))
        refreshChallengesIfNeeded()
    }

    // MARK: - Current User ID (local reference)

    private var currentParticipantID: String {
        KeychainHelper.load(key: "NoumAccountID") ?? ""
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

    /// Create a challenge only after the server has derived both participant
    /// identities and timestamps. A failed create never produces a local
    /// "ready" card; its stable request is retained for retry.
    @discardableResult
    func createAsyncChallenge(
        opponentAccountID: String,
        challengeID: UUID = UUID(),
        prompt: String? = nil
    ) async -> AsyncChallenge? {
        let request = CreateChallengeRequest(
            challengeID: challengeID,
            opponentAccountID: opponentAccountID,
            prompt: prompt ?? PracticeTopics.random()
        )
        return await performAuthorityIntent(.create(request))
    }

    /// Submit a stored session ID; score, duration, summary, participant side,
    /// and server timestamp are intentionally absent. The local result fields
    /// change only after an authoritative challenge envelope returns.
    @discardableResult
    func recordAsyncResult(challengeID: UUID, sessionID: UUID) async -> Bool {
        let request = SubmitChallengeResultRequest(
            challengeID: challengeID,
            sessionID: sessionID
        )
        return await performAuthorityIntent(.submit(request)) != nil
    }

    /// Reactions are optimistic only at the interaction level (the button can
    /// remain responsive); the displayed challenge mutates after server ack.
    @discardableResult
    func addReaction(
        challengeID: UUID,
        reaction: AsyncChallenge.Reaction
    ) async -> Bool {
        let request = SetChallengeReactionRequest(
            challengeID: challengeID,
            reaction: reaction
        )
        return await performAuthorityIntent(.reaction(request)) != nil
    }

    @discardableResult
    func retryLastFailedAuthorityOperation() async -> AsyncChallenge? {
        guard let failure = lastAuthorityFailure else { return nil }
        return await performAuthorityIntent(failure.intent)
    }

    private func performAuthorityIntent(
        _ intent: AsyncChallengeAuthorityIntent
    ) async -> AsyncChallenge? {
        guard pendingAuthorityIntent == nil else { return nil }
        pendingAuthorityIntent = intent
        lastAuthorityFailure = nil
        defer { pendingAuthorityIntent = nil }

        do {
            let result: ChallengeMutationAuthorityResult
            switch intent {
            case .create(let request):
                result = try await BackendSyncManager.shared.createChallenge(request)

            case .submit(let request):
                guard let sessionID = UUID(uuidString: request.sessionID),
                      let session = PracticeSessionStore.shared.sessions.first(where: { $0.id == sessionID }),
                      let accountID = AuthManager.shared.currentAccountID,
                      let providerRawValue = AuthManager.shared.currentAuthProviderRawValue else {
                    throw SocialAuthorityError.sessionUnavailable
                }
                result = try await BackendSyncManager.shared.submitChallengeResult(
                    request,
                    session: session,
                    accountID: accountID,
                    providerRawValue: providerRawValue
                )

            case .reaction(let request):
                result = try await BackendSyncManager.shared.setChallengeReaction(request)
            }

            upsertAuthoritativeChallenge(result.challenge)
            return result.challenge
        } catch {
            let authorityError = error as? SocialAuthorityError
            lastAuthorityFailure = AsyncChallengeAuthorityFailure(
                intent: intent,
                message: error.localizedDescription,
                isRetryable: authorityError?.isRetryable ?? true
            )
            return nil
        }
    }

    private func upsertAuthoritativeChallenge(_ challenge: AsyncChallenge) {
        asyncChallenges.removeAll { $0.id == challenge.id }
        asyncChallenges.append(challenge)
        asyncChallenges.sort { $0.createdAt > $1.createdAt }
        persistAsync()
    }

    /// Arms the exact server-created prompt before navigating into Timed
    /// Practice. The resulting session must carry the same prompt or it cannot
    /// be submitted to the speak-off.
    func armSubmission(for challenge: AsyncChallenge) {
        armedRep = ArmedAsyncChallengeRep(
            challengeID: challenge.id,
            prompt: challenge.prompt,
            armedAt: Date()
        )
        persistArmedRep()
    }

    @discardableResult
    func submitArmedResultIfMatching(sessionID: UUID) async -> Bool {
        guard let armedRep,
              let session = PracticeSessionStore.shared.sessions.first(where: { $0.id == sessionID }),
              Self.repMatchesArmedPrompt(sessionPrompt: session.prompt, armedPrompt: armedRep.prompt) else {
            return false
        }
        let submitted = await recordAsyncResult(
            challengeID: armedRep.challengeID,
            sessionID: session.id
        )
        if submitted {
            self.armedRep = nil
            persistArmedRep()
        }
        return submitted
    }

    nonisolated static func repMatchesArmedPrompt(
        sessionPrompt: String?,
        armedPrompt: String
    ) -> Bool {
        guard let sessionPrompt else { return false }
        let normalize: (String) -> String = {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .lowercased()
        }
        let expected = normalize(armedPrompt)
        return !expected.isEmpty && normalize(sessionPrompt) == expected
    }

    /// Pull challenges where the current user is a participant. Used at
    /// app launch and when the social profile screen appears, so the
    /// opponent's submission and reactions show up without a round-trip.
    func refreshFromBackend() async {
        let participantID = currentParticipantID
        let remote = await BackendSyncManager.shared.fetchAsyncChallenges(forParticipant: participantID)
        guard !remote.isEmpty else { return }

        // The server envelope replaces every field for a matching challenge,
        // including nil results. Retaining a client-cached score after the
        // server says that side has not submitted would create a false result.
        // Local-only legacy rows remain until a successful server copy for the
        // same ID arrives; writes never originate from those rows.
        var merged: [UUID: AsyncChallenge] = [:]
        for local in asyncChallenges { merged[local.id] = local }
        for remoteChallenge in remote {
            merged[remoteChallenge.id] = remoteChallenge
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
        UserDefaults.standard.set(data, forKey: scopedKey(storageKey))
    }

    private func persistCompleted() {
        guard let data = try? JSONEncoder().encode(completedChallenges) else { return }
        UserDefaults.standard.set(data, forKey: scopedKey(completedKey))
    }

    private func persistAsync() {
        guard let data = try? JSONEncoder().encode(asyncChallenges) else { return }
        UserDefaults.standard.set(data, forKey: scopedKey(asyncKey))
    }

    private func persistArmedRep() {
        let key = scopedKey(armedRepKey)
        guard let armedRep else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(armedRep) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load(key: String) -> [SpeakingChallenge2] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let challenges = try? JSONDecoder().decode([SpeakingChallenge2].self, from: data) else {
            return []
        }
        return challenges
    }

    private static func loadAsync(key: String) -> [AsyncChallenge] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let challenges = try? JSONDecoder().decode([AsyncChallenge].self, from: data) else {
            return []
        }
        return challenges
    }

    private static func loadArmedRep(key: String) -> ArmedAsyncChallengeRep? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ArmedAsyncChallengeRep.self, from: data)
    }

    private func scopedKey(_ base: String) -> String {
        Self.accountKey(base: base, accountID: currentParticipantID.isEmpty ? "guest" : currentParticipantID)
    }

    nonisolated static func accountKey(base: String, accountID: String) -> String {
        "\(base).\(accountID)"
    }

    private static func migrateLegacyDataIfNeeded(accountID: String) {
        guard accountID != "guest" else { return }
        for base in ["NoumChallenges", "NoumCompletedChallenges", "NoumAsyncChallenges", "NoumAsyncChallengeArmedRep"] {
            let scoped = accountKey(base: base, accountID: accountID)
            guard UserDefaults.standard.data(forKey: scoped) == nil,
                  let legacy = UserDefaults.standard.data(forKey: base) else { continue }
            UserDefaults.standard.set(legacy, forKey: scoped)
            UserDefaults.standard.removeObject(forKey: base)
        }
    }

    func reloadForCurrentAccount() {
        Self.migrateLegacyDataIfNeeded(accountID: currentParticipantID.isEmpty ? "guest" : currentParticipantID)
        activeChallenges = Self.load(key: scopedKey(storageKey))
        completedChallenges = Self.load(key: scopedKey(completedKey))
        asyncChallenges = Self.loadAsync(key: scopedKey(asyncKey))
        armedRep = Self.loadArmedRep(key: scopedKey(armedRepKey))
        pendingAuthorityIntent = nil
        lastAuthorityFailure = nil
        refreshChallengesIfNeeded()
    }

    func endSession() {
        activeChallenges = []
        completedChallenges = []
        asyncChallenges = []
        armedRep = nil
        pendingAuthorityIntent = nil
        lastAuthorityFailure = nil
    }

    func exportSnapshot(for accountID: String) -> ChallengesAccountDataSnapshot {
        ChallengesAccountDataSnapshot(
            active: Self.load(key: Self.accountKey(base: storageKey, accountID: accountID)),
            completed: Self.load(key: Self.accountKey(base: completedKey, accountID: accountID)),
            asyncChallenges: Self.loadAsync(key: Self.accountKey(base: asyncKey, accountID: accountID)),
            armedRep: Self.loadArmedRep(key: Self.accountKey(base: armedRepKey, accountID: accountID))
        )
    }

    func deleteAllData(for accountID: String) {
        for base in [storageKey, completedKey, asyncKey, armedRepKey] {
            UserDefaults.standard.removeObject(forKey: Self.accountKey(base: base, accountID: accountID))
        }
        if currentParticipantID == accountID {
            endSession()
        }
    }
}

#endif
