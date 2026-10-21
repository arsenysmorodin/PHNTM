
import Foundation
import Combine
import AVFoundation
import Vision

@MainActor
final class CameraManager: NSObject,
                           ObservableObject,
                           AVCaptureVideoDataOutputSampleBufferDelegate,
                           @unchecked Sendable {

    nonisolated(unsafe) let session = AVCaptureSession()

    @Published private(set) var hands: [[CGPoint?]] = []

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
        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            startSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.startSession()
                } else {
                    print("PHNTM: Camera access denied")
                }
            }

        default:
            print("PHNTM: Camera permission unavailable")
        }
    }

    nonisolated private func startSession() {
        sessionQueue.async {

            if !self.isConfigured {
                guard let camera = AVCaptureDevice.default(for: .video) else {
                    print("PHNTM: No camera found")
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: camera)

                    self.session.beginConfiguration()
                    defer { self.session.commitConfiguration() }

                    self.session.sessionPreset = .medium

                    guard self.session.canAddInput(input) else {
                        print("PHNTM: Cannot add camera input")
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
                        return
                    }

                    self.session.addOutput(self.videoOutput)
                    self.isConfigured = true

                } catch {
                    print("PHNTM: Camera setup failed: \(error)")
                    return
                }
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
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

        } catch {
            print("PHNTM: Vision error: \(error)")
            publishHands([])
        }
    }

    nonisolated private func publishHands(_ hands: [[CGPoint?]]) {
        DispatchQueue.main.async { @MainActor [weak self] in
            self?.hands = hands
        }
    }
}
