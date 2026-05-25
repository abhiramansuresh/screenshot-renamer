import Foundation

@MainActor
final class ScreenshotWatcher {
    private let contextTracker: ContextTracker
    private let filenameGenerator = FilenameGenerator()
    private let fileManager = FileManager.default
    private let onStatusChange: (String) -> Void
    private let onLocationsChange: ([URL]) -> Void
    private let onRenameCompleted: (URL) -> Void

    private var watchers: [DirectoryWatcher] = []
    private var watchedDirectories: [URL] = []
    // Paths that already existed before watching/resuming. Newly detected screenshots
    // stay pending only, so a recreated native filename can still be processed.
    private var knownScreenshotPaths = Set<String>()
    private var pendingScreenshotPaths = Set<String>()
    private var locationRefreshTimer: Timer?
    private var isRunning = false
    private var isPaused = false

    init(
        contextTracker: ContextTracker,
        onStatusChange: @escaping (String) -> Void,
        onLocationsChange: @escaping ([URL]) -> Void,
        onRenameCompleted: @escaping (URL) -> Void
    ) {
        self.contextTracker = contextTracker
        self.onStatusChange = onStatusChange
        self.onLocationsChange = onLocationsChange
        self.onRenameCompleted = onRenameCompleted
    }

    deinit {
        locationRefreshTimer?.invalidate()
        watchers.forEach { $0.cancel() }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        ScreenshotDebugLogger.log("watcher_start", fields: [
            "context_schema": "app_window_tab_domain_v2"
        ])
        rebuildWatchers(markExistingScreenshots: true)
        startLocationRefreshTimer()
    }

    func pause() {
        ScreenshotDebugLogger.log("watcher_pause", fields: [
            "pending_count": "\(pendingScreenshotPaths.count)"
        ])
        isPaused = true
        pendingScreenshotPaths.removeAll()
        markExistingScreenshots()
        onStatusChange("Renaming paused")
    }

    func resume() {
        isPaused = false
        ScreenshotDebugLogger.log("watcher_resume")
        markExistingScreenshots()
        onStatusChange("Watching for screenshots")
    }

    func refreshLocations() {
        guard isRunning else {
            let directories = ScreenshotLocationResolver.screenshotDirectories()
            ScreenshotDebugLogger.log("locations_refresh_before_start", fields: [
                "directories": directories.debugPathList
            ])
            onLocationsChange(directories)
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
            ScreenshotDebugLogger.log("locations_unchanged", fields: [
                "announce": "\(announceUnchanged)",
                "directories": watchedDirectories.debugPathList
            ])
            if announceUnchanged {
                onLocationsChange(watchedDirectories)
                onStatusChange(isPaused ? "Renaming paused" : "Watching for screenshots")
            }
            return
        }

        ScreenshotDebugLogger.log("locations_changed", fields: [
            "old": watchedDirectories.debugPathList,
            "new": latestDirectories.debugPathList
        ])
        rebuildWatchers(
            markExistingScreenshots: true,
            statusMessage: latestDirectories.isEmpty ? "No screenshot folder found" : "Updated screenshot folder"
        )
    }

    private func rebuildWatchers(markExistingScreenshots: Bool, statusMessage: String? = nil) {
        ScreenshotDebugLogger.log("watchers_rebuild_begin", fields: [
            "mark_existing": "\(markExistingScreenshots)"
        ])
        watchers.forEach { $0.cancel() }
        watchers.removeAll()

        watchedDirectories = ScreenshotLocationResolver.screenshotDirectories()
        onLocationsChange(watchedDirectories)

        for directoryURL in watchedDirectories {
            if let watcher = DirectoryWatcher(directoryURL: directoryURL, onChange: { [weak self] changedDirectoryURL in
                self?.handleDirectoryChange(changedDirectoryURL)
            }) {
                watchers.append(watcher)
                ScreenshotDebugLogger.log("watcher_created", fields: [
                    "directory": directoryURL.path
                ])
            } else {
                ScreenshotDebugLogger.log("watcher_create_failed", fields: [
                    "directory": directoryURL.path
                ])
            }

            scanDirectory(directoryURL, markExistingScreenshots: markExistingScreenshots)
        }

        ScreenshotDebugLogger.log("watchers_rebuild_end", fields: [
            "watcher_count": "\(watchers.count)",
            "directories": watchedDirectories.debugPathList
        ])
        onStatusChange(statusMessage ?? (watchedDirectories.isEmpty ? "No screenshot folder found" : "Watching for screenshots"))
    }

