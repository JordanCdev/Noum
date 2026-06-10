#if canImport(SwiftUI)
import SwiftUI

// MARK: - Live-call dead-mic watchdog (pure decision logic)
//
// C5 — the diagnosed live-call failure mode: the mic arms, "Listening…"
// shows, and the recognition backend silently hears nothing (broken
// simulator input route, dead recognition service). The session previously
// sat in that state forever. This watchdog flags an armed-but-wordless mic
// after a patient window so the call can say "I can't hear you" honestly
// and end the hands-free loop instead of pretending to listen.
//
// Pure + view-free so the threshold decision is unit-testable.
enum LiveCallMicWatchdog {

    /// Seconds an armed mic may stay wordless before we flag it. Long
    /// enough that a user gathering their thoughts (a few seconds of
    /// natural pre-speech silence is normal on a coaching call) is never
    /// interrupted; short enough that a genuinely dead mic is surfaced
    /// within one breath of suspicion, not a stuck forever-state.
    static let deadMicWindow: TimeInterval = 6.0

    /// Honest line shown when the watchdog fires. Names the likely fix and
    /// the typed escape hatch — never blames the user.
    static let notice = "I can't hear you — check mic access, or use Type instead."

    /// True when the hands-free loop should stop pretending to listen.
    static func shouldFlag(
        loopActive: Bool,
        isRecording: Bool,
        hasPartialTranscript: Bool,
        secondsSinceArmed: TimeInterval
    ) -> Bool {
        loopActive && isRecording && !hasPartialTranscript && secondsSinceArmed > deadMicWindow
    }
}

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
    /// When the mic last armed — feeds `LiveCallMicWatchdog` so an
    /// armed-but-wordless mic is surfaced honestly instead of sitting in a
    /// dead "Listening…" state. Nil while not recording.
    @State private var recordingArmedAt: Date? = nil
    /// Set when the dead-mic watchdog fires; cleared on the next Talk tap.
    @State private var deadMicNotice: String? = nil

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

    /// C5 — one honest status line under the state line, when something is
    /// genuinely wrong or worth knowing. Priority: dead-mic watchdog (the
    /// loop just ended because nothing was heard) > speech-input
    /// unavailability > spoken-reply unavailability (Aloud on, no engine
    /// could produce audio) > the honest "who is listening" engine label
    /// while recording. Nil in the common healthy idle states.
    private var honestStatusLine: String? {
        if let deadMicNotice { return deadMicNotice }
        if let micNotice = voiceInput.notice { return micNotice }
        if voiceSettings.askNoumSpokenRepliesEnabled,
           let voiceNotice = speaker.voiceUnavailableNotice {
            return voiceNotice
        }
        if voiceInput.state == .recording,
           let engine = voiceInput.activeEngineDescription {
            return engine
        }
        return nil
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

    /// True when the latest coach turn being captioned is the OFFLINE
    /// deterministic stand-in (model unreachable). Honest states invariant
    /// (A3): the live-call caption must mark it the same way the chat bubble
    /// does, never passing the local line off as the live coach. Only relevant
    /// when we're showing the coach's turn, not the user's live words.
    private var captionIsOffline: Bool {
        guard voiceInput.state != .recording else { return false }
        return store.messages.last(where: { $0.role == .coach && !$0.isPending })?.isOffline ?? false
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
        // C5 — speech input failed (chain exhausted / permission pulled):
        // end the hands-free loop honestly instead of retry-looping a dead
        // mic. The notice line explains; the user re-taps Talk to retry.
        .onChange(of: voiceInput.unavailableReason) { _, reason in
            if reason != nil, loopActive { endLoop() }
        }
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
            // C5 — never a silent dead state: mic problems, voice-output
            // problems, and the honest "who is listening" engine label all
            // surface here instead of being buried in debug fields.
            if let status = honestStatusLine {
                Text(status)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("askNoum.live.statusLine")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(honestStatusLine.map { "Noum — \(stateLine). \($0)" } ?? "Noum — \(stateLine)")
    }

    // MARK: - Captions

    @ViewBuilder
    private var captionArea: some View {
        if let caption, !caption.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(captionSpeaker)
                        .font(Typography.micro.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.4))
                    // A3: the offline stand-in is marked in the live caption too,
                    // so the local line is never read as the live coach speaking.
                    if captionIsOffline {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi.slash")
                            Text("OFFLINE")
                        }
                        .font(Typography.micro.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.4))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Offline reply. Reconnect for a full read from your coach.")
                    }
                }
                ScrollView {
                    Text(caption)
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(captionIsOffline ? 0.72 : 0.92))
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
    // on a cold start, surfaced an "I have nothing yet" version. Priority:
    // an earned case-file focus first; else one DATA-GROUNDED line from the
    // most recent timed rep's delivery facts ("Last rep: 142 WPM, 3 fillers —
    // want to tighten that?"); else nothing — a true cold start shows no line
    // and lets "Tap Talk" carry the moment. Never fabricated.

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

    /// The single focus line for the live-call landing: an earned case-file
    /// focus when one exists, else one data-grounded line from the latest
    /// timed rep, else `nil` on a true cold start (no reps → no focus to
    /// name, so the landing stays "Tap Talk").
    private var coachingFocusLine: String? {
        if let caseFile = coachMemoryStore.currentMemory?.caseFile,
           let earned = bounded(caseFile.hypothesis)
               ?? caseFile.focus.map({ "Today's lever: \($0.displayName.lowercased())." })
               ?? bounded(caseFile.activeIntervention) {
            return earned
        }
        return lastRepLandingLine
    }

    /// Data-grounded landing fallback: the most recent TIMED rep's delivery
    /// facts (the same evidence source the chat's deterministic fallback
    /// reads — see `CoachReplyPipeline`), composed by the pure
    /// `CoachContextBuilder.liveCallLandingLine`. Nil when no timed rep with
    /// a measurable pace exists, so rep-0 fabricates nothing. Plain read,
    /// not observed — the landing renders before any exchange, and a rep
    /// cannot complete mid-call.
    private var lastRepLandingLine: String? {
        guard let rep = PracticeSessionStore.shared.sessions.last(where: { $0.mode == .timed }) else {
            return nil
        }
        let wpm = PracticeEvaluator.paceSnapshot(
            forTranscript: rep.transcript,
            duration: rep.duration
        ).wordsPerMinute
        return CoachContextBuilder.liveCallLandingLine(
            wordsPerMinute: wpm,
            fillerCount: rep.fillerWordCount
        )
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
        deadMicNotice = nil
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
        recordingArmedAt = Date()
    }

    private func endLoop() {
        loopActive = false
        voiceInput.cancelRecording()
        speaker.stop()
        recordingArmedAt = nil
    }

    /// End the turn after a natural pause (hands-free send), and watch for
    /// an armed-but-wordless mic (C5 — never a silent dead "Listening…").
    private func silenceTick() {
        deadMicTick()
        guard loopActive,
              voiceInput.state == .recording,
              !voiceInput.partialTranscript.isEmpty,
              Date().timeIntervalSince(lastPartialAt) > silenceThreshold
        else { return }
        voiceInput.stopAndSend()  // → onFinalTranscript → handleUtterance
    }

    /// C5 — dead-mic watchdog: recording with zero words for the whole
    /// patience window means nothing is reaching the recognizer. Say so and
    /// end the hands-free loop honestly; the user re-taps Talk to retry or
    /// drops to Type.
    private func deadMicTick() {
        guard let armedAt = recordingArmedAt,
              LiveCallMicWatchdog.shouldFlag(
                  loopActive: loopActive,
                  isRecording: voiceInput.state == .recording,
                  hasPartialTranscript: !voiceInput.partialTranscript.isEmpty,
                  secondsSinceArmed: Date().timeIntervalSince(armedAt)
              )
        else { return }
        deadMicNotice = LiveCallMicWatchdog.notice
        endLoop()
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
            let route = AskNoumSpokenMode.spokenRoute(
                outcome: outcome,
                spokenRepliesEnabled: voiceSettings.askNoumSpokenRepliesEnabled,
                localeSupportsAI: LocaleSettingsManager.shared.current.aiSupported
            )
            if route != .none, let spokenText = AskNoumSpokenMode.spokenText(for: outcome) {
                speaker.speak(
                    spokenText,
                    setup: IMConversationSetup(
                        scenario: .workUpdate,
                        targetTone: AskNoumSpokenMode.coachTone(for: voice)
                    ),
                    allowOnDeviceFallback: true,
                    onDeviceOnly: route == .onDeviceOnly
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
