import Foundation
import CoreGraphics

struct TwoHandGesture {
    let openPalmHand: [CGPoint?]
    let gestureHand: [CGPoint?]
}

enum GestureClassifier {

    // Индексы суставов в нашем массиве landmarks.
    nonisolated private static let fingers: [
        (mcp: Int, pip: Int, tip: Int)
    ] = [
        (5, 6, 8),    // Index
        (9, 10, 12),  // Middle
        (13, 14, 16), // Ring
        (17, 18, 20)  // Little
    ]

    nonisolated static func isOpenPalm(
        _ landmarks: [CGPoint?]
    ) -> Bool {

        guard landmarks.count == 21 else {
            return false
        }

        return fingers.allSatisfy { finger in
            isFingerExtended(
                landmarks,
                mcp: finger.mcp,
                pip: finger.pip,
                tip: finger.tip
            )
        }
    }

    nonisolated static func isPointing(_ landmarks: [CGPoint?]) -> Bool {
        guard landmarks.count == 21 else {
            return false
        }

        // Указательный палец должен быть выпрямлен.
        guard isFingerExtended(
            landmarks,
            mcp: 5,
            pip: 6,
            tip: 8
        ) else {
            return false
        }

        let extendedOtherFingers = fingers.dropFirst().filter { finger in
            isFingerExtended(
                landmarks,
                mcp: finger.mcp,
                pip: finger.pip,
                tip: finger.tip
            )
        }.count

        // Допускаем один неоднозначно распознанный
        // палец, но не открытую ладонь.
        return extendedOtherFingers <= 1
    }

    nonisolated static func twoHandGesture(
        in hands: [[CGPoint?]]
    ) -> TwoHandGesture? {
        guard hands.count >= 2 else {
            return nil
        }

        for (gestureIndex, gestureHand) in hands.enumerated()
        where isPointing(gestureHand) {
            guard let openPalmHand = hands.enumerated().first(where: {
                $0.offset != gestureIndex && isOpenPalm($0.element)
            })?.element else {
                continue
            }

            return TwoHandGesture(
                openPalmHand: openPalmHand,
                gestureHand: gestureHand
            )
        }

        return nil
    }

    nonisolated private static func isFingerExtended(
        _ landmarks: [CGPoint?],
        mcp: Int,
        pip: Int,
        tip: Int
    ) -> Bool {
        guard let base = landmarks[mcp],
              let middle = landmarks[pip],
              let end = landmarks[tip] else {
            return false
        }

        let firstSegment = CGVector(
            dx: base.x - middle.x,
            dy: base.y - middle.y
        )
        let secondSegment = CGVector(
            dx: end.x - middle.x,
            dy: end.y - middle.y
        )

        let firstLength = hypot(firstSegment.dx, firstSegment.dy)
        let secondLength = hypot(secondSegment.dx, secondSegment.dy)

        guard firstLength > 0.0001,
              secondLength > 0.0001 else {
            return false
        }

        let cosine = (
            firstSegment.dx * secondSegment.dx
                + firstSegment.dy * secondSegment.dy
        ) / (firstLength * secondLength)

        // Для выпрямленного пальца угол в PIP близок к 180°.
        // Сочетание угла и общей длины меньше зависит от масштаба руки.
        return cosine < -0.55
            && distance(base, end) / firstLength > 1.35
    }

    nonisolated private static func distance(
        _ a: CGPoint,
        _ b: CGPoint
    ) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
