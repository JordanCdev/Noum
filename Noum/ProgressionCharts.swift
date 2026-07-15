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
// - Uses a restrained linear LineMark + point markers so sparse data
//   never gets visually exaggerated by spline overshoot.
// - Animates in on appear (.scaleEffect + opacity).
// - Pulls fresh data from `PracticeSessionStore` on every render.
// - Hides itself when fewer than 3 data points exist (a 1-point line is
//   noise, not signal).

enum ReviewDevelopmentChartEvidence {
    static let minimumVisibleSessionCount = 3
    static let lookbackDays = 30

    static func recentScoredSessions(
        in sessions: [PracticeSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PracticeSession] {
        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        return PracticeProgressEligibility.eligibleSessions(in: sessions)
            .filter { $0.date >= cutoff && $0.score != nil }
            .sorted { $0.date < $1.date }
    }

    static func hasEnoughData(
        in sessions: [PracticeSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        recentScoredSessions(in: sessions, now: now, calendar: calendar).count >= minimumVisibleSessionCount
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct ProgressionChartsCard: View {
    @ObservedObject var sessionStore: PracticeSessionStore

    @State private var hasAppeared = false
    @State private var selectedSeries: ChartSeries = .score
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var shouldReduceMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    private var dataPoints: [ChartPoint] {
        ReviewDevelopmentChartEvidence.recentScoredSessions(in: sessionStore.progressEligibleSessions)
            .compactMap(ChartPoint.init)
    }

    var body: some View {
        if dataPoints.count < ReviewDevelopmentChartEvidence.minimumVisibleSessionCount {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                header
                seriesPicker
                metricContent
                if shouldShowStatsRow {
                    statsRow
                }
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
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("How you're improving")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)

                Text("\(dataPoints.count) reps in the last 30 days")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 34, height: 34)
                .background(AppColor.brandBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        }
    }

    // MARK: - Series picker

    private var seriesPicker: some View {
        LazyVGrid(columns: seriesPickerColumns, alignment: .leading, spacing: 6) {
            ForEach(ChartSeries.allCases, id: \.self) { series in
                seriesButton(series)
            }
        }
    }

    private var seriesPickerColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 6),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
        )
    }

    private var shouldShowStatsRow: Bool {
        selectedSeriesValues.count >= ChartPresentationModel.minimumDirectionalEvidence
    }

    private var selectedSeriesValues: [Double] {
        dataPoints
            .compactMap { selectedSeries.value(from: $0) }
    }

