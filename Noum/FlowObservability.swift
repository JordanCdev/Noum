import Foundation

// MARK: - Flow observability
//
// The flow-level companion to `AICallDiagnostics` (which records only AI network
// calls). A `FlowEvent` captures a stage transition inside a user-facing flow —
// a practice rep, a chat turn, an achievement evaluation — grouped by a
// `correlationId` so the whole sequence can be reconstructed after the fact.
//
// This exists because incidents like "an accidental 0s rep showed a confident
// 1/10 + a full read" or "a rich chat draft was silently replaced by a shorter
// final" were previously un-reconstructable: the only telemetry was a 30-record
// global ring buffer of AI calls with no correlation key.
//
// Privacy posture is inherited from `AICallDiagnosticRecord`: reasons + bounded
// numerics ONLY. A `FlowEvent` must NEVER carry transcript text or a user's
// words — only decisions, reasons, and bounded counts.

enum FlowKind: String, Codable, CaseIterable {
    case practiceRep
    case chatTurn
    case achievementEval
    case other

    var title: String {
        switch self {
        case .practiceRep: return "Practice rep"
        case .chatTurn: return "Chat turn"
        case .achievementEval: return "Achievement eval"
        case .other: return "Other"
        }
    }
}

/// Stable, bounded event vocabulary for the transformation KPIs. Keeping these
/// names beside the report prevents call sites and denominators drifting apart.
enum TransformationKPIEventStage {
    static let activationExperimentAssigned = "activation.experimentAssigned"
    static let activationExperimentExposed = "activation.experimentExposed"
    static let reviewExperimentAssigned = "review.experimentAssigned"
    static let reviewExperimentExposed = "review.experimentExposed"
    static let reviewSurfaceOpened = "review.surfaceOpened"
    static let structuredStarted = "activation.structuredStarted"
    static let structuredValueDelivered = "activation.structuredValueDelivered"
    static let liveUpgradeTapped = "activation.liveUpgradeTapped"
    static let profileSetupTapped = "activation.profileSetupTapped"
    static let prescriptionShown = "prescription.shown"
    static let prescriptionAccepted = "prescription.accepted"
    static let transcriptLadderShown = "transcriptLadder.shown"
    static let transcriptRetryCompleted = "transcriptRetry.completed"
    static let transcriptTargetCompared = "transcriptRetry.targetCompared"
    static let transcriptInterventionUpdated = "transcriptRetry.interventionUpdated"
    static let cloudTranscriptionResolvedCloud = "transcription.cloudResolvedCloud"
    static let cloudTranscriptionResolvedLocal = "transcription.cloudResolvedLocal"
    static let localTranscriptionResolvedLocal = "transcription.localResolvedLocal"
}

/// The rep → summary → ask → redo coaching journey.
///
/// The terminal halves already existed (`rep.saved`, `rep.aborted`,
/// `prescription.accepted`), but their denominators did not: there was no
/// "a rep began" and no "the summary was actually read". Without those two,
/// a drop-off between finishing a rep and acting on the coaching is
/// indistinguishable from a rep that was never started.
///
/// Same privacy posture as every other stage — reasons and bounded counts,
/// never prompt text, transcript, or coaching copy.
enum CoachingFunnelStage {
    static let repStarted = "rep.started"
    static let summaryViewed = "summary.viewed"
}

/// Stable, content-free stages for one Ask Noum request. Every stage uses the
/// pending coach row UUID as its correlation ID, including provider/server work
/// and the final store/UI commit. Keeping the vocabulary here prevents the
/// Debug trace viewer and tests from depending on ad-hoc strings.
enum CoachTraceStage {
    static let accepted = "coach.accepted"
    static let classified = "coach.classified"
    static let goalResolved = "coach.goalResolved"
    static let evidenceLoaded = "coach.evidenceLoaded"
    static let rubricSelected = "coach.rubricSelected"
    static let promptAssembled = "coach.promptAssembled"
    static let providerDeadlineArmed = "coach.providerDeadlineArmed"
    static let providerStarted = "coach.providerStarted"
    static let providerRetried = "coach.providerRetried"
    static let providerRefused = "coach.providerRefused"
    static let providerFinished = "coach.providerFinished"
    static let streamFirstVisible = "coach.streamFirstVisible"
    static let gatePassed = "coach.gatePassed"
    static let gateRepaired = "coach.gateRepaired"
    static let gateFallback = "coach.gateFallback"
    static let gateRejected = "coach.gateRejected"
    static let finalSanitized = "coach.finalSanitized"
    static let persisted = "coach.persisted"
    static let uiCommitted = "coach.uiCommitted"
    static let terminal = "coach.terminal"

    static let all: Set<String> = [
        accepted,
        classified,
        goalResolved,
        evidenceLoaded,
        rubricSelected,
        promptAssembled,
        providerDeadlineArmed,
        providerStarted,
        providerRetried,
        providerRefused,
        providerFinished,
        streamFirstVisible,
        gatePassed,
        gateRepaired,
        gateFallback,
        gateRejected,
        finalSanitized,
        persisted,
        uiCommitted,
        terminal,
    ]
}

/// The exhaustive user-visible outcome of a dispatched Ask Noum request.
/// Raw values are persisted in the content-free flow log and shown in Debug.
enum CoachTraceTerminalState: String, Codable, Equatable, CaseIterable {
    case accepted
    case repaired
    case safeFallback
    case retryableError
    case cancelled
}

struct CoachDebugTrace: Identifiable, Equatable {
    let correlationId: UUID
    let events: [FlowEvent]

    var id: UUID { correlationId }

    var terminalState: CoachTraceTerminalState? {
        events.reversed().first(where: { $0.stage == CoachTraceStage.terminal })
            .flatMap { CoachTraceTerminalState(rawValue: $0.reason) }
    }

