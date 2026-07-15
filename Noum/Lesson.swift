import Foundation

// MARK: - Lesson Model
//
// Short, technique-focused lessons that teach a single communication
// move. Each lesson is 3 progressive steps:
//
//  1. **Concept** — read what the technique is and why it works.
//  2. **Spot it** — multiple-choice: identify the technique in candidate
//     sentences. The user is doing recognition, not production.
//  3. **Apply** — speak a 30–45s answer using the technique. A transparent,
//     deterministic rubric validates the observable parts of the move.
//
// Retention is tracked per-lesson as 0–5 spaced practice passes. Progress
// persists per-account; `LessonStore` decides when another pass is due.

struct Lesson: Identifiable, Hashable {
    let id: String
    let title: String
    /// One-sentence teaser shown on the catalog row.
    let tagline: String
    /// Theme — used for grouping + icon colouring.
    let category: Category
    /// SF Symbol for the catalog row + lesson hero.
    let symbolName: String
    /// Ordered steps the user works through.
    let steps: [Step]
    /// Devices the user is expected to demonstrate in the Apply step.
    /// Nil when the lesson isn't about a specific eloquence device
    /// (e.g. pause-instead-of-filler is a delivery move, not a device).
    let targetDevice: EloquenceDevice?
    /// A concrete, low-friction way to carry the technique into a real
    /// conversation. This is guidance, not a second state system.
    let transferPrompt: String
    /// Observable checks for the Apply step. These deliberately evaluate the
    /// shape of the response, not the user's intent or personality.
    let applyCriteria: [LessonApplyCriterion]
    /// Fresh prompts used on later spaced rounds so retention is tested on a
    /// new situation instead of rehearsing one memorized answer.
    let reviewPrompts: [String]

    init(
        id: String,
        title: String,
        tagline: String,
        category: Category,
        symbolName: String,
        steps: [Step],
        targetDevice: EloquenceDevice?,
        transferPrompt: String = "Use this move once in your next real conversation.",
        applyCriteria: [LessonApplyCriterion] = [],
        reviewPrompts: [String] = []
    ) {
        self.id = id
        self.title = title
        self.tagline = tagline
        self.category = category
        self.symbolName = symbolName
        self.steps = steps
        self.targetDevice = targetDevice
        self.transferPrompt = transferPrompt
        self.applyCriteria = applyCriteria
        self.reviewPrompts = reviewPrompts
    }

    enum Category: String, Codable, CaseIterable {
        case delivery       // pacing, pause, filler control
        case structure      // openings, closes, parallelism
        case interaction    // listening, questions, feedback, repair
        case explanation    // audience adaptation, plain language
        case rhetoric       // tricolon, anaphora, etc.

        var label: String {
            switch self {
            case .delivery:  return "Delivery"
            case .structure: return "Structure"
            case .interaction: return "Conversation"
            case .explanation: return "Explanation"
            case .rhetoric:  return "Rhetoric"
            }
        }
    }

    enum Step: Hashable {
        /// Concept step. Plain copy + a short example sentence the user
        /// can read aloud to feel the rhythm.
        case concept(headline: String, body: String, example: String?)

        /// Multiple-choice "spot it". Three candidate sentences, exactly
        /// one of which uses the target device.
        case spotIt(question: String, options: [Option])

        /// Apply step. The user records a short answer using the technique.
        /// The EloquenceEngine validates whether they actually used the
        /// `expectedDevice` (or, for delivery lessons, a free-form pass).
        case apply(prompt: String, expectedDevice: EloquenceDevice?, durationTarget: TimeInterval)

        struct Option: Hashable {
            let text: String
            let isCorrect: Bool
            /// Why this option is right or wrong — shown as feedback after
            /// the user picks. Coach voice, never apologetic.
            let explanation: String
        }
    }
}

// MARK: - Apply rubric

/// One user-visible, deterministic check for a lesson's Apply step. The
/// authored title and feedback make the evaluation inspectable instead of
/// hiding a vague pass/fail behind an AI score.
struct LessonApplyCriterion: Identifiable, Hashable {
    let id: String
    let title: String
    let kind: Kind
    let successFeedback: String
    let retryFeedback: String

    enum Kind: Hashable {
        case minimumWords(Int)
        case wordRange(minimum: Int, maximum: Int)
        case containsAny([String])
        case avoidsAny([String])
        case maximumFillers(Int)
        case minimumQuestionSignals(Int)
        case directOpening
        case expectedDevice(EloquenceDevice)
    }
}

struct LessonApplyCriterionResult: Identifiable, Equatable {
    let criterionID: String
    let title: String
    let passed: Bool
    let feedback: String

    var id: String { criterionID }
}

struct LessonApplyEvaluation: Equatable {
    let results: [LessonApplyCriterionResult]

    var passed: Bool {
        !results.isEmpty && results.allSatisfy(\.passed)
    }

    var firstMiss: LessonApplyCriterionResult? {
        results.first(where: { !$0.passed })
    }
}

