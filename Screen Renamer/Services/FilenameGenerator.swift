import Foundation

struct FilenameGenerator {
    private let maxDomainLength = 32
    private let maxTitleLength = 120
    private let maxBaseNameLength = 80
    private let maxTitleWords = 5
    private let maxSearchQueryWords = 4
    private let illegalCharacters = CharacterSet(charactersIn: "/\\:?*\"<>|")
    private let trimCharacters = CharacterSet(charactersIn: "._- ")
    private let searchEngineNames: Set<String> = ["google", "bing", "duckduckgo"]
    private let knownAcronyms: Set<String> = [
        "AI", "API", "CPU", "CSS", "DNS", "GPU", "HTML", "HTTP", "IP", "JSON",
        "LLM", "OPC", "PDF", "SQL", "UI", "URL", "UX", "VPN", "XML"
    ]
    private let specialTitleWords = [
        "figma": "Figma",
        "github": "GitHub",
        "ios": "iOS",
        "macos": "macOS",
        "openai": "OpenAI",
        "xcode": "Xcode"
    ]
    private let domainDisplayNames = [
        "figma.com": "Figma",
        "github.com": "GitHub",
        "google.com": "Google",
        "notion.so": "Notion",
        "openai.com": "OpenAI",
        "stackoverflow.com": "StackOverflow"
    ]
    private let lowQualityTitles: Set<String> = [
        "",
        "untitled",
        "new_tab",
        "newtab",
        "home",
        "google",
        "bing",
        "duckduckgo",
        "emptytitle",
        "empty_title",
        "start_page",
        "startpage",
        "aboutblank",
        "about_blank"
    ]

    func destinationURL(for originalURL: URL, context: AppContext) -> URL {
        let directoryURL = originalURL.deletingLastPathComponent()
        let fileExtension = originalURL.pathExtension.isEmpty ? "png" : originalURL.pathExtension

        let appName = cleanedAppName(context.appName)
        let domainName = cleanedBrowserDomain(context.browserDomain)
        let tabName = cleanedTabName(context.tabName, appName: context.appName)
        let fallbackTitle = cleanedWindowTitle(context.windowTitle, appName: context.appName)
        let pageName = distinctPageName(tabName ?? fallbackTitle, domainName: domainName)
        let baseName = [appName, pageName].compactMap { $0 }.joined(separator: "_")
        let safeBaseName = baseName.isEmpty ? "Screenshot" : truncatedBaseName(baseName, maxLength: maxBaseNameLength)

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
        cleanedContextName(title, appName: appName)
    }

    private func cleanedTabName(_ tabName: String?, appName: String) -> String? {
        cleanedContextName(tabName, appName: appName)
    }

    private func cleanedBrowserDomain(_ domain: String?) -> String? {
        guard let domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines), !domain.isEmpty else {
            return nil
        }

