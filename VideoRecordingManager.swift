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
#if canImport(Photos)
import Photos
#endif

#if canImport(AVFoundation) && canImport(UIKit)

enum VideoRecordingState: Equatable {
    case idle
    case preparing
    case ready
    case recording
    case finalizing
    case available(URL)
    case failed(String)
}

struct VideoRecordingLifecycle: Equatable {
    private(set) var state: VideoRecordingState = .idle
    private(set) var recordingURL: URL?
    private(set) var errorMessage: String?
    private(set) var savedRecordingURL: URL?

    mutating func beginPreparing() {
        state = .preparing
        errorMessage = nil
    }

    mutating func markReady() {
        state = .ready
        errorMessage = nil
    }

    mutating func startRecording() {
        state = .recording
        recordingURL = nil
        savedRecordingURL = nil
        errorMessage = nil
    }

    mutating func beginFinalizing() {
        state = .finalizing
    }

    mutating func complete(url: URL) {
        state = .available(url)
        recordingURL = url
        errorMessage = nil
    }

    mutating func fail(_ message: String) {
        state = .failed(message)
        recordingURL = nil
        errorMessage = message
    }

    mutating func markSaved(url: URL) {
        savedRecordingURL = url
    }

    mutating func cleanup() {
        state = .idle
        recordingURL = nil
        errorMessage = nil
        savedRecordingURL = nil
    }
}

// MARK: - Video Recording Manager

@MainActor
final class VideoRecordingManager: NSObject, ObservableObject {
    static let shared = VideoRecordingManager()

    @Published private(set) var isRecording = false
    @Published private(set) var recordingURL: URL?
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var recordingError: String?
    @Published private(set) var recordingState: VideoRecordingState = .idle

    @Published private(set) var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var durationTimer: Task<Void, Never>?
    private var recordingStartTask: Task<Void, Never>?
    private var lifecycle = VideoRecordingLifecycle()
    private var expectedRecordingURL: URL?

    private override init() {
        super.init()
    }

    // MARK: - Session Setup

    func prepareSession() async -> Bool {
        guard captureSession == nil else { return true }
        applyLifecycleUpdate { $0.beginPreparing() }

        let session = AVCaptureSession()
        session.sessionPreset = .medium

        // Front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(videoInput) else {
            applyLifecycleUpdate { $0.fail("Camera unavailable") }
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
            applyLifecycleUpdate { $0.fail("Could not configure recording") }
            return false
        }
        session.addOutput(output)

        movieOutput = output

