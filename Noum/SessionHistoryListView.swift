import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Session History List Model

/// Pure filtering / sorting / grouping behind the session-history list, so
/// search behavior and low-signal collapsing are testable without SwiftUI.
enum SessionHistorySort: String, CaseIterable, Identifiable {
    case newest
    case highestScore
    case longest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "Newest"
        case .highestScore: return "Highest score"
        case .longest: return "Longest"
        }
    }
}

enum SessionHistoryListGroup: Identifiable {
    case row(PracticeSession)
    /// A run of consecutive low-signal reps, collapsed into one quiet line
    /// so abandoned 6-second warmups stop burying the reps worth revisiting.
    case collapsed([PracticeSession])

    var id: String {
        switch self {
        case .row(let session):
            return "row.\(session.id.uuidString)"
        case .collapsed(let sessions):
            return "collapsed.\(sessions.first?.id.uuidString ?? "empty").\(sessions.count)"
        }
    }
}

enum SessionHistoryListModel {

    /// A rep too thin to deserve a full row: a 1–2/10 read, or one that was
    /// never scored AND barely ran. An unscored rep of real length is still
    /// a real rep (the user bailed on the summary, not the speaking).
    static func isLowSignal(_ session: PracticeSession) -> Bool {
        if let score = session.score {
            return score <= 2
        }
        return session.duration < 20
    }

    static func matches(_ session: PracticeSession, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }

        var haystacks: [String] = [modeLabel(for: session.mode)]
        if let headline = session.headline { haystacks.append(headline) }
        if let summary = session.coachSummary { haystacks.append(summary) }
        if let prompt = session.prompt { haystacks.append(prompt) }
        haystacks.append(session.transcript)

        return haystacks.contains { $0.lowercased().contains(needle) }
    }

    static func apply(
        _ sessions: [PracticeSession],
        mode: PracticeMode?,
        query: String,
        sort: SessionHistorySort
    ) -> [PracticeSession] {
        var result = sessions
        if let mode {
            result = result.filter { $0.mode == mode }
        }
        result = result.filter { matches($0, query: query) }

        switch sort {
        case .newest:
            return result.sorted { $0.date > $1.date }
        case .highestScore:
            return result.sorted { lhs, rhs in
                let l = lhs.score ?? -1
                let r = rhs.score ?? -1
                if l != r { return l > r }
                return lhs.date > rhs.date
            }
        case .longest:
            return result.sorted { lhs, rhs in
                if lhs.duration != rhs.duration { return lhs.duration > rhs.duration }
                return lhs.date > rhs.date
            }
        }
    }

    /// Collapses runs of 2+ consecutive low-signal reps. A single one stays
    /// a normal row — hiding it would feel like the app editing history.
    /// Collapsing is skipped entirely while searching: a query means the
    /// user is hunting, so every match shows.
    static func grouped(_ sessions: [PracticeSession], collapsingLowSignal: Bool) -> [SessionHistoryListGroup] {
        guard collapsingLowSignal else { return sessions.map(SessionHistoryListGroup.row) }

        var groups: [SessionHistoryListGroup] = []
        var pendingLowSignal: [PracticeSession] = []

        func flushPending() {
            if pendingLowSignal.count >= 2 {
                groups.append(.collapsed(pendingLowSignal))
            } else {
                groups.append(contentsOf: pendingLowSignal.map(SessionHistoryListGroup.row))
            }
            pendingLowSignal = []
        }

        for session in sessions {
            if isLowSignal(session) {
                pendingLowSignal.append(session)
            } else {
                flushPending()
                groups.append(.row(session))
            }
        }
        flushPending()

        return groups
    }

    static func collapsedLabel(for sessions: [PracticeSession]) -> String {
        "\(sessions.count) short or incomplete reps"
    }

    static func modeLabel(for mode: PracticeMode) -> String {
        mode.displayLabel
    }
}

#if canImport(SwiftUI)

// MARK: - Session History List View

