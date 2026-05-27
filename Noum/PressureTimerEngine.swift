import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Difficulty

/// Optional difficulty modifier for pressure-based modes (Sudden Death today).
/// `medium` is the canonical baseline — tuned curve shipped before this enum
/// existed. Easy and Hard are multiplicative tweaks on top, not separate
/// curves, so the engine state machine stays unchanged.
enum SuddenDeathDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var subtitle: String {
        switch self {
        case .easy:   return "Wider start window. More time per round."
        case .medium: return "Standard pressure. The default ramp."
        case .hard:   return "Tight start window. Less time per round."
        }
    }

    /// Multiplier on `startWindow`. Wider = more time before timeout.
    var startWindowFactor: Double {
        switch self {
        case .easy: return 1.4
        case .medium: return 1.0
        case .hard: return 0.7
        }
    }

    /// Multiplier on session XP. Survives a personal best on Hard pays more
    /// than survival on Easy.
    var xpMultiplier: Double {
        switch self {
        case .easy: return 0.85
        case .medium: return 1.0
        case .hard: return 1.3
        }
    }
}

// MARK: - Round Config (auto-ramp by round, scaled by difficulty)

/// Timing and tolerance values for a single round. Pressure ramps automatically.
struct PressureRoundConfig: Equatable {
    /// Seconds the user has to begin speaking after the prompt appears.
    let startWindow: TimeInterval
    /// Soft response cap — auto-ends the turn, not a visible countdown.
    let responseCap: TimeInterval
    /// Number of high-confidence fillers tolerated before failure.
    let fillerTolerance: Int
    /// Minimum word count to avoid "too short" failure.
    let minimumWords: Int
    /// Whether this round uses a follow-up (vs. a fresh prompt).
    let isFollowUp: Bool

    /// Builds config for a given round (1-indexed) at a given difficulty.
    /// Filler tolerance is always 0 in Sudden Death — difficulty only controls
    /// start window width and minimum word count.
    static func config(for round: Int, difficulty: SuddenDeathDifficulty = .medium) -> PressureRoundConfig {
        let base = baseConfig(for: round)
        let scaledWindow = max(2, base.startWindow * difficulty.startWindowFactor)
        return PressureRoundConfig(
            startWindow: scaledWindow,
            responseCap: base.responseCap,
            fillerTolerance: 0,
            minimumWords: base.minimumWords,
            isFollowUp: base.isFollowUp
        )
    }

    private static func baseConfig(for round: Int) -> PressureRoundConfig {
        let r = max(1, round)
        let startWindow: TimeInterval
        let fillerTolerance: Int
        let isFollowUp: Bool

        switch r {
        case 1:
            startWindow = 12
            fillerTolerance = 3
            isFollowUp = false
        case 2:
            startWindow = 10
            fillerTolerance = 2
            isFollowUp = true
        case 3:
            startWindow = 8
            fillerTolerance = 2
            isFollowUp = true
        case 4:
            startWindow = 6
            fillerTolerance = 1
            isFollowUp = false  // Topic reset — tests recovery
        case 5:
            startWindow = 5
            fillerTolerance = 1
            isFollowUp = true
        default:
            // Round 6+: brutal
            startWindow = max(3, 5 - Double(r - 5) * 0.5)
            fillerTolerance = 0
            isFollowUp = true
        }

        return PressureRoundConfig(
            startWindow: startWindow,
            responseCap: 30,
            fillerTolerance: fillerTolerance,
            minimumWords: 10,
            isFollowUp: isFollowUp
        )
    }
}

// MARK: - Turn Phase State Machine

/// State machine for timed-response pressure. Reusable across modes.
enum PressureTurnPhase: Equatable {
    /// Pre-session: just a begin button.
    case setup

    /// Countdown before the session begins (3, 2, 1, GO).
    case countdown(Int)
    case go

    /// NPC turn: generating or displaying the follow-up/prompt.
    case npcTurn(round: Int)

