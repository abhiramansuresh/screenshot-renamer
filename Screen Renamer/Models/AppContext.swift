import Foundation

struct AppContext: Equatable {
    static let privacyRestrictedOCRApps: Set<String> = [
        "discord",
        "messages",
        "microsoft teams",
        "slack",
        "teams",
        "whatsapp"
    ]

    let timestamp: Date
    let appName: String
    let windowTitle: String?
    let documentName: String?
    let tabName: String?
    let browserDomain: String?
    let browserPageURL: String?

    init(
        timestamp: Date,
        appName: String,
        windowTitle: String?,
        documentName: String? = nil,
        tabName: String? = nil,
        browserDomain: String? = nil,
        browserPageURL: String? = nil
    ) {
        self.timestamp = timestamp
        self.appName = appName
        self.windowTitle = windowTitle
        self.documentName = documentName
        self.tabName = tabName
        self.browserDomain = browserDomain
        self.browserPageURL = browserPageURL
    }

    var isPrivacyRestrictedOCRApp: Bool {
        Self.privacyRestrictedOCRApps.contains(
            appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }
}
