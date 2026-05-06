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

/// Fires a lightweight "still your goal?" sheet every 14+ days.
/// The user confirms in one tap or updates their goal text.
/// Never blocks — a skip stamps the date and stays quiet for another 14 days.
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

    private func stamp() {
        UserDefaults.standard.set(Date(), forKey: lastRefreshKey())
    }

    private func lastRefreshKey() -> String {
        lastRefreshKeyPrefix + (AuthManager.shared.currentAccountID ?? "guest")
    }
}

// MARK: - Goal Refresh Sheet

@available(iOS 17.0, macOS 12.0, *)
struct GoalRefreshSheet: View {
    @StateObject private var manager = GoalRefreshManager.shared
    @StateObject private var profileStore = CoachingProfileStore.shared
    @State private var isEditing = false
    @State private var editText: String = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text("Still your goal?")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                Text("Noum stays useful when your goal is current. Confirm or update in 30 seconds.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Current goal display / edit toggle
            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    ZStack(alignment: .topLeading) {
                        if editText.isEmpty {
                            Text("What are you working on right now?")
                                .font(Typography.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        TextEditor(text: $editText)
                            .font(Typography.body)
                            .focused($focused)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minHeight: 100)
                    }
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(focused ? AppColor.brandBlue.opacity(0.4) : Color.white.opacity(0.6), lineWidth: 1)
                    )
                } else {
                    Text(profileStore.profile?.displayableGoal ?? "")
                        .font(Typography.body)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
            }

            Spacer()

            if isEditing {
                HStack {
                    Button("Cancel") {
                        isEditing = false
                        focused = false
                    }
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        manager.update(editText)
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Save goal")
                                .font(Typography.headline)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(
                            editText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
                                ? AppColor.brandBlue : Color.secondary.opacity(0.5),
                            in: Capsule()
                        )
                    }
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                }
            } else {
                HStack(spacing: 12) {
                    Button {
                        if let current = profileStore.profile?.coachingBrief, !current.isEmpty {
                            editText = current
                        }
                        isEditing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true }
                    } label: {
                        Text("Update it")
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    Button {
                        manager.confirm()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                            Text("Still right")
                                .font(Typography.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(AppColor.brandBlue, in: Capsule())
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

#endif
