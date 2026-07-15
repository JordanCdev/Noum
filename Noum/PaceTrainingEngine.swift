import Foundation

// MARK: - Sub-Mode

/// The two practice sub-modes in Pace Training.
/// Freestyle (default): User speaks on a topic prompt.
/// Read-Along: Pre-written passage highlighted at target pace.
enum PaceSubMode: String, CaseIterable, Identifiable {
    case freestyle
    case readAlong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .freestyle: return "Freestyle"
        case .readAlong: return "Read Along"
        }
    }
}

// MARK: - Phase

enum PaceTrainingPhase: Equatable {
    case setup
    case countdown(Int)
    case go
    /// Countdown finished; response clock remains stopped until capture is live.
    case connecting
    case active
    case ended(PaceTrainingResult)
}

// MARK: - Conversational Pace Band

enum ConversationalPaceBand {
    static let targetWPM: Double = 130
    static let toleranceWPM: Double = 20

    static var minWPM: Double { targetWPM - toleranceWPM }
    static var maxWPM: Double { targetWPM + toleranceWPM }
    static var minDisplayWPM: Int { Int(minWPM) }
    static var maxDisplayWPM: Int { Int(maxWPM) }
    static var displayRange: String { "\(minDisplayWPM)–\(maxDisplayWPM)" }

    static func contains(_ wpm: Double) -> Bool {
        wpm >= minWPM && wpm <= maxWPM
    }

    static func contains(_ wpm: Int) -> Bool {
        contains(Double(wpm))
    }

    static func distanceFromTarget(_ wpm: Double) -> Double {
        abs(wpm - targetWPM)
    }
}

// MARK: - Result

struct PaceTrainingResult: Equatable {
    let subMode: PaceSubMode
    let targetWPM: Double
    let averageWPM: Double
    let zonePercentage: Double
    let peakWPM: Double
    let lowestWPM: Double
    let totalWords: Int
    let fillerCount: Int
    let totalDuration: TimeInterval
    let wpmSamples: [Double]

    /// 1–10 score derived from zone percentage.
    var score: Int {
        switch zonePercentage {
        case 0.80...: return 10
        case 0.70..<0.80: return 9
        case 0.60..<0.70: return 8
        case 0.50..<0.60: return 7
        case 0.40..<0.50: return 6
        case 0.30..<0.40: return 5
        case 0.20..<0.30: return 4
        case 0.10..<0.20: return 3
        case 0.01..<0.10: return 2
        default: return 1
        }
    }

    var xpEarned: Int {
        score * 5
    }

    var verdictLabel: String {
        switch zonePercentage {
        case 0.70...:
            return "Locked In"
        case 0.40..<0.70:
            // Check if they started slow but finished strong.
            if let firstHalf = wpmHalfZonePercentage(first: true),
               let secondHalf = wpmHalfZonePercentage(first: false),
               secondHalf > firstHalf + 0.15 {
                return "Slow Start, Strong Finish"
            }
            return "Finding the Rhythm"
        default:
            return "Finding the Rhythm"
        }
    }

    var verdictIcon: String {
        switch zonePercentage {
        case 0.70...: return "metronome"
        case 0.40..<0.70: return "waveform.path"
        default: return "waveform"
        }
    }

    /// Zone percentage for first or second half of WPM samples.
    private func wpmHalfZonePercentage(first: Bool) -> Double? {
        guard wpmSamples.count >= 4 else { return nil }
        let mid = wpmSamples.count / 2
        let half = first ? Array(wpmSamples.prefix(mid)) : Array(wpmSamples.suffix(from: mid))
        guard !half.isEmpty else { return nil }
        let zoneMin = targetWPM - ConversationalPaceBand.toleranceWPM
        let zoneMax = targetWPM + ConversationalPaceBand.toleranceWPM
        let inZone = half.filter { $0 >= zoneMin && $0 <= zoneMax }.count
        return Double(inZone) / Double(half.count)
    }
}

// MARK: - Completion Integrity

/// Resolves whether a finished Pace run may become an earned result.
///
/// The engine's samples describe the live pace trace, while the provider's
/// terminal receipt owns the final spoken text and the recorder owns duration.
/// Keeping those responsibilities separate prevents late provider finalization
/// from turning a one- or two-word fragment into a scored result without
/// pretending the final transcript can reconstruct per-second WPM samples.
enum PaceTrainingCompletionDisposition: Equatable {
    case eligible(PaceTrainingResult)
    case insufficientSpeech
    case unusableRecording