        // Start the session on a background thread BEFORE publishing it.
        // This ensures the preview layer receives video frames immediately when
        // SwiftUI renders the CameraPreviewView, preventing the flash-then-disappear.
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                continuation.resume()
            }
        }

        captureSession = session
        applyLifecycleUpdate { $0.markReady() }

        return true
    }

    // MARK: - Camera Flip

    @Published private(set) var usingFrontCamera: Bool = true

    func flipCamera() {
        guard let session = captureSession else { return }

        // Find the current video input
        guard let currentInput = session.inputs
            .compactMap({ $0 as? AVCaptureDeviceInput })
            .first(where: { $0.device.hasMediaType(.video) }) else { return }

        let newPosition: AVCaptureDevice.Position = usingFrontCamera ? .back : .front
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newCamera) else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            usingFrontCamera = !usingFrontCamera
        } else {
            // Fallback: re-add original input
            session.addInput(currentInput)
        }
        session.commitConfiguration()
    }

    // MARK: - Start / Stop

    func startRecording() {
        guard !isRecording, recordingState != .finalizing else { return }
        guard let session = captureSession, let output = movieOutput else {
            applyLifecycleUpdate { $0.fail("Recording not prepared") }
            return
        }

        let filename = "noum_session_\(UUID().uuidString).mov"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        expectedRecordingURL = url
        applyLifecycleUpdate { $0.startRecording() }
        recordingDuration = 0
        isRecording = true

        // Ensure session is running, then begin recording on a background thread.
        // AVCaptureMovieFileOutput.startRecording must be called after the session
        // is actually running — we use a background dispatch to avoid blocking main.
        recordingStartTask?.cancel()
        recordingStartTask = Task.detached(priority: .userInitiated) {
            if !session.isRunning {
                session.startRunning()
            }
            // Brief yield to let the session stabilize
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let shouldStart = await MainActor.run {
                self.expectedRecordingURL == url && self.isRecording
            }
            guard shouldStart else { return }
            output.startRecording(to: url, recordingDelegate: self)
            await MainActor.run { [weak self] in
                guard self?.expectedRecordingURL == url else { return }
                self?.startDurationTimer()
            }
        }
    }

    func stopRecording() {
        guard isRecording || movieOutput?.isRecording == true else { return }
        recordingStartTask?.cancel()
        recordingStartTask = nil
        durationTimer?.cancel()
        durationTimer = nil
        isRecording = false
        if movieOutput?.isRecording == true {
            movieOutput?.stopRecording()
            applyLifecycleUpdate { $0.beginFinalizing() }
        } else {
            expectedRecordingURL = nil
            applyLifecycleUpdate { $0.fail("Recording stopped before video capture started.") }
        }
    }

    @Published private(set) var isSaving = false
    @Published var savedRecordingURL: URL?

    /// Save the current recording to the Photos library for permanent storage.
    func saveRecording() {
        guard let sourceURL = recordingURL else {
            applyLifecycleUpdate { $0.fail("No recording to save.") }
            return
        }
        guard !isSaving else { return }
        isSaving = true

        // Save to Photos library
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: sourceURL)
                    }) { success, error in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.isSaving = false
                            if success {
                                self.markRecordingSaved(at: sourceURL)
                            } else {
                                self.recordingError = "Could not save to Photos: \(error?.localizedDescription ?? "Unknown error")"
                            }
                        }
                    }
                } else {
                    // Fallback: save to Documents
                    self.isSaving = false
                    self.saveToDocuments(sourceURL: sourceURL)
                }
            }
        }
    }

    private func saveToDocuments(sourceURL: URL) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let savedDir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: savedDir, withIntermediateDirectories: true)
        let filename = "session-\(Int(Date().timeIntervalSince1970)).mov"
        let destURL = savedDir.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            markRecordingSaved(at: destURL)
        } catch {
            recordingError = "Could not save recording: \(error.localizedDescription)"
        }
    }

    func cleanup() {
        stopRecording()
        captureSession?.stopRunning()
        captureSession = nil
        movieOutput = nil
        recordingStartTask?.cancel()
        recordingStartTask = nil
        // Clean up temp recording if not saved
        if let url = recordingURL, savedRecordingURL == nil {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        savedRecordingURL = nil
        recordingDuration = 0
        expectedRecordingURL = nil
        applyLifecycleUpdate { $0.cleanup() }
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

    func waitForRecordingFinalization(timeout: TimeInterval = 2.0, pollInterval: TimeInterval = 0.1) async -> URL? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            switch recordingState {
            case .available(let url):
                return url
            case .failed:
                return nil
            case .idle, .preparing, .ready:
                if !isRecording { return recordingURL }
            case .recording, .finalizing:
                break
            }

            let nanoseconds = UInt64(max(0.01, pollInterval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }

        return recordingURL
    }

    private func applyLifecycleUpdate(_ update: (inout VideoRecordingLifecycle) -> Void) {
        update(&lifecycle)
        recordingState = lifecycle.state
        recordingURL = lifecycle.recordingURL
        recordingError = lifecycle.errorMessage
        savedRecordingURL = lifecycle.savedRecordingURL
    }

    private func markRecordingSaved(at url: URL) {
        applyLifecycleUpdate { $0.markSaved(url: url) }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecordingManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            guard expectedRecordingURL == outputFileURL else { return }
            expectedRecordingURL = nil
            recordingStartTask = nil

            if let error {
                // AVFoundation often reports a "stopped" error even when the file was written successfully.
                // Check if the file exists and has content before treating it as a real failure.
                let fileExists = FileManager.default.fileExists(atPath: outputFileURL.path)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)[.size] as? UInt64) ?? 0
                if fileExists && fileSize > 0 {
                    applyLifecycleUpdate { $0.complete(url: outputFileURL) }
                } else {
                    applyLifecycleUpdate { $0.fail("Recording failed: \(error.localizedDescription)") }
                }
            } else {
                applyLifecycleUpdate { $0.complete(url: outputFileURL) }
            }
            isRecording = false
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

/// A stable camera preview that survives SwiftUI re-renders.
/// The UIView is created once in `makeUIView` and reused; `updateUIView` handles
/// session swaps without recreating the preview layer, preventing flash/disappear artifacts.
@available(iOS 17.0, *)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        view.attachSession(session)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Only swap the layer's session if it actually changed (identity check)
        if uiView.previewLayer?.session !== session {
            uiView.attachSession(session)
        }
        // Ensure the layer fills the view on every layout pass
        uiView.previewLayer?.frame = uiView.bounds
    }

    class CameraPreviewUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        func attachSession(_ session: AVCaptureSession) {
            // Reuse existing layer when possible — just swap the session
            if let existing = previewLayer {
                existing.session = session
            } else {
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                self.layer.addSublayer(layer)
                previewLayer = layer
            }
            setNeedsLayout()
        }

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
