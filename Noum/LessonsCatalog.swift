import Foundation

// MARK: - Lessons Catalog
//
// Five hand-authored lessons — the v1 curriculum. Order is the recommended
// sequence (delivery first, then structure, then rhetoric). Each lesson
// follows the same 3-step pattern: Concept → Spot it → Apply.
//
// Adding new lessons later is a question of appending to `all`. The lesson
// engine is purely data-driven; UI and progression don't need to change.

enum LessonsCatalog {
    static let all: [Lesson] = [
        pauseBeatsFiller,
        ruleOfThree,
        repeatToStick,
        frameTheOpen,
        landTheClose
    ]

    static func lesson(id: String) -> Lesson? {
        all.first(where: { $0.id == id })
    }

    // MARK: 1. Pause Beats Filler

    static let pauseBeatsFiller = Lesson(
        id: "pause_beats_filler",
        title: "Pause Beats Filler",
        tagline: "Replace \"um\" with silence. Three breaths in, six seconds long.",
        category: .delivery,
        symbolName: "pause.fill",
        steps: [
            .concept(
                headline: "Why a pause works",
                body: "A filler word fills space. A pause shapes it. Listeners read silence as composure — they think you chose the pause. \"Um\" reads as searching; one second of nothing reads as decision.",
                example: "What I want to say is — [one beat] — we ship Friday."
            ),
            .spotIt(
                question: "Which of these uses pause instead of filler?",
                options: [
                    .init(
                        text: "So um I think the answer is yes for sure.",
                        isCorrect: false,
                        explanation: "\"Um\" is doing the work of a pause but listeners read it as hesitation."
                    ),
                    .init(
                        text: "I think the answer is — yes.",
                        isCorrect: true,
                        explanation: "The dash is a held beat. The yes lands harder for it."
                    ),
                    .init(
                        text: "Like, basically, you know, yes.",
                        isCorrect: false,
                        explanation: "Three discourse markers on top of each other — the \"yes\" is buried."
                    )
                ]
            ),
            .apply(
                prompt: "Answer in 30 seconds: \"What's the most useful habit you've built this year?\" Use a pause instead of a filler before each main point.",
                expectedDevice: nil,
                durationTarget: 30
            )
        ],
        targetDevice: nil
    )

    // MARK: 2. Rule of Three

    static let ruleOfThree = Lesson(
        id: "rule_of_three",
        title: "Rule of Three",
        tagline: "Two examples sound thin. Three sound complete.",
        category: .rhetoric,
        symbolName: "3.circle.fill",
        steps: [
            .concept(
                headline: "Why three lands",
                body: "Two items feel like a list that hasn't finished. Three items feel like a complete idea. The third item is what tells the listener you're done — without you saying \"that's all\".",
                example: "Liberty, equality, fraternity. Fast, cheap, good. Calm, clear, credible."
            ),
            .spotIt(
                question: "Which sentence uses the rule of three?",
                options: [
                    .init(
                        text: "We need to ship faster and with better quality.",
                        isCorrect: false,
                        explanation: "Two items — it sounds like the speaker hasn't quite landed it."
                    ),
                    .init(
                        text: "We need to ship faster, ship cleaner, and ship more often.",
                        isCorrect: true,
                        explanation: "Three parallel items. The third one signals \"that's the full picture\"."
                    ),
                    .init(
                        text: "We need to ship faster, with quality and frequency.",
                        isCorrect: false,
                        explanation: "Three items but the structure isn't parallel — the listener doesn't get the rhythm."
                    )
                ]
            ),
            .apply(
                prompt: "In 30 seconds, answer: \"What's most important about the work you do?\" Use three parallel items.",
                expectedDevice: .tricolon,
                durationTarget: 30
            )
        ],
        targetDevice: .tricolon
    )

    // MARK: 3. Repeat to Stick

