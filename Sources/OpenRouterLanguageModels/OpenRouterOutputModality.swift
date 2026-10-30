public import LanguageModels
public import UniformTypeIdentifiers

/// A kind of output an OpenRouter model generates, such as `text` or `image`.
///
/// Output kinds are an open vocabulary: any kind OpenRouter lists is valid, with or without a static member.
public struct OpenRouterOutputModality: ProviderVocabulary {
    /// The kind's name in OpenRouter's API.
    public let rawValue: String

    /// Creates an output kind from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"image"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The kind of data entry an answer carries for this output besides its text, or `nil` for text itself and for
    /// kinds that don't become data entries.
    ///
    /// Only images do. Audio needs a voice and a format that no Foundation Models option chooses, and the other kinds,
    /// such as embeddings, come from other OpenRouter APIs.
    public var contentType: UTType? {
        self == .image ? .image : nil
    }
}
