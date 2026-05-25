import AppKit
import SwiftUI

@main
@MainActor
struct ScreenshotRenamerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.shared
    @AppStorage(AppController.menuBarItemVisibleKey) private var isMenuBarItemVisible = true

    init() {
        AppController.shared.restoreMenuBarItemIfRequestedAtLaunch()
        AppController.shared.start()
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $isMenuBarItemVisible) {
            MenuBarView()
                .environmentObject(controller)
                .onAppear {
                    controller.refreshStatuses()
                }
        } label: {
            if controller.isPaused {
                Image(systemName: "pause.circle")
            } else {
                activeMenuBarIcon
            }
        }
        .menuBarExtraStyle(.menu)
    }

    @ViewBuilder
    private var activeMenuBarIcon: some View {
        if let image = NSImage(named: "MenuBarIcon")?.templateCopy {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "camera.viewfinder")
        }
    }
}

private extension NSImage {
    var templateCopy: NSImage {
        guard let image = copy() as? NSImage else {
            isTemplate = true
            return self
        }

        image.isTemplate = true
        return image
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppController.shared.start()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            AppController.shared.showMenuBarItem()
        }

        return false
    }
}
