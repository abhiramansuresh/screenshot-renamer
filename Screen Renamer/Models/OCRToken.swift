import CoreGraphics
import Foundation

struct OCRToken: Equatable {
    let text: String
    let confidence: Float
    let boundingRect: CGRect

    init(text: String, confidence: Float, boundingRect: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingRect = boundingRect
    }
}

struct OCRResult: Equatable {
    let tokens: [OCRToken]
    let imageSize: CGSize?

    init(tokens: [OCRToken], imageSize: CGSize? = nil) {
        self.tokens = tokens
        self.imageSize = imageSize
    }
}
