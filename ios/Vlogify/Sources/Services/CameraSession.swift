import AVFoundation
import Observation
import UIKit
import os

/// The capture pipeline, and nothing else: no UI, no rules. `record(maxSeconds:)`
/// returns a file URL and the caller decides what it is.
///
/// In the simulator there is no camera. Rather than a black screen, `isSimulated` is
/// true, the preview shows a placeholder, and "recording" copies the bundled sample
/// clip -- so every screen after the shutter is still reachable by the walker.
@MainActor
@Observable
final class CameraSession {
    enum Position { case front, back }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.matthewpark.vlogify.camera")
    private let output = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private let logger = Logger(subsystem: "com.matthewpark.vlogify", category: "camera")

    var position: Position = .front
    var isTorchOn = false
    var isRunning = false
    var isRecording = false
    /// Physical orientation, for the hour stamp and the rotate hint. The UI itself
    /// never rotates.
    var deviceOrientation: UIDeviceOrientation = .portrait

    #if targetEnvironment(simulator)
    let isSimulated = true
    #else
    let isSimulated = LaunchArguments.isUITesting
    #endif

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                let orientation = UIDevice.current.orientation
                guard orientation.isPortrait || orientation.isLandscape else { return }
                self?.deviceOrientation = orientation
            }
        }
    }

    var isLandscape: Bool { deviceOrientation.isLandscape }

    func start() async {
        guard !isSimulated, !isRunning else { isRunning = true; return }
        await configureIfNeeded()
        let session = session
        await withCheckedContinuation { continuation in
            queue.async {
                if !session.isRunning { session.startRunning() }
                continuation.resume()
            }
        }
        isRunning = true
    }

    func stop() {
        guard !isSimulated else { isRunning = false; return }
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
        isRunning = false
    }

    private var configured = false

    private func configureIfNeeded() async {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .high
        if let audio = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: audio), session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        attachVideoInput()
    }

    private func attachVideoInput() {
        session.beginConfiguration()
        if let videoInput { session.removeInput(videoInput) }
        let avPosition: AVCaptureDevice.Position = position == .front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            session.commitConfiguration()
            logger.error("no camera for \(String(describing: self.position))")
            return
        }
        session.addInput(input)
        videoInput = input
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        if let connection = output.connection(with: .video) {
            connection.isVideoMirrored = avPosition == .front
        }
        session.commitConfiguration()
    }

    func flip() {
        position = position == .front ? .back : .front
        isTorchOn = false
        guard !isSimulated else { return }
        queue.async { [self] in
            Task { @MainActor in self.attachVideoInput() }
        }
    }

    func toggleTorch() {
        isTorchOn.toggle()
        guard !isSimulated, let device = videoInput?.device, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = isTorchOn ? .on : .off
        device.unlockForConfiguration()
    }

    /// Records to a temporary file. `maxSeconds` nil means until `stopRecording()`.
    func record(maxSeconds: Double?) async throws -> URL {
        isRecording = true
        defer { isRecording = false }
        if isSimulated {
            try await Task.sleep(for: .seconds(min(maxSeconds ?? 2, 2)))
            guard let sample = SampleClip.url else { throw CameraError.noSample }
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("rec-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: sample, to: copy)
            return copy
        }
        // Record along the long edge of the phone: a turned phone makes a landscape
        // clip, an upright one a portrait clip. The preview never rotates.
        if let connection = output.connection(with: .video), let coordinator = rotationCoordinator {
            connection.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelCapture
        }
        if let maxSeconds {
            output.maxRecordedDuration = CMTime(seconds: maxSeconds, preferredTimescale: 600)
        } else {
            output.maxRecordedDuration = .invalid
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec-\(UUID().uuidString).mov")
        let delegate = RecordingDelegate()
        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            output.startRecording(to: url, recordingDelegate: delegate)
            self.activeDelegate = delegate
        }
    }

    private var activeDelegate: RecordingDelegate?

    func stopRecording() {
        guard !isSimulated else { return }
        output.stopRecording()
    }
}

enum CameraError: Error {
    case noSample
    case recordingFailed
}

/// Bridges the delegate callback to async. `maxRecordedDuration` being hit arrives as
/// an error with `AVErrorRecordingSuccessfullyFinishedKey` true, which is a success.
private final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    var continuation: CheckedContinuation<URL, Error>?

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        if let error, (error as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool != true {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: outputFileURL)
        }
        continuation = nil
    }
}
