import Foundation

// MARK: - User trajectory cache

/// In-memory cache for the compact state the judgement pass needs. It avoids
/// rebuilding the same trajectory summary during repeated chat turns while
/// keeping the durable ownership in existing stores.
final class UserTrajectoryCache {
    static let shared = UserTrajectoryCache()

    private let lock = NSLock()
    private var cachedSignature: String?
    private var cachedSnapshot: UserTrajectorySnapshot?

    private init() {}

    func snapshot(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        rating: SpeakingRating,
        sessions: [PracticeSession],
        coachMemory: CoachMemory?
    ) -> UserTrajectoryCacheResult {
        let signature = Self.signature(
            profile: profile,
            baseline: baseline,
            rating: rating,
            sessions: sessions,
            coachMemory: coachMemory
        )
        lock.lock()
        defer { lock.unlock() }
        if let cachedSnapshot, cachedSignature == signature {
            return UserTrajectoryCacheResult(snapshot: cachedSnapshot, cacheHit: true)
        }

        let built = Self.build(
            profile: profile,
            baseline: baseline,
            rating: rating,
            sessions: sessions,
            coachMemory: coachMemory
        )
        cachedSignature = signature
        cachedSnapshot = built
        return UserTrajectoryCacheResult(snapshot: built, cacheHit: false)
    }

    func invalidate() {
        lock.lock()
        cachedSignature = nil
        cachedSnapshot = nil
        lock.unlock()
        CoachAssessmentCache.shared.invalidate()
    }

    @discardableResult
    @MainActor
    func warmFromCurrentStores() -> UserTrajectoryCacheResult {
        snapshot(
            profile: CoachingProfileStore.shared.profile,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            sessions: PracticeSessionStore.shared.sessions,
            coachMemory: CoachMemoryStore.shared.currentMemory
        )
    }

    @discardableResult
    @MainActor
    func invalidateAndWarmFromCurrentStores() -> UserTrajectoryCacheResult {
        invalidate()
        return warmFromCurrentStores()
    }

    private static func signature(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        rating: SpeakingRating,
        sessions: [PracticeSession],
        coachMemory: CoachMemory?
    ) -> String {
        let latestSession = sessions.max(by: { $0.date < $1.date })
        let latestID = latestSession?.id.uuidString ?? "none"
        let latestDate = latestSession?.date.timeIntervalSince1970 ?? 0
        let latestCount = sessions.count
        let profileVoice = profile?.speakingStyleGoal.rawValue ?? "none"
        let memoryUpdated = coachMemory?.updatedAt.timeIntervalSince1970 ?? 0
        return [
            "voice=\(profileVoice)",
            "sessions=\(latestCount)",
            "latest=\(latestID)",
            "latestDate=\(Int(latestDate))",
            "rating=\(rating.overall)",
            "rated=\(rating.totalRatedSessions)",
            "baseline=\(baseline.overallConfidence.rawValue)",
            "memory=\(Int(memoryUpdated))"
        ].joined(separator: "|")
    }

    private static func build(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        rating: SpeakingRating,
        sessions: [PracticeSession],
        coachMemory: CoachMemory?
    ) -> UserTrajectorySnapshot {
        let sorted = sessions.sorted { $0.date > $1.date }
        let recent = Array(sorted.prefix(5))
        let coverage = evidenceCoverage(
            sessions: sessions,
            rating: rating,
            baseline: baseline,
            coachMemory: coachMemory
        )

        let recentLines = recent.prefix(3).map { session -> String in
            let score = session.score.map { "\($0)/10" } ?? "no score"
            let duration = "\(Int(session.duration.rounded()))s"
            return "\(session.mode.displayLabel): \(score), \(session.fillerWordCount) fillers, \(duration)"
        }

        let trendLines = trendLines(from: sorted, baseline: baseline)

        return UserTrajectorySnapshot(
            generatedAt: Date(),
            sessionCount: sessions.count,
            ratedSessionCount: rating.totalRatedSessions,
            evidenceCoverage: coverage,
            recentSessionLines: recentLines,
            trendLines: trendLines,
            latestRepEvidencePack: sorted.first.map(latestRepPack),
            coachCaseSummary: coachMemory.map(caseSummary),
            activeInterventionState: coachMemory.flatMap(activeIntervention)
        )
    }

    private static func evidenceCoverage(
        sessions: [PracticeSession],
        rating: SpeakingRating,
        baseline: CommunicationBaseline,
        coachMemory: CoachMemory?
    ) -> Double {
        let sessionDepth = min(1.0, Double(max(sessions.count, rating.totalRatedSessions)) / 10.0)
        let baselineLift: Double
        switch baseline.overallConfidence {
        case .insufficient:
            baselineLift = 0.0
        case .tentative:
            baselineLift = 0.12
        case .moderate:
            baselineLift = 0.20
        case .established, .stable:
            baselineLift = 0.28
        }
        let memoryLift = coachMemory?.caseFile == nil ? 0.0 : 0.14
        let localLift = latestUsableRepLift(from: sessions.max(by: { $0.date < $1.date }))
        let diversityLift = practiceDiversityLift(from: sessions)
        let raw = (sessionDepth * 0.50) + baselineLift + memoryLift + localLift + diversityLift
        let capped: Double
        if sessions.count < 3 {
            // One or two reps can support a useful local read, but not an
            // overall-goal verdict. Keep the cap low enough that the semantic
            // gate still requires missing-evidence language.
            capped = min(raw, sessions.isEmpty ? 0.05 : 0.42)
        } else {
            capped = raw
        }
        return max(0.05, min(1.0, capped))
    }

