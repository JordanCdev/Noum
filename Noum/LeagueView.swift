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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                Group {
                    switch peerVisibility {
                    case .forming:
                        formingState
                    case .available:
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            headerCopy
                            authorityNotice
                            tierCard
                            membersCard
                            Spacer(minLength: Spacing.lg)
                        }
                    }
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

    private var peerVisibility: PeerComparisonVisibility {
        PeerComparisonVisibility.make(
            members: league.members,
            currentAccountID: authManager.currentAccountID
        )
    }

    private var visibleMembers: [PublicProfileSnapshot] {
        PeerComparisonVisibility.visibleMembers(
            league.members,
            currentAccountID: authManager.currentAccountID
        )
    }

    private var formingState: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Peer comparison")
                .font(Typography.bigStat)
                .foregroundStyle(.primary)

            authorityNotice

            VStack(alignment: .leading, spacing: Spacing.md) {
                Image(systemName: "person.2.wave.2")
                    .font(Typography.bigStat)
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 56, height: 56)
                    .background(AppColor.brandBlue.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                Text("Your peer group is still forming.")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)

                Text("This view appears when another speaker in your weekly group has real activity. Noum will not fill the space with sample standings.")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if league.isLoading {
                    ProgressView()
                        .tint(AppColor.brandBlue)
                        .accessibilityLabel("Checking for active peers")
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(AppColor.subtleBorder, lineWidth: 1)
            )
        }
        .accessibilityIdentifier("peerComparison.forming")
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        leagueTitle
                        seePeaksLink
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        leagueTitle
                        Spacer(minLength: 0)
                        seePeaksLink
                    }
                }
            }

            Text(ratingStore.rating.hasRatedEvidence
                 ? "A weekly comparison with active speakers at a similar rating."
                 : "Complete one rated rep to create a fair comparison.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var leagueTitle: some View {
        Text("Peer comparison")
            .font(Typography.bigStat)
            .foregroundStyle(.primary)
    }

    /// M16: opens the full peak-rating wall. Surfaces the same bucket
    /// data this view shows, framed around personal-best comparisons
    /// rather than current-week standings.
    private var seePeaksLink: some View {
        NavigationLink(destination: PeakRatingWallView()) {
            HStack(spacing: 4) {
                Text("Personal bests")
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(AppColor.brandBlue)
            .padding(.vertical, 6)
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
                        .font(Typography.figtreeNumeric(size: 22, weight: .bold, relativeTo: .title3))
                        .foregroundStyle(AppColor.brandBlue)
                    Text(ratingStore.rating.hasRatedEvidence ? "Rating" : "Not rated")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                }
            }

            Divider()

            tierMetrics
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Tier wash — earned placements carry their tier tint; unrated
        // users get the neutral brand-blue diagnostic register.
        .background(tierCardBackground)
        .shadow(color: tierTint.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private var tierCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [tierTint.opacity(0.12), tierTint.opacity(0.0)],
                    center: UnitPoint(x: 0.15, y: 0.15),
                    startRadius: 0,
                    endRadius: 280
                )
            )
            shape.strokeBorder(tierTint.opacity(0.14), lineWidth: 1)
        }
    }

    private func metricColumn(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var tierMetrics: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                metricColumn(label: "Reset", value: resetMetricCopy, icon: "calendar")
                Divider()
                metricColumn(label: "Streak", value: streakValue, icon: "flame.fill")
                Divider()
                metricColumn(label: "This week", value: weeklyActivityCopy, icon: "chart.line.uptrend.xyaxis")
            }
        } else {
            HStack(spacing: 16) {
                metricColumn(label: "Reset", value: resetMetricCopy, icon: "calendar")
                Divider().frame(height: 28)
                metricColumn(label: "Streak", value: streakValue, icon: "flame.fill")
                Divider().frame(height: 28)
                metricColumn(label: "This week", value: weeklyActivityCopy, icon: "chart.line.uptrend.xyaxis")
            }
        }
    }

    private var tierSubtitle: String {
        guard ratingStore.rating.hasRatedEvidence else {
            return "One rated rep creates your comparison baseline."
        }
        if let next = league.tier.nextTier {
            let remaining = max(0, next.ratingFloor - ratingStore.rating.overall)
            return "\(remaining) rating points to \(next.title)."
        }
        return "You are in the top comparison tier."
    }

    private var streakValue: String {
        let s = streakFreeze.currentStreak
        if s == 0 { return "—" }
        return "\(s)d"
    }

    private var resetMetricCopy: String {
        let value = league.resetCopy.replacingOccurrences(of: "Resets ", with: "")
        guard let first = value.first else { return value }
        return first.uppercased() + String(value.dropFirst())
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
                Text("This week")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if league.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            VStack(spacing: 0) {
                if !ratingStore.rating.hasRatedEvidence {
                    placementPendingMembersRow
                } else if visibleMembers.isEmpty {
                    emptyMembersRow
                } else {
                    ForEach(Array(visibleMembers.enumerated()), id: \.element.id) { index, member in
                        memberRow(rank: index + 1, member: member, isYou: member.accountID == authManager.currentAccountID)
                        if index < visibleMembers.count - 1 {
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
                .font(Typography.figtreeNumeric(size: 16, weight: .bold, relativeTo: .headline))
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
                        .fixedSize(horizontal: false, vertical: true)
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
                    .font(Typography.figtreeNumeric(size: 18, weight: .bold, relativeTo: .headline))
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
            Text("Your weekly group is still forming.")
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("One rated rep creates your placement.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Noum waits for real rating evidence before comparing your week with other speakers.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink(value: AppDestination.practiceSelection) {
                Label("Start a rated rep", systemImage: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppColor.brandBlue, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("league.startRatedRep")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var authorityNotice: some View {
        if let failure = league.peerSyncFailure {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ErrorCard(message: failure.message)
                if failure.isRetryable {
                    Button {
                        Task { await league.retryPeerSync() }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            if league.isRetryingPeerSync {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(league.isRetryingPeerSync ? "Retrying peer sync" : "Retry peer sync")
                                .font(Typography.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(.pressable)
                    .disabled(league.isRetryingPeerSync)
                    .accessibilityIdentifier("league.peerSync.retry")
                }
            }
        } else if let divergence = league.ratingDivergence {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(AppColor.caution)
                    .accessibilityHidden(true)
                Text("Peer rating \(divergence.serverRating) differs from coaching rating \(divergence.localRating). Both remain unchanged while Noum verifies the history.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.caution.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .accessibilityIdentifier("league.ratingDivergence")
        }
    }

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
        await league.refreshMembers(force: force)
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
