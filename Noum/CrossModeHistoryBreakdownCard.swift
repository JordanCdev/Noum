#if canImport(SwiftUI)
import SwiftUI

// MARK: - CrossModeHistoryBreakdownCard
//
// The "All" filter's counterpart to the per-mode track-record cards
// (Timed history, IM history, Pressure Drill history, Ah-Counter) —
// the pattern the owner singled out as worth keeping, missing from
// the one filter most users land on first. One compact row per mode
// the user has practiced: reps, average score, and the 7-day trend.
//
// Each row is tappable (when `onSelectMode` is provided) and sets
// that mode's filter chip — the card doubles as a navigator into the
// per-mode card with the richer mode-specific stats.
//
// Self-hides when there are no sessions at all (cold start). Modes
// with zero sessions produce no row; a mode with no scored reps shows
// "—" for its average rather than a fabricated number.
//
// Vision-aligned (docs/VISION.md pillar #4 — Believable progress):
// every number is computed from the session records the engine wrote
// at finalize time, via `CrossModeHistorySummary`. No narrative.

@available(iOS 17.0, *)
struct CrossModeHistoryBreakdownCard: View {

    let sessions: [PracticeSession]
    /// Tap handler for a mode row. When `nil`, rows render read-only
    /// (no chevron, no button affordance). When provided, each row
    /// becomes a button + chevron and invokes the handler on tap —
    /// the list view uses it to set that mode's filter chip.
    var onSelectMode: ((PracticeMode) -> Void)? = nil

    private var rows: [CrossModeHistoryModeRow] {
        CrossModeHistorySummary.rows(from: sessions)
    }

    private var totalReps: Int {
        CrossModeHistorySummary.totalRepCount(from: sessions)
    }

    private var isInteractive: Bool { onSelectMode != nil }

    private let accent = AppColor.brandBlue

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                header
                rowsSection
            }
            .padding(Spacing.lg)
            .background(cardBackground)
            .shadow(color: accent.opacity(0.14), radius: 14, x: 0, y: 6)
            .accessibilityIdentifier("history.allModes.breakdown")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
            Text("Across modes")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text(repCountLabel(totalReps))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func repCountLabel(_ count: Int) -> String {
        count == 1 ? "1 rep" : "\(count) reps"
    }

    // MARK: - Rows

    private var rowsSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                wrappedRow(row)
                if index < rows.count - 1 {
                    Divider()
                        .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func wrappedRow(_ row: CrossModeHistoryModeRow) -> some View {
        if let onSelectMode {
            Button {
                onSelectMode(row.mode)
            } label: {
                modeRow(row)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("history.allModes.row.\(row.mode.rawValue)")
        } else {
            modeRow(row)
        }
    }

    private func modeRow(_ row: CrossModeHistoryModeRow) -> some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: row.mode.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.tint(for: row.mode))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.mode.displayLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(repCountLabel(row.repCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            statColumn(
                value: row.averageScore.map { String(format: "%.1f", $0) } ?? "—",
                label: "avg score"
            )
            trendColumn(row.trend)
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
        .accessibilityHint(isInteractive ? "Filter the list to \(row.mode.displayLabel)." : "")
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
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
        .frame(minWidth: 56, alignment: .center)
    }

    // MARK: - Trend column
    //
    // Same direction language as the Timed card's trend chip (up /
    // down / steady against the 0.3-point band), compacted into a
    // stat column so four mode rows stay scannable. "—" when either
    // 7-day window lacks a scored rep — omitted, never invented.

    private func trendColumn(_ trend: TimedHistorySummaryStats.TrendComparison?) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                if let trend {
                    Image(systemName: trendIcon(trend))
                        .font(.caption2.weight(.bold))
                    Text(trendValue(trend))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.subheadline.weight(.bold))
                }
            }
            .foregroundStyle(trend.map(trendTint) ?? .secondary)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            Text("7-day")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .frame(minWidth: 56, alignment: .center)
    }

    private func trendValue(_ trend: TimedHistorySummaryStats.TrendComparison) -> String {
        switch trend.direction {
        case .steady: return "Steady"
        case .improving, .worsening: return String(format: "%.1f", abs(trend.deltaScore))
        }
    }

    private func trendIcon(_ trend: TimedHistorySummaryStats.TrendComparison) -> String {
        switch trend.direction {
        case .improving: return "arrow.up.right"
        case .worsening: return "arrow.down.right"
        case .steady:    return "equal"
        }
    }

    private func trendTint(_ trend: TimedHistorySummaryStats.TrendComparison) -> Color {
        switch trend.direction {
        case .improving: return AppColor.positive
        case .worsening: return AppColor.caution
        case .steady:    return .secondary
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for row: CrossModeHistoryModeRow) -> String {
        var parts = ["\(row.mode.displayLabel): \(repCountLabel(row.repCount))"]
        if let average = row.averageScore {
            parts.append("average score \(String(format: "%.1f", average))")
        }
        if let trend = row.trend {
            switch trend.direction {
            case .improving:
                parts.append("up \(String(format: "%.1f", abs(trend.deltaScore))) vs last week")
            case .worsening:
                parts.append("down \(String(format: "%.1f", abs(trend.deltaScore))) vs last week")
            case .steady:
                parts.append("steady vs last week")
            }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Background
    //
    // Same hero treatment as the per-mode cards (radial wash + tint
    // border), keyed to brand blue because no single mode owns the
    // All view — the per-mode tints live on the row icons.

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