    private static func latestUsableRepLift(from session: PracticeSession?) -> Double {
        guard let session else { return 0.0 }
        let words = session.transcript.split { $0.isWhitespace || $0.isNewline }.count
        var lift = 0.0
        if session.score != nil { lift += 0.06 }
        if session.duration >= 45 {
            lift += 0.06
        } else if session.duration >= 20 {
            lift += 0.03
        }
        if words >= 55 {
            lift += 0.06
        } else if words >= 25 {
            lift += 0.03
        }
        if session.transcriptConfidence.map({ $0 >= 0.55 }) ?? false {
            lift += 0.03
        }
        if session.pressureLevel >= .elevated || session.mode == .suddenDeath {
            lift += 0.05
        }
        return min(0.18, lift)
    }

    private static func practiceDiversityLift(from sessions: [PracticeSession]) -> Double {
        guard sessions.count >= 2 else { return 0.0 }
        let modes = Set(sessions.map(\.mode))
        let hasPressure = sessions.contains { $0.pressureLevel >= .elevated || $0.mode == .suddenDeath }
        var lift = 0.0
        if modes.count >= 2 { lift += 0.04 }
        if hasPressure { lift += 0.05 }
        return min(0.09, lift)
    }

    private static func latestRepPack(_ session: PracticeSession) -> LatestRepEvidencePack {
        let words = session.transcript
            .split { $0.isWhitespace || $0.isNewline }
            .map(String.init)
        let wordsPerMinute: Int? = session.duration > 0
            ? Int((Double(words.count) / max(session.duration, 1)) * 60.0)
            : nil
        let excerpt = words.isEmpty ? nil : words.prefix(26).joined(separator: " ")
        var evidence: [String] = [
            "latest rep: \(session.mode.displayLabel), \(session.score.map { "\($0)/10" } ?? "no score"), \(session.fillerWordCount) fillers, \(Int(session.duration.rounded()))s"
        ]
        if let wordsPerMinute {
            evidence.append("pace estimate: \(wordsPerMinute) WPM")
        }
        if let excerpt {
            evidence.append("transcript signal: \(excerpt)")
        }
        return LatestRepEvidencePack(
            mode: session.mode.displayLabel,
            score: session.score,
            fillerCount: session.fillerWordCount,
            durationSeconds: Int(session.duration.rounded()),
            wordsPerMinute: wordsPerMinute,
            transcriptWordCount: words.count,
            transcriptExcerpt: excerpt,
            evidenceLines: evidence
        )
    }

    private static func trendLines(
        from sorted: [PracticeSession],
        baseline: CommunicationBaseline
    ) -> [String] {
        var lines: [String] = []
        if sorted.count >= 3 {
            let latestThree = Array(sorted.prefix(3))
            let avgFillers = Double(latestThree.map(\.fillerWordCount).reduce(0, +)) / Double(latestThree.count)
            lines.append("recent filler average: \(String(format: "%.1f", avgFillers)) per rep across last 3")
        }
        if baseline.fillerRate.confidence != .insufficient {
            lines.append("baseline filler rate: \(String(format: "%.1f", baseline.fillerRate.value))/min")
        }
        if baseline.pace.confidence != .insufficient {
            lines.append("baseline pace: \(Int(baseline.pace.value.rounded())) WPM")
        }
        if baseline.hedgingRate.confidence != .insufficient {
            lines.append("baseline hedging: \(String(format: "%.1f", baseline.hedgingRate.value))/min")
        }
        return Array(lines.prefix(4))
    }

    private static func caseSummary(_ memory: CoachMemory) -> CoachCaseSummary {
        CoachCaseSummary(
            hypothesis: memory.caseFile?.hypothesis ?? memory.workingHypothesis,
            focus: memory.caseFile?.focus?.displayName ?? memory.currentLever?.displayName,
            evidenceSummary: memory.caseFile?.evidenceSummary ?? memory.currentLeverBasis,
            nextCoachMove: memory.caseFile?.nextMove.contextLabel
        )
    }

    private static func activeIntervention(_ memory: CoachMemory) -> ActiveInterventionState? {
        guard let intervention = memory.activeIntervention else { return nil }
        return ActiveInterventionState(
            title: intervention.title,
            target: intervention.target,
            followedRepCount: intervention.followedRepCount,
            reviewStatus: intervention.reviewStatus.contextLabel
        )
    }
}
