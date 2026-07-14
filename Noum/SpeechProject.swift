import Foundation

// MARK: - Speech Projects
//
// Prepared speeches are structured around explicit objectives: opener,
// movement, vocal variety, storytelling, and persuasion. Each project has a
// duration target, a focus, and a scoring rubric.
//
// `SpeechProject` is the curated equivalent. Each project ships:
// - a clear focus
// - 3–5 concrete objectives the user reads BEFORE speaking
// - a duration target and minimum
// - a curated set of starter prompts
// - the practice mode it should run as
//
// The catalog is hand-authored. Future iterations could let the AI
// generate variations, but the v1 is a known-quality set.

struct SpeechProject: Identifiable, Hashable {
    let id: String
    let title: String
    let tagline: String
    let durationTarget: TimeInterval
    let durationMinimum: TimeInterval
    let focus: Focus
    let objectives: [String]
    let prompts: [String]
    let coachLine: String
    /// SF Symbol name for the project icon.
    let symbolName: String

    /// Mode the project runs through. Most are Timed (with structure).
    /// IM Mode is reserved for relationship-driven projects.
    var mode: PracticeMode { .timed }

    /// Prepared speeches reuse Timed's evaluator but bring their own honest
    /// evidence floor. Reaching the minimum is enough to avoid a false
    /// "too short" verdict; progress continues toward the stated target.
    var timedDurationTarget: TimedPracticeDurationTarget {
        TimedPracticeDurationTarget(
            minimum: durationMinimum,
            target: durationTarget
        )
    }

    enum Focus: String, Codable {
        case openingClose       // Ice Breaker, Inspire — opening and close
        case vocalVariety       // Pacing, pause, emphasis
        case structure          // Clear Point A → Point B → Point C
        case storytelling       // Concrete narrative arc
        case persuasion         // Argument + call to action
        case explanation        // Teach a topic at a level
        case impromptu          // Table topics — short, structured

        var label: String {
            switch self {
            case .openingClose:  return "Opening + close"
            case .vocalVariety:  return "Vocal variety"
            case .structure:     return "Structure"
            case .storytelling:  return "Storytelling"
            case .persuasion:    return "Persuasion"
            case .explanation:   return "Explanation"
            case .impromptu:     return "Impromptu"
            }
        }
    }
}

// MARK: - Catalog

enum SpeechProjects {
    /// Full catalog. Order matters — beginners-first; the home surface
    /// recommends in this order.
    static let all: [SpeechProject] = [
        iceBreaker,
        tableTopic,
        vocalVariety,
        bodyOfEvidence,
        storytellingArc,
        persuadeWithStructure,
        teachItIn90Seconds,
        inspireYourAudience
    ]

    static func project(id: String) -> SpeechProject? {
        all.first(where: { $0.id == id })
    }

    // MARK: Projects

    static let iceBreaker = SpeechProject(
        id: "ice_breaker",
        title: "Ice Breaker",
        tagline: "Introduce yourself in four to six minutes.",
        durationTarget: 6 * 60,
        durationMinimum: 4 * 60,
        focus: .openingClose,
        objectives: [
            "Open with a sentence that names you and a single specific detail.",
            "Develop one story or claim — not a list of credentials.",
            "Close on a sentence that reframes the opener.",
            "Stay between four and six minutes."
        ],
        prompts: [
            "Tell us who you are by way of a single moment that explains you.",
            "Introduce yourself through the work you do best — and why it suits you.",
            "Speak about the place that shaped you, then bring it back to today.",
            "Tell us about the person who taught you to think the way you do."
        ],
        coachLine: "The first speech is about being heard, not impressing. Land the opening, develop one thread, return to it at the end.",
        symbolName: "person.crop.circle.badge.plus"
    )

    static let tableTopic = SpeechProject(
        id: "table_topic",
        title: "Table Topic",
        tagline: "One to two minutes on a topic you didn't see coming.",
        durationTarget: 90,
        durationMinimum: 45,
        focus: .impromptu,
        objectives: [
            "Open with a clean answer in your first sentence.",
            "Pick one supporting reason or example — only one.",
            "Close with a sentence that points back to the prompt.",
            "Land between 45 and 90 seconds."
        ],
        prompts: [
            "What's the most useful thing you've learned this year?",
            "Describe a moment when changing your mind cost you something.",
            "What would you tell yourself ten years ago, in one sentence?",
            "If you had to teach a class on one thing tomorrow, what would it be?",
            "What's a habit you trust more than your own willpower?",
            "Describe a piece of advice that's aged badly.",
            "What's the difference between being good at something and being known for it?",
            "Name a question you've stopped asking, and why."
        ],
        coachLine: "Table Topics reward composure over content. Answer in the first sentence. Defend it in the second. Land it in the third.",
        symbolName: "questionmark.bubble.fill"
    )

