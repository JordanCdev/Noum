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
            definition: "The rhythm and flow of how something is spoken or done.",
            promptSuggestion: "What is your natural cadence when you're speaking with confidence?",
            forms: ["cadences"]
        ),
        WordOfTheDayEntry(
            word: "Tether",
            partOfSpeech: "verb",
            definition: "To bind or connect something to a fixed point.",
            promptSuggestion: "What value do you tether your decisions to when things get noisy?",
            forms: ["tethered", "tethers", "tethering"]
        ),
        WordOfTheDayEntry(
            word: "Kindred",
            partOfSpeech: "adjective",
            definition: "Sharing a similar nature, spirit, or feeling.",
            promptSuggestion: "Who is the most kindred mind you've spoken to recently?",
            forms: []
        ),
        WordOfTheDayEntry(
            word: "Steward",
            partOfSpeech: "verb",
            definition: "To responsibly look after or manage something on behalf of others.",
            promptSuggestion: "What is something you steward that others are counting on?",
            forms: ["stewards", "stewarded", "stewarding", "stewardship"]
        ),
        WordOfTheDayEntry(
            word: "Astute",
            partOfSpeech: "adjective",
            definition: "Sharp in judgement; quick to read a situation.",
            promptSuggestion: "What is the most astute observation someone has ever made about you?",
            forms: ["astutely"]
        ),
        WordOfTheDayEntry(
            word: "Weather",
            partOfSpeech: "verb",
            definition: "To withstand and come through a difficult period.",
            promptSuggestion: "What is something hard you've weathered that you don't talk about often?",
            forms: ["weathered", "weathers", "weathering"]
        ),
        WordOfTheDayEntry(
            word: "Provenance",
            partOfSpeech: "noun",
            definition: "The origin or source of something — the trail it came from.",
            promptSuggestion: "What is the provenance of an idea you've been carrying for years?",
            forms: []
        ),
        WordOfTheDayEntry(
            word: "Lattice",
            partOfSpeech: "noun",
            definition: "A structure of crossing supports — small parts holding a whole.",
            promptSuggestion: "What lattice of small habits is keeping a bigger goal of yours upright?",
            forms: ["lattices"]
        ),
        WordOfTheDayEntry(
            word: "Quell",
            partOfSpeech: "verb",
            definition: "To put down or quiet — usually a feeling or a disturbance.",
            promptSuggestion: "How do you quell the urge to fill a silence that's working in your favour?",
            forms: ["quelled", "quells", "quelling"]
        ),
        WordOfTheDayEntry(
            word: "Latitude",
            partOfSpeech: "noun",
            definition: "Room to move; freedom from rigid limits.",
            promptSuggestion: "Where do you give yourself the most latitude, and where do you give the least?",
            forms: []
        ),
        WordOfTheDayEntry(
            word: "Reckon",
            partOfSpeech: "verb",
            definition: "To work out, judge, or come to terms with something.",
            promptSuggestion: "What are you still reckoning with that you thought you'd settled?",
            forms: ["reckoned", "reckons", "reckoning"]
        ),
        WordOfTheDayEntry(
            word: "Vivid",
            partOfSpeech: "adjective",
            definition: "Strikingly bright, clear, and lifelike.",
            promptSuggestion: "What is the most vivid memory you can describe in three sentences?",
            forms: ["vividly", "vividness"]
        ),
        WordOfTheDayEntry(
            word: "Sober",
            partOfSpeech: "adjective",
            definition: "Serious, clear-eyed, free of exaggeration.",
            promptSuggestion: "What is your sober read of where you are versus where you wanted to be?",
            forms: ["soberly", "sobering"]
        ),
        WordOfTheDayEntry(
            word: "Buoyant",
            partOfSpeech: "adjective",
            definition: "Light; cheerful and resilient under pressure.",
            promptSuggestion: "What keeps you buoyant when a week stretches longer than you expected?",
            forms: ["buoyancy", "buoyantly"]
        ),
        WordOfTheDayEntry(
            word: "Pith",
            partOfSpeech: "noun",
            definition: "The essential, concentrated core of something.",
            promptSuggestion: "What is the pith of an argument you keep having to make?",
            forms: ["pithy", "pithily"]
        ),
        WordOfTheDayEntry(
            word: "Linger",
            partOfSpeech: "verb",
            definition: "To stay longer than expected; to dwell.",
            promptSuggestion: "What is one comment from this year that still lingers with you?",
            forms: ["lingered", "lingers", "lingering"]
        ),
        WordOfTheDayEntry(
            word: "Sharpen",
            partOfSpeech: "verb",
            definition: "To make more precise, more clear, more pointed.",
            promptSuggestion: "What is one thing you'd sharpen about how you make a first impression?",
            forms: ["sharpened", "sharpens", "sharpening"]
        ),
        WordOfTheDayEntry(
            word: "Equanimity",
            partOfSpeech: "noun",
            definition: "Mental calm and balance, especially under strain.",
            promptSuggestion: "What practice has done the most for your equanimity this year?",
            forms: []
        ),
        WordOfTheDayEntry(
            word: "Decisive",
            partOfSpeech: "adjective",
            definition: "Settling an outcome; acting with clear intent.",
            promptSuggestion: "What was the most decisive 60 seconds of your last big choice?",
            forms: ["decisively", "decisiveness"]
        ),
        WordOfTheDayEntry(
            word: "Patina",
            partOfSpeech: "noun",
            definition: "The surface character that comes only with time and use.",
            promptSuggestion: "What part of your work has a patina that newer people can't fake?",
            forms: []
        ),
        WordOfTheDayEntry(
            word: "Restless",
            partOfSpeech: "adjective",
            definition: "Unable to settle; charged with the need to move.",
            promptSuggestion: "What is making you restless right now that you haven't named out loud?",
            forms: ["restlessly", "restlessness"]
        ),
        WordOfTheDayEntry(
            word: "Agile",
            partOfSpeech: "adjective",
            definition: "Quick to adapt; light on the feet, mentally or physically.",
            promptSuggestion: "Where do you need to be more agile than you currently are?",
            forms: ["agilely", "agility"]
        ),
        WordOfTheDayEntry(
            word: "Refrain",
            partOfSpeech: "verb",
            definition: "To hold back from doing something on purpose.",
            promptSuggestion: "What is one thing you've trained yourself to refrain from saying?",
            forms: ["refrained", "refrains", "refraining"]
        ),
        WordOfTheDayEntry(
            word: "Resolute",
            partOfSpeech: "adjective",
            definition: "Firm in purpose; not wavering once a decision is made.",
            promptSuggestion: "When were you most resolute, and what made it possible to hold the line?",
            forms: ["resolutely", "resolution"]
        ),
        WordOfTheDayEntry(
            word: "Supple",
            partOfSpeech: "adjective",
            definition: "Bending easily without breaking; adaptive but strong.",
            promptSuggestion: "What part of your thinking has stayed supple while the rest hardened?",
            forms: ["supplely", "suppleness"]
        ),
        WordOfTheDayEntry(
            word: "Conviction",
            partOfSpeech: "noun",
            definition: "A firmly held belief, expressed or not.",
            promptSuggestion: "What is one conviction you've grown into rather than inherited?",
            forms: ["convictions"]
        ),
        WordOfTheDayEntry(
            word: "Glide",
            partOfSpeech: "verb",
            definition: "To move smoothly, with little visible effort.",
            promptSuggestion: "Which conversations do you glide through, and what makes them feel that way?",
            forms: ["glided", "glides", "gliding"]
        ),
        WordOfTheDayEntry(
            word: "Discern",
            partOfSpeech: "verb",
            definition: "To recognise or distinguish with care.",
            promptSuggestion: "What can you discern about a person within the first sixty seconds?",
            forms: ["discerned", "discerns", "discerning", "discernment"]
        ),
        WordOfTheDayEntry(
            word: "Contour",
            partOfSpeech: "noun",
            definition: "The shape or outline of something — its defining edges.",
            promptSuggestion: "What contour does your best work share that your weakest doesn't?",
            forms: ["contours", "contoured"]
        ),
        WordOfTheDayEntry(
            word: "Steady",
            partOfSpeech: "verb",
            definition: "To make firm; to balance against motion or pressure.",
            promptSuggestion: "What steadies you in the last sixty seconds before a hard conversation?",
            forms: ["steadied", "steadies", "steadying"]
        ),
        WordOfTheDayEntry(
            word: "Vouch",
            partOfSpeech: "verb",
            definition: "To assert with confidence based on direct experience.",
            promptSuggestion: "What is one outcome you'd vouch for personally even when no one is checking?",
            forms: ["vouched", "vouches", "vouching"]
        ),
        WordOfTheDayEntry(
            word: "Latent",
            partOfSpeech: "adjective",
            definition: "Existing but not yet visible or active.",
            promptSuggestion: "What latent skill of yours hasn't been called on for a while?",
            forms: ["latency"]
        ),
        WordOfTheDayEntry(
            word: "Yield",
            partOfSpeech: "verb",
            definition: "To produce; to give way under measured pressure.",
            promptSuggestion: "What has thirty minutes a day reliably yielded for you over the years?",
            forms: ["yielded", "yields", "yielding"]
        ),
        WordOfTheDayEntry(
            word: "Render",
            partOfSpeech: "verb",
            definition: "To express or represent something in a particular form.",
            promptSuggestion: "How would you render an idea you care about to someone who's never heard it?",
            forms: ["rendered", "renders", "rendering"]
        ),
        WordOfTheDayEntry(
            word: "Revise",
            partOfSpeech: "verb",
            definition: "To reconsider and change something with new understanding.",
            promptSuggestion: "What is a belief you've quietly revised in the last twelve months?",
            forms: ["revised", "revises", "revising", "revision"]
        ),
        WordOfTheDayEntry(
            word: "Tempo",
            partOfSpeech: "noun",
            definition: "The pace or speed at which something unfolds.",
            promptSuggestion: "What tempo do you do your sharpest thinking at, and how do you find it?",
            forms: ["tempos"]
        ),
        WordOfTheDayEntry(
            word: "Brevity",
            partOfSpeech: "noun",
            definition: "Shortness in time or in words.",
            promptSuggestion: "Where has brevity served you better than a longer answer would have?",
            forms: []
        ),
        WordOfTheDayEntry(
            word: "Prudent",
            partOfSpeech: "adjective",
            definition: "Acting with care and forethought, not just speed.",
            promptSuggestion: "What is a prudent decision you nearly didn't make?",
            forms: ["prudence", "prudently"]
        ),
        WordOfTheDayEntry(
            word: "Fortitude",
            partOfSpeech: "noun",
            definition: "Strength of mind that lets you bear pain or hardship.",
            promptSuggestion: "When did fortitude get you through something talent could not?",
            forms: []
        ),
        WordOfTheDayEntry(
            word: "Gentle",
            partOfSpeech: "verb",
            definition: "To soften, ease, or reduce force without losing the message.",
            promptSuggestion: "What is one truth you've learnt to gentle without losing its edge?",
            forms: ["gentled", "gentles", "gentling"]
        ),
        WordOfTheDayEntry(
            word: "Prevail",
            partOfSpeech: "verb",
            definition: "To succeed against opposition or difficulty.",
            promptSuggestion: "Where have you prevailed quietly without anyone else seeing it?",
            forms: ["prevailed", "prevails", "prevailing"]
        )
    ]

    /// Pick today's word deterministically from the catalog.
    static func entry(for dayKey: String) -> WordOfTheDayEntry {
        var hasher = Hasher()
        hasher.combine(dayKey)
        let h = hasher.finalize()
        let idx = abs(h) % entries.count
        return entries[idx]
    }
}