    var terminalEventCount: Int {
        events.lazy.filter { $0.stage == CoachTraceStage.terminal }.count
    }

    /// A dispatched request may be in flight with no terminal event, but once
    /// terminal it must have exactly one known state. Surface violations in
    /// Debug instead of letting a duplicate or malformed terminal look healthy.
    var hasTerminalContractViolation: Bool {
        terminalEventCount > 1 || (terminalEventCount == 1 && terminalState == nil)
    }

    var terminalStatusLabel: String {
        if hasTerminalContractViolation { return "trace error" }
        return terminalState?.rawValue ?? "in flight"
    }

    var latencyMs: Int? {
        if let recorded = events.reversed().compactMap({ $0.numerics["latencyMs"] }).first,
           recorded >= 0 {
            return recorded
        }
        guard let first = events.first?.createdAt, let last = events.last?.createdAt else {
            return nil
        }
        return max(0, Int(last.timeIntervalSince(first) * 1_000))
    }

    func elapsedMs(for event: FlowEvent) -> Int? {
        guard let startedAt = events.first?.createdAt else { return nil }
        return max(0, Int(event.createdAt.timeIntervalSince(startedAt) * 1_000))
    }
}

/// A content-free, machine-readable packet for one Ask Noum request.
///
/// The packet deliberately contains only the bounded trace ledger and matching
/// AI transport diagnostics. It never includes the user turn, transcript,
/// assembled prompt, provider response, account identifier, or credentials.
/// Support can inspect or replay the terminal path locally without expanding
/// production retention of communication content.
struct CoachTraceSupportBundle: Codable, Equatable {
    static let currentSchemaVersion = "noum-coach-trace-support-v1"

    struct Build: Codable, Equatable {
        let appVersion: String
        let buildNumber: String
        let sourceGitCommit: String
    }

    struct Privacy: Codable, Equatable {
        let contentFree: Bool
        let includesUserText: Bool
        let includesTranscript: Bool
        let includesPrompt: Bool
        let includesResponse: Bool
        let includesAccountIdentifier: Bool
        let includesCredentials: Bool
    }

    struct Trace: Codable, Equatable {
        let traceID: UUID
        let terminalState: String?
        let terminalStatus: String
        let terminalEventCount: Int
        let terminalContractViolation: Bool
        let latencyMs: Int?
        let events: [Event]
    }

    struct Event: Codable, Equatable {
        let createdAt: Date
        let elapsedMs: Int?
        let stage: String
        let outcome: String
        let reason: String
        let numerics: [String: Int]
    }

    struct ProviderDiagnostic: Codable, Equatable {
        let createdAt: Date
        let surface: String
        let provider: String
        let model: String?
        let outcome: String
        let statusCode: Int?
        let latencyMs: Int?
        let cacheHit: Bool
        let inputTokens: Int?
        let outputTokens: Int?
        let reason: String
    }

    struct Reproduction: Codable, Equatable {
        let mode: String
        let command: String
        let scope: String
        let semanticFixtureRequired: Bool
    }

    let schemaVersion: String
    let exportedAt: Date
    let build: Build
    let privacy: Privacy
    let trace: Trace
    let providerDiagnostics: [ProviderDiagnostic]
    let reproduction: Reproduction

    static func make(
        trace: CoachDebugTrace,
        diagnostics: [AICallDiagnosticRecord],
        appVersion: String,
        buildNumber: String,
        sourceGitCommit: String,
        exportedAt: Date = Date()
    ) -> CoachTraceSupportBundle {
        let safeEvents = trace.events
            .filter { $0.flow == .chatTurn && CoachTraceStage.all.contains($0.stage) }
            .map { event in
                Event(
                    createdAt: event.createdAt,
                    elapsedMs: trace.elapsedMs(for: event),
                    stage: event.stage,
                    outcome: event.outcome.rawValue,
                    reason: canonicalEventReason(event),
                    numerics: event.numerics
                )
            }
        let matchingDiagnostics = diagnostics
            .filter { $0.correlationID == trace.correlationId }
            .sorted { $0.createdAt < $1.createdAt }
            .map { record in
                ProviderDiagnostic(
                    createdAt: record.createdAt,
                    surface: record.surface,
                    provider: record.provider,
                    model: record.model,
                    outcome: record.outcome.rawValue,
                    statusCode: record.statusCode,
                    latencyMs: record.latencyMs,
                    cacheHit: record.cacheHit,
                    inputTokens: record.inputTokens,
                    outputTokens: record.outputTokens,
                    reason: canonicalProviderReason(record)
                )
            }

        return CoachTraceSupportBundle(
            schemaVersion: currentSchemaVersion,
            exportedAt: exportedAt,
            build: Build(
                appVersion: boundedMetadata(appVersion, fallback: "unknown"),
                buildNumber: boundedMetadata(buildNumber, fallback: "unknown"),
                sourceGitCommit: boundedMetadata(sourceGitCommit, fallback: "unbound")
            ),
            privacy: Privacy(
                contentFree: true,
                includesUserText: false,
                includesTranscript: false,
                includesPrompt: false,
                includesResponse: false,
                includesAccountIdentifier: false,
                includesCredentials: false
            ),
            trace: Trace(
                traceID: trace.correlationId,
                terminalState: trace.terminalState?.rawValue,
                terminalStatus: trace.terminalStatusLabel,
                terminalEventCount: trace.terminalEventCount,
                terminalContractViolation: trace.hasTerminalContractViolation,
                latencyMs: trace.latencyMs,
                events: safeEvents
            ),
            providerDiagnostics: matchingDiagnostics,
            reproduction: Reproduction(
                mode: "content-free-terminal-path-replay",
                command: "./tools/coach-arena/run.sh trace-replay <bundle.json>",
                scope: "Validates the recorded stage order, provider attempts, gate decisions, and terminal UI contract. Raw communication content is intentionally unavailable.",
                semanticFixtureRequired: true
            )
        )
    }

