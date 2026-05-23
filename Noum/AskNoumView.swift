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
//   • Header: NoumCharacter (full character, voice-tinted glow) + the
//     coach's name eyebrow. Makes the coach feel embodied, not a chatbot.
//   • Empty state (no messages): voice-specific starter prompts as
//     tappable chips. Removes the friction of the first message.
//   • Thread: alternating user (right-aligned brand-blue bubble) +
//     coach (left-aligned card bubble) rows, with the NoumCharacter
//     inline glyph next to each coach reply for continuity.
//   • Input bar: rounded text field + send button. Disabled while a
//     reply is in flight.
//
// Brand alignment: white cards on light background, brand-purple accents
// for the coach surface, NoumCharacter as the coach's embodiment.

@available(iOS 17.0, macOS 12.0, *)
struct AskNoumView: View {
    @StateObject private var store = AskNoumStore.shared
    @ObservedObject var sessionStore: PracticeSessionStore
    @ObservedObject var ratingStore: RatingStore
    @ObservedObject var coachingProfileStore: CoachingProfileStore
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var streakFreezeManager = StreakFreezeManager.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var proofStore = ProofMomentStore.shared
    @StateObject private var bigMomentStore = BigMomentStore.shared
    @StateObject private var forwardPlanStore = ForwardPlanStore.shared

    @State private var draft: String = ""
    @State private var didLandFirstAppear = false
    @FocusState private var inputFocused: Bool

