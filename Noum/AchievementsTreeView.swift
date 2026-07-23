import Foundation
#if canImport(SwiftUI)
import SwiftUI

/// Presentation-only copy for the unified progress surface. The functions are
/// pure so tests can keep evidence claims bounded without adding another
/// progress store.
enum UnifiedProgressCopy {
    static func evidenceSummary(completedReps: Int, practiceDays: Int) -> String {
        guard completedReps > 0 else {
            return "Evidence begins after your first completed rep."
        }

        let repNoun = completedReps == 1 ? "rep" : "reps"
        let dayNoun = practiceDays == 1 ? "practice day" : "practice days"
        return "Evidence over time · \(completedReps) completed \(repNoun) across \(practiceDays) \(dayNoun)"
    }

    static func achievementEvidence(
        track: AchievementTrack,
        current: Int,
        target: Int
    ) -> String {
        let boundedCurrent = max(0, min(current, target))
        switch track {
        case .volume:
            return "\(boundedCurrent) qualifying practice reps recorded"
        case .consistency:
            return "\(boundedCurrent)-day practice rhythm recorded"
        case .clarity:
            let noun = boundedCurrent == 1 ? "rep" : "reps"
            return "No filler words detected in \(boundedCurrent) quantity-qualified \(noun)"
        case .scores:
            return "Score threshold recorded from eligible practice"
        case .endurance:
            return "Duration threshold recorded from eligible practice"
        case .modes:
            return "Mode-practice threshold recorded"
        case .mastery:
            return "Combined practice threshold recorded"
        }
    }

    static let practiceRatingBoundary =
        "Practice volume records work completed. Speaking rating moves only from rated pressure reps; the two are not equivalent."

    static func evidenceValue(current: Int, target: Int, isRecorded: Bool) -> Int {
        isRecorded ? target : current
    }
}

enum ProgressOutcomeKind: String, CaseIterable {
    case personalBest
    case practiceLevel
    case achievement
    case landmark

    var label: String {
        switch self {
        case .personalBest: return "Personal best"
        case .practiceLevel: return "Practice volume"
        case .achievement: return "Milestone recorded"
        case .landmark: return "Path landmark"
        }
    }

    var symbolName: String {
        switch self {
        case .personalBest: return "star.fill"
        case .practiceLevel: return "waveform.path.ecg"
        case .achievement: return "checkmark"
        case .landmark: return "arrow.up.right"
        }
    }

    var tint: Color {
        switch self {
        case .personalBest, .practiceLevel, .landmark: return AppColor.brandBlue
        case .achievement: return AppColor.positive
        }
    }

    var surface: Color {
        switch self {
        case .personalBest: return AppColor.brandBlue.opacity(0.08)
        case .practiceLevel, .achievement, .landmark: return AppColor.cardBackground
        }
    }
}

struct ProgressOutcome: Identifiable {
    let id: String
    let kind: ProgressOutcomeKind
    let title: String
    let detail: String
    let provenance: String
    let date: Date?
}

