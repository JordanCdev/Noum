import Foundation

// MARK: - Structural Read
//
// Per VISION § Strategic roadmap #2 (Delivery intelligence):
//   "Pause quality, prosody/intonation, pitch range, breathing,
//    emphasis, vocal energy, authority/tension, **structure**,
//    confidence markers, and word-choice precision reliable session
//    evidence."
//
// This is the fourth derived read after M26 vocal energy + M27
// composure + M28 confidence markers. StructuralReadEngine composes
// the per-rep structural-dimension ratings (Opening / Structure /
// Depth / Close) already captured per-session via FeedbackEngine
// into one 0-1 structural-quality score the coach can quote back.
//
// These dimensions are scored per-rep on a Good/OK/Could-improve
// scale by the existing FeedbackEngine and persisted as
// `SkillSnapshot.categoryRatings`. The baseline aggregates them as
// 1-3 stats (CommunicationBaseline.openingStrength, .closingStrength,
// .structureQuality, .answerDepth) — but until now they live in
// isolation. The structural read fuses the four into one read the
// AI coach can comment on as "the rep's bones".
//
// Per VISION § Dev instructions:
//   - "Weak evidence must produce tentative language." Fewer
//     contributing dimensions → softer prefix ("Early structural
//     read") just like M27/M28.
//   - "Every recommendation must have evidence, purpose, an
//     observable target, and an honest evidence threshold for
//     changing the plan." The composite is honest about which
//     dimensions contributed — no fabricated whole-rep verdict from
//     a single dimension.

/// Per-rep structural-quality score with dimension attribution.
/// `score` is 0-1: 1.0 = all four dimensions read as Good; 0.0 = all
/// four read as Could improve.
struct StructuralRead: Codable, Equatable {
    /// 0-1 composite. Mean of the available dimension scores
    /// (1 = Could improve → 0.0, 2 = OK → 0.5, 3 = Good → 1.0).
    let score: Double
    /// Number of dimensions that contributed. 2-dimension minimum
    /// at the engine level; below that → nil.
    let contributingDimensions: Int
    /// Which dimensions contributed. Honest about which read.
    let inputs: Inputs
    /// Coach-voice readout. Hedged; references which dimensions
    /// landed strong/weak.
    let readout: String

    struct Inputs: Codable, Equatable {
        let openingRating: String?     // "Good" / "OK" / "Could improve"
        let structureRating: String?
        let depthRating: String?
        let closeRating: String?
    }
}

enum StructuralReadEngine {

    /// 2-dimension minimum. One dimension alone isn't enough — a
    /// rep with only "Opening: Good" doesn't tell us how the bones
    /// held across the whole rep.
    static let minimumContributingDimensions: Int = 2

    /// Compose the read from the most-recent SkillSnapshot.
    /// Returns nil when fewer than `minimumContributingDimensions`
    /// dimensions are present in the snapshot's `categoryRatings`.
    static func derive(snapshot: SkillSnapshot?) -> StructuralRead? {
        guard let snapshot = snapshot else { return nil }
        return derive(categoryRatings: snapshot.categoryRatings)
    }

    /// Pure-function entry point — useful for unit tests that don't
    /// need to construct a full SkillSnapshot.
    static func derive(categoryRatings: [String: String]) -> StructuralRead? {
        let opening = categoryRatings["Opening"]
        let structure = categoryRatings["Structure"]
        let depth = categoryRatings["Depth"]
        let close = categoryRatings["Close"]

        var scores: [Double] = []
        if let v = score(forRating: opening)   { scores.append(v) }
        if let v = score(forRating: structure) { scores.append(v) }
        if let v = score(forRating: depth)     { scores.append(v) }
        if let v = score(forRating: close)     { scores.append(v) }

        guard scores.count >= minimumContributingDimensions else { return nil }

        let composite = scores.reduce(0, +) / Double(scores.count)
        let inputs = StructuralRead.Inputs(
            openingRating: opening,
            structureRating: structure,
            depthRating: depth,
            closeRating: close
        )
        return StructuralRead(
            score: composite,
            contributingDimensions: scores.count,
            inputs: inputs,
            readout: readoutCopy(score: composite, inputs: inputs)
        )
    }

    /// Map FeedbackRating string → 0-1 dimension score.
    /// Good → 1.0; OK → 0.5; Could improve → 0.0. Returns nil for
    /// unknown / missing ratings.
    static func score(forRating raw: String?) -> Double? {
        guard let raw = raw else { return nil }
        switch raw {
        case "Good":          return 1.0
        case "OK":            return 0.5
        case "Could improve": return 0.0
        default:              return nil
        }
    }

    /// Coach-voice readout. Names which dimensions landed strong
    /// and which faltered. Per VISION dev rule, hedged when fewer
    /// dimensions contributed.
    static func readoutCopy(score: Double, inputs: StructuralRead.Inputs) -> String {
        let label = qualitativeLabel(score: score)
        let dimensionCount = [inputs.openingRating, inputs.structureRating, inputs.depthRating, inputs.closeRating]
            .compactMap { $0 }.count
        let prefix = dimensionCount >= 3 ? "Structural read" : "Early structural read"

        // Name the strongest and weakest contributing dimensions so
        // the coach can point at specific bones instead of vague-
        // gesturing at the whole rep.
        let attributions = strongestAndWeakest(inputs: inputs)
        let attribTail: String
        if let (strongest, weakest) = attributions, strongest != weakest {
            attribTail = " — \(strongest) held, \(weakest) faltered"
        } else if let (strongest, _) = attributions {
            attribTail = " — \(strongest) carried the rep"
        } else {
            attribTail = ""
        }
        return "\(prefix): \(label)\(attribTail)"
    }

    static func qualitativeLabel(score: Double) -> String {
        switch score {
        case 0.85...:    return "bones held — strong shape across the dimensions"
        case 0.65..<0.85: return "mostly held — one weak dimension"
        case 0.45..<0.65: return "mixed — some dimensions clear, others soft"
        case 0.25..<0.45: return "thin — multiple dimensions read as Could improve"
        default:         return "weak shape — bones didn't hold across the rep"
        }
    }

    /// Find the highest-scoring and lowest-scoring named dimensions
    /// in the inputs. Returns nil tuples for both when no named
    /// dimension contributed. When multiple dimensions tie, returns
    /// the first one encountered (Opening > Structure > Depth > Close).
    static func strongestAndWeakest(inputs: StructuralRead.Inputs) -> (strongest: String, weakest: String)? {
        let pairs: [(name: String, score: Double)] = [
            ("opening",   score(forRating: inputs.openingRating)),
            ("structure", score(forRating: inputs.structureRating)),
            ("depth",     score(forRating: inputs.depthRating)),
            ("close",     score(forRating: inputs.closeRating)),
        ].compactMap { (name, s) in
            guard let s = s else { return nil }
            return (name, s)
        }
        guard !pairs.isEmpty else { return nil }
        let strongest = pairs.max(by: { $0.score < $1.score })!
        let weakest = pairs.min(by: { $0.score < $1.score })!
        return (strongest.name, weakest.name)
    }
}
