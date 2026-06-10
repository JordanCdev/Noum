#if canImport(SwiftUI)
import Foundation
import SwiftUI
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - Live-call STT engine chain (pure decision logic)

/// C5 — provider-selection / fallback decisions for live-call speech input.
///
/// The live call previously depended ENTIRELY on `SFSpeechRecognizer`, which
/// has no working recognition backend on many simulators and can be
/// transiently unavailable on device — the diagnosed "silent dead mic". The
/// fix gives the call the same cloud transcription chain practice reps use
/// (resolved from the persisted `transcriptionProvider` default through
/// `TranscriptionProviderID.resolved(fromStoredValue:)`), with native Apple
/// recognition as the ALWAYS-terminal fallback: a missing key / exhausted
/// quota / dead backend degrades to Apple transcription instead of a dead
/// mic, and when no engine can serve at all the UI says so honestly via
/// `AskNoumVoiceInput.notice` — never a silent "Listening…" that hears
/// nothing.
///
/// Pure + view-free so the selection and fallback decisions are
/// unit-testable without a recognizer, a network, or an audio engine.
enum LiveCallSTTChain {

    /// One speech-input engine the live call can listen through.
    enum Engine: Equatable {
        /// A cloud `TranscriptionProvider` (Deepgram / Google / AWS — the
        /// same registry practice reps stream through).
        case cloud(TranscriptionProviderID)
        /// Native Apple recognition (`SFSpeechRecognizer`).
        case native
    }

    /// Ordered engines for ONE recording attempt. The user's configured
    /// cloud provider leads (same defaulting rule as practice reps); native
    /// Apple recognition is the terminal fallback. A cloud provider that
    /// already failed this surface session (`cloudMarkedUnhealthy`) is
    /// skipped rather than re-tried on every hands-free turn — the retry
    /// cost would be a doomed network round-trip between every utterance.
    static func engineOrder(
        configuredProviderRawValue: String?,
        cloudMarkedUnhealthy: Bool,
        nativeAvailable: Bool
    ) -> [Engine] {
        var order: [Engine] = []
        if !cloudMarkedUnhealthy {
            order.append(.cloud(TranscriptionProviderID.resolved(fromStoredValue: configuredProviderRawValue)))
        }
        if nativeAvailable {
            order.append(.native)
        }
        return order
    }

    /// Honest "who is listening" label for the call UI, so a fallback is
    /// VISIBLE, not pretended. Deliberately does not say "on-device" for the
    /// native engine — `SFSpeechRecognizer` may route to Apple's servers
    /// when the on-device model isn't ready, so "Apple transcription" is
    /// the strongest claim that is always true.
    static func engineDescription(for engine: Engine) -> String {
        switch engine {
        case .cloud: return "Cloud transcription"
        case .native: return "Apple transcription"
        }
    }
}

// MARK: - Ask Noum voice input
//
// Lightweight push-to-talk speech input used by the Ask-Noum chat surface
// and the live coach call. Distinct from `SpeechRecognizerViewModel` —
// which is built around full-session lifecycle (pitch analyzer, pause
// metrics, semantic filler detection, session persistence) and would be a
// sledgehammer for a 3-10s utterance. This wrapper:
//
//   • Captures one short utterance (typical 3-10s, hard cap 30s).
//   • Listens through the `LiveCallSTTChain` engine order: the configured
//     cloud `TranscriptionProvider` first (same chain practice reps use),
//     falling back to `SFSpeechRecognizer` when the cloud provider can't
//     serve (missing key, exhausted quota, backend down, stream death).
//   • Has three observable states: `.idle`, `.recording`, `.processing`.
//   • Cancels cleanly on user request so a half-utterance never reaches
//     the chat thread.
//   • Yields the final transcript through a single closure callback at
//     end-of-utterance; the view turns that into a user turn the same
//     way a typed message would land.
//
// Permission model:
//   • `NSSpeechRecognitionUsageDescription` already lives in Info.plist.
//   • `NSMicrophoneUsageDescription` already lives in Info.plist.
//   • First press triggers both `SFSpeechRecognizer.requestAuthorization`
//     and `AVAudioApplication.requestRecordPermission` in sequence; the user
//     either grants both and we proceed, or we surface a typed-mode
//     fallback prompt via the `unavailableReason` published property.
//
// Voice-mode is additive: the text input bar stays. If a user denies
// permissions, the mic button hides itself (not a dead toggle —
// `isAvailable` gates the whole UI) and the typed flow keeps working
// untouched.

