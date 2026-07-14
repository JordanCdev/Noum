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

    @Test func uiHarnessFlagsAcceptBareMaestroAndEnvironmentShapes() {
        #expect(AICoachChatService.uiHarnessFlagPresent(
            "UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY",
            arguments: ["Noum", "UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY"],
            environment: [:]
        ))
        #expect(AICoachChatService.uiHarnessFlagPresent(
            "UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY",
            arguments: ["Noum", "UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY=true"],
            environment: [:]
        ))
        #expect(AICoachChatService.uiHarnessFlagPresent(
            "UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY",
            arguments: ["Noum"],
            environment: ["UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY": "1"]
        ))
        #expect(!AICoachChatService.uiHarnessFlagPresent(
            "UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY",
            arguments: ["Noum"],
            environment: ["UI_TESTING_CHAT_FORCE_MARKDOWN_REPLY": "false"]
        ))
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
        #expect(CoachChatProviderRefusal.classify(status: 402) == .authBlocked)
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

    @Test func transientProviderTimeoutRetriesOnceBeforeFailover() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let userTurn = "Give me one move for the next rep."
        let acceptedReply = "Your message asks for one move, so keep the test narrow. Next rep, answer first and stop after one proof point. That tests whether pressure is making you over-explain."
        let scripted = TransientThenSuccessCoachHTTP(
            success: .success(Self.geminiData(acceptedReply))
        )
        let service = AICoachChatService(
            keyedProviders: { [.agentPlatform] },
            keyLookup: { _ in "test-google-key" },
            localeSupportsAI: { true },
            providerHTTP: { provider, endpoint, key, body in
                try await scripted.next(
                    provider: provider,
                    endpoint: endpoint,
                    key: key,
                    body: body
                )
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
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: "RATING\n- Total rated sessions: 12."
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected bounded transport retry to recover, got \(outcome)")
            return
        }
        #expect(text == acceptedReply)
        #expect(await scripted.callCount == 2)
        #expect(await scripted.providers == [.agentPlatform, .agentPlatform])
        #expect(diagnostics.records.contains { record in
            record.provider == "Google Cloud" &&
            record.outcome == .fallback &&
            record.reason == "Transient transport failure; retrying once without streaming"
        })
    }

    @Test func transportRetryClassifierExcludesCancellationAndOfflineState() {
        #expect(AICoachChatService.transportFailureCanRetry(URLError(.timedOut)))
        #expect(AICoachChatService.transportFailureCanRetry(URLError(.networkConnectionLost)))
        #expect(!AICoachChatService.transportFailureCanRetry(URLError(.cancelled)))
        #expect(!AICoachChatService.transportFailureCanRetry(URLError(.notConnectedToInternet)))
        #expect(!AICoachChatService.transportFailureCanRetry(
            NSError(domain: "CoachDecode", code: 1)
        ))
    }

    @Test func providerStreamingSkipsTurnsAlreadyCoveredByLocalRead() {
        #expect(!AICoachChatService.providerStreamingShouldRun(
            turnDepth: .trustRepair,
            surface: .text,
            responseMode: .expandable,
            providerStreamingEnabled: true,
            realtimeCoachModeEnabled: true,
            streamRawPartialsToUI: false
        ))
        #expect(!AICoachChatService.providerStreamingShouldRun(
            turnDepth: .quickMove,
            surface: .live,
            responseMode: .immediateOnly,
            providerStreamingEnabled: true,
            realtimeCoachModeEnabled: true,
            streamRawPartialsToUI: false
        ))
        #expect(!AICoachChatService.providerStreamingShouldRun(
            turnDepth: .quickMove,
            surface: .text,
            responseMode: .immediateOnly,
            providerStreamingEnabled: true,
            realtimeCoachModeEnabled: true,
            streamRawPartialsToUI: false
        ))
        #expect(AICoachChatService.providerStreamingShouldRun(
            turnDepth: .quickMove,
            surface: .text,
            responseMode: .immediateOnly,
            providerStreamingEnabled: true,
            realtimeCoachModeEnabled: true,
            streamRawPartialsToUI: true
        ))
        #expect(AICoachChatService.providerStreamingShouldRun(
            turnDepth: .trustRepair,
            surface: .text,
            responseMode: .expandable,
            providerStreamingEnabled: true,
            realtimeCoachModeEnabled: false,
            streamRawPartialsToUI: false
        ))
        #expect(!AICoachChatService.providerStreamingShouldRun(
            turnDepth: .quickMove,
            surface: .text,
            responseMode: .immediateOnly,
            providerStreamingEnabled: false,
            realtimeCoachModeEnabled: true,
            streamRawPartialsToUI: false
        ))
    }

    @Test func qualityMissUsesGateCleanAssessmentBeforeSecondProviderCall() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        var providerEvents: [CoachProviderAttemptEvent] = []
        let turn = "Give me one move for the next rep."
        let weakDraft = "Here are some tips: be confident, be concise, and practice."
        let assessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: turn,
            directVerdict: "The opening is the next lever: put the verdict in sentence one, then prove it once.",
            confidence: 0.34,
            evidenceUsed: ["The useful signal is one recent timed rep gives a usable sample."],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Run one answer with the recommendation first, one proof point, then stop.",
            responseMode: .immediateOnly,
            toneMode: .prescribe,
            repairFocus: nil
        )
        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData(weakDraft))
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
            history: [CoachMessage(role: .user, text: turn)],
            systemPrompt: "You are Noum.",
            userContext: "RECENT (most-recent first)\n- One recent timed rep gives a usable sample.",
            turnDepth: .quickMove,
            assessment: assessment,
            onProviderAttemptEvent: { event in
                providerEvents.append(event)
            }
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected typed assessment repair, got \(outcome)")
            return
        }
        #expect(await scripted.callCount == 1)
        #expect(CoachReplyPipeline.providerRetryCount(providerEvents) == 0)
        #expect(AICoachChatService.replyQualityIssue(
            in: text,
            latestUserTurn: turn,
            systemContext: "RECENT (most-recent first)\n- One recent timed rep gives a usable sample.",
            turnDepth: .quickMove,
            surface: .text
        ) == nil)
        #expect(diagnostics.records.contains { record in
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            [
                "Safe reference repair accepted before provider rewrite",
                "Typed assessment repair accepted before provider rewrite"
            ].contains(record.reason)
        })
    }

    @Test func allowedLandingReadUsesSafeReferenceBeforeSecondProviderCall() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        var providerEvents: [CoachProviderAttemptEvent] = []
        let turn = "Why did that answer land badly?"
        let weakDraft = "Let's focus on the opening. State the decision first, give one reason, then stop."
        let context = "COACH FORMULATION\n- Observable behavior: the recommendation arrived late."
        let assessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: turn,
            directVerdict: "The recommendation arrived late, so order is the next lever.",
            confidence: 0.32,
            evidenceUsed: ["The transcript places the recommendation after the setup."],
            rubricScores: [],
            missingEvidence: [],
            nextProofTest: "Say the decision first, add one reason, then name the implication.",
            responseMode: .immediateOnly,
            toneMode: .prescribe,
            repairFocus: nil
        )
        #expect(AICoachChatService.replyQualityIssue(
            in: weakDraft,
            latestUserTurn: turn,
            systemContext: context,
            turnDepth: .quickMove,
            surface: .text
        ) == .roboticPhrase("let's"))

        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData(weakDraft))
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
            history: [CoachMessage(role: .user, text: turn)],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .quickMove,
            assessment: assessment,
            onProviderAttemptEvent: { event in
                providerEvents.append(event)
            }
        )

        guard case .reply(let reply) = outcome else {
            Issue.record("Expected safe local landing read, got \(outcome)")
            return
        }
        #expect(await scripted.callCount == 1)
        #expect(CoachReplyPipeline.providerRetryCount(providerEvents) == 0)
        #expect(reply.contains("recommendation arrived late"))
        #expect(AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: turn,
            systemContext: context,
            turnDepth: .quickMove,
            surface: .text
        ) == nil)
        #expect(diagnostics.records.contains { record in
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            record.reason == "Safe reference repair accepted before provider rewrite"
        })
    }

    @Test func rejectingPracticeMoreRoutesAsTrustRepair() {
        #expect(TurnDepthClassifier.classify(
            userText: "And stop saying practice more.",
            recentTurns: [CoachMessage(role: .coach, text: "Practice more.")]
        ) == .trustRepair)
    }

    @Test func rejectingPracticeMoreUsesAssessmentSafeRepairBeforeProviderRewrite() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        var providerEvents: [CoachProviderAttemptEvent] = []
        let turn = "And stop saying practice more."
        let weakDraft = "Agreed: that was generic because it named no behavior, so put the recommendation in sentence one, give one proof, then stop."
        let context = "RECENT (most-recent first)\n- One recent timed rep gives a usable sample.\nRECENT USER TURNS\n- The prior answer gave generic advice instead of a coaching read."
        let assessment = CoachAssessment(
            turnDepth: .trustRepair,
            surface: .text,
            questionRestatement: turn,
            directVerdict: "The repair is to name the miss first, then answer with one useful move.",
            confidence: 0.38,
            evidenceUsed: ["trust repair signal: I leaned on generic advice instead of evidence"],
            rubricScores: [],
            missingEvidence: ["A revised answer that earns trust before prescribing."],
            nextProofTest: "Use one user-specific signal first, then prescribe exactly one coach move.",
            responseMode: .expandable,
            toneMode: .repair,
            repairFocus: "I leaned on generic advice instead of evidence"
        )

        #expect(AICoachChatService.replyQualityIssue(
            in: weakDraft,
            latestUserTurn: turn,
            systemContext: context,
            turnDepth: .trustRepair,
            surface: .text
        ) == nil)
        #expect(AICoachChatService.semanticQualityIssue(
            in: weakDraft,
            latestUserTurn: turn,
            systemContext: context,
            turnDepth: .trustRepair,
            assessment: assessment
        ) == .missingRepairInsight)

        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData(weakDraft))
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
                CoachMessage(role: .coach, text: "Fair push. Put the recommendation first and give one proof point."),
                CoachMessage(role: .user, text: turn)
            ],
            systemPrompt: "You are Noum.",
            userContext: context,
            turnDepth: .trustRepair,
            assessment: assessment,
            onProviderAttemptEvent: { event in
                providerEvents.append(event)
            }
        )

        guard case .reply(let reply) = outcome else {
            Issue.record("Expected assessment-safe trust repair, got \(outcome)")
            return
        }
        #expect(await scripted.callCount == 1)
        #expect(CoachReplyPipeline.providerRetryCount(providerEvents) == 0)
        #expect(!reply.lowercased().contains("practice more"))
        #expect(AICoachChatService.semanticQualityIssue(
            in: reply,
            latestUserTurn: turn,
            systemContext: context,
            turnDepth: .trustRepair,
            assessment: assessment
        ) == nil)
        #expect(diagnostics.records.contains { record in
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            record.reason == "Safe reference repair accepted before provider rewrite"
        })
    }

    @Test func transientRepairTransportRetriesOnceBeforeRejectingProvider() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let userTurn = "Give me one move for the next rep."
        let weakDraft = "Here are some tips: be confident, be concise, and practice."
        let repaired = "Your last rep gives one usable signal, so answer in sentence one, give one proof point, then stop."
        #expect(AICoachChatService.replyQualityIssue(
            in: weakDraft,
            latestUserTurn: userTurn
        ) != nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: repaired,
            latestUserTurn: userTurn
        ) == nil)

        let scripted = TransientRepairThenSuccessCoachHTTP(
            first: .success(Self.openAIData(weakDraft)),
            repaired: .success(Self.openAIData(repaired))
        )
        let service = AICoachChatService(
            keyedProviders: { [.openAI] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { provider, endpoint, key, body in
                try await scripted.next(
                    provider: provider,
                    endpoint: endpoint,
                    key: key,
                    body: body
                )
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
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "You are Noum.",
            userContext: "RECENT (most-recent first)\n- One recent rep is available."
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected repair retry to recover, got \(outcome)")
            return
        }
        #expect(text == repaired)
        #expect(await scripted.callCount == 3)
        #expect(diagnostics.records.contains { record in
            record.provider == "OpenAI" &&
            record.outcome == .fallback &&
            record.reason == "Transient repair transport failure; retrying once"
        })
        #expect(diagnostics.records.contains { record in
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            record.reason == "Repair reply accepted"
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

    @Test func repairPromptIncludesExpertReferenceShape() async throws {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let turn = "The ** don't format and TTS reads them out. The responses feel robotic and cold."
        let repaired = "Fair push: TTS reading symbols breaks trust. Your last rep had one filler, so say the recommendation first, give one proof point, then stop."
        #expect(AICoachChatService.replyQualityIssue(
            in: repaired,
            latestUserTurn: turn,
            systemContext: "RECENT (most-recent first)\n- Your last rep had 1 filler."
        ) == nil)
        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData("Fair push. Formatting read aloud breaks trust, so I'll keep the next replies shorter, plain, and warmer.")),
            .success(Self.openAIData(repaired))
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
                CoachMessage(role: .user, text: turn)
            ],
            systemPrompt: "You are Noum.",
            userContext: "RECENT (most-recent first)\n- Your last rep had 1 filler."
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected repaired reply, got \(outcome)")
            return
        }
        #expect(text == repaired)

        let systemMessages = await scripted.systemMessages
        #expect(systemMessages.count == 2)
        let systemMessage = try #require(systemMessages.last)

        #expect(systemMessage.contains("Expert reference shape"))
        #expect(systemMessage.contains("TTS reading symbols breaks trust"))
        #expect(systemMessage.contains("say the recommendation first"))

        #expect(diagnostics.records.contains { record in
            record.surface == "Ask Noum chat" &&
            record.provider == "OpenAI" &&
            record.outcome == .fallback &&
            record.reason.contains("attempting repair") &&
            record.reason.contains("missingPrescribedAction")
        })
        #expect(diagnostics.records.contains { record in
            record.surface == "Ask Noum chat" &&
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            record.reason == "Repair reply accepted"
        })
    }

    @Test func directFollowThroughRepairsPassTheShippingGates() throws {
        let cases: [(turn: String, system: String)] = [
            (
                "What should I do with that filler count?",
                "GLOBAL EXAMPLE\n- A different example had 6 fillers.\nRECENT (most-recent first)\n- Latest qualified filler evidence: 5 fillers in 61 seconds (4.9 per minute).\n- Safe filler fact: filler appeared after the decision/recommendation line."
            ),
            (
                "What should I listen for in the replay?",
                "PERSONALIZATION FLOOR\n- no rated sessions yet\nUPCOMING MOMENT\n- Interview."
            ),
            (
                "How far off am I from sounding authoritative?",
                "RECENT (most-recent first)\n- latest rep: Timed Practice, 7/10, 1 filler, 60s\n- pace estimate: usable\nTRANSCRIPT\n- My recommendation is to keep the launch date."
            ),
            (
                "How do I slow down without sounding unsure?",
                "RECENT (most-recent first)\n- The last rep was clean but compressed."
            ),
            (
                "Do I pause before every sentence?",
                "RECENT (most-recent first)\n- Latest qualified filler evidence: 6 fillers in 64 seconds (5.6 per minute)."
            ),
            (
                "What proves it worked?",
                "RECENT (most-recent first)\n- Test one silent beat before the close on the same 60-second prompt."
            ),
            (
                "I tried the close pause and fillers dropped, but I sounded stiff.",
                "RECENT (most-recent first)\n- The close pause reduced fillers.\nRECENT USER TURNS\n- The user reports that the result sounded stiff."
            ),
            (
                "How do I make that natural tomorrow?",
                "RECENT (most-recent first)\n- The close pause reduced fillers but sounded stiff."
            ),
            (
                "How do I sound more certain at the end?",
                "RECENT (most-recent first)\n- The close softened."
            ),
            (
                "What happened in that rep? It rambled after sentence two.",
                "RECENT USER TURNS\n- The user reports that the answer rambled after sentence two."
            ),
            (
                "What do I take into the interview?",
                "RECENT USER TURNS\n- The last answer drifted after sentence two."
            ),
            (
                "What do I run next?",
                "RECENT (most-recent first)\n- The last recommendation rep had 5 fillers.\nRECENT USER TURNS\n- The decision line came first; the proof is the next boundary to test."
            ),
            (
                "What next?",
                "RECENT (most-recent first)\n- Closing strength lost force in recent reps.\nRECENT USER TURNS\n- The final sentence became a summary instead of the ask."
            ),
            (
                "Why the close instead of the opening?",
                "RECENT (most-recent first)\n- Closing strength lost force in recent reps.\nRECENT USER TURNS\n- The final sentence became a summary instead of the ask."
            ),
            (
                "What is the exact rep?",
                "RECENT (most-recent first)\n- The close is the target.\nRECENT USER TURNS\n- The last sentence should be the ask."
            ),
            (
                "I rewrote the close and it became too direct.",
                "RECENT (most-recent first)\n- The close is the target.\nRECENT USER TURNS\n- Keep the ask without making it abrupt."
            ),
            (
                "What do I do after that rep?",
                "RECENT (most-recent first)\n- The close can become pressure when the ask is too direct."
            ),
            (
                "Do I change the whole answer?",
                "RECENT USER TURNS\n- The decision line is cleaner, but the proof handoff still leaks."
            ),
            (
                "What if the voice still sounds cold?",
                "RECENT USER TURNS\n- The no-symbol version is easier to hear."
            ),
            (
                "The no-symbol version is easier to hear.",
                "RECENT USER TURNS\n- The user says the no-symbol version is easier to hear."
            ),
            (
                "This is robotic and too much writing.",
                "RECENT (most-recent first)\n- The last rep gives one usable opener signal."
            ),
            (
                "What was generic about it?",
                "RECENT (most-recent first)\n- The prior reply named a plan without naming the opener behavior."
            ),
            (
                "So what should you remember next time?",
                "RECENT USER TURNS\n- The prior repair still did not sound like a real coach; the user wanted a sharper read rather than more generic instructions."
            ),
            (
                "Okay, that's cool. However, I don't feel like that answered what I meant.",
                "RECENT (most-recent first)\n- The client answer put reassurance before the recommendation.\nRECENT USER TURNS\n- The polite wording hid stronger friction."
            ),
            (
                "Does that make me sound less warm?",
                "RECENT (most-recent first)\n- The client answer reassured before reaching the recommendation.\nRECENT USER TURNS\n- Put the recommendation first, then use warmth after clarity."
            ),
            (
                "What did you miss?",
                "RECENT (most-recent first)\n- The client answer put reassurance before the recommendation.\nRECENT USER TURNS\n- The polite pushback hid stronger friction."
            ),
            (
                "How do I test that without sounding harsh?",
                "RECENT (most-recent first)\n- The client answer put reassurance before the recommendation.\nRECENT USER TURNS\n- Test order without removing warmth."
            ),
            (
                "I said cool because I was trying not to be rude.",
                "RECENT (most-recent first)\n- The client answer put reassurance before the recommendation.\nRECENT USER TURNS\n- The polite wording hid a stronger no-fit signal."
            ),
            (
                "I tried recommendation first and it sounded abrupt.",
                "RECENT (most-recent first)\n- The client answer reassured before reaching the recommendation.\nRECENT USER TURNS\n- Recommendation first improved order; tone is the next boundary."
            ),
            (
                "And stop saying practice more.",
                "RECENT (most-recent first)\n- One recent timed rep gives a usable sample.\nRECENT USER TURNS\n- The prior answer gave generic advice instead of a coaching read."
            ),
            (
                "So not my whole speaking style yet?",
                "RECENT (most-recent first)\n- No rated sessions yet.\nRECENT USER TURNS\n- The user is creating an interview baseline and checking sentence one first."
            ),
            (
                "Is 7/10 bad?",
                "RECENT (most-recent first)\n- The transcript begins: My recommendation is to keep the launch date.\nVOICE TARGET\n- Authoritative."
            ),
            (
                "What would make you change the diagnosis?",
                "RECENT (most-recent first)\n- One timed rep is useful mechanics evidence, not an authority verdict.\nVOICE TARGET\n- Authoritative under pressure."
            ),
            (
                "I did one pressure rep. It was cleaner but not settled.",
                "RECENT (most-recent first)\n- The authority hypothesis still needs repeated pressure evidence.\nRECENT USER TURNS\n- The user completed one pressure rep."
            ),
            (
                "I tried it and still filled before the proof.",
                "RECENT (most-recent first)\n- The last recommendation rep had 5 fillers.\nRECENT USER TURNS\n- The decision line came first; the proof is the next boundary to test."
            ),
            (
                "What should I look for before I call it progress?",
                "RECENT (most-recent first)\n- The latest pressure rep was cleaner but not settled.\nVOICE TARGET\n- Authoritative."
            ),
            (
                "What test separates those?",
                "RECENT (most-recent first)\n- The recommendation arrived late.\nCOACH FORMULATION\n- Structure is observable; authority remains a hypothesis."
            ),
            (
                "I have a leadership update tomorrow, what should I practice?",
                "RECENT (most-recent first)\n- The latest timed rep had 1 filler and was light on the close.\nUPCOMING MOMENT\n- Leadership update tomorrow."
            ),
            (
                "I do not know the ask yet.",
                "RECENT (most-recent first)\n- The latest timed rep was light on the close.\nUPCOMING MOMENT\n- Leadership update tomorrow; the final sentence should be the ask."
            ),
            (
                "I did the update. People asked for the timeline, not the decision.",
                "RECENT (most-recent first)\n- One recent timed rep gives a usable sample.\nUPCOMING MOMENT\n- Leadership update.\nRECENT USER TURNS\n- The close should land on the decision."
            ),
            (
                "What should I capture now?",
                "RECENT (most-recent first)\n- One recent timed rep gives a usable sample.\nRECENT USER TURNS\n- I did the update. People asked for the timeline, not the decision."
            ),
            (
                "When would you call it authority instead?",
                "RECENT USER TURNS\n- Verdict-first helped, but the user is still unsure."
            ),
            (
                "What should I check after?",
                "UPCOMING MOMENT\n- A leadership update is tomorrow."
            ),
            (
                "How do I know if it worked?",
                "RECENT USER TURNS\n- I tried recommendation first and it sounded abrupt."
            )
        ]

        for testCase in cases {
            let turnDepth: CoachTurnDepth = {
                if testCase.turn.lowercased().contains("stop saying practice") {
                    return .trustRepair
                }
                if testCase.turn == "This is robotic and too much writing." ||
                    testCase.turn.contains("don't feel like that answered") {
                    return .trustRepair
                }
                if testCase.turn.lowercased().contains("how far off") {
                    return .deepAssessment
                }
                return .quickMove
            }()
            let assessment: CoachAssessment? = {
                switch testCase.turn {
                case "How far off am I from sounding authoritative?":
                    return CoachAssessment(
                        turnDepth: .deepAssessment,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "I do not have enough evidence for an overall authoritative communication verdict yet.",
                        confidence: 0.35,
                        evidenceUsed: [
                            "latest rep: Timed Practice, 7/10, 1 fillers, 60s",
                            "pace estimate: 145 WPM"
                        ],
                        rubricScores: [],
                        missingEvidence: [
                            "Need repeated evidence across more than one clean rep before calling the user close overall."
                        ],
                        nextProofTest: "Run one stakes-style pressure proof: verdict first, one reason, clean stop, then compare it with a normal rep.",
                        responseMode: .expandable,
                        toneMode: .explain,
                        repairFocus: nil
                    )
                case "Do I pause before every sentence?",
                     "What proves it worked?",
                     "I tried the close pause and fillers dropped, but I sounded stiff.",
                     "How do I make that natural tomorrow?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "Pacing is the next lever: keep the pause local to the close.",
                        confidence: 0.26,
                        evidenceUsed: ["The recent pressure rep had 6 fillers around the close."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Use the same 60-second prompt and one silent beat before the final sentence.",
                        responseMode: .immediateOnly,
                        toneMode: .prescribe,
                        repairFocus: nil
                    )
                case "What next?",
                     "Why the close instead of the opening?",
                     "What is the exact rep?",
                     "I rewrote the close and it became too direct.",
                     "What do I do after that rep?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The ending is the next lever: make the final sentence the ask or decision, then stop.",
                        confidence: 0.30,
                        evidenceUsed: ["Closing strength lost force in the recent rep."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Use the same topic and make the final sentence the ask, then stop.",
                        responseMode: .immediateOnly,
                        toneMode: .prescribe,
                        repairFocus: nil
                    )
                case "And stop saying practice more.":
                    return CoachAssessment(
                        turnDepth: .trustRepair,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The repair is to name the miss first, then answer with one useful move.",
                        confidence: 0.38,
                        evidenceUsed: ["trust repair signal: I leaned on generic advice instead of evidence"],
                        rubricScores: [],
                        missingEvidence: ["A revised answer that earns trust before prescribing."],
                        nextProofTest: "Use one user-specific signal first, then prescribe exactly one coach move.",
                        responseMode: .expandable,
                        toneMode: .repair,
                        repairFocus: "I leaned on generic advice instead of evidence"
                    )
                case "This is robotic and too much writing.":
                    return CoachAssessment(
                        turnDepth: .trustRepair,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The repair is to name the miss first, then answer with one useful move.",
                        confidence: 0.33,
                        evidenceUsed: ["trust repair signal: I sounded robotic or too much like a report"],
                        rubricScores: [],
                        missingEvidence: ["A shorter behavior-first reply."],
                        nextProofTest: "Use one clean opener in the next rep and stop after the point lands.",
                        responseMode: .expandable,
                        toneMode: .repair,
                        repairFocus: "I sounded robotic or too much like a report"
                    )
                case "Okay, that's cool. However, I don't feel like that answered what I meant.":
                    return CoachAssessment(
                        turnDepth: .trustRepair,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The repair is to answer the friction underneath the polite pushback.",
                        confidence: 0.33,
                        evidenceUsed: ["trust repair signal: I gave generic advice instead of evidence"],
                        rubricScores: [],
                        missingEvidence: ["A behavior-first answer to the user's actual friction."],
                        nextProofTest: "Put the recommendation first, add one reassurance, then stop.",
                        responseMode: .expandable,
                        toneMode: .repair,
                        repairFocus: "I gave generic advice instead of evidence"
                    )
                case "What was generic about it?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The prior reply named a plan without naming the behavior.",
                        confidence: 0.33,
                        evidenceUsed: ["The opener is the behavior worth training."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Run a 45-second rep where sentence one lands before the explanation starts.",
                        responseMode: .immediateOnly,
                        toneMode: .explain,
                        repairFocus: nil
                    )
                case "Does that make me sound less warm?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "Salience is the next lever: add one concrete detail, then return to the ask.",
                        confidence: 0.30,
                        evidenceUsed: ["The recent client answer reassured before reaching the recommendation."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Replay the latest rep with one concrete detail after the verdict, then return to the ask.",
                        responseMode: .immediateOnly,
                        toneMode: .explain,
                        repairFocus: nil
                    )
                case "What did you miss?",
                     "How do I test that without sounding harsh?",
                     "I said cool because I was trying not to be rude.":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The useful read is order: reassurance came before the recommendation.",
                        confidence: 0.30,
                        evidenceUsed: ["The recent client answer reassured before reaching the recommendation."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Run one client concern answer with the recommendation first and one reassurance second.",
                        responseMode: .immediateOnly,
                        toneMode: .explain,
                        repairFocus: nil
                    )
                case "I tried recommendation first and it sounded abrupt.":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "Order improved faster than tone, so change only the bridge after the recommendation.",
                        confidence: 0.30,
                        evidenceUsed: ["The user reports the recommendation-first version sounded abrupt."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Use one reassurance after the recommendation and before the reason.",
                        responseMode: .immediateOnly,
                        toneMode: .prescribe,
                        repairFocus: nil
                    )
                case "So not my whole speaking style yet?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The opening is the next lever: put the verdict in sentence one, then prove it once.",
                        confidence: 0.20,
                        evidenceUsed: ["No rated sessions yet; this is a first interview baseline."],
                        rubricScores: [],
                        missingEvidence: ["Repeated answers across different interview prompts under pressure."],
                        nextProofTest: "Test three different interview prompts, including one under pressure, before widening the claim.",
                        responseMode: .immediateOnly,
                        toneMode: .explain,
                        repairFocus: nil
                    )
                case "Is 7/10 bad?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "Pacing is the next lever: add one deliberate beat before the reason, then judge the same answer.",
                        confidence: 0.36,
                        evidenceUsed: ["One recent timed rep gives a usable mechanics sample."],
                        rubricScores: [],
                        missingEvidence: ["Repeated pressure evidence before calling the authority goal ready."],
                        nextProofTest: "Repeat the latest timed rep with one silent beat after sentence one.",
                        responseMode: .immediateOnly,
                        toneMode: .explain,
                        repairFocus: nil
                    )
                case "What would make you change the diagnosis?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The diagnosis should move only when the result repeats under pressure.",
                        confidence: 0.36,
                        evidenceUsed: ["One timed rep gives a usable mechanics sample."],
                        rubricScores: [],
                        missingEvidence: ["A repeated pressure result with the verdict first and a settled close."],
                        nextProofTest: "Run the next rep under the same conditions and compare the close.",
                        responseMode: .immediateOnly,
                        toneMode: .explain,
                        repairFocus: nil
                    )
                case "I did one pressure rep. It was cleaner but not settled.":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "Pressure is the next lever: repeat the same answer and protect the close.",
                        confidence: 0.36,
                        evidenceUsed: ["The user reports one pressure rep was cleaner but not settled."],
                        rubricScores: [],
                        missingEvidence: ["A second pressure result showing the close stays settled."],
                        nextProofTest: "Run the next rep with the same verdict and slow only the final five words.",
                        responseMode: .immediateOnly,
                        toneMode: .validate,
                        repairFocus: nil
                    )
                case "I tried it and still filled before the proof.":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "Pacing is the next lever: move the pause to the proof boundary.",
                        confidence: 0.34,
                        evidenceUsed: ["The user reports that the filler still appeared before the proof."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Run the next rep with a one-beat pause before the proof and no restart.",
                        responseMode: .immediateOnly,
                        toneMode: .prescribe,
                        repairFocus: nil
                    )
                case "What should I look for before I call it progress?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "One cleaner rep is a signal, not a trend.",
                        confidence: 0.36,
                        evidenceUsed: ["The latest pressure rep was cleaner but not settled."],
                        rubricScores: [],
                        missingEvidence: ["A repeated pressure result with the same verdict and steady close."],
                        nextProofTest: "Run the next pressure rep with the verdict first and check the final five words.",
                        responseMode: .immediateOnly,
                        toneMode: .validate,
                        repairFocus: nil
                    )
                case "What test separates those?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "Treat structure as the observable hypothesis and authority as unproven.",
                        confidence: 0.33,
                        evidenceUsed: ["The recommendation arrived late in the available transcript."],
                        rubricScores: [],
                        missingEvidence: ["A controlled comparison that changes order without changing voice or filler count."],
                        nextProofTest: "Run the same answer both as-is and verdict-first, then compare the result.",
                        responseMode: .immediateOnly,
                        toneMode: .explain,
                        repairFocus: nil
                    )
                case "I have a leadership update tomorrow, what should I practice?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The ending is the next lever: make the final sentence the ask or decision, then stop.",
                        confidence: 0.31,
                        evidenceUsed: ["The latest timed rep was solid on fillers but light on the close."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Give the update as decision, one business reason, and the ask in under 75 seconds.",
                        responseMode: .immediateOnly,
                        toneMode: .prescribe,
                        repairFocus: nil
                    )
                case "I do not know the ask yet.":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The ending is still the lever, even while the business ask is provisional.",
                        confidence: 0.31,
                        evidenceUsed: ["The leadership update needs a final-sentence ask."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Use a placeholder ask and rehearse the close once.",
                        responseMode: .immediateOnly,
                        toneMode: .prescribe,
                        repairFocus: nil
                    )
                case "I did the update. People asked for the timeline, not the decision.":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "The ending is the next lever: make the final sentence the ask or decision, then stop.",
                        confidence: 0.31,
                        evidenceUsed: ["One recent Timed rep gives a usable sample."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "End the next rep with the exact decision or ask, then stop talking for two seconds.",
                        responseMode: .immediateOnly,
                        toneMode: .prescribe,
                        repairFocus: nil
                    )
                case "What should I capture now?":
                    return CoachAssessment(
                        turnDepth: .quickMove,
                        surface: .text,
                        questionRestatement: testCase.turn,
                        directVerdict: "Salience is the next lever: add one concrete detail, then return to the ask.",
                        confidence: 0.31,
                        evidenceUsed: ["One recent Timed rep gives a usable sample."],
                        rubricScores: [],
                        missingEvidence: [],
                        nextProofTest: "Replay the latest Timed rep with one concrete detail after the verdict, then return to the ask.",
                        responseMode: .immediateOnly,
                        toneMode: .prescribe,
                        repairFocus: nil
                    )
                default:
                    return nil
                }
            }()
            let recentCoachReplies: [String] = {
                switch testCase.turn {
                case "And stop saying practice more.":
                    return ["Fair push. The recommendation should come first, followed by one proof point."]
                case "This is robotic and too much writing.":
                    return ["The prior reply sounded like a report instead of a coach read."]
                case "What was generic about it?":
                    return ["The prior answer named a plan without naming the behavior."]
                case "Okay, that's cool. However, I don't feel like that answered what I meant.":
                    return ["The polite wording hid stronger friction than the words suggested."]
                case "Do I pause before every sentence?":
                    return ["Replace the filler urge with one silent beat before the final sentence."]
                case "What proves it worked?":
                    return ["Pause only where the pressure leaks: before the close."]
                case "I tried the close pause and fillers dropped, but I sounded stiff.":
                    return ["Use the same prompt and compare fillers after the pause point."]
                case "How do I make that natural tomorrow?":
                    return ["Keep the beat only before the final sentence and add one natural phrase after it."]
                case "What next?":
                    return ["Choose the highest-leverage next action instead of offering a broad menu."]
                case "Why the close instead of the opening?":
                    return ["The recurring close is the lever; rewrite only the final sentence."]
                case "What is the exact rep?":
                    return ["The close is where authority leaks because the answer ends as a summary."]
                case "I rewrote the close and it became too direct.":
                    return ["Use 60 seconds and make the last sentence the ask."]
                case "What do I do after that rep?":
                    return ["Keep the ask and add one reason before it."]
                case "Does that make me sound less warm?":
                    return ["Put the recommendation first, add one reassurance after it, then stop."]
                case "What did you miss?":
                    return ["The polite pushback hid stronger friction than the words suggested."]
                case "How do I test that without sounding harsh?":
                    return ["The actual read is order: warmth came before the recommendation."]
                case "I said cool because I was trying not to be rude.":
                    return ["Run one client concern answer without removing warmth."]
                case "I tried recommendation first and it sounded abrupt.":
                    return ["Use this order: recommendation, one reason, one reassurance, then stop."]
                case "So not my whole speaking style yet?":
                    return ["For the first baseline, listen to sentence one and rerun it if the answer starts with background."]
                case "Is 7/10 bad?":
                    return ["You are not proven authoritative overall yet; one score is only mechanics evidence."]
                case "What would make you change the diagnosis?":
                    return ["A 7/10 is one useful mechanics signal, not an authority verdict."]
                case "I did one pressure rep. It was cleaner but not settled.":
                    return ["Two clean pressure reps would change the diagnosis; repeatability is the evidence threshold."]
                case "I tried it and still filled before the proof.":
                    return ["Use a 45-second recommendation prompt: decision, one reason, then stop cleanly."]
                case "What should I look for before I call it progress?":
                    return ["Run a second pressure rep with the same verdict and slow only the final five words."]
                case "What test separates those?":
                    return ["The observable issue is order; the authority claim is not proven by this transcript."]
                case "I have a leadership update tomorrow, what should I practice?":
                    return ["The recent timed rep was solid on fillers but light on the close."]
                case "I do not know the ask yet.":
                    return ["Practice one leadership update and make the final sentence the ask, not a summary."]
                default:
                    return []
                }
            }()
            let repairIssue: CoachChatReplyQualityIssue = {
                switch testCase.turn {
                case "How far off am I from sounding authoritative?":
                    return .overclaimsEvidence
                case "Do I pause before every sentence?":
                    return .roboticPhrase("let's")
                case "The no-symbol version is easier to hear.":
                    return .roboticPhrase("understood")
                case "This is robotic and too much writing?",
                     "This is robotic and too much writing.",
                     "What was generic about it?",
                     "Okay, that's cool. However, I don't feel like that answered what I meant.":
                    return .roboticPhrase("let us")
                case "What is the exact rep?":
                    return .unanchoredCoaching
                case "So not my whole speaking style yet?":
                    return .unengagedUserSpeechClaim
                case "Is 7/10 bad?", "What should I look for before I call it progress?":
                    return .overclaimsEvidence
                case "What would make you change the diagnosis?":
                    return .semanticJudgement(.missingIntentFit)
                case "Does that make me sound less warm?":
                    return .semanticJudgement(.missingIntentFit)
                case "What did you miss?", "How do I test that without sounding harsh?":
                    return .missingInsightBridge
                case "I said cool because I was trying not to be rude.":
                    return .unanchoredCoaching
                case "I tried recommendation first and it sounded abrupt.":
                    return .tooLong
                default:
                    return .missingInsightBridge
                }
            }()
            let expected = try #require(
                AICoachChatService.directFollowThroughRepairReferenceShape(
                    for: testCase.turn,
                    system: testCase.system
                )
            )
            let expectedQualityIssue = AICoachChatService.replyQualityIssue(
                in: expected,
                latestUserTurn: testCase.turn,
                systemContext: testCase.system,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth,
                surface: .text
            )
            let expectedSemanticIssue = AICoachChatService.semanticQualityIssue(
                in: expected,
                latestUserTurn: testCase.turn,
                systemContext: testCase.system,
                turnDepth: turnDepth,
                assessment: assessment
            )
            let expectedVision = AICoachChatService.coachVisionEvaluation(
                reply: expected,
                latestUserTurn: testCase.turn,
                systemContext: testCase.system,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth,
                assessment: assessment,
                surface: .text
            )

            #expect(expectedQualityIssue == nil, "\(testCase.turn): \(String(describing: expectedQualityIssue))")
            #expect(expectedSemanticIssue == nil, "\(testCase.turn): \(String(describing: expectedSemanticIssue))")
            #expect(expectedVision.passesProductionFloor, "\(testCase.turn): \(expectedVision)")
            let repaired = try #require(AICoachChatService.safeReferenceRepairReply(
                issue: repairIssue,
                latestUserTurn: testCase.turn,
                system: testCase.system,
                quoteGuard: nil,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth,
                assessment: assessment,
                surface: .text
            ))

            #expect(repaired == expected)
            #expect(AICoachChatService.replyQualityIssue(
                in: repaired,
                latestUserTurn: testCase.turn,
                systemContext: testCase.system,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth,
                surface: .text
            ) == nil)
            #expect(AICoachChatService.semanticQualityIssue(
                in: repaired,
                latestUserTurn: testCase.turn,
                systemContext: testCase.system,
                turnDepth: turnDepth,
                assessment: assessment
            ) == nil)
            #expect(AICoachChatService.coachVisionEvaluation(
                reply: repaired,
                latestUserTurn: testCase.turn,
                systemContext: testCase.system,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth,
                assessment: assessment,
                surface: .text
            ).passesProductionFloor)
        }

        #expect(AICoachChatService.replyQualityIssue(
            in: "I do not have that recording yet, so record it again and I can hear where it drifted.",
            latestUserTurn: "What happened in that rep? It rambled after sentence two.",
            systemContext: "RECENT USER TURNS\n- The user reports that the answer rambled after sentence two.",
            turnDepth: .groundedRead,
            surface: .text
        ) == .missingPrescribedAction)
    }

    @Test func critiqueLetsDraftUsesSafeRepairWithoutSecondProviderCall() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let turn = "This is robotic and too much writing."
        let weakDraft = "Fair push. That sounded like a generic report. Let's put the recommendation first, then stop."
        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData(weakDraft))
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
        let assessment = CoachAssessment(
            turnDepth: .trustRepair,
            surface: .text,
            questionRestatement: turn,
            directVerdict: "The repair is to name the miss first, then answer with one useful move.",
            confidence: 0.33,
            evidenceUsed: ["Your last rep gives one safe signal."],
            rubricScores: [],
            missingEvidence: ["Need another rep before making a stronger call."],
            nextProofTest: "Rewrite the read with one human acknowledgement and one user-specific signal.",
            responseMode: .expandable,
            toneMode: .repair,
            repairFocus: "I sounded cold instead of giving a human coach read"
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: turn)],
            systemPrompt: "You are Noum.",
            userContext: "RECENT (most-recent first)\n- The recommendation arrived late.",
            turnDepth: .trustRepair,
            assessment: assessment
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected deterministic safe repair, got \(outcome)")
            return
        }
        #expect(await scripted.callCount == 1)
        #expect(!text.lowercased().contains("let's"))
        #expect(AICoachChatService.replyQualityIssue(
            in: text,
            latestUserTurn: turn,
            systemContext: "RECENT (most-recent first)\n- The recommendation arrived late."
        ) == nil)
        #expect(diagnostics.records.contains { record in
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            [
                "Safe reference repair accepted before provider rewrite",
                "Typed assessment repair accepted before provider rewrite"
            ].contains(record.reason)
        })
    }

    @Test func repeatedProofTestTripsTurnAwareQualityGate() {
        let prior = "Last rep had 6 fillers, so run the same 60-second proof test."
        let repeated = "The pressure cue is still the close, so run the same 60-second proof test."
        let reminder = "Do not run the same 60-second proof test. Keep the prior result, then vary the close."

        #expect(AICoachChatService.replyQualityIssue(
            in: repeated,
            latestUserTurn: "What next?",
            recentCoachReplies: [prior]
        ) == .repeatedProofTest)
        #expect(AICoachChatService.replyQualityIssue(
            in: reminder,
            latestUserTurn: "What next?",
            recentCoachReplies: [prior]
        ) != .repeatedProofTest)
    }

    @Test func providerRepairCannotRepeatRecentProofTest() async {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let priorCoachReply = "Last rep had 6 fillers, so run the same 60-second proof test."
        let repeatedDraft = "The close is still leaking pressure, so run the same 60-second proof test."
        let advancedRepair = "Your last rep already has that proof test set, so vary the check: keep the same prompt and judge only whether the final sentence lands cleanly."
        #expect(AICoachChatService.replyQualityIssue(
            in: advancedRepair,
            latestUserTurn: "What next?",
            recentCoachReplies: [priorCoachReply]
        ) == nil)
        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData(repeatedDraft)),
            .success(Self.openAIData(advancedRepair))
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
                CoachMessage(role: .user, text: "How do I stop saying um under pressure?"),
                CoachMessage(role: .coach, text: priorCoachReply),
                CoachMessage(role: .user, text: "What next?")
            ],
            systemPrompt: "You are Noum.",
            userContext: "RECENT (most-recent first)\n- Your last rep had 6 fillers."
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected repeated proof-test repair, got \(outcome)")
            return
        }

        #expect(text == advancedRepair)
        #expect(await scripted.callCount == 2)
        #expect(diagnostics.records.contains { record in
            record.surface == "Ask Noum chat" &&
            record.provider == "OpenAI" &&
            record.outcome == .fallback &&
            record.reason.contains("repeatedProofTest")
        })
        #expect(diagnostics.records.contains { record in
            record.surface == "Ask Noum chat" &&
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            record.reason == "Repair reply accepted"
        })
    }

    @Test func critiqueRepairMustNameTheUserFriction() {
        let turn = "This still sounds cold and overexplained, like generic AI tips."
        let vagueRepair = "Fair push. Your last rep had one filler, so say the recommendation first, then stop."
        let specificRepair = "Fair push: that was advice, not coaching. Your last rep had one filler, so say the recommendation first, then soften it with one reassurance."

        #expect(AICoachChatService.replyQualityIssue(
            in: vagueRepair,
            latestUserTurn: turn,
            systemContext: "RECENT (most-recent first)\n- Your last rep had 1 filler."
        ) == .missedTrustRepair)
        #expect(AICoachChatService.professionalCoachRubric(
            reply: vagueRepair,
            latestUserTurn: turn
        ).misses.contains(.missedTrustRepair))

        #expect(AICoachChatService.replyQualityIssue(
            in: specificRepair,
            latestUserTurn: turn,
            systemContext: "RECENT (most-recent first)\n- Your last rep had 1 filler."
        ) == nil)
        #expect(AICoachChatService.professionalCoachRubric(
            reply: specificRepair,
            latestUserTurn: turn
        ).passesSeniorCoachFloor)
    }

    @Test func quoteGuardRejectsRecommendationArrivedLateWhenTranscriptLeads() {
        let turn = "Is 7/10 bad?"
        let transcript = "My recommendation is to keep the launch date because the migration risk is contained."
        let guardContext = CoachChatQuoteGuardContext(
            transcripts: [transcript],
            latestUserTurn: turn
        )

        let issue = AICoachChatService.replyQualityIssue(
            in: "Your last rep was clean, but the recommendation arrived late, so put it in sentence one.",
            latestUserTurn: turn,
            quoteGuard: guardContext,
            systemContext: "TRANSCRIPT\n- \(transcript)",
            turnDepth: .quickMove
        )

        #expect(issue == .overclaimsEvidence)
    }

    @Test func overclaimRepairUsesEvidenceSourceOfTruthBeforeProviderRewrite() async throws {
        let turn = "Why did that answer land badly?"
        let transcript = "I waited too long to state the recommendation, then gave the context after it."
        let repaired = "From the transcript, the recommendation arrived late, so say the decision first, add one reason, then name the implication."
        let guardContext = CoachChatQuoteGuardContext(
            transcripts: [transcript],
            latestUserTurn: turn
        )
        #expect(AICoachChatService.replyQualityIssue(
            in: repaired,
            latestUserTurn: turn,
            quoteGuard: guardContext,
            systemContext: "TRANSCRIPT\n- \(transcript)"
        ) == nil)
        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData("Your last rep led with the point, but it lacked a reason, so give one proof point next time."))
        ])
        let service = AICoachChatService(
            keyedProviders: { [.openAI] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { provider, endpoint, key, body in
                await scripted.next(provider: provider, endpoint: endpoint, key: key, body: body)
            }
        )

        let outcome = await service.reply(
            history: [
                CoachMessage(role: .user, text: turn)
            ],
            systemPrompt: "You are Noum.",
            userContext: "TRANSCRIPT\n- \(transcript)",
            grounding: ChatGroundingContext(recentTimedTranscript: transcript)
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected repaired reply, got \(outcome)")
            return
        }
        #expect(text == repaired)

        let systemMessages = await scripted.systemMessages
        #expect(await scripted.callCount == 1)
        #expect(systemMessages.count == 1)
        let systemMessage = try #require(systemMessages.last)

        #expect(!systemMessage.contains("Evidence overclaim repair"))
    }

    @Test func safeReferenceRepairResolvesEvidenceBoundaryBeforeProviderRepair() async throws {
        let diagnostics = CoachDiagnosticRecorderProbe()
        let turn = "Why did that answer land badly?"
        let transcript = "I waited too long to state the recommendation, then gave the context after it."
        let safeRepair = "From the transcript, the recommendation arrived late, so say the decision first, add one reason, then name the implication."
        let guardContext = CoachChatQuoteGuardContext(
            transcripts: [transcript],
            latestUserTurn: turn
        )
        #expect(AICoachChatService.replyQualityIssue(
            in: safeRepair,
            latestUserTurn: turn,
            quoteGuard: guardContext,
            systemContext: "TRANSCRIPT\n- \(transcript)"
        ) == nil)
        let scripted = ScriptedCoachHTTP(results: [
            .success(Self.openAIData("Your last rep led with the point, but it lacked a reason, so give one proof point next time."))
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
                CoachMessage(role: .user, text: turn)
            ],
            systemPrompt: "You are Noum.",
            userContext: "TRANSCRIPT\n- \(transcript)",
            grounding: ChatGroundingContext(recentTimedTranscript: transcript)
        )

        guard case .reply(let text) = outcome else {
            Issue.record("Expected safe reference repair, got \(outcome)")
            return
        }
        #expect(text == safeRepair)
        #expect(await scripted.callCount == 1)
        #expect(diagnostics.records.contains { record in
            record.surface == "Ask Noum chat" &&
            record.provider == "OpenAI" &&
            record.outcome == .success &&
            record.reason == "Safe reference repair accepted before provider rewrite"
        })
        #expect(!diagnostics.records.contains { record in
            record.reason == "All chat providers failed quality gate"
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

    @Test func paymentRequiredProviderCoolsBehindNextProvider() async {
        let userTurn = "Give me one move for the next rep."
        let acceptedReply = "Your message asks for one move, so keep the test narrow. In the next rep, answer first, give one proof point, then stop. That tests whether structure holds when the timer is tight."
        #expect(AICoachChatService.replyQualityIssue(in: acceptedReply, latestUserTurn: userTurn) == nil)

        let scripted = ScriptedCoachHTTP(results: [
            .refused(status: 402, retryAfter: nil),
            .success(Self.anthropicData(acceptedReply)),
            .success(Self.anthropicData(acceptedReply))
        ])
        let service = AICoachChatService(
            keyedProviders: { [.deepSeek, .anthropic] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { provider, endpoint, key, body in
                await scripted.next(provider: provider, endpoint: endpoint, key: key, body: body)
            }
        )

        let history = [
            CoachMessage(role: .user, text: userTurn)
        ]

        let firstOutcome = await service.reply(
            history: history,
            systemPrompt: "You are Noum.",
            userContext: "No recent sessions."
        )
        guard case .reply(let firstText) = firstOutcome else {
            Issue.record("Expected Claude fallback reply, got \(firstOutcome)")
            return
        }
        #expect(firstText == acceptedReply)

        let secondOutcome = await service.reply(
            history: history,
            systemPrompt: "You are Noum.",
            userContext: "No recent sessions."
        )
        guard case .reply(let secondText) = secondOutcome else {
            Issue.record("Expected Claude to run before cooled DeepSeek, got \(secondOutcome)")
            return
        }
        #expect(secondText == acceptedReply)
        #expect(await scripted.providers == [.deepSeek, .anthropic, .anthropic])
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
    private(set) var systemMessages: [String] = []

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
        if let system = systemText(from: body) {
            systemMessages.append(system)
        }
        guard !results.isEmpty else {
            return .refused(status: 500, retryAfter: nil)
        }
        return results.removeFirst()
    }

    private func systemText(from body: [String: Any]) -> String? {
        if let messages = body["messages"] as? [[String: Any]],
           let system = messages.first(where: { $0["role"] as? String == "system" })?["content"] as? String {
            return system
        }
        if let system = body["system"] as? String {
            return system
        }
        if let instruction = body["systemInstruction"] as? [String: Any],
           let parts = instruction["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text
        }
        return nil
    }
}

