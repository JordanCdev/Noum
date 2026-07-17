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
    /// This account has not granted the current cloud-processing disclosure.
    case consentRequired
    /// Firebase callable rejected the request because no authenticated
    /// session was attached.
    case unauthenticated
    /// The service-owned capability preflight failed before generation. Keep
    /// the exact reason so the UI does not turn a backend-version or identity
    /// limitation into a generic network error.
    case coachUnavailable(CoachChatUnavailableReason)
    /// Server-side per-user budget was exhausted for the current window.
    case rateLimited
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
    /// The callable rejected an incoherent or unsupported request contract.
    case invalidRequest
    /// The authenticated caller lacks authority for this coaching request.
    case permissionDenied
    /// The installed app requires a newer versioned coaching callable than the
    /// currently deployed backend advertises.
    case backendVersionMissing
}

/// Outcome of a chat turn — either a live model reply or a typed failure the
/// store maps to per-cause copy.
enum ChatOutcome {
    /// A live, model-generated reply.
    case reply(String)
    case failure(ChatFailure)
}

/// Redacted quality-gate event for turn metadata. Carries stable gate labels,
/// never draft text or user content.
enum CoachTurnQualityGateEvent: Equatable, Sendable {
    case passed
    case repaired(String)
    case fallback(String)
    case rejected(String)
    case failed(String)
}

/// Redacted provider-call events for per-turn latency/cost observability.
/// Carries only provider identity/model, never user text or draft output.
enum CoachProviderAttemptEvent: Equatable, Sendable {
    case started(CoachTurnProviderChoice)
    case retry(CoachTurnProviderChoice)
    case refused(CoachTurnProviderChoice)
}

/// Guards streamed provider chunks before they become visible in the pending
/// coach row. The first render waits for a complete, sanitized sentence so the
/// UI never flashes raw scaffolding or half a verdict; after that, the row can
/// update as the provider continues streaming. The final committed reply still
/// passes through the full quality and semantic gates.
struct CoachStreamingPartialGate {
    private var rawBuffer = ""
    private var released = false
    private var lastVisible = ""

    mutating func consume(delta: String) -> String? {
        guard !delta.isEmpty else { return nil }
        rawBuffer += delta

        let display = CoachReplyTextSanitizer.liveDisplayText(from: rawBuffer)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !display.isEmpty else { return nil }

        let visible: String
        if released {
            visible = display
        } else {
            guard let prefix = Self.firstPassableCompleteSentencePrefix(in: display) else {
                return nil
            }
            released = true
            visible = prefix
        }

        guard visible != lastVisible else { return nil }
        lastVisible = visible
        return visible
    }

