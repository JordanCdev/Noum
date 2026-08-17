import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

// MARK: - Session History View (Redesigned)

struct SessionHistoryRowPreview: Equatable {
    static func text(for session: PracticeSession) -> String? {
        guard PracticeProgressEligibility.qualifies(session) else {
            return "Saved capture · Not enough speech to measure"
        }
        if let summary = clean(session.coachSummary) { return summary }
        if let outcome = clean(session.imConversationDetails?.outcome?.summary) { return outcome }
        return factualFallback(for: session)
    }

    private static func factualFallback(for session: PracticeSession) -> String? {
        let mode = modeLabel(for: session.mode)
        if let score = session.score {
            return "\(mode) read: \(score)/10 · \(session.fillerWordCount) fillers"
        }

        let seconds = Int(session.duration.rounded())
        if seconds > 0 {
            return "\(mode) rep saved · \(seconds)s"
        }

        return "\(mode) rep saved"
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func modeLabel(for mode: PracticeMode) -> String {
        mode.displayLabel
    }
}

struct SessionHistoryDetailPresentation: Equatable {
    static let insufficientEvidenceHeadline = "Saved capture"
    static let insufficientEvidenceMessage =
        "This capture is saved, but there was not enough speech for a reliable score or coaching read. It does not affect your progress."

    /// A persisted headline can contain evaluator praise even when the raw
    /// capture later fails the shared progress boundary. Keep the row
    /// inspectable, but never present that stale positive read as evidence.
    static func headline(for session: PracticeSession, fallback: String) -> String {
        guard PracticeProgressEligibility.qualifies(session) else {
            return insufficientEvidenceHeadline
        }
        return session.headline ?? fallback
    }

    static func scoreLabel(for session: PracticeSession) -> String {
        guard PracticeProgressEligibility.qualifies(session) else { return "Not measured" }
        return session.score.map { "\($0)/10" } ?? "Pending"
    }

    static func focusLabel(for session: PracticeSession) -> String {
        if session.imConversationDetails != nil {
            return "Next Rep"
        }
        if let intent = clean(session.intentLabel) {
            return intent
        }
        return durationLabel(for: session)
    }

    static func durationLabel(for session: PracticeSession) -> String {
        guard session.duration.isFinite else { return "Unavailable" }
        return "\(max(0, Int(session.duration.rounded())))s"
    }

    /// Historical WPM is a derived comparison metric, not a raw history fact.
    /// Keep the exact saved row inspectable while withholding pace when its
    /// quantity, confidence, schema, or fixture provenance is insufficient.
    static func paceLabel(for session: PracticeSession) -> String {
        guard let pace = SessionQualifier.quantityQualifiedWordsPerMinute(session) else {
            return "Not measured"
        }
        return "\(Int(pace.rounded()))"
    }

    /// The prompt this rep answered, or nil when none was captured. The
    /// score and pace reads are impossible to sanity-check without the
    /// question, so the detail view surfaces this whenever it exists.
    static func prompt(for session: PracticeSession) -> String? {
        clean(session.prompt)
    }

