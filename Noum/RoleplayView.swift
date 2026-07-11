import SwiftUI

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
    @State private var sessionID = UUID()
    @State private var submissionTask: Task<Void, Never>?

    private var isCompletePhase: Bool {
        if case .complete = phase { return true }
        return false
    }

    init(scenario: RoleplayScenario, startingLevel: RoleplayPressureLevel, navigationPath: Binding<NavigationPath>) {
        self.scenario = scenario
        self.startingLevel = startingLevel
        self._navigationPath = navigationPath
        self._currentLevel = State(initialValue: startingLevel)
    }

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
        phase = .feedback
    }

    // MARK: Feedback phase

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let feedback = lastFeedback {
                feedbackRow(label: "Strength", text: feedback.strength, systemImage: "checkmark.circle.fill", tint: AppColor.modeAhCounter)
                feedbackRow(label: "Gap", text: feedback.gap, systemImage: "arrow.up.right.circle.fill", tint: AppColor.modeSuddenDeath)
            }
            if let result = turnResults.last {
                feedbackRow(label: "Next attempt", text: retryModeCopy(result.recommendedRetryMode), systemImage: "arrow.forward.circle.fill", tint: AppColor.modeIM)
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

    private func retryModeCopy(_ mode: RoleplayRetryMode) -> String {
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

    private var continueButton: some View {
        Button {
            advanceAfterFeedback()
        } label: {
            Text(turnResults.count >= Self.maxTurns ? "See results" : "Next attempt")
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
        guard let last = turnResults.last else {
            phase = .complete
            return
        }
        currentLevel = RoleplayEngine.nextLevel(after: last.recommendedRetryMode, currentLevel: currentLevel)

        guard turnResults.count < Self.maxTurns else {
            phase = .complete
            return
        }

        let next = RoleplayEngine.nextObjection(
            for: scenario,
            pressureLevel: currentLevel,
            excluding: RoleplayStore.shared.usedObjectionIDs
        )
        guard let next else {
            phase = .complete
            return
        }
        currentObjection = next
        speechVM.transcribedText = ""
        phase = .turn
    }

    // MARK: Complete phase

    private var completeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Roleplay complete")
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
            Text("\(turnResults.count) response attempts with \(scenario.personaName). Final pressure: \(currentLevel.title).")
                .font(Typography.body)
                .foregroundStyle(.secondary)
            if let feedback = lastFeedback {
                feedbackRow(label: "Strength", text: feedback.strength, systemImage: "checkmark.circle.fill", tint: AppColor.modeAhCounter)
                feedbackRow(label: "Gap", text: feedback.gap, systemImage: "arrow.up.right.circle.fill", tint: AppColor.modeSuddenDeath)
            }
            if let result = turnResults.last {
                feedbackRow(label: "Next attempt", text: retryModeCopy(result.recommendedRetryMode), systemImage: "arrow.forward.circle.fill", tint: AppColor.modeIM)
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
