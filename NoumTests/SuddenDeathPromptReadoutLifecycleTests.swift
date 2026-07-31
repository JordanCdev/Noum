import Foundation
import Testing
@testable import Noum

@Suite("Sudden Death prompt readout lifecycle")
struct SuddenDeathPromptReadoutLifecycleTests {
    @Test func onlyTheExactPromptRoundAndRequestRetainAuthority() {
        let current = SuddenDeathPromptSpeechRequest(
            id: UUID(),
            round: 3,
            prompt: "Tell me what changed."
        )
        let replacement = SuddenDeathPromptSpeechRequest(
            id: UUID(),
            round: current.round,
            prompt: current.prompt
        )

        #expect(SuddenDeathPromptReadoutPolicy.isCurrent(
            current,
            currentRequest: current,
            activeRound: 3,
            currentPrompt: current.prompt,
            isCancelled: false
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.isCurrent(
            current,
            currentRequest: replacement,
            activeRound: 3,
            currentPrompt: current.prompt,
            isCancelled: false
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.isCurrent(
            current,
            currentRequest: current,
            activeRound: 4,
            currentPrompt: current.prompt,
            isCancelled: false
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.isCurrent(
            current,
            currentRequest: current,
            activeRound: 3,
            currentPrompt: "A replacement prompt",
            isCancelled: false
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.isCurrent(
            current,
            currentRequest: current,
            activeRound: 3,
            currentPrompt: current.prompt,
            isCancelled: true
        ))
    }

    @Test func playbackOutcomesChooseOneTerminalPath() {
        #expect(
            SuddenDeathPromptReadoutPolicy.action(for: .started)
                == .awaitCloudCompletion
        )
        #expect(
            SuddenDeathPromptReadoutPolicy.action(for: .unavailable)
                == .useLocalFallback
        )
        #expect(
            SuddenDeathPromptReadoutPolicy.action(for: .superseded)
                == .completeWithoutFallback
        )
    }

    @Test func explicitStopResumesOnlyItsExactPendingNpcRound() {
        #expect(SuddenDeathPromptReadoutPolicy.shouldResumePendingRound(
            requestRound: 2,
            pendingRound: 2,
            activeRound: 2,
            resumeRequested: true
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.shouldResumePendingRound(
            requestRound: 2,
            pendingRound: 2,
            activeRound: 3,
            resumeRequested: true
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.shouldResumePendingRound(
            requestRound: 2,
            pendingRound: 3,
            activeRound: 2,
            resumeRequested: true
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.shouldResumePendingRound(
            requestRound: 2,
            pendingRound: 2,
            activeRound: 2,
            resumeRequested: false
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.shouldResumePendingRound(
            requestRound: nil,
            pendingRound: 2,
            activeRound: 2,
            resumeRequested: true
        ))
    }

    @Test func recorderHandoffRequiresTheExactPendingNpcRound() {
        #expect(SuddenDeathPromptReadoutPolicy.authorizesRecorderHandoff(
            expectedRound: 5,
            pendingRound: 5,
            activeRound: 5
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.authorizesRecorderHandoff(
            expectedRound: 5,
            pendingRound: nil,
            activeRound: 5
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.authorizesRecorderHandoff(
            expectedRound: 5,
            pendingRound: 4,
            activeRound: 5
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.authorizesRecorderHandoff(
            expectedRound: 5,
            pendingRound: 5,
            activeRound: nil
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.authorizesRecorderHandoff(
            expectedRound: 5,
            pendingRound: 5,
            activeRound: 6
        ))
    }

    @Test func recorderHandoffGenerationRejectsStaleAndCancelledTasks() {
        let currentGeneration = UUID()
        let staleGeneration = UUID()

        #expect(SuddenDeathPromptReadoutPolicy.isCurrentRecorderHandoff(
            generation: currentGeneration,
            currentGeneration: currentGeneration,
            expectedRound: 5,
            pendingRound: 5,
            activeRound: 5,
            isCancelled: false
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.isCurrentRecorderHandoff(
            generation: staleGeneration,
            currentGeneration: currentGeneration,
            expectedRound: 5,
            pendingRound: 5,
            activeRound: 5,
            isCancelled: false
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.isCurrentRecorderHandoff(
            generation: currentGeneration,
            currentGeneration: currentGeneration,
            expectedRound: 5,
            pendingRound: 5,
            activeRound: 5,
            isCancelled: true
        ))
        #expect(!SuddenDeathPromptReadoutPolicy.isCurrentRecorderHandoff(
            generation: currentGeneration,
            currentGeneration: currentGeneration,
            expectedRound: 5,
            pendingRound: 5,
            activeRound: 6,
            isCancelled: false
        ))
    }

    @Test func productionPathOwnsCancellationAndRealPlaybackCompletion() throws {
        let source = try suddenDeathSource()
        let readout = try sourceSlice(
            in: source,
            from: "    private func speakCurrentPrompt(force:",
            to: "    /// Stop any in-flight TTS + cloud audio."
        )
        let stop = try sourceSlice(
            in: source,
            from: "    private func stopPromptReadout(resumePendingRound:",
            to: "    #else"
        )
        let recorderHandoff = try sourceSlice(
            in: source,
            from: "    private func prepareRecorderThenBeginUserWaiting(",
            to: "    private var canPresentPressureResult:"
        )

        #expect(source.contains(
            "@State private var promptReadoutTask: Task<Void, Never>?"
        ))
        #expect(source.contains(
            "@State private var promptSpeechRequest: SuddenDeathPromptSpeechRequest?"
        ))
        #expect(source.contains(
            "@State private var recorderPreparationTask: Task<Void, Never>?"
        ))
        #expect(source.contains(
            "@State private var recorderPreparationGeneration: UUID?"
        ))
        #expect(source.contains(
            "@State private var ownsPromptTTSAudioSession = false"
        ))
        #expect(source.contains(
            "@StateObject private var promptSpeaker = IMMessageSpeaker.shared"
        ))
        #expect(readout.contains("promptReadoutTask = Task { @MainActor in"))
        #expect(readout.contains("while promptSpeaker.isSpeaking"))
        #expect(readout.contains("promptRequestIsCurrent("))
        #expect(!readout.contains("estimatedSeconds"))
        #expect(stop.contains("promptSpeechRequest = nil"))
        #expect(stop.contains("promptReadoutTask?.cancel()"))
        #expect(stop.contains("ttsDelegate.clearTracking()"))
        #expect(stop.contains(
            "if shouldDeactivateLocalAudio, !speechVM.isRecording"
        ))
        #expect(stop.contains(
            "resumeRequested: resumePendingRound"
        ))
        #expect(source.contains(
            "stopPromptReadout(resumePendingRound: true)"
        ))
        #expect(recorderHandoff.contains(
            "recorderPreparationGeneration = generation"
        ))
        #expect(recorderHandoff.contains(
            "if recorderPreparationGeneration == generation"
        ))
        #expect(
            recorderHandoff.components(
                separatedBy: "recorderPreparationIsCurrent("
            ).count - 1 >= 5
        )
        #expect(recorderHandoff.contains(
            "recorderPreparationTask?.cancel()"
        ))
        #expect(source.contains("private let ttsDelegate = TTSDelegate()"))
    }

    private func suddenDeathSource() throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Noum/SuddenDeathPracticeView.swift"
            ),
            encoding: .utf8
        )
    }

    private func sourceSlice(
        in source: String,
        from startNeedle: String,
        to endNeedle: String
    ) throws -> String {
        let start = try #require(source.range(of: startNeedle))
        let end = try #require(source.range(
            of: endNeedle,
            range: start.upperBound..<source.endIndex
        ))
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
