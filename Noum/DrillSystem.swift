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

// MARK: - Style Goal Alignment

/// Maps a user's chosen speaking-style goal (Authoritative / Warm / Concise / …)
/// to the SkillArea drills that most directly move them toward that voice.
/// Used by NextActionEngine to ground reasoning in the user's goal, and by
/// MiniDrillResultView to frame post-drill wins through the goal lens.
///
/// Mapping is intentionally narrow (2–3 skills per style) — broader alignment
/// would dilute the coaching signal. A skill not in the list isn't "wrong"
/// for that style, it's just not the most direct lever.
extension SpeakingStyleGoal {
    var alignedSkillAreas: Set<SkillArea> {
        switch self {
        case .authoritative:
            return [.confidence, .closingStrength, .openingStrength]
        case .warm:
            return [.paceControl, .vocalEmphasis, .answerDevelopment]
        case .concise:
            return [.conciseSpeaking, .structure, .fillerReduction]
        case .persuasive:
            return [.structure, .answerDevelopment, .closingStrength]
        case .executive:
            return [.confidence, .conciseSpeaking, .openingStrength]
        case .storytelling:
            return [.answerDevelopment, .vocalEmphasis, .pauseUsage]
        }
    }

    /// True when working on `skill` is one of the highest-leverage moves
    /// toward this style goal.
    func aligns(with skill: SkillArea) -> Bool {
        alignedSkillAreas.contains(skill)
    }

    /// The single most-direct lever for this voice — used by drill selection
    /// when there's no trend or session signal to break a tie. Deterministic
    /// (mirrors the first entry in each `alignedSkillAreas` definition) so an
    /// early-tenure user with no history still gets a goal-grounded pick
    /// instead of the generic `.structure` fallback. `alignedSkillAreas` is a
    /// `Set` and can't carry order; this accessor encodes the canonical
    /// "most direct" reading per voice.
    var primaryAlignedSkillArea: SkillArea {
        switch self {
        case .authoritative: return .confidence
        case .warm:          return .paceControl
        case .concise:       return .conciseSpeaking
        case .persuasive:    return .structure
        case .executive:     return .confidence
        case .storytelling:  return .answerDevelopment
        }
    }

    /// Short label used inline in coach copy — e.g. "warm voice", "concise voice".
    /// Lowercase, no article. Pair with a verb in the caller.
    var shortVoiceLabel: String {
        switch self {
        case .authoritative: return "authoritative voice"
        case .warm:          return "warm voice"
        case .concise:       return "concise voice"
        case .persuasive:    return "persuasive voice"
        case .executive:     return "executive presence"
        case .storytelling:  return "storytelling voice"
        }
    }

    /// Canonical visual mark for the user's chosen voice target. Kept on
    /// the enum so onboarding, profile, live banners, and recommendation
    /// chips cannot drift into separate icon languages.
    var voiceIconSystemName: String {
        switch self {
        case .authoritative: return "shield.fill"
        case .warm:          return "heart.fill"
        case .concise:       return "scissors"
        case .persuasive:    return "megaphone.fill"
        case .executive:     return "briefcase.fill"
        case .storytelling:  return "book.closed.fill"
        }
    }

    /// Resolve a `SpeakingStyleGoal` from either its raw value (e.g. "warm")
    /// or its display title (e.g. "Warm and welcoming"). NextActionEngine and
    /// other consumers receive the goal as `String?` for backward-compatible
    /// callsites — this lookup avoids forcing the type to change everywhere.
    static func resolve(_ value: String?) -> SpeakingStyleGoal? {
        guard let value, !value.isEmpty else { return nil }
        if let exact = SpeakingStyleGoal(rawValue: value) { return exact }
        return SpeakingStyleGoal.allCases.first { $0.title.caseInsensitiveCompare(value) == .orderedSame }
    }

