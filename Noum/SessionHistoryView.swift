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
    @State private var isProgressExpanded = ReviewProgressDisclosure.defaultExpanded
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isAppTabRoot) private var isAppTabRoot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        storySection

                        highlightsSection

                        sessionHistoryEntry

                        progressDisclosureSection

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
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
                        .foregroundStyle(.secondary)
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

                            if let aiFeedback = session.aiCoachFeedback {
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
        if let aiFeedback = session.aiCoachFeedback {
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
