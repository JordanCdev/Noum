import SwiftUI

enum RoleplayPostTurnContinuation: Equatable {
    case nextTurnAvailable
    case attemptLimitReached
    case transitionUnavailable
}

/// Visible guidance after a Roleplay turn. The engine's retry mode remains
/// useful coaching evidence after a run ends, but terminal copy must not
/// present that recommendation as an already-scheduled in-run transition.
struct RoleplayPostTurnPresentation: Equatable {
    let guidanceLabel: String
    let guidanceBody: String
    let continueTitle: String

    static func make(
        retryMode: RoleplayRetryMode,
        continuation: RoleplayPostTurnContinuation
    ) -> Self {
        switch continuation {
        case .nextTurnAvailable:
            return Self(
                guidanceLabel: "Next attempt",
                guidanceBody: nextAttemptCopy(retryMode),
                continueTitle: "Next attempt"
            )
        case .attemptLimitReached:
            return Self(
                guidanceLabel: "Practice focus",
                guidanceBody: nextRunCopy(retryMode),
                continueTitle: "See results"
            )
        case .transitionUnavailable:
            return Self(
                guidanceLabel: "Practice focus",
                guidanceBody: "Take the gap above into your next roleplay. Choose an available starting pressure and build the response deliberately.",
                continueTitle: "See results"
            )
        }
    }

    private static func nextAttemptCopy(_ mode: RoleplayRetryMode) -> String {
        switch mode {
        case .sameObjectionSlower:
            return "Run this same objection again, slower this time."
        case .sameLevelNewObjection:
            return "Stay at this pressure level with a fresh objection next."
        case .levelUp:
            return "You're ready to raise the pressure next attempt."
        case .levelDown:
            return "Drop one rung and rebuild before pushing harder again."
        }
    }

    private static func nextRunCopy(_ mode: RoleplayRetryMode) -> String {
        switch mode {
        case .sameObjectionSlower:
            return "When you return to this scenario, slow the opening and give the answer more room."
        case .sameLevelNewObjection:
            return "Use this pressure level again and focus on adapting your answer rather than rehearsing one line."
        case .levelUp:
            return "Choose a higher starting pressure next time and keep the same clarity under stronger pushback."
        case .levelDown:
            return "Choose a lower starting pressure next time and rebuild the response before pushing harder."
        }
    }
}

#if DEBUG
enum RoleplayDebugFixtureKind: String {
    case terminalFeedback
    case unavailableFeedback
    case preterminalFeedback

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self? {
        guard let index = arguments.firstIndex(of: "UI_TESTING_ROLEPLAY_FIXTURE"),
              index + 1 < arguments.count else {
            return nil
        }
        return Self(rawValue: arguments[index + 1])
    }
}
#endif

/// Live turn loop for the pressure-ladder roleplay: persona objection ->
/// spoken response -> one strength / one gap / one next attempt -> repeat,
/// escalating or stepping back per `RoleplayEngine.retryMode`.
///
/// Mic capture mirrors `CutTheCrutchView`/`PaceTrainingView`/`MiniDrillView`:
/// a fresh `SpeechRecognizerViewModel` with `shouldRecordPracticeSession =
/// false`, so roleplay turns never create a fake practice-mode session in
/// the user's main history (there is no `PracticeMode` case for this
/// feature — see `RoleplayEngine`'s doc-comment for why).
struct RoleplayView: View {
    let scenario: RoleplayScenario
    let startingLevel: RoleplayPressureLevel
    @Binding var navigationPath: NavigationPath

    private enum Phase {
        case turn
        case feedback
        case complete
    }

    private static let maxTurns = 4

    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @State private var phase: Phase = .turn
    @State private var currentLevel: RoleplayPressureLevel
    @State private var currentObjection: RoleplayObjection?
    @State private var turnResults: [RoleplayTurnResult] = []
    @State private var lastFeedback: (strength: String, gap: String)?
    @State private var pendingNextTurn: RoleplayNextTurn?
    @State private var sessionID = UUID()
    @State private var submissionTask: Task<Void, Never>?

