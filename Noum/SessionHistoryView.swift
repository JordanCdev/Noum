import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
struct SessionHistoryView: View {
    private let overviewColumns = [
        GridItem(.adaptive(minimum: 110), spacing: 10, alignment: .top)
    ]
    private let trendColumns = [
        GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)
    ]
    private let metricColumns = [
        GridItem(.adaptive(minimum: 88), spacing: 10, alignment: .top)
    ]

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @State private var selectedAchievementID: String?
    @Environment(\.dismiss) private var dismiss

    private var sessions: [PracticeSession] {
        sessionStore.sessions.sorted { $0.date > $1.date }
    }

    private var totalSessions: Int { sessions.count }
    private var averageScoreText: String {
        let scores = sessions.compactMap(\.score)
        guard !scores.isEmpty else { return "N/A" }
        let average = Double(scores.reduce(0, +)) / Double(scores.count)
        return String(format: "%.1f/10", average)
    }

    private var strongestModeText: String {
        let grouped = Dictionary(grouping: sessions, by: \.mode)
        let ranked = grouped.max { lhs, rhs in
            let lhsAverage = averageScore(for: lhs.value)
            let rhsAverage = averageScore(for: rhs.value)
            return lhsAverage < rhsAverage
        }?.key
        return ranked.map(label(for:)) ?? "Still forming"
    }

    private var primaryInsight: String {
        if let plan = CoachingPlanner.plan(for: sessions, profile: coachingProfileStore.profile) {
            return plan.encouragement
        }
        return "Your session history turns into clearer coaching once a few more reps are logged."
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: sessions,
            profile: coachingProfileStore.profile
        )
    }

    private var recentSessionsForProgress: [PracticeSession] {
        Array(sessions.prefix(8).reversed())
    }

    private var scoreTrendValues: [Double] {
        recentSessionsForProgress.compactMap { session in
            guard let score = session.score else { return nil }
            return Double(score)
        }
    }

    private var fillerControlValues: [Double] {
        recentSessionsForProgress.map { session in
            Double(max(0, 10 - min(session.fillerWordCount, 10)))
        }
    }

    private var pacingStabilityValues: [Double] {
        recentSessionsForProgress.map { session in
            let distance = abs(Double(session.wordsPerMinute) - 130)
            return max(0, 10 - min(distance / 12, 10))
        }
    }

    private var progressionSummary: String {
        guard let first = recentSessionsForProgress.first,
              let last = recentSessionsForProgress.last else {
            return "A few more sessions will make your communication trend easier to read."
        }

        let scoreDelta = (last.score ?? 0) - (first.score ?? 0)
        let fillerDelta = first.fillerWordCount - last.fillerWordCount
        let paceDelta = abs(last.wordsPerMinute - 130) - abs(first.wordsPerMinute - 130)

        if scoreDelta >= 2 || fillerDelta >= 3 {
            return "Your recent sessions show real movement. Delivery is getting sharper, and your speaking habits are starting to look more controlled."
        }

        if scoreDelta <= -2 || fillerDelta <= -3 || paceDelta > 20 {
            return "Your results are still uneven. You’re capable of strong moments, but the consistency piece has not settled yet."
        }

        return "You’re building a base, but the main story right now is consistency. The next few sessions should focus on keeping your quality steady under different conditions."
    }

    private var identityEvolutionText: String {
        let identities = recentSessionsForProgress.compactMap { session -> String? in
            let identity = PracticeEvaluator.speakingIdentity(
                for: session.transcript,
                profile: coachingProfileStore.profile
            ).identity
            return identity.isEmpty ? nil : identity
        }

        guard !identities.isEmpty else { return "Still taking shape" }

        var compact: [String] = []
        for identity in identities where compact.last != identity {
            compact.append(identity)
        }
        return compact.joined(separator: " -> ")
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 0.91),
                    Color.white,
                    Color(red: 0.93, green: 0.96, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overviewPanel
                        journeyPanel
                        progressOverTimePanel

                        Text("Recent Sessions")
                            .font(.title3.weight(.bold))
                            .padding(.horizontal, 2)

                        ForEach(sessions) { session in
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
                                sessionCard(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .navigationTitle("Practice History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("No sessions yet")
                .font(.title3.weight(.bold))
            Text("Your practice runs will show up here with the key takeaways, strongest sessions, and what to work on next.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(24)
    }

    private var overviewPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Communication Read")
                .font(.title3.weight(.bold))

            Text(primaryInsight)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: overviewColumns, alignment: .leading, spacing: 10) {
                overviewMetric(title: "Sessions", value: "\(totalSessions)", tint: .blue)
                overviewMetric(title: "Average", value: averageScoreText, tint: .green)
                overviewMetric(title: "Best Mode", value: strongestModeText, tint: .purple)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var progressOverTimePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress Over Time")
                .font(.title3.weight(.bold))

            Text(progressionSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: trendColumns, alignment: .leading, spacing: 10) {
                trendCard(
                    title: "Session Score",
                    subtitle: trendDeltaText(for: scoreTrendValues, positiveIsImprovement: true, suffix: " pts"),
                    values: scoreTrendValues,
                    tint: .green
                )
                trendCard(
                    title: "Filler Control",
                    subtitle: trendDeltaText(for: fillerControlValues, positiveIsImprovement: true, suffix: " pts"),
                    values: fillerControlValues,
                    tint: .orange
                )
            }

            trendCard(
                title: "Pacing Stability",
                subtitle: "\(recentSessionsForProgress.last?.wordsPerMinute ?? 0) WPM recently",
                values: pacingStabilityValues,
                tint: .blue
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Speaking Identity Evolution")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(identityEvolutionText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var journeyPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Challenges + Achievements")
                .font(.title3.weight(.bold))

            Text(retentionSnapshot.motivationLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            activeChallengeCard
            achievementsCard
        }
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func sessionCard(_ session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionTitle(for: session))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(sessionSubtitle(for: session))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(label(for: session.mode))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sessionColor(for: session.mode))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(sessionColor(for: session.mode).opacity(0.12), in: Capsule())
            }

            Text(sessionSummary(for: session))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                compactMetric(label: "Score", value: session.score.map { "\($0)/10" } ?? "Pending")
                compactMetric(label: "Duration", value: "\(Int(session.duration))s")
                compactMetric(label: "Fillers", value: "\(session.fillerWordCount)")
                if let imDetails = session.imConversationDetails {
                    compactMetric(label: "Tone", value: imDetails.actualTone ?? imDetails.setup.targetTone.title)
                }
            }

            if let outcome = session.imConversationDetails?.outcome {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text(outcome.title)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func overviewMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func trendCard(
        title: String,
        subtitle: String,
        values: [Double],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)

            SparklineView(values: values, color: tint)
                .frame(height: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func compactMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var activeChallengeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Challenge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: 10) {
                PulseBadge(systemImage: "bolt.fill", tint: .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(retentionSnapshot.activeChallenge.title)
                        .font(.headline)
                    Text(retentionSnapshot.activeChallenge.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(retentionSnapshot.activeChallenge.rewardLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                    SparkleRibbon(tint: .orange)
                }
            }

            ShimmerProgressBar(progress: retentionSnapshot.activeChallenge.progress, tint: .blue)

            VStack(alignment: .leading, spacing: 6) {
                Text(retentionSnapshot.activeChallenge.progressLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Text(retentionSnapshot.motivationLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Achievements")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(retentionSnapshot.achievements.prefix(3)) { achievement in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selectedAchievementID = selectedAchievementID == achievement.id ? nil : achievement.id
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Group {
                                if achievement.isUnlocked {
                                    PulseBadge(systemImage: achievement.symbolName, tint: .green)
                                } else {
                                    Image(systemName: achievement.symbolName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, height: 24)
                                        .padding(12)
                                        .background(Color.black.opacity(0.06), in: Circle())
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(achievement.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(achievement.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                Text(achievement.progressLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(achievement.isUnlocked ? .green : .secondary)
                                Image(systemName: selectedAchievementID == achievement.id ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if selectedAchievementID == achievement.id {
                            VStack(alignment: .leading, spacing: 8) {
                                ShimmerProgressBar(
                                    progress: achievement.progress,
                                    tint: achievement.isUnlocked ? .green : .blue
                                )
                                Text(
                                    achievement.isUnlocked
                                        ? "Unlocked. This is now part of your communication identity."
                                        : "Keep going. This one unlocks once the habit becomes repeatable."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sessionTitle(for session: PracticeSession) -> String {
        session.headline ?? label(for: session.mode)
    }

    private func sessionSubtitle(for session: PracticeSession) -> String {
        session.date.formatted(date: .abbreviated, time: .shortened)
    }

    private func sessionSummary(for session: PracticeSession) -> String {
        if let coachSummary = session.coachSummary, !coachSummary.isEmpty {
            return coachSummary
        }
        if let outcome = session.imConversationDetails?.outcome?.summary, !outcome.isEmpty {
            return outcome
        }
        return session.transcript
    }

    private func sessionColor(for mode: PracticeMode) -> Color {
        switch mode {
        case .timed: return .blue
        case .suddenDeath: return .orange
        case .ahCounter: return .green
        case .imConversation: return .purple
        }
    }

    private func label(for mode: PracticeMode) -> String {
        switch mode {
        case .timed: return "Timed"
        case .suddenDeath: return "Sudden Death"
        case .ahCounter: return "Ah-Counter"
        case .imConversation: return "IM Mode"
        }
    }

    private func averageScore(for sessions: [PracticeSession]) -> Double {
        let scores = sessions.compactMap(\.score)
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private func trendDeltaText(
        for values: [Double],
        positiveIsImprovement: Bool,
        suffix: String
    ) -> String {
        guard let first = values.first, let last = values.last else {
            return "Still gathering data"
        }

        let rawDelta = last - first
        let improvementDelta = positiveIsImprovement ? rawDelta : -rawDelta
        let rounded = Int(abs(improvementDelta).rounded())

        if rounded == 0 {
            return "Holding steady"
        }

        if improvementDelta > 0 {
            return "Up \(rounded)\(suffix)"
        }

        return "Down \(rounded)\(suffix)"
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

private struct SessionHistoryDetailView: View {
    let session: PracticeSession
    let insights: [String]
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared

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
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 0.91),
                    Color.white,
                    Color(red: 0.93, green: 0.96, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard

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
                .padding(18)
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.headline ?? "Session Detail")
                .font(.title2.weight(.bold))

            Text(session.coachSummary ?? "Review the strongest signal from this practice run and what to improve next.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                detailMetric(title: "Mode", value: modeLabel, tint: .purple)
                detailMetric(title: "Score", value: session.score.map { "\($0)/10" } ?? "Pending", tint: .green)
                detailMetric(title: "Duration", value: "\(Int(session.duration))s", tint: .blue)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var sessionMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Metrics")
                .font(.headline)

            HStack(spacing: 10) {
                detailMetric(title: "Fillers", value: "\(session.fillerWordCount)", tint: .red)
                detailMetric(title: "WPM", value: "\(session.wordsPerMinute)", tint: .indigo)
                detailMetric(title: "XP", value: session.xpEarned.map(String.init) ?? "Pending", tint: .orange)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func conversationReadCard(_ imDetails: IMConversationDetails) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What Changed")
                .font(.headline)

            HStack(spacing: 10) {
                detailMetric(title: "Target Tone", value: imDetails.setup.targetTone.title, tint: .blue)
                if let finalState = imDetails.finalState {
                    detailMetric(title: "Trust", value: "\(finalState.normalizedTrust)/10", tint: .teal)
                    detailMetric(title: "Tension", value: "\(finalState.normalizedTension)/10", tint: .orange)
                }
            }

            if let outcome = imDetails.outcome {
                VStack(alignment: .leading, spacing: 6) {
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
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
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
                .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if let profile = coachingProfileStore.profile {
                Text("North star: \(profile.communicationNorthStar)")
                    .font(.subheadline.weight(.semibold))
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
                        .background(Color.blue, in: Circle())
                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
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
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
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
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(18)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
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
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
