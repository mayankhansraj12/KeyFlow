import AppKit
import CoreGraphics
import ScreenCaptureKit

enum WindowThumbnailCacheValidator {
    static func matches(
        cachedProcessID: pid_t,
        cachedTitle: String,
        cachedBounds: CGRect,
        window: SwitchableWindow
    ) -> Bool {
        cachedProcessID == window.processID
            && cachedTitle == window.title
            && abs(cachedBounds.width - window.bounds.width) <= 2
            && abs(cachedBounds.height - window.bounds.height) <= 2
    }
}

@MainActor
protocol WindowThumbnailProviding: AnyObject {
    func cachedThumbnails(for windows: [SwitchableWindow]) -> [CGWindowID: NSImage]
    func thumbnails(
        for windows: [SwitchableWindow],
        onUpdate: (([CGWindowID: NSImage]) -> Void)?
    ) async -> [CGWindowID: NSImage]
}

@MainActor
final class WindowThumbnailProvider: WindowThumbnailProviding {
    private struct CacheEntry {
        let processID: pid_t
        let title: String
        let bounds: CGRect
        let image: NSImage
        let byteCost: Int
        let capturedAt: ContinuousClock.Instant
        var lastAccess: ContinuousClock.Instant
    }

    private struct CaptureTarget: @unchecked Sendable {
        let windowID: CGWindowID
        let processID: pid_t
        let bounds: CGRect
        let window: SCWindow
    }

    private struct CapturedThumbnail: @unchecked Sendable {
        let windowID: CGWindowID
        let processID: pid_t
        let bounds: CGRect
        let image: CGImage
    }

    // The cards never render near full-window resolution. A 480 px longest edge remains
    // crisp at the largest card size while avoiding unnecessary ScreenCaptureKit scaling.
    private nonisolated static let maximumPixelLength: CGFloat = 480
    private static let defaultMaximumCacheBytes = 32 * 1_024 * 1_024
    private static let defaultMaximumCacheAge: Duration = .seconds(120)
    // A cached image is only the zero-latency first frame. Revalidate shortly
    // afterward so browser navigation and tab/window changes cannot remain stale.
    private static let defaultMinimumRefreshInterval: Duration = .seconds(2)

    private let maximumCacheBytes: Int
    private let maximumCacheAge: Duration
    private let minimumRefreshInterval: Duration
    private var cache: [CGWindowID: CacheEntry] = [:]
    private var cacheByteCost = 0
    private var evictionTask: Task<Void, Never>?

    init(
        maximumCacheBytes: Int = WindowThumbnailProvider.defaultMaximumCacheBytes,
        maximumCacheAge: Duration = WindowThumbnailProvider.defaultMaximumCacheAge,
        minimumRefreshInterval: Duration = WindowThumbnailProvider.defaultMinimumRefreshInterval
    ) {
        self.maximumCacheBytes = max(1, maximumCacheBytes)
        self.maximumCacheAge = max(.milliseconds(1), maximumCacheAge)
        self.minimumRefreshInterval = max(.zero, minimumRefreshInterval)
    }

    deinit {
        evictionTask?.cancel()
    }

    func cachedThumbnails(for windows: [SwitchableWindow]) -> [CGWindowID: NSImage] {
        let now = ContinuousClock.now
        removeExpiredEntries(now: now)
        removeEntriesMissingFromCurrentCatalog(windows)
        var result: [CGWindowID: NSImage] = [:]
        for window in windows {
            guard
                var entry = cache[window.windowID],
                WindowThumbnailCacheValidator.matches(
                    cachedProcessID: entry.processID,
                    cachedTitle: entry.title,
                    cachedBounds: entry.bounds,
                    window: window
                )
            else { continue }
            entry.lastAccess = now
            cache[window.windowID] = entry
            result[window.windowID] = entry.image
        }
        scheduleNextExpiration()
        return result
    }

