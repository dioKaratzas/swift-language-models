public import LanguageModels

/// A processing tier, which trades speed against price.
///
/// The answer's metadata names the tier that served it, under `LanguageModelMetadataKey.serviceTier`, which can differ
/// from the one asked for.
public struct OpenAIServiceTier: ProviderVocabulary {
    /// The tier the project's settings choose, which is `default` unless the project set another.
    public static let auto: Self = "auto"

    /// The standard tier, at the standard price.
    public static let `default`: Self = "default"

    /// Slower and cheaper processing.
    public static let flex: Self = "flex"

    /// Faster processing at a higher price.
    public static let priority: Self = "priority"

    /// Reserved capacity, for projects that bought it.
    public static let scale: Self = "scale"

    /// Faster processing, which the answer reports as `priority`.
    public static let fast: Self = "fast"

    /// The fastest processing.
    public static let ultrafast: Self = "ultrafast"

    /// The tier's name in OpenAI's API.
    public let rawValue: String

    /// Creates a tier from its name in OpenAI's API.
    ///
    /// - Parameter rawValue: The name, such as `"flex"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
