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
//     and `AVAudioSession.requestRecordPermission` in sequence; the user
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
    /// already been denied we hide rather than dead-toggle.
    var isAvailable: Bool {
        guard unavailableReason == nil else { return false }
        #if canImport(Speech)
        return recognizer != nil
        #else
        return false
        #endif
    }

    // MARK: - Press lifecycle

    /// Called on press-down (`DragGesture.onChanged` first event). Kicks
    /// permission requests if needed, then starts the recognition task.
    /// Idempotent — extra calls while already `.recording` are no-ops.
    func beginPress() {
        guard state == .idle else { return }
        Task { @MainActor in
            await requestPermissionsIfNeeded()
            guard unavailableReason == nil else { return }
            startRecognition()
        }
    }

    /// Called on press-up inside the button bounds. Finalises the
    /// recognition and routes the trimmed transcript through
    /// `onFinalTranscript`. Empty / tiny utterances are dropped silently.
    func endPressAndSend() {
        #if canImport(Speech)
        guard state == .recording else { return }
        state = .processing
        // Tell the recognizer the audio stream is done; the task will
        // finalise and fire its callback one more time with `isFinal`.
        request?.endAudio()
        stopAudioEngine()
        // Defensive timeout — if the recognizer hangs on finalisation,
        // we surface whatever partial we have and reset.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if state == .processing {
                deliverFinalIfAble(textOverride: partialTranscript)
                resetToIdle()
            }
        }
        #endif
    }

    /// Called on press-up *outside* the button bounds (user dragged
    /// off to cancel). Drops the captured audio entirely; nothing
    /// reaches the chat thread.
    func cancelPress() {
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
        // Use `.record` with `.spokenAudio` mode so the OS treats our
        // capture as voice input — quieter mic processing, no music
        // ducking surprises. Ask Noum's chat doesn't need playback so
        // we don't entangle with the soundscape mixer.
        do {
            try session.setCategory(.record, mode: .spokenAudio, options: [])
            try session.setActive(true, options: [])
        } catch {
            unavailableReason = .temporarilyUnavailable
            return
        }
        let micStatus = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            session.requestRecordPermission { granted in
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
        // Prefer on-device recognition where the recognizer supports it.
        // Keeps the user's coaching questions off Apple's servers and
        // adds zero latency vs cloud. If on-device isn't supported the
        // request falls back to cloud automatically.
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            unavailableReason = .temporarilyUnavailable
            inputNode.removeTap(onBus: 0)
            return
        }
        audioEngine = engine

        partialTranscript = ""
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
                if error != nil {
                    // Don't surface as unavailable — a transient error
                    // shouldn't permanently hide the mic. Just reset.
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
