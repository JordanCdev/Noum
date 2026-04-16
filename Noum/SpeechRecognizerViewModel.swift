import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(AVFoundation)
@MainActor
class SpeechRecognizerViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var highlightedText: AttributedString = AttributedString("")
    @Published var isRecording: Bool = false
    @Published var lastSessionDuration: TimeInterval = 0
    @Published var pastSessions: [PracticeSession] = []
    @Published var connectionError: String?
    @Published var activeProviderName: String = ""

    /// When set, filler detection uses context-aware logic that excludes prompt echoes
    /// and ambiguous words in legitimate usage. Used by Pressure Drill mode.
    var pressureDrillPrompt: String?
    @Published var pressureDrillFillerCount: Int = 0

    private let sessionStore = PracticeSessionStore.shared
    private let recommendationLearningStore = RecommendationLearningStore.shared

    // Provider abstraction — replaces direct AWS SDK usage
    private var provider: any TranscriptionProvider
    private var activeSession: (any TranscriptionSession)?
    private var transcriptListenerTask: Task<Void, Never>?

    private var audioEngine: AVAudioEngine?
    private var sessionStart: Date?
    private var finalTranscript: String = ""
    private var partialTranscript: String = ""
    private var currentSessionMode: PracticeMode = .ahCounter
    private var hasPreparedInteractiveUse = false

    // Quality tracking
    private var sessionUpdateCount: Int = 0
    private var totalLatencyMs: Int = 0
    private var confidenceValues: [Double] = []
    private var providerFillerCount: Int = 0

    init(preloadOnInit: Bool = true) {
        self.provider = Self.resolveProvider()
        self.activeProviderName = provider.name
        guard preloadOnInit else { return }
        loadSessions()
        prepareForInteractiveUse()
    }

    private static func resolveProvider() -> any TranscriptionProvider {
        let selected = UserDefaults.standard.string(forKey: "transcriptionProvider") ?? "deepgram"
        switch selected {
        case "deepgram": return DeepgramProvider()
        case "google": return GoogleSpeechProvider()
        default: return AWSTranscribeProvider()
        }
    }

    func prepareSession(mode: PracticeMode) {
        currentSessionMode = mode
    }

    func prepareForInteractiveUse() {
        guard !hasPreparedInteractiveUse else { return }
        hasPreparedInteractiveUse = true
        loadSessions()
        requestRecordAuthorization()
    }

    func annotateLatestSession(
        score: Int? = nil,
        xpEarned: Int? = nil,
        headline: String? = nil,
        insights: [String] = [],
        coachSummary: String? = nil,
        prompt: String? = nil,
        theme: PromptTheme? = nil
    ) {
        sessionStore.annotateLatest(
            PracticeSessionAnnotation(
                score: score,
                xpEarned: xpEarned,
                headline: headline,
                insights: insights,
                coachSummary: coachSummary,
                prompt: prompt,
                theme: theme
            ),
            expectedMode: currentSessionMode
        )
        pastSessions = sessionStore.sessions
        if let latest = sessionStore.sessions.first {
            recommendationLearningStore.recordOutcome(
                for: latest,
                previousSessions: Array(sessionStore.sessions.dropFirst())
            )
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        prepareForInteractiveUse()

        // Re-resolve provider in case user changed settings
        provider = Self.resolveProvider()
        activeProviderName = provider.name

        Task {
            print("Starting transcription with \(provider.name)")
            await startRecordingWithProvider()
        }
    }

    private func startRecordingWithProvider() async {
        resetCurrentSession()
        sessionStart = Date()
        sessionUpdateCount = 0
        totalLatencyMs = 0
        confidenceValues = []
        providerFillerCount = 0

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        let sampleRate = Int(AVAudioSession.sharedInstance().sampleRate)
        let config = TranscriptionConfig(
            languageCode: "en-US",
            sampleRate: sampleRate,
            encoding: .pcmSigned16Bit,
            enableFillerWordDetection: true
        )

        do {
            let session = try await provider.startSession(config: config)
            self.activeSession = session

            // Start audio capture and feed into the session
            try startAudioStream(sendingTo: session)
            isRecording = true

            // Listen for transcript updates
            transcriptListenerTask = Task { [weak self] in
                for await update in session.transcriptUpdates {
                    await self?.handleTranscriptUpdate(update)
                }
            }
        } catch {
            print("Failed to start \(provider.name) session: \(error)")
            failStartRecording(with: error)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        print("Stopping transcription")
        teardownAudioStream()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false

        Task {
            try? await activeSession?.endAudio()
            activeSession = nil
            transcriptListenerTask?.cancel()
            transcriptListenerTask = nil

            // Allow time for any final transcripts to arrive before finalizing
            try? await Task.sleep(for: .milliseconds(500))
            finalizeTranscript()
            recordQualityMetrics()
        }
    }

    private func finalizeTranscript() {
        if !partialTranscript.isEmpty {
            if !finalTranscript.isEmpty { finalTranscript += " " }
            finalTranscript += partialTranscript
            partialTranscript = ""
            transcribedText = finalTranscript
            highlightAndCountFillerWords(in: finalTranscript)
        }
        saveCurrentSession()
    }

    // MARK: - Transcript Update Handling (provider-agnostic)

    private func handleTranscriptUpdate(_ update: TranscriptUpdate) {
        sessionUpdateCount += 1
        if let latency = update.latencyMs { totalLatencyMs += latency }
        if let confidence = update.confidence { confidenceValues.append(confidence) }
        if let providerFillers = update.providerFillerWords {
            providerFillerCount += providerFillers.count
        }

        let snippet = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else { return }

        if update.isFinal {
            if !finalTranscript.isEmpty { finalTranscript += " " }
            finalTranscript += snippet
            partialTranscript = ""
        } else {
            partialTranscript = snippet
        }

        let combined = [finalTranscript, partialTranscript].filter { !$0.isEmpty }.joined(separator: " ")
        transcribedText = combined
        highlightAndCountFillerWords(in: combined)
    }

    // MARK: - Audio Engine (provider-agnostic)

    private func requestRecordAuthorization() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted { print("Microphone access granted.") }
                else { print("Microphone access denied.") }
            }
        }
    }

    private func startAudioStream(sendingTo session: any TranscriptionSession) throws {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let data = self.convertBufferToPCMData(buffer: buffer)
            Task { try? await session.sendAudio(data) }
        }

        audioEngine!.prepare()
        try audioEngine!.start()
    }

    private func teardownAudioStream() {
        guard let audioEngine else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        self.audioEngine = nil
    }

    private func failStartRecording(with error: Error) {
        connectionError = "\(error)"
        teardownAudioStream()
        try? AVAudioSession.sharedInstance().setActive(false)
        activeSession = nil
        transcriptListenerTask?.cancel()
        transcriptListenerTask = nil
        isRecording = false
        sessionStart = nil
    }

    private func convertBufferToPCMData(buffer: AVAudioPCMBuffer) -> Data {
        let frameLength = Int(buffer.frameLength)
        if let channelData = buffer.floatChannelData?[0] {
            var pcmData = Data(capacity: frameLength * MemoryLayout<Int16>.size)
            for i in 0..<frameLength {
                let clamped = max(-1.0, min(1.0, channelData[i]))
                var sample = Int16(clamped * Float(Int16.max))
                withUnsafeBytes(of: &sample) { pcmData.append(contentsOf: $0) }
            }
            return pcmData
        }
        return Data()
    }

    // MARK: - Filler Word Detection

    private func highlightAndCountFillerWords(in text: String) {
        let matches = FillerWordDetector.matches(in: text)
        let count = matches.count
        let attributed = NSMutableAttributedString(string: text)
        for match in matches {
            attributed.addAttribute(.foregroundColor, value: UIColor.red, range: match.range)
        }
        fillerWordCount = count
        highlightedText = AttributedString(attributed)

        // If running in Pressure Drill mode, also compute context-aware count
        if let prompt = pressureDrillPrompt {
            pressureDrillFillerCount = FillerWordDetector.pressureDrillCount(in: text, prompt: prompt)
        }
    }

    // MARK: - Session Management

    func resetCurrentSession() {
        transcribedText = ""
        highlightedText = AttributedString("")
        fillerWordCount = 0
        pressureDrillFillerCount = 0
        finalTranscript = ""
        partialTranscript = ""
        connectionError = nil
    }

    private func saveCurrentSession() {
        let duration = Date().timeIntervalSince(sessionStart ?? Date())
        lastSessionDuration = duration
        let trimmed = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, duration >= 1 else {
            sessionStart = nil
            return
        }
        guard currentSessionMode != .imConversation else {
            sessionStart = nil
            pastSessions = sessionStore.sessions
            return
        }
        let avgConfidence = confidenceValues.isEmpty ? nil : confidenceValues.reduce(0, +) / Double(confidenceValues.count)
        let pressureOn = PracticeSettingsManager.shared.pressureModeEnabled
        let pressure = BaselineEngine.classifyPressure(
            mode: currentSessionMode,
            isPressureModeOn: pressureOn,
            streakDays: PracticeSession.calculateStreak(from: sessionStore.sessions)
        )
        _ = PracticeSessionFinalizer.finalize(
            store: sessionStore,
            draft: PracticeSessionDraft(
                transcript: transcribedText,
                fillerWordCount: fillerWordCount,
                duration: duration,
                date: sessionStart ?? Date(),
                mode: currentSessionMode,
                transcriptConfidence: avgConfidence,
                transcriptionProvider: provider.identifier,
                pressureLevel: pressure,
                isRated: pressureOn
            )
        )
        pastSessions = sessionStore.sessions
        sessionStart = nil
    }

    private func loadSessions() {
        sessionStore.reload()
        pastSessions = sessionStore.sessions
    }

    // MARK: - Quality Metrics

    private func recordQualityMetrics() {
        let duration = Date().timeIntervalSince(sessionStart ?? Date())
        let avgLatency = sessionUpdateCount > 0 ? totalLatencyMs / sessionUpdateCount : 0
        let avgConfidence = confidenceValues.isEmpty ? nil : confidenceValues.reduce(0, +) / Double(confidenceValues.count)
        let wordCount = transcribedText.split { !$0.isLetter && !$0.isNumber }.count

        let metric = TranscriptionQualityMetrics(
            provider: provider.identifier,
            sessionId: UUID(),
            date: Date(),
            totalLatencyMs: avgLatency,
            finalTranscriptLength: wordCount,
            fillerWordsDetected: fillerWordCount,
            providerFillersDetected: providerFillerCount,
            averageConfidence: avgConfidence,
            sessionDuration: duration
        )
        TranscriptionQualityStore.shared.record(metric)
    }
}
#endif

