import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

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

struct CoachingProfile: Codable, Equatable {
    var speakingContext: SpeakingContext
    var primaryGoal: CoachingPriority
    var confidenceLevel: ConfidenceLevel
    var biggestChallenge: SpeakingChallenge
    var desiredOutcome: SpeakingOutcome
    var coachingBrief: String

    var isComplete: Bool { true }
}

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case none
    case openAI
    case deepSeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Off"
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        }
    }

    var model: String {
        switch self {
        case .none: return ""
        case .openAI: return "gpt-5-mini"
        case .deepSeek: return "deepseek-chat"
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
        }
    }

    var environmentKey: String? {
        switch self {
        case .none: return nil
        case .openAI: return "OPENAI_API_KEY"
        case .deepSeek: return "DEEPSEEK_API_KEY"
        }
    }
}

struct AICoachFeedback: Codable, Equatable {
    let strengths: [String]
    let keyImprovement: String
    let suggestedDrill: String
    let revisedOpening: String
}

#if canImport(SwiftUI)
@MainActor
final class PracticeSettingsManager: ObservableObject {
    static let shared = PracticeSettingsManager()

    @Published var timedDifficulty: TimedPracticeDifficulty {
        didSet { UserDefaults.standard.set(timedDifficulty.rawValue, forKey: timedDifficultyKey) }
    }

    private let timedDifficultyKey = "timedPracticeDifficulty"

    private init() {
        let rawValue = UserDefaults.standard.string(forKey: timedDifficultyKey)
        timedDifficulty = TimedPracticeDifficulty(rawValue: rawValue ?? "") ?? .easy
    }
}

@MainActor
final class CoachingProfileStore: ObservableObject {
    static let shared = CoachingProfileStore()

    @Published private(set) var profile: CoachingProfile?

    private let profileKey = "coachingProfile"

    private init() {
        profile = Self.loadProfile(forKey: profileKey)
    }

    var needsOnboarding: Bool {
        profile == nil
    }

    func save(_ profile: CoachingProfile) {
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    private static func loadProfile(forKey key: String) -> CoachingProfile? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(CoachingProfile.self, from: data) else { return nil }
        return profile
    }
}

@MainActor
final class AISettingsManager: ObservableObject {
    static let shared = AISettingsManager()

    @Published var provider: AIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: providerKey) }
    }
    @Published var monthlyAnalysisLimit: Int {
        didSet { UserDefaults.standard.set(monthlyAnalysisLimit, forKey: limitKey) }
    }
    @Published private(set) var analysisCountThisMonth: Int {
        didSet { UserDefaults.standard.set(analysisCountThisMonth, forKey: countKey) }
    }

    private let providerKey = "aiProvider"
    private let limitKey = "aiMonthlyAnalysisLimit"
    private let countKey = "aiMonthlyAnalysisCount"
    private let monthKey = "aiMonthlyAnalysisMonth"

    private init() {
        provider = AIProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .none
        let storedLimit = UserDefaults.standard.integer(forKey: limitKey)
        monthlyAnalysisLimit = storedLimit == 0 ? 20 : storedLimit
        analysisCountThisMonth = UserDefaults.standard.integer(forKey: countKey)
        resetIfNeeded()
    }

    var remainingAnalyses: Int {
        max(0, monthlyAnalysisLimit - analysisCountThisMonth)
    }

    var canRequestAnalysis: Bool {
        provider != .none && remainingAnalyses > 0
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
}
#endif

struct PracticeEvaluation {
    let score: Int
    let xpEarned: Int
    let headline: String
    let feedback: String
    let segments: [PracticeScoreSegment]
    let insights: [String]
}

struct PracticeScoreSegment: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tintName: String
}

