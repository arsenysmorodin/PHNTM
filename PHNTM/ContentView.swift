import SwiftUI

struct ContentView: View {

    @StateObject private var camera = CameraManager()
    @StateObject private var activation = ActivationEngine()

    @State private var isTracking = false

    private var handDetected: Bool {
        camera.landmarks.contains { $0 != nil }
    }

    private var isOpenPalm: Bool {
        GestureClassifier.isOpenPalm(camera.landmarks)
    }

    var body: some View {
        VStack(spacing: 20) {

            // MARK: Header

            HStack {
                Text("PHNTM")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Circle()
                    .fill(activation.isActive ? .green : .gray)
                    .frame(width: 8, height: 8)

                Text(activation.isActive ? "ACTIVE" : "STANDBY")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: Camera

            CameraPreview(
                session: camera.session,
                landmarks: camera.landmarks
            )
            .frame(height: 320)
            .clipShape(
                RoundedRectangle(cornerRadius: 12)
            )
            .background(Color.black)

            // MARK: Vision Status

            HStack {
                Text(handDetected ? "HAND DETECTED" : "NO HAND")
                    .foregroundStyle(
                        handDetected ? .green : .secondary
                    )

                Spacer()

                Text(
                    "\(camera.landmarks.compactMap { $0 }.count) / 21 POINTS"
                )
                .foregroundStyle(.secondary)
            }
            .font(.system(.caption, design: .monospaced))

            // MARK: Gesture Status

            HStack(spacing: 8) {
                Circle()
                    .fill(isOpenPalm ? .green : .gray)
                    .frame(width: 8, height: 8)

                Text(isOpenPalm ? "OPEN PALM" : "NO GESTURE")
                    .font(.caption)

                Spacer()

                Text(activation.instruction)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // MARK: Activation Progress

            ProgressView(value: activation.progress)
                .tint(activation.isActive ? .green : .blue)

            // MARK: Camera Control

            Button(isTracking ? "Stop Camera" : "Start Camera") {
                if isTracking {
                    camera.stop()
                    activation.reset()
                } else {
                    activation.reset()
                    camera.start()
                }

                isTracking.toggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 560)

        // Получаем новые точки от CameraManager.
        // Классифицируем жест один раз на кадр.
        .onReceive(camera.$landmarks) { points in
            guard isTracking else { return }

            let openPalm = GestureClassifier.isOpenPalm(points)

            activation.process(isOpenPalm: openPalm)
        }

        .onDisappear {
            camera.stop()
            activation.reset()
            isTracking = false
        }
    }
}
