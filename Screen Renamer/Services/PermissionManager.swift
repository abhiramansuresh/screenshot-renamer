import AppKit
import ApplicationServices
import Foundation

@MainActor
final class PermissionManager {
    static let shared = PermissionManager()

    private let onboardingKey = "HasShownAccessibilityOnboarding"

    private init() {}

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func presentOnboardingIfNeeded() {
        guard !isAccessibilityTrusted else { return }

        if UserDefaults.standard.bool(forKey: onboardingKey) {
            presentAccessibilityRepairHelp()
            return
        }

        UserDefaults.standard.set(true, forKey: onboardingKey)

        let alert = NSAlert()
        alert.messageText = "Enable Accessibility Access"
        alert.informativeText = "Screen Renamer needs Accessibility access to read the active app and window title when you take a screenshot. This context is used only on this Mac to create better filenames."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            requestPermissionPrompt()
            openAccessibilitySettings()
        }
    }

    func presentAccessibilityRepairHelp() {
        guard !isAccessibilityTrusted else { return }

        let alert = NSAlert()
        alert.messageText = "Accessibility Access Needed"
        alert.informativeText = "If Screen Renamer is already enabled in Privacy & Security, macOS may be holding permission for an older copy of the app. Remove the existing Screen Renamer entry, then add this app again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    func requestPermissionPrompt() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