@available(iOS 17.0, *)
@MainActor
final class AskNoumVoiceInput: ObservableObject {

    /// Lifecycle stages the view binds against. `.processing` is brief
    /// (~150-400ms while the active engine finalises the buffered
    /// audio) — the view shows a shimmer ring for continuity, then the
    /// transcript callback fires and we fall back to `.idle`.
    enum State: Equatable {
        case idle
        case recording
        case processing
    }

    /// Why voice input is unavailable on this device/locale, if it is.
    /// Drives the "is the mic button visible at all" gate in the view —
    /// we never render a dead button.
    enum UnavailableReason: Equatable {
        /// Locale isn't supported by any speech engine on this build
        /// (only reachable when the Speech framework itself is absent).
        /// User can still type.
        case localeUnsupported
        /// User denied speech-recognition permission. User can still
        /// type; we could surface a one-time settings-link nudge.
        case permissionDenied
        /// User denied microphone permission. Same fallback path.
        case microphoneDenied
        /// No engine in the chain could serve right now (cloud provider
        /// failed AND native recognition unavailable/errored). Will retry
        /// on next press.
        case temporarilyUnavailable
    }

    @Published private(set) var state: State = .idle
    /// Live partial transcript surfaced while recording. The view can
    /// render this as a soft "I'm hearing…" preview under the mic
    /// button if useful; today we only show it accessibly so VoiceOver
    /// users hear progress. The final transcript is what lands in the
    /// chat thread.
    @Published private(set) var partialTranscript: String = ""
    /// Nil while the wrapper is available + authorised; set to a
    /// specific reason when the mic button should hide / explain.
    @Published private(set) var unavailableReason: UnavailableReason? = nil
    /// Honest "who is listening" label for the engine serving the CURRENT
    /// recording (`LiveCallSTTChain.engineDescription`). Nil while idle.
    /// Lets the call UI show that a fallback engine took over instead of
    /// silently pretending the premium path is live.
    @Published private(set) var activeEngineDescription: String? = nil

    /// Maximum utterance length. Past this we auto-finalise so a stuck
    /// session doesn't hold the mic open forever. 30s is generous for
    /// an ask-coach question — most are under 10s.
    private static let maxUtteranceDuration: TimeInterval = 30.0

    /// Threshold below which we treat the utterance as "user changed
    /// their mind" rather than a real question. Skips dispatching the
    /// chat turn and resets to idle silently.
    private static let minUtteranceCharacters = 2

    #if canImport(Speech)
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    #endif
    #if canImport(AVFoundation)
    private var audioEngine: AVAudioEngine?
    #endif
    private var maxDurationTimer: Task<Void, Never>?

    // Cloud-engine state (the leading link of `LiveCallSTTChain`).
    private var cloudSession: (any TranscriptionSession)?
    private var cloudListenerTask: Task<Void, Never>?
    /// Finalised cloud segments accumulated so far. Cloud providers emit
    /// rolling per-segment partials (not a cumulative transcript), so the
    /// published `partialTranscript` is always `cloudFinalText` + the live
    /// segment.
    private var cloudFinalText: String = ""
    /// Sticky per-instance: the cloud provider failed (no key, quota,
    /// stream death). Subsequent attempts on this surface session skip
    /// straight to native instead of paying a doomed round-trip on every
    /// hands-free turn. A fresh view mount retries the cloud path.
    private var cloudUnhealthy = false
    /// Which engine is serving the current recording, if any.
    private var activeEngine: LiveCallSTTChain.Engine?

    /// Called exactly once per successful utterance with the final
    /// transcript. The view turns this into a user turn (same path as
    /// typing). Never called for cancelled or empty utterances.
    var onFinalTranscript: ((String) -> Void)?

