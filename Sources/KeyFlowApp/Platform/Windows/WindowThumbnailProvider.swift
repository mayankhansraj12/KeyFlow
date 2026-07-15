import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class WindowThumbnailProvider {
    private struct CacheEntry {
        let processID: pid_t
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
    private static let maximumCacheBytes = 32 * 1_024 * 1_024
    private static let maximumCacheAge: Duration = .seconds(600)
    // Capturing windows is the dominant launch cost of the overlay. Keep valid previews
    // for the working session; bounds/PID changes still invalidate them immediately.
    private static let minimumRefreshInterval: Duration = .seconds(300)

    private var cache: [CGWindowID: CacheEntry] = [:]
    private var cacheByteCost = 0

    func cachedThumbnails(for windows: [SwitchableWindow]) -> [CGWindowID: NSImage] {
        let now = ContinuousClock.now
        removeExpiredEntries(now: now)
        var result: [CGWindowID: NSImage] = [:]
        for window in windows {
            guard
                let windowID = window.windowID,
                var entry = cache[windowID],
                entry.processID == window.processID,
                abs(entry.bounds.width - window.bounds.width) <= 2,
                abs(entry.bounds.height - window.bounds.height) <= 2
            else { continue }
            entry.lastAccess = now
            cache[windowID] = entry
            result[windowID] = entry.image
        }
        return result
    }

    func thumbnails(
        for windows: [SwitchableWindow],
        onUpdate: (([CGWindowID: NSImage]) -> Void)? = nil
    ) async -> [CGWindowID: NSImage] {
        guard CGPreflightScreenCaptureAccess() else { return [:] }
        let now = ContinuousClock.now
        var result = cachedThumbnails(for: windows)
        let windowsNeedingRefresh = windows.filter { window in
            guard
                let windowID = window.windowID,
                let entry = cache[windowID],
                entry.processID == window.processID,
                abs(entry.bounds.width - window.bounds.width) <= 2,
                abs(entry.bounds.height - window.bounds.height) <= 2
            else { return true }
            return now - entry.capturedAt >= Self.minimumRefreshInterval
        }
        guard !windowsNeedingRefresh.isEmpty else { return result }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let requestedWindows = Dictionary(
                uniqueKeysWithValues: windowsNeedingRefresh.compactMap { window in
                    window.windowID.map { ($0, window) }
                }
            )
            let shareableWindows = Dictionary(
                uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) }
            )
            // Preserve the caller's order. The controller puts the selected window first,
            // so the preview the user is looking at is the first result published.
            let targets = windowsNeedingRefresh.compactMap { requested -> CaptureTarget? in
                guard
                    let windowID = requested.windowID,
                    let window = shareableWindows[windowID],
                    requestedWindows[windowID] != nil
                else { return nil }
                return CaptureTarget(
                    windowID: windowID,
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
                    store(
                        image,
                        byteCost: capture.image.bytesPerRow * capture.image.height,
                        windowID: capture.windowID,
                        processID: capture.processID,
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

    private func store(
        _ image: NSImage,
        byteCost: Int,
        windowID: CGWindowID,
        processID: pid_t,
        bounds: CGRect
    ) {
        if let oldEntry = cache[windowID] { cacheByteCost -= oldEntry.byteCost }
        let entry = CacheEntry(
            processID: processID,
            bounds: bounds,
            image: image,
            byteCost: byteCost,
            capturedAt: .now,
            lastAccess: .now
        )
        cache[windowID] = entry
        cacheByteCost += byteCost
        pruneCacheToBudget()
    }

    private func removeExpiredEntries(now: ContinuousClock.Instant) {
        let expiredIDs = cache.compactMap { windowID, entry in
            now - entry.lastAccess > Self.maximumCacheAge ? windowID : nil
        }
        for windowID in expiredIDs {
            if let entry = cache.removeValue(forKey: windowID) { cacheByteCost -= entry.byteCost }
        }
    }

    private func pruneCacheToBudget() {
        while cacheByteCost > Self.maximumCacheBytes,
            let oldest = cache.min(by: { $0.value.lastAccess < $1.value.lastAccess })
        {
            cache.removeValue(forKey: oldest.key)
            cacheByteCost -= oldest.value.byteCost
        }
    }
}
