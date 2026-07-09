import Foundation

enum ScreenshotDebugLogger {
    private static let queue = DispatchQueue(label: "com.screenrenamer.debuglogger", qos: .background)

    static var logURL: URL {
        supportDirectoryURL().appendingPathComponent("debug.log", isDirectory: false)
    }

    static func log(_ event: String, fields: [String: String] = [:]) {
        let line = formattedLine(event: event, fields: fields)
        let url = logURL

        queue.async {
            do {
                try ensureLogFileExistsOnQueue(at: url)
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                if let data = (line + "\n").data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } catch {
                NSLog("Screen Renamer debug log failed: %@", error.localizedDescription)
            }
        }
    }

    static func ensureLogFileExists() throws {
        let directoryURL = supportDirectoryURL()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
    }

    static func clear() {
        let url = logURL
        queue.async {
            do {
                try ensureLogFileExistsOnQueue(at: url)
                try Data().write(to: url)
            } catch {
                NSLog("Screen Renamer debug log clear failed: %@", error.localizedDescription)
            }
        }
    }

    private static func ensureLogFileExistsOnQueue(at url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }

    private static func supportDirectoryURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupportURL.appendingPathComponent("Screen Renamer", isDirectory: true)
    }

    private static func formattedLine(event: String, fields: [String: String]) -> String {
        let timestamp = Self.dateFormatter.string(from: Date())
        let fieldText = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(quoted($0.value))" }
            .joined(separator: " ")

        if fieldText.isEmpty {
            return "\(timestamp) event=\(event)"
        }

        return "\(timestamp) event=\(event) \(fieldText)"
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        return "\"\(escaped)\""
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
