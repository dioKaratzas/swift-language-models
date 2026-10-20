extension CatalogSource {
    /// The availability attribute of a generated member whose model or word left the provider.
    var removedAttribute: String {
        "@available(*, unavailable, message: \(SwiftLiteral.string("Removed from \(displayName)")))"
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
