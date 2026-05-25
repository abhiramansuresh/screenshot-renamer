import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ContextTracker {
    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var isTracking = false
    private var buffer: [AppContext] = []
    private var lastLoggedContextSignature: ContextSignature?
    private let activationSettleDelays: [TimeInterval] = [0.05, 0.15]
    private let maxContextAge: TimeInterval = 10
    private let maxEntryCount = 80
    private let browserNames = [
        "Arc",
        "Brave Browser",
        "Chrome",
        "Chromium",
        "Firefox",
        "Google Chrome",
        "Microsoft Edge",
        "Opera",
        "Safari"
    ]

    func start() {
        guard !isTracking else { return }
        isTracking = true

        captureCurrentContext()
        startActivationObserver()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureCurrentContext()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stopActivationObserver()
        isTracking = false
        buffer.removeAll()
    }

    func context(closestTo date: Date) -> AppContext? {
        ContextMatcher.nearestContext(in: buffer, to: date)
    }

    func context(during interval: DateInterval, referenceDate: Date?) -> AppContext? {
        ContextMatcher.bestContext(in: buffer, during: interval, referenceDate: referenceDate)
    }

    func context(before date: Date) -> AppContext? {
        ContextMatcher.latestContext(in: buffer, before: date)
    }

    private func captureCurrentContext() {
        captureContext(for: NSWorkspace.shared.frontmostApplication)
    }

    private func captureContext(for application: NSRunningApplication?) {
        let timestamp = Date()
        let appName = application?.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isBrowserApp = appName.map { isBrowser($0) } == true
        let details = application.map { windowContextDetails(for: $0.processIdentifier, appName: appName) }

        let context = AppContext(
            timestamp: timestamp,
            appName: appName?.isEmpty == false ? appName! : "Unknown",
            windowTitle: details?.windowTitle,
            tabName: details?.tabName,
            browserDomain: details?.browserDomain
        )

        buffer.append(context)
        pruneBuffer(relativeTo: timestamp)
        logContextCaptureIfChanged(
            context,
            isBrowser: isBrowserApp,
            windowFound: details?.windowFound ?? false,
            processIdentifier: application?.processIdentifier
        )
    }

    private func startActivationObserver() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self, self.isTracking else { return }
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    self.captureCurrentContext()
                    self.scheduleSettledActivationCapture(for: nil)
                    return
                }

                self.captureContext(for: application)
                self.scheduleSettledActivationCapture(for: application)
            }
        }
    }

    private func stopActivationObserver() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }

        activationObserver = nil
    }

    private func scheduleSettledActivationCapture(for application: NSRunningApplication?) {
        for delay in activationSettleDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, application] in
                guard let self, self.isTracking else { return }

                if let application {
                    guard application.isActive else { return }
                    self.captureContext(for: application)
                } else {
                    self.captureCurrentContext()
                }
            }
        }
    }

    private func windowContextDetails(for processIdentifier: pid_t, appName: String?) -> WindowContextDetails {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        guard let windowElement = focusedWindow(for: appElement) else {
            return WindowContextDetails(windowFound: false, windowTitle: nil, tabName: nil, browserDomain: nil)
        }

        return WindowContextDetails(
            windowFound: true,
            windowTitle: title(for: windowElement),
            tabName: selectedTabTitle(in: windowElement),
            browserDomain: appName.map { isBrowser($0) } == true
                ? browserDomain(in: windowElement)
                : nil
        )
    }

    private func isBrowser(_ appName: String) -> Bool {
        browserNames.contains { $0.caseInsensitiveCompare(appName) == .orderedSame }
    }

    private func focusedWindow(for appElement: AXUIElement) -> AXUIElement? {
        var focusedWindowValue: CFTypeRef?

        let focusedWindowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )

        guard focusedWindowResult == .success, let focusedWindowValue else {
            return mainWindow(for: appElement)
        }

        return (focusedWindowValue as! AXUIElement)
    }

    private func mainWindow(for appElement: AXUIElement) -> AXUIElement? {
        var mainWindowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &mainWindowValue
        )

        guard result == .success, let mainWindowValue else { return nil }
        return (mainWindowValue as! AXUIElement)
    }

    private func title(for windowElement: AXUIElement) -> String? {
        for attribute in [kAXTitleAttribute as CFString, "AXDocument" as CFString] {
            guard let title = string(for: attribute, of: windowElement), !title.isEmpty else {
                continue
            }

            return title
        }

        return nil
    }

    private func selectedTabTitle(in rootElement: AXUIElement) -> String? {
        var inspectedNodeCount = 0
        return selectedTabTitle(in: rootElement, depthRemaining: 8, inspectedNodeCount: &inspectedNodeCount)
    }

    private func selectedTabTitle(
        in element: AXUIElement,
        depthRemaining: Int,
        inspectedNodeCount: inout Int
    ) -> String? {
        guard depthRemaining >= 0, inspectedNodeCount < 250 else { return nil }
        inspectedNodeCount += 1

        let elementRole = role(for: element)

        if isSelected(element),
           isTabCandidateRole(elementRole),
           let title = title(for: element),
           !title.isEmpty {
            return title
        }

        if elementRole == kAXTabGroupRole as String {
            if let selectedChildTitle = selectedChildTitle(in: element) {
                return selectedChildTitle
            }

            if let selectedTabTitle = selectedTabTitleFromChildren(in: element) {
                return selectedTabTitle
            }
        }

        guard !shouldPruneTabSearch(for: elementRole) else { return nil }

        for child in childElements(of: element) {
            if let selectedTabTitle = selectedTabTitle(
                in: child,
                depthRemaining: depthRemaining - 1,
                inspectedNodeCount: &inspectedNodeCount
            ) {
                return selectedTabTitle
            }
        }

        return nil
    }

    private func isTabCandidateRole(_ role: String?) -> Bool {
        guard let role else { return false }
        return [
            "AXButton",
            "AXRadioButton",
            "AXTab"
        ].contains(role)
    }

    private func shouldPruneTabSearch(for role: String?) -> Bool {
        guard let role else { return false }
        return [
            "AXOutline",
            "AXScrollArea",
            "AXTable",
            "AXTextArea",
            "AXWebArea"
        ].contains(role)
    }

    private func selectedChildTitle(in element: AXUIElement) -> String? {
        for child in elements(for: kAXSelectedChildrenAttribute as CFString, of: element) {
            if let title = title(for: child), !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private func selectedTabTitleFromChildren(in element: AXUIElement) -> String? {
        for child in childElements(of: element) where isSelected(child) {
            if let title = title(for: child), !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private func childElements(of element: AXUIElement) -> [AXUIElement] {
        elements(for: kAXChildrenAttribute as CFString, of: element)
            + elements(for: "AXTabs" as CFString, of: element)
    }

    private func elements(for attribute: CFString, of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func role(for element: AXUIElement) -> String? {
        var roleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        guard result == .success else { return nil }
        return roleValue as? String
    }

    private func isSelected(_ element: AXUIElement) -> Bool {
        var selectedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedAttribute as CFString, &selectedValue)
        guard result == .success else { return false }
        return selectedValue as? Bool ?? false
    }

    private func browserDomain(in rootElement: AXUIElement) -> String? {
        guard let urlString = browserURL(in: rootElement) else { return nil }
        return browserDomain(from: urlString)
    }

    private func browserURL(in rootElement: AXUIElement) -> String? {
        var webContentNodeCount = 0
        if let url = browserURLFromWebContent(
            in: rootElement,
            depthRemaining: 10,
            inspectedNodeCount: &webContentNodeCount
        ) {
            return url
        }

        var addressFieldNodeCount = 0
        return browserURLFromAddressField(
            in: rootElement,
            depthRemaining: 10,
            inspectedNodeCount: &addressFieldNodeCount
        )
    }

    private func browserURLFromWebContent(
        in element: AXUIElement,
        depthRemaining: Int,
        inspectedNodeCount: inout Int
    ) -> String? {
        guard depthRemaining >= 0, inspectedNodeCount < 350 else { return nil }
        inspectedNodeCount += 1

        let elementRole = role(for: element)

        if let url = string(for: "AXURL" as CFString, of: element),
           let browserURL = normalizedBrowserURL(url) {
            return browserURL
        }

        guard !shouldPruneBrowserURLSearch(for: elementRole) else { return nil }

        for child in childElements(of: element) {
            if let url = browserURLFromWebContent(
                in: child,
                depthRemaining: depthRemaining - 1,
                inspectedNodeCount: &inspectedNodeCount
            ) {
                return url
            }
        }

        return nil
    }

    private func shouldPruneBrowserURLSearch(for role: String?) -> Bool {
        guard let role else { return false }
        return [
            "AXOutline",
            "AXTable",
            "AXTextArea",
            "AXWebArea"
        ].contains(role)
    }

    private func browserURLFromAddressField(
        in element: AXUIElement,
        depthRemaining: Int,
        inspectedNodeCount: inout Int
    ) -> String? {
        guard depthRemaining >= 0, inspectedNodeCount < 250 else { return nil }
        inspectedNodeCount += 1

        let elementRole = role(for: element)

        if isAddressFieldCandidateRole(elementRole),
           let value = string(for: kAXValueAttribute as CFString, of: element),
           let url = normalizedBrowserURL(value) {
            return url
        }

        guard !shouldPruneAddressFieldSearch(for: elementRole) else { return nil }

        for child in childElements(of: element) {
            if let url = browserURLFromAddressField(
                in: child,
                depthRemaining: depthRemaining - 1,
                inspectedNodeCount: &inspectedNodeCount
            ) {
                return url
            }
        }

        return nil
    }

    private func isAddressFieldCandidateRole(_ role: String?) -> Bool {
        guard let role else { return false }
        return [
            "AXComboBox",
            "AXSearchField",
            "AXTextField"
        ].contains(role)
    }

    private func shouldPruneAddressFieldSearch(for role: String?) -> Bool {
        guard let role else { return false }
        return [
            "AXOutline",
            "AXScrollArea",
            "AXTable",
            "AXTextArea",
            "AXWebArea"
        ].contains(role)
    }

    private func string(for attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }

        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let url = value as? URL {
            return url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func normalizedBrowserURL(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedValue = trimmedValue.lowercased()
        guard !trimmedValue.isEmpty else { return nil }

        if lowercasedValue.hasPrefix("http://") || lowercasedValue.hasPrefix("https://") {
            return browserDomain(from: trimmedValue) == nil ? nil : trimmedValue
        }

        guard !trimmedValue.contains("://"),
              trimmedValue.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              looksLikeDomainOrLocalHost(trimmedValue) else {
            return nil
        }

        let urlString = "https://\(trimmedValue)"
        return browserDomain(from: urlString) == nil ? nil : urlString
    }

    private func looksLikeDomainOrLocalHost(_ value: String) -> Bool {
        let hostCandidate = value
            .components(separatedBy: CharacterSet(charactersIn: "/?#"))
            .first?
            .components(separatedBy: ":")
            .first?
            .lowercased()

        guard let hostCandidate, !hostCandidate.isEmpty else { return false }
        return hostCandidate == "localhost" || hostCandidate.contains(".")
    }

    private func browserDomain(from urlString: String) -> String? {
        guard let components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host else {
            return nil
        }

        return normalizedBrowserDomain(from: host)
    }

    private func normalizedBrowserDomain(from host: String) -> String? {
        let host = host
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !host.isEmpty else { return nil }
        if host == "localhost" { return host }

        var parts = host.split(separator: ".").map(String.init)
        while parts.count > 1, ["app", "m", "mobile", "web", "www"].contains(parts[0]) {
            parts.removeFirst()
        }

        let normalizedHost = parts.joined(separator: ".")
        return normalizedHost.contains(".") ? normalizedHost : nil
    }

    private func pruneBuffer(relativeTo date: Date) {
        buffer.removeAll { date.timeIntervalSince($0.timestamp) > maxContextAge }

        if buffer.count > maxEntryCount {
            buffer.removeFirst(buffer.count - maxEntryCount)
        }
    }

    private func logContextCaptureIfChanged(
        _ context: AppContext,
        isBrowser: Bool,
        windowFound: Bool,
        processIdentifier: pid_t?
    ) {
        let signature = ContextSignature(
            appName: context.appName,
            windowTitle: context.windowTitle,
            tabName: context.tabName,
            browserDomain: context.browserDomain
        )

        guard signature != lastLoggedContextSignature else { return }
        lastLoggedContextSignature = signature

        ScreenshotDebugLogger.log("context_captured", fields: [
            "app": context.appName,
            "ax_trusted": "\(AXIsProcessTrusted())",
            "browser_domain": context.browserDomain ?? "",
            "is_browser": "\(isBrowser)",
            "pid": processIdentifier.map(String.init) ?? "",
            "tab_name": context.tabName ?? "",
            "window_found": "\(windowFound)",
            "window_title": context.windowTitle ?? ""
        ])
    }
}

private struct WindowContextDetails {
    let windowFound: Bool
    let windowTitle: String?
    let tabName: String?
    let browserDomain: String?
}

private struct ContextSignature: Equatable {
    let appName: String
    let windowTitle: String?
    let tabName: String?
    let browserDomain: String?
}
