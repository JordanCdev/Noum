import Foundation
import Testing
@testable import Noum

@Suite("Communication curriculum expansion")
struct CommunicationCurriculumExpansionTests {
    @Test func catalogCoversSpeakingListeningExplanationAndRepair() {
        #expect(LessonsCatalog.all.count == 12)
        #expect(Set(LessonsCatalog.all.map(\.id)).count == LessonsCatalog.all.count)

        let categories = Set(LessonsCatalog.all.map(\.category))
        #expect(categories == Set(Lesson.Category.allCases))

        let required = [
            "listen_for_meaning",
            "ask_a_better_question",
            "check_understanding",
            "make_it_plain",
            "give_useful_feedback",
            "set_a_clear_boundary",
            "repair_the_conversation"
        ]
        for id in required {
            #expect(LessonsCatalog.lesson(id: id) != nil)
        }
    }

    @Test func everyLessonHasACompleteLearningLoop() {
        for lesson in LessonsCatalog.all {
            #expect(lesson.steps.count == 3, "\(lesson.id) should keep Concept, Spot it, Apply")
            #expect(!lesson.transferPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!LessonApplyEvaluator.effectiveCriteria(for: lesson).isEmpty)
            #expect(!lesson.reviewPrompts.isEmpty, "\(lesson.id) should test the skill on a fresh review prompt")
        }
    }

    @Test func listeningRequiresReflectionAndAUnderstandingCheck() {
        let lesson = LessonsCatalog.listenForMeaning
        let strong = LessonApplyEvaluator.evaluate(
            transcript: "It sounds like being left out of the change matters more than the workload. Did I get that right?",
            findings: [],
            lesson: lesson
        )
        let adviceOnly = LessonApplyEvaluator.evaluate(
            transcript: "You should ask the manager to send updates earlier and create a better process for everybody next time.",
            findings: [],
            lesson: lesson
        )

        #expect(strong.passed)
        #expect(!adviceOnly.passed)
        #expect(adviceOnly.firstMiss?.criterionID == "listen.reflect")
    }

    @Test func questionLessonRequiresTwoQuestionSignals() {
        let lesson = LessonsCatalog.askABetterQuestion
        let strong = LessonApplyEvaluator.evaluate(
            transcript: "What changed during the client call? Which moment made the conversation turn?",
            findings: [],
            lesson: lesson
        )
        let single = LessonApplyEvaluator.evaluate(
            transcript: "What changed during the client call and the rest of the discussion with the team?",
            findings: [],
            lesson: lesson
        )

        #expect(strong.passed)
        #expect(!single.passed)
    }

    @Test func feedbackNeedsBehaviorImpactAndRequest() {
        let lesson = LessonsCatalog.giveUsefulFeedback
        let strong = LessonApplyEvaluator.evaluate(
            transcript: "When the slide changed after approval, I presented the old version, so I gave the client the wrong number. Next time, could you message me before changing it?",
            findings: [],
            lesson: lesson
        )
        let labelOnly = LessonApplyEvaluator.evaluate(
            transcript: "You need to communicate better because this kind of thing is frustrating and it cannot keep happening.",
            findings: [],
            lesson: lesson
        )

        #expect(strong.passed)
        #expect(!labelOnly.passed)
    }

    @Test func plainLanguageCheckRejectsJargonAndMissingExample() {
        let lesson = LessonsCatalog.makeItPlain
        let clear = LessonApplyEvaluator.evaluate(
            transcript: "The review catches mistakes before clients see them. For example, a second person checks every total before the report goes out.",
            findings: [],
            lesson: lesson
        )
        let abstract = LessonApplyEvaluator.evaluate(
            transcript: "We leverage a cross functional paradigm to operationalize strategic alignment across the relevant workstreams and stakeholder groups.",
            findings: [],
            lesson: lesson
        )

        #expect(clear.passed)
        #expect(!abstract.passed)
    }

    @Test func twelveWordsNoLongerClearsInterpersonalLessonsByItself() {
        let generic = "These are twelve ordinary words that do not demonstrate the requested communication skill today"
        for lesson in [
            LessonsCatalog.listenForMeaning,
            LessonsCatalog.checkUnderstanding,
            LessonsCatalog.giveUsefulFeedback,
            LessonsCatalog.setAClearBoundary,
            LessonsCatalog.repairTheConversation
        ] {
            #expect(!LessonApplyEvaluator.evaluate(transcript: generic, findings: [], lesson: lesson).passed)
        }
    }

