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

    @Test("Capture duration freezes at microphone stop, not provider completion")
    func captureDurationFreezesAtStop() throws {
        var clock = SpeechCaptureClock()
        clock.start(at: 100)
        clock.stop(at: 130)

        #expect(clock.duration(at: 135) == 30)
        #expect(clock.duration(at: 9_000) == 30)
        #expect(clock.stoppedDuration == 30)
    }

    @Test("Capture duration fails closed for invalid clock evidence")
    func captureDurationRejectsInvalidEvidence() {
        #expect(SpeechCaptureClock.elapsed(startedAtUptime: nil, stoppedAtUptime: 10) == nil)
        #expect(SpeechCaptureClock.elapsed(startedAtUptime: 10, stoppedAtUptime: nil) == nil)
        #expect(SpeechCaptureClock.elapsed(startedAtUptime: 10, stoppedAtUptime: 9) == nil)
        #expect(SpeechCaptureClock.elapsed(startedAtUptime: .infinity, stoppedAtUptime: 10) == nil)
        #expect(SpeechCaptureClock.elapsed(startedAtUptime: 10, stoppedAtUptime: .nan) == nil)
    }

    @Test("Capture duration reset prevents reuse by the next rep")
    func captureDurationResetPreventsReuse() {
        var clock = SpeechCaptureClock()
        clock.start(at: 10)
        clock.stop(at: 40)
        #expect(clock.duration(at: 100) == 30)

        clock.reset()
        #expect(clock.duration(at: 100) == 0)

        clock.start(at: 200)
        #expect(clock.duration(at: 212) == 12)
        clock.stop(at: 215)
        #expect(clock.duration(at: 999) == 15)
    }

    @Test("Corrected capture duration advances the comparison epoch")
    func captureDurationAdvancesComparisonEpoch() {
        #expect(PracticeSession.currentComparisonMetricSchemaVersion == 2)

        let historicalLatencyMixedRow = PracticeSession(
            transcript: "This historical answer has enough words to meet the normal comparison evidence floor safely.",
            fillerWordCount: 1,
            duration: 30,
            date: Date(),
            mode: .timed,
            transcriptConfidence: 0.9,
            comparisonMetricSchemaVersion: 1
        )
        #expect(FillerBurden.quantityQualified(historicalLatencyMixedRow) == nil)
    }

    @Test("Persistence and quality metrics share the pre-finalization capture boundary")
    func speechOwnerUsesOneCaptureBoundary() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SpeechRecognizerViewModel.swift"),
            encoding: .utf8
        )

        let stopSnapshot = try #require(source.range(
            of: "captureClock.stop(at: ProcessInfo.processInfo.systemUptime)"
        ))
        let providerFinish = try #require(source.range(
            of: "let providerResult = try await sessionToEnd.finish()"
        ))
        #expect(stopSnapshot.lowerBound < providerFinish.lowerBound)

        let sharedRead = "let duration = captureClock.duration(at: ProcessInfo.processInfo.systemUptime)"
        #expect(source.components(separatedBy: sharedRead).count - 1 == 3)
        #expect(!source.contains("Date().timeIntervalSince(sessionStart"))
    }

    @Test("Mini-drill trusts the shared capture receipt instead of a post-finalization clock")
    func miniDrillUsesSharedCaptureReceipt() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/MiniDrillView.swift"),
            encoding: .utf8
        )

        let outcomeStart = try #require(source.range(of: "private func completedOutcome"))
        let outcomeTail = source[outcomeStart.lowerBound...]
        let nextFunction = outcomeTail.range(of: "\n    private func", options: [], range: outcomeTail.index(after: outcomeTail.startIndex)..<outcomeTail.endIndex)
        let outcomeBody = nextFunction.map { outcomeTail[..<$0.lowerBound] } ?? outcomeTail[...]

        #expect(source.contains("captureDuration: speechVM.lastSessionDuration"))
        #expect(outcomeBody.contains("let duration = evidence.duration"))
        #expect(!outcomeBody.contains("Date().timeIntervalSince"))
        #expect(!outcomeBody.contains("max(speechVM.lastSessionDuration"))
    }

    @Test("Pressure rounds commit the same capture receipt after terminal reconciliation")
    func pressureRoundsUseSharedCaptureReceipt() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let view = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SuddenDeathPracticeView.swift"),
            encoding: .utf8
        )
        let engine = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/PressureTimerEngine.swift"),
            encoding: .utf8
        )

        #expect(view.contains("engine.userEndedTurn(captureDuration: speechVM.lastSessionDuration)"))
        #expect(view.contains("captureDuration: speechVM.lastSessionDuration"))
        #expect(engine.contains("duration: captureDuration"))
        #expect(!engine.contains("timeIntervalSince(roundStartDate"))
    }

    @Test("Baseline recompute and incremental updates reject the prior duration epoch")
    func baselineRejectsPriorDurationEpoch() {
        let transcript = "This complete practice answer contains more than twenty spoken words so it can qualify for a trustworthy current baseline measurement without relying on thin evidence."
        let current = PracticeSession(
            transcript: transcript,
            fillerWordCount: 1,
            duration: 30,
            date: Date(timeIntervalSince1970: 200),
            mode: .timed,
            transcriptConfidence: 0.9
        )
        let historical = PracticeSession(
            transcript: transcript,
            fillerWordCount: 9,
            duration: 90,
            date: Date(timeIntervalSince1970: 100),
            mode: .timed,
            transcriptConfidence: 0.9,
            comparisonMetricSchemaVersion: 1
        )

        let rebuilt = BaselineEngine.compute(from: [current, historical])
        #expect(rebuilt.usesCurrentComparisonMetrics)
        #expect(rebuilt.sessionCount == 2)
        #expect(rebuilt.qualifyingSessionCount == 1)
        #expect(rebuilt.durationTendency.value == 30)
        #expect(rebuilt.fillerRate.value == 2)

        let updated = BaselineEngine.update(rebuilt, with: historical)
        #expect(updated.sessionCount == 3)
        #expect(updated.qualifyingSessionCount == 1)
        #expect(updated.durationTendency == rebuilt.durationTendency)
        #expect(updated.fillerRate == rebuilt.fillerRate)
        #expect(BaselineEngine.updatePressureProfile(.empty, session: historical, pressure: .high) == .empty)
    }

    @Test("Legacy persisted baselines decode as requiring a recipe rebuild")
    func legacyBaselineRequiresRecipeRebuild() throws {
        let encoded = try JSONEncoder().encode(CommunicationBaseline.empty)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "comparisonMetricSchemaVersion")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let legacy = try JSONDecoder().decode(CommunicationBaseline.self, from: legacyData)
        #expect(legacy.comparisonMetricSchemaVersion == nil)
        #expect(!legacy.usesCurrentComparisonMetrics)
    }

    @Test("Pressure migration replays oldest to newest regardless of store order")
    func pressureMigrationUsesChronologicalReplay() {
        func session(id: String, date: TimeInterval, fillers: Int) -> PracticeSession {
            PracticeSession(
                id: UUID(uuidString: id)!,
                transcript: "This complete pressure answer contains more than twenty spoken words and provides enough evidence for a stable chronological profile replay test.",
                fillerWordCount: fillers,
                duration: 60,
                date: Date(timeIntervalSince1970: date),
                mode: .suddenDeath,
                transcriptConfidence: 0.9,
                pressureLevel: .high
            )
        }
        let oldest = session(
            id: "00000000-0000-4000-8000-000000000001",
            date: 100,
            fillers: 8
        )
        let middle = session(
            id: "00000000-0000-4000-8000-000000000002",
            date: 200,
            fillers: 4
        )
        let newest = session(
            id: "00000000-0000-4000-8000-000000000003",
            date: 300,
            fillers: 0
        )

        let fromStoreOrder = BaselineEngine.computePressureProfile(
            from: [newest, middle, oldest]
        )
        let fromChronologicalOrder = BaselineEngine.computePressureProfile(
            from: [oldest, middle, newest]
        )

        #expect(fromStoreOrder == fromChronologicalOrder)
        #expect(abs((fromStoreOrder.highFillerRate?.value ?? 0) - 5.76) < 0.000_001)
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
        let miniCompletionGate = try #require(miniDrill.range(of: "MiniDrillCompletionDisposition.resolve("))
        #expect(miniStart.lowerBound < miniTimer.lowerBound)
        #expect(miniStop.lowerBound < miniCompletionGate.lowerBound)
        #expect(miniDrill.contains("RecordingStartGate.allowsTimerStart(captureReady: captureReady)"))
        #expect(miniDrill.contains(".transcriptionRouteNotice(speechVM.transcriptionRouteNotice)"))
        #expect(!miniDrill.contains("speechVM.startRecording()"))

        let lessonStart = try #require(lesson.range(of: "await speech.startRecordingAwaitingReadiness()"))
        let lessonTimer = try #require(lesson.range(of: "beginApplyTimer()"))
        let lessonStop = try #require(lesson.range(of: "await speech.stopRecordingAwaitingFinalization()"))
        let lessonConsumption = try #require(lesson.range(of: "consumeApplyCompletion("))
        let lessonDisposition = try #require(lesson.range(of: "LessonApplyCompletionDisposition.resolve("))
        let lessonStepMutation = try #require(lesson.range(of: "stepResults.append(.apply("))
        let lessonOutcome = try #require(lesson.range(of: "applyEvidence: applyEvidence"))
        let lessonProgress = try #require(lesson.range(of: "lessonStore.apply(outcome: final)"))
        #expect(lessonStart.lowerBound < lessonTimer.lowerBound)
        #expect(lessonStop.lowerBound < lessonConsumption.lowerBound)
        #expect(lessonConsumption.lowerBound < lessonDisposition.lowerBound)
        #expect(lessonDisposition.lowerBound < lessonStepMutation.lowerBound)
        #expect(lessonStepMutation.lowerBound < lessonOutcome.lowerBound)
        #expect(lessonOutcome.lowerBound < lessonProgress.lowerBound)
        #expect(lesson.contains("RecordingStartGate.allowsTimerStart(captureReady: captureReady)"))
        #expect(lesson.contains("recorderDuration: speech.lastSessionDuration"))
        #expect(lesson.contains("guard let evidence,"))
        #expect(lesson.contains(".transcriptionRouteNotice(speech.transcriptionRouteNotice)"))
        #expect(!lesson.contains("speech.startRecording()"))
        #expect(!lesson.contains("asyncAfter(deadline: .now() + 0.6)"))
    }

    @Test("Mini-drill completion requires terminal speech and a quantity floor")
    func miniDrillCompletionDispositionMatrix() {
        func receipt(_ text: String, final: Bool = true, bytes: Int = 4_096) -> FinalizedTranscript {
            FinalizedTranscript(text: text, receivedFinalResult: final, audioByteCount: bytes)
        }

        #expect(MiniDrillCompletionDisposition.resolve(completion: nil, captureDuration: 10) == .unusableRecording)
        #expect(MiniDrillCompletionDisposition.resolve(completion: receipt("one two three", bytes: 0), captureDuration: 10) == .unusableRecording)
        #expect(MiniDrillCompletionDisposition.resolve(completion: receipt("one two three", final: false), captureDuration: 10) == .unusableRecording)
        #expect(MiniDrillCompletionDisposition.resolve(completion: receipt("   "), captureDuration: 10) == .unusableRecording)
        #expect(MiniDrillCompletionDisposition.resolve(completion: receipt("one"), captureDuration: 10) == .insufficientSpeech)
        #expect(MiniDrillCompletionDisposition.resolve(completion: receipt("one two"), captureDuration: 10) == .insufficientSpeech)
        #expect(MiniDrillCompletionDisposition.resolve(completion: receipt("one two three"), captureDuration: 2.99) == .insufficientSpeech)
        #expect(MiniDrillCompletionDisposition.resolve(completion: receipt("one two three"), captureDuration: .nan) == .insufficientSpeech)

        let eligible = MiniDrillCompletionDisposition.resolve(
            completion: receipt("one, two; three!"),
            captureDuration: 3
        )
        guard case .eligible(let evidence) = eligible else {
            Issue.record("Expected boundary evidence to be eligible")
            return
        }
        #expect(evidence.transcript == "one, two; three!")
        #expect(evidence.wordCount == 3)
        #expect(evidence.duration == 3)
    }

    #if DEBUG
    @Test("Rendered mini-drill fixtures enter the production disposition")
    func miniDrillCompletionUIFixtureContract() throws {
        #expect(MiniDrillCompletionUITestFixture.requested(arguments: []) == nil)
        #expect(
            MiniDrillCompletionUITestFixture.requested(arguments: [
                "UI_TESTING_MINI_DRILL_COMPLETION_FIXTURE", "eligible",
            ]) == nil
        )

        let insufficient = try #require(
            MiniDrillCompletionUITestFixture.requested(arguments: [
                "UI_TESTING",
                "UI_TESTING_MINI_DRILL_COMPLETION_FIXTURE", "insufficient",
            ])
        )
        #expect(
            MiniDrillCompletionDisposition.resolve(
                completion: insufficient.completion,
                captureDuration: insufficient.captureDuration
            ) == .insufficientSpeech
        )

        let eligible = try #require(
            MiniDrillCompletionUITestFixture.requested(arguments: [
                "UI_TESTING",
                "UI_TESTING_MINI_DRILL_COMPLETION_FIXTURE", "eligible",
            ])
        )
        #expect(MiniDrillCompletionUITestFixture.variationID == "filler.silentTransitions")
        let disposition = MiniDrillCompletionDisposition.resolve(
            completion: eligible.completion,
            captureDuration: eligible.captureDuration
        )
        guard case .eligible(let evidence) = disposition else {
            Issue.record("Expected the rendered eligible fixture to pass the production gate")
            return
        }
        #expect(evidence.wordCount == 12)
        #expect(evidence.duration == 12)
    }
    #endif

    @Test("PREP completion cannot succeed from four taps without 28 spoken words")
    func prepStackQuantityFloor() {
        #expect(PREPStackEvaluation.closeStrength(stepsCompleted: 4, wordCount: 0) == 0)
        #expect(PREPStackEvaluation.closeStrength(stepsCompleted: 4, wordCount: 27) < 1)
        #expect(!PREPStackEvaluation.succeeded(stepsCompleted: 4, wordCount: 27, duration: 20))
        #expect(!PREPStackEvaluation.succeeded(stepsCompleted: 4, wordCount: 28, duration: 19.99))
        #expect(PREPStackEvaluation.succeeded(stepsCompleted: 4, wordCount: 28, duration: 20))
        #expect(PREPStackEvaluation.closeStrength(stepsCompleted: 4, wordCount: 28) == 1)
    }

    @Test("Every mini-drill route awaits capture readiness and terminal evidence")
    func allMiniDrillRoutesUseTerminalLifecycle() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "Noum/MiniDrillView.swift",
            "BeatTheBrakeView.swift",
            "LandThePauseView.swift",
            "PREPStackView.swift",
        ]

        for path in paths {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            let start = try #require(source.range(of: "await speechVM.startRecordingAwaitingReadiness()"), Comment(rawValue: path))
            let timer = try #require(source.range(of: "RecordingStartGate.allowsTimerStart(captureReady: captureReady)"), Comment(rawValue: path))
            let stop = try #require(source.range(of: "await speechVM.stopRecordingAwaitingFinalization()"), Comment(rawValue: path))
            let disposition = try #require(source.range(of: "MiniDrillCompletionDisposition.resolve("), Comment(rawValue: path))
            let outcome = try #require(
                source.range(
                    of: "MiniDrillOutcome(",
                    range: disposition.lowerBound..<source.endIndex
                ),
                Comment(rawValue: path)
            )
            #expect(start.lowerBound < timer.lowerBound, Comment(rawValue: path))
            #expect(stop.lowerBound < disposition.lowerBound, Comment(rawValue: path))
            #expect(disposition.lowerBound < outcome.lowerBound, Comment(rawValue: path))
            #expect(source.contains(".transcriptionRouteNotice(speechVM.transcriptionRouteNotice)"), Comment(rawValue: path))
            #expect(!source.contains("speechVM.startRecording()"), Comment(rawValue: path))
            #expect(!source.contains("speechVM.stopRecording()"), Comment(rawValue: path))
            #expect(!source.contains("max(speechVM.lastSessionDuration"), Comment(rawValue: path))
            #expect(!source.contains("milliseconds(800)"), Comment(rawValue: path))
        }
    }

    @Test("Summary durably inserts a verified mini-drill receipt before every reward effect")
    func summaryGuardsMiniDrillRewardSink() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let summary = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SummaryView.swift"),
            encoding: .utf8
        )
        let functionStart = try #require(
            summary.range(of: "private func handleDrillComplete(_ outcome: MiniDrillOutcome)")
        )
        let tail = summary[functionStart.lowerBound...]
        let nextFunction = tail.range(
            of: "\n    private func",
            options: [],
            range: tail.index(after: tail.startIndex)..<tail.endIndex
        )
        let body = String(nextFunction.map { tail[..<$0.lowerBound] } ?? tail[...])

        let eligibility = try #require(body.range(of: "outcome.isProgressEligible"))
        let parentSession = try #require(body.range(of: "let parentSession = currentStoredSession"))
        let processGuard = try #require(
            body.range(of: "committedMiniDrillOutcomeIDs.insert(outcome.id).inserted")
        )
        let prospectiveStreak = try #require(body.range(of: "drillHistory.streakAfterRecording("))
        let exactXP = try #require(
            body.range(of: "DrillXPEngine.breakdown(\n            outcome: outcome,\n            streak: awardedStreak")
        )
        let verifiedReceipt = try #require(
            body.range(of: "DrillHistoryStore.Entry.verified(")
        )
        let durableInsertion = try #require(
            body.range(of: "guard drillHistory.record(receipt) else { return }")
        )
        let profileXP = try #require(
            body.range(of: "ProfileManager.shared.addXP(xpBreakdown.total)")
        )
        let reward = try #require(body.range(of: "RewardEngine.shared.evaluateDrill("))
        let baseline = try #require(
            body.range(of: "BaselineStore.shared.recordMiniDrillOutcome(")
        )
        let resultPresentation = try #require(body.range(of: "miniDrillOutcome = outcome"))

        #expect(eligibility.lowerBound < parentSession.lowerBound)
        #expect(parentSession.lowerBound < processGuard.lowerBound)
        #expect(processGuard.lowerBound < prospectiveStreak.lowerBound)
        #expect(prospectiveStreak.lowerBound < exactXP.lowerBound)
        #expect(exactXP.lowerBound < verifiedReceipt.lowerBound)
        #expect(verifiedReceipt.lowerBound < durableInsertion.lowerBound)
        #expect(durableInsertion.lowerBound < profileXP.lowerBound)
        #expect(durableInsertion.lowerBound < reward.lowerBound)
        #expect(durableInsertion.lowerBound < baseline.lowerBound)
        #expect(durableInsertion.lowerBound < resultPresentation.lowerBound)

        #expect(body.contains("outcomeID: outcome.id"))
        #expect(body.contains("parentSessionId: parentSession.id"))
        #expect(body.contains("terminalWordCount: outcome.wordCount"))
        #expect(body.contains("recorderDuration: outcome.duration"))
        #expect(body.contains("awardedXP: xpBreakdown.total"))
        #expect(body.contains("streak: awardedStreak"))
        #expect(!body.contains("sessionId: UUID()"))
        #expect(!body.contains("DrillXPEngine.breakdown(outcome: outcome)"))
    }

    @Test("Every speech surface explains a cloud-to-device startup fallback")
    func everySpeechSurfacePresentsStartupFallbackNotice() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let surfaces = [
            ("Timed Practice", "Noum/TimedPracticeView.swift", "speechVM"),
            ("Pressure Drill", "Noum/SuddenDeathPracticeView.swift", "speechVM"),
            ("Filler Control", "Noum/AhCounterView.swift", "speechVM"),
            ("Conversation", "Noum/IMPracticeView.swift", "speechVM"),
            ("Cut the Crutch", "Noum/CutTheCrutchView.swift", "speechVM"),
            ("Pace Training", "Noum/PaceTrainingView.swift", "speechVM"),
            ("Roleplay", "Noum/RoleplayView.swift", "speechVM"),
            ("Mini-drill", "Noum/MiniDrillView.swift", "speechVM"),
            ("Lesson Apply", "Noum/LessonView.swift", "speech"),
        ]

        for (name, path, recognizer) in surfaces {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            #expect(
                source.contains(".transcriptionRouteNotice(\(recognizer).transcriptionRouteNotice)"),
                Comment(rawValue: name)
            )
        }
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
