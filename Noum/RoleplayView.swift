import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var showCloudProcessingConsent = false

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
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    sessionHeader
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
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("roleplay.end")
            }
        }
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
        .sheet(isPresented: $showCloudProcessingConsent) {
            CloudProcessingConsentDisclosure(
                isCurrentlyAllowed: AISettingsManager.shared.isCloudProcessingAllowed,
                onAllow: {
                    AISettingsManager.shared.recordCloudProcessingDecision(.allowed)
                    showCloudProcessingConsent = false
                    speechVM.connectionError = nil
                },
                onNotNow: {
                    AISettingsManager.shared.recordCloudProcessingDecision(.declined)
                    showCloudProcessingConsent = false
                }
            )
        }
    }

    // MARK: Session context

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    personaIdentity
                    Spacer()
                    pressureChip
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    personaIdentity
                    pressureChip
                }
            }

            NoumProgressTrack(
                value: Double(turnResults.count) / Double(Self.maxTurns),
                label: "Attempts in this roleplay",
                valueLabel: "\(turnResults.count) of \(Self.maxTurns)",
                tint: AppColor.modeIM
            )
        }
    }

    private var personaIdentity: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            NoumWaveformMark(
                state: waveformState,
                level: speechVM.audioLevel,
                tint: AppColor.modeIM,
                size: 44
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("WITH \(scenario.personaName.uppercased())")
                    .font(Typography.captionSmall.weight(.bold))
                    .foregroundStyle(AppColor.modeIM)
                    .tracking(0.7)
                Text(scenario.personaRole)
                    .font(Typography.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var waveformState: NoumWaveformState {
        if isCompletePhase { return .earned }
        switch speechVM.recordingLifecycle {
        case .recording: return .listening
        case .connecting, .finalizing: return .processing
        case .idle, .completed, .failed: return .idle
        }
    }

    private var pressureChip: some View {
        Text(currentLevel.title)
            .font(Typography.captionSmall)
            .foregroundStyle(AppColor.modeIM)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(AppColor.modeIM.opacity(0.10), in: Capsule())
            .accessibilityIdentifier("roleplay.pressureChip")
    }

    // MARK: Turn phase

    private var turnSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            objectionFocus
            responseControl

            if let message = speechVM.connectionError {
                recordingIssueCard(message)
            } else if let message = speechVM.microphonePermissionState.userFacingRecoveryMessage {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var objectionFocus: some View {
        Group {
            if let objection = currentObjection {
                NoumSurface(.mission) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("RESPOND TO THIS")
                            .font(Typography.captionSmall.weight(.bold))
                            .foregroundStyle(AppColor.homeHeroMetaText)
                            .tracking(0.7)
                        Text(objection.text)
                            .font(Typography.cardTitle)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(scenario.objective)
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.homeHeroSubtitleText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("roleplay.objection")
            } else {
                NoumEvidenceCard(
                    status: .needsMore,
                    title: "No objection is available",
                    detail: "This pressure rung has no unused prompt. End this run and choose another starting pressure."
                )
            }
        }
    }

    private var responseControl: some View {
        NoumSurface(speechVM.isRecording ? .standard : .quiet) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .center, spacing: Spacing.md) {
                    NoumWaveformMark(
                        state: waveformState,
                        level: speechVM.audioLevel,
                        tint: AppColor.modeIM,
                        size: 48
                    )

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(roleplayRecordingStatus)
                            .font(Typography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                        Text(speechVM.isRecording
                             ? "Finish when your answer has landed."
                             : "Noum waits until you finish before showing feedback.")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if speechVM.isRecording, !speechVM.transcribedText.isEmpty {
                    Text(speechVM.transcribedText)
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("roleplay.liveTranscript")
                }

                if speechVM.recordingLifecycle.isBusy && !speechVM.isRecording {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text(roleplayRecordingStatus)
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .noumMinimumTouchTarget()
                } else if canOfferCaptureAction {
                    Button {
                        toggleRecording()
                    } label: {
                        Label(
                            speechVM.isRecording ? "Finish answer" : "Start response",
                            systemImage: speechVM.isRecording ? "stop.fill" : "mic.fill"
                        )
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .noumMinimumTouchTarget()
                        .padding(.vertical, Spacing.xs)
                        .background(
                            speechVM.isRecording ? Color.red : AppColor.coachingInk,
                            in: Capsule(style: .continuous)
                        )
                    }
                    .buttonStyle(.pressable)
                    .disabled(currentObjection == nil || (speechVM.recordingLifecycle.isBusy && !speechVM.isRecording))
                    .accessibilityIdentifier("roleplay.micButton")
                    .accessibilityLabel(speechVM.isRecording ? "Stop responding" : "Start responding")
                }
            }
        }
    }

    private var canOfferCaptureAction: Bool {
        guard let recovery = roleplayRecordingIssuePresentation?.recovery else { return true }
        return recovery == .retry
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
        case .connecting: return "Connecting securely"
        case .recording: return "Listening to your answer"
        case .finalizing: return "Finishing your transcript"
        case .idle, .completed, .failed: return "Answer when you are ready"
        }
    }

    private var roleplayRecordingIssuePresentation: SpeechRecordingIssuePresentation? {
        guard let error = speechVM.connectionError else { return nil }
        return SpeechRecordingIssuePresentation.make(
            issue: speechVM.recordingIssue,
            message: error
        )
    }

    private func recordingIssueCard(_ message: String) -> some View {
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
                    Button("Try connection again") {
                        speechVM.connectionError = nil
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("roleplay.recordingIssue.retry")
                case .grantCloudConsent:
                    Button("Turn on cloud processing") {
                        showCloudProcessingConsent = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("roleplay.recordingIssue.cloudConsent")
                case .openSettings:
                    Button("Open Settings") {
                        openAppSettingsAfterRecordingIssue()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("roleplay.recordingIssue.openSettings")
                case .leaveRep:
                    Button("Back to practice") {
                        if !navigationPath.isEmpty { navigationPath.removeLast() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("roleplay.recordingIssue.backToPractice")
                }
            }
        }
        .accessibilityIdentifier("roleplay.recordingIssue")
    }

    private func openAppSettingsAfterRecordingIssue() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        speechVM.connectionError = nil
        openURL(url)
        #endif
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
        updatePhase(.feedback)
    }

    // MARK: Feedback phase

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Answer reviewed")
                    .font(Typography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Evidence from attempt \(turnResults.count)")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            NoumSurface(.evidence) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let feedback = lastFeedback {
                        feedbackRow(label: "Strength", text: feedback.strength, systemImage: "checkmark.circle.fill", tint: AppColor.positive)
                        Divider()
                        feedbackRow(label: "Gap", text: feedback.gap, systemImage: "arrow.up.right.circle.fill", tint: AppColor.caution)
                    }
                    if let presentation = postTurnPresentation {
                        Divider()
                        feedbackRow(label: presentation.guidanceLabel, text: presentation.guidanceBody, systemImage: "arrow.forward.circle.fill", tint: AppColor.modeIM)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("roleplay.feedback.guidance")
                    }
                }
            }

            continueButton
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
    }

    private func feedbackRow(label: String, text: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label)
                    .font(Typography.captionSmall)
                    .foregroundStyle(tint)
                Text(text)
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var continueButton: some View {
        Button {
            advanceAfterFeedback()
        } label: {
            Text(postTurnPresentation?.continueTitle ?? "See results")
                .font(Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .noumMinimumTouchTarget()
                .padding(.vertical, Spacing.xs)
                .background(AppColor.coachingInk, in: Capsule(style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("roleplay.continue")
    }

    private func advanceAfterFeedback() {
        guard let nextTurn = pendingNextTurn else {
            updatePhase(.complete)
            return
        }
        pendingNextTurn = nil
        currentLevel = nextTurn.pressureLevel
        currentObjection = nextTurn.objection
        speechVM.transcribedText = ""
        updatePhase(.turn)
    }

    private func updatePhase(_ nextPhase: Phase) {
        if reduceMotion {
            phase = nextPhase
        } else {
            withAnimation(NoumMotion.animation(for: .calm, reduceMotion: false)) {
                phase = nextPhase
            }
        }
    }

    // MARK: Complete phase

    private var completeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Roleplay complete")
                    .font(Typography.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityIdentifier("roleplay.complete.screen")
                Text("\(turnResults.count) response attempts with \(scenario.personaName). Final attempted pressure: \(turnResults.last?.pressureLevel.title ?? currentLevel.title).")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("roleplay.complete.summary")
            }

            NoumSurface(.evidence) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Label("Evidence from your final answer", systemImage: "checkmark.seal.fill")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.positive)

                    if let feedback = lastFeedback {
                        feedbackRow(label: "Strength", text: feedback.strength, systemImage: "checkmark.circle.fill", tint: AppColor.positive)
                        Divider()
                        feedbackRow(label: "Gap", text: feedback.gap, systemImage: "arrow.up.right.circle.fill", tint: AppColor.caution)
                    }
                    if let presentation = postTurnPresentation {
                        Divider()
                        feedbackRow(label: presentation.guidanceLabel, text: presentation.guidanceBody, systemImage: "arrow.forward.circle.fill", tint: AppColor.modeIM)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("roleplay.complete.guidance")
                    }
                }
            }

            Button {
                if !navigationPath.isEmpty { navigationPath.removeLast() }
            } label: {
                Text("Done")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .noumMinimumTouchTarget()
                    .padding(.vertical, Spacing.xs)
                    .background(AppColor.coachingInk, in: Capsule(style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("roleplay.done")
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
    }
}

#if DEBUG
#Preview("Roleplay — V3 evidence") {
    NavigationStack {
        RoleplayView.debugFixture(.preterminalFeedback)
    }
}
#endif