    private func seriesButton(_ series: ChartSeries) -> some View {
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
                    .font(Typography.captionSmall.weight(.bold))
                Text(series.shortLabel)
                    .font(Typography.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(selectedSeries == series ? .white : .primary.opacity(0.68))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                selectedSeries == series
                    ? AnyShapeStyle(series.tint)
                    : AnyShapeStyle(AppColor.tagBackground.opacity(0.72)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(series.shortLabel)
        .accessibilityAddTraits(selectedSeries == series ? .isSelected : [])
    }

    // MARK: - Chart

    @ViewBuilder
    private var metricContent: some View {
        let series = selectedSeries
        let points = dataPoints.filter { series.hasValue(in: $0) }

        if points.count < 2 {
            insufficientMetricCard(for: series)
        } else {
            let model = ChartPresentationModel(series: series, points: points)
            VStack(alignment: .leading, spacing: 12) {
                chartRead(for: series, model: model)
                if model.shouldShowTrendLine {
                    chart(for: series, model: model)
                } else {
                    baselineProgressPanel(for: series, model: model)
                }
            }
        }
    }

    private func chart(for series: ChartSeries, model: ChartPresentationModel) -> some View {
        let latestRawIndex = model.rawSamples.last?.index

        return VStack(spacing: 4) {
            Chart {
                if model.shouldShowTrendLine {
                    ForEach(model.trendSamples) { sample in
                        AreaMark(
                            x: .value("Rep", sample.index),
                            yStart: .value("Floor", model.yMin),
                            yEnd: .value(series.shortLabel, sample.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [series.tint.opacity(0.10), series.tint.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.linear)

                        LineMark(
                            x: .value("Rep", sample.index),
                            y: .value(series.shortLabel, sample.value)
                        )
                        .foregroundStyle(series.tint.opacity(0.82))
                        .lineStyle(StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.linear)
                    }
                }

                ForEach(model.rawSamples) { sample in
                    PointMark(
                        x: .value("Rep", sample.index),
                        y: .value(series.shortLabel, sample.value)
                    )
                    .foregroundStyle(
                        series.tint.opacity(
                            sample.index == latestRawIndex
                                ? 0.92
                                : (model.shouldShowTrendLine ? 0.22 : 0.48)
                        )
                    )
                    .symbolSize(sample.index == latestRawIndex ? 70 : (model.shouldShowTrendLine ? 16 : 42))
                }

                RuleMark(y: .value("Average", model.average))
                    .foregroundStyle(series.tint.opacity(model.shouldShowTrendLine ? 0.14 : 0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 6]))
            }
            .chartYScale(domain: model.yMin...model.yMax)
            .chartXScale(domain: model.xMin...model.xMax)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(
                        LinearGradient(
                            colors: [series.tint.opacity(0.045), AppColor.tagBackground.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(Color.white.opacity(0.56), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }
            .frame(height: 132)

            HStack {
                Text("First rep")
                Spacer()
                Text("Latest")
            }
            .font(Typography.micro)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
        }
        .frame(height: 144)
    }

    // MARK: - Stats row

    @ViewBuilder
    private var statsRow: some View {
        let series = selectedSeries
        let values = dataPoints
            .compactMap { series.value(from: $0) }

        if values.count >= 2 {
            let avg = values.reduce(0, +) / Double(values.count)
            let last7 = Array(values.suffix(7))
            let prev7 = Array(values.prefix(max(0, values.count - 7)).suffix(7))
            let last7Avg = last7.reduce(0, +) / Double(max(1, last7.count))
            let prev7Avg = prev7.isEmpty ? last7Avg : prev7.reduce(0, +) / Double(prev7.count)
            let delta = last7Avg - prev7Avg
            let deltaText = series.formatDelta(delta)
            let deltaTint: Color = if series.isFlat(delta: delta) {
                .secondary
            } else if series.isImprovement(delta: delta, recentAverage: last7Avg) {
                AppColor.positive
            } else {
                AppColor.caution
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    statColumn(label: "30d avg", value: series.formatValue(avg), tint: .primary)
                    statColumn(label: "7d shift", value: deltaText, tint: deltaTint)
                    statColumn(label: "Latest", value: series.formatValue(values.last ?? 0), tint: series.tint)
                }
            } else {
                HStack(spacing: 10) {
                    statColumn(label: "30d avg", value: series.formatValue(avg), tint: .primary)
                    statColumn(label: "7d shift", value: deltaText, tint: deltaTint)
                    statColumn(label: "Latest", value: series.formatValue(values.last ?? 0), tint: series.tint)
                }
            }
        }
    }

    private func statColumn(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.tagBackground.opacity(0.54), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func chartRead(for series: ChartSeries, model: ChartPresentationModel) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: model.readIcon)
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(model.readTint)
                .frame(width: 28, height: 28)
                .background(model.readTint.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(model.readTitle)
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)

                Text(model.readBody)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(series.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func baselineProgressPanel(for series: ChartSeries, model: ChartPresentationModel) -> some View {
        let progress = model.baselineProgress

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evidence track")
                        .font(Typography.cardLabel)
                        .foregroundStyle(.primary)

                    Text(progress.remainingCopy)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Text(progress.sampleLabel)
                    .font(Typography.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(series.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(series.tint.opacity(0.10), in: Capsule())
            }

            baselineRail(progress: progress, tint: series.tint)

            HStack(spacing: 12) {
                baselineInlineMetric(
                    icon: series.symbolName,
                    title: "Latest",
                    value: model.latestFormatted,
                    tint: series.tint
                )

                Spacer(minLength: 8)

                baselineInlineMetric(
                    icon: progress.remaining == 0 ? "checkmark.seal.fill" : "clock",
                    title: "Trend",
                    value: progress.trendStateLabel,
                    tint: progress.remaining == 0 ? AppColor.positive : .secondary
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .background(
            LinearGradient(
                colors: [series.tint.opacity(0.07), AppColor.tagBackground.opacity(0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func baselineRail(progress: ChartPresentationModel.BaselineProgress, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColor.tagBackground.opacity(0.78))
                    .frame(height: 10)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.92), tint.opacity(0.48)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * progress.fraction, height: 10)

                HStack(spacing: 0) {
                    ForEach(0..<progress.total, id: \.self) { index in
                        Circle()
                            .fill(index < progress.current ? Color.white.opacity(0.86) : Color.white.opacity(0.92))
                            .frame(width: 4, height: 4)

                        if index < progress.total - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
        }
        .frame(height: 16)
    }

    private func baselineInlineMetric(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Typography.micro)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(value)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
    }

    private func insufficientMetricCard(for series: ChartSeries) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(series.tint)
                .frame(width: 30, height: 30)
                .background(series.tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Not enough \(series.shortLabel.lowercased()) signal yet")
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)

                Text("Run two measured reps and Noum will draw the trend.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .center)
        .background(AppColor.tagBackground.opacity(0.54), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
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

        var minimumVisualSpan: Double {
            switch self {
            case .score:      return 2.0
            case .fillerRate: return 1.0
            case .pace:       return 36.0
            case .pauseRate:  return 1.0
            case .pitch:      return 0.18
            }
        }

        var lowerVisualBound: Double {
            switch self {
            case .score, .fillerRate, .pace, .pauseRate, .pitch:
                return 0
            }
        }

        var upperVisualBound: Double? {
            switch self {
            case .score: return 10
            case .pitch: return 1
            case .fillerRate, .pace, .pauseRate:
                return nil
            }
        }

        func value(from point: ChartPoint) -> Double? {
            switch self {
            case .score:      return point.score
            case .fillerRate: return point.fillerRate
            case .pace:       return point.pace
            case .pauseRate:  return point.pauseRate
            // Render variation (1 - monotone) so up = better, like score.
            case .pitch:      return point.pitchVariation
            }
        }

        /// Returns true only when the underlying point has real data for
        /// this series. Used to filter out sessions whose transcription
        /// provider didn't capture word timings (pause series), and
        /// sessions where pitch wasn't reliable (pitch series).
        func hasValue(in point: ChartPoint) -> Bool {
            value(from: point) != nil
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

        func formatAxisValue(_ value: Double) -> String {
            switch self {
            case .score:      return String(format: "%.0f", value)
            case .fillerRate: return String(format: "%.1f/m", value)
            case .pace:       return String(format: "%.0f", value)
            case .pauseRate:  return String(format: "%.1f/m", value)
            case .pitch:      return "\(Int((value * 100).rounded()))%"
            }
        }

        func formatDelta(_ delta: Double) -> String {
            switch self {
            case .score:
                if abs(delta) < 0.15 { return "Even" }
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

        func isFlat(delta: Double) -> Bool {
            switch self {
            case .score:      return abs(delta) < 0.15
            case .fillerRate: return abs(delta) < 0.05
            case .pace:       return abs(delta) < 5
            case .pauseRate:  return abs(delta) < 0.10
            case .pitch:      return abs(delta) < 0.02
            }
        }

        /// True when the recent shift is good for this series. Pace needs
        /// current-position context: 56 WPM moving up is progress, while
        /// 175 WPM moving up is drift.
        func isImprovement(delta: Double, recentAverage: Double? = nil) -> Bool {
            switch self {
            case .score:      return delta >= 0.05
            case .fillerRate: return delta <= -0.05
            case .pace:
                guard let recentAverage else { return false }
                if ConversationalPaceBand.contains(recentAverage) {
                    return true
                }
                if recentAverage < ConversationalPaceBand.minWPM {
                    return delta >= 5
                }
                return delta <= -5
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

        func movementCopy(delta: Double) -> String {
            if isFlat(delta: delta) {
                return "\(shortLabel) is holding steady across these reps."
            }

            let formatted = formatDelta(delta)
            switch self {
            case .score:
                return delta > 0
                    ? "Score is up \(formatted.replacingOccurrences(of: "+", with: "")) from first to latest."
                    : "Score is down \(formatted.replacingOccurrences(of: "-", with: "")) from first to latest."
            case .fillerRate:
                return delta < 0
                    ? "Fillers are down \(formatted.replacingOccurrences(of: "-", with: "")) from first to latest."
                    : "Fillers are up \(formatted.replacingOccurrences(of: "+", with: "")) from first to latest."
            case .pace:
                return delta > 0
                    ? "Pace is up \(formatted.replacingOccurrences(of: "+", with: "")) from first to latest."
                    : "Pace is down \(formatted.replacingOccurrences(of: "-", with: "")) from first to latest."
            case .pauseRate:
                return delta > 0
                    ? "Pauses are up \(formatted.replacingOccurrences(of: "+", with: "")) from first to latest."
                    : "Pauses are down \(formatted.replacingOccurrences(of: "-", with: "")) from first to latest."
            case .pitch:
                return delta > 0
                    ? "Pitch variety is up \(formatted.replacingOccurrences(of: "+", with: "")) from first to latest."
                    : "Pitch variety is down \(formatted.replacingOccurrences(of: "-", with: "")) from first to latest."
            }
        }

        func recentMovementCopy(delta: Double) -> String {
            if isFlat(delta: delta) {
                return "\(shortLabel) is holding steady across the recent block."
            }

            let formatted = formatDelta(delta)
            switch self {
            case .score:
                return delta > 0
                    ? "Recent score average is up \(formatted.replacingOccurrences(of: "+", with: "")) over the previous block."
                    : "Recent score average is down \(formatted.replacingOccurrences(of: "-", with: "")) over the previous block."
            case .fillerRate:
                return delta < 0
                    ? "Recent filler rate is down \(formatted.replacingOccurrences(of: "-", with: "")) over the previous block."
                    : "Recent filler rate is up \(formatted.replacingOccurrences(of: "+", with: "")) over the previous block."
            case .pace:
                return delta > 0
                    ? "Recent pace average is up \(formatted.replacingOccurrences(of: "+", with: "")) over the previous block."
                    : "Recent pace average is down \(formatted.replacingOccurrences(of: "-", with: "")) over the previous block."
            case .pauseRate:
                return delta > 0
                    ? "Recent pause rate is up \(formatted.replacingOccurrences(of: "+", with: "")) over the previous block."
                    : "Recent pause rate is down \(formatted.replacingOccurrences(of: "-", with: "")) over the previous block."
            case .pitch:
                return delta > 0
                    ? "Recent pitch variety is up \(formatted.replacingOccurrences(of: "+", with: "")) over the previous block."
                    : "Recent pitch variety is down \(formatted.replacingOccurrences(of: "-", with: "")) over the previous block."
            }
        }
    }

    struct ChartPoint: Identifiable {
        let id: UUID
        let date: Date
        let score: Double
        /// Optional because a generally progress-eligible row can still be too
        /// thin, noisy, stale, or fixture-only for historical filler reads.
        let fillerRate: Double?
        /// Optional for the same reason. Missing pace must never render as a
        /// real zero or enter averages, trends, or target-band coaching.
        let pace: Double?
        /// Pauses per minute — nil when the session didn't capture word
        /// timings. Filtered out at the chart-render layer for the
        /// `.pauseRate` series so we don't draw fake zeros.
        let pauseRate: Double?
        /// 1.0 - monotone score (so up = more varied = good). nil when the
        /// pitch reading wasn't reliable. Filtered out at the chart-render
        /// layer for the `.pitch` series so flaky reads don't drag the line.
        let pitchVariation: Double?

        init?(session: PracticeSession) {
            guard PracticeProgressEligibility.qualifies(session) else { return nil }
            guard let score = session.score else { return nil }
            self.id = session.id
            self.date = session.date
            self.score = Double(score)
            let minutes = max(1.0 / 60.0, session.duration / 60.0)
            self.fillerRate = FillerBurden.quantityQualified(session)?.ratePerMinute
            self.pace = SessionQualifier.quantityQualifiedWordsPerMinute(session)
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

    struct ChartPresentationModel {
        let yMin: Double
        let yMax: Double
        let xMin: Double
        let xMax: Double
        let average: Double
        let rawSamples: [TrendSample]
        let trendSamples: [TrendSample]
        let shouldShowTrendLine: Bool
        let latestFormatted: String
        let baselineProgress: BaselineProgress
        let readTitle: String
        let readBody: String
        let readIcon: String
        let readTint: Color
        static let minimumDirectionalEvidence = 8

        struct TrendSample: Identifiable, Equatable {
            let index: Double
            let value: Double

            var id: Double { index }
        }

        struct BaselineProgress: Equatable {
            let current: Int
            let total: Int
            let remaining: Int

            var remainingCopy: String {
                switch remaining {
                case 0:
                    return "Trend ready. Noum can start reading direction."
                case 1:
                    return "1 more measured rep before Noum calls this a trend."
                default:
                    return "\(remaining) more measured reps before Noum calls this a trend."
                }
            }

            var sampleLabel: String {
                "\(current) of \(total)"
            }

            var trendStateLabel: String {
                remaining == 0 ? "Ready" : "\(remaining) left"
            }

            var fraction: Double {
                guard total > 0 else { return 0 }
                return min(1, max(0, Double(current) / Double(total)))
            }
        }

        init(series: ChartSeries, points: [ChartPoint]) {
            let values = points.compactMap { series.value(from: $0) }
            self.average = values.reduce(0, +) / Double(max(1, values.count))
            self.rawSamples = Self.samples(from: values)
            self.trendSamples = Self.trendSamples(for: values)
            self.shouldShowTrendLine = values.count >= Self.minimumDirectionalEvidence
            self.latestFormatted = series.formatValue(values.last ?? 0)
            self.baselineProgress = Self.baselineProgress(forPointCount: values.count)

            let domain = Self.paddedDomain(for: values, series: series)
            self.yMin = domain.lowerBound
            self.yMax = domain.upperBound

            let xDomain = Self.ordinalDomain(forPointCount: values.count)
            self.xMin = xDomain.lowerBound
            self.xMax = xDomain.upperBound

            let delta = values.count >= Self.minimumDirectionalEvidence
                ? Self.recentBlockDelta(for: values)
                : (values.last ?? 0) - (values.first ?? 0)
            let recentAverage = values.count >= Self.minimumDirectionalEvidence
                ? Self.recentBlockAverage(for: values)
                : (values.last ?? 0)

            if values.count < Self.minimumDirectionalEvidence {
                self.readTitle = "Baseline forming"
                self.readIcon = "chart.xyaxis.line"
                self.readTint = AppColor.brandBlue
            } else if series == .pace {
                let read = Self.paceRead(delta: delta, recentAverage: recentAverage)
                self.readTitle = read.title
                self.readIcon = read.icon
                self.readTint = read.tint
            } else if series.isFlat(delta: delta) {
                self.readTitle = "Holding steady"
                self.readIcon = "arrow.right"
                self.readTint = .secondary
            } else if series.isImprovement(delta: delta, recentAverage: recentAverage) {
                self.readTitle = "Moving the right way"
                self.readIcon = "arrow.up.right"
                self.readTint = AppColor.positive
            } else {
                self.readTitle = "Worth a closer look"
                self.readIcon = "target"
                self.readTint = AppColor.brandBlue
            }
            self.readBody = if values.count < Self.minimumDirectionalEvidence {
                "First read, not a verdict. The next few reps will set your direction."
            } else if series == .pace {
                Self.paceRead(delta: delta, recentAverage: recentAverage).body
            } else {
                series.recentMovementCopy(delta: delta)
            }
        }

        static func samples(from values: [Double]) -> [TrendSample] {
            values.enumerated().map { offset, value in
                TrendSample(index: Double(offset), value: value)
            }
        }

        static func trendSamples(for values: [Double]) -> [TrendSample] {
            let raw = samples(from: values)
            guard values.count >= minimumDirectionalEvidence else {
                return raw
            }

            let smoothingRadius = 2
            return values.enumerated().map { offset, _ in
                let lower = max(values.startIndex, offset - smoothingRadius)
                let upper = min(values.index(before: values.endIndex), offset + smoothingRadius)
                let window = values[lower...upper]
                let average = window.reduce(0, +) / Double(window.count)
            return TrendSample(index: Double(offset), value: average)
            }
        }

        static func baselineProgress(forPointCount count: Int) -> BaselineProgress {
            let current = min(max(0, count), minimumDirectionalEvidence)
            return BaselineProgress(
                current: current,
                total: minimumDirectionalEvidence,
                remaining: max(0, minimumDirectionalEvidence - current)
            )
        }

        static func recentBlockDelta(for values: [Double]) -> Double {
            let recent = Array(values.suffix(7))
            let previous = Array(values.prefix(max(0, values.count - 7)).suffix(7))
            let recentAverage = recent.reduce(0, +) / Double(max(1, recent.count))
            let previousAverage = previous.isEmpty ? recentAverage : previous.reduce(0, +) / Double(previous.count)
            return recentAverage - previousAverage
        }

        static func recentBlockAverage(for values: [Double]) -> Double {
            let recent = Array(values.suffix(7))
            return recent.reduce(0, +) / Double(max(1, recent.count))
        }

        private struct PaceRead {
            let title: String
            let body: String
            let icon: String
            let tint: Color
        }

        private static func paceRead(delta: Double, recentAverage: Double) -> PaceRead {
            let band = ConversationalPaceBand.displayRange
            if ConversationalPaceBand.contains(recentAverage) {
                return PaceRead(
                    title: "In the target band",
                    body: "Recent pace is inside the \(band) WPM target band.",
                    icon: "checkmark.seal.fill",
                    tint: AppColor.positive
                )
            }

            if ChartSeries.pace.isFlat(delta: delta) {
                let recent = ChartSeries.pace.formatValue(recentAverage)
                if recentAverage < ConversationalPaceBand.minWPM {
                    return PaceRead(
                        title: "Still too slow",
                        body: "Recent pace is holding near \(recent), below the \(band) WPM target band.",
                        icon: "target",
                        tint: AppColor.caution
                    )
                }

                return PaceRead(
                    title: "Still too fast",
                    body: "Recent pace is holding near \(recent), above the \(band) WPM target band.",
                    icon: "target",
                    tint: AppColor.caution
                )
            }

            let formatted = ChartSeries.pace.formatDelta(delta)
            let cleanDelta = formatted
                .replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "-", with: "")
            let direction = delta >= 0 ? "up" : "down"
            let shifted = "Recent pace is \(direction) \(cleanDelta), but"

            if recentAverage < ConversationalPaceBand.minWPM {
                let movingCloser = delta >= 5
                return PaceRead(
                    title: movingCloser ? "Closer, still slow" : "Still too slow",
                    body: "\(shifted) still below the \(band) WPM target band.",
                    icon: movingCloser ? "arrow.up.right" : "target",
                    tint: movingCloser ? AppColor.positive : AppColor.caution
                )
            }

            let movingCloser = delta <= -5
            return PaceRead(
                title: movingCloser ? "Closer, still fast" : "Still too fast",
                body: "\(shifted) still above the \(band) WPM target band.",
                icon: movingCloser ? "arrow.down.right" : "target",
                tint: movingCloser ? AppColor.positive : AppColor.caution
            )
        }

        static func paddedDomain(for values: [Double], series: ChartSeries) -> ClosedRange<Double> {
            guard let rawMin = values.min(), let rawMax = values.max() else {
                return series.lowerVisualBound...(series.lowerVisualBound + series.minimumVisualSpan)
            }

            if let upperBound = series.upperVisualBound {
                return series.lowerVisualBound...upperBound
            }

            let rawSpan = max(rawMax - rawMin, series.minimumVisualSpan)
            let pad = rawSpan * 0.18
            var lower = rawMin - pad
            var upper = rawMax + pad

            if upper - lower < series.minimumVisualSpan {
                let center = (upper + lower) / 2
                lower = center - (series.minimumVisualSpan / 2)
                upper = center + (series.minimumVisualSpan / 2)
            }

            lower = max(series.lowerVisualBound, lower)
            if let upperBound = series.upperVisualBound {
                upper = min(upperBound, upper)
            }

            if upper - lower < series.minimumVisualSpan {
                if let upperBound = series.upperVisualBound, upper >= upperBound {
                    lower = max(series.lowerVisualBound, upper - series.minimumVisualSpan)
                } else if lower <= series.lowerVisualBound {
                    let unclampedUpper = lower + series.minimumVisualSpan
                    upper = min(series.upperVisualBound ?? unclampedUpper, unclampedUpper)
                } else {
                    let center = (upper + lower) / 2
                    lower = max(series.lowerVisualBound, center - (series.minimumVisualSpan / 2))
                    upper = center + (series.minimumVisualSpan / 2)
                    if let upperBound = series.upperVisualBound, upper > upperBound {
                        upper = upperBound
                        lower = max(series.lowerVisualBound, upper - series.minimumVisualSpan)
                    }
                }
            }

            if upper <= lower {
                upper = lower + series.minimumVisualSpan
            }

            return lower...upper
        }

        static func ordinalDomain(forPointCount count: Int) -> ClosedRange<Double> {
            let latestIndex = Double(max(1, count - 1))
            return -0.35...(latestIndex + 0.35)
        }
    }
}

#endif
