#if canImport(SwiftUI)
import SwiftUI

// MARK: - Recent Rep Review Card
//
// Targeted review surface that lifts 3-5 specific past sessions where the
// user had useful friction into one card,
// each with a one-tap CTA back into the same mode. Distinct from
// `WeakAreasCard`, which surfaces durable patterns; this one surfaces
// individual reps worth revisiting.
//
// Sourcing rules (in priority order):
//   1. Sessions with score <= 5 in the last 14 days
//   2. Sessions with high filler count (>= 6) in the last 14 days
//   3. Sudden Death sessions that failed in round 1 or 2 in the last 7 days
//
// The card hides itself entirely (`EmptyView()`) when there is nothing
// to replay — no fake content, no encouraging-but-empty state.
//
// CTA behavior:
//   The action button pushes the matching mode destination
//   (`.timedPractice`, `.suddenDeathPractice`, `.ahCounterPractice`).
//   Re-launching with the exact same prompt is not currently supported -
//   the prompt source-of-truth is internal `@State` inside
//   `TimedPracticeView`. The user sees the prompt text on this card for
//   context, and lands on a fresh mode entry point. This keeps
//   the architecture clean and avoids a parallel routing surface.

enum RecentRepReviewCopy {
    static let header = "Review recent reps"
    static let action = "Practice this mode"
}

