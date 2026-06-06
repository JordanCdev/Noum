import Foundation

// MARK: - SuddenDeathRunRecord
//
// A single completed Sudden Death run. Captures the honest facts of
// the rep — rounds survived, fillers, score, the final outcome that
// ended the run — so the user can look back at their actual track
// record across difficulties. No invented stats; no narrative; just
// the data the engine already produced at finalize time.
//
// Persisted per-account, per-difficulty by `SuddenDeathRunHistoryStore`.
// Surfaced by the "Recent Runs" section on `SuddenDeathResultView` so a
// completed rep lands beside its closest comparables — the user can
// see "I held 6 rounds last time, 4 today, 8 the week before" without
// having to walk back through History.

@available(iOS 17.0, macOS 12.0, *)
struct SuddenDeathRunRecord: Codable, Equatable, Identifiable {
    private enum CodingKeys: String, CodingKey {
        case id
        case completedAt
        case difficulty
        case roundsSurvived
        case totalFillers
        case totalWords
        case score
        case xpEarned
        case finalOutcome
        case wasNewBestAtTime
        case gamePoints
        case activeMultipliers
    }

    let id: UUID
    let completedAt: Date
    let difficulty: SuddenDeathDifficulty
    let roundsSurvived: Int
    let totalFillers: Int
    let totalWords: Int
    let score: Int
    let xpEarned: Int
    let finalOutcome: RoundOutcome
    /// `true` when this run set a new high score at the moment it was
    /// recorded. Snapshotted at record-time so a later run beating it
    /// doesn't retroactively un-flag the prior peak; the badge in the
    /// list represents "this WAS the best when it happened."
    let wasNewBestAtTime: Bool
    /// Multiplier-based game points shown on the result screen.
    /// Defaults to 0 for records created before this field existed.
    let gamePoints: Int
    /// Which multipliers were active (e.g. ["×1.5 Clean", "×1.3 Deep"]).
    /// Defaults to empty for legacy records.
    let activeMultipliers: [String]

    init(
        id: UUID = UUID(),
        completedAt: Date = Date(),
        difficulty: SuddenDeathDifficulty,
        roundsSurvived: Int,
        totalFillers: Int,
        totalWords: Int,
        score: Int,
        xpEarned: Int,
        finalOutcome: RoundOutcome,
        wasNewBestAtTime: Bool,
        gamePoints: Int = 0,
        activeMultipliers: [String] = []
    ) {
        self.id = id
        self.completedAt = completedAt
        self.difficulty = difficulty
        self.roundsSurvived = roundsSurvived
        self.totalFillers = totalFillers
        self.totalWords = totalWords
        self.score = score
        self.xpEarned = xpEarned
        self.finalOutcome = finalOutcome
        self.wasNewBestAtTime = wasNewBestAtTime
        self.gamePoints = gamePoints
        self.activeMultipliers = activeMultipliers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        difficulty = try container.decode(SuddenDeathDifficulty.self, forKey: .difficulty)
        roundsSurvived = try container.decode(Int.self, forKey: .roundsSurvived)
        totalFillers = try container.decode(Int.self, forKey: .totalFillers)
        totalWords = try container.decode(Int.self, forKey: .totalWords)
        score = try container.decode(Int.self, forKey: .score)
        xpEarned = try container.decode(Int.self, forKey: .xpEarned)
        finalOutcome = try container.decode(RoundOutcome.self, forKey: .finalOutcome)
        wasNewBestAtTime = try container.decode(Bool.self, forKey: .wasNewBestAtTime)
        gamePoints = try container.decodeIfPresent(Int.self, forKey: .gamePoints) ?? 0
        activeMultipliers = try container.decodeIfPresent([String].self, forKey: .activeMultipliers) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(roundsSurvived, forKey: .roundsSurvived)
        try container.encode(totalFillers, forKey: .totalFillers)
        try container.encode(totalWords, forKey: .totalWords)
        try container.encode(score, forKey: .score)
        try container.encode(xpEarned, forKey: .xpEarned)
        try container.encode(finalOutcome, forKey: .finalOutcome)
        try container.encode(wasNewBestAtTime, forKey: .wasNewBestAtTime)
        try container.encode(gamePoints, forKey: .gamePoints)
        try container.encode(activeMultipliers, forKey: .activeMultipliers)
    }
}

extension RoundOutcome: Codable {
    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode(String.self, forKey: .kind)
        switch raw {
        case "survived":            self = .survived
        case "timeoutBeforeStart":  self = .timeoutBeforeStart
        case "fillerOverload":      self = .fillerOverload
        case "tooShort":            self = .tooShort
        default:                    self = .survived
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let raw: String
        switch self {
        case .survived:            raw = "survived"
        case .timeoutBeforeStart:  raw = "timeoutBeforeStart"
        case .fillerOverload:      raw = "fillerOverload"
        case .tooShort:            raw = "tooShort"
        }
        try container.encode(raw, forKey: .kind)
    }
}
