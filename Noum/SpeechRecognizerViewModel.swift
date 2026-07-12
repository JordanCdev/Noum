import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif

#if canImport(AVFoundation)
enum PracticeMicrophonePermissionState: Equatable {
    case unknown
    case undetermined
    case denied
    case granted

    var blocksRecording: Bool {
        switch self {
        case .denied, .unknown: return true
        case .undetermined, .granted: return false
        }
    }

    var userFacingRecoveryMessage: String? {
        switch self {
        case .denied:
            return "Microphone access is blocked. Open iOS Settings and allow Noum to use the microphone, then start the rep again."
        case .unknown:
            return "Microphone access is unavailable on this device. Check the audio route and try again."
        case .undetermined, .granted:
            return nil
        }
    }

    static func current() -> PracticeMicrophonePermissionState {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING_MICROPHONE_GRANTED") {
            return .granted
        }
        #endif
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .undetermined
        @unknown default: return .unknown
        }
    }
}

enum RecordingLifecycleState: Equatable, Sendable {
    case idle
    case connecting
    case recording
    case finalizing
    case completed(FinalizedTranscript)
    case failed(String)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .connecting, .recording, .finalizing: return true
        case .idle, .completed, .failed: return false
        }
    }

    var completedUsableCapture: Bool {
        if case .completed(let result) = self { return result.hasUsableSpeech }
        return false
    }

    var expectsProviderStreamOpen: Bool {
        switch self {
        case .connecting, .recording: return true
        case .idle, .finalizing, .completed, .failed: return false
        }
    }
}

