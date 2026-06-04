import Foundation

struct ScreenshotProcessingPlan {
    let destinationDirectoryURL: URL
    let destinationURL: URL
    let ocrResult: OCRResult?
}

struct ScreenshotProcessor {
    private let filenameGenerator: FilenameGenerator
    private let screenshotOrganizer: ScreenshotOrganizer
    private let ocrProcessor: OCRProcessor

    init(
        filenameGenerator: FilenameGenerator = FilenameGenerator(),
        screenshotOrganizer: ScreenshotOrganizer = ScreenshotOrganizer(),
        ocrProcessor: OCRProcessor = OCRProcessor()
    ) {
        self.filenameGenerator = filenameGenerator
        self.screenshotOrganizer = screenshotOrganizer
        self.ocrProcessor = ocrProcessor
    }

    func processingPlan(for screenshotURL: URL, context: AppContext) async -> ScreenshotProcessingPlan {
        let startedAt = Date()
        let ocrResult = await recognizeTextIfPossible(in: screenshotURL, startedAt: startedAt)
        let destinationDirectoryURL = screenshotOrganizer.destinationDirectoryURL(
            for: screenshotURL,
            appName: context.appName
        )
        let destinationURL = filenameGenerator.destinationURL(
            for: screenshotURL,
            context: context,
            ocrResult: ocrResult,
            directoryURL: destinationDirectoryURL
        )

        return ScreenshotProcessingPlan(
            destinationDirectoryURL: destinationDirectoryURL,
            destinationURL: destinationURL,
            ocrResult: ocrResult
        )
    }

    private func recognizeTextIfPossible(in screenshotURL: URL, startedAt: Date) async -> OCRResult? {
        do {
            let result = try await ocrProcessor.recognizeText(in: screenshotURL)
            ScreenshotDebugLogger.log("ocr_success", fields: [
                "file": screenshotURL.lastPathComponent,
                "milliseconds": "\(Int(Date().timeIntervalSince(startedAt) * 1000))",
                "token_count": "\(result.tokens.count)"
            ])
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
}