    private func handleDirectoryChange(_ directoryURL: URL) {
        ScreenshotDebugLogger.log("directory_changed", fields: [
            "directory": directoryURL.path,
            "paused": "\(isPaused)"
        ])

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
        let fileURLs: [URL]

        do {
            fileURLs = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            ScreenshotDebugLogger.log("scan_failed", fields: [
                "directory": directoryURL.path,
                "error": error.localizedDescription
            ])
            return
        }

        var candidateCount = 0
        ScreenshotDebugLogger.log("scan_begin", fields: [
            "directory": directoryURL.path,
            "file_count": "\(fileURLs.count)",
            "mark_existing": "\(markExistingScreenshots)"
        ])

        for fileURL in fileURLs {
            guard isScreenshotCandidate(fileURL) else {
                if fileURL.lastPathComponent.hasPrefix("Screenshot") {
                    ScreenshotDebugLogger.log("scan_skip_not_candidate", fields: [
                        "file": fileURL.lastPathComponent,
                        "reason": screenshotCandidateRejectionReason(for: fileURL) ?? "unknown"
                    ])
                }
                continue
            }

            candidateCount += 1
            let path = fileURL.standardizedFileURL.path

            if markExistingScreenshots {
                knownScreenshotPaths.insert(path)
                ScreenshotDebugLogger.log("scan_mark_existing", fields: [
                    "file": fileURL.lastPathComponent
                ])
                continue
            }

            if knownScreenshotPaths.contains(path) {
                ScreenshotDebugLogger.log("scan_skip_known", fields: [
                    "file": fileURL.lastPathComponent
                ])
                continue
            }

            if pendingScreenshotPaths.contains(path) {
                ScreenshotDebugLogger.log("scan_skip_pending", fields: [
                    "file": fileURL.lastPathComponent
                ])
                continue
            }

            scheduleProcessing(for: fileURL)
        }

        ScreenshotDebugLogger.log("scan_end", fields: [
            "directory": directoryURL.path,
            "candidate_count": "\(candidateCount)"
        ])
    }

