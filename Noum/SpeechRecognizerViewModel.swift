import Foundation
import AVFoundation

class SpeechRecognizerViewModel: ObservableObject {
    private let apiKey = "efc3c337656d36be52e2c95e4859006a8d676cfc"  // <-- replace this
    private var audioEngine: AVAudioEngine?
    private var webSocketTask: URLSessionWebSocketTask?
    
    private let fillerWords: Set<String> = ["um", "uh", "er", "ah", "eh", "like", "so", "you know"]
    
    func startTranscription() {
        let url = URL(string: "wss://api.deepgram.com/v1/listen?punctuate=true&interim_results=true&filler_words=true")!
        var request = URLRequest(url: url)
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = URLSession(configuration: .default).webSocketTask(with: request)
        webSocketTask?.resume()
        receiveWebSocketMessages()
        
        startAudioStream()
        
        print("Deepgram transcription started...")
    }
    
    func stopTranscription() {
        audioEngine?.stop()
        audioEngine = nil
        webSocketTask?.cancel()
        print("Transcription stopped.")
    }
    
    private func startAudioStream() {
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            let data = self.convertBufferToPCMData(buffer: buffer)
            self.sendPCMData(data)
        }
        
        audioEngine!.prepare()
        try? audioEngine!.start()
    }
    
    private func convertBufferToPCMData(buffer: AVAudioPCMBuffer) -> Data {
        let channelData = buffer.int16ChannelData![0]
        let data = Data(bytes: channelData, count: Int(buffer.frameLength * 2))
        return data
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
        guard let transcript = try? JSONDecoder().decode(DeepgramResponse.self, from: text.data(using: .utf8)!) else {
            print("Failed to decode response")
            return
        }
        
        if let words = transcript.channel.alternatives.first?.words {
            for word in words {
                if fillerWords.contains(word.word.lowercased()) {
                    print("Detected filler word: \(word.word)")
                    self.stopTranscription()
                }
            }
        }
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

