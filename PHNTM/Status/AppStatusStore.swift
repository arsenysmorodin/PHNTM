import Foundation
import Combine

enum AppWorkStatus: Equatable {
    case permissionRequired(String)
    case ready
    case guardPalmDetected
    case brightnessGestureArmed
    case gestureDetected(GestureDirection)
    case brightnessAdjusted
    case error(String)

    var title: String {
        switch self {
        case .permissionRequired:
            return "Permission required"
        case .ready:
            return "PHNTM is ready"
        case .guardPalmDetected:
            return "Open palm detected"
        case .brightnessGestureArmed:
            return "Two palms detected"
        case .gestureDetected(let direction):
            return "Gesture: \(direction.displayName)"
        case .brightnessAdjusted:
            return "Brightness gesture recognized"
        case .error:
            return "PHNTM error"
        }
    }

    var detail: String {
        switch self {
        case .permissionRequired(let message), .error(let message):
            return message
        case .ready:
            return "Show a supported two-hand gesture."
        case .guardPalmDetected:
            return "The safety hand is ready. Show a direction with the other hand."
        case .brightnessGestureArmed:
            return "Close both hands into fists to dim the display."
        case .gestureDetected(let direction):
            return direction.actionDescription
        case .brightnessAdjusted:
            return "Display brightness reduced to one step above minimum."
        }
    }

    var symbolName: String {
        switch self {
        case .permissionRequired:
            return "lock.fill"
        case .ready:
            return "checkmark.circle.fill"
        case .guardPalmDetected:
            return "hand.raised.fill"
        case .brightnessGestureArmed:
            return "hands.clap.fill"
        case .gestureDetected:
            return "hand.point.up.left.fill"
        case .brightnessAdjusted:
            return "sun.min.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
final class AppStatusStore: ObservableObject {

    @Published private(set) var status: AppWorkStatus = .permissionRequired(
        "Camera permission is required."
    )

    private var hasCameraPermission = false
    private var hasInputControlPermission = false
    private var guardPalmDetected = false
    private var brightnessGestureArmed = false
    private var persistentErrorMessage: String?
    private var transientStatus: AppWorkStatus?
    private var transientTask: Task<Void, Never>?

    func updatePermissions(
        camera: Bool,
        inputControl: Bool,
        browserControlEnabled _: Bool
    ) {
        hasCameraPermission = camera
        hasInputControlPermission = inputControl

        if permissionMessage != nil {
            clearTransientStatus()
        }

        refreshStatus()
    }

    func updateGuardPalm(_ detected: Bool) {
        guardPalmDetected = detected
        refreshStatus()
    }

    func updateBrightnessGestureArmed(_ armed: Bool) {
        brightnessGestureArmed = armed
        refreshStatus()
    }

    func reportGesture(_ direction: GestureDirection) {
        guard permissionMessage == nil else {
            refreshStatus()
            return
        }

        showTransient(
            .gestureDetected(direction),
            duration: .seconds(1.2)
        )
    }

    func reportBrightnessAdjusted() {
        guard permissionMessage == nil else {
            refreshStatus()
            return
        }

        showTransient(
            .brightnessAdjusted,
            duration: .seconds(1.4)
        )
    }

    func reportError(_ message: String) {
        guard permissionMessage == nil else {
            refreshStatus()
            return
        }

        clearTransientStatus()
        persistentErrorMessage = message
        refreshStatus()
    }

    func reportTransientError(_ message: String) {
        guard permissionMessage == nil,
              persistentErrorMessage == nil else {
            refreshStatus()
            return
        }

        showTransient(
            .error(message),
            duration: .seconds(3)
        )
    }

    func clearPersistentError() {
        persistentErrorMessage = nil
        refreshStatus()
    }

    private var permissionMessage: String? {
        if !hasCameraPermission {
            return "Allow camera access for PHNTM."
        }

        if !hasInputControlPermission {
            return "Allow PHNTM in Accessibility to control Safari and display brightness."
        }

        return nil
    }

    private func showTransient(
        _ status: AppWorkStatus,
        duration: Duration
    ) {
        transientTask?.cancel()
        transientStatus = status
        self.status = status

        transientTask = Task { [weak self] in
            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.transientStatus = nil
            self?.refreshStatus()
        }
    }

    private func clearTransientStatus() {
        transientTask?.cancel()
        transientTask = nil
        transientStatus = nil
    }

    private func refreshStatus() {
        if let permissionMessage {
            status = .permissionRequired(permissionMessage)
        } else if let persistentErrorMessage {
            status = .error(persistentErrorMessage)
        } else if let transientStatus {
            status = transientStatus
        } else if brightnessGestureArmed {
            status = .brightnessGestureArmed
        } else if guardPalmDetected {
            status = .guardPalmDetected
        } else {
            status = .ready
        }
    }
}

private extension GestureDirection {
    var displayName: String {
        switch self {
        case .left:
            return "left"
        case .right:
            return "right"
        case .up:
            return "up"
        case .down:
            return "down"
        }
    }

    var actionDescription: String {
        switch self {
        case .left:
            return "Previous Safari tab."
        case .right:
            return "Next Safari tab."
        case .up:
            return "Scroll Safari down."
        case .down:
            return "Scroll Safari up."
        }
    }
}
