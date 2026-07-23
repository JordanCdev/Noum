import Testing
@testable import Noum

@Suite("Path journey visual alignment")
struct PathJourneyVisualAlignmentTests {
    @Test func projectionShowsOneCompleteCurrentAndUpcomingLandmark() {
        let statuses = [
            status("baseline", title: "Establish a baseline", isComplete: true),
            status("repeat", title: "Make it repeatable", isCurrent: true),
            status("transfer", title: "Use it under pressure"),
            status("real-world", title: "Take it into the room")
        ]

        let projection = PathJourneyProgressProjection.make(
            statuses: statuses,
            evidenceDays: 12,
            currentGatingPhrase: "Complete the prescribed retry."
        )

        #expect(projection.statusLine == "Stage 2 of 4 · 12 evidence days")
        #expect(projection.completed?.id == "baseline")
        #expect(projection.completed?.state == .complete)
        #expect(projection.current.id == "repeat")
        #expect(projection.current.state == .current)
        #expect(projection.current.detail == "Complete the prescribed retry.")
        #expect(projection.upcoming?.id == "transfer")
        #expect(projection.upcoming?.state == .upcoming)
        #expect(projection.current.accessibilityLabel == "Current landmark, Make it repeatable. Complete the prescribed retry.")
    }

    @Test func emptyPathOffersAnHonestFirstStepWithoutInventingProgress() {
        let projection = PathJourneyProgressProjection.make(
            statuses: [],
            evidenceDays: -3,
            currentGatingPhrase: nil
        )

        #expect(projection.statusLine == "Path ready · 0 evidence days")
        #expect(projection.completed == nil)
        #expect(projection.current.state == .current)
        #expect(projection.current.title == "Start your path")
        #expect(projection.upcoming == nil)
    }

    @Test func completedPathUsesAQuietCompletionStateAndSingularEvidenceDay() {
        let projection = PathJourneyProgressProjection.make(
            statuses: [
                status("baseline", title: "Establish a baseline", isComplete: true),
                status("transfer", title: "Transfer the skill", isComplete: true)
            ],
            evidenceDays: 1,
            currentGatingPhrase: nil
        )

        #expect(projection.statusLine == "Stage 2 of 2 · 1 evidence day")
        #expect(projection.completed == nil)
        #expect(projection.current.id == "path.complete")
        #expect(projection.current.state == .complete)
        #expect(projection.current.title == "Path complete")
        #expect(projection.upcoming == nil)
    }

    @Test func legacyUnlockCopyIsPresentedAsEvidenceNeeded() {
        let projection = PathJourneyProgressProjection.make(
            statuses: [
                status("conversation", title: "First conversation rep", isCurrent: true),
                status("lesson", title: "First lesson cleared")
            ],
            evidenceDays: 2,
            currentGatingPhrase: "Complete 1 rep in Conversation Practice to unlock."
        )

        #expect(projection.current.detail == "Complete 1 rep in Conversation Practice.")
        #expect(!projection.current.detail.localizedCaseInsensitiveContains("unlock"))
    }

    private func status(
        _ id: String,
        title: String,
        isComplete: Bool = false,
        isCurrent: Bool = false
    ) -> PathNodeStatus {
        PathNodeStatus(
            node: PathNode(
                id: id,
                order: 0,
                tier: .bronze,
                title: title,
                detail: "Evidence-linked detail for \(title).",
                coachLine: "A restrained coach line.",
                actionLabel: "Start a rep",
                actionDestination: .practiceSelection,
                symbolName: "circle"
            ),
            progress: isComplete ? 1 : 0,
            isComplete: isComplete,
            isCurrent: isCurrent
        )
    }
}
