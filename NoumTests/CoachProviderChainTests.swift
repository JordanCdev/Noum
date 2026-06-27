//
//  CoachProviderChainTests.swift
//  NoumTests
//
//  Contracts behind the coach-chat provider failover: chain ordering with
//  cooldowns, refusal classification, and the Anthropic request/extract branch.
//

import Foundation
import Testing
@testable import Noum

// MARK: - Provider identity

struct CoachChatProviderTests {

    @Test func agentPlatformProviderShape() {
        let provider = CoachChatProvider.agentPlatform
        #expect(provider.displayName == "Google Cloud")
        #expect(provider.keyName == "GOOGLE_AGENT_PLATFORM_API_KEY")
        #expect(provider.keyNames.contains("GOOGLE_CLOUD_AGENT_PLATFORM_API_KEY"))
        #expect(provider.sharedProvider == .gemini)

        let endpoint = CoachChatProvider.agentPlatformEndpoint(model: "gemini-3.5-flash")
        #expect(endpoint?.absoluteString == "https://aiplatform.googleapis.com/v1/publishers/google/models/gemini-3.5-flash:generateContent")
    }

    @Test func agentPlatformEndpointAcceptsFullPublisherModelPath() {
        let endpoint = CoachChatProvider.agentPlatformEndpoint(model: "publishers/google/models/gemini-3.5-flash")

        #expect(endpoint?.absoluteString == "https://aiplatform.googleapis.com/v1/publishers/google/models/gemini-3.5-flash:generateContent")
    }

    @Test func googleAPIKeyHelperCarriesBundleRestrictionHeader() throws {
        let bundleID = try #require(Bundle.main.bundleIdentifier)
        var request = URLRequest(url: URL(string: "https://example.com")!)

        request.setGoogleAPIKey("test-google-key")

        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "test-google-key")
        #expect(request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") == bundleID)
    }

    @Test func anthropicProviderShape() {
        let provider = CoachChatProvider.anthropic
        let expectedModel = LocalConfigLoader.value(forKey: "ANTHROPIC_CHAT_MODEL", plistNamed: "AIConfig")
            ?? LocalConfigLoader.value(forKey: "ANTHROPIC_MODEL", plistNamed: "AIConfig")
            ?? "claude-sonnet-4-6"
        #expect(provider.model == expectedModel)
        #expect(provider.endpoint?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(provider.keyName == "ANTHROPIC_API_KEY")
        #expect(provider.sharedProvider == nil)
    }

    @Test func sharedProvidersMapToExistingPlumbing() {
        #expect(CoachChatProvider.agentPlatform.sharedProvider == .gemini)
        #expect(CoachChatProvider.gemini.sharedProvider == .gemini)
        #expect(CoachChatProvider.openAI.sharedProvider == .openAI)
        #expect(CoachChatProvider.deepSeek.sharedProvider == .deepSeek)
        // Gemini chat model = plist override when present, else the shared
        // default — and the endpoint must embed whichever model resolved
        // (Gemini carries the model in the URL path, not the body).
        let expectedModel = LocalConfigLoader.value(forKey: "GEMINI_CHAT_MODEL", plistNamed: "AIConfig")
            ?? AIProvider.gemini.model
        #expect(CoachChatProvider.gemini.model == expectedModel)
        #expect(CoachChatProvider.gemini.endpoint?.absoluteString
            == "https://generativelanguage.googleapis.com/v1beta/models/\(expectedModel):generateContent")
    }

    @Test func preferenceOrderIsDeclarationOrder() {
        #expect(CoachChatProvider.allCases.first == .agentPlatform)
        #expect(CoachChatProvider.allCases.dropFirst().first == .gemini)
        #expect(CoachChatProvider.allCases.contains(.anthropic))
    }

    @Test func configurationSummaryRedactsKeysWithoutRequiringAgentProject() {
        let summary = CoachChatProvider.configurationSummary(
            providers: [.agentPlatform, .gemini, .anthropic],
            env: [
                "GOOGLE_CLOUD_AGENT_PLATFORM_API_KEY": "agent-secret",
                "GEMINI_API_KEY": "gemini-secret"
            ],
            localValue: { _ in nil }
        )

        #expect(summary.contains("Google Cloud: key present"))
        #expect(summary.contains("Gemini: key present"))
        #expect(summary.contains("Claude: missing key"))
        #expect(!summary.contains("agent-secret"))
        #expect(!summary.contains("gemini-secret"))
    }

    @Test func configurationSummaryAcceptsAgentKeyWithoutProjectAlias() {
        let summary = CoachChatProvider.configurationSummary(
            providers: [.agentPlatform],
            env: ["GOOGLE_AGENT_PLATFORM_API_KEY": "agent-secret"],
            localValue: { _ in nil }
        )

        #expect(summary == "Google Cloud: key present")
        #expect(!summary.contains("agent-secret"))
    }
}

