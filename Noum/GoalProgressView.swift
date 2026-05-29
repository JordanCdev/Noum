import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

// MARK: - Goal Progress View (M14)
//
// Visualises the user's distance-from-goal as a real progress ring on the
// profile's Coaching Direction card. Closes the M14 goal-aware coaching
// thread: the same metric that anchors the pre-rep VoiceAnchorBanner, biases
// the mid-rep LiveEloquenceHUD, and frames the post-rep Coach Note momentum
// is now visible as a single proximity reading the user can watch move.
//
// Honesty rules:
//   • Hides the percentage entirely when baseline confidence is insufficient
//     for this goal's underlying dimension — shows "Learning your baseline"
//     instead of a fake 50%.
//   • The trend chip ("Closer this week" / "Slipped" / "Holding steady") only
//     fires when at least 3 recent + 3 prior qualifying SkillSnapshots exist.
//     For `.calmerDelivery` "qualifying" additionally means the snapshot
//     carried a non-nil `pauseFilledRatio` (zero-pause reps don't contribute
//     a calmness reading) — so until the user accumulates pause history the
//     chip stays hidden rather than fake a delta.

@available(iOS 17.0, *)
struct GoalProgressView: View {
    let goal: CoachingPriority
    let baseline: CommunicationBaseline
    let snapshots: [SkillSnapshot]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ringSize: CGFloat = 64
    private let ringStroke: CGFloat = 6

    /// Live measured distance (0.0 = at goal, 1.0 = far). nil when confidence
    /// is insufficient — the ring then renders an "Early signal" empty state
    /// rather than a fake reading.
    private var measuredDistance: Double? {
        baseline.measuredDistanceFromGoal(goal)
    }

    private var proximity: Double {
        guard let d = measuredDistance else { return 0 }
        return max(0, min(1.0, 1.0 - d))
    }

    private var label: String {
        guard measuredDistance != nil else { return "Early signal" }
        return baseline.goalDistanceLabel(goal)
    }

    private var trend: GoalProgressTrend? {
        GoalProgressTrend.compute(goal: goal, snapshots: snapshots)
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            ring
                .frame(width: ringSize, height: ringSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let trend, measuredDistance != nil {
                    trendChip(trend)
                } else if measuredDistance == nil {
                    Text("A few more reps to read your baseline.")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.14), lineWidth: ringStroke)

            Circle()
                .trim(from: 0, to: proximity)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .standardSpring, value: proximity)

