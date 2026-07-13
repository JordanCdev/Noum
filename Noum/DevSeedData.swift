//
//  DevSeedData.swift
//  Noum
//
//  Debug-only tooling for injecting realistic baseline + session data.
//  Enables inspection of the intelligence layer without needing 20+ real sessions.
//

#if DEBUG

import Foundation

// MARK: - Seed Profiles

/// Pre-built user profiles representing different stages and patterns.
enum SeedProfile: String, CaseIterable {
    case beginner           // 5 sessions, high fillers, inconsistent
    case improvingIntermediate  // 12 sessions, fillers declining, structure improving
    case plateauedAdvanced  // 20 sessions, strong baseline but stuck on openings
    case pressureVulnerable // 15 sessions, great casually, falls apart under pressure
    case fillerFree         // 18 sessions, near-zero fillers, strong across the board

    var displayName: String {
        switch self {
        case .beginner: return "Beginner (5 sessions)"
        case .improvingIntermediate: return "Improving (12 sessions)"
        case .plateauedAdvanced: return "Plateaued (20 sessions, stuck on openings)"
        case .pressureVulnerable: return "Pressure-vulnerable (great casual, weak under pressure)"
        case .fillerFree: return "Strong speaker (near-zero fillers)"
        }
    }
}

// MARK: - Seed Data Generator

enum DevSeedData {

    /// Stable, non-sensitive copy used only by the rendered active-week phrase
    /// handoff test. Keeping the fixture here lets the test populate the real
    /// account-scoped owners without adding a parallel UI-test store.
    static let forwardPlanPhraseUITestText =
        "Lead with the decision, then give one reason."

    // MARK: - Public API

    /// Generate a set of practice sessions for a given seed profile.
    static func sessions(for profile: SeedProfile) -> [PracticeSession] {
        switch profile {
        case .beginner:
            return beginnerSessions()
        case .improvingIntermediate:
            return improvingIntermediateSessions()
        case .plateauedAdvanced:
            return plateauedAdvancedSessions()
        case .pressureVulnerable:
            return pressureVulnerableSessions()
        case .fillerFree:
            return fillerFreeSessions()
        }
    }

    /// Inject a seed profile into the live stores. Replaces current data.
    @MainActor
    static func injectProfile(_ profile: SeedProfile) {
        let sessions = sessions(for: profile)

        // Write sessions to the store
        let store = PracticeSessionStore.shared
        // Clear existing sessions by writing empty, then append seed data
        store.replaceAllForDebug(sessions)

        // Rebuild baseline from the injected sessions
        BaselineStore.shared.rebuild(from: sessions)

        // Record trend snapshots (oldest first so trends compute correctly)
        for session in sessions.reversed() {
            let wordCount = session.transcript.split { !$0.isLetter }.count
            SkillTrendStore.shared.recordFromSession(
                sessionId: session.id,
                fillerCount: session.fillerWordCount,
                duration: session.duration,
                wordCount: wordCount,
                score: session.score ?? 5,
                categoryRatings: categoryRatingsForSession(session)
            )
        }

        // Seed a plausible SpeakingRating so the premium personal-best hero
        // has something honest to display. The current-week peak is held
        // a few points above the live overall so the "you held N earlier
        // this week" line reads truthfully against the seed history.
        RatingStore.shared.replaceForDebug(seedRating(for: profile))

        // Seed XP so the level + progress + identity surfaces aren't stuck
        // on "Beginner I / 0 XP" for a profile that's logged 12+ sessions.
        // Without this, Profile and Settings show a brand-new user identity
        // on top of a seasoned session history — visually contradictory.
        ProfileManager.shared.replaceFromRemote(seedXP(for: profile))

        // Seed a CoachingProfile aligned with the seed narrative. Without
        // this, signal-gated home cards (Daily Challenge, VoiceMetrics,
        // AIWeeklyInsight, Journey, AskNoum) and goal-aware surfaces
        // (VoiceAlignmentChip, VoiceAnchorBanner, goal-progress ring) all
        // stayed cold on a seeded simulator — the M15 Phase 4 home
        // discipline gates couldn't tell a seeded user from a brand-new
        // one. With this, UI tests can use tap-the-card patterns again on
        // every gated surface, and the goal-aware coaching loop is
        // visible end-to-end in the seeded screenshot tour.
        CoachingProfileStore.shared.replaceForDebug(seedCoachingProfile(for: profile))

        // Populate the coach-intelligence spine, not only the metric spine.
        // This keeps seeded inspection honest: the coach context now has a
        // baseline, subjective reflections, transfer reports, proof moments,
        // and recommendation-response evidence to formulate from.
        let fixture = coachIntelligenceFixture(
            for: profile,
            sessions: sessions,
            baseline: BaselineStore.shared.baseline,
            now: Date()
        )
        populateCoachIntelligenceFixture(fixture)
    }

    /// Populate the real Phrase Bank and Forward Plan owners with one current-
    /// week assignment. This is deliberately separate from the general seed so
    /// screenshot tours and unrelated UI tests do not gain an artificial plan.
    @MainActor
    static func injectForwardPlanPhraseForUITesting() {
        let planStore = ForwardPlanStore.shared
        let phraseBank = PhraseBankStore.shared
        let plan = ForwardPlanService.deterministicPlan(
            input: ForwardPlanCoordinator.buildInput()
        )
        planStore.replace(plan)

        guard let entry = phraseBank.save(
            text: forwardPlanPhraseUITestText,
            voice: CoachingProfileStore.shared.profile?.chosenStyleGoal,
            weakness: .concise,
            intensity: .medium
        ),
        let target = ForwardPlanPhraseProjection.target(plan: planStore.activePlan) else {
            return
        }

        _ = ForwardPlanPhraseCoordinator.assign(
            entryID: entry.id,
            renderedTarget: target,
            currentPlan: planStore.activePlan,
            phraseBank: phraseBank,
            planStore: planStore
        )
    }

