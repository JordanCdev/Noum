import SwiftUI

// MARK: - V4.6 Voice Trace
//
// The single voice motif of the frozen V4.6 system (Figma components
// 209:497–504). One geometry language everywhere: rounded bars whose
// heights and opacities encode energy. The motif lives in exactly the
// homes the design names — the Today hero presence, the recording/
// processing surfaces, and the Progress trajectory — never stamped
// beside titles.
//
// All variants are decorative: every trace is `accessibilityHidden`,
// the story lives in the surrounding labels (accessibility sheet
// 258:1756). Under Reduce Motion the live trace renders as static bars
// at the drawn-state heights — no amplitude drift, no ambient loops.

/// Static silhouette + per-bar opacity ramps, straight from the frozen
/// component geometry. Heights are the resting (drawn) state; the live
/// variant modulates around them with the microphone level.
enum VoiceTraceVariant {
    /// Today hero — quiet white presence (12 bars, 4 pt wide, 4 pt gap).
    case idleHero
    /// Updated Today hero — the earned, brighter presence.
    case earnedHero
    /// Recording — violet amplitude-reactive bars with a dimmer mirror.
    case live
    /// Processing — the live geometry settled: ×1.1 scale, damped opacity.
    case settling

    var barWidth: CGFloat {
        switch self {
        case .idleHero, .earnedHero: return 4
        case .live: return 5
        case .settling: return 5.5
        }
    }

    var barSpacing: CGFloat {
        switch self {
        case .idleHero, .earnedHero: return 4
        case .live: return 9.5
        case .settling: return 10.45
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .idleHero, .earnedHero: return 2
        case .live, .settling: return 2.5
        }
    }

    /// Resting bar heights in points (top row for mirrored variants).
    var heights: [CGFloat] {
        switch self {
        case .idleHero:
            return [6, 10, 16, 24, 18, 28, 20, 12, 8, 14, 9, 6]
        case .earnedHero:
            return [8, 14, 22, 34, 26, 38, 28, 16, 10, 18, 12, 8]
        case .live:
            return [6, 9, 19, 26, 27, 22, 37, 51, 60, 59, 50, 35,
                    44, 54, 55, 48, 36, 21, 18, 16, 9, 6]
        case .settling:
            return VoiceTraceVariant.live.heights.map { $0 * 1.1 }
        }
    }

    /// Per-bar opacity ramp (matches the frozen component fills).
    var opacities: [Double] {
        switch self {
        case .idleHero:
            return [0.18, 0.26, 0.34, 0.41, 0.45, 0.48,
                    0.48, 0.45, 0.41, 0.34, 0.26, 0.18]
        case .earnedHero:
            return [0.35, 0.48, 0.59, 0.69, 0.76, 0.80,
                    0.80, 0.76, 0.69, 0.59, 0.48, 0.35]
        case .live:
            return [0.35, 0.45, 0.54, 0.63, 0.72, 0.79, 0.86, 0.91,
                    0.96, 0.98, 1.0, 1.0, 0.98, 0.96, 0.91, 0.86,
                    0.79, 0.72, 0.63, 0.54, 0.45, 0.35]
        case .settling:
            return VoiceTraceVariant.live.opacities.map { $0 * 0.45 }
        }
    }

    var color: Color {
        switch self {
        case .idleHero, .earnedHero: return .white
        case .live, .settling: return AppColor.voiceLive
        }
    }

    var hasMirror: Bool {
        switch self {
        case .live, .settling: return true
        case .idleHero, .earnedHero: return false
        }
    }
}

/// Renders one V4.6 voice trace. For `.live`, pass the microphone `level`
/// (0…1) — bars breathe around the silhouette with the quantised level so
/// the response is immediate but never jittery. All other variants (and
/// Reduce Motion) draw the resting silhouette exactly.
struct VoiceTrace: View {
    let variant: VoiceTraceVariant
    /// Normalised microphone level (0…1); only `.live` reads it.
    var level: CGFloat = 0
    /// Dims the whole trace (recording-silence state).
    var isQuiet: Bool = false
    /// Adds the violet glow halo behind mirrored variants.
    var showsGlow: Bool = true
    /// V4.6.1 hero entrance choreography: delays the start of the first
    /// breath cycle so the trace visibly wakes after the headline settles.
    /// The resting silhouette always draws immediately — only the ambient
    /// loop waits. Applied inside the breath animation itself, so the
    /// Reduce Motion settle and scenePhase re-arm logic are untouched
    /// (a delayed re-arm of a quiet loop is invisible).
    var wakeDelay: TimeInterval = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// Ambient breath phase for the hero presences — the coach is quietly
    /// alive, never performing. Reduce Motion keeps the drawn state.
    @State private var isBreathing = false

    /// Quantised to 5 % steps (the SpotlightOrb idiom) so 30 Hz level
    /// updates don't thrash layout; animated with a quick ease so the
    /// response still reads as immediate.
    private var quantisedLevel: CGFloat {
        (level * 20).rounded() / 20
    }

    /// Only the hero presences breathe; the live/settling stages already
    /// carry their own meaning through level and settle.
    private var breathes: Bool {
        (variant == .idleHero || variant == .earnedHero) && !reduceMotion
    }

