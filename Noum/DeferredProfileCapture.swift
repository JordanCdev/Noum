#if canImport(SwiftUI)
import SwiftUI

// MARK: - Deferred Profile Capture
//
// Now that onboarding is 3 multi-choice screens (no free-text), the goal /
// why-now / success-vision questions get asked *after* the user has done a
// rep — when answering them costs nothing because they've already
// experienced the product. Pattern lifted from how Threads / Notion / good
// onboarding flows ask for personal info post-value.
//
// Triggers:
// 1. After session 1: ask "What do you want to get better at?"
// 2. After session 3: ask "Why does this matter right now?"
// 3. After session 7: ask "If this improves, what changes?"
//
// Each prompt is skippable. We never block the user. Captured text goes
// into the existing CoachingProfile fields (`coachingBrief`, `motivationWhyNow`,
// `successVision`) and is then used by the AI insight prompt + coaching
// debrief copy.

@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class DeferredProfileCaptureManager: ObservableObject {
    static let shared = DeferredProfileCaptureManager()

    @Published var pendingPrompt: Prompt?

    private let seenKeyPrefix = "noum.deferredCapture.seen."

    private init() {}

    enum Prompt: Identifiable, Equatable {
        case goal
        case whyNow
        case successVision

        var id: String {
            switch self {
            case .goal:          return "goal"
            case .whyNow:        return "whyNow"
            case .successVision: return "successVision"
            }
        }

        var headline: String {
            switch self {
            case .goal:          return "What do you want to get better at?"
            case .whyNow:        return "Why does this matter right now?"
            case .successVision: return "If this improves, what changes?"
            }
        }

        var hint: String {
            switch self {
            case .goal:
                return "One sentence is enough. Specific beats impressive."
            case .whyNow:
                return "Tell Noum the current stakes."
            case .successVision:
                return "Keep it concrete and personal."
            }
        }

        var placeholder: String {
            switch self {
            case .goal:
                return "Lead updates in meetings without second-guessing every sentence."
            case .whyNow:
                return "I need to sound sharper in high-visibility conversations."
            case .successVision:
                return "I will feel calmer, clearer, and more credible at work."
            }
        }

        var minLength: Int {
            switch self {
            case .goal:          return 10
            case .whyNow:        return 8
            case .successVision: return 8
            }
        }

        /// Session count at which this prompt is offered, if it hasn't
        /// been seen yet.
        var triggerCount: Int {
            switch self {
            case .goal:          return 1
            case .whyNow:        return 3
            case .successVision: return 7
            }
        }
    }

    /// Called from `SessionFinalizer` after a session lands. Picks the
    /// appropriate prompt for the user's session count, if any. Skips
    /// prompts the user has already seen or already answered in onboarding.
    func consider(sessionCount: Int, profile: CoachingProfile?) {
        guard sessionCount > 0 else { return }
        // A user may enter the shell after the permissionless first-value
        // exercise while their full CoachingProfile is still deferred. A
        // later spoken rep must not schedule a prompt whose submit path has no
        // profile to update; the quiet setup-resume card owns that state.
        guard profile != nil else { return }
        guard pendingPrompt == nil else { return }

        // Pick the highest-priority unseen prompt that matches the
        // session count. We bias toward the goal prompt fired earliest.
        let candidates: [Prompt] = [.goal, .whyNow, .successVision]
        for prompt in candidates {
            guard sessionCount >= prompt.triggerCount else { continue }
            guard !hasSeen(prompt) else { continue }
            guard !alreadyAnswered(prompt, profile: profile) else { continue }
            pendingPrompt = prompt
            return
        }
    }

    /// Save what the user typed and dismiss the prompt. Empty input
    /// counts as "skipped" — the prompt is marked seen but the field
    /// isn't overwritten with empty text.
    func submit(_ text: String, for prompt: Prompt) {
        markSeen(prompt)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= prompt.minLength else {
            pendingPrompt = nil
            return
        }

        let store = CoachingProfileStore.shared
        guard var profile = store.profile else {
            pendingPrompt = nil
            return
        }
        switch prompt {
        case .goal:
            profile.coachingBrief = trimmed
        case .whyNow:
            profile.motivationWhyNow = trimmed
        case .successVision:
            profile.successVision = trimmed
        }
        store.save(profile)
        pendingPrompt = nil
    }

    func skip(_ prompt: Prompt) {
        markSeen(prompt)
        pendingPrompt = nil
    }

    // MARK: - Persistence

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private func seenKey(for prompt: Prompt) -> String {
        seenKeyPrefix + prompt.id + "." + Self.currentAccountID()
    }

    private func hasSeen(_ prompt: Prompt) -> Bool {
        UserDefaults.standard.bool(forKey: seenKey(for: prompt))
    }

    private func markSeen(_ prompt: Prompt) {
        UserDefaults.standard.set(true, forKey: seenKey(for: prompt))
    }

    #if DEBUG
    func resetForUITesting() {
        for prompt in [Prompt.goal, .whyNow, .successVision] {
            UserDefaults.standard.removeObject(forKey: seenKey(for: prompt))
        }
        pendingPrompt = nil
    }
    #endif

    /// Already filled in via onboarding (legacy users) or a prior prompt.
    private func alreadyAnswered(_ prompt: Prompt, profile: CoachingProfile?) -> Bool {
        guard let profile else { return false }
        switch prompt {
        case .goal:
            return !profile.coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .whyNow:
            return !profile.motivationWhyNow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .successVision:
            return !profile.successVision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - Sheet view

@available(iOS 17.0, macOS 12.0, *)
struct DeferredProfileCaptureSheet: View {
    let prompt: DeferredProfileCaptureManager.Prompt
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 8) {
                Text(prompt.headline)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(prompt.hint)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(prompt.placeholder)
                        .font(Typography.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $text)
                    .font(Typography.body)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 120)
            }
            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isFocused ? AppColor.brandBlue.opacity(0.4) : Color.white.opacity(0.6), lineWidth: 1)
            )

            Spacer()

            HStack {
                Button(action: skip) {
                    Text("Maybe later")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: submit) {
                    HStack(spacing: 6) {
                        Text("Save")
                            .font(Typography.headline)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        canSubmit ? AppColor.brandBlue : Color.secondary.opacity(0.5),
                        in: Capsule()
                    )
                }
                .disabled(!canSubmit)
                .accessibilityIdentifier("deferredCapture.save")
            }
        }
        .padding(Spacing.lg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    private var canSubmit: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= prompt.minLength
    }

    private func submit() {
        DeferredProfileCaptureManager.shared.submit(text, for: prompt)
        dismiss()
    }

    private func skip() {
        DeferredProfileCaptureManager.shared.skip(prompt)
        dismiss()
    }
}

