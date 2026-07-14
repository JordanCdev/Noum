#if canImport(SwiftUI)
import SwiftUI

// MARK: - Friend Leaderboard

/// Weekly peer leaderboard — sorts the current user against their friends by
/// speaking rating, streak, and reps this week.
///
/// Data flow:
/// - The current user's row is always built from local stores
///   (`RatingStore`, `StreakFreezeManager`, `PracticeSessionStore`).
/// - Friends with a known `accountID` are populated via
///   `FriendsManager.refreshPeerStats()` through the reciprocal-friend
///   authorized `getPeerProfile` callable.
///   Friends added before M2 (no `accountID`) render with an "Awaiting sync"
///   tag and a one-line explainer card so the empty state is honest.
struct FriendLeaderboardSelfRowPresentation: Equatable {
    static func ratingValue(for rating: SpeakingRating) -> Int? {
        rating.hasRatedEvidence ? rating.overall : nil
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct FriendLeaderboardView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var friendsManager = FriendsManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var authManager = AuthManager.shared

    @State private var showAddFriendSheet = false
    @State private var pendingRemoval: NoumFriend?
    @State private var showRemovalConfirmation = false

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    headerCopy
                    if !SocialReleaseCapabilities.friendProfiles.isAvailable {
                        capabilityNotice
                    }
                    leaderboardCard
                    if SocialReleaseCapabilities.friendConnections.isAvailable,
                       let message = friendsManager.connectionErrorMessage {
                        ErrorCard(message: message)
                            .accessibilityIdentifier("friends.connection.error")
                    }
                    if showsLegacyFriendNote {
                        legacyFriendNoteCard
                    }
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .refreshable {
                if SocialReleaseCapabilities.friendConnections.isAvailable {
                    await friendsManager.refreshFriendLinks(force: true)
                }
                await friendsManager.refreshPeerStats(force: true)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("leaderboard.screen")
        .task {
            if SocialReleaseCapabilities.friendConnections.isAvailable {
                await friendsManager.refreshFriendLinks()
            }
            await friendsManager.refreshPeerStats()
        }
        .sheet(isPresented: $showAddFriendSheet) {
            AddFriendSheet(
                friends: friendsManager,
                challenges: ChallengesManager.shared
            )
        }
        .confirmationDialog(
            "Remove connection?",
            isPresented: $showRemovalConfirmation,
            titleVisibility: .visible
        ) {
            if let friend = pendingRemoval {
                Button("Remove \(friend.displayName)", role: .destructive) {
                    Task { await friendsManager.removeConnection(id: friend.id) }
                    pendingRemoval = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingRemoval = nil
            }
        } message: {
            Text("Noum will remove this reciprocal connection. Saved manual contacts are unaffected.")
        }
    }

    // MARK: - Header

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Practice partners")
                .font(Typography.bigStat)
                .foregroundStyle(.primary)

            Text("A quiet weekly view of rating evidence and recent practice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Leaderboard

    private var capabilityNotice: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lock.shield")
                .foregroundStyle(AppColor.brandBlue)
                .accessibilityHidden(true)
            Text(SocialReleaseCapabilities.friendProfiles.message)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .accessibilityIdentifier("leaderboard.capabilityUnavailable")
    }

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SettingsSectionLabel(title: "This week")

            VStack(spacing: 0) {
                ForEach(Array(rankedRows.enumerated()), id: \.element.id) { index, row in
                    rankRow(rank: index + 1, row: row)
                    if index < rankedRows.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }

                if friendsManager.friends.isEmpty {
                    Divider()
                        .padding(.leading, 56)
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
        EmptyStateView(
            symbol: "person.crop.circle.badge.plus",
            title: "Save a practice contact",
            body: "Keep someone in mind for future reps. Shared stats appear when their Noum account is connected.",
            tint: AppColor.brandBlue,
            cta: EmptyStateView.CTA(label: "Add contact", icon: "plus") {
                showAddFriendSheet = true
            }
        )
        .accessibilityIdentifier("emptyState.peers")
    }

    private func rankRow(rank: Int, row: LeaderboardRow) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("\(rank)")
                .font(Typography.figtreeNumeric(size: 16, weight: .bold, relativeTo: .headline))
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

            if SocialReleaseCapabilities.friendConnections.isAvailable,
               let friendID = row.friendID,
               let friend = friendsManager.friends.first(where: { $0.id == friendID }),
               friend.isServerLinked {
                Button {
                    pendingRemoval = friend
                    showRemovalConfirmation = true
                } label: {
                    Label("Remove", systemImage: "person.crop.circle.badge.minus")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                        .padding(.horizontal, Spacing.xs)
                }
                .foregroundStyle(AppColor.warning)
                .accessibilityLabel("Remove connection with \(friend.displayName)")
                .disabled(friendsManager.isManagingConnections)
            }
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
                    .font(Typography.figtreeNumeric(size: 18, weight: .bold, relativeTo: .headline))
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
            Text(row.placeholderText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Legacy-friend explainer (only shown when relevant)

    /// True when at least one friend has no `accountID` and so can't be looked
    /// up server-side — typically a friend added before M2 shipped or via a
    /// manual name entry. The explainer tells the user how to get them synced
    /// rather than hiding the gap.
    private var showsLegacyFriendNote: Bool {
        SocialReleaseCapabilities.friendProfiles.isAvailable
            && friendsManager.friends.contains { $0.accountID == nil }
    }

    private var legacyFriendNoteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("Shared stats unavailable")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text("Saved contacts remain available for practice planning. Their scores stay private until account linking is available.")
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
        let friendID: UUID?

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
            if rating == nil { parts.append(placeholderText) }
            return parts.joined(separator: ", ")
        }

        var placeholderText: String {
            isCurrentUser ? "Awaiting rating" : "Awaiting sync"
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
                rating: FriendLeaderboardSelfRowPresentation.ratingValue(for: ratingStore.rating),
                streak: streakFreeze.currentStreak,
                repsThisWeek: myRepsThisWeek,
                isCurrentUser: true,
                friendID: nil
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
            let sharedStatsAvailable = SocialReleaseCapabilities.friendProfiles.isAvailable
                && friend.isServerLinked
            rows.append(
                LeaderboardRow(
                    id: friend.id.uuidString,
                    displayName: friend.displayName,
                    initials: friend.initials,
                    rating: sharedStatsAvailable ? friend.lastKnownRating : nil,
                    streak: sharedStatsAvailable ? friend.lastKnownStreak : nil,
                    repsThisWeek: sharedStatsAvailable ? friend.lastKnownRepsThisWeek : nil,
                    isCurrentUser: false,
                    friendID: friend.id
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