    /// Rhetorical devices whose presence most directly serves this voice goal.
    /// Used by `LiveEloquenceHUD` to swap the chip's subtext from "noticed" to
    /// "toward your <voice> voice" when the listener earns a goal-aligned move
    /// mid-rep — the in-the-moment counterpart to `alignedSkillAreas`.
    ///
    /// Mapping is intentionally narrow (2–4 devices per voice). A device not
    /// in the list isn't "off-style" — it's just not the most direct lever
    /// for that voice and gets the neutral "noticed" treatment.
    var alignedEloquenceDevices: Set<EloquenceDevice> {
        switch self {
        case .authoritative:
            // Steady command: rule-of-three lands verdicts; epistrophe nails
            // the closing word; antithesis sharpens contrast.
            return [.tricolon, .ruleOfThree, .epistrophe, .antithesis]
        case .warm:
            // Rhythmic care: anaphora builds inviting rhythm; diacope makes
            // a key word return with weight; rhetorical questions pull the
            // listener in instead of pushing.
            return [.anaphora, .diacope, .rhetoricalQuestion, .alliteration]
        case .concise:
            // Sharp cuts: asyndeton drops conjunctions for speed; isocolon
            // gives parallel weight without padding.
            return [.asyndeton, .isocolon]
        case .persuasive:
            // Conviction architecture: rule-of-three completes the case;
            // antithesis frames the choice; anaphora drives the through-line.
            return [.tricolon, .ruleOfThree, .antithesis, .anaphora]
        case .executive:
            // Composed clarity: parallel grammar reads as deliberate;
            // rule-of-three is the boardroom move; antithesis frames trade-offs.
            return [.isocolon, .tricolon, .ruleOfThree, .antithesis]
        case .storytelling:
            // Memorable shape: anaphora is the narrator's rhythm; diacope
            // returns to a phrase; epizeuxis lands a beat; alliteration
            // makes a phrase stick; polysyndeton builds cumulative narrative
            // momentum without pretending it is concise.
            return [.anaphora, .diacope, .epizeuxis, .alliteration, .polysyndeton]
        }
    }

    /// True when this rhetorical device is one of the most direct moves
    /// toward this voice goal.
    func aligns(with device: EloquenceDevice) -> Bool {
        alignedEloquenceDevices.contains(device)
    }

    /// True when working a rep in `mode` measurably moves the speaker toward
    /// this voice goal — i.e. the mode's primary skill areas overlap with
    /// the voice's aligned skills. Used by the home `suggestionLink` to
    /// surface a "Toward your <voice>" chip on the recommendation tile when
    /// the recommended mode and the user's chosen voice line up.
    ///
    /// Returns `false` (silent) when the intersection is empty — every voice
    /// has at least one mode it aligns with and at least one it doesn't, so
    /// the chip fires some of the time and stays out of the way the rest of
    /// the time. No fake personalization on off-goal recommendations.
    func aligns(with mode: PracticeMode) -> Bool {
        !alignedSkillAreas.isDisjoint(with: mode.primarySkillAreas)
    }
}

// MARK: - PracticeMode → Skill Areas
//
// The skill areas each practice mode most directly trains. Intentionally
// narrow (2–3 per mode) — broader mappings dilute the alignment signal that
// `SpeakingStyleGoal.aligns(with:)` reads from this.
//
// Reflects the mode's actual coaching purpose, not its surface label:
//   • timed — soft clock, room for structure → answer architecture skills
//   • suddenDeath — one filler ends the round → composure under pressure
//   • ahCounter — live filler + pace tracking → in-the-moment delivery
//   • imConversation — live two-way exchange → tone + relational depth
//
// Aligned with the consumers of this map: the home recommendation chip
// (M14 voice-aware loop, fifth surface) and any future code that needs a
// canonical mode→skill projection.
extension PracticeMode {
    var primarySkillAreas: Set<SkillArea> {
        switch self {
        case .timed:
            return [.structure, .answerDevelopment, .openingStrength]
        case .suddenDeath:
            return [.confidence, .fillerReduction]
        case .ahCounter:
            return [.fillerReduction, .paceControl, .pauseUsage]
        case .imConversation:
            return [.vocalEmphasis, .answerDevelopment]
        }
    }
}

// MARK: - Drill Format

/// Whether the drill is a quick focused exercise or a full re-practice.
enum DrillFormat: String, Codable {
    case miniDrill    // 30–60 seconds, focused on one micro-skill
    case fullRetry    // Full re-practice with constraint overlay
}

// MARK: - Mini Drill Type

