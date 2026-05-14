#if canImport(SwiftUI)
import SwiftUI

// MARK: - Lesson View
//
// Interactive step-by-step lesson runner.
//
// The shape mirrors a Duolingo lesson:
// - Top: thin step-progress bar.
// - Middle: the active step (concept / spot-it / apply).
// - Bottom: a single primary CTA that adapts to the step
//   ("Got it" → "Check" → "Speak now" → "Continue").
//
// On completion, a `LessonOutcome` is produced and handed to `LessonStore`.
// The store decides whether the crown level rises and surfaces the
// celebration.

@available(iOS 17.0, macOS 12.0, *)
struct LessonView: View {
    @Environment(\.dismiss) private var dismiss
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
    @State private var applyElapsed: TimeInterval = 0
    @State private var applyTimer: Timer?
    @State private var applyStart: Date?
    @State private var didShowSummary: Bool = false

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
        .accessibilityIdentifier("lesson.screen")
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<lesson.steps.count, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? AppColor.brandBlue : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Header

    private var lessonHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(AppColor.brandBlue.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: lesson.symbolName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
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
                .font(Typography.caption)
                .foregroundStyle(.secondary)
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
            applyCard(prompt: prompt, durationTarget: durationTarget)
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

    enum ApplyPhase { case ready, recording, evaluating, done }

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
                    .symbolEffect(.pulse, options: .repeating.speed(0.9))
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
            if applyOutcomeUsedDevice {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Detected")
                }
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.positive)
            } else if let device = applyExpectedDevice {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text("\(device.title) not detected")
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
        }
        .padding(.top, 4)
    }

    private var applyExpectedDevice: EloquenceDevice? {
        guard case .apply(_, let device, _) = lesson.steps[currentStep] else { return nil }
        return device
    }

    private var applyOutcomeUsedDevice: Bool {
        guard let expected = applyExpectedDevice else {
            // Delivery-only lessons — pass on any non-trivial transcript.
            return applyTranscript.split(separator: " ").count >= 12
        }
        return applyFindings.contains(where: { $0.device == expected })
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
            case .recording:
                ctaButton(title: "Stop", action: stopApply)
            case .evaluating:
                ctaButton(title: "Evaluating…", enabled: false, action: {})
            case .done:
                ctaButton(title: "Continue", action: advance)
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
        applyPhase = .recording
        applyTranscript = ""
        applyFindings = []
        applyElapsed = 0
        applyStart = Date()

        // Auto-stop once the user hits 1.5× the target duration so a
        // forgotten Stop tap doesn't leave the mic open indefinitely.
        let durationCap = applyDurationTarget * 1.5

        speech.shouldRecordPracticeSession = false
        speech.sessionPrompt = applyPrompt
        speech.startRecording()

        applyTimer?.invalidate()
        applyTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in
                guard let start = applyStart else { return }
                applyElapsed = Date().timeIntervalSince(start)
                if applyElapsed >= durationCap {
                    stopApply()
                }
            }
        }
    }

    /// Stop capture, run the eloquence pass on the real transcript, and
    /// transition to `.done`. Pulls the latest transcript directly from
    /// the speech model instead of waiting for the persisted session
    /// (which the lesson explicitly skips).
    private func stopApply() {
        applyTimer?.invalidate()
        applyTimer = nil
        applyPhase = .evaluating

        speech.stopRecording()

        // Give the provider a beat to flush the final partial. Then
        // analyse the captured transcript.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let transcript = speech.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            applyTranscript = transcript
            applyFindings = EloquenceEngine.analyse(transcript: transcript)
            applyPhase = .done

            let didUseDevice: Bool
            if let expected = applyExpectedDevice {
                didUseDevice = applyFindings.contains(where: { $0.device == expected })
            } else {
                didUseDevice = transcript.split(separator: " ").count >= 12
            }
            let passed = didUseDevice
            stepResults.append(.apply(passed: passed, didUseDevice: didUseDevice))
            if passed { CoachHaptic.trendBreakthrough() }
        }
    }

    private var applyPrompt: String {
        guard case .apply(let prompt, _, _) = lesson.steps[currentStep] else { return "" }
        return prompt
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
            withAnimation(.snappySpring) {
                currentStep += 1
                spotItSelection = nil
                spotItRevealed = false
                applyPhase = .ready
                applyTranscript = ""
                applyFindings = []
            }
        } else {
            finishLesson()
        }
    }

    private func finishLesson() {
        let outcome = LessonOutcome(
            lessonID: lesson.id,
            stepResults: stepResults,
            xpEarned: 0
        )
        let xp = LessonXP.xp(for: outcome)
        let final = LessonOutcome(
            lessonID: lesson.id,
            stepResults: stepResults,
            xpEarned: xp
        )
        // Apply mastery + XP.
        lessonStore.apply(outcome: final)
        profileManager.addXP(xp)

        withAnimation(.bouncySpring) {
            didShowSummary = true
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

            crownRow
            xpRow

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
    }

    private var passedHeadline: String {
        let outcome = LessonOutcome(
            lessonID: lesson.id,
            stepResults: stepResults,
            xpEarned: 0
        )
        if outcome.isPerfect { return "Perfect run" }
        if outcome.passed { return "Lesson cleared" }
        return "Try again next time"
    }

    private var passedSubhead: String {
        let crown = lessonStore.crownLevel(for: lesson.id)
        if crown >= LessonStore.crownCap { return "You've mastered \(lesson.title)." }
        if crown == 1 { return "First crown earned. Four more to master." }
        return "\(crown) of 5 crowns on \(lesson.title)."
    }

    private var crownRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<LessonStore.crownCap, id: \.self) { i in
                Image(systemName: i < lessonStore.crownLevel(for: lesson.id) ? "crown.fill" : "crown")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(i < lessonStore.crownLevel(for: lesson.id) ? AppColor.brandBlue : Color.secondary.opacity(0.35))
            }
        }
    }

    private var xpRow: some View {
        let outcome = LessonOutcome(lessonID: lesson.id, stepResults: stepResults, xpEarned: 0)
        let xp = LessonXP.xp(for: outcome)
        return HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppColor.brandBlue)
            Text("\(xp) XP")
                .font(Typography.bigStat.monospacedDigit())
                .foregroundStyle(AppColor.brandBlue)
            if outcome.isPerfect {
                Text("(perfect bonus +\(LessonXP.perfectBonus))")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(AppColor.brandBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
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
