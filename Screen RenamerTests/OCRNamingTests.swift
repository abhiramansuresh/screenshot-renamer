import CoreGraphics
import XCTest
@testable import ScreenRenamer

final class OCRNamingTests: XCTestCase {
    private let generator = FilenameGenerator()

    // App name is always first; OCR document filename fills the title slot.
    func testDocumentFilenameOCRCandidateWinsOverContextFallback() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "GitHub",
                browserDomain: "github.com"
            ),
            tokens: [
                token("Manual Curriculum Pipeline Inspector", x: 0.30, y: 0.50, width: 0.42, height: 0.08),
                token("ProjectNotes.md", x: 0.72, y: 0.88, width: 0.20, height: 0.04)
            ]
        )

        XCTAssertEqual(destination, "Chrome_ProjectNotes.png")
    }

    // OCR document filename in a tab-context with a visible .md file.
    func testDocumentFilenameOCRWinsOverBodyText() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "GitHub",
                tabName: "ConflictResolution_TestDriveCrawl.md",
                browserDomain: "github.com"
            ),
            tokens: [
                token("ConflictResolution_TestDriveCrawl.md", x: 0.22, y: 0.52, width: 0.56, height: 0.09),
                token("Rule 3", x: 0.43, y: 0.42, width: 0.18, height: 0.07)
            ]
        )

        // Body text "Rule 3" is ignored; OCR document filename fills the title slot.
        XCTAssertEqual(destination, "Chrome_ConflictResolution_TestDriveCrawl.png")
    }

    // Privacy-restricted apps: OCR is skipped entirely (including document filenames).
    func testPrivacyRestrictedAppsIgnoreOCRDocumentFilename() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Slack",
                windowTitle: "Product Design"
            ),
            tokens: [
                token("Quarterly launch plan is blocked", x: 0.28, y: 0.50, width: 0.44, height: 0.08),
                token("PrivateNotes.md", x: 0.32, y: 0.60, width: 0.24, height: 0.04)
            ]
        )

        // Even a document filename visible in a privacy-restricted app is not used.
        XCTAssertEqual(destination, "Slack_Product_Design.png")
    }

    // Long window metadata title wins over OCR document filename.
    func testLongWindowMetadataTitleWinsBeforeOCR() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "GitHub",
                browserDomain: "github.com"
            ),
            tokens: [
                token("ConflictResolution_TestDriveCrawl.md", x: 0.22, y: 0.52, width: 0.56, height: 0.09)
            ],
            windowMetadata: WindowMetadata(
                appName: "Google Chrome",
                windowTitle: "Manual Curriculum Pipeline Inspector",
                documentName: nil
            )
        )

        XCTAssertEqual(destination, "Chrome_ManualCurriculumPipelineInspector.png")
    }

    // Short window title (<4 words) falls through to document name.
    func testWindowMetadataDocumentNameWinsBeforeOCRWhenTitleIsShort() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Finder",
                windowTitle: "Debug"
            ),
            tokens: [
                token("Project Assets", x: 0.34, y: 0.48, width: 0.32, height: 0.08)
            ],
            windowMetadata: WindowMetadata(
                appName: "Finder",
                windowTitle: "Debug",
                documentName: "ScreenRenamer_DebugBuild"
            )
        )

        XCTAssertEqual(destination, "Finder_ScreenRenamer_DebugBuild.png")
    }

    // Document name from context (not passed as windowMetadata) also drives metadata fallback.
    func testCaptureContextDocumentNameCanDriveMetadataFallback() {
        let context = AppContext(
            timestamp: Date(timeIntervalSince1970: 0),
            appName: "Finder",
            windowTitle: "Debug",
            documentName: "ScreenRenamer_DebugBuild"
        )
        let destination = generatedName(
            context: context,
            tokens: [
                token("Project Assets", x: 0.34, y: 0.48, width: 0.32, height: 0.08)
            ],
            windowMetadata: WindowMetadata(
                appName: context.appName,
                windowTitle: context.windowTitle,
                documentName: context.documentName
            )
        )

        XCTAssertEqual(destination, "Finder_ScreenRenamer_DebugBuild.png")
    }

    // Repeated window title collapses, then falls back to clean document name.
    func testRepeatedWindowMetadataTitleFallsBackToCleanDocumentName() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Xcode",
                windowTitle: "Screen Renamer — Screen Renamer.xcodeproj",
                documentName: "Screen Renamer.xcodeproj"
            ),
            tokens: [],
            windowMetadata: WindowMetadata(
                appName: "Xcode",
                windowTitle: "Screen Renamer — Screen Renamer.xcodeproj",
                documentName: "Screen Renamer.xcodeproj"
            )
        )

        XCTAssertEqual(destination, "Xcode_ScreenRenamer.png")
    }

    // No OCR, no window metadata — short title folds into app+title context name.
    func testShortWindowTitleFallsBackToContextNaming() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "Claude",
                browserDomain: nil
            ),
            tokens: [
                token("laude", confidence: 0.92, x: 0.30, y: 0.50, width: 0.30, height: 0.07)
            ]
        )

        // OCR body text "laude" is ignored; result is app+title context.
        XCTAssertEqual(destination, "Chrome_Claude.png")
    }

    // Noisy browser chrome tokens are ignored; falls back to context.
    func testNoisyBrowserTokensFallBackToContext() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "GitHub",
                tabName: nil,
                browserDomain: "github.com"
            ),
            tokens: [
                token("File Edit View 10:33 AM", confidence: 0.98, x: 0.02, y: 0.96, width: 0.34, height: 0.02),
                token("Conflict Resolution", x: 0.32, y: 0.55, width: 0.36, height: 0.08),
                token("Rule 3", x: 0.44, y: 0.45, width: 0.18, height: 0.07)
            ]
        )

        // Body text is ignored; domain display name "GitHub" equals the window title,
        // so distinctPageName returns nil — only app name remains.
        XCTAssertEqual(destination, "Chrome.png")
    }

    // Finder screenshot: short window title goes through context naming.
    func testFinderScreenshotWithShortTitleUsesContext() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Finder",
                windowTitle: "Desktop"
            ),
            tokens: [
                token("Project Assets", x: 0.34, y: 0.48, width: 0.32, height: 0.08),
                token("Search", confidence: 0.94, x: 0.78, y: 0.92, width: 0.12, height: 0.03)
            ]
        )

        XCTAssertEqual(destination, "Finder_Desktop.png")
    }

    // IDE screenshot: visible .swift filename drives naming via OCR document detection.
    func testIDEScreenshotUsesVisibleSwiftFilename() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Visual Studio Code",
                windowTitle: "screenshot_renamer"
            ),
            tokens: [
                token("ScreenshotWatcher.swift", x: 0.30, y: 0.58, width: 0.40, height: 0.07),
                token("processScreenshot", x: 0.34, y: 0.46, width: 0.32, height: 0.05)
            ]
        )

        // "Visual Studio Code" is aliased to "VSCode"; OCR doc filename fills the title slot.
        XCTAssertEqual(destination, "VSCode_ScreenshotWatcher.png")
    }

    // Low-confidence OCR has no document filename; falls back to context.
    func testLowConfidenceOCRFallsBackToContextNaming() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "GitHub Pull Request - Google Chrome",
                tabName: "GitHub Pull Request",
                browserDomain: "github.com"
            ),
            tokens: [
                token("Almost Meaningful", confidence: 0.30, x: 0.30, y: 0.50, width: 0.40, height: 0.08)
            ]
        )

        XCTAssertEqual(destination, "Chrome_GitHub_Pull_Request.png")
    }

    func testEmptyOCRAndEmptyContextFallsBackToScreenshot() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Screenshot",
                windowTitle: nil
            ),
            tokens: []
        )

        XCTAssertEqual(destination, "Screenshot.png")
    }

    func testSameInputProducesSameFilename() {
        let context = AppContext(
            timestamp: Date(timeIntervalSince1970: 0),
            appName: "Google Chrome",
            windowTitle: "Google Sheets",
            tabName: "Year 8 Science Timetable",
            browserDomain: "google.com"
        )
        let tokens = [
            token("Year 8 Science Timetable", x: 0.24, y: 0.52, width: 0.52, height: 0.08),
            token("Google Sheets", x: 0.04, y: 0.90, width: 0.20, height: 0.04)
        ]

        XCTAssertEqual(generatedName(context: context, tokens: tokens), generatedName(context: context, tokens: tokens))
    }

    func testScoringAndGenerationStayFastForManyTokens() {
        let context = AppContext(
            timestamp: Date(timeIntervalSince1970: 0),
            appName: "Google Chrome",
            windowTitle: "GitHub",
            browserDomain: "github.com"
        )
        let tokens = (0..<250).map { index in
            token(
                index == 125 ? "Conflict Resolution" : "Search",
                confidence: 0.90,
                x: 0.30,
                y: 0.50,
                width: 0.35,
                height: 0.06
            )
        }

        let startedAt = Date()
        _ = generatedName(context: context, tokens: tokens)
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 0.20)
    }

    func testNoiseFilterRejectsMenuBarTimestampText() {
        XCTAssertNil(NoiseFilter().cleanedText("File Edit View 10:33 AM"))
    }

    func testNoiseFilterAllowsMonthNameInRealTitle() {
        XCTAssertEqual(NoiseFilter().cleanedText("May Project Plan"), "May Project Plan")
    }

    // Unsafe characters in the window title are sanitized.
    func testFilenameSanitizationRemovesUnsafeCharacters() {
        let destination = generatedName(
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Figma",
                windowTitle: "PDA Onboarding"
            ),
            tokens: [
                token("PDA: Onboarding / Figma?", x: 0.24, y: 0.52, width: 0.52, height: 0.08)
            ]
        )

        // Window title "PDA Onboarding" is only 2 words so context title is used.
        // "PDA" is not a known acronym so it title-cases to "Pda".
        XCTAssertEqual(destination, "Figma_Pda_Onboarding.png")
    }

    private func generatedName(
        context: AppContext,
        tokens: [OCRToken],
        windowMetadata: WindowMetadata? = nil
    ) -> String {
        let originalURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("Screenshot 2026-06-03 at 14.33.21")
            .appendingPathExtension("png")

        return generator.destinationURL(
            for: originalURL,
            context: context,
            ocrResult: OCRResult(tokens: tokens, imageSize: CGSize(width: 1440, height: 900)),
            windowMetadata: windowMetadata,
            directoryURL: originalURL.deletingLastPathComponent()
        ).lastPathComponent
    }

    private func token(
        _ text: String,
        confidence: Float = 0.95,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> OCRToken {
        OCRToken(
            text: text,
            confidence: confidence,
            boundingRect: CGRect(x: x, y: y, width: width, height: height)
        )
    }
}
