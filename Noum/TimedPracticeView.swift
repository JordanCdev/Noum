import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
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

/// Pure timing projection shared by Timed's timer UI and automatic stop.
/// The default preserves the established 60/90/120/150 impromptu contract.
/// Prepared speeches use their own minimum and target and remain user-ended,
/// so a four-to-six-minute brief is never terminated by the short-rep cap.
struct TimedPracticeTimingPolicy: Equatable {
    struct Milestone: Identifiable, Equatable {
        let seconds: Int
        let state: ImpromptuTimingState
        var id: Int { seconds }
    }

    let targetSeconds: Int
    let greenStart: Int
    let yellowStart: Int
    let redStart: Int
    let overtimeStart: Int
    let automaticStopSeconds: Int?

    static let standard = TimedPracticeTimingPolicy(
        targetSeconds: ImpromptuTimingState.hardStopSeconds,
        greenStart: 60,
        yellowStart: 90,
        redStart: 120,
        overtimeStart: ImpromptuTimingState.hardStopSeconds,
        automaticStopSeconds: ImpromptuTimingState.hardStopSeconds
    )

    static func project(_ project: SpeechProject) -> TimedPracticeTimingPolicy {
        let minimum = max(1, Int(project.durationMinimum.rounded(.up)))
        let target = max(minimum, Int(project.durationTarget.rounded(.up)))
        let midpoint = minimum + ((target - minimum) / 2)
        return TimedPracticeTimingPolicy(
            targetSeconds: target,
            greenStart: minimum,
            yellowStart: midpoint,
            redStart: target,
            overtimeStart: target + max(15, target / 10),
            automaticStopSeconds: nil
        )
    }

    var milestones: [Milestone] {
        [
            Milestone(seconds: greenStart, state: .green),
            Milestone(seconds: yellowStart, state: .yellow),
            Milestone(seconds: redStart, state: .red),
        ]
    }

    func state(for elapsedSeconds: Int) -> ImpromptuTimingState {
        switch elapsedSeconds {
        case ..<greenStart: return .neutral
        case greenStart..<yellowStart: return .green
        case yellowStart..<redStart: return .yellow
        case redStart..<overtimeStart: return .red
        default: return .overtime
        }
    }
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

// MARK: - Background Layer (extracted for render isolation)

@available(iOS 17.0, macOS 12.0, *)
private struct BackgroundLayerView: View {
    let phase: TimedSessionPhase
    let timingState: ImpromptuTimingState
    let isFullScreenCameraActive: Bool
    let showLiveTranscript: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if phase == .setup {
            FocusedPracticeBackground(style: .timed)
        } else if phase == .speaking && isFullScreenCameraActive {
            Color.black.ignoresSafeArea()
        } else if phase == .speaking && !showLiveTranscript {
            ZStack {
                LinearGradient(
                    colors: [timingState.immersiveGradientStart, timingState.immersiveGradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.8), value: timingState)

                RadialGradient(
                    colors: [timingState.vividColor.opacity(timingState.glowOpacity * 0.3), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 360
                )
                .ignoresSafeArea()
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.4), value: timingState)
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
    let timingPolicy: TimedPracticeTimingPolicy
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
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: voiceLevel)
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
                .animation(reduceMotion ? nil : .linear(duration: 0.9), value: elapsedSeconds)

            // Center content
            centerContent
        }
        .onAppear { spotlightPulse = true }
    }

    private var milestoneMarkers: some View {
        ForEach(timingPolicy.milestones) { milestone in
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
                .animation(reduceMotion ? nil : .bouncySpring, value: reached)
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: timingState)
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Impromptu Settings Panel (extracted for render isolation)

@available(iOS 17.0, macOS 12.0, *)
private struct ImpromptuSettingsPanel: View {
    @Binding var keepPromptVisible: Bool
    @Binding var timerDisplay: TimerDisplayOption
    @Binding var enableThinkingTime: Bool
    @Binding var showLiveTranscript: Bool
    @Binding var showFillerWords: Bool
    @Binding var enableVideoRecording: Bool
    @Binding var showPaywall: Bool
    @ObservedObject var premium: PremiumManager
    @ObservedObject var videoManager: VideoRecordingManager

    private let accent = AppColor.modeTimed

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rep settings")
                        .font(Typography.cardLabel)
                    Text("Defaults are ready.")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.sm)

            freeToggleRow(
                icon: "timer",
                iconColor: .orange,
                title: "Prep countdown",
                caption: "15 seconds",
                isOn: $enableThinkingTime
            )

            thinDivider

            freeToggleRow(
                icon: "eye",
                iconColor: .indigo,
                title: "Prompt visible",
                caption: "During the rep",
                isOn: $keepPromptVisible
            )

            thinDivider

            timerPicker

            coachToolsHeader

            premiumToggleRow(
                icon: "text.quote",
                iconColor: .teal,
                title: "Live transcript",
                caption: enableVideoRecording ? "Video is on" : "Words on screen",
                isOn: Binding(
                    get: { showLiveTranscript },
                    set: handleLiveTranscriptChange
                ),
                disabled: enableVideoRecording,
                accessibilityID: "timedPractice.settings.liveTranscript"
            )

            thinDivider

            premiumToggleRow(
                icon: "waveform.badge.magnifyingglass",
                iconColor: .red,
                title: "Filler tracking",
                caption: "Live count",
                isOn: $showFillerWords,
                accessibilityID: "timedPractice.settings.fillerTracking"
            )

            thinDivider

            premiumToggleRow(
                icon: "video.fill",
                iconColor: .pink,
                title: "Record video",
                caption: showLiveTranscript ? "Transcript is on" : "Camera review",
                isOn: Binding(
                    get: { enableVideoRecording },
                    set: handleVideoRecordingChange
                ),
                disabled: showLiveTranscript,
                accessibilityID: "timedPractice.settings.video"
            )
        }
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var timerPicker: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Timer display")
                    .font(Typography.body.weight(.semibold))
                Text("Choose timing visibility")
                    .font(Typography.caption)
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
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var coachToolsHeader: some View {
        Text("Coach tools")
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
    }

    private func freeToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        caption: String,
        isOn: Binding<Bool>
    ) -> some View {
        toggleRow(
            icon: icon,
            iconColor: iconColor,
            title: title,
            caption: caption,
            isOn: isOn,
            disabled: false
        )
    }

    @ViewBuilder
    private func premiumToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        caption: String,
        isOn: Binding<Bool>,
        disabled: Bool = false,
        accessibilityID: String
    ) -> some View {
        if premium.isPremium {
            toggleRow(
                icon: icon,
                iconColor: iconColor,
                title: title,
                caption: caption,
                isOn: isOn,
                disabled: disabled
            )
            .accessibilityIdentifier(accessibilityID)
        } else {
            Button {
                showPaywall = true
            } label: {
                rowShell(
                    icon: icon,
                    iconColor: iconColor,
                    title: title,
                    caption: "Pro · \(caption)",
                    disabled: false
                ) {
                    proBadge
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(accessibilityID).locked")
            .accessibilityLabel("\(title), Pro feature. Upgrade to unlock.")
        }
    }

    private func toggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        caption: String,
        isOn: Binding<Bool>,
        disabled: Bool
    ) -> some View {
        rowShell(icon: icon, iconColor: iconColor, title: title, caption: caption, disabled: disabled) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent)
                .disabled(disabled)
        }
    }

    private func rowShell<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        caption: String,
        disabled: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(disabled ? iconColor.opacity(0.4) : iconColor)
                .frame(width: 34, height: 34)
                .background((disabled ? iconColor.opacity(0.04) : iconColor.opacity(0.1)), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(disabled ? .secondary : .primary)
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(disabled ? .tertiary : .secondary)
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var proBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption2.weight(.bold))
            Text("Pro")
                .font(Typography.captionSmall.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(AppColor.pro, in: Capsule())
    }

    private var thinDivider: some View {
        Divider()
            .padding(.horizontal, 16)
    }

    private func handleLiveTranscriptChange(_ newValue: Bool) {
        showLiveTranscript = newValue
        if newValue {
            enableVideoRecording = false
        }
    }

    private func handleVideoRecordingChange(_ newValue: Bool) {
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
}

