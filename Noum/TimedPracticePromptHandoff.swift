import Foundation

/// Process-local, account-bound handoff into Timed Practice.
///
/// The old implementation wrote user-authored prompts to one global
/// `UserDefaults` key. A route cancellation or app termination could leave that
/// text for a later account. This owner intentionally keeps at most one prompt
/// in memory, binds it to the account and exact route that created it, consumes
/// it once, and is cleared during account teardown. It is not another content
/// archive.
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class TimedPracticePromptHandoff {
    static let shared = TimedPracticePromptHandoff()
    nonisolated static let legacyDefaultsKey = "timedPractice.suggestedPrompt"
    nonisolated static let legacySuggestedWordDefaultsKey = "timedPractice.suggestedWord"
    nonisolated static let maximumPromptCharacters = 1_000

    private struct PendingPrompt: Equatable {
        let token: UUID
        let accountID: String
        let text: String
    }

    private var pending: PendingPrompt?
    private let accountIDProvider: () -> String?

    init(accountIDProvider: (() -> String?)? = nil) {
        self.accountIDProvider = accountIDProvider ?? {
            KeychainHelper.load(key: "NoumAccountID")
        }
        // Remove the historical unscoped content key on first use of the new
        // owner. It is never migrated because its account provenance is
        // unknowable.
        UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
        UserDefaults.standard.removeObject(
            forKey: Self.legacySuggestedWordDefaultsKey
        )
    }

    /// Prepare one route-bound prompt. The token is safe to carry in local
    /// navigation state because it contains no prompt content or account
    /// identifier. A Timed route must present this exact token to consume the
    /// value, so an abandoned or delayed route cannot steal a newer prompt.
    func offerToken(_ text: String) -> UUID? {
        offerToken(text, accountID: accountIDProvider())
    }

    func offerToken(_ text: String, accountID: String?) -> UUID? {
        guard let accountID = normalizedAccountID(accountID),
              let text = normalizedPrompt(text) else {
            pending = nil
            return nil
        }
        let token = UUID()
        pending = PendingPrompt(token: token, accountID: accountID, text: text)
        return token
    }

    /// Return the prompt exactly once for its route and active account. An
    /// account mismatch clears the pending value instead of retaining
    /// cross-account content for a later switch-back. A token mismatch leaves
    /// a newer pending route intact.
    func consume(token: UUID) -> String? {
        consume(token: token, accountID: accountIDProvider())
    }

    func consume(token: UUID, accountID: String?) -> String? {
        guard let accountID = normalizedAccountID(accountID) else {
            self.pending = nil
            return nil
        }
        guard let pending else { return nil }
        guard pending.accountID == accountID else {
            self.pending = nil
            return nil
        }
        guard pending.token == token else { return nil }
        self.pending = nil
        return pending.text
    }

    func pendingPrompt(accountID: String?) -> String? {
        guard let accountID = normalizedAccountID(accountID),
              pending?.accountID == accountID else {
            return nil
        }
        return pending?.text
    }

    func clear() {
        pending = nil
        UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
        UserDefaults.standard.removeObject(
            forKey: Self.legacySuggestedWordDefaultsKey
        )
    }

    private func normalizedAccountID(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedPrompt(_ value: String) -> String? {
        let normalized = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return String(normalized.prefix(Self.maximumPromptCharacters))
    }
}
