#if canImport(SwiftUI)
import SwiftUI

// MARK: - Friend Leaderboard

/// Weekly peer leaderboard — sorts the current user against their friends by
/// speaking rating, streak, and reps this week.
///
/// **Backend gap (flagged):** peer stats (`lastKnownRating`, `lastKnownStreak`,
/// `lastKnownRepsThisWeek`) live on `NoumFriend` but are populated by a backend
/// endpoint that doesn't exist yet. Until the backend ships an endpoint at
/// `/v1/friends/stats` (or a Firestore equivalent), friends render with an
/// "Awaiting sync" empty state next to their name. The current user's row is
/// always populated from local stores so the screen is useful even pre-backend.
@available(iOS 17.0, macOS 12.0, *)
struct FriendLeaderboardView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var friendsManager = FriendsManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    headerCopy
                    leaderboardCard
                    backendNoteCard
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("leaderboard.screen")
    }

    // MARK: - Header

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week's leaderboard")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Sorted by speaking rating. Streaks and reps shown alongside.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Leaderboard

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SettingsSectionLabel(title: "Standings")

            VStack(spacing: 0) {
                ForEach(Array(rankedRows.enumerated()), id: \.element.id) { index, row in
                    rankRow(rank: index + 1, row: row)
                    if index < rankedRows.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }

                if friendsManager.friends.isEmpty {
                    emptyFriendsHint
                }
            }
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
        }
    }

    private var emptyFriendsHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add a friend to see how your week stacks up.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private func rankRow(rank: Int, row: LeaderboardRow) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)

            ZStack {
                Circle()
                    .fill(row.isCurrentUser
                        ? AppColor.brandBlue.opacity(0.18)
                        : AppColor.brandBlue.opacity(0.10))
                    .frame(width: 36, height: 36)
                Text(row.initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.subheadline.weight(row.isCurrentUser ? .bold : .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if row.isCurrentUser {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColor.brandBlue, in: Capsule())
                    }
                }
                if let secondary = row.secondaryLine {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Spacing.xs)

            ratingBlock(row: row)
        }
        .frame(minHeight: 56)
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityLabel(rank: rank))
    }

    @ViewBuilder
    private func ratingBlock(row: LeaderboardRow) -> some View {
        if let rating = row.rating {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(rating)")
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppColor.brandBlue)
                if let streak = row.streak, streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                        Text("\(streak)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            }
        } else {
            Text("Awaiting sync")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Backend note

    private var backendNoteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "icloud.slash")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("Peer sync isn't live yet")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            Text("Your friends' stats will populate here once the peer sync endpoint ships. For now you'll see your own row only.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Data

    private struct LeaderboardRow: Identifiable {
        let id: String
        let displayName: String
        let initials: String
        let rating: Int?
        let streak: Int?
        let repsThisWeek: Int?
        let isCurrentUser: Bool

        var secondaryLine: String? {
            if isCurrentUser, let reps = repsThisWeek {
                return "\(reps) rep\(reps == 1 ? "" : "s") this week"
            }
            if let reps = repsThisWeek {
                return "\(reps) rep\(reps == 1 ? "" : "s") this week"
            }
            return nil
        }

        func accessibilityLabel(rank: Int) -> String {
            var parts: [String] = ["Rank \(rank)", displayName]
            if let rating { parts.append("Rating \(rating)") }
            if let streak, streak > 0 { parts.append("Streak \(streak) days") }
            if rating == nil { parts.append("Awaiting sync") }
            return parts.joined(separator: ", ")
        }
    }

    private var rankedRows: [LeaderboardRow] {
        var rows: [LeaderboardRow] = []

        // Current user — always present, real data.
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let myRepsThisWeek = sessionStore.sessions.filter { $0.date >= weekAgo }.count

        let myName = authManager.currentAccountName?.trimmingCharacters(in: .whitespaces) ?? "You"
        let myInitials = String((myName.isEmpty ? "Y" : myName).prefix(1)).uppercased()

        rows.append(
            LeaderboardRow(
                id: authManager.currentAccountID ?? "self",
                displayName: myName.isEmpty ? "You" : myName,
                initials: myInitials,
                rating: ratingStore.rating.overall,
                streak: streakFreeze.currentStreak,
                repsThisWeek: myRepsThisWeek,
                isCurrentUser: true
            )
        )

        // Friends — sorted by lastKnownRating desc, friends with no synced
        // stats float to the bottom in alphabetical order.
        let withRating = friendsManager.friends.filter { $0.lastKnownRating != nil }
        let withoutRating = friendsManager.friends.filter { $0.lastKnownRating == nil }

        let sortedWithRating = withRating.sorted {
            ($0.lastKnownRating ?? 0) > ($1.lastKnownRating ?? 0)
        }
        let sortedWithoutRating = withoutRating.sorted {
            $0.displayName.lowercased() < $1.displayName.lowercased()
        }

        for friend in sortedWithRating + sortedWithoutRating {
            rows.append(
                LeaderboardRow(
                    id: friend.id.uuidString,
                    displayName: friend.displayName,
                    initials: friend.initials,
                    rating: friend.lastKnownRating,
                    streak: friend.lastKnownStreak,
                    repsThisWeek: friend.lastKnownRepsThisWeek,
                    isCurrentUser: false
                )
            )
        }

        // Re-sort the entire list so current user is placed by rating, not pinned.
        return rows.sorted { lhs, rhs in
            (lhs.rating ?? Int.min) > (rhs.rating ?? Int.min)
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
#Preview("Leaderboard — empty friends") {
    NavigationStack {
        FriendLeaderboardView()
    }
}
#endif

#endif