    init() {
        #if canImport(Speech)
        // Try the user's preferred speech-locale; fall back to en-US.
        // A nil recognizer no longer blocks voice input outright — the
        // cloud link of `LiveCallSTTChain` can still serve (its locale
        // comes from `LocaleSettingsManager`, not `SFSpeechRecognizer`'s
        // narrower support table) — so we leave `unavailableReason` nil
        // and let the chain decide at record time.
        let preferred = Locale.preferredLanguages.first.flatMap(Locale.init(identifier:)) ?? Locale(identifier: "en-US")
        if let rec = SFSpeechRecognizer(locale: preferred), rec.isAvailable {
            recognizer = rec
        } else if let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), rec.isAvailable {
            recognizer = rec
        } else {
            recognizer = nil
        }
        #else
        unavailableReason = .localeUnsupported
        #endif
    }

    /// True when the mic button should be rendered at all. The first press
    /// still asks for permission live, but if either permission has already
    /// been denied we hide rather than dead-toggle. A transient engine
    /// failure stays retryable: the user should be able to tap again after
    /// the notice instead of losing the mic affordance. A nil native
    /// recognizer does NOT make voice unavailable — the cloud engine may
    /// still serve, and if the whole chain fails the attempt surfaces an
    /// honest `.temporarilyUnavailable` notice instead.
    var isAvailable: Bool {
        #if canImport(Speech) && canImport(AVFoundation)
        return Self.reasonAllowsRetry(unavailableReason)
        #else
        return false
        #endif
    }

    /// A brief, honest user-facing line for when voice can't proceed — so the
    /// mic never silently "does nothing". Nil when voice is fine.
    var notice: String? { Self.notice(for: unavailableReason) }

    /// Pure reason → message mapping, isolated so it's unit-testable without
    /// standing up the recognizer or touching the `private(set)` state.
    nonisolated static func notice(for reason: UnavailableReason?) -> String? {
        switch reason {
        case .none:
            return nil
        case .localeUnsupported:
            return "Voice input isn't supported for your language yet — type your question instead."
        case .permissionDenied:
            return "Speech access is off. Turn it on in Settings, or type your question."
        case .microphoneDenied:
            return "Mic access is off. Turn it on in Settings, or type your question."
        case .temporarilyUnavailable:
            return "Voice isn't ready just now — try again in a moment, or type your question."
        }
    }

    /// Transient unavailability is a retry state, not a hard "voice is gone"
    /// state. Permission/locale failures hide the mic because another tap
    /// cannot fix them inside the app.
    nonisolated static func reasonAllowsRetry(_ reason: UnavailableReason?) -> Bool {
        reason == nil || reason == .temporarilyUnavailable
    }

    // MARK: - Tap-to-toggle lifecycle

    /// Primary entry point: tap once to start recording, tap again to stop
    /// and send. Replaces the old hold-to-talk press / release / drag-cancel
    /// model. Idempotent — a tap while `.processing` is a no-op so a
    /// double-tap during finalisation doesn't race the recognizer callback.
    func toggle() {
        switch state {
        case .idle:
            Task { @MainActor in
                clearTransientUnavailableIfNeeded()
                await requestPermissionsIfNeeded()
                guard unavailableReason == nil else { return }
                await startRecognition()
            }
        case .recording:
            stopAndSend()
        case .processing:
            break // wait for finalisation; the UI shows .processing state
        }
    }

    /// Finalise the recognition and route the trimmed transcript through
    /// `onFinalTranscript`. Called internally from `toggle()` when the
    /// user taps to stop. Also callable from `runReply` via the Send
    /// button tap while recording is active.
    func stopAndSend() {
        guard state == .recording else { return }
        state = .processing
        switch activeEngine {
        case .cloud:
            // Stop feeding audio, then signal end-of-stream; the listener
            // task delivers the accumulated transcript when the stream
            // closes (see `handleCloudStreamEnded`).
            stopAudioEngine()
            let session = cloudSession
            Task { try? await session?.endAudio() }
        case .native, nil:
            #if canImport(Speech)
            request?.endAudio()
            #endif
            stopAudioEngine()
        }
        // Defensive timeout — if finalisation hangs (either engine),
        // surface whatever partial we have and reset.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if state == .processing {
                deliverFinalIfAble(textOverride: partialTranscript)
                resetToIdle()
            }
        }
    }

    /// Cancel an in-progress recording entirely. Nothing reaches the chat
    /// thread. Exposed for cases where the view needs to clean up (e.g.
    /// view disappears while recording).
    func cancelRecording() {
        #if canImport(Speech)
        task?.cancel()
        request = nil
        task = nil
        #endif
        stopAudioEngine()
        cloudListenerTask?.cancel()
        cloudListenerTask = nil
        if let session = cloudSession {
            cloudSession = nil
            Task { try? await session.endAudio() }
        }
        cloudFinalText = ""
        activeEngine = nil
        activeEngineDescription = nil
        partialTranscript = ""
        maxDurationTimer?.cancel()
        maxDurationTimer = nil
        state = .idle
    }

    // MARK: - Legacy press lifecycle (kept for internal use only)

    func beginPress() {
        guard state == .idle else { return }
        Task { @MainActor in
            clearTransientUnavailableIfNeeded()
            await requestPermissionsIfNeeded()
            guard unavailableReason == nil else { return }
            await startRecognition()
        }
    }

    func endPressAndSend() {
        stopAndSend()
    }

    func cancelPress() {
        cancelRecording()
    }

    // MARK: - Permission + lifecycle internals

    private func requestPermissionsIfNeeded() async {
        #if canImport(Speech)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                SFSpeechRecognizer.requestAuthorization { _ in
                    cont.resume()
                }
            }
        }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .denied, .restricted, .notDetermined:
            unavailableReason = .permissionDenied
            return
        @unknown default:
            unavailableReason = .permissionDenied
            return
        }
        #endif

        #if canImport(AVFoundation)
        let session = AVAudioSession.sharedInstance()
        // `.playAndRecord` (not `.record`) because the live coach call
        // interleaves mic capture with the coach's TTS playback — a `.record`
        // session can't coexist with playback, so alternating the two thrashed
        // the audio route (failed mic starts / "timed out waiting for Stop").
        // `.spokenAudio` keeps voice-optimised processing; `.defaultToSpeaker`
        // routes the coach's voice out loud; `.duckOthers` quiets the soundscape.
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try session.setActive(true, options: [])
        } catch {
            unavailableReason = .temporarilyUnavailable
            return
        }
        let micStatus = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        if !micStatus {
            unavailableReason = .microphoneDenied
            return
        }
        #endif
    }

    /// Walk the `LiveCallSTTChain` engine order until one engine starts.
    /// Cloud first (same provider practice reps use), native Apple
    /// recognition terminal. Exhausting the chain surfaces an honest
    /// `.temporarilyUnavailable` — never a silent dead mic.
    private func startRecognition() async {
        #if canImport(Speech) && canImport(AVFoundation)
        let order = LiveCallSTTChain.engineOrder(
            configuredProviderRawValue: UserDefaults.standard.string(forKey: "transcriptionProvider"),
            cloudMarkedUnhealthy: cloudUnhealthy,
            nativeAvailable: recognizer?.isAvailable == true
        )
        for engine in order {
            switch engine {
            case .cloud(let providerID):
                if await startCloudRecognition(providerID: providerID) { return }
                // Key missing / quota exhausted / backend down — remember
                // and degrade to native for the rest of this surface session.
                cloudUnhealthy = true
            case .native:
                if startNativeRecognition() { return }
            }
        }
        unavailableReason = .temporarilyUnavailable
        #endif
    }

    // MARK: - Cloud engine (leading link)

    /// Start a streaming session on the configured cloud provider. Returns
    /// false on ANY setup failure (key resolution throw, dead input format,
    /// engine start throw) so the chain can fall through to native.
    private func startCloudRecognition(providerID: TranscriptionProviderID) async -> Bool {
        #if canImport(AVFoundation)
        let provider = SpeechRecognizerViewModel.makeProvider(for: providerID)
        let config = TranscriptionConfig(
            languageCode: LocaleSettingsManager.shared.current.code,
            sampleRate: Int(AVAudioSession.sharedInstance().sampleRate),
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: false
        )
        let session: any TranscriptionSession
        do {
            session = try await provider.startSession(config: config)
        } catch {
            return false
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            Task { try? await session.endAudio() }
            return false
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            let data = SpeechRecognizerViewModel.pcm16Data(from: buffer)
            Task { try? await session.sendAudio(data) }
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            Task { try? await session.endAudio() }
            return false
        }

        audioEngine = engine
        cloudSession = session
        cloudFinalText = ""
        partialTranscript = ""
        unavailableReason = nil
        activeEngine = .cloud(providerID)
        activeEngineDescription = LiveCallSTTChain.engineDescription(for: .cloud(providerID))
        state = .recording

        cloudListenerTask = Task { @MainActor [weak self] in
            for await update in session.transcriptUpdates {
                guard let self, self.cloudSession === session else { return }
                self.handleCloudUpdate(update)
            }
            guard let self, self.cloudSession === session else { return }
            self.handleCloudStreamEnded()
        }

        armMaxDurationTimer()
        return true
        #else
        return false
        #endif
    }

    private func handleCloudUpdate(_ update: TranscriptUpdate) {
        let snippet = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else { return }
        if update.isFinal {
            if !cloudFinalText.isEmpty { cloudFinalText += " " }
            cloudFinalText += snippet
            partialTranscript = cloudFinalText
        } else {
            partialTranscript = cloudFinalText.isEmpty ? snippet : cloudFinalText + " " + snippet
        }
    }

    /// The cloud transcript stream closed. Either we asked it to
    /// (`stopAndSend` → deliver the final), or it died mid-utterance
    /// (socket drop / quota cut) — degrade for the rest of this surface
    /// session, salvage what was heard, and surface the retry notice.
    private func handleCloudStreamEnded() {
        switch state {
        case .processing:
            deliverFinalIfAble(textOverride: partialTranscript)
            resetToIdle()
        case .recording:
            cloudUnhealthy = true
            stopAudioEngine()
            let heard = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if heard.count >= Self.minUtteranceCharacters {
                deliverFinalIfAble(textOverride: heard)
            } else {
                unavailableReason = .temporarilyUnavailable
            }
            resetToIdle()
        case .idle:
            break
        }
    }

    // MARK: - Native engine (terminal fallback)

    /// Start `SFSpeechRecognizer`. Returns false on any setup failure so the
    /// caller (the chain walker) owns the "nothing could serve" decision;
    /// mid-utterance task errors still surface `.temporarilyUnavailable`
    /// directly because native is the terminal engine.
    private func startNativeRecognition() -> Bool {
        #if canImport(Speech) && canImport(AVFoundation)
        guard let recognizer = recognizer, recognizer.isAvailable else {
            return false
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // Prefer on-device recognition WITHOUT hard-requiring it. Leaving
        // `requiresOnDeviceRecognition` at its default (false) lets the system
        // use on-device when it's available/ready (the common case on a warmed-
        // up device — keeps the user's coaching questions off the network) AND
        // fall back to cloud when the on-device model isn't ready yet (first
        // use, still downloading, or the simulator). Previously this HARD-
        // required on-device (`= true`), which DEFEATED the documented cloud
        // fallback: when the model wasn't ready, recognition failed silently
        // and the mic appeared to "do nothing". We no longer force the flag.
        request = req

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            request = nil
            return false
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            request = nil
            return false
        }
        audioEngine = engine

        partialTranscript = ""
        unavailableReason = nil
        activeEngine = .native
        activeEngineDescription = LiveCallSTTChain.engineDescription(for: .native)
        state = .recording

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let result = result {
                    self.partialTranscript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.deliverFinalIfAble(textOverride: result.bestTranscription.formattedString)
                        self.resetToIdle()
                    }
                }
                if error != nil, self.state != .idle {
                    // Surface transient recognizer failures so the mic never
                    // appears to do nothing. The retry gate keeps the mic
                    // visible for another tap.
                    self.unavailableReason = .temporarilyUnavailable
                    self.resetToIdle()
                }
            }
        }

        armMaxDurationTimer()
        return true
        #else
        return false
        #endif
    }

    /// Hard ceiling so a stuck recognition doesn't camp on the mic.
    /// Shared by both engines.
    private func armMaxDurationTimer() {
        maxDurationTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.maxUtteranceDuration * 1_000_000_000))
            if self.state == .recording {
                self.endPressAndSend()
            }
        }
    }

    /// Tear down the audio engine + tap. Safe to call multiple times.
    private func stopAudioEngine() {
        #if canImport(AVFoundation)
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        #endif
    }

    /// Reset the wrapper to `.idle`. Called from finalisation and from
    /// error paths. Does NOT clear `unavailableReason` — that's a
    /// stickier state controlled by the permission/availability paths.
    private func resetToIdle() {
        #if canImport(Speech)
        task = nil
        request = nil
        #endif
        cloudListenerTask?.cancel()
        cloudListenerTask = nil
        cloudSession = nil
        cloudFinalText = ""
        activeEngine = nil
        activeEngineDescription = nil
        partialTranscript = ""
        maxDurationTimer?.cancel()
        maxDurationTimer = nil
        state = .idle
    }

    private func clearTransientUnavailableIfNeeded() {
        if unavailableReason == .temporarilyUnavailable {
            unavailableReason = nil
        }
    }

    /// Deliver the final transcript if it clears the minimum-length
    /// gate. Empty / tiny utterances (mic-tap-by-accident, single
    /// throat-clear) are dropped without firing the callback so the
    /// chat thread never gets junk turns.
    private func deliverFinalIfAble(textOverride: String) {
        let trimmed = textOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= Self.minUtteranceCharacters {
            onFinalTranscript?(trimmed)
        }
    }
}

#endif
