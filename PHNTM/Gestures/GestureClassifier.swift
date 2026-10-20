import Foundation
import CoreGraphics

enum GestureClassifier {

    // Индексы суставов в нашем массиве landmarks.
    private static let fingers: [
        (mcp: Int, pip: Int, tip: Int)
    ] = [
        (5, 6, 8),    // Index
        (9, 10, 12),  // Middle
        (13, 14, 16), // Ring
        (17, 18, 20)  // Little
    ]

    static func isOpenPalm(
        _ landmarks: [CGPoint?]
    ) -> Bool {

        guard landmarks.count == 21 else {
            return false
        }

        var extendedFingers = 0

        for finger in fingers {

            guard
                let mcp = landmarks[finger.mcp],
                let pip = landmarks[finger.pip],
                let tip = landmarks[finger.tip]
            else {
                return false
            }

            let baseDistance = distance(mcp, pip)
            let tipDistance = distance(mcp, tip)

            guard baseDistance > 0.0001 else {
                return false
            }

            let ratio = tipDistance / baseDistance

            if ratio > 1.6 {
                extendedFingers += 1
            }
        }

        return extendedFingers == 4
    }

    private static func distance(
        _ a: CGPoint,
        _ b: CGPoint
    ) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
