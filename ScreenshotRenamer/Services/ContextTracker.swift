import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ContextTracker {
    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var isTracking = false
    private var buffer: [AppContext] = []
    private let activationSettleDelays: [TimeInterval] = [0.05, 0.15]
    private let maxContextAge: TimeInterval = 10
    private let maxEntryCount = 80

    func start() {
        guard !isTracking else { return }
        isTracking = true

        captureCurrentContext()
        startActivationObserver()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureCurrentContext()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stopActivationObserver()
        isTracking = false
        buffer.removeAll()
    }

    func context(closestTo date: Date) -> AppContext? {
        ContextMatcher.nearestContext(in: buffer, to: date)
    }

    func context(during interval: DateInterval, referenceDate: Date?) -> AppContext? {
        ContextMatcher.bestContext(in: buffer, during: interval, referenceDate: referenceDate)
    }

    func context(before date: Date) -> AppContext? {
        ContextMatcher.latestContext(in: buffer, before: date)
    }

    private func captureCurrentContext() {
        captureContext(for: NSWorkspace.shared.frontmostApplication)
    }

    private func captureContext(for application: NSRunningApplication?) {
        let timestamp = Date()
        let appName = application?.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)

        let context = AppContext(
            timestamp: timestamp,
            appName: appName?.isEmpty == false ? appName! : "Unknown",
            windowTitle: application.flatMap { focusedWindowTitle(for: $0.processIdentifier) }
        )

        buffer.append(context)
        pruneBuffer(relativeTo: timestamp)
    }

    private func startActivationObserver() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self, self.isTracking else { return }
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    self.captureCurrentContext()
                    self.scheduleSettledActivationCapture(for: nil)
                    return
                }

                self.captureContext(for: application)
                self.scheduleSettledActivationCapture(for: application)
            }
        }
    }

    private func stopActivationObserver() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }

        activationObserver = nil
    }

    private func scheduleSettledActivationCapture(for application: NSRunningApplication?) {
        for delay in activationSettleDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, application] in
                guard let self, self.isTracking else { return }

                if let application {
                    guard application.isActive else { return }
                    self.captureContext(for: application)
                } else {
                    self.captureCurrentContext()
                }
            }
        }
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
