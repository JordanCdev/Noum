import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(SwiftUI)

// MARK: - TTS Delegate (reliable speech completion tracking)

private class TTSDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinish?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.onCancel?()
        }
    }
}

// MARK: - Impromptu Timing

enum ImpromptuTimingState: Equatable {
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
        case .neutral: return Color(red: 0.44, green: 0.52, blue: 0.68)
        case .green: return Color(red: 0.20, green: 0.84, blue: 0.46)
        case .yellow: return Color(red: 1.0, green: 0.82, blue: 0.0)
        case .red: return Color(red: 1.0, green: 0.30, blue: 0.24)
        case .overtime: return Color(red: 1.0, green: 0.20, blue: 0.18)
        }
    }

    /// Deep gradient start color for immersive background
    var immersiveGradientStart: Color {
        switch self {
        case .neutral: return Color(red: 0.08, green: 0.08, blue: 0.14)
        case .green: return Color(red: 0.02, green: 0.12, blue: 0.08)
        case .yellow: return Color(red: 0.14, green: 0.11, blue: 0.02)
        case .red: return Color(red: 0.16, green: 0.04, blue: 0.04)
        case .overtime: return Color(red: 0.20, green: 0.02, blue: 0.02)
        }
    }

    /// Deep gradient end color for immersive background
    var immersiveGradientEnd: Color {
        switch self {
        case .neutral: return Color(red: 0.04, green: 0.04, blue: 0.10)
        case .green: return Color(red: 0.01, green: 0.08, blue: 0.05)
        case .yellow: return Color(red: 0.10, green: 0.08, blue: 0.01)
        case .red: return Color(red: 0.12, green: 0.02, blue: 0.02)
        case .overtime: return Color(red: 0.16, green: 0.01, blue: 0.01)
        }
    }

    /// Glow opacity for the outer halo
    var glowOpacity: Double {
        switch self {
        case .neutral: return 0.10
        case .green: return 0.22
        case .yellow: return 0.26
        case .red: return 0.32
        case .overtime: return 0.38
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

    /// Expressive labels for spotlight / immersive mode
    var spotlightLabel: String {
        switch self {
        case .neutral: return "You're on"
        case .green: return "Nice length"
        case .yellow: return "Start wrapping up"
        case .red: return "Over time"
        case .overtime: return "Time's up"
        }
    }

    /// Motivational sub-label
    var spotlightSublabel: String {
        switch self {
        case .neutral: return "Speak with intention"
        case .green: return "Strong pace — keep going or land it"
        case .yellow: return "Find your closing thought"
        case .red: return "Bring it home now"
        case .overtime: return "Finish strong"
        }
    }

    static func state(forElapsedSeconds seconds: Int) -> ImpromptuTimingState {
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

private enum ImpromptuSetupMode: String, CaseIterable, Identifiable {
    case classic
    case coach

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .coach: return "Coach"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "Pure focus. No distractions."
        case .coach: return "Full feedback and transcript."
        }
    }

    var icon: String {
        switch self {
        case .classic: return "sparkles"
        case .coach: return "text.magnifyingglass"
        }
    }

    var badge: String {
        switch self {
        case .classic: return "Free"
        case .coach: return "Pro"
        }
    }

    var badgeColor: Color {
        switch self {
        case .classic: return AppColor.brandBlue
        case .coach: return AppColor.pro
        }
    }
}

// MARK: - Background Layer (extracted for render isolation)

@available(iOS 17.0, macOS 12.0, *)
private struct BackgroundLayerView: View {
    let phase: TimedSessionPhase
    let timingState: ImpromptuTimingState
    let isFullScreenCameraActive: Bool
    let showLiveTranscript: Bool

    var body: some View {
        if phase == .speaking && isFullScreenCameraActive {
            Color.black.ignoresSafeArea()
        } else if phase == .speaking && !showLiveTranscript {
            ZStack {
                LinearGradient(
                    colors: [timingState.immersiveGradientStart, timingState.immersiveGradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.8), value: timingState)

                RadialGradient(
                    colors: [timingState.vividColor.opacity(timingState.glowOpacity * 0.3), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 360
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.4), value: timingState)
            }
        } else if phase == .thinking {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.03, green: 0.03, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.97, blue: 1.0),
                    Color(red: 0.93, green: 0.95, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Spotlight Orb (extracted for render isolation)

@available(iOS 17.0, macOS 12.0, *)
private struct SpotlightOrbView: View {
    let timingState: ImpromptuTimingState
    let elapsedSeconds: Int
    let totalDuration: Int
    @Binding var spotlightPulse: Bool

    private let orbSize: CGFloat = 240

    var body: some View {
        ZStack {
            // Outer glow halo
            Circle()
                .fill(timingState.vividColor)
                .frame(width: orbSize * 1.4, height: orbSize * 1.4)
                .blur(radius: 50)
                .opacity(spotlightPulse ? timingState.glowOpacity : timingState.glowOpacity * 0.4)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: spotlightPulse)

            // Track ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 6)
                .frame(width: orbSize, height: orbSize)

            // Milestone markers
            milestoneMarkers

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(min(elapsedSeconds, totalDuration)) / CGFloat(totalDuration))
                .stroke(
                    AngularGradient(
                        colors: [timingState.vividColor.opacity(0.3), timingState.vividColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * Double(min(elapsedSeconds, totalDuration)) / Double(totalDuration))
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: orbSize, height: orbSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: timingState.vividColor.opacity(timingState == .neutral ? 0 : 0.5), radius: 12)
                .animation(.linear(duration: 0.9), value: elapsedSeconds)

            // Center content
            centerContent
        }
        .onAppear { spotlightPulse = true }
    }

    private var milestoneMarkers: some View {
        let milestones: [(seconds: Int, state: ImpromptuTimingState)] = [
            (60, .green), (90, .yellow), (120, .red)
        ]

        return ForEach(milestones, id: \.seconds) { milestone in
            let angle = Angle.degrees(Double(milestone.seconds) / Double(totalDuration) * 360 - 90)
            let reached = elapsedSeconds >= milestone.seconds

            Circle()
                .fill(reached ? milestone.state.vividColor : Color.white.opacity(0.15))
                .frame(width: reached ? 12 : 6, height: reached ? 12 : 6)
                .shadow(color: reached ? milestone.state.vividColor.opacity(0.7) : .clear, radius: 6)
                .offset(
                    x: (orbSize / 2) * cos(angle.radians),
                    y: (orbSize / 2) * sin(angle.radians)
                )
                .animation(.bouncySpring, value: reached)
        }
    }

    private var centerContent: some View {
        VStack(spacing: 6) {
            Text(formattedTime(elapsedSeconds))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(timingState == .neutral ? "Keep going" : timingState.spotlightLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(timingState == .neutral ? .white.opacity(0.35) : timingState.vividColor)
                .contentTransition(.interpolate)
        }
        .animation(.easeInOut(duration: 0.4), value: timingState)
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Settings Card (extracted for render isolation)

@available(iOS 17.0, macOS 12.0, *)
private struct SettingsCardView: View {
    @Binding var selectedMode: ImpromptuSetupMode
    @Binding var keepPromptVisible: Bool
    @Binding var timerDisplay: TimerDisplayOption
    @Binding var enableThinkingTime: Bool
    @Binding var showLiveTranscript: Bool
    @Binding var showFillerWords: Bool
    @Binding var enableVideoRecording: Bool
    @ObservedObject var videoManager: VideoRecordingManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Preferences")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 16)

            if selectedMode == .classic {
                toggleRow(
                    icon: "eye",
                    iconColor: .indigo,
                    title: "Show prompt while speaking",
                    caption: "Keep the topic visible",
                    isOn: $keepPromptVisible
                )

                thinDivider

                timerPicker
            }

            if selectedMode == .coach {
                toggleRow(
                    icon: "brain.head.profile",
                    iconColor: .blue,
                    title: "Thinking time",
                    caption: "15 seconds to prepare",
                    isOn: $enableThinkingTime
                )

                thinDivider

                toggleRow(
                    icon: "eye",
                    iconColor: .indigo,
                    title: "Show prompt while speaking",
                    caption: "Keep the topic visible",
                    isOn: $keepPromptVisible
                )

                thinDivider

                toggleRow(
                    icon: "waveform.badge.magnifyingglass",
                    iconColor: .red,
                    title: "Filler word tracking",
                    caption: "Counts verbal crutches live",
                    isOn: $showFillerWords
                )

                thinDivider

                timerPicker

                thinDivider

                toggleRow(
                    icon: "text.quote",
                    iconColor: .teal,
                    title: "Live transcript",
                    caption: enableVideoRecording ? "Not available with video" : "See your words in real time",
                    isOn: Binding(
                        get: { showLiveTranscript },
                        set: { newValue in
                            showLiveTranscript = newValue
                            if newValue { enableVideoRecording = false }
                        }
                    ),
                    disabled: enableVideoRecording
                )

                thinDivider

                toggleRow(
                    icon: "video.fill",
                    iconColor: .pink,
                    title: "Record video",
                    caption: showLiveTranscript ? "Not available with transcript" : "Review your delivery after",
                    isOn: Binding(
                        get: { enableVideoRecording },
                        set: { newValue in
                            enableVideoRecording = newValue
                            if newValue {
                                showLiveTranscript = false
                                Task {
                                    let hasPermission = await VideoRecordingManager.requestCameraPermission()
                                    guard hasPermission else {
                                        await MainActor.run { enableVideoRecording = false }
                                        return
                                    }
                                    let ready = await videoManager.prepareSession()
                                    if ready, let session = videoManager.captureSession, !session.isRunning {
                                        DispatchQueue.global(qos: .userInitiated).async {
                                            session.startRunning()
                                        }
                                    }
                                }
                            } else {
                                videoManager.cleanup()
                            }
                        }
                    ),
                    disabled: showLiveTranscript
                )

                thinDivider

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AppColor.pro)
                    Text("Live transcript · Video · AI feedback · Score breakdown")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.pro.opacity(0.05))
            }
        }
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 4)
        .animation(.standardSpring, value: selectedMode)
    }

    private var timerPicker: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Timer display")
                    .font(.subheadline.weight(.medium))
                Text("Choose timing visibility")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Timer", selection: $timerDisplay) {
                ForEach(TimerDisplayOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.md)
    }

    private func toggleRow(icon: String, iconColor: Color, title: String, caption: String, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(disabled ? iconColor.opacity(0.4) : iconColor)
                .frame(width: 32, height: 32)
                .background((disabled ? iconColor.opacity(0.04) : iconColor.opacity(0.1)), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(disabled ? .secondary : .primary)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(disabled ? .tertiary : .secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.blue)
                .disabled(disabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, Spacing.md)
    }

    private var thinDivider: some View {
        Divider()
            .padding(.horizontal, 16)
    }
}

// MARK: - TimedPracticeView

@available(iOS 17.0, macOS 12.0, *)
struct TimedPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    var goHome: (() -> Void)?
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var premium = PremiumManager.shared

    // Session state
    @State private var selectedTheme: PromptTheme = .all
    @State private var question: String = ""
    @State private var phase: TimedSessionPhase = .setup
    @State private var thinkingCountdown: Int = 15
    @State private var elapsedSeconds: Int = 0
    @State private var showSummary = false
    @State private var evaluation: PracticeEvaluation?
    @State private var isStopping = false

    // Tasks
    @State private var thinkingTask: Task<Void, Never>?
    @State private var speakingTask: Task<Void, Never>?

    // Settings (defaults = immersive "Classic" experience)
    @State private var selectedMode: ImpromptuSetupMode = .classic
    @State private var keepPromptVisible: Bool = false
    @State private var timerDisplay: TimerDisplayOption = .none
    @State private var enableThinkingTime: Bool = true
    @State private var showLiveTranscript: Bool = false
    @State private var showFillerWords: Bool = false

    // TTS — persistent synthesizer + delegate, prewarmed voice for instant playback
    private let ttsEngine = AVSpeechSynthesizer()
    private let ttsDelegate = TTSDelegate()
    private let prewarmedVoice = AVSpeechSynthesisVoice(language: "en-US")
    @State private var isSpeakingPrompt = false
    @State private var ttsReady = false

    // Premium gating
    @State private var showPaywall = false

    // Video recording (Coach mode only)
    @StateObject private var videoManager = VideoRecordingManager.shared
    @State private var enableVideoRecording = false
    @State private var showVideoPlayback = false

    // Immersive state
    @State private var spotlightPulse: Bool = false
    @State private var currentTimingState: ImpromptuTimingState = .neutral
    @State private var lastMilestoneState: ImpromptuTimingState = .neutral
    @State private var milestoneScale: CGFloat = 1.0
    @State private var breathePhase: Bool = false
    @State private var recPulse: Bool = false
    @State private var showCelebration: Bool = false

    private let totalDuration = ImpromptuTimingState.hardStopSeconds

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Group {
                    switch phase {
                    case .setup:
                        setupContent
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    case .thinking:
                        thinkingContent
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    case .briefReveal:
                        briefRevealContent
                            .transition(.opacity)
                    case .speaking:
                        speakingContent
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.4), value: phase)

                bottomBar
            }
        }
        .overlay {
            if showCelebration {
                celebrationOverlay
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(phase == .setup ? .visible : .hidden, for: .navigationBar)
        .accessibilityIdentifier("timedPractice.screen")
        .task {
            // Batch initial setup into a single Task so SwiftUI
            // processes the state changes in one transaction.
            // Yield first so the view renders its initial frame immediately.
            await Task.yield()
            if question.isEmpty {
                question = PracticeTopics.random()
            }
            speechVM.prepareForInteractiveUse()
            prewarmTTS()
        }
        .onDisappear { cleanup() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: evaluation?.score,
                progressSegments: progressSegments,
                xpEarned: evaluation?.xpEarned ?? 0,
                showDuration: false,
                practiceTitle: "Impromptu Practice",
                feedbackOverride: evaluation?.feedback,
                headlineOverride: evaluation?.headline,
                scoreBreakdown: evaluation?.segments ?? [],
                insights: evaluation?.insights ?? [],
                recentSessions: speechVM.pastSessions,
                recordingURL: videoManager.recordingURL,
                sessionPrompt: question,
                sessionTheme: selectedTheme,
                feedbackCategories: evaluation?.categories ?? [],
                strongMoments: evaluation?.strongMoments ?? [],
                weakMoments: evaluation?.weakMoments ?? [],
                onSelectPracticeMode: {
                    showSummary = false
                    if let goHome { goHome() } else { dismiss() }
                },
                onHome: {
                    showSummary = false
                    if let goHome { goHome() } else { dismiss() }
                },
                onPracticeAgain: {
                    showSummary = false
                    restartSession()
                }
            )
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        BackgroundLayerView(
            phase: phase,
            timingState: timingState,
            isFullScreenCameraActive: isFullScreenCameraActive,
            showLiveTranscript: showLiveTranscript
        )
    }

    // MARK: - Computed

    private var timingState: ImpromptuTimingState { currentTimingState }

    /// Update timing state only when the actual zone changes, avoiding unnecessary re-renders
    private func refreshTimingState() {
        let newState = ImpromptuTimingState.state(forElapsedSeconds: elapsedSeconds)
        if newState != currentTimingState {
            withAnimation(.easeInOut(duration: 0.6)) {
                currentTimingState = newState
            }
        }
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

    // MARK: - Setup Phase

    private var setupContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Impromptu")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Pick a theme. Think fast. Speak well.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

                // Mode selector
                modeSelector

                // Theme selector
                themeSelector

                // Settings card
                settingsCard

                // Camera preview (when video recording is enabled)
                if enableVideoRecording, let session = videoManager.captureSession {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Camera Preview")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        CameraPreviewView(session: session)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                    .stroke(Color.pink.opacity(0.2), lineWidth: 1)
                            )

                        Text("You'll see yourself full-screen during the session")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 12) {
            ForEach(ImpromptuSetupMode.allCases) { mode in
                modeCard(mode)
            }
        }
    }

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Theme")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PromptTheme.allCases) { theme in
                        themeChip(theme)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func themeChip(_ theme: PromptTheme) -> some View {
        let isSelected = selectedTheme == theme
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappySpring) {
                selectedTheme = theme
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: theme.icon)
                    .font(.caption.weight(.semibold))
                Text(theme.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.accentColor
                    : Color(.systemGray6),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func modeCard(_ mode: ImpromptuSetupMode) -> some View {
        let isSelected = selectedMode == mode
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.standardSpring) {
                selectedMode = mode
                applyModeDefaults(mode)
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : mode.badgeColor)
                        .frame(width: 36, height: 36)
                        .background(
                            isSelected ? mode.badgeColor : mode.badgeColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        )

                    Spacer()

                    HStack(spacing: 4) {
                        if mode == .coach && !premium.canUseCoachMode {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white.opacity(0.9) : mode.badgeColor)
                        }
                        Text(mode.badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : mode.badgeColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isSelected ? .white.opacity(0.2) : mode.badgeColor.opacity(0.1),
                        in: Capsule()
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    LinearGradient(
                        colors: [mode.badgeColor, mode.badgeColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [Color.white, Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: isSelected ? mode.badgeColor.opacity(0.25) : Color.black.opacity(0.04), radius: isSelected ? 12 : 6, y: isSelected ? 6 : 3)
        }
        .buttonStyle(.plain)
    }

    private func applyModeDefaults(_ mode: ImpromptuSetupMode) {
        switch mode {
        case .classic:
            showLiveTranscript = false
            showFillerWords = false
            keepPromptVisible = false
            timerDisplay = .none
            enableThinkingTime = true
        case .coach:
            showLiveTranscript = true
            showFillerWords = true
            keepPromptVisible = true
            timerDisplay = .elapsed
            enableThinkingTime = true
            enableVideoRecording = false  // Mutually exclusive with transcript
        }
    }

    private var settingsCard: some View {
        SettingsCardView(
            selectedMode: $selectedMode,
            keepPromptVisible: $keepPromptVisible,
            timerDisplay: $timerDisplay,
            enableThinkingTime: $enableThinkingTime,
            showLiveTranscript: $showLiveTranscript,
            showFillerWords: $showFillerWords,
            enableVideoRecording: $enableVideoRecording,
            videoManager: videoManager
        )
    }

    private var thinDivider: some View {
        Divider()
            .padding(.horizontal, 16)
    }

    // MARK: - Thinking Phase

    private var thinkingContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // Prompt card (tappable for TTS)
            Button {
                speakPromptAloud()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("YOUR TOPIC")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1.2)

                        Spacer()

                        // Speaker affordance
                        HStack(spacing: 4) {
                            Image(systemName: isSpeakingPrompt ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .symbolEffect(.variableColor.iterative, isActive: isSpeakingPrompt)
                            Text("Tap to hear")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }

                    Text(question)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer(minLength: 40)

            // Countdown with breathing indicator
            ZStack {
                // Breathing circle — calming visual anchor
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: breathePhase ? 180 : 140, height: breathePhase ? 180 : 140)
                    .blur(radius: 30)
                    .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: breathePhase)

                VStack(spacing: 10) {
                    Text("\(thinkingCountdown)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(thinkingCountdown > 10 ? "Breathe and think" : thinkingCountdown > 5 ? "Plan your opening" : "Almost ready...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .contentTransition(.interpolate)
                        .animation(.easeInOut(duration: 0.3), value: thinkingCountdown)
                }
            }

            Spacer(minLength: 40)
        }
        .padding(.horizontal, 16)
        .onAppear { breathePhase = true }
    }

    // MARK: - Brief Reveal

    private var briefRevealContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("YOUR TOPIC")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Text(question)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Starting soon...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 20, y: 8)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Speaking Phase

    /// Whether Coach mode's full-screen camera is active
    private var isFullScreenCameraActive: Bool {
        enableVideoRecording && videoManager.isRecording && videoManager.captureSession != nil && selectedMode == .coach
    }

    private var speakingContent: some View {
        ZStack {
            // Full-screen camera background (Coach mode with video)
            if isFullScreenCameraActive, let session = videoManager.captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
                    .overlay {
                        // Dark gradient vignette so HUD text is readable over any background
                        LinearGradient(
                            colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    }
            }

            VStack(spacing: 0) {
                if isFullScreenCameraActive {
                    coachHUDLayout
                } else if showLiveTranscript {
                    speakingTranscriptLayout
                } else {
                    speakingImmersiveLayout
                }
            }
        }
    }

    // MARK: - Coach HUD Layout (full-screen camera with overlay)

    private var coachHUDLayout: some View {
        VStack(spacing: 0) {
            // Top bar: REC indicator + timing state
            HStack {
                // REC badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(recPulse ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recPulse)
                        .onAppear { recPulse = true }
                    Text("REC")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.red.opacity(0.25), in: Capsule())

                Spacer()

                // Timing state badge
                Text(timingState.spotlightLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(timingState == .neutral ? .white.opacity(0.7) : timingState.vividColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.3), value: timingState)

                if speechVM.connectionError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Compact timing bar
            timingIndicator
                .padding(.top, 8)

            // Timer
            Text(formattedTime(elapsedSeconds))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                .contentTransition(.numericText())
                .padding(.top, 12)

            Spacer()

            // Bottom HUD: prompt + filler count + transcript snippet
            VStack(spacing: 10) {
                // Optional prompt pill
                if keepPromptVisible {
                    HStack(spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text(question)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }

                // Live transcript snippet (last few words)
                if showLiveTranscript {
                    Text(speechVM.highlightedText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }

                // Filler words chip
                if showFillerWords && speechVM.fillerWordCount > 0 {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: 6, height: 6)
                        Text("Fillers")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(speechVM.fillerWordCount)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Coach / Transcript Layout

    private var speakingTranscriptLayout: some View {
        VStack(spacing: 0) {
            // Premium header with status
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(timingState == .neutral ? Color.green : timingState.vividColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(timingState == .neutral ? Color.green : timingState.vividColor)
                                    .frame(width: 8, height: 8)
                                    .opacity(0.5)
                                    .scaleEffect(recPulse ? 1.8 : 1.0)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: recPulse)
                            )
                        Text("LIVE")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(timingState == .neutral ? Color.green : timingState.vividColor)
                    }
                    Text(timingState.spotlightLabel)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(timingState == .neutral ? .primary : timingState.vividColor)
                        .contentTransition(.interpolate)
                }

                Spacer()

                // Elapsed time pill
                if timerDisplay.showsElapsed || timerDisplay.showsRemaining {
                    let timeStr = timerDisplay.showsElapsed ? formattedTime(elapsedSeconds) : formattedTime(remainingSeconds)
                    Text(timeStr)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }

                if speechVM.connectionError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)

            // Timing progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [timingState.vividColor.opacity(0.7), timingState.vividColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(elapsedSeconds, totalDuration)) / CGFloat(max(totalDuration, 1)))
                        .animation(.easeInOut(duration: 0.5), value: elapsedSeconds)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)

            // Optional prompt — styled as subtle card
            if keepPromptVisible {
                HStack(spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(question)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6).opacity(0.7), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // Transcript area — premium card
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    Text(speechVM.highlightedText)
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .lineSpacing(8)
                        .tracking(0.2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 20)
                        .id("transcriptEnd")
                }
                .onChange(of: speechVM.highlightedText) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("transcriptEnd", anchor: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color(.systemGray5).opacity(0.6), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Filler words — inline badge
            if showFillerWords {
                HStack(spacing: 16) {
                    Label {
                        Text("Filler words")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    Spacer()
                    Text("\(speechVM.fillerWordCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(speechVM.fillerWordCount > 5 ? .red : speechVM.fillerWordCount > 2 ? .orange : .green)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
        .onAppear { recPulse = true }
    }

    // MARK: - Classic / Immersive Layout

    private var speakingImmersiveLayout: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Central orb
                spotlightOrb
                    .padding(.horizontal, 32)

                Spacer(minLength: 16)

                // Stage label
                VStack(spacing: 6) {
                    Text(timingState.spotlightLabel)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(timingState == .neutral ? .white.opacity(0.9) : timingState.vividColor)
                        .contentTransition(.interpolate)
                        .scaleEffect(milestoneScale)
                    Text(timingState.spotlightSublabel)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                        .contentTransition(.interpolate)
                }
                .animation(.easeInOut(duration: 0.5), value: timingState)

                Spacer(minLength: 16)

                // Prompt pill (if visible)
                if keepPromptVisible {
                    spotlightPromptPill
                        .padding(.bottom, 8)
                }

                // Filler chip (if visible)
                if showFillerWords && speechVM.fillerWordCount > 0 {
                    spotlightFillerChip
                        .padding(.bottom, 8)
                }

                if speechVM.connectionError != nil {
                    Text("Transcription issue")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.6))
                        .padding(.bottom, 4)
                }
            }
        }
        .onChange(of: timingState) { _, newState in
            if newState != lastMilestoneState {
                lastMilestoneState = newState
                if newState != .neutral {
                    triggerMilestoneHaptic(for: newState)
                    triggerMilestoneAnimation()
                }
            }
        }
    }

    // MARK: Spotlight Orb

    private var spotlightOrb: some View {
        SpotlightOrbView(
            timingState: timingState,
            elapsedSeconds: elapsedSeconds,
            totalDuration: totalDuration,
            spotlightPulse: $spotlightPulse
        )
    }

    // MARK: Spotlight Prompt Pill

    private var spotlightPromptPill: some View {
        HStack(spacing: 8) {
            Text(question)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: Capsule())
        .padding(.horizontal, 24)
    }

    // MARK: Spotlight Filler Chip

    private var spotlightFillerChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.red.opacity(0.5))
                .frame(width: 6, height: 6)
            Text("Fillers")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
            Text("\(speechVM.fillerWordCount)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    // MARK: - Milestone Animation

    private func triggerMilestoneAnimation() {
        withAnimation(.bouncySpring) {
            milestoneScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.standardSpring) {
                milestoneScale = 1.0
            }
        }
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
        ZStack {
            // Burst of emoji particles
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * (360.0 / 12.0)
                let radians = angle * .pi / 180
                Text(["🎉", "✨", "🔥", "⭐️", "💪", "🏆"][i % 6])
                    .font(.system(size: CGFloat.random(in: 20...32)))
                    .offset(
                        x: showCelebration ? cos(radians) * CGFloat.random(in: 100...160) : 0,
                        y: showCelebration ? sin(radians) * CGFloat.random(in: 100...160) : 0
                    )
                    .opacity(showCelebration ? 0 : 1)
                    .scaleEffect(showCelebration ? 0.3 : 1.0)
                    .animation(
                        .easeOut(duration: 1.4)
                            .delay(Double(i) * 0.04),
                        value: showCelebration
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Haptics

    private func triggerMilestoneHaptic(for state: ImpromptuTimingState) {
        let generator = UIImpactFeedbackGenerator(style: state == .red || state == .overtime ? .heavy : .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - TTS

    private func configureTTSDelegate() {
        ttsEngine.delegate = ttsDelegate
        ttsDelegate.onFinish = { [self] in
            isSpeakingPrompt = false
        }
        ttsDelegate.onCancel = { [self] in
            isSpeakingPrompt = false
        }
    }

    /// Activate audio session for TTS — must be called before speaking.
    /// Uses `.playback` so speech plays even in silent mode, and `.mixWithOthers`
    /// so it doesn't fight the speech recognizer's session during handoff.
    private func activateTTSAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal — TTS may still work on some devices without explicit activation
        }
    }

    /// Deactivate TTS audio session so the speech recognizer can reclaim it.
    private func deactivateTTSAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal
        }
    }

    private func speakPromptAloud() {
        // Ensure delegate is wired up
        if ttsEngine.delegate == nil {
            configureTTSDelegate()
        }

        // Toggle off if already speaking
        if ttsEngine.isSpeaking {
            ttsEngine.stopSpeaking(at: .immediate)
            isSpeakingPrompt = false
            return
        }

        // Activate audio session before speaking — this is the root fix for
        // delayed / silent TTS on first invocation
        activateTTSAudioSession()

        let utterance = AVSpeechUtterance(string: question)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.04
        utterance.prefersAssistiveTechnologySettings = false
        // Use prewarmed voice to avoid first-call latency
        utterance.voice = prewarmedVoice

        isSpeakingPrompt = true
        ttsEngine.speak(utterance)
    }

    /// Prewarm TTS engine with a silent utterance so the first real speak is instant.
    /// Also pre-configures the audio session so there's zero delay on first tap.
    /// Deferred to a background-priority task so it doesn't block the initial render.
    private func prewarmTTS() {
        guard !ttsReady else { return }
        configureTTSDelegate()

        // Defer the entire prewarm sequence so it doesn't block the first frame.
        // Audio session setup runs off-main, then the silent utterance fires on main
        // after a short yield so the view is already interactive.
        Task.detached(priority: .utility) {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try? session.setActive(true)

            // Yield back to main to issue the silent utterance (AVSpeechSynthesizer
            // must be called from the thread that created it — typically main)
            await MainActor.run {
                let warmup = AVSpeechUtterance(string: " ")
                warmup.volume = 0
                warmup.voice = prewarmedVoice
                ttsDelegate.onFinish = { [self] in
                    ttsReady = true
                    deactivateTTSAudioSession()
                    ttsDelegate.onFinish = { [self] in
                        isSpeakingPrompt = false
                        deactivateTTSAudioSession()
                    }
                }
                ttsEngine.speak(warmup)
            }
        }
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

    private func timingSegment(active: Bool, state: ImpromptuTimingState, label: String) -> some View {
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
        .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
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

    // MARK: - Bottom Bar (always visible, safe-area pinned)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            switch phase {
            case .setup:
                setupBottomBar
            case .thinking:
                thinkingBottomBar
            case .briefReveal:
                EmptyView()
            case .speaking:
                speakingBottomBar
            }
        }
    }

    private var setupBottomBar: some View {
        VStack(spacing: 8) {
            Button(action: { beginSession() }) {
                HStack(spacing: 10) {
                    Image(systemName: selectedMode == .classic ? "sparkles" : "text.magnifyingglass")
                        .font(.headline)
                    Text("Begin Session")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(
                    colors: [selectedMode.badgeColor, selectedMode.badgeColor.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .foregroundStyle(.white)
            .shadow(color: selectedMode.badgeColor.opacity(0.3), radius: 12, y: 4)
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.regularMaterial)
    }

    private var thinkingBottomBar: some View {
        VStack(spacing: 8) {
            Button(action: { skipThinkingAndSpeak() }) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.headline)
                    Text("Start Now")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Color.white, in: Capsule())
            .foregroundStyle(Color(red: 0.06, green: 0.06, blue: 0.12))
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.clear)
    }

    private var speakingBottomBar: some View {
        let isImmersive = phase == .speaking && !showLiveTranscript && !isFullScreenCameraActive
        let isCamera = isFullScreenCameraActive

        return VStack(spacing: 8) {
            Button(action: { stopSession() }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.subheadline)
                    Text("End Session")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(
                isImmersive
                    ? AnyShapeStyle(Color.white.opacity(0.15))
                    : isCamera
                        ? AnyShapeStyle(Color.red.opacity(0.85))
                        : AnyShapeStyle(Color.red),
                in: Capsule()
            )
            .foregroundStyle(.white)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isImmersive || isCamera ? 0.2 : 0), lineWidth: 1)
            )
            .buttonStyle(.pressable)
            .disabled(isStopping)
            .opacity(isStopping ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            isCamera
                ? AnyShapeStyle(.ultraThinMaterial)
                : showLiveTranscript
                    ? AnyShapeStyle(.regularMaterial)
                    : AnyShapeStyle(Color.clear)
        )
    }

    // MARK: - Actions

    private func beginSession() {
        guard phase == .setup else { return }

        // Gate Coach mode behind premium
        if selectedMode == .coach && !premium.canUseCoachMode {
            showPaywall = true
            return
        }

        question = PracticeTopics.random(theme: selectedTheme)

        // Ensure TTS is ready (may already be prewarmed from onAppear)
        if ttsEngine.delegate == nil { configureTTSDelegate() }

        // Haptic feedback for session start
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Classic always gets 15-second thinking time; Coach respects the toggle
        let useThinkingTime = selectedMode == .classic ? true : enableThinkingTime

        if useThinkingTime {
            thinkingCountdown = 15
            withAnimation(.easeInOut(duration: 0.3)) { phase = .thinking }
            startThinkingCountdown()
        } else if !keepPromptVisible {
            withAnimation(.easeInOut(duration: 0.3)) { phase = .briefReveal }
            Task {
                try? await Task.sleep(for: .seconds(3))
                if phase == .briefReveal {
                    await MainActor.run { startSpeaking() }
                }
            }
        } else {
            startSpeaking()
        }
    }

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

    private func skipThinkingAndSpeak() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        ttsEngine.stopSpeaking(at: .immediate)
        isSpeakingPrompt = false
        thinkingTask?.cancel()
        thinkingTask = nil
        startSpeaking()
    }

    private func startSpeaking() {
        guard !speechVM.isRecording else { return }

        withAnimation(.easeInOut(duration: 0.3)) { phase = .speaking }

        elapsedSeconds = 0
        isStopping = false
        lastMilestoneState = .neutral
        milestoneScale = 1.0
        speechVM.prepareSession(mode: .timed)
        speechVM.startRecording()

        // Start video recording if enabled (Coach mode, premium only)
        // Camera session was already prepared when the user toggled the switch
        if enableVideoRecording && selectedMode == .coach && premium.canRecordVideo {
            Task {
                if videoManager.captureSession == nil {
                    // Fallback: prepare if not already done
                    let hasPermission = await VideoRecordingManager.requestCameraPermission()
                    guard hasPermission else { return }
                    let ready = await videoManager.prepareSession()
                    guard ready else { return }
                }
                videoManager.startRecording()
            }
        }

        speakingTask?.cancel()
        speakingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                await MainActor.run {
                    elapsedSeconds += 1
                    refreshTimingState()
                    if elapsedSeconds >= ImpromptuTimingState.hardStopSeconds {
                        stopSession()
                    }
                }
            }
        }
    }

    private func stopSession() {
        guard !isStopping else { return }
        isStopping = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        speakingTask?.cancel()
        speakingTask = nil
        speechVM.stopRecording()
        if videoManager.isRecording { videoManager.stopRecording() }

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
                    coachSummary: result.feedback,
                    prompt: question,
                    theme: selectedTheme
                )

                // Celebration haptic for good scores
                if result.score >= 70 {
                    let gen = UINotificationFeedbackGenerator()
                    gen.prepare()
                    gen.notificationOccurred(.success)
                    withAnimation(.bouncySpring) {
                        showCelebration = true
                    }
                    // Auto-dismiss celebration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeOut(duration: 0.5)) { showCelebration = false }
                    }
                }

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
        currentTimingState = .neutral
        evaluation = nil
        isStopping = false
        spotlightPulse = false
        lastMilestoneState = .neutral
        milestoneScale = 1.0
        recPulse = false
        showCelebration = false
        phase = .setup
    }

    private func cleanup() {
        speakingTask?.cancel()
        thinkingTask?.cancel()
        speakingTask = nil
        thinkingTask = nil
        ttsEngine.stopSpeaking(at: .immediate)
        if videoManager.isRecording { videoManager.stopRecording() }
    }


}
#endif
