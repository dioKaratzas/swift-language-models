public import LanguageModels

/// A host that serves models on OpenRouter, by name or slug, such as `Anthropic` or `amazon-bedrock`.
///
/// OpenRouter calls the companies that serve its models providers, such as a model's maker, Amazon Bedrock or
/// Together, and routes each request to one of them. This type, ``OpenRouterRouting``'s settings,
/// ``OpenRouterError/providerName`` and ``OpenRouterMetadataKey/provider`` keep OpenRouter's word, and their
/// documentation calls them hosts. Elsewhere in this package, as in `ProviderVocabulary`, a provider is the API a
/// request goes to, which here is OpenRouter itself.
public struct OpenRouterProviderName: ProviderVocabulary {
    /// The host's name or slug.
    public let rawValue: String

    /// Creates a host name.
    ///
    /// - Parameter rawValue: The name or slug, such as `"Anthropic"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
