import Foundation
import Testing
@testable import Noum

@Suite("Forward plan phrase handoff")
struct ForwardPlanPhraseHandoffTests {
    @Test func assignmentPreservesGeneratedPlanAndChangesOnlyRequestedWeek() throws {
        let plan = makePlan()
        let entryID = UUID()
        let updated = try #require(
            plan.assigningPracticePhrase(entryID: entryID, toWeek: 2)
        )

        #expect(updated.id == plan.id)
        #expect(updated.weeks == plan.weeks)
        #expect(updated.generatedAt == plan.generatedAt)
        #expect(updated.bigMomentID == plan.bigMomentID)
        #expect(updated.voiceAtGeneration == plan.voiceAtGeneration)
        #expect(updated.isAIBacked == plan.isAIBacked)
        #expect(updated.practicePhraseEntryID(forWeek: 1) == nil)
        #expect(updated.practicePhraseEntryID(forWeek: 2) == entryID)
        #expect(updated.practicePhraseEntryID(forWeek: 5) == nil)
    }

    @Test func invalidWeekCannotCreateAParallelPlanShape() {
        let plan = makePlan()

        #expect(plan.assigningPracticePhrase(entryID: UUID(), toWeek: 0) == nil)
        #expect(plan.assigningPracticePhrase(entryID: UUID(), toWeek: 5) == nil)
        #expect(plan.practicePhraseEntryIDsByWeek == nil)
    }

    @Test func activeWeekProjectionResolvesExactSavedPhrase() throws {
        let calendar = utcCalendar()
        let generatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let now = try #require(calendar.date(byAdding: .day, value: 8, to: generatedAt))
        let chosen = makeEntry(text: "Lead with the decision, then give one reason.")
        let other = makeEntry(text: "Name the ask and stop cleanly.")
        let assigned = try #require(
            makePlan(generatedAt: generatedAt)
                .assigningPracticePhrase(entryID: chosen.id, toWeek: 2)
        )

        let projection = try #require(ForwardPlanPhraseProjection.resolve(
            plan: assigned,
            entries: [other, chosen],
            now: now,
            calendar: calendar
        ))

        #expect(projection.target.planID == assigned.id)
        #expect(projection.target.weekIndex == 2)
        #expect(projection.target.assignedEntryID == chosen.id)
        #expect(projection.entry == chosen)
        #expect(projection.practiceIntent.sourceEntryID == chosen.id)
        #expect(projection.practiceIntent.suggestedPrompt == PhrasePracticeIntent.promptPrefix + chosen.text)
    }

    @Test func removedOrUnsafePhraseFailsClosed() throws {
        let safe = makeEntry(text: "Lead with the outcome, then explain the tradeoff.")
        let plan = try #require(
            makePlan().assigningPracticePhrase(entryID: safe.id, toWeek: 1)
        )
        let unsafe = PhraseBankEntry(
            id: safe.id,
            text: "Call +44 7700 900123 after the meeting.",
            voice: .warm,
            weakness: .closing,
            intensity: .light
        )

        #expect(ForwardPlanPhraseProjection.resolve(plan: plan, entries: []) == nil)
        #expect(ForwardPlanPhraseProjection.resolve(plan: plan, entries: [unsafe]) == nil)
    }

    @Test func assignmentRevalidatesPlanWeekExistingLinkAndEntryMembership() throws {
        let entry = makeEntry(text: "Lead with the decision, then stop.")
        let plan = makePlan()
        let renderedTarget = try #require(
            ForwardPlanPhraseProjection.target(plan: plan)
        )

        #expect(ForwardPlanPhraseCoordinator.validatesAssignment(
            entryID: entry.id,
            renderedTarget: renderedTarget,
            currentPlan: plan,
            entries: [entry]
        ))
        #expect(!ForwardPlanPhraseCoordinator.validatesAssignment(
            entryID: entry.id,
            renderedTarget: renderedTarget,
            currentPlan: nil,
            entries: [entry]
        ))
        #expect(!ForwardPlanPhraseCoordinator.validatesAssignment(
            entryID: entry.id,
            renderedTarget: renderedTarget,
            currentPlan: plan,
            entries: []
        ))

        let changedPlan = try #require(
            plan.assigningPracticePhrase(
                entryID: UUID(),
                toWeek: renderedTarget.weekIndex
            )
        )
        #expect(!ForwardPlanPhraseCoordinator.validatesAssignment(
            entryID: entry.id,
            renderedTarget: renderedTarget,
            currentPlan: changedPlan,
            entries: [entry]
        ))
    }

    @Test func deletingEntryClearsEveryReferenceWithoutChangingPlanProvenance() throws {
        let removedID = UUID()
        let retainedID = UUID()
        let plan = ForwardPlan(
            id: UUID(),
            weeks: makeWeeks(),
            generatedAt: Date(timeIntervalSince1970: 42),
            bigMomentID: UUID(),
            voiceAtGeneration: .executive,
            isAIBacked: true,
            practicePhraseEntryIDsByWeek: [1: removedID, 2: retainedID, 4: removedID]
        )

        let updated = plan.removingPracticePhrase(entryID: removedID)

        #expect(updated.id == plan.id)
        #expect(updated.weeks == plan.weeks)
        #expect(updated.bigMomentID == plan.bigMomentID)
        #expect(updated.voiceAtGeneration == plan.voiceAtGeneration)
        #expect(updated.isAIBacked)
        #expect(updated.practicePhraseEntryID(forWeek: 1) == nil)
        #expect(updated.practicePhraseEntryID(forWeek: 2) == retainedID)
        #expect(updated.practicePhraseEntryID(forWeek: 4) == nil)
    }

    @Test func reconciliationClearsEvictedAndFilteredEntryLinks() throws {
        let validID = UUID()
        let evictedID = UUID()
        let filteredID = UUID()
        let plan = ForwardPlan(
            weeks: makeWeeks(),
            generatedAt: Date(timeIntervalSince1970: 42),
            voiceAtGeneration: .executive,
            isAIBacked: false,
            practicePhraseEntryIDsByWeek: [
                1: validID,
                2: evictedID,
                3: filteredID,
            ]
        )

        let reconciled = plan.reconcilingPracticePhrases(
            validEntryIDs: [validID]
        )

        #expect(reconciled.practicePhraseEntryID(forWeek: 1) == validID)
        #expect(reconciled.practicePhraseEntryID(forWeek: 2) == nil)
        #expect(reconciled.practicePhraseEntryID(forWeek: 3) == nil)
    }

    @Test func legacyPersistedPlanWithoutPhraseLinksStillDecodes() throws {
        let original = makePlan()
        let currentData = try JSONEncoder().encode(original)
        var object = try #require(
            JSONSerialization.jsonObject(with: currentData) as? [String: Any]
        )
        object.removeValue(forKey: "practicePhraseEntryIDsByWeek")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ForwardPlan.self, from: legacyData)

        #expect(decoded.id == original.id)
        #expect(decoded.weeks == original.weeks)
        #expect(decoded.practicePhraseEntryIDsByWeek == nil)
    }

    private func makePlan(
        generatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ForwardPlan {
        ForwardPlan(
            id: UUID(),
            weeks: makeWeeks(),
            generatedAt: generatedAt,
            bigMomentID: UUID(),
            voiceAtGeneration: .concise,
            isAIBacked: false
        )
    }

    private func makeWeeks() -> [PlanWeek] {
        [
            PlanWeek(
                weekIndex: 1,
                focus: .moreConcise,
                focusSkillArea: .conciseSpeaking,
                suggestedMode: .timed,
                sessionTarget: 3,
                rationale: "Start with one clean decision line."
            ),
            PlanWeek(
                weekIndex: 2,
                focus: .thinkFaster,
                focusSkillArea: .structure,
                suggestedMode: .imConversation,
                sessionTarget: 3,
                rationale: "Keep the answer shaped under interaction."
            ),
            PlanWeek(
                weekIndex: 3,
                focus: .reduceFillers,
                focusSkillArea: .fillerReduction,
                suggestedMode: .suddenDeath,
                sessionTarget: 3,
                rationale: "Test the line under pressure."
            ),
            PlanWeek(
                weekIndex: 4,
                focus: .calmerDelivery,
                focusSkillArea: .paceControl,
                suggestedMode: .ahCounter,
                sessionTarget: 3,
                rationale: "Carry control into a full answer."
            ),
        ]
    }

    private func makeEntry(text: String) -> PhraseBankEntry {
        PhraseBankEntry(
            id: UUID(),
            text: text,
            voice: .concise,
            weakness: .structure,
            intensity: .medium,
            savedAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
