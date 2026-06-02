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

/// Outcome of a chat turn — either a hydrated reply or a typed failure
/// the store maps to per-cause copy.
enum ChatOutcome {
    case reply(String)
    case failure(ChatFailure)
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

    /// Send a turn to the model. Returns `.reply(text)` on success or
    /// `.failure(cause)` on any failure. The store maps the cause to
    /// per-failure copy so the user always sees an accurate notice
    /// instead of a generic "couldn't reach my model" string that
    /// misdirected locale-blocked users to a useless settings page.
    func reply(
        history: [CoachMessage],
        systemPrompt: String,
        userContext: String
    ) async -> ChatOutcome {
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider)
        else {
            return .failure(.noProvider)
        }

        // M13: AI surfaces are English-only. Surface a locale-specific
        // notice rather than the generic provider-config message.
        guard await activeLocaleSupportsAI() else {
            return .failure(.localeUnsupported)
        }

        // Compose the system prompt — voice + context block.
        let composedSystem = systemPrompt + "\n\n" + userContext

        // Trim replay to the cap, keeping the most recent turns.
        let trimmed = Array(history.suffix(Self.maxReplayMessages))

        do {
            let body = requestBody(for: provider, system: composedSystem, messages: trimmed)
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
                return .failure(.noProvider)
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return .failure(.network)
            }
            if let text = extractText(from: data, provider: provider) {
                return .reply(text)
            }
            return .failure(.empty)
        } catch {
            return .failure(.network)
        }
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
