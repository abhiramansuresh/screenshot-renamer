import CoreGraphics
import Foundation
import ImageIO
import Vision

struct OCRProcessor {
    func recognizeText(in imageURL: URL) async throws -> OCRResult {
        try await Task.detached(priority: .utility) {
            try Self.recognizeTextSynchronously(in: imageURL)
        }.value
    }

    private static func recognizeTextSynchronously(in imageURL: URL) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        // .fast mode returns capped ~0.5 confidences, which permanently failed the
        // 0.62 minimum in FilenameGenerator and produced garbled tokens ("8uild", "laude").
        // .accurate gives graded confidences and clean words; extra latency is fine
        // for a background rename.
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        try handler.perform([request])

        let tokens = (request.results ?? []).compactMap { observation -> OCRToken? in
            guard let candidate = observation.topCandidates(1).first else { return nil }

            return OCRToken(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingRect: observation.boundingBox
            )
        }

        return OCRResult(tokens: tokens, imageSize: imageSize(for: imageURL))
    }

    private static func imageSize(for imageURL: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        guard let width = numericCGFloat(properties[kCGImagePropertyPixelWidth]),
              let height = numericCGFloat(properties[kCGImagePropertyPixelHeight]) else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    private static func numericCGFloat(_ value: Any?) -> CGFloat? {
        switch value {
        case let value as CGFloat:
            return value
        case let value as Double:
            return CGFloat(value)
        case let value as Int:
            return CGFloat(value)
        case let value as NSNumber:
            return CGFloat(truncating: value)
        default:
            return nil
        }
    }
}
