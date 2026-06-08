#if canImport(SwiftUI)
import SwiftUI

// MARK: - Live Coach Call
//
// The DEFAULT coach surface: an immersive, face-to-face "call" with Noum rather
// than a text thread. The `NoumCharacter` orb is the face — it shifts mood with
// the conversation (listening while you speak, thinking while it composes,
// coaching while it speaks back). Captions show the latest turn, not a scrolling
// transcript.
//
// HANDS-FREE: tap the mic once to start. You talk; a ~2.2s pause auto-sends your
// turn; the coach replies and speaks aloud; the mic re-arms itself for your next
// turn — no tapping between turns. Tapping while it's speaking barges in; tapping
// while listening ends the session. Mic stays off while the coach speaks so it
// never hears itself.
//
// Reuses: `AskNoumStore` (same thread the chat reads/writes), `AskNoumVoiceInput`
// (mic), `IMMessageSpeaker` (speak-aloud), `CoachReplyPipeline` (one brain with
// the chat). "Type" drops to the chat; "Leave" pops the surface.

@available(iOS 17.0, macOS 12.0, *)
struct LiveCoachCallView: View {
    /// Switch to the typed chat view (the "Type instead" affordance).
    var onSwitchToType: () -> Void
    /// Leave the coach surface entirely.
    var onLeave: () -> Void

    @StateObject private var store = AskNoumStore.shared
    @StateObject private var voiceInput = AskNoumVoiceInput()
    @StateObject private var speaker = IMMessageSpeaker.shared
    @StateObject private var voiceSettings = IMVoicePlaybackSettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The hands-free session is engaged (auto silence-send + auto re-arm).
    @State private var loopActive = false
    /// Last time the live transcript changed — drives silence detection.
    @State private var lastPartialAt = Date()
    /// Keeps old chat history from leaking into the live landing. The live call
    /// only shows captions after this session has produced a new turn.
    @State private var hasLiveExchange = false

    /// Polls for end-of-turn silence. Cheap no-op unless we're recording.
    private let tick = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    /// A pause this long (with words captured) ends the turn and sends.
    private let silenceThreshold: TimeInterval = 2.2

