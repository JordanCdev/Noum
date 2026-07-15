import Foundation
#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        .background(LightGradientBackground())
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero Strip

    private var heroStrip: some View {
        HStack(spacing: Spacing.md) {
            heroProgressRing
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(unlockedCount) of \(totalCount)")
                    .font(Typography.bigStat.monospacedDigit())
                    .foregroundStyle(AppColor.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.standardSpring, value: unlockedCount)

                Text("achievements unlocked")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)

                if totalCount > 0 {
                    Text(percentLabel)
                        .font(Typography.micro)
                        .foregroundStyle(AppColor.textSecondary.opacity(0.8))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            // Coach character anchors the right side. Mood scales with
            // progress: excited once half the achievements are unlocked,
            // coaching otherwise (reads as "still teaching you").
            NoumCharacter(
                mood: overallFraction >= 0.5 ? .excited : .coaching,
                tint: AppColor.brandBlue,
                size: 56
            )
            .accessibilityHidden(true)
        }
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(unlockedCount) of \(totalCount) achievements unlocked")
    }

    private var percentLabel: String {
        let pct = Int((overallFraction * 100).rounded())
        return "\(pct)% complete"
    }

    private var heroProgressRing: some View {
        ZStack {
            Circle()
                .stroke(AppColor.subtleBorder, lineWidth: 8)

            Circle()
                .trim(from: 0, to: max(0.0001, overallFraction))
                .stroke(
                    LinearGradient(
                        colors: [AppColor.brandBlue, AppColor.pro],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.progressFill, value: overallFraction)

            VStack(spacing: 0) {
                Text("\(unlockedCount)")
                    .font(Typography.cardTitle.monospacedDigit())
                    .foregroundStyle(AppColor.textPrimary)
                Text("of \(totalCount)")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    // MARK: - Track Section

    private func trackSection(track: AchievementTrack, tiers: [AchievementTier]) -> some View {
        let trackStatuses = tiers.compactMap { statusByID[$0.id] }
        let unlockedInTrack = trackStatuses.filter(\.isUnlocked).count

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            trackHeader(track: track, unlocked: unlockedInTrack, total: tiers.count)

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
        }
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
    }

    private func trackHeader(track: AchievementTrack, unlocked: Int, total: Int) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: track.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(track.tint)
                .frame(width: 28, height: 28)
                .background(
                    track.tint.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            Text(track.label)
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            Text("\(unlocked)/\(total)")
                .font(Typography.caption.monospacedDigit())
                .foregroundStyle(AppColor.textSecondary)
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
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(tier.title)
                            .font(Typography.subheadline.weight(.semibold))
                            .foregroundStyle(status.isUnlocked
                                ? AppColor.textPrimary
                                : AppColor.textSecondary)

                        Spacer(minLength: 0)

                        Text(status.progressLabel)
                            .font(Typography.caption.monospacedDigit())
                            .foregroundStyle(status.isUnlocked
                                ? AppColor.positive
                                : AppColor.textSecondary)
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
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            unlockDateLabel(date: unlockDate)
                                .opacity(0.6)
                        }
                    }

                    // Locked: tap reveals what unlocks it (using tier.description as the criteria).
                    if !status.isUnlocked, showingHint {
                        unlockHintLabel(description: tier.description)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(accessibilityLabel(for: tier, status: status, unlockDate: unlockDate))
    }

    // MARK: - Row Pieces

    private func rowIcon(tier: AchievementTier, isUnlocked: Bool) -> some View {
        ZStack {
            if isUnlocked {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: tier.track.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: tier.symbolName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColor.innerSurface)
                    .frame(width: 40, height: 40)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColor.subtleBorder, lineWidth: 1)
                    .frame(width: 40, height: 40)

                Image(systemName: tier.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary.opacity(0.55))
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
                            : AnyShapeStyle(LinearGradient(
                                colors: [tint.opacity(0.85), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .frame(
                        width: max(progress > 0 ? 6 : 0, geo.size.width * min(1.0, progress))
                    )
                    .animation(.progressFill, value: progress)
            }
        }
        .frame(height: 6)
    }

    private func unlockDateLabel(date: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColor.positive)
            Text("Unlocked \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
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
        triggerHaptic()

        if status.isUnlocked {
            withAnimation(.snappySpring) {
                if revealedUnlockedIDs.contains(tier.id) {
                    revealedUnlockedIDs.remove(tier.id)
                } else {
                    revealedUnlockedIDs.insert(tier.id)
                }
            }
        } else {
            withAnimation(.snappySpring) {
                if revealedLockedIDs.contains(tier.id) {
                    revealedLockedIDs.remove(tier.id)
                } else {
                    revealedLockedIDs.insert(tier.id)
                }
            }
        }
    }

    private func triggerHaptic() {
#if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
#endif
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
                parts.append("Unlocked \(formatted)")
            } else {
                parts.append("Unlocked")
            }
        } else {
            parts.append("Locked. Progress \(status.progressLabel)")
        }
        return parts.joined(separator: ". ")
    }
}

#endif