enum PracticeEvaluator {
    static func evaluateTimedPractice(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        difficulty: TimedPracticeDifficulty,
        recentSessions: [PracticeSession]
    ) -> PracticeEvaluation {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = wordCount(in: cleanTranscript)
        let targetDuration = Double(difficulty.duration ?? 45)
        let durationProgress = min(duration / targetDuration, 1.0)
        let contentProgress = min(Double(wordCount) / 35.0, 1.0)
        let wordsPerMinute = duration > 0 ? (Double(wordCount) / duration) * 60.0 : 0
        let paceProgress = max(0, min(wordsPerMinute / 110.0, 1.0))
        let fillerPenalty = min(Double(fillerCount) * 0.7, 3.0)
        let difficultyBonus: Double = {
            switch difficulty {
            case .free: return 0.0
            case .easy: return 0.2
            case .medium: return 0.6
            case .hard: return 1.0
            }
        }()

        let previousSessions = Array(recentSessions.dropFirst())
        let averageFillers = previousSessions.isEmpty
            ? Double(fillerCount)
            : Double(previousSessions.map(\.fillerWordCount).reduce(0, +)) / Double(previousSessions.count)
        let averageDuration = previousSessions.isEmpty
            ? duration
            : previousSessions.map(\.duration).reduce(0, +) / Double(previousSessions.count)

        let score: Int
        if wordCount < 3 || duration < 3 {
            score = 1
        } else {
            let rawScore = 1.0 + (durationProgress * 3.2) + (contentProgress * 2.8) + (paceProgress * 2.0) - fillerPenalty + difficultyBonus
            score = max(1, min(10, Int(round(rawScore))))
        }

        let xpBase = Double(score * 8)
        let xpFromDuration = durationProgress * 18
        let xpEarned = max(5, Int(round((xpBase + xpFromDuration) * difficulty.xpMultiplier)))

        let headline: String
        switch score {
        case 9...10:
            headline = "Table-topics ready"
        case 7...8:
            headline = "Solid response"
        case 4...6:
            headline = "Getting there"
        default:
            headline = "Needs another rep"
        }

        let feedback: String
        if wordCount < 3 || duration < 3 {
            feedback = "This response ended before the answer could develop. Aim for a clear opening, one supporting point, and a brief close."
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
            PracticeScoreSegment(title: "Depth", value: "+\(Int(round(durationProgress * 3)))", tintName: "blue"),
            PracticeScoreSegment(title: "Content", value: "+\(Int(round(contentProgress * 3)))", tintName: "orange"),
            PracticeScoreSegment(title: "Pace", value: "+\(Int(round(paceProgress * 2)))", tintName: "green"),
            PracticeScoreSegment(title: "Filler penalty", value: "-\(Int(round(fillerPenalty)))", tintName: "red"),
            PracticeScoreSegment(title: "Difficulty", value: difficulty.title, tintName: "purple")
        ]

        var insights: [String] = []
        if previousSessions.isEmpty {
            insights.append("This is your first saved timed rep, so future summaries will compare against your baseline.")
        } else {
            if Double(fillerCount) < averageFillers {
                insights.append("You used fewer filler words than your recent average of \(Int(round(averageFillers))).")
            } else if Double(fillerCount) > averageFillers {
                insights.append("Filler words were above your recent average. Try a slower opening sentence.")
            }

            if duration > averageDuration {
                insights.append("You stayed with the answer longer than your recent average, which usually improves structure.")
            } else {
                insights.append("This answer ended earlier than your recent average. Push one idea further before stopping.")
            }
        }

        if wordsPerMinute < 80 && wordCount >= 8 {
            insights.append("Your pace was calm. Keep that control while expanding the middle of the answer.")
        } else if wordsPerMinute > 150 {
            insights.append("You were speaking quickly. Leave more space between points so the answer lands more cleanly.")
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
}

extension PracticeSession {
    var wordCount: Int {
        transcript.split { !$0.isLetter && !$0.isNumber }.count
    }
}

struct PracticeSessionDraft {
    let transcript: String
    let fillerWordCount: Int
    let duration: TimeInterval
    let date: Date
    let mode: PracticeMode
}

struct PracticeSessionAnnotation: Equatable {
    let score: Int?
    let xpEarned: Int?
    let headline: String?
    let insights: [String]
    let coachSummary: String?

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

    private let sessionsKey = "practiceSessions"

    private init() {
        sessions = Self.loadSessions(forKey: sessionsKey)
    }

    func reload() {
        sessions = Self.loadSessions(forKey: sessionsKey)
    }

    @discardableResult
    func append(_ draft: PracticeSessionDraft) -> PracticeSession {
        let session = PracticeSession(
            transcript: draft.transcript,
            fillerWordCount: draft.fillerWordCount,
            duration: draft.duration,
            date: draft.date,
            mode: draft.mode
        )
        sessions.insert(session, at: 0)
        persist()
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
        sessions[0] = latest
        persist()
    }

    func annotate(sessionID: UUID, annotation: PracticeSessionAnnotation) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].score = annotation.score
        sessions[index].xpEarned = annotation.xpEarned
        sessions[index].headline = annotation.headline
        sessions[index].insights = annotation.insights
        sessions[index].coachSummary = annotation.coachSummary
        persist()
    }

    func saveAIFeedback(sessionID: UUID, feedback: AICoachFeedback) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].aiCoachFeedback = feedback
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private static func loadSessions(forKey key: String) -> [PracticeSession] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let sessions = try? JSONDecoder().decode([PracticeSession].self, from: data) else { return [] }
        return sessions.sorted { $0.date > $1.date }
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
        let session = store.append(draft)
        if annotation != .empty {
            store.annotate(sessionID: session.id, annotation: annotation)
        }
        return store.sessions.first(where: { $0.id == session.id }) ?? session
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
}

