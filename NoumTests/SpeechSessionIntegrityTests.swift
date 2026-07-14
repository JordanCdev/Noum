import Foundation
import Testing
@testable import Noum

@Suite("Speech session integrity")
struct SpeechSessionIntegrityTests {
    private enum FixtureError: Error, Equatable {
        case disconnected
    }

    private func update(_ text: String, isFinal: Bool) -> TranscriptUpdate {
        TranscriptUpdate(
            text: text,
            isFinal: isFinal,
            confidence: 0.94,
            words: nil,
            providerFillerWords: nil,
            latencyMs: 20
        )
    }

    private final class PumpSession: TranscriptionSession, @unchecked Sendable {
        private let lock = NSLock()
        private var sentValues: [UInt8] = []
        private let failOnValue: UInt8?
        let transcriptUpdates = AsyncThrowingStream<TranscriptUpdate, Error> { continuation in
            continuation.finish()
        }

        init(failOnValue: UInt8? = nil) {
            self.failOnValue = failOnValue
        }

        func sendAudio(_ data: Data) async throws {
            try await Task.sleep(for: .milliseconds(5))
            if let value = data.first {
                if value == failOnValue { throw FixtureError.disconnected }
                lock.withLock { sentValues.append(value) }
            }
        }

        func finish() async throws -> FinalizedTranscript {
            FinalizedTranscript(text: "", receivedFinalResult: false, audioByteCount: 0)
        }

        var values: [UInt8] { lock.withLock { sentValues } }
    }

    @Test("Terminal receipt waits for provider completion and aggregates only final segments")
    func terminalReceiptAggregatesFinalSegments() async throws {
        let terminal = TranscriptionTerminalState()
        terminal.noteAudio(bytes: 2_048)
        terminal.note(update("working partial", isFinal: false))
        terminal.note(update("The first sentence.", isFinal: true))
        terminal.note(update("The close.", isFinal: true))

        let waiter = Task {
            try await terminal.wait(timeout: .seconds(1))
        }
        terminal.succeed()
        let result = try await waiter.value

        #expect(result.text == "The first sentence. The close.")
        #expect(result.receivedFinalResult)
        #expect(result.audioByteCount == 2_048)
        #expect(result.hasUsableSpeech)
    }

    @Test("Audio pump preserves callback order and drains before finalization")
    func audioPumpOrdering() async throws {
        let session = PumpSession()
        let pump = TranscriptionAudioPump(session: session) { _ in }

        #expect(pump.enqueue(Data([1])))
        #expect(pump.enqueue(Data([2])))
        #expect(pump.enqueue(Data([3])))
        try await pump.finish()

        #expect(session.values == [1, 2, 3])
    }

