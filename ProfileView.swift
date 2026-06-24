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
    case growthLibrary
    case history
}

struct ProfileEvidenceHubPresentation: Equatable {
    let linkOrder: [ProfileEvidenceHubLink]
    let usesCompactRows: Bool
    let showsDefaultHeader: Bool

    static let valueFirst = ProfileEvidenceHubPresentation(
        linkOrder: [.growthLibrary, .history],
        usesCompactRows: true,
        showsDefaultHeader: false
    )
}

struct BaselineMapCard: View {
    let map: BaselineCoachMap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var measuredReads: [BaselineCoachDimensionRead] {
        map.dimensions.filter(\.isMeasured)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            formationBar

            HStack(alignment: .center, spacing: Spacing.md) {
                BaselineRadarChart(reads: map.dimensions)
                    .frame(width: 150, height: 150)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(map.measuredDimensionCount) of \(map.dimensions.count) coach reads active")
                        .font(Typography.cardLabel)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(map.statusDetail)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !measuredReads.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(measuredReads.prefix(3)) { read in
                                dimensionLine(read)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

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
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.pro)
            Text("Baseline map")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text(map.confidence.label)
                .font(Typography.micro)
                .foregroundStyle(AppColor.pro)
                .textCase(.uppercase)
                .tracking(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColor.pro.opacity(0.10), in: Capsule())
        }
    }

