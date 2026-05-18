#if canImport(SwiftUI)
import SwiftUI

// MARK: - Personal Best Hero Card
//
// The "premium" anchor surface in the Noum design system, lifted from the
// Figma spec ("Design Noum Progress Hero" → second prompt). Reserved for
// real personal-best moments — never used as a daily/idle hero. Loud, but
// load-bearing: this is where the product earns the "premium" word.
//
// Layered mesh background:
//   • Linear gradient #6B2BC9 (top-leading) → #4E1B9C (bottom-trailing)
//   • Radial highlight white@30% from top-leading, blended plus-lighter
//   • Radial accent proLight (#D185FF) @ 55% from top-trailing, plus-lighter
//   • Specular gloss along the top 38%, white@22% → transparent
//   • 1pt inner stroke white@22% (sells the gloss)
//   • Drop shadow stack tinted in AppColor.pro (#8F47EB) for the bloom
//
// Voice rules from the spec (every string MUST follow):
//   • Declarative, never selling. No "Congratulations" / "Great job".
//   • No emoji.
//   • Kicker carries the category; headline is one short sentence.
//   • Stats are real numbers, not vibes.

@available(iOS 17.0, *)
struct PersonalBestHeroCard<CTAIcon: View>: View {

    struct Stat: Identifiable {
        let id = UUID()
        let value: String
        let label: String

        init(value: String, label: String) {
            self.value = value
            self.label = label
        }
    }

    let kicker: String
    let headline: String
    let bodyCopy: String
    let stats: [Stat]
    let ctaTitle: String
    let ctaIcon: () -> CTAIcon
    let ctaAction: () -> Void
    var showSparkles: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Figma-spec exact hexes — kept inline because they're specific to this
    // surface's mesh. The brand purples in DesignSystem (`AppColor.pro` /
    // `.proLight`) anchor the rest of the design; these darker tones only
    // exist for the gradient base.
    private static var gradientStart: Color { Color(red: 0.42, green: 0.17, blue: 0.79) } // #6B2BC9
    private static var gradientEnd: Color { Color(red: 0.31, green: 0.11, blue: 0.61) }   // #4E1B9C

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(Typography.figtree(size: 28, weight: .bold, relativeTo: .title))
                    .foregroundStyle(.white)
                    .tracking(-0.4) // -0.015em at 28pt ≈ -0.42pt
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Text(bodyCopy)
                    .font(Typography.manrope(size: 16, weight: .medium, relativeTo: .subheadline))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !stats.isEmpty {
                HStack(spacing: 12) {
                    ForEach(stats) { stat in
                        statTile(stat)
                    }
                }
            }

            cta
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(meshBackground)
        .overlay(specularGloss)
        .overlay(innerStroke)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        // Drop shadow stack — both shadows tinted in the anchor purple so the
        // card glows rather than just sits.
        .shadow(color: AppColor.pro.opacity(0.35), radius: 12, x: 0, y: 8)
        .shadow(color: AppColor.pro.opacity(0.18), radius: 28, x: 0, y: 22)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header (kicker + sparkle cluster)

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(kicker)
                .font(Typography.micro)
                .foregroundStyle(Color.white.opacity(0.72))
                .textCase(.uppercase)
                .tracking(0.8)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if showSparkles {
                SparkleRibbon(tint: .white, animated: !reduceMotion)
                    .frame(height: 14)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Stat tile

    private func statTile(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stat.value)
                .font(Typography.figtree(size: 32, weight: .bold, relativeTo: .title))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(stat.label)
                .font(Typography.manrope(size: 13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - CTA capsule (only place the design uses white as a foreground)

    private var cta: some View {
        Button(action: ctaAction) {
            HStack(spacing: 8) {
                Text(ctaTitle)
                    .font(Typography.figtree(size: 16, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(AppColor.pro)
                ctaIcon()
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.pro)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white, in: Capsule(style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(ctaTitle)
    }

    // MARK: - Mesh background

    private var meshBackground: some View {
        ZStack {
            // 1. Base linear gradient
            LinearGradient(
                colors: [Self.gradientStart, Self.gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 2. White luminosity pop from top-leading, plus-lighter
            RadialGradient(
                colors: [Color.white.opacity(0.30), Color.white.opacity(0)],
                center: UnitPoint(x: 0.05, y: 0.05),
                startRadius: 0,
                endRadius: 260
            )
            .blendMode(.plusLighter)

            // 3. proLight accent from top-trailing, plus-lighter
            RadialGradient(
                colors: [AppColor.proLight.opacity(0.55), AppColor.proLight.opacity(0)],
                center: UnitPoint(x: 0.95, y: 0.05),
                startRadius: 0,
                endRadius: 240
            )
            .blendMode(.plusLighter)
        }
        .compositingGroup() // contain plus-lighter blending within the card
    }

    // MARK: - Specular gloss band (top 38%)

    private var specularGloss: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [Color.white.opacity(0.22), Color.white.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: geo.size.height * 0.38)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Inner hairline stroke

    private var innerStroke: some View {
        RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            .allowsHitTesting(false)
    }
}

// MARK: - Convenience initializer with default chevron CTA

@available(iOS 17.0, *)
extension PersonalBestHeroCard where CTAIcon == Image {
    init(
        kicker: String,
        headline: String,
        body: String,
        stats: [Stat],
        ctaTitle: String,
        showSparkles: Bool = true,
        ctaAction: @escaping () -> Void
    ) {
        self.kicker = kicker
        self.headline = headline
        self.bodyCopy = body
        self.stats = stats
        self.ctaTitle = ctaTitle
        self.ctaIcon = { Image(systemName: "chevron.right") }
        self.ctaAction = ctaAction
        self.showSparkles = showSparkles
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Active week peak") {
    VStack(spacing: 16) {
        PersonalBestHeroCard(
            kicker: "Personal best · this week",
            headline: "A clean rep at full pressure.",
            body: "You held a 60-second answer with zero fillers — a first this week.",
            stats: [
                .init(value: "98", label: "Score"),
                .init(value: "+12", label: "vs last rep")
            ],
            ctaTitle: "Review this rep",
            ctaAction: {}
        )
        Spacer()
    }
    .padding(.horizontal, Spacing.screenH)
    .padding(.top, Spacing.lg)
    .background(AppColor.screenBackground)
}
#endif