/// Distinguishes specialized mini-drill experiences from the standard constraint drill.
enum MiniDrillType: String, Codable {
    case standard       // Existing 45s constraint drill
    case beatTheBrake   // Live WPM gauge, stay in zone
    case landThePause   // 3 checkpoint pauses
    case prepStack      // Guided 4-step PREP structure
    case frameworkCheck // Named-framework drill graded on its own structure
                        // via the deterministic `FrameworkDrillChecks`
                        // detectors. Runs through the standard recording UI;
                        // the post-hoc structural verdict surfaces in the
                        // result copy and never moves the numeric outcome.

    /// Map a variation ID to its drill type.
    static func from(variationId: String) -> MiniDrillType {
        switch variationId {
        case "pace.beatTheBrake": return .beatTheBrake
        case "pause.landThePause": return .landThePause
        case "structure.prepStack": return .prepStack
        case "story.starTurn", "structure.claimCounter", "structure.claimEvidenceWarrant",
             "structure.monroeSequence", "concise.elevatorPitch",
             "structure.bridgeReframe", "depth.areaAnswer":
            return .frameworkCheck
        default: return .standard
        }
    }

    /// The named framework a `frameworkCheck` variation grades against, derived
    /// from its stable ID. `nil` for non-framework drills. Used by the result
    /// copy seam to route to the matching `FrameworkDrillChecks` detector.
    static func framework(for variationId: String) -> FrameworkDrill? {
        switch variationId {
        case "story.starTurn": return .starTurn
        case "structure.claimCounter": return .claimCounter
        case "structure.claimEvidenceWarrant": return .claimEvidenceWarrant
        case "structure.monroeSequence": return .monroeSequence
        case "concise.elevatorPitch": return .elevatorPitch
        case "structure.bridgeReframe": return .bridgeReframe
        case "depth.areaAnswer": return .areaAnswer
        default: return nil
        }
    }
}

/// The named-framework drills graded by `FrameworkDrillChecks`. A bounded,
/// decode-safe enum so the routing has a single typed switch rather than string
/// comparisons scattered across surfaces.
enum FrameworkDrill: String, Codable {
    case starTurn       // STAR / narrative: setup -> turn -> takeaway
    case claimCounter   // Persuasion: claim, acknowledge counter, bridge back
    case claimEvidenceWarrant // CEW: claim -> evidence -> warrant / so-what
    case monroeSequence // Monroe: attention -> need -> solution -> picture -> action
    case elevatorPitch  // Timed self-intro: named self + single hook + time box
    case bridgeReframe  // Curveball: acknowledge fairly -> bridge to the priority
    case areaAnswer     // AREA: answer -> reason -> example -> answer (close loop)
}

// MARK: - Drill-Specific Metrics

struct BeatTheBrakeMetrics {
    let averageWPM: Double
    let timeInZone: TimeInterval      // Seconds within the shared ConversationalPaceBand zone
    let totalDuration: TimeInterval
    let zonePercentage: Double        // timeInZone / totalDuration
    let peakWPM: Double
    let lowestWPM: Double
    let adjustedFillers: Int
    let rushedBursts: Int
}

struct LandThePauseMetrics {
    let checkpointsLocked: Int        // Out of 3
    let pauseDurations: [TimeInterval] // Duration of each pause
    let totalDuration: TimeInterval
    let fillerCount: Int
    let transitionFillers: Int
    let bestCombo: Int
}

struct PREPStackMetrics {
    let stepsCompleted: Int           // Out of 4 (P-R-E-P)
    let totalDuration: TimeInterval
    let wordCount: Int
    let fillerCount: Int
    let transitionFillers: Int
    let closeStrength: Double
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

// MARK: - Mini Drill Completion Integrity

/// Terminal evidence that is substantial enough to become a mini-drill
/// outcome. Keeping this separate from the live transcript prevents interim
/// fragments and provider-finalization latency from entering rewards.
struct MiniDrillCompletionEvidence: Equatable, Sendable {
    static let minimumWordCount = 3
    static let minimumDuration: TimeInterval = 3

    let transcript: String
    let wordCount: Int
    let duration: TimeInterval

    static func validated(
        transcript: String,
        captureDuration: TimeInterval
    ) -> MiniDrillCompletionEvidence? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split { !$0.isLetter && !$0.isNumber }
        guard words.count >= minimumWordCount,
              captureDuration.isFinite,
              captureDuration >= minimumDuration else {
            return nil
        }
        return MiniDrillCompletionEvidence(
            transcript: trimmed,
            wordCount: words.count,
            duration: captureDuration
        )
    }
}

