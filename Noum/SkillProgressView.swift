import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

/// Expandable skill trend visualization for the summary screen.
/// Shows trend lines per skill area with direction indicators.
struct SkillProgressView: View {
    let trends: [SkillTrend]
    let drillHistory: [DrillHistoryStore.Entry]
    /// Chronologically ordered snapshots (most recent first) used to draw
    /// per-skill sparklines. Optional so existing callers keep working.
    var snapshots: [SkillSnapshot] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            Text("Skill Progress")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .accessibilityAddTraits(.isHeader)

            if trends.isEmpty {
                Text("Complete a few more sessions to see your skill trends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Show trends sorted by priority: weakest first
                let sorted = trends.sorted { levelOrder($0.currentLevel) < levelOrder($1.currentLevel) }

                ForEach(sorted, id: \.id) { trend in
                    skillRow(trend)
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Skill Row

    private func skillRow(_ trend: SkillTrend) -> some View {
        let series = sparklineSeries(for: trend.skillArea)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Skill icon
                Image(systemName: trend.skillArea.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(trend.skillArea.tint)
                    .frame(width: 28, height: 28)
                    .background(trend.skillArea.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Name and direction
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(trend.skillArea.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        directionBadge(trend.direction)
                    }

                    // Level bar
                    HStack(spacing: 4) {
                        levelBar(trend.currentLevel, tint: trend.skillArea.tint)

                        Text(trend.currentLevel.rawValue.capitalized)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Sparkline — visual trend across recent sessions
                if series.count >= 3 {
                    Sparkline(values: series, tint: trend.skillArea.tint)
                        .frame(width: 64, height: 22)
                        .accessibilityLabel(sparklineA11y(for: trend, values: series))
                }

                // Streak indicator
                let streak = drillStreak(for: trend.skillArea)
                if streak >= 2 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("\(streak)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    .accessibilityLabel("\(streak) drill streak")
                }
            }

            // Trend context line — human-readable trajectory summary
            Text(TrendFramingCopy.trendContext(
                direction: trend.direction,
                confidence: trend.confidence,
                sessionsInWindow: trend.windowSize
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 40) // align with text, past the icon
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Components

    private func directionBadge(_ direction: TrendDirection) -> some View {
        Group {
            switch direction {
            case .improving:
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                    Text("Improving")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(AppColor.positive)
            case .declining:
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text("Slipping")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(AppColor.caution)
            case .newIssue:
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("New")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(AppColor.warning)
            case .resolved:
                HStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("Resolved")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(AppColor.positive)
            case .stable:
                EmptyView()
            }
        }
    }

    private func levelBar(_ level: SkillLevel, tint: Color) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < levelFillCount(level) ? tint : tint.opacity(0.12))
                    .frame(width: 16, height: 4)
            }
        }
    }

    // MARK: - Helpers

    private func levelFillCount(_ level: SkillLevel) -> Int {
        switch level {
        case .weak: return 1
        case .developing: return 2
        case .solid: return 3
        case .strong: return 4
        }
    }

    private func levelOrder(_ level: SkillLevel) -> Int {
        switch level {
        case .weak: return 0
        case .developing: return 1
        case .solid: return 2
        case .strong: return 3
        }
    }

    private func drillStreak(for skillArea: SkillArea) -> Int {
        var count = 0
        for entry in drillHistory where entry.skillArea == skillArea {
            if entry.succeeded { count += 1 } else { break }
        }
        return count
    }

    // MARK: - Sparkline data

    /// Build a chronological 0–1 series for the skill area from recent snapshots.
    /// Values: 0 = weak signal, 1 = strong signal. Up to 8 points, oldest → newest.
    /// Returns an empty array when there isn't enough signal to draw an honest line.
    private func sparklineSeries(for skillArea: SkillArea) -> [Double] {
        guard !snapshots.isEmpty else { return [] }
        // Snapshots store newest-first; reverse for left-to-right time order.
        let chronological = Array(snapshots.prefix(8).reversed())

        let raw: [Double?] = chronological.map { snapshot in
            metricValue(for: skillArea, snapshot: snapshot)
        }
        let resolved = raw.compactMap { $0 }
        guard resolved.count >= 3 else { return [] }
        return resolved
    }

    /// Map a snapshot to a 0–1 strength signal for a skill area.
    /// Returns nil when the snapshot has no useful data for that skill.
    private func metricValue(for skillArea: SkillArea, snapshot: SkillSnapshot) -> Double? {
        switch skillArea {
        case .fillerReduction:
            // 0 fillers → 1.0; 10+ fillers → 0.0
            return 1.0 - clamp(Double(snapshot.fillerCount) / 10.0, 0, 1)
        case .paceControl:
            // 130 WPM ideal; 60 WPM off → 0
            guard snapshot.wpm > 0 else { return nil }
            let distance = abs(snapshot.wpm - 130)
            return 1.0 - clamp(distance / 80.0, 0, 1)
        case .pauseUsage:
            guard let rate = snapshot.pauseRate else { return nil }
            // Bands match TrendAnalyzer.analyzePause: ≥4.0/min is strong.
            return clamp(rate / 4.0, 0, 1)
        case .vocalEmphasis:
            guard let monotone = snapshot.pitchMonotone else { return nil }
            return 1.0 - clamp(monotone, 0, 1)
        case .openingStrength:
            return categoryValue(snapshot, dimension: "Opening")
        case .closingStrength:
            return categoryValue(snapshot, dimension: "Close")
        case .structure:
            return categoryValue(snapshot, dimension: "Structure")
        case .answerDevelopment:
            return categoryValue(snapshot, dimension: "Depth")
        case .conciseSpeaking:
            return categoryValue(snapshot, dimension: "Clarity")
                ?? durationValue(snapshot)
        case .confidence:
            // Use overall session score as a proxy when no category rating exists.
            return clamp(Double(snapshot.score) / 10.0, 0, 1)
        }
    }

    private func categoryValue(_ snapshot: SkillSnapshot, dimension: String) -> Double? {
        guard let rating = snapshot.categoryRatings[dimension] else { return nil }
        switch rating {
        case "Good": return 1.0
        case "OK": return 0.6
        case "Could improve": return 0.2
        default: return 0.5
        }
    }

    private func durationValue(_ snapshot: SkillSnapshot) -> Double? {
        guard snapshot.duration > 0 else { return nil }
        // Conciseness peaks around 30–90s. Penalize very short or very long answers.
        let d = snapshot.duration
        if d < 10 { return 0.2 }
        if d <= 90 { return 1.0 - abs(d - 50) / 80.0 }
        return max(0.2, 1.0 - (d - 90) / 120.0)
    }

    private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, x))
    }

