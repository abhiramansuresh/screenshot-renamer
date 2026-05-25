import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    static let shared = LoginItemManager()

    private init() {}

    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Launch at login enabled"
        case .requiresApproval:
            return "Launch at login needs approval"
        case .notRegistered:
            return "Launch at login not registered"
        case .notFound:
            return "Launch item unavailable"
        @unknown default:
            return "Launch at login unknown"
        }
    }

    func enableAtLoginIfNeeded() {
        guard SMAppService.mainApp.status == .notRegistered else { return }

        do {
            try SMAppService.mainApp.register()
        } catch {
            // Debug builds outside /Applications can fail here; the app still works normally.
        }
    }
}
