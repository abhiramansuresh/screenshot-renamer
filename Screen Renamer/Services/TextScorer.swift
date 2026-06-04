import CoreGraphics
import Foundation

struct ScoredOCRPhrase: Equatable {
    let text: String
    let score: Double
    let confidence: Float
    let boundingRect: CGRect
}

struct TextScorer {
    private let noiseFilter: NoiseFilter
    private let minimumConfidence: Float = 0.45

    init(noiseFilter: NoiseFilter = NoiseFilter()) {
        self.noiseFilter = noiseFilter
    }

    func scoredPhrases(from tokens: [OCRToken], context: AppContext) -> [ScoredOCRPhrase] {
        let cleanedTokens = tokens.compactMap { token -> OCRToken? in
            guard token.confidence >= minimumConfidence,
                  let cleanedText = noiseFilter.cleanedText(token.text) else {
                return nil
            }

            return OCRToken(
                text: cleanedText,
                confidence: token.confidence,
                boundingRect: token.boundingRect
            )
        }

        let frequencyByPhrase = Dictionary(
            grouping: cleanedTokens,
            by: { noiseFilter.normalizedPhrase($0.text) }
        ).mapValues(\.count)

        return cleanedTokens
            .map { token in
                scoredPhrase(
                    from: token,
                    context: context,
                    frequency: frequencyByPhrase[noiseFilter.normalizedPhrase(token.text)] ?? 1
                )
            }
            .filter { $0.score >= 18 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                if lhs.boundingRect.minY != rhs.boundingRect.minY {
                    return lhs.boundingRect.minY > rhs.boundingRect.minY
                }

                return lhs.text.localizedCaseInsensitiveCompare(rhs.text) == .orderedAscending
            }
    }

    private func scoredPhrase(
        from token: OCRToken,
        context: AppContext,
        frequency: Int
    ) -> ScoredOCRPhrase {
        var score = 0.0
        let words = noiseFilter.normalizedWords(from: token.text)
        let rect = token.boundingRect.standardized
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let centerDistance = hypot(center.x - 0.5, center.y - 0.5)
        let centerWeight = max(0, 1 - centerDistance / 0.72)
        let heightWeight = min(1, max(0, Double(rect.height) / 0.08))
        let widthWeight = min(1, max(0, Double(rect.width) / 0.35))

        score += Double(token.confidence) * 28
        score += centerWeight * 18
        score += heightWeight * 16
        score += widthWeight * 5

        if words.count >= 2 {
            score += min(14, Double(words.count) * 3)
        } else {
            score -= 8
        }

        if looksLikeFilename(token.text) {
            score += 18
        }

        if looksLikeHeading(token.text) {
            score += 8
        }

        if containsAppRelevantTerm(token.text, context: context) {
            score += 8
        }

        if frequency > 1 {
            score -= min(16, Double(frequency - 1) * 5)
        }

        if rect.maxY > 0.93 {
            score -= 24
        }

        if rect.minY < 0.04 {
            score -= 8
        }

        if rect.maxX < 0.22 || rect.minX > 0.82 {
            score -= 6
        }

        if token.text.count <= 2 {
            score -= 16
        }

        return ScoredOCRPhrase(
            text: token.text,
            score: score,
            confidence: token.confidence,
            boundingRect: rect
        )
    }

    private func looksLikeFilename(_ text: String) -> Bool {
        text.range(
            of: #"\b[\w\- ]+\.(swift|md|txt|pdf|png|jpe?g|heic|fig|json|csv|xlsx?|docx?|pptx?|html?|css|js|ts|tsx|jsx)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func looksLikeHeading(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }

        let words = trimmed.split(separator: " ")
        let capitalizedWords = words.filter { word in
            guard let firstScalar = word.unicodeScalars.first else { return false }
            return CharacterSet.uppercaseLetters.contains(firstScalar)
        }

        return !words.isEmpty && Double(capitalizedWords.count) / Double(words.count) >= 0.5
    }

    private func containsAppRelevantTerm(_ text: String, context: AppContext) -> Bool {
        let normalizedText = text.lowercased()
        let appName = context.appName.lowercased()

        if appName.contains("code") || appName.contains("xcode") {
            return looksLikeFilename(text)
                || normalizedText.contains("branch")
                || normalizedText.contains("commit")
        }

        if appName.contains("finder") {
            return looksLikeFilename(text)
                || normalizedText.contains("folder")
                || normalizedText.contains("download")
        }

        if appName.contains("chrome") || appName.contains("safari") || appName.contains("browser") {
            return normalizedText.contains("github")
                || normalizedText.contains("notion")
                || normalizedText.contains("figma")
                || normalizedText.contains("google")
        }

        return false
    }
}
