//
//  SpeechRecognizerViewModel.swift
//  YourApp
//
//  Created by You on today's date.
//

import SwiftUI
import AVFoundation
import Speech
import Combine

class SpeechRecognizerViewModel: ObservableObject {
    // Published properties to update the UI
    @Published var transcribedText: String = ""
    @Published var fillerWordCount: Int = 0
    
    // List of filler words
    private let fillerWords = ["um", "uh", "like", "so", "you know", "er", "ah"]
    
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        // Use the desired locale (en-US as an example)
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        requestSpeechAuthorization()
    }
    
    // MARK: - Request Authorization
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
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
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create SFSpeechAudioBufferRecognitionRequest.")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 5. Create a new recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let bestString = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = bestString
                    self.countFillerWords(in: bestString)
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
            recognitionRequest.append(buffer)
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
        recognitionTask?.cancel()
        recognitionTask = nil
        print("Recording stopped.")
    }
    
    // MARK: - Count Filler Words
    
    private func countFillerWords(in text: String) {
        // Reset for this demonstration (or keep a rolling total)
        fillerWordCount = 0
        
        let lowerText = text.lowercased()
        for filler in fillerWords {
            let occurrences = lowerText.components(separatedBy: filler).count - 1
            if occurrences > 0 {
                fillerWordCount += occurrences
            }
        }
    }
}

