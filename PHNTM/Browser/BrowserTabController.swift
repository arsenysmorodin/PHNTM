import AppKit
import Combine
import CoreGraphics

@MainActor
final class BrowserTabController: ObservableObject {

    @Published private(set) var hasInputControlPermission = false
    @Published private(set) var statusText = "Safari control is off"

    private let safariBundleIdentifier = "com.apple.Safari"
    private let pageUpKeyCode: CGKeyCode = 116
    private let pageDownKeyCode: CGKeyCode = 121

    init() {
        refreshPermissionStatus()
    }

    func refreshPermissionStatus() {
        hasInputControlPermission = CGPreflightPostEventAccess()

        if hasInputControlPermission {
            statusText = "Ready — gestures control frontmost Safari"
        } else {
            statusText = "Input control permission is required"
        }
    }

    func requestAccessibilityPermission() {
        _ = CGRequestPostEventAccess()
        refreshPermissionStatus()

        if !hasInputControlPermission {
            statusText = "Allow PHNTM in Accessibility, then return to the app"
            openAccessibilitySettings()
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled else {
            statusText = "Safari control is off"
            return
        }

        refreshPermissionStatus()
    }

    @discardableResult
    func perform(_ gesture: GestureDirection) -> Bool {
        refreshPermissionStatus()

        guard hasInputControlPermission else {
            statusText = "Gesture detected — grant Accessibility for Safari control"
            return false
        }

        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier,
              bundleIdentifier == safariBundleIdentifier,
              application.isActive,
              !application.isTerminated else {
            statusText = "Gesture detected — focus Safari"
            return false
        }

        switch gesture {
        case .left, .right:
            return switchTab(for: gesture, in: application)
        case .up, .down:
            return scrollPage(for: gesture, in: application)
        }
    }

    private func switchTab(
        for direction: GestureDirection,
        in application: NSRunningApplication
    ) -> Bool {
        // Safari handles Control-Tab independently of the current keyboard
        // layout.
        let flags: CGEventFlags = direction == .left
            ? [.maskControl, .maskShift]
            : [.maskControl]
        let action = direction == .left ? "previous" : "next"

        guard postShortcut(
            keyCode: 48,
            flags: flags,
            to: application.processIdentifier
        ) else {
            statusText = "Could not send the tab shortcut"
            return false
        }

        statusText = "Safari: \(action) tab"
        return true
    }

    private func scrollPage(
        for direction: GestureDirection,
        in application: NSRunningApplication
    ) -> Bool {
        // Match natural scrolling: an upward-pointing gesture moves the page
        // down, while a downward-pointing gesture moves it back up.
        let keyCode = direction == .up ? pageDownKeyCode : pageUpKeyCode
        let action = direction == .up ? "scroll down" : "scroll up"

        guard postShortcut(
            keyCode: keyCode,
            flags: [],
            to: application.processIdentifier
        ) else {
            statusText = "Could not send the scroll event"
            return false
        }

        statusText = "Safari: \(action)"
        return true
    }

    private func postShortcut(
        keyCode: CGKeyCode,
        flags: CGEventFlags,
        to processIdentifier: pid_t
    ) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyCode,
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyCode,
                keyDown: false
              ) else {
            return false
        }

        keyDown.flags = flags
        keyUp.flags = flags

        // Target the already verified frontmost Safari process directly. This avoids
        // losing the shortcut when focus changes between the check above and
        // posting into the global HID event stream.
        keyDown.postToPid(processIdentifier)
        keyUp.postToPid(processIdentifier)
        return true
    }
}
