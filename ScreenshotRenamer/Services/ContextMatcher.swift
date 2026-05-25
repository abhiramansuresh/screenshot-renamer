import Foundation

enum ContextMatcher {
    static func nearestContext(in buffer: [AppContext], to date: Date) -> AppContext? {
        buffer.min { left, right in
            abs(left.timestamp.timeIntervalSince(date)) < abs(right.timestamp.timeIntervalSince(date))
        }
    }
}
