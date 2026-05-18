#if canImport(SwiftUI)
import SwiftUI

// MARK: - Noum Character
//
// An abstract "speaker character" composed from SF Symbols and motion —
// no illustration, per the brand rules in `noum-design`. The character
// is recognisable as a presence (it breathes, listens, reacts) without
// being a cartoon mascot.
//
// The design is a stacked composition:
//   • outer breathing halo (Circle stroke)
//   • inner glow (Circle fill at low opacity)
//   • core waveform (`waveform`) that shifts per state
//
// State-specific accents are layered on top — symmetric pulse rings
// for "listening", sparkle ribbon for "excited", subtle tilt for
// "coaching".
//
// `NoumCharacter.Inline` is a stripped variant sized for ~20pt use as a
// section-header glyph so the coach can narrate sections, not just heroes.

@available(iOS 17.0, macOS 12.0, *)
struct NoumCharacter: View {
    enum Mood: Equatable {
        case calm        // Default: gentle breathing, neutral waveform
        case listening   // During a rep: symmetric pulses, brighter core
        case excited     // After a clean rep: bouncy + sparkle ring
        case coaching    // Summary view: tilted, warmer
    }

    var mood: Mood = .calm
    var tint: Color = AppColor.brandBlue
    var size: CGFloat = 96

    @State private var breathePhase: Double = 0
    @State private var listenPhase: Double = 0
    @State private var excitedScale: CGFloat = 1.0
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Outer breathing halo. Two thin strokes at offset
            // opacities create a "depth" cue without illustration.
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 2)
                .frame(width: size, height: size)
                .scaleEffect(haloScale)

            Circle()
                .stroke(tint.opacity(0.10), lineWidth: 1)
                .frame(width: size * 1.18, height: size * 1.18)
                .scaleEffect(haloScale * 1.04)

            // Inner glow — soft fill that intensifies on listening.
            Circle()
                .fill(tint.opacity(coreGlowOpacity))
                .frame(width: size * 0.78, height: size * 0.78)
                .blur(radius: size * 0.06)

            // Core waveform — the "face" of the character.
            Image(systemName: coreSymbol)
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(coreScale)
                .rotationEffect(coreTilt)

            // Listening accent — symmetric arc-pulses on either side.
            if mood == .listening {
                listeningArcs
            }

            // Excited accent — sparkle ribbon orbiting the head.
            if mood == .excited {
                SparkleRibbon(tint: tint)
                    .frame(width: size * 1.25)
                    .offset(y: size * 0.55)
            }
        }
        .frame(width: size * 1.4, height: size * 1.4)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear { runEntrance() }
        .onChange(of: mood) { _, _ in retriggerForMood() }
        .accessibilityLabel(accessibilityCopy)
    }

    // MARK: - Listening accent

    private var listeningArcs: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { side in
                let direction: CGFloat = side == 0 ? -1 : 1
                let phase = listenPhase + Double(side) * .pi
                let scale = 1.0 + sin(phase) * 0.08
                Image(systemName: side == 0 ? "waveform.path" : "waveform.path")
                    .font(.system(size: size * 0.20, weight: .bold))
                    .foregroundStyle(tint.opacity(0.65))
                    .scaleEffect(scale)
                    .offset(x: direction * size * 0.45)
                    .scaleEffect(x: direction)  // mirror on the right side
            }
        }
    }

    // MARK: - Driven properties

    /// Breathing-driven outer halo scale. Reduce-motion users get a
    /// constant 1.0 so nothing animates.
    private var haloScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        let breath = sin(breathePhase) * 0.04
        return 1.0 + breath
    }

    /// Inner glow opacity. Pumps brighter while listening.
    private var coreGlowOpacity: Double {
        switch mood {
        case .listening: return 0.32
        case .excited:   return 0.28
        case .coaching:  return 0.22
        case .calm:      return 0.18
        }
    }

    /// Symbol used for the character "face". Different states pick
    /// slightly different waveform variants so the mood is readable.
    private var coreSymbol: String {
        switch mood {
        case .calm:      return "waveform"
        case .listening: return "waveform.and.mic"
        case .excited:   return "waveform.path.ecg"
        case .coaching:  return "waveform.badge.magnifyingglass"
        }
    }

    /// Core scale — bigger when excited, otherwise tied to breathing.
    private var coreScale: CGFloat {
        switch mood {
        case .excited:
            return excitedScale
        case .listening:
            guard !reduceMotion else { return 1.0 }
            return 1.0 + sin(breathePhase * 1.4) * 0.05
        default:
            guard !reduceMotion else { return 1.0 }
            return 1.0 + sin(breathePhase) * 0.025
        }
    }

    /// Slight rotation in coaching mode so the character reads as
    /// "leaning in" without illustration.
    private var coreTilt: Angle {
        mood == .coaching ? .degrees(-6) : .degrees(0)
    }

    private var accessibilityCopy: String {
        switch mood {
        case .calm:      return "Noum coach, calm"
        case .listening: return "Noum coach, listening to your rep"
        case .excited:   return "Noum coach, celebrating your rep"
        case .coaching:  return "Noum coach, reading your session"
        }
    }

    // MARK: - Animation drivers

    private func runEntrance() {
        if reduceMotion {
            hasAppeared = true
            return
        }
        withAnimation(.standardSpring) { hasAppeared = true }
        // Continuous breathing — slow sine via repeating linear timer.
        // Using a TimelineView would also work; this keeps state on the
        // view and respects mood-driven scale changes.
        Task { @MainActor in
            let frameRate = 1.0 / 30.0
            while true {
                try? await Task.sleep(for: .seconds(frameRate))
                breathePhase += 2 * .pi / 72   // 2.4s loop at 30fps
                if breathePhase > 2 * .pi { breathePhase -= 2 * .pi }
                if mood == .listening {
                    listenPhase += 2 * .pi / 24  // 0.8s loop
                    if listenPhase > 2 * .pi { listenPhase -= 2 * .pi }
                }
            }
        }
    }

    /// When mood swaps to .excited, kick a brief scale burst.
    private func retriggerForMood() {
        guard !reduceMotion else { return }
        if mood == .excited {
            withAnimation(.bouncySpring) { excitedScale = 1.18 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.standardSpring) { excitedScale = 1.0 }
            }
        }
    }
}

