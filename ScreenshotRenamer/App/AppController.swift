import AppKit
import Foundation

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()
    static let appDisplayName = "Screen Renamer"
    static let menuBarItemVisibleKey = "MenuBarItemVisible"
    static let launchAtStartupKey = "LaunchAtStartup"

    @Published private(set) var isPaused = false
    @Published private(set) var lastStatus = "Starting..."
    @Published private(set) var watchedLocationSummary = "Desktop"
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var launchAtStartupEnabled = false
    @Published private(set) var launchAtStartupNeedsApproval = false
    @Published private(set) var launchAtStartupAvailable = true
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
        syncLaunchAtStartupPreference()
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
        refreshLaunchAtStartupStatus()
        screenshotWatcher.refreshLocations()
    }

    func setLaunchAtStartup(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.launchAtStartupKey)

        do {
            try loginItemManager.syncLaunchAtStartup(isEnabled: enabled)
            lastStatus = enabled ? "Launch at startup enabled" : "Launch at startup disabled"
        } catch {
            lastStatus = "Could not update launch at startup"
        }

        refreshLaunchAtStartupStatus()
    }

    func openDebugLog() {
        do {
            try ScreenshotDebugLogger.ensureLogFileExists()
            NSWorkspace.shared.open(ScreenshotDebugLogger.logURL)
            lastStatus = "Opened debug log"
        } catch {
            lastStatus = "Could not open debug log"
        }
    }

    func clearDebugLog() {
        ScreenshotDebugLogger.clear()
        lastStatus = "Cleared debug log"
    }

    func hideMenuBarItem() {
        let alert = NSAlert()
        alert.messageText = "Hide Menu Bar Icon?"
        alert.informativeText = "Screen Renamer will keep running in the background. Open the app again while it is running to show the icon. If you quit the app first, hold Option while opening it to restore the icon."
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

    private var preferredLaunchAtStartupEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.launchAtStartupKey) == nil {
            return true
        }

        return UserDefaults.standard.bool(forKey: Self.launchAtStartupKey)
    }

    private func syncLaunchAtStartupPreference() {
        do {
            try loginItemManager.syncLaunchAtStartup(isEnabled: preferredLaunchAtStartupEnabled)
        } catch {
            lastStatus = "Could not enable launch at startup"
        }

        refreshLaunchAtStartupStatus()
    }

    private func refreshLaunchAtStartupStatus() {
        launchAtStartupEnabled = loginItemManager.isEnabled
        launchAtStartupNeedsApproval = loginItemManager.needsApproval
        launchAtStartupAvailable = loginItemManager.isAvailable
        loginItemStatus = loginItemManager.statusDescription
    }
}
