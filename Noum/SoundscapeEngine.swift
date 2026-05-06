import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - Soundscape Engine
//
// Pre-rep prep ambience for the 5–10 seconds before recording starts. The
// goal: vocal warm-up texture that pulls the user's attention inward and
// fades cleanly when the rep begins. Speaking practice doesn't need
// music with melody — earworms compete with the rep you're about to record
// — so this synthesises ambient layers procedurally instead of bundling
// MP3s.
//
// Architectural notes:
// - Pure procedural audio via `AVAudioSourceNode`. No external assets,
//   no licensing complications, infinite seamless loop.
// - Mono output is enough for ambience; we don't need stereo separation.
// - Volume + mode persist via `SoundscapeSettings` so the user's choice
//   sticks across launches.
// - `start()` / `stop()` are idempotent and safe to call from the practice
//   view's lifecycle hooks.

#if canImport(AVFoundation)

@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class SoundscapeEngine: ObservableObject {
    static let shared = SoundscapeEngine()

    /// Currently-playing mode (or `.off` when nothing is playing).
    @Published private(set) var activeMode: SoundscapeMode = .off
    /// 0...1. Persisted via `SoundscapeSettings`.
    @Published var volume: Float = 0.55 {
        didSet {
            mainMixer?.outputVolume = volume
            SoundscapeSettings.persistVolume(volume)
        }
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var mainMixer: AVAudioMixerNode?

    /// Internal state for the noise generator. Owned by the render block
    /// (called on the audio thread); read/write only from inside the
    /// closure to stay realtime-safe.
    private var brownState: Float = 0
    private var pinkState: [Float] = Array(repeating: 0, count: 7)
    private var sinePhase: Double = 0
    private var lfoPhase: Double = 0

    private init() {
        volume = SoundscapeSettings.savedVolume
    }

    // MARK: - Public API

    /// Start ambience for `mode`. No-op if it's already the active mode.
    /// Re-routing modes mid-play is graceful: the source node stays
    /// running, we just swap the synthesis function.
    func start(_ mode: SoundscapeMode) {
        guard mode != .off else {
            stop()
            return
        }
        activeMode = mode
        do {
            try ensureSession()
            try ensureGraphRunning()
        } catch {
            #if DEBUG
            print("[Soundscape] failed to start: \(error)")
            #endif
            activeMode = .off
        }
    }

    /// Stop ambience and release the audio session. Safe to call when
    /// nothing's playing.
    func stop() {
        activeMode = .off
        guard engine.isRunning else { return }
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }
        mainMixer = nil
    }

    /// Convenience for the practice flow: start the user's preferred mode
    /// (read from settings) and fade in. Returns true if anything actually
    /// started — false when the user has it set to `.off`.
    @discardableResult
    func startPreferredMode() -> Bool {
        let mode = SoundscapeSettings.savedMode
        guard mode != .off else { return false }
        start(mode)
        return true
    }

    // MARK: - Private setup

    private func ensureSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // Use `.ambient` so the soundscape mixes politely with anything
        // else playing (Music, podcasts) and doesn't override a phone
        // call's audio routing.
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
        #endif
    }

    private func ensureGraphRunning() throws {
        if engine.isRunning, sourceNode != nil { return }

        let format = AVAudioFormat(
            standardFormatWithSampleRate: 44100,
            channels: 1
        )!

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)
            for buffer in buffers {
                let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)
                guard let ptr else { continue }
                for frame in 0..<frames {
                    ptr[frame] = self.nextSample()
                }
            }
            return noErr
        }
        engine.attach(node)
        let mixer = engine.mainMixerNode
        engine.connect(node, to: mixer, format: format)
        mixer.outputVolume = volume
        sourceNode = node
        mainMixer = mixer

        try engine.start()
    }

    // MARK: - Synthesis

    /// One audio frame at 44.1 kHz. Branches on the active mode and
    /// returns a sample in roughly [-1, 1]. Called from the audio thread
    /// — no allocations, no locks, no Foundation calls.
    private func nextSample() -> Float {
        let mode = activeMode
        switch mode {
        case .off:
            return 0
        case .focus:
            // Pink noise with slow amplitude LFO. Reads as "rain on a
            // window" without being literally water.
            let pink = nextPink() * 0.65
            let lfo = Float(0.85 + 0.15 * sin(lfoPhase))
            advanceLFO(rateHz: 0.10)
            return pink * lfo
        case .calm:
            // Brown noise — deeper, slower-decay. Less "static", more
            // "ocean far away". Slight low-pass via running average.
            return nextBrown() * 0.55
        case .steady:
            // Subtle drone: root + fifth at low volume + breath of pink
            // noise so it doesn't feel too synthesised.
            let root: Float = Float(sin(sinePhase)) * 0.10
            let fifth: Float = Float(sin(sinePhase * 1.498)) * 0.07
            let air = nextPink() * 0.18
            advanceSine(rateHz: 110.0)
            return root + fifth + air
        }
    }

    // Brown noise via integration with mild leak so it stays bounded.
    private func nextBrown() -> Float {
        let white = Float.random(in: -1...1)
        brownState = (brownState + 0.02 * white).clampedToUnit()
        return brownState * 4.0  // amplify into audible range
    }

    // Voss-style pink noise approximation. Sums 7 white-noise generators
    // at staggered rates to get a 1/f-shaped spectrum without a real FFT.
    private func nextPink() -> Float {
        let row = Int.random(in: 0..<pinkState.count)
        pinkState[row] = Float.random(in: -1...1)
        var sum: Float = 0
        for v in pinkState { sum += v }
        return sum / Float(pinkState.count)
    }

    private func advanceSine(rateHz: Double) {
        sinePhase += 2 * .pi * rateHz / 44100.0
        if sinePhase > 2 * .pi { sinePhase -= 2 * .pi }
    }

    private func advanceLFO(rateHz: Double) {
        lfoPhase += 2 * .pi * rateHz / 44100.0
        if lfoPhase > 2 * .pi { lfoPhase -= 2 * .pi }
    }
}

