import Foundation

// MARK: - Lesson Model
//
// Short, technique-focused lessons that teach a single rhetorical or delivery
// move. Each lesson is 3 progressive steps:
//
//  1. **Concept** — read what the technique is and why it works.
//  2. **Spot it** — multiple-choice: identify the technique in candidate
//     sentences. The user is doing recognition, not production.
//  3. **Apply** — speak a 30–45s answer using the technique. The
//     `EloquenceEngine` validates that the user actually used it.
//
// Mastery is tracked per-lesson as 0–5 practice passes. Each successful pass
// through all steps raises the count by 1, capped at 5. Progress persists
// per-account.

struct Lesson: Identifiable, Hashable {
    let id: String
    let title: String
    /// One-sentence teaser shown on the catalog row.
    let tagline: String
    /// Theme — used for grouping + icon colouring.
    let category: Category
    /// SF Symbol for the catalog row + lesson hero.
    let symbolName: String
    /// Ordered steps the user works through.
    let steps: [Step]
    /// Devices the user is expected to demonstrate in the Apply step.
    /// Nil when the lesson isn't about a specific eloquence device
    /// (e.g. pause-instead-of-filler is a delivery move, not a device).
    let targetDevice: EloquenceDevice?

    enum Category: String, Codable, CaseIterable {
        case delivery       // pacing, pause, filler control
        case structure      // openings, closes, parallelism
        case rhetoric       // tricolon, anaphora, etc.

        var label: String {
            switch self {
            case .delivery:  return "Delivery"
            case .structure: return "Structure"
            case .rhetoric:  return "Rhetoric"
            }
        }
    }

    enum Step: Hashable {
        /// Concept step. Plain copy + a short example sentence the user
        /// can read aloud to feel the rhythm.
        case concept(headline: String, body: String, example: String?)

        /// Multiple-choice "spot it". Three candidate sentences, exactly
        /// one of which uses the target device.
        case spotIt(question: String, options: [Option])

        /// Apply step. The user records a short answer using the technique.
        /// The EloquenceEngine validates whether they actually used the
        /// `expectedDevice` (or, for delivery lessons, a free-form pass).
        case apply(prompt: String, expectedDevice: EloquenceDevice?, durationTarget: TimeInterval)

        struct Option: Hashable {
            let text: String
            let isCorrect: Bool
            /// Why this option is right or wrong — shown as feedback after
            /// the user picks. Coach voice, never apologetic.
            let explanation: String
        }
    }
}

// MARK: - Lesson Outcome

/// Result of one full pass through a lesson. Used by `LessonStore` to
/// raise practice-pass progress and by the celebration overlay to render
/// the cleared/mastered moment.
struct LessonOutcome: Equatable {
    let lessonID: String
    let stepResults: [StepResult]
    let xpEarned: Int

    var isPerfect: Bool {
        stepResults.allSatisfy(\.passed)
    }

    var passed: Bool {
        // A lesson is "passed" if the user got the spot-it step right and
        // demonstrated the technique on the apply step (when applicable).
        stepResults.allSatisfy { $0.passed || $0.kind == .concept }
    }

    enum StepResult: Equatable {
        case concept
        case spotIt(passed: Bool)
        case apply(passed: Bool, didUseDevice: Bool)

        var passed: Bool {
            switch self {
            case .concept: return true // concept step is read-through, can't fail
            case .spotIt(let passed): return passed
            case .apply(let passed, _): return passed
            }
        }

        var kind: Kind {
            switch self {
            case .concept: return .concept
            case .spotIt: return .spotIt
            case .apply: return .apply
            }
        }

        enum Kind { case concept, spotIt, apply }
    }
}

// MARK: - Lesson XP

enum LessonXP {
    /// Base XP for a lesson pass. Lower than a full session — lessons are
    /// short. Bonus stacks on a perfect run (right answer first time on
    /// spot-it AND device demonstrated on apply).
    static let baseXP = 30
    static let perfectBonus = 20

    static func xp(for outcome: LessonOutcome) -> Int {
        var xp = baseXP
        if outcome.isPerfect { xp += perfectBonus }
        return xp
    }
}