    func thumbnails(
        for windows: [SwitchableWindow],
        onUpdate: (([CGWindowID: NSImage]) -> Void)? = nil
    ) async -> [CGWindowID: NSImage] {
        let performance = KeyFlowPerformance.begin("RefreshThumbnails", using: KeyFlowPerformance.thumbnails)
        defer { performance.end() }
        guard CGPreflightScreenCaptureAccess() else { return [:] }
        let now = ContinuousClock.now
        var result = cachedThumbnails(for: windows)
        let windowsNeedingRefresh = windows.filter { window in
            guard
                let entry = cache[window.windowID],
                WindowThumbnailCacheValidator.matches(
                    cachedProcessID: entry.processID,
                    cachedTitle: entry.title,
                    cachedBounds: entry.bounds,
                    window: window
                )
            else { return true }
            return now - entry.capturedAt >= minimumRefreshInterval
        }
        guard !windowsNeedingRefresh.isEmpty else { return result }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let requestedWindows = Dictionary(
                uniqueKeysWithValues: windowsNeedingRefresh.map { ($0.windowID, $0) }
            )
            let shareableWindows = Dictionary(
                uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) }
            )
            // Preserve the caller's order. The controller puts the selected window first,
            // so the preview the user is looking at is the first result published.
            let targets = windowsNeedingRefresh.compactMap { requested -> CaptureTarget? in
                guard
                    let window = shareableWindows[requested.windowID],
                    requestedWindows[requested.windowID] != nil
                else { return nil }
                return CaptureTarget(
                    windowID: requested.windowID,
                    processID: requested.processID,
                    bounds: requested.bounds,
                    window: window
                )
            }
            var pendingUpdate: [CGWindowID: NSImage] = [:]
            var hasPublishedInitialPreview = false
            for target in targets {
                guard !Task.isCancelled else { return result }
                if let capture = await Self.capture(target) {
                    let image = NSImage(
                        cgImage: capture.image,
                        size: NSSize(width: capture.image.width, height: capture.image.height)
                    )
                    cacheThumbnail(
                        image,
                        byteCost: capture.image.bytesPerRow * capture.image.height,
                        windowID: capture.windowID,
                        processID: capture.processID,
                        title: requestedWindows[capture.windowID]?.title ?? "",
                        bounds: capture.bounds
                    )
                    result[capture.windowID] = image
                    pendingUpdate[capture.windowID] = image
                }
                if !pendingUpdate.isEmpty,
                    !hasPublishedInitialPreview || pendingUpdate.count >= 3
                {
                    onUpdate?(pendingUpdate)
                    pendingUpdate.removeAll(keepingCapacity: true)
                    hasPublishedInitialPreview = true
                }
            }
            if !pendingUpdate.isEmpty { onUpdate?(pendingUpdate) }
            return result
        } catch {
            KeyFlowLog.input.error("Window thumbnail capture failed: \(error.localizedDescription, privacy: .public)")
            return result
        }
    }

    private nonisolated static func capture(_ target: CaptureTarget) async -> CapturedThumbnail? {
        guard !Task.isCancelled else { return nil }
        let configuration = SCStreamConfiguration()
        let longestSide = max(target.window.frame.width, target.window.frame.height, 1)
        let scale = min(1, maximumPixelLength / longestSide)
        configuration.width = max(1, Int((target.window.frame.width * scale).rounded()))
        configuration.height = max(1, Int((target.window.frame.height * scale).rounded()))
        configuration.captureResolution = .nominal
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        let filter = SCContentFilter(desktopIndependentWindow: target.window)
        guard
            let image = try? await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        else { return nil }
        return CapturedThumbnail(
            windowID: target.windowID,
            processID: target.processID,
            bounds: target.bounds,
            image: image
        )
    }

    func cacheThumbnail(
        _ image: NSImage,
        byteCost: Int,
        windowID: CGWindowID,
        processID: pid_t,
        title: String,
        bounds: CGRect
    ) {
        if let oldEntry = cache[windowID] { cacheByteCost -= oldEntry.byteCost }
        let entry = CacheEntry(
            processID: processID,
            title: title,
            bounds: bounds,
            image: image,
            byteCost: byteCost,
            capturedAt: .now,
            lastAccess: .now
        )
        cache[windowID] = entry
        cacheByteCost += byteCost
        pruneCacheToBudget()
        scheduleNextExpiration()
    }

    private func removeExpiredEntries(now: ContinuousClock.Instant) {
        let expiredIDs = cache.compactMap { windowID, entry in
            now - entry.lastAccess >= maximumCacheAge ? windowID : nil
        }
        for windowID in expiredIDs {
            if let entry = cache.removeValue(forKey: windowID) { cacheByteCost -= entry.byteCost }
        }
    }

    private func removeEntriesMissingFromCurrentCatalog(_ windows: [SwitchableWindow]) {
        let currentIDs = Set(windows.map(\.windowID))
        let missingIDs = cache.keys.filter { !currentIDs.contains($0) }
        for windowID in missingIDs {
            if let entry = cache.removeValue(forKey: windowID) { cacheByteCost -= entry.byteCost }
        }
    }

    private func pruneCacheToBudget() {
        while cacheByteCost > maximumCacheBytes,
            let oldest = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess })
        {
            cache.removeValue(forKey: oldest.key)
            cacheByteCost -= oldest.value.byteCost
        }
    }

    private func scheduleNextExpiration() {
        evictionTask?.cancel()
        evictionTask = nil
        guard let deadline = cache.values.map({ $0.lastAccess + maximumCacheAge }).min() else {
            return
        }
        let now = ContinuousClock.now
        let delay = now < deadline ? now.duration(to: deadline) : .zero
        evictionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            self.removeExpiredEntries(now: .now)
            self.scheduleNextExpiration()
        }
    }

    var cacheEntryCount: Int { cache.count }
    var cachedWindowIDs: Set<CGWindowID> { Set(cache.keys) }
    var cacheMemoryCost: Int { cacheByteCost }
}