    // MARK: - Coach-intelligence fixture

    struct CoachIntelligenceFixture {
        let seedProfile: SeedProfile
        let profile: CoachingProfile
        let sessions: [PracticeSession]
        let baseline: CommunicationBaseline
        let rating: SpeakingRating
        let reflections: [SessionReflection]
        let checkIns: [CoachCheckIn]
        let bigMoment: BigMoment
        let transferReports: [BigMomentOutcomeReport]
        let recommendationOutcomes: [RecommendationOutcome]
        let proofs: [ProofMomentRecord]
        let memory: CoachMemory?

        var context: String {
            CoachContextBuilder.userContext(
                profile: profile,
                baseline: baseline,
                rating: rating,
                sessions: sessions,
                currentStreak: PracticeSession.calculateStreak(from: sessions),
                pathStatus: nil,
                pathGatingPhrase: nil,
                recentProofs: proofs,
                bigMoment: bigMoment,
                recentMomentOutcomes: transferReports,
                coachMemory: memory,
                recommendationOutcomes: recommendationOutcomes,
                recentCheckIns: checkIns
            )
        }

        var intelligenceAudit: String {
            var lines: [String] = []
            lines.append("Seed: \(seedProfile.displayName)")
            lines.append("Sessions: \(sessions.count)")
            lines.append("Baseline confidence: \(baseline.overallConfidence.label)")
            lines.append("Filler baseline: \(String(format: "%.1f", baseline.fillerRate.value))/min")
            lines.append("Pace baseline: \(String(format: "%.0f", baseline.pace.value)) WPM")
            if let hypothesis = memory?.workingHypothesis {
                lines.append("Working hypothesis: \(hypothesis)")
            }
            if let caseFile = memory?.caseFile {
                lines.append("Case target: \(caseFile.observableTarget ?? "not set")")
                lines.append("Next move: \(caseFile.nextMove.contextLabel)")
            }
            if let intervention = memory?.activeIntervention {
                lines.append("Active intervention: \(intervention.title) -> \(intervention.reviewStatus.contextLabel)")
            }
            if let latestTransfer = transferReports.first {
                lines.append("Latest transfer: \(latestTransfer.coachContextLine)")
            }
            if let latestCheckIn = checkIns.first {
                lines.append("Latest check-in: \(latestCheckIn.coachContextLines.joined(separator: " "))")
            }
            lines.append("Proofs: \(proofs.count)")
            lines.append("Limit: validation remains user/outcome tested; this fixture cannot prove coach parity.")
            return lines.joined(separator: "\n")
        }
    }

    static func coachIntelligenceFixture(
        for seedProfile: SeedProfile,
        now: Date = Date()
    ) -> CoachIntelligenceFixture {
        let sessions = sessions(for: seedProfile)
        let baseline = BaselineEngine.compute(from: sessions)
        return coachIntelligenceFixture(
            for: seedProfile,
            sessions: sessions,
            baseline: baseline,
            now: now
        )
    }

    private static func coachIntelligenceFixture(
        for seedProfile: SeedProfile,
        sessions: [PracticeSession],
        baseline: CommunicationBaseline,
        now: Date
    ) -> CoachIntelligenceFixture {
        let profile = seedCoachingProfile(for: seedProfile)
        let rating = seedRating(for: seedProfile)
        let reflections = seedReflections(for: seedProfile, sessions: sessions)
        let checkIns = [seedCheckIn(for: seedProfile, now: now)]
        let bigMoment = seedBigMoment(for: seedProfile, now: now)
        let transferReports = seedTransferReports(for: seedProfile, activeMoment: bigMoment, now: now)
        let recommendationOutcomes = seedRecommendationOutcomes(for: seedProfile, sessions: sessions, now: now)
        let proofs = seedProofs(for: seedProfile, sessions: sessions, now: now)
        let memory = CoachMemoryEngine.build(
            profile: profile,
            baseline: baseline,
            sessions: sessions,
            trends: [],
            forwardPlan: nil,
            previous: nil,
            lastSessionID: sessions.sorted { $0.date > $1.date }.first?.id,
            recommendationOutcomes: recommendationOutcomes,
            latestReflection: reflections.first,
            reflectionHistory: reflections,
            latestTransferReport: transferReports.first,
            upcomingMoment: bigMoment,
            now: now
        )
        return CoachIntelligenceFixture(
            seedProfile: seedProfile,
            profile: profile,
            sessions: sessions,
            baseline: baseline,
            rating: rating,
            reflections: reflections,
            checkIns: checkIns,
            bigMoment: bigMoment,
            transferReports: transferReports,
            recommendationOutcomes: recommendationOutcomes,
            proofs: proofs,
            memory: memory
        )
    }