/// Shared, view-only presentation for an inline progress receipt. It never
/// mutates or persists progress, and it deliberately replaces full-screen
/// score/level/achievement celebrations.
@available(iOS 17.0, *)
struct ProgressOutcomeRow: View {
    let outcome: ProgressOutcome
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    outcomeIcon
                    outcomeText
                }
            } else {
                HStack(alignment: .center, spacing: Spacing.md) {
                    outcomeIcon
                    outcomeText
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(
            outcome.kind.surface,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(outcome.kind.tint.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var outcomeIcon: some View {
        Image(systemName: outcome.kind.symbolName)
            .font(.title3.weight(.bold))
            .foregroundStyle(Color.white)
            .frame(width: 48, height: 48)
            .background(outcome.kind.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
    }

    private var outcomeText: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(eyebrow)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .textCase(.uppercase)

            Text(outcome.title)
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(outcome.detail)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(outcome.provenance)
                .font(Typography.captionSmall)
                .foregroundStyle(AppColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var eyebrow: String {
        guard let date = outcome.date else { return outcome.kind.label }
        return "\(outcome.kind.label) · \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var accessibilityLabel: String {
        [eyebrow, outcome.title, outcome.detail, outcome.provenance]
            .joined(separator: ". ")
    }
}

/// A calm, source-bound progress record. Existing stores remain authoritative:
/// this screen only composes their projections into one readable journey.
@available(iOS 17.0, *)
struct AchievementsTreeView: View {
    @StateObject private var achievementStore = AchievementStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var streakManager = StreakFreezeManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var pathProgressManager = PathProgressManager.shared

    @State private var showFullHistory = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct Record: Identifiable {
        let tier: AchievementTier
        let status: PracticeAchievementStatus
        let date: Date?
        let current: Int
        let target: Int

        var id: String { tier.id }
    }

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

    private var records: [Record] {
        AchievementStore.allTiers.compactMap { tier in
            guard let status = statusByID[tier.id] else { return nil }
            let evaluation = tier.evaluate(sessions, streakManager.currentStreak)
            return Record(
                tier: tier,
                status: status,
                date: achievementStore.unlocks[tier.id],
                current: evaluation.current,
                target: evaluation.target
            )
        }
    }

    private var recentAchievementRecords: [Record] {
        records
            .filter { $0.status.isUnlocked }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private var practiceDayCount: Int {
        Set(sessions.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var recentOutcomes: [ProgressOutcome] {
        let personalBests = ratingStore.rating.personalBests.map(personalBestOutcome)
        let achievements = recentAchievementRecords.map(achievementOutcome)
        return Array(
            (personalBests + achievements)
                .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                .prefix(3)
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                currentStageSection

                Text(UnifiedProgressCopy.evidenceSummary(
                    completedReps: sessions.count,
                    practiceDays: practiceDayCount
                ))
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("progress.evidenceSummary")

                practiceAndRatingCard

                if recentOutcomes.isEmpty {
                    recentOutcomesEmptyState
                } else {
                    sectionHeading("Recent outcomes")
                    VStack(spacing: Spacing.sm) {
                        ForEach(recentOutcomes) { outcome in
                            ProgressOutcomeRow(outcome: outcome)
                        }
                    }
                }

                fullHistoryDisclosure
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.xs)
            .padding(.bottom, 40)
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle("Your coaching journey")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("milestones.screen")
    }

    private var currentStageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Current stage")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityAddTraits(.isHeader)

            if let current = pathProgressManager.currentNode {
                currentStageCard(current)
            } else {
                completedPathCard
            }
        }
    }

    private func currentStageCard(_ status: PathNodeStatus) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    currentStageIcon
                    currentStageText(status)
                }
            } else {
                HStack(alignment: .center, spacing: Spacing.md) {
                    currentStageIcon
                    currentStageText(status)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(
            AppColor.brandBlue.opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.brandBlue, lineWidth: 1.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Current stage. \(status.node.title). Next proof. \(status.node.detail)"
        )
        .accessibilityIdentifier("progress.currentStage")
    }

    private var currentStageIcon: some View {
        Image(systemName: "arrow.right")
            .font(.headline.weight(.bold))
            .foregroundStyle(Color.white)
            .frame(width: 48, height: 48)
            .background(AppColor.brandBlue, in: Circle())
            .accessibilityHidden(true)
    }

    private func currentStageText(_ status: PathNodeStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(status.node.title)
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Next proof · \(status.node.detail)")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var completedPathCard: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Current path complete")
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Your recorded evidence has reached every current landmark.")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColor.positive)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var practiceAndRatingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeading("Practice and rating")

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    practiceMetric
                    Divider()
                    ratingMetric
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.md) {
                    practiceMetric
                    Rectangle()
                        .fill(AppColor.subtleBorder)
                        .frame(width: 1, height: 74)
                        .accessibilityHidden(true)
                    ratingMetric
                }
            }

            Text(UnifiedProgressCopy.practiceRatingBoundary)
                .font(Typography.captionSmall)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
    }

    private var practiceMetric: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Practice volume")
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .textCase(.uppercase)
            Text("\(sessions.count) rep\(sessions.count == 1 ? "" : "s")")
                .font(Typography.cardTitle.monospacedDigit())
                .foregroundStyle(AppColor.textPrimary)
            Text("\(profileManager.xp.formatted()) practice XP recorded")
                .font(Typography.captionSmall)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var ratingMetric: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Speaking rating")
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .textCase(.uppercase)

            if ratingStore.rating.hasRatedEvidence {
                Text("\(ratingStore.rating.overall)")
                    .font(Typography.cardTitle.monospacedDigit())
                    .foregroundStyle(AppColor.textPrimary)
                Text("From \(ratingStore.rating.totalRatedSessions) rated pressure rep\(ratingStore.rating.totalRatedSessions == 1 ? "" : "s")")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Still forming")
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Complete a rated Pressure Drill rep")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var recentOutcomesEmptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionHeading("Recent outcomes")
            Label("Complete a qualifying rep to add a source-bound outcome.", systemImage: "waveform")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .background(
                    AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                )
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(Typography.cardLabel)
            .foregroundStyle(AppColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var fullHistoryDisclosure: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    showFullHistory.toggle()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text("Evidence over time and full history")
                        .font(Typography.cardLabel)
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: Spacing.xs)

                    Image(systemName: showFullHistory ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Evidence over time and full history")
            .accessibilityHint(showFullHistory ? "Hides every path and practice milestone." : "Shows every path and practice milestone.")
            .accessibilityValue(showFullHistory ? "Expanded" : "Collapsed")

            if showFullHistory {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    sectionHeading("Journey landmarks")
                    pathLandmarkList

                    sectionHeading("Practice milestones")
                    ForEach(AchievementStore.tiersByTrack, id: \.track) { entry in
                        let trackRecords = entry.tiers.compactMap { tier in
                            records.first { $0.tier.id == tier.id }
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label(entry.track.label, systemImage: entry.track.symbol)
                                .font(Typography.caption.weight(.semibold))
                                .foregroundStyle(AppColor.textSecondary)
                                .accessibilityAddTraits(.isHeader)

                            recordList(trackRecords)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(Spacing.md)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityIdentifier("milestones.inventory")
    }

    private var pathLandmarkList: some View {
        VStack(spacing: 0) {
            ForEach(Array(pathProgressManager.statuses.enumerated()), id: \.element.id) { index, status in
                pathLandmarkRow(status)

                if index < pathProgressManager.statuses.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(
            AppColor.innerSurface,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
    }

    private func pathLandmarkRow(_ status: PathNodeStatus) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Image(systemName: pathStatusSymbol(status))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(pathStatusTint(status))
                .frame(width: 36, height: 36)
                .background(pathStatusTint(status).opacity(0.08), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(status.node.title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status.node.detail)
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.xs)

            Text(pathStatusLabel(status))
                .font(Typography.captionSmall)
                .foregroundStyle(pathStatusTint(status))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.node.title). \(pathStatusLabel(status)). \(status.node.detail)")
    }

    private func recordList(_ records: [Record]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                recordRow(record)

                if index < records.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(
            AppColor.innerSurface,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
    }

    private func recordRow(_ record: Record) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Image(systemName: record.tier.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(record.status.isUnlocked ? AppColor.brandBlue : AppColor.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    (record.status.isUnlocked ? AppColor.brandBlue : AppColor.textSecondary).opacity(0.08),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(record.tier.title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(inventoryDescription(record))
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.xs)

            Text(record.status.isUnlocked ? "Recorded" : record.status.progressLabel)
                .font(Typography.captionSmall.monospacedDigit())
                .foregroundStyle(record.status.isUnlocked ? AppColor.positive : AppColor.textSecondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recordAccessibilityLabel(record))
    }

    private func achievementOutcome(_ record: Record) -> ProgressOutcome {
        ProgressOutcome(
            id: "achievement-\(record.id)",
            kind: .achievement,
            title: record.tier.title,
            detail: UnifiedProgressCopy.achievementEvidence(
                track: record.tier.track,
                current: UnifiedProgressCopy.evidenceValue(
                    current: record.current,
                    target: record.target,
                    isRecorded: record.status.isUnlocked
                ),
                target: record.target
            ),
            provenance: "Source: qualifying Noum practice",
            date: record.date
        )
    }

    private func personalBestOutcome(_ record: PersonalBestRecord) -> ProgressOutcome {
        let modeClause = record.mode.map { " · \($0.displayLabel)" } ?? ""
        let provenance = record.sessionId == nil
            ? "Source: recorded practice history"
            : "Source: qualifying\(modeClause) rep"
        return ProgressOutcome(
            id: "personal-best-\(record.id.uuidString)",
            kind: .personalBest,
            title: RatingEngine.pbTitle(record.category),
            detail: "\(RatingEngine.formatPB(record))\(modeClause)",
            provenance: provenance,
            date: record.date
        )
    }

    private func inventoryDescription(_ record: Record) -> String {
        if record.tier.track == .clarity {
            let noun = record.target == 1 ? "rep" : "reps"
            return "Record \(record.target) quantity-qualified \(noun) with no filler words detected."
        }
        return record.tier.description
    }

    private func recordAccessibilityLabel(_ record: Record) -> String {
        var parts = [record.tier.title, inventoryDescription(record)]
        if record.status.isUnlocked {
            parts.append("Recorded")
            if let date = record.date {
                parts.append(date.formatted(.dateTime.month(.abbreviated).day().year()))
            }
        } else {
            parts.append("In progress, \(record.status.progressLabel)")
        }
        return parts.joined(separator: ". ")
    }

    private func pathStatusLabel(_ status: PathNodeStatus) -> String {
        if status.isComplete { return "Recorded" }
        if status.isCurrent { return "Current" }
        return "Evidence needed"
    }

    private func pathStatusSymbol(_ status: PathNodeStatus) -> String {
        if status.isComplete { return "checkmark" }
        if status.isCurrent { return "arrow.right" }
        return "circle"
    }

    private func pathStatusTint(_ status: PathNodeStatus) -> Color {
        if status.isComplete { return AppColor.positive }
        if status.isCurrent { return AppColor.brandBlue }
        return AppColor.textSecondary
    }
}

#endif
