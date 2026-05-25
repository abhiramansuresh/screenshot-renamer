import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        Text(controller.isPaused ? "Screenshot Renamer Paused" : "Screenshot Renamer ✓")
        Text(controller.lastStatus)
        Text("Watching: \(controller.watchedLocationSummary)")
        Text(controller.loginItemStatus)

        if !controller.accessibilityTrusted {
            Divider()
            Button("Enable Accessibility Access") {
                controller.openAccessibilitySettings()
            }
        }

        Divider()

        Button(controller.isPaused ? "Resume Renaming" : "Pause Renaming") {
            controller.togglePause()
        }

        Button("Refresh Status") {
            controller.refreshStatuses()
        }

        Button("Hide Menu Bar Icon") {
            controller.hideMenuBarItem()
        }

        Divider()

        Button("Quit") {
            controller.quit()
        }
        .keyboardShortcut("q")
    }
}
