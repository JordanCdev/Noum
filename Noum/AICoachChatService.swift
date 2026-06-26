import Foundation

// MARK: - AI Coach Chat Service
//
// Multi-turn coaching chat — the model behind the "Ask Noum" surface.
// Reuses the same provider plumbing (OpenAI / DeepSeek / Gemini) as the
// rest of the AI layer; the difference is that this service is *stateful
// per request* (it replays the conversation history every turn) and
// always-text (no JSON response shape; the coach is supposed to write
// like a coach, not emit data).
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
//   • Truncation-honest — `extractText` reads the provider finish reason
//     (Gemini `finishReason`, OpenAI/DeepSeek `finish_reason`). A
//     length-truncated completion (MAX_TOKENS / "length") is treated as
//     `.empty` so the user sees the honest "try rephrasing" notice
//     instead of a sentence that stops dead. Never commit a guillotined
//     reply verbatim.
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
    /// Request succeeded but the provider returned an empty / unparseable
    /// completion. Distinct from `.network` because retrying the same
    /// prompt won't help — rephrasing might.
    case empty
}

/// Outcome of a chat turn — a live model reply, a *deterministic* offline
/// reply, or a typed failure the store maps to per-cause copy.
enum ChatOutcome {
    /// A live, model-generated reply.
    case reply(String)
    /// A deterministic, grounded, in-voice coach reply assembled locally
    /// when the model is unreachable (`.network` / `.noProvider`) or the
    /// locale is unsupported (`.localeUnsupported`). A real coach always
    /// responds, so these failure paths hand back a useful association-only
    /// line instead of an error notice. Kept DISTINCT from `.reply` so the
    /// spoken path stays silent (TTS needs the same network/provider that is
    /// down) while the store still renders it as a real coach bubble — never
    /// a system notice. Mirrors `AICoachService.deterministicFeedback` /
    /// `PostRepCoachNoteService.deterministicNote`.
    case deterministicReply(String)
    case failure(ChatFailure)
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

    init(
        voice: SpeakingStyleGoal? = nil,
        recentTimedTranscript: String? = nil,
        recentTimedPrompt: String? = nil,
        recentWordsPerMinute: Int = 0,
        recentFillerCount: Int = 0,
        hypothesis: String? = nil,
        observableTarget: String? = nil,
        successMeasure: String? = nil,
        nextQuestion: String? = nil
    ) {
        self.voice = voice
        self.recentTimedTranscript = recentTimedTranscript
        self.recentTimedPrompt = recentTimedPrompt
        self.recentWordsPerMinute = recentWordsPerMinute
        self.recentFillerCount = recentFillerCount
        self.hypothesis = hypothesis
        self.observableTarget = observableTarget
        self.successMeasure = successMeasure
        self.nextQuestion = nextQuestion
    }
}

/// Pure inputs the `retrieve_expertise` tool uses to boost on-case retrieval
/// when the agentic coach calls it. Assembled by `CoachReplyPipeline` from owners
/// already in scope (active lever + chosen voice). No I/O, no singletons.
struct CoachToolContext: Equatable, Sendable {
    var lever: SkillArea?
    var voice: SpeakingStyleGoal?
    var hasDiagnosis: Bool

    init(lever: SkillArea? = nil, voice: SpeakingStyleGoal? = nil, hasDiagnosis: Bool = false) {
        self.lever = lever
        self.voice = voice
        self.hasDiagnosis = hasDiagnosis
    }
}

/// One step of the Gemini agentic loop: the model either requested a tool call,
/// produced a final text answer, or returned something unusable (truncated /
/// empty / unparseable) — in which case the caller falls back to single-shot.
enum GeminiAgenticStep {
    case call(name: String, args: [String: Any], modelContent: [String: Any])
    case text(String)
    case unusable
}

