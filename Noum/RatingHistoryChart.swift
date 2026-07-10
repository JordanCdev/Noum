#if canImport(SwiftUI)
import SwiftUI
#if canImport(Charts)
import Charts
#endif

// MARK: - Rating History Chart

enum RatingTrendCopy {
    static func label(for trend: TrendDirection) -> String {
        switch trend {
        case .improving: return "Trending up"
        case .stable: return "Holding steady"
        case .declining: return "Needs another read"
        case .newIssue: return "New pattern detected"
        case .resolved: return "Recent issue resolved"
        }
    }
}

/// Renders the user's last-30-days rating history as a smoothed `SwiftUI Chart`,
/// with a peak-rating marker and an inline trend label below.
///
/// First Chart in the app (per VISION.md milestone 1) — replaces the previous
/// "Trending up" pill on the Speaking Rating card.
@available(iOS 17.0, *)
struct RatingHistoryChart: View {
    let history: [RatingSnapshot]
    let peakRating: Int
    let trend: TrendDirection

    private let chartHeight: CGFloat = 96
    private let lookbackDays: Int = 30

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            #if canImport(Charts)
            chart
                .frame(height: chartHeight)
                .accessibilityLabel(accessibilityLabel)
            #else
            fallback
                .frame(height: chartHeight)
            #endif

            trendStrip
        }
    }

    #if canImport(Charts)
    @ViewBuilder
    private var chart: some View {
        let series = recentSeries
        if series.isEmpty {
            // No history yet — collapse the chart slot entirely instead
            // of rendering a placeholder. The card's header (rating
            // number + peak + session count) stays visible above this;
            // the trend strip below still surfaces "Holding steady" /
            // "Trending up" / etc. from the live trend computation.
            // Per CLAUDE.md: no placeholder logic presented as complete.
            EmptyView()
        } else {
            Chart {
                ForEach(series) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Rating", point.rating)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppColor.brandBlue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Rating", point.rating)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.brandBlue.opacity(0.18), AppColor.brandBlue.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                if let peakPoint = series.max(by: { $0.rating < $1.rating }) {
                    PointMark(
                        x: .value("Date", peakPoint.date),
                        y: .value("Rating", peakPoint.rating)
                    )
                    .symbolSize(60)
                    .foregroundStyle(AppColor.pro)
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Text("Peak \(peakPoint.rating)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppColor.pro)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColor.pro.opacity(0.12), in: Capsule())
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.black.opacity(0.05))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.black.opacity(0.05))
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
        }
    }
    #endif

    private var fallback: some View {
        Text("Rating chart needs iOS Charts support.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // emptyState removed — when history is empty the chart slot now
    // collapses via `EmptyView()` rather than rendering a placeholder
    // line ("Rated reps will plot here."). Per CLAUDE.md engineering
    // bans: no placeholder logic presented as complete.

    // MARK: - Trend Strip

    private var trendStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: trendIcon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(trendColor)
            Text(trendLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            if peakRating > 0 {
                Text("Peak \(peakRating)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Series + Domain

    /// `RatingSnapshot` is a *change* event, not a daily sample. We bucket by
    /// day so the chart shows a single point per day (the latest rating value).
    private var recentSeries: [Series.Point] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let recent = history.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }

        var byDay: [Date: Int] = [:]
        let calendar = Calendar.current
        for snapshot in recent {
            let day = calendar.startOfDay(for: snapshot.date)
            byDay[day] = snapshot.rating
        }

        return byDay
            .map { Series.Point(date: $0.key, rating: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private var yDomain: ClosedRange<Int> {
        let series = recentSeries
        guard !series.isEmpty else { return 350...450 }
        let lo = series.map(\.rating).min() ?? 400
        let hi = series.map(\.rating).max() ?? 400
        let pad = max(20, (hi - lo) / 4)
        return (lo - pad)...(hi + pad)
    }

    // MARK: - Trend mapping (mirrors ProfileView)

    private var trendIcon: String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .newIssue: return "exclamationmark.circle"
        case .resolved: return "checkmark.circle"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .improving, .resolved: return AppColor.positive
        case .stable: return .secondary
        case .declining, .newIssue: return AppColor.caution
        }
    }

    private var trendLabel: String {
        RatingTrendCopy.label(for: trend)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let series = recentSeries
        guard !series.isEmpty else { return "No rating history yet." }
        let first = series.first!
        let last = series.last!
        return "Rating chart over \(series.count) days. From \(first.rating) to \(last.rating). Peak \(peakRating)."
    }

    private enum Series {
        struct Point: Identifiable, Equatable {
            let id = UUID()
            let date: Date
            let rating: Int
        }
    }
}
#endif
