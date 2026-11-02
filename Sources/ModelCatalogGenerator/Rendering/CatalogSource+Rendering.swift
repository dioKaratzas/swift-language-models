extension CatalogSource {
    /// The availability attribute of a generated member whose model or word the provider stopped listing: deprecated
    /// rather than unavailable, so code that names it still compiles, with a warning.
    ///
    /// - Parameter day: The day the provider stopped listing the model or word, or `nil` for an effort word, which every
    ///   provider shares.
    /// - Returns: The attribute.
    func removedAttribute(on day: CatalogDay?) -> String {
        let message = day.map { "Removed from \(displayName) on \($0)" } ?? "Removed from \(displayName)"
        return "@available(*, deprecated, message: \(SwiftLiteral.string(message)))"
    }

    /// The provider's name in Swift, which names its generated files and members, such as `ModelRemovals.openRouter`.
    var swiftName: String {
        switch self {
        case .openrouter: "OpenRouter"
        }
    }

    /// The generated namespace that holds a type for each of the provider's models, which names the model's efforts,
    /// such as `OpenRouterCatalog`.
    var modelsNamespace: String {
        "\(swiftName)Catalog"
    }

    /// The generated type of the provider's model with the given member name, such as
    /// `OpenRouterCatalog.AnthropicClaudeHaiku5_5` for `anthropicClaudeHaiku5_5`.
    func modelType(named member: SwiftIdentifier) -> String {
        "\(modelsNamespace).\(member.capitalized)"
    }

    /// The effort type of the provider's model with the given member name, such as
    /// `Efforts.Of<OpenRouterCatalog.AnthropicClaudeHaiku5_5>` for `anthropicClaudeHaiku5_5`.
    func effortType(named member: SwiftIdentifier) -> String {
        "Efforts.Of<\(modelType(named: member))>"
    }

    /// The folder of the provider's generated sources, relative to the package root.
    var generatedDirectory: String {
        switch self {
        case .openrouter: "Sources/OpenRouterLanguageModels/Generated"
        }
    }

    /// The generated type that gives each word of a vocabulary a static member.
    func typeName(of vocabulary: CatalogVocabulary) -> String {
        switch (self, vocabulary) {
        case (.openrouter, .inputModalities): "OpenRouterInputModality"
        case (.openrouter, .outputModalities): "OpenRouterOutputModality"
        case (.openrouter, .parameters): "OpenRouterParameter"
        case (.openrouter, .searchContextSizes): "OpenRouterSearchContextSize"
        case (.openrouter, .webFetchEngines): "OpenRouterWebFetchEngine"
        case (.openrouter, .webSearchEngines): "OpenRouterWebSearchEngine"
        case (.openrouter, .webSearchModes): "OpenRouterWebSearchMode"
        }
    }
}
