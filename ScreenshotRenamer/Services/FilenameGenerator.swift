import Foundation

struct FilenameGenerator {
    private let maxTitleLength = 40
    private let illegalCharacters = CharacterSet(charactersIn: "/\\:?*\"<>|")
    private let lowQualityTitles: Set<String> = [
        "untitled",
        "newtab",
        "new_tab",
        "home",
        "emptytitle",
        "empty_title",
        "startpage",
        "start_page",
        "aboutblank",
        "about_blank"
    ]

    func destinationURL(for originalURL: URL, context: AppContext) -> URL {
        let directoryURL = originalURL.deletingLastPathComponent()
        let fileExtension = originalURL.pathExtension.isEmpty ? "png" : originalURL.pathExtension

        let appName = cleanedAppName(context.appName)
        let title = cleanedWindowTitle(context.windowTitle, appName: context.appName)
        let baseName = [appName, title].compactMap { $0 }.joined(separator: "_")
        let safeBaseName = baseName.isEmpty ? "Screenshot" : baseName

        return availableURL(
            in: directoryURL,
            baseName: safeBaseName,
            fileExtension: fileExtension,
            originalURL: originalURL
        )
    }

    private func cleanedAppName(_ appName: String) -> String {
        let normalizedName: String
        switch appName.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Google Chrome":
            normalizedName = "Chrome"
        case "Microsoft Edge":
            normalizedName = "Edge"
        default:
            normalizedName = appName
        }

        return sanitize(normalizedName, maxLength: nil) ?? "Screenshot"
    }

    private func cleanedWindowTitle(_ title: String?, appName: String) -> String? {
        guard var title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }

        title = removeAppSuffixNoise(from: title, appName: appName)

        if isBrowser(appName) {
            title = removeBrowserSiteSuffix(from: title)
        }

        guard !isLowQualityTitle(title) else { return nil }
        return sanitize(title, maxLength: maxTitleLength)
    }

    private func removeAppSuffixNoise(from title: String, appName: String) -> String {
        var cleanedTitle = title
        let suffixes = Set([
            appName,
            cleanedAppName(appName),
            "Google Chrome",
            "Safari",
            "Figma"
        ])

        for suffix in suffixes where !suffix.isEmpty {
            for separator in [" - ", " – ", " — ", " | "] {
                let noisySuffix = separator + suffix
                if cleanedTitle.localizedCaseInsensitiveContains(noisySuffix),
                   cleanedTitle.lowercased().hasSuffix(noisySuffix.lowercased()) {
                    cleanedTitle.removeLast(noisySuffix.count)
                }
            }
        }

        return cleanedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeBrowserSiteSuffix(from title: String) -> String {
        for separator in [" - ", " – ", " — ", " | "] {
            if let firstSegment = title.components(separatedBy: separator).first,
               firstSegment != title,
               !firstSegment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return firstSegment.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return title
    }

    private func isBrowser(_ appName: String) -> Bool {
        let browserNames = ["Safari", "Google Chrome", "Chrome", "Microsoft Edge", "Edge", "Firefox", "Arc"]
        return browserNames.contains { $0.caseInsensitiveCompare(appName) == .orderedSame }
    }

    private func isLowQualityTitle(_ title: String) -> Bool {
        let normalized = title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return normalized.isEmpty || lowQualityTitles.contains(normalized)
    }

    private func sanitize(_ value: String, maxLength: Int?) -> String? {
        var sanitized = value
            .components(separatedBy: illegalCharacters)
            .joined()
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
            .replacingOccurrences(of: #"_+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "._- "))

        if let maxLength, sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
                .trimmingCharacters(in: CharacterSet(charactersIn: "._- "))
        }

        return sanitized.isEmpty ? nil : sanitized
    }

    private func availableURL(
        in directoryURL: URL,
        baseName: String,
        fileExtension: String,
        originalURL: URL
    ) -> URL {
        let fileManager = FileManager.default
        var suffix = 1

        while true {
            let candidateBaseName = suffix == 1 ? baseName : "\(baseName)_\(suffix)"
            let candidateURL = directoryURL.appendingPathComponent(candidateBaseName).appendingPathExtension(fileExtension)

            if candidateURL.standardizedFileURL == originalURL.standardizedFileURL ||
                !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            suffix += 1
        }
    }
}
