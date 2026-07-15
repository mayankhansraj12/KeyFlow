import AppKit

@MainActor
protocol ApplicationPresentationControlling: AnyObject {
    var isHiddenFromDock: Bool { get }
    func prepareHiddenFromDock(_ hidden: Bool)
    func relaunch() throws
}

enum ApplicationPresentationDefaults {
    static let hideFromDockKey = "application.hideFromDock"

    static var shouldHideFromDockAtLaunch: Bool {
        UserDefaults.standard.bool(forKey: hideFromDockKey)
    }
}

@MainActor
final class SystemApplicationPresentationController: ApplicationPresentationControlling {
    var isHiddenFromDock: Bool {
        NSApp.activationPolicy() == .accessory
    }

    func prepareHiddenFromDock(_ hidden: Bool) {
        UserDefaults.standard.set(hidden, forKey: ApplicationPresentationDefaults.hideFromDockKey)
    }

    func relaunch() throws {
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        launcher.arguments = ["-n", Bundle.main.bundleURL.path]
        try launcher.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSApp.terminate(nil)
        }
    }
}

final class KeyFlowApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_: Notification) {
        guard ApplicationPresentationDefaults.shouldHideFromDockAtLaunch else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
