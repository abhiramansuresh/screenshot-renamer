import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    static let shared = LoginItemManager()

    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    var isAvailable: Bool {
        SMAppService.mainApp.status != .notFound
    }

    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Launch at startup enabled"
        case .requiresApproval:
            return "Launch at startup needs approval"
        case .notRegistered:
            return "Launch at startup disabled"
        case .notFound:
            return "Launch at startup unavailable"
        @unknown default:
            return "Launch at startup unknown"
        }
    }

    func syncLaunchAtStartup(isEnabled: Bool) throws {
        if isEnabled {
            try enableLaunchAtStartup()
        } else {
            try disableLaunchAtStartup()
        }
    }

    private func enableLaunchAtStartup() throws {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return
        case .notRegistered, .notFound:
            try SMAppService.mainApp.register()
        @unknown default:
            throw LoginItemError.unknownStatus
        }
    }

    private func disableLaunchAtStartup() throws {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            try SMAppService.mainApp.unregister()
        case .notRegistered, .notFound:
            return
        @unknown default:
            throw LoginItemError.unknownStatus
        }
    }
}

private enum LoginItemError: LocalizedError {
    case unknownStatus

    var errorDescription: String? {
        switch self {
        case .unknownStatus:
            return "Launch at startup status is unknown."
        }
    }
}
