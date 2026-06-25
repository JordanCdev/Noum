#if canImport(SwiftUI)
import SwiftUI
import Charts

// MARK: - Progression Charts
//
// Animated SwiftUI Charts that render the user's last 30 days of session
// data — score, filler rate, and pace. Drops on the profile screen as a
// dedicated "How you're improving" surface.
//
// Each chart:
// - Uses LineMark + AreaMark for the gradient under the line.
// - Animates in on appear (.scaleEffect + opacity).
// - Pulls fresh data from `PracticeSessionStore` on every render.
// - Hides itself when fewer than 3 data points exist (a 1-point line is
//   noise, not signal).

@available(iOS 17.0, macOS 12.0, *)
struct ProgressionChartsCard: View {
    @ObservedObject var sessionStore: PracticeSessionStore

    @State private var hasAppeared = false
    @State private var selectedSeries: ChartSeries = .score
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shouldReduceMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    private var dataPoints: [ChartPoint] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return sessionStore.sessions
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
            .compactMap(ChartPoint.init)
    }

    var body: some View {
        if dataPoints.count < 3 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                seriesPicker
                chart
                statsRow
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .scaleEffect(hasAppeared ? 1 : 0.97)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear {
                // Respect Reduce Motion: appear instantly with no scale pop.
                if shouldReduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.standardSpring.delay(0.05)) { hasAppeared = true }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text("How you're improving")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text("\(dataPoints.count) reps · 30d")
                .font(Typography.micro)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
    }

    // MARK: - Series picker

    private var seriesPicker: some View {
        // Five pillar pills (Score/Fillers/Pace/Pauses/Pitch) don't fit
        // on one row at iPhone-mini widths, so the picker scrolls
        // horizontally. fixedSize on the Text prevents the mid-word
        // wrap we saw before ("Fill / ers", "Pa / ce") when the row
        // tried to compress to fit.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ChartSeries.allCases, id: \.self) { series in
                    Button {
                        if shouldReduceMotion {
                            selectedSeries = series
                        } else {
                            withAnimation(.snappySpring) {
                                selectedSeries = series
                            }
                        }
                        CoachHaptic.selectionTap()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: series.symbolName)
                                .font(.caption2.weight(.bold))
                            Text(series.shortLabel)
                                .font(Typography.caption.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(selectedSeries == series ? .white : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selectedSeries == series
                                ? AnyShapeStyle(series.tint)
                                : AnyShapeStyle(AppColor.tagBackground),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(series.shortLabel)
                }
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        let series = selectedSeries
        // Pause series may omit sessions that lacked word timings —
        // filter so we never draw a fake-zero point.
        let points = dataPoints.filter { series.hasValue(in: $0) }
        let values = points.map { series.value(from: $0) }
        let yMin = (values.min() ?? 0) * 0.85
        let yMax = (values.max() ?? 1) * 1.15

        return Chart {
            ForEach(points) { point in
                let value = series.value(from: point)
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", yMin),
                    yEnd: .value(series.shortLabel, value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [series.tint.opacity(0.30), series.tint.opacity(0.00)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value(series.shortLabel, value)
                )
                .foregroundStyle(series.tint)
                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                if point.id == points.last?.id {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(series.shortLabel, value)
                    )
                    .foregroundStyle(series.tint)
                    .symbolSize(60)
                }
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.10))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(Typography.micro)
                    .foregroundStyle(.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.08))
                AxisValueLabel()
                    .font(Typography.micro)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 160)
    }

    // MARK: - Stats row

    private var statsRow: some View {
        let series = selectedSeries
        let values = dataPoints
            .filter { series.hasValue(in: $0) }
            .map { series.value(from: $0) }
        let avg = values.reduce(0, +) / Double(max(1, values.count))
        let last7 = Array(values.suffix(7))
        let prev7 = Array(values.prefix(max(0, values.count - 7)).suffix(7))
        let last7Avg = last7.reduce(0, +) / Double(max(1, last7.count))
        let prev7Avg = prev7.isEmpty ? last7Avg : prev7.reduce(0, +) / Double(prev7.count)
        let delta = last7Avg - prev7Avg
        let deltaText = series.formatDelta(delta)
        let deltaIsImprovement = series.isImprovement(delta: delta)

        return HStack(spacing: 16) {
            statColumn(label: "30d avg", value: series.formatValue(avg), tint: series.tint)
            Divider().frame(height: 28)
            statColumn(
                label: "Last 7d vs prev",
                value: deltaText,
                tint: deltaIsImprovement ? AppColor.positive : (delta == 0 ? .secondary : AppColor.caution)
            )
            Divider().frame(height: 28)
            statColumn(label: "Latest", value: series.formatValue(values.last ?? 0), tint: series.tint)
        }
    }

    private func statColumn(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(value)
                .font(Typography.cardTitle.monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Series + point

@available(iOS 17.0, macOS 12.0, *)
extension ProgressionChartsCard {
    enum ChartSeries: CaseIterable {
        case score, fillerRate, pace, pauseRate, pitch

        var shortLabel: String {
            switch self {
            case .score:      return "Score"
            case .fillerRate: return "Fillers"
            case .pace:       return "Pace"
            case .pauseRate:  return "Pauses"
            case .pitch:      return "Pitch"
            }
        }

        var symbolName: String {
            switch self {
            case .score:      return "star.fill"
            case .fillerRate: return "speaker.slash.fill"
            case .pace:       return "speedometer"
            case .pauseRate:  return "pause.circle.fill"
            case .pitch:      return "waveform.path"
            }
        }

        var tint: Color {
            switch self {
            case .score:      return AppColor.brandBlue
            case .fillerRate: return AppColor.caution
            case .pace:       return AppColor.modeAhCounter
            case .pauseRate:  return AppColor.modeIM
            case .pitch:      return .pink
            }
        }

        func value(from point: ChartPoint) -> Double {
            switch self {
            case .score:      return point.score
            case .fillerRate: return point.fillerRate
            case .pace:       return point.pace
            case .pauseRate:  return point.pauseRate ?? 0
            // Render variation (1 - monotone) so up = better, like score.
            case .pitch:      return point.pitchVariation ?? 0
            }
        }

        /// Returns true only when the underlying point has real data for
        /// this series. Used to filter out sessions whose transcription
        /// provider didn't capture word timings (pause series), and
        /// sessions where pitch wasn't reliable (pitch series).
        func hasValue(in point: ChartPoint) -> Bool {
            switch self {
            case .pauseRate: return point.pauseRate != nil
            case .pitch:     return point.pitchVariation != nil
            default:         return true
            }
        }

        func formatValue(_ value: Double) -> String {
            switch self {
            case .score:      return String(format: "%.1f", value)
            case .fillerRate: return String(format: "%.1f/min", value)
            case .pace:       return String(format: "%.0f WPM", value)
            case .pauseRate:  return String(format: "%.1f/min", value)
            // Pitch variation as a percentage — easier to read than raw 0–1.
            case .pitch:      return "\(Int((value * 100).rounded()))%"
            }
        }

        func formatDelta(_ delta: Double) -> String {
            switch self {
            case .score:
                if abs(delta) < 0.05 { return "Even" }
                return String(format: "%+.1f", delta)
            case .fillerRate:
                if abs(delta) < 0.05 { return "Even" }
                return String(format: "%+.1f/min", delta)
            case .pace:
                if abs(delta) < 1 { return "Even" }
                return String(format: "%+.0f WPM", delta)
            case .pauseRate:
                if abs(delta) < 0.05 { return "Even" }
                return String(format: "%+.1f/min", delta)
            case .pitch:
                let pct = delta * 100
                if abs(pct) < 2 { return "Even" }
                return String(format: "%+.0f%%", pct)
            }
        }

        /// True when a positive delta is *good* for this series. Score: up
        /// is good. Filler rate: up is bad.
        func isImprovement(delta: Double) -> Bool {
            switch self {
            case .score:      return delta >= 0.05
            case .fillerRate: return delta <= -0.05
            case .pace:
                // Pace is more nuanced — extreme up or down is bad. For
                // this card's scope, treat closer-to-baseline as good.
                return abs(delta) < 5
            case .pauseRate:
                // More pauses = more deliberate delivery, generally good
                // up to a ceiling (~6/min). Treat upward movement as
                // improvement until we have enough data to model the curve.
                return delta >= 0.1
            case .pitch:
                // Higher variation (= lower monotone) is the improvement.
                // We render variation, so positive delta is good.
                return delta >= 0.02
            }
        }
    }

    struct ChartPoint: Identifiable {
        let id: UUID
        let date: Date
        let score: Double
        let fillerRate: Double
        let pace: Double
        /// Pauses per minute — nil when the session didn't capture word
        /// timings. Filtered out at the chart-render layer for the
        /// `.pauseRate` series so we don't draw fake zeros.
        let pauseRate: Double?
        /// 1.0 - monotone score (so up = more varied = good). nil when the
        /// pitch reading wasn't reliable. Filtered out at the chart-render
        /// layer for the `.pitch` series so flaky reads don't drag the line.
        let pitchVariation: Double?

        init?(session: PracticeSession) {
            guard let score = session.score else { return nil }
            self.id = session.id
            self.date = session.date
            self.score = Double(score)
            let minutes = max(1.0 / 60.0, session.duration / 60.0)
            self.fillerRate = Double(session.fillerWordCount) / minutes
            let words = session.wordCount
            self.pace = session.duration > 0 ? Double(words) / minutes : 0
            if let metrics = session.pauseMetrics, session.duration > 0 {
                self.pauseRate = Double(metrics.count) / minutes
            } else {
                self.pauseRate = nil
            }
            if let metrics = session.pitchMetrics, metrics.isReliable {
                self.pitchVariation = 1.0 - metrics.monotoneScore
            } else {
                self.pitchVariation = nil
            }
        }
    }
}

#endif
