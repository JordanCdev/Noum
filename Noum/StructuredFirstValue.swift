import Foundation

/// Content dimensions that written rehearsal can support honestly. Delivery
/// dimensions such as pace, fillers, pauses, vocal tone, and composure are
/// intentionally absent.
enum StructuredFirstValueAxis: String, Codable, CaseIterable, Equatable {
    case directness
    case evidence
    case listening
    case ownership
    case constructiveness
    case inquiry
}

/// Authored, offline-capable first-value exercise for one speaking context.
/// The rubric names only content/structure dimensions that can be read from
/// writing without implying anything about the user's spoken delivery.
struct StructuredFirstValuePrompt: Equatable, Identifiable {
    let id: String
    let context: SpeakingContext
    let prompt: String
    let rubric: [StructuredFirstValueAxis]
}

enum StructuredFirstValueCatalog {
    static let prompts: [StructuredFirstValuePrompt] = [
        StructuredFirstValuePrompt(
            id: "work-clear-update",
            context: .work,
            prompt: "A colleague asks what needs attention this week. Give the main point, one reason, and a practical next step.",
            rubric: [.directness, .evidence, .constructiveness]
        ),
        StructuredFirstValuePrompt(
            id: "interview-specific-example",
            context: .interviews,
            prompt: "An interviewer asks about a difficult decision. State the decision, explain why you made it, and name what you learned.",
            rubric: [.directness, .evidence, .ownership]
        ),
        StructuredFirstValuePrompt(
            id: "presentation-core-message",
            context: .presentations,
            prompt: "Open a short presentation by naming the main message, one supporting fact, and what the audience should do next.",
            rubric: [.directness, .evidence, .constructiveness]
        ),
        StructuredFirstValuePrompt(
            id: "social-supportive-response",
            context: .social,
            prompt: "A friend says they have had a difficult week. Acknowledge what they shared, respond helpfully, and ask one genuine question.",
            rubric: [.listening, .constructiveness, .inquiry]
        ),
    ]

    static func prompt(for context: SpeakingContext) -> StructuredFirstValuePrompt {
        // The catalog is exhaustive over `SpeakingContext`; retain a calm,
        // truthful work fallback as a defensive release guard if a future enum
        // case is added without its authored prompt in the same change.
        prompts.first(where: { $0.context == context }) ?? prompts[0]
    }
}

/// The only persisted projection of a written first-value result. It carries
/// authored identifiers and a bounded word count, never the user's response or
/// a synthetic score.
struct StructuredFirstValueMetadata: Codable, Equatable {
    let promptID: String
    let wordCount: Int
    let strengthAxis: StructuredFirstValueAxis?
    let nextAxis: StructuredFirstValueAxis?

    init(
        promptID: String,
        wordCount: Int,
        strengthAxis: StructuredFirstValueAxis? = nil,
        nextAxis: StructuredFirstValueAxis? = nil
    ) {
        self.promptID = promptID
        // Content-free telemetry still needs a hard numeric bound: callers
        // outside the UI must not be able to grow the persisted receipt with
        // an arbitrary integer.
        self.wordCount = min(600, max(0, wordCount))
        self.strengthAxis = strengthAxis
        self.nextAxis = nextAxis
    }
}

/// Structure-only feedback returned to the fast-lane UI. There is deliberately
/// no score field: thin typed evidence earns one supported strength and one
/// next move, not pseudo-precision.
struct StructuredFirstValueResult: Equatable {
    let promptID: String
    let wordCount: Int
    let strengthAxis: StructuredFirstValueAxis
    let nextAxis: StructuredFirstValueAxis
    let strength: String
    let nextMove: String

    var metadata: StructuredFirstValueMetadata {
        StructuredFirstValueMetadata(
            promptID: promptID,
            wordCount: wordCount,
            strengthAxis: strengthAxis,
            nextAxis: nextAxis
        )
    }

    static let scopeNote = "This read covers the shape of your written response only."
}
