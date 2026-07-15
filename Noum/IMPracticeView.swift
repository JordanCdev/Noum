import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct IMPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var navigationPath: NavigationPath
    @StateObject private var speechVM: SpeechRecognizerViewModel
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var relationshipStore = IMRelationshipStore.shared
    @StateObject private var imVoicePlaybackSettings = IMVoicePlaybackSettingsManager.shared
#if canImport(AVFAudio)
    @StateObject private var messageSpeaker = IMMessageSpeaker.shared
#endif

    @State private var scenario: IMConversationScenario?
    @State private var targetTone: IMTargetTone?
    @State private var turns: [IMConversationTurn] = []
    @State private var conversationState: IMConversationState = .starting
    @State private var isSessionActive = false
    @State private var isAwaitingNPC = false
    @State private var isWrappingUp = false
    @State private var totalDuration: TimeInterval = 0
    @State private var totalFillers = 0
    // Mini-drill navigation

    @State private var summaryTranscript = AttributedString("")
    @State private var summaryEvaluation: IMConversationEvaluation?
    @State private var serviceErrorMessage: String?
    @State private var isEndingConversation = false
    @State private var evaluationFailed = false
    @State private var setupStep: SetupStep = .scenario
    @State private var typingPhase = 0
    @State private var processingStripeOffset: CGFloat = -140
    @State private var sessionContext = IMSessionContextProvider.current()
    @State private var latestUserSignal: IMUserMessageSignal?
    @State private var cachedRelationshipProfile = IMRelationshipProfile.initial(for: .socialCatchUp)
    @State private var showExitConfirmation = false
    @State private var sessionElapsedSeconds = 0
    @State private var sessionTimeoutNudge: String?
    @State private var sessionTimerTask: Task<Void, Never>?
    @State private var openingTask: Task<Void, Never>?
    @State private var replyTask: Task<Void, Never>?
    @State private var evaluationTask: Task<Void, Never>?

    private static let sessionMaxSeconds = 900    // 15-minute hard cap
    private static let sessionNudgeSeconds = 720  // 12-minute gentle nudge

    private let preferredScenario: IMConversationScenario?
    private let preferredTone: IMTargetTone?

    private let conversationService: IMConversationServicing = IMConversationService()
    private let evaluationService: IMConversationEvaluatorServicing = IMConversationEvaluationService()

    init(
        navigationPath: Binding<NavigationPath>,
        preferredScenario: IMConversationScenario? = nil,
        preferredTone: IMTargetTone? = nil
    ) {
        _navigationPath = navigationPath
        _speechVM = StateObject(wrappedValue: SpeechRecognizerViewModel(preloadOnInit: false))
        self.preferredScenario = preferredScenario
        self.preferredTone = preferredTone
    }

    private var setup: IMConversationSetup? {
        guard let scenario, let targetTone else { return nil }
        return IMConversationSetup(scenario: scenario, targetTone: targetTone)
    }

    private var relationshipProfile: IMRelationshipProfile {
        cachedRelationshipProfile
    }

    private var userTurnCount: Int {
        turns.filter { $0.speaker == .user }.count
    }

    private var setupGuidanceTitle: String {
        guard let scenario else {
            return "Choose how you want to come across"
        }

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
        guard let targetTone else {
            return "Pick a tone to shape the pace, phrasing, and overall feel of the conversation."
        }

        return "Aim to \(targetTone.coachingPrompt)."
    }

    private var combinedUserTranscript: String {
        turns
            .filter { $0.speaker == .user }
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdvanceFromScenario: Bool { scenario != nil }

    private var canStartConversation: Bool {
        scenario != nil && targetTone != nil
    }

    private var isToneStep: Bool { setupStep == .tone }

    private var resolvedScenario: IMConversationScenario {
        scenario ?? preferredScenario ?? .socialCatchUp
    }

    private var resolvedTargetTone: IMTargetTone {
        targetTone ?? preferredTone ?? .confident
    }

    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
    }

    var body: some View {
        ZStack {
            if isEndingConversation {
                AppColor.screenBackground.ignoresSafeArea()
            } else {
                FocusedPracticeBackground(style: .conversation)
            }

            content
        }
        .overlay(alignment: .top) {
            // Real-time positive feedback — pulses when the engine catches
            // a rhetorical move in the user's dictated reply. styleGoal
            // makes the chip subtext goal-aware. Only mounts during the
            // active conversation phase so the setup and ending screens
            // stay calm.
            if isSessionActive && !isEndingConversation {
                LiveEloquenceHUD(
                    speechVM: speechVM,
                    styleGoal: coachingProfileStore.profile?.chosenStyleGoal
                )
                .padding(.top, 4)
            }
        }
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
        .accessibilityIdentifier("imPractice.screen")
        .safeAreaInset(edge: .bottom) {
            if !isSessionActive && !isEndingConversation {
                bottomSetupBar
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.black.opacity(0.10).ignoresSafeArea())
            } else if isSessionActive && !isEndingConversation {
                composerBar
                    .environment(\.colorScheme, .dark)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .tint(isEndingConversation ? AppColor.brandBlue : .white)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if isSessionActive {
                        showExitConfirmation = true
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Back")
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
        .alert("Conversation Practice unavailable", isPresented: .constant(serviceErrorMessage != nil), actions: {
            Button("OK", role: .cancel) { serviceErrorMessage = nil }
        }, message: {
            Text(serviceErrorMessage ?? "")
        })
        // C5 — surface transcription start failures the way Timed /
        // SuddenDeath already do. Without this the IM rep was the one
        // surface that NEVER read `connectionError`: a failed provider
        // start left a silently dead mic ("Listening..." with no words).
        .onChange(of: speechVM.connectionError) { _, error in
            if let error { serviceErrorMessage = error }
        }
        .task(id: isAwaitingNPC) {
            guard isAwaitingNPC || isEndingConversation else {
                typingPhase = 0
                return
            }

            while isAwaitingNPC || isEndingConversation {
                try? await Task.sleep(for: .milliseconds(220))
                guard isAwaitingNPC || isEndingConversation else { break }
                typingPhase = (typingPhase + 1) % 3
            }
        }
        .task(id: isEndingConversation) {
            guard isEndingConversation else {
                processingStripeOffset = -140
                return
            }

            processingStripeOffset = -140
            while isEndingConversation {
                if reduceMotion {
                    processingStripeOffset = 0
                } else {
                    withAnimation(.linear(duration: 1.05)) {
                        processingStripeOffset = 140
                    }
                }
                try? await Task.sleep(for: .milliseconds(1050))
                guard isEndingConversation else { break }
                processingStripeOffset = -140
            }
        }
        // Summary navigation is handled by path-based .navigationDestination(for:) in ContentView
        .onAppear {
            if let preferredScenario {
                scenario = preferredScenario
                setupStep = preferredTone == nil ? .tone : .scenario
            }
            if let preferredTone {
                targetTone = preferredTone
            }
            if preferredScenario != nil, preferredTone != nil {
                setupStep = .tone
            }
            cachedRelationshipProfile = IMRelationshipProfile.initial(for: resolvedScenario)

            // Quick Start handshake — picker armed IM for a one-tap
            // launch. IM has two setup steps (scenario, tone); Quick
            // Start defaults to social catch-up + confident (the
            // existing `resolved*` fallbacks) and goes straight into
            // `beginConversation` so the user lands in a live thread,
            // not on the scenario grid.
            if !isSessionActive, PracticeModeQuickStart.consume(for: .imConversation) {
                if scenario == nil { scenario = resolvedScenario }
                if targetTone == nil { targetTone = resolvedTargetTone }
                cachedRelationshipProfile = IMRelationshipProfile.initial(for: resolvedScenario)
                beginConversation()
            }
        }
        .onDisappear {
            openingTask?.cancel()
            replyTask?.cancel()
            evaluationTask?.cancel()
            stopSessionTimer()
            speechVM.cancelRecording()
#if canImport(AVFAudio)
            messageSpeaker.stop()
#endif
        }
    }

    @ViewBuilder
    private var content: some View {
        if isEndingConversation {
            endingConversationScreen
        } else if !isSessionActive {
            FocusedPracticeScaffold(
                style: .conversation,
                status: setupStep == .scenario ? "Step 1 of 2" : "Step 2 of 2",
                title: "Conversation Practice",
                subtitle: "Choose the situation, then decide how you want to sound."
            ) {
                NoumCharacter(
                    mood: .calm,
                    tint: .white,
                    size: 48,
                    stage: characterStage
                )
                .accessibilityHidden(true)
            } content: {
                setupPanel
            }
        } else {
            VStack(spacing: 12) {
                activeHeaderCard

                // Goal-aware intent reminder — fires once per session (not
                // per dictated reply) so the IM user sees what voice
                // they're working toward without being re-anchored every
                // turn. Silent when no CoachingProfile is set.
                if let voice = coachingProfileStore.profile?.chosenStyleGoal {
                    VoiceAnchorBanner(
                        styleGoal: voice,
                        isRecording: speechVM.isRecording,
                        resetsBetweenReps: false
                    )
                }

                conversationCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .environment(\.colorScheme, .dark)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Conversation Practice", systemImage: "message.badge.waveform.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 8) {
                Text(isSessionActive ? resolvedScenario.title : "Choose a conversation")
                    .font(Typography.screenTitle)
                Text(isSessionActive ? "Target tone: \(resolvedTargetTone.title)" : "Pick a scenario, then shape the tone.")
                    .font(Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }

            if !isSessionActive {
                HStack(spacing: 10) {
                    selectionSummaryChip(
                        title: "Scenario",
                        value: scenario?.title ?? "Not selected",
                        isComplete: scenario != nil
                    )
                    selectionSummaryChip(
                        title: "Tone",
                        value: targetTone?.title ?? "Not selected",
                        isComplete: targetTone != nil
                    )
                }
            } else {
                Text("You’re rehearsing a live conversation with \(resolvedScenario.personaName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
        )
    }

    private var setupPanel: some View {
        Group {
            if setupStep == .scenario {
                setupCard
            } else {
                guidanceCard
            }
        }
    }

    private var bottomSetupBar: some View {
        HStack(spacing: 10) {
            if isToneStep {
                Button("Back") {
                    setupStep = .scenario
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, 24)
                .background(Color.white.opacity(0.95), in: Capsule())

                Button("Start conversation") {
                    beginConversation()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(canStartConversation ? Color.white : Color.white.opacity(0.32), in: Capsule())
                .foregroundStyle(canStartConversation ? AppColor.modeIM : Color.white.opacity(0.58))
                .buttonStyle(.pressable)
                .disabled(!canStartConversation)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                NoumCharacter(
                    mood: speechVM.isRecording ? .listening : .calm,
                    tint: AppColor.modeIM,
                    size: 32,
                    audioLevel: speechVM.audioLevel,
                    stage: characterStage
                )
                .accessibilityHidden(true)

                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Text(String(resolvedScenario.personaName.prefix(1)))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(resolvedScenario.personaName)
                        .font(.headline.weight(.bold))
                    Text(resolvedScenario.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isAwaitingNPC {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // One qualitative target chip only. Raw live Trust/Tension numbers
            // were cut per the UX overhaul (metrics-without-judgment mid-rep);
            // the conversation should be felt, not read off a gauge. The
            // qualitative relationship read lives in `continuitySummary` below.
            HStack(spacing: 8) {
                statusChip(title: "Tone", value: resolvedTargetTone.title, tint: .indigo)
            }

            Text(relationshipProfile.continuitySummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColor.focusedGlassFill, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .focusedGlassSurface()
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scenario")
                    .font(.headline)
                Text("Choose the kind of conversation you want to rehearse. Nothing is selected until you choose.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ForEach(IMConversationScenario.allCases) { option in
                    scenarioCard(for: option)
                }
            }
        }
        .padding(16)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tone")
                    .font(.headline)
                Text("Set how you want to sound before the chat begins.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10),
                    GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(IMTargetTone.allCases) { tone in
                    toneChip(for: tone)
                }
            }

            Text(setupGuidanceTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 6)
            Text(setupGuidanceBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let scenario {
                detailPillPair(
                    first: (title: scenario.personaName, systemImage: "person.fill"),
                    second: (title: scenario.stakes, systemImage: "bolt.horizontal.fill")
                )
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
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

                    if let nudge = sessionTimeoutNudge {
                        Text(nudge)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .id("timeout-nudge")
                    }
                }
                .padding(6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, Spacing.md)
            .background(AppColor.focusedGlassFill, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .focusedGlassSurface()
            .onChange(of: turns.count) { _, _ in
                if let last = turns.last?.id {
                    if reduceMotion {
                        proxy.scrollTo(last, anchor: .bottom)
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: isAwaitingNPC) { _, awaiting in
                guard awaiting else { return }
                if reduceMotion {
                    proxy.scrollTo("typing-indicator", anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("typing-indicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageBubble(_ turn: IMConversationTurn) -> some View {
        HStack {
            if turn.speaker == .npc {
                bubbleContent(
                    title: resolvedScenario.personaName,
                    text: turn.text,
                    tint: Color.white.opacity(0.13),
                    isLeading: true
                )
                Spacer(minLength: 72)
            } else {
                Spacer(minLength: 72)
                bubbleContent(
                    title: "You",
                    text: turn.text,
                    tint: Color.white.opacity(0.22),
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
        .padding(Spacing.cardGap)
        .background(tint, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var typingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(resolvedScenario.personaName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.secondary.opacity(0.6))
                            .frame(width: 7, height: 7)
                            .scaleEffect(typingPhase == index ? 1.1 : 0.72)
                            .opacity(typingPhase == index ? 1 : 0.45)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: typingPhase)
                    }
                }
            }
            .frame(maxWidth: 120, alignment: .leading)
            .padding(Spacing.cardGap)
            .background(AppColor.focusedGlassFill, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .focusedGlassSurface()
            Spacer(minLength: 72)
        }
    }

    private var endingConversationScreen: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            if evaluationFailed {
                VStack(spacing: 12) {
                    Text("Couldn't finish")
                        .font(Typography.figtree(size: 26, weight: .bold, relativeTo: .title2))

                    Text("Noum couldn’t finish this read. Try again or return home.")
                        .font(Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    Button {
                        retryEvaluation()
                    } label: {
                        Text("Try Again")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Return home")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 12) {
                    Text("Wrapping up")
                        .font(Typography.figtree(size: 26, weight: .bold, relativeTo: .title2))

                    Text(endingStageMessage)
                        .font(Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                processingIndicator
                    .padding(.horizontal, 36)

                sessionWrapUpCard
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 24)
    }

    private var endingStageMessage: String {
        switch typingPhase {
        case 0:
            return "Reading the full conversation and tone."
        case 1:
            return "Checking how the conversation changed."
        default:
            return "Preparing your summary and next move."
        }
    }

    private var processingIndicator: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.blue.opacity(0.12))
                .frame(height: 10)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.10),
                            Color.blue.opacity(0.80),
                            Color.blue.opacity(0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 118, height: 10)
                .offset(x: processingStripeOffset)
        }
        .frame(maxWidth: .infinity)
        .clipShape(Capsule())
    }

    private var sessionWrapUpCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Conversation snapshot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                wrapUpChip(title: "Turns", value: "\(userTurnCount)", tint: .blue)
                wrapUpChip(title: "Fillers", value: "\(totalFillers)", tint: .orange)
                wrapUpChip(title: "XP", value: "+\(summaryEvaluation?.xpEarned ?? 0)", tint: .teal)
            }

            Text("Preparing your score, conversation read, and next move.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.96), Color.blue.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    private func wrapUpChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    if speechVM.isRecording {
                        finishUserReply()
                    } else {
                        Task { await startReply() }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .fill(speechVM.isRecording ? Color.red.opacity(0.16) : Color.blue.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: speechVM.isRecording ? "stop.fill" : "mic.fill")
                            .font(.headline)
                            .foregroundStyle(speechVM.isRecording ? .red : .blue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAwaitingNPC || (speechVM.recordingLifecycle.isBusy && !speechVM.isRecording))

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        isAwaitingNPC
                            ? "\(resolvedScenario.personaName) is typing..."
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
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
            .disabled(speechVM.isRecording || isAwaitingNPC || isEndingConversation)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if isEndingConversation {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Wrapping up...")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 4)
                .padding(.bottom, 2)
            }
        }
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
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    private func scenarioCard(for option: IMConversationScenario) -> some View {
        Button {
            scenario = option
            targetTone = nil
            setupStep = .tone
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            .fill((scenario == option ? Color.blue : Color.gray).opacity(scenario == option ? 0.14 : 0.10))
                            .frame(width: 48, height: 48)
                        Image(systemName: scenarioIconName(for: option))
                            .font(.headline)
                            .foregroundStyle(scenario == option ? .blue : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(option.summary)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: scenario == option ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(scenario == option ? .blue : .secondary)
                }

                detailPillPair(
                    first: (title: option.personaName, systemImage: "person.fill"),
                    second: (title: option.stakes, systemImage: "sparkles")
                )
            }
            .padding(Spacing.cardGap)
            .background(
                (scenario == option ? Color.blue.opacity(0.08) : Color.white.opacity(0.8)),
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(scenario == option ? Color.blue.opacity(0.35) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("imPractice.scenario.\(option.rawValue)")
        .accessibilityAddTraits(scenario == option ? [.isSelected] : [])
    }

    private func toneChip(for tone: IMTargetTone) -> some View {
        Button {
            targetTone = tone
        } label: {
            Text(tone.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(targetTone == tone ? .white : .primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
                .background(
                    targetTone == tone ? Color.blue : Color.white.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(targetTone == tone ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("imPractice.tone.\(tone.rawValue)")
        .accessibilityAddTraits(targetTone == tone ? [.isSelected] : [])
    }

    private func selectionSummaryChip(title: String, value: String, isComplete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isComplete ? .primary : .secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 0.96, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func detailPill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(Typography.micro.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.04), in: Capsule())
    }

    private func detailPillPair(
        first: (title: String, systemImage: String),
        second: (title: String, systemImage: String)
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                detailPill(title: first.title, systemImage: first.systemImage)
                detailPill(title: second.title, systemImage: second.systemImage)
            }

            VStack(alignment: .leading, spacing: 8) {
                detailPill(title: first.title, systemImage: first.systemImage)
                detailPill(title: second.title, systemImage: second.systemImage)
            }
        }
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
        return IMToneMatcher.score(for: resolvedTargetTone, transcript: transcript)
    }

    private func beginConversation() {
        guard let scenario, let targetTone else { return }
        guard IMModeAvailability.isAvailable else {
            serviceErrorMessage = IMModeServiceError.unavailable.errorDescription
            return
        }
        let setup = IMConversationSetup(scenario: scenario, targetTone: targetTone)
#if canImport(AVFAudio)
        messageSpeaker.resetSessionPlaybackState()
#endif
        resetConversation()
        isSessionActive = true
        startSessionTimer()
        cachedRelationshipProfile = relationshipStore.profile(for: scenario)
        conversationState = relationshipStore.startingState(for: scenario)
        isAwaitingNPC = true

        openingTask?.cancel()
        openingTask = Task {
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
        let started = await speechVM.startRecordingAwaitingReadiness()
        if !started {
            serviceErrorMessage = speechVM.connectionError
        }
    }

    private func finishUserReply() {
        guard speechVM.isRecording else { return }
        replyTask?.cancel()
        replyTask = Task { @MainActor in
            let completion = await speechVM.stopRecordingAwaitingFinalization()
            guard RecordingCompletionGate.allowsScoringAndProgress(completion),
                  !Task.isCancelled else { return }
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
        replyTask?.cancel()
        replyTask = Task { await processReply(text) }
    }

    private func processReply(_ text: String) async {
        guard let setup else { return }
        let analyzedSignal = IMUserMessageAnalyzer.analyze(
            text: text,
            currentState: conversationState,
            scenario: resolvedScenario,
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
        guard !isEndingConversation else { return }
        guard let setup else { return }
        isEndingConversation = true
        stopSessionTimer()
        CoachHaptic.sessionComplete()
        evaluationTask?.cancel()
        evaluationTask = Task {
            let transcript = combinedUserTranscript
            guard !transcript.isEmpty else {
                await MainActor.run {
                    isEndingConversation = false
                    dismiss()
                }
                return
            }

            let wordCount = transcript.split(whereSeparator: \.isWhitespace).count
            guard PracticeProgressEligibility.qualifies(
                wordCount: wordCount,
                duration: totalDuration
            ) else {
                // A transport-valid short capture still belongs in Review, but
                // it is not enough evidence for a coach grade or a durable
                // relationship update. Persist the raw conversation without
                // calling either the cloud evaluator or the relationship store.
                await MainActor.run {
                    summaryEvaluation = nil
                    summaryTranscript = AttributedString(transcript)

                    let pressureOn = PracticeSettingsManager.shared.pressureModeEnabled
                    let pressure = BaselineEngine.classifyPressure(
                        mode: .imConversation,
                        isPressureModeOn: pressureOn,
                        streakDays: PracticeSession.calculateStreak(from: sessionStore.sessions)
                    )
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
                                actualTone: nil,
                                finalState: conversationState,
                                outcome: nil,
                                relationshipSnapshot: relationshipProfile,
                                contextSnapshot: sessionContext
                            ),
                            pressureLevel: pressure,
                            isRated: pressureOn,
                            pauseMetrics: speechVM.currentSessionPauseMetrics()
                        )
                    )
                    pushSummary()
                    isEndingConversation = false
                }
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
                        scenario: resolvedScenario,
                        turns: turns,
                        finalState: conversationState,
                        evaluation: finalEvaluation
                    )
                    cachedRelationshipProfile = updatedRelationship

                    if let closingMessage = finalEvaluation.outcome?.closingMessage,
                       turns.last?.text != closingMessage {
                        turns.append(IMConversationTurn(speaker: .npc, text: closingMessage))
                        speakIfEnabled(closingMessage)
                    }

                    summaryEvaluation = finalEvaluation
                    summaryTranscript = AttributedString(transcript)

                    let pressureOn = PracticeSettingsManager.shared.pressureModeEnabled
                    let pressure = BaselineEngine.classifyPressure(
                        mode: .imConversation,
                        isPressureModeOn: pressureOn,
                        streakDays: PracticeSession.calculateStreak(from: sessionStore.sessions)
                    )
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
                            ),
                            pressureLevel: pressure,
                            isRated: pressureOn,
                            pauseMetrics: speechVM.currentSessionPauseMetrics()
                        ),
                        annotation: PracticeSessionAnnotation(
                            score: finalEvaluation.overallScore,
                            xpEarned: finalEvaluation.xpEarned,
                            headline: finalEvaluation.headline,
                            insights: summaryInsights,
                            coachSummary: finalEvaluation.feedback
                        )
                    )
                    pushSummary()
                    isEndingConversation = false
                }
            } catch {
                await MainActor.run {
                    evaluationFailed = true
                }
            }
        }
    }

    private func retryEvaluation() {
        evaluationFailed = false
        isEndingConversation = false
        endConversation()
    }

    // MARK: - Session Timer (wall-clock cap)

    private func startSessionTimer() {
        sessionElapsedSeconds = 0
        sessionTimeoutNudge = nil
        sessionTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    sessionElapsedSeconds += 1
                    if sessionElapsedSeconds == Self.sessionNudgeSeconds {
                        sessionTimeoutNudge = "Great conversation — wrapping up in a few minutes."
                    } else if sessionElapsedSeconds >= Self.sessionMaxSeconds {
                        endConversation()
                    }
                }
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimerTask?.cancel()
        sessionTimerTask = nil
    }

    private func resetConversation() {
#if canImport(AVFAudio)
        messageSpeaker.resetSessionPlaybackState()
#endif
        turns = []
        conversationState = relationshipStore.startingState(for: resolvedScenario)
        isSessionActive = false
        isAwaitingNPC = false
        isWrappingUp = false
        totalDuration = 0
        totalFillers = 0
        sessionElapsedSeconds = 0
        sessionTimeoutNudge = nil
        stopSessionTimer()
        summaryEvaluation = nil
        summaryTranscript = AttributedString("")
        serviceErrorMessage = nil
        isEndingConversation = false
        sessionContext = IMSessionContextProvider.current()
        latestUserSignal = nil
        speechVM.resetCurrentSession()
    }

    private func speakIfEnabled(_ text: String) {
#if canImport(AVFAudio)
        guard imVoicePlaybackSettings.isEnabled else { return }
        // Why: each call here is one speak() — IMMessageSpeaker.speak()
        // increments its internal generation token and bumps any in-flight
        // playback Task out of contention before playAudioData fires. So
        // turn-N text + turn-N audio stay paired even when the user races
        // through replies. The conversation loop above intentionally does
        // not need to coordinate stop/start itself.
        messageSpeaker.speak(
            text,
            setup: IMConversationSetup(scenario: resolvedScenario, targetTone: resolvedTargetTone)
        )
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

    // MARK: - Navigation

    private func pushSummary() {
        let payloadId = UUID()
        let entry = SummaryDataStore.Entry(
            transcript: summaryTranscript,
            fillerCount: totalFillers,
            duration: totalDuration,
            score: summaryEvaluation?.overallScore,
            progressSegments: min(4, userTurnCount),
            xpEarned: summaryEvaluation?.xpEarned ?? 0,
            committedFinalization: nil,
            suddenDeathGamePoints: nil,
            suddenDeathMultiplierLabels: [],
            suddenDeathTotalWords: nil,
            showDuration: true,
            practiceTitle: "Conversation — \(resolvedScenario.title)",
            feedbackOverride: summaryEvaluation?.feedback,
            headlineOverride: summaryEvaluation?.headline,
            scoreBreakdown: summaryEvaluation?.segments ?? [],
            insights: summaryInsights,
            recentSessions: sessionStore.sessions,
            imConversationDetails: IMConversationDetails(
                setup: setup ?? IMConversationSetup(scenario: resolvedScenario, targetTone: resolvedTargetTone),
                turns: turns,
                actualTone: summaryEvaluation?.actualTone,
                finalState: conversationState,
                outcome: summaryEvaluation?.outcome,
                relationshipSnapshot: relationshipProfile,
                contextSnapshot: sessionContext
            ),
            explicitMode: .imConversation,
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
        let payload = SummaryPayload(id: payloadId, mode: .imConversation)
        navigationPath.append(AppDestination.summary(payload))
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
        IMPracticeView(navigationPath: .constant(NavigationPath()))
    }
}
#endif
