#if canImport(SwiftUI)
import SwiftUI
#if canImport(Charts)
import Charts
#endif

// MARK: - IMScenarioDetailView
//
// Per-scenario drill-down for IM Mode reps. Reached from the
// `IMHistoryBreakdownCard` row tap when the user has the IM filter
// selected on the History screen. Mirrors the shape of
// `SuddenDeathDifficultyRunsView` so the History surface keeps one
// design language across modes:
//   • Mode-tinted summary header — title, rep count, three at-a-glance
//     stat tiles (best score, avg trust, avg tension)
//   • Per-rep row list, newest-first, tap pushes the standard
//     `SessionHistoryDetailView` so the user can drill into full
//     transcript / coach read for any rep
//   • Trailing toolbar ShareLink with a `IMHistoryExport` plain-text
//     dump — same anti-goal contract as the SD export (zero
//     transcripts; only outcome numbers + scenario + target tone)
//
// Honest-data contract: every number here came from the engine at
// finalize. No invented narrative; no AI-generated read.
//
// Vision-aligned (docs/VISION.md pillar #3 — Conversational
// intelligence + pillar #4 — Believable progress + anti-goals): the
// surface lets the user browse their own track record at one
// scenario, the way a £130/hr human coach would pull up "your last
// ten Difficult Conversation reps."

@available(iOS 17.0, *)
struct IMScenarioDetailView: View {

    let scenario: IMConversationScenario
    @Binding var navigationPath: NavigationPath
    @StateObject private var sessionStore = PracticeSessionStore.shared

    /// Reps filtered to this scenario, newest-first. Defensive re-sort
    /// so the view doesn't depend on `PracticeSessionStore`'s invariant.
    private var reps: [PracticeSession] {
        sessionStore.sessions
            .filter { session in
                session.mode == .imConversation
                    && session.imConversationDetails?.setup.scenario == scenario
            }
            .sorted { $0.date > $1.date }
    }

    /// Pure summary read from the shared helper so the drill-down and
    /// the breakdown card never drift on the math.
    private var breakdown: IMScenarioBreakdown? {
        IMHistorySummary.breakdowns(from: sessionStore.sessions).first {
            $0.scenario == scenario
        }
    }

    /// Trust + tension trace, oldest-first. Reads the same data the
    /// summary stats compute over, just per-rep rather than averaged.
    private var tracePoints: [IMHistorySummary.IMScenarioTracePoint] {
        IMHistorySummary.tracePoints(from: sessionStore.sessions, scenario: scenario)
    }

    /// Per-scenario tone-match stats, including the last-five strip.
    private var toneMatchStats: IMHistorySummary.IMScenarioToneMatchStats {
        IMHistorySummary.toneMatchStats(from: sessionStore.sessions, scenario: scenario)
    }

    /// Trust + tension trend (earliest vs latest window). `nil` below 4
    /// reps with a recorded final state; the header chips self-hide
    /// when nil or when both metrics read flat.
    private var relationalTrend: IMHistorySummary.IMScenarioRelationalTrend? {
        IMHistorySummary.relationalTrend(from: sessionStore.sessions, scenario: scenario)
    }

    private var exportText: String {
        IMHistoryExport.formatPlainText(sessions: sessionStore.sessions, scenario: scenario)
    }

