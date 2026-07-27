import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI) && canImport(AVFoundation)

/// PREP Stack — a guided 4-step structure drill.
/// User advances through Point → Reason → Example → Point by tapping "Next Step."
/// Each step shows a coaching hint. Minimum 3 seconds per step before advancing.
/// Success: all 4 steps completed, at least 28 terminal words, and at least
/// 20 seconds of recorder-owned capture duration.
struct PREPStackView: View {
    let drill: DrillRecommendationV2
    let prompt: String?
    let onComplete: (MiniDrillOutcome) -> Void
    let onCancel: () -> Void

    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: DrillPhase = .ready
    @State private var elapsedSeconds: Int = 0
    @State private var countdownValue: Int = 3
    @State private var timerTask: Task<Void, Never>?
    @State private var lifecycleTask: Task<Void, Never>?
    @State private var completionIssue: String?

    // PREP tracking
    @State private var currentStep: Int = 0  // 0-3
    @State private var stepStartTime: Date = Date()
    @State private var stepElapsed: Int = 0
    @State private var stepsCompleted: Int = 0

    private let drillDuration: Int = 90  // Longer for guided structure
    private let minStepSeconds: Int = 3
    private static let insufficientSpeechMessage =
        "We need at least a few spoken words across three seconds to count this drill. Try again when you're ready."

    enum DrillPhase {
        case ready, countdown, connecting, speaking, finishing
    }

    private var steps: [(letter: String, name: String, hint: String)] {
        [
            ("P", "POINT", "State your position in one clear sentence."),
            ("R", "REASON", "Give the strongest reason why."),
            ("E", "EXAMPLE", "Share a specific example or evidence."),
            ("P", "POINT", "Restate your point with conviction. Land it."),
        ]
    }

    private var canAdvance: Bool {
        stepElapsed >= minStepSeconds
    }

