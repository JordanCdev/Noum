#if canImport(SwiftUI)
import Foundation
import SwiftUI
import Combine

// MARK: - Word of the Day Manager (M9)
//
// Reads today's word from the deterministic catalog and tracks whether
// the user has used it in any practice session today. Detection scans
// finalized session transcripts (lowercased + word-boundary safe) for
// any of the entry's `acceptedForms`.
//
// "Used" is a one-shot signal — once detected, persisted for the day.
// Subsequent sessions don't re-celebrate.
//
// Storage shape per account:
//   noum.wordOfTheDay.usedDays.<accountID>  →  Set<String> of dayKeys.
// We store the set, not just "today yes/no", so the user can see "9 days
// used this month" if we ever want to surface a vocabulary streak.

@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class WordOfTheDayManager: ObservableObject {
    static let shared = WordOfTheDayManager()

    /// Today's curated word entry. Refreshes at midnight via ensureForToday().
    @Published private(set) var todaysEntry: WordOfTheDayEntry = WordOfTheDayCatalog.entries[0]

    /// True when the user has used today's word in any of today's sessions.
    /// Once set, stays set until midnight rolls over.
    @Published private(set) var hasUsedToday: Bool = false

    /// Pulse signal for the home tile: set once when the day's word goes
    /// from unused → used. UI consumes via `consumePendingUsage()`.
    @Published private(set) var pendingUsageSignal: Bool = false

    private let usedDaysKeyPrefix = "noum.wordOfTheDay.usedDays."
    private var sessionsSubscription: AnyCancellable?
    private var lastEvaluatedDayKey: String = ""

    private init() {
        ensureForToday()
        observeSessionStore()
    }

    // MARK: - Public API

    func ensureForToday() {
        let key = Self.todayKey()
        let accountID = AuthManager.shared.currentAccountID
        todaysEntry = WordOfTheDayCatalog.entry(for: key, accountID: accountID)
        let used = loadUsedDays()
        let nowUsed = used.contains(key)
        if nowUsed != hasUsedToday {
            hasUsedToday = nowUsed
        }
        // If the day actually rolled over, recompute against today's sessions.
        if key != lastEvaluatedDayKey {
            lastEvaluatedDayKey = key
            evaluateAgainstTodaysSessions()
        }
    }

    /// Re-scan today's sessions for the day's word. Called after each
    /// session finalize via the SessionStore subscription.
    func evaluateAgainstTodaysSessions() {
        guard !hasUsedToday else { return }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let todaysSessions = PracticeSessionStore.shared.progressEligibleSessions
            .filter { $0.date >= todayStart }
        for session in todaysSessions {
            if Self.transcriptContains(any: todaysEntry.acceptedForms, in: session.transcript) {
                markUsed()
                return
            }
        }
    }

    func consumePendingUsage() {
        pendingUsageSignal = false
    }

    func reloadForCurrentAccount() {
        ensureForToday()
    }

    // MARK: - Detection

    /// Scan a transcript for any of the accepted forms. Word-boundary safe —
    /// "art" doesn't match inside "smart". Case-insensitive.
    static func transcriptContains(any forms: [String], in transcript: String) -> Bool {
        let lowered = transcript.lowercased()
        // Tokenize on non-letter boundaries and check membership in a set.
        // O(n + m) instead of regex per form, and matches tokenization
        // semantics used elsewhere in the app (`PracticeSession.wordCount`).
        let tokens = Set(lowered.split { !$0.isLetter }.map(String.init))
        let formSet = Set(forms.map { $0.lowercased() })
        return !tokens.isDisjoint(with: formSet)
    }

    // MARK: - Storage

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    private var usedDaysKey: String {
        let id = AuthManager.shared.currentAccountID ?? "guest"
        return usedDaysKeyPrefix + id
    }

    private func loadUsedDays() -> Set<String> {
        guard let array = UserDefaults.standard.array(forKey: usedDaysKey) as? [String] else {
            return []
        }
        return Set(array)
    }

    private func saveUsedDays(_ days: Set<String>) {
        UserDefaults.standard.set(Array(days), forKey: usedDaysKey)
    }

    private func markUsed() {
        let key = Self.todayKey()
        var days = loadUsedDays()
        guard !days.contains(key) else { return }
        days.insert(key)
        saveUsedDays(days)
        hasUsedToday = true
        pendingUsageSignal = true
        CoachHaptic.skillLevelUp()
    }

    // MARK: - Session subscription

    private func observeSessionStore() {
        sessionsSubscription = PracticeSessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.ensureForToday()
                self?.evaluateAgainstTodaysSessions()
            }
    }
}

#endif
