import Foundation
import Testing
@testable import Noum

@Suite("Cohesive Review story")
struct CohesiveReviewStoryTests {
    private let now = Date(timeIntervalSince1970: 2_100_000_000)

    private func session(
        daysAgo: Double = 0,
        score: Int = 7,
        transcript: String = "A clear answer with one concrete example.",
        duration: TimeInterval = 42,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            transcript: transcript,
            fillerWordCount: 0,
            duration: duration,
            date: now.addingTimeInterval(-daysAgo * 86_400),
            mode: .timed,
            score: score,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func trend(
        _ area: SkillArea,
        direction: TrendDirection,
        confidence: TrendConfidence,
        windowSize: Int
    ) -> SkillTrend {
        SkillTrend(
            skillArea: area,
            direction: direction,
            confidence: confidence,
            windowSize: windowSize,
            currentLevel: .developing,
            recentDelta: nil
        )
    }

    @Test func storyCombinesMovementMeaningAndNextFocus() throws {
        let sessions = (0..<8).map { session(daysAgo: Double($0)) }
        let latest = try #require(sessions.first)
        let story = try #require(ReviewStoryPresentation.make(
            trends: [
                trend(.structure, direction: .improving, confidence: .high, windowSize: 8),
                trend(.paceControl, direction: .declining, confidence: .medium, windowSize: 8)
            ],
            sessions: sessions
        ))