            if measuredDistance == nil {
                Image(systemName: "ellipsis")
                    .font(Typography.cardLabel)
                    .foregroundStyle(.tertiary)
            } else {
                Text("\(Int((proximity * 100).rounded()))%")
                    .font(Typography.figtreeNumeric(size: 18, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .standardSpring, value: proximity)
            }
        }
    }

    private func trendChip(_ trend: GoalProgressTrend) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.system(size: 10, weight: .bold))
            Text(trend.label)
                .font(Typography.captionSmall)
        }
        .foregroundStyle(trend.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(trend.tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Helpers

    private var accent: Color {
        guard measuredDistance != nil else { return .secondary }
        if proximity >= 0.75 { return AppColor.positive }
        if proximity >= 0.50 { return AppColor.brandBlue }
        if proximity >= 0.25 { return AppColor.caution }
        return .secondary
    }

    private var ringGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accessibilityLabel: String {
        guard let d = measuredDistance else {
            return "Goal progress — early signal. A few more reps to read your baseline."
        }
        let pct = Int(((1.0 - d) * 100).rounded())
        var phrase = "Goal progress \(pct) percent. \(label)."
        if let trend {
            phrase += " \(trend.label)."
        }
        return phrase
    }
}

// MARK: - Trend Model

/// Week-over-week goal trend computed from `SkillSnapshot` history.
///
/// Compares the most recent 5 qualifying snapshots against the 5 before that.
/// A negative delta (closer to goal) becomes `.closer`; positive becomes
/// `.slipped`; abs-delta under the noise threshold becomes `.steady`.
struct GoalProgressTrend: Equatable {
    enum Direction: Equatable {
        case closer
        case steady
        case slipped
    }

    let direction: Direction
    /// Signed distance delta (recent - prior). Negative = closer to goal.
    let delta: Double

    /// Snapshot count per window. Equal in both windows when there's enough
    /// data. Used by callers that want to phrase the chip honestly ("over
    /// your last 5 reps") but not surfaced today.
    let windowSize: Int

    /// Noise floor for the steady band. Below this magnitude the change is
    /// indistinguishable from session-to-session noise — celebrate movement
    /// only when it's real.
    static let steadyThreshold: Double = 0.05

    /// Minimum qualifying snapshots in each window before a trend fires.
    static let minimumSamples: Int = 3

    /// Target window size (preferred). The compute helper falls back to
    /// whatever's available down to `minimumSamples`.
    static let preferredWindow: Int = 5

    var label: String {
        switch direction {
        case .closer:  return "Closer this week"
        case .steady:  return "Holding steady"
        case .slipped: return "Slipped this week"
        }
    }

    var icon: String {
        switch direction {
        case .closer:  return "arrow.up.right"
        case .steady:  return "equal"
        case .slipped: return "arrow.down.right"
        }
    }

    #if canImport(SwiftUI)
    var tint: Color {
        switch direction {
        case .closer:  return AppColor.positive
        case .steady:  return .secondary
        case .slipped: return AppColor.caution
        }
    }
    #endif

    static func compute(goal: CoachingPriority, snapshots: [SkillSnapshot]) -> GoalProgressTrend? {
        let ordered = snapshots.sorted { $0.date > $1.date }
        let recent = Array(ordered.prefix(preferredWindow))
        let prior = Array(ordered.dropFirst(preferredWindow).prefix(preferredWindow))

        guard recent.count >= minimumSamples, prior.count >= minimumSamples else {
            return nil
        }
        guard let recentD = CommunicationBaseline.distanceFromGoal(goal, in: recent, minimumSamples: minimumSamples),
              let priorD = CommunicationBaseline.distanceFromGoal(goal, in: prior, minimumSamples: minimumSamples) else {
            return nil
        }
        let delta = recentD - priorD
        let direction: Direction
        if abs(delta) < steadyThreshold {
            direction = .steady
        } else if delta < 0 {
            direction = .closer
        } else {
            direction = .slipped
        }
        return GoalProgressTrend(
            direction: direction,
            delta: delta,
            windowSize: min(recent.count, prior.count)
        )
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
#Preview("Goal Progress — on track") {
    let baseline = CommunicationBaseline(
        lastUpdated: Date(), sessionCount: 12, qualifyingSessionCount: 12,
        fillerRate: BaselineStat(value: 1.0, sampleCount: 12, confidence: .established, trend: .improving, percentile25: 0.5, percentile75: 1.5),
        pace: .empty, paceVariance: .empty, durationTendency: .empty,
        pauseRate: .empty, pauseFilledRatio: .empty,
        openingStrength: .empty, closingStrength: .empty,
        structureQuality: .empty, answerDepth: .empty, clarity: .empty,
        vocabularyRange: .empty, hedgingRate: .empty,
        averageScore: .empty, clutchWordFrequencies: [:],
        topStrengths: [], persistentBlockers: []
    )
    let snapshots: [SkillSnapshot] = (0..<10).map { i in
        SkillSnapshot(
            sessionId: UUID(),
            date: Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(),
            fillerCount: i < 5 ? 1 : 3, duration: 60, wordCount: 120, wpm: 130, score: 7
        )
    }
    return GoalProgressView(goal: .reduceFillers, baseline: baseline, snapshots: snapshots)
        .padding()
        .background(AppColor.cardBackground)
}

@available(iOS 17.0, *)
#Preview("Goal Progress — early signal") {
    GoalProgressView(goal: .reduceFillers, baseline: .empty, snapshots: [])
        .padding()
        .background(AppColor.cardBackground)
}
#endif

#endif