        let displayName = domainDisplayNames[domain.lowercased()] ?? domain
        return sanitize(displayName, maxLength: maxDomainLength)
    }

    private func cleanedContextName(_ name: String?, appName: String) -> String? {
        guard var name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        let browser = isBrowser(appName)
        let titleHadDomain = containsDomainToken(in: name)
        let titleWasURL = looksLikeRawURL(name)

        name = extractMeaningfulRawURLTitle(from: name) ?? name

        if browser {
            name = stripDomainTokens(from: name)
        }

        name = stripAppSuffixNoise(from: name, appName: appName)

        let cleanedTitle: String?
        if isSearchQueryTitle(name, isBrowser: browser, hadDomain: titleHadDomain || titleWasURL) {
            cleanedTitle = formattedTitle(
                stripSearchEngineSuffix(from: name),
                maxWords: maxSearchQueryWords,
                dropLeadingSearchEngine: true
            )
        } else {
            cleanedTitle = formattedTitle(name, maxWords: maxTitleWords)
        }

        guard let cleanedTitle,
              !isLowQualityTitle(cleanedTitle),
              !isAppName(cleanedTitle, appName: appName),
              comparableName(cleanedTitle).count >= 2 else {
            return nil
        }

        return sanitize(cleanedTitle, maxLength: maxTitleLength)
    }

    private func distinctPageName(_ pageName: String?, domainName: String?) -> String? {
        guard let pageName else { return nil }
        guard let domainName else { return pageName }
        return comparableName(pageName) == comparableName(domainName) ? nil : pageName
    }

    private func stripAppSuffixNoise(from title: String, appName: String) -> String {
        var cleanedTitle = title
        let suffixes = Set([
            appName,
            cleanedAppName(appName),
            "Google Chrome",
            "Chrome",
            "Safari",
            "Firefox",
            "Mozilla Firefox",
            "Microsoft Edge",
            "Edge",
            "Arc",
            "Brave",
            "Brave Browser",
            "Notion",
            "Xcode",
            "Visual Studio Code",
            "VSCode",
            "VS Code",
            "Figma",
            "Slack",
            "Linear"
        ])

        var didStrip = true
        while didStrip {
            didStrip = false

            for suffix in suffixes where !suffix.isEmpty {
                for separator in [" - ", " – ", " — ", " | "] {
                    let noisySuffix = separator + suffix
                    if cleanedTitle.localizedCaseInsensitiveContains(noisySuffix),
                       cleanedTitle.lowercased().hasSuffix(noisySuffix.lowercased()) {
                        cleanedTitle.removeLast(noisySuffix.count)
                        cleanedTitle = cleanedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        didStrip = true
                    }
                }
            }
        }

        return cleanedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractMeaningfulRawURLTitle(from title: String) -> String? {
        guard looksLikeRawURL(title), let candidate = firstRawURLCandidate(in: title) else {
            return nil
        }

        return meaningfulURLSegment(from: candidate)
    }

    private func looksLikeRawURL(_ title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedTitle = trimmedTitle.lowercased()

        return lowercasedTitle.contains("://")
            || lowercasedTitle.hasPrefix("http")
            || lowercasedTitle.hasPrefix("www.")
            || trimmedTitle.range(
                of: #"\b[a-z0-9]+(?:-[a-z0-9]+){2,}\.(?:[a-z0-9-]+\.)+[a-z]{2,}\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
    }

    private func firstRawURLCandidate(in title: String) -> String? {
        let patterns = [
            #"\bhttps?://[^\s_]+"#,
            #"\bwww\.[^\s_]+"#,
            #"\b[a-z0-9]+(?:-[a-z0-9]+){2,}\.(?:[a-z0-9-]+\.)+[a-z]{2,}\b"#
        ]

        for pattern in patterns {
            if let range = title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                return String(title[range])
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t\r,.;)]}>"))
            }
        }

        return nil
    }

    private func meaningfulURLSegment(from rawURL: String) -> String? {
        let hasScheme = rawURL.range(of: #"^[a-z][a-z0-9+.-]*://"#, options: [.regularExpression, .caseInsensitive]) != nil
        let urlText = hasScheme ? rawURL : "https://\(rawURL)"
        let components = URLComponents(string: urlText)

        let host = components?.host?
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let pathSegments = components?.path
            .split(separator: "/")
            .map(String.init) ?? []

        var hostLabels = host?.split(separator: ".").map(String.init) ?? []
        if hostLabels.first == "www" {
            hostLabels.removeFirst()
        }

        if let firstHostLabel = hostLabels.first,
           !isGenericURLHostLabel(firstHostLabel),
           let meaningfulSegment = firstMeaningfulPart(of: firstHostLabel) {
            return meaningfulSegment
        }

        if let firstPathSegment = pathSegments.first,
           let meaningfulSegment = firstMeaningfulPart(of: firstPathSegment) {
            return meaningfulSegment
        }

        return hostLabels.first.flatMap { firstMeaningfulPart(of: $0) }
    }

    private func isGenericURLHostLabel(_ label: String) -> Bool {
        [
            "docs", "drive", "github", "google", "localhost", "notion", "vercel"
        ].contains(label.lowercased())
    }

    private func firstMeaningfulPart(of value: String) -> String? {
        let parts = value
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        return parts.first { !$0.isEmpty }
    }

    private func stripDomainTokens(from title: String) -> String {
        title
            .replacingOccurrences(
                of: #"\b(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}\b"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"\blocalhost(?::\d+)?\b"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsDomainToken(in title: String) -> Bool {
        title.range(
            of: #"\b(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
            || title.range(
                of: #"\blocalhost(?::\d+)?\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
    }

    private func isSearchQueryTitle(_ title: String, isBrowser: Bool, hadDomain: Bool) -> Bool {
        let normalizedTitle = title
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .lowercased()

        if normalizedTitle.contains("- google search")
            || normalizedTitle.contains("| google search")
            || normalizedTitle.contains("- bing")
            || normalizedTitle.contains("| bing")
            || normalizedTitle.contains("- duckduckgo")
            || normalizedTitle.contains("| duckduckgo")
            || normalizedTitle.contains("search results for") {
            return true
        }

        return isBrowser && !hadDomain && titleWords(from: title).count > 6
    }

    private func stripSearchEngineSuffix(from title: String) -> String {
        title
            .replacingOccurrences(
                of: #"(?i)\bsearch results for\b[:\s-]*"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\s*[-–—|]\s*(google search|bing|duckduckgo).*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formattedTitle(
        _ title: String,
        maxWords: Int,
        dropLeadingSearchEngine: Bool = false
    ) -> String? {
        var words = titleWords(from: title)

        if dropLeadingSearchEngine,
           let firstWord = words.first,
           searchEngineNames.contains(firstWord.lowercased()) {
            words.removeFirst()
        }

        let formattedWords = words
            .prefix(maxWords)
            .map(titleCasedWord)

        guard !formattedWords.isEmpty else { return nil }
        return formattedWords.joined(separator: "_")
    }

    private func titleWords(from title: String) -> [String] {
        title
            .replacingOccurrences(of: #"(?i)\bhttps?://\S+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[_\s]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^\w']+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
    }

    private func titleCasedWord(_ word: String) -> String {
        let uppercasedWord = word.uppercased()
        let lowercasedWord = word.lowercased()

        if knownAcronyms.contains(uppercasedWord), (2...4).contains(word.count) {
            return uppercasedWord
        }

        if let specialTitleWord = specialTitleWords[lowercasedWord] {
            return specialTitleWord
        }

        guard let firstCharacter = lowercasedWord.first else { return lowercasedWord }
        return firstCharacter.uppercased() + lowercasedWord.dropFirst()
    }

    private func isBrowser(_ appName: String) -> Bool {
        let browserNames = [
            "Arc",
            "Brave",
            "Brave Browser",
            "Chrome",
            "Chromium",
            "Firefox",
            "Google Chrome",
            "Microsoft Edge",
            "Edge",
            "Opera",
            "Safari"
        ]
        return browserNames.contains { $0.caseInsensitiveCompare(appName) == .orderedSame }
    }

    private func isAppName(_ title: String, appName: String) -> Bool {
        let appNames = [appName, cleanedAppName(appName)]
        return appNames.contains { $0.caseInsensitiveCompare(title) == .orderedSame }
    }

    private func isLowQualityTitle(_ title: String) -> Bool {
        let normalized = title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return normalized.isEmpty || lowQualityTitles.contains(normalized)
    }

    private func comparableName(_ name: String) -> String {
        name
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    private func sanitize(_ value: String, maxLength: Int?) -> String? {
        var sanitized = value
            .components(separatedBy: illegalCharacters)
            .joined()
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
            .replacingOccurrences(of: #"_+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: trimCharacters)

        if let maxLength, sanitized.count > maxLength {
            sanitized = truncatedBaseName(sanitized, maxLength: maxLength)
        }

        return sanitized.isEmpty ? nil : sanitized
    }

    private func truncatedBaseName(_ value: String, maxLength: Int) -> String {
        let maxLength = max(1, maxLength)
        guard value.count > maxLength else { return value.trimmingCharacters(in: trimCharacters) }

        let limitIndex = value.index(value.startIndex, offsetBy: maxLength)
        let prefix = String(value[..<limitIndex])
        let minimumBoundaryLength = min(maxLength - 1, max(20, Int(Double(maxLength) * 0.6)))

        if let boundaryIndex = prefix.indices.last(where: { index in
            prefix.distance(from: prefix.startIndex, to: index) >= minimumBoundaryLength
                && "_-. ".contains(prefix[index])
        }) {
            let boundaryTruncated = String(prefix[..<boundaryIndex]).trimmingCharacters(in: trimCharacters)
            if !boundaryTruncated.isEmpty {
                return boundaryTruncated
            }
        }

        let hardTruncated = prefix.trimmingCharacters(in: trimCharacters)
        return hardTruncated.isEmpty ? String(value.prefix(maxLength)) : hardTruncated
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
            let suffixText = suffix == 1 ? "" : "_\(suffix)"
            let candidateBaseName = truncatedBaseName(
                baseName,
                maxLength: maxBaseNameLength - suffixText.count
            ) + suffixText
            let candidateURL = directoryURL.appendingPathComponent(candidateBaseName).appendingPathExtension(fileExtension)

            if candidateURL.standardizedFileURL == originalURL.standardizedFileURL ||
                !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            suffix += 1
        }
    }
}