// MARK: - TimedPracticeView

/// A content-bounded projection of the source-bound retry handoff. The view
/// reads this model but never persists it; ownership remains with
/// `TimedPracticePromptHandoff` and `RecommendationLearningStore`.
struct TargetedRetryPresentation: Equatable {
    static let badge = "SAME PROMPT · SAME TARGET"
    static let permissionNote = "Microphone opens only after you tap Start."

    let title: String
    let focus: String
    let prompt: String
    let cues: [String]

    init?(payload: TimedPracticePromptHandoff.Payload) {
        guard let intent = payload.transcriptPracticeIntent,
              intent.retryTarget.isSupported else {
            return nil
        }
        title = "Try it once more"
        focus = intent.target
        prompt = payload.text
        cues = Self.cues(for: intent.retryTarget.lever)
    }

    var cueAccessibilityLabel: String {
        let ordered = cues.enumerated().map { index, cue in
            "\(index + 1), \(cue)"
        }.joined(separator: ". ")
        return "Retry instructions. \(ordered)."
    }

    private static func cues(for lever: TranscriptPracticeLever) -> [String] {
        switch lever {
        case .opening:
            return ["Answer first", "One proof point", "Then stop"]
        case .closing:
            return ["Name the decision", "Name the next step", "Then stop"]
        case .structure:
            return ["Lead with the point", "Use one signpost", "Land the answer"]
        case .concise:
            return ["Keep the meaning", "One main point", "Then stop"]
        }
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct TimedPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @Binding var navigationPath: NavigationPath
    /// Exact per-rep demand carried by a rendered recommendation. This value
    /// never mutates the user's saved difficulty.
    var prescribedTimedDifficulty: TimedPracticeDifficulty? = nil
    /// Present only for a seeded launch. Ordinary Timed routes deliberately do
    /// not consume a pending prompt from another surface.
    var promptHandoffToken: UUID? = nil
    /// Optional immutable catalog context for an existing Speech Project.
    /// It never becomes a second session or persistence owner.
    var speechProject: SpeechProject? = nil
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var premium = PremiumManager.shared
    // Session intent can still be attached by future inline/chat-driven
    // declarations, but Timed never auto-interrupts setup with a focus sheet.

    // Session state
    @AppStorage("timedPractice.selectedTheme") private var selectedThemeRaw: String = PromptTheme.all.rawValue
    @State private var question: String = ""
    @State private var wordOfTheDayTarget: String?
    @State private var phase: TimedSessionPhase = .setup
    @State private var thinkingCountdown: Int = 15
    @State private var elapsedSeconds: Int = 0
    @State private var evaluation: PracticeEvaluation?
    @State private var isStopping = false
    /// One-shot route payload carrying an exact server challenge prompt and
    /// its content-free authority together. Prompt replacement invalidates it.
    @State private var seededPromptPayload: TimedPracticePromptHandoff.Payload?
    /// Immutable scoring/demand input captured when this rep begins. Settings
    /// may change between reps, but never retroactively change an active rep.
    @State private var activeTimedDifficulty: TimedPracticeDifficulty?
    @State private var showExitConfirmation = false
    @State private var activeDrill: DrillRecommendation?

    // Tasks
    @State private var thinkingTask: Task<Void, Never>?
    @State private var speakingTask: Task<Void, Never>?

    // Settings (persisted via @AppStorage)
    @AppStorage("timedPractice.keepPromptVisible") private var keepPromptVisible: Bool = false
    @AppStorage("timedPractice.timerDisplay") private var timerDisplayRaw: String = TimerDisplayOption.none.rawValue
    @AppStorage("timedPractice.enableThinkingTime") private var enableThinkingTime: Bool = true
    @AppStorage("timedPractice.showLiveTranscript") private var showLiveTranscript: Bool = false
    @AppStorage("timedPractice.showFillerWords") private var showFillerWords: Bool = false
    @State private var showSetupSettings = false

    // Per-rep one-shot fast-start (auto-guided first rep only). When the
    // `AutoGuidedFirstRep.fastStartOnce` flag is consumed in the QuickStart
    // handshake, this rep skips the prep countdown and keeps the prompt visible
    // WITHOUT touching the user's persistent `enableThinkingTime` /
    // `keepPromptVisible` prefs. See `docs/SPEC_first_rep_fast_start.md`.
    @State private var fastStartActive = false

    /// Thinking-time for *this* rep: forced off when fast-start is active,
    /// otherwise the user's saved preference.
    private var effectiveThinkingTime: Bool { fastStartActive ? false : enableThinkingTime }

    /// Prompt visibility for *this* rep: forced on when fast-start is active so
    /// the seeded prompt stays on screen with no countdown; otherwise the user's
    /// saved preference.
    private var effectiveKeepPromptVisible: Bool { fastStartActive ? true : keepPromptVisible }

    private var timerDisplay: TimerDisplayOption {
        get { TimerDisplayOption(rawValue: timerDisplayRaw) ?? .none }
        nonmutating set { timerDisplayRaw = newValue.rawValue }
    }

    private var selectedTheme: PromptTheme {
        get { PromptTheme(rawValue: selectedThemeRaw) ?? .all }
        nonmutating set { selectedThemeRaw = newValue.rawValue }
    }

    private var usesInjectedFirstValueLoop: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_FIRST_VALUE_LOOP")
    }