    private func sparklineA11y(for trend: SkillTrend, values: [Double]) -> String {
        let directionWord: String
        switch trend.direction {
        case .improving: directionWord = "trending up"
        case .declining: directionWord = "trending down"
        case .stable: directionWord = "holding steady"
        case .newIssue: directionWord = "new dip"
        case .resolved: directionWord = "recovered"
        }
        return "\(trend.skillArea.displayName) \(directionWord) across \(values.count) recent sessions"
    }
}

// MARK: - Sparkline

/// Minimal line + fill sparkline. Designed for tiny inline use (~64×22).
/// Reads light: low ink, light tint fill, single stroke, endpoint dot.
private struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let points = mappedPoints(in: CGSize(width: w, height: h))
            ZStack {
                // Soft fill under the line for context.
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: h))
                    path.addLine(to: first)
                    for p in points.dropFirst() { path.addLine(to: p) }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: h))
                    }
                    path.closeSubpath()
                }
                .fill(tint.opacity(0.12))

                // Main stroked line.
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for p in points.dropFirst() { path.addLine(to: p) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

                // Endpoint dot anchors the latest reading.
                if let last = points.last {
                    Circle()
                        .fill(tint)
                        .frame(width: 4, height: 4)
                        .position(last)
                }
            }
        }
        .accessibilityHidden(false)
    }

    private func mappedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, size.width > 0, size.height > 0 else { return [] }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let range = max(0.0001, hi - lo)
        let dx = size.width / CGFloat(values.count - 1)
        // Leave a small inset top/bottom so the line never kisses the edge.
        let inset: CGFloat = 2
        let yTop = inset
        let yBottom = size.height - inset
        return values.enumerated().map { idx, v in
            let x = CGFloat(idx) * dx
            let normalized = CGFloat((v - lo) / range)
            let y = yBottom - normalized * (yBottom - yTop)
            return CGPoint(x: x, y: y)
        }
    }
}

#endif
