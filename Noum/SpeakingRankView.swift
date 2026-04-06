import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct SpeakingRankView: View {
    private let metricColumns = [
        GridItem(.adaptive(minimum: 110), spacing: 10, alignment: .top)
    ]

    @StateObject private var profile = ProfileManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @State private var selectedAchievementID: String?

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

    private var averageScoreText: String {
        let scores = sessions.compactMap(\.score)
        guard !scores.isEmpty else { return "N/A" }
        let average = Double(scores.reduce(0, +)) / Double(scores.count)
        return String(format: "%.1f/10", average)
    }

    private var strongestModeText: String {
        let grouped = Dictionary(grouping: sessions, by: \.mode)
        let ranked = grouped.max { lhs, rhs in
            averageScore(for: lhs.value) < averageScore(for: rhs.value)
        }?.key
        return ranked.map(label(for:)) ?? "Still forming"
    }

    private var primaryInsight: String {
        if let plan = CoachingPlanner.plan(for: sessions, profile: coachingProfileStore.profile) {
            return plan.encouragement
        }
        return "A few more sessions will turn this into a sharper read on how you speak under pressure."
    }

    private var progressionSummary: String {
        let recent = Array(sessions.prefix(8).reversed())
        guard let first = recent.first, let last = recent.last else {
            return "Log a few more reps to see how your speaking habits are shifting over time."
        }

        let scoreDelta = (last.score ?? 0) - (first.score ?? 0)
        let fillerDelta = first.fillerWordCount - last.fillerWordCount

        if scoreDelta >= 2 || fillerDelta >= 3 {
            return "Your recent reps are moving in the right direction. Quality is becoming more repeatable."
        }

        if scoreDelta <= -2 || fillerDelta <= -3 {
            return "Your ceiling is solid, but the baseline is still unstable. Aim for repeatable control before adding pressure."
        }

        return "The main opportunity right now is consistency. Keep the standard steady before you push harder."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroPanel
                performancePanel
                activeChallengePanel
                achievementsPanel
                coachingReadPanel
            }
            .padding(18)
        }
        .background(
            Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("rank.screen")
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: rankSymbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(rankTint)
                    .frame(width: 52, height: 52)
                    .background(rankTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(rankTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(rankDescriptor)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(rankTint)
                    Text(primaryInsight)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(nextRankTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(levelProgressLabel)
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
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private var performancePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Performance Snapshot")
                .font(.title3.weight(.bold))

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                statCard(title: "Sessions", value: "\(sessions.count)", tint: .blue)
                statCard(title: "Average", value: averageScoreText, tint: .green)
                statCard(title: "Best Mode", value: strongestModeText, tint: .indigo)
                statCard(title: "Unlocked", value: "\(unlockedAchievements.count)", tint: .orange)
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var activeChallengePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Challenge")
                .font(.title3.weight(.bold))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 42, height: 42)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

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
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var coachingReadPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coaching Read")
                .font(.title3.weight(.bold))

            Text(progressionSummary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let latest = sessions.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest session")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(latest.headline ?? "Latest practice")
                        .font(.headline)
                    Text(latest.coachSummary ?? latest.transcript)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func achievementRow(_ achievement: PracticeAchievementStatus, expanded: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
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
            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func averageScore(for sessions: [PracticeSession]) -> Double {
        let scores = sessions.compactMap(\.score)
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private func label(for mode: PracticeMode) -> String {
        switch mode {
        case .timed: return "Timed"
        case .suddenDeath: return "Sudden Death"
        case .ahCounter: return "Ah-Counter"
        case .imConversation: return "IM Mode"
        }
    }

    private var levelProgressLabel: String {
        "\(Int((profile.progressTowardsNextLevel * 100).rounded()))%"
    }

    private var rankSymbol: String {
        let title = profile.levelTitle
        if title.contains("Beginner") { return "sparkles" }
        if title.contains("Novice") { return "figure.stand" }
        if title.contains("Average") { return "waveform.path.ecg" }
        if title.contains("Professional") { return "shield.lefthalf.filled" }
        return "crown.fill"
    }

    private var rankTint: Color {
        let title = profile.levelTitle
        if title.contains("Beginner") { return .blue }
        if title.contains("Novice") { return .teal }
        if title.contains("Average") { return .indigo }
        if title.contains("Professional") { return .orange }
        return .yellow
    }

    private var rankDescriptor: String {
        let title = profile.levelTitle
        if title.contains("Beginner") { return "Foundational tier" }
        if title.contains("Novice") { return "Developing tier" }
        if title.contains("Average") { return "Steady tier" }
        if title.contains("Professional") { return "Advanced tier" }
        return "Elite tier"
    }

    private var rankTitle: String {
        "Speaker \(max(1, (profile.xp / 1000) + 1))"
    }

    private var nextRankTitle: String {
        "Next: Speaker \(max(2, (profile.xp / 1000) + 2))"
    }
}
#endif
