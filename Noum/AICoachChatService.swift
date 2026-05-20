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
//   • Token-conservative — temperature 0.6, max_tokens ~ 350 so a
//     single response stays compact and never floods the chat.
//   • Failure-soft — empty / failed completions return nil and the
//     store renders a "couldn't reach my model" notice instead. We
//     never fabricate a coach reply on error.

@available(iOS 17.0, macOS 12.0, *)
actor AICoachChatService {

    static let shared = AICoachChatService()

    /// Cap on the number of chat messages we replay to the model per
    /// request. The user context block carries the long-arc summary,
    /// so older messages don't need to be sent — they'd inflate
    /// tokens without adding signal.
    private static let maxReplayMessages = 24

    private init() {}

    /// Send a turn to the model. Returns the coach's reply text on
    /// success, or nil on any failure (no provider, network error,
    /// empty completion). Callers should hydrate the store's pending
    /// coach row regardless — the store renders a system notice for
    /// nil replies.
    func reply(
        history: [CoachMessage],
        systemPrompt: String,
        userContext: String
    ) async -> String? {
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider)
        else {
            return nil
        }

        // M13: AI surfaces are English-only. Non-English locales get
        // the "no reply" path — the store falls back to a notice.
        guard await activeLocaleSupportsAI() else {
            return nil
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
                return nil
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return extractText(from: data, provider: provider)
        } catch {
            return nil
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
                "max_tokens": 380,
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
                    "maxOutputTokens": 380
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
            let joined = parts
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        case .none:
            return nil
        }
    }
}