// MARK: - Chain ordering + refusal classification

struct CoachProviderChainTests {

    @Test func keyedProvidersReadsEnvironment() {
        let env = [
            "ANTHROPIC_API_KEY": "sk-test",
            "GOOGLE_CLOUD_AGENT_PLATFORM_API_KEY": "agent-test",
            "GEMINI_API_KEY": ""
        ]
        let keyed = AICoachChatService.keyedProviders(env: env)
        #expect(keyed.contains(.agentPlatform))
        #expect(keyed.contains(.anthropic))
        // Empty env value doesn't count as a key by itself (the local plist
        // may still supply one on a dev machine, so only assert presence
        // semantics for the explicitly-keyed provider).
    }

    @Test func placeholderKeysAreNotTreatedAsConfigured() {
        #expect(AICoachChatService.usableAPIKey(nil) == nil)
        #expect(AICoachChatService.usableAPIKey("") == nil)
        #expect(AICoachChatService.usableAPIKey("  REPLACE_ME  ") == nil)
        #expect(AICoachChatService.usableAPIKey("<paste key here>") == nil)
        #expect(AICoachChatService.usableAPIKey("sk-live-test") == "sk-live-test")
    }

    @Test func diagnosticSnapshotRedactsKeys() async {
        let service = AICoachChatService(
            keyedProviders: { [.gemini] },
            keyLookup: { provider in provider == .gemini ? "super-secret-gemini-key" : nil },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in .refused(status: 500, retryAfter: nil) }
        )

        let snapshot = await service.diagnosticSnapshot()
        let gemini = snapshot.first { $0.provider == .gemini }

