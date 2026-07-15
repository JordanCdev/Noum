import Foundation
import Testing
@testable import Noum

@Suite("On-device transcription fallback")
struct LocalSpeechProviderTests {
    @Test func persistedLocalProviderResolvesCanonically() {
        #expect(TranscriptionProviderID.resolved(fromStoredValue: "local") == .local)
        #expect(TranscriptionProviderID.local.displayName == "Apple On-Device")
    }

    @Test func malformedLegacyProviderSelectionUsesAuthenticatedDefault() {
        #expect(TranscriptionProviderID.resolved(fromStoredValue: "") == .deepgram)
        #expect(TranscriptionProviderID.resolved(fromStoredValue: "retired-provider") == .deepgram)
    }

    @MainActor
    @Test func productionConsentOffConstructsNoCloudRoute() {
        let provider = SpeechRecognizerViewModel.productionProvider(cloudProcessingAllowed: false)
        #expect(provider.identifier == "local")
    }

    @MainActor
    @Test func productionConsentOnUsesBoundedAutomaticRoute() {
        let provider = SpeechRecognizerViewModel.productionProvider(cloudProcessingAllowed: true)
        #expect(provider.identifier == "automatic")
    }

    @Test func automaticRouteFallsBackWhenCloudCannotStart() async throws {
        let fallbackSession = StubTranscriptionSession()
        let provider = ResilientTranscriptionProvider(
            primary: StubTranscriptionProvider(result: .failure(TestFailure.cloudUnavailable)),
            fallback: StubTranscriptionProvider(result: .success(fallbackSession))
        )
        let session = try await provider.startSession(config: config)
        #expect(session.resolvedProviderIdentifier == "stub")
    }

    @Test func automaticRouteDoesNotDuplicateWhenCloudStarts() async throws {
        let primarySession = StubTranscriptionSession()
        let fallback = CountingTranscriptionProvider()
        let provider = ResilientTranscriptionProvider(
            primary: StubTranscriptionProvider(result: .success(primarySession)),
            fallback: fallback
        )
        let session = try await provider.startSession(config: config)
        #expect(session.resolvedProviderIdentifier == "stub")
        #expect(await fallback.starts == 0)
    }

    @MainActor
    @Test func productionTranscriptPipelineIgnoresProviderFillerHints() {
        let transcript = "Um, I like the direction, so the next step is clear."
        let prompt = "What is the next step?"
        let routes: [(TranscriptionProviderID, TranscriptUpdate)] = [
            (.local, update(transcript, providerFillers: nil)),
            (.deepgram, update(transcript, providerFillers: ["um", "like", "so"])),
            (.google, update(transcript, providerFillers: [])),
            (.aws, update(transcript, providerFillers: ["um"])),
        ]

        let previousAlertSetting = PracticeSettingsManager.shared.fillerAlertSoundEnabled
        PracticeSettingsManager.shared.fillerAlertSoundEnabled = false
        defer { PracticeSettingsManager.shared.fillerAlertSoundEnabled = previousAlertSetting }

        let projections = routes.map { _, update in
            let recognizer = SpeechRecognizerViewModel(preloadOnInit: false)
            recognizer.sessionPrompt = prompt
            recognizer.handleTranscriptUpdate(update)
            return [
                recognizer.transcribedText,
                String(recognizer.fillerWordCount),
                String(recognizer.highlightedText.characters),
            ].joined(separator: "|")
        }

        #expect(Set(routes.map(\.0)) == Set(TranscriptionProviderID.allCases))
        #expect(Set(projections).count == 1)
        #expect(projections[0].contains(transcript))
        #expect(projections[0].contains("|1|"))
    }

