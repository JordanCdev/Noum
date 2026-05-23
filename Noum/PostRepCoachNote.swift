import Foundation

// MARK: - PostRepCoachNote
//
// A single short coaching note tied to one rep — the £130/hr coach
// turning toward the user and saying "here's what I just saw." 2
// sentences max, voice-shaped, honest about provenance (AI vs
// deterministic rule-based).
//
// Persisted per-account by `PostRepCoachNoteStore`. Surfaced in the
// Summary screen as a hero "Coach's Read" card, and quoted back to
// the persistent coach via `CoachContextBuilder.userContext`'s LAST
// REP NOTE section so the AI coach can build on its own prior read
// instead of starting fresh every chat.
//
// Codable for persistence; legacy persisted sessions decode without
// it because the field doesn't live on `PracticeSession` — the store
// is the source of truth, keyed by sessionID.

@available(iOS 17.0, macOS 12.0, *)
struct PostRepCoachNote: Codable, Equatable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let voice: SpeakingStyleGoal?
    let noteText: String
    let isAIBacked: Bool
    let generatedAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        voice: SpeakingStyleGoal?,
        noteText: String,
        isAIBacked: Bool,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.voice = voice
        self.noteText = noteText
        self.isAIBacked = isAIBacked
        self.generatedAt = generatedAt
    }
}