        #expect(gemini?.displayName == "Gemini")
        #expect(gemini?.hasUsableKey == true)
        #expect(gemini?.endpointHost == "generativelanguage.googleapis.com")
        #expect(!String(describing: snapshot).contains("super-secret-gemini-key"))
    }

    @Test func coolingProvidersMoveToTheBackNotOut() {
        let now = Date()
        let chain = AICoachChatService.orderedChain(
            keyed: [.gemini, .anthropic],
            cooldowns: [.gemini: now.addingTimeInterval(30)],
            now: now
        )
        #expect(chain == [.anthropic, .gemini], "a cooling provider is retried last, never dropped")
    }

    @Test func expiredCooldownRestoresPreferenceOrder() {
        let now = Date()
        let chain = AICoachChatService.orderedChain(
            keyed: [.gemini, .anthropic],
            cooldowns: [.gemini: now.addingTimeInterval(-1)],
            now: now
        )
        #expect(chain == [.gemini, .anthropic])
    }

    @Test func allCoolingStillTriesEveryone() {
        let now = Date()
        let chain = AICoachChatService.orderedChain(
            keyed: [.gemini, .anthropic],
            cooldowns: [.gemini: now.addingTimeInterval(60), .anthropic: now.addingTimeInterval(60)],
            now: now
        )
        #expect(chain.count == 2, "when everything is cooling the chain must still run")
    }

    @Test func refusalClassification() {
        #expect(CoachChatProviderRefusal.classify(status: 429) == .rateLimited)
        #expect(CoachChatProviderRefusal.classify(status: 401) == .authBlocked)
        #expect(CoachChatProviderRefusal.classify(status: 403) == .authBlocked)
        #expect(CoachChatProviderRefusal.classify(status: 500) == .transient)
        #expect(CoachChatProviderRefusal.classify(status: 529) == .transient)
        #expect(CoachChatProviderRefusal.contentRejected.cooldown == 0,
                "a content miss must not bench the provider")
        #expect(CoachChatProviderRefusal.authBlocked.cooldown > CoachChatProviderRefusal.rateLimited.cooldown,
                "a dead key cools longer than a quota window")
    }

    @Test func acceptedReplyWritesPersistentDiagnostic() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let userTurn = "Give me one move for the next rep."
        let acceptedReply = "Your message asks for one move, so keep the test narrow. In the next rep, answer first, give one proof point, then stop. That tests whether structure holds when the timer is tight."
        #expect(AICoachChatService.replyQualityIssue(in: acceptedReply, latestUserTurn: userTurn) == nil)

        let service = AICoachChatService(
            keyedProviders: { [.openAI] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in
                .success(Self.openAIData(acceptedReply))
            },
            diagnosticRecorder: { surface, providerName, model, outcome, reason, statusCode, startedAt, now in
                diagnostics.record(
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
        )

        let outcome = await service.reply(
            history: [
                CoachMessage(role: .user, text: userTurn)
            ],
            systemPrompt: "You are Noum.",
            userContext: "No recent sessions."
        )

        guard case .reply = outcome else {
            Issue.record("Expected live reply, got \(outcome)")
            return
        }

        let acceptedRecord = diagnostics.records.first { record in
            record.surface == "Ask Noum chat" &&
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            record.reason == "Reply accepted"
        }
        #expect(acceptedRecord?.model == CoachChatProvider.openAI.model)
    }

    @Test func agentPlatformGeminiReplyUsesThinkingDisabledFlashPath() async throws {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let bodyProbe = CoachBodyProbe()
        let userTurn = "Give me one move for the next rep."
        let acceptedReply = "Your message asks for one move, so keep the test narrow. Next rep, answer first and stop after one proof point. That tests whether pressure is making you over-explain."
        #expect(AICoachChatService.replyQualityIssue(in: acceptedReply, latestUserTurn: userTurn) == nil)

        let service = AICoachChatService(
            keyedProviders: { [.agentPlatform] },
            keyLookup: { _ in "test-google-key" },
            localeSupportsAI: { true },
            providerHTTP: { provider, endpoint, _, body in
                bodyProbe.capture(provider: provider, endpoint: endpoint, body: body)
                return .success(Self.geminiData(acceptedReply))
            },
            diagnosticRecorder: { surface, providerName, model, outcome, reason, statusCode, startedAt, now in
                diagnostics.record(
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
        )

        let outcome = await service.reply(
            history: [
                CoachMessage(role: .user, text: userTurn)
            ],
            systemPrompt: "You are Noum.",
            userContext: "RATING\n- Total rated sessions: 12."
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected Gemini-backed reply, got \(outcome)")
            return
        }

        #expect(text == acceptedReply)
        let captured = try #require(bodyProbe.captured)
        #expect(captured.provider == .agentPlatform)
        #expect(captured.endpointHost == "aiplatform.googleapis.com")
        #expect(captured.thinkingBudget == 0)
        #expect(captured.maxOutputTokens == 180)

        #expect(diagnostics.records.contains { record in
            record.surface == "Ask Noum chat" &&
            record.provider == "Google Cloud" &&
            record.model == CoachChatProvider.agentPlatform.model &&
            record.outcome == .success &&
            record.reason == "Reply accepted"
        })
    }

    @Test func contentRejectedCritiqueResolvesAsNoticeNotLocalCoachReply() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData("I understand your frustration. Here are some tips to communicate more clearly: be concise.")),
            .success(Self.openAIData("Can you clarify what you mean?"))
        ])
        let service = AICoachChatService(
            keyedProviders: { [.openAI] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { provider, endpoint, key, body in
                await scripted.next(provider: provider, endpoint: endpoint, key: key, body: body)
            },
            diagnosticRecorder: { surface, providerName, model, outcome, reason, statusCode, startedAt, now in
                diagnostics.record(
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
        )

        let outcome = await service.reply(
            history: [
                CoachMessage(role: .user, text: "Why can’t you shape a useful answer?")
            ],
            systemPrompt: "You are Noum.",
            userContext: "No recent sessions."
        )

        guard case .failure(.contentRejected) = outcome else {
            Issue.record("Expected content-rejected notice outcome, got \(outcome)")
            return
        }

        #expect(await scripted.callCount == 2)
        #expect(diagnostics.records.contains { record in
            record.surface == "Ask Noum chat" &&
            record.outcome == .failure &&
            record.reason == "All chat providers failed quality gate"
        })
        #expect(!diagnostics.records.contains { record in
            record.reason.localizedCaseInsensitiveContains("trust-repair fallback")
        })
    }

    @Test func refusedGoogleCloudFallsThroughToClaudeReply() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let acceptedReply = "I don't have a rated rep yet, so use the first answer as the baseline. Run one 45-second interview answer, then mark every um and hold one silent beat before sentence two."
        #expect(AICoachChatService.replyQualityIssue(
            in: acceptedReply,
            latestUserTurn: "How do I stop saying um under pressure?"
        ) == nil)

        let scripted = ScriptedCoachHTTP(results: [
            .refused(status: 429, retryAfter: nil),
            .success(Self.anthropicData(acceptedReply))
        ])
        let service = AICoachChatService(
            keyedProviders: { [.agentPlatform, .anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { provider, endpoint, key, body in
                await scripted.next(provider: provider, endpoint: endpoint, key: key, body: body)
            },
            diagnosticRecorder: { surface, providerName, model, outcome, reason, statusCode, startedAt, now in
                diagnostics.record(
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
        )

        let outcome = await service.reply(
            history: [
                CoachMessage(role: .user, text: "How do I stop saying um under pressure?")
            ],
            systemPrompt: "You are Noum.",
            userContext: "No recent sessions."
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected Claude fallback reply, got \(outcome)")
            return
        }

        #expect(text == acceptedReply)
        #expect(await scripted.providers == [.agentPlatform, .anthropic])
        #expect(diagnostics.records.contains { record in
            record.provider == "Google Cloud" &&
            record.outcome == .fallback &&
            record.statusCode == 429
        })
        #expect(diagnostics.records.contains { record in
            record.provider == "Claude" &&
            record.model == CoachChatProvider.anthropic.model &&
            record.outcome == .success &&
            record.reason == "Reply accepted"
        })
    }

    private static func openAIData(_ content: String) -> Data {
        let payload: [String: Any] = [
            "choices": [
                [
                    "message": ["content": content],
                    "finish_reason": "stop"
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    private static func geminiData(_ content: String) -> Data {
        let payload: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [["text": content]]
                    ],
                    "finishReason": "STOP"
                ]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    private static func anthropicData(_ content: String) -> Data {
        let payload: [String: Any] = [
            "content": [
                [
                    "type": "text",
                    "text": content
                ]
            ],
            "stop_reason": "end_turn"
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}

private actor ScriptedCoachHTTP {
    private var results: [AICoachChatService.ProviderHTTPResult]
    private(set) var callCount: Int = 0
    private(set) var providers: [CoachChatProvider] = []

    init(results: [AICoachChatService.ProviderHTTPResult]) {
        self.results = results
    }

    func next(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any]
    ) -> AICoachChatService.ProviderHTTPResult {
        callCount += 1
        providers.append(provider)
        guard !results.isEmpty else {
            return .refused(status: 500, retryAfter: nil)
        }
        return results.removeFirst()
    }
}

private final class CoachBodyProbe: @unchecked Sendable {
    struct Captured {
        let provider: CoachChatProvider
        let endpointHost: String?
        let thinkingBudget: Int?
        let maxOutputTokens: Int?
    }

    private let lock = NSLock()
    private var storedCaptured: Captured?

    var captured: Captured? {
        lock.lock()
        defer { lock.unlock() }
        return storedCaptured
    }

    func capture(provider: CoachChatProvider, endpoint: URL, body: [String: Any]) {
        let generationConfig = body["generationConfig"] as? [String: Any]
        let thinkingConfig = generationConfig?["thinkingConfig"] as? [String: Any]
        let next = Captured(
            provider: provider,
            endpointHost: endpoint.host,
            thinkingBudget: thinkingConfig?["thinkingBudget"] as? Int,
            maxOutputTokens: generationConfig?["maxOutputTokens"] as? Int
        )
        lock.lock()
        storedCaptured = next
        lock.unlock()
    }
}

private final class CoachDiagnosticRecorderProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRecords: [AICallDiagnosticRecord] = []

    var records: [AICallDiagnosticRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storedRecords
    }

    func record(
        surface: String,
        providerName: String?,
        model: String?,
        outcome: AICallDiagnosticOutcome,
        reason: String,
        statusCode: Int?,
        startedAt: Date?,
        now: Date
    ) {
        let latencyMs = startedAt.map { max(0, Int(now.timeIntervalSince($0) * 1_000)) }
        let record = AICallDiagnosticRecord.make(
            createdAt: now,
            surface: surface,
            provider: providerName,
            model: model,
            outcome: outcome,
            reason: reason,
            statusCode: statusCode,
            latencyMs: latencyMs
        )
        lock.lock()
        storedRecords.append(record)
        lock.unlock()
    }
}

// MARK: - Anthropic extraction

struct AnthropicExtractionTests {

    private func data(_ json: String) -> Data { Data(json.utf8) }

    @Test func extractsTextBlocks() {
        let payload = data("""
        {"content":[{"type":"text","text":"Lead with the point."}],"stop_reason":"end_turn"}
        """)
        let result = AICoachChatService.extractAnthropicReplyText(from: payload)
        #expect(result == .text("Lead with the point."))
    }

    @Test func truncatedReplyIsNeverCommitted() {
        let payload = data("""
        {"content":[{"type":"text","text":"This reply stops dead mid"}],"stop_reason":"max_tokens"}
        """)
        #expect(AICoachChatService.extractAnthropicReplyText(from: payload) == .lengthTruncated)
    }

    @Test func emptyContentIsEmpty() {
        let payload = data("""
        {"content":[],"stop_reason":"end_turn"}
        """)
        #expect(AICoachChatService.extractAnthropicReplyText(from: payload) == .empty)
    }

    @Test func malformedPayloadIsEmpty() {
        #expect(AICoachChatService.extractAnthropicReplyText(from: data("not json")) == .empty)
    }

    @Test func chatExtractRoutesSharedProvidersThroughExistingPath() {
        // OpenAI-shaped payload extracted via the chat wrapper for .openAI.
        let payload = data("""
        {"choices":[{"message":{"content":"Hold the pause."},"finish_reason":"stop"}]}
        """)
        let viaWrapper = AICoachChatService.chatExtractReplyText(from: payload, provider: .openAI)
        let direct = AICoachChatService.extractReplyText(from: payload, provider: .openAI)
        #expect(viaWrapper == direct)
    }

    @Test func chatExtractRoutesAgentPlatformThroughGeminiPath() {
        let payload = data("""
        {"candidates":[{"content":{"parts":[{"text":"NOUM_AI_OK"}]},"finishReason":"STOP"}]}
        """)

        let viaAgent = AICoachChatService.chatExtractReplyText(from: payload, provider: .agentPlatform)
        let direct = AICoachChatService.extractReplyText(from: payload, provider: .gemini)
        #expect(viaAgent == direct)
    }

    @Test func chatHealthRequestForAnthropicUsesTinySentinelPrompt() throws {
        let body = try AICoachChatService.healthRequestBody(for: .anthropic)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(object["model"] as? String == CoachChatProvider.anthropic.model)
        #expect(object["temperature"] as? Int == 0)
        #expect(object["max_tokens"] as? Int == 16)

        let system = try #require(object["system"] as? String)
        let messages = try #require(object["messages"] as? [[String: Any]])
        #expect(system.contains("private API health check"))
        #expect(messages.contains { message in
            (message["content"] as? String)?.contains("NOUM_AI_OK") == true
        })
    }

    @Test func chatHealthRequestForGoogleProvidersKeepsThinkingBudgetDisabled() throws {
        for provider in [CoachChatProvider.agentPlatform, .gemini] {
            let body = try AICoachChatService.healthRequestBody(for: provider)
            let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let generationConfig = try #require(object["generationConfig"] as? [String: Any])
            let thinkingConfig = try #require(generationConfig["thinkingConfig"] as? [String: Any])
            let contents = try #require(object["contents"] as? [[String: Any]])

            #expect(generationConfig["temperature"] as? Int == 0)
            #expect(generationConfig["maxOutputTokens"] as? Int == 16)
            #expect(thinkingConfig["thinkingBudget"] as? Int == 0)
            #expect(contents.contains { content in
                let parts = content["parts"] as? [[String: Any]]
                return parts?.contains { ($0["text"] as? String)?.contains("NOUM_AI_OK") == true } == true
            })
        }
    }

    @Test func chatHealthRequestForGeminiKeepsBackwardCompatibleShape() throws {
        let body = try AICoachChatService.healthRequestBody(for: .gemini)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(object["model"] == nil)
        #expect(object["contents"] != nil)
    }

    @Test func chatHealthSentinelParserAcceptsProviderText() throws {
        let payload = data("""
        {"content":[{"type":"text","text":"NOUM_AI_OK"}],"stop_reason":"end_turn"}
        """)

        #expect(AICoachChatService.healthResponseContainsSentinel(payload, provider: .anthropic))
    }

    @Test func chatHTTPFailureReasonUsesSharedProviderErrorStatus() throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "error": [
                "message": "Gemini API has not been used in this project.",
                "status": "PERMISSION_DENIED"
            ]
        ])

        let reason = AICoachChatService.failureReason(
            forHTTPStatus: 403,
            data: payload,
            provider: .gemini
        )

        #expect(reason == "Provider error: PERMISSION_DENIED (API disabled)")
        #expect(!reason.contains("not been used"))
    }

    @Test func chatHTTPFailureReasonRoutesAgentPlatformThroughGoogleErrorParser() throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "error": [
                "message": "Request contains an invalid argument for project secret-project.",
                "status": "INVALID_ARGUMENT"
            ]
        ])

        let reason = AICoachChatService.failureReason(
            forHTTPStatus: 400,
            data: payload,
            provider: .agentPlatform
        )

        #expect(reason == "Provider error: INVALID_ARGUMENT")
        #expect(!reason.contains("secret-project"))
    }

    @Test func chatHTTPFailureReasonNamesAgentPlatformNotFoundWithoutValues() throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "error": [
                "message": "The model projects/private/locations/global/publishers/google/models/private-model was not found.",
                "status": "NOT_FOUND"
            ]
        ])

        let reason = AICoachChatService.failureReason(
            forHTTPStatus: 404,
            data: payload,
            provider: .agentPlatform
        )

        #expect(reason == "Provider error: NOT_FOUND (model or endpoint)")
        #expect(!reason.contains("private-model"))
        #expect(!reason.contains("projects/private"))
    }

    @Test func chatHTTPFailureReasonUsesAnthropicErrorType() throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "type": "error",
            "error": [
                "type": "authentication_error",
                "message": "Invalid API key"
            ]
        ])

        let reason = AICoachChatService.failureReason(
            forHTTPStatus: 401,
            data: payload,
            provider: .anthropic
        )

        #expect(reason == "Provider error: authentication_error")
        #expect(!reason.contains("Invalid API key"))
    }
}
