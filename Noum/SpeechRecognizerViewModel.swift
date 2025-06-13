//
//  SpeechRecognizerViewModel.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

import SwiftUI
import AVFoundation
import UIKit

class SpeechRecognizerViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var highlightedText: AttributedString = AttributedString("")

#if canImport(WhisperKit)
    @Published var isWhisperReady: Bool = false
    @Published var whisperInitError: String?
#endif


    private let fillerWords = ["um", "uh", "er", "eh", "ah", "like", "so", "you know"]
    private lazy var fillerWordRegexes: [NSRegularExpression] = {
        fillerWords.compactMap { filler in
            let escaped = NSRegularExpression.escapedPattern(for: filler)
            let pattern = #"(?i)(?<!\w)\#(escaped)(?=\b|[^\w]|$)"#
            return try? NSRegularExpression(pattern: pattern)
        }
    }()

#if canImport(WhisperKit)
    private var whisperKit: WhisperKit?
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
#endif

    init() {
        requestRecordAuthorization()
#if canImport(WhisperKit)
        Task {
            do {
                self.whisperKit = try await WhisperKit()
                await MainActor.run { self.isWhisperReady = true }
            } catch {
                print("WhisperKit initialization failed: \(error)")
                await MainActor.run {
                    self.whisperInitError = error.localizedDescription
                    self.isWhisperReady = false
                }
            }
        }
#endif

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
    // MARK: - Recording

    func startRecording() {
#if canImport(WhisperKit)
        guard isWhisperReady else {
            print("WhisperKit not ready: \(whisperInitError ?? "unknown error")")
            return
        }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: .duckOthers)
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("whisper-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.record()
            audioFileURL = tempURL
            print("Whisper recording started...")
        } catch {
            print("Audio recorder setup failed: \(error.localizedDescription)")
        }
#endif
    }

    func stopRecording() {
#if canImport(WhisperKit)
        audioRecorder?.stop()
        guard isWhisperReady else {
            print("WhisperKit not ready: \(whisperInitError ?? "unknown error")")
            return
        }
        guard let url = audioFileURL else { return }

        Task {
            do {
                guard let whisper = whisperKit else {
                    print("WhisperKit not initialized")
                    return
                }
                let results = try await whisper.transcribe(audioPath: url.path)
                let text = results.map { $0.text }.joined(separator: " ")
                await MainActor.run {
                    self.updateTranscription(with: text)
                }
            } catch {
                print("Whisper transcription failed: \(error)")
            }
        }
        print("Recording stopped.")
#endif
    }

    // MARK: - Highlighting

    private func updateTranscription(with text: String) {
        transcribedText = text
        highlightAndCountFillerWords(in: text)
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
