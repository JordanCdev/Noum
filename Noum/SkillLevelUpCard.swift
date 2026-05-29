#if canImport(SwiftUI)
import SwiftUI

// MARK: - Skill Level-Up Card
//
// Inline celebration that appears on Summary when a skill crosses an
// upward band threshold (e.g., Filler Words: developing → solid).
//
// The user explicitly asked for "an intermediary screen" moment when
// skills level up. Rather than a full-screen overlay that hijacks the
// post-rep moment (we just removed that pattern for the deferred-capture
// sheet), this card lives inline near the top of summary and uses
// visual richness to feel celebratory:
//   • Gradient brand-blue → pro-purple background.
//   • Sparkle ribbon overlay.
//   • Animated bar progression — the bars fill from previousLevel to
//     newLevel with a spring on appear.
//   • Reduce-Motion respected: no animation, just static state.
//
// Auto-dismisses on tap. If multiple skills level up in one session, we
// stack the cards vertically (rare; usually only one fires).

@available(iOS 17.0, *)
struct SkillLevelUpCard: View {
    let event: SkillLevelUpEvent
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateBars = false

    var body: some View {
        Button(action: dismiss) {
            VStack(alignment: .leading, spacing: 12) {
                header
                bars
                Text(event.subline)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        AppColor.brandBlue,
                        AppColor.pro.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            )
            .overlay(alignment: .topTrailing) {
                SparkleRibbon(tint: .white)
                    .padding(.trailing, 14)
                    .padding(.top, 14)
                    .opacity(0.6)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.18), in: Circle())
                    .padding(8)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            guard !reduceMotion else { animateBars = true; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.bouncySpring) {
                    animateBars = true
                }
            }
            CoachHaptic.skillLevelUp()
        }
        .accessibilityLabel("\(event.headline). \(event.subline). Tap to dismiss.")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 40, height: 40)
                Image(systemName: event.skillArea.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("LEVELED UP")
                    .font(Typography.micro)
                    .foregroundStyle(Color.white.opacity(0.66))
                    .tracking(1.2)
                Text(event.headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    // MARK: - Bars

    /// Four bars matching the SkillProgressView treatment (weak →
    /// developing → solid → strong). Filled count animates from the
    /// previous level's count to the new level's count when the card
    /// appears.
    private var bars: some View {
        let from = level(event.previousLevel)
        let to = level(event.newLevel)
        let displayed = animateBars ? to : from
        return HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i < displayed
                          ? Color.white.opacity(0.95)
                          : Color.white.opacity(0.20))
                    .frame(height: 8)
            }
        }
    }

    private func level(_ skill: SkillLevel) -> Int {
        switch skill {
        case .weak: return 1
        case .developing: return 2
        case .solid: return 3
        case .strong: return 4
        }
    }

    // MARK: - Actions

    private func dismiss() {
        SkillProgressionStore.shared.consume(event)
        onDismiss()
    }
}

#endif
