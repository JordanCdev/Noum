import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
enum AhCounterRecordingTransitionPolicy {
    static func shouldStartElapsedTimer(wasRecording: Bool, isRecording: Bool) -> Bool {
        !wasRecording && isRecording
    }

    static func shouldStopElapsedTimer(wasRecording: Bool, isRecording: Bool) -> Bool {
        wasRecording && !isRecording
    }
}

/// Open-ended filler-word practice. Setup presents one prompt and one start
/// action; the live room stays quiet; scoring and progress happen only after a
/// usable recording passes `RecordingCompletionGate`.
@available(iOS 17.0, macOS 12.0, *)
struct AhCounterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var navigationPath: NavigationPath

    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared

    @State private var evaluation: PracticeEvaluation?
    @State private var currentPrompt: String = AhCounterView.prompts.randomElement() ?? "Describe your morning routine"
    @State private var elapsedSeconds = 0
    @State private var elapsedTimer: Timer?
    @State private var lastFillerCount = 0
    @State private var currentStreakSeconds = 0
    @State private var bestStreakSeconds = 0
    @State private var fillerFlash = false
    @State private var showExitConfirmation = false
    @State private var showSetupAdjustments = false
    @State private var showCloudProcessingConsent = false
    @State private var launchCountdown: Int?
    @State private var showGoCue = false
    @State private var launchTask: Task<Void, Never>?
    @State private var fillerFeedbackTask: Task<Void, Never>?
    @State private var isFinalizingSession = false
    @State private var sessionNotice: String?
    /// Exact Today/Train target for this mounted rep. It is deliberately not a
    /// second persistence owner; the recommendation ledger owns attribution.
    @State private var acceptedPracticeIntent: PracticeQuickStartIntent?

    private static let prompts: [String] = [
        "Describe your morning routine",
        "Explain your favourite hobby",
        "Tell a story from your childhood",
        "Pitch an idea you've been thinking about",
        "Describe a place you'd love to visit",
        "Talk about a book that changed your perspective",
        "Explain something complex in simple terms",
        "Describe your ideal weekend",
        "Share a lesson you learned the hard way",
        "Talk about someone who inspires you"
    ]

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                Group {
                    if isFinalizingSession {
                        finalizingContent
                    } else if speechVM.isRecording {
                        liveRepContent
                    } else {
                        setupContent
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xl)
                .transition(.opacity)
            }

            if let launchCountdown {
                countdownOverlay(value: "\(launchCountdown)", subtitle: "Get ready")
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
            } else if showGoCue {
                countdownOverlay(value: "GO", subtitle: "Start speaking")
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomAction
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
                .background(.regularMaterial)
        }
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(speechVM.isRecording || isFinalizingSession)
        .toolbar {
            if speechVM.isRecording || isFinalizingSession {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showExitConfirmation = true
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
        .alert("End session?", isPresented: $showExitConfirmation) {
            Button("Keep Practicing", role: .cancel) { }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your current session will be lost.")
        }
        .accessibilityIdentifier("ahCounter.screen")
        .sheet(isPresented: $showSetupAdjustments) {
            setupAdjustmentsSheet
        }
        .sheet(isPresented: $showCloudProcessingConsent) {
            CloudProcessingConsentDisclosure(
                isCurrentlyAllowed: AISettingsManager.shared.isCloudProcessingAllowed,
                onAllow: {
                    AISettingsManager.shared.recordCloudProcessingDecision(.allowed)
                    showCloudProcessingConsent = false
                    speechVM.connectionError = nil
                    beginLaunchCountdown()
                },
                onNotNow: {
                    AISettingsManager.shared.recordCloudProcessingDecision(.declined)
                    showCloudProcessingConsent = false
                }
            )
        }
        .onDisappear {
            launchTask?.cancel()
            fillerFeedbackTask?.cancel()
            speechVM.cancelRecording()
            stopElapsedTimer()
            SoundscapeEngine.shared.stop()
        }
        .task {
            speechVM.prepareForInteractiveUse()
            if !speechVM.isRecording,
               launchCountdown == nil,
               !showGoCue,
               let quickStartLaunch = PracticeModeQuickStart.consumeLaunch(
                    for: .ahCounter
               ) {
                acceptedPracticeIntent = quickStartLaunch.recommendationIntent
                beginLaunchCountdown()
            }
        }
        .onChange(of: speechVM.isRecording) { wasRecording, isRecording in
            if AhCounterRecordingTransitionPolicy.shouldStartElapsedTimer(
                wasRecording: wasRecording,
                isRecording: isRecording
            ) {
                startElapsedTimer()
            } else if AhCounterRecordingTransitionPolicy.shouldStopElapsedTimer(
                wasRecording: wasRecording,
                isRecording: isRecording
            ) {
                stopElapsedTimer()
            }
        }
        .onChange(of: speechVM.fillerWordCount) { _, newCount in
            handleFillerCountChange(newCount: newCount)
        }
    }

    // MARK: - Setup

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Spacing.md) {
                    NoumWaveformMark(state: .idle, tint: AppColor.modeAhCounter)
                    setupHeaderCopy
                    adjustSetupButton
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        NoumWaveformMark(state: .idle, tint: AppColor.modeAhCounter)
                        Spacer()
                        adjustSetupButton
                    }
                    setupHeaderCopy
                }
            }

            NoumSurface(.mission) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("YOUR SPEAKING PROMPT")
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(AppColor.homeHeroMetaText)
                        .tracking(0.7)
                    Text(currentPrompt)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Speak naturally. The rep is open-ended and stops when you choose.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.homeHeroSubtitleText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Speaking prompt: \(currentPrompt)")

            acceptedTargetCue

            if acceptedPracticeIntent == nil,
               let voice = coachingProfileStore.profile?.chosenStyleGoal {
                VoiceAnchorBanner(styleGoal: voice, isRecording: false)
            }

            NoumSurface(.quiet) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("What Noum measures")
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Label("Filler words heard in the transcript", systemImage: "waveform")
                    Label("Your longest filler-free stretch", systemImage: "timer")
                    Text("No score or XP is created until a usable recording finishes.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
            }

            if let sessionNotice {
                NoumEvidenceCard(
                    status: .needsMore,
                    title: "Rep not saved",
                    detail: sessionNotice
                )
            }

            if let error = speechVM.connectionError {
                recordingIssueStatus(error)
            }
        }
    }

    private var setupHeaderCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("FILLER CONTROL")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.modeAhCounter)
                .tracking(0.8)
            Text("Keep the thought. Lose the filler.")
                .font(Typography.screenTitle)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Calm live counts while you speak. Evidence after you finish.")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var adjustSetupButton: some View {
        NoumIconButton(
            systemName: "slider.horizontal.3",
            accessibilityLabel: "Adjust Filler Control",
            tint: AppColor.modeAhCounter
        ) {
            CoachHaptic.selectionTap()
            showSetupAdjustments = true
        }
        .accessibilityIdentifier("ahCounter.adjust")
    }

    private var setupAdjustmentsSheet: some View {
        NavigationStack {
            List {
                Section("Speaking prompt") {
                    Text(currentPrompt)
                        .font(Typography.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        chooseAnotherPrompt()
                    } label: {
                        Label("Choose another prompt", systemImage: "shuffle")
                    }
                    .accessibilityIdentifier("ahCounter.adjust.prompt")
                }

                Section("Live feedback") {
                    Label {
                        Text("Fillers, clean time, and a quiet transcript appear while you speak.")
                    } icon: {
                        Image(systemName: "ear.and.waveform")
                            .foregroundStyle(AppColor.modeAhCounter)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Adjust Filler Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSetupAdjustments = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Live rep

    private var liveRepContent: some View {
        VStack(spacing: Spacing.xl) {
            HStack(spacing: Spacing.sm) {
                NoumWaveformMark(
                    state: .listening,
                    level: speechVM.audioLevel,
                    tint: AppColor.modeAhCounter,
                    size: 44
                )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("LISTENING")
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(AppColor.modeAhCounter)
                        .tracking(0.8)
                    Text("Keep going. Pauses are fine.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                Text(formattedElapsed)
                    .font(Typography.figtreeNumeric(size: 20, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(AppColor.textPrimary)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Recording, \(formattedElapsed) elapsed")

            acceptedTargetCue

            NoumSurface(.quiet) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.lg) {
                        fillerCount
                        Spacer(minLength: Spacing.sm)
                        cleanStreak
                    }

                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        fillerCount
                        cleanStreak
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(speechVM.fillerWordCount) filler words, clean for \(currentStreakSeconds) seconds")
            }

            if !speechVM.highlightedText.characters.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("LIVE WORDS")
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(AppColor.textTertiary)
                        .tracking(0.7)

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            Text(LiveTranscriptStyle.calmed(speechVM.highlightedText))
                                .font(Typography.body)
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("liveWordsEnd")
                        }
                        .frame(maxHeight: 120)
                        .onChange(of: speechVM.highlightedText) {
                            proxy.scrollTo("liveWordsEnd", anchor: .bottom)
                        }
                    }
                }
                .transition(.opacity)
            }

            if elapsedSeconds >= 540 {
                Label("This rep will stop automatically at 10 minutes.", systemImage: "exclamationmark.circle.fill")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.caution)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var acceptedTargetCue: some View {
        if let intent = acceptedPracticeIntent {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "scope")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.modeAhCounter)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("YOUR TARGET")
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(AppColor.textSecondary)
                        .tracking(0.7)
                    Text(intent.target)
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.modeAhCounter.opacity(0.08),
                in: RoundedRectangle(
                    cornerRadius: CornerRadius.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: CornerRadius.medium,
                    style: .continuous
                )
                .stroke(AppColor.modeAhCounter.opacity(0.18), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Practice target. \(intent.target)")
            .accessibilityIdentifier("ahCounter.acceptedTarget")
        }
    }

    private var fillerCount: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("\(speechVM.fillerWordCount)")
                .font(Typography.figtreeNumeric(size: 68, weight: .bold, relativeTo: .largeTitle))
                .foregroundStyle(fillerFlash ? AppColor.caution : AppColor.textPrimary)
                .contentTransition(.numericText())
                .animation(
                    NoumMotion.animation(for: .responsive, reduceMotion: reduceMotion),
                    value: speechVM.fillerWordCount
                )
            Text("FILLER WORDS")
                .font(Typography.captionSmall.weight(.bold))
                .foregroundStyle(AppColor.textSecondary)
                .tracking(0.8)
        }
    }

    private var cleanStreak: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("\(currentStreakSeconds)s clean")
                .font(Typography.cardTitle.monospacedDigit())
                .foregroundStyle(currentStreakSeconds >= 15 ? AppColor.positive : AppColor.textPrimary)
                .contentTransition(.numericText())
            Text(fillerFlash ? "Pause, then continue." : "Longest: \(bestStreakSeconds)s")
                .font(Typography.caption)
                .foregroundStyle(fillerFlash ? AppColor.caution : AppColor.textSecondary)
        }
    }

    private var finalizingContent: some View {
        VStack(alignment: .center, spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xl)
            NoumWaveformMark(state: .processing, tint: AppColor.modeAhCounter, size: 72)
            ProgressView()
            Text("Reviewing your rep")
                .font(Typography.cardTitle)
                .foregroundStyle(AppColor.textPrimary)
            Text("Noum is waiting for the final transcript before it calculates evidence or progress.")
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reviewing your rep. Waiting for the final transcript.")
    }

    // MARK: - Issue recovery

    private var recordingIssuePresentation: SpeechRecordingIssuePresentation? {
        guard let error = speechVM.connectionError else { return nil }
        return SpeechRecordingIssuePresentation.make(
            issue: speechVM.recordingIssue,
            message: error
        )
    }

    private var canOfferStart: Bool {
        guard let recovery = recordingIssuePresentation?.recovery else { return true }
        return recovery == .retry
    }

    private func recordingIssueStatus(_ message: String) -> some View {
        let presentation = SpeechRecordingIssuePresentation.make(
            issue: speechVM.recordingIssue,
            message: message
        )

        return NoumSurface(.standard) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label(presentation.title, systemImage: "exclamationmark.triangle.fill")
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.caution)
                Text(presentation.detail)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                switch presentation.recovery {
                case .retry:
                    Text("Use Start Filler Control to try the connection again.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                case .grantCloudConsent:
                    recordingIssueAction(
                        title: "Turn on cloud processing",
                        icon: "cloud.fill",
                        identifier: "ahCounter.recordingIssue.cloudConsent"
                    ) { showCloudProcessingConsent = true }
                case .openSettings:
                    recordingIssueAction(
                        title: "Open Settings",
                        icon: "gearshape.fill",
                        identifier: "ahCounter.recordingIssue.openSettings"
                    ) { openSettingsAfterRecordingIssue() }
                case .leaveRep:
                    recordingIssueAction(
                        title: "Back to practice",
                        icon: "arrow.backward",
                        identifier: "ahCounter.recordingIssue.backToSetup"
                    ) { dismiss() }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ahCounter.recordingIssue")
    }

    private func recordingIssueAction(
        title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Typography.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .noumMinimumTouchTarget()
                .padding(.vertical, Spacing.xs)
                .background(AppColor.coachingInk, in: Capsule(style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier)
    }

    private func openSettingsAfterRecordingIssue() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        speechVM.connectionError = nil
        openURL(url)
        #endif
    }

    // MARK: - Primary action

    @ViewBuilder
    private var bottomAction: some View {
        if isFinalizingSession || (speechVM.recordingLifecycle.isBusy && !speechVM.isRecording) {
            HStack(spacing: Spacing.sm) {
                ProgressView()
                Text(isFinalizingSession ? "Reviewing rep…" : "Connecting…")
                    .font(Typography.headline)
            }
            .foregroundStyle(AppColor.textSecondary)
            .frame(maxWidth: .infinity)
            .noumMinimumTouchTarget()
        } else if speechVM.isRecording {
            Button("Finish rep") { stopSession() }
                .font(Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .noumMinimumTouchTarget()
                .padding(.vertical, Spacing.xs)
                .background(Color.red, in: Capsule(style: .continuous))
                .buttonStyle(.pressable)
                .accessibilityIdentifier("ahCounter.stop")
        } else if launchCountdown == nil, !showGoCue, canOfferStart {
            Button("Start Filler Control") {
                beginLaunchCountdown()
            }
            .font(Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .noumMinimumTouchTarget()
            .padding(.vertical, Spacing.xs)
            .background(AppColor.coachingInk, in: Capsule(style: .continuous))
            .buttonStyle(.pressable)
            .accessibilityIdentifier("ahCounter.start")
        }
    }

    private func countdownOverlay(value: String, subtitle: String) -> some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                NoumWaveformMark(state: .listening, tint: .white, size: 72)
                Text(value)
                    .font(Typography.figtreeNumeric(size: 72, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(Typography.headline)
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value). \(subtitle)")
    }

    // MARK: - State and timers

    private var formattedElapsed: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func chooseAnotherPrompt() {
        var next = currentPrompt
        while next == currentPrompt && Self.prompts.count > 1 {
            next = Self.prompts.randomElement() ?? currentPrompt
        }

        if reduceMotion {
            currentPrompt = next
        } else {
            withAnimation(NoumMotion.animation(for: .responsive, reduceMotion: false)) {
                currentPrompt = next
            }
        }
    }

    private func startElapsedTimer() {
        elapsedSeconds = 0
        currentStreakSeconds = 0
        bestStreakSeconds = 0
        lastFillerCount = 0
        fillerFlash = false

        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedSeconds += 1
                currentStreakSeconds += 1
                bestStreakSeconds = max(bestStreakSeconds, currentStreakSeconds)

                if elapsedSeconds >= 600 {
                    stopSession()
                }
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func handleFillerCountChange(newCount: Int) {
        guard newCount > lastFillerCount else { return }
        lastFillerCount = newCount
        currentStreakSeconds = 0

        if reduceMotion {
            fillerFlash = true
        } else {
            withAnimation(NoumMotion.animation(for: .responsive, reduceMotion: false)) {
                fillerFlash = true
            }
        }

        fillerFeedbackTask?.cancel()
        fillerFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.25))
            guard !Task.isCancelled else { return }
            if reduceMotion {
                fillerFlash = false
            } else {
                withAnimation(NoumMotion.animation(for: .calm, reduceMotion: false)) {
                    fillerFlash = false
                }
            }
        }
    }

    // MARK: - Capture and scoring

    private func beginLaunchCountdown() {
        guard launchCountdown == nil,
              !showGoCue,
              !speechVM.recordingLifecycle.isBusy else { return }

        sessionNotice = nil
        launchCountdown = 3
        SoundscapeEngine.shared.startPreferredMode()
        launchTask?.cancel()
        launchTask = Task { @MainActor in
            for count in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                launchCountdown = count
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }

            guard !Task.isCancelled else { return }
            launchCountdown = nil
            showGoCue = true
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            showGoCue = false
            SoundscapeEngine.shared.stop()
            startRecording()
        }
    }

    private func startRecording() {
        guard !speechVM.recordingLifecycle.isBusy else { return }
        speechVM.prepareSession(
            mode: .ahCounter,
            competitiveObservationIntent: .noPrompt
        )
        Task { @MainActor in
            _ = await speechVM.startRecordingAwaitingReadiness()
        }
    }

    private func stopSession() {
        guard !isFinalizingSession else { return }
        stopElapsedTimer()
        isFinalizingSession = true

        Task { @MainActor in
            let completion = await speechVM.stopRecordingAwaitingFinalization()
            guard RecordingCompletionGate.allowsScoringAndProgress(completion) else {
                isFinalizingSession = false
                sessionNotice = "Noum did not receive enough final transcript evidence to score or save this rep. You can try again."
                return
            }

            CoachHaptic.sessionComplete()
            let result = PracticeEvaluator.evaluateAhCounterPractice(
                transcript: speechVM.transcribedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                recentSessions: speechVM.pastSessions,
                profile: coachingProfileStore.profile
            )
            evaluation = result
            let finalizedSessionID = speechVM.annotateLatestSession(
                score: result.score,
                xpEarned: result.xpEarned,
                headline: result.headline,
                insights: result.insights,
                coachSummary: result.feedback,
                categoryRatings: result.categories.persistedCategoryRatings
            )
            isFinalizingSession = false
            pushSummary(finalizedSessionID: finalizedSessionID)
        }
    }

    private func pushSummary(finalizedSessionID: UUID?) {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: speechVM.highlightedText,
            fillerCount: speechVM.fillerWordCount,
            duration: speechVM.lastSessionDuration,
            score: evaluation?.score,
            progressSegments: 0,
            xpEarned: evaluation?.xpEarned ?? 0,
            finalizedSessionID: finalizedSessionID,
            committedFinalization: nil,
            suddenDeathGamePoints: nil,
            suddenDeathMultiplierLabels: [],
            suddenDeathTotalWords: nil,
            showDuration: true,
            practiceTitle: "Filler Control",
            feedbackOverride: evaluation?.feedback,
            headlineOverride: evaluation?.headline,
            scoreBreakdown: evaluation?.segments ?? [],
            insights: evaluation?.insights ?? [],
            recentSessions: [],
            imConversationDetails: nil,
            explicitMode: .ahCounter,
            recordingURL: nil,
            sessionPrompt: nil,
            sessionTheme: nil,
            feedbackCategories: [],
            strongMoments: [],
            weakMoments: [],
            durationAssessment: .onTarget,
            targetRange: (30, 60, 120),
            onStartDrill: nil
        )
        SummaryDataStore.shared.store(entry, for: payloadId)
        let payload = SummaryPayload(id: payloadId, mode: .ahCounter)
        navigationPath.append(AppDestination.summary(payload))
    }
}


#if DEBUG
#Preview("Filler Control — V3 setup") {
    NavigationStack {
        AhCounterView(navigationPath: .constant(NavigationPath()))
    }
}
#endif
#endif