// MARK: - Inline variant
//
// A stripped composition for use at small sizes (section-header bullet,
// inline-with-text glyph). The point is "presence at small scale" — the
// coach narrating a section, not a hero ornament.
//
// Composition is intentionally minimal: one faint glow circle + the core
// `waveform` symbol. No breathing halo, no sparkle ribbon, no listening
// arcs. Motion at 20pt is busy and doesn't read, so the inline variant
// stays static even when the parent's full variant would animate.

@available(iOS 17.0, macOS 12.0, *)
extension NoumCharacter {
    struct Inline: View {
        var size: CGFloat
        var mood: Mood
        var tint: Color

        // No reduceMotion env — the Inline variant has no animations
        // by design (motion at 20pt is busy and doesn't read), so the
        // setting has no work to gate.

        init(size: CGFloat = 20, mood: Mood = .calm, tint: Color = AppColor.brandBlue) {
            self.size = size
            self.mood = mood
            self.tint = tint
        }

        var body: some View {
            ZStack {
                // Faint glow — no stroke, just a low-opacity fill. Mood
                // bumps the opacity so .listening reads brighter without
                // adding motion.
                Circle()
                    .fill(tint.opacity(glowOpacity))
                    .frame(width: size, height: size)
                    .blur(radius: size * 0.10)

                // Core waveform — the "face" at small scale.
                Image(systemName: coreSymbol)
                    .font(.system(size: size * 0.85, weight: coreWeight))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
                    .rotationEffect(coreTilt)
            }
            .frame(width: size, height: size)
            .accessibilityLabel(accessibilityCopy)
        }

        // MARK: - Mood resolution
        //
        // The inline variant collapses `.excited` to `.calm` — the
        // sparkle ribbon doesn't read at 20pt and adding it would create
        // visual noise next to a section title. `.coaching` keeps its
        // tilt + warmer-weighted symbol; `.listening` keeps the brighter
        // glow but never animates.

        private var coreSymbol: String {
            switch mood {
            case .calm, .excited:   return "waveform"
            case .listening:        return "waveform.and.mic"
            case .coaching:         return "waveform.badge.magnifyingglass"
            }
        }

        private var coreWeight: Font.Weight {
            // Coaching mood reads warmer with a heavier weight; the
            // others stay semibold so the glyph doesn't dominate the
            // section title beside it.
            mood == .coaching ? .heavy : .semibold
        }