    func encodedJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self),
              let output = String(data: data, encoding: .utf8) else {
            return "{\"schemaVersion\":\"noum-coach-trace-support-error\"}"
        }
        return output
    }

    private static func boundedMetadata(
        _ value: String,
        fallback: String,
        maxLength: Int = 80
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(maxLength))
    }

    private static func canonicalEventReason(_ event: FlowEvent) -> String {
        "stage:\(event.stage)|outcome:\(event.outcome.rawValue)"
    }

    private static func canonicalProviderReason(_ record: AICallDiagnosticRecord) -> String {
        "provider-outcome:\(record.outcome.rawValue)"
    }
}

struct TranscriptPracticeDebugTrace: Identifiable, Equatable {
    let correlationId: UUID
    let events: [FlowEvent]

    var id: UUID { correlationId }

    var result: TranscriptRetryResult? {
        events.reversed()
            .first(where: { $0.stage == TransformationKPIEventStage.transcriptTargetCompared })
            .flatMap { TranscriptRetryResult(rawValue: $0.reason) }
    }

    var latencyMs: Int? {
        guard let first = events.first?.createdAt, let last = events.last?.createdAt else {
            return nil
        }
        return max(0, Int(last.timeIntervalSince(first) * 1_000))
    }
}

struct FlowEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let correlationId: UUID
    let flow: FlowKind
    /// Dotted stage name, e.g. "rep.aborted", "score.decided", "finalize.skipped",
    /// "chat.draftShown", "chat.finalShown".
    let stage: String
    let outcome: AICallDiagnosticOutcome
    /// Bounded reason (256 chars). Reasons only — never transcript text.
    let reason: String
    /// Bounded numeric facts (wordCount, durationMs, score, xp, unlocks, …).
    let numerics: [String: Int]

    static func make(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        correlationId: UUID,
        flow: FlowKind,
        stage: String,
        outcome: AICallDiagnosticOutcome = .success,
        reason: String = "",
        numerics: [String: Int] = [:]
    ) -> FlowEvent {
        FlowEvent(
            id: id,
            createdAt: createdAt,
            correlationId: correlationId,
            flow: flow,
            stage: bounded(stage, fallback: "unknown.stage", maxLength: 48),
            outcome: outcome,
            reason: String(reason.trimmingCharacters(in: .whitespacesAndNewlines).prefix(256)),
            // Cap the numerics dictionary so a bad call site can't bloat storage.
            numerics: Dictionary(numerics.sorted { $0.key < $1.key }.prefix(12).map { ($0.key, $0.value) },
                                 uniquingKeysWith: { a, _ in a })
        )
    }

    private static func bounded(_ value: String, fallback: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(maxLength))
    }

    var numericsSummary: String {
        numerics.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    }
}

@MainActor
final class FlowEventLog: ObservableObject {
    static let shared = FlowEventLog(accountScoped: true)
    nonisolated static let defaultStorageKey = "flowEvents.recent"
    nonisolated static let defaultMaxRecords = 500

    @Published private(set) var events: [FlowEvent] = []