        #expect(story.latestSessionID == latest.id)
        #expect(story.movement.localizedCaseInsensitiveContains("structure"))
        #expect(story.meaning.localizedCaseInsensitiveContains("pace"))
        #expect(story.nextFocus == "Next focus: pace.")
        #expect(story.evidenceCaption == "Seen across 8 recent reps.")
    }

    @Test func storyNeverClaimsMoreEvidenceThanReviewCanOpen() throws {
        let story = try #require(ReviewStoryPresentation.make(
            trends: [trend(.paceControl, direction: .declining, confidence: .medium, windowSize: 8)],
            sessions: (0..<5).map { session(daysAgo: Double($0)) }
        ))

        #expect(story.evidenceCaption == "Seen across 5 recent reps.")
    }

    @Test func sharedFocusKeepsCoreJourneyOnOneInstruction() throws {
        let focus = try #require(CurrentCoachingFocusPresentation.make(
            trends: [trend(.fillerReduction, direction: .declining, confidence: .medium, windowSize: 8)],
            sessionCount: 5
        ))

        #expect(focus.skillArea == .fillerReduction)
        #expect(focus.recommendedMode == .ahCounter)
        #expect(focus.instruction == "Replace the next filler with a silent beat.")
        #expect(focus.observation == "Recent reps point to filler words as the clearest next focus.")
        #expect(focus.evidenceCaption == "Seen across 5 recent reps.")

        let base = RecommendationBiasBlueprint(
            recommendedMode: .timed,
            recommendedTone: nil,
            recommendedScenario: nil,
            focus: "Structure",
            target: "Open with the answer.",
            modeBenefit: "Builds complete answers.",
            whyMode: "A clear structure rep.",
            whyNow: "The next rep needs structure.",
            suggestedTimedDifficulty: .medium,
            suggestedTheme: .all,
            source: .goalBias
        )
        let aligned = focus.applying(to: base)
        #expect(aligned.recommendedMode == .ahCounter)
        #expect(aligned.target == focus.instruction)
        #expect(aligned.focus == "Filler Words")
        #expect(aligned.modeBenefit.localizedCaseInsensitiveContains("filler"))
        #expect(!aligned.modeBenefit.contains("complete answers"))
        #expect(aligned.suggestedTimedDifficulty == nil)
        #expect(aligned.suggestedTheme == .all)
    }

    @Test func thinStoryDoesNotClaimAPattern() throws {
        let story = try #require(ReviewStoryPresentation.make(
            trends: [],
            sessions: [session(daysAgo: 1), session(daysAgo: 0)]
        ))

        #expect(story.meaning == "There is not enough evidence to call a pattern yet.")
        #expect(story.evidenceCaption == "Based on your latest two reps.")
        #expect(!story.movement.localizedCaseInsensitiveContains("trend"))
    }

    @Test func reviewOnlyRowsDoNotInflateStoryOrLatestNavigation() throws {
        let older = session(daysAgo: 2)
        let newestEligible = session(daysAgo: 1)
        let reviewOnly = [
            session(daysAgo: 0.4, transcript: "two words"),
            session(daysAgo: 0.3, duration: 2.99),
            session(daysAgo: 0.2, duration: .infinity),
            session(daysAgo: 0.1, isEvaluationFixture: true),
        ]

        let story = try #require(ReviewStoryPresentation.make(
            trends: [],
            sessions: [older, newestEligible] + reviewOnly
        ))

        #expect(story.latestSessionID == newestEligible.id)
        #expect(story.evidenceCaption == "Based on your latest two reps.")
        #expect(story.meaning == "There is not enough evidence to call a pattern yet.")
    }

    @Test func reviewOnlyRowsCannotCreateAStory() {
        let reviewOnly = [
            session(transcript: "two words"),
            session(duration: 2.99),
            session(duration: .infinity),
            session(isEvaluationFixture: true),
        ]

        #expect(ReviewStoryPresentation.make(trends: [], sessions: reviewOnly) == nil)
    }

    @Test func changedTimedRecommendationGetsNeutralTimedConfiguration() throws {
        let focus = try #require(CurrentCoachingFocusPresentation.make(
            trends: [trend(.structure, direction: .declining, confidence: .medium, windowSize: 5)],
            sessionCount: 5
        ))
        let base = RecommendationBiasBlueprint(
            recommendedMode: .ahCounter,
            recommendedTone: nil,
            recommendedScenario: nil,
            focus: "Fillers",
            target: "Pause instead of filling the space.",
            modeBenefit: "Builds filler awareness.",
            whyMode: "Use a focused filler rep.",
            whyNow: "Fillers are the current focus.",
            suggestedTimedDifficulty: nil,
            suggestedTheme: .ethicsOpinions,
            source: .goalBias
        )

        let aligned = focus.applying(to: base)
        #expect(aligned.recommendedMode == .timed)
        #expect(aligned.modeBenefit.localizedCaseInsensitiveContains("structure"))
        #expect(!aligned.modeBenefit.localizedCaseInsensitiveContains("filler awareness"))
        #expect(aligned.suggestedTimedDifficulty == .medium)
        #expect(aligned.suggestedTheme == .all)
    }

    @Test func progressDisclosureStartsCollapsed() {
        #expect(!ReviewProgressDisclosure.defaultExpanded)
    }

    @Test func reviewHighlightsAreCappedAtTwoRows() {
        let highlights = [
            ReviewHighlightsEngine.Highlight(kind: .breakthrough, sessionID: UUID(), title: "One", line: "One"),
            ReviewHighlightsEngine.Highlight(kind: .goalExample, sessionID: UUID(), title: "Two", line: "Two"),
            ReviewHighlightsEngine.Highlight(kind: .recentBest, sessionID: UUID(), title: "Three", line: "Three")
        ]

        #expect(ReviewHighlightLimit.visible(highlights).count == 2)
    }
}

@Suite("Cohesive Profile composition")
struct CohesiveProfileCompositionTests {
    private func plan() -> CoachingPlan {
        CoachingPlan(
            strongestMode: .timed,
            currentFocus: "Focus on deliberate openings.",
            suggestedDrill: "Timed Practice: open with the answer, then add one concrete example.",
            encouragement: "Your recent reps are becoming more direct.",
            hiddenBaseline: HiddenBaseline(
                averageFillersPerMinute: 1,
                averageDuration: 45,
                averageWordsPerMinute: 138,
                currentIdentity: "Controlled"
            )
        )
    }

    @Test func zeroThinAndEstablishedPlansStayBounded() {
        let zero = ProfileCompositionPlan.make(sessionCount: 0, hasProgressEvidence: false)
        let thin = ProfileCompositionPlan.make(sessionCount: 3, hasProgressEvidence: true)
        let established = ProfileCompositionPlan.make(sessionCount: 12, hasProgressEvidence: true)

        #expect(zero.stage == .zero)
        #expect(zero.surfaces == [.identity, .coachRead, .evidenceHub])
        #expect(thin.stage == .thin)
        #expect(thin.surfaces == [.identity, .progressHero, .coachRead, .evidenceHub])
        #expect(established.stage == .established)
        #expect(established.surfaces == [.identity, .progressHero, .coachRead, .evidenceHub])
    }

