public import LanguageModels

/// A kind of input or output an OpenRouter model handles, such as `text` or `image`.
///
/// Modalities are an open vocabulary: any kind OpenRouter lists is a valid modality, with or without a static member.
public struct OpenRouterModality: ProviderVocabulary {
    /// Sound.
    public static let audio: Self = "audio"
    /// Documents such as PDF files.
    public static let file: Self = "file"
    /// Pictures.
    public static let image: Self = "image"
    /// Text.
    public static let text: Self = "text"
    /// Video.
    public static let video: Self = "video"

    /// The modality's name in OpenRouter's API.
    public let rawValue: String

    /// Creates a modality from its name in OpenRouter's API.
    ///
    /// - Parameter rawValue: The name, such as `"image"`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
