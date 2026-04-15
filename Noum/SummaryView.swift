import Foundation
#if canImport(SwiftUI)
import SwiftUI
// MARK: - Feedback Request Data Models

/// A shareable session package for requesting feedback from peers/mentors.
struct FeedbackRequestPackage: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let senderName: String
    let transcript: String
    let fillerCount: Int
    let duration: TimeInterval
    let score: Int
    let headline: String
    let prompt: String?
    let theme: PromptTheme?
    let mode: PracticeMode
    let feedbackCategories: [FeedbackCategory]
    let aiFeedbackSummary: String?
    let aiStrengths: [String]
    let aiKeyImprovement: String?
    let hasRecording: Bool
    let requestNote: String

    init(
        senderName: String,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        score: Int,
        headline: String,
        prompt: String?,
        theme: PromptTheme?,
        mode: PracticeMode,
        feedbackCategories: [FeedbackCategory],
        aiFeedback: AICoachFeedback?,
        hasRecording: Bool,
        requestNote: String
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.senderName = senderName
        self.transcript = transcript
        self.fillerCount = fillerCount
        self.duration = duration
        self.score = score
        self.headline = headline
        self.prompt = prompt
        self.theme = theme
        self.mode = mode
        self.feedbackCategories = feedbackCategories
        self.aiFeedbackSummary = aiFeedback.map { "Key improvement: \($0.keyImprovement). Drill: \($0.suggestedDrill)" }
        self.aiStrengths = aiFeedback?.strengths ?? []
        self.aiKeyImprovement = aiFeedback?.keyImprovement
        self.hasRecording = hasRecording
        self.requestNote = requestNote
    }
}

/// A reviewer's response to a feedback request.
struct ReviewerResponse: Codable, Identifiable {
    let id: UUID
    let requestID: UUID
    let reviewerName: String
    let date: Date
    let textFeedback: String?
    let voiceNoteURL: URL?
    let videoResponseURL: URL?
    let ratings: [String: FeedbackRating]  // dimension -> rating

    init(
        requestID: UUID,
        reviewerName: String,
        textFeedback: String? = nil,
        voiceNoteURL: URL? = nil,
        videoResponseURL: URL? = nil,
        ratings: [String: FeedbackRating] = [:]
    ) {
        self.id = UUID()
        self.requestID = requestID
        self.reviewerName = reviewerName
        self.date = Date()
        self.textFeedback = textFeedback
        self.voiceNoteURL = voiceNoteURL
        self.videoResponseURL = videoResponseURL
        self.ratings = ratings
    }
}

// MARK: - Feedback Request Composer

/// Sheet view for composing a feedback request before sharing.
struct FeedbackRequestComposer: View {
    let transcript: String
    let fillerCount: Int
    let duration: TimeInterval
    let score: Int
    let headline: String
    let prompt: String?
    let theme: PromptTheme?
    let mode: PracticeMode
    let feedbackCategories: [FeedbackCategory]
    let aiFeedback: AICoachFeedback?
    let recordingURL: URL?

    @State private var requestNote = ""
    @State private var includeTranscript = true
    @State private var includeAIFeedback = true
    @State private var includeRecording = true
    @State private var isGeneratingLink = false
    @State private var generatedShareText: String?
    @Environment(\.dismiss) private var dismiss

