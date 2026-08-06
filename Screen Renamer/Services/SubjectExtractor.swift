import Foundation
import NaturalLanguage

// On-device named-entity detection (organization/person/place), used to rank title
// segments in FilenameGenerator ahead of the old "take the first segment" heuristic.
// NLTagger's .nameType scheme ships with macOS (no download, no network) and is
// deterministic for a given OS/model version — same input always yields the same tags.
//
// ponytail: NER only for now. Redundancy detection (FilenameGenerator.covers) stays
// on substring/token matching until this slice is verified against the benchmark;
// embeddings are the natural follow-up there.
enum SubjectExtractor {
    private static let entityTags: Set<NLTag> = [.organizationName, .personalName, .placeName]

    /// Recognized organization/person/place names in `text`, in the order they appear.
    ///
    /// Must be called on the *full, unsplit* title, not on a fragment of it — NLTagger's
    /// accuracy relies on surrounding sentence context. Tagging "Acme Corp Budget" in
    /// isolation finds nothing; tagging "Q3 Planning — Acme Corp Budget" finds "Acme".
    /// Callers match these phrases back against candidate segments of the original title.
    static func namedEntityPhrases(in text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var phrases: [String] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            if let tag, entityTags.contains(tag) {
                phrases.append(String(text[range]))
            }
            return true
        }

        return phrases
    }
}