    static func resolve(
        candidate: PaceTrainingResult,
        completion: FinalizedTranscript?,
        captureDuration: TimeInterval
    ) -> Self {
        guard RecordingCompletionGate.allowsScoringAndProgress(completion),
              let completion else {
            return .unusableRecording
        }

        let terminalWordCount = completion.text.split {
            !$0.isLetter && !$0.isNumber
        }.count
        guard PracticeProgressEligibility.qualifies(
            wordCount: terminalWordCount,
            duration: captureDuration
        ) else {
            return .insufficientSpeech
        }

        return .eligible(candidate)
    }

    var awardedXP: Int {
        guard case .eligible(let result) = self else { return 0 }
        return result.xpEarned
    }

    var result: PaceTrainingResult? {
        guard case .eligible(let result) = self else { return nil }
        return result
    }
}

// MARK: - Read-Along Passages

struct PacePassage: Identifiable, Equatable {
    let id: Int
    let title: String
    let text: String

    var words: [String] {
        text.split(separator: " ").map(String.init)
    }
}

// MARK: - Engine

@MainActor
final class PaceTrainingEngine: ObservableObject {

    // MARK: Configuration

    nonisolated static let defaultTargetWPM: Double = ConversationalPaceBand.targetWPM
    nonisolated static let zoneWidth: Double = ConversationalPaceBand.toleranceWPM
    nonisolated static let drillDuration: TimeInterval = 75

    // MARK: Published State

    @Published private(set) var phase: PaceTrainingPhase = .setup
    @Published var subMode: PaceSubMode = .freestyle
    @Published private(set) var currentWPM: Double = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var totalWords: Int = 0
    @Published private(set) var timeInZone: Int = 0

    /// Read-along: which word index the highlight should be on (constant pace).
    @Published private(set) var highlightWordIndex: Int = 0

    let targetWPM: Double
    let zoneMin: Double
    let zoneMax: Double

    /// Prompt for freestyle mode.
    @Published var prompt: String = ""

    /// Passage for read-along mode.
    @Published var passage: PacePassage = PaceTrainingEngine.passages[0]

    // MARK: Internals

    private var wordTimestamps: [(count: Int, time: Date)] = []
    private var wpmSamples: [Double] = []
    private var peakWPM: Double = 0
    private var lowestWPM: Double = 999
    private var fillerCount: Int = 0
    private var countdownTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var activeStart: Date?
    private var wasInZone: Bool = false

    // MARK: Init

    init(targetWPM: Double = PaceTrainingEngine.defaultTargetWPM) {
        self.targetWPM = targetWPM
        self.zoneMin = targetWPM - Self.zoneWidth
        self.zoneMax = targetWPM + Self.zoneWidth
    }

    // MARK: Lifecycle

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

    func confirmCaptureReady(captureReady: Bool) {
        guard case .connecting = phase,
              RecordingStartGate.allowsTimerStart(captureReady: captureReady) else { return }
        startActive()
    }

    func reset() {
        countdownTask?.cancel()
        countdownTask = nil
        tickTask?.cancel()
        wordTimestamps = []
        wpmSamples = []
        peakWPM = 0
        lowestWPM = 999
        fillerCount = 0
        currentWPM = 0
        elapsed = 0
        totalWords = 0
        timeInZone = 0
        highlightWordIndex = 0
        wasInZone = false
        activeStart = nil
        // Pick a new random prompt/passage
        prompt = Self.randomPrompt()
        passage = Self.passages.randomElement() ?? Self.passages[0]
        phase = .setup
    }

    /// Stops any in-flight countdown/live loop when the immersive screen is
    /// dismissed. Cancellation is intentionally not a result and therefore
    /// does not mutate progression or session history.
    func cancel() {
        countdownTask?.cancel()
        countdownTask = nil
        tickTask?.cancel()
        tickTask = nil
    }

    #if DEBUG
    /// Deterministic route into the production result surface for UI tests.
    /// The fixture is resolved by `PaceTrainingCompletionDisposition` before
    /// this method is called, so an insufficient receipt never reaches it.
    func presentResultForUITesting(_ result: PaceTrainingResult) {
        cancel()
        phase = .ended(result)
    }
    #endif

    // MARK: Transcript Ingestion

    /// Called from the view's onChange(of: speechVM.transcribedText).
    func ingestTranscript(_ text: String) {
        guard case .active = phase else { return }
        totalWords = text.split(separator: " ").count
    }

    /// Called from the view to update filler count.
    func updateFillerCount(_ count: Int) {
        fillerCount = count
    }

