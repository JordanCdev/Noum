#if canImport(SwiftUI)
import SwiftUI

// MARK: - TimedHistoryBreakdownCard
//
// Per-mode track-record hero card for Timed reps. Reached from
// `SessionHistoryView` when the user filters to Timed. Mirrors the
// shape of `AhCounterHistoryBreakdownCard` so the History surface
// reads as one design language across modes:
//   • Mode-tinted hero treatment (Timed blue) so the card is
//     immediately legible as "this is the Timed surface."
//   • One header row with mode title + rep count + optional trend
//     chip ("Up 0.4 vs last week" / "Down 0.4 vs last week" /
//     "Steady vs last week").
//   • Three stat columns: average score, in-zone reps, average WPM.
//   • Best-rep cell at the bottom — tappable when
//     `onSelectBestRep` is provided to drill into the source session.
//
// Self-hides on cold start (the user has no Timed reps yet). Mirrors
// the SD + Ah-Counter pattern: rendering an empty card with "0 reps"
// would just be visual noise on the History screen.
//
// Vision-aligned (docs/VISION.md pillar #3 — Conversational
// intelligence + pillar #4 — Believable progress): honest evidence
// from the engine's own write path. No invented stats; no narrative;
// just the numbers the user produced.

@available(iOS 17.0, *)
struct TimedHistoryBreakdownCard: View {

    let sessions: [PracticeSession]
    /// Tap handler for the "best rep" cell. When `nil`, the cell
    /// renders read-only (no chevron, no button affordance). When
    /// provided, becomes a button + chevron that opens the source
    /// session — mirrors `AhCounterHistoryBreakdownCard.onSelectCleanestRep`.
    var onSelectBestRep: ((UUID) -> Void)? = nil

    private var stats: TimedHistorySummaryStats? {
        TimedHistorySummary.summarize(sessions: sessions)
    }

    private let accent = AppColor.modeTimed

    var body: some View {
        if let stats {
            VStack(alignment: .leading, spacing: 14) {
                header(for: stats)
                statRow(for: stats)
                if let best = stats.best {
                    Divider()
                    bestRepRow(best)
                }
            }
            .padding(Spacing.lg)
            .background(cardBackground)
            .shadow(color: accent.opacity(0.14), radius: 14, x: 0, y: 6)
            .accessibilityIdentifier("history.timed.breakdown")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(for stats: TimedHistorySummaryStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text("Timed history")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(repCountLabel(stats.runCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let trendChipCopy = trendChipCopy(for: stats) {
                HStack(spacing: 6) {
                    Image(systemName: trendChipIcon(for: stats))
                        .font(.caption2.weight(.bold))
                    Text(trendChipCopy)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(trendChipTint(for: stats))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(trendChipTint(for: stats).opacity(0.12), in: Capsule())
                .accessibilityLabel("Recent trend: \(trendChipCopy)")
            }
        }
    }

    private func repCountLabel(_ count: Int) -> String {
        count == 1 ? "1 rep" : "\(count) reps"
    }

    // MARK: - Trend chip

    private func trendChipCopy(for stats: TimedHistorySummaryStats) -> String? {
        guard let trend = stats.trend else { return nil }
        switch trend.direction {
        case .improving: return "Up \(formatDelta(abs(trend.deltaScore))) vs last week"
        case .worsening: return "Down \(formatDelta(abs(trend.deltaScore))) vs last week"
        case .steady:    return "Steady vs last week"
        }
    }

    private func trendChipIcon(for stats: TimedHistorySummaryStats) -> String {
        guard let trend = stats.trend else { return "minus" }
        switch trend.direction {
        case .improving: return "arrow.up.right"
        case .worsening: return "arrow.down.right"
        case .steady:    return "equal"
        }
    }

    private func trendChipTint(for stats: TimedHistorySummaryStats) -> Color {
        guard let trend = stats.trend else { return .secondary }
        switch trend.direction {
        case .improving: return AppColor.positive
        case .worsening: return AppColor.caution
        case .steady:    return .secondary
        }
    }

    // MARK: - Stat row

    @ViewBuilder
    private func statRow(for stats: TimedHistorySummaryStats) -> some View {
        HStack(alignment: .center, spacing: 14) {
            statColumn(
                value: stats.averageScore.map { formatDelta($0) } ?? "—",
                label: "avg score"
            )
            statColumn(
                value: "\(stats.inZoneRepCount)",
                label: "in zone"
            )
            statColumn(
                value: stats.averageWPM.map { "\($0)" } ?? "—",
                label: "avg WPM"
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statRowAccessibilityLabel(for: stats))
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func statRowAccessibilityLabel(for stats: TimedHistorySummaryStats) -> String {
        let avg = stats.averageScore.map { String(format: "%.1f", $0) } ?? "not yet available"
        let zoneCopy = stats.inZoneRepCount == 1 ? "1 rep in zone" : "\(stats.inZoneRepCount) reps in zone"
        let wpm = stats.averageWPM.map { "\($0)" } ?? "not yet available"
        return "Average score \(avg). \(zoneCopy). Average WPM \(wpm)."
    }

    // MARK: - Best rep row

    @ViewBuilder
    private func bestRepRow(_ best: TimedHistorySummaryStats.BestRep) -> some View {
        let row = HStack(alignment: .center, spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Best rep")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(bestSubtitle(best))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 8)
            if onSelectBestRep != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Best rep: \(bestSubtitle(best))")

        if let onSelectBestRep {
            Button {
                onSelectBestRep(best.sessionID)
            } label: {
                row
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("history.timed.bestRep")
            .accessibilityHint("Open the source session.")
        } else {
            row
                .accessibilityIdentifier("history.timed.bestRep")
        }
    }

    private func bestSubtitle(_ best: TimedHistorySummaryStats.BestRep) -> String {
        let wpmCopy = best.wordsPerMinute > 0 ? "\(best.wordsPerMinute) WPM" : "pace not measured"
        return "\(best.score)/10 · \(wpmCopy) · \(best.date.formatted(.relative(presentation: .named)))"
    }

    private func formatDelta(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    // MARK: - Background

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [accent.opacity(0.18), accent.opacity(0.05), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )
            shape.strokeBorder(accent.opacity(0.25), lineWidth: 1)
        }
    }
}

#endif