    private let defaults: UserDefaults
    private let storageKey: String
    private let maxRecords: Int
    private let accountScoped: Bool

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = FlowEventLog.defaultStorageKey,
        maxRecords: Int = FlowEventLog.defaultMaxRecords,
        accountScoped: Bool = false
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxRecords = max(1, maxRecords)
        self.accountScoped = accountScoped
        load()
    }

    func log(_ event: FlowEvent) {
        events.insert(event, at: 0)
        events = trimmed(events)
        persist()
    }

    func logOnce(_ event: FlowEvent) {
        guard !events.contains(where: {
            $0.correlationId == event.correlationId && $0.stage == event.stage
        }) else { return }
        log(event)
    }

    /// Records one account-local active-day event and a durable starting point
    /// for time-to-first-rep. No device identifier or transcript is captured.
    func recordActiveDay(now: Date = Date(), calendar: Calendar = .current) {
        if !events.contains(where: { $0.stage == "activation.firstEligible" }) {
            log(FlowEvent.make(
                createdAt: now,
                correlationId: UUID(),
                flow: .other,
                stage: "activation.firstEligible",
                reason: "first account-local value opportunity"
            ))
        }
        guard !events.contains(where: {
            $0.stage == "retention.appActive" && calendar.isDate($0.createdAt, inSameDayAs: now)
        }) else { return }
        log(FlowEvent.make(
            createdAt: now,
            correlationId: UUID(),
            flow: .other,
            stage: "retention.appActive",
            reason: "foreground active day"
        ))
    }

    /// Freezes the first valid externally configured assignment for this
    /// account. Later Remote Config changes cannot replace it because the
    /// account-local event ledger is the assignment source of truth after the
    /// first write.
    @discardableResult
    func recordActivationExperimentAssignment(
        _ proposed: ActivationExperimentAssignment
    ) -> ActivationExperimentAssignment {
        if let existing = ActivationExperimentContract.persistedAssignment(in: events) {
            return existing
        }
        log(FlowEvent.make(
            createdAt: proposed.assignedAt,
            correlationId: proposed.correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.activationExperimentAssigned,
            reason: "externally configured activation assignment",
            numerics: [
                "experimentVersion": proposed.version,
                "variant": proposed.variant.rawValue,
            ]
        ))
        return proposed
    }

    /// Records actual route exposure separately from assignment. A mismatched
    /// route is ignored so a later setup screen cannot be misread as exposure
    /// to the full-onboarding control variant.
    func recordActivationExperimentExposure(
        assignment: ActivationExperimentAssignment,
        route: FirstRunOnboardingGate.RootRoute,
        context: ActivationExperimentExposureContext,
        now: Date = Date()
    ) {
        guard route == assignment.variant.rootRoute else { return }
        var numerics = context.numerics
        numerics["experimentVersion"] = assignment.version
        numerics["variant"] = assignment.variant.rawValue
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: assignment.correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.activationExperimentExposed,
            reason: "assigned first-run route appeared",
            numerics: numerics
        ))
    }

    /// Freezes the first exact-token Review assignment for this account. The
    /// flow ledger remains the only durable owner, so account export, deletion,
    /// and switching keep the same behavior as the rest of the diagnostics.
    @discardableResult
    func recordReviewExperimentAssignment(
        _ proposed: ReviewExperimentAssignment
    ) -> ReviewExperimentAssignment {
        if let existing = ReviewExperimentContract.persistedAssignment(in: events) {
            return existing
        }
        log(FlowEvent.make(
            createdAt: proposed.assignedAt,
            correlationId: proposed.correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.reviewExperimentAssigned,
            reason: "externally configured review assignment",
            numerics: [
                "experimentVersion": proposed.version,
                "variant": proposed.variant.rawValue,
            ]
        ))
        return proposed
    }

    /// Records only a presentation that actually mounted. Assignment alone is
    /// never treated as exposure, and an event with a mismatched presentation
    /// is ignored.
    func recordReviewExperimentExposure(
        assignment: ReviewExperimentAssignment,
        presentation: ReviewExperimentPresentation,
        context: ActivationExperimentExposureContext,
        now: Date = Date()
    ) {
        let expected: ReviewExperimentPresentation = assignment.variant == .genericReviewControl
            ? .genericReview
            : .outcomeLoop
        guard presentation == expected else { return }
        var numerics = context.numerics
        numerics["experimentVersion"] = assignment.version
        numerics["variant"] = assignment.variant.rawValue
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: assignment.correlationID,
            flow: .other,
            stage: TransformationKPIEventStage.reviewExperimentExposed,
            reason: "assigned review presentation appeared",
            numerics: numerics
        ))
    }

    /// Marks the first account-local visit to Review without storing which
    /// session, prompt, or transcript the user inspected.
    func recordReviewSurfaceOpened(now: Date = Date()) {
        guard !events.contains(where: {
            $0.stage == TransformationKPIEventStage.reviewSurfaceOpened
        }) else { return }
        log(FlowEvent.make(
            createdAt: now,
            correlationId: UUID(),
            flow: .other,
            stage: TransformationKPIEventStage.reviewSurfaceOpened,
            reason: "review surface opened"
        ))
    }

    /// Opens the funnel for one rep. The caller passes the same correlation ID
    /// it will later use for `rep.saved` / `rep.aborted`, so a started-but-never
    /// -finished rep is visible as a gap rather than as silence. Mode is a
    /// bounded label, never the prompt the user was answering.
    func recordRepStarted(correlationId: UUID, mode: String, now: Date = Date()) {
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .practiceRep,
            stage: CoachingFunnelStage.repStarted,
            reason: "rep started: \(mode)"
        ))
    }

    /// Records that the summary was actually rendered for a finished rep —
    /// the denominator every post-rep coaching action is measured against.
    /// Paired to the rep's correlation ID so "finished a rep but never read
    /// the coaching" is distinguishable from "read it and did nothing".
    func recordSummaryViewed(correlationId: UUID, now: Date = Date()) {
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .practiceRep,
            stage: CoachingFunnelStage.summaryViewed,
            reason: "summary viewed"
        ))
    }

    /// Records the user-visible prescription denominator. The caller supplies
    /// one durable correlation ID for the exposure so a later tap can be paired
    /// without storing the recommendation text or fingerprint in telemetry.
    func recordPrescriptionShown(correlationId: UUID, now: Date = Date()) {
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .other,
            stage: TransformationKPIEventStage.prescriptionShown,
            reason: "prescription shown"
        ))
    }

    func recordPrescriptionAccepted(correlationId: UUID, now: Date = Date()) {
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .other,
            stage: TransformationKPIEventStage.prescriptionAccepted,
            reason: "prescription tapped"
        ))
    }

    func recordTranscriptLadderShown(
        correlationId: UUID,
        lever: TranscriptPracticeLever,
        now: Date = Date()
    ) {
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .other,
            stage: TransformationKPIEventStage.transcriptLadderShown,
            reason: lever.rawValue
        ))
    }

    func recordTranscriptRetryCompleted(correlationId: UUID, now: Date = Date()) {
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .other,
            stage: TransformationKPIEventStage.transcriptRetryCompleted,
            reason: "accepted retry persisted"
        ))
    }

    func recordTranscriptTargetCompared(
        correlationId: UUID,
        result: TranscriptRetryResult,
        comparison: TranscriptRetryComparison?,
        now: Date = Date()
    ) {
        var numerics: [String: Int] = [:]
        if let comparison {
            numerics = [
                "sourceSignal": comparison.sourceSignal,
                "retrySignal": comparison.retrySignal,
                "meaningOverlapPercent": comparison.meaningOverlapPercent,
            ]
        }
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .other,
            stage: TransformationKPIEventStage.transcriptTargetCompared,
            outcome: result == .regressed ? .failure : .success,
            reason: result.rawValue,
            numerics: numerics
        ))
    }

    func recordTranscriptInterventionUpdated(
        correlationId: UUID,
        result: TranscriptRetryResult,
        now: Date = Date()
    ) {
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .other,
            stage: TransformationKPIEventStage.transcriptInterventionUpdated,
            reason: result.rawValue
        ))
    }

    /// Records the requested route separately from the provider that actually
    /// started. A deliberate local-only session is observable but never enters
    /// the cloud-fallback denominator.
    func recordTranscriptionRoute(
        correlationId: UUID,
        requestedCloud: Bool,
        resolvedProviderIdentifier: String,
        now: Date = Date()
    ) {
        let resolvedLocally = resolvedProviderIdentifier == TranscriptionProviderID.local.rawValue
        let stage: String
        if requestedCloud {
            stage = resolvedLocally
                ? TransformationKPIEventStage.cloudTranscriptionResolvedLocal
                : TransformationKPIEventStage.cloudTranscriptionResolvedCloud
        } else {
            stage = TransformationKPIEventStage.localTranscriptionResolvedLocal
        }
        logOnce(FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: .practiceRep,
            stage: stage,
            reason: "transcription route resolved"
        ))
    }

    func reloadForCurrentAccount() {
        load()
    }

    func endSession() {
        events = []
    }

    /// Events for one flow, in chronological (oldest-first) order.
    func events(correlationId: UUID) -> [FlowEvent] {
        events.filter { $0.correlationId == correlationId }.sorted { $0.createdAt < $1.createdAt }
    }

    /// The most recent flows, each as an ordered group. Newest flow first.
    func recentFlows(limit: Int = 20) -> [(correlationId: UUID, events: [FlowEvent])] {
        var seen: [UUID] = []
        for event in events where !seen.contains(event.correlationId) {
            seen.append(event.correlationId)
            if seen.count >= limit { break }
        }
        return seen.map { (correlationId: $0, events: events(correlationId: $0)) }
    }

    /// Content-free request traces for the Debug viewer. A trace is returned
    /// only when at least one Ask Noum stage exists, so unrelated rep funnels do
    /// not crowd out request inspection.
    func recentCoachTraces(limit: Int = 10) -> [CoachDebugTrace] {
        recentFlows(limit: max(limit * 4, limit))
            .filter { group in group.events.contains { $0.flow == .chatTurn } }
            .prefix(limit)
            .map { CoachDebugTrace(correlationId: $0.correlationId, events: $0.events) }
    }

    func recentTranscriptPracticeTraces(limit: Int = 10) -> [TranscriptPracticeDebugTrace] {
        recentFlows(limit: max(limit * 6, limit))
            .filter { group in
                group.events.contains {
                    $0.stage == TransformationKPIEventStage.transcriptLadderShown
                }
            }
            .prefix(limit)
            .map {
                TranscriptPracticeDebugTrace(
                    correlationId: $0.correlationId,
                    events: $0.events
                )
            }
    }

    func reset() {
        events = []
        defaults.removeObject(forKey: effectiveStorageKey)
    }

    func replaceForDebug(_ seeded: [FlowEvent]) {
        events = trimmed(seeded.sorted { $0.createdAt > $1.createdAt })
        persist()
    }

    /// Pipe-delimited export. When `correlationId` is nil, groups by flow with a
    /// blank line between flows (newest first).
    func export(correlationId: UUID? = nil) -> String {
        if let correlationId {
            return exportGroup(events(correlationId: correlationId))
        }
        let flows = recentFlows()
        guard !flows.isEmpty else { return "No flow events recorded." }
        return flows.map { exportGroup($0.events) }.joined(separator: "\n\n")
    }

    /// Structured support export for one Ask Noum trace. Matching transport
    /// records are joined by the same root trace ID; unrelated diagnostics are
    /// excluded. The resulting JSON is suitable for the local `trace-replay`
    /// command and intentionally carries no communication content.
    func exportCoachSupportBundle(
        correlationId: UUID,
        diagnostics: [AICallDiagnosticRecord],
        appVersion: String,
        buildNumber: String,
        sourceGitCommit: String,
        exportedAt: Date = Date()
    ) -> String? {
        guard let trace = recentCoachTraces(limit: max(events.count, 1))
            .first(where: { $0.correlationId == correlationId }) else {
            return nil
        }
        return CoachTraceSupportBundle.make(
            trace: trace,
            diagnostics: diagnostics,
            appVersion: appVersion,
            buildNumber: buildNumber,
            sourceGitCommit: sourceGitCommit,
            exportedAt: exportedAt
        ).encodedJSON()
    }

    private func exportGroup(_ group: [FlowEvent]) -> String {
        guard let first = group.first else { return "" }
        let formatter = ISO8601DateFormatter()
        let header = "── \(first.flow.title) · \(first.correlationId.uuidString.prefix(8)) ──"
        let lines = group.map { event in
            [
                formatter.string(from: event.createdAt),
                event.stage,
                event.outcome.rawValue,
                event.numericsSummary,
                event.reason,
            ].filter { !$0.isEmpty }.joined(separator: " | ")
        }
        return ([header] + lines).joined(separator: "\n")
    }

    private func load() {
        guard let data = defaults.data(forKey: effectiveStorageKey),
              let decoded = try? JSONDecoder().decode([FlowEvent].self, from: data) else {
            events = []
            return
        }
        events = trimmed(decoded.sorted { $0.createdAt > $1.createdAt })
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: effectiveStorageKey)
    }

    private var effectiveStorageKey: String {
        guard accountScoped else { return storageKey }
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? "guest"
        return "\(storageKey).\(accountID)"
    }

    private func trimmed(_ source: [FlowEvent]) -> [FlowEvent] {
        let ordered = source.sorted { $0.createdAt > $1.createdAt }
        // These records anchor cohort denominators and must survive the bounded
        // diagnostics ring. Pin the earliest structured-value delivery rather
        // than the newest one so a duplicate emission can never move a user's
        // measured time-to-first-value forward.
        let assignment = ActivationExperimentContract.persistedAssignment(in: ordered)
        let exposure = assignment.flatMap { assignment in
            ordered
                .filter {
                    $0.stage == TransformationKPIEventStage.activationExperimentExposed
                        && $0.correlationId == assignment.correlationID
                        && $0.createdAt >= assignment.assignedAt
                        && $0.numerics["experimentVersion"] == assignment.version
                        && $0.numerics["variant"] == assignment.variant.rawValue
                }
                .min(by: { $0.createdAt < $1.createdAt })
        }
        let reviewAssignment = ReviewExperimentContract.persistedAssignment(in: ordered)
        let reviewExposure = reviewAssignment.flatMap { assignment in
            ordered
                .filter {
                    $0.stage == TransformationKPIEventStage.reviewExperimentExposed
                        && $0.correlationId == assignment.correlationID
                        && $0.createdAt >= assignment.assignedAt
                        && $0.numerics["experimentVersion"] == assignment.version
                        && $0.numerics["variant"] == assignment.variant.rawValue
                }
                .min(by: { $0.createdAt < $1.createdAt })
        }
        let pinned = Array([
            ordered.filter { $0.stage == "activation.firstEligible" }
                .min(by: { $0.createdAt < $1.createdAt }),
            assignment.flatMap { frozen in
                ordered.first(where: {
                    $0.stage == TransformationKPIEventStage.activationExperimentAssigned
                        && $0.correlationId == frozen.correlationID
                        && $0.createdAt == frozen.assignedAt
                })
            },
            exposure,
            reviewAssignment.flatMap { frozen in
                ordered.first(where: {
                    $0.stage == TransformationKPIEventStage.reviewExperimentAssigned
                        && $0.correlationId == frozen.correlationID
                        && $0.createdAt == frozen.assignedAt
                })
            },
            reviewExposure,
            ordered.filter { $0.stage == TransformationKPIEventStage.reviewSurfaceOpened }
                .min(by: { $0.createdAt < $1.createdAt }),
            ordered.filter { $0.stage == TransformationKPIEventStage.structuredValueDelivered }
                .min(by: { $0.createdAt < $1.createdAt }),
            ordered.first(where: { $0.stage.hasPrefix("transformation.helpfulness") }),
        ].compactMap { $0 }.prefix(maxRecords))
        let pinnedIDs = Set(pinned.map(\.id))
        let recentCapacity = max(0, maxRecords - pinned.count)
        let recent = ordered.filter { !pinnedIDs.contains($0.id) }.prefix(recentCapacity)
        return (Array(recent) + pinned).sorted { $0.createdAt > $1.createdAt }
    }
}

