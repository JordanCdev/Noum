import Foundation
import CryptoKit

// MARK: - Forward Plan Service
//
// Generates a 4-week coaching program from the user's actual state.
// Returns a deterministic `ForwardPlan` when no AI provider is authorized,
// the captured locale is unsupported, or an authorized provider fails. It
// returns nil only when the account/source/authorization lease expires while
// work is suspended, so stale private context never crosses the transport
// boundary and stale fallback copy never becomes durable coaching.
//
// Reuses the same provider plumbing (OpenAI / DeepSeek / Gemini) as
// `AIInsightsService` and `AICoachChatService`. JSON-mode response so
// the parsed plan shape stays stable across providers.

/// Self-contained input snapshot. Constructed once on the call site so
/// the service stays pure (no singleton reads inside the actor — keeps
/// the deterministic fallback unit-testable without provider stubs).
struct ForwardPlanInput {
    let profile: CoachingProfile?
    let baseline: CommunicationBaseline
    let sessions: [PracticeSession]
    let weeklyDelta: Int
    let weeklyReps: Int
    let currentStreak: Int
    let bigMoment: BigMoment?
    let bigMomentDaysUntil: Int?
    let trends: [SkillTrend]
    let recentDrills: [DrillHistoryStore.Entry]
    /// Recorded response to earlier prescribed modes. Raw ownership
    /// remains in RecommendationLearningStore; the planner receives a
    /// snapshot so an AI-created plan can adjust instead of repeating.
    let recommendationOutcomes: [RecommendationOutcome]
    /// Real-world transfer reports (how completed Big Moments actually
    /// went, as the user reported them). Raw ownership stays in
    /// `BigMomentStore.outcomeReports`; the planner receives a snapshot so
    /// the next plan can adapt to what the user said carried into the room
    /// — never as proof the training caused the result (the no-causation
    /// contract; the honesty floor lives in `BigMomentStore.transferTrends`).
    let transferOutcomes: [BigMomentOutcomeReport]

    init(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        weeklyDelta: Int,
        weeklyReps: Int,
        currentStreak: Int,
        bigMoment: BigMoment?,
        bigMomentDaysUntil: Int?,
        trends: [SkillTrend],
        recentDrills: [DrillHistoryStore.Entry],
        recommendationOutcomes: [RecommendationOutcome] = [],
        transferOutcomes: [BigMomentOutcomeReport] = []
    ) {
        self.profile = profile
        self.baseline = baseline
        self.sessions = sessions
        self.weeklyDelta = weeklyDelta
        self.weeklyReps = weeklyReps
        self.currentStreak = currentStreak
        self.bigMoment = bigMoment
        self.bigMomentDaysUntil = bigMomentDaysUntil
        self.trends = trends
        self.recentDrills = recentDrills
        self.recommendationOutcomes = recommendationOutcomes
        self.transferOutcomes = transferOutcomes
    }
}

/// Stable, content-free identity for the exact state snapshot that shaped one
/// asynchronous Forward Plan request. The digest is never persisted or logged;
/// it exists only so a completion can prove that every input family is still
/// current before it becomes durable coaching or conversation history.
extension ForwardPlanInput {
    var generationIdentity: String? {
        let payload = ForwardPlanInputIdentityPayload(input: self)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+infinity",
            negativeInfinity: "-infinity",
            nan: "nan"
        )
        guard let data = try? encoder.encode(payload) else { return nil }
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

/// `SkillTrend` intentionally remains a lightweight analysis value rather than
/// a persistence model. This projection lets the generation identity include
/// every trend field without changing that architectural boundary.
private struct ForwardPlanTrendIdentity: Encodable {
    let id: String
    let skillArea: String
    let direction: String
    let confidence: String
    let windowSize: Int
    let currentLevel: String
    let recentDelta: String?

    init(_ trend: SkillTrend) {
        id = trend.id
        skillArea = trend.skillArea.rawValue
        direction = trend.direction.rawValue
        confidence = trend.confidence.rawValue
        windowSize = trend.windowSize
        currentLevel = trend.currentLevel.rawValue
        recentDelta = trend.recentDelta
    }
}

/// Codable projection of all current and future-facing inputs owned by the
/// existing stores. Including the full value snapshots (rather than only the
/// fields used by today's prompt) makes source drift fail closed if generation
/// logic later begins reading another already-present field.
private struct ForwardPlanInputIdentityPayload: Encodable {
    let profile: CoachingProfile?
    let baseline: CommunicationBaseline
    let sessions: [PracticeSession]
    let weeklyDelta: Int
    let weeklyReps: Int
    let currentStreak: Int
    let bigMoment: BigMoment?
    let bigMomentDaysUntil: Int?
    let trends: [ForwardPlanTrendIdentity]
    let recentDrills: [DrillHistoryStore.Entry]
    let recommendationOutcomes: [RecommendationOutcome]
    let transferOutcomes: [BigMomentOutcomeReport]

    init(input: ForwardPlanInput) {
        profile = input.profile
        baseline = input.baseline
        sessions = input.sessions
        weeklyDelta = input.weeklyDelta
        weeklyReps = input.weeklyReps
        currentStreak = input.currentStreak
        bigMoment = input.bigMoment
        bigMomentDaysUntil = input.bigMomentDaysUntil
        trends = input.trends.map(ForwardPlanTrendIdentity.init)
        recentDrills = input.recentDrills
        recommendationOutcomes = input.recommendationOutcomes
        transferOutcomes = input.transferOutcomes
    }
}

/// One already-started provider request. Production creates and resumes the
/// `URLSessionDataTask` synchronously inside the MainActor lease check, so an
/// account or consent mutation cannot slip into an actor-hop gap between
/// authorization and transmission.
struct ForwardPlanTransportHandle: @unchecked Sendable {
    typealias Response = (Data, URLResponse)