enum CoachingPlanner {
    static func plan(for sessions: [PracticeSession], profile: CoachingProfile?) -> CoachingPlan? {
        guard !sessions.isEmpty else { return nil }
        let recent = Array(sessions.prefix(8))
        let averageFillers = Double(recent.map(\.fillerWordCount).reduce(0, +)) / Double(recent.count)
        let averageDuration = recent.map(\.duration).reduce(0, +) / Double(recent.count)
        let strongestMode = Dictionary(grouping: recent, by: \.mode).max { lhs, rhs in
            averageScore(for: lhs.value) < averageScore(for: rhs.value)
        }?.key

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
        } else if averageDuration < 20 {
            currentFocus = "Focus on expanding answers so each response has a clear middle section."
        } else {
            currentFocus = "Focus on maintaining structure while keeping your delivery relaxed."
        }

        let suggestedDrill: String
        if let profile {
            switch profile.primaryGoal {
            case .reduceFillers:
                suggestedDrill = "Timed Practice on Easy or Medium will help you slow the pace and protect cleaner transitions."
            case .moreConcise:
                suggestedDrill = "Timed Practice on Medium will encourage tighter openings and more disciplined structure."
            case .thinkFaster:
                suggestedDrill = "Timed Practice on Hard or Medium will help you organise thoughts quickly under pressure."
            case .calmerDelivery:
                suggestedDrill = "Ah-Counter and Easy Timed Practice will help you keep composure without forcing pace."
            }
        } else if averageFillers > 4 {
            suggestedDrill = "Timed Practice on Easy or Medium will give you room to slow the pace and clean up transitions."
        } else if averageDuration < 20 {
            suggestedDrill = "Timed Practice on Easy will help you develop fuller answers."
        } else if strongestMode == .suddenDeath {
            suggestedDrill = "Sudden Death is working well for you. Use it to keep the pressure high."
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

        return CoachingPlan(
            strongestMode: strongestMode,
            currentFocus: currentFocus,
            suggestedDrill: suggestedDrill,
            encouragement: [encouragement, outcomeNote].compactMap { $0 }.joined(separator: " "),
            hiddenBaseline: HiddenBaseline(
                averageFillers: averageFillers,
                averageDuration: averageDuration
            )
        )
    }

    static func sessionInsights(for session: PracticeSession, comparedTo sessions: [PracticeSession]) -> [String] {
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
        }
    }
}

struct AICoachSessionInput {
    let transcript: String
    let mode: PracticeMode
    let score: Int?
    let fillerCount: Int
    let duration: TimeInterval
}

protocol AICoachServicing {
    @MainActor
    func generateDeeperFeedback(
        input: AICoachSessionInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) async throws -> AICoachFeedback
}

@MainActor
struct AICoachService: AICoachServicing {
    private let settings = AISettingsManager.shared

    func generateDeeperFeedback(
        input: AICoachSessionInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) async throws -> AICoachFeedback {
        settings.resetIfNeeded()
        guard settings.provider != .none else { throw AICoachError.providerDisabled }
        guard input.transcript.split(whereSeparator: \.isWhitespace).count >= 20 else { throw AICoachError.transcriptTooShort }
        guard let apiKey = apiKey(for: settings.provider) else { throw AICoachError.missingAPIKey }
        guard let endpoint = settings.provider.endpoint else { throw AICoachError.providerDisabled }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = prompt(for: input, profile: profile, plan: plan)
        let body = OpenAICompatibleChatRequest(
            model: settings.provider.model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: prompt)
            ],
            temperature: 0.3,
            responseFormat: .jsonObject
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw AICoachError.invalidResponse
        }

        let completion = try JSONDecoder().decode(OpenAICompatibleChatResponse.self, from: data)
        guard let content = completion.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw AICoachError.invalidResponse
        }

        let feedback = try JSONDecoder().decode(AICoachFeedback.self, from: jsonData)
        await MainActor.run {
            settings.recordAnalysis()
        }
        return feedback
    }

    private var systemPrompt: String {
        """
        You are a supportive, professional speaking coach inspired by the tone of a thoughtful Toastmasters evaluator.
        Return JSON only with keys: strengths, keyImprovement, suggestedDrill, revisedOpening.
        Keep strengths to exactly 2 concise items.
        Keep keyImprovement to one paragraph.
        Keep suggestedDrill to one sentence.
        Keep revisedOpening to 1-2 sentences that improve the speaker's opening while preserving their likely intent.
        Avoid harsh language, therapy language, or overpraise.
        """
    }

    private func prompt(
        for input: AICoachSessionInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) -> String {
        """
        Session mode: \(input.mode.rawValue)
        Score: \(input.score.map(String.init) ?? "n/a") / 10
        Filler words: \(input.fillerCount)
        Duration seconds: \(Int(input.duration))
        Speaker context: \(profile?.speakingContext.title ?? "unknown")
        Speaker priority: \(profile?.primaryGoal.title ?? "unknown")
        Speaker challenge: \(profile?.biggestChallenge.title ?? "unknown")
        Desired outcome: \(profile?.desiredOutcome.title ?? "unknown")
        Coaching brief: \(profile?.coachingBrief ?? "none")
        Current focus suggestion: \(plan?.currentFocus ?? "none")
        Suggested drill: \(plan?.suggestedDrill ?? "none")

        Transcript:
        \(input.transcript)
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
