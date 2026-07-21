import Foundation

// MARK: - Progression spine narration (view-free resolvers)
//
// One story across every progression surface: the speaking rating is the
// ONLY number allowed to answer "am I getting better at speaking?". Every
// other ledger must name its role in the same breath — practice volume
// (XP), unlock/input (crowns, landmarks), or proof (verified quotes).
//
// These resolvers are pure and view-free (same testable pattern as
// `ProfileDefaultSurfacePlan`) so the narration contract is pinned by unit
// tests before any view adopts it. They change WHERE and HOW a number
// reads — never WHETHER it accrues. All credit wiring
// (`ProfileManager.addXP`, lesson passes, mode mastery → PathProgressManager)
// stays untouched by design.

// MARK: Ledger taxonomy

/// Every progression ledger the product tracks. Documentation-as-code:
/// adding a new ledger forces a conscious role decision here, pinned by
/// the spine-uniqueness test.
enum ProgressionLedger: String, CaseIterable, Equatable {
    /// RatingStore / RatingEngine — evidence-gated speaking rating.
    case speakingRating
    /// ProfileManager XP — deliberate-practice volume.
    case practiceVolume
    /// LessonStore practice passes / crowns.
    case lessonCrowns
    /// PathProgressManager nodes — the coach's sequenced course.
    case pathLandmarks
    /// ProofMomentArchive — transcript-verified quotes.
    case proofArchive
}

/// The three narrative roles a ledger may play. There is exactly ONE spine.
enum ProgressionLedgerRole: String, Equatable {
    /// The only ledger allowed to claim skill: the speaking rating.
    case spine
    /// Feeds the spine — volume and unlocks. Narrates as "points UP the
    /// spine" (passes unlock landmarks; landmarks build the skills the
    /// rating measures), never as a competing score.
    case input
    /// Qualitative evidence BEHIND the rating — quoted, never scored.
    case proof

    static func role(for ledger: ProgressionLedger) -> ProgressionLedgerRole {
        switch ledger {
        case .speakingRating:
            return .spine
        case .practiceVolume, .lessonCrowns, .pathLandmarks:
            return .input
        case .proofArchive:
            return .proof
        }
    }
}

// MARK: - Practice volume narration (XP)

/// Colour band for practice-volume chrome, derived from XP — never from
/// string-matching a level title. Re-narrating titles must not silently
/// degrade the level presentation to fallback styling. Bands keep the exact legacy XP boundaries
/// (one band per 3,000 XP, capped) so the swap is visually lossless.
enum PracticeVolumeTintBand: String, CaseIterable, Equatable {
    case blue      // 0–2,999 XP (legacy "Beginner" tier styling)
    case teal      // 3,000–5,999 XP
    case indigo    // 6,000–8,999 XP
    case orange    // 9,000–11,999 XP
    case gold      // 12,000+ XP
}

/// XP is always practice VOLUME, never a skill identity. No string built
/// here may contain Speaker / Beginner / Novice / Professional /
/// World Class / Elite / rank — "Practice level N" is the only permitted
/// title shape (pinned by the vocabulary-ban test). Forward distances are
/// neutral ("M to practice level K"), never countdown or loss framing
/// (never punish-shame).
enum PracticeVolumeNarration {

    private static let xpPerLevel = 1000
    private static let levelsPerBand = 3

    /// 1-based practice level. Mirrors the legacy ladder
    /// (`ProfileManager.levelTitle` reads `xp / 1000`) so level crossings
    /// happen at exactly the same XP totals as before.
    static func level(forXP xp: Int) -> Int {
        max(0, xp) / xpPerLevel + 1
    }

    /// Neutral volume title. Replaces "Speaker N" / "Average Speaker II"
    /// identity claims.
    static func title(forXP xp: Int) -> String {
        "Practice level \(level(forXP: xp))"
    }

    /// Neutral volume line with forward distance, zero skill vocabulary.
    static func detailLine(forXP xp: Int) -> String {
        let banked = max(0, xp)
        return "\(banked) XP banked · \(xpToNextLevel(forXP: xp)) to practice level \(level(forXP: xp) + 1)"
    }

    /// Replaces the "LEVEL UP" headline — a milestone of volume, not rank.
    static func levelUpHeadline() -> String {
        "PRACTICE MILESTONE"
    }

