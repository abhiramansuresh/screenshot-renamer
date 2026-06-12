import AppKit
import ApplicationServices
import Foundation

struct WindowMetadata: Equatable {
    let appName: String
    let windowTitle: String?
    let documentName: String?
}

struct WindowMetadataSnapshot {
    let appName: String
    let windowTitle: String?
    let documentName: String?
}

struct WindowMetadataProvider {
    typealias SnapshotProvider = () -> WindowMetadataSnapshot?

    private let snapshotProvider: SnapshotProvider

    init(snapshotProvider: @escaping SnapshotProvider = WindowMetadataProvider.accessibilitySnapshot) {
        self.snapshotProvider = snapshotProvider
    }

    func metadata() -> WindowMetadata? {
        guard let snapshot = snapshotProvider() else { return nil }
        let appName = snapshot.appName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !appName.isEmpty else { return nil }

        return WindowMetadata(
            appName: appName,
            windowTitle: Self.cleaned(snapshot.windowTitle),
            documentName: Self.documentName(from: snapshot.documentName)
        )
    }

    private static func accessibilitySnapshot() -> WindowMetadataSnapshot? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        let appName = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let windowElement = focusedWindow(for: appElement) ?? mainWindow(for: appElement)

        return WindowMetadataSnapshot(
            appName: appName.isEmpty ? "Unknown" : appName,
            windowTitle: windowElement.flatMap { string(for: kAXTitleAttribute as CFString, of: $0) },
            documentName: windowElement.flatMap { string(for: "AXDocument" as CFString, of: $0) }
        )
    }

    private static func focusedWindow(for appElement: AXUIElement) -> AXUIElement? {
        var focusedWindowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )

        guard result == .success, let focusedWindowValue else { return nil }
        return (focusedWindowValue as! AXUIElement)
    }

    private static func mainWindow(for appElement: AXUIElement) -> AXUIElement? {
        var mainWindowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &mainWindowValue
        )

        guard result == .success, let mainWindowValue else { return nil }
        return (mainWindowValue as! AXUIElement)
    }

    private static func string(for attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success, let value else { return nil }

        if let string = value as? String {
            return string
        }

        if let url = value as? URL {
            return url.absoluteString
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }

        return nil
    }

    static func documentName(from rawDocumentName: String?) -> String? {
        guard let rawDocumentName = cleaned(rawDocumentName) else { return nil }

        if let url = URL(string: rawDocumentName), url.isFileURL {
            let lastPathComponent = url.lastPathComponent
            return lastPathComponent.isEmpty ? nil : lastPathComponent
        }

        if rawDocumentName.contains("/") {
            let lastPathComponent = URL(fileURLWithPath: rawDocumentName).lastPathComponent
            return lastPathComponent.isEmpty ? nil : lastPathComponent
        }

        return rawDocumentName
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleanedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedValue.isEmpty ? nil : cleanedValue
    }
}
