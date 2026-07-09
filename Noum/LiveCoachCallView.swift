#if canImport(SwiftUI)
import SwiftUI
import os

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
// PUSH-TO-TALK: tap the mic to start a turn. You talk; a ~2.2s pause auto-sends
// your turn; the coach replies and speaks aloud. The mic does NOT re-arm itself —
// you tap Talk again for your next turn. (Auto re-arm was deliberately removed: it
// made the mic transcribe the coach's own TTS — an echo loop. See the push-to-talk
// notes at `engaged`/line ~200 and the watchdog above; do not reintroduce it.)
// Tapping while it's speaking barges in; tapping while listening ends the session.
// Mic stays off while the coach speaks so it never hears itself.
//
// Reuses: `AskNoumStore` (same thread the chat reads/writes), `AskNoumVoiceInput`
// (mic), `IMMessageSpeaker` (speak-aloud), `CoachReplyPipeline` (one brain with
// the chat). "Type" drops to the chat; "Leave" pops the surface.

@available(iOS 17.0, macOS 12.0, *)
struct LiveCoachCallView: View {
    private static let speechLog = Logger(subsystem: "com.jordancoaten.noum", category: "AskNoumSpeech")

    /// Defensive copy of the shared Ask Noum evidence gate. The container does
    /// not construct this view before rep one, but the live surface also checks
    /// at its microphone and dispatch boundaries so a stale SwiftUI action can
    /// never open the recognizer or append an unevidenced coach turn.
    let hasCompletedPracticeEvidence: Bool

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

