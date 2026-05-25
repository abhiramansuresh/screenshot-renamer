import Foundation

@MainActor
final class ScreenshotWatcher {
    private let contextTracker: ContextTracker
    private let filenameGenerator = FilenameGenerator()
    private let fileManager = FileManager.default
    private let onStatusChange: (String) -> Void
    private let onLocationsChange: ([URL]) -> Void

    private var watchers: [DirectoryWatcher] = []
    private var watchedDirectories: [URL] = []
    private var knownScreenshotPaths = Set<String>()
    private var pendingScreenshotPaths = Set<String>()
    private var locationRefreshTimer: Timer?
    private var isRunning = false
    private var isPaused = false

    init(
        contextTracker: ContextTracker,
        onStatusChange: @escaping (String) -> Void,
        onLocationsChange: @escaping ([URL]) -> Void
    ) {
        self.contextTracker = contextTracker
        self.onStatusChange = onStatusChange
        self.onLocationsChange = onLocationsChange
    }

    deinit {
        locationRefreshTimer?.invalidate()
        watchers.forEach { $0.cancel() }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        rebuildWatchers(markExistingScreenshots: true)
        startLocationRefreshTimer()
    }

    func pause() {
        isPaused = true
        pendingScreenshotPaths.removeAll()
        markExistingScreenshots()
        onStatusChange("Renaming paused")
    }

    func resume() {
        isPaused = false
        markExistingScreenshots()
        onStatusChange("Watching for screenshots")
    }

    func refreshLocations() {
        guard isRunning else {
            onLocationsChange(ScreenshotLocationResolver.screenshotDirectories())
            return
        }

        refreshLocationsIfNeeded(announceUnchanged: true)
    }