    private var isCompletePhase: Bool {
        if case .complete = phase { return true }
        return false
    }

    private var postTurnPresentation: RoleplayPostTurnPresentation? {
        guard let result = turnResults.last else { return nil }
        let continuation: RoleplayPostTurnContinuation
        if pendingNextTurn != nil {
            continuation = .nextTurnAvailable
        } else if turnResults.count >= Self.maxTurns {
            continuation = .attemptLimitReached
        } else {
            continuation = .transitionUnavailable
        }
        return RoleplayPostTurnPresentation.make(
            retryMode: result.recommendedRetryMode,
            continuation: continuation
        )
    }

    init(scenario: RoleplayScenario, startingLevel: RoleplayPressureLevel, navigationPath: Binding<NavigationPath>) {
        self.scenario = scenario
        self.startingLevel = startingLevel
        self._navigationPath = navigationPath
        self._currentLevel = State(initialValue: startingLevel)
    }

    #if DEBUG
    static func debugFixture(_ kind: RoleplayDebugFixtureKind) -> Self {
        Self(debugFixture: kind)
    }

    private init(debugFixture kind: RoleplayDebugFixtureKind) {
        let fixture = Self.debugFixtureState(kind)
        self.scenario = fixture.scenario
        self.startingLevel = fixture.currentLevel
        self._navigationPath = .constant(NavigationPath())
        self._phase = State(initialValue: .feedback)
        self._currentLevel = State(initialValue: fixture.currentLevel)
        self._currentObjection = State(initialValue: fixture.currentObjection)
        self._turnResults = State(initialValue: fixture.turnResults)
        self._lastFeedback = State(initialValue: fixture.feedback)
        self._pendingNextTurn = State(initialValue: fixture.pendingNextTurn)
    }

    private static func debugFixtureState(_ kind: RoleplayDebugFixtureKind) -> (
        scenario: RoleplayScenario,
        currentLevel: RoleplayPressureLevel,
        currentObjection: RoleplayObjection,
        turnResults: [RoleplayTurnResult],
        feedback: (strength: String, gap: String),
        pendingNextTurn: RoleplayNextTurn?
    ) {
        let feedback = (
            strength: "You answered the actual question in the first sentence.",
            gap: "Name one concrete outcome before adding more context."
        )

        switch kind {
        case .terminalFeedback:
            let scenario = RoleplayCatalog.interview
            let objection = scenario.objections(at: .easy)[0]
            let result = RoleplayTurnResult(
                scenarioId: scenario.scenarioId,
                pressureLevel: .easy,
                objectionType: objection.type,
                objectionId: objection.id,
                responseQuality: 0.3,
                recommendedRetryMode: .sameObjectionSlower
            )
            return (scenario, .easy, objection, Array(repeating: result, count: 4), feedback, nil)

        case .unavailableFeedback:
            let objection = RoleplayObjection(
                id: "fixture.realistic.0",
                pressureLevel: .realistic,
                type: .skepticalPushback,
                text: "Why should I believe that?"
            )
            let scenario = RoleplayScenario(
                scenarioId: "fixture",
                title: "Stakeholder pushback",
                personaName: "Alex",
                personaRole: "Stakeholder",
                objective: "Respond directly.",
                objectionSet: [objection],
                rubric: []
            )
            let result = RoleplayTurnResult(
                scenarioId: scenario.scenarioId,
                pressureLevel: .realistic,
                objectionType: objection.type,
                objectionId: objection.id,
                responseQuality: 0.9,
                recommendedRetryMode: .levelUp
            )
            return (scenario, .realistic, objection, Array(repeating: result, count: 3), feedback, nil)

        case .preterminalFeedback:
            let scenario = RoleplayCatalog.interview
            let current = scenario.objections(at: .easy)[0]
            let next = scenario.objections(at: .realistic)[0]
            let result = RoleplayTurnResult(
                scenarioId: scenario.scenarioId,
                pressureLevel: .easy,
                objectionType: current.type,
                objectionId: current.id,
                responseQuality: 0.9,
                recommendedRetryMode: .levelUp
            )
            return (
                scenario,
                .easy,
                current,
                [result],
                feedback,
                RoleplayNextTurn(pressureLevel: .realistic, objection: next)
            )
        }
    }
    #endif

