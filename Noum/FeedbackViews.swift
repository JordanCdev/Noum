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

                    // Send buttons
                    sendSection
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

    // MARK: - Send Buttons

    @State private var showFriendPicker = false
    @State private var selectedFriend: NoumFriend?
    @State private var requestSent = false

    private var sendSection: some View {
        VStack(spacing: 12) {
            // Primary: Send to a friend (in-app)
            Button {
                showFriendPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.headline.weight(.semibold))
                    Text("Send to Friend")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColor.brandBlue.gradient, in: Capsule(style: .continuous))
            }
            .buttonStyle(.pressable)

            // Secondary: External share
            ShareLink(item: feedbackShareText) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                    Text("Share Externally")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.04), in: Capsule())
            }
        }
        .sheet(isPresented: $showFriendPicker) {
            friendPickerSheet
        }
        .overlay {
            if requestSent {
                requestSentConfirmation
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var friendPickerSheet: some View {
        NavigationStack {
            List {
                if FriendsManager.shared.friends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No friends added yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Add friends from your Profile to send them feedback requests.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(FriendsManager.shared.friends) { friend in
                        Button {
                            sendToFriend(friend)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppColor.brandBlue.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Text(friend.initials)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppColor.brandBlue)
                                }
                                Text(friend.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "paperplane.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.brandBlue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showFriendPicker = false }
                }
            }
        }
    }

    private func sendToFriend(_ friend: NoumFriend) {
        _ = FeedbackRequestManager.shared.createRequest(
            recipientName: friend.displayName,
            transcript: includeTranscript ? transcript : "",
            score: score,
            headline: headline,
            prompt: prompt,
            mode: mode,
            requestNote: requestNote
        )
        showFriendPicker = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            requestSent = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { requestSent = false }
            dismiss()
        }
    }

    private var requestSentConfirmation: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Request sent")
                .font(.headline.weight(.bold))
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                // Save response via FeedbackRequestManager
                let ratingStrings = dimensionRatings.mapValues { $0.rawValue }
                FeedbackRequestManager.shared.addResponse(
                    requestId: package.id,
                    responderName: "You",
                    textFeedback: responseText,
                    dimensionRatings: ratingStrings
                )
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
                .background(
                    responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.gray.gradient
                        : AppColor.brandBlue.gradient,
                    in: Capsule(style: .continuous)
                )
            }
            .buttonStyle(.pressable)
            .disabled(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
