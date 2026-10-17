public import LanguageModels

/// An OpenRouter model id, such as `typesafe/jev-router`.
///
/// A distinct type, so text that isn't an OpenRouter id, such as a display name or another provider's id, can't be
/// passed by mistake.
public struct OpenRouterModelID: ProviderVocabulary {
    /// The id as OpenRouter's API spells it.
    public let rawValue: String

    /// Creates an id from OpenRouter's spelling of it.
    ///
    /// - Parameter rawValue: The id, such as `"typesafe/jev-router"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
