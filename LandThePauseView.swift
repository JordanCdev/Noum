import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI) && canImport(AVFoundation)

/// Land the Pause — a checkpoint pause drill.
/// User speaks and locks in 3 deliberate pauses by tapping a "Lock" button.
/// The Lock button pulses when silence is detected (no new words for 0.5s+).
/// Success: all 3 checkpoints locked.
struct LandThePauseView: View {
    let drill: DrillRecommendationV2
    let prompt: String?
    let onComplete: (MiniDrillOutcome) -> Void
    let onCancel: () -> Void

    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)

    @State private var phase: DrillPhase = .ready
    @State private var elapsedSeconds: Int = 0
    @State private var countdownValue: Int = 3
    @State private var timerTask: Task<Void, Never>?

    // Checkpoint tracking
    @State private var checkpointsLocked: Int = 0
    @State private var pauseDurations: [TimeInterval] = []
    @State private var lastWordTime: Date = Date()
    @State private var isSilent: Bool = false
    @State private var silenceStartTime: Date?
    @State private var previousWordCount: Int = 0
    @State private var lockPulse: Bool = false
    @State private var recordingStartDate: Date?

    private let drillDuration: Int = 45
    private let totalCheckpoints: Int = 3
    private let silenceThreshold: TimeInterval = 0.5

    enum DrillPhase {
        case ready, countdown, speaking, finishing
    }

    private var allLocked: Bool {
        checkpointsLocked >= totalCheckpoints
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
                            Image(systemName: "pause.circle")
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
                VStack(spacing: 20) {
                    if phase == .speaking {
                        // Lock button
                        if !allLocked {
                            Button {
                                lockCheckpoint()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.subheadline.weight(.bold))
                                    Text("LOCK")
                                        .font(.headline.weight(.heavy))
                                        .tracking(1.0)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 36)
                                .padding(.vertical, 16)
                                .background(
                                    isSilent ? drill.tint : drill.tint.opacity(0.3),
                                    in: Capsule()
                                )
                                .scaleEffect(lockPulse && isSilent ? 1.05 : 1.0)
                            }
                            .buttonStyle(.pressable)
                            .disabled(!isSilent)
                        } else {
                            Text("All checkpoints locked in")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppColor.positive)
                        }

                        // Filler count
                        if speechVM.fillerWordCount > 0 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                Text("\(speechVM.fillerWordCount) filler\(speechVM.fillerWordCount == 1 ? "" : "s")")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .transition(.opacity)
                        }
                    }

                    // Prompt
                    if let prompt, phase == .speaking || phase == .ready {
                        Text("\"\(prompt)\"")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Action button
                    switch phase {
                    case .ready:
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
                    case .countdown:
                        EmptyView()
                    case .speaking:
                        Button {
                            finishDrill()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.fill")
                                    .font(.caption.weight(.bold))
                                Text("Stop")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    case .finishing:
                        EmptyView()
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
        VStack(spacing: 24) {
            // Speaking orb
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [drill.tint.opacity(0.3), drill.tint.opacity(0.08)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    Text("\(elapsedSeconds)s")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("of \(drillDuration)s")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            // Checkpoint indicators
            HStack(spacing: 20) {
                ForEach(0..<totalCheckpoints, id: \.self) { index in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(
                                    index < checkpointsLocked ? drill.tint : .white.opacity(0.2),
                                    lineWidth: 2.5
                                )
                                .frame(width: 36, height: 36)

                            if index < checkpointsLocked {
                                Circle()
                                    .fill(drill.tint)
                                    .frame(width: 36, height: 36)

                                Image(systemName: "lock.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            } else if index == checkpointsLocked && isSilent {
                                // Pulsing indicator for next checkpoint
                                Circle()
                                    .fill(drill.tint.opacity(0.3))
                                    .frame(width: 36, height: 36)
                                    .scaleEffect(lockPulse ? 1.1 : 0.9)
                            }
                        }

                        // Pause duration label
                        if index < pauseDurations.count {
                            Text(String(format: "%.1fs", pauseDurations[index]))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(drill.tint.opacity(0.8))
                        } else {
                            Text("—")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                    }
                }
            }

            // Silence indicator
            if isSilent && !allLocked {
                Text("Pause detected — tap LOCK")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(drill.tint)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Constraint Banner

    private var constraintBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pause.circle")
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
        lastWordTime = Date()

        speechVM.sessionPrompt = prompt
        speechVM.shouldRecordPracticeSession = false
        speechVM.prepareSession(mode: .timed)
        recordingStartDate = Date()
        speechVM.startRecording()

        // Start pulse animation for lock button
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            lockPulse = true
        }

        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    checkSilence()
                }
            }
        }

        // Separate second-level timer for elapsed
        Task {
            while !Task.isCancelled && phase == .speaking {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled && phase == .speaking else { return }
                await MainActor.run {
                    elapsedSeconds += 1
                    if elapsedSeconds >= drillDuration {
                        finishDrill()
                    }
                }
            }
        }
    }

    private func checkSilence() {
        let currentWordCount = speechVM.transcribedText.split(separator: " ").count
        if currentWordCount > previousWordCount {
            // New words arrived
            previousWordCount = currentWordCount
            lastWordTime = Date()
            if isSilent {
                withAnimation(.easeOut(duration: 0.2)) { isSilent = false }
                silenceStartTime = nil
            }
        } else {
            // Check for silence duration
            let silenceDuration = Date().timeIntervalSince(lastWordTime)
            if silenceDuration >= silenceThreshold && !isSilent && previousWordCount > 0 {
                withAnimation(.easeOut(duration: 0.2)) { isSilent = true }
                silenceStartTime = lastWordTime
            }
        }
    }

    private func lockCheckpoint() {
        guard isSilent, checkpointsLocked < totalCheckpoints else { return }

        let pauseDuration: TimeInterval
        if let start = silenceStartTime {
            pauseDuration = Date().timeIntervalSince(start)
        } else {
            pauseDuration = Date().timeIntervalSince(lastWordTime)
        }

        withAnimation(.achievementPop) {
            checkpointsLocked += 1
            pauseDurations.append(pauseDuration)
            isSilent = false
            silenceStartTime = nil
        }

        CoachHaptic.checkpointLock()

        // Auto-finish if all locked
        if allLocked {
            Task {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { finishDrill() }
            }
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
        let detections = FillerWordDetector.detections(in: transcript, prompt: prompt ?? "")
        let transitionFillers = detections.filter { $0.confidence >= 0.65 && ($0.context == .transitionGap || $0.context == .sentenceStart) }.count
        let bestCombo = transitionFillers == 0 ? checkpointsLocked : max(0, checkpointsLocked - transitionFillers)
        let succeeded = checkpointsLocked >= totalCheckpoints && transitionFillers <= 1

        let metrics = LandThePauseMetrics(
            checkpointsLocked: checkpointsLocked,
            pauseDurations: pauseDurations,
            totalDuration: duration,
            fillerCount: fillerCount,
            transitionFillers: transitionFillers,
            bestCombo: bestCombo
        )

        if succeeded {
            CoachHaptic.drillSuccess()
        } else {
            CoachHaptic.drillIncomplete()
        }

        let outcome = MiniDrillOutcome(
            drill: drill,
            drillType: .landThePause,
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            succeeded: succeeded,
            landThePauseMetrics: metrics
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