@available(iOS 17.0, macOS 12.0, *)
struct MistakeReplayCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var sessionStore: PracticeSessionStore
    let onReplay: (AppDestination) -> Void

    @State private var hasAppeared = false

    private var shouldReduceMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    static func hasReviewRows(in sessions: [PracticeSession], now: Date = Date()) -> Bool {
        let cutoff14 = now.addingTimeInterval(-14 * 24 * 3600)
        let cutoff7  = now.addingTimeInterval(-7  * 24 * 3600)
        return sessions.contains { session in
            if session.date >= cutoff14 {
                if let score = session.score, score <= 5 { return true }
                if session.fillerWordCount >= 6 { return true }
            }
            if session.date >= cutoff7,
               session.mode == .suddenDeath,
               let rounds = Self.roundsSurvived(in: session),
               rounds <= 2 {
                return true
            }
            return false
        }
    }

    // MARK: - Replay row model

    private struct ReplayRow: Identifiable {
        let id: UUID
        let session: PracticeSession
        let coachLine: String
        let destination: AppDestination
        let priority: Int      // lower = higher priority (sort key)
    }

    // MARK: - Source

    private var rows: [ReplayRow] {
        let now = Date()
        let cutoff14 = now.addingTimeInterval(-14 * 24 * 3600)
        let cutoff7  = now.addingTimeInterval(-7  * 24 * 3600)

        var collected: [ReplayRow] = []
        var seenIDs = Set<UUID>()

        // Newest-first iteration so coach lines reflect the most recent
        // review-worthy reps.
        let recent = sessionStore.sessions.sorted { $0.date > $1.date }

        // 1. Low-score reps (priority 0)
        for session in recent where session.date >= cutoff14 {
            guard let score = session.score, score <= 5 else { continue }
            guard !seenIDs.contains(session.id) else { continue }
            seenIDs.insert(session.id)
            collected.append(ReplayRow(
                id: session.id,
                session: session,
                coachLine: lowScoreLine(for: session, score: score),
                destination: destination(for: session.mode),
                priority: 0
            ))
        }

        // 2. Filler-heavy reps (priority 1)
        for session in recent where session.date >= cutoff14 {
            guard session.fillerWordCount >= 6 else { continue }
            guard !seenIDs.contains(session.id) else { continue }
            seenIDs.insert(session.id)
            collected.append(ReplayRow(
                id: session.id,
                session: session,
                coachLine: fillerHeavyLine(for: session),
                destination: destination(for: session.mode),
                priority: 1
            ))
        }

        // 3. Sudden Death early-out (priority 2)
        for session in recent where session.date >= cutoff7 {
            guard session.mode == .suddenDeath else { continue }
            guard let rounds = roundsSurvived(in: session), rounds <= 2 else { continue }
            guard !seenIDs.contains(session.id) else { continue }
            seenIDs.insert(session.id)
            collected.append(ReplayRow(
                id: session.id,
                session: session,
                coachLine: suddenDeathEarlyLine(for: session, rounds: rounds),
                destination: .suddenDeathPractice,
                priority: 2
            ))
        }

        // Sort: priority asc, then date desc (most recent first within tier).
        let sorted = collected.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.session.date > rhs.session.date
        }

        // Show 3–5; the spec asks for that band.
        return Array(sorted.prefix(5))
    }

    // MARK: - Body

    var body: some View {
        let replayRows = rows
        if replayRows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header(count: replayRows.count)
                VStack(spacing: Spacing.sm) {
                    ForEach(replayRows) { row in
                        replayRowView(row)
                    }
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
                guard !hasAppeared else { return }
                if shouldReduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.standardSpring.delay(0.04)) { hasAppeared = true }
                }
            }
            .accessibilityIdentifier("mistakeReplayCard")
        }
    }

    // MARK: - Header

    private func header(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text(RecentRepReviewCopy.header)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text("\(count) rep\(count == 1 ? "" : "s")")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Row

    private func replayRowView(_ row: ReplayRow) -> some View {
        let tint = AppColor.tint(for: row.session.mode)

        return Button {
            CoachHaptic.selectionTap()
            onReplay(row.destination)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Mode icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: row.session.mode.iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(row.coachLine)
                            .font(Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        staleChip(for: row.session.date)
                    }

                    metricsLine(for: row.session)

                    if let prompt = row.session.prompt, !prompt.isEmpty {
                        Text(prompt)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption2.weight(.bold))
                        Text(RecentRepReviewCopy.action)
                            .font(Typography.caption.weight(.semibold))
                    }
                    .foregroundStyle(tint)
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(row.coachLine). \(metricsAccessibilityText(for: row.session)). \(RecentRepReviewCopy.action)."))
    }

    // MARK: - Metrics line

    private func metricsLine(for session: PracticeSession) -> some View {
        HStack(spacing: 6) {
            if let score = session.score {
                Text("\(score)/10")
                    .foregroundStyle(scoreColor(score))
                    .font(Typography.caption.weight(.semibold))
                Text("·")
                    .foregroundStyle(.tertiary)
            }
            Text("\(session.fillerWordCount) filler\(session.fillerWordCount == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
                .font(Typography.caption)
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(Int(session.duration))s")
                .foregroundStyle(.secondary)
                .font(Typography.caption)
        }
    }

    // MARK: - Stale chip
    //
    // Subtle "stale" indicator — relative-time chip ("5d") that intensifies
    // visually the longer it's been. We use the chip's tint to communicate
    // urgency: today/recent = soft gray, week-old = muted blue, older = caution amber.

    private func staleChip(for date: Date) -> some View {
        let days = max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
        let label = staleLabel(forDays: days)
        let intensity = staleIntensity(forDays: days)

        return Text(label)
            .font(Typography.caption.weight(.bold))
            .foregroundStyle(intensity.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(intensity.background, in: Capsule(style: .continuous))
            .accessibilityLabel(Text(staleAccessibility(forDays: days)))
    }

    private struct StaleIntensity {
        let foreground: Color
        let background: Color
    }

    private func staleIntensity(forDays days: Int) -> StaleIntensity {
        if days <= 1 {
            return StaleIntensity(
                foreground: AppColor.textSecondary,
                background: Color.black.opacity(0.06)
            )
        } else if days <= 5 {
            return StaleIntensity(
                foreground: AppColor.brandBlue,
                background: AppColor.brandBlue.opacity(0.10)
            )
        } else {
            return StaleIntensity(
                foreground: AppColor.caution,
                background: AppColor.caution.opacity(0.12)
            )
        }
    }

    private func staleLabel(forDays days: Int) -> String {
        if days <= 0 { return "today" }
        if days == 1 { return "1d" }
        return "\(days)d"
    }

    private func staleAccessibility(forDays days: Int) -> String {
        if days <= 0 { return "Today" }
        if days == 1 { return "1 day ago" }
        return "\(days) days ago"
    }

    // MARK: - Coach lines

    private func lowScoreLine(for session: PracticeSession, score: Int) -> String {
        let when = relativeWhen(session.date)
        switch session.mode {
        case .timed:        return "Timed Practice rep to revisit · \(when)"
        case .suddenDeath:  return "Pressure Drill rep to revisit · \(when)"
        case .ahCounter:    return "Filler Control rep to revisit · \(when)"
        case .imConversation: return "Conversation Practice rep to revisit · \(when)"
        }
    }

    private func fillerHeavyLine(for session: PracticeSession) -> String {
        let when = relativeWhen(session.date)
        return "Filler pattern to revisit · \(when)"
    }

    private func suddenDeathEarlyLine(for session: PracticeSession, rounds: Int) -> String {
        let when = relativeWhen(session.date)
        if rounds <= 1 {
            return "Round 1 pressure signal · \(when)"
        } else {
            return "Round 2 pressure signal · \(when)"
        }
    }

    private func relativeWhen(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func metricsAccessibilityText(for session: PracticeSession) -> String {
        var parts: [String] = []
        if let score = session.score { parts.append("Score \(score) of 10") }
        parts.append("\(session.fillerWordCount) fillers")
        parts.append("\(Int(session.duration)) seconds")
        return parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    private func destination(for mode: PracticeMode) -> AppDestination {
        switch mode {
        case .timed: return .timedPractice
        case .suddenDeath: return .suddenDeathPractice
        case .ahCounter: return .ahCounterPractice
        // IM Mode requires scenario/tone selection; route the user back through
        // the practice picker so they pick the right opponent fresh.
        case .imConversation: return .practiceSelection
        }
    }

    /// Sudden Death sessions store survivorship as the first insight,
    /// formatted like "Survived N rounds". Parse that conservatively —
    /// if the format ever drifts, we just skip the row instead of guessing.
    private func roundsSurvived(in session: PracticeSession) -> Int? {
        Self.roundsSurvived(in: session)
    }

    private static func roundsSurvived(in session: PracticeSession) -> Int? {
        guard session.mode == .suddenDeath else { return nil }
        guard let line = session.insights.first(where: { $0.lowercased().contains("survived") }) else {
            return nil
        }
        // Pull the first integer out of the line.
        let digits = line.unicodeScalars
            .split(whereSeparator: { !CharacterSet.decimalDigits.contains($0) })
            .first
            .map(String.init)
        return digits.flatMap(Int.init)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return AppColor.positive
        case 5...7:  return .primary
        default:     return AppColor.caution
        }
    }
}

#endif
