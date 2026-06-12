import Foundation

struct AppContext: Equatable {
    let timestamp: Date
    let appName: String
    let windowTitle: String?
    let documentName: String?
    let tabName: String?
    let browserDomain: String?

    init(
        timestamp: Date,
        appName: String,
        windowTitle: String?,
        documentName: String? = nil,
        tabName: String? = nil,
        browserDomain: String? = nil
    ) {
        self.timestamp = timestamp
        self.appName = appName
        self.windowTitle = windowTitle
        self.documentName = documentName
        self.tabName = tabName
        self.browserDomain = browserDomain
    }
}