/// Resolves one recorder stop into an explicit next action. Only `.eligible`
/// may construct an outcome; usable-but-thin speech returns the user to Ready
/// with a retry explanation, while transport/finalization failures preserve
/// the speech owner's recovery error.
enum MiniDrillCompletionDisposition: Equatable, Sendable {
    case eligible(MiniDrillCompletionEvidence)
    case insufficientSpeech
    case unusableRecording

    static func resolve(
        completion: FinalizedTranscript?,
        captureDuration: TimeInterval
    ) -> MiniDrillCompletionDisposition {
        guard RecordingCompletionGate.allowsScoringAndProgress(completion),
              let completion else {
            return .unusableRecording
        }
        guard let evidence = MiniDrillCompletionEvidence.validated(
            transcript: completion.text,
            captureDuration: captureDuration
        ) else {
            return .insufficientSpeech
        }
        return .eligible(evidence)
    }
}

#if DEBUG
/// Deterministic terminal evidence for the rendered TR-5 mini-drill contract.
/// The fixture deliberately supplies only the provider-owned final transcript
/// and recorder-owned duration. The real drill view still resolves the
/// disposition and constructs the outcome, and Summary remains the only
/// durable reward/result sink.
enum MiniDrillCompletionUITestFixture: String {
    case insufficient
    case eligible

    static let variationID = "filler.silentTransitions"

    static func requested(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Self? {
        guard arguments.contains("UI_TESTING"),
              let index = arguments.firstIndex(
                of: "UI_TESTING_MINI_DRILL_COMPLETION_FIXTURE"
              ),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return Self(rawValue: arguments[index + 1])
    }

    var completion: FinalizedTranscript {
        let text: String
        switch self {
        case .insufficient:
            text = "Too short"
        case .eligible:
            text = "Clear answers give listeners one point one reason and one concrete example"
        }
        return FinalizedTranscript(
            text: text,
            receivedFinalResult: true,
            audioByteCount: 4_096
        )
    }

    var captureDuration: TimeInterval { 12 }
}
#endif

/// Pure PREP evaluation shared by the specialized view and tests. Completing
/// the four UI steps is not sufficient evidence by itself: the spoken response
/// must also reach the 28-word floor disclosed by the drill.
enum PREPStackEvaluation {
    static let requiredSteps = 4
    static let minimumWordCount = 28
    static let minimumDuration: TimeInterval = 20

    static func closeStrength(stepsCompleted: Int, wordCount: Int) -> Double {
        let stepCoverage = Double(max(0, min(requiredSteps, stepsCompleted)))
            / Double(requiredSteps)
        let wordCoverage = Double(max(0, min(minimumWordCount, wordCount)))
            / Double(minimumWordCount)
        return min(stepCoverage, wordCoverage)
    }

    static func succeeded(
        stepsCompleted: Int,
        wordCount: Int,
        duration: TimeInterval
    ) -> Bool {
        stepsCompleted >= requiredSteps
            && wordCount >= minimumWordCount
            && duration.isFinite
            && duration >= minimumDuration
    }
}

// MARK: - Drill History

/// Tracks recent drill completions for freshness rotation and streak detection.
class DrillHistoryStore: ObservableObject {
    static let shared = DrillHistoryStore()
    static let capacity = 30
    static let storageKeyPrefix = "drillHistory"
    static let currentEvidenceSchemaVersion = 1

    @Published private(set) var entries: [Entry] = []

    struct Entry: Identifiable, Codable, Equatable {
        enum Source: String, Codable, Equatable {
            case miniDrill
        }

        let id: UUID
        let variationId: String
        let skillArea: SkillArea
        let date: Date
        let succeeded: Bool
        /// The practice session that prescribed this drill, when one exists.
        let sessionId: UUID?
        /// Stable identity from the terminal mini-drill outcome. This is the
        /// durable idempotency key; `id` remains the history-row identity for
        /// backwards-compatible decoding.
        let outcomeID: UUID?
        let evidenceSchemaVersion: Int?
        let source: Source?
        let terminalWordCount: Int?
        let terminalDuration: TimeInterval?
        let awardedXP: Int?

