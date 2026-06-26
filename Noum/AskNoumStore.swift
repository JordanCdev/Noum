#if canImport(SwiftUI)
import Foundation
import Combine
#if canImport(Security)
import Security
#endif

// MARK: - Ask Noum chat message + store
//
// The user's persistent thread with their AI coach. Distinct from the
// IM mode's conversation partner: this is the user *talking to Noum
// about their speaking practice*, not an NPC conversation rep. The
// thread persists per-account and survives app restarts so the user
// can come back to an ongoing coaching dialogue.
//
// Design rules:
//   • Per-account persistence — same convention as every other
//     UserDefaults-backed store (`<key>.<accountID>`). Switching
//     accounts shows that account's thread; a fresh sign-in is a
//     fresh blank thread.
//   • Bounded history — cap at 40 messages on disk. Older messages
//     drop off the top. Keeps the persisted blob small and protects
//     the model's context window from runaway growth.
//   • Idempotent send tracking — every user-authored message gets a
//     UUID at send-time so retries can dedupe and the UI can render
//     a "pending" state without flickering identity.
//   • No backend sync — chat lives on-device. Adding Firestore sync
//     would be a future move; today the priority is "feel intimate"
//     and on-device-only achieves that with zero infra.

/// Direction / authorship of a chat message.
enum CoachMessageRole: String, Codable, Equatable {
    case user
    case coach
    /// A "system" notice rendered in-thread (e.g. "Coach paused — \
    /// configure an AI provider to continue"). Not sent to the model.
    case systemNotice
}

/// One message in the Ask-Noum thread.
struct CoachMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: CoachMessageRole
    let text: String
    let createdAt: Date
    /// True while the model is generating the reply. Only ever true for
    /// `.coach` rows; the UI renders a typing-style placeholder for these.
    var isPending: Bool

    init(
        id: UUID = UUID(),
        role: CoachMessageRole,
        text: String,
        createdAt: Date = Date(),
        isPending: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.isPending = isPending
    }
}

