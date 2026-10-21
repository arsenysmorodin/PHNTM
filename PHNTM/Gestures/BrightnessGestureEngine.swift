import Combine
import CoreGraphics
import Foundation

enum BrightnessGestureEvent: Equatable {
    case dimDisplay
}

enum BrightnessGesturePhase: Equatable {
    case idle
    case arming
    case readyToClose
    case closing
    case waitingForRelease

    var isEngaged: Bool {
        self != .idle
    }
}

@MainActor
final class BrightnessGestureEngine: ObservableObject {

    @Published private(set) var phase: BrightnessGesturePhase = .idle
    @Published private(set) var lastEvent: BrightnessGestureEvent?

    private var openPalmStartedAt: TimeInterval?
    private var transitionStartedAt: TimeInterval?
    private var fistStartedAt: TimeInterval?
    private var releaseStartedAt: TimeInterval?
    private var clearEventTask: Task<Void, Never>?

    private let openPalmStabilizationDuration = 0.24
    private let fistStabilizationDuration = 0.18
    private let maximumClosingDuration = 1.6
    private let releaseDuration = 0.25
    private let eventDisplayDuration: Duration = .seconds(1.25)

    @discardableResult
    func process(
        hands: [[CGPoint?]],
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> BrightnessGestureEvent? {
        let openPalmCount = hands.filter(
            GestureClassifier.isOpenPalm
        ).count
        let fistCount = hands.filter(
            GestureClassifier.isFist
        ).count

        return process(
            openPalmCount: openPalmCount,
            fistCount: fistCount,
            at: time
        )
    }

    @discardableResult
    func process(
        openPalmCount: Int,
        fistCount: Int,
        at time: TimeInterval
    ) -> BrightnessGestureEvent? {
        switch phase {
        case .idle:
            guard openPalmCount >= 2 else { return nil }
            openPalmStartedAt = time
            phase = .arming

        case .arming:
            guard openPalmCount >= 2 else {
                resetRecognitionState()
                return nil
            }

            if let openPalmStartedAt,
               time - openPalmStartedAt >= openPalmStabilizationDuration {
                phase = .readyToClose
                transitionStartedAt = nil
            }

        case .readyToClose:
            if openPalmCount >= 2 {
                transitionStartedAt = nil
                fistStartedAt = nil
                return nil
            }

            if transitionStartedAt == nil {
                transitionStartedAt = time
            }

            guard transitionIsActive(at: time) else {
                resetRecognitionState()
                return nil
            }

            if fistCount >= 2 {
                fistStartedAt = time
                phase = .closing
            }

        case .closing:
            guard transitionIsActive(at: time) else {
                resetRecognitionState()
                return nil
            }

            if openPalmCount >= 2 {
                phase = .readyToClose
                transitionStartedAt = nil
                fistStartedAt = nil
                return nil
            }

            guard fistCount >= 2 else {
                fistStartedAt = nil
                phase = .readyToClose
                return nil
            }

            guard let fistStartedAt,
                  time - fistStartedAt >= fistStabilizationDuration else {
                return nil
            }

            let event = BrightnessGestureEvent.dimDisplay
            publish(event)
            phase = .waitingForRelease
            releaseStartedAt = nil
            return event

        case .waitingForRelease:
            if fistCount >= 2 {
                releaseStartedAt = nil
                return nil
            }

            if releaseStartedAt == nil {
                releaseStartedAt = time
                return nil
            }

            if let releaseStartedAt,
               time - releaseStartedAt >= releaseDuration {
                resetRecognitionState()
            }
        }

        return nil
    }

    private func transitionIsActive(at time: TimeInterval) -> Bool {
        guard let transitionStartedAt else { return true }
        return time - transitionStartedAt <= maximumClosingDuration
    }

    private func publish(_ event: BrightnessGestureEvent) {
        clearEventTask?.cancel()
        lastEvent = event
        let displayDuration = eventDisplayDuration

        clearEventTask = Task { [weak self] in
            do {
                try await Task.sleep(for: displayDuration)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.lastEvent = nil
        }
    }

    private func resetRecognitionState() {
        phase = .idle
        openPalmStartedAt = nil
        transitionStartedAt = nil
        fistStartedAt = nil
        releaseStartedAt = nil
    }

    func reset() {
        clearEventTask?.cancel()
        clearEventTask = nil
        lastEvent = nil
        resetRecognitionState()
    }
}
