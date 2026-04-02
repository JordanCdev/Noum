import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct IMPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var relationshipStore = IMRelationshipStore.shared
    @StateObject private var imVoicePlaybackSettings = IMVoicePlaybackSettingsManager.shared
#if canImport(AVFAudio)
    @StateObject private var messageSpeaker = IMMessageSpeaker.shared
#endif

    @State private var scenario: IMConversationScenario = .socialCatchUp
    @State private var targetTone: IMTargetTone = .confident
    @State private var turns: [IMConversationTurn] = []
    @State private var conversationState: IMConversationState = .starting
    @State private var isSessionActive = false
    @State private var isAwaitingNPC = false
    @State private var isWrappingUp = false
    @State private var totalDuration: TimeInterval = 0
    @State private var totalFillers = 0
    @State private var showSummary = false
    @State private var summaryTranscript = AttributedString("")
    @State private var summaryEvaluation: IMConversationEvaluation?
    @State private var serviceErrorMessage: String?
    @State private var setupStep: SetupStep = .scenario
    @State private var typingPhase = 0
    @State private var sessionContext = IMSessionContextProvider.current()
    @State private var latestUserSignal: IMUserMessageSignal?

    private let conversationService: IMConversationServicing = IMConversationService()
    private let evaluationService: IMConversationEvaluatorServicing = IMConversationEvaluationService()

    private var setup: IMConversationSetup {
        IMConversationSetup(scenario: scenario, targetTone: targetTone)
    }

    private var relationshipProfile: IMRelationshipProfile {
        relationshipStore.profile(for: scenario)
    }

    private var userTurnCount: Int {
        turns.filter { $0.speaker == .user }.count
    }

    private var setupGuidanceTitle: String {
        switch scenario {
        case .socialCatchUp:
            return "Keep it easy and natural"
        case .workUpdate:
            return "Lead with the headline"
        case .difficultConversation:
            return "Be calm and direct"
        case .networking:
            return "Be warm and specific"
        }
    }

    private var setupGuidanceBody: String {
        "Aim to \(targetTone.coachingPrompt)."
    }

    private var combinedUserTranscript: String {
        turns
            .filter { $0.speaker == .user }
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdvanceFromScenario: Bool { true }

    private var isToneStep: Bool { setupStep == .tone }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.87),
                    Color.white,
                    Color(red: 0.90, green: 0.95, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .safeAreaInset(edge: .bottom) {
            if isSessionActive {
                composerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.white.opacity(0.0), Color.white.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .navigationTitle("IM Mode")
        .navigationBarTitleDisplayMode(.inline)
        .alert("IM Mode Unavailable", isPresented: .constant(serviceErrorMessage != nil), actions: {
            Button("OK", role: .cancel) { serviceErrorMessage = nil }
        }, message: {
            Text(serviceErrorMessage ?? "")
        })
        .task(id: isAwaitingNPC) {
            guard isAwaitingNPC else {
                typingPhase = 0
                return
            }

            while isAwaitingNPC {
                try? await Task.sleep(for: .milliseconds(220))
                guard isAwaitingNPC else { break }
                typingPhase = (typingPhase + 1) % 3
            }
        }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: summaryTranscript,
                fillerCount: totalFillers,
                duration: totalDuration,
                score: summaryEvaluation?.overallScore,
                progressSegments: min(4, userTurnCount),
                xpEarned: summaryEvaluation?.xpEarned ?? 0,
                showDuration: true,
                practiceTitle: "IM Mode • \(scenario.title)",
                feedbackOverride: summaryEvaluation?.feedback,
                headlineOverride: summaryEvaluation?.headline,
                scoreBreakdown: summaryEvaluation?.segments ?? [],
                insights: summaryInsights,
                recentSessions: sessionStore.sessions,
                imConversationDetails: IMConversationDetails(
                    setup: setup,
                    turns: turns,
                    actualTone: summaryEvaluation?.actualTone,
                    finalState: conversationState,
                    outcome: summaryEvaluation?.outcome,
                    relationshipSnapshot: relationshipProfile,
                    contextSnapshot: sessionContext
                ), 
                onSelectPracticeMode: {
                    showSummary = false
                    dismiss(times: 2)
                },
                onHome: {
                    showSummary = false
                    dismiss(times: 3)
                },
                onPracticeAgain: {
                    showSummary = false
                    resetConversation()
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if !isSessionActive {
            GeometryReader { _ in
                VStack(spacing: 14) {
                    headerCard
                    stepSwitcher
                    setupPanel
                    bottomSetupBar
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        } else {
            VStack(spacing: 12) {
                activeHeaderCard
                conversationCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSessionActive ? scenario.title : "Choose a conversation")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(isSessionActive ? "Target tone: \(targetTone.title)" : "Pick a scenario, then shape the tone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var stepSwitcher: some View {
        HStack(spacing: 10) {
            stepChip(title: "scenario", isActive: setupStep == .scenario)
            stepChip(title: "tone", isActive: setupStep == .tone)
        }
    }

    private var setupPanel: some View {
        Group {
            if setupStep == .scenario {
                setupCard
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                guidanceCard
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: setupStep)
    }

    private var bottomSetupBar: some View {
        HStack(spacing: 10) {
            if isToneStep {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        setupStep = .scenario
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(isToneStep ? "Start conversation" : "Next") {
                if isToneStep {
                    beginConversation()
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        setupStep = .tone
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!canAdvanceFromScenario)
        }
    }

    private var activeHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Text(String(scenario.personaName.prefix(1)))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(scenario.personaName)
                        .font(.headline.weight(.bold))
                    Text(scenario.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isAwaitingNPC {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                statusChip(title: "Tone", value: targetTone.title, tint: .indigo)
                statusChip(title: "Trust", value: "\(conversationState.normalizedTrust)", tint: .teal)
                statusChip(title: "Tension", value: "\(conversationState.normalizedTension)", tint: .orange)
            }

            Text(relationshipProfile.continuitySummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("scenario")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(IMConversationScenario.allCases) { option in
                    scenarioCard(for: option)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tone")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(IMTargetTone.allCases) { tone in
                    toneChip(for: tone)
                }
            }

            Text(setupGuidanceTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(setupGuidanceBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var conversationCard: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(turns) { turn in
                        messageBubble(turn)
                            .id(turn.id)
                    }

                    if isAwaitingNPC {
                        typingBubble
                            .id("typing-indicator")
                    }
                }
                .padding(6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onChange(of: turns.count) { _, _ in
                if let last = turns.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isAwaitingNPC) { _, awaiting in
                guard awaiting else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("typing-indicator", anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ turn: IMConversationTurn) -> some View {
        HStack {
            if turn.speaker == .npc {
                bubbleContent(
                    title: scenario.personaName,
                    text: turn.text,
                    tint: Color(red: 0.92, green: 0.94, blue: 0.98),
                    isLeading: true
                )
                Spacer(minLength: 72)
            } else {
                Spacer(minLength: 72)
                bubbleContent(
                    title: "You",
                    text: turn.text,
                    tint: Color(red: 0.85, green: 0.93, blue: 1.0),
                    isLeading: false
                )
            }
        }
    }

    private func bubbleContent(title: String, text: String, tint: Color, isLeading: Bool) -> some View {
        VStack(alignment: isLeading ? .leading : .trailing, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
                .multilineTextAlignment(isLeading ? .leading : .trailing)
        }
        .frame(maxWidth: 250, alignment: isLeading ? .leading : .trailing)
        .padding(14)
        .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var typingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(scenario.personaName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary.opacity(0.6))
                            .frame(width: 7, height: 7)
                            .scaleEffect(typingPhase == index ? 1.1 : 0.72)
                            .opacity(typingPhase == index ? 1 : 0.45)
                            .animation(.easeInOut(duration: 0.18), value: typingPhase)
                    }
                }
            }
            .frame(maxWidth: 120, alignment: .leading)
            .padding(14)
            .background(Color(red: 0.92, green: 0.94, blue: 0.98), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Spacer(minLength: 72)
        }
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    if speechVM.isRecording {
                        speechVM.stopRecording()
                    } else {
                        Task { await startReply() }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(speechVM.isRecording ? Color.red.opacity(0.16) : Color.blue.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: speechVM.isRecording ? "stop.fill" : "mic.fill")
                            .font(.headline)
                            .foregroundStyle(speechVM.isRecording ? .red : .blue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAwaitingNPC)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        isAwaitingNPC
                            ? "\(scenario.personaName) is typing..."
                            : (speechVM.isRecording ? "Listening..." : (draftReplyText.isEmpty ? "Tap the mic and speak" : "Ready to send"))
                    )
                        .font(.subheadline.weight(.semibold))
                    Text(
                        isAwaitingNPC
                            ? "Generating a live reply..."
                            : (draftReplyText.isEmpty ? conversationState.beat : draftReplyText)
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button {
                    sendCurrentReply()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.blue, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSendReply || isAwaitingNPC)
                .opacity((!canSendReply || isAwaitingNPC) ? 0.4 : 1.0)
            }

            Button(isWrappingUp ? "See Summary" : "End Chat") {
                endConversation()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .disabled(speechVM.isRecording || isAwaitingNPC)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func statusChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.10), in: Capsule())
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func scenarioCard(for option: IMConversationScenario) -> some View {
        Button {
            scenario = option
            withAnimation(.easeInOut(duration: 0.22)) {
                setupStep = .tone
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill((scenario == option ? Color.blue : Color.gray).opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: scenarioIconName(for: option))
                        .font(.headline)
                        .foregroundStyle(scenario == option ? .blue : .secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(option.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: scenario == option ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(scenario == option ? .blue : .secondary)
            }
            .padding(14)
            .background(
                (scenario == option ? Color.blue.opacity(0.06) : Color.black.opacity(0.03)),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func toneChip(for tone: IMTargetTone) -> some View {
        Button {
            targetTone = tone
        } label: {
            Text(tone.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(targetTone == tone ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
                .background(
                    targetTone == tone ? Color.blue : Color.black.opacity(0.05),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func stepChip(title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? Color.blue : Color.black.opacity(0.05), in: Capsule())
    }

    private func scenarioIconName(for option: IMConversationScenario) -> String {
        switch option {
        case .socialCatchUp:
            return "bubble.left.and.bubble.right.fill"
        case .workUpdate:
            return "briefcase.fill"
        case .difficultConversation:
            return "exclamationmark.bubble.fill"
        case .networking:
            return "person.2.fill"
        }
    }

    private var draftReplyText: String {
        speechVM.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSendReply: Bool {
        speechVM.isRecording || !draftReplyText.isEmpty
    }

    private var summaryInsights: [String] {
        guard let summaryEvaluation else { return [] }
        return ["Actual tone: \(summaryEvaluation.actualTone)."] + summaryEvaluation.insights + [summaryEvaluation.suggestedDrill]
    }

    private var liveToneMatchScore: Int {
        let transcript = turns
            .filter { $0.speaker == .user }
            .map(\.text)
            .joined(separator: " ")
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 5 }
        return IMToneMatcher.score(for: targetTone, transcript: transcript)
    }

    private func beginConversation() {
        guard IMModeAvailability.isAvailable else {
            serviceErrorMessage = IMModeServiceError.unavailable.errorDescription
            return
        }
        resetConversation()
        isSessionActive = true
        conversationState = relationshipStore.startingState(for: scenario)
        isAwaitingNPC = true

        Task {
            do {
                let context = await IMContextService.shared.context(
                    for: scenario,
                    relationship: relationshipProfile
                )
                let opening = try await conversationService.generateReply(
                    setup: setup,
                    turns: [],
                    state: conversationState,
                    profile: coachingProfileStore.profile,
                    relationship: relationshipProfile,
                    context: context,
                    latestUserSignal: nil
                )

                await MainActor.run {
                    let balancedOpeningState = IMTurnStateBalancer.balanced(
                        current: conversationState,
                        proposed: opening.updatedState,
                        signal: nil,
                        isOpening: true
                    )
                    sessionContext = context
                    turns = [IMConversationTurn(speaker: .npc, text: opening.message)]
                    conversationState = balancedOpeningState
                    isAwaitingNPC = false
                    isWrappingUp = opening.shouldWrapUp
                    speakIfEnabled(opening.message)
                }
            } catch {
                await MainActor.run {
                    isAwaitingNPC = false
                    isSessionActive = false
                    serviceErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startReply() async {
#if canImport(AVFAudio)
        messageSpeaker.stop()
#endif
        speechVM.resetCurrentSession()
        try? await Task.sleep(for: .milliseconds(180))
        speechVM.prepareSession(mode: .imConversation)
        speechVM.startRecording()
    }

    private func finishUserReply() {
        guard speechVM.isRecording else { return }
        speechVM.stopRecording()
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            let text = sanitizedUserReplyText(from: draftReplyText)
            guard !text.isEmpty else { return }
            await processReply(text)
        }
    }

    private func sendCurrentReply() {
        if speechVM.isRecording {
            finishUserReply()
            return
        }

        let text = sanitizedUserReplyText(from: draftReplyText)
        guard !text.isEmpty else { return }
        Task { await processReply(text) }
    }

    private func processReply(_ text: String) async {
        let analyzedSignal = IMUserMessageAnalyzer.analyze(
            text: text,
            currentState: conversationState,
            scenario: scenario,
            relationship: relationshipProfile
        )

        await MainActor.run {
            totalDuration += speechVM.lastSessionDuration
            totalFillers += speechVM.fillerWordCount
            turns.append(IMConversationTurn(speaker: .user, text: text))
            latestUserSignal = analyzedSignal
            conversationState = analyzedSignal.adjustedState
            isAwaitingNPC = true
        }

        do {
            let reply = try await conversationService.generateReply(
                setup: setup,
                turns: turns,
                state: analyzedSignal.adjustedState,
                profile: coachingProfileStore.profile,
                relationship: relationshipProfile,
                context: sessionContext,
                latestUserSignal: analyzedSignal
            )

            await MainActor.run {
                let balancedReplyState = IMTurnStateBalancer.balanced(
                    current: analyzedSignal.adjustedState,
                    proposed: reply.updatedState,
                    signal: analyzedSignal,
                    isOpening: false
                )
                turns.append(IMConversationTurn(speaker: .npc, text: reply.message))
                conversationState = balancedReplyState
                isAwaitingNPC = false
                isWrappingUp = reply.shouldWrapUp || analyzedSignal.shouldForceWrapUp || userTurnCount >= 6
                speechVM.resetCurrentSession()
                speakIfEnabled(reply.message)
            }
        } catch {
            await MainActor.run {
                isAwaitingNPC = false
                speechVM.resetCurrentSession()
                serviceErrorMessage = error.localizedDescription
            }
        }
    }

    private func endConversation() {
        Task {
            let transcript = combinedUserTranscript
            guard !transcript.isEmpty else {
                await MainActor.run { dismiss() }
                return
            }

            do {
                let evaluation = try await evaluationService.evaluateConversation(
                    setup: setup,
                    turns: turns,
                    finalState: conversationState,
                    transcript: transcript,
                    fillerCount: totalFillers,
                    duration: totalDuration,
                    recentSessions: speechVM.pastSessions,
                    profile: coachingProfileStore.profile,
                    relationship: relationshipProfile,
                    context: sessionContext
                )

                await MainActor.run {
                    let finalEvaluation = evaluation
                    let updatedRelationship = relationshipStore.applySessionOutcome(
                        scenario: scenario,
                        turns: turns,
                        finalState: conversationState,
                        evaluation: finalEvaluation
                    )

                    if let closingMessage = finalEvaluation.outcome?.closingMessage,
                       turns.last?.text != closingMessage {
                        turns.append(IMConversationTurn(speaker: .npc, text: closingMessage))
                        speakIfEnabled(closingMessage)
                    }

                    summaryEvaluation = finalEvaluation
                    summaryTranscript = AttributedString(transcript)

                    _ = PracticeSessionFinalizer.finalize(
                        store: sessionStore,
                        draft: PracticeSessionDraft(
                            transcript: transcript,
                            fillerWordCount: totalFillers,
                            duration: totalDuration,
                            date: Date(),
                            mode: .imConversation,
                            imDetails: IMConversationDetails(
                                setup: setup,
                                turns: turns,
                                actualTone: finalEvaluation.actualTone,
                                finalState: conversationState,
                                outcome: finalEvaluation.outcome,
                                relationshipSnapshot: updatedRelationship,
                                contextSnapshot: sessionContext
                            )
                        ),
                        annotation: PracticeSessionAnnotation(
                            score: finalEvaluation.overallScore,
                            xpEarned: finalEvaluation.xpEarned,
                            headline: finalEvaluation.headline,
                            insights: summaryInsights,
                            coachSummary: finalEvaluation.feedback
                        )
                    )
                    showSummary = true
                }
            } catch {
                await MainActor.run {
                    serviceErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resetConversation() {
#if canImport(AVFAudio)
        messageSpeaker.stop()
#endif
        turns = []
        conversationState = relationshipStore.startingState(for: scenario)
        isSessionActive = false
        isAwaitingNPC = false
        isWrappingUp = false
        totalDuration = 0
        totalFillers = 0
        summaryEvaluation = nil
        summaryTranscript = AttributedString("")
        serviceErrorMessage = nil
        sessionContext = IMSessionContextProvider.current()
        latestUserSignal = nil
        speechVM.resetCurrentSession()
    }

    private func speakIfEnabled(_ text: String) {
#if canImport(AVFAudio)
        guard imVoicePlaybackSettings.isEnabled else { return }
        messageSpeaker.speak(text, setup: setup)
#endif
    }

    private func sanitizedUserReplyText(from rawText: String) -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let lastNPC = turns.last(where: { $0.speaker == .npc })?.text else {
            return trimmed
        }

        let userWords = tokenizedWords(in: trimmed)
        let npcWords = tokenizedWords(in: lastNPC)
        guard !userWords.isEmpty, !npcWords.isEmpty else { return trimmed }

        let overlapLimit = min(8, userWords.count, npcWords.count)
        var overlapCount = 0

        for count in stride(from: overlapLimit, through: 1, by: -1) {
            let userPrefix = userWords.prefix(count).map(\.normalized)
            let npcSuffix = npcWords.suffix(count).map(\.normalized)
            if userPrefix == npcSuffix {
                overlapCount = count
                break
            }
        }

        guard overlapCount > 0 else { return trimmed }
        return userWords
            .dropFirst(overlapCount)
            .map(\.original)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenizedWords(in text: String) -> [TranscriptWord] {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .map(String.init)
            .map { TranscriptWord(original: $0) }
            .filter { !$0.normalized.isEmpty }
    }

    private func dismiss(times: Int) {
        guard times > 0 else { return }
        withAnimation(.none) { dismiss() }
        if times > 1 {
            DispatchQueue.main.async { dismiss(times: times - 1) }
        }
    }
}

private enum SetupStep {
    case scenario
    case tone
}

private struct TranscriptWord {
    let original: String

    var normalized: String {
        original
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "'" }
    }
}

#Preview {
    if #available(iOS 17.0, macOS 12.0, *) {
        IMPracticeView()
    }
}
#endif
