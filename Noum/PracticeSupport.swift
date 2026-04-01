import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFAudio)
import AVFAudio
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
}

struct IMConversationReply: Codable, Equatable {
    let message: String
    let shouldWrapUp: Bool
    let updatedState: IMConversationState
}

private struct BackendIMConversationReplyRequest: Codable {
    let setup: IMConversationSetup
    let turns: [IMConversationTurn]
    let state: IMConversationState
    let profile: CoachingProfile?
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
        let total = toneMatch + clarityScore + composureScore + vocabularyScore + conversationScore
        return max(1, min(10, Int(round(Double(total) / 5.0))))
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

private struct BackendIMConversationEvaluationRequest: Codable {
    let setup: IMConversationSetup
    let turns: [IMConversationTurn]
    let finalState: IMConversationState?
    let transcript: String
    let fillerCount: Int
    let duration: TimeInterval
    let recentSessions: [PracticeSession]
    let profile: CoachingProfile?

    enum CodingKeys: String, CodingKey {
        case setup
        case turns
        case finalState = "final_state"
        case transcript
        case fillerCount = "filler_count"
        case duration
        case recentSessions = "recent_sessions"
        case profile
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

protocol IMConversationServicing {
    @MainActor
    func generateReply(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        state: IMConversationState,
        profile: CoachingProfile?
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
        profile: CoachingProfile?
    ) async throws -> IMConversationEvaluation
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
    private let providerKey = "NoumAccountProvider"
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
        syncProfileIfPossible(profile, accountID: accountID)
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

    @Published private(set) var lastResolvedEngineTitle: String = "None"
    @Published private(set) var lastPlaybackStatus: String = "Idle"
    @Published private(set) var lastPlaybackError: String?

    private let engineKey = "imVoicePlaybackEngine"
    private let playbackEnabledKey = "imVoicePlaybackEnabled"

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

enum IMVoiceEngine: String, CaseIterable, Codable, Identifiable {
    case auto
    case backend
    case googleCloud
    case elevenLabs
    case openAI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .backend:
            return "Backend"
        case .googleCloud:
            return "Google Cloud"
        case .elevenLabs:
            return "ElevenLabs"
        case .openAI:
            return "AI"
        }
    }

    var subtitle: String {
        switch self {
        case .auto:
            return "Prefer Google Cloud, then ElevenLabs, then OpenAI, then backend voice."
        case .backend:
            return "Use Noum backend voice synthesis first, with provider secrets kept off the device."
        case .googleCloud:
            return "Use Google Cloud Text-to-Speech when an API key or access token is configured."
        case .elevenLabs:
            return "Use ElevenLabs voice synthesis when API keys and voice IDs are configured."
        case .openAI:
            return "Force OpenAI TTS for the most natural NPC replies."
        }
    }
}

#if canImport(AVFAudio)
@MainActor
final class IMMessageSpeaker: NSObject, ObservableObject {
    static let shared = IMMessageSpeaker()

    private let playbackSettings = IMVoicePlaybackSettingsManager.shared
    private var audioPlayer: AVAudioPlayer?
    private var speechTask: Task<Void, Never>?
    private var lastFailureReason: String?

    override private init() {
        super.init()
    }

    func speak(_ text: String, setup: IMConversationSetup) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        speechTask = Task { [weak self] in
            guard let self else { return }
            guard let selectedEngine = resolvedEngine(for: setup) else {
                playbackSettings.recordPlaybackFailure(
                    resolvedEngine: .auto,
                    reason: "No cloud voice provider is configured."
                )
                return
            }
            playbackSettings.recordPlaybackAttempt(resolvedEngine: selectedEngine)
            if selectedEngine == .backend,
               await playWithBackend(trimmed, setup: setup) {
                playbackSettings.recordPlaybackSuccess(resolvedEngine: selectedEngine)
                return
            }
            if selectedEngine == .googleCloud,
               await playWithGoogleCloud(trimmed, setup: setup) {
                playbackSettings.recordPlaybackSuccess(resolvedEngine: selectedEngine)
                return
            }
            if selectedEngine == .elevenLabs,
               await playWithElevenLabs(trimmed, setup: setup) {
                playbackSettings.recordPlaybackSuccess(resolvedEngine: selectedEngine)
                return
            }
            if selectedEngine == .openAI,
               await playWithOpenAI(trimmed, setup: setup) {
                playbackSettings.recordPlaybackSuccess(resolvedEngine: selectedEngine)
                return
            }
            playbackSettings.recordPlaybackFailure(
                resolvedEngine: selectedEngine,
                reason: lastFailureReason ?? "Provider playback did not return playable audio."
            )
        }
    }

