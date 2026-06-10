import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Notification Pre-Prompt
//
// Soft-sell sheet shown before iOS's hard authorization dialog. It frames the
// concrete value of notifications before the system prompt appears.
//
// Trigger: after the user's *first* finished rep (sessionCount == 1). Not
// during onboarding — we want them to have felt the product first.
//
// Persistence (per-account, mirroring StreakFreezeManager / FirstRepCelebration):
// - `noum.notification.prePrompt.seen.<accountID>`        Bool. Accepted path.
//   Once set, never re-shown.
// - `noum.notification.prePrompt.declinedAt.<accountID>`  Date. "Maybe later"
//   path. We respect a 30-day cool-down before the prompt can fire again, then
//   it self-clears so it can be considered again on the next eligible session.
//
// Voice rules (.claude/skills/noum-design):
// - No "Let's", no chirpy copy
// - No emoji in user-facing strings
// - No exclamation marks
// - Concrete value, not vibes — frame around streak protection + weekly read.

#if canImport(SwiftUI)

@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class NotificationPrePromptManager: ObservableObject {
    static let shared = NotificationPrePromptManager()

    /// Set true when the sheet should be presented. ContentView observes this
    /// via `@StateObject` and binds it into a `.sheet(isPresented:)`.
    @Published var pendingPrompt: Bool = false

    private let seenKeyPrefix = "noum.notification.prePrompt.seen."
    private let declinedAtKeyPrefix = "noum.notification.prePrompt.declinedAt."

    /// Cool-down window after a "Maybe later" tap. Mirrors how iOS itself
    /// rate-limits secondary-prompts; long enough that we don't nag.
    private let declinedCooldownDays: Int = 30

    private init() {}

    // MARK: - Account scoping

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private var seenKey: String { seenKeyPrefix + Self.currentAccountID() }
    private var declinedAtKey: String { declinedAtKeyPrefix + Self.currentAccountID() }

    // MARK: - Trigger

    /// Called from `SessionFinalizer` once a session lands. We only fire on
    /// the very first rep (sessionCount == 1). Already-accepted users and
    /// recently-declined users are silently skipped.
    func consider(sessionCount: Int) {
        guard sessionCount == 1 else { return }
        guard !hasAccepted else { return }
        guard !isInDeclinedCooldown else { return }
        guard pendingPrompt == false else { return }
        pendingPrompt = true
    }

    // MARK: - User responses

    /// Primary CTA. Flips on the three daily-rhythm notification surfaces plus
    /// the post-session follow-up, each of which chains into NotificationManager's
    /// authorization request.
    /// Persists "seen" so we never re-show even if the user later toggles
    /// notifications off in Settings.
    func accept() async {
        markAccepted()
        let manager = NotificationManager.shared
        await manager.setStreakWarningEnabled(true)
        await manager.setDailyReminderEnabled(true)
        await manager.setWeeklyDigestEnabled(true)
        // Also arm the +18h post-session follow-up. Without this, the follow-up
        // surface stayed dead for opt-in users — the app went silent after the
        // first rep, the worst outcome for a habit product.
        await manager.setFollowUpEnabled(true)
        pendingPrompt = false
    }

    /// Secondary CTA. Records the decline so we wait `declinedCooldownDays`
    /// before considering the prompt again. We deliberately don't mark "seen" —
    /// "maybe later" is a real intent we should honor by trying again later,
    /// just not soon.
    func decline() {
        UserDefaults.standard.set(Date(), forKey: declinedAtKey)
        pendingPrompt = false
    }

    // MARK: - State queries

    var hasAccepted: Bool {
        UserDefaults.standard.bool(forKey: seenKey)
    }

    var isInDeclinedCooldown: Bool {
        guard let declinedAt = UserDefaults.standard.object(forKey: declinedAtKey) as? Date else {
            return false
        }
        let daysSince = Calendar.current.dateComponents([.day], from: declinedAt, to: Date()).day ?? 0
        return daysSince < declinedCooldownDays
    }

    private func markAccepted() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}

// MARK: - Sheet view

@available(iOS 17.0, macOS 12.0, *)
struct NotificationPrePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasAppeared: Bool = false
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .padding(.bottom, Spacing.xs)

                Text("Noum can nudge you at useful moments")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                bullet(
                    icon: "flame.fill",
                    tint: AppColor.modeSuddenDeath,
                    text: "A quiet evening reminder when you have rhythm and haven't practiced yet."
                )
                bullet(
                    icon: "chart.line.uptrend.xyaxis",
                    tint: AppColor.brandBlue,
                    text: "Weekly read of how your speaking is changing."
                )
                bullet(
                    icon: "hand.raised.fill",
                    tint: AppColor.textSecondary,
                    text: "No marketing, no spam."
                )
            }

            Spacer(minLength: Spacing.sm)

            VStack(spacing: Spacing.sm) {
                PrimaryCTA(
                    "Turn on reminders",
                    icon: "bell.fill",
                    tint: AppColor.brandBlue
                ) {
                    accept()
                }
                .disabled(isSubmitting)

                Button(action: declineAndDismiss) {
                    Text("Maybe later")
                        .font(Typography.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.pressable)
                .disabled(isSubmitting)
                .accessibilityIdentifier("notificationPrePrompt.decline")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 12)
        .animation(.standardSpring, value: hasAppeared)
        .onAppear {
            hasAppeared = true
        }
    }

    private func bullet(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22, alignment: .center)
                .padding(.top, 1)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func accept() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            await NotificationPrePromptManager.shared.accept()
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }

    private func declineAndDismiss() {
        guard !isSubmitting else { return }
        NotificationPrePromptManager.shared.decline()
        dismiss()
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Notification pre-prompt") {
    Color.gray.opacity(0.2)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NotificationPrePromptSheet()
        }
}
#endif

#endif
