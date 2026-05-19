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

    /// Drives the 4-second breath cycle. We toggle this between 0 and 1
    /// with a `repeatForever(autoreverses:)` ease-in-out animation so the
    /// halo's scaleEffect interpolates smoothly between 1.0 and 1.10 in a
    /// genuinely breath-like way (slow inhale, slow exhale, brief pause
    /// implicit in the ease curve).
    @State private var breath01: Double = 0
    /// Continuous radian phase used by the core's subtle wobble + the
    /// listening arc pulse. Driven by a 30fps task; not the halo's
    /// primary driver (the halo now uses SwiftUI's interpolation).
    @State private var breathePhase: Double = 0
    @State private var listenPhase: Double = 0
    /// Outer-ring rotation in degrees. SwiftUI animates this from 0 to
    /// 360 over 12 seconds, then repeats forever — visually seamless
    /// because rotating by 360° matches the starting orientation.
    /// Reduce-motion freezes the angle at a fixed value.
    @State private var ringRotation: Double = 0
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

            // Inner glow — two stacked fills. The outer one carries the
            // tint at its resting opacity; the inner one is a brighter
            // variant (tint blended with white) that adds chromatic depth
            // without motion. For `brandBlue` this reads close to
            // `brandBlueLight`; for `pro` it reads close to `proLight`.
            // The derivation works for any caller tint, so we don't have
            // to add an init parameter.
            Circle()
                .fill(tint.opacity(coreGlowOpacity))
                .frame(width: size * 0.78, height: size * 0.78)
                .blur(radius: size * 0.06)

            Circle()
                .fill(tint.opacity(innerGlowOpacity))
                .frame(width: size * 0.56, height: size * 0.56)
                .blur(radius: size * 0.05)
                // `plusLighter` lifts the underlying tint toward white,
                // so the small inner glow renders as a brighter variant
                // of the caller's tint — close to `brandBlueLight` over
                // `brandBlue`, close to `proLight` over `pro`. Achieves
                // chromatic depth at zero motion cost and no API change.
                .blendMode(.plusLighter)

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

                // Slow rotating ring at the very outer edge. The gradient
                // stroke fades from `tint` to fully transparent around
                // the circumference, so as the ring rotates the bright
                // arc sweeps once every 12s. Read-out: "the coach is
                // actively listening." Reduce-motion freezes the angle.
                listeningRing
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

    /// Slow-rotating outer ring used only in `.listening`. The stroke is
    /// a linear gradient from `tint` → fully transparent, so the visible
    /// "bright arc" sweeps once per full rotation. 12s rotation, low
    /// alpha. Reduce-motion freezes the angle at the top of the cycle.
    private var listeningRing: some View {
        let ringSize = size * 1.32
        let rotation: Angle = reduceMotion ? .degrees(-30) : .degrees(ringRotation)
        return Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        tint.opacity(0.55),
                        tint.opacity(0.18),
                        tint.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
            .frame(width: ringSize, height: ringSize)
            .rotationEffect(rotation)
            .blendMode(.plusLighter)
    }

    // MARK: - Driven properties

    /// Breathing-driven outer halo scale.
    ///
    /// Maps `breath01` (0 → 1, eased by SwiftUI's repeating animation)
    /// into the 1.0–1.10 range. Reduce-motion users get a constant 1.0
    /// so nothing animates — the visible "breath" amplitude was bumped
    /// from the previous ±4% range to ±10% per the redesign brief, so
    /// the halo now visibly swells.
    private var haloScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return 1.0 + CGFloat(breath01) * 0.10
    }

    /// Outer-ring (existing) inner-glow opacity. Pumps brighter while
    /// listening. Backed by the tint passed in by the caller.
    private var coreGlowOpacity: Double {
        switch mood {
        case .listening: return 0.32
        case .excited:   return 0.28
        case .coaching:  return 0.22
        case .calm:      return 0.18
        }
    }

    /// Inner-glow alpha. Combined with `.plusLighter` blend on the
    /// inner Circle, this produces a brighter tint over the outer
    /// glow — the chromatic-depth cue the redesign brief asked for,
    /// achieved at zero motion cost. iOS 17 doesn't have `Color.mix`
    /// (iOS 18+ only), so we lift luminance via blend mode instead of
    /// passing a second `Color` (which would require an API change).
    private var innerGlowOpacity: Double {
        switch mood {
        case .listening: return 0.55
        case .excited:   return 0.48
        case .coaching:  return 0.38
        case .calm:      return 0.32
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
            // Reduce-motion users keep the bumped *static* breath
            // (constant 1.0) — they still get the brighter inner glow
            // and the per-mood symbols, just no motion.
            return
        }
        withAnimation(.standardSpring) { hasAppeared = true }

        // Halo "breath": SwiftUI-driven 4-second ease-in-out autoreverse.
        // `breath01` ramps 0 → 1 over 2s, reverses back 1 → 0 over 2s,
        // repeats forever. The eased curve produces a slow inhale, slow
        // exhale read at the halo, mapped to scale 1.0 → 1.10.
        withAnimation(
            .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        ) {
            breath01 = 1
        }

        // Listening outer ring: continuous slow rotation, 12 seconds per
        // full turn. Eased so the brightest arc gently slows at the top
        // and bottom of each cycle — rhythmically alive, never snappy.
        // Animating to 360° (not a partial angle) means each loop end
        // matches the loop start, so the `repeatForever` returns no
        // visible snap. Reduce-motion gate above means this only runs
        // when motion is allowed.
        withAnimation(
            .easeInOut(duration: 12.0).repeatForever(autoreverses: false)
        ) {
            ringRotation = 360
        }

        // Continuous low-rate phase for the core's subtle wobble and the
        // listening arc-pulse. Independent of the halo's SwiftUI-driven
        // breath so changes to mood-specific core scale stay snappy.
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
