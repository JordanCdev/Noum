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
}

struct ArmedAsyncChallengeRep: Equatable, Sendable {
    let challengeID: UUID
    let prompt: String
    let routeToken: UUID
    let expiresAt: Date
    let armedAt: Date
    let boundSessionID: UUID?

    var isBound: Bool { boundSessionID != nil }

    func canCancel(matchingRouteToken routeToken: UUID) -> Bool {
        self.routeToken == routeToken && !isBound
    }

    func binding(
        routeToken: UUID,
        sessionID: UUID,
        sessionPrompt: String?,
        now: Date = Date()
    ) -> ArmedAsyncChallengeRep? {
        guard self.routeToken == routeToken,
              boundSessionID == nil,
              expiresAt > now,
              Self.promptBytesMatch(sessionPrompt, prompt) else {
            return nil
        }
        return ArmedAsyncChallengeRep(
            challengeID: challengeID,
            prompt: prompt,
            routeToken: self.routeToken,
            expiresAt: expiresAt,
            armedAt: armedAt,
            boundSessionID: sessionID
        )
    }

    func permitsSubmission(
        sessionID: UUID,
        sessionPrompt: String?,
        now: Date = Date()
    ) -> Bool {
        boundSessionID == sessionID
            && expiresAt > now
            && Self.promptBytesMatch(sessionPrompt, prompt)
    }

