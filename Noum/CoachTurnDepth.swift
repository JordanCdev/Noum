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

/// A generic craft benchmark is not personal telemetry. It is a bounded,
/// context-sensitive reference range that the coach may state only when the
/// user asks for that exact kind of guidance.
enum CoachBenchmarkKind: String, Codable, Equatable {
    case keynotePace
    case elevatorPitchLength
    case pauseDuration
}

struct CoachBenchmarkAuthorization: Equatable {
    let kind: CoachBenchmarkKind
    let range: String
    let contextCaveat: String

    var promptName: String {
        switch kind {
        case .keynotePace: return "generic keynote pace"
        case .elevatorPitchLength: return "generic elevator-pitch length"
        case .pauseDuration: return "generic pause duration"
        }
    }

    var directAnswer: String {
        switch kind {
        case .keynotePace:
            return "For most keynotes, about \(range) is a useful starting range, not a universal target; \(contextCaveat)."
        case .elevatorPitchLength:
            return "A useful starting range for an elevator pitch is \(range), not a universal target; \(contextCaveat)."
        case .pauseDuration:
            return "For an emphasis pause, \(range) is a useful starting range, not a fixed rule; \(contextCaveat)."
        }
    }

    /// Authorizes only explicit normative craft questions. A question about
    /// what the user personally did remains in the personal-metric lane.
    static func explicitRequest(in userText: String) -> CoachBenchmarkAuthorization? {
        guard TurnDepthClassifier.requestedPersonalMetrics(userText).isEmpty else {
            return nil
        }
        let turn = normalized(userText)
        let asksForGuidance = [
            "should", "ideal", "recommended", "recommend", "good range",
            "typical", "usually", "good", "best", "how long", "how fast", "what pace",
            "starting point", "benchmark"
        ].contains(where: turn.contains)
        guard asksForGuidance else { return nil }

        if ["keynote", "presentation", "speech"].contains(where: turn.contains),
           ["pace", "wpm", "words per minute", "how fast"].contains(where: turn.contains) {
            return CoachBenchmarkAuthorization(
                kind: .keynotePace,
                range: "120–150 words per minute",
                contextCaveat: "adjust for audience familiarity, idea density, emphasis, and the room"
            )
        }
        if turn.contains("elevator pitch"),
           ["length", "long", "duration", "seconds", "time"].contains(where: turn.contains) {
            return CoachBenchmarkAuthorization(
                kind: .elevatorPitchLength,
                range: "30–60 seconds",
                contextCaveat: "adjust for the listener's context, permission, and the decision you want"
            )
        }
        if ["pause", "silence", "silent beat"].contains(where: turn.contains),
           ["length", "long", "duration", "seconds", "time", "ideal"].contains(where: turn.contains) {
            return CoachBenchmarkAuthorization(
                kind: .pauseDuration,
                range: "0.5–1.5 seconds",
                contextCaveat: "use the shorter end inside a thought and more space at a transition or in a larger room"
            )
        }
        return nil
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(
                of: #"[^a-z0-9.'\s-]"#,
                with: " ",
                options: .regularExpression
            )
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

/// Narrow knowledge-question detector. It intentionally does not treat
/// "How do I ...?" or "What should I say?" as answer-only, because those are
/// requests for applied coaching and benefit from a model plus one attempt.
enum CoachCraftKnowledgeRequest {
    static func isAnswerOnly(_ userText: String) -> Bool {
        if CoachBenchmarkAuthorization.explicitRequest(in: userText) != nil {
            return true
        }
        guard TurnDepthClassifier.requestedPersonalMetrics(userText).isEmpty else {
            return false
        }
        let turn = userText
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !turn.hasPrefix("how do i "),
              !turn.hasPrefix("how can i "),
              !turn.hasPrefix("what should i say"),
              !turn.hasPrefix("what do i say") else {
            return false
        }
        let personalEvidenceMarkers = [
            "my answer", "my rep", "my session", "my last", "based on my",
            "in my delivery", "did i ", "was i ", "do i sound",
            "about me", "know about me", "noticed about me"
        ]
        let usesFirstPersonEvidence = turn.contains(" my ") || turn.hasPrefix("my ")
        guard !usesFirstPersonEvidence,
              !personalEvidenceMarkers.contains(where: turn.contains) else {
            return false
        }
        let knowledgeLeads = [
            "what is ", "what's ", "what are ", "what does ",
            "what makes ", "what's the difference", "what is the difference",
            "why does ", "why is ", "why are ", "how does ", "when should ",
            "explain ", "can you explain ", "could you explain ", "is there ",
            "tell me about "
        ]
        guard knowledgeLeads.contains(where: turn.hasPrefix) else { return false }
        let craftTerms = [
            "communication", "speaking", "speaker", "presentation", "keynote",
            "pitch", "pause", "silence", "cadence", "pace", "prosody",
            "vocal", "tone", "emphasis", "storytelling", "story", "narrative",
            "listening", "listen", "audience", "stakeholder", "executive",
            "clarity", "concise", "rambling", "filler", "eye contact",
            "body language", "delivery", "rhetoric", "message", "conversation",
            "turn-taking", "paraphrase", "summarise", "summarize"
        ]
        return craftTerms.contains(where: turn.contains)
    }
}

/// The conversational posture the coach should take before choosing wording.
/// This is deliberately separate from turn depth: an exhausted user can make a
/// technically deep request and still need presence rather than another task.
enum CoachReplyPosture: String, Codable, Equatable {
    /// The normal professional-coaching loop: read, demonstrate, invite one try.
    case coachedAttempt
    /// The user explicitly asked for telemetry. Answer only the requested facts.
    case requestedMetrics
    /// The user asked for general craft knowledge or a generic benchmark. Give
    /// the answer itself without converting it into a mandatory exercise.
    case informationOnly
    /// The user has signalled that they have no capacity for another exercise.
    /// Presence is a complete response; a drill or closing question is optional
    /// only after the user re-opens the work.
    case presenceOnly

    static func resolve(
        userText: String,
        requestedMetrics: [CoachMetricKind] = []
    ) -> CoachReplyPosture {
        if !requestedMetrics.isEmpty {
            return .requestedMetrics
        }

        let lower = userText
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
        let lowCapacityMarkers = [
            "i'm exhausted", "im exhausted", "i am exhausted",
            "i'm tired", "im tired", "i am tired",
            "i'm too tired", "im too tired", "i am too tired",
            "i'm overwhelmed", "im overwhelmed", "i am overwhelmed",
            "i can't do another", "i cant do another",
            "i don't have it in me", "i dont have it in me",
            "i feel defeated", "i'm defeated", "im defeated",
            "i need to stop", "can we stop"
        ]
        if lowCapacityMarkers.contains(where: lower.contains) {
            return .presenceOnly
        }
        if CoachCraftKnowledgeRequest.isAnswerOnly(userText) {
            return .informationOnly
        }
        return .coachedAttempt
    }
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
