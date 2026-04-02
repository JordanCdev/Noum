import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
private enum SummaryTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case insights = "Coach"
    case transcript = "Transcript"

    var id: String { rawValue }
}

struct SummaryView: View {
    let transcript: AttributedString
    let fillerCount: Int
    let duration: TimeInterval
    let score: Int?
    let progressSegments: Int
    let xpEarned: Int
    var showDuration: Bool = true
    var practiceTitle: String = "Practice Summary"
    var feedbackOverride: String?
    var headlineOverride: String?
    var scoreBreakdown: [PracticeScoreSegment] = []
    var insights: [String] = []
    var recentSessions: [PracticeSession] = []
    var imConversationDetails: IMConversationDetails? = nil
    var explicitMode: PracticeMode? = nil
    var onSelectPracticeMode: () -> Void = {}
    var onHome: () -> Void = {}
    var onPracticeAgain: () -> Void = {}

    @StateObject private var profile = ProfileManager.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedTab: SummaryTab = .overview
    @State private var displayedXP: Int = 0
    @State private var progress: Double = 0
    @State private var currentLevel: String = ""
    @State private var nextLevel: String = ""
    @State private var xpToNext: Int = 0
    @State private var visibleSegments = 0
    @State private var didApplyXP = false
    @State private var aiFeedback: AICoachFeedback?
    @State private var isRequestingAIFeedback = false
    @State private var aiError: String?
    @State private var celebrationVisible = false
    @State private var lockedTranscriptText: String?
    @State private var lockedFillerCount: Int?
    @State private var lockedDuration: TimeInterval?
    @State private var lockedScore: Int?
    @State private var lockedFeedbackOverride: String?
    @State private var lockedHeadlineOverride: String?
    @State private var lockedScoreBreakdown: [PracticeScoreSegment] = []
    @State private var lockedInsights: [String] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let aiCoachService: AICoachServicing = AICoachService()

    private var transcriptText: String {
        lockedTranscriptText ?? String(transcript.characters)
    }

    private var transcriptWordCount: Int {
        transcriptText.split { !$0.isLetter && !$0.isNumber }.count
    }

    private var actualToneText: String? {
        imConversationDetails?.actualTone
    }

    private var targetToneText: String? {
        imConversationDetails?.setup.targetTone.title
    }

    private var nextRelationshipChallenge: String? {
        guard let relationship = imConversationDetails?.relationshipSnapshot else { return nil }
        return relationship.nextSessionHook(profile: coachingProfileStore.profile)
    }

    private var communicationNorthStar: String? {
        coachingProfileStore.profile?.communicationNorthStar
    }