    @MainActor
    private static func populateCoachIntelligenceFixture(_ fixture: CoachIntelligenceFixture) {
        SessionReflectionStore.shared.replaceForDebug(fixture.reflections)
        CoachCheckInStore.shared.replaceForDebug(fixture.checkIns)
        BigMomentStore.shared.replaceForDebug(
            activeMoment: fixture.bigMoment,
            outcomeReports: fixture.transferReports
        )
        RecommendationLearningStore.shared.replaceFromRemote(
            pendingExposure: nil,
            outcomes: fixture.recommendationOutcomes
        )
        if #available(iOS 17.0, macOS 12.0, *) {
            ProofMomentStore.shared.replaceForDebug(fixture.proofs)
        }
        CoachMemoryStore.shared.clearAll()
        CoachMemoryStore.shared.refresh(
            profile: fixture.profile,
            baseline: fixture.baseline,
            sessions: fixture.sessions,
            trends: [],
            forwardPlan: nil,
            lastSessionID: fixture.sessions.sorted { $0.date > $1.date }.first?.id,
            recommendationOutcomes: fixture.recommendationOutcomes,
            latestReflection: fixture.reflections.first,
            reflectionHistory: fixture.reflections,
            latestTransferReport: fixture.transferReports.first,
            upcomingMoment: fixture.bigMoment
        )
    }

    /// Voice + priority + challenge tuned to each seed narrative. The
    /// seeded user should feel like a believable person mid-journey — not
    /// a blank profile, not a generic "everything" voice. `internal` so
    /// tests can lock the per-seed voice mapping without mutating any
    /// live store.
    static func seedCoachingProfile(for profile: SeedProfile) -> CoachingProfile {
        // Every seed is a deliberate demo persona with a genuinely-chosen voice,
        // so stamp `chosenStyleGoal` from the constructed `speakingStyleGoal`
        // once here — keeps `hasChosenVoice` true for all seeds (tailored demo
        // experience) without repeating the field in every case below.
        var built = buildSeedProfile(for: profile)
        if built.chosenStyleGoal == nil {
            built.chosenStyleGoal = built.speakingStyleGoal
        }
        return built
    }

    private static func buildSeedProfile(for profile: SeedProfile) -> CoachingProfile {
        switch profile {
        case .beginner:
            // First few reps, fillers are the visible problem. Warm voice
            // matches the rebuilding-confidence tone; reduces shame
            // signals on the seeded gated cards.
            return CoachingProfile(
                speakingContext: .work,
                primaryGoal: .reduceFillers,
                confidenceLevel: .rebuilding,
                biggestChallenge: .fillerWords,
                desiredOutcome: .composed,
                speakingStyleGoal: .warm,
                styleReference: "Sound steady when I open my mouth at standups.",
                coachingBrief: "Cut the ums so my point lands first.",
                motivationWhyNow: "Standups are getting more visible.",
                successVision: "Sound like I know what I'm saying."
            )
        case .improvingIntermediate:
            // The showcase profile. Fillers dropping → "be more concise"
            // reads as the natural next ask. Warm voice keeps the coach
            // copy across surfaces friendly rather than clipped.
            return CoachingProfile(
                speakingContext: .work,
                primaryGoal: .moreConcise,
                confidenceLevel: .inconsistent,
                biggestChallenge: .rambling,
                desiredOutcome: .composed,
                speakingStyleGoal: .warm,
                styleReference: "Brené Brown — warm but precise.",
                coachingBrief: "Tighten my answers in cross-functional meetings.",
                motivationWhyNow: "I'm getting more stakeholder facetime.",
                successVision: "Land my point in one sentence."
            )
        case .plateauedAdvanced:
            // Strong delivery, stuck on openings. Authoritative voice +
            // executive presence — the user is mid-career, looking for
            // the next edge.
            return CoachingProfile(
                speakingContext: .presentations,
                primaryGoal: .moreConcise,
                confidenceLevel: .confident,
                biggestChallenge: .rambling,
                desiredOutcome: .persuasive,
                speakingStyleGoal: .authoritative,
                styleReference: "Steve Jobs keynotes — clear, decisive openings.",
                coachingBrief: "Sharpen the first 10 seconds of every talk.",
                motivationWhyNow: "Speaking at a leadership offsite next month.",
                successVision: "Open with a line that lands."
            )
        case .pressureVulnerable:
            // Casual reps land, pressure reps blow up. Calmer-delivery
            // primary goal + executive presence; the user is targeting
            // boardroom composure, not warmth.
            return CoachingProfile(
                speakingContext: .interviews,
                primaryGoal: .calmerDelivery,
                confidenceLevel: .inconsistent,
                biggestChallenge: .rushing,
                desiredOutcome: .composed,
                speakingStyleGoal: .executive,
                styleReference: "Composed under fire — board updates, hard questions.",
                coachingBrief: "Keep pace and pitch steady when stakes rise.",
                motivationWhyNow: "Series B fundraise — investor Q&A coming up.",
                successVision: "Sound the same calm whether the question is easy or hard."
            )
        case .fillerFree:
            // Strong baseline across the board. Concise voice + persuasive
            // outcome — the user is honing edge cases, not basics.
            return CoachingProfile(
                speakingContext: .presentations,
                primaryGoal: .moreConcise,
                confidenceLevel: .confident,
                biggestChallenge: .rambling,
                desiredOutcome: .persuasive,
                speakingStyleGoal: .concise,
                styleReference: "Tight, no wasted words — analyst-call register.",
                coachingBrief: "Drop one more unnecessary word per sentence.",
                motivationWhyNow: "Keynoting at a conference in eight weeks.",
                successVision: "Every sentence pulls weight."
            )
        }
    }

    /// XP that matches the seed profile's narrative. 1000 XP = one level
    /// (Beginner → Novice → Average → Professional → World Class). The
    /// values are tuned so the seeded user lands somewhere honest for
    /// their session count: improvingIntermediate (12 sessions, scores
    /// 4→7) lands mid-Novice; plateauedAdvanced (20 sessions, stable
    /// strong) lands deep-Average; fillerFree (18 near-zero sessions)
    /// approaches Professional.
    private static func seedXP(for profile: SeedProfile) -> Int {
        switch profile {
        case .beginner:               return 220   // Beginner Speaker I
        case .improvingIntermediate:  return 1_280 // Novice Speaker II
        case .plateauedAdvanced:      return 3_450 // Average Speaker IV
        case .pressureVulnerable:     return 2_150 // Average Speaker I
        case .fillerFree:             return 4_600 // Average → Professional
        }
    }

    /// Build a `SpeakingRating` aligned with the seed profile's narrative.
    /// `improvingIntermediate` is the showcase profile, so it gets a clear
    /// current-week peak that drives the Figma-spec premium hero.
    private static func seedRating(for profile: SeedProfile) -> SpeakingRating {
        let comps = Calendar.current.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())
        let week = comps.weekOfYear ?? 1
        let year = comps.yearForWeekOfYear ?? 2026

        switch profile {
        case .improvingIntermediate:
            return SpeakingRating(
                overall: 612,
                peakRating: 624,
                ratingHistory: [],
                personalBests: [],
                totalRatedSessions: 12,
                weekPeakRating: 624,
                weekPeakISOWeek: week,
                weekPeakISOYear: year
            )
        case .plateauedAdvanced:
            return SpeakingRating(
                overall: 720,
                peakRating: 740,
                ratingHistory: [],
                personalBests: [],
                totalRatedSessions: 20,
                weekPeakRating: 728,
                weekPeakISOWeek: week,
                weekPeakISOYear: year
            )
        case .fillerFree:
            return SpeakingRating(
                overall: 780,
                peakRating: 820,
                ratingHistory: [],
                personalBests: [],
                totalRatedSessions: 18,
                weekPeakRating: 820,
                weekPeakISOWeek: week,
                weekPeakISOYear: year
            )
        case .pressureVulnerable:
            return SpeakingRating(
                overall: 540,
                peakRating: 612,
                ratingHistory: [],
                personalBests: [],
                totalRatedSessions: 15,
                weekPeakRating: 568,
                weekPeakISOWeek: week,
                weekPeakISOYear: year
            )
        case .beginner:
            // Beginner: no peak yet, stay at initial so the home falls back
            // to the calm hero rather than mis-celebrating.
            return .initial
        }
    }

    private static func seedReflections(
        for profile: SeedProfile,
        sessions: [PracticeSession]
    ) -> [SessionReflection] {
        let newest = sessions.sorted { $0.date > $1.date }
        let reflections: [(ReflectionFeeling, String)] = {
            switch profile {
            case .beginner:
                return [
                    (.nervous, "I knew the answer, but I filled the silence."),
                    (.heldBack, "I kept restarting instead of landing the first point."),
                    (.notLikeMe, "It sounded more apologetic than I wanted.")
                ]
            case .improvingIntermediate:
                return [
                    (.strong, "I cut the preamble and got to the point faster."),
                    (.heldBack, "The close still felt softer than the idea."),
                    (.strong, "The second answer felt more like how I want to sound."),
                    (.nervous, "I rushed when I imagined the room pushing back.")
                ]
            case .plateauedAdvanced:
                return [
                    (.heldBack, "The middle was strong, but the opener still eased in."),
                    (.strong, "Once I named the frame, it felt controlled."),
                    (.notLikeMe, "Polished, but a little rehearsed.")
                ]
            case .pressureVulnerable:
                return [
                    (.nervous, "The hard question made me speed up immediately."),
                    (.heldBack, "I softened the answer instead of holding the line."),
                    (.strong, "The calm rep felt much closer to my normal voice."),
                    (.nervous, "I could feel the pace jump when the stakes went up.")
                ]
            case .fillerFree:
                return [
                    (.notLikeMe, "Clean, but a little too clipped."),
                    (.strong, "The structure held and the transitions were simple."),
                    (.heldBack, "I trimmed so much that one proof point disappeared.")
                ]
            }
        }()

        return zip(newest, reflections).map { session, reflection in
            SessionReflection(
                sessionID: session.id,
                feeling: reflection.0,
                note: reflection.1,
                recordedAt: session.date.addingTimeInterval(600)
            )
        }
    }

    private static func seedCheckIn(for profile: SeedProfile, now: Date) -> CoachCheckIn {
        let fields: (hardest: String, outside: String, verdict: CoachDrillVerdict)
        switch profile {
        case .beginner:
            fields = (
                "Letting a pause exist without apologizing for it.",
                "Team standup. I had the point but padded it.",
                .stalled
            )
        case .improvingIntermediate:
            fields = (
                "Keeping the first sentence short when a stakeholder asks a broad question.",
                "Cross-functional sync. The short opener helped, but the close still softened.",
                .helped
            )
        case .plateauedAdvanced:
            fields = (
                "Opening with a point of view instead of context-setting.",
                "Leadership prep. The story was strong after the first 10 seconds.",
                .stalled
            )
        case .pressureVulnerable:
            fields = (
                "Staying at the same pace when the question gets adversarial.",
                "Investor dry run. I knew the material but sounded hurried under challenge.",
                .missed
            )
        case .fillerFree:
            fields = (
                "Keeping warmth while cutting excess words.",
                "Conference rehearsal. The points landed, but one answer felt too compressed.",
                .helped
            )
        }
        return CoachCheckIn(
            recordedAt: now.addingTimeInterval(-86_400),
            hardest: fields.hardest,
            outsideApp: fields.outside,
            drillVerdict: fields.verdict
        )
    }

    private static func seedBigMoment(for profile: SeedProfile, now: Date) -> BigMoment {
        let daysOut: Int
        let title: String
        let category: BigMomentCategory
        switch profile {
        case .beginner:
            daysOut = 5
            title = "Team standup"
            category = .presentation
        case .improvingIntermediate:
            daysOut = 9
            title = "Stakeholder review"
            category = .review
        case .plateauedAdvanced:
            daysOut = 18
            title = "Leadership offsite keynote"
            category = .presentation
        case .pressureVulnerable:
            daysOut = 12
            title = "Investor Q&A"
            category = .interview
        case .fillerFree:
            daysOut = 28
            title = "Conference keynote"
            category = .publicSpeaking
        }
        let date = Calendar.current.date(byAdding: .day, value: daysOut, to: now) ?? now
        return BigMoment(
            title: title,
            date: date,
            category: category,
            createdAt: now.addingTimeInterval(-10 * 86_400)
        )
    }

    private static func seedTransferReports(
        for profile: SeedProfile,
        activeMoment: BigMoment,
        now: Date
    ) -> [BigMomentOutcomeReport] {
        let pattern: [(ReportedMomentOutcome, ReportedAudienceResponse, ReportedDrillTransfer, String)]
        switch profile {
        case .beginner:
            pattern = [
                (.mixed, .unclear, .partly, "I paused once instead of saying um, but still rambled."),
                (.fellShort, .resistant, .didNotTransfer, "I lost the first sentence when someone interrupted."),
                (.mixed, .unclear, .partly, "The opener was clearer; the middle drifted.")
            ]
        case .improvingIntermediate:
            pattern = [
                (.mixed, .engaged, .partly, "Short opener worked; I softened the final recommendation."),
                (.wentWell, .engaged, .transferred, "The one-sentence answer landed and questions were sharper."),
                (.mixed, .unclear, .partly, "I was concise at first, then added caveats near the end.")
            ]
        case .plateauedAdvanced:
            pattern = [
                (.mixed, .engaged, .partly, "The body was strong, but the opener still needed a cleaner thesis."),
                (.wentWell, .engaged, .transferred, "Once the opening claim landed, the room followed."),
                (.mixed, .unclear, .partly, "Good material, too much runway before the point.")
            ]
        case .pressureVulnerable:
            pattern = [
                (.mixed, .resistant, .partly, "Prepared answer helped, but I sped up on the challenge."),
                (.fellShort, .resistant, .didNotTransfer, "The pressure made me hedge the conclusion."),
                (.mixed, .unclear, .partly, "Better recovery after pausing, still rushed the first response.")
            ]
        case .fillerFree:
            pattern = [
                (.wentWell, .engaged, .transferred, "The tighter answers were easy to follow."),
                (.mixed, .unclear, .partly, "Clear, but one answer needed more connective tissue."),
                (.wentWell, .engaged, .transferred, "The concise structure made the Q&A smoother.")
            ]
        }

        return pattern.enumerated().map { index, item in
            let recordedAt = now.addingTimeInterval(Double(-(index * 5 + 2)) * 86_400)
            let moment = BigMoment(
                title: "\(activeMoment.title) rehearsal \(index + 1)",
                date: recordedAt.addingTimeInterval(-86_400),
                category: activeMoment.category,
                createdAt: recordedAt.addingTimeInterval(-8 * 86_400)
            )
            return BigMomentOutcomeReport(
                moment: moment,
                outcome: item.0,
                audienceResponse: item.1,
                note: item.3,
                drillTransfer: item.2,
                recordedAt: recordedAt
            )
        }
    }

    private static func seedRecommendationOutcomes(
        for profile: SeedProfile,
        sessions: [PracticeSession],
        now: Date
    ) -> [RecommendationOutcome] {
        let newest = sessions.sorted { $0.date > $1.date }
        let mode: PracticeMode
        let title: String
        let focus: String
        let target: String
        let scoreDeltas: [Double]
        let fillerDeltas: [Double]
        let goal: SpeakingStyleGoal
        let targetDimensionID: String
        switch profile {
        case .beginner:
            mode = .timed
            title = "Pause before the first sentence"
            focus = "opening control"
            target = "One clean opening sentence before any explanation."
            scoreDeltas = [0.4, -0.2]
            fillerDeltas = [-0.5, 0.4]
            goal = .warm
            targetDimensionID = "controlled_pacing"
        case .improvingIntermediate:
            mode = .timed
            title = "One-sentence answer structure"
            focus = "concise stakeholder answers"
            target = "Open with the answer, then add one proof point."
            scoreDeltas = [1.2, 1.0, 0.8, 0.6]
            fillerDeltas = [-2.0, -1.5, -1.0, -0.8]
            goal = .warm
            // The seeded warm persona's live read is deliberately weakest on
            // salience. Keep the historical fixture on that same target so
            // the UI can demonstrate repeated, comparable evidence rather
            // than treating one good follow-up as a shareable milestone.
            targetDimensionID = "salience"
        case .plateauedAdvanced:
            mode = .timed
            title = "Thesis-first opening"
            focus = "decisive openings"
            target = "Lead with the claim before context."
            scoreDeltas = [0.1, -0.1, 0.2, 0.0]
            fillerDeltas = [0.0, -0.2, 0.1, 0.0]
            goal = .authoritative
            targetDimensionID = "verdict_first"
        case .pressureVulnerable:
            mode = .suddenDeath
            title = "Pressure pace hold"
            focus = "calm under challenge"
            target = "Answer hard questions without a pace spike."
            scoreDeltas = [-1.1, -0.8, -0.4, 0.2]
            fillerDeltas = [2.0, 1.4, 0.9, -0.2]
            goal = .executive
            targetDimensionID = "pressure_stability"
        case .fillerFree:
            mode = .timed
            title = "Cut one extra clause"
            focus = "precision without losing warmth"
            target = "Keep the proof point while removing one qualifier."
            scoreDeltas = [0.6, 0.3, 0.4, 0.5]
            fillerDeltas = [-0.1, 0.0, -0.2, 0.0]
            goal = .concise
            targetDimensionID = "clean_close"
        }

        let scopedSessions = newest.filter { $0.mode == mode }
        let fallbackSessions = scopedSessions.isEmpty ? newest : scopedSessions
        return Array(fallbackSessions.prefix(scoreDeltas.count)).enumerated().map { index, session in
            RecommendationOutcome(
                id: UUID(),
                fingerprint: "dev-seed.\(profile.rawValue).\(mode.rawValue).\(focus)",
                title: title,
                focus: focus,
                target: target,
                mode: mode,
                sessionID: session.id,
                followed: session.mode == mode,
                completedAt: min(session.date.addingTimeInterval(3_600), now.addingTimeInterval(Double(-index) * 600)),
                scoreDelta: scoreDeltas[index],
                hasComparableScore: true,
                fillerDelta: fillerDeltas[index],
                durationDelta: 4,
                goal: goal,
                targetDimensionID: targetDimensionID,
                goalFollowUpResult: RecommendationLearningStore.goalFollowUpResult(
                    followed: session.mode == mode,
                    comparableScoreDelta: scoreDeltas[index],
                    fillerDelta: fillerDeltas[index],
                    comparablePaceDelta: nil
                )
            )
        }
    }

    private static func seedProofs(
        for profile: SeedProfile,
        sessions: [PracticeSession],
        now: Date
    ) -> [ProofMomentRecord] {
        let newest = sessions.sorted { $0.date > $1.date }
        let voiceAtGeneration = seedCoachingProfile(for: profile).chosenStyleGoal
        let technique: String
        let claim: String
        switch profile {
        case .beginner:
            technique = "Clean Pause"
            claim = "A pause can replace a filler without losing the thread."
        case .improvingIntermediate:
            technique = "Answer First"
            claim = "That is concise warmth: clear point, then support."
        case .plateauedAdvanced:
            technique = "Thesis First"
            claim = "The opening starts carrying more authority."
        case .pressureVulnerable:
            technique = "Composure Reset"
            claim = "A calmer beat gives the answer room under pressure."
        case .fillerFree:
            technique = "Lean Proof"
            claim = "Precision works when the evidence still stays visible."
        }

        return newest.prefix(3).enumerated().map { index, session in
            let proof = ProofMoment(
                quote: proofQuote(from: session.transcript),
                technique: technique,
                claim: claim,
                sessionDate: session.date,
                isAIBacked: false,
                generatedAt: now.addingTimeInterval(Double(-index) * 300)
            )
            return ProofMomentRecord(
                sessionID: session.id,
                proof: proof,
                addedAt: now.addingTimeInterval(Double(-index) * 300),
                voiceAtGeneration: voiceAtGeneration
            )
        }
    }

    private static func proofQuote(from transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let sentence = trimmed.split(separator: ".", maxSplits: 1).first.map(String.init) ?? trimmed
        return String(sentence.prefix(120))
    }

    /// Generate a summary of what a seed profile produces (for debug display).
    static func profileSummary(_ profile: SeedProfile) -> String {
        let sessions = sessions(for: profile)
        let baseline = BaselineEngine.compute(from: sessions)
        var pressure = PressureProfile.empty
        for session in sessions {
            pressure = BaselineEngine.updatePressureProfile(pressure, session: session, pressure: session.pressureLevel)
        }
        let confidence = baseline.overallConfidence

        var lines: [String] = []
        lines.append("Profile: \(profile.displayName)")
        lines.append("Sessions: \(sessions.count)")
        lines.append("Confidence: \(confidence.label)")
        lines.append("Avg score: \(String(format: "%.1f", baseline.averageScore.value))")
        lines.append("Filler rate: \(String(format: "%.1f", baseline.fillerRate.value))/min")
        lines.append("Pace: \(String(format: "%.0f", baseline.pace.value)) WPM")
        if !baseline.topStrengths.isEmpty {
            lines.append("Strengths: \(baseline.topStrengths.joined(separator: ", "))")
        }
        if !baseline.persistentBlockers.isEmpty {
            lines.append("Blockers: \(baseline.persistentBlockers.joined(separator: ", "))")
        }
        if let resilience = pressure.pressureResilience {
            lines.append("Pressure resilience: \(String(format: "%.0f", resilience * 100))%")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Session Generators

    private static func beginnerSessions() -> [PracticeSession] {
        // 5 sessions, spread over 5 days, high fillers, short duration, inconsistent scores
        let baseDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        return (0..<5).map { i in
            let date = Calendar.current.date(byAdding: .day, value: i, to: baseDate)!
            let fillers = [8, 12, 6, 10, 9][i]
            let duration: TimeInterval = [25, 18, 30, 15, 22][Double.self == Double.self ? i : 0]
            let score = [3, 2, 4, 3, 4][i]
            let transcript = beginnerTranscripts[i % beginnerTranscripts.count]
            return makeSession(
                transcript: transcript, fillers: fillers, duration: duration,
                date: date, mode: .timed, score: score, pressure: .standard
            )
        }
    }

    private static func improvingIntermediateSessions() -> [PracticeSession] {
        // 12 sessions over 14 days. Fillers start at 6, drop to 2. Score 4 → 7.
        let baseDate = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        return (0..<12).map { i in
            let dayOffset = i + (i >= 5 ? 1 : 0) + (i >= 9 ? 1 : 0) // skip a couple days
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: baseDate)!
            let fillerProgression = [6, 5, 5, 4, 4, 3, 3, 3, 2, 2, 2, 1]
            let scoreProgression = [4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 7, 7]
            let durationProgression: [TimeInterval] = [25, 28, 30, 32, 35, 38, 40, 42, 45, 45, 48, 50]
            let transcript = intermediateTranscripts[i % intermediateTranscripts.count]
            return makeSession(
                transcript: transcript, fillers: fillerProgression[i],
                duration: durationProgression[i], date: date,
                mode: .timed, score: scoreProgression[i], pressure: .standard
            )
        }
    }

    private static func plateauedAdvancedSessions() -> [PracticeSession] {
        // 20 sessions over 25 days. Strong on most things, consistently weak openings.
        let baseDate = Calendar.current.date(byAdding: .day, value: -25, to: Date())!
        return (0..<20).map { i in
            let dayOffset = i + (i >= 7 ? 1 : 0) + (i >= 14 ? 2 : 0)
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: baseDate)!
            let fillers = [2, 1, 2, 1, 1, 2, 1, 0, 1, 1, 2, 1, 0, 1, 1, 0, 1, 1, 0, 1][i]
            let score = [6, 7, 6, 7, 7, 6, 7, 7, 6, 7, 7, 6, 7, 7, 6, 7, 7, 7, 7, 6][i]
            let duration: TimeInterval = Double([40, 45, 42, 48, 50, 45, 48, 52, 45, 50, 48, 45, 50, 52, 48, 50, 55, 52, 50, 48][i])
            let transcript = advancedTranscripts[i % advancedTranscripts.count]
            return makeSession(
                transcript: transcript, fillers: fillers, duration: duration,
                date: date, mode: .timed, score: score, pressure: .standard,
                categoryOverrides: ["Opening": "Could improve", "Structure": "Good", "Depth": "Good"]
            )
        }
    }

    private static func pressureVulnerableSessions() -> [PracticeSession] {
        // 15 sessions: 10 casual (strong), 5 high-pressure (weak)
        let baseDate = Calendar.current.date(byAdding: .day, value: -18, to: Date())!
        var sessions: [PracticeSession] = []

        // Casual sessions — strong performance
        for i in 0..<10 {
            let date = Calendar.current.date(byAdding: .day, value: i, to: baseDate)!
            let transcript = advancedTranscripts[i % advancedTranscripts.count]
            sessions.append(makeSession(
                transcript: transcript, fillers: [1, 0, 1, 0, 0, 1, 0, 1, 0, 0][i],
                duration: Double([45, 50, 48, 52, 55, 48, 50, 52, 50, 48][i]),
                date: date, mode: .timed, score: [7, 8, 7, 8, 8, 7, 8, 8, 8, 7][i],
                pressure: .casual
            ))
        }

        // Pressure sessions — performance degrades
        for i in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: 11 + i, to: baseDate)!
            let transcript = pressureTranscripts[i % pressureTranscripts.count]
            sessions.append(makeSession(
                transcript: transcript, fillers: [5, 7, 4, 6, 5][i],
                duration: Double([30, 25, 35, 28, 32][i]),
                date: date, mode: .suddenDeath, score: [4, 3, 5, 4, 4][i],
                pressure: .high
            ))
        }

        return sessions
    }

    private static func fillerFreeSessions() -> [PracticeSession] {
        // 18 sessions, near-zero fillers, consistently high scores
        let baseDate = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        return (0..<18).map { i in
            let dayOffset = i + (i >= 6 ? 1 : 0) + (i >= 12 ? 1 : 0)
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: baseDate)!
            let fillers = [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0][i]
            let score = [8, 8, 7, 8, 9, 8, 8, 9, 8, 9, 8, 9, 8, 9, 9, 8, 9, 9][i]
            let duration: TimeInterval = Double([50, 55, 48, 52, 58, 55, 52, 60, 55, 58, 52, 55, 60, 58, 55, 60, 58, 60][i])
            let transcript = advancedTranscripts[i % advancedTranscripts.count]
            return makeSession(
                transcript: transcript, fillers: fillers, duration: duration,
                date: date, mode: .timed, score: score, pressure: .standard,
                categoryOverrides: ["Opening": "Good", "Structure": "Good", "Depth": "Good"]
            )
        }
    }

    // MARK: - Helpers

    private static func makeSession(
        transcript: String,
        fillers: Int,
        duration: TimeInterval,
        date: Date,
        mode: PracticeMode,
        score: Int,
        pressure: PressureLevel,
        categoryOverrides: [String: String]? = nil
    ) -> PracticeSession {
        var session = PracticeSession(
            transcript: transcript,
            fillerWordCount: fillers,
            duration: duration,
            date: date,
            mode: mode,
            pressureLevel: pressure
        )
        session.score = score
        session.headline = headlineForScore(score)
        session.insights = insightsForSession(fillers: fillers, score: score, duration: duration)
        return session
    }

    private static func headlineForScore(_ score: Int) -> String {
        switch score {
        case 0...3: return "Room to grow"
        case 4...5: return "Building momentum"
        case 6...7: return "Solid delivery"
        case 8...9: return "Strong session"
        default: return "Exceptional"
        }
    }

    private static func insightsForSession(fillers: Int, score: Int, duration: TimeInterval) -> [String] {
        var insights: [String] = []
        if fillers == 0 { insights.append("Zero fillers — clean delivery.") }
        else if fillers > 5 { insights.append("Filler words are disrupting your flow.") }
        if score >= 7 { insights.append("Good structure and development.") }
        if duration > 45 { insights.append("Strong duration — you're developing your ideas fully.") }
        else if duration < 20 { insights.append("Try expanding your responses with more examples.") }
        if insights.isEmpty { insights.append("Steady progress — keep practicing.") }
        return insights
    }

    private static func categoryRatingsForSession(_ session: PracticeSession) -> [String: String] {
        let score = session.score ?? 5
        if score >= 7 {
            return ["Opening": "Good", "Structure": "Good", "Depth": score >= 8 ? "Good" : "OK"]
        } else if score >= 5 {
            return ["Opening": "OK", "Structure": "OK", "Depth": "OK"]
        } else {
            return ["Opening": "Could improve", "Structure": "Could improve", "Depth": "Could improve"]
        }
    }

    // MARK: - Sample Transcripts

    private static let beginnerTranscripts = [
        "So um I think like the most important thing about leadership is um you know being there for people. Like when you uh think about great leaders they um always like listen and stuff.",
        "Uh well I guess for me like the key to good communication is um being honest. Like you know when people are honest with each other it just like works better I think.",
        "So um basically I would say that like teamwork is really important because uh you know when everyone works together like things get done faster and um everyone feels like they contributed.",
        "I think um the biggest challenge in my career was like when I had to uh present to the whole company. It was um really nerve-wracking and I like totally forgot what I was going to say.",
        "Well so like I believe that um the future of technology is uh you know going to change everything. Like AI and stuff is um already changing how we like work and communicate."
    ]

    private static let intermediateTranscripts = [
        "I believe the most important quality in a leader is empathy. When leaders um understand their team's perspectives, they build trust. The key is showing that you genuinely care about each person's growth.",
        "Communication starts with listening. In my experience, the best conversations happen when both parties feel heard. I try to like ask clarifying questions before jumping to solutions.",
        "One challenge I faced was leading a cross-functional project with tight deadlines. I learned that clear expectations and regular check-ins prevented most issues before they escalated.",
        "Teamwork requires both individual accountability and collective trust. When each person knows their role and trusts their teammates, the whole group performs at a higher level.",
        "The future of our industry will be shaped by how well we adapt to change. Companies that invest in continuous learning and embrace new tools will have a significant competitive advantage."
    ]

    private static let advancedTranscripts = [
        "The distinction between management and leadership lies in vision. Managers maintain systems. Leaders define direction. The best organizations have both — people who keep the trains running and people who decide where the tracks should go.",
        "When I look at effective decision-making, I see three consistent patterns: clear criteria, diverse input, and committed follow-through. The mistake most teams make is skipping the criteria step and jumping straight to debate.",
        "Building a culture of feedback requires psychological safety first. If people fear consequences for speaking up, no amount of feedback frameworks will work. Start by modeling vulnerability at the top.",
        "The most underrated skill in professional settings is the ability to synthesize complex information into clear narratives. Data tells you what happened. Stories explain why it matters.",
        "Strategic thinking isn't about predicting the future. It's about building optionality. The best strategies create multiple paths forward, so you can adapt as conditions change."
    ]

    private static let pressureTranscripts = [
        "Um so I think that uh in a high-pressure situation the most important thing is like staying calm. You know when everything is um falling apart you need to uh just take a breath and like think clearly.",
        "Well uh I guess the challenge with uh presenting under pressure is that you um tend to speed up and like lose your train of thought. I uh try to like slow down but it's really uh hard sometimes.",
        "So the uh thing about sudden death is that it um makes you really aware of like every word you say. You know you're just uh thinking about not making mistakes instead of like actually communicating.",
        "I think um the key to handling pressure is uh preparation. When you know your material really well you can um still deliver even when you're like nervous and stuff.",
        "Under pressure I uh tend to fall back on like filler words more. It's um almost automatic when I'm uh stressed. I need to work on like pausing instead of um filling silence."
    ]
}

// MARK: - Store Extension for Debug Injection

extension PracticeSessionStore {
    /// Replace all sessions with debug data. DEBUG ONLY.
    /// Writes directly to UserDefaults and reloads.
    func replaceAllForDebug(_ newSessions: [PracticeSession]) {
        let accountID = KeychainHelper.load(key: "NoumAccountID") ?? ""
        let key = accountID.isEmpty ? "practiceSessions.guest" : "practiceSessions.\(accountID)"
        if let data = try? JSONEncoder().encode(newSessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
        reload()
    }
}

#endif
