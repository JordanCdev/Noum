#if canImport(SwiftUI)
import SwiftUI

// MARK: - Weekly Digest Card

/// Compact home-screen card summarizing the user's week:
/// - Their goal (rendered from structured fields, never raw user text)
/// - Reps so far this week
/// - Top filler word
/// - Rating delta over the last 7 days
///
/// Hidden until the user has at least one rep this week — a digest of nothing
/// is just noise.
@available(iOS 17.0, macOS 12.0, *)
struct WeeklyDigestCard: View {
    @ObservedObject var sessionStore: PracticeSessionStore
    @ObservedObject var ratingStore: RatingStore
    @ObservedObject var clutchWordStore: ClutchWordStore
    @ObservedObject var coachingProfileStore: CoachingProfileStore

    var body: some View {
        let snapshot = WeeklySnapshot.compute(
            sessions: sessionStore.sessions,
            ratingDelta: ratingStore.rating.weeklyDelta,
            topClutchWord: clutchWordStore.topClutchWords.first
        )

        if snapshot.repsThisWeek == 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SettingsSectionLabel(title: "This week")

                cardBody(snapshot: snapshot)
            }
        }
    }

    @ViewBuilder
    private func cardBody(snapshot: WeeklySnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let profile = coachingProfileStore.profile {
                Text(profile.displayableGoal)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
            }

            HStack(alignment: .top, spacing: Spacing.sm) {
                stat(
                    label: "Reps",
                    value: "\(snapshot.repsThisWeek)",
                    tint: AppColor.brandBlue
                )
                stat(
                    label: "Rating",
                    value: snapshot.ratingDeltaLabel,
                    tint: snapshot.ratingDeltaTint
                )
                stat(
                    label: "Top filler",
                    value: snapshot.topFillerLabel,
                    tint: AppColor.caution
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(snapshot.accessibilitySummary(profile: coachingProfileStore.profile))
    }

    private func stat(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(value)
                .font(Typography.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Weekly Snapshot

/// Pure value type — easy to test, no SwiftUI dependency. Accepts already-fetched
/// inputs so the manager singletons aren't reached for inside the body.
struct WeeklySnapshot: Equatable {
    let repsThisWeek: Int
    let ratingDelta: Int
    let topFillerWord: String?
    let topFillerCount: Int

    static func compute(
        sessions: [PracticeSession],
        ratingDelta: Int,
        topClutchWord: ClutchWordEntry?
    ) -> WeeklySnapshot {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let reps = sessions.filter { $0.date >= weekAgo }.count

        return WeeklySnapshot(
            repsThisWeek: reps,
            ratingDelta: ratingDelta,
            topFillerWord: topClutchWord?.word,
            topFillerCount: topClutchWord?.totalOccurrences ?? 0
        )
    }

    var ratingDeltaLabel: String {
        if ratingDelta > 0 { return "+\(ratingDelta)" }
        if ratingDelta < 0 { return "\(ratingDelta)" }
        return "Steady"
    }

    var ratingDeltaTint: Color {
        if ratingDelta > 0 { return AppColor.positive }
        if ratingDelta < 0 { return AppColor.warning }
        return .secondary
    }

    var topFillerLabel: String {
        guard let word = topFillerWord, !word.isEmpty else {
            return "—"
        }
        return "\u{201C}\(word)\u{201D}"
    }

    func accessibilitySummary(profile: CoachingProfile?) -> String {
        var parts: [String] = []
        if let goal = profile?.displayableGoal {
            parts.append(goal)
        }
        parts.append("\(repsThisWeek) reps this week")
        if ratingDelta != 0 {
            parts.append("Rating \(ratingDeltaLabel)")
        }
        if let word = topFillerWord, !word.isEmpty {
            parts.append("Top filler word: \(word)")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
#Preview("Weekly Digest — empty") {
    WeeklyDigestCard(
        sessionStore: PracticeSessionStore.shared,
        ratingStore: RatingStore.shared,
        clutchWordStore: ClutchWordStore.shared,
        coachingProfileStore: CoachingProfileStore.shared
    )
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
