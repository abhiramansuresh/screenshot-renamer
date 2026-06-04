import Foundation

struct NoiseFilter {
    private let genericNoiseWords: Set<String> = [
        "a", "an", "and", "are", "at", "back", "battery", "cancel", "chrome",
        "done", "edit", "file", "finder", "forward", "go", "help", "is", "new",
        "of", "open", "safari", "search", "share", "the", "to", "view", "window"
    ]

    private let genericNoisePhrases: Set<String> = [
        "file edit view",
        "file edit view window help",
        "back forward",
        "done cancel",
        "search share",
        "untitled",
        "new tab",
        "screenshot"
    ]

    private let timestampPattern = #"(?i)\b(?:[01]?\d|2[0-3])[:.][0-5]\d(?:\s?[ap]m)?\b"#
    private let datePattern = #"(?i)\b(?:20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]20\d{2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b"#

    func cleanedText(_ text: String) -> String? {
        let collapsed = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty,
              !isNoise(collapsed),
              !isPunctuationHeavy(collapsed) else {
            return nil
        }

        return collapsed
    }

    func isNoise(_ text: String) -> Bool {
        let textWithoutDateTime = removingDateTimeNoise(from: text)
        let normalized = normalizedPhrase(textWithoutDateTime)
        guard !normalized.isEmpty else { return true }

        if genericNoisePhrases.contains(normalized) {
            return true
        }

        if containsOnlyDateTimeRemainder(textWithoutDateTime) {
            return true
        }

        let words = normalizedWords(from: textWithoutDateTime)
        guard !words.isEmpty else { return true }

        if words.count == 1 {
            return words[0].count <= 1 || genericNoiseWords.contains(words[0])
        }

        let noiseWordCount = words.filter { genericNoiseWords.contains($0) }.count
        return Double(noiseWordCount) / Double(words.count) >= 0.75
    }

    func normalizedPhrase(_ text: String) -> String {
        normalizedWords(from: text).joined(separator: " ")
    }

    func normalizedWords(from text: String) -> [String] {
        text
            .lowercased()
            .replacingOccurrences(of: #"[_\-./|:()[\]{}]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9+#]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
    }

    private func removingDateTimeNoise(from text: String) -> String {
        text
            .replacingOccurrences(of: timestampPattern, with: " ", options: .regularExpression)
            .replacingOccurrences(of: datePattern, with: " ", options: .regularExpression)
    }

    private func containsOnlyDateTimeRemainder(_ text: String) -> Bool {
        let words = normalizedWords(from: text)
        guard !words.isEmpty else { return true }

        return words.allSatisfy { word in
            word.range(of: #"^\d+$"#, options: .regularExpression) != nil
                || ["am", "pm"].contains(word)
        }
    }

    private func isPunctuationHeavy(_ text: String) -> Bool {
        let scalarCount = text.unicodeScalars.count
        guard scalarCount >= 4 else { return false }

        let alphanumericCount = text.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }.count

        return Double(alphanumericCount) / Double(scalarCount) < 0.45
    }
}
