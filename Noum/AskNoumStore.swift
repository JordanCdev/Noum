#if canImport(SwiftUI)
import Foundation
import Combine
import os
#if canImport(Security)
import Security
#endif

// MARK: - Ask Noum chat message + store
//
// The user's persistent thread with their AI coach. Distinct from the
// IM mode's conversation partner: this is the user *talking to Noum
// about their speaking practice*, not an NPC conversation rep. The
// thread persists per-account and survives app restarts so the user
// can come back to an ongoing coaching dialogue.
//
// Design rules:
//   • Per-account persistence — same convention as every other
//     UserDefaults-backed store (`<key>.<accountID>`). Switching
//     accounts shows that account's thread; a fresh sign-in is a
//     fresh blank thread.
//   • Bounded history — cap at 40 messages on disk. Older messages
//     drop off the top. Keeps the persisted blob small and protects
//     the model's context window from runaway growth.
//   • Idempotent send tracking — every user-authored message gets a
//     UUID at send-time so retries can dedupe and the UI can render
//     a "pending" state without flickering identity.
//   • No backend sync — chat lives on-device. Adding Firestore sync
//     would be a future move; today the priority is "feel intimate"
//     and on-device-only achieves that with zero infra.

/// Direction / authorship of a chat message.
enum CoachMessageRole: String, Codable, Equatable {
    case user
    case coach
    /// A "system" notice rendered in-thread (e.g. "Coach paused — \
    /// configure an AI provider to continue"). Not sent to the model.
    case systemNotice
}

/// Result of the semantic judgement gate for an accepted coach turn.
/// Stored with the row so shallow/repaired turns can be audited later.
enum CoachTurnSemanticGateOutcome: Codable, Equatable {
    case notEvaluated
    case passed
    case failed(String)

    var logValue: String {
        switch self {
        case .notEvaluated:
            return "notEvaluated"
        case .passed:
            return "passed"
        case .failed(let issue):
            return "failed:\(issue)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case state, issue
    }

    private enum State: String, Codable {
        case notEvaluated, passed, failed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(State.self, forKey: .state) {
        case .notEvaluated:
            self = .notEvaluated
        case .passed:
            self = .passed
        case .failed:
            self = .failed(try c.decode(String.self, forKey: .issue))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .notEvaluated:
            try c.encode(State.notEvaluated, forKey: .state)
        case .passed:
            try c.encode(State.passed, forKey: .state)
        case .failed(let issue):
            try c.encode(State.failed, forKey: .state)
            try c.encode(issue, forKey: .issue)
        }
    }
}

/// Compact final state for the hidden quality gates that ran before a coach
/// reply reached the user. Stored without draft text so production rows can be
/// audited without persisting failed model output.
enum CoachTurnQualityGateOutcome: Codable, Equatable {
    case notEvaluated
    case passed
    case repaired(String)
    case fallback(String)
    case failed(String)

    var logValue: String {
        switch self {
        case .notEvaluated:
            return "notEvaluated"
        case .passed:
            return "passed"
        case .repaired(let gate):
            return "repaired:\(gate)"
        case .fallback(let gate):
            return "fallback:\(gate)"
        case .failed(let gate):
            return "failed:\(gate)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case state, gate
    }

    private enum State: String, Codable {
        case notEvaluated, passed, repaired, fallback, failed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(State.self, forKey: .state) {
        case .notEvaluated:
            self = .notEvaluated
        case .passed:
            self = .passed
        case .repaired:
            self = .repaired(try c.decode(String.self, forKey: .gate))
        case .fallback:
            self = .fallback(try c.decode(String.self, forKey: .gate))
        case .failed:
            self = .failed(try c.decode(String.self, forKey: .gate))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .notEvaluated:
            try c.encode(State.notEvaluated, forKey: .state)
        case .passed:
            try c.encode(State.passed, forKey: .state)
        case .repaired(let gate):
            try c.encode(State.repaired, forKey: .state)
            try c.encode(gate, forKey: .gate)
        case .fallback(let gate):
            try c.encode(State.fallback, forKey: .state)
            try c.encode(gate, forKey: .gate)
        case .failed(let gate):
            try c.encode(State.failed, forKey: .state)
            try c.encode(gate, forKey: .gate)
        }
    }
}

struct CoachTurnProviderChoice: Equatable, Sendable {
    let providerName: String
    let model: String
    let resolvedTier: CoachProviderTier?
    let policyVersion: String?
    let generationMode: CoachChatGenerationMode?

    init(
        providerName: String,
        model: String,
        resolvedTier: CoachProviderTier? = nil,
        policyVersion: String? = nil,
        generationMode: CoachChatGenerationMode? = nil
    ) {
        self.providerName = providerName
        self.model = model
        self.resolvedTier = resolvedTier
        self.policyVersion = policyVersion
        self.generationMode = generationMode
    }
}

struct CoachRetrievalTrace: Codable, Equatable {
    var strategy: String
    var queryPresent: Bool
    var queryCharacterCount: Int
    var hasDiagnosis: Bool
    var activeLever: String?
    var voice: String?
    var semanticRerankAllowed: Bool
    var retrievedCardCount: Int
    var retrievedCardIDs: [String]
    var diagnosticReason: String
}

enum CoachPromptCachePolicy: String, Codable, Equatable {
    case none
    case ephemeral
}

struct CoachPromptModuleTrace: Codable, Equatable {
    let name: String
    let cachePolicy: CoachPromptCachePolicy
    let characterCount: Int
    let nonEmptyLineCount: Int
    /// True only when this exact module crosses the normal secure wire.
    /// Nil means legacy trace data recorded before secure-wire provenance.
    let secureTransportTransmitted: Bool?
}

struct CoachPromptTrace: Codable, Equatable {
    let moduleCount: Int
    let cacheableModuleCount: Int
    let totalCharacterCount: Int
    let modules: [CoachPromptModuleTrace]

    static func make(
        systemPrompt: String,
        userContext: String
    ) -> CoachPromptTrace {
        let modules = [
            moduleTrace(
                name: "coachSystemPrompt",
                text: systemPrompt,
                cachePolicy: .ephemeral,
                secureTransportTransmitted: false
            ),
            moduleTrace(
                name: "userContext",
                text: userContext,
                cachePolicy: .none,
                secureTransportTransmitted: true
            )
        ]
        return CoachPromptTrace(
            moduleCount: modules.count,
            cacheableModuleCount: modules.filter { $0.cachePolicy != .none }.count,
            totalCharacterCount: systemPrompt.count + userContext.count,
            modules: modules
        )
    }

