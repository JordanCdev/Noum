import Foundation

// MARK: - Coaching Knowledge Base (the coach "brain")
//
// The piece that has been missing from Ask Noum: a curated, version-controlled
// body of communication-coaching EXPERTISE the model can be grounded in, so its
// prescribed moves come from real coaching practice instead of an averaged-out
// base-model guess. This is the difference between a generic AI wrapper and a
// coach who actually knows the craft.
//
// Two design rules keep it honest (and keep it from becoming the very
// generic-platitude wrapper it's meant to cure):
//
//   1. A card is TECHNIQUE REFERENCE, never a reading of the user. It tells the
//      coach HOW to coach a given signal; it never claims anything about the
//      user. The user's own telemetry (CONTEXT) is always the evidence; a card
//      is only the method. The system prompt rule makes the precedence explicit:
//      when a card conflicts with the user's observed data, the user's data wins.
//
//   2. Every card carries an honest `evidenceTier`. Delivery mechanics with a
//      real research base read `.empirical`; widely-taught coaching practice
//      reads `.practitioner`; useful heuristics read `.folk`. The formatter
//      surfaces a softening qualifier for the weaker tiers so the coach offers
//      them as suggestions, not facts — matching the app's existing
//      weak-evidence -> softer-language contract.
//
// Pure value types, no state ownership, no I/O, no SwiftUI. Retrieval lives in
// `KnowledgeRetriever`; this file is only the corpus + its schema. Vocabulary is
// deliberately aligned with what the app already detects (`EloquenceEngine`
// devices, `LessonsCatalog` lessons, `SkillArea` levers) so the chat coach and
// the rest of the product speak the same craft language.

// MARK: - Schema

/// The coaching domain a card belongs to. Maps loosely to the product pillars
/// and the real-world transfer surfaces named in `docs/VISION.md`.
enum CoachingDomain: String, Codable, CaseIterable, Equatable {
    case fillerReduction
    case composurePressure
    case pacing
    case structure
    case rhetoric
    case progressReading
    case voiceRegister
    case transferInterview
    case transferPresentation
    case transferConflict
    case transferLeadership
    case transferSocial
    case transferNetworking

    var displayName: String {
        switch self {
        case .fillerReduction:      return "Filler reduction"
        case .composurePressure:    return "Composure under pressure"
        case .pacing:               return "Pacing & clarity"
        case .structure:            return "Structure"
        case .rhetoric:             return "Rhetoric"
        case .progressReading:      return "Reading progress"
        case .voiceRegister:        return "Voice register"
        case .transferInterview:    return "Interviews"
        case .transferPresentation: return "Presentations"
        case .transferConflict:     return "Difficult conversations"
        case .transferLeadership:   return "Leadership presence"
        case .transferSocial:       return "Social & dating"
        case .transferNetworking:   return "Networking"
        }
    }
}

/// How strongly the coach may state a technique. Drives the softening qualifier
/// the formatter emits — the honesty layer that stops the corpus turning the
/// coach into an over-claiming public-speaking wrapper.
enum CoachingEvidenceTier: String, Codable, Equatable {
    /// Delivery mechanics with a genuine research base (e.g. pausing, breathing,
    /// pace). The coach may state these plainly.
    case empirical
    /// Widely-taught, durable coaching practice (frameworks, register moves).
    /// Offer as established practice, not proven law.
    case practitioner
    /// A useful heuristic / rule of thumb. Offer as a suggestion, never a fact.
    case folk

    /// A short qualifier the formatter appends so the model honors the tier.
    /// Empty for `.empirical` (no hedge needed).
    var softeningQualifier: String {
        switch self {
        case .empirical:    return ""
        case .practitioner: return "established coaching practice"
        case .folk:         return "rule of thumb — offer it, don't assert it"
        }
    }
}

/// One unit of coaching expertise. Tight, retrievable, and grounded so the model
/// can hand the user a real move and name the technique behind it.
struct CoachKnowledgeCard: Identifiable, Equatable, Codable {
    /// Stable kebab-case id. Used for deterministic tie-breaking + tests.
    let id: String
    /// Short human title.
    let title: String
    let domain: CoachingDomain
    /// The named technique the coach can cite ("the held pause", "answer-first").
    let technique: String
    /// The mechanism — one clause on WHY it works.
    let why: String
    /// The concrete prescription, in shape the coach can hand the user.
    let howToApply: String
    /// One observable sign the move is landing.
    let successMarker: String
    /// The heuristic trigger — when this technique is the right call.
    let whenToUse: String
    /// Registers the technique fits. EMPTY means it fits any voice.
    let voiceAlignment: [SpeakingStyleGoal]
    /// Skill levers this technique serves — used to boost retrieval onto the
    /// user's ACTIVE coaching lever (`CoachMemory.currentLever`).
    let leverTags: [SkillArea]
    let evidenceTier: CoachingEvidenceTier
    /// Extra retrieval terms (synonyms, the words a user would actually type).
    let keywords: [String]

    /// The text the BM25 index tokenizes. Concatenates the human-meaningful
    /// fields + keywords. Never includes `id` (kebab tokens would pollute the
    /// index).
    var searchableText: String {
        ([title, technique, why, howToApply, whenToUse, domain.displayName] + keywords)
            .joined(separator: " ")
    }
}

// MARK: - Corpus

/// The single source of truth for Noum's coaching expertise. Ships in-binary
/// (no download, no network, works offline + in the Simulator). Curated, not
/// generated — every card meets the same evidence-honest bar as the existing
/// intelligence floor.
enum CoachKnowledgeBase {

    static let cards: [CoachKnowledgeCard] = fillerCards
        + composureCards
        + pacingCards
        + structureCards
        + rhetoricCards
        + progressCards
        + voiceRegisterCards
        + interviewCards
        + presentationCards
        + conflictCards
        + leadershipCards
        + socialCards
        + networkingCards

    // MARK: Filler reduction

