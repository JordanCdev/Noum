import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI) && canImport(AVFoundation)

/// PREP Stack — a guided 4-step structure drill.
/// User advances through Point → Reason → Example → Point by tapping "Next Step."
/// Each step shows a coaching hint. Minimum 3 seconds per step before advancing.
/// Success: all 4 steps completed AND total duration >= 20s.
struct PREPStackView: View {
    let drill: DrillRecommendationV2
    let prompt: String?
    let onComplete: (MiniDrillOutcome) -> Void
    let onCancel: () -> Void

    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)

    @State private var phase: DrillPhase = .ready
    @State private var elapsedSeconds: Int = 0
    @State private var countdownValue: Int = 3
    @State private var timerTask: Task<Void, Never>?

    // PREP tracking
    @State private var currentStep: Int = 0  // 0-3
    @State private var stepStartTime: Date = Date()
    @State private var stepElapsed: Int = 0
    @State private var stepsCompleted: Int = 0
    @State private var recordingStartDate: Date?

    private let drillDuration: Int = 90  // Longer for guided structure
    private let minStepSeconds: Int = 3

    enum DrillPhase {
        case ready, countdown, speaking, finishing
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
                            .transition(.scale.combined(with: .opacity))
                    case .speaking:
                        speakingContent
                    case .finishing:
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(drill.tint)
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
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Close drill")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .interactiveDismissDisabled(phase == .speaking)
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
        withAnimation(.snappySpring) { phase = .countdown }
        CoachHaptic.drillStart()

        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run {
                    withAnimation(.snappySpring) { countdownValue = i }
                }
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run { startSpeaking() }
        }
    }

    private func startSpeaking() {
        withAnimation(.standardSpring) { phase = .speaking }
        stepStartTime = Date()

        speechVM.sessionPrompt = prompt
        speechVM.shouldRecordPracticeSession = false
        speechVM.prepareSession(mode: .timed)
        recordingStartDate = Date()
        speechVM.startRecording()

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

        withAnimation(.snappySpring) {
            stepsCompleted = currentStep + 1
            currentStep += 1
            stepElapsed = 0
            stepStartTime = Date()
        }

        CoachHaptic.selectionTap()
    }

    private func completeLastStep() {
        guard canAdvance else { return }

        withAnimation(.snappySpring) {
            stepsCompleted = steps.count
        }

        CoachHaptic.drillSuccess()

        // Auto-finish after brief delay
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { finishDrill() }
        }
    }

    private func finishDrill() {
        guard phase == .speaking else { return }
        timerTask?.cancel()
        speechVM.stopRecording()

        withAnimation(.standardSpring) { phase = .finishing }

        let fillerCount = speechVM.fillerWordCount
        let measuredDuration = recordingStartDate.map { Date().timeIntervalSince($0) } ?? TimeInterval(elapsedSeconds)
        let duration = max(speechVM.lastSessionDuration, measuredDuration, TimeInterval(elapsedSeconds))
        let transcript = speechVM.transcribedText
        let wordCount = transcript.split(separator: " ").count

        let finalSteps = stepsCompleted
        let detections = FillerWordDetector.detections(in: transcript, prompt: prompt ?? "")
        let transitionFillers = detections.filter { $0.confidence >= 0.65 && ($0.context == .transitionGap || $0.context == .sentenceStart) }.count
        let closeStrength = finalSteps >= steps.count && wordCount >= 28 ? 1.0 : Double(finalSteps) / Double(steps.count)
        let succeeded = finalSteps >= steps.count && duration >= 20 && closeStrength >= 0.75

        let metrics = PREPStackMetrics(
            stepsCompleted: finalSteps,
            totalDuration: duration,
            wordCount: wordCount,
            fillerCount: fillerCount,
            transitionFillers: transitionFillers,
            closeStrength: closeStrength
        )

        if succeeded {
            // Already fired in completeLastStep, but fire again if auto-timed-out
        } else {
            CoachHaptic.drillIncomplete()
        }

        let outcome = MiniDrillOutcome(
            drill: drill,
            drillType: .prepStack,
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            succeeded: succeeded,
            prepStackMetrics: metrics
        )

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run { onComplete(outcome) }
        }
    }

    private func cancelDrill() {
        timerTask?.cancel()
        if speechVM.isRecording { speechVM.stopRecording() }
        onCancel()
    }
}

#endif
