import Foundation

// MARK: - Daily Challenge (M8)
//
// A claim-able micro-task that rotates daily at local midnight. Three
// challenges per day; deterministic per ISO date so the same day's
// challenges don't change when the user reopens the app. Each carries a
// concrete pass criterion that's evaluated against finalized
// PracticeSessions, and an XP reward that's only granted on user claim.
//
// Why three: a single tile can fit three rows comfortably; three options
// give the user a choice without becoming a checklist of obligations.
//
// Why not auto-claim: the "claim" tap is what produces the celebration
// moment (a quiet pull mechanic). Auto-claiming would skip the moment of
// agency that makes the loop work.

enum DailyChallengeKind: String, CaseIterable, Codable {
    case heldPause          // ≥ 1 unfilled pause ≥ 3.0s
    case shortAnswer        // duration ≤ 30s with ≥ 14 words and ≤ 1 filler
    case zeroFillers        // any session with 0 fillers, ≥ 14 words
    case sustainedAnswer    // duration ≥ 60s with ≤ 3 fillers
    case cleanSuddenDeath   // a Sudden Death session with 0 fillers
    case crispDelivery      // wordsPerMinute in 130–155 range with ≤ 2 fillers
    case highScoreSession   // session score ≥ 8/10
    case multiplePauses     // ≥ 2 deliberate pauses with low fill ratio

    /// Friendly headline for the tile row.
    var title: String {
        switch self {
        case .heldPause:        return "Hold a 3-second pause"
        case .shortAnswer:      return "Land a 30-second answer"
        case .zeroFillers:      return "Zero-filler rep"
        case .sustainedAnswer:  return "Hold a 60-second answer"
        case .cleanSuddenDeath: return "Clean Sudden Death round"
        case .crispDelivery:    return "Crisp 130–155 WPM"
        case .highScoreSession: return "Score 8 or higher"
        case .multiplePauses:   return "Two deliberate pauses"
        }
    }

    /// One-line "what to do" subtitle.
    var subtitle: String {
        switch self {
        case .heldPause:        return "Take a deliberate 3s silent pause inside one answer."
        case .shortAnswer:      return "Finish a clean rep in under 30 seconds."
        case .zeroFillers:      return "Get through one rep with zero filler words."
        case .sustainedAnswer:  return "Hold a coherent answer for at least a minute."
        case .cleanSuddenDeath: return "Survive a Sudden Death round with zero fillers."
        case .crispDelivery:    return "Speak in the 130–155 WPM range cleanly."
        case .highScoreSession: return "Land a session that scores 8/10 or better."
        case .multiplePauses:   return "Use silence twice in one rep — no filler bridges."
        }
    }

    /// XP awarded on claim. Tuned so the daily total (~85–135 XP) is
    /// meaningful without trivialising session XP. Three challenges
    /// completed = roughly the value of a strong session.
    var xpReward: Int {
        switch self {
        case .heldPause:        return 30
        case .shortAnswer:      return 25
        case .zeroFillers:      return 40
        case .sustainedAnswer:  return 35
        case .cleanSuddenDeath: return 50
        case .crispDelivery:    return 30
        case .highScoreSession: return 45
        case .multiplePauses:   return 30
        }
    }

    /// SF Symbol used in the tile row for this kind.
    var symbol: String {
        switch self {
        case .heldPause:        return "pause.circle.fill"
        case .shortAnswer:      return "bolt.fill"
        case .zeroFillers:      return "checkmark.seal.fill"
        case .sustainedAnswer:  return "clock.fill"
        case .cleanSuddenDeath: return "flame.fill"
        case .crispDelivery:    return "waveform"
        case .highScoreSession: return "star.fill"
        case .multiplePauses:   return "pause.fill"
        }
    }

    /// Returns true if the given session satisfies this challenge's criterion.
    /// Evaluations are intentionally strict — easy challenges shouldn't feel
    /// trivially claimable on noise.
    func isSatisfied(by session: PracticeSession) -> Bool {
        switch self {
        case .heldPause:
            return (session.pauseMetrics?.longestSeconds ?? 0) >= 3.0 &&
                   (session.pauseMetrics?.filledRatio ?? 1) < 0.8
        case .shortAnswer:
            return session.duration <= 30 && session.wordCount >= 14 && session.fillerWordCount <= 1
        case .zeroFillers:
            return session.fillerWordCount == 0 && session.wordCount >= 14
        case .sustainedAnswer:
            return session.duration >= 60 && session.fillerWordCount <= 3
        case .cleanSuddenDeath:
            return session.mode == .suddenDeath && session.fillerWordCount == 0
        case .crispDelivery:
            return (130...155).contains(session.wordsPerMinute) && session.fillerWordCount <= 2
        case .highScoreSession:
            return (session.score ?? 0) >= 8
        case .multiplePauses:
            return (session.pauseMetrics?.count ?? 0) >= 2 &&
                   (session.pauseMetrics?.filledRatio ?? 1) < 0.5
        }
    }
}

/// One day's challenge bundle. Stored as a single Codable blob keyed by
/// the ISO-8601 date string. Stays small — three kinds + claim flags.
struct DailyChallengeSet: Codable, Equatable {
    /// "yyyy-MM-dd" of the local day this set is valid for. When the
    /// stored value differs from today, the manager regenerates.
    let dayKey: String
    let kinds: [DailyChallengeKind]
    var claimedKinds: Set<DailyChallengeKind>

    /// Has the user satisfied (but not yet claimed) this challenge?
    /// Evaluated by the manager from session history; the set itself
    /// only stores claim flags.
    var allClaimed: Bool { claimedKinds.count == kinds.count && !kinds.isEmpty }

    /// Soft-expiry stamp — 9pm local on the dayKey. After this, the UI
    /// switches to a "fading" treatment with softer copy. Challenges
    /// remain claimable until midnight; the stamp only changes tone.
    func softExpiryDate(now: Date = Date()) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let day = formatter.date(from: dayKey) else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = 21  // 9pm local
        return Calendar.current.date(from: components)
    }

    var isPastSoftExpiry: Bool {
        guard let stamp = softExpiryDate() else { return false }
        return Date() >= stamp
    }
}

// MARK: - Generator (deterministic by date)

enum DailyChallengeGenerator {
    /// Returns three distinct challenge kinds for the given day, seeded by
    /// the dayKey hash so the same day produces the same trio across launches.
    /// Caller passes today's dayKey; we never mutate global state here.
    static func threeKinds(for dayKey: String) -> [DailyChallengeKind] {
        var rng = SeededRandomNumberGenerator(seed: hash(dayKey))
        var pool = DailyChallengeKind.allCases
        pool.shuffle(using: &rng)
        return Array(pool.prefix(3))
    }

    private static func hash(_ key: String) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(key)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }
}

/// Tiny seedable RNG so the daily set is deterministic. Splitmix64 — small,
/// well-distributed, and stable across Swift versions (the system RNG
/// doesn't take a seed publicly).
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
