/// Renders a static member for each word of a vocabulary, as an extension of the vocabulary's type.
enum VocabularyTemplate {
    /// Where the vocabulary's generated file goes.
    static func path(of vocabulary: CatalogVocabulary, from source: CatalogSource) -> String {
        "\(source.generatedDirectory)/\(source.typeName(of: vocabulary))+Catalog.swift"
    }

    static func render(_ vocabulary: CatalogVocabulary, of snapshot: CatalogSnapshot) throws(GeneratorError) -> GeneratedFile {
        let source = snapshot.source
        let typeName = source.typeName(of: vocabulary)
        let words = (snapshot.vocabularies[vocabulary] ?? []).map { (word: $0, name: SwiftIdentifier.member(for: $0.word)) }
        try SwiftIdentifier.check(
            words.map { ($0.name, $0.word.word) },
            reserved: SwiftIdentifier.optionalCaseNames,
            kind: "\(typeName) words"
        )

        var lines = SourceText.header(from: [source])
        lines += ["import LanguageModels", "", "extension \(typeName) {"]
        for (index, (word, name)) in words.enumerated() {
            if index > 0 { lines += [""] }
            lines += SourceText.documentation(word.summary ?? vocabulary.fallbackSummary(for: word.word), indent: "    ")
            if let removedOn = word.removedOn { lines += ["    \(source.removedAttribute(on: removedOn))"] }
            lines += ["    public static let \(name): Self = \(SwiftLiteral.string(word.word))"]
        }
        lines += ["}"]
        return GeneratedFile(path: path(of: vocabulary, from: source), contents: SourceText.file(lines))
    }
}
