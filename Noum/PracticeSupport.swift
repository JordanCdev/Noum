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
    var speakingStyleGoal: SpeakingStyleGoal
    var styleReference: String
    var coachingBrief: String

    var isComplete: Bool { true }
    var personalGoalReference: String {
        let trimmedStyleReference = styleReference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedStyleReference.isEmpty {
            return trimmedStyleReference
        }

        return coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines)
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
    }

    init(
        speakingContext: SpeakingContext,
        primaryGoal: CoachingPriority,
        confidenceLevel: ConfidenceLevel,
        biggestChallenge: SpeakingChallenge,
        desiredOutcome: SpeakingOutcome,
        speakingStyleGoal: SpeakingStyleGoal,
        styleReference: String,
        coachingBrief: String
    ) {
        self.speakingContext = speakingContext
        self.primaryGoal = primaryGoal
        self.confidenceLevel = confidenceLevel
        self.biggestChallenge = biggestChallenge
        self.desiredOutcome = desiredOutcome
        self.speakingStyleGoal = speakingStyleGoal
        self.styleReference = styleReference
        self.coachingBrief = coachingBrief
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speakingContext = try container.decode(SpeakingContext.self, forKey: .speakingContext)
        primaryGoal = try container.decode(CoachingPriority.self, forKey: .primaryGoal)
        confidenceLevel = try container.decode(ConfidenceLevel.self, forKey: .confidenceLevel)
        biggestChallenge = try container.decode(SpeakingChallenge.self, forKey: .biggestChallenge)
        desiredOutcome = try container.decode(SpeakingOutcome.self, forKey: .desiredOutcome)
        speakingStyleGoal = try container.decodeIfPresent(SpeakingStyleGoal.self, forKey: .speakingStyleGoal) ?? .authoritative
        styleReference = try container.decodeIfPresent(String.self, forKey: .styleReference) ?? ""
        coachingBrief = try container.decodeIfPresent(String.self, forKey: .coachingBrief) ?? ""
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
        case .openAI: return "gpt-5-mini"
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
    @Published private(set) var shouldPresentInitialOnboarding = false

    private let accountKey = "NoumAccountID"
    private let profileKeyPrefix = "coachingProfile."
    private let onboardingCompletionKeyPrefix = "coachingProfileOnboardingComplete."

    private init() {
        reloadForCurrentAccount()
    }

    var needsOnboarding: Bool {
        profile == nil
    }

    func save(_ profile: CoachingProfile) {
        guard let accountID = currentAccountID else { return }
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey(for: accountID))
        }
        UserDefaults.standard.set(true, forKey: onboardingCompletionKey(for: accountID))
        shouldPresentInitialOnboarding = false
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

    private func profileKey(for accountID: String) -> String {
        "\(profileKeyPrefix)\(accountID)"
    }

    private func onboardingCompletionKey(for accountID: String) -> String {
        "\(onboardingCompletionKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
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

    @Published private(set) var analysisCountThisMonth: Int {
        didSet { UserDefaults.standard.set(analysisCountThisMonth, forKey: countKey) }
    }

    private let countKey = "aiMonthlyAnalysisCount"
    private let monthKey = "aiMonthlyAnalysisMonth"
    private let monthlyAnalysisLimit = 20

    private init() {
        analysisCountThisMonth = UserDefaults.standard.integer(forKey: countKey)
        resetIfNeeded()
    }

    var activeProvider: AIProvider? {
        [.gemini, .openAI, .deepSeek].first(where: hasAPIKey(for:))
    }

    var remainingAnalyses: Int {
        max(0, monthlyAnalysisLimit - analysisCountThisMonth)
    }

    var canRequestAnalysis: Bool {
        activeProvider != nil && remainingAnalyses > 0
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

    private func hasAPIKey(for provider: AIProvider) -> Bool {
        guard let keyName = provider.environmentKey else { return false }

        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return true
        }

        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig") != nil
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
        profile: CoachingProfile?
    ) -> PracticeEvaluation {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = wordCount(in: cleanTranscript)
        let targetDuration = Double(difficulty.duration ?? 45)
        let durationProgress = min(duration / targetDuration, 1.0)
        let contentProgress = min(Double(wordCount) / 35.0, 1.0)
        let wordsPerMinute = paceValue(wordCount: wordCount, duration: duration)
        let paceSnapshot = paceSnapshot(for: wordsPerMinute, wordCount: wordCount)
        let styleSnapshot = speakingIdentitySnapshot(for: cleanTranscript, profile: profile)
        let styleTrend = styleTrendSnapshot(transcript: cleanTranscript, recentSessions: recentSessions, profile: profile)
        let styleAlignment = styleAlignmentScore(snapshot: styleSnapshot, profile: profile)
        let paceProgress = paceScore(for: wordsPerMinute, wordCount: wordCount)
        let fillerPenalty = min(Double(fillerCount) * 0.7, 3.0)
        let difficultyBonus: Double = {
            switch difficulty {
            case .free: return 0.0
            case .easy: return 0.2
            case .medium: return 0.6
            case .hard: return 1.0
            }
        }()

        let trends = trendSnapshot(fillerCount: fillerCount, duration: duration, recentSessions: recentSessions)

        let score: Int
        if wordCount < 3 || duration < 3 {
            score = 1
        } else {
            let rawScore = 1.0 + (durationProgress * 3.2) + (contentProgress * 2.8) + (paceProgress * 2.0) + (styleAlignment * 1.5) - fillerPenalty + difficultyBonus
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
            paceSnapshot: paceSnapshot
        )
        insights.append(styleAlignmentInsight(styleSnapshot: styleSnapshot, profile: profile, alignment: styleAlignment))
        if let styleTrendNote = styleTrendInsight(styleTrend, profile: profile) {
            insights.append(styleTrendNote)
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

    static func evaluateSuddenDeathPractice(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        pressureEventsHandled: Int,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?
    ) -> PracticeEvaluation {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = wordCount(in: cleanTranscript)
        let wordsPerMinute = paceValue(wordCount: wordCount, duration: duration)
        let paceSnapshot = paceSnapshot(for: wordsPerMinute, wordCount: wordCount)
        let styleSnapshot = speakingIdentitySnapshot(for: cleanTranscript, profile: profile)
        let styleTrend = styleTrendSnapshot(transcript: cleanTranscript, recentSessions: recentSessions, profile: profile)
        let styleAlignment = styleAlignmentScore(snapshot: styleSnapshot, profile: profile)
        let level = max(1, Int(duration / 30.0) + 1)
        let durationProgress = min(duration / Double(level * 30), 1.0)
        let contentProgress = min(Double(wordCount) / 24.0, 1.0)
        let paceProgress = paceScore(for: wordsPerMinute, wordCount: wordCount)
        let fillerPenalty = min(Double(fillerCount) * 2.0, 6.0)
        let trends = trendSnapshot(fillerCount: fillerCount, duration: duration, recentSessions: recentSessions)

        let score: Int
        if wordCount < 3 || duration < 3 {
            score = 1
        } else if wordCount < 8 || duration < 8 {
            score = max(2, min(4, Int(round(2.5 + contentProgress + durationProgress - fillerPenalty))))
        } else {
            let pressureBonus = min(Double(level - 1) * 0.8, 3.2)
            let eventBonus = min(Double(pressureEventsHandled) * 0.35, 1.4)
            let rawScore = 2.0 + (durationProgress * 2.4) + (contentProgress * 2.5) + (paceProgress * 1.2) + (styleAlignment * 1.4) - fillerPenalty + (fillerCount == 0 ? 2.0 : 0.0) + pressureBonus + eventBonus
            score = max(1, min(10, Int(round(rawScore))))
        }

        let xpEarned = max(5, Int(round(Double(score * 9) + (duration / 6.0) + Double(level - 1) * 18.0 + Double(pressureEventsHandled * 8))))
        let headline: String
        switch score {
        case 9...10:
            headline = level >= 3 ? "High-pressure composure" : "Composed under pressure"
        case 6...8:
            headline = "Pressure exposed a few cracks"
        default:
            headline = "Needs another rep"
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
        profile: CoachingProfile?
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
        let paceProgress = paceScore(for: wordsPerMinute, wordCount: wordCount)
        let fillerPenalty = min(Double(fillerCount) * 0.8, 5.0)
        let trends = trendSnapshot(fillerCount: fillerCount, duration: duration, recentSessions: recentSessions)

        let score: Int
        if wordCount < 4 || duration < 4 {
            score = 1
        } else {
            let rawScore = 2.0 + (durationProgress * 2.5) + (contentProgress * 2.0) + (paceProgress * 1.5) + (styleAlignment * 1.6) + max(0, 3.0 - fillerPenalty)
            score = max(1, min(10, Int(round(rawScore))))
        }

        let xpEarned = max(5, Int(round(Double(score * 7) + (durationProgress * 14))))
        let headline: String
        switch score {
        case 8...10: headline = "Good awareness"
        case 5...7: headline = "Useful awareness rep"
        default: headline = "Needs another rep"
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

    private static func timedModeInsights(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        wordsPerMinute: Double,
        trends: TrendSnapshot,
        paceSnapshot: PaceSnapshot
    ) -> [String] {
        var insights = sharedTrendInsights(trends: trends)
        if wordCount < 8 || duration < 8 {
            insights.append("This answer still needs more development before it will sound complete in a real conversation.")
        }
        insights.append("Pace check: \(paceSnapshot.wordsPerMinute) WPM. \(paceSnapshot.coachNote)")
        if fillerCount > 4 {
            insights.append("Too much processing is happening out loud. Replace the next filler with a short pause.")
        }
        return insights
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

    private static func paceScore(for wordsPerMinute: Double, wordCount: Int) -> Double {
        guard wordCount >= 6 else { return 0.15 }
        switch wordsPerMinute {
        case ..<70: return 0.35
        case 70..<95: return 0.72
        case 95..<145: return 1.0
        case 145..<170: return 0.72
        default: return 0.35
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
            return PaceSnapshot(wordsPerMinute: rounded, label: "Too slow", coachNote: "Your pace is very measured. Bring a little more forward energy so the answer feels more alive.")
        case 70..<95:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Measured", coachNote: "Your pace is controlled and calm. Keep that composure while sharpening the structure.")
        case 95..<145:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Strong", coachNote: "Your pace is in a strong range for clear, confident speech.")
        case 145..<170:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Quick", coachNote: "Your pace is edging fast. Create a little more space between points so authority can come through.")
        default:
            return PaceSnapshot(wordsPerMinute: rounded, label: "Rushed", coachNote: "Your pace is rushing the message. Slow the opening and finish each sentence before moving on.")
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
                suggestedDrill = "Use Sudden Death and Medium Timed Practice to strengthen firmer openings, cleaner pauses, and more decisive language."
            case (_, .executive):
                suggestedDrill = "Use Medium Timed Practice and Sudden Death to rehearse steadier pacing, shorter openings, and boardroom-style control."
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
    static let minimumTranscriptWordCount = 10

    private let settings = AISettingsManager.shared

    func generateDeeperFeedback(
        input: AICoachSessionInput,
        profile: CoachingProfile?,
        plan: CoachingPlan?
    ) async throws -> AICoachFeedback {
        settings.resetIfNeeded()
        guard input.transcript.split(whereSeparator: \.isWhitespace).count >= Self.minimumTranscriptWordCount else {
            throw AICoachError.transcriptTooShort
        }
        guard let provider = settings.activeProvider else { throw AICoachError.missingAPIKey }
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
                temperature: 0.3,
                responseFormat: .jsonObject
            )
            request.httpBody = try JSONEncoder().encode(body)
        case .gemini:
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let body = GeminiGenerateContentRequest(
                systemInstruction: .init(parts: [.init(text: systemPrompt)]),
                contents: [.init(parts: [.init(text: prompt)])],
                generationConfig: .init(
                    temperature: 0.3,
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

        let feedback = try JSONDecoder().decode(AICoachFeedback.self, from: jsonData)
        await MainActor.run {
            settings.recordAnalysis()
        }
        return feedback
    }

    private var systemPrompt: String {
        """
        You are a supportive, professional speaking coach inspired by the tone of a thoughtful Toastmasters evaluator.
        Coach toward the speaker's desired voice and presence, not just generic clarity.
        Return JSON only with keys: strengths, keyImprovement, suggestedDrill, revisedOpening.
        Keep strengths to exactly 2 concise items.
        Keep keyImprovement to one paragraph.
        Keep suggestedDrill to one sentence.
        Keep revisedOpening to 1-2 sentences that improve the speaker's opening while preserving their likely intent and moving it toward the requested voice.
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
        Words per minute: \(input.wordsPerMinute)
        Current speaking identity: \(input.speakingIdentity)
        Speaker context: \(profile?.speakingContext.title ?? "unknown")
        Speaker priority: \(profile?.primaryGoal.title ?? "unknown")
        Speaker challenge: \(profile?.biggestChallenge.title ?? "unknown")
        Desired outcome: \(profile?.desiredOutcome.title ?? "unknown")
        Target speaking style: \(profile?.speakingStyleGoal.title ?? "unknown")
        Personal goal reference: \(profile?.personalGoalReference ?? "none")
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
