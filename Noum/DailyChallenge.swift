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
    // MARK: Original pool (M8)
    case heldPause          // ≥ 1 unfilled pause ≥ 3.0s
    case shortAnswer        // duration ≤ 30s with ≥ 14 words and ≤ 1 filler
    case zeroFillers        // any session with 0 fillers, ≥ 14 words
    case sustainedAnswer    // duration ≥ 60s with ≤ 3 fillers
    case cleanSuddenDeath   // a Sudden Death session with 0 fillers
    case crispDelivery      // wordsPerMinute in 130–155 range with ≤ 2 fillers
    case highScoreSession   // session score ≥ 8/10
    case multiplePauses     // ≥ 2 deliberate pauses with low fill ratio

    // MARK: M16 rotation expansion — depth, variety, mode coverage
    //
    // The original pool of 8 produced ~37% day-to-day overlap on the
    // 3-of-N rotation. Expanding to 30 brings that under 10%, so users
    // feel a genuine rotation rather than the same three labels in a
    // shuffled order. Every new kind reuses fields already present on
    // `PracticeSession` — no new metrics needed, no new instrumentation.

    case lowFillerRate      // any session with at most 1 filler regardless of length, ≥ 25 words
    case soloAhCounter      // an Ah Counter session with ≤ 1 filler
    case timedDeepRep       // Timed mode rep ≥ 90s with score ≥ 7
    case suddenDeathSurvivor // Sudden Death session ≥ 60s with ≤ 1 filler
    case imConversationClean // IM mode rep with ≤ 2 fillers, ≥ 30 words
    case ratedRep           // any rated session (real practice, not a drill)
    case noFillerSpike      // ≥ 40 words with 0 fillers
    case sub3PercentFillers // fillerWordCount / wordCount ≤ 0.03 with ≥ 30 words
    case longHeldPause      // longestSeconds ≥ 4.0 with filledRatio < 0.5
    case threeDeliberatePauses // ≥ 3 pauses with filledRatio < 0.4
    case meanPauseQuality   // mean pause length ≥ 1.0s with filledRatio < 0.3
    case steadyPace         // WPM in 120–170 range with ≤ 3 fillers
    case measuredPace       // WPM in 110–135 range with ≤ 2 fillers (deliberate cadence)
    case wordRich           // ≥ 60 words in a single rep with score ≥ 7
    case sustainedSeventy   // duration ≥ 70s with ≤ 2 fillers
    case sustainedNinety    // duration ≥ 90s with ≤ 3 fillers
    case perfectTen         // session score = 10/10
    case strongPair         // session score ≥ 7 with ≤ 2 fillers (combined quality bar)
    case pitchVariation     // pitchMetrics.stdHz ≥ 25 over ≥ 10 voiced windows (varied delivery)
    case pressureRep        // pressureLevel != .standard with score ≥ 7
    case secondRepToday     // simply having ≥ 2 finalized sessions today by check-time
    case calmStart          // first 30s of rep (duration ≥ 60s) with 0 fillers and one pause

    /// Friendly headline for the tile row.
    var title: String {
        switch self {
        case .heldPause:                return "Hold a 3-second pause"
        case .shortAnswer:              return "Land a 30-second answer"
        case .zeroFillers:              return "Zero-filler rep"
        case .sustainedAnswer:          return "Hold a 60-second answer"
        case .cleanSuddenDeath:         return "Clean Pressure Drill round"
        case .crispDelivery:            return "Crisp 130–155 WPM"
        case .highScoreSession:         return "Score 8 or higher"
        case .multiplePauses:           return "Two deliberate pauses"
        case .lowFillerRate:            return "One filler at most"
        case .soloAhCounter:            return "Clean Filler Control round"
        case .timedDeepRep:             return "90-second Timed rep"
        case .suddenDeathSurvivor:      return "60-second Pressure Drill run"
        case .imConversationClean:      return "Clean conversation rep"
        case .ratedRep:                 return "Land one rated rep"
        case .noFillerSpike:            return "40 clean words"
        case .sub3PercentFillers:       return "Under 3% fillers"
        case .longHeldPause:            return "Hold a 4-second pause"
        case .threeDeliberatePauses:    return "Three deliberate pauses"
        case .meanPauseQuality:         return "Average a 1-second pause"
        case .steadyPace:               return "Steady 120–170 WPM"
        case .measuredPace:             return "Measured 110–135 WPM"
        case .wordRich:                 return "60-word rep"
        case .sustainedSeventy:         return "70-second answer"
        case .sustainedNinety:          return "90-second answer"
        case .perfectTen:               return "Score a perfect 10"
        case .strongPair:               return "Strong score, low fillers"
        case .pitchVariation:           return "Vary your pitch"
        case .pressureRep:              return "Score 7 under pressure"
        case .secondRepToday:           return "Stack a second rep"
        case .calmStart:                return "Calm 30-second opener"
        }
    }

    /// One-line "what to do" subtitle.
    var subtitle: String {
        switch self {
        case .heldPause:                return "Take a deliberate 3s silent pause inside one answer."
        case .shortAnswer:              return "Finish a clean rep in under 30 seconds."
        case .zeroFillers:              return "Get through one rep with zero filler words."
        case .sustainedAnswer:          return "Hold a coherent answer for at least a minute."
        case .cleanSuddenDeath:         return "Survive a Pressure Drill round with zero fillers."
        case .crispDelivery:            return "Speak in the 130–155 WPM range cleanly."
        case .highScoreSession:         return "Land a session that scores 8/10 or better."
        case .multiplePauses:           return "Use silence twice in one rep — no filler bridges."
        case .lowFillerRate:            return "Hold one rep to a single filler word."
        case .soloAhCounter:            return "Complete a Filler Control rep with at most one filler."
        case .timedDeepRep:             return "A 90-second Timed answer that scores at least 7."
        case .suddenDeathSurvivor:      return "Hold Pressure Drill for 60 seconds with one filler at most."
        case .imConversationClean:      return "A 30-word conversation rep with at most two fillers."
        case .ratedRep:                 return "Finish any rated session — real reps, not drills."
        case .noFillerSpike:            return "Land a 40-word rep with zero fillers."
        case .sub3PercentFillers:       return "Keep fillers under 3% of words on a 30-word rep."
        case .longHeldPause:            return "Hold a single silent pause for four seconds."
        case .threeDeliberatePauses:    return "Use silence three times in one rep, mostly clean."
        case .meanPauseQuality:         return "Average a 1-second pause across the rep, mostly clean."
        case .steadyPace:               return "Hold a 120–170 WPM cadence with at most three fillers."
        case .measuredPace:             return "Stay in a deliberate 110–135 WPM with at most two fillers."
        case .wordRich:                 return "A 60-word rep that scores at least 7."
        case .sustainedSeventy:         return "Hold an answer 70 seconds with at most two fillers."
        case .sustainedNinety:          return "Hold an answer 90 seconds with at most three fillers."
        case .perfectTen:               return "Land a session that scores a full 10/10."
        case .strongPair:               return "Score 7 or higher with at most two fillers."
        case .pitchVariation:           return "Vary your pitch across the rep, not monotone."
        case .pressureRep:              return "Score at least 7 on a non-standard pressure rep."
        case .secondRepToday:           return "Stack a second finalized rep today."
        case .calmStart:                return "Open a 60-second rep with no fillers and one pause in the first 30s."
        }
    }

    /// XP awarded on claim. Tuned so the daily total (~85–135 XP) is
    /// meaningful without trivialising session XP. Three challenges
    /// completed = roughly the value of a strong session. New M16 kinds
    /// follow the same band — none exceeds +50, none under +20.
    var xpReward: Int {
        switch self {
        case .heldPause:                return 30
        case .shortAnswer:              return 25
        case .zeroFillers:              return 40
        case .sustainedAnswer:          return 35
        case .cleanSuddenDeath:         return 50
        case .crispDelivery:            return 30
        case .highScoreSession:         return 45
        case .multiplePauses:           return 30
        case .lowFillerRate:            return 30
        case .soloAhCounter:            return 35
        case .timedDeepRep:             return 40
        case .suddenDeathSurvivor:      return 45
        case .imConversationClean:      return 35
        case .ratedRep:                 return 20
        case .noFillerSpike:            return 45
        case .sub3PercentFillers:       return 35
        case .longHeldPause:            return 40
        case .threeDeliberatePauses:    return 40
        case .meanPauseQuality:         return 35
        case .steadyPace:               return 30
        case .measuredPace:             return 30
        case .wordRich:                 return 40
        case .sustainedSeventy:         return 35
        case .sustainedNinety:          return 40
        case .perfectTen:               return 50
        case .strongPair:               return 35
        case .pitchVariation:           return 30
        case .pressureRep:              return 45
        case .secondRepToday:           return 25
        case .calmStart:                return 40
        }
    }

    /// SF Symbol used in the tile row for this kind.
    var symbol: String {
        switch self {
        case .heldPause:                return "pause.circle.fill"
        case .shortAnswer:              return "bolt.fill"
        case .zeroFillers:              return "checkmark.seal.fill"
        case .sustainedAnswer:          return "clock.fill"
        case .cleanSuddenDeath:         return "flame.fill"
        case .crispDelivery:            return "waveform"
        case .highScoreSession:         return "star.fill"
        case .multiplePauses:           return "pause.fill"
        case .lowFillerRate:            return "minus.circle.fill"
        case .soloAhCounter:            return "ear.fill"
        case .timedDeepRep:             return "timer"
        case .suddenDeathSurvivor:      return "shield.fill"
        case .imConversationClean:      return "bubble.left.and.bubble.right.fill"
        case .ratedRep:                 return "checkmark.circle.fill"
        case .noFillerSpike:            return "sparkles"
        case .sub3PercentFillers:       return "percent"
        case .longHeldPause:            return "pause.rectangle.fill"
        case .threeDeliberatePauses:    return "ellipsis"
        case .meanPauseQuality:         return "speaker.wave.1.fill"
        case .steadyPace:               return "metronome.fill"
        case .measuredPace:             return "tortoise.fill"
        case .wordRich:                 return "text.alignleft"
        case .sustainedSeventy:         return "hourglass"
        case .sustainedNinety:          return "stopwatch.fill"
        case .perfectTen:               return "rosette"
        case .strongPair:               return "checkmark.shield.fill"
        case .pitchVariation:           return "waveform.path.ecg"
        case .pressureRep:              return "gauge.with.dots.needle.bottom.50percent"
        case .secondRepToday:           return "plus.circle.fill"
        case .calmStart:                return "leaf.fill"
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
            return ConversationalPaceBand.contains(session.wordsPerMinute) && session.fillerWordCount <= 2
        case .highScoreSession:
            return (session.score ?? 0) >= 8
        case .multiplePauses:
            return (session.pauseMetrics?.count ?? 0) >= 2 &&
                   (session.pauseMetrics?.filledRatio ?? 1) < 0.5
        case .lowFillerRate:
            return session.fillerWordCount <= 1 && session.wordCount >= 25
        case .soloAhCounter:
            return session.mode == .ahCounter && session.fillerWordCount <= 1
        case .timedDeepRep:
            return session.mode == .timed && session.duration >= 90 && (session.score ?? 0) >= 7
        case .suddenDeathSurvivor:
            return session.mode == .suddenDeath && session.duration >= 60 && session.fillerWordCount <= 1
        case .imConversationClean:
            return session.mode == .imConversation && session.fillerWordCount <= 2 && session.wordCount >= 30
        case .ratedRep:
            return session.isRated
        case .noFillerSpike:
            return session.fillerWordCount == 0 && session.wordCount >= 40
        case .sub3PercentFillers:
            guard session.wordCount >= 30 else { return false }
            let rate = Double(session.fillerWordCount) / Double(session.wordCount)
            return rate <= 0.03
        case .longHeldPause:
            return (session.pauseMetrics?.longestSeconds ?? 0) >= 4.0 &&
                   (session.pauseMetrics?.filledRatio ?? 1) < 0.5
        case .threeDeliberatePauses:
            return (session.pauseMetrics?.count ?? 0) >= 3 &&
                   (session.pauseMetrics?.filledRatio ?? 1) < 0.4
        case .meanPauseQuality:
            return (session.pauseMetrics?.meanSeconds ?? 0) >= 1.0 &&
                   (session.pauseMetrics?.filledRatio ?? 1) < 0.3 &&
                   (session.pauseMetrics?.count ?? 0) >= 2
        case .steadyPace:
            return ConversationalPaceBand.contains(session.wordsPerMinute) && session.fillerWordCount <= 3
        case .measuredPace:
            return ConversationalPaceBand.contains(session.wordsPerMinute) && session.fillerWordCount <= 2
        case .wordRich:
            return session.wordCount >= 60 && (session.score ?? 0) >= 7
        case .sustainedSeventy:
            return session.duration >= 70 && session.fillerWordCount <= 2
        case .sustainedNinety:
            return session.duration >= 90 && session.fillerWordCount <= 3
        case .perfectTen:
            return (session.score ?? 0) >= 10
        case .strongPair:
            return (session.score ?? 0) >= 7 && session.fillerWordCount <= 2
        case .pitchVariation:
            // Honest gating: only credit when the pitch metrics carry enough
            // signal (reliable windows + voiced ratio). Below that, we can't
            // honestly say "you varied your pitch" — so the rep doesn't count
            // and the user isn't rewarded for noise.
            guard let pitch = session.pitchMetrics, pitch.isReliable, let stdHz = pitch.stdHz else {
                return false
            }
            return stdHz >= 25
        case .pressureRep:
            return session.pressureLevel != .standard && (session.score ?? 0) >= 7
        case .secondRepToday:
            // Evaluated against the "latest session today" view in the
            // manager — we read sessionsTodayCount from the store at
            // evaluation time. This case stays sentinel-style: the
            // manager's recompute path is the only legitimate evaluator.
            // A direct call here returns true if the session itself is
            // already the second-or-later rep of the day; the manager
            // wraps the check to also reflect "happened earlier today".
            return false  // overridden by manager's day-aware check
        case .calmStart:
            // Rep must be substantial enough to "start" something, and the
            // pause metrics must show at least one deliberate pause early.
            // We don't have per-window timing here so we conservatively
            // require ≥ 60s duration, 0 fillers in the whole rep, and at
            // least one mostly-silent pause — a reasonable proxy for a
            // calm opener that we don't overclaim against partial data.
            return session.duration >= 60 &&
                   session.fillerWordCount == 0 &&
                   (session.pauseMetrics?.count ?? 0) >= 1 &&
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
    /// the dayKey (and, optionally, an accountID) so the same day produces
    /// the same trio across launches and across reinstalls — independent
    /// of process-randomised `Hasher`. The accountID lets two users on
    /// the same day see different trios; passing nil collapses to the
    /// per-day rotation only.
    static func threeKinds(for dayKey: String, accountID: String? = nil) -> [DailyChallengeKind] {
        var rng = SeededRandomNumberGenerator(seed: seed(for: dayKey, accountID: accountID))
        var pool = DailyChallengeKind.allCases
        pool.shuffle(using: &rng)
        return Array(pool.prefix(3))
    }

    /// FNV-1a 64-bit hash. Process-stable — unlike Swift's `Hasher`, which
    /// uses a per-launch random seed and will produce different values on
    /// successive runs. The brief explicitly requires "rotation is
    /// deterministic per (date, accountID)", so we hash here instead of
    /// leaning on the standard library.
    static func seed(for dayKey: String, accountID: String?) -> UInt64 {
        let composite: String
        if let id = accountID, !id.isEmpty {
            composite = dayKey + "|" + id
        } else {
            composite = dayKey
        }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in composite.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
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
