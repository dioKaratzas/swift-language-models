/// A word from a provider's API, such as a model id or a parameter name, in a type of its own.
///
/// Giving each kind of word its own type means one kind can't be passed where another belongs, while any word the
/// provider uses stays valid. A string literal creates a value directly, and a value encodes as its raw string.
public protocol ProviderVocabulary: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible
where RawValue == String {
    /// Creates a value from the provider's spelling of it.
    init(rawValue: String)
}

extension ProviderVocabulary {
    /// Creates a value from a string literal.
    ///
    /// - Parameter value: The provider's spelling of the value.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The provider's spelling of the value, so printing it shows the word itself.
    public var description: String { rawValue }
}