    // MARK: Active Loop

    private func startActive() {
        activeStart = Date()
        elapsed = 0
        totalWords = 0
        currentWPM = 0
        timeInZone = 0
        highlightWordIndex = 0
        wordTimestamps = []
        wpmSamples = []
        peakWPM = 0
        lowestWPM = 999
        wasInZone = false
        phase = .active

        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                tick()
            }
        }
    }

    private func tick() {
        guard case .active = phase else { return }

        elapsed += 1
        updateWPM()
        updateHighlight()

        if elapsed >= Self.drillDuration {
            finalize()
        }
    }

    /// Rolling 5-second WPM window — proven pattern from BeatTheBrakeView.
    private func updateWPM() {
        let now = Date()
        wordTimestamps.append((count: totalWords, time: now))

        let windowStart = now.addingTimeInterval(-5)
        wordTimestamps.removeAll { $0.time < windowStart.addingTimeInterval(-1) }

        if let oldest = wordTimestamps.first(where: { $0.time >= windowStart }) {
            let wordDelta = totalWords - oldest.count
            let timeDelta = now.timeIntervalSince(oldest.time)
            if timeDelta > 0.5 {
                let newWPM = Double(wordDelta) / timeDelta * 60
                currentWPM = newWPM
                wpmSamples.append(newWPM)
                if newWPM > peakWPM { peakWPM = newWPM }
                if newWPM < lowestWPM && newWPM > 0 { lowestWPM = newWPM }
            }
        }

        // Track zone time
        let inZone = currentWPM >= zoneMin && currentWPM <= zoneMax
        if inZone {
            timeInZone += 1
        }

        // Haptic on zone transitions
        if wasInZone && !inZone {
            CoachHaptic.paceWarning()
        } else if !wasInZone && inZone && elapsed > 3 {
            CoachHaptic.selectionTap()
        }
        wasInZone = inZone
    }

    /// Advance the read-along highlight at constant target pace.
    private func updateHighlight() {
        guard subMode == .readAlong else { return }
        // Words per second at target pace
        let wps = targetWPM / 60.0
        let newIndex = Int(elapsed * wps)
        highlightWordIndex = min(newIndex, passage.words.count - 1)
    }

    private func finalize() {
        tickTask?.cancel()

        let avgWPM = wpmSamples.isEmpty ? 0 : wpmSamples.reduce(0, +) / Double(wpmSamples.count)
        let zonePct = elapsed > 0 ? Double(timeInZone) / elapsed : 0
        let safeLow = lowestWPM >= 999 ? 0 : lowestWPM

        let result = PaceTrainingResult(
            subMode: subMode,
            targetWPM: targetWPM,
            averageWPM: avgWPM,
            zonePercentage: zonePct,
            peakWPM: peakWPM,
            lowestWPM: safeLow,
            totalWords: totalWords,
            fillerCount: fillerCount,
            totalDuration: elapsed,
            wpmSamples: wpmSamples
        )

        phase = .ended(result)
    }

    /// Var for zone status label.
    var zoneLabel: String {
        if currentWPM < zoneMin { return "Too Slow" }
        if currentWPM > zoneMax { return "Too Fast" }
        return "Good Pace"
    }

    /// Whether current WPM is within the target zone.
    var isInZone: Bool {
        currentWPM >= zoneMin && currentWPM <= zoneMax
    }

    /// Normalized position of the current WPM on the pace band (0–1).
    /// 0 = 60 WPM (hard left), 1 = 200 WPM (hard right).
    var bandPosition: Double {
        let minDisplay: Double = 60
        let maxDisplay: Double = 200
        return max(0, min(1, (currentWPM - minDisplay) / (maxDisplay - minDisplay)))
    }

    // MARK: - Prompts

    private static let prompts: [String] = [
        "Describe a skill you taught yourself and why it mattered.",
        "Explain why your favorite book or film changed your perspective.",
        "Walk through the most important decision you made this year.",
        "Describe a place that makes you feel calm and why.",
        "Explain a complex idea from your work to a complete beginner.",
        "Talk about a mistake you made and what you learned from it.",
        "Describe your ideal morning routine and why it works.",
        "Explain why a particular habit was hard to build.",
        "Talk about someone who influenced how you communicate.",
        "Describe a moment when you had to think on your feet.",
        "Explain why curiosity is underrated in professional life.",
        "Talk about a time you changed your mind about something important.",
    ]

    static func randomPrompt() -> String {
        prompts.randomElement() ?? prompts[0]
    }

    // MARK: - Read-Along Passages

    static let passages: [PacePassage] = [
        PacePassage(id: 1, title: "The Power of Pause",
            text: "The best speakers know when to stop talking. A well-placed pause gives your audience time to absorb what you just said. It signals confidence because only someone who trusts their message can afford silence. Most people rush to fill every gap with sound but the pause is where meaning lands. Practice holding silence for two full seconds after your key point and watch how the room leans in."),
        PacePassage(id: 2, title: "First Impressions",
            text: "You have about seven seconds to make a first impression and most of that judgment happens before you say a word. Your posture, eye contact, and the energy you carry into a room speak louder than your opening line. Stand tall, breathe, and arrive with intention. When you finally speak, let your voice match the confidence your body already showed. People trust consistency between what they see and what they hear."),
        PacePassage(id: 3, title: "Clarity Over Cleverness",
            text: "The goal of communication is not to sound intelligent. It is to be understood. Every unnecessary word is a barrier between your idea and your listener. Strip your message down to its core, then rebuild it with only what serves the audience. Short sentences land harder. Simple words travel further. The most powerful speakers in history were not the most verbose. They were the most clear."),
        PacePassage(id: 4, title: "Storytelling Structure",
            text: "Every good story has three parts. First you set the scene so your listener can picture where they are. Then you introduce tension because without conflict there is no reason to keep listening. Finally you deliver the resolution which gives your audience something to take away. This structure works in boardrooms, on stages, and in everyday conversation. Master it and you will never lose an audience again."),
        PacePassage(id: 5, title: "Listening as a Superpower",
            text: "Most people listen just long enough to plan their response. Real listening means staying with the other person even when your brain wants to jump ahead. It means noticing what they emphasize, what they skip over, and what their voice reveals beneath the words. When you truly listen, your responses become sharper because they are rooted in what was actually said, not what you assumed would be said."),
        PacePassage(id: 6, title: "Speaking Under Pressure",
            text: "Pressure does not create bad speakers. It reveals unprepared ones. When stakes are high your body floods with adrenaline and your brain wants to rush through everything at once. The antidote is structure. Know your opening line cold. Have three points ready. Trust that silence is better than filler. The audience cannot see your nerves unless you let them. Slow down, ground your feet, and speak like you belong there."),
        PacePassage(id: 7, title: "The Rule of Three",
            text: "There is something about the number three that the human mind finds satisfying. Three points feel complete without feeling exhausting. Three examples feel like a pattern without feeling repetitive. Life, liberty, and the pursuit of happiness. Government of the people, by the people, for the people. Veni, vidi, vici. When you structure your ideas in threes, your audience remembers them longer and believes them more."),
        PacePassage(id: 8, title: "Voice as Instrument",
            text: "Your voice is the most versatile instrument you own. You can speed it up to build excitement or slow it down to signal importance. You can drop to a near whisper to pull people closer or project to fill an entire room. Most speakers use only a fraction of their vocal range because they never practice varying it. Record yourself speaking and listen for moments where variety would have strengthened your message."),
        PacePassage(id: 9, title: "Difficult Conversations",
            text: "The conversations we avoid are usually the ones that matter most. Starting them is the hardest part because our brains treat social risk like physical danger. But difficult conversations handled well build deeper trust than easy ones ever could. Lead with what you observed, not what you assumed. Name the feeling without blaming the person. Ask a genuine question and then wait for the real answer, not the polite one."),
        PacePassage(id: 10, title: "Brevity Is Respect",
            text: "Saying less is not about withholding information. It is about respecting your listener enough to value their time and attention. Every meeting that runs long, every email that buries the point, and every presentation that repeats itself sends the same message: my thoughts matter more than your time. Edit ruthlessly. Cut the throat-clearing. Start with your conclusion and let people ask for details if they want them."),
        PacePassage(id: 11, title: "Building Credibility",
            text: "Credibility is not claimed. It is earned through consistency between your words and your actions over time. You build it by showing up prepared, by admitting what you do not know, and by following through on what you promised. One honest admission of uncertainty builds more trust than ten confident assertions. People do not need you to be perfect. They need you to be reliable and transparent about your limits."),
        PacePassage(id: 12, title: "Feedback That Lands",
            text: "Good feedback is specific, timely, and given with care. Telling someone they did a great job teaches them nothing. Telling them that their opening story grounded the audience in sixty seconds teaches them everything. The best feedback describes behavior and impact, not character. It sounds like what you did caused this effect rather than you are this kind of person. That distinction changes whether feedback feels like a gift or an attack."),
    ]
}
