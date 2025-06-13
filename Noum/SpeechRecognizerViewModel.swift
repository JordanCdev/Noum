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
#if canImport(CryptoKit)
import CryptoKit
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

    /// Key used for persisting sessions to UserDefaults.
    private let sessionsKey = "practiceSessions"
    

    /// AWS credentials for authenticating with Amazon Transcribe.
    private var awsAccessKey: String? {
        if let env = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] {
            return env
        }
        if let url = Bundle.main.url(forResource: "Transcribe", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = plist as? [String: Any],
           let key = dict["AWS_ACCESS_KEY_ID"] as? String {
            return key
        }
        return nil
    }

    private var awsSecretKey: String? {
        if let env = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] {
            return env
        }
        if let url = Bundle.main.url(forResource: "Transcribe", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = plist as? [String: Any],
           let key = dict["AWS_SECRET_ACCESS_KEY"] as? String {
            return key
        }
        return nil
    }

    private var awsSessionToken: String? {
        if let env = ProcessInfo.processInfo.environment["AWS_SESSION_TOKEN"] {
            return env
        }
        if let url = Bundle.main.url(forResource: "Transcribe", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = plist as? [String: Any],
           let key = dict["AWS_SESSION_TOKEN"] as? String {
            return key
        }
        return nil
    }

    private var awsRegion: String {
        if let env = ProcessInfo.processInfo.environment["AWS_REGION"] {
            return env
        }
        if let url = Bundle.main.url(forResource: "Transcribe", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let dict = plist as? [String: Any],
           let key = dict["AWS_REGION"] as? String {
            return key
        }
        return "us-east-1"
    }
    
    #if canImport(AVFoundation)
    private var audioEngine: AVAudioEngine?
    #endif
    private var webSocketTask: URLSessionWebSocketTask?

    /// Start time for the current session to calculate duration.
    private var sessionStart: Date?
    /// Final transcript built from all finalized recognition results.
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

    /// Load any previously saved sessions from UserDefaults.
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([PracticeSession].self, from: data) else {
            return
        }
        pastSessions = sessions.sorted { $0.date > $1.date }
    }

    /// Persist the current sessions array to UserDefaults.
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(pastSessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    init() {
        loadSessions()
#if canImport(AVFoundation)
        requestRecordAuthorization()
#endif
    }

#if canImport(AVFoundation)
    func startRecording() {
        guard !isRecording else { return }
        guard let accessKey = awsAccessKey, let secretKey = awsSecretKey else {
            print("AWS credentials not found")
            transcribedText = "Missing AWS credentials."
            return
        }

        resetCurrentSession()
        isRecording = true
        sessionStart = Date()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }

        let sampleRate = Int(audioSession.sampleRate)
        guard let url = createTranscribeURL(sampleRate: sampleRate,
                                            region: awsRegion,
                                            accessKey: accessKey,
                                            secretKey: secretKey,
                                            sessionToken: awsSessionToken) else {
            print("Failed to create Transcribe URL")
            return
        }
        var request = URLRequest(url: url)
        webSocketTask = URLSession(configuration: .default).webSocketTask(with: request)
        webSocketTask?.resume()
        receiveAmazonMessages()
        startAudioStream()
        print("Amazon Transcribe transcription started...")
    }

    /// Start recording using Amazon Transcribe instead of Deepgram.
    func startAmazonRecording() {
        guard !isRecording else { return }
        guard let accessKey = awsAccessKey, let secretKey = awsSecretKey else {
            print("AWS credentials not found")
            transcribedText = "Missing AWS credentials."
            return
        }

        resetCurrentSession()
        isRecording = true
        sessionStart = Date()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }

        let sampleRate = Int(audioSession.sampleRate)
        guard let url = createTranscribeURL(sampleRate: sampleRate,
                                            region: awsRegion,
                                            accessKey: accessKey,
                                            secretKey: secretKey,
                                            sessionToken: awsSessionToken) else {
            print("Failed to create Transcribe URL")
            return
        }
        var request = URLRequest(url: url)
        webSocketTask = URLSession(configuration: .default).webSocketTask(with: request)
        webSocketTask?.resume()
        receiveAmazonMessages()
        startAudioStream()
        print("Amazon Transcribe transcription started...")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        audioEngine?.stop()
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false)
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
        guard let task = webSocketTask else { return }

        // Avoid spamming the log with errors when the connection is closed or
        // failed to open due to network restrictions.
        guard task.state == .running else {
            print("WebSocket not connected; dropping audio chunk")
            return
        }

        task.send(.data(data)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    // MARK: - Amazon Transcribe Helpers

    private func createTranscribeURL(sampleRate: Int, region: String,
                                     accessKey: String, secretKey: String,
                                     sessionToken: String?) -> URL? {
        let service = "transcribe"
        let host = "transcribestreaming.\(region).amazonaws.com:8443"
        let algorithm = "AWS4-HMAC-SHA256"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let amzDate = formatter.string(from: Date())
        let dateStamp = String(amzDate.prefix(8))
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"

        var query: [String: String] = [
            "X-Amz-Algorithm": algorithm,
            "X-Amz-Credential": "\(accessKey)/\(credentialScope)",
            "X-Amz-Date": amzDate,
            "X-Amz-Expires": "300",
            "X-Amz-SignedHeaders": "host",
            "language-code": "en-US",
            "media-encoding": "pcm",
            "sample-rate": String(sampleRate)
        ]
        if let token = sessionToken, !token.isEmpty {
            query["X-Amz-Security-Token"] = token
        }

        let canonicalQuery = query
            .map { ($0.key, $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0)=\($1)" }
            .joined(separator: "&")

        let canonicalRequest = [
            "GET",
            "/stream-transcription-websocket",
            canonicalQuery,
            "host:\(host)\n",
            "host",
            "UNSIGNED-PAYLOAD"
        ].joined(separator: "\n")

        let hash = sha256Hex(canonicalRequest)
        let stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            hash
        ].joined(separator: "\n")

        let signingKey = getSigningKey(secretKey: secretKey, dateStamp: dateStamp, regionName: region, serviceName: service)
        let signature = hmacSHA256Hex(data: stringToSign, key: signingKey)

        let finalQuery = canonicalQuery + "&X-Amz-Signature=" + signature
        let urlString = "wss://\(host)/stream-transcription-websocket?" + finalQuery
        return URL(string: urlString)
    }

    private func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        #if canImport(CryptoKit)
        return data.withUnsafeBytes { bytes in
            let digest = SHA256.hash(data: bytes)
            return digest.map { String(format: "%02x", $0) }.joined()
        }
        #else
        return ""
        #endif
    }

    private func hmacSHA256Hex(data: String, key: Data) -> String {
        let dataBytes = Data(data.utf8)
        #if canImport(CryptoKit)
        let keySym = SymmetricKey(data: key)
        let signature = HMAC<SHA256>.authenticationCode(for: dataBytes, using: keySym)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
        #else
        return ""
        #endif
    }

    private func getSigningKey(secretKey: String, dateStamp: String, regionName: String, serviceName: String) -> Data {
        let kDate = hmacSHA256(data: dateStamp, key: "AWS4" + secretKey)
        let kRegion = hmacSHA256(data: regionName, keyData: kDate)
        let kService = hmacSHA256(data: serviceName, keyData: kRegion)
        return hmacSHA256(data: "aws4_request", keyData: kService)
    }

    private func hmacSHA256(data: String, key: String) -> Data {
        return hmacSHA256(data: data, keyData: Data(key.utf8))
    }

    private func hmacSHA256(data: String, keyData: Data) -> Data {
        let dataBytes = Data(data.utf8)
        #if canImport(CryptoKit)
        let keySym = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(for: dataBytes, using: keySym)
        return Data(signature)
        #else
        return Data()
        #endif
    }
    
    private func receiveAmazonMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            case .success(let message):
                Task { @MainActor in
                    switch message {
                    case .data(let data):
                        self.handleAmazonResponse(data: data)
                    case .string(let text):
                        self.handleAmazonResponse(text: text)
                    @unknown default:
                        break
                    }
                    self.receiveAmazonMessages()
                }
            }
        }
    }


    private func handleAmazonResponse(data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            handleAmazonResponse(text: text)
        }
    }

    private func handleAmazonResponse(text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let message = try? JSONDecoder().decode(TranscribeMessage.self, from: data) else {
            return
        }

        guard let result = message.transcript.results.first,
              let alt = result.alternatives.first else { return }

        let snippet = alt.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else { return }

        DispatchQueue.main.async {
            if result.isPartial == false {
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
        }
    }
#endif // canImport(AVFoundation)
    
    /// Highlight any filler words found in `text` and update ``fillerWordCount``.
    ///
    /// Made internal for unit testing so that tests can verify the filler word
    /// detection logic without needing to record audio or parse a full
    /// service response.
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
        pastSessions.insert(session, at: 0)
        saveSessions()
        sessionStart = nil
    }
    
    // MARK: - Amazon Transcribe Response Models

    struct TranscribeMessage: Codable {
        let transcript: Transcript

        enum CodingKeys: String, CodingKey {
            case transcript = "Transcript"
        }
    }

    struct Transcript: Codable {
        let results: [TranscriptResult]

        enum CodingKeys: String, CodingKey {
            case results = "Results"
        }
    }

    struct TranscriptResult: Codable {
        let alternatives: [TranscriptAlternative]
        let isPartial: Bool

        enum CodingKeys: String, CodingKey {
            case alternatives = "Alternatives"
            case isPartial = "IsPartial"
        }
    }

    struct TranscriptAlternative: Codable {
        let transcript: String

        enum CodingKeys: String, CodingKey {
            case transcript = "Transcript"
        }
    }
    
    // MARK: - Practice Session Model
    
    struct PracticeSession: Identifiable, Codable {
        let id: UUID = UUID()
        let transcript: String
        let fillerWordCount: Int
        let duration: TimeInterval
        let date: Date
    }
}
