#if canImport(SwiftUI)
import SwiftUI

/// A restrained evidence card for a real personal best. The caller still
/// owns the metric, proof, and route; this surface deliberately avoids the
/// gradient, sparkles, glow, and celebration language used by the retired
/// post-rep interstitials.
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
    /// Retained for source compatibility. Personal-best cards no longer use
    /// decorative sparkles, regardless of the legacy argument value.
    var showSparkles: Bool = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(kicker, systemImage: "chart.line.uptrend.xyaxis")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(bodyCopy)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !stats.isEmpty {
                statLayout
            }

            cta
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.xs) {
                ForEach(stats) { stat in
                    statTile(stat)
                }
            }
        } else {
            HStack(spacing: Spacing.xs) {
                ForEach(stats) { stat in
                    statTile(stat)
                }
            }
        }
    }

    private func statTile(_ stat: Stat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(stat.value)
                .font(Typography.figtreeNumeric(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()

            Text(stat.label)
                .font(Typography.captionSmall)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.innerSurface,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var cta: some View {
        Button(action: ctaAction) {
            HStack(spacing: Spacing.xs) {
                Text(ctaTitle)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                Spacer(minLength: Spacing.xs)
                ctaIcon()
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.sm)
            .background(
                AppColor.brandBlue.opacity(0.07),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(ctaTitle)
    }
}

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

@available(iOS 17.0, *)
#Preview("Personal best record") {
    VStack(spacing: Spacing.md) {
        PersonalBestHeroCard(
            kicker: "Personal best · this week",
            headline: "A clean rep at full pressure",
            body: "You held a 60-second answer with zero fillers — a first this week.",
            stats: [
                .init(value: "8/10", label: "Score"),
                .init(value: "+1", label: "Previous best")
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
