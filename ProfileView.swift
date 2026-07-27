import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Contacts)
#endif
#if canImport(CoreImage)
import CoreImage.CIFilterBuiltins
#endif

#if canImport(SwiftUI)

// MARK: - Profile View (Unified Profile + Rank + Social)

enum ProfileDefaultSurface: String, Equatable {
    case identity
    case progressHero
    case coachRead
    case evidenceHub
}

struct ProfileDefaultSurfacePlan: Equatable {
    let surfaces: [ProfileDefaultSurface]

    static func make(hasProgressEvidence: Bool) -> ProfileDefaultSurfacePlan {
        var surfaces: [ProfileDefaultSurface] = [.identity]
        if hasProgressEvidence {
            surfaces.append(.progressHero)
        }
        surfaces.append(contentsOf: [.coachRead, .evidenceHub])
        return ProfileDefaultSurfacePlan(surfaces: surfaces)
    }

    var defaultSectionCount: Int { surfaces.count }

    var ratingSurfaceCount: Int {
        surfaces.filter { $0 == .progressHero }.count
    }
}

enum ProfileCompositionEvidenceStage: Equatable {
    case zero
    case thin
    case established

    static func make(sessionCount: Int) -> ProfileCompositionEvidenceStage {
        switch sessionCount {
        case ...0: return .zero
        case 1...4: return .thin
        default: return .established
        }
    }
}

/// The default Profile is intentionally bounded to four roles. The progress
/// hero self-suppresses when neither rating nor baseline has enough evidence;
/// every other secondary system lives behind the single library disclosure.
struct ProfileCompositionPlan: Equatable {
    let stage: ProfileCompositionEvidenceStage
    let surfaces: [ProfileDefaultSurface]

    static func make(
        sessionCount: Int,
        hasProgressEvidence: Bool
    ) -> ProfileCompositionPlan {
        let stage = ProfileCompositionEvidenceStage.make(sessionCount: sessionCount)
        var surfaces: [ProfileDefaultSurface] = [.identity]
        if hasProgressEvidence {
            surfaces.append(.progressHero)
        }
        surfaces.append(contentsOf: [.coachRead, .evidenceHub])
        return ProfileCompositionPlan(stage: stage, surfaces: surfaces)
    }
}

enum ProfileLibraryRow: String, Equatable {
    case coachingEvidence
    case coachingMemory
    case growthLibrary
    case allReps
    case personalBests
    case friends
    case achievements
    case peerComparison
    case upgrade
}

struct ProfileLibraryPresentation: Equatable {
    let rows: [ProfileLibraryRow]

    static func make(
        showsPeerComparison: Bool,
        isPremium: Bool
    ) -> ProfileLibraryPresentation {
        var rows: [ProfileLibraryRow] = [
            .coachingEvidence,
            .coachingMemory,
            .growthLibrary,
            .allReps,
            .personalBests,
            .friends,
            .achievements
        ]
        if showsPeerComparison {
            rows.append(.peerComparison)
        }
        if !isPremium {
            rows.append(.upgrade)
        }
        return ProfileLibraryPresentation(rows: rows)
    }
}

enum PeerComparisonVisibility: Equatable {
    case forming
    case available(peerCount: Int)

    static func make(
        members: [PublicProfileSnapshot],
        currentAccountID: String?,
        now: Date = Date()
    ) -> PeerComparisonVisibility {
        guard let currentAccountID,
              !currentAccountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .forming
        }

        let peerIDs = Set(
            members.compactMap { member -> String? in
                guard isGenuinePeer(member, currentAccountID: currentAccountID, now: now) else {
                    return nil
                }
                return member.accountID.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
        guard !peerIDs.isEmpty else { return .forming }
        return .available(peerCount: peerIDs.count)
    }

    /// A Firestore bucket document alone is not enough to present a person.
    /// Old test rows, inactive accounts, and anonymous placeholder names stay
    /// out of this trust-sensitive social surface.
    static func isGenuinePeer(
        _ member: PublicProfileSnapshot,
        currentAccountID: String,
        now: Date = Date()
    ) -> Bool {
        let accountID = member.accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty, accountID != currentAccountID else { return false }
        guard member.weeklyReps > 0 else { return false }
        guard currentWeek(containing: now)?.contains(member.updatedAt) == true else { return false }

        let name = member.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let placeholders: Set<String> = ["", "speaker", "guest speaker", "noum speaker"]
        return !placeholders.contains(name)
    }

    /// Peer rows live in an ISO-week Firestore bucket and `weeklyReps` is
    /// computed for that same interval. Keep freshness aligned with that
    /// source-of-truth instead of hiding a valid weekly peer after 24 hours.
    private static func currentWeek(containing date: Date) -> DateInterval? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)
    }

    static func visibleMembers(
        _ members: [PublicProfileSnapshot],
        currentAccountID: String?,
        now: Date = Date()
    ) -> [PublicProfileSnapshot] {
        guard let currentAccountID else { return [] }
        return members.filter { member in
            member.accountID == currentAccountID
                || isGenuinePeer(member, currentAccountID: currentAccountID, now: now)
        }
    }

    var showsProfileEntry: Bool {
        if case .available = self { return true }
        return false
    }
}

enum ProfileEvidenceDetailSurface: String, Equatable {
    case rankProgress
    case ratingTrajectory
    case insightsBanked
    case pressureHistoryShare
    case baselineMap
    case coachingDirection
    case coachLoopReadiness
    case weeklyCheckIn
    case caseReview
    case deliveryProfile
    case speechPatterns
    case skillProgress
    case activeChallenge
    case feedbackInbox
    case league
    case communityPractice
    case achievements
}

struct ProfileEvidenceDetailPlan: Equatable {
    let surfaces: [ProfileEvidenceDetailSurface]

    // Progression-spine order: practice volume (.rankProgress) renders
    // AFTER the rating trajectory — volume is an input, never the spine,
    // so it can never sit above the rating story. Pinned by test.
    static let valueFirst = ProfileEvidenceDetailPlan(
        surfaces: [
            .ratingTrajectory,
            .rankProgress,
            .insightsBanked,
            .pressureHistoryShare,
            .baselineMap,
            .coachingDirection,
            .coachLoopReadiness,
            .weeklyCheckIn,
            .caseReview,
            .deliveryProfile,
            .speechPatterns
        ]
    )

    var ratingStorySurfaceCount: Int {
        surfaces.filter { $0 == .ratingTrajectory }.count
    }

    var optionalSystemSurfaceCount: Int {
        surfaces.filter { [.league, .communityPractice, .achievements].contains($0) }.count
    }
}

enum ProfileEvidenceHubLink: String, Hashable {
    case baselineMap
    case growthLibrary
    case history
}

struct ProfileEvidenceHubPresentation: Equatable {
    let linkOrder: [ProfileEvidenceHubLink]
    let usesCompactRows: Bool
    let showsDefaultHeader: Bool

    static let valueFirst = ProfileEvidenceHubPresentation(
        linkOrder: [.baselineMap, .growthLibrary, .history],
        usesCompactRows: true,
        showsDefaultHeader: false
    )
}

struct BaselineMapCard: View {
    let map: BaselineCoachMap

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            coachSummary
            BaselineCoachReadout(map: map)

            goalGapSection

            if let motivation = map.motivationAnchor {
                motivationSection(motivation)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.pro)
            Text("Baseline readout")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text(headerBadgeLabel)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColor.tagBackground, in: Capsule())
        }
    }

    private var coachSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(map.coachHeadline)
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(map.coachPriorityLine)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                baselineMetricPill(
                    icon: "scope",
                    label: "Reads",
                    value: "\(map.measuredDimensionCount)/\(map.dimensions.count)",
                    tint: AppColor.brandBlue
                )
                baselineMetricPill(
                    icon: "magnifyingglass",
                    label: "Evidence",
                    value: "\(map.qualifyingSessionCount) reps",
                    tint: AppColor.pro
                )
            }
        }
    }

    private func baselineMetricPill(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Typography.micro)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(value)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.065), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private var headerBadgeLabel: String {
        if map.formationProgress >= 1 {
            return "Ready"
        }
        return formationCountLabel
    }

    private var formationCountLabel: String {
        if map.formationProgress >= 1 {
            return "\(map.qualifyingSessionCount) reps"
        }
        return "\(map.qualifyingSessionCount)/\(BaselineCoachMap.establishedRepTarget)"
    }

    @ViewBuilder
    private var goalGapSection: some View {
        if let gap = map.goalGap {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Goal gap")
                            .font(Typography.micro)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        Text("Toward \(gap.goal.title.lowercased())")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Text(gap.percentLabel)
                        .font(Typography.figtreeNumeric(size: 24, weight: .bold, relativeTo: .title3))
                        .foregroundStyle(AppColor.brandBlue)
                }

                HStack(spacing: 10) {
                    goalGapMiniStat(label: "Current", value: gap.currentLabel)
                    goalGapMiniStat(label: "Target", value: gap.targetLabel)
                }
            }
            .padding(Spacing.md)
            .background(AppColor.brandBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        } else {
            Text("Complete a few more reps to see how close you are to your goal.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
    }

    private func goalGapMiniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(value)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        // Adaptive token — a fixed white chip inside an adaptive card leaves
        // its `.primary` ink unreadable in Dark appearance.
        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    private func motivationSection(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(AppColor.pro)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("Why this matters")
                    .font(Typography.micro)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(text)
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .background(AppColor.pro.opacity(0.07), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private var accessibilityLabel: String {
        var parts = [
            "Baseline readout.",
            "\(map.statusTitle).",
            "\(map.measuredDimensionCount) of \(map.dimensions.count) coach reads active."
        ]
        if let gap = map.goalGap {
            parts.append("Gap to goal: \(gap.summary). Current \(gap.currentLabel), target \(gap.targetLabel).")
        }
        if let motivation = map.motivationAnchor {
            parts.append("Original why: \(motivation)")
        }
        return parts.joined(separator: " ")
    }
}

private struct BaselineCoachReadout: View {
    let map: BaselineCoachMap

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let focus = map.readoutFocusDimension {
                BaselinePriorityReadRow(
                    read: focus,
                    role: focusRole(for: focus)
                )
            }

            if let strength = map.readoutStrengthDimension {
                BaselinePriorityReadRow(
                    read: strength,
                    role: .strength
                )
            }

            BaselineSupportingSignals(
                reads: map.supportingReadoutDimensions,
                measuredCount: map.measuredDimensionCount,
                totalCount: map.dimensions.count
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func focusRole(for read: BaselineCoachDimensionRead) -> BaselineReadRole {
        guard read.isMeasured else { return .learning }
        if let score = read.currentScore, score >= 0.72 {
            return .monitor
        }
        return .focus
    }
}

private enum BaselineReadRole {
    case focus
    case strength
    case learning
    case monitor

    var eyebrow: String {
        switch self {
        case .focus: return "Work next"
        case .strength: return "Holding"
        case .learning: return "Needs more reps"
        case .monitor: return "Keep watching"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "scope"
        case .strength: return "checkmark.seal.fill"
        case .learning: return "dot.radiowaves.left.and.right"
        case .monitor: return "eye.fill"
        }
    }

    var tint: Color {
        switch self {
        case .focus: return AppColor.caution
        case .strength: return AppColor.positive
        case .learning: return AppColor.pro
        case .monitor: return AppColor.brandBlue
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .focus: return 0.085
        case .strength: return 0.075
        case .learning: return 0.070
        case .monitor: return 0.070
        }
    }
}

private struct BaselinePriorityReadRow: View {
    let read: BaselineCoachDimensionRead
    let role: BaselineReadRole

    private var stateTint: Color {
        guard read.isMeasured else {
            return role.tint
        }

        let score = read.currentScore ?? 0
        if score >= 0.72 {
            return AppColor.positive
        }
        if score >= 0.42 {
            return read.dimension.signalTint
        }
        return AppColor.caution
    }

    private var valueText: String {
        read.valueLabel ?? "Needs more reps"
    }

    private var meterValue: Double {
        if let score = read.currentScore {
            return score
        }
        return read.evidenceProgress
    }

    private var badgeText: String {
        switch role {
        case .focus:
            return "Focus"
        case .strength:
            return "Strong"
        case .learning:
            return "Learning"
        case .monitor:
            return "Stable"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: role.icon)
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(role.tint)
                .frame(width: 34, height: 34)
                .background(role.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(role.eyebrow)
                    .font(Typography.micro)
                    .foregroundStyle(role.tint)
                    .textCase(.uppercase)
                    .tracking(0.7)

                Text(read.dimension.title)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("\(read.coachStateLabel) · \(valueText)")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(badgeText)
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(stateTint)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateTint.opacity(0.11), in: Capsule())

                BaselineScoreMeter(value: meterValue, tint: stateTint)
                    .frame(width: 82)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(role.tint.opacity(role.backgroundOpacity), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(role.tint.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(role.eyebrow). \(read.dimension.title). \(read.coachStateLabel). \(valueText).")
    }
}

private struct BaselineSupportingSignals: View {
    let reads: [BaselineCoachDimensionRead]
    let measuredCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Supporting signals")
                    .font(Typography.micro)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.7)

                Spacer(minLength: 8)

                Text("\(measuredCount) of \(totalCount) measured")
                    .font(Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            VStack(spacing: 7) {
                ForEach(reads) { read in
                    BaselineSupportSignalRow(read: read)
                }
            }
        }
        .padding(12)
        .background(
            AppColor.tagBackground.opacity(0.76),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
    }
}

private struct BaselineSupportSignalRow: View {
    let read: BaselineCoachDimensionRead

    private var valueText: String {
        read.valueLabel ?? "Gathering"
    }

    private var meterValue: Double {
        read.currentScore ?? read.evidenceProgress
    }

    private var tint: Color {
        guard read.isMeasured else { return .secondary }
        return read.dimension.signalTint
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: read.dimension.signalIcon)
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(read.isMeasured ? 0.10 : 0.07), in: Circle())

            Text(read.dimension.shortTitle)
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.80))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 6)

            Text(valueText)
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()

            BaselineScoreMeter(value: meterValue, tint: tint)
                .frame(width: 44)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(read.dimension.title). \(read.coachStateLabel). \(valueText).")
    }
}

