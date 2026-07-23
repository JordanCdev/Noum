import Foundation
import Testing
@testable import Noum

@Suite("Durable session coaching evidence")
struct SessionCoachingEvidenceDurabilityTests {
    private let epoch = Date(timeIntervalSince1970: 1_750_000_000)

    @Test("Below-floor persisted rows cannot create trend or memory work")
    func belowFloorRowsFailClosed() {
        let thin = session(
            words: "two words",
            duration: 2,
            date: epoch
        )

        #expect(DurableCoachingEvidencePlanner.make(
            triggeringSessionID: thin.id,
            sessions: [thin],
            snapshots: [],
            memory: nil
        ) == nil)
    }

    @Test("An unannotated crash-window row cannot fabricate scored evidence")
    func nilScoreRowsFailClosed() {
        let prior = session(date: epoch.addingTimeInterval(-3_600))
        let unannotated = session(score: nil, date: epoch)
        #expect(DurableCoachingEvidencePlanner.evaluatedSessions(
            in: [unannotated, prior]
        ).map(\.id) == [prior.id])

        #expect(DurableCoachingEvidencePlanner.make(
            triggeringSessionID: unannotated.id,
            sessions: [unannotated, prior],
            snapshots: [],
            memory: nil
        ) == nil)

        // A general reload may still repair older evaluated evidence, but it
        // must never project the newer crash-window row as a zero score.
        #expect(DurableCoachingEvidencePlanner.make(
            triggeringSessionID: nil,
            sessions: [unannotated, prior],
            snapshots: [],
            memory: nil
        )?.sessionID == prior.id)
    }

    @MainActor
    @Test("Evaluated category ratings survive persistence and snapshot repair")
    func categoryRatingsAreDurableAndBackwardCompatible() throws {
        let ratings = [
            "Opening": FeedbackRating.good.rawValue,
            "Structure": FeedbackRating.ok.rawValue,
            "Close": FeedbackRating.couldImprove.rawValue,
        ]
        let evaluatedCategories = [
            FeedbackCategory(dimension: "Opening", rating: .good, note: "Clear start"),
            FeedbackCategory(dimension: "Structure", rating: .ok, note: "One more point"),
            FeedbackCategory(dimension: "Close", rating: .couldImprove, note: "Finish deliberately"),
        ]
        #expect(evaluatedCategories.persistedCategoryRatings == ratings)
        let evaluated = session(
            score: 8,
            categoryRatings: evaluatedCategories.persistedCategoryRatings,
            date: epoch
        )

        let encoded = try JSONEncoder().encode(evaluated)
        let decoded = try JSONDecoder().decode(PracticeSession.self, from: encoded)
        #expect(decoded.categoryRatings == ratings)

        let snapshot = try #require(SessionFinalizer.skillSnapshot(from: decoded))
        #expect(snapshot.score == 8)
        #expect(snapshot.categoryRatings == ratings)

        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "categoryRatings")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try JSONDecoder().decode(PracticeSession.self, from: legacyData)
        #expect(legacy.categoryRatings.isEmpty)
    }

    @MainActor
    @Test("Snapshot projection rejects a nil score")
    func snapshotProjectionRejectsNilScore() {
        let unannotated = session(score: nil, date: epoch)
        #expect(SessionFinalizer.skillSnapshot(from: unannotated).map(\.score) == nil)
    }

    @Test("First durable commit inserts one snapshot and refreshes memory once")
    func firstCommitThenRepeatIsIdempotent() {
        let latest = session(date: epoch)
        let first = DurableCoachingEvidencePlanner.make(
            triggeringSessionID: latest.id,
            sessions: [latest],
            snapshots: [],
            memory: nil
        )

        #expect(first == DurableCoachingEvidencePlan(
            sessionID: latest.id,
            shouldRecordSkillSnapshot: true,
            shouldRefreshCoachMemory: true
        ))

        let repeated = DurableCoachingEvidencePlanner.make(
            triggeringSessionID: latest.id,
            sessions: [latest],
            snapshots: [snapshot(sessionID: latest.id)],
            memory: memory(lastSessionID: latest.id)
        )
        #expect(repeated == DurableCoachingEvidencePlan(
            sessionID: latest.id,
            shouldRecordSkillSnapshot: false,
            shouldRefreshCoachMemory: false
        ))
    }

    @MainActor
    @Test("One evaluated first rep saves a tentative lever and exact content-free prescription")
    func firstRepCreatesBoundedCoachingSeed() throws {
        let first = session(
            score: 7,
            categoryRatings: [
                "Opening": FeedbackRating.good.rawValue,
                "Structure": FeedbackRating.couldImprove.rawValue,
                "Close": FeedbackRating.ok.rawValue,
            ],
            date: epoch
        )
        let skillSnapshot = try #require(SessionFinalizer.skillSnapshot(from: first))
        let preRepRecommendation = RecommendationExposure(
            fingerprint: "day-zero-pre-rep",
            title: "Try a general practice rep",
            focus: "general confidence",
            target: "Finish one answer.",
            mode: .timed,
            isAIBacked: false,
            shownAt: epoch.addingTimeInterval(-10),
            tappedAt: epoch.addingTimeInterval(-5)
        )
        let memory = try #require(CoachMemoryEngine.build(
            // A completed profile is stated intent, not measured evidence. The
            // exact evaluator-owned first-rep read must still become the
            // starting lever; no onboarding draft is needed or published.
            profile: completedProfile,
            baseline: .empty,
            sessions: [first],
            trends: TrendAnalyzer.analyze(snapshots: [skillSnapshot]),
            forwardPlan: nil,
            previous: nil,
            lastSessionID: first.id,
            pendingIntervention: preRepRecommendation,
            now: epoch.addingTimeInterval(1)
        ))

        #expect(memory.evidenceConfidence == .insufficient)
        #expect(memory.currentLever == .structure)
        #expect(memory.currentLeverConfidence == .low)
        #expect(memory.currentLeverBasis?.contains("bounded first-rep structure") == true)
        #expect(memory.workingHypothesis?.contains("verify over more reps") == true)

        let prescription = try #require(memory.activeIntervention)
        #expect(prescription.origin == .boundedFirstRep)
        #expect(prescription.sourceSessionID == first.id)
        #expect(prescription.skillArea == .structure)
        #expect(prescription.mode == .timed)
        #expect(prescription.target == "Open with the answer, then add one concrete example.")
        #expect(prescription.reviewStatus == .awaitingAttempt)
        #expect(BoundedFirstRepCoachingSeed.validates(
            intervention: prescription,
            activationAt: epoch.addingTimeInterval(-1),
            sessions: [first],
            now: epoch.addingTimeInterval(1)
        ))
    }

    @MainActor
    @Test("A first row without evaluator categories cannot invent a coaching seed")
    func firstRepSeedFailsClosedWithoutBoundedCategoryRead() throws {
        let legacy = session(score: 7, categoryRatings: [:], date: epoch)
        let snapshot = try #require(SessionFinalizer.skillSnapshot(from: legacy))
        let memory = try #require(CoachMemoryEngine.build(
            profile: nil,
            baseline: .empty,
            sessions: [legacy],
            trends: TrendAnalyzer.analyze(snapshots: [snapshot]),
            forwardPlan: nil,
            previous: nil,
            lastSessionID: legacy.id,
            now: epoch.addingTimeInterval(1)
        ))

        #expect(memory.currentLever == nil)
        #expect(memory.activeIntervention == nil)
        #expect(BoundedFirstRepCoachingSeed.resolve(session: legacy) == nil)

        let unrelatedMode = session(
            score: 7,
            categoryRatings: ["Structure": FeedbackRating.couldImprove.rawValue],
            mode: .ahCounter,
            date: epoch
        )
        #expect(BoundedFirstRepCoachingSeed.resolve(session: unrelatedMode) == nil)

        let clarityRead = session(
            score: 7,
            categoryRatings: [
                "Structure": FeedbackRating.good.rawValue,
                "Clarity": FeedbackRating.couldImprove.rawValue,
            ],
            date: epoch
        )
        let claritySeed = try #require(
            BoundedFirstRepCoachingSeed.resolve(session: clarityRead)
        )
        #expect(claritySeed.area == .fillerReduction)
    }

    @MainActor
    @Test("The bounded lever and exact prescription survive the second rep")
    func firstRepSeedPersistsUntilStrongerEvidenceExists() throws {
        let first = session(
            score: 7,
            categoryRatings: ["Structure": FeedbackRating.couldImprove.rawValue],
            date: epoch
        )
        let firstSnapshot = try #require(SessionFinalizer.skillSnapshot(from: first))
        let initial = try #require(CoachMemoryEngine.build(
            profile: nil,
            baseline: .empty,
            sessions: [first],
            trends: TrendAnalyzer.analyze(snapshots: [firstSnapshot]),
            forwardPlan: nil,
            previous: nil,
            lastSessionID: first.id,
            now: epoch.addingTimeInterval(1)
        ))

        let second = session(
            score: 8,
            categoryRatings: ["Structure": FeedbackRating.good.rawValue],
            date: epoch.addingTimeInterval(3_600)
        )
        let secondSnapshot = try #require(SessionFinalizer.skillSnapshot(from: second))
        let seed = try #require(BoundedFirstRepCoachingSeed.resolve(session: first))
        let exactDemand = PracticeSessionDemand.timed(difficulty: .medium)
        let followedOutcome = RecommendationOutcome(
            id: UUID(),
            fingerprint: "first-week-seed|\(first.id.uuidString)|timed|medium|structure",
            title: seed.title,
            focus: seed.focus,
            target: seed.target,
            mode: seed.mode,
            sessionID: second.id,
            followed: true,
            prescribedDemand: exactDemand,
            executedDemand: exactDemand,
            completedAt: second.date,
            scoreDelta: 1,
            hasComparableScore: true,
            fillerDelta: 0,
            durationDelta: 0
        )
        let rebuilt = try #require(CoachMemoryEngine.build(
            profile: nil,
            baseline: .empty,
            sessions: [second, first],
            trends: TrendAnalyzer.analyze(
                snapshots: [secondSnapshot, firstSnapshot]
            ),
            forwardPlan: nil,
            previous: initial,
            lastSessionID: second.id,
            recommendationOutcomes: [followedOutcome],
            now: second.date.addingTimeInterval(1)
        ))

        #expect(rebuilt.currentLever == .structure)
        #expect(rebuilt.currentLeverConfidence == .low)
        #expect(rebuilt.currentLeverBasis == initial.currentLeverBasis)
        #expect(rebuilt.activeIntervention?.sourceSessionID == first.id)
        #expect(rebuilt.activeIntervention?.mode == .timed)
        #expect(rebuilt.activeIntervention?.target == initial.activeIntervention?.target)
        #expect(rebuilt.activeIntervention?.origin == .boundedFirstRep)
        #expect(rebuilt.activeIntervention?.followedRepCount == 1)
    }

    @Test("The bounded seed remains tied to its exact durable source row")
    func firstRepSeedRejectsWrongOrMovedSource() throws {
        let first = session(
            categoryRatings: ["Structure": FeedbackRating.couldImprove.rawValue],
            date: epoch
        )
        let seed = try #require(BoundedFirstRepCoachingSeed.resolve(session: first))
        let intervention = seed.intervention

        #expect(!BoundedFirstRepCoachingSeed.validates(
            intervention: intervention,
            activationAt: epoch.addingTimeInterval(1),
            sessions: [first],
            now: epoch.addingTimeInterval(2)
        ))
        #expect(!BoundedFirstRepCoachingSeed.validates(
            intervention: intervention,
            activationAt: epoch.addingTimeInterval(-1),
            sessions: [session(
                categoryRatings: ["Structure": FeedbackRating.couldImprove.rawValue],
                date: epoch
            )],
            now: epoch.addingTimeInterval(2)
        ))
    }

    @Test("Relaunch repairs the persisted latest qualifying row newer than memory")
    func reloadRepairsLatestNewerThanMemory() {
        let older = session(date: epoch.addingTimeInterval(-3_600))
        let latest = session(date: epoch)

        let plan = DurableCoachingEvidencePlanner.make(
            triggeringSessionID: nil,
            sessions: [older, latest],
            snapshots: [snapshot(sessionID: older.id)],
            memory: memory(lastSessionID: older.id)
        )

        #expect(plan == DurableCoachingEvidencePlan(
            sessionID: latest.id,
            shouldRecordSkillSnapshot: true,
            shouldRefreshCoachMemory: true
        ))
    }

    @Test("A missing latest snapshot also rebuilds an apparently current memory")
    func missingSnapshotRepairsCurrentMemoryProjection() {
        let latest = session(date: epoch)

        let plan = DurableCoachingEvidencePlanner.make(
            triggeringSessionID: nil,
            sessions: [latest],
            snapshots: [],
            memory: memory(lastSessionID: latest.id)
        )

        #expect(plan == DurableCoachingEvidencePlan(
            sessionID: latest.id,
            shouldRecordSkillSnapshot: true,
            shouldRefreshCoachMemory: true
        ))
    }

    @Test("An older exact finalization can fill its snapshot but cannot regress current memory")
    func olderTriggerCannotRegressCurrentLever() {
        let older = session(date: epoch.addingTimeInterval(-3_600))
        let latest = session(date: epoch)

        let plan = DurableCoachingEvidencePlanner.make(
            triggeringSessionID: older.id,
            sessions: [latest, older],
            snapshots: [snapshot(sessionID: latest.id)],
            memory: memory(lastSessionID: latest.id)
        )

        #expect(plan == DurableCoachingEvidencePlan(
            sessionID: older.id,
            shouldRecordSkillSnapshot: true,
            shouldRefreshCoachMemory: false
        ))
    }

    @Test("Equal timestamps preserve newest-first store order")
    func equalDatesUseStoreOrder() {
        let first = session(date: epoch)
        let second = session(date: epoch)

        let plan = DurableCoachingEvidencePlanner.make(
            triggeringSessionID: nil,
            sessions: [first, second],
            snapshots: [],
            memory: nil
        )

        #expect(plan?.sessionID == first.id)
    }

    @Test("Source keeps coaching evidence off Summary and account-guards reload repair")
    func sourceBoundaryContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sessionFinalizer = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SessionFinalizer.swift"),
            encoding: .utf8
        )
        let practiceSupport = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/PracticeSupport.swift"),
            encoding: .utf8
        )

        #expect(!sessionFinalizer.contains("SkillTrendStore.shared.recordFromSession"))
        #expect(!sessionFinalizer.contains("CoachMemoryStore.shared.refresh"))

        let baseline = try #require(practiceSupport.range(
            of: "BaselineStore.shared.recordSession(finalized"
        ))
        let durableCommit = try #require(practiceSupport.range(
            of: "triggeringSessionID: finalized.id"
        ))
        #expect(baseline.lowerBound < durableCommit.lowerBound)
        #expect(practiceSupport.contains("self.loadedAccountEpoch == repairEpoch"))
        #expect(practiceSupport.contains("self.currentAccountID == accountScope"))
        #expect(practiceSupport.contains(
            "latest.categoryRatings = annotation.categoryRatings"
        ))
        #expect(practiceSupport.contains(
            "sessions[index].categoryRatings = annotation.categoryRatings"
        ))

        let remoteReplaceStart = try #require(practiceSupport.range(
            of: "func replaceFromRemote(_ remoteSessions: [PracticeSession])"
        ))
        let remoteMergeStart = try #require(practiceSupport.range(
            of: "func mergeFromRemote(\n        _ remoteSessions: [PracticeSession]",
            range: remoteReplaceStart.upperBound..<practiceSupport.endIndex
        ))
        let repairSchedulerStart = try #require(practiceSupport.range(
            of: "private func scheduleDurableCoachingEvidenceRepair(",
            range: remoteMergeStart.upperBound..<practiceSupport.endIndex
        ))
        #expect(practiceSupport[remoteReplaceStart.upperBound..<remoteMergeStart.lowerBound]
            .contains("scheduleDurableCoachingEvidenceRepair("))
        #expect(practiceSupport[remoteMergeStart.upperBound..<repairSchedulerStart.lowerBound]
            .contains("scheduleDurableCoachingEvidenceRepair("))
        #expect(practiceSupport.contains(
            "guard accountScope == nil || repairEpoch?.accountScope == accountScope"
        ))
    }

    private func session(
        words: String = "This persisted answer contains enough useful words.",
        duration: TimeInterval = 30,
        score: Int? = 7,
        categoryRatings: [String: String] = [:],
        mode: PracticeMode = .timed,
        date: Date
    ) -> PracticeSession {
        PracticeSession(
            transcript: words,
            fillerWordCount: 0,
            duration: duration,
            date: date,
            mode: mode,
            score: score,
            categoryRatings: categoryRatings
        )
    }

    private func snapshot(sessionID: UUID) -> SkillSnapshot {
        SkillSnapshot(
            sessionId: sessionID,
            date: epoch,
            fillerCount: 0,
            duration: 30,
            wordCount: 7,
            wpm: 14,
            score: 7
        )
    }

    private func memory(lastSessionID: UUID?) -> CoachMemory {
        CoachMemory(
            updatedAt: epoch,
            lastSessionID: lastSessionID,
            evidenceCount: 1,
            evidenceConfidence: .insufficient,
            goalFit: .noLever,
            strengths: [],
            blockers: []
        )
    }

    private var completedProfile: CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .thinkFaster,
            confidenceLevel: .rebuilding,
            biggestChallenge: .freezing,
            desiredOutcome: .composed,
            speakingStyleGoal: .authoritative,
            styleReference: "",
            coachingBrief: "Prepare for high-stakes meetings.",
            motivationWhyNow: "A stakeholder review is coming up.",
            successVision: "Land the recommendation clearly.",
            chosenStyleGoal: .authoritative
        )
    }
}
