import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
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
    /// Smoothed mic level from `SpeechRecognizerViewModel.audioLevel` —
    /// the orb renders the microphone's live read of the user's voice,
    /// not a generic decorative pulse.
    let audioLevel: Double
    @Binding var spotlightPulse: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let orbSize: CGFloat = 240

    /// Quantized to 5% steps so the glow tracks the voice without
    /// re-animating on every audio buffer callback.
    private var voiceLevel: Double {
        (min(max(audioLevel, 0), 1) * 20).rounded() / 20
    }

    var body: some View {
        ZStack {
            // Outer glow halo — ambient pulse. Reduce-motion: holds a
            // calm mid-bright glow instead of looping.
            Circle()
                .fill(timingState.vividColor)
                .frame(width: orbSize * 1.4, height: orbSize * 1.4)
                .blur(radius: 50)
                .opacity(
                    reduceMotion
                        ? timingState.glowOpacity * 0.7
                        : (spotlightPulse ? timingState.glowOpacity : timingState.glowOpacity * 0.4)
                )
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: spotlightPulse
                )

            // Voice-reactive inner glow — the room hears the user. Scale +
            // brightness track the smoothed mic level while they speak;
            // silence settles it back to a faint resting glow. Honest by
            // construction: it renders real input, claims nothing.
            // Reduce-motion: scale stays fixed, opacity alone carries it.
            Circle()
                .fill(timingState.vividColor)
                .frame(width: orbSize * 0.62, height: orbSize * 0.62)
                .blur(radius: 28)
                .opacity(0.12 + voiceLevel * 0.38)
                .scaleEffect(reduceMotion ? 1.0 : 0.92 + CGFloat(voiceLevel) * 0.30)
                .animation(.easeOut(duration: 0.18), value: voiceLevel)
                .allowsHitTesting(false)

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
    @AppStorage("timedPractice.showSettings") private var showSettings: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $showSettings) {
                Divider()
                    .padding(.horizontal, 16)

                // Shared settings — available in all modes
                if selectedMode == .coach {
                    toggleRow(
                        icon: "brain.head.profile",
                        iconColor: .blue,
                        title: "Thinking time",
                        caption: "15 seconds to prepare",
                        isOn: $enableThinkingTime
                    )

                    thinDivider
                }

                toggleRow(
                    icon: "eye",
                    iconColor: .indigo,
                    title: "Show prompt while speaking",
                    caption: "Keep the topic visible",
                    isOn: $keepPromptVisible
                )

                thinDivider

                if selectedMode == .coach {
                    toggleRow(
                        icon: "waveform.badge.magnifyingglass",
                        iconColor: .red,
                        title: "Filler word tracking",
                        caption: "Counts verbal crutches live",
                        isOn: $showFillerWords
                    )

                    thinDivider
                }

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
                    caption: showLiveTranscript ? "Not available with transcript" : "Full-screen camera while speaking",
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
                                    _ = await videoManager.prepareSession()
                                }
                            } else {
                                videoManager.cleanup()
                            }
                        }
                    ),
                    disabled: showLiveTranscript
                )

                // Removed classic-only coach upsell since recording is now available in all modes
            } label: {
                HStack {
                    Text("Preferences")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .tint(.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, showSettings ? 0 : 18)
        }
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 4)
        .animation(.standardSpring, value: selectedMode)
        .animation(.standardSpring, value: showSettings)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var navigationPath: NavigationPath
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var premium = PremiumManager.shared
    // M21: Session Intent prompt — sheet-driven, one-shot per
    // entry-to-setup. `forwardPlanStore` + `sessionIntentStore` are
    // observed so the chip options refresh when the user regenerates
    // their plan without leaving Timed.
    @StateObject private var forwardPlanStore = ForwardPlanStore.shared
    @StateObject private var sessionIntentStore = SessionIntentStore.shared
    @State private var showIntentPrompt: Bool = false
    @State private var intentPromptShownThisVisit: Bool = false

    // Session state
    @AppStorage("timedPractice.selectedTheme") private var selectedThemeRaw: String = PromptTheme.all.rawValue
    @State private var question: String = ""
    @State private var wordOfTheDayTarget: String?
    @State private var phase: TimedSessionPhase = .setup
    @State private var thinkingCountdown: Int = 15
    @State private var elapsedSeconds: Int = 0
    @State private var evaluation: PracticeEvaluation?
    @State private var isStopping = false
    @State private var showExitConfirmation = false
    @State private var activeDrill: DrillRecommendation?

    // Tasks
    @State private var thinkingTask: Task<Void, Never>?
    @State private var speakingTask: Task<Void, Never>?

    // Settings (persisted via @AppStorage)
    @AppStorage("timedPractice.selectedMode") private var selectedModeRaw: String = ImpromptuSetupMode.classic.rawValue
    @AppStorage("timedPractice.keepPromptVisible") private var keepPromptVisible: Bool = false
    @AppStorage("timedPractice.timerDisplay") private var timerDisplayRaw: String = TimerDisplayOption.none.rawValue
    @AppStorage("timedPractice.enableThinkingTime") private var enableThinkingTime: Bool = true
    @AppStorage("timedPractice.showLiveTranscript") private var showLiveTranscript: Bool = false
    @AppStorage("timedPractice.showFillerWords") private var showFillerWords: Bool = false
    @AppStorage("timedPractice.classicInitialized") private var classicInitialized: Bool = false
    @AppStorage("timedPractice.coachInitialized") private var coachInitialized: Bool = false

    private var selectedMode: ImpromptuSetupMode {
        get { ImpromptuSetupMode(rawValue: selectedModeRaw) ?? .classic }
        nonmutating set { selectedModeRaw = newValue.rawValue }
    }

    private var timerDisplay: TimerDisplayOption {
        get { TimerDisplayOption(rawValue: timerDisplayRaw) ?? .none }
        nonmutating set { timerDisplayRaw = newValue.rawValue }
    }

    private var selectedTheme: PromptTheme {
        get { PromptTheme(rawValue: selectedThemeRaw) ?? .all }
        nonmutating set { selectedThemeRaw = newValue.rawValue }
    }