    @Test func oneOrTwoRepsDescribeAStartingPointWithoutAttributingTheStatedGoal() {
        let one = ProfileCoachBriefPresentation.make(
            sessionCount: 1,
            plan: plan(),
            memory: nil
        )
        let two = ProfileCoachBriefPresentation.make(
            sessionCount: 2,
            plan: plan(),
            memory: nil
        )

        #expect(one.observation == "Your first rep gives Noum a starting point.")
        #expect(two.observation == "Your latest two reps are setting a starting point.")
        #expect(!one.observation.localizedCaseInsensitiveContains("deliberate openings"))
        #expect(!two.observation.localizedCaseInsensitiveContains("deliberate openings"))
    }

    @Test func evidenceCaptionScalesWithDepth() {
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 0) == nil)
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 1) == "Based on your latest rep.")
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 3) == "Early read from 3 recent reps.")
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 7) == "Seen across 7 recent reps.")
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 12) == "Repeated across 12 recent reps.")
    }

    @Test func sharedFocusBriefDoesNotRepeatTheExerciseName() {
        let brief = ProfileCoachBriefPresentation.make(
            sessionCount: 5,
            plan: plan(),
            memory: nil,
            trends: [SkillTrend(
                skillArea: .fillerReduction,
                direction: .declining,
                confidence: .medium,
                windowSize: 5,
                currentLevel: .developing
            )]
        )

        #expect(brief.observation == "Recent reps point to filler words as the clearest next focus.")
        #expect(brief.nextMove == "Replace the next filler with a silent beat.")
        #expect(!brief.nextMove.contains(":"))
    }

    @Test func establishedBriefRemovesInternalCoachingJargon() {
        let memory = CoachMemory(
            updatedAt: Date(),
            evidenceCount: 12,
            evidenceConfidence: .established,
            currentLever: .fillerReduction,
            goalFit: .aligned,
            strengths: [],
            blockers: [],
            workingHypothesis: "Filler Words appears to be the highest-leverage focus because persistent blocker in the rolling baseline; keep checking against future reps."
        )

        let brief = ProfileCoachBriefPresentation.make(
            sessionCount: 12,
            plan: plan(),
            memory: memory
        )
        let visibleCopy = [brief.observation, brief.nextMove, brief.evidenceCaption ?? ""]
            .joined(separator: " ")
            .lowercased()

        #expect(brief.evidenceCaption == "Repeated across 12 recent reps.")
        #expect(!visibleCopy.contains("lever"))
        #expect(!visibleCopy.contains("rolling baseline"))
        #expect(!visibleCopy.contains("rehearsal shapes"))
        #expect(!visibleCopy.contains("established read"))
        #expect(!visibleCopy.contains("evidence behind this read"))
    }

    @Test func activeInterventionOwnsTheCompactProfileStory() {
        let memory = CoachMemory(
            updatedAt: Date(),
            evidenceCount: 12,
            evidenceConfidence: .established,
            currentLever: .fillerReduction,
            goalFit: .aligned,
            strengths: [],
            blockers: [],
            workingHypothesis: "Filler words remain the main focus.",
            activeIntervention: CoachIntervention(
                title: "Concise stakeholder answers",
                focus: "concise stakeholder answers",
                target: "Open with the answer, then add one concrete example.",
                mode: .timed,
                prescribedAt: Date(),
                lastObservedAt: nil,
                followedRepCount: 1,
                minimumFollowedRepsForReview: 2,
                reviewStatus: .formingEvidence,
                reviewBasis: "One followed rep"
            )
        )

        let brief = ProfileCoachBriefPresentation.make(
            sessionCount: 12,
            plan: plan(),
            memory: memory,
            trends: [SkillTrend(
                skillArea: .fillerReduction,
                direction: .declining,
                confidence: .high,
                windowSize: 12,
                currentLevel: .developing
            )]
        )

        #expect(brief.observation == "Your current plan is working on concise stakeholder answers.")
        #expect(brief.nextMove == "Timed Practice: Open with the answer, then add one concrete example.")
        #expect(!brief.observation.localizedCaseInsensitiveContains("filler"))
        #expect(!brief.nextMove.hasSuffix(".."))
    }

    @Test func pathConsistencyNeverShowsARhythmWithoutAVisiblePracticeDay() {
        #expect(PathConsistencyPresentation.displayedStreak(practicedDays: 0, rawStreak: 1) == 0)
        #expect(PathConsistencyPresentation.displayedStreak(practicedDays: 4, rawStreak: 3) == 3)
        #expect(PathConsistencyPresentation.displayedStreak(practicedDays: 2, rawStreak: -1) == 0)
    }
}

