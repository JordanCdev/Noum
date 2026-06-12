import Foundation
import os

// MARK: - AI Coach Chat Service
//
// Multi-turn coaching chat — the model behind the "Ask Noum" surface.
// Speaks a CHAIN of providers (Gemini → Anthropic → OpenAI → DeepSeek,
// whichever have keys) with per-provider cooldowns, so a rate-limited or
// refusing provider fails over to the next instead of silently degrading
// every turn to the deterministic fallback. The rest of the AI layer
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
//   • Token-bounded — temperature 0.6, output cap 800. The system
//     prompt brevity contract (2-4 sentences) is what actually keeps
//     replies tight; the cap is a safety ceiling, not the length lever.
//     History: a 350 cap silently truncated. The default provider is a
//     *thinking* model (gemini-2.5-flash) whose budget is shared between
//     invisible reasoning tokens and visible text, so terse/ambiguous
//     early questions triggered heavy reasoning that ate the 350 budget
//     and guillotined the visible answer mid-word ("…guide you through
//     the app'"). Fix: Gemini reasoning is disabled (thinkingConfig
//     thinkingBudget 0) so the whole budget is visible text, and the cap
//     is 800 (headroom over the 2-4 sentence contract, matching the
//     never-truncating PostRepCoachNoteService which sets no cap).
//   • Truncation-honest — response extraction reads the provider finish
//     reason (Gemini `finishReason`, OpenAI/DeepSeek `finish_reason`). A
//     length-truncated completion (MAX_TOKENS / "length") stays an honest
//     `.empty` notice instead of a sentence that stops dead. Other
//     no-text responses use the grounded deterministic fallback rather than
//     dead-ending the chat. Never commit a guillotined reply verbatim.
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
    /// A reply could not be safely committed: the provider returned a
    /// length-truncated completion, or a deterministic substitute failed its
    /// own quality gate. Distinct from `.network` because rephrasing might help.
    case empty
}

/// Outcome of a chat turn — a live model reply, a *deterministic* offline
/// reply, or a typed failure the store maps to per-cause copy.
enum ChatOutcome {
    /// A live, model-generated reply.
    case reply(String)
    /// A deterministic, grounded, in-voice coach reply assembled locally
    /// when the model is unreachable (`.network` / `.noProvider`), the
    /// locale is unsupported (`.localeUnsupported`), or a successful provider
    /// response contains no usable non-truncated text (`.empty`). A real coach
    /// always responds, so these failure paths hand back a useful
    /// association-only line instead of an error notice. Kept DISTINCT from
    /// `.reply` so the spoken path stays silent (TTS needs the same
    /// network/provider that is down) while the store still renders it as a
    /// real coach bubble — never a system notice. Mirrors
    /// `AICoachService.deterministicFeedback` /
    /// `PostRepCoachNoteService.deterministicNote`.
    case deterministicReply(String)
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
    case unanchoredCoaching
    case overclaimsEvidence
    case unverifiedQuotedUserSpeech
    case unengagedUserSpeechClaim

