import AppKit
import CoreGraphics
import Foundation

enum DisplayBrightnessError: LocalizedError {
    case accessibilityPermissionRequired
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Allow PHNTM in Accessibility to change display brightness."
        case .eventCreationFailed:
            return "PHNTM could not send the display brightness command."
        }
    }
}

@MainActor
final class DisplayBrightnessController {

    private enum MediaKey {
        // Values from IOKit hidsystem/ev_keymap.h.
        static let brightnessUp = 2
        static let brightnessDown = 3
    }

    private var isAdjusting = false

    func dimToNearMinimum() async throws {
        guard !isAdjusting else { return }
        guard CGPreflightPostEventAccess() else {
            throw DisplayBrightnessError.accessibilityPermissionRequired
        }

        isAdjusting = true
        defer { isAdjusting = false }

        // Drive the display to its lower bound first, then raise it by one
        // macOS brightness step so the screen stays visible.
        for _ in 0..<20 {
            guard postMediaKey(MediaKey.brightnessDown) else {
                throw DisplayBrightnessError.eventCreationFailed
            }
            try await Task.sleep(for: .milliseconds(18))
        }

        guard postMediaKey(MediaKey.brightnessUp) else {
            throw DisplayBrightnessError.eventCreationFailed
        }
    }

    private func postMediaKey(_ keyCode: Int) -> Bool {
        guard let keyDown = mediaKeyEvent(keyCode, isDown: true),
              let keyUp = mediaKeyEvent(keyCode, isDown: false),
              let keyDownEvent = keyDown.cgEvent,
              let keyUpEvent = keyUp.cgEvent else {
            return false
        }

        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
        return true
    }

    private func mediaKeyEvent(
        _ keyCode: Int,
        isDown: Bool
    ) -> NSEvent? {
        let keyState = isDown ? 0xA : 0xB
        let data = (keyCode << 16) | (keyState << 8)
        let flags = NSEvent.ModifierFlags(
            rawValue: UInt(isDown ? 0xA00 : 0xB00)
        )

        return NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data,
            data2: -1
        )
    }
}