    /// User's turn — waiting for them to start speaking. Start timer counting down.
    case userTurnWaiting(round: Int, remaining: TimeInterval)

    /// User is actively speaking. Filler monitored, soft response cap running.
    case userTurnActive(round: Int)

    /// Brief inter-round result before the next prompt or session end.
    case roundResult(round: Int, outcome: RoundOutcome)

    /// Full session complete.
    case sessionComplete(result: PressureSessionResult)
}

// MARK: - Round Outcome

/// The outcome of a single round.
enum RoundOutcome: Equatable {
    case survived
    case timeoutBeforeStart
    case fillerOverload
    case tooShort
}

extension RoundOutcome {
    var label: String {
        switch self {
        case .survived: return "Survived"
        case .timeoutBeforeStart: return "Too Slow"
        case .fillerOverload: return "Filler — instant elimination"
        case .tooShort: return "Too Short"
        }
    }

    var icon: String {
        switch self {
        case .survived: return "checkmark.circle.fill"
        case .timeoutBeforeStart: return "clock.badge.exclamationmark"
        case .fillerOverload: return "waveform.badge.exclamationmark"
        case .tooShort: return "text.badge.minus"
        }
    }

    var isFailed: Bool {
        switch self {
        case .survived: return false
        default: return true
        }
    }
}

// MARK: - Session Result

/// Accumulates completed-round measurements through one write path.
/// Sudden Death can terminate during live monitoring, before normal
/// evaluation runs, so result accounting must not depend on how a round ended.
struct PressureSessionTotals: Equatable {
    private(set) var duration: TimeInterval = 0
    private(set) var fillers: Int = 0
    private(set) var words: Int = 0
    private(set) var bestRoundWords: Int = 0

    mutating func recordRound(duration: TimeInterval, fillers: Int, words: Int) {
        self.duration += max(0, duration)
        self.fillers += max(0, fillers)
        self.words += max(0, words)
        bestRoundWords = max(bestRoundWords, max(0, words))
    }
}

/// Preserves the spoken evidence from each completed tier so a multi-tier
/// Sudden Death run is coached as one session rather than only its final turn.
struct PressureSessionTranscriptLog: Equatable {
    private(set) var responses: [String] = []

    mutating func record(_ response: String) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        responses.append(trimmed)
    }

    var combinedText: String {
        responses.joined(separator: "\n\n")
    }
}

/// Full session result with behavior-mapped labels.
struct PressureSessionResult: Equatable {
    let roundsSurvived: Int
    let finalOutcome: RoundOutcome
    let roundOutcomes: [RoundOutcome]
    let totalDuration: TimeInterval
    let totalFillers: Int
    let totalWords: Int
    let bestRoundWords: Int
    let personalBest: Int  // previous best rounds survived
    var difficulty: SuddenDeathDifficulty = .medium

    /// Word count recorded for each round in `roundOutcomes` (same order /
    /// same length). Populated only for rounds where the user actually
    /// got past the start window; rounds that timed out before speaking
    /// record 0. Used by the result screen to surface the exact word
    /// count behind a "Too short" failure instead of leaving the user
    /// guessing what the threshold was.
    var wordCountsByRound: [Int] = []

    /// Per-round `minimumWords` threshold (matches `roundOutcomes` index).
    /// Lets the round list show "5 words / needed 10" without needing the
    /// view to reconstruct round configs.
    var minimumWordsByRound: [Int] = []

    /// Behavior-mapped result label.
    var resultLabel: String {
        if roundsSurvived >= 6 && totalFillers == 0 {
            return "Fast and Clear"
        }
        if roundsSurvived >= 4 {
            if totalFillers == 0 { return "Fast and Clear" }
            return "Beat the Clock"
        }

        switch finalOutcome {
        case .survived:
            return "Beat the Clock"
        case .timeoutBeforeStart:
            if roundsSurvived >= 2 { return "Held Under Pressure" }
            return "Time Broke You"
        case .fillerOverload:
            if roundsSurvived >= 2 { return "Strong Recovery" }
            return "Filler Spike"
        case .tooShort:
            return "Rushed Start"
        }
    }

