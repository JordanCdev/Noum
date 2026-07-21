import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Achievements Tree View
//
// Full inventory of every achievement in the system, grouped by track. Each
// track expands into a list of tiered rows with progress bars, lock states,
// and unlock dates. The hero strip at the top summarizes total unlocked.
//
// All progress data flows from `AchievementStore.shared.allStatuses(...)` —
// this view never recomputes progress itself. Inputs are `PracticeSessionStore`
// sessions and `StreakFreezeManager.currentStreak`.

@available(iOS 17.0, *)
struct AchievementsTreeView: View {
    @StateObject private var achievementStore = AchievementStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var streakManager = StreakFreezeManager.shared

    /// IDs of rows currently revealing their unlock date (after a tap).
    @State private var revealedUnlockedIDs: Set<String> = []
    /// IDs of locked rows currently showing their unlock-criteria tooltip.
    @State private var revealedLockedIDs: Set<String> = []
    /// Track detail stays collapsed until requested. The overview names one
    /// next milestone per track so the page reads as a plan, not an inventory.
    @State private var expandedTrackIDs: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Derived state

    private var sessions: [PracticeSession] {
        sessionStore.progressEligibleSessions
    }

    private var statuses: [PracticeAchievementStatus] {
        achievementStore.allStatuses(
            sessions: sessions,
            streak: streakManager.currentStreak
        )
    }

    private var statusByID: [String: PracticeAchievementStatus] {
        Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
    }

    private var unlockedCount: Int {
        statuses.filter(\.isUnlocked).count
    }

    private var totalCount: Int {
        statuses.count
    }

    private var overallFraction: Double {
        totalCount > 0 ? Double(unlockedCount) / Double(totalCount) : 0
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.cardGap) {
                heroStrip
                    .padding(.top, Spacing.xs)

                VStack(spacing: Spacing.cardGap) {
                    ForEach(AchievementStore.tiersByTrack, id: \.track) { entry in
                        trackSection(track: entry.track, tiers: entry.tiers)
                    }
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 40)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle("Milestones")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("milestones.screen")
    }

    // MARK: - Hero Strip

