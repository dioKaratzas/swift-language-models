public import LanguageModels
public import UniformTypeIdentifiers

/// A kind of input an OpenRouter model accepts, such as `text` or `image`.
///
/// Input kinds are an open vocabulary: any kind OpenRouter lists is valid, with or without a static member.
public struct OpenRouterInputModality: ProviderVocabulary {
    /// The kind's name in OpenRouter's API.
    public let rawValue: String

    /// Creates an input kind from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"image"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The kind of prompt attachment that carries this input, or `nil` for a kind with no attachment form.
    ///
    /// Text is plain text, a file is a PDF document, and video is a movie, with or without sound.
    public var contentType: UTType? {
        switch self {
        case .text: .plainText
        case .image: .image
        case .file: .pdf
        case .audio: .audio
        case .video: .movie
        default: nil
        }
    }
}
