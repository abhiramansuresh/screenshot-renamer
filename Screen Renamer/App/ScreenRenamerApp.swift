import AppKit
import SwiftUI

@main
@MainActor
struct ScreenRenamerApp: App {
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
                menuBarIcon(named: "MenuBarPausedIcon", fallbackSystemName: "pause.circle")
            } else {
                menuBarIcon(named: "MenuBarIcon", fallbackSystemName: "camera.viewfinder")
            }
        }
        .menuBarExtraStyle(.menu)
    }

    @ViewBuilder
    private func menuBarIcon(named name: String, fallbackSystemName: String) -> some View {
        if let image = NSImage(named: name)?.templateCopy {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: fallbackSystemName)
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