/// Pure transcript-shape evaluation used by both the lesson runner and tests.
/// It intentionally avoids sentiment, personality, or semantic-certainty
/// claims that the captured words cannot support.
enum LessonApplyEvaluator {
    static let defaultMinimumWordCount = 12
    static let minimumRecorderDuration: TimeInterval = 3

    private static let fillerTokens: Set<String> = [
        "um", "uh", "erm", "hmm", "basically", "literally"
    ]
    private static let directOpeningMisses = [
        "so ", "well ", "i think", "i guess", "it depends",
        "that s a good question", "there are a lot"
    ]
    private static let questionStarters = [
        "what", "how", "why", "when", "where", "who", "which",
        "could", "would", "can", "do", "does", "did", "is", "are",
        "tell me"
    ]

    static func evaluate(
        transcript: String,
        findings: [EloquenceFinding],
        lesson: Lesson
    ) -> LessonApplyEvaluation {
        let criteria = effectiveCriteria(for: lesson)
        let normalized = normalize(transcript)
        let words = normalized.split(separator: " ").map(String.init)

        let results = criteria.map { criterion in
            let passed = evaluate(
                criterion.kind,
                transcript: transcript,
                normalized: normalized,
                words: words,
                findings: findings
            )
            return LessonApplyCriterionResult(
                criterionID: criterion.id,
                title: criterion.title,
                passed: passed,
                feedback: passed ? criterion.successFeedback : criterion.retryFeedback
            )
        }
        return LessonApplyEvaluation(results: results)
    }

    static func effectiveCriteria(for lesson: Lesson) -> [LessonApplyCriterion] {
        let authored: [LessonApplyCriterion]
        if !lesson.applyCriteria.isEmpty {
            authored = lesson.applyCriteria
        } else if let device = lesson.targetDevice {
            authored = [
                LessonApplyCriterion(
                    id: "expected-device",
                    title: device.title,
                    kind: .expectedDevice(device),
                    successFeedback: "The technique showed up in the transcript.",
                    retryFeedback: "Try the pattern once more so it is visible in the answer."
                )
            ]
        } else {
            authored = []
        }

        guard !authored.contains(where: { $0.kind.minimumWordCount != nil }) else {
            return authored
        }

        return [completeResponseCriterion(minimumWords: defaultMinimumWordCount)] + authored
    }

    static func minimumWordCount(for lesson: Lesson) -> Int {
        effectiveCriteria(for: lesson)
            .compactMap { $0.kind.minimumWordCount }
            .max() ?? defaultMinimumWordCount
    }

    static func wordCount(in transcript: String) -> Int {
        normalize(transcript).split(separator: " ").count
    }

    private static func completeResponseCriterion(minimumWords: Int) -> LessonApplyCriterion {
        LessonApplyCriterion(
            id: "complete-answer",
            title: "Complete answer",
            kind: .minimumWords(minimumWords),
            successFeedback: "You gave the move enough room to land.",
            retryFeedback: "Give a complete answer of at least \(minimumWords) words."
        )
    }

    private static func evaluate(
        _ kind: LessonApplyCriterion.Kind,
        transcript: String,
        normalized: String,
        words: [String],
        findings: [EloquenceFinding]
    ) -> Bool {
        switch kind {
        case .minimumWords(let minimum):
            return words.count >= minimum
        case .wordRange(let minimum, let maximum):
            return words.count >= minimum && words.count <= maximum
        case .containsAny(let phrases):
            return phrases.contains { normalized.contains(normalize($0)) }
        case .avoidsAny(let phrases):
            return !phrases.contains { normalized.contains(normalize($0)) }
        case .maximumFillers(let maximum):
            let count = words.filter { fillerTokens.contains($0) }.count
            return count <= maximum
        case .minimumQuestionSignals(let minimum):
            return questionSignalCount(in: transcript, normalized: normalized) >= minimum
        case .directOpening:
            guard words.count >= 3 else { return false }
            return !directOpeningMisses.contains { normalized.hasPrefix($0) }
        case .expectedDevice(let device):
            return findings.contains(where: { $0.device == device })
        }
    }

    private static func questionSignalCount(in transcript: String, normalized: String) -> Int {
        let punctuationCount = transcript.filter { $0 == "?" }.count
        if punctuationCount > 0 { return punctuationCount }

        let clauses = transcript.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ".!;"))
            .map(normalize)
            .filter { !$0.isEmpty }
        let clauseCount = clauses.filter { clause in
            questionStarters.contains { starter in
                clause == starter || clause.hasPrefix(starter + " ")
            }
        }.count
        if clauseCount > 1 { return clauseCount }

        // Some speech recognizers omit punctuation. Count distinct question
        // openings in the normalized transcript as a conservative fallback.
        let padded = " " + normalized + " "
        let starterCount = questionStarters.reduce(into: 0) { count, starter in
            if normalized.hasPrefix(starter + " ") || padded.contains(" \(starter) ") {
                count += 1
            }
        }
        return max(clauseCount, starterCount)
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private extension LessonApplyCriterion.Kind {
    var minimumWordCount: Int? {
        switch self {
        case .minimumWords(let minimum):
            return minimum
        case .wordRange(let minimum, _):
            return minimum
        case .containsAny, .avoidsAny, .maximumFillers,
             .minimumQuestionSignals, .directOpening, .expectedDevice:
            return nil
        }
    }
}