private struct BaselineScoreMeter: View {
    let value: Double
    let tint: Color

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.07))

                Capsule()
                    .fill(tint.opacity(0.78))
                    .frame(width: max(4, proxy.size.width * CGFloat(clampedValue)))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

private extension BaselineCoachDimension {
    var signalIcon: String {
        switch self {
        case .fillerControl:
            return "speaker.slash.fill"
        case .paceControl:
            return "speedometer"
        case .structure:
            return "rectangle.stack.fill"
        case .clarity:
            return "checkmark.circle.fill"
        case .composure:
            return "pause.circle.fill"
        case .vocalRange:
            return "waveform.path"
        }
    }

    var signalTint: Color {
        switch self {
        case .fillerControl:
            return AppColor.caution
        case .paceControl:
            return AppColor.modeAhCounter
        case .structure:
            return AppColor.brandBlue
        case .clarity:
            return AppColor.positive
        case .composure:
            return AppColor.pro
        case .vocalRange:
            return .pink
        }
    }
}

struct ProfileIdentityPresentation: Equatable {
    let subtitle: String
    let exposesProgressCurrency: Bool

    static func make(profile: CoachingProfile?) -> ProfileIdentityPresentation {
        let subtitle: String
        if let voice = profile?.chosenStyleGoal {
            subtitle = "Voice target: \(voice.title)"
        } else {
            subtitle = "Speaking profile"
        }
        return ProfileIdentityPresentation(
            subtitle: subtitle,
            exposesProgressCurrency: false
        )
    }
}

struct ProfileCoachReadContent: Equatable {
    let label: String
    let read: String
    /// Evidence age + depth behind the hypothesis — "Watching this across
    /// 9 reps over 3 weeks." (assured) or the hedged "Early read — …; still
    /// forming." below the `.moderate` floor. Nil whenever the read shown
    /// is not the durable hypothesis (cold start, thin evidence, plan
    /// encouragement) so the card never ages a line that isn't the watch.
    let evidenceLine: String?
    let nextMove: String
    let proofClaim: String?
    let proofQuote: String?
    let isThinEvidence: Bool

    static func make(
        sessionCount: Int,
        plan: CoachingPlan?,
        memory: CoachMemory?,
        proof: ProofMomentRecord?,
        now: Date = Date()
    ) -> ProfileCoachReadContent {
        let confidence = memory?.evidenceConfidence ?? BaselineConfidence.from(sessionCount: sessionCount)
        let isThin = confidence < .tentative
        var evidenceLine: String?
        let read: String
        if let memory, let hypothesis = bounded(memory.workingHypothesis), confidence >= .tentative {
            read = userFacingRead(fromWorkingHypothesis: hypothesis)
            evidenceLine = CoachCaseFile.evidenceDepthLine(
                evidenceCount: memory.evidenceCount,
                confidence: confidence,
                watchingSince: memory.hypothesisWatchStartedAt,
                now: now
            )
        } else if sessionCount == 0 {
            read = "One short rep gives Noum something real to read."
        } else if let focus = bounded(plan?.currentFocus), isThin {
            read = "Early read: \(focus)"
        } else if let encouragement = bounded(plan?.encouragement) {
            read = encouragement
        } else {
            read = "A few more reps will turn this into a sharper read."
        }

        let nextMove: String
        if let intervention = memory?.activeIntervention {
            let focus = bounded(intervention.target) ?? bounded(intervention.focus) ?? intervention.title
            nextMove = "\(intervention.mode.displayLabel): \(focus)"
        } else if let suggestedDrill = bounded(plan?.suggestedDrill) {
            nextMove = suggestedDrill
        } else {
            nextMove = "Complete one short rep to set your starting line."
        }

        // `.tentative.label` is already "Early read" — appending " READ"
        // would render "EARLY READ READ", so both thin and tentative
        // resolve to the same plain badge.
        let label = (isThin || confidence == .tentative)
            ? "EARLY READ"
            : "\(confidence.label.uppercased()) READ"
        return ProfileCoachReadContent(
            label: label,
            read: read,
            evidenceLine: evidenceLine,
            nextMove: nextMove,
            proofClaim: bounded(proof?.proof.claim),
            proofQuote: bounded(proof?.proof.quote),
            isThinEvidence: isThin
        )
    }

    static func userFacingRead(fromWorkingHypothesis hypothesis: String) -> String {
        let trimmed = hypothesis.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parts = splitHypothesis(
            trimmed,
            marker: " appears to be the main focus because ",
            suffix: "; keep checking against future reps."
        ) {
            let topic = userFacingTopic(parts.topic)
            let basis = sentenceCased(userFacingBasis(parts.basis))
            return "\(topic) looks like the main focus right now. \(basis), so keep checking it in future reps."
        }
        if let parts = splitHypothesis(
            trimmed,
            marker: " may be the main focus because ",
            suffix: "; verify over more reps."
        ) {
            let topic = userFacingTopic(parts.topic)
            let basis = sentenceCased(userFacingBasis(parts.basis))
            return "\(topic) may be the main focus. \(basis), but Noum needs a few more reps before treating it as a pattern."
        }
        if let parts = splitHypothesis(
            trimmed,
            marker: " appears to be the highest-leverage focus because ",
            suffix: "; keep checking against future reps."
        ) {
            let topic = userFacingTopic(parts.topic)
            let basis = sentenceCased(userFacingBasis(parts.basis))
            return "\(topic) looks like the main focus right now. \(basis), so keep checking it in future reps."
        }
        if let parts = splitHypothesis(
            trimmed,
            marker: " may be the highest-leverage focus because ",
            suffix: "; verify over more reps."
        ) {
            let topic = userFacingTopic(parts.topic)
            let basis = sentenceCased(userFacingBasis(parts.basis))
            return "\(topic) may be the main focus. \(basis), but Noum needs a few more reps before treating it as a pattern."
        }
        return trimmed
            .replacingOccurrences(
                of: "persistent blocker in the rolling baseline",
                with: "it keeps showing up in recent reps"
            )
    }

    private static func splitHypothesis(
        _ value: String,
        marker: String,
        suffix: String
    ) -> (topic: String, basis: String)? {
        guard value.hasSuffix(suffix),
              let markerRange = value.range(of: marker) else { return nil }
        let topic = String(value[..<markerRange.lowerBound])
        let basisEnd = value.index(value.endIndex, offsetBy: -suffix.count)
        let basis = String(value[markerRange.upperBound..<basisEnd])
        guard !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !basis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return (topic, basis)
    }

    private static func userFacingTopic(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.localizedCaseInsensitiveCompare("Filler Words") == .orderedSame {
            return "Filler-word control"
        }
        guard let first = trimmed.first else { return trimmed }
        return String(first).uppercased() + String(trimmed.dropFirst()).lowercased()
    }

    private static func userFacingBasis(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if trimmed.localizedCaseInsensitiveCompare("persistent blocker in the rolling baseline") == .orderedSame {
            return "it keeps showing up in recent reps"
        }
        if trimmed.localizedCaseInsensitiveCompare("stable at developing") == .orderedSame {
            return "the pattern is steady, but not yet moving"
        }
        return trimmed
    }

    private static func sentenceCased(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return String(first).uppercased() + String(trimmed.dropFirst())
    }

