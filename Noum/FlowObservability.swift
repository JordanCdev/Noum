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
    static let shared = FlowEventLog()
    nonisolated static let defaultStorageKey = "flowEvents.recent"
    nonisolated static let defaultMaxRecords = 200

    @Published private(set) var events: [FlowEvent] = []

    private let defaults: UserDefaults
    private let storageKey: String
    private let maxRecords: Int

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = FlowEventLog.defaultStorageKey,
        maxRecords: Int = FlowEventLog.defaultMaxRecords
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxRecords = max(1, maxRecords)
        load()
    }

    func log(_ event: FlowEvent) {
        events.insert(event, at: 0)
        events = Array(events.prefix(maxRecords))
        persist()
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

    func reset() {
        events = []
        defaults.removeObject(forKey: storageKey)
    }

    func replaceForDebug(_ seeded: [FlowEvent]) {
        events = Array(seeded.sorted { $0.createdAt > $1.createdAt }.prefix(maxRecords))
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
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FlowEvent].self, from: data) else {
            events = []
            return
        }
        events = Array(decoded.sorted { $0.createdAt > $1.createdAt }.prefix(maxRecords))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: storageKey)
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