    private var isLastStep: Bool {
        currentStep >= steps.count - 1
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                constraintBanner
                    .padding(.top, 8)

                Spacer()

                // Center content
                ZStack {
                    switch phase {
                    case .ready:
                        VStack(spacing: 8) {
                            Image(systemName: "list.number")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(drill.tint)
                            Text("Ready")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                        }
                    case .countdown:
                        Text("\(countdownValue)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(drill.tint)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    case .connecting:
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(drill.tint)
                            Text("Connecting")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Connecting live transcription")
                    case .speaking:
                        speakingContent
                    case .finishing:
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(drill.tint)
                            Text("Finishing")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Finishing your recording")
                    }
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 16) {
                    if phase == .speaking {
                        // Next Step / Finish button
                        if isLastStep {
                            Button {
                                completeLastStep()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.subheadline.weight(.bold))
                                    Text("Finish")
                                        .font(.headline.weight(.bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    canAdvance ? AppColor.positive : AppColor.positive.opacity(0.3),
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(.pressable)
                            .disabled(!canAdvance)
                        } else {
                            Button {
                                advanceStep()
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Next Step")
                                        .font(.headline.weight(.bold))
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.weight(.bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    canAdvance ? drill.tint : drill.tint.opacity(0.3),
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(.pressable)
                            .disabled(!canAdvance)
                        }

                        // Stats row
                        HStack(spacing: 20) {
                            Text("\(elapsedSeconds)s")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.4))
                            if speechVM.fillerWordCount > 0 {
                                HStack(spacing: 4) {
                                    Circle().fill(.red).frame(width: 5, height: 5)
                                    Text("\(speechVM.fillerWordCount)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                            }
                        }

                        // Stop button
                        Button {
                            finishDrill()
                        } label: {
                            Text("Stop early")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.pressable)
                    }

                    // Prompt
                    if let prompt, phase == .ready {
                        Text("\"\(prompt)\"")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if phase == .ready {
                        if let completionIssue {
                            FocusedPracticeErrorStatus(message: completionIssue)
                                .padding(.horizontal, Spacing.sm)
                                .accessibilityIdentifier("prepStack.insufficientSpeech")
                        } else if let error = speechVM.connectionError {
                            FocusedPracticeErrorStatus(message: error)
                                .padding(.horizontal, Spacing.sm)
                                .accessibilityIdentifier("prepStack.captureError")
                        }
                    }

                    // Begin button
                    if phase == .ready {
                        Button {
                            startCountdown()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.subheadline.weight(.bold))
                                Text("Begin Drill")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(drill.tint, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("prepStack.start")
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, Spacing.screenH)

            // Close button
            VStack {
                HStack {
                    Button {
                        cancelDrill()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            // Full strength, not 0.5 — this is the only way out
                            // of a full-screen drill, not decoration.
                            .foregroundStyle(.white.opacity(0.85))
                            // 44pt minimum. It was 36pt, making the sole exit
                            // from an immersive surface the hardest thing on it
                            // to hit.
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Close drill")
                    .accessibilityHint("Leaves the drill. Progress in this drill is not saved.")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .interactiveDismissDisabled(phase == .connecting || phase == .speaking || phase == .finishing)
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
        .onDisappear {
            timerTask?.cancel()
            lifecycleTask?.cancel()
            if speechVM.recordingLifecycle.isBusy {
                speechVM.cancelRecording()
            }
        }
    }

    // MARK: - Speaking Content

    private var speakingContent: some View {
        VStack(spacing: 28) {
            // Step indicator pills
            HStack(spacing: 10) {
                ForEach(0..<steps.count, id: \.self) { index in
                    stepPill(index: index)
                }
            }

            // Current step card
            VStack(spacing: 16) {
                Text(steps[currentStep].name)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(steps[currentStep].hint)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                // Step timer
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text("\(stepElapsed)s")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(canAdvance ? drill.tint : .white.opacity(0.3))
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .fill(drill.tint.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                            .stroke(drill.tint.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Step Pill

    private func stepPill(index: Int) -> some View {
        let isCompleted = index < stepsCompleted
        let isCurrent = index == currentStep && phase == .speaking
        let isFuture = index > currentStep

        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isCompleted ? drill.tint :
                        isCurrent ? drill.tint.opacity(0.3) :
                        .white.opacity(0.06)
                    )
                    .frame(width: 44, height: 44)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Text(steps[index].letter)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            isCurrent ? .white :
                            isFuture ? .white.opacity(0.25) :
                            .white
                        )
                }
            }

            Text(steps[index].name.prefix(3))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(
                    isCompleted ? drill.tint.opacity(0.8) :
                    isCurrent ? .white.opacity(0.6) :
                    .white.opacity(0.2)
                )
        }
    }

    // MARK: - Constraint Banner

    private var constraintBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(drill.tint)
                Text(drill.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Text(drill.constraint)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(drill.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Actions

    private func startCountdown() {
        guard phase == .ready else { return }
        completionIssue = nil
        speechVM.connectionError = nil
        resetAttemptState()
        updateWithMotion(.snappySpring) { phase = .countdown }
        CoachHaptic.drillStart()

        lifecycleTask?.cancel()
        lifecycleTask = Task { @MainActor in
            for i in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                updateWithMotion(.snappySpring) { countdownValue = i }
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            connectRecorderAndStartSpeaking()
        }
    }

    private func connectRecorderAndStartSpeaking() {
        guard phase == .countdown else { return }
        updateWithMotion(.standardSpring) { phase = .connecting }
        speechVM.sessionPrompt = prompt
        speechVM.shouldRecordPracticeSession = false
        speechVM.prepareSession(mode: .timed)

        lifecycleTask?.cancel()
        lifecycleTask = Task { @MainActor in
            let captureReady = await speechVM.startRecordingAwaitingReadiness()
            guard !Task.isCancelled,
                  phase == .connecting,
                  RecordingStartGate.allowsTimerStart(captureReady: captureReady) else {
                if phase == .connecting {
                    updateWithMotion(.standardSpring) { phase = .ready }
                }
                return
            }
            beginSpeakingTimer()
        }
    }

    private func beginSpeakingTimer() {
        updateWithMotion(.standardSpring) { phase = .speaking }
        stepStartTime = Date()

        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    elapsedSeconds += 1
                    stepElapsed = Int(Date().timeIntervalSince(stepStartTime))

                    if elapsedSeconds >= drillDuration {
                        finishDrill()
                    }
                }
            }
        }
    }

    private func advanceStep() {
        guard canAdvance, currentStep < steps.count - 1 else { return }

        updateWithMotion(.snappySpring) {
            stepsCompleted = currentStep + 1
            currentStep += 1
            stepElapsed = 0
            stepStartTime = Date()
        }

        CoachHaptic.selectionTap()
    }

    private func completeLastStep() {
        guard canAdvance else { return }

        updateWithMotion(.snappySpring) {
            stepsCompleted = steps.count
        }
        finishDrill()
    }

    private func finishDrill() {
        guard phase == .speaking else { return }
        timerTask?.cancel()
        updateWithMotion(.standardSpring) { phase = .finishing }

        lifecycleTask?.cancel()
        lifecycleTask = Task { @MainActor in
            let completion = await speechVM.stopRecordingAwaitingFinalization()
            let disposition = MiniDrillCompletionDisposition.resolve(
                completion: completion,
                captureDuration: speechVM.lastSessionDuration
            )

            guard !Task.isCancelled, phase == .finishing else { return }
            switch disposition {
            case .eligible(let evidence):
                completionIssue = nil
                onComplete(completedOutcome(from: evidence))
            case .insufficientSpeech:
                returnToReady(completionIssue: Self.insufficientSpeechMessage)
            case .unusableRecording:
                returnToReady(completionIssue: nil)
            }
        }
    }

    private func completedOutcome(from evidence: MiniDrillCompletionEvidence) -> MiniDrillOutcome {
        let finalSteps = stepsCompleted
        let fillerAnalysis = FillerWordDetector.analysis(
            in: evidence.transcript,
            prompt: prompt ?? ""
        )
        let transitionFillers = fillerAnalysis.detections.filter {
            $0.confidence >= 0.65
                && ($0.context == .transitionGap || $0.context == .sentenceStart)
        }.count
        let closeStrength = PREPStackEvaluation.closeStrength(
            stepsCompleted: finalSteps,
            wordCount: evidence.wordCount
        )
        let succeeded = PREPStackEvaluation.succeeded(
            stepsCompleted: finalSteps,
            wordCount: evidence.wordCount,
            duration: evidence.duration
        )

        let metrics = PREPStackMetrics(
            stepsCompleted: finalSteps,
            totalDuration: evidence.duration,
            wordCount: evidence.wordCount,
            fillerCount: fillerAnalysis.adjustedCount,
            transitionFillers: transitionFillers,
            closeStrength: closeStrength
        )

        if succeeded {
            CoachHaptic.drillSuccess()
        } else {
            CoachHaptic.drillIncomplete()
        }

        return MiniDrillOutcome(
            drill: drill,
            drillType: .prepStack,
            transcript: evidence.transcript,
            fillerCount: fillerAnalysis.adjustedCount,
            duration: evidence.duration,
            wordCount: evidence.wordCount,
            succeeded: succeeded,
            prepStackMetrics: metrics
        )
    }

    private func returnToReady(completionIssue: String?) {
        resetAttemptState()
        self.completionIssue = completionIssue
        updateWithMotion(.standardSpring) { phase = .ready }
    }

    private func resetAttemptState() {
        timerTask?.cancel()
        elapsedSeconds = 0
        countdownValue = 3
        currentStep = 0
        stepElapsed = 0
        stepsCompleted = 0
        stepStartTime = Date()
    }

    private func updateWithMotion(_ animation: Animation, _ updates: () -> Void) {
        withMotion(reduceMotion, animation, updates)
    }

    private func cancelDrill() {
        timerTask?.cancel()
        lifecycleTask?.cancel()
        if speechVM.recordingLifecycle.isBusy {
            speechVM.cancelRecording()
        }
        onCancel()
    }
}

#endif