// MARK: - Goal Refresh (recurring 2-week cadence)

/// Fires a lightweight direction check every 14+ days.
/// The user confirms in one tap or updates their goal text.
/// Never blocks: a skip stamps the date and stays quiet for another 14 days.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class GoalRefreshManager: ObservableObject {
    static let shared = GoalRefreshManager()

    @Published var shouldPresent = false

    private let lastRefreshKeyPrefix = "noum.goalRefresh.lastDate."
    private let minimumSessionsBeforeRefresh = 10
    private let refreshIntervalDays = 14

    private init() {}

    /// Called from SessionFinalizer after each finished rep.
    func consider(sessionCount: Int, profile: CoachingProfile?) {
        guard !shouldPresent else { return }
        guard let profile, !profile.coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard sessionCount >= minimumSessionsBeforeRefresh else { return }

        let key = lastRefreshKey()
        if let lastDate = UserDefaults.standard.object(forKey: key) as? Date {
            let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            guard days >= refreshIntervalDays else { return }
        } else {
            // First refresh — trigger if they have enough sessions but never refreshed.
            guard sessionCount >= 20 else { return }
        }

        shouldPresent = true
    }

    /// User confirmed their goal is still correct — stamp date, no edit.
    func confirm() {
        stamp()
        shouldPresent = false
    }

    /// User submitted an updated goal text.
    func update(_ newGoal: String) {
        stamp()
        let trimmed = newGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { shouldPresent = false; return }
        let store = CoachingProfileStore.shared
        guard var profile = store.profile else { shouldPresent = false; return }
        profile.coachingBrief = trimmed
        profile.paraphrasedGoal = nil  // re-trigger paraphrase pass with new text
        store.save(profile)
        shouldPresent = false
    }

    func skip() {
        stamp()
        shouldPresent = false
    }

    /// Manual entry point from surfaces that already show the user's "why".
    /// It deliberately uses the same `shouldPresent` state as the cadence so
    /// Home, Path, and tests all observe one owner.
    func requestReview() {
        guard !shouldPresent else { return }
        guard CoachingProfileStore.shared.profile != nil else { return }
        shouldPresent = true
    }

    static func canSubmit(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    private func stamp() {
        UserDefaults.standard.set(Date(), forKey: lastRefreshKey())
    }

    private func lastRefreshKey() -> String {
        lastRefreshKeyPrefix + (AuthManager.shared.currentAccountID ?? "guest")
    }
}