    /// A call session is engaged (silence auto-SEND while recording stays;
    /// the mic re-opens only on an explicit Talk tap — push-to-talk, never
    /// auto re-arm, so the mic can't transcribe the coach's own TTS).
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
    /// UI harness only: seed the live caption once for deterministic caption
    /// rendering tests without faking microphone input.
    @State private var didSeedDebugCaption = false

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
        if speaker.isSpeaking { return .coaching }
        if store.isAwaitingReply { return .thinking }
        return .calm
    }

    // V4 — the owner wants a clean landing with no instructional copy; the
    // tappable orb + Talk control carry the affordance. So the idle pre-loop
    // state shows NO state line (returns nil and the row is omitted) rather
    // than "Tap Talk to begin". The unavailable case still speaks up — that's
    // an honest problem, not chrome.
    private var stateLine: String? {
        if !voiceInput.isAvailable { return "Use Type to write instead" }
        if !loopActive { return nil }
        if voiceInput.state == .recording { return "Listening — pause when you're done" }
        if speaker.isSpeaking { return "Speaking…" }
        if store.isAwaitingReply { return "Thinking…" }
        // Push-to-talk: mid-session idle is a real state now (the mic no
        // longer auto re-arms), so name the affordance instead of "…".
        return "Tap Talk to reply"
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
        if store.isAwaitingReply {
            guard let pending = store.messages.last(where: { $0.role == .coach && $0.isPending })?.text,
                  !pending.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return pending
        }
        guard hasLiveExchange || speaker.isSpeaking else { return nil }
        guard let text = store.messages.last(where: { $0.role == .coach && !$0.isPending })?.text else {
            return nil
        }
        return text
    }

    /// True when the latest coach turn being captioned is a legacy offline row.
    /// New live-call turns become system notices instead of local coach copy,
    /// but old saved rows still need honest caption styling.
    private var captionIsOffline: Bool {
        guard voiceInput.state != .recording else { return false }
        return store.messages.last(where: { $0.role == .coach && !$0.isPending })?.isOffline ?? false
    }

    private var captionSpeaker: String {
        voiceInput.state == .recording ? "YOU" : "NOUM"
    }

    /// The live call is a spoken-caption surface, not the rich text chat.
    /// User partials stay verbatim; coach turns get a final sanitizer pass
    /// immediately before visible rendering so old persisted rows, UI-test
    /// seeds, or renderer changes cannot leak prompt scaffolds like "Read:".
    private var visibleCaption: String? {
        guard let text = caption else { return nil }
        if voiceInput.state == .recording {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return Self.visibleCoachCaptionText(from: text)
    }

    nonisolated static func visibleCoachCaptionText(from raw: String) -> String? {
        let value = CoachReplyTextSanitizer.liveDisplayText(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    nonisolated static func liveCoachSpokenText(
        from raw: String,
        spokenRepliesEnabled: Bool,
        localeSupportsAI: Bool
    ) -> String? {
        let outcome = ChatOutcome.reply(raw)
        guard AskNoumSpokenMode.spokenRoute(
            outcome: outcome,
            spokenRepliesEnabled: spokenRepliesEnabled,
            localeSupportsAI: localeSupportsAI
        ) != .none else {
            return nil
        }
        return AskNoumSpokenMode.spokenText(for: outcome)
    }

    /// A live turn should not read the immediate verdict and then read a
    /// second fuller version over the top of it. The final model text still
    /// lands in the thread; this only chooses the audio surface.
    nonisolated static func shouldSpeakFinalCoachOutcome(
        provisionalSpeechStarted: Bool
    ) -> Bool {
        !provisionalSpeechStarted
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
        .onAppear {
            guard hasCompletedPracticeEvidence else {
                onSwitchToType()
                return
            }
            voiceInput.onFinalTranscript = { text in handleUtterance(text) }
            seedDebugCaptionIfNeeded()
        }
        .onDisappear { endLoop() }
        // Silence detection — ends the turn after a natural pause.
        .onReceive(tick) { _ in silenceTick() }
        .onChange(of: voiceInput.partialTranscript) { _, _ in lastPartialAt = Date() }
        // PUSH-TO-TALK: no auto re-arm after the coach finishes. The auto
        // loop re-opened the mic into the device speaker mid-/post-TTS and
        // transcribed the coach's own reply as the user's next turn — the
        // coach ended up answering its own echo. The mic now opens ONLY on
        // an explicit Talk tap (barge-in while the coach speaks still works).
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

    // V5 — the live bar carries call identity with a single quiet status pill.
    // The owner found the old trailing "with Noum" text awkward and floating;
    // it's dropped. The centered "Noum" under the orb and this LIVE/COACH pill
    // already name who you're talking to, so the bar stays clean and leading.
    private var liveBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill((loopActive ? Color.red : AppColor.pro).opacity(loopActive ? 0.9 : 0.65))
                .frame(width: 8, height: 8)
            Text(loopActive ? "LIVE" : "COACH")
                .font(Typography.micro.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(loopActive ? "Live call with Noum" : "Coach call with Noum")
    }

    // MARK: - Presence (the face)

    private var presence: some View {
        VStack(spacing: Spacing.md) {
            // V4 — the orb is the primary "press the circle to start talking"
            // affordance the owner asked for. Tapping it mirrors the Talk
            // button (micTapped) so a user can start hands-free without
            // hunting the control bar; the Talk button stays as the explicit
            // alternative. Disabled when speech input isn't available so it
            // never offers a dead tap.
            Button(action: micTapped) {
                NoumCharacter(mood: orbMood, tint: AppColor.pro, size: 136, stage: characterStage)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .disabled(!voiceInput.isAvailable)
            .accessibilityLabel(orbAccessibilityLabel)
            Text("Noum")
                .font(Typography.cardTitle)
                .foregroundStyle(.white)
            // V4 — idle landing shows no instructional line (stateLine == nil);
            // the orb + controls carry the moment. Only render when there's
            // something honest to say.
            if let stateLine {
                Text(stateLine)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: stateLine)
            }
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
    }

    /// V4 — VoiceOver affordance for the now-tappable orb. Names the action it
    /// performs in the current state so it isn't a mystery target.
    private var orbAccessibilityLabel: String {
        if !voiceInput.isAvailable { return "Noum. Voice unavailable — use Type instead." }
        if loopActive {
            if speaker.isSpeaking { return "Noum is speaking. Tap to interrupt and talk." }
            if voiceInput.state == .recording { return "Noum is listening. Tap to stop the call." }
            return "Noum. Tap to stop the call."
        }
        return "Noum. Tap to start talking."
    }

    // MARK: - Captions

    @ViewBuilder
    private var captionArea: some View {
        if let caption = visibleCaption {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(captionSpeaker)
                        .font(Typography.micro.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.4))
                    // Legacy offline rows are marked in the live caption too,
                    // so old local copy is never read as the live coach speaking.
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
                        .font(Typography.figtree(size: 17, weight: .medium, relativeTo: .body))
                        .foregroundStyle(.white.opacity(captionIsOffline ? 0.72 : 0.92))
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Compact by default so short coach turns don't sit inside a
                // giant empty panel; still scrolls for larger Dynamic Type or a
                // longer coach turn. VoiceOver gets the whole caption as one
                // grouped element, mirroring the chat bubble's "Noum: …" label.
                .frame(maxHeight: 148)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(captionIsOffline ? "Noum, offline reply: \(caption)" : "Noum: \(caption)")
                .accessibilityIdentifier("askNoum.live.caption")
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .padding(.top, Spacing.md)
            .transition(.opacity)
        }
    }

    // MARK: - Coaching focus line
    //
    // The live-call landing leads with the tappable orb (no instructional copy
    // — V4). We add at most ONE supporting focus line — never the old four-field
    // "COACHING READ" meta-brief (headline / current work / target / next move),
    // which made the user read a clinical case sheet before saying a word and,
    // on a cold start, surfaced an "I have nothing yet" version. Priority:
    // an earned case-file focus first; else one DATA-GROUNDED line from the
    // most recent timed rep's delivery facts ("Last rep: 142 WPM, 3 fillers —
    // want to tighten that?"); else nothing — a true cold start shows no line
    // and lets the orb carry the moment. Never fabricated.

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
        if let caseFile = coachMemoryStore.currentMemory?.caseFile {
            // Rank 2 — a standing prescribed plan anchors the landing as
            // continuity ("picking up where we left off"), the move a human
            // coach opens with. This is the *plan*; the *read* (hypothesis)
            // is surfaced in the spoken reply at the trust moment (Rank 1), so
            // the landing leads with the plan and only falls back to the
            // earned read / lever when no prescription is standing yet.
            if let anchor = bounded(caseFile.callLandingAnchor) {
                return anchor
            }
            if let earned = bounded(caseFile.hypothesis)
                ?? caseFile.focus.map({ "Today's lever: \($0.displayName.lowercased())." })
                ?? bounded(caseFile.activeIntervention) {
                return earned
            }
        }
        return lastRepLandingLine
    }

    /// Data-grounded landing fallback: the most recent TIMED rep's delivery
    /// facts, composed by the pure
    /// `CoachContextBuilder.liveCallLandingLine`. Nil when no timed rep with
    /// a measurable pace exists, so rep-0 fabricates nothing. Plain read,
    /// not observed — the landing renders before any exchange, and a rep
    /// cannot complete mid-call.
    private var lastRepLandingLine: String? {
        guard let rep = Self.latestTimedRepForLiveLanding(
            from: PracticeSessionStore.shared.sessions
        ) else {
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

    nonisolated static func latestTimedRepForLiveLanding(
        from sessions: [PracticeSession]
    ) -> PracticeSession? {
        sessions
            .filter { $0.mode == .timed }
            .max { $0.date < $1.date }
    }

    private func bounded(_ value: String?, maximumLength: Int = 96) -> String? {
        guard let raw = value,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let cleaned = CoachReplyTextSanitizer.liveLandingText(from: raw)
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= maximumLength { return trimmed }
        let clipped = String(trimmed.prefix(maximumLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clipped + "..."
    }

    private func seedDebugCaptionIfNeeded() {
        let launchArguments = ProcessInfo.processInfo.arguments
        guard !didSeedDebugCaption,
              launchArguments.contains("UI_TESTING"),
              launchArguments.contains("UI_TESTING_LIVE_FORCE_MARKDOWN_CAPTION")
                || launchArguments.contains("UI_TESTING_LIVE_FORCE_PLAIN_SCAFFOLD_CAPTION")
        else { return }
        didSeedDebugCaption = true
        hasLiveExchange = true
        if launchArguments.contains("UI_TESTING_LIVE_FORCE_PLAIN_SCAFFOLD_CAPTION") {
            _ = store.injectCoachTurn("""
            Read: You want it straight.

            Move: Give one 30-second update, state the recommendation first, then stop.
            """)
        } else {
            _ = store.injectCoachTurn("""
            **Read:** You want it straight. Your baseline says fillers rise near the close.

            **Move:** Give one 30-second update, state the recommendation first, then stop.
            """)
        }
    }

    // MARK: - Control bar (Zoom-style)

    private var controlBar: some View {
        // The user "has the floor" when the hands-free loop is live and the mic
        // is actively recording — that's the moment the primary button must read
        // as "Send" (submit the captured turn), never "Stop" (which users misread
        // as cancel and lost their utterance). Otherwise it's the Talk affordance.
        let onFloor = loopActive && voiceInput.state == .recording
        return HStack(spacing: Spacing.lg) {
            callButton(
                glyph: onFloor ? "arrow.up.circle.fill" : "mic.fill",
                label: onFloor ? "Send" : "Talk",
                fill: onFloor ? AppColor.pro : Color.white.opacity(0.12),
                ring: voiceInput.state == .recording,
                disabled: !voiceInput.isAvailable,
                accessibilityLabel: onFloor ? "Send to coach" : "Talk to coach"
            ) { micTapped() }

            // V1 — this control mutes/unmutes the coach's spoken replies, so it
            // reads as "Mute" (not the vague "Aloud"). Glyph + label flip with
            // the actual state: speaker.wave when voice is ON (tap to Mute),
            // speaker.slash when already muted (label "Muted"). a11y label spells
            // out the *action* the tap performs so VoiceOver users aren't guessing.
            callButton(
                glyph: voiceSettings.askNoumSpokenRepliesEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                label: voiceSettings.askNoumSpokenRepliesEnabled ? "Mute" : "Muted",
                fill: Color.white.opacity(0.12),
                tint: voiceSettings.askNoumSpokenRepliesEnabled ? AppColor.positive : .white,
                accessibilityLabel: voiceSettings.askNoumSpokenRepliesEnabled
                    ? "Mute coach voice"
                    : "Unmute coach voice"
            ) { toggleAloud() }

            callButton(glyph: "keyboard", label: "Type", fill: Color.white.opacity(0.12)) {
                endLoop(); onSwitchToType()
            }

            // V6 — Leave is de-emphasized so it never reads as the "proceed /
            // get my response" button. The owner watched users tap a bright-red
            // Leave to advance and end the call before the reply landed. The
            // turn already completes regardless of Leave (handleUtterance runs
            // a detached Task into the shared store and re-arms on its own), so
            // the real fix is clarity: a quiet ghost treatment keeps the active
            // Talk/Send control visually primary and signals "exit", not "next".
            callButton(
                glyph: "xmark",
                label: "Leave",
                fill: Color.white.opacity(0.12),
                tint: Color.red.opacity(0.85),
                accessibilityLabel: "Leave the call"
            ) {
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
        accessibilityLabel: String? = nil,
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
        .accessibilityLabel(accessibilityLabel ?? label)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Hands-free loop

    private func micTapped() {
        guard hasCompletedPracticeEvidence else {
            endLoop()
            onSwitchToType()
            return
        }
        deadMicNotice = nil
        if loopActive {
            if speaker.isSpeaking {
                store.markLatestCoachTurnVoiceBargeIn()
                speaker.stop()        // barge-in: cut the coach off
                startRecording()      // and take the floor
            } else if voiceInput.state == .recording {
                // Primary button SENDS the captured turn (same path as the
                // hands-free silence send), instead of cancelling it. Users
                // read the old "Stop" as "discard" and lost their utterance.
                voiceInput.stopAndSend()  // → onFinalTranscript → handleUtterance
            } else {
                // Push-to-talk: idle mic + Talk tap = take the floor again.
                // (Under the old auto re-arm loop an idle tap meant "end the
                // session"; ending the call now belongs to Leave alone.)
                startRecording()
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

    @MainActor
    @discardableResult
    private func speakLiveCoachReplyText(
        _ rawText: String,
        source: String,
        setup: IMConversationSetup,
        onDeviceOnly: Bool = false
    ) -> Bool {
        guard loopActive else { return false }
        guard let spokenText = Self.liveCoachSpokenText(
            from: rawText,
            spokenRepliesEnabled: voiceSettings.askNoumSpokenRepliesEnabled,
            localeSupportsAI: LocaleSettingsManager.shared.current.aiSupported
        ) else {
            Self.speechLog.debug("live coach speech skipped route=none")
            return false
        }
        Self.speechLog.info("live coach \(source, privacy: .public) speech starting chars=\(spokenText.count, privacy: .public)")
        speaker.speak(
            spokenText,
            setup: setup,
            allowOnDeviceFallback: true,
            onDeviceOnly: onDeviceOnly
        )
        return true
    }

    private func handleUtterance(_ text: String) {
        guard hasCompletedPracticeEvidence else {
            endLoop()
            onSwitchToType()
            return
        }
        // Single-in-flight: a turn already awaiting a reply must not be
        // superseded by a second dispatch (barge-in / Talk / late silence
        // send all route here). Without this, two pending rows + two
        // CoachReplyPipeline runs race and completeCoachTurn clears
        // isAwaitingReply when EITHER lands, leaving the other stuck.
        guard !store.isAwaitingReply else { return }
        hasLiveExchange = true
        let ids = store.appendUserTurn(text)
        Task {
            let speechSetup = IMConversationSetup(
                scenario: .workUpdate,
                targetTone: AskNoumSpokenMode.coachTone(for: voice)
            )
            var provisionalSpeechStarted = false
            // The pipeline hydrates the thread row regardless — that must
            // always happen so the reply is there when the user returns to
            // Type mode. But SPEAKING is gated on the call still being live:
            // the reply resolves 1-3s later on the IMMessageSpeaker.shared
            // singleton, so without this guard the coach's voice plays on
            // whatever screen the user moved to after Leave/Type. Same
            // TTS-when-it-must-not class the auto-rearm removal closed.
            let outcome = await CoachReplyPipeline.generate(
                coachID: ids.coachID,
                surface: .live,
                onProvisionalCoachReadVisible: { provisionalRead in
                    provisionalSpeechStarted = speakLiveCoachReplyText(
                        provisionalRead,
                        source: "immediate-read",
                        setup: speechSetup,
                        onDeviceOnly: true
                    )
                }
            )
            guard loopActive else { return }
            guard Self.shouldSpeakFinalCoachOutcome(
                provisionalSpeechStarted: provisionalSpeechStarted
            ) else {
                Self.speechLog.debug("live coach final speech skipped after immediate read")
                return
            }
            let route = AskNoumSpokenMode.spokenRoute(
                outcome: outcome,
                spokenRepliesEnabled: voiceSettings.askNoumSpokenRepliesEnabled,
                localeSupportsAI: LocaleSettingsManager.shared.current.aiSupported
            )
            guard route != .none else {
                Self.speechLog.debug("live coach speech skipped route=none")
                return
            }
            guard let spokenText = AskNoumSpokenMode.spokenText(for: outcome) else {
                Self.speechLog.notice("live coach speech skipped after sanitizer emptied reply")
                return
            }
            Self.speechLog.info("live coach final speech starting chars=\(spokenText.count, privacy: .public)")
            speaker.speak(
                spokenText,
                setup: speechSetup,
                allowOnDeviceFallback: true,
                onDeviceOnly: false
            )
        }
    }

    private func toggleAloud() {
        voiceSettings.askNoumSpokenRepliesEnabled.toggle()
        if !voiceSettings.askNoumSpokenRepliesEnabled { speaker.stop() }
    }
}

#endif