    private var motivationSummary: String? {
        coachingProfileStore.profile?.motivationalSummary
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: sessionStore.sessions,
            profile: coachingProfileStore.profile
        )
    }

    private var recentWindow: [PracticeSession] {
        Array(sessionStore.sessions.prefix(5))
    }

    private var strongestMode: PracticeMode? {
        CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)?.strongestMode
    }

    private var summaryRecommendation: RecommendationBiasBlueprint {
        RecommendationBiasEngine.blueprint(
            profile: coachingProfileStore.profile,
            input: AIHomeRecommendationInput(
                recentSessionSummary: recentWindowSummary,
                averageFillers: averageFillers,
                averageDuration: averageDuration,
                averageWordsPerMinute: averagePace,
                fillerTrendDelta: 0,
                durationTrendDelta: 0,
                paceTrendDelta: 0,
                averageWordCount: averageWordCount,
                strongestMode: strongestMode,
                currentIdentity: currentIdentity.identity,
                currentIdentityEvidence: currentIdentity.evidence,
                styleAlignmentScore: 0,
                sessionStreak: sessionStreak,
                daysSinceLastSession: daysSinceLastSession,
                preferredModeBias: "",
                preferredToneBias: "",
                preferredScenarioBias: "",
                modeBenefitBias: ""
            ),
            plan: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
        )
    }

    private var currentMode: PracticeMode {
        if let explicitMode { return explicitMode }
        if imConversationDetails != nil { return .imConversation }
        let title = practiceTitle.lowercased()
        if title.contains("sudden") { return .suddenDeath }
        if title.contains("ah-counter") || title.contains("ah counter") { return .ahCounter }
        return .timed
    }

    private var shouldPushRecommendedMode: Bool {
        summaryRecommendation.recommendedMode != currentMode
    }

    private var primaryActionTitle: String {
        shouldPushRecommendedMode ? "Open Recommended Next Rep" : (scoreValue <= 5 ? "Practice Again Now" : "Practice Again")
    }

    private var secondaryActionTitle: String {
        shouldPushRecommendedMode ? "Run This Drill Again" : "Choose Another Mode"
    }

    private var imSessionStreak: Int {
        guard let scenario = imConversationDetails?.setup.scenario else { return 0 }
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

    private var scoreValue: Int {
        if let lockedScore { return lockedScore }
        if let score { return score }
        if effectiveDuration < 4 || transcriptWordCount < 4 { return 1 }
        if effectiveDuration < 8 || transcriptWordCount < 8 { return max(2, 5 - effectiveFillerCount) }
        return max(3, min(8, 7 - effectiveFillerCount))
    }

    private var headline: String {
        if let lockedHeadlineOverride { return lockedHeadlineOverride }
        if let headlineOverride { return headlineOverride }
        switch scoreValue {
        case 9...10: return "Strong delivery"
        case 7...8: return "Good control"
        case 4...6: return "Room to sharpen"
        default: return "Needs another rep"
        }
    }

    private var feedback: String {
        if let lockedFeedbackOverride { return lockedFeedbackOverride }
        if let feedbackOverride { return feedbackOverride }
        if effectiveDuration < 4 || transcriptWordCount < 4 {
            return "That rep ended before the answer really began. Go again with a clear opening, one point, and a clean finish."
        }
        if effectiveDuration < 8 || transcriptWordCount < 8 {
            return "This was too brief to show control yet. Push the next answer further so the idea has time to land."
        }

        switch scoreValue {
        case 8...10:
            return "A convincing rep. Keep that same control while raising the difficulty."
        case 6...7:
            return "There is a solid response in here. One stronger opening sentence would make it feel more complete."
        case 4...5:
            return "The idea started to form, but it needs more structure and follow-through."
        default:
            return "Go again straight away and aim for a steadier opening with one clear supporting point."
        }
    }

    private var scoreAccent: Color {
        switch scoreValue {
        case 8...10: return Color(red: 0.10, green: 0.56, blue: 0.40)
        case 5...7: return Color(red: 0.83, green: 0.52, blue: 0.10)
        default: return Color(red: 0.74, green: 0.22, blue: 0.20)
        }
    }

    private var visibleBreakdown: [PracticeScoreSegment] {
        Array(effectiveScoreBreakdown.prefix(visibleSegments))
    }

    private var derivedInsights: [String] {
        if !lockedInsights.isEmpty { return lockedInsights }
        if !insights.isEmpty { return insights }
        let previousSessions = Array(recentSessions.dropFirst())
        guard !previousSessions.isEmpty else {
            return ["Finish a few more sessions and this screen will start surfacing trend-based coaching."]
        }

        let averageDuration = previousSessions.map(\.duration).reduce(0, +) / Double(previousSessions.count)
        let averageFillers = previousSessions.map(\.fillerWordCount).reduce(0, +) / previousSessions.count

        var messages: [String] = []
        if duration > averageDuration {
            messages.append("You stayed with this answer longer than your recent average.")
        } else {
            messages.append("This answer ended sooner than your recent average, so push the middle section further next time.")
        }

        if fillerCount < averageFillers {
            messages.append("Your filler count improved against your recent baseline.")
        } else if fillerCount > averageFillers {
            messages.append("Filler words rose above your recent baseline. Try a slower opening.")
        }

        messages.append("You now have \(recentSessions.count) saved practice session\(recentSessions.count == 1 ? "" : "s") to compare against.")
        return Array(messages.prefix(3))
    }

    private var effectiveFillerCount: Int {
        lockedFillerCount ?? fillerCount
    }

    private var effectiveDuration: TimeInterval {
        lockedDuration ?? duration
    }

    private var effectiveScoreBreakdown: [PracticeScoreSegment] {
        lockedScoreBreakdown.isEmpty ? scoreBreakdown : lockedScoreBreakdown
    }

    private var lightweightSignals: [String] {
        Array(derivedInsights.prefix(aiFeedback == nil ? 2 : 1))
    }

    private var latestSessionID: UUID? {
        recentSessions.first?.id ?? sessionStore.sessions.first?.id
    }

    private var recentWindowSummary: String {
        guard !recentWindow.isEmpty else { return "No recent sessions yet." }
        return recentWindow.map { session in
            let label: String
            switch session.mode {
            case .timed: label = "Timed"
            case .suddenDeath: label = "Sudden Death"
            case .ahCounter: label = "Ah-Counter"
            case .imConversation: label = "IM"
            }
            return "\(label): \(session.fillerWordCount) fillers, \(Int(session.duration))s"
        }.joined(separator: " • ")
    }

    private var averageFillers: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return Double(recentWindow.map(\.fillerWordCount).reduce(0, +)) / Double(recentWindow.count)
    }

    private var averageDuration: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return recentWindow.map(\.duration).reduce(0, +) / Double(recentWindow.count)
    }

    private var averagePace: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return Double(recentWindow.map(\.wordsPerMinute).reduce(0, +)) / Double(recentWindow.count)
    }

    private var averageWordCount: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return Double(recentWindow.map(\.wordCount).reduce(0, +)) / Double(recentWindow.count)
    }

    private var daysSinceLastSession: Int {
        guard let last = sessionStore.sessions.first?.date else { return 99 }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }

    private var sessionStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(sessionStore.sessions.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    private var currentIdentity: SpeakingIdentitySnapshot {
        PracticeEvaluator.speakingIdentity(
            for: transcriptText,
            profile: coachingProfileStore.profile
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 0.90),
                    Color.white,
                    Color(red: 0.92, green: 0.96, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    headerCard
                    nextRepPanel
                    metricRow
                    tabPicker
                    detailPanel
                        .frame(height: 280)
                    xpPanel
                    retentionPanel
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
            }

            if celebrationVisible && !reduceMotion {
                summaryCelebrationOverlay
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .navigationTitle("Summary")
        .navigationBarBackButtonHidden(true)
        .disableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Practice Mode") { onSelectPracticeMode() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Home") { onHome() }
            }
        }
        .onAppear(perform: setup)