    private static let fillerCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "filler-pause-beats-filler",
            title: "Pause beats filler",
            domain: .fillerReduction,
            technique: "the silent pause",
            why: "a filler often fills the moment before the next word arrives; a one-second silence gives the speaker the same beat without adding a filler",
            howToApply: "the next time an um or uh wants to come out, hold a one-second silence instead, then speak",
            successMarker: "the gaps go quiet rather than filling with um, and the pause feels less awkward over reps",
            whenToUse: "when fillers cluster at the seams between thoughts",
            voiceAlignment: [],
            leverTags: [.fillerReduction, .pauseUsage],
            evidenceTier: .empirical,
            keywords: ["um", "uh", "er", "filler", "crutch word", "stop saying um", "verbal tic"]
        ),
        CoachKnowledgeCard(
            id: "filler-anchor-word",
            title: "Anchor-word substitution",
            domain: .fillerReduction,
            technique: "a planned transition",
            why: "fillers often appear when a transition is missing; a planned connector gives the next sentence a clean bridge",
            howToApply: "pick two clean transitions ahead of time — \"here's the thing\", \"the short version is\" — and reach for one of those at the seam instead of a filler",
            successMarker: "transitions land cleanly and fewer sentence joins need um",
            whenToUse: "when fillers appear mostly between sentences, not inside them",
            voiceAlignment: [],
            leverTags: [.fillerReduction],
            evidenceTier: .practitioner,
            keywords: ["transition", "connector", "bridge phrase", "filler", "um"]
        ),
        CoachKnowledgeCard(
            id: "filler-slow-the-open",
            title: "Slow the open to cut fillers",
            domain: .fillerReduction,
            technique: "the slow open",
            why: "fillers can cluster in the first few seconds, before the opening has settled",
            howToApply: "say your first sentence slower than feels natural, then hold a tiny pause before sentence two",
            successMarker: "the first fifteen seconds carry fewer fillers without losing the point",
            whenToUse: "when the start of a rep is the filler-heavy part",
            voiceAlignment: [],
            leverTags: [.fillerReduction, .paceControl],
            evidenceTier: .empirical,
            keywords: ["opening fillers", "start", "warm up", "first sentence", "um at the start"]
        ),
        CoachKnowledgeCard(
            id: "filler-silent-reset",
            title: "The silent reset",
            domain: .fillerReduction,
            technique: "a full stop",
            why: "once a sentence tangles, piling on fillers makes it worse; a clean stop lets you restart from a stable point",
            howToApply: "when a sentence runs away from you, stop fully, take one breath, and begin the point again from the top",
            successMarker: "tangled sentences get reset cleanly instead of trailing into a chain of ums",
            whenToUse: "mid-sentence when a thought has clearly gone off the rails",
            voiceAlignment: [],
            leverTags: [.fillerReduction, .pauseUsage],
            evidenceTier: .practitioner,
            keywords: ["reset", "restart", "recover", "tangle", "run-on"]
        ),
        CoachKnowledgeCard(
            id: "filler-end-of-sentence",
            title: "Land the period and stop",
            domain: .fillerReduction,
            technique: "the hard stop",
            why: "trailing fillers — so, right, you know — are a habit of softening the end of a thought instead of letting it stand",
            howToApply: "when you reach the end of a point, hit the final word and stop your mouth completely rather than tacking on so or right",
            successMarker: "sentences end on the word that matters instead of trailing into so or you know",
            whenToUse: "when fillers cluster at the ENDS of sentences",
            voiceAlignment: [.concise, .authoritative],
            leverTags: [.fillerReduction, .closingStrength],
            evidenceTier: .practitioner,
            keywords: ["so", "right", "you know", "trailing", "ending fillers"]
        ),
        CoachKnowledgeCard(
            id: "filler-give-the-pause-a-job",
            title: "Give the pause a job",
            domain: .fillerReduction,
            technique: "the working pause",
            why: "a pause feels awkward and loses the thread when it is empty; a pause with a job — locating the exact next word — reads as composed instead of stalled",
            howToApply: "in the silent beat, do one specific thing: find the first word of your next sentence before you say anything, then say it",
            successMarker: "the pause holds without the thread slipping, because attention stayed on finding the next word instead of on the silence itself",
            whenToUse: "when a pause feels awkward, or you lose your train of thought the moment you stop talking",
            voiceAlignment: [],
            leverTags: [.pauseUsage, .fillerReduction],
            evidenceTier: .practitioner,
            keywords: ["awkward", "lose my train of thought", "silence feels weird", "trail off", "pause feels", "losing my place", "blank during pause"]
        ),
    ]

    // MARK: Composure under pressure

    private static let composureCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "composure-extended-exhale",
            title: "Exhale longer than you inhale",
            domain: .composurePressure,
            technique: "the extended exhale",
            why: "a longer out-breath nudges the nervous system down a gear, which steadies the voice and slows a racing pace",
            howToApply: "before you start, take one breath where the exhale is roughly twice as long as the inhale, then begin on the out-breath",
            successMarker: "the voice starts steady instead of tight, and the first lines don't race",
            whenToUse: "in the seconds before a high-stakes rep or a hard question",
            voiceAlignment: [],
            leverTags: [.confidence, .paceControl],
            evidenceTier: .empirical,
            keywords: ["breathing", "nerves", "anxiety", "calm down", "shaky voice", "racing heart"]
        ),
        CoachKnowledgeCard(
            id: "composure-tactical-pause",
            title: "The tactical pause under challenge",
            domain: .composurePressure,
            technique: "the held beat",
            why: "a beat before answering a hard question gives you time to choose the first sentence instead of rushing into a hedge",
            howToApply: "when a tough question lands, hold a deliberate beat, then open with your actual point",
            successMarker: "hard questions get a composed beat and a clean first sentence instead of a rushed, hedged opener",
            whenToUse: "when challenged, interrupted, or put on the spot",
            voiceAlignment: [.authoritative, .executive],
            leverTags: [.pauseUsage, .confidence],
            evidenceTier: .practitioner,
            keywords: ["pressure", "hard question", "challenge", "interrupted", "put on the spot", "panel"]
        ),
        CoachKnowledgeCard(
            id: "composure-recover-no-apology",
            title: "Recover without apologizing",
            domain: .composurePressure,
            technique: "the clean restate",
            why: "apologizing for a stumble draws attention to it; restating the point simply moves everyone past it",
            howToApply: "after a fumble, skip the sorry — just pause, then say the point again cleanly and carry on",
            successMarker: "stumbles pass unremarked because you restate instead of apologize",
            whenToUse: "right after a visible mistake or a lost thread",
            voiceAlignment: [],
            leverTags: [.confidence, .closingStrength],
            evidenceTier: .practitioner,
            keywords: ["mistake", "stumble", "sorry", "recover", "blank", "lost my place"]
        ),
        CoachKnowledgeCard(
            id: "composure-name-the-nerves",
            title: "Name the nerves, then act",
            domain: .composurePressure,
            technique: "private labeling",
            why: "quietly naming a feeling to yourself takes some of its charge out, which frees attention for the actual speaking",
            howToApply: "before you start, name it plainly in your head — \"this matters, that's why the buzz\" — then put your attention on the first sentence",
            successMarker: "the nerves stay background noise instead of driving the delivery",
            whenToUse: "when anticipation is spiking before a moment that matters",
            voiceAlignment: [.warm],
            leverTags: [.confidence],
            evidenceTier: .empirical,
            keywords: ["nerves", "anxiety", "label", "fear", "stage fright", "nervous"]
        ),
        CoachKnowledgeCard(
            id: "composure-one-anchor-point",
            title: "Anchor to one point in the room",
            domain: .composurePressure,
            technique: "a fixed anchor",
            why: "scanning a hostile or crowded room feeds the threat response; one steady anchor gives attention somewhere calm to rest",
            howToApply: "find one friendly face or a fixed spot, deliver your opening to it, then widen out once you've found your footing",
            successMarker: "the open lands steady instead of scattered, and eye contact settles",
            whenToUse: "when a big or tense audience is rattling the open",
            voiceAlignment: [],
            leverTags: [.confidence],
            evidenceTier: .folk,
            keywords: ["audience", "eye contact", "big room", "crowd", "intimidating"]
        ),
        CoachKnowledgeCard(
            id: "composure-sudden-death-one-line",
            title: "One clean line under sudden pressure",
            domain: .composurePressure,
            technique: "single-sentence framing",
            why: "narrowing a high-stakes moment to one clear sentence stops the spiral of trying to say everything at once",
            howToApply: "when the stakes spike, decide the single sentence that has to land, say that first, and build only if there's room",
            successMarker: "high-pressure reps open with one clear line instead of a scramble",
            whenToUse: "in sudden-death or no-second-chance moments",
            voiceAlignment: [.concise, .authoritative],
            leverTags: [.confidence, .conciseSpeaking],
            evidenceTier: .practitioner,
            keywords: ["sudden death", "high stakes", "one shot", "pressure", "freeze"]
        ),
    ]

    // MARK: Pacing & clarity

    private static let pacingCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "pacing-target-band",
            title: "Aim for a conversational pace band",
            domain: .pacing,
            technique: "pace targeting",
            why: "much past a brisk conversational clip the listener stops processing and starts just hearing sound; well below it the energy sags",
            howToApply: "aim for an unhurried conversational pace — roughly 130 to 160 words a minute — and treat a racing rep as a cue to add pauses, not to talk slower word-by-word",
            successMarker: "the rep lands in the conversational band and points have room to register",
            whenToUse: "when pace runs consistently fast or consistently flat",
            voiceAlignment: [],
            leverTags: [.paceControl],
            evidenceTier: .empirical,
            keywords: ["pace", "speed", "wpm", "fast", "rushing", "too quick", "slow down"]
        ),
        CoachKnowledgeCard(
            id: "pacing-held-beat-after-claim",
            title: "Hold a beat after a claim",
            domain: .pacing,
            technique: "the held beat",
            why: "silence right after a key line is what lets it land; rushing into the next sentence steps on your own point",
            howToApply: "after your most important sentence, hold a full beat of silence before the next one — let it sit",
            successMarker: "key lines get a beat of air and visibly register before you move on",
            whenToUse: "when strong points get buried because everything runs together",
            voiceAlignment: [.authoritative, .executive, .persuasive],
            leverTags: [.pauseUsage, .paceControl, .vocalEmphasis],
            evidenceTier: .practitioner,
            keywords: ["pause", "let it land", "emphasis", "beat", "silence"]
        ),
        CoachKnowledgeCard(
            id: "pacing-chunk-and-pause",
            title: "Chunk and pause",
            domain: .pacing,
            technique: "phrasing",
            why: "the ear groups speech into phrases; pausing at the natural seams makes you easy to follow and stops the run-on rush",
            howToApply: "deliver in short phrases and put a small pause at each natural seam, rather than one long unbroken stream",
            successMarker: "the delivery breathes in phrases instead of running together",
            whenToUse: "when sentences sprawl and the listener loses the thread",
            voiceAlignment: [],
            leverTags: [.paceControl, .pauseUsage, .structure],
            evidenceTier: .empirical,
            keywords: ["phrasing", "chunking", "run-on", "rambling", "breathe"]
        ),
        CoachKnowledgeCard(
            id: "pacing-downshift-key-line",
            title: "Slow down on the line that matters",
            domain: .pacing,
            technique: "the downshift",
            why: "slowing on a single line signals importance; a constant fast pace flattens everything to the same weight",
            howToApply: "pick the one line that carries the point and deliberately slow it down — the change of speed marks it as the line to remember",
            successMarker: "the key line stands out by tempo, not volume",
            whenToUse: "when delivery is monotone-fast and nothing stands out",
            voiceAlignment: [.persuasive, .storytelling, .executive],
            leverTags: [.paceControl, .vocalEmphasis],
            evidenceTier: .practitioner,
            keywords: ["emphasis", "vary", "monotone", "vocal variety", "dynamics"]
        ),
    ]

    // MARK: Structure

    private static let structureCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "structure-answer-first",
            title: "Answer first, then support it",
            domain: .structure,
            technique: "answer-first (bottom line up front)",
            why: "the listener can only weigh your support once they know the point; leading with the answer makes everything after it land as evidence",
            howToApply: "make your first sentence the actual answer or main point, then spend the rest backing it up",
            successMarker: "the point is clear from sentence one instead of arriving late",
            whenToUse: "when the main point keeps getting buried late in the answer",
            voiceAlignment: [.authoritative, .executive, .concise],
            leverTags: [.structure, .openingStrength, .answerDevelopment],
            evidenceTier: .practitioner,
            keywords: ["bluf", "bottom line", "lead with the point", "buried lede", "get to the point", "main point"]
        ),
        CoachKnowledgeCard(
            id: "structure-prep",
            title: "PREP: point, reason, example, point",
            domain: .structure,
            technique: "the PREP frame",
            why: "a tiny arc — claim, why, proof, restate — turns a rambling answer into one the listener can hold and repeat back",
            howToApply: "state your point, give one reason, give one concrete example, then restate the point in a sentence",
            successMarker: "answers have a clear shape someone could summarize back to you",
            whenToUse: "when answers ramble or have no through-line",
            voiceAlignment: [.persuasive, .concise, .authoritative],
            leverTags: [.structure, .answerDevelopment],
            evidenceTier: .practitioner,
            keywords: ["prep", "framework", "rambling", "structure", "organize", "shape"]
        ),
        CoachKnowledgeCard(
            id: "structure-rule-of-three",
            title: "Group in threes",
            domain: .structure,
            technique: "the rule of three",
            why: "three feels complete and is easy to remember — two feels thin, four starts to blur",
            howToApply: "when you list reasons or points, shape them into three; the third is the one that makes the set feel whole",
            successMarker: "lists land as a tidy set of three rather than a sprawling string",
            whenToUse: "when making a case or listing supporting points",
            voiceAlignment: [.persuasive, .storytelling, .authoritative],
            leverTags: [.structure],
            evidenceTier: .practitioner,
            keywords: ["rule of three", "tricolon", "list", "three points", "triad"]
        ),
        CoachKnowledgeCard(
            id: "structure-frame-the-open",
            title: "Frame the open",
            domain: .structure,
            technique: "framing the open",
            why: "a listener who knows what they're about to hear follows it far better than one figuring out the shape as you go",
            howToApply: "open by telling them what this is in one line — \"three reasons this works\" or \"the short version, then the detail\" — before you dive in",
            successMarker: "the audience is oriented from the first line and follows without effort",
            whenToUse: "at the start of anything longer than a sentence or two",
            voiceAlignment: [.executive, .authoritative],
            leverTags: [.openingStrength, .structure],
            evidenceTier: .practitioner,
            keywords: ["opening", "frame", "set up", "roadmap", "orient", "preview"]
        ),
        CoachKnowledgeCard(
            id: "structure-land-the-close",
            title: "Land the close",
            domain: .structure,
            technique: "landing the close",
            why: "people remember how something ends; trailing off throws away the most memorable spot you have",
            howToApply: "decide your last line in advance, make it the point or the ask, and stop there — no drifting epilogue",
            successMarker: "you end on a deliberate line instead of trailing into so, yeah",
            whenToUse: "when endings fizzle or trail off",
            voiceAlignment: [],
            leverTags: [.closingStrength, .structure],
            evidenceTier: .practitioner,
            keywords: ["closing", "ending", "land the close", "finish", "last line", "trail off"]
        ),
        CoachKnowledgeCard(
            id: "structure-minto-pyramid",
            title: "Answer, then grouped support",
            domain: .structure,
            technique: "the pyramid",
            why: "leading with the answer and grouping the support beneath it lets a listener take as much detail as they want without losing the point",
            howToApply: "give the single answer first, then group your support into two or three buckets beneath it rather than a flat list",
            successMarker: "even a long answer stays anchored to one clear top-line",
            whenToUse: "for complex updates, recommendations, or analysis",
            voiceAlignment: [.executive, .persuasive],
            leverTags: [.structure, .answerDevelopment],
            evidenceTier: .practitioner,
            keywords: ["minto", "pyramid", "consulting", "recommendation", "complex", "grouping"]
        ),
        CoachKnowledgeCard(
            id: "structure-signposting",
            title: "Signpost the path",
            domain: .structure,
            technique: "signposting",
            why: "naming how many points are coming and where you are tells the listener what to hold and when it's safe to let go",
            howToApply: "say how many — \"two things\" — then mark each one: \"first… second…\"",
            successMarker: "the listener can track exactly where you are in the answer",
            whenToUse: "when covering more than one point in a row",
            voiceAlignment: [.concise, .executive, .authoritative],
            leverTags: [.structure],
            evidenceTier: .practitioner,
            keywords: ["signpost", "first second", "number your points", "navigation", "transitions"]
        ),
        CoachKnowledgeCard(
            id: "structure-one-idea-per-sentence",
            title: "One idea per sentence",
            domain: .structure,
            technique: "cutting the conjunctions",
            why: "stacking clauses with and, but, so blurs the point; one idea per sentence forces each to stand on its own",
            howToApply: "when a sentence sprawls, break it at the and or so into two short sentences, each carrying one idea",
            successMarker: "sentences get shorter and each one carries a single clear idea",
            whenToUse: "when long, clause-heavy sentences are muddying the point",
            voiceAlignment: [.concise],
            leverTags: [.conciseSpeaking, .structure],
            evidenceTier: .folk,
            keywords: ["concise", "run-on", "shorten", "clauses", "and but so", "tighten"]
        ),
        CoachKnowledgeCard(
            id: "structure-thirty-second-update",
            title: "The 30-second update",
            domain: .structure,
            technique: "the executive summary",
            why: "a senior listener wants the headline and the ask in the first half-minute; the detail is for if they ask",
            howToApply: "build a thirty-second version — what happened, what it means, what you need — and lead with that; hold the detail in reserve",
            successMarker: "you can deliver the whole point in thirty seconds and stop",
            whenToUse: "for status updates, stand-ups, or briefing someone senior",
            voiceAlignment: [.executive, .concise],
            leverTags: [.conciseSpeaking, .structure],
            evidenceTier: .practitioner,
            keywords: ["update", "summary", "standup", "brief", "status", "elevator"]
        ),
        CoachKnowledgeCard(
            id: "structure-star",
            title: "STAR for stories and examples",
            domain: .structure,
            technique: "the STAR frame",
            why: "situation, task, action, result keeps an anecdote from wandering and makes sure it lands on a concrete outcome",
            howToApply: "set the situation and your task in a line each, spend most of it on the action you took, and finish on the result",
            successMarker: "examples arrive at a concrete result instead of fading out",
            whenToUse: "for behavioral examples, case stories, or proof points",
            voiceAlignment: [.storytelling, .persuasive],
            leverTags: [.answerDevelopment, .structure],
            evidenceTier: .practitioner,
            keywords: ["star", "example", "story", "behavioral", "anecdote", "result"]
        ),
    ]

    // MARK: Rhetoric (aligned with EloquenceEngine devices)

    private static let rhetoricCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "rhetoric-anaphora",
            title: "Anaphora — repeat the opening",
            domain: .rhetoric,
            technique: "anaphora",
            why: "repeating the opening of consecutive clauses builds rhythm and presses the point home",
            howToApply: "start two or three clauses the same way — \"we tested, we shipped, we learned\" — when you want a line to build",
            successMarker: "a key passage gains rhythm and feels intentional, not flat",
            whenToUse: "on a peak moment you want to feel deliberate and memorable",
            voiceAlignment: [.persuasive, .storytelling, .authoritative],
            leverTags: [.vocalEmphasis, .structure],
            evidenceTier: .practitioner,
            keywords: ["anaphora", "repetition", "rhythm", "rhetoric", "device", "memorable"]
        ),
        CoachKnowledgeCard(
            id: "rhetoric-antithesis",
            title: "Antithesis — set idea against opposite",
            domain: .rhetoric,
            technique: "antithesis",
            why: "putting an idea against its opposite makes both sharper and the contrast easy to remember",
            howToApply: "frame the point as a contrast — \"not X, but Y\" — when you want a distinction to cut clearly",
            successMarker: "a distinction lands crisply instead of blurring",
            whenToUse: "when you need to make a clear choice or contrast stick",
            voiceAlignment: [.persuasive, .authoritative],
            leverTags: [.vocalEmphasis, .structure],
            evidenceTier: .practitioner,
            keywords: ["antithesis", "contrast", "opposite", "not this but that", "rhetoric"]
        ),
        CoachKnowledgeCard(
            id: "rhetoric-rhetorical-question",
            title: "Rhetorical question — pull them in",
            domain: .rhetoric,
            technique: "the rhetorical question",
            why: "asking instead of asserting pulls the listener into reaching the answer with you, so they own it more",
            howToApply: "pose the question you're about to answer — \"so what actually moves the needle?\" — then answer it",
            successMarker: "the audience leans in to the answer instead of being told it",
            whenToUse: "to open a point or re-engage a drifting listener",
            voiceAlignment: [.persuasive, .storytelling, .warm],
            leverTags: [.openingStrength, .vocalEmphasis],
            evidenceTier: .practitioner,
            keywords: ["rhetorical question", "engage", "ask", "hook", "rhetoric"]
        ),
        CoachKnowledgeCard(
            id: "rhetoric-parallel-structure",
            title: "Parallel structure — equal weight",
            domain: .rhetoric,
            technique: "parallel structure",
            why: "matching grammar across items makes ideas sound equally weighted and easy to hold together",
            howToApply: "phrase a set of points in the same grammatical shape — all verbs, all the same length — so they read as a clean set",
            successMarker: "a list sounds balanced and considered rather than thrown together",
            whenToUse: "when presenting a set of options, values, or priorities",
            voiceAlignment: [.executive, .authoritative, .persuasive],
            leverTags: [.structure],
            evidenceTier: .practitioner,
            keywords: ["parallel", "isocolon", "balanced", "symmetry", "rhetoric"]
        ),
        CoachKnowledgeCard(
            id: "rhetoric-emphatic-repetition",
            title: "Emphatic repetition — used sparingly",
            domain: .rhetoric,
            technique: "emphatic repetition",
            why: "repeating one word back-to-back is the rawest emphasis there is, which is exactly why it only works once in a while",
            howToApply: "on a single moment that truly matters, repeat the key word — \"this is big, big\" — then never again in that talk",
            successMarker: "one moment hits hard because the rest of the delivery stayed measured",
            whenToUse: "for a single peak; overuse kills it",
            voiceAlignment: [.storytelling, .persuasive],
            leverTags: [.vocalEmphasis],
            evidenceTier: .folk,
            keywords: ["repetition", "epizeuxis", "emphasis", "peak", "rhetoric"]
        ),
    ]

    // MARK: Reading progress (meta — keeps the coach honest)

    private static let progressCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "progress-trend-vs-noise",
            title: "One rep is not a verdict",
            domain: .progressReading,
            technique: "trend over single point",
            why: "any single rep swings with mood, topic, and luck; only a run of reps in the same direction is real signal",
            howToApply: "read a single dip or spike as noise and wait for three or four reps before calling it a trend",
            successMarker: "you stop over-reacting to one rep and watch the direction instead",
            whenToUse: "after a surprisingly good or bad single session",
            voiceAlignment: [],
            leverTags: [.confidence],
            evidenceTier: .empirical,
            keywords: ["trend", "noise", "one rep", "variance", "sample", "consistency"]
        ),
        CoachKnowledgeCard(
            id: "progress-wobble-not-verdict",
            title: "Name a wobble, not a verdict",
            domain: .progressReading,
            technique: "the wobble frame",
            why: "framing a bad rep as a wobble keeps the door open to recover; framing it as a verdict invites a spiral",
            howToApply: "when a rep dips, call it a wobble and pick the single thing to steady next time, rather than a referendum on whether you're any good",
            successMarker: "a bad rep becomes one adjustment instead of a confidence hit",
            whenToUse: "right after a discouraging session",
            voiceAlignment: [.warm],
            leverTags: [.confidence],
            evidenceTier: .practitioner,
            keywords: ["bad day", "off rep", "regression", "discouraged", "slump", "wobble"]
        ),
        CoachKnowledgeCard(
            id: "progress-celebrate-the-behavior",
            title: "Credit the controllable",
            domain: .progressReading,
            technique: "process over outcome",
            why: "scores bounce around, but the behavior you chose — held a pause, led with the point — is yours and repeatable",
            howToApply: "after a rep, credit the specific thing you did on purpose, not just the number it produced",
            successMarker: "you can name the deliberate move you made, independent of the score",
            whenToUse: "when motivation is riding too hard on the score alone",
            voiceAlignment: [.warm],
            leverTags: [.confidence],
            evidenceTier: .empirical,
            keywords: ["motivation", "process", "outcome", "score", "habit", "deliberate practice"]
        ),
    ]

    // MARK: Voice register (one anchor per voice)

    private static let voiceRegisterCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "voice-authoritative",
            title: "Authoritative register",
            domain: .voiceRegister,
            technique: "verdict-shaped delivery",
            why: "authority reads through certainty and economy — a clear call, fewer words, no hedging",
            howToApply: "state the call as a verdict, cut the qualifiers — maybe, kind of, I think — and let a pause carry the weight",
            successMarker: "the line sounds decided, with no hedge softening it",
            whenToUse: "when the user is training the authoritative voice",
            voiceAlignment: [.authoritative],
            leverTags: [.confidence, .conciseSpeaking],
            evidenceTier: .practitioner,
            keywords: ["authoritative", "command", "certainty", "hedging", "decisive"]
        ),
        CoachKnowledgeCard(
            id: "voice-warm",
            title: "Warm register",
            domain: .voiceRegister,
            technique: "curiosity and second person",
            why: "warmth reads through interest in the other person — questions, their name, a softer pace — not through more words",
            howToApply: "put one genuine question or a you-centered line near the open, and let the pace stay unhurried",
            successMarker: "the delivery feels like it's with the listener, not at them",
            whenToUse: "when the user is training the warm voice",
            voiceAlignment: [.warm],
            leverTags: [.confidence],
            evidenceTier: .practitioner,
            keywords: ["warm", "warmth", "approachable", "friendly", "curiosity", "connection"]
        ),
        CoachKnowledgeCard(
            id: "voice-concise",
            title: "Concise register",
            domain: .voiceRegister,
            technique: "one idea, cut the rest",
            why: "crispness reads through what you leave out — one idea per sentence, no preamble, no wind-down",
            howToApply: "say the point, then stop; cut the warm-up clause at the front and the softening clause at the end",
            successMarker: "the point arrives fast and ends clean, with nothing padding it",
            whenToUse: "when the user is training the concise voice",
            voiceAlignment: [.concise],
            leverTags: [.conciseSpeaking, .structure],
            evidenceTier: .practitioner,
            keywords: ["concise", "sharp", "crisp", "tight", "brevity", "cut"]
        ),
        CoachKnowledgeCard(
            id: "voice-persuasive",
            title: "Persuasive register",
            domain: .voiceRegister,
            technique: "claim, evidence, ask",
            why: "persuasion reads through a clear claim, one solid piece of support, and an explicit ask — not through volume",
            howToApply: "name the claim, back it with your single strongest reason, and finish with the specific thing you want them to do",
            successMarker: "the listener knows what you believe and what you're asking of them",
            whenToUse: "when the user is training the persuasive voice",
            voiceAlignment: [.persuasive],
            leverTags: [.structure, .closingStrength],
            evidenceTier: .practitioner,
            keywords: ["persuasive", "convince", "argument", "claim", "ask", "pitch"]
        ),
        CoachKnowledgeCard(
            id: "voice-executive",
            title: "Executive presence",
            domain: .voiceRegister,
            technique: "summary first, gravity through brevity",
            why: "executive presence reads through composure and economy — the headline first, fewer words, an unhurried pause",
            howToApply: "open with the one-line bottom line, slow down, and resist filling silences — let brevity do the work",
            successMarker: "you sound composed and high-level, leading with the headline",
            whenToUse: "when the user is training executive presence",
            voiceAlignment: [.executive],
            leverTags: [.conciseSpeaking, .pauseUsage, .confidence],
            evidenceTier: .practitioner,
            keywords: ["executive", "presence", "boardroom", "gravitas", "senior", "composed"]
        ),
        CoachKnowledgeCard(
            id: "voice-storytelling",
            title: "Storytelling register",
            domain: .voiceRegister,
            technique: "setup, turn, point",
            why: "a story holds attention through a small arc — a setup, a turn where something changes, and the point it earns",
            howToApply: "open on a concrete moment, mark the turn where it changed, and end on the point the story makes",
            successMarker: "the anecdote has a clear turn and arrives at a point, not just events",
            whenToUse: "when the user is training the storytelling voice",
            voiceAlignment: [.storytelling],
            leverTags: [.answerDevelopment, .openingStrength],
            evidenceTier: .practitioner,
            keywords: ["storytelling", "story", "narrative", "arc", "vivid", "engaging"]
        ),
    ]

    // MARK: Transfer — interviews

    private static let interviewCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "interview-star-under-pressure",
            title: "STAR under panel pressure",
            domain: .transferInterview,
            technique: "the STAR frame",
            why: "under panel pressure answers wander; a fixed shape — situation, task, action, result — keeps you on track to a concrete outcome",
            howToApply: "for any \"tell me about a time\" question, give one line of situation and task, most of it on your action, and finish on the result",
            successMarker: "behavioral answers arrive at a concrete result instead of trailing off",
            whenToUse: "preparing for or recovering from behavioral interview questions",
            voiceAlignment: [.persuasive, .concise],
            leverTags: [.answerDevelopment, .structure, .confidence],
            evidenceTier: .practitioner,
            keywords: ["interview", "star", "behavioral", "tell me about a time", "panel", "job"]
        ),
        CoachKnowledgeCard(
            id: "interview-answer-first",
            title: "Answer the question first",
            domain: .transferInterview,
            technique: "answer-first",
            why: "interviewers are scoring whether you can get to the point; leading with the answer shows it before the clock runs",
            howToApply: "open with a one-sentence direct answer, then give the reasoning or example behind it",
            successMarker: "each answer states the point in the first sentence",
            whenToUse: "when interview answers ramble before reaching the point",
            voiceAlignment: [.concise, .authoritative],
            leverTags: [.openingStrength, .answerDevelopment],
            evidenceTier: .practitioner,
            keywords: ["interview", "answer first", "direct", "rambling", "concise"]
        ),
        CoachKnowledgeCard(
            id: "interview-tell-me-about-yourself",
            title: "The 60-second self-intro",
            domain: .transferInterview,
            technique: "the present-past-future frame",
            why: "\"tell me about yourself\" is a framing test; a tight present, past, future arc shows you can shape a narrative on demand",
            howToApply: "say what you do now in a line, the one past step that led here, and what you're looking for next — about sixty seconds total",
            successMarker: "the intro lands in around a minute with a clear through-line",
            whenToUse: "for the open of an interview or intro round",
            voiceAlignment: [.concise, .storytelling],
            leverTags: [.openingStrength, .structure],
            evidenceTier: .practitioner,
            keywords: ["tell me about yourself", "intro", "interview", "elevator", "self introduction"]
        ),
        CoachKnowledgeCard(
            id: "interview-buy-thinking-time",
            title: "Buy thinking time cleanly",
            domain: .transferInterview,
            technique: "the framed pause",
            why: "a beat to think reads as considered, but only if you don't fill it with hedging; a short frame buys the time gracefully",
            howToApply: "on a hard question, say a short honest frame — \"good question, the short version is\" — then take your beat and answer",
            successMarker: "hard questions get a composed beat instead of a rushed, hedged scramble",
            whenToUse: "when a tough interview question needs a moment of thought",
            voiceAlignment: [.executive, .authoritative],
            leverTags: [.pauseUsage, .confidence],
            evidenceTier: .folk,
            keywords: ["interview", "thinking time", "hard question", "stall", "pause", "buy time"]
        ),
    ]

    // MARK: Transfer — presentations

    private static let presentationCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "presentation-open-with-stakes",
            title: "Open with the stakes, not the agenda",
            domain: .transferPresentation,
            technique: "the stakes open",
            why: "an agenda slide tells people to wait; opening on why this matters to them earns attention from the first line",
            howToApply: "drop the \"today I'll cover\" open and start on the stakes — the problem, the cost, or the promise — then get into structure",
            successMarker: "the room is engaged in the first fifteen seconds rather than waiting",
            whenToUse: "for the open of a talk or presentation",
            voiceAlignment: [.persuasive, .storytelling],
            leverTags: [.openingStrength],
            evidenceTier: .practitioner,
            keywords: ["presentation", "open", "hook", "agenda", "stakes", "talk", "speech"]
        ),
        CoachKnowledgeCard(
            id: "presentation-close-is-the-ask",
            title: "The close is the ask",
            domain: .transferPresentation,
            technique: "landing the close",
            why: "a presentation that ends on a recap leaves people unsure what to do; ending on the ask tells them",
            howToApply: "end on the single specific thing you want — the decision, the next step, the yes — not a summary of what you just said",
            successMarker: "the talk ends on a clear ask the room can act on",
            whenToUse: "for the close of any persuasive presentation",
            voiceAlignment: [.persuasive, .executive],
            leverTags: [.closingStrength],
            evidenceTier: .practitioner,
            keywords: ["presentation", "close", "ask", "call to action", "ending", "decision"]
        ),
        CoachKnowledgeCard(
            id: "presentation-handle-qa",
            title: "Handle Q&A: restate, answer, bridge",
            domain: .transferPresentation,
            technique: "the Q&A frame",
            why: "restating buys a beat and makes sure the room heard the question; answering then bridging keeps you on message",
            howToApply: "briefly restate the question, give a direct answer, then bridge back to your key point in a sentence",
            successMarker: "answers stay short and return to your message instead of wandering",
            whenToUse: "when fielding questions after a talk",
            voiceAlignment: [.executive, .authoritative],
            leverTags: [.structure, .confidence],
            evidenceTier: .practitioner,
            keywords: ["q&a", "questions", "presentation", "field questions", "bridge", "deflect"]
        ),
        CoachKnowledgeCard(
            id: "presentation-you-carry-not-slides",
            title: "You carry it, the slides support",
            domain: .transferPresentation,
            technique: "slides as support",
            why: "reading slides hands attention to the screen; speaking to the room and using slides as a backdrop keeps you in command",
            howToApply: "make your point to the room first, then glance at the slide as support — never read it aloud word for word",
            successMarker: "you're speaking to people, not narrating a screen",
            whenToUse: "when delivery is buried in reading the deck",
            voiceAlignment: [],
            leverTags: [.confidence, .openingStrength],
            evidenceTier: .folk,
            keywords: ["slides", "deck", "reading", "presentation", "powerpoint", "eye contact"]
        ),
    ]

    // MARK: Transfer — difficult conversations / conflict

    private static let conflictCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "conflict-name-it-then-steer",
            title: "Name the tension, then steer",
            domain: .transferConflict,
            technique: "name it, then steer",
            why: "naming the tension plainly takes the charge out of it and lets you both look at the problem instead of circling it",
            howToApply: "say the tension in one calm line — \"feels like we're stuck on X\" — then point at what you both want to solve",
            successMarker: "the conversation moves to the problem instead of escalating",
            whenToUse: "when a conversation is tense or going in circles",
            voiceAlignment: [.warm, .authoritative],
            leverTags: [.confidence, .structure],
            evidenceTier: .practitioner,
            keywords: ["conflict", "tension", "difficult conversation", "confront", "name it", "disagreement"]
        ),
        CoachKnowledgeCard(
            id: "conflict-non-defensive-repair",
            title: "Acknowledge, don't justify",
            domain: .transferConflict,
            technique: "non-defensive repair",
            why: "justifying yourself reads as defensive and prolongs the friction; a brief acknowledgement lets the other person feel heard and the temperature drop",
            howToApply: "acknowledge their point in a line before you respond — \"fair, I can see that\" — without rushing to defend yourself",
            successMarker: "the other person softens because they felt heard first",
            whenToUse: "when you're being challenged or criticized",
            voiceAlignment: [.warm],
            leverTags: [.confidence],
            evidenceTier: .practitioner,
            keywords: ["defensive", "criticism", "feedback", "conflict", "acknowledge", "repair"]
        ),
        CoachKnowledgeCard(
            id: "conflict-held-pause",
            title: "The held pause lowers the temperature",
            domain: .transferConflict,
            technique: "the held pause",
            why: "a deliberate silence in a heated moment slows the exchange and stops you saying the thing you'd take back",
            howToApply: "when it heats up, take one full breath of silence before you respond — the pause cools the exchange",
            successMarker: "heated moments get a beat instead of a reflexive escalation",
            whenToUse: "when a conversation is escalating fast",
            voiceAlignment: [],
            leverTags: [.pauseUsage, .paceControl, .confidence],
            evidenceTier: .practitioner,
            keywords: ["conflict", "heated", "pause", "escalate", "calm", "temperature"]
        ),
        CoachKnowledgeCard(
            id: "conflict-shared-goal",
            title: "Lead with the shared goal",
            domain: .transferConflict,
            technique: "the shared frame",
            why: "opening on what you both want turns a standoff into a joint problem and lowers the other person's guard",
            howToApply: "start from the goal you share — \"we both want this to ship well\" — before you get into where you differ",
            successMarker: "the conversation feels like the two of you against the problem",
            whenToUse: "at the start of a disagreement or negotiation",
            voiceAlignment: [.persuasive, .warm],
            leverTags: [.openingStrength, .structure],
            evidenceTier: .practitioner,
            keywords: ["conflict", "negotiation", "shared goal", "common ground", "alignment", "disagreement"]
        ),
    ]

    // MARK: Transfer — leadership / executive

    private static let leadershipCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "leadership-verdict-first",
            title: "Decision first, reasoning second",
            domain: .transferLeadership,
            technique: "verdict-shaped delivery",
            why: "a team needs to know the call before they can follow the logic; leading with the decision reads as leadership",
            howToApply: "state the decision in one clean line, then give the reasoning behind it — not the other way around",
            successMarker: "people know the call from your first sentence",
            whenToUse: "when communicating a decision or direction",
            voiceAlignment: [.authoritative, .executive],
            leverTags: [.structure, .confidence, .openingStrength],
            evidenceTier: .practitioner,
            keywords: ["leadership", "decision", "direction", "verdict", "lead", "call"]
        ),
        CoachKnowledgeCard(
            id: "leadership-gravity-fewer-words",
            title: "Gravity through fewer words",
            domain: .transferLeadership,
            technique: "economy",
            why: "extra explanation can weaken a clear point; stopping earlier gives the decision more weight",
            howToApply: "make the point, then stop — resist the urge to add a third supporting sentence or soften it",
            successMarker: "you finish a point and hold the silence instead of padding it",
            whenToUse: "when delivery over-explains or seeks reassurance",
            voiceAlignment: [.executive, .authoritative],
            leverTags: [.conciseSpeaking, .pauseUsage, .confidence],
            evidenceTier: .folk,
            keywords: ["leadership", "presence", "over-explain", "less is more", "gravitas", "economy"]
        ),
        CoachKnowledgeCard(
            id: "leadership-summary-first-update",
            title: "Summary-first updates",
            domain: .transferLeadership,
            technique: "the executive summary",
            why: "senior stakeholders usually need the headline and implication before detail",
            howToApply: "open any update with the one-line takeaway and what it means, then offer detail only if they want it",
            successMarker: "your updates open on the takeaway, not the chronology",
            whenToUse: "when briefing senior stakeholders",
            voiceAlignment: [.executive, .concise],
            leverTags: [.conciseSpeaking, .structure],
            evidenceTier: .practitioner,
            keywords: ["leadership", "update", "summary", "stakeholder", "brief", "headline"]
        ),
        CoachKnowledgeCard(
            id: "leadership-hold-the-room-with-pause",
            title: "Hold the room with the pause, not volume",
            domain: .transferLeadership,
            technique: "the commanding pause",
            why: "raising your volume to hold attention reads as effort; a calm pause reads as someone who expects to be heard",
            howToApply: "when you want the room, drop a deliberate pause before your key line rather than getting louder",
            successMarker: "the room settles on your pause instead of your volume",
            whenToUse: "when competing for attention in a group",
            voiceAlignment: [.executive, .authoritative],
            leverTags: [.pauseUsage, .vocalEmphasis, .confidence],
            evidenceTier: .folk,
            keywords: ["leadership", "command", "room", "attention", "volume", "pause"]
        ),
    ]

    // MARK: Transfer — social / dating

    private static let socialCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "social-warmth-and-curiosity",
            title: "Warmth plus a real question",
            domain: .transferSocial,
            technique: "curiosity",
            why: "connection comes more from genuine interest than from being impressive; a real follow-up question does more than a clever line",
            howToApply: "instead of topping their story, ask the one thing you actually want to know about it",
            successMarker: "the other person opens up because you got curious about them",
            whenToUse: "in social conversation where you want to connect",
            voiceAlignment: [.warm],
            leverTags: [.confidence],
            evidenceTier: .practitioner,
            keywords: ["social", "dating", "small talk", "connection", "curiosity", "questions", "conversation"]
        ),
        CoachKnowledgeCard(
            id: "social-story-arc-small",
            title: "Small-stakes story arc",
            domain: .transferSocial,
            technique: "setup, turn, point",
            why: "even a tiny everyday story holds attention if it has a turn; a flat play-by-play loses people",
            howToApply: "tell the small story with one turn — \"I thought X, then this happened\" — and land it on a feeling or a point",
            successMarker: "everyday stories have a turn and a payoff instead of a flat recap",
            whenToUse: "when sharing in a social setting feels flat",
            voiceAlignment: [.storytelling, .warm],
            leverTags: [.answerDevelopment],
            evidenceTier: .folk,
            keywords: ["social", "story", "anecdote", "dating", "charisma", "engaging"]
        ),
        CoachKnowledgeCard(
            id: "social-invite-more",
            title: "Answer in a way that invites more",
            domain: .transferSocial,
            technique: "the open answer",
            why: "a one-word answer ends the thread; a short answer with a hook gives the other person something to grab",
            howToApply: "answer a social question in a sentence or two that leaves a thread — a detail they can ask about — rather than a flat yes or no",
            successMarker: "your answers keep the conversation moving instead of stalling it",
            whenToUse: "when conversations keep dying after your replies",
            voiceAlignment: [.warm, .storytelling],
            leverTags: [.answerDevelopment, .confidence],
            evidenceTier: .folk,
            keywords: ["social", "dating", "conversation", "small talk", "one word answers", "keep it going"]
        ),
    ]

    // MARK: Transfer — networking

    private static let networkingCards: [CoachKnowledgeCard] = [
        CoachKnowledgeCard(
            id: "networking-concise-self-frame",
            title: "The 15-second self-frame",
            domain: .transferNetworking,
            technique: "the concise self-frame",
            why: "in networking, a long self-intro loses people; a tight who-you-are-and-what-you-care-about leaves room for them",
            howToApply: "build a fifteen-second frame — what you do and the problem you care about — and stop there to let them respond",
            successMarker: "your intro lands in fifteen seconds and hands the floor back",
            whenToUse: "when introducing yourself at an event or meeting",
            voiceAlignment: [.concise, .executive],
            leverTags: [.conciseSpeaking, .openingStrength],
            evidenceTier: .folk,
            keywords: ["networking", "introduction", "elevator pitch", "self intro", "event", "who you are"]
        ),
        CoachKnowledgeCard(
            id: "networking-memorable-hook",
            title: "Lead with the memorable hook",
            domain: .transferNetworking,
            technique: "the hook",
            why: "people remember a concrete hook far better than a job title; one vivid line is what they'll repeat later",
            howToApply: "swap the title for a concrete hook — the surprising thing you do or the problem you solve — as your opening line",
            successMarker: "people remember and repeat your hook, not just your title",
            whenToUse: "when you want to be remembered after an event",
            voiceAlignment: [.storytelling, .persuasive],
            leverTags: [.openingStrength],
            evidenceTier: .folk,
            keywords: ["networking", "hook", "memorable", "pitch", "stand out", "introduction"]
        ),
        CoachKnowledgeCard(
            id: "networking-ask-before-assert",
            title: "Ask before you assert",
            domain: .transferNetworking,
            technique: "lead with curiosity",
            why: "leading with a question about them builds more rapport than leading with a pitch about you",
            howToApply: "open by asking what they're working on before you launch into your own thing — earn the floor by giving it first",
            successMarker: "conversations feel mutual instead of like you pitching at them",
            whenToUse: "at the start of a networking conversation",
            voiceAlignment: [.warm],
            leverTags: [.confidence],
            evidenceTier: .folk,
            keywords: ["networking", "rapport", "question", "ask", "curiosity", "pitch"]
        ),
    ]
}
