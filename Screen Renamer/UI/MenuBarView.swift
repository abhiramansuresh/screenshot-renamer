import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var controller: AppController

    var body: some View {
        appHeader

        pauseMenuItems

        Toggle(launchAtStartupTitle, isOn: launchAtStartupBinding)

        Divider()

        debugMenuItems

        Button("Quit") {
            controller.quit()
        }
        .keyboardShortcut("q")
    }

    @ViewBuilder
    private var appHeader: some View {
        Label {
            Text(AppController.appDisplayName)
                .font(.system(size: 15, weight: .semibold))
        } icon: {
            Image(controller.isPaused ? "MenuBarPausedIcon" : "MenuBarIcon")
                .renderingMode(.template)
                .foregroundStyle(.primary)
        }
        .foregroundStyle(.primary)

        Text("No internet access | Runs 100% locally")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

        Divider()

        Text(controller.lastRenamedSummary)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

        Text(controller.renameCountSummary)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

        Divider()
    }

    @ViewBuilder
    private var pauseMenuItems: some View {
        if controller.isPaused {
            Button("Resume Renaming") {
                controller.resumeRenaming()
            }
        } else {
            Menu("Pause Renaming") {
                Button("Pause for 5 minutes") {
                    controller.pauseRenamingForFiveMinutes()
                }

                Button("Pause for 1 hour") {
                    controller.pauseRenamingForOneHour()
                }

                Button("Pause until tomorrow") {
                    controller.pauseRenamingUntilTomorrow()
                }

                Button("Pause indefinitely") {
                    controller.pauseRenamingIndefinitely()
                }
            }
        }
    }

    private var launchAtStartupTitle: String {
        "Launch at Startup"
    }

    private var launchAtStartupBinding: Binding<Bool> {
        Binding {
            controller.launchAtStartupPreferred
        } set: { isEnabled in
            controller.setLaunchAtStartup(isEnabled)
        }
    }

    @ViewBuilder
    private var debugMenuItems: some View {
        #if DEBUG
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
