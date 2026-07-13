import Foundation
import Testing
@testable import Noum

@Suite("Weekly digest goal copy")
struct WeeklyDigestGoalCopyTests {
    private let representativeRepCounts = [-1, 0, 1, 2, 3, 4, 5, 6, 7, 12]

    @Test func nilGoalPreservesGenericCopyAcrossEveryRepBucket() {
        for weeklyReps in representativeRepCounts {
            let implicit = NotificationCopy.weeklyDigest(weeklyReps: weeklyReps)
            let explicitNil = NotificationCopy.weeklyDigest(
                weeklyReps: weeklyReps,
                chosenStyleGoal: nil
            )

            #expect(implicit.title == explicitNil.title)
            #expect(implicit.body == explicitNil.body)

            for goal in SpeakingStyleGoal.allCases {
                #expect(!implicit.body.localizedCaseInsensitiveContains(goal.rawValue))
            }
        }
    }

    @Test func everyExplicitGoalAddsOnlyItsChosenFocusAcrossEveryRepBucket() {
        let expectedFocus: [SpeakingStyleGoal: String] = [
            .authoritative: "Your authoritative goal stays focused on steadiness and decisive endings.",
            .warm: "Your warm-voice goal stays focused on natural pace and connection.",
            .concise: "Your concise goal stays focused on clean structure and fewer extra words.",
            .persuasive: "Your persuasive goal stays focused on clear structure and support.",
            .executive: "Your executive-presence goal stays focused on composure and concise decisions.",
            .storytelling: "Your storytelling goal stays focused on a clear narrative turn and vocal emphasis."
        ]

        for weeklyReps in representativeRepCounts {
            let generic = NotificationCopy.weeklyDigest(weeklyReps: weeklyReps)

            for goal in SpeakingStyleGoal.allCases {
                let tailored = NotificationCopy.weeklyDigest(
                    weeklyReps: weeklyReps,
                    chosenStyleGoal: goal
                )

                #expect(tailored.title == generic.title)
                #expect(tailored.body == "\(generic.body) \(expectedFocus[goal]!)")
            }
        }
    }

    @Test func everyRepBucketAvoidsUrgencyAndUnearnedProgressClaims() {
        let bannedFragments = [
            "hurry",
            "last chance",
            "before it's too late",
            "don't miss",
            "must practice",
            "at risk",
            "voice changed",
            "voices change",
            "you improved",
            "better by",
            "closer by",
            "progress score",
            "%"
        ]

        for weeklyReps in representativeRepCounts {
            for goal in [nil] + SpeakingStyleGoal.allCases.map(Optional.some) {
                let line = NotificationCopy.weeklyDigest(
                    weeklyReps: weeklyReps,
                    chosenStyleGoal: goal
                )
                let combined = "\(line.title) \(line.body)".lowercased()

                for fragment in bannedFragments {
                    #expect(!combined.contains(fragment))
                }
            }
        }
    }

    @Test func lightWeekCopyUsesActualRepArithmetic() {
        let oneRep = NotificationCopy.weeklyDigest(weeklyReps: 1)
        let twoReps = NotificationCopy.weeklyDigest(weeklyReps: 2)

        #expect(oneRep.title.contains("1 rep"))
        #expect(oneRep.body.hasPrefix("1 rep is on the record."))
        #expect(twoReps.title.contains("2 reps"))
        #expect(twoReps.body.hasPrefix("2 reps are on the record."))

        for line in [oneRep, twoReps] {
            #expect(!line.body.localizedCaseInsensitiveContains("one more rep"))
            #expect(!line.body.localizedCaseInsensitiveContains("at four"))
        }
    }
}