    static let vocalVariety = SpeechProject(
        id: "vocal_variety",
        title: "Vocal Variety",
        tagline: "Five minutes where pace and pause do the heavy lifting.",
        durationTarget: 5 * 60,
        durationMinimum: 3 * 60,
        focus: .vocalVariety,
        objectives: [
            "Use at least three deliberate pauses longer than one second.",
            "Vary pace across the speech — slower for emphasis, faster for setup.",
            "Drop your voice on the most important sentence.",
            "Avoid filler words during transitions — pause instead."
        ],
        prompts: [
            "Talk about something you've changed your mind about — and stage the turn.",
            "Tell a story where the moment of realisation lands on a single, slow sentence.",
            "Describe a place using sound, not sight, for at least sixty seconds.",
            "Argue for an unpopular opinion with deliberate, paced restraint."
        ],
        coachLine: "Pace is rhetoric. The sentence you slow down becomes the sentence they remember.",
        symbolName: "waveform.path"
    )

    static let bodyOfEvidence = SpeechProject(
        id: "body_of_evidence",
        title: "Body of Evidence",
        tagline: "Three concrete pieces of evidence, in five minutes.",
        durationTarget: 5 * 60,
        durationMinimum: 3 * 60,
        focus: .structure,
        objectives: [
            "Open with the claim in a single sentence.",
            "Support with three specific examples — not generalities.",
            "Make each example land in under a minute.",
            "Close by collapsing the three examples into one principle."
        ],
        prompts: [
            "Make the case that the best decision in your career was the smallest one.",
            "Argue that experience is overrated, with three concrete reasons.",
            "Defend a colleague, mentor, or family member through three specific moments.",
            "Make an argument about your industry that's only true in three places."
        ],
        coachLine: "Vague support is no support. A speech earns the right to a conclusion only by spending three real examples on it.",
        symbolName: "list.number"
    )

    static let storytellingArc = SpeechProject(
        id: "storytelling_arc",
        title: "Storytelling Arc",
        tagline: "A real story with a setup, a turn, and a takeaway.",
        durationTarget: 6 * 60,
        durationMinimum: 4 * 60,
        focus: .storytelling,
        objectives: [
            "Set the scene in three sentences — then stop describing.",
            "Mark the turn — the moment something changed.",
            "Land the takeaway in a single sentence at the end.",
            "Use direct quoted dialogue at least once."
        ],
        prompts: [
            "Tell a story about a time you were wrong about a person.",
            "Describe a small failure that taught you a big lesson.",
            "Tell about a stranger who briefly changed how you saw your day.",
            "Describe the moment you first realised your work was more interesting than you'd given it credit for."
        ],
        coachLine: "A real story has a turn. Without the turn it's a description. Find the sentence where the speaker realises something.",
        symbolName: "book.pages.fill"
    )

    static let persuadeWithStructure = SpeechProject(
        id: "persuade_structure",
        title: "Persuade with Structure",
        tagline: "A five-minute argument that lands a request.",
        durationTarget: 5 * 60,
        durationMinimum: 3 * 60,
        focus: .persuasion,
        objectives: [
            "Open with the change you want the listener to make.",
            "Acknowledge the strongest counter-argument in one sentence.",
            "Use one statistic or one specific example — not both.",
            "Close by repeating the requested action verbatim."
        ],
        prompts: [
            "Persuade your team to adopt a habit you already practice.",
            "Make the case that one of your routines should be the company default.",
            "Argue for the addition of a recurring meeting your calendar doesn't have.",
            "Persuade your future self to keep doing the thing you'd be tempted to drop."
        ],
        coachLine: "Persuasion isn't loudness. It's repeating the same clean ask, with one piece of evidence, after acknowledging the strongest objection.",
        symbolName: "megaphone.fill"
    )

    static let teachItIn90Seconds = SpeechProject(
        id: "teach_in_90",
        title: "Teach It in 90",
        tagline: "Explain a complex idea in 90 seconds.",
        durationTarget: 90,
        durationMinimum: 60,
        focus: .explanation,
        objectives: [
            "Define the term in your first sentence.",
            "Use one analogy — not three.",
            "Give one practical example.",
            "Close by stating where the analogy breaks down."
        ],
        prompts: [
            "Explain a technical concept from your work to someone outside the field.",
            "Teach a habit that sounds simple but takes practice.",
            "Define a word that's used loosely, with the meaning you actually want.",
            "Explain something you understand well enough to teach but not yet to publish on."
        ],
        coachLine: "Teaching is not summarising. The hardest sentence in any explanation is the one that names where the analogy breaks down.",
        symbolName: "graduationcap.fill"
    )

    static let inspireYourAudience = SpeechProject(
        id: "inspire_audience",
        title: "Inspire Your Audience",
        tagline: "A close that earns its emotional ask.",
        durationTarget: 6 * 60,
        durationMinimum: 4 * 60,
        focus: .openingClose,
        objectives: [
            "Open with an image — not a thesis.",
            "Build to the emotional centre in the middle third.",
            "Use a rhetorical move (rule of three, anaphora, antithesis) at the climax.",
            "Close by returning to the opening image, transformed."
        ],
        prompts: [
            "Speak to a room of people doing the same job you do, on a hard week.",
            "Inspire a junior in your field on the day they think about quitting.",
            "Speak to your team about why this work, this year, matters more than usual.",
            "Address a roomful of people who don't yet know they're capable of more."
        ],
        coachLine: "Inspiration is earned. The image you open with should appear again at the close — changed by what you've said in between.",
        symbolName: "sparkles"
    )
}
