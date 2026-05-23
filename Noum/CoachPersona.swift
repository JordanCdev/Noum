import Foundation

// MARK: - Coach Persona
//
// Per-voice persona data model — the £130/hr coach's character traits,
// signature openings, signature closings, and the reflective lead-in
// the coach uses when reading back a rep. Until this push the
// personality was a single `coachPersonality(for:)` string lookup
// inside `CoachContextBuilder`; that's fine for the system prompt but
// useless when a non-AI surface (the deterministic post-rep note, a
// future coach letter renderer, the Big Moment landing copy) needs
// pieces of the same coach voice.
//
// `CoachPersona` is the wrapper. Pure data, pure functions, ZERO UI.
// Six voices + nil fallback, each carrying:
//   • `registerName`     — what to call this voice in a debug surface
//   • `signatureTone`    — one-sentence describing how the coach speaks
//   • `openings`         — 3-line catalogue of post-rep openings the
//                          coach uses (no exclamations, ≤90 chars)
//   • `closings`         — 3-line catalogue of post-rep closings
//   • `reflectionLead`   — the phrase the coach uses to introduce a
//                          read of the rep ("Here's what I saw —")
//
// Used by:
//   • `PostRepCoachNoteService` (deterministic + AI fallback path)
//   • Future renderers that need the coach's voice without prompting
//     a model.

@available(iOS 17.0, macOS 12.0, *)
struct CoachPersona: Equatable {
    let voice: SpeakingStyleGoal?
    let registerName: String
    let signatureTone: String
    let openings: [String]
    let closings: [String]
    let reflectionLead: String

    // MARK: - Catalogue

    /// Resolve a persona for the user's voice. Nil voice → `default`
    /// persona (calm, direct, brand-aligned but not yet tuned).
    static func persona(for voice: SpeakingStyleGoal?) -> CoachPersona {
        guard let voice else { return .default }
        switch voice {
        case .authoritative: return .authoritative
        case .warm:          return .warm
        case .concise:       return .concise
        case .persuasive:    return .persuasive
        case .executive:     return .executive
        case .storytelling:  return .storytelling
        }
    }

    // MARK: - Per-voice instances

    static let `default` = CoachPersona(
        voice: nil,
        registerName: "Default",
        signatureTone: "Calm, direct, curious. No gushing, no chirpy filler.",
        openings: [
            "Here's the read.",
            "Quick note on that rep.",
            "Worth flagging from that one."
        ],
        closings: [
            "That's where I'd push next.",
            "Carry that into the next rep.",
            "Hold that thread tomorrow."
        ],
        reflectionLead: "Here's what stood out:"
    )

    static let authoritative = CoachPersona(
        voice: .authoritative,
        registerName: "Authoritative",
        signatureTone: "Senior advisor. Verdict-shaped. No hedging.",
        openings: [
            "Here's my read.",
            "Verdict on that rep.",
            "Straight from the tape:"
        ],
        closings: [
            "That's the move.",
            "Build on that.",
            "Own that line next time."
        ],
        reflectionLead: "What I observed:"
    )

    static let warm = CoachPersona(
        voice: .warm,
        registerName: "Warm",
        signatureTone: "Trusted mentor. Curious. Notices the small wins.",
        openings: [
            "How did that one feel?",
            "Sitting with that rep for a moment —",
            "A few things I noticed:"
        ],
        closings: [
            "You're closer than you think.",
            "Try one more like that.",
            "Keep that texture in mind tomorrow."
        ],
        reflectionLead: "Here's what came through:"
    )

    static let concise = CoachPersona(
        voice: .concise,
        registerName: "Concise",
        signatureTone: "Clipped. One idea per turn. Cuts filler before sending.",
        openings: [
            "Brief:",
            "Tight read:",
            "One line on that rep:"
        ],
        closings: [
            "Repeat that.",
            "Hold that pace.",
            "Same shape, next rep."
        ],
        reflectionLead: "What landed:"
    )

    static let persuasive = CoachPersona(
        voice: .persuasive,
        registerName: "Persuasive",
        signatureTone: "Structured. Premise, evidence, recommendation.",
        openings: [
            "Premise to start —",
            "Looking at the evidence:",
            "Here's the structured read:"
        ],
        closings: [
            "Recommendation: stay the line.",
            "That earns the next move.",
            "Carry that case forward."
        ],
        reflectionLead: "The evidence:"
    )

    static let executive = CoachPersona(
        voice: .executive,
        registerName: "Executive",
        signatureTone: "Chief-of-staff briefing. Top-line first.",
        openings: [
            "Top-line:",
            "Recommend reading this:",
            "Briefing on that rep:"
        ],
        closings: [
            "Recommend: hold the line.",
            "Carry the same shape tomorrow.",
            "Action: repeat under pressure."
        ],
        reflectionLead: "Top-line read:"
    )

    static let storytelling = CoachPersona(
        voice: .storytelling,
        registerName: "Storytelling",
        signatureTone: "Narrative. Speaks in arcs. Quotes the user's actual words.",
        openings: [
            "Picture the rep —",
            "Here's the arc I heard:",
            "There was a moment in that one:"
        ],
        closings: [
            "Carry that arc forward.",
            "Let that be the through-line.",
            "Tell it again, tighter."
        ],
        reflectionLead: "The story I heard:"
    )

    // MARK: - Random pick with stable seed

    /// Pick one opening from the catalogue using a stable seed (typically
    /// the session ID). Same seed → same line, so a rep's note doesn't
    /// shuffle text on every render.
    func opening(seed: Int) -> String {
        guard !openings.isEmpty else { return "" }
        let idx = abs(seed) % openings.count
        return openings[idx]
    }

    /// Pick one closing from the catalogue using a stable seed.
    func closing(seed: Int) -> String {
        guard !closings.isEmpty else { return "" }
        let idx = abs(seed) % closings.count
        return closings[idx]
    }
}
