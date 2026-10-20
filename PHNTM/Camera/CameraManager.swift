
import Foundation
import Combine
import AVFoundation
import Vision

final class CameraManager: NSObject,
                           ObservableObject,
                           AVCaptureVideoDataOutputSampleBufferDelegate,
                           @unchecked Sendable {

    let session = AVCaptureSession()

    @Published private(set) var landmarks: [CGPoint?] = []

    private let sessionQueue = DispatchQueue(
        label: "com.phntm.camera.session"
    )

    private let frameQueue = DispatchQueue(
        label: "com.phntm.camera.frames"
    )

    private let videoOutput = AVCaptureVideoDataOutput()
    private let handRequest = VNDetectHumanHandPoseRequest()

    // Доступ только из sessionQueue
    private var isConfigured = false

    // Доступ только из frameQueue
    private var lastAnalysisTime: TimeInterval = 0

    override init() {
        super.init()
        handRequest.maximumHandCount = 1
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

    private func startSession() {
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

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }

            DispatchQueue.main.async {
                self.landmarks = []
            }
        }
    }

    // MARK: - Frame Processing

    func captureOutput(
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

            guard let hand = handRequest.results?.first else {
                publishLandmarks([])
                return
            }

            let joints: [VNHumanHandPoseObservation.JointName] = [
                .wrist,
                .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                .indexMCP, .indexPIP, .indexDIP, .indexTip,
                .middleMCP, .middlePIP, .middleDIP, .middleTip,
                .ringMCP, .ringPIP, .ringDIP, .ringTip,
                .littleMCP, .littlePIP, .littleDIP, .littleTip
            ]

            let points: [CGPoint?] = joints.map { joint in
                guard let point = try? hand.recognizedPoint(joint),
                      point.confidence > 0.3 else {
                    return nil
                }

                return point.location
            }

            publishLandmarks(points)

        } catch {
            print("PHNTM: Vision error: \(error)")
            publishLandmarks([])
        }
    }

    private func publishLandmarks(_ points: [CGPoint?]) {
        DispatchQueue.main.async {
            self.landmarks = points
        }
    }
}