    @MainActor
    @Test func unsupportedOnDeviceLocaleReachesTheRecordingUIMapper() {
        let recognizer = SpeechRecognizerViewModel(preloadOnInit: false)
        let error = LocalSpeechError.onDeviceRecognitionUnavailable("es-ES")
        let beforeStart = recognizer.userFacingRecordingError(for: error, started: false)
        let afterStart = recognizer.userFacingRecordingError(for: error, started: true)

        #expect(beforeStart == "On-device transcription isn't available for es-ES on this device.")
        #expect(afterStart == beforeStart)
        #expect(beforeStart.contains("on this device"))
        #expect(recognizer.recordingIssue(for: error) == .unsupportedOnDeviceLocale("es-ES"))
        #expect(recognizer.recordingIssue(for: UnsafeProviderFailure()) == nil)
        #expect(
            recognizer.userFacingRecordingError(
                for: UnsafeProviderFailure(),
                started: false
            ) == "Live transcription is temporarily unavailable. Your rep hasn’t started."
        )
    }

    #if DEBUG
    @Test func unsupportedLocaleUIFixtureUsesTheConfiguredLocaleAndLocalRoute() async {
        let provider = UITestUnsupportedLocaleTranscriptionProvider()
        let spanishConfig = TranscriptionConfig(
            languageCode: "es-ES",
            sampleRate: 16_000,
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: false
        )

        #expect(provider.identifier == TranscriptionProviderID.local.rawValue)
        do {
            _ = try await provider.startSession(config: spanishConfig)
            Issue.record("The unsupported-locale fixture unexpectedly opened a session")
        } catch let error as LocalSpeechError {
            #expect(error == .onDeviceRecognitionUnavailable("es-ES"))
        } catch {
            Issue.record("Unexpected fixture error: \(error)")
        }
    }
    #endif

    @Test func cloudStartupFallbackProducesContentFreeNotice() {
        let notice = SpeechRecognizerViewModel.routeNotice(
            requestedCloud: true,
            resolvedProviderIdentifier: TranscriptionProviderID.local.rawValue
        )

        #expect(notice == .cloudStartupFallback)
        #expect(notice?.title == "Continuing on this device")
        #expect(notice?.message == "Cloud transcription wasn’t available at startup, so this rep is staying on this device. No rep audio was sent to a cloud speech provider.")
        #expect(notice?.accessibilityLabel == "Continuing on this device. Cloud transcription wasn’t available at startup, so this rep is staying on this device. No rep audio was sent to a cloud speech provider.")
    }

    @Test func deliberateLocalRouteStaysQuiet() {
        let notice = SpeechRecognizerViewModel.routeNotice(
            requestedCloud: false,
            resolvedProviderIdentifier: TranscriptionProviderID.local.rawValue
        )

        #expect(notice == nil)
    }

    @Test func successfulCloudRouteStaysQuiet() {
        let notice = SpeechRecognizerViewModel.routeNotice(
            requestedCloud: true,
            resolvedProviderIdentifier: TranscriptionProviderID.deepgram.rawValue
        )

        #expect(notice == nil)
    }

    @MainActor
    @Test func nextRouteDecisionClearsPreviousFallbackNotice() {
        let recognizer = SpeechRecognizerViewModel(preloadOnInit: false)
        recognizer.recordTranscriptionRouteResolution(
            requestedCloud: true,
            resolvedProviderIdentifier: TranscriptionProviderID.local.rawValue
        )
        #expect(recognizer.transcriptionRouteNotice == .cloudStartupFallback)

        recognizer.beginTranscriptionRouteDecision()

        #expect(recognizer.transcriptionRouteNotice == nil)
    }

    private var config: TranscriptionConfig {
        TranscriptionConfig(
            languageCode: "en-US",
            sampleRate: 16_000,
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: false
        )
    }

    private func update(
        _ text: String,
        providerFillers: [String]?
    ) -> TranscriptUpdate {
        TranscriptUpdate(
            text: text,
            isFinal: true,
            confidence: 0.94,
            words: nil,
            providerFillerWords: providerFillers,
            latencyMs: 20
        )
    }
}

private enum TestFailure: Error { case cloudUnavailable }

private struct UnsafeProviderFailure: LocalizedError {
    var errorDescription: String? { "raw provider detail must not reach the UI" }
}

private final class StubTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    let name = "Stub"
    let identifier = "stub"
    let result: Result<any TranscriptionSession, Error>

    init(result: Result<any TranscriptionSession, Error>) { self.result = result }

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        try result.get()
    }
}

private actor CountingTranscriptionProvider: TranscriptionProvider {
    nonisolated let name = "Counting"
    nonisolated let identifier = "counting"
    private(set) var starts = 0

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        starts += 1
        return StubTranscriptionSession()
    }
}

private final class StubTranscriptionSession: TranscriptionSession, @unchecked Sendable {
    let transcriptUpdates = AsyncThrowingStream<TranscriptUpdate, Error> { $0.finish() }
    func sendAudio(_ data: Data) async throws {}
    func finish() async throws -> FinalizedTranscript {
        FinalizedTranscript(text: "", receivedFinalResult: false, audioByteCount: 0)
    }
}
