import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

// MARK: - Toastmasters Table Topics Timing

enum TableTopicsTimingState: Equatable {
    case neutral
    case green
    case yellow
    case red
    case overtime

    var color: Color {
        switch self {
        case .neutral: return Color(.systemGray4)
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        case .overtime: return .red
        }
    }

    /// Vivid color for spotlight / immersive mode
    var vividColor: Color {
        switch self {
        case .neutral: return Color(.systemGray3)
        case .green: return Color(red: 0.2, green: 0.84, blue: 0.42)
        case .yellow: return Color(red: 1.0, green: 0.78, blue: 0.0)
        case .red: return Color(red: 1.0, green: 0.23, blue: 0.19)
        case .overtime: return Color(red: 1.0, green: 0.23, blue: 0.19)
        }
    }

    /// Background tint for spotlight mode
    var backgroundTint: Color {
        switch self {
        case .neutral: return Color(.systemGray6)
        case .green: return Color(red: 0.2, green: 0.84, blue: 0.42).opacity(0.06)
        case .yellow: return Color(red: 1.0, green: 0.78, blue: 0.0).opacity(0.06)
        case .red: return Color(red: 1.0, green: 0.23, blue: 0.19).opacity(0.07)
        case .overtime: return Color(red: 1.0, green: 0.23, blue: 0.19).opacity(0.10)
        }
    }

    var label: String {
        switch self {
        case .neutral: return "Keep going"
        case .green: return "Green — good length"
        case .yellow: return "Yellow — wrap up"
        case .red: return "Red — over time"
        case .overtime: return "Time's up"
        }
    }

    /// More expressive labels for spotlight / immersive mode
    var spotlightLabel: String {
        switch self {
        case .neutral: return "Speak now"
        case .green: return "Good length"
        case .yellow: return "Wrap it up"
        case .red: return "Over time"
        case .overtime: return "Time's up"
        }
    }

    static func state(forElapsedSeconds seconds: Int) -> TableTopicsTimingState {
        switch seconds {
        case ..<60: return .neutral
        case 60..<90: return .green
        case 90..<120: return .yellow
        case 120..<150: return .red
        default: return .overtime
        }
    }

    static let hardStopSeconds = 150
}

// MARK: - Timer Display Option

private enum TimerDisplayOption: String, CaseIterable, Identifiable {
    case none
    case elapsed
    case remaining
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .elapsed: return "Elapsed"
        case .remaining: return "Remaining"
        case .both: return "Both"
        }
    }

    var showsElapsed: Bool { self == .elapsed || self == .both }
    var showsRemaining: Bool { self == .remaining || self == .both }
}

// MARK: - Session Phase

private enum TimedSessionPhase: Equatable {
    case setup
    case thinking
    case briefReveal
    case speaking
}

// MARK: - TimedPracticeView

