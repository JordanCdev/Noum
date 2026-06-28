//
//  CoachLiveEvaluationTests.swift
//  NoumTests
//
//  Skipped-by-default live Ask Noum eval harness.
//
//  Run manually with:
//    xcodebuild test -scheme Noum \
//      -destination 'platform=iOS Simulator,id=<id>' \
//      -only-testing:NoumTests/CoachLiveEvaluationTests \
//      OTHER_SWIFT_FLAGS='$(inherited) -D NOUM_LIVE_AI_EVAL -D NOUM_LIVE_AI_EVAL_SINGLE'
//
//  Provider selectors:
//    NOUM_LIVE_AI_PROVIDER_CHAIN=agent-platform|gemini|claude|production
//    -D NOUM_LIVE_AI_EVAL_AGENT_PLATFORM_ONLY
//    -D NOUM_LIVE_AI_EVAL_GEMINI_ONLY
//    -D NOUM_LIVE_AI_EVAL_CLAUDE_ONLY
//    -D NOUM_LIVE_AI_EVAL_PRODUCTION_CHAIN
//
//  Fixture selectors:
//    NOUM_LIVE_AI_FIXTURES=latest-transcript
//    NOUM_LIVE_AI_FIXTURES=fixture-id,another-fixture-id
//    -D NOUM_LIVE_AI_EVAL_SINGLE
//    -D NOUM_LIVE_AI_EVAL_COLD_START
//    -D NOUM_LIVE_AI_EVAL_TRUST_REPAIR
//    -D NOUM_LIVE_AI_EVAL_OVERCLAIM
//    -D NOUM_LIVE_AI_EVAL_LATEST_TRANSCRIPT
//    -D NOUM_LIVE_AI_EVAL_FULL_CORPUS
//
//  This is not CI evidence and not a claim of human-coach parity. It is a
//  repeatable transcript capture for the exact live model path, context builder,
//  quote guard, RAG cards, and professional-coach gate the product uses.
//

import Foundation
import Testing
@testable import Noum

@Suite("CoachLiveEvaluationTests")
struct CoachLiveEvaluationTests {

    @Test func latestTranscriptPresetCoversEveryManualEvalTurn() {
        let fixtures = Self.selectedFixtures(env: [
            "NOUM_LIVE_AI_FIXTURES": "latest-transcript"
        ])

        #expect(fixtures.map(\.id) == CoachChatEvaluationCorpus.latestManualEvalFixtureIDs)
    }

