import Foundation
import Testing
@preconcurrency import AVFoundation
@testable import Noum

@Suite("Timed practice media lifecycle")
struct TimedPracticeMediaLifecycleTests {
    @Test func promptSpeechPresentationStaysActiveForEitherPlaybackOwner() {
        #expect(!TimedPromptSpeechPresentation.isActive(
            local: false,
            cloud: false
        ))
        #expect(TimedPromptSpeechPresentation.isActive(
            local: true,
            cloud: false
        ))
        #expect(TimedPromptSpeechPresentation.isActive(
            local: false,
            cloud: true
        ))
        #expect(TimedPromptSpeechPresentation.isActive(
            local: true,
            cloud: true
        ))
    }

    @Test func promptPlaybackOutcomeAllowsFallbackOnlyForAvailabilityFailure() {
        #expect(IMMessagePromptPlaybackOutcome.started.startedCloudPlayback)
        #expect(!IMMessagePromptPlaybackOutcome.unavailable.startedCloudPlayback)
        #expect(!IMMessagePromptPlaybackOutcome.superseded.startedCloudPlayback)
        #expect(!IMMessagePromptPlaybackOutcome.started.shouldUseLocalFallback)
        #expect(IMMessagePromptPlaybackOutcome.unavailable.shouldUseLocalFallback)
        #expect(!IMMessagePromptPlaybackOutcome.superseded.shouldUseLocalFallback)
    }

    @Test func onlyNewestPromptAndSpeechGenerationsMayPublish() {
        let oldPromptGeneration = UUID()
        let currentPromptGeneration = UUID()
        #expect(!TimedPracticePromptLoadPolicy.accepts(
            completedGeneration: oldPromptGeneration,
            currentGeneration: currentPromptGeneration,
            isCancelled: false
        ))
        #expect(TimedPracticePromptLoadPolicy.accepts(
            completedGeneration: currentPromptGeneration,
            currentGeneration: currentPromptGeneration,
            isCancelled: false
        ))
        #expect(!TimedPracticePromptLoadPolicy.accepts(
            completedGeneration: currentPromptGeneration,
            currentGeneration: currentPromptGeneration,
            isCancelled: true
        ))

        let oldSpeechRequest = UUID()
        let currentSpeechRequest = UUID()
        #expect(!TimedPromptSpeechRequestPolicy.isCurrent(
            oldSpeechRequest,
            currentRequestID: currentSpeechRequest
        ))
        #expect(TimedPromptSpeechRequestPolicy.isCurrent(
            currentSpeechRequest,
            currentRequestID: currentSpeechRequest
        ))
        #expect(!TimedPromptSpeechRequestPolicy.isCurrent(
            currentSpeechRequest,
            currentRequestID: nil
        ))
    }

    @MainActor
    @Test func ttsDelegateKeepsCallbacksBoundToTheirUtterance() async {
        let delegate = TTSDelegate()
        let synthesizer = AVSpeechSynthesizer()
        let first = AVSpeechUtterance(string: "first")
        let replacement = AVSpeechUtterance(string: "replacement")
        var callbacks: [String] = []

        delegate.track(
            first,
            onFinish: { callbacks.append("first-finish") },
            onCancel: { callbacks.append("first-cancel") }
        )
        delegate.speechSynthesizer(synthesizer, didCancel: first)
        delegate.track(
            replacement,
            onFinish: { callbacks.append("replacement-finish") },
            onCancel: { callbacks.append("replacement-cancel") }
        )
        await drainMainQueue()
        #expect(callbacks == ["first-cancel"])

        delegate.speechSynthesizer(synthesizer, didCancel: first)
        await drainMainQueue()
        #expect(callbacks == ["first-cancel"])

        delegate.speechSynthesizer(synthesizer, didFinish: replacement)
        await drainMainQueue()
        #expect(callbacks == ["first-cancel", "replacement-finish"])
    }

    @Test func cancelledLaunchRejectsPromptThatResumesLate() async {
        let provider = SuspendedPromptProvider()
        let launch = Task {
            await TimedPracticeLaunchContinuation.resolvePrompt {
                await provider.load()
            }
        }

        await provider.waitUntilLoadStarts()
        launch.cancel()
        await provider.resume(returning: "A stale prompt")

        let result = await launch.value
        #expect(result == nil)
    }

    @Test func supersededCameraPreparationDoesNotDisableNewerVideoIntent() {
        #expect(VideoPreparationOutcome.ready.isReady)
        #expect(!VideoPreparationOutcome.ready.shouldDisableRequestedVideo)
        #expect(!VideoPreparationOutcome.superseded.isReady)
        #expect(!VideoPreparationOutcome.superseded.shouldDisableRequestedVideo)
        #expect(
            VideoPreparationOutcome.failed("Camera unavailable")
                .shouldDisableRequestedVideo
        )
    }

    @Test func recordingCompletionPublishesOnlyTheCurrentNonDiscardedURL() {
        let expected = URL(fileURLWithPath: "/tmp/current.mov")
        let stale = URL(fileURLWithPath: "/tmp/stale.mov")

        #expect(VideoRecordingCompletionDisposition.resolve(
            expectedURL: expected,
            outputURL: expected,
            discardRequested: false
        ) == .publish)
        #expect(VideoRecordingCompletionDisposition.resolve(
            expectedURL: expected,
            outputURL: expected,
            discardRequested: true
        ) == .discard)
        #expect(VideoRecordingCompletionDisposition.resolve(
            expectedURL: expected,
            outputURL: stale,
            discardRequested: false
        ) == .discard)
        #expect(VideoRecordingCompletionDisposition.resolve(
            expectedURL: nil,
            outputURL: stale,
            discardRequested: false
        ) == .discard)
    }

    @Test func timedPracticeOwnsPrewarmAndSurfacesAdaptiveCameraFailure() throws {
        let source = try timedPracticeSource()
        let prewarm = try sourceSlice(
            in: source,
            from: "    private func prewarmTTS() {",
            to: "    private func cancelTTSPrewarm() -> Bool {"
        )
        let stopSpeech = try sourceSlice(
            in: source,
            from: "    private func stopPromptSpeech() {",
            to: "    // MARK: - Navigation"
        )

        #expect(source.contains(
            "@State private var ttsPrewarmTask: Task<Void, Never>?"
        ))
        #expect(prewarm.contains(
            "guard !ttsReady, ttsPrewarmTask == nil else { return }"
        ))
        #expect(prewarm.contains("guard !Task.isCancelled,"))
        #expect(prewarm.contains(
            "guard ttsPrewarmGeneration == generation else"
        ))
        #expect(stopSpeech.contains("cancelTTSPrewarm()"))

        #expect(source.contains(
            "TimedCameraStatus(message: recordingError)"
        ))
        #expect(source.contains(".safeAreaInset(edge: .top"))
        #expect(source.contains(
            ".accessibilityIdentifier(\"timedPractice.videoStatus\")"
        ))
        #expect(!source.contains(
            "FocusedPracticeErrorStatus(message: recordingError)"
        ))

        let preparationCallCount = source.components(
            separatedBy: "await videoManager.prepareSession()"
        ).count - 1
        let failureOnlyDisableCount = source.components(
            separatedBy: "outcome.shouldDisableRequestedVideo"
        ).count - 1
        #expect(preparationCallCount == 4)
        #expect(failureOnlyDisableCount == 3)
        #expect(source.contains(
            "preparationOutcome.shouldDisableRequestedVideo"
        ))
        #expect(!source.contains("if !prepared"))
    }

    @Test func managerCoalescesPreparationAndOwnsDiscardThroughDelegate() throws {
        let source = try repositorySource(at: "VideoRecordingManager.swift")
        let prepare = try sourceSlice(
            in: source,
            from: "    func prepareSession() async -> VideoPreparationOutcome {",
            to: "    // MARK: - Camera Flip"
        )
        let cleanup = try sourceSlice(
            in: source,
            from: "    func cleanup() {",
            to: "    // MARK: - Camera Preview Layer"
        )
        let delegate = try sourceSlice(
            in: source,
            from: "extension VideoRecordingManager: AVCaptureFileOutputRecordingDelegate {",
            to: "// MARK: - Camera Preview (UIViewRepresentable)"
        )

        #expect(prepare.contains("if let preparationTask"))
        #expect(prepare.contains("return await preparationTask.value"))
        #expect(prepare.contains("return .superseded"))
        #expect(cleanup.contains(
            "discardedRecordingURLs.insert(pendingRecordingURL)"
        ))
        #expect(delegate.contains(
            "discardedRecordingURLs.remove(outputFileURL)"
        ))
        #expect(delegate.contains(
            "try? FileManager.default.removeItem(at: outputFileURL)"
        ))
    }

    @Test func timedPromptLifecycleSeamsAreWiredIntoProductionPaths() throws {
        let timedSource = try timedPracticeSource()
        let beginSession = try sourceSlice(
            in: timedSource,
            from: "    private func beginSession() {",
            to: "    private func startThinkingCountdown("
        )
        let promptSpeech = try sourceSlice(
            in: timedSource,
            from: "    private func speakPromptAloud() {",
            to: "    /// Prewarm TTS engine"
        )
        let themeSelection = try sourceSlice(
            in: timedSource,
            from: "    private func setPromptTheme(",
            to: "    private func animateSetupChange("
        )
        let supportSource = try repositorySource(at: "Noum/PracticeSupport.swift")
        let speakPrompt = try sourceSlice(
            in: supportSource,
            from: "    func speakPrompt(_ text: String)",
            to: "    private func playPrompt("
        )
        let cloudPrompt = try sourceSlice(
            in: supportSource,
            from: "    private func playPrompt(",
            to: "    func stop() {"
        )

        #expect(beginSession.contains(
            "TimedPracticeLaunchContinuation.resolvePrompt"
        ))
        #expect(beginSession.contains("launchPromptGeneration"))
        #expect(timedSource.contains("setupPromptGeneration"))
        #expect(timedSource.contains("promptSpeechRequestID"))
        #expect(themeSelection.contains("invalidatePromptResolution()"))
        #expect(timedSource.contains(
            "@StateObject private var promptSpeaker = IMMessageSpeaker.shared"
        ))
        #expect(promptSpeech.contains("isPromptSpeechActive"))
        #expect(promptSpeech.contains(
            "isPromptRequestOrLocalPlaybackActive = false"
        ))
        #expect(promptSpeech.contains(
            "TimedPromptSpeechRequestPolicy.isCurrent"
        ))
        #expect(promptSpeech.contains("case .superseded:"))
        #expect(speakPrompt.components(
            separatedBy: "let generation = currentGeneration"
        ).count - 1 == 1)
        #expect(speakPrompt.contains("generation: generation"))
        #expect(speakPrompt.contains("return .superseded"))
        #expect(cloudPrompt.contains(
            "playPromptWithOpenAI(text, generation: generation)"
        ))
        #expect(cloudPrompt.contains(
            "guard generation == currentGeneration else { return false }"
        ))
    }

    private func timedPracticeSource() throws -> String {
        try repositorySource(at: "Noum/TimedPracticeView.swift")
    }

    private func repositorySource(at relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
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

    @MainActor
    private func drainMainQueue() async {
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}

private actor SuspendedPromptProvider {
    private var continuation: CheckedContinuation<String, Never>?

    func load() async -> String {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilLoadStarts() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func resume(returning prompt: String) {
        continuation?.resume(returning: prompt)
        continuation = nil
    }
}