#if canImport(UIKit)
        .onChange(of: celebrationVisible) { visible in
            if visible {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
#endif
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(practiceTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(scoreValue)/10")
                    .font(.system(size: compactSummary ? 32 : 38, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreAccent)
                    .scaleEffect(celebrationVisible ? 1.04 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: celebrationVisible)
                Text(headline)
                    .font(.headline)
            }

            Text(feedback)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compactSummary ? 16 : 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var metricRow: some View {
        HStack(spacing: 10) {
            metricCard(title: "Fillers", value: "\(effectiveFillerCount)", tint: .red)
            if showDuration {
                metricCard(title: "Duration", value: "\(Int(effectiveDuration))s", tint: .blue)
            }
            metricCard(title: "XP", value: "\(xpEarned)", tint: .orange)
        }
    }

    private func metricCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compactSummary ? 12 : 14)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(SummaryTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? Color.blue : Color.white.opacity(0.72), in: Capsule())
                        .foregroundStyle(selectedTab == tab ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        ScrollView(showsIndicators: false) {
            switch selectedTab {
            case .overview:
                overviewPanel
            case .insights:
                insightsPanel
            case .transcript:
                transcriptPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollBounceBehavior(.basedOnSize)
        .padding(compactSummary ? 16 : 18)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var overviewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imConversationDetails {
                imTonePanel(details: imConversationDetails)
                Divider()
                    .padding(.vertical, 4)
            }
            Text("Breakdown")
                .font(.headline)
            if visibleBreakdown.isEmpty {
                Text("No scoring breakdown for this mode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleBreakdown) { segment in
                    HStack {
                        Text(segment.title)
                        Spacer()
                        Text(segment.value)
                            .fontWeight(.semibold)
                            .foregroundStyle(color(for: segment.tintName))
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func imTonePanel(details: IMConversationDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation Read")
                .font(.headline)

            HStack(spacing: 10) {
                metricCard(title: "Tone", value: details.setup.targetTone.title, tint: .blue)
                metricCard(title: "Scenario", value: details.setup.scenario.title, tint: .purple)
            }

            if let finalState = details.finalState {
                HStack(spacing: 10) {
                    metricCard(title: "Trust", value: "\(finalState.normalizedTrust)/10", tint: .blue)
                    metricCard(title: "Tension", value: "\(finalState.normalizedTension)/10", tint: .orange)
                    metricCard(title: "Turns", value: "\(details.turns.filter { $0.speaker == .user }.count)", tint: .green)
                }

                Text(finalState.beat)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let outcome = details.outcome {
                VStack(alignment: .leading, spacing: 6) {
                    Text(outcome.title)
                        .font(.subheadline.weight(.semibold))
                    Text(outcome.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let relationship = details.relationshipSnapshot {
                Divider()
                    .padding(.vertical, 4)

                Text("Relationship Impact")
                    .font(.headline)

                HStack(spacing: 10) {
                    metricCard(title: "Milestone", value: relationship.activeMilestone.title, tint: .teal)
                    metricCard(title: "Momentum", value: relationship.nextMilestoneProgressLabel, tint: .orange)
                }

                Text(relationship.activeMilestone.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(relationship.continuitySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let activeArcTitle = relationship.activeArcTitle,
                   let activeArcStageLabel = relationship.activeArcStageLabel {
                    VStack(alignment: .leading, spacing: 8) {
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

                if let nextRelationshipChallenge {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Best Next Move")
                        .font(.subheadline.weight(.semibold))
                        Text(nextRelationshipChallenge)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if communicationNorthStar != nil || motivationSummary != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Why This Matters")
                            .font(.subheadline.weight(.semibold))
                        if let communicationNorthStar {
                            Text(communicationNorthStar)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        if let motivationSummary {
                            Text(motivationSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Keep This Moving")
                        .font(.subheadline.weight(.semibold))

                    metricCard(title: "IM Streak", value: "\(imSessionStreak) days", tint: .orange)

                    ProgressView(value: relationship.nextMilestoneProgress)
                        .tint(.teal)

                    Text(relationship.unlockTeaser)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var insightsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach Read")
                .font(.headline)
            aiCoachSection
            if !lightweightSignals.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                Text(aiFeedback == nil ? "Immediate signals" : "Signal checks")
                    .font(.headline)
                ForEach(Array(lightweightSignals.enumerated()), id: \.offset) { index, insight in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.14))
                                .frame(width: 24, height: 24)
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.blue)
                        }
                        Text(insight)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var aiCoachSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.vertical, 4)
            Text("AI Coach")
                .font(.headline)

            if let aiFeedback {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What you did well")
                        .font(.subheadline.weight(.semibold))
                    ForEach(aiFeedback.strengths, id: \.self) { strength in
                        Text("• \(strength)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Biggest improvement")
                        .font(.subheadline.weight(.semibold))
                    Text(aiFeedback.keyImprovement)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Suggested drill")
                        .font(.subheadline.weight(.semibold))
                    Text(aiFeedback.suggestedDrill)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Stronger opening")
                        .font(.subheadline.weight(.semibold))
                    Text(aiFeedback.revisedOpening)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Noum can generate a deeper coach read from this transcript. The local checks below are only immediate signals, not the full coaching pass.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let aiError {
                Text(aiError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await requestDeeperFeedback() }
            } label: {
                HStack {
                    if isRequestingAIFeedback {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(aiFeedback == nil ? "Generate Coach Read" : "Refresh Coach Read")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isRequestingAIFeedback ? Color.gray.opacity(0.35) : Color.blue, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isRequestingAIFeedback)
        }
    }

    private var transcriptPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(imConversationDetails == nil ? "Transcript" : "Conversation")
                .font(.headline)
            if let details = imConversationDetails {
                VStack(spacing: 10) {
                    ForEach(details.turns) { turn in
                        HStack {
                            if turn.speaker == .npc {
                                transcriptBubble(
                                    speaker: details.setup.scenario.personaName,
                                    text: turn.text,
                                    tint: Color(red: 0.95, green: 0.96, blue: 0.99),
                                    isLeading: true
                                )
                                Spacer(minLength: 36)
                            } else {
                                Spacer(minLength: 36)
                                transcriptBubble(
                                    speaker: "You",
                                    text: turn.text,
                                    tint: Color(red: 0.87, green: 0.94, blue: 1.0),
                                    isLeading: false
                                )
                            }
                        }
                    }
                }
            } else {
                Text(transcript)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func transcriptBubble(speaker: String, text: String, tint: Color, isLeading: Bool) -> some View {
        VStack(alignment: isLeading ? .leading : .trailing, spacing: 6) {
            Text(speaker)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(isLeading ? .leading : .trailing)
        }
        .frame(maxWidth: 260, alignment: isLeading ? .leading : .trailing)
        .padding(12)
        .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var xpPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(currentLevel)
                Spacer()
                Text(nextLevel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ShimmerProgressBar(progress: progress, tint: .blue)

            HStack {
                Text("\(displayedXP) XP")
                Spacer()
                Text("\(xpToNext) to level up")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(compactSummary ? 12 : 14)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var retentionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Momentum Loop")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                PulseBadge(systemImage: "sparkles", tint: .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(retentionSnapshot.activeChallenge.title)
                        .font(.headline)
                    Text(retentionSnapshot.activeChallenge.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ShimmerProgressBar(progress: retentionSnapshot.activeChallenge.progress, tint: .orange)

            HStack {
                Text(retentionSnapshot.activeChallenge.progressLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                HStack(spacing: 6) {
                    SparkleRibbon(tint: .orange)
                    Text(retentionSnapshot.activeChallenge.rewardLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }

            Text(retentionSnapshot.motivationLine)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let nextLocked = retentionSnapshot.achievements.first(where: { !$0.isUnlocked }) {
                Text("Next milestone: \(nextLocked.title) • \(nextLocked.progressLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compactSummary ? 12 : 14)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var nextRepPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PulseBadge(systemImage: systemImage(for: summaryRecommendation.recommendedMode), tint: tint(for: summaryRecommendation.recommendedMode))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Best Rep")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(title(for: summaryRecommendation.recommendedMode))
                        .font(.headline)
                    Text(summaryRecommendation.modeBenefit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                chip(summaryRecommendation.focus, tint: tint(for: summaryRecommendation.recommendedMode))
                chip(summaryRecommendation.target, tint: .blue)
            }

            if summaryRecommendation.recommendedMode == .imConversation,
               let tone = summaryRecommendation.recommendedTone,
               let scenario = summaryRecommendation.recommendedScenario {
                HStack(spacing: 8) {
                    chip("Tone: \(tone.title)", tint: .indigo)
                    chip("Scenario: \(scenario.title)", tint: .purple)
                }
            }

            Text(summaryRecommendation.whyNow)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(compactSummary ? 12 : 14)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.94),
                    tint(for: summaryRecommendation.recommendedMode).opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint(for: summaryRecommendation.recommendedMode).opacity(0.18), lineWidth: 1)
        )
    }

    private var summaryCelebrationOverlay: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1 / 22.0)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(0..<14, id: \.self) { index in
                        let x = geometry.size.width * (0.10 + (Double(index % 7) * 0.13))
                        let travel = (phase.truncatingRemainder(dividingBy: 1.6)) / 1.6
                        let y = geometry.size.height * (0.22 + Double(index / 7) * 0.08) - travel * 120

                        Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                            .font(.system(size: index.isMultiple(of: 2) ? 10 : 8, weight: .bold))
                            .foregroundStyle(scoreAccent.opacity(0.28))
                            .position(x: x, y: y)
                            .opacity(1 - travel)
                            .scaleEffect(0.7 + travel * 0.4)
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button(primaryActionTitle) {
                if shouldPushRecommendedMode {
                    onSelectPracticeMode()
                } else {
                    onPracticeAgain()
                }
            }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compactSummary ? 13 : 15)
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)

            Button(secondaryActionTitle) {
                if shouldPushRecommendedMode {
                    onPracticeAgain()
                } else {
                    onSelectPracticeMode()
                }
            }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Button("Home") { onHome() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var compactSummary: Bool {
        showDuration ? duration <= 25 : transcriptWordCount <= 18
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10), in: Capsule())
    }

    private func title(for mode: PracticeMode) -> String {
        switch mode {
        case .timed: return "Timed Practice"
        case .suddenDeath: return "Sudden Death"
        case .ahCounter: return "Ah-Counter"
        case .imConversation: return "IM Mode"
        }
    }

    private func systemImage(for mode: PracticeMode) -> String {
        switch mode {
        case .timed: return "clock.fill"
        case .suddenDeath: return "bolt.fill"
        case .ahCounter: return "waveform.and.mic"
        case .imConversation: return "message.badge.waveform.fill"
        }
    }

    private func tint(for mode: PracticeMode) -> Color {
        switch mode {
        case .timed:
            return Color(red: 0.20, green: 0.47, blue: 0.96)
        case .suddenDeath:
            return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .ahCounter:
            return Color(red: 0.14, green: 0.60, blue: 0.44)
        case .imConversation:
            return Color(red: 0.32, green: 0.43, blue: 0.94)
        }
    }

    private func setup() {
        guard !didApplyXP else { return }
        didApplyXP = true
        lockedTranscriptText = String(transcript.characters)
        lockedFillerCount = fillerCount
        lockedDuration = duration
        lockedScore = score
        lockedFeedbackOverride = feedbackOverride
        lockedHeadlineOverride = headlineOverride
        lockedScoreBreakdown = scoreBreakdown
        lockedInsights = insights
        aiFeedback = recentSessions.first?.aiCoachFeedback
        selectedTab = (aiFeedback != nil) ? .insights : .overview
        displayedXP = profile.xp
        currentLevel = ProfileManager.levelTitle(forXP: profile.xp)
        nextLevel = ProfileManager.levelTitle(forXP: ((profile.xp / 1000) + 1) * 1000)
        xpToNext = ProfileManager.xpNeededToNextLevel(forXP: profile.xp)
        progress = ProfileManager.progressTowardsNextLevel(forXP: profile.xp)

        profile.addXP(xpEarned)
        animateXP(to: profile.xp)
        animateSegments()
        withAnimation(.easeInOut(duration: 0.35)) {
            celebrationVisible = scoreValue >= 7 || xpEarned >= 100
        }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) {
                    celebrationVisible = false
                }
            }
        }
        Task {
            await notificationManager.scheduleFollowUpReminder(
                profile: coachingProfileStore.profile,
                relationship: imConversationDetails?.relationshipSnapshot,
                sessions: sessionStore.sessions,
                practiceTitle: practiceTitle,
                nextMove: nextRelationshipChallenge ?? derivedInsights.first
            )
        }
    }

    private var canRequestAIFeedback: Bool {
        aiSettings.canRequestAnalysis && latestSessionID != nil
    }

    private func requestDeeperFeedback() async {
        aiError = nil
        guard aiSettings.canRequestAnalysis else {
            aiError = aiSettings.activeProvider == nil
                ? "AI feedback is not configured yet."
                : "AI feedback is temporarily unavailable right now."
            return
        }

        guard let sessionID = latestSessionID else {
            aiError = "This session has not been saved yet. Finish one more rep and try again."
            return
        }

        isRequestingAIFeedback = true
        defer { isRequestingAIFeedback = false }

        do {
            let plan = CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
            let styleSnapshot = PracticeEvaluator.speakingIdentity(
                for: String(transcript.characters),
                profile: coachingProfileStore.profile
            )
            let feedback = try await aiCoachService.generateDeeperFeedback(
                input: AICoachSessionInput(
                    transcript: String(transcript.characters),
                    mode: recentSessions.first?.mode ?? .timed,
                    score: score,
                    fillerCount: fillerCount,
                    duration: duration,
                    wordsPerMinute: PracticeEvaluator.paceSnapshot(
                        forTranscript: String(transcript.characters),
                        duration: duration
                    ).wordsPerMinute,
                    speakingIdentity: styleSnapshot.identity
                ),
                profile: coachingProfileStore.profile,
                plan: plan
            )
            sessionStore.saveAIFeedback(sessionID: sessionID, feedback: feedback)
            aiFeedback = feedback
        } catch {
            aiError = error.localizedDescription
        }
    }

    private func animateXP(to endXP: Int) {
        Task {
            let startXP = displayedXP
            for xp in stride(from: startXP, through: endXP, by: 1) {
                await MainActor.run {
                    displayedXP = xp
                    progress = ProfileManager.progressTowardsNextLevel(forXP: xp)
                }
                try? await Task.sleep(for: .milliseconds(6))
            }
            await MainActor.run {
                currentLevel = ProfileManager.levelTitle(forXP: endXP)
                nextLevel = ProfileManager.levelTitle(forXP: ((endXP / 1000) + 1) * 1000)
                xpToNext = ProfileManager.xpNeededToNextLevel(forXP: endXP)
            }
        }
    }

    private func animateSegments() {
        guard !scoreBreakdown.isEmpty else { return }
        Task {
            for index in 1...scoreBreakdown.count {
                try? await Task.sleep(for: .milliseconds(180))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        visibleSegments = index
                    }
                }
            }
        }
    }

    private func color(for tintName: String) -> Color {
        switch tintName {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        default: return .primary
        }
    }
}

#endif

#if canImport(SwiftUI)
#Preview {
    SummaryView(
        transcript: AttributedString("This was a concise practice answer with a strong opening, clear middle, and a tidy finish."),
        fillerCount: 1,
        duration: 28,
        score: 8,
        progressSegments: 3,
        xpEarned: 74,
        practiceTitle: "Timed Practice • Medium",
        feedbackOverride: "Clear answer overall. Push for a little more depth or time on the next rep.",
        headlineOverride: "Solid response",
        scoreBreakdown: [
            PracticeScoreSegment(title: "Depth", value: "+2", tintName: "blue"),
            PracticeScoreSegment(title: "Content", value: "+3", tintName: "orange"),
            PracticeScoreSegment(title: "Pace", value: "+2", tintName: "green"),
            PracticeScoreSegment(title: "Filler penalty", value: "-1", tintName: "red")
        ],
        insights: [
            "You used fewer filler words than your recent average.",
            "You stayed with the answer longer than your recent average.",
            "Your pace was calm. Keep that control while expanding the middle of the answer."
        ],
        explicitMode: .timed
    )
}
#endif