    private let response: () async throws -> Response
    private let cancellation: () -> Void

    init(
        response: @escaping () async throws -> Response,
        cancellation: @escaping () -> Void = {}
    ) {
        self.response = response
        self.cancellation = cancellation
    }

    func value() async throws -> Response {
        try await response()
    }

    func cancel() {
        cancellation()
    }

    @MainActor
    static func start(
        _ request: URLRequest,
        session: URLSession = .shared
    ) -> ForwardPlanTransportHandle {
        let responseState = ForwardPlanURLSessionResponseState()
        let task = session.dataTask(with: request) { data, response, error in
            Task {
                await responseState.complete(
                    data: data,
                    response: response,
                    error: error
                )
            }
        }
        let handle = ForwardPlanTransportHandle(
            response: {
                try await responseState.value()
            },
            cancellation: {
                task.cancel()
            }
        )
        task.resume()
        return handle
    }
}

private actor ForwardPlanURLSessionResponseState {
    typealias Response = ForwardPlanTransportHandle.Response

    private var result: Result<Response, Error>?
    private var continuation: CheckedContinuation<Response, Error>?

    func value() async throws -> Response {
        if let result {
            return try result.get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func complete(data: Data?, response: URLResponse?, error: Error?) {
        let resolved: Result<Response, Error>
        if let error {
            resolved = .failure(error)
        } else if let data, let response {
            resolved = .success((data, response))
        } else {
            resolved = .failure(URLError(.badServerResponse))
        }
        result = resolved
        continuation?.resume(with: resolved)
        continuation = nil
    }
}

@available(iOS 17.0, macOS 12.0, *)
actor ForwardPlanService {

    static let shared = ForwardPlanService()

    private enum ProviderWorkDeletionState: Equatable {
        case suspended
        case finishing
    }

    private struct ActiveProviderTransport {
        let accountScope: String
        let handle: ForwardPlanTransportHandle
    }

    private struct PendingProviderTransportAdmission {
        let accountScope: String
        var isRevoked = false
    }

    private let apiKeyProvider: (AIProvider) -> String?
    private let transportCreatedHook: (@Sendable () async -> Void)?
    private var providerWorkDeletionStates: [String: ProviderWorkDeletionState] = [:]
    private var pendingProviderTransportAdmissions: [
        UUID: PendingProviderTransportAdmission
    ] = [:]
    private var activeProviderTransports: [UUID: ActiveProviderTransport] = [:]

    init(
        apiKeyProvider: @escaping (AIProvider) -> String? = {
            AIProviderCredential.apiKey(for: $0)
        },
        transportCreatedHook: (@Sendable () async -> Void)? = nil
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.transportCreatedHook = transportCreatedHook
    }

    /// Close provider admission for one account and cancel every registered
    /// transport for it. Auth calls this at deletion admission, before any
    /// remote suspension. Cancellation is best effort; the closed-account
    /// checks below remain the authoritative postflight fence.
    func suspendProviderWorkForDeletion(accountID: String) {
        guard let accountScope = Self.normalizedAccountScope(accountID) else {
            return
        }
        if providerWorkDeletionStates[accountScope] != .finishing {
            providerWorkDeletionStates[accountScope] = .suspended
        }
        revokePendingProviderTransportAdmissions(for: accountScope)
        cancelActiveProviderTransports(for: accountScope)
    }

    /// Account promotion changes the durable owner without deleting either
    /// namespace. Revoke every old-account lease/transport but do not install
    /// a deletion state that would need an unsafe generic resume.
    func invalidateProviderWorkForAccountTransition(accountID: String) {
        guard let accountScope = Self.normalizedAccountScope(accountID) else {
            return
        }
        revokePendingProviderTransportAdmissions(for: accountScope)
        cancelActiveProviderTransports(for: accountScope)
    }

    /// Reopen provider admission only for the explicit recoverable path where
    /// deletion failed before any destructive remote work began. Generic or
    /// post-remote failures must not call this method.
    func resumeProviderWorkAfterSafeDeletionFailure(accountID: String) {
        guard let accountScope = Self.normalizedAccountScope(accountID),
              providerWorkDeletionStates[accountScope] == .suspended else {
            return
        }
        providerWorkDeletionStates.removeValue(forKey: accountScope)
    }

    /// Complete service-local teardown after account deletion. The fence is
    /// retained while a cancellation-ignoring transport is still draining and
    /// released only after the registry is empty; the durable Auth gate remains
    /// closed after that point and rejects any stale store lease.
    func finishProviderWorkDeletion(accountID: String) {
        guard let accountScope = Self.normalizedAccountScope(accountID) else {
            return
        }
        providerWorkDeletionStates[accountScope] = .finishing
        revokePendingProviderTransportAdmissions(for: accountScope)
        cancelActiveProviderTransports(for: accountScope)
        removeFinishedFenceIfDrained(for: accountScope)
    }

    /// Generate from one inseparable account-owned request. The provider and
    /// locale come only from the captured authorization snapshot. `isCurrent`
    /// revalidates that lease immediately before transport and immediately
    /// after it returns; nil means the result no longer has authority to exist.
    func generate(
        request: ForwardPlanGenerationRequest,
        startTransportIfCurrent: @escaping @MainActor (
            URLRequest
        ) -> ForwardPlanTransportHandle?,
        isCurrent: @escaping @MainActor () -> Bool
    ) async -> ForwardPlan? {
        let input = request.input
        let accountScope = request.saveToken.accountScope
        func record(
            _ outcome: AICallDiagnosticOutcome,
            _ reason: String,
            provider: AIProvider? = nil,
            statusCode: Int? = nil,
            startedAt: Date? = nil
        ) {
            AICallDiagnostics.record(
                surface: "Forward plan",
                provider: provider,
                outcome: outcome,
                reason: reason,
                statusCode: statusCode,
                startedAt: startedAt
            )
        }

        guard !providerWorkIsClosed(for: accountScope) else {
            record(.skipped, "Account deletion closed provider work")
            return nil
        }
        let fallback = Self.deterministicPlan(input: input)
        let authorization = request.saveToken.executionAuthorization
        guard authorization.locale.aiSupported else {
            record(.skipped, "Locale not AI-supported")
            return fallback
        }
        let capturedProvider = authorization.activeProvider
        guard let provider = capturedProvider,
              let endpoint = provider.endpoint,
              let key = apiKeyProvider(provider) else {
            record(.skipped, capturedProvider == nil ? "No active provider" : "Missing key or endpoint", provider: capturedProvider)
            return fallback
        }

        let body = requestBody(for: provider, input: input)
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 18
        switch provider {
        case .openAI, .deepSeek:
            urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .gemini:
            urlRequest.setGoogleAPIKey(key)
        case .none:
            record(.skipped, "Provider set to off", provider: provider)
            return fallback
        }

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            guard !providerWorkIsClosed(for: accountScope) else {
                record(.skipped, "Account deletion closed provider work", provider: provider)
                return nil
            }
            record(.failure, "Request encoding failed", provider: provider)
            return fallback
        }

        guard !Task.isCancelled,
              beginProviderTransportAdmission(
                requestID: request.saveToken.requestID,
                accountScope: accountScope
              ) else {
            record(.skipped, "Request authority changed before transport", provider: provider)
            return nil
        }
        guard let transport = await startTransportIfCurrent(urlRequest) else {
            endPendingProviderTransportAdmission(
                requestID: request.saveToken.requestID,
                accountScope: accountScope
            )
            record(.skipped, "Request authority changed before transport", provider: provider)
            return nil
        }
        // A nil production hook adds no suspension. Tests use the injected hook
        // to deterministically exercise a deletion close that wins after the
        // MainActor has created a handle but before actor-owned registration.
        if let transportCreatedHook {
            await transportCreatedHook()
        }
        guard registerActiveProviderTransport(
            transport,
            requestID: request.saveToken.requestID,
            accountScope: accountScope
        ) else {
            record(.skipped, "Account deletion closed provider work before registration", provider: provider)
            return nil
        }
        defer {
            unregisterActiveProviderTransport(
                requestID: request.saveToken.requestID,
                accountScope: accountScope
            )
        }

        let startedAt = Date()
        do {
            let (data, response) = try await withTaskCancellationHandler(
                operation: {
                    try await transport.value()
                },
                onCancel: {
                    transport.cancel()
                }
            )
            guard !Task.isCancelled,
                  !providerWorkIsClosed(for: accountScope),
                  await isCurrent(),
                  !providerWorkIsClosed(for: accountScope) else {
                record(.skipped, "Request authority changed during transport", provider: provider, startedAt: startedAt)
                return nil
            }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                record(
                    .fallback,
                    statusCode.map { "Provider returned HTTP \($0)" } ?? "Non-HTTP response",
                    provider: provider,
                    statusCode: statusCode,
                    startedAt: startedAt
                )
                return fallback
            }
            guard let weeks = parsePlanWeeks(from: data, provider: provider, input: input),
                  weeks.count == 4 else {
                record(.fallback, "Response JSON did not match plan schema", provider: provider, statusCode: http.statusCode, startedAt: startedAt)
                return fallback
            }
            record(.success, "Forward plan accepted", provider: provider, statusCode: http.statusCode, startedAt: startedAt)
            return ForwardPlan(
                weeks: weeks,
                bigMomentID: input.bigMoment?.id,
                voiceAtGeneration: input.profile?.chosenStyleGoal,
                isAIBacked: true
            )
        } catch is CancellationError {
            record(.skipped, "Request cancelled", provider: provider)
            return nil
        } catch {
            guard !Task.isCancelled,
                  !providerWorkIsClosed(for: accountScope) else {
                record(.skipped, "Request cancelled or deletion-fenced", provider: provider)
                return nil
            }
            record(.failure, "Transport or decode error", provider: provider)
            guard await isCurrent(),
                  !providerWorkIsClosed(for: accountScope) else {
                return nil
            }
            return fallback
        }
    }

    private func providerWorkIsClosed(for accountScope: String) -> Bool {
        providerWorkDeletionStates[accountScope] != nil
    }

    /// A pending admission makes the MainActor handle-creation await visible to
    /// deletion teardown. Suspension permanently revokes the entry, even if a
    /// later safe resume reopens admission for newly-created requests.
    private func beginProviderTransportAdmission(
        requestID: UUID,
        accountScope: String
    ) -> Bool {
        guard !providerWorkIsClosed(for: accountScope),
              pendingProviderTransportAdmissions[requestID] == nil,
              activeProviderTransports[requestID] == nil else {
            return false
        }
        pendingProviderTransportAdmissions[requestID] =
            PendingProviderTransportAdmission(accountScope: accountScope)
        return true
    }

    /// Registration is actor-atomic with the closed-account check. A close
    /// that wins before this method cancels the newly created transport; a
    /// close that wins after registration finds it in the central registry.
    private func registerActiveProviderTransport(
        _ transport: ForwardPlanTransportHandle,
        requestID: UUID,
        accountScope: String
    ) -> Bool {
        guard let pending = pendingProviderTransportAdmissions[requestID],
              pending.accountScope == accountScope else {
            transport.cancel()
            return false
        }
        guard !Task.isCancelled,
              !pending.isRevoked,
              !providerWorkIsClosed(for: accountScope),
              activeProviderTransports[requestID] == nil else {
            pendingProviderTransportAdmissions.removeValue(forKey: requestID)
            transport.cancel()
            removeFinishedFenceIfDrained(for: accountScope)
            return false
        }
        // Transfer ownership in one actor turn: finishing can never observe a
        // false-empty gap between pending creation and active registration.
        pendingProviderTransportAdmissions.removeValue(forKey: requestID)
        activeProviderTransports[requestID] = ActiveProviderTransport(
            accountScope: accountScope,
            handle: transport
        )
        return true
    }

    private func endPendingProviderTransportAdmission(
        requestID: UUID,
        accountScope: String
    ) {
        guard pendingProviderTransportAdmissions[requestID]?.accountScope
                == accountScope else {
            return
        }
        pendingProviderTransportAdmissions.removeValue(forKey: requestID)
        removeFinishedFenceIfDrained(for: accountScope)
    }

    private func unregisterActiveProviderTransport(
        requestID: UUID,
        accountScope: String
    ) {
        guard activeProviderTransports[requestID]?.accountScope == accountScope else {
            return
        }
        activeProviderTransports.removeValue(forKey: requestID)
        removeFinishedFenceIfDrained(for: accountScope)
    }

    private func cancelActiveProviderTransports(for accountScope: String) {
        let transports = activeProviderTransports.values
            .filter { $0.accountScope == accountScope }
            .map(\.handle)
        transports.forEach { $0.cancel() }
    }

    private func revokePendingProviderTransportAdmissions(
        for accountScope: String
    ) {
        let requestIDs = pendingProviderTransportAdmissions.compactMap {
            requestID, admission in
            admission.accountScope == accountScope ? requestID : nil
        }
        for requestID in requestIDs {
            pendingProviderTransportAdmissions[requestID]?.isRevoked = true
        }
    }

    private func removeFinishedFenceIfDrained(for accountScope: String) {
        guard providerWorkDeletionStates[accountScope] == .finishing,
              !pendingProviderTransportAdmissions.values.contains(where: {
                  $0.accountScope == accountScope
              }),
              !activeProviderTransports.values.contains(where: {
                  $0.accountScope == accountScope
              }) else {
            return
        }
        providerWorkDeletionStates.removeValue(forKey: accountScope)
    }

    private nonisolated static func normalizedAccountScope(
        _ accountID: String
    ) -> String? {
        let trimmed = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Deterministic plan (pure, exposed for tests)

    /// Rule-based 4-week plan derived from baseline + voice + Big Moment.
    /// Pure and `nonisolated` so the test suite can exercise it without
    /// spinning up the actor. Honest fallback — `isAIBacked: false`.
    nonisolated static func deterministicPlan(input: ForwardPlanInput) -> ForwardPlan {
        let weeks = [
            week1(input: input),
            week2(input: input),
            week3(input: input),
            week4(input: input)
        ]
        return ForwardPlan(
            weeks: weeks,
            bigMomentID: input.bigMoment?.id,
            voiceAtGeneration: input.profile?.chosenStyleGoal,
            isAIBacked: false
        )
    }

    // MARK: - Per-week deterministic builders

    /// Week 1 — address the weakest baseline dimension. This is the
    /// foundation: name the most-visible problem and pick the mode that
    /// surfaces it cleanest.
    private nonisolated static func week1(input: ForwardPlanInput) -> PlanWeek {
        let weakest = weakestSkillArea(baseline: input.baseline, trends: input.trends)
        let focus = priority(for: weakest)
        let mode = modeFor(skillArea: weakest)
        let target = sessionTarget(weeklyReps: input.weeklyReps, base: 3)
        let rationale = "Start where the data is loudest. \(weakest.displayName.lowercased()) is the area with the most room to move — \(mode.displayLabel) reps surface it cleanly."
        return PlanWeek(
            weekIndex: 1,
            focus: focus,
            focusSkillArea: weakest,
            suggestedMode: mode,
            sessionTarget: target,
            rationale: rationale
        )
    }

    /// Week 2 — introduce the mode best aligned with the user's voice
    /// goal. Builds on Week 1's foundation by adding intentional shape
    /// (the voice the user is training toward).
    private nonisolated static func week2(input: ForwardPlanInput) -> PlanWeek {
        let voice = input.profile?.chosenStyleGoal
        let skill = voice?.primaryAlignedSkillArea ?? .structure
        let focus = priority(for: skill)
        let mode = bestModeForVoice(voice) ?? modeFor(skillArea: skill)
        let target = sessionTarget(weeklyReps: input.weeklyReps, base: 3)
        let voiceLabel = voice?.shortVoiceLabel ?? "your voice"
        let rationale = "Shift toward shape. \(mode.displayLabel) reps build \(skill.displayName.lowercased()), the clearest focus for reaching \(voiceLabel)."
        return PlanWeek(
            weekIndex: 2,
            focus: focus,
            focusSkillArea: skill,
            suggestedMode: mode,
            sessionTarget: target,
            rationale: rationale
        )
    }

    /// Week 3 — pressure escalation. Pressure Drill by default; for
    /// users whose Week 1 focus was already filler-reduction, keep the
    /// mode varied so the program doesn't read as three weeks of the
    /// same thing.
    private nonisolated static func week3(input: ForwardPlanInput) -> PlanWeek {
        let week1Skill = weakestSkillArea(baseline: input.baseline, trends: input.trends)
        let isFillerWeek1 = week1Skill == .fillerReduction
        let skill: SkillArea = isFillerWeek1 ? .confidence : .fillerReduction
        let focus = priority(for: skill)
        let mode: PracticeMode = .suddenDeath
        let target = max(2, sessionTarget(weeklyReps: input.weeklyReps, base: 3) - 1)
        let rationale = "Pressure Drill rewards composure — one filler ends the rep, so each rep is a clear test of what you've drilled."
        return PlanWeek(
            weekIndex: 3,
            focus: focus,
            focusSkillArea: skill,
            suggestedMode: mode,
            sessionTarget: target,
            rationale: rationale
        )
    }

    /// Week 4 — mock run for the Big Moment when one is set, else a
    /// consolidation week. The mock-mode picker reads the BigMoment
    /// category so the rehearsal fits the actual shape of the event.
    private nonisolated static func week4(input: ForwardPlanInput) -> PlanWeek {
        if let moment = input.bigMoment {
            let mode = mockModeFor(category: moment.category)
            let skill = mode.primarySkillAreas.first ?? .structure
            let focus = priority(for: skill)
            let target = sessionTarget(weeklyReps: input.weeklyReps, base: 4)
            let daysFragment: String = {
                guard let days = input.bigMomentDaysUntil, days >= 0 else {
                    return "Run the rep as if the moment were tomorrow."
                }
                if days == 0 { return "Today is the day. Run one clean mock and stop." }
                if days == 1 { return "One day out. Run one mock, sleep on it." }
                return "\(days) days out. Treat each rep like the real moment."
            }()
            var rationale = "Mock your \(moment.category.displayName). \(daysFragment) \(mode.displayLabel) most closely matches the shape of the event."
            // Adapt to what the user reported about earlier real moments of
            // this kind — the plan should not ignore real-world results.
            if let bridge = transferBridgeClause(for: moment.category, in: input.transferOutcomes) {
                rationale += " \(bridge)"
            }
            return PlanWeek(
                weekIndex: 4,
                focus: focus,
                focusSkillArea: skill,
                suggestedMode: mode,
                sessionTarget: target,
                rationale: rationale
            )
        }
        // No big moment — consolidation. Mode is whichever the user's
        // most-recent baseline strength reads as: lean into what's
        // working so the program closes with a confidence rep.
        let skill = strongestSkillArea(baseline: input.baseline) ?? .structure
        let focus = priority(for: skill)
        let mode = modeFor(skillArea: skill)
        let target = sessionTarget(weeklyReps: input.weeklyReps, base: 3)
        let rationale = "Consolidation. Bank a clean rep on \(skill.displayName.lowercased()) — close the program by hearing yourself land it."
        return PlanWeek(
            weekIndex: 4,
            focus: focus,
            focusSkillArea: skill,
            suggestedMode: mode,
            sessionTarget: target,
            rationale: rationale
        )
    }

    // MARK: - Pure helpers

    /// Pick the weakest skill area for Week 1. Reads declining trends
    /// first (urgent), then weak-stable (persistent), then falls back
    /// to baseline numbers.
    nonisolated static func weakestSkillArea(baseline: CommunicationBaseline, trends: [SkillTrend]) -> SkillArea {
        if let declining = trends.first(where: { $0.direction == .declining && $0.confidence == .high }) {
            return declining.skillArea
        }
        if let weakStable = trends.first(where: { $0.currentLevel == .weak && $0.direction == .stable }) {
            return weakStable.skillArea
        }
        if baseline.fillerRate.confidence != .insufficient && baseline.fillerRate.value >= 3.0 {
            return .fillerReduction
        }
        if baseline.pace.confidence != .insufficient && baseline.pace.value >= 165 {
            return .paceControl
        }
        if baseline.pauseRate.confidence != .insufficient && baseline.pauseRate.value < 1.0 {
            return .pauseUsage
        }
        if baseline.structureQuality.confidence != .insufficient && baseline.structureQuality.value < 1.8 {
            return .structure
        }
        return .structure
    }

    /// Strongest baseline skill area for Week 4's consolidation case.
    /// Returns nil when no dimension has enough confidence to claim a
    /// strength — the caller falls back to `.structure`.
    nonisolated static func strongestSkillArea(baseline: CommunicationBaseline) -> SkillArea? {
        if baseline.fillerRate.confidence != .insufficient, baseline.fillerRate.value <= 1.5 {
            return .fillerReduction
        }
        if baseline.pauseRate.confidence != .insufficient, baseline.pauseRate.value >= 2.0 {
            return .pauseUsage
        }
        if baseline.structureQuality.confidence != .insufficient, baseline.structureQuality.value >= 2.4 {
            return .structure
        }
        if baseline.averageScore.confidence != .insufficient, baseline.averageScore.value >= 7.5 {
            return .confidence
        }
        return nil
    }

    /// Map skill area → coaching priority for the PlanWeek field.
    nonisolated static func priority(for skill: SkillArea) -> CoachingPriority {
        switch skill {
        case .fillerReduction: return .reduceFillers
        case .conciseSpeaking, .structure, .closingStrength, .answerDevelopment, .openingStrength:
            return .moreConcise
        case .pauseUsage, .paceControl, .vocalEmphasis:
            return .calmerDelivery
        case .confidence:
            return .thinkFaster
        }
    }

    /// Pick the practice mode that drills `skill` most cleanly. Mirrors
    /// `PracticeMode.primarySkillAreas` in reverse — the mode whose
    /// primary skill set contains this skill comes first.
    nonisolated static func modeFor(skillArea: SkillArea) -> PracticeMode {
        switch skillArea {
        case .fillerReduction, .paceControl, .pauseUsage:
            return .ahCounter
        case .structure, .answerDevelopment, .openingStrength, .closingStrength, .conciseSpeaking:
            return .timed
        case .confidence:
            return .suddenDeath
        case .vocalEmphasis:
            return .imConversation
        }
    }

    /// Pick the mode best aligned with a voice goal. Returns nil when
    /// no voice is set — caller falls back to a skill-area lookup.
    nonisolated static func bestModeForVoice(_ voice: SpeakingStyleGoal?) -> PracticeMode? {
        guard let voice else { return nil }
        switch voice {
        case .authoritative, .executive: return .suddenDeath
        case .warm, .storytelling:       return .imConversation
        case .concise:                   return .timed
        case .persuasive:                return .timed
        }
    }

    /// Pick the mode whose rep shape most closely matches the real-world
    /// event the user is preparing for.
    nonisolated static func mockModeFor(category: BigMomentCategory) -> PracticeMode {
        switch category {
        case .presentation, .publicSpeaking: return .timed
        case .interview, .conversation:      return .imConversation
        case .review:                        return .imConversation
        case .other:                         return .timed
        }
    }

    /// Qualifying real-world transfer read for `category`, when enough
    /// reports exist to clear the honesty floor (`transferTrends`
    /// minimumReports = 3). Returns the dominant `ReportedDrillTransfer`
    /// only when one read is the strict plurality — a tie or thin data
    /// returns nil so the planner ignores transfer rather than reacting on
    /// noise. The reports are the user's own account; this is a self-report
    /// pattern, never proof the training caused the result.
    nonisolated static func dominantTransferRead(
        for category: BigMomentCategory,
        in reports: [BigMomentOutcomeReport]
    ) -> ReportedDrillTransfer? {
        BigMomentStore.dominantTransferRead(for: category, in: reports)
    }

    /// One bounded, forward-looking, no-causation clause appended to the
    /// Week-4 mock rationale when recent real-world reports say the prep
    /// hasn't been carrying into the room. Frames the mock as the bridge
    /// rather than passing a verdict on the user (never punish-shame); the
    /// "hasn't fully carried" language is the user's own reported read.
    /// Returns nil for any read other than `.didNotTransfer` so a positive
    /// or partial pattern doesn't trigger a corrective tone.
    nonisolated static func transferBridgeClause(
        for category: BigMomentCategory,
        in reports: [BigMomentOutcomeReport]
    ) -> String? {
        guard dominantTransferRead(for: category, in: reports) == .didNotTransfer else {
            return nil
        }
        return "Recent \(category.displayName) check-ins suggest the rehearsal hasn't fully carried into the room yet. Treat this mock as the bridge to the real thing."
    }

    /// Honest session target. Anchored on the user's actual weekly
    /// rep count so the plan isn't aspirational — a user averaging 2
    /// reps/week doesn't get a 5-target wall of failure.
    nonisolated static func sessionTarget(weeklyReps: Int, base: Int) -> Int {
        // Pin between 2 and 5. The base is the "if you've been doing
        // ~3 reps/week" anchor. Heavy users get a +1; light users
        // get a -1 floor at 2 so the plan still asks for something.
        let raw: Int
        if weeklyReps >= 5 {
            raw = base + 1
        } else if weeklyReps <= 1 {
            raw = base - 1
        } else {
            raw = base
        }
        return max(2, min(5, raw))
    }

    // MARK: - AI request / parse

    private func requestBody(for provider: AIProvider, input: ForwardPlanInput) -> [String: Any] {
        let system = Self.systemPrompt(for: input.profile?.chosenStyleGoal)
        let user = Self.userPrompt(input: input)
        // Token budget — four week-objects with ≤200-char rationale each
        // plus JSON scaffolding fits in ~600 tokens. The earlier unbounded
        // shape risked silent truncation around week 4, where the parser
        // would reject the partial payload and silently drop to the
        // deterministic fallback even though the AI was alive.
        switch provider {
        case .openAI, .deepSeek:
            return [
                "model": provider.model,
                "temperature": 0.5,
                "max_tokens": 600,
                "response_format": ["type": "json_object"],
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ]
            ]
        case .gemini:
            return [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": [["role": "user", "parts": [["text": user]]]],
                "generationConfig": [
                    "temperature": 0.5,
                    "maxOutputTokens": 600,
                    "thinkingConfig": ["thinkingBudget": 0],
                    "responseMimeType": "application/json"
                ]
            ]
        case .none:
            return [:]
        }
    }

    /// Exposed `static` + `internal` so the test suite can assert the
    /// per-voice register clause without standing up the actor.
    static func systemPrompt(for voice: SpeakingStyleGoal?) -> String {
        let voiceRegister = voiceRegisterClause(for: voice)
        return """
        You are Noum — the user's personal speaking coach. The user has \
        asked for a 4-week practice program. Produce a concrete plan tied \
        to their actual baseline numbers + voice goal + Big Moment (if set).

        \(voiceRegister)

        Hard rules (every output must clear all of these):
        - Output strict JSON: {"weeks":[{"weekIndex":1,"focus":"...", \
        "mode":"...","sessionTarget":N,"rationale":"..."}, ...]}.
        - Exactly 4 weeks, weekIndex 1..4.
        - `focus` is one of: reduceFillers, moreConcise, thinkFaster, \
        calmerDelivery.
        - `mode` is one of: timed, suddenDeath, ahCounter, imConversation.
        - `sessionTarget` is an integer 2..5.
        - `rationale` is ≤ 200 chars, second-person, sentence case, no \
        exclamation marks, no emoji, no "Let's", no chirpy filler. Cite \
        the user's actual data when relevant. The rationale should read \
        in the user's voice register.
        - Week 1 names the weakest area. Week 2 moves toward the user's \
        voice goal. Week 3 introduces pressure. Week 4 mocks the Big \
        Moment when set; consolidation when not.
        - If OBSERVED RESPONSE says a previously prescribed mode should be \
        adapted before repeating, do not repeat it unchanged without \
        explaining a different purpose or adjustment in the rationale. \
        Observed response is association, not proof of causation.
        - If REAL-WORLD TRANSFER PATTERNS say the user's prep has not been \
        carrying into the room, the plan should bridge rehearsal to the real \
        moment (e.g. mock the exact moment it slipped) rather than repeating \
        the same drills unchanged. Transfer reports are the user's own read, \
        association only — never claim the training caused any outcome, and \
        never echo a "fell short" verdict back at the user.
        - No invented stats. If you don't have a number, don't claim a number.
        """
    }

    /// Per-voice register clause. Same authoritative=verdict, warm=mentor,
    /// concise=clipped, persuasive=premise→evidence, executive=chief-of-staff,
    /// storytelling=arcs pattern as the live coach. Shapes how the plan's
    /// rationale reads — same plan, different register.
    static func voiceRegisterClause(for voice: SpeakingStyleGoal?) -> String {
        switch voice {
        case .authoritative:
            return "Register: a steady, considered verdict. Rationale sentences are declarative — the user is training authority."
        case .warm:
            return "Register: a trusted mentor. Rationale notices small wins — the user is training warmth."
        case .concise:
            return "Register: clipped and useful. Rationale lands in one tight idea — the user is training conciseness."
        case .persuasive:
            return "Register: premise → evidence → recommendation. Rationale shows the reasoning — the user is training persuasion."
        case .executive:
            return "Register: chief-of-staff briefing a principal. Rationale leads with the top line — the user is training executive presence."
        case .storytelling:
            return "Register: a narrative coach. Rationale frames each week as a chapter — the user is training storytelling."
        case .none:
            return "Register: calm and direct. No voice has been set yet — favour specifics over generalities."
        }
    }

    /// Provider-visible plan context. Recent filler mechanics pass through the
    /// same quantity, confidence, comparison-schema, and fixture boundary as
    /// the rest of Noum's historical coaching surfaces. Keeping this static
    /// makes that trust boundary directly testable without starting an actor or
    /// constructing a provider request.
    nonisolated static func userPrompt(input: ForwardPlanInput) -> String {
        var lines: [String] = []
        if let profile = input.profile {
            if let voice = profile.chosenStyleGoal {
                lines.append("Voice goal: \(voice.title) — wants to \(voice.coachingDescription).")
            }
            lines.append("Coaching goal: \(profile.displayableGoal)")
        } else {
            lines.append("No voice goal set yet — choose moves that fit a cold-start user.")
        }
        if let moment = input.bigMoment {
            if let days = input.bigMomentDaysUntil, days >= 0 {
                lines.append("Big Moment: \(moment.category.displayName) in \(days) day\(days == 1 ? "" : "s").")
            } else {
                lines.append("Big Moment: \(moment.category.displayName) (date not set).")
            }
        }
        lines.append("Sessions this week: \(input.weeklyReps)")
        lines.append("Rating delta this week: \(input.weeklyDelta >= 0 ? "+" : "")\(input.weeklyDelta)")
        lines.append("Current streak: \(input.currentStreak) day\(input.currentStreak == 1 ? "" : "s")")
        if input.baseline.averageScore.confidence != .insufficient {
            lines.append("Average score baseline: \(String(format: "%.1f", input.baseline.averageScore.value))/10")
        }
        if let fillerRate = input.baseline.currentComparisonFillerRate {
            lines.append("Filler rate baseline: \(String(format: "%.1f", fillerRate)) per minute")
        }
        if let paceWPM = input.baseline.currentComparisonPaceWPM {
            lines.append("Pace baseline: \(String(format: "%.0f", paceWPM)) WPM")
        }
        if input.baseline.pauseRate.confidence != .insufficient {
            lines.append("Pause rate baseline: \(String(format: "%.1f", input.baseline.pauseRate.value)) per minute")
        }
        if !input.baseline.topStrengths.isEmpty {
            lines.append("Strengths: \(input.baseline.topStrengths.joined(separator: ", "))")
        }
        if !input.baseline.persistentBlockers.isEmpty {
            lines.append("Blockers: \(input.baseline.persistentBlockers.joined(separator: ", "))")
        }
        let recent = input.sessions.prefix(5).enumerated().map { idx, s in
            let score = s.score.map { "\($0)/10" } ?? "n/a"
            let fillerEvidence: String
            if let rate = QuantityQualifiedFillerEvidence.historical(s).ratePerMinute {
                let formatted = String(
                    format: "%.1f",
                    locale: Locale(identifier: "en_US_POSIX"),
                    rate
                )
                fillerEvidence = "filler rate \(formatted) per minute"
            } else {
                fillerEvidence = "filler rate not measured"
            }
            return "  \(idx + 1). \(s.mode.displayLabel) | score \(score) | \(fillerEvidence)"
        }
        if !recent.isEmpty {
            lines.append("Recent sessions (newest first):")
            lines.append(contentsOf: recent)
        }
        let responseLines = RecommendationResponseAnalyzer.promptLines(from: input.recommendationOutcomes)
        if !responseLines.isEmpty {
            lines.append("Observed response to earlier prescribed modes (association only):")
            lines.append(contentsOf: responseLines)
            // Same reinforce / vary / replace verdict the chat coach surfaces, so
            // the forward plan and Ask Noum read one coherent decision on whether
            // a prescribed mode is working. Omitted below the evidence floor.
            if let topSummary = RecommendationResponseAnalyzer.summarize(outcomes: input.recommendationOutcomes).first,
               let verdictLine = RecommendationAdaptationAnalyzer.adaptationRationale(
                   mode: topSummary.mode, focus: topSummary.focus, in: input.recommendationOutcomes) {
                lines.append(verdictLine)
            }
        }
        // Real-world transfer patterns — how the user reported completed
        // moments actually went. Honesty floor + no-causation framing live in
        // `BigMomentStore.transferTrends` (minimumReports: 3), the same
        // aggregator the live coach reads, so the plan and Ask Noum surface one
        // coherent read. Omitted entirely below the floor. `limit: 2` matches
        // the live coach's bound (intentional: the deterministic
        // `dominantTransferRead` uses an unbounded limit so the active moment's
        // category is never starved — only the AI context under-surfaces here).
        let transferTrends = BigMomentStore.transferTrends(
            from: input.transferOutcomes, minimumReports: 3, limit: 2)
        if !transferTrends.isEmpty {
            lines.append("Real-world transfer patterns (self-report only, association not proof):")
            for trend in transferTrends {
                lines.append("  - \(trend.contextLine)")
            }
        }
        lines.append("")
        lines.append("Produce exactly 4 weeks.")
        return lines.joined(separator: "\n")
    }

    private func parsePlanWeeks(from data: Data, provider: AIProvider, input: ForwardPlanInput) -> [PlanWeek]? {
        guard let raw = extractContent(from: data, provider: provider),
              let payload = decodeJSON(from: raw),
              let weeksRaw = payload["weeks"] as? [[String: Any]] else {
            return nil
        }
        var weeks: [PlanWeek] = []
        for entry in weeksRaw {
            guard let weekIndex = entry["weekIndex"] as? Int,
                  (1...4).contains(weekIndex),
                  let focusRaw = entry["focus"] as? String,
                  let focus = CoachingPriority(rawValue: focusRaw),
                  let modeRaw = entry["mode"] as? String,
                  let mode = PracticeMode(rawValue: modeRaw),
                  let target = (entry["sessionTarget"] as? Int) ?? (entry["sessionTarget"] as? Double).map({ Int($0) }),
                  (2...5).contains(target),
                  let rationaleRaw = entry["rationale"] as? String else {
                return nil
            }
            let rationale = rationaleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rationale.isEmpty, rationale.count <= 240 else { return nil }
            let skill = Self.skillAreaForAIWeek(focus: focus)
            weeks.append(PlanWeek(
                weekIndex: weekIndex,
                focus: focus,
                focusSkillArea: skill,
                suggestedMode: mode,
                sessionTarget: target,
                rationale: rationale
            ))
        }
        // Ensure week indices are unique and complete 1..4.
        let indices = Set(weeks.map(\.weekIndex))
        guard indices == Set(1...4) else { return nil }
        return weeks.sorted { $0.weekIndex < $1.weekIndex }
    }

    /// Resolve a canonical SkillArea for an AI-returned week from its
    /// focus enum. The model returns focus + mode but not the canonical
    /// skill area; we infer it from this fixed map so downstream
    /// consumers (PLAN context section, Profile card) read consistent
    /// data regardless of which path generated the plan.
    nonisolated static func skillAreaForAIWeek(focus: CoachingPriority) -> SkillArea {
        switch focus {
        case .reduceFillers:  return .fillerReduction
        case .moreConcise:    return .conciseSpeaking
        case .calmerDelivery: return .pauseUsage
        case .thinkFaster:    return .confidence
        }
    }

    // MARK: - Provider plumbing (shared with AICoachChatService / AIInsightsService)

    private func extractContent(from data: Data, provider: AIProvider) -> String? {
        switch provider {
        case .openAI, .deepSeek:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }
            return content
        case .gemini:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return nil }
            return parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        case .none:
            return nil
        }
    }

    private func decodeJSON(from raw: String) -> [String: Any]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        let unfenced = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = unfenced.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        return nil
    }
}

