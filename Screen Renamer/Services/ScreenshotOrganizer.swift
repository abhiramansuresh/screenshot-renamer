import Foundation

struct ScreenshotOrganizer {
    static let appFolderThreshold = 5

    private let threshold: Int
    private let fileManager: FileManager
    private let filenameGenerator: FilenameGenerator
    private let supportedScreenshotExtensions: Set<String>

    init(
        appFolderThreshold: Int = Self.appFolderThreshold,
        fileManager: FileManager = .default,
        filenameGenerator: FilenameGenerator = FilenameGenerator(),
        supportedScreenshotExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "pdf"]
    ) {
        self.threshold = max(1, appFolderThreshold)
        self.fileManager = fileManager
        self.filenameGenerator = filenameGenerator
        self.supportedScreenshotExtensions = supportedScreenshotExtensions
    }

    func destinationDirectoryURL(for screenshotURL: URL, appName rawAppName: String) -> URL {
        let baseDirectoryURL = screenshotURL.deletingLastPathComponent()

        guard let appIdentity = appIdentity(for: rawAppName) else {
            ScreenshotDebugLogger.log("auto_organize_skipped", fields: [
                "reason": "invalid_app_name",
                "raw_app": rawAppName
            ])
            return baseDirectoryURL
        }

        let organizedDirectoryURL = baseDirectoryURL.appendingPathComponent(appIdentity.folderName, isDirectory: true)
        let existingCount = appScreenshotCount(
            forAppName: appIdentity.filePrefix,
            in: baseDirectoryURL,
            organizedDirectoryURL: organizedDirectoryURL
        )
        let shouldOrganize = existingCount + 1 >= threshold

        ScreenshotDebugLogger.log("auto_organize_evaluated", fields: [
            "app": appIdentity.filePrefix,
            "existing_count": "\(existingCount)",
            "threshold": "\(threshold)",
            "should_organize": "\(shouldOrganize)",
            "folder": appIdentity.folderName
        ])

        guard shouldOrganize else { return baseDirectoryURL }

        do {
            try fileManager.createDirectory(at: organizedDirectoryURL, withIntermediateDirectories: true)
            migrateExistingScreenshots(
                forAppName: appIdentity.filePrefix,
                from: baseDirectoryURL,
                to: organizedDirectoryURL
            )
            return organizedDirectoryURL
        } catch {
            ScreenshotDebugLogger.log("auto_organize_folder_failed", fields: [
                "app": appIdentity.filePrefix,
                "folder": appIdentity.folderName,
                "error": error.localizedDescription
            ])
            return baseDirectoryURL
        }
    }

    private func appIdentity(for rawAppName: String) -> AppFolderIdentity? {
        guard !rawAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let filePrefix = filenameGenerator.normalizedAppName(for: rawAppName)
        guard filePrefix != "Screenshot" else {
            return nil
        }

        return AppFolderIdentity(
            filePrefix: filePrefix,
            folderName: filenameGenerator.organizedFolderName(for: filePrefix)
        )
    }

    private func appScreenshotCount(
        forAppName appName: String,
        in baseDirectoryURL: URL,
        organizedDirectoryURL: URL
    ) -> Int {
        appScreenshotFileURLs(forAppName: appName, in: baseDirectoryURL).count
            + appScreenshotFileURLs(forAppName: appName, in: organizedDirectoryURL).count
    }

    private func migrateExistingScreenshots(
        forAppName appName: String,
        from baseDirectoryURL: URL,
        to organizedDirectoryURL: URL
    ) {
        let screenshots = appScreenshotFileURLs(forAppName: appName, in: baseDirectoryURL)

        // Future organization modes, such as month folders, sessions, or archives,
        // should plug in here after the app threshold has been reached.
        for screenshotURL in screenshots {
            let destinationURL = migrationDestinationURL(for: screenshotURL, in: organizedDirectoryURL)
            guard destinationURL.standardizedFileURL != screenshotURL.standardizedFileURL else { continue }

            do {
                try fileManager.moveItem(at: screenshotURL, to: destinationURL)
                ScreenshotDebugLogger.log("auto_organize_migration_success", fields: [
                    "app": appName,
                    "from": screenshotURL.lastPathComponent,
                    "to": destinationURL.lastPathComponent
                ])
            } catch {
                ScreenshotDebugLogger.log("auto_organize_migration_failed", fields: [
                    "app": appName,
                    "file": screenshotURL.lastPathComponent,
                    "destination": destinationURL.lastPathComponent,
                    "error": error.localizedDescription
                ])
            }
        }
    }

    private func appScreenshotFileURLs(forAppName appName: String, in directoryURL: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return []
        }

        let fileURLs: [URL]
        do {
            fileURLs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            ScreenshotDebugLogger.log("auto_organize_scan_failed", fields: [
                "directory": directoryURL.path,
                "error": error.localizedDescription
            ])
            return []
        }

        return fileURLs.filter { isAppScreenshot($0, appName: appName) }
    }

    private func isAppScreenshot(_ fileURL: URL, appName: String) -> Bool {
        guard supportedScreenshotExtensions.contains(fileURL.pathExtension.lowercased()) else {
            return false
        }

        let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values?.isRegularFile == true else { return false }

        let baseName = fileURL.deletingPathExtension().lastPathComponent
        return baseName == appName || baseName.hasPrefix("\(appName)_")
    }

    private func migrationDestinationURL(for fileURL: URL, in directoryURL: URL) -> URL {
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension
        var suffix = 1

        while true {
            let suffixText = suffix == 1 ? "" : "_\(suffix)"
            let candidateBaseName = baseName + suffixText
            let candidateURL: URL

            if fileExtension.isEmpty {
                candidateURL = directoryURL.appendingPathComponent(candidateBaseName)
            } else {
                candidateURL = directoryURL.appendingPathComponent(candidateBaseName).appendingPathExtension(fileExtension)
            }

            if candidateURL.standardizedFileURL == fileURL.standardizedFileURL ||
                !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            suffix += 1
        }
    }
}

private struct AppFolderIdentity {
    let filePrefix: String
    let folderName: String
}
