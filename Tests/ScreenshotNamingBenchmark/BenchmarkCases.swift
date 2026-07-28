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
            expectedName: "Chrome_ManualCurriculumPipelineInspector",
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
            expectedName: "Chrome_ConflictResolution_TestDriveCrawl",
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
            expectedName: "Figma_CatchUpOnSameDay",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Figma",
                windowTitle: "Catch-up on same day"
            ),
            tokens: []
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Finder_Debug.png",
            expectedName: "Finder_ScreenRenamer_DebugBuild",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Finder",
                windowTitle: "Debug",
                documentName: "ScreenRenamer_DebugBuild"
            ),
            tokens: []
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Xcode_Screen_Renamer_Project.png",
            expectedName: "Xcode_ScreenRenamer",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Xcode",
                windowTitle: "Screen Renamer — Screen Renamer.xcodeproj",
                documentName: "Screen Renamer.xcodeproj"
            ),
            tokens: []
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Figma_BrainMo_UI_Kit.png",
            expectedName: "Figma_TypographySystem",
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
            expectedName: "VLC_InTheGrey20261080p",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "VLC",
                windowTitle: "In.The.Grey.2026.1080p.WEBRip.x265.10bit.AAC5.1-[YTS.BZ].mp4"
            ),
            tokens: []
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Safari_GitHub_TasteSkill.png",
            expectedName: "GitHub_Leonxlnx_Taste_Skill",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Safari",
                windowTitle: "Leonxlnx/taste-skill: Taste-Skill - gives your AI good taste, stops the AI from generating slop",
                browserDomain: "github.com"
            ),
            tokens: [],
            template: appDomainTitleTemplate
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Safari_Instagram_Messages.png",
            expectedName: "Instagram_Messages",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Safari",
                windowTitle: "(1) Instagram • Messages",
                browserDomain: "instagram.com"
            ),
            tokens: [],
            template: appDomainTitleTemplate
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Safari_BenShih_Portfolio.png",
            expectedName: "Benshih",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Safari",
                windowTitle: "Ben Shih | Product Designer Portfolio, AI Design & Growth Design Case Studies",
                browserDomain: "benshih.design"
            ),
            tokens: [],
            template: appDomainTitleTemplate
        ),
        BenchmarkFixture(
            screenshotPath: "Tests/ScreenshotNamingBenchmark/Safari_Abhiraman_Portfolio.png",
            expectedName: "Abhiraman_Abhi_Suresh",
            context: AppContext(
                timestamp: Date(timeIntervalSince1970: 0),
                appName: "Safari",
                windowTitle: "Abhi Suresh — Senior Product Designer & AI Builder",
                browserDomain: "abhiraman.in"
            ),
            tokens: [],
            template: appDomainTitleTemplate
        )
    ]

    private static let appDomainTitleTemplate = NamingTemplate(
        fields: [.app, .domain, .windowTitle],
        separator: "_",
        prefix: "",
        suffix: ""
    )

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
                template: fixture.template,
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
    var template: NamingTemplate = .default
}