    private var heroStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Markers of consistent work—not another speaking score.")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline) {
                Text("\(unlockedCount) reached")
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Text("\(totalCount) total")
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(AppColor.textSecondary)
            }

            ProgressView(value: overallFraction)
                .tint(AppColor.brandBlue)
        }
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(unlockedCount) of \(totalCount) practice milestones reached")
    }

    // MARK: - Track Section

    private func trackSection(track: AchievementTrack, tiers: [AchievementTier]) -> some View {
        let trackStatuses = tiers.compactMap { statusByID[$0.id] }
        let unlockedInTrack = trackStatuses.filter(\.isUnlocked).count
        let isExpanded = expandedTrackIDs.contains(track.rawValue)
        let nextPair = zip(tiers, trackStatuses).first { !$0.1.isUnlocked }

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                toggleTrack(track)
            } label: {
                trackHeader(
                    track: track,
                    unlocked: unlockedInTrack,
                    total: tiers.count,
                    isExpanded: isExpanded
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("\(track.label), \(unlockedInTrack) of \(tiers.count) reached")
            .accessibilityHint(isExpanded ? "Hides every milestone in this area." : "Shows every milestone in this area.")

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(tiers.enumerated()), id: \.element.id) { index, tier in
                        if let status = statusByID[tier.id] {
                            achievementRow(tier: tier, status: status)

                            if index < tiers.count - 1 {
                                Divider()
                                    .background(AppColor.subtleBorder)
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            } else if let nextPair {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.forward.circle")
                        .foregroundStyle(AppColor.brandBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next: \(nextPair.0.title)")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text(nextPair.1.progressLabel)
                            .font(Typography.captionSmall.monospacedDigit())
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(.top, Spacing.xxs)
            }
        }
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
    }

    @ViewBuilder
    private func trackHeader(
        track: AchievementTrack,
        unlocked: Int,
        total: Int,
        isExpanded: Bool
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                trackTitle(track)
                HStack {
                    Text("\(unlocked) of \(total) reached")
                        .font(Typography.caption.monospacedDigit())
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            HStack(spacing: Spacing.xs) {
                trackTitle(track)
                Spacer()
                Text("\(unlocked)/\(total)")
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(AppColor.textSecondary)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func trackTitle(_ track: AchievementTrack) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: track.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 28, height: 28)
                .background(AppColor.brandBlue.opacity(0.09), in: Circle())
            Text(track.label)
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Row

    private func achievementRow(tier: AchievementTier, status: PracticeAchievementStatus) -> some View {
        let unlockDate = achievementStore.unlocks[tier.id]
        let showingDate = revealedUnlockedIDs.contains(tier.id)
        let showingHint = revealedLockedIDs.contains(tier.id)

        return Button {
            handleRowTap(tier: tier, status: status)
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                rowIcon(tier: tier, isUnlocked: status.isUnlocked)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            milestoneTitle(tier, status: status)
                            milestoneProgress(status)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                            milestoneTitle(tier, status: status)
                            Spacer(minLength: 0)
                            milestoneProgress(status)
                        }
                    }

                    Text(tier.description)
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    rowProgressBar(progress: status.progress, isUnlocked: status.isUnlocked, tint: tier.track.tint)
                        .padding(.top, 2)

                    // Unlocked: show date inline if persisted; reveal on tap.
                    if status.isUnlocked, let unlockDate {
                        if showingDate {
                            unlockDateLabel(date: unlockDate)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        } else {
                            unlockDateLabel(date: unlockDate)
                                .opacity(0.6)
                        }
                    }

                    // Locked: tap reveals what unlocks it (using tier.description as the criteria).
                    if !status.isUnlocked, showingHint {
                        unlockHintLabel(description: tier.description)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(accessibilityLabel(for: tier, status: status, unlockDate: unlockDate))
    }

    private func milestoneTitle(_ tier: AchievementTier, status: PracticeAchievementStatus) -> some View {
        Text(tier.title)
            .font(Typography.subheadline.weight(.semibold))
            .foregroundStyle(status.isUnlocked ? AppColor.textPrimary : AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func milestoneProgress(_ status: PracticeAchievementStatus) -> some View {
        Text(status.progressLabel)
            .font(Typography.caption.monospacedDigit())
            .foregroundStyle(status.isUnlocked ? AppColor.positive : AppColor.textSecondary)
    }

    // MARK: - Row Pieces

    private func rowIcon(tier: AchievementTier, isUnlocked: Bool) -> some View {
        ZStack {
            if isUnlocked {
                Circle()
                    .fill(AppColor.brandBlue)
                    .frame(width: 40, height: 40)

                Image(systemName: tier.symbolName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .fill(AppColor.innerSurface)
                    .frame(width: 40, height: 40)

                Circle()
                    .stroke(AppColor.subtleBorder, lineWidth: 1)
                    .frame(width: 40, height: 40)

                Image(systemName: tier.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.brandBlue.opacity(0.55))
            }
        }
        .frame(width: 40, height: 40)
    }

    private func rowProgressBar(progress: Double, isUnlocked: Bool, tint: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColor.subtleBorder)

                Capsule()
                    .fill(
                        isUnlocked
                            ? AnyShapeStyle(AppColor.positive)
                            : AnyShapeStyle(AppColor.brandBlue)
                    )
                    .frame(
                        width: max(progress > 0 ? 6 : 0, geo.size.width * min(1.0, progress))
                    )
                    .animation(reduceMotion ? nil : .progressFill, value: progress)
            }
        }
        .frame(height: 6)
    }

    private func unlockDateLabel(date: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColor.positive)
            Text("Reached \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
                .font(Typography.micro)
                .foregroundStyle(AppColor.textSecondary)
                .textCase(.none)
                .tracking(0)
        }
        .padding(.top, 2)
    }

    private func unlockHintLabel(description: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary.opacity(0.8))
                .padding(.top, 1)
            Text(description)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 6)
        .background(
            AppColor.innerSurface,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .padding(.top, 4)
    }

    // MARK: - Tap Handling

    private func handleRowTap(tier: AchievementTier, status: PracticeAchievementStatus) {
        CoachHaptic.selectionTap()

        if status.isUnlocked {
            withAnimation(reduceMotion ? nil : .snappySpring) {
                if revealedUnlockedIDs.contains(tier.id) {
                    revealedUnlockedIDs.remove(tier.id)
                } else {
                    revealedUnlockedIDs.insert(tier.id)
                }
            }
        } else {
            withAnimation(reduceMotion ? nil : .snappySpring) {
                if revealedLockedIDs.contains(tier.id) {
                    revealedLockedIDs.remove(tier.id)
                } else {
                    revealedLockedIDs.insert(tier.id)
                }
            }
        }
    }

    private func toggleTrack(_ track: AchievementTrack) {
        CoachHaptic.selectionTap()
        withAnimation(reduceMotion ? nil : .standardSpring) {
            if expandedTrackIDs.contains(track.rawValue) {
                expandedTrackIDs.remove(track.rawValue)
            } else {
                expandedTrackIDs.insert(track.rawValue)
            }
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(
        for tier: AchievementTier,
        status: PracticeAchievementStatus,
        unlockDate: Date?
    ) -> String {
        var parts: [String] = []
        parts.append(tier.title)
        parts.append(tier.description)
        if status.isUnlocked {
            if let unlockDate {
                let formatted = unlockDate.formatted(.dateTime.month(.abbreviated).day().year())
                parts.append("Reached \(formatted)")
            } else {
                parts.append("Reached")
            }
        } else {
            parts.append("Not reached. Progress \(status.progressLabel)")
        }
        return parts.joined(separator: ". ")
    }
}

#endif
