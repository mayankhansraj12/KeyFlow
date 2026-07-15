import ServiceManagement

@MainActor
protocol LoginItemServicing {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct SystemLoginItemService: LoginItemServicing {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
