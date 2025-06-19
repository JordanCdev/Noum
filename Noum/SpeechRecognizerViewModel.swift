import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
import AWSSDKIdentity
import AWSTranscribeStreaming

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

    private let sessionsKey = "practiceSessions"
    private let authManager: AuthManager = .shared

    private var audioEngine: AVAudioEngine?
    private var transcribeClient: TranscribeStreamingClient?
    private var streamConnection: TranscribeStreamingStartStreamTranscriptionOutputEventStream?
    private var requestStream: TranscribeStreamingStartStreamTranscriptionInputStream?

    private var sessionStart: Date?
    private var finalTranscript: String = ""
    private var partialTranscript: String = ""

    private let baseFillerWords: Set<String> = [
        "uh", "um", "er", "erm", "ah", "eh", "huh",
        "like", "so", "you know"
    ]

    private lazy var fillerWordRegexes: [NSRegularExpression] = {
        var regexes: [NSRegularExpression] = []
        if let dynamic = try? NSRegularExpression(
            pattern: #"(?i)(?<!\w)(?:u+h{2,}|u+m{2,}|hu+h+|er{2,}|er+m{2,}|ah+|eh+|h+m+|m{2,})(?=\b|[^\w]|$)"#
        ) {
            regexes.append(dynamic)
        }
        for word in baseFillerWords {
            let escaped = NSRegularExpression.escapedPattern(for: word)
            let pattern = #"(?i)(?<!\w)\#(escaped)(?=\b|[^\w]|$)"#
            if let r = try? NSRegularExpression(pattern: pattern) {
                regexes.append(r)
            }
        }
        return regexes
    }()

    init() {
        loadSessions()
        requestRecordAuthorization()
    }

    func startRecording() {
        guard !isRecording else { return }
        Task {
            do {
                _ = try await authManager.currentCredentials()
                await self.startRecordingWith()
            } catch {
                print("Failed to fetch AWS credentials: \(error)")
                await MainActor.run { self.transcribedText = "Failed to fetch AWS credentials." }
            }
        }
    }

    private func startRecordingWith() async {
        resetCurrentSession()
        isRecording = true
        sessionStart = Date()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        do {
            let config = try TranscribeStreamingClient.TranscribeStreamingClientConfiguration(
                region: authManager.region,
                awsCredentialIdentityResolver: authManager.credentialResolver()
            )
            transcribeClient = TranscribeStreamingClient(config: config)
        } catch {
            print("Failed to create AWS client: \(error)")
            return
        }

        let request = StartStreamTranscriptionInput(
            languageCode: .enUS,
            mediaEncoding: .pcm,
            mediaSampleRateHertz: 48000,
            audioStream: .init()
        )

        self.requestStream = request.audioStream

        Task {
            do {
                streamConnection = try await transcribeClient?.startStreamTranscription(input: request, onEvent: handleTranscribeEvent(_:))
                print("Transcribe streaming started")
            } catch {
                print("Transcribe start failed: \(error)")
                connectionError = "\(error)"
                stopRecording()
            }
        }

        startAudioStream()
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine?.stop()
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        Task { await requestStream?.close() }
        isRecording = false

        if !partialTranscript.isEmpty {
            if !finalTranscript.isEmpty { finalTranscript += " " }
            finalTranscript += partialTranscript
            partialTranscript = ""
            transcribedText = finalTranscript
            highlightAndCountFillerWords(in: finalTranscript)
        }
        saveCurrentSession()
    }

    private func requestRecordAuthorization() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted { print("Microphone access granted.") }
                else { print("Microphone access denied.") }
            }
        }
    }

    private func startAudioStream() {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            let data = self.convertBufferToPCMData(buffer: buffer)
            Task { await self.requestStream?.send(.audioEvent(.init(audioChunk: data))) }
        }

        audioEngine!.prepare()
        try? audioEngine!.start()
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

    private func handleTranscribeEvent(_ event: StartStreamTranscriptionOutputEventStream) async {
        switch event {
        case .transcriptEvent(let transcriptEvent):
            for result in transcriptEvent.transcript?.results ?? [] {
                guard let alternative = result.alternatives?.first,
                      let snippet = alternative.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !snippet.isEmpty else { continue }

                DispatchQueue.main.async {
                    if result.isPartial == false {
                        if !self.finalTranscript.isEmpty { self.finalTranscript += " " }
                        self.finalTranscript += snippet
                        self.partialTranscript = ""
                    } else {
                        self.partialTranscript = snippet
                    }

                    let combined = [self.finalTranscript, self.partialTranscript].filter { !$0.isEmpty }.joined(separator: " ")
                    self.transcribedText = combined
                    self.highlightAndCountFillerWords(in: combined)
                }
            }
        default: break
        }
    }

    private func highlightAndCountFillerWords(in text: String) {
        var count = 0
        let attributed = NSMutableAttributedString(string: text)
        for regex in fillerWordRegexes {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            count += matches.count
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: UIColor.red, range: match.range)
            }
        }
        DispatchQueue.main.async {
            self.fillerWordCount = count
            self.highlightedText = AttributedString(attributed)
        }
    }

    func resetCurrentSession() {
        transcribedText = ""
        highlightedText = AttributedString("")
        fillerWordCount = 0
        finalTranscript = ""
        partialTranscript = ""
        connectionError = nil
    }

    private func saveCurrentSession() {
        let duration = Date().timeIntervalSince(sessionStart ?? Date())
        lastSessionDuration = duration
        let session = PracticeSession(transcript: transcribedText, fillerWordCount: fillerWordCount, duration: duration, date: sessionStart ?? Date())
        pastSessions.insert(session, at: 0)
        saveSessions()
        sessionStart = nil
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([PracticeSession].self, from: data) else { return }
        pastSessions = sessions.sorted { $0.date > $1.date }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(pastSessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }
}
#endif

struct PracticeSession: Identifiable, Codable {
    let id: UUID = UUID()
    let transcript: String
    let fillerWordCount: Int
    let duration: TimeInterval
    let date: Date
}
