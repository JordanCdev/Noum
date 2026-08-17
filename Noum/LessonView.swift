#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Lesson View
//
// Interactive step-by-step lesson runner.
//
// The shape is a compact teaching runner:
// - Top: thin step-progress bar.
// - Middle: the active step (concept / spot-it / apply).
// - Bottom: a single primary CTA that adapts to the step
//   ("Got it" -> "Check" -> "Speak now" -> "Continue").
//
// On completion, a `LessonOutcome` is produced and handed to `LessonStore`.
// The store decides whether practice-pass progress rises and surfaces the
// celebration.

@available(iOS 17.0, macOS 12.0, *)
struct LessonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var lessonStore = LessonStore.shared
    @StateObject private var profileManager = ProfileManager.shared
    /// Real speech capture for the Apply step. Lessons don't write to the
    /// session history (`shouldRecordPracticeSession = false`); they're a
    /// teaching exercise, not a session.
    @StateObject private var speech = SpeechRecognizerViewModel()

    let lesson: Lesson
    @Binding var navigationPath: NavigationPath

    @State private var currentStep: Int = 0
    @State private var spotItSelection: Int? = nil
    @State private var spotItRevealed: Bool = false
    @State private var stepResults: [LessonOutcome.StepResult] = []
    @State private var applyPhase: ApplyPhase = .ready
    @State private var applyTranscript: String = ""
    @State private var applyFindings: [EloquenceFinding] = []
    @State private var applyEvaluation: LessonApplyEvaluation?
    @State private var applyEvidence: LessonApplyCompletionEvidence?
    @State private var applyRetryMessage: String?
    @State private var applyElapsed: TimeInterval = 0
    @State private var applyTimer: Timer?
    @State private var applyLifecycleTask: Task<Void, Never>?
    @State private var applyStart: Date?
    @State private var didShowSummary: Bool = false
    @State private var progressUpdate: LessonProgressUpdate?
    @State private var didInstallApplyCompletionFixture = false
    @State private var showCloudProcessingConsent = false

    init(lesson: Lesson, navigationPath: Binding<NavigationPath>) {
        self.lesson = lesson
        self._navigationPath = navigationPath
    }

    init(lesson: Lesson) {
        self.lesson = lesson
        self._navigationPath = .constant(NavigationPath())
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                progressBar
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, Spacing.sm)

                if didShowSummary {
                    ScrollView(showsIndicators: false) {
                        lessonSummary
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.top, Spacing.lg)
                            .padding(.bottom, Spacing.xl)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            lessonHeader
                            stepCard
                            Spacer(minLength: 60)
                        }
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .transcriptionRouteNotice(speech.transcriptionRouteNotice)
        .sheet(isPresented: $showCloudProcessingConsent) {
            CloudProcessingConsentDisclosure(
                isCurrentlyAllowed: AISettingsManager.shared.isCloudProcessingAllowed,
                onAllow: {
                    AISettingsManager.shared.recordCloudProcessingDecision(.allowed)
                    showCloudProcessingConsent = false
                    speech.connectionError = nil
                },
                onNotNow: {
                    AISettingsManager.shared.recordCloudProcessingDecision(.declined)
                    showCloudProcessingConsent = false
                }
            )
        }
        .task {
            installApplyCompletionFixtureIfNeeded()
        }
        .onDisappear {
            applyTimer?.invalidate()
            applyLifecycleTask?.cancel()
            if speech.recordingLifecycle.isBusy {
                speech.cancelRecording()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close lesson")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !didShowSummary {
                primaryCTA
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 12)
                    .background(
                        AppColor.cardBackground
                            .shadow(.drop(color: .black.opacity(0.06), radius: 12, y: -4))
                    )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lesson.screen")
    }

    // MARK: - Progress

    private var progressBar: some View {
        let completedSteps = didShowSummary ? lesson.steps.count : currentStep
        return NoumProgressTrack(
            value: lesson.steps.isEmpty ? 0 : Double(completedSteps) / Double(lesson.steps.count),
            label: didShowSummary ? "Lesson complete" : "Step \(currentStep + 1) of \(lesson.steps.count)",
            valueLabel: "\(completedSteps) of \(lesson.steps.count) complete",
            tint: lessonHeroTint
        )
    }

    // MARK: - Header

    private var lessonHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.md) {
                NoumWaveformMark(
                    state: lessonWaveformState,
                    level: speech.audioLevel,
                    tint: lessonHeroTint,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.category.label.uppercased())
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(lessonHeroTint)
                        .tracking(0.8)
                    Text(lesson.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(AppColor.textPrimary)
                }
            }

            Text(lesson.tagline)
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lessonWaveformState: NoumWaveformState {
        if didShowSummary { return .earned }
        switch applyPhase {
        case .recording: return .listening
        case .connecting, .evaluating: return .processing
        case .ready, .done: return .idle
        }
    }

    /// Tint per lesson category. Delivery reads as the Ah-Counter green
    /// (pacing + filler control share that register), Structure reads as
    /// brand-blue (Timed mode — structured thinking), Rhetoric reads as Pro
    /// purple (the eloquence layer).
    private var lessonHeroTint: Color {
        switch lesson.category {
        case .delivery:  return AppColor.modeAhCounter
        case .structure: return AppColor.brandBlue
        case .interaction: return AppColor.modeIM
        case .explanation: return AppColor.positive
        case .rhetoric:  return AppColor.pro
        }
    }

    // MARK: - Step card (dispatch on type)

    @ViewBuilder
    private var stepCard: some View {
        let step = lesson.steps[currentStep]
        switch step {
        case .concept(let headline, let body, let example):
            conceptCard(headline: headline, body: body, example: example)
        case .spotIt(let question, let options):
            spotItCard(question: question, options: options)
        case .apply(let prompt, _, let durationTarget):
            applyCard(prompt: reviewPrompt(fallback: prompt), durationTarget: durationTarget)
        }
    }

    // MARK: - Concept

    private func conceptCard(headline: String, body: String, example: String?) -> some View {
        NoumSurface(.standard) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("LEARN THE MOVE")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(lessonHeroTint)
                    .tracking(0.7)
                Text(headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Text(body)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let example {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("EXAMPLE")
                            .font(Typography.captionSmall.weight(.bold))
                            .foregroundStyle(AppColor.textSecondary)
                            .tracking(0.7)
                        Text("\u{201C}\(example)\u{201D}")
                            .font(Typography.body)
                            .foregroundStyle(lessonHeroTint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
            }
        }
    }

    // MARK: - Spot-it

    private func spotItCard(question: String, options: [Lesson.Step.Option]) -> some View {
        NoumSurface(.standard) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("SPOT THE MOVE")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(lessonHeroTint)
                    .tracking(0.7)

                Text(question)
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)

                VStack(spacing: Spacing.sm) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        spotItRow(index: index, option: option)
                    }
                }

                if spotItRevealed, let chosen = spotItSelection {
                    explanation(for: options[chosen])
                }
            }
        }
    }

    private func spotItRow(index: Int, option: Lesson.Step.Option) -> some View {
        let isSelected = spotItSelection == index
        let isRevealedCorrect = spotItRevealed && option.isCorrect
        let isRevealedWrong = spotItRevealed && isSelected && !option.isCorrect

        return Button {
            guard !spotItRevealed else { return }
            spotItSelection = index
            CoachHaptic.selectionTap()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: spotItRowIcon(isSelected: isSelected,
                                                isRevealedCorrect: isRevealedCorrect,
                                                isRevealedWrong: isRevealedWrong))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(spotItRowIconTint(isSelected: isSelected,
                                                       isRevealedCorrect: isRevealedCorrect,
                                                       isRevealedWrong: isRevealedWrong))
                    .frame(width: 22)
                Text(option.text)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                spotItRowBackground(
                    isSelected: isSelected,
                    isRevealedCorrect: isRevealedCorrect,
                    isRevealedWrong: isRevealedWrong
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(spotItRowBorder(isSelected: isSelected,
                                            isRevealedCorrect: isRevealedCorrect,
                                            isRevealedWrong: isRevealedWrong),
                            lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
        .disabled(spotItRevealed)
    }

    private func spotItRowIcon(isSelected: Bool, isRevealedCorrect: Bool, isRevealedWrong: Bool) -> String {
        if isRevealedCorrect { return "checkmark.circle.fill" }
        if isRevealedWrong { return "xmark.circle.fill" }
        if isSelected { return "circle.inset.filled" }
        return "circle"
    }

    private func spotItRowIconTint(isSelected: Bool, isRevealedCorrect: Bool, isRevealedWrong: Bool) -> Color {
        if isRevealedCorrect { return AppColor.positive }
        if isRevealedWrong { return AppColor.warning }
        if isSelected { return lessonHeroTint }
        return Color.secondary.opacity(0.5)
    }

    @ViewBuilder
    private func spotItRowBackground(isSelected: Bool, isRevealedCorrect: Bool, isRevealedWrong: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        if isRevealedCorrect {
            shape.fill(AppColor.positive.opacity(0.10))
        } else if isRevealedWrong {
            shape.fill(AppColor.warning.opacity(0.10))
        } else if isSelected {
            shape.fill(lessonHeroTint.opacity(0.06))
        } else {
            shape.fill(AppColor.cardBackground)
        }
    }

    private func spotItRowBorder(isSelected: Bool, isRevealedCorrect: Bool, isRevealedWrong: Bool) -> Color {
        if isRevealedCorrect { return AppColor.positive.opacity(0.4) }
        if isRevealedWrong { return AppColor.warning.opacity(0.4) }
        if isSelected { return lessonHeroTint.opacity(0.32) }
        return AppColor.subtleBorder
    }

    private func explanation(for option: Lesson.Step.Option) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: option.isCorrect ? "lightbulb.fill" : "info.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(option.isCorrect ? AppColor.positive : lessonHeroTint)
            Text(option.explanation)
                .font(Typography.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Apply

    enum ApplyPhase { case ready, connecting, recording, evaluating, done }

    private func applyCard(prompt: String, durationTarget: TimeInterval) -> some View {
        NoumSurface(.standard) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("PROVE THE MOVE")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(lessonHeroTint)
                    .tracking(0.7)

                Text("Speak the answer")
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)

                Text(prompt)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "timer")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.textSecondary)
                    Text(timerLabel(target: durationTarget))
                        .font(Typography.caption.monospacedDigit())
                        .foregroundStyle(applyPhase == .recording ? lessonHeroTint : AppColor.textSecondary)
                    Spacer()
                    phaseTrailingIndicator
                }

                if applyPhase == .recording {
                    liveMicBlock
                }

                if applyPhase == .ready, let error = speech.connectionError {
                    applyRecordingIssueCard(error)
                }

                if applyPhase == .ready, let applyRetryMessage {
                    Label(applyRetryMessage, systemImage: "arrow.counterclockwise.circle.fill")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.caution)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("lesson.apply.insufficientSpeech")
                }

                if applyPhase == .done {
                    applyResultBlock
                }
            }
        }
    }

    /// Live "Listening…" indicator with a partial transcript while the
    /// user is speaking. Honest — we surface what the engine is hearing,
    /// not a confirmation animation that fires whether the mic is open or
    /// not.
    private var liveMicBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: Spacing.sm) {
                NoumWaveformMark(
                    state: .listening,
                    level: speech.audioLevel,
                    tint: lessonHeroTint,
                    size: 36
                )
                Text("Listening to your answer")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(lessonHeroTint)
                if let error = speech.connectionError {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.warning)
                        .lineLimit(1)
                }
            }
            if !speech.transcribedText.isEmpty {
                Text(speech.transcribedText)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Speak to begin — pauses are fine.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    /// Trailing indicator on the timer row — shows the appropriate state
    /// (recording dot, evaluating spinner, success/miss after .done).
    @ViewBuilder
    private var phaseTrailingIndicator: some View {
        switch applyPhase {
        case .connecting:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7)
                Text("Connecting")
                    .font(Typography.caption.weight(.semibold))
            }
            .foregroundStyle(lessonHeroTint)
        case .recording:
            HStack(spacing: 4) {
                Circle()
                    .fill(AppColor.warning)
                    .frame(width: 8, height: 8)
                Text("REC")
                    .font(Typography.micro)
                    .foregroundStyle(AppColor.warning)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
        case .evaluating:
            ProgressView().scaleEffect(0.7)
        case .done:
            if applyEvaluation?.passed == true {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Skill shown")
                }
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.positive)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("Try once more")
                }
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.caution)
            }
        case .ready:
            EmptyView()
        }
    }

    private func timerLabel(target: TimeInterval) -> String {
        switch applyPhase {
        case .ready:
            return "Target: \(Int(target))s"
        case .connecting:
            return "Waiting for transcription"
        case .recording:
            let remaining = max(0, Int(target - applyElapsed))
            return remaining > 0 ? "\(remaining)s left" : "Over target"
        case .evaluating, .done:
            return "Spoke for \(Int(applyElapsed))s"
        }
    }

    private var applyResultBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !applyTranscript.isEmpty {
                Text("What you said")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text("\u{201C}\(applyTranscript.prefix(220))\u{201D}")
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !applyFindings.isEmpty {
                let titles = applyFindings.map(\.device.title).joined(separator: ", ")
                Text("Found: \(titles)")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.positive)
            }
            if let evaluation = applyEvaluation {
                Divider()
                    .padding(.vertical, 4)
                ForEach(evaluation.results) { result in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: result.passed ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(result.passed ? AppColor.positive : AppColor.caution)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(Typography.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(result.feedback)
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(result.title). \(result.passed ? "Met" : "Try again"). \(result.feedback)")
                    .accessibilityIdentifier("lesson.apply.criterion.\(result.criterionID)")
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lesson.apply.result")
    }

    private var applyExpectedDevice: EloquenceDevice? {
        guard case .apply(_, let device, _) = lesson.steps[currentStep] else { return nil }
        return device
    }

    private var applyRecordingIssuePresentation: SpeechRecordingIssuePresentation? {
        guard let error = speech.connectionError else { return nil }
        return SpeechRecordingIssuePresentation.make(
            issue: speech.recordingIssue,
            message: error
        )
    }

    private func applyRecordingIssueCard(_ message: String) -> some View {
        let presentation = SpeechRecordingIssuePresentation.make(
            issue: speech.recordingIssue,
            message: message
        )

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(presentation.title, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.caution)
            Text(presentation.detail)
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.caution.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .accessibilityIdentifier("lesson.apply.captureError")
    }

    // MARK: - Primary CTA (dispatches by step)

    @ViewBuilder
    private var primaryCTA: some View {
        switch lesson.steps[currentStep] {
        case .concept:
            ctaButton(title: "Got it", action: advance)
        case .spotIt:
            if spotItRevealed {
                ctaButton(title: "Continue", action: advance)
            } else {
                ctaButton(title: "Check", enabled: spotItSelection != nil, action: revealSpotIt)
            }
        case .apply:
            switch applyPhase {
            case .ready:
                if let recovery = applyRecordingIssuePresentation?.recovery {
                    switch recovery {
                    case .retry:
                        ctaButton(title: "Try connection again", action: startApply)
                    case .grantCloudConsent:
                        ctaButton(title: "Turn on cloud processing") {
                            showCloudProcessingConsent = true
                        }
                    case .openSettings:
                        ctaButton(title: "Open Settings", action: openAppSettingsAfterApplyIssue)
                    case .leaveRep:
                        ctaButton(title: "Back to lessons", action: leaveLesson)
                    }
                } else {
                    ctaButton(title: "Speak now", action: startApply)
                }
            case .connecting:
                ctaButton(title: "Connecting…", enabled: false, action: {})
            case .recording:
                ctaButton(title: "Stop", action: stopApply)
            case .evaluating:
                ctaButton(title: "Evaluating…", enabled: false, action: {})
            case .done:
                if applyEvaluation?.passed == true {
                    ctaButton(title: "Continue", action: advance)
                } else {
                    ctaButton(title: "Try again", action: resetApplyForRetry)
                }
            }
        }
    }

    private func ctaButton(title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .noumMinimumTouchTarget()
                .padding(.vertical, Spacing.xs)
                .background(
                    enabled ? AppColor.coachingInk : Color.secondary.opacity(0.4),
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
        .accessibilityIdentifier("lesson.cta")
    }

    private func openAppSettingsAfterApplyIssue() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        speech.connectionError = nil
        openURL(url)
        #endif
    }

    private func leaveLesson() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        } else {
            dismiss()
        }
    }

    // MARK: - Step transitions

    private func revealSpotIt() {
        guard case .spotIt(_, let options) = lesson.steps[currentStep],
              let choice = spotItSelection else { return }
        spotItRevealed = true
        let passed = options[choice].isCorrect
        stepResults.append(.spotIt(passed: passed))
        if passed {
            CoachHaptic.trendBreakthrough()
        } else {
            CoachHaptic.selectionTap()
        }
    }

    /// Begin real microphone capture. Lessons don't get logged to the
    /// session history — they're teaching, not practice — so we set
    /// `shouldRecordPracticeSession = false` before kicking off.
    private func startApply() {
        guard applyPhase == .ready else { return }
        applyPhase = .connecting
        applyTranscript = ""
        applyFindings = []
        applyEvaluation = nil
        applyEvidence = nil
        applyRetryMessage = nil
        applyElapsed = 0
        applyStart = nil
        speech.connectionError = nil

        speech.shouldRecordPracticeSession = false
        speech.sessionPrompt = applyPrompt
        speech.prepareSession(mode: .timed)

        applyLifecycleTask?.cancel()
        applyLifecycleTask = Task { @MainActor in
            let captureReady = await speech.startRecordingAwaitingReadiness()
            guard !Task.isCancelled,
                  applyPhase == .connecting,
                  RecordingStartGate.allowsTimerStart(captureReady: captureReady) else {
                if applyPhase == .connecting {
                    applyPhase = .ready
                }
                return
            }
            beginApplyTimer()
        }
    }

    private func beginApplyTimer() {
        applyPhase = .recording
        applyStart = Date()

        // Auto-stop once the user hits 1.5× the target duration so a
        // forgotten Stop tap doesn't leave the mic open indefinitely.
        let durationCap = applyDurationTarget * 1.5
        applyTimer?.invalidate()
        applyTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in
                guard let start = applyStart else { return }
                applyElapsed = Date().timeIntervalSince(start)
                if applyElapsed >= durationCap { stopApply() }
            }
        }
    }

    /// Stop capture, run the eloquence pass on the real transcript, and
    /// transition to `.done`. Pulls the latest transcript directly from
    /// the speech model instead of waiting for the persisted session
    /// (which the lesson explicitly skips).
    private func stopApply() {
        guard applyPhase == .recording else { return }
        applyTimer?.invalidate()
        applyTimer = nil
        applyPhase = .evaluating
        if let start = applyStart {
            applyElapsed = Date().timeIntervalSince(start)
        }

        applyLifecycleTask?.cancel()
        applyLifecycleTask = Task { @MainActor in
            let completion = await speech.stopRecordingAwaitingFinalization()
            guard !Task.isCancelled else { return }
            consumeApplyCompletion(
                completion: completion,
                recorderDuration: speech.lastSessionDuration
            )
        }
    }

    private func consumeApplyCompletion(
        completion: FinalizedTranscript?,
        recorderDuration: TimeInterval
    ) {
        let terminalText = completion?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let terminalFindings = terminalText.isEmpty
            ? []
            : EloquenceEngine.analyse(transcript: terminalText)
        let disposition = LessonApplyCompletionDisposition.resolve(
            completion: completion,
            recorderDuration: recorderDuration,
            findings: terminalFindings,
            lesson: lesson
        )

        switch disposition {
        case .unusableRecording:
            applyEvidence = nil
            applyStart = nil
            applyPhase = .ready
        case .insufficientDuration(let required):
            applyEvidence = nil
            applyStart = nil
            applyPhase = .ready
            applyRetryMessage = "Speak for at least \(Int(required)) seconds so Noum can assess the move fairly."
        case .evaluated(let transcript, let evaluation, let evidence):
            applyTranscript = transcript
            applyFindings = terminalFindings
            applyEvaluation = evaluation
            applyEvidence = evidence
            applyElapsed = recorderDuration
            applyStart = nil
            applyPhase = .done

            stepResults.removeAll(where: { $0.kind == .apply })
            guard let evidence,
                  evidence.isVerified(for: lesson) else {
                return
            }

            let didUseDevice = applyExpectedDevice.map { expected in
                terminalFindings.contains(where: { $0.device == expected })
            } ?? evaluation.passed
            stepResults.append(.apply(
                passed: evaluation.passed,
                didUseDevice: didUseDevice
            ))
            if evaluation.passed { CoachHaptic.trendBreakthrough() }
        }
    }

    private func installApplyCompletionFixtureIfNeeded() {
        #if DEBUG
        guard !didInstallApplyCompletionFixture,
              let fixture = ApplyCompletionFixture.current else { return }
        didInstallApplyCompletionFixture = true
        guard let applyIndex = lesson.steps.firstIndex(where: { step in
            if case .apply = step { return true }
            return false
        }) else { return }

        currentStep = applyIndex
        stepResults = [.concept, .spotIt(passed: true)]
        applyPhase = .evaluating
        consumeApplyCompletion(
            completion: fixture.completion,
            recorderDuration: fixture.recorderDuration
        )
        #endif
    }

    #if DEBUG
    private enum ApplyCompletionFixture: String {
        case keywordOnly
        case eligible

        static var current: ApplyCompletionFixture? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "UI_TESTING_LESSON_APPLY_COMPLETION_FIXTURE"),
                  arguments.indices.contains(index + 1) else {
                return nil
            }
            return ApplyCompletionFixture(rawValue: arguments[index + 1])
        }

        var completion: FinalizedTranscript {
            FinalizedTranscript(
                text: transcript,
                receivedFinalResult: true,
                audioByteCount: 4_096
            )
        }

        var recorderDuration: TimeInterval { 8 }

        private var transcript: String {
            switch self {
            case .keywordOnly:
                return "send Thursday correct"
            case .eligible:
                return "I will send the revised proposal Thursday at three p m after Finance confirms the final number. Is that correct?"
            }
        }
    }
    #endif

    private func resetApplyForRetry() {
        applyPhase = .ready
        applyTranscript = ""
        applyFindings = []
        applyEvaluation = nil
        applyEvidence = nil
        applyRetryMessage = nil
        applyElapsed = 0
        applyStart = nil
        stepResults.removeAll(where: { $0.kind == .apply })
        CoachHaptic.selectionTap()
    }

    private var applyPrompt: String {
        guard case .apply(let prompt, _, _) = lesson.steps[currentStep] else { return "" }
        return reviewPrompt(fallback: prompt)
    }

    private func reviewPrompt(fallback: String) -> String {
        let completedRounds = lessonStore.practicePassCount(for: lesson.id)
        guard completedRounds > 0, !lesson.reviewPrompts.isEmpty else { return fallback }
        let promptPool = lesson.reviewPrompts + [fallback]
        return promptPool[(completedRounds - 1) % promptPool.count]
    }

    private var applyDurationTarget: TimeInterval {
        guard case .apply(_, _, let target) = lesson.steps[currentStep] else { return 30 }
        return target
    }

    private func advance() {
        // First step (concept) gets recorded as a "concept" StepResult so
        // the outcome shape is consistent.
        if case .concept = lesson.steps[currentStep],
           !stepResults.contains(where: { $0.kind == .concept }) {
            stepResults.append(.concept)
        }

        if currentStep < lesson.steps.count - 1 {
            advanceStepState()
        } else {
            finishLesson()
        }
    }

    private func advanceStepState() {
        let update = {
            currentStep += 1
            spotItSelection = nil
            spotItRevealed = false
            applyPhase = .ready
            applyTranscript = ""
            applyFindings = []
            applyEvaluation = nil
            applyEvidence = nil
            applyRetryMessage = nil
        }
        if reduceMotion { update() }
        else {
            withAnimation(NoumMotion.animation(for: .calm, reduceMotion: false), update)
        }
    }

    private func finishLesson() {
        let outcome = LessonOutcome(
            lessonID: lesson.id,
            stepResults: stepResults,
            xpEarned: 0,
            applyEvidence: applyEvidence
        )
        let xp = LessonXP.xp(for: outcome)
        let final = LessonOutcome(
            lessonID: lesson.id,
            stepResults: stepResults,
            xpEarned: xp,
            applyEvidence: applyEvidence
        )
        // Apply mastery progress + XP accounting.
        let update = lessonStore.apply(outcome: final)
        progressUpdate = update
        if update.earnsXP {
            profileManager.addXP(xp)
        }

        if reduceMotion { didShowSummary = true }
        else {
            withAnimation(NoumMotion.animation(for: .earned, reduceMotion: false)) {
                didShowSummary = true
            }
        }
    }

    // MARK: - Summary

    private var lessonSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .center, spacing: Spacing.md) {
                NoumWaveformMark(state: .earned, tint: lessonHeroTint)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(passedHeadline)
                        .font(Typography.screenTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(lesson.title)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            NoumEvidenceCard(
                status: summaryOutcome.passed ? .verified : .needsMore,
                title: summaryOutcome.passed ? "Spoken evidence accepted" : "No practice pass added",
                detail: passedSubhead,
                source: summaryOutcome.passed
                    ? "Based on the lesson checks and final spoken rep."
                    : "Progress changes only after the lesson criteria are met."
            )

            practicePassProgress

            if progressUpdate?.earnsXP == true {
                NoumRewardPill(kind: .xp(summaryEarnedXP))
            }

            NoumSurface(.quiet) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Use it live", systemImage: "arrow.up.right")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(lessonHeroTint)
                    Text(lesson.transferPrompt)
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                leaveLesson()
            } label: {
                Text("Back to lessons")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .noumMinimumTouchTarget()
                    .padding(.vertical, Spacing.xs)
                    .background(AppColor.coachingInk, in: Capsule(style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("lesson.summary.continue")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lesson.summary")
    }

    private var summaryOutcome: LessonOutcome {
        LessonOutcome(
            lessonID: lesson.id,
            stepResults: stepResults,
            xpEarned: 0,
            applyEvidence: applyEvidence
        )
    }

    private var summaryEarnedXP: Int {
        guard progressUpdate?.earnsXP == true else { return 0 }
        return LessonXP.xp(for: summaryOutcome)
    }

    private var passedHeadline: String {
        if summaryOutcome.passed { return "Practice complete" }
        return "Keep working the move"
    }

    private var passedSubhead: String {
        if progressUpdate?.outcomePassed == true,
           progressUpdate?.didAdvanceRetention == false,
           progressUpdate?.didCompleteMaintenanceReview == false {
            return "The move landed. Its next spaced round is not due yet."
        }
        return LessonProgressPresentation(completedPasses: lessonStore.practicePassCount(for: lesson.id))
            .lessonSummaryLine(title: lesson.title)
    }

    private var practicePassProgress: some View {
        let progress = LessonProgressPresentation(completedPasses: lessonStore.practicePassCount(for: lesson.id))
        return NoumSurface(.quiet) {
            NoumProgressTrack(
                value: Double(progress.completedPasses) / Double(LessonStore.masteryPassCap),
                label: "Spaced practice rounds",
                valueLabel: progress.fractionText,
                tint: lessonHeroTint
            )
        }
        .accessibilityLabel(progress.accessibilityLabel)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Lesson — Rule of Three") {
    NavigationStack {
        LessonView(lesson: LessonsCatalog.ruleOfThree)
    }
}
#endif

#endif