#if DEBUG
/// Deterministic, content-free trace used only by the rendered Developer Tools
/// regression. It exercises the same account-local stores as production after
/// account hydration, so the test cannot pass against a disconnected mock UI.
enum CoachTraceSupportUITestFixture {
    static let traceID = UUID(uuidString: "a11ce000-1234-4234-8234-123456789abc")!

    static func requested(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains("UI_TESTING_COACH_TRACE_SUPPORT")
    }

    @MainActor
    static func installIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        guard requested(arguments: arguments) else { return }
        let start = Date(timeIntervalSince1970: 1_782_000_000)
        let stages: [(String, AICallDiagnosticOutcome, String, [String: Int])] = [
            (CoachTraceStage.accepted, .success, "request accepted; app=2.4 build=208 source=ui-test", [:]),
            (CoachTraceStage.goalResolved, .success, "goal=authoritative provenance=explicit-choice", [:]),
            (CoachTraceStage.classified, .success, "intent=coaching response=personal depth=deepAssessment", ["historyRows": 9, "userCharacters": 3_000]),
            (CoachTraceStage.evidenceLoaded, .success, "memory=bounded-case selectedLever=structure evidence=session+proof+knowledge", ["eligibleSessions": 4, "hasMemory": 1, "knowledgeCards": 3]),
            (CoachTraceStage.rubricSelected, .success, "rubric=authoritative active=1", ["dimensions": 3]),
            (CoachTraceStage.promptAssembled, .success, "redacted prompt modules assembled", ["characters": 8_240, "modules": 7]),
            (CoachTraceStage.providerDeadlineArmed, .success, "provider deadline armed", ["deadlineMs": 75_000]),
            (CoachTraceStage.providerStarted, .success, "provider=Secure callable model=coach-v1", [:]),
            (CoachTraceStage.providerRefused, .failure, "provider=Secure callable model=coach-v1", [:]),
            (CoachTraceStage.gateFallback, .fallback, "provider unavailable; selected safe bounded fallback", [:]),
            (CoachTraceStage.finalSanitized, .success, "safe substituted output sanitized", ["replyWords": 42]),
            (CoachTraceStage.persisted, .fallback, "terminal request state persisted", ["latencyMs": 1_420]),
            (CoachTraceStage.uiCommitted, .fallback, "vetted reply committed to chat", [:]),
            (CoachTraceStage.terminal, .fallback, CoachTraceTerminalState.safeFallback.rawValue, ["latencyMs": 1_420]),
        ]
        let events = stages.enumerated().map { index, stage in
            FlowEvent.make(
                createdAt: start.addingTimeInterval(Double(index) / 10),
                correlationId: traceID,
                flow: .chatTurn,
                stage: stage.0,
                outcome: stage.1,
                reason: stage.2,
                numerics: stage.3
            )
        }
        FlowEventLog.shared.replaceForDebug(events)
        AICallDiagnosticsStore.shared.replaceForDebug([
            AICallDiagnosticRecord.make(
                createdAt: start.addingTimeInterval(0.75),
                surface: "Ask Noum chat",
                provider: "Secure callable",
                model: "coach-v1",
                outcome: .failure,
                reason: "Provider returned a retryable service response",
                statusCode: 503,
                latencyMs: 820,
                correlationID: traceID,
                inputTokens: 1_240,
                outputTokens: 0
            ),
        ])
    }
}
#endif

