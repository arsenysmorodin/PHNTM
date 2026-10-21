import SwiftUI
import AppKit

struct ContentView: View {

    // MARK: - State

    @StateObject private var camera = CameraManager()
    @StateObject private var directionGesture = DirectionGestureEngine()
    @StateObject private var browserTabs = BrowserTabController()

    @State private var isTracking = false
    @AppStorage("browserControlEnabled")
    private var browserControlEnabled = false

    // MARK: - Computed Properties

    private var detectedHandsCount: Int {
        camera.hands.filter { hand in
            hand.contains { $0 != nil }
        }.count
    }

    private var hasOpenPalmHand: Bool {
        camera.hands.contains(where: GestureClassifier.isOpenPalm)
    }

    private var hasGestureHand: Bool {
        camera.hands.contains(where: GestureClassifier.isPointing)
    }

    private var twoHandGesture: TwoHandGesture? {
        GestureClassifier.twoHandGesture(in: camera.hands)
    }

    private var detectedPointsCount: Int {
        camera.hands
            .flatMap { $0 }
            .compactMap { $0 }
            .count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {

            // MARK: Header

            HStack {
                Text("PHNTM")
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Circle()
                    .fill(
                        twoHandGesture != nil
                            ? Color.green
                            : Color.gray
                    )
                    .frame(width: 8, height: 8)

                Text(
                    twoHandGesture != nil
                        ? "READY"
                        : "WAITING"
                )
                .font(.caption)
                .foregroundStyle(Color.secondary)
            }

            // MARK: Camera Preview

            CameraPreview(
                session: camera.session,
                hands: camera.hands
            )
            .frame(height: 320)
            .clipShape(
                RoundedRectangle(cornerRadius: 12)
            )
            .background(Color.black)

            // MARK: Vision Status

            HStack {
                Text(
                    detectedHandsCount == 2
                        ? "TWO HANDS DETECTED"
                        : "SHOW TWO HANDS"
                )
                .foregroundStyle(
                    detectedHandsCount == 2
                        ? Color.green
                        : Color.secondary
                )

                Spacer()

                Text("\(detectedPointsCount) / 42 POINTS")
                    .foregroundStyle(Color.secondary)
            }
            .font(.system(.caption, design: .monospaced))

            // MARK: Open Palm Status

            HStack(spacing: 8) {
                Circle()
                    .fill(
                        hasOpenPalmHand
                            ? Color.green
                            : Color.gray
                    )
                    .frame(width: 8, height: 8)

                Text(
                    hasOpenPalmHand
                        ? "OPEN PALM READY"
                        : "SHOW OPEN PALM"
                )
                .font(.caption)

                Spacer()

                Text("KEEP SECOND HAND OPEN")
                    .font(
                        .system(
                            .caption,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(Color.secondary)
            }

            // MARK: Directional Gesture Status

            HStack(spacing: 8) {
                Circle()
                    .fill(
                        hasGestureHand
                            ? Color.cyan
                            : Color.gray
                    )
                    .frame(width: 8, height: 8)

                Text(
                    hasGestureHand
                        ? "GESTURE HAND READY"
                        : "SHOW POINTING HAND"
                )
                .font(
                    .system(
                        .caption,
                        design: .monospaced
                    )
                )

                Spacer()

                Text(
                    directionGesture.lastEvent?.rawValue ?? "NO GESTURE"
                )
                .font(
                    .system(
                        .caption,
                        design: .monospaced
                    )
                )
                .foregroundStyle(
                    directionGesture.lastEvent == nil
                        ? Color.secondary
                        : Color.cyan
                )
                .animation(
                    .easeOut(duration: 0.15),
                    value: directionGesture.lastEvent
                )
            }

            // MARK: Browser Control

            Divider()

            HStack(spacing: 12) {
                Toggle(
                    "Control Safari",
                    isOn: $browserControlEnabled
                )

                Spacer()

                if browserTabs.hasInputControlPermission {
                    Label("ACCESS GRANTED", systemImage: "checkmark.shield")
                        .foregroundStyle(Color.green)
                } else {
                    Button("Grant Accessibility") {
                        browserTabs.requestAccessibilityPermission()
                    }
                }
            }
            .font(.caption)

            HStack {
                Text(
                    browserControlEnabled
                        ? browserTabs.statusText
                        : "Safari control is off"
                )
                .foregroundStyle(Color.secondary)

                Spacer()

                Text("← PREVIOUS   ↑ SCROLL DOWN   ↓ SCROLL UP   NEXT →")
                    .foregroundStyle(Color.secondary)
            }
            .font(.system(.caption, design: .monospaced))

            // MARK: Camera Control

            Button(
                isTracking
                    ? "Stop Camera"
                    : "Start Camera"
            ) {
                toggleCamera()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 560)

        // MARK: Frame Processing

        .onReceive(camera.$hands) { hands in
            guard isTracking else { return }

            let isGuardPresent = hands.contains(
                where: GestureClassifier.isOpenPalm
            )
            let pointingHand = hands.first(
                where: GestureClassifier.isPointing
            ) ?? []

            if let event = directionGesture.process(
                landmarks: pointingHand,
                isGuardPresent: isGuardPresent
            ) {
                print("PHNTM: \(event.rawValue)")

                if browserControlEnabled {
                    _ = browserTabs.perform(event)
                }
            }
        }
        .onChange(of: browserControlEnabled) { _, enabled in
            browserTabs.setEnabled(enabled)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            browserTabs.refreshPermissionStatus()
        }
        .onDisappear {
            camera.stop()
            directionGesture.reset()
            isTracking = false
        }
    }

    // MARK: - Camera Control

    private func toggleCamera() {
        if isTracking {
            camera.stop()
            isTracking = false
        } else {
            isTracking = true
            camera.start()
        }

        directionGesture.reset()
    }
}
