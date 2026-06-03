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
//   • Eyebrow: "ASK NOUM · <Voice>" — micro caps label, brand-purple
//     so the coach surface reads as a distinct register from the
//     brand-blue path/journey card.
//   • Header: NoumCharacter (voice-tinted orb) + the coach's name. It
//     COLLAPSES on scroll (S4) — the orb shrinks 60→28 and the subtitle
//     drops once the thread scrolls past a small deadband, driven by a
//     scroll-offset probe (`AskNoumScrollOffsetKey`) exactly like the
//     home screen. The full header greets a first-time / top-of-thread
//     user; the conversation gets the screen back once you're in it.
//   • Empty state (no messages): voice-specific starter prompts as
//     tappable chips. Removes the friction of the first message.
//   • Thread: alternating user (right-aligned brand-blue bubble) +
//     coach (left-aligned full-width card) rows. The coach card carries
//     NO per-bubble glyph (S4 removed the repeated orb the user flagged
//     as noise) — left-alignment + the brand-purple stroke read as the
//     coach, and the header carries embodiment. The in-flight bubble
//     keeps a `.thinking` orb as its typing indicator, the one place the
//     orb earns its keep.
//   • Input bar: rounded text field + ONE 44pt trailing control (S4)
//     that swaps glyph by draft state — mic when empty, arrow.up when
//     there's text, stop.fill while recording. Replaced the old greyed
//     send circle + oversized separate mic. Disabled while a reply is in
//     flight; falls back to send-only when voice can't be served.
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

// MARK: - Spoken-coach-mode pure logic (S5)
//
// The decision of WHETHER to speak a freshly-landed coach turn is isolated
// here as pure, view-free logic so it can be unit-tested without standing up
// the SwiftUI view, an audio engine, or a model. `AskNoumView.runReply`
// calls `shouldSpeak(...)` at the single chokepoint where a reply becomes
// visible (`store.completeCoachTurn`), and only then drives
// `IMMessageSpeaker.shared.speak(...)`.
//
// The voice → tone mapping translates the user's CHOSEN `SpeakingStyleGoal`
// into the `IMTargetTone` the TTS layer reads for voice selection, so the
// coach's spoken register leans toward the voice the user is training. A nil
// chosen voice (the user hasn't picked) maps to a steady, neutral `.calm`
// coach voice — never an invented register.
@available(iOS 17.0, macOS 12.0, *)
enum AskNoumSpokenMode {