// MARK: - Goal Refresh Inline Card

@available(iOS 17.0, macOS 12.0, *)
struct GoalRefreshInlineCard: View {
    @StateObject private var manager = GoalRefreshManager.shared
    @StateObject private var profileStore = CoachingProfileStore.shared
    @State private var isEditing = false
    @State private var editText: String = ""
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if manager.shouldPresent {
            content
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityIdentifier("goalRefresh.card")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if isEditing {
                editor
            } else {
                currentDirection
                confirmationActions
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    AppColor.brandBlue.opacity(0.065),
                    AppColor.brandBlueLight.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.18), lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .accessibilityHidden(true)

                Text("Direction check")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                Button {
                    closeInline { manager.skip() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss direction check")
                .accessibilityIdentifier("goalRefresh.skip")
            }

            Text("Is this still the conversation you want Noum to train for?")
                .font(Typography.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("A good coach recalibrates before prescribing. If the real target moved, update it here.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentDirection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current direction")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(currentGoal)
                .font(Typography.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Token, not near-white: this panel shows the user's own goal in
        // `.primary` ink, which resolves to white in Dark appearance. A fixed
        // white fill made their goal unreadable on their own screen.
        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current direction, \(currentGoal)")
    }

    private var confirmationActions: some View {
        HStack(spacing: 12) {
            Button {
                beginEditing()
            } label: {
                Label("Adjust", systemImage: "pencil.line")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColor.brandBlue.opacity(0.10), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("goalRefresh.edit")

            Spacer(minLength: 12)

            Button {
                closeInline { manager.confirm() }
            } label: {
                Label("Still right", systemImage: "checkmark")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(AppColor.brandBlue, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("goalRefresh.confirm")
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if editText.isEmpty {
                    Text("What should Noum keep in mind now?")
                        .font(Typography.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $editText)
                    .font(Typography.body)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 104)
                    .accessibilityIdentifier("goalRefresh.editor")
            }
            // Matches the identical composite at line 237. A fixed white fill
            // here meant a Dark-appearance user could not read what they were
            // typing into their own goal-refresh box.
            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(focused ? AppColor.brandBlue.opacity(0.40) : AppColor.brandBlue.opacity(0.16), lineWidth: 1)
            )

            HStack(spacing: 12) {
                Button {
                    editText = ""
                    focused = false
                    animate { isEditing = false }
                } label: {
                    Text("Keep current")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 12)

                Button {
                    closeInline { manager.update(editText) }
                } label: {
                    Label("Save direction", systemImage: "checkmark")
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            GoalRefreshManager.canSubmit(editText)
                                ? AppColor.brandBlue
                                : Color.secondary.opacity(0.50),
                            in: Capsule(style: .continuous)
                        )
                }
                .disabled(!GoalRefreshManager.canSubmit(editText))
                .buttonStyle(.plain)
                .accessibilityIdentifier("goalRefresh.save")
            }
        }
    }

    private var currentGoal: String {
        guard let profile = profileStore.profile else { return "Your current coaching direction." }
        let displayable = profile.displayableGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayable.isEmpty { return displayable }
        return profile.primaryGoal.title
    }

    private func beginEditing() {
        let current = profileStore.profile?.coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        editText = current.isEmpty ? currentGoal : current
        animate { isEditing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true }
    }

    private func closeInline(_ action: @escaping () -> Void) {
        focused = false
        if reduceMotion {
            action()
            isEditing = false
        } else {
            withAnimation(.easeInOut(duration: 0.20)) {
                action()
                isEditing = false
            }
        }
    }

    private func animate(_ updates: @escaping () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.standardSpring, updates)
        }
    }
}

#endif
