
import SwiftUI
import AVFoundation
import AppKit

struct CameraPreview: NSViewRepresentable {

    let session: AVCaptureSession
    let landmarks: [CGPoint?]

    func makeNSView(context: Context) -> CameraPreviewView {
        CameraPreviewView(session: session)
    }

    func updateNSView(
        _ nsView: CameraPreviewView,
        context: Context
    ) {
        nsView.updateLandmarks(landmarks)
    }
}

final class CameraPreviewView: NSView {

    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let linesLayer = CAShapeLayer()
    private let pointsLayer = CAShapeLayer()

    private var landmarks: [CGPoint?] = []

    // Индексы суставов в массиве landmarks
    private let fingers: [[Int]] = [
        [0, 1, 2, 3, 4],
        [0, 5, 6, 7, 8],
        [0, 9, 10, 11, 12],
        [0, 13, 14, 15, 16],
        [0, 17, 18, 19, 20]
    ]

    init(session: AVCaptureSession) {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        linesLayer.strokeColor = NSColor.systemCyan.cgColor
        linesLayer.fillColor = nil
        linesLayer.lineWidth = 2

        pointsLayer.fillColor = NSColor.white.cgColor

        layer?.addSublayer(previewLayer)
        layer?.addSublayer(linesLayer)
        layer?.addSublayer(pointsLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()

        previewLayer.frame = bounds
        linesLayer.frame = bounds
        pointsLayer.frame = bounds

        drawSkeleton()
    }

    func updateLandmarks(_ newLandmarks: [CGPoint?]) {
        landmarks = newLandmarks
        drawSkeleton()
    }

    private func drawSkeleton() {
        let linePath = CGMutablePath()
        let pointPath = CGMutablePath()

        guard landmarks.count == 21 else {
            linesLayer.path = nil
            pointsLayer.path = nil
            return
        }

        // Vision: начало координат снизу слева.
        // AVFoundation: нормализованная точка отсчёта сверху слева.
        
        func convert(_ point: CGPoint) -> CGPoint {
            return previewLayer.layerPointConverted(
                fromCaptureDevicePoint: point
            )
        }


        // Соединяем суставы каждого пальца.
        for finger in fingers {
            for i in 1..<finger.count {
                let a = finger[i - 1]
                let b = finger[i]

                guard let start = landmarks[a],
                      let end = landmarks[b] else {
                    continue
                }

                linePath.move(to: convert(start))
                linePath.addLine(to: convert(end))
            }
        }

        // Отрисовываем распознанные суставы.
        for point in landmarks {
            guard let point else { continue }

            let position = convert(point)

            pointPath.addEllipse(
                in: CGRect(
                    x: position.x - 3.5,
                    y: position.y - 3.5,
                    width: 7,
                    height: 7
                )
            )
        }

        linesLayer.path = linePath
        pointsLayer.path = pointPath
    }
}
