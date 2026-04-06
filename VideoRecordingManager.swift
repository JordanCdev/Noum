import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVKit)
import AVKit
#endif

#if canImport(AVFoundation) && canImport(UIKit)

// MARK: - Video Recording Manager

@MainActor
final class VideoRecordingManager: NSObject, ObservableObject {
    static let shared = VideoRecordingManager()

    @Published private(set) var isRecording = false
    @Published private(set) var recordingURL: URL?
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var recordingError: String?

    private(set) var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var durationTimer: Task<Void, Never>?

    private override init() {
        super.init()
    }

    // MARK: - Session Setup

    func prepareSession() async -> Bool {
        guard captureSession == nil else { return true }

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        // Front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(videoInput) else {
            recordingError = "Camera unavailable"
            return false
        }
        session.addInput(videoInput)

        // Microphone (optional — audio is also captured by speech recognizer, but we want it in the video)
        if let mic = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Movie output
        let output = AVCaptureMovieFileOutput()
        output.maxRecordedDuration = CMTime(seconds: 180, preferredTimescale: 600) // 3 min max
        guard session.canAddOutput(output) else {
            recordingError = "Could not configure recording"
            return false
        }
        session.addOutput(output)

        captureSession = session
        movieOutput = output

        return true
    }

    // MARK: - Start / Stop

    func startRecording() {
        guard let session = captureSession, let output = movieOutput else {
            recordingError = "Recording not prepared"
            return
        }

        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        let filename = "noum_session_\(Int(Date().timeIntervalSince1970)).mov"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        // Small delay to ensure session is running
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            output.startRecording(to: url, recordingDelegate: self)
            await MainActor.run {
                isRecording = true
                recordingDuration = 0
                recordingURL = nil
                startDurationTimer()
            }
        }
    }

    func stopRecording() {
        movieOutput?.stopRecording()
        durationTimer?.cancel()
        durationTimer = nil
        isRecording = false
    }

    /// Save the current recording to Documents for permanent storage
    @discardableResult
    func saveRecording() -> URL? {
        guard let sourceURL = recordingURL else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let savedDir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: savedDir, withIntermediateDirectories: true)
        let filename = "session-\(Int(Date().timeIntervalSince1970)).mov"
        let destURL = savedDir.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            savedRecordingURL = destURL
            return destURL
        } catch {
            recordingError = "Could not save recording: \(error.localizedDescription)"
            return nil
        }
    }

    @Published var savedRecordingURL: URL?

    func cleanup() {
        stopRecording()
        captureSession?.stopRunning()
        captureSession = nil
        movieOutput = nil
        // Clean up temp recording if not saved
        if let url = recordingURL, savedRecordingURL == nil {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        savedRecordingURL = nil
        recordingDuration = 0
    }

    // MARK: - Camera Preview Layer

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    // MARK: - Permission Check

    static func hasCameraPermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    static func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        durationTimer?.cancel()
        durationTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                await MainActor.run {
                    recordingDuration += 1
                }
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecordingManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            if let error {
                recordingError = "Recording failed: \(error.localizedDescription)"
            } else {
                recordingURL = outputFileURL
            }
            isRecording = false
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

@available(iOS 17.0, *)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.clipsToBounds = true

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)

        // Start the session on a background thread
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? CameraPreviewUIView {
            view.previewLayer?.frame = view.bounds
        }
    }

    class CameraPreviewUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

// MARK: - Video Playback View (for post-session review)

@available(iOS 17.0, *)
struct VideoPlaybackView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VideoPlayerRepresentable(url: url)
                .ignoresSafeArea()
                .navigationTitle("Session Recording")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

@available(iOS 17.0, *)
struct VideoPlayerRepresentable: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

#endif