    private var formationBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(map.statusTitle)
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(formationCountLabel)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.tagBackground)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColor.brandBlue, AppColor.pro],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * map.formationProgress))
                }
            }
            .frame(height: 8)
            .animation(reduceMotion ? nil : .standardSpring, value: map.formationProgress)
        }
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Gap to goal")
                        .font(Typography.micro)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Text(gap.summary)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.brandBlue)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColor.brandBlue.opacity(0.10))
                        Capsule()
                            .fill(AppColor.brandBlue)
                            .frame(width: max(8, proxy.size.width * gap.proximity))
                    }
                }
                .frame(height: 7)
                .animation(reduceMotion ? nil : .standardSpring, value: gap.proximity)

                Text("\(gap.currentLabel) · target: \(gap.targetLabel)")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .background(AppColor.brandBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        } else {
            Text("Goal gap appears once the underlying metric has enough reps.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
    }

    private func motivationSection(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(AppColor.pro)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("Original why")
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

    private func dimensionLine(_ read: BaselineCoachDimensionRead) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(read.confidence.isReliable ? AppColor.positive : AppColor.caution)
                .frame(width: 6, height: 6)
            Text(read.dimension.shortTitle)
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
            if let value = read.valueLabel {
                Text(value)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            "Baseline map.",
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

private struct BaselineRadarChart: View {
    let reads: [BaselineCoachDimensionRead]

    private var evidenceValues: [Double] {
        reads.map(\.evidenceProgress)
    }

    private var measuredValues: [Double]? {
        let values = reads.map { $0.currentScore }
        guard values.compactMap({ $0 }).count >= 3 else { return nil }
        return values.map { $0 ?? 0 }
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let rect = CGRect(
                x: (proxy.size.width - side) / 2,
                y: (proxy.size.height - side) / 2,
                width: side,
                height: side
            )

            ZStack {
                ForEach([0.33, 0.66, 1.0], id: \.self) { scale in
                    RadarPolygonShape(values: Array(repeating: scale, count: reads.count))
                        .stroke(Color.black.opacity(scale == 1.0 ? 0.12 : 0.07), lineWidth: 1)
                }

                ForEach(reads.indices, id: \.self) { index in
                    RadarAxisShape(index: index, count: reads.count)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }

                RadarPolygonShape(values: evidenceValues)
                    .fill(AppColor.brandBlue.opacity(0.18))
                RadarPolygonShape(values: evidenceValues)
                    .stroke(AppColor.brandBlue.opacity(0.85), lineWidth: 2)

                if let measuredValues {
                    RadarPolygonShape(values: measuredValues)
                        .fill(AppColor.pro.opacity(0.12))
                    RadarPolygonShape(values: measuredValues)
                        .stroke(AppColor.pro.opacity(0.75), lineWidth: 1.8)
                }

                ForEach(Array(reads.enumerated()), id: \.offset) { index, read in
                    Text(read.dimension.shortTitle)
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .position(labelPoint(index: index, count: reads.count, rect: rect))
                }
            }
        }
    }

    private func labelPoint(index: Int, count: Int, rect: CGRect) -> CGPoint {
        let angle = angleFor(index: index, count: count)
        let radius = min(rect.width, rect.height) * 0.47
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

private struct RadarPolygonShape: Shape {
    var values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.34
        var path = Path()
        for (index, value) in values.enumerated() {
            let angle = angleFor(index: index, count: values.count)
            let scaled = min(max(value, 0), 1)
            let point = CGPoint(
                x: center.x + cos(angle) * radius * scaled,
                y: center.y + sin(angle) * radius * scaled
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct RadarAxisShape: Shape {
    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        guard count >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.34
        let angle = angleFor(index: index, count: count)
        var path = Path()
        path.move(to: center)
        path.addLine(to: CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        ))
        return path
    }
}

private func angleFor(index: Int, count: Int) -> CGFloat {
    guard count > 0 else { return -.pi / 2 }
    return -.pi / 2 + (CGFloat(index) / CGFloat(count)) * 2 * .pi
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
            read = hypothesis
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

    private static func bounded(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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
            title = "The coaching loop is forming"
        } else {
            let noun = earned.count == 1 ? "stage has" : "stages have"
            title = "\(earned.count) coaching \(noun) solid evidence"
        }

        let detail = stageLine(prefix: "Solid", stages: earned)
            ?? stageLine(prefix: "Forming", stages: forming)
            ?? "Noum is still gathering evidence from your reps and check-ins."

        let next = coachingStages.first { $0.status == .thin }
            ?? coachingStages.first { $0.status == .forming }
        let nextTitle = next.map { "Next evidence: \($0.stage.title)" }
        let nextDetail = next?.basis

        return ProfileCoachLoopReadinessContent(
            title: title,
            detail: detail,
            nextTitle: nextTitle,
            nextDetail: nextDetail,
            validationLine: "Validation stays open outside the app; real-world outcomes over time decide whether the coaching is working."
        )
    }

    private static func stageLine(prefix: String, stages: [CoachParityReadiness.StageRead]) -> String? {
        guard !stages.isEmpty else { return nil }
        let names = stages.map(\.stage.title).prefix(3).joined(separator: ", ")
        let suffix = stages.count > 3 ? " +\(stages.count - 3) more" : ""
        return "\(prefix): \(names)\(suffix)."
    }
}

enum ProfileTransferStatusKind: Equatable {
    case pendingOutcome
    case activePrep
    case transferPattern
    case recentOutcome
}

struct ProfileTransferStatusContent: Equatable {
    let kind: ProfileTransferStatusKind
    let eyebrow: String
    let title: String
    let detail: String
    let actionTitle: String?
    let destination: AppDestination?
    let moment: BigMoment?

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
                voice: voice
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
                actionTitle: "Prep now",
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

        return nil
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

    @State private var showAchievementsTree = false
    @State private var showPaywall = false
    @State private var showProfileEvidence = false
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
            profile: coachingProfileStore.profile,
            displayedStreak: streakFreeze.currentStreak
        )
    }

    private var unlockedAchievements: [PracticeAchievementStatus] {
        retentionSnapshot.achievements.filter(\.isUnlocked)
    }

    private var totalSessions: Int { sessions.count }

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
        if let plan = CoachingPlanner.plan(for: sessions, profile: coachingProfileStore.profile) {
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
        ratingStore.rating.hasRatedEvidence || baselineStore.baseline.overallConfidence >= .tentative
    }

    private var defaultSurfacePlan: ProfileDefaultSurfacePlan {
        ProfileDefaultSurfacePlan.make(hasProgressEvidence: hasProgressEvidence)
    }

    private var evidenceDetailPlan: ProfileEvidenceDetailPlan {
        .valueFirst
    }

    private var coachLoopReadiness: CoachParityReadiness {
        CoachParityReadiness.build(
            memory: coachMemoryStore.currentMemory,
            sessionCount: sessions.count,
            recommendationOutcomeCount: recommendationLearningStore.outcomes.count,
            transferReportCount: bigMomentStore.recentOutcomeReports(limit: BigMomentStore.outcomeReportCap).count,
            checkInCount: coachCheckInStore.checkIns.count
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                let surfacePlan = defaultSurfacePlan

                identityHeader

                if surfacePlan.surfaces.contains(.progressHero) {
                    speakingRatingCard
                }

                profileCoachReadCard

                // Pro after value (owner decision): the upsell renders
                // below the believable-progress hero + coach read, never
                // above them.
                if !premium.isPremium {
                    upgradeCTA
                }

                profileEvidenceHub
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .task {
            bigMomentStore.archiveExpiredIfNeeded()
            await challenges.refreshFromBackend()
            await friends.refreshPeerStats()
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

    // MARK: - Collapsed Profile

    private var profileCoachReadCard: some View {
        let content = ProfileCoachReadContent.make(
            sessionCount: sessions.count,
            plan: CoachingPlanner.plan(for: sessions, profile: coachingProfileStore.profile),
            memory: coachMemoryStore.currentMemory,
            proof: proofStore.recent(limit: 1).first
        )
        let transferStatus = ProfileTransferStatusContent.make(
            activeMoment: bigMomentStore.activeMoment,
            pendingOutcomeMoment: bigMomentStore.pendingOutcomeCheckInMoment,
            recentOutcome: bigMomentStore.recentOutcomeReports(limit: 1).first,
            transferTrend: bigMomentStore.transferTrends(limit: 1).first,
            sessions: sessions,
            voice: coachingProfileStore.profile?.speakingStyleGoal
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                Text("Your coach")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text(content.label)
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(content.isThinEvidence ? AppColor.caution : AppColor.pro)
                    .textCase(.uppercase)
                    .tracking(0.7)
            }

            Text(content.read)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let evidenceLine = content.evidenceLine {
                Text(evidenceLine)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Evidence behind this read: \(evidenceLine)")
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.top, 3)
                Text(content.nextMove)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let proofClaim = content.proofClaim {
                VStack(alignment: .leading, spacing: 6) {
                    Text(proofClaim)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let quote = content.proofQuote {
                        Text("\"\(quote)\"")
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AppColor.pro.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(AppColor.pro.opacity(0.16), lineWidth: 1)
                )
            }

            if let transferStatus {
                Divider()
                    .padding(.vertical, 2)
                profileTransferStatusRow(transferStatus)
            }

            if coachingProfileStore.profile != nil {
                askNoumProfileLink
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.pro.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.coachRead")
    }

    private func profileTransferStatusRow(_ status: ProfileTransferStatusContent) -> some View {
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

            transferStatusAction(status)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.transferStatus")
    }

    @ViewBuilder
    private func transferStatusAction(_ status: ProfileTransferStatusContent) -> some View {
        if let destination = status.destination,
           let actionTitle = status.actionTitle {
            NavigationLink(value: destination) {
                Text(actionTitle)
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
            }
            .accessibilityIdentifier("profile.transferStatus.prep")
        } else if let moment = status.moment,
                  let actionTitle = status.actionTitle {
            Button {
                profileOutcomeMoment = moment
            } label: {
                Text(actionTitle)
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
            }
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
        }
    }

    private var profileEvidenceHub: some View {
        let presentation = ProfileEvidenceHubPresentation.valueFirst
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            if presentation.showsDefaultHeader {
                HStack {
                    Text("Evidence")
                        .font(Typography.micro.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.0)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            VStack(spacing: presentation.usesCompactRows ? 10 : Spacing.cardGap) {
                ForEach(presentation.linkOrder, id: \.self) { link in
                    profileEvidenceLink(for: link)
                }
            }

            Button {
                toggleProfileEvidence()
            } label: {
                profileEvidenceToggleLabel
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(showProfileEvidence ? "Hide supporting evidence" : "Show supporting evidence")
            .accessibilityHint("Shows or hides supporting profile evidence.")
            .accessibilityIdentifier("profile.evidenceHub.toggle")

            if showProfileEvidence {
                profileEvidenceDetails
                    .padding(.top, Spacing.sm)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var profileEvidenceToggleLabel: some View {
        HStack(spacing: 10) {
            Text(showProfileEvidence ? "Hide supporting evidence" : "Show supporting evidence")
                .font(Typography.captionSmall.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "chevron.down")
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(showProfileEvidence ? 180 : 0))
                .animation(reduceMotion ? nil : .standardSpring, value: showProfileEvidence)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
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

    private var historyLinkSubtitle: String {
        if sessions.isEmpty { return "Saved reps appear here" }
        let noun = sessions.count == 1 ? "saved rep" : "saved reps"
        return "\(sessions.count) \(noun) · trends over time"
    }

    private var growthLibrarySubtitle: String {
        let count = proofStore.records.count
        if count == 0 { return "Proof moments appear after reps" }
        // Proof role (progression spine): verified quotes are the evidence
        // BEHIND the rating — an inventory, never a progress currency.
        // Future-tense before any rated evidence exists.
        return LedgerRoleLines.proofRole(
            count: count,
            hasRatedEvidence: ratingStore.rating.hasRatedEvidence
        )
    }

    private var profileEvidenceDetails: some View {
        let plan = evidenceDetailPlan
        return VStack(spacing: Spacing.cardGap) {
            clusterHeader("Progression details")
            if plan.surfaces.contains(.ratingTrajectory) {
                ProgressionChartsCard(sessionStore: sessionStore)
                    .accessibilityIdentifier("profile.evidence.ratingTrajectory")
            }
            // Practice volume renders BELOW the rating trajectory — the
            // spine (rating) always leads the progression story.
            if plan.surfaces.contains(.rankProgress) {
                rankPanel
            }
            if plan.surfaces.contains(.insightsBanked) {
                insightsBankedChip
            }
            if plan.surfaces.contains(.pressureHistoryShare) {
                suddenDeathHistoryShareRow
            }

            clusterHeader("Coaching evidence")
            if plan.surfaces.contains(.baselineMap) {
                baselineMapCard
            }
            if plan.surfaces.contains(.coachingDirection) {
                coachingDirectionCard
            }
            if plan.surfaces.contains(.coachLoopReadiness) {
                coachLoopReadinessCard
            }
            if plan.surfaces.contains(.weeklyCheckIn) {
                weeklyCheckInCard
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
            if plan.surfaces.contains(.skillProgress) {
                skillProgressPanel
            }
            if plan.surfaces.contains(.activeChallenge) {
                activeChallengePanel
            }
            if plan.surfaces.contains(.feedbackInbox) {
                feedbackInboxCard
            }

            let optionalSurfaces: [ProfileEvidenceDetailSurface] = [.league, .communityPractice, .achievements]
            if plan.surfaces.contains(where: { optionalSurfaces.contains($0) }) {
                clusterHeader("Optional systems")
                if plan.surfaces.contains(.league) {
                    leaguePanel
                }
                if plan.surfaces.contains(.communityPractice) {
                    communityPracticeRow
                }
                if plan.surfaces.contains(.achievements) {
                    achievementsSummaryRow
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.evidenceDetails")
    }

    private var baselineMapCard: some View {
        BaselineMapCard(
            map: BaselineCoachMap.make(
                baseline: baselineStore.baseline,
                profile: coachingProfileStore.profile
            )
        )
        .accessibilityIdentifier("profile.evidence.baselineMap")
    }

    // MARK: - Identity Header

    private var identityHeader: some View {
        VStack(spacing: 16) {
            let identity = ProfileIdentityPresentation.make(profile: coachingProfileStore.profile)
            let chosenVoice = coachingProfileStore.profile?.chosenStyleGoal

            if let chosenVoice {
                VoiceGoalIcon(
                    goal: chosenVoice,
                    size: 34,
                    containerSize: 90,
                    cornerRadius: 24
                )
                .padding(.bottom, -8)
            } else {
                // Neutral pre-goal presence. Once a user chooses a voice target,
                // the header leads with that target instead of another generic
                // character mark.
                NoumCharacter(
                    mood: .calm,
                    tint: premium.isPremium ? AppColor.pro : AppColor.brandBlue,
                    size: 90
                )
                .padding(.bottom, -8)
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

                HStack(spacing: 6) {
                    if let chosenVoice {
                        VoiceGoalIcon(goal: chosenVoice, size: 12)
                    }

                    Text(identity.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        // Identity hero — Pro-purple as the ambient brand register, matching
        // the HomeCoachCard treatment. The default surface stays about the
        // speaker and their chosen voice; XP/level detail lives behind the
        // evidence disclosure so it does not compete with Speaking Rating.
        .background(identityHeroBackground)
        .shadow(color: AppColor.pro.opacity(0.18), radius: 22, x: 0, y: 10)
    }

    /// Identity hero chrome — purple ambient wash + faint purple border.
    /// Layers, bottom to top:
    ///   1. White card base.
    ///   2. Top-anchored radial purple wash (the dream's "fancy purple").
    ///   3. Faint purple hairline border.
    /// Outer `.shadow` adds elevation in the same hue.
    private var identityHeroBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [AppColor.pro.opacity(0.48), AppColor.proLight.opacity(0.22), AppColor.pro.opacity(0.04), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )
            shape.strokeBorder(AppColor.pro.opacity(0.40), lineWidth: 1)
        }
    }

    /// Slim purple upgrade pill — lives below the identity card so the
    /// hero stays about WHO you are. Only rendered when `!premium.isPremium`.
    private var upgradeCTA: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.caption.weight(.bold))
                Text("Upgrade to Pro")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [AppColor.pro, AppColor.proLight],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .shadow(color: AppColor.pro.opacity(0.22), radius: 14, x: 0, y: 6)
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
                                    // into a no-op (same discipline as
                                    // HomeStreakStatusLine's number roll).
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
                        Text("Working on: \(baseline.persistentBlockers.joined(separator: ", "))")
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
                }
            }
            .padding(20)
            // Progress hero — the ONE vibrant surface on Profile
            // (docs/UX_VISUAL_DIRECTION.md): blue→green gradient, the
            // believable number in white, evidence on a frosted tray.
            .background(HeroGradient.progress.gradient, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .shadow(color: HeroGradient.progress.shadowTint.opacity(0.30), radius: 22, x: 0, y: 10)
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
                        Text("Best this week, best ever, best in your league.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
        let count = proofStore.records.count
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
                        Text("\(runLabel) · cross-difficulty plain-text")
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
            .accessibilityHint("Opens a share sheet with a plain-text snapshot of your full Pressure Drill track record.")
            .accessibilityIdentifier("profile.suddenDeath.historyShare")
        }
    }

    /// Human phrasing for the most-recent proof's age. Whole-day
    /// granularity to match `SummaryView` / `HomeCoachCard` recency idiom.
    /// Returns nil when the archive is empty (caller already guards).
    private var mostRecentInsightRecency: String? {
        guard let mostRecent = proofStore.recent(limit: 1).first?.proof.sessionDate else {
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
        switch trend {
        case .improving: return "Trending up"
        case .stable: return "Holding steady"
        case .declining: return "Dipping — more reps will help"
        case .newIssue: return "New pattern detected"
        case .resolved: return "Recent issue resolved"
        }
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
            if coachingProfileStore.profile != nil {
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
                    Text("Coach loop")
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
        let state = CoachingPlanCardVisibility.resolve(
            plan: forwardPlanStore.activePlan,
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            activeBigMomentID: bigMomentStore.activeMoment?.id
        )
        return CoachingPlanCard(
            state: state,
            voice: coachingProfileStore.profile?.speakingStyleGoal,
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

    /// Restrained voice-shaped Ask Noum handoff inside the Coaching
    /// Direction card. Opens `noum://ask` so the existing DeepLinkRouter
    /// pathway owns the navigation (no path-binding into Profile needed).
    private var askNoumProfileLink: some View {
        let voice = coachingProfileStore.profile?.speakingStyleGoal
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
    private func askNoumProfileLabel(for voice: SpeakingStyleGoal?) -> String {
        switch voice {
        case .authoritative: return "Ask Noum what to drill next"
        case .warm: return "Talk to Noum about your goal"
        case .concise: return "Ask Noum — one move"
        case .persuasive: return "Ask Noum where to leverage"
        case .executive: return "Brief Noum on what's next"
        case .storytelling: return "Tell Noum what's next"
        case .none: return "Ask Noum about your goal"
        }
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
                    Text("Achievements")
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
            return "Complete a rep before badges enter the profile."
        }
        if unlocked == 0 {
            return "Badges stay secondary to real speaking progress."
        }
        return "Optional badge archive. Your coaching read stays first."
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

    /// Aggregate filler word profile across all sessions.
    private var fillerProfile: [(word: String, count: Int)] {
        var aggregate: [String: Int] = [:]
        for session in sessions {
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
            statCard(title: "Sessions", value: "\(totalSessions)", icon: "mic.fill", tint: AppColor.brandBlue)
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
                            challenges.createAsyncChallenge(
                                opponentID: friend.id,
                                opponentName: friend.displayName,
                                opponentAccountID: friend.accountID
                            )
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
            activityItems: ["Practice speaking with me on Noum. It is like a gym for your voice.", URL(string: url)!],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
}

#endif
