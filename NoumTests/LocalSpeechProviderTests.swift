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

    /// Debug builds may pin a provider, but they must not be able to pin the
    /// app into a rep that cannot start. Consent-off resolves local, and a
    /// pinned cloud provider is always wrapped with the on-device fallback.
    @MainActor
    @Test func developmentSelectionNeverDeadEndsTheRep() {
        for id in TranscriptionProviderID.allCases {
            #expect(
                SpeechRecognizerViewModel.developmentProvider(
                    id: id,
                    cloudProcessingAllowed: false
                ).identifier == "local"
            )
        }

        #expect(
            SpeechRecognizerViewModel.developmentProvider(
                id: .local,
                cloudProcessingAllowed: true
            ).identifier == "local"
        )
        for id in TranscriptionProviderID.allCases where id != .local {
            #expect(
                SpeechRecognizerViewModel.developmentProvider(
                    id: id,
                    cloudProcessingAllowed: true
                ).identifier == "automatic"
            )
        }
    }

    /// Consent-off is not a generic "we could not hear you" — it is a decision
    /// the user can reverse, so it must reach the UI as its own typed issue.
    @MainActor
    @Test func consentRequiredReachesTheRecordingUIMapper() {
        let recognizer = SpeechRecognizerViewModel(preloadOnInit: false)
        let error = TranscriptionSessionError.cloudProcessingConsentRequired
        #expect(recognizer.recordingIssue(for: error) == .cloudProcessingDisabled)
        #expect(
            recognizer.userFacingRecordingError(for: error, started: false)
                == "Cloud processing is off. Turn it on in Settings to use live transcription."
        )
    }

    @MainActor
    @Test func speechAuthorizationDenialRoutesToSettingsWithoutRetrying() {
        let recognizer = SpeechRecognizerViewModel(preloadOnInit: false)
        let error = LocalSpeechError.authorizationDenied

        #expect(recognizer.recordingIssue(for: error) == .speechRecognitionDenied)
        let presentation = SpeechRecordingIssuePresentation.make(
            issue: recognizer.recordingIssue(for: error),
            message: recognizer.userFacingRecordingError(for: error, started: false)
        )
        #expect(presentation.title == "Speech Recognition is off")
        #expect(presentation.detail.contains("Settings"))
        #expect(presentation.recovery == .openSettings)
        #expect(presentation.recovery != .retry)
    }

    @Test func microphoneDenialRoutesToItsOwnSettingsRecovery() {
        #expect(
            SpeechRecognizerViewModel.recordingIssue(for: .denied)
                == .microphoneDenied
        )
        #expect(SpeechRecognizerViewModel.recordingIssue(for: .granted) == nil)
        #expect(SpeechRecognizerViewModel.recordingIssue(for: .undetermined) == nil)
        #expect(
            SpeechRecognizerViewModel.recordingIssue(for: .unknown)
                == .captureUnavailable(started: false)
        )

        let presentation = SpeechRecordingIssuePresentation.make(
            issue: .microphoneDenied,
            message: PracticeMicrophonePermissionState.denied.userFacingRecoveryMessage ?? ""
        )
        #expect(presentation.title == "Microphone access is off")
        #expect(presentation.detail.contains("Open iOS Settings"))
        #expect(presentation.recovery == .openSettings)
        #expect(presentation.recovery != .retry)

        // Apple Speech is a separate permission and must keep its typed cause.
        #expect(
            SpeechRecordingIssuePresentation.make(
                issue: .speechRecognitionDenied,
                message: "Speech recognition access is off."
            ).title == "Speech Recognition is off"
        )
    }

    /// One owner for what a failure means. A surface may render it in its own
    /// register, but none may offer a retry for a cause a retry cannot clear —
    /// that is the loop this mapping exists to prevent.
    @Test func recoveryIsOnlyOfferedWhenTheCauseCanChange() {
        #expect(
            SpeechRecordingIssuePresentation.make(
                issue: .unsupportedOnDeviceLocale("es-ES"),
                message: "On-device transcription isn't available for es-ES on this device."
            ).recovery == .leaveRep
        )
        #expect(
            SpeechRecordingIssuePresentation.make(
                issue: .cloudProcessingDisabled,
                message: "Cloud processing is off."
            ).recovery == .grantCloudConsent
        )
        #expect(
            SpeechRecordingIssuePresentation.make(
                issue: .microphoneDenied,
                message: "Microphone access is off."
            ).recovery == .openSettings
        )
        #expect(
            SpeechRecordingIssuePresentation.make(
                issue: .speechRecognitionDenied,
                message: "Speech recognition access is off."
            ).recovery == .openSettings
        )
        #expect(
            SpeechRecordingIssuePresentation.make(
                issue: nil,
                message: "Noum didn’t hear enough speech to complete that rep."
            ).recovery == .retry
        )
        let interrupted = SpeechRecordingIssuePresentation.make(
            issue: .captureUnavailable(started: true),
            message: "Live transcription was interrupted."
        )
        #expect(interrupted.title == "Live transcription stopped")
        #expect(interrupted.recovery == .retry)
    }

    @Test func everyReachableSpokenSurfaceKeepsSettingsRecoveryVisible() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        let contracts = [
            ("Noum/AhCounterView.swift", "ahCounter.recordingIssue.openSettings"),
            ("Noum/RoleplayView.swift", "roleplay.recordingIssue.openSettings"),
            ("Noum/IMPracticeView.swift", "imPractice.recordingIssue.openSettings"),
            ("Noum/SuddenDeathPracticeView.swift", "suddenDeath.recordingIssue.openSettings"),
            ("Noum/CutTheCrutchView.swift", "cutTheCrutch.recordingIssue.openSettings"),
            ("Noum/TimedPracticeView.swift", "timedPractice.recordingIssue.openSettings"),
            ("Noum/LessonView.swift", "openAppSettingsAfterApplyIssue"),
            ("Noum/MiniDrillView.swift", "miniDrill.recordingIssue.openSettings"),
            ("Noum/PaceTrainingView.swift", "paceTraining.recordingIssue.openSettings"),
        ]

        for (relativePath, identifier) in contracts {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            #expect(
                source.contains("SpeechRecordingIssuePresentation.make"),
                "\(relativePath) must render the shared typed issue mapping"
            )
            #expect(
                source.contains(identifier),
                "\(relativePath) must expose its Settings recovery to UI automation"
            )
        }
    }

    @Test func auxiliaryDrillsReplaceADeadStartWithSettingsRecovery() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        let contracts = [
            (
                "Noum/MiniDrillView.swift",
                "miniDrill.start",
                "miniDrill.recordingIssue.openSettings"
            ),
            (
                "Noum/PaceTrainingView.swift",
                "paceTraining.start",
                "paceTraining.recordingIssue.openSettings"
            ),
        ]

        for (relativePath, startIdentifier, settingsIdentifier) in contracts {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            #expect(source.contains(startIdentifier))
            #expect(source.contains(settingsIdentifier))
            #expect(source.contains("recordingIssuePresentation?.recovery != .openSettings"))
            #expect(source.contains("openAppSettingsAfterRecordingIssue"))
        }
    }

    /// The locale copy must carry the failing locale and the way out, because
    /// every surface renders this same statement.
    @Test func unsupportedLocaleCopyNamesTheLocaleAndTheWayOut() {
        let presentation = SpeechRecordingIssuePresentation.make(
            issue: .unsupportedOnDeviceLocale("es-ES"),
            message: "On-device transcription isn't available for es-ES on this device."
        )
        #expect(presentation.title == "This language isn't available offline")
        #expect(presentation.detail.contains("es-ES"))
        #expect(presentation.detail.contains("Choose another Practice language in Settings"))
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
        #expect(
            recognizer.recordingIssue(
                for: UnsafeProviderFailure(),
                started: true
            ) == .captureUnavailable(started: true)
        )
        #expect(
            recognizer.userFacingRecordingError(
                for: UnsafeProviderFailure(),
                started: false
            ) == "Live transcription is temporarily unavailable. Your rep hasn’t started."
        )
    }

    #if DEBUG
    @Test func speechAuthorizationDeniedFixtureKeepsTheTypedCause() async {
        let provider = UITestSpeechAuthorizationDeniedTranscriptionProvider()
        do {
            _ = try await provider.startSession(config: config)
            Issue.record("The authorization-denied fixture unexpectedly opened a session")
        } catch let error as LocalSpeechError {
            #expect(error == .authorizationDenied)
        } catch {
            Issue.record("Unexpected fixture error: \(error)")
        }
    }

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
