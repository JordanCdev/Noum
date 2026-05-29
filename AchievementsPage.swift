import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Dedicated Achievements Page

/// Full achievement inventory — pushed from the profile's compact preview.
@available(iOS 17.0, *)
struct AchievementsPage: View {
    @StateObject private var achievementStore = AchievementStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared

    @State private var selectedTier: AchievementTier?

    private var sessions: [PracticeSession] {
        sessionStore.sessions.sorted { $0.date > $1.date }
    }

    private var allStatuses: [PracticeAchievementStatus] {
        RetentionLoopEngine.snapshot(
            sessions: sessions,
            profile: coachingProfileStore.profile
        ).achievements
    }

    private var unlockedCount: Int {
        allStatuses.filter(\.isUnlocked).count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Overall progress header
                overallHeader

                // Track sections
                let trackData = AchievementStore.tiersByTrack
                ForEach(Array(trackData.enumerated()), id: \.element.track) { index, element in
                    trackSection(track: element.track, tiers: element.tiers)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
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
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedTier) { tier in
            let status = allStatuses.first { $0.id == tier.id }
            AchievementDetailView(
                tier: tier,
                isUnlocked: status?.isUnlocked ?? false,
                progress: status?.progress ?? 0,
                progressLabel: status?.progressLabel ?? "",
                unlockDate: achievementStore.unlocks[tier.id],
                nextInTrack: nextLockedTier(after: tier)
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }

    // MARK: - Overall Header

    private var overallHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(unlockedCount) of \(allStatuses.count)")
                        .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                    Text("achievements unlocked")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Compact progress bar
            GeometryReader { geo in
                let fraction = allStatuses.isEmpty ? 0.0 : Double(unlockedCount) / Double(allStatuses.count)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * fraction, fraction > 0 ? 8 : 0))
                }
            }
            .frame(height: 6)
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    // MARK: - Track Section

    private func trackSection(track: AchievementTrack, tiers: [AchievementTier]) -> some View {
        let statuses = tiers.compactMap { tier in allStatuses.first { $0.id == tier.id } }
        let unlocked = statuses.filter(\.isUnlocked).count
        let isMastery = track == .mastery

        // Sort: unlocked first (by tier index asc), then locked (by tier index asc)
        let sortedTiers = tiers.sorted { a, b in
            let aUnlocked = achievementStore.unlocks[a.id] != nil
            let bUnlocked = achievementStore.unlocks[b.id] != nil
            if aUnlocked != bUnlocked { return aUnlocked }
            return a.tierIndex < b.tierIndex
        }

        // NEW chip: from last session's unlocks + within 24h
        let newIDs = newlyUnlockedIDs

        return VStack(alignment: .leading, spacing: 12) {
            // Track header
            HStack(spacing: 8) {
                Image(systemName: track.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(track.tint)
                    .frame(width: 26, height: 26)
                    .background(track.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.label)
                        .font(.subheadline.weight(.bold))
                    if isMastery {
                        Text("Prestige")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(track.tint)
                    }
                }

                Spacer()

                Text("\(unlocked)/\(tiers.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            // Tier grid — 4 per row
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(sortedTiers, id: \.id) { tier in
                    let status = statuses.first { $0.id == tier.id }
                    let isUnlocked = status?.isUnlocked ?? false
                    gridItem(tier: tier, status: status, isUnlocked: isUnlocked, isNew: newIDs.contains(tier.id))
                }
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .fill(isMastery
                    ? AnyShapeStyle(LinearGradient(
                        colors: [AppColor.cardBackground, Color(red: 0.98, green: 0.96, blue: 0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    : AnyShapeStyle(AppColor.cardBackground)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    // MARK: - Grid Item

    private func gridItem(tier: AchievementTier, status: PracticeAchievementStatus?, isUnlocked: Bool, isNew: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                AchievementIconView(
                    tier: tier,
                    isUnlocked: isUnlocked,
                    progress: status?.progress ?? 0,
                    size: .grid
                )
                .frame(width: 52, height: 52)

                if isNew {
                    Text("NEW")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(tier.track.tint, in: Capsule())
                        .offset(x: 4, y: -2)
                }
            }

            Text(tier.title)
                .font(.system(size: 9, weight: isUnlocked ? .semibold : .medium))
                .foregroundStyle(isUnlocked ? Color.primary : Color.secondary.opacity(0.5))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTier = tier
        }
    }

    // MARK: - NEW Chip Logic

    /// IDs from the last session's unlocks, still within 24h window.
    private var newlyUnlockedIDs: Set<String> {
        let candidates = Set(achievementStore.newlyUnlocked)
        guard !candidates.isEmpty else { return [] }
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        return candidates.filter { id in
            guard let date = achievementStore.unlocks[id] else { return false }
            return date > cutoff
        }
    }

    // MARK: - Helpers

    private func nextLockedTier(after tier: AchievementTier) -> AchievementTier? {
        let trackTiers = AchievementStore.allTiers
            .filter { $0.track == tier.track }
            .sorted { $0.tierIndex < $1.tierIndex }
        guard let currentIndex = trackTiers.firstIndex(where: { $0.id == tier.id }) else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < trackTiers.count else { return nil }
        let next = trackTiers[nextIndex]
        guard achievementStore.unlocks[next.id] == nil else { return nil }
        return next
    }
}

// MARK: - Achievement Detail View (Sheet)

/// Clean, premium detail sheet — replaces the old dark popup modal.
@available(iOS 17.0, *)
struct AchievementDetailView: View {
    let tier: AchievementTier
    let isUnlocked: Bool
    let progress: Double
    let progressLabel: String
    let unlockDate: Date?
    let nextInTrack: AchievementTier?

    /// Difficulty label derived from position in track.
    private var difficultyLabel: String {
        if tier.totalTiersInTrack <= 1 { return "Milestone" }
        if tier.tierIndex == 0 { return "Starter" }
        if tier.tierIndex == tier.totalTiersInTrack - 1 { return "Elite" }
        return "Milestone"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 4)

            // Large badge
            AchievementIconView(
                tier: tier,
                isUnlocked: isUnlocked,
                progress: progress,
                size: .celebrate
            )
            .padding(.top, 8)

            Spacer().frame(height: 16)

            // Title
            Text(tier.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(isUnlocked ? .primary : .primary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 6)

            // Description
            Text(tier.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 14)

            // Progress or unlock date
            if isUnlocked {
                if let unlockDate {
                    Label(
                        "Unlocked \(unlockDate.formatted(.dateTime.month(.abbreviated).day().year()))",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                }
            } else {
                // Progress bar with inline label
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primary.opacity(0.08))
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    LinearGradient(
                                        colors: tier.track.accentGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(geo.size.width * progress, progress > 0 ? 8 : 0))
                        }
                    }
                    .frame(height: 10)
                    .padding(.horizontal, 32)

                    Text(progressLabel)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }

            Spacer().frame(height: 14)

            // Metadata row: track chip · milestone · difficulty
            HStack(spacing: 8) {
                // Track chip
                HStack(spacing: 5) {
                    Image(systemName: tier.track.symbol)
                        .font(.system(size: 10, weight: .bold))
                    Text(tier.track.label)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(tier.track.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(tier.track.tint.opacity(0.10), in: Capsule())

                // Milestone position
                if tier.totalTiersInTrack > 1 {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text("\(tier.tierIndex + 1) of \(tier.totalTiersInTrack)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text("·")
                    .foregroundStyle(.quaternary)

                // Difficulty tag inline
                Text(difficultyLabel.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(difficultyLabel == "Elite" ? tier.track.tint : .secondary)
            }

            // Next in track hint
            if let next = nextInTrack, isUnlocked {
                Spacer().frame(height: 12)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Next: \(next.title)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

#endif
