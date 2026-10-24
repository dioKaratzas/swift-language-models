public import LanguageModels

/// The engine that runs the searches of the ``OpenRouterServerTool`` web search.
///
/// `auto`, OpenRouter's default, searches with the host's own search when the model's host has one, and with Exa
/// otherwise. `native` asks for the host's own search, also falling back to Exa. The other engines are search services
/// that OpenRouter calls for the model.
///
/// Each search costs extra, on top of the model's tokens: Exa, Parallel and Perplexity charge per search, Firecrawl per
/// search and per result, all from the account's OpenRouter credits, and a host's own search at the host's price.
/// Each engine keeps what it's sent under its own data retention policy. With zero data retention enforced on the
/// account, OpenRouter rejects Firecrawl; Exa, Parallel, Perplexity and the hosts' own search still apply their own
/// policies.
///
/// Engines are an open vocabulary: any engine OpenRouter lists is valid, with or without a static member.
public struct OpenRouterWebSearchEngine: ProviderVocabulary {
    /// The engine's name in OpenRouter's API.
    public let rawValue: String

    /// Creates an engine from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"exa"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an engine from a string literal of its name in OpenRouter's API.
    ///
    /// - Parameter value: The name, such as `"exa"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }
}
