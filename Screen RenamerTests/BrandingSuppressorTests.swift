import CoreGraphics
import XCTest
@testable import ScreenRenamer

final class BrandingSuppressorTests: XCTestCase {
    func testSeedWordsAreSuppressed() {
        let suppressor = BrandingSuppressor()
        let seedWords = [
            "BrainMo",
            "Chrome",
            "Figma",
            "Finder",
            "Safari",
            "Xcode",
            "Dashboard",
            "Settings",
            "Home",
            "Profile",
            "Untitled",
            "Overview"
        ]

        for word in seedWords {
            XCTAssertTrue(suppressor.isSuppressed(word), "\(word) should be suppressed")
        }
    }

    func testContentWordIsNotSuppressed() {
        XCTAssertFalse(BrandingSuppressor().isSuppressed("CurriculumPipeline"))
    }

    func testSuppressedBrandingCannotBecomePrimaryOCRCandidate() {
        let phrases = TextScorer().scoredPhrases(
            from: [
                OCRToken(
                    text: "BrainMo",
                    confidence: 0.99,
                    boundingRect: CGRect(x: 0.30, y: 0.45, width: 0.45, height: 0.10)
                ),
                OCRToken(
                    text: "Manual Curriculum",
                    confidence: 0.92,
                    boundingRect: CGRect(x: 0.34, y: 0.48, width: 0.30, height: 0.06)
                )
            ],
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "BrainMo"
            )
        )

        XCTAssertEqual(phrases.first?.text, "Manual Curriculum")
        XCTAssertFalse(phrases.contains { $0.text == "BrainMo" })
    }
}
