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
//   • Token-bounded — temperature 0.6, output cap 520. The system
//     prompt brevity contract (compact 1-4 line replies) is what actually
//     keeps replies tight; the cap is a safety ceiling, not the length lever.
//     History: a 350 cap silently truncated. The default provider is a
//     *thinking* model (gemini-2.5-flash) whose budget is shared between
//     invisible reasoning tokens and visible text, so terse/ambiguous
//     early questions triggered heavy reasoning that ate the 350 budget
//     and guillotined the visible answer mid-word ("…guide you through
//     the app'"). Fix: Gemini reasoning is disabled (thinkingConfig
//     thinkingBudget 0) so the whole budget is visible text, and the cap
//     is 520 (headroom over the compact reply contract).
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

/// Provider response extraction result for Ask Noum text replies. Kept typed
/// so the service can preserve truncation honesty without treating every
/// no-text response as a user-visible dead end.
enum ChatExtractionResult: Equatable {
    case text(String)
    case empty
    case lengthTruncated
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
    case unverifiedQuotedUserSpeech
    case unengagedUserSpeechClaim

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
            return "The user challenged the coaching quality. Repair trust first, name the friction briefly, and show the changed coaching move."
        case .missingPrescribedAction:
            return "The draft does not prescribe a concrete next move. Give one action the user can take in the next rep or review."
        case .missingInsightBridge:
            return "The draft gives an anchor and an action but does not connect them with a coaching read. Add the reason this move fits the signal."
        case .unanchoredCoaching:
            return "The draft is not anchored in an observable fact, recent user message, case-file target, or honest data gap. Add one grounded anchor."
        case .overclaimsEvidence:
            return "The draft overclaims from limited evidence or labels the user. Reframe as a tentative coaching hypothesis the user can confirm or reject."
        case .unverifiedQuotedUserSpeech:
            return "The draft quotes user speech that is not verified against a transcript or the latest user turn. Remove the quote and cite a metric, pattern, or honest data gap instead."
        case .unengagedUserSpeechClaim:
            return "The draft claims to read the user's words but does not touch any known transcript, verified proof, or their latest message. Ground the read in what they actually said, or cite a metric, pattern, or honest data gap instead."
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
/// Anthropic, which only the chat surface speaks today — promoting it into
/// `AIProvider` proper means giving every AI service a request/extract branch
/// (~40 switch sites across the AI layer), tracked as a follow-up. Declaration
/// order is the failover preference order.
enum CoachChatProvider: CaseIterable, Equatable, Hashable {
    case gemini
    case anthropic
    case openAI
    case deepSeek

    /// The shared-provider equivalent whose request/extract plumbing already
    /// exists, or nil for chat-only providers with their own branch.
    var sharedProvider: AIProvider? {
        switch self {
        case .gemini: return .gemini
        case .openAI: return .openAI
        case .deepSeek: return .deepSeek
        case .anthropic: return nil
        }
    }

    var keyName: String {
        switch self {
        case .gemini: return "GEMINI_API_KEY"
        case .anthropic: return "ANTHROPIC_API_KEY"
        case .openAI: return "OPENAI_API_KEY"
        case .deepSeek: return "DEEPSEEK_API_KEY"
        }
    }

