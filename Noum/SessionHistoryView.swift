import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

// MARK: - Session History View (Redesigned)

struct SessionHistoryView: View {

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var suddenDeathRunHistoryStore = SuddenDeathRunHistoryStore.shared
    @State private var selectedModeFilter: PracticeMode? = nil
    @State private var sessionToDelete: PracticeSession?
    @State private var showTrends = false
    @Binding var navigationPath: NavigationPath
    @Environment(\.dismiss) private var dismiss

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

    private var filteredSessions: [PracticeSession] {
        guard let filter = selectedModeFilter else { return sessions }
        return sessions.filter { $0.mode == filter }
    }

    private var totalSessions: Int { sessions.count }

    private var averageScoreText: String {
        let scores = sessions.compactMap(\.score)
        guard !scores.isEmpty else { return "--" }
        let average = Double(scores.reduce(0, +)) / Double(scores.count)
        return String(format: "%.1f", average)
    }

    private var strongestModeText: String {
        let grouped = Dictionary(grouping: sessions, by: \.mode)
        let ranked = grouped.max { lhs, rhs in
            averageScore(for: lhs.value) < averageScore(for: rhs.value)
        }?.key
        return ranked.map(modeLabel(for:)) ?? "--"
    }

    private var recentForTrends: [PracticeSession] {
        Array(sessions.prefix(8).reversed())
    }

    private var scoreTrend: [Double] {
        recentForTrends.compactMap { $0.score.map(Double.init) }
    }

    private var fillerTrend: [Double] {
        recentForTrends.map { Double(max(0, 10 - min($0.fillerWordCount, 10))) }
    }

    private var pacingTrend: [Double] {
        recentForTrends.map { session in
            let distance = abs(Double(session.wordsPerMinute) - 130)
            return max(0, 10 - min(distance / 12, 10))
        }
    }

    /// Representative tint for the MistakeReplay hero halo. Mirrors the
    /// MistakeReplayCard's own sourcing priority (low-score ≤5 in 14d,
    /// then high-filler ≥6 in 14d) so the halo color matches the mode
    /// the user is most likely about to replay. Falls back to brandBlue
    /// when nothing qualifies (the card itself renders EmptyView in that
    /// case, so the halo is invisible anyway).
    private var mistakeReplayHaloTint: Color {
        let now = Date()
        let cutoff14 = now.addingTimeInterval(-14 * 24 * 3600)
        let recent = sessions
        if let lowScore = recent.first(where: { session in
            guard session.date >= cutoff14 else { return false }
            guard let score = session.score else { return false }
            return score <= 5
        }) {
            return AppColor.tint(for: lowScore.mode)
        }
        if let highFiller = recent.first(where: { session in
            session.date >= cutoff14 && session.fillerWordCount >= 6
        }) {
            return AppColor.tint(for: highFiller.mode)
        }
        return AppColor.brandBlue
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

                        // --- Summary Strip ---
                        summaryStrip
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.top, 8)
                            .padding(.bottom, 20)