    var resultIcon: String {
        switch resultLabel {
        case "Fast and Clear": return "bolt.circle.fill"
        case "Beat the Clock": return "checkmark.seal.fill"
        case "Held Under Pressure": return "shield.fill"
        case "Strong Recovery": return "arrow.up.heart.fill"
        case "Filler Spike": return "waveform.badge.exclamationmark"
        case "Rushed Start": return "hare.fill"
        case "Time Broke You": return "clock.badge.exclamationmark"
        default: return "questionmark.circle"
        }
    }

    var resultTint: Color {
        switch resultLabel {
        case "Fast and Clear": return .green
        case "Beat the Clock": return .blue
        case "Held Under Pressure": return .orange
        case "Strong Recovery": return .teal
        case "Filler Spike": return .red
        case "Rushed Start": return Color(red: 0.80, green: 0.50, blue: 0.10)
        case "Time Broke You": return .red
        default: return .secondary
        }
    }

    /// Score 1–10 based on behavioral signals.
    var score: Int {
        guard roundsSurvived > 0 else { return 1 }
        // Base: 2 + rounds survived (capped contribution)
        let roundScore = min(Double(roundsSurvived) * 0.8, 5.0)
        let fillerPenalty = min(Double(totalFillers) * 1.2, 4.0)
        let cleanBonus: Double = totalFillers == 0 ? 2.0 : 0
        let depthBonus = roundsSurvived >= 5 ? 1.0 : 0
        let raw = 2.0 + roundScore + cleanBonus + depthBonus - fillerPenalty
        return max(1, min(10, Int(round(raw))))
    }

    /// XP earned from the session, scaled by difficulty.
    var xpEarned: Int {
        let base = Double(score) * 10.0
        let survivalBonus = Double(roundsSurvived) * 18.0
        let depthMultiplier = roundsSurvived >= 4 ? 1.3 : 1.0
        let adjusted = (base + survivalBonus) * depthMultiplier * difficulty.xpMultiplier
        return max(10, Int(round(adjusted)))
    }

    /// Whether this is a new personal best.
    var isNewPersonalBest: Bool {
        roundsSurvived > personalBest && personalBest > 0
    }

    // MARK: - Game Points (result-screen scoring)

    /// Transparent, multiplier-based points for the result screen.
    /// Every component maps to a real communication signal:
    /// - Base: 100 pts per tier cleared (survival under pressure)
    /// - Content bonus: +50 per round with 20+ words (developed responses)
    /// - Follow-up bonus: +25 per follow-up round survived (conversational agility)
    /// - Multipliers stack on top for clean speech and depth.
    var gamePoints: Int {
        let base = roundsSurvived * 100

        var bonuses = 0
        for (index, outcome) in roundOutcomes.enumerated() where outcome == .survived {
            if index < wordCountsByRound.count, wordCountsByRound[index] >= 20 {
                bonuses += 50
            }
            let config = PressureRoundConfig.config(for: index + 1, difficulty: difficulty)
            if config.isFollowUp {
                bonuses += 25
            }
        }

        var multiplier = 1.0
        for m in computedMultipliers {
            multiplier *= m.value
        }

        return max(0, Int(round(Double(base + bonuses) * multiplier)))
    }

    /// Which multipliers are active for this run. Each is backed by a
    /// real signal — no decorative numbers.
    var computedMultipliers: [(label: String, value: Double)] {
        var result: [(String, Double)] = []

        if totalFillers == 0 && roundsSurvived >= 1 {
            result.append(("Clean", 1.5))
        }

        if roundsSurvived >= 8 {
            result.append(("Marathon", 1.6))
        } else if roundsSurvived >= 5 {
            result.append(("Deep", 1.3))
        }

        let developedRounds = wordCountsByRound.filter { $0 >= 20 }.count
        if developedRounds >= 3 {
            result.append(("Developed", 1.2))
        }

        return result
    }

