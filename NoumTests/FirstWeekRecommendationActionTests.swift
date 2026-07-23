import Foundation
import Testing
@testable import Noum

@Suite("First-week exact recommendation action")
struct FirstWeekRecommendationActionTests {
    @Test("A current case intervention preserves its exact target and demand")
    func currentInterventionIsLaunchableAndVerifiable() throws {
        let blueprint = caseBlueprint(
            mode: .timed,
            focus: "Open with the answer",
            target: "Add one concrete proof point",
            timedDifficulty: .hard
        )
        let exposure = HomeCoachRecommendationPipeline.exposure(
            for: blueprint,
            title: "Start clean.",
            profile: nil,
            recentSessions: []
        )
        let projection = FirstWeekRecommendationActionProjection.resolve(
            snapshot: snapshot(nextAction: .repeatRep(mode: .timed)),
            candidate: .continuingCase(exposure),
            availability: .allAvailable
        )

        guard case .ready(let ready) = projection.state else {
            Issue.record("Expected the live case intervention to remain launchable")
            return
        }
        #expect(ready.step == .repeatRep)
        #expect(ready.exposure.fingerprint == exposure.fingerprint)
        #expect(ready.exposure.focus == "Open with the answer")
        #expect(ready.exposure.target == "Add one concrete proof point")
        #expect(ready.exposure.mode == .timed)
        #expect(
            ready.exposure.prescribedDemand
                == .timed(difficulty: .hard, speechProjectID: nil)
        )

        let launch = PracticeModeLaunchProjection.resolve(
            displayedMode: ready.exposure.mode,
            scenario: ready.exposure.scenario,
            tone: ready.exposure.tone,
            prescribedDemand: ready.exposure.prescribedDemand,
            imAvailable: true,
            modeAvailability: .allAvailable
        )
        #expect(launch.acceptsDisplayedPrescription)
        #expect(launch.destination == .timedPractice(difficulty: .hard))

        let accepted = RecommendationExposure(
            fingerprint: ready.exposure.fingerprint,
            title: ready.exposure.title,
            focus: ready.exposure.focus,
            target: ready.exposure.target,
            mode: ready.exposure.mode,
            isAIBacked: false,
            shownAt: Date(timeIntervalSince1970: 100),
            tappedAt: Date(timeIntervalSince1970: 101),
            adherenceSchemaVersion: RecommendationAdherenceContract.schemaVersion,
            prescribedDemand: ready.exposure.prescribedDemand
        )
        let completed = PracticeSession(
            transcript: "The answer is yes. The customer impact is the proof point.",
            fillerWordCount: 0,
            duration: 15,
            date: Date(timeIntervalSince1970: 102),
            mode: .timed,
            score: 8,
            transcriptConfidence: 0.95,
            practiceDemand: .timed(difficulty: .hard)
        )
        let followed = RecommendationLearningStore.followedPrescription(
            accepted,
            completedSession: completed
        )
        #expect(followed)

