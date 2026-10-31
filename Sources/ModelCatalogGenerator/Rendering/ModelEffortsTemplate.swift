/// Renders a namespace with an empty type for each of a source's models, such as `OpenRouterModels`, and each model's
/// effort levels as static members of `Efforts.Of` that type.
///
/// Each model has an effort type of its own, so the type stays the same when the model's levels change. A level the
/// model stopped accepting stays, marked deprecated.
enum ModelEffortsTemplate {
    /// The names that `Efforts.Of` already has, which no effort word's member can take.
    static let reservedNames: Set<String> = ["allCases", "rawValue", "reasoningLevel", "hashValue"]

    /// Where the source's generated file goes.
    static func path(for source: CatalogSource) -> String {
        "\(source.generatedDirectory)/\(source.modelsNamespace)+Efforts.swift"
    }

    static func render(_ snapshot: CatalogSnapshot, ranking: EffortRanking) throws(GeneratorError) -> GeneratedFile {
        let source = snapshot.source
        let namespace = source.modelsNamespace
        let models = (snapshot.models + snapshot.removed.map(\.model)).sorted { $0.id < $1.id }
        try SwiftIdentifier.check(
            models.map { (SwiftIdentifier.type(for: $0.id), $0.id) },
            reserved: ["Protocol", "Self", "Type"],
            kind: "\(source.displayName) model types"
        )

        var lines = SourceText.header(from: [source])
        // A model type's lists keep the protocol's documentation.
        lines.insert("// swift-format-ignore-file: AlwaysUseLowerCamelCase, AllPublicDeclarationsHaveDocumentation", at: 0)
        lines += ["public import LanguageModels", ""]
        lines += SourceText.documentation(
            "A type for each model in \(source.displayName)'s catalog, whose effort type is "
                + "`Efforts.Of<\(namespace).ModelName>`.",
            indent: ""
        )
        lines += ["public enum \(namespace) {"]
        for (index, model) in models.enumerated() {
            if index > 0 { lines += [""] }
            lines += SourceText.documentation(model.displayName, indent: "    ")
            lines += ["    public enum \(SwiftIdentifier.type(for: model.id)): ModelEffortList {"]
            lines += wordsLines("efforts", ranking.sorted(model.reasoningEfforts))
            let removed = ranking.sorted(model.removedReasoningEfforts.map(\.word))
            if !removed.isEmpty { lines += wordsLines("removedEfforts", removed) }
            lines += ["    }"]
        }
        lines += ["}"]
        for model in models {
            lines += effortLines(of: model, source: source, ranking: ranking)
        }
        return GeneratedFile(path: path(for: source), contents: SourceText.file(lines))
    }

    /// A model type's list of effort words.
    private static func wordsLines(_ name: String, _ words: [String]) -> [String] {
        SwiftExpression.array(words.map { .atom(SwiftLiteral.string($0)) })
            .lines(indent: "        ", prefix: "public static var \(name): [String] { ", suffix: " }")
    }

    /// The static members of a model's effort type: one for each level it accepts, and a deprecated one for each level
    /// it stopped accepting, highest first.
    private static func effortLines(of model: CatalogModel, source: CatalogSource, ranking: EffortRanking) -> [String] {
        let removedOn = Dictionary(model.removedReasoningEfforts.map { ($0.word, $0.removedOn) }) { first, _ in first }
        let words = ranking.sorted(model.reasoningEfforts + removedOn.keys)
        guard !words.isEmpty else { return [] }
        var lines = ["", "extension Efforts.Of where Model == \(source.modelType(of: model)) {"]
        for (index, word) in words.enumerated() {
            if index > 0 { lines += [""] }
            lines += SourceText.documentation(ReasoningLevelTemplate.summary(of: word), indent: "    ")
            if let day = removedOn[word] {
                let message = "\(source.displayName) stopped accepting this level for this model" + (day.map { " on \($0)" } ?? "")
                lines += ["    @available(*, deprecated, message: \(SwiftLiteral.string(message)))"]
            }
            let name = SwiftIdentifier.effortMember(for: word)
            lines += ["    public static var \(name): Self { Self(listed: \(SwiftLiteral.string(word))) }"]
        }
        lines += ["}"]
        return lines
    }
}