@MainActor
class SpeechRecognizerViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var highlightedText: AttributedString = AttributedString("")
    @Published var isRecording: Bool = false {
        didSet {
            // Hard mute-gate for interaction cues (A2): nothing may
            // synthesize while the mic is open — a cue would bleed into
            // the transcript and fight the playAndRecord session.
            guard isRecording != oldValue else { return }
            InteractionSoundEngine.noteRecordingActive(isRecording)
        }
    }
    @Published var lastSessionDuration: TimeInterval = 0
    @Published var pastSessions: [PracticeSession] = []
    @Published var connectionError: String?
    @Published var activeProviderName: String = ""
    private var activeProviderIdentifier: String
    @Published var microphonePermissionState: PracticeMicrophonePermissionState = .current()
    @Published private(set) var recordingLifecycle: RecordingLifecycleState = .idle

    /// The session prompt (topic). Used by ALL modes for prompt-echo exclusion
    /// in semantic filler detection. Set this before recording starts.
    var sessionPrompt: String?

    /// When set, enables the stricter Pressure Drill filler path.
    /// Uses `sessionPrompt` for echo exclusion with the sudden death threshold.
    var pressureDrillPrompt: String? {
        get { _pressureDrillMode ? sessionPrompt : nil }
        set { _pressureDrillMode = newValue != nil; if let v = newValue { sessionPrompt = v } }
    }
    private var _pressureDrillMode = false

    @Published var pressureDrillFillerCount: Int = 0
    @Published var fillerAlertDebugLine: String?
    /// Count of uncertain filler detections (below general threshold but above noise).
    /// UI can show a "?" indicator for these.
    @Published var uncertainFillerCount: Int = 0

    /// Smoothed live audio amplitude envelope, 0.0–1.0, updated on the main
    /// actor at ~30Hz while recording. Driven by the input-tap RMS of the
    /// mic buffer. Consumers (e.g. `NoumCharacter(audioLevel:)`) read this
    /// to render real-time presence — the orb visibly tracking the user's
    /// voice. Resets to 0 between sessions so a teardown doesn't leave the
    /// orb stuck at the last live value.
    @Published var audioLevel: Double = 0.0

    /// M26 — per-session vocal-energy accumulator. Captures raw RMS
    /// samples on the audio thread (lock-light). Reset on every
    /// session start; finalized at session end via
    /// `currentSessionVocalEnergy()`.
    private let vocalEnergyAccumulator = VocalEnergyAccumulator()
    /// RMS smoothing coefficient — higher = snappier, lower = calmer. 0.30
    /// reads as "alive" without jittering on consonants.
    private static let audioLevelSmoothing: Double = 0.30

    /// Confidence threshold for the general filler count (non-pressure modes).
    /// Detections at or above this level are counted. Default: 0.65 (catches clear
    /// fillers like "um", "uh", "you know" and high-confidence "like"/"so" but
    /// excludes ambiguous low-confidence matches).
    private let generalFillerThreshold: Double = 0.65
    private var fillerAlertGate = FillerAlertGate()

    private let sessionStore = PracticeSessionStore.shared
    private let recommendationLearningStore = RecommendationLearningStore.shared

    // Provider abstraction — replaces direct AWS SDK usage
    private var provider: any TranscriptionProvider
    private var activeSession: (any TranscriptionSession)?
    private var transcriptListenerTask: Task<Void, Never>?
    private var audioSendPump: TranscriptionAudioPump?

    /// Monotonic session token. A terminal provider callback can race a discard
    /// or the next rep; stale callbacks must never persist or annotate the new
    /// buffers. Bumped when a session commits or is invalidated.
    private var sessionGeneration: Int = 0

    /// Pure predicate for the delayed-finalize guard (unit-testable without the
    /// audio stack): finalize only when no newer session has started since.
    nonisolated static func shouldFinalize(captured: Int, current: Int) -> Bool {
        captured == current
    }

    private var audioEngine: AVAudioEngine?
    private var audioSessionObserverTokens: [NSObjectProtocol] = []
    /// Captures audio samples in parallel with transcription so we can
    /// emit `PitchMetrics` at session end. Created fresh per recording;
    /// reset whenever a new session starts.
    private var pitchAnalyzer: PitchAnalyzer?
    private var sessionStart: Date?
    /// Identity of the session THIS rep actually persisted, so the delayed
    /// `annotateLatestSession` writes back to the rep it measured — never
    /// blindly to `sessions[0]`. Nil when the current rep produced no usable
    /// session (empty / too short / non-recording mode), which is exactly the
    /// case that used to corrupt the PREVIOUS real rep's score.
    private var lastSavedSessionID: UUID?
    /// Correlation id grouping this rep's flow-observability events (rep start ->
    /// stop -> save/abort -> finalize) so an incident is reconstructable.
    private var currentRepCorrelationID = UUID()
    private var finalTranscript: String = ""
    private var partialTranscript: String = ""
    private var currentSessionMode: PracticeMode = .ahCounter
    private var hasPreparedInteractiveUse = false
    var shouldRecordPracticeSession = true

    // Quality tracking
    private var sessionUpdateCount: Int = 0
    private var totalLatencyMs: Int = 0
    private var confidenceValues: [Double] = []
    private var providerFillerCount: Int = 0

    // Pause-metric raw inputs. Word timings stay transient (we don't
    // persist them — only the computed `PauseMetrics` lands on the
    // session) but we accumulate across the whole rep so finalization
    // can compute pause stats from the full word stream.
    private var sessionWordTimings: [TranscriptUpdate.WordTiming] = []
    /// `startTime` of every word the filler detector has flagged. Read
    /// at finalize to classify pauses as filled vs unfilled.
    private var fillerStartTimes: [TimeInterval] = []

    /// Snapshot of accumulated word timings, intended for SessionFinalizer
    /// to compute pause metrics. Returns an empty array if the active
    /// transcription provider didn't emit word-level data.
    var capturedWordTimings: [TranscriptUpdate.WordTiming] {
        sessionWordTimings
    }

    /// Compute pause metrics from the session's captured word timings.
    /// Returns nil when the provider didn't emit word data (so we don't
    /// store a misleading "0 pauses" reading on a session we couldn't
    /// actually measure). Public so per-mode views (Sudden Death, IM)
    /// can attach metrics to their own session drafts.
    func currentSessionPauseMetrics() -> PauseMetrics? {
        guard !sessionWordTimings.isEmpty else { return nil }
        // Cross-reference filler detector findings against the word stream
        // by lowercased text. Each filler-classified word's `startTime`
        // becomes a timestamp the pause computer uses to mark "filled" gaps.
        let fillers = FillerWordDetector.detections(
            in: finalTranscript,
            prompt: sessionPrompt ?? ""
        )
        let fillerTexts = Set(fillers.map { $0.word.lowercased() })
        let filledStarts = sessionWordTimings
            .filter { fillerTexts.contains($0.word.lowercased()) }
            .map { $0.startTime }
        return PauseMetrics.compute(
            words: sessionWordTimings,
            fillerStartTimes: filledStarts
        )
    }

    /// Pitch metrics for the just-completed session. Runs autocorrelation
    /// across the captured audio buffer; safe to call from the main actor
    /// (analysis is a few hundred milliseconds at most for a 60s rep).
    /// Returns nil when no analyzer was attached, when the buffer is too
    /// short to analyze, or when no window crossed the voicing threshold.
    ///
    /// Hum-vs-speech gate: also returns nil when the rep produced almost
    /// no transcribed words or ran for under a few seconds. Closes the
    /// gap documented in `PitchMetrics.swift` — without a transcript
    /// signal, voiced f0 in the 70–400 Hz band may be HVAC, background
    /// music, or a TV in the room, not the user's voice. We need the
    /// transcript to credibly attribute the pitch reading to speech.
    /// Thresholds are conservative: 8 words covers "uh, sorry — let me
    /// start over" half-aborts; 4 seconds covers reps where the mic
    /// barely opened.
    func currentSessionPitchMetrics() -> PitchMetrics? {
        guard let analyzer = pitchAnalyzer else { return nil }
        let words = finalTranscript.split { !$0.isLetter && !$0.isNumber }.count
        let duration = sessionStart.map { Date().timeIntervalSince($0) } ?? 0
        guard words >= 8, duration >= 4 else { return nil }
        let metrics = analyzer.analyze()
        return metrics.windowCount > 0 ? metrics : nil
    }

    init(preloadOnInit: Bool = true) {
        self.provider = Self.resolveProvider()
        self.activeProviderName = provider.name
        self.activeProviderIdentifier = provider.identifier
        installAudioSessionObservers()
        guard preloadOnInit else { return }
        loadSessions()
        prepareForInteractiveUse()
    }

    deinit {
        audioSessionObserverTokens.forEach(NotificationCenter.default.removeObserver)
    }

    private static func resolveProvider() -> any TranscriptionProvider {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING_TRANSCRIPTION_START_FAILURE") {
            return UITestUnavailableTranscriptionProvider()
        }
        let selected = UserDefaults.standard.string(forKey: "transcriptionProvider")
        return makeProvider(for: TranscriptionProviderID.resolved(fromStoredValue: selected))
        #else
        // Production prefers the authenticated Deepgram route when consent is
        // present, then falls back to Apple's strictly on-device recognizer if
        // token/network setup cannot begin. With cloud processing off, never
        // instantiate a cloud provider at all.
        return productionProvider(
            cloudProcessingAllowed: AISettingsManager.shared.isCloudProcessingAllowed
        )
        #endif
    }

    /// Pure production selection seam for contract tests. Consent-off never
    /// constructs a cloud provider; consent-on uses one bounded local fallback.
    static func productionProvider(cloudProcessingAllowed: Bool) -> any TranscriptionProvider {
        guard cloudProcessingAllowed else { return LocalSpeechProvider() }
        return ResilientTranscriptionProvider(
            primary: DeepgramProvider(),
            fallback: LocalSpeechProvider()
        )
    }

    /// Shared provider factory. The live coach call (`AskNoumVoiceInput`)
    /// reuses this so its cloud STT chain is constructed from the EXACT
    /// providers practice reps stream through — one registry, no parallel
    /// resolution logic that could drift. Main-actor (like the class)
    /// because `AWSTranscribeProvider.init` reads main-actor auth state.
    static func makeProvider(for id: TranscriptionProviderID) -> any TranscriptionProvider {
        switch id {
        case .deepgram: return DeepgramProvider()
        case .google: return GoogleSpeechProvider()
        case .aws:
            // AWS remains available only for local development compatibility.
            // A future Release call site must never resurrect the legacy
            // direct-credential path merely by resolving this enum case.
            #if DEBUG
            return AWSTranscribeProvider()
            #else
            return LocalSpeechProvider()
            #endif
        case .local: return LocalSpeechProvider()
        }
    }

    func prepareSession(mode: PracticeMode) {
        currentSessionMode = mode
    }

    func prepareForInteractiveUse() {
        guard !hasPreparedInteractiveUse else { return }
        hasPreparedInteractiveUse = true
        loadSessions()
        refreshRecordPermission()
    }

    func refreshRecordPermission() {
        microphonePermissionState = .current()
    }

    @discardableResult
    func requestMicrophoneAccessForPractice() async -> Bool {
        await ensureRecordPermission()
    }

    var hasUsableCompletedCapture: Bool {
        recordingLifecycle.completedUsableCapture
    }

    func annotateLatestSession(
        score: Int? = nil,
        xpEarned: Int? = nil,
        headline: String? = nil,
        insights: [String] = [],
        coachSummary: String? = nil,
        prompt: String? = nil,
        theme: PromptTheme? = nil
    ) {
        // Only annotate the session THIS rep actually persisted. If the rep
        // produced no usable session (empty / too short), `lastSavedSessionID`
        // is nil and we annotate NOTHING — writing to `sessions[0]` here would
        // silently overwrite the user's PREVIOUS real rep with this aborted
        // rep's score/headline (the data-corruption bug this guard closes).
        guard let sessionID = lastSavedSessionID else { return }
        sessionStore.annotateLatest(
            PracticeSessionAnnotation(
                score: score,
                xpEarned: xpEarned,
                headline: headline,
                insights: insights,
                coachSummary: coachSummary,
                prompt: prompt,
                theme: theme
            ),
            expectedMode: currentSessionMode,
            expectedSessionID: sessionID
        )
        pastSessions = sessionStore.sessions
        if let latest = sessionStore.sessions.first {
            recommendationLearningStore.recordOutcome(
                for: latest,
                previousSessions: Array(sessionStore.sessions.dropFirst())
            )
        }
    }

    func startRecording() {
        guard !recordingLifecycle.isBusy else { return }
        Task { await startRecordingAwaitingReadiness() }
    }

    /// Awaitable recording start used by practice modes that own timers or
    /// engines. A `true` result guarantees that both the provider session and
    /// the microphone tap are live; callers must not advance before then.
    @discardableResult
    func startRecordingAwaitingReadiness() async -> Bool {
        guard !recordingLifecycle.isBusy else { return isRecording }
        prepareForInteractiveUse()
        refreshRecordPermission()
        if microphonePermissionState.blocksRecording {
            connectionError = microphonePermissionState.userFacingRecoveryMessage
            transition(to: .failed(connectionError ?? "Microphone access is unavailable."))
            return false
        }

        transition(to: .connecting)

        // Re-resolve provider in case user changed settings
        provider = Self.resolveProvider()
        activeProviderName = provider.name
        activeProviderIdentifier = provider.identifier

        guard await ensureRecordPermission() else {
            guard recordingLifecycle == .connecting else { return false }
            transition(to: .failed(connectionError ?? "Microphone access is unavailable."))
            return false
        }
        guard recordingLifecycle == .connecting else { return false }
        return await startRecordingWithProvider()
    }

    private func startRecordingWithProvider() async -> Bool {
        // A new session is committing — invalidate any pending delayed finalize
        // from a prior stop (its transcript buffers are about to be reset).
        sessionGeneration &+= 1
        let generation = sessionGeneration
        let shouldRestorePressureMode = _pressureDrillMode
        let promptBeforeReset = sessionPrompt
        resetCurrentSession()
        if shouldRestorePressureMode {
            _pressureDrillMode = true
            sessionPrompt = promptBeforeReset
        }
        lastSavedSessionID = nil
        currentRepCorrelationID = UUID()
        sessionUpdateCount = 0
        totalLatencyMs = 0
        confidenceValues = []
        providerFillerCount = 0
        sessionWordTimings = []
        fillerStartTimes = []
        // Pitch analyzer carries the previous rep's audio buffer until
        // we explicitly drop it. Discard so the new session starts fresh.
        pitchAnalyzer?.reset()
        pitchAnalyzer = nil

        do {
            // .allowBluetoothHFP lets AirPods serve as both mic and speaker.
            // Must be set before AVAudioEngine inspects inputNode so the simulator
            // returns a valid (non-zero-channel) input format.
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            failStartRecording(with: error)
            return false
        }

        let sampleRate = Int(AVAudioSession.sharedInstance().sampleRate)
        let practiceLocale = LocaleSettingsManager.shared.current
        let config = TranscriptionConfig(
            languageCode: practiceLocale.code,
            sampleRate: sampleRate,
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: true
        )

        do {
            let requestedCloud = provider.identifier != TranscriptionProviderID.local.rawValue
            let session = try await provider.startSession(config: config)
            guard Self.shouldFinalize(captured: generation, current: sessionGeneration),
                  recordingLifecycle == .connecting else {
                Task { _ = try? await session.finish() }
                return false
            }
            self.activeSession = session
            let resolvedProviderIdentifier = session.resolvedProviderIdentifier ?? provider.identifier
            if session.resolvedProviderIdentifier != nil {
                activeProviderIdentifier = resolvedProviderIdentifier
                activeProviderName = TranscriptionProviderID(rawValue: resolvedProviderIdentifier)?.displayName ?? resolvedProviderIdentifier
            }
            FlowEventLog.shared.recordTranscriptionRoute(
                correlationId: currentRepCorrelationID,
                requestedCloud: requestedCloud,
                resolvedProviderIdentifier: resolvedProviderIdentifier
            )

            transcriptListenerTask = Task { @MainActor [weak self] in
                do {
                    for try await update in session.transcriptUpdates {
                        guard let self,
                              Self.shouldFinalize(captured: generation, current: self.sessionGeneration) else { return }
                        self.handleTranscriptUpdate(update)
                    }
                    guard let self,
                          Self.shouldFinalize(captured: generation, current: self.sessionGeneration),
                          self.recordingLifecycle.expectsProviderStreamOpen else { return }
                    self.failActiveRecording(
                        with: TranscriptionSessionError.transport("The transcription connection closed before the rep finished."),
                        generation: generation
                    )
                } catch {
                    guard let self else { return }
                    self.failActiveRecording(with: error, generation: generation)
                }
            }

            // Start audio capture and feed into the session
            try startAudioStream(sendingTo: session, generation: generation)
            sessionStart = Date()
            transition(to: .recording)
            return true
        } catch {
            guard Self.shouldFinalize(captured: generation, current: sessionGeneration),
                  recordingLifecycle == .connecting else { return false }
            failStartRecording(with: error)
            return false
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        Task { _ = await stopRecordingAwaitingFinalization() }
    }

    /// Tears down a rep without producing a terminal app result. Used for
    /// explicit discard/navigation paths so backing out can never persist or
    /// score a half-finished recording.
    func cancelRecording() {
        guard recordingLifecycle.isBusy else { return }
        let session = activeSession
        sessionGeneration &+= 1
        teardownAudioStream()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        activeSession = nil
        transcriptListenerTask?.cancel()
        transcriptListenerTask = nil
        sessionStart = nil
        lastSavedSessionID = nil
        if let session { Task { _ = try? await session.finish() } }
        transition(to: .idle)
    }

    /// Stops microphone capture and waits for the provider's real terminal
    /// response. Returns nil on transport/finalization failure; callers must
    /// require `result.hasUsableSpeech` before scoring or awarding progress.
    @discardableResult
    func stopRecordingAwaitingFinalization() async -> FinalizedTranscript? {
        guard isRecording else { return nil }
        transition(to: .finalizing)
        let audioPump = audioSendPump
        audioSendPump = nil
        teardownAudioStream(cancelPendingAudio: false)
        try? AVAudioSession.sharedInstance().setActive(false)

        // Capture this stop's generation + session so a session started during
        // the teardown/finalize window can't have its state torn down or its
        // transcript overwritten by this (now stale) tail.
        let gen = sessionGeneration
        let sessionToEnd = activeSession
        do {
            guard let sessionToEnd else {
                throw TranscriptionSessionError.notReady
            }
            // Drain every callback-enqueued buffer before telling the provider
            // to finalize; otherwise the last syllable can race CloseStream.
            try await audioPump?.finish()
            let providerResult = try await sessionToEnd.finish()
            await transcriptListenerTask?.value
            guard Self.shouldFinalize(captured: gen, current: sessionGeneration) else { return nil }
            activeSession = nil
            transcriptListenerTask?.cancel()
            transcriptListenerTask = nil

            // The provider's terminal receipt is authoritative. Never promote
            // an interim fragment merely because an earlier segment happened
            // to be final; CloseStream/finish must explicitly finalize the
            // trailing words before they can be scored or persisted.
            finalTranscript = providerResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
            partialTranscript = ""
            transcribedText = finalTranscript
            highlightAndCountFillerWords(in: finalTranscript)
            let completion = FinalizedTranscript(
                text: finalTranscript,
                receivedFinalResult: providerResult.receivedFinalResult,
                audioByteCount: providerResult.audioByteCount
            )
            recordQualityMetrics()
            if RecordingCompletionGate.allowsScoringAndProgress(completion) {
                saveCurrentSession()
                connectionError = nil
            } else {
                sessionStart = nil
                lastSavedSessionID = nil
                connectionError = "Noum didn’t hear enough speech to complete that rep. Try again when you’re ready."
            }
            transition(to: .completed(completion))
            return completion
        } catch {
            audioPump?.cancel()
            failActiveRecording(with: error, generation: gen)
            return nil
        }
    }

    // MARK: - Transcript Update Handling (provider-agnostic)

    private func handleTranscriptUpdate(_ update: TranscriptUpdate) {
        sessionUpdateCount += 1
        if let latency = update.latencyMs { totalLatencyMs += latency }
        if let confidence = update.confidence { confidenceValues.append(confidence) }
        if let providerFillers = update.providerFillerWords {
            providerFillerCount += providerFillers.count
        }

        let snippet = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else { return }

        if update.isFinal {
            if !finalTranscript.isEmpty { finalTranscript += " " }
            finalTranscript += snippet
            partialTranscript = ""

            // Accumulate word timings only on `isFinal` updates so we
            // don't double-count partials. Provider word arrays are the
            // authoritative source for pause computation.
            if let words = update.words, !words.isEmpty {
                sessionWordTimings.append(contentsOf: words)
            }
        } else {
            partialTranscript = snippet
        }

        let combined = [finalTranscript, partialTranscript].filter { !$0.isEmpty }.joined(separator: " ")
        transcribedText = combined
        highlightAndCountFillerWords(in: combined)
    }

    // MARK: - Audio Engine (provider-agnostic)

    private func ensureRecordPermission() async -> Bool {
        refreshRecordPermission()
        switch microphonePermissionState {
        case .granted:
            connectionError = nil
            return true
        case .denied, .unknown:
            connectionError = microphonePermissionState.userFacingRecoveryMessage
            return false
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            refreshRecordPermission()
            if granted {
                connectionError = nil
                return true
            }
            connectionError = PracticeMicrophonePermissionState.denied.userFacingRecoveryMessage
            return false
        }
    }

    private enum AudioStreamError: LocalizedError {
        case invalidInputFormat
        var errorDescription: String? {
            // Shown to the user via `connectionError`. Common on the simulator
            // when the audio session category wasn't fully committed before
            // AVAudioEngine inspected the input node.
            "Microphone unavailable — check that no other app is using it and try again."
        }
    }

    private func startAudioStream(
        sendingTo session: any TranscriptionSession,
        generation: Int
    ) throws {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // A zero-channel or zero-sampleRate format means the audio session
        // category wasn't fully applied (common on the iOS simulator after a
        // .playback session). Throw instead of crashing in installTap.
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            audioEngine = nil
            throw AudioStreamError.invalidInputFormat
        }

        inputNode.removeTap(onBus: 0)

        // Spin up a fresh pitch analyzer per recording. Lock-light so the
        // audio tap can append samples without contention; analysis runs
        // off-thread at session end.
        let analyzer = PitchAnalyzer()
        pitchAnalyzer = analyzer
        let captureSampleRate = inputFormat.sampleRate
        let pump = TranscriptionAudioPump(session: session) { [weak self] error in
            Task { @MainActor [weak self] in
                self?.failActiveRecording(with: error, generation: generation)
            }
        }
        audioSendPump = pump

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self, analyzer, pump] buffer, _ in
            // Capture samples for pitch analysis (cheap append, no DSP here).
            analyzer.appendBuffer(buffer, sampleRate: captureSampleRate)
            guard let self else { return }
            // Compute RMS amplitude on the audio thread, then hop to main
            // to smooth + publish. Cheap: one pass over the buffer with a
            // running sum-of-squares. The published envelope drives any
            // surface that wants the orb to track the user's voice.
            let level = Self.normalizedRMSLevel(buffer: buffer)
            // M26 — accumulate raw (unsmoothed) RMS for the per-session
            // VocalEnergyMetrics aggregate. Lock-light append; finalize()
            // happens off the audio thread in `currentSessionVocalEnergy()`.
            self.vocalEnergyAccumulator.append(level: level)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let blended = self.audioLevel * (1 - Self.audioLevelSmoothing) + level * Self.audioLevelSmoothing
                self.audioLevel = min(max(blended, 0), 1)
            }
            let data = Self.pcm16Data(from: buffer)
            if !pump.enqueue(data) {
                Task { @MainActor [weak self] in
                    self?.failActiveRecording(
                        with: TranscriptionSessionError.transport("The audio stream stopped accepting microphone data."),
                        generation: generation
                    )
                }
            }
        }

        audioEngine!.prepare()
        try audioEngine!.start()
    }

    private func teardownAudioStream(cancelPendingAudio: Bool = true) {
        if let audioEngine {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            self.audioEngine = nil
        }
        if cancelPendingAudio {
            audioSendPump?.cancel()
            audioSendPump = nil
        }
        // Drop the live envelope to silence so any orb bound to it
        // visibly settles instead of holding the last spoken level.
        audioLevel = 0.0
    }

    /// Convert a mic input buffer into a 0.0–1.0 amplitude envelope.
    /// Uses RMS over the channel-0 float samples + a dB-scaled mapping
    /// so quiet speech reads visibly above silence without the orb
    /// pinning to 1.0 on every consonant. Tuned by ear: -50dB → 0, -10dB → 1.
    nonisolated static func normalizedRMSLevel(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sumSquares: Double = 0
        for i in 0..<frameLength {
            let s = Double(channelData[i])
            sumSquares += s * s
        }
        let rms = (sumSquares / Double(frameLength)).squareRoot()
        // dB conversion + clamp to a usable visual range.
        let db = 20.0 * log10(max(rms, 1e-7))
        let normalized = (db + 50.0) / 40.0  // -50dB → 0, -10dB → 1
        return min(max(normalized, 0), 1)
    }

    private func failStartRecording(with error: Error) {
        let message = userFacingRecordingError(for: error, started: false)
        connectionError = message
        teardownAudioStream()
        try? AVAudioSession.sharedInstance().setActive(false)
        let session = activeSession
        activeSession = nil
        transcriptListenerTask?.cancel()
        transcriptListenerTask = nil
        if let session { Task { _ = try? await session.finish() } }
        sessionStart = nil
        lastSavedSessionID = nil
        transition(to: .failed(message))
    }

    private func failActiveRecording(with error: Error, generation: Int) {
        guard Self.shouldFinalize(captured: generation, current: sessionGeneration),
              recordingLifecycle.isBusy else { return }

        let message = userFacingRecordingError(for: error, started: true)
        connectionError = message
        let session = activeSession
        sessionGeneration &+= 1
        teardownAudioStream()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        activeSession = nil
        transcriptListenerTask?.cancel()
        transcriptListenerTask = nil
        sessionStart = nil
        lastSavedSessionID = nil
        if let session { Task { _ = try? await session.finish() } }
        transition(to: .failed(message))
    }

    private func userFacingRecordingError(for error: Error, started: Bool) -> String {
        if let sessionError = error as? TranscriptionSessionError,
           sessionError == .cloudProcessingConsentRequired,
           let description = sessionError.errorDescription {
            return description
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty,
           error is AudioStreamError {
            return description
        }
        return started
            ? "Live transcription was interrupted. That rep wasn’t saved — start again when the connection is ready."
            : "Live transcription is temporarily unavailable. Your rep hasn’t started."
    }

    private func transition(to state: RecordingLifecycleState) {
        recordingLifecycle = state
        isRecording = state.isRecording
    }

    private func installAudioSessionObservers() {
        let center = NotificationCenter.default
        audioSessionObserverTokens = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] note in
                Task { @MainActor [weak self] in self?.handleAudioSessionInterruption(note) }
            },
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] note in
                Task { @MainActor [weak self] in self?.handleAudioRouteChange(note) }
            },
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.recordingLifecycle.isRecording else { return }
                    self.failActiveRecording(
                        with: TranscriptionSessionError.transport("The device audio service restarted."),
                        generation: self.sessionGeneration
                    )
                }
            },
        ]
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard recordingLifecycle.isRecording,
              let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
        failActiveRecording(
            with: TranscriptionSessionError.transport("Recording was interrupted by another audio session."),
            generation: sessionGeneration
        )
    }

    private func handleAudioRouteChange(_ notification: Notification) {
        guard recordingLifecycle.isRecording,
              let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        switch reason {
        case .oldDeviceUnavailable, .noSuitableRouteForCategory, .routeConfigurationChange:
            failActiveRecording(
                with: TranscriptionSessionError.transport("The microphone route changed during the rep."),
                generation: sessionGeneration
            )
        default:
            break
        }
    }

    /// Float mic buffer → 16-bit signed PCM, the wire format every
    /// `TranscriptionProvider` consumes. `nonisolated static` because it is
    /// called from the audio tap thread (it always was — making the isolation
    /// explicit) and shared with the live coach call's cloud STT path.
    nonisolated static func pcm16Data(from buffer: AVAudioPCMBuffer) -> Data {
        let frameLength = Int(buffer.frameLength)
        if let channelData = buffer.floatChannelData?[0] {
            var pcmData = Data(capacity: frameLength * MemoryLayout<Int16>.size)
            for i in 0..<frameLength {
                let clamped = max(-1.0, min(1.0, channelData[i]))
                var sample = Int16(clamped * Float(Int16.max))
                withUnsafeBytes(of: &sample) { pcmData.append(contentsOf: $0) }
            }
            return pcmData
        }
        return Data()
    }

    // MARK: - Filler Word Detection

    private func highlightAndCountFillerWords(in text: String) {
        // Always use semantic detection — prompt-aware, confidence-scored.
        let prompt = sessionPrompt ?? ""
        let allDetections = FillerWordDetector.detections(in: text, prompt: prompt)

        // General filler count: detections at or above the general threshold.
        // This catches clear fillers but excludes ambiguous "like a", "so that", prompt echoes.
        let generalDetections = allDetections.filter { $0.confidence >= generalFillerThreshold }
        let count = generalDetections.count

        // Highlight confirmed fillers in the transcript
        let attributed = NSMutableAttributedString(string: text)
        for detection in generalDetections {
            attributed.addAttribute(.foregroundColor, value: UIColor.red, range: detection.range)
        }

        let previousCount = fillerWordCount
        fillerWordCount = count
        highlightedText = AttributedString(attributed)

        let alertDecision = fillerAlertGate.evaluate(
            previousAdjustedCount: previousCount,
            adjustedCount: count,
            detections: allDetections,
            isEnabled: PracticeSettingsManager.shared.fillerAlertSoundEnabled
        )
        fillerAlertDebugLine = alertDecision.debugLine

        if alertDecision.shouldPlay {
            CoachHaptic.fillerAlert()
            #if canImport(AudioToolbox)
            AudioServicesPlaySystemSound(1104)
            #endif
            print("[FillerAlert] \(alertDecision.debugLine)")
        } else if alertDecision.detectionFired {
            print("[FillerAlert] \(alertDecision.debugLine)")
        }

        // Pressure Drill mode: stricter sudden death threshold
        if _pressureDrillMode {
            pressureDrillFillerCount = allDetections.filter { $0.confidence >= FillerDetection.suddenDeathThreshold }.count
            uncertainFillerCount = allDetections.filter { $0.confidence >= 0.4 && $0.confidence < FillerDetection.suddenDeathThreshold }.count
        }
    }

    // MARK: - Session Management

    func resetCurrentSession() {
        transcribedText = ""
        highlightedText = AttributedString("")
        fillerWordCount = 0
        pressureDrillFillerCount = 0
        uncertainFillerCount = 0
        fillerAlertDebugLine = nil
        fillerAlertGate.reset()
        _pressureDrillMode = false
        finalTranscript = ""
        partialTranscript = ""
        connectionError = nil
        // M26 — drop the prior session's vocal-energy samples so the
        // accumulator starts clean for the next rep. The audio tap
        // begins appending again the moment recording resumes.
        vocalEnergyAccumulator.reset()
    }

    private func saveCurrentSession() {
        let duration = Date().timeIntervalSince(sessionStart ?? Date())
        lastSessionDuration = duration
        let trimmed = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, duration >= 1 else {
            FlowLog.log(
                correlationId: currentRepCorrelationID,
                flow: .practiceRep,
                stage: "rep.aborted",
                outcome: .skipped,
                reason: "empty or under 1s — not saved, not scored, no progress",
                numerics: ["durationMs": Int(duration * 1000), "words": trimmed.split(separator: " ").count]
            )
            sessionStart = nil
            lastSavedSessionID = nil
            return
        }
        guard shouldRecordPracticeSession, currentSessionMode != .imConversation else {
            sessionStart = nil
            lastSavedSessionID = nil
            pastSessions = sessionStore.sessions
            return
        }
        let avgConfidence = confidenceValues.isEmpty ? nil : confidenceValues.reduce(0, +) / Double(confidenceValues.count)
        let pressureOn = PracticeSettingsManager.shared.pressureModeEnabled
        let pressure = BaselineEngine.classifyPressure(
            mode: currentSessionMode,
            isPressureModeOn: pressureOn,
            streakDays: PracticeSession.calculateStreak(from: sessionStore.sessions)
        )
        let pauseMetrics = currentSessionPauseMetrics()
        let pitchMetrics = currentSessionPitchMetrics()
        // M26 — finalize the vocal-energy accumulator. Returns nil
        // when the rep is too thin (≥ minimumSampleFloor samples
        // required) so we never persist a fabricated read on a 1-2s
        // session.
        let vocalEnergyMetrics = vocalEnergyAccumulator.finalize()
        // Positional read of WHERE this rep's events fell, derived offline from
        // the captured per-word timings (otherwise discarded after PauseMetrics)
        // via the pure TranscriptTimeline. Nil when no credible positional
        // signal, so we never persist a fabricated "you rushed at the close".
        let repEventLocations = RepEventLocationsEngine.derive(
            timeline: TranscriptTimeline(
                words: sessionWordTimings,
                fillerWords: FillerWordDetector.effectiveWordSet()
            )
        )
        let finalizedSession = PracticeSessionFinalizer.finalize(
            store: sessionStore,
            draft: PracticeSessionDraft(
                transcript: transcribedText,
                fillerWordCount: fillerWordCount,
                duration: duration,
                date: sessionStart ?? Date(),
                mode: currentSessionMode,
                transcriptConfidence: avgConfidence,
                transcriptionProvider: activeProviderIdentifier,
                pressureLevel: pressure,
                isRated: pressureOn,
                pauseMetrics: pauseMetrics,
                pitchMetrics: pitchMetrics,
                vocalEnergyMetrics: vocalEnergyMetrics,
                repEventLocations: repEventLocations
            )
        )
        lastSavedSessionID = finalizedSession.id
        FlowLog.log(
            correlationId: finalizedSession.id,
            flow: .practiceRep,
            stage: "rep.saved",
            reason: "\(currentSessionMode.rawValue) rep persisted",
            numerics: [
                "words": trimmed.split(separator: " ").count,
                "durationMs": Int(duration * 1000),
                "fillers": fillerWordCount,
            ]
        )
        pastSessions = sessionStore.sessions
        sessionStart = nil
    }

    private func loadSessions() {
        sessionStore.reload()
        pastSessions = sessionStore.sessions
    }

    // MARK: - Quality Metrics

    private func recordQualityMetrics() {
        let duration = Date().timeIntervalSince(sessionStart ?? Date())
        let avgLatency = sessionUpdateCount > 0 ? totalLatencyMs / sessionUpdateCount : 0
        let avgConfidence = confidenceValues.isEmpty ? nil : confidenceValues.reduce(0, +) / Double(confidenceValues.count)
        let wordCount = transcribedText.split { !$0.isLetter && !$0.isNumber }.count

        let metric = TranscriptionQualityMetrics(
            provider: activeProviderIdentifier,
            sessionId: UUID(),
            date: Date(),
            totalLatencyMs: avgLatency,
            finalTranscriptLength: wordCount,
            fillerWordsDetected: fillerWordCount,
            providerFillersDetected: providerFillerCount,
            averageConfidence: avgConfidence,
            sessionDuration: duration
        )
        TranscriptionQualityStore.shared.record(metric)
    }
}

