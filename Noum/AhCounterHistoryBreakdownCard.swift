#if canImport(SwiftUI)
import SwiftUI

// MARK: - AhCounterHistoryBreakdownCard
//
// Per-mode track-record hero card for Ah-Counter. Reached from
// `SessionHistoryView` when the user filters to Ah-Counter. Mirrors
// the shape of `SuddenDeathHistoryBreakdownCard`:
//   • Mode-tinted hero treatment so the card reads as part of the
//     History surface, not a generic stats panel
//   • One header row with mode title + rep count + trend chip
//   • Three stat columns: avg fillers/minute, clean reps, cleanest rep
//   • Optional `onSelectCleanestRep` callback to jump to the source
//     session — same pattern as the SD breakdown's row-tap navigation
//
// Self-hides on cold start (the user has no Ah-Counter reps yet).
// Mirrors the SD pattern: rendering an empty card with "0 reps" would
// just be visual noise on the History screen for a user who hasn't
// touched the mode.
//
// Vision-aligned (docs/VISION.md pillar #1 — Filler-word reduction +
// pillar #4 — Believable progress): the mode is named for filler
// fighting, so the user's track record IS the filler-rate over time.
// Numbers come from session records the engine wrote at finalize;
// no narrative, no coach voice.

@available(iOS 17.0, *)
struct AhCounterHistoryBreakdownCard: View {

    let sessions: [PracticeSession]
    /// Tap handler for the "cleanest rep" cell. When `nil`, the cell
    /// renders read-only (no chevron, no button affordance). When
    /// provided, becomes a button + chevron that opens the source
    /// session — mirrors `SuddenDeathHistoryBreakdownCard.onSelectDifficulty`.
    var onSelectCleanestRep: ((UUID) -> Void)? = nil

    private var stats: AhCounterHistorySummaryStats? {
        AhCounterHistorySummary.summarize(sessions: sessions)
    }

    private let accent = AppColor.modeAhCounter

    var body: some View {
        if let stats {
            VStack(alignment: .leading, spacing: 14) {
                header(for: stats)
                statRow(for: stats)
                if let cleanest = stats.cleanest {
                    Divider()
                    cleanestRepRow(cleanest)
                }
            }
            .padding(Spacing.lg)
            .background(cardBackground)
            .shadow(color: accent.opacity(0.14), radius: 14, x: 0, y: 6)
            .accessibilityIdentifier("history.ahCounter.breakdown")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(for stats: AhCounterHistorySummaryStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                Text("Ah-Counter history")
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

    private func trendChipCopy(for stats: AhCounterHistorySummaryStats) -> String? {
        guard let trend = stats.trend else { return nil }
        switch trend.direction {
        case .improving: return "Down \(formatRate(abs(trend.deltaRate)))/min vs last week"
        case .worsening: return "Up \(formatRate(abs(trend.deltaRate)))/min vs last week"
        case .steady:    return "Steady vs last week"
        }
    }

    private func trendChipIcon(for stats: AhCounterHistorySummaryStats) -> String {
        guard let trend = stats.trend else { return "minus" }
        switch trend.direction {
        case .improving: return "arrow.down.right"
        case .worsening: return "arrow.up.right"
        case .steady:    return "equal"
        }
    }

    private func trendChipTint(for stats: AhCounterHistorySummaryStats) -> Color {
        guard let trend = stats.trend else { return .secondary }
        switch trend.direction {
        case .improving: return AppColor.positive
        case .worsening: return AppColor.caution
        case .steady:    return .secondary
        }
    }

    // MARK: - Stat row

    @ViewBuilder
    private func statRow(for stats: AhCounterHistorySummaryStats) -> some View {
        HStack(alignment: .center, spacing: 14) {
            statColumn(
                value: stats.averageFillersPerMinute.map { formatRate($0) } ?? "—",
                label: "avg/min"
            )
            statColumn(
                value: "\(stats.cleanRepCount)",
                label: "clean reps"
            )
            statColumn(
                value: stats.cleanest.map { formatRate($0.fillersPerMinute) } ?? "—",
                label: "best/min"
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

    private func statRowAccessibilityLabel(for stats: AhCounterHistorySummaryStats) -> String {
        let avg = stats.averageFillersPerMinute.map { String(format: "%.1f", $0) } ?? "not yet available"
        let cleanCopy = stats.cleanRepCount == 1 ? "1 clean rep" : "\(stats.cleanRepCount) clean reps"
        let best = stats.cleanest.map { String(format: "%.1f", $0.fillersPerMinute) } ?? "not yet available"
        return "Average \(avg) fillers per minute. \(cleanCopy). Best rep: \(best) fillers per minute."
    }

    // MARK: - Cleanest rep row

    @ViewBuilder
    private func cleanestRepRow(_ cleanest: AhCounterHistorySummaryStats.CleanestRep) -> some View {
        let row = HStack(alignment: .center, spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Cleanest rep")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    if stats?.cleanestIsThisWeek == true {
                        thisWeekChip
                    }
                }
                Text(cleanestSubtitle(cleanest))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 8)
            if onSelectCleanestRep != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cleanestRepAccessibilityLabel(cleanest))

        if let onSelectCleanestRep {
            Button {
                onSelectCleanestRep(cleanest.sessionID)
            } label: {
                row
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("history.ahCounter.cleanestRep")
            .accessibilityHint("Open the source session.")
        } else {
            row
                .accessibilityIdentifier("history.ahCounter.cleanestRep")
        }
    }

    private func cleanestSubtitle(_ cleanest: AhCounterHistorySummaryStats.CleanestRep) -> String {
        let fillerCopy: String
        switch cleanest.fillerCount {
        case 0: fillerCopy = "0 fillers"
        case 1: fillerCopy = "1 filler"
        default: fillerCopy = "\(cleanest.fillerCount) fillers"
        }
        return "\(fillerCopy) · \(formatDuration(cleanest.durationSeconds)) · \(cleanest.date.formatted(.relative(presentation: .named)))"
    }

    private func cleanestRepAccessibilityLabel(_ cleanest: AhCounterHistorySummaryStats.CleanestRep) -> String {
        if stats?.cleanestIsThisWeek == true {
            return "Cleanest rep this week: \(cleanestSubtitle(cleanest))"
        }
        return "Cleanest rep: \(cleanestSubtitle(cleanest))"
    }

    /// Small "THIS WEEK" capsule next to the "Cleanest rep" label
    /// when the cleanest rep was set inside the last 7 days. Same
    /// shape as the Timed card's chip so the History surface reads
    /// as one design language across modes.
    private var thisWeekChip: some View {
        Text("THIS WEEK")
            .font(.caption2.weight(.bold))
            .foregroundStyle(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(accent.opacity(0.12), in: Capsule())
            .accessibilityHidden(true)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let remaining = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    private func formatRate(_ rate: Double) -> String {
        if rate < 10 {
            return String(format: "%.1f", rate)
        }
        return "\(Int(rate.rounded()))"
    }

    // MARK: - Background
    //
    // Mirrors the SD breakdown card's mode-tinted hero treatment so the
    // History surface reads as one design language across modes.

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