    private static func moduleTrace(
        name: String,
        text: String,
        cachePolicy: CoachPromptCachePolicy,
        secureTransportTransmitted: Bool
    ) -> CoachPromptModuleTrace {
        CoachPromptModuleTrace(
            name: name,
            cachePolicy: cachePolicy,
            characterCount: text.count,
            nonEmptyLineCount: text
                .split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .count,
            secureTransportTransmitted: secureTransportTransmitted
        )
    }
}

enum CoachFirstVisibleTokenSource: String, Codable, Equatable {
    case localImmediateRead
    case streamedProviderPartial
    case finalReplyCommit
}

/// Persisted per-turn observability for the Ask Noum coach thread.
///
/// Optional fields keep old persisted rows decodable and let non-pipeline
/// injected artifacts stay lightweight. The pushback fields are the ones the
/// store can update after the fact when the user's next turn is a trust-repair
/// prompt.
struct CoachTurnMetadata: Codable, Equatable {
    var turnDepth: CoachTurnDepth?
    var providerTier: CoachProviderTier?
    var providerTierChosen: CoachProviderTier?
    var semanticGateOutcome: CoachTurnSemanticGateOutcome?
    var semanticGateIssue: String?
    var evidenceCoverage: Double?
    var assessment: CoachAssessment?
    var assessmentConfidence: Double?
    var proofTestHash: String?
    var proofTestRecentlyRepeated: Bool?
    var retrievalTrace: CoachRetrievalTrace?
    var promptTrace: CoachPromptTrace?
    var serverPolicyVersion: String?
    var serverGenerationMode: CoachChatGenerationMode?
    var visionScore: Int?
    var visionCriticalMisses: [CoachVisionCriterion]?
    var visionPassesProductionFloor: Bool?
    var qualityGateOutcome: CoachTurnQualityGateOutcome?
    var qualityGateFailureCount: Int?
    var qualityGateRepairCount: Int?
    /// Ordered hidden-gate trail as compact log values (for example
    /// `rejected:semantic:trustRepairMissed`, `repaired:vision:72:bridge`).
    /// Kept as strings so persisted rows remain independent of draft text and
    /// of any future in-memory event enum changes.
    var qualityGateEvents: [String]?
    var assessmentCacheHit: Bool?
    var assessmentCacheAgeMs: Int?
    var immediateCoachReadShown: Bool?
    var replyWordCount: Int?
    var providerRetryCount: Int?
    var providerAttemptCount: Int?
    var providerRefusalCount: Int?
    var ttftMs: Int?
    var fullLatencyMs: Int?
    var timeToFirstVisibleTokenMs: Int?
    var timeToFirstVisibleTokenSource: CoachFirstVisibleTokenSource?
    var timeToCompleteReplyMs: Int?
    var providerName: String?
    var providerModel: String?
    var userImmediatePushback: Bool
    var userPushbackWithinTwoTurns: Bool?
    var coldnessComplaintFlag: Bool?
    var softPushbackFlag: Bool?
    var voiceBargeInOccurred: Bool?
    var trajectoryCacheHit: Bool?
    var surface: CoachReplySurface?
    /// Reliability-gate findings on the final reply (blocking + soft). Empty/nil
    /// when the gate did not run or found nothing.
    var reliabilityIssues: [CoachReliabilityIssue]?
    /// True when a blocking reliability issue caused the truthful fallback to
    /// replace the provider's reply before it reached the UI.
    var reliabilityFallbackApplied: Bool?

    init(
        turnDepth: CoachTurnDepth? = nil,
        providerTier: CoachProviderTier? = nil,
        providerTierChosen: CoachProviderTier? = nil,
        semanticGateOutcome: CoachTurnSemanticGateOutcome? = nil,
        semanticGateIssue: String? = nil,
        evidenceCoverage: Double? = nil,
        assessment: CoachAssessment? = nil,
        assessmentConfidence: Double? = nil,
        proofTestHash: String? = nil,
        proofTestRecentlyRepeated: Bool? = nil,
        retrievalTrace: CoachRetrievalTrace? = nil,
        promptTrace: CoachPromptTrace? = nil,
        serverPolicyVersion: String? = nil,
        serverGenerationMode: CoachChatGenerationMode? = nil,
        visionScore: Int? = nil,
        visionCriticalMisses: [CoachVisionCriterion]? = nil,
        visionPassesProductionFloor: Bool? = nil,
        qualityGateOutcome: CoachTurnQualityGateOutcome? = nil,
        qualityGateFailureCount: Int? = nil,
        qualityGateRepairCount: Int? = nil,
        qualityGateEvents: [String]? = nil,
        assessmentCacheHit: Bool? = nil,
        assessmentCacheAgeMs: Int? = nil,
        immediateCoachReadShown: Bool? = nil,
        replyWordCount: Int? = nil,
        providerRetryCount: Int? = nil,
        providerAttemptCount: Int? = nil,
        providerRefusalCount: Int? = nil,
        ttftMs: Int? = nil,
        fullLatencyMs: Int? = nil,
        timeToFirstVisibleTokenMs: Int? = nil,
        timeToFirstVisibleTokenSource: CoachFirstVisibleTokenSource? = nil,
        timeToCompleteReplyMs: Int? = nil,
        providerName: String? = nil,
        providerModel: String? = nil,
        userImmediatePushback: Bool = false,
        userPushbackWithinTwoTurns: Bool? = nil,
        coldnessComplaintFlag: Bool? = nil,
        softPushbackFlag: Bool? = nil,
        voiceBargeInOccurred: Bool? = nil,
        trajectoryCacheHit: Bool? = nil,
        surface: CoachReplySurface? = nil,
        reliabilityIssues: [CoachReliabilityIssue]? = nil,
        reliabilityFallbackApplied: Bool? = nil
    ) {
        self.turnDepth = turnDepth
        self.providerTier = providerTier
        self.providerTierChosen = providerTierChosen
        self.semanticGateOutcome = semanticGateOutcome
        self.semanticGateIssue = semanticGateIssue
        self.evidenceCoverage = evidenceCoverage
        self.assessment = assessment
        self.assessmentConfidence = assessmentConfidence
        self.proofTestHash = proofTestHash
        self.proofTestRecentlyRepeated = proofTestRecentlyRepeated
        self.retrievalTrace = retrievalTrace
        self.promptTrace = promptTrace
        self.serverPolicyVersion = serverPolicyVersion
        self.serverGenerationMode = serverGenerationMode
        self.visionScore = visionScore
        self.visionCriticalMisses = visionCriticalMisses
        self.visionPassesProductionFloor = visionPassesProductionFloor
        self.qualityGateOutcome = qualityGateOutcome
        self.qualityGateFailureCount = qualityGateFailureCount
        self.qualityGateRepairCount = qualityGateRepairCount
        self.qualityGateEvents = qualityGateEvents
        self.assessmentCacheHit = assessmentCacheHit
        self.assessmentCacheAgeMs = assessmentCacheAgeMs
        self.immediateCoachReadShown = immediateCoachReadShown
        self.replyWordCount = replyWordCount
        self.providerRetryCount = providerRetryCount
        self.providerAttemptCount = providerAttemptCount
        self.providerRefusalCount = providerRefusalCount
        self.ttftMs = ttftMs
        self.fullLatencyMs = fullLatencyMs
        self.timeToFirstVisibleTokenMs = timeToFirstVisibleTokenMs ?? ttftMs
        self.timeToFirstVisibleTokenSource = timeToFirstVisibleTokenSource
        self.timeToCompleteReplyMs = timeToCompleteReplyMs ?? fullLatencyMs
        self.providerName = providerName
        self.providerModel = providerModel
        self.userImmediatePushback = userImmediatePushback
        self.userPushbackWithinTwoTurns = userPushbackWithinTwoTurns
        self.coldnessComplaintFlag = coldnessComplaintFlag
        self.softPushbackFlag = softPushbackFlag
        self.voiceBargeInOccurred = voiceBargeInOccurred
        self.trajectoryCacheHit = trajectoryCacheHit
        self.surface = surface
        self.reliabilityIssues = reliabilityIssues
        self.reliabilityFallbackApplied = reliabilityFallbackApplied
    }
}

/// One message in the Ask-Noum thread.
struct CoachMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: CoachMessageRole
    let text: String
    let createdAt: Date
    /// True while the model is generating the reply. Only ever true for
    /// `.coach` rows; the UI renders a typing-style placeholder for these.
    var isPending: Bool
    /// Legacy offline marker for coach rows persisted by older builds that
    /// hydrated local fallback copy as `.coach`. New Ask Noum turns no longer
    /// create offline coach rows; provider problems become `.systemNotice`.
    ///
    /// Kept as a flag on the EXISTING `.coach` role (rather than a new role)
    /// so every chip / word-reveal / continuation call site that keys off
    /// `role == .coach` keeps working unchanged — only the bubble's visual
    /// treatment branches on this flag.
    var isOffline: Bool
    /// Optional judgement / latency metadata for coach turns. Kept on the
    /// message rather than a parallel store so replay, persistence, and trust
    /// repair all move with the row they describe.
    var metadata: CoachTurnMetadata?

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        text: String,
        createdAt: Date = Date(),
        isPending: Bool = false,
        isOffline: Bool = false,
        metadata: CoachTurnMetadata? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.isPending = isPending
        self.isOffline = isOffline
        self.metadata = metadata
    }

