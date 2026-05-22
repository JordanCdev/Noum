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

    @State private var draft: String = ""
    @State private var didLandFirstAppear = false
    @FocusState private var inputFocused: Bool

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
                    .onChange(of: store.isAwaitingReply) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onAppear {
                        if !didLandFirstAppear {
                            didLandFirstAppear = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                scrollToBottom(proxy: proxy)
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
        if store.isAwaitingReply {
            return "Reading your context\u{2026}"
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
                ForEach(CoachContextBuilder.starterPrompts(for: voice), id: \.self) { prompt in
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
    // most-recent coach reply. Sourced from
    // `CoachContextBuilder.followUpSuggestions(...)` — voice-shaped and
    // anchored on a topic detected in the latest reply (drill / pause /
    // pace / filler / weekly / generic). Tapping fires the same `send`
    // path as the starter prompts, so the chip text lands as the user's
    // next turn and the coach replies normally.
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
        return CoachContextBuilder.followUpSuggestions(
            forCoachReply: last.text,
            voice: voice
        )
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
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            ZStack(alignment: .leading) {
                if draft.isEmpty {
                    Text("Message Noum\u{2026}")
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
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !store.isAwaitingReply
    }

    // MARK: - Send + scroll

    private func trySend() {
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
            recentProofs: proofStore.recent(limit: 3)
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
