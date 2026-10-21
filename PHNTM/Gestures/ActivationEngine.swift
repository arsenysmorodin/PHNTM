import Foundation
import Combine

@MainActor
final class ActivationEngine: ObservableObject {

    enum Mode {
        case standby
        case active
    }

    @Published private(set) var mode: Mode = .standby
    @Published private(set) var progress: Double = 0
    @Published private(set) var needsRelease = false

    private var holdStartedAt: TimeInterval?
    private var lastOpenAt: TimeInterval?
    private var releaseStartedAt: TimeInterval?

    private let activationDuration = 0.7
    private let deactivationDuration = 1.5
    private let releaseDuration = 0.3
    private let detectionGrace = 0.16

    var isActive: Bool {
        mode == .active
    }

    var instruction: String {
        if needsRelease {
            return "RELEASE YOUR PALM"
        }

        return isActive
            ? "HOLD PALM TO DEACTIVATE"
            : "HOLD PALM TO ACTIVATE"
    }

    func process(
        isOpenPalm: Bool,
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        // После смены режима ждём отпускания жеста.
        if needsRelease {
            progress = 0

            if isOpenPalm {
                releaseStartedAt = nil
            } else {
                if releaseStartedAt == nil {
                    releaseStartedAt = time
                }

                if let start = releaseStartedAt,
                   time - start >= releaseDuration {
                    needsRelease = false
                    releaseStartedAt = nil
                }
            }

            return
        }

        if isOpenPalm {
            // Если трекинг пропадал надолго,
            // начинаем отсчёт заново.
            if let last = lastOpenAt,
               time - last > detectionGrace {
                holdStartedAt = time
            }

            if holdStartedAt == nil {
                holdStartedAt = time
            }

            lastOpenAt = time

            let requiredDuration = isActive
                ? deactivationDuration
                : activationDuration

            let elapsed = time - (holdStartedAt ?? time)

            progress = min(
                max(elapsed / requiredDuration, 0),
                1
            )

            if progress >= 1 {
                switchMode()
            }

        } else {
            // Допускаем кратковременный сбой Vision.
            if let last = lastOpenAt,
               time - last <= detectionGrace {
                return
            }

            holdStartedAt = nil
            lastOpenAt = nil
            progress = 0
        }
    }

    private func switchMode() {
        mode = isActive ? .standby : .active

        // Не позволяем тому же жесту
        // переключить режим повторно.
        needsRelease = true

        holdStartedAt = nil
        lastOpenAt = nil
        releaseStartedAt = nil
        progress = 0
    }

    func reset() {
        mode = .standby
        progress = 0
        needsRelease = false

        holdStartedAt = nil
        lastOpenAt = nil
        releaseStartedAt = nil
    }
}