    private static func bounded(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// The three visible lines on Profile's coaching brief. This is a
/// presentation adapter over the existing plan and memory; it does not persist
/// or strengthen a coaching claim.
struct ProfileCoachBriefPresentation: Equatable {
    let observation: String
    let nextMove: String
    let evidenceCaption: String?

    static func make(
        sessionCount: Int,
        plan: CoachingPlan?,
        memory: CoachMemory?,
        trends: [SkillTrend] = [],
        proof: ProofMomentRecord? = nil,
        now: Date = Date()
    ) -> ProfileCoachBriefPresentation {
        // The durable intervention is the coach's active promise to the user.
        // Keep Profile aligned with Home/Train by letting it outrank a generic
        // trend focus; otherwise the card can name fillers while prescribing a
        // structure drill in the very next line.
        if let intervention = memory?.activeIntervention {
            let focus = bounded(intervention.focus)
                ?? bounded(intervention.target)
                ?? intervention.title
            let target = bounded(intervention.target)
                ?? bounded(intervention.focus)
                ?? intervention.title
            return ProfileCoachBriefPresentation(
                observation: "Your current plan is working on \(sentenceFragment(focus)).",
                nextMove: "\(intervention.mode.displayLabel): \(sentenceFragment(target)).",
                evidenceCaption: evidenceCaption(for: max(0, memory?.evidenceCount ?? sessionCount))
            )
        }

        if let currentFocus = CurrentCoachingFocusPresentation.make(
            trends: trends,
            sessionCount: sessionCount
        ) {
            return ProfileCoachBriefPresentation(
                observation: currentFocus.observation,
                nextMove: currentFocus.instruction,
                evidenceCaption: currentFocus.evidenceCaption
            )
        }

        let content = ProfileCoachReadContent.make(
            sessionCount: sessionCount,
            plan: plan,
            memory: memory,
            proof: proof,
            now: now
        )
        let evidenceCount = max(0, memory?.evidenceCount ?? sessionCount)

        let observation: String
        if evidenceCount == 0 {
            observation = "One short rep gives Noum something real to read."
        } else if evidenceCount <= 2 {
            observation = startingPointObservation(for: evidenceCount)
        } else {
            observation = plainLanguage(content.read)
        }

        return ProfileCoachBriefPresentation(
            observation: observation,
            nextMove: plainLanguage(content.nextMove),
            evidenceCaption: evidenceCaption(for: evidenceCount)
        )
    }

    static func evidenceCaption(for evidenceCount: Int) -> String? {
        switch evidenceCount {
        case ...0:
            return nil
        case 1:
            return "Based on your latest rep."
        case 2:
            return "Based on your latest two reps."
        case 3...4:
            return "Early read from \(evidenceCount) recent reps."
        case 5...9:
            return "Seen across \(evidenceCount) recent reps."
        default:
            return "Repeated across \(evidenceCount) recent reps."
        }
    }

    static func plainLanguage(_ value: String) -> String {
        value
            .replacingOccurrences(of: "highest-leverage", with: "main", options: .caseInsensitive)
            .replacingOccurrences(of: "strongest lever right now", with: "main focus right now", options: .caseInsensitive)
            .replacingOccurrences(of: "strongest lever", with: "main focus", options: .caseInsensitive)
            .replacingOccurrences(of: "rolling baseline", with: "recent reps", options: .caseInsensitive)
            .replacingOccurrences(of: "persistent blocker", with: "recurring focus", options: .caseInsensitive)
            .replacingOccurrences(of: "keep testing it against future reps", with: "keep checking it in future reps", options: .caseInsensitive)
            .replacingOccurrences(of: "rehearsal shapes", with: "practice rounds", options: .caseInsensitive)
            .replacingOccurrences(of: "proof point", with: "concrete example", options: .caseInsensitive)
    }

    private static func sentenceFragment(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
    }

    private static func bounded(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func startingPointObservation(for evidenceCount: Int) -> String {
        evidenceCount == 1
            ? "Your first rep gives Noum a starting point."
            : "Your latest two reps are setting a starting point."
    }
}

struct ProfileRatingHeroPresentation: Equatable {
    let value: Int
    let directionLine: String

    static func make(rating: SpeakingRating) -> ProfileRatingHeroPresentation {
        let directionLine: String
        if rating.ratingHistory.count < 3 {
            let remaining = max(1, 3 - rating.ratingHistory.count)
            directionLine = "Baseline forming · \(remaining) rated rep\(remaining == 1 ? "" : "s") remaining"
        } else {
            switch rating.currentTrend {
            case .improving:
                directionLine = "Moving up across recent reps"
            case .stable:
                directionLine = "Holding steady across recent reps"
            case .declining:
                directionLine = "One more rep will clarify the direction"
            case .newIssue:
                directionLine = "New pattern · needs one confirming rep"
            case .resolved:
                directionLine = "A recent issue is no longer showing up"
            }
        }
        return ProfileRatingHeroPresentation(value: rating.overall, directionLine: directionLine)
    }
}

struct ProfileCoachLoopReadinessContent: Equatable {
    let title: String
    let detail: String
    let nextTitle: String?
    let nextDetail: String?
    let validationLine: String

    static func make(readiness: CoachParityReadiness) -> ProfileCoachLoopReadinessContent? {
        let coachingStages = readiness.stages.filter { $0.stage != .validation }
        let earned = coachingStages.filter { $0.status == .earned }
        let forming = coachingStages.filter { $0.status == .forming }

        guard !earned.isEmpty || !forming.isEmpty else {
            return nil
        }

        let title: String
        if earned.isEmpty {
            title = "Noum is still learning what helps you"
        } else {
            title = "Your plan is grounded in \(earned.count) kind\(earned.count == 1 ? "" : "s") of evidence"
        }

        let detail = stageLine(prefix: "Strong so far", stages: earned)
            ?? stageLine(prefix: "Still learning", stages: forming)
            ?? "Noum is still gathering evidence from your reps and check-ins."

        let next = coachingStages.first { $0.status == .thin }
            ?? coachingStages.first { $0.status == .forming }
        let nextTitle = next.map { "Next to strengthen: \(userFacingName(for: $0.stage))" }
        let nextDetail = next?.basis

        return ProfileCoachLoopReadinessContent(
            title: title,
            detail: detail,
            nextTitle: nextTitle,
            nextDetail: nextDetail,
            validationLine: "Real-world check-ins will show whether this coaching is helping outside the app."
        )
    }

    private static func stageLine(prefix: String, stages: [CoachParityReadiness.StageRead]) -> String? {
        guard !stages.isEmpty else { return nil }
        let names = stages.map { userFacingName(for: $0.stage) }
        return "\(prefix): \(naturalList(names))."
    }

    private static func userFacingName(for stage: CoachParityReadiness.Stage) -> String {
        switch stage {
        case .diagnosis: return "your baseline"
        case .formulation: return "the pattern behind your reps"
        case .prescription: return "the exercise choice"
        case .observation: return "how you responded"
        case .adaptation: return "what to adjust next"
        case .transfer: return "what carries into real conversations"
        case .validation: return "real-world results"
        }
    }

    private static func naturalList(_ values: [String]) -> String {
        switch values.count {
        case 0: return ""
        case 1: return values[0]
        case 2: return values.joined(separator: " and ")
        default:
            return values.dropLast().joined(separator: ", ") + ", and " + values.last!
        }
    }
}

enum ProfileTransferStatusKind: Equatable {
    case pendingOutcome
    case activePrep
    case transferPattern
    case recentOutcome
    case setupTeaser
}

struct ProfileTransferStatusContent: Equatable {
    let kind: ProfileTransferStatusKind
    let eyebrow: String
    let title: String
    let detail: String
    let actionTitle: String?
    let destination: AppDestination?
    let moment: BigMoment?

    /// `voice` is currently unread: the planner's intro no longer takes a
    /// register parameter, and this row's detail lines are voice-neutral.
    /// The parameter stays because the call signature is pinned by tests
    /// and it remains the seam for register-tuning the detail line.
    static func make(
        activeMoment: BigMoment?,
        pendingOutcomeMoment: BigMoment?,
        recentOutcome: BigMomentOutcomeReport?,
        transferTrend: BigMomentTransferTrend? = nil,
        sessions: [PracticeSession],
        voice: SpeakingStyleGoal?
    ) -> ProfileTransferStatusContent? {
        if let pendingOutcomeMoment {
            return pendingOutcomeContent(
                for: pendingOutcomeMoment,
                detail: "Your coach can learn from the room only after you report what happened."
            )
        }

        if let activeMoment {
            let days = BigMomentStore.daysUntil(activeMoment)
            if let days, days < 0 {
                return pendingOutcomeContent(
                    for: activeMoment,
                    detail: "This moment has passed. Check in so your coach can adapt the next rep."
                )
            }

            let daysText: String
            if let days {
                if days == 0 {
                    daysText = "today"
                } else if days == 1 {
                    daysText = "tomorrow"
                } else {
                    daysText = "in \(days) days"
                }
            } else {
                daysText = "scheduled"
            }
            let clampedDays = max(days ?? 7, 0)
            let plan = PrepSessionPlanner.plan(
                bigMoment: activeMoment,
                daysRemaining: clampedDays,
                modeAvailability: .failClosed
            )
            let readiness = PrepSessionPlanner.readiness(
                plan: plan,
                sessions: sessions,
                momentCreatedAt: activeMoment.createdAt
            )
            return ProfileTransferStatusContent(
                kind: .activePrep,
                eyebrow: "Real-world prep",
                title: "\(activeMoment.title) \(daysText)",
                detail: readiness.line,
                actionTitle: "Continue prep",
                destination: .prepSession,
                moment: activeMoment
            )
        }

        if let transferTrend {
            return ProfileTransferStatusContent(
                kind: .transferPattern,
                eyebrow: "Transfer pattern",
                title: transferTrend.profileTitle,
                detail: transferTrend.profileDetailLine,
                actionTitle: nil,
                destination: nil,
                moment: nil
            )
        }

        if let recentOutcome {
            let transfer = recentOutcome.drillTransfer.map { " Prep: \($0.chipLabel.lowercased())." } ?? ""
            return ProfileTransferStatusContent(
                kind: .recentOutcome,
                eyebrow: "Last transfer read",
                title: recentOutcome.momentTitle,
                detail: "You reported \(recentOutcome.outcome.chipLabel.lowercased()); room read: \(recentOutcome.audienceResponse.chipLabel.lowercased()).\(transfer)",
                actionTitle: nil,
                destination: nil,
                moment: nil
            )
        }

        return ProfileTransferStatusContent(
            kind: .setupTeaser,
            eyebrow: "Real-world loop",
            title: "Bring Noum a real moment",
            detail: "Set an interview, presentation, or hard conversation. Noum will shape prep around it, then ask how it actually landed.",
            actionTitle: "Set moment",
            destination: .bigMomentIntake,
            moment: nil
        )
    }

    private static func pendingOutcomeContent(
        for moment: BigMoment,
        detail: String
    ) -> ProfileTransferStatusContent {
        ProfileTransferStatusContent(
            kind: .pendingOutcome,
            eyebrow: "Transfer check-in",
            title: "How did \(moment.title) land?",
            detail: detail,
            actionTitle: "Check in",
            destination: nil,
            moment: moment
        )
    }
}

/// Earned-motion policy for the Profile rating number (Iteration 7).
///
/// The numeric roll on the Speaking Rating hero animates ONLY when the
/// rating ticks UP to a new weekly best — the one earned moment on this
/// surface. Everything else updates silently:
///   • first paint (`previous == nil`) — no motion on appear
///   • cold start (no rated evidence) — the seeded 400 never animates
///   • drops — never-punish-shame: the snapshot updates with no motion
///   • partial recoveries below the week peak — quiet until the best is back
///
/// `RatingEngine.processRatedSession` keeps `weekPeakRating` at the max of
/// the current ISO week, so "new weekly best" reduces to the overall rating
/// having just risen to meet (or exceed) that peak inside the current week.
enum ProfileRatingTickMotion {
    static func shouldAnimateTick(previous: Int?, rating: SpeakingRating) -> Bool {
        guard let previous else { return false }
        guard rating.hasRatedEvidence else { return false }
        guard rating.overall > previous else { return false }
        guard rating.isWeekPeakCurrent else { return false }
        return rating.overall >= rating.weekPeakRating
    }
}

/// One quiet "recently resolved" line for the Speaking Rating card — the
/// believable-progress payoff when a tracked weakness flips to `.resolved`
/// ("was a problem, no longer is") in the skill trends.
///
/// Honesty contract:
///   • Only `.resolved` directions render. Improving/declining/stable
///     produce nothing here — a slipping skill is never called out on the
///     progress hero (never punish-shame; drops live in the case file).
///   • Requires better-than-`.low` trend confidence, so a two-rep blip
///     cannot claim a weakness was conquered (weak evidence → no claim).
///   • Returns nil when nothing qualifies — the row disappears entirely,
///     never an empty shell.
enum ProfileResolvedWeaknessLine {
    static func make(trends: [SkillTrend]) -> String? {
        let resolved = trends.filter {
            $0.direction == .resolved && $0.confidence != .low
        }
        guard !resolved.isEmpty else { return nil }
        let names = resolved.prefix(2).map(\.skillArea.displayName)
        return "Recently resolved: \(names.joined(separator: ", "))"
    }
}

@available(iOS 17.0, *)
struct ProfileView: View {
    @StateObject private var profile = ProfileManager.shared
    @StateObject private var premium = PremiumManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var friends = FriendsManager.shared
    @StateObject private var challenges = ChallengesManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @StateObject private var trendStore = SkillTrendStore.shared
    @StateObject private var clutchWordStore = ClutchWordStore.shared
    @StateObject private var feedbackManager = FeedbackRequestManager.shared
    @State private var selectedFeedbackRequest: StoredFeedbackRequest?
    @StateObject private var league = LeagueManager.shared
    @StateObject private var proofStore = ProofMomentStore.shared
    @StateObject private var forwardPlanStore = ForwardPlanStore.shared
    @StateObject private var bigMomentStore = BigMomentStore.shared
    @StateObject private var suddenDeathRunHistoryStore = SuddenDeathRunHistoryStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var coachCheckInStore = CoachCheckInStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var flowEvents = FlowEventLog.shared

    @State private var showAchievementsTree = false
    @State private var showPaywall = false
    @State private var showProfileEvidence = false
    @State private var showCoachReadEvidence = false
    @State private var showRatingEvidence = false
    @State private var showProgressionEvidence = false
    /// Last rating value this view has rendered — feeds the earned-motion
    /// policy so the numeric roll fires only on an upward tick to a new
    /// weekly best (drops and first paint update silently).
    @State private var lastSeenOverallRating: Int?
    /// One-shot trigger for the resolved-weakness settle bounce. Toggled on
    /// row appearance (skipped under Reduce Motion) so the checkmark gets a
    /// single discrete bounce, never a repeating effect.
    @State private var resolvedSettleTick = false
    /// One-shot pop scale for the "+N this week" chip — fires only when the
    /// rating's earned numeric roll fires (`ProfileRatingTickMotion`), so the
    /// chip pop reuses the same upward-only, reduce-motion-aware predicate.
    /// Down weeks render the quiet plain line and never enter this path.
    @State private var weeklyDeltaChipScale: CGFloat = 1.0
    @State private var showAddFriendManual = false
    @State private var selectedAsyncChallenge: AsyncChallenge?
    @State private var showChallengePickFriend = false
    @State private var profileOutcomeMoment: BigMoment?
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isAppTabRoot) private var isAppTabRoot

    private let metricColumns = [
        GridItem(.adaptive(minimum: 110), spacing: 10, alignment: .top)
    ]

    private var displayName: String {
        AuthManager.userFacingDisplayName(from: authManager.currentAccountName)
    }

    private var sessions: [PracticeSession] {
        sessionStore.sessions.sorted { $0.date > $1.date }
    }

    /// Sessions allowed to strengthen coaching and visible progress. Raw
    /// `sessions` remains the saved-rep/Review source so a transport-valid
    /// capture that is too thin to reward can still be inspected or deleted.
    private var progressEligibleSessions: [PracticeSession] {
        sessionStore.progressEligibleSessions.sorted { $0.date > $1.date }
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: progressEligibleSessions,
            profile: coachingProfileStore.profile,
            displayedStreak: streakFreeze.currentStreak
        )
    }

    private var unlockedAchievements: [PracticeAchievementStatus] {
        retentionSnapshot.achievements.filter(\.isUnlocked)
    }

    private var totalProgressSessions: Int { progressEligibleSessions.count }

    /// The displayed streak — always the freeze-aware number from
    /// StreakFreezeManager (the single displayed-streak owner), so the
    /// Profile stat can never disagree with Home's quiet streak line.
    private var currentStreak: Int {
        streakFreeze.currentStreak
    }

    /// True when there's at least one friend and none of them carry an
    /// `accountID`, so scored peer comparison cannot honestly resolve from
    /// backend participant evidence yet.
    private var hasOnlyUnlinkedFriends: Bool {
        let list = friends.friends
        guard !list.isEmpty else { return false }
        return list.allSatisfy { $0.accountID == nil }
    }

    private var linkedSpeakOffFriends: [NoumFriend] {
        SpeakOffFriendEligibility.linkedFriends(from: friends.friends)
    }

    private var canStartSpeakOff: Bool {
        !linkedSpeakOffFriends.isEmpty
    }

    /// One captured free-text reflection — the user's own words from the
    /// deferred-capture sheets. Surfaced on the coaching card so users see
    /// that what they wrote is actually being held by the app.
    private struct CapturedReflection: Identifiable {
        let id: String
        let label: String
        let text: String
    }

    /// Pull non-empty captured reflection fields off the profile and
    /// label them for display. Order: goal → why-now → success-vision.
    private func capturedReflections(for profile: CoachingProfile) -> [CapturedReflection] {
        var out: [CapturedReflection] = []
        let goal = profile.coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines)
        if !goal.isEmpty {
            out.append(CapturedReflection(id: "goal", label: "What I'm working on", text: goal))
        }
        let why = profile.motivationWhyNow.trimmingCharacters(in: .whitespacesAndNewlines)
        if !why.isEmpty {
            out.append(CapturedReflection(id: "why", label: "Why now", text: why))
        }
        let vision = profile.successVision.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vision.isEmpty {
            out.append(CapturedReflection(id: "vision", label: "If this improves", text: vision))
        }
        return out
    }

