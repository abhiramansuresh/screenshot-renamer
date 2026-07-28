import Foundation

struct FilenameGenerator {
    private let maxDomainLength = 32
    private let maxTitleLength = 120
    private let maxBaseNameLength = 80
    private let maxTitleWords = 5
    private let maxSearchQueryWords = 4
    private let minimumWindowMetadataTitleWords = 4
    private let minimumOCRConfidence: Float = 0.62
    private let documentFilenameExtensions = "md|docx|pdf|pptx|xlsx|swift|fig"
    private let filenameCleanupExtensions = "xcodeproj|swift|md|txt|pdf|png|jpe?g|heic|fig|json|csv|xlsx?|docx?|pptx?|html?|css|js|ts|tsx|jsx"
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
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH-mm"
        return f
    }()

    func destinationURL(for originalURL: URL, context: AppContext, directoryURL: URL? = nil) -> URL {
        destinationURL(for: originalURL, context: context, ocrResult: nil, directoryURL: directoryURL)
    }

    func destinationURL(
        for originalURL: URL,
        context: AppContext,
        ocrResult: OCRResult?,
        windowMetadata: WindowMetadata? = nil,
        template: NamingTemplate = .default,
        directoryURL: URL? = nil
    ) -> URL {
        let directoryURL = directoryURL ?? originalURL.deletingLastPathComponent()
        let fileExtension = originalURL.pathExtension.isEmpty ? "png" : originalURL.pathExtension

        var fieldValues = template.fields.compactMap { field in
            fieldValue(for: field, context: context, ocrResult: ocrResult, windowMetadata: windowMetadata)
                .map { (field: field, value: $0) }
        }

        // The browser name is noise once the domain is known: GitHub_TasteSkill beats
        // Safari_GitHub_TasteSkill. Domains only exist for browsers.
        if fieldValues.contains(where: { $0.field == .domain }) {
            fieldValues.removeAll { $0.field == .app }
        }

        // Drop fields that just repeat another field ("instagram.com" + "Instagram_Messages").
        var values: [String] = []
        for candidate in fieldValues.map(\.value) {
            if values.contains(where: { covers($0, candidate) }) { continue }
            values.removeAll { covers(candidate, $0) }
            values.append(candidate)
        }
        let rawBaseName = template.prefix + values.joined(separator: template.separator) + template.suffix
        let safeBaseName = sanitize(rawBaseName, maxLength: maxBaseNameLength) ?? "Screenshot"

        return availableURL(
            in: directoryURL,
            baseName: safeBaseName,
            fileExtension: fileExtension,
            originalURL: originalURL
        )
    }

    private func fieldValue(
        for field: NamingField,
        context: AppContext,
        ocrResult: OCRResult?,
        windowMetadata: WindowMetadata?
    ) -> String? {
        switch field {
        case .app:
            return cleanedAppName(context.appName)
        case .windowTitle:
            // Smart hierarchy: long metadata title → document name → OCR doc → context title
            return windowMetadataBaseName(from: windowMetadata, browserDomain: context.browserDomain)
                ?? ocrBaseName(from: ocrResult, context: context)
                ?? contextTitleOnly(for: context)
        case .tabName:
            return cleanedContextName(context.tabName, appName: context.appName, browserDomain: context.browserDomain)
        case .domain:
            return cleanedBrowserDomain(context.browserDomain)
        case .documentName:
            let name = windowMetadata?.documentName ?? context.documentName
            return name.flatMap { formattedMetadataName($0, appName: context.appName) }
        case .ocrDocument:
            guard !context.isPrivacyRestrictedOCRApp else { return nil }
            return ocrResult.flatMap { documentFilenameBaseName(from: $0) }
        case .date:
            return Self.dateFormatter.string(from: context.timestamp)
        case .time:
            return Self.timeFormatter.string(from: context.timestamp)
        }
    }

    func organizedFolderName(for appName: String) -> String {
        "\(cleanedAppName(appName))_Screenshots"
    }

    func normalizedAppName(for appName: String) -> String {
        cleanedAppName(appName)
    }

    private func windowMetadataBaseName(from metadata: WindowMetadata?, browserDomain: String?) -> String? {
        guard let metadata else { return nil }

        if let windowTitle = metadata.windowTitle,
           metadataWordCount(windowTitle, appName: metadata.appName, browserDomain: browserDomain) >= minimumWindowMetadataTitleWords,
           let formattedTitle = formattedMetadataName(windowTitle, appName: metadata.appName, browserDomain: browserDomain) {
            return formattedTitle
        }

        if let documentName = metadata.documentName,
           let formattedDocumentName = formattedMetadataName(documentName, appName: metadata.appName) {
            return formattedDocumentName
        }

        return nil
    }

    private func metadataWordCount(_ value: String, appName: String, browserDomain: String? = nil) -> Int {
        deduplicatedRepeatedWordSequence(
            titleWords(from: cleanedTitleSubject(value, appName: appName, browserDomain: browserDomain))
        ).count
    }

    // Titles read "Subject SEP tagline SEP site". Only the subject names the screenshot;
    // everything after the first separator is branding that bloats filenames.
    private func subjectSegment(from title: String, skipping skipNames: [String]) -> String {
        let cleanedTitle = title.replacingOccurrences(
            of: #"^\s*[\[(]\d+[\])]\s*"#,
            with: "",
            options: .regularExpression
        )

        var segments = [cleanedTitle]
        for separator in [" — ", " – ", " - ", " | ", " · ", " • ", " :: ", ": "] {
            segments = segments.flatMap { $0.components(separatedBy: separator) }
        }

        let candidates = segments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let skipTokens = skipNames.filter { !$0.isEmpty }.map(comparableTokens)

        let subject = candidates.first { candidate in
            !isLowQualityTitle(candidate)
                && !skipTokens.contains { comparableTokens(candidate).isSubset(of: $0) }
        }

        return subject ?? candidates.first ?? cleanedTitle
    }

    private func cleanedTitleSubject(_ value: String, appName: String, browserDomain: String?) -> String {
        subjectSegment(
            from: stripKnownFileExtension(from: stripAppSuffixNoise(from: value, appName: appName)),
            skipping: [appName, cleanedAppName(appName), browserDomain ?? ""]
        )
    }

    private func comparableTokens(_ value: String) -> Set<String> {
        Set(
            value.lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
        )
    }

    private func covers(_ value: String, _ other: String) -> Bool {
        comparableName(value).contains(comparableName(other))
            || comparableTokens(other).isSubset(of: comparableTokens(value))
    }

    private func formattedMetadataName(_ value: String, appName: String, browserDomain: String? = nil) -> String? {
        var cleanedValue = cleanedTitleSubject(value, appName: appName, browserDomain: browserDomain)
            .replacingOccurrences(of: #"(?i)\bhttps?://\S+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[|:()[\]{}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: trimCharacters)

        if isBrowser(appName) {
            cleanedValue = stripDomainTokens(from: cleanedValue)
        }

        guard !cleanedValue.isEmpty,
              !isLowQualityTitle(cleanedValue),
              !isAppName(cleanedValue, appName: appName) else {
            return nil
        }

        let underscoreSegments = cleanedValue
            .split(separator: "_")
            .map(String.init)
            .compactMap(formattedMetadataSegment)

        guard !underscoreSegments.isEmpty else { return nil }
        return sanitize(underscoreSegments.joined(separator: "_"), maxLength: maxBaseNameLength)
    }

    private func formattedMetadataSegment(_ segment: String) -> String? {
        let words = deduplicatedRepeatedWordSequence(
            segment
            .replacingOccurrences(of: #"[^A-Za-z0-9+#]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
        )

        guard !words.isEmpty else { return nil }
        // ponytail: humans name files in a handful of words; anything longer is a tagline
        return words.prefix(maxTitleWords).map(formattedOCRWord).joined()
    }

    private func deduplicatedRepeatedWordSequence(_ words: [String]) -> [String] {
        guard words.count > 1 else { return words }

        let midpoint = words.count / 2
        if words.count.isMultiple(of: 2) {
            let firstHalf = Array(words[..<midpoint])
            let secondHalf = Array(words[midpoint...])

            if comparableWords(firstHalf) == comparableWords(secondHalf) {
                return firstHalf
            }
        }

        return words.reduce(into: [String]()) { deduplicatedWords, word in
            guard comparableName(deduplicatedWords.last ?? "") != comparableName(word) else { return }
            deduplicatedWords.append(word)
        }
    }

    private func comparableWords(_ words: [String]) -> String {
        words.map(comparableName).joined(separator: "|")
    }

    private func contextTitleOnly(for context: AppContext) -> String? {
        let domainName = cleanedBrowserDomain(context.browserDomain)
        let tabName = cleanedContextName(context.tabName, appName: context.appName, browserDomain: context.browserDomain)
        let fallbackTitle = cleanedContextName(context.windowTitle, appName: context.appName, browserDomain: context.browserDomain)
        return distinctPageName(tabName ?? fallbackTitle, domainName: domainName)
            ?? urlPathSlug(from: context.browserPageURL)
    }

    private func urlPathSlug(from urlString: String?) -> String? {
        guard let urlString, let components = URLComponents(string: urlString) else { return nil }

        // ponytail: last two readable path segments; per-site slug rules if this proves too blunt
        let segments = components.path
            .split(separator: "/")
            .map(String.init)
            .filter { segment in
                segment.count <= 40
                    && segment.range(
                        of: #"^[0-9a-f-]{16,}$"#,
                        options: [.regularExpression, .caseInsensitive]
                    ) == nil
            }

        guard !segments.isEmpty else { return nil }

        let slug = formattedTitle(segments.suffix(2).joined(separator: " "), maxWords: maxTitleWords)
        guard let slug, !isLowQualityTitle(slug) else { return nil }
        return sanitize(slug, maxLength: maxTitleLength)
    }

    private func ocrBaseName(from ocrResult: OCRResult?, context: AppContext) -> String? {
        guard let ocrResult else { return nil }

        // OCR is only used to detect visible document filenames on screen (e.g. a .md or .pdf
        // shown in a title bar or tab). Body text scoring was removed because it produced noisy,
        // partial-word names (e.g. "laude" from "Claude") that were worse than context-based fallbacks.
        // Privacy: skip OCR entirely for chat apps to avoid leaking message content or attachment names.
        guard !context.isPrivacyRestrictedOCRApp else { return nil }

        return documentFilenameBaseName(from: ocrResult)
    }

    private func documentFilenameBaseName(from ocrResult: OCRResult) -> String? {
        ocrResult.tokens
            .compactMap(documentFilenameCandidate(from:))
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return lhs.confidence > rhs.confidence
                }

                return lhs.boundingRect.standardized.height > rhs.boundingRect.standardized.height
            }
            .first
            .flatMap { formattedOCRChunk($0.text) }
    }

    private func documentFilenameCandidate(from token: OCRToken) -> OCRToken? {
        guard token.confidence >= minimumOCRConfidence,
              let filename = documentFilename(in: token.text) else {
            return nil
        }

        return OCRToken(
            text: filename,
            confidence: token.confidence,
            boundingRect: token.boundingRect
        )
    }

    private func documentFilename(in text: String) -> String? {
        let pattern = "\\b[A-Za-z0-9][A-Za-z0-9._ -]*\\.(" + documentFilenameExtensions + ")\\b"
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }

        return String(text[range]).trimmingCharacters(in: trimCharacters)
    }

    private func formattedOCRChunk(_ text: String?) -> String? {
        guard var text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        text = stripKnownFileExtension(from: text)
            .replacingOccurrences(of: #"(?i)\bhttps?://\S+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[|:()[\]{}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: trimCharacters)

        guard !text.isEmpty else { return nil }

        let underscoreSegments = text
            .split(separator: "_")
            .map(String.init)
            .compactMap(formattedOCRSegment)

        guard !underscoreSegments.isEmpty else { return nil }
        return sanitize(underscoreSegments.joined(separator: "_"), maxLength: nil)
    }

    private func stripKnownFileExtension(from value: String) -> String {
        value.replacingOccurrences(
            of: "\\.(" + filenameCleanupExtensions + ")\\b",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private func formattedOCRSegment(_ segment: String) -> String? {
        let words = segment
            .replacingOccurrences(of: #"[^A-Za-z0-9+#]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)

        guard !words.isEmpty else { return nil }

        let formattedWords = words.map(formattedOCRWord)

        if formattedWords.count == 2,
           formattedWords[0].range(of: #"^[A-Za-z]{2,6}$"#, options: .regularExpression) != nil,
           formattedWords[1].range(of: #"^\d+$"#, options: .regularExpression) != nil {
            return formattedWords.joined()
        }

        return formattedWords.joined(separator: "_")
    }

    private func formattedOCRWord(_ word: String) -> String {
        let uppercasedWord = word.uppercased()
        let lowercasedWord = word.lowercased()

        if (knownAcronyms.contains(uppercasedWord) || word == uppercasedWord),
           (2...5).contains(word.count) {
            return uppercasedWord
        }

        if let specialTitleWord = specialTitleWords[lowercasedWord] {
            return specialTitleWord
        }

        if word.range(of: #"[a-z][A-Z]"#, options: .regularExpression) != nil {
            return word
        }

        if word.range(of: #"^\d+$"#, options: .regularExpression) != nil {
            return word
        }

        guard let firstCharacter = lowercasedWord.first else { return lowercasedWord }
        return firstCharacter.uppercased() + lowercasedWord.dropFirst()
    }

    private func cleanedAppName(_ appName: String) -> String {
        let normalizedName: String
        switch appName.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Google Chrome":
            normalizedName = "Chrome"
        case "Microsoft Edge":
            normalizedName = "Edge"
        case "Visual Studio Code":
            normalizedName = "VSCode"
        default:
            normalizedName = appName
        }

        return sanitize(normalizedName, maxLength: nil) ?? "Screenshot"
    }

    private func cleanedBrowserDomain(_ domain: String?) -> String? {
        guard let domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines), !domain.isEmpty else {
            return nil
        }

        let displayName = domainDisplayNames[domain.lowercased()] ?? domainDerivedDisplayName(domain)
        return sanitize(displayName, maxLength: maxDomainLength)
    }

    // instagram.com -> Instagram, benshih.design -> Benshih: humans name the site, not the host.
    private func domainDerivedDisplayName(_ domain: String) -> String {
        let labels = domain.lowercased().split(separator: ".").map(String.init)
        let nameLabels = labels.count > 1 ? Array(labels.dropLast()) : labels

        return nameLabels
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
    }

    private func cleanedContextName(_ name: String?, appName: String, browserDomain: String? = nil) -> String? {
        guard var name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        let browser = isBrowser(appName)

        name = extractMeaningfulRawURLTitle(from: name) ?? name

        if browser {
            name = stripDomainTokens(from: name)
        }

        name = stripAppSuffixNoise(from: name, appName: appName)

        let cleanedTitle: String?
        if isSearchQueryTitle(name) {
            cleanedTitle = formattedTitle(
                stripSearchEngineSuffix(from: name),
                maxWords: maxSearchQueryWords,
                dropLeadingSearchEngine: true
            )
        } else {
            let subject = subjectSegment(
                from: name,
                skipping: [appName, cleanedAppName(appName), browserDomain ?? ""]
            )
            cleanedTitle = formattedTitle(subject, maxWords: maxTitleWords)
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

    private func isSearchQueryTitle(_ title: String) -> Bool {
        let normalizedTitle = title
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .lowercased()

        return normalizedTitle.contains("- google search")
            || normalizedTitle.contains("| google search")
            || normalizedTitle.contains("- bing")
            || normalizedTitle.contains("| bing")
            || normalizedTitle.contains("- duckduckgo")
            || normalizedTitle.contains("| duckduckgo")
            || normalizedTitle.contains("search results for")
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
        let maxSuffix = 9_999

        for suffix in 1...maxSuffix {
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
        }

        let uniqueSuffix = String(Int(Date().timeIntervalSince1970) % 100_000)
        return directoryURL
            .appendingPathComponent(truncatedBaseName(baseName, maxLength: maxBaseNameLength - uniqueSuffix.count - 1) + "_\(uniqueSuffix)")
            .appendingPathExtension(fileExtension)
    }
}
