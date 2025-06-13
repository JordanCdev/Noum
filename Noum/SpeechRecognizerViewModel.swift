import SwiftUI
import AVFoundation
import UIKit

class SpeechRecognizerViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var highlightedText: AttributedString = AttributedString("")
    @Published var isRecording: Bool = false

    private let apiKey = "efc3c337656d36be52e2c95e4859006a8d676cfc"  // <-- replace this
    private var audioEngine: AVAudioEngine?
    private var webSocketTask: URLSessionWebSocketTask?

    private let fillerWords: Set<String> = ["um", "uh", "er", "ah", "eh", "like", "so", "you know"]
    private lazy var fillerWordRegexes: [NSRegularExpression] = {
        fillerWords.compactMap { filler in
            let escaped = NSRegularExpression.escapedPattern(for: filler)
            let pattern = #"(?i)(?<!\w)\#(escaped)(?=\b|[^\w]|$)"#
            return try? NSRegularExpression(pattern: pattern)
        }
    }()

    init() {
        requestRecordAuthorization()
    }

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        let url = URL(string: "wss://api.deepgram.com/v1/listen?punctuate=true&interim_results=true&filler_words=true")!
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
                    pcmData.append(UnsafeBufferPointer(start: &sample, count: 1))
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
        // Very simple decoding for this prototype
        guard let response = try? JSONDecoder().decode(DeepgramResponse.self, from: text.data(using: .utf8)!) else {
            print("Failed to decode response")
            return
        }

        if let alt = response.channel.alternatives.first {
            let snippet = alt.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !snippet.isEmpty {
                transcribedText += transcribedText.isEmpty ? snippet : " " + snippet
                highlightAndCountFillerWords(in: transcribedText)
            }
        }
    }

    private func highlightAndCountFillerWords(in text: String) {
        fillerWordCount = 0
        let attributed = NSMutableAttributedString(string: text)
        for regex in fillerWordRegexes {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            fillerWordCount += matches.count
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: UIColor.red, range: match.range)
            }
        }
        highlightedText = AttributedString(attributed)
        print("Transcript: \(text)")
        print("Filler words found: \(fillerWordCount)")
    }
}

// MARK: - Deepgram Response Models

struct DeepgramResponse: Codable {
    let channel: Channel
    
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
}

