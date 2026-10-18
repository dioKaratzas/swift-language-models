public import LanguageModels

/// A host that serves models on OpenRouter, by name or slug, such as `Anthropic` or `amazon-bedrock`.
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