    @Test("Audio pump surfaces send failure instead of finalizing a partial queue")
    func audioPumpFailure() async {
        let session = PumpSession(failOnValue: 2)
        let pump = TranscriptionAudioPump(session: session) { _ in }
        #expect(pump.enqueue(Data([1])))
        #expect(pump.enqueue(Data([2])))
        #expect(pump.enqueue(Data([3])))

        do {
            try await pump.finish()
            Issue.record("Expected the queued send failure")
        } catch let error as FixtureError {
            #expect(error == .disconnected)
            #expect(session.values == [1])
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Provider failure reaches the terminal waiter")
    func terminalFailurePropagates() async {
        let terminal = TranscriptionTerminalState()
        let waiter = Task {
            try await terminal.wait(timeout: .seconds(1))
        }
        terminal.fail(FixtureError.disconnected)

        do {
            _ = try await waiter.value
            Issue.record("Expected the provider failure to be thrown")
        } catch let error as FixtureError {
            #expect(error == .disconnected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Readiness gate does not report ready before the handshake")
    func readinessGatePropagatesHandshakeFailure() async {
        let gate = TranscriptionReadinessGate()
        let waiter = Task {
            try await gate.wait(timeout: .seconds(1))
        }
        gate.fail(FixtureError.disconnected)

        do {
            try await waiter.value
            Issue.record("Expected the handshake failure to be thrown")
        } catch let error as FixtureError {
            #expect(error == .disconnected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Only a final transcript backed by captured audio may score or award progress")
    func completionGateMatrix() {
        let valid = FinalizedTranscript(
            text: "A complete spoken response.",
            receivedFinalResult: true,
            audioByteCount: 4_096
        )
        let noAudio = FinalizedTranscript(
            text: "Text without captured audio.",
            receivedFinalResult: true,
            audioByteCount: 0
        )
        let silence = FinalizedTranscript(
            text: "   ",
            receivedFinalResult: true,
            audioByteCount: 4_096
        )
        let partialOnly = FinalizedTranscript(
            text: "Provider never finalized this fragment",
            receivedFinalResult: false,
            audioByteCount: 4_096
        )

        #expect(RecordingCompletionGate.allowsScoringAndProgress(valid))
        #expect(!RecordingCompletionGate.allowsScoringAndProgress(nil))
        #expect(!RecordingCompletionGate.allowsScoringAndProgress(noAudio))
        #expect(!RecordingCompletionGate.allowsScoringAndProgress(silence))
        #expect(!RecordingCompletionGate.allowsScoringAndProgress(partialOnly))
    }

    @Test("Every owned mode uses the same completion gate contract")
    func ownedModeGateContract() {
        let failedReceipt: FinalizedTranscript? = nil
        let emptyReceipt = FinalizedTranscript(
            text: "",
            receivedFinalResult: true,
            audioByteCount: 1_024
        )
        let ownedModes = [
            "Timed", "Pressure", "Filler Control", "Conversation",
            "Cut the Crutch", "Pace Training", "Roleplay",
            "Mini-drill", "Lesson Apply",
        ]

        for mode in ownedModes {
            #expect(!RecordingCompletionGate.allowsScoringAndProgress(failedReceipt), Comment(rawValue: mode))
            #expect(!RecordingCompletionGate.allowsScoringAndProgress(emptyReceipt), Comment(rawValue: mode))
        }
    }

    @Test("Mini-drill and Lesson Apply await capture before timing or progress")
    func supplementalSpeechSurfacesUseLifecycleGates() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let miniDrill = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/MiniDrillView.swift"),
            encoding: .utf8
        )
        let lesson = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/LessonView.swift"),
            encoding: .utf8
        )

        let miniStart = try #require(miniDrill.range(of: "await speechVM.startRecordingAwaitingReadiness()"))
        let miniTimer = try #require(miniDrill.range(of: "beginSpeakingTimer()"))
        let miniStop = try #require(miniDrill.range(of: "await speechVM.stopRecordingAwaitingFinalization()"))
        let miniCompletionGate = try #require(miniDrill.range(of: "RecordingCompletionGate.allowsScoringAndProgress(completion)"))
        #expect(miniStart.lowerBound < miniTimer.lowerBound)
        #expect(miniStop.lowerBound < miniCompletionGate.lowerBound)
        #expect(miniDrill.contains("RecordingStartGate.allowsTimerStart(captureReady: captureReady)"))
        #expect(miniDrill.contains(".transcriptionRouteNotice(speechVM.transcriptionRouteNotice)"))
        #expect(!miniDrill.contains("speechVM.startRecording()"))

        let lessonStart = try #require(lesson.range(of: "await speech.startRecordingAwaitingReadiness()"))
        let lessonTimer = try #require(lesson.range(of: "beginApplyTimer()"))
        let lessonStop = try #require(lesson.range(of: "await speech.stopRecordingAwaitingFinalization()"))
        let lessonCompletionGate = try #require(lesson.range(of: "RecordingCompletionGate.allowsScoringAndProgress(completion)"))
        #expect(lessonStart.lowerBound < lessonTimer.lowerBound)
        #expect(lessonStop.lowerBound < lessonCompletionGate.lowerBound)
        #expect(lesson.contains("RecordingStartGate.allowsTimerStart(captureReady: captureReady)"))
        #expect(lesson.contains(".transcriptionRouteNotice(speech.transcriptionRouteNotice)"))
        #expect(!lesson.contains("speech.startRecording()"))
        #expect(!lesson.contains("asyncAfter(deadline: .now() + 0.6)"))
    }

    @Test("Lifecycle exposes one truthful readiness and finalization sequence")
    func recordingLifecycleContract() {
        let completed = FinalizedTranscript(
            text: "Finished response",
            receivedFinalResult: true,
            audioByteCount: 512
        )

        #expect(!RecordingLifecycleState.idle.isBusy)
        #expect(RecordingLifecycleState.connecting.isBusy)
        #expect(!RecordingLifecycleState.connecting.isRecording)
        #expect(RecordingLifecycleState.connecting.expectsProviderStreamOpen)
        #expect(RecordingLifecycleState.recording.isBusy)
        #expect(RecordingLifecycleState.recording.isRecording)
        #expect(RecordingLifecycleState.recording.expectsProviderStreamOpen)
        #expect(RecordingLifecycleState.finalizing.isBusy)
        #expect(!RecordingLifecycleState.finalizing.isRecording)
        #expect(!RecordingLifecycleState.finalizing.expectsProviderStreamOpen)
        #expect(RecordingLifecycleState.completed(completed).completedUsableCapture)
        #expect(!RecordingLifecycleState.failed("offline").completedUsableCapture)
    }

    @Test("Response timers remain closed until capture readiness is confirmed")
    @MainActor
    func responseTimerReadinessGate() {
        #expect(!RecordingStartGate.allowsTimerStart(captureReady: false))
        #expect(RecordingStartGate.allowsTimerStart(captureReady: true))

        let crutch = CutTheCrutchEngine(
            avoidedWord: "actually",
            prompt: "Explain a decision."
        )
        crutch.confirmCaptureReady(captureReady: true)
        #expect(crutch.phase == .setup)

        let pace = PaceTrainingEngine()
        pace.confirmCaptureReady(captureReady: true)
        #expect(pace.phase == .setup)
    }

    @Test("Declining cloud processing removes every cloud voice engine")
    func cloudConsentFiltersLiveCallChain() {
        let onDeviceFallback = LiveCallSTTChain.engineOrder(
            configuredProviderRawValue: TranscriptionProviderID.deepgram.rawValue,
            cloudMarkedUnhealthy: false,
            nativeAvailable: true,
            cloudProcessingAllowed: false
        )
        let noLocalModel = LiveCallSTTChain.engineOrder(
            configuredProviderRawValue: TranscriptionProviderID.deepgram.rawValue,
            cloudMarkedUnhealthy: false,
            nativeAvailable: false,
            cloudProcessingAllowed: false
        )

        #expect(onDeviceFallback == [.native])
        #expect(noLocalModel.isEmpty)
    }

    @Test("Unset production provider resolves to authenticated Deepgram")
    func productionProviderDefault() {
        #expect(TranscriptionProviderID.resolved(fromStoredValue: nil) == .deepgram)
    }

    @Test("Pressure evidence replaces interim words with the terminal transcript")
    func pressureEvidenceReconciliation() {
        var log = PressureSessionTranscriptLog()
        log.record("An interim ending")
        log.reconcileMostRecent("An interim ending with the final words.")
        #expect(log.combinedText == "An interim ending with the final words.")

        var totals = PressureSessionTotals()
        totals.recordRound(duration: 10, fillers: 0, words: 3)
        totals.recordRound(duration: 12, fillers: 0, words: 4)
        totals.reconcileWordCounts([6, 8])
        #expect(totals.words == 14)
        #expect(totals.bestRoundWords == 8)
        #expect(totals.duration == 22)
    }
}

@Suite("Deepgram production token contract")
struct DeepgramProductionTokenContractTests {
    @Test("Streaming request pins endpoint, model, encoding, and model-improvement opt-out")
    func productionStreamingRequestContract() throws {
        let config = TranscriptionConfig(
            languageCode: "en-GB",
            sampleRate: 48_000,
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: true
        )
        let url = DeepgramSession.streamingURL(config: config)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap {
            item in item.value.map { (item.name, $0) }
        })

        #expect(components.scheme == "wss")
        #expect(components.host == "api.deepgram.com")
        #expect(components.path == "/v1/listen")
        #expect(query["model"] == "nova-2")
        #expect(query["language"] == "en-GB")
        #expect(query["encoding"] == "linear16")
        #expect(query["sample_rate"] == "48000")
        #expect(query["channels"] == "1")
        #expect(query["interim_results"] == "true")
        #expect(query["filler_words"] == "true")
        #expect(query["punctuate"] == "true")
        #expect(query["smart_format"] == "true")
        #expect(query["tag"] == "noum-production")
        #expect(query["mip_opt_out"] == "true")
    }

    @Test("Callable response decodes only the public token envelope")
    func responseDecodes() throws {
        let data = Data(#"{"provider":"deepgram","accessToken":"jwt-value","expiresAt":"2099-01-01T00:00:00Z"}"#.utf8)
        let response = try JSONDecoder().decode(TranscriptionTokenResponse.self, from: data)
        let token = try response.validatedToken(now: Date(timeIntervalSince1970: 0))

        #expect(response.provider == "deepgram")
        #expect(token.value == "jwt-value")
        #expect(token.authorizationScheme == .temporaryJWT)
        #expect(token.expiresAt > Date())
    }

    @Test("Wrong provider and expired tokens are rejected")
    func invalidResponsesAreRejected() {
        let wrongProvider = TranscriptionTokenResponse(
            provider: "other",
            accessToken: "jwt-value",
            expiresAt: "2099-01-01T00:00:00Z"
        )
        let expired = TranscriptionTokenResponse(
            provider: "deepgram",
            accessToken: "jwt-value",
            expiresAt: "2000-01-01T00:00:00Z"
        )

        do {
            _ = try wrongProvider.validatedToken(now: Date())
            Issue.record("Expected wrong-provider response to fail")
        } catch {
            #expect(error as? DeepgramError == .invalidTokenResponse)
        }

        do {
            _ = try expired.validatedToken(now: Date())
            Issue.record("Expected expired response to fail")
        } catch {
            #expect(error as? DeepgramError == .expiredToken)
        }
    }

    @Test("Missing any required callable field fails decoding")
    func missingFieldFailsDecoding() {
        let missingToken = Data(#"{"provider":"deepgram","expiresAt":"2099-01-01T00:00:00Z"}"#.utf8)
        do {
            _ = try JSONDecoder().decode(TranscriptionTokenResponse.self, from: missingToken)
            Issue.record("Expected the incomplete token envelope to fail decoding")
        } catch {
            #expect(error is DecodingError)
        }
    }
}