struct TransformationKPIReport: Equatable {
    /// Account-local assignment/exposure attribution. Outcomes remain separate
    /// report fields so assignment is never mistaken for delivered value.
    let activationExperimentAttribution: ActivationExperimentAttribution?
    /// Account-local Test B assignment, actual rendered exposure, and the
    /// first later persisted nonfixture rep. This is not a population result.
    let reviewExperimentAttribution: ReviewExperimentAttribution?
    /// A durable spoken practice session exists. Structured first value never
    /// satisfies this field, preserving its historical speech-evidence meaning.
    let firstRepCompleted: Bool
    let timeToFirstRepSeconds: TimeInterval?
    /// Either a durable spoken rep or the permissionless structured exercise
    /// delivered visible value, whichever happened first.
    let firstValueCompleted: Bool
    let timeToFirstValueSeconds: TimeInterval?
    /// Kept separate so diagnostics never conflate structured activation with
    /// durable speech evidence.
    let firstStructuredValueCompleted: Bool
    let sessionsPerActiveWeek: Double
    /// Unique eligible session-detail opens divided by eligible persisted
    /// sessions. Thin, foreign, and repeated legacy events fail closed.
    let reviewOpenRate: Double?
    let prescriptionAcceptanceRate: Double?
    let transcriptLadderAcceptanceRate: Double?
    let transcriptRetryComparisonCompletionRate: Double?
    let transcriptTargetImprovementRate: Double?
    let cloudToLocalFallbackRate: Double?
    let typedToLiveUpgradeRate: Double?
    /// Structured first-value receipts followed by an explicit tap toward
    /// spoken coaching, paired by content-free correlation ID. This is intent,
    /// not proof that a spoken rep completed.
    let structuredToSpokenUpgradeIntentRate: Double?
    /// Account-local completion truth: after structured value, did a real,
    /// non-fixture PracticeSession persist? Population conversion remains an
    /// external analysis over these per-account reads.
    let structuredToSpokenRepCompleted: Bool?
    let timeFromStructuredValueToSpokenRepSeconds: TimeInterval?
    let goalImprovementRate7Days: Double?
    let goalImprovementRate28Days: Double?
    let notificationOptInAfterValue: Bool?
    let retainedDay1: Bool?
    let retainedDay7: Bool?
    let retainedDay28: Bool?

