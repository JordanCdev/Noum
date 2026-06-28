import Foundation

// MARK: - Coach judgement flags + turn depth

/// Feature flags for the low-latency judgement layer.
///
/// Reads from environment first, then `AIConfig.plist`, so the judgement layer
/// can be rolled forward or back without adding another app state owner.
enum CoachBrainFlags {
    static let judgementPassEnabledKey = "NOUM_COACH_JUDGEMENT_PASS_ENABLED"
    static let realtimeCoachModeEnabledKey = "NOUM_REALTIME_COACH_MODE_ENABLED"
    static let semanticGateDryRunEnabledKey = "NOUM_COACH_SEMANTIC_GATE_DRY_RUN"
    static let providerStreamingEnabledKey = "NOUM_COACH_PROVIDER_STREAMING_ENABLED"

    /// Master switch for the deterministic assessment pass. Default on; a
    /// config value of false keeps the chat pipeline on its pre-judgement
    /// grounded-read path.
    static var judgementPassEnabled: Bool {
        boolFlag(
            key: judgementPassEnabledKey,
            defaultValue: true
        )
    }

    /// Enables the real-time posture for the shared coach brain. When a live
    /// call asks a deep question, the app can render an immediate local read
    /// while the model verbalises the fuller answer.
    static var realtimeCoachModeEnabled: Bool {
        boolFlag(
            key: realtimeCoachModeEnabledKey,
            defaultValue: true
        )
    }

    /// Calibration switch for the semantic judgement gate. Default off: a
    /// semantic miss still repairs/fails the draft. When enabled, the service
    /// records the would-have-failed issue but lets the provider reply through,
    /// so live traffic can calibrate thresholds without user-visible holdbacks.
    static var semanticGateDryRunEnabled: Bool {
        boolFlag(
            key: semanticGateDryRunEnabledKey,
            defaultValue: false
        )
    }

    /// Uses provider-native streaming transports for the final LLM
    /// verbalisation where available. The UI still shows only the local typed
    /// coach read until the completed provider draft passes the existing
    /// quality gates.
    static var providerStreamingEnabled: Bool {
        boolFlag(
            key: providerStreamingEnabledKey,
            defaultValue: true
        )
    }

    static func boolFlag(
        key: String,
        defaultValue: Bool,
        env: [String: String] = ProcessInfo.processInfo.environment,
        configValue: (String) -> String? = { key in
            LocalConfigLoader.value(forKey: key, plistNamed: "AIConfig")
        }
    ) -> Bool {
        if let envValue = parsedBool(env[key]) {
            return envValue
        }
        if let configValue = parsedBool(configValue(key)) {
            return configValue
        }
        return defaultValue
    }

    static func parsedBool(_ raw: String?) -> Bool? {
        guard let value = raw?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !value.isEmpty else {
            return nil
        }

        switch value {
        case "1", "true", "yes", "y", "on", "enabled":
            return true
        case "0", "false", "no", "n", "off", "disabled":
            return false
        default:
            return nil
        }
    }
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
