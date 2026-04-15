import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Skill Areas

/// The 10 distinct skill areas that the drill system targets.
/// Each maps to measurable session data and has a family of drill variations.
enum SkillArea: String, Codable, CaseIterable, Identifiable {
    case fillerReduction
    case openingStrength
    case closingStrength
    case paceControl
    case structure
    case answerDevelopment
    case conciseSpeaking
    case pauseUsage
    case vocalEmphasis
    case confidence

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fillerReduction: return "Filler Words"
        case .openingStrength: return "Openings"
        case .closingStrength: return "Closings"
        case .paceControl: return "Pace"
        case .structure: return "Structure"
        case .answerDevelopment: return "Depth"
        case .conciseSpeaking: return "Conciseness"
        case .pauseUsage: return "Pauses"
        case .vocalEmphasis: return "Emphasis"
        case .confidence: return "Confidence"
        }
    }

    var icon: String {
        switch self {
        case .fillerReduction: return "waveform.path"
        case .openingStrength: return "bolt.fill"
        case .closingStrength: return "flag.checkered"
        case .paceControl: return "metronome.fill"
        case .structure: return "list.number"
        case .answerDevelopment: return "arrow.down.to.line"
        case .conciseSpeaking: return "scissors"
        case .pauseUsage: return "pause.fill"
        case .vocalEmphasis: return "speaker.wave.3.fill"
        case .confidence: return "person.fill"
        }
    }

    #if canImport(SwiftUI)
    var tint: Color {
        switch self {
        case .fillerReduction: return .red
        case .openingStrength: return AppColor.brandBlue
        case .closingStrength: return .purple
        case .paceControl: return .orange
        case .structure: return AppColor.brandBlue
        case .answerDevelopment: return .teal
        case .conciseSpeaking: return Color(.systemIndigo)
        case .pauseUsage: return .mint
        case .vocalEmphasis: return .pink
        case .confidence: return AppColor.positive
        }
    }
    #endif

    /// Sensitivity tier for feedback tone — some skills are anxiety-adjacent.
    var feedbackSensitivity: FeedbackSensitivity {
        switch self {
        case .fillerReduction, .confidence, .paceControl:
            return .gentle
        case .openingStrength, .closingStrength, .pauseUsage, .vocalEmphasis:
            return .measured
        case .structure, .answerDevelopment, .conciseSpeaking:
            return .direct
        }
    }
}

/// How sensitive the user is likely to be about feedback on this skill.
enum FeedbackSensitivity: String, Codable {
    case direct     // Structure, depth — user can hear it straight
    case measured   // Pace, opening — balance honesty with encouragement
    case gentle     // Fillers, confidence — anxiety-adjacent, be careful
}

// MARK: - Drill Format

/// Whether the drill is a quick focused exercise or a full re-practice.
enum DrillFormat: String, Codable {
    case miniDrill    // 30–60 seconds, focused on one micro-skill
    case fullRetry    // Full re-practice with constraint overlay
}

// MARK: - Drill Variation

/// A single drill exercise within a skill family.
struct DrillVariation: Identifiable, Codable, Equatable {
    let id: String                      // Stable ID, e.g. "filler.silentTransitions"
    let skillArea: SkillArea
    let title: String                   // e.g., "Silent Transitions"
    let constraint: String              // The one rule to follow
    let coachingPrinciple: String       // What speaking principle this trains
    let format: DrillFormat
    let successDescription: String      // How success is measured

    #if canImport(SwiftUI)
    var icon: String { skillArea.icon }
    var tint: Color { skillArea.tint }
    #endif

