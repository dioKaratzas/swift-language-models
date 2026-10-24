public import LanguageModels

/// A processing tier, which trades speed against price.
public struct OpenRouterServiceTier: ProviderVocabulary {
    /// The host's choice.
    public static let auto: Self = "auto"

    /// The standard tier.
    public static let `default`: Self = "default"

    /// Slower and cheaper processing.
    public static let flex: Self = "flex"

    /// Faster processing at a higher price. OpenRouter also accepts `fast` for it.
    public static let priority: Self = "priority"

    /// Reserved capacity, for accounts that bought it.
    public static let scale: Self = "scale"

    /// The fastest hosts, then `priority`, then the standard tier.
    public static let ultrafast: Self = "ultrafast"

    /// The tier's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a tier from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"flex"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a tier from a string literal of its name in OpenRouter's API.
    ///
    /// - Parameter value: The name, such as `"flex"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }
}