    private var voice: SpeakingStyleGoal? { coachingProfileStore.profile?.chosenStyleGoal }
    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
    }

    // Conversation state → the orb's mood (the "face" reacting to the call).
    private var orbMood: NoumCharacter.Mood {
        if voiceInput.state == .recording { return .listening }
        if store.isAwaitingReply { return .thinking }
        if speaker.isSpeaking { return .coaching }
        return .calm
    }

    private var stateLine: String {
        if !voiceInput.isAvailable { return "Use Type to write instead" }
        if !loopActive { return "Tap Talk to begin" }
        if voiceInput.state == .recording { return "Listening — pause when you're done" }
        if store.isAwaitingReply { return "Thinking…" }
        if speaker.isSpeaking { return "Speaking…" }
        return "…"
    }

    /// Captions: your live words while you speak, otherwise the coach's latest
    /// turn. Nil while a reply is composing (the orb carries it).
    private var caption: String? {
        if voiceInput.state == .recording {
            return voiceInput.partialTranscript.isEmpty ? nil : voiceInput.partialTranscript
        }
        if store.isAwaitingReply { return nil }
        guard hasLiveExchange || speaker.isSpeaking else { return nil }
        return store.messages.last(where: { $0.role == .coach && !$0.isPending })?.text
    }

    private var captionSpeaker: String {
        voiceInput.state == .recording ? "YOU" : "NOUM"
    }

    private var shouldShowCoachingBrief: Bool {
        coachingFocusLine != nil &&
        !hasLiveExchange &&
        voiceInput.state != .recording &&
        !store.isAwaitingReply &&
        !speaker.isSpeaking
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                liveBar
                Spacer(minLength: 0)
                presence
                if shouldShowCoachingBrief {
                    coachingBriefCard
                } else {
                    captionArea
                }
                Spacer(minLength: 0)
                controlBar
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { voiceInput.onFinalTranscript = { text in handleUtterance(text) } }
        .onDisappear { endLoop() }
        // Silence detection — ends the turn after a natural pause.
        .onReceive(tick) { _ in silenceTick() }
        .onChange(of: voiceInput.partialTranscript) { _, _ in lastPartialAt = Date() }
        // Re-arm the mic once the coach is done (covers spoken + unspoken replies).
        .onChange(of: store.isAwaitingReply) { _, awaiting in if !awaiting { scheduleReArm() } }
        .onChange(of: speaker.isSpeaking) { _, speaking in if !speaking { reArmIfReady() } }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.08, blue: 0.22),
                         Color(red: 0.05, green: 0.05, blue: 0.10)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [AppColor.pro.opacity(0.28), .clear],
                center: .init(x: 0.5, y: 0.18), startRadius: 4, endRadius: 360
            )
        }
    }

    // MARK: - Live bar

    private var liveBar: some View {
        HStack(spacing: 8) {
            Circle().fill((loopActive ? Color.red : AppColor.pro).opacity(loopActive ? 0.9 : 0.65)).frame(width: 8, height: 8)
            Text(loopActive ? "LIVE" : "COACH")
                .font(Typography.micro.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text("with Noum")
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live call with Noum")
    }

    // MARK: - Presence (the face)

    private var presence: some View {
        VStack(spacing: Spacing.md) {
            NoumCharacter(mood: orbMood, tint: AppColor.pro, size: 168, stage: characterStage)
                .accessibilityHidden(true)
            Text("Noum")
                .font(Typography.cardTitle)
                .foregroundStyle(.white)
            Text(stateLine)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: stateLine)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Noum — \(stateLine)")
    }

    // MARK: - Captions

    @ViewBuilder
    private var captionArea: some View {
        if let caption, !caption.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(captionSpeaker)
                    .font(Typography.micro.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.4))
                ScrollView {
                    Text(caption)
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: 150)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .padding(.top, Spacing.lg)
            .transition(.opacity)
        }
    }

    // MARK: - Coaching focus line
    //
    // The live-call landing leads with the orb + "Tap Talk to begin" (stateLine).
    // We add at most ONE supporting focus line — never the old four-field
    // "COACHING READ" meta-brief (headline / current work / target / next move),
    // which made the user read a clinical case sheet before saying a word and,
    // on a cold start, surfaced an "I have nothing yet" version. When there is no
    // earned focus, we show nothing and let "Tap Talk" carry the moment.

    @ViewBuilder
    private var coachingBriefCard: some View {
        if let focus = coachingFocusLine {
            Text(focus)
                .font(Typography.headline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
                .transition(.opacity)
                .accessibilityIdentifier("askNoum.live.coachBrief")
                .accessibilityLabel("Coaching focus. \(focus)")
        }
    }

    /// The single focus line for the live-call landing, or `nil` on a cold start
    /// (no earned case file → no focus to name, so the landing stays "Tap Talk").
    private var coachingFocusLine: String? {
        guard let caseFile = coachMemoryStore.currentMemory?.caseFile else { return nil }
        return bounded(caseFile.hypothesis)
            ?? caseFile.focus.map { "Today's lever: \($0.displayName.lowercased())." }
            ?? bounded(caseFile.activeIntervention)
    }

    private func bounded(_ value: String?, maximumLength: Int = 96) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        if trimmed.count <= maximumLength { return trimmed }
        let clipped = String(trimmed.prefix(maximumLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clipped + "..."
    }

    // MARK: - Control bar (Zoom-style)

    private var controlBar: some View {
        HStack(spacing: Spacing.lg) {
            callButton(
                glyph: loopActive ? "stop.fill" : "mic.fill",
                label: loopActive ? "Stop" : "Talk",
                fill: loopActive ? AppColor.pro : Color.white.opacity(0.12),
                ring: voiceInput.state == .recording,
                disabled: !voiceInput.isAvailable
            ) { micTapped() }

            callButton(
                glyph: voiceSettings.askNoumSpokenRepliesEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                label: "Aloud",
                fill: Color.white.opacity(0.12),
                tint: voiceSettings.askNoumSpokenRepliesEnabled ? AppColor.positive : .white
            ) { toggleAloud() }

            callButton(glyph: "keyboard", label: "Type", fill: Color.white.opacity(0.12)) {
                endLoop(); onSwitchToType()
            }

            callButton(glyph: "xmark", label: "Leave", fill: Color.red.opacity(0.9)) {
                endLoop(); onLeave()
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    @ViewBuilder
    private func callButton(
        glyph: String, label: String, fill: Color,
        tint: Color = .white, ring: Bool = false, disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                ZStack {
                    if ring && !reduceMotion {
                        Circle().stroke(AppColor.pro.opacity(0.5), lineWidth: 2).frame(width: 60, height: 60)
                    }
                    Circle().fill(fill).frame(width: 52, height: 52)
                    Image(systemName: glyph)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Hands-free loop

    private func micTapped() {
        if loopActive {
            if speaker.isSpeaking {
                speaker.stop()        // barge-in: cut the coach off
                startRecording()      // and take the floor
            } else {
                endLoop()             // stop the session
            }
        } else {
            loopActive = true
            speaker.stop()
            startRecording()
        }
    }

    private func startRecording() {
        guard voiceInput.isAvailable else { return }
        if voiceInput.state != .recording { voiceInput.toggle() }
        lastPartialAt = Date()
    }

    private func endLoop() {
        loopActive = false
        voiceInput.cancelRecording()
        speaker.stop()
    }

    /// End the turn after a natural pause (hands-free send).
    private func silenceTick() {
        guard loopActive,
              voiceInput.state == .recording,
              !voiceInput.partialTranscript.isEmpty,
              Date().timeIntervalSince(lastPartialAt) > silenceThreshold
        else { return }
        voiceInput.stopAndSend()  // → onFinalTranscript → handleUtterance
    }

    /// After a reply lands but won't be spoken (aloud off / no provider), the
    /// `speaker.isSpeaking` transition never fires — so re-arm on a short delay.
    private func scheduleReArm() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { reArmIfReady() }
    }

    private func reArmIfReady() {
        guard loopActive,
              voiceInput.state == .idle,
              !store.isAwaitingReply,
              !speaker.isSpeaking
        else { return }
        startRecording()
    }

    private func handleUtterance(_ text: String) {
        hasLiveExchange = true
        let ids = store.appendUserTurn(text)
        Task {
            let outcome = await CoachReplyPipeline.generate(coachID: ids.coachID)
            if AskNoumSpokenMode.shouldSpeak(
                outcome: outcome,
                spokenRepliesEnabled: voiceSettings.askNoumSpokenRepliesEnabled,
                localeSupportsAI: LocaleSettingsManager.shared.current.aiSupported
            ), case .reply(let replyText) = outcome {
                speaker.speak(
                    replyText,
                    setup: IMConversationSetup(
                        scenario: .workUpdate,
                        targetTone: AskNoumSpokenMode.coachTone(for: voice)
                    )
                )
            }
        }
    }

    private func toggleAloud() {
        voiceSettings.askNoumSpokenRepliesEnabled.toggle()
        if !voiceSettings.askNoumSpokenRepliesEnabled { speaker.stop() }
    }
}

#endif