    private func startLocationRefreshTimer() {
        locationRefreshTimer?.invalidate()

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLocationsIfNeeded(announceUnchanged: false)
            }
        }

        locationRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshLocationsIfNeeded(announceUnchanged: Bool) {
        let latestDirectories = ScreenshotLocationResolver.screenshotDirectories()

        guard latestDirectories.standardizedPaths != watchedDirectories.standardizedPaths else {
            if announceUnchanged {
                onLocationsChange(watchedDirectories)
                onStatusChange(isPaused ? "Renaming paused" : "Watching for screenshots")
            }
            return
        }

        rebuildWatchers(
            markExistingScreenshots: true,
            statusMessage: latestDirectories.isEmpty ? "No screenshot folder found" : "Updated screenshot folder"
        )
    }

    private func rebuildWatchers(markExistingScreenshots: Bool, statusMessage: String? = nil) {
        watchers.forEach { $0.cancel() }
        watchers.removeAll()

        watchedDirectories = ScreenshotLocationResolver.screenshotDirectories()
        onLocationsChange(watchedDirectories)

        for directoryURL in watchedDirectories {
            if let watcher = DirectoryWatcher(directoryURL: directoryURL, onChange: { [weak self] changedDirectoryURL in
                self?.handleDirectoryChange(changedDirectoryURL)
            }) {
                watchers.append(watcher)
            }

            scanDirectory(directoryURL, markExistingScreenshots: markExistingScreenshots)
        }

        onStatusChange(statusMessage ?? (watchedDirectories.isEmpty ? "No screenshot folder found" : "Watching for screenshots"))
    }

    private func handleDirectoryChange(_ directoryURL: URL) {
        if isPaused {
            scanDirectory(directoryURL, markExistingScreenshots: true)
            return
        }

        scanDirectory(directoryURL, markExistingScreenshots: false)
    }

    private func markExistingScreenshots() {
        for directoryURL in watchedDirectories {
            scanDirectory(directoryURL, markExistingScreenshots: true)
        }
    }

    private func scanDirectory(_ directoryURL: URL, markExistingScreenshots: Bool) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in fileURLs where isScreenshotCandidate(fileURL) {
            let path = fileURL.standardizedFileURL.path

            if markExistingScreenshots {
                knownScreenshotPaths.insert(path)
                continue
            }

            guard !knownScreenshotPaths.contains(path), !pendingScreenshotPaths.contains(path) else {
                continue
            }

            scheduleProcessing(for: fileURL)
        }
    }

    private func scheduleProcessing(for fileURL: URL) {
        let path = fileURL.standardizedFileURL.path
        knownScreenshotPaths.insert(path)
        pendingScreenshotPaths.insert(path)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.processScreenshot(at: fileURL, originalPath: path)
        }
    }

    private func processScreenshot(at fileURL: URL, originalPath: String) {
        pendingScreenshotPaths.remove(originalPath)

        guard !isPaused, fileManager.fileExists(atPath: fileURL.path), isScreenshotCandidate(fileURL) else {
            return
        }

        let captureTime = screenshotCaptureTime(for: fileURL)
        let context = screenshotContext(for: captureTime)
            ?? AppContext(timestamp: captureTime.fallbackTimestamp, appName: "Screenshot", windowTitle: nil)
        let destinationURL = filenameGenerator.destinationURL(for: fileURL, context: context)

        guard destinationURL.standardizedFileURL != fileURL.standardizedFileURL else { return }

        do {
            try fileManager.moveItem(at: fileURL, to: destinationURL)
            onStatusChange("Renamed \(destinationURL.lastPathComponent)")
        } catch {
            onStatusChange("Could not rename \(fileURL.lastPathComponent)")
        }
    }

    private func isScreenshotCandidate(_ fileURL: URL) -> Bool {
        guard fileURL.lastPathComponent.hasPrefix("Screenshot") else { return false }

        let supportedExtensions = ["png", "jpg", "jpeg", "heic", "tiff", "pdf"]
        guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { return false }

        let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }

    private func screenshotContext(for captureTime: ScreenshotCaptureTime) -> AppContext? {
        if let filenameBucket = captureTime.filenameBucket,
           let context = contextTracker.context(
            during: filenameBucket,
            referenceDate: captureTime.bucketReferenceTimestamp
           ) {
            return context
        }

        return contextTracker.context(closestTo: captureTime.fallbackTimestamp)
    }

    private func screenshotCaptureTime(for fileURL: URL) -> ScreenshotCaptureTime {
        let filenameDate = screenshotFilenameDate(for: fileURL)
        let resourceDate = resourceDate(for: fileURL)
        let filenameBucket = filenameDate.map { DateInterval(start: $0, duration: 1) }
        let bucketReferenceTimestamp = filenameBucket.flatMap { bucket -> Date? in
            guard let resourceDate,
                  resourceDate >= bucket.start,
                  resourceDate < bucket.end else {
                return nil
            }

            return resourceDate
        }

        return ScreenshotCaptureTime(
            fallbackTimestamp: filenameDate ?? resourceDate ?? Date(),
            filenameBucket: filenameBucket,
            bucketReferenceTimestamp: bucketReferenceTimestamp
        )
    }

    private func screenshotFilenameDate(for fileURL: URL) -> Date? {
        let stem = fileURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: #" \(\d+\)$"#, with: "", options: .regularExpression)

        return ScreenshotWatcher.filenameDateFormatterCandidates
            .compactMap { $0.date(from: stem) }
            .first
    }

    private func resourceDate(for fileURL: URL) -> Date? {
        let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
    }

    private static let filenameDateFormatterCandidates: [DateFormatter] = {
        let formats = [
            "'Screenshot' yyyy-MM-dd 'at' HH.mm.ss",
            "'Screenshot' yyyy-MM-dd 'at' h.mm.ss a"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()
}

private extension Array where Element == URL {
    var standardizedPaths: [String] {
        map { $0.standardizedFileURL.path }
    }
}

private struct ScreenshotCaptureTime {
    let fallbackTimestamp: Date
    let filenameBucket: DateInterval?
    let bucketReferenceTimestamp: Date?
}
