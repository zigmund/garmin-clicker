import ServiceManagement

/// Registers the app itself as a login item.
enum LaunchAtLogin {
    /// Registered: enabled, or waiting for the user's approval in System
    /// Settings (still needs `unregister()` to turn off).
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: true
        case .notRegistered, .notFound: false
        @unknown default: false
        }
    }

    static func set(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
