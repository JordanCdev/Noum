import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFAudio)
import AVFAudio
#endif

// MARK: - Navigation Destination Types

enum AppDestination: Hashable {
    case practiceSelection
    case timedPractice
    case suddenDeathPractice
    case ahCounterPractice
    case imPractice(scenario: IMConversationScenario?, tone: IMTargetTone?)
    case cutTheCrutchPractice
    case paceTrainingPractice
    case friendLeaderboard
    case league
    case speechProjects
    case lessons
    case lesson(id: String)
    case summary(SummaryPayload)
    case sessionHistory
    case socialProfile
    case settings
    case speakingRank
    case pathJourney
    case askNoum
    /// Typed Ask Noum entry for accessibility, UI tests, and users who want the
    /// thread directly. The main `askNoum` case remains the live coach session.
    case askNoumTyped
    case growthLibrary
    /// Detail view for a single past session, addressable by session ID so
    /// surfaces like the Growth Library can deep-link straight to "the
    /// session that produced this proof" without going through the History
    /// list. Falls back to the History list when the session has been
    /// deleted or isn't in the store anymore — see `ContentView`'s
    /// destination switch.
    case sessionDetail(sessionID: UUID)
    case bigMomentIntake
    /// M23 Situational Preparation Mode landing surface. Available when
    /// the user has an active BigMoment within 14 days; the HomeCoachCard
    /// surfaces a CTA that pushes here. The view assembles the
    /// PrepSessionPlanner's plan and provides per-step launchers into
    /// Timed, Sudden Death, and IM.
    case prepSession
    /// Per-difficulty drill-down for Sudden Death runs. Reached from
    /// the breakdown card on `SessionHistoryView` when the user filters
    /// to Sudden Death and taps a difficulty row. Renders the full run
    /// list at that difficulty + a plain-text export affordance.
    case suddenDeathDifficultyDetail(difficulty: SuddenDeathDifficulty)
    /// Per-scenario drill-down for IM Mode reps. Reached from the
    /// IM history breakdown card when the user filters to IM Mode and
    /// taps a scenario row. Mirrors `suddenDeathDifficultyDetail`:
    /// renders the full rep list at that scenario + plain-text export.
    case imScenarioDetail(scenario: IMConversationScenario)
}

/// Pure router for the Summary "Practice Again" CTA. Carved out of
/// `SummaryView`'s path-based init so the destination choice is
/// independent of SwiftUI/navigation plumbing and can be locked in tests.
///
/// IM-mode reps carry a `setup` (scenario + tone) on the finished rep's
/// `IMConversationDetails`. Practice Again must re-arm the *same* scenario
/// and tone the user just ran — dropping back to the picker on every rep
/// is friction the rest of the modes never inflict on Timed/Sudden Death/
/// Ah-Counter. The other modes have no per-rep setup to preserve, so they
/// route to their plain practice destinations.
enum SummaryPracticeAgainRouter {
    static func destination(
        for mode: PracticeMode,
        imSetup: IMConversationSetup?
    ) -> AppDestination {
        switch mode {
        case .timed: return .timedPractice
        case .suddenDeath: return .suddenDeathPractice
        case .ahCounter: return .ahCounterPractice
        case .imConversation:
            return .imPractice(
                scenario: imSetup?.scenario,
                tone: imSetup?.targetTone
            )
        }
    }
}

/// Pure router for the Summary "Looking ahead" recommendation launch.
/// Mirrors `SummaryPracticeAgainRouter` but maps the *forward-looking*
/// `RecommendationBiasBlueprint` (the same shape Home's coach card and
/// the mode-picker recommendation tile already consume) into the
/// destination that running the recommendation should push.
///
/// The blueprint carries the recommended scenario + tone for IM reps —
/// when the tone-drill signal fires, those carry the exact pair the user
/// keeps missing, so launching directly into that scenario closes the
/// loop in one tap instead of dropping the user back on the picker. When
/// the blueprint is the goal-biased fallback (no tone-drill signal,
/// non-IM mode), the scenario/tone are nil and the router still routes
/// cleanly to the plain practice destination for that mode.
///
/// IM mode is gated by `imAvailable` so the caller can hand up the same
/// `IMModeAvailability.isAvailable` flag that the other launch surfaces
/// honor. When IM is the recommendation but IM Mode is unconfigured on
/// the device, the router falls back to `.timedPractice` — so the
/// recommendation never sends the user to a surface that can't run. Pure
/// data in, pure destination out — no SwiftUI, no nav path, no
/// availability lookups; the caller owns those.
///
/// As of round 17, both `HomeCoachCard.destination()` (zero-arg as of
/// round 18) and `ContentView.practiceAppDestination(for:)` route their
/// destination calculation through this router so the mode-to-destination
/// mapping and the IM-unavailable fallback live in exactly one place.
/// `ContentView` calls the lower-level
/// `destination(for:scenario:tone:imAvailable:)` overload because its
/// private `PracticeSuggestion` value type holds the three fields the
/// router reads outside a full `RecommendationBiasBlueprint`;
/// `HomeCoachCard` holds the blueprint directly and calls the
/// blueprint-shaped overload.
enum SummaryLookingAheadRouter {
    static func destination(
        for blueprint: RecommendationBiasBlueprint,
        imAvailable: Bool
    ) -> AppDestination {
        destination(
            for: blueprint.recommendedMode,
            scenario: blueprint.recommendedScenario,
            tone: blueprint.recommendedTone,
            imAvailable: imAvailable
        )
    }

    /// Lower-level form for callers that hold the recommended mode +
    /// scenario + tone outside a full `RecommendationBiasBlueprint`
    /// (e.g. `ContentView`'s private `PracticeSuggestion` value type).
    /// Behavior is identical to the blueprint overload — the blueprint
    /// form delegates straight through to this one — so both call sites
    /// get the same mode-to-destination mapping and the same IM-
    /// unavailable fallback to `.timedPractice` without re-deriving them.
    static func destination(
        for mode: PracticeMode,
        scenario: IMConversationScenario?,
        tone: IMTargetTone?,
        imAvailable: Bool
    ) -> AppDestination {
        switch mode {
        case .timed: return .timedPractice
        case .suddenDeath: return .suddenDeathPractice
        case .ahCounter: return .ahCounterPractice
        case .imConversation:
            guard imAvailable else { return .timedPractice }
            return .imPractice(scenario: scenario, tone: tone)
        }
    }
}

struct SummaryPayload: Identifiable, Hashable {
    let id: UUID
    let mode: PracticeMode
}

/// Holds the non-Hashable data that SummaryView needs, keyed by SummaryPayload.id.
/// Practice views store their data here before pushing a `.summary(payload)` onto the navigation path.
@MainActor
final class SummaryDataStore {
    static let shared = SummaryDataStore()
    private init() {}

    struct Entry {
        let transcript: AttributedString
        let fillerCount: Int
        let duration: TimeInterval
        let score: Int?
        let progressSegments: Int
        let xpEarned: Int
        /// Set when a mode commits reward/coaching side effects before
        /// opening Summary. Summary renders this result without finalizing
        /// the same session a second time.
        let committedFinalization: SessionFinalizationResult?
        let suddenDeathGamePoints: Int?
        let suddenDeathMultiplierLabels: [String]
        let suddenDeathTotalWords: Int?
        let showDuration: Bool
        let practiceTitle: String
        let feedbackOverride: String?
        let headlineOverride: String?
        let scoreBreakdown: [PracticeScoreSegment]
        let insights: [String]
        let recentSessions: [PracticeSession]
        let imConversationDetails: IMConversationDetails?
        let explicitMode: PracticeMode?
        let recordingURL: URL?
        let sessionPrompt: String?
        let sessionTheme: PromptTheme?
        let feedbackCategories: [FeedbackCategory]
        let strongMoments: [String]
        let weakMoments: [String]
        let durationAssessment: DurationAssessment
        let targetRange: (min: Double, target: Double, max: Double)
        let onStartDrill: ((DrillRecommendation) -> Void)?
    }

    private var entries: [UUID: Entry] = [:]

    func store(_ entry: Entry, for id: UUID) {
        entries[id] = entry
    }

    func retrieve(for id: UUID) -> Entry? {
        entries[id]
    }

    func remove(for id: UUID) {
        entries.removeValue(forKey: id)
    }
}

enum LocalConfigLoader {
    static func value(forKey key: String, plistNamed plistName: String) -> String? {
        guard let url = Bundle.main.url(forResource: plistName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = plist[key] as? String,
              !value.isEmpty else {
            return nil
        }

        return value
    }
}

enum TimedPracticeDifficulty: String, CaseIterable, Codable, Identifiable {
    case free
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: return "Free"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var duration: Int? {
        switch self {
        case .free: return nil
        case .easy: return 60
        case .medium: return 30
        case .hard: return 15
        }
    }

    var subtitle: String {
        switch self {
        case .free: return "No countdown. Start when ready and stop manually."
        case .easy: return "60 seconds to answer with structure."
        case .medium: return "30 seconds to get to the point quickly."
        case .hard: return "15 seconds. Fast, concise, high pressure."
        }
    }

    var xpMultiplier: Double {
        switch self {
        case .free: return 0.9
        case .easy: return 1.0
        case .medium: return 1.15
        case .hard: return 1.35
        }
    }

    /// Target duration range: (minimum acceptable, ideal target, maximum acceptable) in seconds.
    /// Duration within this range scores highest. Too short or too long both reduce the score.
    var targetRange: (min: Double, target: Double, max: Double) {
        switch self {
        case .free:   return (min: 30, target: 60,  max: 120)  // Free: aim for 30–120s, sweet spot 60s
        case .easy:   return (min: 45, target: 60,  max: 90)   // Easy (60s): aim for 45–90s
        case .medium: return (min: 20, target: 30,  max: 50)   // Medium (30s): aim for 20–50s
        case .hard:   return (min: 10, target: 15,  max: 25)   // Hard (15s): aim for 10–25s
        }
    }
}

/// How the speaker's duration compares to the target range.
enum DurationAssessment: String {
    case tooShort = "Too short"
    case onTarget = "On target"
    case tooLong = "Too long"

    var icon: String {
        switch self {
        case .tooShort: return "arrow.down.circle.fill"
        case .onTarget: return "checkmark.circle.fill"
        case .tooLong: return "arrow.up.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .tooShort: return AppColor.caution
        case .onTarget: return AppColor.positive
        case .tooLong: return AppColor.caution
        }
    }
}

extension PracticeEvaluator {
    /// Assess how the actual duration compares to the difficulty's target range.
    static func assessDuration(_ duration: TimeInterval, difficulty: TimedPracticeDifficulty) -> DurationAssessment {
        let range = difficulty.targetRange
        if duration < range.min { return .tooShort }
        if duration > range.max { return .tooLong }
        return .onTarget
    }

    /// Score duration on a 0–1 scale using the target range. 1.0 = ideal, tapering toward 0 outside range.
    static func durationRangeScore(_ duration: TimeInterval, difficulty: TimedPracticeDifficulty) -> Double {
        let range = difficulty.targetRange
        if duration >= range.min && duration <= range.max {
            // Within acceptable range — score based on closeness to target
            let distanceFromTarget = abs(duration - range.target)
            let maxDistance = max(range.target - range.min, range.max - range.target)
            return maxDistance > 0 ? 1.0 - (distanceFromTarget / maxDistance) * 0.2 : 1.0
        } else if duration < range.min {
            // Too short — linear taper from min down to 0
            let shortfall = range.min - duration
            let maxShortfall = range.min // At 0s, score = 0
            return max(0, 1.0 - (shortfall / maxShortfall))
        } else {
            // Too long — gentler penalty, max penalty at 2x max
            let overshoot = duration - range.max
            let maxOvershoot = range.max // At 2x max, score ≈ 0
            return max(0, 1.0 - (overshoot / maxOvershoot))
        }
    }
}

enum SpeakingContext: String, CaseIterable, Codable, Identifiable {
    case work
    case interviews
    case presentations
    case social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: return "Work conversations"
        case .interviews: return "Interviews"
        case .presentations: return "Presentations"
        case .social: return "Everyday confidence"
        }
    }
}

enum CoachingPriority: String, CaseIterable, Codable, Identifiable {
    case reduceFillers
    case moreConcise
    case thinkFaster
    case calmerDelivery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reduceFillers: return "Reduce filler words"
        case .moreConcise: return "Be more concise"
        case .thinkFaster: return "Think faster on the spot"
        case .calmerDelivery: return "Sound calmer and more composed"
        }
    }
}

enum ConfidenceLevel: String, CaseIterable, Codable, Identifiable {
    case beginner
    case rebuilding
    case inconsistent
    case confident

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .rebuilding: return "Rebuilding confidence"
        case .inconsistent: return "Confident but inconsistent"
        case .confident: return "Already fairly confident"
        }
    }
}

enum SpeakingChallenge: String, CaseIterable, Codable, Identifiable {
    case fillerWords
    case rambling
    case freezing
    case rushing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fillerWords: return "I fall back on filler words"
        case .rambling: return "I lose structure and ramble"
        case .freezing: return "I blank when I’m put on the spot"
        case .rushing: return "I speak too quickly under pressure"
        }
    }

    var recommendedPriority: CoachingPriority {
        switch self {
        case .fillerWords: return .reduceFillers
        case .rambling: return .moreConcise
        case .freezing: return .thinkFaster
        case .rushing: return .calmerDelivery
        }
    }

    var goalPrompt: String {
        switch self {
        case .fillerWords: return "What do you want to say more cleanly when fillers usually creep in?"
        case .rambling: return "What do you want to explain more clearly when your answer starts to drift?"
        case .freezing: return "What situation do you want to handle more smoothly when you’re put on the spot?"
        case .rushing: return "What do you want to deliver with more control when pressure speeds you up?"
        }
    }
}

enum SpeakingOutcome: String, CaseIterable, Codable, Identifiable {
    case concise
    case composed
    case persuasive
    case spontaneous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concise: return "Sound concise and clear"
        case .composed: return "Sound calm and in control"
        case .persuasive: return "Sound more convincing and structured"
        case .spontaneous: return "Think and respond more smoothly in the moment"
        }
    }
}

enum SpeakingStyleGoal: String, CaseIterable, Codable, Identifiable {
    case authoritative
    case warm
    case concise
    case persuasive
    case executive
    case storytelling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .authoritative: return "Authoritative"
        case .warm: return "Warm and welcoming"
        case .concise: return "Concise and sharp"
        case .persuasive: return "Persuasive"
        case .executive: return "Executive presence"
        case .storytelling: return "Storytelling"
        }
    }

    var coachingDescription: String {
        switch self {
        case .authoritative: return "sound steady, assured, and hard to ignore"
        case .warm: return "sound encouraging, natural, and easy to trust"
        case .concise: return "sound crisp, efficient, and clean"
        case .persuasive: return "sound convincing, well-supported, and intentional"
        case .executive: return "sound composed, high-level, and boardroom-ready"
        case .storytelling: return "sound vivid, engaging, and memorable"
        }
    }

    var recommendedOutcome: SpeakingOutcome {
        switch self {
        case .authoritative, .concise: return .concise
        case .warm, .executive: return .composed
        case .persuasive: return .persuasive
        case .storytelling: return .spontaneous
        }
    }
}

struct CoachingProfile: Codable, Equatable {
    var speakingContext: SpeakingContext
    var primaryGoal: CoachingPriority
    var confidenceLevel: ConfidenceLevel
    var biggestChallenge: SpeakingChallenge
    var desiredOutcome: SpeakingOutcome
    /// The user's EFFECTIVE voice goal — always a concrete value so the many
    /// surfaces that tailor copy/persona to a voice never have to branch on nil.
    /// This is NOT proof the user chose it: a brand-new or tap-through profile
    /// carries the neutral default here. Ask `hasChosenVoice` / `chosenStyleGoal`
    /// to know whether the user actually picked, and gate "tailored vs generic"
    /// coaching on that — never assume this value was chosen.
    var speakingStyleGoal: SpeakingStyleGoal
    /// The voice the user EXPLICITLY chose (onboarding, or the in-chat goal
    /// card), or `nil` when they haven't chosen yet. The source of truth for
    /// "is the experience tailored to a real choice." Optional + decoded via
    /// `decodeIfPresent`, so profiles persisted before this field decode as nil
    /// and then back-fill from the (possibly-defaulted) `speakingStyleGoal` only
    /// when that legacy value was genuinely user-set. `nil` => coach stays
    /// generic and offers to set the voice rather than inventing one.
    var chosenStyleGoal: SpeakingStyleGoal?
    /// True once the user has actively chosen a voice. Every "tailor to the
    /// user's voice" decision should read THIS, not the always-populated
    /// `speakingStyleGoal`.
    var hasChosenVoice: Bool { chosenStyleGoal != nil }
    var styleReference: String
    var coachingBrief: String
    var motivationWhyNow: String
    var successVision: String
    /// AI-paraphrased, single-sentence rendering of the user's goal. Set once
    /// at onboarding by `GoalParaphraseService` (best-effort, never blocks).
    /// Read-only post-capture: raw inputs stay for export, the paraphrase is
    /// the sanitised version safe to surface in UI and notifications.
    var paraphrasedGoal: String?
    /// Points at the active `BigMoment` in `BigMomentStore`. Optional so
    /// existing persisted profiles (without this field) decode cleanly as nil.
    var bigMomentID: UUID?
    /// Optional secondary voice for a BLENDED goal — set only when the user
    /// explicitly chooses "Blend <old> + <new>" from the in-chat goal-change
    /// card (`AskNoumView.recordGoalChange`). `speakingStyleGoal` stays the
    /// primary; this is the secondary the coach also reads. `nil` means a
    /// single-voice goal (the overwhelming default). Optional + decoded via
    /// `decodeIfPresent` so every profile persisted before this field decodes
    /// cleanly as `nil` — mirrors `paraphrasedGoal` / `bigMomentID`.
    var secondaryStyleGoal: SpeakingStyleGoal?

    var isComplete: Bool { true }
    var personalGoalReference: String {
        let trimmedStyleReference = styleReference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedStyleReference.isEmpty {
            return trimmedStyleReference
        }

        return coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var whyNowReference: String {
        motivationWhyNow.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var successVisionReference: String {
        successVision.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum CodingKeys: String, CodingKey {
        case speakingContext
        case primaryGoal
        case confidenceLevel
        case biggestChallenge
        case desiredOutcome
        case speakingStyleGoal
        case styleReference
        case coachingBrief
        case motivationWhyNow
        case successVision
        case paraphrasedGoal
        case bigMomentID
        case secondaryStyleGoal
        case chosenStyleGoal
    }

    init(
        speakingContext: SpeakingContext,
        primaryGoal: CoachingPriority,
        confidenceLevel: ConfidenceLevel,
        biggestChallenge: SpeakingChallenge,
        desiredOutcome: SpeakingOutcome,
        speakingStyleGoal: SpeakingStyleGoal,
        styleReference: String,
        coachingBrief: String,
        motivationWhyNow: String,
        successVision: String,
        paraphrasedGoal: String? = nil,
        bigMomentID: UUID? = nil,
        secondaryStyleGoal: SpeakingStyleGoal? = nil,
        chosenStyleGoal: SpeakingStyleGoal? = nil
    ) {
        self.speakingContext = speakingContext
        self.primaryGoal = primaryGoal
        self.confidenceLevel = confidenceLevel
        self.biggestChallenge = biggestChallenge
        self.desiredOutcome = desiredOutcome
        self.speakingStyleGoal = speakingStyleGoal
        self.styleReference = styleReference
        self.coachingBrief = coachingBrief
        self.motivationWhyNow = motivationWhyNow
        self.successVision = successVision
        self.paraphrasedGoal = paraphrasedGoal
        self.bigMomentID = bigMomentID
        self.secondaryStyleGoal = secondaryStyleGoal
        self.chosenStyleGoal = chosenStyleGoal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speakingContext = try container.decode(SpeakingContext.self, forKey: .speakingContext)
        primaryGoal = try container.decode(CoachingPriority.self, forKey: .primaryGoal)
        confidenceLevel = try container.decode(ConfidenceLevel.self, forKey: .confidenceLevel)
        biggestChallenge = try container.decode(SpeakingChallenge.self, forKey: .biggestChallenge)
        desiredOutcome = try container.decode(SpeakingOutcome.self, forKey: .desiredOutcome)
        // The effective voice always has a concrete value. The neutral default
        // is `.concise` (least editorialising register) and is only ever read
        // when no voice was set — `hasChosenVoice` stays false in that case so
        // the default never reads as a real choice.
        let decodedStyle = try container.decodeIfPresent(SpeakingStyleGoal.self, forKey: .speakingStyleGoal)
        speakingStyleGoal = decodedStyle ?? .concise
        // `chosenStyleGoal` is the source of truth for "the user picked."
        // Distinguish three cases by KEY PRESENCE (not just decodeIfPresent,
        // which conflates absent with null):
        //  • key absent  → persisted before this field existed. A present
        //    `speakingStyleGoal` means the user completed the old onboarding
        //    (which always wrote a voice), so back-fill the choice from it;
        //    a fully-unset legacy profile stays nil (generic coach).
        //  • key present (value or null) → written by the current encoder, so
        //    take it verbatim — preserves a deliberate nil across a round-trip.
        if container.contains(.chosenStyleGoal) {
            chosenStyleGoal = try container.decodeIfPresent(SpeakingStyleGoal.self, forKey: .chosenStyleGoal)
        } else {
            chosenStyleGoal = decodedStyle
        }
        styleReference = try container.decodeIfPresent(String.self, forKey: .styleReference) ?? ""
        coachingBrief = try container.decodeIfPresent(String.self, forKey: .coachingBrief) ?? ""
        motivationWhyNow = try container.decodeIfPresent(String.self, forKey: .motivationWhyNow) ?? ""
        successVision = try container.decodeIfPresent(String.self, forKey: .successVision) ?? ""
        paraphrasedGoal = try container.decodeIfPresent(String.self, forKey: .paraphrasedGoal)
        bigMomentID = try container.decodeIfPresent(UUID.self, forKey: .bigMomentID)
        secondaryStyleGoal = try container.decodeIfPresent(SpeakingStyleGoal.self, forKey: .secondaryStyleGoal)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(speakingContext, forKey: .speakingContext)
        try container.encode(primaryGoal, forKey: .primaryGoal)
        try container.encode(confidenceLevel, forKey: .confidenceLevel)
        try container.encode(biggestChallenge, forKey: .biggestChallenge)
        try container.encode(desiredOutcome, forKey: .desiredOutcome)
        try container.encode(speakingStyleGoal, forKey: .speakingStyleGoal)
        try container.encode(styleReference, forKey: .styleReference)
        try container.encode(coachingBrief, forKey: .coachingBrief)
        try container.encode(motivationWhyNow, forKey: .motivationWhyNow)
        try container.encode(successVision, forKey: .successVision)
        try container.encodeIfPresent(paraphrasedGoal, forKey: .paraphrasedGoal)
        try container.encodeIfPresent(bigMomentID, forKey: .bigMomentID)
        try container.encodeIfPresent(secondaryStyleGoal, forKey: .secondaryStyleGoal)
        // ALWAYS write `chosenStyleGoal` (even when nil → JSON null) so the
        // decoder can tell "this profile was written by the current encoder and
        // deliberately has no chosen voice" (key present) from "persisted before
        // the field existed" (key absent → legacy back-fill). This is what makes
        // a nil choice survive a round-trip instead of being back-filled.
        try container.encode(chosenStyleGoal, forKey: .chosenStyleGoal)
    }
}

extension CoachingProfile {
    /// On-voice, single-sentence rendering of the user's goal — safe for any
    /// user-facing surface including lock-screen notifications, weekly digests,
    /// and result cards. Prefers the AI paraphrase set at onboarding by
    /// `GoalParaphraseService`; falls back to a deterministic template when
    /// no paraphrase has been written yet (no provider, network failure, or
    /// legacy profile).
    var displayableGoal: String {
        if let trimmed = paraphrasedGoal?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trimmed.isEmpty {
            return trimmed
        }
        let action = primaryGoal.title.lowercased()
        let style = speakingStyleGoal.coachingDescription
        return "You want to \(action) and \(style)."
    }

    /// The set of high-leverage skill areas for this profile's voice goal,
    /// blended across the primary and (when set) the secondary voice. For a
    /// single-voice profile this is exactly `speakingStyleGoal.alignedSkillAreas`
    /// — identical to the pre-blend read, so every existing consumer that reads
    /// the enum-level set directly keeps the same behaviour. For a BLENDED goal
    /// (the user tapped "Blend <old> + <new>" in chat) it is the union of both
    /// voices' aligned skills, so a blend re-weights the read toward both voices
    /// without erasing either — the secondary widens the leverage set rather than
    /// replacing the primary's. Consumers that want the blended view read this;
    /// the single-voice `SpeakingStyleGoal.alignedSkillAreas` is unchanged for
    /// the many call sites that operate on a bare voice with no profile.
    var blendedAlignedSkillAreas: Set<SkillArea> {
        guard let secondary = secondaryStyleGoal, secondary != speakingStyleGoal else {
            return speakingStyleGoal.alignedSkillAreas
        }
        return speakingStyleGoal.alignedSkillAreas.union(secondary.alignedSkillAreas)
    }

    // MARK: - Chosen-voice coaching copy (S2)
    //
    // Pure, deterministic helpers that turn the user's EXPLICIT voice choice
    // into coaching copy, so the generic Profile/Summary surfaces visibly
    // reflect what the user picked. SINGLE SOURCE OF TRUTH = `chosenStyleGoal`
    // (NOT the always-populated `speakingStyleGoal` default): a never-chosen
    // profile returns nil from both, and every caller keeps its existing
    // generic copy as the fallback — so an un-chosen profile stays neutral
    // (`CoachPersona.default`) instead of impersonating `.concise`.
    //
    // NO model call: no grounding gate, no locale gate, no numeric score
    // touched. The voice name comes from `CoachPersona.persona(for:).registerName`
    // and the aim from `SpeakingStyleGoal.coachingDescription`. A BLEND
    // (secondary set, and not equal to the primary) names both voices.

    /// Short uppercase-friendly register label for the chosen voice, e.g.
    /// "Authoritative register" — or "Authoritative + Warm register" for a
    /// blend. `nil` when the user has not chosen a voice, so the caller falls
    /// back to its existing generic eyebrow. Used by `CaseReviewCard`.
    var chosenVoiceRegisterLabel: String? {
        guard let chosen = chosenStyleGoal else { return nil }
        let primary = CoachPersona.persona(for: chosen).registerName
        if let secondary = secondaryStyleGoal, secondary != chosen {
            let secondaryName = CoachPersona.persona(for: secondary).registerName
            return "\(primary) + \(secondaryName) register"
        }
        return "\(primary) register"
    }

    /// A full lead sentence that anchors the coaching read in the user's
    /// chosen voice, CoachPersona-derived, e.g. "Coaching toward your
    /// Authoritative voice — sound steady, assured, and hard to ignore." For a
    /// blend it names both. `nil` when the user has not chosen a voice, so the
    /// Profile read keeps the existing generic `CoachingPlanner` string
    /// verbatim. No exclamations, no emoji — brand voice. Used to PREPEND the
    /// generic read on Profile, and to voice-shape the Summary empty-state line.
    var chosenVoiceCoachingLead: String? {
        guard let chosen = chosenStyleGoal else { return nil }
        let primaryName = CoachPersona.persona(for: chosen).registerName
        if let secondary = secondaryStyleGoal, secondary != chosen {
            let secondaryName = CoachPersona.persona(for: secondary).registerName
            return "Coaching toward your \(primaryName) voice, blended with \(secondaryName) — \(chosen.coachingDescription)."
        }
        return "Coaching toward your \(primaryName) voice — \(chosen.coachingDescription)."
    }

    var communicationNorthStar: String {
        let goalReference = personalGoalReference.isEmpty
            ? desiredOutcome.title.lowercased()
            : personalGoalReference
        let whyNowNote = whyNowReference.isEmpty ? "" : " It matters now because \(whyNowReference)."
        let successNote = successVisionReference.isEmpty ? "" : " If this works, they want \(successVisionReference)."
        return "The user signed up to \(primaryGoal.title.lowercased()) so they can \(goalReference).\(whyNowNote)\(successNote)"
    }

    var motivationalSummary: String {
        if !whyNowReference.isEmpty && !successVisionReference.isEmpty {
            return "Why now: \(whyNowReference)  Next payoff: \(successVisionReference)"
        }
        if !whyNowReference.isEmpty {
            return "Why now: \(whyNowReference)"
        }
        if !successVisionReference.isEmpty {
            return "What better would unlock: \(successVisionReference)"
        }
        return communicationNorthStar
    }

    var inConversationTrainingFocus: String {
        let priorityNote: String
        switch primaryGoal {
        case .reduceFillers:
            priorityNote = "Reward clean pauses, direct wording, and answers that do not lean on hesitation or filler."
        case .moreConcise:
            priorityNote = "Reward tight, relevant answers and penalize drift, over-explaining, or generic padding."
        case .thinkFaster:
            priorityNote = "Reward timely replies that still make sense under pressure, even if they stay simple."
        case .calmerDelivery:
            priorityNote = "Reward steady tone, calm pacing, and non-defensive replies under pressure."
        }

        let challengeNote: String
        switch biggestChallenge {
        case .fillerWords:
            challengeNote = "If the user starts hedging or padding, do not treat that as strong progress."
        case .rambling:
            challengeNote = "If the user becomes vague or rambly, let the interaction cool slightly until they tighten up."
        case .freezing:
            challengeNote = "If the user hesitates but recovers with something clear and real, count that as progress."
        case .rushing:
            challengeNote = "If the user gets sharp or rushed, let tension rise unless they slow themselves down."
        }

        let outcomeNote = "The long-term aim is for them to sound \(desiredOutcome.title.lowercased()) with a \(speakingStyleGoal.title.lowercased()) edge."
        return "\(priorityNote) \(challengeNote) \(outcomeNote)"
    }
}

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case none
    case openAI
    case deepSeek
    case gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Off"
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        case .gemini: return "Gemini"
        }
    }

    var model: String {
        switch self {
        case .none: return ""
        case .openAI: return "gpt-4o-mini"
        case .deepSeek: return "deepseek-chat"
        case .gemini: return "gemini-2.5-flash"
        }
    }

    var endpoint: URL? {
        switch self {
        case .none:
            return nil
        case .openAI:
            return URL(string: "https://api.openai.com/v1/chat/completions")
        case .deepSeek:
            return URL(string: "https://api.deepseek.com/chat/completions")
        case .gemini:
            return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        }
    }

    var environmentKey: String? {
        switch self {
        case .none: return nil
        case .openAI: return "OPENAI_API_KEY"
        case .deepSeek: return "DEEPSEEK_API_KEY"
        case .gemini: return "GEMINI_API_KEY"
        }
    }
}

struct AICoachFeedback: Codable, Equatable {
    let strengths: [String]
    let keyImprovement: String
    let suggestedDrill: String
    let revisedOpening: String
}

enum IMConversationScenario: String, CaseIterable, Codable, Identifiable {
    case socialCatchUp
    case workUpdate
    case difficultConversation
    case networking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .socialCatchUp: return "Social Catch-Up"
        case .workUpdate: return "Work Update"
        case .difficultConversation: return "Difficult Conversation"
        case .networking: return "Networking"
        }
    }

    var summary: String {
        switch self {
        case .socialCatchUp:
            return "Keep a natural chat moving without rambling or sounding flat."
        case .workUpdate:
            return "Give a useful update that sounds clear, steady, and professional."
        case .difficultConversation:
            return "Handle pressure, pushback, or awkwardness without losing composure."
        case .networking:
            return "Build rapport quickly and keep the conversation warm but intentional."
        }
    }

    var personaName: String {
        switch self {
        case .socialCatchUp: return "Maya"
        case .workUpdate: return "Jordan"
        case .difficultConversation: return "Sam"
        case .networking: return "Alex"
        }
    }

    var personaRole: String {
        switch self {
        case .socialCatchUp: return "friend"
        case .workUpdate: return "coworker"
        case .difficultConversation: return "teammate"
        case .networking: return "new connection"
        }
    }

    var stakes: String {
        switch self {
        case .socialCatchUp: return "low stakes, personal"
        case .workUpdate: return "light professional pressure"
        case .difficultConversation: return "mild tension and emotional risk"
        case .networking: return "social-professional opportunity"
        }
    }

    var currentMood: String {
        switch self {
        case .socialCatchUp: return "curious and relaxed"
        case .workUpdate: return "slightly rushed but open"
        case .difficultConversation: return "tense, guarded, and looking for clarity"
        case .networking: return "friendly, alert, and evaluating the connection"
        }
    }

    var conversationGoal: String {
        switch self {
        case .socialCatchUp: return "keep the chat flowing and feel genuinely interested"
        case .workUpdate: return "understand the update quickly and test whether it is clear"
        case .difficultConversation: return "see whether the speaker can stay calm and direct under pressure"
        case .networking: return "find out whether the speaker is engaging, clear, and worth talking to longer"
        }
    }

    var frictionStyle: String {
        switch self {
        case .socialCatchUp: return "light follow-up questions"
        case .workUpdate: return "asks for the headline and practical detail"
        case .difficultConversation: return "pushes back a little and asks for clarity"
        case .networking: return "tests warmth, clarity, and curiosity"
        }
    }

    var coachingFocus: String {
        switch self {
        case .socialCatchUp: return "sound natural without drifting or going flat"
        case .workUpdate: return "be clear, concise, and easy to follow"
        case .difficultConversation: return "stay composed while being honest and direct"
        case .networking: return "balance warmth with intention and specificity"
        }
    }

    var openingLine: String {
        switch self {
        case .socialCatchUp:
            return "Hey, long time. What’s been going on with you lately?"
        case .workUpdate:
            return "Quick one before the meeting. What’s the headline on your side?"
        case .difficultConversation:
            return "Can we talk about earlier? It didn’t sit right with me."
        case .networking:
            return "Good to meet you. What kind of work are you focused on?"
        }
    }

    var contextIntegrationStyle: IMContextIntegrationStyle {
        switch self {
        case .socialCatchUp:
            return .proactiveSmallTalk
        case .workUpdate:
            return .taskFirst
        case .difficultConversation:
            return .pressureFirst
        case .networking:
            return .situationalBlend
        }
    }

    var currentEventLens: String {
        switch self {
        case .socialCatchUp:
            return "light cultural or local talking points that make a catch-up feel current"
        case .workUpdate:
            return "work-relevant timing, workplace rhythm, or a headline that affects priorities"
        case .difficultConversation:
            return "the immediate practical pressure around the issue, not broad news unless it directly matters"
        case .networking:
            return "industry, event, or city-level context that makes the interaction feel current and grounded"
        }
    }

    var contextUsageRule: String {
        switch self {
        case .socialCatchUp:
            return "Use light small talk naturally if the weather, time of day, or a current event would plausibly come up between friends."
        case .workUpdate:
            return "Open efficiently. You can reference timing, meetings, workload, or a relevant headline, but do not linger in small talk."
        case .difficultConversation:
            return "Skip small talk unless it would realistically soften the opening by a sentence. The NPC should stay focused on the issue."
        case .networking:
            return "Use context as an icebreaker only if it improves rapport quickly, such as event atmosphere, city energy, or a timely topic."
        }
    }

    func relevantContextEnvelope(from context: IMSessionContext, relationship: IMRelationshipProfile?) -> IMRelevantContextEnvelope {
        let regionLabel = context.regionLabel ?? "the user's region"
        let worldContext = context.majorEventsSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        let weatherContext = context.weatherSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        let smallTalkEligible: Bool
        let openingGuidance: String

        switch contextIntegrationStyle {
        case .proactiveSmallTalk:
            smallTalkEligible = true
            openingGuidance = "A natural opener can briefly touch the moment before moving into the real catch-up."
        case .situationalBlend:
            smallTalkEligible = true
            openingGuidance = "Open with rapport first, then pivot into a specific question or observation."
        case .taskFirst:
            smallTalkEligible = false
            openingGuidance = "Lead with the practical point. Context should only sharpen relevance, not delay the ask."
        case .pressureFirst:
            smallTalkEligible = false
            openingGuidance = "Open directly from the tension. Context is only useful if it makes the pressure feel more realistic."
        }

        var relevantLines = [
            "Use context in a way that fits \(title.lowercased()) and the relationship stage.",
            contextUsageRule,
            "Current-event lens: \(currentEventLens).",
            "Primary regional frame: \(regionLabel)."
        ]

        if let weatherContext, smallTalkEligible {
            relevantLines.append("Weather context worth using only if natural: \(weatherContext)")
        }

        if let worldContext {
            relevantLines.append("Current event context available if it fits this scenario: \(worldContext)")
        }

        if let socialPulse = context.socialPulse?.trimmingCharacters(in: .whitespacesAndNewlines),
           !socialPulse.isEmpty {
            relevantLines.append("Use this ambient social cue only if it helps the opening sound human: \(socialPulse)")
        }

        if let relationship {
            relevantLines.append("Relationship reminder: \(relationship.relationshipStage), with continuity note: \(relationship.continuitySummary)")
        }

        return IMRelevantContextEnvelope(
            shouldUseSmallTalk: smallTalkEligible,
            openingGuidance: openingGuidance,
            relevantLines: relevantLines
        )
    }
}

enum IMContextIntegrationStyle {
    case proactiveSmallTalk
    case situationalBlend
    case taskFirst
    case pressureFirst
}

struct IMRelevantContextEnvelope {
    let shouldUseSmallTalk: Bool
    let openingGuidance: String
    let relevantLines: [String]
}

struct IMRelationshipArcTemplate {
    let id: String
    let title: String
    let topicMatches: [String]
    let stages: [String]
    let stageGuidance: [String]
}

struct IMPersonaToleranceProfile: Codable, Equatable {
    let patience: Int
    let forgiveness: Int
    let directness: Int
    let sensitivity: Int
    let conflictReadiness: Int
    let closureLikelihood: Int

    var summary: String {
        "Patience \(patience)/10, forgiveness \(forgiveness)/10, directness \(directness)/10, sensitivity \(sensitivity)/10, conflict readiness \(conflictReadiness)/10, closure likelihood \(closureLikelihood)/10."
    }
}

enum IMRelationshipMilestone: String, Codable, Equatable {
    case guarded
    case openingUp
    case steady
    case trusted
    case fractured
    case recovering

    var title: String {
        switch self {
        case .guarded: return "Guarded"
        case .openingUp: return "Opening Up"
        case .steady: return "Steady"
        case .trusted: return "Trusted"
        case .fractured: return "Fractured"
        case .recovering: return "Recovering"
        }
    }

    var description: String {
        switch self {
        case .guarded:
            return "The persona is cautious and watches for consistency before relaxing."
        case .openingUp:
            return "The persona is warming up and becoming easier to talk to."
        case .steady:
            return "The relationship feels stable but still responsive to tone and effort."
        case .trusted:
            return "The persona now gives more benefit of the doubt and opens more naturally."
        case .fractured:
            return "Recent damage is shaping the relationship and future chats start colder."
        case .recovering:
            return "The relationship is improving again, but trust is still being rebuilt."
        }
    }

    var npcBehaviorGuidance: String {
        switch self {
        case .guarded:
            return "Stay a little measured. Make the user earn ease through steadiness, relevance, and basic social calibration."
        case .openingUp:
            return "Show a little more warmth and openness, but keep testing whether the user can sustain the tone."
        case .steady:
            return "Act comfortable but not automatic. A good exchange can deepen trust, and a sloppy one can still flatten the energy."
        case .trusted:
            return "Open more naturally, allow a touch more personality, and reward nuance, but still react honestly if the user slips."
        case .fractured:
            return "Start colder and more cautious. Do not give easy warmth back. The user should feel that repair needs to be earned."
        case .recovering:
            return "Be tentatively open. Allow repair, but keep a trace of caution until the user proves consistency again."
        }
    }

    var nextMilestoneTitle: String? {
        switch self {
        case .guarded: return IMRelationshipMilestone.openingUp.title
        case .openingUp: return IMRelationshipMilestone.steady.title
        case .steady: return IMRelationshipMilestone.trusted.title
        case .trusted: return nil
        case .fractured: return IMRelationshipMilestone.recovering.title
        case .recovering: return IMRelationshipMilestone.steady.title
        }
    }
}

extension IMConversationScenario {
    var relationshipArcTemplates: [IMRelationshipArcTemplate] {
        switch self {
        case .socialCatchUp:
            return [
                IMRelationshipArcTemplate(
                    id: "social_reset",
                    title: "Rebuilding the Rhythm",
                    topicMatches: ["weekend", "stress", "work", "home"],
                    stages: ["Careful Reconnect", "Shared Updates", "Easy Flow"],
                    stageGuidance: [
                        "The persona is checking whether the catch-up will feel strained or easy.",
                        "The persona is open to swapping more real-life updates if the user stays engaged.",
                        "The persona expects a genuinely natural flow and may volunteer more without being dragged there."
                    ]
                ),
                IMRelationshipArcTemplate(
                    id: "social_life_shift",
                    title: "Life Update Thread",
                    topicMatches: ["dating", "relationship", "move", "travel", "family"],
                    stages: ["Hinted Shift", "More Detail", "Ongoing Thread"],
                    stageGuidance: [
                        "There is a personal life thread in the background, but it should only come up lightly.",
                        "The persona can share a little more if the user shows genuine care and specificity.",
                        "This has become an ongoing part of the relationship and can be referenced naturally."
                    ]
                )
            ]
        case .workUpdate:
            return [
                IMRelationshipArcTemplate(
                    id: "work_pressure",
                    title: "Pressure Cycle",
                    topicMatches: ["deadline", "project", "launch", "client", "budget"],
                    stages: ["Pressure Building", "Need for Clarity", "Trusted Under Load"],
                    stageGuidance: [
                        "Work pressure is present, so the persona is listening for whether the user sounds grounded or messy.",
                        "The persona now expects sharper headlines and more credible practical detail.",
                        "The persona is beginning to trust the user under pressure and responds more efficiently."
                    ]
                ),
                IMRelationshipArcTemplate(
                    id: "manager_read",
                    title: "Professional Read",
                    topicMatches: ["manager", "team", "meeting", "hiring"],
                    stages: ["Being Assessed", "Reliability Test", "Professional Confidence"],
                    stageGuidance: [
                        "The persona is still forming a read on the user's professional reliability.",
                        "The persona is testing whether the user can stay clear, useful, and low-drag consistently.",
                        "The user is starting to sound like someone the persona can rely on quickly."
                    ]
                )
            ]
        case .difficultConversation:
            return [
                IMRelationshipArcTemplate(
                    id: "trust_repair",
                    title: "Trust Repair",
                    topicMatches: ["trust", "respect", "support", "communication"],
                    stages: ["Damage Acknowledged", "Repair Attempt", "Cautious Stability"],
                    stageGuidance: [
                        "Trust damage is alive in the conversation, so defensiveness will cost the user quickly.",
                        "A repair attempt is possible, but the persona is testing whether it sounds real.",
                        "The relationship is stabilising, but the persona still notices lapses fast."
                    ]
                ),
                IMRelationshipArcTemplate(
                    id: "ownership_conflict",
                    title: "Ownership Tension",
                    topicMatches: ["deadline", "ownership", "fair", "frustrat", "pressure"],
                    stages: ["Underlying Friction", "Direct Pushback", "Clearer Ground Rules"],
                    stageGuidance: [
                        "Friction is present beneath the surface and can be triggered by vagueness or defensiveness.",
                        "The persona is willing to push back directly if the user avoids responsibility.",
                        "The conversation can become more constructive if the user stays direct and composed."
                    ]
                )
            ]
        case .networking:
            return [
                IMRelationshipArcTemplate(
                    id: "networking_interest",
                    title: "Mutual Interest",
                    topicMatches: ["startup", "product", "career", "market", "design", "engineer"],
                    stages: ["Polite Curiosity", "Real Interest", "Worth Following Up"],
                    stageGuidance: [
                        "The persona is still deciding whether the interaction is just polite or actually interesting.",
                        "The persona sees potential and is more willing to go beyond surface-level questions.",
                        "The connection now feels follow-up worthy if the user keeps sounding sharp and human."
                    ]
                ),
                IMRelationshipArcTemplate(
                    id: "event_followup",
                    title: "Event Momentum",
                    topicMatches: ["event", "collaborat", "founder"],
                    stages: ["Post-Event Energy", "Specific Opportunity", "Real Connection"],
                    stageGuidance: [
                        "The interaction still has event-style social energy and needs a memorable hook.",
                        "There is now a more specific opening for collaboration or follow-up.",
                        "The persona sees the user as more than a forgettable event contact."
                    ]
                )
            ]
        }
    }

    var topicCandidates: [(match: String, label: String)] {
        switch self {
        case .socialCatchUp:
            return [
                ("work", "work stuff"),
                ("job", "job changes"),
                ("weekend", "weekend plans"),
                ("trip", "travel plans"),
                ("travel", "travel plans"),
                ("family", "family life"),
                ("move", "moving plans"),
                ("flat", "home situation"),
                ("house", "home situation"),
                ("dating", "dating life"),
                ("relationship", "relationship life"),
                ("stress", "stress levels"),
                ("gym", "health routine")
            ]
        case .workUpdate:
            return [
                ("project", "the project"),
                ("deadline", "deadlines"),
                ("client", "the client work"),
                ("meeting", "meeting pressure"),
                ("team", "team dynamics"),
                ("manager", "manager expectations"),
                ("budget", "budget pressure"),
                ("launch", "the launch"),
                ("hiring", "hiring plans")
            ]
        case .difficultConversation:
            return [
                ("trust", "trust issues"),
                ("respect", "respect"),
                ("support", "support"),
                ("fair", "fairness"),
                ("communication", "communication"),
                ("deadline", "missed expectations"),
                ("ownership", "ownership"),
                ("frustrat", "frustration"),
                ("pressure", "pressure")
            ]
        case .networking:
            return [
                ("startup", "startup work"),
                ("founder", "founder role"),
                ("product", "product work"),
                ("career", "career direction"),
                ("market", "market trends"),
                ("event", "the event"),
                ("collaborat", "collaboration ideas"),
                ("design", "design work"),
                ("engineer", "engineering work")
            ]
        }
    }

    var toleranceProfile: IMPersonaToleranceProfile {
        switch self {
        case .socialCatchUp:
            return IMPersonaToleranceProfile(
                patience: 7,
                forgiveness: 8,
                directness: 5,
                sensitivity: 7,
                conflictReadiness: 3,
                closureLikelihood: 5
            )
        case .workUpdate:
            return IMPersonaToleranceProfile(
                patience: 5,
                forgiveness: 4,
                directness: 8,
                sensitivity: 5,
                conflictReadiness: 6,
                closureLikelihood: 6
            )
        case .difficultConversation:
            return IMPersonaToleranceProfile(
                patience: 3,
                forgiveness: 3,
                directness: 8,
                sensitivity: 8,
                conflictReadiness: 9,
                closureLikelihood: 8
            )
        case .networking:
            return IMPersonaToleranceProfile(
                patience: 5,
                forgiveness: 4,
                directness: 6,
                sensitivity: 6,
                conflictReadiness: 4,
                closureLikelihood: 7
            )
        }
    }

    func unlockTeaser(for milestone: IMRelationshipMilestone) -> String {
        switch (self, milestone) {
        case (.socialCatchUp, .guarded):
            return "\(personaName) may start volunteering more of her own life once the chat stops feeling cautious."
        case (.socialCatchUp, .openingUp), (.socialCatchUp, .steady):
            return "\(personaName) is close to treating you like a genuinely easy person to text, not someone she has to read carefully."
        case (.socialCatchUp, .trusted):
            return "\(personaName) now opens warmer and with more personal follow-ups, which is the real reward state here."
        case (.socialCatchUp, .fractured), (.socialCatchUp, .recovering):
            return "Repairing this gets you back to warmer, more natural catch-ups instead of concerned distance."

        case (.workUpdate, .guarded):
            return "\(personaName) will start giving less guarded, more useful work context when your updates feel sharper."
        case (.workUpdate, .openingUp), (.workUpdate, .steady):
            return "\(personaName) is close to trusting your headlines quickly, which makes the exchange feel more senior and efficient."
        case (.workUpdate, .trusted):
            return "\(personaName) now gives you more benefit of the doubt and responds as if you are already reliable under pressure."
        case (.workUpdate, .fractured), (.workUpdate, .recovering):
            return "Repair here means getting back to clean professional trust instead of scrutiny."

        case (.difficultConversation, .guarded):
            return "\(personaName) may stop bracing for defensiveness if you keep showing calm honesty."
        case (.difficultConversation, .openingUp), (.difficultConversation, .steady):
            return "\(personaName) is close to dropping some of the edge and treating the conversation as safer."
        case (.difficultConversation, .trusted):
            return "\(personaName) now expects direct honesty rather than conflict, which is a major unlock in this scenario."
        case (.difficultConversation, .fractured), (.difficultConversation, .recovering):
            return "Repair here unlocks less defensive, less emotionally expensive conversations next time."

        case (.networking, .guarded):
            return "\(personaName) may start engaging beyond polite small talk once you feel sharper and more memorable."
        case (.networking, .openingUp), (.networking, .steady):
            return "\(personaName) is close to seeing you as someone worth continuing the connection with after this chat."
        case (.networking, .trusted):
            return "\(personaName) now treats you more like a real connection than a disposable networking interaction."
        case (.networking, .fractured), (.networking, .recovering):
            return "Repair here gets you back to actual rapport instead of awkward professional distance."
        }
    }

    func topicUnlockGuidance(for milestone: IMRelationshipMilestone) -> String {
        switch milestone {
        case .guarded:
            return "Do not force a callback yet. Keep the opener grounded in the current moment unless a prior topic is the cleanest way in."
        case .openingUp:
            return "A light callback to one remembered topic is allowed if it makes the conversation feel more human."
        case .steady:
            return "You can reuse one remembered thread to make the interaction feel continuous, but keep it natural and brief."
        case .trusted:
            return "Lean into continuity. Natural callbacks to shared threads should make the exchange feel like an ongoing relationship."
        case .fractured:
            return "If using a callback, let it carry tension or distance rather than warmth. Do not pretend the relationship reset."
        case .recovering:
            return "Use callbacks carefully. They should feel like cautious repair, not instant closeness."
        }
    }
}

enum IMTargetTone: String, CaseIterable, Codable, Identifiable {
    case confident
    case warm
    case concise
    case assertive
    case calm
    case professional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confident: return "Confident"
        case .warm: return "Warm"
        case .concise: return "Concise"
        case .assertive: return "Assertive"
        case .calm: return "Calm"
        case .professional: return "Professional"
        }
    }

    var coachingPrompt: String {
        switch self {
        case .confident: return "sound assured without over-explaining"
        case .warm: return "sound human, open, and easy to talk to"
        case .concise: return "get to the point quickly while still sounding natural"
        case .assertive: return "be direct and clear without sounding aggressive"
        case .calm: return "sound steady and composed under pressure"
        case .professional: return "sound polished, clear, and workplace-ready"
        }
    }
}

enum IMConversationSpeaker: String, Codable {
    case user
    case npc
}

struct IMConversationTurn: Identifiable, Codable, Equatable {
    let id: UUID
    let speaker: IMConversationSpeaker
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), speaker: IMConversationSpeaker, text: String, createdAt: Date = Date()) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.createdAt = createdAt
    }
}

struct IMConversationSetup: Codable, Equatable {
    let scenario: IMConversationScenario
    let targetTone: IMTargetTone
}

struct IMConversationState: Codable, Equatable {
    let trust: Int
    let engagement: Int
    let tension: Int
    let beat: String

    static let starting = IMConversationState(
        trust: 5,
        engagement: 5,
        tension: 4,
        beat: "The conversation has just opened."
    )

    var normalizedTrust: Int { max(1, min(10, trust)) }
    var normalizedEngagement: Int { max(1, min(10, engagement)) }
    var normalizedTension: Int { max(1, min(10, tension)) }
}

enum IMTurnStateBalancer {
    static func balanced(
        current: IMConversationState,
        proposed: IMConversationState,
        signal: IMUserMessageSignal?,
        isOpening: Bool
    ) -> IMConversationState {
        let hostility = signal?.hostilityScore ?? 0
        let disengagement = signal?.disengagementScore ?? 0
        let warmth = signal?.warmthScore ?? 0
        let reciprocity = signal?.reciprocityScore ?? 0
        let specificity = signal?.specificityScore ?? 0

        let positiveTrustCap: Int
        if isOpening {
            positiveTrustCap = 1
        } else if warmth >= 5 && reciprocity >= 4 && specificity >= 4 {
            positiveTrustCap = 2
        } else {
            positiveTrustCap = 1
        }

        let negativeTrustCap = hostility >= 7 || disengagement >= 8 ? 4 : 2
        let positiveEngagementCap = isOpening ? 1 : 2
        let negativeEngagementCap = disengagement >= 7 ? 4 : 2
        let positiveTensionCap = hostility >= 6 ? 3 : 2
        let negativeTensionCap = warmth >= 5 && hostility == 0 ? 2 : 1

        return IMConversationState(
            trust: bounded(
                current.normalizedTrust,
                proposed.normalizedTrust,
                riseCap: positiveTrustCap,
                dropCap: negativeTrustCap
            ),
            engagement: bounded(
                current.normalizedEngagement,
                proposed.normalizedEngagement,
                riseCap: positiveEngagementCap,
                dropCap: negativeEngagementCap
            ),
            tension: bounded(
                current.normalizedTension,
                proposed.normalizedTension,
                riseCap: positiveTensionCap,
                dropCap: negativeTensionCap
            ),
            beat: proposed.beat
        )
    }

    private static func bounded(_ current: Int, _ proposed: Int, riseCap: Int, dropCap: Int) -> Int {
        if proposed > current {
            return min(10, current + min(riseCap, proposed - current))
        }
        if proposed < current {
            return max(1, current - min(dropCap, current - proposed))
        }
        return current
    }
}

enum IMToneMatcher {
    static func score(for tone: IMTargetTone, transcript: String) -> Int {
        let text = ToneText(transcript)
        guard text.hasWords else { return 5 }

        switch tone {
        case .confident:
            return phraseScore(
                text: text,
                positive: [
                    "i can", "i will", "i know", "i recommend", "my view",
                    "i am confident", "i'm confident", "i led", "i built",
                    "i handled", "the result"
                ],
                negative: [
                    "i think", "maybe", "kind of", "sort of", "not sure",
                    "i guess", "probably", "hopefully"
                ]
            )
        case .warm:
            return phraseScore(
                text: text,
                positive: [
                    "thanks", "thank you", "appreciate", "glad", "happy",
                    "understand", "hear you", "curious", "love", "good to"
                ],
                negative: [
                    "whatever", "fine", "obviously", "as i said", "not my problem",
                    "you need to"
                ]
            )
        case .concise:
            return conciseScore(text)
        case .assertive:
            return phraseScore(
                text: text,
                positive: [
                    "i need", "i want", "i recommend", "i will", "i am going to",
                    "i'm going to", "my boundary", "the decision", "i cannot",
                    "i can't", "i can", "we need", "let's"
                ],
                negative: [
                    "sorry", "maybe", "if that is okay", "i guess", "just",
                    "i do not know", "i don't know", "whatever", "you always",
                    "you never"
                ]
            )
        case .calm:
            return phraseScore(
                text: text,
                positive: [
                    "steady", "slow down", "take a breath", "pause",
                    "understand", "hear you", "one step", "walk through"
                ],
                negative: [
                    "just", "sorry", "panic", "angry", "frustrated", "hate",
                    "whatever", "you always", "you never", "urgent", "asap"
                ]
            )
        case .professional:
            return phraseScore(
                text: text,
                positive: [
                    "next steps", "follow up", "align", "recommend", "timeline",
                    "priority", "proposal", "decision", "scope", "clarify"
                ],
                negative: [
                    "like", "literally", "kinda", "sort of", "whatever",
                    "lol", "omg", "fuck", "shit"
                ]
            )
        }
    }

    static func matchesActualTone(targetTone: IMTargetTone, actualTone: String) -> Bool {
        let text = ToneText(actualTone)
        guard text.hasWords else { return false }

        let aliases = actualToneAliases(for: targetTone)
        guard aliases.contains(where: { text.contains($0) }) else { return false }
        guard !aliases.contains(where: { aliasIsNegated($0, in: text) }) else { return false }

        return !blockingActualToneDescriptors(for: targetTone).contains { text.contains($0) }
    }

    private static func phraseScore(text: ToneText, positive: [String], negative: [String]) -> Int {
        let positiveHits = positive.filter { text.contains($0) }.count
        let negativeHits = negative.filter { text.contains($0) }.count
        return clamp(7 + min(2, positiveHits) - min(3, negativeHits))
    }

    private static func conciseScore(_ text: ToneText) -> Int {
        let base: Int
        switch text.wordCount {
        case 0:
            return 5
        case ...35:
            base = 8
        case 36...55:
            base = 7
        case 56...85:
            base = 6
        default:
            base = 5
        }

        let structureHits = [
            "bottom line", "in short", "first", "second", "the point",
            "my recommendation"
        ].filter { text.contains($0) }.count
        let rambleHits = [
            "basically", "kind of", "sort of", "i guess", "i mean",
            "to be honest", "long story short"
        ].filter { text.contains($0) }.count

        return clamp(base + min(1, structureHits) - min(2, rambleHits))
    }

    private static func actualToneAliases(for tone: IMTargetTone) -> [String] {
        switch tone {
        case .confident:
            return ["confident", "assured", "self assured", "certain", "decisive", "convincing"]
        case .warm:
            return ["warm", "friendly", "open", "human", "collaborative", "approachable", "appreciative", "empathetic"]
        case .concise:
            return ["concise", "brief", "focused", "tight", "to the point", "succinct"]
        case .assertive:
            return ["assertive", "firm", "direct", "clear boundary", "decisive"]
        case .calm:
            return ["calm", "steady", "composed", "measured", "grounded", "patient", "settled"]
        case .professional:
            return ["professional", "polished", "structured", "workplace ready", "work ready", "businesslike"]
        }
    }

    private static func blockingActualToneDescriptors(for tone: IMTargetTone) -> [String] {
        switch tone {
        case .confident:
            return ["shaky", "uncertain", "hesitant", "tentative", "guarded", "nervous"]
        case .warm:
            return ["cold", "dismissive", "distant", "flat", "transactional"]
        case .concise:
            return ["rambling", "wordy", "meandering", "overexplained", "over explaining"]
        case .assertive:
            return ["soft", "passive", "apologetic", "aggressive", "hostile"]
        case .calm:
            return ["tense", "rushed", "frantic", "agitated", "defensive", "sharp"]
        case .professional:
            return ["casual", "scattered", "vague", "messy", "sloppy", "informal", "unprofessional"]
        }
    }

    private static func aliasIsNegated(_ alias: String, in text: ToneText) -> Bool {
        [
            "not", "not very", "not quite", "less", "barely",
            "without", "missing", "lacks", "needs more", "too", "overly"
        ].contains { prefix in
            text.contains("\(prefix) \(alias)")
        }
    }

    private static func clamp(_ value: Int) -> Int {
        min(10, max(1, value))
    }

    private struct ToneText {
        let words: [String]
        let normalized: String

        init(_ raw: String) {
            let folded = raw
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            words = folded
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
            normalized = words.joined(separator: " ")
        }

        var hasWords: Bool { !words.isEmpty }
        var wordCount: Int { words.count }

        func contains(_ phrase: String) -> Bool {
            let phraseWords = phrase
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
            guard !phraseWords.isEmpty else { return false }
            if phraseWords.count == 1 {
                return words.contains(phraseWords[0])
            }
            return normalized.contains(phraseWords.joined(separator: " "))
        }
    }
}

struct IMUserMessageSignal: Equatable {
    let hostilityScore: Int
    let warmthScore: Int
    let reciprocityScore: Int
    let disengagementScore: Int
    let specificityScore: Int
    let adjustedState: IMConversationState
    let shouldForceWrapUp: Bool
    let summary: String
}

enum IMUserMessageAnalyzer {
    static func analyze(
        text: String,
        currentState: IMConversationState,
        scenario: IMConversationScenario,
        relationship: IMRelationshipProfile?
    ) -> IMUserMessageSignal {
        let tolerance = scenario.toleranceProfile
        let normalized = text.lowercased()
        let hostilityScore = hostilityScore(in: normalized)
        let disengagementScore = disengagementScore(in: normalized)
        let warmthScore = warmthScore(in: normalized)
        let reciprocityScore = reciprocityScore(in: normalized)
        let specificityScore = specificityScore(in: normalized)

        let hostilityMultiplier = max(1.0, Double(tolerance.sensitivity + tolerance.closureLikelihood) / 12.0)
        let forgivenessBuffer = max(0.6, Double(tolerance.forgiveness + tolerance.patience) / 18.0)
        let trustDrop = min(
            6,
            Int(round((Double(hostilityScore) / 2.0 + Double(disengagementScore) / 3.2) * hostilityMultiplier / forgivenessBuffer))
        )
        let engagementDrop = min(
            5,
            Int(round((Double(max(0, disengagementScore / 2) + (specificityScore <= 1 ? 1 : 0))) * Double(11 - tolerance.patience) / 7.0))
        )
        let tensionRise = min(
            6,
            Int(round((Double(hostilityScore) / 2.0 + Double(max(1, disengagementScore / 4))) * Double(tolerance.sensitivity + tolerance.conflictReadiness) / 10.0))
        )

        let trustBoost = hostilityScore == 0
            ? max(0, Int(round(Double(warmthScore / 3 + reciprocityScore / 4 + max(0, specificityScore - 2) / 2) * Double(tolerance.forgiveness) / 6.0)))
            : 0
        let engagementBoost = hostilityScore == 0
            ? max(0, Int(round(Double(reciprocityScore / 3 + specificityScore / 3) * Double(tolerance.patience + 3) / 8.0)))
            : 0
        let tensionEase = hostilityScore == 0
            ? max(0, Int(round(Double(warmthScore / 4 + reciprocityScore / 4) * Double(tolerance.forgiveness) / 7.0)))
            : 0

        let adjustedState = IMConversationState(
            trust: clamp(currentState.normalizedTrust - trustDrop + trustBoost),
            engagement: clamp(currentState.normalizedEngagement - engagementDrop + engagementBoost),
            tension: clamp(currentState.normalizedTension + tensionRise - tensionEase),
            beat: beatSummary(
                hostilityScore: hostilityScore,
                disengagementScore: disengagementScore,
                warmthScore: warmthScore,
                scenario: scenario,
                relationship: relationship
            )
        )

        let shouldForceWrapUp =
            hostilityScore >= max(6, 11 - tolerance.closureLikelihood) ||
            disengagementScore >= max(7, 12 - tolerance.patience)
        let summary = summaryLine(
            hostilityScore: hostilityScore,
            warmthScore: warmthScore,
            reciprocityScore: reciprocityScore,
            disengagementScore: disengagementScore,
            specificityScore: specificityScore,
            shouldForceWrapUp: shouldForceWrapUp,
            tolerance: tolerance
        )

        return IMUserMessageSignal(
            hostilityScore: hostilityScore,
            warmthScore: warmthScore,
            reciprocityScore: reciprocityScore,
            disengagementScore: disengagementScore,
            specificityScore: specificityScore,
            adjustedState: adjustedState,
            shouldForceWrapUp: shouldForceWrapUp,
            summary: summary
        )
    }

    private static func hostilityScore(in text: String) -> Int {
        let severePhrases = [
            "fuck off", "leave me alone", "go away", "shut up",
            "i don't want to speak to you", "don't want to speak to you",
            "don't text me", "stop messaging me", "piss off"
        ]
        let hostileWords = ["fuck", "idiot", "stupid", "annoying", "hate", "loser", "moron"]
        var score = 0
        if severePhrases.contains(where: text.contains) { score += 9 }
        score += hostileWords.reduce(into: 0) { partial, word in
            if text.contains(word) { partial += 3 }
        }
        if text.contains("whatever") { score += 2 }
        return min(10, score)
    }

    private static func disengagementScore(in text: String) -> Int {
        let strong = [
            "i don't want to speak to you", "don't want to speak to you",
            "leave me alone", "stop messaging me", "go away",
            "not now", "can't be bothered"
        ]
        let mild = ["busy", "later", "can't talk", "not in the mood", "not up for this"]
        var score = 0
        if strong.contains(where: text.contains) { score += 9 }
        if mild.contains(where: text.contains) { score += 4 }
        if text.split(whereSeparator: \.isWhitespace).count <= 3 { score += 2 }
        return min(10, score)
    }

    private static func warmthScore(in text: String) -> Int {
        let markers = ["thanks", "appreciate", "sorry", "hope you're okay", "how are you", "glad", "good to hear"]
        return min(10, markers.reduce(into: 0) { partial, marker in
            if text.contains(marker) { partial += 3 }
        })
    }

    private static func reciprocityScore(in text: String) -> Int {
        var score = 0
        if text.contains("?") { score += 4 }
        let markers = ["you", "your", "how are you", "what about you", "how's", "how is"]
        score += markers.reduce(into: 0) { partial, marker in
            if text.contains(marker) { partial += 2 }
        }
        return min(10, score)
    }

    private static func specificityScore(in text: String) -> Int {
        let words = text.split(whereSeparator: \.isWhitespace).count
        if words <= 2 { return 0 }
        if words <= 5 { return 2 }
        if words <= 12 { return 5 }
        if words <= 24 { return 7 }
        return 6
    }

    private static func beatSummary(
        hostilityScore: Int,
        disengagementScore: Int,
        warmthScore: Int,
        scenario: IMConversationScenario,
        relationship: IMRelationshipProfile?
    ) -> String {
        let tolerance = scenario.toleranceProfile
        if hostilityScore >= 8 || disengagementScore >= 9 {
            if tolerance.forgiveness >= 7 {
                return "\(scenario.personaName) is hurt by the rejection and trying to work out if something deeper is wrong before backing off."
            }
            return "\(scenario.personaName) has just been hit with blunt rejection and is deciding whether to pull back completely."
        }
        if hostilityScore >= 5 {
            if tolerance.conflictReadiness >= 7 {
                return "\(scenario.personaName) reads the hostility instantly and is ready to push back or shut the exchange down."
            }
            return "\(scenario.personaName) feels the conversation turn sharp and defensive."
        }
        if warmthScore >= 5 {
            return "\(scenario.personaName) feels a little more at ease and open to continuing."
        }
        if let relationship, relationship.normalizedTrustBaseline <= 4 {
            return "\(scenario.personaName) is still guarded and reading your intent closely."
        }
        return currentBeatFallback(for: scenario)
    }

    private static func currentBeatFallback(for scenario: IMConversationScenario) -> String {
        switch scenario {
        case .socialCatchUp:
            return "The chat is still finding its rhythm."
        case .workUpdate:
            return "The exchange is practical, and clarity matters."
        case .difficultConversation:
            return "The conversation remains delicate and easy to inflame."
        case .networking:
            return "Rapport is still being established."
        }
    }

    private static func summaryLine(
        hostilityScore: Int,
        warmthScore: Int,
        reciprocityScore: Int,
        disengagementScore: Int,
        specificityScore: Int,
        shouldForceWrapUp: Bool,
        tolerance: IMPersonaToleranceProfile
    ) -> String {
        "Latest user signal: hostility \(hostilityScore)/10, disengagement \(disengagementScore)/10, warmth \(warmthScore)/10, reciprocity \(reciprocityScore)/10, specificity \(specificityScore)/10. Persona tolerance: \(tolerance.summary) \(shouldForceWrapUp ? "The NPC should strongly consider ending the chat." : "Adjust tone accordingly but keep it human.")"
    }

    private static func clamp(_ value: Int) -> Int {
        max(1, min(10, value))
    }
}

struct IMConversationOutcome: Codable, Equatable {
    let title: String
    let summary: String
    let closingMessage: String
}

struct IMConversationDetails: Codable, Equatable {
    let setup: IMConversationSetup
    let turns: [IMConversationTurn]
    let actualTone: String?
    let finalState: IMConversationState?
    let outcome: IMConversationOutcome?
    let relationshipSnapshot: IMRelationshipProfile?
    let contextSnapshot: IMSessionContext?

    init(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        actualTone: String?,
        finalState: IMConversationState?,
        outcome: IMConversationOutcome?,
        relationshipSnapshot: IMRelationshipProfile? = nil,
        contextSnapshot: IMSessionContext? = nil
    ) {
        self.setup = setup
        self.turns = turns
        self.actualTone = actualTone
        self.finalState = finalState
        self.outcome = outcome
        self.relationshipSnapshot = relationshipSnapshot
        self.contextSnapshot = contextSnapshot
    }

    enum CodingKeys: String, CodingKey {
        case setup
        case turns
        case actualTone
        case finalState
        case outcome
        case relationshipSnapshot
        case contextSnapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setup = try container.decode(IMConversationSetup.self, forKey: .setup)
        turns = try container.decode([IMConversationTurn].self, forKey: .turns)
        actualTone = try container.decodeIfPresent(String.self, forKey: .actualTone)
        finalState = try container.decodeIfPresent(IMConversationState.self, forKey: .finalState)
        outcome = try container.decodeIfPresent(IMConversationOutcome.self, forKey: .outcome)
        relationshipSnapshot = try container.decodeIfPresent(IMRelationshipProfile.self, forKey: .relationshipSnapshot)
        contextSnapshot = try container.decodeIfPresent(IMSessionContext.self, forKey: .contextSnapshot)
    }
}

struct IMConversationReply: Codable, Equatable {
    let message: String
    let shouldWrapUp: Bool
    let updatedState: IMConversationState
}

private struct BackendIMConversationReplyRequest: Encodable {
    let setup: IMConversationSetup
    let turns: [IMConversationTurn]
    let state: IMConversationState
    let profile: CoachingProfile?
    let relationship: IMRelationshipProfile?
    let context: IMSessionContext
}

struct IMConversationEvaluation: Codable, Equatable {
    let actualTone: String
    let toneMatch: Int
    let clarityScore: Int
    let composureScore: Int
    let vocabularyScore: Int
    let conversationScore: Int
    let headline: String
    let feedback: String
    let insights: [String]
    let suggestedDrill: String
    let outcome: IMConversationOutcome?

    var overallScore: Int {
        let weighted =
            (Double(toneMatch) * 0.15) +
            (Double(clarityScore) * 0.25) +
            (Double(composureScore) * 0.20) +
            (Double(vocabularyScore) * 0.10) +
            (Double(conversationScore) * 0.30)
        return max(1, min(10, Int(round(weighted))))
    }

    var xpEarned: Int {
        max(8, overallScore * 9)
    }

    var segments: [PracticeScoreSegment] {
        [
            PracticeScoreSegment(title: "Tone Match", value: "\(toneMatch)/10", tintName: "blue"),
            PracticeScoreSegment(title: "Clarity", value: "\(clarityScore)/10", tintName: "teal"),
            PracticeScoreSegment(title: "Composure", value: "\(composureScore)/10", tintName: "orange"),
            PracticeScoreSegment(title: "Vocabulary", value: "\(vocabularyScore)/10", tintName: "purple"),
            PracticeScoreSegment(title: "Conversation", value: "\(conversationScore)/10", tintName: "green")
        ]
    }
}

// Internal (not private) so its CodingKeys contract can be unit-tested.
struct BackendIMConversationEvaluationRequest: Encodable {
    let setup: IMConversationSetup
    let turns: [IMConversationTurn]
    let finalState: IMConversationState?
    let transcript: String
    let fillerCount: Int
    let duration: TimeInterval
    let recentSessions: [PracticeSession]
    let profile: CoachingProfile?
    let relationship: IMRelationshipProfile?
    let context: IMSessionContext

    enum CodingKeys: String, CodingKey {
        case setup
        case turns
        case finalState = "final_state"
        case transcript
        case fillerCount = "filler_count"
        case duration
        case recentSessions = "recent_sessions"
        case profile
        // `relationship` and `context` are single words, so they encode
        // verbatim — matching the synthesized keys on the sibling
        // BackendIMConversationReplyRequest, which the backend already reads.
        case relationship
        case context
    }
}

enum IMConversationOutcomeResolver {
    static func resolve(for scenario: IMConversationScenario, state: IMConversationState) -> IMConversationOutcome {
        if state.normalizedTrust >= 8 && state.normalizedEngagement >= 7 && state.normalizedTension <= 4 {
            return IMConversationOutcome(
                title: "Strong connection",
                summary: "You built trust and kept the conversation open.",
                closingMessage: positiveClosing(for: scenario)
            )
        }

        if state.normalizedTension >= 8 && state.normalizedTrust <= 4 {
            return IMConversationOutcome(
                title: "Conversation tightened",
                summary: "The interaction stayed guarded and more strained than it needed to be.",
                closingMessage: guardedClosing(for: scenario)
            )
        }

        if state.normalizedEngagement <= 4 {
            return IMConversationOutcome(
                title: "Low momentum",
                summary: "The conversation lost energy before it fully opened up.",
                closingMessage: flatClosing(for: scenario)
            )
        }

        return IMConversationOutcome(
            title: "Steady exchange",
            summary: "You kept the conversation moving, but there is room to shape the tone more intentionally.",
            closingMessage: neutralClosing(for: scenario)
        )
    }

    private static func positiveClosing(for scenario: IMConversationScenario) -> String {
        switch scenario {
        case .socialCatchUp:
            return "This was actually really nice to catch up on. Let’s talk again soon."
        case .workUpdate:
            return "Perfect, that gives me confidence going into the meeting. Thanks."
        case .difficultConversation:
            return "I appreciate you saying that clearly. I think that helps."
        case .networking:
            return "This has been good. I’d genuinely be up for staying in touch."
        }
    }

    private static func guardedClosing(for scenario: IMConversationScenario) -> String {
        switch scenario {
        case .socialCatchUp:
            return "Right, okay. Anyway, I should get going."
        case .workUpdate:
            return "Okay. I’ll work with that for now."
        case .difficultConversation:
            return "I still don’t think we’re really aligned here."
        case .networking:
            return "Got it. Nice meeting you."
        }
    }

    private static func flatClosing(for scenario: IMConversationScenario) -> String {
        switch scenario {
        case .socialCatchUp:
            return "Yeah, fair enough. Hope the rest of your day goes well."
        case .workUpdate:
            return "Alright, thanks for the update."
        case .difficultConversation:
            return "Okay. I think that’s all I wanted to say."
        case .networking:
            return "Nice chatting. Enjoy the rest of the event."
        }
    }

    private static func neutralClosing(for scenario: IMConversationScenario) -> String {
        switch scenario {
        case .socialCatchUp:
            return "Good to hear where you’re at. Let’s catch up again soon."
        case .workUpdate:
            return "Got it. That helps me understand where things stand."
        case .difficultConversation:
            return "Okay, I hear where you’re coming from."
        case .networking:
            return "Nice talking with you. It’s been good hearing more."
        }
    }
}

struct IMSessionContext: Codable, Equatable {
    let generatedAt: Date
    let weekday: String
    let dateLabel: String
    let timeLabel: String
    let timeZoneLabel: String
    let regionLabel: String?
    let locationLabel: String?
    let weatherSummary: String?
    let majorEventsSummary: String?
    let socialPulse: String?
    let seasonLabel: String
    let partOfDay: String

    var summaryLines: [String] {
        var lines: [String] = [
            "Current local date: \(weekday), \(dateLabel)",
            "Current local time: \(timeLabel) (\(timeZoneLabel))",
            "Season: \(seasonLabel)",
            "Time of day: \(partOfDay)"
        ]
        if let locationLabel, !locationLabel.isEmpty {
            lines.append("Location context: \(locationLabel)")
        }
        if let regionLabel, !regionLabel.isEmpty {
            lines.append("Regional context: \(regionLabel)")
        }
        if let weatherSummary, !weatherSummary.isEmpty {
            lines.append("Weather today: \(weatherSummary)")
        }
        if let majorEventsSummary, !majorEventsSummary.isEmpty {
            lines.append("Current major events: \(majorEventsSummary)")
        }
        if let socialPulse, !socialPulse.isEmpty {
            lines.append("Social pulse: \(socialPulse)")
        }
        return lines
    }
}

private struct IMContextRequestPayload: Encodable {
    let scenario: String
    let personaName: String
    let personaRole: String
    let regionLabel: String?
    let locationLabel: String?
    let relationshipStage: String?
    let relationshipSummary: String?
}

private struct IMContextResponsePayload: Decodable {
    let regionLabel: String?
    let locationLabel: String?
    let weatherSummary: String?
    let majorEventsSummary: String?
    let socialPulse: String?
}

enum IMSessionContextProvider {
    static func current(now: Date = Date()) -> IMSessionContext {
        let calendar = Calendar.current
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.dateFormat = "EEEE"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.locale = .current
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let hour = calendar.component(.hour, from: now)
        let month = calendar.component(.month, from: now)
        let seasonLabel: String
        switch month {
        case 12, 1, 2: seasonLabel = "winter"
        case 3, 4, 5: seasonLabel = "spring"
        case 6, 7, 8: seasonLabel = "summer"
        default: seasonLabel = "autumn"
        }

        let partOfDay: String
        switch hour {
        case 5..<12: partOfDay = "morning"
        case 12..<17: partOfDay = "afternoon"
        case 17..<22: partOfDay = "evening"
        default: partOfDay = "late night"
        }

        let location = configuredValue(for: "IM_CONTEXT_LOCATION") ?? inferredLocationLabel()
        let weather = configuredValue(for: "IM_CONTEXT_WEATHER")
        let majorEvents = configuredValue(for: "IM_CONTEXT_MAJOR_EVENTS")
        let region = configuredValue(for: "IM_CONTEXT_REGION") ??
            localizedRegionName()

        return IMSessionContext(
            generatedAt: now,
            weekday: weekdayFormatter.string(from: now),
            dateLabel: dateFormatter.string(from: now),
            timeLabel: timeFormatter.string(from: now),
            timeZoneLabel: TimeZone.current.identifier,
            regionLabel: region,
            locationLabel: location,
            weatherSummary: weather,
            majorEventsSummary: majorEvents,
            socialPulse: configuredValue(for: "IM_CONTEXT_SOCIAL_PULSE") ?? inferredSocialPulse(hour: hour),
            seasonLabel: seasonLabel,
            partOfDay: partOfDay
        )
    }

    private static func configuredValue(for key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: key, plistNamed: "AIConfig")
    }

    private static func localizedRegionName() -> String? {
        if let region = Locale.current.region?.identifier {
            return Locale.current.localizedString(forRegionCode: region) ?? region
        }
        return nil
    }

    private static func inferredLocationLabel() -> String? {
        let zoneName = TimeZone.current.identifier
            .split(separator: "/")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "_", with: " ")
        guard let zoneName, !zoneName.isEmpty else { return localizedRegionName() }
        if let region = localizedRegionName(), !region.isEmpty {
            return "\(zoneName), \(region)"
        }
        return zoneName
    }

    private static func inferredSocialPulse(hour: Int) -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch (weekday, hour) {
        case (2...5, 7..<10):
            return "Weekday morning pace, people are getting into the day and keeping chats light but purposeful."
        case (2...5, 10..<17):
            return "Typical working-day energy, conversations tend to be efficient unless the relationship is already warm."
        case (2...5, 17..<22):
            return "After-work window, people are more open to catch-up energy once the practical part of the day eases."
        case (1, _), (7, _):
            return "Weekend rhythm, people are more relaxed and likely to tolerate a softer opener."
        default:
            return "Late-day or off-peak mood, keep the opening natural and read the other person's energy quickly."
        }
    }
}

actor IMContextService {
    static let shared = IMContextService()

    private var cachedContexts: [String: IMSessionContext] = [:]
    private var cachedAt: [String: Date] = [:]
    private let cacheTTL: TimeInterval = 60 * 30

    func context(
        for scenario: IMConversationScenario,
        relationship: IMRelationshipProfile?
    ) async -> IMSessionContext {
        let cacheKey = scenario.rawValue
        let baseline = IMSessionContextProvider.current()
        if let timestamp = cachedAt[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheTTL,
           let cached = cachedContexts[cacheKey] {
            return mergedContext(local: baseline, remote: cached)
        }

        var resolved = baseline

        if let publicContext = await fetchPublicContext(for: scenario, local: baseline) {
            resolved = mergedContext(local: resolved, remote: publicContext)
        }

        guard let remote = await fetchRemoteContext(
            scenario: scenario,
            relationship: relationship,
            local: resolved
        ) else {
            cachedContexts[cacheKey] = resolved
            cachedAt[cacheKey] = Date()
            return resolved
        }

        let merged = mergedContext(local: resolved, remote: remote)
        cachedContexts[cacheKey] = merged
        cachedAt[cacheKey] = Date()
        return merged
    }

    private func fetchPublicContext(for scenario: IMConversationScenario, local: IMSessionContext) async -> IMSessionContext? {
        guard let searchName = inferSearchLocation(from: local) else { return nil }

        async let weatherTask = fetchWeatherSummary(for: searchName)
        async let newsTask = fetchHeadlineSummary(for: scenario, regionLabel: local.regionLabel)
        let scenarioPulse = scenarioAwareSocialPulse(for: scenario, local: local)

        let weather = await weatherTask
        let headlines = await newsTask

        guard weather != nil || headlines != nil else { return nil }

        return IMSessionContext(
            generatedAt: local.generatedAt,
            weekday: local.weekday,
            dateLabel: local.dateLabel,
            timeLabel: local.timeLabel,
            timeZoneLabel: local.timeZoneLabel,
            regionLabel: local.regionLabel,
            locationLabel: local.locationLabel,
            weatherSummary: weather ?? local.weatherSummary,
            majorEventsSummary: headlines ?? local.majorEventsSummary,
            socialPulse: scenarioPulse ?? local.socialPulse,
            seasonLabel: local.seasonLabel,
            partOfDay: local.partOfDay
        )
    }

    private func fetchRemoteContext(
        scenario: IMConversationScenario,
        relationship: IMRelationshipProfile?,
        local: IMSessionContext
    ) async -> IMSessionContext? {
        guard let baseURL = backendBaseURL() else { return nil }
        let endpoint = baseURL.appending(path: "/v1/im/context")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = backendAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-Noum-API-Key")
        }
        let authHeaders = await MainActor.run {
            (
                accountID: AuthManager.shared.currentAccountID,
                provider: AuthManager.shared.currentAuthProviderRawValue
            )
        }
        if let accountID = authHeaders.accountID {
            request.setValue(accountID, forHTTPHeaderField: "X-Noum-Account-ID")
        }
        if let provider = authHeaders.provider {
            request.setValue(provider, forHTTPHeaderField: "X-Noum-Auth-Provider")
        }

        let payload = IMContextRequestPayload(
            scenario: scenario.rawValue,
            personaName: scenario.personaName,
            personaRole: scenario.personaRole,
            regionLabel: local.regionLabel,
            locationLabel: local.locationLabel,
            relationshipStage: relationship?.relationshipStage,
            relationshipSummary: relationship?.continuitySummary
        )
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(IMContextResponsePayload.self, from: data)
            return IMSessionContext(
                generatedAt: local.generatedAt,
                weekday: local.weekday,
                dateLabel: local.dateLabel,
                timeLabel: local.timeLabel,
                timeZoneLabel: local.timeZoneLabel,
                regionLabel: decoded.regionLabel ?? local.regionLabel,
                locationLabel: decoded.locationLabel ?? local.locationLabel,
                weatherSummary: decoded.weatherSummary ?? local.weatherSummary,
                majorEventsSummary: decoded.majorEventsSummary ?? local.majorEventsSummary,
                socialPulse: decoded.socialPulse ?? local.socialPulse,
                seasonLabel: local.seasonLabel,
                partOfDay: local.partOfDay
            )
        } catch {
            return nil
        }
    }

    private func mergedContext(local: IMSessionContext, remote: IMSessionContext) -> IMSessionContext {
        IMSessionContext(
            generatedAt: local.generatedAt,
            weekday: local.weekday,
            dateLabel: local.dateLabel,
            timeLabel: local.timeLabel,
            timeZoneLabel: local.timeZoneLabel,
            regionLabel: remote.regionLabel ?? local.regionLabel,
            locationLabel: remote.locationLabel ?? local.locationLabel,
            weatherSummary: remote.weatherSummary ?? local.weatherSummary,
            majorEventsSummary: remote.majorEventsSummary ?? local.majorEventsSummary,
            socialPulse: remote.socialPulse ?? local.socialPulse,
            seasonLabel: local.seasonLabel,
            partOfDay: local.partOfDay
        )
    }

    private func inferSearchLocation(from local: IMSessionContext) -> String? {
        if let configured = local.locationLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            return configured
        }
        if let region = local.regionLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !region.isEmpty {
            return region
        }
        return nil
    }

    private func fetchWeatherSummary(for searchName: String) async -> String? {
        guard let query = searchName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let geocodeURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(query)&count=1&language=en&format=json") else {
            return nil
        }

        do {
            let (geocodeData, geocodeResponse) = try await URLSession.shared.data(from: geocodeURL)
            guard let geocodeHTTP = geocodeResponse as? HTTPURLResponse,
                  (200..<300).contains(geocodeHTTP.statusCode) else { return nil }
            let geocode = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: geocodeData)
            guard let result = geocode.results?.first else { return nil }

            guard let forecastURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(result.latitude)&longitude=\(result.longitude)&current=temperature_2m,apparent_temperature,weather_code&timezone=auto") else {
                return nil
            }

            let (forecastData, forecastResponse) = try await URLSession.shared.data(from: forecastURL)
            guard let forecastHTTP = forecastResponse as? HTTPURLResponse,
                  (200..<300).contains(forecastHTTP.statusCode) else { return nil }
            let forecast = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: forecastData)
            guard let current = forecast.current else { return nil }

            let place = [result.name, result.country].compactMap { $0 }.joined(separator: ", ")
            let temp = Int(current.temperature2m.rounded())
            let apparent = Int(current.apparentTemperature.rounded())
            let weather = weatherDescription(for: current.weatherCode)
            return "\(place): \(weather), about \(temp)C and feels like \(apparent)C."
        } catch {
            return nil
        }
    }

    private func fetchHeadlineSummary(for scenario: IMConversationScenario, regionLabel: String?) async -> String? {
        let normalizedRegion = (regionLabel ?? "").lowercased()
        let prefersUK = normalizedRegion.contains("united kingdom") || normalizedRegion == "uk" || normalizedRegion == "gb"
        let feedCandidates = headlineFeedCandidates(for: scenario, prefersUK: prefersUK)
        let parser = RSSHeadlineParser()

        for candidate in feedCandidates {
            guard let url = URL(string: candidate.urlString) else { continue }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else { continue }
                if let summary = parser.parse(data: data, limit: candidate.limit) {
                    return "\(candidate.label): \(summary)"
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private func headlineFeedCandidates(for scenario: IMConversationScenario, prefersUK: Bool) -> [(label: String, urlString: String, limit: Int)] {
        switch scenario {
        case .socialCatchUp:
            if prefersUK {
                return [
                    ("In the UK today", "https://feeds.bbci.co.uk/news/uk/rss.xml", 2),
                    ("Around the world", "https://feeds.bbci.co.uk/news/world/rss.xml", 1)
                ]
            }
            return [
                ("Around the world", "https://feeds.bbci.co.uk/news/world/rss.xml", 2)
            ]
        case .workUpdate:
            return [
                ("Business backdrop", "https://feeds.bbci.co.uk/news/business/rss.xml", 2),
                ("Top headlines", prefersUK ? "https://feeds.bbci.co.uk/news/uk/rss.xml" : "https://feeds.bbci.co.uk/news/world/rss.xml", 1)
            ]
        case .difficultConversation:
            return [
                ("Public pressure points", prefersUK ? "https://feeds.bbci.co.uk/news/politics/rss.xml" : "https://feeds.bbci.co.uk/news/world/rss.xml", 2),
                ("Top headlines", prefersUK ? "https://feeds.bbci.co.uk/news/uk/rss.xml" : "https://feeds.bbci.co.uk/news/world/rss.xml", 1)
            ]
        case .networking:
            return [
                ("Professional talking points", "https://feeds.bbci.co.uk/news/business/rss.xml", 2),
                ("Broader backdrop", prefersUK ? "https://feeds.bbci.co.uk/news/uk/rss.xml" : "https://feeds.bbci.co.uk/news/world/rss.xml", 1)
            ]
        }
    }

    private func scenarioAwareSocialPulse(for scenario: IMConversationScenario, local: IMSessionContext) -> String? {
        let basePulse = local.socialPulse ?? ""
        switch scenario {
        case .socialCatchUp:
            return basePulse.isEmpty
                ? "Keep the opener easy and human, like someone feeling out whether the other person has bandwidth to chat."
                : "\(basePulse) Socially, the opener can breathe a little before the real catch-up."
        case .workUpdate:
            return "People are usually scanning for the practical point quickly here, so keep any rapport brief and useful."
        case .difficultConversation:
            return "The emotional temperature matters more than chit-chat here. The opener should feel realistic, but the issue stays central."
        case .networking:
            return "The opener should create rapport fast, then pivot into a concrete hook that makes the speaker memorable."
        }
    }

    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "clear skies"
        case 1, 2: return "mostly clear conditions"
        case 3: return "overcast skies"
        case 45, 48: return "misty weather"
        case 51, 53, 55, 56, 57: return "light rain in the air"
        case 61, 63, 65, 66, 67: return "rainy conditions"
        case 71, 73, 75, 77: return "snowy conditions"
        case 80, 81, 82: return "scattered showers"
        case 85, 86: return "snow showers"
        case 95, 96, 99: return "stormy weather"
        default: return "mixed weather"
        }
    }

    private func backendBaseURL() -> URL? {
        let rawValue =
            ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ??
            LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return URL(string: rawValue)
    }

    private func backendAPIKey() -> String? {
        ProcessInfo.processInfo.environment["BACKEND_API_KEY"] ??
        LocalConfigLoader.value(forKey: "BACKEND_API_KEY", plistNamed: "BackendConfig")
    }
}

private struct OpenMeteoGeocodingResponse: Decodable {
    let results: [OpenMeteoGeocodingResult]?
}

private struct OpenMeteoGeocodingResult: Decodable {
    let name: String
    let country: String?
    let latitude: Double
    let longitude: Double
}

private struct OpenMeteoForecastResponse: Decodable {
    let current: OpenMeteoCurrentWeather?
}

private struct OpenMeteoCurrentWeather: Decodable {
    let temperature2m: Double
    let apparentTemperature: Double
    let weatherCode: Int

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case weatherCode = "weather_code"
    }
}

private final class RSSHeadlineParser: NSObject, XMLParserDelegate {
    private var insideItem = false
    private var insideTitle = false
    private var currentTitle = ""
    private var titles: [String] = []

    func parse(data: Data, limit: Int = 2) -> String? {
        titles = []
        currentTitle = ""
        insideItem = false
        insideTitle = false
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }
        let cleaned = titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("BBC") }
        guard !cleaned.isEmpty else { return nil }
        return cleaned.prefix(limit).joined(separator: " / ")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "item" {
            insideItem = true
            currentTitle = ""
        } else if insideItem && elementName == "title" {
            insideTitle = true
            currentTitle = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem, insideTitle else { return }
        currentTitle += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if insideItem && insideTitle && elementName == "title" {
            titles.append(currentTitle)
            insideTitle = false
        } else if elementName == "item" {
            insideItem = false
            insideTitle = false
        }
    }
}

struct IMRelationshipProfile: Codable, Equatable {
    let scenario: IMConversationScenario
    let sessionCount: Int
    let trustBaseline: Int
    let engagementBaseline: Int
    let tensionBaseline: Int
    let warmthScore: Int
    let reliabilityScore: Int
    let opennessScore: Int
    let reciprocityScore: Int
    let frictionScore: Int
    let ruptureScore: Int
    let repairMomentum: Int
    let inconsistencyScore: Int
    let activeMilestone: IMRelationshipMilestone
    let milestoneHistory: [IMRelationshipMilestone]
    let rememberedTopics: [String]
    let callbackCue: String?
    let activeArcID: String?
    let activeArcStage: Int
    let arcHistory: [String]
    let continuitySummary: String
    let lastOutcomeTitle: String?
    let lastOutcomeSummary: String?
    let lastInteractionDate: Date?

    static func initial(for scenario: IMConversationScenario) -> IMRelationshipProfile {
        IMRelationshipProfile(
            scenario: scenario,
            sessionCount: 0,
            trustBaseline: scenario == .socialCatchUp ? 6 : 5,
            engagementBaseline: 5,
            tensionBaseline: scenario == .difficultConversation ? 6 : 4,
            warmthScore: scenario == .socialCatchUp ? 6 : 5,
            reliabilityScore: 5,
            opennessScore: 5,
            reciprocityScore: 5,
            frictionScore: scenario == .difficultConversation ? 6 : 4,
            ruptureScore: 2,
            repairMomentum: 4,
            inconsistencyScore: 3,
            activeMilestone: .guarded,
            milestoneHistory: [.guarded],
            rememberedTopics: [],
            callbackCue: nil,
            activeArcID: nil,
            activeArcStage: 0,
            arcHistory: [],
            continuitySummary: "This relationship is still early, so the other person is reading your tone and consistency closely.",
            lastOutcomeTitle: nil,
            lastOutcomeSummary: nil,
            lastInteractionDate: nil
        )
    }

    var normalizedTrustBaseline: Int { max(1, min(10, trustBaseline)) }
    var normalizedEngagementBaseline: Int { max(1, min(10, engagementBaseline)) }
    var normalizedTensionBaseline: Int { max(1, min(10, tensionBaseline)) }

    var relationshipStage: String {
        switch (normalizedTrustBaseline, frictionScore) {
        case (8..., ..<5): return "strong and comfortable"
        case (6..., ..<7): return "steady but still being reinforced"
        case (...4, 7...): return "fragile and easily strained"
        default: return "developing and somewhat tentative"
        }
    }

    var compactSummary: String {
        "\(activeMilestone.title), trust \(normalizedTrustBaseline)/10, tension \(normalizedTensionBaseline)/10, rupture \(ruptureScore)/10"
    }

    var daysSinceLastInteractionText: String? {
        guard let lastInteractionDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastInteractionDate, to: Date()).day ?? 0
        if days <= 0 { return "Updated today" }
        if days == 1 { return "Updated 1 day ago" }
        return "Updated \(days) days ago"
    }

    func startingState() -> IMConversationState {
        IMConversationState(
            trust: normalizedTrustBaseline,
            engagement: normalizedEngagementBaseline,
            tension: normalizedTensionBaseline,
            beat: continuitySummary
        )
    }

    var promptSummary: String {
        var summary = "Relationship stage: \(relationshipStage). Sessions together: \(sessionCount). Baseline trust \(normalizedTrustBaseline)/10, engagement \(normalizedEngagementBaseline)/10, tension \(normalizedTensionBaseline)/10."
        summary += " Warmth \(warmthScore)/10, reliability \(reliabilityScore)/10, openness \(opennessScore)/10, reciprocity \(reciprocityScore)/10, friction \(frictionScore)/10."
        summary += " Rupture memory \(ruptureScore)/10, repair momentum \(repairMomentum)/10, inconsistency \(inconsistencyScore)/10."
        summary += " Active milestone: \(activeMilestone.title)."
        if !rememberedTopics.isEmpty {
            summary += " Remembered themes: \(rememberedTopics.joined(separator: ", "))."
        }
        if let callbackCue, !callbackCue.isEmpty {
            summary += " Callback cue: \(callbackCue)"
        }
        if let activeArcSummary {
            summary += " Relationship arc: \(activeArcSummary)"
        }
        summary += " Continuity note: \(continuitySummary)"
        if let lastOutcomeTitle, let lastOutcomeSummary {
            summary += " Last outcome: \(lastOutcomeTitle) - \(lastOutcomeSummary)"
        }
        return summary
    }

    var milestoneBehaviorSummary: String {
        activeMilestone.npcBehaviorGuidance
    }

    func nextSessionHook(profile: CoachingProfile?) -> String {
        let goalNote = profile?.primaryGoal.title.lowercased() ?? "communicate better"
        switch activeMilestone {
        case .guarded:
            return "One more steady session with clear, respectful specifics could move this dynamic from guarded to opening up. Focus on \(goalNote), not charm."
        case .openingUp:
            return "The other person is warming up. Another grounded exchange could make this feel genuinely steady, so keep \(goalNote) under light pressure."
        case .steady:
            return "This is close to becoming a relationship advantage. A sharper next session could turn steady rapport into real trust."
        case .trusted:
            return "This connection now has upside. The next challenge is making your stronger communication style feel natural enough to hold under pressure."
        case .fractured:
            return "The relationship is carrying damage. A calm, non-defensive repair attempt is the shortest path back, but it has to feel earned."
        case .recovering:
            return "Repair is working, but it is not locked in. Stack another composed session to prove the change is real."
        }
    }

    var nextMilestoneProgress: Double {
        switch activeMilestone {
        case .guarded:
            return progressScore(
                trust: normalizedTrustBaseline,
                repair: repairMomentum,
                rupture: ruptureScore,
                inconsistency: inconsistencyScore,
                trustTarget: 6,
                repairTarget: 6,
                ruptureCap: 4,
                inconsistencyCap: 5
            )
        case .openingUp:
            return progressScore(
                trust: normalizedTrustBaseline,
                repair: repairMomentum,
                rupture: ruptureScore,
                inconsistency: inconsistencyScore,
                trustTarget: 7,
                repairTarget: 6,
                ruptureCap: 4,
                inconsistencyCap: 5
            )
        case .steady:
            return progressScore(
                trust: normalizedTrustBaseline,
                repair: repairMomentum,
                rupture: ruptureScore,
                inconsistency: inconsistencyScore,
                trustTarget: 8,
                repairTarget: 8,
                ruptureCap: 4,
                inconsistencyCap: 4
            )
        case .trusted:
            return 1
        case .fractured:
            return progressScore(
                trust: normalizedTrustBaseline,
                repair: repairMomentum,
                rupture: 10 - ruptureScore,
                inconsistency: 10 - inconsistencyScore,
                trustTarget: 6,
                repairTarget: 6,
                ruptureCap: 6,
                inconsistencyCap: 6
            )
        case .recovering:
            return progressScore(
                trust: normalizedTrustBaseline,
                repair: repairMomentum,
                rupture: 10 - ruptureScore,
                inconsistency: 10 - inconsistencyScore,
                trustTarget: 6,
                repairTarget: 7,
                ruptureCap: 6,
                inconsistencyCap: 6
            )
        }
    }

    var nextMilestoneProgressLabel: String {
        if let nextMilestoneTitle = activeMilestone.nextMilestoneTitle {
            return "\(Int((nextMilestoneProgress * 100).rounded()))% to \(nextMilestoneTitle)"
        }
        return "Relationship state maximized"
    }

    var unlockTeaser: String {
        scenario.unlockTeaser(for: activeMilestone)
    }

    var topicUnlockGuidance: String {
        scenario.topicUnlockGuidance(for: activeMilestone)
    }

    var activeArcTemplate: IMRelationshipArcTemplate? {
        guard let activeArcID else { return nil }
        return scenario.relationshipArcTemplates.first { $0.id == activeArcID }
    }

    var activeArcTitle: String? {
        activeArcTemplate?.title
    }

    var activeArcStageLabel: String? {
        guard let template = activeArcTemplate, template.stages.indices.contains(activeArcStage) else { return nil }
        return template.stages[activeArcStage]
    }

    var activeArcGuidance: String? {
        guard let template = activeArcTemplate, template.stageGuidance.indices.contains(activeArcStage) else { return nil }
        return template.stageGuidance[activeArcStage]
    }

    var activeArcSummary: String? {
        guard let activeArcTitle, let activeArcStageLabel else { return nil }
        return "\(activeArcTitle) - \(activeArcStageLabel)"
    }

    var activeArcProgress: Double {
        guard let template = activeArcTemplate, !template.stages.isEmpty else { return 0 }
        return min(1, Double(activeArcStage + 1) / Double(template.stages.count))
    }

    var activeArcProgressLabel: String {
        guard let template = activeArcTemplate, let stage = activeArcStageLabel else {
            return "No active arc yet"
        }
        return "\(stage) (\(activeArcStage + 1)/\(template.stages.count))"
    }

    private func progressScore(
        trust: Int,
        repair: Int,
        rupture: Int,
        inconsistency: Int,
        trustTarget: Int,
        repairTarget: Int,
        ruptureCap: Int,
        inconsistencyCap: Int
    ) -> Double {
        let trustProgress = min(1.0, Double(trust) / Double(max(trustTarget, 1)))
        let repairProgress = min(1.0, Double(repair) / Double(max(repairTarget, 1)))
        let ruptureProgress = min(1.0, Double(max(0, ruptureCap - rupture + 1)) / Double(max(ruptureCap, 1)))
        let inconsistencyProgress = min(1.0, Double(max(0, inconsistencyCap - inconsistency + 1)) / Double(max(inconsistencyCap, 1)))
        return max(0.0, min(1.0, (trustProgress * 0.4) + (repairProgress * 0.3) + (ruptureProgress * 0.2) + (inconsistencyProgress * 0.1)))
    }
}

private enum IMRelationshipProfileCodingKeys: String, CodingKey {
    case scenario
    case sessionCount
    case trustBaseline
    case engagementBaseline
    case tensionBaseline
    case warmthScore
    case reliabilityScore
    case opennessScore
    case reciprocityScore
    case frictionScore
    case ruptureScore
    case repairMomentum
    case inconsistencyScore
    case activeMilestone
    case milestoneHistory
    case rememberedTopics
    case callbackCue
    case activeArcID
    case activeArcStage
    case arcHistory
    case continuitySummary
    case lastOutcomeTitle
    case lastOutcomeSummary
    case lastInteractionDate
}

extension IMRelationshipProfile {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: IMRelationshipProfileCodingKeys.self)
        self.init(
            scenario: try container.decode(IMConversationScenario.self, forKey: .scenario),
            sessionCount: try container.decode(Int.self, forKey: .sessionCount),
            trustBaseline: try container.decode(Int.self, forKey: .trustBaseline),
            engagementBaseline: try container.decode(Int.self, forKey: .engagementBaseline),
            tensionBaseline: try container.decode(Int.self, forKey: .tensionBaseline),
            warmthScore: try container.decode(Int.self, forKey: .warmthScore),
            reliabilityScore: try container.decode(Int.self, forKey: .reliabilityScore),
            opennessScore: try container.decode(Int.self, forKey: .opennessScore),
            reciprocityScore: try container.decode(Int.self, forKey: .reciprocityScore),
            frictionScore: try container.decode(Int.self, forKey: .frictionScore),
            ruptureScore: try container.decode(Int.self, forKey: .ruptureScore),
            repairMomentum: try container.decode(Int.self, forKey: .repairMomentum),
            inconsistencyScore: try container.decode(Int.self, forKey: .inconsistencyScore),
            activeMilestone: try container.decode(IMRelationshipMilestone.self, forKey: .activeMilestone),
            milestoneHistory: try container.decode([IMRelationshipMilestone].self, forKey: .milestoneHistory),
            rememberedTopics: try container.decodeIfPresent([String].self, forKey: .rememberedTopics) ?? [],
            callbackCue: try container.decodeIfPresent(String.self, forKey: .callbackCue),
            activeArcID: try container.decodeIfPresent(String.self, forKey: .activeArcID),
            activeArcStage: try container.decodeIfPresent(Int.self, forKey: .activeArcStage) ?? 0,
            arcHistory: try container.decodeIfPresent([String].self, forKey: .arcHistory) ?? [],
            continuitySummary: try container.decode(String.self, forKey: .continuitySummary),
            lastOutcomeTitle: try container.decodeIfPresent(String.self, forKey: .lastOutcomeTitle),
            lastOutcomeSummary: try container.decodeIfPresent(String.self, forKey: .lastOutcomeSummary),
            lastInteractionDate: try container.decodeIfPresent(Date.self, forKey: .lastInteractionDate)
        )
    }
}

enum IMRelationshipArcPlanner {
    static func nextState(
        profile: IMRelationshipProfile,
        rememberedTopics: [String],
        evaluation: IMConversationEvaluation,
        averageHostility: Int,
        averageDisengagement: Int,
        milestone: IMRelationshipMilestone
    ) -> (arcID: String?, stage: Int, history: [String]) {
        let templates = profile.scenario.relationshipArcTemplates
        guard !templates.isEmpty else { return (nil, 0, profile.arcHistory) }

        let activeTemplate = profile.activeArcTemplate ?? chooseTemplate(from: templates, rememberedTopics: rememberedTopics)
        guard let activeTemplate else { return (nil, 0, profile.arcHistory) }

        var stage = max(0, min(profile.activeArcStage, activeTemplate.stages.count - 1))
        let strongPositive = evaluation.conversationScore >= 7 && evaluation.toneMatch >= 7 && averageHostility <= 3 && averageDisengagement <= 4
        let breakdown = averageHostility >= 7 || averageDisengagement >= 8 || milestone == .fractured

        if breakdown {
            stage = max(0, stage - 1)
        } else if strongPositive {
            stage = min(activeTemplate.stages.count - 1, stage + 1)
        }

        let marker = "\(activeTemplate.title): \(activeTemplate.stages[stage])"
        let history = profile.arcHistory.last == marker ? profile.arcHistory : Array((profile.arcHistory + [marker]).suffix(6))
        return (activeTemplate.id, stage, history)
    }

    private static func chooseTemplate(
        from templates: [IMRelationshipArcTemplate],
        rememberedTopics: [String]
    ) -> IMRelationshipArcTemplate? {
        let loweredTopics = rememberedTopics.map { $0.lowercased() }
        if let matched = templates.max(by: { score(for: $0, topics: loweredTopics) < score(for: $1, topics: loweredTopics) }),
           score(for: matched, topics: loweredTopics) > 0 {
            return matched
        }
        return templates.first
    }

    private static func score(for template: IMRelationshipArcTemplate, topics: [String]) -> Int {
        template.topicMatches.reduce(0) { partial, match in
            partial + (topics.contains { $0.contains(match) } ? 1 : 0)
        }
    }
}

enum IMTopicMemoryBuilder {
    static func rememberedTopics(
        for scenario: IMConversationScenario,
        turns: [IMConversationTurn],
        existing: [String]
    ) -> [String] {
        let userText = turns
            .filter { $0.speaker == .user }
            .map { $0.text.lowercased() }
            .joined(separator: " ")

        var topics = existing
        for topic in scenario.topicCandidates {
            if topics.count >= 3 { break }
            if userText.contains(topic.match), !topics.contains(topic.label) {
                topics.append(topic.label)
            }
        }

        if topics.count < 2 {
            let fallbackPhrases = turns
                .filter { $0.speaker == .user }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.split(whereSeparator: \.isWhitespace).count >= 4 }
                .sorted { $0.count > $1.count }
                .prefix(2)
                .map { fallbackTopic(from: $0) }
            for phrase in fallbackPhrases where !phrase.isEmpty && !topics.contains(phrase) {
                topics.append(phrase)
                if topics.count >= 3 { break }
            }
        }

        return Array(topics.prefix(3))
    }

    static func callbackCue(
        for scenario: IMConversationScenario,
        milestone: IMRelationshipMilestone,
        rememberedTopics: [String]
    ) -> String? {
        guard let firstTopic = rememberedTopics.first else { return nil }
        switch milestone {
        case .guarded:
            return nil
        case .openingUp, .steady:
            return "\(scenario.personaName) can naturally call back to \(firstTopic.lowercased()) if it helps the opener feel grounded."
        case .trusted:
            return "\(scenario.personaName) should feel comfortable referencing \(firstTopic.lowercased()) more naturally, like someone who actually remembers the thread."
        case .fractured:
            return "\(scenario.personaName) may reopen the conversation with unresolved distance around \(firstTopic.lowercased()) rather than acting like nothing happened."
        case .recovering:
            return "\(scenario.personaName) can cautiously reference \(firstTopic.lowercased()) as a test of whether the dynamic is genuinely improving."
        }
    }

    private static func fallbackTopic(from text: String) -> String {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace).prefix(6)
        let phrase = words.joined(separator: " ")
        if phrase.count <= 42 {
            return phrase
        }
        return String(phrase.prefix(39)) + "..."
    }
}

enum IMRelationshipHeuristics {
    static func updatedProfile(
        from profile: IMRelationshipProfile,
        turns: [IMConversationTurn],
        finalState: IMConversationState,
        evaluation: IMConversationEvaluation
    ) -> IMRelationshipProfile {
        let tolerance = profile.scenario.toleranceProfile
        let userTexts = turns.filter { $0.speaker == .user }.map(\.text)
        let totalWordCount = userTexts.map(wordCount).reduce(0, +)
        let averageWordCount = userTexts.isEmpty ? 0 : totalWordCount / max(1, userTexts.count)
        let questionCount = userTexts.reduce(0) { $0 + $1.filter { $0 == "?" }.count }
        let acknowledgementCount = userTexts.reduce(0) { partial, text in
            partial + acknowledgementSignals(in: text)
        }
        let selfFocusCount = userTexts.reduce(0) { partial, text in
            partial + tokenCount(in: text, matches: ["i", "me", "my", "mine"])
        }
        let sharedFocusCount = userTexts.reduce(0) { partial, text in
            partial + tokenCount(in: text, matches: ["you", "your", "we", "us", "our"])
        }
        let signalScores = userTexts.map {
            IMUserMessageAnalyzer.analyze(
                text: $0,
                currentState: .starting,
                scenario: profile.scenario,
                relationship: profile
            )
        }
        let averageHostility = signalScores.isEmpty ? 0 : signalScores.map(\.hostilityScore).reduce(0, +) / signalScores.count
        let averageWarmth = signalScores.isEmpty ? 0 : signalScores.map(\.warmthScore).reduce(0, +) / signalScores.count
        let averageReciprocity = signalScores.isEmpty ? 0 : signalScores.map(\.reciprocityScore).reduce(0, +) / signalScores.count
        let averageDisengagement = signalScores.isEmpty ? 0 : signalScores.map(\.disengagementScore).reduce(0, +) / signalScores.count
        let qualityScore = Double(evaluation.clarityScore + evaluation.composureScore + evaluation.conversationScore + evaluation.toneMatch) / 4.0
        let reciprocitySignal = questionCount > 0 ? 1 : 0
        let balancedFocusSignal = sharedFocusCount >= max(1, selfFocusCount / 2) ? 1 : 0
        let specificitySignal = averageWordCount >= 6 && averageWordCount <= 26 ? 1 : (averageWordCount > 26 ? 0 : -1)
        let warmthSignal = min(1, acknowledgementCount)
        let sharpnessPenalty = averageWordCount < 4 ? 1 : 0
        let strainPenalty = finalState.normalizedTension >= 8 ? 1 : 0
        let rupturePenalty = profile.ruptureScore >= 7 ? 1 : 0
        let inconsistencyPenalty = profile.inconsistencyScore >= 7 ? 1 : 0

        let trustDelta = boundedDelta(
            Int(round((qualityScore - 6.0) / 1.4)) +
            reciprocitySignal +
            balancedFocusSignal +
            specificitySignal -
            sharpnessPenalty -
            strainPenalty -
            rupturePenalty -
            inconsistencyPenalty,
            magnitude: 2
        )

        let engagementDelta = boundedDelta(
            Int(round((Double(evaluation.conversationScore) - 6.0) / 1.5)) +
            reciprocitySignal +
            max(0, specificitySignal),
            magnitude: 2
        )

        let tensionDelta = boundedDelta(
            Int(round((Double(finalState.normalizedTension) - 5.0) / 2.0)) -
            Int(round((Double(evaluation.composureScore) - 6.0) / 2.0)),
            magnitude: 2
        )

        let warmthScore = clamp(profile.warmthScore + warmthSignal + (evaluation.toneMatch >= 7 ? 1 : 0) - strainPenalty)
        let reliabilityScore = clamp(profile.reliabilityScore + boundedDelta(Int(round((Double(evaluation.clarityScore + evaluation.composureScore) / 2.0 - 6.0) / 1.5)), magnitude: 2))
        let opennessScore = clamp(profile.opennessScore + specificitySignal + (averageWordCount >= 10 ? 1 : 0) - sharpnessPenalty)
        let reciprocityScore = clamp(profile.reciprocityScore + reciprocitySignal + balancedFocusSignal - (questionCount == 0 ? 1 : 0))
        let frictionScore = clamp(profile.frictionScore + tensionDelta - (evaluation.composureScore >= 7 ? 1 : 0))
        let ruptureScore = updatedRuptureScore(
            current: profile.ruptureScore,
            averageHostility: averageHostility,
            averageDisengagement: averageDisengagement,
            tolerance: tolerance,
            evaluation: evaluation
        )
        let repairMomentum = updatedRepairMomentum(
            current: profile.repairMomentum,
            averageWarmth: averageWarmth,
            averageReciprocity: averageReciprocity,
            evaluation: evaluation,
            ruptureScore: ruptureScore
        )
        let inconsistencyScore = updatedInconsistencyScore(
            current: profile.inconsistencyScore,
            averageHostility: averageHostility,
            averageWarmth: averageWarmth,
            averageDisengagement: averageDisengagement,
            evaluation: evaluation
        )

        let repairBonus = repairMomentum >= 7 ? 1 : 0
        let ruptureTax = ruptureScore >= 7 ? 2 : (ruptureScore >= 5 ? 1 : 0)
        let inconsistencyTax = inconsistencyScore >= 7 ? 1 : 0

        let newTrust = clamp(
            smoothedBaseline(current: profile.normalizedTrustBaseline, live: finalState.normalizedTrust) +
            trustDelta +
            repairBonus -
            ruptureTax -
            inconsistencyTax
        )
        let newEngagement = clamp(
            smoothedBaseline(current: profile.normalizedEngagementBaseline, live: finalState.normalizedEngagement) +
            engagementDelta -
            (inconsistencyScore >= 6 ? 1 : 0)
        )
        let newTension = clamp(
            smoothedBaseline(current: profile.normalizedTensionBaseline, live: finalState.normalizedTension) +
            tensionDelta +
            (ruptureScore >= 6 ? 1 : 0) -
            repairBonus
        )
        let milestone = resolveMilestone(
            trust: newTrust,
            rupture: ruptureScore,
            repair: repairMomentum,
            inconsistency: inconsistencyScore,
            previous: profile.activeMilestone
        )
        let rememberedTopics = IMTopicMemoryBuilder.rememberedTopics(
            for: profile.scenario,
            turns: turns,
            existing: profile.rememberedTopics
        )
        let callbackCue = IMTopicMemoryBuilder.callbackCue(
            for: profile.scenario,
            milestone: milestone,
            rememberedTopics: rememberedTopics
        )
        let arcState = IMRelationshipArcPlanner.nextState(
            profile: profile,
            rememberedTopics: rememberedTopics,
            evaluation: evaluation,
            averageHostility: averageHostility,
            averageDisengagement: averageDisengagement,
            milestone: milestone
        )

        let continuitySummary = continuitySummary(
            scenario: profile.scenario,
            trust: newTrust,
            engagement: newEngagement,
            tension: newTension,
            reliability: reliabilityScore,
            reciprocity: reciprocityScore,
            rupture: ruptureScore,
            repair: repairMomentum,
            inconsistency: inconsistencyScore,
            rememberedTopics: rememberedTopics,
            callbackCue: callbackCue,
            lastOutcome: evaluation.outcome
        )
        let milestoneHistory = updatedMilestoneHistory(
            current: profile.milestoneHistory,
            next: milestone
        )

        return IMRelationshipProfile(
            scenario: profile.scenario,
            sessionCount: profile.sessionCount + 1,
            trustBaseline: newTrust,
            engagementBaseline: newEngagement,
            tensionBaseline: newTension,
            warmthScore: warmthScore,
            reliabilityScore: reliabilityScore,
            opennessScore: opennessScore,
            reciprocityScore: reciprocityScore,
            frictionScore: frictionScore,
            ruptureScore: ruptureScore,
            repairMomentum: repairMomentum,
            inconsistencyScore: inconsistencyScore,
            activeMilestone: milestone,
            milestoneHistory: milestoneHistory,
            rememberedTopics: rememberedTopics,
            callbackCue: callbackCue,
            activeArcID: arcState.arcID,
            activeArcStage: arcState.stage,
            arcHistory: arcState.history,
            continuitySummary: continuitySummary,
            lastOutcomeTitle: evaluation.outcome?.title,
            lastOutcomeSummary: evaluation.outcome?.summary,
            lastInteractionDate: Date()
        )
    }

    private static func continuitySummary(
        scenario: IMConversationScenario,
        trust: Int,
        engagement: Int,
        tension: Int,
        reliability: Int,
        reciprocity: Int,
        rupture: Int,
        repair: Int,
        inconsistency: Int,
        rememberedTopics: [String],
        callbackCue: String?,
        lastOutcome: IMConversationOutcome?
    ) -> String {
        let connectionNote: String
        if rupture >= 7 {
            connectionNote = "\(scenario.personaName) remembers recent damage in the dynamic, so warmth alone will not reset the tone."
        } else if trust >= 8 && reciprocity >= 7 && tension <= 4 {
            connectionNote = "\(scenario.personaName) now expects a warmer, more natural back-and-forth and is more willing to open up quickly."
        } else if trust <= 4 || tension >= 7 {
            connectionNote = "\(scenario.personaName) is more guarded now and will need steadiness, relevance, and follow-through before relaxing."
        } else {
            connectionNote = "\(scenario.personaName) is moderately comfortable, but still judges whether you are engaged, specific, and easy to talk to."
        }

        let reliabilityNote: String
        if inconsistency >= 7 {
            reliabilityNote = "The relationship feels inconsistent, so one good exchange will not outweigh recent swings."
        } else if reliability >= 8 {
            reliabilityNote = "Your last few interactions read as dependable and composed."
        } else if reliability <= 4 {
            reliabilityNote = "The relationship still feels inconsistent, so vague or abrupt replies will cost you quickly."
        } else {
            reliabilityNote = "Consistency matters more than charm here."
        }

        let repairNote: String
        if repair >= 8 && rupture <= 4 {
            repairNote = "There is clear repair momentum, so the other person is becoming more willing to give you the benefit of the doubt."
        } else if rupture >= 6 {
            repairNote = "Repair will take repeated, credible good interactions rather than one warm moment."
        } else {
            repairNote = "The relationship is still being shaped by repeated behaviour, not isolated lines."
        }

        let memoryNote: String
        if let callbackCue, !callbackCue.isEmpty {
            memoryNote = "Carry-forward cue: \(callbackCue)"
        } else if !rememberedTopics.isEmpty {
            memoryNote = "Remembered themes include \(rememberedTopics.joined(separator: ", "))."
        } else {
            memoryNote = "No strong carry-forward topic has been earned yet."
        }

        if let lastOutcome {
            return "\(connectionNote) \(reliabilityNote) \(repairNote) \(memoryNote) Last time landed as: \(lastOutcome.summary)"
        }
        return "\(connectionNote) \(reliabilityNote) \(repairNote) \(memoryNote)"
    }

    private static func resolveMilestone(
        trust: Int,
        rupture: Int,
        repair: Int,
        inconsistency: Int,
        previous: IMRelationshipMilestone
    ) -> IMRelationshipMilestone {
        if rupture >= 8 {
            return .fractured
        }
        if previous == .fractured && repair >= 6 {
            return .recovering
        }
        if repair >= 8 && trust >= 8 && inconsistency <= 4 {
            return .trusted
        }
        if trust >= 6 && repair >= 6 && rupture <= 4 {
            return .openingUp
        }
        if trust >= 6 && inconsistency <= 6 {
            return .steady
        }
        if previous == .recovering && repair >= 7 && rupture <= 4 {
            return .steady
        }
        return .guarded
    }

    private static func updatedMilestoneHistory(
        current: [IMRelationshipMilestone],
        next: IMRelationshipMilestone
    ) -> [IMRelationshipMilestone] {
        var history = current
        if history.last != next {
            history.append(next)
        }
        return Array(history.suffix(6))
    }

    private static func updatedRuptureScore(
        current: Int,
        averageHostility: Int,
        averageDisengagement: Int,
        tolerance: IMPersonaToleranceProfile,
        evaluation: IMConversationEvaluation
    ) -> Int {
        let hostilityWeight = Int(round(Double(averageHostility) * Double(tolerance.sensitivity + tolerance.closureLikelihood) / 12.0))
        let disengagementWeight = Int(round(Double(averageDisengagement) * Double(11 - tolerance.patience) / 10.0))
        let relief = evaluation.composureScore >= 8 && evaluation.conversationScore >= 7 ? 2 : (evaluation.composureScore >= 7 ? 1 : 0)
        return clamp(current + hostilityWeight / 3 + disengagementWeight / 4 - relief)
    }

    private static func updatedRepairMomentum(
        current: Int,
        averageWarmth: Int,
        averageReciprocity: Int,
        evaluation: IMConversationEvaluation,
        ruptureScore: Int
    ) -> Int {
        let positiveSession = evaluation.conversationScore >= 7 && evaluation.toneMatch >= 7
        let gain = positiveSession ? max(1, (averageWarmth + averageReciprocity) / 6) : 0
        let drag = ruptureScore >= 7 ? 2 : (ruptureScore >= 5 ? 1 : 0)
        return clamp(current + gain - drag)
    }

    private static func updatedInconsistencyScore(
        current: Int,
        averageHostility: Int,
        averageWarmth: Int,
        averageDisengagement: Int,
        evaluation: IMConversationEvaluation
    ) -> Int {
        let volatility = abs(averageWarmth - averageHostility) >= 4 ? 2 : 0
        let unclearPenalty = evaluation.clarityScore <= 5 ? 1 : 0
        let disengagementPenalty = averageDisengagement >= 6 ? 2 : 0
        let stabilityRelief = evaluation.composureScore >= 8 && evaluation.clarityScore >= 7 ? 2 : 0
        return clamp(current + volatility + unclearPenalty + disengagementPenalty - stabilityRelief)
    }

    private static func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private static func tokenCount(in text: String, matches tokens: Set<String>) -> Int {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" })
            .reduce(into: 0) { count, token in
                if tokens.contains(String(token)) {
                    count += 1
                }
            }
    }

    private static func acknowledgementSignals(in text: String) -> Int {
        let lower = text.lowercased()
        let markers = [
            "that makes sense",
            "i hear you",
            "i get that",
            "thanks",
            "appreciate",
            "fair enough",
            "i'm sorry",
            "sorry"
        ]
        return markers.reduce(into: 0) { count, marker in
            if lower.contains(marker) {
                count += 1
            }
        }
    }

    private static func smoothedBaseline(current: Int, live: Int) -> Int {
        Int(round((Double(current) * 0.65) + (Double(live) * 0.35)))
    }

    private static func boundedDelta(_ value: Int, magnitude: Int) -> Int {
        max(-magnitude, min(magnitude, value))
    }

    private static func clamp(_ value: Int) -> Int {
        max(1, min(10, value))
    }
}

protocol IMConversationServicing {
    @MainActor
    func generateReply(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        state: IMConversationState,
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        context: IMSessionContext,
        latestUserSignal: IMUserMessageSignal?
    ) async throws -> IMConversationReply
}

protocol IMConversationEvaluatorServicing {
    @MainActor
    func evaluateConversation(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        finalState: IMConversationState?,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        context: IMSessionContext
    ) async throws -> IMConversationEvaluation
}

#if canImport(SwiftUI)
@MainActor
final class PracticeSettingsManager: ObservableObject {
    static let shared = PracticeSettingsManager()

    @Published var timedDifficulty: TimedPracticeDifficulty {
        didSet { UserDefaults.standard.set(timedDifficulty.rawValue, forKey: timedDifficultyKey) }
    }

    @Published var pressureModeEnabled: Bool {
        didSet { UserDefaults.standard.set(pressureModeEnabled, forKey: pressureModeKey) }
    }

    @Published var fillerAlertSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(fillerAlertSoundEnabled, forKey: fillerAlertSoundKey) }
    }

    private let timedDifficultyKey = "timedPracticeDifficulty"
    private let pressureModeKey = "pressureModeEnabled"
    private let fillerAlertSoundKey = "fillerAlertSoundEnabled"

    private init() {
        let rawValue = UserDefaults.standard.string(forKey: timedDifficultyKey)
        timedDifficulty = TimedPracticeDifficulty(rawValue: rawValue ?? "") ?? .easy
        pressureModeEnabled = UserDefaults.standard.bool(forKey: pressureModeKey)
        fillerAlertSoundEnabled = UserDefaults.standard.bool(forKey: fillerAlertSoundKey)
    }
}

@MainActor
final class CoachingProfileStore: ObservableObject {
    static let shared = CoachingProfileStore()

    @Published private(set) var profile: CoachingProfile?
    @Published private(set) var shouldPresentInitialOnboarding = false

    private let accountKey = "NoumAccountID"
    private let providerKey = "NoumAccountProvider"
    private let profileKeyPrefix = "coachingProfile."
    private let onboardingCompletionKeyPrefix = "coachingProfileOnboardingComplete."

    private init() {
        // Start with nil profile; AuthManager.deferStoreReloadForCurrentAccount()
        // will call reloadForCurrentAccount() after the first run-loop cycle,
        // avoiding synchronous Keychain + UserDefaults + JSON decode during
        // @StateObject creation.
    }

    var needsOnboarding: Bool {
        profile == nil
    }

    func save(_ profile: CoachingProfile) {
        guard let accountID = currentAccountID else { return }
        // Snapshot the prior voice BEFORE mutating self.profile so we
        // can detect a voice change and trigger a retroactive regen of
        // the most-recent PostRepCoachNote in the new voice. Initial
        // capture (previousVoice == nil) does not trigger a regen
        // because there's no rep history to regenerate against on a
        // fresh account; the next finalize will produce the first note
        // in the chosen voice naturally.
        let previousVoice = self.profile?.speakingStyleGoal
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey(for: accountID))
        }
        UserDefaults.standard.set(true, forKey: onboardingCompletionKey(for: accountID))
        shouldPresentInitialOnboarding = false
        syncProfileIfPossible(profile, accountID: accountID)
        paraphraseGoalIfNeeded(profile: profile, accountID: accountID)

        if let previousVoice, previousVoice != profile.speakingStyleGoal {
            PracticeSessionFinalizer.regenerateMostRecentNoteIfVoiceChanged(
                newVoice: profile.speakingStyleGoal
            )
        }
    }

    /// Single-shot AI paraphrase of the user's goal at capture time. Best-effort:
    /// silent on failure (no provider, no network, model error) — `displayableGoal`
    /// falls back to the deterministic template. Guarded so we never repeat the
    /// pass for the same profile, even across launches.
    private func paraphraseGoalIfNeeded(profile: CoachingProfile, accountID: String) {
        guard profile.paraphrasedGoal == nil else { return }
        Task { [weak self] in
            guard let self else { return }
            guard let paraphrase = await GoalParaphraseService.shared.paraphrase(profile: profile),
                  !paraphrase.isEmpty
            else { return }
            await MainActor.run {
                guard self.currentAccountID == accountID else { return }
                guard var current = self.profile, current.paraphrasedGoal == nil else { return }
                current.paraphrasedGoal = paraphrase
                self.profile = current
                if let data = try? JSONEncoder().encode(current) {
                    UserDefaults.standard.set(data, forKey: self.profileKey(for: accountID))
                }
                self.syncProfileIfPossible(current, accountID: accountID)
            }
        }
    }

    func reloadForCurrentAccount() {
        guard let accountID = currentAccountID else {
            profile = nil
            shouldPresentInitialOnboarding = false
            return
        }

        let loadedProfile = Self.loadProfile(forKey: profileKey(for: accountID))
        profile = loadedProfile

        if loadedProfile != nil {
            UserDefaults.standard.set(true, forKey: onboardingCompletionKey(for: accountID))
        }

        shouldPresentInitialOnboarding = false
    }

    func beginSession(isNewAccount: Bool) {
        guard let accountID = currentAccountID else {
            shouldPresentInitialOnboarding = false
            return
        }

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletionKey(for: accountID))
        shouldPresentInitialOnboarding = isNewAccount && !hasCompletedOnboarding && profile == nil
    }

    func endSession() {
        profile = nil
        shouldPresentInitialOnboarding = false
    }

    func replaceFromRemote(_ profile: CoachingProfile?, for accountID: String) {
        self.profile = profile
        if let profile, let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey(for: accountID))
            UserDefaults.standard.set(true, forKey: onboardingCompletionKey(for: accountID))
        }
        shouldPresentInitialOnboarding = false
    }

    #if DEBUG
    /// Debug-only injector for `DevSeedData`. Writes the profile against
    /// the current account ID (Keychain) or the `"guest"` namespace when
    /// no account is set, and refreshes the published `profile` so SwiftUI
    /// surfaces gated on `coachingProfileStore.profile != nil` light up
    /// immediately. Skips the backend sync + AI paraphrase side effects
    /// the production `save(_:)` triggers — seeded data is local-only.
    func replaceForDebug(_ profile: CoachingProfile?) {
        let accountID = currentAccountID ?? "guest"
        if let profile, let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey(for: accountID))
            UserDefaults.standard.set(true, forKey: onboardingCompletionKey(for: accountID))
        } else {
            UserDefaults.standard.removeObject(forKey: profileKey(for: accountID))
            UserDefaults.standard.removeObject(forKey: onboardingCompletionKey(for: accountID))
        }
        self.profile = profile
        shouldPresentInitialOnboarding = false
    }
    #endif

    private func profileKey(for accountID: String) -> String {
        "\(profileKeyPrefix)\(accountID)"
    }

    private func onboardingCompletionKey(for accountID: String) -> String {
        "\(onboardingCompletionKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private var currentProviderRawValue: String? {
        KeychainHelper.load(key: providerKey)
    }

    private static func loadProfile(forKey key: String) -> CoachingProfile? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(CoachingProfile.self, from: data) else { return nil }
        return profile
    }

    private func syncProfileIfPossible(_ profile: CoachingProfile, accountID: String) {
        guard let providerRawValue = currentProviderRawValue else { return }
        Task {
            await BackendSyncManager.shared.syncProfile(profile, accountID: accountID, providerRawValue: providerRawValue)
        }
    }
}

@MainActor
final class IMRelationshipStore: ObservableObject {
    static let shared = IMRelationshipStore()

    @Published private var profiles: [String: IMRelationshipProfile]

    private let accountKey = "NoumAccountID"
    private let providerKey = "NoumAccountProvider"

    private init() {
        // Start with empty profiles; reloadForCurrentAccount() is called
        // after the first run-loop cycle via AuthManager, avoiding synchronous
        // Keychain + UserDefaults + JSON decode during @StateObject creation.
        profiles = [:]
    }

    func reloadForCurrentAccount() {
        profiles = Self.loadProfiles(forKey: Self.storageKey(for: currentAccountID))
    }

    func endSession() {
        profiles = [:]
    }

    func profile(for scenario: IMConversationScenario) -> IMRelationshipProfile {
        let stored = profiles[scenario.rawValue] ?? IMRelationshipProfile.initial(for: scenario)
        return decayedProfile(from: stored)
    }

    func startingState(for scenario: IMConversationScenario) -> IMConversationState {
        profile(for: scenario).startingState()
    }

    func applySessionOutcome(
        scenario: IMConversationScenario,
        turns: [IMConversationTurn],
        finalState: IMConversationState,
        evaluation: IMConversationEvaluation
    ) -> IMRelationshipProfile {
        let updated = IMRelationshipHeuristics.updatedProfile(
            from: profile(for: scenario),
            turns: turns,
            finalState: finalState,
            evaluation: evaluation
        )
        profiles[scenario.rawValue] = updated
        persist()
        syncIfPossible()
        return updated
    }

    func replaceFromRemote(_ remoteProfiles: [IMRelationshipProfile]) {
        profiles = Dictionary(uniqueKeysWithValues: remoteProfiles.map { ($0.scenario.rawValue, $0) })
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Array(profiles.values)) {
            UserDefaults.standard.set(data, forKey: Self.storageKey(for: currentAccountID))
        }
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private var currentProviderRawValue: String? {
        KeychainHelper.load(key: providerKey)
    }

    private func syncIfPossible() {
        guard currentAccountID != nil, currentProviderRawValue != nil else { return }
    }

    private func decayedProfile(from profile: IMRelationshipProfile) -> IMRelationshipProfile {
        guard let lastInteractionDate = profile.lastInteractionDate else { return profile }
        let daysElapsed = Calendar.current.dateComponents([.day], from: lastInteractionDate, to: Date()).day ?? 0
        guard daysElapsed > 3 else { return profile }

        let decaySteps = min(3, daysElapsed / 7)
        guard decaySteps > 0 else { return profile }

        return IMRelationshipProfile(
            scenario: profile.scenario,
            sessionCount: profile.sessionCount,
            trustBaseline: max(4, profile.trustBaseline - decaySteps),
            engagementBaseline: max(4, profile.engagementBaseline - decaySteps),
            tensionBaseline: min(7, profile.tensionBaseline + (profile.scenario == .difficultConversation ? 1 : 0)),
            warmthScore: max(4, profile.warmthScore - decaySteps),
            reliabilityScore: max(4, profile.reliabilityScore - decaySteps),
            opennessScore: max(4, profile.opennessScore - decaySteps),
            reciprocityScore: max(4, profile.reciprocityScore - decaySteps),
            frictionScore: min(8, profile.frictionScore + (daysElapsed >= 21 ? 1 : 0)),
            ruptureScore: max(2, profile.ruptureScore - (daysElapsed >= 28 ? 1 : 0)),
            repairMomentum: max(3, profile.repairMomentum - decaySteps),
            inconsistencyScore: min(8, profile.inconsistencyScore + (daysElapsed >= 21 ? 1 : 0)),
            activeMilestone: profile.activeMilestone,
            milestoneHistory: profile.milestoneHistory,
            rememberedTopics: profile.rememberedTopics,
            callbackCue: profile.callbackCue,
            activeArcID: profile.activeArcID,
            activeArcStage: profile.activeArcStage,
            arcHistory: profile.arcHistory,
            continuitySummary: "\(profile.scenario.personaName) remembers the dynamic, but some ease has cooled with time, so you need to re-earn flow through relevance and steadiness. Old tension may soften slowly, but inconsistency is still noticed.",
            lastOutcomeTitle: profile.lastOutcomeTitle,
            lastOutcomeSummary: profile.lastOutcomeSummary,
            lastInteractionDate: profile.lastInteractionDate
        )
    }

    private static func storageKey(for accountID: String?) -> String {
        if let accountID, !accountID.isEmpty {
            return "imRelationshipProfiles.\(accountID)"
        }
        return "imRelationshipProfiles.guest"
    }

    private static func loadProfiles(forKey key: String) -> [String: IMRelationshipProfile] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([IMRelationshipProfile].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: decoded.map { ($0.scenario.rawValue, $0) })
    }
}

@MainActor
final class AISettingsManager: ObservableObject {
    static let shared = AISettingsManager()

    @Published private(set) var analysisCountThisMonth: Int {
        didSet { UserDefaults.standard.set(analysisCountThisMonth, forKey: countKey) }
    }

    private let countKey = "aiMonthlyAnalysisCount"
    private let monthKey = "aiMonthlyAnalysisMonth"
    private let disclosureKeyPrefix = "hasAcknowledgedAIDisclosure."

    // MARK: - Usage Tiers
    // Premium: generous 100/month — most active users won't hit this.
    // Free: 20/month — enough to experience value, encourages upgrade.
    // Exposed for the Settings AI-usage card so the upgrade CTA can
    // honestly cite the Pro number rather than hard-code a stale
    // duplicate. The runtime cap (used by `monthlyLimit`) still reads
    // these same constants.
    static let premiumMonthlyDebriefLimit: Int = 100
    static let freeMonthlyDebriefLimit: Int = 20
    private static let premiumMonthlyLimit = premiumMonthlyDebriefLimit
    private static let freeMonthlyLimit = freeMonthlyDebriefLimit

    /// The threshold (as fraction of limit) at which we surface a gentle heads-up.
    /// Set at 90% so users get a soft nudge, not a wall.
    static let usageAwarenessThreshold: Double = 0.90

    private init() {
        analysisCountThisMonth = UserDefaults.standard.integer(forKey: countKey)
        resetIfNeeded()
    }

    var activeProvider: AIProvider? {
        [.gemini, .openAI].first(where: hasAPIKey(for:))
    }

    /// Current monthly limit based on subscription tier.
    var monthlyLimit: Int {
        PremiumManager.shared.isPremium ? Self.premiumMonthlyLimit : Self.freeMonthlyLimit
    }

    var remainingAnalyses: Int {
        max(0, monthlyLimit - analysisCountThisMonth)
    }

    var canRequestAnalysis: Bool {
        activeProvider != nil && remainingAnalyses > 0
    }

    /// Whether the user is approaching their limit (≥90% used).
    /// Returns false if they still have plenty of headroom.
    var isApproachingLimit: Bool {
        let limit = monthlyLimit
        guard limit > 0 else { return true }
        return Double(analysisCountThisMonth) / Double(limit) >= Self.usageAwarenessThreshold
    }

    /// True when the monthly cap has been reached.
    var hasReachedLimit: Bool {
        analysisCountThisMonth >= monthlyLimit
    }

    /// Estimated date when the counter resets (first of next month).
    var resetDate: Date {
        let cal = Calendar.current
        let now = Date()
        if let nextMonth = cal.date(byAdding: .month, value: 1, to: cal.startOfDay(for: now)) {
            let comps = cal.dateComponents([.year, .month], from: nextMonth)
            return cal.date(from: comps) ?? nextMonth
        }
        return now
    }

    /// Human-readable reset date (e.g., "May 1").
    var resetDateFormatted: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d"
        return fmt.string(from: resetDate)
    }

    func recordAnalysis() {
        resetIfNeeded()
        analysisCountThisMonth += 1
    }

    func resetIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        let savedMonth = UserDefaults.standard.string(forKey: monthKey)
        if savedMonth != currentMonth {
            UserDefaults.standard.set(currentMonth, forKey: monthKey)
            analysisCountThisMonth = 0
        }
    }

    // MARK: - AI Transcript Disclosure

    /// Whether the current user has acknowledged that speech transcripts are sent to cloud AI.
    var hasAcknowledgedAIDisclosure: Bool {
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? "guest"
        return UserDefaults.standard.bool(forKey: disclosureKeyPrefix + accountID)
    }

    func acknowledgeAIDisclosure() {
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? "guest"
        UserDefaults.standard.set(true, forKey: disclosureKeyPrefix + accountID)
    }

    /// The user-facing name of the active AI provider (e.g., "Google Gemini", "OpenAI").
    var activeProviderDisplayName: String {
        switch activeProvider {
        case .gemini: return "Google Gemini"
        case .openAI: return "OpenAI"
        default: return "a cloud AI provider"
        }
    }

    private func hasAPIKey(for provider: AIProvider) -> Bool {
        guard let keyName = provider.environmentKey else { return false }

        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return true
        }

        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig") != nil
    }
}

@MainActor
enum IMModeAvailability {
    static var isAvailable: Bool {
        AISettingsManager.shared.activeProvider != nil || backendBaseURL != nil
    }

    private static var backendBaseURL: URL? {
        let rawValue =
            ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ??
            LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return URL(string: rawValue)
    }
}

enum IMModeServiceError: LocalizedError {
    case unavailable
    case replyGenerationFailed(String)
    case evaluationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "IM Mode is unavailable right now because no live AI provider or backend is configured."
        case .replyGenerationFailed(let reason):
            return "IM reply generation failed: \(reason)"
        case .evaluationFailed(let reason):
            return "IM evaluation failed: \(reason)"
        }
    }
}

@MainActor
final class IMVoicePlaybackSettingsManager: ObservableObject {
    static let shared = IMVoicePlaybackSettingsManager()

    @Published var engine: IMVoiceEngine {
        didSet { UserDefaults.standard.set(engine.rawValue, forKey: engineKey) }
    }

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: playbackEnabledKey) }
    }

    /// S5 — spoken replies in the Ask-Noum *coach chat* (distinct from the
    /// `isEnabled` flag above, which governs the IM *conversation rep* mode).
    /// They are deliberately separate surfaces with different defaults:
    ///   • IM rep voice (`isEnabled`) defaults ON — a conversation partner
    ///     that never speaks is a broken rep.
    ///   • Coach-chat voice (`askNoumSpokenRepliesEnabled`) now defaults ON
    ///     (A5 voice-first) — the coach speaks its replies by default so Ask
    ///     Noum reads as a spoken conversation with a coach, not a text thread.
    ///     The mute toggle is the explicit opt-out, and it is always respected.
    /// Reusing this existing settings owner (rather than a new store) keeps
    /// every voice-playback preference in one inspectable place. Persisted
    /// under its own key so toggling one never moves the other.
    @Published var askNoumSpokenRepliesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(askNoumSpokenRepliesEnabled, forKey: askNoumSpokenRepliesKey)
        }
    }

    @Published private(set) var lastResolvedEngineTitle: String = "None"
    @Published private(set) var lastPlaybackStatus: String = "Idle"
    @Published private(set) var lastPlaybackError: String?

    private let engineKey = "imVoicePlaybackEngine"
    private let playbackEnabledKey = "imVoicePlaybackEnabled"
    private let askNoumSpokenRepliesKey = "askNoumSpokenRepliesEnabled"

    private init() {
        if UserDefaults.standard.object(forKey: playbackEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: playbackEnabledKey)
        }
        if let storedEngine = UserDefaults.standard.string(forKey: engineKey),
           let parsedEngine = IMVoiceEngine(rawValue: storedEngine) {
            engine = parsedEngine
        } else {
            engine = .auto
        }
        isEnabled = UserDefaults.standard.bool(forKey: playbackEnabledKey)
        // A5 voice-first: resolve the coach-chat voice ON when the user has
        // never set it (absent key), so the coach speaks by default and Ask
        // Noum reads as a spoken conversation. An explicit opt-out (key present
        // = the user used the mute toggle) is always respected. Setting the
        // property in init does not fire `didSet`, so an untouched preference
        // stays absent and re-resolves to ON each launch until the user mutes.
        askNoumSpokenRepliesEnabled = Self.voiceFirstDefault(
            objectPresent: UserDefaults.standard.object(forKey: askNoumSpokenRepliesKey) != nil,
            stored: UserDefaults.standard.bool(forKey: askNoumSpokenRepliesKey)
        )
    }

    /// A5 — voice-first default semantics for the coach-chat voice: an absent
    /// preference resolves ON (the coach speaks by default); a present
    /// preference respects the stored value (the user's explicit mute choice).
    /// Pure + testable.
    static func voiceFirstDefault(objectPresent: Bool, stored: Bool) -> Bool {
        objectPresent ? stored : true
    }

    func recordPlaybackAttempt(resolvedEngine: IMVoiceEngine) {
        lastResolvedEngineTitle = resolvedEngine.title
        lastPlaybackStatus = "Attempting \(resolvedEngine.title)"
        lastPlaybackError = nil
    }

    func recordPlaybackSuccess(resolvedEngine: IMVoiceEngine) {
        lastResolvedEngineTitle = resolvedEngine.title
        lastPlaybackStatus = "Playing via \(resolvedEngine.title)"
        lastPlaybackError = nil
    }

    func recordPlaybackFallback(to fallbackEngine: IMVoiceEngine, reason: String) {
        lastResolvedEngineTitle = fallbackEngine.title
        lastPlaybackStatus = "Fell back to \(fallbackEngine.title)"
        lastPlaybackError = reason
    }

    func recordPlaybackFailure(resolvedEngine: IMVoiceEngine, reason: String) {
        lastResolvedEngineTitle = resolvedEngine.title
        lastPlaybackStatus = "Failed via \(resolvedEngine.title)"
        lastPlaybackError = reason
    }
}

enum IMVoiceEngine: String, Codable, Identifiable {
    case auto
    case backend
    case googleCloud
    case openAI

    static var allCases: [IMVoiceEngine] {
        [.auto, .googleCloud, .openAI]
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .backend:
            return "Backend"
        case .googleCloud:
            return "Google Cloud"
        case .openAI:
            return "AI"
        }
    }

    var subtitle: String {
        switch self {
        case .auto:
            return "Prefer Google Cloud first, then OpenAI, with backend voice only as the quiet fallback."
        case .backend:
            return "Use Noum backend voice synthesis when cloud voice providers are unavailable."
        case .googleCloud:
            return "Use Google Cloud Text-to-Speech as the primary premium voice path."
        case .openAI:
            return "Use OpenAI TTS as the backup premium voice if Google Cloud is unavailable."
        }
    }
}

#if canImport(AVFAudio)
@MainActor
final class IMMessageSpeaker: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = IMMessageSpeaker()

    private let playbackSettings = IMVoicePlaybackSettingsManager.shared
    private var audioPlayer: AVAudioPlayer?
    private var speechTask: Task<Void, Never>?

    /// True only while a cloud-TTS clip is *actually* playing on the
    /// shared `AVAudioPlayer`. Set true the moment `play()` succeeds in
    /// `playAudioData`, and cleared on BOTH natural finish
    /// (`audioPlayerDidFinishPlaying`) and barge-in (`stop()`) — so a
    /// "coach is speaking" UI can never stick.
    ///
    /// Bound to the REAL audio lifecycle, never a timer: `speak()` /
    /// `speakPrompt()` return on `play()` (clip start), not on finish,
    /// so any timer-based state would drift from the actual clip length.
    /// Additive `@Published` — no existing caller of `speak` / `speakPrompt`
    /// / `stop` changes behavior; views may OR this with their own
    /// on-device `AVSpeechSynthesizer.isSpeaking` for a combined state.
    ///
    /// Scope note: the on-device `AVSpeechSynthesizer` *offline fallback*
    /// is owned by the practice views (`TimedPracticeView` /
    /// `SuddenDeathPracticeView`), not by this class, so this flag tracks
    /// the cloud `AVAudioPlayer` path only.
    @Published private(set) var isSpeaking: Bool = false

    /// Optional listen → speak → listen handoff hook for the S5 voice
    /// conversation UI. Fired on the main actor exactly once per clip,
    /// when playback finishes *naturally* (not on barge-in `stop()`, where
    /// the caller initiated the interruption and already knows). Defaulted
    /// nil for back-compat; no current caller sets it.
    var onPlaybackFinished: (() -> Void)?
    private var lastFailureReason: String?
    private var hasPreparedAudioSession = false
    private var prewarmingKeys: Set<String> = []
    private var warmedKeys: Set<String> = []
    private var hasPrewarmedDefaultConnection = false

    // M25: monotonic generation counter for speak() invocations. Each
    // speak() increments this and captures the new value locally before
    // spawning the playback Task. Before audio actually plays we re-read
    // currentGeneration and bail if it moved — meaning a later speak()
    // (or stop()) has invalidated this in-flight request.
    //
    // Why: this single guard fixes BOTH the bug where round 1's audio
    // replays in round 2+ (an old fetch lands after stop() and plays
    // anyway) AND the text/audio drift bug (visible text matches the
    // latest reply.message but the audio still belongs to the previous
    // one because its fetch landed later). One source of truth — the
    // generation token — collapses both races.
    //
    // Exposed `internal` (not `private`) so the M25 race-fix tests can
    // verify advancement contracts without a network provider.
    internal private(set) var currentGeneration: UInt64 = 0

    /// Test seam: returns true when the supplied generation matches the
    /// current one (i.e. the in-flight request is still valid). This is
    /// the exact predicate the production playback paths use before
    /// calling `playAudioData`. Deterministic, no network.
    internal func isGenerationStillCurrent(_ generation: UInt64) -> Bool {
        generation == currentGeneration
    }

    /// Test seam: increments the generation counter the way `speak()`
    /// does and returns the new value, without doing any network or
    /// audio work. Lets the M25 tests exercise the token guard
    /// deterministically.
    internal func advanceGenerationForTesting() -> UInt64 {
        currentGeneration &+= 1
        return currentGeneration
    }

    /// Test seam: simulate a natural end-of-clip when there is no live
    /// `AVAudioPlayer` to deliver a real `audioPlayerDidFinishPlaying`
    /// callback (no audio is ever played in the test environment).
    /// Mirrors the natural-finish branch exactly: clears `isSpeaking` and
    /// fires `onPlaybackFinished`. Deterministic, no audio.
    internal func finishPlaybackForTesting() {
        audioPlayer = nil
        isSpeaking = false
        onPlaybackFinished?()
    }

    /// Test seam: deterministically set the speaking flag the way a
    /// successful `play()` in `playAudioData` does, without real audio.
    /// Lets the state-transition tests assert that `stop()` /
    /// `finishPlaybackForTesting()` clear a flag that was actually set.
    internal func setSpeakingForTesting(_ value: Bool) {
        isSpeaking = value
    }

    override private init() {
        super.init()
    }

    func speak(_ text: String, setup: IMConversationSetup) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        currentGeneration &+= 1
        let myGeneration = currentGeneration
        speechTask = Task { [weak self] in
            guard let self else { return }
            let candidateEngines = candidateEngines(for: setup)
            guard let selectedEngine = candidateEngines.first else {
                playbackSettings.recordPlaybackFailure(
                    resolvedEngine: .auto,
                    reason: "No cloud voice provider is configured."
                )
                return
            }
            for (index, engine) in candidateEngines.enumerated() {
                // Generation gate before each engine attempt — a later
                // speak() or stop() in the meantime invalidates this
                // whole fallback chain too, not just the current request.
                guard myGeneration == self.currentGeneration else { return }
                playbackSettings.recordPlaybackAttempt(resolvedEngine: engine)
                if await play(trimmed, using: engine, setup: setup, generation: myGeneration) {
                    playbackSettings.recordPlaybackSuccess(resolvedEngine: engine)
                    return
                }
                if index < candidateEngines.count - 1 {
                    let fallbackEngine = candidateEngines[index + 1]
                    playbackSettings.recordPlaybackFallback(
                        to: fallbackEngine,
                        reason: lastFailureReason ?? "\(engine.title) did not return playable audio."
                    )
                }
            }
            // Final guard: don't record a stale failure if we've already
            // been invalidated by a newer speak().
            guard myGeneration == self.currentGeneration else { return }
            playbackSettings.recordPlaybackFailure(
                resolvedEngine: selectedEngine,
                reason: lastFailureReason ?? "Provider playback did not return playable audio."
            )
        }
    }

    func prepareForPlayback() {
        guard !hasPreparedAudioSession else { return }
        do {
            #if canImport(AVFoundation)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
            #endif
            hasPreparedAudioSession = true
            lastFailureReason = nil
        } catch {
            lastFailureReason = "Audio playback preparation error: \(error.localizedDescription)"
        }
    }

    func prewarmPreferredEngineIfNeeded(for setup: IMConversationSetup) {
        guard let engine = candidateEngines(for: setup).first else { return }
        let warmupKey = "\(engine.rawValue):\(setup.scenario.rawValue)"
        guard !warmedKeys.contains(warmupKey), !prewarmingKeys.contains(warmupKey) else { return }
        prewarmingKeys.insert(warmupKey)

        Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let didWarm = await self.prewarm(engine: engine, setup: setup)
            await MainActor.run {
                self.prewarmingKeys.remove(warmupKey)
                if didWarm {
                    self.warmedKeys.insert(warmupKey)
                }
            }
        }
    }

    func prewarmDefaultConnectionIfNeeded() {
        guard !hasPrewarmedDefaultConnection else { return }
        hasPrewarmedDefaultConnection = true
        prewarmPreferredEngineIfNeeded(
            for: IMConversationSetup(
                scenario: .socialCatchUp,
                targetTone: .confident
            )
        )
    }

    func resetSessionPlaybackState() { stop() }

    // MARK: - Prompt Readout (Timed Practice Mode)

    /// Speak a practice prompt using the best available cloud TTS provider.
    /// Returns true if cloud audio was successfully played, false if caller should fall back to on-device TTS.
    func speakPrompt(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        stop()

        // Build a minimal setup for voice selection — use a calm, coaching-like persona
        let setup = IMConversationSetup(scenario: .workUpdate, targetTone: .confident)
        let engines = candidateEngines(for: setup)
        guard !engines.isEmpty else { return false }

        for engine in engines {
            if await playPrompt(trimmed, using: engine, setup: setup) {
                return true
            }
        }
        return false
    }

    private func playPrompt(_ text: String, using engine: IMVoiceEngine, setup: IMConversationSetup) async -> Bool {
        // Prompt readout shares the M25 generation token so a new speak()
        // arriving mid-readout invalidates the in-flight prompt fetch the
        // same way it invalidates a stale message fetch. The prompt path
        // doesn't increment the token itself; it threads the current
        // value through so the same `playAudioData` guard applies.
        let generation = currentGeneration
        switch engine {
        case .openAI:
            return await playPromptWithOpenAI(text)
        case .googleCloud:
            return await playWithGoogleCloud(text, setup: setup, generation: generation)
        case .backend:
            return await playWithBackend(text, setup: setup, generation: generation)
        case .auto:
            return false
        }
    }

    /// OpenAI TTS specifically tuned for prompt readout — calm, clear coaching voice
    private func playPromptWithOpenAI(_ text: String) async -> Bool {
        guard let apiKey = openAIAPIKey(),
              let endpoint = URL(string: "https://api.openai.com/v1/audio/speech") else {
            return false
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8

        let body = OpenAITTSSpeechRequest(
            model: "tts-1",
            voice: "nova",
            input: text,
            responseFormat: "mp3",
            instructions: "Read this speaking prompt clearly and warmly, like a calm speaking coach presenting a question. Natural pace, confident tone, slight warmth. Do not rush."
        )
        request.httpBody = try? JSONEncoder().encode(body)
        guard request.httpBody != nil else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return false
            }
            return playAudioData(data)
        } catch {
            return false
        }
    }

    func stop() {
        // Why: bumping the generation invalidates any in-flight playback
        // request whose Task body has already passed the network fetch
        // but not yet hit playAudioData. The Task.cancel() below catches
        // pre-fetch and during-fetch cases via URLSession's cancellation;
        // the generation token catches the post-fetch, pre-play window
        // that was the root cause of stale-audio replay in M25.
        currentGeneration &+= 1
        speechTask?.cancel()
        speechTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        // Barge-in / teardown: clear the speaking flag immediately so a
        // "coach is speaking" UI never sticks. AVAudioPlayer.stop() does
        // not invoke audioPlayerDidFinishPlaying, and onPlaybackFinished
        // is intentionally NOT fired here (the caller initiated the
        // interruption and already knows).
        isSpeaking = false
    }

    /// S5 — true when at least one cloud TTS provider is configured, so the
    /// spoken-reply path can actually produce audio. Lets a voice-mode toggle
    /// follow `AskNoumVoiceInput.isAvailable` discipline: HIDE the affordance
    /// when speaking can't be served rather than offering a dead toggle that
    /// silently no-ops on tap.
    ///
    /// Mirrors the engine resolution `candidateEngines(for:)` does for the
    /// `.auto` engine (the user-facing default) — any of Google Cloud (token
    /// or key), OpenAI, or a configured backend voice. Unlike the practice
    /// views, the Ask-Noum coach chat does NOT own an on-device
    /// `AVSpeechSynthesizer` fallback (that owner lives in the rep views), so
    /// "no cloud provider" genuinely means "no spoken reply here" — and the
    /// honest UI is to hide the toggle, never to pretend.
    var canSpeakReplies: Bool {
        googleCloudAccessToken() != nil
            || googleCloudAPIKey() != nil
            || openAIAPIKey() != nil
            || backendTTSAvailable()
    }

    private func candidateEngines(for setup: IMConversationSetup) -> [IMVoiceEngine] {
        func appendUnique(_ engine: IMVoiceEngine, to engines: inout [IMVoiceEngine]) {
            guard !engines.contains(engine) else { return }
            engines.append(engine)
        }

        var engines: [IMVoiceEngine] = []
        switch playbackSettings.engine {
        case .auto:
            if googleCloudAccessToken() != nil || googleCloudAPIKey() != nil {
                appendUnique(.googleCloud, to: &engines)
            }
            if openAIAPIKey() != nil {
                appendUnique(.openAI, to: &engines)
            }
            if backendTTSAvailable() {
                appendUnique(.backend, to: &engines)
            }
        case .backend:
            appendUnique(.backend, to: &engines)
        case .googleCloud:
            appendUnique(.googleCloud, to: &engines)
            if openAIAPIKey() != nil {
                appendUnique(.openAI, to: &engines)
            }
            if backendTTSAvailable() {
                appendUnique(.backend, to: &engines)
            }
        case .openAI:
            appendUnique(.openAI, to: &engines)
            if backendTTSAvailable() {
                appendUnique(.backend, to: &engines)
            }
        }
        return engines
    }

    private func play(_ text: String, using engine: IMVoiceEngine, setup: IMConversationSetup, generation: UInt64) async -> Bool {
        switch engine {
        case .backend:
            return await playWithBackend(text, setup: setup, generation: generation)
        case .googleCloud:
            return await playWithGoogleCloud(text, setup: setup, generation: generation)
        case .openAI:
            return await playWithOpenAI(text, setup: setup, generation: generation)
        case .auto:
            return false
        }
    }

    private func prewarm(engine: IMVoiceEngine, setup: IMConversationSetup) async -> Bool {
        switch engine {
        case .googleCloud:
            guard let request = googleCloudRequest(for: ".", setup: setup) else { return false }
            return await executeWarmupRequest(request)
        case .openAI:
            guard let request = openAIRequest(for: ".", setup: setup) else { return false }
            return await executeWarmupRequest(request)
        case .backend:
            guard let request = backendRequest(for: ".", setup: setup) else { return false }
            return await executeWarmupRequest(request)
        case .auto:
            return false
        }
    }

    private func executeWarmupRequest(_ request: URLRequest) async -> Bool {
        do {
            var warmupRequest = request
            warmupRequest.timeoutInterval = 8
            let (_, response) = try await URLSession.shared.data(for: warmupRequest)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func preferredLanguageCode() -> String {
        let current = Locale.autoupdatingCurrent
        if current.identifier.hasPrefix("en_GB") || TimeZone.autoupdatingCurrent.identifier == "Europe/London" {
            return "en-GB"
        }
        return "en-US"
    }

    private func backendTTSAvailable() -> Bool {
        backendBaseURL() != nil
    }

    private func backendBaseURL() -> URL? {
        let rawValue =
            ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ??
            LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return URL(string: rawValue)
    }

    private func backendAPIKey() -> String? {
        ProcessInfo.processInfo.environment["BACKEND_API_KEY"] ??
        LocalConfigLoader.value(forKey: "BACKEND_API_KEY", plistNamed: "BackendConfig")
    }

    private func playWithBackend(_ text: String, setup: IMConversationSetup, generation: UInt64) async -> Bool {
        guard let request = backendRequest(for: text, setup: setup) else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                lastFailureReason = "Backend TTS request failed."
                return false
            }

            // Why: generation gate before any audio actually plays — a
            // newer speak() (or a stop()) since this fetch began means
            // this audio belongs to a stale text. Drop it silently so
            // round-1 audio never replays over round-2 text.
            guard generation == currentGeneration else { return false }

            if let mimeType = http.value(forHTTPHeaderField: "Content-Type"),
               mimeType.contains("audio"),
               playAudioData(data) {
                return true
            }

            let payload = try JSONDecoder().decode(BackendIMTTSResponse.self, from: data)
            guard let audioData = Data(base64Encoded: payload.audioBase64) else {
                lastFailureReason = "Backend TTS returned invalid audio."
                return false
            }
            guard generation == currentGeneration else { return false }
            return playAudioData(audioData)
        } catch {
            lastFailureReason = "Backend TTS error: \(error.localizedDescription)"
            return false
        }
    }

    private func playAudioData(_ data: Data) -> Bool {
        do {
            prepareForPlayback()
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.prepareToPlay()
            audioPlayer = player
            // Only treat the clip as "speaking" if play() actually starts.
            // The generation token is already verified by every caller
            // before this method runs, so the clip we're starting here is
            // the current one — never stale audio.
            let didStart = player.play()
            isSpeaking = didStart
            lastFailureReason = nil
            return didStart
        } catch {
            isSpeaking = false
            lastFailureReason = "Audio playback error: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - AVAudioPlayerDelegate

    /// Natural end-of-clip. Hops to the main actor (the protocol callback
    /// is `nonisolated`) and clears `isSpeaking` only if the player that
    /// finished is still the live one — a clip superseded by a newer
    /// `speak()` / barge-in must not clear the state of the new clip.
    /// Fires `onPlaybackFinished` for the listen → speak → listen handoff.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Identity check: ignore a finish callback from a player we've
            // already replaced (a newer clip is now current).
            guard self.audioPlayer === player else { return }
            self.audioPlayer = nil
            self.isSpeaking = false
            self.onPlaybackFinished?()
        }
    }

    private func googleCloudAccessToken() -> String? {
        if let value = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_TTS_ACCESS_TOKEN"], !value.isEmpty {
            return value
        }
        if let value = ProcessInfo.processInfo.environment["GCP_TTS_ACCESS_TOKEN"], !value.isEmpty {
            return value
        }
        if let value = LocalConfigLoader.value(forKey: "GOOGLE_CLOUD_TTS_ACCESS_TOKEN", plistNamed: "AIConfig"),
           !value.isEmpty {
            return value
        }
        if let value = LocalConfigLoader.value(forKey: "GCP_TTS_ACCESS_TOKEN", plistNamed: "AIConfig"),
           !value.isEmpty {
            return value
        }
        return nil
    }

    private func googleCloudAPIKey() -> String? {
        if let value = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_TTS_API_KEY"], !value.isEmpty {
            return value
        }
        if let value = ProcessInfo.processInfo.environment["GCP_TTS_API_KEY"], !value.isEmpty {
            return value
        }
        if let value = LocalConfigLoader.value(forKey: "GOOGLE_CLOUD_TTS_API_KEY", plistNamed: "AIConfig"),
           !value.isEmpty {
            return value
        }
        if let value = LocalConfigLoader.value(forKey: "GCP_TTS_API_KEY", plistNamed: "AIConfig"),
           !value.isEmpty {
            return value
        }
        return nil
    }

    private func googleCloudProjectID() -> String? {
        if let value = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT_ID"], !value.isEmpty {
            return value
        }
        if let value = ProcessInfo.processInfo.environment["GCP_PROJECT_ID"], !value.isEmpty {
            return value
        }
        if let value = LocalConfigLoader.value(forKey: "GOOGLE_CLOUD_PROJECT_ID", plistNamed: "AIConfig"),
           !value.isEmpty {
            return value
        }
        if let value = LocalConfigLoader.value(forKey: "GCP_PROJECT_ID", plistNamed: "AIConfig"),
           !value.isEmpty {
            return value
        }
        return nil
    }

    private func googleCloudVoiceOverride(for scenario: IMConversationScenario) -> String? {
        let key: String
        switch scenario {
        case .socialCatchUp:
            key = "GOOGLE_CLOUD_TTS_VOICE_MAYA"
        case .workUpdate:
            key = "GOOGLE_CLOUD_TTS_VOICE_JORDAN"
        case .difficultConversation:
            key = "GOOGLE_CLOUD_TTS_VOICE_SAM"
        case .networking:
            key = "GOOGLE_CLOUD_TTS_VOICE_ALEX"
        }

        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }
        if let value = LocalConfigLoader.value(forKey: key, plistNamed: "AIConfig") {
            return value
        }
        if let value = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_TTS_VOICE_DEFAULT"], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: "GOOGLE_CLOUD_TTS_VOICE_DEFAULT", plistNamed: "AIConfig")
    }

    private func preferredGoogleCloudVoice(for setup: IMConversationSetup) -> String {
        if let override = googleCloudVoiceOverride(for: setup.scenario) {
            return override
        }

        let languageCode = preferredLanguageCode()
        switch (languageCode, setup.scenario) {
        case ("en-GB", .socialCatchUp):
            return "en-GB-Chirp3-HD-Achernar"
        case ("en-GB", .networking):
            return "en-GB-Chirp3-HD-Achernar"
        case ("en-GB", .workUpdate):
            return "en-GB-Chirp3-HD-Orus"
        case ("en-GB", .difficultConversation):
            return "en-GB-Chirp3-HD-Orus"
        case ("en-US", .socialCatchUp):
            return "en-US-Chirp3-HD-Achernar"
        case ("en-US", .networking):
            return "en-US-Chirp3-HD-Achernar"
        case ("en-US", .workUpdate):
            return "en-US-Chirp3-HD-Orus"
        case ("en-US", .difficultConversation):
            return "en-US-Chirp3-HD-Orus"
        default:
            return "\(languageCode)-Chirp3-HD-Achernar"
        }
    }

    private func playWithGoogleCloud(_ text: String, setup: IMConversationSetup, generation: UInt64) async -> Bool {
        guard let request = googleCloudRequest(for: text, setup: setup) else {
            lastFailureReason = "Google Cloud TTS key or access token is missing."
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                let responseBody = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let http = response as? HTTPURLResponse {
                    lastFailureReason = "Google Cloud TTS request failed (\(http.statusCode)): \(responseBody ?? "No response body")"
                } else {
                    lastFailureReason = "Google Cloud TTS request failed."
                }
                return false
            }

            let payload = try JSONDecoder().decode(GoogleCloudTTSSpeechResponse.self, from: data)
            guard let audioData = Data(base64Encoded: payload.audioContent) else {
                lastFailureReason = "Google Cloud TTS returned invalid audio."
                return false
            }

            // Why: see speak() — generation gate stops stale audio from a
            // since-superseded request from being played over fresh text.
            guard generation == currentGeneration else { return false }
            return playAudioData(audioData)
        } catch {
            lastFailureReason = "Google Cloud TTS error: \(error.localizedDescription)"
            return false
        }
    }

    private func openAIAPIKey() -> String? {
        if let value = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: "OPENAI_API_KEY", plistNamed: "AIConfig")
    }

    private func preferredOpenAIVoice(for setup: IMConversationSetup) -> String {
        switch setup.scenario {
        case .socialCatchUp:
            return "coral"
        case .workUpdate:
            return "sage"
        case .difficultConversation:
            return "ash"
        case .networking:
            return setup.targetTone == .warm ? "shimmer" : "nova"
        }
    }

    private func playWithOpenAI(_ text: String, setup: IMConversationSetup, generation: UInt64) async -> Bool {
        guard let request = openAIRequest(for: text, setup: setup) else {
            lastFailureReason = "OpenAI TTS credentials are missing."
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                lastFailureReason = "OpenAI TTS request failed."
                return false
            }

            // Why: see speak() — generation gate. This is the canonical
            // race-fix path: an in-flight openAIRequest from round N can
            // finish AFTER round N+1's speak() has started; without this
            // guard playAudioData(data) would play N's audio over N+1's
            // visible text. Bailing here keeps spoken audio aligned with
            // the latest reply.message the user sees.
            guard generation == currentGeneration else { return false }
            return playAudioData(data)
        } catch {
            lastFailureReason = "OpenAI TTS error: \(error.localizedDescription)"
            return false
        }
    }

    private func openAIInstructions(for setup: IMConversationSetup) -> String {
        switch setup.scenario {
        case .socialCatchUp:
            return "Speak like a warm, natural friend in a short instant message voice note. Sound human, relaxed, and lightly upbeat. Keep the delivery concise and conversational."
        case .workUpdate:
            return "Speak clearly and professionally, like a calm coworker sending a quick voice note. Natural, steady, and confident. Avoid sounding robotic or theatrical."
        case .difficultConversation:
            return "Speak with calm directness and emotional control, like a real person in a slightly tense conversation. Keep it grounded, human, and short."
        case .networking:
            return "Speak like a warm, polished new connection in a short voice note. Sound approachable, natural, and socially confident."
        }
    }



    private func backendRequest(for text: String, setup: IMConversationSetup) -> URLRequest? {
        guard let baseURL = backendBaseURL() else { return nil }
        let endpoint = baseURL.appending(path: "/v1/tts/im")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = backendAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-Noum-API-Key")
        }
        if let accountID = AuthManager.shared.currentAccountID {
            request.setValue(accountID, forHTTPHeaderField: "X-Noum-Account-ID")
        }
        if let provider = AuthManager.shared.currentAuthProviderRawValue {
            request.setValue(provider, forHTTPHeaderField: "X-Noum-Auth-Provider")
        }

        let body = BackendIMTTSRequest(
            text: text,
            languageCode: preferredLanguageCode(),
            scenario: setup.scenario.rawValue,
            targetTone: setup.targetTone.rawValue,
            personaName: setup.scenario.personaName
        )
        request.httpBody = try? JSONEncoder().encode(body)
        return request.httpBody == nil ? nil : request
    }

    private func googleCloudRequest(for text: String, setup: IMConversationSetup) -> URLRequest? {
        guard var components = URLComponents(string: "https://texttospeech.googleapis.com/v1/text:synthesize") else {
            return nil
        }

        let accessToken = googleCloudAccessToken()
        let apiKey = googleCloudAPIKey()
        guard accessToken != nil || apiKey != nil else { return nil }

        if let apiKey {
            components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }

        guard let endpoint = components.url else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if accessToken != nil, let projectID = googleCloudProjectID() {
            request.setValue(projectID, forHTTPHeaderField: "x-goog-user-project")
        }

        let body = GoogleCloudTTSSpeechRequest(
            input: GoogleCloudTTSInput(text: text),
            voice: GoogleCloudTTSVoiceSelectionParams(
                languageCode: preferredLanguageCode(),
                name: preferredGoogleCloudVoice(for: setup)
            ),
            audioConfig: GoogleCloudTTSAudioConfig(audioEncoding: "MP3", speakingRate: 0.94)
        )
        request.httpBody = try? JSONEncoder().encode(body)
        return request.httpBody == nil ? nil : request
    }

    private func openAIRequest(for text: String, setup: IMConversationSetup) -> URLRequest? {
        guard let apiKey = openAIAPIKey(),
              let endpoint = URL(string: "https://api.openai.com/v1/audio/speech") else {
            return nil
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OpenAITTSSpeechRequest(
            model: "tts-1",
            voice: preferredOpenAIVoice(for: setup),
            input: text,
            responseFormat: "mp3",
            instructions: openAIInstructions(for: setup)
        )
        request.httpBody = try? JSONEncoder().encode(body)
        return request.httpBody == nil ? nil : request
    }

}

private struct BackendIMTTSRequest: Codable {
    let text: String
    let languageCode: String
    let scenario: String
    let targetTone: String
    let personaName: String

    enum CodingKeys: String, CodingKey {
        case text
        case languageCode = "language_code"
        case scenario
        case targetTone = "target_tone"
        case personaName = "persona_name"
    }
}

private struct BackendIMTTSResponse: Codable {
    let audioBase64: String

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base64"
    }
}

private struct OpenAITTSSpeechRequest: Codable {
    let model: String
    let voice: String
    let input: String
    let responseFormat: String
    let instructions: String

    enum CodingKeys: String, CodingKey {
        case model
        case voice
        case input
        case instructions
        case responseFormat = "response_format"
    }
}

private struct GoogleCloudTTSSpeechRequest: Codable {
    let input: GoogleCloudTTSInput
    let voice: GoogleCloudTTSVoiceSelectionParams
    let audioConfig: GoogleCloudTTSAudioConfig

    enum CodingKeys: String, CodingKey {
        case input
        case voice
        case audioConfig = "audioConfig"
    }
}

private struct GoogleCloudTTSInput: Codable {
    let text: String
}

private struct GoogleCloudTTSVoiceSelectionParams: Codable {
    let languageCode: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case languageCode = "languageCode"
        case name
    }
}

private struct GoogleCloudTTSAudioConfig: Codable {
    let audioEncoding: String
    let speakingRate: Double

    enum CodingKeys: String, CodingKey {
        case audioEncoding = "audioEncoding"
        case speakingRate = "speakingRate"
    }
}

private struct GoogleCloudTTSSpeechResponse: Codable {
    let audioContent: String

    enum CodingKeys: String, CodingKey {
        case audioContent = "audioContent"
    }
}


#endif
#endif

struct PracticeEvaluation {
    let score: Int
    let xpEarned: Int
    let headline: String
    let feedback: String
    let segments: [PracticeScoreSegment]
    let insights: [String]
    var categories: [FeedbackCategory] = []
    var strongMoments: [String] = []
    var weakMoments: [String] = []
    var durationAssessment: DurationAssessment = .onTarget
    var targetRange: (min: Double, target: Double, max: Double) = (30, 60, 120)
}

struct PracticeScoreSegment: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tintName: String
}

// MARK: - Next Rep Drill System

/// A single, opinionated drill recommendation generated from session metrics.
struct DrillRecommendation: Identifiable {
    let id = UUID()
    let type: DrillType
    let title: String
    let reason: String           // Why this drill, based on what happened
    let constraint: String       // The one rule to follow
    let successGoal: String      // How to know you nailed it
    let icon: String             // SF Symbol
    let tint: Color

    /// The drill types available in the system, ordered by priority.
    enum DrillType: String {
        case pauseAndBreathe       // High fillers — replace fillers with silence
        case slowOpen              // Rushed pace — deliberately slow first 2 sentences
        case extendAndDevelop      // Too short — hit a minimum duration
        case structuredResponse    // No structure — use intro/point/close
        case cleanRun              // Moderate fillers — aim for zero
        case powerOpen             // Weak opening — nail the first sentence
        case paceSetter            // Too slow — hit a natural pace
        case closingStatement      // Weak close — end with a deliberate sentence
        case depthDive             // Shallow content — develop one idea fully
        case confidenceHold        // Good session — maintain under harder conditions
        case freeRepeat            // Clean session — just do it again
    }
}

/// Generates a single drill recommendation from raw session metrics.
/// Deterministic, template-driven — no AI call needed.
enum DrillEngine {

    static func recommend(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        score: Int,
        feedbackCategories: [FeedbackCategory],
        durationAssessment: DurationAssessment
    ) -> DrillRecommendation {

        let wpm = duration > 0 ? Double(wordCount) / duration * 60 : 0
        let isMinimal = wordCount < 5 || duration < 5

        // Helper to find worst category
        func rating(for dimension: String) -> FeedbackRating? {
            feedbackCategories.first(where: { $0.dimension == dimension })?.rating
        }

        // --- Priority cascade (most impactful issue first) ---

        // 1. No speech / minimal effort → just get them talking
        if wordCount == 0 || isMinimal {
            return DrillRecommendation(
                type: .extendAndDevelop,
                title: "Commit to 30 Seconds",
                reason: "Your last attempt was too short to practice anything meaningful.",
                constraint: "Keep talking for at least 30 seconds — no stopping early.",
                successGoal: "Reach 30 seconds with a clear point",
                icon: "timer",
                tint: .orange
            )
        }

        // 2. High fillers (≥5) → pause & breathe drill
        if fillerCount >= 5 {
            return DrillRecommendation(
                type: .pauseAndBreathe,
                title: "Silent Transitions",
                reason: "You used \(fillerCount) filler words — most appeared between ideas when your brain was searching for the next thought.",
                constraint: "Pause silently for a full beat before every new point. No \"um\", \"uh\", or \"like\" allowed.",
                successGoal: "Fewer than 2 filler words",
                icon: "waveform.path",
                tint: .red
            )
        }

        // 3. Very short duration (<15s) → extend
        if duration < 15 {
            return DrillRecommendation(
                type: .extendAndDevelop,
                title: "Develop the Thought",
                reason: "Your answer was only \(Int(duration)) seconds — too short to show structure or control.",
                constraint: "After your opening, add one example and one closing sentence. Don't stop until you've made all three.",
                successGoal: "Speak for at least 30 seconds with 3 distinct sections",
                icon: "text.line.last.and.arrowtriangle.forward",
                tint: .orange
            )
        }

        // 4. Rushed pace above the shared band → slow open
        if wpm > ConversationalPaceBand.maxWPM {
            return DrillRecommendation(
                type: .slowOpen,
                title: "Slow Your Start",
                reason: "Your pace hit \(Int(wpm)) WPM — noticeably fast. Speed undermines clarity even when the content is strong.",
                constraint: "Deliberately slow your first two sentences. Count one beat between them.",
                successGoal: "Pace inside \(ConversationalPaceBand.displayRange) WPM",
                icon: "hare.fill",
                tint: .orange
            )
        }

        // 5. Moderate fillers (2-4) → clean run
        if fillerCount >= 2 {
            return DrillRecommendation(
                type: .cleanRun,
                title: "Zero Filler Run",
                reason: "You had \(fillerCount) filler words — they cluster at transition points and make you sound less certain.",
                constraint: "Deliver your answer with zero filler words. Replace every urge to say \"um\" with silence.",
                successGoal: "Zero filler words",
                icon: "sparkles",
                tint: Color(.systemIndigo)
            )
        }

        // 6. Weak opening
        if rating(for: "Opening") == .couldImprove {
            return DrillRecommendation(
                type: .powerOpen,
                title: "Nail the First Line",
                reason: "Your opening didn't grab attention. A strong first sentence sets confidence for everything after.",
                constraint: "Start with a clear, declarative statement — no hedge words, no throat-clearing.",
                successGoal: "Opening rated OK or better",
                icon: "bolt.fill",
                tint: .blue
            )
        }

        // 7. Weak structure
        if rating(for: "Structure") == .couldImprove {
            return DrillRecommendation(
                type: .structuredResponse,
                title: "Build a Framework",
                reason: "Your answer lacked clear structure. Without a framework, ideas blur together.",
                constraint: "Use a strict 3-part structure: opening statement, one supporting example, closing sentence.",
                successGoal: "Structure rated OK or better",
                icon: "list.number",
                tint: .blue
            )
        }

        // 8. Weak close
        if rating(for: "Close") == .couldImprove {
            return DrillRecommendation(
                type: .closingStatement,
                title: "Stick the Landing",
                reason: "Your answer trailed off instead of ending with intention. A strong close leaves a lasting impression.",
                constraint: "End with one deliberate closing sentence that summarizes your main point.",
                successGoal: "Close rated OK or better",
                icon: "flag.checkered",
                tint: .purple
            )
        }

        // 9. Too slow below the shared band, duration ≥15s
        if wpm > 0 && wpm < ConversationalPaceBand.minWPM && duration >= 15 {
            return DrillRecommendation(
                type: .paceSetter,
                title: "Find Your Flow",
                reason: "Your pace was \(Int(wpm)) WPM — quite slow. Hesitation can make you sound uncertain.",
                constraint: "Commit to each sentence before starting it, then deliver at conversational speed — no long pauses mid-thought.",
                successGoal: "Pace inside \(ConversationalPaceBand.displayRange) WPM",
                icon: "metronome.fill",
                tint: .blue
            )
        }

        // 10. Shallow depth
        if rating(for: "Depth") == .couldImprove {
            return DrillRecommendation(
                type: .depthDive,
                title: "Go Deeper",
                reason: "Your answer stayed surface-level. One well-developed idea beats three shallow ones.",
                constraint: "Pick one point and give a specific, concrete example to support it.",
                successGoal: "Depth rated OK or better",
                icon: "arrow.down.to.line",
                tint: .blue
            )
        }

        // 11. Good session (score ≥7) → confidence hold / free repeat
        if score >= 7 {
            return DrillRecommendation(
                type: .confidenceHold,
                title: "Hold the Standard",
                reason: "Strong session. Now prove it wasn't a one-off — repeat the same quality on the same prompt.",
                constraint: "Match or beat your score. Stay clean, stay structured, stay in control.",
                successGoal: "Score \(score) or higher",
                icon: "flame.fill",
                tint: .green
            )
        }

        // 12. Default fallback — free repeat with structure focus
        return DrillRecommendation(
            type: .freeRepeat,
            title: "One More Rep",
            reason: "Your delivery had room to improve. The best way to get better is to try again with intention.",
            constraint: "Focus on a strong open, one clear point, and a deliberate close.",
            successGoal: "Improve your overall score",
            icon: "arrow.clockwise",
            tint: .blue
        )
    }
}

// MARK: - Feedback Categories (7 dimensions)

enum FeedbackRating: String, Codable, CaseIterable {
    case good = "Good"
    case ok = "OK"
    case couldImprove = "Could improve"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "good":
            self = .good
        case "ok", "okay":
            self = .ok
        case "couldimprove", "could_improve", "could improve":
            self = .couldImprove
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown feedback rating: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var tint: String {
        switch self {
        case .good: return "green"
        case .ok: return "yellow"
        case .couldImprove: return "orange"
        }
    }

    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .ok: return "minus.circle.fill"
        case .couldImprove: return "arrow.up.circle.fill"
        }
    }
}

struct FeedbackCategory: Identifiable, Codable {
    var id: String { dimension }
    let dimension: String   // Opening, Structure, Relevance, Depth, Clarity, Pace, Close
    let rating: FeedbackRating
    let note: String        // Short coaching note, e.g. "Strong hook" or "Try a clearer opening line"

    static let dimensions = ["Opening", "Structure", "Relevance", "Depth", "Clarity", "Pace", "Close"]
}

// MARK: - AI Video Analysis Result

struct VideoAnalysisResult: Codable {
    let posture: FeedbackRating
    let postureNote: String
    let eyeContact: FeedbackRating
    let eyeContactNote: String
    let facialExpression: FeedbackRating
    let facialExpressionNote: String
    let gestureUse: FeedbackRating
    let gestureNote: String
    let energyConfidence: FeedbackRating
    let energyNote: String
    let presenceDelivery: FeedbackRating
    let presenceNote: String
    let overallNote: String
}

enum VideoAnalysisError: LocalizedError, Equatable {
    case localeUnsupported
    case providerNotVisionCapable
    case noUsableFrames
    case invalidProviderRead

    var errorDescription: String? {
        switch self {
        case .localeUnsupported:
            return "Video analysis is currently available only for English practice."
        case .providerNotVisionCapable:
            return "Video analysis requires a vision-capable AI provider."
        case .noUsableFrames:
            return "Noum could not extract usable frames from this recording."
        case .invalidProviderRead:
            return "The video analysis did not produce a usable visual read."
        }
    }
}

enum VideoAnalysisContract {
    static func localeSupportsAI(_ locale: PracticeLocale) -> Bool {
        locale.aiSupported
    }

    static func providerSupportsVision(_ provider: AIProvider) -> Bool {
        switch provider {
        case .openAI, .gemini:
            return true
        case .none, .deepSeek:
            return false
        }
    }

    static func normalized(_ result: VideoAnalysisResult) -> VideoAnalysisResult? {
        guard let postureNote = boundedNote(result.postureNote, wordLimit: 18),
              let eyeContactNote = boundedNote(result.eyeContactNote, wordLimit: 18),
              let facialExpressionNote = boundedNote(result.facialExpressionNote, wordLimit: 18),
              let gestureNote = boundedNote(result.gestureNote, wordLimit: 18),
              let energyNote = boundedNote(result.energyNote, wordLimit: 18),
              let presenceNote = boundedNote(result.presenceNote, wordLimit: 18),
              let overallNote = boundedNote(result.overallNote, wordLimit: 42) else {
            return nil
        }

        return VideoAnalysisResult(
            posture: result.posture,
            postureNote: postureNote,
            eyeContact: result.eyeContact,
            eyeContactNote: eyeContactNote,
            facialExpression: result.facialExpression,
            facialExpressionNote: facialExpressionNote,
            gestureUse: result.gestureUse,
            gestureNote: gestureNote,
            energyConfidence: result.energyConfidence,
            energyNote: energyNote,
            presenceDelivery: result.presenceDelivery,
            presenceNote: presenceNote,
            overallNote: overallNote
        )
    }

    private static func boundedNote(_ value: String, wordLimit: Int) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, passesVisualContract(trimmed) else {
            return nil
        }
        return trimmed.truncatedToWordLimit(wordLimit)
    }

    private static func passesVisualContract(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        guard !value.contains("!"),
              !lowercased.contains("as an ai"),
              !lowercased.contains("as a language model"),
              !lowercased.contains("cannot see the frames"),
              !lowercased.contains("can't see the frames"),
              !lowercased.contains("without frames"),
              !lowercased.contains("no frames"),
              !lowercased.contains("generic video analysis"),
              !lowercased.contains("common areas speakers") else {
            return false
        }
        return true
    }
}

struct PaceSnapshot {
    let wordsPerMinute: Int
    let label: String
    let coachNote: String
}

struct SpeakingIdentitySnapshot {
    let identity: String
    let evidence: String
    let coachingNote: String
}

private struct StyleSignalSnapshot {
    let hedgeScore: Int
    let authorityScore: Int
    let warmthScore: Int
    let storyScore: Int
    let conciseScore: Int
    let executiveScore: Int
    let persuasiveScore: Int
    let repetitionScore: Int
    let averageSentenceLength: Double
    let uniqueWordRatio: Double
    let questionCount: Int
}

enum PracticeEvaluator {
    static func evaluateTimedPractice(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        difficulty: TimedPracticeDifficulty,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?,
        transcriptConfidence: Double? = nil,
        question: String? = nil
    ) -> PracticeEvaluation {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = wordCount(in: cleanTranscript)
        let durationProgress = durationRangeScore(duration, difficulty: difficulty)
        // Content cap raised from 35 → 65 words. 35 was ~12s of speech and
        // gave full content credit too easily — the user's real-device
        // 8/10 read came partly from this cap being too lenient.
        let contentProgress = min(Double(wordCount) / 65.0, 1.0)
        // Prompt-grounded relevance read — feeds the Relevance *rating* only.
        // The numeric score below still reads contentProgress, so no score
        // moves from this. nil/thin prompt -> high default (no down-rate).
        let relevanceRead = promptRelevance(prompt: question, transcript: cleanTranscript)
        let wordsPerMinute = paceValue(wordCount: wordCount, duration: duration)
        let paceSnapshot = paceSnapshot(for: wordsPerMinute, wordCount: wordCount)
        let styleSnapshot = speakingIdentitySnapshot(for: cleanTranscript, profile: profile)
        let styleTrend = styleTrendSnapshot(transcript: cleanTranscript, recentSessions: recentSessions, profile: profile)
        let styleAlignment = styleAlignmentScore(snapshot: styleSnapshot, profile: profile)
        let paceProgress = paceScore(for: wordsPerMinute, wordCount: wordCount)
        let isLowConfidence = (transcriptConfidence ?? 1.0) < 0.6
        let fillerPenaltyMultiplier = isLowConfidence ? 0.6 : 1.0  // Reduce 40% when audio quality is poor
        // Filler penalty: linear up to 4 fillers, then accelerates so 6+
        // genuinely costs the score. Old cap of 3.0 meant 10 fillers
        // looked the same as 4 — that hid bad reps.
        let fillerPenalty: Double = {
            let raw: Double
            if fillerCount <= 4 {
                raw = Double(fillerCount) * 0.8
            } else {
                raw = 3.2 + Double(fillerCount - 4) * 1.1
            }
            return min(raw * fillerPenaltyMultiplier, 5.5)
        }()
        let difficultyBonus: Double = {
            switch difficulty {
            case .free: return 0.0
            case .easy: return 0.2
            case .medium: return 0.5
            case .hard: return 0.8
            }
        }()

        let trends = trendSnapshot(fillerCount: fillerCount, duration: duration, recentSessions: recentSessions)

        let score: Int
        if wordCount < 3 || duration < 3 {
            score = 1
        } else {
            // Honest-assessment recalibration. Old formula: base 1.0 +
            // (3.2 * dur + 2.8 * content + 2.0 * pace + 1.5 * style) -
            // fillerPenalty + diffBonus. That floored the score at ~6 even
            // for poor speech because pace 80 WPM still scored 0.72 and
            // content capped at 35 words. New formula:
            //   • drops the base 1.0 floor (0.5 instead)
            //   • content carries less weight (was 2.8, now 2.4) since the cap is harder to hit
            //   • pace and duration carry more (they're the honest signal)
            //   • style alignment carries less (it's a soft signal that
            //     shouldn't lift a poor delivery)
            let voiceBonus = voiceDeliveryBonus(
                profile: profile,
                wordCount: wordCount,
                duration: duration,
                fillerCount: fillerCount,
                wordsPerMinute: wordsPerMinute
            )
            let rawScore = 0.5
                + (durationProgress * 3.4)
                + (contentProgress * 2.4)
                + (paceProgress * 2.6)
                + (styleAlignment * 1.0)
                - fillerPenalty
                + difficultyBonus
                + voiceBonus
            score = max(1, min(10, Int(round(rawScore))))
        }

        let xpBase = Double(score * 8)
        let xpFromDuration = durationProgress * 18
        let xpEarned = max(5, Int(round((xpBase + xpFromDuration) * difficulty.xpMultiplier)))

        let baseHeadline: String
        switch score {
        case 9...10:
            baseHeadline = "Table-topics ready"
        case 7...8:
            baseHeadline = "Solid response"
        case 4...6:
            baseHeadline = "Building momentum"
        default:
            baseHeadline = "Good warmup"
        }
        let headline = isLowConfidence ? "Based on what we could hear" : baseHeadline

        let durationAssessment = assessDuration(duration, difficulty: difficulty)

        let feedback: String
        if wordCount < 3 || duration < 3 {
            feedback = "This response ended before the answer could develop. Aim for a clear opening, one supporting point, and a brief close."
        } else if durationAssessment == .tooShort && fillerCount <= 2 {
            let range = difficulty.targetRange
            feedback = "Your answer was only \(Int(duration))s — the target range is \(Int(range.min))–\(Int(range.max))s. Give your answer more room to develop."
        } else if durationAssessment == .tooLong {
            let range = difficulty.targetRange
            feedback = "At \(Int(duration))s you went well past the \(Int(range.max))s mark. Tighten the structure: opening, one strong point, then close."
        } else if fillerCount == 0 && durationProgress >= 0.8 {
            feedback = "Strong control. You kept the answer clean while giving it enough shape to sound complete."
        } else if fillerCount <= 2 && durationProgress >= 0.6 {
            feedback = "A solid response overall. On the next round, give the middle section a little more development."
        } else if fillerCount > 4 {
            feedback = "The structure is there, but filler words are getting in the way. Slow the pace slightly and let pauses do the work."
        } else {
            feedback = "A worthwhile pass. Keep the answer moving and make each transition a little cleaner."
        }

        let segments = [
            PracticeScoreSegment(title: "Timing", value: durationAssessment.rawValue, tintName: durationAssessment == .onTarget ? "green" : "orange"),
            PracticeScoreSegment(title: "Content", value: "+\(Int(round(contentProgress * 3)))", tintName: "orange"),
            PracticeScoreSegment(title: "Pace", value: paceSnapshot.label, tintName: "green"),
            PracticeScoreSegment(title: "Voice", value: styleAlignmentLabel(for: styleAlignment), tintName: "indigo"),
            PracticeScoreSegment(title: "Filler penalty", value: "-\(Int(round(fillerPenalty)))", tintName: "red"),
            PracticeScoreSegment(title: "Difficulty", value: difficulty.title, tintName: "purple")
        ]

        var insights = timedModeInsights(
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            wordsPerMinute: wordsPerMinute,
            trends: trends,
            paceSnapshot: paceSnapshot,
            transcript: cleanTranscript,
            relevance: relevanceRead
        )
        insights.append(styleAlignmentInsight(styleSnapshot: styleSnapshot, profile: profile, alignment: styleAlignment))
        if let styleTrendNote = styleTrendInsight(styleTrend, profile: profile) {
            insights.append(styleTrendNote)
        }
        insights.append(styleSnapshot.coachingNote)
        if isLowConfidence {
            insights.insert("Audio quality was lower than usual — filler count may be approximate.", at: 0)
        }

        // Generate 7-dimension feedback categories
        let categories = buildFeedbackCategories(
            wordCount: wordCount,
            duration: duration,
            fillerCount: fillerCount,
            wordsPerMinute: wordsPerMinute,
            durationProgress: durationProgress,
            contentProgress: contentProgress,
            paceProgress: paceProgress,
            transcript: cleanTranscript,
            // When the evidence floor isn't met (nil/thin prompt or thin
            // transcript) pass nil so buildFeedbackCategories falls back to
            // the old contentProgress proxy — byte-identical to today on
            // weak evidence, never an upward or downward drift. Only a real,
            // floor-met read overrides the rating.
            relevanceProgress: relevanceRead.evidenceFloorMet ? relevanceRead.progress : nil
        )

        // Strong and weak moments
        let strongMoments = buildStrongMoments(score: score, fillerCount: fillerCount, duration: duration, wordsPerMinute: wordsPerMinute)
        let weakMoments = buildWeakMoments(score: score, fillerCount: fillerCount, duration: duration, wordsPerMinute: wordsPerMinute)

        return PracticeEvaluation(
            score: score,
            xpEarned: xpEarned,
            headline: headline,
            feedback: feedback,
            segments: segments,
            insights: Array(insights.prefix(3)),
            categories: categories,
            strongMoments: strongMoments,
            weakMoments: weakMoments,
            durationAssessment: durationAssessment,
            targetRange: difficulty.targetRange
        )
    }

    // MARK: - Feedback Category Builder

    private static func buildFeedbackCategories(
        wordCount: Int, duration: TimeInterval, fillerCount: Int,
        wordsPerMinute: Double, durationProgress: Double, contentProgress: Double,
        paceProgress: Double, transcript: String, relevanceProgress: Double? = nil
    ) -> [FeedbackCategory] {
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let sentenceCount = sentences.count
        let hasStrongOpen = sentenceCount > 0 && sentences[0].split(separator: " ").count >= 5
        let hasClose = sentenceCount > 1 && (
            transcript.lowercased().hasSuffix(".") ||
            transcript.lowercased().contains("in conclusion") ||
            transcript.lowercased().contains("to sum up") ||
            transcript.lowercased().contains("overall") ||
            duration >= 40
        )

        let opening: FeedbackRating = hasStrongOpen && fillerCount <= 1 ? .good : (hasStrongOpen ? .ok : .couldImprove)
        let structure: FeedbackRating = sentenceCount >= 3 && duration >= 20 ? .good : (sentenceCount >= 2 ? .ok : .couldImprove)
        // Relevance now rates on the prompt-grounded read when available
        // (drop-in for the old contentProgress proxy), falling back to
        // contentProgress for back-compat (nil prompt / legacy callers).
        // Same thresholds, same copy — only the gating signal changes.
        let relevanceBasis = relevanceProgress ?? contentProgress
        let relevance: FeedbackRating = relevanceBasis >= 0.7 ? .good : (relevanceBasis >= 0.4 ? .ok : .couldImprove)
        let depth: FeedbackRating = durationProgress >= 0.7 && wordCount >= 40 ? .good : (durationProgress >= 0.4 ? .ok : .couldImprove)
        let clarity: FeedbackRating = fillerCount <= 1 && wordsPerMinute <= 160 ? .good : (fillerCount <= 3 ? .ok : .couldImprove)
        let pace: FeedbackRating = paceProgress >= 0.7 ? .good : (paceProgress >= 0.4 ? .ok : .couldImprove)
        let close: FeedbackRating = hasClose && duration >= 25 ? .good : (hasClose || duration >= 20 ? .ok : .couldImprove)

        return [
            FeedbackCategory(dimension: "Opening", rating: opening, note: opening == .good ? "Clear, confident start" : opening == .ok ? "Decent start — tighten the first sentence" : "Try a stronger opening line"),
            FeedbackCategory(dimension: "Structure", rating: structure, note: structure == .good ? "Well-organized answer" : structure == .ok ? "Add one more supporting point" : "Break into intro → point → close"),
            FeedbackCategory(dimension: "Relevance", rating: relevance, note: relevance == .good ? "Stayed on topic" : relevance == .ok ? "Mostly relevant" : "Connect more directly to the prompt"),
            FeedbackCategory(dimension: "Depth", rating: depth, note: depth == .good ? "Good detail and development" : depth == .ok ? "Push for more examples" : "Expand your supporting points"),
            FeedbackCategory(dimension: "Clarity", rating: clarity, note: clarity == .good ? "Clean, minimal fillers" : clarity == .ok ? "A few fillers crept in" : "Filler words interrupted flow"),
            FeedbackCategory(dimension: "Pace", rating: pace, note: pace == .good ? "Comfortable, natural pace" : pace == .ok ? "Slightly rushed" : "Slow down and use pauses"),
            FeedbackCategory(dimension: "Close", rating: close, note: close == .good ? "Strong finish" : close == .ok ? "Ended a bit abruptly" : "Add a deliberate closing sentence"),
        ]
    }

    private static func buildStrongMoments(score: Int, fillerCount: Int, duration: TimeInterval, wordsPerMinute: Double) -> [String] {
        var moments: [String] = []
        if fillerCount == 0 { moments.append("Zero filler words — clean delivery") }
        if duration >= 50 { moments.append("Sustained a full-length answer") }
        if wordsPerMinute >= 120 && wordsPerMinute <= 155 { moments.append("Natural, well-paced delivery") }
        if score >= 8 { moments.append("Confident structure from open to close") }
        return Array(moments.prefix(3))
    }

    private static func buildWeakMoments(score: Int, fillerCount: Int, duration: TimeInterval, wordsPerMinute: Double) -> [String] {
        var moments: [String] = []
        if fillerCount >= 4 { moments.append("Filler words disrupted flow (\(fillerCount) counted)") }
        if duration < 15 { moments.append("Answer ended too quickly to develop") }
        if wordsPerMinute > 170 { moments.append("Pace was rushed — slow down") }
        if score <= 3 { moments.append("Structure needs work — try intro → point → close") }
        return Array(moments.prefix(3))
    }

    static func evaluateSuddenDeathPractice(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        pressureEventsHandled: Int,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?,
        transcriptConfidence: Double? = nil
    ) -> PracticeEvaluation {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = wordCount(in: cleanTranscript)
        let wordsPerMinute = paceValue(wordCount: wordCount, duration: duration)
        let paceSnapshot = paceSnapshot(for: wordsPerMinute, wordCount: wordCount)
        let styleSnapshot = speakingIdentitySnapshot(for: cleanTranscript, profile: profile)
        let styleTrend = styleTrendSnapshot(transcript: cleanTranscript, recentSessions: recentSessions, profile: profile)
        let styleAlignment = styleAlignmentScore(snapshot: styleSnapshot, profile: profile)
        let isLowConfidence = (transcriptConfidence ?? 1.0) < 0.6
        let level = max(1, Int(duration / 30.0) + 1)
        let durationProgress = min(duration / Double(level * 30), 1.0)
        let contentProgress = min(Double(wordCount) / 24.0, 1.0)
        let paceProgress = paceScore(for: wordsPerMinute, wordCount: wordCount)
        let fillerPenaltyMultiplier = isLowConfidence ? 0.6 : 1.0
        let fillerPenalty = min(Double(fillerCount) * 2.0 * fillerPenaltyMultiplier, 6.0)
        let trends = trendSnapshot(fillerCount: fillerCount, duration: duration, recentSessions: recentSessions)

        let score: Int
        if wordCount < 3 || duration < 3 {
            score = 1
        } else if wordCount < 8 || duration < 8 {
            score = max(2, min(4, Int(round(2.5 + contentProgress + durationProgress - fillerPenalty))))
        } else {
            let pressureBonus = min(Double(level - 1) * 0.8, 3.2)
            let eventBonus = min(Double(pressureEventsHandled) * 0.35, 1.4)
            let voiceBonus = voiceDeliveryBonus(
                profile: profile,
                wordCount: wordCount,
                duration: duration,
                fillerCount: fillerCount,
                wordsPerMinute: wordsPerMinute
            )
            let rawScore = 2.0 + (durationProgress * 2.4) + (contentProgress * 2.5) + (paceProgress * 1.2) + (styleAlignment * 1.4) - fillerPenalty + (fillerCount == 0 ? 2.0 : 0.0) + pressureBonus + eventBonus + voiceBonus
            score = max(1, min(10, Int(round(rawScore))))
        }

        let xpEarned = max(5, Int(round(Double(score * 9) + (duration / 6.0) + Double(level - 1) * 18.0 + Double(pressureEventsHandled * 8))))
        let headline: String
        switch score {
        case 9...10:
            headline = level >= 3 ? "High-pressure composure" : "Composed under pressure"
        case 6...8:
            headline = "Held up under pressure"
        default:
            headline = "Good warmup"
        }
        let feedback: String
        if wordCount < 3 || duration < 3 {
            feedback = "That round ended before the answer developed. Go again immediately and finish one complete opening thought."
        } else if fillerCount == 0 && level >= 3 {
            feedback = "Strong control under pressure. You kept the run alive deep into the harder levels without losing composure."
        } else if fillerCount == 0 && duration >= 15 {
            feedback = "Strong control under pressure. You stayed clean long enough for the answer to feel composed."
        } else if fillerCount > 0 {
            feedback = "A filler word ended the run. Keep the opening deliberate, then protect your pauses as the pressure level climbs."
        } else {
            feedback = "You kept the round alive, but the answer still needs more shape to feel complete."
        }

        let segments = [
            PracticeScoreSegment(title: "Control", value: fillerCount == 0 ? "+2" : "-\(min(6, fillerCount * 2))", tintName: fillerCount == 0 ? "green" : "red"),
            PracticeScoreSegment(title: "Survival", value: "\(Int(duration))s", tintName: "blue"),
            PracticeScoreSegment(title: "Content", value: "+\(Int(round(contentProgress * 3)))", tintName: "orange"),
            PracticeScoreSegment(title: "Pace", value: paceSnapshot.label, tintName: "green"),
            PracticeScoreSegment(title: "Voice", value: styleAlignmentLabel(for: styleAlignment), tintName: "indigo"),
            PracticeScoreSegment(title: "Pressure level", value: "Level \(level)", tintName: "purple"),
            PracticeScoreSegment(title: "Pressure events", value: "\(pressureEventsHandled)", tintName: "pink")
        ]

        var insights = sharedTrendInsights(trends: trends)
        if fillerCount == 0 {
            insights.append(level >= 2
                ? "You reached level \(level), so the pressure stayed high long enough to feel more like a real high-stakes speaking moment."
                : "You stayed filler-free. Next step is surviving into level 2 without losing structure.")
        } else {
            insights.append(level >= 2
                ? "The run broke under higher pressure, so rehearse calmer pauses as the level climbs."
                : "The round ended on a filler word, so rehearse a calmer first sentence and cleaner pauses.")
        }
        if pressureEventsHandled > 0 {
            insights.append("You handled \(pressureEventsHandled) live pressure prompt\(pressureEventsHandled == 1 ? "" : "s") before the run ended.")
        }
        insights.append(styleAlignmentInsight(styleSnapshot: styleSnapshot, profile: profile, alignment: styleAlignment))
        if let styleTrendNote = styleTrendInsight(styleTrend, profile: profile) {
            insights.append(styleTrendNote)
        }
        insights.append(paceSnapshot.coachNote)
        if isLowConfidence {
            insights.insert("Audio quality was lower than usual — filler count may be approximate.", at: 0)
        }
        insights.append(styleSnapshot.coachingNote)

        return PracticeEvaluation(
            score: score,
            xpEarned: xpEarned,
            headline: headline,
            feedback: feedback,
            segments: segments,
            insights: Array(insights.prefix(3))
        )
    }

    static func evaluateAhCounterPractice(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?,
        transcriptConfidence: Double? = nil
    ) -> PracticeEvaluation {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = wordCount(in: cleanTranscript)
        let durationProgress = min(duration / 45.0, 1.0)
        let contentProgress = min(Double(wordCount) / 40.0, 1.0)
        let wordsPerMinute = paceValue(wordCount: wordCount, duration: duration)
        let paceSnapshot = paceSnapshot(for: wordsPerMinute, wordCount: wordCount)
        let styleSnapshot = speakingIdentitySnapshot(for: cleanTranscript, profile: profile)
        let styleTrend = styleTrendSnapshot(transcript: cleanTranscript, recentSessions: recentSessions, profile: profile)
        let styleAlignment = styleAlignmentScore(snapshot: styleSnapshot, profile: profile)
        let isLowConfidence = (transcriptConfidence ?? 1.0) < 0.6
        let paceProgress = paceScore(for: wordsPerMinute, wordCount: wordCount)
        let fillerPenaltyMultiplier = isLowConfidence ? 0.6 : 1.0
        let fillerPenalty = min(Double(fillerCount) * 0.8 * fillerPenaltyMultiplier, 5.0)
        let trends = trendSnapshot(fillerCount: fillerCount, duration: duration, recentSessions: recentSessions)

        let score: Int
        if wordCount < 4 || duration < 4 {
            score = 1
        } else {
            let voiceBonus = voiceDeliveryBonus(
                profile: profile,
                wordCount: wordCount,
                duration: duration,
                fillerCount: fillerCount,
                wordsPerMinute: wordsPerMinute
            )
            let rawScore = 2.0 + (durationProgress * 2.5) + (contentProgress * 2.0) + (paceProgress * 1.5) + (styleAlignment * 1.6) + max(0, 3.0 - fillerPenalty) + voiceBonus
            score = max(1, min(10, Int(round(rawScore))))
        }

        let xpEarned = max(5, Int(round(Double(score * 7) + (durationProgress * 14))))
        let headline: String
        switch score {
        case 8...10: headline = "Good awareness"
        case 5...7: headline = "Useful awareness rep"
        default: headline = "Good warmup"
        }

        let feedback: String
        if wordCount < 4 || duration < 4 {
            feedback = "This was too short to expose the pattern properly. Give the next rep enough time for your habits to show up."
        } else if fillerCount <= 1 {
            feedback = "Strong awareness. You kept the filler count low while letting the answer breathe."
        } else if fillerCount <= 3 {
            feedback = "A useful awareness pass. You can feel where filler words creep in, so slow those moments down next time."
        } else {
            feedback = "This drill surfaced a real filler habit. Repeat it and focus on replacing the first filler with silence."
        }

        let segments = [
            PracticeScoreSegment(title: "Awareness", value: fillerCount <= 1 ? "+3" : "+\(max(1, 4 - fillerCount))", tintName: "green"),
            PracticeScoreSegment(title: "Depth", value: "+\(Int(round(durationProgress * 2)))", tintName: "blue"),
            PracticeScoreSegment(title: "Content", value: "+\(Int(round(contentProgress * 2)))", tintName: "orange"),
            PracticeScoreSegment(title: "Pace", value: paceSnapshot.label, tintName: "purple"),
            PracticeScoreSegment(title: "Voice", value: styleAlignmentLabel(for: styleAlignment), tintName: "indigo"),
            PracticeScoreSegment(title: "Filler penalty", value: "-\(Int(round(fillerPenalty)))", tintName: "red")
        ]

        var insights = sharedTrendInsights(trends: trends)
        if fillerCount <= 2 {
            insights.append("You kept filler words relatively low in a free-form rep. Now keep that same awareness on tougher prompts.")
        } else {
            insights.append("This rep surfaced where filler words appear under less structure, which is useful coaching data.")
        }
        insights.append(styleAlignmentInsight(styleSnapshot: styleSnapshot, profile: profile, alignment: styleAlignment))
        if let styleTrendNote = styleTrendInsight(styleTrend, profile: profile) {
            insights.append(styleTrendNote)
        }
        insights.append(paceSnapshot.coachNote)
        insights.append(styleSnapshot.coachingNote)
        if isLowConfidence {
            insights.insert("Audio quality was lower than usual — filler count may be approximate.", at: 0)
        }

        return PracticeEvaluation(
            score: score,
            xpEarned: xpEarned,
            headline: headline,
            feedback: feedback,
            segments: segments,
            insights: Array(insights.prefix(3))
        )
    }

    private static func wordCount(in transcript: String) -> Int {
        transcript.split { !$0.isLetter && !$0.isNumber }.count
    }

    // MARK: - Prompt-grounded relevance (deterministic, association not causation)
    //
    // Replaces the old wordCount/65 relevance proxy for the Relevance
    // *rating* on the 7-dimension card. The proxy rewarded length: a long
    // fluent answer that never engaged the question's content words read
    // "Stayed on topic". This reducer instead asks the one thing a coach
    // checks first — did the answer engage what was actually asked — by
    // lexical overlap of the prompt's content words with the transcript's.
    //
    // It is deliberately CONSERVATIVE. Lexical overlap is association on
    // weak evidence, never a verdict: a nil/thin prompt or a thin
    // transcript defaults the rating HIGH (it can never *down-rate* on
    // absent/weak evidence — it behaves exactly like the old length proxy
    // there), and even a clear miss only ever softens the rating to
    // "Mostly relevant", never to a confident "off-topic" from overlap
    // alone. The harsh band stays reachable only via the existing
    // contentProgress fallback (truly tiny/empty reps).
    //
    // The numeric SCORE is untouched: contentProgress still feeds rawScore.
    // Only the Relevance category *rating* consumes this read this pass.

    /// Conservative 0...1 relevance read of `transcript` against `prompt`
    /// by content-word lexical overlap. Pure: no I/O, no singletons.
    struct PromptRelevanceRead: Equatable {
        /// 0...1 fraction of the prompt's distinct content words echoed in
        /// the WHOLE transcript (Jaccard-lite: |prompt ∩ transcript| / |prompt|).
        /// This is the *magnitude* read — "is the point present anywhere" — and
        /// is what the deterministic Relevance rating consumes.
        let overlap: Double
        /// Count of distinct prompt content words considered (post stop-filter).
        let promptContentWords: Int
        /// True once `promptContentWords >= minPromptContentWordsForRelevance`
        /// AND the transcript is long enough to judge against. When false the
        /// rating falls back to the high `relevanceAbsentDefault`.
        let evidenceFloorMet: Bool
        /// 0...1 value the Relevance rating consumes (drop-in for the old
        /// contentProgress in the rating only).
        let progress: Double
        /// 0...1 fraction of the prompt's distinct content words echoed in just
        /// the FIRST sentence/clause of the transcript (same split as
        /// `openerAnchor`). This is the *positional* read — "did the point lead
        /// or arrive late" — and is what makes `promptAnswerVerdict` genuinely
        /// distinguish a buried lede (present overall, absent from the lead)
        /// from an answer that led with the point. Defaulted to 0 so the field
        /// is back-compatible for any construction that predates the positional
        /// read; the rating never consumes it, so a 0 default cannot move a
        /// score. Always 0 below the evidence floor (no positional claim on
        /// thin evidence).
        var firstSentenceOverlap: Double = 0

        init(
            overlap: Double,
            promptContentWords: Int,
            evidenceFloorMet: Bool,
            progress: Double,
            firstSentenceOverlap: Double = 0
        ) {
            self.overlap = overlap
            self.promptContentWords = promptContentWords
            self.evidenceFloorMet = evidenceFloorMet
            self.progress = progress
            self.firstSentenceOverlap = firstSentenceOverlap
        }
    }

    // Named, asserted thresholds — every boundary is locked by a test.
    /// Below this the prompt is too thin to judge an answer against.
    static let minPromptContentWordsForRelevance: Int = 3
    /// Below this the transcript is too thin for a confident relevance read
    /// (mirrors the thin-rep gates elsewhere in the evaluator).
    static let minTranscriptWordsForRelevance: Int = 12
    /// >= this fraction of prompt content words echoed -> clearly on-topic.
    static let relevanceStrongOverlap: Double = 0.30
    /// < this fraction -> a clear miss (still only "mostly relevant", never
    /// a confident off-topic verdict from overlap alone).
    static let relevanceWeakOverlap: Double = 0.12
    /// nil/thin prompt OR thin transcript -> high default so the rating can
    /// never down-rate on absent/weak evidence.
    static let relevanceAbsentDefault: Double = 0.70

    /// Local content-word stop set for relevance overlap. Mirrors the
    /// established local-set pattern in this file (`repeatedContentWords`'s
    /// set) — the private `WordChoiceMetrics.stopWords` /
    /// `EloquenceEngine.stopwords` are private to other types and cannot be
    /// reused cross-type. Broader than the repeated-content set because the
    /// prompt phrasing ("should we", "what is", "tell me about") carries
    /// more function words than a transcript body.
    private static let relevanceStopWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "any", "can",
        "her", "was", "one", "our", "out", "his", "has", "had", "how", "who",
        "why", "did", "does", "this", "that", "with", "your", "from", "they",
        "have", "what", "when", "were", "will", "would", "should", "could",
        "about", "there", "their", "them", "then", "than", "into", "more",
        "some", "such", "only", "very", "just", "most", "over", "also", "been",
        "being", "which", "while", "these", "those", "here", "make", "made",
        "much", "many", "like", "well", "even", "ever", "because", "really"
    ]

    /// Content words in `text`: lowercased tokens, tokenized with the same
    /// `split { !$0.isLetter && !$0.isNumber }` as `wordCount(in:)`, kept
    /// only when >= 4 chars and not in `relevanceStopWords`.
    ///
    /// Internal (not `private`) so the deterministic framework-drill detectors
    /// (`FrameworkDrillChecks`) reuse the SAME content-word tokenizer the prompt-
    /// relevance reducer uses — one canonical "what counts as a content word"
    /// rule across the prompt-answer verdict and the STAR/elevator-pitch checks,
    /// matching how `relevanceFirstSentence` / `promptAnswerVerdict` are already
    /// shared cross-file. Pure: no I/O, no singletons.
    static func relevanceContentWords(in text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !relevanceStopWords.contains($0) }
    }

    /// The first sentence/clause of `text`, used for the positional ("lead vs
    /// buried lede") read. Splits on `.`, `!`, `?` and returns the leading span
    /// — the IDENTICAL first-sentence rule `AICoachService.openerAnchor` uses to
    /// pick the quote it shows the user, so the verdict's notion of "the lead"
    /// is the same span the coach copy anchors to. Pure. Returns the whole
    /// trimmed string when there is no terminal punctuation (a single-sentence
    /// answer's lead IS the whole answer). Empty in, empty out.
    static func relevanceFirstSentence(in text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed
            .split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
    }

    /// Pure. Lexical-overlap relevance of `transcript` to `prompt`.
    ///
    /// Conservative contract:
    /// - nil/thin prompt OR thin transcript -> `evidenceFloorMet == false`,
    ///   `progress == relevanceAbsentDefault` (no down-rate on weak evidence).
    /// - otherwise map overlap to progress: `>= relevanceStrongOverlap` -> 1.0
    ///   (".good"); `< relevanceWeakOverlap` -> clamped to 0.45 (the ".ok"
    ///   band — never below 0.4, so overlap alone can never assert a confident
    ///   off-topic); linear in between.
    static func promptRelevance(prompt: String?, transcript: String) -> PromptRelevanceRead {
        let transcriptWords = wordCount(in: transcript)
        let promptWords = prompt.map(relevanceContentWords(in:)) ?? []
        let distinctPromptWords = Set(promptWords)
        let promptContentWordCount = distinctPromptWords.count

        // Evidence floor: too-thin prompt or too-thin transcript -> default
        // HIGH so relevance can never pull the rating down on weak evidence.
        guard promptContentWordCount >= minPromptContentWordsForRelevance,
              transcriptWords >= minTranscriptWordsForRelevance else {
            return PromptRelevanceRead(
                overlap: 0,
                promptContentWords: promptContentWordCount,
                evidenceFloorMet: false,
                progress: relevanceAbsentDefault
            )
        }

        let transcriptWordSet = Set(relevanceContentWords(in: transcript))
        let echoed = distinctPromptWords.intersection(transcriptWordSet).count
        let overlap = Double(echoed) / Double(promptContentWordCount)

        // Positional read: overlap of the prompt's content words against ONLY
        // the first sentence/clause. This is the signal that separates "the
        // point led" from "the point arrived late" — the whole-transcript
        // `overlap` above can't see WHERE the point landed. Computed over the
        // same distinct prompt set so the two fractions share a denominator and
        // `firstSentenceOverlap <= overlap` always holds (the lead is a subset
        // of the whole). The numeric SCORE never reads this; it feeds the
        // verdict (the rating) only.
        let firstSentenceWordSet = Set(relevanceContentWords(in: relevanceFirstSentence(in: transcript)))
        let echoedInLead = distinctPromptWords.intersection(firstSentenceWordSet).count
        let firstSentenceOverlap = Double(echoedInLead) / Double(promptContentWordCount)

        let progress: Double
        if overlap >= relevanceStrongOverlap {
            progress = 1.0
        } else if overlap < relevanceWeakOverlap {
            // Clear miss -> soften to the ".ok" band only. Never below 0.4,
            // so the rating can never assert a confident off-topic from
            // overlap alone (association not causation on weak evidence).
            progress = 0.45
        } else {
            // Linear ramp between the weak and strong thresholds, mapped onto
            // the [0.45, 1.0] rating range so the worst overlap-driven read is
            // still ".ok".
            let span = relevanceStrongOverlap - relevanceWeakOverlap
            let t = (overlap - relevanceWeakOverlap) / span
            progress = 0.45 + t * (1.0 - 0.45)
        }

        return PromptRelevanceRead(
            overlap: overlap,
            promptContentWords: promptContentWordCount,
            evidenceFloorMet: true,
            progress: progress,
            firstSentenceOverlap: firstSentenceOverlap
        )
    }

    /// The shared, now-POSITIONAL "lead vs buried lede" verdict that all four
    /// coaching surfaces read — the live chat coach (`CoachContextBuilder`
    /// PROMPT RELEVANCE), the Timed three-part coach note
    /// (`FeedbackEngine.buildPromptRelevanceNote`), the post-rep deterministic
    /// fallback (`AICoachService.deterministicFeedback`), and the AICoachService
    /// rubric line — so every surface speaks from ONE read of the stored
    /// `PracticeSession.prompt` rather than each re-deriving its own. Boundaries
    /// are the same named, test-locked overlap thresholds the Relevance rating
    /// uses, so the verdict can never disagree with the 7-dimension card.
    ///
    /// The bands are now about WHERE the point landed, not only HOW MUCH of the
    /// question was echoed — because "lead with your point" is the substance
    /// thing a coach actually checks, and four surfaces already claimed that
    /// positional reasoning in copy ("lead vs arrived late") the verdict never
    /// performed. The magnitude read still gates the Relevance *rating*; the
    /// position read decides the *verdict*.
    enum PromptAnswerVerdict: Equatable {
        /// The point LED: the question's key terms appeared in the first
        /// sentence/clause (`firstSentenceOverlap >= relevanceStrongOverlap`).
        /// The answer opened on the answer.
        case answered
        /// The point neither clearly led nor was clearly present-but-late:
        /// either it engaged the question only loosely, or it barely engaged it
        /// at all. This absorbs both the genuine in-between case and the
        /// low-whole-overlap "barely engaged it" case; it never claims a
        /// confident "off-topic" and never claims a buried lede it cannot see.
        /// Lexical association on the rep's own words only.
        case partial
        /// The point was BURIED: it is present across the rep
        /// (`overlap >= relevanceStrongOverlap`) but NOT in the lead
        /// (`firstSentenceOverlap < relevanceWeakOverlap`) — the answer was in
        /// there, it just arrived late. This is the only band that asserts the
        /// positional "arrived late" claim, and it is honest by construction:
        /// it requires the point to actually be present somewhere first. Lexical
        /// association on the rep's own words, never a confident "off-topic".
        case buried
    }

    /// Pure. Maps a `PromptRelevanceRead` onto the shared POSITIONAL verdict.
    /// Returns `nil` below the evidence floor (`evidenceFloorMet == false`)
    /// — no verdict on weak/absent evidence, exactly as the rating defaults
    /// HIGH there. The single point all four surfaces call into so they can
    /// never drift apart.
    ///
    /// Order matters and is deliberate:
    /// 1. The point led (`firstSentenceOverlap >= relevanceStrongOverlap`) ->
    ///    `.answered`. Because `firstSentenceOverlap <= overlap` always, an
    ///    `.answered` rep also clears the strong whole-overlap bar, so the
    ///    verdict can never say "answered" while the rating says weak.
    /// 2. The point is present overall (`overlap >= relevanceStrongOverlap`) but
    ///    NOT in the lead (`firstSentenceOverlap < relevanceWeakOverlap`) ->
    ///    `.buried`. The "arrived late" claim is TRUE here, not asserted.
    /// 3. Everything else -> `.partial`. This absorbs both the genuinely
    ///    in-between case AND the low-whole-overlap "barely engaged it" case;
    ///    neither earns the confident positional `.buried` claim.
    static func promptAnswerVerdict(for read: PromptRelevanceRead) -> PromptAnswerVerdict? {
        guard read.evidenceFloorMet else { return nil }
        if read.firstSentenceOverlap >= relevanceStrongOverlap { return .answered }
        if read.overlap >= relevanceStrongOverlap,
           read.firstSentenceOverlap < relevanceWeakOverlap {
            return .buried
        }
        return .partial
    }

    // MARK: - Argument logic (claim -> evidence -> implication chain)
    //
    // A deterministic, transcript-only read of whether an answer is structured
    // as an ARGUMENT — a claim that is both justified (evidence) and carried
    // forward to a consequence (implication) — rather than a bare assertion.
    //
    // This is DELIBERATELY DISTINCT from `promptAnswerVerdict` (topic
    // relevance / "did you answer the question"). A rep can be perfectly
    // on-topic and still be a flat assertion with no reasoning chain; and a rep
    // can be a tight claim->evidence->implication argument about something the
    // prompt never asked. Relevance reads the prompt overlap; this reads the
    // rep's own internal logical scaffold. The two never share a band.
    //
    // It is also distinct from the persuasion `claimCounter` framework drill
    // (`FrameworkDrillChecks`), which checks ACKNOWLEDGE-then-bridge ordering for
    // a two-sided argument. This checks the one-sided spine — claim, why, so-what
    // — which is the thing a coach asks for on an unstructured impromptu answer.
    //
    // Conservative by construction: lexical-marker association, never causation,
    // and `nil` below the content-word floor (no confident "no argument" on a
    // fragment). Marker presence is necessary but not sufficient for a real
    // argument — so the strongest verdict the read ever asserts is "the shape of
    // an argument is present", framed as a hypothesis everywhere it surfaces.

    /// Minimum distinct content words (post `relevanceContentWords` stop-filter)
    /// before any argument-structure verdict is asserted. Below this the rep is
    /// too thin to claim a missing reasoning chain — the read returns `nil`
    /// (tentative, never punitive). Matches the spirit of the framework-drill
    /// floor (`FrameworkDrillChecks.minContentWordsForVerdict`) so "too thin to
    /// judge structure" is one bar across the structural reads.
    static let minContentWordsForArgument: Int = 6

    /// EVIDENCE markers — the speaker justifies WHY the claim is true (backward
    /// support). Deliberately scoped to JUSTIFICATION, not consequence: this band
    /// answers "why should I believe this." Multi-word phrases are listed so they
    /// match as whole runs. Distinct from `StyleSignalSnapshot.persuasiveScore`'s
    /// band (which mixes justification and consequence into one persuasion score)
    /// — here evidence and implication are split so the chain can be read as a
    /// chain. Note `because` is in `relevanceContentWords`'s stop set (so it
    /// never inflates the content-word floor) but still matches here as a
    /// discourse marker; marker matching is independent of the content-word count.
    static let argumentEvidenceMarkers: [String] = [
        "because", "since", "the reason", "the reason is", "reason being",
        "due to", "given that", "the data", "the evidence", "research shows",
        "studies show", "for example", "for instance", "based on", "in fact"
    ]

    /// IMPLICATION / consequence markers — the speaker carries the claim FORWARD
    /// to what follows from it (the "so what"). Deliberately scoped to
    /// CONSEQUENCE, not justification: this band answers "so what does this
    /// mean." Distinct from the evidence band above so a rep with only a "why"
    /// and a rep with only a "so what" land in different verdicts. Whole-run
    /// matched.
    static let argumentImplicationMarkers: [String] = [
        "which means", "so that", "therefore", "as a result", "the result is",
        "that leads to", "which is why", "so we should", "the takeaway",
        "the upshot", "this means", "that means", "in turn", "consequently",
        "the implication", "what this means"
    ]

    /// The internal-logic read of an answer's claim->evidence->implication chain.
    /// Pure, transcript-only.
    struct ArgumentStructureRead: Equatable {
        /// True once the lead sentence carries at least one content word — the
        /// answer actually opens on a claim rather than a pure hedge. Uses the
        /// SAME `relevanceFirstSentence` lead span the positional BLUF read uses
        /// (single source of truth for "the lead").
        let hasClaim: Bool
        /// True when a backward-justification marker is present anywhere.
        let hasEvidence: Bool
        /// True when a forward-consequence marker is present anywhere.
        let hasImplication: Bool
        /// True once the content-word floor is met. When false the read is
        /// tentative and the verdict mapping returns `nil` (no confident
        /// "no argument" on thin evidence).
        let evidenceFloorMet: Bool
    }

    /// The shared argument-logic verdict — a HYPOTHESIS about the rep's internal
    /// reasoning shape, never a claim that the argument is correct. Distinct from
    /// `PromptAnswerVerdict` by construction (that reads prompt relevance; this
    /// reads the rep's own claim/evidence/implication markers).
    enum ArgumentLogicVerdict: Equatable {
        /// Claim + evidence + implication all present: the shape of a complete
        /// argument (point, why, so-what). Lexical association, never proof the
        /// reasoning is sound.
        case fullChain
        /// A claim plus EXACTLY ONE of evidence or implication — supported or
        /// carried forward, but not both. A partial spine.
        case claimWithSupport
        /// A claim with neither a justification nor a consequence marker — the
        /// point was asserted but never backed or carried forward. Constructive,
        /// never a verdict on correctness, never a confident negative below the
        /// floor (that path returns `nil`).
        case assertionOnly
    }

    /// Pure. Reads the claim->evidence->implication scaffold of `transcript`.
    /// Marker scanning uses the SAME normalisation discipline as the framework
    /// detectors (whole-run, word-boundary aware) via a local padded-string scan,
    /// so "but" never matches inside "contribute" and a trailing comma never
    /// hides a marker. Below the content-word floor every structural flag is
    /// reported but `evidenceFloorMet` is false, and the verdict mapping returns
    /// `nil`.
    static func argumentStructure(transcript: String) -> ArgumentStructureRead {
        let contentCount = relevanceContentWords(in: transcript).count
        let floorMet = contentCount >= minContentWordsForArgument
        let lead = relevanceFirstSentence(in: transcript)
        let hasClaim = !relevanceContentWords(in: lead).isEmpty
        let padded = argumentNormalisedPadded(transcript)
        let hasEvidence = argumentContains(any: argumentEvidenceMarkers, in: padded)
        let hasImplication = argumentContains(any: argumentImplicationMarkers, in: padded)
        return ArgumentStructureRead(
            hasClaim: hasClaim,
            hasEvidence: hasEvidence,
            hasImplication: hasImplication,
            evidenceFloorMet: floorMet
        )
    }

    /// Pure. Maps an `ArgumentStructureRead` onto the shared argument-logic
    /// verdict. Returns `nil` below the evidence floor — no verdict on thin
    /// evidence — and `nil` when the lead carries no claim at all (there is no
    /// argument spine to grade if nothing was even asserted). Order:
    /// 1. claim + evidence + implication -> `.fullChain`.
    /// 2. claim + (evidence XOR implication) -> `.claimWithSupport`.
    /// 3. claim alone -> `.assertionOnly`.
    static func argumentLogicVerdict(for read: ArgumentStructureRead) -> ArgumentLogicVerdict? {
        guard read.evidenceFloorMet, read.hasClaim else { return nil }
        if read.hasEvidence && read.hasImplication { return .fullChain }
        if read.hasEvidence != read.hasImplication { return .claimWithSupport }
        return .assertionOnly
    }

    // MARK: - Concision of meaning (meaning-density + answer-arrival)
    //
    // A deterministic "how much meaning per word, and how soon did it arrive"
    // read. DISTINCT from raw `wordCount` (length) and from
    // `StyleSignalSnapshot.uniqueWordRatio` (lexical DIVERSITY — how many
    // *different* words). A rep can be long and word-diverse yet meaning-thin
    // (varied function words, slow arrival); this measures SUBSTANCE density:
    // the fraction of tokens that are content words, combined with how early the
    // point landed (the answer-arrival signal, reused from the positional BLUF
    // read so the two surfaces share one notion of "the lead").
    //
    // Conservative: `nil` below the transcript floor, no confident "padded"
    // on a fragment. Lexical association, never a verdict on whether the content
    // itself was good.

    /// Below this many tokens the transcript is too short to read meaning
    /// density honestly (a five-word reply is not "padded"). Reuses the same raw
    /// floor as the relevance read (`minTranscriptWordsForRelevance`, 12 words)
    /// so "too thin to judge" is one bar.
    static let minWordsForMeaningDensity: Int = minTranscriptWordsForRelevance
    /// >= this content-word fraction reads as point-packed ("dense"). Hand-traced
    /// against the real `relevanceContentWords` stop set + `wordCount` tokenizer:
    /// natural conversational speech carrying real substance clears this; a
    /// hedge-and-filler answer ("well you know I think maybe…") falls below it.
    static let meaningDensityHighFraction: Double = 0.50
    /// < this content-word fraction reads as padded — many words, little meaning
    /// per word. Never below this is a confident negative; it only ever softens
    /// to the constructive "took a while to land" nudge.
    static let meaningDensityLowFraction: Double = 0.35

    /// The meaning-density / answer-arrival read. Pure.
    struct MeaningDensityRead: Equatable {
        /// 0...1 fraction of tokens that are content words
        /// (`relevanceContentWords.count / wordCount`). The substance-density
        /// signal. 0 when the transcript has no tokens.
        let contentWordFraction: Double
        /// Total tokens considered (`wordCount(in:)`).
        let totalWords: Int
        /// Whether the answer ARRIVED early — the lead sentence carried the
        /// point. Nil when there is no prompt to judge arrival against (a
        /// nil/thin-prompt rep still gets a density read, just no arrival term).
        /// Reused from the positional BLUF read so "arrived early" means the
        /// SAME thing here as in `promptAnswerVerdict`.
        let answerArrivedEarly: Bool?
        /// True once the token floor is met. False -> verdict mapping returns
        /// `nil`.
        let evidenceFloorMet: Bool
    }

    /// The shared concision-of-meaning verdict — a HYPOTHESIS about substance
    /// density, never a claim the content was good. Distinct from raw word count
    /// and from lexical diversity by construction.
    enum ConcisionOfMeaningVerdict: Equatable {
        /// High content-word fraction AND (when a prompt is present) the point
        /// arrived in the lead — meaning-dense and front-loaded.
        case dense
        /// A middling content-word fraction — some substance, some padding.
        /// Also the band a high-density-but-late-arrival rep lands in, so a
        /// front-loading nudge can apply without overclaiming the answer was thin.
        case measured
        /// Low content-word fraction — many words, little meaning per word.
        /// Constructive "tighten it" nudge, never a confident negative (that
        /// path returns `nil` below the floor).
        case padded
    }

    /// Pure. Reads meaning density (content-word fraction) and answer arrival
    /// for `transcript`, taking the already-computed `PromptRelevanceRead` so the
    /// arrival signal is single-sourced with the positional BLUF read rather than
    /// re-derived. Below the token floor `evidenceFloorMet` is false and the
    /// verdict mapping returns `nil`.
    static func meaningDensity(transcript: String, relevance: PromptRelevanceRead) -> MeaningDensityRead {
        let totalWords = wordCount(in: transcript)
        let contentCount = relevanceContentWords(in: transcript).count
        let fraction = totalWords > 0 ? Double(contentCount) / Double(totalWords) : 0
        // Answer arrival only when the relevance read itself cleared its floor
        // (there is a real prompt to judge "did the point lead" against).
        let arrived: Bool? = relevance.evidenceFloorMet
            ? relevance.firstSentenceOverlap >= relevanceStrongOverlap
            : nil
        return MeaningDensityRead(
            contentWordFraction: fraction,
            totalWords: totalWords,
            answerArrivedEarly: arrived,
            evidenceFloorMet: totalWords >= minWordsForMeaningDensity
        )
    }

    /// Pure. Maps a `MeaningDensityRead` onto the concision-of-meaning verdict.
    /// Returns `nil` below the token floor. Order:
    /// 1. `< meaningDensityLowFraction` -> `.padded` (meaning-thin).
    /// 2. `>= meaningDensityHighFraction` AND the point arrived early (or no
    ///    prompt to judge arrival) -> `.dense`.
    /// 3. everything else (mid fraction, or dense-but-late arrival) -> `.measured`.
    static func concisionOfMeaningVerdict(for read: MeaningDensityRead) -> ConcisionOfMeaningVerdict? {
        guard read.evidenceFloorMet else { return nil }
        if read.contentWordFraction < meaningDensityLowFraction { return .padded }
        if read.contentWordFraction >= meaningDensityHighFraction {
            // Dense — but only call it front-loaded when arrival is unknown
            // (no prompt) or genuinely early. A dense-but-late rep is `.measured`
            // so the nudge can still say "lead with it" without claiming thinness.
            if read.answerArrivedEarly ?? true { return .dense }
            return .measured
        }
        return .measured
    }

    /// Whole-run, word-boundary-aware substring check over a pre-padded,
    /// normalised string. Mirrors `FrameworkDrillChecks.contains(any:in:)` but
    /// kept local to `PracticeEvaluator` so the argument-logic read does not
    /// depend on a sibling enum's private helpers (single-file ownership of its
    /// own marker scan). Pure.
    private static func argumentContains(any phrases: [String], in padded: String) -> Bool {
        for phrase in phrases where padded.contains(" \(phrase) ") { return true }
        return false
    }

    /// Lowercased, punctuation-folded, space-padded transcript for whole-run
    /// marker scanning. Every non-letter/number/apostrophe maps to a space, runs
    /// of whitespace collapse, the curly apostrophe folds onto the straight one,
    /// and the result is wrapped in leading/trailing spaces so the first and last
    /// tokens are matchable as whole runs. Same discipline as
    /// `FrameworkDrillChecks.normalised`, kept local. Pure.
    private static func argumentNormalisedPadded(_ text: String) -> String {
        let folded = text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        let scrubbed = String(folded.map { ch -> Character in
            (ch.isLetter || ch.isNumber || ch == "'") ? ch : " "
        })
        let collapsed = scrubbed
            .split(whereSeparator: { $0 == " " })
            .joined(separator: " ")
        return " \(collapsed) "
    }

    private static func timedModeInsights(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        wordsPerMinute: Double,
        trends: TrendSnapshot,
        paceSnapshot: PaceSnapshot,
        transcript: String,
        relevance: PromptRelevanceRead
    ) -> [String] {
        var insights = sharedTrendInsights(trends: trends)
        if wordCount < 8 || duration < 8 {
            insights.append("This answer still needs more development before it will sound complete in a real conversation.")
        }
        insights.append("Pace check: \(paceSnapshot.wordsPerMinute) WPM. \(paceSnapshot.coachNote)")
        if fillerCount > 4 {
            insights.append("Too much processing is happening out loud. Replace the next filler with a short pause.")
        }
        // Argument-logic read — claim -> evidence -> implication scaffold. A
        // deterministic structural HYPOTHESIS about the rep's own reasoning
        // shape, distinct from the prompt-relevance read (topic) and from the
        // pace/filler signals. Adds NOTHING below the content-word floor (the
        // verdict is nil there), so a thin rep is byte-identical to today.
        if let argumentLine = argumentLogicInsight(transcript: transcript) {
            insights.append(argumentLine)
        }
        // Concision-of-meaning read — content-word density + answer arrival.
        // Distinct from raw word count and from lexical diversity. Adds nothing
        // below the token floor (verdict nil there).
        if let densityLine = meaningDensityInsight(transcript: transcript, relevance: relevance) {
            insights.append(densityLine)
        }
        return insights
    }

    /// Deterministic argument-logic insight line, or `nil` below the floor /
    /// when no claim was even asserted. Coaching copy only — never a score, never
    /// a confident negative. Every line is framed as a HYPOTHESIS about the
    /// reasoning shape, association on the rep's own discourse markers.
    private static func argumentLogicInsight(transcript: String) -> String? {
        let read = argumentStructure(transcript: transcript)
        guard let verdict = argumentLogicVerdict(for: read) else { return nil }
        switch verdict {
        case .fullChain:
            return "Your point, your reason, and what it means all landed — that's the shape of a complete argument. Keep building answers on that spine."
        case .claimWithSupport:
            if read.hasEvidence {
                return "You made a point and backed it, but did not carry it forward. Add one line on what it means before you close."
            } else {
                return "You stated a point and where it leads, but not why. One reason — \"because…\" — would make the argument hold."
            }
        case .assertionOnly:
            return "You led with a clear point but did not back it. Try claim, then reason, then what it means — even one of each gives the answer a backbone."
        }
    }

    /// Deterministic concision-of-meaning insight line, or `nil` below the floor.
    /// Coaching copy only. The "padded" band only ever softens to a constructive
    /// "tighten it" nudge — never a confident negative on the content itself.
    private static func meaningDensityInsight(transcript: String, relevance: PromptRelevanceRead) -> String? {
        let read = meaningDensity(transcript: transcript, relevance: relevance)
        guard let verdict = concisionOfMeaningVerdict(for: read) else { return nil }
        switch verdict {
        case .dense:
            // Only claim "arrived early" when a prompt was present to judge
            // arrival against (answerArrivedEarly == true). With no prompt the
            // arrival is unknown, so praise density without the unfounded
            // positional claim — never overclaim from absent evidence.
            if read.answerArrivedEarly == true {
                return "High signal — most of your words carried meaning and the point arrived early. That density is hard to do under pressure."
            }
            return "High signal — most of your words carried real meaning, very little padding. That density is hard to do under pressure."
        case .measured:
            // Distinguish "the point was there but late" from a plain mid read,
            // using the single-sourced arrival signal — only when a prompt was
            // present to judge arrival against.
            if read.answerArrivedEarly == false {
                return "There was real substance here, but the point took a while to arrive. Lead with it and the same content lands faster."
            }
            return "A reasonable balance of substance and connective words. To sharpen it, cut one qualifier and let the point stand."
        case .padded:
            return "A lot of words carried little of the meaning. Say the same point in fewer words and it will land with more weight."
        }
    }

    static func paceSnapshot(forTranscript transcript: String, duration: TimeInterval) -> PaceSnapshot {
        let count = wordCount(in: transcript)
        return paceSnapshot(for: paceValue(wordCount: count, duration: duration), wordCount: count)
    }

    static func speakingIdentity(for transcript: String, profile: CoachingProfile?) -> SpeakingIdentitySnapshot {
        speakingIdentitySnapshot(for: transcript, profile: profile)
    }

    private static func paceValue(wordCount: Int, duration: TimeInterval) -> Double {
        duration > 0 ? (Double(wordCount) / duration) * 60.0 : 0
    }

    /// Test hook — exposes the private `paceScore` for honest-assessment
    /// regression tests. Internal-visibility only; production callers go
    /// through the full evaluation pipeline.
    static func paceScoreForTesting(wpm: Double, wordCount: Int) -> Double {
        paceScore(for: wpm, wordCount: wordCount)
    }

    /// Test hook — exposes the private `paceSnapshot` for label
    /// regression tests after the M14 calibration fix.
    static func paceSnapshotForTesting(wpm: Double, wordCount: Int) -> PaceSnapshot {
        paceSnapshot(for: wpm, wordCount: wordCount)
    }

    /// Test hook — exposes the private `buildFeedbackCategories` so the
    /// prompt-grounded relevance override + contentProgress back-compat can
    /// be pinned directly (the 7-dimension card is otherwise only reachable
    /// through the full `evaluateTimedPractice` pipeline).
    static func buildFeedbackCategoriesForTesting(
        wordCount: Int, duration: TimeInterval, fillerCount: Int,
        wordsPerMinute: Double, durationProgress: Double, contentProgress: Double,
        paceProgress: Double, transcript: String, relevanceProgress: Double? = nil
    ) -> [FeedbackCategory] {
        buildFeedbackCategories(
            wordCount: wordCount, duration: duration, fillerCount: fillerCount,
            wordsPerMinute: wordsPerMinute, durationProgress: durationProgress,
            contentProgress: contentProgress, paceProgress: paceProgress,
            transcript: transcript, relevanceProgress: relevanceProgress
        )
    }

    /// Test hook — exposes the private `timedModeInsights` builder UNCAPPED (the
    /// production `evaluateTimedPractice` path applies `.prefix(3)` after
    /// appending the style insights, which would hide the later argument-logic /
    /// concision lines behind the cap in a full-pipeline assertion). Lets the
    /// argument-logic + concision-of-meaning consumer lines be pinned directly:
    /// they surface above the floor and are absent below it. Internal-visibility
    /// only; production callers go through the full evaluation pipeline.
    static func timedModeInsightsForTesting(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        wordsPerMinute: Double,
        recentSessions: [PracticeSession],
        transcript: String,
        prompt: String?
    ) -> [String] {
        let trends = trendSnapshot(
            fillerCount: fillerCount,
            duration: duration,
            recentSessions: recentSessions
        )
        let snapshot = paceSnapshot(for: wordsPerMinute, wordCount: wordCount)
        let relevance = promptRelevance(prompt: prompt, transcript: transcript)
        return timedModeInsights(
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            wordsPerMinute: wordsPerMinute,
            trends: trends,
            paceSnapshot: snapshot,
            transcript: transcript,
            relevance: relevance
        )
    }

    /// Pace scoring bands recalibrated for honest assessment. The full-credit
    /// zone is the shared conversational pace band; anything under 100 WPM is
    /// genuinely halting/disfluent rather than "controlled and calm." Old
    /// bands (70–95 WPM = 0.72 "Measured") were too generous.
    private static func paceScore(for wordsPerMinute: Double, wordCount: Int) -> Double {
        guard wordCount >= 6 else { return 0.15 }
        switch wordsPerMinute {
        case ..<70:           return 0.10  // halting, often disfluent
        case 70..<100:        return 0.35  // slow, hesitant
        case 100..<ConversationalPaceBand.minWPM:
            return 0.70  // deliberate but acceptable
        case ConversationalPaceBand.minWPM...ConversationalPaceBand.maxWPM:
            return 1.00  // target — clear conversational pace
        case ConversationalPaceBand.maxWPM..<180:
            return 0.78  // edges fast
        case 180..<200:       return 0.50  // rushed
        default:              return 0.25  // unintelligibly fast
        }
    }

    private static func paceSnapshot(for wordsPerMinute: Double, wordCount: Int) -> PaceSnapshot {
        let rounded = Int(wordsPerMinute.rounded())
        guard wordCount >= 6 else {
            return PaceSnapshot(
                wordsPerMinute: rounded,
                label: "Developing",
                coachNote: "There was not enough content yet to judge pace properly. Push the next answer further before scoring the rhythm."
            )
        }

        switch wordsPerMinute {
        case ..<70:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Halting", coachNote: "Your pace was below 70 WPM — that's slow enough to feel disfluent to a listener. Aim for \(ConversationalPaceBand.minDisplayWPM)–\(ConversationalPaceBand.maxDisplayWPM) WPM with deliberate pauses, not pauses inside sentences.")
        case 70..<100:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Hesitant", coachNote: "Your pace is well below conversational speed. Push the engine harder — start the next answer with the strongest opening line you have, then let momentum carry you.")
        case 100..<ConversationalPaceBand.minWPM:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Deliberate", coachNote: "Your pace is steady but slower than a confident conversational rhythm. Lean a touch faster on the connective material; reserve slowness for the points that need weight.")
        case ConversationalPaceBand.minWPM...ConversationalPaceBand.maxWPM:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Confident", coachNote: "Your pace is in the target range for clear, confident speech.")
        case ConversationalPaceBand.maxWPM..<180:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Quick", coachNote: "Your pace is edging fast. Create a little more space between points so authority can come through.")
        case 180..<200:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Rushed", coachNote: "Your pace is rushing the message. Slow the opening and finish each sentence before moving on.")
        default:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Sprinting", coachNote: "Above 200 WPM is hard for any listener to keep up with. Cut the pace by ~30% and the same content will land with twice the authority.")
        }
    }

    private static func speakingIdentitySnapshot(for transcript: String, profile: CoachingProfile?) -> SpeakingIdentitySnapshot {
        let lowercased = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowercased.isEmpty else {
            return SpeakingIdentitySnapshot(
                identity: "Unclear",
                evidence: "No usable speaking sample yet.",
                coachingNote: "Give the next rep enough language to reveal your current speaking identity."
            )
        }

        let signals = styleSignals(from: lowercased)

        let identity: String
        let evidence: String
        if signals.executiveScore >= max(signals.authorityScore, signals.warmthScore, signals.storyScore, signals.conciseScore, signals.persuasiveScore)
            && signals.executiveScore >= 2 {
            identity = "Executive and composed"
            evidence = "Your language sounds controlled, deliberate, and oriented around clear decisions."
        } else if signals.authorityScore >= max(signals.hedgeScore, signals.warmthScore, signals.storyScore, signals.conciseScore, signals.executiveScore, signals.persuasiveScore)
            && signals.authorityScore >= 2 {
            identity = "Direct and authoritative"
            evidence = "Your wording sounds decisive and forward-moving."
        } else if signals.persuasiveScore >= max(signals.authorityScore, signals.hedgeScore, signals.warmthScore, signals.storyScore, signals.conciseScore, signals.executiveScore)
            && signals.persuasiveScore >= 2 {
            identity = "Persuasive and reason-led"
            evidence = "You are backing points with reasons and pushing the listener toward a conclusion."
        } else if signals.storyScore >= max(signals.authorityScore, signals.hedgeScore, signals.warmthScore, signals.conciseScore, signals.executiveScore, signals.persuasiveScore)
            && signals.storyScore >= 1 {
            identity = "Story-led"
            evidence = "You naturally lean into examples and scene-setting language."
        } else if signals.conciseScore >= max(signals.authorityScore, signals.hedgeScore, signals.warmthScore, signals.storyScore, signals.executiveScore, signals.persuasiveScore)
            && signals.conciseScore >= 1 {
            identity = "Structured and concise"
            evidence = "You already show signs of organised, economical phrasing."
        } else if signals.warmthScore >= max(signals.authorityScore, signals.hedgeScore, signals.storyScore, signals.conciseScore, signals.executiveScore, signals.persuasiveScore)
            && signals.warmthScore >= 1 {
            identity = "Warm and conversational"
            evidence = "Your language lands as approachable and people-focused."
        } else if signals.hedgeScore >= 2 {
            identity = "Tentative"
            evidence = "A few hedging phrases are softening the impact of your ideas."
        } else if signals.repetitionScore >= 2 && signals.uniqueWordRatio < 0.58 {
            identity = "Searching and repetitive"
            evidence = "You are circling the point rather than landing it cleanly."
        } else {
            identity = "Conversational"
            evidence = "Your delivery currently sounds natural, but not strongly stylised yet."
        }

        let craftNote: String
        if signals.averageSentenceLength > 22 {
            craftNote = "Your sentences are running long, which can soften clarity."
        } else if signals.averageSentenceLength < 8 && transcript.split(separator: " ").count >= 10 {
            craftNote = "Your sentences are very clipped, so add a touch more development where needed."
        } else if signals.uniqueWordRatio > 0.72 {
            craftNote = "Your word choice has healthy range, which helps the delivery feel more intentional."
        } else if signals.repetitionScore >= 2 {
            craftNote = "A bit of repetition is flattening the voice, so vary the verbs and sentence openings more."
        } else {
            craftNote = "The raw material is there; the next gains come from making the phrasing more intentional."
        }

        var targetNote: String
        if let profile {
            switch profile.speakingStyleGoal {
            case .authoritative:
                targetNote = identity == "Direct and authoritative" || identity == "Executive and composed"
                    ? "You are already showing authority. Keep removing hedges so the confidence sounds earned."
                    : "To sound more authoritative, shorten the opening, use firmer verbs, and let pauses carry confidence."
            case .warm:
                targetNote = identity == "Warm and conversational" ? "You already sound approachable. Keep the warmth while tightening the structure." : "To sound warmer, use more inclusive and listener-aware language without losing clarity."
            case .concise:
                targetNote = identity == "Structured and concise" ? "Your style is already moving in a concise direction. Keep the answers lean." : "To sound more concise, cut the soft lead-ins and make the point earlier."
            case .persuasive:
                targetNote = identity == "Persuasive and reason-led"
                    ? "You are already sounding more persuasive. Keep tightening the proof behind each claim."
                    : "To sound more persuasive, link each claim to a reason or example so the message feels earned."
            case .executive:
                targetNote = identity == "Executive and composed"
                    ? "Your executive presence is starting to show. Keep the language disciplined and calm."
                    : "To build executive presence, keep the phrasing steady, decisive, and free of unnecessary qualifiers."
            case .storytelling:
                targetNote = identity == "Story-led" ? "You already use story cues well. Add sharper structure so the message lands with more force." : "To sound more like a storyteller, introduce one concrete image or example earlier."
            }
            if !profile.personalGoalReference.isEmpty {
                targetNote += " Keep nudging the voice toward: \"\(profile.personalGoalReference)\"."
            }
        } else {
            targetNote = "Your speaking identity is becoming clearer. More reps will make the coaching more specific."
        }

        return SpeakingIdentitySnapshot(
            identity: identity,
            evidence: evidence,
            coachingNote: "\(evidence) \(craftNote) \(targetNote)"
        )
    }

    private static func phraseCount(in text: String, phrases: [String]) -> Int {
        phrases.reduce(0) { partialResult, phrase in
            partialResult + max(0, text.components(separatedBy: phrase).count - 1)
        }
    }

    private static func styleAlignmentScore(snapshot: SpeakingIdentitySnapshot, profile: CoachingProfile?) -> Double {
        guard let profile else { return 0.5 }

        switch profile.speakingStyleGoal {
        case .authoritative:
            return snapshot.identity == "Direct and authoritative" || snapshot.identity == "Executive and composed" ? 1.0 : (snapshot.identity == "Tentative" ? 0.2 : 0.55)
        case .warm:
            return snapshot.identity == "Warm and conversational" ? 1.0 : 0.55
        case .concise:
            return snapshot.identity == "Structured and concise" ? 1.0 : (snapshot.identity == "Searching and repetitive" ? 0.2 : 0.55)
        case .persuasive:
            return snapshot.identity == "Persuasive and reason-led" ? 1.0 : 0.55
        case .executive:
            return snapshot.identity == "Executive and composed" ? 1.0 : (snapshot.identity == "Tentative" ? 0.2 : 0.5)
        case .storytelling:
            return snapshot.identity == "Story-led" ? 1.0 : 0.55
        }
    }

    private static func styleAlignmentLabel(for alignment: Double) -> String {
        switch alignment {
        case 0.9...: return "Aligned"
        case 0.55..<0.9: return "Building"
        default: return "Off target"
        }
    }

    // MARK: - Goal-aware delivery bonus
    //
    // Closes the last M14 verdict-loop edge documented in `docs/VISION.md`:
    // every line of coaching copy already speaks the user's chosen voice
    // (`enrichMomentumWithStyleAlignment`, `enrichLeverageWithStyleAlignment`,
    // `enrichNextStepWithStyleAlignment`, `drillRationale`), but the 0–10
    // score itself was voice-blind. This helper adds a small bonus to the
    // raw score when the *delivery profile* — fillers, pace, duration,
    // word count — matches what the user's chosen voice asks for. The
    // existing `styleAlignment * 1.0` slot reads *word choice*; this
    // reads *delivery*. They're orthogonal signals.
    //
    // Restraint contract (matches the copy enrichments):
    //   • Returns 0 when there's no profile / no goal.
    //   • Returns 0 when the delivery does not fit the voice — no penalty,
    //     because the existing dimension weights already penalise misses
    //     and a second penalty would double-hit the user.
    //   • Caps at 0.6 raw, so the bonus rounds the final 0/10 up by at most
    //     1 point on a borderline case. No mid-stream shock.
    //   • Mirrors `SpeakingStyleGoal.alignedSkillAreas` so the score uplift
    //     lands on the same dimensions the drill picker / verdict copy
    //     already lean on — score, copy, and drill stay in agreement.
    //
    // Voice deltas (each measured against the criteria the corresponding
    // `alignedSkillAreas` set already names):
    //   .concise        → tight delivery: few fillers, restrained pace, short answer with real content
    //   .warm           → natural pace, content depth (conversational lift, not breakneck)
    //   .authoritative  → composed delivery: zero fillers, room to land the message
    //   .persuasive     → developed content + sustained duration (reason-stack room)
    //   .executive      → composed clarity: zero fillers + controlled pace
    //   .storytelling   → long-form: room for arc + scene
    //
    // Each delta uses a 0.3 / 0.2 split (cap 0.5–0.6). The two halves are
    // independent — a partial match (one condition out of two) still earns
    // half the bonus, so the signal degrades gracefully instead of going
    // binary.
    static func voiceDeliveryBonus(
        profile: CoachingProfile?,
        wordCount: Int,
        duration: TimeInterval,
        fillerCount: Int,
        wordsPerMinute: Double
    ) -> Double {
        guard let profile, wordCount >= 8, duration >= 8 else { return 0 }
        switch profile.speakingStyleGoal {
        case .concise:
            var bonus = 0.0
            if fillerCount <= 1 { bonus += 0.2 }
            if duration <= 35 && wordCount >= 15 { bonus += 0.2 }
            if wordsPerMinute >= 110 && wordsPerMinute <= 145 { bonus += 0.2 }
            return min(bonus, 0.6)
        case .warm:
            var bonus = 0.0
            if wordsPerMinute >= 125 && wordsPerMinute <= 155 { bonus += 0.3 }
            if wordCount >= 30 { bonus += 0.2 }
            return min(bonus, 0.5)
        case .authoritative:
            var bonus = 0.0
            if fillerCount == 0 { bonus += 0.3 }
            if duration >= 25 { bonus += 0.2 }
            return min(bonus, 0.5)
        case .persuasive:
            var bonus = 0.0
            if wordCount >= 40 { bonus += 0.3 }
            if duration >= 30 { bonus += 0.2 }
            return min(bonus, 0.5)
        case .executive:
            var bonus = 0.0
            if fillerCount == 0 { bonus += 0.3 }
            if wordsPerMinute >= 115 && wordsPerMinute <= 150 { bonus += 0.2 }
            return min(bonus, 0.5)
        case .storytelling:
            var bonus = 0.0
            if duration >= 35 { bonus += 0.3 }
            if wordCount >= 50 { bonus += 0.2 }
            return min(bonus, 0.5)
        }
    }

    private static func styleAlignmentInsight(
        styleSnapshot: SpeakingIdentitySnapshot,
        profile: CoachingProfile?,
        alignment: Double
    ) -> String {
        guard let profile else {
            return "Your current voice reads as \(styleSnapshot.identity.lowercased())."
        }

        switch alignment {
        case 0.9...:
            return "Your current voice is landing close to the \(profile.speakingStyleGoal.title.lowercased()) style you asked Noum to build."
        case 0.55..<0.9:
            return "Your current voice is moving toward \(profile.speakingStyleGoal.title.lowercased()), but the phrasing is not there consistently yet."
        default:
            return "Your current voice is still some distance from the \(profile.speakingStyleGoal.title.lowercased()) style target, so keep shaping the word choice more intentionally."
        }
    }

    static func styleTrendSnapshot(
        transcript: String,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?
    ) -> StyleTrendSnapshot {
        let currentSnapshot = speakingIdentitySnapshot(for: transcript, profile: profile)
        let currentAlignment = styleAlignmentScore(snapshot: currentSnapshot, profile: profile)
        let previousSessions = Array(recentSessions.dropFirst().prefix(4))
        guard !previousSessions.isEmpty else {
            return StyleTrendSnapshot(
                hasHistory: false,
                recentIdentity: currentSnapshot.identity,
                previousIdentity: nil,
                currentAlignment: currentAlignment,
                previousAlignment: nil
            )
        }

        let previousIdentities = previousSessions.map { speakingIdentitySnapshot(for: $0.transcript, profile: profile).identity }
        let previousIdentity = mostCommonIdentity(in: previousIdentities)
        let previousAlignment = previousSessions
            .map { styleAlignmentScore(snapshot: speakingIdentitySnapshot(for: $0.transcript, profile: profile), profile: profile) }
            .reduce(0, +) / Double(previousSessions.count)

        return StyleTrendSnapshot(
            hasHistory: true,
            recentIdentity: currentSnapshot.identity,
            previousIdentity: previousIdentity,
            currentAlignment: currentAlignment,
            previousAlignment: previousAlignment
        )
    }

    static func styleTrendInsight(_ trend: StyleTrendSnapshot, profile: CoachingProfile?) -> String? {
        guard let profile else { return nil }
        guard trend.hasHistory else {
            return "This is the first saved read on your speaking identity, so Noum will start comparing future sessions against it."
        }

        let previousAlignment = trend.previousAlignment ?? trend.currentAlignment
        if trend.currentAlignment > previousAlignment + 0.18 {
            return "You are sounding closer to your \(profile.speakingStyleGoal.title.lowercased()) target than in recent sessions."
        }
        if trend.currentAlignment < previousAlignment - 0.18 {
            return "This rep drifted away from your \(profile.speakingStyleGoal.title.lowercased()) target, so tighten the phrasing on the next round."
        }
        if let previousIdentity = trend.previousIdentity, previousIdentity != trend.recentIdentity {
            return "Your speaking identity is shifting from \(previousIdentity.lowercased()) toward \(trend.recentIdentity.lowercased())."
        }
        return "Your recent sessions are reinforcing a \(trend.recentIdentity.lowercased()) voice. Keep nudging it toward \(profile.speakingStyleGoal.title.lowercased())."
    }

    private static func mostCommonIdentity(in identities: [String]) -> String? {
        Dictionary(grouping: identities, by: { $0 })
            .max { $0.value.count < $1.value.count }?
            .key
    }

    private static func styleSignals(from text: String) -> StyleSignalSnapshot {
        let words = text
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .map { $0.lowercased() }
        let sentences = text
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let uniqueWordRatio = words.isEmpty ? 0 : Double(Set(words).count) / Double(words.count)
        let averageSentenceLength = sentences.isEmpty
            ? Double(words.count)
            : Double(words.count) / Double(max(sentences.count, 1))

        let repeatedLeadIns = repeatedStarts(in: sentences)
        let repeatedWords = repeatedContentWords(in: words)

        return StyleSignalSnapshot(
            hedgeScore: phraseCount(in: text, phrases: ["i think", "i guess", "maybe", "sort of", "kind of", "probably", "just", "i feel like"]),
            authorityScore: phraseCount(in: text, phrases: ["clearly", "definitely", "certainly", "will", "must", "because", "therefore", "the reality is", "the point is"]),
            warmthScore: phraseCount(in: text, phrases: ["together", "help", "support", "appreciate", "thank you", "care", "we can", "let's"]),
            storyScore: phraseCount(in: text, phrases: ["for example", "imagine", "once", "story", "picture this", "let me tell you"]),
            conciseScore: phraseCount(in: text, phrases: ["first", "second", "finally", "the point is", "in short", "bottom line", "put simply"]),
            executiveScore: phraseCount(in: text, phrases: ["the priority", "the decision", "the outcome", "the recommendation", "moving forward", "the key point", "the result"]),
            persuasiveScore: phraseCount(in: text, phrases: ["because", "which means", "that matters", "so that", "therefore", "for that reason"]),
            repetitionScore: repeatedLeadIns + repeatedWords,
            averageSentenceLength: averageSentenceLength,
            uniqueWordRatio: uniqueWordRatio,
            questionCount: text.filter { $0 == "?" }.count
        )
    }

    private static func repeatedStarts(in sentences: [String]) -> Int {
        let starters = sentences.compactMap { sentence -> String? in
            let words = sentence.split { !$0.isLetter && !$0.isNumber }.map { $0.lowercased() }
            guard let first = words.first else { return nil }
            return first
        }
        let counts = Dictionary(grouping: starters, by: { $0 }).mapValues(\.count)
        return counts.values.filter { $0 > 1 }.count
    }

    private static func repeatedContentWords(in words: [String]) -> Int {
        let stopWords: Set<String> = ["the", "and", "to", "of", "a", "in", "it", "is", "that", "i", "you", "we", "this"]
        let counts = Dictionary(grouping: words.filter { !stopWords.contains($0) && $0.count > 3 }, by: { $0 }).mapValues(\.count)
        return counts.values.filter { $0 >= 3 }.count
    }

    private static func sharedTrendInsights(trends: TrendSnapshot) -> [String] {
        var insights: [String] = []
        if trends.hasHistory {
            if trends.fillerDelta < 0 {
                insights.append("You used fewer filler words than your recent average of \(Int(round(trends.averageFillers))).")
            } else if trends.fillerDelta > 0 {
                insights.append("Filler words were above your recent average. Slow the opening and let the next point arrive cleanly.")
            }

            if trends.durationDelta > 0 {
                insights.append("You stayed with the answer longer than your recent average, which usually improves structure.")
            } else if trends.durationDelta < 0 {
                insights.append("This answer ended earlier than your recent average. Push one idea further before stopping.")
            }
        } else {
            insights.append("This is your first saved rep in this style, so future summaries will compare against it.")
        }
        return insights
    }

    private static func trendSnapshot(
        fillerCount: Int,
        duration: TimeInterval,
        recentSessions: [PracticeSession]
    ) -> TrendSnapshot {
        let previousSessions = Array(recentSessions.dropFirst())
        let averageFillers = previousSessions.isEmpty
            ? Double(fillerCount)
            : Double(previousSessions.map(\.fillerWordCount).reduce(0, +)) / Double(previousSessions.count)
        let averageDuration = previousSessions.isEmpty
            ? duration
            : previousSessions.map(\.duration).reduce(0, +) / Double(previousSessions.count)

        return TrendSnapshot(
            hasHistory: !previousSessions.isEmpty,
            averageFillers: averageFillers,
            averageDuration: averageDuration,
            fillerDelta: Double(fillerCount) - averageFillers,
            durationDelta: duration - averageDuration
        )
    }
}

private struct TrendSnapshot {
    let hasHistory: Bool
    let averageFillers: Double
    let averageDuration: TimeInterval
    let fillerDelta: Double
    let durationDelta: TimeInterval
}

struct StyleTrendSnapshot {
    let hasHistory: Bool
    let recentIdentity: String
    let previousIdentity: String?
    let currentAlignment: Double
    let previousAlignment: Double?
}

extension PracticeSession {
    var wordCount: Int {
        transcript.split { !$0.isLetter && !$0.isNumber }.count
    }

    var wordsPerMinute: Int {
        guard duration > 0 else { return 0 }
        return Int((Double(wordCount) / duration * 60).rounded())
    }

    // MARK: - Streak Calculation

    /// Calculates the current practice streak from a list of sessions.
    ///
    /// A streak counts consecutive days with at least one session, starting from
    /// today and walking backward. A **one-day grace period** allows a single
    /// missed day inside the streak without breaking it (two consecutive missed
    /// days end the streak).
    static func calculateStreak(from sessions: [PracticeSession]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        var gracePeriodUsed = false

        // Check if today has a session; if not, start from yesterday
        if !uniqueDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            // If yesterday also doesn't have a session, streak is 0
            guard uniqueDays.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        while true {
            if uniqueDays.contains(cursor) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previousDay
            } else if !gracePeriodUsed {
                // One grace day — skip this day but keep counting
                gracePeriodUsed = true
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previousDay
            } else {
                break
            }
        }

        return streak
    }
}

struct PracticeSessionDraft {
    let transcript: String
    let fillerWordCount: Int
    let duration: TimeInterval
    let date: Date
    let mode: PracticeMode
    let imDetails: IMConversationDetails?
    let transcriptConfidence: Double?
    let transcriptionProvider: String?
    let pressureLevel: PressureLevel
    let isRated: Bool
    let pauseMetrics: PauseMetrics?
    let pitchMetrics: PitchMetrics?
    /// M21: the declared focus the user committed to before the rep,
    /// when they tapped a chip in the SessionIntent prompt. Threaded
    /// through `append(_:)` → `PracticeSession.intentFocus` so the
    /// summary cards and Ask Noum can reference it.
    let intentFocus: CoachingPriority?
    let intentLabel: String?
    /// M26: per-session vocal-energy aggregate. Optional default nil
    /// so existing draft call sites compile unchanged; only the
    /// `SpeechRecognizerViewModel.saveCurrentSession` path opts in by
    /// passing the accumulator's finalized output. Other draft
    /// builders (debug seeds, IM session synthesis) leave it nil.
    let vocalEnergyMetrics: VocalEnergyMetrics?

    init(
        transcript: String,
        fillerWordCount: Int,
        duration: TimeInterval,
        date: Date,
        mode: PracticeMode,
        imDetails: IMConversationDetails? = nil,
        transcriptConfidence: Double? = nil,
        transcriptionProvider: String? = nil,
        pressureLevel: PressureLevel = .standard,
        isRated: Bool = false,
        pauseMetrics: PauseMetrics? = nil,
        pitchMetrics: PitchMetrics? = nil,
        intentFocus: CoachingPriority? = nil,
        intentLabel: String? = nil,
        vocalEnergyMetrics: VocalEnergyMetrics? = nil
    ) {
        self.transcript = transcript
        self.fillerWordCount = fillerWordCount
        self.duration = duration
        self.date = date
        self.mode = mode
        self.imDetails = imDetails
        self.transcriptConfidence = transcriptConfidence
        self.transcriptionProvider = transcriptionProvider
        self.pressureLevel = pressureLevel
        self.isRated = isRated
        self.pauseMetrics = pauseMetrics
        self.pitchMetrics = pitchMetrics
        self.intentFocus = intentFocus
        self.intentLabel = intentLabel
        self.vocalEnergyMetrics = vocalEnergyMetrics
    }
}

struct PracticeSessionAnnotation: Equatable {
    let score: Int?
    let xpEarned: Int?
    let headline: String?
    let insights: [String]
    let coachSummary: String?
    var prompt: String? = nil
    var theme: PromptTheme? = nil

    static let empty = PracticeSessionAnnotation(
        score: nil,
        xpEarned: nil,
        headline: nil,
        insights: [],
        coachSummary: nil
    )
}

#if canImport(SwiftUI)
@MainActor
final class PracticeSessionStore: ObservableObject {
    static let shared = PracticeSessionStore()

    @Published private(set) var sessions: [PracticeSession]

    private let accountKey = "NoumAccountID"
    private let providerKey = "NoumAccountProvider"

    private init() {
        // Start with empty sessions; AuthManager.deferStoreReloadForCurrentAccount()
        // will call reloadForCurrentAccount() after the first run-loop cycle,
        // avoiding synchronous Keychain + UserDefaults + JSON decode during
        // @StateObject creation.
        sessions = []
    }

    func reload() {
        sessions = Self.loadSessions(forKey: Self.storageKey(for: currentAccountID))
    }

    func reloadForCurrentAccount() {
        reload()
    }

    func endSession() {
        sessions = []
        // Also clear persisted data so old sessions don't reappear on reload
        UserDefaults.standard.removeObject(forKey: Self.storageKey(for: currentAccountID))
    }

    @discardableResult
    func append(_ draft: PracticeSessionDraft) -> PracticeSession {
        let session = PracticeSession(
            transcript: draft.transcript,
            fillerWordCount: draft.fillerWordCount,
            duration: draft.duration,
            date: draft.date,
            mode: draft.mode,
            imConversationDetails: draft.imDetails,
            transcriptConfidence: draft.transcriptConfidence,
            transcriptionProvider: draft.transcriptionProvider,
            pressureLevel: draft.pressureLevel,
            isRated: draft.isRated,
            pauseMetrics: draft.pauseMetrics,
            pitchMetrics: draft.pitchMetrics,
            intentFocus: draft.intentFocus,
            intentLabel: draft.intentLabel,
            vocalEnergyMetrics: draft.vocalEnergyMetrics
        )
        sessions.insert(session, at: 0)
        persist()
        syncSessionIfPossible(session)
        return session
    }

    func annotateLatest(_ annotation: PracticeSessionAnnotation, expectedMode: PracticeMode) {
        guard !sessions.isEmpty else { return }
        var latest = sessions[0]
        guard latest.mode == expectedMode else { return }
        latest.score = annotation.score
        latest.xpEarned = annotation.xpEarned
        latest.headline = annotation.headline
        latest.insights = annotation.insights
        latest.coachSummary = annotation.coachSummary
        latest.prompt = annotation.prompt
        latest.theme = annotation.theme
        sessions[0] = latest
        persist()
        syncSessionIfPossible(latest)
    }

    func annotate(sessionID: UUID, annotation: PracticeSessionAnnotation) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].score = annotation.score
        sessions[index].xpEarned = annotation.xpEarned
        sessions[index].headline = annotation.headline
        sessions[index].insights = annotation.insights
        sessions[index].coachSummary = annotation.coachSummary
        persist()
        syncSessionIfPossible(sessions[index])
    }

    func saveAIFeedback(sessionID: UUID, feedback: AICoachFeedback) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].aiCoachFeedback = feedback
        persist()
        syncSessionIfPossible(sessions[index])
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    func replaceFromRemote(_ remoteSessions: [PracticeSession]) {
        sessions = remoteSessions.sorted { $0.date > $1.date }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.storageKey(for: currentAccountID))
        }
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private var currentProviderRawValue: String? {
        KeychainHelper.load(key: providerKey)
    }

    private static func storageKey(for accountID: String?) -> String {
        if let accountID, !accountID.isEmpty {
            return "practiceSessions.\(accountID)"
        }
        return "practiceSessions.guest"
    }

    private func syncSessionIfPossible(_ session: PracticeSession) {
        guard let accountID = currentAccountID, let providerRawValue = currentProviderRawValue else { return }
        Task {
            await BackendSyncManager.shared.syncSession(session, accountID: accountID, providerRawValue: providerRawValue)
        }
    }

    private static func loadSessions(forKey key: String) -> [PracticeSession] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let sessions = try? JSONDecoder().decode([PracticeSession].self, from: data) else { return [] }
        return sessions.sorted { $0.date > $1.date }
    }
}
#endif

// MARK: - Rank Helpers (shared across ContentView, ProfileView, SpeakingRankView)

#if canImport(SwiftUI)
import SwiftUI

extension ProfileManager {
    var rankSymbol: String {
        let title = levelTitle
        if title.contains("Beginner") { return "sparkles" }
        if title.contains("Novice") { return "figure.stand" }
        if title.contains("Average") { return "waveform.path.ecg" }
        if title.contains("Professional") { return "shield.lefthalf.filled" }
        return "crown.fill"
    }

    var rankTint: Color {
        let title = levelTitle
        if title.contains("Beginner") { return .blue }
        if title.contains("Novice") { return .teal }
        if title.contains("Average") { return .indigo }
        if title.contains("Professional") { return .orange }
        return .yellow
    }

    var rankDescriptor: String {
        let title = levelTitle
        if title.contains("Beginner") { return "Foundational tier" }
        if title.contains("Novice") { return "Developing tier" }
        if title.contains("Average") { return "Steady tier" }
        if title.contains("Professional") { return "Advanced tier" }
        return "Elite tier"
    }

    var rankTitle: String {
        "Speaker \(max(1, (xp / 1000) + 1))"
    }

    var nextRankTitle: String {
        "Next: Speaker \(max(2, (xp / 1000) + 2))"
    }

    var levelProgressLabel: String {
        "\(Int((progressTowardsNextLevel * 100).rounded()))%"
    }
}
#endif
#if canImport(SwiftUI)
struct RecommendationExposure: Codable, Equatable {
    let fingerprint: String
    let title: String
    let focus: String
    let target: String
    let mode: PracticeMode
    let isAIBacked: Bool
    let shownAt: Date
    var tappedAt: Date?
}

struct RecommendationOutcome: Codable, Equatable, Identifiable {
    let id: UUID
    let fingerprint: String
    let title: String
    /// The coaching purpose shown when this mode was prescribed.
    /// Optional so outcomes persisted before intervention-response
    /// coaching continue to decode cleanly.
    let focus: String?
    let target: String?
    let mode: PracticeMode
    let sessionID: UUID
    let followed: Bool
    let completedAt: Date
    let scoreDelta: Double
    /// True only when both this rep and earlier reps supplied scores.
    /// Older outcomes decode as nil and are excluded from score claims.
    let hasComparableScore: Bool?
    let fillerDelta: Double
    let durationDelta: Double
}

enum RecommendationResponseAssessment: Equatable {
    case forming
    case promising
    case mixed
    case needsAdjustment

    var coachingGuidance: String {
        switch self {
        case .forming:
            return "one observation only; treat it as tentative"
        case .promising:
            return "associated with improvement so far; continue and verify"
        case .mixed:
            return "results are mixed; diagnose before simply repeating it"
        case .needsAdjustment:
            return "associated with worse results so far; adapt before repeating it"
        }
    }
}

struct RecommendationResponseSummary: Equatable {
    let mode: PracticeMode
    let focus: String?
    let followedCount: Int
    let averageScoreDelta: Double?
    let averageFillerDelta: Double
    let assessment: RecommendationResponseAssessment
}

/// Bounded interpretation of the modes Noum prescribed and the user
/// actually attempted. This is association, not causal attribution:
/// the user may have faced a harder prompt or a different pressure level.
enum RecommendationResponseAnalyzer {
    private struct GroupKey: Hashable {
        let mode: PracticeMode
        let focus: String?
    }

    static func summarize(
        outcomes: [RecommendationOutcome],
        limit: Int = 2
    ) -> [RecommendationResponseSummary] {
        guard limit > 0 else { return [] }
        let recentFollowed = outcomes
            .filter(\.followed)
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(12)

        var grouped: [GroupKey: [RecommendationOutcome]] = [:]
        for outcome in recentFollowed {
            let focus = normalizedFocus(outcome.focus)
            grouped[GroupKey(mode: outcome.mode, focus: focus), default: []].append(outcome)
        }

        return grouped.map { key, groupedOutcomes in
            let averageFillerDelta = average(groupedOutcomes.map(\.fillerDelta))
            let comparableScores = groupedOutcomes
                .filter { $0.hasComparableScore == true }
                .map(\.scoreDelta)
            let averageScoreDelta = comparableScores.isEmpty ? nil : average(comparableScores)
            return RecommendationResponseSummary(
                mode: key.mode,
                focus: key.focus,
                followedCount: groupedOutcomes.count,
                averageScoreDelta: averageScoreDelta,
                averageFillerDelta: averageFillerDelta,
                assessment: assessment(
                    count: groupedOutcomes.count,
                    averageScoreDelta: averageScoreDelta,
                    averageFillerDelta: averageFillerDelta
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.followedCount != rhs.followedCount {
                return lhs.followedCount > rhs.followedCount
            }
            return lhs.mode.displayLabel < rhs.mode.displayLabel
        }
        .prefix(limit)
        .map { $0 }
    }

    static func promptLines(from outcomes: [RecommendationOutcome]) -> [String] {
        summarize(outcomes: outcomes).map { summary in
            let repNoun = summary.followedCount == 1 ? "rep" : "reps"
            let focusClause = summary.focus.map { " for \($0)" } ?? ""
            var metrics: [String] = []
            if let scoreDelta = summary.averageScoreDelta {
                metrics.append("score \(signed(scoreDelta))")
            }
            metrics.append("fillers \(signed(summary.averageFillerDelta))")
            return "- \(summary.mode.displayLabel)\(focusClause), followed for \(summary.followedCount) \(repNoun): \(metrics.joined(separator: ", ")) vs preceding reps; \(summary.assessment.coachingGuidance)."
        }
    }

    private static func assessment(
        count: Int,
        averageScoreDelta: Double?,
        averageFillerDelta: Double
    ) -> RecommendationResponseAssessment {
        guard count >= 2 else { return .forming }
        let scoreImproved = averageScoreDelta.map { $0 >= 0.5 } ?? false
        let scoreWorsened = averageScoreDelta.map { $0 <= -0.5 } ?? false
        let fillersImproved = averageFillerDelta <= -0.75
        let fillersWorsened = averageFillerDelta >= 0.75

        if (scoreImproved || fillersImproved), !scoreWorsened, !fillersWorsened {
            return .promising
        }
        if (scoreWorsened || fillersWorsened), !scoreImproved, !fillersImproved {
            return .needsAdjustment
        }
        return .mixed
    }

    private static func normalizedFocus(_ focus: String?) -> String? {
        guard let trimmed = focus?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(80))
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func signed(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }
}

/// A decision — not just narration — over the outcome ledger for one
/// `(mode, focus)` prescription: should the coach REINFORCE the current drill,
/// VARY the approach, or REPLACE the mode? This is the general-loop analog of
/// the IM tone-drill Adaptation read (`IMHistorySummary.toneDrillProgress` /
/// `toneDrillResolved`).
///
/// Honesty contract (mirrors the IM loop):
/// - Pure function of the stored outcomes; no `UserDefaults`, no main actor.
/// - Association only: a mode "has / has not moved alongside your metric over N
///   measurable reps" — never "this drill caused / failed".
/// - Never a verdict below its evidence floor: vary/replace need ≥3 reps that
///   recorded real movement; a confident replace needs ≥6 and a genuinely
///   negative recent window. Thin evidence reinforces tentatively and stays
///   silent in copy.
struct RecommendationAdaptationVerdict: Equatable {
    enum Action: String, Equatable { case reinforce, vary, replace }
    enum Confidence: String, Equatable { case tentative, confident }
    /// Raw direction of the recent-vs-earlier window on the net-read scale.
    enum Trend: String, Equatable { case recovering, stalled, slipping }

    let action: Action
    let confidence: Confidence
    /// Followed reps for the key in the recent window (the effort count).
    let followedReps: Int
    /// Subset of `followedReps` that recorded MEANINGFUL movement (the floor count).
    let movementReps: Int
    let improvedRate: Double      // favorable / movementReps, 0…1 (0 when none)
    let unfavorableRate: Double   // unfavorable / movementReps
    let trend: Trend
    let mode: PracticeMode
    let normalizedFocus: String?  // key evaluated; nil for the mode-only overload
}

/// Pure reducer that collapses the outcome ledger into a reinforce/vary/replace
/// verdict. Mirrors `RecommendationResponseAnalyzer`'s shape (free enum of
/// statics + named, test-asserted constants) so it stays unit-testable off the
/// main actor without touching the store.
enum RecommendationAdaptationAnalyzer {
    // Evidence floors — counted in reps that recorded ACTUAL movement.
    static let minMovementRepsToAdapt = 3        // mirror IMHistorySummary.toneDrillMinEvaluatedReps
    static let minMovementRepsToReplace = 6      // confident-replace bar (selection-biasing > narration)
    static let minTrendWindowForReplace = 3      // late window must be ≥3 reps before trend can authorise replace
    static let minMovementRepsForTrendRescue = 4 // a recovering trend may rescue reinforce only at ≥4 (toneDrillProgress window floor)
    static let recentWindowCap = 12              // mirror summarize() .prefix(12)
    // Per-rep favorable/unfavorable magnitudes — the SHIPPED analyzer constants.
    static let scoreSwing = 0.5                  // mirror assessment scoreImproved/Worsened
    static let fillerSwing = 0.75                // mirror assessment fillersImproved/Worsened (polarity-inverted)
    static let fillerMovementFloor = 0.375       // = fillerSwing * 0.5; below this, filler jitter is NOT movement
    // Trend + rate thresholds.
    static let netReadTrendThreshold = 0.5       // recovering/slipping vs stalled on the {-1,0,+1} net-read scale
    static let favorableRateThreshold = 0.5
    static let replaceUnfavorableRate = 0.6      // confident-replace bar ABOVE a coin-flip (anti-autocorrelation)
    /// The late-window net-read MEAN must be at least this negative to confidently
    /// replace. Keying replace on the recent *level* (not `trend == .slipping`)
    /// is deliberate: the {-1,0,+1} quantization makes a uniformly-bad history
    /// read as `stalled` (flat trend), so a slipping-only gate would never fire on
    /// the clearest replace case. A negative late level catches both "all bad" and
    /// "was good, now bad", while a mean-reversion bounce (… , 0, +1, +1) reads
    /// positive here and correctly lands on `.vary`.
    static let replaceRecentLevelCeiling = -0.5
    static let stalenessDecayHorizon = 8         // a replaced mode unrevisited this long decays .replace -> .vary

    /// Per-rep favorable/unfavorable/neutral read, polarity-correct and gated on
    /// the fabricated-score honesty flag.
    private enum Read: Int { case unfavorable = -1, neutral = 0, favorable = 1 }

    private struct Resolved {
        let verdict: RecommendationAdaptationVerdict
        let belowFloor: Bool   // true when movementReps < minMovementRepsToAdapt
    }

    /// Verdict for one `(mode, focus)` prescription key.
    static func adaptationVerdict(mode: PracticeMode, focus: String?, in outcomes: [RecommendationOutcome]) -> RecommendationAdaptationVerdict? {
        resolve(mode: mode, focus: focus, matchFocus: true, in: outcomes)?.verdict
    }

    /// Mode-only verdict for the selection path (`NextActionInput` carries no
    /// focus). Aggregates every focus under the mode, so it deliberately
    /// UNDER-fires replace when a mode's focuses net out — the safe direction.
    static func adaptationVerdict(mode: PracticeMode, in outcomes: [RecommendationOutcome]) -> RecommendationAdaptationVerdict? {
        resolve(mode: mode, focus: nil, matchFocus: false, in: outcomes)?.verdict
    }

    /// Shared selection predicate for deterministic recommendation surfaces.
    /// Only the strongest mode-level verdict biases selection: `.replace` with
    /// `.confident` evidence. Empty/thin ledgers and `.vary` remain no-ops.
    static func confidentlyReplaces(mode: PracticeMode, in outcomes: [RecommendationOutcome]) -> Bool {
        let verdict = adaptationVerdict(mode: mode, in: outcomes)
        return verdict?.action == .replace && verdict?.confidence == .confident
    }

    /// One association-only rationale line for the INTERVENTION RESPONSE block.
    /// `nil` on cold start OR below the movement floor (silence is the honest
    /// output below the floor — never a placeholder).
    static func adaptationRationale(mode: PracticeMode, focus: String?, in outcomes: [RecommendationOutcome]) -> String? {
        guard let resolved = resolve(mode: mode, focus: focus, matchFocus: true, in: outcomes),
              !resolved.belowFloor else { return nil }
        return rationale(for: resolved.verdict)
    }

    private static func resolve(mode: PracticeMode, focus: String?, matchFocus: Bool, in outcomes: [RecommendationOutcome]) -> Resolved? {
        let key = normalizedFocus(focus)
        let scoped = outcomes.filter { outcome in
            outcome.followed
                && outcome.mode == mode
                && (!matchFocus || normalizedFocus(outcome.focus) == key)
        }
        guard !scoped.isEmpty else { return nil }   // cold start

        let window = scoped
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(recentWindowCap)
        let followedReps = window.count

        // Movement gate — only reps that recorded MEANINGFUL movement count toward
        // the floor (the evaluatedCount discipline), so trivial filler jitter can
        // never inflate the sample toward the replace bar.
        let movingNewestFirst = window.filter(hasMovement)
        let movementReps = movingNewestFirst.count
        let moving = Array(movingNewestFirst.reversed())   // oldest -> newest

        let favorableCount = moving.filter { read(of: $0) == .favorable }.count
        let unfavorableCount = moving.filter { read(of: $0) == .unfavorable }.count
        let improvedRate = movementReps == 0 ? 0 : Double(favorableCount) / Double(movementReps)
        let unfavorableRate = movementReps == 0 ? 0 : Double(unfavorableCount) / Double(movementReps)

        // Disjoint-window trend over the net reads (oldest -> newest), mirroring
        // toneDrillProgress: w = min(3, count/2) guarantees the two windows never
        // overlap.
        let netReads = moving.map { Double(read(of: $0).rawValue) }
        let w = min(3, movementReps / 2)
        var lateMean = 0.0
        var trend: RecommendationAdaptationVerdict.Trend = .stalled
        if w >= 1 {
            let earlyMean = mean(Array(netReads.prefix(w)))
            lateMean = mean(Array(netReads.suffix(w)))
            let trendDelta = lateMean - earlyMean
            if trendDelta >= netReadTrendThreshold { trend = .recovering }
            else if trendDelta <= -netReadTrendThreshold { trend = .slipping }
            else { trend = .stalled }
        }

        func make(_ action: RecommendationAdaptationVerdict.Action, _ confidence: RecommendationAdaptationVerdict.Confidence) -> RecommendationAdaptationVerdict {
            RecommendationAdaptationVerdict(
                action: action,
                confidence: confidence,
                followedReps: followedReps,
                movementReps: movementReps,
                improvedRate: improvedRate,
                unfavorableRate: unfavorableRate,
                trend: trend,
                mode: mode,
                normalizedFocus: matchFocus ? key : nil
            )
        }

        // Thin evidence — never vary/replace; reinforce tentatively, omit rationale.
        if movementReps < minMovementRepsToAdapt {
            return Resolved(verdict: make(.reinforce, .tentative), belowFloor: true)
        }

        let confidentEvidence = movementReps >= minMovementRepsToReplace

        // (a) Sticky reinforce — a high lifetime favorable rate keeps reinforce even
        //     on a small dip (anti-fickle), BUT never reinforce a drill whose recent
        //     window is clearly negative.
        let recovers = movementReps >= minMovementRepsForTrendRescue && trend == .recovering
        let recentlyNegative = trend == .slipping && lateMean < 0
        if (improvedRate >= favorableRateThreshold || recovers) && !recentlyNegative {
            return Resolved(verdict: make(.reinforce, confidentEvidence ? .confident : .tentative), belowFloor: false)
        }

        // (b) Confident replace — autocorrelation-hardened. Requires a genuinely
        //     negative RECENT window (lateMean), not merely a flat ledger of
        //     minus-running-mean deltas, plus an above-coin-flip unfavorable rate.
        if confidentEvidence
            && w >= minTrendWindowForReplace
            && unfavorableRate >= replaceUnfavorableRate
            && improvedRate < 0.34
            && lateMean <= replaceRecentLevelCeiling {
            // (c) Staleness-decay / latch escape-hatch — a replaced mode stops being
            //     handed out, so its window freezes; if the user has not revisited it
            //     within the last `stalenessDecayHorizon` followed reps across ALL
            //     keys, decay to .vary so the engine re-offers it and fresh evidence
            //     can re-decide.
            if isStale(newestMovingDate: movingNewestFirst.first?.completedAt, in: outcomes) {
                return Resolved(verdict: make(.vary, .tentative), belowFloor: false)
            }
            return Resolved(verdict: make(.replace, .confident), belowFloor: false)
        }

        // (d) Everything else above the floor — vary, tentative (inert in selection).
        return Resolved(verdict: make(.vary, .tentative), belowFloor: false)
    }

    private static func hasMovement(_ outcome: RecommendationOutcome) -> Bool {
        outcome.hasComparableScore == true || abs(outcome.fillerDelta) >= fillerMovementFloor
    }

    private static func read(of outcome: RecommendationOutcome) -> Read {
        let scoreFavorable = outcome.hasComparableScore == true && outcome.scoreDelta >= scoreSwing
        let scoreUnfavorable = outcome.hasComparableScore == true && outcome.scoreDelta <= -scoreSwing
        let fillerFavorable = outcome.fillerDelta <= -fillerSwing   // negative filler delta = improvement
        let fillerUnfavorable = outcome.fillerDelta >= fillerSwing
        let favorable = scoreFavorable || fillerFavorable
        let unfavorable = scoreUnfavorable || fillerUnfavorable
        if favorable && !unfavorable { return .favorable }
        if unfavorable && !favorable { return .unfavorable }
        return .neutral
    }

    private static func isStale(newestMovingDate: Date?, in outcomes: [RecommendationOutcome]) -> Bool {
        guard let newestMovingDate else { return false }
        let followedDates = outcomes.filter(\.followed).map(\.completedAt).sorted(by: >)
        guard followedDates.count >= stalenessDecayHorizon else { return false }
        let boundary = followedDates[stalenessDecayHorizon - 1]
        return newestMovingDate < boundary
    }

    private static func rationale(for verdict: RecommendationAdaptationVerdict) -> String {
        let n = verdict.movementReps
        let repNoun = n == 1 ? "measurable rep" : "measurable reps"
        let label = verdict.mode.displayLabel
        let focusClause = verdict.normalizedFocus.map { " for \($0)" } ?? ""
        switch verdict.action {
        case .reinforce:
            return "- \(label)\(focusClause) has moved alongside your metric across your last \(n) \(repNoun) — keep it."
        case .vary:
            return "- \(label)\(focusClause) has not moved alongside your metric over your last \(n) \(repNoun); worth varying the approach, not abandoning it yet."
        case .replace:
            return "- Across \(n) \(repNoun), your metric has trended down alongside \(label)\(focusClause) — time to swap it for a different angle."
        }
    }

    private static func normalizedFocus(_ focus: String?) -> String? {
        guard let trimmed = focus?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(80))
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}

@MainActor
final class RecommendationLearningStore: ObservableObject {
    static let shared = RecommendationLearningStore()

    @Published private(set) var pendingExposure: RecommendationExposure?
    @Published private(set) var outcomes: [RecommendationOutcome]

    private let accountKey = "NoumAccountID"
    private let providerKey = "NoumAccountProvider"

    private init() {
        // Start with empty state; reloadForCurrentAccount() is called
        // after the first run-loop cycle via AuthManager, avoiding synchronous
        // Keychain + UserDefaults + JSON decode during @StateObject creation.
        pendingExposure = nil
        outcomes = []
    }

    func reloadForCurrentAccount() {
        let accountID = KeychainHelper.load(key: accountKey)
        pendingExposure = Self.loadPending(forKey: Self.pendingKey(for: accountID))
        outcomes = Self.loadOutcomes(forKey: Self.outcomesKey(for: accountID))
    }

    func replaceFromRemote(pendingExposure: RecommendationExposure?, outcomes: [RecommendationOutcome]) {
        self.pendingExposure = pendingExposure
        self.outcomes = outcomes.sorted { $0.completedAt > $1.completedAt }
        persistOutcomes()
        persistPending()
    }

    func recordShown(
        fingerprint: String,
        title: String,
        focus: String,
        target: String,
        mode: PracticeMode,
        isAIBacked: Bool
    ) {
        if pendingExposure?.fingerprint == fingerprint { return }
        pendingExposure = RecommendationExposure(
            fingerprint: fingerprint,
            title: title,
            focus: focus,
            target: target,
            mode: mode,
            isAIBacked: isAIBacked,
            shownAt: Date(),
            tappedAt: nil
        )
        persistPending()
        syncIfPossible()
    }

    func markTapped(mode: PracticeMode) {
        guard var pendingExposure else { return }
        guard pendingExposure.mode == mode else { return }
        pendingExposure.tappedAt = Date()
        self.pendingExposure = pendingExposure
        persistPending()
        syncIfPossible()
    }

    func recordOutcome(for session: PracticeSession, previousSessions: [PracticeSession]) {
        guard let pendingExposure else { return }

        let relevantHistory = previousSessions.isEmpty ? PracticeSessionStore.shared.sessions.filter { $0.id != session.id } : previousSessions
        let priorScores = relevantHistory.compactMap(\.score)
        let comparableScoreDelta: Double? = {
            guard let score = session.score, !priorScores.isEmpty else { return nil }
            let averageScore = Double(priorScores.reduce(0, +)) / Double(priorScores.count)
            return Double(score) - averageScore
        }()
        let averageFillers = relevantHistory.isEmpty
            ? Double(session.fillerWordCount)
            : Double(relevantHistory.map(\.fillerWordCount).reduce(0, +)) / Double(relevantHistory.count)
        let averageDuration = relevantHistory.isEmpty
            ? session.duration
            : relevantHistory.map(\.duration).reduce(0, +) / Double(relevantHistory.count)

        let outcome = RecommendationOutcome(
            id: UUID(),
            fingerprint: pendingExposure.fingerprint,
            title: pendingExposure.title,
            focus: pendingExposure.focus,
            target: pendingExposure.target,
            mode: pendingExposure.mode,
            sessionID: session.id,
            followed: pendingExposure.mode == session.mode,
            completedAt: Date(),
            scoreDelta: comparableScoreDelta ?? 0,
            hasComparableScore: comparableScoreDelta != nil,
            fillerDelta: Double(session.fillerWordCount) - averageFillers,
            durationDelta: session.duration - averageDuration
        )

        outcomes.insert(outcome, at: 0)
        outcomes = Array(outcomes.prefix(40))
        self.pendingExposure = nil
        persistOutcomes()
        persistPending()
        syncIfPossible()
    }

    func resetDiagnostics() {
        outcomes = []
        pendingExposure = nil
        persistOutcomes()
        persistPending()
        syncIfPossible()
    }

    func exportDiagnostics() -> String? {
        struct ExportPayload: Codable {
            let pendingExposure: RecommendationExposure?
            let outcomes: [RecommendationOutcome]
            let exportedAt: Date
        }

        let payload = ExportPayload(
            pendingExposure: pendingExposure,
            outcomes: outcomes,
            exportedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func persistPending() {
        let key = Self.pendingKey(for: KeychainHelper.load(key: accountKey))
        if let pendingExposure, let data = try? JSONEncoder().encode(pendingExposure) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func persistOutcomes() {
        let key = Self.outcomesKey(for: KeychainHelper.load(key: accountKey))
        if let data = try? JSONEncoder().encode(outcomes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func syncIfPossible() {
        guard let accountID = KeychainHelper.load(key: accountKey),
              let providerRawValue = KeychainHelper.load(key: providerKey) else { return }
        let pendingExposure = pendingExposure
        let outcomes = outcomes
        Task {
            await BackendSyncManager.shared.syncRecommendationState(
                pendingExposure: pendingExposure,
                outcomes: outcomes,
                accountID: accountID,
                providerRawValue: providerRawValue
            )
        }
    }

    private static func pendingKey(for accountID: String?) -> String {
        if let accountID, !accountID.isEmpty {
            return "recommendation.pending.\(accountID)"
        }
        return "recommendation.pending.guest"
    }

    private static func outcomesKey(for accountID: String?) -> String {
        if let accountID, !accountID.isEmpty {
            return "recommendation.outcomes.\(accountID)"
        }
        return "recommendation.outcomes.guest"
    }

    private static func loadPending(forKey key: String) -> RecommendationExposure? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(RecommendationExposure.self, from: data) else {
            return nil
        }
        return value
    }

    private static func loadOutcomes(forKey key: String) -> [RecommendationOutcome] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode([RecommendationOutcome].self, from: data) else {
            return []
        }
        return value
    }
}
#endif

@MainActor
enum PracticeSessionFinalizer {
    static func finalize(
        store: PracticeSessionStore,
        draft: PracticeSessionDraft,
        annotation: PracticeSessionAnnotation = .empty
    ) -> PracticeSession {
        // M21: consume any pending SessionIntent before appending so the
        // session row carries the user's declared focus from the start.
        // Mutating the draft inline keeps every call site (Timed, Sudden
        // Death, Ah-Counter, drill mini-runs) untouched; the intent
        // landing is a single-source decision here.
        let intent = SessionIntentStore.shared.pendingIntent
        let intentAwareDraft: PracticeSessionDraft = {
            // Preserve any caller-supplied intent (tests can pass one
            // directly); only inject from the store when the draft has
            // none of its own.
            if draft.intentFocus != nil { return draft }
            guard let intent else { return draft }
            return PracticeSessionDraft(
                transcript: draft.transcript,
                fillerWordCount: draft.fillerWordCount,
                duration: draft.duration,
                date: draft.date,
                mode: draft.mode,
                imDetails: draft.imDetails,
                transcriptConfidence: draft.transcriptConfidence,
                transcriptionProvider: draft.transcriptionProvider,
                pressureLevel: draft.pressureLevel,
                isRated: draft.isRated,
                pauseMetrics: draft.pauseMetrics,
                pitchMetrics: draft.pitchMetrics,
                intentFocus: intent.priority,
                intentLabel: intent.label
            )
        }()
        let session = store.append(intentAwareDraft)
        // Link the pending intent to the session and drop it from
        // pending state — single-rep lifecycle, no leakage to the next
        // rep if the user goes straight back into another session.
        SessionIntentStore.shared.consume(sessionID: session.id)
        if annotation != .empty {
            store.annotate(sessionID: session.id, annotation: annotation)
        }
        let finalized = store.sessions.first(where: { $0.id == session.id }) ?? session

        // Speech-backed modes record recommendation outcomes once their
        // delayed evaluation annotates the captured rep. IM Conversation
        // arrives here already evaluated, so it must enter the same
        // intervention cycle here or prescribed conversation reps vanish
        // from the coach's evidence.
        if finalized.mode == .imConversation, annotation != .empty {
            RecommendationLearningStore.shared.recordOutcome(
                for: finalized,
                previousSessions: store.sessions.filter { $0.id != finalized.id }
            )
        }

        // Analyze verbal habits before refreshing the baseline so clutch words are included immediately.
        ClutchWordStore.shared.analyzeSession(transcript: draft.transcript)

        // Record baseline data
        BaselineStore.shared.recordSession(finalized, pressure: draft.pressureLevel)

        // Check personal bests (for all sessions)
        let streak = PracticeSession.calculateStreak(from: store.sessions)
        RatingStore.shared.checkPersonalBests(session: finalized, currentStreak: streak)

        // Update speaking rating (only for rated/pressure sessions)
        if draft.isRated, let score = finalized.score {
            RatingStore.shared.recordRatedSession(
                score: score,
                sessionId: finalized.id,
                pressureLevel: draft.pressureLevel
            )
        }

        // Evaluate achievements
        AchievementStore.shared.evaluate(sessions: store.sessions, streak: streak)

        // M24 Track 1 — drop a deterministic post-rep coach note in
        // the store immediately so the Summary surface can render the
        // coach's voice in the very same paint cycle as the verdict.
        // The AI upgrade fires concurrently and replaces the
        // deterministic record on completion (de-dupe by sessionID is
        // enforced by `PostRepCoachNoteStore.record`).
        Self.recordPostRepCoachNote(for: finalized)

        return finalized
    }

    /// Build a `PostRepCoachNoteInput` from the finalized session +
    /// live stores, write the deterministic note immediately, then fire
    /// the AI upgrade as a detached task. Pure boilerplate — keeps
    /// `finalize` readable.
    private static func recordPostRepCoachNote(for session: PracticeSession) {
        let profile = CoachingProfileStore.shared.profile
        let baseline = BaselineStore.shared.baseline
        let bigMoment = BigMomentStore.shared.activeMoment
        let bigMomentDays = bigMoment.flatMap { BigMomentStore.daysUntil($0) }

        let baselineFillerRate: Double? = baseline.fillerRate.confidence == .insufficient ? nil : baseline.fillerRate.value
        let baselinePace: Double? = baseline.pace.confidence == .insufficient ? nil : baseline.pace.value

        // Pull the recents + proofs the AI needs to write a continuity-aware
        // note ("third time you've leaned on…") rather than a stat dashboard.
        let allSessions = PracticeSessionStore.shared.sessions
        let recentSummaries: [String] = allSessions
            .filter { $0.id != session.id }
            .prefix(3)
            .map { rep in
                var parts: [String] = [rep.mode.displayLabel]
                if let s = rep.score { parts.append("score \(s)/10") }
                parts.append("\(rep.fillerWordCount) filler\(rep.fillerWordCount == 1 ? "" : "s")")
                parts.append("\(Int(rep.duration.rounded()))s")
                return parts.joined(separator: ", ")
            }
        let recentProofs: [String] = ProofMomentStore.shared
            .recent(limit: 2)
            .map { $0.proof.quote }
            .filter { !$0.isEmpty }

        // Compute cross-session momentum signals so the deterministic
        // note can reference trajectory (consecutive clean reps, filler
        // trend, personal bests) rather than just today's numbers.
        let momentum = MomentumComputer.compute(
            currentSession: session,
            allSessions: allSessions,
            baselineFillerRate: baselineFillerRate
        )

        // IM tone-drill Adaptation read for the just-finished rep's
        // scenario, so the post-rep note can speak to whether the tone
        // work is landing — the same Adaptation signal the next-practice
        // card and the chat coach read. Round 43 lifted this block out
        // of the finalizer and into `MomentumComputer.imToneDrillNoteFields`
        // so the per-rep anchoring contract (the trio reads from the
        // just-finished rep's scenario, NEVER another scenario's
        // trajectory) is testable in isolation. See `IMToneDrillNoteFields`.
        let imToneFields = MomentumComputer.imToneDrillNoteFields(
            forJustFinished: session, in: allSessions
        )

        let input = PostRepCoachNoteInput(
            sessionID: session.id,
            mode: session.mode,
            score: session.score,
            fillerCount: session.fillerWordCount,
            duration: session.duration,
            wordCount: session.wordCount,
            voice: profile?.speakingStyleGoal,
            intentLabel: session.intentLabel,
            baselineFillerRate: baselineFillerRate,
            baselinePaceWPM: baselinePace,
            bigMoment: bigMoment,
            bigMomentDaysUntil: bigMomentDays,
            transcript: session.transcript,
            prompt: session.prompt ?? "",
            recentSessionSummaries: recentSummaries,
            recentProofQuotes: recentProofs,
            consecutiveCleanReps: momentum.consecutiveCleanReps,
            fillerTrendDirection: momentum.fillerTrendDirection,
            scoreTrendDirection: momentum.scoreTrendDirection,
            weeklyRepCount: momentum.weeklyRepCount,
            isPersonalBest: momentum.isPersonalBest,
            totalSessionCount: momentum.totalSessionCount,
            imToneDrillProgress: imToneFields.progress,
            imToneDrillScenarioTitle: imToneFields.scenarioTitle,
            imToneDrillToneTitle: imToneFields.toneTitle,
            imToneDrillResolved: imToneFields.resolved,
            imToneDrillResolvedScenarioTitle: imToneFields.resolvedScenarioTitle,
            imToneDrillResolvedToneTitle: imToneFields.resolvedToneTitle
        )

        // Deterministic note lands synchronously so the Summary
        // surface already has a coach voice to show on the first frame.
        let deterministic = PostRepCoachNoteService.deterministicNote(input: input)
        PostRepCoachNoteStore.shared.record(deterministic)

        // AI upgrade fires concurrently. If the network is unreachable
        // or the locale is non-English, `generate` returns the same
        // deterministic note (no second write needed but harmless).
        Task { [input] in
            let upgraded = await PostRepCoachNoteService.shared.generate(input: input)
            await MainActor.run {
                // Only replace when the upgrade is actually AI-backed
                // — same-deterministic re-writes are no-ops but waste
                // a published change.
                if upgraded.isAIBacked {
                    PostRepCoachNoteStore.shared.record(upgraded)
                }
            }
        }
    }

    // MARK: - Voice-change retroactive read (M24 Track 1 future move)
    //
    // When the user changes their `speakingStyleGoal`, the most recent
    // PostRepCoachNote is still written in the OLD voice. The persistent
    // Ask Noum chat coach reads that note as "your current voice" via
    // `CoachContextBuilder.userContext`'s LAST REP NOTE section — so
    // until the user finishes another rep, the chat coach quotes a
    // stale-voice note as if it were the live voice. This regen closes
    // the gap: when the voice changes, the most recent note is rewritten
    // immediately in the new voice. Same sessionID, so the store's
    // dedupe-by-sessionID contract replaces the prior record rather
    // than stacking.

    /// Pure helper: build a `PostRepCoachNoteInput` for re-generating
    /// the note that's already attached to a finalized session, in a
    /// new voice. Session metrics carry through; baseline + BigMoment
    /// come from the live stores at regen time (a baseline that's
    /// evolved since the rep is the right read for "current voice on
    /// past rep" — the deterministic priority chain is mostly
    /// session-derived anyway). Exposed for tests.
    nonisolated static func regenerationInput(
        from session: PracticeSession,
        newVoice: SpeakingStyleGoal?,
        baseline: CommunicationBaseline,
        bigMoment: BigMoment?,
        bigMomentDaysUntil: Int?,
        recentSessionSummaries: [String] = [],
        recentProofQuotes: [String] = []
    ) -> PostRepCoachNoteInput {
        let baselineFillerRate: Double? = baseline.fillerRate.confidence == .insufficient
            ? nil : baseline.fillerRate.value
        let baselinePace: Double? = baseline.pace.confidence == .insufficient
            ? nil : baseline.pace.value
        return PostRepCoachNoteInput(
            sessionID: session.id,
            mode: session.mode,
            score: session.score,
            fillerCount: session.fillerWordCount,
            duration: session.duration,
            wordCount: session.wordCount,
            voice: newVoice,
            intentLabel: session.intentLabel,
            baselineFillerRate: baselineFillerRate,
            baselinePaceWPM: baselinePace,
            bigMoment: bigMoment,
            bigMomentDaysUntil: bigMomentDaysUntil,
            transcript: session.transcript,
            prompt: session.prompt ?? "",
            recentSessionSummaries: recentSessionSummaries,
            recentProofQuotes: recentProofQuotes
        )
    }

    /// Fired from `CoachingProfileStore.save(_:)` when the user changes
    /// their voice. No-op when: no note has been recorded yet (cold
    /// start), the latest note's voice already matches the new voice
    /// (idempotent — onboarding "save" with no actual change), or the
    /// originating session has been deleted from history since the
    /// note was written (defensive — never invent a note for a session
    /// that no longer exists).
    @MainActor
    static func regenerateMostRecentNoteIfVoiceChanged(newVoice: SpeakingStyleGoal?) {
        guard let latest = PostRepCoachNoteStore.shared.latestNote() else { return }
        guard latest.voice != newVoice else { return }
        guard let session = PracticeSessionStore.shared.sessions
            .first(where: { $0.id == latest.sessionID }) else { return }

        let baseline = BaselineStore.shared.baseline
        let bigMoment = BigMomentStore.shared.activeMoment
        let bigMomentDays = bigMoment.flatMap { BigMomentStore.daysUntil($0) }

        let input = regenerationInput(
            from: session,
            newVoice: newVoice,
            baseline: baseline,
            bigMoment: bigMoment,
            bigMomentDaysUntil: bigMomentDays
        )

        // Deterministic note lands synchronously so the Ask Noum chat
        // coach reads the new-voice note on the very next reply rather
        // than quoting the stale-voice line one more time.
        let deterministic = PostRepCoachNoteService.deterministicNote(input: input)
        PostRepCoachNoteStore.shared.record(deterministic)

        // AI upgrade fires concurrently — same shape as the finalize
        // path so the polished phrasing eventually lands once the
        // model rewrites in the new voice.
        Task { [input] in
            let upgraded = await PostRepCoachNoteService.shared.generate(input: input)
            await MainActor.run {
                if upgraded.isAIBacked {
                    PostRepCoachNoteStore.shared.record(upgraded)
                }
            }
        }
    }
}

struct CoachingPlan {
    let strongestMode: PracticeMode?
    let currentFocus: String
    let suggestedDrill: String
    let encouragement: String
    let hiddenBaseline: HiddenBaseline
}

struct HiddenBaseline {
    let averageFillers: Double
    let averageDuration: Double
    let averageWordsPerMinute: Double
    let currentIdentity: String
}

enum CoachingPlanner {
    static func plan(for sessions: [PracticeSession], profile: CoachingProfile?) -> CoachingPlan? {
        guard !sessions.isEmpty else { return nil }
        let recent = Array(sessions.prefix(8))
        let averageFillers = Double(recent.map(\.fillerWordCount).reduce(0, +)) / Double(recent.count)
        let averageDuration = recent.map(\.duration).reduce(0, +) / Double(recent.count)
        let averageWordsPerMinute = recent.map { Double($0.wordsPerMinute) }.reduce(0, +) / Double(recent.count)
        let strongestMode = Dictionary(grouping: recent, by: \.mode).max { lhs, rhs in
            averageScore(for: lhs.value) < averageScore(for: rhs.value)
        }?.key
        let identitySnapshot = PracticeEvaluator.speakingIdentity(for: recent.first?.transcript ?? "", profile: profile)

        let latest = recent.first
        let previousFillers = recent.dropFirst().map(\.fillerWordCount)
        let previousAverageFillers = previousFillers.isEmpty ? averageFillers : Double(previousFillers.reduce(0, +)) / Double(previousFillers.count)
        let encouragement: String
        if let latest, Double(latest.fillerWordCount) < previousAverageFillers {
            encouragement = "Your recent practice is moving in the right direction, so keep building on that consistency."
        } else if let latest, Double(latest.fillerWordCount) > previousAverageFillers {
            encouragement = "There is useful room to tighten the delivery, and a calmer opening will help."
        } else {
            encouragement = "Your recent sessions are fairly steady, which gives you a good platform for focused improvement."
        }

        let currentFocus: String
        if let profile {
            switch profile.biggestChallenge {
            case .fillerWords:
                currentFocus = "Focus on replacing filler words with deliberate pauses and cleaner sentence openings."
            case .rambling:
                currentFocus = "Focus on shaping each answer around one clear point before you expand."
            case .freezing:
                currentFocus = "Focus on answering directly first, then adding one supporting idea to keep momentum."
            case .rushing:
                currentFocus = "Focus on steadier pacing so each point sounds more deliberate and confident."
            }
        } else if averageFillers > 4 {
            currentFocus = "Focus on reducing filler words by pausing before each new idea."
        } else if averageWordsPerMinute > 155 {
            currentFocus = "Focus on slowing the pace slightly so the message sounds more controlled."
        } else if averageDuration < 20 {
            currentFocus = "Focus on expanding answers so each response has a clear middle section."
        } else {
            currentFocus = "Focus on maintaining structure while keeping your delivery relaxed."
        }

        let suggestedDrill: String
        if let profile {
            switch (profile.primaryGoal, profile.speakingStyleGoal) {
            case (_, .authoritative):
                suggestedDrill = "Use Pressure Drill and Medium Timed Practice to strengthen firmer openings, cleaner pauses, and more decisive language."
            case (_, .executive):
                suggestedDrill = "Use Medium Timed Practice and Pressure Drill to rehearse steadier pacing, shorter openings, and boardroom-style control."
            case (_, .storytelling):
                suggestedDrill = "Use Easy Timed Practice to build fuller examples, then bring that colour into harder prompts."
            case (.reduceFillers, _):
                suggestedDrill = "Timed Practice on Easy or Medium will help you slow the pace and protect cleaner transitions."
            case (.moreConcise, _):
                suggestedDrill = "Timed Practice on Medium will encourage tighter openings and more disciplined structure."
            case (.thinkFaster, _):
                suggestedDrill = "Timed Practice on Hard or Medium will help you organise thoughts quickly under pressure."
            case (.calmerDelivery, _):
                suggestedDrill = "Ah-Counter and Easy Timed Practice will help you keep composure without forcing pace."
            }
        } else if averageFillers > 4 {
            suggestedDrill = "Timed Practice on Easy or Medium will give you room to slow the pace and clean up transitions."
        } else if averageDuration < 20 {
            suggestedDrill = "Timed Practice on Easy will help you develop fuller answers."
        } else if strongestMode == .suddenDeath {
            suggestedDrill = "Pressure Drill is working well for you. Use it to keep the pressure high."
        } else {
            suggestedDrill = "Mix Timed Practice with Ah-Counter so you can balance structure and awareness."
        }

        let outcomeNote: String? = profile.map { profile in
            switch profile.desiredOutcome {
            case .concise:
                return "The coaching will keep steering you toward answers that land quickly and clearly."
            case .composed:
                return "The coaching will keep rewarding steadier pacing and calmer openings."
            case .persuasive:
                return "The coaching will keep pushing for stronger structure and clearer support."
            case .spontaneous:
                return "The coaching will keep emphasising responsiveness and on-the-spot clarity."
            }
        }
        let styleNote: String? = profile.map { profile in
            "Noum is steering your delivery toward a \(profile.speakingStyleGoal.title.lowercased()) voice, while your current sessions still read as \(identitySnapshot.identity.lowercased())."
        }

        return CoachingPlan(
            strongestMode: strongestMode,
            currentFocus: currentFocus,
            suggestedDrill: suggestedDrill,
            encouragement: [encouragement, outcomeNote, styleNote].compactMap { $0 }.joined(separator: " "),
            hiddenBaseline: HiddenBaseline(
                averageFillers: averageFillers,
                averageDuration: averageDuration,
                averageWordsPerMinute: averageWordsPerMinute,
                currentIdentity: identitySnapshot.identity
            )
        )
    }

    static func sessionInsights(for session: PracticeSession, comparedTo sessions: [PracticeSession], profile: CoachingProfile?) -> [String] {
        let previousSessions = sessions.filter { $0.id != session.id }
        guard !previousSessions.isEmpty else {
            return session.insights.isEmpty
                ? ["This is the first saved session in your history, so it sets the initial baseline."]
                : session.insights
        }

        let averageFillers = Double(previousSessions.map(\.fillerWordCount).reduce(0, +)) / Double(previousSessions.count)
        let averageDuration = previousSessions.map(\.duration).reduce(0, +) / Double(previousSessions.count)

        var insights = session.insights
        if Double(session.fillerWordCount) < averageFillers {
            insights.append("This session had fewer filler words than your running average.")
        } else if Double(session.fillerWordCount) > averageFillers {
            insights.append("This session had more filler words than your running average.")
        }

        if session.duration > averageDuration {
            insights.append("You stayed with the answer longer than usual, which often improves clarity.")
        } else {
            insights.append("This answer ended sooner than your typical response length.")
        }

        let sessionPace = PracticeEvaluator.paceSnapshot(forTranscript: session.transcript, duration: session.duration)
        insights.append("Pace check: \(sessionPace.wordsPerMinute) WPM. \(sessionPace.coachNote)")
        let styleTrend = PracticeEvaluator.styleTrendSnapshot(
            transcript: session.transcript,
            recentSessions: [session] + previousSessions,
            profile: profile
        )
        if let styleTrendNote = PracticeEvaluator.styleTrendInsight(styleTrend, profile: profile) {
            insights.append(styleTrendNote)
        }

        return Array(NSOrderedSet(array: insights).array as? [String] ?? insights).prefix(3).map { $0 }
    }

    private static func averageScore(for sessions: [PracticeSession]) -> Double {
        let scored = sessions.compactMap(\.score)
        guard !scored.isEmpty else { return 0 }
        return Double(scored.reduce(0, +)) / Double(scored.count)
    }
}

enum AICoachError: LocalizedError {
    case providerDisabled
    case missingAPIKey
    case transcriptTooShort
    case invalidResponse
    case apiFailure(String)

    var errorDescription: String? {
        switch self {
        case .providerDisabled:
            return "AI coaching is turned off."
        case .missingAPIKey:
            return "AI provider API key is missing."
        case .transcriptTooShort:
            return "The transcript is too short for meaningful deeper feedback."
        case .invalidResponse:
            return "The AI response could not be parsed."
        case .apiFailure(let message):
            return message
        }
    }
}

struct AICoachSessionInput {
    let transcript: String
    let mode: PracticeMode
    let score: Int?
    let fillerCount: Int
    let duration: TimeInterval
    let wordsPerMinute: Int
    let speakingIdentity: String
    // --- new, all defaulted (initiative #9: Coach Read parity) ---
    /// The question this rep answered (`PracticeSession.prompt`). Lets the
    /// read judge "did you answer it / where did the point land" — the one
    /// thing a coach checks first. Empty when unknown (legacy/silence).
    let prompt: String
    /// The user's voice goal. Drives the per-voice register line + the
    /// deterministic fallback persona. Nil when not yet set (cold start).
    let voice: SpeakingStyleGoal?
    /// Short descriptors of the last few reps for continuity ("Timed | score
    /// 7 | 2 fillers"). Never invented — built from real sessions at the call
    /// site, current rep dropped.
    let recentSessionSummaries: [String]
    /// Confidence-gated baseline (nil when insufficient data — never a fake
    /// number). Mirrors `PostRepCoachNoteInput.baselineFillerRate`/`PaceWPM`.
    let baselineFillerRate: Double?
    let baselinePaceWPM: Double?
    // --- new, all defaulted (SUBSTANCE-4: standing-case context) ---
    /// The user's STANDING working hypothesis from `CoachMemory` — the durable
    /// read the coach is carrying across reps, not this rep's evidence. Lets the
    /// Coach Read reason over the standing goal/target, not just the last rep.
    /// Nil when no durable hypothesis exists yet (cold start). Built at the call
    /// site from `coachMemoryStore.currentMemory?.workingHypothesis`.
    let standingHypothesis: String?
    /// The observable target of the user's active intervention (reused from the
    /// already-built `CoachCaseFile.observableTarget`, single source of truth —
    /// never re-derived from the raw `activeIntervention`). Nil when no active
    /// intervention.
    let standingObservableTarget: String?
    /// What success on the standing intervention looks like (reused from
    /// `CoachCaseFile.successMeasure`). Nil when no active intervention.
    let standingSuccessMeasure: String?
    /// The active case-file review cadence (reused from
    /// `CoachCaseFile.reviewDueAt`). Nil when no active intervention or review
    /// cadence exists; never synthesized from the current rep.
    let standingReviewDueAt: Date?

    init(
        transcript: String,
        mode: PracticeMode,
        score: Int?,
        fillerCount: Int,
        duration: TimeInterval,
        wordsPerMinute: Int,
        speakingIdentity: String,
        prompt: String = "",
        voice: SpeakingStyleGoal? = nil,
        recentSessionSummaries: [String] = [],
        baselineFillerRate: Double? = nil,
        baselinePaceWPM: Double? = nil,
        standingHypothesis: String? = nil,
        standingObservableTarget: String? = nil,
        standingSuccessMeasure: String? = nil,
        standingReviewDueAt: Date? = nil
    ) {
        self.transcript = transcript
        self.mode = mode
        self.score = score
        self.fillerCount = fillerCount
        self.duration = duration
        self.wordsPerMinute = wordsPerMinute
        self.speakingIdentity = speakingIdentity
        self.prompt = prompt
        self.voice = voice
        self.recentSessionSummaries = recentSessionSummaries
        self.baselineFillerRate = baselineFillerRate
        self.baselinePaceWPM = baselinePaceWPM
        self.standingHypothesis = standingHypothesis
        self.standingObservableTarget = standingObservableTarget
        self.standingSuccessMeasure = standingSuccessMeasure
        self.standingReviewDueAt = standingReviewDueAt
    }
}

protocol AICoachServicing {
    @MainActor
    func generateDeeperFeedback(
        input: AICoachSessionInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) async throws -> AICoachFeedback
}

struct AIHomeRecommendation: Codable, Equatable {
    let title: String
    let detail: String
    let focus: String
    let target: String
    let recommendedMode: String
    let recommendedTone: String?
    let recommendedScenario: String?
    let modeBenefit: String
    let whyMode: String
    let whyNow: String

    enum CodingKeys: String, CodingKey {
        case title
        case detail
        case focus
        case target
        case recommendedMode
        case recommendedTone
        case recommendedScenario
        case modeBenefit
        case whyMode
        case whyNow
    }

    init(
        title: String,
        detail: String,
        focus: String,
        target: String,
        recommendedMode: String,
        recommendedTone: String?,
        recommendedScenario: String?,
        modeBenefit: String,
        whyMode: String,
        whyNow: String
    ) {
        self.title = title
        self.detail = detail
        self.focus = focus
        self.target = target
        self.recommendedMode = recommendedMode
        self.recommendedTone = recommendedTone
        self.recommendedScenario = recommendedScenario
        self.modeBenefit = modeBenefit
        self.whyMode = whyMode
        self.whyNow = whyNow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        focus = try container.decode(String.self, forKey: .focus)
        target = try container.decode(String.self, forKey: .target)
        recommendedMode = try container.decode(String.self, forKey: .recommendedMode)
        recommendedTone = try container.decodeIfPresent(String.self, forKey: .recommendedTone)
        recommendedScenario = try container.decodeIfPresent(String.self, forKey: .recommendedScenario)
        modeBenefit = try container.decodeIfPresent(String.self, forKey: .modeBenefit) ?? ""
        whyMode = try container.decode(String.self, forKey: .whyMode)
        whyNow = try container.decode(String.self, forKey: .whyNow)
    }
}

struct AIHomeRecommendationInput {
    let recentSessionSummary: String
    let averageFillers: Double
    let averageDuration: Double
    let averageWordsPerMinute: Double
    let fillerTrendDelta: Double
    let durationTrendDelta: Double
    let paceTrendDelta: Double
    let averageWordCount: Double
    let strongestMode: PracticeMode?
    let currentIdentity: String
    let currentIdentityEvidence: String
    let styleAlignmentScore: Double
    let sessionStreak: Int
    let daysSinceLastSession: Int
    let preferredModeBias: String
    let preferredToneBias: String
    let preferredScenarioBias: String
    let modeBenefitBias: String
}

enum AIHomeRecommendationContract {
    static func normalized(
        _ recommendation: AIHomeRecommendation,
        input: AIHomeRecommendationInput
    ) -> AIHomeRecommendation? {
        let modeID = normalizedID(recommendation.recommendedMode)
        guard let mode = PracticeMode(rawValue: modeID) else { return nil }

        if let preferredMode = preferredMode(from: input),
           preferredMode != mode {
            return nil
        }

        let toneID = normalizedOptionalID(recommendation.recommendedTone)
        let scenarioID = normalizedOptionalID(recommendation.recommendedScenario)
        let normalizedTone: String?
        let normalizedScenario: String?

        if mode == .imConversation {
            guard let setup = normalizedIMSetup(
                toneID: toneID,
                scenarioID: scenarioID,
                input: input
            ) else {
                return nil
            }
            normalizedTone = setup.tone
            normalizedScenario = setup.scenario
        } else {
            normalizedTone = nil
            normalizedScenario = nil
        }

        guard let title = boundedCopy(recommendation.title, wordLimit: 8),
              let detail = boundedCopy(recommendation.detail, wordLimit: 28),
              let focus = boundedCopy(recommendation.focus, wordLimit: 6),
              let target = boundedCopy(recommendation.target, wordLimit: 8),
              let whyMode = boundedCopy(recommendation.whyMode, wordLimit: 28),
              let whyNow = boundedCopy(recommendation.whyNow, wordLimit: 28) else {
            return nil
        }

        let modeBenefitCandidate = recommendation.modeBenefit
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let modeBenefitSource = modeBenefitCandidate.isEmpty
            ? input.modeBenefitBias
            : modeBenefitCandidate
        guard let modeBenefit = boundedCopy(modeBenefitSource, wordLimit: 28) else {
            return nil
        }

        return AIHomeRecommendation(
            title: title,
            detail: detail,
            focus: focus,
            target: target,
            recommendedMode: mode.rawValue,
            recommendedTone: normalizedTone,
            recommendedScenario: normalizedScenario,
            modeBenefit: modeBenefit,
            whyMode: whyMode,
            whyNow: whyNow
        )
    }

    private static func normalizedIMSetup(
        toneID: String?,
        scenarioID: String?,
        input: AIHomeRecommendationInput
    ) -> (tone: String?, scenario: String?)? {
        let preferredTone = normalizedOptionalID(input.preferredToneBias)
        let preferredScenario = normalizedOptionalID(input.preferredScenarioBias)

        if let preferredTone {
            guard toneID == preferredTone,
                  IMTargetTone(rawValue: preferredTone) != nil else {
                return nil
            }
        } else if let toneID, IMTargetTone(rawValue: toneID) == nil {
            return nil
        }

        if let preferredScenario {
            guard scenarioID == preferredScenario,
                  IMConversationScenario(rawValue: preferredScenario) != nil else {
                return nil
            }
        } else if let scenarioID, IMConversationScenario(rawValue: scenarioID) == nil {
            return nil
        }

        return (
            tone: preferredTone ?? toneID,
            scenario: preferredScenario ?? scenarioID
        )
    }

    private static func preferredMode(from input: AIHomeRecommendationInput) -> PracticeMode? {
        PracticeMode(rawValue: normalizedID(input.preferredModeBias))
    }

    private static func normalizedID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedOptionalID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = normalizedID(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func boundedCopy(_ value: String, wordLimit: Int) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, passesCoachVoiceContract(trimmed) else {
            return nil
        }
        return trimmed.truncatedToWordLimit(wordLimit)
    }

    private static func passesCoachVoiceContract(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        guard !value.contains("!"),
              !lowercased.contains("let's"),
              !lowercased.contains("great job"),
              !lowercased.contains("the user"),
              !lowercased.contains("they need"),
              !lowercased.contains("their ") else {
            return false
        }
        return true
    }
}

struct PracticeModePlaybookEntry {
    let mode: PracticeMode
    let benefit: String
    let bestFor: String
}

enum RecommendationBlueprintSource: Equatable {
    case coldStart
    case goalBias
    case imToneDrill
    case caseIntervention
    case adaptationBias

    var trackingLabel: String {
        switch self {
        case .coldStart: return "coldStart"
        case .goalBias: return "goalBias"
        case .imToneDrill: return "imToneDrill"
        case .caseIntervention: return "caseIntervention"
        case .adaptationBias: return "adaptationBias"
        }
    }
}

struct RecommendationBiasBlueprint {
    let recommendedMode: PracticeMode
    let recommendedTone: IMTargetTone?
    let recommendedScenario: IMConversationScenario?
    let focus: String
    let target: String
    let modeBenefit: String
    let whyMode: String
    let whyNow: String
    /// Suggested Timed difficulty based on the user's coaching goal.
    /// `nil` if the recommended mode is not Timed or no profile is set.
    let suggestedTimedDifficulty: TimedPracticeDifficulty?
    /// Prompt theme that best matches this user's coaching goal.
    let suggestedTheme: PromptTheme
    /// Why this blueprint won precedence. Surfaces can use this to keep an
    /// active coaching intervention from being displaced by stale AI copy.
    let source: RecommendationBlueprintSource

    init(
        recommendedMode: PracticeMode,
        recommendedTone: IMTargetTone?,
        recommendedScenario: IMConversationScenario?,
        focus: String,
        target: String,
        modeBenefit: String,
        whyMode: String,
        whyNow: String,
        suggestedTimedDifficulty: TimedPracticeDifficulty?,
        suggestedTheme: PromptTheme,
        source: RecommendationBlueprintSource = .goalBias
    ) {
        self.recommendedMode = recommendedMode
        self.recommendedTone = recommendedTone
        self.recommendedScenario = recommendedScenario
        self.focus = focus
        self.target = target
        self.modeBenefit = modeBenefit
        self.whyMode = whyMode
        self.whyNow = whyNow
        self.suggestedTimedDifficulty = suggestedTimedDifficulty
        self.suggestedTheme = suggestedTheme
        self.source = source
    }
}

enum RecommendationSessionSummaryStyle {
    case detailed
    case compact
    case empty
}

struct RecommendationBiasContext {
    let input: AIHomeRecommendationInput
    let plan: CoachingPlan?
    let imToneSignal: IMToneDrillSignal?
    let blueprint: RecommendationBiasBlueprint
}

enum RecommendationBiasContextBuilder {
    static func context(
        profile: CoachingProfile?,
        sessions: [PracticeSession],
        sessionStreak: Int,
        daysSinceLastSession: Int,
        coachMemory: CoachMemory?,
        imAvailable: Bool,
        recommendationOutcomes: [RecommendationOutcome] = [],
        summaryStyle: RecommendationSessionSummaryStyle = .detailed,
        preferredModeBias: String = "",
        preferredToneBias: String = "",
        preferredScenarioBias: String = "",
        modeBenefitBias: String = ""
    ) -> RecommendationBiasContext {
        let plan = CoachingPlanner.plan(for: sessions, profile: profile)
        let input = input(
            profile: profile,
            sessions: sessions,
            plan: plan,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            summaryStyle: summaryStyle,
            preferredModeBias: preferredModeBias,
            preferredToneBias: preferredToneBias,
            preferredScenarioBias: preferredScenarioBias,
            modeBenefitBias: modeBenefitBias
        )
        let imToneSignal = imAvailable ? IMHistorySummary.toneDrillSignal(from: sessions) : nil
        let blueprint = RecommendationBiasEngine.blueprint(
            profile: profile,
            input: input,
            plan: plan,
            imToneSignal: imToneSignal,
            coachMemory: coachMemory,
            recommendationOutcomes: recommendationOutcomes
        )
        return RecommendationBiasContext(
            input: input,
            plan: plan,
            imToneSignal: imToneSignal,
            blueprint: blueprint
        )
    }

    static func input(
        profile: CoachingProfile?,
        sessions: [PracticeSession],
        plan: CoachingPlan?,
        sessionStreak: Int,
        daysSinceLastSession: Int,
        summaryStyle: RecommendationSessionSummaryStyle = .detailed,
        preferredModeBias: String = "",
        preferredToneBias: String = "",
        preferredScenarioBias: String = "",
        modeBenefitBias: String = ""
    ) -> AIHomeRecommendationInput {
        let recent = Array(sessions.prefix(5))
        let previous = Array(sessions.dropFirst(5).prefix(5))
        let identity = PracticeEvaluator.speakingIdentity(
            for: recent.first?.transcript ?? "",
            profile: profile
        )
        let styleTrend = PracticeEvaluator.styleTrendSnapshot(
            transcript: recent.first?.transcript ?? "",
            recentSessions: recent,
            profile: profile
        )

        return AIHomeRecommendationInput(
            recentSessionSummary: recentSessionSummary(
                from: recent,
                profile: profile,
                style: summaryStyle
            ),
            averageFillers: average(recent.map { Double($0.fillerWordCount) }),
            averageDuration: average(recent.map(\.duration)),
            averageWordsPerMinute: average(recent.map { Double($0.wordsPerMinute) }),
            fillerTrendDelta: trendDelta(
                current: recent.map { Double($0.fillerWordCount) },
                previous: previous.map { Double($0.fillerWordCount) }
            ),
            durationTrendDelta: trendDelta(
                current: recent.map(\.duration),
                previous: previous.map(\.duration)
            ),
            paceTrendDelta: trendDelta(
                current: recent.map { Double($0.wordsPerMinute) },
                previous: previous.map { Double($0.wordsPerMinute) }
            ),
            averageWordCount: average(recent.map { Double($0.wordCount) }),
            strongestMode: plan?.strongestMode,
            currentIdentity: identity.identity,
            currentIdentityEvidence: identity.evidence,
            styleAlignmentScore: styleTrend.currentAlignment,
            sessionStreak: sessionStreak,
            daysSinceLastSession: daysSinceLastSession,
            preferredModeBias: preferredModeBias,
            preferredToneBias: preferredToneBias,
            preferredScenarioBias: preferredScenarioBias,
            modeBenefitBias: modeBenefitBias
        )
    }

    private static func recentSessionSummary(
        from sessions: [PracticeSession],
        profile: CoachingProfile?,
        style: RecommendationSessionSummaryStyle
    ) -> String {
        guard !sessions.isEmpty else { return "No recent sessions yet." }

        switch style {
        case .empty:
            return ""
        case .compact:
            return sessions.map { session in
                "\(session.mode.displayLabel): \(session.fillerWordCount) fillers, \(Int(session.duration))s"
            }.joined(separator: " • ")
        case .detailed:
            return sessions.enumerated().map { index, session in
                let scoreText = session.score.map(String.init) ?? "n/a"
                let pace = PracticeEvaluator.paceSnapshot(
                    forTranscript: session.transcript,
                    duration: session.duration
                )
                let identity = PracticeEvaluator.speakingIdentity(
                    for: session.transcript,
                    profile: profile
                )
                return "Session \(index + 1): mode=\(session.mode.rawValue), fillers=\(session.fillerWordCount), duration=\(Int(session.duration))s, words=\(session.wordCount), wpm=\(session.wordsPerMinute), paceLabel=\(pace.label), score=\(scoreText), headline=\(session.headline ?? "none"), identity=\(identity.identity)"
            }.joined(separator: "\n")
        }
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func trendDelta(current: [Double], previous: [Double]) -> Double {
        guard !current.isEmpty, !previous.isEmpty else { return 0 }
        return average(current) - average(previous)
    }
}

/// How a scenario's tone-match rate has moved across the user's recent
/// reps — the *Adaptation* read (docs/VISION.md coach-parity stage #4).
/// The drill prescription says "work on this"; this says whether the
/// work is paying off, so the coach can reinforce a drill that is landing
/// or change the approach on one that is not. Produced by
/// `IMHistorySummary.toneDrillProgress(from:scenario:)`, which compares
/// the hit rate of the earliest vs the latest window of evaluated reps.
/// `nil` (carried as `IMToneDrillSignal.progress == nil`) when there
/// aren't enough evaluated reps to compare two disjoint windows honestly.
struct IMToneDrillProgress: Equatable {
    /// The value-judged direction of the tone-match rate. Unlike the raw
    /// `IMScenarioRelationalTrend.Movement`, this is goal-oriented — a
    /// higher hit rate is unambiguously better — because its only
    /// consumer is the deterministic recommendation copy, not a chip the
    /// view colours itself.
    enum Direction: Equatable {
        case recovering   // recent window beats the earlier one — the drill is working
        case stalled      // flat within the threshold — not getting better, not worse
        case slipping     // recent window is worse — the approach needs to change
    }
    let direction: Direction
    /// Tone-match rate (0.0–1.0) of the earliest `windowSize` evaluated reps.
    let earlierRate: Double
    /// Tone-match rate (0.0–1.0) of the latest `windowSize` evaluated reps.
    let recentRate: Double
    /// Reps averaged in each window (the `min(3, count / 2)` bound, so the
    /// earliest and latest stretches never overlap).
    let windowSize: Int
}

/// A scenario where the user reliably misses the IM tone they committed
/// to at setup, surfaced as a focused, auto-fillable drill. Produced by
/// `IMHistorySummary.toneDrillSignal(from:)` only when the evidence bar
/// clears (≥ `toneDrillMinEvaluatedReps` evaluated reps AND a hit rate
/// below `toneDrillMatchRateThreshold`), so a thin or random miss never
/// fabricates a recommendation. `matchRate` is 0.0–1.0; `targetTone` is
/// the tone the user committed to most in that scenario — the exact
/// target the re-rep should re-set, not a generic profile default.
/// `progress` carries the Adaptation read for that scenario (whether the
/// hit rate is recovering, stalled, or slipping) so the engine can
/// reinforce a working drill or change the approach on a stuck one; it is
/// `nil` below the 4-rep two-window bar, in which case the engine gives
/// the neutral prescription.
struct IMToneDrillSignal: Equatable {
    let scenario: IMConversationScenario
    let targetTone: IMTargetTone
    let matchRate: Double
    let evaluatedCount: Int
    let progress: IMToneDrillProgress?

    init(
        scenario: IMConversationScenario,
        targetTone: IMTargetTone,
        matchRate: Double,
        evaluatedCount: Int,
        progress: IMToneDrillProgress? = nil
    ) {
        self.scenario = scenario
        self.targetTone = targetTone
        self.matchRate = matchRate
        self.evaluatedCount = evaluatedCount
        self.progress = progress
    }
}

/// A scenario where the user *used to* miss the IM tone they committed to
/// but has since recovered and is now holding above the drill bar — the
/// win, surfaced so the coach can name it instead of going silent the
/// moment a drill is won. The complement to `IMToneDrillSignal` (which
/// prescribes a still-failing drill and self-clears on recovery) and
/// `IMToneDrillProgress` (the in-flight Adaptation read). Produced by
/// `IMHistorySummary.toneDrillResolved(from:)` only with genuine
/// turnaround evidence: an earliest window below the drill bar (a real gap
/// existed), a latest window holding at/above `toneDrillResolvedHoldRate`
/// (the climb stuck), and an overall rate at/above the drill bar so the
/// active-drill signal has already cleared — "solved" and "still drilling"
/// can never both fire for one scenario. `earlierRate`/`recentRate` are
/// 0.0–1.0; `lastEvaluatedDate` is the most-recent evaluated rep so the
/// coach can acknowledge the freshest win first.
struct IMToneDrillResolved: Equatable {
    let scenario: IMConversationScenario
    let targetTone: IMTargetTone
    let earlierRate: Double
    let recentRate: Double
    let evaluatedCount: Int
    let lastEvaluatedDate: Date
}

enum RecommendationBiasEngine {
    static let playbook: [PracticeModePlaybookEntry] = [
        .init(
            mode: .timed,
            benefit: "Best for building structure, clean openings, and complete answers before pressure breaks the thought.",
            bestFor: "Users who need clearer structure, longer answers, or steadier pacing."
        ),
        .init(
            mode: .suddenDeath,
            benefit: "Best for fast thinking and composure when there is no warm-up and every hesitation gets exposed.",
            bestFor: "Users who freeze, overthink, or need sharper recall under pressure."
        ),
        .init(
            mode: .ahCounter,
            benefit: "Best for real-time filler awareness and replacing verbal clutter with cleaner pauses.",
            bestFor: "Users whose main drag is fillers, rambling, or rushed delivery."
        ),
        .init(
            mode: .imConversation,
            benefit: "Best for training tone, relationship reading, and saying the right thing cleanly in a live exchange.",
            bestFor: "Users who want better small talk, work conversations, networking, or difficult-message control."
        )
    ]

    static func blueprint(
        profile: CoachingProfile?,
        input: AIHomeRecommendationInput,
        plan: CoachingPlan?,
        imToneSignal: IMToneDrillSignal? = nil,
        coachMemory: CoachMemory? = nil,
        recommendationOutcomes: [RecommendationOutcome] = []
    ) -> RecommendationBiasBlueprint {
        // The durable case file is the professional-coach layer: if the
        // coach has prescribed an intervention and has not yet gathered
        // enough honest evidence, keep the next recommendation on that
        // intervention. This prevents the app from behaving like a fresh
        // stateless recommender after every rep.
        if let caseBlueprint = caseInterventionBlueprint(
            profile: profile,
            input: input,
            memory: coachMemory
        ) {
            return caseBlueprint
        }

        // A scenario where the committed tone reliably misses is a
        // concrete, evidence-backed intervention — the read side of
        // this loop (the trust/tension + tone-match chips on IM
        // History) is already surfaced, so the next coaching move is
        // to *act* on it. When the caller hands up a signal it has
        // already cleared the honest bar (≥3 evaluated reps, sub-40%
        // hit rate), so it takes precedence over the generic
        // goal-based bias and prescribes the exact scenario + tone to
        // re-drill. The signal self-clears once the hit rate recovers,
        // so this never gets stuck recommending a scenario the user
        // has already fixed.
        if let imToneSignal {
            return toneDrillBlueprint(signal: imToneSignal)
        }

        guard let profile else {
            let defaultMode: PracticeMode = input.averageFillers >= 4 ? .ahCounter : (input.averageDuration < 20 ? .timed : .suddenDeath)
            let modeRead = adaptedMode(
                from: [defaultMode, .timed, .ahCounter, .suddenDeath, .imConversation],
                recommendationOutcomes: recommendationOutcomes
            )
            let mode = modeRead.mode
            return RecommendationBiasBlueprint(
                recommendedMode: mode,
                recommendedTone: nil,
                recommendedScenario: nil,
                focus: mode == .ahCounter ? "Cleaner delivery" : "Baseline control",
                target: mode == .ahCounter ? "Cut fillers by 1" : "One complete rep",
                modeBenefit: playbookEntry(for: mode).benefit,
                whyMode: playbookEntry(for: mode).bestFor,
                whyNow: adaptationWhyNow(replacedMode: modeRead.replacedMode, selectedMode: mode)
                    ?? (input.daysSinceLastSession > 2 ? "The fastest win is getting back into a clean practice rhythm." : "Your recent sessions still need a steadier baseline."),
                suggestedTimedDifficulty: nil,
                suggestedTheme: .all,
                source: modeRead.replacedMode == nil ? .coldStart : .adaptationBias
            )
        }

        let tone = recommendedTone(for: profile)
        let scenario = recommendedScenario(for: profile)
        let priorities = prioritizedModes(for: profile)
        let modeRead = preferredMode(
            from: priorities,
            strongestMode: plan?.strongestMode,
            recommendationOutcomes: recommendationOutcomes
        )
        let mode = modeRead.mode
        let benefit = playbookEntry(for: mode)
        let target = target(for: mode, profile: profile, input: input)
        let focus = focus(for: mode, profile: profile)
        let whyNow = adaptationWhyNow(replacedMode: modeRead.replacedMode, selectedMode: mode)
            ?? whyNow(for: mode, profile: profile, input: input)
        let difficulty = mode == .timed ? suggestedTimedDifficulty(for: profile) : nil
        let theme = suggestedTheme(for: profile)

        return RecommendationBiasBlueprint(
            recommendedMode: mode,
            recommendedTone: mode == .imConversation ? tone : nil,
            recommendedScenario: mode == .imConversation ? scenario : nil,
            focus: focus,
            target: target,
            modeBenefit: benefit.benefit,
            whyMode: benefit.bestFor + " This lines up with your north star.",
            whyNow: whyNow,
            suggestedTimedDifficulty: difficulty,
            suggestedTheme: theme,
            source: modeRead.replacedMode == nil ? .goalBias : .adaptationBias
        )
    }

    private static func caseInterventionBlueprint(
        profile: CoachingProfile?,
        input: AIHomeRecommendationInput,
        memory: CoachMemory?
    ) -> RecommendationBiasBlueprint? {
        guard let memory,
              memory.evidenceConfidence >= .tentative,
              let intervention = memory.activeIntervention,
              shouldContinueCaseIntervention(intervention) else {
            return nil
        }

        let mode = intervention.mode
        let benefit = playbookEntry(for: mode)
        let focus = caseFocus(for: intervention)
        let target = caseTarget(for: intervention)
        let theme = profile.map { suggestedTheme(for: $0) } ?? .all
        let timedDifficulty = mode == .timed ? profile.map { suggestedTimedDifficulty(for: $0) } : nil
        let tone = mode == .imConversation ? profile.map { recommendedTone(for: $0) } : nil
        let scenario = mode == .imConversation ? profile.map { recommendedScenario(for: $0) } : nil

        return RecommendationBiasBlueprint(
            recommendedMode: mode,
            recommendedTone: tone,
            recommendedScenario: scenario,
            focus: focus,
            target: target,
            modeBenefit: benefit.benefit,
            whyMode: caseWhyMode(for: intervention, focus: focus),
            whyNow: caseWhyNow(for: intervention, input: input),
            suggestedTimedDifficulty: timedDifficulty,
            suggestedTheme: theme,
            source: .caseIntervention
        )
    }

    private static func shouldContinueCaseIntervention(_ intervention: CoachIntervention) -> Bool {
        switch intervention.reviewStatus {
        case .awaitingAttempt, .formingEvidence, .continueAndVerify:
            return true
        case .diagnoseBeforeRepeating, .adaptBeforeRepeating:
            return false
        }
    }

    private static func caseFocus(for intervention: CoachIntervention) -> String {
        let candidates = [intervention.focus, intervention.title]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            ?? intervention.mode.displayLabel
    }

    private static func caseTarget(for intervention: CoachIntervention) -> String {
        if let target = intervention.target?.trimmingCharacters(in: .whitespacesAndNewlines),
           !target.isEmpty {
            return target
        }
        if let criterion = intervention.successCriterion?.summary.trimmingCharacters(in: .whitespacesAndNewlines),
           !criterion.isEmpty {
            return criterion
        }
        return "One followed rep"
    }

    private static func caseWhyMode(for intervention: CoachIntervention, focus: String) -> String {
        let modeName = intervention.mode.displayLabel
        switch intervention.reviewStatus {
        case .awaitingAttempt:
            return "\(modeName) is the open case-file intervention for \(focus.lowercased()); Noum needs one followed rep before judging it."
        case .formingEvidence:
            return "\(modeName) is still the active intervention for \(focus.lowercased()); keep collecting reps before strengthening the claim."
        case .continueAndVerify:
            return "\(modeName) is showing promise for \(focus.lowercased()); verify it once more before raising the confidence."
        case .diagnoseBeforeRepeating, .adaptBeforeRepeating:
            return intervention.reviewBasis
        }
    }

    private static func caseWhyNow(
        for intervention: CoachIntervention,
        input: AIHomeRecommendationInput
    ) -> String {
        let observed = intervention.followedRepCount
        let minimum = max(1, intervention.minimumFollowedRepsForReview)
        let remaining = max(0, minimum - observed)

        switch intervention.reviewStatus {
        case .awaitingAttempt:
            return "This was prescribed in the current case file, but Noum has not observed a followed rep yet."
        case .formingEvidence:
            if remaining <= 1 {
                return "The case file has \(observed) of \(minimum) followed reps. One more makes the review more honest."
            }
            return "The case file has \(observed) of \(minimum) followed reps. \(remaining) more reps make the review more honest."
        case .continueAndVerify:
            if let status = intervention.criterionStatus {
                return "Early response is \(status.contextLabel); run one more rep to verify it holds."
            }
            return "Early response looks promising; run one more rep to verify it holds."
        case .diagnoseBeforeRepeating, .adaptBeforeRepeating:
            return input.daysSinceLastSession > 2
                ? "The case needs a fresh read before repeating the same prescription."
                : intervention.reviewBasis
        }
    }

    /// Builds the focused "drill this scenario's tone" recommendation
    /// from a tone-drill signal. Biases to IM (the relevant skill area
    /// for tone) and prefills the exact scenario + the tone the user
    /// keeps missing, so the home CTA is a one-tap re-rep of the
    /// weakest setup. Copy reports the *observed* hit rate — no AI
    /// reframe, no shame; the amber read is informative, the fix is a
    /// rep, not a lecture.
    ///
    /// When the signal carries an Adaptation read (`progress`), the copy
    /// closes the coach-parity loop's fourth stage: a *recovering* rate
    /// reinforces the drill the user is already on ("it's working — one
    /// more"); a *slipping* rate changes the approach ("same scenario,
    /// open it differently") rather than repeating the identical ask;
    /// a *stalled* read or no read falls back to the neutral prescription
    /// reporting the overall hit rate. The mode/scenario/tone prefill is
    /// identical across all branches — only the rationale adapts.
    private static func toneDrillBlueprint(signal: IMToneDrillSignal) -> RecommendationBiasBlueprint {
        let benefit = playbookEntry(for: .imConversation)
        let scenario = signal.scenario.title
        let tone = signal.targetTone.title
        let lowerTone = tone.lowercased()
        let pct = Int((signal.matchRate * 100).rounded())

        let whyMode: String
        let whyNow: String
        switch signal.progress?.direction {
        case .recovering:
            let recentPct = Int(((signal.progress?.recentRate ?? 0) * 100).rounded())
            let earlierPct = Int(((signal.progress?.earlierRate ?? 0) * 100).rounded())
            whyMode = "Your \(lowerTone) tone is landing more often than it was — the drill is working. One more focused rep locks it in."
            whyNow = "Across your latest \(scenario) reps your \(lowerTone) tone is up to \(recentPct)% from \(earlierPct)%. Keep the same scenario and hold the tone end to end."
        case .slipping:
            let recentPct = Int(((signal.progress?.recentRate ?? 0) * 100).rounded())
            let earlierPct = Int(((signal.progress?.earlierRate ?? 0) * 100).rounded())
            whyMode = "Your \(lowerTone) tone slipped back in this setup — same scenario, but change how you open it."
            whyNow = "Your \(lowerTone) tone dropped to \(recentPct)% across your latest \(scenario) reps, down from \(earlierPct)%. Re-run it slower and commit to the tone from the first beat."
        case .stalled, .none:
            whyMode = "Your committed tone keeps slipping in this exact setup — drilling the same scenario is where it gets fixed."
            whyNow = "Across your last \(signal.evaluatedCount) \(scenario) reps your \(lowerTone) tone landed only \(pct)% of the time. Re-run the same scenario and hold the tone end to end."
        }

        return RecommendationBiasBlueprint(
            recommendedMode: .imConversation,
            recommendedTone: signal.targetTone,
            recommendedScenario: signal.scenario,
            focus: "\(scenario) tone",
            target: "Land \(lowerTone) in \(scenario)",
            modeBenefit: benefit.benefit,
            whyMode: whyMode,
            whyNow: whyNow,
            suggestedTimedDifficulty: nil,
            suggestedTheme: .all,
            source: .imToneDrill
        )
    }

    /// Maps a coaching goal to a suggested Timed difficulty.
    private static func suggestedTimedDifficulty(for profile: CoachingProfile) -> TimedPracticeDifficulty {
        switch profile.primaryGoal {
        case .moreConcise:  return .hard    // 15s forces conciseness
        case .thinkFaster:  return .medium  // 30s balanced speed + structure
        case .reduceFillers: return .medium // 30s — enough time to self-monitor
        case .calmerDelivery: return .easy  // 60s — room to compose and pace
        }
    }

    /// Maps a coaching goal to the prompt theme most likely to surface useful practice.
    private static func suggestedTheme(for profile: CoachingProfile) -> PromptTheme {
        switch profile.primaryGoal {
        case .moreConcise:
            return profile.speakingContext == .interviews ? .interviewPrep : .workCareer
        case .thinkFaster:
            return profile.biggestChallenge == .freezing ? .general : .funRandom
        case .reduceFillers:
            return .all
        case .calmerDelivery:
            return profile.speakingContext == .social ? .socialConfidence : .ethicsOpinions
        }
    }

    private static func prioritizedModes(for profile: CoachingProfile) -> [PracticeMode] {
        switch (profile.primaryGoal, profile.biggestChallenge) {
        case (.reduceFillers, _), (_, .fillerWords):
            return [.ahCounter, .suddenDeath, .timed, .imConversation]
        case (.moreConcise, _), (_, .rambling):
            return [.timed, .imConversation, .ahCounter, .suddenDeath]
        case (.thinkFaster, _), (_, .freezing):
            return [.suddenDeath, .timed, .imConversation, .ahCounter]
        case (.calmerDelivery, _), (_, .rushing):
            return [.imConversation, .timed, .ahCounter, .suddenDeath]
        }
    }

    private static func preferredMode(
        from priorities: [PracticeMode],
        strongestMode: PracticeMode?,
        recommendationOutcomes: [RecommendationOutcome]
    ) -> (mode: PracticeMode, replacedMode: PracticeMode?) {
        guard let first = priorities.first else { return (.timed, nil) }
        let ordered: [PracticeMode]
        if strongestMode == first, priorities.count > 1 {
            ordered = Array(priorities.dropFirst()) + [first]
        } else {
            ordered = priorities
        }
        return adaptedMode(from: ordered, recommendationOutcomes: recommendationOutcomes)
    }

    private static func adaptedMode(
        from candidates: [PracticeMode],
        recommendationOutcomes: [RecommendationOutcome]
    ) -> (mode: PracticeMode, replacedMode: PracticeMode?) {
        let ordered = deduplicated(candidates)
        let fallback = ordered.first ?? .timed
        guard RecommendationAdaptationAnalyzer.confidentlyReplaces(mode: fallback, in: recommendationOutcomes),
              let replacement = ordered.dropFirst().first(where: {
                  !RecommendationAdaptationAnalyzer.confidentlyReplaces(mode: $0, in: recommendationOutcomes)
              }) else {
            return (fallback, nil)
        }
        return (replacement, fallback)
    }

    private static func deduplicated(_ modes: [PracticeMode]) -> [PracticeMode] {
        var result: [PracticeMode] = []
        for mode in modes where !result.contains(mode) {
            result.append(mode)
        }
        return result
    }

    private static func adaptationWhyNow(replacedMode: PracticeMode?, selectedMode: PracticeMode) -> String? {
        guard let replacedMode else { return nil }
        return "Across enough followed \(replacedMode.displayLabel) reps, your metric has trended down alongside that mode, so this switches to \(selectedMode.displayLabel) while keeping the same coaching goal."
    }

    private static func recommendedTone(for profile: CoachingProfile) -> IMTargetTone {
        switch profile.speakingStyleGoal {
        case .warm: return .warm
        case .concise: return .concise
        case .persuasive: return .assertive
        case .executive: return .professional
        case .storytelling: return .confident
        case .authoritative: return .confident
        }
    }

    private static func recommendedScenario(for profile: CoachingProfile) -> IMConversationScenario {
        switch profile.speakingContext {
        case .social:
            return .socialCatchUp
        case .work, .presentations:
            return profile.primaryGoal == .calmerDelivery ? .difficultConversation : .workUpdate
        case .interviews:
            return profile.primaryGoal == .thinkFaster ? .networking : .workUpdate
        }
    }

    private static func focus(for mode: PracticeMode, profile: CoachingProfile) -> String {
        switch mode {
        case .timed:
            return "Structured delivery"
        case .suddenDeath:
            return "Thinking on your feet"
        case .ahCounter:
            return "Filler control"
        case .imConversation:
            return "\(profile.speakingContext.title) realism"
        }
    }

    private static func target(for mode: PracticeMode, profile: CoachingProfile, input: AIHomeRecommendationInput) -> String {
        switch mode {
        case .timed:
            return profile.primaryGoal == .moreConcise ? "45s, clean structure" : "One complete answer"
        case .suddenDeath:
            return profile.primaryGoal == .thinkFaster ? "Fast clear reply" : "Zero panic fillers"
        case .ahCounter:
            return input.averageFillers >= 5 ? "Cut fillers by 2" : "Zero filler start"
        case .imConversation:
            return "\(recommendedTone(for: profile).title) \(recommendedScenario(for: profile).title)"
        }
    }

    private static func whyNow(for mode: PracticeMode, profile: CoachingProfile, input: AIHomeRecommendationInput) -> String {
        if input.daysSinceLastSession > 2 {
            return "You've been away from the rhythm, so this drill reconnects the next rep to the communication goal you chose."
        }

        switch mode {
        case .timed:
            return "Your recent reps still need stronger structure before pressure gets layered on."
        case .suddenDeath:
            return "You need a cleaner reaction under pressure, not more time to polish the answer."
        case .ahCounter:
            return "Verbal clutter is still costing clarity, so awareness needs to happen live."
        case .imConversation:
            return "Your goal depends on sounding right with another person, not just speaking cleanly in isolation."
        }
    }

    private static func playbookEntry(for mode: PracticeMode) -> PracticeModePlaybookEntry {
        playbook.first(where: { $0.mode == mode }) ?? playbook[0]
    }
}

protocol AIHomeRecommendationServicing {
    @MainActor
    func generateHomeRecommendation(
        input: AIHomeRecommendationInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) async throws -> AIHomeRecommendation
}

@MainActor
struct IMConversationService: IMConversationServicing {
    private let settings = AISettingsManager.shared

    func generateReply(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        state: IMConversationState,
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        context: IMSessionContext,
        latestUserSignal: IMUserMessageSignal?
    ) async throws -> IMConversationReply {
        guard IMModeAvailability.isAvailable else {
            throw IMModeServiceError.unavailable
        }

        guard let provider = settings.activeProvider,
              let apiKey = apiKey(for: provider),
              let endpoint = provider.endpoint else {
            if let backendReply = try? await backendReply(
                setup: setup,
                turns: turns,
                state: state,
                profile: profile,
                relationship: relationship,
                context: context,
                latestUserSignal: latestUserSignal
            ) {
                return backendReply
            }
            throw IMModeServiceError.unavailable
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = prompt(
            for: setup,
            turns: turns,
            state: state,
            profile: profile,
            relationship: relationship,
            context: context,
            latestUserSignal: latestUserSignal
        )
        switch provider {
        case .none:
            throw IMModeServiceError.unavailable
        case .openAI, .deepSeek:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let body = OpenAICompatibleChatRequest(
                model: provider.model,
                messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: prompt)
                ],
                temperature: 0.7,
                responseFormat: .jsonObject
            )
            request.httpBody = try JSONEncoder().encode(body)
        case .gemini:
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let body = GeminiGenerateContentRequest(
                systemInstruction: .init(parts: [.init(text: systemPrompt)]),
                contents: [.init(parts: [.init(text: prompt)])],
                generationConfig: .init(
                    temperature: 0.7,
                    responseMimeType: "application/json"
                )
            )
            request.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw IMModeServiceError.replyGenerationFailed("HTTP request failed")
            }

            let jsonData = try extractJSONData(from: data, provider: provider)
            let decoded = try decodeIMConversationReply(from: jsonData)
            return IMConversationReply(
                message: decoded.message.truncatedToWordLimit(30),
                shouldWrapUp: decoded.shouldWrapUp,
                updatedState: IMConversationState(
                    trust: decoded.updatedState.normalizedTrust,
                    engagement: decoded.updatedState.normalizedEngagement,
                    tension: decoded.updatedState.normalizedTension,
                    beat: decoded.updatedState.beat
                )
            )
        } catch {
            if let backendReply = try? await backendReply(
                setup: setup,
                turns: turns,
                state: state,
                profile: profile,
                relationship: relationship,
                context: context,
                latestUserSignal: latestUserSignal
            ) {
                return backendReply
            }
            throw IMModeServiceError.replyGenerationFailed(error.localizedDescription)
        }
    }

    private func backendReply(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        state: IMConversationState,
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        context: IMSessionContext,
        latestUserSignal: IMUserMessageSignal?
    ) async throws -> IMConversationReply? {
        guard var request = backendRequest(path: "/v1/im/reply") else { return nil }
        let body = BackendIMConversationReplyRequest(
            setup: setup,
            turns: turns,
            state: state,
            profile: profile,
            relationship: relationship,
            context: context
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(IMConversationReply.self, from: data)
        return IMConversationReply(
            message: decoded.message.truncatedToWordLimit(30),
            shouldWrapUp: decoded.shouldWrapUp,
            updatedState: IMConversationState(
                trust: decoded.updatedState.normalizedTrust,
                engagement: decoded.updatedState.normalizedEngagement,
                tension: decoded.updatedState.normalizedTension,
                beat: decoded.updatedState.beat
            )
        )
    }

    private var systemPrompt: String {
        """
        You are roleplaying one human in a realistic text conversation.
        Reply with JSON only using keys: message, shouldWrapUp, updatedState.
        Hard rules:
        - message must be conversational and sound like texting or IM, not coaching
        - message should usually be 8 to 18 words and never exceed 30 words
        - do not use bullets, emojis, stage directions, or explanations
        - never mention being AI
        - ask or react naturally
        - one conversational move per message
        - keep pressure and realism appropriate to the scenario
        - the opening message must feel like something a real person would actually send first in that exact context
        - if context is relevant, use at most one concrete contextual cue in the opener
        - if context would sound forced, ignore it and open naturally from relationship + scenario instead
        """
    }

    private func prompt(
        for setup: IMConversationSetup,
        turns: [IMConversationTurn],
        state: IMConversationState,
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        context: IMSessionContext,
        latestUserSignal: IMUserMessageSignal?
    ) -> String {
        let userTurnCount = turns.filter { $0.speaker == .user }.count
        let lastUserMessage = turns.last(where: { $0.speaker == .user })?.text ?? "none yet"
        let contextEnvelope = setup.scenario.relevantContextEnvelope(from: context, relationship: relationship)
        let conversationPhase: String
        switch userTurnCount {
        case 0...1:
            conversationPhase = "opening"
        case 2...3:
            conversationPhase = "middle"
        default:
            conversationPhase = "late"
        }

        let escalationInstruction: String
        switch setup.scenario {
        case .socialCatchUp:
            escalationInstruction = conversationPhase == "late" ? "Start testing whether the conversation still has energy or should naturally close." : "Stay friendly, but make the user earn the flow by being specific."
        case .workUpdate:
            escalationInstruction = conversationPhase == "late" ? "Push for the clearest headline and one practical takeaway." : "Ask for clarity, specifics, or the practical point."
        case .difficultConversation:
            escalationInstruction = conversationPhase == "late" ? "Push slightly harder and check whether the user stays calm and direct." : "Apply mild pressure and ask the user to clarify intent."
        case .networking:
            escalationInstruction = conversationPhase == "late" ? "Test whether the user can keep warmth while becoming more memorable or specific." : "Reward good specificity and push back on generic answers."
        }

        let transcript = turns.map { turn in
            let speaker = turn.speaker == .user ? "User" : setup.scenario.personaName
            return "\(speaker): \(turn.text)"
        }.joined(separator: "\n")

        return """
        Scenario: \(setup.scenario.title)
        Persona name: \(setup.scenario.personaName)
        Persona role: \(setup.scenario.personaRole)
        Stakes: \(setup.scenario.stakes)
        Persona mood: \(setup.scenario.currentMood)
        Persona goal: \(setup.scenario.conversationGoal)
        Persona friction style: \(setup.scenario.frictionStyle)
        Persona tolerance profile: \(setup.scenario.toleranceProfile.summary)
        User target tone: \(setup.targetTone.title)
        User tone goal: \(setup.targetTone.coachingPrompt)
        Speaker context: \(profile?.speakingContext.title ?? "unknown")
        Speaker priority: \(profile?.primaryGoal.title ?? "unknown")
        Biggest challenge: \(profile?.biggestChallenge.title ?? "unknown")
        Desired outcome: \(profile?.desiredOutcome.title ?? "unknown")
        Desired style: \(profile?.speakingStyleGoal.title ?? "unknown")
        Personal goal reference: \(profile?.personalGoalReference ?? "none")
        Communication north star: \(profile?.communicationNorthStar ?? "Help the user become a stronger communicator over time.")
        In-conversation training focus: \(profile?.inConversationTrainingFocus ?? "Reward clear, human, well-calibrated communication that would strengthen a real relationship.")
        Relationship memory: \(relationship?.promptSummary ?? "No prior relationship memory yet. Treat this as an early interaction and calibrate based on consistency, reciprocity, and relevance.")
        Active milestone behavior guide: \(relationship?.milestoneBehaviorSummary ?? IMRelationshipMilestone.guarded.npcBehaviorGuidance)
        Remembered relationship themes: \(relationship?.rememberedTopics.joined(separator: ", ") ?? "none yet")
        Callback cue: \(relationship?.callbackCue ?? "No callback earned yet.")
        Topic unlock guidance: \(relationship?.topicUnlockGuidance ?? setup.scenario.topicUnlockGuidance(for: .guarded))
        Active relationship arc: \(relationship?.activeArcSummary ?? "No active multi-session arc yet.")
        Arc guidance: \(relationship?.activeArcGuidance ?? "Let the relationship feel continuous if a thread has genuinely formed, but do not invent fake history.")
        Latest user signal analysis: \(latestUserSignal?.summary ?? "No user message yet, so open based on scenario, relationship, and context.")
        Conversation phase: \(conversationPhase)
        User turn count: \(userTurnCount)
        Latest user message: \(lastUserMessage)
        Current trust: \(state.normalizedTrust)/10
        Current engagement: \(state.normalizedEngagement)/10
        Current tension: \(state.normalizedTension)/10
        Current beat: \(state.beat)
        Escalation instruction: \(escalationInstruction)
        Real-world context:
        \(context.summaryLines.joined(separator: "\n"))
        Scenario relevance layer:
        \(contextEnvelope.relevantLines.joined(separator: "\n"))
        Opening guidance: \(contextEnvelope.openingGuidance)
        Keep the conversation realistic and brief.
        React to what the user actually said. Do not sound generic.
        Trust should rise from steadiness, specificity, reciprocity, and appropriate warmth, not from empty compliments.
        If the user is charming but vague, keep the relationship only slightly improved at most.
        If the latest user signal shows strong hostility or disengagement, reflect that realistically. Trust should drop, tension should rise, and the NPC may pull back or end the chat.
        You are not a coach inside the chat, but your reactions should naturally train the user toward their communication goal.
        Reward progress toward the communication north star with slightly more openness, warmth, or trust.
        Penalize regressions in the user's biggest challenge in a realistic human way.
        If remembered relationship themes exist, only call one back when it would sound like something this person would genuinely remember and mention.
        If the relationship is fractured or recovering, callbacks should carry caution or unresolved tension instead of false warmth.
        If an active relationship arc exists, let it subtly shape what matters in the exchange and what the NPC notices next.
        If this is the first NPC message, initiate the conversation naturally from the scenario and context instead of waiting for the user.
        Only use small talk if it would make the opening feel more human in this scenario. Never force news or weather if it would sound unnatural.
        For the first NPC message, make an explicit choice:
        - Option A: open with one natural contextual cue plus a human follow-up
        - Option B: skip context entirely and open directly because that is more realistic here
        The opener must not sound like a template, briefing, headline summary, or generic catch-all.
        In social catch-up, a softer opener is usually acceptable if the relationship is warm enough.
        In work update, get to the point quickly unless one brief contextual line sharpens relevance.
        In difficult conversation, do not hide the issue behind small talk.
        In networking, use context only if it creates rapport fast and leads into a specific question.
        If the conversation already feels naturally complete, set shouldWrapUp to true.
        Update the state based on how the user is handling the interaction.

        Conversation so far:
        \(transcript)
        """
    }

    private func apiKey(for provider: AIProvider) -> String? {
        if let keyName = provider.environmentKey,
           let value = ProcessInfo.processInfo.environment[keyName],
           !value.isEmpty {
            return value
        }

        if let keyName = provider.environmentKey,
           let value = LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig") {
            return value
        }

        return nil
    }

    private func extractJSONData(from data: Data, provider: AIProvider) throws -> Data {
        switch provider {
        case .none:
            throw AICoachError.providerDisabled
        case .openAI, .deepSeek:
            let completion = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
            guard let content = completion.choices.first?.message.content,
                  let contentData = normalizedJSONData(from: content) else {
                throw AICoachError.invalidResponse
            }
            return contentData
        case .gemini:
            let completion = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            let content = completion.candidates.first?.content.parts.compactMap(\.text).joined()
            guard let content, let contentData = normalizedJSONData(from: content) else {
                throw AICoachError.invalidResponse
            }
            return contentData
        }
    }

    private func normalizedJSONData(from text: String) -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        let unfenced = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = unfenced.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard
            let start = unfenced.firstIndex(of: "{"),
            let end = unfenced.lastIndex(of: "}"),
            start <= end
        else {
            return nil
        }

        let candidate = String(unfenced[start...end])
        guard let data = candidate.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return nil
        }
        return data
    }

    private func decodeIMConversationReply(from data: Data) throws -> IMConversationReply {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AICoachError.invalidResponse
        }

        let message = (object["message"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !message.isEmpty else {
            throw IMModeServiceError.replyGenerationFailed("Model response did not include a usable message.")
        }

        let shouldWrapUp = boolValue(from: object["shouldWrapUp"]) ?? false
        let stateObject = object["updatedState"] as? [String: Any]
        let starting = IMConversationState.starting
        let updatedState = IMConversationState(
            trust: intValue(from: stateObject?["trust"]) ?? starting.trust,
            engagement: intValue(from: stateObject?["engagement"]) ?? starting.engagement,
            tension: intValue(from: stateObject?["tension"]) ?? starting.tension,
            beat: normalizedBeat(from: stateObject?["beat"]) ?? starting.beat
        )

        return IMConversationReply(
            message: message,
            shouldWrapUp: shouldWrapUp,
            updatedState: updatedState
        )
    }

    private func intValue(from value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double.rounded())
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func boolValue(from value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let string as String:
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "true" { return true }
            if normalized == "false" { return false }
            return nil
        default:
            return nil
        }
    }

    private func normalizedBeat(from value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func backendRequest(path: String) -> URLRequest? {
        guard let baseURL = backendBaseURL() else { return nil }
        let endpoint = baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = backendAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-Noum-API-Key")
        }
        if let accountID = AuthManager.shared.currentAccountID {
            request.setValue(accountID, forHTTPHeaderField: "X-Noum-Account-ID")
        }
        if let provider = AuthManager.shared.currentAuthProviderRawValue {
            request.setValue(provider, forHTTPHeaderField: "X-Noum-Auth-Provider")
        }
        return request
    }

    private func backendBaseURL() -> URL? {
        let rawValue =
            ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ??
            LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return URL(string: rawValue)
    }

    private func backendAPIKey() -> String? {
        ProcessInfo.processInfo.environment["BACKEND_API_KEY"] ??
        LocalConfigLoader.value(forKey: "BACKEND_API_KEY", plistNamed: "BackendConfig")
    }
}

@MainActor
struct IMConversationEvaluationService: IMConversationEvaluatorServicing {
    private let settings = AISettingsManager.shared

    func evaluateConversation(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        finalState: IMConversationState?,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        context: IMSessionContext
    ) async throws -> IMConversationEvaluation {
        // Fallback-first + gated-accept (mirrors PostRepCoachNoteService.generate
        // and AICoachService.generateDeeperFeedback). IM is the
        // highest-fidelity role-play surface and its grade drives the saved
        // score, the relationship state, and the next move — so a finished
        // conversation must NEVER dead-end with a thrown error. The deterministic
        // read is computed up front from the SAME IM analyzers the per-turn reads
        // use (IMUserMessageAnalyzer + IMToneMatcher), and is returned on every
        // gated failure (no provider / no key / no endpoint / non-2xx / decode /
        // ungrounded AI read) and when the locale doesn't support an English LLM
        // grade. The protocol stays `async throws` for type-compat; the body
        // simply stops throwing on the gated paths.
        let fallback = Self.deterministicEvaluation(
            setup: setup,
            turns: turns,
            finalState: finalState,
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            recentSessions: recentSessions,
            relationship: relationship
        )

        // Locale gate — the same one-liner the rest of PracticeSupport.swift
        // uses for English-only AI coaching. A Spanish/French IM rep gets the deterministic grounded
        // read, not an English LLM grade that would be worse than the template.
        guard activeLocaleSupportsAI() else { return fallback }

        guard let provider = settings.activeProvider,
              let apiKey = apiKey(for: provider),
              let endpoint = provider.endpoint else {
            if let backendEvaluation = try? await backendEvaluation(
                setup: setup,
                turns: turns,
                finalState: finalState,
                transcript: transcript,
                fillerCount: fillerCount,
                duration: duration,
                recentSessions: recentSessions,
                profile: profile,
                relationship: relationship,
                context: context
            ), Self.evaluationEngagesTranscript(backendEvaluation, transcript: transcript) {
                return backendEvaluation
            }
            return fallback
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = prompt(
            for: setup,
            turns: turns,
            finalState: finalState,
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            recentSessions: recentSessions,
            profile: profile,
            relationship: relationship,
            context: context
        )

        switch provider {
        case .none:
            return fallback
        case .openAI, .deepSeek:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let body = OpenAICompatibleChatRequest(
                model: provider.model,
                messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: prompt)
                ],
                temperature: 0.2,
                responseFormat: .jsonObject
            )
            request.httpBody = try JSONEncoder().encode(body)
        case .gemini:
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let body = GeminiGenerateContentRequest(
                systemInstruction: .init(parts: [.init(text: systemPrompt)]),
                contents: [.init(parts: [.init(text: prompt)])],
                generationConfig: .init(
                    temperature: 0.2,
                    responseMimeType: "application/json"
                )
            )
            request.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return fallback
            }

            let jsonData = try extractJSONData(from: data, provider: provider)
            let evaluation = try JSONDecoder().decode(IMConversationEvaluation.self, from: jsonData)
            // Grounding gate (mirrors PostRepCoachNoteService.engagesTranscript
            // + AICoachService.engagesTranscript): the headline +
            // insights must actually engage a real turn from the conversation —
            // share a >= 4-char non-stop content word OR a >= 12-char verbatim
            // slice — else it's a generic grade dressed as a coach read and we
            // return the grounded deterministic fallback. Empty transcript ->
            // passes (nothing to quote).
            guard Self.evaluationEngagesTranscript(evaluation, transcript: transcript) else {
                return fallback
            }
            return evaluation
        } catch {
            if let backendEvaluation = try? await backendEvaluation(
                setup: setup,
                turns: turns,
                finalState: finalState,
                transcript: transcript,
                fillerCount: fillerCount,
                duration: duration,
                recentSessions: recentSessions,
                profile: profile,
                relationship: relationship,
                context: context
            ), Self.evaluationEngagesTranscript(backendEvaluation, transcript: transcript) {
                return backendEvaluation
            }
            return fallback
        }
    }

    /// Locale gate — `true` only when the active locale supports an English
    /// coaching read (mirrors `AICoachService.activeLocaleSupportsAI` and
    /// `PostRepCoachNoteService.activeLocaleSupportsAI`). On `false`,
    /// `evaluateConversation` returns the deterministic fallback rather than an
    /// English LLM grade. `IMConversationEvaluationService` is already
    /// `@MainActor`, so this is a plain method, not an actor hop.
    private func activeLocaleSupportsAI() -> Bool {
        LocaleSettingsManager.shared.current.aiSupported
    }

    private func backendEvaluation(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        finalState: IMConversationState?,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        context: IMSessionContext
    ) async throws -> IMConversationEvaluation? {
        guard var request = backendRequest(path: "/v1/im/evaluate") else { return nil }
        let body = BackendIMConversationEvaluationRequest(
            setup: setup,
            turns: turns,
            finalState: finalState,
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            recentSessions: recentSessions,
            profile: profile,
            relationship: relationship,
            context: context
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        return try JSONDecoder().decode(IMConversationEvaluation.self, from: data)
    }

    private var systemPrompt: String {
        """
        You are a sharp, experienced communication coach evaluating an instant-message conversation.
        You think in three layers:

        LAYER 1 — FUNDAMENTALS (universal)
        Clarity, composure, filler-word discipline, vocabulary range.
        These are table stakes. Judge them honestly but don't belabor what's fine.

        LAYER 2 — CONTEXT FIT (conversation-specific)
        Did the user read the room? Did they move the conversation forward?
        Did trust or engagement shift in the right direction?
        Was the tone appropriate for this specific scenario and relationship?
        A technically clear message that ignores the other person's state is still a miss.

        LAYER 3 — IDENTITY LENS (personal style direction)
        The user has a speaking-style goal. This is a direction, not a destination.
        Map their goal to traits (e.g. "speak like a king" → authority, decisiveness, calm).
        Judge whether they moved toward those traits in this conversation — even slightly.
        Never evaluate whether they literally sounded like someone else.

        BASELINE CONTEXT:
        If a speaker baseline is provided, use it to calibrate your evaluation:
        - Compare this session's metrics against their established baseline, not abstract ideals.
        - If they improved relative to their baseline, acknowledge the progress specifically.
        - If they regressed, name the regression honestly but without alarm — one session doesn't define a trend.
        - Reference persistent blockers if provided — these are the patterns they've been stuck on.
        - Reference strengths if provided — these are what they can rely on.
        - If baseline confidence is low ("tentative" or "early"), frame comparisons softly: "early signal" or "initial read."
        - If the session was under elevated or high pressure, weight composure-under-pressure more heavily.
        - If a style goal is provided, note whether this session moved toward it.

        WRITING RULES:
        - Write like a coach who's watched the tape, not like an AI summarizing.
        - Use plain, direct language. No corporate jargon. No "Great job!" unless they genuinely nailed it.
        - headline: a short, honest read. "You held the room" or "You backed off too early" — not a compliment sandwich.
        - feedback: 2-3 sentences max. One thing they did well, one thing to work on. Be specific — reference an actual moment or turn from the conversation. When baseline data is available, ground your feedback in it (e.g. "filler rate dropped below your usual" rather than "good job on fillers").
        - insights: exactly 3 concise strings. Each should be a concrete observation, not a vague principle. At least one insight should reference the baseline or a trend when available.
        - If the conversation was very short (under 3 turns), soften your confidence. Use language like "early read" or "hard to tell from this much" rather than definitive judgments.

        Return JSON only with keys:
        actualTone, toneMatch, clarityScore, composureScore, vocabularyScore, conversationScore, headline, feedback, insights, suggestedDrill.
        All numeric scores are integers from 1 to 10.
        """
    }

    private func prompt(
        for setup: IMConversationSetup,
        turns: [IMConversationTurn],
        finalState: IMConversationState?,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        context: IMSessionContext
    ) -> String {
        let pace = PracticeEvaluator.paceSnapshot(forTranscript: transcript, duration: duration)
        let identity = PracticeEvaluator.speakingIdentity(for: transcript, profile: profile)
        let recentAverageFillers = recentSessions.isEmpty ? 0 : Double(recentSessions.map(\.fillerWordCount).reduce(0, +)) / Double(recentSessions.count)
        let recentAverageDuration = recentSessions.isEmpty ? 0 : recentSessions.map(\.duration).reduce(0, +) / Double(recentSessions.count)
        let transcriptLog = turns.map { turn in
            let speaker = turn.speaker == .user ? "User" : setup.scenario.personaName
            return "\(speaker): \(turn.text)"
        }.joined(separator: "\n")

        let turnCount = turns.filter { $0.speaker == .user }.count
        let isShortSession = turnCount <= 2 || duration < 30

        return """
        --- LAYER 1: FUNDAMENTALS ---
        Filler words: \(fillerCount) (recent avg: \(String(format: "%.1f", recentAverageFillers)))
        Duration: \(Int(duration))s (recent avg: \(Int(recentAverageDuration))s)
        Words per minute: \(pace.wordsPerMinute) (\(pace.label))
        User turns: \(turnCount)
        \(isShortSession ? "⚠️ SHORT SESSION — soften confidence in all judgments." : "")

        --- LAYER 2: CONTEXT FIT ---
        Scenario: \(setup.scenario.title)
        Coaching focus: \(setup.scenario.coachingFocus)
        Target tone: \(setup.targetTone.title) — \(setup.targetTone.coachingPrompt)
        Trust: \(finalState?.normalizedTrust ?? 5)/10
        Engagement: \(finalState?.normalizedEngagement ?? 5)/10
        Tension: \(finalState?.normalizedTension ?? 4)/10
        Beat reached: \(finalState?.beat ?? "Not captured")
        Relationship history: \(relationship?.promptSummary ?? "First conversation.")
        Real-world context:
        \(context.summaryLines.joined(separator: "\n"))

        --- LAYER 3: IDENTITY LENS ---
        Style direction: \(profile?.speakingStyleGoal.title ?? "not set")
        Biggest challenge: \(profile?.biggestChallenge.title ?? "unknown")
        North star: \(profile?.communicationNorthStar ?? "Become a stronger communicator over time.")
        Training focus: \(profile?.inConversationTrainingFocus ?? "Clear, human, well-calibrated communication.")
        Current speaking identity: \(identity.identity)
        Identity evidence: \(identity.evidence)

        \(BaselineEngine.promptContext(baseline: BaselineStore.shared.baseline, pressure: BaselineStore.shared.pressureProfile, currentPressureLevel: BaselineEngine.classifyPressure(mode: .imConversation, isPressureModeOn: PracticeSettingsManager.shared.pressureModeEnabled, streakDays: PracticeSession.calculateStreak(from: recentSessions)), styleGoal: profile?.speakingStyleGoal.title))

        --- FULL CONVERSATION ---
        \(transcriptLog)

        --- USER TRANSCRIPT ONLY ---
        \(transcript)

        EVALUATION FOCUS:
        Layer 2 matters most here. This is a conversation, not a speech.
        - Did the user read the other person and respond to what was actually happening?
        - Did they move the conversation forward or just react?
        - Was any trust gain earned through specificity and responsiveness, or just politeness?
        - Did tension resolve productively or get avoided?
        - For Layer 3: did the user move even slightly toward their style direction? Note it if so.
        """
    }

    private func backendRequest(path: String) -> URLRequest? {
        guard let baseURL = backendBaseURL() else { return nil }
        let endpoint = baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = backendAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-Noum-API-Key")
        }
        if let accountID = AuthManager.shared.currentAccountID {
            request.setValue(accountID, forHTTPHeaderField: "X-Noum-Account-ID")
        }
        if let provider = AuthManager.shared.currentAuthProviderRawValue {
            request.setValue(provider, forHTTPHeaderField: "X-Noum-Auth-Provider")
        }
        return request
    }

    private func backendBaseURL() -> URL? {
        let rawValue =
            ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ??
            LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return URL(string: rawValue)
    }

    private func backendAPIKey() -> String? {
        ProcessInfo.processInfo.environment["BACKEND_API_KEY"] ??
        LocalConfigLoader.value(forKey: "BACKEND_API_KEY", plistNamed: "BackendConfig")
    }

    private func toneMatchScore(for tone: IMTargetTone, transcript: String) -> Int {
        IMToneMatcher.score(for: tone, transcript: transcript)
    }

    private func inferredTone(from transcript: String, paceLabel: String) -> String {
        let lower = transcript.lowercased()
        if lower.contains("thanks") || lower.contains("glad") {
            return "Warm"
        }
        if lower.contains("i need") || lower.contains("let's") {
            return "Assertive"
        }
        if paceLabel == "Fast" {
            return "Slightly rushed"
        }
        return "Clear but measured"
    }

    private func apiKey(for provider: AIProvider) -> String? {
        if let keyName = provider.environmentKey,
           let value = ProcessInfo.processInfo.environment[keyName],
           !value.isEmpty {
            return value
        }

        if let keyName = provider.environmentKey,
           let value = LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig") {
            return value
        }

        return nil
    }

    private func extractJSONData(from data: Data, provider: AIProvider) throws -> Data {
        switch provider {
        case .none:
            throw AICoachError.providerDisabled
        case .openAI, .deepSeek:
            let completion = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
            guard let content = completion.choices.first?.message.content,
                  let contentData = content.data(using: .utf8) else {
                throw AICoachError.invalidResponse
            }
            return contentData
        case .gemini:
            let completion = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            let content = completion.candidates.first?.content.parts.compactMap(\.text).joined()
            guard let content, let contentData = content.data(using: .utf8) else {
                throw AICoachError.invalidResponse
            }
            return contentData
        }
    }

    // MARK: - Deterministic fallback + grounding gate (pure, exposed for tests)

    /// Local content-word stop set for the IM grounding gate. Same established
    /// local-set pattern as `PostRepCoachNoteService.engagementStopWords`,
    /// `AICoachService.engagementStopWords`, and
    /// `PracticeEvaluator.relevanceStopWords` — those are private to their own
    /// types and cannot be reused cross-type. Tokens here don't count as
    /// "engaging the transcript", so a grade that only echoes filler words like
    /// "the"/"with" still falls back.
    private nonisolated static let engagementStopWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "your", "with",
        "this", "that", "they", "them", "from", "have", "what", "when",
        "were", "will", "would", "should", "could", "about", "there",
        "their", "then", "than", "into", "more", "some", "such", "only",
        "very", "just", "most", "over", "also", "been", "being", "which",
        "while", "these", "those", "here", "make", "made", "much", "many",
        "like", "well", "even", "ever", "because", "really"
    ]

    /// Pure deterministic IM conversation grade — the always-on path offline /
    /// non-English / no-provider, and the `fallback` every gated failure returns.
    /// Mirrors `AICoachService.deterministicFeedback` and
    /// `PostRepCoachNoteService.deterministicNote`. Built entirely from the
    /// inputs + the SAME IM analyzers the per-turn reads already use
    /// (`IMToneMatcher.score` for `toneMatch`, `IMUserMessageAnalyzer.analyze`
    /// for warmth/specificity/reciprocity/hostility/disengagement aggregated
    /// across the user's turns) so the fallback grade AGREES with the live tone
    /// and relationship reads — single source of truth. No singletons, so it is
    /// unit-testable, and it quotes a real user turn in the headline rather than
    /// emitting a generic stat-restate.
    ///
    /// Honesty contract:
    /// - Short sessions (<= 2 user turns or < 30s) soften the headline to an
    ///   "early read" rather than a confident verdict, matching the LLM prompt's
    ///   own short-session rule.
    /// - Never invents a quote: the headline quotes the longest substantive user
    ///   turn; with no usable turn it states a grounded scenario read instead.
    /// - The outcome is resolved by the SAME `IMConversationOutcomeResolver` the
    ///   relationship layer uses, so the call site's `outcome?.closingMessage`
    ///   path is preserved end-to-end.
    nonisolated static func deterministicEvaluation(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        finalState: IMConversationState?,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        recentSessions: [PracticeSession],
        relationship: IMRelationshipProfile?
    ) -> IMConversationEvaluation {
        let scenario = setup.scenario
        let tone = setup.targetTone
        let state = finalState ?? IMConversationState.starting

        // --- Aggregate the SAME per-turn signals the live reads use ---
        let userTurns = turns.filter { $0.speaker == .user && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let userTurnCount = userTurns.count
        let isShortSession = userTurnCount <= 2 || duration < 30

        var warmthTotal = 0
        var specificityTotal = 0
        var reciprocityTotal = 0
        var hostilityTotal = 0
        var disengagementTotal = 0
        var runningState = IMConversationState.starting
        for turn in userTurns {
            let signal = IMUserMessageAnalyzer.analyze(
                text: turn.text,
                currentState: runningState,
                scenario: scenario,
                relationship: relationship
            )
            warmthTotal += signal.warmthScore
            specificityTotal += signal.specificityScore
            reciprocityTotal += signal.reciprocityScore
            hostilityTotal += signal.hostilityScore
            disengagementTotal += signal.disengagementScore
            runningState = signal.adjustedState
        }
        let divisor = max(1, userTurnCount)
        let avgWarmth = warmthTotal / divisor
        let avgSpecificity = specificityTotal / divisor
        let avgReciprocity = reciprocityTotal / divisor
        let avgHostility = hostilityTotal / divisor
        let avgDisengagement = disengagementTotal / divisor

        // --- Scores: SAME tone matcher the per-turn read uses, plus state ---
        let toneMatch = IMToneMatcher.score(for: tone, transcript: transcript)

        // Clarity rewards specificity, penalizes filler density. (Pure ints,
        // clamped 1...10 — no fake precision.)
        let fillerPenalty = min(3, fillerCount / max(1, userTurnCount) / 2)
        let clarityScore = Self.clampScore(3 + avgSpecificity - fillerPenalty)
        // Composure tracks the resolved tension + how hostile the user's own
        // turns read (a hostile user is escalating, not composed).
        let composureScore = Self.clampScore(11 - state.normalizedTension - max(0, avgHostility - 2))
        // Vocabulary is a conservative read of specificity + warmth range.
        let vocabularyScore = Self.clampScore(3 + (avgSpecificity + avgWarmth) / 3)
        // Conversation = did trust/engagement land + reciprocity, minus
        // disengagement. This is the heaviest-weighted dimension (Layer 2).
        let conversationScore = Self.clampScore(
            (state.normalizedTrust + state.normalizedEngagement) / 2
            + min(2, avgReciprocity / 3)
            - min(3, avgDisengagement / 3)
        )

        // --- Headline: quote a real user turn (the grounding anchor) ---
        let quotedTurn = Self.longestSubstantiveTurn(in: userTurns)
        let headline = Self.deterministicHeadline(
            quotedTurn: quotedTurn,
            scenario: scenario,
            state: state,
            isShortSession: isShortSession
        )

        // --- Feedback: one earned strength + one grounded next move ---
        let feedback = Self.deterministicFeedbackLine(
            tone: tone,
            avgReciprocity: avgReciprocity,
            avgSpecificity: avgSpecificity,
            state: state,
            isShortSession: isShortSession
        )

        // --- Insights: 3 concrete observations, at least one quoting a turn ---
        let insights = Self.deterministicInsights(
            quotedTurn: quotedTurn,
            tone: tone,
            avgSpecificity: avgSpecificity,
            avgReciprocity: avgReciprocity,
            state: state,
            fillerCount: fillerCount,
            isShortSession: isShortSession
        )

        let suggestedDrill = Self.deterministicDrill(
            tone: tone,
            avgSpecificity: avgSpecificity,
            avgReciprocity: avgReciprocity,
            state: state
        )

        let actualTone = Self.inferredToneStatic(from: transcript)
        let outcome = IMConversationOutcomeResolver.resolve(for: scenario, state: state)

        return IMConversationEvaluation(
            actualTone: actualTone,
            toneMatch: toneMatch,
            clarityScore: clarityScore,
            composureScore: composureScore,
            vocabularyScore: vocabularyScore,
            conversationScore: conversationScore,
            headline: headline,
            feedback: feedback,
            insights: insights,
            suggestedDrill: suggestedDrill,
            outcome: outcome
        )
    }

    private nonisolated static func clampScore(_ value: Int) -> Int {
        max(1, min(10, value))
    }

    /// The longest substantive user turn (>= 4 words), trimmed and capped to a
    /// short span so the quote stays tight. Returns nil when no usable turn
    /// exists — the headline then states a grounded scenario read instead of
    /// fabricating a quote.
    private nonisolated static func longestSubstantiveTurn(in userTurns: [IMConversationTurn]) -> String? {
        let candidates = userTurns
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.split(whereSeparator: \.isWhitespace).count >= 4 }
        guard let longest = candidates.max(by: { $0.count < $1.count }) else { return nil }
        let words = longest.split(whereSeparator: \.isWhitespace).prefix(14)
        let span = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard span.count >= 10 else { return nil }
        return span
    }

    private nonisolated static func deterministicHeadline(
        quotedTurn: String?,
        scenario: IMConversationScenario,
        state: IMConversationState,
        isShortSession: Bool
    ) -> String {
        let landed = state.normalizedTrust >= 6 && state.normalizedTension <= 5
        if let quotedTurn {
            let quoted = "'\(quotedTurn.trimmingCharacters(in: CharacterSet(charactersIn: ".'\"")))'"
            if isShortSession {
                return "Early read on a short exchange — \(quoted) set the tone, but there wasn't much to go on yet."
            }
            if landed {
                return "You held the thread with \(quotedTurn.isEmpty ? "the chat" : quoted) and kept \(scenario.personaName) engaged."
            }
            return "You opened with \(quoted), but the conversation stayed tighter than it needed to."
        }
        if isShortSession {
            return "Early read — the exchange ended before there was much to judge."
        }
        if landed {
            return "You kept \(scenario.personaName) engaged and the conversation moving."
        }
        return "The conversation with \(scenario.personaName) stayed guarded — there's room to open it up."
    }

    private nonisolated static func deterministicFeedbackLine(
        tone: IMTargetTone,
        avgReciprocity: Int,
        avgSpecificity: Int,
        state: IMConversationState,
        isShortSession: Bool
    ) -> String {
        let softener = isShortSession ? "From this much it's an early read, but " : ""
        if avgReciprocity >= 4 {
            return "\(softener)you brought the other person into it — asking back and responding to what they said is what kept this from going flat. To push further, aim to \(tone.coachingPrompt)."
        }
        if avgSpecificity <= 2 {
            return "\(softener)your replies stayed short and general. Adding one concrete detail per message gives the other person something real to respond to, and it's what would help you \(tone.coachingPrompt)."
        }
        if state.normalizedTension >= 7 {
            return "\(softener)the tension climbed and didn't fully resolve. Naming the awkwardness directly, then steering back, keeps you composed — that's the core of being able to \(tone.coachingPrompt)."
        }
        return "\(softener)you kept the conversation steady. The next lever is to \(tone.coachingPrompt) — that's the edge between holding a chat and leading one."
    }

    private nonisolated static func deterministicInsights(
        quotedTurn: String?,
        tone: IMTargetTone,
        avgSpecificity: Int,
        avgReciprocity: Int,
        state: IMConversationState,
        fillerCount: Int,
        isShortSession: Bool
    ) -> [String] {
        var insights: [String] = []
        if let quotedTurn {
            insights.append("Your line '\(quotedTurn.trimmingCharacters(in: CharacterSet(charactersIn: ".'\"")))' carried the most weight — it's where the conversation turned.")
        } else if isShortSession {
            insights.append("The exchange was short, so treat this as an early signal rather than a verdict.")
        } else {
            insights.append("Your replies stayed brief — there wasn't a standout line for the other person to grab onto.")
        }

        if avgReciprocity >= 4 {
            insights.append("You drew the other person in rather than just reacting — that reciprocity is what built engagement.")
        } else {
            insights.append("Most replies answered without inviting more back. One genuine question would have kept the thread alive.")
        }

        if avgSpecificity <= 2 {
            insights.append("Specificity ran low. A concrete detail per message is the fastest way to sound clear and \(tone.title.lowercased()).")
        } else if fillerCount >= 4 {
            insights.append("Fillers crept in across the chat — trimming them sharpens the \(tone.title.lowercased()) read you're going for.")
        } else if state.normalizedTrust >= 6 {
            insights.append("Trust landed above the midpoint — the other person was reading you as someone worth staying in it with.")
        } else {
            insights.append("Trust stayed guarded — leading with intent earlier would move it in the right direction.")
        }

        return Array(insights.prefix(3))
    }

    private nonisolated static func deterministicDrill(
        tone: IMTargetTone,
        avgSpecificity: Int,
        avgReciprocity: Int,
        state: IMConversationState
    ) -> String {
        if avgReciprocity < 4 {
            return "Reciprocity drill: end each reply with one genuine question that moves the conversation, not just acknowledges it."
        }
        if avgSpecificity <= 2 {
            return "Specificity drill: rewrite three short replies to each carry one concrete detail."
        }
        if state.normalizedTension >= 7 {
            return "Composure drill: name the tension in one line, then steer back to the point without softening it away."
        }
        return "Tone drill: take one reply and rewrite it to \(tone.coachingPrompt)."
    }

    /// Deterministic `actualTone` read used by the fallback — mirrors the
    /// instance `inferredTone(from:paceLabel:)` lexical rules without the
    /// pace dependency (the fallback states tone from word choice only, never a
    /// fabricated pace claim).
    private nonisolated static func inferredToneStatic(from transcript: String) -> String {
        let lower = transcript.lowercased()
        if lower.contains("thanks") || lower.contains("glad") || lower.contains("appreciate") {
            return "Warm"
        }
        if lower.contains("i need") || lower.contains("let's") || lower.contains("i want") {
            return "Assertive"
        }
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Measured"
        }
        return "Clear but measured"
    }

    /// Grounding gate for the AI/backend grade (mirrors
    /// `PostRepCoachNoteService.engagesTranscript` and
    /// `AICoachService.engagesTranscript`). True when the grade genuinely
    /// engages a real turn from the conversation: the headline OR any insight
    /// shares a >= 4-char non-stop content word with the transcript, OR contains
    /// a >= 12-char verbatim slice of it (case-insensitive). Empty transcript ->
    /// true (nothing to quote; never blocks). On `false`, `evaluateConversation`
    /// substitutes the grounded deterministic fallback.
    nonisolated static func evaluationEngagesTranscript(_ evaluation: IMConversationEvaluation, transcript: String) -> Bool {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return true }

        let lowerTranscript = trimmedTranscript.lowercased()
        // The headline + insights are the qualitative read that must be grounded.
        let candidate = ([evaluation.headline] + evaluation.insights)
            .joined(separator: " ")
            .lowercased()

        // 1) Shared content word.
        let transcriptWords = Set(
            lowerTranscript
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 && !engagementStopWords.contains($0) }
        )
        let candidateWords = candidate
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !engagementStopWords.contains($0) }
        if candidateWords.contains(where: { transcriptWords.contains($0) }) {
            return true
        }

        // 2) >= 12-char verbatim slice of the transcript appears in the read.
        let window = 12
        let chars = Array(lowerTranscript)
        if chars.count >= window {
            for start in 0...(chars.count - window) {
                let slice = String(chars[start..<(start + window)])
                if candidate.contains(slice) {
                    return true
                }
            }
        }
        return false
    }
}

@MainActor
struct AICoachService: AICoachServicing {
    static let minimumTranscriptWordCount = 10

    private let settings = AISettingsManager.shared

    func generateDeeperFeedback(
        input: AICoachSessionInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) async throws -> AICoachFeedback {
        // Fallback-first (mirrors PostRepCoachNoteService.generate). The
        // deterministic read is computed up front and returned on EVERY gated
        // failure instead of throwing — so a non-English rep, an offline rep,
        // a missing key, a malformed response, or an ungrounded AI read all
        // yield a real grounded Coach Read rather than the raw error text the
        // old throw-path surfaced at SummaryView ("Coach Read failed: …").
        // The protocol stays `async throws` for type-compat; this body simply
        // stops throwing on the gated paths.
        settings.resetIfNeeded()
        let fallback = Self.deterministicFeedback(input: input)

        // Locale gate — the one-liner the whole of PracticeSupport.swift was
        // missing (verified 0 prior occurrences). A Spanish/French rep gets the
        // deterministic grounded read, never English LLM coaching.
        guard activeLocaleSupportsAI() else { return fallback }

        // Defense-in-depth: SummaryView already pre-checks short transcripts,
        // but a thin transcript here returns the deterministic read rather
        // than throwing .transcriptTooShort.
        guard input.transcript.split(whereSeparator: \.isWhitespace).count >= Self.minimumTranscriptWordCount else {
            return fallback
        }
        guard let provider = settings.activeProvider,
              let apiKey = apiKey(for: provider),
              let endpoint = provider.endpoint else {
            return fallback
        }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let prompt = prompt(for: input, profile: profile, plan: plan)
            let system = Self.systemPrompt(persona: CoachPersona.persona(for: input.voice))
            switch provider {
            case .none:
                return fallback
            case .openAI, .deepSeek:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                let body = OpenAICompatibleChatRequest(
                    model: provider.model,
                    messages: [
                        .init(role: "system", content: system),
                        .init(role: "user", content: prompt)
                    ],
                    temperature: 0.3,
                    responseFormat: .jsonObject
                )
                request.httpBody = try JSONEncoder().encode(body)
            case .gemini:
                request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                let body = GeminiGenerateContentRequest(
                    systemInstruction: .init(parts: [.init(text: system)]),
                    contents: [.init(parts: [.init(text: prompt)])],
                    generationConfig: .init(
                        temperature: 0.3,
                        responseMimeType: "application/json"
                    )
                )
                request.httpBody = try JSONEncoder().encode(body)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return fallback
            }

            let jsonData: Data
            switch provider {
            case .none:
                return fallback
            case .openAI, .deepSeek:
                let completion = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
                guard let content = completion.choices.first?.message.content,
                      let contentData = content.data(using: .utf8) else {
                    return fallback
                }
                jsonData = contentData
            case .gemini:
                let completion = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
                let content = completion.candidates
                    .first?
                    .content
                    .parts
                    .compactMap(\.text)
                    .joined()
                guard let content, let contentData = content.data(using: .utf8) else {
                    return fallback
                }
                jsonData = contentData
            }

            guard let feedback = try? JSONDecoder().decode(AICoachFeedback.self, from: jsonData) else {
                return fallback
            }
            // Brand-voice contract: no exclamation, no chirpy filler, bounded
            // length. A policy-violating read falls back rather than rendering.
            guard Self.passesBrandVoiceContract(feedback) else { return fallback }
            // Transcript-grounding gate (mirrors PostRepCoachNoteService
            // .engagesTranscript + GrammarFeedbackService's excerpt
            // check): keyImprovement OR revisedOpening must actually engage
            // the rep's words, else it's a generic read dressed as a coach
            // note and we return the deterministic fallback. Empty transcript
            // -> passes (nothing to quote).
            guard Self.engagesTranscript(feedback, transcript: input.transcript) else {
                return fallback
            }
            await MainActor.run {
                settings.recordAnalysis()
            }
            return feedback
        } catch {
            return fallback
        }
    }

    /// Pure system-prompt builder over `persona` only (mirrors the
    /// `nonisolated static` `userPrompt` seam). Made static + unit-testable so
    /// the STANDING CASE rubric line and the honesty rules are verified without
    /// a live model — single source of truth, no duplicated prompt string.
    nonisolated static func systemPrompt(persona: CoachPersona) -> String {
        """
        You are a senior £130/hr speaking coach writing a structured read of one \
        practice rep for your client. Voice register: \(persona.signatureTone)

        What makes a good read (priority order):
        1. SUBSTANCE FIRST. If a QUESTION ASKED is given, your read must judge \
        whether the rep actually answered THAT question and where the main \
        point landed — lead (in the first sentence) or buried (arrived late). \
        Ground this in their words, never a generic relevance claim.
        2. QUOTE A SPECIFIC PHRASE from their transcript — an opener, a claim, \
        a structural choice. Quote it in their words. A read that never quotes \
        is a dashboard, not a coach.
        3. SUPPORT vs ASSERTION. Note whether claims were backed by an example \
        or specifics, or stated bare — when the transcript shows it.
        4. Connect to prior reps only when genuinely true (continuity), e.g. \
        "second time the lede arrived late." Never invent past behavior.
        5. STANDING CASE. If a STANDING CASE is given, weigh this rep against \
        that standing target/measure/review cadence (the user's ongoing goal), \
        not just this rep in isolation — but it is durable context, NOT this-rep evidence: \
        treat it as the hypothesis you are testing, and never assert the \
        standing target was hit this rep unless the transcript shows it.
        6. Stats (score, filler count, pace) are CONTEXT, not the read.

        Honesty rules (hard):
        - Patterns are HYPOTHESES, not diagnoses. Association, never causation.
        - Make no claim the input does not support. If you lack data, say so — \
        never invent a number, a quote, or a history.
        - Never punish-shame. If something dropped, name it factually and \
        anchor one small next move.
        - No exclamation marks. No chirpy filler ("Awesome", "Great job", \
        "Let's"). No emoji.

        Output STRICT JSON, nothing else:
        {"strengths": ["…","…"], "keyImprovement": "…", "suggestedDrill": "…", \
        "revisedOpening": "…"}
        - strengths: exactly 2 concise items, at least one tied to a quoted \
        moment.
        - keyImprovement: one short paragraph; if a QUESTION ASKED is given it \
        must address answer/where-the-point-landed, grounded in their words.
        - suggestedDrill: one sentence.
        - revisedOpening: 1-2 sentences modelling a stronger opening that \
        PRESERVES the speaker's intent and moves it toward their voice — show, \
        don't tell.
        """
    }

    private func prompt(
        for input: AICoachSessionInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) -> String {
        let baselineStore = BaselineStore.shared
        let pressureLevel = BaselineEngine.classifyPressure(
            mode: input.mode,
            isPressureModeOn: PracticeSettingsManager.shared.pressureModeEnabled,
            streakDays: PracticeSession.calculateStreak(from: PracticeSessionStore.shared.sessions)
        )
        let baselineContext = BaselineEngine.promptContext(
            baseline: baselineStore.baseline,
            pressure: baselineStore.pressureProfile,
            currentPressureLevel: pressureLevel,
            styleGoal: profile?.speakingStyleGoal.title
        )
        return Self.userPrompt(
            input: input,
            profile: profile,
            plan: plan,
            baselineContext: baselineContext
        )
    }

    /// Pure user-prompt builder (mirrors `PostRepCoachNoteService.userPrompt`).
    /// `nonisolated static` so the omit-when-empty / surface-when-
    /// present contract for THE QUESTION ASKED, the register line, the baseline
    /// deltas, and the RECENT REPS block is unit-tested without singletons.
    /// The singleton-dependent `baselineContext` is computed by the caller and
    /// injected, so this stays pure over its arguments.
    nonisolated static func userPrompt(
        input: AICoachSessionInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?,
        baselineContext: String
    ) -> String {
        var lines: [String] = []
        // Voice + per-voice register line — same register mapping the post-rep
        // note and the session debrief use, so the Coach Read sounds like the
        // same coach. Omitted entirely when no voice is set (cold start).
        if let voice = input.voice {
            lines.append("User's voice goal: \(voice.title) (\(voice.coachingDescription))")
            lines.append(AIInsightsService.registerClause(for: voice))
        }
        lines.append("Mode: \(input.mode.displayLabel)")
        lines.append("Score: \(input.score.map(String.init) ?? "n/a")/10            Filler words: \(input.fillerCount)")
        lines.append("Duration: \(Int(input.duration))s   Words per minute: \(input.wordsPerMinute)")
        lines.append("Current speaking identity: \(input.speakingIdentity)")
        lines.append("Speaker context: \(profile?.speakingContext.title ?? "unknown")")
        lines.append("Speaker priority: \(profile?.primaryGoal.title ?? "unknown")")
        lines.append("Speaker challenge: \(profile?.biggestChallenge.title ?? "unknown")")
        lines.append("Desired outcome: \(profile?.desiredOutcome.title ?? "unknown")")
        lines.append("Target speaking style: \(profile?.speakingStyleGoal.title ?? "unknown")")
        lines.append("Personal goal reference: \(profile?.personalGoalReference ?? "none")")
        lines.append("Coaching brief: \(profile?.coachingBrief ?? "none")")
        lines.append("Current focus suggestion: \(plan?.currentFocus ?? "none")")
        lines.append("Suggested drill: \(plan?.suggestedDrill ?? "none")")
        // Confidence-gated baselines — omitted when nil (never a fake number).
        if let baselineFiller = input.baselineFillerRate {
            lines.append(String(format: "Baseline filler rate: %.1f per minute", baselineFiller))
        }
        if let baselinePace = input.baselinePaceWPM {
            lines.append(String(format: "Baseline pace: %.0f WPM", baselinePace))
        }

        let trimmedContext = baselineContext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContext.isEmpty {
            lines.append("")
            lines.append(trimmedContext)
        }

        // STANDING CASE — the user's durable working hypothesis + active
        // intervention target/measure/review cadence (SUBSTANCE-4). Durable
        // context the coach is carrying, NOT this-rep evidence: the rubric
        // weighs the rep against this standing target but never asserts it was
        // hit without transcript support. Each component is omitted when its
        // source field is nil; the whole block is omitted when all four are
        // absent (no placeholder).
        var standingCaseLines: [String] = []
        if let hypothesis = input.standingHypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hypothesis.isEmpty {
            standingCaseLines.append("Working hypothesis: \(hypothesis)")
        }
        if let target = input.standingObservableTarget?.trimmingCharacters(in: .whitespacesAndNewlines),
           !target.isEmpty {
            standingCaseLines.append("Observable target: \(target)")
        }
        if let measure = input.standingSuccessMeasure?.trimmingCharacters(in: .whitespacesAndNewlines),
           !measure.isEmpty {
            standingCaseLines.append("Success measure: \(measure)")
        }
        if let due = input.standingReviewDueAt {
            standingCaseLines.append("Review cadence: revisit by \(CoachContextBuilder.caseReviewLabel(for: due))")
        }
        if !standingCaseLines.isEmpty {
            lines.append("")
            lines.append("STANDING CASE (the user's current goal/target — reason over this, not just this rep):")
            lines.append(contentsOf: standingCaseLines)
        }

        // THE QUESTION ASKED — the field that makes "did you answer it"
        // possible. Omitted entirely when unknown (no placeholder injected).
        let trimmedPrompt = input.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty {
            lines.append("")
            lines.append("THE QUESTION ASKED: \(trimmedPrompt)")
        }

        lines.append("")
        lines.append("THIS REP — TRANSCRIPT (quote a specific phrase, and say whether it answered THE QUESTION ASKED and where the main point landed):")
        lines.append(input.transcript)

        // Continuity — drop-in summaries of prior reps. Omitted when empty;
        // the prompt forbids inventing past behavior.
        if !input.recentSessionSummaries.isEmpty {
            lines.append("")
            lines.append("RECENT REPS (continuity, never invent):")
            for summary in input.recentSessionSummaries.prefix(3) {
                lines.append("- \(summary)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func apiKey(for provider: AIProvider) -> String? {
        if let keyName = provider.environmentKey,
           let value = ProcessInfo.processInfo.environment[keyName],
           !value.isEmpty {
            return value
        }
        if let keyName = provider.environmentKey,
           let value = LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig") {
            return value
        }
        return nil
    }

    /// Locale gate — `true` only when the active locale supports an English
    /// coaching read (mirrors `PostRepCoachNoteService.activeLocaleSupportsAI`).
    /// On `false`, `generateDeeperFeedback` returns the deterministic
    /// fallback instead of English LLM coaching. `AICoachService` is already
    /// `@MainActor`, so this is a plain method, not an actor hop.
    private func activeLocaleSupportsAI() -> Bool {
        LocaleSettingsManager.shared.current.aiSupported
    }

    // MARK: - Deterministic fallback (pure, exposed for tests)

    /// Local content-word stop set for the transcript-grounding gate. Same
    /// established local-set pattern as `PostRepCoachNoteService
    /// .engagementStopWords` and `PracticeEvaluator.relevanceStopWords`
    /// — those are private to their own types and cannot be reused cross-type.
    /// Tokens here don't count as "engaging the transcript", so feedback that
    /// only shares filler words like "the"/"with" still falls back.
    private nonisolated static let engagementStopWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "your", "with",
        "this", "that", "they", "them", "from", "have", "what", "when",
        "were", "will", "would", "should", "could", "about", "there",
        "their", "then", "than", "into", "more", "some", "such", "only",
        "very", "just", "most", "over", "also", "been", "being", "which",
        "while", "these", "those", "here", "make", "made", "much", "many",
        "like", "well", "even", "ever", "because", "really"
    ]

    /// Pure deterministic Coach Read — the always-on path offline / non-English
    /// / no-provider, and the `fallback` every gated failure returns. Mirrors
    /// `PostRepCoachNoteService.deterministicNote`. Built entirely from
    /// the input + `CoachPersona` (no singletons), so it is unit-testable and
    /// genuinely coach-grade rather than a stat-restate: it quotes the opener
    /// when one exists and states the SHARED answered/buried verdict
    /// (`PracticeEvaluator.promptAnswerVerdict`) so every surface agrees.
    ///
    /// Honesty contract:
    /// - The substance verdict is asserted ONLY above its evidence floor
    ///   (`promptAnswerVerdict` returns nil on thin prompt/transcript); below
    ///   the floor the read states delivery facts only — no fake certainty.
    /// - Baseline comparisons fire only when the confidence-gated baseline is
    ///   present (`baselineFillerRate`/`PaceWPM` non-nil).
    /// - Never invents a quote: `openerAnchor` returns nil on a too-short
    ///   transcript, and `revisedOpening` is then "" (the render path already
    ///   handles empty `revisedOpening`).
    /// - Every field passes `passesBrandVoiceContract` by construction.
    nonisolated static func deterministicFeedback(input: AICoachSessionInput) -> AICoachFeedback {
        let persona = CoachPersona.persona(for: input.voice)
        let opener = openerAnchor(in: input.transcript)

        // --- strengths[0]: quoted opener when present, else clean-delivery ---
        let firstStrength: String
        if let opener {
            firstStrength = openerStrength(opener: opener, persona: persona)
        } else if input.fillerCount == 0 {
            firstStrength = "You kept the delivery clean — no filler words to cut."
        } else if let score = input.score, score >= 7 {
            firstStrength = "A solid rep — the read held together start to finish."
        } else {
            firstStrength = "You got the rep in and kept going under the clock."
        }

        // --- strengths[1]: a delivery strength vs baseline (never invented) ---
        let secondStrength = deliveryStrength(input: input)

        // --- keyImprovement: the SHARED substance verdict above the floor ---
        let read = PracticeEvaluator.promptRelevance(
            prompt: input.prompt.isEmpty ? nil : input.prompt,
            transcript: input.transcript
        )
        let verdict = PracticeEvaluator.promptAnswerVerdict(for: read)
        let keyImprovement: String
        switch verdict {
        case .answered:
            // The point led — `firstSentenceOverlap` cleared the strong bar.
            keyImprovement = "You engaged the question directly and led with the point — the answer was right up front. Tighten the close so the last line lands as cleanly as the open."
        case .partial:
            // The point neither clearly led nor was clearly present-but-late.
            // True for both the loose-engagement and barely-engaged cases — no
            // "arrived late" claim (that is `.buried`'s alone) and no claim of
            // contact the rep may not have made.
            keyImprovement = "The question's key terms didn't clearly lead your answer. Make your main point the first sentence, then spend the rest supporting it."
        case .buried:
            // The point was present across the rep but absent from the lead —
            // the positional claim is TRUE here, not asserted.
            keyImprovement = "The answer was in there, but it arrived late. Lead with your point in the first sentence next time, then build the case behind it."
        case .none:
            // Below the evidence floor — NO substance claim. Delivery only.
            keyImprovement = deliveryImprovement(input: input)
        }

        // --- suggestedDrill: per-verdict / per-voice deterministic line ---
        let suggestedDrill = drillLine(verdict: verdict, persona: persona)

        // --- revisedOpening: lead-with-the-point rewrite anchored to the
        // opener, or "" when there's nothing to anchor (no fabrication). ---
        let revisedOpening: String
        if let opener {
            revisedOpening = revisedOpeningLine(opener: opener, persona: persona)
        } else {
            revisedOpening = ""
        }

        return AICoachFeedback(
            strengths: [firstStrength, secondStrength],
            keyImprovement: keyImprovement,
            suggestedDrill: suggestedDrill,
            revisedOpening: revisedOpening
        )
    }

    /// The first sentence-like span of the transcript, trimmed, when it is
    /// long enough to quote (>= 10 chars, the `openerAnchoredSentence` floor).
    /// Returns nil otherwise so the fallback never fabricates a quote.
    private nonisolated static func openerAnchor(in transcript: String) -> String? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // First sentence: split on . ! ? — fall back to a leading word window.
        let firstSentence = trimmed
            .split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        // Cap to a short opener span (first ~10 words) so the quote stays tight.
        let words = firstSentence.split(whereSeparator: \.isWhitespace).prefix(10)
        let opener = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard opener.count >= 10 else { return nil }
        return opener
    }

    /// Per-voice quoted-opener strength (mirrors
    /// `PostRepCoachNoteService.openerAnchoredSentence`).
    private nonisolated static func openerStrength(opener: String, persona: CoachPersona) -> String {
        let quoted = "'\(opener.trimmingCharacters(in: CharacterSet(charactersIn: ".'\"")))'"
        switch persona.voice {
        case .authoritative: return "Your opener — \(quoted) — set the frame cleanly."
        case .warm:          return "You opened with \(quoted) — it set the right tone."
        case .concise:       return "Opener: \(quoted). It landed."
        case .persuasive:    return "The opener — \(quoted) — set the premise well."
        case .executive:     return "Opening with \(quoted) — effective framing."
        case .storytelling:  return "You opened with \(quoted) — the first line drew the listener in."
        case .none:          return "Your opener — \(quoted) — set the frame."
        }
    }

    /// A delivery strength grounded in the metrics vs the confidence-gated
    /// baseline — never invented. Priority: fillers at/below baseline, then a
    /// pace in the shared conversational band, then a clean zero-filler rep,
    /// then a steady fallback that asserts nothing it cannot support.
    private nonisolated static func deliveryStrength(input: AICoachSessionInput) -> String {
        if let baselineFiller = input.baselineFillerRate, baselineFiller > 0 {
            let minutes = max(input.duration / 60.0, 0.0001)
            let sessionRate = Double(input.fillerCount) / minutes
            if sessionRate <= baselineFiller {
                return "Your filler rate sat at or below your usual — the discipline is holding."
            }
        }
        if ConversationalPaceBand.contains(input.wordsPerMinute) {
            return "Your pace stayed in a listenable band — easy to follow, no rush."
        }
        if input.fillerCount == 0 {
            return "Not a single filler word — the delivery stayed clean throughout."
        }
        return "You held a steady delivery and saw the rep through."
    }

    /// Delivery-only improvement used when the substance verdict is below its
    /// evidence floor (no prompt / thin transcript) — states a pace or filler
    /// fact, never a substance claim. No fake certainty.
    private nonisolated static func deliveryImprovement(input: AICoachSessionInput) -> String {
        if input.wordsPerMinute > 170 {
            return "Your pace ran fast at \(input.wordsPerMinute) WPM. Add a beat between points so each one has room to land."
        }
        if input.wordsPerMinute > 0 && input.wordsPerMinute < 95 {
            return "Your pace ran slow at \(input.wordsPerMinute) WPM. Lift the energy a touch so the line carries."
        }
        if input.fillerCount >= 4 {
            return "Fillers crept in this rep. Try a deliberate pause where a filler wants to go — silence reads as composure."
        }
        return "Pick one concrete idea and make it the spine of the next rep, then cut anything that doesn't serve it."
    }

    /// Per-verdict / per-voice deterministic drill line.
    private nonisolated static func drillLine(verdict: PracticeEvaluator.PromptAnswerVerdict?, persona: CoachPersona) -> String {
        switch verdict {
        case .buried, .partial:
            return "BLUF drill: state your answer in one sentence first, then give two sentences of support."
        case .answered:
            return "Close-strong drill: end on a single declarative sentence that restates the point."
        case .none:
            switch persona.voice {
            case .concise:
                return "One-breath drill: deliver the core idea in a single breath, then stop."
            case .storytelling:
                return "Arc drill: open on a concrete moment, then connect it to the point."
            default:
                return "Pause drill: insert one deliberate beat between your two strongest points."
            }
        }
    }

    /// A deterministic lead-with-the-point rewrite anchored to the opener.
    private nonisolated static func revisedOpeningLine(opener: String, persona: CoachPersona) -> String {
        let trimmedOpener = opener.trimmingCharacters(in: CharacterSet(charactersIn: ".'\""))
        switch persona.voice {
        case .executive, .authoritative:
            return "Lead with the verdict, then support it: open on your conclusion in one line before the context you started with ('\(trimmedOpener)')."
        case .persuasive:
            return "Open with your claim, then the evidence: state the recommendation first, then earn it — rather than building up to it from '\(trimmedOpener)'."
        case .concise:
            return "Cut to it: make your first sentence the point itself, not the run-up ('\(trimmedOpener)')."
        default:
            return "Try opening on the point itself — say what you concluded first, then walk back to '\(trimmedOpener)' as support."
        }
    }

    // MARK: - Brand-voice contract + grounding gate (pure, exposed for tests)

    /// True when every emitted text field honors the brand-voice contract:
    /// no exclamation marks, no chirpy filler ("Awesome"/"Great job"/"Let's"),
    /// bounded length. Mirrors `PostRepCoachNoteService.passesBrandVoiceContract`
    /// applied across all four `AICoachFeedback` fields.
    nonisolated static func passesBrandVoiceContract(_ feedback: AICoachFeedback) -> Bool {
        let fields = feedback.strengths + [feedback.keyImprovement, feedback.suggestedDrill]
        for field in fields {
            if !fieldPassesBrandVoice(field, allowEmpty: false) { return false }
        }
        // revisedOpening may legitimately be empty (the render path handles it).
        if !fieldPassesBrandVoice(feedback.revisedOpening, allowEmpty: true) { return false }
        return true
    }

    private nonisolated static func fieldPassesBrandVoice(_ text: String, allowEmpty: Bool) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return allowEmpty }
        let lower = trimmed.lowercased()
        if trimmed.contains("!") { return false }
        if lower.contains("let's") || lower.contains("lets ") { return false }
        if lower.contains("awesome") { return false }
        if lower.contains("great job") { return false }
        if trimmed.count > 320 { return false }
        return true
    }

    /// Transcript-grounding gate (mirrors `PostRepCoachNoteService
    /// .engagesTranscript`). True when the AI feedback genuinely engages
    /// the rep's transcript: `keyImprovement` OR `revisedOpening` shares a
    /// >= 4-char non-stop content word with the transcript, OR contains a
    /// >= 12-char verbatim slice of it (case-insensitive). Empty transcript ->
    /// true (nothing to quote; never blocks).
    nonisolated static func engagesTranscript(_ feedback: AICoachFeedback, transcript: String) -> Bool {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return true }

        let lowerTranscript = trimmedTranscript.lowercased()
        // The two SUBSTANCE fields are what must be grounded.
        let candidate = "\(feedback.keyImprovement) \(feedback.revisedOpening)".lowercased()

        // 1) Shared content word.
        let transcriptWords = Set(
            lowerTranscript
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 && !engagementStopWords.contains($0) }
        )
        let candidateWords = candidate
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !engagementStopWords.contains($0) }
        if candidateWords.contains(where: { transcriptWords.contains($0) }) {
            return true
        }

        // 2) >= 12-char verbatim slice of the transcript appears in the field.
        let window = 12
        let chars = Array(lowerTranscript)
        if chars.count >= window {
            for start in 0...(chars.count - window) {
                let slice = String(chars[start..<(start + window)])
                if candidate.contains(slice) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Continuity (pure, exposed for tests)

    /// Build the continuity summaries the Coach Read feeds into
    /// `recentSessionSummaries`: drop the current rep, take the next 3 prior
    /// reps, map each to the same "Mode | score X/10 | N fillers" shape the
    /// session debrief renders (`AIInsightsService.userPrompt`). Pure over
    /// the inputs so the exclude-current-rep + bound-to-3 contract is tested
    /// without the View. Never invents — only describes real stored sessions.
    nonisolated static func recentSessionSummaries(
        sessions: [PracticeSession],
        currentRepID: UUID?
    ) -> [String] {
        sessions
            .filter { currentRepID == nil || $0.id != currentRepID }
            .prefix(3)
            .map { rep in
                let scoreText = rep.score.map { "\($0)/10" } ?? "n/a"
                return "\(rep.mode.displayLabel) | score \(scoreText) | \(rep.fillerWordCount) filler\(rep.fillerWordCount == 1 ? "" : "s")"
            }
    }
}

@MainActor
struct AIHomeRecommendationService: AIHomeRecommendationServicing {
    static let minimumSessionCount = 2

    private let settings = AISettingsManager.shared

    func generateHomeRecommendation(
        input: AIHomeRecommendationInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) async throws -> AIHomeRecommendation {
        settings.resetIfNeeded()
        guard let provider = settings.activeProvider else { throw AICoachError.missingAPIKey }
        guard settings.canRequestAnalysis else { throw AICoachError.providerDisabled }
        guard let apiKey = apiKey(for: provider) else { throw AICoachError.missingAPIKey }
        guard let endpoint = provider.endpoint else { throw AICoachError.providerDisabled }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = prompt(for: input, profile: profile, plan: plan)
        switch provider {
        case .none:
            throw AICoachError.providerDisabled
        case .openAI, .deepSeek:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let body = OpenAICompatibleChatRequest(
                model: provider.model,
                messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: prompt)
                ],
                temperature: 0.2,
                responseFormat: .jsonObject
            )
            request.httpBody = try JSONEncoder().encode(body)
        case .gemini:
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let body = GeminiGenerateContentRequest(
                systemInstruction: .init(parts: [.init(text: systemPrompt)]),
                contents: [.init(parts: [.init(text: prompt)])],
                generationConfig: .init(
                    temperature: 0.2,
                    responseMimeType: "application/json"
                )
            )
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AICoachError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw apiError(from: data, provider: provider)
        }

        let jsonData: Data
        switch provider {
        case .none:
            throw AICoachError.providerDisabled
        case .openAI, .deepSeek:
            let completion = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
            guard let content = completion.choices.first?.message.content,
                  let contentData = content.data(using: .utf8) else {
                throw AICoachError.invalidResponse
            }
            jsonData = contentData
        case .gemini:
            let completion = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
            let content = completion.candidates
                .first?
                .content
                .parts
                .compactMap(\.text)
                .joined()
            guard let content, let contentData = content.data(using: .utf8) else {
                throw AICoachError.invalidResponse
            }
            jsonData = contentData
        }

        let recommendation = try JSONDecoder().decode(AIHomeRecommendation.self, from: jsonData)
        guard let normalizedRecommendation = AIHomeRecommendationContract.normalized(
            recommendation,
            input: input
        ) else {
            throw AICoachError.invalidResponse
        }
        settings.recordAnalysis()
        return normalizedRecommendation
    }

    private var systemPrompt: String {
        """
        You are the intelligence behind a premium communication coaching app.
        Recommend the single best next speaking drill for the user based on recent performance.
        Be specific, coach-like, and adaptive. Do not sound generic.
        The rule-based preferred mode, tone, and scenario fields in the user prompt are binding. Do not choose a different mode.
        If the preferred mode is imConversation and a preferred tone/scenario are supplied, return those exact enum identifiers.
        Return JSON only with keys: title, detail, focus, target, recommendedMode, recommendedTone, recommendedScenario, modeBenefit, whyMode, whyNow.
        recommendedMode must be one of: timed, suddenDeath, ahCounter, imConversation.
        recommendedTone must be one of: confident, warm, concise, assertive, calm, professional, or an empty string if not relevant.
        recommendedScenario must be one of: socialCatchUp, workUpdate, difficultConversation, networking, or an empty string if not relevant.
        title should be short and action-oriented.
        detail should explain the reasoning in one sentence.
        focus should be a short coaching label.
        target should be a concise measurable target like '30s+' or 'Zero fillers' or '<150 WPM'.
        modeBenefit should explain the defined benefit of the chosen mode for this user in one sentence.
        whyMode should explain why this mode is the best fit right now in one sentence.
        whyNow should explain the timing or trend behind the recommendation in one sentence.
        """
    }

    private func prompt(
        for input: AIHomeRecommendationInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) -> String {
        """
        Average fillers: \(String(format: "%.2f", input.averageFillers))
        Filler trend delta vs previous block: \(String(format: "%.2f", input.fillerTrendDelta))
        Average duration: \(Int(input.averageDuration)) seconds
        Duration trend delta vs previous block: \(Int(input.durationTrendDelta)) seconds
        Average words per minute: \(Int(input.averageWordsPerMinute.rounded()))
        Pace trend delta vs previous block: \(Int(input.paceTrendDelta.rounded())) WPM
        Average word count: \(Int(input.averageWordCount.rounded()))
        Strongest mode: \(input.strongestMode?.rawValue ?? "none")
        Current speaking identity: \(input.currentIdentity)
        Identity evidence: \(input.currentIdentityEvidence)
        Style alignment score: \(String(format: "%.2f", input.styleAlignmentScore))
        Session streak in days: \(input.sessionStreak)
        Days since last session: \(input.daysSinceLastSession)
        Binding preferred mode: \(input.preferredModeBias)
        Binding preferred tone: \(input.preferredToneBias)
        Binding preferred scenario: \(input.preferredScenarioBias)
        Defined mode benefit to preserve: \(input.modeBenefitBias)
        Speaker context: \(profile?.speakingContext.title ?? "unknown")
        Speaker priority: \(profile?.primaryGoal.title ?? "unknown")
        Speaker challenge: \(profile?.biggestChallenge.title ?? "unknown")
        Desired outcome: \(profile?.desiredOutcome.title ?? "unknown")
        Target speaking style: \(profile?.speakingStyleGoal.title ?? "unknown")
        Personal goal reference: \(profile?.personalGoalReference ?? "none")
        Current coaching focus: \(plan?.currentFocus ?? "none")
        Suggested drill from rules engine: \(plan?.suggestedDrill ?? "none")

        Recent sessions:
        \(input.recentSessionSummary)
        """
    }

    private func apiKey(for provider: AIProvider) -> String? {
        if let keyName = provider.environmentKey,
           let value = ProcessInfo.processInfo.environment[keyName],
           !value.isEmpty {
            return value
        }
        if let keyName = provider.environmentKey,
           let value = LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig") {
            return value
        }
        return nil
    }

    private func apiError(from data: Data, provider: AIProvider) -> AICoachError {
        if provider == .gemini,
           let response = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
            return .apiFailure(response.error.message)
        }

        if let response = try? JSONDecoder().decode(OpenAICompatibleErrorResponse.self, from: data) {
            return .apiFailure(response.error.message)
        }

        return .invalidResponse
    }
}

private struct OpenAICompatibleChatRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Codable {
        let type: String

        static let jsonObject = ResponseFormat(type: "json_object")
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }
}

private extension String {
    func truncatedToWordLimit(_ limit: Int) -> String {
        let words = split(whereSeparator: \.isWhitespace)
        guard words.count > limit else { return self }
        return words.prefix(limit).joined(separator: " ")
    }
}

private struct OpenAICompatibleChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenAICompatibleErrorResponse: Codable {
    struct ErrorBody: Codable {
        let message: String
    }

    let error: ErrorBody
}

private struct GeminiGenerateContentRequest: Codable {
    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String
    }

    struct GenerationConfig: Codable {
        let temperature: Double
        let responseMimeType: String
    }

    let systemInstruction: Content
    let contents: [Content]
    let generationConfig: GenerationConfig

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
        case generationConfig
    }
}

private struct GeminiGenerateContentResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String?
            }

            let parts: [Part]
        }

        let content: Content
    }

    let candidates: [Candidate]
}

private struct GeminiErrorResponse: Codable {
    struct ErrorBody: Codable {
        let message: String
    }

    let error: ErrorBody
}
// MARK: - Video Analysis Service

#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import UIKit

@MainActor
final class VideoAnalysisService {
    static let shared = VideoAnalysisService()

    private let settings = AISettingsManager.shared
    private let frameCount = 4  // Extract 4 frames evenly spaced

    private init() {}

    func analyzeRecording(at url: URL) async throws -> VideoAnalysisResult {
        settings.resetIfNeeded()
        guard VideoAnalysisContract.localeSupportsAI(LocaleSettingsManager.shared.current) else {
            throw VideoAnalysisError.localeUnsupported
        }
        guard let provider = settings.activeProvider else {
            throw AICoachError.missingAPIKey
        }
        guard VideoAnalysisContract.providerSupportsVision(provider) else {
            throw VideoAnalysisError.providerNotVisionCapable
        }
        guard settings.canRequestAnalysis else {
            throw AICoachError.providerDisabled
        }
        guard let apiKey = apiKey(for: provider) else {
            throw AICoachError.missingAPIKey
        }

        // Extract frames from video
        let frames = try await extractFrames(from: url)
        guard !frames.isEmpty else {
            throw VideoAnalysisError.noUsableFrames
        }

        // Encode frames to base64 JPEG
        let base64Frames = frames.compactMap { image -> String? in
            guard let data = image.jpegData(compressionQuality: 0.6) else { return nil }
            return data.base64EncodedString()
        }
        guard !base64Frames.isEmpty else {
            throw VideoAnalysisError.noUsableFrames
        }

        // Build API request based on provider
        let jsonData: Data
        switch provider {
        case .none:
            throw AICoachError.providerDisabled
        case .openAI:
            jsonData = try await callOpenAIVision(apiKey: apiKey, frames: base64Frames)
        case .deepSeek:
            throw VideoAnalysisError.providerNotVisionCapable
        case .gemini:
            jsonData = try await callGeminiVision(apiKey: apiKey, frames: base64Frames)
        }

        let result = try JSONDecoder().decode(VideoAnalysisResult.self, from: jsonData)
        guard let normalized = VideoAnalysisContract.normalized(result) else {
            throw VideoAnalysisError.invalidProviderRead
        }
        await MainActor.run { settings.recordAnalysis() }
        return normalized
    }

    // MARK: - Frame Extraction

    private func extractFrames(from url: URL) async throws -> [UIImage] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)

        var frames: [UIImage] = []
        let interval = durationSeconds / Double(frameCount + 1)

        for i in 1...frameCount {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                frames.append(UIImage(cgImage: cgImage))
            } catch {
                continue
            }
        }
        return frames
    }

    // MARK: - OpenAI Vision

    private func callOpenAIVision(apiKey: String, frames: [String]) async throws -> Data {
        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        // Build multimodal content array
        var contentParts: [[String: Any]] = [
            ["type": "text", "text": videoAnalysisPrompt]
        ]
        for base64 in frames {
            contentParts.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64)", "detail": "low"]
            ])
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": videoAnalysisSystemPrompt],
                ["role": "user", "content": contentParts]
            ],
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AICoachError.invalidResponse
        }

        let chatResponse = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw AICoachError.invalidResponse
        }
        return jsonData
    }

    // MARK: - Gemini Vision

    private func callGeminiVision(apiKey: String, frames: [String]) async throws -> Data {
        let model = "gemini-2.5-flash"
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 60

        // Build parts with text + images
        var parts: [[String: Any]] = [
            ["text": videoAnalysisPrompt]
        ]
        for base64 in frames {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": videoAnalysisSystemPrompt]]],
            "contents": [["parts": parts]],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AICoachError.invalidResponse
        }

        let geminiResponse = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        guard let content = geminiResponse.candidates.first?.content.parts.compactMap(\.text).joined(),
              let jsonData = content.data(using: .utf8) else {
            throw AICoachError.invalidResponse
        }
        return jsonData
    }

    // MARK: - Prompts

    private var videoAnalysisSystemPrompt: String {
        """
        You are an expert speaking coach analyzing video frames from a practice speaking session.
        Evaluate the speaker's visual delivery across six dimensions.
        Return JSON only with these exact keys:
        posture, postureNote, eyeContact, eyeContactNote, facialExpression, facialExpressionNote,
        gestureUse, gestureNote, energyConfidence, energyNote, presenceDelivery, presenceNote, overallNote.
        Rating values must be exactly one of: "Good", "OK", "Could improve".
        Notes should be 1 sentence, specific, and actionable.
        overallNote should be 2 sentences summarizing the key strength and primary improvement area.
        Be encouraging but honest. Focus on what's observable.
        """
    }

    private var videoAnalysisPrompt: String {
        """
        Analyze these frames from a speaking practice session. Evaluate:
        1. Posture — upright, stable, open body position
        2. Eye Contact — looking at camera/audience, avoiding looking down
        3. Facial Expression — warmth, engagement, appropriate emotion
        4. Gesture Use — deliberate hand movements, not fidgeting or frozen
        5. Energy & Confidence — vocal projection visible in body, forward lean, engagement
        6. Presence & Delivery — overall command, use of space, intentional pauses reflected in stillness

        Rate each as "good", "ok", or "couldImprove" and provide a brief actionable note.
        End with an overall note summarizing the biggest strength and the #1 thing to improve.
        """
    }

    // MARK: - Helpers

    private func apiKey(for provider: AIProvider) -> String? {
        if let keyName = provider.environmentKey,
           let value = ProcessInfo.processInfo.environment[keyName],
           !value.isEmpty {
            return value
        }
        if let keyName = provider.environmentKey,
           let value = LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig") {
            return value
        }
        return nil
    }
}
#endif
