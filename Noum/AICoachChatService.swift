import Foundation
import os

// MARK: - AI Coach Chat Service
//
// Multi-turn coaching chat — the model behind the "Ask Noum" surface.
// Speaks a CHAIN of providers (Gemini → Anthropic → OpenAI → DeepSeek,
// whichever have keys) with per-provider cooldowns, so a rate-limited or
// refusing provider fails over to the next instead of failing on the first
// outage or synthesizing local coach copy. The rest of the AI layer
// still uses the shared single-provider plumbing; this service is
// *stateful per request* (it replays the conversation history every
// turn) and always-text (no JSON response shape; the coach is supposed
// to write like a coach, not emit data).
//
// Design rules:
//   • Composed of: a voice-specific system prompt (from
//     `CoachContextBuilder.systemPrompt`), the user's context block
//     (`CoachContextBuilder.userContext`), and the running thread.
//   • Bounded replay — cap at 12 user-coach turn pairs in the request
//     body (24 messages). Older context is summarised by virtue of
//     being baked into the user context block.
//   • Token-bounded — temperature 0.6, output cap 180. The system
//     prompt brevity contract (compact 1-4 line replies) carries the style;
//     the cap prevents Gemini from spending a spoken coach beat on a mini-report.
//     History: a 350 cap silently truncated. The default provider is a
//     thinking-capable Gemini models whose budget can be shared between
//     invisible reasoning tokens and visible text, so terse/ambiguous
//     early questions triggered heavy reasoning that ate the 350 budget
//     and guillotined the visible answer mid-word ("…guide you through
//     the app'"). Fix: Gemini reasoning is disabled (thinkingConfig
//     thinkingBudget 0) so the whole budget is visible text. The cap now keeps
//     enough headroom for a short requested plan without inviting ramble.
//   • Truncation-honest — response extraction reads the provider finish
//     reason (Gemini `finishReason`, OpenAI/DeepSeek `finish_reason`). A
//     length-truncated completion (MAX_TOKENS / "length") stays an honest
//     `.empty` notice instead of a sentence that stops dead. Other no-text
//     responses also stay typed failures; Ask Noum must never fake a coach
//     answer locally.
//   • Failure-typed — `reply(...)` returns `ChatOutcome` so the store
//     can route to per-cause copy (locale-block vs. network vs. no
//     provider vs. empty) instead of one generic "couldn't reach my
//     model" string that misdirected users. Never fabricate a reply.

/// Why a chat turn didn't produce a coach reply. Mapped to per-cause
/// copy by `AskNoumStore`; never shown raw to the user.
enum ChatFailure: Equatable {
    /// No AI provider has a usable API key configured.
    case noProvider
    /// Current practice locale isn't supported by the AI surfaces
    /// (English-only today per M13).
    case localeUnsupported
    /// Transport / HTTP / JSON-encode failure.
    case network
    /// A reply could not be safely committed: the provider returned empty or
    /// length-truncated content. Distinct from `.network` because rephrasing
    /// might help.
    case empty
    /// The model WAS reachable and replied, but every draft (and repair)
    /// failed the local quality gate. Distinct from `.network` so the UI
    /// never claims "offline" to a user who is online — that reads as a
    /// broken product, not an honest state.
    case contentRejected
}

/// Outcome of a chat turn — either a live model reply or a typed failure the
/// store maps to per-cause copy.
enum ChatOutcome {
    /// A live, model-generated reply.
    case reply(String)
    case failure(ChatFailure)
}

typealias CoachChatDiagnosticRecorder = (
    _ surface: String,
    _ providerName: String?,
    _ model: String?,
    _ outcome: AICallDiagnosticOutcome,
    _ reason: String,
    _ statusCode: Int?,
    _ startedAt: Date?,
    _ now: Date
) -> Void

/// Provider response extraction result for Ask Noum text replies. Kept typed
/// so the service can preserve truncation honesty without treating every
/// no-text response as a user-visible dead end.
enum ChatExtractionResult: Equatable {
    case text(String)
    case empty
    case lengthTruncated
}

/// Normalizes live coach text before it is stored, rendered in the live call,
/// or sent to TTS. The model may still occasionally emit Markdown-ish text;
/// Noum's app surfaces should never expose raw scaffolding like `**Read:**`,
/// and spoken replies should not read formatting labels aloud.
enum CoachReplyTextSanitizer {
    static let coachScaffoldLeadInPattern = #"read|the read|coach read|observation|diagnosis|insight|next move|next rep|move|action|why|evidence|try this|try|focus|target|drill|practice|recommend|recommendation"#

    private static let coachScaffoldOnlyLabels: Set<String> = [
        "read", "the read", "coach read", "observation", "diagnosis",
        "insight", "move", "next move", "next rep", "action", "why",
        "evidence", "try this", "try", "focus", "target", "drill",
        "practice", "recommend", "recommendation"
    ]

    nonisolated static func displayText(from raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }

        value = replace(pattern: "\\[([^\\]\\n]+?)\\]\\([^\\)\\n]+?\\)", in: value, template: "$1")
        value = replace(pattern: "`([^`\\n]+?)`", in: value, template: "$1")
        value = replace(pattern: "\\*\\*([^\\n*]+?)\\*\\*", in: value, template: "$1")
        value = replace(pattern: "__([^\\n_]+?)__", in: value, template: "$1")
        value = replace(pattern: "\\*([^\\n*]+?)\\*", in: value, template: "$1")
        value = replace(pattern: "(?<![A-Za-z0-9])_([^\\n_]+?)_(?![A-Za-z0-9])", in: value, template: "$1")
        value = value
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")

        let lines = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { normalizeDisplayLine(String($0)) }

        return lines
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Stored coach replies should be clean user-facing speech, not the
    /// model's internal planning scaffold. Unlike `liveDisplayText`, this
    /// keeps bullets / numbered steps so text chat can still scan well.
    nonisolated static func coachReplyText(from raw: String) -> String {
        let display = displayText(from: raw)
        guard !display.isEmpty else { return "" }

        let lines = display
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { stripCoachScaffoldForStoredReplyLine(String($0)) }

        return collapseBlankLines(lines)
    }

    /// Live-call captions should read like the coach is speaking in the room,
    /// not like a transcript of the model's planning scaffold. Keep the chat
    /// display sanitizer permissive for formatted text bubbles; make the call
    /// surface stricter and strip labels the user should never have to parse
    /// mid-conversation.
    nonisolated static func liveDisplayText(from raw: String) -> String {
        let display = coachReplyText(from: raw)
        guard !display.isEmpty else { return "" }

        let lines = display
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var value = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                value = stripBulletMarker(from: value)
                value = stripNumberMarker(from: value)
                value = stripCoachLeadIn(from: value)
                value = stripInlineCoachLeadIns(from: value)
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return isScaffoldOnlyDisplayLine(value) ? "" : value
            }

