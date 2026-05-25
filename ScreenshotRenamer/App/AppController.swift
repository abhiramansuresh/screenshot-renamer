import AppKit
import Foundation

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()
    static let appDisplayName = "Screen Renamer"
    static let menuBarItemVisibleKey = "MenuBarItemVisible"
    static let launchAtStartupKey = "LaunchAtStartup"
    static let renameCountKey = "RenameCount"
    static let lastRenamedFileNameKey = "LastRenamedFileName"
    static let lastRenamedAtKey = "LastRenamedAt"

    @Published private(set) var isPaused = false
    @Published private(set) var lastStatus = "Starting..."
    @Published private(set) var renameCount = UserDefaults.standard.integer(forKey: renameCountKey)
    @Published private(set) var lastRenamedFileName = UserDefaults.standard.string(forKey: lastRenamedFileNameKey)
    @Published private(set) var lastRenamedAt = UserDefaults.standard.object(forKey: lastRenamedAtKey) as? Date
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var isPausedIndefinitely = false
    @Published private(set) var watchedLocationSummary = "Desktop"
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var launchAtStartupPreferred = AppController.storedLaunchAtStartupPreference()
    @Published private(set) var launchAtStartupEnabled = false
    @Published private(set) var launchAtStartupNeedsApproval = false
    @Published private(set) var launchAtStartupAvailable = true
    @Published private(set) var loginItemStatus = "Checking..."
    @Published private var menuClock = Date()

    private var didStart = false
    private let contextTracker = ContextTracker()
    private let permissionManager = PermissionManager.shared
    private let loginItemManager = LoginItemManager.shared
    private var didStartServices = false
    private var didPresentStartupAccessibilityPrompt = false
    private var didAttemptLaunchAtStartupSync = false
    private var startupPermissionStage: StartupPermissionStage?
    private var startupPermissionTimer: Timer?
    private var pauseTimer: Timer?
    private var menuClockTimer: Timer?

    private lazy var screenshotWatcher = ScreenshotWatcher(
        contextTracker: contextTracker,
        onStatusChange: { [weak self] status in
            self?.lastStatus = status
        },
        onLocationsChange: { [weak self] locations in
            self?.watchedLocationSummary = Self.locationSummary(for: locations)
        },
        onRenameCompleted: { [weak self] destinationURL in
            self?.recordRename(to: destinationURL)
        }
    )

    private init() {
        startMenuClockTimer()
    }

    var lastRenamedSummary: String {
        _ = menuClock

        guard let lastRenamedFileName else {
            return "Last renamed: None yet"
        }

        guard let lastRenamedAt else {
            return "Last renamed: \(lastRenamedFileName)"
        }

        return "Last renamed: \(lastRenamedFileName)  •  \(shortRelativeTime(since: lastRenamedAt))"
    }

    var renameCountSummary: String {
        let formattedCount = Self.countFormatter.string(from: NSNumber(value: renameCount)) ?? "\(renameCount)"
        let noun = renameCount == 1 ? "screenshot" : "screenshots"
        return "\(formattedCount) \(noun) renamed"
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        refreshPermissionStatuses()
        continueStartupPermissionSequence()
    }

    func togglePause() {
        if isPaused {
            resumeRenaming()
        } else {
            pauseRenamingIndefinitely()
        }
    }

    func pauseRenamingForFiveMinutes() {
        pauseRenaming(until: Date().addingTimeInterval(5 * 60))
    }

    func pauseRenamingForOneHour() {
        pauseRenaming(until: Date().addingTimeInterval(60 * 60))
    }

    func pauseRenamingUntilTomorrow() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(24 * 60 * 60)
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 0
        components.second = 0

        let resumeDate = calendar.date(from: components) ?? tomorrow
        pauseRenaming(until: resumeDate)
    }

    func pauseRenamingIndefinitely() {
        pauseTimer?.invalidate()
        pauseTimer = nil
        pausedUntil = nil
        isPausedIndefinitely = true
        isPaused = true
        screenshotWatcher.pause()
        lastStatus = "Paused indefinitely"
    }

    func resumeRenaming() {
        guard isPaused else { return }

        pauseTimer?.invalidate()
        pauseTimer = nil
        pausedUntil = nil
        isPausedIndefinitely = false
        isPaused = false
        screenshotWatcher.resume()
    }

    func openAccessibilitySettings() {
        if permissionManager.isAccessibilityTrusted {
            permissionManager.openAccessibilitySettings()
        } else {
            permissionManager.presentAccessibilityRepairHelp()
        }

        refreshStatuses()
    }

    func refreshStatuses() {
        refreshPermissionStatuses()

        if didStartServices {
            screenshotWatcher.refreshLocations()
        } else {
            updatePendingStartupStatus()
        }

        continueStartupPermissionSequence()
    }

    func setLaunchAtStartup(_ enabled: Bool) {
        launchAtStartupPreferred = enabled
        UserDefaults.standard.set(enabled, forKey: Self.launchAtStartupKey)

        do {
            try loginItemManager.syncLaunchAtStartup(isEnabled: enabled)
            lastStatus = enabled ? "Launch at startup enabled" : "Launch at startup disabled"
        } catch {
            lastStatus = "Could not update launch at startup: \(error.localizedDescription)"
        }

        refreshLaunchAtStartupStatus()
        continueStartupPermissionSequence()
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

    private func continueStartupPermissionSequence() {
        guard didStart, !didStartServices else { return }

        refreshPermissionStatuses()

        guard accessibilityTrusted else {
            presentStartupAccessibilityPromptIfNeeded()
            waitForStartupPermission(.accessibility)
            return
        }

        if preferredLaunchAtStartupEnabled {
            syncLaunchAtStartupPreferenceIfNeeded()
            refreshLaunchAtStartupStatus()

            if launchAtStartupNeedsApproval {
                lastStatus = "Waiting for launch at startup approval"
                waitForStartupPermission(.launchAtStartup)
                return
            }
        }

        startServicesAfterPermissions()
    }

    private func presentStartupAccessibilityPromptIfNeeded() {
        guard !didPresentStartupAccessibilityPrompt else { return }
        didPresentStartupAccessibilityPrompt = true
        lastStatus = "Waiting for Accessibility access"
        watchedLocationSummary = "Waiting for permissions"
        permissionManager.presentOnboardingIfNeeded()
        refreshPermissionStatuses()
    }

    private func waitForStartupPermission(_ stage: StartupPermissionStage) {
        guard startupPermissionStage != stage else { return }

        startupPermissionTimer?.invalidate()
        startupPermissionStage = stage

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.continueStartupPermissionSequence()
            }
        }

        startupPermissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startServicesAfterPermissions() {
        guard !didStartServices else { return }

        startupPermissionTimer?.invalidate()
        startupPermissionTimer = nil
        startupPermissionStage = nil
        didStartServices = true

        contextTracker.start()
        screenshotWatcher.start()
    }

    private func refreshPermissionStatuses() {
        accessibilityTrusted = permissionManager.isAccessibilityTrusted
        refreshLaunchAtStartupStatus()
    }

    private func updatePendingStartupStatus() {
        if !accessibilityTrusted {
            lastStatus = "Waiting for Accessibility access"
            watchedLocationSummary = "Waiting for permissions"
        } else if launchAtStartupNeedsApproval {
            lastStatus = "Waiting for launch at startup approval"
            watchedLocationSummary = "Waiting for permissions"
        }
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
        launchAtStartupPreferred
    }

    private func syncLaunchAtStartupPreference() {
        do {
            try loginItemManager.syncLaunchAtStartup(isEnabled: preferredLaunchAtStartupEnabled)
        } catch {
            lastStatus = "Could not enable launch at startup"
        }

        refreshLaunchAtStartupStatus()
    }

    private func syncLaunchAtStartupPreferenceIfNeeded() {
        guard !didAttemptLaunchAtStartupSync else { return }
        didAttemptLaunchAtStartupSync = true
        syncLaunchAtStartupPreference()
    }

    private func refreshLaunchAtStartupStatus() {
        launchAtStartupEnabled = loginItemManager.isEnabled
        launchAtStartupNeedsApproval = loginItemManager.needsApproval
        launchAtStartupAvailable = loginItemManager.isAvailable
        loginItemStatus = loginItemManager.statusDescription

        if launchAtStartupEnabled || launchAtStartupNeedsApproval {
            launchAtStartupPreferred = true
            UserDefaults.standard.set(true, forKey: Self.launchAtStartupKey)
        } else {
            launchAtStartupPreferred = Self.storedLaunchAtStartupPreference()
        }
    }

    private func recordRename(to destinationURL: URL) {
        let displayName = destinationURL.deletingPathExtension().lastPathComponent
        let renamedAt = Date()

        lastRenamedFileName = displayName
        lastRenamedAt = renamedAt
        renameCount += 1

        UserDefaults.standard.set(displayName, forKey: Self.lastRenamedFileNameKey)
        UserDefaults.standard.set(renamedAt, forKey: Self.lastRenamedAtKey)
        UserDefaults.standard.set(renameCount, forKey: Self.renameCountKey)
    }

    private func pauseRenaming(until resumeDate: Date) {
        pauseTimer?.invalidate()
        pausedUntil = resumeDate
        isPausedIndefinitely = false
        isPaused = true
        screenshotWatcher.pause()
        lastStatus = "Paused until \(Self.timeFormatter.string(from: resumeDate))"

        let interval = resumeDate.timeIntervalSinceNow
        guard interval > 0 else {
            resumeRenaming()
            return
        }

        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.resumeRenaming()
            }
        }

        pauseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startMenuClockTimer() {
        menuClockTimer?.invalidate()

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.menuClock = Date()
            }
        }

        menuClockTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func shortRelativeTime(since date: Date) -> String {
        let elapsedSeconds = max(Int(menuClock.timeIntervalSince(date)), 0)

        if elapsedSeconds < 60 {
            return "just now"
        }

        let elapsedMinutes = elapsedSeconds / 60
        if elapsedMinutes < 60 {
            return "\(elapsedMinutes)m ago"
        }

        let elapsedHours = elapsedMinutes / 60
        if elapsedHours < 24 {
            return "\(elapsedHours)h ago"
        }

        let elapsedDays = elapsedHours / 24
        return "\(elapsedDays)d ago"
    }

    private static func storedLaunchAtStartupPreference() -> Bool {
        if UserDefaults.standard.object(forKey: launchAtStartupKey) == nil {
            return true
        }

        return UserDefaults.standard.bool(forKey: launchAtStartupKey)
    }

    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum StartupPermissionStage {
    case accessibility
    case launchAtStartup
}
