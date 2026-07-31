import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI) && canImport(AVFoundation)

/// A focused 45-second mini-drill experience.
/// Stripped-down UI: constraint, orb, progress ring, filler count.
/// Designed to be low-friction and completable in under a minute.
struct MiniDrillView: View {
    let drill: DrillRecommendationV2
    let prompt: String?                 // Same prompt or nil for open topic
    let onComplete: (MiniDrillOutcome) -> Void
    let onCancel: () -> Void

    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var phase: DrillPhase = .ready
    @State private var elapsedSeconds: Int = 0
    @State private var countdownValue: Int = 3
    @State private var progressRingFill: Double = 0
    @State private var showPulse = false
    @State private var timerTask: Task<Void, Never>?
    @State private var lifecycleTask: Task<Void, Never>?
    @State private var completionIssue: String?
    #if DEBUG
    @State private var didInstallCompletionFixture = false
    #endif

    private let drillDuration: Int = 45

    enum DrillPhase {
        case ready
        case countdown
        case connecting
        case speaking
        case finishing
    }

    var body: some View {
        ZStack {
            // Background — dark, focused
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top: constraint banner
                constraintBanner
                    .padding(.top, 8)

                Spacer()

                // Center: the orb
                ZStack {
                    // Progress ring
                    Circle()
                        .stroke(focusedAccent.opacity(0.15), lineWidth: 6)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: progressRingFill)
                        .stroke(focusedAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 1), value: progressRingFill)

                    // Inner orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [focusedAccent.opacity(0.3), focusedAccent.opacity(0.08)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(showPulse ? 1.05 : 1.0)

                    // Center content
                    switch phase {
                    case .ready:
                        VStack(spacing: 8) {
                            Image(systemName: drill.icon)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(focusedAccent)
                            Text("Ready")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                        }
                    case .countdown:
                        Text("\(countdownValue)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(focusedAccent)
                            .transition(.scale.combined(with: .opacity))
                    case .connecting:
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(focusedAccent)
                            Text("Connecting")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                        }
                    case .speaking:
                        VStack(spacing: 4) {
                            Text("\(elapsedSeconds)s")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("of \(drillDuration)s")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppColor.focusedTextSecondary)
                        }
                    case .finishing:
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(focusedAccent)
                    }
                }

                Spacer()

                // Bottom: filler count + action button
                VStack(spacing: 20) {
                    // Filler count (visible during speaking)
                    if phase == .speaking && speechVM.fillerWordCount > 0 {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                            Text("\(speechVM.fillerWordCount) filler\(speechVM.fillerWordCount == 1 ? "" : "s")")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        .transition(.opacity)
                    }

                    // Prompt (if available) — prominent enough to actually read
                    if let prompt, phase == .speaking || phase == .ready {
                        Text("\"\(prompt)\"")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                            .fixedSize(
                                horizontal: false,
                                vertical: dynamicTypeSize.isAccessibilitySize
                            )
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Goal line — what success looks like
                    if phase == .ready {
                        Text("Goal: \(drill.variation.successDescription)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColor.focusedTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    if phase == .ready, let error = speechVM.connectionError {
                        FocusedPracticeErrorStatus(message: error)
                            .padding(.horizontal, Spacing.sm)
                            .accessibilityIdentifier("miniDrill.captureError")
                    }

                    if phase == .ready, let completionIssue {
                        FocusedPracticeErrorStatus(message: completionIssue)
                            .padding(.horizontal, Spacing.sm)
                            .accessibilityIdentifier("miniDrill.completionIssue")
                    }

                    // Keep the action in the established composition at
                    // standard sizes. Accessibility sizes pin the same action
                    // below the scrollable content, so recovery never depends
                    // on reaching the end of a very tall error state.
                    if !dynamicTypeSize.isAccessibilitySize {
                        phaseAction
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 56 : 0)
            .modifier(
                MiniDrillAccessibilityScrollModifier(
                    isEnabled: dynamicTypeSize.isAccessibilitySize
                )
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if dynamicTypeSize.isAccessibilitySize,
                   phase == .ready || phase == .speaking {
                    HStack {
                        Spacer(minLength: 0)
                        phaseAction
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.black.opacity(0.94))
                }
            }

            // Close button (top-left)
            VStack {
                HStack {
                    Button {
                        cancelDrill()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            // 44pt minimum — this is the only way out of the
                            // drill, so it should not be the hardest thing on
                            // screen to hit.
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Close drill")
                    .accessibilityHint("Leaves the drill. Progress in this drill is not saved.")
                    .accessibilityIdentifier("miniDrill.close")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .interactiveDismissDisabled(phase == .connecting || phase == .speaking || phase == .finishing)
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
        .onAppear {
            #if DEBUG
            installCompletionFixtureIfNeeded()
            #endif
        }
        .onDisappear {
            timerTask?.cancel()
            lifecycleTask?.cancel()
            if speechVM.recordingLifecycle.isBusy {
                speechVM.cancelRecording()
            }
        }
    }

    // MARK: - Constraint Banner

    private var focusedAccent: Color {
        drill.skillArea.miniDrillFocusedAccent
    }

    private var constraintBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: drill.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(focusedAccent)
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
        .background(focusedAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Actions

    @ViewBuilder
    private var phaseAction: some View {
        switch phase {
        case .ready:
            Button {
                startCountdown()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.bold))
                    Text("Start drill")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(drill.skillArea.miniDrillActionForeground)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(drill.skillArea.miniDrillActionFill, in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("miniDrill.start")
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
                .frame(minHeight: 44)
                .background(.white.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.pressable)
        case .finishing:
            EmptyView()
        }
    }

    private func startCountdown() {
        completionIssue = nil
        setPhase(.countdown, animation: .snappySpring)
        CoachHaptic.drillStart()

        lifecycleTask?.cancel()
        lifecycleTask = Task {
            for i in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if reduceMotion {
                        countdownValue = i
                    } else {
                        withAnimation(.snappySpring) { countdownValue = i }
                    }
                }
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { connectRecorderAndStartSpeaking() }
        }
    }

    private func connectRecorderAndStartSpeaking() {
        guard phase == .countdown else { return }
        setPhase(.connecting, animation: .standardSpring)

        speechVM.connectionError = nil
        completionIssue = nil
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
                    setPhase(.ready, animation: .standardSpring)
                }
                return
            }
            beginSpeakingTimer()
        }
    }

    private func beginSpeakingTimer() {
        setPhase(.speaking, animation: .standardSpring)
        showPulse = !reduceMotion
        elapsedSeconds = 0
        progressRingFill = 0

        // Timer task
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    elapsedSeconds += 1
                    let fill = Double(elapsedSeconds) / Double(drillDuration)
                    if reduceMotion {
                        progressRingFill = fill
                    } else {
                        withAnimation(.linear(duration: 0.3)) { progressRingFill = fill }
                    }

                    // Auto-stop at drill duration
                    if elapsedSeconds >= drillDuration {
                        finishDrill()
                    }
                }
            }
        }

        // Pulse animation
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                showPulse = true
            }
        }
    }

    private func finishDrill() {
        guard phase == .speaking else { return }
        timerTask?.cancel()

        setPhase(.finishing, animation: .standardSpring)
        progressRingFill = 1.0

        lifecycleTask?.cancel()
        lifecycleTask = Task { @MainActor in
            let completion = await speechVM.stopRecordingAwaitingFinalization()
            guard !Task.isCancelled else { return }
            let disposition = MiniDrillCompletionDisposition.resolve(
                completion: completion,
                captureDuration: speechVM.lastSessionDuration
            )
            switch disposition {
            case .eligible(let evidence):
                let outcome = completedOutcome(from: evidence)
                guard phase == .finishing else { return }
                onComplete(outcome)
            case .insufficientSpeech:
                progressRingFill = 0
                completionIssue = Self.insufficientSpeechMessage
                setPhase(.ready, animation: .standardSpring)
            case .unusableRecording:
                progressRingFill = 0
                setPhase(.ready, animation: .standardSpring)
            }
        }
    }

    #if DEBUG
    private func installCompletionFixtureIfNeeded() {
        guard !didInstallCompletionFixture,
              let fixture = MiniDrillCompletionUITestFixture.requested(),
              drill.variation.id == MiniDrillCompletionUITestFixture.variationID else {
            return
        }
        didInstallCompletionFixture = true

        switch MiniDrillCompletionDisposition.resolve(
            completion: fixture.completion,
            captureDuration: fixture.captureDuration
        ) {
        case .eligible(let evidence):
            completionIssue = nil
            onComplete(completedOutcome(from: evidence))
        case .insufficientSpeech:
            progressRingFill = 0
            completionIssue = Self.insufficientSpeechMessage
            setPhase(.ready, animation: .standardSpring)
        case .unusableRecording:
            assertionFailure("Mini-drill UI fixture must provide a usable terminal receipt")
        }
    }
    #endif

    private func completedOutcome(from evidence: MiniDrillCompletionEvidence) -> MiniDrillOutcome {
        let transcript = evidence.transcript
        let duration = evidence.duration
        let wordCount = evidence.wordCount
        let fillerCount = FillerWordDetector.analysis(
            in: transcript,
            prompt: prompt ?? ""
        ).adjustedCount

        let succeeded = evaluateSuccess(
            skillArea: drill.skillArea,
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount
        )

        if succeeded {
            CoachHaptic.drillSuccess()
        } else {
            CoachHaptic.drillIncomplete()
        }

        // `MiniDrillView` is the shared recording UI for both the generic
        // constraint drill (`.standard`) and the named-framework drills
        // (`.frameworkCheck`). Derive the type + framework from the variation
        // ID so the result surface routes to the right copy. The structural
        // verdict is computed READ-ONLY — `succeeded` above is untouched, so
        // XP / streaks / history stay driven purely by the deterministic
        // `evaluateSuccess` thresholds (score-safety).
        let drillType = MiniDrillType.from(variationId: drill.variation.id)
        let framework = MiniDrillType.framework(for: drill.variation.id)
        let frameworkVerdict = FrameworkDrillVerdict.evaluate(
            framework,
            transcript: transcript,
            duration: duration
        )

        return MiniDrillOutcome(
            drill: drill,
            drillType: drillType,
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            succeeded: succeeded,
            framework: framework,
            frameworkVerdict: frameworkVerdict
        )
    }

    private func cancelDrill() {
        timerTask?.cancel()
        lifecycleTask?.cancel()
        if speechVM.recordingLifecycle.isBusy { speechVM.cancelRecording() }
        onCancel()
    }

    private func setPhase(_ newPhase: DrillPhase, animation: Animation) {
        if reduceMotion {
            phase = newPhase
        } else {
            withAnimation(animation) { phase = newPhase }
        }
    }

    private static let insufficientSpeechMessage =
        "Say at least 3 words over 3 seconds so Noum has enough speech to assess this drill."

    // MARK: - Success Evaluation

    private func evaluateSuccess(
        skillArea: SkillArea,
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int
    ) -> Bool {
        let wpm = duration > 0 ? Double(wordCount) / duration * 60 : 0

        switch skillArea {
        case .fillerReduction:
            return fillerCount <= 1
        case .openingStrength, .closingStrength:
            return wordCount >= 10 && duration >= 10
        case .paceControl:
            return ConversationalPaceBand.contains(wpm)
        case .structure:
            return wordCount >= 30 && duration >= 20
        case .answerDevelopment:
            return duration >= 25 && wordCount >= 40
        case .conciseSpeaking:
            return duration <= 25 && wordCount >= 15
        case .pauseUsage:
            return duration >= 15 && fillerCount <= 1
        case .vocalEmphasis:
            return duration >= 15 && wordCount >= 20
        case .confidence:
            return fillerCount <= 1 && wordCount >= 15
        }
    }
}

