/// Renders the named reasoning levels and the effort ranking, as an extension of Apple's `ReasoningLevel`.
enum ReasoningLevelTemplate {
    static let path = "Sources/LanguageModels/Generated/ReasoningLevel+Efforts.swift"

    /// Global functions that a static member with the same name hides inside the type's extensions.
    private static let globalFunctionNames: Set<String> = ["max", "min"]

    static func render(ranking: [String], sources: [CatalogSource]) -> GeneratedFile {
        var lines = SourceText.header(from: sources)
        lines += ["public import FoundationModels", "", "extension ContextOptions.ReasoningLevel {"]
        for word in ranking {
            let name = SwiftIdentifier.effortCase(for: word)
            let summary = word == "none" ? "The `none` effort, which turns reasoning off." : "The `\(word)` effort."
            lines += ["    /// \(summary)"]
            if Self.globalFunctionNames.contains(name) {
                lines += [
                    "    ///",
                    "    /// Inside an extension of `ContextOptions.ReasoningLevel`, this hides the global `\(name)(_:_:)`; call that one",
                    "    /// as `Swift.\(name)`.",
                ]
            }
            lines += ["    public static var \(name): Self { .custom(\(SwiftLiteral.string(word))) }", ""]
        }
        lines += ["    /// Every effort word providers use, highest first."]
        lines += SourceText.array("package static let effortRanking = ", ranking.map(SwiftLiteral.string), indent: "    ")
        lines += ["}"]
        return GeneratedFile(path: path, contents: SourceText.file(lines))
    }
}
