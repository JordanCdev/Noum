import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
import AWSSDKIdentity
import AWSTranscribeStreaming
import AWSClientRuntime



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
    private var streamConnection: StartStreamTranscriptionOutput?
    private var requestStream: AsyncThrowingStream<TranscribeStreamingClientTypes.AudioStream, Error>.Continuation?

    private var sessionStart: Date?
    private var finalTranscript: String = ""
    private var partialTranscript: String = ""


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

        let stream = AsyncThrowingStream<TranscribeStreamingClientTypes.AudioStream, Error> { continuation in
            self.requestStream = continuation
        }
        let request = StartStreamTranscriptionInput(
            audioStream: stream,
            languageCode: .enUs,
            mediaEncoding: .pcm,
            mediaSampleRateHertz: 48000
        )

        // NEW AWS SDK WAY
        do {
            transcribeClient = try TranscribeStreamingClient(
                region: authManager.region,
                awsCredentialIdentityResolver: authManager.credentialResolver()
            )
        } catch {
            print("Failed to create AWS client: \(error)")
            connectionError = "\(error)"
            return
        }

        Task {
            do {
                if let client = transcribeClient {
                    let output = try await client.startStreamTranscription(input: request)
                    streamConnection = output
                    Task.detached { [weak self] in
                        if let events = output.transcriptResultStream {
                            for try await event in events {
                                await self?.handleTranscribeEvent(event)
                            }
                        }
                    }
                    print("Transcribe streaming started")
                }
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
        requestStream?.finish()
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
            self.requestStream?.yield(
                .audioevent(TranscribeStreamingClientTypes.AudioEvent(audioChunk: data))
            )
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

    private func handleTranscribeEvent(_ event: TranscribeStreamingClientTypes.TranscriptResultStream) async {
        switch event {
        case .transcriptevent(let transcriptEvent):
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
        let matches = FillerWordDetector.matches(in: text)
        let count = matches.count
        let attributed = NSMutableAttributedString(string: text)
        for match in matches {
            attributed.addAttribute(.foregroundColor, value: UIColor.red, range: match.range)
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
