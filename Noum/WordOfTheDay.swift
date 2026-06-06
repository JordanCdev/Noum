import Foundation

// MARK: - Word of the Day (M9)
//
// One curated word per day. Each entry carries:
//   • word — the headword the user is asked to use.
//   • partOfSpeech — short label ("noun", "verb", "adjective").
//   • definition — concise gloss (≤ 90 chars).
//   • promptSuggestion — a 30s speaking prompt that never contains the
//     target word; the word itself stays a separate intentional cue.
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
        promptSuggestion: String? = nil,
        forms: [String] = []
    ) {
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        var combined = [word.lowercased()]
        combined.append(contentsOf: forms.map { $0.lowercased() })
        let acceptedForms = Array(Set(combined))
        self.acceptedForms = acceptedForms

        let proposedPrompt = promptSuggestion ?? Self.defaultPrompt(for: partOfSpeech)
        self.promptSuggestion = Self.containsAcceptedForm(in: proposedPrompt, acceptedForms: acceptedForms)
            ? Self.defaultPrompt(for: partOfSpeech)
            : proposedPrompt
    }

    private static func defaultPrompt(for partOfSpeech: String) -> String {
        switch partOfSpeech.lowercased() {
        case "verb":
            return "Describe a recent exchange where one choice changed the outcome?"
        case "adjective":
            return "Describe a recent moment where the room's mood changed what people heard?"
        default:
            return "Describe a recent conversation through one clear idea, then make it concrete?"
        }
    }

    private static func containsAcceptedForm(in prompt: String, acceptedForms: [String]) -> Bool {
        let lowercasedPrompt = prompt.lowercased()
        return acceptedForms.contains { form in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: form.lowercased()))\\b"
            return lowercasedPrompt.range(of: pattern, options: .regularExpression) != nil
        }
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
            forms: ["pivots", "pivoted", "pivoting"]
        ),
        WordOfTheDayEntry(
            word: "Resonant",
            partOfSpeech: "adjective",
            definition: "Producing a strong, lingering effect — emotionally or sonically.",
            forms: ["resonance", "resonate", "resonates", "resonated"]
        ),
        WordOfTheDayEntry(
            word: "Galvanise",
            partOfSpeech: "verb",
            definition: "To shock or excite into sudden action.",
            forms: ["galvanize", "galvanises", "galvanized", "galvanising"]
        ),
        WordOfTheDayEntry(
            word: "Tangible",
            partOfSpeech: "adjective",
            definition: "Concrete and measurable; able to be touched or counted.",
            forms: ["tangibly", "tangibility"]
        ),
        WordOfTheDayEntry(
            word: "Distill",
            partOfSpeech: "verb",
            definition: "To extract the essential meaning or substance from something.",
            forms: ["distil", "distills", "distilled", "distilling"]
        ),
        WordOfTheDayEntry(
            word: "Deliberate",
            partOfSpeech: "adjective",
            definition: "Done on purpose, with care and intention.",
            forms: ["deliberately", "deliberation"]
        ),
        WordOfTheDayEntry(
            word: "Catalyst",
            partOfSpeech: "noun",
            definition: "Something that accelerates change without being consumed by it.",
            forms: ["catalysts", "catalytic", "catalyse", "catalyze"]
        ),
        WordOfTheDayEntry(
            word: "Compose",
            partOfSpeech: "verb",
            definition: "To put together with care; to settle one's manner.",
            forms: ["composed", "composes", "composure", "composing"]
        ),
        WordOfTheDayEntry(
            word: "Concise",
            partOfSpeech: "adjective",
            definition: "Brief and to the point; no extra words.",
            forms: ["concisely", "conciseness"]
        ),
        WordOfTheDayEntry(
            word: "Kindle",
            partOfSpeech: "verb",
            definition: "To start something burning; to spark interest.",
            forms: ["kindled", "kindles", "kindling"]
        ),
        WordOfTheDayEntry(
            word: "Lucid",
            partOfSpeech: "adjective",
            definition: "Clear, easy to understand, free from haze.",
            forms: ["lucidly", "lucidity"]
        ),
        WordOfTheDayEntry(
            word: "Reframe",
            partOfSpeech: "verb",
            definition: "To put something in a different perspective or framing.",
            forms: ["reframed", "reframes", "reframing"]
        ),
        WordOfTheDayEntry(
            word: "Salient",
            partOfSpeech: "adjective",
            definition: "Most noticeable; the part that stands out.",
            forms: ["salience", "saliently"]
        ),
        WordOfTheDayEntry(
            word: "Composure",
            partOfSpeech: "noun",
            definition: "Calmness of manner under pressure.",
            forms: ["composed", "composing"]
        ),
        WordOfTheDayEntry(
            word: "Pragmatic",
            partOfSpeech: "adjective",
            definition: "Focused on what works, not on what should work in theory.",
            forms: ["pragmatically", "pragmatism"]
        ),
        WordOfTheDayEntry(
            word: "Anchor",
            partOfSpeech: "noun",
            definition: "Something that holds you steady when everything else moves.",
            forms: ["anchors", "anchored", "anchoring"]
        ),
        WordOfTheDayEntry(
            word: "Iterate",
            partOfSpeech: "verb",
            definition: "To repeat with small improvements each time.",
            forms: ["iterated", "iterates", "iterating", "iteration", "iterative"]
        ),
        WordOfTheDayEntry(
            word: "Candour",
            partOfSpeech: "noun",
            definition: "Honesty delivered without varnish.",
            forms: ["candor", "candid", "candidly"]
        ),
        WordOfTheDayEntry(
            word: "Gravity",
            partOfSpeech: "noun",
            definition: "Weight of meaning or seriousness.",
            forms: ["grave", "gravely"]
        ),
        WordOfTheDayEntry(
            word: "Hone",
            partOfSpeech: "verb",
            definition: "To sharpen a skill or focus by repeated effort.",
            forms: ["honed", "hones", "honing"]
        ),
        WordOfTheDayEntry(
            word: "Sustain",
            partOfSpeech: "verb",
            definition: "To keep something going over time.",
            forms: ["sustained", "sustains", "sustaining", "sustainable"]
        ),
        WordOfTheDayEntry(
            word: "Curate",
            partOfSpeech: "verb",
            definition: "To select carefully from a wider set.",
            forms: ["curated", "curates", "curating", "curation"]
        ),
        WordOfTheDayEntry(
            word: "Resilience",
            partOfSpeech: "noun",
            definition: "The ability to recover quickly from setbacks.",
            forms: ["resilient", "resiliently"]
        ),
        WordOfTheDayEntry(
            word: "Inflect",
            partOfSpeech: "verb",
            definition: "To change tone or direction subtly.",
            forms: ["inflected", "inflects", "inflection", "inflecting"]
        ),
        WordOfTheDayEntry(
            word: "Earnest",
            partOfSpeech: "adjective",
            definition: "Sincere and serious in intention or feeling.",
            forms: ["earnestly", "earnestness"]
        ),
        WordOfTheDayEntry(
            word: "Threshold",
            partOfSpeech: "noun",
            definition: "The point at which something starts; a boundary.",
            forms: ["thresholds"]
        ),
        WordOfTheDayEntry(
            word: "Ambient",
            partOfSpeech: "adjective",
            definition: "Surrounding; existing in the background of a scene.",
            forms: ["ambience", "ambiently"]
        ),
        WordOfTheDayEntry(
            word: "Posture",
            partOfSpeech: "noun",
            definition: "A position or attitude held over time.",
            forms: ["posturing", "postures", "postured"]
        ),
        WordOfTheDayEntry(
            word: "Forge",
            partOfSpeech: "verb",
            definition: "To make or shape with sustained effort.",
            forms: ["forged", "forges", "forging"]
        ),
        WordOfTheDayEntry(
            word: "Texture",
            partOfSpeech: "noun",
            definition: "The grain or feel of something — surface or speech.",
            forms: ["textures", "textured"]
        ),
        WordOfTheDayEntry(
            word: "Vivid",
            partOfSpeech: "adjective",
            definition: "Sharp and lifelike; producing strong mental images.",
            forms: ["vividly", "vividness"]
        ),
        WordOfTheDayEntry(
            word: "Glean",
            partOfSpeech: "verb",
            definition: "To gather small bits of information patiently.",
            forms: ["gleaned", "gleans", "gleaning"]
        ),
        WordOfTheDayEntry(
            word: "Parry",
            partOfSpeech: "verb",
            definition: "To turn aside a question or attack with a measured response.",
            forms: ["parried", "parries", "parrying"]
        ),
        WordOfTheDayEntry(
            word: "Hedge",
            partOfSpeech: "verb",
            definition: "To soften a claim by leaving yourself an out.",
            forms: ["hedged", "hedges", "hedging"]
        ),
        WordOfTheDayEntry(
            word: "Brisk",
            partOfSpeech: "adjective",
            definition: "Quick and energetic; efficient without rushing.",
            forms: ["briskly", "briskness"]
        ),
        WordOfTheDayEntry(
            word: "Taut",
            partOfSpeech: "adjective",
            definition: "Pulled tight; lean with no slack.",
            forms: ["tautly", "tautness"]
        ),
        WordOfTheDayEntry(
            word: "Succinct",
            partOfSpeech: "adjective",
            definition: "Said in the fewest words that still carry the meaning.",
            forms: ["succinctly", "succinctness"]
        ),
        WordOfTheDayEntry(
            word: "Frank",
            partOfSpeech: "adjective",
            definition: "Open and direct in a way that costs nothing to say.",
            forms: ["frankly", "frankness"]
        ),
        WordOfTheDayEntry(
            word: "Steady",
            partOfSpeech: "adjective",
            definition: "Consistent in pace or manner; unshaken.",
            forms: ["steadily", "steadiness", "steadied"]
        ),
        WordOfTheDayEntry(
            word: "Grounded",
            partOfSpeech: "adjective",
            definition: "Connected to what's real and present; not flighty.",
            forms: ["ground", "grounding", "grounds"]
        ),
        WordOfTheDayEntry(
            word: "Brittle",
            partOfSpeech: "adjective",
            definition: "Hard but prone to snapping under pressure.",
            forms: ["brittleness", "brittly"]
        ),
        WordOfTheDayEntry(
            word: "Supple",
            partOfSpeech: "adjective",
            definition: "Flexible and responsive; bending without breaking.",
            forms: ["suppleness", "supply"]
        ),
        WordOfTheDayEntry(
            word: "Unvarnished",
            partOfSpeech: "adjective",
            definition: "Without polish or softening — plain and clear.",
            forms: ["unvarnish"]
        ),
        WordOfTheDayEntry(
            word: "Patient",
            partOfSpeech: "adjective",
            definition: "Willing to wait without losing steadiness.",
            forms: ["patiently", "patience"]
        ),
        WordOfTheDayEntry(
            word: "Generous",
            partOfSpeech: "adjective",
            definition: "Giving more than what's strictly required.",
            forms: ["generously", "generosity"]
        ),
        WordOfTheDayEntry(
            word: "Curious",
            partOfSpeech: "adjective",
            definition: "Drawn toward what you don't yet understand.",
            forms: ["curiously", "curiosity"]
        ),
        WordOfTheDayEntry(
            word: "Understated",
            partOfSpeech: "adjective",
            definition: "Said with less emphasis than the moment would allow, on purpose.",
            forms: ["understatement", "understate"]
        ),
        WordOfTheDayEntry(
            word: "Direct",
            partOfSpeech: "adjective",
            definition: "Aimed straight at the thing without detour.",
            forms: ["directly", "directness", "directed"]
        ),
        WordOfTheDayEntry(
            word: "Specific",
            partOfSpeech: "adjective",
            definition: "Pointed at the particular rather than the general.",
            forms: ["specifically", "specificity"]
        ),
        WordOfTheDayEntry(
            word: "Forthcoming",
            partOfSpeech: "adjective",
            definition: "Willing to share what someone needs to know without being asked twice.",
            forms: ["forthcomingly"]
        ),
        WordOfTheDayEntry(
            word: "Measured",
            partOfSpeech: "adjective",
            definition: "Spoken or done with weight and restraint.",
            forms: ["measure", "measuring", "measures"]
        ),
        WordOfTheDayEntry(
            word: "Crisp",
            partOfSpeech: "adjective",
            definition: "Clean and sharp at the edges; no soggy middle.",
            forms: ["crisply", "crispness"]
        ),
        WordOfTheDayEntry(
            word: "Sharp",
            partOfSpeech: "adjective",
            definition: "Precise and alert; able to cut to the point.",
            forms: ["sharply", "sharpness", "sharpen", "sharpened"]
        ),
        WordOfTheDayEntry(
            word: "Frame",
            partOfSpeech: "verb",
            definition: "To set the context that shapes how something lands.",
            forms: ["framed", "frames", "framing"]
        ),
        WordOfTheDayEntry(
            word: "Bridge",
            partOfSpeech: "verb",
            definition: "To connect two points or positions that don't meet on their own.",
            forms: ["bridged", "bridges", "bridging"]
        ),
        WordOfTheDayEntry(
            word: "Surface",
            partOfSpeech: "verb",
            definition: "To bring something hidden into view.",
            forms: ["surfaced", "surfaces", "surfacing"]
        ),
        WordOfTheDayEntry(
            word: "Land",
            partOfSpeech: "verb",
            definition: "To arrive in a way the listener actually feels.",
            forms: ["landed", "lands", "landing"]
        ),
        WordOfTheDayEntry(
            word: "Carry",
            partOfSpeech: "verb",
            definition: "To hold and convey something with weight.",
            forms: ["carried", "carries", "carrying"]
        ),
        WordOfTheDayEntry(
            word: "Dwell",
            partOfSpeech: "verb",
            definition: "To stay with a thought longer than it's comfortable to.",
            forms: ["dwelled", "dwelt", "dwells", "dwelling"]
        ),
        WordOfTheDayEntry(
            word: "Slow",
            partOfSpeech: "verb",
            definition: "To deliberately ease pace so meaning catches up.",
            forms: ["slowed", "slows", "slowing", "slowly"]
        ),
        WordOfTheDayEntry(
            word: "Soften",
            partOfSpeech: "verb",
            definition: "To take the hard edge off without losing the substance.",
            forms: ["softened", "softens", "softening"]
        ),
        WordOfTheDayEntry(
            word: "Sharpen",
            partOfSpeech: "verb",
            definition: "To make a point cleaner and harder to misread.",
            forms: ["sharpened", "sharpens", "sharpening"]
        ),
        WordOfTheDayEntry(
            word: "Tighten",
            partOfSpeech: "verb",
            definition: "To strip slack so what remains is load-bearing.",
            forms: ["tightened", "tightens", "tightening", "tight"]
        ),
        WordOfTheDayEntry(
            word: "Broach",
            partOfSpeech: "verb",
            definition: "To raise a difficult subject for the first time.",
            forms: ["broached", "broaches", "broaching"]
        ),
        WordOfTheDayEntry(
            word: "Adjourn",
            partOfSpeech: "verb",
            definition: "To bring something to a clean, agreed end before continuing later.",
            forms: ["adjourned", "adjourns", "adjourning"]
        ),
        WordOfTheDayEntry(
            word: "Probe",
            partOfSpeech: "verb",
            definition: "To ask carefully into something you don't yet understand.",
            forms: ["probed", "probes", "probing"]
        ),
        WordOfTheDayEntry(
            word: "Concede",
            partOfSpeech: "verb",
            definition: "To grant a point that goes against you because it's true.",
            forms: ["conceded", "concedes", "conceding", "concession"]
        ),
        WordOfTheDayEntry(
            word: "Defer",
            partOfSpeech: "verb",
            definition: "To yield to someone else's judgment without losing your own.",
            forms: ["deferred", "defers", "deferring", "deference"]
        ),
        WordOfTheDayEntry(
            word: "Resist",
            partOfSpeech: "verb",
            definition: "To hold against pressure without becoming hostile.",
            forms: ["resisted", "resists", "resisting", "resistance"]
        ),
        WordOfTheDayEntry(
            word: "Yield",
            partOfSpeech: "verb",
            definition: "To give ground deliberately so the right thing can happen.",
            forms: ["yielded", "yields", "yielding"]
        ),
        WordOfTheDayEntry(
            word: "Trace",
            partOfSpeech: "verb",
            definition: "To follow a thread back to its origin.",
            forms: ["traced", "traces", "tracing"]
        ),
        WordOfTheDayEntry(
            word: "Witness",
            partOfSpeech: "verb",
            definition: "To see something and let the other person know it was seen.",
            forms: ["witnessed", "witnesses", "witnessing"]
        ),
        WordOfTheDayEntry(
            word: "Name",
            partOfSpeech: "verb",
            definition: "To call something by what it actually is.",
            forms: ["named", "names", "naming"]
        ),
        WordOfTheDayEntry(
            word: "Notice",
            partOfSpeech: "verb",
            definition: "To take in something small enough to be easily missed.",
            forms: ["noticed", "notices", "noticing"]
        ),
        WordOfTheDayEntry(
            word: "Echo",
            partOfSpeech: "verb",
            definition: "To repeat back so the other person knows they were heard.",
            forms: ["echoed", "echoes", "echoing"]
        ),
        WordOfTheDayEntry(
            word: "Mirror",
            partOfSpeech: "verb",
            definition: "To reflect back what you're picking up so it can be confirmed.",
            forms: ["mirrored", "mirrors", "mirroring"]
        ),
        WordOfTheDayEntry(
            word: "Press",
            partOfSpeech: "verb",
            definition: "To push gently on a point that needs more weight.",
            forms: ["pressed", "presses", "pressing"]
        ),
        WordOfTheDayEntry(
            word: "Pause",
            partOfSpeech: "noun",
            definition: "A break in speech that lets meaning settle.",
            forms: ["paused", "pauses", "pausing"]
        ),
        WordOfTheDayEntry(
            word: "Cadence",
            partOfSpeech: "noun",
            definition: "The rhythm of how you speak — pace, beats, and rest.",
            forms: ["cadences"]
        ),
        WordOfTheDayEntry(
            word: "Tone",
            partOfSpeech: "noun",
            definition: "The colour your voice gives to what you say.",
            forms: ["tones", "toned"]
        ),
        WordOfTheDayEntry(
            word: "Stance",
            partOfSpeech: "noun",
            definition: "The position you're speaking from before you say a word.",
            forms: ["stances"]
        ),
        WordOfTheDayEntry(
            word: "Footing",
            partOfSpeech: "noun",
            definition: "The stability you start from in a charged conversation.",
            forms: ["footings"]
        ),
        WordOfTheDayEntry(
            word: "Margin",
            partOfSpeech: "noun",
            definition: "The room you keep around a decision or schedule.",
            forms: ["margins", "marginal"]
        ),
        WordOfTheDayEntry(
            word: "Signal",
            partOfSpeech: "noun",
            definition: "A small cue that carries meaningful information.",
            forms: ["signals", "signalled", "signaled", "signalling", "signaling"]
        ),
        WordOfTheDayEntry(
            word: "Subtext",
            partOfSpeech: "noun",
            definition: "What is meant without being said outright.",
            forms: ["subtexts", "subtextual"]
        ),
        WordOfTheDayEntry(
            word: "Tension",
            partOfSpeech: "noun",
            definition: "Pressure between two things pulling in different directions.",
            forms: ["tensions", "tense"]
        ),
        WordOfTheDayEntry(
            word: "Pattern",
            partOfSpeech: "noun",
            definition: "A repeated shape that appears once you look.",
            forms: ["patterns", "patterned"]
        ),
        WordOfTheDayEntry(
            word: "Habit",
            partOfSpeech: "noun",
            definition: "A behaviour you've practised into something automatic.",
            forms: ["habits", "habitual"]
        ),
        WordOfTheDayEntry(
            word: "Friction",
            partOfSpeech: "noun",
            definition: "Resistance in a process — sometimes helpful, often not.",
            forms: ["frictions", "frictional"]
        ),
        WordOfTheDayEntry(
            word: "Stakes",
            partOfSpeech: "noun",
            definition: "What is actually on the line in a moment.",
            forms: ["stake"]
        ),
        WordOfTheDayEntry(
            word: "Range",
            partOfSpeech: "noun",
            definition: "The span of registers or modes you can comfortably move across.",
            forms: ["ranges", "ranged", "ranging"]
        ),
        WordOfTheDayEntry(
            word: "Restraint",
            partOfSpeech: "noun",
            definition: "Deliberately holding back what doesn't need to be said.",
            forms: ["restraints", "restrained", "restraining"]
        ),
        WordOfTheDayEntry(
            word: "Discipline",
            partOfSpeech: "noun",
            definition: "Consistent practice when no one is watching.",
            forms: ["disciplines", "disciplined", "disciplining"]
        ),
        WordOfTheDayEntry(
            word: "Conviction",
            partOfSpeech: "noun",
            definition: "Belief firm enough to act from without overstating.",
            forms: ["convictions", "convinced"]
        ),
        WordOfTheDayEntry(
            word: "Reckon",
            partOfSpeech: "verb",
            definition: "To weigh something honestly before deciding.",
            forms: ["reckoned", "reckons", "reckoning"]
        ),
        WordOfTheDayEntry(
            word: "Settle",
            partOfSpeech: "verb",
            definition: "To come to rest in a position you can stand behind.",
            forms: ["settled", "settles", "settling"]
        ),
        WordOfTheDayEntry(
            word: "Anticipate",
            partOfSpeech: "verb",
            definition: "To prepare for what's likely without forcing it to happen.",
            forms: ["anticipated", "anticipates", "anticipating", "anticipation"]
        ),
        WordOfTheDayEntry(
            word: "Discern",
            partOfSpeech: "verb",
            definition: "To tell two close-looking things apart.",
            forms: ["discerned", "discerns", "discerning", "discernment"]
        ),
        WordOfTheDayEntry(
            word: "Reveal",
            partOfSpeech: "verb",
            definition: "To bring something true into the open.",
            forms: ["revealed", "reveals", "revealing"]
        ),
        WordOfTheDayEntry(
            word: "Defend",
            partOfSpeech: "verb",
            definition: "To stand behind a point when it's challenged.",
            forms: ["defended", "defends", "defending", "defence", "defense"]
        ),
        WordOfTheDayEntry(
            word: "Invite",
            partOfSpeech: "verb",
            definition: "To open space for the other person to step in.",
            forms: ["invited", "invites", "inviting"]
        ),
        WordOfTheDayEntry(
            word: "Affirm",
            partOfSpeech: "verb",
            definition: "To state something true with quiet weight.",
            forms: ["affirmed", "affirms", "affirming", "affirmation"]
        ),
        WordOfTheDayEntry(
            word: "Acknowledge",
            partOfSpeech: "verb",
            definition: "To say out loud what the other person is sensing.",
            forms: ["acknowledged", "acknowledges", "acknowledging"]
        ),
        WordOfTheDayEntry(
            word: "Disagree",
            partOfSpeech: "verb",
            definition: "To hold a different view without dismantling the relationship.",
            forms: ["disagreed", "disagrees", "disagreeing", "disagreement"]
        ),
        WordOfTheDayEntry(
            word: "Attune",
            partOfSpeech: "verb",
            definition: "To tune in so closely you pick up what isn't said.",
            forms: ["attuned", "attunes", "attuning", "attunement"]
        ),
        WordOfTheDayEntry(
            word: "Test",
            partOfSpeech: "verb",
            definition: "To put a claim under pressure to see what holds.",
            forms: ["tested", "tests", "testing"]
        ),
        WordOfTheDayEntry(
            word: "Flag",
            partOfSpeech: "verb",
            definition: "To mark something as worth attention without insisting on action.",
            forms: ["flagged", "flags", "flagging"]
        ),
        WordOfTheDayEntry(
            word: "Venture",
            partOfSpeech: "verb",
            definition: "To put a thought into the open before you know how it lands.",
            forms: ["ventured", "ventures", "venturing"]
        ),
        WordOfTheDayEntry(
            word: "Stretch",
            partOfSpeech: "verb",
            definition: "To work just past the edge of what's comfortable.",
            forms: ["stretched", "stretches", "stretching"]
        ),
        WordOfTheDayEntry(
            word: "Coach",
            partOfSpeech: "verb",
            definition: "To guide someone toward what they already half-know.",
            forms: ["coached", "coaches", "coaching"]
        ),
        WordOfTheDayEntry(
            word: "Center",
            partOfSpeech: "verb",
            definition: "To gather yourself back into the present.",
            forms: ["centred", "centered", "centers", "centres", "centering", "centring"]
        ),
        WordOfTheDayEntry(
            word: "Recover",
            partOfSpeech: "verb",
            definition: "To come back from a stumble without losing the thread.",
            forms: ["recovered", "recovers", "recovering", "recovery"]
        ),
        WordOfTheDayEntry(
            word: "Crystallise",
            partOfSpeech: "verb",
            definition: "To bring a fuzzy thought into a clear, fixed shape.",
            forms: ["crystallize", "crystallised", "crystallized", "crystallises", "crystallizes"]
        ),
        WordOfTheDayEntry(
            word: "Underscore",
            partOfSpeech: "verb",
            definition: "To draw deliberate attention to a point you don't want missed.",
            forms: ["underscored", "underscores", "underscoring"]
        ),
        WordOfTheDayEntry(
            word: "Caveat",
            partOfSpeech: "noun",
            definition: "A small condition or warning attached to a claim.",
            forms: ["caveats"]
        ),
        WordOfTheDayEntry(
            word: "Premise",
            partOfSpeech: "noun",
            definition: "The base assumption an argument is built on.",
            forms: ["premises", "premised"]
        ),
        WordOfTheDayEntry(
            word: "Nuance",
            partOfSpeech: "noun",
            definition: "A subtle distinction that changes the meaning.",
            forms: ["nuances", "nuanced"]
        ),
        WordOfTheDayEntry(
            word: "Aside",
            partOfSpeech: "noun",
            definition: "A small remark spoken off the main line.",
            forms: ["asides"]
        ),
        WordOfTheDayEntry(
            word: "Backbone",
            partOfSpeech: "noun",
            definition: "The structural spine that lets you hold a position.",
            forms: ["backbones"]
        ),
        WordOfTheDayEntry(
            word: "Brevity",
            partOfSpeech: "noun",
            definition: "Saying it shortly enough that nothing is wasted.",
            forms: ["brief", "briefly"]
        ),
        WordOfTheDayEntry(
            word: "Empathy",
            partOfSpeech: "noun",
            definition: "Carrying for a moment what another person is carrying.",
            forms: ["empathetic", "empathise", "empathize", "empathic"]
        ),
        WordOfTheDayEntry(
            word: "Equanimity",
            partOfSpeech: "noun",
            definition: "Steadiness of mind that survives the news.",
            forms: ["equanimous"]
        ),
        WordOfTheDayEntry(
            word: "Latitude",
            partOfSpeech: "noun",
            definition: "Room to move within an agreement or expectation.",
            forms: ["latitudes"]
        ),
        WordOfTheDayEntry(
            word: "Levity",
            partOfSpeech: "noun",
            definition: "Lightness brought into a heavy moment without dismissing it.",
            forms: ["levities"]
        ),
        WordOfTheDayEntry(
            word: "Poise",
            partOfSpeech: "noun",
            definition: "Composed bearing — body, voice, attention aligned.",
            forms: ["poised"]
        ),
        WordOfTheDayEntry(
            word: "Rapport",
            partOfSpeech: "noun",
            definition: "A working trust built between two people in real time.",
            forms: ["rapports"]
        ),
        WordOfTheDayEntry(
            word: "Tact",
            partOfSpeech: "noun",
            definition: "Skill at saying a hard thing without doing harm.",
            forms: ["tactful", "tactfully", "tactless"]
        ),
        WordOfTheDayEntry(
            word: "Discretion",
            partOfSpeech: "noun",
            definition: "Knowing what to share, with whom, and when.",
            forms: ["discreet", "discreetly"]
        ),
        WordOfTheDayEntry(
            word: "Inflection",
            partOfSpeech: "noun",
            definition: "A small shift in voice that changes the meaning.",
            forms: ["inflections", "inflected", "inflecting"]
        ),
        WordOfTheDayEntry(
            word: "Beat",
            partOfSpeech: "noun",
            definition: "A short, deliberate pause that gives a line weight.",
            forms: ["beats", "beating"]
        ),
        WordOfTheDayEntry(
            word: "Thread",
            partOfSpeech: "noun",
            definition: "The through-line that holds a longer thought together.",
            forms: ["threads", "threaded", "threading"]
        ),
        WordOfTheDayEntry(
            word: "Spine",
            partOfSpeech: "noun",
            definition: "The structural argument that keeps the rest from collapsing.",
            forms: ["spines"]
        ),
        WordOfTheDayEntry(
            word: "Weight",
            partOfSpeech: "noun",
            definition: "The significance a sentence carries when spoken right.",
            forms: ["weights", "weighted", "weighting", "weighty"]
        ),
        WordOfTheDayEntry(
            word: "Shape",
            partOfSpeech: "verb",
            definition: "To form something into a clearer outline.",
            forms: ["shaped", "shapes", "shaping"]
        ),
        WordOfTheDayEntry(
            word: "Refine",
            partOfSpeech: "verb",
            definition: "To improve by removing what isn't needed.",
            forms: ["refined", "refines", "refining", "refinement"]
        ),
        WordOfTheDayEntry(
            word: "Recast",
            partOfSpeech: "verb",
            definition: "To re-tell something in a way that lands differently.",
            forms: ["recasts", "recasted", "recasting"]
        ),
        WordOfTheDayEntry(
            word: "Untangle",
            partOfSpeech: "verb",
            definition: "To separate strands that have knotted together.",
            forms: ["untangled", "untangles", "untangling"]
        ),
        WordOfTheDayEntry(
            word: "Calibrate",
            partOfSpeech: "verb",
            definition: "To tune your delivery to what the room can actually take.",
            forms: ["calibrated", "calibrates", "calibrating", "calibration"]
        ),
        WordOfTheDayEntry(
            word: "Modulate",
            partOfSpeech: "verb",
            definition: "To adjust tone or volume in step with the moment.",
            forms: ["modulated", "modulates", "modulating", "modulation"]
        ),
        WordOfTheDayEntry(
            word: "Champion",
            partOfSpeech: "verb",
            definition: "To stand publicly behind a person or idea.",
            forms: ["championed", "champions", "championing"]
        ),
        WordOfTheDayEntry(
            word: "Uphold",
            partOfSpeech: "verb",
            definition: "To keep something in force by your own conduct.",
            forms: ["upheld", "upholds", "upholding"]
        ),
        WordOfTheDayEntry(
            word: "Forthright",
            partOfSpeech: "adjective",
            definition: "Direct and honest in a way that respects the listener.",
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