struct PracticeSession: Identifiable, Codable {
    var id: UUID = UUID()
    let transcript: String
    let fillerWordCount: Int
    let duration: TimeInterval
    let date: Date
    var mode: PracticeMode = .ahCounter
    var imConversationDetails: IMConversationDetails? = nil
    var score: Int? = nil
    var xpEarned: Int? = nil
    var headline: String? = nil
    var insights: [String] = []
    var coachSummary: String? = nil
    var aiCoachFeedback: AICoachFeedback? = nil
    var prompt: String? = nil
    var theme: PromptTheme? = nil
    var drillResult: DrillResult? = nil
    var transcriptConfidence: Double? = nil
    var transcriptionProvider: String? = nil
    var pressureLevel: PressureLevel = .standard
    var isRated: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case transcript
        case fillerWordCount
        case duration
        case date
        case mode
        case imConversationDetails
        case score
        case xpEarned
        case headline
        case insights
        case coachSummary
        case aiCoachFeedback
        case prompt
        case theme
        case drillResult
        case transcriptConfidence
        case transcriptionProvider
        case pressureLevel
        case isRated
    }

    init(
        id: UUID = UUID(),
        transcript: String,
        fillerWordCount: Int,
        duration: TimeInterval,
        date: Date,
        mode: PracticeMode = .ahCounter,
        imConversationDetails: IMConversationDetails? = nil,
        score: Int? = nil,
        xpEarned: Int? = nil,
        headline: String? = nil,
        insights: [String] = [],
        coachSummary: String? = nil,
        aiCoachFeedback: AICoachFeedback? = nil,
        prompt: String? = nil,
        theme: PromptTheme? = nil,
        drillResult: DrillResult? = nil,
        transcriptConfidence: Double? = nil,
        transcriptionProvider: String? = nil,
        pressureLevel: PressureLevel = .standard,
        isRated: Bool = false
    ) {
        self.id = id
        self.transcript = transcript
        self.fillerWordCount = fillerWordCount
        self.duration = duration
        self.date = date
        self.mode = mode
        self.imConversationDetails = imConversationDetails
        self.score = score
        self.xpEarned = xpEarned
        self.headline = headline
        self.insights = insights
        self.coachSummary = coachSummary
        self.aiCoachFeedback = aiCoachFeedback
        self.prompt = prompt
        self.theme = theme
        self.drillResult = drillResult
        self.transcriptConfidence = transcriptConfidence
        self.transcriptionProvider = transcriptionProvider
        self.pressureLevel = pressureLevel
        self.isRated = isRated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        transcript = try container.decode(String.self, forKey: .transcript)
        fillerWordCount = try container.decode(Int.self, forKey: .fillerWordCount)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        date = try container.decode(Date.self, forKey: .date)
        mode = try container.decodeIfPresent(PracticeMode.self, forKey: .mode) ?? .ahCounter
        imConversationDetails = try container.decodeIfPresent(IMConversationDetails.self, forKey: .imConversationDetails)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        xpEarned = try container.decodeIfPresent(Int.self, forKey: .xpEarned)
        headline = try container.decodeIfPresent(String.self, forKey: .headline)
        insights = try container.decodeIfPresent([String].self, forKey: .insights) ?? []
        coachSummary = try container.decodeIfPresent(String.self, forKey: .coachSummary)
        aiCoachFeedback = try container.decodeIfPresent(AICoachFeedback.self, forKey: .aiCoachFeedback)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        theme = try container.decodeIfPresent(PromptTheme.self, forKey: .theme)
        drillResult = try container.decodeIfPresent(DrillResult.self, forKey: .drillResult)
        transcriptConfidence = try container.decodeIfPresent(Double.self, forKey: .transcriptConfidence)
        transcriptionProvider = try container.decodeIfPresent(String.self, forKey: .transcriptionProvider)
        pressureLevel = try container.decodeIfPresent(PressureLevel.self, forKey: .pressureLevel) ?? .standard
        isRated = try container.decodeIfPresent(Bool.self, forKey: .isRated) ?? false
    }
}