                        // --- Trends (collapsible) ---
                        trendsSection
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.bottom, 20)

                        // --- Replay misses (specific past sessions) ---
                        // Hero halo + tinted shadow draw the eye; the tint
                        // is the mode of the next session likely to be
                        // replayed (matches `MistakeReplayCard`'s own
                        // sourcing priority).
                        MistakeReplayCard(sessionStore: sessionStore) { destination in
                            navigationPath.append(destination)
                        }
                        .background(heroHalo(tint: mistakeReplayHaloTint))
                        .shadow(color: mistakeReplayHaloTint.opacity(0.16), radius: 16, x: 0, y: 8)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 20)

                        // --- Mistakes to fix (Duolingo-style review surface) ---
                        // Brand-blue halo: this card surfaces durable
                        // analytics-level weaknesses, so it lives in the
                        // analytics/rating register.
                        WeakAreasCard(sessionStore: sessionStore) { target in
                            navigationPath.append(target.destination)
                        }
                        .background(heroHalo(tint: AppColor.brandBlue))
                        .shadow(color: AppColor.brandBlue.opacity(0.14), radius: 16, x: 0, y: 8)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 20)

                        // --- Mode Filter ---
                        modeFilterChips
                            .padding(.bottom, 12)

                        // --- Sudden Death history breakdown ---
                        // Surfaces the per-difficulty track record (best,
                        // avg, clean) on the Sudden Death filter so the
                        // engine's honest data lives in the History
                        // surface, not only on the per-run Result screen.
                        // Self-hides on cold start (no SD runs yet) and
                        // when any other filter is selected.
                        if selectedModeFilter == .suddenDeath {
                            SuddenDeathHistoryBreakdownCard(
                                runs: suddenDeathRunHistoryStore.runs,
                                onSelectDifficulty: { difficulty in
                                    navigationPath.append(
                                        AppDestination.suddenDeathDifficultyDetail(difficulty: difficulty)
                                    )
                                }
                            )
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.bottom, 16)
                        }

                        // --- Ah-Counter history breakdown ---
                        // Same shape as the SD breakdown, sourced from the
                        // generic PracticeSession store (Ah-Counter doesn't
                        // have an engine-specific run store; the filler-rate
                        // signal lives on each PracticeSession row already).
                        // Tapping the "cleanest rep" cell pushes the session
                        // detail view — same destination as the row tap.
                        if selectedModeFilter == .ahCounter {
                            AhCounterHistoryBreakdownCard(
                                sessions: filteredSessions,
                                onSelectCleanestRep: { sessionID in
                                    navigationPath.append(
                                        AppDestination.sessionDetail(sessionID: sessionID)
                                    )
                                }
                            )
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.bottom, 16)
                        }

                        // --- Timed history breakdown ---
                        // Per-mode track record for Timed. Surfaces average
                        // score + in-zone count + average WPM + best rep
                        // with a 7-day vs prior-7-day trend chip. Self-hides
                        // on cold start. Tapping the "best rep" cell pushes
                        // the session detail view.
                        if selectedModeFilter == .timed {
                            TimedHistoryBreakdownCard(
                                sessions: filteredSessions,
                                onSelectBestRep: { sessionID in
                                    navigationPath.append(
                                        AppDestination.sessionDetail(sessionID: sessionID)
                                    )
                                }
                            )
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.bottom, 16)
                        }

                        // --- IM history breakdown ---
                        // Per-scenario track record across the four built-in
                        // IM setups. Reads from the conversation metadata
                        // on each PracticeSession (no new store) so a user
                        // who's been working "Difficult Conversation" can
                        // see their trust + tension trend without leaving
                        // History. Self-hides until at least one rep has
                        // recorded scenario metadata.
                        if selectedModeFilter == .imConversation {
                            IMHistoryBreakdownCard(
                                sessions: filteredSessions,
                                onSelectScenario: { scenario in
                                    navigationPath.append(
                                        AppDestination.imScenarioDetail(scenario: scenario)
                                    )
                                }
                            )
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.bottom, 16)
                        }

                        // --- Section Header ---
                        // Sentence-case cardTitle + hairline divider. Reads as
                        // a premium app sentence, not a wireframe label.
                        VStack(alignment: .leading, spacing: 10) {
                            Text(sectionTitle)
                                .font(Typography.cardTitle)
                                .foregroundStyle(.primary)
                            Rectangle()
                                .fill(AppColor.subtleBorder)
                                .frame(height: 1)
                        }
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 12)

                        // --- Session List ---
                        if filteredSessions.isEmpty {
                            emptyFilterState
                                .padding(.horizontal, Spacing.screenH)
                        } else {
                            ForEach(filteredSessions) { session in
                                NavigationLink {
                                    SessionHistoryDetailView(
                                        session: session,
                                        insights: CoachingPlanner.sessionInsights(
                                            for: session,
                                            comparedTo: sessions,
                                            profile: coachingProfileStore.profile
                                        )
                                    )
                                } label: {
                                    sessionRow(session)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("history.row.\(session.id.uuidString)")
                                .contextMenu {
                                    Button(role: .destructive) {
                                        sessionToDelete = session
                                    } label: {
                                        Label("Delete Session", systemImage: "trash")
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.screenH)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.screen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Delete Session?", isPresented: .init(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    sessionStore.deleteSession(id: session.id)
                    sessionToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This permanently removes this practice session from your history. This cannot be undone.")
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            statPill(value: "\(totalSessions)", label: "Sessions", tint: .blue)
            Spacer(minLength: 0)
            statPill(value: averageScoreText, label: "Avg Score", tint: .green)
            Spacer(minLength: 0)
            statPill(value: strongestModeText, label: "Strongest", tint: .purple)
        }
        .padding(14)
        .background(heroBackground(tint: AppColor.brandBlue, cornerRadius: CornerRadius.large))
        .shadow(color: AppColor.brandBlue.opacity(0.14), radius: 14, x: 0, y: 6)
    }

    // MARK: - Hero Background
    //
    // Mirrors the `HomeCoachCard.coachCardBackground` / `LeagueView.tierCardBackground`
    // pattern: opaque card base + radial tinted wash (0.12 → 0) anchored to the
    // top edge + faint tinted border. Used to lift the summary strip into
    // "hero surface" treatment.
    private func heroBackground(tint: Color, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [tint.opacity(0.12), tint.opacity(0.03), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )
            shape.strokeBorder(tint.opacity(0.18), lineWidth: 1)
        }
    }

    /// Tinted ambient halo + soft shadow used to lift the Replay / Mistakes
    /// cards into hero treatment without modifying their internals. The
    /// halo bleeds beyond the card edges via negative padding so the
    /// glow reads outside the card's own opaque cardBackground.
    private func heroHalo(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: CornerRadius.large + 4, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [tint.opacity(0.18), tint.opacity(0.04), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )
            .blur(radius: 10)
            .padding(-10)
    }

    private func statPill(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trends Section

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showTrends.toggle() }
            } label: {
                HStack {
                    Text("Progress Trends")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showTrends ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showTrends {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        miniTrend(title: "Score", values: scoreTrend, tint: .green)
                        miniTrend(title: "Filler Control", values: fillerTrend, tint: .orange)
                    }
                    miniTrend(title: "Pacing", values: pacingTrend, tint: .blue)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func miniTrend(title: String, values: [Double], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(trendDelta(for: values))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
            }
            SparklineView(values: values, color: tint)
                .frame(height: 32)
        }
        .padding(10)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Mode Filter Chips

    private var modeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", mode: nil)
                filterChip(label: PracticeMode.timed.displayLabel, mode: .timed)
                filterChip(label: PracticeMode.suddenDeath.displayLabel, mode: .suddenDeath)
                filterChip(label: PracticeMode.ahCounter.displayLabel, mode: .ahCounter)
                filterChip(label: PracticeMode.imConversation.displayLabel, mode: .imConversation)
            }
            .padding(.horizontal, Spacing.screenH)
        }
    }

    private func filterChip(label: String, mode: PracticeMode?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedModeFilter = mode }
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    selectedModeFilter == mode ? AppColor.brandBlue : Color(.systemGray6),
                    in: Capsule(style: .continuous)
                )
                .foregroundStyle(selectedModeFilter == mode ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session Row (Compact, Premium Feel)

    private func sessionRow(_ session: PracticeSession) -> some View {
        // Leading mode-tint stripe spans full row height so each row reads
        // visually distinct by mode at a glance — Timed (blue), Sudden
        // Death (orange), Ah-Counter (green), IM (indigo). Tokens via
        // `AppColor.tint(for:)`.
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColor.tint(for: session.mode))
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(session.headline ?? modeLabel(for: session.mode))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let score = session.score {
                            Text("\(score)/10")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(scoreColor(score))
                        }
                    }

                    HStack(spacing: 6) {
                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        Text("·")
                        Text("\(Int(session.duration))s")
                        if session.fillerWordCount > 0 {
                            Text("·")
                            Text("\(session.fillerWordCount) fillers")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                    if let summary = sessionOneLiner(for: session) {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary)
                    .padding(.top, 6)
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)
            .padding(.trailing, 14)
        }
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .padding(.bottom, 8)
    }

    // MARK: - Empty States

    private var emptyState: some View {
        EmptyStateView(
            symbol: "clock.arrow.circlepath",
            title: "Your first session is the hardest",
            body: "One short rep populates this view with score, pacing, and filler trends.",
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

    private var emptyFilterState: some View {
        Text("No sessions for this mode yet")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    private var sectionTitle: String {
        if let mode = selectedModeFilter {
            return "\(modeLabel(for: mode)) sessions"
        }
        return "All sessions"
    }

    // MARK: - Helpers

    private func sessionOneLiner(for session: PracticeSession) -> String? {
        if let summary = session.coachSummary, !summary.isEmpty { return summary }
        if let outcome = session.imConversationDetails?.outcome?.summary, !outcome.isEmpty { return outcome }
        let trimmed = session.transcript.prefix(80)
        return trimmed.isEmpty ? nil : String(trimmed)
    }

    private func modeLabel(for mode: PracticeMode) -> String {
        switch mode {
        case .timed: return "Timed"
        case .suddenDeath: return "Sudden Death"
        case .ahCounter: return "Ah-Counter"
        case .imConversation: return "IM Mode"
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return .green
        case 5...7: return .primary
        default: return .orange
        }
    }

    private func averageScore(for sessions: [PracticeSession]) -> Double {
        let scores = sessions.compactMap(\.score)
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private func trendDelta(for values: [Double]) -> String {
        guard let first = values.first, let last = values.last else { return "" }
        let delta = Int((last - first).rounded())
        if delta == 0 { return "Steady" }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }
}

private struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let normalized = normalizedValues

            ZStack {
                if normalized.count >= 2 {
                    Path { path in
                        for (index, point) in normalized.enumerated() {
                            let x = geometry.size.width * CGFloat(point.x)
                            let y = geometry.size.height * CGFloat(1 - point.y)
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                } else {
                    Capsule()
                        .fill(color.opacity(0.25))
                        .frame(height: 4)
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                ForEach(Array(normalized.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(index == normalized.count - 1 ? color : color.opacity(0.35))
                        .frame(width: index == normalized.count - 1 ? 8 : 6, height: index == normalized.count - 1 ? 8 : 6)
                        .position(
                            x: geometry.size.width * CGFloat(point.x),
                            y: geometry.size.height * CGFloat(1 - point.y)
                        )
                }
            }
        }
    }

    private var normalizedValues: [(x: Double, y: Double)] {
        guard !values.isEmpty else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.001)

        return values.enumerated().map { index, value in
            let x = values.count == 1 ? 0.5 : Double(index) / Double(values.count - 1)
            let y = (value - minValue) / range
            return (x, y)
        }
    }
}

/// Visible to surfaces outside SessionHistoryView (e.g. Growth Library's
/// quote-card deep link) so the source-session detail can be pushed from
/// anywhere. The view is otherwise unchanged — same heroCard, focusCard,
/// transcript card, AI coach read, IM conversation card.
struct SessionHistoryDetailView: View {
    let session: PracticeSession
    let insights: [String]
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @State private var showsFullReview = false

    private var imSessionStreak: Int {
        guard let scenario = session.imConversationDetails?.setup.scenario else { return 0 }
        let imSessions = sessionStore.sessions
            .filter { $0.imConversationDetails?.setup.scenario == scenario }
            .sorted { $0.date > $1.date }

        guard !imSessions.isEmpty else { return 0 }
        var streak = 0
        var currentDay: Date?
        let calendar = Calendar.current

        for session in imSessions {
            if let day = currentDay {
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                if calendar.isDate(session.date, inSameDayAs: day) {
                    continue
                }
                guard calendar.isDate(session.date, inSameDayAs: previousDay) else { break }
            }
            currentDay = session.date
            streak += 1
        }

        return streak
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard

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
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.headline ?? "Session detail")
                .font(.title2.weight(.bold))

            Text(primarySummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                detailMetric(title: "Score", value: session.score.map { "\($0)/10" } ?? "Pending", tint: .green)
                detailMetric(title: "Focus", value: focusLabel, tint: .blue)
                detailMetric(title: "Mode", value: modeLabel, tint: AppColor.tint(for: session.mode))
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
                    detailMetric(title: "Duration", value: "\(Int(session.duration))s", tint: .blue)
                    detailMetric(title: "Fillers", value: "\(session.fillerWordCount)", tint: .red)
                    detailMetric(title: "WPM", value: "\(session.wordsPerMinute)", tint: .indigo)
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var fullReviewToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showsFullReview.toggle()
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
                detailMetric(title: "WPM", value: "\(session.wordsPerMinute)", tint: .indigo)
                detailMetric(title: "XP", value: session.xpEarned.map(String.init) ?? "Pending", tint: .orange)
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func conversationReadCard(_ imDetails: IMConversationDetails) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Full IM review")
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
            return aiFeedback.keyImprovement
        }
        if let firstInsight = insights.first {
            return firstInsight
        }
        return "Focus on saying one clear thing cleanly before adding more detail."
    }

    private var focusLabel: String {
        if session.imConversationDetails != nil {
            return "Next Rep"
        }
        if let xpEarned = session.xpEarned {
            return "+\(xpEarned) XP"
        }
        return "\(Int(session.duration))s"
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

    private func historyBubble(speaker: String, text: String, tint: Color, isLeading: Bool) -> some View {
        VStack(alignment: isLeading ? .leading : .trailing, spacing: 6) {
            Text(speaker)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(isLeading ? .leading : .trailing)
        }
        .frame(maxWidth: 270, alignment: isLeading ? .leading : .trailing)
        .padding(12)
        .background(tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private var modeLabel: String {
        switch session.mode {
        case .timed: return "Timed"
        case .suddenDeath: return "Sudden Death"
        case .ahCounter: return "Ah-Counter"
        case .imConversation: return "IM Mode"
        }
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    SessionHistoryView()
}
#endif
