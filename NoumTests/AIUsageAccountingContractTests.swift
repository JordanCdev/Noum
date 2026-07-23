import Foundation
import Testing
@testable import Noum

@MainActor
struct AIUsageAccountingContractTests {
    private let acceptedReply = "Put the recommendation first, add one concrete proof point, then stop. That keeps the next answer clear under time pressure."

    @Test func secureCoachCarriesReturnedUsageIntoOnePricedRecord() async throws {
        let traceID = UUID()
        let probe = AIUsageRecordProbe()
        let transport = AIUsageCompletionTransport(
            text: acceptedReply,
            model: "gemini-2.5-flash",
            inputTokens: 120,
            outputTokens: 24
        )
        let service = AICoachChatService(
            secureTransport: transport,
            usageRecorder: { probe.record($0) }
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I fix first?")],
            systemPrompt: "Coach only from available evidence.",
            userContext: "The recommendation arrived after the setup.",
            traceID: traceID,
            turnDepth: .quickMove,
            preferredTier: .geminiFast
        )

        guard case .reply = outcome else {
            Issue.record("Expected the secure coach reply to land, got \(outcome)")
            return
        }
        let record = try #require(probe.records.first)
        #expect(probe.records.count == 1)
        #expect(record.provider == "Firebase / Vertex AI")
        #expect(record.model == "gemini-2.5-flash")
        #expect(record.inputTokens == 120)
        #expect(record.outputTokens == 24)
        #expect(record.correlationID == traceID)
        #expect(record.usageAccounting == .providerRequest)

        let events = try projectedEvents(for: [record])
        #expect(events.count == 1)
        #expect(events.first?.name == .aiUsageEstimated)
        #expect(events.first?.aiProvider == .google)
        #expect(!events.contains { $0.name == .aiUsageUnpriced })
    }

    @Test func directProviderSuccessProducesOnePricedRecord() async throws {
        let probe = AIUsageRecordProbe()
        let service = AICoachChatService(
            keyedProviders: { [.agentPlatform] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in
                .success(Self.geminiResponse(
                    text: acceptedReply,
                    inputTokens: 80,
                    outputTokens: 16
                ))
            },
            diagnosticRecorder: { _, _, _, _, _, _, _, _ in },
            usageRecorder: { probe.record($0) }
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "Give me one move for the next rep.")],
            systemPrompt: "You are Noum.",
            userContext: "No recent sessions."
        )

        guard case .reply = outcome else {
            Issue.record("Expected the direct provider reply to land, got \(outcome)")
            return
        }
        let record = try #require(probe.records.first)
        #expect(probe.records.count == 1)
        #expect(record.provider == "Google Cloud")
        #expect(record.inputTokens == 80)
        #expect(record.outputTokens == 16)

        let events = try projectedEvents(for: [record])
        #expect(events.count == 1)
        #expect(events.first?.name == .aiUsageEstimated)
        #expect(!events.contains { $0.name == .aiUsageUnpriced })
    }

    @Test func streamingBreadcrumbsCannotCreateDuplicateUnpricedUsage() throws {
        let terminal = AICallDiagnosticRecord.make(
            surface: "Ask Noum chat",
            provider: "Google Cloud",
            model: "gemini-3.5-flash",
            outcome: .success,
            reason: "input=80 output=16",
            inputTokens: 80,
            outputTokens: 16,
            usageAccounting: .providerRequest
        )
        let firstToken = AICallDiagnosticRecord.make(
            surface: "Ask Noum chat",
            provider: "Google Cloud",
            model: "gemini-3.5-flash",
            outcome: .success,
            reason: "Streaming first provider token received",
            usageAccounting: .informational
        )
        let accepted = AICallDiagnosticRecord.make(
            surface: "Ask Noum chat",
            provider: "Google Cloud",
            model: "gemini-3.5-flash",
            outcome: .success,
            reason: "Reply accepted",
            usageAccounting: .informational
        )

        let events = try projectedEvents(for: [firstToken, terminal, accepted])
        #expect(events.count == 1)
        #expect(events.first?.name == .aiUsageEstimated)
        #expect(!events.contains { $0.name == .aiUsageUnpriced })
    }

    @Test func refusedDirectRequestProducesOneExplicitUnpricedRecord() async throws {
        let probe = AIUsageRecordProbe()
        let service = AICoachChatService(
            keyedProviders: { [.agentPlatform] },
            keyLookup: { _ in "test-key" },
            localeSupportsAI: { true },
            providerHTTP: { _, _, _, _ in
                .refused(status: 402, retryAfter: nil)
            },
            diagnosticRecorder: { _, _, _, _, _, _, _, _ in },
            usageRecorder: { probe.record($0) }
        )

        _ = await service.reply(
            history: [CoachMessage(role: .user, text: "Give me one move.")],
            systemPrompt: "You are Noum.",
            userContext: "No recent sessions."
        )

        let record = try #require(probe.records.first)
        #expect(probe.records.count == 1)
        #expect(record.outcome == .fallback)
        #expect(record.statusCode == 402)
        #expect(record.inputTokens == nil)
        #expect(record.outputTokens == nil)

        let events = try projectedEvents(for: [record])
        #expect(events.count == 1)
        #expect(events.first?.name == .aiUsageUnpriced)
        #expect(events.first?.aiProvider == .google)
    }

    private func projectedEvents(for records: [AICallDiagnosticRecord]) throws -> [GrowthEvent] {
        let suiteName = "ai-usage-accounting.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let diagnostics = AICallDiagnosticsStore(
            defaults: defaults,
            storageKey: "diagnostics"
        )
        let log = FlowEventLog(defaults: defaults, storageKey: "growth")
        let sink = FlowEventGrowthEventSink(flowEventLog: log)

        for record in records {
            _ = AICallDiagnostics.commit(
                record,
                diagnosticsStore: diagnostics,
                growthEventSink: sink
            )
        }
        #expect(diagnostics.records.count == records.count)
        return log.growthEvents()
    }

    private static func geminiResponse(
        text: String,
        inputTokens: Int,
        outputTokens: Int
    ) -> Data {
        let payload: [String: Any] = [
            "candidates": [[
                "content": ["parts": [["text": text]]],
                "finishReason": "STOP",
            ]],
            "usageMetadata": [
                "promptTokenCount": inputTokens,
                "candidatesTokenCount": outputTokens,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }
}

private final class AIUsageRecordProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRecords: [AICallDiagnosticRecord] = []

    var records: [AICallDiagnosticRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storedRecords
    }

    func record(_ record: AICallDiagnosticRecord) {
        lock.lock()
        storedRecords.append(record)
        lock.unlock()
    }
}

private struct AIUsageCompletionTransport: CoachChatTransport {
    let text: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int

    func availability() async -> CoachChatTransportAvailability { .available }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        let completion = CoachChatCompletion(
            requestID: request.requestID,
            text: text,
            model: model,
            qualityTier: request.qualityTier,
            finishReason: "STOP",
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            policyVersion: "noum-coach-v2",
            generationMode: .model
        )
        return AsyncThrowingStream { continuation in
            continuation.yield(.completion(completion))
            continuation.finish()
        }
    }
}
