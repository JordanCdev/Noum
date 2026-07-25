import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
import os

// MARK: - Interaction Sound Engine (A2)
//
// Tiny synthesized interaction cues — a verdict thump, a settle tick, a
// drill-complete brush, a streak tock — that land on the same frame as the
// motion + haptic beats the A1 register added. The brand rule stands: no
// melody, no bundled assets. Every cue is non-melodic (single-pitch
// impacts and filtered noise; distinction by timbre, never pitch
// sequence) and synthesized procedurally through the same
// `AVAudioSourceNode` pattern as `SoundscapeEngine`.
//
// Honesty contract (mirrors the motion register):
// - A cue fires only when something REAL just landed: a computed verdict,
//   a number that genuinely increased, a drill that genuinely resolved.
//   No ambient chrome, no per-digit ticking, no celebratory fanfares —
//   celebrations stay RewardEngine `.major`-gated and silent here.
// - The incomplete drill variant is a duller brush, never a fail-buzzer
//   (never punish-shame).
//
// Audio-safety contract:
// - `.ambient` + `.mixWithOthers` session: the device silent switch
//   always wins, music/podcasts keep playing, and we never steal the
//   route from a phone call.
// - HARD-suppressed whenever the mic is open. `SpeechRecognizerViewModel`
//   reports recording state via `noteRecordingActive(_:)`; a cue must
//   never bleed into a transcript or fight the `.playAndRecord` session
//   at a rep boundary. Recording start also stops any in-flight cue.
// - `repStartBreath` is budgeted to hard-finish in 450 ms so the in-rep
//   cluster can land it strictly BEFORE mic activation (verify the gap on
//   a real device before wiring that call site).

// MARK: - Cue vocabulary

/// The approved interaction-cue set (sound plan, A2). Two cues —
/// `repStartBreath` and `coachTurnExhale` — are synthesized and
/// duration-tested here but wired by the in-rep cluster, which owns the
/// rep-start boundary and the live-call turn loop.
enum InteractionCue: String, CaseIterable {
    /// Breath-in swell: pink noise through a rising band-pass
    /// (300→900 Hz), inhale-shaped envelope. Pre-mic handoff cue.
    case repStartBreath
    /// Low warm thump: 90 Hz sine, fast exponential decay, soft noise
    /// transient on the attack. Lands on the score ring's settle frame.
    case verdictReveal
    /// Single dry tick: ~1.8 kHz band-limited click, very quiet. Fires
    /// once per settle (a number landing) — never per digit or frame.
    case countSettle
    /// Soft brush: brown noise swept through a falling low-pass, bright
    /// cutoff start. Drill resolved with criteria met.
    case drillCompleteSuccess
    /// Same brush, duller cutoff start — distinction by timbre, not
    /// pitch sequence, so it reads as "quieter", never as a fail-buzzer.
    case drillCompleteIncomplete
    /// Quiet exhale: low-passed pink noise fading in then out, barely
    /// above the noise floor. Live-call presence punctuation.
    case coachTurnExhale

    /// Hard envelope budget in seconds. The synth is silent at and after
    /// this point — pinned by unit tests so `repStartBreath` can never
    /// grow past the pre-mic gap it must fit inside.
    var duration: TimeInterval {
        switch self {
        case .repStartBreath:          return 0.45
        case .verdictReveal:           return 0.14
        case .countSettle:             return 0.012
        case .drillCompleteSuccess:    return 0.20
        case .drillCompleteIncomplete: return 0.20
        case .coachTurnExhale:         return 0.30
        }
    }

    /// Starting low-pass cutoff for the drill-complete brush. Success is
    /// brighter than incomplete — the only difference between the two
    /// variants, keeping the distinction timbral and non-punishing.
    var drillBrushStartCutoffHz: Double? {
        switch self {
        case .drillCompleteSuccess:    return 1200
        case .drillCompleteIncomplete: return 500
        default:                       return nil
        }
    }
}

// MARK: - Trigger policy (pure)

/// Pure trigger decision, separated from the engine so the suppression
/// invariants are unit-testable without an audio graph.
///
/// Rules:
/// - User toggle off → never. (`InteractionSoundSettings`, default ON;
///   the `.ambient` category means the silent switch wins regardless.)
/// - Mic open → never, for EVERY cue including `repStartBreath` — once
///   recording is active the pre-mic window has already closed, and a
///   cue would bleed into the transcript.
enum InteractionSoundPolicy {
    static func shouldPlay(_ cue: InteractionCue, enabled: Bool, isRecording: Bool) -> Bool {
        enabled && !isRecording
    }
}

// MARK: - Settings

