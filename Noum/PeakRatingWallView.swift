#if canImport(SwiftUI)
import SwiftUI
#if canImport(Charts)
import Charts
#endif

// MARK: - Peak Rating Wall (M16)
//
// Full-screen surface that opens the "chase loop" from the compact
// `PeakRatingWallCard` on Profile. Three honest comparisons, each with a
// sparkline of the user's own history:
//
//   1. Best in week — highest rating this ISO week (via
//      `RatingStore.peakRatingThisWeek`, hidden when no rated reps yet).
//   2. Best ever — `SpeakingRating.peakRating`, always present once any
//      rated session lands.
//   3. Best in your friends — top peak ratings in the user's current
//      league bucket (via `LeagueManager.peakRatingsInBucket()`), top 5
//      list. Hidden entirely when the bucket is empty or unreachable.
//
// VISION anti-goals honored:
//   - never punish-shame ("you fell" copy is banned)
//   - never publish raw transcripts (rows show rating + name + when only)
//   - hide empty sections instead of loading placeholders
//   - sentence case, no emoji, no exclamation marks
@available(iOS 17.0, *)
struct PeakRatingWallView: View {
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var league = LeagueManager.shared
    @StateObject private var authManager = AuthManager.shared

    @State private var bucketPeaks: [PeakRatingEntry] = []
    @State private var hasLoadedBucket = false

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if ratingStore.rating.hasRatedEvidence {
                        header
                        bestInWeekSection
                        bestEverSection
                        if !bucketPeaks.isEmpty {
                            bestInFriendsSection
                        }
                    } else {
                        unratedEmptyState
                    }
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("Peak rating")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("peakRatingWall.screen")
        .task {
            await loadBucket()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where you peak")
                .font(Typography.bigStat)
                .foregroundStyle(.primary)
            Text("Your best this week, your best ever, and how that lines up with your league.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var unratedEmptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.brandBlue)
            Text("No peak rating yet")
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
            Text("One rated rep sets the first mark. After that, this wall shows your best this week, your best ever, and your league comparison.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Best in week

    @ViewBuilder
    private var bestInWeekSection: some View {
        if let weekPeak = ratingStore.peakRatingThisWeek {
            sectionCard(
                kicker: "Best in week",
                accent: AppColor.brandBlue,
                primary: "\(weekPeak)",
                supporting: weekSupportingCopy(weekPeak: weekPeak),
                sparkline: { sparkline(history: thisWeekHistory, accent: AppColor.brandBlue) },
                accessibilityValue: "Best rating this week, \(weekPeak)"
            )
        } else {
            // No rated reps yet this week — honest reduction to a
            // muted "still to come" card rather than a numeric placeholder.
            // Sentence case, no exclamation, no shame for not yet
            // practising.
            sectionCard(
                kicker: "Best in week",
                accent: .secondary,
                primary: "—",
                supporting: "Your first rated rep this week will set the mark.",
                sparkline: { EmptyView() },
                accessibilityValue: "No rated rep this week yet."
            )
        }
    }

    private func weekSupportingCopy(weekPeak: Int) -> String {
        let current = ratingStore.rating.overall
        if weekPeak > current {
            let diff = weekPeak - current
            return "You held \(weekPeak) earlier — \(diff) above where you sit right now."
        }
        return "You're sitting at this week's peak. Hold it through one more rep."
    }

    // MARK: - Best ever

    @ViewBuilder
    private var bestEverSection: some View {
        let peak = ratingStore.rating.peakRating
        let current = ratingStore.rating.overall
        if ratingStore.rating.totalRatedSessions > 0 {
            sectionCard(
                kicker: "Best ever",
                accent: AppColor.pro,
                primary: "\(peak)",
                supporting: bestEverSupportingCopy(peak: peak, current: current),
                sparkline: { sparkline(history: allTimeHistory, accent: AppColor.pro) },
                accessibilityValue: "Best ever rating, \(peak)"
            )
        }
    }

    private func bestEverSupportingCopy(peak: Int, current: Int) -> String {
        if current >= peak {
            return "You're at your all-time high. Hold the line."
        }
        let diff = peak - current
        return "Your highest rating to date. You're \(diff) below it right now."
    }

    // MARK: - Best in your friends

    private var bestInFriendsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Text("Best in your friends")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(league.tier.title)
                    .font(Typography.micro)
                    .foregroundStyle(league.tier.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(league.tier.tint.opacity(0.14), in: Capsule())
            }

            VStack(spacing: 0) {
                ForEach(Array(bucketPeaks.enumerated()), id: \.element.id) { index, entry in
                    bucketRow(rank: index + 1, entry: entry)
                    if index < bucketPeaks.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )

            Text("Top peaks in your \(league.tier.title.lowercased()) bucket this week.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func bucketRow(rank: Int, entry: PeakRatingEntry) -> some View {
        let isYou = entry.accountID == authManager.currentAccountID
        return HStack(spacing: Spacing.sm) {
            Text("\(rank)")
                .font(Typography.figtreeNumeric(size: 15, weight: .bold, relativeTo: .subheadline))
                .foregroundStyle(rankTint(rank))
                .frame(width: 22, alignment: .center)

            ZStack {
                Circle()
                    .fill(isYou ? AppColor.brandBlue.opacity(0.18) : AppColor.brandBlue.opacity(0.10))
                    .frame(width: 30, height: 30)
                Text(initials(for: entry.displayName))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName ?? "Speaker")
                        .font(.subheadline.weight(isYou ? .bold : .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isYou {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColor.brandBlue, in: Capsule())
                    }
                }
                Text(relativeAchievedAt(entry.achievedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.xs)

            Text("\(Int(entry.peakRating))")
                .font(Typography.figtreeNumeric(size: 18, weight: .bold, relativeTo: .headline))
                .foregroundStyle(AppColor.brandBlue)
        }
        .frame(minHeight: 48)
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bucketRowAccessibility(rank: rank, entry: entry, isYou: isYou))
    }

    // MARK: - Section card builder

    @ViewBuilder
    private func sectionCard(
        kicker: String,
        accent: Color,
        primary: String,
        supporting: String,
        sparkline: () -> some View,
        accessibilityValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(kicker)
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(primary)
                    .font(Typography.figtreeNumeric(size: 44, relativeTo: .largeTitle))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                    .animation(.standardSpring, value: primary)
                Spacer()
            }

            Text(supporting)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            sparkline()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.10), radius: 14, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kicker)
        .accessibilityValue(accessibilityValue)
    }

    // MARK: - Sparkline

    @ViewBuilder
    private func sparkline(history: [RatingSnapshot], accent: Color) -> some View {
        #if canImport(Charts)
        let points = sparklinePoints(history: history)
        if points.count >= 2 {
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Rating", point.rating)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Rating", point.rating)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.18), accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: sparkDomain(points: points))
            .frame(height: 56)
            .accessibilityHidden(true) // the card header already narrates the number
        } else {
            // Single-point or empty histories collapse silently — drawing
            // a one-point "line" reads as a misleading flat trend.
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }

    private struct SparkPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let rating: Int
    }

    private func sparklinePoints(history: [RatingSnapshot]) -> [SparkPoint] {
        let calendar = Calendar.current
        var byDay: [Date: Int] = [:]
        for snapshot in history {
            let day = calendar.startOfDay(for: snapshot.date)
            byDay[day] = max(byDay[day] ?? 0, snapshot.rating)
        }
        return byDay
            .map { SparkPoint(date: $0.key, rating: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func sparkDomain(points: [SparkPoint]) -> ClosedRange<Int> {
        let lo = points.map(\.rating).min() ?? 400
        let hi = points.map(\.rating).max() ?? 400
        let pad = max(10, (hi - lo) / 4)
        return (lo - pad)...(hi + pad)
    }

    // MARK: - History slices

    private var thisWeekHistory: [RatingSnapshot] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return ratingStore.rating.ratingHistory.filter { week.contains($0.date) }
    }

    private var allTimeHistory: [RatingSnapshot] {
        ratingStore.rating.ratingHistory
    }

    // MARK: - Helpers

    private func loadBucket() async {
        guard !hasLoadedBucket else { return }
        hasLoadedBucket = true
        guard ratingStore.rating.hasRatedEvidence else { return }
        bucketPeaks = await league.peakRatingsInBucket(limit: 5)
    }

    private func rankTint(_ rank: Int) -> Color {
        switch rank {
        case 1: return LeagueTier.gold.tint
        case 2: return LeagueTier.silver.tint
        case 3: return LeagueTier.bronze.tint
        default: return .secondary
        }
    }

    private func initials(for name: String?) -> String {
        guard let name, !name.isEmpty else { return "—" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func relativeAchievedAt(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func bucketRowAccessibility(rank: Int, entry: PeakRatingEntry, isYou: Bool) -> String {
        var parts: [String] = ["Rank \(rank)", entry.displayName ?? "Speaker"]
        if isYou { parts.append("You") }
        parts.append("Peak rating \(Int(entry.peakRating))")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview("Peak rating wall") {
    NavigationStack {
        PeakRatingWallView()
    }
}
#endif

#endif