@Suite("Peer comparison visibility")
struct PeerComparisonVisibilityTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func member(
        _ accountID: String,
        name: String,
        weeklyReps: Int = 1,
        updatedAt: Date? = nil
    ) -> PublicProfileSnapshot {
        PublicProfileSnapshot(
            accountID: accountID,
            displayName: name,
            rating: 620,
            peakRating: 640,
            currentStreak: 2,
            weeklyReps: weeklyReps,
            weeklyDelta: 8,
            leagueTier: LeagueTier.gold.rawValue,
            updatedAt: updatedAt ?? now
        )
    }

    @Test func emptyAndSelfOnlyBucketsStayForming() {
        #expect(PeerComparisonVisibility.make(
            members: [],
            currentAccountID: "me",
            now: now
        ) == .forming)
        #expect(PeerComparisonVisibility.make(
            members: [member("me", name: "Me")],
            currentAccountID: "me",
            now: now
        ) == .forming)
    }

    @Test func missingCurrentAccountNeverTreatsRowsAsPeers() {
        #expect(PeerComparisonVisibility.make(
            members: [member("someone", name: "Someone")],
            currentAccountID: nil,
            now: now
        ) == .forming)
    }

    @Test func genuinePeersUnlockTheProfileRouteAndDeduplicate() {
        let visibility = PeerComparisonVisibility.make(
            members: [
                member("me", name: "Me"),
                member("peer", name: "Alex Morgan"),
                member("peer", name: "Alex Morgan")
            ],
            currentAccountID: "me",
            now: now
        )

        #expect(visibility == .available(peerCount: 1))
        #expect(visibility.showsProfileEntry)
        #expect(ProfileLibraryPresentation.make(
            showsPeerComparison: visibility.showsProfileEntry,
            isPremium: true
        ).rows.contains(.peerComparison))
    }

    @Test func inactivePriorWeekAndPlaceholderRowsNeverCreateStandings() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let week = try #require(calendar.dateInterval(of: .weekOfYear, for: now))
        let priorWeek = week.start.addingTimeInterval(-1)
        let members = [
            member("inactive", name: "Alex Morgan", weeklyReps: 0),
            member("prior-week", name: "Taylor Reed", updatedAt: priorWeek),
            member("placeholder", name: "Guest Speaker")
        ]

        #expect(PeerComparisonVisibility.make(
            members: members,
            currentAccountID: "me",
            now: now
        ) == .forming)
        #expect(PeerComparisonVisibility.visibleMembers(
            members,
            currentAccountID: "me",
            now: now
        ).isEmpty)
    }

    @Test func currentWeekPeerRemainsVisibleAfterTwentyFourHours() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let week = try #require(calendar.dateInterval(of: .weekOfYear, for: now))
        let earlyWeekUpdate = week.start.addingTimeInterval(60 * 60)
        let lateWeekNow = week.end.addingTimeInterval(-(60 * 60))
        let peer = member("peer", name: "Taylor Reed", updatedAt: earlyWeekUpdate)

        #expect(lateWeekNow.timeIntervalSince(earlyWeekUpdate) > 24 * 60 * 60)
        #expect(PeerComparisonVisibility.isGenuinePeer(
            peer,
            currentAccountID: "me",
            now: lateWeekNow
        ))
    }

    @Test func priorWeekPeerExpiresAtBoundaryEvenWhenUpdatedWithinTwentyFourHours() throws {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let week = try #require(calendar.dateInterval(of: .weekOfYear, for: now))
        let justAfterBoundary = week.start.addingTimeInterval(30 * 60)
        let justBeforeBoundary = week.start.addingTimeInterval(-(30 * 60))
        let peer = member("peer", name: "Taylor Reed", updatedAt: justBeforeBoundary)

        #expect(justAfterBoundary.timeIntervalSince(justBeforeBoundary) < 24 * 60 * 60)
        #expect(!PeerComparisonVisibility.isGenuinePeer(
            peer,
            currentAccountID: "me",
            now: justAfterBoundary
        ))
    }

    @Test func formingStateKeepsPeerRouteOutOfProfile() {
        let presentation = ProfileLibraryPresentation.make(
            showsPeerComparison: PeerComparisonVisibility.forming.showsProfileEntry,
            isPremium: false
        )
        #expect(!presentation.rows.contains(.peerComparison))
        #expect(presentation.rows.last == .upgrade)
    }
}

