/// Renders one `Efforts` enum for each distinct set of effort words.
enum EffortSetsTemplate {
    static let path = "Sources/LanguageModels/Generated/Efforts+Sets.swift"

    /// The file of effort sets, with a documented case for each word and the removed sets marked unavailable.
    ///
    /// - Parameters:
    ///   - sets: The effort types of the sets, in order.
    ///   - removed: The sets that no model accepts any more, each with a source it left.
    ///   - sources: The sources of the catalogs.
    /// - Returns: The generated file.
    static func render(_ sets: [EffortType], removed: [EffortType: CatalogSource], sources: [CatalogSource]) -> GeneratedFile {
        var lines = SourceText.header(from: sources)
        lines += ["extension Efforts {"]
        for (index, set) in sets.enumerated() {
            let words = set.words
            let summary =
                words.count == 1 ? "The level \(SourceText.prose(words))." : "The levels \(SourceText.prose(words)), highest first."
            if index > 0 { lines += [""] }
            lines += SourceText.documentation(summary, indent: "    ")
            if let source = removed[set] { lines += ["    \(source.removedAttribute)"] }
            lines += ["    public enum \(set.name): String, ModelEffort, CaseIterable, Codable {"]
            for (caseIndex, word) in words.enumerated() {
                let name = SwiftIdentifier.effortCase(for: word)
                if caseIndex > 0 { lines += [""] }
                lines += SourceText.documentation(ReasoningLevelTemplate.summary(of: word), indent: "        ")
                lines += [name.name == word ? "        case \(name)" : "        case \(name) = \(SwiftLiteral.string(word))"]
            }
            lines += ["    }"]
        }
        lines += ["}"]
        return GeneratedFile(path: path, contents: SourceText.file(lines))
    }
}
