import Foundation
import Testing
@testable import Noum

@Suite("V3 profile, progress, memory, and settings presentation")
struct V3ProfileSettingsPresentationTests {
    @Test("Profile identity names only verified practice")
    func profilePracticeSummaryFailsClosed() {
        #expect(ProfilePracticeSummaryPresentation.make(streak: 4, verifiedRepCount: 0).line == "No verified reps yet")
        #expect(ProfilePracticeSummaryPresentation.make(streak: 0, verifiedRepCount: 1).line == "1 verified rep")
        #expect(ProfilePracticeSummaryPresentation.make(streak: 3, verifiedRepCount: 12).line == "3-day practice streak · 12 verified reps")
        #expect(ProfilePracticeSummaryPresentation.make(streak: -2, verifiedRepCount: -8).line == "No verified reps yet")
    }

    @Test("Profile keeps metrics behind Library and uses one prompt slot")
    func profileNarrativeKeepsAFourSurfaceBudget() throws {
        let prompts = ProfileOptionalPromptPlan.make(
            hasProgressEligibleEvidence: true,
            isWeeklyCheckInDue: true,
            shouldAskTransformationQuestion: true
        )
        let plan = ProfileCompositionPlan.make(
            sessionCount: 12,
            optionalPromptPlan: prompts
        )

        let coachRead = try #require(plan.surfaces.firstIndex(of: .coachRead))
        let prompt = try #require(plan.surfaces.firstIndex(of: .optionalPrompt))

        #expect(coachRead < prompt)
        #expect(plan.surfaces == [.identity, .coachRead, .optionalPrompt, .evidenceHub])
        #expect(!plan.surfaces.contains(.progressHero))
        #expect(prompts.primary == .weeklyCheckIn)
        #expect(prompts.secondary == .transformationFeedback)
    }

    @Test("Optional prompt priority is deterministic and never duplicates a slot")
    func optionalPromptPriorityIsBounded() {
        let none = ProfileOptionalPromptPlan.make(
            hasProgressEligibleEvidence: true,
            isWeeklyCheckInDue: false,
            shouldAskTransformationQuestion: false
        )
        let feedbackOnly = ProfileOptionalPromptPlan.make(
            hasProgressEligibleEvidence: true,
            isWeeklyCheckInDue: false,
            shouldAskTransformationQuestion: true
        )
        let weeklyOnly = ProfileOptionalPromptPlan.make(
            hasProgressEligibleEvidence: true,
            isWeeklyCheckInDue: true,
            shouldAskTransformationQuestion: false
        )
        let both = ProfileOptionalPromptPlan.make(
            hasProgressEligibleEvidence: true,
            isWeeklyCheckInDue: true,
            shouldAskTransformationQuestion: true
        )

        #expect(none.orderedPrompts.isEmpty)
        #expect(feedbackOnly.orderedPrompts == [.transformationFeedback])
        #expect(weeklyOnly.orderedPrompts == [.weeklyCheckIn])
        #expect(both.orderedPrompts == [.weeklyCheckIn, .transformationFeedback])

        let library = ProfileLibraryPresentation.make(
            showsSecondaryPrompt: both.secondary != nil,
            showsPeerComparison: false,
            isPremium: true
        )
        #expect(library.rows.filter { $0 == .pendingPrompt }.count == 1)
    }

    @Test("Weekly check-in requires progress-eligible evidence")
    func weeklyCheckInDoesNotLeadAZeroRepProfile() {
        let coldStart = ProfileOptionalPromptPlan.make(
            hasProgressEligibleEvidence: false,
            isWeeklyCheckInDue: true,
            shouldAskTransformationQuestion: false
        )
        let eligible = ProfileOptionalPromptPlan.make(
            hasProgressEligibleEvidence: true,
            isWeeklyCheckInDue: true,
            shouldAskTransformationQuestion: false
        )
        let coldStartWithFeedback = ProfileOptionalPromptPlan.make(
            hasProgressEligibleEvidence: false,
            isWeeklyCheckInDue: true,
            shouldAskTransformationQuestion: true
        )

        #expect(coldStart.primary == nil)
        #expect(!coldStart.orderedPrompts.contains(.weeklyCheckIn))
        #expect(coldStartWithFeedback.primary == .transformationFeedback)
        #expect(!coldStartWithFeedback.orderedPrompts.contains(.weeklyCheckIn))
        #expect(eligible.primary == .weeklyCheckIn)
        #expect(eligible.orderedPrompts == [.weeklyCheckIn])
    }

