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

    @State private var phase: DrillPhase = .ready
    @State private var elapsedSeconds: Int = 0
    @State private var countdownValue: Int = 3
    @State private var progressRingFill: Double = 0
    @State private var showPulse = false
    @State private var timerTask: Task<Void, Never>?
    @State private var recordingStartDate: Date?

    private let drillDuration: Int = 45

    enum DrillPhase {
        case ready
        case countdown
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
                        .stroke(drill.tint.opacity(0.15), lineWidth: 6)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: progressRingFill)
                        .stroke(drill.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progressRingFill)

                    // Inner orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [drill.tint.opacity(0.3), drill.tint.opacity(0.08)],
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
                        VStack(spacing: 4) {
                            Text("\(elapsedSeconds)s")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("of \(drillDuration)s")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    case .finishing:
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(drill.tint)
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
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .transition(.opacity)
                    }

                    // Prompt (if available) — prominent enough to actually read
                    if let prompt, phase == .speaking || phase == .ready {
                        Text("\"\(prompt)\"")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Goal line — what success looks like
                    if phase == .ready {
                        Text("Goal: \(drill.variation.successDescription)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(drill.tint.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
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

            // Close button (top-left)
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
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .interactiveDismissDisabled(phase == .speaking)
    }

    // MARK: - Constraint Banner

    private var constraintBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: drill.icon)
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
        withAnimation(.standardSpring) {
            phase = .speaking
            showPulse = true
        }

        speechVM.sessionPrompt = prompt
        speechVM.shouldRecordPracticeSession = false
        speechVM.prepareSession(mode: .timed)
        recordingStartDate = Date()
        speechVM.startRecording()

        // Timer task
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    elapsedSeconds += 1
                    withAnimation(.linear(duration: 0.3)) {
                        progressRingFill = Double(elapsedSeconds) / Double(drillDuration)
                    }

                    // Auto-stop at drill duration
                    if elapsedSeconds >= drillDuration {
                        finishDrill()
                    }
                }
            }
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            showPulse = true
        }
    }

    private func finishDrill() {
        guard phase == .speaking else { return }
        timerTask?.cancel()
        speechVM.stopRecording()

        withAnimation(.standardSpring) {
            phase = .finishing
            progressRingFill = 1.0
        }

        // Evaluate success
        let fillerCount = speechVM.fillerWordCount
        let measuredDuration = recordingStartDate.map { Date().timeIntervalSince($0) } ?? TimeInterval(elapsedSeconds)
        let duration = max(speechVM.lastSessionDuration, measuredDuration, TimeInterval(elapsedSeconds))
        let transcript = speechVM.transcribedText
        let wordCount = transcript.split(separator: " ").count

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

        let outcome = MiniDrillOutcome(
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

        // Brief pause before showing result
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

/// A type-erased wrapper over the three per-framework verdicts so the result
/// view holds one optional field rather than three. Bounded + `Equatable`.
enum FrameworkDrillVerdict: Equatable {
    case star(FrameworkDrillChecks.StarTurnVerdict)
    case claimCounter(FrameworkDrillChecks.ClaimCounterVerdict)
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
        case .elevatorPitch:
            return FrameworkDrillChecks.elevatorPitch(transcript: transcript, duration: duration).map(FrameworkDrillVerdict.elevatorPitch)
        case .bridgeReframe:
            return FrameworkDrillChecks.bridgeReframe(transcript: transcript).map(FrameworkDrillVerdict.bridgeReframe)
        case .areaAnswer:
            return FrameworkDrillChecks.areaAnswer(transcript: transcript).map(FrameworkDrillVerdict.areaAnswer)
        }
    }
}

#endif