@available(iOS 17.0, macOS 12.0, *)
actor AICoachChatService {

    static let shared = AICoachChatService()

    /// Cap on the number of chat messages we replay to the model per
    /// request. The user context block carries the long-arc summary,
    /// so older messages don't need to be sent — they'd inflate
    /// tokens without adding signal.
    private static let maxReplayMessages = 24

    private init() {}

    /// Send a turn to the model. Returns `.reply(text)` on a live success,
    /// `.deterministicReply(text)` when the model is unreachable / the locale
    /// is unsupported (a real coach always answers — see `ChatFallbackContext`),
    /// or `.failure(cause)` on the one path where a canned line could mask a
    /// real bug (`.empty`: the model WAS reached but returned nothing parseable
    /// or was length-truncated — the user gets the honest "try rephrasing"
    /// notice instead of substituted text). Total function — never throws.
    ///
    /// `fallback` is the LAST, defaulted parameter (arg-order rule) so the
    /// single existing call site can opt in without reordering; with the
    /// default empty context the deterministic reply degrades to an in-voice,
    /// fabrication-free line.
    func reply(
        history: [CoachMessage],
        systemPrompt: String,
        userContext: String,
        fallback: ChatFallbackContext = ChatFallbackContext(),
        // AGENTIC — when true (text chat only; the live call leaves it false for
        // latency) AND the provider is Gemini, the coach may call the
        // `retrieve_expertise` tool on demand before answering. Any failure in
        // the loop falls through to the single-shot path below, so worst case is
        // today's behavior. `toolContext` carries the lever/voice the tool boosts
        // retrieval with. Defaulted so existing callers are unchanged.
        allowAgentic: Bool = false,
        toolContext: CoachToolContext = CoachToolContext()
    ) async -> ChatOutcome {
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider)
        else {
            // No provider configured — the model can't be reached at all.
            // A real coach still answers, so hand back a grounded, in-voice
            // deterministic line rather than an error notice.
            return .deterministicReply(Self.deterministicReply(failure: .noProvider, context: fallback))
        }

        // M13: AI surfaces are English-only. The deterministic fallback is
        // locale-agnostic English copy (layer-wide precedent), so a non-English
        // user still gets a useful coach line rather than a config notice.
        guard await activeLocaleSupportsAI() else {
            return .deterministicReply(Self.deterministicReply(failure: .localeUnsupported, context: fallback))
        }

        // Compose the system prompt — voice + context block.
        let composedSystem = systemPrompt + "\n\n" + userContext

        // Trim replay to the cap, keeping the most recent turns.
        let trimmed = Array(history.suffix(Self.maxReplayMessages))
        let latestUserTurn = trimmed.last(where: { $0.role == .user })?.text

        // AGENTIC PATH (text chat + Gemini + flag). The coach can call
        // `retrieve_expertise` on demand. Returns nil on ANY problem (network,
        // parse, unknown tool, gate fail, round budget) so we drop to the
        // single-shot path below — which carries the SAME grounded context, so
        // the fallback reply is still expertise-grounded. Never worse than today.
        if allowAgentic, provider == .gemini, KnowledgeBrainFlags.agenticToolCallingEnabled {
            if let outcome = await geminiAgenticReply(
                composedSystem: composedSystem,
                history: trimmed,
                latestUserTurn: latestUserTurn,
                endpoint: endpoint,
                key: key,
                toolContext: toolContext
            ) {
                return outcome
            }
            // else: fall through to the single-shot path.
        }

        do {
            let body = requestBody(for: provider, system: composedSystem, messages: trimmed)
            guard let data = try await providerResponseData(
                provider: provider,
                endpoint: endpoint,
                key: key,
                body: body
            ) else {
                // Transport reached the server but it refused — treat as a
                // network failure and answer deterministically (a coach who
                // can't reach their notes still gives a useful read).
                return .deterministicReply(Self.deterministicReply(failure: .network, context: fallback))
            }
            if let text = extractText(from: data, provider: provider) {
                if let issue = Self.replyQualityIssue(in: text, latestUserTurn: latestUserTurn) {
                    if let repaired = await repairLowQualityReply(
                        issue: issue,
                        draft: text,
                        provider: provider,
                        endpoint: endpoint,
                        key: key,
                        system: composedSystem,
                        messages: trimmed
                    ) {
                        return .reply(repaired)
                    }
                    return .deterministicReply(Self.deterministicReply(failure: .empty, context: fallback))
                }
                return .reply(text)
            }
            // The model WAS reached but returned nothing parseable / was
            // length-truncated. Keep the honest `.empty` notice — substituting
            // a canned line here could mask a real truncation bug.
            return .failure(.empty)
        } catch {
            // Transport / encode failure — the model is unreachable. Answer
            // deterministically instead of dead-ending the user.
            return .deterministicReply(Self.deterministicReply(failure: .network, context: fallback))
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
        latestUserTurn: String?
    ) -> CoachChatReplyQualityIssue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
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
        if containsAny(lower, [
            "last rep", "recent rep", "next rep", "session", "transcript",
            "filler", "pace", "pause", "score", "wpm", "word choice",
            "you said", "you asked", "i heard", "what i notice", "pattern",
            "case", "hypothesis", "target", "success measure", "not enough data",
            "i don't have", "i do not have", "i can't see", "from what you wrote",
            "your message", "your words", "the friction"
        ]) {
            return true
        }
        // Soft anchors a senior coach actually uses: a grounded reference to a
        // moment in time PLUS a specific second-person action ("earlier you
        // rushed the open", "the moment you hesitated before the question").
        // These are genuinely anchored even without a hard keyword/digit, so
        // requiring BOTH a temporal marker and a second-person action keeps the
        // gate from false-rejecting real coaching. Only ADMITS replies — never
        // newly rejects — so it's safe on the shared live-call path.
        let hasTemporal = containsAny(lower, [
            "this week", "yesterday", "last time", "earlier", "just now",
            "a moment ago", "that last", "in your last", "the moment you",
            "when you opened", "when you closed"
        ])
        let hasSecondPersonAction = containsAny(lower, [
            "you rushed", "you raced", "you opened", "you closed", "you hesitated",
            "you paused", "you held", "you led", "you buried", "you slowed",
            "you landed", "you showed", "you trailed", "you softened", "you sped",
            "you stalled", "you jumped"
        ])
        return hasTemporal && hasSecondPersonAction
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
        provider: AIProvider,
        endpoint: URL,
        key: String,
        system: String,
        messages: [CoachMessage]
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

        let body = requestBody(for: provider, system: repairSystem, messages: messages)
        guard
            let data = try? await providerResponseData(
                provider: provider,
                endpoint: endpoint,
                key: key,
                body: body
            ),
            let text = extractText(from: data, provider: provider),
            Self.replyQualityIssue(in: text, latestUserTurn: messages.last(where: { $0.role == .user })?.text) == nil
        else { return nil }

        return text
    }

    // MARK: - Agentic tool-calling loop (Gemini, text chat only)
    //
    // The coach can call `retrieve_expertise` on demand — model-driven retrieval
    // on top of the pre-retrieved context. Bounded rounds, and ANY failure
    // returns nil so the caller drops to the single-shot path (which carries the
    // same grounded context). Voice call stays single-shot (latency); only the
    // text chat passes `allowAgentic`.

    static let agenticToolName = "retrieve_expertise"
    static let agenticMaxRounds = 3

    /// Run the Gemini function-calling loop. Returns a finished `ChatOutcome` on
    /// success, or nil to signal "fall back to single-shot".
    private func geminiAgenticReply(
        composedSystem: String,
        history: [CoachMessage],
        latestUserTurn: String?,
        endpoint: URL,
        key: String,
        toolContext: CoachToolContext
    ) async -> ChatOutcome? {
        var contents = Self.geminiContents(from: history)
        let tools: [[String: Any]] = [["functionDeclarations": [Self.expertiseToolDeclaration()]]]
        let toolConfig: [String: Any] = ["functionCallingConfig": ["mode": "AUTO"]]

        for _ in 0..<Self.agenticMaxRounds {
            let body: [String: Any] = [
                "systemInstruction": ["parts": [["text": composedSystem]]],
                "contents": contents,
                "tools": tools,
                "toolConfig": toolConfig,
                "generationConfig": [
                    "temperature": 0.6,
                    "thinkingConfig": ["thinkingBudget": 0],
                    "maxOutputTokens": 800
                ]
            ]

            let data: Data?
            do {
                data = try await providerResponseData(
                    provider: .gemini, endpoint: endpoint, key: key, body: body
                )
            } catch {
                return nil
            }
            guard let data,
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { return nil }

            switch Self.parseGeminiStep(from: object) {
            case .text(let text):
                // Same quality gate + single repair pass as the non-agentic path.
                if let issue = Self.replyQualityIssue(in: text, latestUserTurn: latestUserTurn) {
                    if let repaired = await repairLowQualityReply(
                        issue: issue, draft: text, provider: .gemini,
                        endpoint: endpoint, key: key, system: composedSystem, messages: history
                    ) {
                        return .reply(repaired)
                    }
                    return nil
                }
                return .reply(text)

            case .call(let name, let args, let modelContent):
                guard name == Self.agenticToolName, let query = args["query"] as? String else {
                    return nil
                }
                // Re-append the model's functionCall turn verbatim (role "model"),
                // then the tool RESULT as a role:"user" functionResponse part —
                // the exact two-turn shape Gemini requires. (Gemini uses "user"
                // for the function result, NOT "function"/"tool" — that would
                // break the call.)
                contents.append(modelContent)
                let response = Self.executeExpertiseTool(query: query, context: toolContext)
                contents.append([
                    "role": "user",
                    "parts": [["functionResponse": ["name": name, "response": response]]]
                ])

            case .unusable:
                return nil
            }
        }
        return nil
    }

    /// The one tool the coach can call: a JSON-schema function declaration for
    /// on-demand expertise retrieval. Pure + nonisolated for tests.
    nonisolated static func expertiseToolDeclaration() -> [String: Any] {
        [
            "name": agenticToolName,
            "description": "Look up Noum's curated communication-coaching technique cards relevant to a topic (fillers, pacing, structure, openings, closings, composure under pressure, interviews, presentations, difficult conversations, leadership, networking, social). Call this when the user asks how to improve something, or when you want a grounded, named technique to prescribe. Returns each technique's name, why it works, how to apply it, and the observable sign it is working.",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "What to find a technique for, in plain words — e.g. 'stop saying um', 'open a presentation', 'calm interview nerves', 'sound more concise'."
                    ]
                ],
                "required": ["query"]
            ]
        ]
    }

    /// Execute `retrieve_expertise`: the model explicitly asked, so bypass the
    /// cold-start gate (`hasDiagnosis: true`) and return the cards as a JSON
    /// object (Gemini requires `functionResponse.response` to be an object).
    nonisolated static func executeExpertiseTool(
        query: String,
        context: CoachToolContext
    ) -> [String: Any] {
        let cards = KnowledgeRetriever.retrieve(
            query: query,
            lever: context.lever,
            voice: context.voice,
            hasDiagnosis: true,
            limit: 4
        )
        guard !cards.isEmpty else {
            return [
                "techniques": [[String: Any]](),
                "note": "No specific technique card matched. Coach from the user's own data instead."
            ]
        }
        let techniques: [[String: Any]] = cards.map { card in
            [
                "technique": card.title,
                "why": card.why,
                "apply": card.howToApply,
                "successMarker": card.successMarker,
                "evidence": card.evidenceTier.rawValue
            ]
        }
        return ["techniques": techniques]
    }

    /// Map chat history to Gemini `contents`. Skips empty/UI-only turns so a
    /// trailing empty pending-coach row can't end the contents on a model turn.
    nonisolated static func geminiContents(from messages: [CoachMessage]) -> [[String: Any]] {
        var contents: [[String: Any]] = []
        for m in messages {
            let role: String
            switch m.role {
            case .user: role = "user"
            case .coach: role = "model"
            case .systemNotice: continue
            }
            guard !m.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            contents.append(["role": role, "parts": [["text": m.text]]])
        }
        return contents
    }

    /// Classify a Gemini response: a tool request, a final text answer, or
    /// unusable (truncated/empty/unparseable). Iterates `parts` and matches on
    /// the `functionCall` key — never assumes position 0 (thinking/tool models
    /// interleave parts). Pure + nonisolated for tests.
    nonisolated static func parseGeminiStep(from object: [String: Any]) -> GeminiAgenticStep {
        guard let candidates = object["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else { return .unusable }

        for part in parts {
            if let call = part["functionCall"] as? [String: Any],
               let name = call["name"] as? String {
                let args = (call["args"] as? [String: Any]) ?? [:]
                return .call(name: name, args: args, modelContent: content)
            }
        }

        if isLengthTruncated(responseObject: object, provider: .gemini) {
            return .unusable
        }
        let text = parts
            .compactMap { $0["text"] as? String }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .unusable : .text(text)
    }

    // MARK: - Deterministic offline fallback
    //
    // A real coach always responds. When the model is unreachable
    // (`.network` / `.noProvider`) or the locale is unsupported
    // (`.localeUnsupported`), this assembles a grounded, in-voice coach line
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

    /// The single body sentence. Priority:
    /// 1. Substance verdict over the most-recent timed rep, when above floor.
    /// 2. A delivery FACT (pace / fillers) when present but the verdict is below
    ///    floor — never a substance claim.
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
        if context.recentWordsPerMinute > 170 {
            return "On your last timed rep the pace ran fast at \(context.recentWordsPerMinute) WPM, so add a beat between points and each one gets room to land."
        }
        if context.recentWordsPerMinute > 0 && context.recentWordsPerMinute < 95 {
            return "On your last timed rep the pace ran slow at \(context.recentWordsPerMinute) WPM, so lift the energy a touch and the line carries."
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
    private func currentProvider() -> AIProvider? {
        AISettingsManager.shared.activeProvider
    }

    @MainActor
    private func activeLocaleSupportsAI() -> Bool {
        LocaleSettingsManager.shared.current.aiSupported
    }

    private func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }

    // MARK: - Request body construction

    private func providerResponseData(
        provider: AIProvider,
        endpoint: URL,
        key: String,
        body: [String: Any]
    ) async throws -> Data? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 18
        switch provider {
        case .openAI, .deepSeek:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .gemini:
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        case .none:
            return nil
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return nil
        }
        return data
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

    private func extractText(from data: Data, provider: AIProvider) -> String? {
        switch provider {
        case .openAI, .deepSeek:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }
            // Truncation-honest: a completion the provider stopped for
            // length is a guillotined sentence. Treat it as empty so the
            // store shows "try rephrasing" rather than a dead-stop reply.
            if Self.isLengthTruncated(responseObject: object, provider: provider) {
                return nil
            }
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .gemini:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return nil }
            if Self.isLengthTruncated(responseObject: object, provider: provider) {
                return nil
            }
            let joined = parts
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        case .none:
            return nil
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