// MARK: - Plan rendering for coach messages

/// Pure-function helpers that turn a `ForwardPlan` into the coach-voice
/// text dropped into the Ask Noum thread. Kept separate from the service
/// so the rendering shape is testable and doesn't depend on the actor.
enum ForwardPlanRenderer {

    /// Multi-paragraph coach turn that introduces the plan in the
    /// user's voice. The structure follows the £130/hr coach handoff
    /// shape: open with the verdict, walk the four weeks, close with
    /// a single concrete next move.
    static func coachMessage(
        for plan: ForwardPlan,
        voice: SpeakingStyleGoal?,
        bigMoment: BigMoment?
    ) -> String {
        var paragraphs: [String] = []

        paragraphs.append(openingLine(voice: voice, bigMoment: bigMoment, isAIBacked: plan.isAIBacked))

        // One paragraph per week — keeps the text scannable and the
        // structure obvious. The four-week cadence reads as "I've
        // thought about this in steps," not "here's a blob."
        for week in plan.weeks.sorted(by: { $0.weekIndex < $1.weekIndex }) {
            paragraphs.append(weekParagraph(week))
        }

        paragraphs.append(closingLine(plan: plan, voice: voice))
        return paragraphs.joined(separator: "\n\n")
    }

    private static func openingLine(voice: SpeakingStyleGoal?, bigMoment: BigMoment?, isAIBacked: Bool) -> String {
        let frame: String
        if let bigMoment {
            frame = "Here is your four-week program leading into your \(bigMoment.category.displayName)."
        } else {
            frame = "Here is your four-week program."
        }
        let provenance = "I shaped it around your recent reps and the voice you're training."
        return "\(frame) \(provenance)"
    }

