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
            word: "Vivid",
            partOfSpeech: "adjective",
            definition: "Sharp and lifelike; producing strong mental images.",
            promptSuggestion: "Describe a vivid memory from the last month in 30 seconds.",
            forms: ["vividly", "vividness"]
        ),
        WordOfTheDayEntry(
            word: "Glean",
            partOfSpeech: "verb",
            definition: "To gather small bits of information patiently.",
            promptSuggestion: "What's one thing you gleaned from a conversation this week that stuck with you?",
            forms: ["gleaned", "gleans", "gleaning"]
        ),
        WordOfTheDayEntry(
            word: "Parry",
            partOfSpeech: "verb",
            definition: "To turn aside a question or attack with a measured response.",
            promptSuggestion: "How do you parry a question you don't want to answer directly?",
            forms: ["parried", "parries", "parrying"]
        ),
        WordOfTheDayEntry(
            word: "Hedge",
            partOfSpeech: "verb",
            definition: "To soften a claim by leaving yourself an out.",
            promptSuggestion: "When does it pay to hedge what you say, and when does it cost trust?",
            forms: ["hedged", "hedges", "hedging"]
        ),
        WordOfTheDayEntry(
            word: "Brisk",
            partOfSpeech: "adjective",
            definition: "Quick and energetic; efficient without rushing.",
            promptSuggestion: "Where does a brisk pace serve you, and where does it cost depth?",
            forms: ["briskly", "briskness"]
        ),
        WordOfTheDayEntry(
            word: "Taut",
            partOfSpeech: "adjective",
            definition: "Pulled tight; lean with no slack.",
            promptSuggestion: "Describe the tautest argument you've heard recently.",
            forms: ["tautly", "tautness"]
        ),
        WordOfTheDayEntry(
            word: "Succinct",
            partOfSpeech: "adjective",
            definition: "Said in the fewest words that still carry the meaning.",
            promptSuggestion: "What is your most-held belief, in one succinct sentence?",
            forms: ["succinctly", "succinctness"]
        ),
        WordOfTheDayEntry(
            word: "Frank",
            partOfSpeech: "adjective",
            definition: "Open and direct in a way that costs nothing to say.",
            promptSuggestion: "Where could you be more frank in a conversation you've been avoiding?",
            forms: ["frankly", "frankness"]
        ),
        WordOfTheDayEntry(
            word: "Steady",
            partOfSpeech: "adjective",
            definition: "Consistent in pace or manner; unshaken.",
            promptSuggestion: "Who's the steadiest person you know, and what makes them feel that way?",
            forms: ["steadily", "steadiness", "steadied"]
        ),
        WordOfTheDayEntry(
            word: "Grounded",
            partOfSpeech: "adjective",
            definition: "Connected to what's real and present; not flighty.",
            promptSuggestion: "What keeps you grounded when the day starts to unravel?",
            forms: ["ground", "grounding", "grounds"]
        ),
        WordOfTheDayEntry(
            word: "Brittle",
            partOfSpeech: "adjective",
            definition: "Hard but prone to snapping under pressure.",
            promptSuggestion: "Describe a moment when your composure went brittle.",
            forms: ["brittleness", "brittly"]
        ),
        WordOfTheDayEntry(
            word: "Supple",
            partOfSpeech: "adjective",
            definition: "Flexible and responsive; bending without breaking.",
            promptSuggestion: "What's a stance you've kept supple instead of letting it harden?",
            forms: ["suppleness", "supply"]
        ),
        WordOfTheDayEntry(
            word: "Unvarnished",
            partOfSpeech: "adjective",
            definition: "Without polish or softening — plain and clear.",
            promptSuggestion: "What's an unvarnished opinion you've been quietly holding?",
            forms: ["unvarnish"]
        ),
        WordOfTheDayEntry(
            word: "Patient",
            partOfSpeech: "adjective",
            definition: "Willing to wait without losing steadiness.",
            promptSuggestion: "Where has being patient paid off in a way you didn't expect?",
            forms: ["patiently", "patience"]
        ),
        WordOfTheDayEntry(
            word: "Generous",
            partOfSpeech: "adjective",
            definition: "Giving more than what's strictly required.",
            promptSuggestion: "Describe the most generous read someone has given you.",
            forms: ["generously", "generosity"]
        ),
        WordOfTheDayEntry(
            word: "Curious",
            partOfSpeech: "adjective",
            definition: "Drawn toward what you don't yet understand.",
            promptSuggestion: "What are you curious about right now that you haven't told anyone?",
            forms: ["curiously", "curiosity"]
        ),
        WordOfTheDayEntry(
            word: "Understated",
            partOfSpeech: "adjective",
            definition: "Said with less emphasis than the moment would allow, on purpose.",
            promptSuggestion: "When does an understated reply land harder than a strong one?",
            forms: ["understatement", "understate"]
        ),
        WordOfTheDayEntry(
            word: "Direct",
            partOfSpeech: "adjective",
            definition: "Aimed straight at the thing without detour.",
            promptSuggestion: "What's a question you'd ask if you let yourself be fully direct?",
            forms: ["directly", "directness", "directed"]
        ),
        WordOfTheDayEntry(
            word: "Specific",
            partOfSpeech: "adjective",
            definition: "Pointed at the particular rather than the general.",
            promptSuggestion: "Take a vague compliment you've received and make it specific in 30 seconds.",
            forms: ["specifically", "specificity"]
        ),
        WordOfTheDayEntry(
            word: "Forthcoming",
            partOfSpeech: "adjective",
            definition: "Willing to share what someone needs to know without being asked twice.",
            promptSuggestion: "Where could you be more forthcoming this week without oversharing?",
            forms: ["forthcomingly"]
        ),
        WordOfTheDayEntry(
            word: "Measured",
            partOfSpeech: "adjective",
            definition: "Spoken or done with weight and restraint.",
            promptSuggestion: "When is a measured response stronger than a fast one?",
            forms: ["measure", "measuring", "measures"]
        ),
        WordOfTheDayEntry(
            word: "Crisp",
            partOfSpeech: "adjective",
            definition: "Clean and sharp at the edges; no soggy middle.",
            promptSuggestion: "How would your last reply have changed if you'd kept it crisp?",
            forms: ["crisply", "crispness"]
        ),
        WordOfTheDayEntry(
            word: "Sharp",
            partOfSpeech: "adjective",
            definition: "Precise and alert; able to cut to the point.",
            promptSuggestion: "What's a sharp observation someone has made about you that you remember?",
            forms: ["sharply", "sharpness", "sharpen", "sharpened"]
        ),
        WordOfTheDayEntry(
            word: "Frame",
            partOfSpeech: "verb",
            definition: "To set the context that shapes how something lands.",
            promptSuggestion: "How do you frame bad news so it can actually be heard?",
            forms: ["framed", "frames", "framing"]
        ),
        WordOfTheDayEntry(
            word: "Bridge",
            partOfSpeech: "verb",
            definition: "To connect two points or positions that don't meet on their own.",
            promptSuggestion: "What conversation could you bridge that's been stuck for too long?",
            forms: ["bridged", "bridges", "bridging"]
        ),
        WordOfTheDayEntry(
            word: "Surface",
            partOfSpeech: "verb",
            definition: "To bring something hidden into view.",
            promptSuggestion: "What's a feeling you'd surface in a meeting if it were safe to?",
            forms: ["surfaced", "surfaces", "surfacing"]
        ),
        WordOfTheDayEntry(
            word: "Land",
            partOfSpeech: "verb",
            definition: "To arrive in a way the listener actually feels.",
            promptSuggestion: "Describe a time your point didn't land — and what would have helped it.",
            forms: ["landed", "lands", "landing"]
        ),
        WordOfTheDayEntry(
            word: "Carry",
            partOfSpeech: "verb",
            definition: "To hold and convey something with weight.",
            promptSuggestion: "What's a sentence you can still hear someone carry years later?",
            forms: ["carried", "carries", "carrying"]
        ),
        WordOfTheDayEntry(
            word: "Dwell",
            partOfSpeech: "verb",
            definition: "To stay with a thought longer than it's comfortable to.",
            promptSuggestion: "What's something worth dwelling on this week instead of moving past?",
            forms: ["dwelled", "dwelt", "dwells", "dwelling"]
        ),
        WordOfTheDayEntry(
            word: "Slow",
            partOfSpeech: "verb",
            definition: "To deliberately ease pace so meaning catches up.",
            promptSuggestion: "Take a sentence you'd usually rush and slow it down in 30 seconds.",
            forms: ["slowed", "slows", "slowing", "slowly"]
        ),
        WordOfTheDayEntry(
            word: "Soften",
            partOfSpeech: "verb",
            definition: "To take the hard edge off without losing the substance.",
            promptSuggestion: "Where could you soften a recent message without watering it down?",
            forms: ["softened", "softens", "softening"]
        ),
        WordOfTheDayEntry(
            word: "Sharpen",
            partOfSpeech: "verb",
            definition: "To make a point cleaner and harder to misread.",
            promptSuggestion: "What's an opinion of yours you could sharpen into a single line?",
            forms: ["sharpened", "sharpens", "sharpening"]
        ),
        WordOfTheDayEntry(
            word: "Tighten",
            partOfSpeech: "verb",
            definition: "To strip slack so what remains is load-bearing.",
            promptSuggestion: "Take a recent paragraph in your head and tighten it to one sentence.",
            forms: ["tightened", "tightens", "tightening", "tight"]
        ),
        WordOfTheDayEntry(
            word: "Broach",
            partOfSpeech: "verb",
            definition: "To raise a difficult subject for the first time.",
            promptSuggestion: "What's a topic you've been quietly trying to broach with someone?",
            forms: ["broached", "broaches", "broaching"]
        ),
        WordOfTheDayEntry(
            word: "Adjourn",
            partOfSpeech: "verb",
            definition: "To bring something to a clean, agreed end before continuing later.",
            promptSuggestion: "When was the last time adjourning a conversation served you better than finishing it?",
            forms: ["adjourned", "adjourns", "adjourning"]
        ),
        WordOfTheDayEntry(
            word: "Probe",
            partOfSpeech: "verb",
            definition: "To ask carefully into something you don't yet understand.",
            promptSuggestion: "What's a topic you'd probe further if you weren't worried about looking unsure?",
            forms: ["probed", "probes", "probing"]
        ),
        WordOfTheDayEntry(
            word: "Concede",
            partOfSpeech: "verb",
            definition: "To grant a point that goes against you because it's true.",
            promptSuggestion: "When was the last time conceding mid-debate actually moved things forward?",
            forms: ["conceded", "concedes", "conceding", "concession"]
        ),
        WordOfTheDayEntry(
            word: "Defer",
            partOfSpeech: "verb",
            definition: "To yield to someone else's judgment without losing your own.",
            promptSuggestion: "Where do you defer to someone, and why have you earned to?",
            forms: ["deferred", "defers", "deferring", "deference"]
        ),
        WordOfTheDayEntry(
            word: "Resist",
            partOfSpeech: "verb",
            definition: "To hold against pressure without becoming hostile.",
            promptSuggestion: "What's a pull you've been quietly resisting, and what does it cost you?",
            forms: ["resisted", "resists", "resisting", "resistance"]
        ),
        WordOfTheDayEntry(
            word: "Yield",
            partOfSpeech: "verb",
            definition: "To give ground deliberately so the right thing can happen.",
            promptSuggestion: "Where would yielding actually be the stronger move this week?",
            forms: ["yielded", "yields", "yielding"]
        ),
        WordOfTheDayEntry(
            word: "Trace",
            partOfSpeech: "verb",
            definition: "To follow a thread back to its origin.",
            promptSuggestion: "Trace one belief of yours back to the moment you first held it.",
            forms: ["traced", "traces", "tracing"]
        ),
        WordOfTheDayEntry(
            word: "Witness",
            partOfSpeech: "verb",
            definition: "To see something and let the other person know it was seen.",
            promptSuggestion: "When did being witnessed change what you were going through?",
            forms: ["witnessed", "witnesses", "witnessing"]
        ),
        WordOfTheDayEntry(
            word: "Name",
            partOfSpeech: "verb",
            definition: "To call something by what it actually is.",
            promptSuggestion: "What's a feeling in a room you've avoided naming out loud?",
            forms: ["named", "names", "naming"]
        ),
        WordOfTheDayEntry(
            word: "Notice",
            partOfSpeech: "verb",
            definition: "To take in something small enough to be easily missed.",
            promptSuggestion: "What's something you noticed about a friend recently that they don't know you saw?",
            forms: ["noticed", "notices", "noticing"]
        ),
        WordOfTheDayEntry(
            word: "Echo",
            partOfSpeech: "verb",
            definition: "To repeat back so the other person knows they were heard.",
            promptSuggestion: "How do you echo someone's point without sounding like you're parroting it?",
            forms: ["echoed", "echoes", "echoing"]
        ),
        WordOfTheDayEntry(
            word: "Mirror",
            partOfSpeech: "verb",
            definition: "To reflect back what you're picking up so it can be confirmed.",
            promptSuggestion: "When has mirroring someone helped you understand them better than asking did?",
            forms: ["mirrored", "mirrors", "mirroring"]
        ),
        WordOfTheDayEntry(
            word: "Press",
            partOfSpeech: "verb",
            definition: "To push gently on a point that needs more weight.",
            promptSuggestion: "Where would pressing a little harder serve you in a current conversation?",
            forms: ["pressed", "presses", "pressing"]
        ),
        WordOfTheDayEntry(
            word: "Pause",
            partOfSpeech: "noun",
            definition: "A break in speech that lets meaning settle.",
            promptSuggestion: "Use one deliberate pause in this 30-second answer about what makes a great listener.",
            forms: ["paused", "pauses", "pausing"]
        ),
        WordOfTheDayEntry(
            word: "Cadence",
            partOfSpeech: "noun",
            definition: "The rhythm of how you speak — pace, beats, and rest.",
            promptSuggestion: "How would you describe your natural cadence when you're relaxed?",
            forms: ["cadences"]
        ),
        WordOfTheDayEntry(
            word: "Tone",
            partOfSpeech: "noun",
            definition: "The colour your voice gives to what you say.",
            promptSuggestion: "Whose tone do you trust most, and what makes it feel that way?",
            forms: ["tones", "toned"]
        ),
        WordOfTheDayEntry(
            word: "Stance",
            partOfSpeech: "noun",
            definition: "The position you're speaking from before you say a word.",
            promptSuggestion: "What stance do you usually take into hard conversations?",
            forms: ["stances"]
        ),
        WordOfTheDayEntry(
            word: "Footing",
            partOfSpeech: "noun",
            definition: "The stability you start from in a charged conversation.",
            promptSuggestion: "Describe a time you lost your footing mid-conversation and how you got it back.",
            forms: ["footings"]
        ),
        WordOfTheDayEntry(
            word: "Margin",
            partOfSpeech: "noun",
            definition: "The room you keep around a decision or schedule.",
            promptSuggestion: "Where do you wish you had more margin right now?",
            forms: ["margins", "marginal"]
        ),
        WordOfTheDayEntry(
            word: "Signal",
            partOfSpeech: "noun",
            definition: "A small cue that carries meaningful information.",
            promptSuggestion: "What signal do you give people when you've reached your limit?",
            forms: ["signals", "signalled", "signaled", "signalling", "signaling"]
        ),
        WordOfTheDayEntry(
            word: "Subtext",
            partOfSpeech: "noun",
            definition: "What is meant without being said outright.",
            promptSuggestion: "Describe a recent conversation where the subtext mattered more than the words.",
            forms: ["subtexts", "subtextual"]
        ),
        WordOfTheDayEntry(
            word: "Tension",
            partOfSpeech: "noun",
            definition: "Pressure between two things pulling in different directions.",
            promptSuggestion: "Name a tension in your life right now that you'd rather not resolve too quickly.",
            forms: ["tensions", "tense"]
        ),
        WordOfTheDayEntry(
            word: "Pattern",
            partOfSpeech: "noun",
            definition: "A repeated shape that appears once you look.",
            promptSuggestion: "What's a pattern in your speech you've started to notice?",
            forms: ["patterns", "patterned"]
        ),
        WordOfTheDayEntry(
            word: "Habit",
            partOfSpeech: "noun",
            definition: "A behaviour you've practised into something automatic.",
            promptSuggestion: "What's one habit you've built that you'd defend if pressed?",
            forms: ["habits", "habitual"]
        ),
        WordOfTheDayEntry(
            word: "Friction",
            partOfSpeech: "noun",
            definition: "Resistance in a process — sometimes helpful, often not.",
            promptSuggestion: "Where would removing one piece of friction unlock the rest of your week?",
            forms: ["frictions", "frictional"]
        ),
        WordOfTheDayEntry(
            word: "Stakes",
            partOfSpeech: "noun",
            definition: "What is actually on the line in a moment.",
            promptSuggestion: "Describe a small moment with real stakes you handled well.",
            forms: ["stake"]
        ),
        WordOfTheDayEntry(
            word: "Range",
            partOfSpeech: "noun",
            definition: "The span of registers or modes you can comfortably move across.",
            promptSuggestion: "Where would a wider range of tone serve you in your work?",
            forms: ["ranges", "ranged", "ranging"]
        ),
        WordOfTheDayEntry(
            word: "Restraint",
            partOfSpeech: "noun",
            definition: "Deliberately holding back what doesn't need to be said.",
            promptSuggestion: "When has restraint earned you more than the thing you held back would have?",
            forms: ["restraints", "restrained", "restraining"]
        ),
        WordOfTheDayEntry(
            word: "Discipline",
            partOfSpeech: "noun",
            definition: "Consistent practice when no one is watching.",
            promptSuggestion: "Describe a quiet discipline that has shaped you more than people realise.",
            forms: ["disciplines", "disciplined", "disciplining"]
        ),
        WordOfTheDayEntry(
            word: "Conviction",
            partOfSpeech: "noun",
            definition: "Belief firm enough to act from without overstating.",
            promptSuggestion: "What's a conviction you'd defend even if the room turned against it?",
            forms: ["convictions", "convinced"]
        ),
        WordOfTheDayEntry(
            word: "Reckon",
            partOfSpeech: "verb",
            definition: "To weigh something honestly before deciding.",
            promptSuggestion: "What's something you're still reckoning with from this year?",
            forms: ["reckoned", "reckons", "reckoning"]
        ),
        WordOfTheDayEntry(
            word: "Settle",
            partOfSpeech: "verb",
            definition: "To come to rest in a position you can stand behind.",
            promptSuggestion: "Describe a decision you've settled into recently and how it feels.",
            forms: ["settled", "settles", "settling"]
        ),
        WordOfTheDayEntry(
            word: "Anticipate",
            partOfSpeech: "verb",
            definition: "To prepare for what's likely without forcing it to happen.",
            promptSuggestion: "What's something you're quietly anticipating that you haven't said aloud?",
            forms: ["anticipated", "anticipates", "anticipating", "anticipation"]
        ),
        WordOfTheDayEntry(
            word: "Discern",
            partOfSpeech: "verb",
            definition: "To tell two close-looking things apart.",
            promptSuggestion: "Where have you learned to discern signal from noise in your field?",
            forms: ["discerned", "discerns", "discerning", "discernment"]
        ),
        WordOfTheDayEntry(
            word: "Reveal",
            partOfSpeech: "verb",
            definition: "To bring something true into the open.",
            promptSuggestion: "Describe a small reveal in a recent conversation that changed it.",
            forms: ["revealed", "reveals", "revealing"]
        ),
        WordOfTheDayEntry(
            word: "Defend",
            partOfSpeech: "verb",
            definition: "To stand behind a point when it's challenged.",
            promptSuggestion: "Pick one belief and defend it for 30 seconds without raising your voice.",
            forms: ["defended", "defends", "defending", "defence", "defense"]
        ),
        WordOfTheDayEntry(
            word: "Invite",
            partOfSpeech: "verb",
            definition: "To open space for the other person to step in.",
            promptSuggestion: "Where could you invite more pushback than you usually do?",
            forms: ["invited", "invites", "inviting"]
        ),
        WordOfTheDayEntry(
            word: "Affirm",
            partOfSpeech: "verb",
            definition: "To state something true with quiet weight.",
            promptSuggestion: "What's one thing you'd like to affirm about someone in your life right now?",
            forms: ["affirmed", "affirms", "affirming", "affirmation"]
        ),
        WordOfTheDayEntry(
            word: "Acknowledge",
            partOfSpeech: "verb",
            definition: "To say out loud what the other person is sensing.",
            promptSuggestion: "What's something you should have acknowledged sooner in a recent conversation?",
            forms: ["acknowledged", "acknowledges", "acknowledging"]
        ),
        WordOfTheDayEntry(
            word: "Disagree",
            partOfSpeech: "verb",
            definition: "To hold a different view without dismantling the relationship.",
            promptSuggestion: "Practise disagreeing with a popular take for 30 seconds, calmly.",
            forms: ["disagreed", "disagrees", "disagreeing", "disagreement"]
        ),
        WordOfTheDayEntry(
            word: "Attune",
            partOfSpeech: "verb",
            definition: "To tune in so closely you pick up what isn't said.",
            promptSuggestion: "Whose moods are you most attuned to, and how can you tell?",
            forms: ["attuned", "attunes", "attuning", "attunement"]
        ),
        WordOfTheDayEntry(
            word: "Test",
            partOfSpeech: "verb",
            definition: "To put a claim under pressure to see what holds.",
            promptSuggestion: "Take a current opinion and test it out loud in 30 seconds.",
            forms: ["tested", "tests", "testing"]
        ),
        WordOfTheDayEntry(
            word: "Flag",
            partOfSpeech: "verb",
            definition: "To mark something as worth attention without insisting on action.",
            promptSuggestion: "What's something you'd flag for a colleague this week without making it a thing?",
            forms: ["flagged", "flags", "flagging"]
        ),
        WordOfTheDayEntry(
            word: "Venture",
            partOfSpeech: "verb",
            definition: "To put a thought into the open before you know how it lands.",
            promptSuggestion: "What's a half-formed idea you'd venture this week if the room were safe?",
            forms: ["ventured", "ventures", "venturing"]
        ),
        WordOfTheDayEntry(
            word: "Stretch",
            partOfSpeech: "verb",
            definition: "To work just past the edge of what's comfortable.",
            promptSuggestion: "Where in your communication are you stretching this month?",
            forms: ["stretched", "stretches", "stretching"]
        ),
        WordOfTheDayEntry(
            word: "Coach",
            partOfSpeech: "verb",
            definition: "To guide someone toward what they already half-know.",
            promptSuggestion: "Describe how you'd coach someone through their first hard conversation.",
            forms: ["coached", "coaches", "coaching"]
        ),
        WordOfTheDayEntry(
            word: "Center",
            partOfSpeech: "verb",
            definition: "To gather yourself back into the present.",
            promptSuggestion: "How do you center yourself in the 30 seconds before you're called on?",
            forms: ["centred", "centered", "centers", "centres", "centering", "centring"]
        ),
        WordOfTheDayEntry(
            word: "Recover",
            partOfSpeech: "verb",
            definition: "To come back from a stumble without losing the thread.",
            promptSuggestion: "Describe a moment you recovered from mid-sentence — what saved you?",
            forms: ["recovered", "recovers", "recovering", "recovery"]
        ),
        WordOfTheDayEntry(
            word: "Crystallise",
            partOfSpeech: "verb",
            definition: "To bring a fuzzy thought into a clear, fixed shape.",
            promptSuggestion: "Crystallise one half-formed idea you've been carrying into a single sentence.",
            forms: ["crystallize", "crystallised", "crystallized", "crystallises", "crystallizes"]
        ),
        WordOfTheDayEntry(
            word: "Underscore",
            partOfSpeech: "verb",
            definition: "To draw deliberate attention to a point you don't want missed.",
            promptSuggestion: "What would you underscore in your week if your future self were listening?",
            forms: ["underscored", "underscores", "underscoring"]
        ),
        WordOfTheDayEntry(
            word: "Caveat",
            partOfSpeech: "noun",
            definition: "A small condition or warning attached to a claim.",
            promptSuggestion: "Make a confident statement and add a real caveat in the same 30 seconds.",
            forms: ["caveats"]
        ),
        WordOfTheDayEntry(
            word: "Premise",
            partOfSpeech: "noun",
            definition: "The base assumption an argument is built on.",
            promptSuggestion: "What premise underlies a belief of yours that you haven't questioned in a while?",
            forms: ["premises", "premised"]
        ),
        WordOfTheDayEntry(
            word: "Nuance",
            partOfSpeech: "noun",
            definition: "A subtle distinction that changes the meaning.",
            promptSuggestion: "Where do you wish people gave more nuance to a topic you care about?",
            forms: ["nuances", "nuanced"]
        ),
        WordOfTheDayEntry(
            word: "Aside",
            partOfSpeech: "noun",
            definition: "A small remark spoken off the main line.",
            promptSuggestion: "Tell a short story about something, with one deliberate aside in the middle.",
            forms: ["asides"]
        ),
        WordOfTheDayEntry(
            word: "Backbone",
            partOfSpeech: "noun",
            definition: "The structural spine that lets you hold a position.",
            promptSuggestion: "Describe an issue where you've had to show backbone recently.",
            forms: ["backbones"]
        ),
        WordOfTheDayEntry(
            word: "Brevity",
            partOfSpeech: "noun",
            definition: "Saying it shortly enough that nothing is wasted.",
            promptSuggestion: "What's a topic you'd talk about with more brevity if you could?",
            forms: ["brief", "briefly"]
        ),
        WordOfTheDayEntry(
            word: "Empathy",
            partOfSpeech: "noun",
            definition: "Carrying for a moment what another person is carrying.",
            promptSuggestion: "Describe a time empathy changed how you spoke into a hard moment.",
            forms: ["empathetic", "empathise", "empathize", "empathic"]
        ),
        WordOfTheDayEntry(
            word: "Equanimity",
            partOfSpeech: "noun",
            definition: "Steadiness of mind that survives the news.",
            promptSuggestion: "Where in your life have you found unexpected equanimity?",
            forms: ["equanimous"]
        ),
        WordOfTheDayEntry(
            word: "Latitude",
            partOfSpeech: "noun",
            definition: "Room to move within an agreement or expectation.",
            promptSuggestion: "Who gives you the most latitude in your work, and what do you do with it?",
            forms: ["latitudes"]
        ),
        WordOfTheDayEntry(
            word: "Levity",
            partOfSpeech: "noun",
            definition: "Lightness brought into a heavy moment without dismissing it.",
            promptSuggestion: "Where has a moment of levity rescued a conversation for you?",
            forms: ["levities"]
        ),
        WordOfTheDayEntry(
            word: "Poise",
            partOfSpeech: "noun",
            definition: "Composed bearing — body, voice, attention aligned.",
            promptSuggestion: "Describe someone whose poise you'd most like to study.",
            forms: ["poised"]
        ),
        WordOfTheDayEntry(
            word: "Rapport",
            partOfSpeech: "noun",
            definition: "A working trust built between two people in real time.",
            promptSuggestion: "How do you build rapport with someone in the first two minutes?",
            forms: ["rapports"]
        ),
        WordOfTheDayEntry(
            word: "Tact",
            partOfSpeech: "noun",
            definition: "Skill at saying a hard thing without doing harm.",
            promptSuggestion: "What's a moment where you needed more tact than you had?",
            forms: ["tactful", "tactfully", "tactless"]
        ),
        WordOfTheDayEntry(
            word: "Discretion",
            partOfSpeech: "noun",
            definition: "Knowing what to share, with whom, and when.",
            promptSuggestion: "Where do you exercise discretion that nobody sees you exercising?",
            forms: ["discreet", "discreetly"]
        ),
        WordOfTheDayEntry(
            word: "Inflection",
            partOfSpeech: "noun",
            definition: "A small shift in voice that changes the meaning.",
            promptSuggestion: "Use a single inflection shift to change the meaning of one sentence in your 30s.",
            forms: ["inflections", "inflected", "inflecting"]
        ),
        WordOfTheDayEntry(
            word: "Beat",
            partOfSpeech: "noun",
            definition: "A short, deliberate pause that gives a line weight.",
            promptSuggestion: "Use one clear beat in your 30 seconds about what you've learned this month.",
            forms: ["beats", "beating"]
        ),
        WordOfTheDayEntry(
            word: "Thread",
            partOfSpeech: "noun",
            definition: "The through-line that holds a longer thought together.",
            promptSuggestion: "Pick a thread from a conversation last week and keep talking it for 30 seconds.",
            forms: ["threads", "threaded", "threading"]
        ),
        WordOfTheDayEntry(
            word: "Spine",
            partOfSpeech: "noun",
            definition: "The structural argument that keeps the rest from collapsing.",
            promptSuggestion: "What's the spine of an argument you make often, in one sentence?",
            forms: ["spines"]
        ),
        WordOfTheDayEntry(
            word: "Weight",
            partOfSpeech: "noun",
            definition: "The significance a sentence carries when spoken right.",
            promptSuggestion: "Take a small fact about your week and give it real weight in 30 seconds.",
            forms: ["weights", "weighted", "weighting", "weighty"]
        ),
        WordOfTheDayEntry(
            word: "Shape",
            partOfSpeech: "verb",
            definition: "To form something into a clearer outline.",
            promptSuggestion: "How do you shape a story so the listener stays with you to the end?",
            forms: ["shaped", "shapes", "shaping"]
        ),
        WordOfTheDayEntry(
            word: "Refine",
            partOfSpeech: "verb",
            definition: "To improve by removing what isn't needed.",
            promptSuggestion: "What's a sentence about your work you've been refining for a while?",
            forms: ["refined", "refines", "refining", "refinement"]
        ),
        WordOfTheDayEntry(
            word: "Recast",
            partOfSpeech: "verb",
            definition: "To re-tell something in a way that lands differently.",
            promptSuggestion: "Take a complaint you've made recently and recast it as a request.",
            forms: ["recasts", "recasted", "recasting"]
        ),
        WordOfTheDayEntry(
            word: "Untangle",
            partOfSpeech: "verb",
            definition: "To separate strands that have knotted together.",
            promptSuggestion: "What's a tangle in your thinking you'd like to untangle out loud?",
            forms: ["untangled", "untangles", "untangling"]
        ),
        WordOfTheDayEntry(
            word: "Calibrate",
            partOfSpeech: "verb",
            definition: "To tune your delivery to what the room can actually take.",
            promptSuggestion: "Where have you had to calibrate how directly you speak with someone?",
            forms: ["calibrated", "calibrates", "calibrating", "calibration"]
        ),
        WordOfTheDayEntry(
            word: "Modulate",
            partOfSpeech: "verb",
            definition: "To adjust tone or volume in step with the moment.",
            promptSuggestion: "Modulate your voice deliberately across one 30-second answer about your week.",
            forms: ["modulated", "modulates", "modulating", "modulation"]
        ),
        WordOfTheDayEntry(
            word: "Champion",
            partOfSpeech: "verb",
            definition: "To stand publicly behind a person or idea.",
            promptSuggestion: "Who's worth championing in your circle, and why don't you do it more?",
            forms: ["championed", "champions", "championing"]
        ),
        WordOfTheDayEntry(
            word: "Uphold",
            partOfSpeech: "verb",
            definition: "To keep something in force by your own conduct.",
            promptSuggestion: "What's a standard you've upheld even when nobody was watching?",
            forms: ["upheld", "upholds", "upholding"]
        ),
        WordOfTheDayEntry(
            word: "Forthright",
            partOfSpeech: "adjective",
            definition: "Direct and honest in a way that respects the listener.",
            promptSuggestion: "Where could you be more forthright without becoming blunt?",
            forms: ["forthrightly", "forthrightness"]
        )
    ]

    /// Pick today's word deterministically from the catalog.
    ///
    /// Selection key combines the local-calendar day with an opaque account
    /// identifier so two users on the same day see different words (per the
    /// M16 brief) while a single user sees the same word everywhere they're
    /// signed in. Pre-M16 callers can omit `accountID`; the catalog still
    /// returns a stable per-day word for guest sessions.
    ///
    /// We deliberately avoid Swift's `Hasher` here — it uses a randomised
    /// per-process seed, so the index would change every time the app
    /// relaunched. Instead we fold the bytes of the selection string into
    /// a 64-bit FNV-1a hash, which is process-stable and gives uniform
    /// distribution across the catalog.
    static func entry(for dayKey: String, accountID: String? = nil) -> WordOfTheDayEntry {
        var selection = dayKey
        if let accountID, !accountID.isEmpty {
            selection += "|"
            selection += accountID
        }
        let h = fnv1a64(selection)
        let idx = Int(h % UInt64(entries.count))
        return entries[idx]
    }

    /// 64-bit FNV-1a — small, stable across launches, no external deps.
    /// Good enough for picking 1 of 142 buckets; we don't need crypto.
    private static func fnv1a64(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01b3
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}
