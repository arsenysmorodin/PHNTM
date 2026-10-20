
import SwiftUI

struct ContentView: View {

    @StateObject private var camera = CameraManager()
    @State private var isTracking = false

    private var handDetected: Bool {
        camera.landmarks.contains { $0 != nil }
    }
    
    private var isOpenPalm: Bool {
        GestureClassifier.isOpenPalm(camera.landmarks)
    }

    var body: some View {
        VStack(spacing: 20) {

            HStack {
                Text("PHNTM")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Circle()
                    .fill(handDetected ? .green : .gray)
                    .frame(width: 8, height: 8)

                Text(
                    handDetected
                        ? "HAND DETECTED"
                        : "NO HAND"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            CameraPreview(
                session: camera.session,
                landmarks: camera.landmarks
            )
            .frame(height: 320)
            .clipShape(
                RoundedRectangle(cornerRadius: 12)
            )
            .background(Color.black)

            HStack {
                Text("VISION TRACKING")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(camera.landmarks.compactMap { $0 }.count) / 21 POINTS")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(isOpenPalm ? .green : .gray)
                    .frame(width: 8, height: 8)

                Text(
                    isOpenPalm
                        ? "OPEN PALM DETECTED"
                        : "NO GESTURE"
                )
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(
                    isOpenPalm ? .green : .secondary
                )

                Spacer()
            }

            Button(isTracking ? "Stop Camera" : "Start Camera") {
                if isTracking {
                    camera.stop()
                } else {
                    camera.start()
                }

                isTracking.toggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 560)
        .onDisappear {
            camera.stop()
            isTracking = false
        }
    }
}