@Suite("Account-scoped coaching trends")
struct AccountScopedCoachingTrendTests {
    @Test func switchingAccountsNeverReusesAnotherAccountsEvidence() throws {
        let suiteName = "AccountScopedCoachingTrendTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var activeAccountID: String? = "account-a"
        let store = SkillTrendStore(
            defaults: defaults,
            accountIDProvider: { activeAccountID }
        )
        let accountASnapshot = snapshot(score: 4)
        store.record(accountASnapshot)

        activeAccountID = "account-b"
        store.reloadForCurrentAccount()
        #expect(store.snapshots.isEmpty)

        let accountBSnapshot = snapshot(score: 8)
        store.record(accountBSnapshot)

        activeAccountID = "account-a"
        store.reloadForCurrentAccount()
        #expect(store.snapshots.map(\.id) == [accountASnapshot.id])

        activeAccountID = "account-b"
        store.reloadForCurrentAccount()
        #expect(store.snapshots.map(\.id) == [accountBSnapshot.id])
    }

    @Test func legacyEvidenceMigratesOnlyIntoTheActiveAccount() throws {
        let suiteName = "AccountScopedCoachingTrendMigrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacySnapshot = snapshot(score: 6)
        defaults.set(
            try JSONEncoder().encode([legacySnapshot]),
            forKey: "skillTrendSnapshots"
        )

        var activeAccountID: String? = "upgrading-account"
        let store = SkillTrendStore(
            defaults: defaults,
            accountIDProvider: { activeAccountID }
        )
        #expect(store.snapshots.map(\.id) == [legacySnapshot.id])
        #expect(defaults.data(forKey: "skillTrendSnapshots") == nil)
        #expect(defaults.data(
            forKey: SkillTrendStore.storageKey(for: activeAccountID)
        ) != nil)

        activeAccountID = "different-account"
        store.reloadForCurrentAccount()
        #expect(store.snapshots.isEmpty)
    }

    @Test func debugReplacementRemovesThePreviousPersonaEvidenceAndPersists() throws {
        let suiteName = "AccountScopedCoachingTrendReplacementTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SkillTrendStore(
            defaults: defaults,
            accountIDProvider: { "seeded-account" }
        )
        let plateauSnapshots = (0..<20).map { _ in snapshot(score: 8) }
        let beginnerSnapshots = (0..<5).map { _ in snapshot(score: 4) }

        store.replaceForDebug(plateauSnapshots)
        store.replaceForDebug(beginnerSnapshots)

        #expect(store.snapshots.map(\.id) == beginnerSnapshots.map(\.id))

        let reloaded = SkillTrendStore(
            defaults: defaults,
            accountIDProvider: { "seeded-account" }
        )
        #expect(reloaded.snapshots.map(\.id) == beginnerSnapshots.map(\.id))
    }

    private func snapshot(score: Int) -> SkillSnapshot {
        SkillSnapshot(
            sessionId: UUID(),
            fillerCount: 2,
            duration: 30,
            wordCount: 70,
            wpm: 140,
            qualifiedFillerRatePerMinute: 4,
            qualifiedPaceWPM: 140,
            comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion,
            score: score
        )
    }
}