    /// Volume-framed milestone detail. Replaces "Keep practicing to reach
    /// the next rank."
    static func levelUpDetail(forXP xp: Int) -> String {
        let banked = max(0, xp)
        return "\(banked) XP of deliberate practice banked — \(xpToNextLevel(forXP: xp)) more to practice level \(level(forXP: xp) + 1)."
    }

    /// Quiet credit caption for the verdict's Details drawer. Folds the
    /// eloquence bonus into one honest total; nil when nothing accrued so
    /// the row self-suppresses instead of rendering "+0".
    static func verdictCreditLine(xpEarned: Int, eloquenceBonus: Int) -> String? {
        let total = max(0, xpEarned) + max(0, eloquenceBonus)
        guard total > 0 else { return nil }
        return "+\(total) XP banked"
    }

    /// Celebration tint band, total over all Int XP (negatives clamp to
    /// the first band — never traps, never falls through to a lie).
    static func tintBand(forXP xp: Int) -> PracticeVolumeTintBand {
        switch bandIndex(forXP: xp) {
        case 0: return .blue
        case 1: return .teal
        case 2: return .indigo
        case 3: return .orange
        default: return .gold
        }
    }

    /// Celebration SF Symbol, total over all Int XP. Same symbols the
    /// legacy title-matching produced, so re-narrated titles keep their
    /// established chrome.
    static func symbol(forXP xp: Int) -> String {
        switch bandIndex(forXP: xp) {
        case 0: return "sparkles"
        case 1: return "figure.stand"
        case 2: return "waveform.path.ecg"
        case 3: return "shield.lefthalf.filled"
        default: return "crown.fill"
        }
    }

    private static func xpToNextLevel(forXP xp: Int) -> Int {
        xpPerLevel - (max(0, xp) % xpPerLevel)
    }

    private static func bandIndex(forXP xp: Int) -> Int {
        min((max(0, xp) / xpPerLevel) / levelsPerBand, PracticeVolumeTintBand.allCases.count - 1)
    }
}

// MARK: - Post-rep progression gate

/// Full-screen post-rep progression is retired. Earned events persist and are
/// presented through the single inline Results receipt.
enum PostRepProgressionGate {

    static func shouldShowInterstitial(newUnlockCount: Int) -> Bool {
        _ = newUnlockCount
        return false
    }

    /// Drop-in for the legacy call shape. Every input is deliberately ignored.
    static func shouldShowInterstitial(
        xpEarned: Int,
        progressDeltaCount: Int,
        newUnlockCount: Int
    ) -> Bool {
        shouldShowInterstitial(newUnlockCount: newUnlockCount)
    }
}

// MARK: - Ledger role lines

/// One-sentence role narration for each input/proof surface, tying the
/// ledger UP the spine: passes unlock landmarks; landmarks build the skills
/// the rating measures; quotes are the evidence behind it.
///
/// `hasRatedEvidence == false` flips every spine reference to future
/// tense — no surface may reference a present-tense rating before
/// RatingStore has rated evidence (the day-0 cold-start honesty contract,
/// pinned by tests). Callers must pass the real gate, never a hardcoded
/// `true`.
enum LedgerRoleLines {

    /// Lesson crowns / practice passes (LessonsHomeView header, Passes pill).
    static func crownsRole(hasRatedEvidence: Bool) -> String {
        if hasRatedEvidence {
            return "Each pass drills one technique — passes unlock landmarks on your path, and landmarks build the skills your rating measures."
        }
        return "Each pass drills one technique — passes unlock landmarks on your path, and landmarks build the skills your rating will measure once it's earned."
    }

    /// Path landmarks (PathJourneyView "What this means" card). Landmarks
    /// are the coach's sequence — position, not a parallel score.
    static func landmarkRole(hasRatedEvidence: Bool) -> String {
        if hasRatedEvidence {
            return "Landmarks are your coach's sequence toward the skills your rating measures — a position on the path, not a second score."
        }
        return "Landmarks are your coach's sequence toward the skills your rating will measure once it's earned — a position on the path, not a second score."
    }

    /// Proof archive (Growth Library header, Profile insights chip).
    /// The banked count is an inventory, never a progress currency.
    static func proofRole(count: Int, hasRatedEvidence: Bool) -> String {
        let subject: String
        if count > 0 {
            subject = count == 1
                ? "1 verified line from your own reps"
                : "\(count) verified lines from your own reps"
        } else {
            subject = "Verified lines from your own reps"
        }
        if hasRatedEvidence {
            return "\(subject) — the evidence behind your rating."
        }
        return "\(subject) — the evidence your rating will stand on once it's earned."
    }
}
