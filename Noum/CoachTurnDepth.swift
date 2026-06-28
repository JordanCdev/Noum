import Foundation

// MARK: - Coach judgement flags + turn depth

/// Feature flags for the low-latency judgement layer.
///
/// Kept as plain static flags to match the existing `KnowledgeBrainFlags`
/// pattern: fast to read, easy for tests to flip, and no new settings owner.
enum CoachBrainFlags {
    /// Master switch for the deterministic assessment pass. Default on; a
    /// future remote/config surface can thread into this without changing call
    /// sites.
    nonisolated(unsafe) static var judgementPassEnabled = true

    /// Enables the real-time posture for the shared coach brain. When a live
    /// call asks a deep question, the app can render an immediate local read
    /// while the model verbalises the fuller answer.
    nonisolated(unsafe) static var realtimeCoachModeEnabled = true
}

/// How much coaching work the current user turn is asking for.
enum CoachTurnDepth: String, Codable, Equatable, CaseIterable {
    /// Tactical next move. Short, fast, one action.
    case quickMove
    /// Evidence-backed read of the latest rep or pattern.
    case groundedRead
    /// Meta judgement: distance to goal, overall readiness, honest calibration.
    case deepAssessment
    /// The user is pushing back on the coach's usefulness or accuracy.
    case trustRepair
}

/// Surface asking for the reply. The brain is shared, but text and live-call
/// budgets differ.
enum CoachReplySurface: String, Codable, Equatable {
    case text
    case live
}

/// High-level routing intent for the provider chain.
enum CoachProviderTier: String, Codable, Equatable {
    case geminiFast
    case claudeReasoning
}