    private var senderName: String {
        "A speaker"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview header
                    feedbackPreviewCard

                    // What's included
                    inclusionToggles

                    // Personal note
                    noteSection

                    // Share button
                    shareButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(AppColor.screenBackground)
            .navigationTitle("Request Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Preview Card

    private var feedbackPreviewCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                // Score badge
                ZStack {
                    Circle()
                        .fill(previewAccent.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Text("\(score)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(previewAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(.headline.weight(.bold))
                    HStack(spacing: 8) {
                        Label(mode.displayLabel, systemImage: mode.iconName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(Int(duration))s")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let prompt {
                Text("\"\(prompt)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            // Quick stats
            HStack(spacing: 0) {
                feedbackStatCell(value: "\(fillerCount)", label: "Fillers")
                feedbackStatCell(value: "\(wpm)", label: "WPM")
                feedbackStatCell(value: "\(transcript.split { !$0.isLetter && !$0.isNumber }.count)", label: "Words")
            }
            .padding(.vertical, 10)
            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private func feedbackStatCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var previewAccent: Color {
        switch score {
        case 8...10: return AppColor.positive
        case 5...7: return AppColor.caution
        default: return AppColor.warning
        }
    }

    private var wpm: Int {
        guard duration > 0 else { return 0 }
        return Int((Double(transcript.split { !$0.isLetter && !$0.isNumber }.count) / duration * 60).rounded())
    }

    // MARK: - Inclusion Toggles

    private var inclusionToggles: some View {
        VStack(spacing: 0) {
            SectionHeader("What to include", icon: "checklist")
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                inclusionRow(
                    icon: "doc.text",
                    title: "Full Transcript",
                    subtitle: "Your complete spoken response",
                    isOn: $includeTranscript
                )

                if aiFeedback != nil {
                    Divider().padding(.leading, 52)
                    inclusionRow(
                        icon: "brain",
                        title: "AI Coach Feedback",
                        subtitle: "Strengths, improvements, drills",
                        isOn: $includeAIFeedback
                    )
                }

                if recordingURL != nil {
                    Divider().padding(.leading, 52)
                    inclusionRow(
                        icon: "video.fill",
                        title: "Recording",
                        subtitle: "Audio/video of your session",
                        isOn: $includeRecording
                    )
                }
            }
            .padding(.vertical, 4)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
    }

    private func inclusionRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(AppColor.brandBlue)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Personal note", icon: "pencil.line")

            TextField("What would you like feedback on?", text: $requestNote, axis: .vertical)
                .lineLimit(3...5)
                .padding(14)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            Text("E.g., \"Focus on my opening — did it hook you?\" or \"How was my pacing?\"")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        ShareLink(item: feedbackShareText) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.headline.weight(.semibold))
                Text("Send Feedback Request")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColor.brandBlue.gradient, in: Capsule(style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private var feedbackShareText: String {
        var parts: [String] = []

        // Header
        parts.append("\(senderName) is requesting feedback on a speaking practice session.")
        parts.append("")

        // Session overview
        parts.append("Session: \(mode.displayLabel) Mode — Score: \(score)/10 (\(headline))")
        if let prompt {
            parts.append("Prompt: \"\(prompt)\"")
        }
        parts.append("Duration: \(Int(duration))s | Fillers: \(fillerCount) | WPM: \(wpm)")
        parts.append("")

        // Personal note
        if !requestNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Note from speaker: \"\(requestNote)\"")
            parts.append("")
        }

        // Transcript
        if includeTranscript {
            parts.append("— TRANSCRIPT —")
            parts.append(transcript)
            parts.append("")
        }

        // AI Feedback
        if includeAIFeedback, let ai = aiFeedback {
            parts.append("— AI COACH FEEDBACK —")
            parts.append("Strengths: \(ai.strengths.joined(separator: ", "))")
            parts.append("Key Improvement: \(ai.keyImprovement)")
            parts.append("Suggested Drill: \(ai.suggestedDrill)")
            parts.append("")
        }

        // Category breakdown
        if !feedbackCategories.isEmpty {
            parts.append("— DIMENSION RATINGS —")
            for cat in feedbackCategories {
                let icon = cat.rating == .good ? "+" : cat.rating == .ok ? "~" : "-"
                parts.append("[\(icon)] \(cat.dimension): \(cat.note)")
            }
            parts.append("")
        }

        parts.append("Sent via Noum — Speaking Practice")

        return parts.joined(separator: "\n")
    }
}

// MARK: - Feedback Review Screen

/// Full-screen review experience for recipients of a feedback request.
struct FeedbackReviewScreen: View {
    let package: FeedbackRequestPackage

    @State private var responseText = ""
    @State private var selectedTab: FeedbackReviewTab = .overview
    @State private var dimensionRatings: [String: FeedbackRating] = [:]
    @Environment(\.dismiss) private var dismiss

    enum FeedbackReviewTab: String, CaseIterable {
        case overview = "Overview"
        case transcript = "Transcript"
        case feedback = "AI Feedback"
    }

    private var accent: Color {
        switch package.score {
        case 8...10: return AppColor.positive
        case 5...7: return AppColor.caution
        default: return AppColor.warning
        }
    }

    private var wordCount: Int {
        package.transcript.split { !$0.isLetter && !$0.isNumber }.count
    }

    private var wpm: Int {
        guard package.duration > 0 else { return 0 }
        return Int((Double(wordCount) / package.duration * 60).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Sender card
                    senderCard

                    // Tab picker
                    Picker("Section", selection: $selectedTab) {
                        ForEach(FeedbackReviewTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Tab content
                    switch selectedTab {
                    case .overview:
                        overviewTab
                    case .transcript:
                        transcriptTab
                    case .feedback:
                        aiFeedbackTab
                    }

                    // Response section
                    responseSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(AppColor.screenBackground)
            .navigationTitle("Review Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sender Card

    private var senderCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Text(String(package.senderName.prefix(1)).uppercased())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(package.senderName)
                        .font(.headline.weight(.bold))
                    Text("asked for your feedback")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !package.requestNote.isEmpty {
                Text("\"\(package.requestNote)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Quick stats
            HStack(spacing: 16) {
                reviewStatBadge(value: "\(package.score)/10", label: "Score", tint: accent)
                reviewStatBadge(value: "\(Int(package.duration))s", label: "Duration", tint: .blue)
                reviewStatBadge(value: "\(package.fillerCount)", label: "Fillers", tint: .orange)
                reviewStatBadge(value: "\(wpm)", label: "WPM", tint: .purple)
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private func reviewStatBadge(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 14) {
            // Mode & prompt
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: package.mode.iconName)
                        .foregroundStyle(AppColor.tint(for: package.mode))
                    Text(package.mode.displayLabel)
                        .font(.subheadline.weight(.semibold))
                }

                if let prompt = package.prompt {
                    Text("\"\(prompt)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            // Dimension breakdown
            if !package.feedbackCategories.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Dimension Ratings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(package.feedbackCategories) { cat in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(ratingColor(cat.rating))
                                .frame(width: 8, height: 8)
                            Text(cat.dimension)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(cat.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(16)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }
        }
    }

    // MARK: - Transcript Tab

    private var transcriptTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Full Transcript")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(package.transcript)
                .font(.body)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - AI Feedback Tab

    private var aiFeedbackTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !package.aiStrengths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Strengths", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.positive)

                    ForEach(package.aiStrengths, id: \.self) { strength in
                        HStack(alignment: .top, spacing: 8) {
                            Text("·")
                                .foregroundStyle(AppColor.positive)
                            Text(strength)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(16)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }

            if let improvement = package.aiKeyImprovement {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Key Improvement", systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.caution)

                    Text(improvement)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }

            if package.aiStrengths.isEmpty && package.aiKeyImprovement == nil {
                VStack(spacing: 12) {
                    Image(systemName: "brain")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("AI feedback was not included")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }
        }
    }

    // MARK: - Response Section

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Your Feedback", icon: "text.bubble.fill")

            // Dimension quick-ratings
            if !package.feedbackCategories.isEmpty {
                VStack(spacing: 0) {
                    ForEach(package.feedbackCategories) { cat in
                        HStack {
                            Text(cat.dimension)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            HStack(spacing: 8) {
                                ratingButton(.good, dimension: cat.dimension, icon: "hand.thumbsup.fill")
                                ratingButton(.ok, dimension: cat.dimension, icon: "hand.raised.fill")
                                ratingButton(.couldImprove, dimension: cat.dimension, icon: "arrow.up.right")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        if cat.id != package.feedbackCategories.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }

            // Text response
            TextField("Share your thoughts, observations, or advice...", text: $responseText, axis: .vertical)
                .lineLimit(4...8)
                .padding(14)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            // Submit
            Button {
                // Build response and dismiss
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text("Send Feedback")
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColor.brandBlue.gradient, in: Capsule(style: .continuous))
            }
            .buttonStyle(.pressable)
        }
    }

    private func ratingButton(_ rating: FeedbackRating, dimension: String, icon: String) -> some View {
        let isSelected = dimensionRatings[dimension] == rating
        return Button {
            if isSelected {
                dimensionRatings.removeValue(forKey: dimension)
            } else {
                dimensionRatings[dimension] = rating
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : ratingColor(rating))
                .frame(width: 32, height: 32)
                .background(
                    isSelected ? ratingColor(rating) : ratingColor(rating).opacity(0.1),
                    in: Circle()
                )
        }
        .buttonStyle(.pressable)
    }

    private func ratingColor(_ rating: FeedbackRating) -> Color {
        switch rating {
        case .good: return AppColor.positive
        case .ok: return AppColor.caution
        case .couldImprove: return AppColor.warning
        }
    }
}

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
    var durationAssessment: DurationAssessment = .onTarget
    var targetRange: (min: Double, target: Double, max: Double) = (30, 60, 120)
    var onSelectPracticeMode: () -> Void = {}
    var onHome: () -> Void = {}
    var onPracticeAgain: () -> Void = {}
    var onStartDrill: ((DrillRecommendation) -> Void)?
    var onStartMiniDrill: ((DrillRecommendationV2) -> Void)?

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
    @State private var showShareMenu = false
    @State private var showFeedbackRequestSheet = false
    @State private var feedbackRequestURL: URL?
    @State private var videoAnalysisResult: VideoAnalysisResult?
    @State private var isAnalyzingVideo = false
    @State private var activeMilestone: MilestoneEvent?
    @State private var personalBestMilestone: MilestoneEvent?
    @State private var showPersonalBestScreen = false
    @State private var showLevelUpScreen = false
    @State private var levelUpPreviousLevel: String = ""
    @State private var levelUpNewLevel: String = ""
    @State private var showSecondaryDetails = false
    @State private var coachNoteRevealed = false
    @State private var showAIDisclosure = false
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
        // No words spoken at all = 0
        if transcriptWordCount == 0 { return 0 }
        if effectiveDuration < 4 || transcriptWordCount < 4 { return 1 }
        if effectiveDuration < 8 || transcriptWordCount < 8 { return max(2, 5 - effectiveFillerCount) }
        return max(3, min(8, 7 - effectiveFillerCount))
    }

    /// True when the user barely said anything — don't give credit for zero fillers etc.
    private var isMinimalEffort: Bool {
        transcriptWordCount < 5 || effectiveDuration < 5
    }

    /// The single "Next Rep" drill recommendation for this session (legacy v1).
    private var drillRecommendation: DrillRecommendation {
        DrillEngine.recommend(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            score: scoreValue,
            feedbackCategories: feedbackCategories,
            durationAssessment: durationAssessment
        )
    }

    // MARK: - v2 Drill System

    /// The v2 drill recommendation using trend intelligence and drill catalog.
    private var drillRecommendationV2: DrillRecommendationV2 {
        let categoryTuples = feedbackCategories.map { ($0.dimension, $0.rating.rawValue) }
        return DrillEngineV2.recommend(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            score: scoreValue,
            feedbackCategories: categoryTuples
        )
    }

    /// Skill trends across recent sessions.
    private var skillTrends: [SkillTrend] {
        TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots)
    }

    /// Three-part coach note: momentum, leverage, next step.
    private var coachNote: CoachNote {
        let wpm = effectiveDuration > 0 ? Double(transcriptWordCount) / effectiveDuration * 60 : 0
        let categoryRatings = Dictionary(uniqueKeysWithValues: feedbackCategories.map { ($0.dimension, $0.rating.rawValue) })
        return VerdictEngine.generate(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            wpm: wpm,
            score: scoreValue,
            categoryRatings: categoryRatings,
            trends: skillTrends,
            primaryFocus: drillRecommendationV2.skillArea,
            drillHistory: DrillHistoryStore.shared.entries
        )
    }

    private var headline: String {
        if let lockedHeadlineOverride { return lockedHeadlineOverride }
        if let headlineOverride { return headlineOverride }
        if transcriptWordCount == 0 { return "No response detected" }
        if isMinimalEffort { return "Just getting started" }
        switch scoreValue {
        case 9...10: return "Strong delivery"
        case 7...8: return "Good control"
        case 4...6: return "Building momentum"
        default: return "Room to grow"
        }
    }

    private var verdict: String {
        if let lockedFeedbackOverride { return lockedFeedbackOverride }
        if let feedbackOverride { return feedbackOverride }
        if transcriptWordCount == 0 {
            return "No words were captured. Make sure your microphone is working and try speaking clearly. Tap Retry to give it another go."
        }
        if effectiveDuration < 4 || transcriptWordCount < 4 {
            return "That was barely a start. Hit Retry and commit to at least 15 seconds — even a rough answer counts more than silence."
        }
        if effectiveDuration < 8 || transcriptWordCount < 8 {
            return "Brief answer — try pushing past the opening sentence next time. Even 10 more seconds makes a difference."
        }
        switch scoreValue {
        case 8...10: return "A convincing rep. Keep that same control while raising the difficulty."
        case 6...7: return "There is a solid response in here. One stronger opening sentence would make it feel more complete."
        case 4...5: return "The idea started to form, but it needs more structure and follow-through."
        default: return "Every rep builds the habit. Go again and focus on one strong opening sentence."
        }
    }

    private var scoreAccent: Color {
        switch scoreValue {
        case 8...10: return AppColor.positive
        case 5...7: return AppColor.caution
        default: return AppColor.warning
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
            return ["First rep complete — your baseline is set. From here, every session gives you something to compare against."]
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
            AppColor.screenBackground
                .ignoresSafeArea()

            if showPersonalBestScreen, let milestone = personalBestMilestone {
                // Full-screen personal best celebration (intermediary before summary)
                personalBestCelebration(milestone: milestone)
                    .transition(.opacity)
            } else if showLevelUpScreen {
                // Full-screen level up celebration
                LevelUpCelebrationScreen(
                    newLevel: levelUpNewLevel,
                    previousLevel: levelUpPreviousLevel,
                    xpProgress: progress,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showLevelUpScreen = false
                        }
                    }
                )
                .transition(.opacity)
            } else {
                // Normal summary content — redesigned hierarchy
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // TIER 1: How did I do?
                        heroScoreCard

                        // TIER 2: Coach Note (momentum / leverage)
                        coachNoteCard

                        // TIER 3: Your Next Move (primary CTA)
                        yourNextMoveCard

                        // IM Conversation overview (mode-specific)
                        if isIMSummary, let details = imConversationDetails {
                            imConversationOverview(details)
                        }

                        // TIER 4: Expandable details
                        expandableDetailsSection

                        // Pro Preview (free users only)
                        if !premium.isPremium {
                            proPreviewCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                .safeAreaInset(edge: .bottom) {
                    actionBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            AppColor.cardBackground
                                .shadow(.drop(color: .black.opacity(0.06), radius: 12, y: -4))
                        )
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                if celebrationVisible && !reduceMotion {
                    celebrationOverlay
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Non-personal-best milestones (level-up, streak, first session)
                if let milestone = activeMilestone {
                    MilestoneCelebrationOverlay(
                        icon: milestone.icon,
                        tint: milestone.tint,
                        title: milestone.title,
                        subtitle: milestone.subtitle,
                        detail: milestone.detail,
                        onDismiss: { activeMilestone = nil }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
#if canImport(UIKit)
        .onChange(of: celebrationVisible) { _, visible in
            if visible {
                CoachHaptic.personalBest()
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
            .animation(.bouncySpring, value: celebrationVisible)

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

            // Quick stats row with trend deltas
            HStack(spacing: 20) {
                statPill(label: "Fillers", value: "\(effectiveFillerCount)", delta: fillerDelta, tint: fillerTint, invertDelta: true)
                durationAssessmentPill
                statPill(label: "XP", value: "+\(xpEarned)", delta: nil, tint: .orange, invertDelta: false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [AppColor.cardBackground, scoreAccent.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(scoreAccent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func statPill(label: String, value: String, delta: Int?, tint: Color, invertDelta: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            if let delta, delta != 0 {
                let improved = invertDelta ? delta < 0 : delta > 0
                HStack(spacing: 2) {
                    Image(systemName: improved ? "arrow.down" : "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(abs(delta))")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(improved ? AppColor.positive : AppColor.caution)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Duration assessment pill — shows under/on-target/over with clear explanation
    private var durationAssessmentPill: some View {
        VStack(spacing: 4) {
            Text("\(Int(effectiveDuration))s")
                .font(.headline.weight(.bold))
                .foregroundStyle(durationAssessment.tint)
            Text("Duration")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                Image(systemName: durationAssessment.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(durationAssessment.rawValue)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(durationAssessment.tint)
        }
        .frame(maxWidth: .infinity)
    }

    /// Filler count tint: green if zero or better than average, orange if slightly above, red only if significantly worse.
    /// Gray if no words were spoken — zero fillers isn't an achievement when you said nothing.
    private var fillerTint: Color {
        if isMinimalEffort { return .secondary }
        if effectiveFillerCount == 0 { return AppColor.positive }
        let pastFillers = recentWindow.dropFirst().map(\.fillerWordCount)
        guard !pastFillers.isEmpty else { return AppColor.caution }
        let avg = Double(pastFillers.reduce(0, +)) / Double(pastFillers.count)
        if Double(effectiveFillerCount) <= avg { return AppColor.positive }
        if Double(effectiveFillerCount) <= avg + 2 { return AppColor.caution }
        return AppColor.warning
    }

    /// Delta vs recent average fillers (negative = improved)
    private var fillerDelta: Int? {
        let past = recentWindow.dropFirst().map(\.fillerWordCount)
        guard !past.isEmpty else { return nil }
        let avg = Double(past.reduce(0, +)) / Double(past.count)
        let delta = effectiveFillerCount - Int(avg.rounded())
        return delta
    }

    /// Delta vs recent average duration (positive = improved)
    private var durationDelta: Int? {
        let past = recentWindow.dropFirst().map(\.duration)
        guard !past.isEmpty else { return nil }
        let avg = past.reduce(0, +) / Double(past.count)
        let delta = Int(effectiveDuration) - Int(avg.rounded())
        return abs(delta) >= 3 ? delta : nil // only show if meaningful (3+ seconds)
    }

    // MARK: - Coach Note Card (v2 — replaces verdict)

    private var coachNoteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach Note")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            // Momentum — what's getting stronger (stagger: line 0)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.positive)
                    .frame(width: 18)
                Text(coachNote.momentum)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)

            // Leverage — what's holding them back (stagger: line 1)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "scope")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.caution)
                    .frame(width: 18)
                Text(coachNote.leverage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)

            // Next step — one concrete action (stagger: line 2)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 18)
                Text(coachNote.nextStep)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Your Next Move Card (v2 — replaces nextRepCard)

    private var yourNextMoveCard: some View {
        let drill = drillRecommendationV2
        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: drill.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(drill.tint)
                Text("Your Next Move")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                // Format badge
                Text(drill.format == .miniDrill ? "Quick Drill" : "Full Retry")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(drill.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(drill.tint.opacity(0.1), in: Capsule())
            }

            // Drill title
            Text(drill.title)
                .font(.headline)
                .foregroundStyle(.primary)

            // Session-specific rationale
            Text(drill.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Trend context (if available)
            if let context = drill.trendContext {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(drill.tint.opacity(0.7))
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(drill.tint.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            // Constraint rule
            VStack(alignment: .leading, spacing: 6) {
                Text("Your rule")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(drill.tint)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(drill.constraint)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(drill.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            // Primary CTA — Mini Drill or Full Retry
            if drill.format == .miniDrill {
                Button {
                    onStartMiniDrill?(drill)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("Start Quick Drill (45s)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)

                // Alternate: full retry
                if let onStartDrill {
                    Button {
                        onStartDrill(drillRecommendation)
                    } label: {
                        Text("or Full Retry")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Full retry is the primary action
                if let onStartDrill {
                    Button {
                        onStartDrill(drillRecommendation)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                            Text("Start Full Retry")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                }

                // Alternate: mini drill
                Button {
                    onStartMiniDrill?(drill)
                } label: {
                    Text("or Quick Drill (45s)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // AI Coach suggested drill (if available, shown subtly)
            if let aiFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("AI Coach: \(aiFeedback.suggestedDrill)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Expandable Details Section

    private var expandableDetailsSection: some View {
        VStack(spacing: 12) {
            // Session Details (collapsed by default)
            DisclosureGroup(isExpanded: $showSecondaryDetails) {
                VStack(spacing: 14) {
                    // Category grid
                    if !feedbackCategories.isEmpty {
                        categoryGrid
                    }

                    // AI Moments
                    if !strongMoments.isEmpty || !weakMoments.isEmpty {
                        aiMomentsContent
                    }

                    // Coach Read (premium)
                    if premium.canViewCoachingInsights {
                        coachReadCard
                    }

                    // Video playback
                    if recordingURL != nil {
                        videoPlaybackButton
                    }

                    // Session comparison
                    sessionComparisonCard
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Session Details")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }
            }
            .tint(.secondary)
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)

            // Skill Progress (always visible if trend data exists)
            if !skillTrends.isEmpty {
                SkillProgressView(
                    trends: skillTrends,
                    drillHistory: DrillHistoryStore.shared.entries
                )
            }

            // XP Progress
            xpProgressCard
        }
    }

    // MARK: - Pro Preview Card (Free Users)

    private var proPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                Text("Unlock Deeper Insights")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Text("Pro members get personalized coach reads, video body language analysis, trend tracking, and detailed drills after every session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Preview glimpse — show what a coach read looks like
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Coach Read Preview")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your opening was strong — direct and grounded...")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.5))
                    Text("Filler pattern suggests rehearsal on transitions...")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.3))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    LinearGradient(
                        colors: [.clear, AppColor.cardBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Button {
                showPaywall = true
            } label: {
                HStack {
                    Text("See What Pro Unlocks")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.orange.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
        )
    }

    /// AI Moments content (extracted from the old aiMomentsCard for reuse inside DisclosureGroup)
    private var aiMomentsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !strongMoments.isEmpty {
                Text("Strong Moments")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.positive)
                    .textCase(.uppercase)
                    .tracking(0.6)
                ForEach(strongMoments, id: \.self) { moment in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColor.positive)
                        Text(moment)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
            if !weakMoments.isEmpty {
                Text("Areas to Watch")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.caution)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.top, weakMoments.isEmpty ? 0 : 4)
                ForEach(weakMoments, id: \.self) { moment in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(AppColor.caution)
                        Text(moment)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    /// Video playback button for the expandable section
    private var videoPlaybackButton: some View {
        Button {
            showVideoPlayback = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.caption.weight(.semibold))
                Text("Watch Recording")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppColor.brandBlue)
        }
    }

    /// Session comparison card
    private var sessionComparisonCard: some View {
        Group {
            if recentSessions.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("vs. Recent Average")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    HStack(spacing: 16) {
                        if let fd = fillerDelta {
                            comparisonStat(label: "Fillers", delta: fd, inverted: true)
                        }
                        if let dd = durationDelta {
                            comparisonStat(label: "Duration", delta: dd, inverted: false)
                        }
                    }
                }
            }
        }
    }

    private func comparisonStat(label: String, delta: Int, inverted: Bool) -> some View {
        let improved = inverted ? delta < 0 : delta > 0
        return HStack(spacing: 4) {
            Image(systemName: improved ? "arrow.down" : "arrow.up")
                .font(.caption2.weight(.bold))
            Text("\(abs(delta))")
                .font(.caption.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(improved ? AppColor.positive : AppColor.caution)
    }

    // MARK: - Legacy Verdict Card (kept for backward compatibility)

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
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Next Rep Card

    private var nextRepCard: some View {
        let drill = drillRecommendation
        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: drill.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(drill.tint)
                Text("Next Rep")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(drill.tint.opacity(0.5))
            }

            // Drill title
            Text(drill.title)
                .font(.headline)
                .foregroundStyle(.primary)

            // Why this drill
            Text(drill.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // The constraint / rule
            VStack(alignment: .leading, spacing: 6) {
                Text("Your rule")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(drill.tint)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(drill.constraint)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(drill.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            // Success goal
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(drill.successGoal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // CTA Button
            if onStartDrill != nil {
                Button {
                    onStartDrill?(drill)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                        Text("Start Next Rep")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private struct FreeInsight {
        let icon: String
        let tint: Color
        let message: String
        let action: String
    }

    private var primaryFreeInsight: FreeInsight {
        let wpm = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
        let fillers = effectiveFillerCount
        let dur = effectiveDuration

        // No words at all — the only insight is to actually speak
        if transcriptWordCount == 0 {
            return FreeInsight(
                icon: "mic.slash",
                tint: .secondary,
                message: "No speech was detected. This could be a microphone issue, or the session ended before you started speaking.",
                action: "Tap Retry, take a breath, and start talking — even a rough answer is better than none."
            )
        }

        // Minimal effort
        if isMinimalEffort {
            return FreeInsight(
                icon: "timer",
                tint: .orange,
                message: "You only spoke for about \(Int(dur)) seconds. That's not enough to practice any real speaking skill.",
                action: "Next time, commit to at least 20 seconds. Structure it: opening thought, one example, then a close."
            )
        }

        // High filler count is the most impactful thing to fix
        if fillers >= 5 {
            return FreeInsight(
                icon: "waveform.path",
                tint: .red,
                message: "You used \(fillers) filler words. Most appeared in quick transitions between ideas — the moments where your brain is searching for the next thought.",
                action: "Try this: pause silently for one beat before each new point. Silence feels longer to you than to your audience."
            )
        }

        // Very short answers
        if dur < 15 {
            return FreeInsight(
                icon: "timer",
                tint: .orange,
                message: "Your answer was only \(Int(dur)) seconds. That's too short to develop a complete thought and show control.",
                action: "Try this: after your opening sentence, add one concrete example and then close with a summary."
            )
        }

        // Rushed pace
        if wpm > 160 {
            return FreeInsight(
                icon: "hare.fill",
                tint: .orange,
                message: "Your pace hit \(wpm) words per minute — noticeably fast. Rapid delivery can undermine clarity even when the content is strong.",
                action: "Try this: deliberately slow your first two sentences. That sets a calmer tempo for the rest."
            )
        }

        // Moderate fillers
        if fillers >= 2 {
            return FreeInsight(
                icon: "waveform.path",
                tint: AppColor.caution,
                message: "You used \(fillers) filler words. They tend to cluster when you're transitioning between ideas or thinking out loud.",
                action: "Try this: replace each \"um\" with a silent pause. The silence sounds confident to your audience."
            )
        }

        // Very slow pace
        if wpm > 0 && wpm < 100 && dur >= 15 {
            return FreeInsight(
                icon: "tortoise.fill",
                tint: .blue,
                message: "Your pace was \(wpm) WPM — quite slow. While pausing is good, too much hesitation can make you sound uncertain.",
                action: "Try this: commit to each sentence before starting it, then deliver it at a natural conversational speed."
            )
        }

        // Clean session — reinforce what worked
        if fillers == 0 && dur >= 20 {
            return FreeInsight(
                icon: "checkmark.circle.fill",
                tint: AppColor.positive,
                message: "Zero filler words and \(Int(dur)) seconds of clean delivery. That's genuine control under pressure.",
                action: "Next step: try a harder mode or a longer duration to push this control further."
            )
        }

        // Default — general improvement
        return FreeInsight(
            icon: "lightbulb.fill",
            tint: .blue,
            message: "Your delivery had \(fillers) filler\(fillers == 1 ? "" : "s") across \(Int(dur)) seconds at \(wpm) WPM.",
            action: "Try this: focus on a strong opening sentence. A confident start sets the tone for everything after."
        )
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
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ratingColor(category.rating))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ratingColor(category.rating).opacity(0.08), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func ratingColor(_ rating: FeedbackRating) -> Color {
        switch rating {
        case .good: return AppColor.positive
        case .ok: return AppColor.caution
        case .couldImprove: return AppColor.caution
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
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
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
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
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
                        .foregroundStyle(.primary)
                    Text("Watch Recording")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.cardGap)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                // Save recording
                if videoManager.savedRecordingURL == nil {
                    Button {
                        videoManager.saveRecording()
                    } label: {
                        HStack(spacing: 6) {
                            if videoManager.isSaving {
                                ProgressView()
                                    .tint(.secondary)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.caption)
                            }
                            Text(videoManager.isSaving ? "Saving..." : "Save")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(videoManager.isSaving)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColor.positive)
                        Text("Saved")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }

                // AI Video Analysis
                Button {
                    analyzeVideo()
                } label: {
                    HStack(spacing: 6) {
                        if isAnalyzingVideo {
                            ProgressView()
                                .tint(.secondary)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.caption)
                        }
                        Text(isAnalyzingVideo ? "Analyzing..." : "AI Analysis")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzingVideo)
            }

            // Video analysis results
            if let result = videoAnalysisResult {
                videoAnalysisResultView(result)
            }

            // Recording error display
            if let error = videoManager.recordingError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }

            if videoManager.savedRecordingURL == nil && !videoManager.isSaving {
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
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
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
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
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
                            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
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

            // Gentle approaching-limit note (only when ≥90% used and no feedback yet generated)
            if aiFeedback == nil && aiSettings.isApproachingLimit && !aiSettings.hasReachedLimit {
                Text("\(aiSettings.remainingAnalyses) coaching \(aiSettings.remainingAnalyses == 1 ? "analysis" : "analyses") remaining this month")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if aiSettings.hasReachedLimit && aiFeedback == nil {
                // Graceful at-limit experience — warm, not punitive
                VStack(spacing: 8) {
                    Text("Monthly coaching limit reached")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("You've made great use of AI coaching this month. Fresh analyses will be available \(aiSettings.resetDateFormatted).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, Spacing.md)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            } else {
                Button {
                    if aiSettings.hasAcknowledgedAIDisclosure {
                        Task { await requestDeeperFeedback() }
                    } else {
                        showAIDisclosure = true
                    }
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
                    .background(isRequestingAIFeedback ? Color(.systemGray4) : Color.primary.opacity(0.85), in: Capsule())
                    .foregroundStyle(Color(.systemBackground))
                }
                .buttonStyle(.plain)
                .disabled(isRequestingAIFeedback)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    // MARK: - Secondary Details Section (Collapsed by Default)

    private var secondaryDetailsSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSecondaryDetails.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Details")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: showSecondaryDetails ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if showSecondaryDetails {
                VStack(spacing: 14) {
                    if !feedbackCategories.isEmpty {
                        categoryGrid
                    } else if !effectiveScoreBreakdown.isEmpty {
                        breakdownCard
                    }

                    if let recordingURL {
                        recordingCard(url: recordingURL)
                    }

                    if let comparison = smartComparison {
                        sessionComparisonCard(comparison)
                    }

                    xpProgressCard
                    retentionCard
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
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
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Action Bar (Icon-based)

    private var actionBar: some View {
        HStack(spacing: 0) {
            // Home
            Button { onHome() } label: {
                actionBarItem(icon: "house.fill", label: "Home")
            }
            .buttonStyle(.pressable)

            // Retry Same Prompt
            Button { onPracticeAgain() } label: {
                actionBarItem(icon: "arrow.clockwise", label: "Retry", highlighted: true)
            }
            .buttonStyle(.pressable)

            // New Prompt
            Button { onSelectPracticeMode() } label: {
                actionBarItem(icon: "sparkles", label: "New")
            }
            .buttonStyle(.pressable)

            // Share (opens dual-flow menu)
            Button { showShareMenu = true } label: {
                actionBarItem(icon: "square.and.arrow.up", label: "Share")
            }
            .buttonStyle(.pressable)
        }
        .confirmationDialog("Share Session", isPresented: $showShareMenu) {
            ShareLink(item: shareImage, preview: SharePreview("My Noum Score", image: shareImage)) {
                Label("Share Achievement Card", systemImage: "photo.fill")
            }
            Button {
                showFeedbackRequestSheet = true
            } label: {
                Label("Request Feedback", systemImage: "person.2.fill")
            }
        } message: {
            Text("Choose how to share this session")
        }
        .sheet(isPresented: $showFeedbackRequestSheet) {
            FeedbackRequestComposer(
                transcript: transcriptText,
                fillerCount: effectiveFillerCount,
                duration: effectiveDuration,
                score: scoreValue,
                headline: headline,
                prompt: sessionPrompt,
                theme: sessionTheme,
                mode: currentMode,
                feedbackCategories: feedbackCategories,
                aiFeedback: aiFeedback,
                recordingURL: recordingURL
            )
        }
        .alert("AI Coaching Disclosure", isPresented: $showAIDisclosure) {
            Button("Continue") {
                aiSettings.acknowledgeAIDisclosure()
                Task { await requestDeeperFeedback() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To generate coaching feedback, your speech transcript is sent to \(aiSettings.activeProviderDisplayName) for analysis. Your transcript is processed under their API data terms and is not used to train their AI models. Noum does not sell or share your data with advertisers.")
        }
    }

    private func actionBarItem(icon: String, label: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(highlighted ? .white : .primary.opacity(0.6))
                .frame(width: 44, height: 44)
                .background(
                    highlighted
                        ? AnyShapeStyle(Color.primary.opacity(0.85))
                        : AnyShapeStyle(Color(.systemGray6)),
                    in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                )
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(highlighted ? .blue : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Share Achievement Card (Premium Visual)

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
        VStack(spacing: 0) {
            // Top brand bar
            HStack {
                Text("NOUM")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(4)
                Spacer()
                Text(currentMode.displayLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(shareModeTint.opacity(0.8))
                    .tracking(1.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(shareModeTint.opacity(0.15), in: Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Hero score
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(shareModeTint.opacity(0.12), lineWidth: 3)
                    .frame(width: 140, height: 140)

                // Score ring
                Circle()
                    .trim(from: 0, to: Double(scoreValue) / 10.0)
                    .stroke(
                        AngularGradient(
                            colors: [shareModeTint, shareModeTint.opacity(0.6), shareModeTint],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Track
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 120, height: 120)

                VStack(spacing: 0) {
                    Text("\(scoreValue)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("out of 10")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.bottom, 16)

            // Headline
            Text(headline)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.bottom, 6)

            // Prompt
            if let sessionPrompt {
                Text("\"\(sessionPrompt)\"")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            // Stats row
            HStack(spacing: 0) {
                shareStatCell(value: "\(effectiveFillerCount)", label: "Fillers", tint: fillerTint)
                shareDivider
                shareStatCell(value: "\(Int(effectiveDuration))s", label: "Duration", tint: .blue)
                shareDivider
                shareStatCell(value: "\(shareWPM)", label: "WPM", tint: .orange)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // Footer
            HStack {
                Text("noum.app")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
                Spacer()
                Text(Date().formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 360)
        .background(
            ZStack {
                // Base dark gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.14),
                        Color(red: 0.10, green: 0.08, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Accent glow
                RadialGradient(
                    colors: [shareModeTint.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var shareModeTint: Color {
        AppColor.tint(for: currentMode)
    }

    private var shareWPM: Int {
        guard effectiveDuration > 0 else { return 0 }
        return Int((Double(transcriptWordCount) / effectiveDuration * 60).rounded())
    }

    private func shareStatCell(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    private var shareDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 1, height: 30)
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

        // Same prompt match — always show when available
        if let match = past.first(where: { $0.prompt == prompt && $0.score != nil }) {
            let currentWPM = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
            let matchWPM = match.duration > 0 ? Int(Double(match.transcript.split { !$0.isLetter }.count) / match.duration * 60) : 0
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

        // Same theme match — show whenever there's a theme match
        if let theme = sessionTheme, theme != .all {
            if let match = past.first(where: { $0.theme == theme && $0.score != nil }) {
                let currentWPM = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
                let matchWPM = match.duration > 0 ? Int(Double(match.transcript.split { !$0.isLetter }.count) / match.duration * 60) : 0
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

        // Same mode match — fallback comparison
        if let match = past.first(where: { $0.mode == currentMode && $0.score != nil }) {
            let currentWPM = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
            let matchWPM = match.duration > 0 ? Int(Double(match.transcript.split { !$0.isLetter }.count) / match.duration * 60) : 0
            return SessionComparison(
                reason: "Previous \(currentMode.displayLabel) session",
                previousScore: match.score ?? 0,
                currentScore: currentScore,
                previousWPM: matchWPM,
                currentWPM: currentWPM,
                previousFillers: match.fillerWordCount,
                currentFillers: lockedFillerCount ?? fillerCount,
                previousDate: match.date
            )
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
                    .foregroundStyle(AppColor.positive)
            } else if scoreDelta == 0 {
                Text("Consistency is progress. Same score, building the habit.")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(Spacing.cardGap)
        .background(
            (improved ? Color.green : Color.orange).opacity(0.06),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
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
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
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
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    // MARK: - Personal Best Celebration (Full-Screen Intermediary)

    private func personalBestCelebration(milestone: MilestoneEvent) -> some View {
        PersonalBestCelebrationScreen(
            scoreValue: scoreValue,
            scoreAccent: scoreAccent,
            modeName: currentMode.displayLabel,
            previousBest: milestone.detail,
            onContinue: {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showPersonalBestScreen = false
                }
            }
        )
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

        let levelBefore = ProfileManager.levelTitle(forXP: profile.xp)
        profile.addXP(xpEarned)
        let levelAfter = ProfileManager.levelTitle(forXP: profile.xp)
        animateXP(to: profile.xp)
        animateSegments()
        CoachHaptic.scoreReveal()
        withAnimation(.easeInOut(duration: 0.35)) {
            celebrationVisible = scoreValue >= 7 || xpEarned >= 100
        }
        // Stagger the coach note card lines in after the score settles
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) { coachNoteRevealed = true }
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) {
                    celebrationVisible = false
                }
            }
        }

        // Milestone detection — personal bests and level-ups get full intermediary screens,
        // other milestones (streak, first session) use the compact overlay.
        let milestone = detectMilestone(levelBefore: levelBefore, levelAfter: levelAfter)
        if let milestone {
            if milestone.title == "New Personal Best!" {
                personalBestMilestone = milestone
                showPersonalBestScreen = true
            } else if milestone.title == "Level Up!" {
                levelUpPreviousLevel = levelBefore
                levelUpNewLevel = levelAfter
                showLevelUpScreen = true
            } else {
                Task {
                    try? await Task.sleep(for: .seconds(2.2))
                    await MainActor.run {
                        withAnimation(.standardSpring) { activeMilestone = milestone }
                    }
                }
            }
        }
        // Record skill snapshot for trend analysis
        var categoryMap: [String: String] = [:]
        for seg in lockedScoreBreakdown {
            categoryMap[seg.title] = seg.value
        }
        SkillTrendStore.shared.recordFromSession(
            sessionId: latestSessionID ?? UUID(),
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: (lockedTranscriptText ?? "").split(separator: " ").count,
            score: scoreValue,
            categoryRatings: categoryMap
        )

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

        // Check API configuration with specific error messages
        if aiSettings.activeProvider == nil {
            aiError = "Add an AI API key in Settings to enable Coach Read."
            return
        }
        if aiSettings.hasReachedLimit {
            aiError = "You've used all \(aiSettings.monthlyLimit) coaching analyses this month. Fresh analyses available \(aiSettings.resetDateFormatted)."
            return
        }

        guard let sessionID = latestSessionID else {
            aiError = "This session has not been saved yet. Finish one more rep and try again."
            return
        }

        let text = transcriptText
        let wordCount = text.split(whereSeparator: \.isWhitespace).count
        if wordCount < 10 {
            aiError = "Speak at least 10 words to generate coaching feedback."
            return
        }

        isRequestingAIFeedback = true
        defer { isRequestingAIFeedback = false }

        do {
            let plan = CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
            let styleSnapshot = PracticeEvaluator.speakingIdentity(
                for: text,
                profile: coachingProfileStore.profile
            )
            let feedback = try await aiCoachService.generateDeeperFeedback(
                input: AICoachSessionInput(
                    transcript: text,
                    mode: recentSessions.first?.mode ?? .timed,
                    score: score,
                    fillerCount: fillerCount,
                    duration: duration,
                    wordsPerMinute: PracticeEvaluator.paceSnapshot(
                        forTranscript: text,
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
            let desc = error.localizedDescription
            if desc.contains("transcriptTooShort") || desc.contains("too short") {
                aiError = "Speak at least 10 words to generate coaching feedback."
            } else if desc.contains("API key") || desc.contains("apiKey") {
                aiError = "API key issue — check your AI provider settings."
            } else {
                aiError = "Coach Read failed: \(desc)"
            }
        }
    }

    private func analyzeVideo() {
        guard let url = recordingURL else { return }
        isAnalyzingVideo = true

        Task {
            do {
                let result = try await VideoAnalysisService.shared.analyzeRecording(at: url)
                await MainActor.run {
                    videoAnalysisResult = result
                    isAnalyzingVideo = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzingVideo = false
                    let desc = error.localizedDescription
                    if desc.contains("API key") || desc.contains("apiKey") || desc.contains("configured") {
                        aiError = "Add an AI API key in Settings to analyze video."
                    } else {
                        aiError = "Video analysis failed: \(desc)"
                    }
                }
            }
        }
    }

    private func detectMilestone(levelBefore: String, levelAfter: String) -> MilestoneEvent? {
        // 1. Level-up (highest priority — gets full-screen celebration)
        if levelBefore != levelAfter {
            return MilestoneEvent(
                icon: "arrow.up.circle.fill",
                tint: .blue,
                title: "Level Up!",
                subtitle: levelAfter,
                detail: "Keep practicing to reach the next rank."
            )
        }

        // 2. Personal best score (across all sessions in the same mode)
        let pastScores = sessionStore.sessions
            .filter { $0.mode == currentMode }
            .dropFirst() // exclude the session we just saved
            .compactMap(\.score)
        let previousBest = pastScores.max() ?? 0
        if scoreValue > previousBest && scoreValue >= 6 && !pastScores.isEmpty {
            return MilestoneEvent(
                icon: "star.fill",
                tint: .orange,
                title: "New Personal Best!",
                subtitle: "\(scoreValue)/10 in \(currentMode.displayLabel)",
                detail: previousBest > 0 ? "Previous best: \(previousBest)/10" : nil
            )
        }

        // 3. Streak milestones (3, 7, 14, 30 days)
        let streak = sessionStreak
        if [3, 7, 14, 30].contains(streak) {
            let copy = MilestoneCopy.streakMilestone(streak)
            return MilestoneEvent(
                icon: "flame.fill",
                tint: .orange,
                title: copy.title,
                subtitle: copy.subtitle,
                detail: copy.detail
            )
        }

        // 4. Session count milestones (10, 25, 50, 100)
        let count = sessionStore.sessions.count
        if [10, 25, 50, 100].contains(count) {
            let copy = MilestoneCopy.sessionCount(count)
            return MilestoneEvent(
                icon: "number.circle.fill",
                tint: .blue,
                title: copy.title,
                subtitle: copy.subtitle,
                detail: copy.detail
            )
        }

        // 5. Skill resolved (a previously problematic skill is now resolved)
        let trends = skillTrends
        if let resolved = trends.first(where: { $0.direction == .resolved }) {
            let copy = MilestoneCopy.skillResolved(resolved.skillArea)
            return MilestoneEvent(
                icon: "checkmark.seal.fill",
                tint: AppColor.positive,
                title: copy.title,
                subtitle: copy.subtitle,
                detail: copy.detail
            )
        }

        // 6. First session ever
        if sessionStore.sessions.count == 1 {
            return MilestoneEvent(
                icon: "sparkles",
                tint: .blue,
                title: "First Rep Complete!",
                subtitle: "Your speaking journey starts now",
                detail: "The app learns your patterns over time — it gets smarter the more you use it."
            )
        }

        return nil
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
                CoachHaptic.xpEarned()
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

// MARK: - Path-based Navigation Init (in extension to preserve memberwise init)
#if canImport(SwiftUI)
extension SummaryView {
    /// Path-based navigation initializer. Pulls all heavy data from SummaryDataStore.
    init(payload: SummaryPayload, navigationPath: Binding<NavigationPath>) {
        let store = SummaryDataStore.shared
        let entry = store.retrieve(for: payload.id)

        self.transcript = entry?.transcript ?? AttributedString("")
        self.fillerCount = entry?.fillerCount ?? 0
        self.duration = entry?.duration ?? 0
        self.score = entry?.score
        self.progressSegments = entry?.progressSegments ?? 0
        self.xpEarned = entry?.xpEarned ?? 0
        self.showDuration = entry?.showDuration ?? true
        self.practiceTitle = entry?.practiceTitle ?? "Practice Summary"
        self.feedbackOverride = entry?.feedbackOverride
        self.headlineOverride = entry?.headlineOverride
        self.scoreBreakdown = entry?.scoreBreakdown ?? []
        self.insights = entry?.insights ?? []
        self.recentSessions = entry?.recentSessions ?? []
        self.imConversationDetails = entry?.imConversationDetails
        self.explicitMode = entry?.explicitMode ?? payload.mode
        self.recordingURL = entry?.recordingURL
        self.sessionPrompt = entry?.sessionPrompt
        self.sessionTheme = entry?.sessionTheme
        self.feedbackCategories = entry?.feedbackCategories ?? []
        self.strongMoments = entry?.strongMoments ?? []
        self.weakMoments = entry?.weakMoments ?? []
        self.durationAssessment = entry?.durationAssessment ?? .onTarget
        self.targetRange = entry?.targetRange ?? (30, 60, 120)

        // Path-based navigation callbacks
        let pathBinding = navigationPath
        let payloadId = payload.id
        let payloadMode = payload.mode
        self.onHome = {
            SummaryDataStore.shared.remove(for: payloadId)
            pathBinding.wrappedValue = NavigationPath()
        }
        self.onSelectPracticeMode = {
            SummaryDataStore.shared.remove(for: payloadId)
            pathBinding.wrappedValue = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pathBinding.wrappedValue.append(AppDestination.practiceSelection)
            }
        }
        self.onPracticeAgain = {
            SummaryDataStore.shared.remove(for: payloadId)
            var path = pathBinding.wrappedValue
            if path.count > 0 { path.removeLast() }
            if path.count > 0 { path.removeLast() }
            pathBinding.wrappedValue = path
            let destination: AppDestination
            switch payloadMode {
            case .timed: destination = .timedPractice
            case .suddenDeath: destination = .suddenDeathPractice
            case .ahCounter: destination = .ahCounterPractice
            case .imConversation: destination = .imPractice(scenario: nil, tone: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pathBinding.wrappedValue.append(destination)
            }
        }
        self.onStartDrill = entry?.onStartDrill
        self.onStartMiniDrill = entry?.onStartMiniDrill
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

// MARK: - Personal Best Celebration Screen

struct PersonalBestCelebrationScreen: View {
    let scoreValue: Int
    let scoreAccent: Color
    let modeName: String
    let previousBest: String?
    let onContinue: () -> Void

    @State private var phase1 = false  // score ring
    @State private var phase2 = false  // text
    @State private var phase3 = false  // particles
    @State private var starRotation: Double = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    scoreAccent.opacity(0.15),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Floating particles
            if phase3 {
                particleField
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Star icon
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(scoreAccent.opacity(phase1 ? 0.15 - Double(i) * 0.04 : 0), lineWidth: 2)
                            .frame(width: CGFloat(160 + i * 40), height: CGFloat(160 + i * 40))
                            .scaleEffect(phase1 ? 1.0 : 0.5)
                    }

                    // Score ring
                    Circle()
                        .stroke(scoreAccent.opacity(0.2), lineWidth: 10)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: phase1 ? Double(scoreValue) / 10.0 : 0)
                        .stroke(scoreAccent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))

                    // Star
                    Image(systemName: "star.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(scoreAccent)
                        .scaleEffect(phase1 ? 1.0 : 0.1)
                        .rotationEffect(.degrees(starRotation))
                }

                Spacer().frame(height: 40)

                // Title
                VStack(spacing: 12) {
                    Text("NEW PERSONAL BEST")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(scoreAccent)
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 20)

                    Text("\(scoreValue)/10")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(phase2 ? 1 : 0)
                        .scaleEffect(phase2 ? 1.0 : 0.7)

                    Text(modeName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 10)

                    if let previousBest {
                        Text(previousBest)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.4))
                            .opacity(phase2 ? 1 : 0)
                            .padding(.top, 4)
                    }
                }

                Spacer()

                // Continue button
                Button {
                    onContinue()
                } label: {
                    Text("View Results")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(scoreAccent, in: Capsule())
                }
                .buttonStyle(.pressable)
                .opacity(phase2 ? 1 : 0)
                .offset(y: phase2 ? 0 : 30)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
#if canImport(UIKit)
        // Initial heavy haptic
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
#endif

        // Phase 1: Score ring + star scale in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            phase1 = true
        }
        withAnimation(.easeInOut(duration: 1.2)) {
            starRotation = 360
        }

#if canImport(UIKit)
        // Haptic burst during animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
#endif

        // Phase 2: Text fades in
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            phase2 = true
        }

        // Phase 3: Particles
        withAnimation(.easeIn(duration: 0.3).delay(0.7)) {
            phase3 = true
        }
    }

    private var particleField: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<20, id: \.self) { i in
                        let seed = Double(i) * 1.618
                        let x = geo.size.width * (0.05 + (seed.truncatingRemainder(dividingBy: 0.9)))
                        let speed = 0.8 + seed.truncatingRemainder(dividingBy: 1.2)
                        let travel = (t * speed).truncatingRemainder(dividingBy: 4.0) / 4.0
                        let y = geo.size.height * (1.0 - travel)

                        Image(systemName: i.isMultiple(of: 3) ? "sparkle" : i.isMultiple(of: 2) ? "star.fill" : "circle.fill")
                            .font(.system(size: CGFloat(4 + (i % 5) * 2)))
                            .foregroundStyle(scoreAccent.opacity(0.3 * (1.0 - travel)))
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Level Up Celebration Screen

struct LevelUpCelebrationScreen: View {
    let newLevel: String
    let previousLevel: String
    let xpProgress: Double  // 0...1 towards next sub-level
    let onContinue: () -> Void

    @State private var phase1 = false
    @State private var phase2 = false
    @State private var phase3 = false
    @State private var ringRotation: Double = 0

    private var levelTint: Color {
        if newLevel.contains("Beginner") { return .blue }
        if newLevel.contains("Novice") { return .teal }
        if newLevel.contains("Average") { return .indigo }
        if newLevel.contains("Professional") { return .orange }
        return .yellow
    }

    private var levelIcon: String {
        if newLevel.contains("Beginner") { return "sparkles" }
        if newLevel.contains("Novice") { return "figure.stand" }
        if newLevel.contains("Average") { return "waveform.path.ecg" }
        if newLevel.contains("Professional") { return "shield.lefthalf.filled" }
        return "crown.fill"
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.black,
                    levelTint.opacity(0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating particles
            if phase3 {
                levelUpParticles
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Icon with rings
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(levelTint.opacity(phase1 ? 0.12 - Double(i) * 0.03 : 0), lineWidth: 1.5)
                            .frame(width: CGFloat(150 + i * 35), height: CGFloat(150 + i * 35))
                            .scaleEffect(phase1 ? 1.0 : 0.4)
                    }

                    Circle()
                        .fill(levelTint.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(phase1 ? 1.0 : 0.5)

                    Circle()
                        .stroke(levelTint.opacity(0.3), lineWidth: 4)
                        .frame(width: 120, height: 120)
                        .scaleEffect(phase1 ? 1.0 : 0.5)

                    Image(systemName: levelIcon)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(levelTint)
                        .scaleEffect(phase1 ? 1.0 : 0.1)
                        .rotationEffect(.degrees(ringRotation))
                }

                Spacer().frame(height: 44)

                // Text content
                VStack(spacing: 14) {
                    Text("LEVEL UP")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(levelTint)
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 20)

                    Text(newLevel)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(phase2 ? 1 : 0)
                        .scaleEffect(phase2 ? 1.0 : 0.8)

                    Text("Previously: \(previousLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 10)

                    Text("Keep practicing to reach the next rank")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.3))
                        .opacity(phase2 ? 1 : 0)
                        .padding(.top, 4)
                }

                Spacer()

                // Continue button
                Button {
                    onContinue()
                } label: {
                    Text("View Results")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(levelTint, in: Capsule())
                }
                .buttonStyle(.pressable)
                .opacity(phase2 ? 1 : 0)
                .offset(y: phase2 ? 0 : 30)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear { runLevelUpAnimation() }
    }

    private func runLevelUpAnimation() {
#if canImport(UIKit)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
#endif

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            phase1 = true
        }
        withAnimation(.easeInOut(duration: 1.0)) {
            ringRotation = 360
        }

#if canImport(UIKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
#endif

        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            phase2 = true
        }
        withAnimation(.easeIn(duration: 0.3).delay(0.6)) {
            phase3 = true
        }
    }

    private var levelUpParticles: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<16, id: \.self) { i in
                        let seed = Double(i) * 1.618
                        let x = geo.size.width * (0.05 + (seed.truncatingRemainder(dividingBy: 0.9)))
                        let speed = 0.6 + seed.truncatingRemainder(dividingBy: 1.0)
                        let travel = (t * speed).truncatingRemainder(dividingBy: 5.0) / 5.0
                        let y = geo.size.height * (1.0 - travel)

                        Image(systemName: i.isMultiple(of: 3) ? "arrow.up" : i.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                            .font(.system(size: CGFloat(3 + (i % 4) * 2)))
                            .foregroundStyle(levelTint.opacity(0.25 * (1.0 - travel)))
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#endif
