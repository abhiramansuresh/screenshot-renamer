import Foundation

enum ScreenshotLocationResolver {
    private static let screencapturePreferencesDomain = "com.apple.screencapture" as CFString

    static func screenshotDirectories() -> [URL] {
        let directory = customScreenshotLocation() ?? desktopDirectory()
        return uniqueExistingDirectories([directory])
    }

    private static func desktopDirectory() -> URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    private static func customScreenshotLocation() -> URL? {
        _ = CFPreferencesAppSynchronize(screencapturePreferencesDomain)

        guard let rawLocation = CFPreferencesCopyAppValue(
            "location" as CFString,
            screencapturePreferencesDomain
        ) else {
            return nil
        }

        return directoryURL(from: rawLocation)
    }

    private static func directoryURL(from rawLocation: Any) -> URL? {
        if let url = rawLocation as? URL {
            return url
        }

        if let bookmarkData = rawLocation as? Data {
            var isStale = false
            return try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }

        guard let rawLocation = rawLocation as? String, !rawLocation.isEmpty else {
            return nil
        }

        let expandedPath: String
        if let fileURL = URL(string: rawLocation), fileURL.isFileURL {
            expandedPath = fileURL.path
        } else {
            expandedPath = NSString(string: rawLocation).expandingTildeInPath
        }

        guard expandedPath.hasPrefix("/") else { return nil }

        return URL(fileURLWithPath: expandedPath, isDirectory: true)
    }

    private static func uniqueExistingDirectories(_ directories: [URL]) -> [URL] {
        var seenPaths = Set<String>()

        return directories.compactMap { directory in
            let standardizedURL = directory.standardizedFileURL
            var isDirectory: ObjCBool = false

            guard FileManager.default.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  seenPaths.insert(standardizedURL.path).inserted else {
                return nil
            }

            return standardizedURL
        }
    }
}
