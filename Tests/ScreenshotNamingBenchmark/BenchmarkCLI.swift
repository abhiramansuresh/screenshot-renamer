import Darwin
import Foundation

let cases = ScreenshotNamingBenchmark.makeCases()
print(ScreenshotNamingBenchmark.report(for: cases))

let failedCount = cases.filter { !$0.passed }.count

if CommandLine.arguments.contains("--strict"), failedCount > 0 {
    fputs("Benchmark failed: \(failedCount) case(s) did not match expected names.\n", stderr)
    exit(1)
}