    private static func weekParagraph(_ week: PlanWeek) -> String {
        "Week \(week.weekIndex) — \(week.focusSkillArea.displayName). \(week.suggestedMode.displayLabel), \(week.sessionTarget) rep\(week.sessionTarget == 1 ? "" : "s"). \(week.rationale)"
    }

    private static func closingLine(plan: ForwardPlan, voice: SpeakingStyleGoal?) -> String {
        guard let first = plan.weeks.first(where: { $0.weekIndex == 1 }) else {
            return "Start a practice rep when you're ready."
        }
        switch voice {
        case .authoritative:
            return "First move: a \(first.suggestedMode.displayLabel) rep on \(first.focusSkillArea.displayName.lowercased())."
        case .warm:
            return "When you're ready, start \(first.suggestedMode.displayLabel) — that's the gentlest first step."
        case .concise:
            return "Start: \(first.suggestedMode.displayLabel). \(first.focusSkillArea.displayName)."
        case .persuasive:
            return "Start \(first.suggestedMode.displayLabel) — Week 1 builds the case for the program."
        case .executive:
            return "Recommendation: start \(first.suggestedMode.displayLabel) this week."
        case .storytelling:
            return "Chapter one is \(first.suggestedMode.displayLabel) — that's where the arc begins."
        case .none:
            return "Start \(first.suggestedMode.displayLabel) when you're ready."
        }
    }
}
