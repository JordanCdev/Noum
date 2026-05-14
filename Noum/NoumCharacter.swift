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
#endif

#endif
