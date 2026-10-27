public import LanguageModels

/// An OpenRouter model id, such as `typesafe/jev-router`.
///
/// A distinct type, so text that isn't an OpenRouter id, such as a display name or another provider's id, can't be
/// passed by mistake.
///
/// To make ids from strings, name the initializer in full, since a bare `OpenRouterModelID.init` could also mean the
/// string-literal one:
///
/// ```swift
/// let ids = savedIDs.map(OpenRouterModelID.init(rawValue:))
/// ```
public struct OpenRouterModelID: ProviderVocabulary {
    /// The id as OpenRouter's API spells it.
    public let rawValue: String

    /// Creates an id from OpenRouter's spelling of it.
    ///
    /// - Parameter rawValue: The id, such as `"typesafe/jev-router"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an id from a string literal of OpenRouter's spelling of it.
    ///
    /// - Parameter value: The id, such as `"typesafe/jev-router"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }
}
