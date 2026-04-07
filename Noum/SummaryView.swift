import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)

// MARK: - SummaryView (Redesigned)

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
    var recordingURL: URL? = nil
    var sessionPrompt: String? = nil
    var sessionTheme: PromptTheme? = nil
    var feedbackCategories: [FeedbackCategory] = []
    var strongMoments: [String] = []
    var weakMoments: [String] = []
    var onSelectPracticeMode: () -> Void = {}
    var onHome: () -> Void = {}
    var onPracticeAgain: () -> Void = {}

    @StateObject private var profile = ProfileManager.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var premium = PremiumManager.shared
    @State private var showPaywall = false
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
    @State private var showVideoPlayback = false
    @State private var celebrationVisible = false
    @State private var lockedTranscriptText: String?
    @State private var lockedFillerCount: Int?
    @State private var lockedDuration: TimeInterval?
    @State private var lockedScore: Int?
    @State private var lockedFeedbackOverride: String?
    @State private var lockedHeadlineOverride: String?
    @State private var lockedScoreBreakdown: [PracticeScoreSegment] = []
    @State private var lockedInsights: [String] = []
    @State private var showShareSheet = false
    @State private var videoAnalysisResult: VideoAnalysisResult?
    @State private var isAnalyzingVideo = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let aiCoachService: AICoachServicing = AICoachService()

    // MARK: - Computed Properties

    private var transcriptText: String {
        lockedTranscriptText ?? String(transcript.characters)
    }

    private var transcriptWordCount: Int {
        transcriptText.split { !$0.isLetter && !$0.isNumber }.count
    }

    private var effectiveFillerCount: Int { lockedFillerCount ?? fillerCount }
    private var effectiveDuration: TimeInterval { lockedDuration ?? duration }

    private var effectiveScoreBreakdown: [PracticeScoreSegment] {
        lockedScoreBreakdown.isEmpty ? scoreBreakdown : lockedScoreBreakdown
    }

    private var currentMode: PracticeMode {
        if let explicitMode { return explicitMode }
        if imConversationDetails != nil { return .imConversation }
        let title = practiceTitle.lowercased()
        if title.contains("sudden") { return .suddenDeath }
        if title.contains("ah-counter") || title.contains("ah counter") { return .ahCounter }
        return .timed
    }

    private var isIMSummary: Bool { currentMode == .imConversation }

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

    private var verdict: String {
        if let lockedFeedbackOverride { return lockedFeedbackOverride }
        if let feedbackOverride { return feedbackOverride }
        if effectiveDuration < 4 || transcriptWordCount < 4 {
            return "That rep ended before the answer really began. Go again with a clear opening, one point, and a clean finish."
        }
        if effectiveDuration < 8 || transcriptWordCount < 8 {
            return "This was too brief to show control yet. Push the next answer further so the idea has time to land."
        }
        switch scoreValue {
        case 8...10: return "A convincing rep. Keep that same control while raising the difficulty."
        case 6...7: return "There is a solid response in here. One stronger opening sentence would make it feel more complete."
        case 4...5: return "The idea started to form, but it needs more structure and follow-through."
        default: return "Go again straight away and aim for a steadier opening with one clear supporting point."
        }
    }

    private var scoreAccent: Color {
        switch scoreValue {
        case 8...10: return Color(red: 0.10, green: 0.56, blue: 0.40)
        case 5...7: return Color(red: 0.83, green: 0.52, blue: 0.10)
        default: return Color(red: 0.74, green: 0.22, blue: 0.20)
        }
    }

    private var scoreEmoji: String {
        switch scoreValue {
        case 9...10: return "flame.fill"
        case 7...8: return "hand.thumbsup.fill"
        case 4...6: return "arrow.up.right"
        default: return "arrow.clockwise"
        }
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

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: sessionStore.sessions,
            profile: coachingProfileStore.profile
        )
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
        PracticeEvaluator.speakingIdentity(for: transcriptText, profile: coachingProfileStore.profile)
    }

    private var latestSessionID: UUID? {
        recentSessions.first?.id ?? sessionStore.sessions.first?.id
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

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    heroScoreCard
                    verdictCard

                    if isIMSummary, let details = imConversationDetails {
                        imConversationOverview(details)
                    }

                    if !feedbackCategories.isEmpty {
                        categoryGrid
                    } else if !effectiveScoreBreakdown.isEmpty {
                        breakdownCard
                    }

                    aiMomentsCard

                    if let recordingURL {
                        recordingCard(url: recordingURL)
                    }

                    if let comparison = smartComparison {
                        sessionComparisonCard(comparison)
                    }

                    if premium.canViewCoachingInsights {
                        coachReadCard
                    }

                    xpProgressCard
                    retentionCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
            }

            if celebrationVisible && !reduceMotion {
                celebrationOverlay
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .disableSwipeBack()
        .onAppear(perform: setup)
        .sheet(isPresented: $showVideoPlayback) {
            if let recordingURL {
                VideoPlaybackView(url: recordingURL)
            }
        }
#if canImport(UIKit)
        .onChange(of: celebrationVisible) { _, visible in
            if visible {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
#endif
    }

    // MARK: - Hero Score Card

    private var heroScoreCard: some View {
        VStack(spacing: 16) {
            // Mode label
            Text(practiceTitle.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.4)

            // Score ring
            ZStack {
                Circle()
                    .stroke(scoreAccent.opacity(0.15), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: Double(scoreValue) / 10.0)
                    .stroke(scoreAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(scoreValue)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreAccent)
                    Text("/10")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .scaleEffect(celebrationVisible ? 1.06 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: celebrationVisible)

            // Headline
            HStack(spacing: 8) {
                Image(systemName: scoreEmoji)
                    .foregroundStyle(scoreAccent)
                Text(headline)
                    .font(.title3.weight(.bold))
            }

            // Prompt (if available)
            if let sessionPrompt {
                Text("\"\(sessionPrompt)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
            }

            // Quick stats row
            HStack(spacing: 20) {
                statPill(label: "Fillers", value: "\(effectiveFillerCount)", tint: effectiveFillerCount == 0 ? .green : .red)
                statPill(label: "Duration", value: "\(Int(effectiveDuration))s", tint: .blue)
                statPill(label: "XP", value: "+\(xpEarned)", tint: .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.white, scoreAccent.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(scoreAccent.opacity(0.12), lineWidth: 1)
        )
    }

    private func statPill(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Verdict Card

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verdict")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(verdict)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Category Grid (7 dimensions)

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Breakdown")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(feedbackCategories) { category in
                HStack(spacing: 12) {
                    // Rating indicator
                    Image(systemName: category.rating.icon)
                        .font(.subheadline)
                        .foregroundStyle(ratingColor(category.rating))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.dimension)
                            .font(.subheadline.weight(.semibold))
                        Text(category.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(category.rating.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ratingColor(category.rating))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ratingColor(category.rating).opacity(0.10), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func ratingColor(_ rating: FeedbackRating) -> Color {
        switch rating {
        case .good: return Color(red: 0.14, green: 0.60, blue: 0.38)
        case .ok: return Color(red: 0.83, green: 0.65, blue: 0.10)
        case .couldImprove: return Color(red: 0.85, green: 0.42, blue: 0.12)
        }
    }

    // MARK: - Legacy Breakdown (fallback when no categories)

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(Array(effectiveScoreBreakdown.prefix(visibleSegments))) { segment in
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - AI Moments (Strong + Weak)

    private var aiMomentsCard: some View {
        let hasStrong = !strongMoments.isEmpty
        let hasWeak = !weakMoments.isEmpty
        let hasInsights = !derivedInsights.isEmpty

        return Group {
            if hasStrong || hasWeak || hasInsights {
                VStack(alignment: .leading, spacing: 14) {
                    if hasStrong {
                        momentSection(title: "What was strong", icon: "checkmark.seal.fill", tint: .green, items: strongMoments)
                    }

                    if hasWeak {
                        if hasStrong { Divider() }
                        momentSection(title: "What needs work", icon: "exclamationmark.triangle.fill", tint: .orange, items: weakMoments)
                    }

                    if hasInsights && !hasStrong && !hasWeak {
                        momentSection(title: "Signals", icon: "lightbulb.fill", tint: .blue, items: Array(derivedInsights.prefix(2)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private func momentSection(title: String, icon: String, tint: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.bold))
            }

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(tint.opacity(0.4))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Recording Card

    private func recordingCard(url: URL) -> some View {
        let videoManager = VideoRecordingManager.shared
        return VStack(alignment: .leading, spacing: 12) {
            Text("Session Recording")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            // Watch recording button
            Button {
                showVideoPlayback = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                    Text("Watch Recording")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                // Save recording
                if videoManager.savedRecordingURL == nil {
                    Button {
                        videoManager.saveRecording()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.caption)
                            Text("Save")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Saved")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // AI Video Analysis (premium)
                if premium.isPremium {
                    Button {
                        analyzeVideo()
                    } label: {
                        HStack(spacing: 6) {
                            if isAnalyzingVideo {
                                ProgressView()
                                    .tint(.purple)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                    .font(.caption)
                            }
                            Text(isAnalyzingVideo ? "Analyzing..." : "Analyze with AI")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnalyzingVideo || !premium.canUseVideoAnalysis)
                }
            }

            // Credits remaining
            if premium.isPremium {
                Text("\(premium.videoAnalysisCreditsRemaining) AI analysis credit\(premium.videoAnalysisCreditsRemaining == 1 ? "" : "s") remaining this month")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Video analysis results
            if let result = videoAnalysisResult {
                videoAnalysisResultView(result)
            }

            if videoManager.savedRecordingURL == nil {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text("Recordings are temporary unless saved.")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func videoAnalysisResultView(_ result: VideoAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("AI Video Analysis")
                .font(.subheadline.weight(.bold))

            videoAnalysisRow(label: "Posture", rating: result.posture, note: result.postureNote)
            videoAnalysisRow(label: "Eye Contact", rating: result.eyeContact, note: result.eyeContactNote)
            videoAnalysisRow(label: "Expression", rating: result.facialExpression, note: result.facialExpressionNote)
            videoAnalysisRow(label: "Gestures", rating: result.gestureUse, note: result.gestureNote)
            videoAnalysisRow(label: "Energy", rating: result.energyConfidence, note: result.energyNote)
            videoAnalysisRow(label: "Presence", rating: result.presenceDelivery, note: result.presenceNote)

            Text(result.overallNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func videoAnalysisRow(label: String, rating: FeedbackRating, note: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rating.icon)
                .font(.caption)
                .foregroundStyle(ratingColor(rating))
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(width: 70, alignment: .leading)
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Coach Read Card

    private var coachReadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            if let aiFeedback {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What you did well")
                        .font(.subheadline.weight(.semibold))
                    ForEach(aiFeedback.strengths, id: \.self) { strength in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                                .padding(.top, 3)
                            Text(strength)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    Text("Key improvement")
                        .font(.subheadline.weight(.semibold))
                    Text(aiFeedback.keyImprovement)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Suggested drill")
                        .font(.subheadline.weight(.semibold))
                    Text(aiFeedback.suggestedDrill)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !aiFeedback.revisedOpening.isEmpty {
                        Text("Try this opening")
                            .font(.subheadline.weight(.semibold))
                        Text("\"\(aiFeedback.revisedOpening)\"")
                            .font(.subheadline.italic())
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                Text("Generate a deeper coaching read from this session's transcript.")
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
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isRequestingAIFeedback ? Color.gray.opacity(0.35) : Color.blue, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isRequestingAIFeedback)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - XP Progress Card

    private var xpProgressCard: some View {
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
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Retention Card

    private var retentionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PulseBadge(systemImage: "sparkles", tint: .orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(retentionSnapshot.activeChallenge.title)
                        .font(.subheadline.weight(.semibold))
                    Text(retentionSnapshot.activeChallenge.summary)
                        .font(.caption)
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
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Action Bar (Retry Loop)

    private var actionBar: some View {
        VStack(spacing: 10) {
            // Primary: Retry Same Prompt
            Button {
                onPracticeAgain()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                    Text("Retry Same Prompt")
                        .font(.headline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                // Secondary: Try New Prompt
                Button {
                    onSelectPracticeMode()
                } label: {
                    Text("New Prompt")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.primary)
                }

                // Share Result (visual card)
                ShareLink(item: shareImage, preview: SharePreview("My Noum Score", image: shareImage)) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                        Text("Share")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.08), in: Capsule())
                }
            }
        }
    }

    // MARK: - Share Card (Visual Accomplishment Card)

    @MainActor
    private var shareImage: Image {
        let renderer = ImageRenderer(content: shareCardContent)
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "square.fill")
    }

    private var shareCardContent: some View {
        VStack(spacing: 16) {
            Text("NOUM")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(3)

            Text("\(scoreValue)/10")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            if let sessionPrompt {
                Text("\"\(sessionPrompt)\"")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                shareStatPill(label: "Fillers", value: "\(effectiveFillerCount)")
                shareStatPill(label: "Duration", value: "\(Int(effectiveDuration))s")
                shareStatPill(label: "XP", value: "+\(xpEarned)")
            }
        }
        .frame(width: 340)
        .padding(32)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.18), scoreAccent.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func shareStatPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Smart Session Comparison

    private struct SessionComparison {
        let reason: String
        let previousScore: Int
        let currentScore: Int
        let previousWPM: Int
        let currentWPM: Int
        let previousFillers: Int
        let currentFillers: Int
        let previousDate: Date
    }

    private var smartComparison: SessionComparison? {
        guard let currentScore = lockedScore ?? score,
              let prompt = sessionPrompt else { return nil }

        let past = recentSessions.dropFirst()
        if let match = past.first(where: { $0.prompt == prompt && $0.score != nil }) {
            let scoreDelta = currentScore - (match.score ?? 0)
            let currentWPM = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
            let matchWPM = match.duration > 0 ? Int(Double(match.transcript.split { !$0.isLetter }.count) / match.duration * 60) : 0
            let fillerDelta = (lockedFillerCount ?? fillerCount) - match.fillerWordCount

            if abs(scoreDelta) >= 5 || fillerDelta <= -2 {
                return SessionComparison(
                    reason: "Same prompt",
                    previousScore: match.score ?? 0,
                    currentScore: currentScore,
                    previousWPM: matchWPM,
                    currentWPM: currentWPM,
                    previousFillers: match.fillerWordCount,
                    currentFillers: lockedFillerCount ?? fillerCount,
                    previousDate: match.date
                )
            }
        }

        if let theme = sessionTheme, theme != .all {
            if let match = past.first(where: { $0.theme == theme && $0.score != nil }) {
                let scoreDelta = currentScore - (match.score ?? 0)
                let currentWPM = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
                let matchWPM = match.duration > 0 ? Int(Double(match.transcript.split { !$0.isLetter }.count) / match.duration * 60) : 0

                if scoreDelta >= 10 {
                    return SessionComparison(
                        reason: "Same theme: \(theme.rawValue)",
                        previousScore: match.score ?? 0,
                        currentScore: currentScore,
                        previousWPM: matchWPM,
                        currentWPM: currentWPM,
                        previousFillers: match.fillerWordCount,
                        currentFillers: lockedFillerCount ?? fillerCount,
                        previousDate: match.date
                    )
                }
            }
        }

        return nil
    }

    private func sessionComparisonCard(_ comparison: SessionComparison) -> some View {
        let scoreDelta = comparison.currentScore - comparison.previousScore
        let improved = scoreDelta > 0
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: improved ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundStyle(improved ? .green : .orange)
                Text(comparison.reason)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatter.localizedString(for: comparison.previousDate, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                comparisonMetric(label: "Score", previous: "\(comparison.previousScore)", current: "\(comparison.currentScore)", improved: scoreDelta > 0)
                comparisonMetric(label: "WPM", previous: "\(comparison.previousWPM)", current: "\(comparison.currentWPM)", improved: comparison.currentWPM >= comparison.previousWPM)
                comparisonMetric(label: "Fillers", previous: "\(comparison.previousFillers)", current: "\(comparison.currentFillers)", improved: comparison.currentFillers <= comparison.previousFillers)
            }

            if improved {
                Text("You're improving. Keep going.")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(
            (improved ? Color.green : Color.orange).opacity(0.06),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((improved ? Color.green : Color.orange).opacity(0.12), lineWidth: 1)
        )
    }

    private func comparisonMetric(label: String, previous: String, current: String, improved: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(previous)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .strikethrough()
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(current)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(improved ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - IM Conversation Overview

    private func imConversationOverview(_ details: IMConversationDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation Read")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 10) {
                chip(details.setup.targetTone.title, tint: .blue)
                chip(details.setup.scenario.title, tint: .purple)
            }

            if let finalState = details.finalState {
                HStack(spacing: 10) {
                    statCard(title: "Trust", value: "\(finalState.normalizedTrust)/10", tint: .blue)
                    statCard(title: "Tension", value: "\(finalState.normalizedTension)/10", tint: .orange)
                    statCard(title: "Turns", value: "\(details.turns.filter { $0.speaker == .user }.count)", tint: .green)
                }

                Text(finalState.beat)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
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

    // MARK: - Helpers

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10), in: Capsule())
    }

    private func color(for tintName: String) -> Color {
        switch tintName {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "indigo": return .indigo
        default: return .primary
        }
    }

    // MARK: - Setup & Logic

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
                nextMove: derivedInsights.first
            )
        }
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

    private func analyzeVideo() {
        guard premium.consumeVideoAnalysisCredit() else { return }
        isAnalyzingVideo = true

        // Simulated analysis — in production this would upload to a backend
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run {
                videoAnalysisResult = VideoAnalysisResult(
                    posture: .ok,
                    postureNote: "Mostly upright — watch for slight slouching",
                    eyeContact: .good,
                    eyeContactNote: "Consistent eye-line toward camera",
                    facialExpression: .ok,
                    facialExpressionNote: "Neutral — try adding more warmth",
                    gestureUse: .couldImprove,
                    gestureNote: "Hands stayed still — use deliberate gestures",
                    energyConfidence: .good,
                    energyNote: "Strong vocal energy throughout",
                    presenceDelivery: .ok,
                    presenceNote: "Good presence — work on intentional pauses",
                    overallNote: "Solid delivery fundamentals. Focus on adding deliberate hand gestures and warmer facial expressions to elevate your presence."
                )
                isAnalyzingVideo = false
            }
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
        practiceTitle: "Impromptu Practice",
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
        explicitMode: .timed,
        feedbackCategories: [
            FeedbackCategory(dimension: "Opening", rating: .good, note: "Clear, confident start"),
            FeedbackCategory(dimension: "Structure", rating: .good, note: "Well-organized answer"),
            FeedbackCategory(dimension: "Relevance", rating: .good, note: "Stayed on topic"),
            FeedbackCategory(dimension: "Depth", rating: .ok, note: "Push for more examples"),
            FeedbackCategory(dimension: "Clarity", rating: .good, note: "Clean, minimal fillers"),
            FeedbackCategory(dimension: "Pace", rating: .good, note: "Comfortable, natural pace"),
            FeedbackCategory(dimension: "Close", rating: .ok, note: "Ended a bit abruptly"),
        ],
        strongMoments: ["Zero filler words — clean delivery", "Natural, well-paced delivery"],
        weakMoments: []
    )
}
#endif
