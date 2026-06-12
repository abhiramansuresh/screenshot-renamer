import CoreGraphics
import Foundation

#if !BENCHMARK_STANDALONE
@testable import ScreenRenamer
#endif

struct BenchmarkCase {
    let screenshotPath: String
    let expectedName: String
    let generatedName: String
    let passed: Bool
}

enum ScreenshotNamingBenchmark {
    static func makeCases() -> [BenchmarkCase] {
        fixtures.map { fixture in
            let generatedName = generatedName(for: fixture)
            return BenchmarkCase(
                screenshotPath: fixture.screenshotPath,
                expectedName: fixture.expectedName,
                generatedName: generatedName,
                passed: generatedName == fixture.expectedName
            )
        }
    }

    static func report(for cases: [BenchmarkCase]) -> String {
        let passCount = cases.filter(\.passed).count
        var lines = [
            "",
            "Screenshot naming benchmark",
            "Pass/fail: \(passCount)/\(cases.count)",
            String(repeating: "-", count: 72)
        ]

        for benchmarkCase in cases {
            lines.append(benchmarkCase.passed ? "PASS" : "FAIL")
            lines.append("  Screenshot: \(benchmarkCase.screenshotPath)")
            lines.append("  Expected:   \(benchmarkCase.expectedName)")
            lines.append("  Generated:  \(benchmarkCase.generatedName)")
        }

        return lines.joined(separator: "\n")
    }

    private static let fixtures: [BenchmarkFixture] = [
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Chrome_BrainMo.png",
            expectedName: "ManualCurriculumPipelineInspector",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "Manual Curriculum Pipeline Inspector",
                tabName: "BrainMo",
                browserDomain: nil
            ),
            tokens: []
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Chrome_GitHub_Document.png",
            expectedName: "ConflictResolution_TestDriveCrawl_Rule3_GitHub",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Google Chrome",
                windowTitle: "GitHub",
                browserDomain: "github.com"
            ),
            tokens: [
                OCRToken(
                    text: "Rule 3",
                    confidence: 0.95,
                    boundingRect: CGRect(x: 0.43, y: 0.42, width: 0.18, height: 0.07)
                ),
                OCRToken(
                    text: "ConflictResolution_TestDriveCrawl.md",
                    confidence: 0.95,
                    boundingRect: CGRect(x: 0.22, y: 0.52, width: 0.56, height: 0.09)
                )
            ]
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Figma_BrainMo.png",
            expectedName: "CatchUpOnSameDay",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Figma",
                windowTitle: "Catch-up on same day"
            ),
            tokens: []
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Finder_Debug.png",
            expectedName: "ScreenRenamer_DebugBuild",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Finder",
                windowTitle: "Debug",
                documentName: "ScreenRenamer_DebugBuild"
            ),
            tokens: []
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Figma_BrainMo_UI_Kit.png",
            expectedName: "TypographySystem",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Figma",
                windowTitle: "BrainMo UI Kit - Figma",
                documentName: "Typography System"
            ),
            tokens: []
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/VLC_In_The_Grey.png",
            expectedName: "InTheGrey20261080pWebripX26510bitAAC51YTSBZMp4",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "VLC",
                windowTitle: "In.The.Grey.2026.1080p.WEBRip.x265.10bit.AAC5.1-[YTS.BZ].mp4"
            ),
            tokens: []
        )
    ]

    private static func generatedName(for fixture: BenchmarkFixture) -> String {
        let originalURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(
                URL(fileURLWithPath: fixture.screenshotPath)
                    .deletingPathExtension()
                    .lastPathComponent
            )
            .appendingPathExtension("png")

        return FilenameGenerator()
            .destinationURL(
                for: originalURL,
                context: fixture.context,
                ocrResult: OCRResult(
                    tokens: fixture.tokens,
                    imageSize: CGSize(width: 1440, height: 900)
                ),
                windowMetadata: WindowMetadata(
                    appName: fixture.context.appName,
                    windowTitle: fixture.context.windowTitle,
                    documentName: fixture.context.documentName
                ),
                directoryURL: originalURL.deletingLastPathComponent()
            )
            .deletingPathExtension()
            .lastPathComponent
    }
}

private struct BenchmarkFixture {
    let screenshotPath: String
    let expectedName: String
    let context: AppContext
    let tokens: [OCRToken]
}
