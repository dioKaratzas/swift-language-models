public import LanguageModels

/// How OpenRouter ranks a model's hosts.
public struct OpenRouterProviderSort: ProviderVocabulary {
    /// The lowest price first.
    public static let price: Self = "price"

    /// The highest throughput first.
    public static let throughput: Self = "throughput"

    /// The lowest latency first.
    public static let latency: Self = "latency"

    /// The hosts whose tool calls OpenRouter measures as most accurate first.
    public static let exacto: Self = "exacto"

    /// The ranking's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a ranking from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"price"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a ranking from a string literal of its name in OpenRouter's API.
    ///
    /// - Parameter value: The name, such as `"price"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }
}
