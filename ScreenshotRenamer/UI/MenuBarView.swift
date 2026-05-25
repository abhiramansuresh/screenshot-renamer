import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        appHeader

        Button(controller.isPaused ? "Unpause Screen Renamer" : "Pause Screen Renamer") {
            controller.togglePause()
        }

        Button("Hide Menu Bar Icon") {
            controller.hideMenuBarItem()
        }

        Toggle(launchAtStartupTitle, isOn: launchAtStartupBinding)
            .disabled(!controller.launchAtStartupAvailable)

        debugMenuItems

        Divider()

        Button("Quit") {
            controller.quit()
        }
        .keyboardShortcut("q")
    }

    private var appHeader: some View {
        Label {
            Text(AppController.appDisplayName)
        } icon: {
            Image(controller.isPaused ? "MenuBarPausedIcon" : "MenuBarIcon")
        }
    }

    private var launchAtStartupTitle: String {
        controller.launchAtStartupNeedsApproval ? "Launch at Startup (Needs Approval)" : "Launch at Startup"
    }

    private var launchAtStartupBinding: Binding<Bool> {
        Binding {
            controller.launchAtStartupEnabled || controller.launchAtStartupNeedsApproval
        } set: { isEnabled in
            controller.setLaunchAtStartup(isEnabled)
        }
    }

    @ViewBuilder
    private var debugMenuItems: some View {
        #if DEBUG
        Divider()

        Text(controller.lastStatus)
        Text("Watching: \(controller.watchedLocationSummary)")
        Text(controller.loginItemStatus)
        Text(controller.accessibilityTrusted ? "Accessibility: granted" : "Accessibility: missing or stale")
        Text("Build: Debug")

        Button("Refresh Status") {
            controller.refreshStatuses()
        }

        if !controller.accessibilityTrusted {
            Button("Enable Accessibility Access") {
                controller.openAccessibilitySettings()
            }
        }

        Button("Open Debug Log") {
            controller.openDebugLog()
        }

        Button("Clear Debug Log") {
            controller.clearDebugLog()
        }
        #endif
    }
}
