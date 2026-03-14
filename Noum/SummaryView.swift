import Foundation
#if canImport(SwiftUI)
import SwiftUI
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
    var onSelectPracticeMode: () -> Void = {}
    var onHome: () -> Void = {}
    var onPracticeAgain: () -> Void = {}

    @StateObject private var profile = ProfileManager.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
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

    private let aiCoachService: AICoachServicing = AICoachService()

    private var transcriptText: String {
        String(transcript.characters)
    }

    private var transcriptWordCount: Int {
        transcriptText.split { !$0.isLetter && !$0.isNumber }.count
    }

    private var scoreValue: Int {
        if let score { return score }
        if duration < 4 || transcriptWordCount < 4 { return 1 }
        if duration < 8 || transcriptWordCount < 8 { return max(2, 5 - fillerCount) }
        return max(3, min(8, 7 - fillerCount))
    }

    private var headline: String {
        if let headlineOverride { return headlineOverride }
        switch scoreValue {
        case 9...10: return "Strong delivery"
        case 7...8: return "Good control"
        case 4...6: return "Room to sharpen"
        default: return "Needs another rep"
        }
    }

    private var feedback: String {
        if let feedbackOverride { return feedbackOverride }
        if duration < 4 || transcriptWordCount < 4 {
            return "That rep ended before the answer really began. Go again with a clear opening, one point, and a clean finish."
        }
        if duration < 8 || transcriptWordCount < 8 {
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
        Array(scoreBreakdown.prefix(visibleSegments))
    }

    private var derivedInsights: [String] {
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

    private var lightweightSignals: [String] {
        Array(derivedInsights.prefix(aiFeedback == nil ? 2 : 1))
    }

    private var latestSessionID: UUID? {
        recentSessions.first?.id ?? sessionStore.sessions.first?.id
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompactHeight = geometry.size.height < 760
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

                VStack(spacing: isCompactHeight ? 10 : 12) {
                    headerCard
                    metricRow
                    tabPicker
                    detailPanel
                        .frame(minHeight: isCompactHeight ? 210 : 240)
                        .frame(maxHeight: max(isCompactHeight ? 240 : 260, geometry.size.height * (isCompactHeight ? 0.31 : 0.34)))
                    xpPanel
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.top, isCompactHeight ? 8 : 12)
                .padding(.bottom, isCompactHeight ? 12 : 18)
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
            metricCard(title: "Fillers", value: "\(fillerCount)", tint: .red)
            if showDuration {
                metricCard(title: "Duration", value: "\(Int(duration))s", tint: .blue)
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
            Text("Transcript")
                .font(.headline)
            Text(transcript)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(14)
                .background(Color(red: 0.97, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

            ProgressView(value: progress)
                .tint(.blue)

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

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button(scoreValue <= 5 ? "Practice Again Now" : "Practice Again") { onPracticeAgain() }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compactSummary ? 13 : 15)
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)

            Button("Choose Another Mode") { onSelectPracticeMode() }
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

    private func setup() {
        guard !didApplyXP else { return }
        didApplyXP = true
        aiFeedback = recentSessions.first?.aiCoachFeedback
        displayedXP = profile.xp
        currentLevel = ProfileManager.levelTitle(forXP: profile.xp)
        nextLevel = ProfileManager.levelTitle(forXP: ((profile.xp / 1000) + 1) * 1000)
        xpToNext = ProfileManager.xpNeededToNextLevel(forXP: profile.xp)
        progress = ProfileManager.progressTowardsNextLevel(forXP: profile.xp)

        profile.addXP(xpEarned)
        animateXP(to: profile.xp)
        animateSegments()
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
        ]
    )
}
#endif
