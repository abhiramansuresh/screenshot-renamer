import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ContextTracker {
    private var timer: Timer?
    private var buffer: [AppContext] = []
    private let maxContextAge: TimeInterval = 10
    private let maxEntryCount = 24

    func start() {
        guard timer == nil else { return }

        captureCurrentContext()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureCurrentContext()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        buffer.removeAll()
    }

    func context(closestTo date: Date) -> AppContext? {
        ContextMatcher.nearestContext(in: buffer, to: date)
    }

    private func captureCurrentContext() {
        let timestamp = Date()
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApplication?.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)

        let context = AppContext(
            timestamp: timestamp,
            appName: appName?.isEmpty == false ? appName! : "Unknown",
            windowTitle: frontmostApplication.flatMap { focusedWindowTitle(for: $0.processIdentifier) }
        )

        buffer.append(context)
        pruneBuffer(relativeTo: timestamp)
    }

    private func focusedWindowTitle(for processIdentifier: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        var focusedWindowValue: CFTypeRef?

        let focusedWindowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )

        guard focusedWindowResult == .success, let focusedWindowValue else {
            return mainWindowTitle(for: appElement)
        }

        return title(for: focusedWindowValue as! AXUIElement)
    }

    private func mainWindowTitle(for appElement: AXUIElement) -> String? {
        var mainWindowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &mainWindowValue
        )

        guard result == .success, let mainWindowValue else { return nil }
        return title(for: mainWindowValue as! AXUIElement)
    }

    private func title(for windowElement: AXUIElement) -> String? {
        var titleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            windowElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        guard result == .success else { return nil }
        return (titleValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pruneBuffer(relativeTo date: Date) {
        buffer.removeAll { date.timeIntervalSince($0.timestamp) > maxContextAge }

        if buffer.count > maxEntryCount {
            buffer.removeFirst(buffer.count - maxEntryCount)
        }
    }
}