    @Test("Profile source renders one prompt slot and labels feedback controls")
    func profileSourceKeepsPromptsAccessible() throws {
        let profile = try source("ProfileView.swift")
        let viewStart = try #require(profile.range(of: "struct ProfileView: View {"))
        let bodyStart = try #require(profile.range(
            of: "    var body: some View {",
            range: viewStart.upperBound..<profile.endIndex
        ))
        let bodyEnd = try #require(profile.range(
            of: "    private var shouldAskTransformationQuestion",
            range: bodyStart.upperBound..<profile.endIndex
        ))
        let body = profile[bodyStart.lowerBound..<bodyEnd.lowerBound]

        #expect(body.contains("surfacePlan.surfaces.contains(.optionalPrompt)"))
        #expect(!body.contains("compactSpeakingRatingHero"))
        #expect(!body.contains("weeklyCheckInCard"))
        #expect(!body.contains("transformationQuestionCard"))
        #expect(profile.contains("hasProgressEligibleEvidence: !progressEligibleSessions.isEmpty"))
        #expect(profile.contains(".frame(minWidth: 80, minHeight: 44)"))
        #expect(profile.contains("Yes, this helped outside the app"))
        #expect(profile.contains("Not yet, this has not helped outside the app"))
    }

    @Test("Owned V3 surfaces use the waveform identity instead of a mascot")
    func waveformIdentityReplacesCharacterChrome() throws {
        for relativePath in [
            "ProfileView.swift",
            "Noum/CoachingMemoryView.swift",
            "Noum/SettingsView.swift",
        ] {
            let source = try source(relativePath)
            #expect(source.contains("NoumWaveformMark("))
            #expect(!source.contains("NoumCharacter("))
        }
    }

    @Test("Settings progressively discloses secondary controls without hiding beta feedback")
    func settingsKeepsCoreTrustRoutesVisible() throws {
        let settings = try source("Noum/SettingsView.swift")
        let disclosure = try #require(settings.range(of: "if advancedExpanded {"))
        let repCues = try #require(settings.range(of: "practiceVoiceCuesRow", range: disclosure.lowerBound..<settings.endIndex))
        let notifications = try #require(settings.range(of: "dailyReminderRow", range: disclosure.lowerBound..<settings.endIndex))
        let betaFeedback = try #require(settings.range(of: "BetaFeedbackView()"))

        #expect(repCues.lowerBound > disclosure.lowerBound)
        #expect(notifications.lowerBound > disclosure.lowerBound)
        #expect(betaFeedback.lowerBound > disclosure.lowerBound)
        #expect(settings.contains("settings.betaFeedback"))
        #expect(settings.contains("settings.account.delete"))
        #expect(settings.contains("Your practice, your data."))
        #expect(settings.contains("Core controls stay visible. Advanced tuning stays out of the way."))
        #expect(settings.contains(".navigationTitle(\"Settings\")"))
        #expect(settings.contains("profileHeroPresentation.accessibilityLabel"))
        #expect(settings.contains("Pro subscriber"))

        let heroStart = try #require(settings.range(of: "private var profileHeroContent"))
        let heroEnd = try #require(settings.range(
            of: "private var profileHeroCompactIdentity",
            range: heroStart.upperBound..<settings.endIndex
        ))
        let hero = settings[heroStart.lowerBound..<heroEnd.lowerBound]
        #expect(hero.contains("profileHeroCompactIdentity"))
        #expect(hero.contains("profileHeroExpandedIdentity"))
        #expect(!hero.contains("settingsIntroductionCopy"))
        #expect(!hero.contains("profileHeroProBadge"))
    }

    @Test("Profile gives coach read and library authored hierarchy")
    func profileSourceUsesAuthoredHierarchy() throws {
        let profile = try source("ProfileView.swift")

        #expect(profile.contains("CURRENT COACH READ"))
        #expect(profile.contains("STARTING DIRECTION"))
        #expect(profile.contains("Your coaching library"))
        #expect(profile.contains("Open the full coaching record"))
        #expect(profile.contains("profile.identity"))
        #expect(profile.contains("ProfilePracticeSummaryPresentation.make("))
        #expect(profile.contains("let readTint = AppColor.coachingInkOnQuiet"))
        #expect(profile.contains("Image(systemName: \"waveform\")"))
    }

    private func source(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
