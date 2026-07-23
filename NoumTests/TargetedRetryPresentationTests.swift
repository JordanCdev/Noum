import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Targeted retry presentation")
struct TargetedRetryPresentationTests {
    @Test("Source-bound retry keeps the exact prompt and target")
    func sourceBoundPresentation() throws {
        let target = TranscriptRetryTarget(lever: .opening)
        let payload = try makePayload(
            prompt: "A stakeholder asks: What do you recommend we do next?",
            target: target
        )
        let presentation = try #require(
            TargetedRetryPresentation(payload: payload)
        )

        #expect(presentation.title == "Try it once more")
        #expect(presentation.focus == target.lever.successMeasure)
        #expect(
            presentation.prompt
                == "A stakeholder asks: What do you recommend we do next?"
        )
        #expect(
            presentation.cues
                == ["Answer first", "One proof point", "Then stop"]
        )
        #expect(
            presentation.cueAccessibilityLabel
                == "Retry instructions. 1, Answer first. 2, One proof point. 3, Then stop."
        )
    }

    @Test("Every retry lever has three ordered instructional cues")
    func everyLeverHasOrderedCues() throws {
        for lever in TranscriptPracticeLever.allCases {
            let presentation = try #require(
                TargetedRetryPresentation(
                    payload: makePayload(
                        prompt: "Use the exact source-bound prompt.",
                        target: TranscriptRetryTarget(lever: lever)
                    )
                )
            )

            #expect(presentation.cues.count == 3)
            #expect(Set(presentation.cues).count == 3)
            for (index, cue) in presentation.cues.enumerated() {
                #expect(
                    presentation.cueAccessibilityLabel
                        .contains("\(index + 1), \(cue)")
                )
            }
        }
    }

    @Test("Ordinary Timed handoff does not become a targeted retry")
    func ordinaryPromptFailsClosed() throws {
        let handoff = TimedPracticePromptHandoff(
            accountIDProvider: { "targeted-retry-test" }
        )
        let token = try #require(handoff.offerToken("An ordinary prompt"))
        let payload = try #require(handoff.consumePayload(token: token))

        #expect(TargetedRetryPresentation(payload: payload) == nil)
    }

    @Test("Permission note names the user-initiated microphone boundary")
    func permissionBoundaryCopy() {
        #expect(
            TargetedRetryPresentation.permissionNote
                == "Microphone opens only after you tap Start."
        )
    }

    private func makePayload(
        prompt: String,
        target: TranscriptRetryTarget
    ) throws -> TimedPracticePromptHandoff.Payload {
        let handoff = TimedPracticePromptHandoff(
            accountIDProvider: { "targeted-retry-test" }
        )
        let prescription = TranscriptPracticePrescription(
            correlationID: UUID(),
            sourceSessionID: UUID(),
            suggestedPrompt: prompt,
            title: "One-step \(target.lever.focusLabel) upgrade",
            focus: target.lever.focusLabel,
            target: target.lever.successMeasure,
            targetDimensionID: nil,
            goal: nil,
            retryTarget: target
        )
        let token = try #require(
            handoff.offerTranscriptRetryToken(prescription)
        )
        return try #require(handoff.consumePayload(token: token))
    }
}
