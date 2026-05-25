import Foundation

enum ContextMatcher {
    static func nearestContext(in buffer: [AppContext], to date: Date) -> AppContext? {
        buffer.min { left, right in
            abs(left.timestamp.timeIntervalSince(date)) < abs(right.timestamp.timeIntervalSince(date))
        }
    }

    static func bestContext(
        in buffer: [AppContext],
        during interval: DateInterval,
        referenceDate: Date?
    ) -> AppContext? {
        let candidates = buffer.filter {
            $0.timestamp >= interval.start && $0.timestamp < interval.end
        }

        guard !candidates.isEmpty else { return nil }

        if let referenceDate,
           referenceDate >= interval.start,
           referenceDate < interval.end {
            return nearestContext(in: candidates, to: referenceDate)
        }

        return candidates.max { left, right in
            left.timestamp < right.timestamp
        }
    }
}