private actor TransientThenSuccessCoachHTTP {
    private let success: AICoachChatService.ProviderHTTPResult
    private(set) var callCount: Int = 0
    private(set) var providers: [CoachChatProvider] = []

    init(success: AICoachChatService.ProviderHTTPResult) {
        self.success = success
    }

    func next(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any]
    ) throws -> AICoachChatService.ProviderHTTPResult {
        callCount += 1
        providers.append(provider)
        if callCount == 1 {
            throw URLError(.timedOut)
        }
        return success
    }
}

private actor TransientRepairThenSuccessCoachHTTP {
    private let first: AICoachChatService.ProviderHTTPResult
    private let repaired: AICoachChatService.ProviderHTTPResult
    private(set) var callCount: Int = 0

    init(
        first: AICoachChatService.ProviderHTTPResult,
        repaired: AICoachChatService.ProviderHTTPResult
    ) {
        self.first = first
        self.repaired = repaired
    }

    func next(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any]
    ) throws -> AICoachChatService.ProviderHTTPResult {
        callCount += 1
        switch callCount {
        case 1:
            return first
        case 2:
            throw URLError(.networkConnectionLost)
        default:
            return repaired
        }
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

    @Test func anthropicStreamExtractionAccumulatesTextDeltas() {
        let payload = data("""
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_1"}}

        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Lead with "}}

        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"the verdict."}}

        event: message_stop
        data: {"type":"message_stop"}
        """)

        #expect(AICoachChatService.chatExtractStreamReplyText(
            from: payload,
            provider: .anthropic
        ) == .text("Lead with the verdict."))
    }

    @Test func anthropicStreamMaxTokensIsLengthTruncated() {
        let payload = data("""
        event: content_block_delta
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"This stops mid"}}

        event: message_delta
        data: {"type":"message_delta","delta":{"stop_reason":"max_tokens"}}
        """)

        #expect(AICoachChatService.chatExtractStreamReplyText(
            from: payload,
            provider: .anthropic
        ) == .lengthTruncated)
    }

    @Test func openAIStyleStreamExtractionAccumulatesDeltas() {
        let payload = data("""
        data: {"choices":[{"delta":{"content":"Use one "},"finish_reason":null}]}

        data: {"choices":[{"delta":{"content":"proof point."},"finish_reason":"stop"}]}

        data: [DONE]
        """)

        #expect(AICoachChatService.chatExtractStreamReplyText(
            from: payload,
            provider: .openAI
        ) == .text("Use one proof point."))
    }

    @Test func geminiStreamExtractionAccumulatesDeltas() {
        let payload = data("""
        data: {"candidates":[{"content":{"parts":[{"text":"Mechanics are "}]}}]}

        data: {"candidates":[{"content":{"parts":[{"text":"usable; authority is not proven."}]},"finishReason":"STOP"}]}
        """)

        #expect(AICoachChatService.chatExtractStreamReplyText(
            from: payload,
            provider: .gemini
        ) == .text("Mechanics are usable; authority is not proven."))
    }

    @Test func googleStreamingEndpointsUseSSEGenerateContent() {
        let agent = CoachChatProvider.agentPlatformStreamingEndpoint(model: "gemini-3.5-flash")?.absoluteString
        let gemini = CoachChatProvider.gemini.streamingEndpoint?.absoluteString

        #expect(agent?.contains(":streamGenerateContent?alt=sse") == true)
        #expect(gemini?.contains(":streamGenerateContent?alt=sse") == true)
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

    @Test func chatHTTPFailureReasonNamesPaymentRequiredBillingBlock() {
        let reason = AICoachChatService.failureReason(
            forHTTPStatus: 402,
            data: Data(),
            provider: .deepSeek
        )

        #expect(reason == "Provider billing/account blocked (HTTP 402)")
    }
}