    var model: String {
        switch self {
        // Haiku: the chat contract is 1-2 sentences in a fixed voice —
        // fast + cheap fits; the system prompt carries the intelligence.
        case .anthropic: return "claude-haiku-4-5"
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
        case .gemini: return "Gemini"
        case .anthropic: return "Claude"
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        }
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

actor AICoachChatService {

    static let shared = AICoachChatService()

    private static let log = Logger(subsystem: "com.jordancoaten.noum", category: "CoachChat")

    /// Providers that refused recently sit at the BACK of the chain until
    /// this date — never dropped entirely, because a cooling provider is
    /// still better than no provider when it's the only one keyed.
    private var providerCooldowns: [CoachChatProvider: Date] = [:]

    /// Cap on the number of chat messages we replay to the model per
    /// request. The user context block carries the long-arc summary,
    /// so older messages don't need to be sent — they'd inflate
    /// tokens without adding signal.
    private static let maxReplayMessages = 24

    private init() {}

    /// Send a turn to the model. Returns `.reply(text)` on a live success or
    /// `.failure(cause)` when the model cannot produce a safe answer. Total
    /// function — never throws. The store turns failures into honest system
    /// notices; Ask Noum must not synthesize local coach replies.
    func reply(
        history: [CoachMessage],
        systemPrompt: String,
        userContext: String,
        grounding: ChatGroundingContext = ChatGroundingContext()
    ) async -> ChatOutcome {
        #if DEBUG
        // UI harness only: lets simulator tests verify send -> pipeline ->
        // store -> system-notice rendering without depending on live provider
        // latency or keys. Production builds never see this branch.
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING_CHAT_FORCE_NOTICE") {
            return .failure(.network)
        }
        #endif

        // M13: AI surfaces are English-only. Non-English chat now resolves as
        // a typed notice rather than an English local coach substitute.
        guard await activeLocaleSupportsAI() else {
            return .failure(.localeUnsupported)
        }

        let keyed = Self.keyedProviders()
        guard !keyed.isEmpty else {
            Self.log.error("no chat provider has a key")
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
        var sawContentRejection = false
        for provider in chain {
            guard let endpoint = provider.endpoint, let key = key(for: provider) else { continue }
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
        return .failure(sawContentRejection ? .contentRejected : .network)
    }

    // MARK: - Provider chain

    /// Providers with a usable key, in declaration (preference) order.
    nonisolated static func keyedProviders(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> [CoachChatProvider] {
        CoachChatProvider.allCases.filter { provider in
            if let value = env[provider.keyName], !value.isEmpty { return true }
            return LocalConfigLoader.value(forKey: provider.keyName, plistNamed: "AIConfig") != nil
        }
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

    private enum AttemptOutcome {
        case reply(String)
        case refused(CoachChatProviderRefusal)
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
        do {
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
                return .refused(.classify(status: status))
            case .success(let data):
                let extraction = Self.chatExtractReplyText(from: data, provider: provider)
                switch extraction {
                case .text(let text):
                    if let issue = Self.replyQualityIssue(
                        in: text,
                        latestUserTurn: latestUserTurn,
                        quoteGuard: quoteGuard
                    ) {
                        Self.log.notice("\(provider.displayName, privacy: .public) reply tripped quality gate (\(String(describing: issue), privacy: .public)) — repairing")
                        if let repaired = await repairLowQualityReply(
                            issue: issue,
                            draft: text,
                            provider: provider,
                            endpoint: endpoint,
                            key: key,
                            system: system,
                            messages: messages,
                            quoteGuard: quoteGuard
                        ) {
                            return .reply(repaired)
                        }
                        // A content miss by this model on this turn — let the
                        // next provider in the chain take the question.
                        return .refused(.contentRejected)
                    }
                    return .reply(text)
                case .empty, .lengthTruncated:
                    Self.log.error("\(provider.displayName, privacy: .public) returned no usable text (\(extraction == .lengthTruncated ? "truncated" : "empty", privacy: .public))")
                    return .refused(.transient)
                }
            }
        } catch {
            Self.log.error("\(provider.displayName, privacy: .public) transport failure: \(error.localizedDescription, privacy: .public)")
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
        quoteGuard: CoachChatQuoteGuardContext? = nil
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

        if lower.contains("which direction would you prefer")
            || lower.contains("what is your priority")
            || (lower.contains("we can ") && lower.contains(" or ") && lower.contains("?")) {
            return .menuInsteadOfDecision
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
        "as an ai",
        "as your ai",
        "optimize your",
        "utilize"
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
            "hardcoded", "low eq", "not high eq"
        ])
    }

    private nonisolated static func turnRequestsExpandedAnswer(_ turn: String?) -> Bool {
        guard let lower = turn?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !lower.isEmpty else { return false }
        return containsAny(lower, [
            "plan", "full", "breakdown", "detail", "explain", "list",
            "7-day", "7 day", "week", "roadmap", "step by step"
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

    private nonisolated static func replyRepairsTrust(_ lower: String) -> Bool {
        containsAny(lower, [
            "fair", "you're right", "you are right", "good call", "useful push",
            "that read", "that felt", "the friction", "too generic", "too robotic",
            "i'll be", "i will be", "i'll keep", "i will keep", "i'll change",
            "i will change"
        ])
    }

    private nonisolated static func replyHasObservableAnchor(_ lower: String) -> Bool {
        if lower.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        return containsAny(lower, [
            "last rep", "recent rep", "next rep", "session", "transcript",
            "filler", "pace", "pause", "score", "wpm", "word choice",
            "you said", "you asked", "i heard", "what i notice", "pattern",
            "case", "hypothesis", "target", "success measure", "not enough data",
            "i don't have", "i do not have", "i can't see", "from what you wrote",
            "your message", "your words", "the friction"
        ])
    }

    private nonisolated static func replyPrescribesAction(_ lower: String) -> Bool {
        containsAny(lower, [
            "next rep", "try ", "practice", "run ", "hold ", "record",
            "answer", "send", "say ", "use ", "repeat", "do one", "focus",
            "start", "ask ", "replace", "keep the ", "keep this ", "cut ",
            "pause before", "one drill", "one rep", "review"
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
            "always do this", "you lack conviction", "you are weak"
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
        let repairSystem = """
        \(system)

        QUALITY REWRITE PASS
        The previous draft failed the Ask Noum professional-coach gate.
        Failure: \(issue.repairInstruction)

        Draft to replace:
        \(draft)

        Rewrite from scratch. Requirements:
        - 1-4 short lines, usually under 75 words.
        - Use **bold lead-ins**, up to 3 bullets, or numbered steps only when they reduce reading.
        - No long paragraph and no decorative formatting.
        - No broad menu. Pick one coaching move.
        - If the user showed frustration, do not defend the app.
        - Sound like a senior communications coach, not an assistant explaining itself.
        - Connect the evidence to the move with one coaching reason; do not just list a metric and a drill.
        """

        let body = chatRequestBody(for: provider, system: repairSystem, messages: messages)
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
            return nil
        }
        if let remainingIssue = Self.replyQualityIssue(
            in: text,
            latestUserTurn: messages.last(where: { $0.role == .user })?.text,
            quoteGuard: quoteGuard
        ) {
            Self.log.error("repair pass still tripped the gate (\(String(describing: remainingIssue), privacy: .public))")
            return nil
        }
        return text
    }

    // MARK: - Provider plumbing

    @MainActor
    private func activeLocaleSupportsAI() -> Bool {
        LocaleSettingsManager.shared.current.aiSupported
    }

    private func key(for provider: CoachChatProvider) -> String? {
        if let value = ProcessInfo.processInfo.environment[provider.keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: provider.keyName, plistNamed: "AIConfig")
    }

    // MARK: - Transport

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
        case .gemini:
            request.setGoogleAPIKey(key)
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            return .refused(status: -1, retryAfter: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            return .refused(status: http.statusCode, retryAfter: retryAfter)
        }
        return .success(data)
    }

    // MARK: - Request body construction

    private func chatRequestBody(
        for provider: CoachChatProvider,
        system: String,
        messages: [CoachMessage]
    ) -> [String: Any] {
        if let shared = provider.sharedProvider {
            return requestBody(for: shared, system: system, messages: messages)
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
            // 520 is a safety ceiling, not the length lever — the compact
            // reply contract governs length.
            "max_tokens": 520,
            "system": system,
            "messages": msgs
        ]
    }

    private func requestBody(
        for provider: AIProvider,
        system: String,
        messages: [CoachMessage]
    ) -> [String: Any] {
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
                // 520 is a safety ceiling, not the length lever — the compact
                // reply contract governs length.
                "max_tokens": 520,
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
                    // gemini-2.5-flash is a thinking model: reasoning
                    // tokens otherwise share — and eat — the output
                    // budget, guillotining the visible reply mid-word.
                    // thinkingBudget 0 spends the whole budget on text.
                    "thinkingConfig": ["thinkingBudget": 0],
                    // 520 = safety ceiling; the compact system-prompt
                    // contract is what keeps replies tight.
                    "maxOutputTokens": 520
                ]
            ]
        case .none:
            return [:]
        }
    }

    // MARK: - Response parsing

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
