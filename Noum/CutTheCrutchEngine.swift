import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Cut the Crutch — Configuration

/// Per-round configuration for the Cut the Crutch drill.
/// Fixed for v1 — pressure does not auto-ramp; the avoided word is the variable.
struct CutTheCrutchConfig: Equatable {
    /// Total seconds the user has to survive on the prompt.
    let survivalDuration: TimeInterval
    /// Number of allowed slips the user starts with.
    let initialHearts: Int
    /// Composure setback applied on each violation (0.0–1.0).
    let composurePenalty: Double

    static let standard = CutTheCrutchConfig(
        survivalDuration: 60,
        initialHearts: 3,
        composurePenalty: 0.15
    )
}

// MARK: - Phases

/// State machine for a Cut the Crutch round.
enum CutTheCrutchPhase: Equatable {
    /// Word selected, prompt staged, waiting on Begin.
    case setup
    /// 3 / 2 / 1 / GO before recording starts.
    case countdown(Int)
    case go
    /// Countdown finished; response clock remains stopped until capture is live.
    case connecting
    /// Live: transcript flowing, allowed slips and composure mutating.
    case active
    /// Round complete with a result.
    case ended(CutTheCrutchResult)
}

// MARK: - Violation

/// One detected use of the avoided word during a round.
struct CutTheCrutchViolation: Identifiable, Equatable {
    let id = UUID()
    /// Seconds since round start when the word was detected.
    let timeFromStart: TimeInterval
    /// Short surrounding fragment of the transcript at the moment of detection.
    let fragment: String
}

// MARK: - Result

/// Final outcome of a Cut the Crutch round.
struct CutTheCrutchResult: Equatable {
    let avoidedWord: String
    let heartsRemaining: Int
    let composure: Double
    let survivedDuration: TimeInterval
    let violations: [CutTheCrutchViolation]
    let cleanCut: Bool

    var verdictLabel: String {
        if cleanCut && violations.isEmpty { return "Clean cut" }
        if cleanCut { return "Held the line" }
        return "Run ended"
    }

    var verdictIcon: String {
        cleanCut ? "scissors" : "xmark.circle.fill"
    }

    /// Score 1–10 for parity with other modes.
    var score: Int {
        if cleanCut && violations.isEmpty { return 10 }
        if cleanCut { return 8 - min(violations.count, 4) }
        let survivedFraction = max(0, min(1, survivedDuration / 60.0))
        let raw = 1.0 + survivedFraction * 5.0
        return max(1, min(7, Int(raw.rounded())))
    }

    /// XP earned. Clean cut is the headline reward; partial runs still earn XP for time survived.
    var xpEarned: Int {
        let base = 30
        let survivalXP = Int((survivedDuration / 60.0) * 40.0)
        let cleanBonus = cleanCut ? 50 : 0
        let slipBonus = heartsRemaining * 10
        return max(10, base + survivalXP + cleanBonus + slipBonus)
    }
}

// MARK: - Engine