    static func derive(
        events: [FlowEvent],
        sessions: [PracticeSession],
        outcomes: [RecommendationOutcome],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TransformationKPIReport {
        let orderedSessions = PracticeProgressEligibility.eligibleSessions(in: sessions)
            .sorted { $0.date < $1.date }
        let firstEligible = events.filter { $0.stage == "activation.firstEligible" }.map(\.createdAt).min()
        let firstRep = orderedSessions.first?.date
        let firstStructuredValue = events
            .filter { $0.stage == TransformationKPIEventStage.structuredValueDelivered }
            .map(\.createdAt)
            .min()
        let firstValue = [firstRep, firstStructuredValue].compactMap { $0 }.min()
        let timeToFirstRep = firstEligible.flatMap { start in
            firstRep.map { max(0, $0.timeIntervalSince(start)) }
        }
        let timeToFirstValue = firstEligible.flatMap { start in
            firstValue.map { max(0, $0.timeIntervalSince(start)) }
        }

        let activeDays = Set(events.filter { $0.stage == "retention.appActive" }.map {
            calendar.startOfDay(for: $0.createdAt)
        })
        let activeWeekStarts = Set(activeDays.compactMap {
            calendar.dateInterval(of: .weekOfYear, for: $0)?.start
        })
        let sessionsPerWeek = activeWeekStarts.isEmpty
            ? 0
            : Double(orderedSessions.count) / Double(activeWeekStarts.count)

        let eligibleSessionIDs = Set(orderedSessions.map(\.id))
        let reviewOpenSessionIDs = Set(events.lazy
            .filter {
                $0.stage == "review.sessionOpened"
                    && eligibleSessionIDs.contains($0.correlationId)
            }
            .map(\.correlationId))
        let reviewRate = orderedSessions.isEmpty
            ? nil
            : Double(reviewOpenSessionIDs.count) / Double(orderedSessions.count)
        let shownPrescriptionIDs = Set(events.lazy
            .filter { $0.stage == TransformationKPIEventStage.prescriptionShown }
            .map(\.correlationId))
        let acceptedPrescriptionIDs = Set(events.lazy
            .filter { $0.stage == TransformationKPIEventStage.prescriptionAccepted }
            .map(\.correlationId))
            .intersection(shownPrescriptionIDs)
        let acceptance = shownPrescriptionIDs.isEmpty
            ? nil
            : Double(acceptedPrescriptionIDs.count) / Double(shownPrescriptionIDs.count)
        let ladderIDs = Set(events.lazy
            .filter { $0.stage == TransformationKPIEventStage.transcriptLadderShown }
            .map(\.correlationId))
        let acceptedLadderIDs = acceptedPrescriptionIDs.intersection(ladderIDs)
        let comparedLadderIDs = Set(events.lazy
            .filter { $0.stage == TransformationKPIEventStage.transcriptTargetCompared }
            .map(\.correlationId))
            .intersection(acceptedLadderIDs)
        let improvedLadderIDs = Set(events.lazy
            .filter {
                $0.stage == TransformationKPIEventStage.transcriptTargetCompared
                    && $0.reason == TranscriptRetryResult.improved.rawValue
            }
            .map(\.correlationId))
            .intersection(comparedLadderIDs)
        let ladderAcceptance = ladderIDs.isEmpty
            ? nil
            : Double(acceptedLadderIDs.count) / Double(ladderIDs.count)
        let retryComparisonCompletion = acceptedLadderIDs.isEmpty
            ? nil
            : Double(comparedLadderIDs.count) / Double(acceptedLadderIDs.count)
        let targetImprovement = comparedLadderIDs.isEmpty
            ? nil
            : Double(improvedLadderIDs.count) / Double(comparedLadderIDs.count)
        let cloudRoutes = events.filter {
            $0.stage == TransformationKPIEventStage.cloudTranscriptionResolvedCloud
                || $0.stage == TransformationKPIEventStage.cloudTranscriptionResolvedLocal
        }
        let localFallbacks = cloudRoutes.filter {
            $0.stage == TransformationKPIEventStage.cloudTranscriptionResolvedLocal
        }.count
        let fallbackRate = cloudRoutes.isEmpty
            ? nil
            : Double(localFallbacks) / Double(cloudRoutes.count)
        let typedOpens = events.filter { $0.stage == "coach.typedOpened" }.count
        let liveUpgrades = events.filter { $0.stage == "coach.typedToLive" }.count
        let upgradeRate = typedOpens == 0 ? nil : min(1, Double(liveUpgrades) / Double(typedOpens))
        let structuredValueIDs = Set(events.lazy
            .filter { $0.stage == TransformationKPIEventStage.structuredValueDelivered }
            .map(\.correlationId))
        let structuredLiveIDs = Set(events.lazy
            .filter { $0.stage == TransformationKPIEventStage.liveUpgradeTapped }
            .map(\.correlationId))
            .intersection(structuredValueIDs)
        let structuredUpgradeRate = structuredValueIDs.isEmpty
            ? nil
            : Double(structuredLiveIDs.count) / Double(structuredValueIDs.count)
        let firstSpokenAfterStructuredValue = firstStructuredValue.flatMap { valueAt in
            orderedSessions.first(where: { $0.date >= valueAt })
        }
        let structuredToSpokenRepCompleted = firstStructuredValue.map { _ in
            firstSpokenAfterStructuredValue != nil
        }
        let timeFromStructuredValueToSpokenRep = firstStructuredValue.flatMap { valueAt in
            firstSpokenAfterStructuredValue.map {
                max(0, $0.date.timeIntervalSince(valueAt))
            }
        }

        func improvementRate(days: Int) -> Double? {
            guard let cutoff = calendar.date(byAdding: .day, value: -days, to: now) else { return nil }
            let reads = outcomes
                .filter {
                    $0.completedAt >= cutoff
                        && $0.hasComparableBaseline
                        && $0.isVerifiedFollowed
                        && $0.goal != nil
                }
                .compactMap(\.goalFollowUpResult)
                .filter { $0 != .needsMoreEvidence }
            guard !reads.isEmpty else { return nil }
            return Double(reads.filter { $0 == .earlyImprovement }.count) / Double(reads.count)
        }

        let notificationDecision = firstValue.flatMap { valueAt in
            events
                .filter {
                    ($0.stage == "notification.authorizationGranted"
                        || $0.stage == "notification.authorizationDeclined")
                        && $0.createdAt >= valueAt
                }
                .max { $0.createdAt < $1.createdAt }
        }

        func retained(day: Int) -> Bool? {
            guard let firstEligible,
                  let target = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: firstEligible)),
                  now >= target else { return nil }
            return activeDays.contains(target)
        }

