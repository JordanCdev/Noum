// VoiceMetricsCard.swift
// Noum
//
// Promotes Pause + Word-choice from "post-session summary surface" to a
// first-class Home read. VISION.md called these the next-most-differentiating
// signals after fillers and pace; this card is what makes that real for the
// user — visible at-rest on Home, in coach voice, with concrete numbers and a
// trend-aware read.
//
// Source data:
//   • Pause row:   `BaselineStore.shared.baseline.pauseRate` +
//                  `.pauseFilledRatio` (already top-level baseline dims),
//                  aggregated over recent-week sessions for the concrete
//                  numbers in the body.
//   • Word row:    `baseline.vocabularyRange` (unique-content ratio, already
//                  top-level) compared this-week vs last-week from the
//                  session store for the trend phrasing.
//
// Honesty rules:
//   • A row collapses entirely when its baseline dimension is `.insufficient`.
//     No "Awaiting data" placeholder — that's the kind of dead toggle CLAUDE.md
//     bans. Silence is better than fake.
//   • The whole card collapses when BOTH rows are silent.
//   • Trend phrasing fires only when there are ≥ 2 qualifying sessions in
//     each window (this week / prior week). Otherwise the row carries the
//     read alone, no trend clause.
//   • Regression rows are never punish-shame. A drop reads as a coach
//     redirect, not a scolding ("Re-anchor on the next rep.").
//
// Visual register:
//   • Brand-blue subtle radial wash matching `speakingRatingHeroBackground`
//     on Profile, so the home "metric register" carries the same family
//     identity as the rating hero. Two rows, no chrome between them — the
//     card is one frame, not a dashboard.
//   • Tap → Profile, where the full pause / word-variety trend chart lives.

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct VoiceMetricsCard: View {

    @Binding var navigationPath: NavigationPath

    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The card itself collapses when neither row has anything honest to
        // say. This is the engineering-ban guard: a "voice metrics" card
        // shown with both rows hidden would read as a dead surface.
        let read = VoiceMetricsRead.compute(
            baseline: baselineStore.baseline,
            sessions: sessionStore.sessions
        )
        if read.isEmpty {
            EmptyView()
        } else {
            cardBody(read)
        }
    }

    @ViewBuilder
    private func cardBody(_ read: VoiceMetricsRead) -> some View {
        Button {
            navigationPath.append(AppDestination.socialProfile)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                if let pause = read.pause {
                    metricRow(
                        label: "Pause control",
                        copy: pause.copy,
                        symbol: "pause.circle.fill",
                        tint: AppColor.brandBlue
                    )
                }
                if let word = read.wordChoice {
                    if read.pause != nil {
                        rowDivider
                    }
                    metricRow(
                        label: "Word variety",
                        copy: word.copy,
                        symbol: "text.word.spacing",
                        tint: AppColor.brandBlue
                    )
                }
                seeFullReadLink
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(brandBlueHeroBackground)
            .shadow(color: AppColor.brandBlue.opacity(0.16), radius: 22, x: 0, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.voiceMetricsCard")
        .accessibilityLabel(accessibilityLabel(read))
        .accessibilityHint("Opens your profile with the full voice-metrics trend.")
    }

    // MARK: - Header / rows

    private var header: some View {
        HStack(spacing: 6) {
            Text("THIS WEEK")
                .font(Typography.micro)
                .foregroundStyle(AppColor.brandBlue)
                .textCase(.uppercase)
                .tracking(0.8)

            Text("\u{00B7}")
                .font(Typography.micro)
                .foregroundStyle(.secondary)

            Text("VOICE METRICS")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Spacer(minLength: 0)
        }
    }

    private func metricRow(
        label: String,
        copy: String,
        symbol: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)
                Text(copy)
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AppColor.brandBlue.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 36 + Spacing.sm)
    }

    private var seeFullReadLink: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            Text("See full read")
                .font(Typography.caption)
                .foregroundStyle(AppColor.brandBlue)
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
        }
    }

    // MARK: - Background

    /// Brand-blue subtle hero treatment — mirrors `speakingRatingHeroBackground`
    /// on Profile so the two surfaces read as one visual family. Same radial
    /// shape, same color register, same hairline border treatment.
    private var brandBlueHeroBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [
                        AppColor.brandBlue.opacity(0.28),
                        AppColor.brandBlueLight.opacity(0.14),
                        AppColor.brandBlue.opacity(0.03),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 280
                )
            )
            shape.strokeBorder(AppColor.brandBlue.opacity(0.30), lineWidth: 1)
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(_ read: VoiceMetricsRead) -> String {
        var parts: [String] = ["This week's voice metrics."]
        if let pause = read.pause {
            parts.append("Pause control: \(pause.copy)")
        }
        if let word = read.wordChoice {
            parts.append("Word variety: \(word.copy)")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Read computation (testable)
//
// All read logic lives here so unit tests can assert the copy contract
// without instantiating SwiftUI. The two row reads share a structure:
// optional copy + optional trend phrasing. The whole struct is `isEmpty`
// when both rows are silent — that's the signal to collapse the card.

struct VoiceMetricsRead: Equatable {
    let pause: Row?
    let wordChoice: Row?

    struct Row: Equatable {
        let copy: String
    }

    var isEmpty: Bool { pause == nil && wordChoice == nil }

    /// Build a read from the live baseline + the user's session history.
    /// Either row collapses when its underlying baseline dimension hasn't
    /// reached `.moderate` confidence (≥ 5 qualifying sessions).
    static func compute(
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        now: Date = Date()
    ) -> VoiceMetricsRead {
        let pause = pauseRow(baseline: baseline, sessions: sessions, now: now)
        let word = wordChoiceRow(baseline: baseline, sessions: sessions, now: now)
        return VoiceMetricsRead(pause: pause, wordChoice: word)
    }

    // MARK: Pause row

    private static func pauseRow(
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        now: Date
    ) -> Row? {
        // The baseline dimension has to be reliable. Anything less and we
        // don't have enough signal to claim a number.
        guard baseline.pauseRate.confidence.isReliable else { return nil }

        // Walk the last seven days of sessions to find clean (silent) pauses
        // and a representative mean. We aggregate from the actual rep-level
        // PauseMetrics rather than the EMA so the body line carries concrete
        // numbers the user can recognise from their reps.
        let weekWindow = sessionsInWindow(sessions, daysBack: 0, daysSpan: 7, now: now)
        let pauseMetrics = weekWindow.compactMap { $0.pauseMetrics }.filter { $0.count > 0 }

        let cleanCount: Int
        let meanSeconds: Double
        if !pauseMetrics.isEmpty {
            let totalCount = pauseMetrics.reduce(0) { $0 + $1.count }
            let totalFilledCount = pauseMetrics.reduce(0.0) { $0 + (Double($1.count) * $1.filledRatio) }
            cleanCount = max(0, totalCount - Int(totalFilledCount.rounded()))
            let weighted = pauseMetrics.reduce(0.0) { $0 + ($1.meanSeconds * Double($1.count)) }
            meanSeconds = totalCount > 0 ? weighted / Double(totalCount) : 0
        } else {
            // No this-week pauses captured (e.g. the user's last reps were
            // very short or didn't emit timings). Fall back to the baseline
            // EMA so the row still carries a read — but flag the silent
            // numbers below.
            cleanCount = 0
            meanSeconds = 0
        }

        // Trend phrasing — compare the filled-pause ratio (the proxy for
        // "clean") against the baseline's interquartile band. A ratio below
        // p25 = "above your baseline" (better than usual); above p75 =
        // "below your baseline" (worse than usual). Mid-band = no clause.
        //
        // We use filled-ratio direction (lower = better) so the user-facing
        // word "above your baseline" reads naturally as "cleaner than usual".
        let trend = pauseTrend(filledRatioStat: baseline.pauseFilledRatio)

        let copy: String
        if cleanCount > 0 && meanSeconds > 0 {
            let meanStr = formatSeconds(meanSeconds)
            let pauseWord = cleanCount == 1 ? "clean pause" : "clean pauses"
            switch trend {
            case .above:
                copy = "\(cleanCount) \(pauseWord), \(meanStr) mean. Above your baseline."
            case .below:
                if cleanCount == 1 {
                    copy = "\(cleanCount) \(pauseWord) this week, down from your usual. Re-anchor on the next rep."
                } else {
                    copy = "\(cleanCount) \(pauseWord), \(meanStr) mean. Below your baseline."
                }
            case .steady:
                copy = "\(cleanCount) \(pauseWord), \(meanStr) mean."
            }
        } else {
            // Reliable baseline but no clean-pause material in this week's
            // reps. Tell the user where they sit on the baseline; never
            // shame.
            switch trend {
            case .above:
                copy = "Your overall pause pattern is cleaner than your usual range."
            case .below:
                copy = "Pauses ran filled this week. Re-anchor on the next rep."
            case .steady:
                let ratePerMin = baseline.pauseRate.value
                copy = "Around \(String(format: "%.1f", ratePerMin)) pauses per minute on your baseline."
            }
        }

        return Row(copy: copy)
    }

    enum PauseTrend { case above, below, steady }

    static func pauseTrend(filledRatioStat: BaselineStat) -> PauseTrend {
        // Lower filled-ratio = cleaner pauses. So if the user's mean is
        // below the lower percentile band, they're doing better than their
        // own baseline. The card surfaces the user-facing word "above
        // your baseline" for that case ("cleaner than usual").
        guard filledRatioStat.confidence.isReliable else { return .steady }
        let value = filledRatioStat.value
        // Treat "below 30%" as a strong-clean threshold regardless of the
        // sample's spread; matches the spec's "above your baseline" trigger
        // when filledRatio is low + pauseRate is reliable.
        if value <= 0.30 { return .above }
        if filledRatioStat.percentile75 > filledRatioStat.percentile25 {
            if value < filledRatioStat.percentile25 { return .above }
            if value > filledRatioStat.percentile75 { return .below }
        }
        // No interquartile spread (insufficient variation in the data) —
        // fall back to absolute thresholds so the trend never reads "steady"
        // on a clearly poor or clearly clean value.
        if value >= 0.50 { return .below }
        return .steady
    }

    // MARK: Word-choice row

    private static func wordChoiceRow(
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        now: Date
    ) -> Row? {
        guard baseline.vocabularyRange.confidence.isReliable else { return nil }

        // Aggregate unique-content-word ratio over each window using the same
        // tokenization as `WordChoiceMetrics.compute`. We compute the ratio
        // on the *combined* transcript across the window so a single short
        // rep doesn't dominate the read.
        let thisWeek = sessionsInWindow(sessions, daysBack: 0, daysSpan: 7, now: now)
        let lastWeek = sessionsInWindow(sessions, daysBack: 7, daysSpan: 7, now: now)

        let thisWeekRatio = uniqueRatio(across: thisWeek)
        let lastWeekRatio = uniqueRatio(across: lastWeek)

        let currentRatio = thisWeekRatio ?? baseline.vocabularyRange.value
        let percent = Int((currentRatio * 100).rounded())

        // Trend phrasing requires ≥ 2 qualifying reps in each window so we
        // don't claim "up from last week" off a single rep.
        let thisQualifies = thisWeek.filter(qualifiesForVocab).count >= 2
        let lastQualifies = lastWeek.filter(qualifiesForVocab).count >= 2

        let copy: String
        if let lhs = thisWeekRatio, let rhs = lastWeekRatio, thisQualifies, lastQualifies {
            let lhsPct = Int((lhs * 100).rounded())
            let rhsPct = Int((rhs * 100).rounded())
            let delta = lhsPct - rhsPct
            if delta >= 3 {
                copy = "\(lhsPct)% unique words. Up from \(rhsPct)% last week."
            } else if delta <= -3 {
                copy = "\(lhsPct)% unique words. Down from \(rhsPct)% last week. Lean on stronger verbs next rep."
            } else {
                copy = "\(lhsPct)% unique words. Holding steady week over week."
            }
        } else {
            // Not enough material for a week-over-week read. Drop the
            // baseline number so the row still has signal.
            copy = "\(percent)% unique words on your baseline."
        }
        return Row(copy: copy)
    }

    // MARK: - Helpers

    private static func sessionsInWindow(
        _ sessions: [PracticeSession],
        daysBack: Int,
        daysSpan: Int,
        now: Date
    ) -> [PracticeSession] {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: -daysBack, to: now) ?? now
        let start = cal.date(byAdding: .day, value: -(daysBack + daysSpan), to: now) ?? now
        return sessions.filter { $0.date >= start && $0.date < end }
    }

    private static func qualifiesForVocab(_ session: PracticeSession) -> Bool {
        // Mirrors WordChoiceMetrics.minContentWords floor so the rep
        // actually has material to read.
        let tokens = session.transcript
            .lowercased()
            .split { !$0.isLetter }
        return tokens.count >= WordChoiceMetrics.minContentWords
    }

    private static func uniqueRatio(across window: [PracticeSession]) -> Double? {
        let combined = window
            .map { $0.transcript }
            .joined(separator: " ")
        let tokens = combined
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)
        guard tokens.count >= WordChoiceMetrics.minContentWords else { return nil }
        let unique = Set(tokens).count
        return Double(unique) / Double(tokens.count)
    }

    private static func formatSeconds(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0fs", value) }
        return String(format: "%.1fs", value)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 12.0, *)
#Preview("Voice metrics — clean week") {
    @Previewable @State var path = NavigationPath()
    return ScrollView {
        VoiceMetricsCard(navigationPath: $path)
            .padding(Spacing.screenH)
    }
    .background(AppColor.screenBackground)
}
#endif

#endif
