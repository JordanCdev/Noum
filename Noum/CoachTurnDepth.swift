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
    static let reliabilityGateEnabledKey = "NOUM_COACH_RELIABILITY_GATE_ENABLED"
    static let streamRawPartialsToUIKey = "NOUM_COACH_STREAM_RAW_PARTIALS_TO_UI"

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

    /// Whether raw, un-vetted provider tokens are streamed into the VISIBLE
    /// coach row as they arrive. Default OFF, which matches
    /// `providerStreamingEnabled`'s own documented intent ("the UI still shows
    /// only the local typed coach read until the completed provider draft passes
    /// the existing quality gates"). Off closes the "multi-version reply" defect:
    /// a rich streamed draft can no longer be shown and then quietly replaced by
    /// a shorter gate-substituted final. With partials withheld, every assessed
    /// turn gets the local read and the provider uses its ordinary endpoint;
    /// streaming would add connection risk without changing visible latency.
    /// On restores the prior show-raw-partials behaviour for A/B.
    static var streamRawPartialsToUI: Bool {
        boolFlag(
            key: streamRawPartialsToUIKey,
            defaultValue: false
        )
    }

    /// Master switch for the last-mile `CoachReliabilityGate`. Default on: a
    /// final reply that is empty, a verbatim duplicate, a placeholder stub, or a
    /// leaked scaffold is replaced with a truthful coach-shaped fallback before
    /// it reaches the UI. Off keeps the pre-gate behaviour (whatever the provider
    /// chain produced ships as-is).
    static var reliabilityGateEnabled: Bool {
        boolFlag(
            key: reliabilityGateEnabledKey,
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
enum CoachProviderTier: String, Codable, Equatable, Sendable {
    case geminiFast
    case claudeReasoning

    /// Stable transport vocabulary. The provider-oriented enum cases remain
    /// backward compatible with persisted diagnostics, while the production
    /// wire contract names the user-visible service levels directly.
    var transportQualityTier: String {
        switch self {
        case .geminiFast: return "fast"
        case .claudeReasoning: return "ultra"
        }
    }

    /// Decodes both the stable transport vocabulary and the provider-oriented
    /// spellings emitted by pre-production clients/servers during rollout.
    init?(transportQualityTier value: String) {
        switch value {
        case "fast", Self.geminiFast.rawValue:
            self = .geminiFast
        case "ultra", Self.claudeReasoning.rawValue:
            self = .claudeReasoning
        default:
            return nil
        }
    }

    static func transportQualityTiersMatch(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = Self(transportQualityTier: lhs),
              let right = Self(transportQualityTier: rhs) else {
            return false
        }
        return left == right
    }
}
