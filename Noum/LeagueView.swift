#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct LeagueView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var league = LeagueManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    headerCopy
                    tierCard
                    membersCard
                    if league.members.isEmpty && !league.isLoading {
                        emptyLeagueExplainer
                    }
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .refreshable {
                await league.refreshMembers(force: true)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("league.screen")
        .task {
            await pushSelfAndRefresh(force: false)
        }
    }

    // MARK: - Header

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text("Your league")
                    .font(Typography.bigStat)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                seePeaksLink
            }

            Text(ratingStore.rating.hasRatedEvidence
                 ? "Speakers in your rating range, this week. Climbing rating moves you up a tier."
                 : "One rated pressure rep creates a fair weekly placement.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// M16: opens the full peak-rating wall. Surfaces the same bucket
    /// data this view shows, framed around personal-best comparisons
    /// rather than current-week standings.
    private var seePeaksLink: some View {
        NavigationLink(destination: PeakRatingWallView()) {
            HStack(spacing: 4) {
                Text("See peaks")
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(AppColor.brandBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("league.peakRatingWall.link")
        .accessibilityLabel("See your peak rating wall")
    }

    // MARK: - Tier card

    private var tierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tierTint.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "rosette")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(tierTint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(LeaguePlacementPresentation.tierTitle(tier: league.tier, rating: ratingStore.rating))
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                    Text(tierSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(LeaguePlacementPresentation.ratingValue(for: ratingStore.rating))
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(AppColor.brandBlue)
                    Text(ratingStore.rating.hasRatedEvidence ? "Rating" : "Not rated")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                }
            }

            Divider()

            HStack(spacing: 16) {
                metricColumn(label: "Reset", value: league.resetCopy, icon: "calendar")
                Divider().frame(height: 28)
                metricColumn(label: "Streak", value: streakValue, icon: "flame.fill")
                Divider().frame(height: 28)
                metricColumn(label: "This week", value: weeklyActivityCopy, icon: "chart.line.uptrend.xyaxis")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Tier wash — earned placements carry their tier tint; unrated
        // users get the neutral brand-blue diagnostic register.
        .background(tierCardBackground)
        .shadow(color: tierTint.opacity(0.14), radius: 14, x: 0, y: 6)
    }

    private var tierCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [tierTint.opacity(0.20), tierTint.opacity(0.0)],
                    center: UnitPoint(x: 0.15, y: 0.15),
                    startRadius: 0,
                    endRadius: 280
                )
            )
            shape.strokeBorder(tierTint.opacity(0.22), lineWidth: 1)
        }
    }

    private func metricColumn(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tierSubtitle: String {
        LeaguePlacementPresentation.fullScreenSubtitle(tier: league.tier, rating: ratingStore.rating)
    }

    private var streakValue: String {
        let s = streakFreeze.currentStreak
        if s == 0 { return "—" }
        return "\(s)d"
    }

    private var weeklyActivityCopy: String {
        LeagueActivityPresentation.weeklyActivityValue(
            sessionCount: LeagueActivityPresentation.weeklySessionCount(
                from: sessionStore.sessions,
                now: Date()
            ),
            dailyChallengeClaims: league.weeklyDailyChallengeCompletions
        )
    }

    // MARK: - Members

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SettingsSectionLabel(title: "Standings")
                Spacer()
                if league.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            VStack(spacing: 0) {
                if !ratingStore.rating.hasRatedEvidence {
                    placementPendingMembersRow
                } else if league.members.isEmpty {
                    emptyMembersRow
                } else {
                    ForEach(Array(league.members.enumerated()), id: \.element.id) { index, member in
                        memberRow(rank: index + 1, member: member, isYou: member.accountID == authManager.currentAccountID)
                        if index < league.members.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
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

    private func memberRow(rank: Int, member: PublicProfileSnapshot, isYou: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(rankTint(rank))
                .frame(width: 24, alignment: .center)

            ZStack {
                Circle()
                    .fill(isYou ? AppColor.brandBlue.opacity(0.18) : AppColor.brandBlue.opacity(0.10))
                    .frame(width: 36, height: 36)
                Text(initials(for: member.displayName))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName.isEmpty ? "Speaker" : member.displayName)
                        .font(.subheadline.weight(isYou ? .bold : .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isYou {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColor.brandBlue, in: Capsule())
                    }
                }
                if member.weeklyReps > 0 {
                    Text("\(member.weeklyReps) rep\(member.weeklyReps == 1 ? "" : "s") this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Spacing.xs)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(member.rating)")
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppColor.brandBlue)
                if member.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                        Text("\(member.currentStreak)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .frame(minHeight: 56)
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(memberAccessibilityLabel(rank: rank, member: member, isYou: isYou))
    }

    private var emptyMembersRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your league forms over the week.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Other \(league.tier.title.lowercased())-tier speakers will appear here as they practice.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var placementPendingMembersRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Placement starts after one rated rep.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Noum will place you in a weekly bucket only after there is rating evidence to compare.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var emptyLeagueExplainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("How leagues work")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            Text(ratingStore.rating.hasRatedEvidence
                 ? "You're matched with speakers in your rating range each ISO week. Climbing rating moves you up a tier; the leaderboard resets every Monday."
                 : "League placement starts after your first rated pressure rep, so the comparison is based on real speaking evidence.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Helpers

    private var tierTint: Color {
        ratingStore.rating.hasRatedEvidence ? league.tier.tint : AppColor.brandBlue
    }

    private func rankTint(_ rank: Int) -> Color {
        switch rank {
        case 1: return LeagueTier.gold.tint
        case 2: return LeagueTier.silver.tint
        case 3: return LeagueTier.bronze.tint
        default: return .secondary
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func memberAccessibilityLabel(rank: Int, member: PublicProfileSnapshot, isYou: Bool) -> String {
        var parts: [String] = ["Rank \(rank)", member.displayName]
        if isYou { parts.append("You") }
        parts.append("Rating \(member.rating)")
        if member.currentStreak > 0 { parts.append("Streak \(member.currentStreak) days") }
        if member.weeklyReps > 0 { parts.append("\(member.weeklyReps) reps this week") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Sync

    private func pushSelfAndRefresh(force: Bool) async {
        guard ratingStore.rating.hasRatedEvidence else { return }
        guard let accountID = authManager.currentAccountID else {
            await league.refreshMembers(force: force)
            return
        }
        let displayName = authManager.currentAccountName ?? "Speaker"
        let snapshot = PublicProfileBuilder.build(accountID: accountID, displayName: displayName)
        await league.syncSelf(snapshot: snapshot)
        await league.refreshMembers(force: true)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("League — empty") {
    NavigationStack {
        LeagueView()
    }
}
#endif

#endif
