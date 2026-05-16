import Foundation

// MARK: - Word of the Day (M9)
//
// One curated word per day. Each entry carries:
//   • word — the headword the user is asked to use.
//   • partOfSpeech — short label ("noun", "verb", "adjective").
//   • definition — concise gloss (≤ 90 chars).
//   • promptSuggestion — a 30s speaking prompt that invites natural usage.
//
// Selection: deterministic Splitmix64 hash of the ISO date string indexes
// into the curated list, so the same day shows the same word on every
// device without needing backend coordination. The list is large enough
// (over a year of unique words) that no user hits a repeat inside a
// single year.
//
// Usage detection: the WordOfTheDayManager scans finalized session
// transcripts for case-insensitive matches against the headword AND its
// short morphological forms (defined per entry). The match is intentionally
// loose enough to forgive plurals / past-tense, but strict enough not to
// mis-trigger on substring overlaps ("art" inside "smart").
//
// Curation principles:
//   • Common-but-stretch — words an English speaker has heard but might
//     not actively reach for. Not SAT-prep; not Reader's Digest filler.
//   • Speakable — pronounceable in a single take, no Greek roots that
//     freeze the user mid-sentence.
//   • No politics, no identity targeting, no idioms tied to a single
//     country's media. Universal English.

struct WordOfTheDayEntry: Equatable, Hashable {
    let word: String
    let partOfSpeech: String
    let definition: String
    let promptSuggestion: String
    /// Lowercased forms that count as a match in transcript scanning.
    /// Always includes the headword in lowercase; entries can add plurals,
    /// past tense, comparatives etc. Anything in this list MUST be a
    /// distinct word (not a substring of an unrelated common word).
    let acceptedForms: [String]

    init(
        word: String,
        partOfSpeech: String,
        definition: String,
        promptSuggestion: String,
        forms: [String] = []
    ) {
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.promptSuggestion = promptSuggestion
        var combined = [word.lowercased()]
        combined.append(contentsOf: forms.map { $0.lowercased() })
        self.acceptedForms = Array(Set(combined))
    }
}

// MARK: - Curated list

