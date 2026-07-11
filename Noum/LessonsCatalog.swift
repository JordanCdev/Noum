import Foundation

// MARK: - Lessons Catalog
//
// A communication curriculum spanning delivery, structure, interaction,
// explanation, and rhetoric. Order alternates outward-facing conversation
// skills with speaking mechanics so the learner does not mistake polished
// monologue for complete communication. Each lesson
// follows the same 3-step pattern: Concept → Spot it → Apply.
//
// Adding new lessons later is a question of appending to `all`. The lesson
// engine is purely data-driven; UI and progression don't need to change.

enum LessonsCatalog {
    static let all: [Lesson] = [
        pauseBeatsFiller,
        listenForMeaning,
        frameTheOpen,
        askABetterQuestion,
        makeItPlain,
        checkUnderstanding,
        ruleOfThree,
        giveUsefulFeedback,
        repeatToStick,
        setAClearBoundary,
        landTheClose,
        repairTheConversation
    ]

    static func lesson(id: String) -> Lesson? {
        all.first(where: { $0.id == id })
    }

    // MARK: 1. Pause Beats Filler

    static let pauseBeatsFiller = Lesson(
        id: "pause_beats_filler",
        title: "Pause Beats Filler",
        tagline: "Use one quiet beat when you need time to think.",
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
        targetDevice: nil,
        transferPrompt: "In your next conversation, let one full beat pass before your main point.",
        applyCriteria: [
            .init(
                id: "pause.complete",
                title: "Complete thought",
                kind: .minimumWords(18),
                successFeedback: "You gave the answer enough room to breathe.",
                retryFeedback: "Keep going until one complete thought lands."
            ),
            .init(
                id: "pause.filler",
                title: "Clean space",
                kind: .maximumFillers(1),
                successFeedback: "The transcript stayed clear of repeated filler.",
                retryFeedback: "Try again and replace the next filler with one silent beat."
            )
        ],
        reviewPrompts: [
            "Answer in 30 seconds: “What decision did you change your mind about?” Let one quiet beat replace each filler before a main point."
        ]
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
        targetDevice: .tricolon,
        transferPrompt: "Use a three-part list when you next need to make a recommendation memorable.",
        reviewPrompts: [
            "In 30 seconds, answer: “What should a new teammate know about this work?” Use three parallel items."
        ]
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
        targetDevice: .anaphora,
        transferPrompt: "Repeat the same short opener across two or three sentences in your next high-stakes explanation.",
        reviewPrompts: [
            "Answer in 30 seconds: “What must this project protect?” Open three consecutive sentences with the same short phrase."
        ]
    )

    // MARK: 4. Frame the Open