// MARK: - Mini Drill Outcome

/// The result of a completed mini-drill, passed to the result view.
struct MiniDrillOutcome: Identifiable {
    let id = UUID()
    let drill: DrillRecommendationV2
    let drillType: MiniDrillType
    let transcript: String
    let fillerCount: Int
    let duration: TimeInterval
    let wordCount: Int
    let succeeded: Bool
    // Drill-specific metrics (only one populated per drill type)
    var beatTheBrakeMetrics: BeatTheBrakeMetrics?
    var landThePauseMetrics: LandThePauseMetrics?
    var prepStackMetrics: PREPStackMetrics?
    /// The named framework a `.frameworkCheck` drill graded against, when this
    /// is a framework drill. `nil` for every other drill type — defaulted so
    /// existing construction sites are unaffected.
    var framework: FrameworkDrill?
    /// The post-hoc structural verdict for a `.frameworkCheck` drill, carried
    /// so the result copy can surface ONE constructive structural nudge without
    /// re-running detection. READ-ONLY w.r.t. the numeric outcome: it never
    /// feeds `succeeded` or XP (mirrors how the prompt-relevance verdict never
    /// moves the score). `nil` when below the detector's evidence floor or for
    /// non-framework drills.
    var frameworkVerdict: FrameworkDrillVerdict?
}

