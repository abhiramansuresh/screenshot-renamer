import XCTest

final class ScreenshotNamingBenchmarkTests: XCTestCase {
    func testScreenshotNamingBenchmarkPrintsReport() {
        let cases = ScreenshotNamingBenchmark.makeCases()

        print(ScreenshotNamingBenchmark.report(for: cases))

        XCTAssertEqual(cases.count, 7)
        XCTAssertTrue(cases.allSatisfy { !$0.generatedName.isEmpty })
    }
}