    func stop() {
        speechTask?.cancel()
        speechTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func resolvedEngine(for setup: IMConversationSetup) -> IMVoiceEngine? {
        switch playbackSettings.engine {
        case .auto:
            if googleCloudAccessToken() != nil {
                return .googleCloud
            }
            if googleCloudAPIKey() != nil {
                return .googleCloud
            }
            if elevenLabsAPIKey() != nil, elevenLabsVoiceID(for: setup.scenario) != nil {
                return .elevenLabs
            }
            if openAIAPIKey() != nil {
                return .openAI
            }
            if backendTTSAvailable() {
                return .backend
            }
            return nil
        case .backend:
            return .backend
        case .googleCloud:
            return .googleCloud
        case .elevenLabs:
            return .elevenLabs
        case .openAI:
            return .openAI
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

    private func playWithBackend(_ text: String, setup: IMConversationSetup) async -> Bool {
        guard let baseURL = backendBaseURL() else { return false }
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

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                lastFailureReason = "Backend TTS request failed."
                return false
            }

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
            return playAudioData(audioData)
        } catch {
            lastFailureReason = "Backend TTS error: \(error.localizedDescription)"
            return false
        }
    }

    private func playAudioData(_ data: Data) -> Bool {
        do {
            #if canImport(AVFoundation)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
            #endif
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            audioPlayer = player
            player.play()
            lastFailureReason = nil
            return true
        } catch {
            lastFailureReason = "Audio playback error: \(error.localizedDescription)"
            return false
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

    private func playWithGoogleCloud(_ text: String, setup: IMConversationSetup) async -> Bool {
        guard var components = URLComponents(string: "https://texttospeech.googleapis.com/v1/text:synthesize") else {
            return false
        }

        let accessToken = googleCloudAccessToken()
        let apiKey = googleCloudAPIKey()
        guard accessToken != nil || apiKey != nil else {
            lastFailureReason = "Google Cloud TTS key or access token is missing."
            return false
        }

        if let apiKey {
            components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }

        guard let endpoint = components.url else {
            return false
        }

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

        do {
            request.httpBody = try JSONEncoder().encode(body)
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

    private func playWithOpenAI(_ text: String, setup: IMConversationSetup) async -> Bool {
        guard let apiKey = openAIAPIKey(),
              let endpoint = URL(string: "https://api.openai.com/v1/audio/speech") else {
            lastFailureReason = "OpenAI TTS credentials are missing."
            return false
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OpenAITTSSpeechRequest(
            model: "gpt-4o-mini-tts",
            voice: preferredOpenAIVoice(for: setup),
            input: text,
            responseFormat: "wav",
            instructions: openAIInstructions(for: setup)
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                lastFailureReason = "OpenAI TTS request failed."
                return false
            }

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

    private func elevenLabsAPIKey() -> String? {
        if let value = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: "ELEVENLABS_API_KEY", plistNamed: "AIConfig")
    }

    private func elevenLabsModelID() -> String {
        ProcessInfo.processInfo.environment["ELEVENLABS_MODEL_ID"]
            ?? LocalConfigLoader.value(forKey: "ELEVENLABS_MODEL_ID", plistNamed: "AIConfig")
            ?? "eleven_multilingual_v2"
    }

    private func elevenLabsVoiceID(for scenario: IMConversationScenario) -> String? {
        let scenarioKey: String
        switch scenario {
        case .socialCatchUp:
            scenarioKey = "ELEVENLABS_VOICE_ID_MAYA"
        case .workUpdate:
            scenarioKey = "ELEVENLABS_VOICE_ID_JORDAN"
        case .difficultConversation:
            scenarioKey = "ELEVENLABS_VOICE_ID_SAM"
        case .networking:
            scenarioKey = "ELEVENLABS_VOICE_ID_ALEX"
        }

        if let value = ProcessInfo.processInfo.environment[scenarioKey], !value.isEmpty {
            return value
        }
        if let value = LocalConfigLoader.value(forKey: scenarioKey, plistNamed: "AIConfig") {
            return value
        }
        if let value = ProcessInfo.processInfo.environment["ELEVENLABS_VOICE_ID_DEFAULT"], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: "ELEVENLABS_VOICE_ID_DEFAULT", plistNamed: "AIConfig")
    }

    private func playWithElevenLabs(_ text: String, setup: IMConversationSetup) async -> Bool {
        guard let apiKey = elevenLabsAPIKey(),
              let voiceID = elevenLabsVoiceID(for: setup.scenario),
              let endpoint = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else {
            lastFailureReason = "ElevenLabs credentials or voice ID are missing."
            return false
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body = ElevenLabsSpeechRequest(
            text: text,
            modelID: elevenLabsModelID(),
            voiceSettings: ElevenLabsVoiceSettings(
                stability: 0.48,
                similarityBoost: 0.78,
                style: 0.22,
                useSpeakerBoost: true,
                speed: 0.96
            )
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                lastFailureReason = "ElevenLabs request failed."
                return false
            }

            return playAudioData(data)
        } catch {
            lastFailureReason = "ElevenLabs error: \(error.localizedDescription)"
            return false
        }
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

private struct ElevenLabsSpeechRequest: Codable {
    let text: String
    let modelID: String
    let voiceSettings: ElevenLabsVoiceSettings

    enum CodingKeys: String, CodingKey {
        case text
        case modelID = "model_id"
        case voiceSettings = "voice_settings"
    }
}

private struct ElevenLabsVoiceSettings: Codable {
    let stability: Double
    let similarityBoost: Double
    let style: Double
    let useSpeakerBoost: Bool
    let speed: Double

    enum CodingKeys: String, CodingKey {
        case stability
        case similarityBoost = "similarity_boost"
        case style
        case useSpeakerBoost = "use_speaker_boost"
        case speed
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
    let imDetails: IMConversationDetails?

    init(
        transcript: String,
        fillerWordCount: Int,
        duration: TimeInterval,
        date: Date,
        mode: PracticeMode,
        imDetails: IMConversationDetails? = nil
    ) {
        self.transcript = transcript
        self.fillerWordCount = fillerWordCount
        self.duration = duration
        self.date = date
        self.mode = mode
        self.imDetails = imDetails
    }
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

    private let accountKey = "NoumAccountID"
    private let providerKey = "NoumAccountProvider"

    private init() {
        sessions = Self.loadSessions(forKey: Self.storageKey(for: KeychainHelper.load(key: "NoumAccountID")))
    }

    func reload() {
        sessions = Self.loadSessions(forKey: Self.storageKey(for: currentAccountID))
    }

    func reloadForCurrentAccount() {
        reload()
    }

    func endSession() {
        sessions = []
    }

    @discardableResult
    func append(_ draft: PracticeSessionDraft) -> PracticeSession {
        let session = PracticeSession(
            transcript: draft.transcript,
            fillerWordCount: draft.fillerWordCount,
            duration: draft.duration,
            date: draft.date,
            mode: draft.mode,
            imConversationDetails: draft.imDetails
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
    let mode: PracticeMode
    let sessionID: UUID
    let followed: Bool
    let completedAt: Date
    let scoreDelta: Double
    let fillerDelta: Double
    let durationDelta: Double
}

@MainActor
final class RecommendationLearningStore: ObservableObject {
    static let shared = RecommendationLearningStore()

    @Published private(set) var pendingExposure: RecommendationExposure?
    @Published private(set) var outcomes: [RecommendationOutcome]

    private let accountKey = "NoumAccountID"
    private let providerKey = "NoumAccountProvider"

    private init() {
        let accountID = KeychainHelper.load(key: "NoumAccountID")
        pendingExposure = Self.loadPending(forKey: Self.pendingKey(for: accountID))
        outcomes = Self.loadOutcomes(forKey: Self.outcomesKey(for: accountID))
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
        let averageScore = relevantHistory.compactMap(\.score).isEmpty
            ? Double(session.score ?? 0)
            : Double(relevantHistory.compactMap(\.score).reduce(0, +)) / Double(relevantHistory.compactMap(\.score).count)
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
            mode: pendingExposure.mode,
            sessionID: session.id,
            followed: pendingExposure.mode == session.mode,
            completedAt: Date(),
            scoreDelta: Double(session.score ?? 0) - averageScore,
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

struct AIHomeRecommendation: Codable, Equatable {
    let title: String
    let detail: String
    let focus: String
    let target: String
    let recommendedMode: String
    let whyMode: String
    let whyNow: String
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
        profile: CoachingProfile?
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
                profile: profile
            ) {
                return backendReply
            }
            throw IMModeServiceError.unavailable
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = prompt(for: setup, turns: turns, state: state, profile: profile)
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
            let decoded = try JSONDecoder().decode(IMConversationReply.self, from: jsonData)
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
                profile: profile
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
        profile: CoachingProfile?
    ) async throws -> IMConversationReply? {
        guard var request = backendRequest(path: "/v1/im/reply") else { return nil }
        let body = BackendIMConversationReplyRequest(
            setup: setup,
            turns: turns,
            state: state,
            profile: profile
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
        """
    }

    private func prompt(
        for setup: IMConversationSetup,
        turns: [IMConversationTurn],
        state: IMConversationState,
        profile: CoachingProfile?
    ) -> String {
        let userTurnCount = turns.filter { $0.speaker == .user }.count
        let lastUserMessage = turns.last(where: { $0.speaker == .user })?.text ?? "none yet"
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
        User target tone: \(setup.targetTone.title)
        User tone goal: \(setup.targetTone.coachingPrompt)
        Speaker context: \(profile?.speakingContext.title ?? "unknown")
        Biggest challenge: \(profile?.biggestChallenge.title ?? "unknown")
        Desired style: \(profile?.speakingStyleGoal.title ?? "unknown")
        Conversation phase: \(conversationPhase)
        User turn count: \(userTurnCount)
        Latest user message: \(lastUserMessage)
        Current trust: \(state.normalizedTrust)/10
        Current engagement: \(state.normalizedEngagement)/10
        Current tension: \(state.normalizedTension)/10
        Current beat: \(state.beat)
        Escalation instruction: \(escalationInstruction)
        Keep the conversation realistic and brief.
        React to what the user actually said. Do not sound generic.
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
        profile: CoachingProfile?
    ) async throws -> IMConversationEvaluation {
        guard IMModeAvailability.isAvailable else {
            throw IMModeServiceError.unavailable
        }

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
                profile: profile
            ) {
                return backendEvaluation
            }
            throw IMModeServiceError.unavailable
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
            profile: profile
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
                throw IMModeServiceError.evaluationFailed("HTTP request failed")
            }

            let jsonData = try extractJSONData(from: data, provider: provider)
            return try JSONDecoder().decode(IMConversationEvaluation.self, from: jsonData)
        } catch {
            if let backendEvaluation = try? await backendEvaluation(
                setup: setup,
                turns: turns,
                finalState: finalState,
                transcript: transcript,
                fillerCount: fillerCount,
                duration: duration,
                recentSessions: recentSessions,
                profile: profile
            ) {
                return backendEvaluation
            }
            throw IMModeServiceError.evaluationFailed(error.localizedDescription)
        }
    }

    private func backendEvaluation(
        setup: IMConversationSetup,
        turns: [IMConversationTurn],
        finalState: IMConversationState?,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        recentSessions: [PracticeSession],
        profile: CoachingProfile?
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
            profile: profile
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
        You are evaluating a short voice-driven instant message conversation for a speaking coach app.
        Return JSON only with keys:
        actualTone, toneMatch, clarityScore, composureScore, vocabularyScore, conversationScore, headline, feedback, insights, suggestedDrill.
        Scoring rules:
        - all numeric scores are integers from 1 to 10
        - insights must contain exactly 3 concise strings
        - headline must be short
        - feedback should be 2-4 sentences, practical and coach-like
        - actualTone should describe how the speaker actually came across
        - judge target tone vs actual tone, conversational relevance, clarity, pacing signals, vocabulary, and composure
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
        profile: CoachingProfile?
    ) -> String {
        let pace = PracticeEvaluator.paceSnapshot(forTranscript: transcript, duration: duration)
        let identity = PracticeEvaluator.speakingIdentity(for: transcript, profile: profile)
        let recentAverageFillers = recentSessions.isEmpty ? 0 : Double(recentSessions.map(\.fillerWordCount).reduce(0, +)) / Double(recentSessions.count)
        let recentAverageDuration = recentSessions.isEmpty ? 0 : recentSessions.map(\.duration).reduce(0, +) / Double(recentSessions.count)
        let transcriptLog = turns.map { turn in
            let speaker = turn.speaker == .user ? "User" : setup.scenario.personaName
            return "\(speaker): \(turn.text)"
        }.joined(separator: "\n")

        return """
        Scenario: \(setup.scenario.title)
        Target tone: \(setup.targetTone.title)
        Tone goal: \(setup.targetTone.coachingPrompt)
        Scenario coaching focus: \(setup.scenario.coachingFocus)
        Final trust: \(finalState?.normalizedTrust ?? 5)/10
        Final engagement: \(finalState?.normalizedEngagement ?? 5)/10
        Final tension: \(finalState?.normalizedTension ?? 4)/10
        Final conversation beat: \(finalState?.beat ?? "Not captured")
        Speaker context: \(profile?.speakingContext.title ?? "unknown")
        Biggest challenge: \(profile?.biggestChallenge.title ?? "unknown")
        Desired style: \(profile?.speakingStyleGoal.title ?? "unknown")
        Filler words: \(fillerCount)
        Duration seconds: \(Int(duration))
        Words per minute: \(pace.wordsPerMinute)
        Pace label: \(pace.label)
        Speaking identity: \(identity.identity)
        Identity evidence: \(identity.evidence)
        Recent average fillers: \(String(format: "%.1f", recentAverageFillers))
        Recent average duration: \(Int(recentAverageDuration))

        Full conversation:
        \(transcriptLog)

        Combined user transcript:
        \(transcript)

        Evaluate not only speaking delivery but conversational quality:
        - directness
        - relevance to the other person
        - tone consistency
        - recovery after awkward or pressured moments
        - whether the user actually moved the conversation forward
        - whether trust/engagement improved or tension escalated appropriately
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
        let lower = transcript.lowercased()
        switch tone {
        case .confident:
            return lower.contains("i think") ? 6 : 8
        case .warm:
            return lower.contains("thanks") || lower.contains("love") || lower.contains("glad") ? 8 : 6
        case .concise:
            return transcript.split(separator: " ").count < 45 ? 8 : 6
        case .assertive:
            return lower.contains("i need") || lower.contains("i want") ? 8 : 6
        case .calm:
            return lower.contains("just") || lower.contains("sorry") ? 6 : 8
        case .professional:
            return lower.contains("like") || lower.contains("literally") ? 6 : 8
        }
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
        settings.recordAnalysis()
        return recommendation
    }

    private var systemPrompt: String {
        """
        You are the intelligence behind a premium communication coaching app.
        Recommend the single best next speaking drill for the user based on recent performance.
        Be specific, coach-like, and adaptive. Do not sound generic.
        Return JSON only with keys: title, detail, focus, target, recommendedMode, whyMode, whyNow.
        recommendedMode must be one of: timed, suddenDeath, ahCounter.
        title should be short and action-oriented.
        detail should explain the reasoning in one sentence.
        focus should be a short coaching label.
        target should be a concise measurable target like '30s+' or 'Zero fillers' or '<150 WPM'.
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
