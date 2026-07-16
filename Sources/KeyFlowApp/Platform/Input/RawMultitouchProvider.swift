import Foundation
import KeyFlowMultitouchBridge

enum MultitouchProviderIssue: Equatable, Sendable {
    case disabledByCompatibilityPolicy(String)
    case privateFrameworkUnavailable
    case requiredSymbolsUnavailable
    case defaultDeviceUnavailable
    case invalidCallback
    case startFailed

    var userFacingDescription: String {
        switch self {
        case let .disabledByCompatibilityPolicy(reason): reason
        case .privateFrameworkUnavailable: "Private multitouch framework unavailable"
        case .requiredSymbolsUnavailable: "Required multitouch APIs unavailable"
        case .defaultDeviceUnavailable: "No compatible trackpad found"
        case .invalidCallback: "Multitouch callback rejected"
        case .startFailed: "Multitouch provider could not start"
        }
    }

    var diagnosticsDescription: String {
        switch self {
        case let .disabledByCompatibilityPolicy(reason): "disabled by compatibility policy: \(reason)"
        case .privateFrameworkUnavailable: "private framework unavailable"
        case .requiredSymbolsUnavailable: "required symbols unavailable"
        case .defaultDeviceUnavailable: "default device unavailable"
        case .invalidCallback: "invalid callback"
        case .startFailed: "start failed"
        }
    }
}

struct MultitouchCompatibilityContext: Sendable {
    let operatingSystemVersion: OperatingSystemVersion
    let operatingSystemBuild: String
    let forceDisabled: Bool

    static var current: Self {
        Self(
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion,
            operatingSystemBuild: SystemVersionMetadata.productBuildVersion,
            forceDisabled: ProcessInfo.processInfo.environment["KEYFLOW_DISABLE_RAW_MULTITOUCH"] == "1"
        )
    }
}

enum MultitouchCompatibilityDecision: Equatable, Sendable {
    case allowed
    case disabled(String)
}

enum MultitouchCompatibilityPolicy {
    static let minimumSupportedMajorVersion = 15

    // Add an affected build or prefix here to stop the private provider in the
    // next signed app build while leaving keyboard input fully operational.
    static let blockedOperatingSystemBuildPrefixes: Set<String> = []

    static func evaluate(
        _ context: MultitouchCompatibilityContext,
        blockedBuildPrefixes: Set<String> = blockedOperatingSystemBuildPrefixes
    ) -> MultitouchCompatibilityDecision {
        if context.forceDisabled {
            return .disabled("disabled by KEYFLOW_DISABLE_RAW_MULTITOUCH")
        }
        if context.operatingSystemVersion.majorVersion < minimumSupportedMajorVersion {
            return .disabled("macOS \(minimumSupportedMajorVersion) or later is required")
        }
        if blockedBuildPrefixes.contains(where: context.operatingSystemBuild.hasPrefix) {
            return .disabled("macOS build \(context.operatingSystemBuild) is blocked")
        }
        return .allowed
    }
}

private enum SystemVersionMetadata {
    static let productBuildVersion: String = {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/SystemVersion.plist")
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let values = plist as? [String: Any],
            let build = values["ProductBuildVersion"] as? String
        else { return "unknown" }
        return build
    }()
}

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

    var availabilityIssue: MultitouchProviderIssue? {
        switch MultitouchCompatibilityPolicy.evaluate(.current) {
        case .allowed: break
        case let .disabled(reason): return .disabledByCompatibilityPolicy(reason)
        }
        return Self.issue(for: KFMTGetAvailabilityStatus())
    }

    var isAvailable: Bool { availabilityIssue == nil }

    func start() -> Bool {
        frameGate.reset()
        return KFMTStart(rawMultitouchCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    var lastStartIssue: MultitouchProviderIssue? {
        Self.issue(for: KFMTGetLastStartStatus())
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

    private static func issue(for status: KFMTStatus) -> MultitouchProviderIssue? {
        switch status {
        case KFMTStatus(KFMTStatusAvailable): nil
        case KFMTStatus(KFMTStatusInvalidCallback): .invalidCallback
        case KFMTStatus(KFMTStatusFrameworkUnavailable): .privateFrameworkUnavailable
        case KFMTStatus(KFMTStatusRequiredSymbolsUnavailable): .requiredSymbolsUnavailable
        case KFMTStatus(KFMTStatusDefaultDeviceUnavailable): .defaultDeviceUnavailable
        default: .startFailed
        }
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
