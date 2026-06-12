import CoreGraphics
import XCTest
@testable import ScreenRenamer

final class OCRNamingTests: XCTestCase {
    private let generator = FilenameGenerator()

    func testClearTitleUsesOCRChunksBeforeAppLabel() {
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

        XCTAssertEqual(destination, "ConflictResolution_TestDriveCrawl_Rule3_GitHub.png")
    }

    func testDocumentFilenameOCRCandidateWinsBeforeGenericPhrase() {
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

        XCTAssertEqual(destination, "ProjectNotes_Manual_Curriculum_Pipeline_Inspector_GitHub.png")
    }

    func testPrivacyRestrictedAppsIgnoreOCRMessageBody() {
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

        XCTAssertEqual(destination, "Slack_Product_Design.png")
    }

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

        XCTAssertEqual(destination, "ManualCurriculumPipelineInspector.png")
    }

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

        XCTAssertEqual(destination, "ScreenRenamer_DebugBuild.png")
    }

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

        XCTAssertEqual(destination, "ScreenRenamer_DebugBuild.png")
    }

    func testNoisyBrowserChromeDoesNotDriveFilename() {
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

        XCTAssertEqual(destination, "Conflict_Resolution_Rule3_GitHub.png")
    }

    func testFinderScreenshotUsesVisibleSelection() {
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

        XCTAssertEqual(destination, "Project_Assets_Finder.png")
    }

    func testIDEScreenshotFavorsFileNameAndVisibleSymbol() {
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

        XCTAssertEqual(destination, "ScreenshotWatcher_processScreenshot_Visual_Studio_Code.png")
    }

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

        XCTAssertEqual(destination, "PDA_Onboarding_Figma.png")
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
