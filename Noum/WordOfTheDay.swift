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

        // MARK: Speaking craft

        WordOfTheDayEntry(
            word: "Articulate",
            partOfSpeech: "verb",
            definition: "To express an idea with clear shape and edges.",
            promptSuggestion: "What is one thought you've been trying to articulate but couldn't yet?",
            forms: ["articulated", "articulates", "articulating", "articulation"]
        ),
        WordOfTheDayEntry(
            word: "Cadence",
            partOfSpeech: "noun",
            definition: "The rhythm and lift of how someone speaks.",
            promptSuggestion: "Whose speaking cadence do you most enjoy listening to, and why?",
            forms: ["cadences"]
        ),
        WordOfTheDayEntry(
            word: "Modulate",
            partOfSpeech: "verb",
            definition: "To adjust tone, volume, or pace as the moment asks.",
            promptSuggestion: "When do you most need to modulate your volume mid-conversation?",
            forms: ["modulated", "modulates", "modulating", "modulation"]
        ),
        WordOfTheDayEntry(
            word: "Phrase",
            partOfSpeech: "verb",
            definition: "To choose the exact words that carry a thought best.",
            promptSuggestion: "How would you phrase the hardest truth you've had to deliver this year?",
            forms: ["phrased", "phrases", "phrasing"]
        ),
        WordOfTheDayEntry(
            word: "Project",
            partOfSpeech: "verb",
            definition: "To send the voice cleanly across a room.",
            promptSuggestion: "Where do you find it hardest to project, and what changes when you do?",
            forms: ["projected", "projects", "projecting", "projection"]
        ),
        WordOfTheDayEntry(
            word: "Diction",
            partOfSpeech: "noun",
            definition: "The clarity and care of how each word is shaped.",
            promptSuggestion: "Whose diction sounds effortless to you, and what would you steal from it?"
        ),
        WordOfTheDayEntry(
            word: "Punctuate",
            partOfSpeech: "verb",
            definition: "To break speech with pauses that give meaning room to land.",
            promptSuggestion: "Where could a pause have punctuated a recent point of yours better?",
            forms: ["punctuated", "punctuates", "punctuating", "punctuation"]
        ),
        WordOfTheDayEntry(
            word: "Voice",
            partOfSpeech: "verb",
            definition: "To put a private thought into the room.",
            promptSuggestion: "What is something you've been meaning to voice but haven't yet?",
            forms: ["voiced", "voices", "voicing"]
        ),
        WordOfTheDayEntry(
            word: "Land",
            partOfSpeech: "verb",
            definition: "To make a point connect rather than drift past.",
            promptSuggestion: "What was the last point you really wanted to land — and did it?",
            forms: ["landed", "lands", "landing"]
        ),
        WordOfTheDayEntry(
            word: "Address",
            partOfSpeech: "verb",
            definition: "To meet a subject directly rather than skirt it.",
            promptSuggestion: "What is one issue you've been circling that's time to address?",
            forms: ["addressed", "addresses", "addressing"]
        ),

        // MARK: Judgement and decision-making

        WordOfTheDayEntry(
            word: "Discern",
            partOfSpeech: "verb",
            definition: "To see a fine distinction others miss.",
            promptSuggestion: "What is a distinction you've learned to discern that took years?",
            forms: ["discerned", "discerns", "discerning", "discernment"]
        ),
        WordOfTheDayEntry(
            word: "Calibrate",
            partOfSpeech: "verb",
            definition: "To adjust until something matches the moment exactly.",
            promptSuggestion: "Where do you calibrate hardest — tone, pace, or word choice?",
            forms: ["calibrated", "calibrates", "calibrating", "calibration"]
        ),
        WordOfTheDayEntry(
            word: "Vet",
            partOfSpeech: "verb",
            definition: "To check carefully before letting something forward.",
            promptSuggestion: "How do you vet advice before you let it shape a real decision?",
            forms: ["vetted", "vets", "vetting"]
        ),
        WordOfTheDayEntry(
            word: "Weigh",
            partOfSpeech: "verb",
            definition: "To hold competing values and feel their relative pull.",
            promptSuggestion: "What is something you're weighing this week that's harder than it looks?",
            forms: ["weighed", "weighs", "weighing"]
        ),
        WordOfTheDayEntry(
            word: "Audit",
            partOfSpeech: "verb",
            definition: "To look back honestly at what was done and what wasn't.",
            promptSuggestion: "When was the last time you audited your own week without flinching?",
            forms: ["audited", "audits", "auditing"]
        ),
        WordOfTheDayEntry(
            word: "Sift",
            partOfSpeech: "verb",
            definition: "To separate what matters from what surrounds it.",
            promptSuggestion: "Where in your week do you sift signal from noise the best?",
            forms: ["sifted", "sifts", "sifting"]
        ),
        WordOfTheDayEntry(
            word: "Triangulate",
            partOfSpeech: "verb",
            definition: "To check a claim against several independent sources.",
            promptSuggestion: "How do you triangulate when one expert tells you one thing?",
            forms: ["triangulated", "triangulates", "triangulating"]
        ),
        WordOfTheDayEntry(
            word: "Reconcile",
            partOfSpeech: "verb",
            definition: "To bring two opposing things into a livable peace.",
            promptSuggestion: "What is something you've reconciled in yourself recently?",
            forms: ["reconciled", "reconciles", "reconciling", "reconciliation"]
        ),
        WordOfTheDayEntry(
            word: "Probe",
            partOfSpeech: "verb",
            definition: "To ask a careful question to reach what's underneath.",
            promptSuggestion: "What is one assumption you've recently probed and found shaky?",
            forms: ["probed", "probes", "probing"]
        ),
        WordOfTheDayEntry(
            word: "Qualify",
            partOfSpeech: "verb",
            definition: "To add the boundary that makes a claim accurate.",
            promptSuggestion: "Where in your speech could a small qualifier sharpen the whole point?",
            forms: ["qualified", "qualifies", "qualifying"]
        ),

        // MARK: Character

        WordOfTheDayEntry(
            word: "Integrity",
            partOfSpeech: "noun",
            definition: "The match between what someone says and what they then do.",
            promptSuggestion: "Whose integrity have you watched carry them through a hard year?"
        ),
        WordOfTheDayEntry(
            word: "Steadfast",
            partOfSpeech: "adjective",
            definition: "Holding the line over a long stretch of doubt.",
            promptSuggestion: "What commitment have you held steadfast even when it cost you?",
            forms: ["steadfastly", "steadfastness"]
        ),
        WordOfTheDayEntry(
            word: "Principled",
            partOfSpeech: "adjective",
            definition: "Acting from rules you'd defend even when they don't pay.",
            promptSuggestion: "What is one principled stance you've taken that was expensive?",
            forms: ["principle", "principles"]
        ),
        WordOfTheDayEntry(
            word: "Accountable",
            partOfSpeech: "adjective",
            definition: "Willing to own an outcome you helped shape.",
            promptSuggestion: "Where could you be more accountable for something you helped create?",
            forms: ["accountability", "accountably"]
        ),
        WordOfTheDayEntry(
            word: "Conscientious",
            partOfSpeech: "adjective",
            definition: "Doing the careful version of a thing nobody is checking.",
            promptSuggestion: "What is the most conscientious habit you keep when nobody's watching?",
            forms: ["conscientiously"]
        ),
        WordOfTheDayEntry(
            word: "Resolute",
            partOfSpeech: "adjective",
            definition: "Decided, with the doubt already worked through.",
            promptSuggestion: "Where are you resolute right now, and where are you still wavering?",
            forms: ["resolutely", "resoluteness"]
        ),
        WordOfTheDayEntry(
            word: "Forthright",
            partOfSpeech: "adjective",
            definition: "Honest in a way that doesn't hide behind softness.",
            promptSuggestion: "Whose forthright voice would you most miss if it went quiet?",
            forms: ["forthrightly"]
        ),
        WordOfTheDayEntry(
            word: "Tenacious",
            partOfSpeech: "adjective",
            definition: "Refusing to let go of a goal that keeps slipping.",
            promptSuggestion: "What goal have you been tenacious about that surprised even you?",
            forms: ["tenaciously"]
        ),
        WordOfTheDayEntry(
            word: "Disciplined",
            partOfSpeech: "adjective",
            definition: "Holding a structure that lets the work happen.",
            promptSuggestion: "What is one disciplined habit that has compounded for you?",
            forms: ["discipline", "disciplines", "disciplining"]
        ),
        WordOfTheDayEntry(
            word: "Dependable",
            partOfSpeech: "adjective",
            definition: "Someone whose word reliably matches their week.",
            promptSuggestion: "Who is the most dependable person in your circle, and what makes them so?",
            forms: ["dependably", "dependability"]
        ),

        // MARK: Mind-state

        WordOfTheDayEntry(
            word: "Present",
            partOfSpeech: "adjective",
            definition: "Fully here in the conversation rather than elsewhere.",
            promptSuggestion: "Where do you most struggle to stay present, and what pulls you out?",
            forms: ["presence", "presently"]
        ),
        WordOfTheDayEntry(
            word: "Attuned",
            partOfSpeech: "adjective",
            definition: "Picking up small signals others miss in a room.",
            promptSuggestion: "Who in your life is most attuned to what you're not saying?",
            forms: ["attune", "attunes", "attuning", "attunement"]
        ),
        WordOfTheDayEntry(
            word: "Centred",
            partOfSpeech: "adjective",
            definition: "Settled in oneself even when the surroundings churn.",
            promptSuggestion: "What practice keeps you centred when the day starts to tilt?",
            forms: ["center", "centered", "centering", "centring"]
        ),
        WordOfTheDayEntry(
            word: "Grounded",
            partOfSpeech: "adjective",
            definition: "Connected to the ordinary fact of where you are.",
            promptSuggestion: "What grounds you on a day when nothing else is sure?",
            forms: ["ground", "grounds", "grounding"]
        ),
        WordOfTheDayEntry(
            word: "Alert",
            partOfSpeech: "adjective",
            definition: "Awake to what's about to change, without flinching at it.",
            promptSuggestion: "When did you last feel fully alert in a conversation that mattered?",
            forms: ["alerts", "alerted", "alerting", "alertness"]
        ),
        WordOfTheDayEntry(
            word: "Sober",
            partOfSpeech: "adjective",
            definition: "Clear-eyed about the actual stakes, no inflation.",
            promptSuggestion: "What is one truth you've grown sober about in the last year?",
            forms: ["soberly", "sobered", "sobers", "sobering"]
        ),
        WordOfTheDayEntry(
            word: "Receptive",
            partOfSpeech: "adjective",
            definition: "Open to information that contradicts what you'd hoped.",
            promptSuggestion: "Where are you most receptive to feedback, and where are you not?",
            forms: ["receptively", "receptivity"]
        ),
        WordOfTheDayEntry(
            word: "Patient",
            partOfSpeech: "adjective",
            definition: "Willing to let the right answer take its time.",
            promptSuggestion: "Where in your work have you had to be patient longer than you wanted?",
            forms: ["patiently", "patience"]
        ),
        WordOfTheDayEntry(
            word: "Measured",
            partOfSpeech: "adjective",
            definition: "Considered, never rushed by the room's tempo.",
            promptSuggestion: "Whose measured tone do you trust most when the stakes are real?",
            forms: ["measure", "measures", "measuring"]
        ),
        WordOfTheDayEntry(
            word: "Settled",
            partOfSpeech: "adjective",
            definition: "Inside oneself with the hum turned down.",
            promptSuggestion: "What does it take for you to feel settled before a hard conversation?",
            forms: ["settle", "settles", "settling"]
        ),

        // MARK: Communication moves

        WordOfTheDayEntry(
            word: "Surface",
            partOfSpeech: "verb",
            definition: "To bring something underneath into open view.",
            promptSuggestion: "What is one thing worth surfacing in a conversation you've avoided?",
            forms: ["surfaced", "surfaces", "surfacing"]
        ),
        WordOfTheDayEntry(
            word: "Name",
            partOfSpeech: "verb",
            definition: "To say the exact thing rather than circle around it.",
            promptSuggestion: "What feeling has been hardest for you to name out loud lately?",
            forms: ["named", "names", "naming"]
        ),
        WordOfTheDayEntry(
            word: "Acknowledge",
            partOfSpeech: "verb",
            definition: "To say out loud that you've noticed something.",
            promptSuggestion: "Whose effort have you been meaning to acknowledge but haven't?",
            forms: ["acknowledged", "acknowledges", "acknowledging", "acknowledgement", "acknowledgment"]
        ),
        WordOfTheDayEntry(
            word: "Concede",
            partOfSpeech: "verb",
            definition: "To grant a point that the other side has actually won.",
            promptSuggestion: "When did you last concede a point and feel stronger for it?",
            forms: ["conceded", "concedes", "conceding", "concession"]
        ),
        WordOfTheDayEntry(
            word: "Echo",
            partOfSpeech: "verb",
            definition: "To repeat back what was said so the speaker knows you heard.",
            promptSuggestion: "Whose words have you found yourself echoing without meaning to?",
            forms: ["echoed", "echoes", "echoing"]
        ),
        WordOfTheDayEntry(
            word: "Mirror",
            partOfSpeech: "verb",
            definition: "To match someone's tempo so they feel met.",
            promptSuggestion: "When does mirroring help a conversation, and when is it just performance?",
            forms: ["mirrored", "mirrors", "mirroring"]
        ),
        WordOfTheDayEntry(
            word: "Bridge",
            partOfSpeech: "verb",
            definition: "To connect two sides that are talking past each other.",
            promptSuggestion: "Where in your work do you bridge two camps that don't share language?",
            forms: ["bridged", "bridges", "bridging"]
        ),
        WordOfTheDayEntry(
            word: "Underscore",
            partOfSpeech: "verb",
            definition: "To put extra weight under a point that matters most.",
            promptSuggestion: "What is one belief you've found yourself underscoring more lately?",
            forms: ["underscored", "underscores", "underscoring"]
        ),
        WordOfTheDayEntry(
            word: "Signal",
            partOfSpeech: "verb",
            definition: "To show, before saying, what's about to come.",
            promptSuggestion: "How do you signal to a room that the next thing you say matters?",
            forms: ["signalled", "signaled", "signals", "signalling", "signaling"]
        ),
        WordOfTheDayEntry(
            word: "Defer",
            partOfSpeech: "verb",
            definition: "To let someone else's judgement carry the moment.",
            promptSuggestion: "Whose judgement do you defer to often, and what have they earned that with?",
            forms: ["deferred", "defers", "deferring", "deference"]
        ),

        // MARK: Ideas and argument

        WordOfTheDayEntry(
            word: "Premise",
            partOfSpeech: "noun",
            definition: "The base assumption a whole argument rests on.",
            promptSuggestion: "What is one premise you'd defend if pushed, and one you wouldn't?",
            forms: ["premises", "premised"]
        ),
        WordOfTheDayEntry(
            word: "Tenet",
            partOfSpeech: "noun",
            definition: "A core belief held closely enough to act from.",
            promptSuggestion: "What is a tenet you'd keep even if everyone around you dropped it?",
            forms: ["tenets"]
        ),
        WordOfTheDayEntry(
            word: "Thesis",
            partOfSpeech: "noun",
            definition: "The one claim a longer piece of thinking serves.",
            promptSuggestion: "If your week were an essay, what would the thesis be?",
            forms: ["theses"]
        ),
        WordOfTheDayEntry(
            word: "Hypothesis",
            partOfSpeech: "noun",
            definition: "A claim worth testing before treating as true.",
            promptSuggestion: "What is a quiet hypothesis about yourself you've been testing this year?",
            forms: ["hypotheses", "hypothesise", "hypothesize"]
        ),
        WordOfTheDayEntry(
            word: "Proposition",
            partOfSpeech: "noun",
            definition: "A statement put forward to be agreed to or argued with.",
            promptSuggestion: "What is one proposition you find harder to defend than it seemed at first?",
            forms: ["propositions"]
        ),
        WordOfTheDayEntry(
            word: "Caveat",
            partOfSpeech: "noun",
            definition: "A small reservation that keeps a claim honest.",
            promptSuggestion: "What caveat would you add to advice you've given a lot lately?",
            forms: ["caveats"]
        ),
        WordOfTheDayEntry(
            word: "Inference",
            partOfSpeech: "noun",
            definition: "What you reasoned to, but didn't see directly.",
            promptSuggestion: "What is an inference you made recently that turned out wrong?",
            forms: ["inferences", "infer", "inferred", "infers", "inferring"]
        ),
        WordOfTheDayEntry(
            word: "Stance",
            partOfSpeech: "noun",
            definition: "The position you'd defend if asked where you stand.",
            promptSuggestion: "What is one stance you've revised in the last year, and why?",
            forms: ["stances"]
        ),
        WordOfTheDayEntry(
            word: "Counterpoint",
            partOfSpeech: "noun",
            definition: "A view that pushes back without dismissing the first.",
            promptSuggestion: "What is a useful counterpoint to a strong belief of yours?",
            forms: ["counterpoints"]
        ),
        WordOfTheDayEntry(
            word: "Nuance",
            partOfSpeech: "noun",
            definition: "The fine grain that crude statements miss.",
            promptSuggestion: "Where do you most need to bring nuance into how you say something?",
            forms: ["nuanced", "nuances"]
        ),

        // MARK: Action

        WordOfTheDayEntry(
            word: "Undertake",
            partOfSpeech: "verb",
            definition: "To take on something significant by choice.",
            promptSuggestion: "What is one thing you've undertaken this year that surprised you?",
            forms: ["undertook", "undertakes", "undertaking", "undertaken"]
        ),
        WordOfTheDayEntry(
            word: "Embark",
            partOfSpeech: "verb",
            definition: "To begin a long thing with both feet committed.",
            promptSuggestion: "What is one project you're about to embark on, and what scares you about it?",
            forms: ["embarked", "embarks", "embarking"]
        ),
        WordOfTheDayEntry(
            word: "Commit",
            partOfSpeech: "verb",
            definition: "To choose, then refuse to keep choosing.",
            promptSuggestion: "Where in your week could you commit more cleanly and circle less?",
            forms: ["committed", "commits", "committing", "commitment"]
        ),
        WordOfTheDayEntry(
            word: "Mobilise",
            partOfSpeech: "verb",
            definition: "To get people moving toward the same thing.",
            promptSuggestion: "Who do you mobilise best — strangers, friends, or yourself?",
            forms: ["mobilize", "mobilised", "mobilized", "mobilises", "mobilizes", "mobilising", "mobilizing"]
        ),
        WordOfTheDayEntry(
            word: "Initiate",
            partOfSpeech: "verb",
            definition: "To start a thing rather than wait to be invited.",
            promptSuggestion: "What is one conversation you should initiate this week?",
            forms: ["initiated", "initiates", "initiating", "initiation"]
        ),
        WordOfTheDayEntry(
            word: "Spearhead",
            partOfSpeech: "verb",
            definition: "To lead an effort from the visible front.",
            promptSuggestion: "What is one effort you'd spearhead if you weren't waiting for permission?",
            forms: ["spearheaded", "spearheads", "spearheading"]
        ),
        WordOfTheDayEntry(
            word: "Champion",
            partOfSpeech: "verb",
            definition: "To carry a person or idea forward when nobody else will.",
            promptSuggestion: "Whose idea would you champion right now if asked?",
            forms: ["championed", "champions", "championing"]
        ),
        WordOfTheDayEntry(
            word: "Steer",
            partOfSpeech: "verb",
            definition: "To guide direction without grabbing the wheel.",
            promptSuggestion: "Where do you steer your team rather than tell them where to go?",
            forms: ["steered", "steers", "steering"]
        ),
        WordOfTheDayEntry(
            word: "Pursue",
            partOfSpeech: "verb",
            definition: "To keep moving toward something even when it pulls away.",
            promptSuggestion: "What is one thing you've pursued long past easy, and was it worth it?",
            forms: ["pursued", "pursues", "pursuing", "pursuit"]
        ),
        WordOfTheDayEntry(
            word: "Volunteer",
            partOfSpeech: "verb",
            definition: "To raise your hand before someone has to ask.",
            promptSuggestion: "Where in your work have you been quietly volunteering more lately?",
            forms: ["volunteered", "volunteers", "volunteering"]
        ),

        // MARK: Craft and refinement

        WordOfTheDayEntry(
            word: "Refine",
            partOfSpeech: "verb",
            definition: "To take something nearly finished and make it cleaner.",
            promptSuggestion: "What is one piece of yours you've refined a hundred times already?",
            forms: ["refined", "refines", "refining", "refinement"]
        ),
        WordOfTheDayEntry(
            word: "Sculpt",
            partOfSpeech: "verb",
            definition: "To shape with patient, repeated subtraction.",
            promptSuggestion: "What in your craft are you sculpting one revision at a time?",
            forms: ["sculpted", "sculpts", "sculpting"]
        ),
        WordOfTheDayEntry(
            word: "Render",
            partOfSpeech: "verb",
            definition: "To make a final, presentable version of something.",
            promptSuggestion: "What idea have you rendered so many times the words feel automatic?",
            forms: ["rendered", "renders", "rendering"]
        ),
        WordOfTheDayEntry(
            word: "Draft",
            partOfSpeech: "verb",
            definition: "To put down a first version meant to be cut later.",
            promptSuggestion: "What are you drafting in your head that you haven't put on paper?",
            forms: ["drafted", "drafts", "drafting"]
        ),
        WordOfTheDayEntry(
            word: "Shape",
            partOfSpeech: "verb",
            definition: "To give a rough thing the form it wants.",
            promptSuggestion: "What is one habit you've spent years shaping into something quieter?",
            forms: ["shaped", "shapes", "shaping"]
        ),
        WordOfTheDayEntry(
            word: "Polish",
            partOfSpeech: "verb",
            definition: "To make a working thing visibly cared for.",
            promptSuggestion: "What in your daily work could use a small polish, not a rewrite?",
            forms: ["polished", "polishes", "polishing"]
        ),
        WordOfTheDayEntry(
            word: "Temper",
            partOfSpeech: "verb",
            definition: "To make stronger by exposing to controlled stress.",
            promptSuggestion: "What part of you has been tempered by something you didn't choose?",
            forms: ["tempered", "tempers", "tempering"]
        ),
        WordOfTheDayEntry(
            word: "Frame",
            partOfSpeech: "verb",
            definition: "To choose the angle a listener will receive a thing through.",
            promptSuggestion: "How do you frame a hard message so it's heard, not absorbed?",
            forms: ["framed", "frames", "framing"]
        ),
        WordOfTheDayEntry(
            word: "Workshop",
            partOfSpeech: "verb",
            definition: "To rehearse an idea in front of trusted ears.",
            promptSuggestion: "Whose ears would you most trust to workshop something half-finished with?",
            forms: ["workshopped", "workshops", "workshopping"]
        ),
        WordOfTheDayEntry(
            word: "Build",
            partOfSpeech: "verb",
            definition: "To assemble something useful over more than one day.",
            promptSuggestion: "What are you building right now that nobody else is watching yet?",
            forms: ["built", "builds", "building"]
        ),

        // MARK: Reflection

        WordOfTheDayEntry(
            word: "Ponder",
            partOfSpeech: "verb",
            definition: "To turn a thought over slowly with no rush to land.",
            promptSuggestion: "What are you pondering this week that resists being answered quickly?",
            forms: ["pondered", "ponders", "pondering"]
        ),
        WordOfTheDayEntry(
            word: "Contemplate",
            partOfSpeech: "verb",
            definition: "To sit with something long enough to see new edges.",
            promptSuggestion: "What is one question you've been contemplating for more than a month?",
            forms: ["contemplated", "contemplates", "contemplating", "contemplation"]
        ),
        WordOfTheDayEntry(
            word: "Reflect",
            partOfSpeech: "verb",
            definition: "To look back honestly and let the look change you.",
            promptSuggestion: "When was the last time you reflected on a week and changed something?",
            forms: ["reflected", "reflects", "reflecting", "reflection"]
        ),
        WordOfTheDayEntry(
            word: "Mull",
            partOfSpeech: "verb",
            definition: "To turn an idea over slowly while doing other things.",
            promptSuggestion: "What has been mulling in the back of your mind that you haven't named?",
            forms: ["mulled", "mulls", "mulling"]
        ),
        WordOfTheDayEntry(
            word: "Examine",
            partOfSpeech: "verb",
            definition: "To look at something carefully enough to see what's there.",
            promptSuggestion: "What belief of yours could stand a careful examination this month?",
            forms: ["examined", "examines", "examining", "examination"]
        ),
        WordOfTheDayEntry(
            word: "Process",
            partOfSpeech: "verb",
            definition: "To work feelings through until they sit differently.",
            promptSuggestion: "What are you processing right now that needs more time than it's getting?",
            forms: ["processed", "processes", "processing"]
        ),
        WordOfTheDayEntry(
            word: "Consider",
            partOfSpeech: "verb",
            definition: "To weigh a thing before taking a position on it.",
            promptSuggestion: "What is one position you've considered and then refused?",
            forms: ["considered", "considers", "considering", "consideration"]
        ),
        WordOfTheDayEntry(
            word: "Survey",
            partOfSpeech: "verb",
            definition: "To take in a wider view before deciding the next move.",
            promptSuggestion: "When was the last time you surveyed your life rather than worked inside it?",
            forms: ["surveyed", "surveys", "surveying"]
        ),
        WordOfTheDayEntry(
            word: "Revisit",
            partOfSpeech: "verb",
            definition: "To return to a thought you'd closed and open it again.",
            promptSuggestion: "What is one belief you've revisited this year that didn't survive?",
            forms: ["revisited", "revisits", "revisiting"]
        ),
        WordOfTheDayEntry(
            word: "Recollect",
            partOfSpeech: "verb",
            definition: "To pull a memory back into useful focus.",
            promptSuggestion: "What moment do you recollect when you need to remember why you started?",
            forms: ["recollected", "recollects", "recollecting", "recollection"]
        ),

        // MARK: Strength

        WordOfTheDayEntry(
            word: "Fortitude",
            partOfSpeech: "noun",
            definition: "Strength of mind under sustained pressure.",
            promptSuggestion: "Whose fortitude have you watched up close that you can't unsee?"
        ),
        WordOfTheDayEntry(
            word: "Mettle",
            partOfSpeech: "noun",
            definition: "What you're made of when something tests you.",
            promptSuggestion: "When did something recently test your mettle, and how did you find it?"
        ),
        WordOfTheDayEntry(
            word: "Grit",
            partOfSpeech: "noun",
            definition: "Stubborn effort applied past the point of comfort.",
            promptSuggestion: "Where in your life has grit mattered more than talent so far?",
            forms: ["gritty"]
        ),
        WordOfTheDayEntry(
            word: "Backbone",
            partOfSpeech: "noun",
            definition: "The willingness to hold a hard line in a hard room.",
            promptSuggestion: "When have you needed backbone in a conversation that wasn't expecting it?",
            forms: ["backbones"]
        ),
        WordOfTheDayEntry(
            word: "Resolve",
            partOfSpeech: "noun",
            definition: "A settled decision that pressure doesn't move.",
            promptSuggestion: "What is a recent resolve of yours that surprised even you?",
            forms: ["resolved", "resolves", "resolving", "resolution"]
        ),
        WordOfTheDayEntry(
            word: "Tenacity",
            partOfSpeech: "noun",
            definition: "Long-distance refusal to let go of a goal.",
            promptSuggestion: "Where does your tenacity come from when the work stops feeling rewarded?"
        ),
        WordOfTheDayEntry(
            word: "Steel",
            partOfSpeech: "verb",
            definition: "To prepare yourself for something difficult.",
            promptSuggestion: "How do you steel yourself before walking into a hard conversation?",
            forms: ["steeled", "steels", "steeling"]
        ),
        WordOfTheDayEntry(
            word: "Brace",
            partOfSpeech: "verb",
            definition: "To set yourself before impact rather than after.",
            promptSuggestion: "What did you brace for recently that arrived smaller than feared?",
            forms: ["braced", "braces", "bracing"]
        ),
        WordOfTheDayEntry(
            word: "Endure",
            partOfSpeech: "verb",
            definition: "To stay inside something hard until it eases.",
            promptSuggestion: "What is one thing you've endured that you'd now do differently?",
            forms: ["endured", "endures", "enduring", "endurance"]
        ),
        WordOfTheDayEntry(
            word: "Persist",
            partOfSpeech: "verb",
            definition: "To keep showing up after the novelty has worn off.",
            promptSuggestion: "What habit have you persisted with longer than you thought you would?",
            forms: ["persisted", "persists", "persisting", "persistence", "persistent"]
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