    @Test func everyLessonRequiresAVisibleCompleteResponseCriterion() {
        for lesson in LessonsCatalog.all {
            let criteria = LessonApplyEvaluator.effectiveCriteria(for: lesson)
            let quantityFloors = criteria.compactMap { criterion -> Int? in
                switch criterion.kind {
                case .minimumWords(let minimum): return minimum
                case .wordRange(let minimum, _): return minimum
                default: return nil
                }
            }

            #expect(!quantityFloors.isEmpty, "\(lesson.id) needs an explicit response floor")
            #expect(
                LessonApplyEvaluator.minimumWordCount(for: lesson) == (quantityFloors.max() ?? 0),
                "\(lesson.id) should derive one authoritative word floor"
            )
        }
    }

    @Test func keywordFragmentsCannotClearLessons() {
        let fixtures: [(Lesson, String)] = [
            (LessonsCatalog.checkUnderstanding, "send Thursday correct"),
            (LessonsCatalog.giveUsefulFeedback, "changed because please"),
            (LessonsCatalog.setAClearBoundary, "I can't because tomorrow"),
            (LessonsCatalog.repairTheConversation, "I'm sorry dismissive next time"),
        ]

        for (lesson, transcript) in fixtures {
            let evaluation = LessonApplyEvaluator.evaluate(
                transcript: transcript,
                findings: [],
                lesson: lesson
            )
            #expect(!evaluation.passed, "\(lesson.id) accepted keyword-only speech")
            #expect(evaluation.firstMiss?.criterionID == "complete-answer")
        }
    }

    @Test func deviceDetectionCannotClearAThinLessonResponse() {
        let fixtures: [(Lesson, EloquenceDevice, String)] = [
            (LessonsCatalog.ruleOfThree, .tricolon, "Fast clean clear"),
            (LessonsCatalog.repeatToStick, .anaphora, "We listen. We act."),
        ]

        for (lesson, device, transcript) in fixtures {
            let evaluation = LessonApplyEvaluator.evaluate(
                transcript: transcript,
                findings: [EloquenceFinding(
                    device: device,
                    snippet: transcript,
                    coachLine: "Detected fixture"
                )],
                lesson: lesson
            )
            #expect(!evaluation.passed, "\(lesson.id) accepted a device-only fragment")
            #expect(evaluation.firstMiss?.criterionID == "complete-answer")
        }
    }

    @Test func authoredResponseFloorsRemainAuthoritative() {
        #expect(LessonApplyEvaluator.minimumWordCount(for: LessonsCatalog.askABetterQuestion) == 10)
        #expect(LessonApplyEvaluator.minimumWordCount(for: LessonsCatalog.listenForMeaning) == 14)
        #expect(LessonApplyEvaluator.minimumWordCount(for: LessonsCatalog.pauseBeatsFiller) == 18)
        #expect(LessonApplyEvaluator.minimumWordCount(for: LessonsCatalog.makeItPlain) == 20)
        #expect(LessonApplyEvaluator.minimumWordCount(for: LessonsCatalog.checkUnderstanding) == 12)
        #expect(LessonApplyEvaluator.minimumWordCount(for: LessonsCatalog.ruleOfThree) == 12)
    }
}

@Suite("Lesson spaced review")
struct LessonSpacedReviewTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test func firstSuccessfulRoundIsImmediateThenReviewWaitsOneDay() {
        let fresh = LessonProgress.empty(lessonID: "lesson")
        #expect(LessonReviewSchedule.canCountAnotherPass(for: fresh, now: now))

