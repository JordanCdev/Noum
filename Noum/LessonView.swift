#if canImport(SwiftUI)
import SwiftUI

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
                    lessonSummary
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
        HStack(spacing: 6) {
            ForEach(0..<lesson.steps.count, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? lessonHeroTint : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Header

    /// Lesson hero — promoted from a plain HStack to a tinted hero card so
    /// it matches the M14 hero treatment used on Profile / Settings /
    /// League / Coach Card. Tint is derived from the lesson's category so
    /// Delivery / Structure / Rhetoric each carry a distinct register. The
    /// lesson's persistent tagline is inlined as the hero body — the hero
    /// is "what is this lesson about", the step cards below are the
    /// interactive surface.
    private var lessonHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(lessonHeroTint.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: lesson.symbolName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(lessonHeroTint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.category.label)
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(lesson.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Text("Step \(currentStep + 1) of \(lesson.steps.count)")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(lessonHeroTint)
            }
            Text(lesson.tagline)
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(lessonHeaderBackground)
        .shadow(color: lessonHeroTint.opacity(0.16), radius: 22, x: 0, y: 10)
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

    /// Hero chrome for the lesson header — same radial wash + tint border
    /// shape used on Profile / Settings / League. Picks the canonical
    /// `*Light` sibling for the mid gradient stop when one exists (pro,
    /// brandBlue) and falls back to the same tint at 0.22 alpha for the
    /// delivery register (no `modeAhCounterLight` is defined).
    private var lessonHeaderBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        let tint = lessonHeroTint
        let midColor: Color = {
            switch lesson.category {
            case .delivery:  return AppColor.modeAhCounter
            case .structure: return AppColor.brandBlueLight
            case .interaction: return AppColor.modeIM
            case .explanation: return AppColor.positive
            case .rhetoric:  return AppColor.proLight
            }
        }()
        return ZStack {
            shape.fill(AppColor.cardBackground)
            shape.fill(
                RadialGradient(
                    colors: [tint.opacity(0.42), midColor.opacity(0.22), tint.opacity(0.04), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 320
                )
            )
            shape.strokeBorder(tint.opacity(0.40), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 16) {
            Text(headline)
                .font(Typography.headline)
                .foregroundStyle(.primary)
            Text(body)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let example {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example")
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text("\u{201C}\(example)\u{201D}")
                        .font(Typography.body)
                        .foregroundStyle(AppColor.brandBlue)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.brandBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    // MARK: - Spot-it

    private func spotItCard(question: String, options: [Lesson.Step.Option]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(question)
                .font(Typography.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    spotItRow(index: index, option: option)
                }
            }

            if spotItRevealed, let chosen = spotItSelection {
                explanation(for: options[chosen])
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
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
        if isSelected { return AppColor.brandBlue }
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
            shape.fill(AppColor.brandBlue.opacity(0.06))
        } else {
            shape.fill(AppColor.cardBackground)
        }
    }

    private func spotItRowBorder(isSelected: Bool, isRevealedCorrect: Bool, isRevealedWrong: Bool) -> Color {
        if isRevealedCorrect { return AppColor.positive.opacity(0.4) }
        if isRevealedWrong { return AppColor.warning.opacity(0.4) }
        if isSelected { return AppColor.brandBlue.opacity(0.32) }
        return Color.white.opacity(0.6)
    }

    private func explanation(for option: Lesson.Step.Option) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: option.isCorrect ? "lightbulb.fill" : "info.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(option.isCorrect ? AppColor.positive : AppColor.brandBlue)
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Speak the answer")
                .font(Typography.headline)
                .foregroundStyle(.primary)
            Text(prompt)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.brandBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(timerLabel(target: durationTarget))
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(applyPhase == .recording ? AppColor.brandBlue : .secondary)
                Spacer()
                phaseTrailingIndicator
            }

            if applyPhase == .recording {
                liveMicBlock
            }

            if applyPhase == .ready, let error = speech.connectionError {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("lesson.apply.captureError")
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
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    /// Live "Listening…" indicator with a partial transcript while the
    /// user is speaking. Honest — we surface what the engine is hearing,
    /// not a confirmation animation that fires whether the mic is open or
    /// not.
    private var liveMicBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .symbolEffect(.pulse, options: .repeating.speed(0.9), isActive: !reduceMotion)
                Text("Listening")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
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
        .background(AppColor.brandBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
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
            .foregroundStyle(AppColor.brandBlue)
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
                ctaButton(title: "Speak now", action: startApply)
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
                .padding(.vertical, 14)
                .background(
                    enabled ? AppColor.brandBlue : Color.secondary.opacity(0.4),
                    in: Capsule()
                )
        }
        .disabled(!enabled)
        .accessibilityIdentifier("lesson.cta")
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
            withAnimation(.snappySpring, update)
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
            withAnimation(.bouncySpring) {
                didShowSummary = true
            }
        }
    }

    // MARK: - Summary

    private var lessonSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: 8) {
                Text(passedHeadline)
                    .font(Typography.screenTitle)
                    .foregroundStyle(.primary)
                Text(passedSubhead)
                    .font(Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            practicePassRow

            VStack(alignment: .leading, spacing: 8) {
                Label("Use it live", systemImage: "arrow.up.right")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                Text(lesson.transferPrompt)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.brandBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            Spacer()

            Button {
                navigationPath.removeLast(navigationPath.count == 0 ? 0 : 1)
                dismiss()
            } label: {
                Text("Back to lessons")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.brandBlue, in: Capsule())
            }
            .accessibilityIdentifier("lesson.summary.continue")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lesson.summary")
    }

    private var passedHeadline: String {
        let outcome = LessonOutcome(
            lessonID: lesson.id,
            stepResults: stepResults,
            xpEarned: 0,
            applyEvidence: applyEvidence
        )
        if outcome.passed { return "Practice complete" }
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

    private var practicePassRow: some View {
        let progress = LessonProgressPresentation(completedPasses: lessonStore.practicePassCount(for: lesson.id))
        return HStack(spacing: 6) {
            ForEach(0..<LessonStore.masteryPassCap, id: \.self) { i in
                Image(systemName: i < progress.completedPasses ? "checkmark.seal.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(i < progress.completedPasses ? AppColor.brandBlue : Color.secondary.opacity(0.35))
            }
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
