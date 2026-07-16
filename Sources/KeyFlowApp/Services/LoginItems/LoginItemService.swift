import ServiceManagement

@MainActor
protocol LoginItemServicing {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
protocol LoginItemRegistration: AnyObject {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItemService: LoginItemServicing {
    private let registration: any LoginItemRegistration

    init(registration: (any LoginItemRegistration)? = nil) {
        self.registration = registration ?? MainApplicationLoginItemRegistration()
    }

    var isEnabled: Bool { registration.isEnabled }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try registration.register()
        } else {
            try registration.unregister()
        }
    }
}

@MainActor
final class MainApplicationLoginItemRegistration: LoginItemRegistration {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}
