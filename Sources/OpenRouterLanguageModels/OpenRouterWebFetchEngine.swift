public import LanguageModels

/// The engine that fetches pages for the ``OpenRouterServerTool`` web fetch.
///
/// `auto`, OpenRouter's default, fetches with the host's own fetch when the model's host has one, and with Exa
/// otherwise. `native` asks for the host's own fetch, falling back to `openrouter`, OpenRouter's own fetcher, which is
/// free. The other engines are services that OpenRouter calls for the model.
///
/// Each fetch with Exa, Parallel or Firecrawl costs extra, on top of the model's tokens, from the account's OpenRouter
/// credits, and a host's own fetch costs the host's price. Each engine keeps what it's sent under its own data
/// retention policy. With zero data retention enforced on the account, OpenRouter rejects Firecrawl; Exa, Parallel and
/// the hosts' own fetch still apply their own policies.
///
/// Engines are an open vocabulary: any engine OpenRouter lists is valid, with or without a static member.
public struct OpenRouterWebFetchEngine: ProviderVocabulary {
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
