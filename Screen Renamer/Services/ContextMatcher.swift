import Foundation

enum ContextMatcher {
    private static let lateBucketEdgeTolerance: TimeInterval = 0.15
    private static let previousContextFreshnessLimit: TimeInterval = 2

    static func nearestContext(in buffer: [AppContext], to date: Date) -> AppContext? {
        buffer.min { left, right in
            abs(left.timestamp.timeIntervalSince(date)) < abs(right.timestamp.timeIntervalSince(date))
        }
    }

    static func latestContext(in buffer: [AppContext], before date: Date) -> AppContext? {
        buffer
            .filter { $0.timestamp < date }
            .max { left, right in
                left.timestamp < right.timestamp
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

        guard let latestCandidate = candidates.max(by: { left, right in
            left.timestamp < right.timestamp
        }) else {
            return nil
        }

        if let previousContext = previousContextForLateBucketEdge(
            in: buffer,
            interval: interval,
            latestCandidate: latestCandidate
        ) {
            return previousContext
        }

        return latestCandidate
    }

    private static func previousContextForLateBucketEdge(
        in buffer: [AppContext],
        interval: DateInterval,
        latestCandidate: AppContext
    ) -> AppContext? {
        let timeUntilBucketEnd = interval.end.timeIntervalSince(latestCandidate.timestamp)
        guard timeUntilBucketEnd >= 0,
              timeUntilBucketEnd <= lateBucketEdgeTolerance else {
            return nil
        }

        guard let previousContext = latestContext(in: buffer, before: interval.start) else {
            return nil
        }

        let previousContextAge = interval.start.timeIntervalSince(previousContext.timestamp)
        guard previousContextAge >= 0,
              previousContextAge <= previousContextFreshnessLimit else {
            return nil
        }

        return previousContext
    }
}
