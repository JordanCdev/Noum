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
    @State private var lifecycleTask: Task<Void, Never>?
    @State private var completionIssue: String?

    // Checkpoint tracking
    @State private var checkpointsLocked: Int = 0
    @State private var pauseDurations: [TimeInterval] = []
    @State private var lastWordTime: Date = Date()
    @State private var isSilent: Bool = false
    @State private var silenceStartTime: Date?
    @State private var previousWordCount: Int = 0
    @State private var lockPulse: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let drillDuration: Int = 45
    private let totalCheckpoints: Int = 3
    private let silenceThreshold: TimeInterval = 0.5

    enum DrillPhase {
        case ready, countdown, connecting, speaking, finishing
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

                    if phase == .ready, let completionIssue {
                        FocusedPracticeErrorStatus(message: completionIssue)
                            .padding(.horizontal, Spacing.sm)
                            .accessibilityIdentifier("landThePause.insufficientSpeech")
                    } else if phase == .ready, let error = speechVM.connectionError {
                        FocusedPracticeErrorStatus(message: error)
                            .padding(.horizontal, Spacing.sm)
                            .accessibilityIdentifier("landThePause.captureError")
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
                        .accessibilityIdentifier("landThePause.start")
                    case .countdown, .connecting:
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
        guard phase == .ready else { return }
        timerTask?.cancel()
        lifecycleTask?.cancel()
        resetRunState()
        completionIssue = nil
        speechVM.connectionError = nil
        setPhase(.countdown, animation: .snappySpring)
        CoachHaptic.drillStart()

        lifecycleTask = Task { @MainActor in
            for i in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled, phase == .countdown else { return }
                if reduceMotion {
                    countdownValue = i
                } else {
                    withAnimation(.snappySpring) { countdownValue = i }
                }
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled, phase == .countdown else { return }
            await connectRecorderAndStartSpeaking()
        }
    }

    @MainActor
    private func connectRecorderAndStartSpeaking() async {
        setPhase(.connecting, animation: .standardSpring)
        speechVM.sessionPrompt = prompt
        speechVM.shouldRecordPracticeSession = false
        speechVM.prepareSession(mode: .timed)

        let captureReady = await speechVM.startRecordingAwaitingReadiness()
        guard !Task.isCancelled,
              phase == .connecting,
              RecordingStartGate.allowsTimerStart(captureReady: captureReady) else {
            if phase == .connecting {
                setPhase(.ready, animation: .standardSpring)
            }
            return
        }

        beginSpeaking()
    }

    private func beginSpeaking() {
        setPhase(.speaking, animation: .standardSpring)
        lastWordTime = Date()

        // Start pulse animation for lock button
        if reduceMotion {
            lockPulse = false
        } else {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                lockPulse = true
            }
        }

        timerTask?.cancel()
        timerTask = Task { @MainActor in
            var tickCount = 0
            while !Task.isCancelled, phase == .speaking {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, phase == .speaking else { return }
                checkSilence()
                tickCount += 1
                if tickCount.isMultiple(of: 5) {
                    elapsedSeconds += 1
                    if elapsedSeconds >= drillDuration {
                        finishDrill()
                    }
                }
            }
        }
    }

    private func resetRunState() {
        elapsedSeconds = 0
        countdownValue = 3
        checkpointsLocked = 0
        pauseDurations = []
        lastWordTime = Date()
        isSilent = false
        silenceStartTime = nil
        previousWordCount = 0
        lockPulse = false
    }

    private func setPhase(_ newPhase: DrillPhase, animation: Animation) {
        if reduceMotion {
            phase = newPhase
        } else {
            withAnimation(animation) {
                phase = newPhase
            }
        }
    }

    private func setSilenceDetected(_ detected: Bool) {
        if reduceMotion {
            isSilent = detected
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                isSilent = detected
            }
        }
    }

    private func commitCheckpoint(pauseDuration: TimeInterval) {
        let update = {
            checkpointsLocked += 1
            pauseDurations.append(pauseDuration)
            isSilent = false
            silenceStartTime = nil
        }
        if reduceMotion {
            update()
        } else {
            withAnimation(.achievementPop, update)
        }
    }

    private func returnToReady(completionIssue issue: String?) {
        completionIssue = issue
        setPhase(.ready, animation: .standardSpring)
    }

    private static let insufficientSpeechMessage =
        "We didn’t catch enough speech to score that pause drill. Speak a little longer and try again."

    private func checkSilence() {
        let currentWordCount = speechVM.transcribedText.split(separator: " ").count
        if currentWordCount > previousWordCount {
            // New words arrived
            previousWordCount = currentWordCount
            lastWordTime = Date()
            if isSilent {
                setSilenceDetected(false)
                silenceStartTime = nil
            }
        } else {
            // Check for silence duration
            let silenceDuration = Date().timeIntervalSince(lastWordTime)
            if silenceDuration >= silenceThreshold && !isSilent && previousWordCount > 0 {
                setSilenceDetected(true)
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

        commitCheckpoint(pauseDuration: pauseDuration)

        CoachHaptic.checkpointLock()

        // Auto-finish if all locked
        if allLocked {
            lifecycleTask?.cancel()
            lifecycleTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, phase == .speaking, allLocked else { return }
                finishDrill()
            }
        }
    }

    private func finishDrill() {
        guard phase == .speaking else { return }
        timerTask?.cancel()
        setPhase(.finishing, animation: .standardSpring)

        lifecycleTask?.cancel()
        lifecycleTask = Task { @MainActor in
            let completion = await speechVM.stopRecordingAwaitingFinalization()
            guard !Task.isCancelled, phase == .finishing else { return }

            let disposition = MiniDrillCompletionDisposition.resolve(
                completion: completion,
                captureDuration: speechVM.lastSessionDuration
            )
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
        let transcript = evidence.transcript
        let fillerAnalysis = FillerWordDetector.analysis(in: transcript, prompt: prompt ?? "")
        let fillerCount = fillerAnalysis.adjustedCount
        let transitionFillers = fillerAnalysis.adjustedDetections.filter {
            $0.context == .transitionGap || $0.context == .sentenceStart
        }.count
        let bestCombo = transitionFillers == 0 ? checkpointsLocked : max(0, checkpointsLocked - transitionFillers)
        let succeeded = checkpointsLocked >= totalCheckpoints && transitionFillers <= 1

        let metrics = LandThePauseMetrics(
            checkpointsLocked: checkpointsLocked,
            pauseDurations: pauseDurations,
            totalDuration: evidence.duration,
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
            duration: evidence.duration,
            wordCount: evidence.wordCount,
            succeeded: succeeded,
            landThePauseMetrics: metrics
        )
        return outcome
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
