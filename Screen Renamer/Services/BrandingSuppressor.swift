import Foundation

struct BrandingSuppressor {
    static let suppressedWords: Set<String> = [
        "brainmo",
        "chrome",
        "figma",
        "finder",
        "safari",
        "xcode",
        "dashboard",
        "settings",
        "home",
        "profile",
        "untitled",
        "overview"
    ]

    func isSuppressed(_ word: String) -> Bool {
        Self.suppressedWords.contains(Self.normalized(word))
    }

    static func isSuppressed(_ word: String) -> Bool {
        Self.suppressedWords.contains(Self.normalized(word))
    }

    private static func normalized(_ word: String) -> String {
        word
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }
}
