#if canImport(SwiftUI)
import Foundation
import SwiftUI
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - Ask Noum voice input
//
// Lightweight, on-device push-to-talk wrapper around `SFSpeechRecognizer`
// used by the Ask-Noum chat surface. Distinct from
// `SpeechRecognizerViewModel` — which is built around full-session
// lifecycle (pitch analyzer, pause metrics, semantic filler detection,
// session persistence, multi-provider AWS/Deepgram/Google abstraction)
// and would be a sledgehammer for a 3-10s utterance. This wrapper:
//
//   • Captures one short utterance (typical 3-10s, hard cap 30s).
//   • Runs `SFSpeechRecognizer` with on-device recognition preferred
//     when the locale supports it — no network round-trip, no cloud
//     transcript exposure for the user's coaching questions.
//   • Has three observable states: `.idle`, `.recording`, `.processing`.
//   • Cancels cleanly on user request (drag finger off the mic button)
//     so a half-utterance never reaches the chat thread.
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
// permissions or the device's locale isn't supported by SFSpeechRecognizer,
// the mic button hides itself (not a dead toggle — `isAvailable` gates
// the whole UI) and the typed flow keeps working untouched.

@available(iOS 17.0, *)
@MainActor
final class AskNoumVoiceInput: ObservableObject {

    /// Lifecycle stages the view binds against. `.processing` is brief
    /// (~150-400ms while SFSpeechRecognizer finalises the buffered
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
        /// Locale isn't supported by SFSpeechRecognizer (e.g. obscure
        /// regional variant). User can still type.
        case localeUnsupported
        /// User denied speech-recognition permission. User can still
        /// type; we could surface a one-time settings-link nudge.
        case permissionDenied
        /// User denied microphone permission. Same fallback path.
        case microphoneDenied
        /// SFSpeechRecognizer reported transient unavailability (e.g.
        /// on-device model still downloading). Will retry on next press.
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

    /// Called exactly once per successful utterance with the final
    /// transcript. The view turns this into a user turn (same path as
    /// typing). Never called for cancelled or empty utterances.
    var onFinalTranscript: ((String) -> Void)?

    init() {
        #if canImport(Speech)
        // Try the user's preferred speech-locale; fall back to en-US.
        // SFSpeechRecognizer locale support is narrower than the system's
        // — we surface .localeUnsupported below if neither works.
        let preferred = Locale.preferredLanguages.first.flatMap(Locale.init(identifier:)) ?? Locale(identifier: "en-US")
        if let rec = SFSpeechRecognizer(locale: preferred), rec.isAvailable {
            recognizer = rec
        } else if let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), rec.isAvailable {
            recognizer = rec
        } else {
            recognizer = nil
            unavailableReason = .localeUnsupported
        }
        #else
        unavailableReason = .localeUnsupported
        #endif
    }

    /// True when the mic button should be rendered at all. Reads the
    /// underlying recognizer availability + authorisation cache; the
    /// first press still asks for permission live, but if either has
    /// already been denied we hide rather than dead-toggle. A transient
    /// recognizer failure stays retryable: the user should be able to tap
    /// again after the notice instead of losing the mic affordance.
    var isAvailable: Bool {
        #if canImport(Speech)
        guard recognizer != nil else { return false }
        guard Self.reasonAllowsRetry(unavailableReason) else { return false }
        return true
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
                startRecognition()
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
        #if canImport(Speech)
        guard state == .recording else { return }
        state = .processing
        request?.endAudio()
        stopAudioEngine()
        // Defensive timeout — if the recognizer hangs on finalisation,
        // surface whatever partial we have and reset.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if state == .processing {
                deliverFinalIfAble(textOverride: partialTranscript)
                resetToIdle()
            }
        }
        #endif
    }

    /// Cancel an in-progress recording entirely. Nothing reaches the chat
    /// thread. Exposed for cases where the view needs to clean up (e.g.
    /// view disappears while recording).
    func cancelRecording() {
        #if canImport(Speech)
        task?.cancel()
        stopAudioEngine()
        request = nil
        task = nil
        #endif
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
            startRecognition()
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

    private func startRecognition() {
        #if canImport(Speech) && canImport(AVFoundation)
        guard let recognizer = recognizer, recognizer.isAvailable else {
            unavailableReason = .temporarilyUnavailable
            return
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
            unavailableReason = .temporarilyUnavailable
            request = nil
            resetToIdle()
            return
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            unavailableReason = .temporarilyUnavailable
            inputNode.removeTap(onBus: 0)
            resetToIdle()
            return
        }
        audioEngine = engine

        partialTranscript = ""
        unavailableReason = nil
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

        // Hard ceiling so a stuck recognition doesn't camp on the mic.
        maxDurationTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.maxUtteranceDuration * 1_000_000_000))
            if self.state == .recording {
                self.endPressAndSend()
            }
        }
        #endif
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
