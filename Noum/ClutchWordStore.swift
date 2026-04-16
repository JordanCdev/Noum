import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Clutch Word Profile

/// A "clutch word" is a personal verbal habit — words or phrases the user
/// relies on as crutches (e.g. "actually", "basically", "literally", "right",
/// "I mean", "honestly"). These go beyond standard filler words.
///
/// The system tracks which clutch words appear across sessions, building a
/// per-user speech fingerprint.

struct ClutchWordEntry: Codable, Identifiable {
    let id: UUID
    let word: String
    let sessionCount: Int     // how many sessions it appeared in
    let totalOccurrences: Int // total times across all sessions
    let firstSeen: Date
    let lastSeen: Date

    init(word: String, sessionCount: Int = 1, totalOccurrences: Int = 1,
         firstSeen: Date = Date(), lastSeen: Date = Date()) {
        self.id = UUID()
        self.word = word
        self.sessionCount = sessionCount
        self.totalOccurrences = totalOccurrences
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }
}

// MARK: - Clutch Word Store

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class ClutchWordStore: ObservableObject {
    static let shared = ClutchWordStore()

    /// Default clutch word candidates to watch for.
    static let defaultClutchWords: Set<String> = [
        "actually", "basically", "literally", "honestly", "right",
        "obviously", "clearly", "just", "really", "totally",
        "definitely", "absolutely", "essentially", "i mean", "you see",
        "kind of", "sort of", "i guess", "thing is", "the thing is"
    ]

    /// User-added custom filler words (added to the standard filler detection).
    @Published var customFillerWords: Set<String> = []

    /// Tracked clutch word profile built from session history.
    @Published private(set) var clutchProfile: [String: ClutchWordEntry] = [:]

    /// Words the user has explicitly dismissed (don't want to track).
    @Published var dismissedWords: Set<String> = []

    private let customFillersKey = "noum_custom_filler_words"
    private let clutchProfileKey = "noum_clutch_word_profile"
    private let dismissedKey = "noum_dismissed_clutch_words"

    private init() {
        load()
    }

    // MARK: - Custom Filler Management

    func addCustomFiller(_ word: String) {
        let lowered = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowered.isEmpty else { return }
        customFillerWords.insert(lowered)
        save()
    }

    func removeCustomFiller(_ word: String) {
        customFillerWords.remove(word.lowercased())
        save()
    }

    // MARK: - Clutch Word Detection

    /// Scan a transcript for clutch words and update the profile.
    /// Call this after each session.
    func analyzeSession(transcript: String) {
        let lowered = transcript.lowercased()
        let candidates = Self.defaultClutchWords.subtracting(dismissedWords)
        var foundWords: [String: Int] = [:]

        for candidate in candidates {
            let count = countOccurrences(of: candidate, in: lowered)
            if count > 0 {
                foundWords[candidate] = count
            }
        }

        // Also check custom filler words as clutch words
        for word in customFillerWords {
            let count = countOccurrences(of: word, in: lowered)
            if count > 0 {
                foundWords[word] = (foundWords[word] ?? 0) + count
            }
        }

        let now = Date()
        for (word, count) in foundWords {
            if var existing = clutchProfile[word] {
                existing = ClutchWordEntry(
                    word: word,
                    sessionCount: existing.sessionCount + 1,
                    totalOccurrences: existing.totalOccurrences + count,
                    firstSeen: existing.firstSeen,
                    lastSeen: now
                )
                clutchProfile[word] = existing
            } else {
                clutchProfile[word] = ClutchWordEntry(
                    word: word,
                    sessionCount: 1,
                    totalOccurrences: count,
                    firstSeen: now,
                    lastSeen: now
                )
            }
        }

        save()
    }

    /// Dismiss a clutch word so it's no longer tracked.
    func dismissWord(_ word: String) {
        let lowered = word.lowercased()
        dismissedWords.insert(lowered)
        clutchProfile.removeValue(forKey: lowered)
        save()
    }

    /// Top clutch words sorted by total occurrences (descending).
    var topClutchWords: [ClutchWordEntry] {
        clutchProfile.values
            .sorted { $0.totalOccurrences > $1.totalOccurrences }
    }

    /// Clutch words that appear in 3+ sessions (established patterns).
    var establishedPatterns: [ClutchWordEntry] {
        topClutchWords.filter { $0.sessionCount >= 3 }
    }

    // MARK: - Helpers

    private func countOccurrences(of word: String, in text: String) -> Int {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = #"(?i)(?<!\w)\#(escaped)(?=\b|[^\w]|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    // MARK: - Persistence

    private func save() {
        // Custom filler words
        if let data = try? JSONEncoder().encode(Array(customFillerWords)) {
            UserDefaults.standard.set(data, forKey: customFillersKey)
        }

        // Clutch profile
        let entries = Array(clutchProfile.values)
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: clutchProfileKey)
        }

        // Dismissed words
        if let data = try? JSONEncoder().encode(Array(dismissedWords)) {
            UserDefaults.standard.set(data, forKey: dismissedKey)
        }
    }

    private func load() {
        // Custom filler words
        if let data = UserDefaults.standard.data(forKey: customFillersKey),
           let words = try? JSONDecoder().decode([String].self, from: data) {
            customFillerWords = Set(words)
        }

        // Clutch profile
        if let data = UserDefaults.standard.data(forKey: clutchProfileKey),
           let entries = try? JSONDecoder().decode([ClutchWordEntry].self, from: data) {
            clutchProfile = Dictionary(uniqueKeysWithValues: entries.map { ($0.word, $0) })
        }

        // Dismissed words
        if let data = UserDefaults.standard.data(forKey: dismissedKey),
           let words = try? JSONDecoder().decode([String].self, from: data) {
            dismissedWords = Set(words)
        }
    }
}
#endif