extension MiniDrillOutcome {
    /// Defense-in-depth for the reward sink. Views should only construct an
    /// outcome from terminal evidence, and Summary independently rechecks the
    /// same minimum quantity before mutating history, XP, streaks, or baselines.
    var isProgressEligible: Bool {
        MiniDrillCompletionEvidence.validated(
            transcript: transcript,
            captureDuration: duration
        )?.wordCount == wordCount
    }
}

/// A type-erased wrapper over the per-framework verdicts so the result view
/// holds one optional field rather than one field per framework. Bounded +
/// `Equatable`.
enum FrameworkDrillVerdict: Equatable {
    case star(FrameworkDrillChecks.StarTurnVerdict)
    case claimCounter(FrameworkDrillChecks.ClaimCounterVerdict)
    case claimEvidenceWarrant(FrameworkDrillChecks.ClaimEvidenceWarrantVerdict)
    case monroeSequence(FrameworkDrillChecks.MonroeSequenceVerdict)
    case elevatorPitch(FrameworkDrillChecks.ElevatorPitchVerdict)
    case bridgeReframe(FrameworkDrillChecks.BridgeReframeVerdict)
    case areaAnswer(FrameworkDrillChecks.AreaVerdict)

    /// Run the matching deterministic detector for `framework`. Returns `nil`
    /// when there is no framework (a non-framework drill) or when the detector
    /// is below its evidence floor (no confident negative on thin data). Pure —
    /// the single place that maps a framework to its detector + wraps the
    /// result, so the recording flow and any test read the same routing.
    static func evaluate(
        _ framework: FrameworkDrill?,
        transcript: String,
        duration: TimeInterval
    ) -> FrameworkDrillVerdict? {
        guard let framework else { return nil }
        switch framework {
        case .starTurn:
            return FrameworkDrillChecks.starTurn(transcript: transcript).map(FrameworkDrillVerdict.star)
        case .claimCounter:
            return FrameworkDrillChecks.claimCounter(transcript: transcript).map(FrameworkDrillVerdict.claimCounter)
        case .claimEvidenceWarrant:
            return FrameworkDrillChecks.claimEvidenceWarrant(transcript: transcript).map(FrameworkDrillVerdict.claimEvidenceWarrant)
        case .monroeSequence:
            return FrameworkDrillChecks.monroeSequence(transcript: transcript).map(FrameworkDrillVerdict.monroeSequence)
        case .elevatorPitch:
            return FrameworkDrillChecks.elevatorPitch(transcript: transcript, duration: duration).map(FrameworkDrillVerdict.elevatorPitch)
        case .bridgeReframe:
            return FrameworkDrillChecks.bridgeReframe(transcript: transcript).map(FrameworkDrillVerdict.bridgeReframe)
        case .areaAnswer:
            return FrameworkDrillChecks.areaAnswer(transcript: transcript).map(FrameworkDrillVerdict.areaAnswer)
        }
    }
}

private struct MiniDrillAccessibilityScrollModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

#endif
