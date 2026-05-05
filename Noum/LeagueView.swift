#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct LeagueView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var league = LeagueManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var authManager = AuthManager.shared

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
            Text("Your league")
                .font(Typography.bigStat)
                .foregroundStyle(.primary)

            Text("Speakers in your rating range, this week. Climbing rating moves you up a tier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
                    Text(league.tier.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                    Text(tierSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(ratingStore.rating.overall)")
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(AppColor.brandBlue)
                    Text("Rating")
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
                metricColumn(label: "This week", value: weeklyDeltaCopy, icon: "chart.line.uptrend.xyaxis")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
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
        if let toNext = league.ratingToNextTier, let next = league.tier.nextTier {
            return "+\(toNext) rating to \(next.title)"
        }
        return "Top tier — defend your rating to stay here."
    }

    private var streakValue: String {
        let s = streakFreeze.currentStreak
        if s == 0 { return "—" }
        return "\(s)d"
    }

    private var weeklyDeltaCopy: String {
        let delta = ratingStore.rating.weeklyDelta
        if delta > 0 { return "+\(delta)" }
        if delta < 0 { return "\(delta)" }
        return "—"
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
                if league.members.isEmpty {
                    emptyMembersRow
                    seededPeerStandings
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

    /// Seeded "ghost" rows shown when the league has only the user. These
    /// are not real users — they're plausible neighbours rendered with a
    /// disclosure that reads "Sample standings — your league fills as
    /// other speakers practise this week." Honest empty state without
    /// feeling barren.
    private var seededPeerStandings: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                Text("Sample standings · live data appears as the bucket fills")
                    .font(Typography.micro)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ForEach(Array(seededPeers.enumerated()), id: \.element.id) { index, peer in
                seededPeerRow(rank: index + 2, peer: peer) // start at rank 2 — user is rank 1
                if index < seededPeers.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    /// Hand-tuned ghost peers within the user's tier. Rating range
    /// matches the current tier so the user can see "what I'd see when
    /// the bucket fills" without us inventing an unrealistic peer set.
    private struct SeededPeer: Identifiable {
        let id: String
        let initials: String
        let rating: Int
        let streak: Int
        let weeklyReps: Int
    }

    private var seededPeers: [SeededPeer] {
        let floor = league.tier.ratingFloor
        let ceiling = min(1000, league.tier.ratingCeiling)
        let mid = (floor + ceiling) / 2
        // Place ghosts symmetrically around the user's likely rating so
        // the visualisation reads honest. Ratings + streaks + reps are
        // tuned to feel real but the IDs make it clear they're samples.
        return [
            .init(id: "sample-1", initials: "AM", rating: mid + 30, streak: 6, weeklyReps: 5),
            .init(id: "sample-2", initials: "TR", rating: mid + 10, streak: 4, weeklyReps: 4),
            .init(id: "sample-3", initials: "JB", rating: mid - 20, streak: 9, weeklyReps: 3),
            .init(id: "sample-4", initials: "KL", rating: max(floor + 10, mid - 60), streak: 2, weeklyReps: 2)
        ]
    }

    private func seededPeerRow(rank: Int, peer: SeededPeer) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .center)

            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.10))
                    .frame(width: 36, height: 36)
                Text(peer.initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Sample peer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Text("\(peer.weeklyReps) rep\(peer.weeklyReps == 1 ? "" : "s") this week")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: Spacing.xs)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(peer.rating)")
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.tertiary)
                if peer.streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2.weight(.bold))
                        Text("\(peer.streak)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                    }
                    .foregroundStyle(Color.orange.opacity(0.55))
                }
            }
        }
        .frame(minHeight: 56)
        .padding(.horizontal, Spacing.md)
        .opacity(0.7)
        .accessibilityHidden(true) // sample copy isn't useful to VoiceOver
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
            Text("You're matched with speakers in your rating range each ISO week. Climbing rating moves you up a tier; the leaderboard resets every Monday.")
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
        switch league.tier {
        case .bronze:   return Color(red: 0.65, green: 0.42, blue: 0.20)
        case .silver:   return Color(red: 0.60, green: 0.62, blue: 0.66)
        case .gold:     return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .platinum: return Color(red: 0.39, green: 0.55, blue: 0.78)
        case .diamond:  return Color(red: 0.36, green: 0.78, blue: 0.78)
        }
    }

    private func rankTint(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case 2: return Color(red: 0.60, green: 0.62, blue: 0.66)
        case 3: return Color(red: 0.65, green: 0.42, blue: 0.20)
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