    var body: some View {
        ZStack {
            if isCompletePhase {
                AppColor.screenBackground.ignoresSafeArea()
            } else {
                FocusedPracticeBackground(style: .conversation)
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    personaHeader
                    switch phase {
                    case .turn:
                        turnSection
                    case .feedback:
                        feedbackSection
                    case .complete:
                        completeSection
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .environment(\.colorScheme, isCompletePhase ? .light : .dark)
        }
        .navigationTitle(scenario.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            speechVM.shouldRecordPracticeSession = false
            if currentObjection == nil {
                currentObjection = RoleplayEngine.nextObjection(
                    for: scenario,
                    pressureLevel: currentLevel,
                    excluding: RoleplayStore.shared.usedObjectionIDs
                )
            }
        }
        .onDisappear {
            submissionTask?.cancel()
            speechVM.cancelRecording()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("End") {
                    speechVM.cancelRecording()
                    if !navigationPath.isEmpty { navigationPath.removeLast() }
                }
                .foregroundStyle(isCompletePhase ? Color.secondary : Color.white)
                .accessibilityIdentifier("roleplay.end")
            }
        }
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
    }

    // MARK: Persona header

    private var personaHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text(scenario.personaName)
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                Text(scenario.personaRole)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                pressureChip
            }
            Text(scenario.objective)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pressureChip: some View {
        Text(currentLevel.title)
            .font(Typography.captionSmall)
            .foregroundStyle(isCompletePhase ? AppColor.modeIM : .white)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(isCompletePhase ? AppColor.modeIM.opacity(0.10) : AppColor.focusedGlassFill, in: Capsule())
            .accessibilityIdentifier("roleplay.pressureChip")
    }

    // MARK: Turn phase