        return collapseBlankLines(lines)
    }

    /// The call landing is a single focus line. Strip scaffolds with the live
    /// sanitizer, then collapse line breaks so a stored case-file note cannot
    /// render as a mini brief before the user speaks.
    nonisolated static func liveLandingText(from raw: String) -> String {
        liveDisplayText(from: raw)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func spokenText(from raw: String) -> String {
        let display = displayText(from: raw)
        guard !display.isEmpty else { return "" }

        let parts = display
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var value = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                value = stripBulletMarker(from: value)
                value = stripNumberMarker(from: value)
                value = stripCoachLeadIn(from: value)
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let speechSafe = stripSpokenOnlyDecorations(from: parts.joined(separator: " "))
            .replacingOccurrences(of: "\\s+([,.!?;:])", with: "$1", options: .regularExpression)
        return stripInlineCoachLeadIns(from: speechSafe)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func replace(
        pattern: String,
        in value: String,
        template: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        return regex.stringByReplacingMatches(
            in: value,
            range: NSRange(value.startIndex..., in: value),
            withTemplate: template
        )
    }

    private nonisolated static func normalizeDisplayLine(_ line: String) -> String {
        var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("#") {
            value.removeFirst()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while value.hasPrefix(">") {
            value.removeFirst()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if value.hasPrefix("* ") {
            value = "- " + String(value.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if value.hasPrefix("+ ") {
            value = "- " + String(value.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private nonisolated static func collapseBlankLines(_ lines: [String]) -> String {
        var output: [String] = []
        var previousBlank = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !previousBlank, !output.isEmpty {
                    output.append("")
                }
                previousBlank = true
            } else {
                output.append(trimmed)
                previousBlank = false
            }
        }
        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func stripBulletMarker(from value: String) -> String {
        for marker in ["- ", "* ", "+ ", "• "] where value.hasPrefix(marker) {
            return String(value.dropFirst(marker.count))
        }
        return value
    }

    private nonisolated static func stripNumberMarker(from value: String) -> String {
        guard let separator = value.firstIndex(where: { $0 == "." || $0 == ")" }) else {
            return value
        }
        let prefix = value[..<separator]
        guard !prefix.isEmpty,
              prefix.allSatisfy({ $0.isNumber }),
              let number = Int(prefix),
              number > 0 else {
            return value
        }
        let after = value.index(after: separator)
        guard after < value.endIndex, value[after].isWhitespace else { return value }
        return String(value[after...])
    }

    private nonisolated static func stripCoachScaffoldForStoredReplyLine(_ line: String) -> String {
        var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }

        var prefix = ""
        if let marker = ["- ", "* ", "+ ", "• "].first(where: { value.hasPrefix($0) }) {
            prefix = marker
            value = String(value.dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let list = numberedListPrefix(in: value) {
            prefix = list.prefix
            value = list.body
        }

        value = stripCoachLeadIn(from: value)
        value = stripInlineCoachLeadIns(from: value)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty, !isScaffoldOnlyDisplayLine(value) else { return "" }
        return prefix.isEmpty ? value : "\(prefix)\(value)"
    }

    private nonisolated static func numberedListPrefix(in value: String) -> (prefix: String, body: String)? {
        guard let separator = value.firstIndex(where: { $0 == "." || $0 == ")" }) else {
            return nil
        }
        let prefix = value[..<separator]
        guard !prefix.isEmpty,
              prefix.allSatisfy({ $0.isNumber }),
              Int(prefix) != nil else {
            return nil
        }
        let afterSeparator = value.index(after: separator)
        guard afterSeparator < value.endIndex,
              value[afterSeparator].isWhitespace else {
            return nil
        }
        let bodyStart = value.index(after: afterSeparator)
        guard bodyStart <= value.endIndex else { return nil }
        return (
            "\(prefix)\(value[separator]) ",
            String(value[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private nonisolated static func stripCoachLeadIn(from value: String) -> String {
        let pattern = #"(?i)^("# + coachScaffoldLeadInPattern + #"):\s*"#
        return replace(pattern: pattern, in: value, template: "")
    }

    private nonisolated static func stripInlineCoachLeadIns(from value: String) -> String {
        let pattern = #"(?i)(^|[.!?]\s+|\s+[—-]\s+)("# + coachScaffoldLeadInPattern + #"):\s*"#
        return replace(pattern: pattern, in: value, template: "$1")
    }

    private nonisolated static func isScaffoldOnlyDisplayLine(_ value: String) -> Bool {
        let lower = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":."))
            .lowercased()
        return coachScaffoldOnlyLabels.contains(lower)
    }

    /// Keep visual warmth available in chat, but never send emoji/decorative
    /// symbols to TTS where they can be read aloud as literal names.
    private nonisolated static func stripSpokenOnlyDecorations(from value: String) -> String {
        var output = ""
        for character in value {
            if character.unicodeScalars.contains(where: isSpokenEmojiScalar) {
                continue
            }
            output.append(character)
        }
        return output
    }

    private nonisolated static func isSpokenEmojiScalar(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.isEmojiPresentation ||
            scalar.properties.isEmojiModifier ||
            scalar.properties.isEmojiModifierBase {
            return true
        }
        switch scalar.value {
        case 0xFE0F, 0x200D:
            return true
        case 0x1F000...0x1FAFF, 0x2600...0x27BF:
            return true
        default:
            return false
        }
    }
}

/// Obvious ways a live Ask-Noum reply can fail the professional-coach contract.
/// This is intentionally conservative: it catches drafts that are plainly too
/// long, robotic, defensive, menu-shaped, or asking for bare clarification. It
/// does not try to score nuance or truth; that still belongs to the model and
/// the structured context.
enum CoachChatReplyQualityIssue: Equatable {
    case tooLong
    case roboticPhrase(String)
    case bareClarification
    case defensiveProductLanguage
    case menuInsteadOfDecision
    case missedTrustRepair
    case missingPrescribedAction
    case missingInsightBridge
    case unanchoredCoaching
    case overclaimsEvidence
    case unrequestedNamedTechnique
    case scaffoldLabel
    case unverifiedQuotedUserSpeech
    case unengagedUserSpeechClaim
    case ignoredCoachingExpertise

    var repairInstruction: String {
        switch self {
        case .tooLong:
            return "The draft is too long for text-mode coaching. Rewrite it as 1-4 short lines, usually under 75 words."
        case .roboticPhrase(let phrase):
            return "The draft uses robotic/template language: \(phrase). Rewrite it in a senior human coach register."
        case .bareClarification:
            return "The draft asks for clarification without doing coaching work. Infer the likely intent and give one useful move."
        case .defensiveProductLanguage:
            return "The draft defends the product or model. Do not defend; repair trust and return to the coaching work."
        case .menuInsteadOfDecision:
            return "The draft offers a broad menu or asks the user to choose again. Pick one recommendation and prescribe it."
        case .missedTrustRepair:
            return "The user challenged the coaching quality. Repair trust first with \"Fair push\" or another short natural acknowledgement, name the friction briefly, then use so or because to connect one grounded fact to one changed coaching move. Avoid stiff self-narration about changing the reply style."
        case .missingPrescribedAction:
            return "The draft does not prescribe a concrete next move. Give one action the user can take in the next rep or review."
        case .missingInsightBridge:
            return "The draft gives an anchor and an action but does not connect them with a coaching read. Use so or because to explain why this move fits the signal."
        case .unanchoredCoaching:
            return "The draft is not anchored in an observable fact, recent user message, case-file target, or honest data gap. Add one grounded anchor. If referencing a practice session, say \"your last rep\" or \"a recent rep\", never the exact calendar date."
        case .overclaimsEvidence:
            return "The draft overclaims from limited evidence, labels the user, or treats a drill as guaranteed to cause improvement. Reframe as a testable coaching hypothesis the user can confirm or reject."
        case .unrequestedNamedTechnique:
            return "The draft turns the move into an app-like drill or framework label the user did not ask for. Rewrite it as plain action; name a framework only when the user explicitly asks for one."
        case .scaffoldLabel:
            return "The draft exposes planning labels such as Read, Move, Target, or Next rep. Remove the labels and write the same coaching in natural user-facing language."
        case .unverifiedQuotedUserSpeech:
            return "The draft quotes user speech that is not verified against a transcript or the latest user turn. Remove the quote and cite a metric, pattern, or honest data gap instead."
        case .unengagedUserSpeechClaim:
            return "The draft claims to read the user's words but does not touch any known transcript, verified proof, or their latest message. Ground the read in what they actually said, or cite a metric, pattern, or honest data gap instead."
        case .ignoredCoachingExpertise:
            return "The draft ignores the retrieved coaching expertise for this technique-seeking turn. Use the COACHING EXPERTISE block as craft guidance: apply its technique in plain user-facing language, tied to the user's context."
        }
    }
}

/// Rubric misses used by the local professional-coach gate. This is not a
/// claim that the app is calibrated against a human coach; it is the
/// version-controlled substrate for catching obvious non-coach replies before
/// they ship to the user.
enum CoachChatProfessionalRubricMiss: String, Equatable {
    case overlong
    case roboticRegister
    case missedTrustRepair
    case missingObservableAnchor
    case missingPrescribedAction
    case missingInsightBridge
    case overclaimsEvidence
    case menuInsteadOfDecision
}

/// Pure, inspectable scoring result for one Ask-Noum reply. Kept outside the
/// actor so tests can evaluate candidate replies without touching provider
/// plumbing, stores, or network state.
struct CoachChatProfessionalRubricResult: Equatable {
    let score: Int
    let misses: [CoachChatProfessionalRubricMiss]

    var passesSeniorCoachFloor: Bool {
        score >= 8 && misses.isEmpty
    }
}

/// Transcript sources the live chat may quote from. Ask Noum is still a prose
/// chat surface, but any "you said ..." quote must be backed by an exact slice
/// of a known transcript, a verified proof quote, or the user's latest turn.
/// Pure and transient — no persistence, no new chat schema.
///
/// This context backs BOTH halves of the chat's dual gate (the same pairing
/// `PostRepCoachNoteService.generate` enforces on the post-rep note):
///   • Gate 1 — presence (`engagesAnySource`): a reply that CLAIMS a read of
///     the user's words must actually touch a known source at the
///     `PostRepCoachNoteService.engagesTranscript` standard.
///   • Gate 2 — fabrication (`verifies`): any QUOTED fragment attributed to
///     the user must match a source exactly (ProofMomentService).
struct CoachChatQuoteGuardContext: Equatable {
    let sourceTexts: [String]

    init(
        transcripts: [String?] = [],
        verifiedProofQuotes: [String] = [],
        latestUserTurn: String? = nil,
        recentUserTurns: [String] = []
    ) {
        // `recentUserTurns` carries the WHOLE replayed conversation's user
        // messages, not just the latest. A coach who says "you mentioned
        // interviews" about something the user typed three turns ago is
        // reading real user words — without these sources Gate 1 rejects useful
        // replies and pushes the turn into a system notice.
        // Anti-fabrication holds: claims still must match something the
        // user actually said in a rep, a verified proof, or the chat.
        self.sourceTexts = (transcripts + verifiedProofQuotes.map { Optional($0) }
            + [latestUserTurn] + recentUserTurns.map { Optional($0) })
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func verifies(_ quote: String) -> Bool {
        sourceTexts.contains { source in
            ProofMomentService.transcriptContains(quote, in: source)
        }
    }

    /// Gate 1 of the dual gate: true when the reply genuinely engages at
    /// least one known source — shares a >= 4-char content word or a
    /// >= 12-char verbatim slice with a rep transcript, a verified proof
    /// quote, or the user's latest turn. Reuses the post-rep note's
    /// `engagesTranscript` core so chat and note hold the same standard.
    /// With no sources at all, a claimed read is unverifiable and fails —
    /// mirroring Gate 2's rejection of unverifiable attributed quotes.
    func engagesAnySource(_ reply: String) -> Bool {
        sourceTexts.contains { source in
            PostRepCoachNoteService.engagesTranscript(reply, transcript: source)
        }
    }
}

/// Decode-free, transient grounding context for live chat quote safety.
/// Assembled at the call site from existing stores; never persisted.
struct ChatGroundingContext: Equatable {
    /// The most-recent timed rep's transcript, when one exists. The live model
    /// may reference it, and the quote guard verifies any attributed quote.
    var recentTimedTranscript: String?
    /// Quotes that have already passed the proof-moment guard elsewhere.
    /// The live chat may quote these back; anything else needs to appear in a
    /// transcript or the user's latest turn.
    var verifiedProofQuotes: [String]

    init(
        recentTimedTranscript: String? = nil,
        verifiedProofQuotes: [String] = []
    ) {
        self.recentTimedTranscript = recentTimedTranscript
        self.verifiedProofQuotes = verifiedProofQuotes
    }
}

@available(iOS 17.0, macOS 12.0, *)
// MARK: - Chat provider chain

/// Chat-reply provider identity. Wraps the shared `AIProvider` cases and adds
/// chat-only providers. Promoting each chat-only provider into `AIProvider`
/// proper means giving every AI service a request/extract branch (~40 switch
/// sites across the AI layer), tracked as a follow-up. Declaration order is
/// the failover preference order.
enum CoachChatProvider: CaseIterable, Equatable, Hashable {
    case agentPlatform
    case gemini
    case anthropic
    case openAI
    case deepSeek

    /// The shared-provider equivalent whose request/extract plumbing already
    /// exists, or nil for chat-only providers with their own branch.
    var sharedProvider: AIProvider? {
        switch self {
        case .agentPlatform, .gemini: return .gemini
        case .openAI: return .openAI
        case .deepSeek: return .deepSeek
        case .anthropic: return nil
        }
    }

    var keyName: String {
        keyNames[0]
    }

    var keyNames: [String] {
        switch self {
        case .agentPlatform:
            return [
                "GOOGLE_AGENT_PLATFORM_API_KEY",
                "GOOGLE_CLOUD_AGENT_PLATFORM_API_KEY",
                "VERTEX_AI_API_KEY"
            ]
        case .gemini: return ["GEMINI_API_KEY"]
        case .anthropic: return ["ANTHROPIC_API_KEY"]
        case .openAI: return ["OPENAI_API_KEY"]
        case .deepSeek: return ["DEEPSEEK_API_KEY"]
        }
    }

    var model: String {
        switch self {
        case .agentPlatform:
            // Agent Platform uses Google Cloud billing. It can share the chat
            // model override, but gets its own key so Cloud/AI Studio
            // experiments do not have to move together.
            return Self.configValue(forKeys: [
                "GOOGLE_AGENT_PLATFORM_MODEL",
                "GOOGLE_CLOUD_AGENT_MODEL",
                "VERTEX_AI_GEMINI_MODEL",
                "GEMINI_CHAT_MODEL"
            ]) ?? "gemini-3.5-flash"
        case .anthropic:
            // Claude is a quality fallback for the coach, not a cheap
            // background summarizer. Default to Sonnet, while allowing
            // AIConfig/env overrides for cost or latency experiments.
            return Self.configValue(forKeys: [
                "ANTHROPIC_CHAT_MODEL",
                "ANTHROPIC_MODEL"
            ]) ?? "claude-sonnet-4-6"
        case .gemini:
            // Chat-only override (AIConfig.plist `GEMINI_CHAT_MODEL`) so a
            // newer Gemini can be A/B'd against the register/quality gate
            // without touching the other AI surfaces. Absent key = shared
            // default, same behavior as before.
            return LocalConfigLoader.value(forKey: "GEMINI_CHAT_MODEL", plistNamed: "AIConfig")
                ?? sharedProvider?.model ?? ""
        case .openAI, .deepSeek: return sharedProvider?.model ?? ""
        }
    }

    var endpoint: URL? {
        switch self {
        case .agentPlatform:
            return Self.agentPlatformEndpoint(model: model)
        case .anthropic: return URL(string: "https://api.anthropic.com/v1/messages")
        case .gemini:
            // Built from `model` (not the shared endpoint) so the
            // GEMINI_CHAT_MODEL override actually changes the URL — Gemini
            // carries the model in the path, not the request body.
            return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        case .openAI, .deepSeek: return sharedProvider?.endpoint
        }
    }

    var displayName: String {
        switch self {
        case .agentPlatform: return "Google Cloud"
        case .gemini: return "Gemini"
        case .anthropic: return "Claude"
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        }
    }

    nonisolated static func configurationSummary(
        providers: [CoachChatProvider] = CoachChatProvider.allCases,
        env: [String: String] = ProcessInfo.processInfo.environment,
        localValue: (String) -> String? = { keyName in
            LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
        }
    ) -> String {
        providers
            .map { provider in
                let states: [String] = [
                    provider.hasConfiguredKey(env: env, localValue: localValue)
                        ? "key present"
                        : "missing key"
                ]
                return "\(provider.displayName): \(states.joined(separator: ", "))"
            }
            .joined(separator: " | ")
    }

    nonisolated static func agentPlatformEndpoint(model: String) -> URL? {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else { return nil }

        let modelPath = trimmedModel.hasPrefix("publishers/google/models/")
            ? String(trimmedModel.dropFirst("publishers/google/models/".count))
            : trimmedModel
        return URL(
            string: "https://aiplatform.googleapis.com/v1/publishers/google/models/\(modelPath):generateContent"
        )
    }

    private nonisolated func hasConfiguredKey(
        env: [String: String],
        localValue: (String) -> String?
    ) -> Bool {
        keyNames.contains { keyName in
            AIProviderCredential.usableAPIKey(env[keyName]) != nil ||
            AIProviderCredential.usableAPIKey(localValue(keyName)) != nil
        }
    }

    private nonisolated static func configurationValue(
        forKeys keys: [String],
        env: [String: String],
        localValue: (String) -> String?
    ) -> String? {
        for key in keys {
            if let value = AIProviderCredential.usableAPIKey(env[key]) {
                return value
            }
            if let value = AIProviderCredential.usableAPIKey(localValue(key)) {
                return value
            }
        }
        return nil
    }

    private nonisolated static func configValue(forKeys keys: [String]) -> String? {
        for key in keys {
            if let value = ProcessInfo.processInfo.environment[key],
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let value = LocalConfigLoader.value(forKey: key, plistNamed: "AIConfig"),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}

/// Why a provider attempt produced no usable reply, and how long that
/// provider should sit out of the chain. Cooldowns stop a rate-limited
/// provider from being re-hit on every chat turn while it's refusing.
enum CoachChatProviderRefusal: Equatable {
    /// 429 — the quota window will pass; sit out briefly.
    case rateLimited
    /// 401/403 — the key is bad or blocked; hammering won't fix it.
    case authBlocked
    /// 5xx / transport / empty body — likely transient.
    case transient
    /// Reply text failed the quality gate and repair — a content miss by
    /// this model on this turn, not a provider-health problem. No cooldown.
    case contentRejected

    var cooldown: TimeInterval {
        switch self {
        case .rateLimited: return 60
        case .authBlocked: return 600
        case .transient: return 30
        case .contentRejected: return 0
        }
    }

    static func classify(status: Int) -> CoachChatProviderRefusal {
        switch status {
        case 429: return .rateLimited
        case 401, 403: return .authBlocked
        default: return .transient
        }
    }
}

/// Redacted provider state for debug tooling and future support screens.
/// Never stores API keys, request bodies, user prompts, or response text.
struct CoachChatProviderDiagnostic: Equatable {
    let provider: CoachChatProvider
    let displayName: String
    let hasUsableKey: Bool
    let model: String
    let endpointHost: String?
    let endpointPath: String?
    let isCoolingDown: Bool
    let cooldownRemainingSeconds: Int?
}

actor AICoachChatService {

    static let shared = AICoachChatService()

    private static let log = Logger(subsystem: "com.jordancoaten.noum", category: "CoachChat")
    private static let chatSurface = "Ask Noum chat"
    private static let healthSurface = "Ask Noum provider check"
    private static let healthSentinel = "NOUM_AI_OK"
    private static let healthPrompt = "Reply with exactly: \(healthSentinel)"
    private static let healthSystemPrompt = "You are a private API health check. Return the requested sentinel only."
    private static let defaultDiagnosticRecorder: CoachChatDiagnosticRecorder = {
        surface,
        providerName,
        model,
        outcome,
        reason,
        statusCode,
        startedAt,
        now in
        AICallDiagnostics.record(
            surface: surface,
            providerName: providerName,
            model: model,
            outcome: outcome,
            reason: reason,
            statusCode: statusCode,
            startedAt: startedAt,
            now: now
        )
    }

    /// Providers that refused recently sit at the BACK of the chain until
    /// this date — never dropped entirely, because a cooling provider is
    /// still better than no provider when it's the only one keyed.
    private var providerCooldowns: [CoachChatProvider: Date] = [:]
    private let keyedProvidersOverride: (() -> [CoachChatProvider])?
    private let keyLookupOverride: ((CoachChatProvider) -> String?)?
    private let localeSupportsAIOverride: (() -> Bool)?
    private let providerHTTPOverride: ((CoachChatProvider, URL, String, [String: Any]) async throws -> ProviderHTTPResult)?
    private let diagnosticRecorder: CoachChatDiagnosticRecorder

    /// Cap on the number of chat messages we replay to the model per
    /// request. The user context block carries the long-arc summary,
    /// so older messages don't need to be sent — they'd inflate
    /// tokens without adding signal.
    private static let maxReplayMessages = 24
    /// Hard output ceiling for the coach turn. The prompt still governs style,
    /// but Gemini will fill whatever visible budget we hand it; keep enough
    /// room for an explicitly requested short plan while making rambling
    /// replies structurally harder.
    private static let coachReplyMaxOutputTokens = 180
    private static let coachRepairMaxOutputTokens = 128

    private nonisolated static func liveEvalDraftSuffix(_ draft: String) -> String {
        #if NOUM_LIVE_AI_EVAL_INCLUDE_DRAFTS
        let includeDraft = true
        #else
        let includeDraft = ProcessInfo.processInfo.environment["NOUM_LIVE_AI_EVAL_INCLUDE_DRAFTS"] == "1"
        #endif
        guard includeDraft else {
            return ""
        }
        let compact = draft
            .unicodeScalars
            .map { scalar -> Character in
                if CharacterSet.newlines.contains(scalar) || scalar.value < 0x20 {
                    return " "
                }
                if scalar.value == 0x22 {
                    return "'"
                }
                return Character(scalar)
            }
            .reduce(into: "") { output, character in
                output.append(character)
            }
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return "" }
        return " draft=\"\(String(compact.prefix(700)))\""
    }

    private init() {
        self.keyedProvidersOverride = nil
        self.keyLookupOverride = nil
        self.localeSupportsAIOverride = nil
        self.providerHTTPOverride = nil
        self.diagnosticRecorder = Self.defaultDiagnosticRecorder
    }

    init(
        keyedProviders: @escaping () -> [CoachChatProvider],
        keyLookup: @escaping (CoachChatProvider) -> String?,
        localeSupportsAI: @escaping () -> Bool,
        providerHTTP: @escaping (CoachChatProvider, URL, String, [String: Any]) async throws -> ProviderHTTPResult,
        diagnosticRecorder: CoachChatDiagnosticRecorder? = nil
    ) {
        self.keyedProvidersOverride = keyedProviders
        self.keyLookupOverride = keyLookup
        self.localeSupportsAIOverride = localeSupportsAI
        self.providerHTTPOverride = providerHTTP
        self.diagnosticRecorder = diagnosticRecorder ?? Self.defaultDiagnosticRecorder
    }

    /// Send a turn to the model. Returns `.reply(text)` on a live success or
    /// `.failure(cause)` when the model cannot produce a safe answer. Total
    /// function — never throws. The store turns failures into honest system
    /// notices; local deterministic coach copy must never masquerade as the
    /// senior AI coach.
    func reply(
        history: [CoachMessage],
        systemPrompt: String,
        userContext: String,
        grounding: ChatGroundingContext = ChatGroundingContext()
    ) async -> ChatOutcome {
        // UI harness only: lets simulator tests verify send -> pipeline ->
        // store -> system-notice rendering without depending on live provider
        // latency or keys. Runtime-gated by `UI_TESTING` rather than
        // compile-gated so UI tests stay deterministic across build configs.
        let launchArguments = ProcessInfo.processInfo.arguments
        if launchArguments.contains("UI_TESTING") {
            if launchArguments.contains("UI_TESTING_CHAT_FORCE_GOAL_REPLY") {
                return .reply("I can help with that shift. Confirm the voice card below, then I will tune the next rep around it.")
            }
            if launchArguments.contains("UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY") {
                return .reply("""
                **Fair.** I’ll keep it direct.

                - Answer first, proof second.
                - Give one 30-second update, so the recommendation lands before the explanation: recommendation, one proof point, stop.
                """)
            }
            if launchArguments.contains("UI_TESTING_CHAT_FORCE_NOTICE") {
                return .failure(.network)
            }
        }

        // M13: AI surfaces are English-only. Non-English chat now resolves as
        // a typed notice rather than an English local coach substitute.
        let localeSupportsAI: Bool
        if let localeSupportsAIOverride {
            localeSupportsAI = localeSupportsAIOverride()
        } else {
            localeSupportsAI = await activeLocaleSupportsAI()
        }
        guard localeSupportsAI else {
            recordChatDiagnostic(.skipped, "Locale not AI-supported")
            return .failure(.localeUnsupported)
        }

        let keyed = keyedProvidersOverride?() ?? Self.keyedProviders()
        guard !keyed.isEmpty else {
            Self.log.error("no chat provider has a key")
            recordChatDiagnostic(.skipped, "No configured chat provider")
            return .failure(.noProvider)
        }

        // Compose the system prompt — voice + context block.
        let composedSystem = systemPrompt + "\n\n" + userContext

        // Trim replay to the cap, keeping the most recent turns.
        let trimmed = Array(history.suffix(Self.maxReplayMessages))
        let latestUserTurn = trimmed.last(where: { $0.role == .user })?.text
        let quoteGuard = CoachChatQuoteGuardContext(
            transcripts: [grounding.recentTimedTranscript],
            verifiedProofQuotes: grounding.verifiedProofQuotes,
            latestUserTurn: latestUserTurn,
            recentUserTurns: trimmed.filter { $0.role == .user }.map(\.text)
        )

        let chain = Self.orderedChain(keyed: keyed, cooldowns: providerCooldowns, now: Date())
        Self.log.debug("chat turn start providers=\(chain.count, privacy: .public) replay=\(trimmed.count, privacy: .public) proofs=\(grounding.verifiedProofQuotes.count, privacy: .public) latestUserChars=\(latestUserTurn?.count ?? 0, privacy: .public)")
        Self.log.debug("chat provider chain=\(Self.providerChainDescription(chain), privacy: .public)")
        var sawContentRejection = false
        for provider in chain {
            guard let endpoint = provider.endpoint else {
                Self.log.error("\(provider.displayName, privacy: .public) skipped: missing endpoint")
                recordChatDiagnostic(.skipped, "Missing provider endpoint", provider: provider)
                continue
            }
            guard let key = key(for: provider) else {
                Self.log.error("\(provider.displayName, privacy: .public) skipped: missing API key")
                recordChatDiagnostic(.skipped, "Missing API key", provider: provider)
                continue
            }
            let outcome = await attempt(
                provider: provider,
                endpoint: endpoint,
                key: key,
                system: composedSystem,
                messages: trimmed,
                quoteGuard: quoteGuard,
                latestUserTurn: latestUserTurn
            )
            switch outcome {
            case .reply(let text):
                providerCooldowns[provider] = nil
                Self.log.info("chat turn succeeded via \(provider.displayName, privacy: .public) chars=\(text.count, privacy: .public)")
                return .reply(text)
            case .refused(let refusal):
                if refusal == .contentRejected { sawContentRejection = true }
                if refusal.cooldown > 0 {
                    providerCooldowns[provider] = Date().addingTimeInterval(refusal.cooldown)
                }
                continue
            }
        }

        // Every keyed provider refused this turn. A content rejection means
        // the model WAS reachable, so that cause must win over `.network`.
        Self.log.error("all \(chain.count) chat providers refused")
        recordChatDiagnostic(
            .failure,
            sawContentRejection ? "All chat providers failed quality gate" : "All chat providers refused"
        )
        return .failure(sawContentRejection ? .contentRejected : .network)
    }

    // MARK: - Provider chain

    /// Providers with a usable key, in declaration (preference) order.
    nonisolated static func keyedProviders(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> [CoachChatProvider] {
        CoachChatProvider.allCases.filter { provider in
            provider.keyNames.contains { keyName in
                if usableAPIKey(env[keyName]) != nil { return true }
                return usableAPIKey(LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")) != nil
            }
        }
    }

    /// Redacted snapshot for support/debug flows. It answers "what can the
    /// app try right now?" without exposing credentials or user content.
    func diagnosticSnapshot(now: Date = Date()) -> [CoachChatProviderDiagnostic] {
        CoachChatProvider.allCases.map { provider in
            let cooldownUntil = providerCooldowns[provider]
            let remaining = cooldownUntil.map { max(0, Int(ceil($0.timeIntervalSince(now)))) } ?? 0
            let isCooling = remaining > 0
            let endpoint = provider.endpoint
            return CoachChatProviderDiagnostic(
                provider: provider,
                displayName: provider.displayName,
                hasUsableKey: key(for: provider) != nil,
                model: provider.model,
                endpointHost: endpoint?.host,
                endpointPath: endpoint?.path,
                isCoolingDown: isCooling,
                cooldownRemainingSeconds: isCooling ? remaining : nil
            )
        }
    }

    /// Tiny live probe for the exact provider/model chain Ask Noum uses.
    /// This complements `AIProviderHealthProbe`, which checks the shared
    /// structured-AI provider path. Chat has its own Gemini model override and
    /// Claude branch, so it needs its own probe to answer "will the coach reply?"
    /// without sending a user prompt or transcript.
    func runConfiguredProviderHealthProbes(
        providers: [CoachChatProvider] = CoachChatProvider.allCases,
        session: URLSession = .shared
    ) async -> [AIProviderHealthProbeResult] {
        var results: [AIProviderHealthProbeResult] = []
        for provider in providers {
            results.append(await runProviderHealthProbe(for: provider, session: session))
        }
        return results
    }

    /// Pure ordering: ready providers first, cooling ones moved to the BACK —
    /// not dropped, because when everything is cooling the chain must still
    /// try its best option rather than ending the turn early.
    nonisolated static func orderedChain(
        keyed: [CoachChatProvider],
        cooldowns: [CoachChatProvider: Date],
        now: Date
    ) -> [CoachChatProvider] {
        let ready = keyed.filter { (cooldowns[$0] ?? .distantPast) <= now }
        let cooling = keyed.filter { (cooldowns[$0] ?? .distantPast) > now }
        return ready + cooling
    }

    nonisolated static func usableAPIKey(_ value: String?) -> String? {
        AIProviderCredential.usableAPIKey(value)
    }

    private nonisolated static func providerChainDescription(_ providers: [CoachChatProvider]) -> String {
        providers.map(\.displayName).joined(separator: " > ")
    }

    private enum AttemptOutcome {
        case reply(String)
        case refused(CoachChatProviderRefusal)
    }

    private func runProviderHealthProbe(
        for provider: CoachChatProvider,
        session: URLSession
    ) async -> AIProviderHealthProbeResult {
        guard let endpoint = provider.endpoint else {
            return recordHealthProbe(.skipped, "Missing provider endpoint", provider: provider)
        }
        guard let key = key(for: provider) else {
            return recordHealthProbe(.skipped, "Missing API key", provider: provider)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        switch provider {
        case .openAI, .deepSeek:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .agentPlatform, .gemini:
            request.setGoogleAPIKey(key)
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }

        do {
            request.httpBody = try Self.healthRequestBody(for: provider)
        } catch {
            return recordHealthProbe(.failure, "Could not build health-check request", provider: provider)
        }

        let startedAt = Date()
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return recordHealthProbe(.failure, "Non-HTTP response", provider: provider, startedAt: startedAt)
            }
            guard (200..<300).contains(http.statusCode) else {
                return recordHealthProbe(
                    .failure,
                    Self.failureReason(forHTTPStatus: http.statusCode, data: data, provider: provider),
                    provider: provider,
                    statusCode: http.statusCode,
                    startedAt: startedAt
                )
            }
            guard Self.healthResponseContainsSentinel(data, provider: provider) else {
                return recordHealthProbe(
                    .failure,
                    "Sentinel missing from provider response",
                    provider: provider,
                    statusCode: http.statusCode,
                    startedAt: startedAt
                )
            }
            return recordHealthProbe(
                .success,
                "Provider returned health-check sentinel",
                provider: provider,
                statusCode: http.statusCode,
                startedAt: startedAt
            )
        } catch {
            return recordHealthProbe(.failure, "Transport error", provider: provider, startedAt: startedAt)
        }
    }

    private nonisolated func recordHealthProbe(
        _ outcome: AICallDiagnosticOutcome,
        _ reason: String,
        provider: CoachChatProvider,
        statusCode: Int? = nil,
        startedAt: Date? = nil
    ) -> AIProviderHealthProbeResult {
        AICallDiagnostics.record(
            surface: Self.healthSurface,
            providerName: provider.displayName,
            model: provider.model,
            outcome: outcome,
            reason: reason,
            statusCode: statusCode,
            startedAt: startedAt
        )
        return AIProviderHealthProbeResult(
            provider: provider.sharedProvider,
            outcome: outcome,
            reason: reason,
            statusCode: statusCode,
            providerName: "Ask Noum \(provider.displayName)",
            model: provider.model
        )
    }

    /// One provider attempt: request (with a single short retry when the
    /// server names a small Retry-After), extraction, quality gate + repair.
    private func attempt(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        system: String,
        messages: [CoachMessage],
        quoteGuard: CoachChatQuoteGuardContext,
        latestUserTurn: String?
    ) async -> AttemptOutcome {
        let startedAt = Date()
        do {
            Self.log.debug("attempting chat provider \(provider.displayName, privacy: .public)")
            let body = chatRequestBody(for: provider, system: system, messages: messages)
            var result = try await providerHTTP(provider: provider, endpoint: endpoint, key: key, body: body)

            // One in-call retry when the refusal is explicitly short-lived
            // (429/503/529 with Retry-After within the turn's latency budget).
            if case .refused(let status, let retryAfter) = result,
               [429, 503, 529].contains(status),
               let delay = retryAfter, delay > 0, delay <= 4 {
                Self.log.info("\(provider.displayName, privacy: .public) \(status) — retrying after \(delay, format: .fixed(precision: 1))s")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                result = try await providerHTTP(provider: provider, endpoint: endpoint, key: key, body: body)
            }

            switch result {
            case .refused(let status, _):
                Self.log.error("\(provider.displayName, privacy: .public) refused: HTTP \(status)")
                recordChatDiagnostic(
                    .fallback,
                    "Provider refused: HTTP \(status)",
                    provider: provider,
                    statusCode: status,
                    startedAt: startedAt
                )
                return .refused(.classify(status: status))
            case .success(let data):
                let extraction = Self.chatExtractReplyText(from: data, provider: provider)
                switch extraction {
                case .text(let text):
                    let display = CoachReplyTextSanitizer.displayText(from: text)
                    guard !display.isEmpty else {
                        Self.log.error("\(provider.displayName, privacy: .public) reply normalized to empty text")
                        recordChatDiagnostic(.fallback, "Reply normalized to empty", provider: provider)
                        return .refused(.transient)
                    }
                    if display != text.trimmingCharacters(in: .whitespacesAndNewlines) {
                        Self.log.notice("\(provider.displayName, privacy: .public) reply normalized before storage and speech")
                    }
                    if let issue = Self.replyQualityIssue(
                        in: display,
                        latestUserTurn: latestUserTurn,
                        quoteGuard: quoteGuard,
                        systemContext: system
                    ) {
                        Self.log.notice("\(provider.displayName, privacy: .public) reply tripped quality gate (\(String(describing: issue), privacy: .public)) — repairing")
                        if let repaired = await repairLowQualityReply(
                            issue: issue,
                            draft: display,
                            provider: provider,
                            endpoint: endpoint,
                            key: key,
                            system: system,
                            messages: messages,
                            quoteGuard: quoteGuard
                        ) {
                            recordChatDiagnostic(.success, "Repair reply accepted", provider: provider)
                            return .reply(repaired)
                        }
                        // A content miss by this model on this turn — let the
                        // next provider in the chain take the question.
                        recordChatDiagnostic(
                            .fallback,
                            "Reply failed professional-coach gate: \(String(describing: issue))\(Self.liveEvalDraftSuffix(display))",
                            provider: provider
                        )
                        return .refused(.contentRejected)
                    }
                    let normalized = CoachReplyTextSanitizer.coachReplyText(from: display)
                    guard !normalized.isEmpty else {
                        Self.log.error("\(provider.displayName, privacy: .public) reply scaffold normalized to empty text")
                        recordChatDiagnostic(.fallback, "Reply scaffold normalized to empty", provider: provider)
                        return .refused(.transient)
                    }
                    recordChatDiagnostic(.success, "Reply accepted", provider: provider)
                    return .reply(normalized)
                case .empty, .lengthTruncated:
                    Self.log.error("\(provider.displayName, privacy: .public) returned no usable text (\(extraction == .lengthTruncated ? "truncated" : "empty", privacy: .public))")
                    recordChatDiagnostic(
                        .fallback,
                        extraction == .lengthTruncated ? "Reply length-truncated" : "Missing response content",
                        provider: provider
                    )
                    return .refused(.transient)
                }
            }
        } catch {
            let nsError = error as NSError
            Self.log.error("\(provider.displayName, privacy: .public) transport failure: \(error.localizedDescription, privacy: .public)")
            recordChatDiagnostic(
                .failure,
                "Transport failure: \(nsError.domain) \(nsError.code)",
                provider: provider,
                startedAt: startedAt
            )
            return .refused(.transient)
        }
    }

    // MARK: - Live reply quality gate

    /// Conservative post-generation gate for live Ask-Noum replies. A draft
    /// that trips this is not "a little imperfect"; it is the kind of response
    /// that makes the coach feel like a generic AI wrapper.
    nonisolated static func replyQualityIssue(in text: String) -> CoachChatReplyQualityIssue? {
        replyQualityIssue(in: text, latestUserTurn: nil)
    }

    /// Turn-aware variant of the live reply gate. The no-context gate catches
    /// obvious global failures; this layer catches replies that are plausible
    /// in isolation but wrong for the user's actual turn.
    nonisolated static func replyQualityIssue(
        in text: String,
        latestUserTurn: String?,
        quoteGuard: CoachChatQuoteGuardContext? = nil,
        systemContext: String? = nil
    ) -> CoachChatReplyQualityIssue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if let quoteGuard,
           Self.containsUnverifiedQuotedUserSpeech(in: trimmed, quoteGuard: quoteGuard) {
            return .unverifiedQuotedUserSpeech
        }
        // Gate 1 of the dual gate (presence — mirrors the post-rep note's
        // `engagesTranscript` check): a reply that claims a read of the
        // user's words WITHOUT quoting ("your opening buried the lede...")
        // must still touch a known source. Quote-free fabrication is the
        // gap Gate 2 cannot see.
        if let quoteGuard,
           Self.claimsVerbatimRead(in: trimmed),
           !quoteGuard.engagesAnySource(trimmed) {
            return .unengagedUserSpeechClaim
        }

        if lower.hasPrefix("understood.")
            || lower.hasPrefix("understood,")
            || lower.hasPrefix("understood ") {
            return .roboticPhrase("understood")
        }

        if let phrase = roboticPhrases.first(where: { lower.contains($0) }) {
            return .roboticPhrase(phrase)
        }

        if replyUsesCoachScaffoldLabel(trimmed) {
            return .scaffoldLabel
        }

        let expandedAnswer = turnRequestsExpandedAnswer(latestUserTurn)
        let maxCharacters = expandedAnswer ? 680 : 420
        let maxSentences = expandedAnswer ? 7 : 4
        let maxWords = expandedAnswer ? 150 : 85
        let maxLines = expandedAnswer ? 9 : 5
        if trimmed.count > maxCharacters
            || sentenceCount(in: trimmed) > maxSentences
            || wordCount(in: trimmed) > maxWords
            || nonEmptyLineCount(in: trimmed) > maxLines {
            return .tooLong
        }

        if (lower.contains("can you clarify") || lower.contains("could you clarify")
            || lower.contains("please clarify") || lower.contains("what do you mean"))
            && wordCount(in: lower) <= 18 {
            return .bareClarification
        }

        if lower.contains("the app is designed")
            || lower.contains("the system is designed")
            || lower.contains("as an ai")
            || lower.contains("i am just")
            || lower.contains("i'm just") {
            return .defensiveProductLanguage
        }

        if replyUsesUnhelpfulRepDate(lower) {
            return .unanchoredCoaching
        }

        if replyClaimsNoUsableRecentEvidenceDespiteContext(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .unanchoredCoaching
        }

        if replyAddsColdStartIntakeQuestion(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .menuInsteadOfDecision
        }

        if let quoteGuard,
           replyContradictsRecommendationPosition(lower, quoteGuard: quoteGuard) {
            return .overclaimsEvidence
        }
        if let quoteGuard,
           replyContradictsLateRecommendationEvidence(lower, quoteGuard: quoteGuard) {
            return .overclaimsEvidence
        }

        if lower.contains("which direction would you prefer")
            || lower.contains("what is your priority")
            || (lower.contains("we can ") && lower.contains(" or ") && lower.contains("?")) {
            return .menuInsteadOfDecision
        }

        if trustRepairLacksUserPracticeMove(lower, latestUserTurn: latestUserTurn) {
            return .missingPrescribedAction
        }

        if turnAsksWhyAnswerLandedBadly(latestUserTurn),
           !replyExplainsWhyAnswerLanded(lower) {
            return .missingInsightBridge
        }

        if replyUsesUnrequestedNamedTechnique(lower, latestUserTurn: latestUserTurn) {
            return .unrequestedNamedTechnique
        }

        if replyIgnoresRetrievedCoachingExpertise(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .ignoredCoachingExpertise
        }

        let rubric = professionalCoachRubric(reply: trimmed, latestUserTurn: latestUserTurn)
        if rubric.misses.contains(.missedTrustRepair) {
            return .missedTrustRepair
        }
        if rubric.misses.contains(.overclaimsEvidence) {
            return .overclaimsEvidence
        }
        if rubric.misses.contains(.missingPrescribedAction),
           turnExpectsPrescribedAction(latestUserTurn) || rubric.score <= 6 {
            return .missingPrescribedAction
        }
        if rubric.misses.contains(.missingInsightBridge),
           turnExpectsCoaching(latestUserTurn) || rubric.score <= 6 {
            return .missingInsightBridge
        }
        if rubric.misses.contains(.missingObservableAnchor),
           turnExpectsCoaching(latestUserTurn) || rubric.score <= 6 {
            return .unanchoredCoaching
        }

        if replyShouldCiteRecentSession(systemContext),
           turnExpectsCoaching(latestUserTurn),
           !replyCitesRecentSessionAnchor(lower) {
            return .unanchoredCoaching
        }

        return nil
    }

    /// Score a reply against the minimum shape a senior communications coach
    /// would normally provide in text mode: brief, attuned, evidence-aware,
    /// specific, action-oriented, and humble about thin data. It is deliberately
    /// conservative and lexical; nuanced calibration still needs a future
    /// expert-eval fixture set, but this catches the generic-AI failure mode
    /// reliably enough to protect the live chat surface.
    nonisolated static func professionalCoachRubric(
        reply: String,
        latestUserTurn: String? = nil
    ) -> CoachChatProfessionalRubricResult {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CoachChatProfessionalRubricResult(score: 0, misses: [
                .missingObservableAnchor,
                .missingPrescribedAction
            ])
        }

        let lower = trimmed.lowercased()
        let latestLower = latestUserTurn?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        var score = 10
        var misses: [CoachChatProfessionalRubricMiss] = []

        func apply(_ miss: CoachChatProfessionalRubricMiss, penalty: Int) {
            if !misses.contains(miss) {
                misses.append(miss)
                score -= penalty
            }
        }

        let expandedAnswer = turnRequestsExpandedAnswer(latestUserTurn)
        let maxCharacters = expandedAnswer ? 680 : 420
        let maxSentences = expandedAnswer ? 7 : 4
        let maxWords = expandedAnswer ? 150 : 85
        let maxLines = expandedAnswer ? 9 : 5
        if trimmed.count > maxCharacters
            || sentenceCount(in: trimmed) > maxSentences
            || wordCount(in: trimmed) > maxWords
            || nonEmptyLineCount(in: trimmed) > maxLines {
            apply(.overlong, penalty: 2)
        }

        if roboticPhrases.contains(where: { lower.contains($0) })
            || defensiveProductPhrases.contains(where: { lower.contains($0) }) {
            apply(.roboticRegister, penalty: 2)
        }

        if replyOffersMenu(lower) {
            apply(.menuInsteadOfDecision, penalty: 2)
        }

        if isCritiqueTurn(latestLower), !replyRepairsTrust(lower) {
            apply(.missedTrustRepair, penalty: 3)
        }

        if turnExpectsCoaching(latestUserTurn), !replyHasObservableAnchor(lower) {
            apply(.missingObservableAnchor, penalty: 2)
        }

        if turnExpectsPrescribedAction(latestUserTurn), !replyPrescribesAction(lower) {
            apply(.missingPrescribedAction, penalty: 2)
        }

        if turnExpectsCoaching(latestUserTurn),
           !expandedAnswer,
           replyHasObservableAnchor(lower),
           replyPrescribesAction(lower),
           !replyHasInsightBridge(lower) {
            apply(.missingInsightBridge, penalty: 2)
        }

        if replyOverclaimsEvidence(lower) {
            apply(.overclaimsEvidence, penalty: 3)
        }

        return CoachChatProfessionalRubricResult(
            score: max(0, min(10, score)),
            misses: misses
        )
    }

    /// Internal (not private): `CoachContextBuilder.systemPrompt` folds this
    /// SAME list into the prompt's hard-ban line, so the model is told every
    /// phrase the gate will reject — the two can never silently drift apart.
    nonisolated static let roboticPhrases = [
        "based on your data",
        "the key insight is",
        "concrete next move",
        "this indicates",
        "recent reps show",
        "scores are down",
        "let's",
        "let us",
        "as an ai",
        "as your ai",
        "optimize your",
        "utilize",
        "i understand your frustration",
        "here are some tips",
        "here are a few tips",
        "it's important to",
        "it is important to",
        "in order to improve",
        "to break this",
        "effective communication",
        "to communicate more clearly",
        "be clear and concise",
        "try to be more confident",
        "retrieval load",
        "chosen profile",
        "profile yet",
        "since we do not have",
        "since we don't have",
        "i don't have rated sessions",
        "i do not have rated sessions",
        "no rated sessions yet",
        "we do not have any rated sessions",
        "we don't have any rated sessions",
        "do not have any rated sessions yet",
        "removes the reason",
        "give yourself room to find",
        "before the gap turns into",
        "reads as command",
        "looks like control",
        "leaks uncertainty",
        "a senior room wants",
        "senior room wants",
        "in my response",
        "system symbols",
        "stripping out",
        "i'm dropping",
        "i am dropping",
        "we're dropping",
        "we are dropping",
        "dropping both now",
        "we are shifting",
        "we're shifting",
        "i am shifting",
        "i'm shifting",
        "the coaching shifts",
        "coaching shifts now",
        "from here the coaching",
        "from this rep forward",
        "the coaching drops",
        "coaching drops the",
        "the coaching will",
        "coaching that sounds like a person",
        "report-voice",
        "speaks to you directly",
        "nothing templated",
        "generic tip-giving",
        "i'll cut the markers",
        "i will cut the markers",
        "cut the markers and the report voice",
        "you are right to call that out, as",
        "i am cutting the",
        "i'm cutting the",
        "i will cut the report voice",
        "i'll cut the report voice",
        "i will cut the robotic report voice",
        "i'll cut the robotic report voice",
        "you are right to call that out",
        "you're right to call that out",
        "your brain",
        "brain was searching",
        "searching for the next word",
        "close your mouth",
        "closing your mouth",
        "close your lips",
        "closing your lips",
        "go to the practice tab",
        "open the practice tab",
        "tap the practice tab",
        "use the practice screen",
        "go to the practice screen",
        "open the practice screen"
    ]

    private nonisolated static let defensiveProductPhrases = [
        "the app is designed",
        "the system is designed",
        "i am just",
        "i'm just"
    ]

    private nonisolated static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private nonisolated static func isCritiqueTurn(_ lower: String) -> Bool {
        containsAny(lower, [
            "robotic", "generic", "not ideal", "not a fan", "no where near",
            "nowhere near", "annoy", "frustrat", "sucks", "poop",
            "not human", "doesn't feel", "does not feel", "too much writing",
            "too long", "shorter", "less writing", "less text",
            "straight to the point", "straight to point", "get to the point",
            "hardcoded", "low eq", "not high eq",
            "why can't", "why can’t", "why cannot",
            "couldn't shape", "couldn’t shape", "shape a useful answer"
        ]) || turnRequestsShortness(lower)
            || turnCritiquesCoachOverexplaining(lower)
    }

    private nonisolated static func turnRequestsExpandedAnswer(_ turn: String?) -> Bool {
        guard let lower = turn?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !lower.isEmpty else { return false }
        guard !turnRequestsShortness(lower) else { return false }
        return containsAny(lower, [
            "plan", "full", "breakdown", "detail", "explain", "list",
            "7-day", "7 day", "week", "roadmap", "step by step"
        ])
    }

    private nonisolated static func turnRequestsNamedTechnique(_ turn: String?) -> Bool {
        guard let lower = turn?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !lower.isEmpty else { return false }
        if containsAny(lower, [
            "don't name", "do not name", "without naming", "no drill name",
            "not a drill name", "plain action"
        ]) {
            return false
        }
        return containsAny(lower, [
            "drill", "framework", "method", "technique", "exercise",
            "what is it called", "what's it called", "name it", "name the",
            "pyramid", "star"
        ])
    }

    private nonisolated static func replyUsesCoachScaffoldLabel(_ text: String) -> Bool {
        let display = CoachReplyTextSanitizer.displayText(from: text)
        guard !display.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let labels = CoachReplyTextSanitizer.coachScaffoldLeadInPattern
        let linePattern = #"(?im)^\s*(?:[-*+•]\s*|\d+[.)]\s*)?(?:"# + labels + #"):\s*"#
        let inlinePattern = #"(?i)(?:[.!?]\s+|\s+[—-]\s+)(?:"# + labels + #"):\s*"#

        return [linePattern, inlinePattern].contains { pattern in
            (try? NSRegularExpression(pattern: pattern))?
                .firstMatch(
                    in: display,
                    range: NSRange(display.startIndex..., in: display)
                ) != nil
        }
    }

    private nonisolated static let directnessRequestPhrases = [
        "be direct", "direct with me", "give it to me straight",
        "tell me straight", "keep it direct"
    ]

    private nonisolated static func turnRequestsDirectness(_ lower: String) -> Bool {
        containsAny(lower, directnessRequestPhrases)
    }

    private nonisolated static func turnRequestsShortness(_ lower: String) -> Bool {
        turnRequestsDirectness(lower) || containsAny(lower, [
            "keep it short", "keep this short", "make it short", "shorter",
            "too much writing", "too long", "less writing", "less text",
            "straight to the point", "straight to point", "get to the point",
            "to the point", "brief", "concise", "one sentence"
        ])
    }

    private nonisolated static func turnCritiquesCoachOverexplaining(_ lower: String) -> Bool {
        guard containsAny(lower, [
            "stop overexplaining", "stop over explaining",
            "you overexplain", "you over-explain", "you are overexplaining",
            "you're overexplaining", "you’re overexplaining",
            "your reply overexplained", "your answer overexplained"
        ]) else {
            return false
        }

        return !containsAny(lower, [
            "i overexplain", "i over-explain", "i over explain",
            "i keep overexplaining", "i keep over-explaining", "i keep over explaining",
            "when i overexplain", "when i over-explain", "when i over explain",
            "because i overexplain", "because i over-explain", "because i over explain"
        ])
    }

    private nonisolated static func turnExpectsCoaching(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return true }
        let lower = latestUserTurn.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return true }
        if lower.count <= 4 && containsAny(lower, ["hi", "hey", "yo"]) { return false }
        return true
    }

    private nonisolated static func turnExpectsPrescribedAction(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return true }
        let lower = latestUserTurn.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.count <= 4 && containsAny(lower, ["hi", "hey", "yo"]) { return false }
        return containsAny(lower, [
            "what next", "next move", "what should", "continue", "implement",
            "develop", "work on", "focus", "how do i", "help me", "coach me",
            "practice", "prepare", "fix", "improve", "replace", "go for",
            "make a bigger stride"
        ]) || isCritiqueTurn(lower)
    }

    private nonisolated static func turnAsksWhyAnswerLandedBadly(_ turn: String?) -> Bool {
        guard let lower = turn?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              lower.contains("why") else {
            return false
        }
        return containsAny(lower, [
            "landed badly", "land badly", "landed bad", "did not land",
            "didn't land", "didn’t land", "not land", "not work",
            "did not work", "didn't work", "didn’t work",
            "fell flat", "missed", "came across wrong"
        ])
    }

    private nonisolated static func trustRepairLacksUserPracticeMove(
        _ lower: String,
        latestUserTurn: String?
    ) -> Bool {
        guard isCritiqueTurn(latestUserTurn?.lowercased() ?? ""),
              replyRepairsTrust(lower),
              !replyHasUserPracticeMove(lower) else {
            return false
        }
        return containsAny(lower, [
            "i'll ", "i will ", "i’m ", "i'm ", "i am ",
            "we'll ", "we will ", "we're ", "we are ",
            "my reply", "my response", "next replies", "future replies",
            "the reply", "the response", "the coaching", "plain text",
            "shorter", "warmer", "more direct", "less robotic",
            "formatting", "symbols", "tts", "report"
        ])
    }

    private nonisolated static func replyHasUserPracticeMove(_ lower: String) -> Bool {
        containsAny(lower, [
            "say ", "run ", "record", "hold ", "state ", "state the",
            "lead with", "put the", "give one", "give a ", "answer ",
            "practice", "review", "repeat", "pause before", "add one",
            "add a ", "end with", "end the", "end it", "stop there",
            "cut the hedge", "cut that hedge", "make the ask",
            "make your ask", "make the decision", "ask for",
            "write one", "send one", "speak "
        ])
    }

    private nonisolated static func replyRepairsTrust(_ lower: String) -> Bool {
        containsAny(lower, [
            "fair", "you're right", "you are right", "good call", "useful push",
            "that read", "that felt", "the friction", "too generic", "too robotic",
            "right to call", "that should not", "that shouldn't", "should not happen",
            "shouldn't happen", "that was advice", "that was generic", "that was cold",
            "markup read", "tts read", "read aloud", "overexplained",
            "formatting", "markdown", "symbols",
            "i'll be", "i will be", "i'll keep", "i will keep", "i'll change",
            "i will change", "i'll cut", "i will cut", "i'll stop", "i will stop"
        ])
    }

    private nonisolated static func replyHasObservableAnchor(_ lower: String) -> Bool {
        if lower.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        return containsAny(lower, [
            "last rep", "recent rep", "next rep", "session", "transcript",
            "filler", "pace", "pause", "score", "wpm", "word choice",
            "you said", "you asked", "i heard", "what i notice", "pattern",
            "case", "hypothesis", "target", "success measure", "not enough data",
            "baseline",
            "i don't have", "i do not have", "i can't see", "from what you wrote",
            "your message", "your words", "the friction", "the claim was there",
            "no reason followed", "bare claim", "the rep led", "formatting",
            "markdown", "tts", "symbols"
        ])
    }

    private nonisolated static func replyShouldCiteRecentSession(_ systemContext: String?) -> Bool {
        guard let lower = systemContext?.lowercased() else { return false }
        return lower.contains("recent (most-recent first)")
            || lower.contains("most-recent first")
    }

    private nonisolated static func replyCitesRecentSessionAnchor(_ lower: String) -> Bool {
        if lower.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        return containsAny(lower, [
            "last rep", "recent rep", "latest rep", "last session",
            "recent session", "rated session", "your timed rep",
            "your rep", "the transcript", "your transcript"
        ])
    }

    private nonisolated static func replyUsesUnhelpfulRepDate(_ lower: String) -> Bool {
        guard containsAny(lower, [" rep", "session", "practice"]) else { return false }
        return containsAny(lower, [
            "january", "february", "march", "april", "may ", "june",
            "july", "august", "september", "october", "november", "december"
        ])
    }

    private nonisolated static func replyPrescribesAction(_ lower: String) -> Bool {
        containsAny(lower, [
            "next rep", "try ", "practice", "run ", "hold ", "record",
            "answer", "send", "say ", "use ", "repeat", "do one", "focus",
            "start", "ask ", "replace", "add one", "add a ", "keep the ", "keep this ", "cut ",
            "pause before", "one drill", "one rep", "review", "speak ",
            "end your", "state your", "state the", "make the", "make your", "lead with",
            "put the", "give one", "end the", "end it", "end with",
            "stop there", "then stop"
        ])
    }

    private nonisolated static func replyExplainsWhyAnswerLanded(_ lower: String) -> Bool {
        containsAny(lower, [
            "recommendation arrived late",
            "recommendation came late",
            "recommendation landed late",
            "decision arrived late",
            "decision came late",
            "point arrived late",
            "point came late",
            "buried the recommendation",
            "buried your recommendation",
            "buried the decision",
            "buried your decision",
            "too much context",
            "context came first",
            "setup came first",
            "no reason followed",
            "without giving a reason",
            "without a reason",
            "no implication",
            "without an implication",
            "bare claim",
            "unsupported claim",
            "asserted the claim",
            "sounded like an opinion",
            "risked sounding like an opinion",
            "close softened",
            "ending softened",
            "trailed off",
            "missing ask",
            "ask was missing",
            "hedge softened",
            "hedged the close"
        ])
    }

    private nonisolated static func replyHasInsightBridge(_ lower: String) -> Bool {
        containsAny(lower, [
            " so ", " because ", " therefore ", " which is why",
            "that is why", "that's why", "that’s why", "that tests",
            "tests whether", "tests if", "the pattern", "the signal",
            "useful signal", "enough signal", "pressure cue", "the read",
            "the move is", "the fix is", "the point arrived late",
            "arrived late", "showing up", "carried", "softened", "held",
            "light on", "not a summary", "not abandoning", "worth varying",
            "hypothesis", "moved alongside", "trended down alongside",
            "the gap", "what broke", "what held"
        ])
    }

    private nonisolated static func replyOverclaimsEvidence(_ lower: String) -> Bool {
        if containsAny(lower, [
            "this proves", "the data proves", "definitely means",
            "always do this", "you lack conviction", "you are weak",
            "never led with the point", "never led with your point",
            "never led with the recommendation",
            "never led with your recommendation"
        ]) {
            return true
        }
        if containsAny(lower, [
            "guarantees", "guarantee that", "will ensure", "ensures that",
            "automatically improves", "automatically reduces",
            "naturally drops", "naturally reduces", "will drop your pace",
            "will reduce your fillers", "will make you sound",
            "stops the filler", "stops fillers", "stops filler words",
            "will stop the filler", "will stop fillers", "will stop filler words"
        ]) {
            return true
        }
        if lower.contains("will make"),
           containsAny(lower, [
            " stick", " land", " clearer", " stronger",
            " more authoritative", " more confident", " sound"
           ]) {
            return true
        }
        if containsAny(lower, [
            "fillers because", "filler because", "filler words because",
            "fillers came because", "filler came because",
            "fillers happened because", "filler happened because"
        ]) {
            return true
        }
        if containsAny(lower, [
            "what brings out the um", "brings out the um",
            "what brings out the filler", "brings out the filler",
            "rush to fill silence"
        ]) {
            return true
        }
        if lower.contains("fillers"),
           lower.contains(" because "),
           containsAny(lower, [
            "point did not", "point didn't", "did not clearly lead",
            "didn't clearly lead", "recommendation", "structure", "opening",
            "next word was not ready", "next word wasn't ready",
            "next word is not ready", "next word isn't ready",
            "the next word was not", "the next word wasn't"
           ]) {
            return true
        }
        if containsAny(lower, [
            "you signal that you", "you signal you", "you actually signal",
            "you are signaling that", "you're signaling that", "you’re signaling that",
            "this signals that you", "this invites the", "this invites challenges",
            "silence forces", "silence reads as", "that silence reads",
            "reads as composure", "this forces stakeholders", "stakeholders will think",
            "stakeholders will assume", "stakeholders will see", "listeners will think",
            "listeners will assume", "audience will think", "audience will assume",
            "they will think", "they will assume", "defending a weak position",
            "forces you to", "force you to"
        ]) {
            return true
        }
        let sensitiveLabels = ["evasive", "timid", "detached", "defensive", "insecure"]
        if containsAny(lower, sensitiveLabels),
           containsAny(lower, ["clearly", "obviously", "you are ", "you’re "]) {
            return true
        }
        return false
    }

    private nonisolated static func replyContradictsRecommendationPosition(
        _ lower: String,
        quoteGuard: CoachChatQuoteGuardContext
    ) -> Bool {
        guard containsAny(lower, [
            "buried the recommendation",
            "recommendation was buried",
            "recommendation is buried",
            "recommendation at the end",
            "recommendation came at the end",
            "recommendation landed at the end",
            "point didn't lead",
            "point did not lead",
            "main point didn't lead",
            "main point did not lead",
            "point arrived late",
            "main point arrived late",
            "point landed late",
            "main point landed late",
            "recommendation didn't lead",
            "recommendation did not lead"
        ]) else {
            return false
        }

        return quoteGuard.sourceTexts.contains { source in
            let sourceLower = source.lowercased()
            guard let range = sourceLower.range(of: "recommendation") else {
                return false
            }
            let offset = sourceLower.distance(from: sourceLower.startIndex, to: range.lowerBound)
            return offset <= max(32, sourceLower.count / 3)
        }
    }

    private nonisolated static func replyContradictsLateRecommendationEvidence(
        _ lower: String,
        quoteGuard: CoachChatQuoteGuardContext
    ) -> Bool {
        guard containsAny(lower, [
            "your last rep led with the point",
            "last rep led with the point",
            "the last rep led with the point",
            "your last rep led with the recommendation",
            "last rep led with the recommendation",
            "the last rep led with the recommendation",
            "your last rep led with the decision",
            "last rep led with the decision",
            "you led with the point",
            "you led with the recommendation",
            "you led with the decision",
            "you opened with the point",
            "you opened with the recommendation",
            "you opened with the decision",
            "the point was up front",
            "the recommendation was up front",
            "the decision was up front",
            "point right up front",
            "recommendation right up front",
            "decision right up front",
            "put the point right up front",
            "put the recommendation right up front",
            "put the decision right up front",
            "your opening led with the point",
            "your opening led with the recommendation"
        ]) else {
            return false
        }

        return quoteGuard.sourceTexts.contains { source in
            sourceMentionsLateRecommendation(source)
        }
    }

    private nonisolated static func sourceMentionsLateRecommendation(_ text: String) -> Bool {
        CoachContextBuilder.transcriptMentionsLateRecommendation(text)
    }

    private nonisolated static func replyClaimsNoUsableRecentEvidenceDespiteContext(
        _ lower: String,
        latestUserTurn: String?,
        systemContext: String?
    ) -> Bool {
        guard replyShouldCiteRecentSession(systemContext),
              isCritiqueTurn(latestUserTurn?.lowercased() ?? "") else {
            return false
        }
        return containsAny(lower, [
            "i don't have enough reps",
            "i do not have enough reps",
            "not enough reps",
            "don't have enough reps",
            "do not have enough reps",
            "i don't have enough sessions",
            "i do not have enough sessions",
            "not enough sessions",
            "i don't have enough data",
            "i do not have enough data",
            "not enough data yet"
        ])
    }

    private nonisolated static func replyAddsColdStartIntakeQuestion(
        _ lower: String,
        latestUserTurn: String?,
        systemContext: String?
    ) -> Bool {
        guard let context = systemContext?.lowercased(),
              containsAny(context, [
                "no rated sessions yet",
                "not enough data for a stable baseline yet",
                "personalization floor: no rated sessions yet",
                "no voice set yet"
              ]) else {
            return false
        }
        guard containsAny(latestUserTurn?.lowercased() ?? "", [
            "interview", "presentation", "update", "pitch", "meeting",
            "get better", "improve", "practice", "prepare"
        ]) else {
            return false
        }
        guard lower.contains("?") else { return false }
        return containsAny(lower, [
            "what's the interview for",
            "what is the interview for",
            "what role",
            "what job",
            "which interview",
            "tell me more",
            "what are you preparing for",
            "what situation",
            "what kind of"
        ])
    }

    private nonisolated static func replyUsesUnrequestedNamedTechnique(
        _ lower: String,
        latestUserTurn: String?
    ) -> Bool {
        guard turnExpectsPrescribedAction(latestUserTurn),
              !turnRequestsExpandedAnswer(latestUserTurn),
              !turnRequestsNamedTechnique(latestUserTurn) else {
            return false
        }
        if containsAny(lower, [
            "pyramid drill", "pyramid-drill", "star drill",
            "star method drill", "answer-first drill", "bottom-line drill",
            "bottom line drill"
        ]) {
            return true
        }
        let pattern = #"\b(try|run|do|use|practice)\s+(the\s+)?([a-z][a-z-]*(\s+[a-z][a-z-]*){0,3})\s+(drill|framework|method|exercise)\b"#
        return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?
            .firstMatch(
                in: lower,
                range: NSRange(lower.startIndex..., in: lower)
            ) != nil
    }

    private nonisolated static func replyIgnoresRetrievedCoachingExpertise(
        _ lower: String,
        latestUserTurn: String?,
        systemContext: String?
    ) -> Bool {
        guard let turn = latestUserTurn?.trimmingCharacters(in: .whitespacesAndNewlines),
              KnowledgeRetriever.isTechniqueSeekingTurn(turn),
              replyPrescribesAction(lower),
              let systemContext else {
            return false
        }

        let anchors = retrievedCoachingExpertiseAnchorTokens(from: systemContext)
        guard !anchors.isEmpty else { return false }

        let replyTokens = Set(
            KnowledgeRetriever.tokenize(lower)
                .map(KnowledgeRetriever.stem)
                .filter { !retrievedExpertiseStopTokens.contains($0) }
        )
        return anchors.isDisjoint(with: replyTokens)
    }

    nonisolated static func retrievedCoachingExpertiseAnchorTokens(from systemContext: String) -> Set<String> {
        var inExpertiseSection = false
        var tokens = Set<String>()

        for rawLine in systemContext.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = line.lowercased()
            if lower.hasPrefix("coaching expertise") {
                inExpertiseSection = true
                continue
            }
            guard inExpertiseSection else { continue }
            if line.isEmpty || line.hasPrefix("===") {
                break
            }
            guard line.hasPrefix("-") else { continue }
            for token in KnowledgeRetriever.tokenize(line).map(KnowledgeRetriever.stem) {
                guard token.count >= 4,
                      !retrievedExpertiseStopTokens.contains(token) else {
                    continue
                }
                tokens.insert(token)
            }
        }

        return tokens
    }

    private nonisolated static let retrievedExpertiseStopTokens: Set<String> = [
        "about", "above", "after", "again", "also", "apply", "around",
        "because", "before", "being", "card", "coach", "coaching",
        "communicate", "communication", "context", "craft", "curated",
        "data", "domain", "evidence", "expertise", "filler", "fillers",
        "ground", "guidance", "language", "marker", "model", "move",
        "practice", "prescribe", "prescribed", "reply", "speaker",
        "speaking", "success", "technique", "their", "there", "these",
        "this", "those", "turn", "user", "using", "voice", "when",
        "where", "which", "while", "with", "word", "work", "working",
        "your"
    ]

    /// Attribution phrases that may precede a QUOTED fragment. BROAD set, used
    /// by Gate 2: if any quoted text follows one of these and isn't verified
    /// against a source, it's a fabricated quote. Includes topic-reference
    /// verbs ("you mentioned/described/talked about/argued") because a
    /// fabricated quote after those is just as bad.
    private nonisolated static let userSpeechAttributionPhrases = [
        "you said", "you used", "your words", "your phrase",
        "you put it", "your line", "you opened with", "your opening line",
        "you closed with", "your closing line", "you mentioned",
        "you talked about", "you described", "you argued",
        "your exact words", "your phrasing", "your wording"
    ]

    /// VERBATIM-claim subset, used by Gate 1 (the no-quote presence check). A
    /// reply that claims to read the user's actual WORDS without quoting must
    /// engage a known source. Topic-reference verbs ("you mentioned the board
    /// meeting", "you described the standup") are deliberately EXCLUDED: the
    /// coach legitimately knows topics from the case file / BigMoment / standing
    /// plan — content the quote-guard's transcript sources don't contain — so
    /// gating those produced false `.unengagedUserSpeechClaim` trips on exactly
    /// the grounded intelligence the recent COACH-* work surfaces.
    private nonisolated static let verbatimReadPhrases = [
        "you said", "you used", "your words", "your phrase",
        "you put it", "your line", "you opened with", "your opening line",
        "you closed with", "your closing line",
        "your exact words", "your phrasing", "your wording"
    ]

    /// True when the text claims to read the user's actual words (as opposed
    /// to citing a metric or prescribing a move). Pure + lexical, exposed for
    /// tests alongside the dual gate it scopes. BROAD — scopes Gate 2.
    nonisolated static func claimsUserSpeechRead(in text: String) -> Bool {
        containsAny(text.lowercased(), userSpeechAttributionPhrases)
    }

    /// True when the text claims a VERBATIM read of the user's words. NARROW —
    /// scopes Gate 1 so topic references to case-file content don't false-trip.
    nonisolated static func claimsVerbatimRead(in text: String) -> Bool {
        containsAny(text.lowercased(), verbatimReadPhrases)
    }

    nonisolated static func containsUnverifiedQuotedUserSpeech(
        in text: String,
        quoteGuard: CoachChatQuoteGuardContext
    ) -> Bool {
        guard claimsUserSpeechRead(in: text) else { return false }

        return quotedFragments(in: text).contains { quote in
            !quoteGuard.verifies(quote)
        }
    }

    nonisolated static func quotedFragments(in text: String) -> [String] {
        let patterns = [
            "\"([^\"]{3,180})\"",
            // Straight single quote shares its glyph (U+0027) with the English
            // contraction apostrophe (you're, I'd, can't). Without boundaries,
            // a reply with two contractions captures the text BETWEEN them as a
            // bogus "quote" ("re rushing the close, so I" from "you're rushing
            // the close, so I'd hold"), which then fails Gate 2 and kills a
            // grounded reply. Require the opening/closing quote to sit on a
            // letter boundary: a contraction apostrophe is letter-flanked on
            // both sides, so it can no longer open or close a capture, while a
            // genuine 'quoted phrase' (space/punctuation-flanked) still matches.
            "(?<!\\p{L})'([^']{3,180})'(?!\\p{L})",
            "\u{201C}([^\u{201D}]{3,180})\u{201D}",
            "\u{2018}([^\u{2019}]{3,180})\u{2019}"
        ]
        let nsText = text as NSString
        var fragments: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(
                in: text,
                range: NSRange(location: 0, length: nsText.length)
            )
            fragments.append(contentsOf: matches.compactMap { match in
                guard match.numberOfRanges > 1 else { return nil }
                let raw = nsText.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return raw.isEmpty ? nil : raw
            })
        }
        return fragments
    }

    private nonisolated static func replyOffersMenu(_ lower: String) -> Bool {
        lower.contains("which direction would you prefer")
            || lower.contains("what is your priority")
            || (lower.contains("we can ") && lower.contains(" or ") && lower.contains("?"))
    }

    /// Abbreviations whose internal/trailing periods must NOT read as sentence
    /// terminators. These are common in coaching copy — the system prompt
    /// itself models "e.g." — and counting their periods inflated legal
    /// 2-sentence replies into a `.tooLong` trip. Erring permissive (a rare
    /// end-of-sentence "etc." may undercount by one) is the correct direction
    /// for a gate whose failure mode has been over-firing.
    private nonisolated static let sentenceCountAbbreviations = [
        "e.g.", "i.e.", "etc.", "vs.", "a.m.", "p.m.",
        "mr.", "mrs.", "ms.", "dr.", "u.s.", "ph.d.", "approx."
    ]

    private nonisolated static func sentenceCount(in text: String) -> Int {
        // Neutralize known abbreviations so their periods don't count.
        var scrubbed = text
        for abbr in sentenceCountAbbreviations {
            scrubbed = scrubbed.replacingOccurrences(
                of: abbr,
                with: abbr.replacingOccurrences(of: ".", with: ""),
                options: [.caseInsensitive]
            )
        }
        // Count runs of terminal punctuation (.!?) followed by whitespace or
        // end-of-text. Decimals in coaching stats ("3.5 fillers per rep") are
        // not followed by whitespace, so they never count.
        let endings = CharacterSet(charactersIn: ".!?")
        var count = 0
        var inRun = false
        for scalar in scrubbed.unicodeScalars {
            if endings.contains(scalar) {
                inRun = true
            } else {
                if inRun, CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    count += 1
                }
                inRun = false
            }
        }
        if inRun { count += 1 }
        return max(count, scrubbed.isEmpty ? 0 : 1)
    }

    private nonisolated static func wordCount(in text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber }.count
    }

    private nonisolated static func nonEmptyLineCount(in text: String) -> Int {
        text.split(separator: "\n").filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    private func repairLowQualityReply(
        issue: CoachChatReplyQualityIssue,
        draft: String,
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        system: String,
        messages: [CoachMessage],
        quoteGuard: CoachChatQuoteGuardContext?
    ) async -> String? {
        let requiredAnchor = Self.requiredRepairAnchor(
            issue: issue,
            latestUserTurn: messages.last(where: { $0.role == .user })?.text,
            system: system
        )
        let referenceShape = Self.repairReferenceShape(
            issue: issue,
            latestUserTurn: messages.last(where: { $0.role == .user })?.text,
            system: system
        )
        let repairSystem = """
        \(system)

        QUALITY REWRITE PASS
        The previous draft failed the Ask Noum professional-coach gate.
        Failure: \(issue.repairInstruction)

        Draft to replace:
        \(draft)

        Rewrite from scratch. Requirements:
        - Usually 1-2 short lines and under 50 words unless the user explicitly asked for a plan.
        - Use natural sentence starts, up to 3 bullets, or numbered steps only when they reduce reading.
        - Never output literal Markdown markers such as **, __, ###, or decorative formatting.
        - Do not label the reply with Read, Move, Target, Recommend, or Next rep.
        - Do not write "Next rep:" with a colon; write the action as a normal
          sentence.
        - Do not write "let's" or "let us". Start with the action instead: "Test this", "Use this", "Run one rep", "Say the recommendation first".
        - No long paragraph.
        - No broad menu. Pick one coaching move.
        \(requiredAnchor.map { "- Required anchor: \($0)" } ?? "")
        \(referenceShape.map { "- Expert reference shape: \($0)" } ?? "")
        - The final answer must include a direct action verb the user can do now
          or in the next rep: say, run, record, hold, cut, use, answer,
          practice, review, end, state, make, lead, put, or give.
        - For filler-word work, say "hold a silent beat" or "hold one second of
          silence"; never tell the user to close their mouth or lips.
        - Do not explain filler counts as caused by a separate structure read
          unless the context explicitly says that. Write "you had 6 fillers, so
          test a silent beat"; do not write "you had 6 fillers because the point
          did not lead."
        - Do not infer the user's hidden mental cause for fillers. Avoid lines
          like "because the next word was not ready." Use observable phrasing:
          "you had 6 fillers, so test a silent beat as the replacement."
        - Do not make absolute structure claims such as "never led with the
          point" unless the context explicitly says the point never appeared.
          Prefer the safer observable target: "the close softened", "the point
          arrived late", or "the final sentence needs the ask."
        - If the source transcript already opens with a recommendation, point,
          or decision, do not write "the point arrived late", "buried the
          recommendation", or similar. Use a safe anchor instead, such as the
          filler count, the exact transcript wording, or a missing
          reason/implication only when the context supports it.
        - If the source transcript says the user waited too long to state the
          recommendation, do not write "led with the point", "point was up
          front", or similar. Say the recommendation arrived late, then
          prescribe recommendation first plus one reason or implication.
        - Do not present silence as a guaranteed perception or outcome. Avoid
          "silence reads as composure" and "it stops the filler"; write "a
          silent beat can give you one deliberate next word."
        - Avoid stiff trust-repair narration such as "You are right to call that
          out, as...", "I am cutting the robotic report voice", "from here the
          coaching drops...", "from this rep forward...", or "we are dropping
          the metrics", or "the coaching shifts now". Prefer a human first
          sentence like "Fair push. That read too much like a report."
        - Avoid formal no-data openings such as "Since we do not have...".
          Prefer "No baseline yet, so start there."
        - On cold-start/no-baseline turns, prescribe one first rep before asking
          discovery questions. Avoid "What's the interview for?" in the same
          reply.
        - The final answer must contain the word "so" or "because" when it connects the anchor to the action.
        - When the user asks why an answer landed badly, start from the
          transcript or last rep before the prescription, for example "From the
          transcript..." or "In your last rep...".
        - When referencing a practice session, write "your last rep" or "a recent rep"; never write the exact calendar date.
        - If this is a trust-repair or critique turn, use exactly two sentences:
          first repair the specific friction in the user's terms (formatting,
          TTS, symbols, robotic, cold, generic), second cite one safe fact or
          honest data gap and use "so" or "because" to prescribe one changed
          move. Prefer the safest available anchor: a recent transcript pattern,
          a metric such as fillers or pace, or an honest data gap. If RECENT is
          present in context, do not claim there are no usable reps. Do not
          invent structural claims such as "buried the recommendation" unless
          the context explicitly says that happened. The
          second sentence still needs the action, for example: "Your last rep had
          4 fillers, so say the decision first, give one proof point, then stop."
        - Do not narrate your own response mechanics. Avoid assistant-style phrases
          such as "in my response", "system symbols", "generic tip-giving", or
          "stripping out"; own the friction briefly, then say the changed
          coaching move directly.
        - Do not name a drill/framework unless the user explicitly asked for a named drill or plan. Translate the technique into plain action.
        - If the user showed frustration, do not defend the app.
        - If the user asked for shortness, make the answer shorter before making it smarter.
        - Sound like a senior communications coach, not an assistant explaining itself.
        - Connect the evidence to the move with one coaching reason; do not just list a metric and a drill.
        """

        let body = chatRequestBody(
            for: provider,
            system: repairSystem,
            messages: messages,
            maxOutputTokens: Self.coachRepairMaxOutputTokens
        )
        guard
            let result = try? await providerHTTP(
                provider: provider,
                endpoint: endpoint,
                key: key,
                body: body
            ),
            case .success(let data) = result,
            case .text(let text) = Self.chatExtractReplyText(from: data, provider: provider)
        else {
            Self.log.error("repair pass got no usable text from \(provider.displayName, privacy: .public)")
            recordChatDiagnostic(.fallback, "Repair response missing content", provider: provider)
            return nil
        }
        let display = CoachReplyTextSanitizer.displayText(from: text)
        guard !display.isEmpty else {
            Self.log.error("repair pass normalized to empty text from \(provider.displayName, privacy: .public)")
            recordChatDiagnostic(.fallback, "Repair reply normalized to empty", provider: provider)
            return nil
        }
        if display != text.trimmingCharacters(in: .whitespacesAndNewlines) {
            Self.log.notice("repair pass normalized reply from \(provider.displayName, privacy: .public)")
        }
        if let remainingIssue = Self.replyQualityIssue(
            in: display,
            latestUserTurn: messages.last(where: { $0.role == .user })?.text,
            quoteGuard: quoteGuard,
            systemContext: system
        ) {
            Self.log.error("repair pass still tripped the gate (\(String(describing: remainingIssue), privacy: .public))")
            recordChatDiagnostic(
                .fallback,
                "Repair reply failed professional-coach gate: \(String(describing: remainingIssue))\(Self.liveEvalDraftSuffix(display))",
                provider: provider
            )
            return nil
        }
        let normalized = CoachReplyTextSanitizer.coachReplyText(from: display)
        guard !normalized.isEmpty else {
            Self.log.error("repair pass scaffold-normalized to empty text from \(provider.displayName, privacy: .public)")
            recordChatDiagnostic(.fallback, "Repair reply scaffold-normalized to empty", provider: provider)
            return nil
        }
        return normalized
    }

    nonisolated static func repairReferenceShape(
        issue: CoachChatReplyQualityIssue,
        latestUserTurn: String?,
        system: String
    ) -> String? {
        let lowerTurn = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !lowerTurn.isEmpty else { return nil }

        if turnAsksWhyAnswerLandedBadly(latestUserTurn) {
            if sourceMentionsLateRecommendation(system) {
                return "From the transcript, the recommendation arrived late, so say the decision first, add one reason, then name the implication."
            }
            return "Name the landing problem first, then the move: the close softened, so end with the one decision you need."
        }

        if isCritiqueTurn(lowerTurn) {
            return trustRepairReferenceShape(for: lowerTurn, system: system)
        }

        if containsAny(lowerTurn, ["interview", "get better", "prepare", "practice"]),
           containsAny(system.lowercased(), [
            "no rated sessions yet",
            "not enough data for a stable baseline yet",
            "personalization floor: no rated sessions yet",
            "no voice set yet"
           ]) {
            return "No baseline yet, so start there. Record 60 seconds on one likely question, then review whether your first sentence answers it before polishing anything."
        }

        if containsAny(lowerTurn, ["um", "filler", "fillers", "hesitat"]) {
            if let count = firstFillerCount(in: system) {
                return "Your last rep had \(count) \(count == 1 ? "filler" : "fillers"), so hold one silent beat before sentence two and check whether the next rep lowers the count."
            }
            return "No stable filler pattern yet, so record one short rep and mark every filler before changing the drill."
        }

        if containsAny(lowerTurn, ["leadership", "update", "meeting", "executive", "board"]) {
            return "Run a 30-second update: headline, implication, one decision you need."
        }

        if containsAny(lowerTurn, ["what next", "next move", "what should"]) {
            return "Use the last rep to pick one gap, so run the same prompt once and sharpen either the close, the pause, or the first sentence."
        }

        switch issue {
        case .missingInsightBridge, .missingPrescribedAction, .unanchoredCoaching:
            return "Name one observable signal, connect it with so or because, then prescribe one next move the user can test."
        case .missedTrustRepair, .defensiveProductLanguage:
            return "Fair push. Name the friction briefly, then use one safe signal to prescribe the changed coaching move."
        default:
            return nil
        }
    }

    private nonisolated static func trustRepairReferenceShape(
        for lowerTurn: String,
        system: String
    ) -> String {
        let friction: String
        if containsAny(lowerTurn, ["tts", "read them out", "read aloud", "**", "markdown", "format"]) {
            friction = "Fair push: TTS reading symbols breaks trust."
        } else if containsAny(lowerTurn, ["robotic", "report", "too much writing", "too long", "less text"]) {
            friction = "Fair push. That read too much like a report."
        } else if containsAny(lowerTurn, ["cold", "generic", "not human", "low eq", "not high eq"]) {
            friction = "Fair push: that was advice, not coaching."
        } else {
            friction = "Fair push. That answer did not earn enough trust."
        }

        let move: String
        if containsAny(lowerTurn, ["short", "less text", "too much writing", "too long"]) {
            move = "run one cleaner rep: main point first, then stop"
        } else if containsAny(lowerTurn, ["tts", "read them out", "read aloud", "**", "markdown", "format"]) {
            move = "say the recommendation first, give one proof point, then stop"
        } else if containsAny(lowerTurn, ["cold", "generic", "robotic", "not human", "low eq", "not high eq"]) {
            move = "say the decision first, then soften it with one human reassurance"
        } else {
            move = "run one short rep with the point first and one proof point after it"
        }

        if let count = firstFillerCount(in: system) {
            return "\(friction) Your last rep had \(count) \(count == 1 ? "filler" : "fillers"), so \(move)."
        }
        if replyShouldCiteRecentSession(system) {
            return "\(friction) Your last rep gives one usable signal, so \(move)."
        }
        return "\(friction) No baseline yet, so record one short rep before polishing the answer."
    }

    private nonisolated static func requiredRepairAnchor(
        issue: CoachChatReplyQualityIssue,
        latestUserTurn: String?,
        system: String
    ) -> String? {
        let shouldCarryAnchor: Bool
        switch issue {
        case .unanchoredCoaching, .missingInsightBridge, .missingPrescribedAction,
                .missedTrustRepair, .defensiveProductLanguage, .scaffoldLabel:
            shouldCarryAnchor = true
        case .roboticPhrase:
            shouldCarryAnchor = true
        case .tooLong, .bareClarification, .menuInsteadOfDecision,
                .unrequestedNamedTechnique,
                .unverifiedQuotedUserSpeech, .unengagedUserSpeechClaim:
            shouldCarryAnchor = false
        case .ignoredCoachingExpertise:
            shouldCarryAnchor = true
        case .overclaimsEvidence:
            shouldCarryAnchor = true
        }
        guard shouldCarryAnchor else {
            return nil
        }
        if issue == .overclaimsEvidence,
           sourceMentionsLateRecommendation(system) {
            return "The transcript says the recommendation arrived late; do not say the rep led with the point. Prescribe recommendation first plus one reason or implication."
        }
        if issue == .ignoredCoachingExpertise {
            return "Use the COACHING EXPERTISE technique as craft guidance; do not add a data claim unless the context supports it."
        }
        let lowerTurn = latestUserTurn?.lowercased() ?? ""
        guard containsAny(lowerTurn, ["um", "filler", "fillers", "hesitat"])
                || isCritiqueTurn(lowerTurn) else {
            if replyShouldCiteRecentSession(system) {
                return "Anchor the answer to the last rep or transcript before prescribing the move."
            }
            return nil
        }
        guard let count = firstFillerCount(in: system) else {
            return "I do not have enough rated filler data yet."
        }
        return "Your last rep had \(count) \(count == 1 ? "filler" : "fillers")."
    }

    private nonisolated static func firstFillerCount(in text: String) -> Int? {
        let pattern = #"(?i)\b(\d{1,3})\s+fillers?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[range])
    }

    // MARK: - Provider plumbing

    @MainActor
    private func activeLocaleSupportsAI() -> Bool {
        return LocaleSettingsManager.shared.current.aiSupported
    }

    private func key(for provider: CoachChatProvider) -> String? {
        if let keyLookupOverride {
            return Self.usableAPIKey(keyLookupOverride(provider))
        }
        for keyName in provider.keyNames {
            if let value = Self.usableAPIKey(ProcessInfo.processInfo.environment[keyName]) {
                return value
            }
            if let value = Self.usableAPIKey(LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")) {
                return value
            }
        }
        return nil
    }

    // MARK: - Transport

    private func recordChatDiagnostic(
        _ outcome: AICallDiagnosticOutcome,
        _ reason: String,
        provider: CoachChatProvider? = nil,
        statusCode: Int? = nil,
        startedAt: Date? = nil,
        now: Date = Date()
    ) {
        diagnosticRecorder(
            Self.chatSurface,
            provider?.displayName,
            provider?.model,
            outcome,
            reason,
            statusCode,
            startedAt,
            now
        )
    }

    enum ProviderHTTPResult {
        case success(Data)
        /// The server answered with a non-2xx. `retryAfter` carries the
        /// parsed Retry-After header when the server named one.
        case refused(status: Int, retryAfter: TimeInterval?)
    }

    private func providerHTTP(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any]
    ) async throws -> ProviderHTTPResult {
        if let providerHTTPOverride {
            return try await providerHTTPOverride(provider, endpoint, key, body)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 12s per attempt (was 18): a fast chat model (gemini-3.5-flash with
        // thinkingBudget 0) answers in ~2-4s, so 12s still tolerates a slow
        // network while bounding the worst case. With the optional repair pass
        // this caps a turn near ~24s instead of the old ~40-58s "Thinking…" hang.
        request.timeoutInterval = 12
        switch provider {
        case .openAI, .deepSeek:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .agentPlatform, .gemini:
            request.setGoogleAPIKey(key)
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let started = Date()
        let bodyBytes = request.httpBody?.count ?? 0
        Self.log.debug("transport start provider=\(provider.displayName, privacy: .public) host=\(endpoint.host ?? "unknown", privacy: .public) path=\(endpoint.path, privacy: .public) bodyBytes=\(bodyBytes, privacy: .public)")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let now = Date()
            let elapsedMs = Int(now.timeIntervalSince(started) * 1_000)
            guard let http = response as? HTTPURLResponse else {
                Self.log.error("transport non-http response provider=\(provider.displayName, privacy: .public) ms=\(elapsedMs, privacy: .public) bytes=\(data.count, privacy: .public)")
                recordChatDiagnostic(
                    .failure,
                    "Non-HTTP response",
                    provider: provider,
                    startedAt: started,
                    now: now
                )
                return .refused(status: -1, retryAfter: nil)
            }
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            Self.log.info("transport response provider=\(provider.displayName, privacy: .public) status=\(http.statusCode, privacy: .public) ms=\(elapsedMs, privacy: .public) bytes=\(data.count, privacy: .public) retryAfter=\(retryAfter != nil, privacy: .public)")
            guard (200..<300).contains(http.statusCode) else {
                recordChatDiagnostic(
                    .fallback,
                    Self.failureReason(forHTTPStatus: http.statusCode, data: data, provider: provider),
                    provider: provider,
                    statusCode: http.statusCode,
                    startedAt: started,
                    now: now
                )
                return .refused(status: http.statusCode, retryAfter: retryAfter)
            }
            recordChatDiagnostic(
                .success,
                "Transport succeeded",
                provider: provider,
                statusCode: http.statusCode,
                startedAt: started,
                now: now
            )
            return .success(data)
        } catch {
            recordChatDiagnostic(
                .failure,
                "Transport error",
                provider: provider,
                startedAt: started
            )
            throw error
        }
    }

    // MARK: - Request body construction

    private func chatRequestBody(
        for provider: CoachChatProvider,
        system: String,
        messages: [CoachMessage],
        maxOutputTokens: Int? = nil
    ) -> [String: Any] {
        let tokenCap = maxOutputTokens ?? Self.coachReplyMaxOutputTokens
        if let shared = provider.sharedProvider {
            return requestBody(
                for: shared,
                system: system,
                messages: messages,
                maxOutputTokens: tokenCap
            )
        }

        // Anthropic Messages API: system is a top-level field; messages carry
        // user/assistant roles and must START with a user turn (the thread
        // can open with a coach greeting, so leading assistant turns drop —
        // their substance is already baked into the context block).
        var msgs: [[String: Any]] = []
        for m in messages {
            let role: String
            switch m.role {
            case .user: role = "user"
            case .coach: role = "assistant"
            case .systemNotice: continue // UI-only, never sent to model
            }
            msgs.append(["role": role, "content": m.text])
        }
        while let first = msgs.first, first["role"] as? String == "assistant" {
            msgs.removeFirst()
        }
        return [
            "model": provider.model,
            "max_tokens": tokenCap,
            "system": system,
            "messages": msgs
        ]
    }

    private func requestBody(
        for provider: AIProvider,
        system: String,
        messages: [CoachMessage],
        maxOutputTokens: Int? = nil
    ) -> [String: Any] {
        let tokenCap = maxOutputTokens ?? Self.coachReplyMaxOutputTokens
        switch provider {
        case .openAI, .deepSeek:
            // OpenAI-style chat completion. Each role maps directly;
            // our `.coach` role becomes "assistant" in OpenAI parlance.
            var msgs: [[String: Any]] = [["role": "system", "content": system]]
            for m in messages {
                let role: String
                switch m.role {
                case .user: role = "user"
                case .coach: role = "assistant"
                case .systemNotice: continue // UI-only, never sent to model
                }
                msgs.append(["role": role, "content": m.text])
            }
            return [
                "model": provider.model,
                "temperature": 0.6,
                "max_tokens": tokenCap,
                "messages": msgs
            ]
        case .gemini:
            // Gemini expects role-tagged content parts. Map .user → "user",
            // .coach → "model". The system instruction is a separate
            // top-level field, distinct from the message array.
            var contents: [[String: Any]] = []
            for m in messages {
                let role: String
                switch m.role {
                case .user: role = "user"
                case .coach: role = "model"
                case .systemNotice: continue
                }
                contents.append([
                    "role": role,
                    "parts": [["text": m.text]]
                ])
            }
            return [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": contents,
                "generationConfig": [
                    "temperature": 0.6,
                    // Thinking-capable Gemini models can otherwise spend
                    // visible output budget on hidden reasoning tokens,
                    // guillotining the reply mid-word.
                    // thinkingBudget 0 spends the whole budget on text.
                    "thinkingConfig": ["thinkingBudget": 0],
                    "maxOutputTokens": tokenCap
                ]
            ]
        case .none:
            return [:]
        }
    }

    // MARK: - Response parsing

    static func healthRequestBody(for provider: CoachChatProvider) throws -> Data {
        let body: [String: Any]
        switch provider {
        case .agentPlatform, .gemini:
            body = [
                "systemInstruction": ["parts": [["text": healthSystemPrompt]]],
                "contents": [
                    [
                        "role": "user",
                        "parts": [["text": healthPrompt]]
                    ]
                ],
                "generationConfig": [
                    "temperature": 0,
                    "thinkingConfig": ["thinkingBudget": 0],
                    "maxOutputTokens": 16
                ]
            ]
        case .openAI, .deepSeek:
            body = [
                "model": provider.model,
                "temperature": 0,
                "max_tokens": 16,
                "messages": [
                    ["role": "system", "content": healthSystemPrompt],
                    ["role": "user", "content": healthPrompt]
                ]
            ]
        case .anthropic:
            body = [
                "model": provider.model,
                "system": healthSystemPrompt,
                "messages": [
                    ["role": "user", "content": healthPrompt]
                ],
                "temperature": 0,
                "max_tokens": 16
            ]
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    static func healthResponseContainsSentinel(_ data: Data, provider: CoachChatProvider) -> Bool {
        guard case .text(let text) = chatExtractReplyText(from: data, provider: provider) else {
            return false
        }
        return text.contains(healthSentinel)
    }

    static func failureReason(
        forHTTPStatus statusCode: Int,
        data: Data,
        provider: CoachChatProvider
    ) -> String {
        if let shared = provider.sharedProvider {
            return AIProviderHealthProbe.failureReason(
                forHTTPStatus: statusCode,
                data: data,
                provider: shared
            )
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let type = error["type"] as? String,
           !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Provider error: \(type)"
        }
        return "Provider returned HTTP \(statusCode)"
    }

    static func chatExtractReplyText(from data: Data, provider: CoachChatProvider) -> ChatExtractionResult {
        if let shared = provider.sharedProvider {
            return extractReplyText(from: data, provider: shared)
        }
        return extractAnthropicReplyText(from: data)
    }

    /// Anthropic Messages API extraction: text blocks joined, with
    /// `stop_reason == "max_tokens"` treated as truncation — a guillotined
    /// reply is never committed verbatim (same contract as the other
    /// providers' finish-reason handling).
    static func extractAnthropicReplyText(from data: Data) -> ChatExtractionResult {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .empty
        }
        let stopReason = object["stop_reason"] as? String
        let blocks = object["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if stopReason == "max_tokens" {
            return .lengthTruncated
        }
        return text.isEmpty ? .empty : .text(text)
    }

    static func extractReplyText(from data: Data, provider: AIProvider) -> ChatExtractionResult {
        switch provider {
        case .openAI, .deepSeek:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return .empty }
            // Truncation-honest: a completion the provider stopped for
            // length is a guillotined sentence. Keep it distinct so the
            // store shows "try rephrasing" rather than a dead-stop reply.
            if Self.isLengthTruncated(responseObject: object, provider: provider) {
                return .lengthTruncated
            }
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? .empty : .text(trimmed)
        case .gemini:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return .empty }
            if Self.isLengthTruncated(responseObject: object, provider: provider) {
                return .lengthTruncated
            }
            let joined = parts
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? .empty : .text(joined)
        case .none:
            return .empty
        }
    }

    // MARK: - Finish-reason inspection (truncation guard)

    /// Reads the provider-specific finish reason from a parsed response
    /// object. Gemini reports `candidates[0].finishReason`; OpenAI /
    /// DeepSeek report `choices[0].finish_reason`. Returns `nil` when the
    /// field is absent (some providers omit it on a clean stop).
    ///
    /// Pure + dependency-free so the truncation gate is unit-testable
    /// without a live provider (see `AICoachTruncationGuardTests`).
    static func parseFinishReason(responseObject object: [String: Any], provider: AIProvider) -> String? {
        switch provider {
        case .openAI, .deepSeek:
            guard
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first
            else { return nil }
            return first["finish_reason"] as? String
        case .gemini:
            guard
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first
            else { return nil }
            return first["finishReason"] as? String
        case .none:
            return nil
        }
    }

    /// Whether the parsed response was cut off because the model hit its
    /// output cap (Gemini `MAX_TOKENS`, OpenAI/DeepSeek `length`). Such a
    /// completion is a mid-sentence fragment and must not be committed as
    /// a finished reply. Case-insensitive; a missing or any other finish
    /// reason (e.g. `STOP`, `stop`) is treated as *not* truncated.
    static func isLengthTruncated(responseObject object: [String: Any], provider: AIProvider) -> Bool {
        guard let reason = parseFinishReason(responseObject: object, provider: provider) else {
            return false
        }
        switch reason.uppercased() {
        case "MAX_TOKENS", "LENGTH":
            return true
        default:
            return false
        }
    }
}
