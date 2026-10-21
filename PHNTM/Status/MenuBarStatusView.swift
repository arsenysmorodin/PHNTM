import SwiftUI
import AppKit

struct MenuBarStatusView: View {

    @EnvironmentObject private var appStatus: AppStatusStore
    @Environment(\.openWindow) private var openWindow

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

            Button("Open PHNTM") {
                openWindow(id: "main")
                NSApplication.shared.activate()
            }

            Button("Quit PHNTM") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