    // Voice input wrapper — shipped in `AskNoumVoiceInput.swift`. Single
    // instance per view so the tap-to-toggle lifecycle owns the audio
    // engine + recognition task. Tap once → start recording; tap again
    // → stop and send. The view reads `state` + `unavailableReason` to
    // drive UI, and calls `toggle()` from the button action.
    @StateObject private var voiceInput = AskNoumVoiceInput()
    @StateObject private var bigMomentStore = BigMomentStore.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var voice: SpeakingStyleGoal? {
        coachingProfileStore.profile?.speakingStyleGoal
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
                        VStack(spacing: Spacing.md) {
                            if store.messages.isEmpty {
                                emptyState
                            } else {
                                ForEach(store.messages) { message in
                                    messageRow(message: message)
                                        .id(message.id)
                                }
                                if let chips = followUpChips, !chips.isEmpty {
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
                    .scrollDismissesKeyboard(.interactively)
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
                if !store.messages.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            store.clearThread()
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
            HStack(spacing: Spacing.md) {
                NoumCharacter(
                    // `.thinking` reads more accurately than `.listening`
                    // here — the user just sent a message; the orb is
                    // composing a reply, not actively hearing audio.
                    // Distinct visuals separate "Noum is reading what
                    // you said" from "Noum is hearing you in a rep."
                    mood: store.isAwaitingReply ? .thinking : .calm,
                    tint: AppColor.pro,
                    size: 60,
                    stage: characterStage
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Noum")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(headerSubtitle)
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background(AppColor.cardBackground.opacity(0.5))
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

            Text("Starters")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.top, Spacing.xs)

            VStack(spacing: Spacing.sm) {
                ForEach(CoachContextBuilder.starterPrompts(
                    bigMoment: bigMomentStore.activeMoment,
                    baseline: baselineStore.baseline,
                    voice: voice
                ), id: \.self) { prompt in
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
    }

    private var emptyStateHeadline: String {
        if let voice = voice {
            return "Coaching your \(voice.title.lowercased())."
        }
        return "Your coaching thread."
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
        Task {
            let generated = await CoachContextBuilder.generateAIFollowUpChips(
                lastUserTurn: lastUserTurn,
                lastCoachReply: coachReply,
                voice: voiceCapture
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

    private func followUpRow(chips: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Keep going")
                .font(Typography.micro.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.leading, 34) // align with coach card body, past inline glyph
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
            .padding(.leading, 34)
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
        HStack(alignment: .top, spacing: 10) {
            // Inline glyph next to every coach reply for continuity.
            // Smaller than the header character; just enough to mark
            // it as the coach speaking.
            NoumCharacter.Inline(size: 24, tint: AppColor.pro, stage: characterStage)
                .padding(.top, 6)
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
            partialTranscriptPreview
            inputBarRow
        }
        .background(.ultraThinMaterial)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: voiceInput.state == .recording)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: voiceInput.partialTranscript)
    }

    private var inputBarRow: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            ZStack(alignment: .leading) {
                if draft.isEmpty {
                    Text(textFieldPlaceholder)
                        .font(Typography.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextField("", text: $draft, axis: .vertical)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
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

            // Send button stays as the typed-text dispatch. When the
            // user has draft text it's the primary action; when empty,
            // it dims and the mic becomes the visual lead.
            Button {
                trySend()
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? AppColor.pro : Color.secondary.opacity(0.20))
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")

            // Voice path — only rendered when the wrapper reports the
            // device + locale + permissions can actually deliver a
            // transcript. Dead-toggle gate: when the wrapper can't
            // serve voice, the mic disappears entirely rather than
            // pretending to work. Typed flow above keeps working.
            if voiceInput.isAvailable {
                micButton
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
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
            return "Message Noum, or tap the mic\u{2026}"
        }
        return "Message Noum\u{2026}"
    }

    // MARK: - Mic button (tap-to-toggle)
    //
    // Tap once → starts recording (halo + waveform pulse).
    // Tap again → stops recording, delivers transcript to the text field,
    //             user can review then tap Send — OR the Send button
    //             itself also stops-and-sends if tapped while recording.
    // No drag-to-cancel: dropped in favour of simplicity. Users can
    // clear the draft text field if they want to discard.
    private var micButton: some View {
        let isRecording = voiceInput.state == .recording
        let isProcessing = voiceInput.state == .processing
        return ZStack {
            if isRecording {
                Circle()
                    .fill(AppColor.brandBlue.opacity(0.18))
                    .frame(width: reduceMotion ? 72 : 84, height: reduceMotion ? 72 : 84)
                    .overlay(
                        Circle()
                            .stroke(AppColor.brandBlue.opacity(0.40), lineWidth: 2)
                    )
                    .transition(.opacity)
            }
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColor.brandBlueLight, AppColor.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .scaleEffect(isRecording && !reduceMotion ? 1.08 : 1.0)
                .shadow(color: AppColor.brandBlue.opacity(isRecording ? 0.35 : 0.18),
                        radius: isRecording ? 10 : 6,
                        x: 0, y: 3)
            Image(systemName: isProcessing ? "waveform" : (isRecording ? "stop.fill" : "mic.fill"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating, isActive: isProcessing && !reduceMotion)
        }
        .frame(width: 72, height: 72)
        .contentShape(Circle())
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.72), value: isRecording)
        .onTapGesture {
            CoachHaptic.selectionTap()
            voiceInput.toggle()
        }
        .accessibilityLabel(micAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .opacity(store.isAwaitingReply ? 0.45 : 1.0)
        .allowsHitTesting(!store.isAwaitingReply)
    }

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

    private func send(_ text: String) {
        let ids = store.appendUserTurn(text)
        Task {
            await runReply(coachID: ids.coachID)
        }
    }

    private func runReply(coachID: UUID) async {
        let systemPrompt = CoachContextBuilder.systemPrompt(for: coachingProfileStore.profile)
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
            forwardPlan: forwardPlanStore.activePlan
        )
        let history = await MainActor.run { store.replayForModel }
        let outcome = await AICoachChatService.shared.reply(
            history: history,
            systemPrompt: systemPrompt,
            userContext: context
        )
        await MainActor.run {
            store.completeCoachTurn(id: coachID, outcome: outcome)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .linear(duration: 0.001) : .easeOut(duration: 0.25)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - Pending pulse modifier (reduce-motion-aware)

@available(iOS 17.0, *)
private struct PendingPulse: ViewModifier {
    let delay: Double
    let reduceMotion: Bool
    @State private var bumped = false

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .scaleEffect(bumped ? 1.4 : 0.8)
                .opacity(bumped ? 1.0 : 0.4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(delay)) {
                        bumped = true
                    }
                }
        }
    }
}

#endif