    private var turnSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            objectionBubble
            micControl
            if let message = speechVM.microphonePermissionState.userFacingRecoveryMessage {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            if let message = speechVM.connectionError {
                FocusedPracticeErrorStatus(message: message)
            }
        }
    }

    private var objectionBubble: some View {
        Group {
            if let objection = currentObjection {
                Text(objection.text)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.focusedGlassFill, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                    .focusedGlassSurface()
                    .accessibilityIdentifier("roleplay.objection")
            } else {
                Text("No objection available at this pressure level.")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var micControl: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(speechVM.isRecording ? Color.red.opacity(0.16) : AppColor.modeIM.opacity(0.14))
                        .frame(width: 64, height: 64)
                    Image(systemName: speechVM.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(speechVM.isRecording ? .red : AppColor.modeIM)
                }
            }
            .buttonStyle(.plain)
            .disabled(currentObjection == nil || (speechVM.recordingLifecycle.isBusy && !speechVM.isRecording))
            .accessibilityIdentifier("roleplay.micButton")
            .accessibilityLabel(speechVM.isRecording ? "Stop responding" : "Start responding")

            Text(roleplayRecordingStatus)
                .font(Typography.caption)
                .foregroundStyle(.secondary)

            if !speechVM.transcribedText.isEmpty {
                Text(speechVM.transcribedText)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .accessibilityIdentifier("roleplay.liveTranscript")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleRecording() {
        if speechVM.isRecording {
            submissionTask?.cancel()
            submissionTask = Task { @MainActor in
                let completion = await speechVM.stopRecordingAwaitingFinalization()
                guard RecordingCompletionGate.allowsScoringAndProgress(completion),
                      !Task.isCancelled else { return }
                submitTurn()
            }
        } else {
            submissionTask?.cancel()
            submissionTask = Task { @MainActor in
                speechVM.resetCurrentSession()
                _ = await speechVM.startRecordingAwaitingReadiness()
            }
        }
    }

    private var roleplayRecordingStatus: String {
        switch speechVM.recordingLifecycle {
        case .connecting: return "Connecting to live transcription"
        case .recording: return "Listening — tap to finish"
        case .finalizing: return "Finishing your response"
        case .idle, .completed, .failed: return "Tap the mic and respond to the objection"
        }
    }

    private func submitTurn() {
        guard let objection = currentObjection else { return }
        let response = speechVM.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = RoleplayEngine.evaluateTurn(scenario: scenario, objection: objection, response: response)
        let feedback = RoleplayEngine.feedback(response: response, rubric: scenario.rubric)
        RoleplayStore.shared.record(sessionID: sessionID, result: result, date: Date())
        turnResults.append(result)
        lastFeedback = feedback
        pendingNextTurn = RoleplayEngine.nextTurn(
            after: result,
            currentObjection: objection,
            for: scenario,
            completedAttemptCount: turnResults.count,
            maximumAttemptCount: Self.maxTurns,
            excluding: RoleplayStore.shared.usedObjectionIDs
        )
        phase = .feedback
    }

    // MARK: Feedback phase

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let feedback = lastFeedback {
                feedbackRow(label: "Strength", text: feedback.strength, systemImage: "checkmark.circle.fill", tint: AppColor.modeAhCounter)
                feedbackRow(label: "Gap", text: feedback.gap, systemImage: "arrow.up.right.circle.fill", tint: AppColor.modeSuddenDeath)
            }
            if let presentation = postTurnPresentation {
                feedbackRow(label: presentation.guidanceLabel, text: presentation.guidanceBody, systemImage: "arrow.forward.circle.fill", tint: AppColor.modeIM)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("roleplay.feedback.guidance")
            }
            continueButton
        }
    }

    private func feedbackRow(label: String, text: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            isCompletePhase ? AppColor.cardBackground : AppColor.focusedGlassFill,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .overlay {
            if !isCompletePhase {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(AppColor.focusedGlassBorder, lineWidth: 1)
            }
        }
    }

    private var continueButton: some View {
        Button {
            advanceAfterFeedback()
        } label: {
            Text(postTurnPresentation?.continueTitle ?? "See results")
                .font(Typography.headline)
                .foregroundStyle(AppColor.modeIM)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.pressable)
        .background(.white, in: Capsule())
        .accessibilityIdentifier("roleplay.continue")
    }

    private func advanceAfterFeedback() {
        guard let nextTurn = pendingNextTurn else {
            phase = .complete
            return
        }
        pendingNextTurn = nil
        currentLevel = nextTurn.pressureLevel
        currentObjection = nextTurn.objection
        speechVM.transcribedText = ""
        phase = .turn
    }

    // MARK: Complete phase

    private var completeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Roleplay complete")
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("roleplay.complete.screen")
            Text("\(turnResults.count) response attempts with \(scenario.personaName). Final attempted pressure: \(turnResults.last?.pressureLevel.title ?? currentLevel.title).")
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("roleplay.complete.summary")
            if let feedback = lastFeedback {
                feedbackRow(label: "Strength", text: feedback.strength, systemImage: "checkmark.circle.fill", tint: AppColor.modeAhCounter)
                feedbackRow(label: "Gap", text: feedback.gap, systemImage: "arrow.up.right.circle.fill", tint: AppColor.modeSuddenDeath)
            }
            if let presentation = postTurnPresentation {
                feedbackRow(label: presentation.guidanceLabel, text: presentation.guidanceBody, systemImage: "arrow.forward.circle.fill", tint: AppColor.modeIM)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("roleplay.complete.guidance")
            }
            Button {
                if !navigationPath.isEmpty { navigationPath.removeLast() }
            } label: {
                Text("Done")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.pressable)
            .background(AppColor.modeIM, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .accessibilityIdentifier("roleplay.done")
        }
    }
}
