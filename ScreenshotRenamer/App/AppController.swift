import AppKit
import Foundation

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()
    static let menuBarItemVisibleKey = "MenuBarItemVisible"

    @Published private(set) var isPaused = false
    @Published private(set) var lastStatus = "Starting..."
    @Published private(set) var watchedLocationSummary = "Desktop"
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var loginItemStatus = "Checking..."

    private var didStart = false
    private let contextTracker = ContextTracker()
    private let permissionManager = PermissionManager.shared
    private let loginItemManager = LoginItemManager.shared

    private lazy var screenshotWatcher = ScreenshotWatcher(
        contextTracker: contextTracker,
        onStatusChange: { [weak self] status in
            self?.lastStatus = status
        },
        onLocationsChange: { [weak self] locations in
            self?.watchedLocationSummary = Self.locationSummary(for: locations)
        }
    )

    private init() {}

    func start() {
        guard !didStart else { return }
        didStart = true

        refreshStatuses()
        permissionManager.presentOnboardingIfNeeded()
        loginItemManager.enableAtLoginIfNeeded()
        refreshStatuses()

        contextTracker.start()
        screenshotWatcher.start()
    }

    func togglePause() {
        if isPaused {
            isPaused = false
            screenshotWatcher.resume()
        } else {
            isPaused = true
            screenshotWatcher.pause()
        }
    }

    func openAccessibilitySettings() {
        permissionManager.requestPermissionPrompt()
        permissionManager.openAccessibilitySettings()
        refreshStatuses()
    }

    func refreshStatuses() {
        accessibilityTrusted = permissionManager.isAccessibilityTrusted
        loginItemStatus = loginItemManager.statusDescription
        screenshotWatcher.refreshLocations()
    }

    func hideMenuBarItem() {
        let alert = NSAlert()
        alert.messageText = "Hide Menu Bar Icon?"
        alert.informativeText = "Screenshot Renamer will keep running in the background. Open the app again while it is running to show the icon. If you quit the app first, hold Option while opening it to restore the icon."
        alert.addButton(withTitle: "Hide Icon")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        UserDefaults.standard.set(false, forKey: Self.menuBarItemVisibleKey)
        lastStatus = "Menu bar icon hidden"
    }

    func showMenuBarItem() {
        UserDefaults.standard.set(true, forKey: Self.menuBarItemVisibleKey)
        refreshStatuses()
        lastStatus = isPaused ? "Renaming paused" : "Menu bar icon shown"
    }

    func restoreMenuBarItemIfRequestedAtLaunch() {
        guard NSEvent.modifierFlags.contains(.option) else { return }
        showMenuBarItem()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private static func locationSummary(for locations: [URL]) -> String {
        guard !locations.isEmpty else { return "No folders" }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        return locations
            .map { url in
                let path = url.standardizedFileURL.path
                if path.hasPrefix(homePath) {
                    return "~" + path.dropFirst(homePath.count)
                }
                return path
            }
            .joined(separator: ", ")
    }
}