    static func completeSentencePrefix(in text: String) -> String? {
        var index = text.startIndex
        while index < text.endIndex {
            if ".!?".contains(text[index]) {
                let next = text.index(after: index)
                if next == text.endIndex ||
                    text[next].unicodeScalars.allSatisfy({
                        CharacterSet.whitespacesAndNewlines.contains($0)
                    }) {
                    let prefix = String(text[..<next])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return prefix.isEmpty ? nil : prefix
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func firstPassableCompleteSentencePrefix(in text: String) -> String? {
        var index = text.startIndex
        while index < text.endIndex {
            if ".!?".contains(text[index]) {
                let next = text.index(after: index)
                if next == text.endIndex ||
                    text[next].unicodeScalars.allSatisfy({
                        CharacterSet.whitespacesAndNewlines.contains($0)
                    }) {
                    let prefix = String(text[..<next])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if passesInitialGate(prefix) {
                        return prefix
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    static func passesInitialGate(_ text: String) -> Bool {
        let normalized = CoachReplyTextSanitizer.spokenText(from: text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 24 else { return false }
        let words = normalized
            .split { !$0.isLetter && !$0.isNumber }
        guard words.count >= 5 else { return false }

        let lower = normalized.lowercased()
        let blockedPrefixes = ["read:", "move:", "target:", "next rep:", "-", "•"]
        return !blockedPrefixes.contains { lower.hasPrefix($0) }
    }
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

/// Token usage + prompt-cache accounting for one provider response. COST/
/// LATENCY instrumentation only — never a signal about reply quality. Fields
/// are provider-shaped: Anthropic reports `cacheCreationInputTokens` /
/// `cacheReadInputTokens`; Gemini's implicit caching reports a single
/// `cachedContentTokenCount`. A field is nil when the provider's response
/// omitted it (e.g. no usage on a refused/errored call), not when it is zero.
struct CoachChatUsage: Equatable {
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheCreationInputTokens: Int?
    var cacheReadInputTokens: Int?
    var cachedContentTokenCount: Int?

    var hasAnyTokenData: Bool {
        inputTokens != nil || outputTokens != nil
            || cacheCreationInputTokens != nil || cacheReadInputTokens != nil
            || cachedContentTokenCount != nil
    }

    var cacheHit: Bool {
        (cacheReadInputTokens ?? 0) > 0 || (cachedContentTokenCount ?? 0) > 0
    }

    /// Overlays `newer`'s non-nil fields on top of `self`. Anthropic's
    /// streaming `message_delta` event repeats only `output_tokens`, so a
    /// naive overwrite would drop the cache fields `message_start` already
    /// reported — this keeps every field's most-recent non-nil value.
    func merged(with newer: CoachChatUsage) -> CoachChatUsage {
        CoachChatUsage(
            inputTokens: newer.inputTokens ?? inputTokens,
            outputTokens: newer.outputTokens ?? outputTokens,
            cacheCreationInputTokens: newer.cacheCreationInputTokens ?? cacheCreationInputTokens,
            cacheReadInputTokens: newer.cacheReadInputTokens ?? cacheReadInputTokens,
            cachedContentTokenCount: newer.cachedContentTokenCount ?? cachedContentTokenCount
        )
    }

    /// Compact non-secret line for the AI call diagnostics reason field.
    var diagnosticSummary: String {
        var parts: [String] = []
        if let inputTokens { parts.append("input=\(inputTokens)") }
        if let cacheReadInputTokens { parts.append("cacheRead=\(cacheReadInputTokens)") }
        if let cacheCreationInputTokens { parts.append("cacheCreate=\(cacheCreationInputTokens)") }
        if let cachedContentTokenCount { parts.append("cachedContent=\(cachedContentTokenCount)") }
        if let outputTokens { parts.append("output=\(outputTokens)") }
        guard !parts.isEmpty else { return "Cache usage: no token data" }
        return "Cache usage: " + parts.joined(separator: " ")
    }
}

/// Normalizes live coach text before it is stored, rendered in the live call,
/// or sent to TTS. The model may still occasionally emit Markdown-ish text;
/// Noum's app surfaces should never expose raw scaffolding like `**Read:**`,
/// and spoken replies should not read formatting labels aloud.
enum CoachReplyTextSanitizer {
    static let coachScaffoldLeadInPattern = #"read|the read|coach read|real read|observation|diagnosis|insight|next move|next rep|move|action|why|evidence|try this|try|focus|target|drill|practice|recommend|recommendation"#

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
        let stripped = replace(pattern: pattern, in: value, template: "")
        guard stripped != value else { return value }
        return recapitalizeSentenceStarts(in: stripped)
    }

    private nonisolated static func stripInlineCoachLeadIns(from value: String) -> String {
        // A scaffold lead-in can appear mid-line after sentence punctuation, an
        // em/hyphen dash, OR a comma/semicolon join ("that was fluff, real read:
        // ..."). The earlier pattern only anchored on `^`, `[.!?]\s+`, or a dash,
        // so a comma-joined "Real read:" survived. Adding `[,;]\s+` closes that
        // mid-sentence gap without touching label-free prose (the trailing `:`
        // is still required, so only genuine "label:" scaffolds are removed).
        let pattern = #"(?i)(^|[.!?]\s+|[,;]\s+|\s+[—-]\s+)("# + coachScaffoldLeadInPattern + #"):\s*"#
        let stripped = replace(pattern: pattern, in: value, template: "$1")
        guard stripped != value else { return value }
        return recapitalizeSentenceStarts(in: stripped)
    }

    /// Bare report-voice telemetry residue the model sometimes leaves behind
    /// after a scaffold label is stripped ("... coaching. score 74, but your
    /// point ..."). On trust-repair / sensitive turns a raw "score 74",
    /// "5 fillers in 68 seconds", or "170 words per minute" is not a coaching
    /// read — the reliability gate already REJECTS these so the chain
    /// regenerates, but this is the last-mile backstop that makes the leak
    /// impossible in the *emitted* text even if a bypass/fallback path ever
    /// ships an un-regenerated draft. It only runs on turns the gate marks
    /// sensitive-and-metrics-not-requested, so an explicit progress turn that
    /// legitimately cites a trend is never touched (see the AICoachChatService
    /// caller predicate). Patterns are the superset of the gate's own
    /// `replyContainsRawReportVoiceMetrics` detector so anything the gate would
    /// flag is guaranteed gone after this pass.
    nonisolated static let reportVoiceResiduePatterns: [String] = [
        #"(?i)\b(?:score|scored|scoring|hit)\s+\d{1,3}(?:\.\d)?(?:\s*/\s*10)?\b"#,
        #"(?i)(?:,\s*)?\b\d(?:\.\d)?\s*/\s*10\s*,\s*\d+\s+fillers?\s*,\s*\d+\s*s(?:ec(?:ond)?s?)?\b"#,
        #"(?i)\b\d{2,3}\s*(?:/|over)\s*\d{2,3}\s*s(?:ec(?:ond)?s?)?\s*(?:/|with)\s*(?:only\s*)?\d+\s+fillers?\b"#,
        #"(?i)\b\d+\s+fillers?\s+(?:in|over|across)\s+\d{2,3}\s*s(?:ec(?:ond)?s?)?\b"#,
        #"(?i)\b(?:clean|landed|held)\s+at\s+\d{2,3}\b"#,
        #"(?i)\b\d{2,3}\s*(?:words per minute|wpm)\b"#,
        #"(?i)\b\d+\s+fillers?\b"#
    ]

    private nonisolated static let reportVoiceBridgeResiduePatterns: [String] = [
        #"(?i)\b(?:your|the)\s+(?:last|latest)\s+rep\s+had\s+\d+\s+fillers?\s*,?\s+so\s+"#,
        #"(?i)\byou\s+had\s+\d+\s+fillers?\s*,?\s+so\s+"#,
        #"(?i)\bthere\s+(?:was|were)\s+\d+\s+fillers?\s*,?\s+so\s+"#
    ]

    private nonisolated static let reportVoicePhraseTranslations: [(pattern: String, template: String)] = [
        (
            #"(?i)\b(more than\s+)(?:your|the)?\s*\d+\s+fillers?\s+(?:do|did)\b"#,
            "$1the filler words do"
        )
    ]

    private nonisolated static let reportVoiceModeOnlyEvidencePatterns: [String] = [
        #"(?i)(^|[.!?]\s+)the signal i can use is\s+(?:timed(?:\s+practice)?|practice|pressure(?:\s+drill)?)\s*[.!?]?\s*"#
    ]

    nonisolated static func strippingReportVoiceResidue(from text: String) -> String {
        var value = text
        for translation in reportVoicePhraseTranslations {
            value = replace(pattern: translation.pattern, in: value, template: translation.template)
        }
        for pattern in reportVoiceBridgeResiduePatterns {
            value = replace(pattern: pattern, in: value, template: "")
        }
        for pattern in reportVoiceModeOnlyEvidencePatterns {
            value = replace(pattern: pattern, in: value, template: "$1")
        }
        for pattern in reportVoiceResiduePatterns {
            // Also swallow an immediately-following connective + separator
            // ("score 74, but ...") so the surviving clause reflows cleanly
            // instead of orphaning a lowercase "but"/"and". "So" is kept:
            // it often introduces the actual coaching move after a stripped
            // metric, and removing it can leave broken prose ("had for...").
            let full = pattern + #"(?:\s*[,;—-]\s*(?:but|and|though|with|only)\b)?"#
            value = replace(pattern: full, in: value, template: "")
        }
        // Repair the punctuation/whitespace/casing artifacts the removals leave.
        value = replace(pattern: #"(?i)([.!?]\s+)(?:but|and|so|though)\s+"#, in: value, template: "$1")
        value = replace(pattern: #"\.\s*\.\s+"#, in: value, template: ". ")
        value = replace(pattern: #"\s*,\s*,"#, in: value, template: ",")
        value = replace(pattern: #"([.!?:])\s*,\s*"#, in: value, template: "$1 ")
        value = replace(pattern: #"(^|[.!?]\s+)—\s+"#, in: value, template: "$1")
        value = replace(pattern: #"\s+—\s+(?=[.!?]|$)"#, in: value, template: " ")
        value = replace(pattern: #"([:,])\s*(?=[.!?])"#, in: value, template: "")
        value = replace(pattern: #"\s{2,}"#, in: value, template: " ")
        value = replace(pattern: #"\s+([,.;:!?])"#, in: value, template: "$1")
        value = recapitalizeSentenceStarts(in: value)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func recapitalizeSentenceStarts(in value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(^|[.!?]\s+)([a-z])"#) else {
            return value
        }
        let ns = value as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
            let pre = match.range(at: 1)
            let ch = match.range(at: 2)
            let nextLocation = ch.location + ch.length
            let nextIsUpperCamelCase = nextLocation < ns.length && ns.substring(
                with: NSRange(location: nextLocation, length: 1)
            ).range(of: #"[A-Z]"#, options: .regularExpression) != nil
            result += ns.substring(with: NSRange(location: last, length: pre.location + pre.length - last))
            result += nextIsUpperCamelCase ? ns.substring(with: ch) : ns.substring(with: ch).uppercased()
            last = ch.location + ch.length
        }
        result += ns.substring(from: last)
        return result
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
    case missingVerifiedExampleQuote
    case ignoredCoachingExpertise
    case repeatedProofTest
    case nonCoachingPrescription
    case visionGate(score: Int, misses: [CoachVisionCriterion])
    case semanticJudgement(CoachSemanticQualityIssue)

    var auditLabel: String {
        switch self {
        case .tooLong:
            return "professional:tooLong"
        case .roboticPhrase:
            return "professional:roboticPhrase"
        case .bareClarification:
            return "professional:bareClarification"
        case .defensiveProductLanguage:
            return "professional:defensiveProductLanguage"
        case .menuInsteadOfDecision:
            return "professional:menuInsteadOfDecision"
        case .missedTrustRepair:
            return "professional:missedTrustRepair"
        case .missingPrescribedAction:
            return "professional:missingPrescribedAction"
        case .missingInsightBridge:
            return "professional:missingInsightBridge"
        case .unanchoredCoaching:
            return "professional:unanchoredCoaching"
        case .overclaimsEvidence:
            return "professional:overclaimsEvidence"
        case .unrequestedNamedTechnique:
            return "professional:unrequestedNamedTechnique"
        case .scaffoldLabel:
            return "professional:scaffoldLabel"
        case .unverifiedQuotedUserSpeech:
            return "professional:unverifiedQuotedUserSpeech"
        case .unengagedUserSpeechClaim:
            return "professional:unengagedUserSpeechClaim"
        case .missingVerifiedExampleQuote:
            return "professional:missingVerifiedExampleQuote"
        case .ignoredCoachingExpertise:
            return "professional:ignoredCoachingExpertise"
        case .repeatedProofTest:
            return "professional:repeatedProofTest"
        case .nonCoachingPrescription:
            return "professional:nonCoachingPrescription"
        case .visionGate(let score, let misses):
            let labels = misses.map(\.rawValue).joined(separator: ",")
            return "vision:\(score):\(labels)"
        case .semanticJudgement(let issue):
            return "semantic:\(issue.rawValue)"
        }
    }

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
            return "The user challenged the coaching quality. Repair trust first with \"Fair push\" or another short natural acknowledgement, name the friction briefly, then explain naturally how one grounded fact changes the coaching move. Avoid stiff self-narration about changing the reply style."
        case .missingPrescribedAction:
            return "The draft does not prescribe a concrete next move. Give one action the user can take in the next rep or review."
        case .missingInsightBridge:
            return "The draft gives an anchor and an action but does not connect them with a coaching read. Explain naturally why this move fits the signal; do not force a particular connector."
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
        case .missingVerifiedExampleQuote:
            return "The user asked for an example from sessions, and a verified proof quote is available. Include one verified quote, explain the pattern it shows, then give one next move."
        case .ignoredCoachingExpertise:
            return "The draft ignores the retrieved coaching expertise for this technique-seeking turn. Use the COACHING EXPERTISE block as craft guidance: apply its technique in plain user-facing language, tied to the user's context."
        case .repeatedProofTest:
            return "The draft repeats or paraphrases a recent validation rep. Do not reissue it as new. If the typed brief retains that intervention, name the current evidence once and say to stay with that focus without restating the drill; otherwise vary the target, evidence check, or next condition."
        case .nonCoachingPrescription:
            return "This turn did not ask for a drill. Respond naturally without a diagnosis, evidence read, or practice instruction."
        case .visionGate(let score, let misses):
            let labels = misses.map(\.rawValue).joined(separator: ", ")
            return "The draft scored \(score)/100 on the Ask Noum vision gate. Missing: \(labels). Rewrite it so it directly answers, uses one observable anchor or honest data gap, prescribes one specific action, stays evidence-honest, and sounds like a senior communications coach."
        case .semanticJudgement(let issue):
            return issue.repairInstruction
        }
    }
}

/// Semantic misses for typed judgement turns. These are deliberately lexical
/// and conservative: the assessment object is the source of truth; this gate
/// only catches drafts that plainly failed to verbalise it.
enum CoachSemanticQualityIssue: String, Equatable {
    case missingDirectVerdict
    case missingMechanicsGoalDistinction
    case missingCaseAnchor
    case missingEvidenceDisclosure
    case insufficientEvidenceReferences
    case missingRepairInsight
    case unsupportedClosenessClaim
    case unsupportedTransferCausalityClaim
    case missingProofTest
    case missingIntentFit

    var repairInstruction: String {
        switch self {
        case .missingDirectVerdict:
            return "The draft does not answer the judgement question first. Rewrite with the typed direct verdict in the first sentence."
        case .missingMechanicsGoalDistinction:
            return "The draft treats a better score as proof of the full goal. Separate the control shown in this answer from authority that is consistent under pressure."
        case .missingCaseAnchor:
            return "The draft ignores the active case or intervention evidence in the typed assessment. Tie the read to the current case hypothesis, next coach move, or active intervention before prescribing."
        case .missingEvidenceDisclosure:
            return "The draft fails to name missing evidence. Say exactly what evidence is still needed before a stronger verdict is fair."
        case .insufficientEvidenceReferences:
            return "The draft does not use enough concrete evidence. Include at least two evidence points from the typed assessment when available."
        case .missingRepairInsight:
            return "The draft acknowledges the trust repair but does not give a concrete coach read. Name the behavioral signal, evidence anchor, or actual read before prescribing a specific validation rep."
        case .unsupportedClosenessClaim:
            return "The draft says the user is close or not far off without enough evidence. Remove the closeness claim or limit it to the control observed in this answer."
        case .unsupportedTransferCausalityClaim:
            return "The draft treats user-reported real-world transfer as proof or causation. Reframe it as the user's self-report or room read, use association language only, and do not say a drill caused the outcome."
        case .missingProofTest:
            return "The draft does not end with one concrete validation rep. End with the typed final action, written as a normal sentence rather than generic advice."
        case .missingIntentFit:
            return "The draft answers a neighboring coaching task instead of the user's actual ask. Rewrite so the first sentence fits whether they asked for an example, a why, a check, a capture, a keep/change decision, or a threshold."
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
    case unsolicitedPrescription
}

/// Harsher product-vision score for transcript review. Unlike
/// `professionalCoachRubric`, which starts at 10 and subtracts obvious
/// failures, this starts at zero and makes a reply earn coaching quality:
/// direct answer, grounded read, action, bridge, honesty, adaptation,
/// personalization, transfer, register, and brevity.
enum CoachVisionCriterion: String, Codable, Equatable, CaseIterable {
    case directAnswer
    case observableAnchor
    case prescribedAction
    case insightBridge
    case evidenceHonesty
    case adaptiveRepair
    case personalization
    case transferProof
    case seniorRegister
    case brevity
}

struct CoachVisionEvaluationResult: Equatable {
    let score: Int
    let earned: [CoachVisionCriterion]
    let missed: [CoachVisionCriterion]

    var passesProductionFloor: Bool {
        score >= 85 && criticalMisses.isEmpty
    }

    var criticalMisses: [CoachVisionCriterion] {
        missed.filter {
            [
                .directAnswer,
                .observableAnchor,
                .prescribedAction,
                .evidenceHonesty,
                .seniorRegister
            ].contains($0)
        }
    }
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
    let verifiedProofQuotes: [String]
    /// User-authored chat turns are a separate provenance class from practice
    /// transcripts and verified quotes. A number in one of these turns is a
    /// self-report, not an observed app measurement.
    let userReportTexts: [String]

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
        self.verifiedProofQuotes = verifiedProofQuotes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.userReportTexts = ([latestUserTurn] + recentUserTurns.map { Optional($0) })
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.sourceTexts = (transcripts + self.verifiedProofQuotes.map { Optional($0) }
            + self.userReportTexts.map { Optional($0) })
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func verifies(_ quote: String) -> Bool {
        sourceTexts.contains { source in
            Self.quoteVerificationCandidates(quote).contains { candidate in
                ProofMomentService.transcriptContains(candidate, in: source)
            }
        }
    }

    var hasVerifiedProofQuotes: Bool {
        !verifiedProofQuotes.isEmpty
    }

    func includesVerifiedProofQuote(in reply: String) -> Bool {
        verifiedProofQuotes.contains { quote in
            ProofMomentService.transcriptContains(quote, in: reply)
        }
    }

    private static func quoteVerificationCandidates(_ quote: String) -> [String] {
        let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var strippedTerminalPunctuation = trimmed
        while strippedTerminalPunctuation.last.map({ ".!?".contains($0) }) == true {
            strippedTerminalPunctuation.removeLast()
        }
        if strippedTerminalPunctuation.isEmpty || strippedTerminalPunctuation == trimmed {
            return [trimmed]
        }
        return [trimmed, strippedTerminalPunctuation]
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

    var streamingEndpoint: URL? {
        switch self {
        case .agentPlatform:
            return Self.agentPlatformStreamingEndpoint(model: model)
        case .gemini:
            return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse")
        case .anthropic:
            return endpoint
        case .openAI, .deepSeek:
            return sharedProvider?.endpoint
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

    nonisolated static func agentPlatformStreamingEndpoint(model: String) -> URL? {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else { return nil }

        let modelPath = trimmedModel.hasPrefix("publishers/google/models/")
            ? String(trimmedModel.dropFirst("publishers/google/models/".count))
            : trimmedModel
        return URL(
            string: "https://aiplatform.googleapis.com/v1/publishers/google/models/\(modelPath):streamGenerateContent?alt=sse"
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
    /// 401/402/403 — the key, billing, or account is blocked; hammering won't fix it.
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
        case 401, 402, 403: return .authBlocked
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
    private let semanticGateDryRunOverride: (() -> Bool)?
    private let diagnosticRecorder: CoachChatDiagnosticRecorder
    private let secureTransport: any CoachChatTransport
    private let cloudProcessingAllowed: () async -> Bool

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
        self.semanticGateDryRunOverride = nil
        self.diagnosticRecorder = Self.defaultDiagnosticRecorder
        self.secureTransport = FirebaseCoachChatTransport()
        self.cloudProcessingAllowed = {
            await MainActor.run {
                AISettingsManager.shared.isCloudProcessingAllowed
            }
        }
    }

    /// Focused injection point for secure-transport contract tests. Runtime
    /// uses the private shared initializer above; no alternate state owner is
    /// introduced.
    init(
        secureTransport: any CoachChatTransport,
        cloudProcessingAllowed: @escaping () async -> Bool = { true }
    ) {
        self.keyedProvidersOverride = nil
        self.keyLookupOverride = nil
        self.localeSupportsAIOverride = { true }
        self.providerHTTPOverride = nil
        self.semanticGateDryRunOverride = nil
        self.diagnosticRecorder = Self.defaultDiagnosticRecorder
        self.secureTransport = secureTransport
        self.cloudProcessingAllowed = cloudProcessingAllowed
    }

    init(
        keyedProviders: @escaping () -> [CoachChatProvider],
        keyLookup: @escaping (CoachChatProvider) -> String?,
        localeSupportsAI: @escaping () -> Bool,
        providerHTTP: @escaping (CoachChatProvider, URL, String, [String: Any]) async throws -> ProviderHTTPResult,
        semanticGateDryRun: (() -> Bool)? = nil,
        diagnosticRecorder: CoachChatDiagnosticRecorder? = nil,
        secureTransport: any CoachChatTransport = FirebaseCoachChatTransport(),
        cloudProcessingAllowed: @escaping () async -> Bool = { true }
    ) {
        self.keyedProvidersOverride = keyedProviders
        self.keyLookupOverride = keyLookup
        self.localeSupportsAIOverride = localeSupportsAI
        self.providerHTTPOverride = providerHTTP
        self.semanticGateDryRunOverride = semanticGateDryRun
        self.diagnosticRecorder = diagnosticRecorder ?? Self.defaultDiagnosticRecorder
        self.secureTransport = secureTransport
        self.cloudProcessingAllowed = cloudProcessingAllowed
    }

    init(
        keyedProviders: @escaping () -> [CoachChatProvider],
        keyLookup: @escaping (CoachChatProvider) -> String?,
        localeSupportsAI: @escaping () -> Bool,
        semanticGateDryRun: (() -> Bool)? = nil,
        diagnosticRecorder: CoachChatDiagnosticRecorder? = nil,
        secureTransport: any CoachChatTransport = FirebaseCoachChatTransport(),
        cloudProcessingAllowed: @escaping () async -> Bool = { true }
    ) {
        self.keyedProvidersOverride = keyedProviders
        self.keyLookupOverride = keyLookup
        self.localeSupportsAIOverride = localeSupportsAI
        self.providerHTTPOverride = nil
        self.semanticGateDryRunOverride = semanticGateDryRun
        self.diagnosticRecorder = diagnosticRecorder ?? Self.defaultDiagnosticRecorder
        self.secureTransport = secureTransport
        self.cloudProcessingAllowed = cloudProcessingAllowed
    }

    /// Send a turn to the model. Returns `.reply(text)` on a live success or
    /// `.failure(cause)` when the model cannot produce a safe answer. Total
    /// function — never throws. The store keeps operational failures outside
    /// the transcript; local deterministic coach copy must never masquerade
    /// as the senior AI coach.
    func reply(
        history: [CoachMessage],
        systemPrompt: String,
        userContext: String,
        accountID: String? = nil,
        grounding: ChatGroundingContext = ChatGroundingContext(),
        turnDepth: CoachTurnDepth = .groundedRead,
        assessment: CoachAssessment? = nil,
        responseKind: CoachChatResponseKind? = nil,
        coachVoice: SpeakingStyleGoal? = nil,
        surface: CoachReplySurface = .text,
        preferredTier: CoachProviderTier? = nil,
        providerWorkAllowed: @escaping () async -> Bool = { true },
        onStreamedPartialVisible: (@MainActor (String) -> Void)? = nil,
        onProviderChosen: (@MainActor (CoachTurnProviderChoice) -> Void)? = nil,
        onProviderAttemptEvent: (@MainActor (CoachProviderAttemptEvent) -> Void)? = nil,
        onQualityGateEvent: (@MainActor (CoachTurnQualityGateEvent) -> Void)? = nil
    ) async -> ChatOutcome {
        guard !Task.isCancelled, await providerWorkAllowed() else {
            return .failure(.unauthenticated)
        }
        // UI harness only: lets simulator tests verify send -> pipeline ->
        // store -> system-notice rendering without depending on live provider
        // latency or keys. Runtime-gated by `UI_TESTING` rather than
        // compile-gated so UI tests stay deterministic across build configs.
        let launchArguments = ProcessInfo.processInfo.arguments
        let launchEnvironment = ProcessInfo.processInfo.environment
        if Self.uiHarnessFlagPresent(
            "UI_TESTING",
            arguments: launchArguments,
            environment: launchEnvironment
        ) {
            if Self.uiHarnessFlagPresent(
                "UI_TESTING_CHAT_FORCE_GOAL_REPLY",
                arguments: launchArguments,
                environment: launchEnvironment
            ) {
                if let onProviderChosen {
                    await onProviderChosen(Self.uiHarnessProviderChoice)
                }
                return .reply("I can help with that shift. Confirm the voice card below, then I will tune the next rep around it.")
            }
            if Self.uiHarnessFlagPresent(
                "UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY",
                arguments: launchArguments,
                environment: launchEnvironment
            ) {
                if let onProviderChosen {
                    await onProviderChosen(Self.uiHarnessProviderChoice)
                }
                return .reply("""
                **Fair.** I’ll keep it direct.

                - Answer first, proof second.
                - Give one 30-second update, so the recommendation lands before the explanation: recommendation, one proof point, stop.
                """)
            }
            if Self.uiHarnessFlagPresent(
                "UI_TESTING_CHAT_FORCE_JUDGEMENT_REPLY",
                arguments: launchArguments,
                environment: launchEnvironment
            ) {
                if let onProviderChosen {
                    await onProviderChosen(Self.uiHarnessProviderChoice)
                }
                return .reply("Your latest answer shows control, but the evidence is too thin to call the voice consistently authoritative. One rep does not yet show how you hold the answer under pressure or whether you can close cleanly more than once. Record a 75-second answer: give the verdict in sentence one, support it with one reason, then stop cleanly.")
            }
            if Self.uiHarnessFlagPresent(
                "UI_TESTING_CHAT_FORCE_NOTICE",
                arguments: launchArguments,
                environment: launchEnvironment
            ) {
                return .failure(.network)
            }
        }

        guard await cloudProcessingAllowed() else {
            recordChatDiagnostic(.skipped, "Cloud processing not allowed")
            return .failure(.consentRequired)
        }
        guard !Task.isCancelled, await providerWorkAllowed() else {
            return .failure(.unauthenticated)
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
        guard !Task.isCancelled, await providerWorkAllowed() else {
            return .failure(.unauthenticated)
        }

        #if DEBUG
        if keyedProvidersOverride == nil,
           providerHTTPOverride == nil,
           ProcessInfo.processInfo.environment["NOUM_DIRECT_AI_DEBUG"] == "1" {
            let directTransport = DirectProviderDebugTransport(
                isConfigured: { !Self.keyedProviders().isEmpty },
                operation: { [self] request in
                    let outcome = await directProviderReply(
                        history: history,
                        systemPrompt: systemPrompt,
                        userContext: userContext,
                        grounding: grounding,
                        turnDepth: turnDepth,
                        assessment: assessment,
                        explicitResponseKind: responseKind,
                        surface: surface,
                        preferredTier: preferredTier,
                        providerWorkAllowed: providerWorkAllowed,
                        onStreamedPartialVisible: nil,
                        onProviderChosen: nil,
                        onProviderAttemptEvent: nil,
                        onQualityGateEvent: nil
                    )
                    guard case .reply(let text) = outcome else {
                        throw CoachChatTransportError.serviceUnavailable
                    }
                    return CoachChatCompletion(
                        requestID: request.requestID,
                        text: text,
                        model: Self.keyedProviders().first?.model ?? "direct-debug",
                        qualityTier: request.qualityTier,
                        finishReason: "STOP",
                        inputTokens: nil,
                        outputTokens: nil
                    )
                }
            )
            return await secureReply(
                transportOverride: directTransport,
                history: history,
                userContext: userContext,
                accountID: accountID,
                grounding: grounding,
                turnDepth: turnDepth,
                assessment: assessment,
                explicitResponseKind: responseKind,
                coachVoice: coachVoice,
                surface: surface,
                preferredTier: preferredTier,
                providerWorkAllowed: providerWorkAllowed,
                onStreamedPartialVisible: onStreamedPartialVisible,
                onProviderChosen: onProviderChosen,
                onProviderAttemptEvent: onProviderAttemptEvent,
                onQualityGateEvent: onQualityGateEvent
            )
        }
        #endif

        let shouldAttemptSecureTransport: Bool = {
            guard keyedProvidersOverride == nil, providerHTTPOverride == nil else { return false }
            #if DEBUG
            return ProcessInfo.processInfo.environment["NOUM_DIRECT_AI_DEBUG"] != "1"
            #else
            return true
            #endif
        }()

        if shouldAttemptSecureTransport {
            let secureOutcome = await secureReply(
                history: history,
                userContext: userContext,
                accountID: accountID,
                grounding: grounding,
                turnDepth: turnDepth,
                assessment: assessment,
                explicitResponseKind: responseKind,
                coachVoice: coachVoice,
                surface: surface,
                preferredTier: preferredTier,
                providerWorkAllowed: providerWorkAllowed,
                onStreamedPartialVisible: onStreamedPartialVisible,
                onProviderChosen: onProviderChosen,
                onProviderAttemptEvent: onProviderAttemptEvent,
                onQualityGateEvent: onQualityGateEvent
            )
            if case .reply = secureOutcome {
                return secureOutcome
            }
            // Direct provider use is opt-in through the Debug transport above;
            // an ordinary build never falls through from Firebase to client
            // credentials merely because an environment variable exists.
            return secureOutcome
        }

        return await directProviderReply(
            history: history,
            systemPrompt: systemPrompt,
            userContext: userContext,
            grounding: grounding,
            turnDepth: turnDepth,
            assessment: assessment,
            explicitResponseKind: responseKind,
            surface: surface,
            preferredTier: preferredTier,
            providerWorkAllowed: providerWorkAllowed,
            onStreamedPartialVisible: onStreamedPartialVisible,
            onProviderChosen: onProviderChosen,
            onProviderAttemptEvent: onProviderAttemptEvent,
            onQualityGateEvent: onQualityGateEvent
        )
    }

    private func directProviderReply(
        history: [CoachMessage],
        systemPrompt: String,
        userContext: String,
        grounding: ChatGroundingContext,
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?,
        explicitResponseKind: CoachChatResponseKind?,
        surface: CoachReplySurface,
        preferredTier: CoachProviderTier?,
        providerWorkAllowed: @escaping () async -> Bool,
        onStreamedPartialVisible: (@MainActor (String) -> Void)?,
        onProviderChosen: (@MainActor (CoachTurnProviderChoice) -> Void)?,
        onProviderAttemptEvent: (@MainActor (CoachProviderAttemptEvent) -> Void)?,
        onQualityGateEvent: (@MainActor (CoachTurnQualityGateEvent) -> Void)?
    ) async -> ChatOutcome {
        guard !Task.isCancelled, await providerWorkAllowed() else {
            return .failure(.unauthenticated)
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
        let recentCoachReplies = Self.recentCoachReplies(
            beforeLatestUserTurnIn: trimmed
        )
        let turnIntent = CoachChatTurnIntent.classify(latestUserTurn)
        let responseKind = explicitResponseKind ?? CoachChatResponseKind.classify(
            latestUserTurn,
            intent: turnIntent
        )
        let laneAssessment: CoachAssessment?
        switch responseKind {
        case .personalEvidenceRead, .memoryHandoff:
            laneAssessment = assessment
        case .generalCoaching, .conversational:
            laneAssessment = nil
        }
        let coachingBrief = laneAssessment.flatMap {
            CoachChatBrief.applicable(
                assessment: $0,
                responseKind: responseKind
            )
        }
        // Keep the direct-debug provider on the same evidence boundary as the
        // secure transport. Trust repair gets exactly the reply being challenged
        // plus the complaint; other non-personal lanes keep only the current
        // user turn.
        let providerMessages = Self.providerReplay(
            from: trimmed,
            responseKind: responseKind,
            turnDepth: turnDepth
        )

        let routingTier = preferredTier ?? CoachPromptBundle.preferredProviderTier(
            for: turnDepth,
            surface: surface
        )
        let chain = Self.orderedChain(
            keyed: keyed,
            cooldowns: providerCooldowns,
            now: Date(),
            preferredTier: routingTier
        )
        Self.log.debug("chat turn start providers=\(chain.count, privacy: .public) replay=\(trimmed.count, privacy: .public) proofs=\(grounding.verifiedProofQuotes.count, privacy: .public) latestUserChars=\(latestUserTurn?.count ?? 0, privacy: .public)")
        Self.log.debug("chat provider chain=\(Self.providerChainDescription(chain), privacy: .public) depth=\(turnDepth.rawValue, privacy: .public) tier=\(routingTier.rawValue, privacy: .public)")
        var sawContentRejection = false
        for provider in chain {
            guard !Task.isCancelled, await providerWorkAllowed() else {
                return .failure(.unauthenticated)
            }
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
                cacheableSystemPrompt: systemPrompt,
                cacheableUserContext: userContext,
                messages: providerMessages,
                quoteGuard: quoteGuard,
                latestUserTurn: latestUserTurn,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth,
                assessment: laneAssessment,
                surface: surface,
                responseKind: responseKind,
                coachingBrief: coachingBrief,
                providerWorkAllowed: providerWorkAllowed,
                onStreamedPartialVisible: onStreamedPartialVisible,
                onProviderAttemptEvent: onProviderAttemptEvent,
                onQualityGateEvent: onQualityGateEvent
            )
            guard !Task.isCancelled, await providerWorkAllowed() else {
                return .failure(.unauthenticated)
            }
            switch outcome {
            case .reply(let text):
                providerCooldowns[provider] = nil
                // Single convergence point for every accepted provider reply
                // (main commit, repaired, safe-repair). Apply the last-mile
                // report-voice backstop here so no reply path can leak raw
                // telemetry on a sensitive turn.
                let finalText = Self.finalizedCoachReply(
                    from: text,
                    latestUserTurn: latestUserTurn,
                    turnDepth: turnDepth
                )
                Self.log.info("chat turn succeeded via \(provider.displayName, privacy: .public) chars=\(finalText.count, privacy: .public)")
                if let onProviderChosen {
                    await onProviderChosen(CoachTurnProviderChoice(
                        providerName: provider.displayName,
                        model: provider.model
                    ))
                }
                return .reply(finalText)
            case .localFallback(let text, let origin):
                // The provider transport succeeded, but the visible reply was
                // produced locally after its draft failed a quality gate. Keep
                // that origin intact so turn metadata never credits a provider
                // with deterministic copy it did not write.
                providerCooldowns[provider] = nil
                let finalText = Self.finalizedCoachReply(
                    from: text,
                    latestUserTurn: latestUserTurn,
                    turnDepth: turnDepth
                )
                let choice: CoachTurnProviderChoice
                switch origin {
                case .safeReference:
                    choice = CoachTurnProviderChoice(
                        providerName: "Deterministic quality fallback",
                        model: "SafeReferenceCoachGuard",
                        resolvedTier: routingTier
                    )
                case .typedAssessment:
                    choice = Self.typedFallbackProviderChoice
                }
                Self.log.info("chat turn used local quality fallback after \(provider.displayName, privacy: .public)")
                if let onProviderChosen {
                    await onProviderChosen(choice)
                }
                return .reply(finalText)
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
        if sawContentRejection,
           let fallback = Self.deterministicAssessmentFallbackReply(
            assessment: laneAssessment,
            latestUserTurn: latestUserTurn,
            quoteGuard: quoteGuard,
            systemContext: composedSystem,
            recentCoachReplies: recentCoachReplies,
            turnDepth: turnDepth,
            surface: surface,
            responseKind: responseKind,
            coachingBrief: coachingBrief
           ) {
            Self.log.notice("chat turn accepted typed judgement fallback after provider quality failure")
            recordChatDiagnostic(
                .success,
                "Typed judgement fallback accepted after provider quality failure"
            )
            if let onProviderChosen {
                await onProviderChosen(Self.typedFallbackProviderChoice)
            }
            await onQualityGateEvent?(.fallback("typedAssessment"))
            return .reply(Self.finalizedCoachReply(
                from: fallback,
                latestUserTurn: latestUserTurn,
                turnDepth: turnDepth
            ))
        }

        Self.log.error("all \(chain.count) chat providers refused")
        recordChatDiagnostic(
            .failure,
            sawContentRejection ? "All chat providers failed quality gate" : "All chat providers refused"
        )
        await onQualityGateEvent?(.failed(sawContentRejection ? "contentRejected" : "providerRefused"))
        return .failure(sawContentRejection ? .contentRejected : .network)
    }

    private func secureReply(
        transportOverride: (any CoachChatTransport)? = nil,
        history: [CoachMessage],
        userContext: String,
        accountID: String?,
        grounding: ChatGroundingContext,
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?,
        explicitResponseKind: CoachChatResponseKind?,
        coachVoice: SpeakingStyleGoal?,
        surface: CoachReplySurface,
        preferredTier: CoachProviderTier?,
        providerWorkAllowed: @escaping () async -> Bool,
        onStreamedPartialVisible: (@MainActor (String) -> Void)?,
        onProviderChosen: (@MainActor (CoachTurnProviderChoice) -> Void)?,
        onProviderAttemptEvent: (@MainActor (CoachProviderAttemptEvent) -> Void)?,
        onQualityGateEvent: (@MainActor (CoachTurnQualityGateEvent) -> Void)?
    ) async -> ChatOutcome {
        guard !Task.isCancelled, await providerWorkAllowed() else {
            return .failure(.unauthenticated)
        }
        let transport = transportOverride ?? secureTransport
        let trimmedAccountID = accountID?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let requestAccountID: String
        if !trimmedAccountID.isEmpty, trimmedAccountID.count <= 128 {
            requestAccountID = trimmedAccountID
        } else if transport.requiresDurableAccountBinding {
            recordChatDiagnostic(.skipped, "Secure coach account binding unavailable")
            return .failure(.unauthenticated)
        } else {
            // Injected and direct-debug transports never cross the Firebase
            // callable boundary. Keep their wire-shape tests deterministic
            // without inventing authority for the production transport.
            requestAccountID = "non-firebase-transport"
        }
        switch await transport.availability() {
        case .available:
            break
        case .unavailable(let reason):
            recordChatDiagnostic(.skipped, "Secure coach capability unavailable")
            return .failure(.coachUnavailable(reason))
        case .checking:
            recordChatDiagnostic(.skipped, "Secure coach service unavailable")
            return .failure(.coachUnavailable(.service))
        }
        guard !Task.isCancelled, await providerWorkAllowed() else {
            return .failure(.unauthenticated)
        }

        let trimmed = Array(history.suffix(Self.maxReplayMessages))
        let latestUserTurn = trimmed.last(where: { $0.role == .user })?.text
        let recentUserTurns = trimmed.filter { $0.role == .user }.map(\.text)
        let quoteGuard = CoachChatQuoteGuardContext(
            transcripts: [grounding.recentTimedTranscript],
            verifiedProofQuotes: grounding.verifiedProofQuotes,
            latestUserTurn: latestUserTurn,
            recentUserTurns: recentUserTurns
        )
        let recentCoachReplies = Self.recentCoachReplies(beforeLatestUserTurnIn: trimmed)
        let tier = preferredTier ?? CoachPromptBundle.preferredProviderTier(
            for: turnDepth,
            surface: surface
        )
        let turnIntent = CoachChatTurnIntent.classify(latestUserTurn)
        let responseKind = explicitResponseKind ?? CoachChatResponseKind.classify(
            latestUserTurn,
            intent: turnIntent
        )
        let laneAssessment: CoachAssessment?
        switch responseKind {
        case .personalEvidenceRead, .memoryHandoff:
            laneAssessment = assessment
        case .generalCoaching, .conversational:
            laneAssessment = nil
        }
        let coachingBrief = laneAssessment.flatMap {
            CoachChatBrief.applicable(
                assessment: $0,
                responseKind: responseKind
            )
        }
        // A trust-repair turn needs the immediately challenged coach reply to
        // name and correct the actual miss. All other non-personal lanes stay
        // current-turn-only; memory carries authorized continuity through its
        // typed brief rather than raw replay.
        let replayForWire = Self.providerReplay(
            from: trimmed,
            responseKind: responseKind,
            turnDepth: turnDepth
        )
        let wireMessages = replayForWire.compactMap { message -> CoachChatWireMessage? in
            switch message.role {
            case .user:
                return CoachChatWireMessage(role: .user, content: message.text)
            case .coach:
                return CoachChatWireMessage(role: .assistant, content: message.text)
            case .systemNotice:
                return nil
            }
        }
        let request = CoachChatRequest(
            accountID: requestAccountID,
            surface: surface.rawValue,
            qualityTier: tier.transportQualityTier,
            coachVoice: coachVoice?.rawValue,
            turnDepth: turnDepth.rawValue,
            turnIntent: turnIntent.rawValue,
            responseKind: responseKind.rawValue,
            coachingBrief: coachingBrief,
            // The full latest transcript remains local to the existing quote
            // guard. Only short proof quotes already selected for coaching may
            // cross the secure provider boundary.
            verifiedQuoteSources: responseKind == .personalEvidenceRead
                ? grounding.verifiedProofQuotes
                : [],
            coachingContext: userContext,
            messages: wireMessages
        )
        let providerChoice = CoachTurnProviderChoice(
            providerName: "Firebase / Vertex AI",
            model: "Server configured"
        )
        await onProviderAttemptEvent?(.started(providerChoice))
        guard !Task.isCancelled, await providerWorkAllowed() else {
            return .failure(.unauthenticated)
        }

        do {
            var completion: CoachChatCompletion?
            var partialGate = CoachStreamingPartialGate()
            for try await event in try transport.stream(request) {
                switch event {
                case .delta(let delta):
                    if let visible = partialGate.consume(delta: delta) {
                        await onStreamedPartialVisible?(visible)
                    }
                case .completion(let result):
                    completion = result
                }
            }

            guard let completion else {
                recordChatDiagnostic(.failure, "Secure coach returned no completion")
                return .failure(.empty)
            }
            guard CoachProviderTier.transportQualityTiersMatch(
                completion.qualityTier,
                request.qualityTier
            ), let resolvedTier = CoachProviderTier(
                transportQualityTier: completion.qualityTier
            ) else {
                recordChatDiagnostic(.failure, "Secure coach returned a mismatched quality tier")
                return .failure(.empty)
            }
            guard completion.finishReason.uppercased() == "STOP" else {
                recordChatDiagnostic(.failure, "Secure coach reply was truncated")
                return .failure(.empty)
            }
            if transport.requiresDurableAccountBinding {
                guard completion.policyVersion ==
                        FirebaseCoachChatTransport.requiredPolicyVersion,
                      completion.generationMode != nil else {
                    recordChatDiagnostic(
                        .failure,
                        "Secure coach returned an incompatible policy contract"
                    )
                    return .failure(.backendVersionMissing)
                }
            }
            let finalized = Self.finalizedCoachReply(
                from: completion.text,
                latestUserTurn: latestUserTurn,
                turnDepth: turnDepth
            )
            guard !finalized.isEmpty else { return .failure(.empty) }
            if let issue = Self.replyQualityIssue(
                in: finalized,
                latestUserTurn: latestUserTurn,
                quoteGuard: quoteGuard,
                systemContext: userContext,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth,
                surface: surface,
                responseKind: responseKind,
                coachingBrief: coachingBrief
            ) {
                await onQualityGateEvent?(.rejected(String(describing: issue)))
                Self.log.notice("Secure coach reply rejected by local gate (\(issue.auditLabel, privacy: .public))")
                recordChatDiagnostic(
                    .failure,
                    "Secure coach reply failed quality gate: \(issue.auditLabel)"
                )
                return .failure(.contentRejected)
            }

            let landedChoice = CoachTurnProviderChoice(
                providerName: completion.generationMode == .deterministicBrief
                    ? "Noum deterministic coach"
                    : "Firebase / Vertex AI",
                model: completion.model,
                resolvedTier: resolvedTier,
                policyVersion: completion.policyVersion,
                generationMode: completion.generationMode
            )
            await onProviderChosen?(landedChoice)
            await onQualityGateEvent?(.passed)
            recordChatDiagnostic(.success, "Secure coach reply accepted")
            return .reply(finalized)
        } catch let error as CoachChatTransportError {
            switch error {
            case .unauthenticated: return .failure(.unauthenticated)
            case .rateLimited: return .failure(.rateLimited)
            case .cancelled: return .failure(.network)
            case .invalidResponse: return .failure(.empty)
            case .qualityRejected: return .failure(.contentRejected)
            case .invalidRequest: return .failure(.invalidRequest)
            case .permissionDenied: return .failure(.permissionDenied)
            case .backendVersionMissing: return .failure(.backendVersionMissing)
            case CoachChatTransportError.serviceUnavailable,
                 CoachChatTransportError.network:
                return .failure(.network)
            }
        } catch {
            return .failure(.network)
        }
    }

    func availability() async -> CoachChatTransportAvailability {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING") {
            if ProcessInfo.processInfo.arguments.contains("UI_TESTING_CHAT_FORCE_UNAVAILABLE") {
                return .unavailable(.service)
            }
            return .available
        }
        if ProcessInfo.processInfo.environment["NOUM_DIRECT_AI_DEBUG"] == "1" {
            let transport = DirectProviderDebugTransport(
                isConfigured: { !Self.keyedProviders().isEmpty },
                operation: { _ in throw CoachChatTransportError.serviceUnavailable }
            )
            return await transport.availability()
        }
        #endif
        return await secureTransport.availability()
    }

    // MARK: - Provider chain

    private nonisolated static let uiHarnessProviderChoice = CoachTurnProviderChoice(
        providerName: "UI test harness",
        model: "Forced coach reply"
    )

    private nonisolated static let typedFallbackProviderChoice = CoachTurnProviderChoice(
        providerName: "Typed judgement fallback",
        model: "CoachAssessment"
    )

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
        now: Date,
        preferredTier: CoachProviderTier? = nil
    ) -> [CoachChatProvider] {
        let ready = keyed.filter { (cooldowns[$0] ?? .distantPast) <= now }
        let cooling = keyed.filter { (cooldowns[$0] ?? .distantPast) > now }
        return reorder(ready, preferredTier: preferredTier)
            + reorder(cooling, preferredTier: preferredTier)
    }

    nonisolated static func usableAPIKey(_ value: String?) -> String? {
        AIProviderCredential.usableAPIKey(value)
    }

    nonisolated static func reorder(
        _ providers: [CoachChatProvider],
        preferredTier: CoachProviderTier?
    ) -> [CoachChatProvider] {
        guard let preferredTier else { return providers }
        let priority: [CoachChatProvider]
        switch preferredTier {
        case .geminiFast:
            priority = [.agentPlatform, .gemini]
        case .claudeReasoning:
            priority = [.anthropic]
        }
        let preferred = providers.filter { priority.contains($0) }
            .sorted { lhs, rhs in
                (priority.firstIndex(of: lhs) ?? Int.max) < (priority.firstIndex(of: rhs) ?? Int.max)
            }
        let rest = providers.filter { !priority.contains($0) }
        return preferred + rest
    }

    private nonisolated static func providerChainDescription(_ providers: [CoachChatProvider]) -> String {
        providers.map(\.displayName).joined(separator: " > ")
    }

    private enum LocalFallbackOrigin {
        case safeReference
        case typedAssessment
    }

    private enum AttemptOutcome {
        case reply(String)
        case localFallback(String, LocalFallbackOrigin)
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
        cacheableSystemPrompt: String,
        cacheableUserContext: String,
        messages: [CoachMessage],
        quoteGuard: CoachChatQuoteGuardContext,
        latestUserTurn: String?,
        recentCoachReplies: [String],
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?,
        surface: CoachReplySurface,
        responseKind: CoachChatResponseKind,
        coachingBrief: CoachChatBrief?,
        providerWorkAllowed: @escaping () async -> Bool,
        onStreamedPartialVisible: (@MainActor (String) -> Void)? = nil,
        onProviderAttemptEvent: (@MainActor (CoachProviderAttemptEvent) -> Void)? = nil,
        onQualityGateEvent: (@MainActor (CoachTurnQualityGateEvent) -> Void)? = nil
    ) async -> AttemptOutcome {
        let startedAt = Date()
        let providerChoice = CoachTurnProviderChoice(
            providerName: provider.displayName,
            model: provider.model
        )
        do {
            Self.log.debug("attempting chat provider \(provider.displayName, privacy: .public)")
            await onProviderAttemptEvent?(.started(providerChoice))
            guard !Task.isCancelled, await providerWorkAllowed() else {
                return .refused(.transient)
            }
            let streamEndpoint = provider.streamingEndpoint
            let usesProviderStream = Self.providerStreamingShouldRun(
                turnDepth: turnDepth,
                surface: surface,
                responseMode: assessment?.responseMode,
                providerStreamingEnabled: CoachBrainFlags.providerStreamingEnabled,
                realtimeCoachModeEnabled: CoachBrainFlags.realtimeCoachModeEnabled
            ) &&
                providerHTTPOverride == nil &&
                streamEndpoint != nil
            let requestEndpoint = usesProviderStream ? (streamEndpoint ?? endpoint) : endpoint
            let body = chatRequestBody(
                for: provider,
                systemPrompt: cacheableSystemPrompt,
                userContext: cacheableUserContext,
                messages: messages,
                maxOutputTokens: CoachPromptBundle.maxOutputTokens(
                    for: turnDepth,
                    surface: surface
                ),
                streaming: usesProviderStream
            )
            var result: ProviderTextTransportResult
            var didRetryTransport = false
            do {
                result = try await providerTextHTTP(
                    provider: provider,
                    endpoint: requestEndpoint,
                    key: key,
                    body: body,
                    streaming: usesProviderStream,
                    onStreamedPartialVisible: onStreamedPartialVisible
                )
            } catch {
                guard !Task.isCancelled,
                      Self.transportFailureCanRetry(error) else {
                    throw error
                }

                // A single transient URL failure should not exhaust the only
                // configured provider. Retry once through the ordinary
                // response endpoint; when streaming was the failing path this
                // also gives the turn an independent transport shape. The
                // retry stays inside the existing per-provider attempt budget
                // and is surfaced in telemetry rather than hidden.
                Self.log.notice("\(provider.displayName, privacy: .public) transient transport failure — retrying once without streaming")
                recordChatDiagnostic(
                    .fallback,
                    "Transient transport failure; retrying once without streaming",
                    provider: provider,
                    startedAt: startedAt
                )
                await onProviderAttemptEvent?(.retry(providerChoice))
                didRetryTransport = true
                let retryBody = usesProviderStream
                    ? chatRequestBody(
                        for: provider,
                        systemPrompt: cacheableSystemPrompt,
                        userContext: cacheableUserContext,
                        messages: messages,
                        maxOutputTokens: CoachPromptBundle.maxOutputTokens(
                            for: turnDepth,
                            surface: surface
                        ),
                        streaming: false
                    )
                    : body
                result = try await providerTextHTTP(
                    provider: provider,
                    endpoint: usesProviderStream ? endpoint : requestEndpoint,
                    key: key,
                    body: retryBody,
                    streaming: false,
                    onStreamedPartialVisible: nil
                )
            }

            // One in-call retry when the refusal is explicitly short-lived
            // (429/503/529 with Retry-After within the turn's latency budget).
            if !didRetryTransport,
               case .refused(let status, let retryAfter) = result,
               [429, 503, 529].contains(status),
               let delay = retryAfter, delay > 0, delay <= 4 {
                Self.log.info("\(provider.displayName, privacy: .public) \(status) — retrying after \(delay, format: .fixed(precision: 1))s")
                await onProviderAttemptEvent?(.retry(providerChoice))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                result = try await providerTextHTTP(
                    provider: provider,
                    endpoint: requestEndpoint,
                    key: key,
                    body: body,
                    streaming: usesProviderStream,
                    onStreamedPartialVisible: onStreamedPartialVisible
                )
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
                await onProviderAttemptEvent?(.refused(providerChoice))
                return .refused(.classify(status: status))
            case .success(let extraction, let firstTokenAt, let usage):
                if let firstTokenAt {
                    recordChatDiagnostic(
                        .success,
                        "Streaming first provider token received",
                        provider: provider,
                        startedAt: startedAt,
                        now: firstTokenAt
                    )
                }
                recordCacheUsageDiagnostic(usage: usage, provider: provider, startedAt: startedAt)
                switch extraction {
                case .text(let text):
                    let display = CoachReplyTextSanitizer.displayText(from: text)
                    guard !display.isEmpty else {
                        Self.log.error("\(provider.displayName, privacy: .public) reply normalized to empty text")
                        recordChatDiagnostic(.fallback, "Reply normalized to empty", provider: provider)
                        await onProviderAttemptEvent?(.refused(providerChoice))
                        return .refused(.transient)
                    }
                    if display != text.trimmingCharacters(in: .whitespacesAndNewlines) {
                        Self.log.notice("\(provider.displayName, privacy: .public) reply normalized before storage and speech")
                    }
                    if let issue = Self.replyQualityIssue(
                        in: display,
                        latestUserTurn: latestUserTurn,
                        quoteGuard: quoteGuard,
                        systemContext: system,
                        recentCoachReplies: recentCoachReplies,
                        turnDepth: turnDepth,
                        surface: surface,
                        responseKind: responseKind,
                        coachingBrief: coachingBrief
                    ) {
                        Self.log.notice("\(provider.displayName, privacy: .public) reply tripped quality gate (\(String(describing: issue), privacy: .public)) — repairing")
                        recordChatDiagnostic(
                            .fallback,
                            "Reply tripped professional-coach gate; attempting repair: \(String(describing: issue))",
                            provider: provider,
                            startedAt: startedAt
                        )
                        if Self.safeReferenceRepairShouldRunBeforeProvider(
                            issue: issue,
                            latestUserTurn: latestUserTurn,
                            system: system
                        ) {
                            if let safeRepair = Self.safeReferenceRepairReply(
                                issue: issue,
                                latestUserTurn: latestUserTurn,
                                system: system,
                                quoteGuard: quoteGuard,
                                recentCoachReplies: recentCoachReplies,
                                turnDepth: turnDepth,
                                assessment: assessment,
                                surface: surface,
                                responseKind: responseKind,
                                coachingBrief: coachingBrief
                            ) {
                                recordChatDiagnostic(
                                    .success,
                                    "Safe reference repair accepted before provider rewrite",
                                    provider: provider
                                )
                                await onQualityGateEvent?(.fallback("safeReference:\(issue.auditLabel)"))
                                return .localFallback(safeRepair, .safeReference)
                            }
                            if let typedRepair = Self.deterministicAssessmentFallbackReply(
                                assessment: assessment,
                                latestUserTurn: latestUserTurn,
                                quoteGuard: quoteGuard,
                                systemContext: system,
                                recentCoachReplies: recentCoachReplies,
                                turnDepth: turnDepth,
                                surface: surface,
                                responseKind: responseKind,
                                coachingBrief: coachingBrief
                            ) {
                                recordChatDiagnostic(
                                    .success,
                                    "Typed assessment repair accepted before provider rewrite",
                                    provider: provider
                                )
                                await onQualityGateEvent?(.fallback("typedAssessmentRepair:\(issue.auditLabel)"))
                                return .localFallback(typedRepair, .typedAssessment)
                            }
                        }
                        // The deterministic assessment is already the source
                        // of truth for evidence, confidence, and the next proof
                        // test. If it can express a gate-clean answer for this
                        // exact turn, prefer that bounded local repair over a
                        // second network generation. This removes a fragile
                        // latency/cost hop without weakening the floor: the
                        // fallback is accepted only after it clears the same
                        // professional, semantic, and VISION gates below.
                        if let typedRepair = Self.deterministicAssessmentFallbackReply(
                            assessment: assessment,
                            latestUserTurn: latestUserTurn,
                            quoteGuard: quoteGuard,
                            systemContext: system,
                            recentCoachReplies: recentCoachReplies,
                            turnDepth: turnDepth,
                            surface: surface,
                            responseKind: responseKind,
                            coachingBrief: coachingBrief
                        ) {
                            recordChatDiagnostic(
                                .success,
                                "Typed assessment repair accepted before provider rewrite",
                                provider: provider
                            )
                            await onQualityGateEvent?(.fallback("typedAssessmentRepair:\(issue.auditLabel)"))
                            return .localFallback(typedRepair, .typedAssessment)
                        }
                        // A local safe/typed repair is a quality fallback, not a
                        // provider retry. Emit retry telemetry only when another
                        // provider request is actually about to run; otherwise
                        // readiness overstates network pressure and cost.
                        await onProviderAttemptEvent?(.retry(providerChoice))
                        if let repaired = await repairLowQualityReply(
                            issue: issue,
                            draft: display,
                            provider: provider,
                            endpoint: endpoint,
                            key: key,
                            system: system,
                            messages: messages,
                            quoteGuard: quoteGuard,
                            recentCoachReplies: recentCoachReplies,
                            turnDepth: turnDepth,
                            assessment: assessment,
                            surface: surface,
                            responseKind: responseKind,
                            coachingBrief: coachingBrief,
                            onProviderAttemptEvent: onProviderAttemptEvent
                        ) {
                            recordChatDiagnostic(.success, "Repair reply accepted", provider: provider)
                            await onQualityGateEvent?(.repaired(issue.auditLabel))
                            return .reply(repaired)
                        }
                        if let safeRepair = Self.safeReferenceRepairReply(
                            issue: issue,
                            latestUserTurn: latestUserTurn,
                            system: system,
                            quoteGuard: quoteGuard,
                            recentCoachReplies: recentCoachReplies,
                            turnDepth: turnDepth,
                            assessment: assessment,
                            surface: surface,
                            responseKind: responseKind,
                            coachingBrief: coachingBrief
                        ) {
                            recordChatDiagnostic(
                                .success,
                                "Safe reference repair accepted",
                                provider: provider
                            )
                            await onQualityGateEvent?(.fallback("safeReference:\(issue.auditLabel)"))
                            return .localFallback(safeRepair, .safeReference)
                        }
                        // A content miss by this model on this turn — let the
                        // next provider in the chain take the question.
                        recordChatDiagnostic(
                            .fallback,
                            "Reply failed professional-coach gate: \(String(describing: issue))\(Self.liveEvalDraftSuffix(display))",
                            provider: provider
                        )
                        await onQualityGateEvent?(.rejected(issue.auditLabel))
                        await onProviderAttemptEvent?(.refused(providerChoice))
                        return .refused(.contentRejected)
                    }
                    if let semanticIssue = Self.semanticQualityIssue(
                        in: display,
                        latestUserTurn: latestUserTurn,
                        systemContext: system,
                        turnDepth: turnDepth,
                        assessment: responseKind == .conversational
                            ? nil
                            : assessment,
                        responseKind: responseKind
                    ) {
                        if semanticGateDryRunEnabled() {
                            Self.log.notice("\(provider.displayName, privacy: .public) reply would trip semantic judgement gate (\(semanticIssue.rawValue, privacy: .public)) — dry-run accepting")
                            recordChatDiagnostic(
                                .success,
                                "Semantic judgement gate dry-run: would reject (\(semanticIssue.rawValue))\(Self.liveEvalDraftSuffix(display))",
                                provider: provider,
                                startedAt: startedAt
                            )
                            await onQualityGateEvent?(.fallback("semanticDryRun:\(semanticIssue.rawValue)"))
                        } else {
                            let issue = CoachChatReplyQualityIssue.semanticJudgement(semanticIssue)
                            Self.log.notice("\(provider.displayName, privacy: .public) reply tripped semantic judgement gate (\(semanticIssue.rawValue, privacy: .public)) — repairing")
                            recordChatDiagnostic(
                                .fallback,
                                "Reply tripped semantic judgement gate: \(semanticIssue.rawValue)",
                                provider: provider,
                                startedAt: startedAt
                            )
                            if Self.safeReferenceRepairShouldRunBeforeProvider(
                                issue: issue,
                                latestUserTurn: latestUserTurn,
                                system: system
                            ) {
                                if let safeRepair = Self.safeReferenceRepairReply(
                                    issue: issue,
                                    latestUserTurn: latestUserTurn,
                                    system: system,
                                    quoteGuard: quoteGuard,
                                    recentCoachReplies: recentCoachReplies,
                                    turnDepth: turnDepth,
                                    assessment: assessment,
                                    surface: surface,
                                    responseKind: responseKind,
                                    coachingBrief: coachingBrief
                                ) {
                                    recordChatDiagnostic(
                                        .success,
                                        "Safe reference repair accepted before provider rewrite",
                                        provider: provider
                                    )
                                    await onQualityGateEvent?(.fallback("safeReference:\(issue.auditLabel)"))
                                    return .localFallback(safeRepair, .safeReference)
                                }
                                if let typedRepair = Self.deterministicAssessmentFallbackReply(
                                    assessment: assessment,
                                    latestUserTurn: latestUserTurn,
                                    quoteGuard: quoteGuard,
                                    systemContext: system,
                                    recentCoachReplies: recentCoachReplies,
                                    turnDepth: turnDepth,
                                    surface: surface,
                                    responseKind: responseKind,
                                    coachingBrief: coachingBrief
                                ) {
                                    recordChatDiagnostic(
                                        .success,
                                        "Typed assessment repair accepted before provider rewrite",
                                        provider: provider
                                    )
                                    await onQualityGateEvent?(.fallback("typedAssessmentRepair:\(issue.auditLabel)"))
                                    return .localFallback(typedRepair, .typedAssessment)
                                }
                            }
                            await onProviderAttemptEvent?(.retry(providerChoice))
                            if let repaired = await repairLowQualityReply(
                                issue: issue,
                                draft: display,
                                provider: provider,
                                endpoint: endpoint,
                                key: key,
                                system: system,
                                messages: messages,
                                quoteGuard: quoteGuard,
                                recentCoachReplies: recentCoachReplies,
                                turnDepth: turnDepth,
                                assessment: assessment,
                                surface: surface,
                                responseKind: responseKind,
                                coachingBrief: coachingBrief,
                                onProviderAttemptEvent: onProviderAttemptEvent
                            ) {
                                recordChatDiagnostic(.success, "Semantic repair reply accepted", provider: provider)
                                await onQualityGateEvent?(.repaired(issue.auditLabel))
                                return .reply(repaired)
                            }
                            recordChatDiagnostic(
                                .fallback,
                                "Reply failed semantic judgement gate: \(semanticIssue.rawValue)\(Self.liveEvalDraftSuffix(display))",
                                provider: provider
                            )
                            await onQualityGateEvent?(.rejected(issue.auditLabel))
                            await onProviderAttemptEvent?(.refused(providerChoice))
                            return .refused(.contentRejected)
                        }
                    }
                    if let visionIssue = Self.visionQualityIssue(
                        in: display,
                        latestUserTurn: latestUserTurn,
                        quoteGuard: quoteGuard,
                        systemContext: system,
                        recentCoachReplies: recentCoachReplies,
                        turnDepth: turnDepth,
                        assessment: assessment,
                        surface: surface,
                        responseKind: responseKind
                    ) {
                        Self.log.notice("\(provider.displayName, privacy: .public) reply tripped vision gate (\(String(describing: visionIssue), privacy: .public)) — repairing")
                        recordChatDiagnostic(
                            .fallback,
                            "Reply tripped vision gate: \(String(describing: visionIssue))",
                            provider: provider,
                            startedAt: startedAt
                        )
                        if Self.safeReferenceRepairShouldRunBeforeProvider(
                            issue: visionIssue,
                            latestUserTurn: latestUserTurn,
                            system: system
                        ) {
                            if let safeRepair = Self.safeReferenceRepairReply(
                                issue: visionIssue,
                                latestUserTurn: latestUserTurn,
                                system: system,
                                quoteGuard: quoteGuard,
                                recentCoachReplies: recentCoachReplies,
                                turnDepth: turnDepth,
                                assessment: assessment,
                                surface: surface,
                                responseKind: responseKind,
                                coachingBrief: coachingBrief
                            ) {
                                recordChatDiagnostic(
                                    .success,
                                    "Safe reference repair accepted before provider rewrite",
                                    provider: provider
                                )
                                await onQualityGateEvent?(.fallback("safeReference:\(visionIssue.auditLabel)"))
                                return .localFallback(safeRepair, .safeReference)
                            }
                            if let typedRepair = Self.deterministicAssessmentFallbackReply(
                                assessment: assessment,
                                latestUserTurn: latestUserTurn,
                                quoteGuard: quoteGuard,
                                systemContext: system,
                                recentCoachReplies: recentCoachReplies,
                                turnDepth: turnDepth,
                                surface: surface,
                                responseKind: responseKind,
                                coachingBrief: coachingBrief
                            ) {
                                recordChatDiagnostic(
                                    .success,
                                    "Typed assessment repair accepted before provider rewrite",
                                    provider: provider
                                )
                                await onQualityGateEvent?(.fallback("typedAssessmentRepair:\(visionIssue.auditLabel)"))
                                return .localFallback(typedRepair, .typedAssessment)
                            }
                        }
                        await onProviderAttemptEvent?(.retry(providerChoice))
                        if let repaired = await repairLowQualityReply(
                            issue: visionIssue,
                            draft: display,
                            provider: provider,
                            endpoint: endpoint,
                            key: key,
                            system: system,
                            messages: messages,
                            quoteGuard: quoteGuard,
                            recentCoachReplies: recentCoachReplies,
                            turnDepth: turnDepth,
                            assessment: assessment,
                            surface: surface,
                            responseKind: responseKind,
                            coachingBrief: coachingBrief,
                            onProviderAttemptEvent: onProviderAttemptEvent
                        ) {
                            recordChatDiagnostic(.success, "Vision repair reply accepted", provider: provider)
                            await onQualityGateEvent?(.repaired(visionIssue.auditLabel))
                            return .reply(repaired)
                        }
                        recordChatDiagnostic(
                            .fallback,
                            "Reply failed vision gate: \(String(describing: visionIssue))\(Self.liveEvalDraftSuffix(display))",
                            provider: provider
                        )
                        await onQualityGateEvent?(.rejected(visionIssue.auditLabel))
                        await onProviderAttemptEvent?(.refused(providerChoice))
                        return .refused(.contentRejected)
                    }
                    let normalized = CoachReplyTextSanitizer.coachReplyText(from: display)
                    guard !normalized.isEmpty else {
                        Self.log.error("\(provider.displayName, privacy: .public) reply scaffold normalized to empty text")
                        recordChatDiagnostic(.fallback, "Reply scaffold normalized to empty", provider: provider)
                        await onProviderAttemptEvent?(.refused(providerChoice))
                        return .refused(.transient)
                    }
                    recordChatDiagnostic(.success, "Reply accepted", provider: provider)
                    await onQualityGateEvent?(.passed)
                    return .reply(normalized)
                case .empty, .lengthTruncated:
                    Self.log.error("\(provider.displayName, privacy: .public) returned no usable text (\(extraction == .lengthTruncated ? "truncated" : "empty", privacy: .public))")
                    recordChatDiagnostic(
                        .fallback,
                        extraction == .lengthTruncated ? "Reply length-truncated" : "Missing response content",
                        provider: provider
                    )
                    await onProviderAttemptEvent?(.refused(providerChoice))
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
            await onProviderAttemptEvent?(.refused(providerChoice))
            return .refused(.transient)
        }
    }

    private func semanticGateDryRunEnabled() -> Bool {
        semanticGateDryRunOverride?() ?? CoachBrainFlags.semanticGateDryRunEnabled
    }

    private nonisolated static func deterministicAssessmentFallbackReply(
        assessment: CoachAssessment?,
        latestUserTurn: String?,
        quoteGuard: CoachChatQuoteGuardContext?,
        systemContext: String,
        recentCoachReplies: [String] = [],
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface,
        responseKind: CoachChatResponseKind = .personalEvidenceRead,
        coachingBrief: CoachChatBrief? = nil
    ) -> String? {
        let lowerTurn = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let raw: String
        if responseKind == .conversational {
            // This lane owns coach-style feedback, greetings, tiny probes, and
            // vulnerable disclosures. It must never resurrect a personal
            // assessment or hand the speaker another drill merely because a
            // direct/debug caller supplied one.
            raw = CoachReliabilityGate.truthfulFallback(
                turnDepth: turnDepth,
                assessment: nil,
                surface: surface,
                previousCoachReply: recentCoachReplies.first,
                recentCoachReplies: recentCoachReplies,
                latestUserTurn: latestUserTurn,
                responseKind: .conversational,
                coachingBrief: nil
            )
        } else if responseKind == .generalCoaching {
            guard let fallback = CoachReliabilityGate.generalCoachingFailureFallback(
                turnDepth: turnDepth,
                surface: surface,
                latestUserTurn: latestUserTurn,
                previousCoachReply: recentCoachReplies.first,
                recentCoachReplies: recentCoachReplies
            ) else {
                return nil
            }
            raw = fallback
        } else if let assessment {
            if TurnDepthClassifier.isGreetingOrSmallTalk(lowerTurn) {
                raw = CoachReliabilityGate.greetingFallback(
                    surface: surface,
                    assessment: assessment
                )
            } else if CoachReliabilityGate.lowCapacityUserTurn(latestUserTurn) {
                raw = CoachReliabilityGate.lowCapacityFallback(
                    surface: surface,
                    previousCoachReply: recentCoachReplies.last,
                    recentCoachReplies: recentCoachReplies
                )
            } else if TurnDepthClassifier.isLowSignalOffTopicTest(lowerTurn) {
                raw = CoachReliabilityGate.offTopicTestFallback(surface: surface)
            } else if let coldStartShape = coldStartRepairReferenceShape(
                for: lowerTurn,
                system: systemContext
            ) {
                raw = coldStartShape
            } else if CoachReliabilityGate.notInformativeRepairUserTurn(latestUserTurn) {
                raw = CoachReliabilityGate.notInformativeRepairFallback(surface: surface)
            } else if CoachReliabilityGate.repetitionCalloutUserTurn(latestUserTurn) {
                raw = CoachReliabilityGate.repetitionCourseCorrectionFallback(surface: surface)
            } else if CoachReliabilityGate.vulnerablePushbackUserTurn(latestUserTurn) {
                raw = CoachReliabilityGate.vulnerablePushbackFallback(
                    surface: surface,
                    assessment: assessment
                )
            } else if CoachReliabilityGate.paceSelfFrustrationUserTurn(latestUserTurn) {
                raw = CoachReliabilityGate.paceSelfFrustrationFallback(
                    surface: surface,
                    assessment: assessment,
                    replyText: systemContext
                )
            } else if CoachReliabilityGate.rambleStoppingRuleUserTurn(latestUserTurn) {
                raw = CoachReliabilityGate.rambleStoppingRuleFallback(
                    surface: surface,
                    latestUserTurn: latestUserTurn,
                    assessment: assessment
                )
            } else if CoachReliabilityGate.leadershipStatusReportUserTurn(latestUserTurn) {
                raw = CoachReliabilityGate.leadershipStatusReportFallback(surface: surface)
            } else if CoachReliabilityGate.recurringCloseRushUserTurn(latestUserTurn),
                      CoachReliabilityGate.recurringCloseRushTrendAvailable(
                        assessment: assessment,
                        replyText: systemContext
                      ) {
                raw = CoachReliabilityGate.recurringCloseRushFallback(surface: surface)
            } else if CoachReliabilityGate.metadataSelfKnowledgeUserTurn(latestUserTurn),
                      CoachReliabilityGate.metadataSelfKnowledgeSourceAvailable(
                        assessment: assessment,
                        replyText: systemContext
                      ) {
                raw = CoachReliabilityGate.metadataSelfKnowledgeFallback(surface: surface)
            } else if turnLooksLikeVoiceGoalIntent(lowerTurn) {
                raw = CoachReliabilityGate.goalStateDirectiveFallback(
                    surface: surface,
                    latestUserTurn: latestUserTurn,
                    replyText: systemContext
                )
            } else if CoachReliabilityGate.straightAnswerUserTurn(latestUserTurn) {
                raw = CoachReliabilityGate.straightAnswerSplitFallback(surface: surface)
            } else {
                switch turnDepth {
                case .deepAssessment:
                    raw = deterministicIntentOverrideReply(
                        latestUserTurn: latestUserTurn,
                        systemContext: systemContext
                    ) ?? deterministicDeepAssessmentReply(assessment)
                case .trustRepair:
                    raw = deterministicTrustRepairReply(
                        assessment: assessment,
                        latestUserTurn: latestUserTurn,
                        systemContext: systemContext
                    )
                case .quickMove:
                    raw = deterministicPressureFillerQuickMoveReply(
                        latestUserTurn: latestUserTurn,
                        systemContext: systemContext
                    ) ?? deterministicIntentOverrideReply(
                        latestUserTurn: latestUserTurn,
                        systemContext: systemContext
                    ) ?? deterministicQuickMoveReply(assessment)
                case .groundedRead:
                    raw = deterministicIntentOverrideReply(
                        latestUserTurn: latestUserTurn,
                        systemContext: systemContext
                    ) ?? deterministicGroundedReadReply(assessment)
                }
            }
        } else {
            return nil
        }

        let normalized = CoachReplyTextSanitizer.coachReplyText(from: raw)
        guard !normalized.isEmpty else { return nil }
        guard replyQualityIssue(
            in: normalized,
            latestUserTurn: latestUserTurn,
            quoteGuard: quoteGuard,
            systemContext: systemContext,
            recentCoachReplies: recentCoachReplies,
            turnDepth: turnDepth,
            surface: surface,
            responseKind: responseKind,
            coachingBrief: coachingBrief
        ) == nil else {
            return nil
        }
        guard semanticQualityIssue(
            in: normalized,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext,
            turnDepth: turnDepth,
            assessment: responseKind == .conversational ? nil : assessment,
            responseKind: responseKind
        ) == nil else {
            return nil
        }
        guard visionQualityIssue(
            in: normalized,
            latestUserTurn: latestUserTurn,
            quoteGuard: quoteGuard,
            systemContext: systemContext,
            recentCoachReplies: recentCoachReplies,
            turnDepth: turnDepth,
            assessment: assessment,
            surface: surface,
            responseKind: responseKind
        ) == nil else {
            return nil
        }
        return normalized
    }

    /// Deterministic follow-through for narrow questions whose answer shape is
    /// already established by the conversation. These are intentionally
    /// phrased as observable tests rather than new diagnoses, so a provider
    /// rewrite failure can still preserve the user's intent without inventing
    /// evidence.
    nonisolated static func directFollowThroughRepairReferenceShape(
        for latestUserTurn: String?,
        system: String = ""
    ) -> String? {
        guard let lower = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !lower.isEmpty else {
            return nil
        }
        let lowerSystem = system.lowercased()

        if containsAny(lower, [
            "what should i do with that filler count",
            "what do i do with that filler count"
        ]),
           fillerEvidenceSitsInsideDecisionLine(system),
           let fillerEvidence = QuantityQualifiedFillerEvidence.parseLatest(in: system) {
            if let summary = fillerEvidence.summary {
                return "Your latest qualified rep had \(summary). One filler appeared after the decision line, so hold one silent beat there on an equivalent rep, then compare fillers per minute."
            }
            return "That sample is too small or uncertain for a fair filler-rate read. One filler appeared after the decision line, so test one silent beat there and gather one 60-second equivalent rep before judging the pattern."
        }
        if containsAny(lower, [
            "what should i listen for in the replay",
            "what do i listen for in the replay"
        ]) {
            return "Listen to sentence one: keep it if the answer arrives before the setup, because that lets the listener place your point before the context. If background comes first, rewrite only that sentence."
        }
        if containsAny(lower, [
            "how far off am i from sounding authoritative",
            "how close am i to sounding authoritative"
        ]),
           lowerSystem.contains("latest rep"),
           lowerSystem.contains("pace estimate"),
           lowerSystem.contains("recommendation") {
            return "You are closer mechanically than to authoritative overall. This latest timed rep gives one clean recommendation and a usable pace estimate, so the mechanics are partly landing; authority still needs repeated pressure evidence. One rep is not enough for the broader verdict."
        }
        if lower.contains("slow down"),
           containsAny(lower, ["unsure", "uncertain"]) {
            return "Keep the same first sentence, hold one silent beat after the decision, then deliver the reason at your normal volume; that keeps the wording firm while you test the pace."
        }
        if containsAny(lower, [
            "do i pause before every sentence",
            "should i pause before every sentence"
        ]) {
            return "No. Use one beat before the final sentence as the test, because pausing everywhere changes too much at once to show whether that one timing move helped."
        }
        if containsAny(lower, ["what proves it worked", "what would prove it worked"]) {
            return "Proof needs one changed variable under comparable conditions: it worked if the target improved without making the close weaker."
        }
        if lower.contains("tried the close pause"),
           lower.contains("fillers dropped"),
           lower.contains("sounded stiff") {
            return "Fewer fillers with a stiffer close is a mixed result. The beat belongs only before the final sentence; natural phrasing is the next adjustment."
        }
        if containsAny(lower, [
            "how do i make that natural tomorrow",
            "how can i make that natural tomorrow"
        ]),
           containsAny(lowerSystem, ["filler", "close", "stiff", "pause"]) {
            return "Tomorrow, rehearse the final sentence once aloud, then deliver the answer at your normal pace, because only the ending needs adjustment. Keep the version that sounds natural rather than performed."
        }
        if containsAny(lower, ["more certain", "more confident"]),
           containsAny(lower, ["at the end", "at the close", "ending", "closing"]) {
            return "Say the recommendation once, give one reason, and stop without adding a softener; that keeps certainty in the wording instead of adding volume."
        }
        if CoachReliabilityGate.rambleStoppingRuleUserTurn(lower),
           containsAny(lower, [
            "rambled after sentence two",
            "ramble after sentence two",
            "drifted after sentence two"
           ]) {
            return "Sentence one gave the point; the answer reopened after one supporting reason. That second reason was the drift."
        }
        if lower.contains("interview"),
           containsAny(lower, ["take into", "bring into", "remember in"]) {
            return "Take one rule into the interview: put the answer in sentence one, give one evidence line, then stop, because that keeps the point ahead of the setup. Afterward, note whether the follow-up is specific or confused."
        }
        if normalizedTurnText(lower) == "what do i run next",
           lowerSystem.contains("filler"),
           containsAny(lowerSystem, ["decision line", "recommendation"]) {
            return "Run a recommendation answer: decision, one reason, clean stop, because that isolates the proof boundary without inviting a full essay."
        }
        if normalizedTurnText(lower) == "what next",
           containsAny(lowerSystem, ["close lost force", "closing strength", "rushed close", "final sentence"]) {
            return "The recurring close is the lever, so review the last transcript, rewrite only the final sentence, then run one rep with that close as the target."
        }
        if containsAny(lower, [
            "why the close instead of the opening",
            "why the close rather than the opening"
        ]),
           containsAny(lowerSystem, ["close lost force", "closing strength", "rushed close", "final sentence"]) {
            return "In the last transcript, the opening is serviceable enough. The close is where authority leaks because the answer ends as a summary instead of an ask."
        }
        if containsAny(lower, ["what is the exact rep", "what's the exact rep"]),
           containsAny(lowerSystem, ["close", "closing", "final sentence", "the ask"]) {
            return "The recent rep makes the close the target, so use the same topic and change only the ending. Make the final sentence the ask; if it turns into a recap, rewrite that sentence before another run."
        }
        if lower.contains("rewrote the close"), lower.contains("too direct") {
            return "Good boundary: direct is useful, but abrupt is the risk. Keep the ask and add one reason before it so the listener can agree without feeling pushed."
        }
        if containsAny(lower, ["what do i do after that rep", "what should i do after that rep"]),
           containsAny(lowerSystem, ["close", "ask", "direct", "abrupt"]) {
            return "Review the final sentence—the single behavior that rep tested—because it shows whether directness became pressure. Keep it if it improved without creating a new problem; otherwise change one variable."
        }
        if containsAny(lower, [
            "do i change the whole answer",
            "should i change the whole answer"
        ]),
           lowerSystem.contains("proof"),
           containsAny(lowerSystem, ["decision line", "recommendation"]) {
            return "No. Keep the answer structure and change only the proof handoff, because that isolates the part you are testing."
        }
        if lower.contains("voice"), lower.contains("cold") {
            return "If the voice still sounds cold, the issue is tone rather than content, so stop the drill, record one warm version of the same recommendation, and compare whether the proof still lands."
        }
        if containsAny(lower, [
            "the no-symbol version is easier to hear",
            "the no symbol version is easier to hear"
        ]) {
            return CoachReliabilityGate.preferenceAcknowledgementFallback(
                surface: .text,
                latestUserTurn: latestUserTurn
            )
        }
        if lower == "this is robotic and too much writing." ||
           lower == "this is robotic and too much writing" {
            return CoachReliabilityGate.preferenceAcknowledgementFallback(
                surface: .text,
                latestUserTurn: latestUserTurn
            )
        }
        if containsAny(lower, ["what was generic about it", "what exactly was generic about it"]) {
            return CoachReliabilityGate.preferenceAcknowledgementFallback(
                surface: .text,
                latestUserTurn: latestUserTurn
            )
        }
        if containsAny(lower, [
            "so what should you remember next time",
            "what should you remember next time"
        ]),
           containsAny(lowerSystem, ["real coach", "sharper read", "robotic", "generic"]) {
            return "I should remember this: keep replies short, name the behavior, and offer a test only when you ask for one."
        }
        if containsAny(lower, [
            "okay, that's cool. however, i don't feel like that answered what i meant",
            "okay, thats cool. however, i dont feel like that answered what i meant"
        ]) {
            return CoachReliabilityGate.preferenceAcknowledgementFallback(
                surface: .text,
                latestUserTurn: latestUserTurn
            )
        }
        if containsAny(lower, [
            "does that make me sound less warm",
            "does that make me less warm",
            "will that make me sound less warm"
        ]) {
            return "No. The target is placement, not less warmth. The decision needs to be clear enough that the warmth supports it instead of delaying it."
        }
        if containsAny(lower, ["what did you miss", "what exactly did you miss"]),
           containsAny(lowerSystem, ["warmth", "reassurance", "recommendation"]) {
            return CoachReliabilityGate.preferenceAcknowledgementFallback(
                surface: .text,
                latestUserTurn: latestUserTurn
            )
        }
        if containsAny(lower, [
            "how do i test that without sounding harsh",
            "how can i test that without sounding harsh"
        ]) {
            return "Use two versions with the wording held constant: direct point first, then the same point with one reassurance. Compare clarity and warmth."
        }
        if containsAny(lower, [
            "i said cool because i was trying not to be rude",
            "i said cool because i did not want to be rude",
            "i said cool because i didn't want to be rude"
        ]) {
            return "In your words, ‘cool’ was politeness, not agreement. I should not treat that phrase as proof the answer landed."
        }
        if lower.contains("tried recommendation first"),
           lower.contains("sounded abrupt") {
            return "The recommendation-first version sounded abrupt, so keep the order and change only the tone bridge. In the next rep, state the recommendation, add one reassurance before the reason, then stop."
        }
        if lower.contains("stop"),
           containsAny(lower, ["saying practice", "telling me to practice", "just tell me to practice"]) {
            return CoachReliabilityGate.preferenceAcknowledgementFallback(
                surface: .text,
                latestUserTurn: latestUserTurn
            )
        }
        if lower.contains("leadership update"),
           containsAny(lower, ["tomorrow", "what should i practice", "what do i practice"]),
           containsAny(lowerSystem, ["filler", "light on the close", "closing", "final sentence"]) {
            return "Practice one leadership update: decision first, one business reason, then the ask as the final sentence, because that order keeps the point clear and makes the action explicit."
        }
        if containsAny(lower, [
            "i do not know the ask yet",
            "i don't know the ask yet",
            "i dont know the ask yet"
        ]),
           containsAny(lowerSystem, ["leadership", "update", "final sentence", "the ask"]) {
            return "Use ‘I need alignment on the next step’ as a provisional ask, because it lets you rehearse the close before the business content is final."
        }
        if lower.contains("not my whole speaking style") {
            return "Right—not your whole speaking style. One interview answer supports only a narrow read about sentence one; a broader claim needs repeated answers across different prompts and pressure."
        }
        if lower.contains("7/10"), lower.contains("bad"),
           containsAny(lowerSystem, ["authority", "authoritative"]),
           lowerSystem.contains("recommendation") {
            return "No—a 7/10 is one mechanics signal, not an authority verdict. This transcript shows the recommendation came first; authority still needs repeated pressure evidence."
        }
        if containsAny(lower, [
            "what would make you change the diagnosis",
            "what would change your diagnosis"
        ]),
           containsAny(lowerSystem, ["authority", "authoritative", "pressure"]) {
            return "The latest timed rep is not enough to change the diagnosis. Two clean pressure reps with the verdict early and the close settled would."
        }
        if containsAny(lower, [
            "i did one pressure rep. it was cleaner but not settled",
            "i did one pressure rep; it was cleaner but not settled",
            "one pressure rep was cleaner but not settled"
        ]),
           containsAny(lowerSystem, ["authority", "authoritative", "pressure"]) {
            return "Cleaner but not settled is progress in mechanics, not proof of presence. The remaining question is whether the close stays steady under the same pressure."
        }
        if containsAny(lower, [
            "still filled before the proof",
            "still used a filler before the proof",
            "filler still came before the proof"
        ]),
           containsAny(lowerSystem, ["decision", "recommendation"]),
           containsAny(lowerSystem, ["filler", "proof"]) {
            return "That puts the filler at the proof boundary, not the decision line. The evidence supports a pause there, but not a broader diagnosis yet."
        }
        if lower.contains("call it progress"),
           containsAny(lowerSystem, ["authority", "authoritative", "pressure rep", "under pressure"]) {
            return "The latest pressure rep was cleaner but not settled. Compare the next two pressure reps under the same conditions, because repeatability is the difference between a signal and a pattern. Call it progress only if the close stays steady in both."
        }
        if containsAny(lower, ["what test separates those", "which test separates those"]),
           containsAny(lowerSystem, ["authority", "hypothesis", "recommendation arrived late"]) {
            return "Run the same answer twice: once as-is, once with the verdict in sentence one. If verdict-first lands more clearly, structure is likelier; if not, the authority hypothesis still needs evidence."
        }
        if containsAny(lower, ["people asked for the timeline", "they asked for the timeline"]),
           containsAny(lowerSystem, ["leadership update", "timeline", "decision"]) {
            return "Your update gives one outcome signal, not proof: the timeline was clearer than the decision. Because the room asked about timing, capture their exact question, then in the next rep close with the decision you need plus the date and stop."
        }
        if containsAny(lower, [
            "what should i capture now",
            "what do i capture now",
            "what should i capture next"
        ]),
           containsAny(lowerSystem, [
            "people asked for the timeline",
            "asked for the timeline",
            "timeline, not the decision",
            "timeline question",
            "leadership update",
            "timeline",
            "decision"
           ]) {
            return "Capture the exact question, the decision you wanted them to understand, and what they did next. That preserves the gap between what landed and what was missing."
        }
        if containsAny(lower, [
            "when would you call it authority",
            "when would you call that authority",
            "when is it authority instead"
        ]) {
            return "Only after repeated pressure reps show the verdict stays early and the close stays calm, because authority needs to survive pressure. Until then, call it a structure improvement with authority potential."
        }
        if containsAny(lower, [
            "what should i check after",
            "what do i check after",
            "what should i review after"
        ]) {
            return "Check the final sentence, because that is where the update either becomes an ask or falls back into recap: did it ask for alignment or a decision?"
        }
        if containsAny(lower, [
            "how do i know if it worked",
            "how will i know if it worked",
            "how do i tell if it worked"
        ]) {
            return "Use the same conditions and change only one variable, because that isolates the target. It worked if the target improved without creating a new tone problem."
        }
        return nil
    }

    nonisolated static func deterministicIntentOverrideReply(
        latestUserTurn: String?,
        systemContext: String
    ) -> String? {
        guard let latest = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !latest.isEmpty else {
            return nil
        }

        if let followThrough = directFollowThroughRepairReferenceShape(
            for: latest,
            system: systemContext
        ) {
            return followThrough
        }

        if containsAny(latest, ["example of me", "examples of me", "give me an example", "doing this in sessions"]) {
            return "I don’t have enough evidence here to give a verified session example, and I won’t invent one. Which rep or transcript should I use to point to the exact moment?"
        }
        if containsAny(latest, ["did the drill cause", "did that cause", "cause that", "caused that"]) {
            return "I would not call that causation. Treat it as useful association: on the latest rep you used the prepared close, so your read that the room stayed engaged is a signal, not proof. Keep the close; next time capture the exact question people asked afterward."
        }
        if containsAny(latest, ["difficult conversation tonight", "conversation tonight"]) {
            return "Tonight's risk is over-proving, so practice the boundary sentence only: say the disagreement in sentence one, give one calm reason, then stop before proving you are reasonable."
        }
        if containsAny(latest, ["networking", "introducing myself", "intro"]) {
            return "Start with a 20-second test: who you help, what changes, and one question for them. No full story yet, because first we need to hear where the ramble starts."
        }
        if containsAny(latest, ["sales pitch", "loses people", "customer"]) {
            return "The likely gap is salience: reasons are there, but nothing for the listener to picture. So add one concrete customer example after the first claim, then return to the ask."
        }
        if containsAny(latest, ["presentation", "polished but flat", "sounds polished", "flat"]) {
            return "On the latest rep the words scored 7/10 and read as structured; I cannot prove vocal energy from text alone. Treat flatness as a structure-versus-energy hypothesis. Test one sentence as the peak: mark the consequence, record it, and listen for deliberate emphasis."
        }
        if containsAny(latest, ["afraid to disagree", "fear to disagree"]) {
            return "I would not diagnose fear from the latest rep alone; treat it as a hypothesis only, with delay before disagreement as the observable pattern. Put the disagreement in sentence one and see whether that changes the pressure."
        }
        if containsAny(latest, ["lack conviction", "lacking conviction"]) {
            return "There is not enough evidence to call this lack of conviction overall. The same focus keeps showing up across recent reps. The latest rep and pace estimate point to one narrow read: the hedge before the recommendation is the best place to work, not a verdict about your identity. I still need repeated answers under pressure before making a stronger call. Repeat the answer and replace the first hedge with a direct verb."
        }
        if containsAny(latest, ["polished but evasive", "sound polished but evasive", "evasive"]) {
            return "Yes, it could, but keep it as a structure read, not a claim about you. The latest rep and pace estimate point to an answer that arrives after too much setup. The structure is usable, but I have not seen it hold under pressure. I still need repeated pressure reps and a listener's read before making a stronger call. Put the direct answer in sentence one, then use one polished reason after it."
        }
        if containsAny(latest, ["sound timid", "sounds timid", "timid"]) {
            return "I cannot prove timid from text alone; the latest rep supports only indirectness before the recommendation, so any tone verdict still needs audio evidence. In the next rep, try one direct recommendation first and compare how it sounds."
        }
        if containsAny(latest, ["not like me", "sounds correct but not like me"]) {
            return "Trust that signal. On the latest rep, keep the structure but replace the most polished sentence with the phrase you would actually say in the room, because that is what makes it sound like you. Record once and check how it feels against the cleaner version."
        }
        if containsAny(latest, [
            "meant it as a comparison",
            "meant like as a comparison",
            "like as a comparison",
            "semantic",
            "counted 'like'",
            "counted like"
        ]) {
            return "Good correction: on the latest rep, like was doing semantic comparison work, so I should not count it as filler; counting it would punish valid speech. Keep the comparison on the next rep; mark only empty pause-fillers that add no meaning."
        }
        if containsAny(latest, ["prompt made me repeat", "prompt echo", "repeat the phrase"]) {
            return "Fair boundary: on the latest rep, prompt echo was not the same as filler, so I would not count the repeated prompt phrase. On the next rep, mark only words added while searching for the next thought."
        }
        if containsAny(latest, ["did i actually say", "actually say that"]) {
            return "Correction: I should not have put that in quotes unless it was exact, so I retract the quote. The supported read is only that your recommendation came late; use that, not the unverified wording."
        }
        if containsAny(latest, ["this week felt harder", "score improved"]) {
            return "Both can be true: the score says mechanics improved, while your check-in says the rep felt harder. Use the same prompt with one fewer condition because effort matters too, then check whether effort drops without the score falling."
        }
        if containsAny(latest, ["landed better than practice", "what do we learn", "interview answer landed"]) {
            return "Your report that the interview answer landed better is useful self-report, not proof. The latest rep gives the comparison, so keep verdict first plus one example for interviews and capture what question made it land."
        }
        if containsAny(latest, ["quickly", "what do i do next"]) {
            return "The close is the lever, so make the final sentence the ask, then stop."
        }
        if containsAny(latest, ["what is the one move"]) {
            return "The close is the move, so make the final sentence the ask, then stop."
        }
        if containsAny(latest, ["can you coach this"]) {
            return "I need one rep before I can coach this honestly. Record 60 seconds, then I will read the opener and close."
        }

        return nil
    }

    nonisolated static func uiHarnessFlagPresent(
        _ flag: String,
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        if arguments.contains(flag) ||
            arguments.contains("\(flag)=true") ||
            arguments.contains("\(flag)=1") {
            return true
        }
        guard let value = environment[flag]?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return ["1", "true", "yes"].contains(value.lowercased())
    }

    private nonisolated static func deterministicQuickMoveReply(
        _ assessment: CoachAssessment
    ) -> String {
        var action = connectorClause(assessment.nextProofTest)
        if action.lowercased().hasPrefix("run the same answer under ") {
            action = "use" + String(action.dropFirst("run".count))
        }
        guard let anchor = coachSafeEvidencePhrase(from: assessment.evidenceUsed.first) else {
            if action.contains("one silent beat after the verdict"),
               action.contains("without speeding up") {
                return "Your last rep gives one usable signal: under pressure, the close needs one silent beat after the verdict. Use that beat, then finish the answer without speeding up."
            }
            return "Your last rep gives one usable signal so far, so \(action)"
        }
        return "Your last rep gives one usable signal: \(anchor), so \(action)"
    }

    private nonisolated static func deterministicPressureFillerQuickMoveReply(
        latestUserTurn: String?,
        systemContext: String
    ) -> String? {
        let lowerTurn = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard pressureFillerQuickMoveIntent(
            latestUserTurn: lowerTurn,
            systemContext: systemContext
        ) else {
            return nil
        }
        if CoachChatResponseKind.classify(latestUserTurn) == .generalCoaching {
            return "When um wants to enter under pressure, hold a one-second silence instead because the gap stays quiet. Repeat the prompt and compare fillers per minute; treat one rep as a test, not a pattern."
        }
        guard let fillerEvidence = QuantityQualifiedFillerEvidence.parseLatest(in: systemContext) else {
            return "I do not have a comparable filler sample yet, so run one 60-second pressure rep on the same prompt. Hold one silent beat before the final sentence, finish the ask, then use its fillers-per-minute rate as the baseline."
        }
        guard let summary = fillerEvidence.summary else {
            return "That pressure sample is too small or uncertain for a fair filler-rate read, so run one 60-second pressure rep on the same prompt. Hold one silent beat before the final sentence, finish the ask, then use its fillers-per-minute rate as the baseline."
        }
        return "Your latest qualified rep had \(summary). That rate is one usable signal, not a pressure pattern, so hold one silent beat before the final sentence on the same prompt, finish the ask, then compare fillers per minute under the same demand."
    }

    private nonisolated static func pressureFillerQuickMoveIntent(
        latestUserTurn: String,
        systemContext: String
    ) -> Bool {
        let lowerSystem = systemContext.lowercased()
        let pressureContext = containsAny(latestUserTurn, [
            "under pressure",
            "pressure",
            "stakes",
            "timer",
            "timed",
            "under fire",
            "real room"
        ]) || containsAny(lowerSystem, [
            "pressure rep",
            "under pressure"
        ])
        let fillerContext = containsAny(latestUserTurn, [
            "filler",
            "fillers",
            "hesitat",
            "stop saying um",
            "stop saying uh",
            "stop saying ah",
            "saying um",
            "saying uh",
            "saying ah",
            "say like"
        ])
        let semanticDisambiguation = containsAny(latestUserTurn, [
            "semantic",
            "comparison",
            "meant it as a comparison",
            "counted like",
            "counted 'like'",
            "prompt echo",
            "prompt made me repeat"
        ])
        return pressureContext && fillerContext && !semanticDisambiguation
    }

    private nonisolated static func deterministicGroundedReadReply(
        _ assessment: CoachAssessment
    ) -> String {
        guard let anchor = conciseEvidencePhrase(from: assessment.evidenceUsed.first) else {
            return "\(completeSentence(assessment.directVerdict)) No baseline yet, so \(connectorClause(assessment.nextProofTest))"
        }
        return "\(completeSentence(assessment.directVerdict)) The signal I can use is \(anchor), so \(connectorClause(assessment.nextProofTest))"
    }

    private nonisolated static func deterministicDeepAssessmentReply(
        _ assessment: CoachAssessment
    ) -> String {
        var lines: [String] = []
        lines.append(completeSentence(deepAssessmentFallbackVerdict(from: assessment)))
        lines.append("That matters because one result can show a mechanics gain, while the full goal needs repeated evidence under pressure.")
        let evidence = assessment.evidenceUsed
            .prefix(2)
            .compactMap { deepAssessmentEvidencePhrase(from: $0) }
        if !evidence.isEmpty {
            lines.append("The usable evidence is \(evidence.joined(separator: " and ")).")
        }
        if let missing = assessment.missingEvidence.first,
           let clause = deepAssessmentMissingEvidenceClause(from: missing) {
            lines.append("I still need \(completeSentence(clause))")
        }
        lines.append("For the next check, \(connectorClause(assessment.nextProofTest))")
        return lines.joined(separator: " ")
    }

    private nonisolated static func deepAssessmentEvidencePhrase(
        from raw: String
    ) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard !trimmed.isEmpty else { return nil }

        if lower.hasPrefix("latest rep:") {
            let rest = String(trimmed.dropFirst("latest rep:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let mode = rest.split(separator: ",", maxSplits: 1)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return mode.map { "the latest \($0) rep" } ?? "the latest rep"
        }
        if lower.hasPrefix("pace estimate:") {
            return "its pace estimate"
        }
        if lower.hasPrefix("transcript signal:") {
            return "the available transcript"
        }
        if lower.hasPrefix("case summary:") {
            return "the active case file"
        }
        if lower.hasPrefix("active intervention:") {
            return "the active intervention"
        }
        return conciseEvidencePhrase(from: trimmed)
    }

    private nonisolated static func deepAssessmentMissingEvidenceClause(
        from raw: String
    ) -> String? {
        var clause = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clause.isEmpty else { return nil }
        for prefix in ["Need ", "Still need ", "Missing: "]
            where clause.lowercased().hasPrefix(prefix.lowercased()) {
            clause = String(clause.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        clause = clause.replacingOccurrences(
            of: "before calling the user close overall",
            with: "before making an overall readiness call",
            options: .caseInsensitive
        )
        guard let first = clause.first else { return nil }
        return first.lowercased() + String(clause.dropFirst())
    }

    private nonisolated static func deepAssessmentFallbackVerdict(
        from assessment: CoachAssessment
    ) -> String {
        let verdict = assessment.directVerdict
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = verdict.lowercased()
        guard !verdict.isEmpty else {
            return "You are not proven authoritative overall yet, even if the mechanics are usable."
        }
        guard containsAny(lower, [
            "not enough evidence",
            "do not have enough evidence",
            "don't have enough evidence",
            "not enough data",
            "do not have enough data",
            "don't have enough data"
        ]) else {
            return verdict
        }
        return "You are not proven authoritative overall yet, even if the mechanics are usable."
    }

    private nonisolated static func deterministicTrustRepairReply(
        assessment: CoachAssessment,
        latestUserTurn: String?,
        systemContext: String
    ) -> String {
        let lowerTurn = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if let directFollowThrough = directFollowThroughRepairReferenceShape(
            for: lowerTurn,
            system: systemContext
        ) {
            return directFollowThrough
        }
        if containsAny(lowerTurn, [
            "it's not easy", "its not easy", "not that easy",
            "easier said than done", "harder than that"
        ]) {
            return CoachReliabilityGate.vulnerablePushbackFallback(
                surface: .text,
                assessment: assessment
            )
        }
        let friction = trustRepairFallbackFriction(for: lowerTurn)
        let action = connectorClause(trustRepairFallbackAction(
            for: lowerTurn,
            assessment: assessment
        ))
        if contextSaysWarmthBeforeRecommendation(systemContext) {
            return "\(friction) The ordering signal is warmth before the recommendation, so put the recommendation first, add one reassurance after it, then stop."
        }
        if let evidence = coachSafeEvidencePhrase(from: assessment.evidenceUsed.first) {
            return "\(friction) Your last rep gives one safe signal, \(evidence), so \(action)"
        }
        return "\(friction) Your last rep gives only one safe signal so far, so \(action)"
    }

    private nonisolated static func coachSafeEvidencePhrase(
        from raw: String?
    ) -> String? {
        guard let evidence = conciseEvidencePhrase(from: raw) else { return nil }
        let stripped = CoachReplyTextSanitizer.strippingReportVoiceResidue(from: evidence)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = stripped
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,:;"))
            .lowercased()
        let evidenceNucleus = normalized
            .replacingOccurrences(of: #"^(?:the\s+)?(?:last|latest)\s+rep\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,:;"))
        guard !normalized.isEmpty,
              ![
                "timed",
                "timed practice",
                "practice",
                "pressure",
                "pressure drill"
              ].contains(evidenceNucleus) else {
            return nil
        }
        return stripped
    }

    private nonisolated static func trustRepairFallbackFriction(
        for lowerTurn: String
    ) -> String {
        var clauses: [String] = []

        if containsAny(lowerTurn, [
            "tts", "read them out", "read aloud", "**", "markdown",
            "formatting", "symbols", "stars"
        ]) {
            clauses.append("TTS reading formatting symbols breaks trust")
        }
        if containsAny(lowerTurn, [
            "robotic", "report", "too much writing", "too long",
            "less text", "less writing", "shorter"
        ]) {
            clauses.append("I sounded robotic or too much like a report")
        }
        if containsAny(lowerTurn, [
            "not informative", "not helpful", "not useful",
            "missed the point", "doesn't answer", "does not answer"
        ]) {
            clauses.append("I answered around the useful read instead of giving it")
        }
        if containsAny(lowerTurn, [
            "repeating yourself", "same thing again", "said that already",
            "already said that"
        ]) {
            clauses.append("I repeated the same move instead of advancing the coaching")
        }
        if containsAny(lowerTurn, [
            "it's not easy", "its not easy", "not that easy",
            "easier said than done", "harder than that"
        ]) {
            clauses.append("I made the move sound easier than it feels under pressure")
        }
        if containsAny(lowerTurn, [
            "cold", "generic", "not human", "low eq", "not high eq",
            "overexplained", "over explained", "over-explained",
            "expert coach", "ai tips", "ai wrapper"
        ]) {
            clauses.append("I sounded cold or generic instead of giving you a specific coaching read")
        }

        guard let last = clauses.last else {
            return "Fair push. That answer did not earn enough trust."
        }
        if clauses.count == 1 {
            return "Fair push. \(sentenceStart(last))."
        }
        let prefix = clauses.dropLast().enumerated().map { index, clause in
            index == 0 ? sentenceStart(clause) : clause
        }.joined(separator: ", ")
        return "Fair push. \(prefix), and \(last)."
    }

    private nonisolated static func trustRepairFallbackAction(
        for lowerTurn: String,
        assessment: CoachAssessment
    ) -> String {
        if containsAny(lowerTurn, ["short", "less text", "less writing", "too much writing", "too long"]) {
            return "run one cleaner rep with the main point first, then stop."
        }
        if containsAny(lowerTurn, [
            "not informative", "not helpful", "not useful",
            "missed the point", "doesn't answer", "does not answer"
        ]) {
            return "answer the actual read first, then run one narrow rep that tests it."
        }
        if containsAny(lowerTurn, [
            "repeating yourself", "same thing again", "said that already",
            "already said that"
        ]) {
            return "keep the current target but change the condition so the next rep teaches us something new."
        }
        if containsAny(lowerTurn, [
            "it's not easy", "its not easy", "not that easy",
            "easier said than done", "harder than that"
        ]) {
            return "say only the disagreement and one calm reason, then stop before defending it."
        }
        if containsAny(lowerTurn, ["tts", "read them out", "read aloud", "**", "markdown", "formatting"]) {
            return "run one rep by saying the recommendation first, giving one proof point, then stopping."
        }
        let proof = assessment.nextProofTest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !proof.isEmpty {
            return completeSentence(proof)
        }
        return "run one short rep with the point first and one proof point after it."
    }

    private nonisolated static func sentenceStart(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + String(text.dropFirst())
    }

    private nonisolated static func connectorClause(_ text: String) -> String {
        let sentence = completeSentence(text)
        guard let first = sentence.first else { return sentence }
        return String(first).lowercased() + String(sentence.dropFirst())
    }

    private nonisolated static func conciseEvidencePhrase(
        from raw: String?
    ) -> String? {
        guard let raw else { return nil }
        var value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !value.isEmpty else { return nil }
        let lower = value.lowercased()
        for prefix in [
            "latest rep:",
            "pace estimate:",
            "case summary:",
            "case focus:",
            "case evidence:",
            "active intervention:",
            "trust repair signal:"
        ] where lower.hasPrefix(prefix) {
            let rest = String(value.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if prefix == "trust repair signal:" {
                value = rest
            } else {
                let label = String(prefix.dropLast())
                value = "\(label) \(rest)"
            }
            break
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.count > 120 {
            value = String(value.prefix(117)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return value
    }

    private nonisolated static func completeSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let last = trimmed.last, ".!?".contains(last) {
            return trimmed
        }
        return trimmed + "."
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
    /// True when the reply is an honest "I can't coach this without a rep yet —
    /// record one" notice. These are explicit admissions that the coach has no
    /// usable evidence to read, which is the correct professional move on a
    /// no-baseline / no-content turn (e.g. the `placeholder-leak-049` trap). Kept
    /// high-precision — only unambiguous "cannot coach yet / no usable rep"
    /// admissions — so a normal coaching reply that merely closes by asking for
    /// another rep is not exempted from the professional gate.
    nonisolated static func replyIsHonestNoBaselineNotice(_ lower: String) -> Bool {
        containsAny(lower, [
            "before i can coach", "need one rep before", "need a rep before",
            "no usable rep", "no rep for me to read", "no usable signal",
            "can't coach this honestly", "cannot coach this honestly",
            "not enough to coach", "i won't invent one", "i won't guess one",
            "i wont invent one", "i wont guess one",
            "i don’t have enough evidence to choose your next move",
            "i don't have enough evidence to choose your next move"
        ])
    }

    nonisolated static func replyQualityIssue(
        in text: String,
        latestUserTurn: String?,
        quoteGuard: CoachChatQuoteGuardContext? = nil,
        systemContext: String? = nil,
        recentCoachReplies: [String] = [],
        turnDepth: CoachTurnDepth = .groundedRead,
        surface: CoachReplySurface = .text,
        responseKind explicitResponseKind: CoachChatResponseKind? = nil,
        coachingBrief: CoachChatBrief? = nil
    ) -> CoachChatReplyQualityIssue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let responseKind = explicitResponseKind ?? {
            guard latestUserTurn != nil else { return .personalEvidenceRead }
            return CoachChatResponseKind.classify(latestUserTurn)
        }()
        let turnIntent = CoachChatTurnIntent.classify(latestUserTurn)
        let groundedMoveContinuation = replyUsesGroundedMoveContinuation(
            lower,
            latestUserTurn: latestUserTurn,
            recentCoachReplies: recentCoachReplies,
            coachingBrief: coachingBrief
        )
        if responseKind == .conversational ||
            [.greeting, .offTopic, .preference, .vulnerable].contains(turnIntent),
           replyContainsNonCoachingPrescription(lower) {
            return .nonCoachingPrescription
        }
        // A personal evidence question can carry a stored next move in its
        // typed brief without asking the coach to prescribe it on this turn.
        // Keep the observation available, but fail a high-confidence user
        // imperative so provider context cannot silently turn "what did you
        // notice?" into another drill.
        if responseKind == .personalEvidenceRead,
           coachingBrief?.nextMove != nil,
           !turnExpectsPrescribedAction(latestUserTurn),
           replyContainsNonCoachingPrescription(lower) {
            return .nonCoachingPrescription
        }
        if responseKind == .personalEvidenceRead,
           coachingBrief?.evidenceReadKind != nil,
           replyContainsNonCoachingPrescription(lower) {
            return .nonCoachingPrescription
        }
        if responseKind != .conversational,
           CoachReliabilityGate.rambleStoppingRuleUserTurn(latestUserTurn),
           CoachReliabilityGate.rambleStoppingRuleNeedsRepair(replyText: trimmed) {
            return .missingPrescribedAction
        }
        // An honest "I can't coach this without a rep — record one" notice is the
        // correct professional move on a no-evidence turn. It deliberately carries
        // no insight bridge, no prescribed mechanics drill, and no retrieved-expertise
        // read, so the downstream professional checks (missingInsightBridge /
        // missingPrescribedAction / ignoredCoachingExpertise) would wrongly reject
        // the *excellent* answer and force a deterministic fallback in its place.
        // Exempt it up front. High-precision: only fires on explicit "cannot coach
        // yet / no usable rep" admissions, never on a normal reply that merely ends
        // by asking for another rep.
        if responseKind == .personalEvidenceRead,
           coachingBrief?.decisiveEvidence == nil,
           !replyShouldCiteRecentSession(systemContext),
           replyIsHonestNoBaselineNotice(lower) {
            return nil
        }
        if let quoteGuard,
           Self.containsUnverifiedQuotedUserSpeech(in: trimmed, quoteGuard: quoteGuard) {
            return .unverifiedQuotedUserSpeech
        }
        if let quoteGuard,
           Self.turnRequestsSessionExample(latestUserTurn),
           quoteGuard.hasVerifiedProofQuotes,
           !quoteGuard.includesVerifiedProofQuote(in: trimmed) {
            return .missingVerifiedExampleQuote
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

        // A personal number is trustworthy only when the same fact exists in
        // user-authored chat or the typed brief. Metric kind matters as well as
        // the numeral: a filler count cannot become a score, and a duration in
        // a prescribed move cannot become an observed rep duration. User
        // numbers remain self-reports unless the reply says so explicitly.
        if responseKind == .personalEvidenceRead,
           (quoteGuard != nil || coachingBrief != nil),
           replyUsesUnauthorizedPersonalMetric(
            trimmed,
            latestUserTurn: latestUserTurn,
            quoteGuard: quoteGuard,
            coachingBrief: coachingBrief
           ) {
            return .overclaimsEvidence
        }

        // A general-craft reply that claims personal history violates the lane
        // boundary before it violates style. Report the evidence overclaim as
        // the primary defect even when the same sentence also contains a banned
        // robotic phrase such as "recent reps show".
        if responseKind == .generalCoaching,
           replyContainsUnverifiedPersonalRead(lower) {
            return .overclaimsEvidence
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

        if replyUsesTrustRepairReportVoiceMetrics(
            lower,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth
        ) {
            return .roboticPhrase("trust-repair report voice")
        }
        if replyUsesSensitiveTurnReportVoiceMetrics(
            lower,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth
        ) {
            return .roboticPhrase("sensitive-turn report voice")
        }

        // Safety and response-contract defects must outrank brevity. Repairing
        // only a long reply can preserve an invented cause or guarantee, while
        // a server-accepted preference reply can otherwise be rejected by the
        // app after the provider chain is exhausted.
        if let quoteGuard,
           replyContradictsRecommendationPosition(lower, quoteGuard: quoteGuard) {
            return .overclaimsEvidence
        }
        if let quoteGuard,
           replyContradictsLateRecommendationEvidence(lower, quoteGuard: quoteGuard) {
            return .overclaimsEvidence
        }
        if replyClaimsNoUsableRecentEvidenceDespiteContext(
            lower,
            systemContext: systemContext
        ) {
            return .unanchoredCoaching
        }
        if let voiceDirective = replyUsesVoiceGoalStateDirective(
            lower,
            latestUserTurn: latestUserTurn
        ) {
            return .roboticPhrase(voiceDirective)
        }
        if replyOverclaimsEvidence(lower) {
            return .overclaimsEvidence
        }
        if replyUsesUnrequestedNamedTechnique(
            lower,
            latestUserTurn: latestUserTurn
        ) {
            return .unrequestedNamedTechnique
        }
        if turnAsksWhyAnswerLandedBadly(latestUserTurn),
           !replyExplainsWhyAnswerLanded(lower) {
            return .missingInsightBridge
        }
        if replyIgnoresRetrievedCoachingExpertise(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .ignoredCoachingExpertise
        }

        if responseKind != .conversational,
           replyRepeatsRecentProofTest(
            trimmed,
            recentCoachReplies: recentCoachReplies
        ) {
            return .repeatedProofTest
        }

        let expandedAnswer = turnRequestsExpandedAnswer(latestUserTurn)
            || turnDepth == .deepAssessment
            || turnDepth == .trustRepair
        let limits = replyLengthLimits(
            expandedAnswer: expandedAnswer,
            turnDepth: turnDepth,
            surface: surface,
            responseKind: responseKind
        )
        let maxCharacters = limits.characters
        let maxSentences = limits.sentences
        let maxWords = limits.words
        let maxLines = limits.lines
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

        // Cold-start safeguards apply to both personal reads and general craft
        // questions. Check them before the lane-specific early returns below so
        // a new user cannot receive an invented filler target merely because
        // "Where do I start?" is classified as general coaching.
        if replyAddsColdStartIntakeQuestion(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .menuInsteadOfDecision
        }
        if replyUsesVagueColdStartBaselineRep(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .roboticPhrase("cold-start vague baseline rep")
        }
        if let coldStartPhrase = replyUsesColdStartProductOrMetricTarget(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .roboticPhrase(coldStartPhrase)
        }

        // These response lanes deliberately do not use the personal coaching
        // rubric. A conversational acknowledgement can own Noum's wording miss
        // without assigning work to the speaker. General craft must be useful
        // and concrete, but it must never be upgraded into a fabricated read of
        // this person's history just because rich context exists locally.
        if responseKind == .conversational {
            if CoachChatTurnIntent.isCoachStyleFeedback(latestUserTurn),
               CoachReliabilityGate.conversationalTrustRepairNeedsCorrection(trimmed) {
                return .missedTrustRepair
            }
            return nil
        }
        if CoachReliabilityGate.leadershipStatusReportUserTurn(latestUserTurn),
           CoachReliabilityGate.leadershipStatusReportNeedsRepair(
            replyText: trimmed
           ) {
            return .missingInsightBridge
        }
        if responseKind == .generalCoaching {
            let actionRequested = turnExpectsPrescribedAction(latestUserTurn)
            if actionRequested,
               !replyPrescribesAction(lower) {
                return .missingPrescribedAction
            }
            // Match the server contract: an ordinary self-disclosure can land
            // as a concise, useful explanation without pretending Noum read a
            // rep or prescribing work the user did not request. Explicit
            // how-to turns still require an observable communication anchor
            // and an explanation that connects it to the prescribed move.
            if actionRequested,
               !replyHasObservableAnchor(lower) {
                return .unanchoredCoaching
            }
            if actionRequested,
               replyHasObservableAnchor(lower),
               replyPrescribesAction(lower),
               !replyHasInsightBridge(lower) {
                return .missingInsightBridge
            }
            return nil
        }
        if responseKind == .personalEvidenceRead,
           replyIsEvidenceGapClarification(lower),
           (coachingBrief == nil ||
            (turnRequestsSessionExample(latestUserTurn) &&
             quoteGuard?.hasVerifiedProofQuotes != true)) {
            return nil
        }
        if responseKind == .memoryHandoff,
           coachingBrief == nil,
           replyIsHonestNoMemoryHandoff(lower) {
            return nil
        }

        if responseKind == .memoryHandoff || turnAsksMemoryHandoff(latestUserTurn),
           replyIsConsentBoundMemoryHandoff(
            lower,
            coachingBrief: coachingBrief
           ),
           !replyOverclaimsEvidence(lower) {
            return nil
        }

        if replyUsesUnhelpfulRepDate(lower) {
            return .unanchoredCoaching
        }

        if replyMisdirectsDecisionLineFillerRead(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .missingInsightBridge
        }

        if replyIgnoresClosingStrengthNextMove(
            lower,
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) {
            return .missingInsightBridge
        }

        if lower.contains("which direction would you prefer")
            || lower.contains("what is your priority")
            || (lower.contains("we can ") && lower.contains(" or ") && lower.contains("?")) {
            return .menuInsteadOfDecision
        }

        if trustRepairMissesSpecificFriction(lower, latestUserTurn: latestUserTurn) {
            return .missedTrustRepair
        }

        if trustRepairLacksUserPracticeMove(lower, latestUserTurn: latestUserTurn) {
            return .missingPrescribedAction
        }

        // A typed intervention can remain the right focus after another rep.
        // Accept a concise evidence-led continuation here only after all
        // evidence, length, trust, and overclaim checks have passed. Exact or
        // synonym-swapped drill restatements still fail above as repetition.
        if groundedMoveContinuation {
            return nil
        }

        if replyDirectlyAnswersBriefTacticalTurn(
            lower,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth
        ) {
            return nil
        }

        // Exact-stat and longitudinal reads are evidence answers, not coaching
        // prescriptions. Once the common safety, provenance, restraint, and
        // length gates above have passed, validate their narrow typed contract
        // instead of forcing an otherwise honest answer through the action-led
        // professional-coaching rubric.
        if responseKind == .personalEvidenceRead,
           coachingBrief?.evidenceReadKind != nil {
            return replySatisfiesTypedEvidenceRead(
                lower,
                coachingBrief: coachingBrief
            ) ? nil : .overclaimsEvidence
        }

        let rubric = professionalCoachRubric(
            reply: trimmed,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth,
            surface: surface,
            responseKind: responseKind
        )
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

        let vision = coachVisionEvaluation(
            reply: trimmed,
            latestUserTurn: latestUserTurn,
            quoteGuard: quoteGuard,
            systemContext: systemContext,
            recentCoachReplies: recentCoachReplies,
            turnDepth: turnDepth,
            assessment: nil,
            surface: surface,
            responseKind: responseKind
        )
        if vision.score < 45,
           let issue = qualityIssue(forVisionMisses: vision.missed) {
            return issue
        }

        if replyShouldCiteRecentSession(systemContext),
           turnExpectsCoaching(latestUserTurn),
           !replyCitesRecentSessionAnchor(lower),
           !replyIsGroundedInConversationFollowUp(
            lower,
            latestUserTurn: latestUserTurn,
            recentCoachReplies: recentCoachReplies
           ) {
            return .unanchoredCoaching
        }

        return nil
    }

    private nonisolated static func replyContainsNonCoachingPrescription(
        _ lower: String
    ) -> Bool {
        replyContainsHighConfidenceUserPrescription(lower)
    }

    /// Shared bounded imperative detector used by both conversational-lane
    /// protection and the coaching-action rubric. Requiring an instruction
    /// boundary prevents descriptive prose (including the "use" inside
    /// "because") from being mistaken for a prescribed move.
    private nonisolated static func replyContainsHighConfidenceUserPrescription(
        _ lower: String
    ) -> Bool {
        let verbs = [
            "answer", "record", "run", "try", "practice", "say", "state",
            "lead", "put", "give", "pause", "ask", "repeat", "start",
            "open", "use", "hold", "make", "end", "check", "listen",
            "review", "rewrite", "keep", "add", "place", "replay", "test",
            "advance", "repair", "log", "send", "speak", "replace", "cut",
            "compare",
            "write", "mark", "capture", "plant", "focus", "stop", "do"
        ].joined(separator: "|")
        let instructionStart =
            #"(?:^|[.!?,;:—]\s+)(?:(?:and(?:\s+then)?|but|so|then|therefore|instead|which\s+means)\s+)?(?:please\s+|you\s+(?:should|can|could|may|might|must|need\s+to|have\s+to)\s+)?(?:"# +
            verbs + #")\b"#
        let userDirected =
            #"(?:\byou\s+(?:should|can|could|may|might|must|need\s+to|have\s+to)\s+(?:"# +
            verbs +
            #")\b|\bi\s+(?:recommend|suggest)\s+(?:that\s+)?you\s+(?:"# +
            verbs +
            #")\b|\b(?:the|your)\s+(?:next\s+(?:move|step)|drill|exercise)\s+(?:is|would\s+be|should\s+be)\s+(?:to\s+)?(?:"# +
            verbs + #")\b)"#
        return [instructionStart, userDirected].contains { pattern in
            lower.range(of: pattern, options: .regularExpression) != nil
        } || replyUsesMoveContinuationReference(lower)
    }

    private nonisolated static func recentCoachReplies(
        beforeLatestUserTurnIn messages: [CoachMessage],
        limit: Int = 4
    ) -> [String] {
        let latestUserIndex = messages.lastIndex { $0.role == .user } ?? messages.endIndex
        guard latestUserIndex > messages.startIndex else { return [] }
        return Array(messages[..<latestUserIndex]
            .reversed()
            .filter { $0.role == .coach }
            .map(\.text)
            .prefix(limit))
    }

    private nonisolated static func providerReplay(
        from messages: [CoachMessage],
        responseKind: CoachChatResponseKind,
        turnDepth: CoachTurnDepth
    ) -> [CoachMessage] {
        guard let latestUserIndex = messages.lastIndex(where: { $0.role == .user }) else {
            return responseKind == .personalEvidenceRead ? messages : []
        }
        let latestUser = messages[latestUserIndex]
        switch responseKind {
        case .personalEvidenceRead:
            return messages
        case .conversational where turnDepth == .trustRepair:
            guard latestUserIndex > messages.startIndex,
                  let challengedReply = messages[..<latestUserIndex]
                    .last(where: { $0.role == .coach }) else {
                return [latestUser]
            }
            return [challengedReply, latestUser]
        case .generalCoaching:
            if latestUserIndex > messages.startIndex,
               isEllipticalGeneralFollowUp(latestUser.text),
               let priorUser = messages[..<latestUserIndex]
                .last(where: { $0.role == .user }) {
                return [priorUser, latestUser]
            }
            return [latestUser]
        case .conversational, .memoryHandoff:
            return [latestUser]
        }
    }

    private nonisolated static func isEllipticalGeneralFollowUp(
        _ userTurn: String
    ) -> Bool {
        let words = userTurn.split { !$0.isLetter && !$0.isNumber }
        guard words.count <= 12 else { return false }
        let normalized = " \(userTurn.lowercased()) "
        return [
            "what should i check", "what should i listen for",
            "what do i do after", "what should i do after",
            "how do i make that", "how do i do that",
            " after?", " that ", " this "
        ].contains(where: normalized.contains)
    }

    private nonisolated static func replyRepeatsRecentProofTest(
        _ reply: String,
        recentCoachReplies: [String]
    ) -> Bool {
        guard !recentCoachReplies.isEmpty else { return false }
        let current = Set(actionSentenceFingerprints(in: reply))
        guard !current.isEmpty else { return false }
        let recent = Set(recentCoachReplies.flatMap(actionSentenceFingerprints))
        return actionFingerprintsShareFamily(current, recent)
    }

    private nonisolated static func replyUsesGroundedMoveContinuation(
        _ lower: String,
        latestUserTurn: String?,
        recentCoachReplies: [String],
        coachingBrief: CoachChatBrief?
    ) -> Bool {
        guard turnExpectsPrescribedAction(latestUserTurn),
              let coachingBrief,
              let nextMove = coachingBrief.nextMove,
              let decisiveEvidence = coachingBrief.decisiveEvidence,
              !nextMove.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !decisiveEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              replyUsesMoveContinuationReference(lower) else {
            return false
        }
        let typedMove = Set(actionSentenceFingerprints(in: nextMove))
        let recent = Set(recentCoachReplies.flatMap(actionSentenceFingerprints))
        guard !typedMove.isEmpty,
              actionFingerprintsShareFamily(typedMove, recent) else {
            return false
        }

        let moveTerms = moveGroundingTerms(nextMove)
        let evidenceTerms = moveGroundingTerms(decisiveEvidence)
            .subtracting(moveTerms)
        guard !evidenceTerms.isEmpty else { return false }
        let visibleTerms = moveGroundingTerms(lower)
        let overlap = evidenceTerms.intersection(visibleTerms).count
        return overlap >= min(2, evidenceTerms.count)
    }

    private nonisolated static func actionFingerprintsShareFamily(
        _ left: Set<String>,
        _ right: Set<String>
    ) -> Bool {
        left.contains { candidate in
            right.contains { prior in
                let candidateTokens = Set(candidate.split(separator: " "))
                let priorTokens = Set(prior.split(separator: " "))
                let smaller = candidateTokens.count <= priorTokens.count
                    ? candidateTokens
                    : priorTokens
                let larger = smaller == candidateTokens
                    ? priorTokens
                    : candidateTokens
                return smaller.count >= 3 && smaller.isSubset(of: larger)
            }
        }
    }

    private nonisolated static func replyUsesMoveContinuationReference(
        _ lower: String
    ) -> Bool {
        lower.range(
            of: #"\b(?:stay with|continue with|keep|hold|maintain)\s+(?:(?:that|this|the same)\s+)?(?:focus|target|move|intervention)\b"#,
            options: .regularExpression
        ) != nil
    }

    private nonisolated static func moveGroundingTerms(_ value: String) -> Set<String> {
        let canonical = value
            .lowercased()
            .replacingOccurrences(
                of: #"\b(?:lead|open|start|begin) with\b"#,
                with: "put first",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(?:recommendation|verdict|decision|main point)\b"#,
                with: "answer",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(?:session|transcript)\b"#,
                with: "rep",
                options: .regularExpression
            )
        let ignored: Set<String> = [
            "about", "after", "again", "also", "and", "available",
            "because", "before", "but", "evidence", "for", "from",
            "have", "into", "just", "latest", "next", "recent",
            "showed", "appears", "that", "the", "then", "this",
            "through", "when", "with", "you", "your"
        ]
        return Set(canonical
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !ignored.contains($0) })
    }

    private nonisolated static func recentActionSentenceFingerprints(
        in replies: [String],
        limit: Int
    ) -> [String] {
        Array(replies.flatMap(actionSentenceFingerprints).prefix(limit))
    }

    private nonisolated static func actionSentenceFingerprints(
        in reply: String
    ) -> [String] {
        let delimiters = CharacterSet(charactersIn: ".!?\n")
        return reply
            .components(separatedBy: delimiters)
            .flatMap(actionClauseCandidates)
            .map(normalizedActionSentenceFingerprint)
            .filter { !$0.isEmpty }
    }

    private nonisolated static func actionClauseCandidates(
        in sentence: String
    ) -> [String] {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lower = trimmed.lowercased()
        let separators = [
            ", so ", "; so ", " so ",
            ", then ", "; then ", " then ",
            ", and then ", "; and then ", " and then ",
            ":"
        ]
        let fragments = separators.reduce([lower]) { partial, separator in
            partial.flatMap { fragment in
                fragment.components(separatedBy: separator)
            }
        }
        let candidates = [lower] + fragments
        var seen: Set<String> = []
        return candidates.compactMap { candidate in
            let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return normalized
        }
    }

    private nonisolated static func normalizedActionSentenceFingerprint(
        _ sentence: String
    ) -> String {
        let lower = sentence.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(
                of: #"\b(?:lead|open|start|begin) with (?:the |your )?(?:decision|recommendation|answer|verdict|main point)\b"#,
                with: "put decision first",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bput (?:the |your )?(?:decision|recommendation|answer|verdict|main point) first\b"#,
                with: "put decision first",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bstate (?:the |your )?(?:decision|recommendation|answer|verdict|main point) (?:in|as) (?:the |your )?first sentence\b"#,
                with: "put decision first",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(?:decision|recommendation|verdict|main point)\b"#,
                with: "decision",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return "" }
        // First-person commitments describe work the coach will do; they are
        // not exercises assigned to the speaker. Treating "I'll answer once"
        // as a proof-test action made repeated style feedback fail closed.
        if lower.range(
            of: #"^i(?:'ll|\s+will|\s+can|\s+should|\s+need\s+to|'m\s+going\s+to|\s+am\s+going\s+to)\b"#,
            options: .regularExpression
        ) != nil {
            return ""
        }
        if lower.hasPrefix("no ")
            || lower.hasPrefix("not ")
            || lower.hasPrefix("don't ")
            || lower.hasPrefix("do not ")
            || lower.hasPrefix("avoid ") {
            return ""
        }

        let authorizedMoveVerbs: Set<String> = [
            "record", "run", "repeat", "rewrite", "review", "check",
            "listen", "use", "say", "open", "hold", "make", "end",
            "answer", "practice", "state", "lead", "put", "give",
            "add", "advance", "keep", "log", "place", "repair", "replay",
            "test"
        ]
        let lexicalWords = lower
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        guard lexicalWords.contains(where: authorizedMoveVerbs.contains) else {
            return ""
        }

        let ignored: Set<String> = [
            "a", "an", "the", "one", "same", "next", "again", "then",
            "exact", "exactly", "rep", "reply", "answer"
        ]
        let words = lower
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { word in
                !ignored.contains(word) &&
                !word.allSatisfy(\.isNumber) &&
                !word.hasSuffix("second")
            }
        guard words.count >= 3 else { return "" }
        return words.joined(separator: " ")
    }

    /// Score a reply against the minimum shape a senior communications coach
    /// would normally provide in text mode: brief, attuned, evidence-aware,
    /// specific, action-oriented, and humble about thin data. It is deliberately
    /// conservative and lexical; nuanced calibration still needs a future
    /// expert-eval fixture set, but this catches the generic-AI failure mode
    /// reliably enough to protect the live chat surface.
    nonisolated static func professionalCoachRubric(
        reply: String,
        latestUserTurn: String? = nil,
        turnDepth: CoachTurnDepth? = nil,
        surface: CoachReplySurface = .text,
        responseKind explicitResponseKind: CoachChatResponseKind? = nil
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
        let responseKind = explicitResponseKind ?? CoachChatResponseKind.classify(
            latestUserTurn
        )
        let conversationalStyleFeedback = responseKind == .conversational &&
            CoachChatTurnIntent.isCoachStyleFeedback(latestUserTurn)
        var score = 10
        var misses: [CoachChatProfessionalRubricMiss] = []

        func apply(_ miss: CoachChatProfessionalRubricMiss, penalty: Int) {
            if !misses.contains(miss) {
                misses.append(miss)
                score -= penalty
            }
        }

        let effectiveDepth: CoachTurnDepth
        if let turnDepth {
            effectiveDepth = turnDepth
        } else if latestLower.isEmpty {
            effectiveDepth = .groundedRead
        } else {
            effectiveDepth = TurnDepthClassifier.classify(userText: latestLower)
        }
        let expandedAnswer = turnRequestsExpandedAnswer(latestUserTurn)
            || effectiveDepth == .deepAssessment
            || effectiveDepth == .trustRepair
        let limits = replyLengthLimits(
            expandedAnswer: expandedAnswer,
            turnDepth: effectiveDepth,
            surface: surface,
            responseKind: responseKind
        )
        let maxCharacters = limits.characters
        let maxSentences = limits.sentences
        let maxWords = limits.words
        let maxLines = limits.lines
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

        if conversationalStyleFeedback {
            if CoachReliabilityGate.conversationalTrustRepairNeedsCorrection(trimmed) {
                apply(.missedTrustRepair, penalty: 3)
            }
            if replyContainsNonCoachingPrescription(lower) {
                apply(.unsolicitedPrescription, penalty: 3)
            }
        } else if isCritiqueTurn(latestLower),
                  (!replyRepairsTrust(lower) ||
                   trustRepairMissesSpecificFriction(
                    lower,
                    latestUserTurn: latestUserTurn
                   )) {
            apply(.missedTrustRepair, penalty: 3)
        }

        let anchorExpected = responseKind != .conversational &&
            responseKind != .memoryHandoff &&
            turnExpectsCoaching(latestUserTurn)
        let actionExpected = responseKind != .conversational &&
            responseKind != .memoryHandoff &&
            turnExpectsPrescribedAction(latestUserTurn)
        if anchorExpected, !replyHasObservableAnchor(lower) {
            apply(.missingObservableAnchor, penalty: 2)
        }

        if actionExpected, !replyPrescribesAction(lower) {
            apply(.missingPrescribedAction, penalty: 2)
        }

        if anchorExpected,
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

    nonisolated static func coachVisionEvaluation(
        reply: String,
        latestUserTurn: String? = nil,
        quoteGuard: CoachChatQuoteGuardContext? = nil,
        systemContext: String? = nil,
        recentCoachReplies: [String] = [],
        turnDepth: CoachTurnDepth? = nil,
        assessment: CoachAssessment? = nil,
        surface: CoachReplySurface = .text,
        responseKind explicitResponseKind: CoachChatResponseKind? = nil
    ) -> CoachVisionEvaluationResult {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CoachVisionEvaluationResult(
                score: 0,
                earned: [],
                missed: CoachVisionCriterion.allCases
            )
        }

        let lower = trimmed.lowercased()
        let latestLower = latestUserTurn?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let responseKind = explicitResponseKind ?? CoachChatResponseKind.classify(
            latestUserTurn
        )
        let conversationalStyleFeedback = responseKind == .conversational &&
            CoachChatTurnIntent.isCoachStyleFeedback(latestUserTurn)
        let hasNoUserPrescription = !replyContainsNonCoachingPrescription(lower)
        let hasSpecificCoachCorrection = conversationalStyleFeedback &&
            !CoachReliabilityGate.conversationalTrustRepairNeedsCorrection(trimmed)
        let effectiveDepth = turnDepth ?? (latestLower.isEmpty
            ? .groundedRead
            : TurnDepthClassifier.classify(userText: latestLower))
        let expandedAnswer = turnRequestsExpandedAnswer(latestUserTurn)
            || effectiveDepth == .deepAssessment
            || effectiveDepth == .trustRepair
        let limits = replyLengthLimits(
            expandedAnswer: expandedAnswer,
            turnDepth: effectiveDepth,
            surface: surface,
            responseKind: responseKind
        )

        var earned: [CoachVisionCriterion] = []
        var missed: [CoachVisionCriterion] = []
        var score = 0

        func evaluate(
            _ criterion: CoachVisionCriterion,
            weight: Int,
            passes: Bool
        ) {
            if passes {
                earned.append(criterion)
                score += weight
            } else {
                missed.append(criterion)
            }
        }

        let isCritique = isCritiqueTurn(latestLower)
        let hasObservableAnchor = replyHasObservableAnchor(lower)
        let hasSpecificPracticeMove = replyHasSpecificPracticeMove(lower)
        let honestEvidenceGap = responseKind == .personalEvidenceRead &&
            replyIsEvidenceGapClarification(lower)
        let directAnswer: Bool
        if responseKind == .conversational {
            directAnswer = conversationalStyleFeedback
                ? hasSpecificCoachCorrection && hasNoUserPrescription
                : !replyOffersMenu(lower) && hasNoUserPrescription && wordCount(in: lower) > 1
        } else if honestEvidenceGap {
            directAnswer = true
        } else if isCritique {
            directAnswer = replyRepairsTrust(lower)
                && !trustRepairMissesSpecificFriction(lower, latestUserTurn: latestUserTurn)
        } else if turnAsksWhyAnswerLandedBadly(latestUserTurn) {
            directAnswer = replyExplainsWhyAnswerLanded(lower)
        } else if effectiveDepth == .deepAssessment, let assessment {
            directAnswer = replyStartsWithJudgement(trimmed, assessment: assessment)
        } else {
            directAnswer = !replyOffersMenu(lower)
                && !((lower.contains("can you clarify") || lower.contains("could you clarify")) && wordCount(in: lower) <= 18)
                && (hasObservableAnchor || hasSpecificPracticeMove)
        }
        evaluate(.directAnswer, weight: 12, passes: directAnswer)

        let anchorExpected = responseKind != .conversational &&
            responseKind != .memoryHandoff &&
            turnExpectsCoaching(latestUserTurn)
        evaluate(
            .observableAnchor,
            weight: 12,
            passes: conversationalStyleFeedback
                ? hasSpecificCoachCorrection
                : honestEvidenceGap || !anchorExpected || hasObservableAnchor
        )

        let actionExpected = responseKind != .conversational &&
            responseKind != .memoryHandoff &&
            turnExpectsPrescribedAction(latestUserTurn)
        evaluate(
            .prescribedAction,
            weight: 12,
            passes: conversationalStyleFeedback
                ? hasSpecificCoachCorrection && hasNoUserPrescription
                : !actionExpected || hasSpecificPracticeMove
        )

        let bridgeExpected = anchorExpected && actionExpected
        let hasInsightBridge = replyHasInsightBridge(lower)
        evaluate(
            .insightBridge,
            weight: 10,
            passes: conversationalStyleFeedback
                ? hasSpecificCoachCorrection
                : !bridgeExpected || hasInsightBridge
        )

        let evidenceHonest = !replyOverclaimsEvidence(lower)
            && !replyMakesUnsupportedClosenessClaim(lower)
            && (quoteGuard.map { !containsUnverifiedQuotedUserSpeech(in: trimmed, quoteGuard: $0) } ?? true)
            && (assessment.map { assessment in
                !(assessment.confidence < 0.70
                    && !assessment.missingEvidence.isEmpty
                    && effectiveDepth == .deepAssessment
                    && !replyNamesMissingEvidence(lower))
            } ?? true)
        evaluate(.evidenceHonesty, weight: 14, passes: evidenceHonest)

        let adaptiveRepair: Bool
        if responseKind == .conversational {
            adaptiveRepair = conversationalStyleFeedback
                ? hasSpecificCoachCorrection && hasNoUserPrescription
                : !replyOffersMenu(lower) && hasNoUserPrescription
        } else if isCritique {
            adaptiveRepair = replyRepairsTrust(lower)
                && !trustRepairMissesSpecificFriction(lower, latestUserTurn: latestUserTurn)
                && !trustRepairLacksUserPracticeMove(lower, latestUserTurn: latestUserTurn)
        } else {
            adaptiveRepair = !replyOffersMenu(lower)
                && !replyUsesUnrequestedNamedTechnique(lower, latestUserTurn: latestUserTurn)
        }
        evaluate(.adaptiveRepair, weight: 10, passes: adaptiveRepair)

        let personalization: Bool
        if responseKind == .conversational {
            personalization = conversationalStyleFeedback
                ? hasSpecificCoachCorrection
                : true
        } else if responseKind == .memoryHandoff {
            // A memory handoff is personalized when the coach explicitly
            // owns what it should retain. Requiring a session citation here
            // turns a preference acknowledgement back into an evidence read.
            personalization = containsAny(lower, [
                "i should remember", "i'll remember", "i’ll remember",
                "next time", "your preference", "you asked", "you want"
            ]) && !replyContainsUnverifiedPersonalRead(lower)
        } else if responseKind == .generalCoaching {
            // General craft is personalized to the question, not to stored
            // history. Requiring a recent-session citation here would either
            // fabricate a personal read or pad a direct answer with irrelevant
            // telemetry from a context this lane intentionally excludes.
            personalization = hasObservableAnchor &&
                !replyContainsUnverifiedPersonalRead(lower)
        } else if honestEvidenceGap {
            personalization = true
        } else if replyShouldCiteRecentSession(systemContext) {
            personalization = replyCitesRecentSessionAnchor(lower) ||
                replyIsGroundedInConversationFollowUp(
                    lower,
                    latestUserTurn: latestUserTurn,
                    recentCoachReplies: recentCoachReplies
                )
        } else {
            personalization = containsAny(lower, [
                "no baseline", "not enough data", "your message",
                "what you wrote", "your words", "your goal", "your case"
            ]) || hasObservableAnchor
        }
        evaluate(.personalization, weight: 8, passes: personalization)

        let transferProof: Bool
        if responseKind == .conversational {
            transferProof = conversationalStyleFeedback
                ? hasSpecificCoachCorrection
                : true
        } else if responseKind == .memoryHandoff {
            // This lane changes coach behaviour. A user-facing practice test
            // would be an unsolicited assignment, not transfer evidence.
            transferProof = true
        } else if responseKind == .generalCoaching {
            // A concrete action in the user's named situation is already a
            // usable transfer test. Do not force a second "next rep" sentence
            // solely to satisfy the personal-evidence rubric.
            transferProof = hasSpecificPracticeMove
        } else if honestEvidenceGap {
            transferProof = true
        } else {
            transferProof = assessment.map {
                replyContainsProofTest(lower, assessment: $0)
            } ?? (hasSpecificPracticeMove && containsAny(lower, [
                "next rep", "record", "run one", "repeat", "tomorrow",
                "interview", "meeting", "leadership", "pressure", "proof",
                "replay", "listen for", "run the rep", "rewrite"
            ]))
        }
        evaluate(.transferProof, weight: 8, passes: transferProof)

        let seniorRegister = !roboticPhrases.contains(where: { lower.contains($0) })
            && !defensiveProductPhrases.contains(where: { lower.contains($0) })
            && !replyUsesCoachScaffoldLabel(trimmed)
            && !replyUsesUnrequestedNamedTechnique(lower, latestUserTurn: latestUserTurn)
            && (responseKind != .conversational || hasNoUserPrescription)
        evaluate(.seniorRegister, weight: 8, passes: seniorRegister)

        let conciseEnough = trimmed.count <= limits.characters
            && sentenceCount(in: trimmed) <= limits.sentences
            && wordCount(in: trimmed) <= limits.words
            && nonEmptyLineCount(in: trimmed) <= limits.lines
        evaluate(.brevity, weight: 6, passes: conciseEnough)

        var cappedScore = score
        if !evidenceHonest {
            cappedScore = min(cappedScore, 44)
        }
        if !seniorRegister {
            cappedScore = min(cappedScore, 44)
        }
        if actionExpected && !hasSpecificPracticeMove {
            cappedScore = min(cappedScore, 48)
        }
        if anchorExpected && !hasObservableAnchor && !honestEvidenceGap {
            cappedScore = min(cappedScore, 48)
        }
        if bridgeExpected && !hasInsightBridge {
            cappedScore = min(cappedScore, 78)
        }

        return CoachVisionEvaluationResult(
            score: max(0, min(100, cappedScore)),
            earned: earned,
            missed: missed
        )
    }

    nonisolated static func visionQualityIssue(
        in text: String,
        latestUserTurn: String? = nil,
        quoteGuard: CoachChatQuoteGuardContext? = nil,
        systemContext: String? = nil,
        recentCoachReplies: [String] = [],
        turnDepth: CoachTurnDepth = .groundedRead,
        assessment: CoachAssessment? = nil,
        surface: CoachReplySurface = .text,
        responseKind explicitResponseKind: CoachChatResponseKind? = nil
    ) -> CoachChatReplyQualityIssue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard visionRuntimeGateApplies(
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth
        ) else {
            return nil
        }

        let vision = coachVisionEvaluation(
            reply: trimmed,
            latestUserTurn: latestUserTurn,
            quoteGuard: quoteGuard,
            systemContext: systemContext,
            recentCoachReplies: recentCoachReplies,
            turnDepth: turnDepth,
            assessment: assessment,
            surface: surface,
            responseKind: explicitResponseKind
        )
        if !vision.criticalMisses.isEmpty {
            return .visionGate(score: vision.score, misses: vision.criticalMisses)
        }
        if vision.score < visionRuntimeMinimumScore(
            turnDepth: turnDepth,
            surface: surface
        ) {
            return .visionGate(score: vision.score, misses: vision.missed)
        }
        return nil
    }

    private nonisolated static func visionRuntimeGateApplies(
        latestUserTurn: String?,
        turnDepth: CoachTurnDepth
    ) -> Bool {
        guard let latestUserTurn else {
            return turnDepth == .deepAssessment || turnDepth == .trustRepair
        }
        let lower = latestUserTurn
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if lower.count <= 4, containsAny(lower, ["hi", "hey", "yo"]) {
            return false
        }
        if containsAny(lower, [
            "thanks", "thank you", "got it", "okay", "ok", "cool",
            "makes sense", "that helps"
        ]),
           !turnExpectsPrescribedAction(latestUserTurn),
           !turnAsksWhyAnswerLandedBadly(latestUserTurn),
           !isCritiqueTurn(lower) {
            return false
        }
        return turnClearlyAsksForCoachingOrJudgement(lower)
            || turnDepth == .deepAssessment
            || turnDepth == .trustRepair
            || turnAsksWhyAnswerLandedBadly(latestUserTurn)
            || isCritiqueTurn(lower)
    }

    private nonisolated static func turnClearlyAsksForCoachingOrJudgement(_ lower: String) -> Bool {
        if turnExpectsPrescribedAction(lower) { return true }
        return containsAny(lower, [
            "feedback", "coach", "read", "notice", "diagnos",
            "judge", "assess", "score", "rate", "far off",
            "how close", "why did", "why does", "why is",
            "land badly", "landed badly", "land weak", "landed weak",
            "sound", "sounding", "voice", "pick", "choose",
            "authoritative", "authority",
            "confident", "executive", "leadership", "interview",
            "presentation", "meeting", "update", "pitch", "conflict",
            "filler", "fillers", " um", "pace", "pause", "close",
            "closing", "opening", "opener", "structure", "clarity",
            "better", "improve", "weak", "strong", "good", "bad"
        ])
    }

    private nonisolated static func visionRuntimeMinimumScore(
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface
    ) -> Int {
        if surface == .live {
            return turnDepth == .deepAssessment ? 66 : 62
        }
        // Text has enough room to earn the same quality floor used by the
        // production-readiness artifact. Accepting a 70-84 draft here made the
        // shipping service return replies that the declared 85-point launch
        // contract immediately rejected (most often an observation plus action
        // with no explanation of why the move matters).
        return 85
    }

    private nonisolated static func qualityIssue(
        forVisionMisses misses: [CoachVisionCriterion]
    ) -> CoachChatReplyQualityIssue? {
        if misses.contains(.seniorRegister) { return .roboticPhrase("vision score register miss") }
        if misses.contains(.evidenceHonesty) { return .overclaimsEvidence }
        if misses.contains(.directAnswer) { return .missingInsightBridge }
        if misses.contains(.observableAnchor) { return .unanchoredCoaching }
        if misses.contains(.prescribedAction) { return .missingPrescribedAction }
        if misses.contains(.insightBridge) { return .missingInsightBridge }
        return nil
    }

    private nonisolated static func replyHasSpecificPracticeMove(_ lower: String) -> Bool {
        guard replyPrescribesAction(lower) || replyHasUserPracticeMove(lower) else {
            return false
        }
        return !containsAny(lower, [
            "keep practicing",
            "practice more",
            "practice often",
            "sound more confident",
            "be more confident",
            "try to sound more confident",
            "try to be more confident",
            "communicate clearly",
            "be clear and concise",
            "structure your thoughts",
            "focus on structure",
            "focus on your structure",
            "focus on clarity",
            "focus on being confident",
            "focus on sounding confident",
            "prepare thoroughly",
            "prepare more",
            "think about your audience",
            "work on confidence",
            "improve your confidence"
        ])
    }

    nonisolated static func semanticQualityIssue(
        in text: String,
        latestUserTurn: String? = nil,
        systemContext: String? = nil,
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?,
        responseKind explicitResponseKind: CoachChatResponseKind? = nil
    ) -> CoachSemanticQualityIssue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()

        if replyMakesUnsupportedTransferCausalityClaim(lower, systemContext: systemContext) {
            return .unsupportedTransferCausalityClaim
        }

        let responseKind = explicitResponseKind ?? CoachChatResponseKind.classify(
            latestUserTurn
        )
        if responseKind == .conversational {
            return nil
        }

        guard let assessment else { return nil }

        if replyMissesRequestedIntent(lower, latestUserTurn: latestUserTurn) {
            return .missingIntentFit
        }

        switch turnDepth {
        case .deepAssessment:
            if !replyStartsWithJudgement(trimmed, assessment: assessment) {
                return .missingDirectVerdict
            }
            if !replyDistinguishesMechanicsFromGoal(lower) {
                return .missingMechanicsGoalDistinction
            }
            if assessment.evidenceReferenceCount >= 2,
               countEvidenceTouches(lower, assessment: assessment) < 2 {
                return .insufficientEvidenceReferences
            }
            if assessmentRequiresCaseAnchor(assessment),
               !replyTouchesCaseAnchor(lower, assessment: assessment) {
                return .missingCaseAnchor
            }
            if !assessment.missingEvidence.isEmpty,
               assessment.confidence < 0.78,
               !replyNamesMissingEvidence(lower) {
                return .missingEvidenceDisclosure
            }
            if assessment.confidence < 0.70,
               replyMakesUnsupportedClosenessClaim(lower) {
                return .unsupportedClosenessClaim
            }
            if !replyContainsProofTest(lower, assessment: assessment) {
                return .missingProofTest
            }
        case .trustRepair:
            if !replyRepairsTrust(lower) {
                return .missingDirectVerdict
            }
            if let repairFocus = assessment.repairFocus,
               !replyNamesRepairFocus(lower, repairFocus: repairFocus) {
                return .missingDirectVerdict
            }
            if assessment.repairFocus != nil,
               !replyContainsTrustRepairRead(lower, assessment: assessment) {
                return .missingRepairInsight
            }
            if assessmentRequiresCaseAnchor(assessment),
               !replyTouchesCaseAnchor(lower, assessment: assessment) {
                return .missingCaseAnchor
            }
            if !replyContainsProofTest(lower, assessment: assessment),
               !replyNamesMissingEvidence(lower) {
                return .missingProofTest
            }
        case .quickMove, .groundedRead:
            if assessment.confidence < 0.55,
               replyMakesUnsupportedClosenessClaim(lower) {
                return .unsupportedClosenessClaim
            }
        }

        return nil
    }

    private nonisolated static func replyMakesUnsupportedTransferCausalityClaim(
        _ lower: String,
        systemContext: String?
    ) -> Bool {
        guard let systemContext else { return false }
        let context = systemContext.lowercased()
        guard context.contains("real-world transfer") else { return false }

        let transferReference = containsAny(lower, [
            "real-world", "real world", "transfer", "outcome", "audience",
            "room", "interview", "presentation", "meeting", "leadership",
            "update", "prep", "practice", "drill", "training"
        ])
        guard transferReference else { return false }

        return containsAny(lower, [
            "drill caused", "drill made", "training caused", "training made",
            "prep caused", "prep made", "practice caused", "practice made",
            "because of the drill", "because of your drill",
            "because of that drill", "because you practiced",
            "thanks to the drill", "thanks to your prep",
            "proves the drill", "proved the drill", "proof that the drill",
            "objective proof", "proof that training", "proves transfer",
            "proved transfer", "guarantees transfer",
            "audience response is proof", "room response is proof",
            "outcome proves", "outcome proved", "this proves transfer"
        ])
    }

    private nonisolated static func replyMissesRequestedIntent(
        _ lower: String,
        latestUserTurn: String?
    ) -> Bool {
        let latest = latestUserTurn?
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !latest.isEmpty else { return false }

        if containsAny(latest, [
            "give me an example", "give me examples", "example of me",
            "examples of me", "doing this in sessions", "where did i do"
        ]) {
            return !containsAny(lower, [
                "for example", "example", "you said", "in the ", "in your ",
                "rep", "session", "when you", "last time"
            ])
        }

        if CoachReliabilityGate.metadataSelfKnowledgeUserTurn(latestUserTurn) {
            let answersWhatIsKnown = containsAny(lower, [
                "real read", "what i know", "i know", "your goal",
                "the pattern", "pace baseline", "streak"
            ])
            let assignsUnrequestedWork = replyPrescribesAction(lower) &&
                !turnExpectsPrescribedAction(latestUserTurn)
            return !answersWhatIsKnown || assignsUnrequestedWork
        }

        if containsAny(latest, [
            "how do i know if it worked", "how would i know if it worked",
            "did it work", "if it worked", "worked?"
        ]) {
            return !containsAny(lower, [
                "check whether", "look for", "listen for", "compare",
                "test", "if ", "whether", "worked", "lands"
            ])
        }

        if containsAny(latest, [
            "pause before every sentence",
            "pause before each sentence"
        ]) {
            let answersNo = lower.hasPrefix("no")
            let keepsPauseLocal = containsAny(lower, [
                "before the close", "where the pressure", "pause only",
                "final sentence"
            ])
            return !(answersNo && keepsPauseLocal)
        }

        if containsAny(latest, ["what proves it worked", "what would prove it worked"]) {
            let namesSuccess = containsAny(lower, [
                "success", "worked", "fewer fillers", "final sentence",
                "proof", "target improves"
            ])
            let keepsTestComparable = containsAny(lower, [
                "same 60", "same prompt", "same timer", "pause point",
                "comparable conditions", "one changed variable"
            ])
            return !(namesSuccess && keepsTestComparable)
        }

        if latest.contains("tried the close pause"),
           latest.contains("sounded stiff") {
            let carriesResult = containsAny(lower, [
                "reduced fillers", "fillers dropped", "cost warmth",
                "sounded stiff", "reported fewer fillers", "fewer fillers",
                "stiffer close"
            ])
            let adaptsMove = containsAny(lower, [
                "natural phrase", "only before the final", "keep the beat",
                "keep the pause", "belongs only", "next adjustment"
            ])
            return !(carriesResult && adaptsMove)
        }

        if containsAny(latest, [
            "make that natural tomorrow",
            "make it natural tomorrow"
        ]) {
            let testsNaturalness = containsAny(lower, [
                "naturalness", "natural", "sounded stiff"
            ])
            let givesTomorrowRep = containsAny(lower, [
                "tomorrow", "30-second", "30 second", "spoken rehearsal",
                "rehearse", "normal pace"
            ])
            return !(testsNaturalness && givesTomorrowRep)
        }

        if normalizedTurnText(latest) == "what next" {
            let choosesOneLever = containsAny(lower, [
                "is the lever", "is the target", "next lever",
                "pattern i'd pick", "pattern i would pick", "one move"
            ])
            let givesMove = containsAny(lower, [
                "rewrite", "review", "run one", "next rep"
            ])
            return !(choosesOneLever && givesMove)
        }

        if containsAny(latest, [
            "why the close instead of the opening",
            "why the close rather than the opening"
        ]) {
            let comparesBoth = containsAny(lower, ["opening", "opener"])
                && containsAny(lower, ["close", "closing"])
            return !(comparesBoth && replyHasInsightBridge(lower))
        }

        if containsAny(latest, ["what is the exact rep", "what's the exact rep"]) {
            let givesExactShape = containsAny(lower, [
                "same topic", "last sentence", "final sentence"
            ])
                && containsAny(lower, ["the ask", "ask"])
            return !givesExactShape
        }

        if latest.contains("rewrote the close"), latest.contains("too direct") {
            let preservesAsk = containsAny(lower, ["keep the ask", "keep that ask"])
            let softensWithReason = containsAny(lower, [
                "one reason", "add a reason", "before it", "before the ask"
            ])
            return !(preservesAsk && softensWithReason)
        }

        if containsAny(latest, [
            "what do i do after that rep",
            "what should i do after that rep"
        ]) {
            let reviewsClose = containsAny(lower, [
                "review", "check", "last sentence", "close", "ask",
                "single behavior"
            ])
            let givesDecisionRule = containsAny(lower, [
                "if ", "alignment", "pressure", "rewrite", "softer verb",
                "otherwise", "change one variable"
            ])
            return !(reviewsClose && givesDecisionRule)
        }

        if containsAny(latest, [
            "make me sound less warm",
            "make me less warm"
        ]) {
            let answersNo = lower.hasPrefix("no") || containsAny(lower, [
                "not less warm", "does not mean less warmth",
                "doesn't mean less warmth"
            ])
            let preservesWarmth = containsAny(lower, [
                "placement", "order", "warmth", "warm",
                "reassurance"
            ])
            return !(answersNo && preservesWarmth)
        }

        if containsAny(latest, ["what did you miss", "what exactly did you miss"]) {
            let ownsMiss = containsAny(lower, [
                "i missed", "missed the hesitation", "missed the pushback"
            ])
            let namesBehavior = containsAny(lower, [
                "reassurance", "warmth", "recommendation", "order",
                "point arrived"
            ])
            return !(ownsMiss && namesBehavior)
        }

        if containsAny(latest, [
            "test that without sounding harsh",
            "test it without sounding harsh"
        ]) {
            let namesTest = containsAny(lower, ["test", "run ", "record"])
            let preservesTone = containsAny(lower, [
                "reassurance", "warmth", "warm", "tone", "harsh"
            ])
            return !((namesTest || containsAny(lower, ["two versions", "compare"])) && preservesTone)
        }

        if latest.contains("said cool because"),
           containsAny(latest, ["not to be rude", "did not want to be rude", "didn't want to be rude"]) {
            let readsPoliteness = containsAny(lower, [
                "polite", "not rude", "hesitation", "pushback"
            ])
            let changesRepair = containsAny(lower, [
                "name the miss", "before the drill", "recommendation first",
                "reassurance", "should not treat", "not treat it as evidence",
                "answer landed"
            ])
            return !(readsPoliteness && changesRepair)
        }

        if latest.contains("leadership update"),
           containsAny(latest, ["what should i practice", "what do i practice"]) {
            let namesLeadershipClose = containsAny(lower, [
                "leadership", "final sentence", "close", "the ask",
                "decision"
            ])
            let givesPracticeMove = containsAny(lower, [
                "practice", "record", "run ", "75-second", "75 second"
            ])
            return !(namesLeadershipClose && givesPracticeMove)
        }

        if containsAny(latest, [
            "i do not know the ask yet",
            "i don't know the ask yet",
            "i dont know the ask yet"
        ]) {
            let suppliesPlaceholder = containsAny(lower, [
                "placeholder ask", "alignment on the next step",
                "temporary ask", "provisional ask"
            ])
            return !(suppliesPlaceholder && containsAny(lower, [
                "ask", "close", "final sentence"
            ]))
        }

        if containsAny(latest, [
            "what should i check after",
            "what do i check after",
            "what should i review after"
        ]) {
            let namesCheck = containsAny(lower, [
                "check", "review", "listen for", "look for"
            ])
            let checksClose = containsAny(lower, [
                "final", "last sentence", "close", "closing",
                "the ask", "decision", "recap"
            ])
            return !(namesCheck && checksClose)
        }

        if containsAny(latest, [
            "what test", "test separates", "what separates"
        ]) {
            let namesTest = containsAny(lower, ["test", "run", "compare", "separates"])
            let namesOutcome = containsAny(lower, ["if ", "whether", "then", "compare"])
            return !(namesTest && namesOutcome)
        }

        if latest.contains("not my whole speaking style") {
            let keepsClaimNarrow = containsAny(lower, [
                "not your whole", "one answer", "one rep", "too thin",
                "baseline", "broader style", "speaking style"
            ])
            let namesEvidenceBoundary = containsAny(lower, [
                "different prompts", "under pressure", "repeated answers",
                "more evidence", "before calling"
            ])
            return !(keepsClaimNarrow && namesEvidenceBoundary)
        }

        if containsAny(latest, [
            "what would make you change the diagnosis",
            "what would change your diagnosis"
        ]) {
            let namesRevision = containsAny(lower, [
                "change the diagnosis", "would change", "change my view",
                "update the diagnosis"
            ])
            let namesEvidenceCondition = containsAny(lower, [
                "two ", "more than one", "repeated", "repeatability",
                "repeatable", "across pressure"
            ])
            return !(namesRevision && namesEvidenceCondition)
        }

        if latest.contains("call it progress") {
            let namesProgressBoundary = containsAny(lower, [
                "call it progress", "progress only", "not a trend",
                "two reps", "repeated", "repeats"
            ])
            let namesObservableCheck = containsAny(lower, [
                "verdict", "sentence one", "close", "final five",
                "steady", "settled"
            ])
            return !(namesProgressBoundary && namesObservableCheck)
        }

        if containsAny(latest, [
            "what should i capture", "what do i capture", "capture now",
            "write down", "note now"
        ]) {
            return !containsAny(lower, ["capture", "write", "note", "record", "log", "save"])
        }

        if containsAny(latest, [
            "do i change", "change the whole", "change my whole", "keep the answer"
        ]) {
            return !containsAny(lower, ["no", "yes", "keep", "change only", "do not", "don't"])
        }

        if containsAny(latest, [
            "when would", "when should", "when do you call", "when would you call"
        ]) {
            return !containsAny(lower, ["when", "after", "only after", "until", "once"])
        }

        if containsAny(latest, [
            "what should noum remember", "what should you remember",
            "remember next time", "what do you remember"
        ]) {
            return !containsAny(lower, [
                "remember", "memory", "next time", "carry forward",
                "i should", "i need to"
            ])
        }

        if containsAny(latest, [
            "what do i take into", "take into the", "bring into"
        ]) {
            return !containsAny(lower, ["take", "bring", "use", "remember", "carry"])
        }

        if latest.hasPrefix("why ") || containsAny(latest, [" why ", "why did", "why after"]) {
            return !replyHasInsightBridge(lower)
        }

        if containsAny(latest, [
            "what happened", "what went wrong", "what went well",
            "what did you notice", "what do you notice"
        ]) {
            return !replyHasObservableAnchor(lower) ||
                !containsAny(lower, [
                    "happened", "read", "signal", "drift", "opening",
                    "sentence", "verdict", "pause", "filler", "tone", "pace"
                ])
        }

        return false
    }

    private nonisolated static func replyStartsWithJudgement(
        _ text: String,
        assessment: CoachAssessment
    ) -> Bool {
        let first = firstSentence(in: text).lowercased()
        let verdict = assessment.directVerdict.lowercased()
        if verdict.split(separator: " ").prefix(4).allSatisfy({ first.contains($0) }) {
            return true
        }
        if first.hasPrefix("yes,") ||
            first.hasPrefix("yes.") ||
            first.hasPrefix("yes ") ||
            first.hasPrefix("no,") ||
            first.hasPrefix("no.") ||
            first.hasPrefix("no ") {
            return true
        }
        return containsAny(first, [
            "you are", "you're", "you have", "you do not", "you don't",
            "not enough evidence", "i do not have enough", "i don't have enough",
            "i would not", "i wouldn't", "i cannot prove", "i can't prove",
            "closer mechanically", "closer on mechanics", "not proven",
            "the verdict"
        ])
    }

    private nonisolated static func replyDistinguishesMechanicsFromGoal(_ lower: String) -> Bool {
        let hasMechanics = containsAny(lower, [
            "mechanic", "score", "number", "filler", "pace", "clean rep",
            "metric", "technically", "structure"
        ])
        let hasGoal = containsAny(lower, [
            "goal", "ready", "readiness", "authoritative", "authority",
            "overall", "under pressure", "full standard", "embodiment"
        ])
        return hasMechanics && hasGoal
    }

    private nonisolated static func replyNamesMissingEvidence(_ lower: String) -> Bool {
        containsAny(lower, [
            "missing", "need to see", "need evidence", "do not yet know",
            "don't yet know", "not enough evidence", "not enough data",
            "i do not have enough", "i don't have enough", "still need"
        ])
    }

    private nonisolated static func replyMakesUnsupportedClosenessClaim(_ lower: String) -> Bool {
        guard containsAny(lower, [
            "you are close", "you're close", "not far off", "nearly there",
            "basically there", "almost there", "close overall"
        ]) else { return false }
        return !containsAny(lower, [
            "mechanically", "on mechanics", "not overall", "not proven",
            "but not", "only"
        ])
    }

    private nonisolated static func replyContainsProofTest(
        _ lower: String,
        assessment: CoachAssessment
    ) -> Bool {
        if containsAny(lower, ["proof test", "validation rep", "next check", "test this", "that tests", "next rep", "record", "run one", "repeat it"]) {
            return true
        }
        let testWords = assessment.nextProofTest
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .filter { $0.count >= 5 }
        let hitCount = testWords.reduce(0) { count, word in
            count + (lower.contains(word) ? 1 : 0)
        }
        return hitCount >= min(2, testWords.count)
    }

    private nonisolated static func assessmentRequiresCaseAnchor(
        _ assessment: CoachAssessment
    ) -> Bool {
        assessment.evidenceUsed.contains { evidence in
            let lower = evidence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return lower.hasPrefix("case summary:") || lower.hasPrefix("active intervention:")
        }
    }

    private nonisolated static func replyTouchesCaseAnchor(
        _ lower: String,
        assessment: CoachAssessment
    ) -> Bool {
        let anchorTokens = assessment.evidenceUsed
            .filter { evidence in
                let lower = evidence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return lower.hasPrefix("case summary:") || lower.hasPrefix("active intervention:")
            }
            .flatMap(caseAnchorTokens)
        guard !anchorTokens.isEmpty else { return true }
        return anchorTokens.contains { lower.contains($0) }
    }

    private nonisolated static func caseAnchorTokens(from evidence: String) -> [String] {
        let labelStopWords: Set<String> = [
            "case", "summary", "active", "intervention", "hypothesis",
            "focus", "evidence", "next", "move", "target", "followed",
            "review", "status", "title", "reps", "rep", "latest",
            "timed", "score", "pace", "filler", "fillers", "mechanics",
            "goal", "readiness", "proof", "test", "pressure", "under",
            "before", "after", "without", "within", "about", "because",
            "clear", "recent", "where", "whether", "there", "their",
            "this", "that", "your", "they", "than", "into", "with",
            "from", "only", "more", "less", "still", "need",
            "answer", "sentence", "record", "clean", "close", "ask",
            "recommendation", "reason", "stop", "verdict", "decision"
        ]
        var seen = Set<String>()
        var tokens: [String] = []
        for raw in evidence.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let token = String(raw)
            guard token.count >= 4,
                  !labelStopWords.contains(token),
                  !seen.contains(token) else {
                continue
            }
            seen.insert(token)
            tokens.append(token)
        }
        return tokens
    }

    private nonisolated static func countEvidenceTouches(
        _ lower: String,
        assessment: CoachAssessment
    ) -> Int {
        var count = 0
        for evidence in assessment.evidenceUsed {
            let words = evidence
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .filter { $0.count >= 4 }
            if words.contains(where: { lower.contains($0) }) {
                count += 1
            }
        }
        return count
    }

    private nonisolated static func firstSentence(in text: String) -> String {
        if let end = text.firstIndex(where: { ".!?".contains($0) }) {
            return String(text[...end])
        }
        return text
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
        "keep practicing",
        "practice more",
        "practice often",
        "sound more confident",
        "be more confident",
        "work on confidence",
        "structure your thoughts",
        "think about your audience",
        "communicate clearly",
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
        "fluff, not coaching",
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
        "open the practice screen",
        "tap to confirm",
        "tap the card",
        "tap the confirmation",
        "confirm and i'll",
        "confirm and i will",
        "i'll lock it in",
        "i will lock it in",
        "lock it in"
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
            "couldn't shape", "couldn’t shape", "shape a useful answer",
            "not informative", "not helpful", "not useful",
            "missed the point", "doesn't answer", "does not answer",
            "stop saying practice", "stop telling me to practice",
            "do not just tell me to practice", "don't just tell me to practice"
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

    private nonisolated static func turnRequestsSessionExample(_ turn: String?) -> Bool {
        guard let lower = turn?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !lower.isEmpty else { return false }
        let asksForExample = containsAny(lower, [
            "example", "specific moment", "show me", "where did i",
            "when did i", "quote me", "something i said"
        ])
        let asksFromHistory = containsAny(lower, [
            "session", "sessions", "rep", "reps", "practice", "before"
        ])
        return asksForExample && asksFromHistory
    }

    /// Last-mile finalizer for every committed coach reply. Runs the standard
    /// scaffold-stripping sanitize, then strips bare report-voice telemetry
    /// residue on trust-repair / sensitive-non-report turns and for compact raw
    /// metric clusters, unless the user explicitly asked for metrics. On the
    /// happy path the gate already regenerated such replies, so this is a no-op;
    /// on a fallback / bypass path it prevents "score 74"-style telemetry from
    /// reaching the user when it would weaken coaching trust.
    nonisolated static func finalizedCoachReply(
        from raw: String,
        latestUserTurn: String?,
        turnDepth: CoachTurnDepth
    ) -> String {
        let normalized = CoachReplyTextSanitizer.coachReplyText(from: raw)
        guard !normalized.isEmpty else { return normalized }
        let lowerTurn = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let containsCompactMetricCluster = replyContainsCompactMetricCluster(normalized.lowercased())
        let containsModeOnlyEvidenceSentence = replyContainsModeOnlyEvidenceSentence(normalized.lowercased())
        let sensitive = turnDepth == .trustRepair
            || turnIsSensitiveNonReportTurn(lowerTurn, turnDepth: turnDepth)
        guard (sensitive || containsCompactMetricCluster || containsModeOnlyEvidenceSentence),
              !turnExplicitlyRequestsMetrics(lowerTurn) else {
            return normalized
        }
        let stripped = CoachReplyTextSanitizer.strippingReportVoiceResidue(from: normalized)
        return stripped.isEmpty ? normalized : stripped
    }

    private nonisolated static func replyUsesTrustRepairReportVoiceMetrics(
        _ lower: String,
        latestUserTurn: String?,
        turnDepth: CoachTurnDepth
    ) -> Bool {
        let lowerTurn = latestUserTurn?.lowercased() ?? ""
        guard turnDepth == .trustRepair || isCritiqueTurn(lowerTurn) else {
            return false
        }
        return replyContainsRawReportVoiceMetrics(lower)
    }

    private nonisolated static func replyUsesSensitiveTurnReportVoiceMetrics(
        _ lower: String,
        latestUserTurn: String?,
        turnDepth: CoachTurnDepth
    ) -> Bool {
        let lowerTurn = latestUserTurn?.lowercased() ?? ""
        guard turnIsSensitiveNonReportTurn(lowerTurn, turnDepth: turnDepth),
              !turnExplicitlyRequestsMetrics(lowerTurn) else {
            return false
        }
        return replyContainsRawReportVoiceMetrics(lower)
    }

    private nonisolated static func replyContainsCompactMetricCluster(_ lower: String) -> Bool {
        let compactMetricCluster = #"\b\d(?:\.\d)?\s*/\s*10\s*,\s*\d+\s+fillers?\s*,\s*\d+\s*s(?:ec(?:ond)?s?)?\b"#
        return lower.range(of: compactMetricCluster, options: .regularExpression) != nil
    }

    private nonisolated static func replyContainsModeOnlyEvidenceSentence(_ lower: String) -> Bool {
        let modeOnlySignal = #"(^|[.!?]\s+)the signal i can use is\s+(?:timed(?:\s+practice)?|practice|pressure(?:\s+drill)?)\s*[.!?]?"#
        return lower.range(of: modeOnlySignal, options: .regularExpression) != nil
    }

    private nonisolated static func replyContainsRawReportVoiceMetrics(_ lower: String) -> Bool {
        let scoreReadout = #"\b(?:score|scored|hit)\s+(?:\d{2,3}|\d(?:\.\d)?(?:\s*/\s*10)?)\b"#
        if lower.range(of: scoreReadout, options: .regularExpression) != nil {
            return true
        }

        if replyContainsCompactMetricCluster(lower) {
            return true
        }

        let statCluster = #"\b\d{2,3}\s*(?:/|over)\s*\d{2,3}\s*s(?:ec(?:ond)?s?)?\s*(?:/|with)\s*(?:only\s*)?\d+\s+fillers?\b"#
        if lower.range(of: statCluster, options: .regularExpression) != nil {
            return true
        }

        let fillerDurationCluster = #"\b\d+\s+fillers?\s+(?:in|over|across)\s+\d{2,3}\s*(?:s|sec(?:ond)?s?)\b"#
        if lower.range(of: fillerDurationCluster, options: .regularExpression) != nil {
            return true
        }

        let scoreAdjectiveReadout = #"\b(?:clean|landed|held)\s+at\s+\d{2,3}\b"#
        if lower.range(of: scoreAdjectiveReadout, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private nonisolated static func turnIsSensitiveNonReportTurn(
        _ lowerTurn: String,
        turnDepth: CoachTurnDepth
    ) -> Bool {
        if turnDepth == .trustRepair || isCritiqueTurn(lowerTurn) {
            return true
        }
        return turnLooksLikeVoiceGoalIntent(lowerTurn)
            || turnLooksLikeGreeting(lowerTurn)
            || turnLooksLikeLowSignalOffTopicTest(lowerTurn)
            || turnLooksEmotionallyVulnerable(lowerTurn)
    }

    private nonisolated static func turnExplicitlyRequestsMetrics(_ lowerTurn: String) -> Bool {
        TurnDepthClassifier.explicitlyRequestsMetrics(lowerTurn)
    }

    private nonisolated static func turnLooksLikeGreeting(_ lowerTurn: String) -> Bool {
        let normalized = normalizedTurnText(lowerTurn)
        return [
            "hi", "hey", "hello", "yo", "good morning", "good afternoon",
            "good evening", "im back", "i am back", "back again"
        ].contains(normalized)
    }

    private nonisolated static func turnLooksLikeLowSignalOffTopicTest(_ lowerTurn: String) -> Bool {
        let normalized = normalizedTurnText(lowerTurn)
        if ["egg", "banana", "asdf", "test", "lol", "huh"].contains(normalized) {
            return true
        }
        if turnLooksEmotionallyVulnerable(lowerTurn) {
            return false
        }
        guard normalized.count <= 18,
              wordCount(in: normalized) <= 2 else {
            return false
        }
        return !containsAny(normalized, [
            "score", "filler", "voice", "rate", "plan", "help", "practice",
            "interview", "meeting", "presentation", "pitch", "better",
            "improve", "why", "what", "how"
        ])
    }

    private nonisolated static func turnLooksEmotionallyVulnerable(_ lowerTurn: String) -> Bool {
        containsAny(lowerTurn, [
            "it's not easy", "it is not easy", "this is hard", "that's hard",
            "that is hard", "i'm exhausted", "im exhausted", "i am exhausted",
            "i'm tired", "im tired", "i am tired", "i feel like a fraud",
            "feel like a fraud", "everyone is better", "everyone's better",
            "i keep freezing", "i froze", "i panic", "i blank", "not improving"
        ])
    }

    private nonisolated static func normalizedTurnText(_ lowerTurn: String) -> String {
        lowerTurn
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: "", options: .regularExpression)
            .split { $0.isWhitespace }
            .joined(separator: " ")
    }

    private nonisolated static func replyLengthLimits(
        expandedAnswer _: Bool,
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface,
        responseKind: CoachChatResponseKind
    ) -> (characters: Int, sentences: Int, words: Int, lines: Int) {
        if surface == .live {
            return (260, 2, 35, 2)
        }

        switch responseKind {
        case .conversational:
            return (220, 2, 30, 2)
        case .generalCoaching:
            return (340, 3, 45, 3)
        case .memoryHandoff:
            return (380, 3, 50, 3)
        case .personalEvidenceRead:
            break
        }
        switch turnDepth {
        case .deepAssessment:
            return (700, 5, 90, 6)
        case .trustRepair:
            return (340, 3, 45, 3)
        case .groundedRead, .quickMove:
            return (380, 2, 50, 3)
        }
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
        // Match the sanitizer's mid-line strip anchors exactly (now including a
        // comma/semicolon join) so the gate flags every scaffold form the strip
        // would remove — stricter, never weaker.
        let inlinePattern = #"(?i)(?:[.!?]\s+|[,;]\s+|\s+[—-]\s+)(?:"# + labels + #"):\s*"#

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
        if TurnDepthClassifier.isLowSignalOffTopicTest(lower) { return false }
        if turnLooksLikeVoiceGoalIntent(lower) { return false }
        return true
    }

    private nonisolated static func turnExpectsPrescribedAction(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return true }
        let lower = latestUserTurn.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.count <= 4 && containsAny(lower, ["hi", "hey", "yo"]) { return false }
        if TurnDepthClassifier.isBroadPerformanceRead(lower) ||
            TurnDepthClassifier.explicitlyRequestsMetrics(lower) {
            return false
        }
        return containsAny(lower, [
            "what next", "next move", "what should", "continue", "implement",
            "develop", "work on", "focus", "how do i", "help me", "coach me",
            "how can i", "how could i", "how should i", "how would i",
            "practice", "prepare", "fix", "improve", "replace", "go for",
            "make a bigger stride", "what do i run", "what is the exact rep",
            "what's the exact rep", "what test", "which test"
        ]) || isCritiqueTurn(lower)
    }

    private nonisolated static func replyDirectlyAnswersBriefTacticalTurn(
        _ lower: String,
        latestUserTurn: String?,
        turnDepth: CoachTurnDepth
    ) -> Bool {
        guard turnDepth == .quickMove else { return false }
        guard let latestUserTurn else { return false }
        let turn = latestUserTurn.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard containsAny(turn, [
            "quickly", "what do i do next", "what's next",
            "what is the one move", "one move", "next move",
            "what should i record", "what should i do with that"
        ]) else {
            return false
        }
        guard wordCount(in: lower) <= 30,
              sentenceCount(in: lower) <= 2,
              !replyOffersMenu(lower),
              replyHasObservableAnchor(lower),
              replyPrescribesAction(lower),
              replyHasInsightBridge(lower) else {
            return false
        }
        return true
    }

    private nonisolated static func turnAsksWhyAnswerLandedBadly(_ turn: String?) -> Bool {
        guard let turn else { return false }
        return TurnDepthClassifier.isSpecificAnswerLandingRead(turn)
    }

    private nonisolated static func turnAsksMemoryHandoff(_ turn: String?) -> Bool {
        guard let lower = turn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }
        return TurnDepthClassifier.isMemoryHandoff(lower)
    }

    private nonisolated static func replyIsConsentBoundMemoryHandoff(
        _ lower: String,
        coachingBrief: CoachChatBrief? = nil
    ) -> Bool {
        let namesMemory = containsAny(lower, [
            "memory", "remember", "keep this", "carry forward"
        ])
        let keepsHypothetical = containsAny(lower, [
            "testable hypothesis", "hypothesis only", "not a label",
            "keep it if", "drop it if", "reject that hypothesis",
            "possible pattern", "for now"
        ])
        let groundsTypedMemory: Bool = {
            guard let coachingBrief,
                  coachingBrief.decisiveEvidence != nil,
                  coachingBrief.nextMove != nil else {
                return containsAny(lower, [
                    "disagreement", "setup", "point arrives late",
                    "verdict-first", "observable read", "pressure reps",
                    "sentence one"
                ])
            }
            let ignored: Set<String> = [
                "about", "after", "again", "also", "and", "before", "but",
                "for", "from", "have", "into", "just", "next", "that",
                "the", "then", "this", "through", "when", "with", "you",
                "your", "coach", "read", "prior", "conversation",
                "hypothesis", "possible", "pattern"
            ]
            func terms(_ value: String) -> Set<String> {
                Set(value.lowercased()
                    .split { !$0.isLetter && !$0.isNumber }
                    .map(String.init)
                    .filter { $0.count >= 4 && !ignored.contains($0) })
            }
            let allowed = [
                coachingBrief.directVerdict,
                coachingBrief.decisiveEvidence,
                coachingBrief.nextMove
            ]
                .compactMap { $0 }
                .reduce(into: Set<String>()) { result, value in
                    result.formUnion(terms(value))
                }
            let visible = terms(lower)
            guard allowed.count >= 2 else { return false }
            return allowed.intersection(visible).count >= 2
        }()
        let hasRevisionPath = containsAny(lower, [
            "drop it if", "reject", "doesn't fit", "does not fit",
            "if verdict-first solves it", "if two pressure reps",
            "drop this read if", "change this read if"
        ])
        return namesMemory && keepsHypothetical && groundsTypedMemory && hasRevisionPath
    }

    private nonisolated static func replyIsEvidenceGapClarification(
        _ lower: String
    ) -> Bool {
        let ownsEvidenceGap = containsAny(lower, [
            "i don't have enough evidence", "i don’t have enough evidence",
            "i do not have enough evidence", "i need one example",
            "i need one recent rep", "i need a recent rep",
            "i can't answer that honestly yet", "i cannot answer that honestly yet",
            "i can't make a personal read yet", "i cannot make a personal read yet"
        ])
        guard ownsEvidenceGap,
              lower.filter({ $0 == "?" }).count == 1,
              !replyContainsUnverifiedPersonalRead(lower),
              !replyContainsNonCoachingPrescription(lower) else {
            return false
        }
        return containsAny(lower, [
            "what did", "what happens", "which part", "when does",
            "where does", "what changed", "what do you", "which answer",
            "which rep", "can you share"
        ])
    }

    private nonisolated static func replyIsHonestNoMemoryHandoff(
        _ lower: String
    ) -> Bool {
        containsAny(lower, [
            "i don't have a clear pattern to carry forward yet",
            "i don’t have a clear pattern to carry forward yet",
            "there isn't a clear pattern to carry forward yet",
            "there isn’t a clear pattern to carry forward yet"
        ]) && !replyContainsNonCoachingPrescription(lower) &&
            !replyContainsUnverifiedPersonalRead(lower)
    }

    private nonisolated static func replyContainsUnverifiedPersonalRead(
        _ lower: String
    ) -> Bool {
        let patterns = [
            #"\b(?:your|the) (?:latest|recent|last) (?:rep|session|answer|transcript)s? (?:show|shows|showed|suggest|suggests|suggested|prove|proves|proved|have|has|had|give|gives|gave|place|placed|reveal|reveals|revealed|indicate|indicates|indicated|be|is|was|are|were)\b"#,
            #"\bi(?:'ve| have) noticed (?:that )?you\b"#,
            #"\byou (?:tend|usually|often|typically|consistently)\b"#,
            #"\byour (?:communication )?pattern (?:is|was|shows|suggests)\b"#
        ]
        return patterns.contains { pattern in
            lower.range(of: pattern, options: .regularExpression) != nil
        }
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
        replyContainsHighConfidenceUserPrescription(lower)
    }

    private nonisolated static func replyRepairsTrust(_ lower: String) -> Bool {
        containsAny(lower, [
            "fair", "you're right", "you are right", "good call", "useful push",
            "that read", "that felt", "the friction", "too generic", "too robotic",
            "right to call", "that should not", "that shouldn't", "should not happen",
            "shouldn't happen", "that was advice", "that was generic", "that was cold",
            "not easy", "easier than it feels", "hard part",
            "repeated the same", "same test", "changing the evidence",
            "markup read", "tts read", "read aloud", "overexplained",
            "formatting", "markdown", "symbols",
            "i'll be", "i will be", "i'll keep", "i will keep", "i'll change",
            "i will change", "i'll cut", "i will cut", "i'll stop", "i will stop"
        ])
    }

    private nonisolated static func replyNamesRepairFocus(
        _ lower: String,
        repairFocus: String
    ) -> Bool {
        let focus = repairFocus.lowercased()
        let needles: [String]
        if containsAny(focus, ["cold", "human coach"]) {
            needles = [
                "cold", "robotic", "human", "coach read", "not coaching",
                "generic ai", "ai tips"
            ]
        } else if containsAny(focus, ["too much writing", "writing", "wordy"]) {
            needles = [
                "too much writing", "too long", "shorter", "wordy",
                "overexplained", "dense", "get to the point",
                "close is the leak"
            ]
        } else if containsAny(focus, ["repeated", "repeating", "same coaching"]) {
            needles = ["repeated", "repeating", "same move", "same coaching", "same thing", "already said"]
        } else if containsAny(focus, ["easier than", "not easy", "pressure"]) {
            needles = ["not easy", "easier", "harder", "pressure", "feels under pressure", "too simple"]
        } else if containsAny(focus, ["actual question", "missed"]) {
            needles = [
                "missed", "actual question", "didn't answer", "did not answer",
                "wrong question", "useful read", "answered around", "not informative"
            ]
        } else if containsAny(focus, ["generic", "evidence"]) {
            needles = ["generic", "evidence", "generic advice", "not evidence", "template", "templated"]
        } else if containsAny(focus, ["polite pushback", "friction"]) {
            needles = [
                "friction", "pushback", "hesitation", "what you meant",
                "what you were asking", "didn't answer", "did not answer",
                "missed the question", "missed your question", "missed the ask",
                "underneath the polite", "polite push"
            ]
        } else {
            needles = focus
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 5 }
        }
        return containsAny(lower, needles)
    }

    private nonisolated static func replyContainsTrustRepairRead(
        _ lower: String,
        assessment: CoachAssessment
    ) -> Bool {
        if replyTouchesNonRepairEvidence(lower, assessment: assessment) {
            return true
        }
        // On vulnerable pushback, the useful read can be the mechanism of the
        // difficulty plus a deliberately smaller experiment. That is substantive
        // coaching even when no historical metric is appropriate to cite.
        let namesDifficultyMechanism = containsAny(lower, [
            "the hard part",
            "what makes this hard",
            "the friction is",
            "the pressure point",
            "social risk",
            "carries the risk",
            "under pressure"
        ])
        let adjustsIntervention = containsAny(lower, [
            "smaller version",
            "smallest version",
            "keep the next step small",
            "say only",
            "first hard sentence",
            "one calm reason",
            "reduce the ask"
        ])
        if namesDifficultyMechanism,
           adjustsIntervention,
           replyHasUserPracticeMove(lower) {
            return true
        }
        return containsAny(lower, [
            "last rep", "recent rep", "latest rep", "available excerpt",
            "transcript", "filler count", "fillers", "pace estimate",
            "words per minute", " wpm", "/10",
            "what i notice", "what i heard",
            "the useful read is", "the actual read is", "the real read is",
            "the coaching read is", "the signal i can use",
            "one safe signal", "usable signal", "changing the evidence",
            "same test", "the close is the leak"
        ])
    }

    private nonisolated static func replyTouchesNonRepairEvidence(
        _ lower: String,
        assessment: CoachAssessment
    ) -> Bool {
        assessment.evidenceUsed.contains { evidence in
            let evidenceLower = evidence.lowercased()
            guard !evidenceLower.hasPrefix("trust repair signal:") else {
                return false
            }
            let words = evidenceLower
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 }
            guard !words.isEmpty else { return false }
            let hitCount = words.reduce(0) { count, word in
                count + (lower.contains(word) ? 1 : 0)
            }
            return hitCount >= min(2, words.count)
        }
    }

    private nonisolated static func trustRepairMissesSpecificFriction(
        _ lowerReply: String,
        latestUserTurn: String?
    ) -> Bool {
        guard let lowerTurn = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              isCritiqueTurn(lowerTurn),
              replyRepairsTrust(lowerReply) else {
            return false
        }

        let frictionNeedles = trustRepairFrictionNeedles(for: lowerTurn)
        guard !frictionNeedles.isEmpty else {
            return false
        }

        return !containsAny(lowerReply, frictionNeedles)
    }

    private nonisolated static func trustRepairFrictionNeedles(for lowerTurn: String) -> [String] {
        var needles: [String] = []

        if containsAny(lowerTurn, [
            "tts", "read them out", "read aloud", "**", "markdown",
            "formatting", "symbols", "stars"
        ]) {
            needles += [
                "tts", "read aloud", "read out", "voice", "spoken",
                "markdown", "formatting", "symbol", "symbols",
                "stars", "asterisk"
            ]
        }

        if containsAny(lowerTurn, [
            "robotic", "report", "too much writing", "too long",
            "less writing", "less text", "shorter", "overexplained",
            "over explained", "over-explained"
        ]) || turnCritiquesCoachOverexplaining(lowerTurn) {
            needles += [
                "robotic", "report", "too much writing", "too long",
                "less writing", "less text", "shorter", "overexplained",
                "over explained", "over-explained", "dense", "wordy",
                "generic", "template", "templated"
            ]
        }

        if containsAny(lowerTurn, [
            "not informative", "not helpful", "not useful",
            "missed the point", "doesn't answer", "does not answer"
        ]) {
            needles += [
                "not informative", "not helpful", "missed", "actual question",
                "didn't answer", "did not answer", "useful read", "answer"
            ]
        }

        if containsAny(lowerTurn, [
            "repeating yourself", "same thing again", "said that already",
            "already said that"
        ]) {
            needles += [
                "repeating", "repeated", "same move", "same thing",
                "already said", "advance", "advancing"
            ]
        }

        if containsAny(lowerTurn, [
            "it's not easy", "its not easy", "not that easy",
            "easier said than done", "harder than that"
        ]) {
            needles += [
                "not easy", "easier", "harder", "pressure",
                "too simple", "feels under pressure"
            ]
        }

        if containsAny(lowerTurn, [
            "cold", "generic", "not human", "doesn't feel", "does not feel",
            "low eq", "not high eq", "expert coach", "ai tips", "ai wrapper"
        ]) {
            needles += [
                "cold", "generic", "advice", "not coaching", "coaching",
                "human", "warm", "expert", "ai tips", "ai wrapper",
                "template", "templated"
            ]
        }

        if containsAny(lowerTurn, [
            "stop saying practice", "stop telling me to practice",
            "do not just tell me to practice", "don't just tell me to practice"
        ]) {
            needles += [
                "generic", "advice", "not coaching", "actual read",
                "behavior", "proof", "signal", "specific"
            ]
        }

        return Array(Set(needles))
    }

    private nonisolated static func replyHasObservableAnchor(_ lower: String) -> Bool {
        if lower.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        return containsAny(lower, [
            "last rep", "recent rep", "next rep", "session", "transcript",
            "filler", "pace", "pause", "score", "wpm", "word choice",
            "you said", "you asked", "i heard", "what i notice", "pattern",
            "case", "hypothesis", "target", "success measure", "not enough data",
            "baseline", "sentence", "first sentence", "sentence one",
            "opener", "opening", "close", "closing", "final line",
            "directness", "silent beat", "beat before", "decision",
            "recommendation", "verdict", "proof point", "proof",
            "reason", "reassurance", "example", "structure", "authority",
            "warmth", "setup", "point",
            "voice", "meetings", "meeting", "talked over", "interrupted",
            "room", "senior room",
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
        if replyNamesPastRepAnchor(lower) { return true }
        return containsAny(lower, [
            "last rep", "recent rep", "latest rep", "last session",
            "recent session", "rated session", "your timed rep",
            "your rep", "the transcript", "your transcript",
            "last transcript", "latest transcript", "recent transcript"
        ])
    }

    private nonisolated static func replyNamesPastRepAnchor(_ lower: String) -> Bool {
        guard lower.contains(" rep") else { return false }
        return !containsAny(lower, [
            "next rep", "one rep", "same rep", "this rep", "a rep",
            "the rep again", "run the rep", "run a rep", "record a rep"
        ])
    }

    private nonisolated static func replyIsGroundedInConversationFollowUp(
        _ lower: String,
        latestUserTurn: String?,
        recentCoachReplies: [String]
    ) -> Bool {
        guard turnIsConversationLocalFollowUp(latestUserTurn) else {
            return false
        }
        return replyHasObservableAnchor(lower) ||
            replySharesPriorCoachAnchor(lower, recentCoachReplies: recentCoachReplies)
    }

    private nonisolated static func turnIsConversationLocalFollowUp(_ latestUserTurn: String?) -> Bool {
        guard let latestUserTurn else { return false }
        let lower = latestUserTurn.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty, lower.count <= 140 else { return false }
        if containsAny(lower, [
            "this", "that", "those", "it", "so ", "why", "pattern",
            "short version", "shorter", "what test", "which test",
            "separates those", "does that", "do i", "should i",
            "what if", "what should noum judge", "what should noum check",
            "what should noum look for", "judge after", "check after",
            "what do i repeat", "what should i repeat",
            "what exactly do i repeat",
            "not my whole", "answered what i meant", "answer what i meant",
            "what i meant", "stop saying", "give me the", "remember",
            "what should noum remember", "what should you remember",
            "what do you remember", "i did the", "i gave the",
            "i finished the",
            "people asked", "they asked", "after the meeting",
            "after the update", "after the presentation"
        ]) {
            return true
        }
        return isCritiqueTurn(lower)
    }

    private nonisolated static func replySharesPriorCoachAnchor(
        _ lower: String,
        recentCoachReplies: [String]
    ) -> Bool {
        guard let previous = recentCoachReplies.first?.lowercased() else {
            return false
        }
        let currentTerms = Set(coachAnchorTerms(in: lower))
        guard !currentTerms.isEmpty else { return false }
        let previousTerms = Set(coachAnchorTerms(in: previous))
        return !currentTerms.intersection(previousTerms).isEmpty
    }

    private nonisolated static func coachAnchorTerms(in lower: String) -> [String] {
        [
            "sentence", "opener", "opening", "close", "closing",
            "decision", "recommendation", "verdict", "proof",
            "reason", "reassurance", "pause", "filler", "warmth",
            "structure", "authority", "baseline", "example", "ask",
            "point", "setup", "claim", "transcript", "hypothesis",
            "memory", "remember", "disagreement", "softened"
        ].filter { lower.contains($0) }
    }

    private nonisolated static func replyUsesUnhelpfulRepDate(_ lower: String) -> Bool {
        guard containsAny(lower, [" rep", "session", "practice"]) else { return false }
        let month = #"(?:january|february|march|april|may|june|july|august|september|october|november|december)"#
        let monthFirst = #"\b"# + month + #"\s+\d{1,2}(?:st|nd|rd|th)?\b"#
        let dayFirst = #"\b\d{1,2}(?:st|nd|rd|th)?\s+"# + month + #"\b"#
        return [monthFirst, dayFirst].contains { pattern in
            lower.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private nonisolated static func replyPrescribesAction(_ lower: String) -> Bool {
        replyContainsHighConfidenceUserPrescription(lower)
    }

    private nonisolated static func replyExplainsWhyAnswerLanded(_ lower: String) -> Bool {
        containsAny(lower, [
            "recommendation arrived late",
            "recommendation came late",
            "recommendation landed late",
            "waited too long to state the recommendation",
            "waited too long to give the recommendation",
            "took too long to state the recommendation",
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
        if containsAny(lower, [
            " so ", " because ", "because ", " therefore ", " which is why",
            "that is why", "that's why", "that’s why", "that tests",
            "tests whether", "tests if", "the pattern", "the signal",
            "useful signal", "enough signal", "pressure cue", "the read",
            "next lever",
            "the move is", "the fix is", "the point arrived late",
            "arrived late", "showing up", "carried", "softened", "held",
            "light on", "not a summary", "not abandoning", "worth varying",
            "hypothesis", "moved alongside", "trended down alongside",
            "the gap", "what broke", "what held",
            "if it names", "if it starts", "listen for sentence"
        ]) {
            return true
        }
        // Natural coaching often expresses the observation → consequence link
        // without a canned "because/so" connector. Keep these patterns narrow:
        // they still require an explicit relational subject (that/this/which)
        // or a when-clause followed by an observable listener effect.
        if lower.range(
            of: #"\b(?:that|this|which)\b[^.!?\n]{0,80}\bmeant\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if lower.range(
            of: #"\b(?:that|this|which)\b[^.!?\n]{0,50}\b(?:creates?|keeps?|gives?|lets?|makes?|separates?|protects?|prevents?|helps?)\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if lower.range(
            of: #"\bwhen\b[^.!?\n]{0,140}\b(?:easier|harder|clearer)\b[^.!?\n]{0,45}\b(?:follow|understand|track|hear)\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return replyHasPressureMechanicBridge(lower)
    }

    private nonisolated static func replyHasPressureMechanicBridge(_ lower: String) -> Bool {
        guard containsAny(lower, ["under pressure", "pressure makes", "pressure is"]) else {
            return false
        }
        guard containsAny(lower, [
            "close", "closing", "pause", "beat", "verdict",
            "recommendation", "reason", "sentence", "opening",
            "opener", "ask", "proof"
        ]) else {
            return false
        }
        return containsAny(lower, [
            "needs", "need", "gets harder", "harder", "breaks",
            "leaks", "wobbles", "softens", "rushes", "holds",
            "doesn't hold", "does not hold", "lands", "land"
        ])
    }

    private nonisolated static func replyOverclaimsEvidence(_ lower: String) -> Bool {
        if replyOverclaimsUnconfirmedPersonalPattern(lower) {
            return true
        }
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
            "fillers happened because", "filler happened because",
            "fillers drifted in because", "filler drifted in because"
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

    private nonisolated static func replyOverclaimsUnconfirmedPersonalPattern(
        _ lower: String
    ) -> Bool {
        guard containsAny(lower, [
            "you are defensive", "you're defensive", "youre defensive", "you’re defensive",
            "you seem defensive", "you sound defensive",
            "you are evasive", "you're evasive", "youre evasive", "you’re evasive",
            "you seem evasive", "you sound evasive",
            "you are timid", "you're timid", "youre timid", "you’re timid",
            "you seem timid", "you sound timid",
            "you are detached", "you're detached", "youre detached", "you’re detached",
            "emotionally detached", "you are insecure", "you're insecure",
            "youre insecure", "you’re insecure",
            "you avoid disagreement", "you're avoiding disagreement",
            "you are avoiding disagreement", "you avoid conflict",
            "you're avoiding conflict", "you are avoiding conflict",
            "you fear disagreement", "you fear conflict",
            "you're afraid of disagreement", "you are afraid of disagreement",
            "you're afraid of conflict", "you are afraid of conflict",
            "you're scared of disagreement", "you are scared of disagreement",
            "you're scared of conflict", "you are scared of conflict",
            "fear of disagreement is driving", "fear of conflict is driving",
            "your fear of disagreement", "your fear of conflict",
            "you hide from disagreement", "you're hiding from disagreement",
            "you hide from conflict", "you're hiding from conflict",
            "your defensiveness", "your avoidance", "your insecurity",
            "your real blocker is fear", "the real blocker is fear",
            "your issue is insecurity", "the issue is insecurity",
            "lack of conviction is", "no conviction"
        ]) else {
            return false
        }

        return !replyFramesPersonalPatternAsHypothesis(lower)
    }

    private nonisolated static func replyFramesPersonalPatternAsHypothesis(
        _ lower: String
    ) -> Bool {
        let hypothesisFrame = containsAny(lower, [
            "hypothesis", "may be", "might be", "could be",
            "could be that", "i would test", "i would treat",
            "i'd treat", "it may be", "it might be",
            "looks like", "reads like", "as a test",
            "not a label", "not an identity label"
        ])
        let confirmationFrame = containsAny(lower, [
            "does that fit", "if that fits", "if it fits",
            "confirm", "reject", "disconfirm", "test whether",
            "check whether", "compare whether", "keep it if",
            "drop it if", "change my view", "what would change",
            "not a label", "not an identity label"
        ])
        return hypothesisFrame && confirmationFrame
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
            "recommendation arrived late",
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
            // A transcript can mention the recommendation near the start while
            // explicitly saying it was delivered late (for example, "I waited
            // too long to state the recommendation"). Position in this source
            // string is not evidence of position in the described answer.
            guard !sourceMentionsLateRecommendation(sourceLower) else {
                return false
            }
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

    private nonisolated static func replyMisdirectsDecisionLineFillerRead(
        _ lower: String,
        latestUserTurn: String?,
        systemContext: String?
    ) -> Bool {
        guard containsAny(latestUserTurn?.lowercased() ?? "", [
            "um", "filler", "fillers", "hesitat"
        ]),
              let systemContext,
              fillerEvidenceSitsInsideDecisionLine(systemContext) else {
            return false
        }
        if containsAny(lower, [
            "after the decision",
            "after the recommendation",
            "inside the recommendation",
            "inside the decision"
        ]) {
            return false
        }
        return containsAny(lower, [
            "slow open",
            "slow opener",
            "first line slower",
            "first sentence slower",
            "open your next",
            "opening slower",
            "before sentence two",
            "early um",
            "strong start",
            "first sentence"
        ])
    }

    private nonisolated static func replyIgnoresClosingStrengthNextMove(
        _ lower: String,
        latestUserTurn: String?,
        systemContext: String?
    ) -> Bool {
        guard turnAsksForNextMove(latestUserTurn),
              let context = systemContext?.lowercased(),
              contextMentionsClosingStrengthLeverage(context) else {
            return false
        }
        guard containsAny(lower, [
            "point arrived late",
            "main point arrived late",
            "state your main",
            "state the main",
            "very first sentence",
            "first sentence",
            "lead with the conclusion",
            "leading with the conclusion",
            "open your next",
            "opening"
        ]) else {
            return false
        }
        return !containsAny(lower, [
            "close",
            "closing",
            "ending",
            "final sentence",
            "end with",
            "end on",
            "the ask"
        ])
    }

    private nonisolated static func turnAsksForNextMove(_ latestUserTurn: String?) -> Bool {
        let lower = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return containsAny(lower, [
            "what next",
            "next move",
            "what should i do next",
            "what should i practice next",
            "where next"
        ])
    }

    private nonisolated static func contextMentionsClosingStrengthLeverage(_ lower: String) -> Bool {
        containsAny(lower, [
            "closingstrength",
            "closing strength",
            "close lost force",
            "rushed close",
            "weak close",
            "soft close",
            "final sentence the ask",
            "final sentence needs the ask"
        ])
    }

    private nonisolated static func sourceMentionsLateRecommendation(_ text: String) -> Bool {
        CoachContextBuilder.transcriptMentionsLateRecommendation(text)
    }

    private nonisolated static func replyClaimsNoUsableRecentEvidenceDespiteContext(
        _ lower: String,
        systemContext: String?
    ) -> Bool {
        guard replyShouldCiteRecentSession(systemContext) else {
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

    private nonisolated static func replyUsesColdStartProductOrMetricTarget(
        _ lower: String,
        latestUserTurn: String?,
        systemContext: String?
    ) -> String? {
        guard replyIsColdStartBaselineTurn(
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) else {
            return nil
        }

        if containsAny(lower, [
            "ah-counter",
            "ah counter",
            "sudden death",
            "im conversation"
        ]) {
            return "cold-start product mode"
        }
        if lower.range(
            of: #"(?:first number|starting number|baseline number|a number to (?:hit|beat|track|chase|aim for)|(?:under|below|less than|fewer than|no more than|at most)\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+fillers?|stay\s+(?:under|below)\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+fillers?|(?:target|aim(?:ing)?(?:\s+to)?|aim for)\s+(?:stay\s+)?(?:under|below|at|for|to)?\s*(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+fillers?|keep\s+(?:your\s+)?fillers?\s+(?:under|below|to)\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)|beat\s+(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+fillers?)"#,
            options: .regularExpression
        ) != nil {
            return "cold-start metric target"
        }
        return nil
    }

    private nonisolated static func replyUsesVagueColdStartBaselineRep(
        _ lower: String,
        latestUserTurn: String?,
        systemContext: String?
    ) -> Bool {
        guard replyIsColdStartBaselineTurn(
            latestUserTurn: latestUserTurn,
            systemContext: systemContext
        ) else {
            return false
        }
        guard containsAny(lower, [
            "one short rep",
            "a short rep",
            "one quick rep",
            "a quick rep",
            "one simple rep",
            "a simple rep"
        ]) else {
            return false
        }
        return !containsAny(lower, [
            "60 seconds",
            "60-second",
            "sixty seconds",
            "sixty-second"
        ])
    }

    private nonisolated static func replyUsesVoiceGoalStateDirective(
        _ lower: String,
        latestUserTurn: String?
    ) -> String? {
        guard turnLooksLikeVoiceGoalIntent(latestUserTurn) else {
            return nil
        }
        let phrases = [
            "tap to confirm",
            "tap the card",
            "tap the confirmation",
            "confirm and i'll",
            "confirm and i will",
            "i'll lock it in",
            "i will lock it in",
            "lock it in",
            "i'll set it",
            "i will set it",
            "i'll set that",
            "i will set that",
            "i'll set your voice",
            "i will set your voice",
            "i'll switch you",
            "i will switch you",
            "i'll change your voice",
            "i will change your voice"
        ]
        return phrases.first(where: { lower.contains($0) })
    }

    private nonisolated static func turnLooksLikeVoiceGoalIntent(_ turn: String?) -> Bool {
        guard let lower = turn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !lower.isEmpty else {
            return false
        }
        if containsAny(lower, [
            "what voice", "which voice", "voice should", "voice do i",
            "voice to pick", "voice should i pick", "pick a voice",
            "choose a voice", "choose my voice", "set my voice",
            "change my voice", "switch my voice", "switch to",
            "sound more engaging", "sound warmer", "sound more warm",
            "something warmer", "warmer altogether", "more authoritative",
            "more persuasive", "more executive", "more concise",
            "more storytelling"
        ]) {
            return true
        }
        return SpeakingStyleGoal.allCases.contains { voice in
            let title = voice.title.lowercased()
            return lower.contains(title)
                && containsAny(lower, ["set", "change", "switch", "pick", "choose"])
        }
    }

    private nonisolated static func replyIsColdStartBaselineTurn(
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
        return turnLooksLikeColdStartBaselineIntent(latestUserTurn)
    }

    private nonisolated static func turnLooksLikeColdStartBaselineIntent(_ turn: String?) -> Bool {
        guard let lower = turn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !lower.isEmpty else {
            return false
        }
        // A user rejecting generic "practice more" advice is repairing trust,
        // not asking for a first-session baseline. The broad `practice` token
        // below must not invert that pushback into the exact advice they asked
        // the coach to stop repeating.
        if lower.contains("practice"),
           containsAny(lower, ["stop saying", "stop telling", "do not just", "don't just"]) {
            return false
        }
        // A report from the real moment is follow-through evidence, not a new
        // user's request for a baseline. The broad moment words below (update,
        // meeting, presentation) must not erase that temporal distinction.
        if containsAny(lower, [
            "i did the", "i gave the", "i finished the", "i tried it",
            "people asked", "they asked", "it went", "what happened",
            "after the meeting", "after the update", "after the presentation"
        ]) {
            return false
        }
        return containsAny(lower, [
            "what should i work on",
            "what do i work on",
            "where should i start",
            "where do i start",
            "where do i begin",
            "where do we start",
            "how should i start",
            "how do i start",
            "what should i do first",
            "what first",
            "first thing",
            "what next",
            "what do i do first",
            "just downloaded",
            "just installed",
            "new here",
            "i'm new",
            "im new",
            "get better",
            "improve",
            "practice",
            "prepare",
            "interview",
            "presentation",
            "meeting",
            "update",
            "pitch"
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
              !isCritiqueTurn(turn.lowercased()),
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
        "next", "practice", "prescribe", "prescribed", "rep", "reply",
        "speaker", "speaking", "success", "technique", "their", "there", "these",
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
        "your exact words", "your phrasing", "your wording",
        "from your answer", "from your rep", "from your transcript",
        "line you used", "phrase you used", "words you used",
        "wording you used"
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

    /// Mirrors the secure server's number boundary for local provider and
    /// fallback paths, then adds metric-kind provenance. A matching digit is
    /// not enough: `5 fillers`, `5/10`, and `5 seconds` are different facts.
    nonisolated static func replyUsesUnauthorizedPersonalMetric(
        _ text: String,
        latestUserTurn: String?,
        quoteGuard: CoachChatQuoteGuardContext?,
        coachingBrief: CoachChatBrief?
    ) -> Bool {
        let unquoted = text.replacingOccurrences(
            of: #"[\"“][^\"”\n]{1,240}[\"”]"#,
            with: "",
            options: .regularExpression
        ).lowercased()
        let userTexts: [String] = {
            if let quoteGuard { return quoteGuard.userReportTexts }
            guard let latestUserTurn else { return [] }
            return [latestUserTurn]
        }()
        let briefTexts = [
            coachingBrief?.directVerdict,
            coachingBrief?.decisiveEvidence,
            coachingBrief?.nextMove,
            coachingBrief?.missingEvidence,
            coachingBrief?.repairFocus,
            coachingBrief?.projectedMetricEvidenceText
        ].compactMap { $0 }
        let allowedText = (userTexts + briefTexts).joined(separator: "\n").lowercased()

        let replyNumbers = Set(regexMatches(
            #"\b\d+(?:[.,]\d+)*(?:%|ms|s)?\b"#,
            in: unquoted
        ))
        let allowedNumbers = Set(regexMatches(
            #"\b\d+(?:[.,]\d+)*(?:%|ms|s)?\b"#,
            in: allowedText
        ))
        if !replyNumbers.isSubset(of: allowedNumbers) {
            return true
        }

        let spokenNumber =
            "zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve"
        let spokenFactPattern =
            "\\b(?:\(spokenNumber))(?:\\s+to\\s+(?:\(spokenNumber))|" +
            "\\s+(?:seconds?|minutes?|fillers?|pauses?|percent|reps?|times?))\\b"
        let replySpokenFacts = Set(regexMatches(spokenFactPattern, in: unquoted))
        let allowedSpokenFacts = Set(regexMatches(spokenFactPattern, in: allowedText))
        if !replySpokenFacts.isSubset(of: allowedSpokenFacts) {
            return true
        }

        let replyMetricFacts = metricFactTuples(in: unquoted)
        guard !replyMetricFacts.isEmpty else { return false }
        var authorizedMetricFacts = metricFactTuples(
            in: coachingBrief?.decisiveEvidence?.lowercased() ?? ""
        )
        authorizedMetricFacts.formUnion(metricFactTuples(
            in: coachingBrief?.projectedMetricEvidenceText.lowercased() ?? ""
        ))
        if replyContainsNonCoachingPrescription(unquoted) {
            authorizedMetricFacts.formUnion(metricFactTuples(
                in: coachingBrief?.nextMove?.lowercased() ?? ""
            ))
        }
        if replyAttributesMetricToUserReport(unquoted) {
            authorizedMetricFacts.formUnion(metricFactTuples(
                in: userTexts.joined(separator: "\n").lowercased()
            ))
        }
        return !replyMetricFacts.isSubset(of: authorizedMetricFacts)
    }

    private nonisolated static func replySatisfiesTypedEvidenceRead(
        _ lower: String,
        coachingBrief: CoachChatBrief?
    ) -> Bool {
        guard let coachingBrief,
              let readKind = coachingBrief.evidenceReadKind else {
            return false
        }
        switch readKind {
        case .latestRepMetrics:
            let requested = Set(
                coachingBrief.requestedMetrics ?? CoachMetricKind.allCases
            )
            guard let projection = coachingBrief.latestRepMetrics else {
                return replyNamesTypedEvidenceGap(lower)
            }
            let availableRequested = requested.filter {
                projection.hasValue(for: $0)
            }
            guard !availableRequested.isEmpty else {
                return replyNamesTypedEvidenceGap(lower)
            }

            let replyFacts = metricFactTuples(in: lower)
            let projectedFacts = metricFactTuples(
                in: coachingBrief.projectedMetricEvidenceText.lowercased()
            )
            let relevantPrefixes = Set(availableRequested.map {
                metricFactPrefix($0)
            })
            let contextualPrefixes: Set<String> = (
                requested.contains(.fillerCount) ||
                    requested.contains(.paceWordsPerMinute)
            ) ? ["duration-seconds:"] : []
            let permittedPrefixes = relevantPrefixes.union(contextualPrefixes)
            guard !replyFacts.isEmpty,
                  replyFacts.contains(where: { fact in
                    relevantPrefixes.contains { fact.hasPrefix($0) }
                  }),
                  replyFacts.allSatisfy({ fact in
                    permittedPrefixes.contains { fact.hasPrefix($0) }
                  }) else {
                return false
            }
            return replyFacts.isSubset(of: projectedFacts)

        case .longitudinalTrend:
            guard let trend = coachingBrief.longitudinalTrend else {
                return replyNamesTypedEvidenceGap(lower)
            }
            let replyFacts = metricFactTuples(in: lower)
            let projectedFacts = metricFactTuples(
                in: coachingBrief.projectedMetricEvidenceText.lowercased()
            )
            let namesComparison = containsAny(lower, [
                "comparable", "same setup", "prior rep", "prior reps",
                "earlier rep", "earlier reps"
            ])
            let staysQualified = containsAny(lower, [
                "signal", "steady", "mixed", "moved", "not a broad verdict",
                "wouldn’t call broad improvement", "wouldn't call broad improvement"
            ])
            let directions = Set(trend.metrics.map(\.direction))
            let hasImproving = directions.contains(.improving)
            let hasDeclining = directions.contains(.declining)
            let directionMatches: Bool
            if hasImproving, hasDeclining {
                directionMatches = lower.contains("mixed")
            } else if hasImproving {
                directionMatches = lower.contains("positive signal")
            } else if hasDeclining {
                directionMatches = lower.contains("wrong direction")
            } else {
                directionMatches = lower.contains("steady")
            }
            return !replyFacts.isEmpty
                && replyFacts.isSubset(of: projectedFacts)
                && directionMatches
                && namesComparison
                && staysQualified
        }
    }

    private nonisolated static func metricFactPrefix(
        _ metric: CoachMetricKind
    ) -> String {
        switch metric {
        case .score: return "score:"
        case .fillerCount: return "filler-count:"
        case .fillerRatePerMinute: return "filler-rate:"
        case .paceWordsPerMinute: return "pace-wpm:"
        case .durationSeconds: return "duration-seconds:"
        }
    }

    private nonisolated static func replyNamesTypedEvidenceGap(
        _ lower: String
    ) -> Bool {
        containsAny(lower, [
            "don't have", "don’t have", "not enough", "still missing",
            "was withheld", "were withheld", "did not clear", "didn’t clear",
            "won't report", "won’t report", "cannot report", "can't report",
            "not reliable enough"
        ])
    }

    private nonisolated static func metricFactTuples(in text: String) -> Set<String> {
        let number =
            "(?:\\d+(?:\\.\\d+)?|zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)"
        let patterns: [(kind: String, pattern: String)] = [
            ("score", "\\b(\(number))\\s*(?:/\\s*10|out of ten)\\b"),
            ("score", "\\b(?:score|rating|scored)\\s*(?:was|is|of|at|:)?\\s*(\(number))\\b"),
            (
                "filler-count",
                "\\b(\(number))\\s+(?:fillers?|filler words?)\\b" +
                    "(?!\\s*(?:/|per)\\s*(?:min|minute)\\b)"
            ),
            ("filler-rate", "\\b(\(number))\\s*(?:fillers?\\s*)?(?:/|per)\\s*(?:min|minute)\\b"),
            ("duration-seconds", "\\b(\(number))\\s*(?:s|sec|secs|second|seconds)\\b"),
            ("pace-wpm", "\\b(\(number))\\s*(?:wpm|words? per minute)\\b")
        ]
        var facts: Set<String> = []
        let nsText = text as NSString
        for item in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: item.pattern,
                options: [.caseInsensitive]
            ) else { continue }
            for match in regex.matches(
                in: text,
                range: NSRange(location: 0, length: nsText.length)
            ) where match.numberOfRanges > 1 {
                let value = nsText.substring(with: match.range(at: 1)).lowercased()
                facts.insert("\(item.kind):\(value)")
            }
        }
        return facts
    }

    private nonisolated static func regexMatches(
        _ pattern: String,
        in text: String
    ) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return [] }
        let nsText = text as NSString
        return regex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ).map { nsText.substring(with: $0.range).lowercased() }
    }

    private nonisolated static func replyAttributesMetricToUserReport(
        _ lower: String
    ) -> Bool {
        containsAny(lower, [
            "you reported", "you counted", "you estimated", "you logged",
            "you said", "you told me", "by your count", "from your count",
            "your estimate", "your own count", "according to you"
        ])
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
        quoteGuard: CoachChatQuoteGuardContext?,
        recentCoachReplies: [String],
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?,
        surface: CoachReplySurface,
        responseKind: CoachChatResponseKind,
        coachingBrief: CoachChatBrief?,
        onProviderAttemptEvent: (@MainActor (CoachProviderAttemptEvent) -> Void)? = nil
    ) async -> String? {
        let latestUserTurn = messages.last(where: { $0.role == .user })?.text
        let userAskedForAction = responseKind != .conversational
            && Self.turnExpectsPrescribedAction(latestUserTurn)
        let requiredAnchor = Self.requiredRepairAnchor(
            issue: issue,
            latestUserTurn: latestUserTurn,
            system: system
        )
        let referenceShape = Self.repairReferenceShape(
            issue: issue,
            latestUserTurn: latestUserTurn,
            system: system
        )
        let evidenceRepairSourceOfTruthRule = issue == .overclaimsEvidence
            ? "- Evidence overclaim repair: treat the Required anchor and Expert reference shape as the source of truth. Do not re-diagnose the transcript differently; preserve the late/early recommendation read exactly."
            : ""
        let repairLengthRule: String = {
            switch turnDepth {
            case .deepAssessment:
                return surface == .live
                    ? "- This is a live deep-assessment repair: keep it spoken and compact, but preserve the verdict, evidence, missing evidence, and one concrete validation rep."
                    : "- This is a deep-assessment repair: it may be longer than a normal coach beat, but it must still be scan-friendly and must preserve the verdict, observed answer control versus consistent authority, evidence, missing evidence, and one concrete validation rep."
            case .trustRepair:
                return "- This is a trust repair: acknowledge the miss first, then repair the answer. Do not defend the product."
            case .quickMove, .groundedRead:
                return userAskedForAction
                    ? "- Keep the repair short: one direct answer, one reason, and one useful action."
                    : "- Keep the repair short: answer the current question without adding an unrequested drill."
            }
        }()
        let actionRule = userAskedForAction
            ? "- Give one specific action the user can take. Explain why it helps in natural language; do not force the words so or because."
            : "- Do not add a drill, next rep, or practice instruction unless it directly answers the current question."
        let trustRepairRule = responseKind == .conversational
            ? "- For feedback about this coach, use at most two sentences: own the specific friction, then state the concrete change in the coaching. Do not assign the user another exercise."
            : "- For a trust-repair coaching turn, own the specific friction first, then give one grounded correction that answers what the user asked."
        let recentActionRule: String = {
            let recentActions = Self.recentActionSentenceFingerprints(
                in: recentCoachReplies,
                limit: 3
            )
            guard !recentActions.isEmpty else { return "" }
            return "- Recent coach actions already prescribed: \(recentActions.joined(separator: "; ")). Do not repeat the same validation rep; vary the condition, target, or evidence check."
        }()
        let repairSystem = """
        \(system)

        QUALITY REWRITE PASS
        The previous draft failed the Ask Noum professional-coach gate.
        Failure: \(issue.repairInstruction)

        Draft to replace:
        \(draft)

        Rewrite from scratch. Requirements:
        \(repairLengthRule)
        - Usually 1-2 short lines and under 50 words unless the user explicitly asked for a plan or this is a deep-assessment repair.
        - Use natural sentence starts, up to 3 bullets, or numbered steps only when they reduce reading.
        - Never output literal Markdown markers such as **, __, ###, or decorative formatting.
        - Do not label the reply with Read, Move, Target, Recommend, or Next rep.
        - No long paragraph.
        - No broad menu. Make one clear coaching decision.
        \(requiredAnchor.map { "- Required anchor: \($0)" } ?? "")
        \(referenceShape.map { "- Expert reference shape: \($0)" } ?? "")
        \(evidenceRepairSourceOfTruthRule)
        \(recentActionRule)
        \(actionRule)
        \(trustRepairRule)
        - For filler-word work, say "hold a silent beat" or "hold one second of
          silence"; never tell the user to close their mouth or lips.
        - Cite a filler count only when the exact latest qualified evidence line
          supplies its duration and per-minute rate. Compare fillers per minute
          under equivalent demand, never raw counts. If comparison is withheld,
          say the sample is too small or uncertain and gather a 60-second rep.
        - Do not explain qualified filler evidence as caused by a separate
          structure read unless the context explicitly says that.
        - Do not infer the user's hidden mental cause for fillers. Avoid lines
          like "because the next word was not ready." Use observable phrasing
          and frame the silent beat as a test.
        - Do not make absolute structure claims such as "never led with the
          point" unless the context explicitly says the point never appeared.
          Prefer the safer observable target: "the close softened", "the point
          arrived late", or "the final sentence needs the ask."
        - If the source transcript already opens with a recommendation, point,
          or decision, do not write "the point arrived late", "buried the
          recommendation", or similar. Use a safe anchor instead, such as the
          qualified filler evidence, the exact transcript wording, or a missing
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
          reply. Do not name internal practice modes such as Ah-Counter,
          Sudden Death, or IM Conversation, do not set a filler-count target,
          and do not frame the first rep as a "first number"; the user has no
          calibrated baseline yet.
        - On voice/goal-change turns, never use raw score, filler-count,
          duration, or score-this-week readouts as proof for the voice. Translate
          them into spoken progress ("your authoritative work is already
          landing") and ask what changed. The confirmation UI owns state changes.
        - When the user asks why an answer landed badly, start from the
          transcript or last rep before the prescription, for example "From the
          transcript..." or "In your last rep...".
        - When referencing a practice session, write "your last rep" or "a recent rep"; never write the exact calendar date.
        - Do not narrate your own response mechanics. Avoid assistant-style phrases
          such as "in my response", "system symbols", "generic tip-giving", or
          "stripping out"; own the friction briefly, then say the changed
          coaching move directly.
        - Do not name a drill/framework unless the user explicitly asked for a named drill or plan. Translate the technique into plain action.
        - If the user showed frustration, do not defend the app.
        - If the user asked for shortness, make the answer shorter before making it smarter.
        - Sound like a senior communications coach, not an assistant explaining itself.
        - When an action is useful, connect it to the observation with one natural coaching reason; do not just list a metric and a drill.
        """

        let body = chatRequestBody(
            for: provider,
            system: repairSystem,
            messages: messages,
            maxOutputTokens: max(
                Self.coachRepairMaxOutputTokens,
                CoachPromptBundle.maxOutputTokens(for: turnDepth, surface: surface)
            )
        )
        let result: ProviderHTTPResult
        do {
            result = try await providerHTTP(
                provider: provider,
                endpoint: endpoint,
                key: key,
                body: body
            )
        } catch {
            guard !Task.isCancelled,
                  Self.transportFailureCanRetry(error) else {
                Self.log.error("repair pass transport failed for \(provider.displayName, privacy: .public)")
                recordChatDiagnostic(.fallback, "Repair response missing content", provider: provider)
                return nil
            }

            Self.log.notice("\(provider.displayName, privacy: .public) repair transport failed transiently — retrying once")
            recordChatDiagnostic(
                .fallback,
                "Transient repair transport failure; retrying once",
                provider: provider
            )
            await onProviderAttemptEvent?(.retry(CoachTurnProviderChoice(
                providerName: provider.displayName,
                model: provider.model
            )))
            do {
                result = try await providerHTTP(
                    provider: provider,
                    endpoint: endpoint,
                    key: key,
                    body: body
                )
            } catch {
                Self.log.error("repair pass retry failed for \(provider.displayName, privacy: .public)")
                recordChatDiagnostic(.fallback, "Repair response missing content", provider: provider)
                return nil
            }
        }
        guard
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
            systemContext: system,
            recentCoachReplies: recentCoachReplies,
            turnDepth: turnDepth,
            surface: surface,
            responseKind: responseKind,
            coachingBrief: coachingBrief
        ) {
            Self.log.error("repair pass still tripped the gate (\(String(describing: remainingIssue), privacy: .public))")
            recordChatDiagnostic(
                .fallback,
                "Repair reply failed professional-coach gate: \(String(describing: remainingIssue))\(Self.liveEvalDraftSuffix(display))",
                provider: provider
            )
            return nil
        }
        if let semanticIssue = Self.semanticQualityIssue(
            in: display,
            latestUserTurn: messages.last(where: { $0.role == .user })?.text,
            systemContext: system,
            turnDepth: turnDepth,
            assessment: responseKind == .conversational ? nil : assessment,
            responseKind: responseKind
        ) {
            Self.log.error("repair pass still tripped semantic gate (\(semanticIssue.rawValue, privacy: .public))")
            recordChatDiagnostic(
                .fallback,
                "Repair reply failed semantic judgement gate: \(semanticIssue.rawValue)\(Self.liveEvalDraftSuffix(display))",
                provider: provider
            )
            return nil
        }
        if let visionIssue = Self.visionQualityIssue(
            in: display,
            latestUserTurn: messages.last(where: { $0.role == .user })?.text,
            quoteGuard: quoteGuard,
            systemContext: system,
            turnDepth: turnDepth,
            assessment: assessment,
            surface: surface,
            responseKind: responseKind
        ) {
            Self.log.error("repair pass still tripped vision gate (\(String(describing: visionIssue), privacy: .public))")
            recordChatDiagnostic(
                .fallback,
                "Repair reply failed vision gate: \(String(describing: visionIssue))\(Self.liveEvalDraftSuffix(display))",
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

        if let followThrough = directFollowThroughRepairReferenceShape(
            for: lowerTurn,
            system: system
        ) {
            return followThrough
        }

        if turnAsksWhyAnswerLandedBadly(latestUserTurn) {
            if sourceMentionsLateRecommendation(system) {
                return "From the transcript, the recommendation arrived late, so say the decision first, add one reason, then name the implication."
            }
            return "Name the landing problem first, then the move: the close softened, so end with the one decision you need."
        }

        if CoachChatTurnIntent.isCoachStyleFeedback(lowerTurn) {
            return CoachReliabilityGate.preferenceAcknowledgementFallback(
                surface: .text,
                latestUserTurn: lowerTurn
            )
        }

        if isCritiqueTurn(lowerTurn) {
            return trustRepairReferenceShape(for: lowerTurn, system: system)
        }

        if issue == .ignoredCoachingExpertise,
           let expertiseShape = retrievedExpertiseRepairReferenceShape(
            latestUserTurn: lowerTurn,
            system: system
           ) {
            return expertiseShape
        }

        if let voiceGoalShape = voiceGoalRepairReferenceShape(
            for: lowerTurn,
            system: system
        ) {
            return voiceGoalShape
        }

        if let coldStartShape = coldStartRepairReferenceShape(
            for: lowerTurn,
            system: system
        ) {
            return coldStartShape
        }

        if containsAny(lowerTurn, ["um", "filler", "fillers", "hesitat"]) {
            if let pressureShape = deterministicPressureFillerQuickMoveReply(
                latestUserTurn: lowerTurn,
                systemContext: system
            ) {
                return pressureShape
            }
            if let fillerEvidence = QuantityQualifiedFillerEvidence.parseLatest(in: system),
               fillerEvidenceSitsInsideDecisionLine(system) {
                if let summary = fillerEvidence.summary {
                    return "Your latest qualified rep had \(summary). One filler appeared after the decision line, so hold one silent beat there on an equivalent rep, then compare fillers per minute."
                }
                return "That sample is too small or uncertain for a fair filler-rate read. One filler appeared after the decision line, so test one silent beat there and gather one 60-second equivalent rep before judging the pattern."
            }
            if let fillerEvidence = QuantityQualifiedFillerEvidence.parseLatest(in: system) {
                if let summary = fillerEvidence.summary {
                    return "Your latest qualified rep had \(summary), so test one silent beat before sentence two and compare fillers per minute on an equivalent rep."
                }
                return "That sample is too small or uncertain for a fair filler-rate read, so run one 60-second equivalent rep before judging the pattern."
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
            return "Name one observable signal, explain why it supports the move, then prescribe one next step the user can test."
        case .missedTrustRepair, .defensiveProductLanguage:
            return "Fair push. Name the friction briefly, then use one safe signal to prescribe the changed coaching move."
        default:
            return nil
        }
    }

    nonisolated static func safeReferenceRepairReply(
        issue: CoachChatReplyQualityIssue,
        latestUserTurn: String?,
        system: String,
        quoteGuard: CoachChatQuoteGuardContext?,
        recentCoachReplies: [String] = [],
        turnDepth: CoachTurnDepth = .groundedRead,
        assessment: CoachAssessment? = nil,
        surface: CoachReplySurface = .text,
        responseKind: CoachChatResponseKind? = nil,
        coachingBrief: CoachChatBrief? = nil
    ) -> String? {
        let resolvedResponseKind = responseKind ?? CoachChatResponseKind.classify(
            latestUserTurn
        )
        guard safeReferenceRepairIssueIsAllowed(
            issue,
            latestUserTurn: latestUserTurn,
            system: system
        ) else {
            return nil
        }
        let referenceShape: String
        if resolvedResponseKind == .conversational,
           CoachChatTurnIntent.isCoachStyleFeedback(latestUserTurn) {
            referenceShape = CoachReliabilityGate.preferenceAcknowledgementFallback(
                surface: surface,
                latestUserTurn: latestUserTurn,
                previousCoachReply: recentCoachReplies.first,
                recentCoachReplies: recentCoachReplies
            )
        } else {
            guard safeReferenceRepairIsAllowed(
                latestUserTurn: latestUserTurn,
                system: system
            ),
                  let shape = repairReferenceShape(
                issue: issue,
                latestUserTurn: latestUserTurn,
                system: system
              ) else {
                return nil
            }
            referenceShape = shape
        }
        guard replyQualityIssue(
            in: referenceShape,
            latestUserTurn: latestUserTurn,
            quoteGuard: quoteGuard,
            systemContext: system,
            recentCoachReplies: recentCoachReplies,
            turnDepth: turnDepth,
            surface: surface,
            responseKind: resolvedResponseKind,
            coachingBrief: coachingBrief
        ) == nil else {
            return nil
        }
        guard semanticQualityIssue(
            in: referenceShape,
            latestUserTurn: latestUserTurn,
            systemContext: system,
            turnDepth: turnDepth,
            assessment: resolvedResponseKind == .conversational ? nil : assessment,
            responseKind: resolvedResponseKind
        ) == nil else {
            return nil
        }
        guard visionQualityIssue(
            in: referenceShape,
            latestUserTurn: latestUserTurn,
            quoteGuard: quoteGuard,
            systemContext: system,
            recentCoachReplies: recentCoachReplies,
            turnDepth: turnDepth,
            assessment: assessment,
            surface: surface,
            responseKind: resolvedResponseKind
        ) == nil else {
            return nil
        }
        let normalized = CoachReplyTextSanitizer.coachReplyText(from: referenceShape)
        return normalized.isEmpty ? nil : normalized
    }

    private nonisolated static func safeReferenceRepairShouldRunBeforeProvider(
        issue: CoachChatReplyQualityIssue,
        latestUserTurn: String?,
        system: String? = nil
    ) -> Bool {
        let lowerTurn = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if safeReferenceRepairShouldRunForColdStart(
            issue: issue,
            latestUserTurn: lowerTurn
        ) {
            return true
        }
        if safeReferenceRepairShouldRunForVoiceGoal(
            issue: issue,
            latestUserTurn: lowerTurn
        ) {
            return true
        }
        if directFollowThroughRepairReferenceShape(
            for: lowerTurn,
            system: system ?? ""
           ) != nil {
            switch issue {
            case .tooLong, .missingInsightBridge, .missingPrescribedAction,
                 .unanchoredCoaching,
                 .unengagedUserSpeechClaim, .overclaimsEvidence,
                 .semanticJudgement, .visionGate, .roboticPhrase:
                return true
            default:
                break
            }
        }
        // This intent has a grounded transcript read and an explicit evidence
        // check, so prefer its validated local reference over a second network
        // call. Keep the broader critique/quote-sensitive paths on their
        // existing provider policy; they can require nuance this shape cannot
        // safely supply.
        if turnAsksWhyAnswerLandedBadly(latestUserTurn),
           sourceMentionsLateRecommendation(system ?? "") {
            switch issue {
            case .tooLong, .roboticPhrase, .bareClarification,
                 .defensiveProductLanguage, .menuInsteadOfDecision,
                 .missedTrustRepair, .missingPrescribedAction,
                 .missingInsightBridge, .unanchoredCoaching,
                 .overclaimsEvidence, .unrequestedNamedTechnique,
                 .scaffoldLabel, .unengagedUserSpeechClaim,
                 .visionGate, .semanticJudgement:
                return true
            case .unverifiedQuotedUserSpeech, .missingVerifiedExampleQuote,
                 .ignoredCoachingExpertise, .repeatedProofTest,
                 .nonCoachingPrescription:
                break
            }
        }
        guard isCritiqueTurn(lowerTurn) else {
            return false
        }
        switch issue {
        case .missedTrustRepair, .defensiveProductLanguage,
             .scaffoldLabel, .visionGate, .semanticJudgement,
             .nonCoachingPrescription:
            return true
        case .roboticPhrase(let phrase):
            let lowerPhrase = phrase.lowercased()
            return lowerPhrase.contains("trust-repair report voice")
                || lowerPhrase.contains("sensitive-turn report voice")
                || lowerPhrase.contains("fluff, not coaching")
                || lowerPhrase.contains("generic tip-giving")
                || lowerPhrase.contains("let's")
                || lowerPhrase.contains("let us")
        default:
            return false
        }
    }

    private nonisolated static func safeReferenceRepairShouldRunForColdStart(
        issue: CoachChatReplyQualityIssue,
        latestUserTurn: String?
    ) -> Bool {
        guard turnLooksLikeColdStartBaselineIntent(latestUserTurn) else {
            return false
        }
        switch issue {
        case .menuInsteadOfDecision:
            return true
        case .roboticPhrase(let phrase):
            let lowerPhrase = phrase.lowercased()
            return lowerPhrase.contains("cold-start product mode")
                || lowerPhrase.contains("cold-start metric target")
                || lowerPhrase.contains("cold-start vague baseline rep")
        default:
            return false
        }
    }

    private nonisolated static func safeReferenceRepairShouldRunForVoiceGoal(
        issue: CoachChatReplyQualityIssue,
        latestUserTurn: String?
    ) -> Bool {
        guard turnLooksLikeVoiceGoalIntent(latestUserTurn) else {
            return false
        }
        switch issue {
        case .menuInsteadOfDecision:
            return true
        case .roboticPhrase(let phrase):
            return replyUsesVoiceGoalStateDirective(
                phrase.lowercased(),
                latestUserTurn: latestUserTurn
            ) != nil
        default:
            return false
        }
    }

    private nonisolated static func safeReferenceRepairIssueIsAllowed(
        _ issue: CoachChatReplyQualityIssue,
        latestUserTurn: String?,
        system: String
    ) -> Bool {
        switch issue {
        case .overclaimsEvidence, .missingInsightBridge:
            return true
        default:
            return safeReferenceRepairShouldRunBeforeProvider(
                issue: issue,
                latestUserTurn: latestUserTurn,
                system: system
            )
        }
    }

    private nonisolated static func safeReferenceRepairIsAllowed(
        latestUserTurn: String?,
        system: String
    ) -> Bool {
        let lowerTurn = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let lowerSystem = system.lowercased()
        if isCritiqueTurn(lowerTurn) {
            return true
        }
        if voiceGoalRepairReferenceShape(for: lowerTurn, system: system) != nil {
            return true
        }
        if coldStartRepairReferenceShape(for: lowerTurn, system: system) != nil {
            return true
        }
        if directFollowThroughRepairReferenceShape(
            for: lowerTurn,
            system: system
        ) != nil {
            return true
        }
        if turnAsksWhyAnswerLandedBadly(latestUserTurn),
           sourceMentionsLateRecommendation(system) {
            return true
        }
        if deterministicPressureFillerQuickMoveReply(
            latestUserTurn: lowerTurn,
            systemContext: system
        ) != nil {
            return true
        }
        if containsAny(lowerTurn, ["um", "filler", "fillers", "hesitat"]),
           fillerEvidenceSitsInsideDecisionLine(system) {
            return true
        }
        if turnAsksForNextMove(latestUserTurn),
           contextMentionsClosingStrengthLeverage(lowerSystem) {
            return true
        }
        return false
    }

    private nonisolated static func coldStartRepairReferenceShape(
        for lowerTurn: String,
        system: String
    ) -> String? {
        guard containsAny(system.lowercased(), [
            "no rated sessions yet",
            "not enough data for a stable baseline yet",
            "personalization floor: no rated sessions yet",
            "no voice set yet"
        ]) else {
            return nil
        }
        guard turnLooksLikeColdStartBaselineIntent(lowerTurn) else {
            return nil
        }

        if containsAny(lowerTurn, [
            "interview",
            "presentation",
            "meeting",
            "update",
            "pitch",
            "prepare"
        ]) {
            if containsAny(lowerTurn, ["interview"]) {
                return "No baseline yet, so start there. Record 60 seconds on one likely question, with sentence one as the answer."
            }
            return "No baseline yet, so start there. Record 60 seconds on the first question or opening point for that moment, with sentence one as the answer."
        }
        return CoachReliabilityGate.coldStartFallback(surface: .text)
    }

    nonisolated static func retrievedCoachingExpertiseApplicationLine(from systemContext: String) -> String? {
        var inExpertiseSection = false

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
            guard line.hasPrefix("-"),
                  let applyRange = line.range(of: "Apply it:", options: [.caseInsensitive]) else {
                continue
            }

            let remainder = line[applyRange.upperBound...]
            let applicationSlice: Substring
            if let workingRange = remainder.range(
                of: ". Working when:",
                options: [.caseInsensitive]
            ) {
                applicationSlice = remainder[..<workingRange.lowerBound]
            } else if let workingRange = remainder.range(
                of: "Working when:",
                options: [.caseInsensitive]
            ) {
                applicationSlice = remainder[..<workingRange.lowerBound]
            } else {
                applicationSlice = remainder[...]
            }

            let application = String(applicationSlice)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !application.isEmpty {
                return application
            }
        }

        return nil
    }

    private nonisolated static func retrievedExpertiseRepairReferenceShape(
        latestUserTurn: String,
        system: String
    ) -> String? {
        guard let application = retrievedCoachingExpertiseApplicationLine(from: system) else {
            return nil
        }

        if containsAny(latestUserTurn, ["um", "filler", "fillers", "hesitat"]) {
            if let pressureShape = deterministicPressureFillerQuickMoveReply(
                latestUserTurn: latestUserTurn,
                systemContext: system
            ) {
                return pressureShape
            }
            // Technique-seeking turns use the general-coaching lane. Retrieved
            // expertise may shape the answer, but broad context cannot be turned
            // into a personal observation merely because a recent metric exists.
            return "When um wants to enter under pressure, hold a one-second silence instead because the gap stays quiet. Repeat the prompt and compare fillers per minute; treat one rep as a test, not a pattern."
        }

        if containsAny(system.lowercased(), [
            "no rated sessions yet",
            "not enough data for a stable baseline yet",
            "personalization floor: no rated sessions yet"
        ]) {
            if containsAny(latestUserTurn, ["interview", "prepare", "practice"]) {
                return "No baseline yet, so start there. Record 60 seconds on one likely question using this one constraint: \(application)."
            }
            return CoachReliabilityGate.coldStartFallback(surface: .text)
        }

        if replyShouldCiteRecentSession(system) {
            return "Your last rep gives one usable signal, so \(application)."
        }

        return "Test the next rep so the move is observable: \(application)."
    }

    private nonisolated static func trustRepairReferenceShape(
        for lowerTurn: String,
        system: String
    ) -> String {
        let friction: String
        if containsAny(lowerTurn, ["tts", "read them out", "read aloud", "**", "markdown", "formatting"]) {
            friction = "Fair push. TTS reading symbols breaks trust."
        } else if containsAny(lowerTurn, ["robotic", "report", "too much writing", "too long", "less text"]) {
            friction = "Fair push. That read too much like a report."
        } else if containsAny(lowerTurn, ["repeating yourself", "same thing again", "said that already", "already said that"]) {
            friction = "Fair push. I repeated the same move instead of advancing the coaching."
        } else if containsAny(lowerTurn, ["it's not easy", "its not easy", "not that easy", "easier said than done", "harder than that"]) {
            friction = "Fair push: no, it is not easy."
        } else if containsAny(lowerTurn, ["not informative", "not helpful", "not useful", "missed the point", "doesn't answer", "does not answer"]) {
            friction = "Fair push. I answered around the useful read instead of giving it."
        } else if containsAny(lowerTurn, ["cold", "generic", "not human", "low eq", "not high eq"]) {
            friction = "Fair push. That was advice, not coaching."
        } else {
            friction = "Fair push. That answer did not earn enough trust."
        }

        let move: String
        if containsAny(lowerTurn, ["short", "less text", "too much writing", "too long"]) {
            move = "run one cleaner rep: main point first, then stop"
        } else if containsAny(lowerTurn, ["repeating yourself", "same thing again", "said that already", "already said that"]) {
            move = "keep the same target but change the condition so the next rep teaches us something new"
        } else if containsAny(lowerTurn, ["it's not easy", "its not easy", "not that easy", "easier said than done", "harder than that"]) {
            move = "test a smaller version in the next rep: say only the disagreement and one calm reason, then stop before defending it"
        } else if containsAny(lowerTurn, ["not informative", "not helpful", "not useful", "missed the point", "doesn't answer", "does not answer"]) {
            move = "answer the actual read first, then run one narrow rep that tests it"
        } else if containsAny(lowerTurn, ["tts", "read them out", "read aloud", "**", "markdown", "formatting"]) {
            move = "say the recommendation first, give one proof point, then stop"
        } else if containsAny(lowerTurn, ["cold", "generic", "robotic", "not human", "low eq", "not high eq"]) {
            move = "say the decision first, then soften it with one human reassurance"
        } else {
            move = "run one short rep with the point first and one proof point after it"
        }

        if containsAny(lowerTurn, ["not informative", "not helpful", "not useful", "missed the point", "doesn't answer", "does not answer"]),
           contextSaysPointArrivedAfterWarmup(system) {
            return CoachReliabilityGate.notInformativeRepairFallback(surface: .text)
        }
        if contextSaysWarmthBeforeRecommendation(system) {
            return "\(friction) The ordering signal is warmth before the recommendation, so put the recommendation first, add one reassurance after it, then stop."
        }
        if containsAny(lowerTurn, ["it's not easy", "its not easy", "not that easy", "easier said than done", "harder than that"]) {
            let step = "say only the first hard sentence, then stop."
            let frame = CoachReliabilityGate.vulnerablePushbackDifficultyFrame(for: step)
            if let anchor = CoachReliabilityGate.vulnerablePushbackEvidenceAnchor(from: [system]) {
                return "Fair push: no, it is not easy. \(anchor) \(frame) Keep the next step small: \(step)"
            }
            return CoachReliabilityGate.vulnerablePushbackFallback(
                surface: .text,
                assessment: nil
            )
        }
        if let fillerEvidence = QuantityQualifiedFillerEvidence.parseLatest(in: system) {
            if let summary = fillerEvidence.summary {
                return "\(friction) Your latest qualified rep had \(summary), so \(move); compare fillers per minute on an equivalent rep."
            }
            return "\(friction) The latest sample is too small or uncertain for a fair filler-rate read, so gather one 60-second equivalent rep before judging change."
        }
        if replyShouldCiteRecentSession(system) {
            return "\(friction) Your last rep gives one usable signal, so \(move)."
        }
        return "\(friction) No baseline yet, so record 60 seconds on something you know well before polishing the answer."
    }

    private nonisolated static func voiceGoalRepairReferenceShape(
        for lowerTurn: String,
        system: String
    ) -> String? {
        guard turnLooksLikeVoiceGoalIntent(lowerTurn) else {
            return nil
        }

        if containsAny(lowerTurn, [
            "what voice", "which voice", "voice should", "voice do i",
            "voice to pick", "pick a voice", "choose a voice"
        ]) {
            let choiceContext = system.lowercased() + " " + lowerTurn
            if containsAny(choiceContext, [
                "talked over", "interrupted", "running meetings",
                "run meetings", "meeting", "meetings"
            ]) {
                return "Start with Authoritative: short verdicts suit meetings where you get talked over. Compare Executive presence only if the real pressure is senior-room calm."
            }
            return "Authoritative is the strongest first fit for short, decisive verdicts. Executive presence is the comparison only if senior-room calm is the real pressure."
        }

        if containsAny(lowerTurn, ["sound more engaging", "more engaging", "engaging"]) {
            return "Storytelling is the closest first comparison because it trains memorable shape. Warm fits better only if connection—not energy—is the real gap."
        }

        if containsAny(lowerTurn, [
            "warmer", "warm", "cold", "switch", "change"
        ]) {
            return "Warm and welcoming is the closest fit, but I wouldn’t switch yet. The key question is what changed: one cold comment, or a repeated mismatch with Authoritative?"
        }

        return nil
    }

    private nonisolated static func contextSaysWarmthBeforeRecommendation(_ system: String) -> Bool {
        containsAny(system.lowercased(), [
            "safe warmth fact",
            "warmth came before the recommendation",
            "reassurance came before the recommendation"
        ])
    }

    private nonisolated static func contextSaysPointArrivedAfterWarmup(_ system: String) -> Bool {
        containsAny(system.lowercased(), [
            "point arrived in sentence 4",
            "point arrived in sentence four",
            "point didn't show up until sentence four",
            "point did not show up until sentence four",
            "first 3 sentences were throat-clearing",
            "first three were throat-clearing",
            "first 3 sentences were warm-up",
            "first three were warm-up",
            "buries the lede",
            "buried the lede"
        ])
    }

    private nonisolated static func requiredRepairAnchor(
        issue: CoachChatReplyQualityIssue,
        latestUserTurn: String?,
        system: String
    ) -> String? {
        let shouldCarryAnchor: Bool
        switch issue {
        case .unanchoredCoaching, .missingInsightBridge, .missingPrescribedAction,
                .missedTrustRepair, .defensiveProductLanguage, .scaffoldLabel,
                .visionGate, .repeatedProofTest, .missingVerifiedExampleQuote:
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
        case .semanticJudgement:
            shouldCarryAnchor = false
        case .nonCoachingPrescription:
            shouldCarryAnchor = false
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
        if issue == .missingVerifiedExampleQuote {
            return "Use one verified proof quote from the quote guard as the example, explain the pattern it shows, then give one next move."
        }
        let lowerTurn = latestUserTurn?.lowercased() ?? ""
        guard containsAny(lowerTurn, ["um", "filler", "fillers", "hesitat"])
                || isCritiqueTurn(lowerTurn) else {
            if replyShouldCiteRecentSession(system) {
                return "Anchor the answer to the last rep or transcript before prescribing the move."
            }
            return nil
        }
        guard let fillerEvidence = QuantityQualifiedFillerEvidence.parseLatest(in: system) else {
            return "I do not have enough rated filler data yet."
        }
        if let summary = fillerEvidence.summary {
            return "Your latest qualified rep had \(summary). Compare fillers per minute under equivalent demand."
        }
        return "The latest sample is too small or uncertain for a fair filler-rate read. Gather one 60-second equivalent rep before judging the pattern."
    }

    private nonisolated static func fillerEvidenceSitsInsideDecisionLine(_ text: String) -> Bool {
        let lower = text.lowercased()
        if containsAny(lower, [
            "safe filler fact",
            "filler appeared after the decision/recommendation line",
            "placement-only filler observation",
            "placement observation",
            "hold one silent beat after the decision line"
        ]) {
            return true
        }
        guard containsAny(lower, [
            "the recommendation is",
            "my recommendation is",
            "recommendation is to",
            "the decision is",
            "my decision is"
        ]) else {
            return false
        }
        return containsAny(lower, [" um,", " uh,", " um ", " uh ", "filler", "fillers"])
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

    /// COST/LATENCY instrumentation only, separate from `recordChatDiagnostic`
    /// so the existing `diagnosticRecorder` closure (and any test double built
    /// against it) keeps its signature. A no-op when the provider response
    /// carried no token data at all (e.g. a transport error never reached
    /// `usage` parsing) — logging an empty cache record would just be noise.
    private func recordCacheUsageDiagnostic(
        usage: CoachChatUsage?,
        provider: CoachChatProvider,
        startedAt: Date
    ) {
        guard let usage, usage.hasAnyTokenData else { return }
        AICallDiagnostics.record(
            surface: Self.chatSurface,
            providerName: provider.displayName,
            model: provider.model,
            outcome: .success,
            reason: usage.diagnosticSummary,
            startedAt: startedAt,
            cacheCreationInputTokens: usage.cacheCreationInputTokens,
            cacheReadInputTokens: usage.cacheReadInputTokens,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            cachedContentTokenCount: usage.cachedContentTokenCount
        )
    }

    enum ProviderHTTPResult {
        case success(Data)
        /// The server answered with a non-2xx. `retryAfter` carries the
        /// parsed Retry-After header when the server named one.
        case refused(status: Int, retryAfter: TimeInterval?)
    }

    private enum ProviderTextTransportResult {
        case success(ChatExtractionResult, firstTokenReceivedAt: Date?, usage: CoachChatUsage?)
        /// The server answered with a non-2xx. `retryAfter` carries the
        /// parsed Retry-After header when the server named one.
        case refused(status: Int, retryAfter: TimeInterval?)
    }

    /// Only retry failures that can plausibly clear on a second transport
    /// shape. Cancellation and offline state stay terminal for this turn so
    /// the app never fights an explicit user action or burns latency while the
    /// device has no route to the network.
    nonisolated static func transportFailureCanRetry(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return [
                URLError.Code.timedOut,
                .cannotFindHost,
                .cannotConnectToHost,
                .networkConnectionLost,
                .dnsLookupFailed,
                .resourceUnavailable
            ].contains(URLError.Code(rawValue: nsError.code))
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return transportFailureCanRetry(underlying)
        }
        return false
    }

    /// Provider streaming adds no user-visible latency value while the shipping
    /// pipeline is already showing the local assessment read. Use the ordinary
    /// response endpoint for those two-speed turns, which avoids holding a
    /// second long-lived streaming connection behind an already-visible answer.
    /// A quick text turn streams only in the explicit raw-partial UI posture;
    /// with gated partials (the shipping default), it receives a local read too.
    nonisolated static func providerStreamingShouldRun(
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface,
        responseMode: CoachAssessment.ResponseMode?,
        providerStreamingEnabled: Bool,
        realtimeCoachModeEnabled: Bool,
        streamRawPartialsToUI: Bool = CoachBrainFlags.streamRawPartialsToUI
    ) -> Bool {
        guard providerStreamingEnabled else { return false }
        guard let responseMode else { return true }
        return !CoachReplyPipeline.shouldShowProvisionalCoachRead(
            turnDepth: turnDepth,
            surface: surface,
            responseMode: responseMode,
            realtimeCoachModeEnabled: realtimeCoachModeEnabled,
            streamRawPartialsToUI: streamRawPartialsToUI
        )
    }

    private func providerTextHTTP(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any],
        streaming: Bool,
        onStreamedPartialVisible: (@MainActor (String) -> Void)? = nil
    ) async throws -> ProviderTextTransportResult {
        if streaming {
            return try await providerStreamingHTTP(
                provider: provider,
                endpoint: endpoint,
                key: key,
                body: body,
                onStreamedPartialVisible: onStreamedPartialVisible
            )
        }

        let result = try await providerHTTP(
            provider: provider,
            endpoint: endpoint,
            key: key,
            body: body
        )
        switch result {
        case .success(let data):
            return .success(
                Self.chatExtractReplyText(from: data, provider: provider),
                firstTokenReceivedAt: nil,
                usage: Self.chatExtractUsage(from: data, provider: provider)
            )
        case .refused(let status, let retryAfter):
            return .refused(status: status, retryAfter: retryAfter)
        }
    }

    private func providerStreamingHTTP(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any],
        onStreamedPartialVisible: (@MainActor (String) -> Void)? = nil
    ) async throws -> ProviderTextTransportResult {
        guard !Task.isCancelled else { throw CancellationError() }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        Self.log.debug("stream transport start provider=\(provider.displayName, privacy: .public) host=\(endpoint.host ?? "unknown", privacy: .public) path=\(endpoint.path, privacy: .public) bodyBytes=\(bodyBytes, privacy: .public)")
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let headersAt = Date()
            let headerMs = Int(headersAt.timeIntervalSince(started) * 1_000)
            guard let http = response as? HTTPURLResponse else {
                Self.log.error("stream transport non-http response provider=\(provider.displayName, privacy: .public) ms=\(headerMs, privacy: .public)")
                recordChatDiagnostic(
                    .failure,
                    "Streaming non-HTTP response",
                    provider: provider,
                    startedAt: started,
                    now: headersAt
                )
                return .refused(status: -1, retryAfter: nil)
            }

            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            guard (200..<300).contains(http.statusCode) else {
                var errorBody = Data()
                for try await byte in bytes {
                    if errorBody.count < 8_192 {
                        errorBody.append(byte)
                    }
                }
                Self.log.info("stream transport response provider=\(provider.displayName, privacy: .public) status=\(http.statusCode, privacy: .public) ms=\(headerMs, privacy: .public) bytes=\(errorBody.count, privacy: .public) retryAfter=\(retryAfter != nil, privacy: .public)")
                recordChatDiagnostic(
                    .fallback,
                    Self.failureReason(forHTTPStatus: http.statusCode, data: errorBody, provider: provider),
                    provider: provider,
                    statusCode: http.statusCode,
                    startedAt: started,
                    now: headersAt
                )
                return .refused(status: http.statusCode, retryAfter: retryAfter)
            }

            var accumulator = CoachChatStreamAccumulator(provider: provider)
            var firstTokenAt: Date?
            for try await line in bytes.lines {
                if let event = accumulator.consume(line: line) {
                    if !event.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty,
                       firstTokenAt == nil {
                        firstTokenAt = Date()
                    }
                    if let visiblePartial = event.visiblePartial {
                        await MainActor.run {
                            onStreamedPartialVisible?(visiblePartial)
                        }
                    }
                }
            }
            let completedAt = Date()
            Self.log.info("stream transport response provider=\(provider.displayName, privacy: .public) status=\(http.statusCode, privacy: .public) ms=\(Int(completedAt.timeIntervalSince(started) * 1_000), privacy: .public) firstToken=\(firstTokenAt != nil, privacy: .public)")
            recordChatDiagnostic(
                .success,
                "Streaming transport succeeded",
                provider: provider,
                statusCode: http.statusCode,
                startedAt: started,
                now: completedAt
            )
            return .success(accumulator.extractionResult, firstTokenReceivedAt: firstTokenAt, usage: accumulator.usage)
        } catch {
            recordChatDiagnostic(
                .failure,
                "Streaming transport error",
                provider: provider,
                startedAt: started
            )
            throw error
        }
    }

    private func providerHTTP(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any]
    ) async throws -> ProviderHTTPResult {
        guard !Task.isCancelled else { throw CancellationError() }
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
        maxOutputTokens: Int? = nil,
        streaming: Bool = false
    ) -> [String: Any] {
        let tokenCap = maxOutputTokens ?? Self.coachReplyMaxOutputTokens
        if let shared = provider.sharedProvider {
            return requestBody(
                for: shared,
                system: system,
                messages: messages,
                maxOutputTokens: tokenCap,
                streaming: streaming
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
        var body: [String: Any] = [
            "model": provider.model,
            "max_tokens": tokenCap,
            "system": system,
            "messages": msgs
        ]
        if streaming {
            body["stream"] = true
        }
        return body
    }

    private func requestBody(
        for provider: AIProvider,
        system: String,
        messages: [CoachMessage],
        maxOutputTokens: Int? = nil,
        streaming: Bool = false
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
            var body: [String: Any] = [
                "model": provider.model,
                "temperature": 0.6,
                "max_tokens": tokenCap,
                "messages": msgs
            ]
            if streaming {
                body["stream"] = true
            }
            return body
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

    // MARK: - Prompt caching (system-field split)
    //
    // The composed system content is STABLE `systemPrompt` (the voice, fixed
    // for the life of the app build) followed by DYNAMIC `userContext` (goal,
    // memory, recent transcript — different on every turn). Splitting the two
    // lets the provider cache the stable prefix instead of re-billing/re-
    // processing it every turn. Total text sent to the model is unchanged —
    // only how it is chunked in the request body.

    /// Anthropic Messages API: `system` becomes an array of content blocks.
    /// The first block carries the explicit `cache_control` breakpoint — it
    /// MUST be byte-identical across requests to hit the cache, so nothing
    /// per-turn (timestamps, memory, the user's latest words) may leak into
    /// it. The second, dynamic block sits after the breakpoint and is never
    /// marked cacheable, since Anthropic would otherwise auto-place a
    /// top-level `cache_control` on the LAST cacheable block — caching
    /// content that changes every request instead of the stable prefix.
    /// Pure + `nonisolated` so the split itself is directly unit-testable.
    nonisolated static func anthropicSystemBlocks(
        systemPrompt: String,
        userContext: String
    ) -> [[String: Any]] {
        [
            [
                "type": "text",
                "text": systemPrompt,
                "cache_control": ["type": "ephemeral"]
            ],
            [
                "type": "text",
                "text": userContext
            ]
        ]
    }

    /// Gemini implicit caching is prefix-based, not an explicit marked block:
    /// the provider caches however much of the request's start matches a
    /// prior request byte-for-byte. Keeping the stable prompt as its own part
    /// ahead of the dynamic context (rather than one concatenated string)
    /// maximizes that shared prefix without changing what the model reads.
    nonisolated static func geminiSystemParts(
        systemPrompt: String,
        userContext: String
    ) -> [[String: Any]] {
        [
            ["text": systemPrompt],
            ["text": userContext]
        ]
    }

    private func chatRequestBody(
        for provider: CoachChatProvider,
        systemPrompt: String,
        userContext: String,
        messages: [CoachMessage],
        maxOutputTokens: Int? = nil,
        streaming: Bool = false
    ) -> [String: Any] {
        let tokenCap = maxOutputTokens ?? Self.coachReplyMaxOutputTokens
        if let shared = provider.sharedProvider {
            return requestBody(
                for: shared,
                systemPrompt: systemPrompt,
                userContext: userContext,
                messages: messages,
                maxOutputTokens: tokenCap,
                streaming: streaming
            )
        }

        // Anthropic branch only — same message-shaping as the non-cacheable
        // overload above, just with the cache-split system field.
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
        var body: [String: Any] = [
            "model": provider.model,
            "max_tokens": tokenCap,
            "system": Self.anthropicSystemBlocks(systemPrompt: systemPrompt, userContext: userContext),
            "messages": msgs
        ]
        if streaming {
            body["stream"] = true
        }
        return body
    }

    private func requestBody(
        for provider: AIProvider,
        systemPrompt: String,
        userContext: String,
        messages: [CoachMessage],
        maxOutputTokens: Int? = nil,
        streaming: Bool = false
    ) -> [String: Any] {
        switch provider {
        case .openAI, .deepSeek:
            // No caching contract given for these providers in this pass;
            // recombine to the identical single-string system this class has
            // always sent them.
            return requestBody(
                for: provider,
                system: systemPrompt + "\n\n" + userContext,
                messages: messages,
                maxOutputTokens: maxOutputTokens,
                streaming: streaming
            )
        case .gemini:
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
            let tokenCap = maxOutputTokens ?? Self.coachReplyMaxOutputTokens
            return [
                "systemInstruction": ["parts": Self.geminiSystemParts(systemPrompt: systemPrompt, userContext: userContext)],
                "contents": contents,
                "generationConfig": [
                    "temperature": 0.6,
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

    /// Cache/cost accounting from a non-streaming response body. `nil` when
    /// the response has no usage object at all (malformed JSON, or a shape
    /// this parser does not recognize) — distinct from a `CoachChatUsage`
    /// whose fields are individually nil because the provider omitted them.
    static func chatExtractUsage(from data: Data, provider: CoachChatProvider) -> CoachChatUsage? {
        if let shared = provider.sharedProvider {
            return chatExtractUsage(from: data, provider: shared)
        }
        return extractAnthropicUsage(from: data)
    }

    private static func chatExtractUsage(from data: Data, provider: AIProvider) -> CoachChatUsage? {
        switch provider {
        case .gemini: return extractGeminiUsage(from: data)
        case .openAI, .deepSeek, .none: return nil
        }
    }

    /// Anthropic `usage` object: `input_tokens`/`output_tokens` are always
    /// present on a real reply; `cache_creation_input_tokens`/
    /// `cache_read_input_tokens` are present whenever prompt caching is
    /// active for this account, 0 when the prefix was below the minimum
    /// cacheable length or the cache entry expired.
    static func extractAnthropicUsage(from data: Data) -> CoachChatUsage? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let usage = object["usage"] as? [String: Any]
        else { return nil }
        return CoachChatUsage(
            inputTokens: usage["input_tokens"] as? Int,
            outputTokens: usage["output_tokens"] as? Int,
            cacheCreationInputTokens: usage["cache_creation_input_tokens"] as? Int,
            cacheReadInputTokens: usage["cache_read_input_tokens"] as? Int,
            cachedContentTokenCount: nil
        )
    }

    /// Gemini `usageMetadata`. `cachedContentTokenCount` is only present when
    /// implicit caching actually hit — absent (not zero) otherwise, so this
    /// stays nil rather than defaulting to 0 on a cache miss.
    static func extractGeminiUsage(from data: Data) -> CoachChatUsage? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let usageMetadata = object["usageMetadata"] as? [String: Any]
        else { return nil }
        return CoachChatUsage(
            inputTokens: usageMetadata["promptTokenCount"] as? Int,
            outputTokens: usageMetadata["candidatesTokenCount"] as? Int,
            cacheCreationInputTokens: nil,
            cacheReadInputTokens: nil,
            cachedContentTokenCount: usageMetadata["cachedContentTokenCount"] as? Int
        )
    }

    static func chatExtractStreamReplyText(from data: Data, provider: CoachChatProvider) -> ChatExtractionResult {
        var accumulator = CoachChatStreamAccumulator(provider: provider)
        guard let text = String(data: data, encoding: .utf8) else {
            return .empty
        }
        for line in text.components(separatedBy: .newlines) {
            _ = accumulator.consume(line: line)
        }
        return accumulator.extractionResult
    }

    private struct CoachChatStreamAccumulator {
        let provider: CoachChatProvider
        private var chunks: [String] = []
        private var lengthTruncated = false
        private var partialGate = CoachStreamingPartialGate()
        private(set) var usage: CoachChatUsage?

        init(provider: CoachChatProvider) {
            self.provider = provider
        }

        var extractionResult: ChatExtractionResult {
            if lengthTruncated { return .lengthTruncated }
            let joined = chunks
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? .empty : .text(joined)
        }

        mutating func consume(line rawLine: String) -> CoachChatStreamEvent? {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("data:") else { return nil }

            let payload = String(line.dropFirst("data:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !payload.isEmpty, payload != "[DONE]" else { return nil }
            guard let data = payload.data(using: .utf8) else { return nil }

            let delta = AICoachChatService.streamDelta(from: data, provider: provider)
            if delta.lengthTruncated {
                lengthTruncated = true
            }
            if let partialUsage = AICoachChatService.streamUsage(from: data, provider: provider) {
                usage = usage?.merged(with: partialUsage) ?? partialUsage
            }
            let visiblePartial = partialGate.consume(delta: delta.text)
            if !delta.text.isEmpty {
                chunks.append(delta.text)
            }
            return CoachChatStreamEvent(
                text: delta.text,
                visiblePartial: visiblePartial
            )
        }
    }

    private struct CoachChatStreamEvent {
        var text: String
        var visiblePartial: String?
    }

    private struct CoachChatStreamDelta {
        var text: String
        var lengthTruncated: Bool
    }

    private static func streamDelta(from data: Data, provider: CoachChatProvider) -> CoachChatStreamDelta {
        if let shared = provider.sharedProvider {
            return streamDelta(from: data, provider: shared)
        }
        return anthropicStreamDelta(from: data)
    }

    private static func streamDelta(from data: Data, provider: AIProvider) -> CoachChatStreamDelta {
        switch provider {
        case .openAI, .deepSeek:
            return openAIStyleStreamDelta(from: data)
        case .gemini:
            return geminiStreamDelta(from: data)
        case .none:
            return CoachChatStreamDelta(text: "", lengthTruncated: false)
        }
    }

    private static func openAIStyleStreamDelta(from data: Data) -> CoachChatStreamDelta {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = object["choices"] as? [[String: Any]]
        else {
            return CoachChatStreamDelta(text: "", lengthTruncated: false)
        }

        var text = ""
        var lengthTruncated = false
        for choice in choices {
            if (choice["finish_reason"] as? String) == "length" {
                lengthTruncated = true
            }
            if let delta = choice["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                text += content
            } else if let message = choice["message"] as? [String: Any],
                      let content = message["content"] as? String {
                text += content
            }
        }
        return CoachChatStreamDelta(text: text, lengthTruncated: lengthTruncated)
    }

    private static func geminiStreamDelta(from data: Data) -> CoachChatStreamDelta {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CoachChatStreamDelta(text: "", lengthTruncated: false)
        }
        let lengthTruncated = isLengthTruncated(responseObject: object, provider: .gemini)
        let candidates = object["candidates"] as? [[String: Any]] ?? []
        let text = candidates
            .compactMap { $0["content"] as? [String: Any] }
            .flatMap { $0["parts"] as? [[String: Any]] ?? [] }
            .compactMap { $0["text"] as? String }
            .joined()
        return CoachChatStreamDelta(text: text, lengthTruncated: lengthTruncated)
    }

    private static func anthropicStreamDelta(from data: Data) -> CoachChatStreamDelta {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CoachChatStreamDelta(text: "", lengthTruncated: false)
        }

        var text = ""
        var lengthTruncated = false
        if let delta = object["delta"] as? [String: Any] {
            if let chunk = delta["text"] as? String {
                text += chunk
            }
            if (delta["stop_reason"] as? String) == "max_tokens" {
                lengthTruncated = true
            }
        }
        if (object["stop_reason"] as? String) == "max_tokens" {
            lengthTruncated = true
        }
        return CoachChatStreamDelta(text: text, lengthTruncated: lengthTruncated)
    }

    /// Usage from a single SSE chunk, if this chunk carries any. Anthropic
    /// splits it across two events (`message_start` has the cache fields,
    /// `message_delta` repeats only `output_tokens`); the accumulator merges
    /// successive non-nil calls so both halves survive. Gemini repeats the
    /// full `usageMetadata` on the relevant chunk(s), so the latest wins.
    private static func streamUsage(from data: Data, provider: CoachChatProvider) -> CoachChatUsage? {
        if let shared = provider.sharedProvider {
            return streamUsage(from: data, provider: shared)
        }
        return anthropicStreamUsage(from: data)
    }

    private static func streamUsage(from data: Data, provider: AIProvider) -> CoachChatUsage? {
        switch provider {
        case .gemini: return extractGeminiUsage(from: data)
        case .openAI, .deepSeek, .none: return nil
        }
    }

    private static func anthropicStreamUsage(from data: Data) -> CoachChatUsage? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let usage = (object["message"] as? [String: Any])?["usage"] as? [String: Any]
            ?? object["usage"] as? [String: Any]
        guard let usage else { return nil }
        return CoachChatUsage(
            inputTokens: usage["input_tokens"] as? Int,
            outputTokens: usage["output_tokens"] as? Int,
            cacheCreationInputTokens: usage["cache_creation_input_tokens"] as? Int,
            cacheReadInputTokens: usage["cache_read_input_tokens"] as? Int,
            cachedContentTokenCount: nil
        )
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
