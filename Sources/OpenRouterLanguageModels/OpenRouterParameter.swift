public import LanguageModels

/// A request parameter that an OpenRouter model accepts, such as `tools` or `temperature`.
///
/// Parameters are an open vocabulary: any name OpenRouter lists is a valid parameter, with or without a static member.
public struct OpenRouterParameter: ProviderVocabulary {
    /// The parameter's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a parameter from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"top_p"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a parameter from a string literal of its name in OpenRouter's API.
    ///
    /// - Parameter value: The name, such as `"top_p"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }
}
