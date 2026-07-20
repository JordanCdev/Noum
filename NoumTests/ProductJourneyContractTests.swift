import Foundation
import Testing
@testable import Noum

@Suite("Product journey contracts", .serialized)
struct ProductJourneyContractTests {

    @Test("Transcript ladder UI fixture has two safe bounded rewrites")
    func transcriptLadderUITestFixtureIsRewriteable() throws {
        let transcript = "Um, so I think the release should start next week because the support team has time to prepare. The customer message needs one clear decision."
        let oneStep = try #require(AIRewriteService.onDeviceRewrite(
            transcript: transcript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .medium,
            confidence: nil
        ))
        let aspiration = try #require(AIRewriteService.onDeviceRewrite(
            transcript: transcript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .strong,
            confidence: nil
        ))

        #expect(oneStep.source == .onDevice)
        #expect(aspiration.source == .onDevice)
        #expect(oneStep.text != transcript)
        #expect(aspiration.text != oneStep.text)
    }

    @Test("Transcript ladder highlights only the changed lever")
    func transcriptLadderDiffUsesSequenceNotWordSet() {
        let changed = TranscriptChangeHighlighter.changedWordIndexes(
            original: "I think we should ship it this week",
            revision: "We should ship it this week"
        )
        #expect(changed == [0])

        let insertion = TranscriptChangeHighlighter.changedWordIndexes(
            original: "The data supports this",
            revision: "The data clearly supports this"
        )
        #expect(insertion == [2])
    }

    @MainActor
    @Test("Voice goal changes preserve evidence and invalidate only plan projection")
    func voiceGoalChangePreservesTheObservedCase() {
        let suiteName = "product-journey-voice-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CoachMemoryStore(defaults: defaults, accountIDProvider: { "tester" })
        let hypothesis = "Under pressure, the close loses its final beat."
        let reflection = "I felt rushed when the follow-up arrived."
        let memory = CoachMemory(
            updatedAt: Date(timeIntervalSince1970: 1_000),
            lastSessionID: UUID(),
            evidenceCount: 8,
            evidenceConfidence: .moderate,
            voice: .warm,
            statedGoalSummary: "Keep difficult updates human.",
            currentLever: .paceControl,
            currentLeverConfidence: .medium,
            currentLeverBasis: "Pace rose in three pressure reps.",
            previousLever: .fillerReduction,
            goalFit: .aligned,
            strengths: ["Clear recommendation"],
            blockers: ["Close rush"],
            planWeekIndex: 2,
            planFocus: .paceControl,
            planMode: .timed,
            workingHypothesis: hypothesis,
            adaptationLog: [],
            lastReflectionSummary: reflection
        )
        store.replaceForTesting(memory)

        store.noteVoiceChange(
            from: .warm,
            to: .persuasive,
            reason: CoachCourseChange.voiceChangeReason(from: .warm, to: .persuasive),
            evidenceBasis: "Prior observed evidence retained; only training emphasis changed.",
            statedGoalSummary: "Make the recommendation easier to act on.",
            at: Date(timeIntervalSince1970: 2_000)
        )

        let updated = store.currentMemory
        #expect(updated?.voice == .persuasive)
        #expect(updated?.statedGoalSummary == "Make the recommendation easier to act on.")
        #expect(updated?.evidenceCount == 8)
        #expect(updated?.currentLever == .paceControl)
        #expect(updated?.currentLeverBasis == memory.currentLeverBasis)
        #expect(updated?.strengths == memory.strengths)
        #expect(updated?.blockers == memory.blockers)
        #expect(updated?.workingHypothesis == hypothesis)
        #expect(updated?.lastReflectionSummary == reflection)
        #expect(updated?.planWeekIndex == nil)
        #expect(updated?.planFocus == nil)
        #expect(updated?.planMode == nil)
        #expect(updated?.goalFit == .offGoal)
        #expect(updated?.adaptationLog?.last?.documentsVoiceChange == true)
    }

    @MainActor
    @Test("A blended emphasis records the addition without replacing the primary voice")
    func blendedGoalKeepsPrimaryMemoryProvenance() {
        let suiteName = "product-journey-blend-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CoachMemoryStore(defaults: defaults, accountIDProvider: { "tester" })
        store.replaceForTesting(CoachMemory(
            updatedAt: Date(timeIntervalSince1970: 1_000),
            evidenceCount: 4,
            evidenceConfidence: .moderate,
            voice: .warm,
            currentLever: .structure,
            currentLeverConfidence: .medium,
            currentLeverBasis: "Four eligible reps",
            goalFit: .offGoal,
            strengths: [],
            blockers: []
        ))

        store.noteVoiceChange(
            from: .warm,
            to: .persuasive,
            reason: CoachCourseChange.voiceChangeReason(
                from: .warm,
                to: .persuasive,
                kind: .blend
            ),
            evidenceBasis: "Prior evidence retained.",
            statedGoalSummary: "Keep the warmth while making the ask clearer.",
            effectiveVoice: .warm,
            at: Date(timeIntervalSince1970: 2_000)
        )

        #expect(store.currentMemory?.voice == .warm)
        #expect(store.currentMemory?.evidenceCount == 4)
        #expect(store.currentMemory?.adaptationLog?.last?.reason.contains("blend") == true)
    }

    @MainActor
    @Test("Coaching memory edits cannot rewrite observed evidence")
    func coachingMemoryControlsRespectProvenance() {
        let suiteName = "product-journey-memory-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CoachMemoryStore(defaults: defaults, accountIDProvider: { "tester" })
        let memory = CoachMemory(
            updatedAt: Date(),
            evidenceCount: 5,
            evidenceConfidence: .moderate,
            statedGoalSummary: "Old goal",
            currentLever: .structure,
            currentLeverBasis: "Three eligible reps",
            goalFit: .aligned,
            strengths: ["Specific examples"],
            blockers: ["Buried recommendation"],
            workingHypothesis: "The recommendation arrives after the evidence.",
            lastReflectionSummary: "I was unsure where to stop."
        )
        store.replaceForTesting(memory)

        store.updateStatedGoalSummary("  Lead with the decision.  ")
        store.removeWorkingHypothesis()
        store.removeCarriedReflection()

        let updated = store.currentMemory
        #expect(updated?.statedGoalSummary == "Lead with the decision.")
        #expect(updated?.workingHypothesis == nil)
        #expect(updated?.lastReflectionSummary == nil)
        #expect(updated?.evidenceCount == memory.evidenceCount)
        #expect(updated?.currentLever == memory.currentLever)
        #expect(updated?.currentLeverBasis == memory.currentLeverBasis)
        #expect(updated?.strengths == memory.strengths)
        #expect(updated?.blockers == memory.blockers)
    }

    @MainActor
    @Test("Debug traces group one content-free terminal journey")
    func debugTraceGroupsTerminalStateAndLatency() {
        let suiteName = "product-journey-trace-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let traceID = UUID()
        log.log(FlowEvent.make(
            correlationId: traceID,
            flow: .chatTurn,
            stage: CoachTraceStage.accepted,
            reason: "request accepted"
        ))
        log.log(FlowEvent.make(
            correlationId: traceID,
            flow: .chatTurn,
            stage: CoachTraceStage.providerStarted,
            reason: "provider=secure model=coach"
        ))
        log.log(FlowEvent.make(
            correlationId: traceID,
            flow: .chatTurn,
            stage: CoachTraceStage.terminal,
            reason: CoachTraceTerminalState.safeFallback.rawValue,
            numerics: ["latencyMs": 1_250]
        ))

        let trace = log.recentCoachTraces(limit: 1).first
        #expect(trace?.correlationId == traceID)
        #expect(trace?.terminalState == .safeFallback)
        #expect(trace?.terminalEventCount == 1)
        #expect(trace?.hasTerminalContractViolation == false)
        #expect(trace?.terminalStatusLabel == CoachTraceTerminalState.safeFallback.rawValue)
        #expect(trace?.latencyMs == 1_250)
        #expect(trace?.events.count == 3)
    }

    @MainActor
    @Test("Debug traces expose duplicate or malformed terminal events")
    func debugTraceExposesTerminalContractViolation() {
        let suiteName = "product-journey-duplicate-terminal-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let log = FlowEventLog(defaults: defaults, storageKey: "events")
        let traceID = UUID()
        log.log(FlowEvent.make(
            correlationId: traceID,
            flow: .chatTurn,
            stage: CoachTraceStage.accepted,
            reason: "request accepted"
        ))
        for terminal in [CoachTraceTerminalState.retryableError, .cancelled] {
            log.log(FlowEvent.make(
                correlationId: traceID,
                flow: .chatTurn,
                stage: CoachTraceStage.terminal,
                reason: terminal.rawValue
            ))
        }

        let trace = log.recentCoachTraces(limit: 1).first
        #expect(trace?.terminalEventCount == 2)
        #expect(trace?.hasTerminalContractViolation == true)
        #expect(trace?.terminalStatusLabel == "trace error")

        let malformedID = UUID()
        let malformedTrace = CoachDebugTrace(
            correlationId: malformedID,
            events: [FlowEvent.make(
                correlationId: malformedID,
                flow: .chatTurn,
                stage: CoachTraceStage.terminal,
                reason: "unknown-terminal-state"
            )]
        )
        #expect(malformedTrace.terminalEventCount == 1)
        #expect(malformedTrace.hasTerminalContractViolation)
        #expect(malformedTrace.terminalStatusLabel == "trace error")
    }

    @Test("Every provider outcome maps to an explicit terminal state")
    func terminalStateContractIsExhaustive() {
        #expect(CoachReplyPipeline.terminalState(
            providerOutcome: .reply("Useful reply"),
            finalOutcome: .reply("Useful reply"),
            finalOutcomeSubstituted: false,
            qualityGateEvents: [.passed]
        ) == .accepted)
        #expect(CoachReplyPipeline.terminalState(
            providerOutcome: .reply("Draft"),
            finalOutcome: .reply("Repair"),
            finalOutcomeSubstituted: false,
            qualityGateEvents: [.repaired("semantic guard")]
        ) == .repaired)
        #expect(CoachReplyPipeline.terminalState(
            providerOutcome: .failure(.timedOut),
            finalOutcome: .reply("Safe fallback"),
            finalOutcomeSubstituted: true,
            qualityGateEvents: [.fallback("provider deadline")]
        ) == .safeFallback)
        #expect(CoachReplyPipeline.terminalState(
            providerOutcome: .failure(.timedOut),
            finalOutcome: .failure(.timedOut),
            finalOutcomeSubstituted: false,
            qualityGateEvents: []
        ) == .retryableError)
        #expect(CoachReplyPipeline.terminalState(
            providerOutcome: .failure(.cancelled),
            finalOutcome: .failure(.cancelled),
            finalOutcomeSubstituted: false,
            qualityGateEvents: []
        ) == .cancelled)
    }

    @Test("Provider deadline wins even when provider cancellation is ignored")
    func providerDeadlineCannotWaitForLateProvider() async {
        let provider = Task<ChatOutcome, Never> {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    continuation.resume(returning: .reply("Late reply"))
                }
            }
        }
        defer { provider.cancel() }

        let startedAt = Date()
        let outcome = await CoachReplyPipeline.awaitFirstProviderOutcome(
            provider,
            deadlineSeconds: 0.02
        )
        let elapsed = Date().timeIntervalSince(startedAt)

        guard case .failure(.timedOut) = outcome else {
            Issue.record("Expected a typed timeout, got \(String(describing: outcome))")
            return
        }
        #expect(elapsed < 0.25)
    }

    @Test("Parent cancellation wins even when provider cancellation is ignored")
    func parentCancellationCannotWaitForLateProvider() async {
        let provider = Task<ChatOutcome, Never> {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    continuation.resume(returning: .reply("Late reply"))
                }
            }
        }
        defer { provider.cancel() }

        let waiter = Task {
            await CoachReplyPipeline.awaitFirstProviderOutcome(
                provider,
                deadlineSeconds: 10
            )
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
        let startedAt = Date()
        waiter.cancel()
        let outcome = await waiter.value
        let elapsed = Date().timeIntervalSince(startedAt)

        guard case .failure(.cancelled) = outcome else {
            Issue.record("Expected typed cancellation, got \(String(describing: outcome))")
            return
        }
        #expect(elapsed < 0.25)
    }

    @Test("Authenticity shaming is blocked on voice-goal turns")
    func authenticityShamingCannotReachTheUser() {
        let verdict = CoachReliabilityGate.evaluate(
            replyText: "Your old delivery was a fake persona. You were pretending to be warm.",
            previousCoachReply: nil,
            latestUserTurn: "Can I change my voice goal from warm to persuasive?",
            turnDepth: .quickMove,
            assessment: nil,
            evidenceCoverage: nil
        )
        #expect(verdict.blockingIssues.contains(.goalAuthenticityShaming))
        #expect(verdict.fallbackText != nil)
        #expect(!(verdict.fallbackText ?? "").lowercased().contains("pretending"))
    }

    @Test("A terse copy complaint repairs Noum instead of assigning user work")
    func terseCopyComplaintUsesConversationalRepairLane() {
        let turn = "Too much writing. Get to the point."
        #expect(CoachChatTurnIntent.classify(turn) == .preference)
        #expect(CoachChatResponseKind.classify(turn) == .conversational)
    }

}
