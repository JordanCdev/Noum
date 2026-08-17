import Foundation
import Testing
@testable import Noum

@Suite("Path unlock celebration integrity")
struct PathUnlockCelebrationIntegrityTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func session(
        id: UUID = UUID(),
        words: Int = 20,
        duration: TimeInterval = 20,
        mode: PracticeMode = .timed,
        score: Int? = 5,
        dayOffset: Int = 0,
        date: Date? = nil,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: Array(repeating: "word", count: words).joined(separator: " "),
            fillerWordCount: 0,
            duration: duration,
            date: date ?? Calendar.current.date(byAdding: .day, value: dayOffset, to: now) ?? now,
            mode: mode,
            score: score,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func input(_ sessions: [PracticeSession]) -> PathProgressInput {
        PathProgressInput(
            sessions: sessions,
            currentStreak: 0,
            baseline: .empty,
            rating: .initial,
            modeMastery: [:],
            totalLessonPasses: 0,
            maxLessonPassCount: 0,
            now: now
        )
    }

    @Test("Only finalized, non-fixture reps advance general Path criteria")
    func progressEligibilityMatrix() {
        let eligible = session()
        let tooShort = session(duration: 2.99)
        let tooFewWords = session(words: 2)
        let fixture = session(isEvaluationFixture: true)
        let progress = input([eligible, tooShort, tooFewWords, fixture])

        #expect(progress.sessionCount == 1)
        #expect(PathNodeCriterion.sessionCountAtLeast(2).progress(for: progress) == 0.5)
        #expect(PathNodeCriterion.modeSessionAtLeast(.timed, 2).progress(for: progress) == 0.5)
        #expect(PathNodeCriterion.scoreAtLeast(6).progress(for: progress) == Double(5) / 6)
        #expect(progress.distinctPracticeDayCount == 1)
    }

    @Test("The progress floor rejects invalid duration without hiding valid short reps")
    func sharedProgressFloor() {
        #expect(PracticeProgressEligibility.qualifies(wordCount: 3, duration: 3))
        #expect(!PracticeProgressEligibility.qualifies(wordCount: 2, duration: 3))
        #expect(!PracticeProgressEligibility.qualifies(wordCount: 3, duration: 2.99))
        #expect(!PracticeProgressEligibility.qualifies(wordCount: 20, duration: .infinity))
        #expect(!PracticeProgressEligibility.qualifies(wordCount: 20, duration: 20, isEvaluationFixture: true))
    }

    @Test("Progress history keeps only rows that can honestly earn effects")
    func progressHistoryProjection() {
        let eligible = session(id: UUID(), words: 3, duration: 3)
        let tooFewWords = session(id: UUID(), words: 2, duration: 30)
        let tooShort = session(id: UUID(), words: 20, duration: 2.99)
        let invalidDuration = session(id: UUID(), words: 20, duration: .infinity)
        let fixture = session(id: UUID(), words: 20, duration: 30, isEvaluationFixture: true)

        let projected = PracticeProgressEligibility.eligibleSessions(
            in: [tooFewWords, tooShort, invalidDuration, fixture, eligible]
        )

        #expect(projected.map(\.id) == [eligible.id])
    }

    @Test("Profile evidence remains cold when saved rows are Review-only")
    func profileEvidenceUsesProgressProjection() {
        let reviewOnly = [
            session(words: 2, duration: 30),
            session(words: 20, duration: 2.99),
            session(words: 20, duration: .infinity),
            session(words: 20, duration: 30, isEvaluationFixture: true),
        ]
        let progressSessions = PracticeProgressEligibility.eligibleSessions(in: reviewOnly)

        #expect(reviewOnly.count == 4)
        #expect(progressSessions.isEmpty)
        #expect(ProfileCompositionPlan.make(
            sessionCount: progressSessions.count
        ).stage == .zero)
        #expect(CoachParityReadiness.build(
            memory: nil,
            sessionCount: progressSessions.count,
            recommendationOutcomeCount: 0,
            transferReportCount: 0,
            checkInCount: 0
        ).status(for: .diagnosis) == .thin)
        #expect(!TransformationQuestionEligibility.shouldShow(
            sessionCount: progressSessions.count,
            events: []
        ))

        let brief = ProfileCoachBriefPresentation.make(
            sessionCount: progressSessions.count,
            plan: nil,
            memory: nil
        )
        #expect(brief.evidenceCaption == nil)
        #expect(brief.observation == "One short rep gives Noum something real to read.")
    }

    @Test("Raw streak and league activity ignore Review-only captures")
    func progressDerivedCounts() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let eligibleYesterday = PracticeSession(
            transcript: "one complete eligible rep",
            fillerWordCount: 0,
            duration: 3,
            date: yesterday,
            mode: .timed
        )
        let reviewOnlyToday = PracticeSession(
            transcript: "too short",
            fillerWordCount: 0,
            duration: 2,
            date: today,
            mode: .timed
        )
        let eligibleToday = PracticeSession(
            transcript: "another complete eligible rep",
            fillerWordCount: 0,
            duration: 3,
            date: today,
            mode: .timed
        )

        #expect(PracticeSession.calculateStreak(from: [reviewOnlyToday, eligibleYesterday]) == 1)
        #expect(PracticeSession.calculateStreak(from: [eligibleToday, eligibleYesterday]) == 2)
        #expect(
            LeagueActivityPresentation.weeklySessionCount(
                from: [reviewOnlyToday, eligibleToday],
                now: today,
                calendar: calendar
            ) == 1
        )
    }

    @Test("Coach trajectory excludes Review-only captures")
    func trajectoryProjection() {
        let eligible = session(id: UUID(), words: 20, duration: 30)
        let reviewOnly = session(id: UUID(), words: 2, duration: 2)
        let cache = UserTrajectoryCache.shared
        cache.invalidate()
        defer { cache.invalidate() }

        let result = cache.snapshot(
            profile: nil,
            baseline: .empty,
            rating: .initial,
            sessions: [reviewOnly, eligible],
            coachMemory: nil
        )

        #expect(result.snapshot.sessionCount == 1)
        #expect(result.snapshot.latestRepEvidencePack?.durationSeconds == 30)
        #expect(result.snapshot.latestRepEvidencePack?.transcriptWordCount == 20)
    }

    @Test("Review-only captures cannot unlock coaching, journey, achievement, or weekly projections")
    @MainActor
    func reviewOnlyProjectionBoundary() {
        let reviewOnly = session(words: 2, duration: 2)
        let currentReviewOnly = session(words: 2, duration: 2, date: Date())
        let currentEligible = session(words: 20, duration: 30, date: Date())

        #expect(CoachingPlanner.plan(for: [reviewOnly], profile: nil) == nil)
        let recommendation = RecommendationBiasContextBuilder.context(
            profile: nil,
            sessions: [reviewOnly],
            sessionStreak: 0,
            daysSinceLastSession: 0,
            coachMemory: nil,
            imAvailable: false
        )
        #expect(recommendation.plan == nil)
        #expect(recommendation.input.recentSessionSummary == "No recent sessions yet.")

        #expect(PracticeJourneySnapshot.make(from: [currentReviewOnly]).practicedDays == 0)
        #expect(PracticeJourneySnapshot.make(from: [currentReviewOnly, currentEligible]).practicedDays == 1)
        #expect(
            WeeklySnapshot.compute(
                sessions: [reviewOnly],
                ratingDelta: 0,
                topClutchWord: nil
            ).repsThisWeek == 0
        )

        let emptyProgress = AchievementStore.shared
            .allStatuses(sessions: [], streak: 0)
            .map(\.progress)
        let reviewOnlyProgress = AchievementStore.shared
            .allStatuses(sessions: [reviewOnly], streak: 0)
            .map(\.progress)
        #expect(reviewOnlyProgress == emptyProgress)
    }

    @Test("Unlock resolution keeps registry order and exact session provenance")
    func unlockEventOrderingAndProvenance() throws {
        let sessionID = UUID()
        let event = try #require(
            PathUnlockCelebrationResolver.resolve(
                snapshot: PathUnlockSnapshot(unlockedNodeIDs: ["first_rep"]),
                currentUnlockedNodeIDs: ["first_rep", "clean_rep", "three_reps"],
                triggeringSessionID: sessionID,
                orderedNodeIDs: ["first_rep", "three_reps", "clean_rep"]
            )
        )

        #expect(event.nodeID == "three_reps")
        #expect(event.triggeringSessionID == sessionID)
    }

    @Test("No newly unlocked node produces no celebration")
    func noFalseCelebration() {
        let ids: Set<String> = ["first_rep", "three_reps"]
        #expect(
            PathUnlockCelebrationResolver.resolve(
                snapshot: PathUnlockSnapshot(unlockedNodeIDs: ids),
                currentUnlockedNodeIDs: ids,
                triggeringSessionID: UUID(),
                orderedNodeIDs: Array(ids)
            ) == nil
        )
    }

    @Test("Common finalization snapshots before append and emits the exact event once")
    func finalizationSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let practiceSupport = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/PracticeSupport.swift"),
            encoding: .utf8
        )
        let sessionFinalizer = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SessionFinalizer.swift"),
            encoding: .utf8
        )

        let snapshot = try #require(practiceSupport.range(of: "captureUnlockSnapshot()"))
        let append = try #require(practiceSupport.range(of: "store.append(intentAwareDraft)"))
        let evaluate = try #require(practiceSupport.range(of: "evaluateAfterSession(\n            triggeringSessionID: finalized.id"))
        #expect(snapshot.lowerBound < append.lowerBound)
        #expect(append.lowerBound < evaluate.lowerBound)
        #expect(!sessionFinalizer.contains("PathProgressManager.shared.evaluateAfterSession"))
    }

    @Test("Common finalization gates every earned effect after persistence")
    func finalizationProgressGateSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let practiceSupport = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/PracticeSupport.swift"),
            encoding: .utf8
        )

        let append = try #require(practiceSupport.range(of: "store.append(intentAwareDraft)"))
        let annotation = try #require(practiceSupport.range(of: "store.annotate(sessionID: session.id"))
        let guardRange = try #require(practiceSupport.range(of: "guard PracticeProgressEligibility.qualifies(finalized)"))
        let firstEffect = try #require(practiceSupport.range(of: "DeferredProfileCaptureManager.shared.consider"))
        #expect(append.lowerBound < annotation.lowerBound)
        #expect(annotation.lowerBound < guardRange.lowerBound)
        #expect(guardRange.lowerBound < firstEffect.lowerBound)

        let reactiveConsumers = [
            "DailyGoalManager.swift",
            "StreakFreezeManager.swift",
            "DailyChallengesManager.swift",
            "WordOfTheDayManager.swift",
            "SharedNoumStateMirror.swift",
        ]
        for file in reactiveConsumers {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent("Noum/\(file)"),
                encoding: .utf8
            )
            #expect(source.contains("progressEligibleSessions"), "\(file) must project Review-only rows out")
        }

        let mastery = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/ModeMasteryStore.swift"),
            encoding: .utf8
        )
        #expect(mastery.contains("PracticeProgressEligibility.eligibleSessions(in: sessions)"))

        let recognizer = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SpeechRecognizerViewModel.swift"),
            encoding: .utf8
        )
        #expect(recognizer.contains("PracticeProgressEligibility.qualifies(latest)"))
        #expect(practiceSupport.contains("func recordOutcome(for session: PracticeSession"))
        #expect(practiceSupport.contains("guard PracticeProgressEligibility.qualifies(session) else { return }"))
    }

    @Test("Profile separates raw saved history from progress-bearing evidence")
    func profileProgressProjectionSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let profile = try String(
            contentsOf: repositoryRoot.appendingPathComponent("ProfileView.swift"),
            encoding: .utf8
        )

        #expect(profile.contains("private var progressEligibleSessions: [PracticeSession]"))
        #expect(profile.contains("sessionStore.progressEligibleSessions.sorted"))
        #expect(!profile.contains("sessionCount: sessions.count"))
        #expect(!profile.contains("CoachingPlanner.plan(for: sessions"))
        #expect(profile.contains("for session in progressEligibleSessions"))
        #expect(profile.contains("sessions: progressEligibleSessions"))

        // Saved-rep navigation remains an exact raw-history surface.
        #expect(profile.contains("if sessions.isEmpty { return \"Saved reps appear here\" }"))
        #expect(profile.contains("return \"\\(sessions.count) \\(noun) · trends over time\""))
    }

    @Test("Mode-specific completion cannot cross the shared progress boundary")
    func modeSpecificProgressGateSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let imSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/IMPracticeView.swift"),
            encoding: .utf8
        )
        let imBody = try #require(imSource.range(of: "private func endConversation()"))
        let imCompletion = String(imSource[imBody.lowerBound...])
        let imGate = try #require(imCompletion.range(of: "guard PracticeProgressEligibility.qualifies("))
        let reviewOnlyOutcome = try #require(imCompletion.range(of: "outcome: nil"))
        let evaluator = try #require(imCompletion.range(of: "evaluationService.evaluateConversation("))
        let relationship = try #require(imCompletion.range(of: "relationshipStore.applySessionOutcome("))
        #expect(imGate.lowerBound < reviewOnlyOutcome.lowerBound)
        #expect(reviewOnlyOutcome.lowerBound < evaluator.lowerBound)
        #expect(evaluator.lowerBound < relationship.lowerBound)

        let pressureEngine = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/PressureTimerEngine.swift"),
            encoding: .utf8
        )
        #expect(pressureEngine.contains("var isProgressEligible: Bool"))
        #expect(pressureEngine.contains("wordCount: totalWords"))
        #expect(pressureEngine.contains("duration: totalDuration"))

        let resultSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SuddenDeathResultView.swift"),
            encoding: .utf8
        )
        let resolveStart = try #require(resultSource.range(of: "private func resolveAndAnimate()"))
        let resolveBody = String(resultSource[resolveStart.lowerBound...])
        let resultGate = try #require(resolveBody.range(of: "guard result.isProgressEligible else"))
        let roundsBest = try #require(resolveBody.range(of: "highScoreStore.recordRun("))
        let pointsBest = try #require(resolveBody.range(of: "highScoreStore.recordPoints("))
        let runHistory = try #require(resolveBody.range(of: "runHistoryStore.record(record)"))
        #expect(resultGate.lowerBound < roundsBest.lowerBound)
        #expect(resultGate.lowerBound < pointsBest.lowerBound)
        #expect(resultGate.lowerBound < runHistory.lowerBound)

        let practiceSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SuddenDeathPracticeView.swift"),
            encoding: .utf8
        )
        let practiceGate = try #require(practiceSource.range(of: "guard result.isProgressEligible else"))
        let legacyBest = try #require(practiceSource.range(
            of: "UserDefaults.standard.set(result.roundsSurvived"
        ))
        #expect(practiceGate.lowerBound < legacyBest.lowerBound)
    }

    @Test("Summary gates review-only credit and AI side effects")
    func summaryProgressGateSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let summary = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SummaryView.swift"),
            encoding: .utf8
        )

        #expect(summary.contains("private var currentRepIsProgressEligible: Bool"))
        #expect(summary.contains("private var earnedXPForPresentation: Int"))
        #expect(summary.contains("guard currentRepIsProgressEligible else"))
        #expect(summary.contains("PracticeProgressEligibility.qualifies(session)"))
        #expect(summary.contains("sessionStore.progressEligibleSessionCount"))
        #expect(summary.contains("private var currentRepUnlockedPathStep: Bool"))
        #expect(summary.contains(
            "PathProgressManager.shared.pendingCelebrationSessionID == sessionID"
        ))
        #expect(summary.contains("if currentRepUnlockedPathStep"))
        #expect(!summary.contains(
            "if PathProgressManager.shared.pendingCelebrationNodeID != nil"
        ))
    }

    @Test("Home resolves the pending path node into the unified progress receipt")
    func renderedProvenanceSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let content = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/ContentView.swift"),
            encoding: .utf8
        )

        #expect(content.contains("home.progressReceipt"))
        #expect(content.contains("guard let celebration = pathProgress.pendingCelebration"))
        #expect(content.contains("celebration.triggeringSessionID"))
        #expect(content.contains("PracticeProgressEligibility.qualifies(source)"))
        #expect(content.contains("$0.0.id == celebration.nodeID"))
        #expect(content.contains("onDismiss: pathProgress.consumeCelebration"))
        #expect(!content.contains("PathNodeCelebration("))
    }
}
