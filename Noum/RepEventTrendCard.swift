#if canImport(SwiftUI)
import SwiftUI

// MARK: - Rep Event Trend Card
//
// The VISIBLE companion to `RepEventTrendEngine` — the LONGITUDINAL positional
// read that, until now, only reached the coach prompt (via
// `CoachContextBuilder`'s POSITIONAL TREND block) and never the user's eyes.
// Where `RepTimelineCard` shows WHERE this one rep's events fell, this shows
// when the SAME position keeps failing across recent reps ("your fastest
// stretch keeps landing in the close"). It is the recurring-habit read a human
// coach leads with — the layer Speeko/Orai/Yoodli's whole-take averages never
// reach — rendered in Noum's calm card language, not a dense dashboard.
//
// HONEST BY CONSTRUCTION. It renders ONLY the trends `RepEventTrendEngine`
// already decided were credible (>= 3 occurrences in one zone, >= 0.6
// super-majority, denominator = reps that CARRIED the event). The subline names
// that earned denominator explicitly ("in 4 of your last 5 reps with a rushed
// stretch") so the read can never imply a base rate it hasn't got, and a footer
// carries the rep-set hedge ("a pattern in your recent reps, not a fixed
// trait"). `SummaryView` constructs the card only when the engine returns a
// non-empty set, so it never shows a hollow shell.
//
// Motion-free by design (a static list satisfies reduced-motion without a
// branch). A11y collapses the whole card into one coherent sentence.

@available(iOS 17.0, macOS 12.0, *)
struct RepEventTrendCard: View {
    let trends: [RepEventTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(AppColor.brandBlue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "repeat")
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.brandBlue)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recurring pattern")
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text("The same position keeps recurring across your recent reps.")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(trends, id: \.self) { trend in
                    row(for: trend)
                }
            }

            Text(RepEventTrendCopy.hedgeFooter)
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RepEventTrendCopy.accessibilityReadout(for: trends))
        .accessibilityIdentifier("summary.repEventTrendCard")
    }

    private func row(for trend: RepEventTrend) -> some View {
        let style = RepEventTrendCopy.style(for: trend.kind)
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: style.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(style.color)
                .frame(width: 18)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(RepEventTrendCopy.headline(for: trend))
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(RepEventTrendCopy.evidenceSubline(for: trend))
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.innerSurface,
            in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
        )
    }
}

// MARK: - Rep Event Trend Copy
//
// Pure, view-free derivation of the card's user-facing strings, composed ONLY
// from the trend's typed fields (kind / zone / dominantCount / repsWithSignal).
// The card can therefore never assert a claim the engine didn't earn, and the
// copy contract is unit-testable without a SwiftUI host — the same discipline
// `RepTimelineCopy` uses.

enum RepEventTrendCopy {
    /// Semantic symbol + color per event kind, reusing EXACTLY the tokens
    /// `RepTimelineCard` uses (pace = caution amber, silence = brandBlue,
    /// fillers = muted secondary) so the two positional surfaces read as one.
    static func style(for kind: RepEventTrend.EventKind) -> (symbol: String, color: Color) {
        switch kind {
        case .rushedBurst:   return ("hare.fill", AppColor.caution)
        case .longestPause:  return ("pause.circle.fill", AppColor.brandBlue)
        case .fillerCluster: return ("waveform", AppColor.textSecondary)
        }
    }

    /// The recurring-position headline — names the event and the zone it keeps
    /// landing in, present-continuous ("keeps") to signal a pattern not a verdict.
    static func headline(for trend: RepEventTrend) -> String {
        let zone = trend.zone.label
        switch trend.kind {
        case .rushedBurst:   return "Your fastest stretch keeps landing in the \(zone)."
        case .longestPause:  return "Your longest silence keeps falling in the \(zone)."
        case .fillerCluster: return "Fillers keep clustering in the \(zone)."
        }
    }

    /// The earned-denominator evidence line. Names the count AND the base it is
    /// out of ("reps that had a rushed stretch"), so the read never implies a
    /// prevalence it hasn't measured.
    static func evidenceSubline(for trend: RepEventTrend) -> String {
        let base: String
        switch trend.kind {
        case .rushedBurst:   base = "with a rushed stretch"
        case .longestPause:  base = "with a notable pause"
        case .fillerCluster: base = "with a filler cluster"
        }
        return "In \(trend.dominantCount) of your last \(trend.repsWithSignal) reps \(base)."
    }

    /// The rep-set hedge, shown once at the foot of the card.
    static let hedgeFooter = "A pattern in your recent reps — a place to aim next, not a fixed trait."

    /// One coherent VoiceOver sentence covering every rendered trend.
    static func accessibilityReadout(for trends: [RepEventTrend]) -> String {
        let clauses = trends.map { trend -> String in
            let kindPhrase: String
            switch trend.kind {
            case .rushedBurst:   kindPhrase = "fastest stretch"
            case .longestPause:  kindPhrase = "longest silence"
            case .fillerCluster: kindPhrase = "fillers"
            }
            return "\(kindPhrase) in the \(trend.zone.label) in \(trend.dominantCount) of \(trend.repsWithSignal) reps"
        }
        return "Recurring pattern. " + clauses.joined(separator: ", ") + ". A pattern in recent reps, not a fixed trait."
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Trend — rushed close") {
    RepEventTrendCard(trends: [
        RepEventTrend(kind: .rushedBurst, zone: .close, dominantCount: 4, repsWithSignal: 5)
    ])
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Trend — two patterns") {
    RepEventTrendCard(trends: [
        RepEventTrend(kind: .rushedBurst, zone: .close, dominantCount: 4, repsWithSignal: 5),
        RepEventTrend(kind: .longestPause, zone: .opening, dominantCount: 3, repsWithSignal: 3)
    ])
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