        private var glowOpacity: Double {
            switch mood {
            case .listening: return 0.28
            case .coaching:  return 0.20
            case .calm,
                 .excited:   return 0.16
            }
        }

        private var coreTilt: Angle {
            // The 4° lean is the inline echo of the full character's
            // -6° "leaning in" tilt — present but restrained, since
            // small glyphs amplify rotation visually.
            mood == .coaching ? .degrees(-4) : .degrees(0)
        }

        private var accessibilityCopy: String {
            switch mood {
            case .calm,
                 .excited:    return "Noum coach"
            case .listening:  return "Noum coach, listening"
            case .coaching:   return "Noum coach, reading your session"
            }
        }
    }
}

// MARK: - Mood pulse hook
//
// Lets a call site briefly flash to a different mood without owning the
// transient state. Example:
//
//     NoumCharacter(mood: .calm).moodPulse(.excited, duration: 1.0)
//
// During `duration` the character renders in the pulse mood; afterwards
// it reverts to the underlying static mood. Reduce-motion users get the
// pulse mood applied instantly (no fade transition).
//
// Implementation note: `moodPulse` is a method on `NoumCharacter` rather
// than a generic `View` modifier because it needs `self.size` and
// `self.tint` to render the pulse with the same visual weight as the
// resting character — a generic modifier would lose those values.

@available(iOS 17.0, macOS 12.0, *)
private struct MoodPulseWrapper: View {
    let staticMood: NoumCharacter.Mood
    let pulseMood: NoumCharacter.Mood
    let tint: Color
    let size: CGFloat
    let duration: Double

    // The transient mood is the *override*. While non-nil the character
    // renders in that mood; once cleared we fall through to the static
    // mood the call site originally specified.
    @State private var transientMood: NoumCharacter.Mood?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Resolved mood for this frame: the transient pulse mood while the
    /// timer is alive, otherwise the resting mood the caller passed in.
    private var displayMood: NoumCharacter.Mood {
        transientMood ?? staticMood
    }

    var body: some View {
        NoumCharacter(mood: displayMood, tint: tint, size: size)
            .onAppear {
                guard duration > 0, transientMood == nil else { return }
                transientMood = pulseMood
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(duration))
                    if reduceMotion {
                        transientMood = nil
                    } else {
                        withAnimation(.standardSpring) { transientMood = nil }
                    }
                }
            }
    }
}

@available(iOS 17.0, macOS 12.0, *)
extension NoumCharacter {
    /// Briefly flashes the character to `pulseMood` for `duration` seconds,
    /// then reverts to the static mood the view was initialised with.
    ///
    /// Useful for marking a moment — e.g. fire `.excited` for a second
    /// after a clean rep posts, even while the surrounding surface holds
    /// the calm hero state. Preserves the original `size` and `tint`.
    func moodPulse(_ pulseMood: Mood, duration: Double = 1.0) -> some View {
        MoodPulseWrapper(
            staticMood: self.mood,
            pulseMood: pulseMood,
            tint: self.tint,
            size: self.size,
            duration: duration
        )
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Calm") {
    ZStack {
        AppColor.screenBackground.ignoresSafeArea()
        NoumCharacter(mood: .calm, tint: AppColor.brandBlue, size: 120)
    }
}

@available(iOS 17.0, *)
#Preview("Listening") {
    ZStack {
        AppColor.screenBackground.ignoresSafeArea()
        NoumCharacter(mood: .listening, tint: AppColor.modeAhCounter, size: 120)
    }
}

@available(iOS 17.0, *)
#Preview("Excited") {
    ZStack {
        AppColor.screenBackground.ignoresSafeArea()
        NoumCharacter(mood: .excited, tint: AppColor.modeSuddenDeath, size: 120)
    }
}

@available(iOS 17.0, *)
#Preview("Coaching") {
    ZStack {
        AppColor.screenBackground.ignoresSafeArea()
        NoumCharacter(mood: .coaching, tint: AppColor.pro, size: 120)
    }
}

@available(iOS 17.0, *)
#Preview("Inline glyph") {
    ZStack {
        AppColor.screenBackground.ignoresSafeArea()
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.xs) {
                NoumCharacter.Inline(mood: .calm)
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.xs) {
                NoumCharacter.Inline(mood: .coaching, tint: AppColor.pro)
                Text("This week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.xs) {
                NoumCharacter.Inline(mood: .listening, tint: AppColor.modeAhCounter)
                Text("Listening")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
#endif

#endif