        /// Explicit semantic name for new call sites while the encoded
        /// `sessionId` field remains stable for legacy archive decoding.
        var parentSessionId: UUID? { sessionId }

        /// Legacy value initializer retained for pure evaluators and old
        /// archives. Rows built this way deliberately have no current evidence
        /// provenance and therefore cannot be persisted by `record(_:)`.
        init(
            variationId: String,
            skillArea: SkillArea,
            date: Date = Date(),
            succeeded: Bool,
            sessionId: UUID
        ) {
            self.id = UUID()
            self.variationId = variationId
            self.skillArea = skillArea
            self.date = date
            self.succeeded = succeeded
            self.sessionId = sessionId
            self.outcomeID = nil
            self.evidenceSchemaVersion = nil
            self.source = nil
            self.terminalWordCount = nil
            self.terminalDuration = nil
            self.awardedXP = nil
        }

        private init(
            id: UUID,
            variationId: String,
            skillArea: SkillArea,
            date: Date,
            succeeded: Bool,
            sessionId: UUID?,
            outcomeID: UUID?,
            evidenceSchemaVersion: Int?,
            source: Source?,
            terminalWordCount: Int?,
            terminalDuration: TimeInterval?,
            awardedXP: Int?
        ) {
            self.id = id
            self.variationId = variationId
            self.skillArea = skillArea
            self.date = date
            self.succeeded = succeeded
            self.sessionId = sessionId
            self.outcomeID = outcomeID
            self.evidenceSchemaVersion = evidenceSchemaVersion
            self.source = source
            self.terminalWordCount = terminalWordCount
            self.terminalDuration = terminalDuration
            self.awardedXP = awardedXP
        }

        /// Constructs a current-schema receipt. Validation intentionally lives
        /// at the store boundary too, so a malformed candidate can never become
        /// progress merely because a caller used this factory.
        static func verified(
            outcomeID: UUID,
            variationId: String,
            skillArea: SkillArea,
            date: Date = Date(),
            succeeded: Bool,
            parentSessionId: UUID,
            terminalWordCount: Int,
            recorderDuration: TimeInterval,
            awardedXP: Int
        ) -> Entry {
            Entry(
                id: outcomeID,
                variationId: variationId,
                skillArea: skillArea,
                date: date,
                succeeded: succeeded,
                sessionId: parentSessionId,
                outcomeID: outcomeID,
                evidenceSchemaVersion: DrillHistoryStore.currentEvidenceSchemaVersion,
                source: .miniDrill,
                terminalWordCount: terminalWordCount,
                terminalDuration: recorderDuration,
                awardedXP: awardedXP
            )
        }

        var isVerified: Bool {
            evidenceSchemaVersion == DrillHistoryStore.currentEvidenceSchemaVersion
                && source == .miniDrill
                && outcomeID == id
                && sessionId != nil
                && !variationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && terminalWordCount.map { $0 >= MiniDrillCompletionEvidence.minimumWordCount } == true
                && terminalDuration.map {
                    $0.isFinite && $0 >= MiniDrillCompletionEvidence.minimumDuration
                } == true
                && awardedXP.map { DrillXPEngine.awardRange.contains($0) } == true
        }
    }

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        self.accountIDProvider = accountIDProvider ?? {
            KeychainHelper.load(key: "NoumAccountID")
        }
        load()
    }

    /// Persists one verified terminal receipt. Duplicate outcomes and invalid
    /// evidence are rejected before any in-memory or durable mutation occurs.
    @discardableResult
    func record(_ entry: Entry) -> Bool {
        guard entry.isVerified,
              let outcomeID = entry.outcomeID,
              !entries.contains(where: { $0.outcomeID == outcomeID }) else {
            return false
        }

        var updated = entries
        updated.append(entry)
        updated.sort { lhs, rhs in
            if lhs.date == rhs.date { return lhs.id.uuidString > rhs.id.uuidString }
            return lhs.date > rhs.date
        }
        entries = Array(updated.prefix(Self.capacity))
        save()
        return true
    }

    func reloadForCurrentAccount() {
        load()
    }

    /// Clears only process memory. Durable account history remains available
    /// when that account starts another authenticated session.
    func endSession() {
        entries = []
    }