/// Master toggle for interaction cues. Mirrors the `HapticsSettings`
/// ownership pattern: one `@MainActor` singleton for SwiftUI bindings,
/// plus a synchronous nonisolated read for trigger paths. Defaults ON —
/// the cues respect the device silent switch via `.ambient`, so the
/// hardware mute remains the outer gate.
@MainActor
final class InteractionSoundSettings: ObservableObject {
    static let shared = InteractionSoundSettings()

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.storageKey) }
    }

    private nonisolated static let storageKey = "noum.interactionSounds.enabled"

    private init() {
        isEnabled = Self.resolve(stored: UserDefaults.standard.object(forKey: Self.storageKey) as? Bool)
    }

    /// Synchronous, non-isolated read used by the engine's trigger path.
    nonisolated static var isEnabledSync: Bool {
        resolve(stored: UserDefaults.standard.object(forKey: storageKey) as? Bool)
    }

    /// Pure default semantics: never stored → ON. Unit-tested so the
    /// first-launch default is a deliberate, pinned decision.
    nonisolated static func resolve(stored: Bool?) -> Bool {
        stored ?? true
    }
}

// MARK: - Cue synthesis (pure)

/// Per-sample synthesis state for one cue. Pure value type — no
/// AVFoundation — so unit tests can render every cue offline and pin the
/// envelope contracts (audible body, bounded output, hard-silent tail).
///
/// Realtime contract: `nextSample()` does no allocation, no locking, no
/// Foundation calls — safe to drive from the audio render thread. Noise
/// comes from an embedded xorshift64 generator (deterministic per seed,
/// cheaper than `Float.random`).
struct InteractionCueSynth {
    let cue: InteractionCue
    let sampleRate: Double

    private var frame: Int = 0
    private var rngState: UInt64
    private var pinkRows: (Float, Float, Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0, 0, 0)
    private var pinkIndex: Int = 0
    private var brownState: Float = 0
    private var filterA: Float = 0
    private var filterB: Float = 0

    init(cue: InteractionCue, sampleRate: Double = 44100, seed: UInt64 = 0x9E3779B97F4A7C15) {
        self.cue = cue
        self.sampleRate = sampleRate
        self.rngState = seed == 0 ? 1 : seed
    }

    var totalFrames: Int { Int(cue.duration * sampleRate) }
    var isFinished: Bool { frame >= totalFrames }

    /// One mono frame in [-1, 1]. Returns exact silence once finished.
    mutating func nextSample() -> Float {
        guard frame < totalFrames else { return 0 }
        let t = Double(frame) / sampleRate
        let d = cue.duration
        frame += 1

        switch cue {
        case .repStartBreath:
            // Pink noise through a rising band-pass (300→900 Hz center),
            // inhale-shaped envelope: smooth rise, fast 70 ms release
            // that guarantees silence before the 450 ms budget ends.
            let center = 300.0 + 600.0 * (t / d)
            let x = nextPink()
            onePole(&filterA, input: x, cutoffHz: center * 0.6)
            let highPassed = x - filterA
            onePole(&filterB, input: highPassed, cutoffHz: center * 1.6)
            let rise = min(t / (d * 0.82), 1.0)
            let release = clamp01((d - t) / 0.07)
            return filterB * Float(rise * rise * release) * 0.5

        case .verdictReveal:
            // 90 Hz sine body, exponential decay, 5 ms noise transient on
            // the attack. One moment, three channels — lands with the
            // scoreReveal haptic on the ring's settle frame.
            let body = sin(2 * .pi * 90 * t) * exp(-t / 0.030) * 0.6
            let transient = Double(nextWhite()) * max(0, 1 - t / 0.005) * 0.10
            let release = clamp01((d - t) / 0.010)
            return Float((body + transient) * release)

        case .countSettle:
            // 1.8 kHz click, very fast decay, very quiet. Once per
            // settle — never per digit, never per frame.
            let tick = sin(2 * .pi * 1800 * t) * exp(-t / 0.003) * 0.16
            let release = clamp01((d - t) / 0.002)
            return Float(tick * release)

        case .drillCompleteSuccess, .drillCompleteIncomplete:
            // Brown noise through a low-pass gliding from the variant's
            // start cutoff down to 150 Hz; smooth fade to zero.
            let start = cue.drillBrushStartCutoffHz ?? 500
            let cutoff = start * pow(150.0 / start, t / d)
            let x = nextBrown()
            onePole(&filterA, input: x, cutoffHz: cutoff)
            let envelope = pow(1.0 - t / d, 1.4)
            return filterA * Float(envelope) * 0.9

        case .coachTurnExhale:
            // Low-passed pink noise under a sin² window — fades in and
            // out, barely above the noise floor.
            let x = nextPink()
            onePole(&filterA, input: x, cutoffHz: 500)
            let window = sin(.pi * t / d)
            return filterA * Float(window * window) * 0.16
        }
    }

    // MARK: Generators

