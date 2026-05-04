import Foundation

// MARK: - Eloquence XP Scoring
//
// Findings are worth XP. The point: if the user uses a rhetorical move,
// the rank ladder reflects it — the app rewards *better speaking*, not
// just speaking-without-fillers.
//
// Constraints:
// - **Diminishing returns** so a single one-trick session can't farm XP.
// - **Stronger devices > weaker devices**. A genuine antithesis is rarer
//   than three alliterating words; the points reflect that.
// - **Capped per session** so the bonus stays a flavour, not a dominant
//   contribution. A fluent-but-clean rep should still earn meaningful XP
//   from the base session score.

enum EloquenceXP {

    /// XP cap a single session can earn from rhetorical findings. Picked
    /// so it can't outweigh the base session XP for a clean Pressure rep.
    static let perSessionCap: Int = 60

    /// Total XP for a list of findings, with per-finding values + a
    /// per-session cap.
    static func totalXP(for findings: [EloquenceFinding]) -> Int {
        var total = 0
        for (index, finding) in findings.enumerated() {
            let base = baseXP(for: finding.device)
            // Diminishing: 100% → 70% → 50% → 35% → 25%
            let multiplier: Double
            switch index {
            case 0: multiplier = 1.0
            case 1: multiplier = 0.70
            case 2: multiplier = 0.50
            case 3: multiplier = 0.35
            default: multiplier = 0.25
            }
            total += Int((Double(base) * multiplier).rounded())
        }
        return min(total, perSessionCap)
    }

    /// Per-device base XP. Tuned so harder-to-pull-off devices pay more.
    static func baseXP(for device: EloquenceDevice) -> Int {
        switch device {
        case .antithesis:           return 25 // genuinely hard, conservative detector
        case .tricolon, .ruleOfThree: return 20
        case .anaphora, .epistrophe: return 18
        case .isocolon:             return 16
        case .diacope:              return 14
        case .rhetoricalQuestion:   return 12
        case .epizeuxis:            return 12
        case .polysyndeton:         return 10
        case .asyndeton:            return 10
        case .alliteration:         return 8  // easiest to land, easiest to spot
        }
    }

    /// Short coach-voice copy summarising the bonus, used on the summary
    /// XP line. Returns nil when no bonus was earned.
    static func bonusCopy(for findings: [EloquenceFinding]) -> String? {
        guard !findings.isEmpty else { return nil }
        let xp = totalXP(for: findings)
        guard xp > 0 else { return nil }
        if findings.count == 1, let only = findings.first {
            return "+\(xp) XP for \(only.device.title.lowercased())"
        }
        return "+\(xp) XP for shape (\(findings.count) moves)"
    }
}
