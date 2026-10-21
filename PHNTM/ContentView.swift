import SwiftUI
import AppKit

struct ContentView: View {

    // MARK: - State

    @EnvironmentObject private var appController: AppController
    @AppStorage(AppStorageKeys.completedOnboarding)
    private var completedOnboarding = false

    private var camera: CameraManager { appController.camera }
    private var directionGesture: DirectionGestureEngine {
        appController.directionGesture
    }
    private var brightnessGesture: BrightnessGestureEngine {
        appController.brightnessGesture
    }
    private var browserTabs: BrowserTabController { appController.browserTabs }

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

    private var openPalmCount: Int {
        camera.hands.filter(GestureClassifier.isOpenPalm).count
    }

    private var fistCount: Int {
        camera.hands.filter(GestureClassifier.isFist).count
    }

    private var isGestureReady: Bool {
        twoHandGesture != nil || brightnessGesture.phase.isEngaged
    }

    private var brightnessInstruction: String {
        switch brightnessGesture.phase {
        case .idle:
            return "SHOW TWO OPEN PALMS"
        case .arming:
            return "HOLD BOTH PALMS"
        case .readyToClose:
            return "CLOSE BOTH HANDS"
        case .closing:
            return "HOLD BOTH FISTS"
        case .waitingForRelease:
            return "RELEASE TO REARM"
        }
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

                Button {
                    completedOnboarding = false
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("Open Setup Guide")

                Circle()
                    .fill(
                        isGestureReady
                            ? Color.green
                            : Color.gray
                    )
                    .frame(width: 8, height: 8)

                Text(
                    isGestureReady
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

            // MARK: Brightness Gesture Status

            HStack(spacing: 8) {
                Circle()
                    .fill(
                        brightnessGesture.phase.isEngaged
                            ? Color.orange
                            : Color.gray
                    )
                    .frame(width: 8, height: 8)

                Text(brightnessInstruction)
                    .font(.system(.caption, design: .monospaced))

                Spacer()

                Text(
                    brightnessGesture.lastEvent == .dimDisplay
                        ? "DISPLAY DIMMED"
                        : "\(openPalmCount)/2 PALMS   \(fistCount)/2 FISTS"
                )
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(
                    brightnessGesture.lastEvent == nil
                        ? Color.secondary
                        : Color.orange
                )
            }

            // MARK: Browser Control

            Divider()

            HStack(spacing: 12) {
                Toggle(
                    "Control Safari",
                    isOn: $appController.browserControlEnabled
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
                    appController.browserControlEnabled
                        ? browserTabs.statusText
                        : "Safari control is off; brightness gesture stays active"
                )
                .foregroundStyle(Color.secondary)

                Spacer()

                Text("☀ TWO PALMS → FISTS")
                    .foregroundStyle(Color.secondary)
            }
            .font(.system(.caption, design: .monospaced))

            // MARK: Camera Control

            Button(
                appController.isTracking
                    ? "Stop Camera"
                    : "Start Camera"
            ) {
                appController.toggleCamera()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 560)

        .onAppear {
            appController.refreshPermissions()
        }
        .sheet(isPresented: onboardingPresentation) {
            OnboardingView(
                camera: camera,
                browserTabs: browserTabs
            ) {
                appController.completeOnboarding()
                completedOnboarding = true
            }
        }
    }

    private var onboardingPresentation: Binding<Bool> {
        Binding(
            get: { !completedOnboarding },
            set: { isPresented in
                if !isPresented {
                    completedOnboarding = true
                }
            }
        )
    }
}
