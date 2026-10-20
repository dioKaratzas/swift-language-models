public import LanguageModels

/// How much of each page a web search returns to the model, from `low` to `high`.
///
/// Exa caps each result at a size the level picks, Parallel caps all results together, and Perplexity passes the level
/// on. Firecrawl and the hosts' own search ignore it. More context gives the model more to cite, and costs more prompt
/// tokens.
///
/// Sizes are an open vocabulary: any size OpenRouter lists is valid, with or without a static member.
public struct OpenRouterSearchContextSize: ProviderVocabulary {
    /// The size's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a size from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"medium"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