    static let repeatToStick = Lesson(
        id: "repeat_to_stick",
        title: "Repeat to Stick",
        tagline: "Same opener, three sentences in a row. The point lands.",
        category: .rhetoric,
        symbolName: "arrow.forward.circle.fill",
        steps: [
            .concept(
                headline: "Anaphora — opening repetition",
                body: "Repeating the first word or phrase across consecutive sentences turns rhythm into emphasis. It tells the listener \"this is the same idea, three times, building.\" Used badly it sounds like a chant. Used well it's the most memorable sentence in your speech.",
                example: "We'll show up. We'll prepare. We'll deliver."
            ),
            .spotIt(
                question: "Which uses anaphora?",
                options: [
                    .init(
                        text: "I will plan, then prepare, then deliver.",
                        isCorrect: false,
                        explanation: "Three actions but only one verb leads — no repeated opener."
                    ),
                    .init(
                        text: "I will plan. I will prepare. I will deliver.",
                        isCorrect: true,
                        explanation: "Same opener, three sentences. Each \"I will\" reinforces the last."
                    ),
                    .init(
                        text: "I will deliver, deliver, deliver.",
                        isCorrect: false,
                        explanation: "That's epizeuxis — back-to-back repetition. Different move."
                    )
                ]
            ),
            .apply(
                prompt: "Answer in 30 seconds: \"What does this team do at its best?\" Open three consecutive sentences with the same two words.",
                expectedDevice: .anaphora,
                durationTarget: 30
            )
        ],
        targetDevice: .anaphora
    )

    // MARK: 4. Frame the Open

    static let frameTheOpen = Lesson(
        id: "frame_the_open",
        title: "Frame the Open",
        tagline: "First sentence does the work. The rest defends it.",
        category: .structure,
        symbolName: "text.alignleft",
        steps: [
            .concept(
                headline: "Lead with the answer",
                body: "Most weak openings warm up to the point. Strong openings *are* the point. Say the answer in your first sentence. The rest of the speech is defence and detail.",
                example: "Yes, we should ship Friday. Here's why in three reasons."
            ),
            .spotIt(
                question: "Which opens with a clean answer?",
                options: [
                    .init(
                        text: "So I've been thinking about this for a while, and there's a lot to consider…",
                        isCorrect: false,
                        explanation: "Throat-clearing. The listener has heard nothing yet."
                    ),
                    .init(
                        text: "We should ship Friday. The risk is real, but the cost of waiting is bigger.",
                        isCorrect: true,
                        explanation: "Answer first sentence. Defence second. Listener already knows your position."
                    ),
                    .init(
                        text: "There's a question about whether we should ship Friday.",
                        isCorrect: false,
                        explanation: "Restating the question is the most common stall. The opening should answer it."
                    )
                ]
            ),
            .apply(
                prompt: "Answer in 30 seconds: \"Should the team prioritise speed or polish?\" Make your first sentence the full answer.",
                expectedDevice: nil,
                durationTarget: 30
            )
        ],
        targetDevice: nil
    )

    // MARK: 5. Land the Close

    static let landTheClose = Lesson(
        id: "land_the_close",
        title: "Land the Close",
        tagline: "Return to the opener. Transformed.",
        category: .structure,
        symbolName: "text.alignright",
        steps: [
            .concept(
                headline: "End where you started — but changed",
                body: "The strongest closes echo the opening sentence with new weight. The listener remembers the first sentence and the last; making them rhyme makes the whole speech feel intentional.",
                example: "Open: \"This work is hard.\" Close: \"This work is still hard. But we're not the same people we were when we started.\""
            ),
            .spotIt(
                question: "Which close lands?",
                options: [
                    .init(
                        text: "So yeah, that's basically what I wanted to say.",
                        isCorrect: false,
                        explanation: "Apologising for finishing — and finishing on \"yeah, basically\". The point dissolves."
                    ),
                    .init(
                        text: "We started with one question. We end with one answer.",
                        isCorrect: true,
                        explanation: "Echo + transformation. The listener feels the speech finished where it began, with weight."
                    ),
                    .init(
                        text: "Thanks everyone, that's all I had.",
                        isCorrect: false,
                        explanation: "Polite, but the speech ends on the speaker, not the idea."
                    )
                ]
            ),
            .apply(
                prompt: "Open with \"Today, we're behind on this.\" Speak for 30 seconds. Close with a sentence that echoes \"Today, we're …\" — but says something different.",
                expectedDevice: nil,
                durationTarget: 30
            )
        ],
        targetDevice: nil
    )
}
