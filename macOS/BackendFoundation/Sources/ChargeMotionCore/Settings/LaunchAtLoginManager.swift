import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginManager {
    public init() {}

    public var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    public var isEnabled: Bool {
        status == .enabled
    }

    public func enable() throws {
        guard !isEnabled else { return }
        try SMAppService.mainApp.register()
    }

    public func disable() throws {
        guard isEnabled else { return }
        try SMAppService.mainApp.unregister()
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try self.enable()
        } else {
            try self.disable()
        }
    }
}