    /// Display-ready multiplier labels (e.g. ["×1.5 Clean", "×1.3 Deep"]).
    var multiplierLabels: [String] {
        computedMultipliers.map { "×\(String(format: "%.1f", $0.value)) \($0.label)" }
    }
}

// MARK: - Follow-Up Provider Protocol (reusable)

/// Protocol for providing NPC follow-up messages. Implemented by Gemini service
/// or a fallback template system.
@MainActor
protocol PressureFollowUpProviding {
    func generateFollowUp(
        userTranscript: String,
        previousPrompt: String,
        round: Int,
        profile: CoachingProfile?
    ) async -> String
}

// MARK: - Pressure Timer Engine (Observable)

/// The core engine that drives timed-response pressure. Observable for SwiftUI binding.
///
/// Design principles:
/// - Single visible countdown: time to begin speaking (the core pressure mechanic)
/// - Response cap is soft/invisible — just prevents infinite rambling
/// - No difficulty selector. Pressure auto-ramps by round.
/// - Infinite survival — session ends on first failure. Personal best = highest round.
/// - Follow-ups after round 1 create conversational pressure (NPC responds to what you said)
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class PressureTimerEngine: ObservableObject {
    @Published private(set) var phase: PressureTurnPhase = .setup
    @Published private(set) var currentRound: Int = 0
    @Published private(set) var roundOutcomes: [RoundOutcome] = []

    /// Current prompt or follow-up text being shown/responded to.
    @Published private(set) var currentPromptText: String = ""

    /// Countdown fraction (0.0 = full, 1.0 = expired) for the start timer bar.
    @Published private(set) var timerFraction: Double = 0.0

    /// Remaining seconds for the start timer.
    @Published private(set) var displayRemaining: TimeInterval = 0

    /// Whether the user has started speaking in the current round.
    @Published var userHasStartedSpeaking: Bool = false

    /// Current filler count for the active round (set externally by the view).
    @Published var currentFillerCount: Int = 0

    /// Current word count for the active round (set externally by the view).
    @Published var currentWordCount: Int = 0

    /// Whether the NPC is currently generating a follow-up.
    @Published private(set) var isGeneratingFollowUp: Bool = false

    /// Set by `advanceToNextRound` when the round is ready to begin the user
    /// waiting phase but the view should first finish any in-flight TTS readout.
    /// The view observes this and calls `confirmBeginUserWaiting()` once TTS
    /// has finished, which clears this and starts the actual start timer.
    @Published private(set) var pendingUserWaitingRound: Int? = nil

    /// The transcript from the most recent user turn (for follow-up generation).
    @Published var lastUserTranscript: String = ""

    var followUpProvider: PressureFollowUpProviding?
    private var openingPrompt: String = ""
    private var sessionStartDate: Date?
    private var roundStartDate: Date?
    private var timerTask: Task<Void, Never>?
    private var responseLimitTask: Task<Void, Never>?
    private(set) var roundConfig: PressureRoundConfig = .config(for: 1)
    private(set) var previousBestRounds: Int = 0
    /// Difficulty for the current session. Set in `configure()`.
    private(set) var difficulty: SuddenDeathDifficulty = .medium

    // Accumulated stats. Written only when a round ends so direct
    // filler elimination and ordinary evaluation cannot drift.
    private var totals = PressureSessionTotals()
    private var transcriptLog = PressureSessionTranscriptLog()

    /// Complete spoken evidence for the finished run, in tier order.
    var sessionTranscript: String { transcriptLog.combinedText }

    // Per-round word counts + thresholds so the result screen can show
    // the user the actual words they spoke vs. the bar they missed,
    // instead of leaving "Too Short" as an unexplained verdict.
    private var roundWordCounts: [Int] = []
    private var roundMinimumWords: [Int] = []

    // MARK: - Session Control

    /// Configure with an opening prompt and optional follow-up provider.
    func configure(
        openingPrompt: String,
        followUpProvider: PressureFollowUpProviding?,
        previousBest: Int = 0,
        difficulty: SuddenDeathDifficulty = .medium
    ) {
        self.openingPrompt = openingPrompt
        self.followUpProvider = followUpProvider
        self.previousBestRounds = previousBest
        self.difficulty = difficulty
        reset()
    }

    func reset() {
        timerTask?.cancel()
        responseLimitTask?.cancel()
        phase = .setup
        currentRound = 0
        roundOutcomes = []
        currentPromptText = ""
        timerFraction = 0
        displayRemaining = 0
        userHasStartedSpeaking = false
        currentFillerCount = 0
        currentWordCount = 0
        isGeneratingFollowUp = false
        lastUserTranscript = ""
        sessionStartDate = nil
        roundStartDate = nil
        totals = PressureSessionTotals()
        transcriptLog = PressureSessionTranscriptLog()
        roundWordCounts = []
        roundMinimumWords = []
        pendingUserWaitingRound = nil
        print("[PressureEngine] Reset complete")
    }

    #if DEBUG
    /// Moves the existing engine into a completed state for deterministic
    /// screenshot/UI-test fixtures without replaying timers or microphone input.
    func presentResultForUITesting(_ result: PressureSessionResult) {
        reset()
        phase = .sessionComplete(result: result)
    }
    #endif

    /// Begin the countdown sequence.
    func beginCountdown() {
        sessionStartDate = Date()
        Task {
            for count in [3, 2, 1] {
                phase = .countdown(count)
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }
            phase = .go
            CoachHaptic.drillSuccess()
            try? await Task.sleep(for: .milliseconds(600))
            advanceToNextRound()
        }
    }

    /// Called when speech is first detected during userTurnWaiting.
    func userStartedSpeaking() {
        guard case .userTurnWaiting(let round, _) = phase else { return }
        userHasStartedSpeaking = true
        print("[PressureEngine] User started speaking in round \(round)")
        beginActiveResponse(round: round)
    }

    /// Called when the user manually ends their turn.
    func userEndedTurn() {
        guard case .userTurnActive(let round) = phase else { return }
        timerTask?.cancel()
        responseLimitTask?.cancel()
        evaluateRound(round: round)
    }

    /// Force-stop the session (user quit).
    func forceStop() {
        timerTask?.cancel()
        responseLimitTask?.cancel()
        let survived = roundOutcomes.filter { !$0.isFailed }.count
        let result = buildSessionResult(finalOutcome: roundOutcomes.last ?? .timeoutBeforeStart, roundsSurvived: survived)
        phase = .sessionComplete(result: result)
        print("[PressureEngine] Force stopped")
    }

    // MARK: - NPC Turn (Prompt / Follow-Up)

    private func advanceToNextRound() {
        let nextRound = currentRound + 1
        currentRound = nextRound
        currentFillerCount = 0
        currentWordCount = 0
        userHasStartedSpeaking = false
        roundConfig = PressureRoundConfig.config(for: nextRound, difficulty: difficulty)

        print("[PressureEngine] Entering NPC turn for round \(nextRound), isFollowUp: \(roundConfig.isFollowUp)")
        phase = .npcTurn(round: nextRound)

        if nextRound == 1 || !roundConfig.isFollowUp {
            // Fresh prompt
            if nextRound == 1 {
                currentPromptText = openingPrompt
            } else {
                // Round 4+ topic reset: pick a new random prompt
                currentPromptText = PracticeTopics.random()
            }
            // Signal the view that this round is ready to begin the user waiting
            // phase. The view will call confirmBeginUserWaiting() once TTS has
            // finished reading the prompt so the card stays expanded mid-readout.
            Task {
                let displayTime: TimeInterval = nextRound == 1 ? 2.5 : 2.0
                try? await Task.sleep(for: .seconds(displayTime))
                pendingUserWaitingRound = nextRound
            }
        } else {
            // Follow-up: call Gemini or fallback
            generateFollowUp(round: nextRound)
        }
    }

    /// Called by the view once TTS has finished for the current NPC turn.
    /// Clears `pendingUserWaitingRound` and starts the actual start-window timer.
    func confirmBeginUserWaiting() {
        guard let round = pendingUserWaitingRound else { return }
        pendingUserWaitingRound = nil
        beginUserWaiting(round: round)
    }

    private func generateFollowUp(round: Int) {
        isGeneratingFollowUp = true
        let transcript = lastUserTranscript
        let previousPrompt = currentPromptText

        Task {
            let followUp: String
            if let provider = followUpProvider, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                followUp = await provider.generateFollowUp(
                    userTranscript: transcript,
                    previousPrompt: previousPrompt,
                    round: round,
                    profile: nil
                )
            } else {
                // Fallback templates
                followUp = PressureFollowUpTemplates.random()
            }

            await MainActor.run {
                currentPromptText = followUp
                isGeneratingFollowUp = false
                print("[PressureEngine] Follow-up generated for round \(round): \(followUp.prefix(50))...")
            }

            // Brief display, then signal the view to start the user waiting
            // phase once TTS finishes the follow-up readout.
            try? await Task.sleep(for: .seconds(1.8))
            pendingUserWaitingRound = round
        }
    }

    // MARK: - User Turn Waiting (Start Timer — the core pressure mechanic)

    private func beginUserWaiting(round: Int) {
        roundStartDate = Date()
        // The previous response has already been consumed by follow-up
        // generation. Clear it so a start-timeout never duplicates it.
        lastUserTranscript = ""
        let startWindow = roundConfig.startWindow
        displayRemaining = startWindow
        timerFraction = 0
        phase = .userTurnWaiting(round: round, remaining: startWindow)
        print("[PressureEngine] User turn waiting — \(startWindow)s to start, round \(round)")

        timerTask?.cancel()
        timerTask = Task {
            let start = Date()
            let tickInterval: TimeInterval = 0.05
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickInterval))
                guard !Task.isCancelled else { return }

                let elapsed = Date().timeIntervalSince(start)
                let remaining = max(0, startWindow - elapsed)
                let fraction = min(1.0, elapsed / startWindow)

                displayRemaining = remaining
                timerFraction = fraction
                phase = .userTurnWaiting(round: round, remaining: remaining)

                if remaining <= 0 {
                    handleStartTimeout(round: round)
                    return
                }

                // Check if user started speaking via external flag
                if userHasStartedSpeaking {
                    return // userStartedSpeaking() already called
                }
            }
        }
    }

    // MARK: - User Turn Active (filler monitoring, soft response cap)

    private func beginActiveResponse(round: Int) {
        timerTask?.cancel()
        // Timer bar disappears — pressure shifts from "start fast" to "stay clean"
        timerFraction = 0
        displayRemaining = 0
        phase = .userTurnActive(round: round)
        print("[PressureEngine] User turn active, round \(round)")

        // Soft response cap — invisible, just prevents infinite rambling
        responseLimitTask?.cancel()
        responseLimitTask = Task {
            try? await Task.sleep(for: .seconds(roundConfig.responseCap))
            guard !Task.isCancelled else { return }
            print("[PressureEngine] Response cap reached, auto-ending round \(round)")
            evaluateRound(round: round)
        }

        // Filler monitoring tick
        timerTask = Task {
            let tickInterval: TimeInterval = 0.1
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickInterval))
                guard !Task.isCancelled else { return }

                if currentFillerCount > roundConfig.fillerTolerance {
                    timerTask?.cancel()
                    responseLimitTask?.cancel()
                    endRound(round: round, outcome: .fillerOverload)
                    return
                }
            }
        }
    }

    // MARK: - Round Evaluation

    private func handleStartTimeout(round: Int) {
        print("[PressureEngine] Start timeout in round \(round)")
        CoachHaptic.gameOver()
        endRound(round: round, outcome: .timeoutBeforeStart)
    }

    private func evaluateRound(round: Int) {
        timerTask?.cancel()
        responseLimitTask?.cancel()

        if currentWordCount < roundConfig.minimumWords {
            endRound(round: round, outcome: .tooShort)
        } else if currentFillerCount > roundConfig.fillerTolerance {
            endRound(round: round, outcome: .fillerOverload)
        } else {
            endRound(round: round, outcome: .survived)
        }
    }

    private func endRound(round: Int, outcome: RoundOutcome) {
        timerTask?.cancel()
        responseLimitTask?.cancel()
        roundOutcomes.append(outcome)
        transcriptLog.record(lastUserTranscript)

        // Record this round's word count + threshold for the result-screen
        // breakdown. `currentWordCount` is 0 for start-timeout rounds
        // (user never spoke), and reflects spoken-so-far for fillerOverload
        // / tooShort.
        roundWordCounts.append(currentWordCount)
        roundMinimumWords.append(roundConfig.minimumWords)

        totals.recordRound(
            duration: Date().timeIntervalSince(roundStartDate ?? Date()),
            fillers: currentFillerCount,
            words: currentWordCount
        )

        print("[PressureEngine] Round \(round) ended: \(outcome.label)")
        phase = .roundResult(round: round, outcome: outcome)

        if outcome.isFailed {
            // Session over on failure — Sudden Death
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                CoachHaptic.gameOver()
                try? await Task.sleep(for: .seconds(1.5))
                completeSession()
            }
        } else {
            CoachHaptic.roundSurvived()
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                advanceToNextRound()
            }
        }
    }

    // MARK: - Session Complete

    private func completeSession() {
        let survived = roundOutcomes.filter { !$0.isFailed }.count
        let finalOutcome = roundOutcomes.last ?? .survived
        let result = buildSessionResult(finalOutcome: finalOutcome, roundsSurvived: survived)
        phase = .sessionComplete(result: result)
        print("[PressureEngine] Session complete — survived \(survived) rounds, label: \(result.resultLabel)")
    }

    private func buildSessionResult(finalOutcome: RoundOutcome, roundsSurvived: Int) -> PressureSessionResult {
        PressureSessionResult(
            roundsSurvived: roundsSurvived,
            finalOutcome: finalOutcome,
            roundOutcomes: roundOutcomes,
            totalDuration: totals.duration,
            totalFillers: totals.fillers,
            totalWords: totals.words,
            bestRoundWords: totals.bestRoundWords,
            personalBest: previousBestRounds,
            difficulty: difficulty,
            wordCountsByRound: roundWordCounts,
            minimumWordsByRound: roundMinimumWords
        )
    }

    // MARK: - Helpers

    var isUserTurn: Bool {
        switch phase {
        case .userTurnWaiting, .userTurnActive: return true
        default: return false
        }
    }

    var isNpcTurn: Bool {
        if case .npcTurn = phase { return true }
        return false
    }

    /// Whether the start timer is currently visible (only during userTurnWaiting).
    var isStartTimerActive: Bool {
        if case .userTurnWaiting = phase { return true }
        return false
    }
}

// MARK: - Follow-Up Templates (fallback when Gemini unavailable)

enum PressureFollowUpTemplates {
    private static let templates = [
        "What do you mean by that?",
        "Can you give me a specific example?",
        "Why does that matter?",
        "How would you explain that to someone who disagrees?",
        "And what happened after that?",
        "What would you do differently next time?",
        "Break that down for me.",
        "Interesting — but why should I care?",
        "What's the most important part of what you just said?",
        "Walk me through your thinking.",
        "So what's the actual takeaway?",
        "How does that apply in practice?",
        "Say more about that.",
        "What are you leaving out?",
        "What would someone who disagrees say?",
        "Give me the short version.",
    ]

    static func random() -> String {
        templates.randomElement() ?? "What do you mean by that?"
    }
}
