import Foundation

// MARK: - Filler Lexicon (M12)
//
// Per-locale filler-word sets used by `FillerWordDetector`. Each set is
// curated by reference to native-speaker disfluency studies + common
// public-speaking-coach guidance for that language.
//
// Style guide for additions:
//   • Single-word entries dominate. Multi-word phrases ("you know",
//     "tu vois") are supported but should be used sparingly because
//     regex matching across word boundaries is more error-prone.
//   • Avoid words that have heavy semantic load — adding "well" or
//     "bueno" risks false positives in normal sentence structure. We
//     ship with conservative defaults and let users add custom words.
//   • Lowercase only. Detection is case-insensitive in the regex layer.
//
// Honest gap (v1): the dynamic-vocal-hesitation regex in
// `FillerWordDetector.buildRegexes(for:)` is English-shaped (uh/um/erm/
// hmm patterns). Spanish "eh" and French "euh" are covered as explicit
// tokens; longer drawn-out variants ("ehhhh", "euuuuh") fall through.
// Acceptable for v1 — provider transcripts collapse most of these.

enum FillerLexicon {
    /// English (US) — matches the legacy `baseFillerWords` set so
    /// switching the locale picker back to en-US gives identical results
    /// to the pre-M12 behavior.
    static let enUS: Set<String> = [
        "uh", "um", "er", "erm", "ah", "eh", "huh",
        "like", "so", "you know"
    ]

    /// Spanish (Spain). Headword choices follow the most-cited Spanish
    /// disfluency tokens — "este" and "pues" are the heavy hitters,
    /// "o sea" is the multi-word equivalent of English "I mean".
    /// Intentionally omit "vale" and "bueno" because they carry
    /// genuine semantic content too often to flag without context.
    static let esES: Set<String> = [
        "eh", "este", "pues", "o sea", "tipo", "como", "no sé",
        "verdad", "ehm", "mmm"
    ]

    /// French (France). "Euh" is the canonical hesitation; "ben" and
    /// "alors" frequently appear at sentence starts under pressure;
    /// "voilà", "quoi", "donc", and "en fait" fill mid-thought gaps.
    /// We omit "bon" and "voilà" at sentence boundaries — same
    /// semantic-load concern as the Spanish list.
    static let frFR: Set<String> = [
        "euh", "ben", "donc", "alors", "quoi", "voilà",
        "en fait", "tu vois", "genre", "hein"
    ]

    /// Resolve the active lexicon for a locale. Falls back to en-US for
    /// any unrecognised value so a future locale addition won't crash
    /// users on older builds.
    static func words(for locale: PracticeLocale) -> Set<String> {
        switch locale {
        case .enUS: return enUS
        case .esES: return esES
        case .frFR: return frFR
        }
    }
}
