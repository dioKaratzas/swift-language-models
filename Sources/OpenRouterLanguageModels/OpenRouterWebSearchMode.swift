public import LanguageModels

/// How deep a web search engine searches, trading speed against thoroughness and price.
///
/// Each engine takes its own modes and ignores the others: Exa takes `instant`, `fast`, `auto`, its default,
/// `deep-lite`, `deep` and `deep-reasoning`, and Parallel takes `turbo`, `fast`, `basic`, its default, and `advanced`.
/// Deeper modes take longer and cost more per search.
///
/// Modes are an open vocabulary: any mode OpenRouter lists is valid, with or without a static member.
public struct OpenRouterWebSearchMode: ProviderVocabulary {
    /// The mode's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a mode from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"fast"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a mode from a string literal of its name in OpenRouter's API.
    ///
    /// - Parameter value: The name, such as `"fast"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }
}