    /// Lightweight section divider used to cluster the Profile sections
    /// into named groups (Progression / Coaching / Community). Same
    /// micro-eyebrow treatment as the rest of the app — uppercase,
    /// tracked, secondary tint — so it visually disappears into the
    /// rhythm without dominating any card below it.
    private func clusterHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.0)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    private var coachingInsight: String {
        // The generic read (unchanged) — kept verbatim so a never-chosen
        // profile still reads neutral.
        let genericRead: String
        if let plan = CoachingPlanner.plan(for: progressEligibleSessions, profile: coachingProfileStore.profile) {
            genericRead = plan.encouragement
        } else {
            genericRead = "A few more sessions will turn this into a sharper read on how you speak under pressure."
        }
        // S2: when the user has EXPLICITLY chosen a voice, lead the read with a
        // CoachPersona-derived chosen-voice line so the app visibly reflects the
        // choice. Gated on `hasChosenVoice` (via the nil-returning helper) — an
        // un-chosen profile returns nil and falls through to the generic read,
        // so it never impersonates the default `.concise` voice. Deterministic,
        // no model call.
        if let voiceLead = coachingProfileStore.profile?.chosenVoiceCoachingLead {
            return voiceLead + " " + genericRead
        }
        return genericRead
    }

    private var hasProgressEvidence: Bool {
        ratingStore.rating.hasRatedEvidence
    }

    private var defaultSurfacePlan: ProfileCompositionPlan {
        ProfileCompositionPlan.make(
            sessionCount: progressEligibleSessions.count,
            hasProgressEvidence: hasProgressEvidence
        )
    }

    private var evidenceDetailPlan: ProfileEvidenceDetailPlan {
        .valueFirst
    }

    private var coachLoopReadiness: CoachParityReadiness {
        CoachParityReadiness.build(
            memory: coachMemoryStore.currentMemory,
            sessionCount: progressEligibleSessions.count,
            recommendationOutcomeCount: recommendationLearningStore.outcomes.count,
            transferReportCount: bigMomentStore.recentOutcomeReports(limit: BigMomentStore.outcomeReportCap).count,
            checkInCount: coachCheckInStore.checkIns.count
        )
    }

    private var peerComparisonVisibility: PeerComparisonVisibility {
        PeerComparisonVisibility.make(
            members: league.members,
            currentAccountID: authManager.currentAccountID
        )
    }

    private var profileLibraryPresentation: ProfileLibraryPresentation {
        ProfileLibraryPresentation.make(
            showsPeerComparison: SocialReleaseCapabilities.peerProgress.isAvailable
                && peerComparisonVisibility.showsProfileEntry,
            isPremium: premium.isPremium
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Spacing.cardGap) {
                let surfacePlan = defaultSurfacePlan

                // Same staggered entrance Home uses (ContentView 530/569/593).
                // Profile is a persistent tab that rendered as one instant slab,
                // so switching Home → Profile was a visible drop in production
                // value inside the same app.
                //
                // Deliberately only the cards that are on screen at first
                // render. Home's stack is a plain VStack, so every card appears
                // together and the stagger reads as one entrance; this stack is
                // a LazyVStack, where `.onAppear` fires as a card is scrolled
                // into view. Tagging the lower cards would make them fade in
                // under the user's thumb mid-scroll — a different effect from
                // the one Home has, and a noisier one. `cardEntrance` caps the
                // stagger and collapses to an instant appearance under Reduce
                // Motion.
                identityHeader
                    .cardEntrance(0)

                if surfacePlan.surfaces.contains(.progressHero) {
                    compactSpeakingRatingHero
                        .cardEntrance(1)
                }

                profileCoachReadCard
                    .cardEntrance(2)

                // A due real-world check-in is part of the active coaching
                // loop, not evidence-library content. The row self-hides when
                // cadence says it is not due.
                weeklyCheckInCard

                if shouldAskTransformationQuestion {
                    transformationQuestionCard
                }

                profileEvidenceHub
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.sm)
            .padding(
                .bottom,
                Spacing.lg + (isAppTabRoot ? Spacing.tabRootNavigationClearance : 0)
            )
        }
        .task {
            bigMomentStore.archiveExpiredIfNeeded()
            await challenges.refreshFromBackend()
            await friends.refreshPeerStats()
            if ratingStore.rating.hasRatedEvidence {
                await league.refreshMembers(force: false)
            }
        }
        .background(AppColor.screenBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // V4.6 four-area IA — Settings lives under You. The gear pushes the
        // existing settings destination; the settings tab remains routable
        // for deep links only.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppDestination.settings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("profile.openSettings")
            }
        }
        .accessibilityIdentifier("profile.screen")
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(item: $profileOutcomeMoment) { moment in
            BigMomentOutcomeInlineCard(moment: moment)
                .padding()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showChallengePickFriend) {
            ChallengePickFriendSheet(friends: friends, challenges: challenges)
        }
        .sheet(isPresented: $showAddFriendManual) {
            AddFriendSheet(friends: friends, challenges: challenges)
        }
        .sheet(item: $selectedAsyncChallenge) { challenge in
            AsyncChallengeDetailSheet(challenge: challenge, challenges: challenges)
        }
        .navigationDestination(isPresented: $showAchievementsTree) {
            AchievementsTreeView()
        }
    }

    private var shouldAskTransformationQuestion: Bool {
        TransformationQuestionEligibility.shouldShow(
            sessionCount: progressEligibleSessions.count,
            events: flowEvents.events
        )
    }

    private var transformationQuestionCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Spacing.md) {
                transformationQuestionCopy
                transformationButtons
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                transformationQuestionCopy
                transformationButtons
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.transformationQuestion")
    }

    private var transformationQuestionCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Did this help outside the app?")
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            Text("Your answer shapes the next coaching step.")
                .font(Typography.captionSmall)
                .foregroundStyle(AppColor.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transformationButtons: some View {
        HStack(spacing: Spacing.xs) {
            transformationResponseButton(title: "Yes", value: "yes")
            transformationResponseButton(title: "Not yet", value: "notYet")
        }
    }

    private func transformationResponseButton(title: String, value: String) -> some View {
        Button {
            FlowEventLog.shared.log(FlowEvent.make(
                correlationId: UUID(),
                flow: .other,
                stage: "transformation.helpfulness.\(value)",
                reason: "three-plus-rep qualitative outcome response"
            ))
        } label: {
            Text(title)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .background(AppColor.cardBackground, in: Capsule())
                .overlay(
                    Capsule().stroke(AppColor.brandBlue.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Records an account-local response without transcript text.")
    }

    // MARK: - Collapsed Profile

    private var profileCoachReadCard: some View {
        let presentation = ProfileCoachBriefPresentation.make(
            sessionCount: progressEligibleSessions.count,
            plan: CoachingPlanner.plan(for: progressEligibleSessions, profile: coachingProfileStore.profile),
            memory: coachMemoryStore.currentMemory,
            trends: TrendAnalyzer.analyze(snapshots: trendStore.snapshots),
            proof: proofStore.recent(
                limit: 1,
                compatibleWith: coachingProfileStore.profile?.chosenStyleGoal
            ).first
        )

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                    .accessibilityHidden(true)
                Text("Current focus")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }

            Text(presentation.observation)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "scope")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next rep")
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                    Text(presentation.nextMove)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
            }

            if let evidenceCaption = presentation.evidenceCaption {
                Text(evidenceCaption)
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.coachRead")
    }

    private func profileTransferStatusRow(_ status: ProfileTransferStatusContent) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                profileTransferStatusSummary(status)
                transferStatusAction(status)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                profileTransferStatusSummary(status)
                transferStatusAction(status, fillsWidth: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.transferStatus")
    }

    private func profileTransferStatusSummary(_ status: ProfileTransferStatusContent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: transferStatusIcon(for: status.kind))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
                .padding(.top, 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(status.eyebrow)
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Text(status.title)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status.detail)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func transferStatusAction(_ status: ProfileTransferStatusContent, fillsWidth: Bool = false) -> some View {
        if let destination = status.destination,
           let actionTitle = status.actionTitle {
            NavigationLink(value: destination) {
                Text(actionTitle)
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
                    .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
            }
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .accessibilityIdentifier("profile.transferStatus.prep")
        } else if let moment = status.moment,
                  let actionTitle = status.actionTitle {
            Button {
                profileOutcomeMoment = moment
            } label: {
                Text(actionTitle)
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
                    .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
            }
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.transferStatus.checkIn")
        }
    }

    private func transferStatusIcon(for kind: ProfileTransferStatusKind) -> String {
        switch kind {
        case .pendingOutcome: return "arrow.uturn.left.circle.fill"
        case .activePrep: return "flag.checkered.circle.fill"
        case .transferPattern: return "chart.line.uptrend.xyaxis.circle.fill"
        case .recentOutcome: return "checkmark.seal.fill"
        case .setupTeaser: return "calendar.badge.plus"
        }
    }

    private var profileEvidenceHub: some View {
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                toggleProfileEvidence()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(width: 40, height: 40)
                        .background(AppColor.brandBlue.opacity(0.10), in: Circle())

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Library")
                            .font(Typography.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text("Evidence and history")
                            .font(Typography.captionSmall)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showProfileEvidence ? 180 : 0))
                        .animation(reduceMotion ? nil : .standardSpring, value: showProfileEvidence)
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(showProfileEvidence ? "Hide profile library" : "Show profile library")
            .accessibilityHint("Shows or hides evidence, history, and account tools.")
            .accessibilityIdentifier("profile.evidenceHub.toggle")

            if showProfileEvidence {
                VStack(spacing: 0) {
                    Divider()

                    ForEach(Array(profileLibraryPresentation.rows.enumerated()), id: \.element.rawValue) { index, row in
                        profileLibraryRow(row)
                        if index < profileLibraryPresentation.rows.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func profileLibraryRow(_ row: ProfileLibraryRow) -> some View {
        switch row {
        case .coachingEvidence:
            NavigationLink {
                ScrollView(showsIndicators: false) {
                    profileEvidenceDetails
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.vertical, Spacing.md)
                }
                .background(AppColor.screenBackground.ignoresSafeArea())
                .navigationTitle("Coaching evidence")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)
                .toolbarBackground(AppColor.screenBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            } label: {
                profileLibraryRowLabel(
                    title: "Coaching evidence",
                    subtitle: baselineMapHubSubtitle,
                    icon: "chart.bar.xaxis",
                    tint: AppColor.pro
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.evidence.baselineMap.row")

        case .growthLibrary:
            NavigationLink(value: AppDestination.growthLibrary) {
                profileLibraryRowLabel(
                    title: "Growth library",
                    subtitle: growthLibrarySubtitle,
                    icon: "quote.opening",
                    tint: AppColor.positive
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.evidence.library")

        case .coachingMemory:
            NavigationLink(value: AppDestination.coachingMemory) {
                profileLibraryRowLabel(
                    title: "Coaching memory",
                    subtitle: coachingMemoryLibrarySubtitle,
                    icon: "brain.head.profile",
                    tint: AppColor.brandBlue
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.library.coachingMemory")

        case .allReps:
            NavigationLink(value: AppDestination.sessionHistory) {
                profileLibraryRowLabel(
                    title: "All reps",
                    subtitle: historyLinkSubtitle,
                    icon: "clock.arrow.circlepath",
                    tint: AppColor.brandBlue
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.evidence.history")

        case .personalBests:
            NavigationLink(destination: PeakRatingWallView()) {
                profileLibraryRowLabel(
                    title: "Personal bests",
                    subtitle: "Your strongest verified results",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: AppColor.brandBlue
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.peakRatingWall.link")

        case .friends:
            NavigationLink(value: AppDestination.friendLeaderboard) {
                profileLibraryRowLabel(
                    title: "Friends",
                    subtitle: friends.friendCount == 0
                        ? "Add a friend when you want to practice together"
                        : "\(friends.friendCount) connected",
                    icon: "person.2.fill",
                    tint: AppColor.positive
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.friendLeaderboard")

        case .achievements:
            Button {
                showAchievementsTree = true
            } label: {
                profileLibraryRowLabel(
                    title: "Practice milestones",
                    subtitle: achievementsSummarySubtitle(
                        unlocked: unlockedAchievements.count,
                        total: retentionSnapshot.achievements.count
                    ),
                    icon: "checkmark.circle",
                    tint: AppColor.brandBlue
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.library.achievements")

        case .peerComparison:
            NavigationLink(value: AppDestination.league) {
                profileLibraryRowLabel(
                    title: "Peer comparison",
                    subtitle: peerComparisonSubtitle,
                    icon: "person.2.wave.2.fill",
                    tint: leagueTierTint
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.library.peerComparison")

        case .upgrade:
            Button {
                showPaywall = true
            } label: {
                profileLibraryRowLabel(
                    title: "Explore Noum Pro",
                    subtitle: "Deeper coaching and review tools",
                    icon: "crown.fill",
                    tint: AppColor.pro
                )
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.upgradeCTA")
        }
    }

    private func profileLibraryRowLabel(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var peerComparisonSubtitle: String {
        guard case let .available(peerCount) = peerComparisonVisibility else {
            return "Appears when another speaker is available"
        }
        return peerCount == 1 ? "Compare with one active peer" : "Compare with \(peerCount) active peers"
    }

    private var coachingMemoryLibrarySubtitle: String {
        guard let memory = coachMemoryStore.currentMemory else {
            return "Context Noum can use across reps"
        }
        if let lever = memory.currentLever {
            return "Current lever · \(lever.displayName)"
        }
        return "Goal and preferences you have shared"
    }

    private var baselineCoachMap: BaselineCoachMap {
        BaselineCoachMap.make(
            baseline: baselineStore.baseline,
            profile: coachingProfileStore.profile
        )
    }

    private var baselineMapHubSubtitle: String {
        let map = baselineCoachMap
        if let gap = map.goalGap {
            return "\(map.statusTitle) · \(gap.summary)"
        }
        if map.formationProgress < 1 {
            return "\(map.statusTitle) · \(map.qualifyingSessionCount)/\(BaselineCoachMap.establishedRepTarget) reps"
        }
        return "\(map.statusTitle) · \(map.measuredDimensionCount) coach reads"
    }

    private func toggleProfileEvidence() {
        if reduceMotion {
            showProfileEvidence.toggle()
        } else {
            withAnimation(.standardSpring) {
                showProfileEvidence.toggle()
            }
        }
    }

    private func toggleCoachReadEvidence() {
        if reduceMotion {
            showCoachReadEvidence.toggle()
        } else {
            withAnimation(.standardSpring) {
                showCoachReadEvidence.toggle()
            }
        }
    }

    private func toggleRatingEvidence() {
        if reduceMotion {
            showRatingEvidence.toggle()
        } else {
            withAnimation(.standardSpring) {
                showRatingEvidence.toggle()
            }
        }
    }

    private func toggleProgressionEvidence() {
        if reduceMotion {
            showProgressionEvidence.toggle()
        } else {
            withAnimation(.standardSpring) {
                showProgressionEvidence.toggle()
            }
        }
    }

    private func profileEvidenceLink(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        destination: AppDestination,
        identifier: String
    ) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 12)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func profileEvidenceLink(for link: ProfileEvidenceHubLink) -> some View {
        switch link {
        case .baselineMap:
            profileEvidenceActionRow(
                title: "Baseline readout",
                subtitle: baselineMapHubSubtitle,
                icon: "chart.bar.xaxis",
                tint: AppColor.pro,
                identifier: "profile.evidence.baselineMap.row"
            )
        case .growthLibrary:
            profileEvidenceLink(
                title: "Growth library",
                subtitle: growthLibrarySubtitle,
                icon: "quote.opening",
                tint: AppColor.positive,
                destination: .growthLibrary,
                identifier: "profile.evidence.library"
            )
        case .history:
            profileEvidenceLink(
                title: "History",
                subtitle: historyLinkSubtitle,
                icon: "clock.arrow.circlepath",
                tint: .secondary,
                destination: .sessionHistory,
                identifier: "profile.evidence.history"
            )
        }
    }

    private func profileEvidenceActionRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        identifier: String
    ) -> some View {
        Button {
            toggleProfileEvidence()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(showProfileEvidence ? 180 : 0))
                    .animation(reduceMotion ? nil : .standardSpring, value: showProfileEvidence)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 12)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showProfileEvidence ? "Hide baseline readout" : "Show baseline readout")
        .accessibilityHint("Shows the baseline readout, goal gap, and supporting coaching evidence.")
        .accessibilityIdentifier(identifier)
    }

    private var historyLinkSubtitle: String {
        if sessions.isEmpty { return "Saved reps appear here" }
        let noun = sessions.count == 1 ? "saved rep" : "saved reps"
        return "\(sessions.count) \(noun) · trends over time"
    }

    private var growthLibrarySubtitle: String {
        let count = compatibleProofRecords.count
        if count == 0 { return "Proof moments appear after reps" }
        // Proof role (progression spine): verified quotes are the evidence
        // BEHIND the rating — an inventory, never a progress currency.
        // Future-tense before any rated evidence exists.
        return LedgerRoleLines.proofRole(
            count: count,
            hasRatedEvidence: ratingStore.rating.hasRatedEvidence
        )
    }

    private var compatibleProofRecords: [ProofMomentRecord] {
        proofStore.compatibleRecords(
            with: coachingProfileStore.profile?.chosenStyleGoal
        )
    }

    private var profileEvidenceDetails: some View {
        let plan = evidenceDetailPlan
        return VStack(spacing: Spacing.cardGap) {
            profileCoachReadCard

            evidenceDisclosure(
                title: "Why this focus",
                subtitle: "Baseline and repeated patterns",
                systemImage: "doc.text.magnifyingglass",
                identifier: "profile.evidence.whyPlan.toggle",
                isExpanded: showCoachReadEvidence,
                action: toggleCoachReadEvidence
            ) {
                VStack(spacing: Spacing.cardGap) {
                    if plan.surfaces.contains(.baselineMap) {
                        baselineMapCard
                    }
                    if plan.surfaces.contains(.coachingDirection) {
                        coachingDirectionCard
                    }
                    if plan.surfaces.contains(.coachLoopReadiness) {
                        coachLoopReadinessCard
                    }
                    if plan.surfaces.contains(.caseReview) {
                        caseReviewCard
                    }
                    if plan.surfaces.contains(.deliveryProfile) {
                        deliveryProfileCard
                    }
                    if plan.surfaces.contains(.speechPatterns) {
                        speechPatternsCard
                    }
                }
            }

            evidenceDisclosure(
                title: "Progress over time",
                subtitle: "Rating, practice, and pressure records",
                systemImage: "chart.xyaxis.line",
                identifier: "profile.evidence.progress.toggle",
                isExpanded: showProgressionEvidence,
                action: toggleProgressionEvidence
            ) {
                VStack(spacing: Spacing.cardGap) {
                    if plan.surfaces.contains(.ratingTrajectory) {
                        ProgressionChartsCard(sessionStore: sessionStore)
                            .accessibilityIdentifier("profile.evidence.ratingTrajectory")
                    }
                    if plan.surfaces.contains(.rankProgress) {
                        rankPanel
                    }
                    if plan.surfaces.contains(.insightsBanked) {
                        insightsBankedChip
                    }
                    if plan.surfaces.contains(.pressureHistoryShare) {
                        suddenDeathHistoryShareRow
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.evidenceDetails")
    }

    private func evidenceDisclosure<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        identifier: String,
        isExpanded: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button(action: action) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(width: 38, height: 38)
                        .background(AppColor.brandBlue.opacity(0.09), in: Circle())

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(title)
                            .font(Typography.cardLabel)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(AppColor.subtleBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(isExpanded ? "Hide \(title)" : "Show \(title)")
            .accessibilityIdentifier(identifier)

            if isExpanded {
                content()
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var baselineMapCard: some View {
        BaselineMapCard(
            map: baselineCoachMap
        )
        .accessibilityIdentifier("profile.evidence.baselineMap")
    }

    // MARK: - Identity Header

    private var identityHeader: some View {
        let identity = ProfileIdentityPresentation.make(profile: coachingProfileStore.profile)
        let chosenVoice = coachingProfileStore.profile?.chosenStyleGoal
        // One icon only — the voice target's small glyph beside the subtitle.
        // The former 52pt leading tile duplicated it and added no meaning.
        return HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(Typography.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if premium.isPremium {
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColor.pro, in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    if let chosenVoice {
                        VoiceGoalIcon(goal: chosenVoice, size: 12)
                    }

                    Text(identity.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    /// Quiet secondary row shown after the coaching value, never a second hero.
    private var upgradeCTA: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "crown.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                    .frame(width: 36, height: 36)
                    .background(AppColor.pro.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Explore Noum Pro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Deeper coaching and review tools")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(AppColor.subtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("profile.upgradeCTA")
    }

    // MARK: - Practice volume (XP)
    //
    // Quiet volume row (progression spine): XP is deliberate-practice
    // VOLUME, never a skill identity — no "Speaker N" titles, no tier
    // descriptors. The rating trajectory above answers "am I getting
    // better?"; this row only answers "how much have I practiced?".
    private var rankPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                Text("Practice volume")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.0)
                Spacer()
            }

            Text(PracticeVolumeNarration.title(forXP: profile.xp))
                .font(Typography.headline)
                .foregroundStyle(.primary)

            // settleCue: earned XP is the one bar that may tick when its
            // fill lands after a live increase (A2 count-settle).
            ShimmerProgressBar(progress: profile.progressTowardsNextLevel, tint: AppColor.brandBlue, settleCue: true)

            Text(PracticeVolumeNarration.detailLine(forXP: profile.xp))
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .standardSpring, value: profile.xp)
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Practice volume. \(PracticeVolumeNarration.title(forXP: profile.xp)). \(PracticeVolumeNarration.detailLine(forXP: profile.xp))")
        .accessibilityIdentifier("profile.evidence.rankProgress")
    }

    // MARK: - Speaking Rating

    private var compactSpeakingRatingHero: some View {
        let presentation = ProfileRatingHeroPresentation.make(rating: ratingStore.rating)
        return HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .accessibilityHidden(true)
                Text("Speaking rating")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                }

                Text(presentation.directionLine)
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(presentation.value)")
                .font(Typography.figtreeNumeric(size: 36, relativeTo: .largeTitle))
                .foregroundStyle(AppColor.textPrimary)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Speaking rating \(presentation.value). \(presentation.directionLine)")
        .accessibilityIdentifier("profile.rating.hero")
    }

    @ViewBuilder
    private var speakingRatingCard: some View {
        let rating = ratingStore.rating
        let baseline = baselineStore.baseline
        // Earned motion only (Iteration 7): the numeric roll animates solely
        // on an upward tick to a new weekly best. Drops, sideways churn and
        // first paint snap silently — never punish-shame, never decorate.
        let animateRatingTick = !reduceMotion && ProfileRatingTickMotion.shouldAnimateTick(
            previous: lastSeenOverallRating,
            rating: rating
        )
        let pbs = rating.personalBests.filter { $0.value > 0 }
        let resolvedLine = ProfileResolvedWeaknessLine.make(
            trends: TrendAnalyzer.analyze(snapshots: trendStore.snapshots)
        )
        // Frosted tray renders only with real content — a thin-data user
        // gets the hero numbers alone, never an empty white shell.
        let hasTrayContent = rating.totalRatedSessions > 0 || !pbs.isEmpty
            || !baseline.topStrengths.isEmpty || !baseline.persistentBlockers.isEmpty
            || resolvedLine != nil

        if rating.totalRatedSessions > 0 || baseline.overallConfidence >= .tentative {
            VStack(alignment: .leading, spacing: 16) {
                // Header — white-on-gradient (progress hero register)
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Speaking Rating")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .textCase(.uppercase)
                    Spacer()
                }

                if rating.totalRatedSessions > 0 {
                    // Rating display
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(rating.overall)")
                                .font(Typography.figtreeNumeric(size: 44, relativeTo: .largeTitle))
                                .foregroundStyle(.white)
                                .contentTransition(animateRatingTick ? .numericText() : .identity)
                                .animation(animateRatingTick ? .standardSpring : nil, value: rating.overall)
                            // Upward week: earned glass chip. Down week:
                            // quiet plain line — honest, never decorated.
                            if rating.weeklyDelta > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrowtriangle.up.fill")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("+\(rating.weeklyDelta) this week")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.16), in: Capsule())
                                .scaleEffect(weeklyDeltaChipScale)
                                .opacity(weeklyDeltaChipScale < 1 ? 0 : 1)
                                // Pops once alongside the earned numeric roll:
                                // `animateRatingTick` flips true only on an
                                // upward tick to a new weekly best (and never
                                // under Reduce Motion), so the chip's beat is
                                // gated by the exact same honesty predicate.
                                .onChange(of: animateRatingTick) { _, isTicking in
                                    guard isTicking else { return }
                                    // Seed the collapsed scale in its own
                                    // pass so the pop has a real start frame
                                    // — a same-pass animated write coalesces
                                    // into a no-op.
                                    weeklyDeltaChipScale = 0.6
                                    DispatchQueue.main.async {
                                        withAnimation(.statDelta) { weeklyDeltaChipScale = 1.0 }
                                    }
                                }
                            } else if rating.weeklyDelta < 0 {
                                Text("\(rating.weeklyDelta) this week")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Peak: \(rating.peakRating)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Text("\(rating.totalRatedSessions) rated sessions")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }

                // Evidence tray — chart + honest sub-rows ride a frosted
                // white surface so their tinted semantics stay legible on
                // the gradient.
                if hasTrayContent {
                    Button {
                        toggleRatingEvidence()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(showRatingEvidence ? "Hide rating details" : "Rating details")
                                .font(Typography.caption.weight(.semibold))
                            Spacer(minLength: Spacing.xs)
                            Image(systemName: "chevron.down")
                                .font(Typography.captionSmall.weight(.bold))
                                .rotationEffect(.degrees(showRatingEvidence ? 180 : 0))
                                .animation(reduceMotion ? nil : .standardSpring, value: showRatingEvidence)
                        }
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(showRatingEvidence ? "Hide speaking rating details" : "Show speaking rating details")
                    .accessibilityIdentifier("profile.rating.detailsToggle")

                    if showRatingEvidence {
                        VStack(alignment: .leading, spacing: 16) {
                if rating.totalRatedSessions > 0 {
                    // Rating history chart — last 30 days, smoothed line
                    // with peak marker.
                    RatingHistoryChart(
                        history: rating.ratingHistory,
                        peakRating: rating.peakRating,
                        trend: rating.currentTrend
                    )
                }

                // Personal Bests
                if !pbs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Personal Bests")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                            ForEach(pbs, id: \.category) { pb in
                                HStack(spacing: 8) {
                                    Image(systemName: RatingEngine.pbIcon(pb.category))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.orange)
                                        .frame(width: 28, height: 28)
                                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(RatingEngine.pbTitle(pb.category))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text(RatingEngine.formatPB(pb))
                                            .font(.caption.weight(.bold))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                // Baseline strengths
                if !baseline.topStrengths.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColor.positive)
                        Text("Strengths: \(baseline.topStrengths.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Persistent blockers
                if !baseline.persistentBlockers.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColor.caution)
                        Text("Current focus: \(baseline.persistentBlockers.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Recently-resolved weakness — the earned "fill + settle"
                // moment (Iteration 7). Renders only when a tracked skill
                // flipped to `.resolved` with real confidence; the checkmark
                // gets ONE discrete bounce (skipped under Reduce Motion).
                // Slipping skills get no mirror-image row — drops stay in
                // the case file, silently.
                if let resolvedLine {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColor.positive)
                            .symbolEffect(.bounce, options: .nonRepeating, value: resolvedSettleTick)
                        Text(resolvedLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(resolvedLine)
                    .accessibilityIdentifier("profile.rating.resolvedWeakness")
                    .onAppear {
                        guard !reduceMotion else { return }
                        resolvedSettleTick.toggle()
                    }
                }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(20)
            // Progress hero — the ONE vibrant surface on Profile
            // (docs/UX_VISUAL_DIRECTION.md): blue→green gradient, the
            // believable number in white, evidence on a frosted tray.
            .background(HeroGradient.progress.gradient, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .shadow(color: HeroGradient.progress.shadowTint.opacity(0.18), radius: 12, x: 0, y: 6)
            .onAppear { lastSeenOverallRating = rating.overall }
            .onChange(of: rating.overall) { _, newValue in
                lastSeenOverallRating = newValue
            }
        }
    }

    /// M16: slim entry-link card that pushes `PeakRatingWallView`.
    /// Sits directly under `speakingRatingCard` so the user can drill
    /// from "your current rating" into "where you peak" without leaving
    /// the rating ambient. Hidden until the user has at least one rated
    /// session — VISION bans surfacing empty comparisons.
    @ViewBuilder
    private var peakRatingWallLink: some View {
        if ratingStore.rating.totalRatedSessions > 0 {
            NavigationLink(destination: PeakRatingWallView()) {
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(AppColor.brandBlue.opacity(0.14))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColor.brandBlue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("See your peak wall")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Best this week, best ever, and your peer comparison.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.xs)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.peakRatingWall.link")
        }
    }

    /// M15 Phase 5: "Insights banked" — quiet chip that mirrors the
    /// strengths / working-on row register (icon + caption text). Counts
    /// the persisted proof-moment records and surfaces the most-recent
    /// session's relative age. Hidden entirely when the archive is empty
    /// so we never render "0 insights" or a "you lost your streak" prompt
    /// — VISION.md bans the streak-and-badge loop.
    @ViewBuilder
    private var insightsBankedChip: some View {
        let count = compatibleProofRecords.count
        if count > 0 {
            let noun = count == 1 ? "insight" : "insights"
            NavigationLink(value: AppDestination.growthLibrary) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.caption2)
                        .foregroundStyle(AppColor.pro)
                    Text("\(count) \(noun) banked")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let recency = mostRecentInsightRecency {
                        Text("\u{00B7} Most recent: \(recency)")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(insightsAccessibilityLabel(count: count))
            .accessibilityHint("Opens your growth library.")
            .accessibilityIdentifier("profile.insightsBanked.link")
        }
    }

    // MARK: - Pressure Drill history share
    //
    // Quiet ShareLink row in the Progression cluster. Surfaces the
    // user's full Pressure Drill track record as a plain-text snapshot
    // they can paste anywhere — Notes, Messages, an email thread.
    // Mirrors the SD Result-screen share affordance so the same
    // helper (`SuddenDeathHistoryExport.formatPlainText(runs:)`)
    // backs both surfaces; the user can reach the export from either
    // post-rep or post-hoc.
    //
    // Self-hides when there are no SD runs yet (cold start), so a
    // user who hasn't touched Pressure Drill sees nothing — the row
    // appears the moment they have something to share.
    //
    // Restraint: this is a single quiet row, not a card. The
    // Achievements panel sits directly below as the visual hero of
    // the section; this row is a small affordance that reads as a
    // utility tail. Mirrors the "insightsBankedChip" pattern at the
    // top of the screen.
    //
    // Anti-goal compliance: the export carries zero transcript
    // content (locked by `SuddenDeathHistoryExportTests.exportNeverContainsTranscriptContent`).
    @ViewBuilder
    private var suddenDeathHistoryShareRow: some View {
        let runCount = suddenDeathRunHistoryStore.runs.count
        if runCount > 0 {
            let runLabel = runCount == 1 ? "1 run" : "\(runCount) runs"
            ShareLink(
                item: SuddenDeathHistoryExport.formatPlainText(runs: suddenDeathRunHistoryStore.runs)
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.modeSuddenDeath)
                        .frame(width: 28, height: 28)
                        .background(
                            AppColor.modeSuddenDeath.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Pressure Drill history")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(runLabel), all difficulties")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(
                    AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Share Pressure Drill history — \(runLabel)")
            .accessibilityHint("Shares your Pressure Drill history across every difficulty.")
            .accessibilityIdentifier("profile.suddenDeath.historyShare")
        }
    }

    /// Human phrasing for the most-recent proof's age. Whole-day
    /// granularity to match `SummaryView` / `HomeCoachCard` recency idiom.
    /// Returns nil when the archive is empty (caller already guards).
    private var mostRecentInsightRecency: String? {
        guard let mostRecent = proofStore.recent(
            limit: 1,
            compatibleWith: coachingProfileStore.profile?.chosenStyleGoal
        ).first?.proof.sessionDate else {
            return nil
        }
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: mostRecent),
            to: cal.startOfDay(for: Date())
        ).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "1d ago"
        default: return "\(days)d ago"
        }
    }

    private func insightsAccessibilityLabel(count: Int) -> String {
        // Proof role narration — names what the banked lines ARE (evidence
        // behind the rating), not just a count. Future-tense pre-evidence.
        let role = LedgerRoleLines.proofRole(
            count: count,
            hasRatedEvidence: ratingStore.rating.hasRatedEvidence
        )
        if let recency = mostRecentInsightRecency {
            return "\(role) Most recent \(recency)."
        }
        return role
    }

    private func trendIcon(_ trend: TrendDirection) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .newIssue: return "exclamationmark.circle"
        case .resolved: return "checkmark.circle"
        }
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving, .resolved: return AppColor.positive
        case .stable: return .secondary
        case .declining, .newIssue: return AppColor.caution
        }
    }

    private func trendLabel(_ trend: TrendDirection) -> String {
        RatingTrendCopy.label(for: trend)
    }

    // MARK: - League

    /// Tappable summary of the user's current league tier. Real peer ranking
    /// lives in `LeagueView` — this card is a low-noise entry point that
    /// surfaces tier + rating headroom + reset countdown without filling
    /// the profile with a full leaderboard.
    private var leaguePanel: some View {
        NavigationLink(value: AppDestination.league) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(leagueTierTint.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: "rosette")
                        .font(Typography.headline)
                        .foregroundStyle(leagueTierTint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(LeaguePlacementPresentation.title(tier: league.tier, rating: ratingStore.rating))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(leagueSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(league.resetCopy)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("profile.league")
    }

    private var leagueSubtitle: String {
        LeaguePlacementPresentation.subtitle(tier: league.tier, rating: ratingStore.rating)
    }

    private var leagueTierTint: Color {
        ratingStore.rating.hasRatedEvidence ? league.tier.tint : AppColor.brandBlue
    }

    private var communityPracticeRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.teal)
                    .frame(width: 36, height: 36)
                    .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Community practice")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(communityPracticeSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                Button {
                    presentSpeakOffPickerIfAvailable()
                } label: {
                    Label("Challenge", systemImage: "bolt.fill")
                        .font(Typography.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .disabled(!canStartSpeakOff)
                .opacity(canStartSpeakOff ? 1 : 0.45)
                .buttonStyle(.bordered)
                .tint(.teal)
                .accessibilityIdentifier("profile.community.challenge")

                Button {
                    showAddFriendManual = true
                } label: {
                    Label("Add friend", systemImage: "plus")
                        .font(Typography.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(AppColor.brandBlue)
                .accessibilityIdentifier("profile.community.addFriend")
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var communityPracticeSubtitle: String {
        if canStartSpeakOff {
            return "\(linkedSpeakOffFriends.count) linked friend\(linkedSpeakOffFriends.count == 1 ? "" : "s") ready for scored reps."
        }
        if friends.friends.isEmpty {
            return "Add a friend when you want scored practice with someone else."
        }
        return SpeakOffConnectionCopy.unlinkedFriendsNotice
    }

    // MARK: - Coaching Direction

    private var coachingDirectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coaching Direction")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            if let profile = coachingProfileStore.profile {
                // M14: visualise the same distance-from-goal metric that
                // anchors the pre-rep VoiceAnchorBanner, biases the mid-rep
                // LiveEloquenceHUD, and frames the post-rep Coach Note
                // momentum. The user reads one proximity number end-to-end
                // instead of just "Getting closer" text.
                VStack(alignment: .leading, spacing: 10) {
                    Text(profile.displayableGoal)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    GoalProgressView(
                        goal: profile.primaryGoal,
                        baseline: baselineStore.baseline,
                        snapshots: trendStore.snapshots
                    )

                    if let read = GoalOutcomeEngine.read(
                        profile: profile,
                        baseline: baselineStore.baseline,
                        rating: ratingStore.rating,
                        sessions: progressEligibleSessions,
                        coachMemory: coachMemoryStore.currentMemory,
                        outcomes: recommendationLearningStore.outcomes
                    ) {
                        GoalOutcomeCard(read: read)
                    }
                }

                // M14: surface the user's own captured reflection text so
                // they see that what they wrote in the deferred-capture
                // sheets ("What do you want to get better at?", "Why
                // does this matter right now?", "If this improves, what
                // changes?") is actually being held by the app.
                let reflections = capturedReflections(for: profile)
                if !reflections.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("In your own words")
                            .font(Typography.micro)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        ForEach(reflections) { reflection in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "quote.opening")
                                    .font(Typography.captionSmall.weight(.bold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reflection.label)
                                        .font(Typography.micro.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .tracking(0.6)
                                    Text(reflection.text)
                                        .font(Typography.caption)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Text(coachingInsight)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // M20: Forward Plan surface — quietly hidden until the user
            // has ≥3 sessions (no plan to read on cold-start data), then
            // promotes a pre-prompt CTA, then renders the live week +
            // progress once a plan exists. The card itself is a button
            // → Ask Noum so the program lives in the chat thread where
            // the user can scroll back to the full 4-week breakdown.
            coachingPlanCard

            // M14: third Ask Noum entry point — Profile sits where the
            // user reads their goal + progress + reflections, so the
            // contextual "talk to your coach about this" handoff lives
            // here too. Brand-purple register mirrors the home promo
            // and summary bridge; the link is restrained on purpose
            // (no card, no glyph) so it reads as a quiet handoff, not
            // a second hero competing with the goal ring above.
            if coachingProfileStore.profile != nil,
               case .hidden = coachingPlanState {
                askNoumProfileLink
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .accessibilityIdentifier("profile.evidence.coachingDirection")
    }

    @ViewBuilder
    private var coachLoopReadinessCard: some View {
        if let content = ProfileCoachLoopReadinessContent.make(readiness: coachLoopReadiness) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(Typography.caption.weight(.bold))
                        .foregroundStyle(AppColor.pro)
                    Text("How your plan is learning")
                        .font(Typography.micro.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }

                Text(content.title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(content.detail)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let nextTitle = content.nextTitle,
                   let nextDetail = content.nextDetail {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextTitle)
                            .font(Typography.captionSmall.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(nextDetail)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }

                Text(content.validationLine)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.evidence.coachLoop")
        }
    }

    /// Compact read-only surface for the coaching case file — the
    /// coach's working hypothesis, active intervention, adaptation log,
    /// and momentum signals. Only shown when the coach has at least a
    /// tentative evidence base (≥3 sessions). Shows nothing on cold
    /// start so Profile never over-promises on thin data.
    @ViewBuilder
    private var caseReviewCard: some View {
        if let memory = coachMemoryStore.currentMemory,
           memory.evidenceConfidence >= .tentative {
            // S2: pass the coaching profile so the card can render a chosen-voice
            // register eyebrow when the user has picked a voice. Additive +
            // defaulted nil on `CaseReviewCard`, so previews/other call sites are
            // unaffected; a nil/unchosen profile renders exactly as before.
            CaseReviewCard(
                memory: memory,
                profile: coachingProfileStore.profile,
                // F4a: wire the card's acknowledgement chips to the SAME durable
                // path AskNoum uses. noteHypothesisAcknowledgement updates the
                // @Published currentMemory, so this view re-renders and the card
                // swaps the chips for the quiet acknowledged echo.
                onAcknowledge: { confidence in
                    coachMemoryStore.noteHypothesisAcknowledgement(confidence)
                }
            )
            .accessibilityIdentifier("profile.evidence.caseReview")
        }
    }

    /// F3: the user-facing delivery profile ("how you come across"). Reads the
    /// durable `CoachMemory.deliveryProfile`, computed in `CoachMemory.build`
    /// from the same engines the coach context uses. Self-hides when the profile
    /// is nil (nothing has earned a line yet), so Profile never over-promises.
    @ViewBuilder
    private var deliveryProfileCard: some View {
        if let profile = coachMemoryStore.currentMemory?.deliveryProfile {
            DeliveryProfileCard(profile: profile)
                .accessibilityIdentifier("profile.evidence.deliveryProfile")
        }
    }

    /// F1: the weekly coach check-in prompt. Renders only when the no-nag
    /// cadence is due (the card self-guards too); hidden otherwise so Profile
    /// never nags. Saving records a CoachCheckIn that feeds the coach context.
    @ViewBuilder
    private var weeklyCheckInCard: some View {
        WeeklyCheckInCard(store: coachCheckInStore)
    }

    /// M20: Forward Plan card inside the Coaching Direction card. Pure
    /// resolver decides which state to render — see
    /// `CoachingPlanCardVisibility` for the four-state contract.
    ///
    /// Tap behavior depends on state:
    ///   • `.prompt` / `.stale` → trigger plan generation, then open
    ///     Ask Noum. The generation injects a coach-voice rendering of
    ///     the plan as a fresh coach turn so the user lands inside an
    ///     already-written program rather than waiting for a reply.
    ///   • `.live` → just open Ask Noum (the program is already in the
    ///     thread; the user is navigating back to it).
    private var coachingPlanCard: some View {
        let state = coachingPlanState
        return CoachingPlanCard(
            state: state,
            voice: coachingProfileStore.profile?.chosenStyleGoal,
            transferReceipt: CoachingPlanCardVisibility.transferAdaptationReceipt(
                plan: forwardPlanStore.activePlan,
                activeMoment: bigMomentStore.activeMoment,
                reports: bigMomentStore.outcomeReports
            ),
            onTap: {
                let triggersGeneration: Bool
                switch state {
                case .prompt, .stale: triggersGeneration = true
                case .live, .hidden:  triggersGeneration = false
                }
                if triggersGeneration {
                    Task {
                        await ForwardPlanCoordinator.generateAndAnnounce()
                    }
                }
                if let url = URL(string: "noum://ask") {
                    openURL(url)
                }
            }
        )
    }

    private var coachingPlanState: CoachingPlanCardState {
        CoachingPlanCardVisibility.resolve(
            plan: forwardPlanStore.activePlan,
            profile: coachingProfileStore.profile,
            sessions: progressEligibleSessions,
            activeBigMomentID: bigMomentStore.activeMoment?.id
        )
    }

    /// Restrained voice-shaped Ask Noum handoff inside the Coaching
    /// Direction card. Opens `noum://ask` so the existing DeepLinkRouter
    /// pathway owns the navigation (no path-binding into Profile needed).
    private var askNoumProfileLink: some View {
        let voice = coachingProfileStore.profile?.chosenStyleGoal
        let label = askNoumProfileLabel(for: voice)
        return Button {
            if let url = URL(string: "noum://ask") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.pro)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.pro)
            }
            .padding(.top, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(label). Opens the Ask Noum thread."))
        .accessibilityIdentifier("profile.askNoumLink")
    }

    /// Voice-shaped Ask Noum handoff copy for the Profile coaching card.
    /// Mirrors the `askCoachBridgeHeadline` / `askNoumPromoHeadline`
    /// catalogues so all three coach entry points sound like the same
    /// voice. Phrasing is ambient ("about your goal", "what to drill
    /// next") because Profile isn't anchored to a specific rep.
    private func askNoumProfileLabel(for _: SpeakingStyleGoal?) -> String {
        "Ask Noum"
    }

    // MARK: - Active Challenge

    private var activeChallengePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Challenge")
                .font(.title3.weight(.bold))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(Typography.cardLabel)
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
            }

            Text(retentionSnapshot.motivationLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .accessibilityIdentifier("profile.evidence.activeChallenge")
    }

    // MARK: - Achievements (Compact Preview)

    private var achievementsSummaryRow: some View {
        let allStatuses = retentionSnapshot.achievements
        let unlockedCount = unlockedAchievements.count
        let totalCount = allStatuses.count

        return Button {
            showAchievementsTree = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "seal.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                    .frame(width: 36, height: 36)
                    .background(AppColor.pro.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Practice milestones")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(achievementsSummarySubtitle(unlocked: unlockedCount, total: totalCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(totalCount == 0 ? "Pending" : "\(unlockedCount)/\(totalCount)")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.achievements.summary")
    }

    private func achievementsSummarySubtitle(unlocked: Int, total: Int) -> String {
        if total == 0 {
            return "Complete a rep to begin your milestone record."
        }
        if unlocked == 0 {
            return "Small markers of consistent practice."
        }
        return "\(unlocked) of \(total) reached through real practice."
    }

    private var achievementsPanel: some View {
        let allStatuses = retentionSnapshot.achievements
        let previewTiers = achievementPreviewTiers(from: allStatuses)
        // NEW = from the last session's unlocks AND within 24h
        let newlyUnlockedIDs = Set(AchievementStore.shared.newlyUnlocked)
        let newCutoff = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()

        return VStack(alignment: .leading, spacing: 14) {
            // Header row — entire card taps to open achievements
            HStack(alignment: .firstTextBaseline) {
                Text("Achievements")
                    .font(.title3.weight(.bold))
                Spacer()
                HStack(spacing: 4) {
                    Text("\(unlockedAchievements.count)/\(allStatuses.count)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            if allStatuses.isEmpty {
                Text("Complete your first session to start earning achievements.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // 4-badge preview row
                HStack(spacing: 0) {
                    ForEach(Array(previewTiers.enumerated()), id: \.element.id) { index, tier in
                        let status = allStatuses.first { $0.id == tier.id }
                        let isUnlocked = status?.isUnlocked ?? false
                        // Only the single most recent NEW badge gets the chip
                        let isNew = index == 0
                            && newlyUnlockedIDs.contains(tier.id)
                            && (AchievementStore.shared.unlocks[tier.id] ?? .distantPast) > newCutoff

                        VStack(spacing: 5) {
                            ZStack(alignment: .topTrailing) {
                                AchievementIconView(
                                    tier: tier,
                                    isUnlocked: isUnlocked,
                                    progress: status?.progress ?? 0,
                                    size: .grid
                                )
                                .frame(width: 48, height: 48)

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
                                .font(.system(size: 8.5, weight: isUnlocked ? .semibold : .medium))
                                .foregroundStyle(isUnlocked ? Color.primary : Color.secondary.opacity(0.5))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { showAchievementsTree = true }
    }

    /// Up to 4 preview tiers: most recent unlocks first, then easiest locked ones to fill to 4.
    private func achievementPreviewTiers(from allStatuses: [PracticeAchievementStatus]) -> [AchievementTier] {
        let unlockDates = AchievementStore.shared.unlocks
        // Recent unlocks sorted by date descending
        let recentUnlocked = AchievementStore.allTiers
            .filter { unlockDates[$0.id] != nil }
            .sorted { (unlockDates[$0.id] ?? .distantPast) > (unlockDates[$1.id] ?? .distantPast) }

        if recentUnlocked.count >= 4 {
            return Array(recentUnlocked.prefix(4))
        }

        // Fill remaining slots with easiest locked badges (lowest tierIndex)
        let unlockedIDs = Set(unlockDates.keys)
        let easiestLocked = AchievementStore.allTiers
            .filter { !unlockedIDs.contains($0.id) }
            .sorted { $0.tierIndex < $1.tierIndex }

        let combined = recentUnlocked + easiestLocked
        return Array(combined.prefix(4))
    }

    // MARK: - Speech Patterns Card

    private var speechPatternsCard: some View {
        let topClutch = clutchWordStore.topClutchWords.prefix(5)
        let topFillers = fillerProfile.prefix(5)
        let hasData = !topFillers.isEmpty || !topClutch.isEmpty

        return Group {
            if hasData {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Speech Patterns")
                        .font(.title3.weight(.bold))

                    // Filler word profile
                    if !topFillers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top Filler Words")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            ForEach(topFillers, id: \.word) { entry in
                                HStack(spacing: 10) {
                                    Text("\"\(entry.word)\"")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 80, alignment: .leading)

                                    GeometryReader { geo in
                                        let maxCount = topFillers.first?.count ?? 1
                                        let fraction = maxCount > 0 ? min(1.0, Double(entry.count) / Double(maxCount)) : 0
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.orange.opacity(0.2))
                                            .frame(height: 6)
                                            .overlay(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.orange)
                                                    .frame(width: geo.size.width * fraction, height: 6)
                                            }
                                    }
                                    .frame(height: 6)

                                    Text("\(entry.count)")
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                }
                            }
                        }
                    }

                    // Clutch word profile
                    if !topClutch.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Verbal Habits")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                                Text("across sessions")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(Array(topClutch), id: \.id) { entry in
                                HStack(spacing: 10) {
                                    Text("\"\(entry.word)\"")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 80, alignment: .leading)

                                    Text("\(entry.totalOccurrences)x")
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(.purple)

                                    Spacer()

                                    Text("\(entry.sessionCount) sessions")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if clutchWordStore.establishedPatterns.count >= 2 {
                                Text("These words appear frequently across your sessions. They may be unconscious habits.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
                .accessibilityIdentifier("profile.evidence.speechPatterns")
            }
        }
    }

    /// Aggregate filler evidence only across sessions allowed to strengthen
    /// coaching; Review-only captures remain visible in saved history.
    private var fillerProfile: [(word: String, count: Int)] {
        var aggregate: [String: Int] = [:]
        for session in progressEligibleSessions {
            let bd = FillerWordDetector.breakdown(
                in: session.transcript,
                customWords: clutchWordStore.customFillerWords
            )
            for (word, count) in bd.wordCounts {
                aggregate[word, default: 0] += count
            }
        }
        return aggregate.sorted { $0.value > $1.value }.map { (word: $0.key, count: $0.value) }
    }

    // MARK: - Skill Progress

    @ViewBuilder
    private var skillProgressPanel: some View {
        let trends = TrendAnalyzer.analyze(snapshots: trendStore.snapshots)
        if !trends.isEmpty {
            SkillProgressView(
                trends: trends,
                drillHistory: DrillHistoryStore.shared.entries
            )
            .accessibilityIdentifier("profile.evidence.skillProgress")
        }
    }

    // MARK: - Feedback Inbox

    private var feedbackInboxCard: some View {
        Group {
            if !feedbackManager.requests.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Feedback Requests")
                            .font(.title3.weight(.bold))
                        Spacer()
                        if feedbackManager.unreadCount > 0 {
                            Text("\(feedbackManager.unreadCount) new")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColor.brandBlue, in: Capsule())
                        }
                    }

                    ForEach(feedbackManager.requests.prefix(5)) { request in
                        // M14 fix: rows were previously a static HStack —
                        // tapping them on a real device did nothing. Wrap
                        // in a Button so users can open the report detail.
                        Button {
                            selectedFeedbackRequest = request
                        } label: {
                            feedbackRequestRow(request)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
                .accessibilityIdentifier("profile.evidence.feedbackInbox")
            }
        }
        .sheet(item: $selectedFeedbackRequest) { request in
            FeedbackRequestDetailSheet(request: request)
        }
    }

    private func feedbackRequestRow(_ request: StoredFeedbackRequest) -> some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(feedbackStatusColor(request.status).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: feedbackStatusIcon(request.status))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(feedbackStatusColor(request.status))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("To \(request.recipientName)")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text(request.mode.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("Score: \(request.score)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !request.responses.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(request.responses.count) response\(request.responses.count == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.brandBlue)
                    }
                }
            }

            Spacer()

            Text(request.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func feedbackStatusColor(_ status: FeedbackRequestStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .responded: return AppColor.brandBlue
        case .archived: return .secondary
        }
    }

    private func feedbackStatusIcon(_ status: FeedbackRequestStatus) -> String {
        switch status {
        case .pending: return "clock.fill"
        case .responded: return "text.bubble.fill"
        case .archived: return "archivebox.fill"
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Spacing.sm) {
            statCard(title: "Sessions", value: "\(totalProgressSessions)", icon: "mic.fill", tint: AppColor.brandBlue)
            statCard(title: "Streak", value: "\(currentStreak)d", icon: "flame.fill", tint: .orange)
            statCard(title: "Friends", value: "\(friends.friendCount)", icon: "person.2.fill", tint: AppColor.positive)
        }
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: Spacing.xs) {
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
        .padding(.vertical, Spacing.md)
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
                    presentSpeakOffPickerIfAvailable()
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
                .disabled(!canStartSpeakOff)
                .opacity(canStartSpeakOff ? 1 : 0.45)
            }

            Text(canStartSpeakOff
                 ? "Challenge a linked friend to the same prompt. Both speak, then compare scores."
                 : "Scored speak-offs unlock when a friend is linked to a Noum account.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if hasOnlyUnlinkedFriends {
                Text(SpeakOffConnectionCopy.unlinkedFriendsNotice)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            let active = challenges.activeAsyncChallenges
            if active.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "person.2.wave.2")
                        .font(.system(.largeTitle))
                        .foregroundStyle(.secondary.opacity(0.4))

                    Text("No active speak-offs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        presentSpeakOffPickerIfAvailable()
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
                    .disabled(!canStartSpeakOff)
                    .opacity(canStartSpeakOff ? 1 : 0.45)
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
        let participantID = authManager.currentAccountID ?? ""
        let status = challenge.status(forParticipantID: participantID)
        let friendName = challenge.opponentName(forParticipantID: participantID)

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

                    if let result = challenge.result(forParticipantID: participantID) {
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

    private func presentSpeakOffPickerIfAvailable() {
        guard canStartSpeakOff else { return }
        showChallengePickFriend = true
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

            if !friends.friends.isEmpty {
                NavigationLink(value: AppDestination.friendLeaderboard) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.number")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                        Text("View leaderboard")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.friendLeaderboard")
            }

            if friends.friends.isEmpty {
                Text("No friends yet. Add a friend to start speak-offs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(friends.friends.prefix(5)) { friend in
                    friendRow(friend)
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

    private func friendRow(_ friend: NoumFriend) -> some View {
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
                createSpeakOff(with: friend)
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                    .frame(width: 30, height: 30)
                    .background(Color.teal.opacity(0.1), in: Circle())
            }
            .disabled(
                !SocialReleaseCapabilities.speakOffs.isAvailable
                    || friend.accountID == nil
                    || challenges.pendingAuthorityIntent != nil
            )
        }
    }

    private func createSpeakOff(with friend: NoumFriend) {
        guard SocialReleaseCapabilities.speakOffs.isAvailable,
              let opponentAccountID = friend.accountID else { return }
        Task {
            await challenges.createAsyncChallenge(opponentAccountID: opponentAccountID)
        }
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite Friends")
                .font(.headline)

            Text("Share Noum with someone you want to practice with.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                shareInviteLink()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                    Text("Share Noum")
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
            activityItems: ["Practice speaking with me on Noum — a gym for your voice.", URL(string: url)!],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
}

#endif