    static let frameTheOpen = Lesson(
        id: "frame_the_open",
        title: "Frame the Open",
        tagline: "Lead with the answer. Use the rest to support it.",
        category: .structure,
        symbolName: "text.alignleft",
        steps: [
            .concept(
                headline: "Lead with the answer",
                body: "Most weak openings warm up to the point. Strong openings *are* the point. Say the answer in your first sentence. The rest of the speech is support and detail.",
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
                        explanation: "Answer first sentence. Support second. The listener already knows your position."
                    ),
                    .init(
                        text: "There's a question about whether we should ship Friday.",
                        isCorrect: false,
                        explanation: "Restating the question is the most common stall. The opening should answer it."
                    )
                ]
            ),
            .apply(
                prompt: "Answer in 30 seconds: \"Should the team prioritize speed or polish?\" Make your first sentence the full answer.",
                expectedDevice: nil,
                durationTarget: 30
            )
        ],
        targetDevice: nil,
        transferPrompt: "In your next update, make the first sentence your full answer.",
        applyCriteria: [
            .init(
                id: "open.complete",
                title: "Complete answer",
                kind: .minimumWords(18),
                successFeedback: "You supported the opening with a complete answer.",
                retryFeedback: "Add enough support for the opening to stand up."
            ),
            .init(
                id: "open.direct",
                title: "Answer first",
                kind: .directOpening,
                successFeedback: "The response opened without throat-clearing.",
                retryFeedback: "Start with your position, not the thinking that led to it."
            )
        ],
        reviewPrompts: [
            "Answer in 30 seconds: “Should this weekly meeting be shorter?” Make the first sentence your full answer."
        ]
    )

    // MARK: 5. Land the Close

    static let landTheClose = Lesson(
        id: "land_the_close",
        title: "Land the Close",
        tagline: "Echo the opening so the ending feels intentional.",
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
                        explanation: "Apologizing for finishing — and finishing on \"yeah, basically\". The point dissolves."
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
        targetDevice: nil,
        transferPrompt: "Before your next important conversation, decide the final sentence you want remembered.",
        applyCriteria: [
            .init(
                id: "close.complete",
                title: "Complete arc",
                kind: .minimumWords(20),
                successFeedback: "The answer had enough shape for the close to carry weight.",
                retryFeedback: "Build one complete thought before you return to the opening."
            ),
            .init(
                id: "close.echo",
                title: "Echo the opening",
                kind: .containsAny(["today we're", "today we are"]),
                successFeedback: "The closing returned to the words that opened the answer.",
                retryFeedback: "Bring back “Today, we're…” in the final sentence."
            )
        ],
        reviewPrompts: [
            "Open with “This plan is ambitious.” Speak for 30 seconds, then close by returning to “This plan…” with a changed meaning."
        ]
    )

    // MARK: - Listen for Meaning

    static let listenForMeaning = Lesson(
        id: "listen_for_meaning",
        title: "Listen for Meaning",
        tagline: "Reflect the point before you add your own.",
        category: .interaction,
        symbolName: "ear.badge.waveform",
        steps: [
            .concept(
                headline: "Prove you heard the point",
                body: "Active listening is not silent waiting. Briefly name what the other person means, then check that you understood. That lowers the chance of answering the wrong concern.",
                example: "It sounds like the missed handoff matters more than the delay itself. Did I get that right?"
            ),
            .spotIt(
                question: "Which response listens before solving?",
                options: [
                    .init(
                        text: "You should move the deadline and tell the team today.",
                        isCorrect: false,
                        explanation: "It jumps to advice before confirming the real concern."
                    ),
                    .init(
                        text: "It sounds like the uncertainty is the hardest part. Is that right?",
                        isCorrect: true,
                        explanation: "It reflects the meaning and gives the other person room to correct it."
                    ),
                    .init(
                        text: "I know exactly how you feel; the same thing happened to me.",
                        isCorrect: false,
                        explanation: "It redirects attention to the speaker's own experience."
                    )
                ]
            ),
            .apply(
                prompt: "A teammate says: “I can handle the workload. I just hate finding out about changes after everyone else.” Respond by reflecting the meaning and checking that you understood.",
                expectedDevice: nil,
                durationTarget: 30
            )
        ],
        targetDevice: nil,
        transferPrompt: "In your next conversation, paraphrase one concern before offering your view.",
        applyCriteria: [
            .init(
                id: "listen.complete",
                title: "Full response",
                kind: .minimumWords(14),
                successFeedback: "You stayed with the concern long enough to respond to it.",
                retryFeedback: "Give the reflection and the check in one complete response."
            ),
            .init(
                id: "listen.reflect",
                title: "Reflect the meaning",
                kind: .containsAny(["it sounds like", "what i'm hearing", "what i hear", "you are saying", "the part that matters", "the real concern"]),
                successFeedback: "You put the other person's meaning into your own words.",
                retryFeedback: "Start with “It sounds like…” or “What I'm hearing is…”."
            ),
            .init(
                id: "listen.check",
                title: "Check your read",
                kind: .minimumQuestionSignals(1),
                successFeedback: "You left room for the other person to correct your read.",
                retryFeedback: "End with a short check such as “Did I get that right?”"
            )
        ],
        reviewPrompts: [
            "A colleague says: “The deadline is manageable. I am worried nobody agrees on what finished means.” Reflect the meaning and check your understanding."
        ]
    )

    // MARK: - Ask a Better Question

    static let askABetterQuestion = Lesson(
        id: "ask_a_better_question",
        title: "Ask a Better Question",
        tagline: "Open the subject, then clarify what matters.",
        category: .interaction,
        symbolName: "questionmark.bubble",
        steps: [
            .concept(
                headline: "Use questions to discover, not corner",
                body: "Begin with an open question that invites detail. Follow with one focused question based on what you heard. The second question is what makes the exchange feel attentive rather than scripted.",
                example: "What made the launch difficult? Which handoff created the most risk?"
            ),
            .spotIt(
                question: "Which pair creates a useful follow-up?",
                options: [
                    .init(
                        text: "Was the meeting bad? Did people dislike it?",
                        isCorrect: false,
                        explanation: "Both questions push toward a yes-or-no judgment."
                    ),
                    .init(
                        text: "What changed in the meeting? Which moment shifted the room?",
                        isCorrect: true,
                        explanation: "The first opens the subject; the second narrows to a revealing detail."
                    ),
                    .init(
                        text: "Why didn't you prepare more? Whose fault was it?",
                        isCorrect: false,
                        explanation: "The questions assign blame before they build understanding."
                    )
                ]
            ),
            .apply(
                prompt: "A colleague says a client call went differently than expected. Ask one open question, then one focused follow-up that would uncover what changed.",
                expectedDevice: nil,
                durationTarget: 25
            )
        ],
        targetDevice: nil,
        transferPrompt: "Ask one open question in your next conversation, then make the follow-up depend on the answer.",
        applyCriteria: [
            .init(
                id: "question.complete",
                title: "Two clear questions",
                kind: .minimumWords(10),
                successFeedback: "The questions had enough context to be useful.",
                retryFeedback: "Give both questions as complete sentences."
            ),
            .init(
                id: "question.count",
                title: "Open, then focus",
                kind: .minimumQuestionSignals(2),
                successFeedback: "You asked an opening question and a follow-up.",
                retryFeedback: "Ask two questions: one broad, then one more specific."
            ),
            .init(
                id: "question.neutral",
                title: "Keep it neutral",
                kind: .avoidsAny(["whose fault", "why didn't you", "did you fail", "was it bad"]),
                successFeedback: "The wording invited detail without assigning blame.",
                retryFeedback: "Remove the judgment and ask what happened instead."
            )
        ],
        reviewPrompts: [
            "A teammate says the project milestone felt harder than expected. Ask one open question, then one focused follow-up."
        ]
    )

    // MARK: - Check Understanding

    static let checkUnderstanding = Lesson(
        id: "check_understanding",
        title: "Check Understanding",
        tagline: "Close the loop before the work moves on.",
        category: .interaction,
        symbolName: "arrow.triangle.2.circlepath",
        steps: [
            .concept(
                headline: "Do not rely on “Got it”",
                body: "Important instructions deserve a closed loop. Say what you believe happens next, include the key detail, and invite correction. Repeating the meaning catches errors before they become rework.",
                example: "I'll send the revised draft by 3 p.m., and you'll review the numbers before it goes out. Is that the right sequence?"
            ),
            .spotIt(
                question: "Which response closes the loop?",
                options: [
                    .init(
                        text: "Understood. I'll take care of it.",
                        isCorrect: false,
                        explanation: "The speaker confirms confidence, not shared understanding."
                    ),
                    .init(
                        text: "I'll send the draft Thursday, then you approve it before Friday's meeting. Correct?",
                        isCorrect: true,
                        explanation: "It repeats the action and timing, then invites correction."
                    ),
                    .init(
                        text: "Can you send all of that in an email?",
                        isCorrect: false,
                        explanation: "Written detail may help, but the current understanding remains unchecked."
                    )
                ]
            ),
            .apply(
                prompt: "You are asked to send a revised proposal by Thursday at 3 p.m., after Finance confirms the final number. Close the loop in your own words.",
                expectedDevice: nil,
                durationTarget: 25
            )
        ],
        targetDevice: nil,
        transferPrompt: "At the end of your next handoff, state the owner, action, and timing in your own words.",
        applyCriteria: [
            .init(
                id: "check.action",
                title: "Repeat the action",
                kind: .containsAny(["send", "proposal", "revised"]),
                successFeedback: "You named the work that needs to happen.",
                retryFeedback: "Restate the action, not only that you understand."
            ),
            .init(
                id: "check.detail",
                title: "Keep the key detail",
                kind: .containsAny(["thursday", "3 p m", "three p m", "finance"]),
                successFeedback: "A timing or dependency detail survived the handoff.",
                retryFeedback: "Include the Thursday timing or Finance dependency."
            ),
            .init(
                id: "check.confirm",
                title: "Invite correction",
                kind: .containsAny(["is that right", "is that correct", "correct", "did i get", "right sequence"]),
                successFeedback: "You made it easy to correct a misunderstanding.",
                retryFeedback: "End by asking whether your understanding is correct."
            )
        ],
        reviewPrompts: [
            "You are asked to share the client notes by noon after Legal approves the wording. Close the loop with the action, dependency, and timing."
        ]
    )

    // MARK: - Make It Plain

    static let makeItPlain = Lesson(
        id: "make_it_plain",
        title: "Make It Plain",
        tagline: "Main point first. Familiar words. One useful example.",
        category: .explanation,
        symbolName: "person.wave.2",
        steps: [
            .concept(
                headline: "Clarity starts with the listener",
                body: "Choose what this listener needs first, not everything you know. Lead with the main message, use familiar words, and make one abstract idea concrete with an example.",
                example: "The change makes checkout faster. For example, returning customers can pay without entering their address again."
            ),
            .spotIt(
                question: "Which explanation is easiest to use?",
                options: [
                    .init(
                        text: "We leveraged a cross-functional optimization paradigm.",
                        isCorrect: false,
                        explanation: "The sentence names process language but not what changed for the listener."
                    ),
                    .init(
                        text: "The new process cuts one approval step. For example, routine requests can move the same day.",
                        isCorrect: true,
                        explanation: "Main point first, familiar words, then a concrete example."
                    ),
                    .init(
                        text: "There are several architectural considerations across multiple workstreams.",
                        isCorrect: false,
                        explanation: "It sounds complete while withholding the information the listener needs."
                    )
                ]
            ),
            .apply(
                prompt: "Explain a process you know well to a new teammate. Lead with why it matters, avoid internal jargon, and give one concrete example.",
                expectedDevice: nil,
                durationTarget: 35
            )
        ],
        targetDevice: nil,
        transferPrompt: "Before your next explanation, remove one term the listener would have to decode.",
        applyCriteria: [
            .init(
                id: "plain.length",
                title: "Keep the explanation focused",
                kind: .wordRange(minimum: 20, maximum: 80),
                successFeedback: "The explanation was developed without turning into a lecture.",
                retryFeedback: "Aim for one point and one example in 20 to 80 words."
            ),
            .init(
                id: "plain.example",
                title: "Make it concrete",
                kind: .containsAny(["for example", "for instance", "imagine", "that means", "in practice"]),
                successFeedback: "You connected the idea to something the listener can picture.",
                retryFeedback: "Add one example with “For example…” or “In practice…”."
            ),
            .init(
                id: "plain.jargon",
                title: "Use familiar words",
                kind: .avoidsAny(["leverage", "synergy", "paradigm", "utilize", "operationalize"]),
                successFeedback: "The answer avoided common abstraction and jargon.",
                retryFeedback: "Replace the abstract term with what actually happens."
            )
        ],
        reviewPrompts: [
            "Explain a tool you use often to a customer seeing it for the first time. Lead with why it matters and give one example."
        ]
    )

    // MARK: - Give Useful Feedback

    static let giveUsefulFeedback = Lesson(
        id: "give_useful_feedback",
        title: "Give Useful Feedback",
        tagline: "Name the behavior, the impact, and the next move.",
        category: .interaction,
        symbolName: "quote.bubble",
        steps: [
            .concept(
                headline: "Make feedback usable",
                body: "Describe a specific behavior without labeling the person. Explain the impact, then make a clear request. The listener should know what happened and what to do differently.",
                example: "When the decision changed after the meeting, the team repeated two days of work. Next time, could you flag the change before we close the plan?"
            ),
            .spotIt(
                question: "Which feedback gives the listener a next move?",
                options: [
                    .init(
                        text: "You're unreliable and need to communicate better.",
                        isCorrect: false,
                        explanation: "It labels the person and leaves the desired behavior unclear."
                    ),
                    .init(
                        text: "When the update arrived after the deadline, I sent the wrong number. Next time, please message me before the cutoff.",
                        isCorrect: true,
                        explanation: "Specific behavior, concrete impact, clear request."
                    ),
                    .init(
                        text: "No worries, but maybe just be a bit more careful.",
                        isCorrect: false,
                        explanation: "The softening hides both the impact and the requested change."
                    )
                ]
            ),
            .apply(
                prompt: "A teammate changed a client slide after approval and you presented the old version. Give feedback using the behavior, its impact, and one request for next time.",
                expectedDevice: nil,
                durationTarget: 35
            )
        ],
        targetDevice: nil,
        transferPrompt: "Before your next feedback conversation, write one sentence each for behavior, impact, and request.",
        applyCriteria: [
            .init(
                id: "feedback.behavior",
                title: "Name the behavior",
                kind: .containsAny(["when you", "when the", "changed", "after approval"]),
                successFeedback: "You anchored the feedback to something observable.",
                retryFeedback: "Start with the specific action or moment, not a label."
            ),
            .init(
                id: "feedback.impact",
                title: "Explain the impact",
                kind: .containsAny(["meant", "impact", "because", "so i", "presented", "resulted"]),
                successFeedback: "You explained why the behavior mattered.",
                retryFeedback: "Add what the change caused for the work or the listener."
            ),
            .init(
                id: "feedback.request",
                title: "Make one request",
                kind: .containsAny(["next time", "could you", "please", "i need", "can you"]),
                successFeedback: "The listener has a clear next move.",
                retryFeedback: "Finish with one specific request for next time."
            )
        ],
        reviewPrompts: [
            "A teammate missed a handoff and the next team started late. Give feedback using the behavior, impact, and one request."
        ]
    )

    // MARK: - Set a Clear Boundary

    static let setAClearBoundary = Lesson(
        id: "set_a_clear_boundary",
        title: "Set a Clear Boundary",
        tagline: "State the limit without turning it into a fight.",
        category: .interaction,
        symbolName: "hand.raised",
        steps: [
            .concept(
                headline: "Clear is kinder than vague",
                body: "Name what you can or cannot do, give the relevant constraint, and offer a workable alternative when one exists. Do not bury the boundary in apology or invite a negotiation you cannot support.",
                example: "I can't deliver both versions by Friday. I can finish the client version Friday and the internal version Monday."
            ),
            .spotIt(
                question: "Which response sets a usable boundary?",
                options: [
                    .init(
                        text: "I'll try, but it might be difficult and I can't promise anything.",
                        isCorrect: false,
                        explanation: "The listener still cannot tell what will happen."
                    ),
                    .init(
                        text: "I can't take this on today without delaying the launch. I can review it tomorrow morning.",
                        isCorrect: true,
                        explanation: "The limit, reason, and alternative are all clear."
                    ),
                    .init(
                        text: "That's not my problem. Ask someone else.",
                        isCorrect: false,
                        explanation: "It rejects the person instead of stating a professional limit."
                    )
                ]
            ),
            .apply(
                prompt: "Your manager asks for a second urgent report today, but accepting it would delay a client deadline. Set the boundary and offer one realistic alternative.",
                expectedDevice: nil,
                durationTarget: 30
            )
        ],
        targetDevice: nil,
        transferPrompt: "For your next difficult request, decide the limit and one alternative before you respond.",
        applyCriteria: [
            .init(
                id: "boundary.limit",
                title: "State the limit",
                kind: .containsAny(["i can't", "i cannot", "i can", "not able", "won't be able"]),
                successFeedback: "The listener can tell exactly what is and is not possible.",
                retryFeedback: "Say plainly what you can or cannot do."
            ),
            .init(
                id: "boundary.reason",
                title: "Name the constraint",
                kind: .containsAny(["because", "would delay", "client deadline", "to protect", "if i"]),
                successFeedback: "You gave the relevant constraint without over-defending it.",
                retryFeedback: "Add the short work reason behind the limit."
            ),
            .init(
                id: "boundary.alternative",
                title: "Offer a workable option",
                kind: .containsAny(["i can", "tomorrow", "instead", "alternative", "either", "by"]),
                successFeedback: "You kept the conversation moving toward a solution.",
                retryFeedback: "Offer one option you can actually deliver."
            )
        ],
        reviewPrompts: [
            "A client requests a same-day change that would skip the quality review. State the limit and offer one workable alternative."
        ]
    )

    // MARK: - Repair the Conversation

    static let repairTheConversation = Lesson(
        id: "repair_the_conversation",
        title: "Repair the Conversation",
        tagline: "Own your part, name the impact, and reset the next step.",
        category: .interaction,
        symbolName: "wrench.and.screwdriver",
        steps: [
            .concept(
                headline: "Repair without self-defense",
                body: "A useful repair owns the specific part you played, acknowledges the effect on the other person, and proposes a change. Explanation can come later; the first job is to restore shared ground.",
                example: "I interrupted you twice and moved on before your concern was clear. That shut down the discussion. Next time, I'll summarize your point before I respond."
            ),
            .spotIt(
                question: "Which response begins a real repair?",
                options: [
                    .init(
                        text: "I'm sorry you felt ignored, but the meeting was rushed.",
                        isCorrect: false,
                        explanation: "The apology shifts responsibility back to the other person's reaction."
                    ),
                    .init(
                        text: "I cut you off and moved on too quickly. I can see why that felt dismissive. Next time, I'll pause and check your point first.",
                        isCorrect: true,
                        explanation: "It owns the behavior, acknowledges the impact, and changes the next move."
                    ),
                    .init(
                        text: "We both could have handled that better.",
                        isCorrect: false,
                        explanation: "Shared blame avoids naming the speaker's own part."
                    )
                ]
            ),
            .apply(
                prompt: "A colleague says you dismissed their concern in a meeting. Repair the conversation by owning your part, acknowledging the impact, and proposing what you will do next time.",
                expectedDevice: nil,
                durationTarget: 35
            )
        ],
        targetDevice: nil,
        transferPrompt: "When a conversation goes wrong, make your first repair sentence about your own behavior, not their reaction.",
        applyCriteria: [
            .init(
                id: "repair.ownership",
                title: "Own your part",
                kind: .containsAny(["i interrupted", "i dismissed", "i moved", "i should have", "i was wrong", "my part", "i'm sorry", "i am sorry"]),
                successFeedback: "You named your own behavior without spreading the blame.",
                retryFeedback: "Name the specific part you played using “I…”."
            ),
            .init(
                id: "repair.impact",
                title: "Acknowledge the impact",
                kind: .containsAny(["i can see", "that felt", "that made", "the impact", "dismissive", "shut down", "left you"]),
                successFeedback: "You showed that the other person's experience registered.",
                retryFeedback: "Name what your behavior may have caused for the other person."
            ),
            .init(
                id: "repair.next",
                title: "Change the next move",
                kind: .containsAny(["next time", "from now on", "i will", "i'll", "going forward"]),
                successFeedback: "The repair included a concrete change.",
                retryFeedback: "Finish with what you will do differently next time."
            )
        ],
        reviewPrompts: [
            "A teammate says you interrupted them twice and the group moved on without hearing their concern. Own your part, acknowledge the impact, and reset the next move."
        ]
    )
}
