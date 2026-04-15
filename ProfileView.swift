import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Contacts)
import Contacts
#endif
#if canImport(CoreImage)
import CoreImage.CIFilterBuiltins
#endif

#if canImport(SwiftUI)

// MARK: - Profile View (Unified Profile + Rank + Social)

@available(iOS 17.0, *)
struct ProfileView: View {
    @StateObject private var profile = ProfileManager.shared
    @StateObject private var premium = PremiumManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var friends = FriendsManager.shared
    @StateObject private var challenges = ChallengesManager.shared

    @State private var selectedAchievementID: String?
    @State private var showPaywall = false
    @State private var showAddFriendManual = false
    @State private var showScanner = false
    @State private var selectedAsyncChallenge: AsyncChallenge?
    @State private var showChallengePickFriend = false
    @Environment(\.openURL) private var openURL

    private let metricColumns = [
        GridItem(.adaptive(minimum: 110), spacing: 10, alignment: .top)
    ]

    private var displayName: String {
        authManager.currentAccountName ?? "Speaker"
    }

    private var sessions: [PracticeSession] {
        sessionStore.sessions.sorted { $0.date > $1.date }
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: sessions,
            profile: coachingProfileStore.profile
        )
    }

    private var unlockedAchievements: [PracticeAchievementStatus] {
        retentionSnapshot.achievements.filter(\.isUnlocked)
    }

    private var lockedAchievements: [PracticeAchievementStatus] {
        retentionSnapshot.achievements.filter { !$0.isUnlocked }
    }

    private var totalSessions: Int { sessions.count }

    private var currentStreak: Int {
        PracticeSession.calculateStreak(from: sessions)
    }

    private var coachingInsight: String {
        if let plan = CoachingPlanner.plan(for: sessions, profile: coachingProfileStore.profile) {
            return plan.encouragement
        }
        return "A few more sessions will turn this into a sharper read on how you speak under pressure."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                identityHeader
                rankPanel
                coachingDirectionCard
                activeChallengePanel
                achievementsPanel
                statsRow
                socialSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [AppColor.lightGradientStart, AppColor.lightGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showChallengePickFriend) {
            ChallengePickFriendSheet(friends: friends, challenges: challenges)
        }
        .sheet(isPresented: $showAddFriendManual) {
            AddFriendSheet(friends: friends, challenges: challenges)
        }
        .sheet(item: $selectedAsyncChallenge) { challenge in
            AsyncChallengeDetailSheet(challenge: challenge, challenges: challenges)
        }
    }

    // MARK: - Identity Header

    private var identityHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.purple.opacity(0.2), radius: 16, y: 6)

                Text(String(displayName.prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.title2.weight(.bold))

                    if premium.isPremium {
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColor.pro, in: Capsule())
                    }
                }

                Text(profile.levelTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("\(profile.xp) XP")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            if !premium.isPremium {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                        Text("Upgrade to Pro")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColor.pro, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Rank & XP Progress

    private var rankPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: profile.rankSymbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(profile.rankTint)
                    .frame(width: 52, height: 52)
                    .background(profile.rankTint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.rankTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(profile.rankDescriptor)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(profile.rankTint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(profile.nextRankTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(profile.levelProgressLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                ShimmerProgressBar(progress: profile.progressTowardsNextLevel, tint: .blue)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(profile.xp) XP total")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.blue)
                    Text("\(ProfileManager.xpNeededToNextLevel(forXP: profile.xp)) XP to level up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    // MARK: - Coaching Direction

    private var coachingDirectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coaching Direction")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(coachingInsight)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    // MARK: - Active Challenge

    private var activeChallengePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Challenge")
                .font(.title3.weight(.bold))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(retentionSnapshot.activeChallenge.title)
                        .font(.headline)
                    Text(retentionSnapshot.activeChallenge.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ShimmerProgressBar(progress: retentionSnapshot.activeChallenge.progress, tint: .orange)

            VStack(alignment: .leading, spacing: 6) {
                Text(retentionSnapshot.activeChallenge.progressLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(retentionSnapshot.activeChallenge.rewardLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            Text(retentionSnapshot.motivationLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    // MARK: - Achievements

    private var achievementsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Achievements")
                .font(.title3.weight(.bold))

            if unlockedAchievements.isEmpty {
                Text("Your first achievement will appear here once a habit becomes repeatable.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Attained achievements")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(unlockedAchievements) { achievement in
                    achievementRow(achievement, expanded: selectedAchievementID == achievement.id)
                }
            }

            if let nextAchievement = lockedAchievements.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    achievementRow(nextAchievement, expanded: selectedAchievementID == nextAchievement.id)
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private func achievementRow(_ achievement: PracticeAchievementStatus, expanded: Bool) -> some View {
        Button {
            withAnimation(.standardSpring) {
                selectedAchievementID = expanded ? nil : achievement.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: achievement.symbolName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(achievement.isUnlocked ? .green : .secondary)
                        .frame(width: 24, height: 24)
                        .padding(12)
                        .background(
                            achievement.isUnlocked ? Color.green.opacity(0.12) : Color.black.opacity(0.06),
                            in: Circle()
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(achievement.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(achievement.progressLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(achievement.isUnlocked ? .green : .secondary)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                if expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ShimmerProgressBar(
                            progress: achievement.progress,
                            tint: achievement.isUnlocked ? .green : .blue
                        )
                        Text(
                            achievement.isUnlocked
                                ? "Unlocked and retained. This is now part of the way you tend to show up."
                                : "Still in progress. Keep stacking reps until this becomes stable."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "Sessions", value: "\(totalSessions)", icon: "mic.fill", tint: .blue)
            statCard(title: "Streak", value: "\(currentStreak)d", icon: "flame.fill", tint: .orange)
            statCard(title: "Friends", value: "\(friends.friendCount)", icon: "person.2.fill", tint: .green)
        }
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Social Section

    private var socialSection: some View {
        VStack(spacing: 18) {
            speakOffsSection
            friendsSection
            inviteSection
        }
    }

    private var speakOffsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Speak-offs")
                    .font(.headline)
                Spacer()
                Button {
                    if friends.friends.isEmpty {
                        showAddFriendManual = true
                    } else {
                        showChallengePickFriend = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Challenge")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.teal, in: Capsule())
                }
            }

            Text("Challenge a friend to the same prompt. Both speak, then compare scores.")
                .font(.caption)
                .foregroundStyle(.secondary)

            let active = challenges.activeAsyncChallenges
            if active.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "person.2.wave.2")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.4))

                    Text("No active speak-offs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        if friends.friends.isEmpty {
                            showAddFriendManual = true
                        } else {
                            showChallengePickFriend = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                            Text("Start a Speak-off")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.teal, in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(active.prefix(5)) { challenge in
                    asyncChallengeRow(challenge)
                }
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func asyncChallengeRow(_ challenge: AsyncChallenge) -> some View {
        let userID = UUID(uuidString: authManager.currentAccountID ?? "") ?? UUID()
        let status = challenge.status(forUser: userID)
        let friendName = challenge.opponentName(forUser: userID)

        return Button {
            selectedAsyncChallenge = challenge
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 36, height: 36)
                    .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("vs \(friendName)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(status.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(status.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(status.tint.opacity(0.1), in: Capsule())
                    }

                    Text(challenge.prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let result = challenge.result(forUser: userID) {
                        HStack(spacing: 4) {
                            Image(systemName: result.icon)
                                .font(.caption2)
                            Text(result.label)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(result == .won ? .green : result == .lost ? .orange : .secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Friends")
                    .font(.headline)
                Spacer()
                Button {
                    showAddFriendManual = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Add")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.blue)
                }
            }

            if friends.friends.isEmpty {
                Text("No friends yet. Add a friend to start speak-offs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(friends.friends.prefix(5)) { friend in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)

                            Text(friend.initials)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.displayName)
                                .font(.subheadline.weight(.medium))
                            Text("Added \(friend.addedAt, style: .relative) ago")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Button {
                            challenges.createAsyncChallenge(opponentID: friend.id, opponentName: friend.displayName)
                        } label: {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                                .foregroundStyle(.teal)
                                .frame(width: 30, height: 30)
                                .background(Color.teal.opacity(0.1), in: Circle())
                        }
                    }
                }

                if friends.friendCount > 5 {
                    Text("+ \(friends.friendCount - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite Friends")
                .font(.headline)

            Text("Share your invite link and practice together.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                shareInviteLink()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                    Text("Share Invite Link")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func shareInviteLink() {
        let url = "https://apps.apple.com/app/noum/id6740486498"
        let activityVC = UIActivityViewController(
            activityItems: ["Practice speaking with me on Noum — it's like a gym for your voice.", URL(string: url)!],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
}

#endif