/// Drives a single Cut the Crutch round. Observable for SwiftUI binding.
///
/// Design principles:
/// - **Slip allowance** + **gain-framed composure bar** running side by side. Both update
///   live and the user can see push/pull at any moment.
/// - **Composure fills passively** as you survive. Each violation spends one slip and a
///   chunk of composure. There is no "fill the bar by waiting" — survival without violation
///   is the work.
/// - **No auto-ramp.** Round shape is fixed (60s, 3 slips) so the drill is comparable across
///   sessions and the variable is which word you're avoiding.
/// - **Word detection runs on transcript deltas** — we hold a `lastSeenCount` and only flag
///   new occurrences, so a single utterance is never double-counted.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class CutTheCrutchEngine: ObservableObject {

    // MARK: Published State

    @Published private(set) var phase: CutTheCrutchPhase = .setup
    @Published private(set) var heartsRemaining: Int
    /// 0.0 — 1.0. Passive fill from elapsed time, decremented per violation.
    @Published private(set) var composure: Double = 0.0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var violations: [CutTheCrutchViolation] = []
    @Published var avoidedWord: String
    @Published var prompt: String

    // MARK: Internals

    let config: CutTheCrutchConfig
    private var lastSeenCount: Int = 0
    private var roundStart: Date?
    private var countdownTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private(set) var hasCommittedValidCapture = false

    // MARK: Init

    init(
        avoidedWord: String,
        prompt: String,
        config: CutTheCrutchConfig = .standard
    ) {
        self.avoidedWord = avoidedWord
        self.prompt = prompt
        self.config = config
        self.heartsRemaining = config.initialHearts
    }

    // MARK: Lifecycle

    /// Reset to setup phase with a new word and prompt.
    func reset(avoidedWord: String, prompt: String) {
        countdownTask?.cancel()
        countdownTask = nil
        tickTask?.cancel()
        self.avoidedWord = avoidedWord
        self.prompt = prompt
        self.heartsRemaining = config.initialHearts
        self.composure = 0
        self.elapsed = 0
        self.violations = []
        self.lastSeenCount = 0
        self.roundStart = nil
        self.hasCommittedValidCapture = false
        self.phase = .setup
    }

    /// Run the visual countdown, then wait in `.connecting`. The view starts
    /// capture there and calls `confirmCaptureReady` before active time moves.
    func beginCountdown() {
        guard case .setup = phase else { return }
        countdownTask?.cancel()
        countdownTask = Task {
            for n in [3, 2, 1] {
                guard !Task.isCancelled else { return }
                phase = .countdown(n)
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            phase = .go
            CoachHaptic.drillSuccess()
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            phase = .connecting
        }
    }

    /// Opens the scored response window only after provider and microphone
    /// readiness. Countdown time is deliberately not recorded as rep audio.
    func confirmCaptureReady(captureReady: Bool) {
        guard case .connecting = phase,
              RecordingStartGate.allowsTimerStart(captureReady: captureReady) else { return }
        startActive()
    }

    func cancel() {
        countdownTask?.cancel()
        countdownTask = nil
        tickTask?.cancel()
        tickTask = nil
    }

    /// User force-stopped the round — finalize as not-cleanCut with current state.
    func userEnded() {
        guard case .active = phase else { return }
        finalize(cleanCut: false)
    }

    /// Commits progression only after the transcription boundary returns a
    /// usable terminal receipt. The engine may calculate a candidate result
    /// first, but an empty or failed capture never counts as a completed drill.
    @discardableResult
    func confirmCompletedCapture() -> Bool {
        guard case .ended(let result) = phase, !hasCommittedValidCapture else { return false }
        hasCommittedValidCapture = true
        if result.cleanCut {
            CoachHaptic.drillSuccess()
        } else {
            CoachHaptic.gameOver()
        }
        DailyGoalManager.shared.recordDrillCompletion(at: Date())
        return true
    }

    // MARK: Active Loop

    private func startActive() {
        roundStart = Date()
        elapsed = 0
        composure = 0
        phase = .active

        tickTask?.cancel()
        tickTask = Task { [weak self] in
            let interval: TimeInterval = 0.1
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self else { return }
                guard case .active = self.phase else { return }

                let now = Date()
                let start = self.roundStart ?? now
                self.elapsed = now.timeIntervalSince(start)

                // Composure fills from elapsed survival, minus penalty for each
                // violation. Caps at 1.0 even if the user has banked extra time.
                let survivalFill = min(1.0, self.elapsed / self.config.survivalDuration)
                let penalty = Double(self.violations.count) * self.config.composurePenalty
                self.composure = max(0, min(1.0, survivalFill - penalty))

                if self.elapsed >= self.config.survivalDuration {
                    self.finalize(cleanCut: self.heartsRemaining > 0)
                    return
                }
            }
        }
    }

    // MARK: Transcript Bridge

    /// Called by the view whenever the transcript changes. Counts new occurrences
    /// of the avoided word and emits violations + slip allowance changes.
    func ingestTranscript(_ transcript: String) {
        guard case .active = phase else { return }
        let total = Self.countOccurrences(of: avoidedWord, in: transcript)
        guard total > lastSeenCount else { return }
        let newViolations = total - lastSeenCount
        lastSeenCount = total

        let now = Date()
        let start = roundStart ?? now
        let timeFromStart = now.timeIntervalSince(start)

        for _ in 0..<newViolations {
            violations.append(
                CutTheCrutchViolation(
                    timeFromStart: timeFromStart,
                    fragment: Self.fragment(around: avoidedWord, in: transcript)
                )
            )
            heartsRemaining = max(0, heartsRemaining - 1)
            CoachHaptic.fillerAlert()
        }

        if heartsRemaining == 0 {
            finalize(cleanCut: false)
        }
    }

    // MARK: Finalize

    private func finalize(cleanCut: Bool) {
        tickTask?.cancel()
        let now = Date()
        let start = roundStart ?? now
        let survived = now.timeIntervalSince(start)
        let result = CutTheCrutchResult(
            avoidedWord: avoidedWord,
            heartsRemaining: heartsRemaining,
            composure: composure,
            survivedDuration: min(survived, config.survivalDuration),
            violations: violations,
            cleanCut: cleanCut
        )
        phase = .ended(result)
    }

    // MARK: - Word Detection

    /// Word-boundary aware case-insensitive count. Mirrors the regex used by
    /// `ClutchWordStore.countOccurrences` so detection is consistent across the app.
    static func countOccurrences(of word: String, in text: String) -> Int {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !text.isEmpty else { return 0 }
        let escaped = NSRegularExpression.escapedPattern(for: trimmed)
        let pattern = #"(?i)(?<!\w)\#(escaped)(?=\b|[^\w]|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    /// Pulls a small surrounding fragment around the last occurrence of `word`,
    /// for the result-card breakdown. Falls back to the trailing 12 words.
    static func fragment(around word: String, in text: String, contextWords: Int = 5) -> String {
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return "" }
        let lowerWord = word.lowercased()
        if let idx = words.lastIndex(where: { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) == lowerWord }) {
            let lo = max(0, idx - contextWords)
            let hi = min(words.count - 1, idx + contextWords)
            return words[lo...hi].joined(separator: " ")
        }
        return words.suffix(contextWords * 2).joined(separator: " ")
    }
}
