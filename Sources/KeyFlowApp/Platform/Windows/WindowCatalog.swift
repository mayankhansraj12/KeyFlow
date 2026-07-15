import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import KeyFlowCore
import KeyFlowWindowServerBridge

@MainActor
protocol WindowCataloging: AnyObject {
    func availableWindows(scope: WindowSwitcherWindowScope) -> [SwitchableWindow]
    func activate(_ window: SwitchableWindow) throws
}

enum WindowCatalogError: LocalizedError {
    case noWindows
    case applicationUnavailable
    case windowUnavailable

    var errorDescription: String? {
        switch self {
        case .noWindows: "No switchable windows are currently visible."
        case .applicationUnavailable: "The selected application's process is no longer available."
        case .windowUnavailable: "The selected window could not be raised."
        }
    }
}

@MainActor
final class SystemWindowCatalog: WindowCataloging {
    func availableWindows(scope: WindowSwitcherWindowScope) -> [SwitchableWindow] {
        guard
            let rawWindows = CGWindowListCopyWindowInfo(
                [.optionAll, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[CFString: Any]]
        else { return [] }

        var seen = Set<CGWindowID>()
        var applicationElements: [pid_t: AXUIElement] = [:]
        var applicationWindows: [pid_t: [AXUIElement]] = [:]
        var claimedWindows: [pid_t: [AXUIElement]] = [:]
        let windowEntries: [SwitchableWindow] = rawWindows.compactMap { info in
            guard
                let windowID = number(info[kCGWindowNumber]).map(CGWindowID.init),
                seen.insert(windowID).inserted,
                let processID = number(info[kCGWindowOwnerPID]).map(pid_t.init),
                let layer = number(info[kCGWindowLayer]),
                let isOnscreen = (info[kCGWindowIsOnscreen] as? NSNumber)?.boolValue,
                (info[kCGWindowAlpha] as? NSNumber)?.doubleValue ?? 1 > 0.05,
                let boundsDictionary = info[kCGWindowBounds] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                bounds.width >= 160,
                bounds.height >= 100
            else { return nil }

            guard
                let application = NSRunningApplication(processIdentifier: processID),
                !application.isTerminated,
                application.isFinishedLaunching,
                WindowCatalogFilter.includesWindow(
                    layer: layer,
                    isOnscreen: isOnscreen,
                    activationPolicy: application.activationPolicy,
                    bundleIdentifier: application.bundleIdentifier,
                    scope: scope
                )
            else { return nil }
            let applicationName =
                (info[kCGWindowOwnerName] as? String)
                ?? application.localizedName
                ?? "Application"
            let catalogTitle = nonEmpty(info[kCGWindowName] as? String) ?? applicationName
            let applicationElement =
                applicationElements[processID]
                ?? AXUIElementCreateApplication(processID)
            applicationElements[processID] = applicationElement
            let candidates: [AXUIElement]
            if let cached = applicationWindows[processID] {
                candidates = cached
            } else {
                candidates = windows(of: applicationElement)
                applicationWindows[processID] = candidates
            }
            let resolvedWindow = resolvedWindow(
                candidates: candidates,
                excluding: claimedWindows[processID] ?? [],
                title: catalogTitle,
                bounds: bounds
            )
            let windowElement = resolvedWindow?.element
            if let windowElement {
                claimedWindows[processID, default: []].append(windowElement)
            } else if application.activationPolicy == .regular {
                // Regular apps are represented by their application fallback
                // when an exact AX window cannot be resolved. Accepting every
                // unmatched regular CG surface would reintroduce browser tabs,
                // toolbars, and other child surfaces as duplicate windows.
                return nil
            }
            let title =
                windowElement.flatMap { nonEmpty(attributeString($0, kAXTitleAttribute as CFString)) }
                ?? catalogTitle
            let icon = applicationIcon(application) ?? NSWorkspace.shared.icon(for: .applicationBundle)
            return SwitchableWindow(
                id: .window(windowID),
                windowID: windowID,
                processID: processID,
                title: title,
                applicationName: applicationName,
                bounds: resolvedWindow?.bounds ?? bounds,
                applicationIcon: icon,
                applicationElement: applicationElement,
                windowElement: windowElement,
                thumbnail: nil
            )
        }

        guard scope == .allActiveWindows else { return windowEntries }
        let representedProcesses = Set(windowEntries.map(\.processID))
        let applicationEntries: [SwitchableWindow] = NSWorkspace.shared.runningApplications.compactMap {
            application -> SwitchableWindow? in
            let processID = application.processIdentifier
            guard
                !representedProcesses.contains(processID),
                !application.isTerminated,
                application.isFinishedLaunching,
                WindowCatalogFilter.includesApplicationFallback(
                    activationPolicy: application.activationPolicy,
                    scope: scope
                ),
                let applicationName = nonEmpty(application.localizedName)
            else { return nil }

            let icon = applicationIcon(application) ?? NSWorkspace.shared.icon(for: .applicationBundle)
            return SwitchableWindow(
                id: .application(processID),
                windowID: nil,
                processID: processID,
                title: applicationName,
                applicationName: applicationName,
                bounds: .zero,
                applicationIcon: icon,
                applicationElement: AXUIElementCreateApplication(processID),
                windowElement: nil,
                thumbnail: nil
            )
        }
        return windowEntries + applicationEntries
    }

    func activate(_ window: SwitchableWindow) throws {
        guard let application = NSRunningApplication(processIdentifier: window.processID) else {
            throw WindowCatalogError.applicationUnavailable
        }

        guard let target = window.windowElement, let windowID = window.windowID else {
            guard application.activate(options: [.activateAllWindows]) else {
                throw WindowCatalogError.applicationUnavailable
            }
            return
        }

        // Use the exact AX window retained when the gesture began. Re-enumerating here and
        // matching by a mutable title or frame made release unreliable when a window moved,
        // changed title, or an application exposed several similar windows.
        let unminimizeResult = AXUIElementSetAttributeValue(
            target,
            kAXMinimizedAttribute as CFString,
            kCFBooleanFalse
        )
        let focusedWindowResult = AXUIElementSetAttributeValue(
            window.applicationElement,
            kAXFocusedWindowAttribute as CFString,
            target
        )
        let mainResult = AXUIElementSetAttributeValue(
            target,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )
        let focusedResult = AXUIElementSetAttributeValue(
            target,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        let windowServerFocused = KFWFocusWindow(window.processID, windowID)
        let finalRaiseResult = AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        KeyFlowLog.actions.info(
            "Window activation pid=\(window.processID, privacy: .public) unminimize=\(unminimizeResult.rawValue, privacy: .public) focusWindow=\(focusedWindowResult.rawValue, privacy: .public) main=\(mainResult.rawValue, privacy: .public) focused=\(focusedResult.rawValue, privacy: .public) windowServer=\(windowServerFocused, privacy: .public) finalRaise=\(finalRaiseResult.rawValue, privacy: .public)"
        )
        let focusedSelectedWindow =
            focusedWindowResult == .success
            && (mainResult == .success || focusedResult == .success)
        guard windowServerFocused && (finalRaiseResult == .success || focusedSelectedWindow) else {
            throw WindowCatalogError.windowUnavailable
        }
    }

    private func resolvedWindow(
        candidates: [AXUIElement],
        excluding claimedWindows: [AXUIElement],
        title: String,
        bounds: CGRect
    ) -> (element: AXUIElement, bounds: CGRect)? {
        let unclaimed = candidates.filter { candidate in
            !claimedWindows.contains { claimed in CFEqual(candidate, claimed) }
        }
        let matches = unclaimed.compactMap { candidate -> (AXUIElement, CGRect, Double)? in
            guard
                let candidateBounds = accessibilityBounds(candidate),
                WindowGeometryMatcher.matches(accessibility: candidateBounds, windowServer: bounds)
            else { return nil }
            return (
                candidate,
                candidateBounds,
                score(candidate, candidateBounds: candidateBounds, title: title, bounds: bounds)
            )
        }
        guard let best = matches.max(by: { $0.2 < $1.2 }) else { return nil }
        return (best.0, best.1)
    }

    private func windows(of applicationElement: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                applicationElement,
                kAXWindowsAttribute as CFString,
                &value
            ) == .success,
            let windows = value as? [AXUIElement]
        else { return [] }
        return windows
    }

    private func score(
        _ element: AXUIElement,
        candidateBounds: CGRect,
        title: String,
        bounds: CGRect
    ) -> Double {
        var score = attributeString(element, kAXTitleAttribute as CFString) == title ? 25.0 : 0
        score -= abs(candidateBounds.origin.x - bounds.origin.x)
        score -= abs(candidateBounds.origin.y - bounds.origin.y)
        score -= abs(candidateBounds.width - bounds.width)
        score -= abs(candidateBounds.height - bounds.height)
        return score
    }

    private func accessibilityBounds(_ element: AXUIElement) -> CGRect? {
        guard
            let position = attributePoint(element, kAXPositionAttribute as CFString),
            let size = attributeSize(element, kAXSizeAttribute as CFString)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

}

enum WindowCatalogFilter {
    static func includesApplication(
        activationPolicy: NSApplication.ActivationPolicy,
        scope: WindowSwitcherWindowScope
    ) -> Bool {
        switch scope {
        case .standardApplications:
            activationPolicy == .regular
        case .allActiveWindows:
            true
        }
    }

    static func includesWindow(
        layer: Int,
        isOnscreen: Bool,
        activationPolicy: NSApplication.ActivationPolicy,
        bundleIdentifier: String?,
        scope: WindowSwitcherWindowScope
    ) -> Bool {
        guard includesApplication(activationPolicy: activationPolicy, scope: scope) else { return false }
        if activationPolicy == .regular { return layer == 0 }
        guard scope == .allActiveWindows, isOnscreen, layer >= 0 else { return false }

        // Dock tiles, Control Center panels (including the volume HUD),
        // Notification Center, and other macOS shell surfaces are windows at
        // the WindowServer level, but they are not user-switchable app windows.
        // Finder and other normal Apple apps remain eligible through the
        // regular-application branch above.
        if bundleIdentifier?.hasPrefix("com.apple.") == true { return false }
        return true
    }

    static func includesApplicationFallback(
        activationPolicy: NSApplication.ActivationPolicy,
        scope: WindowSwitcherWindowScope
    ) -> Bool {
        scope == .allActiveWindows && activationPolicy == .regular
    }
}

enum WindowGeometryMatcher {
    static func matches(accessibility: CGRect, windowServer: CGRect) -> Bool {
        let originTolerance: CGFloat = 24
        let widthTolerance = max(24, accessibility.width * 0.04)
        let heightTolerance = max(24, accessibility.height * 0.04)
        return abs(accessibility.origin.x - windowServer.origin.x) <= originTolerance
            && abs(accessibility.origin.y - windowServer.origin.y) <= originTolerance
            && abs(accessibility.width - windowServer.width) <= widthTolerance
            && abs(accessibility.height - windowServer.height) <= heightTolerance
    }
}

extension SystemWindowCatalog {
    private func attributeString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func attributePoint(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func attributeSize(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

    private func applicationIcon(_ application: NSRunningApplication) -> NSImage? {
        if let icon = application.icon { return icon }
        guard let bundleURL = application.bundleURL else { return nil }
        return NSWorkspace.shared.icon(forFile: bundleURL.path)
    }

    private func number(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