    /// How many consecutive successful drills in a given skill area (most recent first).
    func currentStreak(for skillArea: SkillArea) -> Int {
        var count = 0
        for entry in entries where entry.skillArea == skillArea {
            if entry.succeeded { count += 1 } else { break }
        }
        return count
    }

    /// The streak that would be visible after a candidate outcome is inserted.
    /// This lets the caller calculate and persist its exact XP receipt before
    /// granting any separate profile reward.
    func streakAfterRecording(for skillArea: SkillArea, succeeded: Bool) -> Int {
        succeeded ? currentStreak(for: skillArea) + 1 : 0
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
            defaults.set(data, forKey: currentStorageKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: currentStorageKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            entries = []
            return
        }

        entries = Array(decoded
            .filter(\.isVerified)
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.id.uuidString > rhs.id.uuidString }
                return lhs.date > rhs.date
            }
            .prefix(Self.capacity))

        // Rewrite the account archive after filtering so unverified legacy
        // rows are quarantined once rather than reconsidered on every launch.
        save()
    }

    private var currentStorageKey: String {
        let accountID = accountIDProvider()
        let accountScope = accountID.map { $0.isEmpty ? "guest" : $0 } ?? "guest"
        return "\(Self.storageKeyPrefix).\(accountScope)"
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
            successDescription: "WPM within \(ConversationalPaceBand.displayRange) range"
        ),
        DrillVariation(
            id: "pace.slowStart",
            skillArea: .paceControl,
            title: "The Slow Start",
            constraint: "Deliberately slow your first 10 seconds to half your normal speed.",
            coachingPrinciple: "A slow start anchors calm for the rest of the answer.",
            format: .miniDrill,
            successDescription: "Pace below \(ConversationalPaceBand.maxDisplayWPM) WPM"
        ),
        DrillVariation(
            id: "pace.pausePunctuation",
            skillArea: .paceControl,
            title: "Pause Punctuation",
            constraint: "Pause for one full second after every period. Let each sentence land.",
            coachingPrinciple: "Pauses between sentences naturally regulate pace.",
            format: .miniDrill,
            successDescription: "WPM within \(ConversationalPaceBand.displayRange) range"
        ),
        DrillVariation(
            id: "pace.speedCheck",
            skillArea: .paceControl,
            title: "The Speed Check",
            constraint: "Halfway through your answer, consciously check your pace and adjust.",
            coachingPrinciple: "Self-monitoring builds the habit of pace awareness.",
            format: .miniDrill,
            successDescription: "WPM within \(ConversationalPaceBand.displayRange) range"
        ),
        DrillVariation(
            id: "pace.conversationalGear",
            skillArea: .paceControl,
            title: "Conversational Gear",
            constraint: "Speak as if explaining something to a friend over coffee. Natural, unhurried.",
            coachingPrinciple: "Conversational pace is the most persuasive pace.",
            format: .miniDrill,
            successDescription: "WPM within \(ConversationalPaceBand.displayRange) range"
        ),
        DrillVariation(
            id: "pace.beatTheBrake",
            skillArea: .paceControl,
            title: "Beat the Brake",
            constraint: "Keep your pace between \(ConversationalPaceBand.displayRange) WPM. The gauge turns red if you drift.",
            coachingPrinciple: "Controlled pace is the foundation of clear communication.",
            format: .miniDrill,
            successDescription: "60%+ time in the zone"
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
        DrillVariation(
            id: "structure.prepStack",
            skillArea: .structure,
            title: "PREP Stack",
            constraint: "Follow the guided structure: Point → Reason → Example → Point. Advance each step.",
            coachingPrinciple: "PREP is the gold standard for structured impromptu responses.",
            format: .miniDrill,
            successDescription: "All 4 PREP steps completed"
        ),
        DrillVariation(
            id: "structure.claimCounter",
            skillArea: .structure,
            title: "Claim & Counter",
            constraint: "Make your claim, then acknowledge the strongest counter-argument (\"Some would say…\", \"Admittedly…\") before bridging back (\"But…\", \"Still…\") to why your claim holds.",
            coachingPrinciple: "Claim-evidence-warrant: acknowledging the counter before bridging back is what separates a persuasive case from a one-sided assertion.",
            format: .miniDrill,
            successDescription: "A counter acknowledged, then bridged back to your claim"
        ),
        DrillVariation(
            id: "structure.claimEvidenceWarrant",
            skillArea: .structure,
            title: "Claim, Evidence, Warrant",
            constraint: "Make one claim, back it with a reason or evidence (\"because…\"), then add the warrant: what that evidence means (\"which means…\", \"so the impact is…\").",
            coachingPrinciple: "CEW gives an argument its backbone: point, proof, and the so-what that makes the proof matter.",
            format: .miniDrill,
            successDescription: "Claim, evidence, and warrant all present"
        ),
        DrillVariation(
            id: "structure.monroeSequence",
            skillArea: .structure,
            title: "Monroe's Sequence",
            constraint: "Persuade in order: attention, need, solution, picture the better outcome, then one concrete action.",
            coachingPrinciple: "Monroe's Sequence works because it earns action: make them feel the need, see the solution, picture the outcome, then ask.",
            format: .miniDrill,
            successDescription: "Need, solution, visualization, and action in order"
        ),
        DrillVariation(
            id: "structure.bridgeReframe",
            skillArea: .structure,
            title: "Reframe the Curveball",
            constraint: "Answer a hostile or loaded question: acknowledge it fairly first (\"That's fair…\", \"I hear that…\"), then bridge to the more important issue (\"The real question is…\", \"What matters more…\").",
            coachingPrinciple: "Under a curveball, the acknowledge-then-bridge move is what reframes the question fairly instead of dodging it — concede the premise, then redirect to what matters most.",
            format: .miniDrill,
            successDescription: "Acknowledged the question, then bridged to the more important point"
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
        DrillVariation(
            id: "story.starTurn",
            skillArea: .answerDevelopment,
            title: "Story Arc",
            constraint: "Tell a real story: set the scene, then hit the turn — the moment it changed (\"…but then…\", \"…until…\", \"that's when…\") — and land the takeaway.",
            coachingPrinciple: "A story without a turn is just a description. The pivot from setup to change is what makes a STAR answer land.",
            format: .miniDrill,
            successDescription: "A clear turn between the setup and the takeaway"
        ),
        DrillVariation(
            id: "depth.areaAnswer",
            skillArea: .answerDevelopment,
            title: "AREA — Answer, Reason, Example, Answer",
            constraint: "Lead with your answer, give the reason (\"because…\"), ground it in one concrete example (\"for instance…\", \"last week…\"), then close by returning to the answer.",
            coachingPrinciple: "AREA develops an answer the way a coach would: state it, justify it, prove it with one example, then loop back so the point lands twice.",
            format: .miniDrill,
            successDescription: "Answer led, reason given, one example, then looped back to the answer"
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
        DrillVariation(
            id: "concise.elevatorPitch",
            skillArea: .conciseSpeaking,
            title: "The Elevator Pitch",
            constraint: "Introduce yourself and land one concrete hook — who you are and the single thing worth remembering — in under 30 seconds.",
            coachingPrinciple: "An elevator pitch is a self-introduction with one memorable hook, delivered before the doors open. Name yourself, make one point, stop.",
            format: .miniDrill,
            successDescription: "Named yourself with one clear hook, inside 30 seconds"
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
        DrillVariation(
            id: "pause.landThePause",
            skillArea: .pauseUsage,
            title: "Land the Pause",
            constraint: "Lock in 3 deliberate pauses during your answer. Tap to lock each one.",
            coachingPrinciple: "Intentional pauses separate good speakers from great ones.",
            format: .miniDrill,
            successDescription: "All 3 checkpoints locked"
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

// MARK: - Drill XP Engine

/// Performance-based XP calculation for mini-drills.
/// Replaces hardcoded 50/20 values with a formula based on actual drill metrics.
///
/// Formula:
///   baseXP (success/fail) + qualityBonus + cleanBonus + streakModifier
///
/// Range: 10–80 XP per drill (roughly).
enum DrillXPEngine {
    static let awardRange = 10...80

    struct Breakdown: Equatable {
        let base: Int
        let quality: Int
        let clean: Int
        let streak: Int

        var total: Int {
            min(
                DrillXPEngine.awardRange.upperBound,
                max(DrillXPEngine.awardRange.lowerBound, base + quality + clean + streak)
            )
        }
        var label: String {
            var parts = ["\(base) base"]
            if quality > 0 { parts.append("+\(quality) quality") }
            if clean > 0 { parts.append("+\(clean) clean") }
            if streak > 0 { parts.append("+\(streak) streak") }
            return parts.joined(separator: " / ")
        }
    }

    /// Calculate XP earned for a drill outcome.
    static func calculate(outcome: MiniDrillOutcome) -> Int {
        breakdown(outcome: outcome).total
    }

    static func breakdown(outcome: MiniDrillOutcome) -> Breakdown {
        breakdown(
            outcome: outcome,
            streak: DrillHistoryStore.shared.currentStreak(for: outcome.drill.skillArea)
        )
    }

    /// Variant used by the durable reward sink. The caller supplies the
    /// prospective streak so the exact award can be written into the receipt
    /// before profile XP is granted.
    static func breakdown(outcome: MiniDrillOutcome, streak: Int) -> Breakdown {
        let base = outcome.succeeded ? 30 : 10

        var qualityBonus = 0
        var cleanBonus = 0

        switch outcome.drillType {
        case .standard:
            qualityBonus = standardQualityBonus(outcome: outcome)
        case .beatTheBrake:
            qualityBonus = beatTheBrakeQualityBonus(outcome: outcome)
        case .landThePause:
            qualityBonus = landThePauseQualityBonus(outcome: outcome)
        case .prepStack:
            qualityBonus = prepStackQualityBonus(outcome: outcome)
        case .frameworkCheck:
            // Framework drills run through the standard recording flow, so they
            // earn the same word-density / duration-engagement quality bonus.
            // The structural verdict is deliberately NOT an XP input — XP stays
            // driven by `succeeded` + delivery density only (score-safety: the
            // verdict surfaces as coaching copy, never as points).
            qualityBonus = standardQualityBonus(outcome: outcome)
        }

        // Clean execution bonus: zero fillers in any drill
        if outcome.fillerCount == 0 && outcome.wordCount >= 10 {
            cleanBonus = 10
        }

        // Streak modifier: consecutive successes in this skill area give a small bump
        let streakBonus = min(max(0, streak) * 3, 15) // Cap at +15 for 5+ streak

        return Breakdown(base: base, quality: qualityBonus, clean: cleanBonus, streak: streakBonus)
    }

    // MARK: - Drill-Specific Quality Bonuses

    private static func standardQualityBonus(outcome: MiniDrillOutcome) -> Int {
        guard outcome.succeeded else { return 0 }
        var bonus = 0
        // Word density bonus: more meaningful content
        if outcome.wordCount >= 50 { bonus += 5 }
        if outcome.wordCount >= 80 { bonus += 5 }
        // Duration engagement: used most of the drill time
        if outcome.duration >= 35 { bonus += 5 }
        return bonus
    }

    private static func beatTheBrakeQualityBonus(outcome: MiniDrillOutcome) -> Int {
        guard let m = outcome.beatTheBrakeMetrics else { return 0 }
        var bonus = 0
        // Zone percentage tiers
        if m.zonePercentage >= 0.80 { bonus += 15 }
        else if m.zonePercentage >= 0.70 { bonus += 10 }
        else if m.zonePercentage >= 0.60 { bonus += 5 }
        // Tight range bonus: peak and lowest both within zone
        if m.peakWPM <= 145 && m.lowestWPM >= 105 { bonus += 5 }
        return bonus
    }

    private static func landThePauseQualityBonus(outcome: MiniDrillOutcome) -> Int {
        guard let m = outcome.landThePauseMetrics else { return 0 }
        var bonus = 0
        // Per-checkpoint bonus
        bonus += m.checkpointsLocked * 5
        // Pause quality: average pause duration in sweet spot (0.8–2.0s)
        let avgPause = m.pauseDurations.isEmpty ? 0 : m.pauseDurations.reduce(0, +) / Double(m.pauseDurations.count)
        if avgPause >= 0.8 && avgPause <= 2.0 { bonus += 5 }
        return bonus
    }

    private static func prepStackQualityBonus(outcome: MiniDrillOutcome) -> Int {
        guard let m = outcome.prepStackMetrics else { return 0 }
        var bonus = 0
        // Per-step bonus
        bonus += m.stepsCompleted * 4
        // Content depth bonus
        if m.wordCount >= 60 { bonus += 5 }
        return bonus
    }
}