    static func == (lhs: DrillVariation, rhs: DrillVariation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Drill Recommendation (v2)

/// The drill recommendation shown to the user after a session.
/// Includes the selected variation, dynamic rationale, and format.
struct DrillRecommendationV2: Identifiable {
    let id = UUID()
    let variation: DrillVariation
    let reason: String                  // Dynamic, session-specific rationale
    let trendContext: String?           // Cross-session trend context, if available
    let alternateFormat: DrillFormat?   // If "either" applies, the other option

    var skillArea: SkillArea { variation.skillArea }
    var format: DrillFormat { variation.format }
    var title: String { variation.title }
    var constraint: String { variation.constraint }
    var successDescription: String { variation.successDescription }

    #if canImport(SwiftUI)
    var icon: String { variation.icon }
    var tint: Color { variation.tint }
    #endif
}

// MARK: - Drill Result

/// Recorded when a user completes a drill (mini or full retry).
struct DrillResult: Codable, Equatable {
    let variationId: String
    let skillArea: SkillArea
    let format: DrillFormat
    let succeeded: Bool
    let parentSessionId: UUID?          // The session that triggered this drill
}

// MARK: - Drill History

/// Tracks recent drill completions for freshness rotation and streak detection.
class DrillHistoryStore: ObservableObject {
    static let shared = DrillHistoryStore()

    @Published var entries: [Entry] = []

    struct Entry: Identifiable, Codable {
        let id: UUID
        let variationId: String
        let skillArea: SkillArea
        let date: Date
        let succeeded: Bool
        let sessionId: UUID

        init(variationId: String, skillArea: SkillArea, date: Date = Date(), succeeded: Bool, sessionId: UUID) {
            self.id = UUID()
            self.variationId = variationId
            self.skillArea = skillArea
            self.date = date
            self.succeeded = succeeded
            self.sessionId = sessionId
        }
    }

    private let storageKey = "drillHistory"

    private init() {
        load()
    }

    func record(_ entry: Entry) {
        entries.insert(entry, at: 0)
        if entries.count > 30 { entries = Array(entries.prefix(30)) }
        save()
    }

    /// How many consecutive successful drills in a given skill area (most recent first).
    func currentStreak(for skillArea: SkillArea) -> Int {
        var count = 0
        for entry in entries where entry.skillArea == skillArea {
            if entry.succeeded { count += 1 } else { break }
        }
        return count
    }

    /// The most recently completed variation IDs for a skill area.
    func recentVariationIds(for skillArea: SkillArea, limit: Int = 5) -> [String] {
        entries
            .filter { $0.skillArea == skillArea }
            .prefix(limit)
            .map(\.variationId)
    }

    /// Whether a specific variation was the last drill completed.
    func wasLastDrill(_ variationId: String) -> Bool {
        entries.first?.variationId == variationId
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = decoded
    }
}

// MARK: - Drill Catalog

/// The complete catalog of drill variations, organized by skill area.
/// All variations are hand-crafted and grounded in speaking/coaching principles.
enum DrillCatalog {

    static let allVariations: [DrillVariation] = {
        var all: [DrillVariation] = []
        all.append(contentsOf: fillerReduction)
        all.append(contentsOf: openingStrength)
        all.append(contentsOf: closingStrength)
        all.append(contentsOf: paceControl)
        all.append(contentsOf: structureDrills)
        all.append(contentsOf: answerDevelopment)
        all.append(contentsOf: conciseSpeaking)
        all.append(contentsOf: pauseUsage)
        all.append(contentsOf: vocalEmphasis)
        all.append(contentsOf: confidenceDrills)
        return all
    }()

    static func variations(for skillArea: SkillArea) -> [DrillVariation] {
        allVariations.filter { $0.skillArea == skillArea }
    }

    // MARK: Filler Reduction

    static let fillerReduction: [DrillVariation] = [
        DrillVariation(
            id: "filler.silentTransitions",
            skillArea: .fillerReduction,
            title: "Silent Transitions",
            constraint: "Pause silently for a full beat before every new point. No \"um\", \"uh\", or \"like\" allowed.",
            coachingPrinciple: "Silence is confidence. Fillers are the sound of thinking out loud.",
            format: .miniDrill,
            successDescription: "Fewer than 2 filler words"
        ),
        DrillVariation(
            id: "filler.breathReset",
            skillArea: .fillerReduction,
            title: "The Breath Reset",
            constraint: "Take one deliberate breath between every sentence. No exceptions.",
            coachingPrinciple: "Controlled breathing prevents filler cascades.",
            format: .miniDrill,
            successDescription: "Fewer than 2 filler words"
        ),
        DrillVariation(
            id: "filler.slowFirstCleanSecond",
            skillArea: .fillerReduction,
            title: "Slow First, Clean Second",
            constraint: "Speak at 80% of your normal speed. Slower pace means fewer fillers naturally.",
            coachingPrinciple: "Speed is the #1 filler trigger. Slow down to clean up.",
            format: .miniDrill,
            successDescription: "Pace below 130 WPM with fewer than 2 fillers"
        ),
        DrillVariation(
            id: "filler.bridgePhrases",
            skillArea: .fillerReduction,
            title: "Bridge Phrases",
            constraint: "When transitioning between ideas, use \"And so...\" or \"Which means...\" instead of filler sounds.",
            coachingPrinciple: "Replacing fillers with bridge phrases keeps flow without the crutch.",
            format: .miniDrill,
            successDescription: "Zero filler words"
        ),
        DrillVariation(
            id: "filler.pointPausePoint",
            skillArea: .fillerReduction,
            title: "Point-Pause-Point",
            constraint: "Make one point. Full stop. Pause for 2 seconds. Then make the next point.",
            coachingPrinciple: "Chunking ideas eliminates the gap where fillers live.",
            format: .miniDrill,
            successDescription: "Zero filler words"
        ),
    ]

    // MARK: Opening Strength

    static let openingStrength: [DrillVariation] = [
        DrillVariation(
            id: "opening.declarative",
            skillArea: .openingStrength,
            title: "The Declarative Open",
            constraint: "Start with a bold, clear statement. No hedging, no \"I think\", no \"Well...\"",
            coachingPrinciple: "First impressions anchor everything that follows.",
            format: .miniDrill,
            successDescription: "Opening rated OK or better"
        ),
        DrillVariation(
            id: "opening.questionHook",
            skillArea: .openingStrength,
            title: "The Question Hook",
            constraint: "Open with a rhetorical question that frames your answer.",
            coachingPrinciple: "Questions create engagement and buy you thinking time.",
            format: .miniDrill,
            successDescription: "Opening rated OK or better"
        ),
        DrillVariation(
            id: "opening.contrastOpen",
            skillArea: .openingStrength,
            title: "The Contrast Open",
            constraint: "Start with \"Most people think X. But actually...\" or a similar contrast.",
            coachingPrinciple: "Contrast creates attention and signals confidence.",
            format: .miniDrill,
            successDescription: "Opening rated OK or better"
        ),
        DrillVariation(
            id: "opening.storyEntry",
            skillArea: .openingStrength,
            title: "The Story Entry",
            constraint: "Open with \"Last week...\" or \"I remember when...\" — start with a story, not an opinion.",
            coachingPrinciple: "Narrative openings are memorable and feel natural.",
            format: .miniDrill,
            successDescription: "Opening rated OK or better"
        ),
        DrillVariation(
            id: "opening.oneLineThesis",
            skillArea: .openingStrength,
            title: "One-Line Thesis",
            constraint: "Your first sentence must contain your entire argument in one line.",
            coachingPrinciple: "Thesis-first speaking trains executive presence.",
            format: .miniDrill,
            successDescription: "Opening rated OK or better"
        ),
    ]

    // MARK: Closing Strength

    static let closingStrength: [DrillVariation] = [
        DrillVariation(
            id: "closing.callback",
            skillArea: .closingStrength,
            title: "The Callback Close",
            constraint: "End by referring back to something you said in your opening.",
            coachingPrinciple: "Callbacks create a sense of completeness and polish.",
            format: .miniDrill,
            successDescription: "Close rated OK or better"
        ),
        DrillVariation(
            id: "closing.oneLineSummary",
            skillArea: .closingStrength,
            title: "One-Sentence Summary",
            constraint: "End with exactly one sentence that summarizes your entire point.",
            coachingPrinciple: "A deliberate close leaves a lasting impression.",
            format: .miniDrill,
            successDescription: "Close rated OK or better"
        ),
        DrillVariation(
            id: "closing.forwardLook",
            skillArea: .closingStrength,
            title: "The Forward Look",
            constraint: "End with a forward-looking statement: what this means going forward.",
            coachingPrinciple: "Forward-looking closes feel confident and intentional.",
            format: .miniDrill,
            successDescription: "Close rated OK or better"
        ),
        DrillVariation(
            id: "closing.decisiveStop",
            skillArea: .closingStrength,
            title: "The Decisive Stop",
            constraint: "Deliver your last sentence with conviction, then stop completely. No trailing off.",
            coachingPrinciple: "How you end is what people remember. Don't fade — land.",
            format: .miniDrill,
            successDescription: "Close rated OK or better"
        ),
    ]

    // MARK: Pace Control

    static let paceControl: [DrillVariation] = [
        DrillVariation(
            id: "pace.metronome",
            skillArea: .paceControl,
            title: "The Metronome",
            constraint: "Speak at a deliberate, even pace throughout. No speeding up, no slowing down.",
            coachingPrinciple: "Consistent pace signals control and composure.",
            format: .miniDrill,
            successDescription: "WPM within 110–150 range"
        ),
        DrillVariation(
            id: "pace.slowStart",
            skillArea: .paceControl,
            title: "The Slow Start",
            constraint: "Deliberately slow your first 10 seconds to half your normal speed.",
            coachingPrinciple: "A slow start anchors calm for the rest of the answer.",
            format: .miniDrill,
            successDescription: "Pace below 150 WPM"
        ),
        DrillVariation(
            id: "pace.pausePunctuation",
            skillArea: .paceControl,
            title: "Pause Punctuation",
            constraint: "Pause for one full second after every period. Let each sentence land.",
            coachingPrinciple: "Pauses between sentences naturally regulate pace.",
            format: .miniDrill,
            successDescription: "WPM within 110–150 range"
        ),
        DrillVariation(
            id: "pace.speedCheck",
            skillArea: .paceControl,
            title: "The Speed Check",
            constraint: "Halfway through your answer, consciously check your pace and adjust.",
            coachingPrinciple: "Self-monitoring builds the habit of pace awareness.",
            format: .miniDrill,
            successDescription: "WPM within 110–150 range"
        ),
        DrillVariation(
            id: "pace.conversationalGear",
            skillArea: .paceControl,
            title: "Conversational Gear",
            constraint: "Speak as if explaining something to a friend over coffee. Natural, unhurried.",
            coachingPrinciple: "Conversational pace is the most persuasive pace.",
            format: .miniDrill,
            successDescription: "WPM within 110–150 range"
        ),
    ]

    // MARK: Structure

    static let structureDrills: [DrillVariation] = [
        DrillVariation(
            id: "structure.threePartFramework",
            skillArea: .structure,
            title: "Three-Part Framework",
            constraint: "Use strict 3-part structure: opening statement, one supporting example, closing sentence.",
            coachingPrinciple: "Simple frameworks make impromptu answers feel prepared.",
            format: .fullRetry,
            successDescription: "Structure rated OK or better"
        ),
        DrillVariation(
            id: "structure.prepMethod",
            skillArea: .structure,
            title: "The PREP Method",
            constraint: "Follow Point → Reason → Example → Point. Hit all four in order.",
            coachingPrinciple: "PREP is the gold standard for structured impromptu responses.",
            format: .fullRetry,
            successDescription: "Structure rated OK or better"
        ),
        DrillVariation(
            id: "structure.timeline",
            skillArea: .structure,
            title: "The Timeline",
            constraint: "Organize your answer chronologically: past → present → future.",
            coachingPrinciple: "Chronological structure is intuitive for both speaker and listener.",
            format: .fullRetry,
            successDescription: "Structure rated OK or better"
        ),
        DrillVariation(
            id: "structure.contrastFrame",
            skillArea: .structure,
            title: "The Contrast Frame",
            constraint: "Structure as: \"On one hand... On the other hand... Therefore...\"",
            coachingPrinciple: "Contrast frames show balanced thinking and intellectual range.",
            format: .fullRetry,
            successDescription: "Structure rated OK or better"
        ),
    ]

    // MARK: Answer Development

    static let answerDevelopment: [DrillVariation] = [
        DrillVariation(
            id: "depth.specificExample",
            skillArea: .answerDevelopment,
            title: "The Specific Example",
            constraint: "Your answer must include one concrete, real story or example. No abstractions.",
            coachingPrinciple: "Specificity is what makes an answer memorable and believable.",
            format: .fullRetry,
            successDescription: "Depth rated OK or better"
        ),
        DrillVariation(
            id: "depth.soWhatTest",
            skillArea: .answerDevelopment,
            title: "The \"So What\" Test",
            constraint: "After every point, say why it matters. End each idea with the implication.",
            coachingPrinciple: "The \"so what\" test forces development beyond surface statements.",
            format: .fullRetry,
            successDescription: "Depth rated OK or better"
        ),
        DrillVariation(
            id: "depth.detailLayer",
            skillArea: .answerDevelopment,
            title: "The Detail Layer",
            constraint: "Add one sensory or emotional detail to your main example. Make it vivid.",
            coachingPrinciple: "Detail creates engagement and makes abstractions feel real.",
            format: .fullRetry,
            successDescription: "Depth rated OK or better"
        ),
        DrillVariation(
            id: "depth.evidenceStack",
            skillArea: .answerDevelopment,
            title: "The Evidence Stack",
            constraint: "Support your point with two different types of evidence: a personal example and a general observation.",
            coachingPrinciple: "Multiple evidence types make arguments more persuasive.",
            format: .fullRetry,
            successDescription: "Depth rated OK or better"
        ),
    ]

    // MARK: Concise Speaking

    static let conciseSpeaking: [DrillVariation] = [
        DrillVariation(
            id: "concise.threeSentenceCap",
            skillArea: .conciseSpeaking,
            title: "Three-Sentence Cap",
            constraint: "Make your full point in exactly three sentences. No more.",
            coachingPrinciple: "Constraints force clarity. Three sentences is enough for one powerful idea.",
            format: .miniDrill,
            successDescription: "Answer under 25 seconds with clear point"
        ),
        DrillVariation(
            id: "concise.headlineFirst",
            skillArea: .conciseSpeaking,
            title: "Headline First",
            constraint: "Lead with your conclusion in the first sentence. Then support it.",
            coachingPrinciple: "Bottom-line-up-front is how executives communicate.",
            format: .miniDrill,
            successDescription: "Clear main point in first sentence"
        ),
        DrillVariation(
            id: "concise.timeBox",
            skillArea: .conciseSpeaking,
            title: "The Time Box",
            constraint: "Make your full point in 20 seconds. Complete thought, then stop.",
            coachingPrinciple: "Time boxing forces you to find the core of what you want to say.",
            format: .miniDrill,
            successDescription: "Complete answer in 20 seconds"
        ),
        DrillVariation(
            id: "concise.noRepeat",
            skillArea: .conciseSpeaking,
            title: "No Repeat",
            constraint: "Say each idea exactly once. No restating, no circling back, no rephrasing.",
            coachingPrinciple: "Repetition is the most common form of rambling. Cut it.",
            format: .miniDrill,
            successDescription: "No repeated ideas"
        ),
    ]

    // MARK: Pause Usage

    static let pauseUsage: [DrillVariation] = [
        DrillVariation(
            id: "pause.powerPause",
            skillArea: .pauseUsage,
            title: "The Power Pause",
            constraint: "Take one deliberate 2-second pause before your single most important point.",
            coachingPrinciple: "Pausing before a key point creates anticipation and emphasis.",
            format: .miniDrill,
            successDescription: "At least one deliberate pause detected"
        ),
        DrillVariation(
            id: "pause.paragraphBreak",
            skillArea: .pauseUsage,
            title: "Paragraph Breaks",
            constraint: "Pause between each distinct idea — treat your speech like paragraphs.",
            coachingPrinciple: "Pauses signal structure and give the listener time to absorb.",
            format: .miniDrill,
            successDescription: "Clear pauses between ideas"
        ),
        DrillVariation(
            id: "pause.landingPause",
            skillArea: .pauseUsage,
            title: "The Landing Pause",
            constraint: "After your final sentence, hold silence for 2 seconds. Don't trail off.",
            coachingPrinciple: "A landing pause makes your close feel intentional and powerful.",
            format: .miniDrill,
            successDescription: "Clean ending with deliberate pause"
        ),
        DrillVariation(
            id: "pause.thinkingPause",
            skillArea: .pauseUsage,
            title: "The Thinking Pause",
            constraint: "When you need to think, pause visibly and calmly instead of filling the silence.",
            coachingPrinciple: "A thinking pause looks confident. A filler word looks nervous.",
            format: .miniDrill,
            successDescription: "Zero filler words with at least one thinking pause"
        ),
    ]

    // MARK: Vocal Emphasis

    static let vocalEmphasis: [DrillVariation] = [
        DrillVariation(
            id: "emphasis.keyWord",
            skillArea: .vocalEmphasis,
            title: "The Key Word",
            constraint: "In each sentence, choose one word to emphasize. Hit it harder.",
            coachingPrinciple: "Vocal emphasis guides the listener to what matters most.",
            format: .miniDrill,
            successDescription: "Noticeable variation in delivery"
        ),
        DrillVariation(
            id: "emphasis.volumeShift",
            skillArea: .vocalEmphasis,
            title: "Volume Shift",
            constraint: "Drop or raise your volume on your most important phrase.",
            coachingPrinciple: "Volume contrast creates dramatic emphasis without words.",
            format: .miniDrill,
            successDescription: "Clear volume variation"
        ),
        DrillVariation(
            id: "emphasis.paceShift",
            skillArea: .vocalEmphasis,
            title: "Pace Shift",
            constraint: "Slow down noticeably for your most important point. Speed up slightly for supporting details.",
            coachingPrinciple: "Pace variation signals importance — fast for energy, slow for weight.",
            format: .miniDrill,
            successDescription: "Pace variation within answer"
        ),
        DrillVariation(
            id: "emphasis.repetitionPunch",
            skillArea: .vocalEmphasis,
            title: "The Repetition Punch",
            constraint: "Repeat your most important phrase once for impact. Say it, pause, say it again.",
            coachingPrinciple: "Strategic repetition is a tool of persuasion used by the best speakers.",
            format: .miniDrill,
            successDescription: "One deliberate repetition for emphasis"
        ),
    ]

    // MARK: Confidence

    static let confidenceDrills: [DrillVariation] = [
        DrillVariation(
            id: "confidence.commitmentDrill",
            skillArea: .confidence,
            title: "The Commitment Drill",
            constraint: "No hedge words allowed: no \"I think\", \"maybe\", \"sort of\", \"kind of\", \"I guess\".",
            coachingPrinciple: "Hedge words undermine authority. Commit to your statements.",
            format: .miniDrill,
            successDescription: "Zero hedge words"
        ),
        DrillVariation(
            id: "confidence.ownershipOpen",
            skillArea: .confidence,
            title: "Ownership Open",
            constraint: "Start with \"I believe\" or \"In my experience\" — own your perspective.",
            coachingPrinciple: "Owning your perspective signals confidence and authenticity.",
            format: .miniDrill,
            successDescription: "Opening with ownership language"
        ),
        DrillVariation(
            id: "confidence.groundedPace",
            skillArea: .confidence,
            title: "Grounded Pace",
            constraint: "Speak at 80% of your natural speed. Control signals confidence.",
            coachingPrinciple: "Slow, grounded delivery is the hallmark of confident speakers.",
            format: .miniDrill,
            successDescription: "Pace below 130 WPM"
        ),
        DrillVariation(
            id: "confidence.silenceComfort",
            skillArea: .confidence,
            title: "Silence Comfort",
            constraint: "Include at least three deliberate 2-second silences. Get comfortable with quiet.",
            coachingPrinciple: "Comfort with silence is the ultimate confidence signal.",
            format: .miniDrill,
            successDescription: "Three or more deliberate pauses"
        ),
    ]
}

// MARK: - Drill Selector

/// Selects the best drill variation for a given skill area, respecting freshness constraints.
enum DrillSelector {

    /// Pick the best variation for a skill area, avoiding recently used ones.
    static func select(
        for skillArea: SkillArea,
        history: DrillHistoryStore = .shared
    ) -> DrillVariation? {
        let variations = DrillCatalog.variations(for: skillArea)
        guard !variations.isEmpty else { return nil }

        let recentIds = Set(history.recentVariationIds(for: skillArea, limit: variations.count - 1))
        let lastDrillId = history.entries.first?.variationId

        // Prefer variations not recently used
        let fresh = variations.filter { !recentIds.contains($0.id) }

        // From fresh options, avoid the very last drill done (any skill area)
        let preferred = fresh.filter { $0.id != lastDrillId }

        if let pick = preferred.randomElement() { return pick }
        if let pick = fresh.randomElement() { return pick }

        // All exhausted — pick any that isn't the very last one done
        let fallback = variations.filter { $0.id != lastDrillId }
        return fallback.randomElement() ?? variations.first
    }
}
