import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(SwiftUI)
import SwiftUI
#else
// Provide minimal stubs so the code builds on platforms without SwiftUI
protocol ObservableObject {}
@propertyWrapper struct Published<Value> { var wrappedValue: Value; init(wrappedValue: Value) { self.wrappedValue = wrappedValue } }
#endif
#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

@available(iOS 17.0, macOS 12.0, *)
@MainActor
class SpeechRecognizerViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var highlightedText: AttributedString = AttributedString("")
    @Published var isRecording: Bool = false
    
    /// Duration of the last completed recording session.
    @Published var lastSessionDuration: TimeInterval = 0
    
    /// Completed practice sessions with transcript, filler count and duration.
    @Published var pastSessions: [PracticeSession] = []
    
    /// API key for authenticating with Deepgram.
    ///
    /// The key is loaded from the `DEEPGRAM_API_KEY` environment variable.
    /// If that is not present, the view model looks for a `Deepgram.plist`
    /// file in the main bundle containing the same key.  This allows the
    /// key to be provided securely without hard coding it in source control.
    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] {
            return env
        }
        if let url = Bundle.main.url(forResource: "Deepgram", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = plist as? [String: Any],
           let key = dict["DEEPGRAM_API_KEY"] as? String {
            return key
        }
        return nil
    }
    
    #if canImport(AVFoundation)
    private var audioEngine: AVAudioEngine?
    #endif
    private var webSocketTask: URLSessionWebSocketTask?

    /// Start time for the current session to calculate duration.
    private var sessionStart: Date?

    /// Final transcript built from all finalized Deepgram results.
    private var finalTranscript: String = ""

    /// Latest partial snippet that has not yet been finalized.
    private var partialTranscript: String = ""
    
    /// Common filler words that should always be highlighted.
    ///
    /// This includes short variants like "um" or "er" in addition to
    /// conversational phrases such as "you know".
    private let baseFillerWords: Set<String> = [
        "uh", "um", "er", "erm", "ah", "eh", "huh",
        "like", "so", "you know"
    ]
    
    /// Regexes used to locate filler words in the transcript.  This includes
    /// patterns for common dynamic variants such as "ummm" or "hmmm" so we
    /// don't rely on an exhaustive static list.
    private lazy var fillerWordRegexes: [NSRegularExpression] = {
        var regexes: [NSRegularExpression] = []
        
        // Regex for dynamic variants with repeated letters like "ummm" or
        // "erhh". These catch stuttered forms that may not match the base
        // words exactly.
        if let dynamic = try? NSRegularExpression(
            pattern: #"(?i)(?<!\w)(?:u+h{2,}|u+m{2,}|hu+h+|er{2,}|er+m{2,}|ah+|eh+|h+m+|m{2,})(?=\b|[^\w]|$)"#
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
    
#if canImport(AVFoundation)
    init() {
        requestRecordAuthorization()
    }

    func startRecording() {
        guard !isRecording else { return }
        guard let key = apiKey, !key.isEmpty else {
            print("Deepgram API key not found")
            transcribedText = "Missing Deepgram API key."
            return
        }
        resetCurrentSession()
        isRecording = true
        sessionStart = Date()
        
        let sampleRate = AVAudioSession.sharedInstance().sampleRate
        let urlString = "wss://api.deepgram.com/v1/listen?punctuate=true&interim_results=true&filler_words=true&words=true&encoding=linear16&channels=1&sample_rate=\(Int(sampleRate))"
        guard let url = URL(string: urlString) else {
            print("Invalid Deepgram URL")
            return
        }
        var request = URLRequest(url: url)
        
        request.addValue("Token \(key)", forHTTPHeaderField: "Authorization")
        
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
        // Append any remaining partial transcript before saving.
        if !partialTranscript.isEmpty {
            if !finalTranscript.isEmpty {
                finalTranscript += " "
            }
            finalTranscript += partialTranscript
            partialTranscript = ""
            transcribedText = finalTranscript
            highlightAndCountFillerWords(in: finalTranscript)
        }
        saveCurrentSession()
        print("Transcription stopped.")
        print("Final transcript: \(finalTranscript)")
        print("Total filler words: \(fillerWordCount)")
    }
    
    private func requestRecordAuthorization() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Microphone access granted.")
                } else {
                    print("Microphone access denied.")
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
                Task { @MainActor in
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
            guard !snippet.isEmpty else { return }
            DispatchQueue.main.async {
                if message.isFinal == true {
                    if !self.finalTranscript.isEmpty {
                        self.finalTranscript += " "
                    }
                    self.finalTranscript += snippet
                    self.partialTranscript = ""
                } else {
                    self.partialTranscript = snippet
                }

                let combined = [self.finalTranscript, self.partialTranscript]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                self.transcribedText = combined
                self.highlightAndCountFillerWords(in: combined)
                print("Transcript snippet: \(snippet)")
                print("Current transcript on screen: \(combined)")
                print("Filler words found: \(self.fillerWordCount)")
            }
        }
    }
#endif // canImport(AVFoundation)
    
    /// Highlight any filler words found in `text` and update ``fillerWordCount``.
    ///
    /// Made internal for unit testing so that tests can verify the filler word
    /// detection logic without needing to record audio or parse a full
    /// Deepgram response.
    func highlightAndCountFillerWords(in text: String) {
        var count = 0
        let attributed = NSMutableAttributedString(string: text)
        for regex in fillerWordRegexes {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            count += matches.count
            for match in matches {
#if canImport(UIKit) || canImport(AppKit)
                attributed.addAttribute(.foregroundColor, value: PlatformColor.red, range: match.range)
#endif
            }
        }
        DispatchQueue.main.async {
            self.fillerWordCount = count

        #if canImport(UIKit) || canImport(AppKit)
            self.highlightedText = AttributedString(attributed)
        #else
            self.highlightedText = AttributedString(text)
        #endif
        }
    }

    /// Clear current transcript and counters before a new session.
    func resetCurrentSession() {
        transcribedText = ""
        highlightedText = AttributedString("")
        fillerWordCount = 0
        finalTranscript = ""
        partialTranscript = ""
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
    
    // MARK: - Deepgram Response Models
    
    struct DeepgramMessage: Codable {
        let type: String?
        let channel: Channel?
        let isFinal: Bool?

        private enum CodingKeys: String, CodingKey {
            case type
            case channel
            case isFinal = "is_final"
        }

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
}