    private let accent = AppColor.modeIM

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            if reps.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        summaryHeader
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.top, 8)

                        if tracePoints.count >= 2 {
                            traceChartCard
                                .padding(.horizontal, Spacing.screenH)
                        }

                        if toneMatchStats.evaluatedCount > 0 {
                            toneMatchCard
                                .padding(.horizontal, Spacing.screenH)
                        }

                        repsList
                            .padding(.horizontal, Spacing.screenH)

                        Spacer(minLength: 32)
                    }
                }
            }
        }
        .navigationTitle("IM · \(scenario.title)")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.im.scenarioDetail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !reps.isEmpty {
                    ShareLink(item: exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share scenario history")
                    .accessibilityIdentifier("history.im.scenario.export")
                }
            }
        }
    }

    // MARK: - Empty state

    /// Empty state — when the user lands here from the breakdown card
    /// row tap but no rep has been recorded for this scenario yet
    /// (rare in practice; only reachable if the user reaches this
    /// route via deep-link or if every rep at this scenario has been
    /// deleted from the History list). The CTA pushes
    /// `imPractice(scenario:tone:)` with tone nil so the IM practice
    /// view's own tone picker resolves it from the user's last
    /// preference — same behaviour the Quick Start CTA uses.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No \(scenario.title) reps yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Finish an IM rep in this scenario to start a track record.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            Button {
                navigationPath.append(
                    AppDestination.imPractice(scenario: scenario, tone: nil)
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("Launch this scenario")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(accent, in: Capsule())
            }
            .accessibilityIdentifier("history.im.scenario.launchCTA")
            .accessibilityLabel("Launch \(scenario.title)")
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Trust / tension trace

    /// Two-line sparkline plotting `finalState.normalizedTrust` and
    /// `normalizedTension` across reps in this scenario, ordered by
    /// date. Pure visual layer; the underlying data is already on
    /// each `PracticeSession`. Renders only when at least 2 reps with
    /// a recorded final state exist — a single point isn't a trace.
    ///
    /// Reduce-motion contract: the chart has no animation. Honest
    /// data contract: every point is a real `finalState` from the
    /// engine; no interpolation across missing data.
    private var traceChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text("Trust vs tension")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(tracePoints.count) reps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            #if canImport(Charts)
            traceChart
                .frame(height: 120)
                .accessibilityHidden(true)
            #endif

            HStack(spacing: 14) {
                traceLegendDot(color: .teal, label: "trust")
                traceLegendDot(color: .orange, label: "tension")
                Spacer()
                Text("oldest → newest")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(Spacing.lg)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(traceChartAccessibilityLabel)
    }

    #if canImport(Charts)
    @ViewBuilder
    private var traceChart: some View {
        Chart {
            ForEach(tracePoints) { point in
                LineMark(
                    x: .value("Rep", point.date),
                    y: .value("Trust", point.trust),
                    series: .value("Series", "Trust")
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.teal)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Rep", point.date),
                    y: .value("Trust", point.trust)
                )
                .symbolSize(28)
                .foregroundStyle(Color.teal)
            }
            ForEach(tracePoints) { point in
                LineMark(
                    x: .value("Rep", point.date),
                    y: .value("Tension", point.tension),
                    series: .value("Series", "Tension")
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Rep", point.date),
                    y: .value("Tension", point.tension)
                )
                .symbolSize(28)
                .foregroundStyle(Color.orange)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.black.opacity(0.05))
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
            AxisMarks(position: .leading, values: [1, 5, 10]) { value in
                AxisGridLine().foregroundStyle(Color.black.opacity(0.05))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 1...10)
    }
    #endif

    private func traceLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var traceChartAccessibilityLabel: String {
        guard let first = tracePoints.first, let last = tracePoints.last else {
            return "Trust and tension trace, no data."
        }
        return "Trust and tension trace across \(tracePoints.count) reps. Trust moved from \(first.trust) to \(last.trust); tension moved from \(first.tension) to \(last.tension), on a 1-to-10 scale."
    }

    // MARK: - Tone-match strip

    /// Per-scenario tone-match strip — a small chip row for the last
    /// 5 reps that recorded an `actualTone` reading + a "matched X of
    /// Y" ratio. The matcher is case-insensitive substring containment
    /// of the target tone's title in the engine's `actualTone`
    /// readout (e.g., target "Confident" matches an `actualTone` of
    /// "warmly confident"). Honest data: a rep with `actualTone ==
    /// nil` is excluded from the denominator — missing data isn't a
    /// miss. Self-hides when `evaluatedCount == 0`.
    private var toneMatchCard: some View {
        let stats = toneMatchStats
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text("Tone match")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(toneMatchRatioLabel(stats: stats))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !stats.lastFive.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last 5 reps")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    HStack(spacing: 6) {
                        ForEach(stats.lastFive) { entry in
                            toneMatchChip(matched: entry.matched)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(toneMatchAccessibilityLabel(stats: stats))
    }

    private func toneMatchChip(matched: Bool) -> some View {
        Image(systemName: matched ? "checkmark" : "xmark")
            .font(.caption2.weight(.bold))
            .foregroundStyle(matched ? AppColor.positive : AppColor.caution)
            .frame(width: 22, height: 22)
            .background(
                Circle().fill(
                    (matched ? AppColor.positive : AppColor.caution).opacity(0.14)
                )
            )
    }

    private func toneMatchRatioLabel(stats: IMHistorySummary.IMScenarioToneMatchStats) -> String {
        guard stats.evaluatedCount > 0 else { return "" }
        return "\(stats.matchCount) of \(stats.evaluatedCount) matched"
    }

    private func toneMatchAccessibilityLabel(stats: IMHistorySummary.IMScenarioToneMatchStats) -> String {
        guard stats.evaluatedCount > 0 else {
            return "Tone match, no evaluated reps yet."
        }
        let rate = stats.matchRate.map { Int(($0 * 100).rounded()) } ?? 0
        return "Tone match: \(stats.matchCount) of \(stats.evaluatedCount) reps matched the target tone, \(rate) percent."
    }

    // MARK: - Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text(scenario.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(reps.count) rep\(reps.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(scenario.summary)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
            HStack(spacing: 18) {
                summaryStat(value: bestScoreLabel, label: "Best")
                summaryStat(value: averageTrustLabel, label: "Avg trust")
                summaryStat(value: averageTensionLabel, label: "Avg tension")
            }
            if let trend = relationalTrend, trend.hasSignal {
                HStack(spacing: 8) {
                    trendChip(label: "Trust", movement: trend.trust, goodWhenUp: true)
                    trendChip(label: "Tension", movement: trend.tension, goodWhenUp: false)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(relationalTrendAccessibilityLabel(trend))
                .accessibilityIdentifier("history.im.scenario.trendChips")
            }
        }
        .padding(Spacing.lg)
        .background(cardBackground)
        .shadow(color: accent.opacity(0.12), radius: 12, x: 0, y: 5)
    }

    /// One trend chip. Self-hides on a flat metric. Color reads the
    /// *value judgment*: trust rising is good, tension falling is good,
    /// so `goodWhenUp` flips the green/amber assignment per metric.
    /// The arrow always shows the raw numeric direction so the chip is
    /// honest about which way the line actually moved.
    @ViewBuilder
    private func trendChip(
        label: String,
        movement: IMHistorySummary.IMScenarioRelationalTrend.Movement,
        goodWhenUp: Bool
    ) -> some View {
        if movement != .flat {
            let isUp = movement == .up
            let isGood = (isUp == goodWhenUp)
            let tint = isGood ? AppColor.positive : AppColor.caution
            HStack(spacing: 4) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
        }
    }

    private func relationalTrendAccessibilityLabel(
        _ trend: IMHistorySummary.IMScenarioRelationalTrend
    ) -> String {
        var parts: [String] = []
        switch trend.trust {
        case .up: parts.append("trust trending up")
        case .down: parts.append("trust trending down")
        case .flat: break
        }
        switch trend.tension {
        case .up: parts.append("tension trending up")
        case .down: parts.append("tension trending down")
        case .flat: break
        }
        guard !parts.isEmpty else { return "" }
        return "Recent trend: " + parts.joined(separator: ", ")
            + ", based on your earliest and latest \(trend.windowSize) reps."
    }

    private var bestScoreLabel: String {
        guard let best = breakdown?.bestScore else { return "—" }
        return "\(best)/10"
    }

    private var averageTrustLabel: String {
        guard let value = breakdown?.averageFinalTrust else { return "—" }
        return formatScalar(value)
    }

    private var averageTensionLabel: String {
        guard let value = breakdown?.averageFinalTension else { return "—" }
        return formatScalar(value)
    }

    private func formatScalar(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
    }

    // MARK: - Run list

    private var repsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(reps.enumerated()), id: \.element.id) { index, session in
                Button {
                    navigationPath.append(AppDestination.sessionDetail(sessionID: session.id))
                } label: {
                    repRow(session: session)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("history.im.scenario.row.\(session.id.uuidString)")

                if index < reps.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func repRow(session: PracticeSession) -> some View {
        HStack(spacing: 12) {
            let isTopScore = session.score != nil && session.score == breakdown?.bestScore
            Image(systemName: isTopScore ? "trophy.fill" : "bubble.left.and.bubble.right")
                .font(.subheadline)
                .foregroundStyle(isTopScore ? .yellow : accent.opacity(0.85))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.score.map { "\($0)/10" } ?? "—")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    if let tone = session.imConversationDetails?.setup.targetTone {
                        Text(tone.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(accent.opacity(0.12), in: Capsule())
                    }
                }
                Text(absoluteDateLabel(session.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 14) {
                relationalChip(
                    value: session.imConversationDetails?.finalState.map { "\($0.normalizedTrust)" } ?? "—",
                    label: "trust",
                    tint: .teal
                )
                relationalChip(
                    value: session.imConversationDetails?.finalState.map { "\($0.normalizedTension)" } ?? "—",
                    label: "tension",
                    tint: .orange
                )
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: session))
    }

    private func relationalChip(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func absoluteDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func accessibilityLabel(for session: PracticeSession) -> String {
        let score = session.score.map { "score \($0) of 10" } ?? "no score recorded"
        let trust = session.imConversationDetails?.finalState.map { "trust \($0.normalizedTrust)" } ?? "no trust reading"
        let tension = session.imConversationDetails?.finalState.map { "tension \($0.normalizedTension)" } ?? "no tension reading"
        return "\(scenario.title) rep, \(score), \(trust), \(tension)"
    }

    // MARK: - Background

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [accent.opacity(0.16), accent.opacity(0.04), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 280
                )
            )
            shape.strokeBorder(accent.opacity(0.22), lineWidth: 1)
        }
    }
}

#endif
