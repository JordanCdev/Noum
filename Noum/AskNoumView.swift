#if canImport(SwiftUI)
import SwiftUI

// MARK: - Ask Noum view
//
// The chat surface for the user's persistent coaching thread. Reads from
// `AskNoumStore` for the message log and `AICoachChatService` for the
// actual model calls. System prompt + user context block are produced
// by `CoachContextBuilder` at send-time.
//
// Layout (top to bottom):
//   • Header: NoumCharacter (voice-tinted orb) + the coach's name. The orb
//     REACTS to the thread (`orbMood`) — `.thinking` while a reply is
//     composing/writing, `.coaching` once a conversation exists, a `.calm`
//     greeting at the empty state. Existing threads open compact by default;
//     first contact gets the fuller identity moment.
//   • Current focus strip: visible only when the thread has messages and the
//     case file has an active target/focus.
//   • Empty state (no messages): one recommended ask, with alternatives tucked
//     into a menu. Removes first-message friction without a prompt tray.
//   • Thread: alternating user (right-aligned brand-blue bubble) +
//     coach (left-aligned full-width card) rows. The coach card carries
//     NO per-bubble glyph (S4 removed the repeated orb the user flagged
//     as noise) — left-alignment + the brand-purple stroke read as the
//     coach, and the header carries embodiment. The in-flight bubble
//     keeps a `.thinking` orb as its typing indicator, the one place the
//     orb earns its keep. A just-landed reply then REVEALS word by word
//     (the coach reads as writing to you, not popping in fully formed) —
//     view-only timing, the store still holds the full text, and
//     reduce-motion lands it instantly.
//   • Continuation: a single "Next move" panel when a drill/choice/follow-up
//     is earned; generic replies stay quiet.
//   • Input bar: rounded text field + ONE 44pt trailing control that swaps
//     glyph by draft state — mic when empty, arrow.up when there's text,
//     stop.fill while recording. Disabled while a reply is in flight; falls
//     back to send-only when voice can't be served.
//
// Brand alignment: white cards on light background, brand-purple accents
// for the coach surface, NoumCharacter as the coach's embodiment.

// Reports the thread ScrollView's top offset so the header can collapse
// as the user scrolls into the conversation. Same shape as
// `HomeScrollOffsetKey` (ContentView.swift) — a zero-height probe at the
// top of the scroll content publishes its `minY` in the named coordinate
// space, and the view derives a compact flag from it. Kept private + file
// scoped so it never collides with the home key.
@available(iOS 17.0, macOS 12.0, *)
private struct AskNoumScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Coach message formatting

enum CoachMessageTextFormatter {
    struct InlineSegment: Equatable {
        let text: String
        let isStrong: Bool
    }

    enum Block: Equatable {
        case paragraph(String)
        case bullet(String)
        case numbered(Int, String)
    }