    private var usesInjectedTranscriptRetryImprovement: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_TRANSCRIPT_RETRY_IMPROVED")
    }

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

    // Video recording
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

    private var timingPolicy: TimedPracticeTimingPolicy {
        speechProject.map(TimedPracticeTimingPolicy.project) ?? .standard
    }

    private var totalDuration: Int { timingPolicy.targetSeconds }

    private var thinkingSubtitle: String {
        if practiceSettings.pressureModeEnabled {
            return thinkingCountdown > 5 ? "Pressure mode — think fast" : thinkingCountdown > 2 ? "Commit to your opening" : "Go."
        }
        return thinkingCountdown > 10 ? "Breathe and think" : thinkingCountdown > 5 ? "Plan your opening" : "Almost ready..."
    }

    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
    }

    private var targetedRetryPresentation: TargetedRetryPresentation? {
        seededPromptPayload.flatMap(TargetedRetryPresentation.init(payload:))
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
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: phase)

                if phase != .setup {
                    bottomBar
                }
            }
        }
        .overlay {
            if showCelebration {
                celebrationOverlay
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .center) {
            if phase == .speaking, let error = speechVM.connectionError, !speechVM.isRecording {
                recordingIssueCard(error)
                    .padding(.horizontal, Spacing.screenH)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.96))
                    )
            }
        }
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
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
        .task {
            // Quick Start handshake FIRST — before the yield and the awaited
            // prompt resolution below. When the picker armed a one-tap launch,
            // begin immediately so the setup page (and its own Begin button)
            // never renders: otherwise that page is visible for the duration of
            // `await PracticeTopics.next(...)` (up to a ~3s budget), flashing a
            // redundant second Begin at the flagship first-rep moment.
            // `beginSession()` resolves the prompt and configures TTS itself,
            // so the work skipped here is not lost — just not done twice.
            let quickStartRequested = phase == .setup
                && PracticeModeQuickStart.consume(for: .timed)
            let quickStartSeededPrompt = quickStartRequested
                ? consumeSeededPrompt()
                : nil
            if quickStartRequested, targetedRetryPresentation == nil {
                if let seeded = quickStartSeededPrompt { question = seeded }
                // Consume the auto-guided first-rep instant-start one-shot. A
                // returning-user QuickStart never armed it, so this is a no-op
                // for them; for the auto-guided rep it drops the 15s countdown
                // and keeps the prompt visible for this rep only.
                fastStartActive = AutoGuidedFirstRep.consumeFastStartOnce()
                speechVM.prepareForInteractiveUse()
                prewarmTTS()
                enforcePremiumFeatureAvailability()
                if enableVideoRecording && videoManager.captureSession == nil {
                    if await VideoRecordingManager.requestCameraPermission() {
                        _ = await videoManager.prepareSession()
                    } else {
                        enableVideoRecording = false
                    }
                }
                beginSession()
                return
            }

            // Batch initial setup into a single Task so SwiftUI
            // processes the state changes in one transaction.
            // Yield first so the view renders its initial frame immediately.
            await Task.yield()
            // A source-bound retry consumes any stale quick-start authority
            // above but deliberately remains on setup until its visible Start
            // action is tapped. Reuse its already-consumed payload here.
            let seededPrompt = quickStartSeededPrompt ?? consumeSeededPrompt()
            if question.isEmpty {
                // A route-bound producer may supply one exact prompt. Ordinary
                // Timed routes fall through to the established topic engine.
                if let seeded = seededPrompt {
                    question = seeded
                } else {
                    question = await nextPrompt()
                }
            }
            speechVM.prepareForInteractiveUse()
            prewarmTTS()
            enforcePremiumFeatureAvailability()

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

            // (Quick Start consume is handled at the top of this `.task` so the
            // setup page never renders for an armed one-tap launch.)
        }
        .onDisappear {
            discardSeededChallengeAuthority()
            cleanup()
            // Drop any pending intent that wasn't consumed by a finalize.
            SessionIntentStore.shared.clearPending()
        }
        .onChange(of: speechVM.connectionError) { _, error in
            guard error != nil, phase == .speaking else { return }
            speakingTask?.cancel()
            speakingTask = nil
            if videoManager.isRecording { videoManager.stopRecording() }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(entryPoint: .train)
        }
        .sheet(isPresented: $showSetupSettings) {
            NavigationStack {
                ZStack {
                    AppColor.screenBackground.ignoresSafeArea()
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Spacing.lg) {
                            promptPoolRow
                            settingsCard
                            if enableVideoRecording, let session = videoManager.captureSession {
                                cameraSetupPreview(session: session)
                            }
                        }
                        .padding(Spacing.screenH)
                    }
                }
                .navigationTitle("Adjust impromptu")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showSetupSettings = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        let newState = timingPolicy.state(for: elapsedSeconds)
        if newState != currentTimingState {
            updateWithMotion(.easeInOut(duration: 0.6)) {
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
        if let seededPromptPayload {
            return seededPromptPayload.text
        }
        guard let promptHandoffToken else { return nil }
        guard let payload = TimedPracticePromptHandoff.shared.consumePayload(
            token: promptHandoffToken
        ) else { return nil }
        if let challengeID = payload.competitiveObservationIntent?.challengeID,
           !ChallengesManager.shared.armSubmission(
            challengeID: challengeID,
            exactPrompt: payload.text,
            routeToken: promptHandoffToken
           ) {
            return nil
        }
        if let intent = payload.transcriptPracticeIntent {
            // Summary can render another recommendation while navigation is
            // transitioning. Reassert the accepted, source-bound ladder at
            // the practice boundary so the completed rep cannot be joined to
            // a newer card or silently lose its intervention provenance.
            RecommendationLearningStore.shared.ensureTranscriptRetryAccepted(intent)
        }
        seededPromptPayload = payload
        return payload.text
    }

    private func discardSeededChallengeAuthority() {
        guard let promptHandoffToken,
              seededPromptPayload?.competitiveObservationIntent?.challengeID != nil else {
            seededPromptPayload = nil
            return
        }
        ChallengesManager.shared.disarmSubmission(
            matchingRouteToken: promptHandoffToken
        )
        seededPromptPayload = nil
    }

    private func nextPrompt() async -> String {
        if let speechProject,
           let prompt = speechProject.prompts.randomElement() {
            return prompt
        }
        return await PracticeTopics.next(
            profile: coachingProfileStore.profile,
            baseline: baselineStore.baseline,
            theme: selectedTheme
        )
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Setup Phase

    @ViewBuilder
    private var setupContent: some View {
        if let targetedRetryPresentation {
            targetedRetrySetupContent(targetedRetryPresentation)
        } else {
            standardSetupContent
        }
    }

    private var standardSetupContent: some View {
        FocusedPracticeScaffold(
            style: .timed,
            status: enableThinkingTime ? "Ready with 15-second prep" : "Ready for instant start",
            title: speechProject?.title ?? PracticeMode.timed.displayLabel,
            subtitle: speechProject?.tagline ?? "One prompt. One take. A clear landing."
        ) {
            Button {
                CoachHaptic.selectionTap()
                showSetupSettings = true
            } label: {
                Label("Adjust", systemImage: "slider.horizontal.3")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(.white.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timedPractice.settings.toggle")
            .accessibilityLabel("Adjust Timed Practice")
        } content: {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(speechProject == nil
                         ? "Think fast. Land one clear answer."
                         : "Prepare one complete speech.")
                        .font(Typography.figtree(size: 30, weight: .bold, relativeTo: .title))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("The prompt appears when the rep starts.")
                        .font(Typography.subheadline)
                        .foregroundStyle(AppColor.focusedTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let speechProject {
                    speechProjectSetupCue(speechProject)
                } else {
                    impromptuSetupCue
                }

                microphoneReadinessCard
            }
        }
        .accessibilityIdentifier("timedPractice.screen")
        .safeAreaInset(edge: .bottom) {
            setupBottomBar
        }
    }

    private func targetedRetrySetupContent(
        _ presentation: TargetedRetryPresentation
    ) -> some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // V4.6 colour law: retry is a coaching action — one
                    // indigo/violet action family, never the legacy blue.
                    Text(TargetedRetryPresentation.badge)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.proText)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            AppColor.proQuietSurface,
                            in: Capsule()
                        )
                        .accessibilityLabel("Same prompt, same target")

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(presentation.title)
                            .font(Typography.screenTitle)
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text(presentation.focus)
                            .font(Typography.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("YOUR PROMPT")
                            .font(Typography.captionSmall)
                            .foregroundStyle(AppColor.textTertiary)

                        Text(presentation.prompt)
                            .font(Typography.cardTitle)
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("timedPractice.prompt")
                    }
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        AppColor.cardBackground,
                        in: RoundedRectangle(
                            cornerRadius: CornerRadius.large,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: CornerRadius.large,
                            style: .continuous
                        )
                        .stroke(AppColor.subtleBorder, lineWidth: 1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Your prompt. \(presentation.prompt)")

                    retryCueLayout(presentation)

                    setupStartAction

                    Text(targetedRetryMicrophoneNote)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            AppColor.tagBackground,
                            in: RoundedRectangle(
                                cornerRadius: CornerRadius.medium,
                                style: .continuous
                            )
                        )
                        .accessibilityIdentifier("timedPractice.targetedRetry.microphoneNote")
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }
        }
        .accessibilityIdentifier("timedPractice.targetedRetry.screen")
    }

    @ViewBuilder
    private func retryCueLayout(_ presentation: TargetedRetryPresentation) -> some View {
        let verticalCues = VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(presentation.cues.enumerated()), id: \.offset) { _, cue in
                retryCue(cue)
            }
        }

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalCues
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(Array(presentation.cues.enumerated()), id: \.offset) { _, cue in
                            retryCue(cue)
                        }
                    }
                    verticalCues
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.cueAccessibilityLabel)
        .accessibilityHint("Instructions for this retry")
        .accessibilityIdentifier("timedPractice.targetedRetry.cues")
    }

    private func retryCue(_ cue: String) -> some View {
        Text(cue)
            .font(Typography.caption)
            .foregroundStyle(AppColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(AppColor.tagBackground, in: Capsule())
    }

    private var targetedRetryMicrophoneNote: String {
        switch speechVM.microphonePermissionState {
        case .granted:
            return "Microphone starts only after you tap Start."
        case .undetermined:
            return TargetedRetryPresentation.permissionNote
        case .denied:
            return "Microphone access is off. Enable it in Settings before this retry can begin."
        case .unknown:
            return "Microphone is unavailable. Check your audio route before you tap Start."
        }
    }

    private var impromptuSetupCue: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: selectedTheme.icon)
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(wordOfTheDayTarget == nil ? "Prompt pool" : "Today's word")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.focusedTextSecondary)

                Text(wordOfTheDayTarget ?? selectedTheme.rawValue)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 6) {
                if let prescribedTimedDifficulty {
                    Text(prescribedTimedDifficulty.title)
                        .font(Typography.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.18), in: Capsule())
                }

                Text(enableThinkingTime ? "15s prep" : "Instant start")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.focusedTextSecondary)
            }
        }
        .padding(Spacing.md)
        .focusedGlassSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("timedPractice.prescribedDifficulty")
        .accessibilityLabel(impromptuSetupCueAccessibilityLabel)
    }

    private func speechProjectSetupCue(_ project: SpeechProject) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: project.symbolName)
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(project.focus.label)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(formattedTime(Int(project.durationMinimum))) minimum · \(formattedTime(Int(project.durationTarget))) target")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.focusedTextSecondary)
                }
            }

            Text(project.coachLine)
                .font(Typography.caption)
                .foregroundStyle(AppColor.focusedTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .focusedGlassSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timedPractice.speechProject.\(project.id)")
        .accessibilityLabel("\(project.title) speech project")
        .accessibilityValue("\(Int(project.durationMinimum)) second minimum, \(Int(project.durationTarget)) second target")
    }

    private var impromptuSetupCueAccessibilityLabel: String {
        let promptContext = wordOfTheDayTarget.map { "Today's word, \($0)" }
            ?? "Prompt pool, \(selectedTheme.rawValue)"
        let startStyle = enableThinkingTime ? "15 seconds to prepare" : "instant start"
        let demand = prescribedTimedDifficulty.map { " Recommended difficulty, \($0.title)." } ?? ""
        return "\(promptContext).\(demand) \(startStyle)."
    }

    private var setupHeader: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(PracticeMode.timed.displayLabel)
                    .font(Typography.figtree(size: 36, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(.primary)
                if !showSetupSettings {
                    Text("Surprise prompt. One take. Clean landing.")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Button {
                CoachHaptic.selectionTap()
                animateSetupChange {
                    showSetupSettings.toggle()
                }
            } label: {
                Image(systemName: showSetupSettings ? "xmark" : "gearshape.fill")
                    .font(Typography.headline)
                    .foregroundStyle(showSetupSettings ? .secondary : AppColor.modeTimed)
                    .frame(width: 48, height: 48)
                    .background(AppColor.cardBackground, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timedPractice.settings.toggle")
            .accessibilityLabel(showSetupSettings ? "Hide Timed Practice settings" : "Show Timed Practice settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var impromptuLaunchCard: some View {
        if showSetupSettings {
            compactImpromptuLaunchCard
        } else {
            fullImpromptuLaunchCard
        }
    }

    @ViewBuilder
    private var microphoneReadinessCard: some View {
        switch speechVM.microphonePermissionState {
        case .granted:
            EmptyView()
        case .undetermined:
            microphoneCard(
                icon: "mic.fill",
                title: "Mic check",
                message: "Noum needs the microphone to hear your rep and coach the real answer.",
                actionTitle: "Enable microphone",
                action: requestMicrophoneAccess
            )
        case .denied:
            microphoneCard(
                icon: "mic.slash.fill",
                title: "Mic access blocked",
                message: PracticeMicrophonePermissionState.denied.userFacingRecoveryMessage ?? "Open Settings and allow microphone access before starting.",
                actionTitle: "Open Settings",
                action: openAppSettings
            )
        case .unknown:
            microphoneCard(
                icon: "waveform.badge.exclamationmark",
                title: "Mic unavailable",
                message: PracticeMicrophonePermissionState.unknown.userFacingRecoveryMessage ?? "Check the audio route and try again.",
                actionTitle: nil,
                action: nil
            )
        }
    }

    private func microphoneCard(
        icon: String,
        title: String,
        message: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(Typography.headline)
                .foregroundStyle(AppColor.modeTimed)
                .frame(width: 42, height: 42)
                .background(AppColor.modeTimed.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.modeTimed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(minHeight: 44)
                    .background(AppColor.modeTimed.opacity(0.10), in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("timedPractice.microphoneReadiness.action")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.modeTimed.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 5)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timedPractice.microphoneReadiness")
    }

    private func recordingIssueCard(_ message: String) -> some View {
        let title: String
        let detail: String
        let requiresLocaleChange: Bool
        switch speechVM.recordingIssue {
        case .unsupportedOnDeviceLocale:
            title = "This language isn't available offline"
            detail = "\(message) Choose another Practice language in Settings or continue on a device that supports it."
            requiresLocaleChange = true
        case nil:
            title = "We could not hear the rep"
            detail = message
            requiresLocaleChange = false
        }

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "mic.slash.fill")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(Typography.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if requiresLocaleChange {
                Button(action: returnToSetupAfterRecordingIssue) {
                    Label("Back to setup", systemImage: "arrow.backward")
                        .font(Typography.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white, in: Capsule())
                        .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.22))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("timedPractice.recordingIssue.backToSetup")
            } else {
                Button(action: retryRecordingAfterIssue) {
                    Label(speechVM.microphonePermissionState == .denied ? "Open Settings" : "Try again", systemImage: "arrow.clockwise")
                        .font(Typography.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white, in: Capsule())
                        .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.22))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("timedPractice.recordingIssue.retry")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.20), Color(red: 0.21, green: 0.28, blue: 0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 30, y: 15)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timedPractice.recordingIssue")
    }

    private var compactImpromptuLaunchCard: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Ready to start")
                    .font(Typography.figtree(size: 20, weight: .bold, relativeTo: .title3))
                    .foregroundStyle(.white)

                Text("\(enableThinkingTime ? "You have 15 seconds to prepare" : "Starts immediately") with \(selectedTheme.rawValue.lowercased()) prompts. \(keepPromptVisible ? "The prompt stays visible." : "The prompt hides when you start.")")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                CoachHaptic.selectionTap()
                animateSetupChange {
                    showSetupSettings = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timedPractice.settings.toggle")
            .accessibilityLabel("Hide Impromptu settings")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(impromptuCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppColor.modeTimed.opacity(0.18), radius: 18, y: 8)
    }

    private var fullImpromptuLaunchCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .center) {
                Label("Ready", systemImage: "bolt.fill")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.16), in: Capsule())

                Spacer()

                Text(enableThinkingTime ? "15s prep" : "Instant start")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Think fast. Land one clear answer.")
                    .font(Typography.figtree(size: 28, weight: .bold, relativeTo: .title))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("The prompt appears when the rep begins.")
                    .font(Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                setupChip(icon: selectedTheme.icon, text: selectedTheme.rawValue)
                setupChip(icon: keepPromptVisible ? "eye.fill" : "eye.slash.fill", text: keepPromptVisible ? "Prompt on" : "Prompt hidden")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusedGlassSurface()
    }

    private var impromptuCardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    AppColor.modeTimed,
                    AppColor.modePace
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 190, height: 190)
                .blur(radius: 22)
                .offset(x: 120, y: -80)

            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                .frame(width: 170, height: 170)
                .offset(x: -105, y: 82)
        }
        .clipShape(RoundedRectangle(cornerRadius: showSetupSettings ? CornerRadius.large : CornerRadius.xl, style: .continuous))
    }

    private func setupChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(text)
                .font(Typography.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.13), in: Capsule())
    }

    private var promptPoolRow: some View {
        Menu {
            ForEach(PromptTheme.allCases) { theme in
                Button {
                    setPromptTheme(theme)
                } label: {
                    Label(theme.rawValue, systemImage: theme.icon)
                }
            }
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: selectedTheme.icon)
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(themeTint(selectedTheme))
                    .frame(width: 40, height: 40)
                    .background(themeTint(selectedTheme).opacity(0.11), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Prompt pool")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedTheme.rawValue)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("timedPractice.themeMenu")
        .accessibilityLabel("Prompt pool, \(selectedTheme.rawValue)")
    }

    @available(iOS 17.0, *)
    private func cameraSetupPreview(session: AVCaptureSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "video.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.pink)
                Text("Camera preview")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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

    private var settingsCard: some View {
        ImpromptuSettingsPanel(
            keepPromptVisible: $keepPromptVisible,
            timerDisplay: Binding(get: { timerDisplay }, set: { timerDisplay = $0 }),
            enableThinkingTime: $enableThinkingTime,
            showLiveTranscript: $showLiveTranscript,
            showFillerWords: $showFillerWords,
            enableVideoRecording: $enableVideoRecording,
            showPaywall: $showPaywall,
            premium: premium,
            videoManager: videoManager
        )
    }

    private var thinDivider: some View {
        Divider()
            .padding(.horizontal, 16)
    }

    private func setPromptTheme(_ theme: PromptTheme) {
        UISelectionFeedbackGenerator().selectionChanged()
        animateSetupChange {
            selectedTheme = theme
            question = ""
            discardSeededChallengeAuthority()
        }
    }

    private func animateSetupChange(_ changes: () -> Void) {
        updateWithMotion(.snappySpring, changes)
    }

    private func updateWithMotion(_ animation: Animation, _ changes: () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(animation) {
                changes()
            }
        }
    }

    private func themeTint(_ theme: PromptTheme) -> Color {
        switch theme {
        case .all: return AppColor.pro
        case .general: return AppColor.brandBlue
        case .workCareer: return AppColor.modeSuddenDeath
        case .personalStories: return AppColor.modeCrutch
        case .leadership: return Color(red: 0.78, green: 0.18, blue: 0.22)
        case .ethicsOpinions: return AppColor.modeIM
        case .funRandom: return AppColor.modeAhCounter
        case .interviewPrep: return AppColor.modePace
        case .socialConfidence: return Color(red: 0.74, green: 0.50, blue: 0.08)
        }
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
                        .accessibilityIdentifier("timedPractice.prompt")

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
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: thinkingCountdown)
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
                    .accessibilityIdentifier("timedPractice.prompt")
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
                if activeDrill == nil, let voice = coachingProfileStore.profile?.chosenStyleGoal {
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
                styleGoal: coachingProfileStore.profile?.chosenStyleGoal
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
            Text("Pressure on")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
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
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: elapsedSeconds)
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
                if effectiveKeepPromptVisible {
                    Text(question)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .accessibilityIdentifier("timedPractice.prompt")
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
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: elapsedSeconds)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)

            // Optional prompt — styled as subtle card
            if effectiveKeepPromptVisible {
                HStack(spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(question)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("timedPractice.prompt")
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
                    if reduceMotion {
                        proxy.scrollTo("transcriptEnd", anchor: .bottom)
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("transcriptEnd", anchor: .bottom)
                        }
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
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: timingState)

                Spacer(minLength: 16)

                // Prompt pill (if visible)
                if effectiveKeepPromptVisible {
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
            timingPolicy: timingPolicy,
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
                .accessibilityIdentifier("timedPractice.prompt")
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
                ForEach(timingPolicy.milestones) { milestone in
                    timingSegment(
                        active: elapsedSeconds >= milestone.seconds,
                        state: milestone.state,
                        label: formattedTime(milestone.seconds)
                    )
                }
            }
            .padding(.horizontal, 16)

            if showLiveTranscript {
                Text(timingState.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(timingState == .neutral ? .secondary : timingState.color)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: timingState)
            }
        }
    }

    private func timingSegment(active: Bool, state: ImpromptuTimingState, label: String) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3)
                .fill(active ? state.color : Color(.systemGray5))
                .frame(height: 6)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: active)
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
                .accessibilityIdentifier("timedPractice.prompt")
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
            setupStartAction
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    private var setupStartAction: some View {
        let isTargetedRetry = targetedRetryPresentation != nil
        return Button(action: { beginSession() }) {
            HStack(spacing: 10) {
                if !isTargetedRetry {
                    Image(systemName: "bolt.fill")
                        .font(.headline)
                        .accessibilityHidden(true)
                }
                Text(isTargetedRetry ? "Start targeted retry" : "Start Timed Practice")
                    .font(Typography.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, Spacing.md)
        }
        .background(
            isTargetedRetry ? AppColor.pro : Color.white,
            in: Capsule()
        )
        .foregroundStyle(isTargetedRetry ? Color.white : AppColor.modeTimed)
        .shadow(
            color: Color.black.opacity(isTargetedRetry ? 0.10 : 0.18),
            radius: 18,
            y: 8
        )
        .buttonStyle(.pressable)
        .accessibilityIdentifier("timedPractice.begin")
        .accessibilityHint(
            isTargetedRetry
                ? "Starts a retry using the same prompt and target"
                : "Starts Timed Practice"
        )
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
        let hasRecordingIssue = speechVM.connectionError != nil

        return Group {
            if hasRecordingIssue {
                // Startup and interruption failures own their recovery action
                // in `recordingIssueCard`; the normal stop action has no live
                // recording to end and would otherwise be a dead control.
                Color.clear.frame(height: 0)
            } else if isCamera {
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

    private func enforcePremiumFeatureAvailability() {
        guard !premium.isPremium else { return }
        if showLiveTranscript {
            showLiveTranscript = false
        }
        if showFillerWords {
            showFillerWords = false
        }
        if enableVideoRecording {
            enableVideoRecording = false
            videoManager.cleanup()
        }
    }

    // MARK: - Actions

    private func requestMicrophoneAccess() {
        Task {
            _ = await speechVM.requestMicrophoneAccessForPractice()
        }
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
        #endif
    }

    private func prepareMicrophoneForLaunch() async -> Bool {
        speechVM.refreshRecordPermission()
        if speechVM.microphonePermissionState == .undetermined {
            return await speechVM.requestMicrophoneAccessForPractice()
        }
        if speechVM.microphonePermissionState.blocksRecording {
            speechVM.connectionError = speechVM.microphonePermissionState.userFacingRecoveryMessage
            return false
        }
        speechVM.connectionError = nil
        return true
    }

    private func retryRecordingAfterIssue() {
        speechVM.connectionError = nil
        speechVM.refreshRecordPermission()
        if speechVM.microphonePermissionState == .denied {
            openAppSettings()
            return
        }
        startSpeaking()
    }

    private func returnToSetupAfterRecordingIssue() {
        cleanup()
        resetState(keepPrompt: true)
    }

    private func beginSession() {
        guard phase == .setup else { return }
        enforcePremiumFeatureAvailability()

        // Haptic feedback for session start fires before the AI hop so the
        // tap feels immediate even if prompt selection takes a beat.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if usesInjectedFirstValueLoop {
            if speechProject == nil {
                question = "Brief the team on a customer handoff risk."
            }
            if ttsEngine.delegate == nil { configureTTSDelegate() }
            phase = .speaking
            elapsedSeconds = 0
            isStopping = false
            completeInjectedFirstValueLoopRep()
            return
        }

        // Resolve the prompt asynchronously — gives PracticeTopics.next() a
        // budget to attempt an AI-generated prompt without blocking. Falls
        // back to the curated pool on timeout/failure (≤ 3s).
        Task { @MainActor in
            guard await prepareMicrophoneForLaunch() else { return }

            // Pre-rep ambience starts only after microphone readiness is
            // known; otherwise a denied permission can feel like a rep began.
            SoundscapeEngine.shared.startPreferredMode()

            if question.isEmpty {
                question = await nextPrompt()
            }

            // Ensure TTS is ready (may already be prewarmed from onAppear)
            if ttsEngine.delegate == nil { configureTTSDelegate() }

            // Pressure mode halves thinking time for increased challenge.
            let useThinkingTime = effectiveThinkingTime
            let thinkingDuration = practiceSettings.pressureModeEnabled ? 8 : 15

            if useThinkingTime {
                thinkingCountdown = thinkingDuration
                updateWithMotion(.easeInOut(duration: 0.3)) { phase = .thinking }
                startThinkingCountdown(thinkingDuration: thinkingDuration)
            } else if !effectiveKeepPromptVisible {
                updateWithMotion(.easeInOut(duration: 0.3)) { phase = .briefReveal }
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
                    updateWithMotion(.snappy(duration: 0.25)) { thinkingCountdown = i }
                }
                try? await Task.sleep(for: .seconds(1))
            }
            if Task.isCancelled { return }
            await MainActor.run {
                updateWithMotion(.snappy(duration: 0.25)) { thinkingCountdown = 0 }
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
        guard !speechVM.recordingLifecycle.isBusy else { return }
        speechVM.refreshRecordPermission()
        if speechVM.microphonePermissionState == .undetermined {
            Task { @MainActor in
                if await speechVM.requestMicrophoneAccessForPractice() {
                    startSpeaking()
                } else {
                    SoundscapeEngine.shared.stop()
                    thinkingTask?.cancel()
                    thinkingTask = nil
                    updateWithMotion(.easeInOut(duration: 0.25)) { phase = .setup }
                }
            }
            return
        }
        if speechVM.microphonePermissionState.blocksRecording {
            speechVM.connectionError = speechVM.microphonePermissionState.userFacingRecoveryMessage
            SoundscapeEngine.shared.stop()
            thinkingTask?.cancel()
            thinkingTask = nil
            updateWithMotion(.easeInOut(duration: 0.25)) { phase = .setup }
            return
        }

        // Cut pre-rep ambience the moment the rep starts — soundscape
        // is for prep only, never for the rep itself.
        SoundscapeEngine.shared.stop()

        updateWithMotion(.easeInOut(duration: 0.3)) { phase = .speaking }

        elapsedSeconds = 0
        isStopping = false
        activeTimedDifficulty = prescribedTimedDifficulty ?? practiceSettings.timedDifficulty
        lastMilestoneState = .neutral
        milestoneScale = 1.0

        if usesInjectedFirstValueLoop {
            speakingTask?.cancel()
            speakingTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                completeInjectedFirstValueLoopRep()
            }
            return
        }

        speechVM.sessionPrompt = question
        let observationIntent = seededPromptPayload?.observationIntent(
            matchingDisplayedPrompt: question,
            activeAccountID: AuthManager.shared.currentAccountID
        )
        speechVM.prepareSession(
            mode: .timed,
            practiceDemand: .timed(
                difficulty: activeTimedDifficulty ?? practiceSettings.timedDifficulty,
                speechProjectID: speechProject?.id
            ),
            competitiveObservationIntent: observationIntent
        )
        Task { @MainActor in
            guard await speechVM.startRecordingAwaitingReadiness() else {
                speakingTask?.cancel()
                speakingTask = nil
                return
            }

            // Camera capture and the speaking clock begin only after the mic
            // and transcription provider are both live.
            if enableVideoRecording {
                var cameraReady = videoManager.captureSession != nil
                if videoManager.captureSession == nil {
                    let hasPermission = await VideoRecordingManager.requestCameraPermission()
                    if hasPermission {
                        cameraReady = await videoManager.prepareSession()
                    }
                }
                if cameraReady {
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
                        if let automaticStop = timingPolicy.automaticStopSeconds,
                           elapsedSeconds >= automaticStop {
                            stopSession()
                        }
                    }
                }
            }
        }
    }

    private func completeInjectedFirstValueLoopRep() {
        guard usesInjectedFirstValueLoop, !isStopping else { return }

        SoundscapeEngine.shared.stop()
        isStopping = true
        speakingTask?.cancel()
        speakingTask = nil
        elapsedSeconds = 46
        currentTimingState = timingPolicy.state(for: elapsedSeconds)

        let transcript: String
        if usesInjectedTranscriptRetryImprovement,
           seededPromptPayload?.transcriptPracticeIntent != nil {
            transcript = """
            The release should start next week because the support team has time to prepare. The customer message needs one clear decision.
            """
        } else {
            transcript = """
            I would start by naming the decision clearly. The team needs one owner for the customer handoff, then a weekly check on risk. I would tell the client what changed, what stays on track, and exactly when they will hear from us again.
            """
        }
        let duration: TimeInterval = 46
        let fillerCount = FillerWordDetector.count(in: transcript)
        let result = PracticeEvaluator.evaluateTimedPractice(
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            difficulty: activeTimedDifficulty ?? practiceSettings.timedDifficulty,
            recentSessions: sessionStore.sessions,
            profile: coachingProfileStore.profile,
            question: question.isEmpty ? nil : question,
            durationTarget: speechProject?.timedDurationTarget
        )
        evaluation = result

        let pressureOn = practiceSettings.pressureModeEnabled
        let pressure = BaselineEngine.classifyPressure(
            mode: .timed,
            difficulty: (activeTimedDifficulty ?? practiceSettings.timedDifficulty).rawValue,
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
                isRated: pressureOn,
                practiceDemand: .timed(
                    difficulty: activeTimedDifficulty ?? practiceSettings.timedDifficulty,
                    speechProjectID: speechProject?.id
                )
            ),
            annotation: PracticeSessionAnnotation(
                score: result.score,
                xpEarned: result.xpEarned,
                headline: result.headline,
                insights: result.insights,
                coachSummary: result.feedback,
                prompt: question,
                theme: selectedTheme,
                categoryRatings: result.categories.persistedCategoryRatings
            )
        )
        if let scopedSession = sessionStore.accountScopedSession(id: finalized.id) {
            _ = AutoGuidedFirstRep.reconcileQualifiedCompletion(
                scopedSession: scopedSession
            )
        }
        RecommendationLearningStore.shared.recordOutcome(
            for: finalized,
            previousSessions: Array(sessionStore.sessions.dropFirst())
        )
        pushInjectedSummary(
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            result: result,
            finalizedSessionID: finalized.id
        )
    }

    private func pushInjectedSummary(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        result: PracticeEvaluation,
        finalizedSessionID: UUID
    ) {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: AttributedString(transcript),
            fillerCount: fillerCount,
            duration: duration,
            score: result.score,
            progressSegments: progressSegments,
            xpEarned: result.xpEarned,
            finalizedSessionID: finalizedSessionID,
            committedFinalization: nil,
            suddenDeathGamePoints: nil,
            suddenDeathMultiplierLabels: [],
            suddenDeathTotalWords: nil,
            showDuration: false,
            practiceTitle: speechProject?.title ?? PracticeMode.timed.displayLabel,
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

    private func stopSession() {
        guard !isStopping else { return }
        isStopping = true
        speakingTask?.cancel()
        speakingTask = nil
        if videoManager.isRecording { videoManager.stopRecording() }

        Task { @MainActor in
            let completion = await speechVM.stopRecordingAwaitingFinalization()
            // Wait for video recording delegate to finish writing the file
            // The delegate publishes an explicit terminal state when the file is ready or failed.
            if enableVideoRecording {
                _ = await videoManager.waitForRecordingFinalization()
            }

            guard RecordingCompletionGate.allowsScoringAndProgress(completion) else {
                isStopping = false
                return
            }
            CoachHaptic.sessionComplete()
            let result = PracticeEvaluator.evaluateTimedPractice(
                transcript: speechVM.transcribedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                difficulty: activeTimedDifficulty ?? practiceSettings.timedDifficulty,
                recentSessions: speechVM.pastSessions,
                profile: coachingProfileStore.profile,
                question: question.isEmpty ? nil : question,
                durationTarget: speechProject?.timedDurationTarget
            )
            evaluation = result
            let savedSessionID = speechVM.annotateLatestSession(
                score: result.score,
                xpEarned: result.xpEarned,
                headline: result.headline,
                insights: result.insights,
                coachSummary: result.feedback,
                prompt: question,
                theme: selectedTheme,
                categoryRatings: result.categories.persistedCategoryRatings
            )
            if let savedSessionID,
               let scopedSession = sessionStore.accountScopedSession(id: savedSessionID) {
                _ = AutoGuidedFirstRep.reconcileQualifiedCompletion(
                    scopedSession: scopedSession
                )
            }
            if let savedSessionID,
               let promptHandoffToken,
               seededPromptPayload?.competitiveObservationIntent?.challengeID != nil {
                _ = ChallengesManager.shared.bindArmedSubmission(
                    matchingRouteToken: promptHandoffToken,
                    sessionID: savedSessionID,
                    sessionPrompt: question
                )
            }

            // Celebration haptic for good scores
            if result.score >= 70 {
                let gen = UINotificationFeedbackGenerator()
                gen.prepare()
                gen.notificationOccurred(.success)
                updateWithMotion(.bouncySpring) {
                    showCelebration = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    updateWithMotion(.easeOut(duration: 0.5)) { showCelebration = false }
                }
            }

            pushSummary(finalizedSessionID: savedSessionID)
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
        discardSeededChallengeAuthority()
        resetState(keepPrompt: false)
        Task { @MainActor in
            question = await nextPrompt()
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
        // The instant-start one-shot applies to the auto-guided FIRST rep only.
        // A retry / new-prompt rep in the same view must fall back to the user's
        // persistent prep-countdown / prompt prefs — never inherit fast-start.
        fastStartActive = false
        // Don't reset phase yet — launchSessionFlow will set it
        phase = .setup
    }

    /// Shared logic for starting a session from retry/new prompt flows.
    /// Bypasses the setup page guard in beginSession().
    private func launchSessionFlow() {
        if ttsEngine.delegate == nil { configureTTSDelegate() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        enforcePremiumFeatureAvailability()
        let useThinkingTime = effectiveThinkingTime
        let thinkingDuration = practiceSettings.pressureModeEnabled ? 8 : 15
        if useThinkingTime {
            thinkingCountdown = thinkingDuration
            updateWithMotion(.easeInOut(duration: 0.3)) { phase = .thinking }
            // Pre-rep ambience runs through the thinking window — long
            // enough for the user to feel it, cuts the moment recording
            // starts inside `startSpeaking()` so it never bleeds onto the
            // rep itself.
            SoundscapeEngine.shared.startPreferredMode()
            startThinkingCountdown(thinkingDuration: thinkingDuration)
        } else if !effectiveKeepPromptVisible {
            updateWithMotion(.easeInOut(duration: 0.3)) { phase = .briefReveal }
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
        speechVM.cancelRecording()
    }

    // MARK: - Navigation

    private func pushSummary(finalizedSessionID: UUID?) {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: speechVM.highlightedText,
            fillerCount: speechVM.fillerWordCount,
            duration: speechVM.lastSessionDuration,
            score: evaluation?.score,
            progressSegments: progressSegments,
            xpEarned: evaluation?.xpEarned ?? 0,
            finalizedSessionID: finalizedSessionID,
            committedFinalization: nil,
            suddenDeathGamePoints: nil,
            suddenDeathMultiplierLabels: [],
            suddenDeathTotalWords: nil,
            showDuration: false,
            practiceTitle: PracticeMode.timed.displayLabel,
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
            targetRange: evaluation?.targetRange
                ?? activeTimedDifficulty?.targetRange
                ?? prescribedTimedDifficulty?.targetRange
                ?? practiceSettings.timedDifficulty.targetRange,
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
