
import Foundation
import Combine
import AVFoundation
import AppKit
import Vision

@MainActor
final class CameraManager: NSObject,
                           ObservableObject,
                           AVCaptureVideoDataOutputSampleBufferDelegate,
                           @unchecked Sendable {

    nonisolated(unsafe) let session = AVCaptureSession()

    @Published private(set) var hands: [[CGPoint?]] = []
    @Published private(set) var authorizationStatus =
        AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var errorMessage: String?

    var hasCameraPermission: Bool {
        authorizationStatus == .authorized
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestPermission() {
        refreshAuthorizationStatus()

        guard authorizationStatus == .notDetermined else {
            if authorizationStatus != .authorized {
                openPrivacySettings()
            }
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            self?.publishAuthorizationStatus()

            if !granted {
                self?.publishError("Camera access was denied.")
            }
        }
    }

    func openPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private let sessionQueue = DispatchQueue(
        label: "com.phntm.camera.session"
    )

    private let frameQueue = DispatchQueue(
        label: "com.phntm.camera.frames"
    )

    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let handRequest = VNDetectHumanHandPoseRequest()

    // Доступ только из sessionQueue
    nonisolated(unsafe) private var isConfigured = false

    // Доступ только из frameQueue
    nonisolated(unsafe) private var lastAnalysisTime: TimeInterval = 0

    override init() {
        super.init()
        handRequest.maximumHandCount = 2
    }

    func start() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {

        case .authorized:
            errorMessage = nil
            startSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                self?.publishAuthorizationStatus()

                if granted {
                    self?.startSession()
                } else {
                    print("PHNTM: Camera access denied")
                    self?.publishError("Camera access was denied.")
                }
            }

        default:
            print("PHNTM: Camera permission unavailable")
            errorMessage = "Camera permission is unavailable."
        }
    }

    nonisolated private func startSession() {
        sessionQueue.async {

            if !self.isConfigured {
                guard let camera = AVCaptureDevice.default(for: .video) else {
                    print("PHNTM: No camera found")
                    self.publishError("No camera was found.")
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: camera)

                    self.session.beginConfiguration()
                    defer { self.session.commitConfiguration() }

                    self.session.sessionPreset = .medium

                    guard self.session.canAddInput(input) else {
                        print("PHNTM: Cannot add camera input")
                        self.publishError("The camera input could not be added.")
                        return
                    }

                    self.session.addInput(input)

                    self.videoOutput.alwaysDiscardsLateVideoFrames = true

                    self.videoOutput.setSampleBufferDelegate(
                        self,
                        queue: self.frameQueue
                    )

                    guard self.session.canAddOutput(self.videoOutput) else {
                        self.session.removeInput(input)
                        print("PHNTM: Cannot add video output")
                        self.publishError("The camera output could not be added.")
                        return
                    }

                    self.session.addOutput(self.videoOutput)
                    self.isConfigured = true

                } catch {
                    print("PHNTM: Camera setup failed: \(error)")
                    self.publishError("Camera setup failed: \(error.localizedDescription)")
                    return
                }
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            self.publishError(nil)
        }
    }

    nonisolated func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }

            DispatchQueue.main.async {
                self.hands = []
            }
        }
    }

    // MARK: - Frame Processing

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Ограничиваем анализ примерно 12 кадрами/с.
        let now = Date.timeIntervalSinceReferenceDate

        guard now - lastAnalysisTime >= 1.0 / 12.0 else {
            return
        }

        lastAnalysisTime = now

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([handRequest])

            let joints: [VNHumanHandPoseObservation.JointName] = [
                .wrist,
                .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                .indexMCP, .indexPIP, .indexDIP, .indexTip,
                .middleMCP, .middlePIP, .middleDIP, .middleTip,
                .ringMCP, .ringPIP, .ringDIP, .ringTip,
                .littleMCP, .littlePIP, .littleDIP, .littleTip
            ]

            guard let observations = handRequest.results else {
                publishHands([])
                return
            }

            let hands: [[CGPoint?]] = observations.map { hand in
                joints.map { joint -> CGPoint? in
                    guard let point = try? hand.recognizedPoint(
                        forKey: joint.rawValue
                    ),
                          point.confidence > 0.3 else {
                        return nil
                    }

                    return point.location
                }
            }

            publishHands(hands)
            publishError(nil)

        } catch {
            print("PHNTM: Vision error: \(error)")
            publishHands([])
            publishError("Hand recognition failed: \(error.localizedDescription)")
        }
    }

    nonisolated private func publishAuthorizationStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        DispatchQueue.main.async { @MainActor [weak self] in
            self?.authorizationStatus = status
        }
    }

    nonisolated private func publishError(_ message: String?) {
        DispatchQueue.main.async { @MainActor [weak self] in
            self?.errorMessage = message
        }
    }

    nonisolated private func publishHands(_ hands: [[CGPoint?]]) {
        DispatchQueue.main.async { @MainActor [weak self] in
            self?.hands = hands
        }
    }
}
