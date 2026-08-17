import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFAudio)
import AVFAudio
#endif

#if canImport(AVFAudio)
struct SuddenDeathPromptSpeechRequest: Equatable, Sendable {
    let id: UUID
    let round: Int
    let prompt: String
}

enum SuddenDeathPromptPlaybackAction: Equatable {
    case awaitCloudCompletion
    case useLocalFallback
    case completeWithoutFallback
}

enum SuddenDeathPromptReadoutPolicy {
    static func isCurrent(
        _ request: SuddenDeathPromptSpeechRequest,
        currentRequest: SuddenDeathPromptSpeechRequest?,
        activeRound: Int?,
        currentPrompt: String,
        isCancelled: Bool
    ) -> Bool {
        !isCancelled
            && request == currentRequest
            && request.round == activeRound
            && request.prompt == currentPrompt
    }

    static func action(
        for outcome: IMMessagePromptPlaybackOutcome
    ) -> SuddenDeathPromptPlaybackAction {
        switch outcome {
        case .started:
            return .awaitCloudCompletion
        case .unavailable:
            return .useLocalFallback
        case .superseded:
            return .completeWithoutFallback
        }
    }

    static func shouldResumePendingRound(
        requestRound: Int?,
        pendingRound: Int?,
        activeRound: Int?,
        resumeRequested: Bool
    ) -> Bool {
        guard resumeRequested, let requestRound else { return false }
        return authorizesRecorderHandoff(
            expectedRound: requestRound,
            pendingRound: pendingRound,
            activeRound: activeRound
        )
    }

    static func authorizesRecorderHandoff(
        expectedRound: Int,
        pendingRound: Int?,
        activeRound: Int?
    ) -> Bool {
        expectedRound == pendingRound && expectedRound == activeRound
    }

    static func isCurrentRecorderHandoff(
        generation: UUID,
        currentGeneration: UUID?,
        expectedRound: Int,
        pendingRound: Int?,
        activeRound: Int?,
        isCancelled: Bool
    ) -> Bool {
        !isCancelled
            && generation == currentGeneration
            && authorizesRecorderHandoff(
                expectedRound: expectedRound,
                pendingRound: pendingRound,
                activeRound: activeRound
            )
    }
}
#endif

#if canImport(SwiftUI)

// MARK: - Sudden Death Practice View