private extension Float {
    func clampedToUnit() -> Float {
        Swift.max(-0.25, Swift.min(0.25, self))
    }
}

// MARK: - Mode

enum SoundscapeMode: String, CaseIterable, Codable, Identifiable {
    case off
    case focus
    case calm
    case steady

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:    return "Off"
        case .focus:  return "Focus"
        case .calm:   return "Calm"
        case .steady: return "Steady"
        }
    }

    var coachLine: String {
        switch self {
        case .off:    return "Silence — the default speaking environment."
        case .focus:  return "Pink-noise wash. Pulls attention inward, fades on rep start."
        case .calm:   return "Deeper texture. Slows the breath before the clock starts."
        case .steady: return "Subtle drone at the root + fifth. Adds presence, not melody."
        }
    }

    var symbolName: String {
        switch self {
        case .off:    return "speaker.slash"
        case .focus:  return "drop.fill"
        case .calm:   return "wind"
        case .steady: return "waveform"
        }
    }
}

// MARK: - Settings

/// Lightweight persistence for the user's soundscape preference. Lives
/// outside the engine so the picker can read/write without spinning up
/// the audio graph.
enum SoundscapeSettings {
    private static let modeKey = "soundscape.preferredMode"
    private static let volumeKey = "soundscape.volume"

    static var savedMode: SoundscapeMode {
        guard let raw = UserDefaults.standard.string(forKey: modeKey),
              let mode = SoundscapeMode(rawValue: raw) else {
            return .off
        }
        return mode
    }

    static func persistMode(_ mode: SoundscapeMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
    }

    static var savedVolume: Float {
        let stored = UserDefaults.standard.float(forKey: volumeKey)
        // First-run default — UserDefaults returns 0 for missing floats,
        // so check explicitly via a presence flag.
        if UserDefaults.standard.object(forKey: volumeKey) == nil {
            return 0.55
        }
        return stored
    }

    static func persistVolume(_ volume: Float) {
        UserDefaults.standard.set(volume, forKey: volumeKey)
    }
}

#endif
