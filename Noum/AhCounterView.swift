import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct AhCounterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @State private var evaluation: PracticeEvaluation?
    // Mini-drill navigation


    // MARK: - Prompt Suggestions

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

    @State private var currentPrompt: String = AhCounterView.prompts.randomElement() ?? "Describe your morning routine"

    // MARK: - Elapsed Timer

    @State private var elapsedSeconds: Int = 0
    @State private var elapsedTimer: Timer?

    // MARK: - Filler-Free Streak

    @State private var lastFillerCount: Int = 0
    @State private var currentStreakSeconds: Int = 0
    @State private var bestStreakSeconds: Int = 0
    @State private var fillerFlash: Bool = false
    @State private var showExitConfirmation = false

    // MARK: - Milestone Toast

    @State private var toastMessage: String? = nil
    @State private var toastIsCoaching: Bool = false
    @State private var firedMilestones: Set<String> = []
    @State private var recentFillerTimestamps: [Int] = []

    // MARK: - Launch Countdown
    @State private var launchCountdown: Int? = nil
    @State private var showGoCue = false

    // MARK: - Encouragement

    private var encouragementMessage: String {
        if !speechVM.isRecording {
            return "Tap Start when you're ready"
        }
        // Brief filler flash takes priority
        if fillerFlash {
            return "Shake it off, keep going"
        }
        if currentStreakSeconds >= 60 {
            return "Outstanding control"
        }
        if currentStreakSeconds >= 30 {
            return "Impressive focus"
        }
        if currentStreakSeconds >= 15 {
            return "Clean streak going"
        }
        if elapsedSeconds <= 10 {
            return "You're rolling"
        }
        return "Keep going"
    }

    private var encouragementIcon: String {
        if !speechVM.isRecording {
            return "hand.tap"
        }
        if fillerFlash {
            return "arrow.clockwise"
        }
        if currentStreakSeconds >= 60 {
            return "star.fill"
        }
        if currentStreakSeconds >= 30 {
            return "flame.fill"
        }
        if currentStreakSeconds >= 15 {
            return "bolt.fill"
        }
        return "waveform"
    }

    // MARK: - Glow Color

    private var glowColor: Color {
        fillerFlash ? .orange : AppColor.modeAhCounter
    }

    // MARK: - Formatted Elapsed Time

    private var formattedElapsed: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // MARK: Header Card — mode hero treatment matching
                    // Cut the Crutch / Sudden Death / Timed setup. Mode-
                    // tinted waveform icon + rounded display headline so
                    // every mode pre-rep screen shares one visual rhythm.
                    HStack(alignment: .center, spacing: Spacing.md) {
                        NoumCharacter(
                            mood: speechVM.isRecording ? .listening : .calm,
                            tint: AppColor.modeAhCounter,
                            size: 44,
                            audioLevel: speechVM.audioLevel,
                            stage: characterStage
                        )
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Ah-Counter")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("Track filler words live. Open-ended reps without a fixed countdown — speak freely while Noum listens.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
                    .accessibilityElement(children: .combine)

                    // Goal-aware intent reminder — fades in at the start of
                    // a free-form Ah-Counter rep so the user sees what voice
                    // they're working toward. One mount = one rep; default
                    // reset behaviour is correct here.
                    if let voice = coachingProfileStore.profile?.speakingStyleGoal {
                        VoiceAnchorBanner(styleGoal: voice, isRecording: speechVM.isRecording)
                    }

                    // MARK: Prompt Suggestion (pre-recording only)
                    if !speechVM.isRecording && elapsedSeconds == 0 && speechVM.fillerWordCount == 0 {
                        VStack(spacing: Spacing.sm) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                Text("Speaking Prompt")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    withAnimation(.standardSpring) {
                                        var next = currentPrompt
                                        while next == currentPrompt && Self.prompts.count > 1 {
                                            next = Self.prompts.randomElement() ?? currentPrompt
                                        }
                                        currentPrompt = next
                                    }
                                } label: {
                                    Image(systemName: "shuffle")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppColor.modeAhCounter)
                                }
                                .buttonStyle(.pressable)
                            }
                            Text(currentPrompt)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppColor.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(Spacing.lg)
                        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: Encouragement Banner
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: encouragementIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(speechVM.isRecording ? (fillerFlash ? .orange : AppColor.modeAhCounter) : .secondary)
                        Text(encouragementMessage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(speechVM.isRecording ? (fillerFlash ? .orange : AppColor.textPrimary) : .secondary)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        (fillerFlash ? Color.orange.opacity(0.08) : AppColor.modeAhCounter.opacity(speechVM.isRecording ? 0.08 : 0.04)),
                        in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    )
                    .animation(.easeInOut(duration: 0.3), value: encouragementMessage)
                    .animation(.easeInOut(duration: 0.3), value: fillerFlash)

                    // MARK: Stats Row
                    HStack(spacing: Spacing.sm) {
                        // Filler word counter with pulsing glow
                        ZStack {
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .fill(glowColor.opacity(0.15))
                                .shadow(color: glowColor.opacity(speechVM.isRecording ? 0.35 : 0), radius: fillerFlash ? 12 : 6, x: 0, y: 0)
                                .animation(.easeInOut(duration: fillerFlash ? 0.4 : 1.5).repeatForever(autoreverses: true), value: speechVM.isRecording)

                            VStack(spacing: Spacing.xxs) {
                                Text("\(speechVM.fillerWordCount)")
                                    .font(.title2.bold())
                                    .foregroundStyle(speechVM.fillerWordCount > 0 ? .red : AppColor.modeAhCounter)
                                    .contentTransition(.numericText())
                                Text("Filler Words")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.md)
                        }
                        .animation(.easeInOut(duration: 0.3), value: fillerFlash)

                        if speechVM.isRecording || elapsedSeconds > 0 {
                            // Elapsed timer
                            StatCard(title: "Elapsed", value: formattedElapsed, tint: AppColor.brandBlue)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }

                    // MARK: Streak Stats (visible during or after recording)
                    if speechVM.isRecording || bestStreakSeconds > 0 {
                        HStack(spacing: Spacing.sm) {
                            StatCard(
                                title: "Current Streak",
                                value: "\(currentStreakSeconds)s",
                                tint: currentStreakSeconds >= 15 ? AppColor.positive : AppColor.modeAhCounter
                            )
                            StatCard(
                                title: "Best Streak",
                                value: "\(bestStreakSeconds)s",
                                tint: bestStreakSeconds >= 30 ? AppColor.positive : AppColor.caution
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // MARK: Error Card
                    if let error = speechVM.connectionError {
                        ErrorCard(message: error)
                    }

                    // MARK: Transcript
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Transcript")
                            .font(.headline)
                        ScrollView {
                            Text(speechVM.highlightedText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Spacing.md)
                                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                        }
                        .frame(minHeight: 260)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.md)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if speechVM.isRecording {
                        Button("Stop") { stopSession() }
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Color.red.gradient, in: Capsule(style: .continuous))
                            .foregroundStyle(.white)
                            .buttonStyle(.pressable)
                    } else if launchCountdown == nil && !showGoCue {
                        Button("Start") { beginLaunchCountdown() }
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(AppColor.modeAhCounter.gradient, in: Capsule(style: .continuous))
                            .foregroundStyle(.white)
                            .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
                .background(.regularMaterial)
            }

            // MARK: Countdown Overlay
            if let launchCountdown {
                countdownOverlay(value: "\(launchCountdown)", subtitle: "Get ready")
                    .transition(.opacity.combined(with: .scale))
            } else if showGoCue {
                countdownOverlay(value: "GO", subtitle: "Start speaking")
                    .transition(.opacity.combined(with: .scale))
            }

            // MARK: Milestone Toast Overlay
            if let message = toastMessage {
                VStack {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: toastIsCoaching ? "wind" : "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(toastIsCoaching ? .orange : AppColor.positive)
                        Text(message)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColor.textPrimary)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .strokeBorder(
                                (toastIsCoaching ? Color.orange : AppColor.positive).opacity(0.25),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, Spacing.lg)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            // Real-time positive feedback — pulses when the engine catches
            // a rhetorical move during free-form speaking. styleGoal makes
            // the chip subtext goal-aware when the device aligns with the
            // user's chosen voice. Self-contained lifecycle bound to the
            // speech VM's recording flag.
            LiveEloquenceHUD(
                speechVM: speechVM,
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal
            )
            .padding(.top, 4)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(speechVM.isRecording)
        .toolbar {
            if speechVM.isRecording {
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
            Button("Keep Practicing", role: .cancel) { }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your current session will be lost.")
        }
        .accessibilityIdentifier("ahCounter.screen")
        .task {
            speechVM.prepareForInteractiveUse()

            // Quick Start handshake — picker armed Ah-Counter for a
            // one-tap launch. Ah-Counter has the lightest setup of any
            // mode (just a prompt suggestion); Quick Start auto-fires
            // the launch countdown so the user goes straight into the
            // shared 3-2-1 → GO ramp without the manual Start tap.
            if !speechVM.isRecording,
               launchCountdown == nil,
               !showGoCue,
               PracticeModeQuickStart.consume(for: .ahCounter) {
                beginLaunchCountdown()
            }
        }
        .onChange(of: speechVM.fillerWordCount) { _, newCount in
            handleFillerCountChange(newCount: newCount)
            trackRapidFillers()
        }
        .onChange(of: currentStreakSeconds) { _, newStreak in
            checkStreakMilestones(streak: newStreak)
        }
        .onChange(of: elapsedSeconds) { _, newElapsed in
            checkTimeMilestones(elapsed: newElapsed)
        }
        // Summary navigation is handled by path-based .navigationDestination(for:) in ContentView
    }

    // MARK: - Timer Management

    private func startElapsedTimer() {
        elapsedSeconds = 0
        currentStreakSeconds = 0
        bestStreakSeconds = 0
        lastFillerCount = 0
        fillerFlash = false
        toastMessage = nil
        firedMilestones.removeAll()
        recentFillerTimestamps.removeAll()

        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedSeconds += 1
                currentStreakSeconds += 1
                if currentStreakSeconds > bestStreakSeconds {
                    bestStreakSeconds = currentStreakSeconds
                }
                // Gentle session cap — nudge at 9 min, auto-stop at 10 min
                if elapsedSeconds == 540 {
                    toastMessage = "9 minutes — great session. Wrapping up soon."
                } else if elapsedSeconds >= 600 {
                    stopSession()
                }
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func resetStreakState() {
        elapsedSeconds = 0
        currentStreakSeconds = 0
        bestStreakSeconds = 0
        lastFillerCount = 0
        fillerFlash = false
        toastMessage = nil
        firedMilestones.removeAll()
        recentFillerTimestamps.removeAll()
    }

    // MARK: - Filler Detection

    private func handleFillerCountChange(newCount: Int) {
        guard newCount > lastFillerCount else { return }
        lastFillerCount = newCount

        // Reset current streak
        currentStreakSeconds = 0

        // Flash the filler indicator
        withAnimation(.easeInOut(duration: 0.2)) {
            fillerFlash = true
        }

        // Clear the flash after a short duration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeInOut(duration: 0.3)) {
                fillerFlash = false
            }
        }
    }

    // MARK: - Milestone Toast

    private func showToast(_ message: String, isCoaching: Bool = false) {
        withAnimation(.standardSpring) {
            toastMessage = message
            toastIsCoaching = isCoaching
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.standardSpring) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func checkStreakMilestones(streak: Int) {
        guard speechVM.isRecording else { return }
        if streak == 30, !firedMilestones.contains("streak30") {
            firedMilestones.insert("streak30")
            showToast("30s clean — nice rhythm")
        } else if streak == 60, !firedMilestones.contains("streak60") {
            firedMilestones.insert("streak60")
            showToast("1 minute clean — you're locked in")
        }
    }

    private func checkTimeMilestones(elapsed: Int) {
        guard speechVM.isRecording else { return }
        if elapsed == 120, !firedMilestones.contains("elapsed120") {
            firedMilestones.insert("elapsed120")
            showToast("2 minutes strong")
        }
    }

    private func trackRapidFillers() {
        guard speechVM.isRecording else { return }
        recentFillerTimestamps.append(elapsedSeconds)
        // Remove timestamps older than 15 seconds
        recentFillerTimestamps.removeAll { $0 < elapsedSeconds - 15 }
        if recentFillerTimestamps.count >= 3, !firedMilestones.contains("rapidFillers") {
            firedMilestones.insert("rapidFillers")
            showToast("Take a breath. Silence is power.", isCoaching: true)
        }
    }

    // MARK: - Launch Countdown

    private func beginLaunchCountdown() {
        launchCountdown = 3
        // Start the user's preferred pre-rep ambience (no-op if Off).
        // It runs through the 3-2-1 + GO cue, then stops the moment
        // recording starts so it doesn't bleed into the rep itself.
        SoundscapeEngine.shared.startPreferredMode()
        Task {
            for count in stride(from: 3, through: 1, by: -1) {
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.25)) { launchCountdown = count }
                    CoachHaptic.countdownBeat()
                }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run {
                withAnimation(.snappy(duration: 0.25)) { launchCountdown = nil }
                showGoCue = true
            }
            try? await Task.sleep(for: .milliseconds(700))
            await MainActor.run {
                showGoCue = false
                SoundscapeEngine.shared.stop()
                startRecording()
            }
        }
    }

    private func countdownOverlay(value: String, subtitle: String) -> some View {
        ZStack {
            Color.black.opacity(0.10)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text(value)
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.modeAhCounter.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .padding(36)
            .shadow(color: .black.opacity(0.16), radius: 24, y: 18)
        }
    }

    // MARK: - Session Control

    private func startRecording() {
        speechVM.prepareSession(mode: .ahCounter)
        speechVM.startRecording()
        startElapsedTimer()
    }

    private func stopSession() {
        speechVM.stopRecording()
        stopElapsedTimer()
        CoachHaptic.sessionComplete()
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                let result = PracticeEvaluator.evaluateAhCounterPractice(
                    transcript: speechVM.transcribedText,
                    fillerCount: speechVM.fillerWordCount,
                    duration: speechVM.lastSessionDuration,
                    recentSessions: speechVM.pastSessions,
                    profile: coachingProfileStore.profile
                )
                evaluation = result
                speechVM.annotateLatestSession(
                    score: result.score,
                    xpEarned: result.xpEarned,
                    headline: result.headline,
                    insights: result.insights,
                    coachSummary: result.feedback
                )
                pushSummary()
            }
        }
    }

    // MARK: - Navigation

    private func pushSummary() {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: speechVM.highlightedText,
            fillerCount: speechVM.fillerWordCount,
            duration: speechVM.lastSessionDuration,
            score: evaluation?.score,
            progressSegments: 0,
            xpEarned: evaluation?.xpEarned ?? 0,
            suddenDeathGamePoints: nil,
            suddenDeathMultiplierLabels: [],
            suddenDeathTotalWords: nil,
            showDuration: true,
            practiceTitle: "Ah-Counter Practice",
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
#endif