#if DEBUG
    private var usesInjectedFirstValueLoop: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_FIRST_VALUE_LOOP")
    }
#endif

    // TTS — persistent synthesizer + delegate, premium voice for warm, coach-like delivery
    private let ttsEngine = AVSpeechSynthesizer()
    private let ttsDelegate = TTSDelegate()
    /// Select the best available English voice — prefer premium/enhanced quality voices
    private let prewarmedVoice: AVSpeechSynthesisVoice? = {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let enVoices = allVoices.filter { $0.language.hasPrefix("en") }

        // Prefer premium quality voices (user-downloaded enhanced voices)
        if let premium = enVoices.first(where: { $0.quality == .premium }) {
            return premium
        }
        // Fall back to enhanced quality
        if let enhanced = enVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        // Fall back to any en-US voice
        return AVSpeechSynthesisVoice(language: "en-US")
    }()
    @State private var isSpeakingPrompt = false
    @State private var ttsReady = false

    // Premium gating
    @State private var showPaywall = false

    // Video recording (Coach mode only)
    @StateObject private var videoManager = VideoRecordingManager.shared
    @AppStorage("timedPractice.enableVideoRecording") private var enableVideoRecording: Bool = false
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

    private var thinkingSubtitle: String {
        if practiceSettings.pressureModeEnabled {
            return thinkingCountdown > 5 ? "Pressure mode — think fast" : thinkingCountdown > 2 ? "Commit to your opening" : "Go."
        }
        return thinkingCountdown > 10 ? "Breathe and think" : thinkingCountdown > 5 ? "Plan your opening" : "Almost ready..."
    }

    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
    }

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
        .navigationBarBackButtonHidden(phase == .speaking || phase == .thinking)
        .toolbar {
            if phase == .speaking || phase == .thinking {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showExitConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Back")
                        }
                    }
                }
            }
        }
        .toolbar(phase == .setup ? .visible : .hidden, for: .navigationBar)
        .alert("End session?", isPresented: $showExitConfirmation) {
            Button("Keep Practicing", role: .cancel) { }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your current session will be lost.")
        }
        .sheet(isPresented: $showIntentPrompt) {
            // M21: declared focus prompt. Sheet is shown at most once per
            // visit to the setup phase. Dismissing without selecting drops
            // cleanly — the rep finalizes with `intentFocus: nil`.
            SessionIntentPromptView(
                options: SessionIntentEngine.options(
                    forwardPlan: forwardPlanStore.activePlan,
                    trendFocus: TrendAnalyzer.primaryFocus(
                        trends: TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots),
                        currentSessionSnapshot: nil,
                        recentDrills: DrillHistoryStore.shared.entries,
                        styleGoal: coachingProfileStore.profile?.speakingStyleGoal
                    ),
                    profile: coachingProfileStore.profile
                ),
                onSelect: { intent in
                    sessionIntentStore.setPending(intent)
                },
                onSkip: {
                    sessionIntentStore.clearPending()
                }
            )
            .presentationDetents([.medium])
        }
        .task {
            // Batch initial setup into a single Task so SwiftUI
            // processes the state changes in one transaction.
            // Yield first so the view renders its initial frame immediately.
            await Task.yield()
            let seededPrompt = consumeSeededPrompt()
            wordOfTheDayTarget = consumeSeededWord()
            if question.isEmpty {
                // Word-of-the-day path — if home tile seeded a one-shot
                // neutral prompt, use it directly. Today's word is carried
                // separately as a cue so the topic never does the user's
                // vocabulary work for them.
                if let seeded = seededPrompt {
                    question = seeded
                } else {
                    question = await PracticeTopics.next(
                        profile: coachingProfileStore.profile,
                        baseline: baselineStore.baseline,
                        theme: selectedTheme
                    )
                }
            }
            speechVM.prepareForInteractiveUse()
            prewarmTTS()

            // If video recording was previously enabled, prepare the camera session
            // prepareSession() starts the session internally before publishing captureSession
            if enableVideoRecording && videoManager.captureSession == nil {
                let hasPermission = await VideoRecordingManager.requestCameraPermission()
                if hasPermission {
                    _ = await videoManager.prepareSession()
                } else {
                    enableVideoRecording = false
                }
            }

            // Quick Start handshake — if the picker armed Timed for a
            // one-tap launch, skip the setup card and go straight into
            // the existing begin flow. `beginSession` re-reads the
            // persisted Classic/Coach + theme config, so the user's
            // last settings still apply; "Start now" only saves taps,
            // not their preferences.
            if phase == .setup, PracticeModeQuickStart.consume(for: .timed) {
                beginSession()
            } else if phase == .setup,
                      SessionIntentPromptPolicy.shouldPresent(
                        completedSessionCount: sessionStore.sessions.count,
                        hasPendingIntent: sessionIntentStore.pendingIntent != nil,
                        hasPromptedThisVisit: intentPromptShownThisVisit
                      ) {
                // M21/MRevamp: surface the focus prompt only after Noum
                // has enough completed reps to make a pre-rep focus feel
                // earned. Quick Start stays one tap, and returning from a
                // declined prompt stays quiet for this visit.
                intentPromptShownThisVisit = true
                showIntentPrompt = true
            }
        }
        .onDisappear {
            cleanup()
            // M21: drop any pending intent that wasn't consumed by a
            // finalize — keeps the next mode entry clean.
            sessionIntentStore.clearPending()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // Summary navigation is handled by path-based .navigationDestination(for:) in ContentView
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

    private func consumeSeededPrompt() -> String? {
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: "timedPractice.suggestedPrompt") }
        return normalizedSeed(defaults.string(forKey: "timedPractice.suggestedPrompt"))
    }

    private func consumeSeededWord() -> String? {
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: "timedPractice.suggestedWord") }
        return normalizedSeed(defaults.string(forKey: "timedPractice.suggestedWord"))
    }

    private func normalizedSeed(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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
                // Header — orb anchors the screen as a coach presence
                // before the user even sees the timer; once recording
                // starts the bound audioLevel reads as live.
                HStack(alignment: .center, spacing: Spacing.md) {
                    NoumCharacter(
                        mood: speechVM.isRecording ? .listening : .calm,
                        tint: AppColor.brandBlue,
                        size: 44,
                        audioLevel: speechVM.audioLevel,
                        stage: characterStage
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Impromptu")
                            .font(Typography.figtree(size: 34, weight: .bold, relativeTo: .largeTitle))
                            .foregroundStyle(.primary)
                        Text("Pick a theme. Think fast. Speak well.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

                if let wordOfTheDayTarget {
                    wordOfTheDaySetupCue(wordOfTheDayTarget)
                }

                // Mode selector
                modeSelector

                // Theme selector
                themeSelector

                // Settings card
                settingsCard

                // M14: live camera preview during setup so the user can
                // see themselves and adjust framing BEFORE the rep starts.
                // Real-device feedback: the preview was only rendering during
                // the speaking phase, so users had no visibility while
                // they were prepping. Tap the toggle in settings → preview
                // appears here.
                if enableVideoRecording, let session = videoManager.captureSession {
                    cameraSetupPreview(session: session)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("timedPractice.screen")
    }

    @available(iOS 17.0, *)
    private func cameraSetupPreview(session: AVCaptureSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "video.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.pink)
                Text("Camera preview")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text("Visible only to you")
                    .font(Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            CameraPreviewView(session: session)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
        }
    }

    private func wordOfTheDaySetupCue(_ word: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "textformat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 34, height: 34)
                .background(AppColor.brandBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY'S WORD")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Text(word)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("Use it if it earns its place.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's word: \(word). Use it if it earns its place.")
    }

    private func wordOfTheDayDarkCue(_ word: String) -> some View {
        HStack(spacing: 8) {
            Text("TODAY'S WORD")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(0.8)
            Text(word)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.84))
            Text("Use it if it fits.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's word: \(word). Use it if it fits.")
    }

    private func wordOfTheDayLightCue(_ word: String) -> some View {
        HStack(spacing: 8) {
            Text("TODAY'S WORD")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Text(word)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Use it if it fits.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColor.brandBlue.opacity(0.08), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's word: \(word). Use it if it fits.")
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
                            Text("PRO")
                                .font(Typography.figtree(size: 9, weight: .heavy, relativeTo: .caption2))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange, in: Capsule())
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
            guard !classicInitialized else { return }
            classicInitialized = true
            showLiveTranscript = false
            showFillerWords = false
            keepPromptVisible = false
            timerDisplay = .none
            enableThinkingTime = true
        case .coach:
            guard !coachInitialized else { return }
            coachInitialized = true
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
            selectedMode: Binding(get: { selectedMode }, set: { selectedMode = $0 }),
            keepPromptVisible: $keepPromptVisible,
            timerDisplay: Binding(get: { timerDisplay }, set: { timerDisplay = $0 }),
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

                    if let wordOfTheDayTarget {
                        wordOfTheDayDarkCue(wordOfTheDayTarget)
                    }
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
                // Breathing circle — calming in normal mode, tighter pulse in
                // pressure mode. Reduce-motion: a still mid-size glow.
                Circle()
                    .fill(practiceSettings.pressureModeEnabled ? Color.orange.opacity(0.06) : Color.white.opacity(0.04))
                    .frame(
                        width: reduceMotion ? 160 : (breathePhase ? 180 : 140),
                        height: reduceMotion ? 160 : (breathePhase ? 180 : 140)
                    )
                    .blur(radius: 30)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: practiceSettings.pressureModeEnabled ? 2.0 : 3.5).repeatForever(autoreverses: true),
                        value: breathePhase
                    )

                VStack(spacing: 10) {
                    Text("\(thinkingCountdown)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(practiceSettings.pressureModeEnabled ? .orange : .white)
                        .contentTransition(.numericText())

                    Text(thinkingSubtitle)
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
                if let wordOfTheDayTarget {
                    wordOfTheDayLightCue(wordOfTheDayTarget)
                }
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

    /// Whether full-screen camera background is active.
    /// True whenever recording is enabled and the camera session is prepared — any mode.
    private var isFullScreenCameraActive: Bool {
        enableVideoRecording && videoManager.captureSession != nil
    }

    private var speakingContent: some View {
        ZStack {
            // Full-screen camera background (any mode with recording enabled)
            if isFullScreenCameraActive, let session = videoManager.captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
                    .overlay {
                        // Top-to-bottom vignette for readability
                        LinearGradient(
                            colors: [.black.opacity(0.5), .clear, .clear, .black.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    }
            }

            VStack(spacing: 0) {
                // Pressure mode indicator (shown when pressure toggle is on)
                if practiceSettings.pressureModeEnabled && activeDrill == nil {
                    pressureBanner
                }

                // Drill constraint banner (shown during Next Rep sessions)
                if let drill = activeDrill {
                    drillBanner(drill)
                }

                // Goal-aware intent reminder — shows for ~4s at session start
                // so the user sees what voice they're working toward every rep.
                // Suppressed when an active drill already owns the intent surface.
                if activeDrill == nil, let voice = coachingProfileStore.profile?.speakingStyleGoal {
                    VoiceAnchorBanner(styleGoal: voice, isRecording: speechVM.isRecording)
                }

                if isFullScreenCameraActive {
                    cameraOverlayLayout
                } else if showLiveTranscript {
                    speakingTranscriptLayout
                } else {
                    speakingImmersiveLayout
                }
            }
        }
        .overlay(alignment: .top) {
            // Real-time positive feedback — pulses when the engine catches
            // a rhetorical move. Self-contained: lifecycle is bound to the
            // speech VM's recording flag, so it resets between sessions.
            // styleGoal makes the chip's subtext goal-aware when the device
            // aligns with the user's chosen voice (e.g. "toward your warm voice").
            LiveEloquenceHUD(
                speechVM: speechVM,
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal
            )
                .padding(.top, 4)
        }
    }

    /// Compact banner shown at top during a drill session, reminding the user of their constraint.
    private func drillBanner(_ drill: DrillRecommendation) -> some View {
        HStack(spacing: 8) {
            Image(systemName: drill.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(drill.tint)
            Text(drill.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text("·")
                .foregroundStyle(.secondary)
            Text(drill.constraint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    /// Compact banner indicating pressure mode is active during speaking.
    private var pressureBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
            Text("Pressure Mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text("·")
                .foregroundStyle(.secondary)
            Text("One take — stay committed")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Camera Overlay Layout (full-screen camera with minimal overlay)

    private var cameraOverlayLayout: some View {
        VStack(spacing: 0) {
            // Top bar: minimal — REC dot + timing + flip
            HStack(spacing: 12) {
                // REC indicator (no "LIVE" label)
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(reduceMotion ? 0.85 : (recPulse ? 1.0 : 0.3))
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: recPulse
                        )
                        .onAppear { recPulse = true }
                    Text("REC")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.2), in: Capsule())

                if speechVM.connectionError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                // Flip camera
                Button { videoManager.flipCamera() } label: {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial.opacity(0.3), in: Circle())
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            // Bottom overlay panel — elegant, glass-style
            cameraBottomPanel
        }
    }

    private var cameraBottomPanel: some View {
        VStack(spacing: 0) {
            // Timing progress bar — thin accent line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(timingState == .neutral ? .white.opacity(0.4) : timingState.vividColor)
                        .frame(width: geo.size.width * CGFloat(min(elapsedSeconds, totalDuration)) / CGFloat(max(totalDuration, 1)))
                        .animation(.easeInOut(duration: 0.5), value: elapsedSeconds)
                }
            }
            .frame(height: 2)

            VStack(spacing: 10) {
                // Timer — large, cinematic
                Text(formattedTime(elapsedSeconds))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                // Timing state label
                if timingState != .neutral {
                    Text(timingState.spotlightLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(timingState.vividColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(timingState.vividColor.opacity(0.15), in: Capsule())
                        .contentTransition(.interpolate)
                        .transition(.opacity.combined(with: .scale))
                }

                // Optional prompt — compact
                if keepPromptVisible {
                    Text(question)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                // Filler count — subtle
                if showFillerWords && speechVM.fillerWordCount > 0 {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: 5, height: 5)
                        Text("Fillers")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("\(speechVM.fillerWordCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }

                // Inline stop button — integrated into the panel
                Button(action: { stopSession() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                        Text("End")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(isStopping)
                .opacity(isStopping ? 0.5 : 1)
            }
            .padding(.top, 14)
            .padding(.bottom, 20)
            .padding(.horizontal, 24)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.45), .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Coach / Transcript Layout

    private var speakingTranscriptLayout: some View {
        VStack(spacing: 0) {
            // Premium header with status
            HStack(alignment: .center, spacing: 12) {
                NoumCharacter(
                    mood: speechVM.isRecording ? .listening : .calm,
                    tint: AppColor.brandBlue,
                    size: 36,
                    audioLevel: speechVM.audioLevel,
                    stage: characterStage
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(timingState == .neutral ? Color.green : timingState.vividColor)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(timingState == .neutral ? Color.green : timingState.vividColor)
                                    .frame(width: 8, height: 8)
                                    .opacity(reduceMotion ? 0 : 0.5)
                                    .scaleEffect(reduceMotion ? 1.0 : (recPulse ? 1.8 : 1.0))
                                    .animation(
                                        reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                        value: recPulse
                                    )
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

            // Transcript area — premium card. Rendered through the calm
            // live treatment: confirmed fillers are dim-marked, never red
            // mid-rep — live mistake-marking during performance invites
            // the self-monitoring the coaching trains away. The red
            // ledger stays on the summary, where it's reviewed after.
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    Text(LiveTranscriptStyle.calmed(speechVM.highlightedText))
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
                        .font(Typography.cardTitle)
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
            audioLevel: speechVM.audioLevel,
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
        // Reduce-motion: the label still changes (contentTransition is
        // env-aware) and the milestone haptic still fires — only the
        // scale bounce is dropped.
        guard !reduceMotion else { return }
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
        ConfettiLayer(active: showCelebration)
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
        // Toggle off if already speaking
        let speaker = IMMessageSpeaker.shared
        if ttsEngine.isSpeaking || isSpeakingPrompt {
            ttsEngine.stopSpeaking(at: .immediate)
            speaker.stop()
            isSpeakingPrompt = false
            return
        }

        isSpeakingPrompt = true

        // Try cloud TTS first (natural, high quality voice) with on-device fallback
        Task {
            let didPlayCloud = await speaker.speakPrompt(question)
            if didPlayCloud {
                // Cloud audio played successfully — wait for it to finish
                // The speaker's AVAudioPlayer will handle playback completion
                await MainActor.run { isSpeakingPrompt = false }
                return
            }

            // Fallback: on-device AVSpeechSynthesizer
            await MainActor.run {
                if ttsEngine.delegate == nil { configureTTSDelegate() }
                activateTTSAudioSession()

                let utterance = AVSpeechUtterance(string: question)
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
                utterance.pitchMultiplier = 0.98
                utterance.preUtteranceDelay = 0.15
                utterance.postUtteranceDelay = 0.3
                utterance.prefersAssistiveTechnologySettings = false
                utterance.voice = prewarmedVoice
                ttsEngine.speak(utterance)
            }
        }
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
            .accessibilityIdentifier("timedPractice.begin")
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
            .accessibilityIdentifier("timedPractice.startNow")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.clear)
    }

    private var speakingBottomBar: some View {
        let isImmersive = phase == .speaking && !showLiveTranscript && !isFullScreenCameraActive
        let isCamera = isFullScreenCameraActive

        return Group {
            if isCamera {
                // Camera mode: stop button is in the overlay panel, no bottom bar needed
                Color.clear.frame(height: 0)
            } else {
                VStack(spacing: 8) {
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
                            : AnyShapeStyle(Color.red),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isImmersive ? 0.2 : 0), lineWidth: 1)
                    )
                    .buttonStyle(.pressable)
                    .disabled(isStopping)
                    .opacity(isStopping ? 0.5 : 1)
                    .accessibilityIdentifier("timedPractice.end")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(
                    showLiveTranscript
                        ? AnyShapeStyle(.regularMaterial)
                        : AnyShapeStyle(Color.clear)
                )
            }
        }
    }

    // MARK: - Actions

    private func beginSession() {
        guard phase == .setup else { return }

        // Gate Coach mode behind premium
        if selectedMode == .coach && !premium.canUseCoachMode {
            showPaywall = true
            return
        }

        // Haptic feedback for session start fires before the AI hop so the
        // tap feels immediate even if prompt selection takes a beat.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Pre-rep ambience starts now so the user has audio feedback while
        // we resolve the prompt + warm up TTS.
        SoundscapeEngine.shared.startPreferredMode()

#if DEBUG
        if usesInjectedFirstValueLoop {
            question = "Brief the team on a customer handoff risk."
            if ttsEngine.delegate == nil { configureTTSDelegate() }
            phase = .speaking
            elapsedSeconds = 0
            isStopping = false
            completeInjectedFirstValueLoopRep()
            return
        }
#endif

        // Resolve the prompt asynchronously — gives PracticeTopics.next() a
        // budget to attempt an AI-generated prompt without blocking. Falls
        // back to the curated pool on timeout/failure (≤ 3s).
        Task { @MainActor in
            question = await PracticeTopics.next(
                profile: coachingProfileStore.profile,
                baseline: baselineStore.baseline,
                theme: selectedTheme
            )

            // Ensure TTS is ready (may already be prewarmed from onAppear)
            if ttsEngine.delegate == nil { configureTTSDelegate() }

            // Classic always gets 15-second thinking time; Coach respects the toggle
            // Pressure mode halves thinking time for increased challenge
            let useThinkingTime = selectedMode == .classic ? true : enableThinkingTime
            let thinkingDuration = practiceSettings.pressureModeEnabled ? 8 : 15

            if useThinkingTime {
                thinkingCountdown = thinkingDuration
                withAnimation(.easeInOut(duration: 0.3)) { phase = .thinking }
                startThinkingCountdown(thinkingDuration: thinkingDuration)
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
    }

    private func startThinkingCountdown(thinkingDuration: Int = 15) {
        thinkingTask?.cancel()
        thinkingTask = Task {
            for i in stride(from: thinkingDuration, through: 1, by: -1) {
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

        // Cut pre-rep ambience the moment the rep starts — soundscape
        // is for prep only, never for the rep itself.
        SoundscapeEngine.shared.stop()

        withAnimation(.easeInOut(duration: 0.3)) { phase = .speaking }

        elapsedSeconds = 0
        isStopping = false
        lastMilestoneState = .neutral
        milestoneScale = 1.0

#if DEBUG
        if usesInjectedFirstValueLoop {
            speakingTask?.cancel()
            speakingTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                completeInjectedFirstValueLoopRep()
            }
            return
        }
#endif

        speechVM.sessionPrompt = question
        speechVM.prepareSession(mode: .timed)
        speechVM.startRecording()

        // Start video recording if enabled (any mode)
        // Camera session was already prepared when the user toggled the switch
        if enableVideoRecording {
            Task {
                if videoManager.captureSession == nil {
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

#if DEBUG
    private func completeInjectedFirstValueLoopRep() {
        guard usesInjectedFirstValueLoop, !isStopping else { return }

        SoundscapeEngine.shared.stop()
        isStopping = true
        speakingTask?.cancel()
        speakingTask = nil
        elapsedSeconds = 46
        currentTimingState = ImpromptuTimingState.state(forElapsedSeconds: elapsedSeconds)

        let transcript = """
        I would start by naming the decision clearly. The team needs one owner for the customer handoff, then a weekly check on risk. I would tell the client what changed, what stays on track, and exactly when they will hear from us again.
        """
        let duration: TimeInterval = 46
        let fillerCount = FillerWordDetector.count(in: transcript)
        let result = PracticeEvaluator.evaluateTimedPractice(
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            difficulty: practiceSettings.timedDifficulty,
            recentSessions: sessionStore.sessions,
            profile: coachingProfileStore.profile,
            question: question.isEmpty ? nil : question
        )
        evaluation = result

        let pressureOn = practiceSettings.pressureModeEnabled
        let pressure = BaselineEngine.classifyPressure(
            mode: .timed,
            isPressureModeOn: pressureOn,
            streakDays: PracticeSession.calculateStreak(from: sessionStore.sessions)
        )
        let finalized = PracticeSessionFinalizer.finalize(
            store: sessionStore,
            draft: PracticeSessionDraft(
                transcript: transcript,
                fillerWordCount: fillerCount,
                duration: duration,
                date: Date(),
                mode: .timed,
                transcriptConfidence: 0.98,
                transcriptionProvider: "ui-testing",
                pressureLevel: pressure,
                isRated: pressureOn
            ),
            annotation: PracticeSessionAnnotation(
                score: result.score,
                xpEarned: result.xpEarned,
                headline: result.headline,
                insights: result.insights,
                coachSummary: result.feedback,
                prompt: question,
                theme: selectedTheme
            )
        )
        RecommendationLearningStore.shared.recordOutcome(
            for: finalized,
            previousSessions: Array(sessionStore.sessions.dropFirst())
        )
        pushInjectedSummary(
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            result: result
        )
    }

    private func pushInjectedSummary(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        result: PracticeEvaluation
    ) {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: AttributedString(transcript),
            fillerCount: fillerCount,
            duration: duration,
            score: result.score,
            progressSegments: progressSegments,
            xpEarned: result.xpEarned,
            committedFinalization: nil,
            suddenDeathGamePoints: nil,
            suddenDeathMultiplierLabels: [],
            suddenDeathTotalWords: nil,
            showDuration: false,
            practiceTitle: "Impromptu Practice",
            feedbackOverride: result.feedback,
            headlineOverride: result.headline,
            scoreBreakdown: result.segments,
            insights: result.insights,
            recentSessions: sessionStore.sessions,
            imConversationDetails: nil,
            explicitMode: .timed,
            recordingURL: nil,
            sessionPrompt: question,
            sessionTheme: selectedTheme,
            feedbackCategories: result.categories,
            strongMoments: result.strongMoments,
            weakMoments: result.weakMoments,
            durationAssessment: result.durationAssessment,
            targetRange: result.targetRange,
            onStartDrill: { [self] drill in
                activeDrill = drill
                restartSession()
            }
        )
        SummaryDataStore.shared.store(entry, for: payloadId)
        navigationPath.append(AppDestination.summary(SummaryPayload(id: payloadId, mode: .timed)))
    }
#endif

    private func stopSession() {
        guard !isStopping else { return }
        isStopping = true
        CoachHaptic.sessionComplete()
        speakingTask?.cancel()
        speakingTask = nil
        speechVM.stopRecording()
        if videoManager.isRecording { videoManager.stopRecording() }

        Task {
            // Wait for video recording delegate to finish writing the file
            // The delegate publishes an explicit terminal state when the file is ready or failed.
            if enableVideoRecording {
                _ = await videoManager.waitForRecordingFinalization()
            }
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                let result = PracticeEvaluator.evaluateTimedPractice(
                    transcript: speechVM.transcribedText,
                    fillerCount: speechVM.fillerWordCount,
                    duration: speechVM.lastSessionDuration,
                    difficulty: practiceSettings.timedDifficulty,
                    recentSessions: speechVM.pastSessions,
                    profile: coachingProfileStore.profile,
                    question: question.isEmpty ? nil : question
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

                pushSummary()
            }
        }
    }

    /// Retry with the same prompt — skip setup and go straight to thinking/speaking.
    private func restartSession() {
        cleanup()
        resetState(keepPrompt: true)
        // Go straight into the session flow (skip setup page)
        launchSessionFlow()
    }

    /// Pick a new random prompt and start a new session.
    private func newPromptSession() {
        cleanup()
        resetState(keepPrompt: false)
        Task { @MainActor in
            question = await PracticeTopics.next(
                profile: coachingProfileStore.profile,
                baseline: baselineStore.baseline,
                theme: selectedTheme
            )
            launchSessionFlow()
        }
    }

    private func resetState(keepPrompt: Bool) {
        speakingTask?.cancel()
        thinkingTask?.cancel()
        speechVM.resetCurrentSession()
        thinkingCountdown = practiceSettings.pressureModeEnabled ? 8 : 15
        elapsedSeconds = 0
        currentTimingState = .neutral
        evaluation = nil
        isStopping = false
        spotlightPulse = false
        lastMilestoneState = .neutral
        milestoneScale = 1.0
        recPulse = false
        showCelebration = false
        // Reset video recording state for the new session
        videoManager.cleanup()
        // Don't reset phase yet — launchSessionFlow will set it
        phase = .setup
    }

    /// Shared logic for starting a session from retry/new prompt flows.
    /// Bypasses the setup page guard in beginSession().
    private func launchSessionFlow() {
        if ttsEngine.delegate == nil { configureTTSDelegate() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let useThinkingTime = selectedMode == .classic ? true : enableThinkingTime
        let thinkingDuration = practiceSettings.pressureModeEnabled ? 8 : 15
        if useThinkingTime {
            thinkingCountdown = thinkingDuration
            withAnimation(.easeInOut(duration: 0.3)) { phase = .thinking }
            // Pre-rep ambience runs through the thinking window — long
            // enough for the user to feel it, cuts the moment recording
            // starts inside `startSpeaking()` so it never bleeds onto the
            // rep itself.
            SoundscapeEngine.shared.startPreferredMode()
            startThinkingCountdown(thinkingDuration: thinkingDuration)
        } else if !keepPromptVisible {
            withAnimation(.easeInOut(duration: 0.3)) { phase = .briefReveal }
            SoundscapeEngine.shared.startPreferredMode()
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

    private func cleanup() {
        speakingTask?.cancel()
        thinkingTask?.cancel()
        speakingTask = nil
        thinkingTask = nil
        ttsEngine.stopSpeaking(at: .immediate)
        if videoManager.isRecording { videoManager.stopRecording() }
        // If the user backs out mid-thinking-window, stop ambience so
        // it doesn't leak into the next surface.
        SoundscapeEngine.shared.stop()
    }

    // MARK: - Navigation

    private func pushSummary() {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: speechVM.highlightedText,
            fillerCount: speechVM.fillerWordCount,
            duration: speechVM.lastSessionDuration,
            score: evaluation?.score,
            progressSegments: progressSegments,
            xpEarned: evaluation?.xpEarned ?? 0,
            committedFinalization: nil,
            suddenDeathGamePoints: nil,
            suddenDeathMultiplierLabels: [],
            suddenDeathTotalWords: nil,
            showDuration: false,
            practiceTitle: "Impromptu Practice",
            feedbackOverride: evaluation?.feedback,
            headlineOverride: evaluation?.headline,
            scoreBreakdown: evaluation?.segments ?? [],
            insights: evaluation?.insights ?? [],
            recentSessions: speechVM.pastSessions,
            imConversationDetails: nil,
            explicitMode: .timed,
            recordingURL: videoManager.recordingURL,
            sessionPrompt: question,
            sessionTheme: selectedTheme,
            feedbackCategories: evaluation?.categories ?? [],
            strongMoments: evaluation?.strongMoments ?? [],
            weakMoments: evaluation?.weakMoments ?? [],
            durationAssessment: evaluation?.durationAssessment ?? .onTarget,
            targetRange: evaluation?.targetRange ?? practiceSettings.timedDifficulty.targetRange,
            onStartDrill: { [self] drill in
                activeDrill = drill
                restartSession()
            }
        )
        SummaryDataStore.shared.store(entry, for: payloadId)
        let payload = SummaryPayload(id: payloadId, mode: .timed)
        navigationPath.append(AppDestination.summary(payload))
    }

}
#endif
