import Foundation
import KeyFlowMultitouchBridge

struct RawTouchPoint: Sendable {
    let identifier: Int32
    let state: Int32
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
}

struct RawTouchFrame: Sendable {
    let points: [RawTouchPoint]
    let timestamp: TimeInterval
}

final class RawMultitouchProvider: @unchecked Sendable {
    private let onFrame: @Sendable (RawTouchFrame) -> Void
    private var frameGate = RawTouchFrameGate()

    init(onFrame: @escaping @Sendable (RawTouchFrame) -> Void) {
        self.onFrame = onFrame
    }

    var isAvailable: Bool { KFMTIsAvailable() }

    func start() -> Bool {
        frameGate.reset()
        return KFMTStart(rawMultitouchCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    func stop() {
        KFMTStop()
        frameGate.reset()
    }

    fileprivate func receive(
        points: UnsafePointer<KFMTouchPoint>?,
        count: Int32,
        timestamp: Double
    ) {
        guard count >= 0, count <= 32 else { return }
        let buffer = points.map { UnsafeBufferPointer(start: $0, count: Int(count)) }
        let activeCount =
            buffer?.reduce(into: 0) { result, point in
                if point.state == 3 || point.state == 4 { result += 1 }
            } ?? 0
        guard frameGate.shouldForward(activeContactCount: activeCount) else { return }

        var copied: [RawTouchPoint] = []
        copied.reserveCapacity(activeCount)
        if let buffer {
            for point in buffer where point.state == 3 || point.state == 4 {
                copied.append(
                    RawTouchPoint(
                        identifier: point.identifier,
                        state: point.state,
                        x: CGFloat(point.x),
                        y: CGFloat(point.y),
                        size: CGFloat(point.size)
                    )
                )
            }
        }
        onFrame(RawTouchFrame(points: copied, timestamp: timestamp))
    }
}

struct RawTouchFrameGate {
    private(set) var isTrackingGesture = false

    mutating func reset() {
        isTrackingGesture = false
    }

    mutating func shouldForward(activeContactCount: Int) -> Bool {
        if activeContactCount >= 3 {
            isTrackingGesture = true
            return true
        }
        if activeContactCount == 0, isTrackingGesture {
            isTrackingGesture = false
            return true
        }
        return false
    }
}

private let rawMultitouchCallback: KFMTFrameCallback = { points, count, timestamp, context in
    guard let context else { return }
    let provider = Unmanaged<RawMultitouchProvider>.fromOpaque(context).takeUnretainedValue()
    provider.receive(points: points, count: count, timestamp: timestamp)
}
