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
}

private enum TestFailure: Error { case cloudUnavailable }

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
