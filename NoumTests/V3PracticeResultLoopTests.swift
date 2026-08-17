import Foundation
import Testing
@testable import Noum

@Suite("V3 practice and result loop")
struct V3PracticeResultLoopTests {
    @Test("Live focus keeps exactly one intervention")
    func liveFocusPrecedenceIsStable() {
        #expect(
            TimedLiveRepFocus.target(
                retryFocus: "Lead with the recommendation.",
                drillConstraint: "Remove every filler.",
                styleGoal: .warm,
                pressureEnabled: true
            ) == "Lead with the recommendation."
        )
        #expect(
            TimedLiveRepFocus.target(
                retryFocus: nil,
                drillConstraint: "Use one signpost.",
                acceptedRecommendationTarget: "Lead with the decision.",
                styleGoal: .concise,
                pressureEnabled: true
            ) == "Use one signpost."
        )
        #expect(
            TimedLiveRepFocus.target(
                retryFocus: nil,
                drillConstraint: nil,
                acceptedRecommendationTarget: "Lead with the decision.",
                styleGoal: .warm,
                pressureEnabled: true
            ) == "Lead with the decision."
        )
    }

    @Test("Accepted recommendation target and demand are consumed exactly once")
    func recommendationQuickStartIsImmutableAndOneShot() throws {
        let suite = "V3PracticeResultLoopTests.quickStart.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let demand = PracticeSessionDemand.timed(difficulty: .hard)
        let intent = try #require(PracticeQuickStartIntent(
            fingerprint: "home-exposure-1",
            focus: "Make the opening decisive.",
            target: "Lead with the decision. Give one reason.",
            mode: .timed,
            prescribedDemand: demand,
            acceptedAt: now
        ))

        #expect(PracticeModeQuickStart.arm(intent: intent, defaults: defaults))
        let consumed = PracticeModeQuickStart.consumeLaunch(
            for: .timed,
            defaults: defaults,
            now: now.addingTimeInterval(1)
        )
        #expect(consumed?.recommendationIntent == intent)
        #expect(consumed?.recommendationIntent?.target == intent.target)
        #expect(consumed?.recommendationIntent?.prescribedDemand == demand)
        #expect(PracticeModeQuickStart.consumeLaunch(
            for: .timed,
            defaults: defaults,
            now: now.addingTimeInterval(2)
        ) == nil)
    }

    @Test("The visible Home exposure is the accepted launch contract")
    func homeExposureProjectsWithoutRederivingTarget() throws {
        let acceptedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let demand = PracticeSessionDemand.timed(difficulty: .medium)
        let exposure = HomeCoachRecommendationExposure(
            fingerprint: "visible-home-exposure",
            title: "Make the answer land.",
            focus: "Remove setup before the answer.",
            target: "Answer first. Give one reason. Then stop.",
            mode: .timed,
            scenario: nil,
            tone: nil,
            suggestedTheme: .all,
            prescribedDemand: demand
        )
        let intent = try #require(exposure.quickStartIntent(acceptedAt: acceptedAt))

        #expect(intent.fingerprint == exposure.fingerprint)
        #expect(intent.focus == exposure.focus)
        #expect(intent.target == exposure.target)
        #expect(intent.mode == exposure.mode)
        #expect(intent.prescribedDemand == exposure.prescribedDemand)
        #expect(intent.acceptedAt == acceptedAt)
    }

    @Test("Train projects the rendered recommendation into the same immutable contract")
    func trainExposureProjectsWithoutRederivingTarget() throws {
        let acceptedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let projection = TrainRecommendationProjection(
            blueprint: TrainRecommendationProjection.initialBlueprint,
            mode: .imConversation,
            title: "Conversation Practice",
            reason: "A live exchange tests whether the point holds.",
            focus: "Hold one clear point.",
            target: "Lead with the answer, then ask one useful question.",
            scenario: .workUpdate,
            tone: .confident,
            suggestedTheme: .all,
            prescribedDemand: nil
        )
        let intent = try #require(projection.quickStartIntent(
            fingerprint: "train-visible-exposure",
            acceptedAt: acceptedAt
        ))

        #expect(intent.fingerprint == "train-visible-exposure")
        #expect(intent.focus == projection.focus)
        #expect(intent.target == projection.target)
        #expect(intent.mode == projection.mode)
        #expect(intent.prescribedDemand == nil)
        #expect(intent.acceptedAt == acceptedAt)
    }

    @Test("Every recommendation destination consumes its exact target once")
    func recommendationDestinationsRetainExactTarget() throws {
        let acceptedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let contracts: [(PracticeMode, PracticeSessionDemand?)] = [
            (.ahCounter, nil),
            (.imConversation, nil),
            (.suddenDeath, .suddenDeath(difficulty: .hard)),
        ]

        for (mode, demand) in contracts {
            let suite = "V3PracticeResultLoopTests.\(mode.rawValue).\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let intent = try #require(PracticeQuickStartIntent(
                fingerprint: "exact-\(mode.rawValue)",
                focus: "Keep one intervention.",
                target: "Lead with the decision. Give one reason. Then stop.",
                mode: mode,
                prescribedDemand: demand,
                acceptedAt: acceptedAt
            ))

            #expect(PracticeModeQuickStart.arm(intent: intent, defaults: defaults))
            let launch = PracticeModeQuickStart.consumeLaunch(
                for: mode,
                defaults: defaults,
                now: acceptedAt.addingTimeInterval(1)
            )
            #expect(launch?.recommendationIntent == intent)
            #expect(launch?.recommendationIntent?.target == intent.target)
            #expect(launch?.recommendationIntent?.prescribedDemand == demand)
            #expect(PracticeModeQuickStart.consumeLaunch(
                for: mode,
                defaults: defaults,
                now: acceptedAt.addingTimeInterval(2)
            ) == nil)
        }
    }

    @Test("Non-Timed destinations retain the target without inventing persistence")
    func recommendationDestinationsUseMountedIntentOnly() throws {
        let im = try repositorySource("IMPracticeView.swift")
        let filler = try repositorySource("AhCounterView.swift")
        let pressure = try repositorySource("SuddenDeathPracticeView.swift")
        let train = try repositorySource("PracticeModeSelectionView.swift")

        for (source, mode, identifier) in [
            (im, "imConversation", "imPractice.acceptedTarget"),
            (filler, "ahCounter", "ahCounter.acceptedTarget"),
            (pressure, "suddenDeath", "suddenDeath.acceptedTarget"),
        ] {
            #expect(source.contains("PracticeModeQuickStart.consumeLaunch("))
            #expect(source.contains("for: .\(mode)"))
            #expect(source.contains("acceptedPracticeIntent = quickStartLaunch.recommendationIntent"))
            #expect(source.contains("Text(intent.target)"))
            #expect(source.contains("if acceptedPracticeIntent == nil"))
            #expect(source.contains(".accessibilityIdentifier(\"\(identifier)\")"))
        }
        #expect(train.contains("PracticeModeQuickStart.arm(intent: intent)"))
        #expect(pressure.contains(".suddenDeathDifficulty ?? .medium"))
        #expect(!im.contains("transcriptRetryTarget = acceptedPracticeIntent"))
        #expect(!filler.contains("transcriptRetryTarget = acceptedPracticeIntent"))
        #expect(!pressure.contains("transcriptRetryTarget = acceptedPracticeIntent"))
    }

    @Test("A wrong tab or expired recommendation clears quick-start authority")
    func recommendationQuickStartFailsClosed() throws {
        let suite = "V3PracticeResultLoopTests.staleQuickStart.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let acceptedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let intent = try #require(PracticeQuickStartIntent(
            fingerprint: "home-exposure-2",
            focus: "Tighten the close.",
            target: "Name the next step. Then stop.",
            mode: .timed,
            prescribedDemand: .timed(difficulty: .medium),
            acceptedAt: acceptedAt
        ))

        #expect(PracticeModeQuickStart.arm(intent: intent, defaults: defaults))
        #expect(PracticeModeQuickStart.consumeLaunch(
            for: .ahCounter,
            defaults: defaults,
            now: acceptedAt
        ) == nil)
        #expect(PracticeModeQuickStart.consumeLaunch(
            for: .timed,
            defaults: defaults,
            now: acceptedAt
        ) == nil)

        #expect(PracticeModeQuickStart.arm(intent: intent, defaults: defaults))
        #expect(PracticeModeQuickStart.consumeLaunch(
            for: .timed,
            defaults: defaults,
            now: acceptedAt.addingTimeInterval(
                PracticeQuickStartIntent.maximumAge + 1
            )
        ) == nil)
        #expect(defaults.object(forKey: PracticeModeQuickStart.armedModeKey) == nil)
        #expect(defaults.object(forKey: PracticeModeQuickStart.intentKey) == nil)
    }

    @Test("A recommendation cannot pair a mode with an incompatible demand")
    func recommendationQuickStartRejectsDemandMismatch() {
        #expect(PracticeQuickStartIntent(
            fingerprint: "home-exposure-3",
            focus: "Stay composed.",
            target: "Pause before the answer.",
            mode: .imConversation,
            prescribedDemand: .timed(difficulty: .easy)
        ) == nil)
    }

    @Test("Every voice fallback is observable and bounded")
    func voiceTargetsRemainBiteSized() {
        for goal in SpeakingStyleGoal.allCases {
            let target = TimedLiveRepFocus.target(
                retryFocus: nil,
                drillConstraint: nil,
                styleGoal: goal,
                pressureEnabled: false
            )
            #expect(!target.isEmpty)
            #expect(target.count <= 90)
            #expect(target.components(separatedBy: ".").count <= 4)
        }
    }

    @Test("Gold reward requires the exact qualified session")
    func rewardQualificationFailsClosed() {
        let finalized = UUID()
        let other = UUID()

        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: finalized,
            resolvedSessionID: finalized,
            isProgressEligible: true,
            xpEarned: 25
        ) == 25)
        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: finalized,
            resolvedSessionID: other,
            isProgressEligible: true,
            xpEarned: 25
        ) == 0)
        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: nil,
            resolvedSessionID: finalized,
            isProgressEligible: true,
            xpEarned: 25
        ) == 0)
        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: finalized,
            resolvedSessionID: finalized,
            isProgressEligible: false,
            xpEarned: 25
        ) == 0)
        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: finalized,
            resolvedSessionID: finalized,
            isProgressEligible: true,
            xpEarned: 0
        ) == 0)
    }

    @Test("Pressure keeps a prescription in the focused action slot")
    func summaryFocusedStageIsDeterministic() {
        #expect(SummaryFocusedActionStage.resolve(
            isPressureRun: true,
            transcriptUpgradeOwnsNextAction: true
        ) == .pressurePrescription)
        #expect(SummaryFocusedActionStage.resolve(
            isPressureRun: false,
            transcriptUpgradeOwnsNextAction: true
        ) == .transcriptUpgrade)
        #expect(SummaryFocusedActionStage.resolve(
            isPressureRun: false,
            transcriptUpgradeOwnsNextAction: false
        ) == .prescription)
    }

    @Test("Timed capture never celebrates a score by itself")
    func timedCaptureContainsNoScoreConfetti() throws {
        let source = try repositorySource("TimedPracticeView.swift")
        #expect(!source.contains("showCelebration"))
        #expect(!source.contains("ConfettiLayer("))
        #expect(!source.contains("if result.score >= 70"))
        #expect(!source.contains("NoumCharacter("))
        #expect(source.contains("RecordingCompletionGate.allowsScoringAndProgress"))
        #expect(source.contains("level: CGFloat(min(max(audioLevel, 0), 1))"))
        #expect(source.contains("Live microphone waveform"))
    }

    @Test("Earned retry separates evidence graphics from audio")
    func earnedRetryUsesSemanticGraphicsAndSupportsDarkMode() throws {
        let source = try repositorySource("TranscriptPracticeLoop.swift")
        let milestone = try #require(sourceSlice(
            source,
            from: "struct TranscriptRetryMilestoneView: View",
            through: "private enum RetryRewardEmblemPhase"
        ))
        let burst = try #require(sourceSlice(
            source,
            from: "private struct RetryRewardParticleBurst: View",
            through: "private enum RetryComparisonStage"
        ))

        #expect(milestone.contains("role: .verifiedEvidence"))
        #expect(milestone.contains("role: .nextStepUnlocked"))
        #expect(milestone.contains("if earnedXP > 0"))
        #expect(milestone.contains("if unlockedNextStep"))
        #expect(milestone.contains("See the comparison"))
        #expect(!milestone.contains("Evidence ready"))
        #expect(!milestone.contains("NoumWaveformMark"))
        #expect(burst.contains("Image(systemName: \"diamond.fill\")"))
        #expect(burst.contains("Image(systemName: \"star.fill\")"))
        #expect(!burst.contains("Capsule()"))
        #expect(milestone.contains("NoumRewardPill("))
        #expect(milestone.contains("NoumEvidenceCard("))
        #expect(!milestone.contains(".preferredColorScheme(.light)"))
        #expect(!milestone.contains("repeatForever"))
    }

    @Test("Retry comparison uses numbered evidence stages")
    func retryComparisonGraphicsCommunicateSequence() throws {
        let source = try repositorySource("TranscriptPracticeLoop.swift")

        #expect(source.contains("case .source: return .originalAttempt"))
        #expect(source.contains("case .retry: return .retryAttempt"))
        #expect(source.contains("Text(\"“\")"))
        #expect(source.contains("Text(\"”\")"))
        #expect(source.contains("Text(\"Same coaching target\")"))
        #expect(source.contains("case .regressed:"))
        #expect(source.contains("return self == .source"))
        #expect(source.contains("case .held, .needsMoreEvidence:"))
        #expect(source.contains("Text(\"COMPARISON · TWO TRIES\")"))
        #expect(source.contains("let rungFont = dominant"))
        #expect(source.contains("font: rungFont"))
        #expect(source.contains(".font(font)"))
        #expect(!source.contains("Image(systemName: \"arrow.left.arrow.right\")"))
    }

    @Test("Retry comparison presentation revalidates the exact persisted join")
    func retryComparisonQualificationFailsClosed() throws {
        let sourceID = UUID()
        let retryID = UUID()
        let sourceSession = qualifiedTimedSession(id: sourceID)
        let retrySession = qualifiedTimedSession(id: retryID)
        let valid = retryOutcome(
            sourceSessionID: sourceID,
            retrySessionID: retryID,
            result: .improved
        )

        #expect(TranscriptRetryComparisonQualification.resolve(
            outcome: valid,
            sourceSession: sourceSession,
            retrySession: retrySession
        )?.result == .improved)

        let needsMore = retryOutcome(
            sourceSessionID: sourceID,
            retrySessionID: retryID,
            result: .needsMoreEvidence
        )
        #expect(TranscriptRetryComparisonQualification.resolve(
            outcome: needsMore,
            sourceSession: sourceSession,
            retrySession: retrySession
        )?.result == .needsMoreEvidence)

        let mismatchedSource = retryOutcome(
            sourceSessionID: sourceID,
            retrySessionID: retryID,
            comparisonSourceSessionID: UUID(),
            result: .improved
        )
        #expect(TranscriptRetryComparisonQualification.resolve(
            outcome: mismatchedSource,
            sourceSession: sourceSession,
            retrySession: retrySession
        ) == nil)

        let mismatchedRetry = retryOutcome(
            sourceSessionID: sourceID,
            retrySessionID: retryID,
            comparisonRetrySessionID: UUID(),
            result: .improved
        )
        #expect(TranscriptRetryComparisonQualification.resolve(
            outcome: mismatchedRetry,
            sourceSession: sourceSession,
            retrySession: retrySession
        ) == nil)

        let legacy = retryOutcome(
            sourceSessionID: sourceID,
            retrySessionID: retryID,
            adherenceSchemaVersion: nil,
            result: .improved
        )
        #expect(TranscriptRetryComparisonQualification.resolve(
            outcome: legacy,
            sourceSession: sourceSession,
            retrySession: retrySession
        ) == nil)

        let inconsistentResult = retryOutcome(
            sourceSessionID: sourceID,
            retrySessionID: retryID,
            result: .improved,
            sourceSignal: 70,
            retrySignal: 30
        )
        #expect(TranscriptRetryComparisonQualification.resolve(
            outcome: inconsistentResult,
            sourceSession: sourceSession,
            retrySession: retrySession
        ) == nil)
    }

    private func qualifiedTimedSession(id: UUID) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: "I recommend we launch today because the evidence and accountable owner are ready.",
            fillerWordCount: 0,
            duration: 30,
            date: Date(),
            mode: .timed,
            score: 8,
            prompt: "Should we launch today?"
        )
    }

    private func retryOutcome(
        sourceSessionID: UUID,
        retrySessionID: UUID,
        comparisonSourceSessionID: UUID? = nil,
        comparisonRetrySessionID: UUID? = nil,
        adherenceSchemaVersion: Int? = RecommendationAdherenceContract.schemaVersion,
        result: TranscriptRetryResult,
        sourceSignal: Int = 40,
        retrySignal: Int = 70
    ) -> RecommendationOutcome {
        RecommendationOutcome(
            id: UUID(),
            fingerprint: "v3-source-bound-comparison",
            title: "Answer first",
            focus: "Lead with the answer",
            target: "Lead with the answer, then give one reason.",
            mode: .timed,
            sessionID: retrySessionID,
            followed: true,
            adherenceSchemaVersion: adherenceSchemaVersion,
            completedAt: Date(),
            scoreDelta: 0,
            hasComparableScore: true,
            fillerDelta: 0,
            durationDelta: 0,
            sourceSessionID: sourceSessionID,
            transcriptRetryTarget: TranscriptRetryTarget(lever: .opening),
            transcriptRetryComparison: TranscriptRetryComparison(
                schemaVersion: TranscriptRetryComparison.schemaVersion,
                lever: .opening,
                sourceSessionID: comparisonSourceSessionID ?? sourceSessionID,
                retrySessionID: comparisonRetrySessionID ?? retrySessionID,
                sourceSignal: sourceSignal,
                retrySignal: retrySignal,
                meaningOverlapPercent: 80,
                result: result
            )
        )
    }

    private func repositorySource(_ filename: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent("Noum").appendingPathComponent(filename),
            encoding: .utf8
        )
    }

    private func sourceSlice(
        _ source: String,
        from startMarker: String,
        through endMarker: String
    ) -> String? {
        guard let start = source.range(of: startMarker),
              let end = source.range(
                of: endMarker,
                range: start.lowerBound..<source.endIndex
              ) else {
            return nil
        }
        return String(source[start.lowerBound..<end.upperBound])
    }
}