    static func blocks(from text: String) -> [Block] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { raw -> Block? in
                let trimmed = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                if let bullet = bulletText(from: trimmed) {
                    return .bullet(bullet)
                }
                if let numbered = numberedText(from: trimmed) {
                    return .numbered(numbered.index, numbered.text)
                }
                return .paragraph(strippedHeadingPrefix(from: trimmed))
            }
    }

    static func inlineSegments(from text: String) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        var buffer = ""
        var isStrong = false
        var index = text.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            segments.append(InlineSegment(text: buffer, isStrong: isStrong))
            buffer = ""
        }

        while index < text.endIndex {
            let next = text.index(after: index)
            if next < text.endIndex,
               text[index] == "*",
               text[next] == "*" {
                flush()
                isStrong.toggle()
                index = text.index(after: next)
            } else {
                buffer.append(text[index])
                index = next
            }
        }
        flush()
        return segments.isEmpty ? [InlineSegment(text: text, isStrong: false)] : segments
    }

    private static func bulletText(from trimmed: String) -> String? {
        for marker in ["- ", "* ", "• "] where trimmed.hasPrefix(marker) {
            let value = String(trimmed.dropFirst(marker.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func numberedText(from trimmed: String) -> (index: Int, text: String)? {
        guard let separator = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) else {
            return nil
        }
        let prefix = trimmed[..<separator]
        guard !prefix.isEmpty,
              prefix.allSatisfy({ $0.isNumber }),
              let index = Int(prefix),
              index > 0 else {
            return nil
        }
        let afterSeparator = trimmed.index(after: separator)
        guard afterSeparator < trimmed.endIndex,
              trimmed[afterSeparator].isWhitespace else {
            return nil
        }
        let value = String(trimmed[afterSeparator...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : (index, value)
    }

    private static func strippedHeadingPrefix(from trimmed: String) -> String {
        var value = trimmed
        while value.first == "#" {
            value.removeFirst()
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@available(iOS 17.0, macOS 12.0, *)
private struct CoachFormattedMessageText: View {
    let text: String
    let textColor: Color
    let accent: Color

    private var blocks: [CoachMessageTextFormatter.Block] {
        CoachMessageTextFormatter.blocks(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: CoachMessageTextFormatter.Block) -> some View {
        switch block {
        case .paragraph(let value):
            inlineText(value)
                .foregroundStyle(textColor)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let value):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("•")
                    .font(Typography.figtree(size: 18, weight: .bold, relativeTo: .body))
                    .foregroundStyle(accent)
                    .frame(width: 12, alignment: .center)
                inlineText(value)
                    .foregroundStyle(textColor)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .numbered(let index, let value):
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("\(index).")
                    .font(Typography.monoDigit(Typography.figtree(size: 17, weight: .bold, relativeTo: .body)))
                    .foregroundStyle(accent)
                    .frame(width: 22, alignment: .trailing)
                inlineText(value)
                    .foregroundStyle(textColor)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func inlineText(_ raw: String) -> Text {
        CoachMessageTextFormatter.inlineSegments(from: raw).reduce(Text("")) { partial, segment in
            partial + Text(segment.text)
                .font(
                    segment.isStrong
                    ? Typography.figtree(size: 17, weight: .bold, relativeTo: .body)
                    : Typography.figtree(size: 17, weight: .medium, relativeTo: .body)
                )
        }
    }
}

// MARK: - Spoken-coach-mode pure logic (S5, routes since C5)
//
// The decision of WHETHER (and through WHICH engines) to speak a
// freshly-landed coach turn is isolated here as pure, view-free logic so it
// can be unit-tested without standing up the SwiftUI view, an audio engine,
// or a model. `AskNoumView.runReply` and the live call's `handleUtterance`
// call `spokenRoute(...)` at the single chokepoint where a reply becomes
// visible (`store.completeCoachTurn`), and only then drive
// `IMMessageSpeaker.shared.speak(...)`.
//
// The voice → tone mapping translates the user's CHOSEN `SpeakingStyleGoal`
// into the `IMTargetTone` the TTS layer reads for voice selection, so the
// coach's spoken register leans toward the voice the user is training. A nil
// chosen voice (the user hasn't picked) maps to a steady, neutral `.calm`
// coach voice — never an invented register.
@available(iOS 17.0, macOS 12.0, *)
enum AskNoumSpokenMode {

    /// How a landed coach turn reaches the user's ears, if at all.
    enum SpokenRoute: Equatable {
        /// Live `.reply`: full engine chain — cloud TTS first, on-device
        /// system voice as the terminal fallback so a TTS outage degrades
        /// to an audible reply instead of a silent bubble.
        case fullChain
        /// `.deterministicReply`: ON-DEVICE system voice ONLY. The grounded
        /// offline line usually lands exactly when the network/provider is
        /// down (so cloud TTS is moot), and honesty is preserved because
        /// the system voice is audibly NOT the cloud coach voice — a canned
        /// line is never passed off as the live coach speaking.
        case onDeviceOnly
        /// Stay silent (toggle off, unsupported locale, failure, empty).
        case none
    }

    /// The single source of truth for "how should this landed outcome be
    /// spoken?".
    ///
    /// Non-`.none` ONLY when ALL hold:
    ///   • the voice-mode toggle is ON (`spokenRepliesEnabled`),
    ///   • the active locale supports AI (`localeSupportsAI`) — non-English
    ///     users stay clean text-only, matching the chat-reply locale gate,
    ///   • the outcome carries non-empty trimmed coach text.
    ///
    /// A `.failure` (any cause) is NEVER spoken — a system-notice row is a
    /// UI affordance, not the coach's voice, so reading "I couldn't reach my
    /// model" aloud would be worse than silence. An all-whitespace reply is
    /// also rejected (defensive; the store routes that to `.failure(.empty)`
    /// anyway, but the predicate must not depend on that downstream
    /// behavior).
    static func spokenRoute(
        outcome: ChatOutcome,
        spokenRepliesEnabled: Bool,
        localeSupportsAI: Bool
    ) -> SpokenRoute {
        guard spokenRepliesEnabled, localeSupportsAI else { return .none }
        switch outcome {
        case .reply(let text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .none : .fullChain
        case .deterministicReply(let text, _):
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .none : .onDeviceOnly
        case .failure:
            return .none
        }
    }

    /// The coach text a non-`.none` route speaks. Nil for `.failure` and
    /// empty outcomes — total, so callers can `if let` without re-deriving
    /// the route's preconditions.
    static func spokenText(for outcome: ChatOutcome) -> String? {
        switch outcome {
        case .reply(let text), .deterministicReply(let text, _):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .failure:
            return nil
        }
    }

    /// Map the user's chosen training voice to the spoken coach tone. Pure +
    /// total so it is trivially testable and never crashes on a new case.
    static func coachTone(for voice: SpeakingStyleGoal?) -> IMTargetTone {
        switch voice {
        case .authoritative: return .confident
        case .warm: return .warm
        case .concise: return .concise
        case .persuasive: return .assertive
        case .executive: return .professional
        case .storytelling: return .warm
        case nil: return .calm
        }
    }
}

// MARK: - Day-0 seeded coach presence (coach-parity eval move 2)
//
// Before the first completed rep the coach has a stated goal (the
// CoachingProfile from onboarding) but ZERO evidence. The old behavior
// locked the thread door until rep 1 — the coach couldn't be talked to
// exactly when a first-timer was deciding whether to trust the product.
// This opens the door with an honest seeded presence instead of a fake
// conversation:
//
//   • The greeting is a PURE deterministic template from enum-derived
//     profile fields — no LLM call, no fabricated read, and never a
//     verbatim quote of user-typed text (lock-screen-safety rule).
//   • The composer is replaced by a "run your first rep" CTA + a plain
//     one-line reason. Full coach replies stay gated on rep 1 because
//     a reply with zero reps would be a guess wearing a coach voice.
//
// Pure + view-free so the gate and the template are unit-testable.
@available(iOS 17.0, macOS 12.0, *)
enum AskNoumDayZeroGreeting {

    /// True before the user's FIRST completed rep — the window where the
    /// thread is seeded/read-only.
    static func isActive(sessionCount: Int) -> Bool {
        sessionCount < 1
    }

    /// Deterministic seeded greeting. Acknowledges the stated challenge
    /// and/or chosen voice using enum-derived copy only, states plainly
    /// that there is no read yet (weak evidence → soft language), and
    /// invites ONE rep for a real read. Total — every input combination
    /// returns a non-empty, non-overclaiming line.
    static func greeting(
        challenge: SpeakingChallenge?,
        voice: SpeakingStyleGoal?
    ) -> String {
        let evidenceInvite = "No read yet. One short rep gives me evidence; then I can name the first lever worth training."
        let acknowledgement: String?
        switch (challenge, voice) {
        case let (challenge?, voice?):
            acknowledgement = "You want to work on \(challenge.trainingFocusFragment) and to \(voice.coachingDescription)."
        case let (challenge?, nil):
            acknowledgement = "You want to work on \(challenge.trainingFocusFragment)."
        case let (nil, voice?):
            acknowledgement = "You want to \(voice.coachingDescription)."
        case (nil, nil):
            acknowledgement = nil
        }
        guard let acknowledgement else { return evidenceInvite }
        return acknowledgement + " " + evidenceInvite
    }

    /// Headline over the seeded greeting card.
    static let headline = "Before rep one"

    /// Title for the first-rep CTA that stands in for the composer.
    static let firstRepCTATitle = "Run your first rep"

    /// One-line honest reason the composer is not there yet. Plain
    /// statement, no countdown, no shame.
    static let inputLockedNote = "The thread opens after one rep, so the coaching starts from evidence."
}

@available(iOS 17.0, macOS 12.0, *)
struct AskNoumView: View {
    @StateObject private var store = AskNoumStore.shared
    @ObservedObject var sessionStore: PracticeSessionStore
    @ObservedObject var ratingStore: RatingStore
    @ObservedObject var coachingProfileStore: CoachingProfileStore
    /// A3: lets a coach reply that names a concrete mode/exercise surface a
    /// tappable launch card that pushes the matching practice destination onto
    /// the shared stack (same routing Home/Summary use).
    @Binding var navigationPath: NavigationPath
    /// When set, the chat options menu can start the live coach call. Kept out
    /// of the visible header row so it reads as an action, not a false "live"
    /// status.
    var onGoLive: (() -> Void)? = nil
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var bigMomentStore = BigMomentStore.shared
    @StateObject private var forwardPlanStore = ForwardPlanStore.shared
    @StateObject private var postRepCoachNoteStore = PostRepCoachNoteStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared

    @State private var draft: String = ""
    @State private var didLandFirstAppear = false
    @FocusState private var inputFocused: Bool

    // S3 — the in-chat goal set/change intent detected on the most-recent user
    // turn (`CoachContextBuilder.detectGoalIntent`, set in `send(_:)`). Drives
    // the ephemeral `goalProposalRow` confirmation card and injects a GOAL
    // context line into the next reply so the coach PROPOSES rather than
    // assumes. Held as view state (not derived from the message log) so it
    // survives view rebuilds and is cleared on commit/decline — the card
    // collapses when this returns to nil. The model NEVER writes to the
    // profile; only a tap on this card's chip commits.
    @State private var pendingGoalIntent: CoachContextBuilder.GoalIntent?

    // S4 — live top offset of the thread ScrollView, published by the
    // zero-height probe inside it (`AskNoumScrollOffsetKey`). Drives the
    // collapsing header so the ~25% pinned intro block shrinks the moment
    // the user scrolls into the conversation. Resting value is 0 (top);
    // it goes negative as content scrolls up.
    @State private var scrollOffset: CGFloat = 0

    // Living-coach-presence (Pillar A) — progressive reply reveal. The store
    // holds the full reply text (source of truth); the view reveals it word by
    // word so the coach reads as *writing to you* rather than the reply popping
    // in fully-formed. `revealingMessageID` marks the one coach row currently
    // animating; `revealedText` is its visible prefix. Both reset when the
    // reveal completes (the bubble falls back to the full `message.text`).
    // Fully gated on reduce-motion — when it's on, no reveal is armed and
    // replies land instantly. `revealTask` is cancelled on a new turn and on
    // disappear so a superseded reveal never mutates state for the wrong row.
    @State private var revealingMessageID: UUID? = nil
    @State private var revealedText: String = ""
    @State private var revealTask: Task<Void, Never>? = nil

    // Voice input wrapper — shipped in `AskNoumVoiceInput.swift`. Single
    // instance per view so the tap-to-toggle lifecycle owns the audio
    // engine + recognition task. Tap once → start recording; tap again
    // → stop and send. The view reads `state` + `unavailableReason` to
    // drive UI, and calls `toggle()` from the button action.
    @StateObject private var voiceInput = AskNoumVoiceInput()

    // S5 — spoken coach mode. `speaker` drives the "coach is speaking" state
    // (its `isSpeaking` is the real AVAudioPlayer lifecycle, never a timer) and
    // exposes `canSpeakReplies` so the toggle hides when no TTS provider is
    // configured. `voiceSettings` owns the persisted, default-OFF toggle
    // (`askNoumSpokenRepliesEnabled`) on the existing playback-settings owner —
    // no new store. Both are shared singletons, observed so the speaking-state
    // UI + toggle re-render on change.
    @StateObject private var speaker = IMMessageSpeaker.shared
    @StateObject private var voiceSettings = IMVoicePlaybackSettingsManager.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        sessionStore: PracticeSessionStore,
        ratingStore: RatingStore,
        coachingProfileStore: CoachingProfileStore,
        navigationPath: Binding<NavigationPath>,
        onGoLive: (() -> Void)? = nil,
        startsInTextMode: Bool = false
    ) {
        self.sessionStore = sessionStore
        self.ratingStore = ratingStore
        self.coachingProfileStore = coachingProfileStore
        self._navigationPath = navigationPath
        self.onGoLive = onGoLive
        _ = startsInTextMode
    }

    private var voice: SpeakingStyleGoal? {
        // The CHOSEN voice, not the always-populated effective default — so the
        // header/persona stay generic ("Your speaking coach.") until the user
        // actually picks a voice, and the coach offers to set one instead of
        // inventing "authoritative."
        coachingProfileStore.profile?.chosenStyleGoal
    }

    /// True before the first completed rep — the seeded/read-only window.
    /// While active the empty state shows the deterministic day-0 greeting
    /// and the composer is replaced by a first-rep CTA (full replies stay
    /// gated on rep 1; see `AskNoumDayZeroGreeting`).
    private var isDayZero: Bool {
        AskNoumDayZeroGreeting.isActive(sessionCount: sessionStore.sessions.count)
    }

    /// True once the thread has scrolled up past a small threshold. Collapses
    /// the header to a compact bar (small orb + name, no subtitle) so the
    /// conversation gets the screen back. The 24pt deadband keeps the header
    /// from twitching on tiny rubber-band offsets at rest. Only meaningful
    /// when there are messages to scroll — the empty state never scrolls far
    /// enough to trip it, so the full header greets a first-time user.
    private var isHeaderCompact: Bool {
        !store.messages.isEmpty || scrollOffset < -24
    }

    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
    }

    /// Conversational mood for the header presence. Reacts to the thread so the
    /// orb reads as a coach who is *with you*: `.thinking` while a reply is
    /// composing OR writing (the progressive reveal), settling to `.coaching`
    /// (the warmer, leaning-in read) once a conversation exists, and a gentle
    /// `.calm` greeting before the first message. Pure read — no state, same
    /// shape as `isHeaderCompact`.
    private var orbMood: NoumCharacter.Mood {
        if store.isAwaitingReply || revealingMessageID != nil { return .thinking }
        return store.messages.isEmpty ? .calm : .coaching
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                currentFocusStrip
                ScrollViewReader { proxy in
                    ScrollView {
                        // Zero-height offset probe — publishes the scroll
                        // position so the header can collapse. Placed as the
                        // ScrollView's first child (before the padded content
                        // VStack) so its resting `minY` is 0, exactly the home
                        // screen's probe placement (ContentView.swift).
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: AskNoumScrollOffsetKey.self,
                                    value: geo.frame(in: .named("askNoumScroll")).minY
                                )
                        }
                        .frame(height: 0)

                        VStack(spacing: Spacing.md) {
                            if store.messages.isEmpty {
                                emptyState
                            } else {
                                ForEach(store.messages) { message in
                                    messageRow(message: message)
                                        .id(message.id)
                                }
                                // ONE continuation surface per turn — the
                                // arbiter (`CoachContextBuilder.continuationSurface`)
                                // picks the single surface this reply earned:
                                // a pending decision (goal commit / hypothesis
                                // verdict / revised-read verdict) outranks the
                                // "Next move" panel, which itself collapses
                                // drill + follow-up chips into one primary
                                // action. Never two calls-to-action stacked
                                // under one coach reply.
                                switch activeContinuationSurface {
                                case .goalProposal:
                                    goalProposalRow
                                        .id("goalProposal")
                                case .hypothesisAcknowledgement:
                                    hypothesisAckRow
                                        .id("hypothesisAck")
                                case .revisedReadFollowUp:
                                    revisedReadFollowUpRow
                                        .id("revisedReadFollowUp")
                                case .nextMove:
                                    coachNextMovePanel(
                                        destination: suggestedModeDestination,
                                        chips: followUpChips ?? []
                                    )
                                    .id("coachNextMove")
                                case nil:
                                    EmptyView()
                                }

                                // End chat — the deliberate session exit,
                                // at the BOTTOM of the thread (owner
                                // refinement on T2: "like end chat which
                                // takes you home, and shouldn't be at the
                                // top"). Same register as the live call's
                                // Leave and the verdict's bottom Done.
                                endChatRow
                            }
                            // Bottom spacer keeps the last message off
                            // the input bar so it's never visually cramped.
                            Color.clear.frame(height: Spacing.lg)
                                .id("bottom")
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.md)
                    }
                    .coordinateSpace(name: "askNoumScroll")
                    .scrollDismissesKeyboard(.interactively)
                    .onPreferenceChange(AskNoumScrollOffsetKey.self) { value in
                        scrollOffset = value
                    }
                    .onChange(of: store.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: store.isAwaitingReply) { _, awaiting in
                        scrollToBottom(proxy: proxy)
                        if awaiting {
                            // A reply just went in-flight. Pre-arm the reveal on
                            // the pending coach row NOW (on main) so the instant
                            // it lands it renders an empty prefix and writes out
                            // — never a one-frame flash of the full text. Cancel
                            // any superseded reveal first. Skipped under
                            // reduce-motion (no reveal is ever armed).
                            revealTask?.cancel()
                            if !reduceMotion,
                               let pendingID = store.messages.last(where: { $0.role == .coach })?.id {
                                revealingMessageID = pendingID
                                revealedText = ""
                            } else {
                                revealingMessageID = nil
                                revealedText = ""
                            }
                        } else {
                            // The reply hydrated — fire the AI chip request for
                            // the freshly landed coach message (idempotent;
                            // cache-deduped).
                            if let coachID = latestLandedCoachID {
                                requestAIChipsIfNeeded(for: coachID)
                            }
                            // Reveal the landed reply word by word. Normally the
                            // row was pre-armed above; the cross-surface inject
                            // path (Summary bridge) sets isAwaitingReply before
                            // this view observes it, so fall back to the latest
                            // landed coach id. Only reveal a REAL coach bubble —
                            // a `.failure` becomes a systemNotice, so don't
                            // re-reveal an older message.
                            let revealID = revealingMessageID ?? latestLandedCoachID
                            if !reduceMotion,
                               let id = revealID,
                               let landed = store.messages.first(where: { $0.id == id }),
                               landed.role == .coach, !landed.isPending, !landed.text.isEmpty {
                                startReveal(of: landed, proxy: proxy)
                            } else {
                                revealingMessageID = nil
                                revealedText = ""
                            }
                        }
                    }
                    .onAppear {
                        if !didLandFirstAppear {
                            didLandFirstAppear = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                scrollToBottom(proxy: proxy)
                            }
                            // If the thread was rehydrated from disk with
                            // a landed coach reply at the tail, request
                            // AI chips for it once — same behavior as a
                            // fresh reply that just hydrated.
                            if let coachID = latestLandedCoachID {
                                requestAIChipsIfNeeded(for: coachID)
                            }
                        }
                    }
                }
                if isDayZero {
                    // Day-0: the composer is honestly absent, not greyed.
                    // One CTA toward the rep that earns the first real
                    // reply, with the reason in plain words above it.
                    dayZeroFooter
                } else {
                    inputArea
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // T2 (owner refinement): the deliberate exit is the bottom-of-thread
        // "End chat" row (`endChatRow`), not a top-bar control — "shouldn't
        // be at the top." The standard back chevron stays for plain
        // navigation; End chat is the session-ending action that returns
        // straight Home.
        .onAppear {
            // T3 — owner: "clicking stop on voice dictation auto-inserts the
            // message into chat to upload again; it should auto-send on stop."
            // The final transcript now dispatches the user turn directly
            // through the single `send(_:)` funnel (same path as typed text,
            // chips, and the live call's `handleUtterance`) so stopping
            // dictation immediately runs the reply pipeline — no second tap on
            // the composer. `send(_:)` keeps the day-0 gate, goal-intent
            // detection, and barge-in stop, so auto-send inherits every
            // invariant the explicit path had.
            voiceInput.onFinalTranscript = { transcript in
                let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                // Clear any half-typed draft so the dictated turn doesn't leave
                // stale text in the composer after it sends.
                draft = ""
                inputFocused = false
                send(trimmed)
            }
            // Pick up any cross-surface inject (e.g. Summary's "Talk to
            // your coach about this rep" bridge dropped a seed message
            // into the store right before pushing us onto the nav
            // stack). The store hands back the matching coachID once
            // and clears its own signal — so re-mounts of this view
            // won't fire a second reply for the same opener.
            if let coachID = store.consumePendingInjectedCoachID() {
                Task { await runReply(coachID: coachID) }
            }
        }
        .onDisappear {
            // S5 — barge-in/teardown: never let the coach's voice bleed across
            // a navigation pop. Mirrors `SuddenDeathPracticeView.stopPromptReadout`
            // calling `IMMessageSpeaker.shared.stop()` on `.onDisappear`. Cheap
            // no-op when nothing is playing.
            speaker.stop()
            // Backing out mid-dictation must release the mic. Without this the
            // AVAudioEngine keeps running, the cloud (Deepgram) websocket keeps
            // streaming (billable), the audio session stays held in
            // playAndRecord+duckOthers, and InteractionSoundEngine.recordingActive
            // stays true — every tap/selection sound app-wide silenced until the
            // 30s max-duration timer finally fires. Cheap no-op when idle.
            voiceInput.cancelRecording()
            // Never let a half-written reveal mutate state after we've left.
            revealTask?.cancel()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: isHeaderCompact ? Spacing.sm : Spacing.md) {
            NoumCharacter(
                // Living-coach-presence: the orb REACTS to the thread via
                // `orbMood` — `.thinking` while composing/writing a reply,
                // `.coaching` (warmer, leaning-in) once a conversation
                // exists, a gentle `.calm` greeting before the first
                // message. It shrinks on scroll but never disappears, so the
                // coach stays a present, reacting embodiment even compact.
                mood: orbMood,
                tint: AppColor.pro,
                size: isHeaderCompact ? 34 : 56,
                stage: characterStage
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("Noum")
                    // Hardcoded 22pt swapped for the shared type scale:
                    // cardTitle (20) at rest, headline (18) when compact.
                    .font(isHeaderCompact ? Typography.headline : Typography.cardTitle)
                if !isHeaderCompact {
                    Text(headerSubtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: Spacing.sm)
            threadOptionsMenu
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isHeaderCompact)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
        // T1 — the header no longer reads as a closed box. The old opaque
        // `cardBackground.opacity(0.5)` bar + hard Divider fenced the coach
        // off from the thread; now the header sits directly on
        // `screenBackground` so the orb + name flow continuously into the
        // conversation below. No hardcoded opacity — the screen background
        // token carries the surface.
        .background(AppColor.screenBackground)
    }

    @ViewBuilder
    private var currentFocusStrip: some View {
        if !store.messages.isEmpty, let line = activeCaseSubtitle {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(AppColor.pro.opacity(0.85))
                Text(line)
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 6)
            .background(AppColor.cardBackground.opacity(0.35))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current focus: \(line)")
            .accessibilityIdentifier("askNoum.currentFocus")
        }
    }

    // MARK: - Thread options
    //
    // One compact menu owns secondary chat actions. This keeps the coach header
    // focused on presence ("Noum") instead of exposing implementation toggles:
    // live-call launch, spoken-reply preference, and clear-thread all live here.
    @ViewBuilder
    private var threadOptionsMenu: some View {
        if shouldShowThreadOptions {
            Menu {
                if let onGoLive {
                    Button(action: onGoLive) {
                        Label("Start coach call", systemImage: "phone.waveform")
                    }
                }
                if speaker.canSpeakReplies {
                    Button {
                        toggleSpokenReplies()
                    } label: {
                        Label(
                            voiceSettings.askNoumSpokenRepliesEnabled
                            ? "Spoken replies on"
                            : "Spoken replies off",
                            systemImage: voiceSettings.askNoumSpokenRepliesEnabled
                            ? "speaker.wave.2.fill"
                            : "speaker.slash.fill"
                        )
                    }
                }
                if !store.messages.isEmpty {
                    Button(role: .destructive) {
                        store.clearThread()
                        // Drop any un-acted goal proposal so a wiped thread
                        // doesn't carry a stale intent into the next turn.
                        pendingGoalIntent = nil
                    } label: {
                        Label("Clear thread", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Chat options")
            .accessibilityIdentifier("askNoum.threadOptions")
        }
    }

    private var shouldShowThreadOptions: Bool {
        onGoLive != nil || speaker.canSpeakReplies || !store.messages.isEmpty
    }

    private func toggleSpokenReplies() {
        CoachHaptic.selectionTap()
        let newValue = !voiceSettings.askNoumSpokenRepliesEnabled
        voiceSettings.askNoumSpokenRepliesEnabled = newValue
        // Turning voice OFF should silence any reply still playing — the user
        // just asked for text-only; honor it immediately.
        if !newValue {
            speaker.stop()
        }
    }

    private var headerSubtitle: String {
        // "Reading your context…" earned the user's complaint by showing
        // during EVERY pending reply — even after the first reply had
        // landed and the context was clearly already read. That made the
        // header read as stuck/stale. Now we only claim "reading context"
        // before the first reply of the thread has hydrated; after that,
        // pending replies show "Thinking…" which matches the actual
        // mental model the user has of what the coach is doing.
        if store.isAwaitingReply {
            return store.hasLandedCoachReply ? "Thinking\u{2026}" : "Reading your context\u{2026}"
        }
        if let line = activeCaseSubtitle {
            return line
        }
        if let voice = voice {
            return "Your \(voice.title.lowercased()) coach."
        }
        return "Your speaking coach."
    }

    private var activeCaseSubtitle: String? {
        guard let memory = coachMemoryStore.currentMemory,
              let caseFile = memory.caseFile else { return nil }
        if let target = caseFile.observableTarget?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !target.isEmpty {
            return "Working on \(Self.shortCaseLine(target).lowercased())"
        }
        if let focus = caseFile.focus {
            return "Working on \(focus.displayName.lowercased())"
        }
        if let intervention = caseFile.activeIntervention?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !intervention.isEmpty {
            return "Current drill: \(Self.shortCaseLine(intervention).lowercased())"
        }
        return nil
    }

    static func shortCaseLine(_ raw: String, maxLength: Int = 58) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let prefix = trimmed.prefix(maxLength)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "\u{2026}"
        }
        return String(prefix) + "\u{2026}"
    }

    // MARK: - Empty state (starter prompts)

    @ViewBuilder
    private var emptyState: some View {
        if isDayZero {
            // Seeded day-0 presence — deterministic greeting only. No
            // starter prompts (they dispatch LLM replies, which stay
            // gated on rep 1) and no AI starter generation task.
            dayZeroIntroCard
        } else {
            standardEmptyState
        }
    }

    /// Day-0 seeded greeting card. Same chrome as the standard empty
    /// state so the surface reads as the same coach, one day earlier.
    /// Copy is the pure `AskNoumDayZeroGreeting` template — enum-derived
    /// acknowledgement of the stated goal/challenge plus the one-rep
    /// invite. The matching CTA lives in `dayZeroFooter`, where the
    /// composer would otherwise be.
    private var dayZeroIntroCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(AskNoumDayZeroGreeting.headline)
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
            Text(AskNoumDayZeroGreeting.greeting(
                challenge: coachingProfileStore.profile?.biggestChallenge,
                voice: voice
            ))
            .font(Typography.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.pro.opacity(0.06), AppColor.cardBackground],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("askNoum.dayZeroIntro")
    }

    private var standardEmptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(emptyStateHeadline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                Text(emptyStateBody)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            standingPlanLandingStrip

            caseReviewStarterChip

            starterPrimaryAction
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.pro.opacity(0.06), AppColor.cardBackground],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.20), lineWidth: 1)
        )
        // Fire the AI starter generation once per input signature while the
        // empty state is on screen. The deterministic data-grounded
        // `starterPrompts(...)` renders immediately via `displayedStarters`;
        // this upgrades them to a tailored set if a provider is configured
        // and the locale supports AI. Idempotent + signature-gated, so an
        // unchanged empty state never re-rolls.
        .task(id: starterSignature) {
            await requestAIStartersIfNeeded()
        }
    }

    // MARK: - Day-0 footer (stands in for the composer)

    /// Replaces the input bar before rep 1. A plain one-line reason +
    /// ONE CTA that routes into the same recommended first rep the Home
    /// hero's Begin button starts — not a dead/disabled composer.
    private var dayZeroFooter: some View {
        VStack(spacing: Spacing.sm) {
            Text(AskNoumDayZeroGreeting.inputLockedNote)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryCTA(AskNoumDayZeroGreeting.firstRepCTATitle, icon: "play.fill", tint: AppColor.pro) {
                beginFirstRep()
            }
            .accessibilityIdentifier("askNoum.dayZeroBegin")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("askNoum.dayZeroFooter")
    }

    /// Route into the recommended first rep — the same blueprint +
    /// router pair `HomeCoachCard.beginRecommendedRep` uses, so the
    /// coach's "run one rep" invite lands in the exact rep the Home
    /// hero would start. No new routing logic.
    private func beginFirstRep() {
        CoachHaptic.selectionTap()
        let blueprint = RecommendationBiasContextBuilder.context(
            profile: coachingProfileStore.profile,
            sessions: sessionStore.sessions,
            sessionStreak: streakFreezeManager.currentStreak,
            daysSinceLastSession: 0,
            coachMemory: coachMemoryStore.currentMemory,
            imAvailable: IMModeAvailability.isAvailable,
            recommendationOutcomes: recommendationLearningStore.outcomes,
            summaryStyle: .compact
        ).blueprint
        navigationPath.append(
            SummaryLookingAheadRouter.destination(
                for: blueprint,
                imAvailable: IMModeAvailability.isAvailable
            )
        )
    }

    private var emptyStateHeadline: String {
        if activeCaseSubtitle != nil {
            return "Start with the current case."
        }
        if let voice = voice {
            return "Start with your \(voice.title.lowercased())."
        }
        return "Start with a coaching read."
    }

    // MARK: - Standing plan landing strip

    @ViewBuilder
    private var standingPlanLandingStrip: some View {
        if let line = Self.standingPlanLandingLine(caseFile: coachMemoryStore.currentMemory?.caseFile) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(AppColor.pro.opacity(0.70))
                    .frame(width: 3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CURRENT CASE")
                        .font(Typography.captionSmall.weight(.bold))
                        .foregroundStyle(AppColor.pro)
                    Text(line)
                        .font(Typography.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current coaching case: \(line)")
            .accessibilityIdentifier("askNoum.emptyState.standingPlan")
        }
    }

    static func standingPlanLandingLine(caseFile: CoachCaseFile?) -> String? {
        guard let raw = caseFile?.callLandingAnchor?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return shortCaseLine(raw, maxLength: 150)
    }

    // MARK: - Case-review starter chip
    //
    // Empty-state companion to `InterventionReviewPromptCard`. Renders
    // only when the active `CoachIntervention.isReviewDue(at:)`
    // predicate returns true — same eligibility gate the summary card
    // uses, so the two surfaces honour the same case-file cadence.
    //
    // Why a distinct visual register (calendar icon, brand-purple
    // tinted background, heavier stroke) rather than just another
    // entry in the starter-prompts catalog:
    //   • The chip is a coach priority signal, not a generic prompt.
    //     The user reads "your coach has a check-in queued" in one
    //     beat, not "here's another thing you could ask."
    //   • The display label is intentionally short (the
    //     `interventionReviewStarterHeadline` helper renders ~40 chars).
    //     The actual dispatched opener is the full `interventionReviewOpener`,
    //     same string the summary card sends — so the reply lands
    //     with mode + focus + followed-rep depth in scope and a
    //     voice-shaped review question already asked.
    //   • Voice continuity: tapping the chip from Ask Noum and tapping
    //     "Review with coach" from the summary produce the identical
    //     chat thread. No surface-specific phrasing drift.
    @ViewBuilder
    private var caseReviewStarterChip: some View {
        if let memory = coachMemoryStore.currentMemory,
           let intervention = memory.activeIntervention,
           intervention.isReviewDue(at: Date()) {
            Button {
                let opener = CoachContextBuilder.interventionReviewOpener(
                    intervention: intervention,
                    voice: voice,
                    reflectionPattern: memory.reflectionPattern
                )
                send(opener)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.pro)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REVIEW DUE")
                            .font(Typography.captionSmall)
                            .tracking(0.6)
                            .foregroundStyle(AppColor.pro)
                        Text(CoachContextBuilder.interventionReviewStarterHeadline(for: intervention))
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.pro)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AppColor.pro.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Review the active coaching case with Noum")
            .accessibilityHint("Opens the case-review conversation with the same context the post-rep card uses.")
            .accessibilityIdentifier("askNoum.emptyState.caseReviewChip")
        }
    }

    private var emptyStateBody: String {
        switch voice {
        case .authoritative:
            return "I'll keep it direct: one read, one reason, one move."
        case .warm:
            return "Bring the moment that felt awkward or important. We'll make the next attempt feel more like you."
        case .concise:
            return "Short question in, sharp coaching move out."
        case .persuasive:
            return "Tell me who you need to move. I'll work backwards to the line that carries weight."
        case .executive:
            return "Top-line first. We'll stay on the move that changes the room."
        case .storytelling:
            return "Give me the scene. I'll help you find the turn that makes it land."
        case .none:
            return "I read your practice history before replying, then keep the answer focused."
        }
    }

    @ViewBuilder
    private var starterPrimaryAction: some View {
        let layout = Self.coachOptionLayout(for: displayedStarters)
        if let primary = layout.primary {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    send(primary)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColor.pro)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recommended ask")
                                .font(Typography.micro.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.7)
                            Text(primary)
                                .font(Typography.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Spacing.xs)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        AppColor.cardBackground,
                        in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recommended ask: \(primary)")

                if !layout.overflow.isEmpty {
                    starterMoreMenu(options: layout.overflow)
                }
            }
        }
    }

    private func starterMoreMenu(options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    send(option)
                }
            }
        } label: {
            Label("Other useful asks", systemImage: "ellipsis.circle")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(AppColor.pro)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
        .accessibilityLabel("Other useful asks")
    }

    // MARK: - Follow-up chips
    //
    // Quiet "keep the thread alive" suggestions surfaced beneath the
    // most-recent coach reply. Two-tier sourcing:
    //   1. AI-tailored (preferred) — `CoachContextBuilder.generateAIFollowUpChips`
    //      fires once per landed reply and caches the result on
    //      `AskNoumStore.aiChipsCache[coachID]`. Tailored to the actual
    //      last-user-turn + last-coach-reply + voice tone.
    //   2. Deterministic catalog (fallback + skeleton) —
    //      `CoachContextBuilder.followUpSuggestions(...)`. Renders
    //      instantly while the AI request is in flight, and stays as the
    //      final state if the AI returns nil (no provider, locale block,
    //      network failure, or all chips failed the brand-voice filter).
    //
    // Chips never disappear once a reply lands. They may upgrade from
    // deterministic to AI when the cached entry arrives.
    //
    // Visibility contract:
    //   • Latest message must be a coach reply.
    //   • Reply must NOT be pending (no chips for an in-flight bubble).
    //   • Reply must NOT be a system notice (no chips when the model
    //     failed — there's nothing useful to follow up on).
    //   • No reply in flight at all (`!isAwaitingReply`) — keeps the
    //     row from flickering as the user is mid-send.
    //
    // Returns `nil` when the chip row should collapse entirely. Returns
    // a `[String]` (possibly empty after detection) otherwise — the
    // view bails on empty arrays too via the `chips.isEmpty` guard at
    // the call site.
    private var followUpChips: [String]? {
        guard !store.isAwaitingReply,
              let last = store.messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty
        else { return nil }
        let previousMessages = store.messages.dropLast()
        let previousCoachReply = previousMessages
            .last(where: { $0.role == .coach && !$0.isPending })?
            .text
        let lastUserTurn = previousMessages
            .last(where: { $0.role == .user })?
            .text
        let deterministic = CoachContextBuilder.followUpSuggestions(
            forCoachReply: last.text,
            previousCoachReply: previousCoachReply,
            lastUserTurn: lastUserTurn,
            voice: voice
        )
        guard !deterministic.isEmpty else { return [] }
        // Prefer cached AI chips only after the deterministic policy says this
        // reply earned a continuation. This prevents generic replies from
        // sprouting a chip tray just because the provider invented one.
        if let cached = store.aiChips(for: last.id), !cached.isEmpty {
            return cached
        }
        return deterministic
    }

    /// A3: the single launchable practice destination the LATEST coach reply
    /// points at, if any. Lifecycle is implicit + clean: it is computed from
    /// `store.messages.last` only, so it appears under the freshest coach reply
    /// that names a mode, is superseded the moment a new turn lands, and is
    /// dismissed by navigating away on tap. Nil while awaiting a reply, on a
    /// user turn, or when the reply names no mode (no card rather than a guess).
    private var suggestedModeDestination: AppDestination? {
        guard !store.isAwaitingReply,
              let last = store.messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty
        else { return nil }
        return AskNoumModeSuggestion.detect(in: last.text)
    }

    /// The ONE continuation surface the current turn earned, resolved by the
    /// pure arbiter on `CoachContextBuilder` from each surface's own
    /// eligibility composite. The body renders only the returned case, so a
    /// pending decision (goal commit / hypothesis verdict / revised-read
    /// verdict) and the "Next move" panel can never stack under one reply.
    private var activeContinuationSurface: CoachContextBuilder.ChatContinuationSurface? {
        let layout = Self.coachOptionLayout(for: followUpChips ?? [])
        return CoachContextBuilder.continuationSurface(
            goalProposalEligible: shouldShowGoalProposal,
            hypothesisAckEligible: shouldShowHypothesisAck,
            revisedReadFollowUpEligible: shouldShowRevisedReadFollowUp,
            nextMoveAvailable: suggestedModeDestination != nil || layout.primary != nil
        )
    }

    /// Coach message ID of the most-recent landed reply, if any. Drives
    /// the AI chip request — when this flips to a new ID we kick off a
    /// generation request for that reply (the previous reply's chips
    /// stay cached and don't need to re-roll).
    private var latestLandedCoachID: UUID? {
        guard let last = store.messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty
        else { return nil }
        return last.id
    }

    /// Fire an AI chip generation request for the given coach reply if
    /// one hasn't already been cached. Idempotent — re-entry with a
    /// cached ID is a no-op, so the on-change hook can safely fire
    /// every time the messages array mutates.
    private func requestAIChipsIfNeeded(for coachID: UUID) {
        // Skip if we already have chips for this reply — view rebuilds
        // must not re-roll generation.
        if store.aiChips(for: coachID) != nil { return }
        // Find the coach reply + the user turn that preceded it. The
        // generation request needs both for context-tailoring.
        guard let coachIdx = store.messages.firstIndex(where: { $0.id == coachID }) else { return }
        let coachReply = store.messages[coachIdx].text
        let lastUserTurn = store.messages
            .prefix(coachIdx)
            .last(where: { $0.role == .user })?
            .text ?? ""
        guard !lastUserTurn.isEmpty else { return }
        let previousCoachReply = store.messages
            .prefix(coachIdx)
            .last(where: { $0.role == .coach && !$0.isPending })?
            .text
        let deterministic = CoachContextBuilder.followUpSuggestions(
            forCoachReply: coachReply,
            previousCoachReply: previousCoachReply,
            lastUserTurn: lastUserTurn,
            voice: voice
        )
        guard !deterministic.isEmpty else { return }
        let voiceCapture = voice
        // Privacy-bounded summary of the user's recent reps (score / theme
        // / declared-intent / coach headline — NEVER raw transcript). Gives
        // the follow-up chips a real anchor ("ask about my last rep")
        // instead of pure conversational follow-up. Nil when there's no
        // usable history → the chip path falls through to today's behavior.
        let digestCapture = CoachContextBuilder.recentSessionDigestForChips(
            sessions: sessionStore.sessions,
            baseline: baselineStore.baseline
        )
        Task {
            let generated = await CoachContextBuilder.generateAIFollowUpChips(
                lastUserTurn: lastUserTurn,
                lastCoachReply: coachReply,
                voice: voiceCapture,
                recentSessionDigest: digestCapture
            )
            // Cache only on success — nil leaves the deterministic
            // fallback in place (no UI flicker, no dead chip row).
            if let chips = generated, !chips.isEmpty {
                await MainActor.run {
                    store.setAIChips(chips, for: coachID)
                }
            }
        }
    }

    // MARK: - Empty-state starter prompts (two-tier sourcing)
    //
    // Mirrors the follow-up chip machinery above. Two-tier:
    //   1. AI-tailored (preferred) — `CoachContextBuilder.generateAIStarterPrompts`
    //      fires once per input signature and caches on
    //      `AskNoumStore.starterChipsCache[signature]`. Tailored to the
    //      chosen voice + active BigMoment + weakest baseline dimension +
    //      a privacy-bounded recent-rep digest.
    //   2. Deterministic catalog (fallback + skeleton) —
    //      `CoachContextBuilder.starterPrompts(bigMoment:baseline:voice:)`.
    //      Renders instantly while the AI request is in flight, and stays
    //      as the final state if the AI returns nil (no provider, locale
    //      block, network failure, or fewer than 3 chips survived the
    //      brand-voice filter).
    //
    // Starters never disappear — they upgrade from deterministic to AI
    // when the cached entry arrives.

    /// Slow-changing rotation seed (day-of-year): the starter trio re-rolls
    /// daily instead of being identical on every open (owner feedback
    /// 2026-06-10), while staying stable within a session.
    private var starterRotation: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }

    /// The deterministic data-grounded starters. Always non-empty; this is
    /// both the instant skeleton and the final fallback.
    private var deterministicStarters: [String] {
        CoachContextBuilder.starterPrompts(
            bigMoment: bigMomentStore.activeMoment,
            baseline: baselineStore.baseline,
            voice: voice,
            rotation: starterRotation
        )
    }

    /// Stable signature of the inputs that shape the starters. A change to
    /// the chosen voice, the active upcoming moment, or the weakest
    /// dimension re-rolls the AI starters; idle re-renders reuse the cache.
    /// The deterministic starters are folded in so two states that produce
    /// the same catalog also share a cache slot.
    private var starterSignature: String {
        let voicePart = voice?.rawValue ?? "none"
        let momentPart = bigMomentStore.activeMoment.map { moment -> String in
            let days = BigMomentStore.daysUntil(moment).map(String.init) ?? "x"
            return "\(moment.category.rawValue)#\(days)"
        } ?? "nomoment"
        let weakPart = PracticeTopics.weakestDimensionLabel(for: baselineStore.baseline) ?? "noweak"
        // Day-bucket component: the AI-tailored starters re-roll daily too,
        // not only when voice/moment/weakness change.
        return "\(voicePart)|\(momentPart)|\(weakPart)|r\(starterRotation)"
    }

    /// Starters shown in the empty state. Prefers the cached AI set for the
    /// current signature; otherwise the deterministic catalog.
    private var displayedStarters: [String] {
        if let cached = store.starterChips(for: starterSignature), !cached.isEmpty {
            return cached
        }
        return deterministicStarters
    }

    /// Fire an AI starter generation request for the current signature if
    /// one hasn't already been cached. Idempotent — re-entry with a cached
    /// signature is a no-op, so the `.task(id:)` hook can safely re-fire.
    private func requestAIStartersIfNeeded() async {
        let signature = starterSignature
        // Skip if we already have starters for this signature.
        if store.starterChips(for: signature) != nil { return }
        let voiceCapture = voice
        let momentCapture = bigMomentStore.activeMoment
        let baselineCapture = baselineStore.baseline
        // Same privacy-bounded recent-rep digest as the follow-up chips.
        let digestCapture = CoachContextBuilder.recentSessionDigestForChips(
            sessions: sessionStore.sessions,
            baseline: baselineCapture
        )
        let generated = await CoachContextBuilder.generateAIStarterPrompts(
            voice: voiceCapture,
            bigMoment: momentCapture,
            baseline: baselineCapture,
            recentSessionDigest: digestCapture
        )
        // Cache only on success — nil leaves the deterministic catalog in
        // place (no flicker, no error surfaced to the user).
        if let chips = generated, !chips.isEmpty {
            await MainActor.run {
                store.setStarterChips(chips, for: signature)
            }
        }
    }

    // MARK: - Hypothesis acknowledgement row (post-case-review reply)
    //
    // Renders below the coach's reply to an `interventionReviewOpener`
    // dispatch (from either the summary card or the empty-state chip).
    // Three one-tap chips — confirmed / uncertain / rejected — let the
    // user lodge their verdict on the working hypothesis without typing
    // a sentence. The tap:
    //   1. Persists the verdict to `CoachMemoryStore.shared` via
    //      `noteHypothesisAcknowledgement(_:)`. The ack lands in
    //      durable case-file storage immediately.
    //   2. Dispatches the chip's voice-shaped text as a user turn via
    //      the existing `send(_:)` path. This keeps the chat surface
    //      continuous — the chip reads as a real reply, the model gets
    //      a coherent conversation, and the next reply lands with the
    //      user's verdict reflected in the user-context block (the
    //      builder reads `memory.hypothesisAcknowledgement` and
    //      surfaces a coach-direction line).
    //
    // Eligibility (`shouldShowHypothesisAcknowledgement`):
    //   • Most-recent message is a non-pending coach reply.
    //   • The user turn that triggered it begins with
    //     `interventionReviewOpenerLead` ("Time to review the active
    //     case:" — pinned on `CoachContextBuilder`).
    //   • The current memory's `workingHypothesis` is non-empty
    //     (otherwise there's nothing for the user to acknowledge).
    //   • The user hasn't already acknowledged this hypothesis (the
    //     snapshot guard on `CoachHypothesisAcknowledgement.appliesTo`
    //     — a stale ack from a prior case read re-prompts).
    //
    // Vision alignment:
    //   • Coach-parity gap closure. Per `docs/VISION.md`, the case
    //     formulation needs an explicit "reason for changing course."
    //     The user's hypothesis verdict IS that reason — the next
    //     `CoachCourseChange` entry can reference whether the user
    //     confirmed or rejected the read.
    //   • Pillar #5 (Personalized coaching). A real coach asks "does
    //     that sound right?" after sharing a read; we owe the same
    //     structured back-channel.
    @ViewBuilder
    private var hypothesisAckRow: some View {
        if shouldShowHypothesisAck {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Does this read match?")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .accessibilityLabel("Quick verdict on the working hypothesis")

                FlowLayout(spacing: 8, runSpacing: 6) {
                    ForEach(hypothesisAckChips, id: \.confidence) { chip in
                        Button {
                            recordHypothesisAck(chip)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: ackChipGlyph(for: chip.confidence))
                                    .font(Typography.captionSmall.weight(.semibold))
                                Text(chip.label)
                                    .font(Typography.caption.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(AppColor.pro)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                AppColor.pro.opacity(0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Acknowledge: \(chip.label)")
                        .accessibilityIdentifier("askNoum.hypothesisAck.\(chip.confidence.rawValue)")
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Eligibility composite for the hypothesis-ack row. The predicate
    /// from `CoachContextBuilder` covers the chat-shape check; the
    /// store-level check ensures we don't render a row the user has
    /// already answered for the currently-carried hypothesis.
    private var shouldShowHypothesisAck: Bool {
        guard CoachContextBuilder.shouldShowHypothesisAcknowledgement(messages: store.messages) else { return false }
        guard let memory = coachMemoryStore.currentMemory,
              let hypothesis = memory.workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hypothesis.isEmpty else { return false }
        // Suppress if the user has already acknowledged THIS hypothesis.
        // A drift to a different working hypothesis (memory rebuild) drops
        // the ack via `appliesTo`, which re-enables the row.
        if let ack = memory.hypothesisAcknowledgement,
           ack.appliesTo(currentHypothesis: memory.workingHypothesis) {
            return false
        }
        return true
    }

    private var hypothesisAckChips: [CoachContextBuilder.HypothesisAcknowledgementChip] {
        CoachContextBuilder.hypothesisAcknowledgementChips(for: voice)
    }

    private func ackChipGlyph(for confidence: CoachHypothesisConfidence) -> String {
        switch confidence {
        case .confirmed: return "checkmark.circle"
        case .uncertain: return "questionmark.circle"
        case .rejected: return "arrow.triangle.2.circlepath"
        }
    }

    private func recordHypothesisAck(_ chip: CoachContextBuilder.HypothesisAcknowledgementChip) {
        // Persist the verdict first so it lands in case-file storage even
        // if the dispatched user turn fails to reach the model (no
        // provider, locale block). The durable record is the priority;
        // the chat continuation is the courtesy.
        coachMemoryStore.noteHypothesisAcknowledgement(chip.confidence)
        send(chip.dispatchText)
    }

    // MARK: - Revised-read follow-up row (post-rebuild reply)
    //
    // Renders below the coach's reply to a `revisedReadOpener` dispatch
    // (the round-29 seed routed by `SummaryView.talkToNoumOpener` when the
    // post-rep `RevisedReadCard` is showing). Three voice-shaped one-tap
    // chips — stick / add / push back — let the user land a verdict on
    // the rebuilt working hypothesis without typing a sentence. The tap
    // path mirrors the round-26 `hypothesisAckRow` exactly:
    //
    //   1. Persists the verdict to `CoachMemoryStore.shared` via
    //      `noteHypothesisAcknowledgement(_:)`. The ack is tagged to the
    //      NEW (rebuilt) working hypothesis snapshot — `appliesTo` will
    //      preserve it across re-renders until the next memory rebuild.
    //   2. Dispatches the chip's voice-shaped text as a user turn via the
    //      existing `send(_:)` path. The chat thread stays continuous —
    //      the chip reads as a real reply, the model gets a coherent
    //      conversation, the next coach reply lands with the user's
    //      verdict reflected in the user-context block (the builder reads
    //      `memory.hypothesisAcknowledgement`).
    //
    // Eligibility (`shouldShowRevisedReadFollowUp`):
    //   • Most-recent message is a non-pending coach reply.
    //   • The user turn that triggered it begins with `revisedReadOpenerLead`
    //     ("Picking up the case file — I flagged the prior read as off." —
    //     pinned on `CoachContextBuilder` since round 29).
    //   • The current memory's `workingHypothesis` is non-empty.
    //   • The user hasn't already lodged a verdict on this rebuild (same
    //     `CoachHypothesisAcknowledgement.appliesTo` snapshot guard as the
    //     round-26 row — a memory rebuild that rewrote the hypothesis again
    //     re-prompts).
    //
    // The two acknowledgement predicates (round-26 case-review and round-30
    // revised-read) are mutually exclusive at the chat-shape level: a single
    // user turn can only begin with one opener lead. The body additionally
    // routes ALL post-reply surfaces through the one-per-turn arbiter
    // (`activeContinuationSurface`), so no two continuation rows can ever
    // stack under a single coach reply.
    //
    // Vision alignment:
    //   • Coach-parity stage #4 (Adaptation). Per `docs/VISION.md`, the
    //     case formulation needs a "reason for changing course" AND a way
    //     to confirm a rebuild has landed before the next adaptation
    //     cycle fires. Round 29 closed the seed half (chat thread names
    //     the user's pushback); round 30 closes the verdict half (chat
    //     thread records whether the rebuild stuck, needs refining, or
    //     needs another adaptation).
    //   • Pillar #5 (Personalized coaching). A human coach who rebuilt
    //     their read at the user's pushback would not move on without
    //     asking "does this new read land?" — they'd want the user's
    //     verdict on the revised hypothesis, not just the original one.
    @ViewBuilder
    private var revisedReadFollowUpRow: some View {
        if shouldShowRevisedReadFollowUp {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Where does the new read land?")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .accessibilityLabel("Quick verdict on the rebuilt working hypothesis")

                FlowLayout(spacing: 8, runSpacing: 6) {
                    ForEach(revisedReadFollowUpChips, id: \.confidence) { chip in
                        Button {
                            recordHypothesisAck(chip)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: ackChipGlyph(for: chip.confidence))
                                    .font(Typography.captionSmall.weight(.semibold))
                                Text(chip.label)
                                    .font(Typography.caption.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(AppColor.pro)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                AppColor.pro.opacity(0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("Land verdict: \(chip.label)")
                        .accessibilityIdentifier("askNoum.revisedReadFollowUp.\(chip.confidence.rawValue)")
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Eligibility composite for the revised-read follow-up row. The
    /// predicate from `CoachContextBuilder` covers the chat-shape check;
    /// the store-level check ensures we don't render a row the user has
    /// already answered for the currently-carried (rebuilt) hypothesis.
    /// Same composite shape as `shouldShowHypothesisAck`.
    private var shouldShowRevisedReadFollowUp: Bool {
        guard CoachContextBuilder.shouldShowRevisedReadFollowUp(messages: store.messages) else { return false }
        guard let memory = coachMemoryStore.currentMemory,
              let hypothesis = memory.workingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hypothesis.isEmpty else { return false }
        // Suppress if the user has already acknowledged THIS rebuilt
        // hypothesis. A subsequent memory rebuild (e.g. another `.rejected`
        // ack folded into a new course change) will rewrite the hypothesis
        // and drop the ack via `appliesTo`, which re-enables the row.
        if let ack = memory.hypothesisAcknowledgement,
           ack.appliesTo(currentHypothesis: memory.workingHypothesis) {
            return false
        }
        return true
    }

    private var revisedReadFollowUpChips: [CoachContextBuilder.HypothesisAcknowledgementChip] {
        CoachContextBuilder.revisedReadFollowUpChips(for: voice)
    }

    // MARK: - Goal proposal row (in-chat set / change confirmation card)
    //
    // S3 — the human-in-the-loop affordance that closes the dead-end where the
    // coach could only say "go to Settings." Renders below the coach's reply to
    // a detected set/change request (held on `pendingGoalIntent`). The card
    // states EXACTLY what will change and offers one-tap chips; ONLY a tap here
    // commits a profile write (`recordGoalSet` / `recordGoalChange`). The model
    // never writes — it only proposes in prose.
    //
    // Visual register is identical to `hypothesisAckRow` / `revisedReadFollowUpRow`
    // (left-inset header eyebrow + `FlowLayout` of `AppColor.pro` capsules,
    // `.buttonStyle(.pressable)`, per-chip accessibility) so it lands consistent
    // with the rest of the surface. A short intro line names the change so the
    // user reads what they're confirming before they tap.
    //
    // Eligibility (`shouldShowGoalProposal`): a pending intent exists AND the
    // most-recent message is a non-pending coach reply. Commit/decline clears
    // `pendingGoalIntent`, which collapses the card.
    @ViewBuilder
    private var goalProposalRow: some View {
        if shouldShowGoalProposal, let intent = pendingGoalIntent {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(goalProposalEyebrow(for: intent))
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .accessibilityLabel("Confirm a change to your speaking voice")

                if let detail = goalProposalDetail(for: intent) {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FlowLayout(spacing: 8, runSpacing: 6) {
                    ForEach(goalProposalChips) { chip in
                        Button {
                            handleGoalProposalChip(chip)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: goalChipGlyph(for: chip.action))
                                    .font(Typography.captionSmall.weight(.semibold))
                                Text(chip.label)
                                    .font(Typography.caption.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundStyle(AppColor.pro)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                AppColor.pro.opacity(0.10),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(goalChipAccessibilityLabel(for: chip))
                        .accessibilityIdentifier("askNoum.goalProposal.\(chip.id)")
                    }
                }
            }
            .padding(.top, 2)
            .padding(.bottom, Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    /// Eligibility composite for the goal-proposal card. The pure predicate from
    /// `CoachContextBuilder` covers the chat-shape + intent-present check; this
    /// thin wrapper passes the view's `pendingGoalIntent` presence so the same
    /// store-driven gate the ack rows use applies here too.
    private var shouldShowGoalProposal: Bool {
        CoachContextBuilder.shouldShowGoalProposal(
            messages: store.messages,
            intentPresent: pendingGoalIntent != nil
        )
    }

    private var goalProposalChips: [CoachContextBuilder.GoalProposalChip] {
        guard let intent = pendingGoalIntent else { return [] }
        return CoachContextBuilder.goalProposalChips(intent: intent, currentVoice: voice)
    }

    /// Card eyebrow — names whether this is a cold-start set or a change.
    private func goalProposalEyebrow(for intent: CoachContextBuilder.GoalIntent) -> String {
        switch intent.kind {
        case .initialSet:
            return intent.requestedVoice == nil ? "Pick your voice" : "Set your voice?"
        case .change:
            return "Change your voice?"
        }
    }

    /// One-line detail under the eyebrow that states EXACTLY what the user is
    /// confirming. For a resolved target it surfaces the voice's coaching
    /// description (cold start) or the explicit old→new trade-off (change). For
    /// an unresolved "help me pick" it nudges the user to tap a voice. Returns
    /// nil only when there is genuinely nothing to add beyond the chips.
    private func goalProposalDetail(for intent: CoachContextBuilder.GoalIntent) -> String? {
        switch intent.kind {
        case .initialSet:
            if let target = intent.requestedVoice {
                return "I'll set your voice to \(target.title) — you'll \(target.coachingDescription). Saved to your profile when you tap."
            }
            return "Pick the voice you want to train toward. I'll save it to your profile and shape every read around it."
        case .change:
            let current = voice?.title ?? "your current voice"
            if let target = intent.requestedVoice {
                return "You've been building \(current). What's changed — a moment coming up, or \(current) not landing? Switch fully to \(target.title), blend the two, or keep \(current) — your call."
            }
            return "You've been building \(current). What's changed — a moment coming up, or \(current) not landing? Pick what to switch to, or keep \(current)."
        }
    }

    private func goalChipGlyph(for action: CoachContextBuilder.GoalProposalAction) -> String {
        switch action {
        case .set: return "checkmark.circle"
        case .switchTo: return "arrow.triangle.2.circlepath"
        case .blend: return "circle.grid.2x1"
        case .decline: return "xmark.circle"
        }
    }

    private func goalChipAccessibilityLabel(for chip: CoachContextBuilder.GoalProposalChip) -> String {
        switch chip.action {
        case .set(let v): return "Set your voice to \(v.title) and save it"
        case .switchTo(let v): return "Switch your voice to \(v.title) and save it"
        case .blend(let v): return "Blend your current voice with \(v.title) and save it"
        case .decline: return chip.label
        }
    }

    /// Route a goal-proposal chip tap. The durable write happens FIRST (so the
    /// profile change lands even if the chat continuation fails — no provider,
    /// locale block), then the pending intent is cleared (collapsing the card),
    /// then the voice-shaped continuation is dispatched WITHOUT re-detection so
    /// it doesn't re-arm the card. Mirrors `recordHypothesisAck`'s
    /// durable-write-before-chat ordering. The LLM is never in this path —
    /// `CoachingProfileStore.save` is reached ONLY here, from the user's tap.
    private func handleGoalProposalChip(_ chip: CoachContextBuilder.GoalProposalChip) {
        switch chip.action {
        case .set(let newVoice):
            recordGoalSet(newVoice)
            CoachHaptic.drillSuccess()
        case .switchTo(let newVoice):
            recordGoalChange(to: newVoice, blend: false)
            CoachHaptic.drillSuccess()
        case .blend(let newVoice):
            recordGoalChange(to: newVoice, blend: true)
            CoachHaptic.drillSuccess()
        case .decline:
            CoachHaptic.selectionTap()
        }
        // Clear the pending intent BEFORE dispatching the continuation so the
        // card collapses and the continuation turn (which would itself match
        // the detector) does not re-arm it.
        pendingGoalIntent = nil
        send(chip.dispatchText, detectIntent: false)
    }

    /// COLD START commit — the user has no `CoachingProfile` yet. Construct a
    /// full profile from sensible defaults + the chosen voice (mirrors the
    /// canonical `CoachingOnboardingView.saveProfile` construction) and save.
    /// `save()` persists, syncs, and kicks the AI goal-paraphrase. No
    /// `noteVoiceChange` here — cold start has no prior voice and no memory to
    /// record a course change against; the profile write IS the durable record.
    private func recordGoalSet(_ newVoice: SpeakingStyleGoal) {
        // Guard against a race where a profile materialised between detection
        // and tap (e.g. onboarding finished in another surface). If a profile
        // now exists, treat this as a change instead of clobbering it.
        if coachingProfileStore.profile != nil {
            recordGoalChange(to: newVoice, blend: false)
            return
        }
        // Default biggest challenge → its recommended priority; voice → its
        // recommended outcome. Same derivations the onboarding flow uses, so a
        // chat-set profile is shaped identically to an onboarded one.
        let defaultChallenge: SpeakingChallenge = .fillerWords
        let profile = CoachingProfile(
            speakingContext: .work,
            primaryGoal: defaultChallenge.recommendedPriority,
            confidenceLevel: .rebuilding,
            biggestChallenge: defaultChallenge,
            desiredOutcome: newVoice.recommendedOutcome,
            speakingStyleGoal: newVoice,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: "",
            chosenStyleGoal: newVoice   // explicit user choice → tailored from here
        )
        coachingProfileStore.save(profile)
    }

    /// CHANGE commit — the user already has a voice. Record the course change in
    /// the coach's memory FIRST (the honest "reason for changing course" audit
    /// trail; appends a bounded `CoachCourseChange`, never wipes baseline /
    /// trends / session history), THEN save the mutated profile copy. A full
    /// switch replaces `speakingStyleGoal` and clears any prior blend secondary;
    /// a blend keeps the current primary and sets the new voice as the
    /// secondary. `paraphrasedGoal` is reset to nil so `save()` re-paraphrases
    /// the goal in the new voice. Bounded scope — only voice fields + the
    /// paraphrase reset are touched, never arbitrary profile data.
    private func recordGoalChange(to newVoice: SpeakingStyleGoal, blend: Bool) {
        guard var profile = coachingProfileStore.profile else {
            // No profile to change — fall back to cold-start construction. (Only
            // reachable if the profile vanished between detection and tap.)
            recordGoalSet(newVoice)
            return
        }
        let fromVoice = profile.speakingStyleGoal
        // No-op guard: a full "switch" to the voice the user already has would
        // record a meaningless course change. Bail before any write.
        if !blend && fromVoice == newVoice { return }

        // Durable course-change record FIRST. `noteVoiceChange` no-ops when
        // there's no current memory (nothing to record against) — the profile
        // write below is still the durable record in that case.
        let kind: CoachCourseChange.VoiceChangeKind = blend ? .blend : .switchVoice
        coachMemoryStore.noteVoiceChange(
            from: fromVoice,
            to: newVoice,
            reason: CoachCourseChange.voiceChangeReason(from: fromVoice, to: newVoice, kind: kind),
            evidenceBasis: "User changed their chosen voice goal from the in-chat goal card."
        )

        if blend {
            // Keep the primary; add the new voice as the secondary. A blend onto
            // the existing primary widens the read without erasing it.
            profile.secondaryStyleGoal = newVoice
            // The primary stays the user's chosen voice; ensure the choice flag
            // is set (covers a legacy profile whose chosenStyleGoal was nil).
            profile.chosenStyleGoal = profile.speakingStyleGoal
        } else {
            // Full switch — new primary, drop any prior blend secondary.
            profile.speakingStyleGoal = newVoice
            profile.chosenStyleGoal = newVoice
            profile.secondaryStyleGoal = nil
        }
        // Re-paraphrase the goal in the new voice on the next save pass.
        profile.paraphrasedGoal = nil
        coachingProfileStore.save(profile)
    }

    struct CoachOptionLayout: Equatable {
        let primary: String?
        let overflow: [String]
    }

    static func coachOptionLayout(for options: [String]) -> CoachOptionLayout {
        var seen = Set<String>()
        let cleaned = options.compactMap { option -> String? in
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return trimmed
        }
        return CoachOptionLayout(primary: cleaned.first, overflow: Array(cleaned.dropFirst()))
    }

    @ViewBuilder
    private func coachNextMovePanel(destination: AppDestination?, chips: [String]) -> some View {
        let layout = Self.coachOptionLayout(for: chips)
        if destination != nil || layout.primary != nil {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Next move")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .accessibilityHidden(true)

                Button {
                    CoachHaptic.selectionTap()
                    if let destination {
                        navigationPath.append(destination)
                    } else if let primary = layout.primary {
                        send(primary)
                    }
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: destination == nil ? "arrow.up.right.circle.fill" : "play.circle.fill")
                            .font(Typography.caption.weight(.bold))
                            .foregroundStyle(AppColor.pro)
                        Text(primaryNextMoveLabel(destination: destination, fallback: layout.primary))
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        AppColor.cardBackground,
                        in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(AppColor.pro.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("askNoum.nextMove.primary")
                .accessibilityLabel(primaryNextMoveAccessibilityLabel(destination: destination, fallback: layout.primary))

                if !layout.overflow.isEmpty {
                    Menu {
                        ForEach(layout.overflow, id: \.self) { option in
                            Button(option) {
                                send(option)
                            }
                        }
                    } label: {
                        Label("Other directions", systemImage: "ellipsis.circle")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.pro)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("askNoum.nextMove.more")
                    .accessibilityLabel("Other directions")
                }
            }
            .padding(.top, 2)
            .padding(.bottom, Spacing.xs)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityIdentifier("askNoum.nextMovePanel")
        }
    }

    private func primaryNextMoveLabel(destination: AppDestination?, fallback: String?) -> String {
        if let destination {
            return AskNoumModeSuggestion.label(for: destination)
        }
        return fallback ?? "Continue"
    }

    private func primaryNextMoveAccessibilityLabel(destination: AppDestination?, fallback: String?) -> String {
        if let destination {
            return AskNoumModeSuggestion.label(for: destination)
        }
        return "Follow up: \(fallback ?? "Continue")"
    }

    // MARK: - Message rows

    /// Quiet session-ending action at the bottom of the thread. Stops any
    /// speech, then pops the shared NavigationPath to root — a deep chat
    /// thread returns straight Home in one tap. Renders only when a
    /// conversation exists (the empty state has nothing to end).
    private var endChatRow: some View {
        Button {
            CoachHaptic.selectionTap()
            speaker.stop()
            navigationPath = NavigationPath()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.uturn.left")
                    .font(.caption.weight(.semibold))
                Text("End chat")
                    .font(Typography.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
            .background(AppColor.tagBackground, in: Capsule())
        }
        .buttonStyle(.pressable)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xs)
        .accessibilityLabel("End chat and return home")
        .accessibilityIdentifier("askNoum.endChat")
    }

    @ViewBuilder
    private func messageRow(message: CoachMessage) -> some View {
        switch message.role {
        case .user:
            userBubble(message: message)
        case .coach:
            coachBubble(message: message)
        case .systemNotice:
            noticeBubble(message: message)
        }
    }

    private func userBubble(message: CoachMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 40)
            Text(message.text)
                .font(Typography.manrope(size: 16, weight: .medium, relativeTo: .body))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    AppColor.brandBlue,
                    in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                )
                .accessibilityLabel("You: \(message.text)")
        }
    }

    private func coachBubble(message: CoachMessage) -> some View {
        // No per-bubble inline glyph anymore. The user called the repeated
        // orb beside every reply visual noise; left-alignment + the
        // brand-purple stroke already read as "coach speaking", and the
        // header (always visible, even compact) carries embodiment. The
        // in-flight `pendingDots` keeps its own `.thinking` orb so the
        // typing state still reads as the coach — that's the one place the
        // orb earns its keep. The card spans full width, flush to the
        // container's leading edge, so the ack / follow-up / proposal rows
        // below align to it without the old 34pt inset.
        //
        // HONEST OFFLINE STATE (A3): a `.deterministicReply` (model
        // unreachable) carries `isOffline`. It is a real, useful coach line —
        // it still shows — but it is NOT the intelligent live coach, so it must
        // never wear the brand-purple live treatment. Offline rows get a quiet
        // "Offline — reconnect for a full read" marker + a neutral grey stroke
        // and slightly muted text, so the user can trust that the purple-stroke
        // bubbles are the live coach and this one is the local stand-in.
        let accent = message.isOffline ? AppColor.textSecondary : AppColor.pro

        return HStack(alignment: .top, spacing: 12) {
            if !message.isPending {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.opacity(message.isOffline ? 0.45 : 0.78))
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                if message.isPending {
                    pendingDots
                        .padding(.vertical, 4)
                } else {
                    if message.isOffline {
                        offlineMarker
                    }
                    // Living-coach-presence: the just-landed reply reveals word
                    // by word (see `revealingMessageID`); every other row shows
                    // its full text. The renderer supports compact Markdown
                    // (`**bold**`, bullets, numbered steps) without changing the
                    // persisted thread schema.
                    CoachFormattedMessageText(
                        text: visibleCoachText(for: message),
                        textColor: message.isOffline ? Color.secondary : Color.primary,
                        accent: accent
                    )
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            message.isOffline ? AppColor.innerSurface : AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(
                    message.isOffline ? AppColor.subtleBorder : AppColor.pro.opacity(0.10),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(message.isOffline ? 0 : 0.035), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            message.isOffline
                ? "Noum, offline reply: \(message.text)"
                : "Noum: \(message.text)"
        )
    }

    private func visibleCoachText(for message: CoachMessage) -> String {
        guard message.id == revealingMessageID else { return message.text }
        if !revealedText.isEmpty { return revealedText }
        return message.isPending ? "" : message.text
    }

    /// Quiet "offline" chip shown above a `.deterministicReply`'s text. Honest
    /// states invariant: this row is the local stand-in, not the live coach, so
    /// it says so plainly — and stays useful (the grounded line still renders
    /// below). Uses neutral tokens only; never the brand-purple live treatment.
    private var offlineMarker: some View {
        HStack(spacing: 5) {
            Image(systemName: "wifi.slash")
                .font(Typography.micro.weight(.semibold))
            Text("Offline \u{2014} reconnect for a full read")
                .font(Typography.micro.weight(.semibold))
                .tracking(0.3)
        }
        .foregroundStyle(AppColor.textSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline reply. Reconnect for a full read from your coach.")
    }

    private func noticeBubble(message: CoachMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
            Text(message.text)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Color.orange.opacity(0.08),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
    }

    // MARK: - Pending typing indicator
    //
    // Replaces the legacy three-dot pulse with a small `.thinking` orb —
    // same coach character that lives in the header, sized down to
    // bubble-glyph register. Reads as "Noum is thinking about what you
    // said" with continuity to the rest of the surface. Reduce-motion
    // is handled inside `NoumCharacter` itself (the orb collapses to a
    // static glow at small sizes), so no extra gate here.

    private var pendingDots: some View {
        HStack {
            NoumCharacter(
                mood: .thinking,
                tint: AppColor.pro,
                size: 24,
                stage: characterStage
            )
            Spacer(minLength: 0)
        }
        .accessibilityLabel("Noum is thinking")
    }

    // MARK: - Input area (integrated text + voice composer)

    @ViewBuilder
    private var inputArea: some View {
        inputBar
    }

    /// Shared tap action for the single trailing composer control.
    private func performInputAction(for mode: InputControlMode) {
        switch mode {
        case .send, .sendOnly:
            trySend()
        case .speaking:
            // The control is the Stop affordance while the coach speaks.
            CoachHaptic.selectionTap()
            speaker.stop()
        case .mic, .recording, .processing:
            CoachHaptic.selectionTap()
            // Barge-in: silence any in-flight coach speech the moment the user
            // reaches for the mic, so the synthesizer never fights the recognizer.
            speaker.stop()
            voiceInput.toggle()
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            micNoticeRow
            voiceNoticeRow
            partialTranscriptPreview
            inputBarRow
        }
        .background(.ultraThinMaterial)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: voiceInput.state == .recording)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: voiceInput.partialTranscript)
    }

    /// A2: surfaces a brief reason when voice can't proceed (permission /
    /// locale / temporary), so the mic never silently "does nothing" — paired
    /// with the mic control hiding itself. Renders only when set.
    @ViewBuilder
    private var micNoticeRow: some View {
        if let notice = voiceInput.notice {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(Typography.captionSmall)
                Text(notice)
                    .font(Typography.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .accessibilityIdentifier("askNoum.micNotice")
        }
    }

    /// C5 — honest spoken-reply state: when the user asked for voice (Aloud
    /// on) but no engine could produce audio, say so quietly instead of
    /// letting the silent bubble read as a muted coach. Gated on the voice
    /// preference so a user who has voice off never sees voice plumbing.
    @ViewBuilder
    private var voiceNoticeRow: some View {
        if voiceSettings.askNoumSpokenRepliesEnabled,
           let notice = speaker.voiceUnavailableNotice {
            HStack(spacing: 6) {
                Image(systemName: "speaker.slash")
                    .font(Typography.captionSmall)
                Text(notice)
                    .font(Typography.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .accessibilityIdentifier("askNoum.voiceNotice")
            .accessibilityLabel(notice)
        }
    }

    private var inputBarRow: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            ZStack(alignment: .leading) {
                if draft.isEmpty {
                    Text(textFieldPlaceholder)
                        .font(Typography.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .allowsHitTesting(false)
                }
                TextField("", text: $draft, axis: .vertical)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .focused($inputFocused)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit { trySend() }
            }
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )

            // One unified 44pt trailing control replaces the old greyed
            // send circle + the oversized separate mic. The glyph swaps by
            // draft state: empty → mic (start dictation), text → arrow.up
            // (send). Recording shows stop.fill, processing shows waveform.
            // When voice can't be served the control stays send-only (the
            // dead-toggle fallback) — it never pretends a mic that isn't
            // there. `.symbolEffect(.replace)` makes the swap a calm
            // morph, gated on reduce-motion.
            unifiedInputControl
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Unified input control (mic / arrow swap)
    //
    // Collapses what used to be three controls (text field + a greyed
    // up-arrow send circle + a larger separate blue mic) into one 44pt
    // trailing button whose meaning follows the draft. The previous
    // layout drew a *dead* greyed send button at all times AND a mic that
    // was visually larger than send — the user flagged both as clutter.
    //
    // Mode resolution (`inputControlMode`):
    //   • text in draft → `.send` (arrow.up, brand-purple, active)
    //   • empty draft + voice available + idle → `.mic` (mic.fill, brand-blue)
    //   • recording → `.recording` (stop.fill, brand-blue) — tap stops + sends
    //   • processing → `.processing` (waveform, brand-blue) — inert, recognizer
    //     is finalising
    //   • empty draft + voice unavailable → `.sendOnly` (arrow.up, greyed,
    //     disabled) — the honest dead-toggle fallback
    //
    // Both accessibility labels survive: the send modes read "Send
    // message" (the string the UI test taps); the voice modes read the
    // state-specific `micAccessibilityLabel`. Awaiting a reply dims +
    // disables the control (mirrors the old per-button gates).
    private var unifiedInputControl: some View {
        let mode = inputControlMode
        return Button {
            performInputAction(for: mode)
        } label: {
            ZStack {
                Circle()
                    .fill(inputControlFill(for: mode))
                    .frame(width: 44, height: 44)
                // Recording-only ring — keeps the live-capture cue without
                // reintroducing the oversized halo. Sized to hug the 44pt
                // control. The richer "Listening… + your words" affordance
                // already lives in `partialTranscriptPreview` above.
                if mode == .recording {
                    Circle()
                        .stroke(AppColor.brandBlue.opacity(0.35), lineWidth: 2)
                        .frame(width: 52, height: 52)
                        .transition(.opacity)
                }
                Image(systemName: inputControlGlyph(for: mode))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: mode == .processing && !reduceMotion)
                    // S5 — "coach is speaking" cue: the same variableColor
                    // waveform register the live-transcript preview uses, so
                    // the user reads "voice is active". Reduced-motion safe:
                    // the symbol stays static when motion is disabled (the
                    // glyph + Stop semantics still communicate the state).
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: mode == .speaking && !reduceMotion)
            }
        }
        .disabled(inputControlDisabled(for: mode))
        // Speaking is an active, tappable Stop — it must NOT inherit the
        // awaiting-reply dim (the coach can be speaking turn N while turn N is,
        // by definition, no longer awaiting).
        .opacity((store.isAwaitingReply && mode != .speaking) ? 0.45 : 1.0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: mode)
        .accessibilityLabel(inputControlAccessibilityLabel(for: mode))
        .accessibilityIdentifier("askNoum.inputControl")
    }

    /// The state of the single trailing control. Precedence, top-down:
    /// recording / processing (a live mic interaction wins over everything);
    /// then draft text → send; then a speaking coach → Stop; then the resting
    /// mic (or a disabled send when voice capture can't serve). Speaking sits
    /// BELOW send so typing always dispatches, and BELOW recording/processing
    /// so it never masks an in-progress dictation — but ABOVE the idle mic so
    /// an empty composer surfaces the Stop affordance while audio plays.
    private enum InputControlMode: Equatable {
        case send        // draft has text → dispatch
        case sendOnly    // empty draft, voice unavailable → disabled send
        case mic         // empty draft, voice idle → start dictation
        case recording   // capturing → stop + send
        case processing  // recognizer finalising → inert
        case speaking    // coach reply playing → tap to stop (barge-in)
    }

    private var inputControlMode: InputControlMode {
        if voiceInput.state == .recording { return .recording }
        if voiceInput.state == .processing { return .processing }
        let hasDraft = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasDraft { return .send }
        if speaker.isSpeaking { return .speaking }
        return voiceInput.isAvailable ? .mic : .sendOnly
    }

    private func inputControlGlyph(for mode: InputControlMode) -> String {
        switch mode {
        case .send, .sendOnly: return "arrow.up"
        case .mic: return "mic.fill"
        case .recording: return "stop.fill"
        case .processing: return "waveform"
        case .speaking: return "waveform"
        }
    }

    private func inputControlFill(for mode: InputControlMode) -> Color {
        switch mode {
        case .send:
            // Active send — only reachable when `canSend`, but guard anyway
            // so a stray awaiting-reply frame greys instead of inviting a tap.
            return canSend ? AppColor.pro : Color.secondary.opacity(0.20)
        case .sendOnly:
            return Color.secondary.opacity(0.20)
        case .mic, .recording, .processing, .speaking:
            return AppColor.brandBlue
        }
    }

    private func inputControlDisabled(for mode: InputControlMode) -> Bool {
        switch mode {
        case .send: return !canSend
        case .sendOnly: return true
        case .mic, .recording: return store.isAwaitingReply
        case .processing: return true
        // Always tappable — the whole point is barge-in.
        case .speaking: return false
        }
    }

    private func inputControlAccessibilityLabel(for mode: InputControlMode) -> String {
        switch mode {
        case .send, .sendOnly:
            return "Send message"
        case .speaking:
            return "Coach is speaking, double-tap to stop"
        case .mic, .recording, .processing:
            return micAccessibilityLabel
        }
    }

    /// "I'm hearing…" preview above the input bar while voice capture
    /// is active. Real-device confidence: without it, a long press on
    /// a noisy environment looks like a dead mic — the user can't tell
    /// whether the recognizer caught their first word. Surfaces the
    /// live partial transcript from `AskNoumVoiceInput` so the user
    /// sees their words appearing as they speak.
    ///
    /// Honest empty-state: while recording with no recognized text yet
    /// we show a soft "Listening…" line, NOT a stale stuck preview.
    /// The transcript replaces it as soon as the recognizer lands a
    /// word. After release-to-send the preview hides — the final
    /// transcript lands in the composer as editable draft text and the preview
    /// hides. The user sends it with the same trailing control.
    ///
    /// Visual register: small italic body text, brand-blue tint at
    /// 75% opacity, brand-blue 10% backdrop. Same accent the mic
    /// button uses so the user reads "this is the mic talking" not
    /// "this is a new system message". Hidden via opacity + 0-height
    /// frame collapse when idle so the input bar's resting layout
    /// doesn't shift around when capture starts.
    @ViewBuilder
    private var partialTranscriptPreview: some View {
        let isRecording = voiceInput.state == .recording
        let trimmed = voiceInput.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if isRecording {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "waveform")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue.opacity(0.80))
                    .padding(.top, 2)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                Text(trimmed.isEmpty ? "Listening\u{2026}" : trimmed)
                    .font(Typography.body.italic())
                    .foregroundStyle(AppColor.brandBlue.opacity(trimmed.isEmpty ? 0.55 : 0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(trimmed.isEmpty
                                        ? "Listening for your voice"
                                        : "Hearing: \(trimmed)")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.brandBlue.opacity(0.08))
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var textFieldPlaceholder: String {
        "Message Noum..."
    }

    /// State-specific accessibility label for the voice modes of the
    /// unified input control. Replaces the standalone mic button's label
    /// (the big mic was removed in the S4 input-row unification) — read by
    /// `inputControlAccessibilityLabel(for:)` when the control is in a
    /// mic / recording / processing mode.
    private var micAccessibilityLabel: String {
        switch voiceInput.state {
        case .idle:
            return "Tap to record your message"
        case .recording:
            return "Recording — tap to stop"
        case .processing:
            return "Processing your message"
        }
    }

    private var canSend: Bool {
        // Recording is an active stop state; typed text is the send state.
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
         || voiceInput.state == .recording)
        && !store.isAwaitingReply
    }

    // MARK: - Send + scroll

    private func trySend() {
        // If recording is active, finalise it. Voice-first mode dispatches from
        // `onFinalTranscript`; typed fallback receives the transcript as draft
        // for review/edit before the next Send tap.
        if voiceInput.state == .recording {
            voiceInput.stopAndSend()
            return
        }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !store.isAwaitingReply else { return }
        draft = ""
        inputFocused = false
        send(trimmed)
    }

    /// Dispatch a user turn into the thread and request the coach reply.
    ///
    /// `detectIntent` is the single funnel for goal set/change detection — every
    /// organic entry point (typed, voice transcript, starter chip, follow-up
    /// chip, cross-surface inject) flows through here with it `true`, so
    /// `CoachContextBuilder.detectGoalIntent` runs once per real user turn and
    /// arms the confirmation card. The goal-card commit handlers dispatch their
    /// voice-shaped continuation with `detectIntent: false` so a continuation
    /// like "Set my voice to Warm." (which would itself match the detector)
    /// does NOT re-arm the card after the user already confirmed.
    ///
    /// Detection runs BEFORE the reply is dispatched and stores the intent on
    /// `pendingGoalIntent`; `runReply` reads it to inject the GOAL context line
    /// so the coach PROPOSES (the model still never writes — only a card tap
    /// commits). A nil result clears any stale pending intent so a non-goal
    /// turn collapses a card the user neither confirmed nor declined.
    private func send(_ text: String, detectIntent: Bool = true) {
        // Day-0 invariant: full replies stay gated on rep 1. The UI never
        // offers a dispatch path while `isDayZero` (no composer, no starter
        // chips), so this guard is belt-and-braces — it keeps the invariant
        // true even if a future surface wires a send into the seeded window.
        guard !isDayZero else { return }
        // Single-in-flight: every dispatch path (typed Send, voice transcript,
        // starter/follow-up/goal/next-move chips, cross-surface inject) funnels
        // through here. `trySend` checks isAwaitingReply but the chip/voice/menu
        // paths call send() directly, so a rapid second chip or an already-open
        // menu could mint a second pending row + a second CoachReplyPipeline run
        // (double Gemini spend, racing replies). Guard once at the funnel.
        guard !store.isAwaitingReply else { return }
        // S5 — barge-in: a new user turn supersedes the prior coach reply, so
        // stop any audio still playing from it before we dispatch. The reply
        // that lands for THIS turn will start its own clip via `runReply`. This
        // is the single dispatch funnel (typed / voice transcript / chip /
        // cross-surface inject all flow through here), so one stop covers them.
        speaker.stop()
        if detectIntent {
            pendingGoalIntent = CoachContextBuilder.detectGoalIntent(text, currentVoice: voice)
        }
        let ids = store.appendUserTurn(text)
        Task {
            await runReply(coachID: ids.coachID)
        }
    }

    private func runReply(coachID: UUID) async {
        // Context assembly + model call + row hydration is shared with the live
        // call view via `CoachReplyPipeline` (one brain for both surfaces). The
        // spoken-reply decision stays here because it differs by surface.
        let outcome = await CoachReplyPipeline.generate(
            coachID: coachID,
            pendingGoalIntent: pendingGoalIntent
        )
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

    /// Progressively reveal a just-landed coach reply, word by word, so the
    /// coach reads as *writing to you* rather than the text popping in. The
    /// store already holds the full text; this only drives the visible prefix
    /// (`revealedText`) for `message.id`. Cancellable — a new turn or a view
    /// teardown cancels the task so it never writes state for a superseded row.
    /// Caller guarantees reduce-motion is OFF (the instant path skips this).
    @MainActor
    private func startReveal(of message: CoachMessage, proxy: ScrollViewProxy) {
        revealTask?.cancel()
        revealingMessageID = message.id
        revealedText = ""
        let words = message.text.split(separator: " ", omittingEmptySubsequences: false)
        revealTask = Task { @MainActor in
            var assembled = ""
            for (i, word) in words.enumerated() {
                if Task.isCancelled { return }
                assembled += i == 0 ? String(word) : " " + word
                revealedText = assembled
                // Keep the growing bubble in view without thrashing the
                // scroller — nudge every few words, not every word.
                if i % 4 == 0 { scrollToBottom(proxy: proxy) }
                try? await Task.sleep(nanoseconds: 30_000_000) // ~30ms/word
            }
            if Task.isCancelled { return }
            // Hand back to the store's full `message.text` (identical to the
            // assembled string) so the bubble's source of truth is the store.
            revealingMessageID = nil
            revealedText = ""
            scrollToBottom(proxy: proxy)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .linear(duration: 0.001) : .easeOut(duration: 0.25)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

#endif
