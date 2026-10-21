import Foundation
import Combine
import CoreGraphics

enum GestureDirection: String {
    case left = "POINT LEFT"
    case right = "POINT RIGHT"
    case up = "POINT UP"
    case down = "POINT DOWN"
}

@MainActor
final class DirectionGestureEngine: ObservableObject {

    @Published private(set) var lastEvent: GestureDirection?

    private var clearEventTask: Task<Void, Never>?
    private let eventDisplayDuration: Duration = .seconds(1.15)

    private var candidateDirection: GestureDirection?
    private var candidateStartedAt: TimeInterval?
    private var waitingForRelease = false
    private var releaseStartedAt: TimeInterval?

    private let stabilizationDuration = 0.18
    private let releaseDuration = 0.18
    private let directionRatio: CGFloat = 1.35
    private let minimumFingerLength: CGFloat = 0.08
    private let palmLengthMultiplier: CGFloat = 1.05

    func process(
        landmarks: [CGPoint?],
        isGuardPresent: Bool,
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> GestureDirection? {
        let direction = direction(in: landmarks)

        // Удержание позы создаёт ровно одно событие. Даже если открытая
        // ладонь на секунду потеряется, новый жест не разрешается, пока
        // указывающая рука явно не отпустит позу.
        if waitingForRelease {
            if direction == nil {
                if releaseStartedAt == nil {
                    releaseStartedAt = time
                }

                if let releaseStartedAt,
                   time - releaseStartedAt >= releaseDuration {
                    resetRearmState()
                }
            } else {
                releaseStartedAt = nil
            }

            return nil
        }

        guard isGuardPresent, let direction else {
            resetCandidate()
            return nil
        }

        if candidateDirection != direction {
            candidateDirection = direction
            candidateStartedAt = time
            return nil
        }

        guard let candidateStartedAt,
              time - candidateStartedAt >= stabilizationDuration else {
            return nil
        }

        publish(direction)
        waitingForRelease = true
        releaseStartedAt = nil
        resetCandidate()

        return direction
    }

    private func direction(
        in landmarks: [CGPoint?]
    ) -> GestureDirection? {
        guard landmarks.count == 21,
              GestureClassifier.isPointing(landmarks),
              let indexBase = landmarks[5],
              let indexTip = landmarks[8],
              let littleBase = landmarks[17] else {
            return nil
        }

        let dx = indexTip.x - indexBase.x
        let dy = indexTip.y - indexBase.y
        let horizontal = abs(dx)
        let vertical = abs(dy)

        let palmWidth = hypot(
            indexBase.x - littleBase.x,
            indexBase.y - littleBase.y
        )
        let requiredLength = max(
            minimumFingerLength,
            palmWidth * palmLengthMultiplier
        )

        guard hypot(dx, dy) >= requiredLength else {
            return nil
        }

        if horizontal >= vertical * directionRatio {
            return dx > 0 ? .right : .left
        }

        if vertical >= horizontal * directionRatio {
            // Vision использует начало координат в левом нижнем углу.
            return dy > 0 ? .up : .down
        }

        return nil
    }

    private func publish(_ direction: GestureDirection) {
        clearEventTask?.cancel()
        lastEvent = direction
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

    private func resetCandidate() {
        candidateDirection = nil
        candidateStartedAt = nil
    }

    private func resetRearmState() {
        waitingForRelease = false
        releaseStartedAt = nil
    }

    func reset() {
        clearEventTask?.cancel()
        clearEventTask = nil
        resetCandidate()
        resetRearmState()
        lastEvent = nil
    }
}
