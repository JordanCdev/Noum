#if canImport(SwiftUI)
import SwiftUI

// MARK: - Tier Promotion Overlay
//
// Full-screen celebration fired when the user's rating crosses up into a
// new league tier (Bronze → Silver, etc.). Visual richness comes from the
// tier's tint, scale springs, and SparkleRibbon — no illustration, per
// the design rules.
//
// Voice: framed as recognition, not reward. "You're now in Silver" reads
// like a coach acknowledging a milestone, not a slot-machine cha-ching.

@available(iOS 17.0, macOS 12.0, *)
struct TierPromotionOverlay: View {
    let promotion: TierPromotion
    let onDismiss: () -> Void

    @State private var hasAppeared = false
    @State private var sparkleActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { promotion.newTier.tint }

    var body: some View {
        ZStack {
            // Backdrop — radial gradient anchored to the new tier's
            // tint so the screen feels owned by the moment, not just
            // dimmed-out modal.
            RadialGradient(
                colors: [
                    tint.opacity(0.32),
                    Color.black.opacity(0.55)
                ],
                center: .top,
                startRadius: 0,
                endRadius: 700
            )
            .ignoresSafeArea()
            .onTapGesture(perform: onDismiss)

            VStack(spacing: Spacing.lg) {
                Spacer(minLength: 0)

                // Big tier symbol — uses the existing tier-glyph language
                // (rosette / shield / star) at scale, low-opacity behind
                // the foreground crown for visual depth without
                // illustration.
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 220, height: 220)
                        .scaleEffect(hasAppeared ? 1.0 : 0.4)
                        .blur(radius: 22)

                    Image(systemName: tierGlyph(for: promotion.newTier))
                        .font(.system(size: 110, weight: .black))
                        .foregroundStyle(tint.opacity(0.20))
                        .scaleEffect(hasAppeared ? 1.0 : 0.6)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: tint.opacity(0.8), radius: 18, y: 6)
                        .scaleEffect(hasAppeared ? 1.05 : 0.5)
                }
                .opacity(hasAppeared ? 1.0 : 0)

                // Sparkle ribbon — same primitive used elsewhere on
                // celebrations, tinted to the new tier.
                SparkleRibbon(tint: .white)
                    .opacity(sparkleActive ? 1.0 : 0)

                VStack(spacing: 8) {
                    Text("Promoted")
                        .font(Typography.micro)
                        .foregroundStyle(.white.opacity(0.78))
                        .textCase(.uppercase)
                        .tracking(1.0)
                    Text(promotion.newTier.title.uppercased() + " PEER GROUP")
                        .font(Typography.figtree(size: 36, weight: .black, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .kerning(1.4)
                    Text(coachLine)
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(hasAppeared ? 1.0 : 0)
                .offset(y: hasAppeared ? 0 : 16)

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(Typography.headline)
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(.white, in: Capsule(style: .continuous))
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
                .opacity(hasAppeared ? 1.0 : 0)
            }
        }
        .onAppear { runSequence() }
        .accessibilityIdentifier("tier.promotion.overlay")
        .accessibilityLabel("Moved to the \(promotion.newTier.title) peer group")
    }

    private func runSequence() {
        if reduceMotion {
            hasAppeared = true
            sparkleActive = true
            return
        }
        CoachHaptic.trendBreakthrough()
        withAnimation(.bouncySpring) { hasAppeared = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.standardSpring) { sparkleActive = true }
        }
    }

    private func tierGlyph(for tier: LeagueTier) -> String {
        switch tier {
        case .bronze:   return "shield.fill"
        case .silver:   return "shield.lefthalf.filled"
        case .gold:     return "rosette"
        case .platinum: return "seal.fill"
        case .diamond:  return "star.circle.fill"
        }
    }

    private var coachLine: String {
        // Tier-specific framing. No exclamations — celebration overlays
        // earn motion + sparkle, not punctuation.
        switch promotion.newTier {
        case .bronze:
            return "Your first peer group is forming from real rated reps."
        case .silver:
            return "Your recent rated reps now place you with the Silver group."
        case .gold:
            return "Your recent consistency now places you with the Gold group."
        case .platinum:
            return "Composure under pressure now places you with the Platinum group."
        case .diamond:
            return "Your rating now places you in the highest comparison group."
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Promoted to Silver") {
    TierPromotionOverlay(
        promotion: TierPromotion(previousTier: .bronze, newTier: .silver, date: Date()),
        onDismiss: {}
    )
}

@available(iOS 17.0, *)
#Preview("Promoted to Gold") {
    TierPromotionOverlay(
        promotion: TierPromotion(previousTier: .silver, newTier: .gold, date: Date()),
        onDismiss: {}
    )
}

@available(iOS 17.0, *)
#Preview("Promoted to Diamond") {
    TierPromotionOverlay(
        promotion: TierPromotion(previousTier: .platinum, newTier: .diamond, date: Date()),
        onDismiss: {}
    )
}
#endif

#endif