        return TransformationKPIReport(
            activationExperimentAttribution: ActivationExperimentContract.attribution(in: events),
            reviewExperimentAttribution: ReviewExperimentContract.attribution(
                in: events,
                sessions: sessions
            ),
            firstRepCompleted: firstRep != nil,
            timeToFirstRepSeconds: timeToFirstRep,
            firstValueCompleted: firstValue != nil,
            timeToFirstValueSeconds: timeToFirstValue,
            firstStructuredValueCompleted: firstStructuredValue != nil,
            sessionsPerActiveWeek: sessionsPerWeek,
            reviewOpenRate: reviewRate,
            prescriptionAcceptanceRate: acceptance,
            transcriptLadderAcceptanceRate: ladderAcceptance,
            transcriptRetryComparisonCompletionRate: retryComparisonCompletion,
            transcriptTargetImprovementRate: targetImprovement,
            cloudToLocalFallbackRate: fallbackRate,
            typedToLiveUpgradeRate: upgradeRate,
            structuredToSpokenUpgradeIntentRate: structuredUpgradeRate,
            structuredToSpokenRepCompleted: structuredToSpokenRepCompleted,
            timeFromStructuredValueToSpokenRepSeconds: timeFromStructuredValueToSpokenRep,
            goalImprovementRate7Days: improvementRate(days: 7),
            goalImprovementRate28Days: improvementRate(days: 28),
            notificationOptInAfterValue: notificationDecision.map { $0.stage == "notification.authorizationGranted" },
            retainedDay1: retained(day: 1),
            retainedDay7: retained(day: 7),
            retainedDay28: retained(day: 28)
        )
    }
}

enum TransformationQuestionEligibility {
    static func shouldShow(sessionCount: Int, events: [FlowEvent]) -> Bool {
        sessionCount >= 3 && !events.contains {
            $0.stage.hasPrefix("transformation.helpfulness")
        }
    }
}

/// Nonisolated funnel so any call site (including background actors) can emit a
/// flow event without hopping to the main actor first. Mirrors `AICallDiagnostics`.
enum FlowLog {
    nonisolated static func log(
        correlationId: UUID,
        flow: FlowKind,
        stage: String,
        outcome: AICallDiagnosticOutcome = .success,
        reason: String = "",
        numerics: [String: Int] = [:],
        now: Date = Date()
    ) {
        let event = FlowEvent.make(
            createdAt: now,
            correlationId: correlationId,
            flow: flow,
            stage: stage,
            outcome: outcome,
            reason: reason,
            numerics: numerics
        )
        Task { @MainActor in
            FlowEventLog.shared.log(event)
        }
    }
}