        let completed = LessonProgress(
            lessonID: "lesson",
            practicePassCount: 1,
            lastCompletedAt: now,
            totalAttempts: 1,
            lastPassedAt: now
        )
        #expect(!LessonReviewSchedule.canCountAnotherPass(for: completed, now: now))
        #expect(!LessonReviewSchedule.canCountAnotherPass(for: completed, now: now.addingTimeInterval(86_399)))
        #expect(LessonReviewSchedule.canCountAnotherPass(for: completed, now: now.addingTimeInterval(86_400)))
    }

    @Test func intervalsExpandAcrossRetentionRounds() {
        let expectedDays = [1, 3, 7, 14, 30]
        for (offset, expectedDays) in expectedDays.enumerated() {
            let passCount = offset + 1
            let progress = LessonProgress(
                lessonID: "lesson",
                practicePassCount: passCount,
                lastCompletedAt: now,
                totalAttempts: passCount,
                lastPassedAt: now
            )
            let due = LessonReviewSchedule.dueDate(for: progress)
            #expect(due == now.addingTimeInterval(TimeInterval(expectedDays) * 86_400))
        }
    }

    @Test func dueReviewTakesPriorityOverNewContent() throws {
        let dueLesson = LessonsCatalog.pauseBeatsFiller
        let newLesson = LessonsCatalog.listenForMeaning
        let oldPass = now.addingTimeInterval(-2 * 86_400)
        let progress = LessonProgress(
            lessonID: dueLesson.id,
            practicePassCount: 1,
            lastCompletedAt: oldPass,
            totalAttempts: 1,
            lastPassedAt: oldPass
        )

        let recommendation = LessonRecommendationEngine.recommendedLesson(
            catalog: [dueLesson, newLesson],
            progressByID: [dueLesson.id: progress],
            now: now
        )
        #expect(recommendation?.id == dueLesson.id)
    }

    @Test func newContentIsRecommendedWhilePriorSkillIsWaiting() {
        let waitingLesson = LessonsCatalog.pauseBeatsFiller
        let newLesson = LessonsCatalog.listenForMeaning
        let progress = LessonProgress(
            lessonID: waitingLesson.id,
            practicePassCount: 1,
            lastCompletedAt: now,
            totalAttempts: 1,
            lastPassedAt: now
        )

        let recommendation = LessonRecommendationEngine.recommendedLesson(
            catalog: [waitingLesson, newLesson],
            progressByID: [waitingLesson.id: progress],
            now: now
        )
        #expect(recommendation?.id == newLesson.id)
    }

    @Test func reviewCopyExplainsTheWaitWithoutGamification() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let progress = LessonProgress(
            lessonID: "lesson",
            practicePassCount: 2,
            lastCompletedAt: now,
            totalAttempts: 2,
            lastPassedAt: now
        )
        let line = LessonReviewPresentation(progress: progress, now: now, calendar: calendar).rowLabel

        #expect(line == "2 spaced rounds · Review in 3 days")
        #expect(!line.localizedCaseInsensitiveContains("streak"))
        #expect(!line.localizedCaseInsensitiveContains("crown"))
    }

    @Test func legacySuccessfulProgressMigratesItsReviewAnchor() throws {
        let data = #"{"lessonID":"lesson","practicePassCount":2,"lastCompletedAt":1000,"totalAttempts":3}"#
            .data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LessonProgress.self, from: data)

        #expect(decoded.lastPassedAt == decoded.lastCompletedAt)
        #expect(decoded.lastPassedAt != nil)
    }
}

@Suite("Interpersonal roleplay axes")
struct InterpersonalRoleplayAxisTests {
    @Test func expandedCatalogHasNoDuplicateScenarioOrObjectionIDs() {
        #expect(RoleplayCatalog.all.count == 8)
        #expect(Set(RoleplayCatalog.all.map(\.scenarioId)).count == RoleplayCatalog.all.count)
        let objections = RoleplayCatalog.all.flatMap(\.objectionSet).map(\.id)
        #expect(Set(objections).count == objections.count)
    }

    @Test func everyRubricUsesAnImplementedAxis() {
        let known = Set([
            "Directness", "Evidence", "Composure", "Listening",
            "Ownership", "Constructiveness", "Inquiry"
        ])
        for criterion in RoleplayCatalog.all.flatMap(\.rubric) {
            #expect(known.contains(criterion.label), "Unknown roleplay axis: \(criterion.label)")
        }
    }

    @Test func repairSignalsOutscoreDeflection() {
        let rubric = RoleplayCatalog.repairTrust.rubric
        let repair = "I hear why you felt excluded. I should have brought you in before I decided. Next time, I will check with you first."
        let deflection = "I guess the deadline was difficult and maybe everybody could have communicated more clearly about the situation."
        #expect(RoleplayEngine.score(response: repair, rubric: rubric) > RoleplayEngine.score(response: deflection, rubric: rubric))
    }

    @Test func discoveryQuestionsOutscorePrematureAdvice() {
        let rubric = RoleplayCatalog.discoveryConversation.rubric
        let discovery = "It sounds like the workaround is hiding the real issue. What happens just before people leave the process? Which team sees it most?"
        let advice = "You should retrain everyone and tell them to follow the process because consistency will solve the problem."
        #expect(RoleplayEngine.score(response: discovery, rubric: rubric) > RoleplayEngine.score(response: advice, rubric: rubric))
    }
}
