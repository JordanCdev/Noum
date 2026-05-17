import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

// MARK: - Sudden Death Practice View

@available(iOS 17.0, macOS 12.0, *)
struct SuddenDeathPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var navigationPath: NavigationPath
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var engine = PressureTimerEngine()

    /// Live Activity coordinator. Lazily initialised on first use because
    /// we need access to `engine` and `speechVM` which are
    /// `@StateObject`-resolved by SwiftUI on first body access. Built
    /// inside `start()` below.
    @State private var liveActivityCoordinator: PressureLiveActivityCoordinator?

    // UI state
    @State private var showExitConfirmation = false
    @State private var showUncertainIndicator = false
    @State private var roundTranscript = ""
    @State private var hasDetectedSpeechThisRound = false
    @State private var evaluation: PracticeEvaluation?

    // Personal best stored in UserDefaults
    private static let personalBestKey = "pressureMode.personalBestRounds"
    private var previousBestRounds: Int {
        UserDefaults.standard.integer(forKey: Self.personalBestKey)
    }

    // Difficulty selector — persisted across launches.
    private static let difficultyKey = "suddenDeath.difficulty"
    @State private var difficulty: SuddenDeathDifficulty = {
        let raw = UserDefaults.standard.string(forKey: Self.difficultyKey) ?? ""
        return SuddenDeathDifficulty(rawValue: raw) ?? .medium
    }()

    private let accentColor = AppColor.modeSuddenDeath

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            content
                .animation(.snappySpring, value: phaseGroup)
        }
        .accessibilityIdentifier("suddenDeath.screen")
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
                speechVM.stopRecording()
                engine.forceStop()
            }
        } message: {
            Text("Your progress in this run will be lost.")
        }
        .task {
            speechVM.prepareForInteractiveUse()
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
            engine.currentWordCount = words
        }
        .onChange(of: speechVM.pressureDrillFillerCount) { _, count in
            guard engine.isUserTurn else { return }
            engine.currentFillerCount = count
        }
        .onChange(of: speechVM.uncertainFillerCount) { oldVal, newVal in
            if newVal > oldVal, engine.isUserTurn {
                withAnimation(.easeIn(duration: 0.15)) { showUncertainIndicator = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.3)) { showUncertainIndicator = false }
                    }
                }
            }
        }
        .onChange(of: engine.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .onDisappear {
            // Belt-and-braces: if the user taps back during a live
            // session, kill the activity instead of leaving it dangling
            // in the Dynamic Island. The coordinator's `end()` is
            // idempotent.
            liveActivityCoordinator?.end()
            liveActivityCoordinator = nil
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
            resultScreen(result: result)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    // MARK: - Background

    private var background: some View {
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

        return LinearGradient(
            colors: [base.0, Color.white, base.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 0.6), value: phaseGroup)
        .animation(.easeInOut(duration: 0.4), value: engine.isUserTurn)
    }

    // MARK: - Setup Screen (zero friction)

    private var setupScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Icon + title
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(accentColor)

                    Text("Pressure Drill")
                        .font(Typography.bigStat)

                    Text("Respond fast. Stay clean. Survive.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // What to expect
                VStack(alignment: .leading, spacing: 12) {
                    ruleRow(icon: "timer", text: "A prompt appears. You have seconds to start speaking.")
                    ruleRow(icon: "arrow.turn.right.up", text: "The NPC fires back follow-ups based on what you said.")
                    ruleRow(icon: "waveform.badge.exclamationmark", text: "Too many fillers, too slow, or too short — run over.")
                    ruleRow(icon: "flame.fill", text: "Pressure increases every round. How far can you go?")
                }
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))

                difficultyPicker

                // Personal best
                if previousBestRounds > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("Best: Round \(previousBestRounds)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.1), in: Capsule())
                }

                if let error = speechVM.connectionError {
                    ErrorCard(message: error)
                }
            }
            .padding(.horizontal, Spacing.screenH)

            Spacer()

            // Begin button — zero friction, just tap
            Button {
                beginSession()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.headline)
                    Text("Begin")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(accentColor.gradient, in: Capsule())
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 24)
        }
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Difficulty Picker (Easy / Medium / Hard)

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DIFFICULTY")
                .font(Typography.micro)
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(SuddenDeathDifficulty.allCases) { option in
                    difficultyChip(option)
                }
            }

            Text(difficulty.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Difficulty: \(difficulty.title). \(difficulty.subtitle)")
    }

    private func difficultyChip(_ option: SuddenDeathDifficulty) -> some View {
        let isSelected = difficulty == option
        return Button {
            withAnimation(.snappySpring) {
                difficulty = option
                UserDefaults.standard.set(option.rawValue, forKey: Self.difficultyKey)
            }
            CoachHaptic.selectionTap()
        } label: {
            Text(option.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? accentColor : accentColor.opacity(0.10),
                    in: Capsule()
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Countdown Screen

    private var countdownScreen: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                if case .countdown(let value) = engine.phase {
                    Text("\(value)")
                        .font(.system(size: 110, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: accentColor.opacity(0.5), radius: 30, y: 8)
                        .transition(.scale.combined(with: .opacity))
                } else if case .go = engine.phase {
                    Text("GO")
                        .font(.system(size: 110, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Color.green.opacity(0.5), radius: 30, y: 8)
                        .transition(.scale.combined(with: .opacity))
                }

                // Goal anchor — quietly reinforces the user's voice goal
                // during the pre-rep moment. Pressure mode benefits most
                // from the reminder — the few seconds before "go" is when
                // intent is set.
                if let goal = coachingProfileStore.profile?.speakingStyleGoal {
                    GoalAnchorCapsule(goal: goal, style: .onDark)
                        .accessibilityIdentifier("suddenDeath.goalAnchor")
                }
            }
        }
    }

    // MARK: - Live Challenge Screen

    private func liveScreen(round: Int, roundOutcome: RoundOutcome? = nil) -> some View {
        let isUserTurn = engine.isUserTurn

        return VStack(spacing: 0) {
            // Top bar: round + survival dots
            topBar(round: round)

            // Start timer bar — only visible during userTurnWaiting
            if engine.isStartTimerActive {
                timerBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Turn cards
            VStack(spacing: 12) {
                // NPC / Prompt card
                npcCard(round: round, expanded: !isUserTurn && roundOutcome == nil)

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
                        .animation(.standardSpring, value: round)
                }
            }

            // Uncertain filler "?" indicator
            if showUncertainIndicator {
                Text("?")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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
                    .animation(.linear(duration: 0.05), value: fraction)
            }
            .frame(height: isCritical ? 5 : 3)
            .animation(.easeInOut(duration: 0.2), value: isCritical)
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
                    .textCase(.uppercase)

                Spacer()

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
                    .lineLimit(expanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: expanded)
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
            .animation(.easeInOut(duration: 0.25), value: isCritical)
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
                    .textCase(.uppercase)

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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: expanded)
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
                Text(outcome.isFailed ? "Run over" : "Next round...")
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
            speechVM.stopRecording()
            engine.userEndedTurn()
        } label: {
            Text("Done")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.green.gradient, in: Capsule())
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Result Screen

    private func resultScreen(result: PressureSessionResult) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Result icon
                ZStack {
                    Circle()
                        .fill(result.resultTint.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: result.resultIcon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(result.resultTint)
                }

                // Result label
                Text(result.resultLabel)
                    .font(Typography.bigStat)

                // Key stat: rounds survived
                Text("Survived \(result.roundsSurvived) round\(result.roundsSurvived == 1 ? "" : "s")")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Stats row
                HStack(spacing: 20) {
                    resultStat(value: "\(result.roundsSurvived)", label: "Rounds", tint: .green)
                    resultStat(value: "\(result.totalFillers)", label: "Fillers", tint: result.totalFillers == 0 ? .green : .red)
                    resultStat(value: "\(result.score)/10", label: "Score", tint: .blue)
                }

                // Round-by-round breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rounds")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(Array(result.roundOutcomes.enumerated()), id: \.offset) { index, outcome in
                        HStack(spacing: 8) {
                            Image(systemName: outcome.isFailed ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(outcome.isFailed ? .red : .green)
                                .font(.caption)
                            Text("Round \(index + 1)")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text(outcome.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(outcome.isFailed ? .red : .green)
                        }
                    }
                }
                .padding(Spacing.md)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))

                // Personal best
                if result.isNewPersonalBest {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("New personal best")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                        SparkleRibbon(tint: .yellow)
                    }
                }

                // XP earned
                Text("+\(result.xpEarned) XP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppColor.brandBlue.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, Spacing.screenH)

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button {
                    retrySession()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.bold))
                        Text("Go Again")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(accentColor.gradient, in: Capsule())
                }
                .buttonStyle(.pressable)

                Button {
                    pushSummary(result: result)
                } label: {
                    Text("See Full Summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, 24)
        }
    }

    private func resultStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Session Control

    private func beginSession() {
        Task { @MainActor in
            let openingPrompt = await PracticeTopics.next(
                profile: coachingProfileStore.profile,
                baseline: baselineStore.baseline
            )
            resetSpeechState()
            engine.configure(
                openingPrompt: openingPrompt,
                followUpProvider: PressureFollowUpService.shared,
                previousBest: previousBestRounds,
                difficulty: difficulty
            )
            engine.beginCountdown()
        }
    }

    private func retrySession() {
        Task { @MainActor in
            let openingPrompt = await PracticeTopics.next(
                profile: coachingProfileStore.profile,
                baseline: baselineStore.baseline
            )
            resetSpeechState()
            engine.configure(
                openingPrompt: openingPrompt,
                followUpProvider: PressureFollowUpService.shared,
                previousBest: previousBestRounds,
                difficulty: difficulty
            )
            engine.beginCountdown()
        }
    }

    private func resetSpeechState() {
        speechVM.stopRecording()
        speechVM.resetCurrentSession()
        roundTranscript = ""
        hasDetectedSpeechThisRound = false
        evaluation = nil
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
        // Kick off the Live Activity the first time the engine moves
        // away from setup. Ending the activity is handled inside the
        // coordinator on `.sessionComplete`.
        if newPhase != .setup {
            startLiveActivityIfNeeded()
        }
        switch newPhase {
        case .countdown:
            // Pre-rep ambience runs only through the countdown so it
            // never bleeds into the rep itself or the NPC's turn.
            SoundscapeEngine.shared.startPreferredMode()

        case .npcTurn:
            // Reset transcript for new round
            speechVM.stopRecording()
            speechVM.resetCurrentSession()
            roundTranscript = ""
            hasDetectedSpeechThisRound = false

            // Animate typing dots
            startTypingAnimation()

        case .userTurnWaiting:
            // Start recording for this round; cut soundscape if it's
            // still running so it doesn't compete with the user's voice.
            SoundscapeEngine.shared.stop()
            speechVM.prepareSession(mode: .suddenDeath)
            speechVM.pressureDrillPrompt = engine.currentPromptText
            speechVM.startRecording()

        case .sessionComplete(let result):
            speechVM.stopRecording()
            SoundscapeEngine.shared.stop()
            finalizeSession(result: result)

        default:
            break
        }
    }

    private func startTypingAnimation() {
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
        let transcript = roundTranscript
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
            coachSummary: eval.feedback
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
                transcript: transcript,
                fillerWordCount: result.totalFillers,
                duration: result.totalDuration,
                date: Date(),
                mode: .suddenDeath,
                pressureLevel: pressure,
                isRated: pressureOn,
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
                coachSummary: eval.feedback
            )
        )

        // Persist personal best
        if result.roundsSurvived > previousBestRounds {
            UserDefaults.standard.set(result.roundsSurvived, forKey: Self.personalBestKey)
        }

        if result.roundsSurvived >= 4 {
            CoachHaptic.pressureSessionComplete()
        }
        print("[PressureDrill] Session finalized: \(result.resultLabel), score \(result.score), rounds \(result.roundsSurvived)")
    }

    // MARK: - Summary Navigation

    private func pushSummary(result: PressureSessionResult) {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: speechVM.highlightedText,
            fillerCount: result.totalFillers,
            duration: result.totalDuration,
            score: result.score,
            progressSegments: result.roundsSurvived,
            xpEarned: result.xpEarned,
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
}
#endif