    private static func promptBytesMatch(_ candidate: String?, _ exact: String) -> Bool {
        guard let candidate, !exact.isEmpty else { return false }
        return candidate.utf8.elementsEqual(exact.utf8)
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
    @Published private(set) var pendingAuthorityIntent: AsyncChallengeAuthorityIntent?
    @Published private(set) var lastAuthorityFailure: AsyncChallengeAuthorityFailure?
    @Published private(set) var armedRep: ArmedAsyncChallengeRep?

    private let storageKey = "NoumChallenges"
    private let completedKey = "NoumCompletedChallenges"
    private let asyncKey = "NoumAsyncChallenges"
    private let legacyArmedRepKey = "NoumAsyncChallengeArmedRep"
    private var activeAccountID: String?
    private var accountGeneration: UInt64 = 0
    private var isSessionActive = true

    private init() {
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? "guest"
        activeAccountID = accountID
        Self.purgeLegacyArmedRepPersistence()
        Self.migrateLegacyDataIfNeeded(accountID: accountID)
        activeChallenges = Self.load(key: Self.accountKey(base: "NoumChallenges", accountID: accountID))
        completedChallenges = Self.load(key: Self.accountKey(base: "NoumCompletedChallenges", accountID: accountID))
        asyncChallenges = Self.loadAsync(key: Self.accountKey(base: "NoumAsyncChallenges", accountID: accountID))
        armedRep = nil
        refreshChallengesIfNeeded()
    }

    // MARK: - Current User ID (local reference)

    private var currentParticipantID: String {
        activeAccountID ?? ""
    }

    // MARK: - Session Progress

    func recordSession(mode: PracticeMode, fillerCount: Int, duration: TimeInterval) {
        guard isSessionActive, activeAccountID != nil else { return }
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
        guard SocialReleaseCapabilities.speakOffs.isAvailable else {
            lastAuthorityFailure = nil
            return nil
        }
        guard let failure = lastAuthorityFailure else { return nil }
        let result = await performAuthorityIntent(failure.intent)
        if result != nil,
           case .submit(let request) = failure.intent,
           let challengeID = UUID(uuidString: request.challengeID),
           let sessionID = UUID(uuidString: request.sessionID),
           armedRep?.challengeID == challengeID,
           armedRep?.boundSessionID == sessionID {
            armedRep = nil
        }
        return result
    }

    private func performAuthorityIntent(
        _ intent: AsyncChallengeAuthorityIntent
    ) async -> AsyncChallenge? {
        guard SocialReleaseCapabilities.speakOffs.isAvailable else {
            lastAuthorityFailure = nil
            return nil
        }
        guard let context = captureOperationContext(),
              pendingAuthorityIntent == nil else { return nil }
        pendingAuthorityIntent = intent
        lastAuthorityFailure = nil
        defer {
            if isOperationContextCurrent(context), pendingAuthorityIntent == intent {
                pendingAuthorityIntent = nil
            }
        }

        do {
            let result: ChallengeMutationAuthorityResult
            switch intent {
            case .create(let request):
                result = try await BackendSyncManager.shared.createChallenge(request)

            case .submit(let request):
                guard let sessionID = UUID(uuidString: request.sessionID),
                      let session = PracticeSessionStore.shared.sessions.first(where: { $0.id == sessionID }),
                      let providerRawValue = AuthManager.shared.currentAuthProviderRawValue else {
                    throw SocialAuthorityError.sessionUnavailable
                }
                result = try await BackendSyncManager.shared.submitChallengeResult(
                    request,
                    session: session,
                    accountID: context.accountID,
                    providerRawValue: providerRawValue
                )

            case .reaction(let request):
                result = try await BackendSyncManager.shared.setChallengeReaction(request)
            }

            guard isOperationContextCurrent(context) else { return nil }
            upsertAuthoritativeChallenge(result.challenge, context: context)
            return result.challenge
        } catch {
            guard isOperationContextCurrent(context) else { return nil }
            let authorityError = error as? SocialAuthorityError
            lastAuthorityFailure = AsyncChallengeAuthorityFailure(
                intent: intent,
                message: error.localizedDescription,
                isRetryable: authorityError?.isRetryable ?? true
            )
            return nil
        }
    }

    private func upsertAuthoritativeChallenge(
        _ challenge: AsyncChallenge,
        context: SocialAccountOperationContext
    ) {
        guard isOperationContextCurrent(context) else { return }
        asyncChallenges.removeAll { $0.id == challenge.id }
        asyncChallenges.append(challenge)
        asyncChallenges.sort { $0.createdAt > $1.createdAt }
        persistAsync(context: context)
    }

    /// Arms only after Timed Practice consumes the exact account-bound route.
    /// This is a process-local lease, not durable challenge history: the route
    /// token disappears on relaunch, so persisting the prompt would resurrect
    /// authority that can no longer prove where it came from.
    @discardableResult
    func armSubmission(
        challengeID: UUID,
        exactPrompt: String,
        routeToken: UUID,
        now: Date = Date()
    ) -> Bool {
        guard SocialReleaseCapabilities.speakOffs.isAvailable,
              let context = captureOperationContext(),
              let challenge = asyncChallenges.first(where: { $0.id == challengeID }),
              let candidate = Self.armedRepCandidate(
                challenge: challenge,
                participantID: context.accountID,
                exactPrompt: exactPrompt,
                routeToken: routeToken,
                now: now
              ) else {
            return false
        }
        armedRep = candidate
        return true
    }

    nonisolated static func armedRepCandidate(
        challenge: AsyncChallenge,
        participantID: String,
        exactPrompt: String,
        routeToken: UUID,
        now: Date
    ) -> ArmedAsyncChallengeRep? {
        guard challenge.participantIDs.contains(participantID),
              challenge.expiresAt > now,
              challenge.prompt.utf8.elementsEqual(exactPrompt.utf8) else {
            return nil
        }
        let isCreator = challenge.isCreatorPerspective(participantID: participantID)
        guard isCreator ? !challenge.creatorHasPlayed : !challenge.opponentHasPlayed else {
            return nil
        }
        return ArmedAsyncChallengeRep(
            challengeID: challenge.id,
            prompt: challenge.prompt,
            routeToken: routeToken,
            expiresAt: challenge.expiresAt,
            armedAt: now,
            boundSessionID: nil
        )
    }

    /// Binds the route lease to the exact session persisted by the speech
    /// owner. Summary may then disappear without racing submission cleanup.
    @discardableResult
    func bindArmedSubmission(
        matchingRouteToken routeToken: UUID,
        sessionID: UUID,
        sessionPrompt: String?,
        now: Date = Date()
    ) -> Bool {
        guard SocialReleaseCapabilities.speakOffs.isAvailable,
              captureOperationContext() != nil,
              let bound = armedRep?.binding(
                routeToken: routeToken,
                sessionID: sessionID,
                sessionPrompt: sessionPrompt,
                now: now
              ) else {
            return false
        }
        armedRep = bound
        return true
    }

    /// Cancels only an unbound lease for this exact route. A stale Timed view
    /// cannot erase a newer route, and the Timed-to-Summary transition cannot
    /// erase a lease already bound to its saved session.
    func disarmSubmission(matchingRouteToken routeToken: UUID) {
        guard armedRep?.canCancel(matchingRouteToken: routeToken) == true else { return }
        armedRep = nil
    }

    @discardableResult
    func submitArmedResultIfMatching(sessionID: UUID) async -> Bool {
        guard SocialReleaseCapabilities.speakOffs.isAvailable,
              let context = captureOperationContext(),
              let armedRep,
              let session = PracticeSessionStore.shared.sessions.first(where: { $0.id == sessionID }) else {
            return false
        }
        guard armedRep.permitsSubmission(
            sessionID: sessionID,
            sessionPrompt: session.prompt
        ) else {
            if armedRep.expiresAt <= Date(), self.armedRep == armedRep {
                self.armedRep = nil
            }
            return false
        }
        let submitted = await recordAsyncResult(
            challengeID: armedRep.challengeID,
            sessionID: session.id
        )
        let terminalFailure = lastAuthorityFailure.map {
            !$0.isRetryable
                && $0.intent.challengeID == armedRep.challengeID.uuidString
        } ?? false
        if (submitted || terminalFailure),
           isOperationContextCurrent(context),
           self.armedRep == armedRep {
            self.armedRep = nil
        }
        return submitted
    }

    nonisolated static func repMatchesArmedPrompt(
        sessionPrompt: String?,
        armedPrompt: String
    ) -> Bool {
        guard let sessionPrompt, !armedPrompt.isEmpty else { return false }
        return sessionPrompt.utf8.elementsEqual(armedPrompt.utf8)
    }

    /// Pull challenges where the current user is a participant. Used at
    /// app launch and when the social profile screen appears, so the
    /// opponent's submission and reactions show up without a round-trip.
    func refreshFromBackend(
        fetch: @Sendable (String) async -> BackendAsyncChallengeFetchResult = { participantID in
            await BackendSyncManager.shared.fetchAsyncChallenges(forParticipant: participantID)
        }
    ) async {
        guard SocialReleaseCapabilities.speakOffs.isAvailable else { return }
        guard let context = captureOperationContext() else { return }
        let result = await fetch(context.accountID)
        guard isOperationContextCurrent(context) else { return }
        guard let reconciled = Self.reconcileHydratedChallenges(
            cached: asyncChallenges,
            result: result
        ) else { return }
        asyncChallenges = reconciled
        persistAsync(context: context)
    }

    /// A successful, untruncated metadata query is authoritative for removals,
    /// including a genuinely empty collection. Query failures leave the cache
    /// unchanged. If the capped query may have older rows, or any returned row
    /// failed to hydrate, successful rows may advance the cache but no cached
    /// row is removed from that partial view.
    nonisolated static func reconcileHydratedChallenges(
        cached: [AsyncChallenge],
        result: BackendAsyncChallengeFetchResult
    ) -> [AsyncChallenge]? {
        switch result {
        case .capabilityUnavailable, .unavailable:
            return nil

        case .success(let snapshot):
            let base = snapshot.isAuthoritativeForRemovals
                ? cached.filter { snapshot.contains($0.id) }
                : cached
            return mergeHydratedChallenges(
                cached: base,
                remote: snapshot.challenges
            )
        }
    }

    nonisolated static func mergeHydratedChallenges(
        cached: [AsyncChallenge],
        remote: [AsyncChallenge]
    ) -> [AsyncChallenge] {
        var merged = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        for challenge in remote {
            if let existing = merged[challenge.id],
               authorityEvidenceCount(challenge) < authorityEvidenceCount(existing) {
                continue
            }
            merged[challenge.id] = challenge
        }
        return merged.values.sorted { $0.createdAt > $1.createdAt }
    }

    nonisolated private static func authorityEvidenceCount(_ challenge: AsyncChallenge) -> Int {
        [
            challenge.creatorScore != nil,
            challenge.creatorDuration != nil,
            challenge.creatorSummary != nil,
            challenge.opponentScore != nil,
            challenge.opponentDuration != nil,
            challenge.opponentSummary != nil,
            challenge.creatorReaction != nil,
            challenge.opponentReaction != nil,
        ].filter { $0 }.count
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

    private func persistActive(context: SocialAccountOperationContext? = nil) {
        guard canPersist(context: context), let key = scopedKey(storageKey) else { return }
        guard let data = try? JSONEncoder().encode(activeChallenges) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func persistCompleted(context: SocialAccountOperationContext? = nil) {
        guard canPersist(context: context), let key = scopedKey(completedKey) else { return }
        guard let data = try? JSONEncoder().encode(completedChallenges) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func persistAsync(context: SocialAccountOperationContext? = nil) {
        guard canPersist(context: context), let key = scopedKey(asyncKey) else { return }
        guard let data = try? JSONEncoder().encode(asyncChallenges) else { return }
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

    private func scopedKey(_ base: String) -> String? {
        guard let activeAccountID else { return nil }
        return Self.accountKey(base: base, accountID: activeAccountID)
    }

    private func canPersist(context: SocialAccountOperationContext?) -> Bool {
        guard isSessionActive, activeAccountID != nil else { return false }
        return context.map(isOperationContextCurrent) ?? true
    }

    nonisolated static func accountKey(base: String, accountID: String) -> String {
        "\(base).\(accountID)"
    }

    private static func migrateLegacyDataIfNeeded(accountID: String) {
        guard accountID != "guest" else { return }
        for base in ["NoumChallenges", "NoumCompletedChallenges", "NoumAsyncChallenges"] {
            let scoped = accountKey(base: base, accountID: accountID)
            guard UserDefaults.standard.data(forKey: scoped) == nil,
                  let legacy = UserDefaults.standard.data(forKey: base) else { continue }
            UserDefaults.standard.set(legacy, forKey: scoped)
            UserDefaults.standard.removeObject(forKey: base)
        }
    }

    func reloadForCurrentAccount() {
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? "guest"
        accountGeneration &+= 1
        activeAccountID = accountID
        isSessionActive = true
        Self.purgeLegacyArmedRepPersistence()
        Self.migrateLegacyDataIfNeeded(accountID: accountID)
        activeChallenges = Self.load(key: Self.accountKey(base: storageKey, accountID: accountID))
        completedChallenges = Self.load(key: Self.accountKey(base: completedKey, accountID: accountID))
        asyncChallenges = Self.loadAsync(key: Self.accountKey(base: asyncKey, accountID: accountID))
        armedRep = nil
        pendingAuthorityIntent = nil
        lastAuthorityFailure = nil
        refreshChallengesIfNeeded()
    }

    func endSession() {
        accountGeneration &+= 1
        activeAccountID = nil
        isSessionActive = false
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
            asyncChallenges: Self.loadAsync(key: Self.accountKey(base: asyncKey, accountID: accountID))
        )
    }

    func deleteAllData(for accountID: String) {
        for base in [storageKey, completedKey, asyncKey, legacyArmedRepKey] {
            UserDefaults.standard.removeObject(forKey: Self.accountKey(base: base, accountID: accountID))
        }
        if activeAccountID == accountID {
            endSession()
        }
    }

    /// Removes the historical prompt-bearing pre-route archive. Route tokens
    /// were always process-local, so no persisted row can retain valid proof
    /// after a relaunch. Purging every scoped key also prevents an inactive
    /// account's prompt from surviving until a later switch-back.
    nonisolated static func purgeLegacyArmedRepPersistence(
        defaults: UserDefaults = .standard
    ) {
        let base = "NoumAsyncChallengeArmedRep"
        for key in defaults.dictionaryRepresentation().keys
            where key == base || key.hasPrefix("\(base).") {
            defaults.removeObject(forKey: key)
        }
    }

    func captureOperationContext() -> SocialAccountOperationContext? {
        guard isSessionActive,
              let activeAccountID,
              AuthManager.shared.currentAccountID == activeAccountID else { return nil }
        return SocialAccountOperationContext(
            accountID: activeAccountID,
            generation: accountGeneration
        )
    }

    func isOperationContextCurrent(_ context: SocialAccountOperationContext) -> Bool {
        isSessionActive
            && context.matches(accountID: activeAccountID, generation: accountGeneration)
            && AuthManager.shared.currentAccountID == context.accountID
    }
}

#endif
