#if DEBUG

import Foundation

/// Persistence-realistic mixed history for rendered Review/Profile integrity.
///
/// The three newer rows are deliberately saved and scored but fail the shared
/// three-word / three-second progress boundary. They must remain available in
/// All Reps without becoming coaching depth, a chart point, a best rep, or the
/// Review root's "latest" destination. Non-finite and evaluation-only rows
/// stay in unit tests because neither can exist as durable user history.
enum ReviewProgressEligibilityUITestFixture {
    static let launchArgument = "UI_TESTING_REVIEW_PROGRESS_ELIGIBILITY_FIXTURE"

    static let eligibleLatestID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    static let eligibleEarlierID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    static let tooFewWordsID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    static let tooShortDurationID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
    static let combinedThinID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!

    static let eligibleLatestPrompt = "Which decision should the team make next?"
    static let tooFewWordsPrompt = "Which saved short transcript should stay inspectable?"

    static func requested(arguments: [String]) -> Bool {
        arguments.contains("UI_TESTING") && arguments.contains(launchArgument)
    }

    static func sessions(now: Date = Date()) -> [PracticeSession] {
        [
            PracticeSession(
                id: tooFewWordsID,
                transcript: "Clear answer",
                fillerWordCount: 0,
                duration: 24,
                date: now.addingTimeInterval(-60),
                mode: .timed,
                score: 10,
                headline: "Two-word capture",
                prompt: tooFewWordsPrompt,
                transcriptConfidence: 0.98,
                transcriptionProvider: "local"
            ),
            PracticeSession(
                id: tooShortDurationID,
                transcript: "This complete answer has enough words but ends before three seconds.",
                fillerWordCount: 0,
                duration: 2.5,
                date: now.addingTimeInterval(-120),
                mode: .timed,
                score: 9,
                headline: "Sub-three-second capture",
                prompt: "Which saved short duration should stay inspectable?",
                transcriptConfidence: 0.98,
                transcriptionProvider: "local"
            ),
            PracticeSession(
                id: combinedThinID,
                transcript: "Brief reply",
                fillerWordCount: 0,
                duration: 2,
                date: now.addingTimeInterval(-180),
                mode: .timed,
                score: 8,
                headline: "Thin capture",
                prompt: "Which combined thin capture should stay inspectable?",
                transcriptConfidence: 0.98,
                transcriptionProvider: "local"
            ),
            PracticeSession(
                id: eligibleLatestID,
                transcript: "I led with the decision, explained the tradeoff in one clear reason, and closed by naming the owner and the next concrete step.",
                fillerWordCount: 0,
                duration: 30,
                date: now.addingTimeInterval(-3_600),
                mode: .timed,
                score: 7,
                headline: "Eligible latest rep",
                prompt: eligibleLatestPrompt,
                transcriptConfidence: 0.98,
                transcriptionProvider: "local"
            ),
            PracticeSession(
                id: eligibleEarlierID,
                transcript: "I paused before answering, stated the recommendation plainly, explained why it mattered, and finished by confirming the next concrete step with the team.",
                fillerWordCount: 1,
                duration: 36,
                date: now.addingTimeInterval(-86_400),
                mode: .timed,
                score: 6,
                headline: "Eligible earlier rep",
                prompt: "How should the team communicate the next step?",
                transcriptConfidence: 0.98,
                transcriptionProvider: "local"
            ),
        ]
    }

    @MainActor
    static func installIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        now: Date = Date()
    ) {
        guard requested(arguments: arguments) else { return }

        let rawSessions = sessions(now: now)
        let profile = DevSeedData.seedCoachingProfile(for: .beginner)

        // Reuse the real account-scoped owners. Raw sessions are installed in
        // the history store; every coaching owner must enforce its own shared
        // eligibility projection from that same source.
        PracticeSessionStore.shared.replaceAllForDebug(rawSessions)
        CoachingProfileStore.shared.replaceForDebug(profile)
        SkillTrendStore.shared.replaceForDebug([])
        ProfileManager.shared.replaceFromRemote(0)
        SuddenDeathRunHistoryStore.shared.replaceForDebug([])
        if #available(iOS 17.0, macOS 12.0, *) {
            ClutchWordStore.shared.resetForDebug()
        }
        BaselineStore.shared.rebuild(from: rawSessions)
        RatingStore.shared.replaceForDebug(.initial)
        FlowEventLog.shared.reset()
        SessionReflectionStore.shared.replaceForDebug([])
        CoachCheckInStore.shared.replaceForDebug([])
        BigMomentStore.shared.replaceForDebug(activeMoment: nil, outcomeReports: [])
        ForwardPlanStore.shared.clearPlan()
        _ = RecommendationLearningStore.shared.replaceFromRemote(
            pendingExposure: nil,
            outcomes: []
        )
        if #available(iOS 17.0, macOS 12.0, *) {
            ProofMomentStore.shared.replaceForDebug([])
        }

        CoachMemoryStore.shared.clearAll()
        CoachMemoryStore.shared.refresh(
            profile: profile,
            baseline: BaselineStore.shared.baseline,
            // Match the production finalizer call site: durable coach memory
            // receives the shared eligible projection, never raw history.
            sessions: PracticeProgressEligibility.eligibleSessions(in: rawSessions),
            trends: [],
            forwardPlan: nil,
            lastSessionID: eligibleLatestID
        )
    }
}

#endif