    /// The single source of truth for "should this landed outcome be spoken?".
    ///
    /// True ONLY when ALL hold:
    ///   • the voice-mode toggle is ON (`spokenRepliesEnabled`),
    ///   • the active locale supports AI (`localeSupportsAI`) — non-English
    ///     users stay clean text-only, matching the chat-reply locale gate,
    ///   • the outcome is a real `.reply` with non-empty trimmed text.
    ///
    /// A `.failure` (any cause) is NEVER spoken — a system-notice row is a
    /// UI affordance, not the coach's voice, so reading "I couldn't reach my
    /// model" aloud would be worse than silence. A `.deterministicReply` (the
    /// grounded offline line) is ALSO never spoken: TTS needs the same network /
    /// provider that is down, and reading a canned line aloud as if it were the
    /// live coach would overclaim — it stays a silent text bubble. An
    /// all-whitespace reply is also rejected (defensive; the store routes that
    /// to `.failure(.empty)` anyway, but the predicate must not depend on that
    /// downstream behavior).
    static func shouldSpeak(
        outcome: ChatOutcome,
        spokenRepliesEnabled: Bool,
        localeSupportsAI: Bool
    ) -> Bool {
        guard spokenRepliesEnabled, localeSupportsAI else { return false }
        switch outcome {
        case .reply(let text):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .deterministicReply:
            // A canned offline line is NEVER read aloud as the live coach —
            // TTS needs the same network / provider that is down, and a
            // deterministic line spoken as if live would overclaim. It renders
            // as a coach bubble (see `AskNoumStore.completeCoachTurn`) but stays
            // silent.
            return false
        case .failure:
            return false
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
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var proofStore = ProofMomentStore.shared
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

    private var voice: SpeakingStyleGoal? {
        // The CHOSEN voice, not the always-populated effective default — so the
        // header/persona stay generic ("Your speaking coach.") until the user
        // actually picks a voice, and the coach offers to set one instead of
        // inventing "authoritative."
        coachingProfileStore.profile?.chosenStyleGoal
    }

    /// True once the thread has scrolled up past a small threshold. Collapses
    /// the header to a compact bar (small orb + name, no subtitle) so the
    /// conversation gets the screen back. The 24pt deadband keeps the header
    /// from twitching on tiny rubber-band offsets at rest. Only meaningful
    /// when there are messages to scroll — the empty state never scrolls far
    /// enough to trip it, so the full header greets a first-time user.
    private var isHeaderCompact: Bool {
        scrollOffset < -24
    }

    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                    .opacity(0.4)
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
                                hypothesisAckRow
                                    .id("hypothesisAck")
                                revisedReadFollowUpRow
                                    .id("revisedReadFollowUp")
                                goalProposalRow
                                    .id("goalProposal")
                                // A3: ONE prompt at a time. A concrete mode/
                                // exercise recommendation (the stronger, more
                                // actionable CTA) takes precedence over the
                                // keep-going suggestion chips.
                                if let modeDestination = suggestedModeDestination {
                                    modeLaunchRow(destination: modeDestination)
                                        .id("modeLaunch")
                                } else if let chips = followUpChips, !chips.isEmpty {
                                    followUpRow(chips: chips)
                                        .id("followups")
                                }
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
                        // The reply hydrated — fire the AI chip request
                        // for the freshly landed coach message. The
                        // generator dedupes via the cache; this hook is
                        // safe to fire on every transition out of an
                        // in-flight state.
                        if !awaiting, let coachID = latestLandedCoachID {
                            requestAIChipsIfNeeded(for: coachID)
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
                insightsCaption
                inputBar
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Wire the voice-input transcript callback. Transcript lands
            // in the draft text field so the user can review (and edit)
            // before tapping Send. This makes tap-to-toggle feel like
            // dictation, not auto-fire — user owns the send action.
            voiceInput.onFinalTranscript = { transcript in
                draft = transcript
                inputFocused = true
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
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                Text(headerEyebrow)
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                voiceModeToggle
                if !store.messages.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            store.clearThread()
                            // Drop any un-acted goal proposal so a wiped thread
                            // doesn't carry a stale intent into the next turn.
                            pendingGoalIntent = nil
                        } label: {
                            Label("Clear thread", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Thread options")
                }
            }
            HStack(spacing: isHeaderCompact ? Spacing.sm : Spacing.md) {
                NoumCharacter(
                    // `.thinking` reads more accurately than `.listening`
                    // here — the user just sent a message; the orb is
                    // composing a reply, not actively hearing audio.
                    // Distinct visuals separate "Noum is reading what
                    // you said" from "Noum is hearing you in a rep."
                    // The orb shrinks but never disappears when the header
                    // collapses, so the coach stays embodied even compact —
                    // and its `.thinking` mood keeps signalling an in-flight
                    // reply once the subtitle is gone.
                    mood: store.isAwaitingReply ? .thinking : .calm,
                    tint: AppColor.pro,
                    size: isHeaderCompact ? 28 : 60,
                    stage: characterStage
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Noum")
                        // Hardcoded 22pt swapped for the shared type scale:
                        // cardTitle (20) at rest, headline (18) when compact.
                        .font(isHeaderCompact ? Typography.headline : Typography.cardTitle)
                    if !isHeaderCompact {
                        Text(headerSubtitle)
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                Spacer()
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isHeaderCompact)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(AppColor.cardBackground.opacity(0.5))
    }

    // MARK: - Voice-mode toggle (S5)
    //
    // A real, persisted, default-OFF control — never a dead toggle. It only
    // renders when the TTS layer can actually produce audio
    // (`speaker.canSpeakReplies`): with no cloud provider configured the
    // affordance HIDES rather than offering a switch that silently no-ops,
    // mirroring `AskNoumVoiceInput.isAvailable` discipline for the mic. When
    // ON, freshly-landed coach replies are spoken (gated again on locale +
    // real-reply at the speak site). Turning it OFF mid-speech stops the
    // current clip immediately so the coach goes quiet the instant the user
    // asks for text-only.
    @ViewBuilder
    private var voiceModeToggle: some View {
        if speaker.canSpeakReplies {
            let isOn = voiceSettings.askNoumSpokenRepliesEnabled
            Button {
                CoachHaptic.selectionTap()
                let newValue = !isOn
                voiceSettings.askNoumSpokenRepliesEnabled = newValue
                // Turning voice OFF should silence any reply still playing —
                // the user just asked for text-only; honor it immediately.
                if !newValue {
                    speaker.stop()
                }
            } label: {
                Image(systemName: isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOn ? AppColor.brandBlue : .secondary)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(isOn ? "Spoken replies on" : "Spoken replies off")
            .accessibilityHint(isOn
                               ? "Double-tap to switch the coach to text only"
                               : "Double-tap to let the coach speak replies aloud")
            .accessibilityIdentifier("askNoum.voiceModeToggle")
        }
    }

    private var headerEyebrow: String {
        if let voice = voice {
            return "Ask Noum \u{00B7} \(voice.title)"
        }
        return "Ask Noum"
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
        if let voice = voice {
            return "Your \(voice.title.lowercased()) coach."
        }
        return "Your speaking coach."
    }

    // MARK: - Empty state (starter prompts)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Calmer framing — coach voice. Set context for the user
            // about what this surface is FOR before they have to make
            // the first move.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(emptyStateHeadline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                Text(emptyStateBody)
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Case-review priority chip — only renders when the active
            // intervention has reached its review threshold. Conditional
            // sibling to `InterventionReviewPromptCard` on SummaryView,
            // wired below the empty-state intro so a user who lands in
            // Ask Noum directly (not through the post-rep flow) still
            // gets a one-tap entry into the same case-review conversation.
            caseReviewStarterChip

            Text("Starters")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.top, Spacing.xs)

            VStack(spacing: Spacing.sm) {
                ForEach(displayedStarters, id: \.self) { prompt in
                    Button {
                        send(prompt)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right.circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColor.pro)
                            Text(prompt)
                                .font(Typography.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
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
                                .stroke(AppColor.pro.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(prompt)
                }
            }
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

    private var emptyStateHeadline: String {
        if let voice = voice {
            return "Coaching your \(voice.title.lowercased())."
        }
        return "Your coaching thread."
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
            return "Ask about your delivery, plan an upcoming pitch, or get a verdict on this week's data. I read your last 30 days before every reply."
        case .warm:
            return "Tell me about your speaking week — what felt natural, what didn't. I'll help you find the moves that read as warmer."
        case .concise:
            return "Ask short questions, get short answers. I read your last 30 days before every reply."
        case .persuasive:
            return "Tell me what you're trying to convince someone of. I'll work backwards from there to the move you need to make."
        case .executive:
            return "Top-line first. Tell me what's on the calendar; I'll give you a read on the moves that matter."
        case .storytelling:
            return "Where are you in your speaking arc this week? I read your last 30 days before every reply, then I'll help you find the next chapter."
        case .none:
            return "Ask me anything about your speaking practice. I read your goal, baseline, and last 30 days before every reply."
        }
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
        // Prefer cached AI chips for this coach reply. Falls back to the
        // deterministic catalog if the cache hasn't hydrated yet (request
        // in flight) or the AI returned nil (provider cold / locale /
        // failure).
        if let cached = store.aiChips(for: last.id), !cached.isEmpty {
            return cached
        }
        return CoachContextBuilder.followUpSuggestions(
            forCoachReply: last.text,
            voice: voice
        )
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

    /// The one mode-launch card — a calm, single CTA that pushes the matching
    /// practice destination onto the shared stack. Reuses AppDestination
    /// routing; no parallel navigation.
    private func modeLaunchRow(destination: AppDestination) -> some View {
        Button {
            CoachHaptic.selectionTap()
            navigationPath.append(destination)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(Typography.caption.weight(.semibold))
                Text(AskNoumModeSuggestion.label(for: destination))
                    .font(Typography.caption.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(AppColor.pro)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.pro.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(AppColor.pro.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
        .accessibilityIdentifier("askNoum.modeLaunch")
        .accessibilityLabel(AskNoumModeSuggestion.label(for: destination))
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

    /// The deterministic data-grounded starters. Always non-empty; this is
    /// both the instant skeleton and the final fallback.
    private var deterministicStarters: [String] {
        CoachContextBuilder.starterPrompts(
            bigMoment: bigMomentStore.activeMoment,
            baseline: baselineStore.baseline,
            voice: voice
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
        return "\(voicePart)|\(momentPart)|\(weakPart)"
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
    // user turn can only begin with one opener lead. The UI layer doesn't
    // need a tiebreaker — both rows can sit back-to-back in the body and
    // only one will ever render for a given coach reply.
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

    private func followUpRow(chips: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Keep going")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .accessibilityHidden(true)

            // Wrapping flow — chips lay out horizontally and wrap onto
            // a second row when the screen can't hold them all. Three
            // chips on a regular-width iPhone usually fit on one row;
            // smaller widths break naturally without truncating the
            // copy. Reuses the `FlowLayout` already defined for the
            // AIWeeklyInsightCard evidence pills so the chip rhythm
            // matches that surface visually.
            FlowLayout(spacing: 8, runSpacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        send(chip)
                    } label: {
                        Text(chip)
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(AppColor.pro)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                AppColor.cardBackground,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.pro.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Follow up: \(chip)")
                }
            }
        }
        .padding(.top, 2)
        .padding(.bottom, Spacing.xs)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Message rows

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
                .font(Typography.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
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
        VStack(alignment: .leading, spacing: 4) {
            if message.isPending {
                pendingDots
                    .padding(.vertical, 4)
            } else {
                Text(message.text)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Noum: \(message.text)")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.10), lineWidth: 1)
        )
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

    // MARK: - Insights caption (M15 Phase 5)
    //
    // Ambient signal that the coach has banked N proof moments about
    // you. Reads `ProofMomentStore.shared.records.count` directly — no
    // new store, no tap-through, no animation. Hidden when the archive
    // is empty so we never render "0 insights" or any "you lost your
    // streak" loss-aversion copy. VISION.md anti-goal #2.
    @ViewBuilder
    private var insightsCaption: some View {
        let count = proofStore.records.count
        if count > 0 {
            let noun = count == 1 ? "insight" : "insights"
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption2)
                    .foregroundStyle(AppColor.pro.opacity(0.75))
                Text("\(count) \(noun) banked")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(count) \(noun) banked.")
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            micNoticeRow
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
            switch mode {
            case .send, .sendOnly:
                trySend()
            case .speaking:
                // S5 — the control is the Stop affordance while the coach
                // speaks. Tap silences the current reply; the input returns to
                // its resting mic/send state on the next frame.
                CoachHaptic.selectionTap()
                speaker.stop()
            case .mic, .recording, .processing:
                CoachHaptic.selectionTap()
                // S5 — barge-in: silence any in-flight coach speech the moment
                // the user reaches for the mic, so the synthesizer never fights
                // the recognizer (same discipline as the rep views stopping TTS
                // on `.userTurnWaiting`).
                speaker.stop()
                voiceInput.toggle()
            }
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
    /// transcript lands in the chat thread as a user turn (same path
    /// as typed messages) and the preview's job is done.
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
        if voiceInput.isAvailable {
            // A5 voice-first: lead with talking; typing is the fallback.
            return "Tap the mic to talk \u{2014} or type\u{2026}"
        }
        return "Message Noum\u{2026}"
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
            return "Recording — tap to stop and send"
        case .processing:
            return "Processing your message"
        }
    }

    private var canSend: Bool {
        // Send is active when there's draft text OR when recording is live
        // (tapping Send while recording stops and sends the current transcript).
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
         || voiceInput.state == .recording)
        && !store.isAwaitingReply
    }

    // MARK: - Send + scroll

    private func trySend() {
        // If recording is active, stop-and-send: the transcript will land
        // in `draft` via `onFinalTranscript`, then we forward it.
        if voiceInput.state == .recording {
            voiceInput.stopAndSend()
            // Transcript arrival is async (recognizer callback); the user
            // will see the draft populate then can tap Send a second time,
            // OR we wait for the transcript here. Since `onFinalTranscript`
            // sets `draft`, the next user-tap of Send picks it up naturally.
            // This keeps the code path simple without racing the recognizer.
            return
        }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !store.isAwaitingReply else { return }
        draft = ""
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
        let systemPrompt = CoachContextBuilder.systemPrompt(for: coachingProfileStore.profile)
        // Run the trend analyzer at call time — cheap pure work over the
        // current snapshot store. Lets the coach quote direction
        // ("filler reduction declining for 3 weeks") not just the noun
        // labels in baseline strengths/blockers.
        let snapshots = SkillTrendStore.shared.snapshots
        let trends = TrendAnalyzer.analyze(snapshots: snapshots)
        let context = CoachContextBuilder.userContext(
            profile: coachingProfileStore.profile,
            baseline: baselineStore.baseline,
            rating: ratingStore.rating,
            sessions: sessionStore.sessions,
            currentStreak: streakFreezeManager.currentStreak,
            pathStatus: pathProgress.currentNode,
            pathGatingPhrase: pathProgress.currentNodeGatingPhrase,
            recentProofs: proofStore.recent(limit: 3),
            bigMoment: bigMomentStore.activeMoment,
            recentMomentOutcomes: bigMomentStore.recentOutcomeReports(limit: 2),
            forwardPlan: forwardPlanStore.activePlan,
            latestRepNote: postRepCoachNoteStore.latestNote(),
            coachMemory: coachMemoryStore.currentMemory,
            pendingRecommendation: recommendationLearningStore.pendingExposure,
            recommendationOutcomes: recommendationLearningStore.outcomes,
            trends: trends,
            latestSnapshot: snapshots.last,
            snapshotsForTrends: snapshots,
            // S3 — the detected set/change intent for THIS turn (if any). Makes
            // the coach PROPOSE the voice in prose ("want me to set that?" /
            // name the trade-off on a change) while the goal card under the
            // reply carries the explicit confirm. The model never writes; this
            // only shapes the reply's framing.
            pendingGoalIntent: pendingGoalIntent,
            // F1 — surface the most-recent weekly check-in so the coach can
            // ask a sharper follow-up grounded in the user's own words.
            recentCheckIns: CoachCheckInStore.shared.recentForContext(limit: 2)
        )
        // Deterministic-fallback context (A1). Assembled HERE, in the same
        // main-actor prologue as the `userContext` store reads above (before any
        // `await`), so an OFFLINE / no-provider / locale-blocked turn still gets
        // a grounded, in-voice coach reply instead of an error notice. Reads the
        // most-recent TIMED rep (the mode the prompt-answer verdict is about)
        // and the already-summarized standing case off the case file — never
        // re-derives, never fabricates. The service ignores this on the live
        // path; it only consumes it on the handled failure paths.
        let recentTimed = sessionStore.sessions.last(where: { $0.mode == .timed })
        let recentTimedWPM: Int = recentTimed.map {
            PracticeEvaluator.paceSnapshot(forTranscript: $0.transcript, duration: $0.duration).wordsPerMinute
        } ?? 0
        let fallbackCaseFile = coachMemoryStore.currentMemory?.caseFile
        let fallbackContext = ChatFallbackContext(
            voice: voice,
            recentTimedTranscript: recentTimed?.transcript,
            recentTimedPrompt: recentTimed?.prompt,
            recentWordsPerMinute: recentTimedWPM,
            recentFillerCount: recentTimed?.fillerWordCount ?? 0,
            hypothesis: fallbackCaseFile?.hypothesis,
            observableTarget: fallbackCaseFile?.observableTarget,
            successMeasure: fallbackCaseFile?.successMeasure,
            nextQuestion: fallbackCaseFile?.nextQuestion
        )
        let history = await MainActor.run { store.replayForModel }
        let outcome = await AICoachChatService.shared.reply(
            history: history,
            systemPrompt: systemPrompt,
            userContext: context,
            fallback: fallbackContext
        )
        await MainActor.run {
            store.completeCoachTurn(id: coachID, outcome: outcome)
            // S5 — spoken coach mode. This is the single chokepoint where a
            // reply becomes visible, so it's the one place the spoken path is
            // triggered. `shouldSpeak` gates on: toggle ON, locale supports AI
            // (non-English stays text-only, mirroring the chat-reply gate), and
            // a real non-empty `.reply` (a `.failure` system notice is NEVER
            // spoken). `speak()` internally `stop()`s any in-flight clip and
            // bumps its generation token, so back-to-back replies stay paired
            // with their own audio. When no TTS provider is configured the
            // toggle is hidden upstream, so this only ever fires when speaking
            // can actually be served; if it somehow fires without a provider,
            // `speak()` records a failure and plays nothing — no raw error
            // reaches the user, and the text reply is already on screen.
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

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .linear(duration: 0.001) : .easeOut(duration: 0.25)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

#endif
