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
        guard !UserDefaults.standard.bool(forKey: onboardingKey) else {
            requestPermissionPrompt()
            return
        }

        UserDefaults.standard.set(true, forKey: onboardingKey)

        let alert = NSAlert()
        alert.messageText = "Enable Accessibility Access"
        alert.informativeText = "Screen Renamer needs Accessibility access to detect the active app and window title for each screenshot."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            requestPermissionPrompt()
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