    var repairInstruction: String {
        switch self {
        case .tooLong:
            return "The draft is too long for text-mode coaching. Rewrite it as 1-2 short sentences."
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
        // reading real user words — without these sources Gate 1 rejected
        // every such reply into the same deterministic fallback (owner bug
        // report 2026-06-10: "chat says the same thing over and over").
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

/// Decode-free, transient context the deterministic chat fallback reads to
/// ground its reply. Assembled at the call site (`AskNoumView.runReply`) from
/// owners already in scope — the user's chosen voice, the most-recent timed
/// rep, and the already-summarized standing case (hypothesis / observable
/// target / success measure / next question) off `CoachCaseFile`. Pure data;
/// no I/O, no singletons, nothing persisted (so no Codable surface). Every
/// field is optional and defaulted so the call site can pass exactly what it
/// has and the builder degrades gracefully (no fabrication below a floor).
struct ChatFallbackContext: Equatable {
    /// The user's CHOSEN training voice (nil until they pick one). Selects
    /// the `CoachPersona` register so the offline line speaks in-voice.
    var voice: SpeakingStyleGoal?
    /// The most-recent TIMED rep's transcript, when one exists. Drives the
    /// SHARED `PracticeEvaluator.promptAnswerVerdict`; nil → no substance
    /// verdict (delivery-fact-only). Never quoted directly (no fabrication).
    var recentTimedTranscript: String?
    /// The prompt the most-recent timed rep answered, when known. Paired
    /// with `recentTimedTranscript` for the positional verdict.
    var recentTimedPrompt: String?
    /// Whole-words-per-minute on that rep (0 when unknown) — a delivery fact
    /// the fallback may state when the substance verdict is below its floor.
    var recentWordsPerMinute: Int
    /// Whole-word COUNT on that rep (0 when unknown). The delivery-fact branch
    /// is gated on this clearing the SAME evidence floor `PracticeEvaluator`'s
    /// own pace label uses (`>= 6` words). A degenerate near-empty rep
    /// (e.g. 1 word over a full duration) yields a nonsensical "pace ran slow
    /// at 1 WPM" line otherwise — the chat fallback must refuse to judge pace
    /// on too little content, exactly as `paceSnapshot` does.
    var recentTimedWordCount: Int
    /// Filler-word COUNT on that rep (not a rate) — a delivery fact only.
    var recentFillerCount: Int
    /// The standing working hypothesis, already bounded/summarized on the
    /// case file. Folded in association-only framing — never as a diagnosis.
    var hypothesis: String?
    /// The active intervention's observable target, already summarized.
    var observableTarget: String?
    /// The active intervention's success measure, already summarized.
    var successMeasure: String?
    /// The case file's next coaching question, already phrased. Used to
    /// advance the case when there is no recent rep to read.
    var nextQuestion: String?
    /// Quotes that have already passed the proof-moment guard elsewhere.
    /// The live chat may quote these back; anything else needs to appear in a
    /// transcript or the user's latest turn.
    var verifiedProofQuotes: [String]

    init(
        voice: SpeakingStyleGoal? = nil,
        recentTimedTranscript: String? = nil,
        recentTimedPrompt: String? = nil,
        recentWordsPerMinute: Int = 0,
        recentTimedWordCount: Int = 0,
        recentFillerCount: Int = 0,
        hypothesis: String? = nil,
        observableTarget: String? = nil,
        successMeasure: String? = nil,
        nextQuestion: String? = nil,
        verifiedProofQuotes: [String] = []
    ) {
        self.voice = voice
        self.recentTimedTranscript = recentTimedTranscript
        self.recentTimedPrompt = recentTimedPrompt
        self.recentWordsPerMinute = recentWordsPerMinute
        self.recentTimedWordCount = recentTimedWordCount
        self.recentFillerCount = recentFillerCount
        self.hypothesis = hypothesis
        self.observableTarget = observableTarget
        self.successMeasure = successMeasure
        self.nextQuestion = nextQuestion
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
        // Haiku: the chat contract is 2-4 sentences in a fixed voice —
        // fast + cheap fits; the system prompt carries the intelligence.
        case .anthropic: return "claude-haiku-4-5"
        case .gemini, .openAI, .deepSeek: return sharedProvider?.model ?? ""
        }
    }

    var endpoint: URL? {
        switch self {
        case .anthropic: return URL(string: "https://api.anthropic.com/v1/messages")
        case .gemini, .openAI, .deepSeek: return sharedProvider?.endpoint
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

    /// Send a turn to the model. Returns `.reply(text)` on a live success,
    /// `.deterministicReply(text)` when the model is unreachable, the locale is
    /// unsupported, or the provider returns no usable non-truncated text (a real
    /// coach always answers — see `ChatFallbackContext`), or `.failure(cause)`
    /// when a reply would be unsafe to commit (`.empty`: length-truncated or the
    /// deterministic substitute itself failed the quality gate). Total function
    /// — never throws.
    ///
    /// `fallback` is the LAST, defaulted parameter (arg-order rule) so the
    /// single existing call site can opt in without reordering; with the
    /// default empty context the deterministic reply degrades to an in-voice,
    /// fabrication-free line.
    func reply(
        history: [CoachMessage],
        systemPrompt: String,
        userContext: String,
        fallback: ChatFallbackContext = ChatFallbackContext()
    ) async -> ChatOutcome {
        // The previous coach bubble — the repeat-guard input. A provider
        // outage must never present as the coach saying the same line twice.
        let previousCoachText = history.last(where: { $0.role == .coach })?.text

        // M13: AI surfaces are English-only. The deterministic fallback is
        // locale-agnostic English copy (layer-wide precedent), so a non-English
        // user still gets a useful coach line rather than a config notice.
        guard await activeLocaleSupportsAI() else {
            return Self.deterministicReplyOutcome(failure: .localeUnsupported, context: fallback, previousCoachText: previousCoachText)
        }

        let keyed = Self.keyedProviders()
        guard !keyed.isEmpty else {
            // No provider has a key — the model can't be reached at all.
            // A real coach still answers, so hand back a grounded, in-voice
            // deterministic line rather than an error notice.
            Self.log.error("no chat provider has a key — deterministic fallback")
            return Self.deterministicReplyOutcome(failure: .noProvider, context: fallback, previousCoachText: previousCoachText)
        }

        // Compose the system prompt — voice + context block.
        let composedSystem = systemPrompt + "\n\n" + userContext

        // Trim replay to the cap, keeping the most recent turns.
        let trimmed = Array(history.suffix(Self.maxReplayMessages))
        let latestUserTurn = trimmed.last(where: { $0.role == .user })?.text
        let quoteGuard = CoachChatQuoteGuardContext(
            transcripts: [fallback.recentTimedTranscript],
            verifiedProofQuotes: fallback.verifiedProofQuotes,
            latestUserTurn: latestUserTurn,
            recentUserTurns: trimmed.filter { $0.role == .user }.map(\.text)
        )

        let chain = Self.orderedChain(keyed: keyed, cooldowns: providerCooldowns, now: Date())
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
                if refusal.cooldown > 0 {
                    providerCooldowns[provider] = Date().addingTimeInterval(refusal.cooldown)
                }
                continue
            }
        }

        // Every keyed provider refused this turn — answer deterministically
        // instead of dead-ending the user (a coach who can't reach their
        // notes still gives a useful read).
        Self.log.error("all \(chain.count) chat providers refused — deterministic fallback")
        return Self.deterministicReplyOutcome(
            failure: .network,
            context: fallback,
            latestUserTurn: latestUserTurn,
            previousCoachText: previousCoachText
        )
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
    /// try its best option rather than silently going deterministic.
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
                        Self.log.notice("\(provider.displayName, privacy: .public) reply tripped quality gate — repairing")
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
           Self.claimsUserSpeechRead(in: trimmed),
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
        let maxCharacters = expandedAnswer ? 560 : 380
        let maxSentences = expandedAnswer ? 5 : 2
        if trimmed.count > maxCharacters || sentenceCount(in: trimmed) > maxSentences {
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
        let maxCharacters = expandedAnswer ? 560 : 360
        let maxSentences = expandedAnswer ? 5 : 2
        if trimmed.count > maxCharacters || sentenceCount(in: trimmed) > maxSentences {
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

        if replyOverclaimsEvidence(lower) {
            apply(.overclaimsEvidence, penalty: 3)
        }

        return CoachChatProfessionalRubricResult(
            score: max(0, min(10, score)),
            misses: misses
        )
    }

    private nonisolated static let roboticPhrases = [
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

    /// Attribution phrases that claim a read of the user's actual words.
    /// Shared by both halves of the dual gate: Gate 2 verifies any QUOTED
    /// fragment that follows one of these; Gate 1 requires the reply to
    /// engage a known source even when nothing is quoted.
    private nonisolated static let userSpeechAttributionPhrases = [
        "you said", "you used", "your words", "your phrase",
        "you put it", "your line", "you opened with", "your opening line",
        "you closed with", "your closing line", "you mentioned",
        "you talked about", "you described", "you argued",
        "your exact words", "your phrasing", "your wording"
    ]

    /// True when the text claims to read the user's actual words (as opposed
    /// to citing a metric or prescribing a move). Pure + lexical, exposed for
    /// tests alongside the dual gate it scopes.
    nonisolated static func claimsUserSpeechRead(in text: String) -> Bool {
        containsAny(text.lowercased(), userSpeechAttributionPhrases)
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
            "'([^']{3,180})'",
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

    private nonisolated static func sentenceCount(in text: String) -> Int {
        let endings = CharacterSet(charactersIn: ".!?")
        let count = text.unicodeScalars.reduce(0) { partial, scalar in
            partial + (endings.contains(scalar) ? 1 : 0)
        }
        return max(count, text.isEmpty ? 0 : 1)
    }

    private nonisolated static func wordCount(in text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber }.count
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
        - 1-2 short sentences.
        - No headers, bullets, or numbered lists.
        - No broad menu. Pick one coaching move.
        - If the user showed frustration, do not defend the app.
        - Sound like a senior communications coach, not an assistant explaining itself.
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
            case .text(let text) = Self.chatExtractReplyText(from: data, provider: provider),
            Self.replyQualityIssue(
                in: text,
                latestUserTurn: messages.last(where: { $0.role == .user })?.text,
                quoteGuard: quoteGuard
            ) == nil
        else { return nil }

        return text
    }

    // MARK: - Deterministic offline fallback
    //
    // A real coach always responds. When the model is unreachable
    // (`.network` / `.noProvider`), the locale is unsupported
    // (`.localeUnsupported`), or the provider returns no usable non-truncated
    // text (`.empty`), this assembles a grounded, in-voice coach line
    // from the same rich context the LLM gets — the chosen voice's persona,
    // the SHARED prompt-answer verdict over the most-recent timed rep, and the
    // standing case (hypothesis / target / success measure). It mirrors
    // `AICoachService.deterministicFeedback` and
    // `PostRepCoachNoteService.deterministicNote`:
    //
    //   • Pure + `nonisolated` + total — unit-testable, never throws/empties.
    //   • Honors evidence floors — `promptAnswerVerdict == nil` (thin / absent
    //     rep) yields a delivery-fact-only line, NEVER a substance claim; with
    //     no recent rep at all it advances the standing case in association-only
    //     framing instead of inventing a read.
    //   • Never fabricates a quote — it states the verdict and delivery facts,
    //     and folds the already-summarized case in; it never reproduces the
    //     transcript text.
    //   • Locale-agnostic English copy (the deterministic path is shared by the
    //     non-English locale-block per layer-wide precedent).
    //   • Brand-safe by construction — run through `ensureNoExclamations` /
    //     `collapseWhitespace` / `truncate` (reused from
    //     `PostRepCoachNoteService`), bounded to the brand-voice length ceiling.

    /// Build the deterministic, in-voice coach reply for a handled failure
    /// cause. The `failure` parameter is accepted for symmetry / future
    /// per-cause shaping but the COPY is intentionally cause-agnostic: the user
    /// shouldn't be able to tell whether the model was offline, unconfigured,
    /// or locale-blocked — they just get a useful coach line. Pure + total.
    nonisolated static func deterministicReply(
        failure: ChatFailure,
        context: ChatFallbackContext
    ) -> String {
        _ = failure // cause-agnostic copy today; kept for per-cause shaping later
        let persona = CoachPersona.persona(for: context.voice)
        let lead = persona.reflectionLead

        // The grounded body: the SHARED substance verdict above its floor,
        // else a delivery fact, else a case-advancing line, else a steady
        // in-voice fallback. Exactly one body sentence — coach voice rule #1.
        let body = bodySentence(context: context, persona: persona)

        // The standing case, folded in association-only framing. Suppressed
        // when there is no durable case (no hypothesis / target / measure /
        // next question) so the line never gestures at a plan that isn't there.
        let caseLine = standingCaseLine(context: context, persona: persona)

        var text = caseLine.isEmpty ? "\(lead) \(body)" : "\(lead) \(body) \(caseLine)"
        text = PostRepCoachNoteService.collapseWhitespace(in: text)
        text = PostRepCoachNoteService.ensureNoExclamations(in: text)
        // Bounded to the brand-voice ceiling so the rendered bubble stays tight
        // and `passesBrandVoiceContract` holds (it rejects > 220 chars).
        text = PostRepCoachNoteService.truncate(text, max: 220)
        return text
    }

    /// Build a deterministic fallback line AND hold it to the same quality bar
    /// the live path enforces (`replyQualityIssue`). The deterministic builder
    /// emits controlled, in-voice copy that should always clear the bar, so this
    /// is a safety net rather than a routine rejection: if a future copy change
    /// ever produced a robotic / over-long / bare line, the user gets the honest
    /// `.empty` "try rephrasing" notice instead of a sub-bar substitute. This
    /// keeps the offline path under the SAME contract as the live path — there is
    /// no second, looser quality standard for when the model is unreachable.
    ///
    /// The deterministic builder never quotes raw user speech (it composes from
    /// the shared verdict / delivery facts / standing-case copy), so no quote
    /// guard is threaded; the turn-aware lexical checks are what matter here.
    nonisolated static func deterministicReplyOutcome(
        failure: ChatFailure,
        context: ChatFallbackContext,
        latestUserTurn: String? = nil,
        previousCoachText: String? = nil
    ) -> ChatOutcome {
        var candidate = deterministicReply(failure: failure, context: context)
        // Repeat-guard: the deterministic line is a pure function of the
        // fallback context, which rarely changes between turns — so a
        // provider outage would otherwise present as the coach saying the
        // SAME line on every turn. Never send the previous bubble verbatim.
        if let previous = normalizedFallbackText(previousCoachText),
           normalizedFallbackText(candidate) == previous {
            candidate = alternateDeterministicReply(context: context, avoidingNormalized: previous)
        }
        guard let issue = replyQualityIssue(in: candidate, latestUserTurn: latestUserTurn) else {
            return .deterministicReply(candidate)
        }
        switch issue {
        case .unanchoredCoaching, .missingPrescribedAction:
            // Turn-contextual checks, NOT objective quality failures. When the
            // model is unreachable AND there is no rep/case yet, the controlled
            // builder's honest "run one more rep, I'll read it when I'm back"
            // line genuinely cannot anchor to data that does not exist — that is
            // the correct cold coach response, so these do not block the offline
            // path (the live path, with real data + a real turn, still enforces
            // them on model output).
            return .deterministicReply(candidate)
        case .tooLong, .roboticPhrase, .bareClarification, .defensiveProductLanguage,
             .menuInsteadOfDecision, .missedTrustRepair, .overclaimsEvidence,
             .unverifiedQuotedUserSpeech, .unengagedUserSpeechClaim:
            // Objective failures the deterministic builder must never produce on
            // ANY path. If a future copy change ever did, the user gets the
            // honest `.empty` notice instead of a sub-bar substitute.
            return .failure(.empty)
        }
    }

    /// Second-choice fallback when the primary deterministic line would repeat
    /// the previous coach bubble verbatim. Composes lead + steady line
    /// (skipping the verdict/case body the primary used); if even that matches
    /// the previous bubble, falls to a neutral honest line. Every candidate is
    /// held to the same whitespace/exclamation/length contract as the primary.
    nonisolated static func alternateDeterministicReply(
        context: ChatFallbackContext,
        avoidingNormalized previous: String
    ) -> String {
        let persona = CoachPersona.persona(for: context.voice)
        let candidates = [
            "\(persona.reflectionLead) \(steadyFallback(persona: persona))",
            "Still working without my full read here. Your reps are saved — run another and I'll compare them properly the moment the connection is back."
        ]
        var last = candidates[candidates.count - 1]
        for raw in candidates {
            var text = PostRepCoachNoteService.collapseWhitespace(in: raw)
            text = PostRepCoachNoteService.ensureNoExclamations(in: text)
            text = PostRepCoachNoteService.truncate(text, max: 220)
            last = text
            if normalizedFallbackText(text) != previous { return text }
        }
        return last
    }

    /// Case/whitespace-insensitive comparison key for the repeat-guard.
    nonisolated static func normalizedFallbackText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    /// Evidence floor for stating a pace FACT in the offline fallback. Mirrors
    /// the `wordCount >= 6` floor `PracticeEvaluator.paceSnapshot` uses to refuse
    /// a pace label — below it the pace number is meaningless (1 word / 60s
    /// rounds to 1 WPM), so the chat fallback must not assert one.
    nonisolated static let minWordsForPaceFact = 6

    /// A believable conversational-speech band. Even when the word-count floor
    /// is met, a WPM outside human speaking range (a sensor glitch, a clipped
    /// duration) must never be stated as a fact. The window is deliberately wide
    /// — it only rejects values that are physically implausible for connected
    /// speech, leaving the slow/fast COACHING bands (`< 95`, `> 170`) intact.
    nonisolated static func isSanePaceFact(_ wpm: Int) -> Bool {
        (40...260).contains(wpm)
    }

    /// The single body sentence. Priority:
    /// 1. Substance verdict over the most-recent timed rep, when above floor.
    /// 2. A delivery FACT (pace / fillers) when present but the verdict is below
    ///    floor — never a substance claim, and never a pace number below the
    ///    word-count floor or outside a believable speaking range.
    /// 3. A case-advancing reflection when there's no rep to read.
    /// 4. A steady in-voice fallback that asserts nothing it cannot support.
    private nonisolated static func bodySentence(
        context: ChatFallbackContext,
        persona: CoachPersona
    ) -> String {
        // 1) Substance verdict — only above the shared evidence floor.
        if let transcript = context.recentTimedTranscript,
           !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let read = PracticeEvaluator.promptRelevance(
                prompt: context.recentTimedPrompt?.isEmpty == false ? context.recentTimedPrompt : nil,
                transcript: transcript
            )
            if let verdict = PracticeEvaluator.promptAnswerVerdict(for: read) {
                return verdictSentence(verdict)
            }
            // Below the substance floor — fall through to a delivery fact.
        }

        // 2) Delivery fact (no substance claim). Pace band first, then fillers.
        //
        // GATE: only judge pace when the rep cleared the SAME evidence floor
        // `PracticeEvaluator.paceSnapshot` uses to refuse a pace label
        // (`wordCount >= 6`). A degenerate near-empty rep (1 word over a full
        // minute → round(1.0) = 1 WPM) would otherwise emit "pace ran slow at
        // 1 WPM" — a nonsensical number stated with false confidence. Below the
        // floor the pace is simply unknown, so we omit the number entirely and
        // fall through to the filler fact / case line / steady fallback. A
        // 0-valued `recentTimedWordCount` (unknown rep length) is treated as
        // below-floor for the same reason.
        let paceJudgeable = context.recentTimedWordCount >= Self.minWordsForPaceFact
            && Self.isSanePaceFact(context.recentWordsPerMinute)
        if paceJudgeable {
            if context.recentWordsPerMinute > 170 {
                return "On your last timed rep the pace ran fast at \(context.recentWordsPerMinute) WPM, so add a beat between points and each one gets room to land."
            }
            if context.recentWordsPerMinute < 95 {
                return "On your last timed rep the pace ran slow at \(context.recentWordsPerMinute) WPM, so lift the energy a touch and the line carries."
            }
        }
        if context.recentFillerCount >= 4 {
            return "Fillers crept into your last timed rep, so try a deliberate pause where one wants to go — silence reads as composure."
        }

        // 3) No rep to read — advance the standing case if we have one. (Copy
        // deliberately avoids "let's", which the brand-voice contract rejects.)
        if let next = bounded(context.nextQuestion) {
            return "I don't have a fresh rep in front of me, so the open thread is still the one to pull on: \(lowerFirst(next))"
        }
        if bounded(context.hypothesis) != nil {
            return "I don't have a fresh rep in front of me, but the working read still stands."
        }

        // 4) Steady in-voice fallback — asserts nothing it cannot support.
        return steadyFallback(persona: persona)
    }

    /// Per-verdict body, mirroring the shared positional language used by
    /// `AICoachService.deterministicFeedback` / the AI rubric so every surface
    /// agrees. Association on the rep's own words only — never a confident
    /// off-topic claim.
    private nonisolated static func verdictSentence(_ verdict: PracticeEvaluator.PromptAnswerVerdict) -> String {
        switch verdict {
        case .answered:
            return "Your last timed rep led with the point — the answer was right up front, so the work now is closing as cleanly as you opened."
        case .partial:
            return "On your last timed rep the question's key terms didn't clearly lead, so make your main point the first sentence and spend the rest supporting it."
        case .buried:
            return "Your last timed rep had the answer in it, but it arrived late — lead with the point in the first sentence, then build the case behind it."
        }
    }

    /// The standing case folded into one association-only line. Order:
    /// success measure (the most concrete target) > observable target >
    /// hypothesis. Empty when there is no durable case so nothing is invented.
    private nonisolated static func standingCaseLine(
        context: ChatFallbackContext,
        persona: CoachPersona
    ) -> String {
        if let measure = bounded(context.successMeasure) {
            return "That ties to where we're aiming: \(lowerFirst(measure))."
        }
        if let target = bounded(context.observableTarget) {
            return "Keep it pointed at the target we set: \(lowerFirst(target))."
        }
        if let hypothesis = bounded(context.hypothesis) {
            return "It fits the read we're carrying: \(lowerFirst(hypothesis))."
        }
        return ""
    }

    /// A steady, in-voice fallback line when there is neither a rep nor a case
    /// to ground against. Asserts nothing about the user's last rep.
    private nonisolated static func steadyFallback(persona: CoachPersona) -> String {
        switch persona.voice {
        case .concise:
            return "Pick one idea, make it the first sentence of your next rep, and cut the rest."
        case .storytelling:
            return "Run one more rep and give me the arc — open on the point, then carry it through."
        case .authoritative, .executive, .persuasive:
            return "Run one more rep with a single clear point up front, and I'll read it the moment I'm back online."
        case .warm, .none:
            return "Run one more rep when you're ready — lead with your point, and I'll read it the moment I'm back online."
        }
    }

    // MARK: - Small string helpers (deterministic fallback)

    /// Trim + non-empty guard, returning nil for absent/blank input so the
    /// builder never folds in an empty fragment. Mirrors the `bounded(_:)`
    /// idiom used by `CoachCaseFile`.
    private nonisolated static func bounded(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Lowercase only the first character so a summarized fragment reads
    /// naturally mid-sentence ("Hold under 4%…" → "hold under 4%…"). Leaves
    /// the rest untouched so acronyms / numbers are preserved. Pure.
    private nonisolated static func lowerFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
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
        request.timeoutInterval = 18
        switch provider {
        case .openAI, .deepSeek:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .gemini:
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
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
            // 800 is a safety ceiling, not the length lever — the
            // system-prompt brevity contract (2-4 sentences) governs length.
            "max_tokens": 800,
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
                // 800 is a safety ceiling, not the length lever — the
                // system-prompt brevity contract (2-4 sentences) governs
                // length. A lower cap silently clipped replies mid-word.
                "max_tokens": 800,
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
                    // 800 = safety ceiling; the 2-4 sentence system-prompt
                    // contract is what keeps replies tight.
                    "maxOutputTokens": 800
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

    /// Maps no-text extraction states into user-visible outcomes. A successful
    /// provider response with no usable text gets the grounded deterministic
    /// coach bubble; a length-truncated response remains an honest notice.
    static func outcomeForMissingExtractedReply(
        _ extraction: ChatExtractionResult,
        context: ChatFallbackContext,
        latestUserTurn: String? = nil
    ) -> ChatOutcome? {
        switch extraction {
        case .text:
            return nil
        case .empty:
            return deterministicReplyOutcome(failure: .empty, context: context, latestUserTurn: latestUserTurn)
        case .lengthTruncated:
            return .failure(.empty)
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