    @Test func runtimeProviderSelectorCanExerciseProductionChain() {
        let allKeyed: (CoachChatProvider) -> String? = { _ in "test-key" }

        #expect(Self.liveProviderChain(
            env: ["NOUM_LIVE_AI_PROVIDER_CHAIN": "production"],
            keyLookup: allKeyed
        ) == CoachChatProvider.allCases)
        #expect(Self.liveProviderChain(
            env: ["NOUM_LIVE_AI_PROVIDER_CHAIN": "claude"],
            keyLookup: allKeyed
        ) == [.anthropic])
        #expect(Self.liveProviderChain(
            env: ["NOUM_LIVE_AI_PROVIDER_CHAIN": "gemini"],
            keyLookup: allKeyed
        ) == [.agentPlatform, .gemini])
    }

    @Test func liveGeminiRepliesClearFixtureRubric() async {
        guard Self.liveEvalEnabled else {
            return
        }

        let fixtures = Self.selectedFixtures()
        #expect(!fixtures.isEmpty)

        let diagnostics = CoachLiveDiagnosticRecorder()
        let service = Self.liveService(diagnostics: diagnostics)
        var diagnosticCursor = 0

        var report: [String] = []
        var failed = false
        func emit(_ line: String = "") {
            report.append(line)
            print(line)
        }
        let outputPath = ProcessInfo.processInfo.environment["NOUM_LIVE_AI_EVAL_OUTPUT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedOutputPath = (outputPath?.isEmpty == false)
            ? outputPath!
            : Self.defaultReportPath()

        emit("# Noum Chat With Noum Live Transcripts")
        emit("")
        emit("Purpose: live transcript capture through the Ask Noum chat service, context builder, retrieved coaching expertise, quote guard, professional-coach gate, and typed judgement pass.")
        emit("Secrets: API keys and request bodies are not written to this report.")
        emit("reportPath: \(resolvedOutputPath)")
        emit("fixtures: \(fixtures.map { $0.id }.joined(separator: ","))")
        emit("providerChain: \(Self.liveProviderChain().map { "\($0.displayName) (\($0.model))" }.joined(separator: " -> "))")

        for fixture in fixtures {
            let expertise = await KnowledgeRetriever.retrieveReranked(
                query: fixture.latestUserTurn,
                lever: fixture.trends.first?.skillArea,
                voice: fixture.profile?.speakingStyleGoal,
                hasDiagnosis: !fixture.sessions.isEmpty
            )
            var context = Self.liveContext(for: fixture, coachingExpertise: expertise)
            let system = CoachContextBuilder.systemPrompt(for: fixture.profile)
            let history = Self.history(for: fixture)
            let judgement = Self.judgement(for: fixture, history: history, surface: .text)
            context += "\n" + CoachPromptBundle.contextBlock(
                assessment: judgement.assessment,
                rubric: judgement.rubric,
                surface: .text
            )
            let recentTimed = fixture.sessions
                .filter { $0.mode == .timed }
                .max(by: { $0.date < $1.date })
            let grounding = ChatGroundingContext(
                recentTimedTranscript: recentTimed?.transcript,
                verifiedProofQuotes: []
            )

            let outcome = await service.reply(
                history: history,
                systemPrompt: system,
                userContext: context,
                grounding: grounding,
                turnDepth: judgement.turnDepth,
                assessment: judgement.assessment,
                surface: .text,
                preferredTier: CoachPromptBundle.preferredProviderTier(
                    for: judgement.turnDepth,
                    surface: .text
                )
            )
            let records = diagnostics.records
            let newRecords = Array(records.dropFirst(diagnosticCursor))
            diagnosticCursor = records.count

            emit("")
            emit("## \(fixture.id)")
            emit("")
            emit("userTurn: \(fixture.latestUserTurn)")
            emit("turnDepth: \(judgement.turnDepth.rawValue)")
            emit("providerTier: \(CoachPromptBundle.preferredProviderTier(for: judgement.turnDepth, surface: .text).rawValue)")
            emit("trajectoryCacheHit: \(judgement.trajectory.cacheHit)")
            emit("assessmentConfidence: \(String(format: "%.2f", judgement.assessment.confidence))")
            emit("assessmentVerdict: \(judgement.assessment.directVerdict)")
            emit("assessmentImmediateRead: \(judgement.assessment.immediateCoachRead)")
            if !judgement.assessment.missingEvidence.isEmpty {
                emit("missingEvidence: \(judgement.assessment.missingEvidence.joined(separator: " | "))")
            }
            emit("proofTest: \(judgement.assessment.nextProofTest)")
            emit("brain: \(expertise.map { $0.id }.joined(separator: ", "))")
            emit("diagnostics:")
            for record in newRecords {
                emit("- \(record.provider) \(record.model ?? "unknown-model") \(record.outcome.rawValue): \(record.reason) status=\(record.statusCode.map(String.init) ?? "nil") latencyMs=\(record.latencyMs.map(String.init) ?? "nil")")
            }

            switch outcome {
            case .reply(let raw):
                let reply = CoachReplyTextSanitizer.coachReplyText(from: raw)
                let rubric = AICoachChatService.professionalCoachRubric(
                    reply: reply,
                    latestUserTurn: fixture.latestUserTurn
                )
                let issue = AICoachChatService.replyQualityIssue(
                    in: reply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatQuoteGuardContext(
                        transcripts: [grounding.recentTimedTranscript],
                        latestUserTurn: fixture.latestUserTurn,
                        recentUserTurns: history.filter { $0.role == .user }.map { $0.text }
                    ),
                    systemContext: context,
                    turnDepth: judgement.turnDepth,
                    surface: .text
                )
                let semanticIssue = AICoachChatService.semanticQualityIssue(
                    in: reply,
                    turnDepth: judgement.turnDepth,
                    assessment: judgement.assessment
                )

                emit("")
                emit("transcript:")
                emit("")
                emit("User: \(fixture.latestUserTurn)")
                emit("")
                emit("Noum: \(reply)")
                emit("")
                emit("rawReply:")
                emit("")
                emit(reply)
                emit("")
                emit("rubric: score=\(rubric.score) misses=\(rubric.misses.map { $0.rawValue }.joined(separator: ","))")
                emit("qualityIssue: \(String(describing: issue))")
                emit("semanticIssue: \(String(describing: semanticIssue))")

                if issue != nil || semanticIssue != nil || !rubric.passesSeniorCoachFloor {
                    failed = true
                }
                #expect(issue == nil)
                #expect(semanticIssue == nil)
                #expect(rubric.passesSeniorCoachFloor)

            case .failure(let failure):
                emit("failure: \(failure)")
                failed = true
                #expect(Bool(false), "\(fixture.id) failed with \(failure)")
            }
        }

        let reportText = report.reduce(into: "") { output, line in
            if !output.isEmpty {
                output.append("\n")
            }
            output.append(line)
        }

        do {
            try reportText
                .write(toFile: resolvedOutputPath, atomically: true, encoding: .utf8)
            print("NOUM_LIVE_AI_EVAL_OUTPUT=\(resolvedOutputPath)")
        } catch {
            print("failed to write live eval report: \(error)")
            #expect(Bool(false))
        }
        if failed {
            #expect(!failed, "Live coach eval failed; report written to \(resolvedOutputPath)\n\(reportText)")
        }
    }

    private static var liveEvalEnabled: Bool {
        #if NOUM_LIVE_AI_EVAL
        return true
        #else
        return ProcessInfo.processInfo.environment["NOUM_LIVE_AI_EVAL"] == "1"
        #endif
    }

    private static func selectedFixtures(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> [CoachChatEvaluationFixture] {
        let all = CoachChatEvaluationCorpus.fixtures
        let raw = env["NOUM_LIVE_AI_FIXTURES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let raw, !raw.isEmpty else {
            #if NOUM_LIVE_AI_EVAL_FULL_CORPUS
            return all
            #else
            // Keep the default run cheap but representative: cold start,
            // pressure prescription, and trust repair.
            #if NOUM_LIVE_AI_EVAL_LATEST_TRANSCRIPT
            let defaults = CoachChatEvaluationCorpus.latestManualEvalFixtureIDs
            #elseif NOUM_LIVE_AI_EVAL_SINGLE
            let defaults = [
                "filler-pressure-prescription"
            ]
            #elseif NOUM_LIVE_AI_EVAL_TRUST_REPAIR
            let defaults = [
                "markdown-tts-trust-repair"
            ]
            #elseif NOUM_LIVE_AI_EVAL_COLD_START
            let defaults = [
                "cold-start-interview-baseline"
            ]
            #elseif NOUM_LIVE_AI_EVAL_OVERCLAIM
            let defaults = [
                "overclaim-hypothesis-boundary"
            ]
            #else
            let defaults = [
                "cold-start-interview-baseline",
                "filler-pressure-prescription",
                "markdown-tts-trust-repair"
            ]
            #endif
            return defaults.compactMap { id in all.first { $0.id == id } }
            #endif
        }

        let preset = raw.lowercased()
        if ["latest", "latest-transcript", "latest-manual-eval"].contains(preset) {
            return CoachChatEvaluationCorpus.latestManualEvalFixtureIDs
                .compactMap { id in all.first { $0.id == id } }
        }

        let wanted = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return wanted.compactMap { id in all.first { $0.id == id } }
    }

    private struct JudgementContext {
        let turnDepth: CoachTurnDepth
        let trajectory: UserTrajectoryCacheResult
        let rubric: ActiveGoalRubric
        let assessment: CoachAssessment
    }

    private static func judgement(
        for fixture: CoachChatEvaluationFixture,
        history: [CoachMessage],
        surface: CoachReplySurface
    ) -> JudgementContext {
        let turnDepth = CoachBrainFlags.judgementPassEnabled
            ? TurnDepthClassifier.classify(
                userText: fixture.latestUserTurn,
                recentTurns: history,
                liveMode: surface == .live
            )
            : .groundedRead
        let trajectory = UserTrajectoryCache.shared.snapshot(
            profile: fixture.profile,
            baseline: .empty,
            rating: .initial,
            sessions: fixture.sessions,
            coachMemory: nil
        )
        let rubric = GoalRubricStore.activeRubric(for: fixture.profile)
        let assessment = CoachReasoningPass.assess(
            turnDepth: turnDepth,
            userQuestion: fixture.latestUserTurn,
            trajectory: trajectory.snapshot,
            rubric: rubric,
            surface: surface
        )
        return JudgementContext(
            turnDepth: turnDepth,
            trajectory: trajectory,
            rubric: rubric,
            assessment: assessment
        )
    }

    private static func history(for fixture: CoachChatEvaluationFixture) -> [CoachMessage] {
        var messages: [CoachMessage] = []
        if let previous = fixture.previousCoachReply,
           !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(CoachMessage(role: .coach, text: previous))
        }
        messages.append(CoachMessage(role: .user, text: fixture.latestUserTurn))
        return messages
    }

    private static func liveContext(
        for fixture: CoachChatEvaluationFixture,
        coachingExpertise: [CoachKnowledgeCard]
    ) -> String {
        CoachContextBuilder.userContext(
            profile: fixture.profile,
            baseline: .empty,
            rating: .initial,
            sessions: fixture.sessions,
            currentStreak: fixture.sessions.isEmpty ? 0 : 2,
            pathStatus: nil,
            pathGatingPhrase: nil,
            trends: fixture.trends,
            latestUserTurn: fixture.latestUserTurn,
            previousCoachReply: fixture.previousCoachReply,
            recentUserTurns: [fixture.latestUserTurn],
            coachingExpertise: coachingExpertise
        )
    }

    private static func liveService(diagnostics: CoachLiveDiagnosticRecorder) -> AICoachChatService {
        AICoachChatService(
            keyedProviders: {
                Self.liveProviderChain()
            },
            keyLookup: { provider in
                Self.liveKey(for: provider)
            },
            localeSupportsAI: {
                true
            },
            providerHTTP: { provider, endpoint, key, body in
                try await Self.liveHTTP(provider: provider, endpoint: endpoint, key: key, body: body)
            },
            diagnosticRecorder: { surface, providerName, model, outcome, reason, statusCode, startedAt, now in
                diagnostics.record(
                    surface: surface,
                    providerName: providerName,
                    model: model,
                    outcome: outcome,
                    reason: reason,
                    statusCode: statusCode,
                    startedAt: startedAt,
                    now: now
                )
            }
        )
    }

    private static func liveProviderChain(
        env: [String: String] = ProcessInfo.processInfo.environment,
        keyLookup: ((CoachChatProvider) -> String?)? = nil
    ) -> [CoachChatProvider] {
        let lookup = keyLookup ?? { provider in
            Self.liveKey(for: provider)
        }
        let runtimeSelector = env["NOUM_LIVE_AI_PROVIDER_CHAIN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch runtimeSelector {
        case "agent", "agent-platform", "google-cloud", "vertex":
            return [.agentPlatform].filter { lookup($0) != nil }
        case "gemini", "google":
            return [.agentPlatform, .gemini].filter { lookup($0) != nil }
        case "claude", "anthropic":
            return [.anthropic].filter { lookup($0) != nil }
        case "production", "all", "chain":
            return CoachChatProvider.allCases.filter { lookup($0) != nil }
        case nil, "":
            break
        default:
            break
        }

        #if NOUM_LIVE_AI_EVAL_AGENT_PLATFORM_ONLY
        return [.agentPlatform].filter { lookup($0) != nil }
        #elseif NOUM_LIVE_AI_EVAL_GEMINI_ONLY
        return [.gemini].filter { lookup($0) != nil }
        #elseif NOUM_LIVE_AI_EVAL_CLAUDE_ONLY
        return [.anthropic].filter { lookup($0) != nil }
        #elseif NOUM_LIVE_AI_EVAL_PRODUCTION_CHAIN
        return CoachChatProvider.allCases.filter { lookup($0) != nil }
        #else
        // Keep the manual eval focused on the Google Gemini path the product is
        // being tuned around. If Google Cloud is keyed it goes first; direct
        // Gemini remains the fast fallback. Other providers are deliberately
        // excluded so a "green" live eval cannot hide that Gemini is broken.
        return [.agentPlatform, .gemini].filter { lookup($0) != nil }
        #endif
    }

    private static func liveKey(for provider: CoachChatProvider) -> String? {
        for keyName in provider.keyNames {
            if let value = AICoachChatService.usableAPIKey(ProcessInfo.processInfo.environment[keyName]) {
                return value
            }
            if let value = AICoachChatService.usableAPIKey(LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")) {
                return value
            }
        }
        return nil
    }

    private static func liveHTTP(
        provider: CoachChatProvider,
        endpoint: URL,
        key: String,
        body: [String: Any]
    ) async throws -> AICoachChatService.ProviderHTTPResult {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        switch provider {
        case .openAI, .deepSeek:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .agentPlatform, .gemini:
            request.setGoogleAPIKey(key)
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            return .refused(status: -1, retryAfter: nil)
        }
        let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
        guard (200..<300).contains(http.statusCode) else {
            return .refused(status: http.statusCode, retryAfter: retryAfter)
        }
        return .success(data)
    }

    private static func defaultReportPath() -> String {
        if let shared = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.jordancoaten.noum"
        ) {
            return shared.appendingPathComponent("noum-live-coach-eval.md").path
        }
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documents.appendingPathComponent("noum-live-coach-eval.md").path
        }
        return (NSTemporaryDirectory() as NSString).appendingPathComponent("noum-live-coach-eval.md")
    }
}

private struct CoachLiveDiagnosticRecord: Sendable {
    let provider: String
    let model: String?
    let outcome: AICallDiagnosticOutcome
    let reason: String
    let statusCode: Int?
    let latencyMs: Int?
}

private final class CoachLiveDiagnosticRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRecords: [CoachLiveDiagnosticRecord] = []

    var records: [CoachLiveDiagnosticRecord] {
        lock.lock()
        defer { lock.unlock() }
        return storedRecords
    }

    func record(
        surface: String,
        providerName: String?,
        model: String?,
        outcome: AICallDiagnosticOutcome,
        reason: String,
        statusCode: Int?,
        startedAt: Date?,
        now: Date
    ) {
        let latencyMs = startedAt.map { max(0, Int(now.timeIntervalSince($0) * 1_000)) }
        let record = CoachLiveDiagnosticRecord(
            provider: providerName ?? "No provider",
            model: model,
            outcome: outcome,
            reason: reason,
            statusCode: statusCode,
            latencyMs: latencyMs
        )
        lock.lock()
        storedRecords.append(record)
        lock.unlock()
    }
}