    // Custom decoder so threads persisted BEFORE `isOffline` existed still
    // load — the synthesised `Decodable` would fail on the missing key. Old
    // rows decode as not-offline (the conservative default: an unknown
    // historical row reads as a normal coach bubble, never falsely "offline").
    private enum CodingKeys: String, CodingKey {
        case id, role, text, createdAt, isPending, isOffline, metadata
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.role = try c.decode(CoachMessageRole.self, forKey: .role)
        self.text = try c.decode(String.self, forKey: .text)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.isPending = try c.decodeIfPresent(Bool.self, forKey: .isPending) ?? false
        self.isOffline = try c.decodeIfPresent(Bool.self, forKey: .isOffline) ?? false
        self.metadata = try c.decodeIfPresent(CoachTurnMetadata.self, forKey: .metadata)
    }
}

/// A synchronous admission captured before an availability or other async
/// preflight. It proves which hydrated account authorized the eventual send;
/// callers must revalidate it before appending text captured before an await.
struct AskNoumSendAdmission: Equatable, Sendable {
    let accountScope: String
    let accountLifecycleGeneration: UInt64
    let threadStoreGeneration: UInt64
}

/// Authority for one pending coach row. Provider work and every provisional,
/// final, or cancellation mutation carry this exact value so a UUID alone can
/// never hydrate a row after sign-out, deletion, reload, or account switch.
struct AskNoumReplyLease: Equatable, Sendable {
    let accountScope: String
    let accountLifecycleGeneration: UInt64
    let threadStoreGeneration: UInt64
    let coachID: UUID
}

/// Authority for one account-scoped provider request that does not own a
/// pending coach row, such as starter or follow-up chip generation. These
/// requests still carry conversation context, so deletion must revoke them at
/// the same boundary as a full coach reply.
struct AskNoumAuxiliaryProviderLease: Equatable, Sendable {
    let accountScope: String
    let accountLifecycleGeneration: UInt64
    let threadStoreGeneration: UInt64
    let workID: UUID
}

