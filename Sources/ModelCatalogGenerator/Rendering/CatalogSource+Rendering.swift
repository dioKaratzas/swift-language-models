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
        case .openai: "OpenAI"
        }
    }

    /// The provider's name in Swift as the start of a member's name, such as `openRouter`.
    var memberPrefix: String {
        swiftName.prefix(1).lowercased() + swiftName.dropFirst()
    }

    /// The provider module's type of a model's details, such as `OpenRouterModel`.
    var modelTypeName: String {
        "\(swiftName)Model"
    }

    /// The arguments of the provider module's model initializer that not every provider's takes, such as OpenRouter's
    /// `aliasTarget`. A model whose data needs one that its provider's initializer doesn't take can't become code.
    var optionalModelArguments: Set<String> {
        switch self {
        case .openrouter: ["aliasTarget", "cachesOnlyMarkedPrompts", "outputModalities"]
        case .openai: []
        }
    }

    /// The provider module's type of a model id, such as `OpenRouterModelID`.
    var modelIDTypeName: String {
        "\(swiftName)ModelID"
    }

    /// A model id the generated documentation shows, such as `typesafe/jev-router`.
    var exampleModelID: String {
        switch self {
        case .openrouter: "typesafe/jev-router"
        case .openai: "gpt-6-luna"
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
        "Sources/\(swiftName)LanguageModels/Generated"
    }

    /// The generated type that gives each word of a vocabulary a static member, such as `OpenRouterParameter`.
    func typeName(of vocabulary: CatalogVocabulary) -> String {
        let word =
            switch vocabulary {
            case .inputModalities: "InputModality"
            case .outputModalities: "OutputModality"
            case .parameters: "Parameter"
            case .searchContextSizes: "SearchContextSize"
            case .webFetchEngines: "WebFetchEngine"
            case .webSearchEngines: "WebSearchEngine"
            case .webSearchModes: "WebSearchMode"
            }
        return "\(swiftName)\(word)"
    }
}
