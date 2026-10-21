import SwiftUI
import AppKit

struct MenuBarStatusView: View {

    @EnvironmentObject private var appStatus: AppStatusStore
    @EnvironmentObject private var appController: AppController
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppStorageKeys.completedOnboarding)
    private var completedOnboarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                appStatus.status.title,
                systemImage: appStatus.status.symbolName
            )
            .font(.headline)

            Text(appStatus.status.detail)
                .font(.caption)
                .foregroundStyle(Color.secondary)

            Divider()

            Button(
                appController.isTracking ? "Stop Camera" : "Start Camera"
            ) {
                appController.toggleCamera()
            }

            Button("Open PHNTM") {
                openWindow(id: "main")
                NSApplication.shared.activate()
            }

            Button("Setup Guide…") {
                completedOnboarding = false
                openWindow(id: "main")
                NSApplication.shared.activate()
            }

            Divider()

            Button("Quit PHNTM") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