    private mutating func nextWhite() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 7
        rngState ^= rngState << 17
        return Float(rngState & 0xFFFFFF) / Float(0x7FFFFF) - 1.0
    }

    /// Voss-style pink approximation — 7 staggered white rows, one
    /// refreshed per sample (deterministic round-robin).
    private mutating func nextPink() -> Float {
        let fresh = nextWhite()
        switch pinkIndex {
        case 0: pinkRows.0 = fresh
        case 1: pinkRows.1 = fresh
        case 2: pinkRows.2 = fresh
        case 3: pinkRows.3 = fresh
        case 4: pinkRows.4 = fresh
        case 5: pinkRows.5 = fresh
        default: pinkRows.6 = fresh
        }
        pinkIndex = (pinkIndex + 1) % 7
        let sum = pinkRows.0 + pinkRows.1 + pinkRows.2 + pinkRows.3
            + pinkRows.4 + pinkRows.5 + pinkRows.6
        return sum / 7
    }

    /// Brown noise via leaky integration, bounded like SoundscapeEngine.
    private mutating func nextBrown() -> Float {
        brownState = max(-0.25, min(0.25, brownState + 0.02 * nextWhite()))
        return brownState * 4.0
    }

    private func onePole(_ state: inout Float, input: Float, cutoffHz: Double) {
        let k = Float(1 - exp(-2 * .pi * cutoffHz / sampleRate))
        state += k * (input - state)
    }

    private func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

// MARK: - Engine

#if canImport(AVFoundation)

/// One-shot cue playback through the `SoundscapeEngine` source-node
/// pattern. The render closure captures only the lock-boxed synth — no
/// actor state crosses onto the audio thread.
@MainActor
final class InteractionSoundEngine {
    static let shared = InteractionSoundEngine()

    /// Mic gate, reported by `SpeechRecognizerViewModel.isRecording`.
    /// While true every trigger is refused and any in-flight cue is cut.
    private(set) static var recordingActive = false

    static func noteRecordingActive(_ active: Bool) {
        recordingActive = active
        if active { shared.stopNow() }
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let activeSynth = OSAllocatedUnfairLock<InteractionCueSynth?>(initialState: nil)
    private var idleStopTask: Task<Void, Never>?

    private init() {}

    /// Fire-and-forget trigger — the only public entry point. Callable
    /// from any context (including the GCD settle-frame closures the
    /// motion register uses); hops to the main actor where the policy
    /// gate and the audio graph live.
    nonisolated static func cue(_ cue: InteractionCue) {
        Task { @MainActor in shared.play(cue) }
    }

    /// Play one cue, if the policy allows it right now. Failure to spin
    /// up audio is silent — a missing tick must never break a flow.
    private func play(_ cue: InteractionCue) {
        guard InteractionSoundPolicy.shouldPlay(
            cue,
            enabled: InteractionSoundSettings.isEnabledSync,
            isRecording: Self.recordingActive
        ) else { return }

        do {
            try ensureSession()
            try ensureGraphRunning()
        } catch {
            #if DEBUG
            print("[InteractionSound] failed to start: \(error)")
            #endif
            return
        }

        activeSynth.withLock { $0 = InteractionCueSynth(cue: cue) }
        scheduleIdleStop(after: cue.duration + 2.0)
    }

    /// Cut any in-flight cue and idle the graph. Called when recording
    /// starts — the recorder owns the audio session from here, so we
    /// deliberately do not touch the session category.
    func stopNow() {
        activeSynth.withLock { $0 = nil }
        idleStopTask?.cancel()
        idleStopTask = nil
        if engine.isRunning { engine.stop() }
    }

    // MARK: Private

    private func ensureSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // `.ambient` + `.mixWithOthers` — the silent switch always wins,
        // and nothing else playing gets ducked or interrupted
        // (SoundscapeEngine precedent).
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
        #endif
    }

    private func ensureGraphRunning() throws {
        if sourceNode == nil {
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            // Capture only the lock box — `OSAllocatedUnfairLock` has
            // reference semantics for its protected state, so the render
            // thread and main actor share one synth slot without touching
            // actor-isolated state.
            let box = activeSynth
            let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let frames = Int(frameCount)
                box.withLock { synth in
                    for buffer in buffers {
                        guard let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                        for frame in 0..<frames {
                            ptr[frame] = synth?.nextSample() ?? 0
                        }
                    }
                    if synth?.isFinished == true { synth = nil }
                }
                return noErr
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 1.0
            sourceNode = node
        }
        if !engine.isRunning {
            try engine.start()
        }
    }

    /// Stop the graph shortly after the cue tail so we don't hold an
    /// audio engine (and its session claim) open between rare cues.
    private func scheduleIdleStop(after delay: TimeInterval) {
        idleStopTask?.cancel()
        idleStopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            let idle = self.activeSynth.withLock { $0 == nil || $0?.isFinished == true }
            if idle, self.engine.isRunning { self.engine.stop() }
        }
    }
}

#else

/// Platform stub — keeps call sites clean where AVFoundation is absent.
@MainActor
final class InteractionSoundEngine {
    static let shared = InteractionSoundEngine()
    private(set) static var recordingActive = false
    static func noteRecordingActive(_ active: Bool) { recordingActive = active }
    private init() {}
    nonisolated static func cue(_ cue: InteractionCue) {}
    func stopNow() {}
}

#endif
