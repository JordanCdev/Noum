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
    /// The character's lifetime-arc register. Composes on top of `mood`:
    /// mood is moment-to-moment, stage is "where this user is in their
    /// long arc with Noum." The same `.listening` mood reads differently
    /// at `.awakening` vs `.mastery` because the surrounding rings,
    /// glow brightness, and (for mastery) rotating outer band are
    /// layered in based on stage. Defaults to `.awakening` so existing
    /// call sites compile unchanged.
    var stage: Stage = .awakening

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
    /// Mastery outer ring rotation. Runs ~24s/turn (twice as slow as the
    /// listening ring so the two never read as the same motion) and is
    /// always-on at low alpha once `.mastery` is reached. Reduce-motion
    /// freezes the angle at a fixed value.
    @State private var masteryRingRotation: Double = 0
    /// Idle sparkle ribbon for `.mastery`: fires for ~1s every 60s while
    /// the character is at rest. We toggle `masterySparkleVisible` from
    /// the entrance task; the ribbon fades in/out via `.opacity` and
    /// inherits the existing `SparkleRibbon` motion.
    @State private var masterySparkleVisible: Bool = false
    @State private var excitedScale: CGFloat = 1.0
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Stage outer band — sits behind everything else so the inner
            // composition layers on top. Renders nothing for the earliest
            // stages; brings in the dotted ring at .composure, the solid
            // ring at .command, and the rotating gradient at .mastery.
            // Always-on (no mood gating) so the lifetime arc is visible
            // in every state — the "the coach has presence beyond their
            // own silhouette" reading the brief asked for.
            stageOuterBand

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

            // Third halo ring — only present from `.command` onward. The
            // brief specifies "Dual halo rings get +1 (3 total)" at the
            // .command stage; this is that third stroke, sitting between
            // the inner pair at a faint alpha so the depth read is
            // additive, not overpowering.
            if stage >= .command {
                Circle()
                    .stroke(tint.opacity(0.07), lineWidth: 1)
                    .frame(width: size * 1.30, height: size * 1.30)
                    .scaleEffect(haloScale * 1.08)
            }

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

            // Mastery idle sparkle — fires for ~1s every 60s while the
            // character is at rest at `.mastery`. Visually distinct from
            // the `.excited` sparkle (which orbits below the head): this
            // one drifts above, reads as "carrying weight at rest." Gated
            // on reduce-motion at the call site so it never animates for
            // users who've opted out, and it's silent unless the
            // character is actually at `.mastery`.
            if stage == .mastery && masterySparkleVisible {
                SparkleRibbon(tint: tint)
                    .frame(width: size * 1.10)
                    .offset(y: -size * 0.60)
                    .opacity(0.85)
                    .transition(.opacity)
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear { runEntrance() }
        .onChange(of: mood) { _, _ in retriggerForMood() }
        .accessibilityLabel(accessibilityCopy)
    }

    // MARK: - Stage outer band
    //
    // The "lifetime arc" register. Each stage layers a new ring on top of
    // what the previous stage drew:
    //
    //   • .awakening, .voice:  nothing (the inner halo carries the read).
    //   • .composure:          dotted outer ring at ~1.45× character size,
    //                          very low alpha, fixed angle.
    //   • .command:            solid (non-dotted) outer ring at ~1.45×
    //                          character size, low alpha.
    //   • .mastery:            slow rotating gradient ring at ~1.45×
    //                          character size, always-on at low alpha.
    //                          Reduce-motion freezes the angle.
    //
    // All composed from `Circle` + `LinearGradient` per the brand rule.
    // The "behind everything" placement means stage upgrades never fight
    // with mood-specific accents in the inner composition.

    @ViewBuilder
    private var stageOuterBand: some View {
        let bandSize = size * 1.45
        switch stage {
        case .awakening, .voice:
            // No outer band — the lifetime arc is carried inside the
            // halo + inner glow brightness shift at these stages.
            EmptyView()

        case .composure:
            // Dotted ring suggests "the coach has presence beyond their
            // own silhouette." Very low alpha so the ring reads as ambient
            // rather than decorative.
            Circle()
                .stroke(
                    tint.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 4])
                )
                .frame(width: bandSize, height: bandSize)

        case .command:
            // Solid, non-dotted band. Same size as `.composure`'s ring so
            // the transition between stages is "the dashes filled in,"
            // not "a new ring appeared."
            Circle()
                .stroke(tint.opacity(0.32), lineWidth: 1)
                .frame(width: bandSize, height: bandSize)

        case .mastery:
            // Slow rotating gradient band — visually distinct from the
            // listening ring (different rotation speed, lower alpha, no
            // mood gating). Always-on once mastery is earned.
            let rotation: Angle = reduceMotion
                ? .degrees(45)
                : .degrees(masteryRingRotation)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.45),
                            tint.opacity(0.18),
                            tint.opacity(0.04),
                            tint.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: bandSize, height: bandSize)
                .rotationEffect(rotation)
                .blendMode(.plusLighter)
        }
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
    /// into the 1.0–1.10 range at `.awakening` and the 1.0–1.13 range
    /// from `.voice` onward (brief: "Soft breathing range widened" at
    /// .voice). Reduce-motion users get a constant 1.0 so nothing
    /// animates.
    private var haloScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        // Wider breath at .voice and beyond — the character is more
        // "alive" once it has found its voice.
        let amplitude: CGFloat = stage >= .voice ? 0.13 : 0.10
        return 1.0 + CGFloat(breath01) * amplitude
    }

    /// Outer-ring (existing) inner-glow opacity. Pumps brighter while
    /// listening. Backed by the tint passed in by the caller. `.voice`
    /// nudges the floor up so the inner glow reads brighter at rest —
    /// the brief's "Brighter inner glow ring" at the .voice stage.
    private var coreGlowOpacity: Double {
        let base: Double
        switch mood {
        case .listening: base = 0.32
        case .excited:   base = 0.28
        case .coaching:  base = 0.22
        case .calm:      base = 0.18
        }
        return base + stageGlowBoost
    }

    /// Inner-glow alpha. Combined with `.plusLighter` blend on the
    /// inner Circle, this produces a brighter tint over the outer
    /// glow — the chromatic-depth cue the redesign brief asked for,
    /// achieved at zero motion cost. iOS 17 doesn't have `Color.mix`
    /// (iOS 18+ only), so we lift luminance via blend mode instead of
    /// passing a second `Color` (which would require an API change).
    ///
    /// Stage bumps: `.command` "Inner glow color now reads brighter
    /// (lean toward `proLight` / `brandBlueLight` even more)" per the
    /// brief — implemented as a higher alpha on the `.plusLighter`-
    /// blended fill so the tint resolves closer to the light variant
    /// of whatever the caller passed in.
    private var innerGlowOpacity: Double {
        let base: Double
        switch mood {
        case .listening: base = 0.55
        case .excited:   base = 0.48
        case .coaching:  base = 0.38
        case .calm:      base = 0.32
        }
        return base + stageGlowBoost * 1.4
    }

    /// Additive opacity bump applied to both the core glow and (more
    /// strongly) the inner `.plusLighter` glow at each stage. The
    /// numbers are small on purpose — calm + restrained progression is
    /// the spec, so the user notices over weeks, not in a single
    /// session.
    private var stageGlowBoost: Double {
        switch stage {
        case .awakening: return 0.0
        case .voice:     return 0.04
        case .composure: return 0.06
        case .command:   return 0.10
        case .mastery:   return 0.12
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
        // Mood-specific base copy — the moment-to-moment state.
        let base: String
        switch mood {
        case .calm:      base = "Noum coach, calm"
        case .listening: base = "Noum coach, listening to your rep"
        case .excited:   base = "Noum coach, celebrating your rep"
        case .coaching:  base = "Noum coach, reading your session"
        }
        // Append the stage suffix only when we have one — `.awakening`
        // intentionally adds nothing so a brand-new user doesn't hear
        // "just arriving" every time they meet the coach.
        if let suffix = stage.accessibilitySuffix {
            return "\(base), \(suffix)"
        }
        return base
    }

    // MARK: - Animation drivers

    private func runEntrance() {
        if reduceMotion {
            hasAppeared = true
            // Reduce-motion users keep the bumped *static* breath
            // (constant 1.0) — they still get the brighter inner glow,
            // the per-mood symbols, and every stage's visual upgrades
            // (extra rings, brighter glow, the *static* mastery band).
            // What they don't get: the mastery ring rotation and the
            // 60s idle sparkle ribbon — both gated below on `reduceMotion`.
            return
        }
        withAnimation(.standardSpring) { hasAppeared = true }

        // Halo "breath": SwiftUI-driven 4-second ease-in-out autoreverse.
        // `breath01` ramps 0 → 1 over 2s, reverses back 1 → 0 over 2s,
        // repeats forever. The eased curve produces a slow inhale, slow
        // exhale read at the halo, mapped to scale 1.0 → 1.10 (or
        // 1.0 → 1.13 from .voice onward, per the brief).
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

        // Mastery outer-band rotation. 24-second per full turn (twice as
        // slow as the listening ring so the two motions never read as
        // the same loop). Always-on once .mastery is reached — but the
        // ring itself only renders for .mastery in `stageOuterBand`, so
        // animating the value is harmless for earlier stages (the
        // unused value just spins quietly in state).
        withAnimation(
            .linear(duration: 24.0).repeatForever(autoreverses: false)
        ) {
            masteryRingRotation = 360
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

        // Mastery idle sparkle — fires for ~1s every 60s while the
        // character is at .mastery. Restraint by design: 1 second of
        // sparkle every minute is "carrying weight at idle," not a
        // distraction. Loop only runs when stage starts at .mastery; if
        // a user reaches mastery mid-view they'll see it on the next
        // render (the view re-enters this task on appear).
        if stage == .mastery {
            Task { @MainActor in
                while true {
                    try? await Task.sleep(for: .seconds(60))
                    guard stage == .mastery else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        masterySparkleVisible = true
                    }
                    try? await Task.sleep(for: .seconds(1.0))
                    withAnimation(.easeInOut(duration: 0.4)) {
                        masterySparkleVisible = false
                    }
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
        /// Lifetime-arc register. The inline variant only carries the
        /// simplest 2-3 visual cues per the brief: a subtle outer ring
        /// from `.composure` onward (filled in at `.command`+) and a
        /// slightly brighter glow at `.mastery`. We deliberately don't
        /// load the inline with every stage's detail — motion at 20pt
        /// is busy and a five-stage progression would crowd a section
        /// title beside it. Default `.awakening` keeps existing call
        /// sites compiling unchanged.
        var stage: Stage

        // No reduceMotion env — the Inline variant has no animations
        // by design (motion at 20pt is busy and doesn't read), so the
        // setting has no work to gate.

        init(
            size: CGFloat = 20,
            mood: Mood = .calm,
            tint: Color = AppColor.brandBlue,
            stage: Stage = .awakening
        ) {
            self.size = size
            self.mood = mood
            self.tint = tint
            self.stage = stage
        }

        var body: some View {
            ZStack {
                // Stage outer ring at the inline scale. Static (no motion),
                // dotted at `.composure`, solid from `.command` onward,
                // nothing for the early stages.
                inlineStageRing

                // Faint glow — no stroke, just a low-opacity fill. Mood
                // bumps the opacity so .listening reads brighter without
                // adding motion. `.mastery` adds a small additional
                // boost so the inline glyph reads visibly "more present"
                // for mastered users without overpowering the section
                // title beside it.
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
            .frame(width: stageFrameSize, height: stageFrameSize)
            .accessibilityLabel(accessibilityCopy)
        }

        /// Outer ring drawn at `~1.3×` size for the inline variant. The
        /// inline reduces the brief's five visual cues to the two that
        /// read at 20pt: a static dotted/solid ring (presence beyond
        /// the silhouette) and a brighter glow at `.mastery` (presence
        /// in the glyph itself).
        @ViewBuilder
        private var inlineStageRing: some View {
            let ringSize = size * 1.3
            switch stage {
            case .awakening, .voice:
                EmptyView()
            case .composure:
                Circle()
                    .stroke(
                        tint.opacity(0.30),
                        style: StrokeStyle(lineWidth: 0.75, dash: [1.5, 2.5])
                    )
                    .frame(width: ringSize, height: ringSize)
            case .command, .mastery:
                Circle()
                    .stroke(tint.opacity(0.34), lineWidth: 0.75)
                    .frame(width: ringSize, height: ringSize)
            }
        }

        /// Frame size accounts for the outer ring (1.3× size) at
        /// `.composure` and beyond so the surrounding layout doesn't
        /// clip the ring. Earlier stages keep the legacy 1× frame so
        /// existing inline call sites don't reflow.
        private var stageFrameSize: CGFloat {
            stage >= .composure ? size * 1.3 : size
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
