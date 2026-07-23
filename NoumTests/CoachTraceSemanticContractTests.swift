import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Ask Noum trace semantic contract", .serialized)
struct CoachTraceSemanticContractTests {

    @Test("Pipeline records classification, goal, memory, and evidence in causal order")
    func semanticStagesFollowCausalOrder() async throws {
        let context = makeContext(label: "semantic-order")
        defer { context.cleanup() }

        _ = await CoachReplyPipeline.generate(
            coachID: context.coachID,
            store: context.store,
            coachService: context.service,
            judgementPassEnabled: false,
            realtimeCoachModeEnabled: false,
            sessionsOverride: [],
            coachMemoryOverride: { nil }
        )

        let trace = try #require(FlowEventLog.shared.recentCoachTraces(limit: 20)
            .first(where: { $0.correlationId == context.coachID }))
        let stages = trace.events.map(\.stage)
        let semanticPath = [
            CoachTraceStage.classified,
            CoachTraceStage.goalResolved,
            CoachTraceStage.memoryLoaded,
            CoachTraceStage.evidenceLoaded,
            CoachTraceStage.rubricSelected,
            CoachTraceStage.promptAssembled,
        ]
        let indexes = try semanticPath.map { stage in
            try #require(stages.firstIndex(of: stage), "Missing trace stage \(stage)")
        }

        #expect(indexes == indexes.sorted())
        #expect(Set(indexes).count == semanticPath.count)
        let memory = try #require(trace.events.first(where: {
            $0.stage == CoachTraceStage.memoryLoaded
        }))
        #expect(memory.numerics["hasMemory"] == 0)
        #expect(memory.numerics["memoryEvidence"] == 0)
    }

    @Test("Gated provider partial records buffering without claiming UI visibility")
    func gatedPartialDoesNotClaimVisibility() async throws {
        #expect(!CoachBrainFlags.streamRawPartialsToUI)
        let context = makeContext(label: "stream-buffered")
        defer { context.cleanup() }

        _ = await CoachReplyPipeline.generate(
            coachID: context.coachID,
            store: context.store,
            coachService: context.service,
            judgementPassEnabled: false,
            realtimeCoachModeEnabled: false,
            sessionsOverride: [],
            coachMemoryOverride: { nil }
        )

        let trace = try #require(FlowEventLog.shared.recentCoachTraces(limit: 20)
            .first(where: { $0.correlationId == context.coachID }))
        let stages = trace.events.map(\.stage)
        #expect(stages.filter { $0 == CoachTraceStage.streamFirstBuffered }.count == 1)
        #expect(!stages.contains(CoachTraceStage.streamFirstVisible))
    }

    private func makeContext(label: String) -> TraceTestContext {
        let suiteName = "CoachTraceSemanticContractTests.\(label).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        FlowEventLog.shared.reset()
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()

        let store = AskNoumStore(
            defaults: defaults,
            accountIDProvider: { "trace-contract" }
        )
        let ids = store.appendUserTurn(
            "How can I make my next project update clearer?"
        )
        return TraceTestContext(
            suiteName: suiteName,
            defaults: defaults,
            store: store,
            coachID: ids.coachID,
            service: AICoachChatService(secureTransport: TraceStreamingTransport())
        )
    }
}

@MainActor
private struct TraceTestContext {
    let suiteName: String
    let defaults: UserDefaults
    let store: AskNoumStore
    let coachID: UUID
    let service: AICoachChatService

    func cleanup() {
        FlowEventLog.shared.reset()
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private struct TraceStreamingTransport: CoachChatTransport {
    func availability() async -> CoachChatTransportAvailability { .available }

    func stream(
        _ request: CoachChatRequest
    ) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        let reply = "State the decision first, then add one concrete reason."
        let completion = CoachChatCompletion(
            requestID: request.requestID,
            text: reply,
            model: "trace-contract-model",
            qualityTier: request.qualityTier,
            finishReason: "STOP",
            inputTokens: 12,
            outputTokens: 10,
            policyVersion: "noum-coach-v2",
            generationMode: .model
        )
        return AsyncThrowingStream { continuation in
            continuation.yield(.delta("State the decision first, then pause. "))
            continuation.yield(.completion(completion))
            continuation.finish()
        }
    }
}
