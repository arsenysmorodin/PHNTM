import AppKit
import AVFoundation
import SwiftUI

struct OnboardingView: View {

    @ObservedObject var camera: CameraManager
    @ObservedObject var browserTabs: BrowserTabController

    let onComplete: () -> Void

    @State private var step = 0

    private let stepTitles = [
        "Welcome",
        "Gestures",
        "Permissions"
    ]

    private var permissionsGranted: Bool {
        camera.hasCameraPermission && browserTabs.hasInputControlPermission
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0:
                        welcomeStep
                    case 1:
                        gesturesStep
                    default:
                        permissionsStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                navigation
            }
        }
        .frame(width: 760, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .interactiveDismissDisabled()
        .onAppear {
            camera.refreshAuthorizationStatus()
            browserTabs.refreshPermissionStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            camera.refreshAuthorizationStatus()
            browserTabs.refreshPermissionStatus()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PHNTM")
                        .font(.headline)
                    Text("SETUP")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(stepTitles.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(stepColor(for: index).opacity(0.16))

                            if index < step {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .foregroundStyle(stepColor(for: index))
                        .frame(width: 26, height: 26)

                        Text(stepTitles[index])
                            .font(.subheadline.weight(
                                index == step ? .semibold : .regular
                            ))
                            .foregroundStyle(
                                index <= step ? .primary : .secondary
                            )
                    }
                }
            }

            Spacer()

            Label("Hand data stays on this Mac", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 224)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var welcomeStep: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 116, height: 116)
                .shadow(color: .cyan.opacity(0.18), radius: 24, y: 8)

            VStack(spacing: 8) {
                Text("Control Safari with a gesture")
                    .font(.system(size: 28, weight: .bold))

                Text("PHNTM recognizes two static hand poses and turns them into\nSafari tab and page controls. No swiping required.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            HStack(spacing: 18) {
                featureLabel("On-device", icon: "cpu")
                featureLabel("No recordings", icon: "video.slash")
                featureLabel("Safari only", icon: "safari")
            }

            Spacer()
        }
        .padding(40)
    }

    private var gesturesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Two hands. One deliberate command.")
                    .font(.system(size: 24, weight: .bold))
                Text("Keep one hand open as a safety signal. Hold a pointing gesture with the other hand.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 16) {
                gestureCard(
                    title: "Safety hand",
                    detail: "Hold an open palm",
                    symbol: "hand.raised.fill",
                    color: .green
                )

                Image(systemName: "plus")
                    .foregroundStyle(.secondary)

                gestureCard(
                    title: "Command hand",
                    detail: "Point in one direction",
                    symbol: "hand.point.up.left.fill",
                    color: .cyan
                )
            }

            VStack(spacing: 0) {
                actionRow("arrow.left", title: "Left", action: "Previous Safari tab")
                Divider()
                actionRow("arrow.right", title: "Right", action: "Next Safari tab")
                Divider()
                actionRow("arrow.up", title: "Up", action: "Scroll the page down")
                Divider()
                actionRow("arrow.down", title: "Down", action: "Scroll the page up")
            }
            .padding(.horizontal, 16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Safari must be the frontmost app. PHNTM waits for a new pose before repeating a command.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Allow two permissions")
                    .font(.system(size: 26, weight: .bold))
                Text("PHNTM needs the camera to see hand poses and Accessibility to send commands to Safari.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                PermissionRow(
                    title: "Camera",
                    detail: cameraPermissionDetail,
                    symbol: "camera.fill",
                    isGranted: camera.hasCameraPermission,
                    buttonTitle: cameraPermissionButtonTitle,
                    action: requestCameraPermission
                )

                PermissionRow(
                    title: "Accessibility",
                    detail: browserTabs.hasInputControlPermission
                        ? "Allowed. Safari controls are ready."
                        : "Required to switch tabs and scroll in Safari.",
                    symbol: "accessibility",
                    isGranted: browserTabs.hasInputControlPermission,
                    buttonTitle: "Open Settings",
                    action: browserTabs.requestAccessibilityPermission
                )
            }

            if permissionsGranted {
                Label(
                    "PHNTM is ready. The camera will start when setup is complete.",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
                .font(.subheadline.weight(.medium))
            } else {
                Label(
                    "After changing a setting, return to PHNTM. This screen updates automatically.",
                    systemImage: "arrow.uturn.backward.circle"
                )
                .foregroundStyle(.secondary)
                .font(.caption)
            }

            Spacer()
        }
        .padding(36)
    }

    private var navigation: some View {
        HStack {
            if step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step -= 1
                    }
                }
            }

            Spacer()

            if step < stepTitles.count - 1 {
                Button("Continue") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Start Using PHNTM") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!permissionsGranted)
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 68)
    }

    private var cameraPermissionDetail: String {
        switch camera.authorizationStatus {
        case .authorized:
            return "Allowed. Processing stays on this Mac."
        case .notDetermined:
            return "Required to recognize your hands. Video never leaves this Mac."
        case .denied:
            return "Camera access is off. Enable PHNTM in System Settings."
        case .restricted:
            return "Camera access is restricted on this Mac."
        @unknown default:
            return "Camera access is unavailable."
        }
    }

    private var cameraPermissionButtonTitle: String {
        camera.authorizationStatus == .notDetermined
            ? "Allow Camera"
            : "Open Settings"
    }

    private func requestCameraPermission() {
        if camera.authorizationStatus == .notDetermined {
            camera.requestPermission()
        } else {
            camera.openPrivacySettings()
        }
    }

    private func stepColor(for index: Int) -> Color {
        if index < step {
            return .green
        }

        return index == step ? .accentColor : .secondary
    }

    private func featureLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(Capsule())
    }

    private func gestureCard(
        title: String,
        detail: String,
        symbol: String,
        color: Color
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 32))
                .foregroundStyle(color)

            VStack(spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func actionRow(
        _ symbol: String,
        title: String,
        action: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .fontWeight(.medium)
                .frame(width: 52, alignment: .leading)
            Text(action)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.subheadline)
        .frame(height: 34)
    }
}

private struct PermissionRow: View {

    let title: String
    let detail: String
    let symbol: String
    let isGranted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isGranted ? Color.green : Color.accentColor)
                .frame(width: 42, height: 42)
                .background(
                    (isGranted ? Color.green : Color.accentColor)
                        .opacity(0.10)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button(buttonTitle, action: action)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
