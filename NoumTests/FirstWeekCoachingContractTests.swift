import Foundation
import Testing
@testable import Noum

@Suite("First-week coaching contract", .serialized)
struct FirstWeekCoachingContractTests {
    private let accountID = "first-week-account"

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.locale = Locale(identifier: "en_US_POSIX")
        return value
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(
            from: DateComponents(
                year: 2026,
                month: 1,
                day: day,
                hour: hour
            )
        )!
    }

    private func activationDraft(at completedAt: Date) -> CoachingProfileDraft {
        CoachingProfileDraft(
            correlationID: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!,
            speakingContext: .work,
            speakingChallenge: .rambling,
            createdAt: completedAt.addingTimeInterval(-60),
            firstValueReceipt: .structured(
                metadata: StructuredFirstValueMetadata(
                    promptID: StructuredFirstValueCatalog.prompt(for: .work).id,
                    wordCount: 18
                ),
                completedAt: completedAt
            )
        )
    }

    private func session(
        id: UUID = UUID(),
        at date: Date,
        transcript: String = "State the answer first and support it clearly.",
        duration: TimeInterval = 30,
        score: Int? = nil,
        isRated: Bool = false,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: transcript,
            fillerWordCount: 0,
            duration: duration,
            date: date,
            mode: .timed,
            score: score,
            isRated: isRated,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func comparisonReadyMemory(
        prescribedAt: Date,
        observedAt: Date? = nil,
        followedRepCount: Int = 2,
        reviewStatus: CoachInterventionReviewStatus = .formingEvidence,
        reviewDueAt: Date? = nil
    ) -> CoachMemory {
        CoachMemory(
            updatedAt: observedAt ?? prescribedAt,
            evidenceCount: max(1, followedRepCount),
            evidenceConfidence: .moderate,
            currentLever: .structure,
            goalFit: .noLever,
            strengths: [],
            blockers: [],
            activeIntervention: CoachIntervention(
                title: "Structure comparison",
                focus: "Lead with the answer",
                target: "Answer first, give one reason, then stop.",
                mode: .timed,
                prescribedAt: prescribedAt,
                lastObservedAt: observedAt,
                followedRepCount: followedRepCount,
                minimumFollowedRepsForReview: 2,
                reviewStatus: reviewStatus,
                reviewBasis: "Bounded followed-rep evidence.",
                reviewDueAt: reviewDueAt
            )
        )
    }

    private func input(
        activationAt: Date,
        sessions: [PracticeSession] = [],
        activeAccountID: String? = nil,
        activationAccountID: String? = nil,
        sessionAccountID: String? = nil,
        coachingAccountID: String? = nil,
        memory: CoachMemory? = nil,
        checkIn: CoachCheckIn? = nil,
        longitudinalTrend: CoachLongitudinalTrendProjection? = nil
    ) -> FirstWeekCoachingContract.Input {
        let activation = FirstWeekCoachingContract.ActivationReceipt(
            accountID: activationAccountID ?? accountID,
            draft: activationDraft(at: activationAt)
        )!
        let coaching: FirstWeekCoachingContract.CoachingEvidence? = if memory != nil || checkIn != nil || longitudinalTrend != nil || coachingAccountID != nil {
            FirstWeekCoachingContract.CoachingEvidence(
                accountID: coachingAccountID ?? accountID,
                memory: memory,
                latestCheckIn: checkIn,
                longitudinalTrend: longitudinalTrend
            )
        } else {
            nil
        }
        return FirstWeekCoachingContract.Input(
            activeAccountID: activeAccountID ?? accountID,
            activation: activation,
            sessionEvidence: .init(
                accountID: sessionAccountID ?? accountID,
                sessions: sessions
            ),
            coachingEvidence: coaching
        )
    }

    @Test("Calendar selects reminder bands without inventing evidence")
    func stageBoundaries() throws {
        let activationAt = date(1, hour: 23)
        let spokenBaseline = session(
            at: activationAt.addingTimeInterval(30)
        )
        let expected: [(day: Int, stage: FirstWeekCoachingContract.Stage)] = [
            (1, .day0Baseline),
            (2, .day1To2Repeat),
            (3, .day1To2Repeat),
            (4, .day3To4CompareAndAdapt),
            (5, .day3To4CompareAndAdapt),
            (6, .day5To6RealWorldCheckIn),
            (7, .day5To6RealWorldCheckIn),
            (8, .day7FirstWeekRead),
        ]

        for item in expected {
            let snapshot = try #require(FirstWeekCoachingContract.resolve(
                input: input(
                    activationAt: activationAt,
                    sessions: [spokenBaseline]
                ),
                now: date(item.day, hour: 23),
                calendar: calendar
            ))
            #expect(snapshot.stage == item.stage)
            let expectedAction: FirstWeekCoachingContract.NextAction =
                item.day == 1
                    ? .recordSpokenBaseline
                    : .repeatRep(mode: nil)
            #expect(snapshot.nextAction == expectedAction)
            #expect(snapshot.firstWeekRead == nil)
        }

        let afterFirstWeek = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [spokenBaseline]
            ),
            now: date(9, hour: 23),
            calendar: calendar
        ))
        #expect(afterFirstWeek.stage == .day7FirstWeekRead)
        #expect(afterFirstWeek.nextAction == .repeatRep(mode: nil))
        #expect(afterFirstWeek.firstWeekRead == nil)

        let muchLater = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [spokenBaseline]
            ),
            now: calendar.date(byAdding: .day, value: 60, to: activationAt)!,
            calendar: calendar
        ))
        #expect(muchLater.stage == .day7FirstWeekRead)
        #expect(muchLater.nextAction == .repeatRep(mode: nil))
        #expect(muchLater.firstWeekRead == nil)
        #expect(FirstWeekCoachingContract.resolve(
            input: input(activationAt: activationAt),
            now: date(1, hour: 22),
            calendar: calendar
        ) == nil)
    }

    @Test("Written activation stays Day zero until a late spoken baseline starts the contract")
    func lateSpokenBaselineStartsItsOwnSevenDayWindow() throws {
        let activationAt = date(1)
        let baseline = session(at: date(9))
        let daySevenRep = session(at: date(16), score: 8)
        let afterWindow = session(at: date(18), score: 10)

        let stillWaiting = try #require(FirstWeekCoachingContract.resolve(
            input: input(activationAt: activationAt),
            now: date(8),
            calendar: calendar
        ))
        #expect(stillWaiting.activation.completedAt == activationAt)
        #expect(stillWaiting.day == 0)
        #expect(stillWaiting.stage == .day0Baseline)
        #expect(stillWaiting.nextAction == .recordSpokenBaseline)
        #expect(stillWaiting.firstWeekRead == nil)

        let baselineDay = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [baseline]
            ),
            now: baseline.date.addingTimeInterval(60),
            calendar: calendar
        ))
        #expect(baselineDay.day == 0)
        #expect(baselineDay.stage == .day0Baseline)
        #expect(baselineDay.eligibleSessionCount == 1)
        #expect(baselineDay.nextAction == .repeatRep(mode: nil))

        let progression: [(date: Date, day: Int, stage: FirstWeekCoachingContract.Stage)] = [
            (date(10), 1, .day1To2Repeat),
            (date(12), 3, .day3To4CompareAndAdapt),
            (date(14), 5, .day5To6RealWorldCheckIn),
            (date(16), 7, .day7FirstWeekRead),
        ]
        for expected in progression {
            let snapshot = try #require(FirstWeekCoachingContract.resolve(
                input: input(
                    activationAt: activationAt,
                    sessions: [baseline, daySevenRep]
                ),
                now: expected.date,
                calendar: calendar
            ))
            #expect(snapshot.day == expected.day)
            #expect(snapshot.stage == expected.stage)
        }

        let daySeven = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [baseline, daySevenRep, afterWindow]
            ),
            now: date(30),
            calendar: calendar
        ))
        #expect(daySeven.day == 21)
        #expect(daySeven.stage == .day7FirstWeekRead)
        #expect(daySeven.eligibleSessionCount == 2)
        #expect(daySeven.nextAction == .repeatRep(mode: nil))
        #expect(daySeven.firstWeekRead == nil)
    }

    @Test("Day zero keeps writing permissionless and asks for a user-started spoken proof")
    func dayZeroSpokenProofHandoff() throws {
        let activationAt = date(1)
        let empty = try #require(FirstWeekCoachingContract.resolve(
            input: input(activationAt: activationAt),
            now: activationAt,
            calendar: calendar
        ))
        #expect(empty.activation.source == .structuredFirstValue)
        #expect(empty.activation.sessionID == nil)
        #expect(empty.nextAction == .recordSpokenBaseline)
        #expect(empty.notificationIntent == .recordSpokenBaseline)

        let withProof = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [session(at: activationAt.addingTimeInterval(120))]
            ),
            now: activationAt.addingTimeInterval(180),
            calendar: calendar
        ))
        #expect(withProof.eligibleSessionCount == 1)
        #expect(withProof.nextAction == .repeatRep(mode: nil))
    }

    @Test("Only eligible sessions recorded after activation enter the contract")
    func eligibleSessionsAreBounded() throws {
        let activationAt = date(1)
        let eligibleID = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!
        let snapshot = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [
                    session(at: activationAt.addingTimeInterval(-1)),
                    session(at: activationAt.addingTimeInterval(60), transcript: "two words"),
                    session(at: activationAt.addingTimeInterval(120), duration: 2),
                    session(at: activationAt.addingTimeInterval(180), isEvaluationFixture: true),
                    session(id: eligibleID, at: activationAt.addingTimeInterval(240)),
                    session(at: activationAt.addingTimeInterval(600)),
                ]
            ),
            now: activationAt.addingTimeInterval(300),
            calendar: calendar
        ))

        #expect(snapshot.eligibleSessionCount == 1)
        #expect(snapshot.activation.accountID == accountID)
    }

    @Test("Every evidence projection must match the active account")
    func accountIsolationFailsClosed() {
        let activationAt = date(1)
        #expect(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                activeAccountID: "account-b"
            ),
            now: activationAt,
            calendar: calendar
        ) == nil)
        #expect(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessionAccountID: "account-b"
            ),
            now: activationAt,
            calendar: calendar
        ) == nil)
        #expect(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                coachingAccountID: "account-b"
            ),
            now: activationAt,
            calendar: calendar
        ) == nil)
    }

    @Test("Current lever and prescription stay projections of coach memory")
    func coachingEvidenceIsReusedWithoutOwningCopy() throws {
        let activationAt = date(1)
        let observedAt = date(4)
        let intervention = CoachIntervention(
            title: "PRIVATE PRESCRIPTION TITLE",
            focus: "PRIVATE FOCUS",
            target: "PRIVATE TARGET",
            mode: .timed,
            prescribedAt: date(2),
            lastObservedAt: observedAt,
            followedRepCount: 2,
            minimumFollowedRepsForReview: 2,
            reviewStatus: .formingEvidence,
            reviewBasis: "PRIVATE BASIS"
        )
        let memory = CoachMemory(
            updatedAt: observedAt,
            evidenceCount: 3,
            evidenceConfidence: .moderate,
            currentLever: .structure,
            goalFit: .noLever,
            strengths: [],
            blockers: [],
            activeIntervention: intervention
        )
        let snapshot = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [
                    session(at: activationAt.addingTimeInterval(60)),
                    session(at: date(3)),
                    session(at: observedAt),
                ],
                memory: memory
            ),
            now: observedAt,
            calendar: calendar
        ))

        #expect(snapshot.stage == .day3To4CompareAndAdapt)
        #expect(snapshot.currentLever == .structure)
        #expect(snapshot.prescription?.mode == .timed)
        #expect(snapshot.nextAction == .compareAndAdapt(lever: .structure, mode: .timed))

        let encodedCopy = NotificationCopy.firstWeek(intent: snapshot.notificationIntent)
        let lockScreen = "\(encodedCopy.title) \(encodedCopy.body)"
        #expect(!lockScreen.contains("PRIVATE"))
    }

    @Test("Comparison waits for followed evidence even after the calendar band changes")
    func comparisonDoesNotUnlockFromElapsedDays() throws {
        let activationAt = date(1)
        let baseline = session(at: activationAt.addingTimeInterval(60))
        let oneFollowed = comparisonReadyMemory(
            prescribedAt: date(2),
            observedAt: date(3),
            followedRepCount: 1
        )
        let inconsistentAdaptation = comparisonReadyMemory(
            prescribedAt: date(2),
            observedAt: date(3),
            followedRepCount: 0,
            reviewStatus: .adaptBeforeRepeating
        )
        let enoughFollowed = comparisonReadyMemory(
            prescribedAt: date(2),
            observedAt: date(4),
            followedRepCount: 2
        )

        for memory in [oneFollowed, inconsistentAdaptation] {
            let waiting = try #require(FirstWeekCoachingContract.resolve(
                input: input(
                    activationAt: activationAt,
                    sessions: [baseline],
                    memory: memory
                ),
                now: date(4),
                calendar: calendar
            ))
            #expect(waiting.stage == .day3To4CompareAndAdapt)
            #expect(waiting.nextAction == .repeatRep(mode: .timed))
            #expect(waiting.firstWeekRead == nil)
        }

        let comparison = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [baseline, session(at: date(3)), session(at: date(4))],
                memory: enoughFollowed
            ),
            now: date(4),
            calendar: calendar
        ))
        #expect(
            comparison.nextAction
                == .compareAndAdapt(lever: .structure, mode: .timed)
        )
    }

    @Test("Real-world check-in is the unfinished day-five step")
    func realWorldCheckInProgression() throws {
        let activationAt = date(1)
        let now = date(6)
        let boundedSessions = [
            session(at: activationAt.addingTimeInterval(60)),
            session(at: date(3)),
            session(at: date(5)),
        ]
        let memory = comparisonReadyMemory(
            prescribedAt: date(2),
            observedAt: date(5)
        )
        let due = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: boundedSessions,
                memory: memory
            ),
            now: now,
            calendar: calendar
        ))
        #expect(due.nextAction == .realWorldCheckIn)
        #expect(due.notificationIntent == .realWorldCheckIn)

        let inAppOnly = CoachCheckIn(
            recordedAt: now.addingTimeInterval(-60),
            hardest: "The countdown felt tight."
        )
        let stillDue = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: boundedSessions,
                memory: memory,
                checkIn: inAppOnly
            ),
            now: now,
            calendar: calendar
        ))
        #expect(stillDue.nextAction == .realWorldCheckIn)

        let transferred = CoachCheckIn(
            recordedAt: now.addingTimeInterval(-30),
            outsideApp: "A real meeting."
        )
        let complete = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: boundedSessions,
                memory: memory,
                checkIn: transferred
            ),
            now: now,
            calendar: calendar
        ))
        #expect(complete.hasRealWorldCheckIn)
        #expect(complete.nextAction == .repeatRep(mode: .timed))
    }

    @Test("Day-seven read projects change, unknowns, one example reference, and next week")
    func daySevenReadProjection() throws {
        let activationAt = date(1)
        let firstID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let latestID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let sessions = [
            session(at: activationAt.addingTimeInterval(60)),
            session(id: firstID, at: date(2), score: 6, isRated: true),
            session(id: secondID, at: date(3), score: 6, isRated: true),
            session(id: latestID, at: date(7), score: 8, isRated: true),
        ]
        let trend = CoachLongitudinalTrendProjection(
            sourceSessionID: latestID,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion,
            mode: PracticeMode.timed.displayLabel,
            comparableSessionIDs: [firstID, secondID],
            metrics: [
                CoachLongitudinalMetricTrend(
                    metric: .score,
                    direction: .improving,
                    currentValue: 8,
                    priorAverage: 6
                ),
            ]
        )
        let intervention = CoachIntervention(
            title: "PRIVATE PLAN",
            focus: "PRIVATE FOCUS",
            target: "PRIVATE TARGET",
            mode: .timed,
            prescribedAt: date(2),
            lastObservedAt: date(7),
            followedRepCount: 2,
            minimumFollowedRepsForReview: 2,
            reviewStatus: .continueAndVerify,
            reviewBasis: "PRIVATE REVIEW"
        )
        let memory = CoachMemory(
            updatedAt: date(7),
            evidenceCount: 3,
            evidenceConfidence: .moderate,
            currentLever: .structure,
            goalFit: .noLever,
            strengths: [],
            blockers: [],
            activeIntervention: intervention
        )

        let snapshot = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: sessions,
                memory: memory,
                longitudinalTrend: trend
            ),
            now: date(8),
            calendar: calendar
        ))
        let read = try #require(snapshot.firstWeekRead)

        #expect(read.whatChanged == .verifiedComparison(trend))
        #expect(!read.remainsUnproven.contains(.practiceChange))
        #expect(read.remainsUnproven.contains(.realWorldOutcome))
        #expect(read.remainsUnproven.contains(.durability))
        #expect(read.verifiedExample?.sessionID == latestID)
        #expect(read.verifiedExample?.score == 8)
        #expect(read.nextWeekPlan.lever == .structure)
        #expect(read.nextWeekPlan.mode == .timed)
        #expect(read.nextWeekPlan.remainingComparableRepsBeforeReview == 1)
        #expect(
            read.nextWeekPlan.recommendedAction
                == .repeatRep(mode: .timed)
        )

        let visibleProjection = String(describing: read)
        #expect(!visibleProjection.localizedCaseInsensitiveContains("private"))
        #expect(!visibleProjection.localizedCaseInsensitiveContains("state the answer"))
    }

    @Test("Day-seven withholds a trend and read whose evidence leaves the account window")
    func daySevenReadRejectsUnboundedTrend() throws {
        let activationAt = date(1)
        let priorID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let inWindowID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let trend = CoachLongitudinalTrendProjection(
            sourceSessionID: inWindowID,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion,
            mode: PracticeMode.timed.displayLabel,
            comparableSessionIDs: [priorID, UUID()],
            metrics: [
                CoachLongitudinalMetricTrend(
                    metric: .score,
                    direction: .improving,
                    currentValue: 8,
                    priorAverage: 6
                ),
            ]
        )
        let snapshot = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [
                    session(id: priorID, at: activationAt.addingTimeInterval(-60)),
                    session(id: inWindowID, at: date(7), score: 8, isRated: true),
                ],
                memory: comparisonReadyMemory(
                    prescribedAt: date(2),
                    observedAt: date(7)
                ),
                longitudinalTrend: trend
            ),
            now: date(14),
            calendar: calendar
        ))
        #expect(snapshot.stage == .day7FirstWeekRead)
        #expect(snapshot.eligibleSessionCount == 1)
        #expect(snapshot.prescription == nil)
        #expect(snapshot.nextAction == .repeatRep(mode: nil))
        #expect(snapshot.firstWeekRead == nil)
    }

    @Test("Day-seven caps followed-rep claims to bounded post-prescription sessions")
    func daySevenReadRejectsImpossibleFollowedCount() throws {
        let activationAt = date(1)
        let snapshot = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [
                    session(at: activationAt.addingTimeInterval(60)),
                    session(at: date(7)),
                ],
                memory: comparisonReadyMemory(
                    prescribedAt: date(2),
                    observedAt: date(7),
                    followedRepCount: 2
                )
            ),
            now: date(8),
            calendar: calendar
        ))

        #expect(snapshot.stage == .day7FirstWeekRead)
        #expect(snapshot.prescription?.followedRepCount == 1)
        #expect(snapshot.nextAction == .repeatRep(mode: .timed))
        #expect(snapshot.firstWeekRead == nil)
    }

    @Test("A post-window followed observation cannot create a first-week read")
    func daySevenReadRejectsPostWindowFollowedObservation() throws {
        let activationAt = date(1)
        let snapshot = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [
                    session(at: activationAt.addingTimeInterval(60)),
                    session(at: date(3)),
                    session(at: date(7)),
                    session(at: date(10)),
                ],
                memory: comparisonReadyMemory(
                    prescribedAt: date(2),
                    observedAt: date(10),
                    followedRepCount: 2
                )
            ),
            now: date(14),
            calendar: calendar
        ))

        #expect(snapshot.stage == .day7FirstWeekRead)
        #expect(snapshot.eligibleSessionCount == 3)
        #expect(snapshot.prescription?.followedRepCount == 0)
        #expect(snapshot.nextAction == .repeatRep(mode: .timed))
        #expect(snapshot.firstWeekRead == nil)
    }

    @Test("Verified example skips a higher-scoring rep below the proof floor")
    func verifiedExampleRequiresARestrainedProofSource() throws {
        let activationAt = date(1)
        let baseline = session(
            at: activationAt.addingTimeInterval(60),
            transcript: "Start with the answer and support it clearly.",
            score: 5
        )
        let proofCapable = session(
            at: date(3),
            transcript: "We should decide the owner and deadline today.",
            score: 8
        )
        let tooThin = session(
            at: date(7),
            transcript: "Owner deadline today",
            duration: 3,
            score: 10
        )
        let noCoherentThought = session(
            at: date(6),
            transcript: "One. Two. Three. Four.",
            duration: 30,
            score: 9
        )

        #expect(PracticeProgressEligibility.qualifies(tooThin))
        #expect(!ProofMomentService.canProduceRestrainedProof(from: tooThin))
        #expect(PracticeProgressEligibility.qualifies(noCoherentThought))
        #expect(
            !ProofMomentService.canProduceRestrainedProof(
                from: noCoherentThought
            )
        )
        #expect(ProofMomentService.canProduceRestrainedProof(from: proofCapable))

        let snapshot = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [
                    baseline,
                    proofCapable,
                    noCoherentThought,
                    tooThin,
                ],
                memory: comparisonReadyMemory(
                    prescribedAt: date(2),
                    observedAt: date(7)
                )
            ),
            now: date(8),
            calendar: calendar
        ))
        let read = try #require(snapshot.firstWeekRead)

        #expect(snapshot.eligibleSessionCount == 4)
        #expect(read.verifiedExample?.sessionID == proofCapable.id)
        #expect(read.verifiedExample?.sessionID != tooThin.id)
    }

    @Test("Notification copy names each unfinished step without hype or private text")
    func notificationCopyContract() {
        let expectedTerms: [FirstWeekCoachingContract.NotificationIntent: String] = [
            .recordSpokenBaseline: "30-second",
            .repeatRep: "Repeat",
            .compareAndAdapt: "compare",
            .realWorldCheckIn: "check-in",
            .firstWeekRead: "first-week",
        ]

        for intent in FirstWeekCoachingContract.NotificationIntent.allCases {
            let copy = NotificationCopy.firstWeek(intent: intent)
            let combined = "\(copy.title) \(copy.body)"
            #expect(combined.localizedCaseInsensitiveContains(expectedTerms[intent]!))
            #expect(!combined.contains("!"))
            #expect(!combined.localizedCaseInsensitiveContains("let's"))
            #expect(!combined.localizedCaseInsensitiveContains("private"))
            #expect(!combined.localizedCaseInsensitiveContains("transcript"))
        }
    }

    @Test("First-week notification attribution is bounded, routable, and decodable")
    func notificationAttributionContract() throws {
        let activationAt = date(1)
        let readyMemory = comparisonReadyMemory(
            prescribedAt: date(2),
            observedAt: date(4)
        )
        let readySessions = [
            session(at: activationAt.addingTimeInterval(60)),
            session(at: date(3)),
            session(at: date(4)),
        ]
        let snapshots = [
            try #require(FirstWeekCoachingContract.resolve(
                input: input(activationAt: activationAt),
                now: activationAt,
                calendar: calendar
            )),
            try #require(FirstWeekCoachingContract.resolve(
                input: input(
                    activationAt: activationAt,
                    sessions: [session(at: activationAt.addingTimeInterval(60))]
                ),
                now: date(2),
                calendar: calendar
            )),
            try #require(FirstWeekCoachingContract.resolve(
                input: input(
                    activationAt: activationAt,
                    sessions: readySessions,
                    memory: readyMemory
                ),
                now: date(4),
                calendar: calendar
            )),
            try #require(FirstWeekCoachingContract.resolve(
                input: input(
                    activationAt: activationAt,
                    sessions: readySessions,
                    memory: readyMemory
                ),
                now: date(6),
                calendar: calendar
            )),
            try #require(FirstWeekCoachingContract.resolve(
                input: input(
                    activationAt: activationAt,
                    sessions: readySessions,
                    memory: readyMemory
                ),
                now: date(8),
                calendar: calendar
            )),
        ]
        let expectedRoutes = [
            "noum://home/first-week-spoken-proof",
            "noum://home/first-week-action",
            "noum://home/first-week-action",
            "noum://profile/check-in",
            "noum://home/first-week-read",
        ]

        for (snapshot, expectedRoute) in zip(snapshots, expectedRoutes) {
            let attribution = FirstWeekNotificationAttribution(snapshot: snapshot)
            let payload = attribution.userInfo
            let decoded = try #require(FirstWeekNotificationAttribution.decode(payload))
            #expect(decoded.intent == snapshot.notificationIntent)
            #expect(decoded.route.absoluteString == expectedRoute)
            #expect(payload.count == 4)
            let serialized = String(describing: payload)
            #expect(!serialized.contains(accountID))
            #expect(!serialized.localizedCaseInsensitiveContains("transcript"))
            #expect(!serialized.localizedCaseInsensitiveContains("private"))
        }

        #expect(FirstWeekNotificationAttribution.decode([:]) == nil)
        let baselineAttribution = FirstWeekNotificationAttribution(
            snapshot: snapshots[0]
        )
        var routeTamper = baselineAttribution.userInfo
        routeTamper[FirstWeekNotificationAttribution.routeKey] =
            "noum://home/first-week-action"
        #expect(FirstWeekNotificationAttribution.decode(routeTamper) == nil)
        var kindTamper = baselineAttribution.userInfo
        kindTamper[FirstWeekNotificationAttribution.growthKindKey] =
            GrowthNotificationKind.weeklyRead.rawValue
        #expect(FirstWeekNotificationAttribution.decode(kindTamper) == nil)
        #expect(
            FirstWeekNotificationAttribution(snapshot: snapshots[0]).growthKind
                == .practiceReminder
        )
        #expect(
            FirstWeekNotificationAttribution(snapshot: snapshots[4]).growthKind
                == .weeklyRead
        )
    }

    @Test("Every next action exposes one stable accessibility identifier")
    func accessibilityIdentifiersAreUnique() {
        let actions: [FirstWeekCoachingContract.NextAction] = [
            .recordSpokenBaseline,
            .repeatRep(mode: nil),
            .compareAndAdapt(lever: nil, mode: nil),
            .realWorldCheckIn,
            .reviewFirstWeekRead,
        ]
        let identifiers = actions.map(\.accessibilityIdentifier)
        #expect(Set(identifiers).count == actions.count)
        #expect(identifiers.allSatisfy { $0.hasPrefix("firstWeek.nextAction.") })
    }

    @Test("First-week routes land on the existing owner and durable read")
    func directRouteContract() throws {
        let checkInURL = try #require(URL(string: "noum://profile/check-in"))
        #expect(AppTab.topLevelRoute(for: checkInURL) == .profile)
        #expect(AppTab.rootDestination(for: checkInURL) == .weeklyCheckIn)

        let readURL = try #require(URL(string: "noum://home/first-week-read"))
        #expect(AppTab.topLevelRoute(for: readURL) == .home)
        #expect(AppTab.rootDestination(for: readURL) == .firstWeekRead)

        let proofURL = FirstWeekNotificationAttribution.spokenBaselineActionRoute
        #expect(AppTab.topLevelRoute(for: proofURL) == .home)
        #expect(AppTab.rootDestination(for: proofURL) == nil)
        #expect(AppTab.isFirstWeekSpokenProofRoute(proofURL))
        let malformedProofURL = try #require(
            URL(string: "noum://home/first-week-spoken-proof?difficulty=medium")
        )
        #expect(!AppTab.isFirstWeekSpokenProofRoute(malformedProofURL))

        let continuationURL = try #require(
            URL(string: "noum://home/first-week-action")
        )
        #expect(AppTab.topLevelRoute(for: continuationURL) == .home)
        #expect(AppTab.rootDestination(for: continuationURL) == nil)
        #expect(AppTab.isFirstWeekRecommendationActionRoute(continuationURL))
        let malformedContinuationURL = try #require(
            URL(string: "noum://home/first-week-action?mode=timed")
        )
        #expect(
            !AppTab.isFirstWeekRecommendationActionRoute(
                malformedContinuationURL
            )
        )
    }

    @Test("Activation-relative notification days are one-shot and omit elapsed dates")
    func activationRelativeNotificationSchedule() throws {
        let activationAt = date(1, hour: 8)
        let fullSchedule = FirstWeekNotificationSchedule.deliveries(
            activationAt: activationAt,
            now: activationAt.addingTimeInterval(30 * 60),
            reminderHour: 9,
            reminderMinute: 0,
            calendar: calendar
        )
        #expect(fullSchedule.map(\.day) == Array(0...7))
        #expect(fullSchedule.first?.fireAt == date(1, hour: 9))
        #expect(fullSchedule.last?.fireAt == date(8, hour: 9))

        let resumedOnDayThree = FirstWeekNotificationSchedule.deliveries(
            activationAt: activationAt,
            now: date(4, hour: 12),
            reminderHour: 9,
            reminderMinute: 0,
            calendar: calendar
        )
        #expect(resumedOnDayThree.map(\.day) == [4, 5, 6, 7])
        #expect(Set(resumedOnDayThree.map(\.fireAt)).count == resumedOnDayThree.count)
    }

    @Test("First-week days and reminder wall time survive the spring DST boundary")
    func springDSTKeepsCalendarDayContract() throws {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = try #require(
            TimeZone(identifier: "America/Los_Angeles")
        )
        localCalendar.locale = Locale(identifier: "en_US_POSIX")

        func localDate(_ day: Int, hour: Int, minute: Int = 0) throws -> Date {
            try #require(localCalendar.date(from: DateComponents(
                year: 2026,
                month: 3,
                day: day,
                hour: hour,
                minute: minute
            )))
        }

        let activationAt = try localDate(7, hour: 8)
        let firstSpokenRep = session(at: try localDate(7, hour: 23))
        let dayOne = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [firstSpokenRep]
            ),
            now: try localDate(8, hour: 12),
            calendar: localCalendar
        ))
        #expect(dayOne.day == 1)
        #expect(dayOne.stage == .day1To2Repeat)

        let deliveries = FirstWeekNotificationSchedule.deliveries(
            activationAt: activationAt,
            now: try localDate(7, hour: 8, minute: 30),
            reminderHour: 9,
            reminderMinute: 0,
            calendar: localCalendar
        )
        #expect(deliveries.map(\.day) == Array(0...7))
        #expect(Set(deliveries.map(\.fireAt)).count == deliveries.count)
        for delivery in deliveries {
            let components = localCalendar.dateComponents(
                [.hour, .minute],
                from: delivery.fireAt
            )
            #expect(components.hour == 9)
            #expect(components.minute == 0)
        }
        let intervals = zip(deliveries, deliveries.dropFirst()).map {
            $1.fireAt.timeIntervalSince($0.fireAt)
        }
        #expect(intervals.contains(23 * 60 * 60))
    }

    @Test("Notification anchor waits for a late spoken baseline")
    func notificationAnchorFollowsSpokenContract() {
        let activationAt = date(1, hour: 8)
        let dayEight = date(9, hour: 12)

        #expect(
            FirstWeekNotificationSchedule.contractAnchor(
                activationAt: activationAt,
                sessions: [],
                now: dayEight
            ) == dayEight
        )

        let lateBaseline = session(at: date(9, hour: 10))
        let tooEarly = session(at: date(1, hour: 7))
        #expect(
            FirstWeekNotificationSchedule.contractAnchor(
                activationAt: activationAt,
                sessions: [tooEarly, lateBaseline],
                now: dayEight
            ) == lateBaseline.date
        )

        let plan = DailyRhythmNotificationPlan.resolve(
            activationAt: dayEight,
            now: dayEight,
            dailyReminderEnabled: true,
            streakWarningEnabled: true,
            weeklyDigestEnabled: true,
            calendar: calendar
        )
        #expect(plan.firstWeekWindowActive)
        #expect(plan.scheduleFirstWeekContract)
        #expect(!plan.scheduleDailyReminder)
    }

    @MainActor
    @Test("Future Day-7 notification projection cannot capture the durable read")
    func futureNotificationProjectionIsSideEffectFree() throws {
        let activationAt = date(1, hour: 8)
        let eligibleSessions = [
            session(at: date(1, hour: 12)),
            session(at: date(3)),
            session(at: date(7)),
        ]
        let deliveries = FirstWeekNotificationSchedule.deliveries(
            activationAt: activationAt,
            now: activationAt.addingTimeInterval(30 * 60),
            reminderHour: 9,
            reminderMinute: 0,
            calendar: calendar
        )
        let daySevenDelivery = try #require(deliveries.last)
        #expect(daySevenDelivery.day == FirstWeekCoachingContract.finalDay)

        let contractInput = input(
            activationAt: activationAt,
            sessions: eligibleSessions,
            memory: comparisonReadyMemory(
                prescribedAt: date(2),
                observedAt: date(7)
            )
        )
        let futureSnapshot = try #require(FirstWeekCoachingContract.resolve(
            input: contractInput,
            now: daySevenDelivery.fireAt,
            calendar: calendar
        ))
        #expect(futureSnapshot.nextAction == .reviewFirstWeekRead)
        #expect(futureSnapshot.firstWeekRead != nil)

        var captureCallCount = 0
        let projected = FirstWeekCoachingSnapshotResolver.applyingReadExposure(
            .projectionOnly,
            to: futureSnapshot,
            activation: contractInput.activation,
            eligibleSessions: eligibleSessions,
            now: daySevenDelivery.fireAt,
            calendar: calendar,
            capture: { _, _, _ in
                captureCallCount += 1
                return nil
            }
        )

        #expect(projected == futureSnapshot)
        #expect(captureCallCount == 0)
    }

    @MainActor
    @Test("Presenting the current Day-7 read captures before display")
    func currentReadPresentationCapturesDurableReceipt() throws {
        let activationAt = date(1, hour: 8)
        let eligibleSessions = [
            session(at: date(2)),
            session(at: date(3)),
            session(at: date(7)),
        ]
        let contractInput = input(
            activationAt: activationAt,
            sessions: eligibleSessions,
            memory: comparisonReadyMemory(
                prescribedAt: date(2),
                observedAt: date(7)
            )
        )
        let now = date(9, hour: 12)
        let liveSnapshot = try #require(FirstWeekCoachingContract.resolve(
            input: contractInput,
            now: now,
            calendar: calendar
        ))
        let candidate = try #require(liveSnapshot.firstWeekRead)

        var capturedAccountID: String?
        var capturedAt: Date?
        var captureCallCount = 0
        let presented = FirstWeekCoachingSnapshotResolver.applyingReadExposure(
            .captureForPresentation,
            to: liveSnapshot,
            activation: contractInput.activation,
            eligibleSessions: eligibleSessions,
            now: now,
            calendar: calendar,
            capture: { projection, accountID, date in
                captureCallCount += 1
                capturedAccountID = accountID
                capturedAt = date
                return FirstWeekCoachingContract.FirstWeekReadSnapshot(
                    capturedAt: date,
                    projection: projection
                )
            }
        )

        #expect(captureCallCount == 1)
        #expect(capturedAccountID == accountID)
        #expect(capturedAt == now)
        #expect(presented?.firstWeekRead == candidate)
    }

    @Test("Days zero through seven suppress generic rhythm notifications")
    func firstWeekNotificationPlanTimeTravel() {
        let activationAt = date(1, hour: 8)

        for elapsedDay in 0...FirstWeekCoachingContract.finalDay {
            let now = date(1 + elapsedDay, hour: 12)
            let plan = DailyRhythmNotificationPlan.resolve(
                activationAt: activationAt,
                now: now,
                dailyReminderEnabled: true,
                streakWarningEnabled: true,
                weeklyDigestEnabled: true,
                calendar: calendar
            )

            #expect(plan.firstWeekWindowActive)
            #expect(plan.scheduleFirstWeekContract)
            #expect(!plan.scheduleDailyReminder)
            #expect(!plan.scheduleStreakWarning)
            #expect(!plan.scheduleWeeklyDigest)
        }
    }

    @Test("First-week policy preserves opt-out and resumes ordinary rhythm on Day 8")
    func firstWeekNotificationPlanBoundary() {
        let activationAt = date(1, hour: 8)
        let optedOutDaily = DailyRhythmNotificationPlan.resolve(
            activationAt: activationAt,
            now: date(5),
            dailyReminderEnabled: false,
            streakWarningEnabled: true,
            weeklyDigestEnabled: true,
            calendar: calendar
        )
        #expect(optedOutDaily.firstWeekWindowActive)
        #expect(!optedOutDaily.scheduleFirstWeekContract)
        #expect(!optedOutDaily.scheduleStreakWarning)
        #expect(!optedOutDaily.scheduleWeeklyDigest)

        let dayEight = DailyRhythmNotificationPlan.resolve(
            activationAt: activationAt,
            now: date(9),
            dailyReminderEnabled: true,
            streakWarningEnabled: true,
            weeklyDigestEnabled: true,
            calendar: calendar
        )
        #expect(!dayEight.firstWeekWindowActive)
        #expect(!dayEight.scheduleFirstWeekContract)
        #expect(dayEight.scheduleDailyReminder)
        #expect(dayEight.scheduleStreakWarning)
        #expect(dayEight.scheduleWeeklyDigest)

        let futureActivation = DailyRhythmNotificationPlan.resolve(
            activationAt: activationAt,
            now: date(1, hour: 7),
            dailyReminderEnabled: true,
            streakWarningEnabled: true,
            weeklyDigestEnabled: true,
            calendar: calendar
        )
        #expect(!futureActivation.firstWeekWindowActive)
        #expect(futureActivation.scheduleDailyReminder)
        #expect(futureActivation.scheduleStreakWarning)
        #expect(futureActivation.scheduleWeeklyDigest)
    }

    @Test("Durable first-week read excludes sessions recorded after its evidence window")
    func durableReadKeepsFirstWeekEvidenceBounded() throws {
        let activationAt = date(1)
        let firstWeekID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        let laterID = UUID(uuidString: "88888888-8888-4888-8888-888888888888")!
        let snapshot = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: [
                    session(id: firstWeekID, at: date(8), score: 7),
                    session(at: date(10)),
                    session(at: date(14)),
                    session(id: laterID, at: date(17), score: 10),
                ],
                memory: comparisonReadyMemory(
                    prescribedAt: date(8),
                    observedAt: date(14)
                )
            ),
            now: date(20),
            calendar: calendar
        ))

        #expect(snapshot.stage == .day7FirstWeekRead)
        #expect(snapshot.eligibleSessionCount == 3)
        #expect(snapshot.firstWeekRead?.verifiedExample?.sessionID == firstWeekID)
    }

    @MainActor
    @Test("The first produced read is write-once and survives Day-8 memory rebuilds")
    func durableReadIsImmutableAcrossLaterMemoryAndTrajectoryChanges() throws {
        let activationAt = date(1)
        let firstID = UUID(uuidString: "91111111-1111-4111-8111-111111111111")!
        let secondID = UUID(uuidString: "92222222-2222-4222-8222-222222222222")!
        let sourceID = UUID(uuidString: "93333333-3333-4333-8333-333333333333")!
        let laterID = UUID(uuidString: "94444444-4444-4444-8444-444444444444")!
        let firstWeekSessions = [
            session(id: firstID, at: date(2), score: 5, isRated: true),
            session(id: secondID, at: date(3), score: 6, isRated: true),
            session(id: sourceID, at: date(7), score: 8, isRated: true),
        ]
        let firstWeekTrend = CoachLongitudinalTrendProjection(
            sourceSessionID: sourceID,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion,
            mode: PracticeMode.timed.displayLabel,
            comparableSessionIDs: [firstID, secondID],
            metrics: [
                CoachLongitudinalMetricTrend(
                    metric: .score,
                    direction: .improving,
                    currentValue: 8,
                    priorAverage: 5.5
                ),
            ]
        )
        let daySevenMemory = CoachMemory(
            updatedAt: date(7),
            evidenceCount: 3,
            evidenceConfidence: .moderate,
            currentLever: .structure,
            goalFit: .noVoice,
            strengths: [],
            blockers: []
        )
        let daySeven = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: firstWeekSessions,
                memory: daySevenMemory,
                longitudinalTrend: firstWeekTrend
            ),
            now: date(9),
            calendar: calendar
        ))
        let originalRead = try #require(daySeven.firstWeekRead)

        // Day 10 has a different memory read and a trajectory sourced from a
        // post-window rep. A live recomputation would therefore lose both the
        // original lever and qualified comparison.
        let laterTrend = CoachLongitudinalTrendProjection(
            sourceSessionID: laterID,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion,
            mode: PracticeMode.timed.displayLabel,
            comparableSessionIDs: [sourceID, secondID],
            metrics: [
                CoachLongitudinalMetricTrend(
                    metric: .score,
                    direction: .declining,
                    currentValue: 4,
                    priorAverage: 7
                ),
            ]
        )
        let dayTenMemory = CoachMemory(
            updatedAt: date(10),
            evidenceCount: 4,
            evidenceConfidence: .moderate,
            currentLever: .paceControl,
            goalFit: .noVoice,
            strengths: [],
            blockers: [],
            activeIntervention: comparisonReadyMemory(
                prescribedAt: date(2),
                observedAt: date(7)
            ).activeIntervention
        )
        let dayTen = try #require(FirstWeekCoachingContract.resolve(
            input: input(
                activationAt: activationAt,
                sessions: firstWeekSessions + [
                    session(id: laterID, at: date(10), score: 4, isRated: true),
                ],
                memory: dayTenMemory,
                longitudinalTrend: laterTrend
            ),
            now: date(10),
            calendar: calendar
        ))
        let recomputedLaterRead = try #require(dayTen.firstWeekRead)
        #expect(recomputedLaterRead != originalRead)

        let suiteName = "FirstWeekImmutable.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let activeAccount: String? = accountID
        let store = CoachMemoryStore(
            defaults: defaults,
            accountIDProvider: { activeAccount }
        )
        store.replaceForTesting(daySevenMemory)

        let captured = try #require(store.captureFirstWeekReadIfNeeded(
            originalRead,
            expectedAccountID: accountID,
            capturedAt: date(9)
        ))
        let secondCapture = try #require(store.captureFirstWeekReadIfNeeded(
            recomputedLaterRead,
            expectedAccountID: accountID,
            capturedAt: date(10)
        ))
        #expect(secondCapture == captured)
        #expect(store.currentMemory?.firstWeekReadSnapshot == captured)

        // The normal Day-8+ CoachMemoryEngine rebuild must carry the receipt
        // even while every live trajectory input changes.
        let rebuilt = try #require(CoachMemoryEngine.build(
            profile: nil,
            baseline: .empty,
            sessions: [session(id: laterID, at: date(10), score: 4)],
            trends: [],
            forwardPlan: nil,
            previous: store.currentMemory,
            lastSessionID: laterID,
            now: date(10),
            calendar: calendar
        ))
        #expect(rebuilt.firstWeekReadSnapshot == captured)
    }

    @Test("Saved read references fail closed without mutating the receipt")
    func savedReadReferencesRemainFailClosed() throws {
        let activationAt = date(1)
        let firstID = UUID(uuidString: "A1111111-1111-4111-8111-111111111111")!
        let secondID = UUID(uuidString: "A2222222-2222-4222-8222-222222222222")!
        let sourceID = UUID(uuidString: "A3333333-3333-4333-8333-333333333333")!
        let first = session(id: firstID, at: date(2), score: 5, isRated: true)
        let second = session(id: secondID, at: date(3), score: 6, isRated: true)
        let source = session(id: sourceID, at: date(7), score: 8, isRated: true)
        let trend = CoachLongitudinalTrendProjection(
            sourceSessionID: sourceID,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion,
            mode: PracticeMode.timed.displayLabel,
            comparableSessionIDs: [firstID, secondID],
            metrics: [
                CoachLongitudinalMetricTrend(
                    metric: .score,
                    direction: .improving,
                    currentValue: 8,
                    priorAverage: 5.5
                ),
            ]
        )
        let original = FirstWeekCoachingContract.FirstWeekReadProjection(
            whatChanged: .verifiedComparison(trend),
            remainsUnproven: [.realWorldOutcome, .durability],
            verifiedExample: .init(
                sessionID: sourceID,
                recordedAt: source.date,
                mode: source.mode,
                score: source.score,
                comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion
            ),
            nextWeekPlan: .init(
                lever: .structure,
                mode: .timed,
                remainingComparableRepsBeforeReview: 1,
                recommendedAction: .repeatRep(mode: .timed)
            )
        )
        let saved = FirstWeekCoachingContract.FirstWeekReadSnapshot(
            capturedAt: date(8),
            projection: original
        )
        let activation = try #require(FirstWeekCoachingContract.ActivationReceipt(
            accountID: accountID,
            draft: activationDraft(at: activationAt)
        ))

        let withLaterRep = FirstWeekCoachingContract.displayProjection(
            from: saved,
            activation: activation,
            sessions: [first, second, source, session(at: date(12), score: 10)],
            now: date(20),
            calendar: calendar
        )
        #expect(withLaterRep == original)

        let missingSources = FirstWeekCoachingContract.displayProjection(
            from: saved,
            activation: activation,
            sessions: [first],
            now: date(20),
            calendar: calendar
        )
        #expect(missingSources.whatChanged == .notYetProven(eligibleRepCount: 1))
        #expect(missingSources.remainsUnproven.first == .practiceChange)
        #expect(missingSources.verifiedExample == nil)
        #expect(saved.projection == original)
    }

    @MainActor
    @Test("Saved reads are isolated by account switch and removed by account deletion")
    func savedReadAccountIsolationAndDeletion() throws {
        let accountA = "first-week-a"
        let accountB = "first-week-b"
        let suiteName = "FirstWeekAccounts.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var activeAccount: String? = accountA
        let store = CoachMemoryStore(
            defaults: defaults,
            accountIDProvider: { activeAccount }
        )
        let baseMemory = CoachMemory(
            updatedAt: date(7),
            evidenceCount: 2,
            evidenceConfidence: .tentative,
            goalFit: .noLever,
            strengths: [],
            blockers: []
        )
        let readA = FirstWeekCoachingContract.FirstWeekReadProjection(
            whatChanged: .notYetProven(eligibleRepCount: 2),
            remainsUnproven: [.practiceChange, .realWorldOutcome, .durability],
            verifiedExample: nil,
            nextWeekPlan: .init(
                lever: .structure,
                mode: .timed,
                remainingComparableRepsBeforeReview: 1,
                recommendedAction: .repeatRep(mode: .timed)
            )
        )
        let readB = FirstWeekCoachingContract.FirstWeekReadProjection(
            whatChanged: .notYetProven(eligibleRepCount: 1),
            remainsUnproven: [.practiceChange, .realWorldOutcome, .durability],
            verifiedExample: nil,
            nextWeekPlan: .init(
                lever: .paceControl,
                mode: .suddenDeath,
                remainingComparableRepsBeforeReview: 2,
                recommendedAction: .repeatRep(mode: .suddenDeath)
            )
        )

        store.replaceForTesting(baseMemory)
        let savedA = try #require(store.captureFirstWeekReadIfNeeded(
            readA,
            expectedAccountID: accountA,
            capturedAt: date(8)
        ))
        #expect(store.captureFirstWeekReadIfNeeded(
            readB,
            expectedAccountID: accountB,
            capturedAt: date(8)
        ) == nil)

        activeAccount = accountB
        store.reloadForCurrentAccount()
        #expect(store.currentMemory == nil)
        store.replaceForTesting(baseMemory)
        let savedB = try #require(store.captureFirstWeekReadIfNeeded(
            readB,
            expectedAccountID: accountB,
            capturedAt: date(8)
        ))

        activeAccount = accountA
        store.reloadForCurrentAccount()
        #expect(store.currentMemory?.firstWeekReadSnapshot == savedA)
        #expect(store.currentMemory?.firstWeekReadSnapshot != savedB)
        store.deleteAllData(for: accountA)
        #expect(store.currentMemory == nil)

        activeAccount = accountB
        store.reloadForCurrentAccount()
        #expect(store.currentMemory?.firstWeekReadSnapshot == savedB)
        store.deleteAllData(for: accountB)
        #expect(store.currentMemory == nil)
    }

    @Test("A missing referenced transcript never falls back to another session")
    func verifiedExampleIdentityFailsClosed() {
        let referenced = session(at: date(2), transcript: "", score: 9)
        let alternate = session(at: date(3), transcript: "A different valid line.", score: 10)

        #expect(
            VerifiedExampleTranscriptResolver.session(
                referenceID: referenced.id,
                allEligibleSessions: [referenced, alternate],
                rollingWeeklySessions: [referenced, alternate]
            ) == nil
        )
        #expect(
            VerifiedExampleTranscriptResolver.session(
                referenceID: nil,
                allEligibleSessions: [referenced, alternate],
                rollingWeeklySessions: [referenced, alternate]
            )?.id == alternate.id
        )
    }

    @MainActor
    @Test("User-initiated spoken proof seeds Timed without arming microphone capture")
    func userInitiatedProofNeverQuickStarts() throws {
        let proofAccount = "first-week-proof-\(UUID().uuidString)"
        let completedKey = AutoGuidedFirstRep.completedKeyPrefix + proofAccount
        defer {
            UserDefaults.standard.removeObject(forKey: completedKey)
            AutoGuidedFirstRep.cancelPendingLaunch()
        }
        UserDefaults.standard.removeObject(forKey: completedKey)
        AutoGuidedFirstRep.cancelPendingLaunch()

        let preparation = try #require(
            AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(accountID: proofAccount)
        )
        #expect(!preparation.automaticallyStartsCapture)
        #expect(!PracticeModeQuickStart.consume(for: .timed))
        #expect(!AutoGuidedFirstRep.consumeFastStartOnce())
        #expect(
            TimedPracticePromptHandoff.shared.pendingPrompt(accountID: proofAccount)
                == AutoGuidedFirstRep.framingPrompt
        )

        let route = try #require(AutoGuidedFirstRep.routeURL(for: preparation))
        #expect(
            AppTab.pushedDestination(for: route)
                == .timedPracticePrompt(
                    token: preparation.promptToken!,
                    difficulty: .medium
                )
        )
        let replacement = try #require(
            AutoGuidedFirstRep.prepareUserInitiatedSpokenProof(accountID: proofAccount)
        )
        #expect(replacement.promptToken != preparation.promptToken)
        #expect(!replacement.automaticallyStartsCapture)
        #expect(!PracticeModeQuickStart.consume(for: .timed))
        #expect(!AutoGuidedFirstRep.consumeFastStartOnce())
    }
}
