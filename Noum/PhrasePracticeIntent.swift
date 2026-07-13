import Foundation

/// A transient bridge from one explicitly saved phrase into the existing
/// Timed Practice prompt handoff. This value owns no persistence and carries
/// no source transcript or session metadata.
@available(iOS 17.0, macOS 12.0, *)
struct PhrasePracticeIntent: Equatable {
    static let promptPrefix = "Say this line in your own voice: "
    static let maximumSuggestedPromptCharacters =
        promptPrefix.count + PhraseBankStore.maximumTextCharacters

    let sourceEntryID: UUID
    let suggestedPrompt: String

    init?(entry: PhraseBankEntry) {
        guard let phrase = PhraseBankStore.sanitizedText(entry.text) else {
            return nil
        }

        let prompt = Self.promptPrefix + phrase
        guard prompt.count <= Self.maximumSuggestedPromptCharacters else {
            return nil
        }

        sourceEntryID = entry.id
        suggestedPrompt = prompt
    }
}

/// Stable target for attaching a Phrase Bank entry to the week the user is
/// actually in. Callers capture this value when they render an action, then
/// pass its plan identity back to `ForwardPlanStore` so regeneration cannot
/// redirect a delayed tap into a different plan.
@available(iOS 17.0, macOS 12.0, *)
struct ForwardPlanPhraseTarget: Equatable {
    let planID: UUID
    let weekIndex: Int
    let assignedEntryID: UUID?
}

/// Read-only projection joining the existing Forward Plan and Phrase Bank
/// owners. It persists no text and fails closed when a linked phrase has been
/// removed or no longer passes the Phrase Bank privacy boundary.
@available(iOS 17.0, macOS 12.0, *)
struct ForwardPlanPhraseProjection: Equatable {
    let target: ForwardPlanPhraseTarget
    let entry: PhraseBankEntry
    let practiceIntent: PhrasePracticeIntent

    static func target(
        plan: ForwardPlan?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ForwardPlanPhraseTarget? {
        guard let plan,
              let week = plan.currentWeek(now: now, calendar: calendar) else {
            return nil
        }
        return ForwardPlanPhraseTarget(
            planID: plan.id,
            weekIndex: week.weekIndex,
            assignedEntryID: plan.practicePhraseEntryID(forWeek: week.weekIndex)
        )
    }

    static func resolve(
        plan: ForwardPlan?,
        entries: [PhraseBankEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ForwardPlanPhraseProjection? {
        guard let target = target(plan: plan, now: now, calendar: calendar),
              let entryID = target.assignedEntryID,
              let entry = entries.first(where: { $0.id == entryID }),
              let practiceIntent = PhrasePracticeIntent(entry: entry) else {
            return nil
        }
        return ForwardPlanPhraseProjection(
            target: target,
            entry: entry,
            practiceIntent: practiceIntent
        )
    }
}