// MARK: - Apply completion evidence

/// Transcript-free proof that a terminal Lesson Apply capture carried enough
/// real speech to make its authored rubric meaningful. The transcript remains
/// transient in the view; durable lesson progress stores only aggregate passes.
struct LessonApplyCompletionEvidence: Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let terminalWordCount: Int
    let recorderDuration: TimeInterval

    static func verified(
        transcript: String,
        recorderDuration: TimeInterval,
        lesson: Lesson
    ) -> LessonApplyCompletionEvidence? {
        let evidence = LessonApplyCompletionEvidence(
            schemaVersion: currentSchemaVersion,
            terminalWordCount: LessonApplyEvaluator.wordCount(in: transcript),
            recorderDuration: recorderDuration
        )
        return evidence.isVerified(for: lesson) ? evidence : nil
    }

    func isVerified(for lesson: Lesson) -> Bool {
        schemaVersion == Self.currentSchemaVersion
            && terminalWordCount >= LessonApplyEvaluator.minimumWordCount(for: lesson)
            && recorderDuration.isFinite
            && recorderDuration >= LessonApplyEvaluator.minimumRecorderDuration
    }
}

enum LessonApplyCompletionDisposition: Equatable {
    case unusableRecording
    case insufficientDuration(required: TimeInterval)
    case evaluated(
        transcript: String,
        evaluation: LessonApplyEvaluation,
        evidence: LessonApplyCompletionEvidence?
    )

    static func resolve(
        completion: FinalizedTranscript?,
        recorderDuration: TimeInterval,
        findings: [EloquenceFinding],
        lesson: Lesson
    ) -> LessonApplyCompletionDisposition {
        guard RecordingCompletionGate.allowsScoringAndProgress(completion),
              let completion else {
            return .unusableRecording
        }

        let transcript = completion.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let evaluation = LessonApplyEvaluator.evaluate(
            transcript: transcript,
            findings: findings,
            lesson: lesson
        )
        guard recorderDuration.isFinite,
              recorderDuration >= LessonApplyEvaluator.minimumRecorderDuration else {
            return .insufficientDuration(required: LessonApplyEvaluator.minimumRecorderDuration)
        }

        return .evaluated(
            transcript: transcript,
            evaluation: evaluation,
            evidence: LessonApplyCompletionEvidence.verified(
                transcript: transcript,
                recorderDuration: recorderDuration,
                lesson: lesson
            )
        )
    }
}

// MARK: - Lesson Outcome

/// Result of one full pass through a lesson. Used by `LessonStore` to
/// raise practice-pass progress and by the celebration overlay to render
/// the cleared/mastered moment.
struct LessonOutcome: Equatable {
    let lessonID: String
    let stepResults: [StepResult]
    let xpEarned: Int
    let applyEvidence: LessonApplyCompletionEvidence?

    init(
        lessonID: String,
        stepResults: [StepResult],
        xpEarned: Int,
        applyEvidence: LessonApplyCompletionEvidence? = nil
    ) {
        self.lessonID = lessonID
        self.stepResults = stepResults
        self.xpEarned = xpEarned
        self.applyEvidence = applyEvidence
    }

    var isPerfect: Bool {
        passed && stepResults.allSatisfy(\.passed)
    }

    var hasVerifiedAttemptShape: Bool {
        guard stepResults.count == 3,
              stepResults.filter({ $0.kind == .concept }).count == 1,
              stepResults.filter({ $0.kind == .spotIt }).count == 1,
              stepResults.filter({ $0.kind == .apply }).count == 1,
              let lesson = LessonsCatalog.lesson(id: lessonID),
              applyEvidence?.isVerified(for: lesson) == true else {
            return false
        }
        return true
    }

    var passed: Bool {
        guard hasVerifiedAttemptShape else { return false }
        return stepResults.allSatisfy(\.passed)
    }

    enum StepResult: Equatable {
        case concept
        case spotIt(passed: Bool)
        case apply(passed: Bool, didUseDevice: Bool)

        var passed: Bool {
            switch self {
            case .concept: return true // concept step is read-through, can't fail
            case .spotIt(let passed): return passed
            case .apply(let passed, _): return passed
            }
        }

        var kind: Kind {
            switch self {
            case .concept: return .concept
            case .spotIt: return .spotIt
            case .apply: return .apply
            }
        }

        enum Kind { case concept, spotIt, apply }
    }
}

// MARK: - Lesson XP

enum LessonXP {
    /// Base XP for a lesson pass. Lower than a full session — lessons are
    /// short. Bonus stacks on a perfect run (right answer first time on
    /// spot-it AND device demonstrated on apply).
    static let baseXP = 30
    static let perfectBonus = 20

    static func xp(for outcome: LessonOutcome) -> Int {
        guard outcome.passed else { return 0 }
        var xp = baseXP
        if outcome.isPerfect { xp += perfectBonus }
        return xp
    }
}