#if DEBUG
/// Deterministic UI-test seam for the provider-start recovery path. It is
/// selected only by an explicit launch argument and cannot enter Release.
private struct UITestUnavailableTranscriptionProvider: TranscriptionProvider {
    let name = "Unavailable UI test provider"
    let identifier = "ui-test-unavailable"

    func startSession(config: TranscriptionConfig) async throws -> any TranscriptionSession {
        _ = config
        throw TranscriptionSessionError.transport("UI test provider start failure")
    }
}
#endif
#endif

struct PracticeSession: Identifiable, Codable {
    var id: UUID = UUID()
    let transcript: String
    let fillerWordCount: Int
    let duration: TimeInterval
    let date: Date
    var mode: PracticeMode = .ahCounter
    var imConversationDetails: IMConversationDetails? = nil
    var score: Int? = nil
    var xpEarned: Int? = nil
    var headline: String? = nil
    var insights: [String] = []
    var coachSummary: String? = nil
    var aiCoachFeedback: AICoachFeedback? = nil
    var prompt: String? = nil
    var theme: PromptTheme? = nil
    var drillResult: DrillResult? = nil
    var transcriptConfidence: Double? = nil
    var transcriptionProvider: String? = nil
    var pressureLevel: PressureLevel = .standard
    var isRated: Bool = false
    /// Pause statistics for this session. Optional because (a) older
    /// persisted sessions decode without it, and (b) some transcription
    /// providers may not emit word-level timings on certain reps.
    var pauseMetrics: PauseMetrics? = nil
    /// Pitch statistics for this session (M10). Optional because legacy
    /// persisted sessions don't carry it and because some recording paths
    /// (paused-mid-rep, extremely short reps) won't produce reliable f0.
    var pitchMetrics: PitchMetrics? = nil
    // NOTE: parallel teammate `pitch-intonation-v1` is also adding a field
    // at the end of this struct. Merge order is mechanical — both fields
    // co-exist without interaction.
    /// Grammar findings for this session (M16). Optional because (a) older
    /// sessions decode without it, (b) the grammar pass skips short / noisy /
    /// non-English / non-Pro reps, and (c) the rubric is strict — most reps
    /// produce nothing. Empty array means "ran and found nothing worth
    /// surfacing"; nil means "didn't run".
    var grammarFindings: [GrammarFinding]? = nil
    /// M21: the coaching priority the user declared they were focusing on
    /// before this rep started, if any. Nil for sessions where the user
    /// dismissed the intent prompt or for older persisted sessions. Drives
    /// the "You aimed for this" chip on the summary cards + the "Intent
    /// declared" line in the Ask Noum context block.
    var intentFocus: CoachingPriority? = nil
    /// M21: the user-visible chip label that matched the declared intent
    /// (e.g. "Cut fillers", "Tighten structure"). Persisted alongside
    /// `intentFocus` so the coach can quote the exact label back at the
    /// user rather than paraphrasing.
    var intentLabel: String? = nil
    /// M26: per-session vocal-energy aggregate (mean RMS, peak,
    /// steadiness). Optional because (a) older persisted sessions
    /// decode without it and (b) reps shorter than the accumulator's
    /// minimumSampleFloor return nil rather than a fabricated read.
    /// Feeds the coach context block so the AI can comment on HOW the
    /// user sounded, not only what they said.
    var vocalEnergyMetrics: VocalEnergyMetrics? = nil
    /// WHERE this rep's notable events fell (longest pause / fastest stretch /
    /// filler cluster, by opening/middle/close third). Optional because older
    /// persisted sessions decode without it and reps with no credible
    /// positional signal derive nil. Feeds the coach context so the AI can give
    /// a positional read, not only whole-rep averages.
    var repEventLocations: RepEventLocations? = nil
    /// True only for version-controlled evaluation-corpus sessions. These
    /// sessions are test substrate and must never enter live user history,
    /// baselines, ratings, league surfaces, or backend sync.
    var isEvaluationFixture: Bool = false
    /// Stable, human-readable fixture key for evaluation snapshots. Nil for
    /// every real user session.
    var fixtureID: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case transcript
        case fillerWordCount
        case duration
        case date
        case mode
        case imConversationDetails
        case score
        case xpEarned
        case headline
        case insights
        case coachSummary
        case aiCoachFeedback
        case prompt
        case theme
        case drillResult
        case transcriptConfidence
        case transcriptionProvider
        case pressureLevel
        case isRated
        case pauseMetrics
        case pitchMetrics
        case grammarFindings
        case intentFocus
        case intentLabel
        case vocalEnergyMetrics
        case repEventLocations
        case isEvaluationFixture
        case fixtureID
    }

    init(
        id: UUID = UUID(),
        transcript: String,
        fillerWordCount: Int,
        duration: TimeInterval,
        date: Date,
        mode: PracticeMode = .ahCounter,
        imConversationDetails: IMConversationDetails? = nil,
        score: Int? = nil,
        xpEarned: Int? = nil,
        headline: String? = nil,
        insights: [String] = [],
        coachSummary: String? = nil,
        aiCoachFeedback: AICoachFeedback? = nil,
        prompt: String? = nil,
        theme: PromptTheme? = nil,
        drillResult: DrillResult? = nil,
        transcriptConfidence: Double? = nil,
        transcriptionProvider: String? = nil,
        pressureLevel: PressureLevel = .standard,
        isRated: Bool = false,
        pauseMetrics: PauseMetrics? = nil,
        pitchMetrics: PitchMetrics? = nil,
        grammarFindings: [GrammarFinding]? = nil,
        intentFocus: CoachingPriority? = nil,
        intentLabel: String? = nil,
        vocalEnergyMetrics: VocalEnergyMetrics? = nil,
        repEventLocations: RepEventLocations? = nil,
        isEvaluationFixture: Bool = false,
        fixtureID: String? = nil
    ) {
        self.id = id
        self.transcript = transcript
        self.fillerWordCount = fillerWordCount
        self.duration = duration
        self.date = date
        self.mode = mode
        self.imConversationDetails = imConversationDetails
        self.score = score
        self.xpEarned = xpEarned
        self.headline = headline
        self.insights = insights
        self.coachSummary = coachSummary
        self.aiCoachFeedback = aiCoachFeedback
        self.prompt = prompt
        self.theme = theme
        self.drillResult = drillResult
        self.transcriptConfidence = transcriptConfidence
        self.transcriptionProvider = transcriptionProvider
        self.pressureLevel = pressureLevel
        self.isRated = isRated
        self.pauseMetrics = pauseMetrics
        self.pitchMetrics = pitchMetrics
        self.grammarFindings = grammarFindings
        self.intentFocus = intentFocus
        self.intentLabel = intentLabel
        self.vocalEnergyMetrics = vocalEnergyMetrics
        self.repEventLocations = repEventLocations
        self.isEvaluationFixture = isEvaluationFixture
        self.fixtureID = fixtureID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        transcript = try container.decode(String.self, forKey: .transcript)
        fillerWordCount = try container.decode(Int.self, forKey: .fillerWordCount)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        date = try container.decode(Date.self, forKey: .date)
        mode = try container.decodeIfPresent(PracticeMode.self, forKey: .mode) ?? .ahCounter
        imConversationDetails = try container.decodeIfPresent(IMConversationDetails.self, forKey: .imConversationDetails)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        xpEarned = try container.decodeIfPresent(Int.self, forKey: .xpEarned)
        headline = try container.decodeIfPresent(String.self, forKey: .headline)
        insights = try container.decodeIfPresent([String].self, forKey: .insights) ?? []
        coachSummary = try container.decodeIfPresent(String.self, forKey: .coachSummary)
        aiCoachFeedback = try container.decodeIfPresent(AICoachFeedback.self, forKey: .aiCoachFeedback)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        theme = try container.decodeIfPresent(PromptTheme.self, forKey: .theme)
        drillResult = try container.decodeIfPresent(DrillResult.self, forKey: .drillResult)
        transcriptConfidence = try container.decodeIfPresent(Double.self, forKey: .transcriptConfidence)
        transcriptionProvider = try container.decodeIfPresent(String.self, forKey: .transcriptionProvider)
        pressureLevel = try container.decodeIfPresent(PressureLevel.self, forKey: .pressureLevel) ?? .standard
        isRated = try container.decodeIfPresent(Bool.self, forKey: .isRated) ?? false
        pauseMetrics = try container.decodeIfPresent(PauseMetrics.self, forKey: .pauseMetrics)
        pitchMetrics = try container.decodeIfPresent(PitchMetrics.self, forKey: .pitchMetrics)
        grammarFindings = try container.decodeIfPresent([GrammarFinding].self, forKey: .grammarFindings)
        intentFocus = try container.decodeIfPresent(CoachingPriority.self, forKey: .intentFocus)
        intentLabel = try container.decodeIfPresent(String.self, forKey: .intentLabel)
        vocalEnergyMetrics = try container.decodeIfPresent(VocalEnergyMetrics.self, forKey: .vocalEnergyMetrics)
        repEventLocations = try container.decodeIfPresent(RepEventLocations.self, forKey: .repEventLocations)
        isEvaluationFixture = try container.decodeIfPresent(Bool.self, forKey: .isEvaluationFixture) ?? false
        fixtureID = try container.decodeIfPresent(String.self, forKey: .fixtureID)
    }
}