/// Persisted thread + send / replay surface for the Ask-Noum chat.
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class AskNoumStore: ObservableObject {

    static let shared = AskNoumStore()
    private static let log = Logger(subsystem: "com.jordancoaten.noum", category: "AskNoumStore")

    // MARK: - Conversation evidence gate
    //
    // PracticeSessionStore remains the owner of completed reps. Ask Noum only
    // owns the policy those reps unlock: until one completed rep exists, both
    // typed and live coaching stay on the same read-only first-rep door. Keep
    // this pure so routing and direct-entry defenses cannot drift apart.

    /// Whether Ask Noum has enough real practice evidence to open an
    /// interactive coaching surface. A chosen profile shapes the eventual
    /// coach voice, but is stated intent rather than observed evidence and
    /// therefore never satisfies this gate by itself.
    nonisolated static func hasCompletedPracticeEvidence(sessionCount: Int) -> Bool {
        sessionCount > 0
    }

    /// Cap on the number of messages held on disk. Older messages drop
    /// off the front when the cap is exceeded. 40 covers ~20 turns of
    /// conversation, which is plenty for coaching continuity without
    /// blowing the model's context window on replay.
    private static let maxStoredMessages = 40

    /// Storage key prefix. Joined with the account ID the same way
    /// every other per-account value is keyed.
    private static let storagePrefix = "askNoum.thread"

    @Published private(set) var messages: [CoachMessage] = []

    /// True while a `coach` reply is mid-flight. UI uses this to
    /// disable the input bar and show the pending message row.
    @Published private(set) var isAwaitingReply: Bool = false

    /// Operational failures are transient UI state, never conversation. The
    /// user's turn stays in the thread and can be retried without adding a
    /// duplicate message.
    @Published private(set) var lastFailure: ChatFailure?

    var transientFailureMessage: String? {
        lastFailure.map { Self.noticeCopy(for: $0) }
    }

    /// AI-tailored follow-up chips keyed by the coach message ID they
    /// belong to. Lets `AskNoumView` request chips once per reply, cache
    /// the result, and read it back synchronously on every view rebuild
    /// without re-rolling the generation request (which would burn
    /// tokens + jitter the chip text under the user's finger).
    ///
    /// In-memory only — chips are conversational ephemera tied to the
    /// current view session. A relaunched app starts fresh; the cost
    /// is one re-roll on the very last reply, the win is no persistence
    /// surface dragging stale model output across sessions.
    ///
    /// Cleared by `clearThread()` so a thread-wipe doesn't leave
    /// orphaned chip data for IDs that no longer exist.
    @Published private(set) var aiChipsCache: [UUID: [String]] = [:]

    /// AI-tailored EMPTY-STATE starter prompts, cached against a stable
    /// signature of the inputs that shape them (chosen voice + active
    /// BigMoment + weakest baseline dimension). Unlike `aiChipsCache`,
    /// which keys by coach message ID, the starter row is a single
    /// pre-conversation surface — one cached set at a time. Keying by a
    /// signature means a voice change / a new upcoming moment / a shifted
    /// weakest dimension re-rolls the starters, while idle re-renders
    /// (keyboard focus, scroll) reuse the cached set without re-rolling
    /// the generation request.
    ///
    /// In-memory only — same rationale as `aiChipsCache`: starters are
    /// pre-conversation ephemera, not a persistence surface. A relaunch
    /// re-rolls once; until a clean AI set arrives the view simply shows no
    /// suggested ask rather than a deterministic coach-like fallback.
    ///
    /// Cleared by `clearThread()` alongside the reply chip cache.
    @Published private(set) var starterChipsCache: [String: [String]] = [:]

    /// Set by `injectUserTurn(_:)` when a different surface (e.g. the
    /// post-session Summary's "Talk to your coach about this rep" CTA)
    /// drops a seed message into the thread *before* AskNoumView has
    /// mounted. AskNoumView consumes this on appear and triggers the
    /// coach reply for the matching pending row. Nil at rest.
    ///
    /// Why this lives on the store rather than as a parameter on
    /// AskNoumView's init: the inject + the navigation push are two
    /// independent events that must survive the gap between them
    /// (the user tapping the bridge → SwiftUI mounting AskNoumView).
    /// A published store property bridges that gap without forcing the
    /// caller to know about AskNoumView's lifecycle.
    @Published private(set) var pendingInjectedCoachID: UUID? = nil

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?
    private let accountLifecycleGenerationProvider: () -> UInt64
    private let accountIsReadyProvider: () -> Bool
    private let providerWorkAllowedProvider: (String) -> Bool
    private let diagnosticsStore: AICallDiagnosticsStore?
    /// Account whose thread is actually resident in `messages`. This must not
    /// be inferred from the current Keychain identity during an account switch;
    /// registry hydration owns when a newly identified account is loaded.
    private(set) var loadedAccountScope: String? = nil
    private var threadStoreGeneration: UInt64 = 0

    private struct ActiveProviderWork {
        let lease: AskNoumReplyLease
        let cancel: @MainActor () -> Void
    }

    private struct ActiveAuxiliaryProviderWork {
        let lease: AskNoumAuxiliaryProviderLease
        let cancel: @MainActor () -> Void
    }

    /// Best-effort transport cancellation. Lease checks remain authoritative:
    /// a request can already have reached a provider before cancellation lands.
    private var activeProviderWorkByCoachID: [UUID: ActiveProviderWork] = [:]
    private var activeAuxiliaryProviderWorkByID: [UUID: ActiveAuxiliaryProviderWork] = [:]

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil,
        accountLifecycleGenerationProvider: (() -> UInt64)? = nil,
        accountIsReadyProvider: (() -> Bool)? = nil,
        providerWorkAllowedProvider: ((String) -> Bool)? = nil,
        diagnosticsStore: AICallDiagnosticsStore? = nil
    ) {
        self.defaults = defaults
        self.diagnosticsStore = diagnosticsStore
        if let provider = accountIDProvider {
            self.accountIDProvider = provider
        } else {
            self.accountIDProvider = { Self.defaultAccountIDProvider() }
        }
        self.accountLifecycleGenerationProvider = accountLifecycleGenerationProvider ?? {
            AuthManager.shared.accountLifecycleGeneration
        }
        if let accountIsReadyProvider {
            self.accountIsReadyProvider = accountIsReadyProvider
        } else if accountIDProvider != nil {
            // Existing isolated stores predate AuthManager injection. Their
            // explicit identity closure is their complete test lifecycle.
            self.accountIsReadyProvider = { true }
        } else {
            self.accountIsReadyProvider = {
                AuthManager.shared.isSignedIn
                    && AuthManager.shared.initialAccountHydrationState == .ready
            }
        }
        if let providerWorkAllowedProvider {
            self.providerWorkAllowedProvider = providerWorkAllowedProvider
        } else if accountIDProvider != nil {
            self.providerWorkAllowedProvider = { _ in true }
        } else {
            self.providerWorkAllowedProvider = { accountID in
                AuthManager.shared.isProviderWorkAllowed(for: accountID)
            }
        }
        loadedAccountScope = currentAccountScope
        if let loadedAccountScope {
            loadFromDisk(accountScope: loadedAccountScope)
        }
    }

    /// Append a user-authored message + a pending coach row. Returns
    /// the IDs of both so the caller can hydrate the coach row once
    /// the service returns.
    @discardableResult
    func appendUserTurn(_ text: String) -> (userID: UUID, coachID: UUID) {
        guard let admission = sendAdmission(),
              let dispatch = appendUserTurn(text, expected: admission) else {
            // Source-compatible rejection for legacy synchronous callers. No
            // row is appended and the detached IDs cannot acquire a lease.
            return (UUID(), UUID())
        }
        return (dispatch.userID, dispatch.coachID)
    }

    /// Checked send boundary used after async availability work. The admission
    /// was captured before suspension and is revalidated on this actor turn;
    /// the returned reply lease is inseparable from the pending row it owns.
    @discardableResult
    func appendUserTurn(
        _ text: String,
        expected admission: AskNoumSendAdmission
    ) -> (userID: UUID, coachID: UUID, lease: AskNoumReplyLease)? {
        guard sendAdmissionIsCurrent(admission) else { return nil }
        lastFailure = nil
        markImmediatePushbackIfNeeded(for: text)
        let userMsg = CoachMessage(role: .user, text: text)
        let coachMsg = CoachMessage(role: .coach, text: "", isPending: true)
        messages.append(userMsg)
        messages.append(coachMsg)
        isAwaitingReply = true
        trimAndPersist()
        return (
            userMsg.id,
            coachMsg.id,
            AskNoumReplyLease(
                accountScope: admission.accountScope,
                accountLifecycleGeneration: admission.accountLifecycleGeneration,
                threadStoreGeneration: admission.threadStoreGeneration,
                coachID: coachMsg.id
            )
        )
    }

    /// Hydrate the pending coach row once the service returns. Only a live
    /// `.reply` becomes a coach bubble. Any non-live outcome becomes a system
    /// notice with cause-specific copy, so Ask Noum never presents a local
    /// deterministic line as the intelligent coach.
    func completeCoachTurn(
        id: UUID,
        outcome: ChatOutcome,
        metadata: CoachTurnMetadata? = nil
    ) {
        guard let lease = replyLease(for: id) else { return }
        _ = completeCoachTurn(
            id: id,
            outcome: outcome,
            metadata: metadata,
            expected: lease
        )
    }

    /// Compare-and-complete boundary for async replies. Persistence targets the
    /// account embedded in the lease and never re-derives a destination from a
    /// mutable Keychain identity.
    @discardableResult
    func completeCoachTurn(
        id: UUID,
        outcome: ChatOutcome,
        metadata: CoachTurnMetadata? = nil,
        expected lease: AskNoumReplyLease
    ) -> Bool {
        guard id == lease.coachID,
              replyLeaseIsCurrent(lease),
              let idx = messages.firstIndex(where: { $0.id == id }) else {
            return false
        }
        let resolvedMetadata = Self.metadataByPreservingMutableFlags(
            incoming: metadata,
            existing: messages[idx].metadata
        )
        switch outcome {
        case .reply(let text):
            let trimmed = CoachDisplayCopy.normalized(
                CoachReplyTextSanitizer.coachReplyText(from: text)
            )
            if trimmed.isEmpty {
                // Defensive: a live empty should be `.failure(.empty)`, but if
                // it reaches the store, route through the same notice instead
                // of leaving a blank coach bubble.
                Self.log.error("coach turn completed with empty normalized text")
                resolveFailure(at: idx, failure: .empty)
            } else {
                if trimmed != text.trimmingCharacters(in: .whitespacesAndNewlines) {
                    Self.log.notice("normalized coach turn before persistence id=\(id.uuidString, privacy: .public)")
                }
                messages[idx] = CoachMessage(
                    id: id,
                    role: .coach,
                    text: trimmed,
                    createdAt: messages[idx].createdAt,
                    isPending: false,
                    isOffline: false,
                    metadata: resolvedMetadata
                )
                Self.log.info("coach turn stored as live reply chars=\(trimmed.count, privacy: .public)")
            }
        case .failure(let failure):
            Self.log.notice("coach turn resolved as transient failure cause=\(String(describing: failure), privacy: .public)")
            resolveFailure(at: idx, failure: failure)
        }
        isAwaitingReply = false
        trimAndPersist(accountScope: lease.accountScope)
        return true
    }

    /// Hydrate the pending coach row with a local deterministic read while the
    /// live model is still verbalising the final reply. The row stays pending
    /// and is never persisted, so this improves perceived latency without
    /// masquerading as the final AI coach response.
    @discardableResult
    func setProvisionalCoachRead(
        id: UUID,
        text: String,
        metadata: CoachTurnMetadata? = nil
    ) -> Bool {
        guard let lease = replyLease(for: id) else { return false }
        return setProvisionalCoachRead(
            id: id,
            text: text,
            metadata: metadata,
            expected: lease
        )
    }

    /// Checked provisional mutation. The row remains pending so the same lease
    /// can authorize a later streamed partial or final completion.
    @discardableResult
    func setProvisionalCoachRead(
        id: UUID,
        text: String,
        metadata: CoachTurnMetadata? = nil,
        expected lease: AskNoumReplyLease
    ) -> Bool {
        let trimmed = CoachDisplayCopy.normalized(
            CoachReplyTextSanitizer.coachReplyText(from: text)
        )
        guard id == lease.coachID,
              replyLeaseIsCurrent(lease),
              !trimmed.isEmpty,
              let idx = messages.firstIndex(where: { $0.id == id }),
              messages[idx].role == .coach,
              messages[idx].isPending else {
            return false
        }
        messages[idx] = CoachMessage(
            id: id,
            role: .coach,
            text: trimmed,
            createdAt: messages[idx].createdAt,
            isPending: true,
            isOffline: false,
            metadata: metadata ?? messages[idx].metadata
        )
        Self.log.info("coach turn provisional read visible chars=\(trimmed.count, privacy: .public)")
        return true
    }

    /// Live-call telemetry: the user tapped Talk while the spoken coach reply
    /// was still playing. Store it on the coach row that got interrupted, not
    /// in a parallel live-call store, so transcript review and replay audits see
    /// the same row-level signals as pushback/coldness.
    @discardableResult
    func markLatestCoachTurnVoiceBargeIn() -> Bool {
        guard let idx = messages.lastIndex(where: {
            $0.role == .coach &&
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            return false
        }

        var metadata = messages[idx].metadata ?? CoachTurnMetadata()
        metadata.voiceBargeInOccurred = true
        messages[idx].metadata = metadata
        AICallDiagnostics.record(
            surface: "Ask Noum live barge-in",
            providerName: "User feedback",
            model: metadata.providerModel,
            outcome: .failure,
            reason: [
                "priorDepth=\(metadata.turnDepth?.rawValue ?? "unknown")",
                "provider=\(metadata.providerName ?? "unknown")",
                "providerTierChosen=\(metadata.providerTierChosen?.rawValue ?? "unknown")",
                "surface=\(metadata.surface?.rawValue ?? "unknown")",
                "voiceBargeInOccurred=true",
                "immediateCoachReadShown=\(metadata.immediateCoachReadShown.map { "\($0)" } ?? "unknown")",
                "replyWordCount=\(metadata.replyWordCount ?? -1)",
                "semanticGateIssue=\(metadata.semanticGateIssue ?? "none")",
                "visionScore=\(metadata.visionScore.map { "\($0)" } ?? "unknown")",
                "ttftMs=\(metadata.ttftMs ?? -1)",
                "timeToFirstVisibleTokenMs=\(metadata.timeToFirstVisibleTokenMs ?? -1)"
            ].joined(separator: " ")
        )
        persist()
        return true
    }

    private func resolveFailure(at idx: Int, failure: ChatFailure) {
        messages.remove(at: idx)
        lastFailure = failure
    }

    private static func metadataByPreservingMutableFlags(
        incoming: CoachTurnMetadata?,
        existing: CoachTurnMetadata?
    ) -> CoachTurnMetadata? {
        guard var metadata = incoming ?? existing else { return nil }
        guard let existing else { return metadata }
        if existing.userImmediatePushback {
            metadata.userImmediatePushback = true
        }
        if existing.userPushbackWithinTwoTurns != nil {
            metadata.userPushbackWithinTwoTurns = existing.userPushbackWithinTwoTurns
        }
        if existing.coldnessComplaintFlag != nil {
            metadata.coldnessComplaintFlag = existing.coldnessComplaintFlag
        }
        if existing.softPushbackFlag != nil {
            metadata.softPushbackFlag = existing.softPushbackFlag
        }
        if existing.voiceBargeInOccurred == true {
            metadata.voiceBargeInOccurred = true
        }
        return metadata
    }

    private func markImmediatePushbackIfNeeded(for userText: String) {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              TurnDepthClassifier.classify(
                userText: trimmed,
                recentTurns: replayForModel
              ) == .trustRepair,
              let idx = messages.lastIndex(where: {
                $0.role == .coach && !$0.isPending && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              }) else {
            return
        }

        var metadata = messages[idx].metadata ?? CoachTurnMetadata()
        metadata.userImmediatePushback = true
        metadata.userPushbackWithinTwoTurns = true
        metadata.coldnessComplaintFlag = Self.isColdnessComplaint(trimmed)
        metadata.softPushbackFlag = Self.isSoftPushback(trimmed)
        messages[idx].metadata = metadata
        let diagnostic = AICallDiagnostics.makeRecord(
            surface: "Ask Noum immediate pushback",
            providerName: "User feedback",
            model: metadata.providerModel,
            outcome: .failure,
            reason: [
                "priorDepth=\(metadata.turnDepth?.rawValue ?? "unknown")",
                "provider=\(metadata.providerName ?? "unknown")",
                "userPushbackWithinTwoTurns=\(metadata.userPushbackWithinTwoTurns.map { "\($0)" } ?? "unknown")",
                "coldnessComplaint=\(metadata.coldnessComplaintFlag.map { "\($0)" } ?? "unknown")",
                "softPushback=\(metadata.softPushbackFlag.map { "\($0)" } ?? "unknown")",
                "semanticGate=\(metadata.semanticGateOutcome?.logValue ?? "unknown")",
                "semanticGateIssue=\(metadata.semanticGateIssue ?? "none")",
                "qualityGate=\(metadata.qualityGateOutcome?.logValue ?? "unknown")",
                "qualityGateFailures=\(metadata.qualityGateFailureCount ?? 0)",
                "qualityGateRepairs=\(metadata.qualityGateRepairCount ?? 0)",
                "assessmentCacheHit=\(metadata.assessmentCacheHit.map { "\($0)" } ?? "unknown")",
                "assessmentCacheAgeMs=\(metadata.assessmentCacheAgeMs ?? -1)",
                "immediateCoachReadShown=\(metadata.immediateCoachReadShown.map { "\($0)" } ?? "unknown")",
                "replyWordCount=\(metadata.replyWordCount ?? -1)",
                "providerTierChosen=\(metadata.providerTierChosen?.rawValue ?? "unknown")",
                "providerRetryCount=\(metadata.providerRetryCount ?? 0)",
                "providerAttemptCount=\(metadata.providerAttemptCount ?? 0)",
                "providerRefusalCount=\(metadata.providerRefusalCount ?? 0)",
                "voiceBargeInOccurred=\(metadata.voiceBargeInOccurred.map { "\($0)" } ?? "unknown")",
                "visionScore=\(metadata.visionScore.map { "\($0)" } ?? "unknown")",
                "visionPassesFloor=\(metadata.visionPassesProductionFloor.map { "\($0)" } ?? "unknown")",
                "ttftMs=\(metadata.ttftMs ?? -1)",
                "timeToFirstVisibleTokenMs=\(metadata.timeToFirstVisibleTokenMs ?? -1)",
                "timeToCompleteReplyMs=\(metadata.timeToCompleteReplyMs ?? -1)"
            ].joined(separator: " ")
        )
        if let diagnosticsStore {
            diagnosticsStore.record(diagnostic)
        } else {
            AICallDiagnostics.record(diagnostic)
        }
    }

    private static func isSoftPushback(_ text: String) -> Bool {
        TurnDepthClassifier.isSoftPushback(
            text
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .replacingOccurrences(of: "\u{2018}", with: "'")
                .lowercased()
        )
    }

    private static func isColdnessComplaint(_ text: String) -> Bool {
        let lower = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .lowercased()
        return [
            "cold",
            "robotic",
            "generic ai",
            "generic tips",
            "ai tips",
            "ai wrapper",
            "low eq",
            "not high eq",
            "not human",
            "doesn't feel human",
            "does not feel human",
            "not like a coach",
            "nowhere near an expert coach",
            "no where near an expert coach"
        ].contains { lower.contains($0) }
    }

    /// User-facing copy per failure cause. First-person voice (Noum),
    /// sentence case, no exclamation marks, action-oriented — matches
    /// the coach voice rules used everywhere else.
    static func noticeCopy(for failure: ChatFailure) -> String {
        switch failure {
        case .noProvider:
            #if DEBUG
            return "Live coaching isn’t connected in this build."
            #else
            return "Noum is temporarily unavailable. Your message is still here."
            #endif
        case .consentRequired:
            return "Cloud coaching is off. Your message is still here. You can allow it in Settings > Cloud Processing."
        case .unauthenticated:
            return "Noum is temporarily unavailable. Your message is still here."
        case .coachUnavailable(let reason):
            switch reason {
            case .authenticationPending:
                return "Noum is temporarily unavailable. Your message is still here."
            case .localOnlyGuest:
                return "Connect this guest once to use live coaching. Your practice stays on this device if the connection fails."
            case .secureSessionMissing:
                return "Ask Noum needs its secure session reconnected. Your practice is unchanged."
            case .backendVersionMissing:
                return "This build’s Ask Noum service isn’t live yet. Updating the app won’t fix it. Your message is still here."
            case .debugProviderMissing:
                return "Live coaching isn’t connected in this build."
            case .service:
                return "Noum is temporarily unavailable. Your message is still here."
            }
        case .rateLimited:
            return "Noum is taking a short pause. Your message is still here. Try again in a moment."
        case .localeUnsupported:
            return "Live coaching is currently available in English. Your message is still here."
        case .network:
            return "Noum is temporarily unavailable. Your message is still here."
        case .empty:
            return "Noum couldn’t complete that coaching read. Your message is still here."
        case .contentRejected:
            return "Noum couldn’t complete that coaching read. Your message is still here."
        case .invalidRequest:
            return "Noum couldn’t accept that coaching request. Your message is still here."
        case .permissionDenied:
            return "Noum couldn’t verify access to coaching. Your message is still here."
        case .backendVersionMissing:
            return "This build’s Ask Noum service isn’t live yet. Updating the app won’t fix it. Your message is still here."
        }
    }

    // MARK: - Async account ownership

    /// Capture account authority before an async preflight. Readiness proves
    /// registry hydration has completed; the provider-work gate additionally
    /// closes immediately when account deletion begins.
    func sendAdmission() -> AskNoumSendAdmission? {
        guard accountIsReadyProvider(),
              let accountScope = currentAccountScope,
              loadedAccountScope == accountScope,
              providerWorkAllowedProvider(accountScope) else {
            return nil
        }
        return AskNoumSendAdmission(
            accountScope: accountScope,
            accountLifecycleGeneration: accountLifecycleGenerationProvider(),
            threadStoreGeneration: threadStoreGeneration
        )
    }

    func sendAdmissionIsCurrent(_ admission: AskNoumSendAdmission) -> Bool {
        guard accountIsReadyProvider(),
              currentAccountScope == admission.accountScope,
              loadedAccountScope == admission.accountScope,
              accountLifecycleGenerationProvider()
                == admission.accountLifecycleGeneration,
              threadStoreGeneration == admission.threadStoreGeneration,
              providerWorkAllowedProvider(admission.accountScope) else {
            return false
        }
        return true
    }

    /// Bind provider work to the exact pending row after a synchronous append.
    func replyLease(for coachID: UUID) -> AskNoumReplyLease? {
        guard let admission = sendAdmission(),
              messages.contains(where: {
                  $0.id == coachID && $0.role == .coach && $0.isPending
              }) else {
            return nil
        }
        return AskNoumReplyLease(
            accountScope: admission.accountScope,
            accountLifecycleGeneration: admission.accountLifecycleGeneration,
            threadStoreGeneration: admission.threadStoreGeneration,
            coachID: coachID
        )
    }

    /// Scope check remains useful immediately after a successful completion,
    /// when the row is intentionally no longer pending but UI speech still
    /// must not cross an account/lifecycle boundary.
    func replyLeaseScopeIsCurrent(_ lease: AskNoumReplyLease) -> Bool {
        sendAdmissionIsCurrent(AskNoumSendAdmission(
            accountScope: lease.accountScope,
            accountLifecycleGeneration: lease.accountLifecycleGeneration,
            threadStoreGeneration: lease.threadStoreGeneration
        ))
    }

    func replyLeaseIsCurrent(_ lease: AskNoumReplyLease) -> Bool {
        replyLeaseScopeIsCurrent(lease)
            && messages.contains(where: {
                $0.id == lease.coachID && $0.role == .coach && $0.isPending
            })
    }

    /// Register the explicit provider task only while its pending-row lease is
    /// current. The closure is actor-isolated because Task cancellation and the
    /// registry's deletion hook both originate on MainActor.
    @discardableResult
    func registerProviderWorkCancellation(
        expected lease: AskNoumReplyLease,
        cancel: @escaping @MainActor () -> Void
    ) -> Bool {
        guard replyLeaseIsCurrent(lease),
              activeProviderWorkByCoachID[lease.coachID] == nil else {
            return false
        }
        activeProviderWorkByCoachID[lease.coachID] = ActiveProviderWork(
            lease: lease,
            cancel: cancel
        )
        return true
    }

    func unregisterProviderWorkCancellation(expected lease: AskNoumReplyLease) {
        guard activeProviderWorkByCoachID[lease.coachID]?.lease == lease else {
            return
        }
        activeProviderWorkByCoachID.removeValue(forKey: lease.coachID)
    }

    /// Capture a distinct lease for provider work that has no pending coach
    /// row. Registration must still happen synchronously before the child task
    /// gets an actor turn.
    func auxiliaryProviderLease(
        expected admission: AskNoumSendAdmission
    ) -> AskNoumAuxiliaryProviderLease? {
        guard sendAdmissionIsCurrent(admission) else { return nil }
        return AskNoumAuxiliaryProviderLease(
            accountScope: admission.accountScope,
            accountLifecycleGeneration: admission.accountLifecycleGeneration,
            threadStoreGeneration: admission.threadStoreGeneration,
            workID: UUID()
        )
    }

    @discardableResult
    func registerAuxiliaryProviderWorkCancellation(
        expected lease: AskNoumAuxiliaryProviderLease,
        cancel: @escaping @MainActor () -> Void
    ) -> Bool {
        guard auxiliaryProviderScopeIsCurrent(lease),
              activeAuxiliaryProviderWorkByID[lease.workID] == nil else {
            return false
        }
        activeAuxiliaryProviderWorkByID[lease.workID] = ActiveAuxiliaryProviderWork(
            lease: lease,
            cancel: cancel
        )
        return true
    }

    func unregisterAuxiliaryProviderWork(
        expected lease: AskNoumAuxiliaryProviderLease
    ) {
        guard activeAuxiliaryProviderWorkByID[lease.workID]?.lease == lease else {
            return
        }
        activeAuxiliaryProviderWorkByID.removeValue(forKey: lease.workID)
    }

    func auxiliaryProviderWorkIsCurrent(
        _ lease: AskNoumAuxiliaryProviderLease
    ) -> Bool {
        auxiliaryProviderScopeIsCurrent(lease)
            && activeAuxiliaryProviderWorkByID[lease.workID]?.lease == lease
    }

    /// The final gate and actual URLSession start share one MainActor turn.
    /// Deletion cannot interleave between the lease check and invocation; once
    /// suspended, cancelling the registered child task propagates to the
    /// async URLSession operation as a best-effort transport cancellation.
    func performAuxiliaryProviderRequest(
        _ request: URLRequest,
        expected lease: AskNoumAuxiliaryProviderLease,
        transport: @MainActor (URLRequest) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(for: $0)
        }
    ) async throws -> (Data, URLResponse) {
        guard auxiliaryProviderWorkIsCurrent(lease),
              !Task.isCancelled else {
            throw CancellationError()
        }
        return try await transport(request)
    }

    private func auxiliaryProviderScopeIsCurrent(
        _ lease: AskNoumAuxiliaryProviderLease
    ) -> Bool {
        sendAdmissionIsCurrent(AskNoumSendAdmission(
            accountScope: lease.accountScope,
            accountLifecycleGeneration: lease.accountLifecycleGeneration,
            threadStoreGeneration: lease.threadStoreGeneration
        ))
    }

    /// Re-arm the latest unanswered user turn without appending it again.
    /// Returns the pending coach row ID the existing reply pipeline should
    /// hydrate.
    func prepareRetry() -> UUID? {
        guard let admission = sendAdmission(),
              let retry = prepareRetry(expected: admission) else {
            return nil
        }
        return retry.coachID
    }

    /// Checked retry admission for callers returning from availability work.
    func prepareRetry(
        expected admission: AskNoumSendAdmission
    ) -> (coachID: UUID, lease: AskNoumReplyLease)? {
        guard sendAdmissionIsCurrent(admission) else { return nil }
        guard !isAwaitingReply,
              lastFailure != nil,
              messages.last(where: { $0.role == .user }) != nil else {
            return nil
        }
        let coach = CoachMessage(role: .coach, text: "", isPending: true)
        messages.append(coach)
        lastFailure = nil
        isAwaitingReply = true
        trimAndPersist()
        return (
            coach.id,
            AskNoumReplyLease(
                accountScope: admission.accountScope,
                accountLifecycleGeneration: admission.accountLifecycleGeneration,
                threadStoreGeneration: admission.threadStoreGeneration,
                coachID: coach.id
            )
        )
    }

    /// Cancel an in-flight coach reply (user navigated away, etc.).
    /// Drops the pending row entirely so the thread doesn't show a
    /// stuck typing indicator.
    func cancelPendingCoachTurn(id: UUID) {
        guard let lease = replyLease(for: id) else { return }
        _ = cancelPendingCoachTurn(id: id, expected: lease)
    }

    @discardableResult
    func cancelPendingCoachTurn(
        id: UUID,
        expected lease: AskNoumReplyLease
    ) -> Bool {
        guard id == lease.coachID, replyLeaseIsCurrent(lease) else {
            return false
        }
        activeProviderWorkByCoachID.removeValue(forKey: id)?.cancel()
        messages.removeAll { $0.id == id }
        isAwaitingReply = false
        trimAndPersist(accountScope: lease.accountScope)
        return true
    }

    /// Clear the entire thread. Used by Settings → "Reset Ask Noum
    /// thread" + by account sign-out paths. UI confirms first; this
    /// is a one-button wipe.
    func clearThread() {
        invalidateReplyLeases(cancelActiveProviderWork: true)
        messages.removeAll()
        lastFailure = nil
        pendingInjectedCoachID = nil
        // Drop the AI chip cache too — every cached entry is keyed by
        // a coach message ID that no longer exists.
        aiChipsCache.removeAll()
        // Drop the empty-state starter cache as well — a wiped thread
        // returns to the empty state, which should re-roll fresh starters.
        starterChipsCache.removeAll()
        persist()
    }

    /// Per-account lifecycle — mirrors every other UserDefaults-backed store
    /// (CoachMemoryStore, PostRepCoachNoteStore, …) so `AuthManager`'s
    /// account-switch / session-reset / data-deletion plumbing covers the
    /// coach thread too. WITHOUT this registration, signing into account B
    /// showed account A's entire dialogue (and the model replayed A's turns as
    /// B's history via `replayForModel`), and account deletion never wiped the
    /// thread from disk — a GDPR-deletion leak.
    ///
    /// Reload: drop the in-memory thread, then read the NEW account's key.
    func reloadForCurrentAccount() {
        clearInMemoryState()
        loadedAccountScope = currentAccountScope
        if let loadedAccountScope {
            loadFromDisk(accountScope: loadedAccountScope)
        }
    }

    /// Session reset (sign-out): clear the in-memory thread. Disk is left
    /// intact — the per-account key isolates users; hard deletion is
    /// `AuthManager.clearAllUserData`.
    func endSession() {
        clearInMemoryState()
    }

    /// Empty all in-memory thread state without touching disk. Shared by the
    /// reload (before re-reading the new account) and the session-reset paths.
    private func clearInMemoryState() {
        invalidateReplyLeases(cancelActiveProviderWork: true)
        messages.removeAll()
        aiChipsCache.removeAll()
        starterChipsCache.removeAll()
        pendingInjectedCoachID = nil
        isAwaitingReply = false
        lastFailure = nil
        loadedAccountScope = nil
    }

    /// Called synchronously at deletion initiation, before any remote await.
    /// It revokes every lease, best-effort cancels active provider work, drops
    /// transient pending coach rows, and writes only completed/non-system rows
    /// back to the explicitly named originating account. A failed remote delete
    /// can therefore recover the completed conversation without ever creating a
    /// `askNoum.thread.guest` destination.
    func suspendProviderWorkForAccountTransition(accountID: String) {
        guard let accountScope = Self.normalizedAccountScope(accountID) else {
            return
        }
        invalidateReplyLeases(
            cancelActiveProviderWork: true,
            matchingAccountScope: accountScope
        )
        guard loadedAccountScope == accountScope else { return }
        messages.removeAll { $0.isPending }
        pendingInjectedCoachID = nil
        isAwaitingReply = false
        lastFailure = nil
        persist(accountScope: accountScope)
    }

    func suspendProviderWorkForDeletion(accountID: String) {
        suspendProviderWorkForAccountTransition(accountID: accountID)
    }

    /// Cache an AI-generated chip set for a specific coach reply. Called
    /// by AskNoumView once the chip-generation request returns successfully.
    /// Idempotent — overwriting is a no-op if the chips match; we don't
    /// distinguish because the source of truth is the cached value, not
    /// the request that produced it.
    func setAIChips(_ chips: [String], for coachID: UUID) {
        aiChipsCache[coachID] = normalizedVisibleChips(chips)
    }

    @discardableResult
    func setAIChips(
        _ chips: [String],
        for coachID: UUID,
        expected admission: AskNoumSendAdmission
    ) -> Bool {
        guard sendAdmissionIsCurrent(admission),
              messages.contains(where: {
                  $0.id == coachID && $0.role == .coach && !$0.isPending
              }) else {
            return false
        }
        aiChipsCache[coachID] = normalizedVisibleChips(chips)
        return true
    }

    /// Read cached chips for a coach reply, if any. Returns nil when the
    /// reply has no cached entry yet — the view shows no chip row in the
    /// meantime. Deterministic chip logic remains request eligibility only.
    func aiChips(for coachID: UUID) -> [String]? {
        aiChipsCache[coachID]
    }

    /// Cache an AI-generated empty-state starter set keyed by the input
    /// signature that produced it. Called by AskNoumView once the starter
    /// generation request returns successfully.
    func setStarterChips(_ chips: [String], for signature: String) {
        starterChipsCache[signature] = normalizedVisibleChips(chips)
    }

    @discardableResult
    func setStarterChips(
        _ chips: [String],
        for signature: String,
        expected admission: AskNoumSendAdmission
    ) -> Bool {
        guard sendAdmissionIsCurrent(admission) else { return false }
        starterChipsCache[signature] = normalizedVisibleChips(chips)
        return true
    }

    /// Read cached starter prompts for a given input signature, if any.
    /// Returns nil when nothing has hydrated for this signature yet — the
    /// view shows no suggested ask in the meantime, and the request fires
    /// once per new signature.
    func starterChips(for signature: String) -> [String]? {
        starterChipsCache[signature]
    }

    private func normalizedVisibleChips(_ chips: [String]) -> [String] {
        var seen: Set<String> = []
        return chips.compactMap { raw in
            let normalized = CoachDisplayCopy.normalized(raw)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }

    /// Cross-surface seed-message inject. Used by post-session bridges
    /// (Summary's "Talk to your coach about this rep") to drop a
    /// session-anchored opener into the thread before AskNoumView
    /// mounts. The returned coachID is the row AskNoumView should
    /// hydrate via the model.
    ///
    /// Idempotency: if the most-recent non-system user turn carries
    /// the same text AND a coach reply for it is either pending or
    /// already in flight, this is a no-op (returns the existing
    /// coachID if pending, nil otherwise). Stops a double-tap on the
    /// bridge from queuing two identical seed prompts back-to-back.
    @discardableResult
    func injectUserTurn(_ text: String) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let admission = sendAdmission() else {
            return nil
        }

        // Idempotency guard — if the last user turn IS this opener AND
        // its coach reply is still pending, return that same coachID
        // instead of queuing a duplicate. A double-tap on the Summary
        // bridge mid-reply must not produce a second seed pair.
        //
        // Once the prior reply has hydrated, re-inject is a legitimate
        // fresh ask (the user is asking again on a later visit) and
        // falls through to append a new pair.
        if let lastUserIdx = messages.lastIndex(where: { $0.role == .user }),
           messages[lastUserIdx].text == trimmed {
            let after = messages.suffix(from: messages.index(after: lastUserIdx))
            if let coachRow = after.first(where: { $0.role == .coach }),
               coachRow.isPending {
                return coachRow.id
            }
            // Hydrated coach row (or none yet for some odd state) →
            // fall through, append a fresh pair.
        }

        guard let dispatch = appendUserTurn(trimmed, expected: admission) else {
            return nil
        }
        pendingInjectedCoachID = dispatch.coachID
        return dispatch.coachID
    }

    /// One-shot consumer. AskNoumView calls this on appear; if the
    /// returned ID is non-nil it runs the model for that coachID and
    /// the store atomically clears the pending signal so a second
    /// AskNoumView mount (same nav stack lifecycle) doesn't fire a
    /// duplicate reply task.
    func consumePendingInjectedCoachID() -> UUID? {
        let id = pendingInjectedCoachID
        pendingInjectedCoachID = nil
        return id
    }

    /// Append a coach-authored message directly into the thread without
    /// a corresponding user turn. Used by surfaces that synthesise a
    /// coach artifact server-side or deterministically — e.g. the M20
    /// Forward Plan, where `ForwardPlanService.generate(...)` produces
    /// a four-week program that's rendered as a coach turn so the user
    /// can scroll back to it like any other reply. The returned ID lets
    /// callers reference the row (e.g. for cross-surface deep-linking
    /// or chip caching) once they need to.
    ///
    /// Empty text is rejected (defensive — a placeholder coach turn
    /// would render as an empty bubble). Non-empty text lands as a
    /// hydrated, non-pending `.coach` row immediately.
    @discardableResult
    func injectCoachTurn(_ text: String) -> UUID? {
        appendInjectedCoachTurn(text)
    }

    /// Async-derived artifacts use this explicit overload. The expected
    /// account must be both the current identity and the thread actually loaded
    /// in memory; there is intentionally no optional/defaulted safety token.
    @discardableResult
    func injectCoachTurn(
        _ text: String,
        expectedAccountScope: String
    ) -> UUID? {
        let expected = Self.normalizedAccountScope(expectedAccountScope)
        guard let expected,
              expected == currentAccountScope,
              expected == loadedAccountScope,
              providerWorkAllowedProvider(expected) else {
            return nil
        }
        return appendInjectedCoachTurn(text)
    }

    private func appendInjectedCoachTurn(_ text: String) -> UUID? {
        let trimmed = CoachReplyTextSanitizer.coachReplyText(from: text)
        guard !trimmed.isEmpty else { return nil }
        let msg = CoachMessage(role: .coach, text: trimmed, isPending: false)
        messages.append(msg)
        trimAndPersist()
        return msg.id
    }

    /// All non-system messages, oldest-first, suitable for the model
    /// replay. System notices are dropped — they're UI-only.
    var replayForModel: [CoachMessage] {
        messages.filter { $0.role != .systemNotice && !$0.isPending }
    }

    /// True once at least one coach reply has hydrated in this thread.
    /// Used by the header to flip the pending-reply subtitle from
    /// "Reading your context…" (cold start) to "Thinking…" (every
    /// subsequent reply) so the header never claims to still be reading
    /// context after the model has already responded.
    var hasLandedCoachReply: Bool {
        messages.contains { $0.role == .coach && !$0.isPending && !$0.text.isEmpty }
    }

    // MARK: - Persistence

    private func storageKey(accountScope: String) -> String {
        "\(Self.storagePrefix).\(accountScope)"
    }

    private func loadFromDisk(accountScope: String) {
        guard loadedAccountScope == accountScope,
              let data = defaults.data(forKey: storageKey(accountScope: accountScope)),
              let decoded = try? JSONDecoder().decode([CoachMessage].self, from: data) else {
            return
        }
        // Defensive: don't restore a row that was pending when the app
        // exited — the model never returned, so this is effectively
        // dead. Drop it.
        var didCleanLegacyCoachNotes = decoded.contains { $0.role == .systemNotice }
        messages = decoded.filter { !$0.isPending && $0.role != .systemNotice }.compactMap { message in
            guard message.role == .coach else {
                return message
            }
            let normalized = CoachReplyTextSanitizer.coachReplyText(from: message.text)
            if normalized != message.text.trimmingCharacters(in: .whitespacesAndNewlines),
               !normalized.isEmpty {
                didCleanLegacyCoachNotes = true
                return CoachMessage(
                    id: message.id,
                    role: .coach,
                    text: normalized,
                    createdAt: message.createdAt,
                    isPending: false,
                    isOffline: message.isOffline,
                    metadata: message.metadata
                )
            }
            guard Self.shouldCleanLegacyCoachMessage(message.text) else {
                return message
            }
            didCleanLegacyCoachNotes = true
            return nil
        }
        if didCleanLegacyCoachNotes {
            persist(accountScope: accountScope)
        }
    }

    nonisolated static func shouldCleanLegacyCoachMessage(_ text: String) -> Bool {
        guard let issue = AICoachChatService.replyQualityIssue(in: text) else { return false }
        switch issue {
        case .roboticPhrase, .bareClarification, .defensiveProductLanguage, .menuInsteadOfDecision, .unrequestedNamedTechnique, .scaffoldLabel, .unverifiedQuotedUserSpeech:
            return true
        case .tooLong, .missedTrustRepair, .missingPrescribedAction,
                .missingInsightBridge, .unanchoredCoaching, .overclaimsEvidence,
                .unengagedUserSpeechClaim, .missingVerifiedExampleQuote,
                .ignoredCoachingExpertise,
                .visionGate, .semanticJudgement, .repeatedProofTest,
                .nonCoachingPrescription:
            // These need per-turn source / RAG / vision / recent-reply context;
            // this legacy sweep has none of that, so it never rewrites history
            // on that basis.
            return false
        }
    }

    private func trimAndPersist(accountScope: String? = nil) {
        if messages.count > Self.maxStoredMessages {
            messages.removeFirst(messages.count - Self.maxStoredMessages)
        }
        if let accountScope {
            persist(accountScope: accountScope)
        } else {
            persist()
        }
    }

    private func persist() {
        guard let loadedAccountScope else { return }
        persist(accountScope: loadedAccountScope)
    }

    private func persist(accountScope: String) {
        guard Self.normalizedAccountScope(accountScope) == accountScope,
              loadedAccountScope == accountScope else {
            return
        }
        // Don't persist the pending placeholder rows — they're
        // transient. If the user backgrounds the app mid-reply the
        // pending row will reappear from memory but won't be written
        // to disk, so a relaunch starts clean.
        let persistable = messages.filter { !$0.isPending && $0.role != .systemNotice }
        guard let data = try? JSONEncoder().encode(persistable) else { return }
        defaults.set(data, forKey: storageKey(accountScope: accountScope))
    }

    // MARK: - Account ID

    /// Default account-ID resolver. Mirrors the convention every other
    /// per-account store uses (`AuthManager` → keychain `NoumAccountID`).
    /// Returns nil when signed-out. Production guest sessions have a durable,
    /// nonempty local account ID before account-scoped stores hydrate; there is
    /// deliberately no shared literal guest persistence bucket.
    private static func defaultAccountIDProvider() -> String? {
        #if canImport(Security)
        return KeychainHelper.load(key: "NoumAccountID")
        #else
        return nil
        #endif
    }

    private static func normalizedAccountScope(_ accountID: String?) -> String? {
        let trimmed = accountID?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var currentAccountScope: String? {
        Self.normalizedAccountScope(accountIDProvider())
    }

    private func invalidateReplyLeases(
        cancelActiveProviderWork: Bool,
        matchingAccountScope: String? = nil
    ) {
        threadStoreGeneration &+= 1
        guard cancelActiveProviderWork else { return }
        let workToCancel = activeProviderWorkByCoachID.values.filter { work in
            matchingAccountScope == nil
                || work.lease.accountScope == matchingAccountScope
        }
        let auxiliaryWorkToCancel = activeAuxiliaryProviderWorkByID.values.filter { work in
            matchingAccountScope == nil
                || work.lease.accountScope == matchingAccountScope
        }
        for work in workToCancel {
            activeProviderWorkByCoachID.removeValue(forKey: work.lease.coachID)
        }
        for work in auxiliaryWorkToCancel {
            activeAuxiliaryProviderWorkByID.removeValue(forKey: work.lease.workID)
        }
        for work in workToCancel {
            work.cancel()
        }
        for work in auxiliaryWorkToCancel {
            work.cancel()
        }
    }
}

#endif
