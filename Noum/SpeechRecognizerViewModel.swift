//
//  SpeechRecognizerViewModel.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

import SwiftUI
import AVFoundation
import Speech
import Combine
import UIKit

class SpeechRecognizerViewModel: ObservableObject {
    // Published properties to update the UI
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    @Published var highlightedText: AttributedString = AttributedString("")
    
    // List of filler words
    private let fillerWords = ["um", "uh", "er", "eh", "ah", "like", "so", "you know"]

    // Precompiled regexes for fast filler word detection
    private lazy var fillerWordRegexes: [NSRegularExpression] = {
        fillerWords.compactMap { filler in
            let escaped = NSRegularExpression.escapedPattern(for: filler)
            let pattern = #"(?i)(?<!\w)\#(escaped)(?=\b|[^\w]|$)"#
            return try? NSRegularExpression(pattern: pattern)
        }
    }()
    
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        // Use the desired locale (en-US as an example)
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        requestSpeechAndRecordAuthorization()
    }

    // MARK: - Request Authorization
    private func requestSpeechAndRecordAuthorization() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { speechAuthStatus in
            DispatchQueue.main.async {
                switch speechAuthStatus {
                case .authorized:
                    print("Speech recognition authorized.")
                case .denied:
                    print("Speech recognition authorization denied.")
                case .restricted:
                    print("Speech recognition restricted on this device.")
                case .notDetermined:
                    print("Speech recognition not determined.")
                @unknown default:
                    print("Unknown speech recognition authorization state.")
                }
            }
        }

        // Request microphone permission
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
    
    // MARK: - Start Recording
    
    func startRecording() {
        // 1. If audio engine is running, stop it and remove old tap
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 2. Cancel any previous recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 3. Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
            return
        }
        
        // 4. Create a new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            print("Unable to create SFSpeechAudioBufferRecognitionRequest.")
            return
        }

        request.shouldReportPartialResults = true
        request.contextualStrings = fillerWords
        if #available(iOS 13.0, *) {
            request.taskHint = .dictation
            request.requiresOnDeviceRecognition = false
        }

        // 5. Create a new recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let bestString = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.updateTranscription(with: bestString)
                }
            }
            
            if let error = error {
                print("Recognition error: \(error.localizedDescription)")
            }
            
            if error != nil || (result?.isFinal ?? false) {
                // Stop audio engine and remove tap
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        // 6. Install a tap on the audio engine’s input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        // 7. Start the audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("Recording started...")
        } catch {
            print("Audio engine couldn't start: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Stop Recording
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask = nil
        highlightAndCountFillerWords(in: transcribedText)
        print("Recording stopped.")
        print("Final transcript: \(transcribedText)")
        print("Total filler words: \(fillerWordCount)")
    }
    
    // MARK: - Update Transcription and Highlight Filler Words

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