@available(iOS 17.0, macOS 12.0, *)
struct TimedPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared

    // Session state
    @State private var question: String = PracticeTopics.random()
    @State private var phase: TimedSessionPhase = .setup
    @State private var thinkingCountdown: Int = 15
    @State private var elapsedSeconds: Int = 0
    @State private var showSummary = false
    @State private var evaluation: PracticeEvaluation?
    @State private var isStopping = false

    // Tasks
    @State private var thinkingTask: Task<Void, Never>?
    @State private var speakingTask: Task<Void, Never>?

    // Settings
    @State private var keepPromptVisible: Bool = true
    @State private var timerDisplay: TimerDisplayOption = .none
    @State private var enableThinkingTime: Bool = true
    @State private var showLiveTranscript: Bool = true
    @State private var showFillerWords: Bool = true

    private let totalDuration = TableTopicsTimingState.hardStopSeconds

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch phase {
                    case .setup:
                        setupContent
                    case .thinking:
                        thinkingContent
                    case .briefReveal:
                        briefRevealContent
                    case .speaking:
                        speakingContent
                    }
                }
                .frame(maxHeight: .infinity)

                bottomButton
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("timedPractice.screen")
        .onDisappear { cleanup() }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: evaluation?.score,
                progressSegments: progressSegments,
                xpEarned: evaluation?.xpEarned ?? 0,
                showDuration: false,
                practiceTitle: "Table Topics Practice",
                feedbackOverride: evaluation?.feedback,
                headlineOverride: evaluation?.headline,
                scoreBreakdown: evaluation?.segments ?? [],
                insights: evaluation?.insights ?? [],
                recentSessions: speechVM.pastSessions,
                onSelectPracticeMode: {
                    showSummary = false
                    dismiss(times: 2)
                },
                onHome: {
                    showSummary = false
                    dismiss(times: 3)
                },
                onPracticeAgain: {
                    showSummary = false
                    restartSession()
                }
            )
        }
    }

    // MARK: - Computed

    private var timingState: TableTopicsTimingState {
        TableTopicsTimingState.state(forElapsedSeconds: elapsedSeconds)
    }

    private var progressSegments: Int {
        switch timingState {
        case .neutral: return 0
        case .green: return 1
        case .yellow: return 2
        case .red: return 3
        case .overtime: return 4
        }
    }

    private var remainingSeconds: Int {
        max(0, totalDuration - elapsedSeconds)
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Setup Phase (passive config screen)

    private var setupContent: some View {
        VStack(spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("TABLE TOPICS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Table Topics Practice")
                    .font(.title2.weight(.bold))
                Text("You'll receive a random prompt and have up to 2 minutes 30 seconds to respond, just like a real Toastmasters Table Topics round.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Settings
            VStack(spacing: 0) {
                settingsToggle("Show prompt during speech", isOn: $keepPromptVisible)
                Divider().padding(.leading, 16)
                timerDisplayRow
                Divider().padding(.leading, 16)
                settingsToggle("15-second thinking time", isOn: $enableThinkingTime)
                Divider().padding(.leading, 16)
                settingsToggle("Show live transcript", isOn: $showLiveTranscript)
                Divider().padding(.leading, 16)
                settingsToggle("Show filler words", isOn: $showFillerWords)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.subheadline)
        }
        .tint(.blue)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var timerDisplayRow: some View {
        HStack {
            Text("Timer display")
                .font(.subheadline)
            Spacer()
            Picker("Timer display", selection: $timerDisplay) {
                ForEach(TimerDisplayOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Thinking Phase (prompt + countdown)

    private var thinkingContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            // Prompt card
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR TOPIC")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(question)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)

            Spacer(minLength: 24)

            // Countdown
            VStack(spacing: 6) {
                Text("\(thinkingCountdown)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .contentTransition(.numericText())
                Text("seconds to think")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Brief Reveal (for no-thinking + no-prompt-during-speech)

    private var briefRevealContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("YOUR TOPIC")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(question)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Starting soon...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - Speaking Phase

    private var speakingContent: some View {
        VStack(spacing: 0) {
            if showLiveTranscript {
                speakingTranscriptLayout
            } else {
                speakingImmersiveLayout
            }
        }
    }

    // Transcript-based (tool-like) layout
    private var speakingTranscriptLayout: some View {
        VStack(spacing: 8) {
            // Compact header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TABLE TOPICS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Speak now")
                        .font(.headline)
                }
                Spacer()
                if speechVM.connectionError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Timing bar
            timingIndicator

            // Timer text
            if timerDisplay.showsElapsed || timerDisplay.showsRemaining {
                timerTextRow
            }

            // Optional prompt
            if keepPromptVisible {
                compactPrompt
            }

            // Transcript area
            ScrollView {
                Text(speechVM.highlightedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)

            // Filler words
            if showFillerWords {
                fillerWordsRow
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    // MARK: - Spotlight Mode (immersive, non-transcript)

    @State private var spotlightPulse: Bool = false
    @State private var lastMilestoneState: TableTopicsTimingState = .neutral

    private var speakingImmersiveLayout: some View {
        ZStack {
            // Phase-reactive background
            timingState.backgroundTint
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: timingState)

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                // Central focal element
                spotlightOrb
                    .padding(.horizontal, 32)

                Spacer(minLength: 20)

                // Prompt (elegant floating pill)
                if keepPromptVisible {
                    spotlightPromptPill
                        .padding(.bottom, 12)
                }

                // Filler words (compact chip)
                if showFillerWords && speechVM.fillerWordCount > 0 {
                    spotlightFillerChip
                        .padding(.bottom, 8)
                }

                if speechVM.connectionError != nil {
                    Text("Transcription issue")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(.bottom, 4)
                }
            }
        }
        .onChange(of: timingState) { _, newState in
            if newState != lastMilestoneState {
                lastMilestoneState = newState
                if newState != .neutral {
                    triggerMilestoneHaptic(for: newState)
                }
            }
        }
    }

    // MARK: Spotlight Orb (central element)

    private let orbSize: CGFloat = 220

    private var spotlightOrb: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            timingState.vividColor.opacity(spotlightPulse ? 0.25 : 0.12),
                            timingState.vividColor.opacity(0)
                        ],
                        center: .center,
                        startRadius: orbSize * 0.4,
                        endRadius: orbSize * 0.7
                    )
                )
                .frame(width: orbSize * 1.4, height: orbSize * 1.4)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: spotlightPulse)

            // Track ring (background)
            Circle()
                .stroke(Color(.systemGray5).opacity(0.5), lineWidth: 8)
                .frame(width: orbSize, height: orbSize)

            // Milestone markers on the ring
            spotlightMilestoneMarkers

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(min(elapsedSeconds, totalDuration)) / CGFloat(totalDuration))
                .stroke(
                    timingState.vividColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: orbSize, height: orbSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: timingState.vividColor.opacity(0.5), radius: timingState == .neutral ? 0 : 8)
                .animation(.easeInOut(duration: 0.6), value: elapsedSeconds)

            // Center content
            spotlightCenterContent
        }
        .onAppear { spotlightPulse = true }
    }

    private var spotlightMilestoneMarkers: some View {
        let milestones: [(seconds: Int, state: TableTopicsTimingState)] = [
            (60, .green), (90, .yellow), (120, .red)
        ]

        return ForEach(milestones, id: \.seconds) { milestone in
            let angle = Angle.degrees(Double(milestone.seconds) / Double(totalDuration) * 360 - 90)
            let reached = elapsedSeconds >= milestone.seconds

            Circle()
                .fill(reached ? milestone.state.vividColor : Color(.systemGray4))
                .frame(width: reached ? 10 : 6, height: reached ? 10 : 6)
                .shadow(color: reached ? milestone.state.vividColor.opacity(0.6) : .clear, radius: 4)
                .offset(
                    x: (orbSize / 2) * cos(angle.radians),
                    y: (orbSize / 2) * sin(angle.radians)
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: reached)
        }
    }

    private var spotlightCenterContent: some View {
        VStack(spacing: 6) {
            switch timerDisplay {
            case .none:
                // Stage label only
                Text(timingState.spotlightLabel)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(timingState == .neutral ? .primary : timingState.vividColor)
                    .contentTransition(.interpolate)

            case .elapsed:
                // Elapsed as primary
                Text(formattedTime(elapsedSeconds))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(timingState.spotlightLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(timingState == .neutral ? .secondary : timingState.vividColor)

            case .remaining:
                // Remaining as primary
                Text(formattedTime(remainingSeconds))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(timingState == .red || timingState == .overtime ? timingState.vividColor : .primary)
                    .contentTransition(.numericText())
                Text(timingState.spotlightLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(timingState == .neutral ? .secondary : timingState.vividColor)

            case .both:
                // Remaining primary, elapsed secondary
                Text(formattedTime(remainingSeconds))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(timingState == .red || timingState == .overtime ? timingState.vividColor : .primary)
                    .contentTransition(.numericText())
                Text(timingState.spotlightLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(timingState == .neutral ? .secondary : timingState.vividColor)
                Text(formattedTime(elapsedSeconds))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }
        }
        .animation(.easeInOut(duration: 0.3), value: timingState)
    }

    // MARK: Spotlight Prompt Pill

    private var spotlightPromptPill: some View {
        HStack(spacing: 8) {
            Text(question)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 24)
    }

    // MARK: Spotlight Filler Chip

    private var spotlightFillerChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 6, height: 6)
            Text("Fillers")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(speechVM.fillerWordCount)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: Haptics

    private func triggerMilestoneHaptic(for state: TableTopicsTimingState) {
        let generator = UIImpactFeedbackGenerator(style: state == .red || state == .overtime ? .heavy : .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Shared Speaking Components

    private var timingIndicator: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                timingSegment(active: elapsedSeconds >= 0, state: .neutral, label: "0:00")
                timingSegment(active: elapsedSeconds >= 60, state: .green, label: "1:00")
                timingSegment(active: elapsedSeconds >= 90, state: .yellow, label: "1:30")
                timingSegment(active: elapsedSeconds >= 120, state: .red, label: "2:00")
            }
            .padding(.horizontal, 16)

            if showLiveTranscript {
                Text(timingState.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(timingState == .neutral ? .secondary : timingState.color)
                    .animation(.easeInOut(duration: 0.3), value: timingState)
            }
        }
    }

    private func timingSegment(active: Bool, state: TableTopicsTimingState, label: String) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3)
                .fill(active ? state.color : Color(.systemGray5))
                .frame(height: 6)
                .animation(.easeInOut(duration: 0.4), value: active)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(active ? .primary : .tertiary)
        }
    }

    private var timerTextRow: some View {
        HStack(spacing: 16) {
            if timerDisplay.showsElapsed {
                HStack(spacing: 4) {
                    Image(systemName: "stopwatch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedTime(elapsedSeconds))
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .contentTransition(.numericText())
                }
            }
            if timerDisplay == .both {
                Text("·")
                    .foregroundStyle(.tertiary)
            }
            if timerDisplay.showsRemaining {
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedTime(remainingSeconds))
                        .font(.system(.subheadline, design: .monospaced).weight(.medium))
                        .foregroundStyle(timingState == .red || timingState == .overtime ? .red : .primary)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var compactPrompt: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(question)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var fillerWordsRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red.opacity(0.18))
                .frame(width: 10, height: 10)
            Text("Filler Words")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(speechVM.fillerWordCount)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Group {
            switch phase {
            case .setup:
                Button(action: { beginSession() }) {
                    Text("Begin Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)

            case .thinking:
                Button(action: { skipThinkingAndSpeak() }) {
                    Text("Start Now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)

            case .briefReveal:
                EmptyView()

            case .speaking:
                Button(action: { stopSession() }) {
                    Text("Stop")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .background(Color.red, in: Capsule())
                .foregroundStyle(.white)
                .disabled(isStopping)
                .opacity(isStopping ? 0.6 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    /// User taps "Begin Session" on setup screen
    private func beginSession() {
        guard phase == .setup else { return }
        question = PracticeTopics.random()

        if enableThinkingTime {
            // Go to thinking phase with countdown
            thinkingCountdown = 15
            withAnimation(.easeInOut(duration: 0.3)) { phase = .thinking }
            startThinkingCountdown()
        } else if !keepPromptVisible {
            // No thinking time AND prompt won't be shown during speech
            // Show a brief reveal so the user sees the topic
            withAnimation(.easeInOut(duration: 0.3)) { phase = .briefReveal }
            Task {
                try? await Task.sleep(for: .seconds(3))
                if phase == .briefReveal {
                    await MainActor.run { startSpeaking() }
                }
            }
        } else {
            // No thinking time but prompt will be visible during speech
            startSpeaking()
        }
    }

    /// Start the 15-second thinking countdown
    private func startThinkingCountdown() {
        thinkingTask?.cancel()
        thinkingTask = Task {
            for i in stride(from: 15, through: 1, by: -1) {
                if Task.isCancelled { return }
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.25)) { thinkingCountdown = i }
                }
                try? await Task.sleep(for: .seconds(1))
            }
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.snappy(duration: 0.25)) { thinkingCountdown = 0 }
                startSpeaking()
            }
        }
    }

    /// Skip remaining thinking time and go straight to speaking
    private func skipThinkingAndSpeak() {
        thinkingTask?.cancel()
        thinkingTask = nil
        startSpeaking()
    }

    /// Enter the live speaking phase
    private func startSpeaking() {
        guard !speechVM.isRecording else { return }

        withAnimation(.easeInOut(duration: 0.3)) { phase = .speaking }

        elapsedSeconds = 0
        isStopping = false
        speechVM.prepareSession(mode: .timed)
        speechVM.startRecording()

        speakingTask?.cancel()
        speakingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                await MainActor.run {
                    elapsedSeconds += 1
                    if elapsedSeconds >= TableTopicsTimingState.hardStopSeconds {
                        stopSession()
                    }
                }
            }
        }
    }

    private func stopSession() {
        guard !isStopping else { return }
        isStopping = true
        speakingTask?.cancel()
        speakingTask = nil
        speechVM.stopRecording()

        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                let result = PracticeEvaluator.evaluateTimedPractice(
                    transcript: speechVM.transcribedText,
                    fillerCount: speechVM.fillerWordCount,
                    duration: speechVM.lastSessionDuration,
                    difficulty: practiceSettings.timedDifficulty,
                    recentSessions: speechVM.pastSessions,
                    profile: coachingProfileStore.profile
                )
                evaluation = result
                speechVM.annotateLatestSession(
                    score: result.score,
                    xpEarned: result.xpEarned,
                    headline: result.headline,
                    insights: result.insights,
                    coachSummary: result.feedback
                )
                showSummary = true
            }
        }
    }

    private func restartSession() {
        cleanup()
        resetState()
    }

    private func resetState() {
        speakingTask?.cancel()
        thinkingTask?.cancel()
        speechVM.resetCurrentSession()
        thinkingCountdown = 15
        elapsedSeconds = 0
        evaluation = nil
        isStopping = false
        phase = .setup
    }

    private func cleanup() {
        speakingTask?.cancel()
        thinkingTask?.cancel()
        speakingTask = nil
        thinkingTask = nil
    }

    private func dismiss(times: Int) {
        guard times > 0 else { return }
        withAnimation(.none) { dismiss() }
        if times > 1 {
            DispatchQueue.main.async { dismiss(times: times - 1) }
        }
    }
}
#endif
