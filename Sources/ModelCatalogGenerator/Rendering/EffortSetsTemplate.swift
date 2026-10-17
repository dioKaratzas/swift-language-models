/// Renders one `Efforts` enum for each distinct set of effort words.
enum EffortSetsTemplate {
    static let path = "Sources/LanguageModels/Generated/Efforts+Sets.swift"

    static func render(_ sets: [[String]], sources: [CatalogSource]) -> GeneratedFile {
        var lines = SourceText.header(from: sources)
        lines += ["extension Efforts {"]
        for (index, words) in sets.enumerated() {
            let name = EffortType.setTypeName(words)
            let summary =
                words.count == 1 ? "The level \(SourceText.prose(words))." : "The levels \(SourceText.prose(words)), highest first."
            if index > 0 { lines += [""] }
            lines += [
                "    /// \(summary)",
                "    public enum \(name): String, ModelEffort, CaseIterable, Codable {",
            ]
            lines += words.map { word in
                let name = SwiftIdentifier.effortCase(for: word)
                return name == word ? "        case \(name)" : "        case \(name) = \(SwiftLiteral.string(word))"
            }
            lines += ["    }"]
        }
        lines += ["}"]
        return GeneratedFile(path: path, contents: SourceText.file(lines))
    }
}