    private func scheduleProcessing(for fileURL: URL) {
        let path = fileURL.standardizedFileURL.path
        pendingScreenshotPaths.insert(path)
        ScreenshotDebugLogger.log("process_scheduled", fields: [
            "file": fileURL.lastPathComponent,
            "delay_seconds": "0.8"
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.processScreenshot(at: fileURL, originalPath: path)
        }
    }

    private func processScreenshot(at fileURL: URL, originalPath: String) {
        pendingScreenshotPaths.remove(originalPath)
        ScreenshotDebugLogger.log("process_begin", fields: [
            "file": fileURL.lastPathComponent,
            "original_path": originalPath
        ])

        guard !isPaused else {
            ScreenshotDebugLogger.log("process_skip", fields: [
                "file": fileURL.lastPathComponent,
                "reason": "paused"
            ])
            return
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            ScreenshotDebugLogger.log("process_skip", fields: [
                "file": fileURL.lastPathComponent,
                "reason": "file_missing"
            ])
            return
        }

        guard isScreenshotCandidate(fileURL) else {
            ScreenshotDebugLogger.log("process_skip", fields: [
                "file": fileURL.lastPathComponent,
                "reason": screenshotCandidateRejectionReason(for: fileURL) ?? "not_candidate"
            ])
            return
        }

        let captureTime = screenshotCaptureTime(for: fileURL)
        let context = screenshotContext(for: captureTime)
            ?? AppContext(timestamp: captureTime.fallbackTimestamp, appName: "Screenshot", windowTitle: nil)
        let destinationURL = filenameGenerator.destinationURL(for: fileURL, context: context)

        ScreenshotDebugLogger.log("process_resolved", fields: [
            "file": fileURL.lastPathComponent,
            "capture": captureTime.debugDescription,
            "context_schema": "app_window_tab_domain_v2",
            "context_app": context.appName,
            "context_title": context.windowTitle ?? "",
            "context_tab": context.tabName ?? "",
            "context_domain": context.browserDomain ?? "",
            "context_timestamp": Self.debugDateFormatter.string(from: context.timestamp),
            "destination": destinationURL.lastPathComponent
        ])

        guard destinationURL.standardizedFileURL != fileURL.standardizedFileURL else {
            ScreenshotDebugLogger.log("process_skip", fields: [
                "file": fileURL.lastPathComponent,
                "reason": "destination_matches_original"
            ])
            return
        }

        ScreenshotDebugLogger.log("move_attempt", fields: [
            "from": fileURL.lastPathComponent,
            "to": destinationURL.lastPathComponent
        ])

        do {
            try fileManager.moveItem(at: fileURL, to: destinationURL)
            ScreenshotDebugLogger.log("move_success", fields: [
                "from": fileURL.lastPathComponent,
                "to": destinationURL.lastPathComponent
            ])
            onRenameCompleted(destinationURL)
            onStatusChange("Renamed \(destinationURL.lastPathComponent)")
        } catch {
            ScreenshotDebugLogger.log("move_failed", fields: [
                "file": fileURL.lastPathComponent,
                "destination": destinationURL.lastPathComponent,
                "error": error.localizedDescription
            ])
            onStatusChange("Could not rename \(fileURL.lastPathComponent)")
        }
    }

    private func isScreenshotCandidate(_ fileURL: URL) -> Bool {
        screenshotCandidateRejectionReason(for: fileURL) == nil
    }

    private func screenshotCandidateRejectionReason(for fileURL: URL) -> String? {
        guard fileURL.lastPathComponent.hasPrefix("Screenshot") else { return "name_prefix" }
        let supportedExtensions = ["png", "jpg", "jpeg", "heic", "tiff", "pdf"]
        guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { return "extension" }

        let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values?.isRegularFile == true else { return "not_regular_file" }

        return nil
    }

    private func screenshotContext(for captureTime: ScreenshotCaptureTime) -> AppContext? {
        if let filenameBucket = captureTime.filenameBucket {
            if let context = contextTracker.context(
                during: filenameBucket,
                referenceDate: captureTime.bucketReferenceTimestamp
            ) {
                return context
            }

            if let context = contextTracker.context(before: filenameBucket.start) {
                return context
            }
        }

        return contextTracker.context(closestTo: captureTime.fallbackTimestamp)
    }

    private func screenshotCaptureTime(for fileURL: URL) -> ScreenshotCaptureTime {
        let filenameDate = screenshotFilenameDate(for: fileURL)
        let fileTimestamps = fileTimestamps(for: fileURL)
        let filenameBucket = filenameDate.map { DateInterval(start: $0, duration: 1) }
        let bucketReferenceTimestamp = filenameBucket.flatMap { bucket -> Date? in
            fileTimestamps.timestamp(in: bucket)
        }

        return ScreenshotCaptureTime(
            fallbackTimestamp: filenameDate ?? fileTimestamps.fallbackTimestamp ?? Date(),
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

    private func fileTimestamps(for fileURL: URL) -> ScreenshotFileTimestamps {
        let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return ScreenshotFileTimestamps(
            creationDate: values?.creationDate,
            modificationDate: values?.contentModificationDate
        )
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

    private static let debugDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension Array where Element == URL {
    var standardizedPaths: [String] {
        map { $0.standardizedFileURL.path }
    }

    var debugPathList: String {
        map(\.path).joined(separator: ",")
    }
}

private struct ScreenshotCaptureTime {
    let fallbackTimestamp: Date
    let filenameBucket: DateInterval?
    let bucketReferenceTimestamp: Date?

    var debugDescription: String {
        let bucketText: String

        if let filenameBucket {
            bucketText = "\(Self.dateFormatter.string(from: filenameBucket.start))...\(Self.dateFormatter.string(from: filenameBucket.end))"
        } else {
            bucketText = "nil"
        }

        return [
            "fallback=\(Self.dateFormatter.string(from: fallbackTimestamp))",
            "bucket=\(bucketText)",
            "reference=\(bucketReferenceTimestamp.map { Self.dateFormatter.string(from: $0) } ?? "nil")"
        ].joined(separator: ";")
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct ScreenshotFileTimestamps {
    let creationDate: Date?
    let modificationDate: Date?

    var fallbackTimestamp: Date? {
        creationDate ?? modificationDate
    }

    func timestamp(in interval: DateInterval) -> Date? {
        [creationDate, modificationDate]
            .compactMap { $0 }
            .first { timestamp in
                timestamp >= interval.start && timestamp < interval.end
            }
    }
}
