import SwiftUI
import AVFoundation
import UIKit
import Foundation

class SpeechRecognizerViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var highlightedText: AttributedString = AttributedString("")
    @Published var isRecording: Bool = false

    /// Duration of the last completed recording session.
    @Published var lastSessionDuration: TimeInterval = 0

    /// Completed practice sessions with transcript, filler count and duration.
    @Published var pastSessions: [PracticeSession] = []

    private let apiKey = "efc3c337656d36be52e2c95e4859006a8d676cfc"  // <-- replace this
    private var audioEngine: AVAudioEngine?
    private var webSocketTask: URLSessionWebSocketTask?

    /// Start time for the current session to calculate duration.
    private var sessionStart: Date?

    /// Common filler words that should always be highlighted.
    private let baseFillerWords: Set<String> = ["like", "so", "you know"]

    /// Regexes used to locate filler words in the transcript.  This includes
    /// patterns for common dynamic variants such as "ummm" or "hmmm" so we
    /// don't rely on an exhaustive static list.
    private lazy var fillerWordRegexes: [NSRegularExpression] = {
        var regexes: [NSRegularExpression] = []

        // Regex for dynamic variants (e.g. "umm", "uhhh", "errr", "hmm").
        if let dynamic = try? NSRegularExpression(
            pattern: #"(?i)(?<!\w)(?:u+h+|u+m+|er+|ah+|eh+|h+m+|m{2,})(?=\b|[^\w]|$)"#
        ) {
            regexes.append(dynamic)
        }

        // Regexes for the base filler words.
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
        requestRecordAuthorization()
    }

    func startRecording() {
        guard !isRecording else { return }
        resetCurrentSession()
        isRecording = true
        sessionStart = Date()

        let sampleRate = AVAudioSession.sharedInstance().sampleRate
        let urlString = "wss://api.deepgram.com/v1/listen?punctuate=true&interim_results=true&filler_words=true&encoding=linear16&channels=1&sample_rate=\(Int(sampleRate))"
        guard let url = URL(string: urlString) else {
            print("Invalid Deepgram URL")
            return
        }
        var request = URLRequest(url: url)
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        webSocketTask = URLSession(configuration: .default).webSocketTask(with: request)
        webSocketTask?.resume()
        receiveWebSocketMessages()

        startAudioStream()

        print("Deepgram transcription started...")
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine?.stop()
        audioEngine = nil
        webSocketTask?.cancel()
        isRecording = false
        saveCurrentSession()
        print("Transcription stopped.")
    }

    private func requestRecordAuthorization() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("Microphone access granted.")
                    } else {
                        print("Microphone access denied.")
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("Microphone access granted.")
                    } else {
                        print("Microphone access denied.")
                    }
                }
            }
        }
    }
    
    private func startAudioStream() {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            let data = self.convertBufferToPCMData(buffer: buffer)
            self.sendPCMData(data)
        }
        
        audioEngine!.prepare()
        try? audioEngine!.start()
    }
    
    private func convertBufferToPCMData(buffer: AVAudioPCMBuffer) -> Data {
        let frameLength = Int(buffer.frameLength)
        switch buffer.format.commonFormat {
        case .pcmFormatInt16:
            if let channelData = buffer.int16ChannelData?[0] {
                return Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
            }
        case .pcmFormatFloat32:
            if let channelData = buffer.floatChannelData?[0] {
                var pcmData = Data(capacity: frameLength * MemoryLayout<Int16>.size)
                for i in 0..<frameLength {
                    let clamped = max(-1.0, min(1.0, channelData[i]))
                    var sample = Int16(clamped * Float(Int16.max))
                    withUnsafeBytes(of: &sample) { pcmData.append(contentsOf: $0) }
                }
                return pcmData
            }
        default:
            break
        }
        return Data()
    }
    
    private func sendPCMData(_ data: Data) {
        webSocketTask?.send(.data(data)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func receiveWebSocketMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleDeepgramResponse(data: data)
                case .string(let text):
                    self.handleDeepgramResponse(text: text)
                @unknown default:
                    break
                }
                self.receiveWebSocketMessages()  // keep listening
            }
        }
    }
    
    private func handleDeepgramResponse(data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            handleDeepgramResponse(text: text)
        }
    }
    
    private func handleDeepgramResponse(text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let message = try? JSONDecoder().decode(DeepgramMessage.self, from: data) else {
            print("Failed to decode response")
            return
        }

        if message.type == "Results", let alt = message.channel?.alternatives.first {
            let snippet = alt.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !snippet.isEmpty {
                DispatchQueue.main.async {
                    // Deepgram streams the full transcript with each message,
                    // so replace the text instead of appending to avoid
                    // duplicates in the UI.
                    self.transcribedText = snippet
                    self.highlightAndCountFillerWords(in: snippet)
                }
            }
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
            if let converted = try? AttributedString(attributed) {
                self.highlightedText = converted
            } else {
                self.highlightedText = AttributedString(text)
            }
            print("Transcript: \(text)")
            print("Filler words found: \(count)")
        }
    }

    /// Clear current transcript and counters before a new session.
    func resetCurrentSession() {
        transcribedText = ""
        highlightedText = AttributedString("")
        fillerWordCount = 0
    }

    /// Persist the completed session to the history list.
    private func saveCurrentSession() {
        let duration = Date().timeIntervalSince(sessionStart ?? Date())
        lastSessionDuration = duration
        let session = PracticeSession(
            transcript: transcribedText,
            fillerWordCount: fillerWordCount,
            duration: duration,
            date: sessionStart ?? Date()
        )
        pastSessions.append(session)
        sessionStart = nil
    }
}

// MARK: - Deepgram Response Models

struct DeepgramMessage: Codable {
    let type: String?
    let channel: Channel?
}

struct Channel: Codable {
    let alternatives: [Alternative]
}

struct Alternative: Codable {
    let transcript: String
    let words: [Word]?
}

struct Word: Codable {
    let word: String
    let start: Double
    let end: Double
}

// MARK: - Practice Session Model

struct PracticeSession: Identifiable {
    let id = UUID()
    let transcript: String
    let fillerWordCount: Int
    let duration: TimeInterval
    let date: Date
}