    /// First sentence of a coach paragraph — the focus card carries the
    /// headline thought; the full paragraph stays in Coach Read so the
    /// same wall of text isn't rendered twice on one screen.
    static func leadSentence(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        var lead = ""
        for character in trimmed {
            lead.append(character)
            // Min length guards against abbreviation periods ("e.g.",
            // "Mr.") ending the sentence absurdly early.
            if ".!?".contains(character) && lead.count >= 25 {
                break
            }
        }
        return lead.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Neutral context line connecting this rep to the previous scored rep
    /// of the same mode — answers "what happened between sessions" without
    /// judging a drop. Nil when this is the first scored rep of its mode.
    static func previousRepLine(for session: PracticeSession, in sessions: [PracticeSession]) -> String? {
        guard PracticeProgressEligibility.qualifies(session), session.score != nil else { return nil }
        let previous = PracticeProgressEligibility.eligibleSessions(in: sessions)
            .filter { $0.mode == session.mode && $0.date < session.date && $0.score != nil }
            .max(by: { $0.date < $1.date })
        guard let previous, let previousScore = previous.score else { return nil }
        let day = previous.date.formatted(date: .abbreviated, time: .omitted)
        return "Previous \(modeLabel(for: session.mode)) rep: \(previousScore)/10 on \(day)."
    }

    /// Footer for the transcript card. The transcript is stored in full —
    /// when it reads as cut off, that's where the recording stopped, and
    /// saying so explicitly is what keeps the user trusting the capture.
    static func transcriptEndLine(for session: PracticeSession) -> String {
        "Recording ended here. \(durationLabel(for: session))"
    }

    private static func modeLabel(for mode: PracticeMode) -> String {
        mode.displayLabel
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

enum SessionHistoryReviewSurface: Equatable {
    case none
    case recentReps
    case targetedPractice

    static func visibleSurface(
        hasRecentRepReviews: Bool,
        hasTargetedPractice: Bool
    ) -> SessionHistoryReviewSurface {
        if hasRecentRepReviews {
            return .recentReps
        }
        if hasTargetedPractice {
            return .targetedPractice
        }
        return .none
    }
}

struct SessionHistoryView: View {

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var skillTrendStore = SkillTrendStore.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var clutchWordStore = ClutchWordStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @State private var isProgressExpanded = ReviewProgressDisclosure.defaultExpanded
    @State private var isV46EvidenceExpanded = false
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isAppTabRoot) private var isAppTabRoot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
    }

    init() {
        self._navigationPath = .constant(NavigationPath())
    }

    // MARK: - Derived Data

    private var sessions: [PracticeSession] {
        sessionStore.sessions.sorted { $0.date > $1.date }
    }

    private var progressEligibleSessions: [PracticeSession] {
        sessionStore.progressEligibleSessions.sorted { $0.date > $1.date }
    }

    private var totalSessions: Int { sessions.count }

    /// Uses the chart's shared evidence projection so the page and child
    /// card cannot disagree about whether a measured chart will draw.
    private var developmentChartHasData: Bool {
        ReviewDevelopmentChartEvidence.hasEnoughData(in: progressEligibleSessions)
    }

    private var skillTrends: [SkillTrend] {
        TrendAnalyzer.analyze(snapshots: skillTrendStore.snapshots)
    }

    private var highlights: [ReviewHighlightsEngine.Highlight] {
        ReviewHighlightsEngine.highlights(
            sessions: progressEligibleSessions,
            profile: coachingProfileStore.profile
        )
    }

    private var visibleHighlights: [ReviewHighlightsEngine.Highlight] {
        ReviewHighlightLimit.visible(highlights)
    }

    private var reviewStory: ReviewStoryPresentation? {
        ReviewStoryPresentation.make(trends: skillTrends, sessions: progressEligibleSessions)
    }

    private var reviewSurface: SessionHistoryReviewSurface {
        SessionHistoryReviewSurface.visibleSurface(
            hasRecentRepReviews: MistakeReplayCard.hasReviewRows(in: sessions),
            hasTargetedPractice: WeakAreasCard.hasTargets(
                baseline: baselineStore.baseline,
                topClutchWords: clutchWordStore.topClutchWords,
                rating: ratingStore.rating
            )
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        v46ProgressHead

                        highlightsSection

                        sessionHistoryEntry

                        progressDisclosureSection

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isAppTabRoot {
                        Color.clear
                            .frame(height: Spacing.tabRootNavigationClearance)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("history.screen")
        .onAppear {
            FlowEventLog.shared.recordReviewSurfaceOpened()
        }
        .toolbar {
            if !isAppTabRoot {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - V4.6 Progress head (258:1131)

    private var v46Progress: V46ProgressPresentation? {
        V46ProgressPresentation.make(
            outcomes: recommendationLearningStore.outcomes,
            intervention: coachMemoryStore.currentMemory?.activeIntervention
        )
    }

    private var v46PracticeProjection: V46ProgressPracticeProjection? {
        guard let target = v46Progress?.practiceTarget else { return nil }
        return V46ProgressPracticeProjection.make(
            target: target,
            sessions: sessionStore.sessions
        )
    }

    /// The evidence-led trajectory: eyebrow (active target) → one bounded
    /// reliability statement → honest tally → comparable proof chronology →
    /// up to three evidence rows (lapse kept, amber + text cue) → one
    /// plan-review action. Renders only on real comparable evidence; the
    /// legacy story card remains the fallback.
    @ViewBuilder
    private var v46ProgressHead: some View {
        if let presentation = v46Progress {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("What changed in your communication.")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                v46CoachReadCard(presentation)

                v46NextFocusCard(
                    presentation: presentation,
                    practice: v46PracticeProjection
                )

                if let reviewTitle = presentation.reviewRowTitle {
                    Button {
                        navigationPath.append(AppDestination.weeklyCheckIn)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: presentation.reviewIsDue ? "calendar.badge.exclamationmark" : "calendar")
                                .font(Typography.caption.weight(.semibold))
                                .foregroundStyle(AppColor.coachingInkOnQuiet)
                                .accessibilityHidden(true)
                            Text(reviewTitle)
                                .font(Typography.caption.weight(.semibold))
                                .foregroundStyle(AppColor.coachingInkOnQuiet)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: Spacing.xs)
                            Image(systemName: "chevron.right")
                                .font(Typography.captionSmall.weight(.bold))
                                .foregroundStyle(AppColor.coachingInkOnQuiet)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: NoumControlMetric.minimumTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("progress.v46.reviewTarget")
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.lg)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("progress.v46.head")
        } else {
            storySection
        }
    }

    /// The primary interpretation is one authored surface: a semantic read
    /// mark, bounded conclusion, categorical proof chronology, then the
    /// newest supporting receipt. Older receipts remain available without
    /// making the page read like a ledger.
    private func v46CoachReadCard(_ presentation: V46ProgressPresentation) -> some View {
        NoumSurface(.standard) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "scope")
                        .font(Typography.headline.weight(.semibold))
                        .foregroundStyle(v46ReadTint(for: presentation.readStage))
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(presentation.coachReadEyebrow)
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(v46ReadTint(for: presentation.readStage))
                        Text(presentation.eyebrow.capitalized)
                            .font(Typography.captionSmall.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                Text(presentation.authoredHeadline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("progress.v46.headline")

                Text(presentation.subtitle)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("progress.v46.subtitle")

                v46ProofChronology(presentation)

                v46EvidenceDisclosure(presentation)
            }
        }
    }

    /// A chronology, not a score chart. Every node sits on the same baseline
    /// because the ledger gives us categorical retry outcomes, not a
    /// continuous daily measurement. The caption makes the per-day roll-up
    /// explicit. The authored read gives the cohort total once; this view
    /// shows the day-level evidence without repeating a second tally tile.
    private func v46ProofChronology(_ presentation: V46ProgressPresentation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text("Comparable retries")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: Spacing.xs)
                Text("Best result each day")
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
            }

            if dynamicTypeSize.isAccessibilitySize {
                v46VerticalProofChronology(presentation.trajectory)
            } else {
                v46HorizontalProofChronology(presentation.trajectory)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(trajectoryAccessibilityLabel(for: presentation)))
        .accessibilityIdentifier("progress.v46.chronology")
        .id(trajectoryIdentity(for: presentation))
    }

    private func v46HorizontalProofChronology(_ days: [V46TrajectoryDay]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: Spacing.xxs) {
                    HStack(spacing: 0) {
                        v46TrajectoryConnector(isVisible: index > 0)
                        v46TrajectoryNode(for: day.outcome)
                        v46TrajectoryConnector(isVisible: index < days.count - 1)
                    }
                    Text(day.label)
                        .font(Typography.captionSmall.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                    Text(day.outcome.label)
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(v46TrajectoryTint(for: day.outcome))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
                .modifier(V46TrajectoryReveal(index: index, reduceMotion: reduceMotion))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func v46VerticalProofChronology(_ days: [V46TrajectoryDay]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(spacing: 0) {
                        v46TrajectoryNode(for: day.outcome)
                        Rectangle()
                            .fill(AppColor.textTertiary.opacity(0.30))
                            .frame(width: 2, height: 24)
                            .opacity(index < days.count - 1 ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 32)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(day.label)
                            .font(Typography.captionSmall.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(AppColor.textSecondary)
                        Text(day.outcome.label)
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(v46TrajectoryTint(for: day.outcome))
                    }
                    .padding(.top, Spacing.xxs)

                    Spacer(minLength: 0)
                }
                .modifier(V46TrajectoryReveal(index: index, reduceMotion: reduceMotion))
            }
        }
    }

    private func v46TrajectoryConnector(isVisible: Bool) -> some View {
        Rectangle()
            .fill(AppColor.textTertiary.opacity(0.30))
            .frame(maxWidth: .infinity, minHeight: 2, maxHeight: 2)
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(true)
    }

    private func v46TrajectoryNode(for outcome: V46TrajectoryOutcome) -> some View {
        ZStack {
            Circle()
                .fill(AppColor.cardBackground)
            Circle()
                .stroke(v46TrajectoryTint(for: outcome), lineWidth: 2)
            Image(systemName: v46TrajectorySymbol(for: outcome))
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(v46TrajectoryTint(for: outcome))
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }

    private func v46TrajectorySymbol(for outcome: V46TrajectoryOutcome) -> String {
        switch outcome {
        case .improved: return "arrow.up.right"
        case .held: return "checkmark"
        case .lapse: return "arrow.down.right"
        }
    }

    private func v46TrajectoryTint(for outcome: V46TrajectoryOutcome) -> Color {
        switch outcome {
        case .improved: return AppColor.positive
        case .held: return AppColor.coachingInk
        case .lapse: return AppColor.caution
        }
    }

    private func trajectoryAccessibilityLabel(for presentation: V46ProgressPresentation) -> String {
        let sequence = presentation.trajectory
            .map { "\($0.label): \($0.outcome.label)" }
            .joined(separator: ", ")
        return "\(presentation.trajectoryAccessibilitySummary) Best comparable result each day: \(sequence)."
    }

    @ViewBuilder
    private func v46EvidenceDisclosure(_ presentation: V46ProgressPresentation) -> some View {
        if let latest = presentation.rows.last {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Latest evidence")
                    .font(Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
                v46EvidenceRow(latest)

                let earlier = Array(presentation.rows.dropLast())
                if !earlier.isEmpty {
                    Button {
                        withAnimation(NoumMotion.animation(for: .calm, reduceMotion: reduceMotion)) {
                            isV46EvidenceExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(isV46EvidenceExpanded
                                ? "Hide earlier evidence"
                                : "Show \(earlier.count) earlier receipt\(earlier.count == 1 ? "" : "s")")
                                .font(Typography.caption.weight(.semibold))
                            Spacer(minLength: Spacing.xs)
                            Image(systemName: isV46EvidenceExpanded ? "chevron.up" : "chevron.down")
                                .font(Typography.captionSmall.weight(.bold))
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(AppColor.coachingInkOnQuiet)
                        .frame(maxWidth: .infinity, minHeight: NoumControlMetric.minimumTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("progress.v46.evidenceDisclosure")

                    if isV46EvidenceExpanded {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(earlier) { row in
                                v46EvidenceRow(row)
                            }
                        }
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .accessibilityIdentifier("progress.v46.rows")
        }
    }

    private func v46EvidenceRow(_ row: V46EvidenceRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(row.dayLabel)
                .font(Typography.captionSmall.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(row.tone == .lapse ? AppColor.caution : AppColor.coachingInk)
                .frame(width: 56, alignment: .leading)
            Text(row.copy)
                .font(Typography.caption.weight(row.tone == .lapse ? .regular : .semibold))
                .foregroundStyle(row.tone == .lapse ? AppColor.textSecondary : AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private func v46NextFocusCard(
        presentation: V46ProgressPresentation,
        practice: V46ProgressPracticeProjection?
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Next focus")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.coachingInkOnQuiet)
                Text(presentation.nextFocus)
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.proQuietSurface,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )

            if let practice {
                PrimaryCTA(
                    "Practice this target",
                    icon: "mic.fill",
                    tint: AppColor.coachingInk
                ) {
                    startV46TargetPractice(practice)
                }
                .frame(minHeight: NoumControlMetric.minimumTouchTarget + Spacing.cardGap)
                .accessibilityHint("Repeats the original prompt with the same coaching target.")
                .accessibilityIdentifier("progress.v46.practiceTarget")
            }
        }
    }

    private func v46ReadTint(for stage: V46ProgressReadStage) -> Color {
        switch stage {
        case .early: return AppColor.coachingInk
        case .forming: return AppColor.caution
        case .reliable: return AppColor.positive
        }
    }

    /// Stable identity for the current chronology so new evidence resets the
    /// restrained reveal while unchanged content stays coherent in-place.
    private func trajectoryIdentity(for presentation: V46ProgressPresentation) -> String {
        presentation.trajectory
            .map { "\($0.label)|\($0.outcome.label)" }
            .joined(separator: "·")
    }

    private func startV46TargetPractice(_ projection: V46ProgressPracticeProjection) {
        let correlationID = UUID()
        let prescription = projection.prescription(correlationID: correlationID)
        guard let token = TimedPracticePromptHandoff.shared
            .offerTranscriptRetryToken(prescription) else { return }

        recommendationLearningStore.recordShown(
            fingerprint: prescription.fingerprint,
            title: prescription.title,
            focus: prescription.focus,
            target: prescription.target,
            mode: .timed,
            isAIBacked: false,
            goal: prescription.goal,
            targetDimensionID: prescription.targetDimensionID,
            sourceSessionID: prescription.sourceSessionID,
            observabilityID: correlationID,
            transcriptRetryTarget: prescription.retryTarget
        )
        recommendationLearningStore.markTapped(mode: .timed)
        navigationPath.append(AppDestination.timedPracticePrompt(token: token))
    }

    // MARK: - Development

    @ViewBuilder
    private var storySection: some View {
        if let reviewStory {
            ReviewStoryCard(presentation: reviewStory) {
                navigationPath.append(
                    AppDestination.sessionDetail(sessionID: reviewStory.latestSessionID)
                )
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, Spacing.lg)
        }
    }

    private var progressDisclosureSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(reduceMotion ? nil : .standardSpring) {
                    isProgressExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(Typography.caption.weight(.bold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(width: 34, height: 34)
                        .background(AppColor.brandBlue.opacity(0.10), in: Circle())

                    Text(isProgressExpanded ? "Hide progress" : "See progress")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: Spacing.xs)

                    Image(systemName: "chevron.down")
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isProgressExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(isProgressExpanded ? "Hide progress" : "See progress")
            .accessibilityIdentifier("review.progress.toggle")

            if isProgressExpanded {
                Group {
                    if developmentChartHasData {
                        ProgressionChartsCard(sessionStore: sessionStore)
                    } else {
                        earlyDevelopmentCard
                    }
                }
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, Spacing.lg)
    }

    @ViewBuilder
    private var developmentSection: some View {
        Group {
            if developmentChartHasData {
                ProgressionChartsCard(sessionStore: sessionStore)
            } else {
                earlyDevelopmentCard
            }
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, 16)
    }

    /// Honest placeholder while the chart's evidence floor isn't met —
    /// names what unlocks it rather than drawing a two-point line.
    private var earlyDevelopmentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                Text("Progress is forming")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("A few more scored reps will unlock the progress chart.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .accessibilityIdentifier("review.developmentForming")
    }

    private var coachReadSection: some View {
        ReviewCoachReadCard(trends: skillTrends)
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 16)
    }

    @ViewBuilder
    private var highlightsSection: some View {
        if !visibleHighlights.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Worth another look")
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 0) {
                    ForEach(Array(visibleHighlights.enumerated()), id: \.element.id) { index, highlight in
                        ReviewHighlightRow(highlight: highlight) {
                            navigationPath.append(
                                AppDestination.sessionDetail(sessionID: highlight.sessionID)
                            )
                        }
                        if index < visibleHighlights.count - 1 {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Session history entry

    private var sessionHistoryEntry: some View {
        NavigationLink {
            SessionHistoryListView(navigationPath: $navigationPath)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 34, height: 34)
                    .background(AppColor.brandBlue.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("All reps")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(totalSessions) saved rep\(totalSessions == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, 20)
        .accessibilityIdentifier("history.sessionListEntry")
    }

    @ViewBuilder
    private var reviewSignalsSection: some View {
        switch reviewSurface {
        case .none:
            EmptyView()
        case .recentReps:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Worth a replay")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .padding(.horizontal, Spacing.screenH)

                MistakeReplayCard(sessionStore: sessionStore) { destination in
                    navigationPath.append(destination)
                }
                .padding(.horizontal, Spacing.screenH)
            }
            .padding(.bottom, 20)

        case .targetedPractice:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Worth a replay")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .padding(.horizontal, Spacing.screenH)

                WeakAreasCard(sessionStore: sessionStore) { target in
                    navigationPath.append(target.destination)
                }
                .padding(.horizontal, Spacing.screenH)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        EmptyStateView(
            symbol: "clock.arrow.circlepath",
            title: "Your progress starts with one rep",
            body: "Complete a short rep to see your first score, pace, and filler count.",
            tint: AppColor.brandBlue,
            cta: EmptyStateView.CTA(label: "Start a rep", icon: "mic.fill") {
                navigationPath.append(AppDestination.practiceSelection)
            }
        )
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .padding(Spacing.lg)
        .accessibilityIdentifier("emptyState.history")
    }

}

/// One restrained reveal for the presented chronology. Nodes settle in
/// reading order; Reduce Motion is fully static from the first rendered frame.
private struct V46TrajectoryReveal: ViewModifier {
    let index: Int
    let reduceMotion: Bool
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || revealed ? 1 : 0)
            .offset(y: reduceMotion || revealed ? 0 : 6)
            .onAppear {
                guard !revealed else { return }
                if reduceMotion {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        revealed = true
                    }
                    return
                }
                withMotion(false, .stagger(index)) {
                    revealed = true
                }
            }
            .onChange(of: reduceMotion) { _, enabled in
                guard enabled, !revealed else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    revealed = true
                }
            }
    }
}

/// Visible to surfaces outside SessionHistoryView (e.g. Growth Library's
/// quote-card deep link) so the source-session detail can be pushed from
/// anywhere. The view is otherwise unchanged — same heroCard, focusCard,
/// transcript card, AI coach read, IM conversation card.
struct SessionHistoryDetailReplayPresentation: Equatable {
    enum Semantics: Equatable {
        /// Starts a fresh attempt from a historical record. It is user-led
        /// replay, not a new adaptive prescription or causal acceptance event.
        case replay

        var recordsAdaptivePrescriptionAcceptance: Bool { false }
    }

    /// Legacy source-compatible fields retained for existing consumers and
    /// tests. The historical detail UI renders `displayTitle` /
    /// `displaySupportingCopy` below so the visible language is replay-first.
    let title: String
    let supportingCopy: String
    let displayTitle: String
    let displaySupportingCopy: String
    let accessibilityLabel: String
    let destination: AppDestination
    let semantics: Semantics

    static func make(for session: PracticeSession) -> SessionHistoryDetailReplayPresentation {
        let legacyTitle = "Practice this mode"
        let legacySupportingCopy = "Start a fresh \(session.mode.displayLabel) rep."
        let displayTitle = "Repeat this rep"
        let displaySupportingCopy = "Replay the recorded \(session.mode.displayLabel) setup in a fresh rep."
        return SessionHistoryDetailReplayPresentation(
            title: legacyTitle,
            supportingCopy: legacySupportingCopy,
            displayTitle: displayTitle,
            displaySupportingCopy: displaySupportingCopy,
            accessibilityLabel: "\(displayTitle). \(displaySupportingCopy)",
            destination: SummaryPracticeAgainRouter.destination(
                for: session.mode,
                imSetup: session.imConversationDetails?.setup
            ),
            semantics: .replay
        )
    }
}

struct SessionHistoryDetailView: View {
    let session: PracticeSession
    let insights: [String]
    @Binding var navigationPath: NavigationPath
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @State private var showsFullReview = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard

                    promptCard
                    if isProgressEligible {
                        if let snapshot = durableRewriteSnapshot {
                            transcriptUpgradeCard(snapshot)
                        }
                        if let goalOutcomeRead {
                            // Historical goal movement is a read, not a fresh
                            // adaptive prescription. The replay action below owns
                            // the only launch and deliberately writes no causal
                            // recommendation acceptance.
                            GoalOutcomeCard(read: goalOutcomeRead)
                        }
                        focusCard
                        fullReviewToggle

                        if showsFullReview {
                            if let imDetails = session.imConversationDetails {
                                conversationReadCard(imDetails)
                            } else {
                                sessionMetricsCard
                            }

                            if !insights.isEmpty {
                                insightsCard
                            }

                            if let aiFeedback = session.evidenceSafeAICoachFeedback {
                                coachReadCard(aiFeedback)
                            }

                            transcriptCard
                        }
                    } else {
                        insufficientEvidenceCard
                        transcriptCard
                    }
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            FlowEventLog.shared.logOnce(FlowEvent.make(
                correlationId: session.id,
                flow: .other,
                stage: "review.sessionOpened",
                reason: "historical session detail opened"
            ))
        }
    }

    private var goalOutcomeRead: GoalOutcomeRead? {
        guard isProgressEligible else { return nil }
        return GoalOutcomeEngine.read(
            profile: coachingProfileStore.profile,
            baseline: baselineStore.baseline,
            rating: ratingStore.rating,
            sessions: sessionStore.sessions.filter { $0.date <= session.date },
            coachMemory: coachMemoryStore.currentMemory,
            outcomes: recommendationLearningStore.outcomes.filter { $0.completedAt <= session.date }
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(SessionHistoryDetailPresentation.headline(for: session, fallback: "Session detail"))
                .font(.title2.weight(.bold))

            Text(primarySummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isProgressEligible {
                HStack(spacing: 10) {
                    detailMetric(title: "Score", value: SessionHistoryDetailPresentation.scoreLabel(for: session), tint: .green)
                    detailMetric(title: "Focus", value: SessionHistoryDetailPresentation.focusLabel(for: session), tint: .blue)
                    detailMetric(title: "Mode", value: modeLabel, tint: AppColor.tint(for: session.mode))
                }
            } else {
                HStack(spacing: 10) {
                    detailMetric(title: "Score", value: SessionHistoryDetailPresentation.scoreLabel(for: session), tint: .secondary)
                    detailMetric(title: "Duration", value: SessionHistoryDetailPresentation.durationLabel(for: session), tint: .blue)
                    detailMetric(title: "Mode", value: modeLabel, tint: AppColor.tint(for: session.mode))
                }
            }

            if let previousLine = SessionHistoryDetailPresentation.previousRepLine(for: session, in: sessionStore.sessions) {
                Text(previousLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("history.detail.previousRep")
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground)
        .shadow(color: AppColor.tint(for: session.mode).opacity(0.16), radius: 22, x: 0, y: 10)
    }

    /// Hero chrome for the session-detail hero — mode-tinted radial wash +
    /// tint border. Matches the M14 hero treatment on Coach Card / Profile /
    /// Settings / League so the Review detail surface stops reading
    /// iOS-stock. The mid gradient stop holds the same mode tint at a
    /// lower alpha rather than a dedicated `*Light` sibling — keeps the
    /// hue identity tight for modes without a Light variant (Sudden Death,
    /// Ah-Counter, IM).
    private var heroCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        let tint = AppColor.tint(for: session.mode)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [tint.opacity(0.42), tint.opacity(0.22), tint.opacity(0.04), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )
            shape.strokeBorder(tint.opacity(0.40), lineWidth: 1)
        }
    }

    /// The question this rep answered. Stored on every prompted session but
    /// historically never rendered here — without it, neither the score nor
    /// the pace read can be judged against what was actually asked.
    @ViewBuilder
    private var promptCard: some View {
        if let prompt = SessionHistoryDetailPresentation.prompt(for: session) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Prompt")
                        .font(.headline)
                    Spacer()
                    if let theme = session.theme, theme != .all {
                        Text(theme.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColor.tint(for: session.mode).opacity(0.10), in: Capsule(style: .continuous))
                    }
                }

                Text("“\(prompt)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .accessibilityIdentifier("history.detail.prompt")
        }
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Focus next")
                .font(.headline)

            Text(nextFocusText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let imDetails = session.imConversationDetails {
                HStack(spacing: 10) {
                    detailMetric(title: "Target tone", value: imDetails.setup.targetTone.title, tint: .blue)
                    if let finalState = imDetails.finalState {
                        detailMetric(title: "Trust", value: "\(finalState.normalizedTrust)/10", tint: .teal)
                        detailMetric(title: "Tension", value: "\(finalState.normalizedTension)/10", tint: .orange)
                    }
                }

                if let outcome = imDetails.outcome {
                    Text(outcome.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let beat = imDetails.finalState?.beat {
                    Text(beat)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 10) {
                    detailMetric(title: "Duration", value: SessionHistoryDetailPresentation.durationLabel(for: session), tint: .blue)
                    detailMetric(title: "Fillers", value: "\(session.fillerWordCount)", tint: .red)
                    detailMetric(title: "WPM", value: SessionHistoryDetailPresentation.paceLabel(for: session), tint: .indigo)
                }
            }

            practiceThisModeLink
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var durableRewriteSnapshot: TranscriptRewriteSnapshot? {
        guard let snapshot = session.transcriptRewriteSnapshot,
              snapshot.matches(sourceTranscript: session.transcript) else {
            return nil
        }
        return snapshot
    }

    private func transcriptUpgradeCard(
        _ snapshot: TranscriptRewriteSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("A stronger version of your words")
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Saved with this rep, so the coaching does not change when you reopen it.")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ReviewTranscriptStep(
                eyebrow: "FROM YOUR TRANSCRIPT · VERIFIED \(RepDurationLabel.mss(session.duration))",
                text: TranscriptChangeHighlighter.recededText(
                    original: snapshot.originalSnippet,
                    revision: snapshot.oneStepText
                ),
                detail: "Verified excerpt from this rep",
                tint: AppColor.textSecondary,
                identifier: "history.detail.rewrite.original",
                plainText: snapshot.originalSnippet,
                spokenDiff: TranscriptChangeHighlighter
                    .spokenRemovals(original: snapshot.originalSnippet, revision: snapshot.oneStepText)
                    .map { "Your original. Words being let go: \($0)." }
            )

            ReviewTranscriptStep(
                eyebrow: "TRY THIS",
                text: TranscriptChangeHighlighter.highlightedText(
                    original: snapshot.originalSnippet,
                    revision: snapshot.oneStepText
                ),
                detail: "Noum's minimal edit · changed words are highlighted",
                tint: AppColor.proText,
                identifier: "history.detail.rewrite.oneStep",
                plainText: snapshot.oneStepText,
                spokenDiff: TranscriptChangeHighlighter
                    .spokenAdditions(original: snapshot.originalSnippet, revision: snapshot.oneStepText)
                    .map { "Upgrade — adds \($0). Meaning and voice preserved." },
                hero: true
            )

            if let aspiration = snapshot.aspirationalRewrite {
                ReviewTranscriptStep(
                    eyebrow: "ASPIRATIONAL END STATE",
                    text: TranscriptChangeHighlighter.highlightedText(
                        original: snapshot.originalSnippet,
                        revision: aspiration.text
                    ),
                    detail: "A direction to grow toward — not the next rep target",
                    tint: AppColor.brandBlue,
                    identifier: "history.detail.rewrite.aspiration"
                )
            }

            Button {
                startTargetedRetry(snapshot)
            } label: {
                Text("Try again with the same prompt")
                    .font(Typography.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(EditorialCTAButtonStyle())
            .accessibilityIdentifier("history.detail.rewrite.retry")
            .accessibilityHint("Starts Timed Practice with the exact same prompt and the same improvement target.")

            if snapshot.origin == .onDevice {
                Label("Private on-device edit", systemImage: "lock.fill")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityLabel("Private on-device edit, built without an AI provider.")
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.proQuietSurface, AppColor.cardBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.pro.opacity(0.18), lineWidth: 1)
        )
        .accessibilityIdentifier("history.detail.rewriteLadder")
    }

    private func startTargetedRetry(_ snapshot: TranscriptRewriteSnapshot) {
        let correlationID = UUID()
        let lever = TranscriptPracticeLever(weakness: snapshot.weakness)
        let retryTarget = TranscriptRetryTarget(lever: lever)
        // Retry contract: when the source rep had a prompt, Timed Practice
        // must present that exact prompt again (TranscriptRetryPrompt.resolve)
        // — the rewrite text is only the fallback for promptless reps.
        let prescription = TranscriptPracticePrescription(
            correlationID: correlationID,
            sourceSessionID: session.id,
            suggestedPrompt: TranscriptRetryPrompt.resolve(
                sourcePrompt: session.prompt,
                fallbackRewritePrompt: snapshot.oneStepText
            ),
            title: "One-step \(lever.focusLabel) upgrade",
            focus: lever.focusLabel,
            target: lever.successMeasure,
            targetDimensionID: nil,
            goal: coachingProfileStore.profile?.chosenStyleGoal,
            retryTarget: retryTarget
        )
        guard let token = TimedPracticePromptHandoff.shared
            .offerTranscriptRetryToken(prescription) else { return }

        recommendationLearningStore.recordShown(
            fingerprint: prescription.fingerprint,
            title: prescription.title,
            focus: prescription.focus,
            target: prescription.target,
            mode: .timed,
            isAIBacked: snapshot.origin == .provider,
            goal: prescription.goal,
            targetDimensionID: nil,
            sourceSessionID: session.id,
            observabilityID: correlationID,
            transcriptRetryTarget: retryTarget
        )
        recommendationLearningStore.markTapped(mode: .timed)
        navigationPath.append(
            AppDestination.timedPracticePrompt(token: token)
        )
    }

    private var insufficientEvidenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saved capture")
                .font(.headline)
            Text(SessionHistoryDetailPresentation.insufficientEvidenceMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            practiceThisModeLink
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .accessibilityIdentifier("history.detail.insufficientEvidence")
    }

    private var practiceThisModeLink: some View {
        let presentation = SessionHistoryDetailReplayPresentation.make(for: session)
        let tint = AppColor.tint(for: session.mode)

        return Button {
            navigationPath.append(presentation.destination)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: session.mode.iconName)
                    .font(Typography.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(presentation.displayTitle)
                        .font(Typography.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(presentation.displaySupportingCopy)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                tint.opacity(0.10),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityIdentifier("history.detail.practiceAgain")
    }

    private var fullReviewToggle: some View {
        Button {
            if reduceMotion {
                showsFullReview.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsFullReview.toggle()
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(showsFullReview ? "Hide full review" : "See full review")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Open the deeper breakdown only when you want more detail.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: showsFullReview ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.blue)
            }
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var sessionMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session metrics")
                .font(.headline)

            HStack(spacing: 10) {
                detailMetric(title: "Fillers", value: "\(session.fillerWordCount)", tint: .red)
                detailMetric(title: "WPM", value: SessionHistoryDetailPresentation.paceLabel(for: session), tint: .indigo)
                detailMetric(title: "Duration", value: SessionHistoryDetailPresentation.durationLabel(for: session), tint: .blue)
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func conversationReadCard(_ imDetails: IMConversationDetails) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Full conversation review")
                .font(.headline)

            if let outcome = imDetails.outcome {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Main read")
                        .font(.subheadline.weight(.semibold))
                    Text(outcome.title)
                        .font(.subheadline.weight(.semibold))
                    Text(outcome.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(imDetails.finalState?.beat ?? "The conversation is still settling into a readable pattern.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let relationship = imDetails.relationshipSnapshot {
                relationshipBlock(relationship)
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func relationshipBlock(_ relationship: IMRelationshipProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.vertical, 2)

            Text("Relationship Impact")
                .font(.headline)

            HStack(spacing: 10) {
                detailMetric(title: "Milestone", value: relationship.activeMilestone.title, tint: .teal)
                detailMetric(title: "Momentum", value: relationship.nextMilestoneProgressLabel, tint: .orange)
            }

            Text(relationship.activeMilestone.description)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(relationship.continuitySummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let activeArcTitle = relationship.activeArcTitle,
               let activeArcStageLabel = relationship.activeArcStageLabel {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active Arc")
                        .font(.subheadline.weight(.semibold))
                    Text("\(activeArcTitle) • \(activeArcStageLabel)")
                        .font(.subheadline.weight(.semibold))
                    if let activeArcGuidance = relationship.activeArcGuidance {
                        Text(activeArcGuidance)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: relationship.activeArcProgress)
                        .tint(.purple)
                }
                .padding(12)
                .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Next best move")
                    .font(.subheadline.weight(.semibold))
                Text(relationship.nextSessionHook(profile: coachingProfileStore.profile))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Matters")
                .font(.headline)

            ForEach(Array(insights.prefix(3).enumerated()), id: \.offset) { index, insight in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(AppColor.brandBlue, in: Circle())
                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func coachReadCard(_ aiFeedback: AICoachFeedback) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach Read")
                .font(.headline)

            coachSection(title: "What worked", lines: aiFeedback.strengths)

            VStack(alignment: .leading, spacing: 6) {
                Text("Biggest improvement")
                    .font(.subheadline.weight(.semibold))
                Text(aiFeedback.keyImprovement)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Suggested drill")
                    .font(.subheadline.weight(.semibold))
                Text(aiFeedback.suggestedDrill)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.imConversationDetails == nil ? "Transcript" : "Conversation Transcript")
                .font(.headline)
            Text(session.transcript)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            // Explicit end marker — a transcript that stops mid-thought with
            // no signal reads as "did it even capture my speech?". It did;
            // this is where the rep stopped.
            HStack(spacing: 5) {
                Image(systemName: "stop.circle")
                    .font(.caption2)
                Text(SessionHistoryDetailPresentation.transcriptEndLine(for: session))
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
            .accessibilityIdentifier("history.detail.transcriptEnd")
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func coachSection(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(lines, id: \.self) { line in
                Text("• \(line)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var primarySummary: String {
        guard isProgressEligible else {
            return "Saved capture. Not enough speech to measure reliably."
        }
        if let coachSummary = session.coachSummary, !coachSummary.isEmpty {
            return coachSummary
        }
        if let firstInsight = insights.first {
            return firstInsight
        }
        return "Review the strongest signal from this practice run and what to improve next."
    }

    private var nextFocusText: String {
        if let relationship = session.imConversationDetails?.relationshipSnapshot {
            return relationship.nextSessionHook(profile: coachingProfileStore.profile)
        }
        if let aiFeedback = session.evidenceSafeAICoachFeedback {
            // Lead sentence only — the full paragraph renders inside Coach
            // Read below, and showing it twice on one screen reads as
            // padding rather than coaching.
            return SessionHistoryDetailPresentation.leadSentence(of: aiFeedback.keyImprovement)
        }
        if let firstInsight = insights.first {
            return firstInsight
        }
        return "Focus on saying one clear thing cleanly before adding more detail."
    }

    private func detailMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.cardGap)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private var modeLabel: String {
        session.mode.displayLabel
    }

    private var isProgressEligible: Bool {
        PracticeProgressEligibility.qualifies(session)
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    SessionHistoryView()
}
#endif