/// The full session log, demoted from the Review home to its own surface:
/// mode chips, per-mode track-record cards, search, sort, and the row list
/// with low-signal runs collapsed. The Review home keeps the insights; this
/// is where you come to find a specific rep.
struct SessionHistoryListView: View {

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var suddenDeathRunHistoryStore = SuddenDeathRunHistoryStore.shared
    @State private var selectedModeFilter: PracticeMode? = nil
    @State private var query = ""
    @State private var sort: SessionHistorySort = .newest
    @State private var sessionToDelete: PracticeSession?
    @State private var expandedGroupIDs: Set<String> = []
    @Binding var navigationPath: NavigationPath
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
    }

    // MARK: - Derived data

    private var sessions: [PracticeSession] {
        sessionStore.sessions.sorted { $0.date > $1.date }
    }

    private var visibleSessions: [PracticeSession] {
        SessionHistoryListModel.apply(sessions, mode: selectedModeFilter, query: query, sort: sort)
    }

    private var groups: [SessionHistoryListGroup] {
        SessionHistoryListModel.grouped(
            visibleSessions,
            collapsingLowSignal: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    private var leadSummary: String {
        let total = sessions.count
        var line = "\(total) session\(total == 1 ? "" : "s") saved"
        let scores = sessions.compactMap(\.score)
        if !scores.isEmpty {
            let average = Double(scores.reduce(0, +)) / Double(scores.count)
            line += ". Average score \(String(format: "%.1f", average))"
        }
        return line + "."
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(leadSummary)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .accessibilityIdentifier("history.leadSummary")

                    modeFilterChips
                        .padding(.bottom, 12)

                    modeBreakdownSection

                    searchAndSortRow
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 12)

                    sessionListHeader

                    sessionListSection

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Session history")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.list.screen")
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

    // MARK: - Search + sort

    private var searchAndSortRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Search prompts, transcripts, reads", text: $query)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("history.list.search")
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            Menu {
                ForEach(SessionHistorySort.allCases) { option in
                    Button {
                        sort = option
                    } label: {
                        if sort == option {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption.weight(.bold))
                    Text(sort.label)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }
            .accessibilityIdentifier("history.list.sort")
        }
    }

    // MARK: - Mode filter chips

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
            if reduceMotion {
                selectedModeFilter = mode
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { selectedModeFilter = mode }
            }
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

    // MARK: - Mode breakdown cards

    @ViewBuilder
    private var modeBreakdownSection: some View {
        if selectedModeFilter == nil {
            CrossModeHistoryBreakdownCard(
                sessions: visibleSessions,
                onSelectMode: { mode in
                    if reduceMotion {
                        selectedModeFilter = mode
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedModeFilter = mode }
                    }
                }
            )
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 16)
        }

        if selectedModeFilter == .suddenDeath {
            SuddenDeathHistoryBreakdownCard(
                runs: suddenDeathRunHistoryStore.runs,
                onSelectDifficulty: { difficulty in
                    navigationPath.append(
                        AppDestination.suddenDeathDifficultyDetail(difficulty: difficulty)
                    )
                },
                sessions: visibleSessions,
                onSelectBestRep: { sessionID in
                    navigationPath.append(
                        AppDestination.sessionDetail(sessionID: sessionID)
                    )
                }
            )
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 16)
        }

        if selectedModeFilter == .ahCounter {
            AhCounterHistoryBreakdownCard(
                sessions: visibleSessions,
                onSelectCleanestRep: { sessionID in
                    navigationPath.append(
                        AppDestination.sessionDetail(sessionID: sessionID)
                    )
                }
            )
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 16)
        }

        if selectedModeFilter == .timed {
            TimedHistoryBreakdownCard(
                sessions: visibleSessions,
                onSelectBestRep: { sessionID in
                    navigationPath.append(
                        AppDestination.sessionDetail(sessionID: sessionID)
                    )
                }
            )
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 16)
        }

        if selectedModeFilter == .imConversation {
            IMHistoryBreakdownCard(
                sessions: visibleSessions,
                onSelectScenario: { scenario in
                    navigationPath.append(
                        AppDestination.imScenarioDetail(scenario: scenario)
                    )
                }
            )
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Session list

    private var sessionListHeader: some View {
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
    }

    private var sectionTitle: String {
        if let mode = selectedModeFilter {
            return "\(SessionHistoryListModel.modeLabel(for: mode)) sessions"
        }
        return "All sessions"
    }

    @ViewBuilder
    private var sessionListSection: some View {
        if visibleSessions.isEmpty {
            emptyListState
                .padding(.horizontal, Spacing.screenH)
        } else {
            ForEach(groups) { group in
                switch group {
                case .row(let session):
                    sessionLink(session)
                case .collapsed(let collapsedSessions):
                    collapsedGroupRow(id: group.id, sessions: collapsedSessions)
                    if expandedGroupIDs.contains(group.id) {
                        ForEach(collapsedSessions) { session in
                            sessionLink(session)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenH)
        }
    }

    private func sessionLink(_ session: PracticeSession) -> some View {
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

    private func collapsedGroupRow(id: String, sessions collapsedSessions: [PracticeSession]) -> some View {
        let isExpanded = expandedGroupIDs.contains(id)
        return Button {
            if reduceMotion {
                toggleGroup(id)
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { toggleGroup(id) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "tray.full")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SessionHistoryListModel.collapsedLabel(for: collapsedSessions))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(isExpanded ? "Tap to tuck them away" : "Tap to show them")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6).opacity(0.6), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .accessibilityIdentifier("history.list.collapsedGroup")
    }

    private func toggleGroup(_ id: String) {
        if expandedGroupIDs.contains(id) {
            expandedGroupIDs.remove(id)
        } else {
            expandedGroupIDs.insert(id)
        }
    }

    // MARK: - Row

    private func sessionRow(_ session: PracticeSession) -> some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColor.tint(for: session.mode))
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(session.headline ?? SessionHistoryListModel.modeLabel(for: session.mode))
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
                        Text(SessionHistoryDetailPresentation.durationLabel(for: session))
                        if session.fillerWordCount > 0 {
                            Text("·")
                            Text("\(session.fillerWordCount) fillers")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                    if let summary = SessionHistoryRowPreview.text(for: session) {
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

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return .green
        case 5...7: return .primary
        default: return .orange
        }
    }

    // MARK: - Empty state

    private var emptyListState: some View {
        Text(query.isEmpty ? "No sessions for this mode yet" : "No sessions match your search")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }
}

#endif