        let outcome = RecommendationOutcome(
            id: UUID(),
            fingerprint: accepted.fingerprint,
            title: accepted.title,
            focus: accepted.focus,
            target: accepted.target,
            mode: accepted.mode,
            sessionID: completed.id,
            followed: followed,
            adherenceSchemaVersion: accepted.adherenceSchemaVersion,
            prescribedDemand: accepted.prescribedDemand,
            executedDemand: completed.practiceDemand,
            completedAt: completed.date,
            scoreDelta: 0,
            hasComparableScore: false,
            fillerDelta: 0,
            durationDelta: 0
        )
        #expect(outcome.isVerifiedFollowed)
    }

    @Test("A comparison step reuses the same current intervention")
    func comparisonUsesCurrentIntervention() {
        let blueprint = caseBlueprint(
            mode: .ahCounter,
            focus: "Pause instead of filling",
            target: "Hold one clean pause"
        )
        let exposure = HomeCoachRecommendationPipeline.exposure(
            for: blueprint,
            title: "Pause instead of filling.",
            profile: nil,
            recentSessions: []
        )
        let projection = FirstWeekRecommendationActionProjection.resolve(
            snapshot: snapshot(
                nextAction: .compareAndAdapt(
                    lever: .fillerReduction,
                    mode: .ahCounter
                )
            ),
            candidate: .continuingCase(exposure),
            availability: .allAvailable
        )

        guard case .ready(let ready) = projection.state else {
            Issue.record("Expected a matching comparison prescription")
            return
        }
        #expect(ready.step == .compareAndAdapt)
        #expect(ready.exposure.mode == .ahCounter)
        #expect(ready.exposure.prescribedDemand == nil)
    }

    @Test("The bounded first-rep target survives when Summary emitted no exposure")
    func boundedFirstRepSeedBridgesMissingSummaryExposure() throws {
        let repeatSnapshot = snapshot(nextAction: .repeatRep(mode: .timed))
        let first = eligibleSession(
            id: UUID(uuidString: "DDDDDDDD-DDDD-4DDD-8DDD-DDDDDDDDDDDD")!,
            at: repeatSnapshot.activation.completedAt.addingTimeInterval(30),
            categoryRatings: [
                "Structure": FeedbackRating.couldImprove.rawValue,
                "Opening": FeedbackRating.good.rawValue,
            ]
        )
        let seed = try #require(BoundedFirstRepCoachingSeed.resolve(session: first))
        let memory = memory(activeIntervention: seed.intervention, session: first)
        let exposure = try #require(FirstWeekSeedPrescriptionExposure.resolve(
            memory: memory,
            snapshot: repeatSnapshot,
            sessions: [first],
            now: first.date.addingTimeInterval(1)
        ))

        #expect(exposure.mode == .timed)
        #expect(exposure.focus == "Structure")
        #expect(exposure.target == "Open with the answer, then add one concrete example.")
        #expect(exposure.fingerprint.contains(first.id.uuidString))
        #expect(
            exposure.prescribedDemand
                == .timed(difficulty: .medium, speechProjectID: nil)
        )

        for planSnapshot in [
            repeatSnapshot,
            snapshot(
                nextAction: .compareAndAdapt(
                    lever: .structure,
                    mode: .timed
                )
            ),
        ] {
            let candidate = try #require(
                FirstWeekRecommendationActionProjection.selectCandidate(
                    snapshot: planSnapshot,
                    pending: nil,
                    latestEligibleSession: first,
                    liveCaseExposure: exposure,
                    now: first.date.addingTimeInterval(1)
                )
            )
            let projection = FirstWeekRecommendationActionProjection.resolve(
                snapshot: planSnapshot,
                candidate: candidate,
                availability: .allAvailable
            )
            guard case .ready(let ready) = projection.state else {
                Issue.record("Expected the source-bound first-week prescription")
                continue
            }
            #expect(ready.exposure.fingerprint == exposure.fingerprint)
            #expect(ready.exposure.mode == seed.mode)
            #expect(ready.exposure.target == seed.target)
        }
    }

    @Test("A missing or changed bounded source cannot manufacture a first-week action")
    func boundedFirstRepSeedFailsClosedWhenSourceIsNotExact() throws {
        let liveSnapshot = snapshot(nextAction: .repeatRep(mode: .timed))
        let first = eligibleSession(
            at: liveSnapshot.activation.completedAt.addingTimeInterval(30),
            categoryRatings: [
                "Structure": FeedbackRating.couldImprove.rawValue,
            ]
        )
        let seed = try #require(BoundedFirstRepCoachingSeed.resolve(session: first))
        let validMemory = memory(
            activeIntervention: seed.intervention,
            session: first
        )

        #expect(FirstWeekSeedPrescriptionExposure.resolve(
            memory: validMemory,
            snapshot: liveSnapshot,
            sessions: [],
            now: first.date.addingTimeInterval(1)
        ) == nil)

        var changed = seed.intervention
        changed.target = "A target not present in the bounded catalog"
        #expect(FirstWeekSeedPrescriptionExposure.resolve(
            memory: memory(activeIntervention: changed, session: first),
            snapshot: liveSnapshot,
            sessions: [first],
            now: first.date.addingTimeInterval(1)
        ) == nil)
    }

    @Test("The current Summary mode-only action restores only for its exact source rep")
    func persistedExposureBridgesBeforeCoachMemoryProjection() throws {
        let liveSnapshot = snapshot(
            nextAction: .repeatRep(mode: nil)
        )
        let latest = eligibleSession(
            id: UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC")!,
            at: liveSnapshot.activation.completedAt.addingTimeInterval(30)
        )
        let pending = RecommendationExposure(
            fingerprint: "summary-next-action|\(latest.id.uuidString)|timed|Open with the answer.|general|\(latest.id.uuidString)",
            title: "Open with the answer.",
            focus: "Structure",
            target: "Lead with one clear decision",
            mode: .timed,
            isAIBacked: false,
            shownAt: latest.date.addingTimeInterval(30),
            tappedAt: nil,
            sourceSessionID: latest.id,
            adherenceSchemaVersion: RecommendationAdherenceContract.schemaVersion,
            prescribedDemand: nil
        )
        let candidate = try #require(
            FirstWeekRecommendationActionProjection.Candidate.persisted(
                pending,
                snapshot: liveSnapshot,
                latestEligibleSession: latest,
                now: pending.shownAt.addingTimeInterval(1)
            )
        )
        let projection = FirstWeekRecommendationActionProjection.resolve(
            snapshot: liveSnapshot,
            candidate: candidate,
            availability: .allAvailable
        )

        guard case .ready(let ready) = projection.state else {
            Issue.record("Expected the exact pending Summary exposure")
            return
        }
        #expect(candidate.source == .persistedExposure)
        #expect(ready.exposure.fingerprint == pending.fingerprint)
        #expect(ready.exposure.focus == pending.focus)
        #expect(ready.exposure.target == pending.target)
        #expect(ready.exposure.mode == pending.mode)
        #expect(ready.exposure.prescribedDemand == nil)

        let preActivation = RecommendationExposure(
            fingerprint: "summary-next-action|\(latest.id.uuidString)|timed|Stale|general|\(latest.id.uuidString)",
            title: pending.title,
            focus: pending.focus,
            target: pending.target,
            mode: pending.mode,
            isAIBacked: false,
            shownAt: liveSnapshot.activation.completedAt.addingTimeInterval(-1),
            tappedAt: nil,
            sourceSessionID: latest.id,
            adherenceSchemaVersion: RecommendationAdherenceContract.schemaVersion,
            prescribedDemand: nil
        )
        #expect(
            FirstWeekRecommendationActionProjection.Candidate.persisted(
                preActivation,
                snapshot: liveSnapshot,
                latestEligibleSession: latest,
                now: pending.shownAt
            ) == nil
        )

        let wrongSource = RecommendationExposure(
            fingerprint: pending.fingerprint,
            title: pending.title,
            focus: pending.focus,
            target: pending.target,
            mode: pending.mode,
            isAIBacked: false,
            shownAt: pending.shownAt,
            tappedAt: nil,
            sourceSessionID: UUID(),
            adherenceSchemaVersion: RecommendationAdherenceContract.schemaVersion,
            prescribedDemand: nil
        )
        #expect(
            FirstWeekRecommendationActionProjection.Candidate.persisted(
                wrongSource,
                snapshot: liveSnapshot,
                latestEligibleSession: latest,
                now: pending.shownAt.addingTimeInterval(1)
            ) == nil
        )
    }

    @Test("A matching live IM case preserves scenario and tone")
    func liveIMCasePreservesExactSetup() throws {
        let snapshot = snapshot(nextAction: .repeatRep(mode: .imConversation))
        let latest = eligibleSession(
            at: snapshot.activation.completedAt.addingTimeInterval(20),
            mode: .imConversation
        )
        let live = HomeCoachRecommendationPipeline.exposure(
            for: caseBlueprint(
                mode: .imConversation,
                focus: "Stay direct under pushback",
                target: "State the boundary once",
                scenario: .difficultConversation,
                tone: .calm
            ),
            title: "Hold the boundary.",
            profile: nil,
            recentSessions: [latest]
        )
        let pending = pendingExposure(
            matching: live,
            shownAt: latest.date.addingTimeInterval(1)
        )

        let candidate = try #require(
            FirstWeekRecommendationActionProjection.selectCandidate(
                snapshot: snapshot,
                pending: pending,
                latestEligibleSession: latest,
                liveCaseExposure: live,
                now: pending.shownAt.addingTimeInterval(1)
            )
        )

        #expect(candidate.source == .continuingCase)
        #expect(candidate.exposure == live)
        #expect(candidate.exposure.scenario == .difficultConversation)
        #expect(candidate.exposure.tone == .calm)
    }

    @Test("A matching live Timed case preserves its non-All theme and demand")
    func liveTimedCasePreservesTheme() throws {
        let snapshot = snapshot(nextAction: .repeatRep(mode: .timed))
        let latest = eligibleSession(
            at: snapshot.activation.completedAt.addingTimeInterval(20)
        )
        let live = HomeCoachRecommendationPipeline.exposure(
            for: caseBlueprint(
                mode: .timed,
                focus: "Lead with the decision",
                target: "Use one stakeholder example",
                timedDifficulty: .hard,
                theme: .leadership
            ),
            title: "Lead with the decision.",
            profile: nil,
            recentSessions: [latest]
        )
        let pending = pendingExposure(
            matching: live,
            shownAt: latest.date.addingTimeInterval(1)
        )

        let candidate = try #require(
            FirstWeekRecommendationActionProjection.selectCandidate(
                snapshot: snapshot,
                pending: pending,
                latestEligibleSession: latest,
                liveCaseExposure: live,
                now: pending.shownAt.addingTimeInterval(1)
            )
        )

        #expect(candidate.exposure == live)
        #expect(candidate.exposure.suggestedTheme == .leadership)
        #expect(
            candidate.exposure.prescribedDemand
                == .timed(difficulty: .hard, speechProjectID: nil)
        )

        let collidingButChanged = RecommendationExposure(
            fingerprint: live.fingerprint,
            title: live.title,
            focus: live.focus,
            target: "A different target",
            mode: live.mode,
            isAIBacked: false,
            shownAt: pending.shownAt,
            tappedAt: nil,
            adherenceSchemaVersion: RecommendationAdherenceContract.schemaVersion,
            prescribedDemand: live.prescribedDemand
        )
        #expect(
            FirstWeekRecommendationActionProjection.selectCandidate(
                snapshot: snapshot,
                pending: collidingButChanged,
                latestEligibleSession: latest,
                liveCaseExposure: live,
                now: pending.shownAt.addingTimeInterval(1)
            ) == nil
        )
    }

    @Test("A pending action shown before the latest baseline cannot be restored")
    func stalePreBaselinePendingFailsClosed() {
        let snapshot = snapshot(nextAction: .repeatRep(mode: .timed))
        let latest = eligibleSession(
            at: snapshot.activation.completedAt.addingTimeInterval(60)
        )
        let pending = RecommendationExposure(
            fingerprint: "summary-next-action|\(latest.id.uuidString)|timed|Old|general|\(latest.id.uuidString)",
            title: "Old action",
            focus: "Structure",
            target: "Lead with one point",
            mode: .timed,
            isAIBacked: false,
            shownAt: latest.date.addingTimeInterval(-1),
            tappedAt: nil,
            sourceSessionID: latest.id,
            adherenceSchemaVersion: RecommendationAdherenceContract.schemaVersion,
            prescribedDemand: nil
        )

        #expect(
            FirstWeekRecommendationActionProjection.selectCandidate(
                snapshot: snapshot,
                pending: pending,
                latestEligibleSession: latest,
                liveCaseExposure: nil,
                now: latest.date.addingTimeInterval(2)
            ) == nil
        )
    }

    @Test("An unrelated pending action cannot override the live case")
    func unrelatedPendingFallsBackToLiveCase() throws {
        let snapshot = snapshot(nextAction: .repeatRep(mode: .timed))
        let latest = eligibleSession(
            at: snapshot.activation.completedAt.addingTimeInterval(20)
        )
        let live = HomeCoachRecommendationPipeline.exposure(
            for: caseBlueprint(
                mode: .timed,
                focus: "Current focus",
                target: "Current target",
                timedDifficulty: .medium
            ),
            title: "Current action.",
            profile: nil,
            recentSessions: [latest]
        )
        let unrelated = RecommendationExposure(
            fingerprint: "train-unrelated-action",
            title: "Different action",
            focus: "Fillers",
            target: "Avoid every filler",
            mode: .ahCounter,
            isAIBacked: false,
            shownAt: latest.date.addingTimeInterval(1),
            tappedAt: nil
        )

        let candidate = try #require(
            FirstWeekRecommendationActionProjection.selectCandidate(
                snapshot: snapshot,
                pending: unrelated,
                latestEligibleSession: latest,
                liveCaseExposure: live,
                now: unrelated.shownAt.addingTimeInterval(1)
            )
        )
        #expect(candidate == .continuingCase(live))
    }

    @Test("Missing, moved, and unavailable prescriptions fail closed")
    func staleActionsDoNotBecomeAcceptedPrescriptions() {
        let timed = caseBlueprint(
            mode: .timed,
            focus: "Structure",
            target: "One clear point",
            timedDifficulty: .medium
        )
        let exposure = HomeCoachRecommendationPipeline.exposure(
            for: timed,
            title: "Start clean.",
            profile: nil,
            recentSessions: []
        )

        #expect(
            FirstWeekRecommendationActionProjection.resolve(
                snapshot: snapshot(nextAction: .repeatRep(mode: .timed)),
                candidate: nil,
                availability: .allAvailable
            ).state == .unavailable(.noCurrentPrescription)
        )
        #expect(
            FirstWeekRecommendationActionProjection.resolve(
                snapshot: snapshot(nextAction: .realWorldCheckIn),
                candidate: .continuingCase(exposure),
                availability: .allAvailable
            ).state == .unavailable(.planMovedOn)
        )
        #expect(
            FirstWeekRecommendationActionProjection.resolve(
                snapshot: snapshot(nextAction: .repeatRep(mode: .ahCounter)),
                candidate: .continuingCase(exposure),
                availability: .allAvailable
            ).state == .unavailable(.planMovedOn)
        )

        let pressure = caseBlueprint(
            mode: .suddenDeath,
            focus: "Composure",
            target: "Answer on the first beat"
        )
        let pressureExposure = HomeCoachRecommendationPipeline.exposure(
            for: pressure,
            title: "Composure.",
            profile: nil,
            recentSessions: []
        )
        #expect(
            FirstWeekRecommendationActionProjection.resolve(
                snapshot: snapshot(
                    nextAction: .repeatRep(mode: .suddenDeath)
                ),
                candidate: .continuingCase(pressureExposure),
                availability: .failClosed
            ).state == .unavailable(.modeUnavailable)
        )
    }

    @Test("Day 1 through 4 notification route contains no coaching content")
    func neutralRouteCarriesNoTargetOrMode() {
        for action in [
            FirstWeekCoachingContract.NextAction.repeatRep(mode: .timed),
            .compareAndAdapt(lever: .structure, mode: .suddenDeath),
        ] {
            let attribution = FirstWeekNotificationAttribution(
                snapshot: snapshot(nextAction: action)
            )
            #expect(
                attribution.route
                    == FirstWeekNotificationAttribution.recommendationActionRoute
            )
            let serialized = String(describing: attribution.userInfo)
            #expect(!serialized.localizedCaseInsensitiveContains("structure"))
            #expect(!serialized.localizedCaseInsensitiveContains("timed"))
            #expect(!serialized.localizedCaseInsensitiveContains("suddenDeath"))
            #expect(!serialized.localizedCaseInsensitiveContains("target"))
        }
    }

    private func caseBlueprint(
        mode: PracticeMode,
        focus: String,
        target: String,
        timedDifficulty: TimedPracticeDifficulty? = nil,
        scenario: IMConversationScenario? = nil,
        tone: IMTargetTone? = nil,
        theme: PromptTheme = .all
    ) -> RecommendationBiasBlueprint {
        RecommendationBiasBlueprint(
            recommendedMode: mode,
            recommendedTone: tone,
            recommendedScenario: scenario,
            focus: focus,
            target: target,
            modeBenefit: "A focused rep.",
            whyMode: "Keep the intervention stable.",
            whyNow: "One more rep checks whether it holds.",
            suggestedTimedDifficulty: timedDifficulty,
            suggestedTheme: theme,
            source: .caseIntervention
        )
    }

    private func pendingExposure(
        matching exposure: HomeCoachRecommendationExposure,
        shownAt: Date
    ) -> RecommendationExposure {
        RecommendationExposure(
            fingerprint: exposure.fingerprint,
            title: exposure.title,
            focus: exposure.focus,
            target: exposure.target,
            mode: exposure.mode,
            isAIBacked: false,
            shownAt: shownAt,
            tappedAt: nil,
            adherenceSchemaVersion: RecommendationAdherenceContract.schemaVersion,
            prescribedDemand: exposure.prescribedDemand
        )
    }

    private func eligibleSession(
        id: UUID = UUID(),
        at date: Date,
        mode: PracticeMode = .timed,
        categoryRatings: [String: String] = [:]
    ) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: "This baseline contains enough spoken words.",
            fillerWordCount: 0,
            duration: 30,
            date: date,
            mode: mode,
            score: 7,
            categoryRatings: categoryRatings,
            transcriptConfidence: 0.95,
            practiceDemand: mode == .timed
                ? .timed(difficulty: .medium)
                : nil
        )
    }

    private func memory(
        activeIntervention: CoachIntervention,
        session: PracticeSession
    ) -> CoachMemory {
        CoachMemory(
            updatedAt: session.date,
            lastSessionID: session.id,
            evidenceCount: 1,
            evidenceConfidence: .insufficient,
            currentLever: activeIntervention.skillArea,
            currentLeverConfidence: .low,
            currentLeverBasis: "bounded first-rep read",
            goalFit: .noVoice,
            strengths: [],
            blockers: [],
            activeIntervention: activeIntervention
        )
    }

    private func snapshot(
        nextAction: FirstWeekCoachingContract.NextAction
    ) -> FirstWeekCoachingContract.Snapshot {
        let stage: FirstWeekCoachingContract.Stage = switch nextAction {
        case .recordSpokenBaseline: .day0Baseline
        case .repeatRep: .day1To2Repeat
        case .compareAndAdapt: .day3To4CompareAndAdapt
        case .realWorldCheckIn: .day5To6RealWorldCheckIn
        case .reviewFirstWeekRead: .day7FirstWeekRead
        }
        let intent: FirstWeekCoachingContract.NotificationIntent = switch nextAction {
        case .recordSpokenBaseline: .recordSpokenBaseline
        case .repeatRep: .repeatRep
        case .compareAndAdapt: .compareAndAdapt
        case .realWorldCheckIn: .realWorldCheckIn
        case .reviewFirstWeekRead: .firstWeekRead
        }
        return FirstWeekCoachingContract.Snapshot(
            accountID: "first-week-action-tests",
            activation: activation,
            day: stage == .day3To4CompareAndAdapt ? 3 : 1,
            stage: stage,
            eligibleSessionCount: 1,
            currentLever: .structure,
            prescription: nil,
            hasRealWorldCheckIn: false,
            firstWeekRead: nil,
            nextAction: nextAction,
            notificationIntent: intent
        )
    }

    private var activation: FirstWeekCoachingContract.ActivationReceipt {
        let completedAt = Date(timeIntervalSince1970: 1_767_225_600)
        let draft = CoachingProfileDraft(
            correlationID: UUID(
                uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB"
            )!,
            speakingContext: .work,
            speakingChallenge: .rambling,
            createdAt: completedAt.addingTimeInterval(-60),
            firstValueReceipt: .structured(
                metadata: StructuredFirstValueMetadata(
                    promptID: StructuredFirstValueCatalog.prompt(for: .work).id,
                    wordCount: 12
                ),
                completedAt: completedAt
            )
        )
        return FirstWeekCoachingContract.ActivationReceipt(
            accountID: "first-week-action-tests",
            draft: draft
        )!
    }
}