@available(iOS 17.0, macOS 12.0, *)
struct SuddenDeathPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var navigationPath: NavigationPath
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var engine = PressureTimerEngine()
    // Session intent can still be attached by future inline/chat-driven
    // declarations, but Pressure never auto-interrupts setup with a focus sheet.

    /// Live Activity coordinator. Lazily initialised on first use because
    /// we need access to `engine` and `speechVM` which are
    /// `@StateObject`-resolved by SwiftUI on first body access. Built
    /// inside `start()` below.
    @State private var liveActivityCoordinator: PressureLiveActivityCoordinator?

    // UI state
    @State private var showExitConfirmation = false
    @State private var showSetupAdjustments = false
    @State private var showUncertainIndicator = false
    @State private var roundTranscript = ""
    @State private var hasDetectedSpeechThisRound = false
    @State private var evaluation: PracticeEvaluation?
    @State private var wordThresholdHapticFired = false
    @State private var enrichedResult: PressureSessionResult?
    @State private var committedFinalization: SessionFinalizationResult?
    @State private var finalizedSessionID: UUID?
    @State private var didCommitCompletedRun = false
    @State private var runHadUsableCapture = false
    @State private var recorderPreparationTask: Task<Void, Never>?
    @State private var recorderPreparationGeneration: UUID?
    #if DEBUG
    @State private var isPresentingResultFixture = false
    #endif

    // MARK: - TTS (prompt readout)
    //
    // Mirrors `TimedPracticeView`'s TTS setup so the voice the user already
    // hears in Timed practice is the same voice that reads Pressure-drill
    // prompts. The cloud path goes through `IMMessageSpeaker.speakPrompt`
    // (Google → OpenAI fallback) and falls through to an on-device
    // `AVSpeechSynthesizer` when both providers are unavailable so offline
    // users still get spoken prompts.
    //
    // Why auto-speak on the NPC turn instead of tap-to-hear (Timed's
    // pattern): Sudden Death's pressure loop gives the user only a few
    // seconds between prompt appearance and the start window opening.
    // Tap-to-hear adds friction that conflicts with the mode's intent;
    // a conversational NPC that speaks its prompt matches the
    // user-flagged expectation ("read it aloud like Timed mode does")
    // and parallels IMPracticeView's auto-speak on NPC turns.
    #if canImport(AVFAudio)
    private let ttsEngine = AVSpeechSynthesizer()
    private let ttsDelegate = TTSDelegate()
    /// Best available English voice — prefer premium / enhanced quality
    /// for warmth. Selection logic matches `TimedPracticeView`.
    private let prewarmedVoice: AVSpeechSynthesisVoice? = {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let enVoices = allVoices.filter { $0.language.hasPrefix("en") }
        if let premium = enVoices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = enVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }()
    @StateObject private var promptSpeaker = IMMessageSpeaker.shared
    @State private var promptReadoutTask: Task<Void, Never>?
    @State private var promptSpeechRequest: SuddenDeathPromptSpeechRequest?
    @State private var ownsPromptTTSAudioSession = false
    #endif
    @State private var isSpeakingPrompt = false
    /// The prompt text already spoken aloud in this round, so a
    /// re-render of `npcCard` (transcript / filler updates) doesn't
    /// re-trigger the readout mid-utterance.
    @State private var lastSpokenPromptText: String = ""
    /// The round number whose prompt was last spoken. M24 fix: pairs
    /// with `lastSpokenPromptText` to gate audio replay. Without
    /// round-tracking, round 2's `.npcTurn` entry would blank
    /// `lastSpokenPromptText` and re-speak round 1's text (which is
    /// still held in `engine.currentPromptText` until the async
    /// follow-up generation completes). Round-tracking means we only
    /// speak when EITHER the text changed OR the round changed.
    @State private var lastSpokenForRound: Int? = nil

    /// User-configurable gate that already powers IM auto-speak. We
    /// honour the same setting in Pressure mode so users who have
    /// muted NPC voices everywhere stay muted here too.
    @StateObject private var voicePlaybackSettings = IMVoicePlaybackSettingsManager.shared

    // Personal best stored in UserDefaults
    private static let personalBestKey = "pressureMode.personalBestRounds"
    private var previousBestRounds: Int {
        UserDefaults.standard.integer(forKey: Self.personalBestKey)
    }

    private let accentColor = AppColor.modeSuddenDeath

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            content
                .animation(reduceMotion ? nil : .snappySpring, value: phaseGroup)
        }
        // Note: `LiveEloquenceHUD` is intentionally NOT mounted here.
        // The chip surface fires the moment a rhetorical move lands
        // ("Rule of Three", "Anaphora", etc.) which broke rep
        // concentration mid-flow in user testing — pressure mode is
        // about staying in the response, not reading a notice about
        // it. Rhetorical findings still surface in the post-session
        // `EloquenceFindingsCard` driven by the same engine output, so
        // the user gets credit without the intra-round interruption.
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
        .accessibilityIdentifier(phaseGroup == .result ? "suddenDeath.result.screen" : "suddenDeath.screen")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(phaseGroup != .setup)
        .toolbar {
            if phaseGroup == .live {
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
        .alert("End session?", isPresented: $showExitConfirmation) {
            Button("Keep Going", role: .cancel) { }
            Button("End", role: .destructive) {
                cancelRecorderPreparation()
                speechVM.cancelRecording()
                engine.reset()
                dismiss()
            }
        } message: {
            Text("Your progress in this run will be lost.")
        }
        .sheet(isPresented: $showSetupAdjustments) {
            setupAdjustmentsSheet
        }
        .task {
            speechVM.prepareForInteractiveUse()

            #if DEBUG
            if presentRequestedResultFixtureIfNeeded() {
                return
            }
            #endif

            // Quick Start handshake — picker armed Sudden Death for a
            // one-tap launch. `beginSession` resolves a fresh prompt
            // and starts the automatic pressure ramp.
            if engine.phase == .setup, PracticeModeQuickStart.consume(for: .suddenDeath) {
                beginSession()
            }
        }
        .onChange(of: speechVM.transcribedText) { _, newText in
            guard engine.isUserTurn else { return }
            roundTranscript = newText
            engine.lastUserTranscript = newText

            // Detect speech start
            let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !hasDetectedSpeechThisRound && !trimmed.isEmpty {
                hasDetectedSpeechThisRound = true
                engine.userHasStartedSpeaking = true
                engine.userStartedSpeaking()
            }

            // Update word count
            let words = trimmed.split { !$0.isLetter && !$0.isNumber }.count
            let previousWords = engine.currentWordCount
            engine.currentWordCount = words

            // Fire a single light haptic the moment the word count crosses
            // the minimum threshold — confirms the safety net is cleared
            // without interrupting the rep.
            if !wordThresholdHapticFired,
               words >= engine.roundConfig.minimumWords,
               previousWords < engine.roundConfig.minimumWords {
                wordThresholdHapticFired = true
                CoachHaptic.xpEarned()
            }
        }
        .onChange(of: speechVM.pressureDrillFillerCount) { _, count in
            guard engine.isUserTurn else { return }
            engine.currentFillerCount = count
        }
        .onChange(of: speechVM.uncertainFillerCount) { oldVal, newVal in
            if newVal > oldVal, engine.isUserTurn {
                if reduceMotion {
                    showUncertainIndicator = true
                } else {
                    withAnimation(.easeIn(duration: 0.15)) { showUncertainIndicator = true }
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    await MainActor.run {
                        if reduceMotion {
                            showUncertainIndicator = false
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) { showUncertainIndicator = false }
                        }
                    }
                }
            }
        }
        .onChange(of: engine.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .onChange(of: engine.pendingUserWaitingRound) { _, pending in
            guard let pending else { return }
            guard !speechVM.recordingLifecycle.isBusy else { return }
            // If TTS is still speaking, confirmBeginUserWaiting() will be called
            // from the ttsDelegate.onFinish callback instead. If TTS has already
            // finished (or was never started), unblock immediately.
            if !isSpeakingPrompt {
                prepareRecorderThenBeginUserWaiting(expectedRound: pending)
            }
        }
        .onChange(of: engine.pendingCaptureEnd) { _, pending in
            guard pending != nil else { return }
            finalizeAutomaticPressureEnd()
        }
        .onChange(of: speechVM.recordingLifecycle) { _, lifecycle in
            guard case .failed = lifecycle, engine.phase != .setup else { return }
            SoundscapeEngine.shared.stop()
            stopPromptReadout()
            cancelRecorderPreparation()
            engine.reset()
        }
        .onChange(of: engine.currentPromptText) { _, newText in
            // Follow-up prompts land asynchronously after the engine
            // enters `.npcTurn`. When the text resolves, kick off the
            // readout — `speakCurrentPromptIfReady` no-ops if the same
            // prompt is already speaking so we don't double-trigger
            // for round 1 (where `npcTurn` and the text both land at
            // once).
            guard !newText.isEmpty,
                  !speechVM.recordingLifecycle.isBusy else { return }
            if case .npcTurn(let round) = engine.phase {
                speakCurrentPromptIfReady(round: round)
                if engine.pendingUserWaitingRound == round, !isSpeakingPrompt {
                    prepareRecorderThenBeginUserWaiting(expectedRound: round)
                }
            }
        }
        .onDisappear {
            // Belt-and-braces: if the user taps back during a live
            // session, kill the activity instead of leaving it dangling
            // in the Dynamic Island. The coordinator's `end()` is
            // idempotent.
            liveActivityCoordinator?.end()
            liveActivityCoordinator = nil
            // Same guard for TTS — never leave the synthesizer
            // speaking after the screen is gone.
            stopPromptReadout()
            cancelRecorderPreparation()
            speechVM.cancelRecording()
            engine.reset()
            // Pre-rep ambience is started on `.countdown` and only stopped by
            // `.userTurnWaiting` / completion. Backing out during `.npcTurn` —
            // the TTS readout plus, from round 2, an async follow-up generation
            // — reached none of those, so the soundscape kept playing over
            // whatever screen the user landed on. `stop()` is idempotent.
            SoundscapeEngine.shared.stop()
            // Drop any pending intent that wasn't consumed by a finalize.
            SessionIntentStore.shared.clearPending()
        }
    }

    // MARK: - Phase Grouping

    private enum PhaseGroup: Equatable {
        case setup, countdown, live, result
    }

    private var phaseGroup: PhaseGroup {
        switch engine.phase {
        case .setup: return .setup
        case .countdown, .go: return .countdown
        case .sessionComplete: return .result
        default: return .live
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .setup:
            setupScreen
                .transition(.opacity.combined(with: .move(edge: .leading)))

        case .countdown, .go:
            countdownScreen

        case .npcTurn(let round):
            liveScreen(round: round)
                .transition(.opacity)

        case .userTurnWaiting(let round, _):
            liveScreen(round: round)
                .transition(.opacity)

        case .userTurnActive(let round):
            liveScreen(round: round)
                .transition(.opacity)

        case .roundResult(let round, let outcome):
            liveScreen(round: round, roundOutcome: outcome)
                .transition(.opacity)

        case .sessionComplete(let result):
            if canPresentPressureResult {
                resultScreen(result: enrichedResult ?? result)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                pressureFinalizingSurface
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        if phaseGroup == .setup {
            return AnyView(FocusedPracticeBackground(style: .pressure))
        }
        let base: (Color, Color) = {
            switch phaseGroup {
            case .setup:
                return (Color(red: 0.98, green: 0.95, blue: 0.90), Color(red: 0.99, green: 0.96, blue: 0.92))
            case .countdown:
                return (Color(red: 0.96, green: 0.92, blue: 0.88), Color(red: 0.98, green: 0.94, blue: 0.88))
            case .live:
                if engine.isUserTurn {
                    // Warm shift when user is under pressure
                    return (Color(red: 0.99, green: 0.93, blue: 0.88), Color(red: 1.0, green: 0.95, blue: 0.90))
                }
                return (Color(red: 0.96, green: 0.96, blue: 0.97), Color(red: 0.98, green: 0.97, blue: 0.98))
            case .result:
                return (Color(red: 0.96, green: 0.96, blue: 0.98), Color(red: 0.98, green: 0.97, blue: 1.0))
            }
        }()

        return AnyView(LinearGradient(
            colors: [base.0, Color.white, base.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: phaseGroup)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: engine.isUserTurn))
    }

    // MARK: - Setup Screen (zero friction)

    private var setupScreen: some View {
        FocusedPracticeScaffold(
            style: .pressure,
            status: "Pressure Drill",
            title: "Stay direct under pressure.",
            subtitle: "Each round gives you less time to respond."
        ) {
            Button {
                CoachHaptic.selectionTap()
                showSetupAdjustments = true
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
            .accessibilityIdentifier("suddenDeath.adjust")
            .accessibilityLabel("Adjust pressure drill")
        } content: {
            VStack(spacing: Spacing.lg) {
                HStack(alignment: .center, spacing: Spacing.md) {
                    Image(systemName: "waveform.badge.exclamationmark")
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                        .accessibilityHidden(true)

                    Text("A filler, slow start, or short response ends the drill.")
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(AppColor.focusedTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(Spacing.md)
                .focusedGlassSurface()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("A filler, slow start, or short response ends the drill.")

                if let error = speechVM.connectionError {
                    FocusedPracticeErrorStatus(message: error)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                beginSession()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.headline)
                    Text("Start pressure drill")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(AppColor.warning)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(.white, in: Capsule())
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, Spacing.screenH)
            .padding(.vertical, Spacing.sm)
            .background(Color.black.opacity(0.10).ignoresSafeArea())
            .accessibilityIdentifier("suddenDeath.begin")
        }
    }

    private var setupAdjustmentsSheet: some View {
        NavigationStack {
            List {
                Section("How the drill works") {
                    ruleRow(icon: "timer", text: "A prompt appears. You have seconds to start speaking.")
                    ruleRow(icon: "arrow.turn.right.up", text: "Noum follows up based on your answer.")
                    ruleRow(icon: "waveform.badge.exclamationmark", text: "One filler, a slow start, or a short response ends the drill.")
                    ruleRow(icon: "flame.fill", text: "Pressure increases every round.")
                }

                Section("Prompt audio") {
                    Toggle(isOn: $voicePlaybackSettings.isEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Read prompts aloud")
                                .font(Typography.body.weight(.semibold))
                            Text("Uses your existing conversation voice setting.")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(accentColor)
                    .accessibilityIdentifier("suddenDeath.adjust.promptAudio")
                }

                if previousBestRounds > 0 {
                    Section("Personal best") {
                        Label("Round \(previousBestRounds)", systemImage: "trophy.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.screenBackground)
            .navigationTitle("Adjust pressure drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showSetupAdjustments = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Countdown Screen

    private var countdownScreen: some View {
        Group {
            if case .countdown(let value) = engine.phase {
                FocusedPracticeCountdownOverlay(
                    style: .pressure,
                    value: "\(value)",
                    subtitle: "Get ready"
                )
            } else if case .go = engine.phase {
                FocusedPracticeCountdownOverlay(
                    style: .pressure,
                    value: "GO",
                    subtitle: "Start speaking"
                )
            }
        }
    }

    // MARK: - Live Challenge Screen

    private func liveScreen(round: Int, roundOutcome: RoundOutcome? = nil) -> some View {
        let isUserTurn = engine.isUserTurn

        return VStack(spacing: 0) {
            // Top bar: round + survival dots
            topBar(round: round)

            // Goal-aware intent reminder — fires once per session (not per
            // round) so the user sees what voice they're working toward
            // without being re-prompted each pressure turn. Silent when
            // no CoachingProfile is set.
            if let voice = coachingProfileStore.profile?.chosenStyleGoal {
                VoiceAnchorBanner(
                    styleGoal: voice,
                    isRecording: speechVM.isRecording,
                    resetsBetweenReps: false
                )
            }

            // Start timer bar — only visible during userTurnWaiting
            if engine.isStartTimerActive {
                timerBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Turn cards
            VStack(spacing: 12) {
                // NPC / Prompt card — stays expanded while TTS is reading aloud
                // even if the phase has already moved to userTurnWaiting, so the
                // user can read/hear the full prompt before the start timer opens.
                npcCard(round: round, expanded: (!isUserTurn || isSpeakingPrompt) && roundOutcome == nil)

                // User response card
                userCard(round: round, expanded: isUserTurn)

                // Round outcome flash
                if let outcome = roundOutcome {
                    roundOutcomeCard(outcome)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, 12)
            .frame(maxHeight: .infinity)

            // Bottom: Done button when user is actively speaking
            if case .userTurnActive = engine.phase {
                doneButton
            }
        }
    }

    // MARK: Top Bar

    private func topBar(round: Int) -> some View {
        HStack {
            NoumWaveformMark(
                state: speechVM.isRecording ? .listening : .idle,
                level: speechVM.audioLevel,
                tint: accentColor,
                size: 32
            )
            .accessibilityHidden(true)

            // Round label
            Text("Round \(round)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accentColor)

            Spacer()

            // Survival dots (show all completed + current)
            HStack(spacing: 4) {
                ForEach(0..<max(round, engine.roundOutcomes.count), id: \.self) { i in
                    Circle()
                        .fill(dotColor(for: i, currentRound: round))
                        .frame(width: i + 1 == round ? 10 : 7, height: i + 1 == round ? 10 : 7)
                        .animation(reduceMotion ? nil : .standardSpring, value: round)
                }
            }

            // Uncertain filler "?" indicator
            if showUncertainIndicator {
                Text("?")
                    .font(Typography.figtree(size: 14, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.orange.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.12), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.vertical, 10)
    }

    private func dotColor(for index: Int, currentRound: Int) -> Color {
        if index < engine.roundOutcomes.count {
            return engine.roundOutcomes[index].isFailed ? .red : .green
        }
        if index + 1 == currentRound {
            return accentColor
        }
        return Color.secondary.opacity(0.2)
    }

    // MARK: Timer Bar (start timer only — disappears once user speaks)

    private var timerBar: some View {
        GeometryReader { geo in
            let fraction = engine.timerFraction
            let isUrgent = fraction > 0.70
            let isCritical = fraction > 0.88
            let barColor: Color = isCritical ? .red : (isUrgent ? .orange : accentColor)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.secondary.opacity(0.12))

                RoundedRectangle(cornerRadius: 2.5)
                    .fill(barColor)
                    .frame(width: geo.size.width * (1.0 - fraction))
                    .animation(reduceMotion ? nil : .linear(duration: 0.05), value: fraction)
            }
            .frame(height: isCritical ? 5 : 3)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isCritical)
        }
        .frame(height: 5)
        .padding(.horizontal, Spacing.screenH)
    }

    // MARK: NPC Card (prompt / follow-up)

    private func npcCard(round: Int, expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)
                Text(engine.roundConfig.isFollowUp && round > 1 ? "Follow-up" : "Prompt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // Speaker glyph — visible whenever the prompt is the
                // focal card. Tap = replay readout (cancel if already
                // speaking). Matches the affordance Timed users see
                // and reuses the same TTS path.
                if expanded && !engine.isGeneratingFollowUp {
                    speakerReplayButton
                }

                if expanded {
                    startTimerBadge
                }
            }

            if engine.isGeneratingFollowUp {
                // Typing indicator
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(accentColor.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .scaleEffect(typingDotScale(index: i))
                    }
                    Text("thinking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                Text(engine.currentPromptText)
                    .font(expanded ? .title3.weight(.semibold) : .subheadline)
                    .foregroundStyle(expanded ? .primary : .secondary)
                    // 3-line floor when collapsed so the prompt stays
                    // readable even if the TTS completion gating fires early.
                    .lineLimit(expanded ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Threshold hint — only shown on the expanded prompt card and
            // only when we know what bar applies to the response (i.e.
            // a real round, not the typing indicator). Tells the user
            // exactly how many words they need to clear "Too short" so
            // a short answer never feels like an unexplained failure.
            // Reduce-motion users get the same content with no fade
            // animation (handled by SwiftUI's environment).
            if expanded && !engine.isGeneratingFollowUp {
                thresholdHint
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(expanded ? Spacing.lg : Spacing.md)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(expanded ? accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(expanded ? 1.0 : 0.92, anchor: .top)
        .opacity(expanded ? 1.0 : 0.5)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: expanded)
    }

    /// Small unobtrusive capsule that surfaces this round's minimum-word
    /// threshold. Sentence-case, no exclamation, neutral tint so it reads
    /// as guidance, not pressure.
    private var thresholdHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "text.alignleft")
                .font(.caption2.weight(.semibold))
            Text("Aim for \(engine.roundConfig.minimumWords)+ words")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.08))
        )
        .accessibilityLabel("Aim for at least \(engine.roundConfig.minimumWords) words; shorter answers end the drill.")
    }

    /// Replay button for the prompt-read-aloud. Mirrors Timed's
    /// "Tap to hear" affordance — same glyph, same `.variableColor`
    /// pulse while speaking. Hidden when AVFAudio isn't available
    /// (covers preview / non-iOS targets).
    @ViewBuilder
    private var speakerReplayButton: some View {
        #if canImport(AVFAudio)
        Button {
            speakCurrentPrompt(force: true)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isSpeakingPrompt ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .font(.caption2.weight(.semibold))
                    // Reduce Motion: a repeating colour pulse is ambient motion.
                    .symbolEffect(.variableColor.iterative, isActive: isSpeakingPrompt && !reduceMotion)
            }
            .foregroundStyle(accentColor.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.10))
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isSpeakingPrompt ? "Stop reading prompt" : "Read prompt aloud")
        #else
        EmptyView()
        #endif
    }

    @State private var typingDotPhase: Int = 0

    private func typingDotScale(index: Int) -> CGFloat {
        // Simple pulsing per dot
        let phase = (typingDotPhase + index) % 3
        return phase == 0 ? 1.3 : 0.8
    }

    // MARK: Start Timer Badge (inside NPC card or user card header)

    @ViewBuilder
    private var startTimerBadge: some View {
        if engine.isStartTimerActive {
            let remaining = engine.displayRemaining
            let isUrgent = engine.timerFraction > 0.70
            let isCritical = engine.timerFraction > 0.88

            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption2.weight(.bold))
                Text("\(Int(ceil(remaining)))s")
                    .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
            }
            .foregroundStyle(isCritical ? .red : (isUrgent ? .orange : accentColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (isCritical ? Color.red : (isUrgent ? Color.orange : accentColor))
                    .opacity(isCritical ? 0.15 : 0.08),
                in: Capsule()
            )
            .scaleEffect(isCritical ? 1.08 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isCritical)
        }
    }

    // MARK: User Response Card

    private func userCard(round: Int, expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(expanded ? accentColor : .secondary)
                Text("You")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // Timer badge when user is waiting to start
                if expanded {
                    startTimerBadge
                }
            }

            if expanded {
                // Live transcript
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        if roundTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if case .userTurnWaiting = engine.phase {
                                Text("Start speaking...")
                                    .font(.body)
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .italic()
                            } else {
                                Text("Listening...")
                                    .font(.body)
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .italic()
                            }
                        } else {
                            Text(speechVM.highlightedText)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)

                // Live word counter — only during active speaking, not waiting.
                // Color shifts from secondary to primary as the user approaches
                // the minimum threshold. A light haptic fires on the exact frame
                // the threshold is crossed (see onChange(transcribedText)).
                if case .userTurnActive = engine.phase {
                    wordCounter
                }
            } else {
                if !roundTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(roundTranscript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: expanded ? .infinity : nil)
        .padding(expanded ? Spacing.lg : Spacing.md)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(
                    expanded ? accentColor.opacity(0.3) : Color.clear,
                    lineWidth: expanded ? 2 : 1
                )
        )
        .scaleEffect(expanded ? 1.0 : 0.92, anchor: .bottom)
        .opacity(expanded ? 1.0 : 0.5)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: expanded)
    }

    // MARK: Word Counter (live, during userTurnActive)

    private var wordCounter: some View {
        let words = engine.currentWordCount
        let minimum = engine.roundConfig.minimumWords
        let met = words >= minimum
        let approaching = words >= max(0, minimum - 3)
        let foreground: Color = met ? .primary : (approaching ? accentColor : .secondary)

        return HStack(spacing: 4) {
            Image(systemName: met ? "checkmark.circle" : "text.alignleft")
                .font(.caption2.weight(.semibold))
            Text("\(words)/\(minimum) words")
                .font(.system(.caption, design: .rounded).weight(.medium).monospacedDigit())
        }
        .foregroundStyle(foreground)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: met)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: approaching)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel("\(words) of \(minimum) words spoken")
    }

    // MARK: Round Outcome Card

    private func roundOutcomeCard(_ outcome: RoundOutcome) -> some View {
        HStack(spacing: 12) {
            Image(systemName: outcome.icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(outcome.isFailed ? .red : .green)

            VStack(alignment: .leading, spacing: 2) {
                Text(outcome.label)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(outcome.isFailed ? .red : .green)
                Text(outcome.isFailed ? "Round over" : "Next round…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            (outcome.isFailed ? Color.red : Color.green).opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
    }

    // MARK: Done Button

    private var doneButton: some View {
        Button {
            Task { @MainActor in
                guard engine.pendingCaptureEnd == nil, speechVM.isRecording else { return }
                engine.pauseForCaptureFinalization()
                let completion = await speechVM.stopRecordingAwaitingFinalization()
                guard RecordingCompletionGate.allowsScoringAndProgress(completion) else {
                    engine.reset()
                    return
                }
                if let completion {
                    engine.reconcileFinalizedTranscript(completion.text)
                }
                engine.currentFillerCount = speechVM.pressureDrillFillerCount
                runHadUsableCapture = true
                engine.userEndedTurn(captureDuration: speechVM.lastSessionDuration)
            }
        } label: {
            Text("Done")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.green.gradient, in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(!speechVM.isRecording || engine.pendingCaptureEnd != nil)
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Result Screen

    private func resultScreen(result: PressureSessionResult) -> some View {
        SuddenDeathResultView(
            result: result,
            highScoreStore: .shared,
            runHistoryStore: .shared,
            onRetry: {
                guard canPresentPressureResult else { return }
                finalizeSession(result: result)
                retrySession()
            },
            onSeeFullSummary: {
                guard canPresentPressureResult else { return }
                finalizeSession(result: result)
                pushSummary(result: result)
            }
        )
    }

    // MARK: - Session Control

    #if DEBUG
    private func presentRequestedResultFixtureIfNeeded() -> Bool {
        guard let fixture = SuddenDeathResultFixture.requested() else { return false }
        isPresentingResultFixture = true
        SuddenDeathRunHistoryStore.shared.replaceForDebug(fixture.priorRuns)
        SuddenDeathHighScoreStore.shared.replaceBestPointsForDebug(fixture.previousBestPoints)
        engine.presentResultForUITesting(fixture.result)
        return true
    }
    #endif

    private func beginSession() {
        // Commitment register, matching Timed and Filler Control. Fires before
        // the prompt hop so the tap feels immediate even when topic selection
        // takes a beat.
        CoachHaptic.drillStart()
        Task { @MainActor in
            let openingPrompt = await PracticeTopics.next(
                profile: coachingProfileStore.profile,
                baseline: baselineStore.baseline
            )
            resetSpeechState()
            engine.configure(
                openingPrompt: openingPrompt,
                followUpProvider: PressureFollowUpService.shared,
                previousBest: previousBestRounds
            )
            engine.beginCountdown()
        }
    }

    private func retrySession() {
        CoachHaptic.drillStart()
        Task { @MainActor in
            let openingPrompt = await PracticeTopics.next(
                profile: coachingProfileStore.profile,
                baseline: baselineStore.baseline
            )
            resetSpeechState()
            engine.configure(
                openingPrompt: openingPrompt,
                followUpProvider: PressureFollowUpService.shared,
                previousBest: previousBestRounds
            )
            engine.beginCountdown()
        }
    }

    private func resetSpeechState() {
        speechVM.cancelRecording()
        speechVM.resetCurrentSession()
        speechVM.shouldRecordPracticeSession = false
        roundTranscript = ""
        hasDetectedSpeechThisRound = false
        evaluation = nil
        enrichedResult = nil
        committedFinalization = nil
        finalizedSessionID = nil
        didCommitCompletedRun = false
        runHadUsableCapture = false
        cancelRecorderPreparation()
    }

    // MARK: - Phase Change Handler

    /// Start (lazily) the Pressure Live Activity coordinator at the
    /// transition from `.setup` to anything live. Subsequent phase
    /// changes are observed by the coordinator's own subscription.
    private func startLiveActivityIfNeeded() {
        guard liveActivityCoordinator == nil else { return }
        let coordinator = PressureLiveActivityCoordinator(
            engine: engine,
            modeLabel: "Pressure Drill",
            fillerCountProvider: { [weak speechVM = self.speechVM] in
                speechVM?.pressureDrillFillerCount ?? 0
            }
        )
        coordinator.start()
        liveActivityCoordinator = coordinator
    }

    private func handlePhaseChange(_ newPhase: PressureTurnPhase) {
        #if DEBUG
        if isPresentingResultFixture, case .sessionComplete = newPhase {
            return
        }
        #endif

        // Kick off the Live Activity the first time the engine moves
        // away from setup. Ending the activity is handled inside the
        // coordinator on `.sessionComplete`.
        if newPhase != .setup {
            startLiveActivityIfNeeded()
        }
        switch newPhase {
        case .setup:
            stopPromptReadout()
            cancelRecorderPreparation()

        case .countdown:
            // Pre-rep ambience runs only through the countdown so it
            // never bleeds into the rep itself or the NPC's turn.
            SoundscapeEngine.shared.startPreferredMode()

        case .npcTurn(let round):
            // Reset transcript for new round
            if speechVM.isRecording {
                Task { @MainActor in
                    let completion = await speechVM.stopRecordingAwaitingFinalization()
                    guard RecordingCompletionGate.allowsScoringAndProgress(completion) else {
                        engine.reset()
                        return
                    }
                    if let completion {
                        engine.reconcileFinalizedTranscript(completion.text)
                    }
                    runHadUsableCapture = true
                    speechVM.resetCurrentSession()
                    prepareNpcTurnAfterRecorderStopped(round: round)
                }
            } else {
                speechVM.resetCurrentSession()
                prepareNpcTurnAfterRecorderStopped(round: round)
            }
            roundTranscript = ""
            hasDetectedSpeechThisRound = false
            // M24 fix — do NOT blank lastSpokenPromptText here. On round 2+,
            // engine.currentPromptText still holds the PREVIOUS round's
            // text (the new one is generated async via isGeneratingFollowUp).
            // Blanking the cache would let speakCurrentPromptIfReady fire
            // again on the stale text and replay round 1's audio. Instead,
            // we rely on lastSpokenForRound to invalidate per-round, and
            // the natural text-change in onChange(currentPromptText) to
            // detect the new prompt arrival.
            wordThresholdHapticFired = false

        case .userTurnWaiting:
            // Start recording for this round; cut soundscape if it's
            // still running so it doesn't compete with the user's voice.
            SoundscapeEngine.shared.stop()
            // Kill any in-flight TTS so the mic isn't competing with
            // the synthesizer when the start window opens. The
            // synthesizer's `.duckOthers` audio session would dip the
            // mic input otherwise.
            stopPromptReadout()
            // The recorder was connected before this phase was allowed to
            // start, so the pressure countdown never spends connection time.
            guard speechVM.isRecording else {
                engine.reset()
                return
            }

        case .sessionComplete(let result):
            SoundscapeEngine.shared.stop()
            stopPromptReadout()
            cancelRecorderPreparation()
            #if DEBUG
            if isPresentingResultFixture {
                enrichedResult = result
                return
            }
            #endif
            let pitchMetrics = speechVM.currentSessionPitchMetrics()
            Task { @MainActor in
                var resolvedResult = result
                if speechVM.isRecording {
                    let completion = await speechVM.stopRecordingAwaitingFinalization()
                    guard RecordingCompletionGate.allowsScoringAndProgress(completion) else {
                        engine.reset()
                        return
                    }
                    if let completion,
                       let reconciled = engine.reconcileFinalizedTranscript(completion.text) {
                        resolvedResult = reconciled
                    }
                    runHadUsableCapture = true
                }
                guard runHadUsableCapture,
                      !engine.sessionTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    engine.reset()
                    return
                }

                var enriched = resolvedResult
                enriched.pitchMetrics = pitchMetrics
                enriched.wordChoiceMetrics = WordChoiceMetrics.compute(transcript: engine.sessionTranscript)
                enriched.eloquenceFindings = EloquenceEngine.analyse(transcript: engine.sessionTranscript)
                if resolvedResult.totalDuration > 0 {
                    enriched.sessionWPM = Double(resolvedResult.totalWords) / (resolvedResult.totalDuration / 60.0)
                }
                enrichedResult = enriched
                finalizeSession(result: enriched)
            }

        default:
            break
        }
    }

    /// Starts NPC UI/TTS only after the prior microphone stream has returned
    /// its terminal receipt. A follow-up voice must never enter the tail of the
    /// user's transcript or compete for the active audio session.
    private func prepareNpcTurnAfterRecorderStopped(round: Int) {
        guard case .npcTurn(let currentRound) = engine.phase,
              currentRound == round,
              !speechVM.recordingLifecycle.isBusy else { return }
        startTypingAnimation()
        speakCurrentPromptIfReady(round: round)
        if engine.pendingUserWaitingRound == round, !isSpeakingPrompt {
            prepareRecorderThenBeginUserWaiting(expectedRound: round)
        }
    }

    private func finalizeAutomaticPressureEnd() {
        guard engine.pendingCaptureEnd != nil, speechVM.isRecording else { return }
        Task { @MainActor in
            let completion = await speechVM.stopRecordingAwaitingFinalization()
            guard RecordingCompletionGate.allowsScoringAndProgress(completion) else {
                engine.reset()
                return
            }
            if let completion {
                engine.reconcileFinalizedTranscript(completion.text)
            }
            engine.currentFillerCount = speechVM.pressureDrillFillerCount
            runHadUsableCapture = true
            engine.confirmPendingCaptureEnd(
                captureDuration: speechVM.lastSessionDuration
            )
        }
    }

    /// Connect the provider and microphone before opening the pressure start
    /// window. The engine keeps `pendingUserWaitingRound` armed until this
    /// succeeds, so network latency can never count as a slow start.
    private func prepareRecorderThenBeginUserWaiting(expectedRound: Int) {
        guard recorderHandoffIsCurrent(expectedRound),
              recorderPreparationGeneration == nil else {
            return
        }
        let generation = UUID()
        recorderPreparationGeneration = generation
        recorderPreparationTask = Task { @MainActor in
            defer {
                if recorderPreparationGeneration == generation {
                    recorderPreparationGeneration = nil
                    recorderPreparationTask = nil
                }
            }

            // A prior round may still be returning its provider receipt while
            // the next prompt is being read. Give that bounded finalization
            // the same window as the provider contract before opening a new mic.
            let deadline = ContinuousClock.now + .seconds(6)
            while speechVM.recordingLifecycle.isBusy {
                guard recorderPreparationIsCurrent(
                    generation,
                    expectedRound: expectedRound,
                    isCancelled: Task.isCancelled
                ) else {
                    return
                }
                guard ContinuousClock.now < deadline else {
                    if recorderPreparationIsCurrent(
                        generation,
                        expectedRound: expectedRound,
                        isCancelled: Task.isCancelled
                    ) {
                        engine.reset()
                    }
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    return
                }
            }

            guard recorderPreparationIsCurrent(
                generation,
                expectedRound: expectedRound,
                isCancelled: Task.isCancelled
            ) else {
                return
            }
            speechVM.resetCurrentSession()
            speechVM.shouldRecordPracticeSession = false
            speechVM.prepareSession(mode: .suddenDeath)
            speechVM.pressureDrillPrompt = engine.currentPromptText
            guard await speechVM.startRecordingAwaitingReadiness() else {
                if recorderPreparationIsCurrent(
                    generation,
                    expectedRound: expectedRound,
                    isCancelled: Task.isCancelled
                ) {
                    engine.reset()
                }
                return
            }
            guard recorderPreparationIsCurrent(
                generation,
                expectedRound: expectedRound,
                isCancelled: Task.isCancelled
            ) else {
                speechVM.cancelRecording()
                return
            }
            engine.confirmBeginUserWaiting(captureReady: true)
        }
    }

    private func recorderHandoffIsCurrent(_ expectedRound: Int) -> Bool {
        let activeRound: Int?
        if case .npcTurn(let round) = engine.phase {
            activeRound = round
        } else {
            activeRound = nil
        }
        return SuddenDeathPromptReadoutPolicy.authorizesRecorderHandoff(
            expectedRound: expectedRound,
            pendingRound: engine.pendingUserWaitingRound,
            activeRound: activeRound
        )
    }

    private func recorderPreparationIsCurrent(
        _ generation: UUID,
        expectedRound: Int,
        isCancelled: Bool
    ) -> Bool {
        let activeRound: Int?
        if case .npcTurn(let round) = engine.phase {
            activeRound = round
        } else {
            activeRound = nil
        }
        return SuddenDeathPromptReadoutPolicy.isCurrentRecorderHandoff(
            generation: generation,
            currentGeneration: recorderPreparationGeneration,
            expectedRound: expectedRound,
            pendingRound: engine.pendingUserWaitingRound,
            activeRound: activeRound,
            isCancelled: isCancelled
        )
    }

    private func cancelRecorderPreparation() {
        recorderPreparationGeneration = nil
        recorderPreparationTask?.cancel()
        recorderPreparationTask = nil
    }

    private var canPresentPressureResult: Bool {
        #if DEBUG
        if isPresentingResultFixture { return true }
        #endif
        return didCommitCompletedRun && runHadUsableCapture
    }

    private var pressureFinalizingSurface: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(accentColor)
            Text("Finishing your recording…")
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finishing your recording")
    }

    private func startTypingAnimation() {
        guard !reduceMotion else {
            typingDotPhase = 0
            return
        }
        Task {
            while engine.isGeneratingFollowUp {
                withAnimation(.easeInOut(duration: 0.3)) {
                    typingDotPhase = (typingDotPhase + 1) % 3
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    private func finalizeSession(result: PressureSessionResult) {
        #if DEBUG
        if !isPresentingResultFixture {
            guard runHadUsableCapture,
                  !engine.sessionTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        }
        #else
        guard runHadUsableCapture,
              !engine.sessionTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        #endif
        guard !didCommitCompletedRun else { return }
        didCommitCompletedRun = true

        let transcript = engine.sessionTranscript
        let eval = PracticeEvaluator.evaluateSuddenDeathPractice(
            transcript: transcript,
            fillerCount: result.totalFillers,
            duration: result.totalDuration,
            pressureEventsHandled: result.roundsSurvived,
            recentSessions: speechVM.pastSessions,
            profile: coachingProfileStore.profile
        )
        evaluation = eval

        speechVM.annotateLatestSession(
            score: result.score,
            xpEarned: result.xpEarned,
            headline: result.resultLabel,
            insights: [
                "Survived \(result.roundsSurvived) rounds",
                result.totalFillers == 0 ? "Zero fillers under pressure" : "\(result.totalFillers) filler(s) detected"
            ],
            coachSummary: eval.feedback,
            categoryRatings: eval.categories.persistedCategoryRatings
        )

        let pressureOn = PracticeSettingsManager.shared.pressureModeEnabled
        let pressure = BaselineEngine.classifyPressure(
            mode: .suddenDeath,
            isPressureModeOn: pressureOn,
            streakDays: PracticeSession.calculateStreak(from: PracticeSessionStore.shared.sessions)
        )
        let session = PracticeSessionFinalizer.finalize(
            store: PracticeSessionStore.shared,
            draft: PracticeSessionDraft(
                transcript: transcript,
                fillerWordCount: result.totalFillers,
                duration: result.totalDuration,
                date: Date(),
                mode: .suddenDeath,
                pressureLevel: pressure,
                isRated: pressureOn,
                practiceDemand: .suddenDeath(difficulty: result.difficulty),
                pauseMetrics: speechVM.currentSessionPauseMetrics()
            ),
            annotation: PracticeSessionAnnotation(
                score: result.score,
                xpEarned: result.xpEarned,
                headline: result.resultLabel,
                insights: [
                    "Survived \(result.roundsSurvived) rounds",
                    "Ended: \(result.finalOutcome.label)"
                ],
                coachSummary: eval.feedback,
                categoryRatings: eval.categories.persistedCategoryRatings
            )
        )
        finalizedSessionID = session.id
        committedFinalization = SessionFinalizer.finalize(
            xpEarned: result.xpEarned,
            scoreValue: result.score,
            effectiveFillerCount: result.totalFillers,
            effectiveDuration: result.totalDuration,
            transcriptWordCount: result.totalWords,
            scoreBreakdown: eval.segments,
            currentMode: .suddenDeath,
            sessionPrompt: engine.currentPromptText,
            latestSessionID: session.id,
            recentSessions: PracticeSessionStore.shared.sessions,
            imConversationDetails: nil,
            practiceTitle: "Pressure Drill",
            derivedInsightsFirst: eval.insights.first,
            pressureLevel: pressure,
            transcript: transcript
        )

        guard result.isProgressEligible else {
            print("[PressureDrill] Review-only capture persisted without game progress")
            return
        }

        // Persist personal best
        if result.roundsSurvived > previousBestRounds {
            UserDefaults.standard.set(result.roundsSurvived, forKey: Self.personalBestKey)
        }

        if result.roundsSurvived >= 4 {
            CoachHaptic.pressureSessionComplete()
        } else {
            // A shorter run still finished a rep. Leaving it silent made the
            // weaker outcome feel ignored while the strong one was celebrated —
            // the inverse of the never-punish-shame rule. `drillIncomplete` is
            // the acknowledgment register for exactly this: a soft single tap,
            // never a fail-buzzer.
            CoachHaptic.drillIncomplete()
        }
        print("[PressureDrill] Session finalized: \(result.resultLabel), score \(result.score), rounds \(result.roundsSurvived)")
    }

    // MARK: - Summary Navigation

    private func pushSummary(result: PressureSessionResult) {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: AttributedString(engine.sessionTranscript),
            fillerCount: result.totalFillers,
            duration: result.totalDuration,
            score: result.score,
            progressSegments: result.roundsSurvived,
            xpEarned: result.xpEarned,
            finalizedSessionID: finalizedSessionID,
            committedFinalization: committedFinalization,
            suddenDeathGamePoints: result.gamePoints,
            suddenDeathMultiplierLabels: result.multiplierLabels,
            suddenDeathTotalWords: result.totalWords,
            showDuration: true,
            practiceTitle: "Pressure Drill",
            feedbackOverride: evaluation?.feedback,
            headlineOverride: result.resultLabel,
            scoreBreakdown: evaluation?.segments ?? [],
            insights: evaluation?.insights ?? [],
            recentSessions: [],
            imConversationDetails: nil,
            explicitMode: .suddenDeath,
            recordingURL: nil,
            sessionPrompt: engine.currentPromptText,
            sessionTheme: nil,
            feedbackCategories: [],
            strongMoments: [],
            weakMoments: [],
            durationAssessment: .onTarget,
            targetRange: (15, 30, 60),
            onStartDrill: nil
        )
        SummaryDataStore.shared.store(entry, for: payloadId)
        let payload = SummaryPayload(id: payloadId, mode: .suddenDeath)
        navigationPath.append(AppDestination.summary(payload))
    }

    // MARK: - TTS (mirrors TimedPracticeView.speakPromptAloud pattern)

    #if canImport(AVFAudio)
    /// Wire the shared utterance-bound delegate. Completion behavior is
    /// registered per request immediately before `speak`, so a delayed
    /// callback from an older utterance cannot advance a successor round.
    private func configureTTSDelegate() {
        ttsEngine.delegate = ttsDelegate
    }

    /// `.playback` + `.mixWithOthers + .duckOthers` so speech plays in
    /// silent mode without fighting the speech recognizer's session.
    private func activateTTSAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal — TTS may still work on some devices without
            // explicit activation.
        }
    }

    /// Release the session so the speech recognizer can reclaim it
    /// without contention when the user-turn window opens.
    private func deactivateTTSAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal
        }
    }

    private var activeNpcRound: Int? {
        guard case .npcTurn(let round) = engine.phase else { return nil }
        return round
    }

    private func promptRequestIsCurrent(
        _ request: SuddenDeathPromptSpeechRequest,
        isCancelled: Bool = false
    ) -> Bool {
        SuddenDeathPromptReadoutPolicy.isCurrent(
            request,
            currentRequest: promptSpeechRequest,
            activeRound: activeNpcRound,
            currentPrompt: engine.currentPromptText,
            isCancelled: isCancelled
        )
    }

    /// Finish only the exact request that still owns prompt playback. The
    /// pending round is resumed only when it still matches that request and
    /// the engine remains on the same NPC turn.
    private func completePromptReadout(
        _ request: SuddenDeathPromptSpeechRequest,
        deactivateLocalAudio: Bool,
        resumePendingRound: Bool
    ) {
        guard promptSpeechRequest == request else { return }
        promptSpeechRequest = nil
        promptReadoutTask = nil
        isSpeakingPrompt = false
        if deactivateLocalAudio, ownsPromptTTSAudioSession {
            ownsPromptTTSAudioSession = false
            deactivateTTSAudioSession()
        }

        let activeRound = activeNpcRound
        guard SuddenDeathPromptReadoutPolicy.shouldResumePendingRound(
            requestRound: request.round,
            pendingRound: engine.pendingUserWaitingRound,
            activeRound: activeRound,
            resumeRequested: resumePendingRound
        ) else {
            return
        }
        prepareRecorderThenBeginUserWaiting(expectedRound: request.round)
    }

    /// Auto-speak guard. Fires from `.npcTurn` phase change and from the
    /// async follow-up prompt arrival. Skips silently when:
    ///   • user has muted NPC voice playback (IMVoicePlaybackSettings)
    ///   • the prompt is empty (still generating)
    ///   • we've already spoken for this round AND the text is unchanged
    ///     (M24 fix — round-tracking prevents replaying round 1's text
    ///     when round 2's .npcTurn fires before the async follow-up text
    ///     arrives)
    private func speakCurrentPromptIfReady(round: Int) {
        guard voicePlaybackSettings.isEnabled else { return }
        let prompt = engine.currentPromptText
        guard !prompt.isEmpty else { return }
        // M25 fix — guard on text alone. The old "round + text" AND-guard
        // missed the round-2 stale-text case: when `.npcTurn(2)` fired
        // before the async round-2 prompt arrived, `engine.currentPromptText`
        // still held round 1's text, but `lastSpokenForRound` (1) ≠ round
        // (2), so the AND-guard fell through and replayed round 1's audio.
        // Text-only guard refuses to re-speak the same prompt regardless of
        // which round claims to own it; the natural onChange(currentPromptText)
        // path fires the real new prompt when it actually arrives async.
        if prompt == lastSpokenPromptText { return }
        speakCurrentPrompt(force: false, round: round)
    }

    /// User-initiated speak (the replay button). `force == true` toggles
    /// off mid-utterance so a second tap stops the readout instead of
    /// queuing another. `round` is the round whose prompt is being
    /// spoken; the replay button passes the current phase's round.
    private func speakCurrentPrompt(force: Bool, round: Int? = nil) {
        let prompt = engine.currentPromptText
        guard !prompt.isEmpty,
              let activeRound = activeNpcRound,
              round == nil || round == activeRound else {
            return
        }

        if let activeRequest = promptSpeechRequest,
           activeRequest.round != activeRound || activeRequest.prompt != prompt {
            // A newly published follow-up owns the surface now. Invalidate the
            // previous request before starting it so no stale continuation can
            // clear the successor.
            stopPromptReadout()
        } else if isSpeakingPrompt || ttsEngine.isSpeaking {
            if force {
                stopPromptReadout(resumePendingRound: true)
            }
            return
        }

        promptReadoutTask?.cancel()
        promptSpeaker.stop()
        let request = SuddenDeathPromptSpeechRequest(
            id: UUID(),
            round: activeRound,
            prompt: prompt
        )
        promptSpeechRequest = request
        isSpeakingPrompt = true
        lastSpokenPromptText = prompt
        lastSpokenForRound = activeRound

        promptReadoutTask = Task { @MainActor in
            // Cloud TTS first (Google/OpenAI) for premium voice quality;
            // on-device AVSpeechSynthesizer as the offline fallback so
            // users without network still get spoken prompts.
            let outcome = await promptSpeaker.speakPrompt(prompt)
            guard promptRequestIsCurrent(
                request,
                isCancelled: Task.isCancelled
            ) else {
                return
            }

            switch SuddenDeathPromptReadoutPolicy.action(for: outcome) {
            case .awaitCloudCompletion:
                // `speakPrompt` resolves when real playback starts. Observe the
                // shared player's published lifecycle rather than guessing clip
                // length from word count.
                while promptSpeaker.isSpeaking {
                    do {
                        try await Task.sleep(for: .milliseconds(50))
                    } catch {
                        return
                    }
                    guard promptRequestIsCurrent(
                        request,
                        isCancelled: Task.isCancelled
                    ) else {
                        return
                    }
                }
                guard promptRequestIsCurrent(
                    request,
                    isCancelled: Task.isCancelled
                ) else {
                    return
                }
                completePromptReadout(
                    request,
                    deactivateLocalAudio: false,
                    resumePendingRound: true
                )
                return

            case .completeWithoutFallback:
                // Another shared-speaker request won authority before this one
                // started. Do not replay stale text locally, but do terminate
                // this exact request so the pressure round cannot stick.
                completePromptReadout(
                    request,
                    deactivateLocalAudio: false,
                    resumePendingRound: true
                )
                return

            case .useLocalFallback:
                if ttsEngine.delegate == nil { configureTTSDelegate() }
                activateTTSAudioSession()
                ownsPromptTTSAudioSession = true
                let utterance = AVSpeechUtterance(string: prompt)
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
                utterance.pitchMultiplier = 0.98
                utterance.preUtteranceDelay = 0.15
                utterance.postUtteranceDelay = 0.3
                utterance.voice = prewarmedVoice
                let completion = { [self] in
                    completePromptReadout(
                        request,
                        deactivateLocalAudio: true,
                        resumePendingRound: true
                    )
                }
                ttsDelegate.track(
                    utterance,
                    onFinish: completion,
                    onCancel: completion
                )
                guard promptRequestIsCurrent(
                    request,
                    isCancelled: Task.isCancelled
                ) else {
                    ttsDelegate.clearTracking()
                    if ownsPromptTTSAudioSession {
                        ownsPromptTTSAudioSession = false
                        deactivateTTSAudioSession()
                    }
                    return
                }
                ttsEngine.speak(utterance)
                promptReadoutTask = nil
            }
        }
    }

    /// Stop any in-flight TTS + cloud audio. Called from
    /// `.userTurnWaiting` (so the mic doesn't fight the synthesizer),
    /// `.sessionComplete`, and `.onDisappear`. Only the explicit replay-button
    /// toggle requests pending-round resumption; teardown paths never do.
    private func stopPromptReadout(resumePendingRound: Bool = false) {
        let stoppedRequest = promptSpeechRequest
        let shouldDeactivateLocalAudio = ownsPromptTTSAudioSession
        promptSpeechRequest = nil
        promptReadoutTask?.cancel()
        promptReadoutTask = nil
        ownsPromptTTSAudioSession = false
        ttsDelegate.clearTracking()
        if ttsEngine.isSpeaking {
            ttsEngine.stopSpeaking(at: .immediate)
        }
        promptSpeaker.stop()
        isSpeakingPrompt = false
        if shouldDeactivateLocalAudio, !speechVM.isRecording {
            deactivateTTSAudioSession()
        }

        guard SuddenDeathPromptReadoutPolicy.shouldResumePendingRound(
            requestRound: stoppedRequest?.round,
            pendingRound: engine.pendingUserWaitingRound,
            activeRound: activeNpcRound,
            resumeRequested: resumePendingRound
        ), let stoppedRequest else {
            return
        }
        prepareRecorderThenBeginUserWaiting(expectedRound: stoppedRequest.round)
    }
    #else
    // Stub-out the TTS surface when AVFAudio isn't available (preview /
    // non-iOS targets) so the call sites still compile.
    private func speakCurrentPromptIfReady(round: Int) { }
    private func speakCurrentPrompt(force: Bool, round: Int? = nil) { }
    private func stopPromptReadout() { }
    #endif
}

#if DEBUG
/// Deterministic post-run content for the screenshot tour. Fixtures use the
/// production result view and state owners; only the route into a completed
/// engine state is test-only.
@available(iOS 17.0, macOS 12.0, *)
private enum SuddenDeathResultFixture {
    case fillerEnded
    case longRun

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self? {
        if arguments.contains("UI_TESTING_SUDDEN_DEATH_RESULT_FILLER") {
            return .fillerEnded
        }
        if arguments.contains("UI_TESTING_SUDDEN_DEATH_RESULT_LONG") {
            return .longRun
        }
        return nil
    }

    var previousBestPoints: Int {
        switch self {
        case .fillerEnded: return 560
        case .longRun: return 2_400
        }
    }

    var result: PressureSessionResult {
        switch self {
        case .fillerEnded:
            return PressureSessionResult(
                roundsSurvived: 2,
                finalOutcome: .fillerOverload,
                roundOutcomes: [.survived, .survived, .fillerOverload],
                totalDuration: 52,
                totalFillers: 1,
                totalWords: 47,
                bestRoundWords: 20,
                personalBest: 4,
                difficulty: .medium,
                wordCountsByRound: [20, 19, 8],
                minimumWordsByRound: [10, 10, 10]
            )
        case .longRun:
            return PressureSessionResult(
                roundsSurvived: 11,
                finalOutcome: .fillerOverload,
                roundOutcomes: Array(repeating: .survived, count: 11) + [.fillerOverload],
                totalDuration: 267,
                totalFillers: 1,
                totalWords: 260,
                bestRoundWords: 29,
                personalBest: 8,
                difficulty: .medium,
                wordCountsByRound: [23, 24, 21, 27, 22, 26, 25, 20, 24, 29, 21, 8],
                minimumWordsByRound: Array(repeating: 10, count: 12)
            )
        }
    }

    var priorRuns: [SuddenDeathRunRecord] {
        let now = Date()
        switch self {
        case .fillerEnded:
            return [
                priorRun(rounds: 3, points: 480, minutesAgo: 16, date: now, wasNewBest: true),
                priorRun(rounds: 1, points: 125, minutesAgo: 42, date: now),
                priorRun(rounds: 2, points: 275, minutesAgo: 95, date: now)
            ]
        case .longRun:
            return [
                priorRun(rounds: 8, points: 2_150, minutesAgo: 38, date: now, wasNewBest: true),
                priorRun(rounds: 6, points: 1_260, minutesAgo: 125, date: now),
                priorRun(rounds: 7, points: 1_780, minutesAgo: 360, date: now)
            ]
        }
    }

    private func priorRun(
        rounds: Int,
        points: Int,
        minutesAgo: TimeInterval,
        date: Date,
        wasNewBest: Bool = false
    ) -> SuddenDeathRunRecord {
        SuddenDeathRunRecord(
            completedAt: date.addingTimeInterval(-(minutesAgo * 60)),
            difficulty: .medium,
            roundsSurvived: rounds,
            totalFillers: 1,
            totalWords: rounds * 19,
            score: 0,
            xpEarned: 0,
            finalOutcome: .fillerOverload,
            wasNewBestAtTime: wasNewBest,
            gamePoints: points
        )
    }
}
#endif
#endif