    /// Height multiplier for the live variant. Resting bars sit at 45 %
    /// of the silhouette; full level reaches 100 %. Static under Reduce
    /// Motion and for non-live variants.
    private var heightScale: CGFloat {
        guard variant == .live, !reduceMotion else { return 1 }
        return 0.45 + 0.55 * min(max(quantisedLevel, 0), 1)
    }

    var body: some View {
        bars
            .background {
                if showsGlow, variant.hasMirror {
                    glow
                }
            }
            .opacity(isQuiet ? 0.45 : 1)
            .animation(.easeOut(duration: 0.3), value: isQuiet)
            .accessibilityHidden(true)
    }

    private var bars: some View {
        HStack(alignment: .center, spacing: variant.barSpacing) {
            ForEach(Array(variant.heights.enumerated()), id: \.offset) { index, height in
                if variant.hasMirror {
                    mirroredBar(height: height, opacity: variant.opacities[index])
                } else {
                    bar(height: height * heightScale, opacity: variant.opacities[index])
                        .scaleEffect(
                            // The resting (non-breathing) scale is always the
                            // drawn 1.0 — the breath dips to 0.84 and back only
                            // while armed, so a Reduce Motion toggle can never
                            // strand the squashed frame.
                            y: (breathes && isBreathing) ? 0.84 : 1.0,
                            anchor: .center
                        )
                        .animation(
                            breathes
                                ? .easeInOut(duration: 2.4)
                                    .repeatForever(autoreverses: true)
                                    .delay(wakeDelay + Double(index) * 0.14)
                                : nil,
                            value: isBreathing
                        )
                }
            }
        }
        .onAppear {
            guard breathes else { return }
            isBreathing = true
        }
        // Reduce Motion can flip mid-session and `onAppear` never re-fires:
        // arm the breath when motion returns, settle to the drawn state
        // (without animating) when it goes.
        .onChange(of: reduceMotion) { _, _ in
            if breathes {
                isBreathing = true
            } else {
                var settle = Transaction()
                settle.disablesAnimations = true
                withTransaction(settle) { isBreathing = false }
            }
        }
        // `repeatForever` driven by a one-shot state flip can freeze
        // mid-scale across a background/foreground cycle. Re-arm on return:
        // reset the phase without animation (the resting scale is the drawn
        // state, so there is no visible pop), then restart the loop on the
        // next runloop tick.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, breathes else { return }
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { isBreathing = false }
            DispatchQueue.main.async {
                guard breathes else { return }
                isBreathing = true
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: quantisedLevel
        )
    }

    /// Main bar + the dimmer reflection under a fixed 4 pt seam, per the
    /// frozen live/settling geometry (mirror ≈ 45 % of the main height).
    private func mirroredBar(height: CGFloat, opacity: Double) -> some View {
        VStack(spacing: 4) {
            bar(height: height * heightScale, opacity: opacity)
            bar(
                height: max(4, height * heightScale * 0.45),
                opacity: opacity * 0.45
            )
        }
    }

    private func bar(height: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
            .fill(variant.color.opacity(opacity))
            .frame(width: variant.barWidth, height: max(3, height))
    }

    private var glow: some View {
        Ellipse()
            .fill(AppColor.voiceLive.opacity(0.22))
            .blur(radius: 36)
            .scaleEffect(x: 1.15, y: 1.0)
            .padding(.vertical, -20)
    }
}

// MARK: - Weekly trajectory (Progress chart)

/// One day cluster of the Progress trajectory — five bars + reflections in
/// coach accent, with the day label under it. Day + outcome read as one
/// VoiceOver element at the row level; the chart itself is summarised by
/// the surrounding copy, so the cluster is decorative here.
struct VoiceTraceDayCluster: View {
    /// Relative bar heights for the cluster (5 values, points).
    let heights: [CGFloat]
    let label: String
    /// Amber label marks the honest lapse day; violet otherwise.
    var isLapse: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 3.5) {
                ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AppColor.coachAccent)
                            .frame(width: 4.5, height: max(3, height))
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AppColor.coachAccent.opacity(0.45))
                            .frame(width: 4.5, height: max(3, height * 0.4))
                    }
                }
            }
            Text(label)
                .font(Typography.figtree(size: 9.5, weight: .heavy, relativeTo: .caption2))
                .tracking(0.8)
                .foregroundStyle(isLapse ? AppColor.caution : AppColor.coachingInk)
                .textCase(.uppercase)
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Traces") {
    VStack(spacing: 32) {
        ZStack {
            LinearGradient(
                colors: [AppColor.heroGradientStart, AppColor.heroGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 24) {
                VoiceTrace(variant: .idleHero)
                VoiceTrace(variant: .earnedHero)
            }
        }
        .frame(height: 160)
        ZStack {
            LinearGradient(
                colors: [AppColor.immersiveTop, AppColor.immersiveBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 24) {
                VoiceTrace(variant: .live, level: 0.7)
                VoiceTrace(variant: .settling)
            }
        }
        .frame(height: 340)
        HStack(spacing: 40) {
            VoiceTraceDayCluster(heights: [8, 26, 33, 26, 8], label: "Mon")
            VoiceTraceDayCluster(heights: [8, 23, 29, 23, 8], label: "Wed", isLapse: true)
            VoiceTraceDayCluster(heights: [8, 35, 52, 52, 35], label: "Today")
        }
    }
}
#endif