/// Persisted thread + send / replay surface for the Ask-Noum chat.
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class AskNoumStore: ObservableObject {

    static let shared = AskNoumStore()

    /// Cap on the number of messages held on disk. Older messages drop
    /// off the front when the cap is exceeded. 40 covers ~20 turns of
    /// conversation, which is plenty for coaching continuity without
    /// blowing the model's context window on replay.
    private static let maxStoredMessages = 40

    /// Storage key prefix. Joined with the account ID the same way
    /// every other per-account value is keyed.
    private static let storagePrefix = "askNoum.thread"

    @Published private(set) var messages: [CoachMessage] = []

    /// True while a `coach` reply is mid-flight. UI uses this to
    /// disable the input bar and show the pending message row.
    @Published private(set) var isAwaitingReply: Bool = false

    /// AI-tailored follow-up chips keyed by the coach message ID they
    /// belong to. Lets `AskNoumView` request chips once per reply, cache
    /// the result, and read it back synchronously on every view rebuild
    /// without re-rolling the generation request (which would burn
    /// tokens + jitter the chip text under the user's finger).
    ///
    /// In-memory only — chips are conversational ephemera tied to the
    /// current view session. A relaunched app starts fresh; the cost
    /// is one re-roll on the very last reply, the win is no persistence
    /// surface dragging stale model output across sessions.
    ///
    /// Cleared by `clearThread()` so a thread-wipe doesn't leave
    /// orphaned chip data for IDs that no longer exist.
    @Published private(set) var aiChipsCache: [UUID: [String]] = [:]

    /// AI-tailored EMPTY-STATE starter prompts, cached against a stable
    /// signature of the inputs that shape them (chosen voice + active
    /// BigMoment + weakest baseline dimension). Unlike `aiChipsCache`,
    /// which keys by coach message ID, the starter row is a single
    /// pre-conversation surface — one cached set at a time. Keying by a
    /// signature means a voice change / a new upcoming moment / a shifted
    /// weakest dimension re-rolls the starters, while idle re-renders
    /// (keyboard focus, scroll) reuse the cached set without re-rolling
    /// the generation request.
    ///
    /// In-memory only — same rationale as `aiChipsCache`: starters are
    /// pre-conversation ephemera, not a persistence surface. A relaunch
    /// re-rolls once against the deterministic catalog skeleton.
    ///
    /// Cleared by `clearThread()` alongside the reply chip cache.
    @Published private(set) var starterChipsCache: [String: [String]] = [:]

    /// Set by `injectUserTurn(_:)` when a different surface (e.g. the
    /// post-session Summary's "Talk to your coach about this rep" CTA)
    /// drops a seed message into the thread *before* AskNoumView has
    /// mounted. AskNoumView consumes this on appear and triggers the
    /// coach reply for the matching pending row. Nil at rest.
    ///
    /// Why this lives on the store rather than as a parameter on
    /// AskNoumView's init: the inject + the navigation push are two
    /// independent events that must survive the gap between them
    /// (the user tapping the bridge → SwiftUI mounting AskNoumView).
    /// A published store property bridges that gap without forcing the
    /// caller to know about AskNoumView's lifecycle.
    @Published private(set) var pendingInjectedCoachID: UUID? = nil

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        if let provider = accountIDProvider {
            self.accountIDProvider = provider
        } else {
            self.accountIDProvider = { Self.defaultAccountIDProvider() }
        }
        loadFromDisk()
    }

    /// Append a user-authored message + a pending coach row. Returns
    /// the IDs of both so the caller can hydrate the coach row once
    /// the service returns.
    @discardableResult
    func appendUserTurn(_ text: String) -> (userID: UUID, coachID: UUID) {
        let userMsg = CoachMessage(role: .user, text: text)
        let coachMsg = CoachMessage(role: .coach, text: "", isPending: true)
        messages.append(userMsg)
        messages.append(coachMsg)
        isAwaitingReply = true
        trimAndPersist()
        return (userMsg.id, coachMsg.id)
    }

    /// Hydrate the pending coach row once the service returns. On
    /// `.reply` the placeholder becomes a coach bubble; on `.failure`
    /// it becomes a system notice with cause-specific copy so the user
    /// knows what to actually fix (locale, network, provider, prompt)
    /// instead of being told to "check Settings" no matter what broke.
    func completeCoachTurn(id: UUID, outcome: ChatOutcome) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        switch outcome {
        case .reply(let text), .deterministicReply(let text):
            // A live `.reply` and a grounded `.deterministicReply` both render
            // as a real coach bubble — the deterministic offline line is the
            // coach answering, NOT a system notice. (The spoken path treats
            // them differently — see `AskNoumSpokenMode.shouldSpeak` — because
            // a canned line must never be read aloud as the live coach.)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                // Defensive: neither path should hand us empty content (a live
                // empty returns `.failure(.empty)`; the deterministic builder
                // is total and always non-empty), but if it does, route through
                // the same notice rather than leaving a blank bubble.
                replaceWithNotice(at: idx, id: id, failure: .empty)
            } else {
                messages[idx] = CoachMessage(
                    id: id,
                    role: .coach,
                    text: trimmed,
                    createdAt: messages[idx].createdAt,
                    isPending: false
                )
            }
        case .failure(let failure):
            replaceWithNotice(at: idx, id: id, failure: failure)
        }
        isAwaitingReply = false
        trimAndPersist()
    }

    private func replaceWithNotice(at idx: Int, id: UUID, failure: ChatFailure) {
        messages[idx] = CoachMessage(
            id: id,
            role: .systemNotice,
            text: Self.noticeCopy(for: failure),
            createdAt: messages[idx].createdAt,
            isPending: false
        )
    }

    /// User-facing copy per failure cause. First-person voice (Noum),
    /// sentence case, no exclamation marks, action-oriented — matches
    /// the coach voice rules used everywhere else.
    private static func noticeCopy(for failure: ChatFailure) -> String {
        switch failure {
        case .noProvider:
            return "Coaching chat is unavailable — no AI provider is set up. Add a key in Settings to turn it on."
        case .localeUnsupported:
            return "I can only chat in English right now. Switch practice locale in Settings to continue."
        case .network:
            return "Coaching chat is unavailable right now — I couldn't reach the model. Try again in a moment."
        case .empty:
            return "I came up empty on that one. Try rephrasing."
        }
    }

    /// Cancel an in-flight coach reply (user navigated away, etc.).
    /// Drops the pending row entirely so the thread doesn't show a
    /// stuck typing indicator.
    func cancelPendingCoachTurn(id: UUID) {
        messages.removeAll { $0.id == id }
        isAwaitingReply = false
        trimAndPersist()
    }

    /// Clear the entire thread. Used by Settings → "Reset Ask Noum
    /// thread" + by account sign-out paths. UI confirms first; this
    /// is a one-button wipe.
    func clearThread() {
        messages.removeAll()
        pendingInjectedCoachID = nil
        // Drop the AI chip cache too — every cached entry is keyed by
        // a coach message ID that no longer exists.
        aiChipsCache.removeAll()
        // Drop the empty-state starter cache as well — a wiped thread
        // returns to the empty state, which should re-roll fresh starters.
        starterChipsCache.removeAll()
        persist()
    }

    /// Cache an AI-generated chip set for a specific coach reply. Called
    /// by AskNoumView once the chip-generation request returns successfully.
    /// Idempotent — overwriting is a no-op if the chips match; we don't
    /// distinguish because the source of truth is the cached value, not
    /// the request that produced it.
    func setAIChips(_ chips: [String], for coachID: UUID) {
        aiChipsCache[coachID] = chips
    }

    /// Read cached chips for a coach reply, if any. Returns nil when the
    /// reply has no cached entry yet — the view falls back to the
    /// deterministic chip catalog in the meantime.
    func aiChips(for coachID: UUID) -> [String]? {
        aiChipsCache[coachID]
    }

    /// Cache an AI-generated empty-state starter set keyed by the input
    /// signature that produced it. Called by AskNoumView once the starter
    /// generation request returns successfully.
    func setStarterChips(_ chips: [String], for signature: String) {
        starterChipsCache[signature] = chips
    }

    /// Read cached starter prompts for a given input signature, if any.
    /// Returns nil when nothing has hydrated for this signature yet — the
    /// view shows the deterministic data-grounded `starterPrompts(...)` in
    /// the meantime, and the request fires once per new signature.
    func starterChips(for signature: String) -> [String]? {
        starterChipsCache[signature]
    }

    /// Cross-surface seed-message inject. Used by post-session bridges
    /// (Summary's "Talk to your coach about this rep") to drop a
    /// session-anchored opener into the thread before AskNoumView
    /// mounts. The returned coachID is the row AskNoumView should
    /// hydrate via the model.
    ///
    /// Idempotency: if the most-recent non-system user turn carries
    /// the same text AND a coach reply for it is either pending or
    /// already in flight, this is a no-op (returns the existing
    /// coachID if pending, nil otherwise). Stops a double-tap on the
    /// bridge from queuing two identical seed prompts back-to-back.
    @discardableResult
    func injectUserTurn(_ text: String) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Idempotency guard — if the last user turn IS this opener AND
        // its coach reply is still pending, return that same coachID
        // instead of queuing a duplicate. A double-tap on the Summary
        // bridge mid-reply must not produce a second seed pair.
        //
        // Once the prior reply has hydrated, re-inject is a legitimate
        // fresh ask (the user is asking again on a later visit) and
        // falls through to append a new pair.
        if let lastUserIdx = messages.lastIndex(where: { $0.role == .user }),
           messages[lastUserIdx].text == trimmed {
            let after = messages.suffix(from: messages.index(after: lastUserIdx))
            if let coachRow = after.first(where: { $0.role == .coach }),
               coachRow.isPending {
                return coachRow.id
            }
            // Hydrated coach row (or none yet for some odd state) →
            // fall through, append a fresh pair.
        }

        let ids = appendUserTurn(trimmed)
        pendingInjectedCoachID = ids.coachID
        return ids.coachID
    }

    /// One-shot consumer. AskNoumView calls this on appear; if the
    /// returned ID is non-nil it runs the model for that coachID and
    /// the store atomically clears the pending signal so a second
    /// AskNoumView mount (same nav stack lifecycle) doesn't fire a
    /// duplicate reply task.
    func consumePendingInjectedCoachID() -> UUID? {
        let id = pendingInjectedCoachID
        pendingInjectedCoachID = nil
        return id
    }

    /// Append a coach-authored message directly into the thread without
    /// a corresponding user turn. Used by surfaces that synthesise a
    /// coach artifact server-side or deterministically — e.g. the M20
    /// Forward Plan, where `ForwardPlanService.generate(...)` produces
    /// a four-week program that's rendered as a coach turn so the user
    /// can scroll back to it like any other reply. The returned ID lets
    /// callers reference the row (e.g. for cross-surface deep-linking
    /// or chip caching) once they need to.
    ///
    /// Empty text is rejected (defensive — a placeholder coach turn
    /// would render as an empty bubble). Non-empty text lands as a
    /// hydrated, non-pending `.coach` row immediately.
    @discardableResult
    func injectCoachTurn(_ text: String) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let msg = CoachMessage(role: .coach, text: trimmed, isPending: false)
        messages.append(msg)
        trimAndPersist()
        return msg.id
    }

    /// All non-system messages, oldest-first, suitable for the model
    /// replay. System notices are dropped — they're UI-only.
    var replayForModel: [CoachMessage] {
        messages.filter { $0.role != .systemNotice && !$0.isPending }
    }

    /// True once at least one coach reply has hydrated in this thread.
    /// Used by the header to flip the pending-reply subtitle from
    /// "Reading your context…" (cold start) to "Thinking…" (every
    /// subsequent reply) so the header never claims to still be reading
    /// context after the model has already responded.
    var hasLandedCoachReply: Bool {
        messages.contains { $0.role == .coach && !$0.isPending && !$0.text.isEmpty }
    }

    // MARK: - Persistence

    private var currentKey: String {
        let id = accountIDProvider() ?? "guest"
        return "\(Self.storagePrefix).\(id)"
    }

    private func loadFromDisk() {
        guard let data = defaults.data(forKey: currentKey),
              let decoded = try? JSONDecoder().decode([CoachMessage].self, from: data) else {
            return
        }
        // Defensive: don't restore a row that was pending when the app
        // exited — the model never returned, so this is effectively
        // dead. Drop it.
        var didCleanLegacyCoachNotes = false
        messages = decoded.filter { !$0.isPending }.map { message in
            guard message.role == .coach,
                  Self.shouldCleanLegacyCoachMessage(message.text) else {
                return message
            }
            didCleanLegacyCoachNotes = true
            return CoachMessage(
                id: message.id,
                role: .systemNotice,
                text: Self.legacyCoachMessageNotice,
                createdAt: message.createdAt,
                isPending: false
            )
        }
        if didCleanLegacyCoachNotes {
            persist()
        }
    }

    nonisolated static func shouldCleanLegacyCoachMessage(_ text: String) -> Bool {
        guard let issue = AICoachChatService.replyQualityIssue(in: text) else { return false }
        switch issue {
        case .roboticPhrase, .bareClarification, .defensiveProductLanguage, .menuInsteadOfDecision:
            return true
        case .tooLong, .missedTrustRepair, .missingPrescribedAction, .unanchoredCoaching, .overclaimsEvidence:
            return false
        }
    }

    private static let legacyCoachMessageNotice = "I cleaned up an older coach note that no longer meets the current standard. Ask for the current read and I'll use your latest case file."

    private func trimAndPersist() {
        if messages.count > Self.maxStoredMessages {
            messages.removeFirst(messages.count - Self.maxStoredMessages)
        }
        persist()
    }

    private func persist() {
        // Don't persist the pending placeholder rows — they're
        // transient. If the user backgrounds the app mid-reply the
        // pending row will reappear from memory but won't be written
        // to disk, so a relaunch starts clean.
        let persistable = messages.filter { !$0.isPending }
        guard let data = try? JSONEncoder().encode(persistable) else { return }
        defaults.set(data, forKey: currentKey)
    }

    // MARK: - Account ID

    /// Default account-ID resolver. Mirrors the convention every other
    /// per-account store uses (`AuthManager` → keychain `NoumAccountID`).
    /// Returns nil when signed-out / anonymous; the storage key falls
    /// back to `"guest"` so pre-sign-in chat survives.
    private static func defaultAccountIDProvider() -> String? {
        #if canImport(Security)
        return KeychainHelper.load(key: "NoumAccountID")
        #else
        return nil
        #endif
    }
}

#endif
