import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

// MARK: - Phase State Machine

private enum PressureDrillPhase: Equatable {
    case setup
    case countdown(Int)       // 3, 2, 1
    case go                   // brief flash
    case active
    case gameOver(fillerTriggered: Bool)
}

// MARK: - View

@available(iOS 17.0, macOS 12.0, *)
struct SuddenDeathPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared

    // Prompt is set once and locked
    @State private var question: String = ""

    // State machine
    @State private var phase: PressureDrillPhase = .setup

    // Run state
    @State private var elapsed: Int = 0
    @State private var pressureLevel: Int = 1
    @State private var pressureEventsHandled: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var evaluation: PracticeEvaluation?
    @State private var showExitConfirmation = false
    @State private var showUncertainIndicator = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [pressureBackground.leading, Color.white, pressureBackground.trailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: pressureLevel)

            // Content
            switch phase {
            case .setup:
                setupScreen
                    .transition(.opacity)

            case .active:
                activeScreen
                    .transition(.opacity)

            case .gameOver:
                gameOverScreen
                    .transition(.opacity)

            case .countdown, .go:
                // Show the prompt faded behind the countdown
                activeScreenPreview
            }

            // Countdown overlay
            if case .countdown(let value) = phase {
                countdownOverlay(text: "\(value)", color: .orange)
            } else if case .go = phase {
                countdownOverlay(text: "GO", color: .green)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(phase != .setup)
        .toolbar {
            if case .active = phase {
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
        .task {
            if question.isEmpty { question = PracticeTopics.random() }
            speechVM.pressureDrillPrompt = question
            speechVM.prepareForInteractiveUse()
        }
        .onChange(of: speechVM.pressureDrillFillerCount) { _, count in
            if count > 0, case .active = phase {
                endRun(fillerTriggered: true)
            }
        }
        .onChange(of: speechVM.uncertainFillerCount) { oldVal, newVal in
            if newVal > oldVal, case .active = phase {
                // Flash the uncertain indicator briefly
                withAnimation(.easeIn(duration: 0.15)) { showUncertainIndicator = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.3)) { showUncertainIndicator = false }
                    }
                }
            }
        }
    }

    // MARK: - Setup Screen

    private var setupScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.orange)

                    Text("Pressure Drill")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Survive without fillers")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Prompt card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your prompt")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(question)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                )

                // New prompt button
                Button {
                    withAnimation(.snappySpring) {
                        question = PracticeTopics.random()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text("New Prompt")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }

                if let error = speechVM.connectionError {
                    ErrorCard(message: error)
                }
            }
            .padding(.horizontal, Spacing.screenH)

            Spacer()

            // Begin button
            Button {
                beginCountdown()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.headline)
                    Text("Begin Run")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.orange.gradient, in: Capsule())
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Active Screen

    private var activeScreen: some View {
        VStack(spacing: 0) {
            // Top bar: level + timer
            HStack {
                Text(levelTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(levelTint)

                Spacer()

                // Uncertain filler indicator — flashes briefly when a borderline detection is noticed
                if showUncertainIndicator {
                    Text("?")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.12), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }

                Text(formatTime(elapsed))
                    .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.vertical, 12)

            // Level progress bar
            GeometryReader { geo in
                let progress = min(1.0, Double(elapsed % 30) / 30.0)
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelTint.opacity(0.2))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(levelTint)
                            .frame(width: geo.size.width * progress, height: 3)
                            .animation(.linear(duration: 1), value: elapsed)
                    }
            }
            .frame(height: 3)
            .padding(.horizontal, Spacing.screenH)

            // Transcript area
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(speechVM.highlightedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.md)

                    // Prompt reminder (faded)
                    Text(question)
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.horizontal, Spacing.md)
                }
                .padding(.top, Spacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Spacing.screenH)

            // End run button
            Button {
                endRun(fillerTriggered: false)
            } label: {
                Text("End Run")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color.red.opacity(0.85), in: Capsule())
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 24)
        }
    }

    // Preview version shown behind countdown
    private var activeScreenPreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Level 1 • Settle in")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                Spacer()
                Text("0:00")
                    .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.vertical, 12)

            Spacer()

            Text(question)
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.3))
                .padding(.horizontal, Spacing.screenH)

            Spacer()
        }
        .opacity(0.3)
    }

    // MARK: - Game Over Screen

    private var gameOverScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon
                Image(systemName: fillerTriggeredGameOver ? "waveform.badge.exclamationmark" : "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(fillerTriggeredGameOver ? .orange : .green)

                // Title
                Text(fillerTriggeredGameOver ? "Filler Detected" : "Run Complete")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                // Time
                VStack(spacing: 4) {
                    Text("\(elapsed)")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                    Text("seconds survived")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Score
                if let score = evaluation?.score {
                    Text("Score: \(score)/10")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.blue)
                }

                // Level badge
                Text("Reached Level \(pressureLevel)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(levelTint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(levelTint.opacity(0.12), in: Capsule())

                // Personal best
                if isNewPersonalBest {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("New Personal Best!")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                } else if suddenDeathPersonalBest > 0 {
                    Text("Personal best: \(suddenDeathPersonalBest)s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                // Try Again — same prompt, straight to countdown
                Button {
                    retryRun()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.bold))
                        Text("Try Again")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color.orange.gradient, in: Capsule())
                }
                .buttonStyle(.pressable)

                // New Prompt
                Button {
                    question = PracticeTopics.random()
                    resetRunState()
                    withAnimation(.snappySpring) { phase = .setup }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                        Text("New Prompt")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColor.cardBackground, in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
                }

                // See Summary
                Button {
                    pushSummary()
                } label: {
                    Text("See Full Summary")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 24)
        }
    }

    private var fillerTriggeredGameOver: Bool {
        if case .gameOver(let filler) = phase { return filler }
        return false
    }

    // MARK: - Countdown Overlay

    private func countdownOverlay(text: String, color: Color) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            Text(text)
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: color.opacity(0.5), radius: 30, y: 8)
                .transition(.scale.combined(with: .opacity))
        }
        .transition(.opacity)
    }

    // MARK: - Run Control

    private func beginCountdown() {
        speechVM.prepareSession(mode: .suddenDeath)
        Task {
            for count in [3, 2, 1] {
                await MainActor.run {
                    withAnimation(.snappySpring) { phase = .countdown(count) }
                }
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run {
                withAnimation(.snappySpring) { phase = .go }
            }
            CoachHaptic.drillSuccess()
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run {
                withAnimation(.snappySpring) { phase = .active }
                startRecording()
            }
        }
    }

    private func retryRun() {
        // Same prompt, reset state, go straight to countdown
        resetRunState()
        beginCountdown()
    }

    private func startRecording() {
        speechVM.resetCurrentSession()
        speechVM.prepareSession(mode: .suddenDeath)
        speechVM.startRecording()
        elapsed = 0
        pressureLevel = 1
        pressureEventsHandled = 0
        timerTask = Task {
            var seconds = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                seconds += 1
                await MainActor.run {
                    elapsed = seconds
                    let newLevel = max(1, (seconds / 30) + 1)
                    if newLevel != pressureLevel {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            pressureLevel = newLevel
                        }
                        CoachHaptic.levelUp()
                    }
                    if seconds >= 15 && seconds % 15 == 0 {
                        pressureEventsHandled += 1
                    }
                    // 5-minute cap
                    if seconds >= 300 {
                        endRun(fillerTriggered: false)
                    }
                }
            }
        }
    }

    private func endRun(fillerTriggered: Bool) {
        guard case .active = phase else { return }
        timerTask?.cancel()
        speechVM.stopRecording()
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                let result = PracticeEvaluator.evaluateSuddenDeathPractice(
                    transcript: speechVM.transcribedText,
                    fillerCount: speechVM.fillerWordCount,
                    duration: TimeInterval(elapsed),
                    pressureEventsHandled: pressureEventsHandled,
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

                let pressureOn = PracticeSettingsManager.shared.pressureModeEnabled
                let pressure = BaselineEngine.classifyPressure(
                    mode: .suddenDeath,
                    isPressureModeOn: pressureOn,
                    streakDays: PracticeSession.calculateStreak(from: PracticeSessionStore.shared.sessions)
                )
                _ = PracticeSessionFinalizer.finalize(
                    store: PracticeSessionStore.shared,
                    draft: PracticeSessionDraft(
                        transcript: speechVM.transcribedText,
                        fillerWordCount: speechVM.fillerWordCount,
                        duration: TimeInterval(elapsed),
                        date: Date(),
                        mode: .suddenDeath,
                        pressureLevel: pressure,
                        isRated: pressureOn
                    ),
                    annotation: PracticeSessionAnnotation(
                        score: result.score,
                        xpEarned: result.xpEarned,
                        headline: result.headline,
                        insights: result.insights,
                        coachSummary: result.feedback
                    )
                )

                if fillerTriggered {
                    CoachHaptic.gameOver()
                } else {
                    CoachHaptic.sessionComplete()
                }
                withAnimation(.snappySpring) {
                    phase = .gameOver(fillerTriggered: fillerTriggered)
                }
            }
        }
    }

    private func resetRunState() {
        timerTask?.cancel()
        speechVM.resetCurrentSession()
        speechVM.pressureDrillPrompt = question
        elapsed = 0
        pressureLevel = 1
        pressureEventsHandled = 0
        evaluation = nil
    }

    // MARK: - Helpers

    private var levelTint: Color {
        switch pressureLevel {
        case 1: return .orange
        case 2: return .pink
        case 3: return .red
        default: return .purple
        }
    }

    private var levelTitle: String {
        switch pressureLevel {
        case 1: return "Level 1 • Settle in"
        case 2: return "Level 2 • Pressure rising"
        case 3: return "Level 3 • High pressure"
        default: return "Level \(pressureLevel) • Hold your nerve"
        }
    }

    private var pressureBackground: (leading: Color, trailing: Color) {
        switch pressureLevel {
        case 1: return (Color(red: 0.98, green: 0.93, blue: 0.88), Color(red: 0.99, green: 0.95, blue: 0.88))
        case 2: return (Color(red: 0.99, green: 0.91, blue: 0.90), Color(red: 0.99, green: 0.90, blue: 0.94))
        case 3: return (Color(red: 1.0, green: 0.90, blue: 0.90), Color(red: 0.98, green: 0.87, blue: 0.87))
        default: return (Color(red: 0.95, green: 0.88, blue: 0.96), Color(red: 0.92, green: 0.87, blue: 0.98))
        }
    }

    private var suddenDeathPersonalBest: Int {
        PracticeSessionStore.shared.sessions
            .filter { $0.mode == .suddenDeath }
            .dropFirst()
            .map { Int($0.duration) }
            .max() ?? 0
    }

    private var isNewPersonalBest: Bool {
        elapsed > suddenDeathPersonalBest && suddenDeathPersonalBest > 0
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Navigation

    private func pushSummary() {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: speechVM.highlightedText,
            fillerCount: speechVM.fillerWordCount,
            duration: TimeInterval(elapsed),
            score: evaluation?.score,
            progressSegments: max(0, pressureLevel - 1),
            xpEarned: evaluation?.xpEarned ?? 0,
            showDuration: true,
            practiceTitle: "Pressure Drill",
            feedbackOverride: evaluation?.feedback,
            headlineOverride: evaluation?.headline,
            scoreBreakdown: evaluation?.segments ?? [],
            insights: evaluation?.insights ?? [],
            recentSessions: [],
            imConversationDetails: nil,
            explicitMode: .suddenDeath,
            recordingURL: nil,
            sessionPrompt: question,
            sessionTheme: nil,
            feedbackCategories: [],
            strongMoments: [],
            weakMoments: [],
            durationAssessment: .onTarget,
            targetRange: (30, 60, 120),
            onStartDrill: nil
        )
        SummaryDataStore.shared.store(entry, for: payloadId)
        let payload = SummaryPayload(id: payloadId, mode: .suddenDeath)
        navigationPath.append(AppDestination.summary(payload))
    }
}
#endif
