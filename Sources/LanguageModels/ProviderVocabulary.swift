/// A word from a provider's API, such as a model id or a parameter name, in a type of its own.
///
/// Giving each kind of word its own type means one kind can't be passed where another belongs, while any word the
/// provider uses stays valid. A string literal creates a value directly, and a value encodes as its raw string.
///
/// Each conforming type declares `init(stringLiteral:)` and `description` itself, with `description` returning the raw
/// value. An extension in this module would provide them only to files that import it, so declaring them on the type
/// lets an app write a value as a string literal with only the provider's module imported.
public protocol ProviderVocabulary: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral,
    CustomStringConvertible
where RawValue == String {
    /// Creates a value from the provider's spelling of it.
    init(rawValue: String)
}
