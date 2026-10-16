/// Renders the named reasoning levels and the effort ranking, as an extension of Apple's `ReasoningLevel`.
enum ReasoningLevelTemplate {
    static let path = "Sources/LanguageModels/Generated/ReasoningLevel+Efforts.swift"

    static func render(ranking: [String], sources: [CatalogSource]) -> GeneratedFile {
        var lines = SourceText.header(from: sources)
        lines += ["public import FoundationModels", "", "extension ContextOptions.ReasoningLevel {"]
        for word in ranking {
            let summary = word == "none" ? "The `none` effort, which turns reasoning off." : "The `\(word)` effort."
            lines += [
                "    /// \(summary)",
                "    public static var \(SwiftIdentifier.effortCase(for: word)): Self { .custom(\(SwiftLiteral.string(word))) }",
                "",
            ]
        }
        lines += ["    /// Every effort word providers use, highest first."]
        lines += SourceText.array("package static let effortRanking = ", ranking.map(SwiftLiteral.string), indent: "    ")
        lines += ["}"]
        return GeneratedFile(path: path, contents: SourceText.file(lines))
    }
}