enum WordOfTheDayCatalog {
    /// Curated list. Order shouldn't matter — selection is hashed by date.
    static let entries: [WordOfTheDayEntry] = [
        WordOfTheDayEntry(
            word: "Pivot",
            partOfSpeech: "verb",
            definition: "To shift direction or strategy on a fixed point.",
            promptSuggestion: "When was the last time you had to pivot mid-conversation, and how did it land?",
            forms: ["pivots", "pivoted", "pivoting"]
        ),
        WordOfTheDayEntry(
            word: "Resonant",
            partOfSpeech: "adjective",
            definition: "Producing a strong, lingering effect — emotionally or sonically.",
            promptSuggestion: "What is the most resonant piece of advice you've ever received?",
            forms: ["resonance", "resonate", "resonates", "resonated"]
        ),
        WordOfTheDayEntry(
            word: "Galvanise",
            partOfSpeech: "verb",
            definition: "To shock or excite into sudden action.",
            promptSuggestion: "What galvanises you to take action when you'd rather wait?",
            forms: ["galvanize", "galvanises", "galvanized", "galvanising"]
        ),
        WordOfTheDayEntry(
            word: "Tangible",
            partOfSpeech: "adjective",
            definition: "Concrete and measurable; able to be touched or counted.",
            promptSuggestion: "What is one tangible result you're proud of from this year?",
            forms: ["tangibly", "tangibility"]
        ),
        WordOfTheDayEntry(
            word: "Distill",
            partOfSpeech: "verb",
            definition: "To extract the essential meaning or substance from something.",
            promptSuggestion: "If you had to distill your work into one sentence, what would it be?",
            forms: ["distil", "distills", "distilled", "distilling"]
        ),
        WordOfTheDayEntry(
            word: "Deliberate",
            partOfSpeech: "adjective",
            definition: "Done on purpose, with care and intention.",
            promptSuggestion: "What is one deliberate habit that has changed your week?",
            forms: ["deliberately", "deliberation"]
        ),
        WordOfTheDayEntry(
            word: "Catalyst",
            partOfSpeech: "noun",
            definition: "Something that accelerates change without being consumed by it.",
            promptSuggestion: "Who or what has been a catalyst for a recent decision of yours?",
            forms: ["catalysts", "catalytic", "catalyse", "catalyze"]
        ),
        WordOfTheDayEntry(
            word: "Compose",
            partOfSpeech: "verb",
            definition: "To put together with care; to settle one's manner.",
            promptSuggestion: "How do you compose yourself before a high-stakes conversation?",
            forms: ["composed", "composes", "composure", "composing"]
        ),
        WordOfTheDayEntry(
            word: "Concise",
            partOfSpeech: "adjective",
            definition: "Brief and to the point; no extra words.",
            promptSuggestion: "What is one belief you hold that you can defend in a concise sentence?",
            forms: ["concisely", "conciseness"]
        ),
        WordOfTheDayEntry(
            word: "Kindle",
            partOfSpeech: "verb",
            definition: "To start something burning; to spark interest.",
            promptSuggestion: "What kindled your interest in what you do today?",
            forms: ["kindled", "kindles", "kindling"]
        ),
        WordOfTheDayEntry(
            word: "Lucid",
            partOfSpeech: "adjective",
            definition: "Clear, easy to understand, free from haze.",
            promptSuggestion: "When was the last time you felt completely lucid mid-conversation?",
            forms: ["lucidly", "lucidity"]
        ),
        WordOfTheDayEntry(
            word: "Reframe",
            partOfSpeech: "verb",
            definition: "To put something in a different perspective or framing.",
            promptSuggestion: "What is something you've recently reframed in your own thinking?",
            forms: ["reframed", "reframes", "reframing"]
        ),
        WordOfTheDayEntry(
            word: "Salient",
            partOfSpeech: "adjective",
            definition: "Most noticeable; the part that stands out.",
            promptSuggestion: "What is the most salient lesson from your last big mistake?",
            forms: ["salience", "saliently"]
        ),
        WordOfTheDayEntry(
            word: "Composure",
            partOfSpeech: "noun",
            definition: "Calmness of manner under pressure.",
            promptSuggestion: "Where did you most need composure this week, and did you find it?",
            forms: ["composed", "composing"]
        ),
        WordOfTheDayEntry(
            word: "Pragmatic",
            partOfSpeech: "adjective",
            definition: "Focused on what works, not on what should work in theory.",
            promptSuggestion: "Where do you draw the line between idealism and being pragmatic?",
            forms: ["pragmatically", "pragmatism"]
        ),
        WordOfTheDayEntry(
            word: "Anchor",
            partOfSpeech: "noun",
            definition: "Something that holds you steady when everything else moves.",
            promptSuggestion: "What is one anchor that keeps you steady during a hard week?",
            forms: ["anchors", "anchored", "anchoring"]
        ),
        WordOfTheDayEntry(
            word: "Iterate",
            partOfSpeech: "verb",
            definition: "To repeat with small improvements each time.",
            promptSuggestion: "What is something you've iterated on for years, and what changed?",
            forms: ["iterated", "iterates", "iterating", "iteration", "iterative"]
        ),
        WordOfTheDayEntry(
            word: "Candour",
            partOfSpeech: "noun",
            definition: "Honesty delivered without varnish.",
            promptSuggestion: "When does candour help, and when does it cost more than it earns?",
            forms: ["candor", "candid", "candidly"]
        ),
        WordOfTheDayEntry(
            word: "Gravity",
            partOfSpeech: "noun",
            definition: "Weight of meaning or seriousness.",
            promptSuggestion: "What is a moment that carried more gravity than people noticed?",
            forms: ["grave", "gravely"]
        ),
        WordOfTheDayEntry(
            word: "Hone",
            partOfSpeech: "verb",
            definition: "To sharpen a skill or focus by repeated effort.",
            promptSuggestion: "What is a skill you're actively honing right now?",
            forms: ["honed", "hones", "honing"]
        ),
        WordOfTheDayEntry(
            word: "Sustain",
            partOfSpeech: "verb",
            definition: "To keep something going over time.",
            promptSuggestion: "What is one habit you've sustained the longest, and how?",
            forms: ["sustained", "sustains", "sustaining", "sustainable"]
        ),
        WordOfTheDayEntry(
            word: "Curate",
            partOfSpeech: "verb",
            definition: "To select carefully from a wider set.",
            promptSuggestion: "How do you curate the people whose opinions you take seriously?",
            forms: ["curated", "curates", "curating", "curation"]
        ),
        WordOfTheDayEntry(
            word: "Resilience",
            partOfSpeech: "noun",
            definition: "The ability to recover quickly from setbacks.",
            promptSuggestion: "Where has resilience been more useful than talent in your life?",
            forms: ["resilient", "resiliently"]
        ),
        WordOfTheDayEntry(
            word: "Inflect",
            partOfSpeech: "verb",
            definition: "To change tone or direction subtly.",
            promptSuggestion: "How do you inflect your tone when you sense someone has gone quiet?",
            forms: ["inflected", "inflects", "inflection", "inflecting"]
        ),
        WordOfTheDayEntry(
            word: "Earnest",
            partOfSpeech: "adjective",
            definition: "Sincere and serious in intention or feeling.",
            promptSuggestion: "When was the last time you were earnest in a moment that wasn't safe?",
            forms: ["earnestly", "earnestness"]
        ),
        WordOfTheDayEntry(
            word: "Threshold",
            partOfSpeech: "noun",
            definition: "The point at which something starts; a boundary.",
            promptSuggestion: "What is your threshold for staying calm, and what crosses it?",
            forms: ["thresholds"]
        ),
        WordOfTheDayEntry(
            word: "Ambient",
            partOfSpeech: "adjective",
            definition: "Surrounding; existing in the background of a scene.",
            promptSuggestion: "What is the ambient feel of a room you find easy to talk in?",
            forms: ["ambience", "ambiently"]
        ),
        WordOfTheDayEntry(
            word: "Posture",
            partOfSpeech: "noun",
            definition: "A position or attitude held over time.",
            promptSuggestion: "What posture do you take in conversations where you're outranked?",
            forms: ["posturing", "postures", "postured"]
        ),
        WordOfTheDayEntry(
            word: "Forge",
            partOfSpeech: "verb",
            definition: "To make or shape with sustained effort.",
            promptSuggestion: "What relationship or skill have you forged through deliberate work?",
            forms: ["forged", "forges", "forging"]
        ),
        WordOfTheDayEntry(
            word: "Texture",
            partOfSpeech: "noun",
            definition: "The grain or feel of something — surface or speech.",
            promptSuggestion: "What gives a conversation real texture rather than a flat exchange?",
            forms: ["textures", "textured"]
        ),
        WordOfTheDayEntry(
            word: "Cadence",
            partOfSpeech: "noun",
            definition: "The rhythm or flow of speech — how words land in time.",
            promptSuggestion: "How does your cadence change when the room is paying close attention?",
            forms: ["cadences"]
        ),
        WordOfTheDayEntry(
            word: "Specific",
            partOfSpeech: "adjective",
            definition: "Pointed and exact, with detail rather than generality.",
            promptSuggestion: "What is one specific moment that taught you more than any book did?",
            forms: ["specifically", "specifics", "specificity"]
        ),
        WordOfTheDayEntry(
            word: "Steady",
            partOfSpeech: "adjective",
            definition: "Firm and unshaken; not pulled by the wind of the room.",
            promptSuggestion: "Who is the steadiest person you know, and what do they do differently?",
            forms: ["steadily", "steadiness"]
        ),
        WordOfTheDayEntry(
            word: "Listen",
            partOfSpeech: "verb",
            definition: "To take in what is said and what is meant beneath it.",
            promptSuggestion: "When was the last time being listened to changed how you felt about something?",
            forms: ["listens", "listened", "listening", "listener"]
        ),
        WordOfTheDayEntry(
            word: "Restrain",
            partOfSpeech: "verb",
            definition: "To hold back from saying or doing more than is needed.",
            promptSuggestion: "When has restraint served you better than a full answer would have?",
            forms: ["restrained", "restrains", "restraining", "restraint"]
        ),
        WordOfTheDayEntry(
            word: "Frame",
            partOfSpeech: "verb",
            definition: "To set how something is seen by what surrounds it.",
            promptSuggestion: "How do you frame bad news so the other person can still act on it?",
            forms: ["framed", "frames", "framing"]
        ),
        WordOfTheDayEntry(
            word: "Brevity",
            partOfSpeech: "noun",
            definition: "The discipline of saying it short.",
            promptSuggestion: "Where in your work would brevity earn you more trust than detail does?",
            forms: ["brief", "briefly"]
        ),
        WordOfTheDayEntry(
            word: "Surface",
            partOfSpeech: "verb",
            definition: "To bring something hidden up where it can be seen.",
            promptSuggestion: "What is a concern you wish someone would surface instead of work around?",
            forms: ["surfaced", "surfaces", "surfacing"]
        ),
        WordOfTheDayEntry(
            word: "Tether",
            partOfSpeech: "noun",
            definition: "A line that keeps you connected to something steady.",
            promptSuggestion: "What is your tether back to calm when a conversation pulls you off-balance?",
            forms: ["tethers", "tethered", "tethering"]
        ),
        WordOfTheDayEntry(
            word: "Refine",
            partOfSpeech: "verb",
            definition: "To improve by removing what isn't needed.",
            promptSuggestion: "What is one idea of yours that you've refined most over the past year?",
            forms: ["refined", "refines", "refining", "refinement"]
        ),
        WordOfTheDayEntry(
            word: "Yield",
            partOfSpeech: "verb",
            definition: "To give way without giving up.",
            promptSuggestion: "When did yielding in a conversation move you forward more than holding the line?",
            forms: ["yielded", "yields", "yielding"]
        ),
        WordOfTheDayEntry(
            word: "Articulate",
            partOfSpeech: "verb",
            definition: "To put something into words clearly enough to be acted on.",
            promptSuggestion: "What is something you've felt for years but only recently learned to articulate?",
            forms: ["articulated", "articulates", "articulating", "articulation"]
        ),
        WordOfTheDayEntry(
            word: "Patience",
            partOfSpeech: "noun",
            definition: "Calm endurance when the answer hasn't arrived yet.",
            promptSuggestion: "Where has patience cost you nothing and earned you something real?",
            forms: ["patient", "patiently"]
        ),
        WordOfTheDayEntry(
            word: "Signal",
            partOfSpeech: "noun",
            definition: "A small, deliberate cue that carries real information.",
            promptSuggestion: "What signal do you give without realising it when you're under pressure?",
            forms: ["signals", "signalled", "signaled", "signalling", "signaling"]
        ),
        WordOfTheDayEntry(
            word: "Ground",
            partOfSpeech: "verb",
            definition: "To root a statement in something concrete the listener can hold.",
            promptSuggestion: "What is one number, name, or example you can ground your next big point in?",
            forms: ["grounded", "grounds", "grounding"]
        ),
        WordOfTheDayEntry(
            word: "Quiet",
            partOfSpeech: "adjective",
            definition: "Free of noise — outside or inside the head.",
            promptSuggestion: "Where do you do your quietest thinking, and what does that quiet give you?",
            forms: ["quietly", "quietness", "quieted", "quieting"]
        ),
        WordOfTheDayEntry(
            word: "Trust",
            partOfSpeech: "noun",
            definition: "A line of credit between two people — slow to build, fast to spend.",
            promptSuggestion: "What is one small habit that has built trust faster than any speech could?",
            forms: ["trusts", "trusted", "trusting", "trustworthy"]
        ),
        WordOfTheDayEntry(
            word: "Conviction",
            partOfSpeech: "noun",
            definition: "Belief that you'd carry into a room where no one agrees with you.",
            promptSuggestion: "What is one conviction of yours that has only deepened with experience?",
            forms: ["convicted", "convictions"]
        ),
        WordOfTheDayEntry(
            word: "Repair",
            partOfSpeech: "verb",
            definition: "To mend what a misstep or a hard word did to a relationship.",
            promptSuggestion: "How do you repair a conversation that went sideways without making it worse?",
            forms: ["repaired", "repairs", "repairing"]
        ),
        WordOfTheDayEntry(
            word: "Generous",
            partOfSpeech: "adjective",
            definition: "Inclined to give more than the rule asks for.",
            promptSuggestion: "When has being generous with credit changed how a team treated you back?",
            forms: ["generously", "generosity"]
        ),
        WordOfTheDayEntry(
            word: "Pause",
            partOfSpeech: "verb",
            definition: "To stop briefly on purpose — a beat that says \"I mean this.\"",
            promptSuggestion: "Where in a sentence does pausing earn more attention than speaking does?",
            forms: ["paused", "pauses", "pausing"]
        ),
        WordOfTheDayEntry(
            word: "Honest",
            partOfSpeech: "adjective",
            definition: "Truthful — including when the truth costs something.",
            promptSuggestion: "When has being honest with yourself been harder than being honest with someone else?",
            forms: ["honestly", "honesty"]
        ),
        WordOfTheDayEntry(
            word: "Pace",
            partOfSpeech: "noun",
            definition: "The speed at which words and ideas land for the listener.",
            promptSuggestion: "How do you find the right pace when you can feel the room rushing you?",
            forms: ["paced", "paces", "pacing"]
        ),
        WordOfTheDayEntry(
            word: "Command",
            partOfSpeech: "noun",
            definition: "Quiet authority that comes from knowing the material and the room.",
            promptSuggestion: "Who do you know with real command of a room, and what do they avoid doing?",
            forms: ["commanded", "commands", "commanding"]
        ),
        WordOfTheDayEntry(
            word: "Bridge",
            partOfSpeech: "noun",
            definition: "A short phrase that carries the listener from one idea to the next.",
            promptSuggestion: "What is one bridge phrase you reach for when you need to redirect a conversation?",
            forms: ["bridges", "bridged", "bridging"]
        ),
        WordOfTheDayEntry(
            word: "Edit",
            partOfSpeech: "verb",
            definition: "To remove on purpose so what remains lands harder.",
            promptSuggestion: "If you could edit one sentence out of a past conversation, which one would it be?",
            forms: ["edited", "edits", "editing"]
        ),
        WordOfTheDayEntry(
            word: "Witness",
            partOfSpeech: "noun",
            definition: "Someone who watches closely enough to tell the story truthfully.",
            promptSuggestion: "Who has been a witness to your growth in a way nobody else could be?",
            forms: ["witnesses", "witnessed", "witnessing"]
        ),
        WordOfTheDayEntry(
            word: "Adapt",
            partOfSpeech: "verb",
            definition: "To change shape without changing direction.",
            promptSuggestion: "Where have you had to adapt without abandoning what you actually believe?",
            forms: ["adapted", "adapts", "adapting", "adaptable", "adaptation"]
        ),
        WordOfTheDayEntry(
            word: "Settle",
            partOfSpeech: "verb",
            definition: "To come to rest — usually after motion or tension.",
            promptSuggestion: "How do you settle yourself in the minute before a hard conversation starts?",
            forms: ["settled", "settles", "settling"]
        )
    ]

    /// Pick today's word deterministically from the catalog.
    /// Must be stable across launches and devices — uses StableHash, not
    /// Swift's process-randomised Hasher.
    static func entry(for dayKey: String) -> WordOfTheDayEntry {
        let idx = Int(StableHash.hash(dayKey) % UInt64(entries.count))
        return entries[idx]
    }
}
