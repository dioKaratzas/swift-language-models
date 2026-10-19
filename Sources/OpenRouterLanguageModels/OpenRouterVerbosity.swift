public import LanguageModels

/// How long and detailed a model's answers are, from `low` to `max`.
///
/// Lower levels give shorter answers, and higher levels fuller ones. For Anthropic models, OpenRouter sends the level
/// as the model's effort setting.
public struct OpenRouterVerbosity: ProviderVocabulary {
    /// Short, concise answers.
    public static let low: Self = "low"

    /// Answers of the usual length, the model's default.
    public static let medium: Self = "medium"

    /// Longer, more detailed answers.
    public static let high: Self = "high"

    /// More detail than `high`, for models that take it, such as Claude Opus 4.7 and later.
    public static let xhigh: Self = "xhigh"

    /// The most detail, for models that take it, such as Claude Opus 4.6 and later.
    public static let max: Self = "max"

    /// The level's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a level from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"low"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
