import AppKit
import Foundation

struct ApplicationSelection: Identifiable {
    let url: URL
    let bundleIdentifier: String?
    let name: String
    let icon: NSImage

    var id: String { bundleIdentifier ?? url.path }

    static func resolve(storedValue: String) -> ApplicationSelection? {
        let value = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let url =
            value.hasPrefix("/")
            ? URL(fileURLWithPath: value)
            : NSWorkspace.shared.urlForApplication(withBundleIdentifier: value)
        guard let url else { return nil }
        return selection(for: url)
    }

    static func selection(for url: URL) -> ApplicationSelection? {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else { return nil }
        let bundle = Bundle(url: standardizedURL)
        let name =
            bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? standardizedURL.deletingPathExtension().lastPathComponent
        return ApplicationSelection(
            url: standardizedURL,
            bundleIdentifier: bundle?.bundleIdentifier,
            name: name,
            icon: NSWorkspace.shared.icon(forFile: standardizedURL.path)
        )
    }
}
