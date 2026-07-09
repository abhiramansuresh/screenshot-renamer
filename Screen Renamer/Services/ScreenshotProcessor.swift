import Foundation

struct ScreenshotProcessingPlan {
    let destinationDirectoryURL: URL
    let destinationURL: URL
    let ocrResult: OCRResult?
    let windowMetadata: WindowMetadata?
}

struct ScreenshotProcessor {
    private let filenameGenerator: FilenameGenerator
    private let screenshotOrganizer: ScreenshotOrganizer
    private let ocrProcessor: OCRProcessor
    private let textScorer: TextScorer
    init(
        filenameGenerator: FilenameGenerator = FilenameGenerator(),
        screenshotOrganizer: ScreenshotOrganizer = ScreenshotOrganizer(),
        ocrProcessor: OCRProcessor = OCRProcessor(),
        textScorer: TextScorer = TextScorer()
    ) {
        self.filenameGenerator = filenameGenerator
        self.screenshotOrganizer = screenshotOrganizer
        self.ocrProcessor = ocrProcessor
        self.textScorer = textScorer
    }

    func processingPlan(for screenshotURL: URL, context: AppContext) async -> ScreenshotProcessingPlan {
        let startedAt = Date()
        let windowMetadata = WindowMetadata(
            appName: context.appName,
            windowTitle: context.windowTitle,
            documentName: context.documentName
        )
        let ocrResult = await recognizeTextIfPossible(in: screenshotURL, context: context, startedAt: startedAt)
        let destinationDirectoryURL = screenshotOrganizer.destinationDirectoryURL(
            for: screenshotURL,
            appName: context.appName
        )
        let destinationURL = filenameGenerator.destinationURL(
            for: screenshotURL,
            context: context,
            ocrResult: ocrResult,
            windowMetadata: windowMetadata,
            template: NamingTemplate.stored,
            directoryURL: destinationDirectoryURL
        )

        return ScreenshotProcessingPlan(
            destinationDirectoryURL: destinationDirectoryURL,
            destinationURL: destinationURL,
            ocrResult: ocrResult,
            windowMetadata: windowMetadata
        )
    }

    private func recognizeTextIfPossible(
        in screenshotURL: URL,
        context: AppContext,
        startedAt: Date
    ) async -> OCRResult? {
        do {
            let result = try await ocrProcessor.recognizeText(in: screenshotURL)
            ScreenshotDebugLogger.log("ocr_success", fields: [
                "file": screenshotURL.lastPathComponent,
                "milliseconds": "\(Int(Date().timeIntervalSince(startedAt) * 1000))",
                "token_count": "\(result.tokens.count)"
            ])
            logOCRCandidateSummary(result, context: context, screenshotURL: screenshotURL)
            return result
        } catch {
            ScreenshotDebugLogger.log("ocr_failed", fields: [
                "file": screenshotURL.lastPathComponent,
                "error": error.localizedDescription,
                "milliseconds": "\(Int(Date().timeIntervalSince(startedAt) * 1000))"
            ])
            return nil
        }
    }

    private func logOCRCandidateSummary(_ result: OCRResult, context: AppContext, screenshotURL: URL) {
        guard !context.isPrivacyRestrictedOCRApp else {
            ScreenshotDebugLogger.log("ocr_candidates_redacted", fields: [
                "app": context.appName,
                "file": screenshotURL.lastPathComponent,
                "reason": "privacy_restricted_app"
            ])
            return
        }

        let candidates = textScorer.scoredPhrases(from: result.tokens, context: context).prefix(5)
        ScreenshotDebugLogger.log("ocr_candidates", fields: [
            "app": context.appName,
            "candidate_count": "\(candidates.count)",
            "file": screenshotURL.lastPathComponent,
            "top_candidates": candidates.map(candidateSummary).joined(separator: " || ")
        ])
    }

    private func candidateSummary(_ phrase: ScoredOCRPhrase) -> String {
        let score = String(format: "%.1f", phrase.score)
        let confidence = String(format: "%.2f", phrase.confidence)
        return "\(phrase.text) [score=\(score), confidence=\(confidence)]"
    }
}
