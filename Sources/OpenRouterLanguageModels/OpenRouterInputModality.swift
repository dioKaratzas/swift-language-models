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

    /// Creates an input kind from a string literal of its name in OpenRouter's API.
    ///
    /// - Parameter value: The name, such as `"image"`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    /// The raw value, so printing a value shows OpenRouter's spelling of it.
    public var description: String { rawValue }

    /// The kinds of prompt attachment that carry this input, or none for a kind with no attachment form.
    ///
    /// Text is plain text, sent as text. An image is any kind ImageIO reads, such as PNG, JPEG or HEIC, sent as JPEG. A
    /// file is a PDF document. Audio is WAV, MP3, AIFF, AAC, FLAC, Ogg or MPEG-4 audio, and video is MPEG-4, MPEG,
    /// QuickTime or WebM movies. A kind that conforms to one of these, such as UTF-8 text to plain text, is carried too.
    public var contentTypes: Set<UTType> {
        switch self {
        case .text: [.plainText]
        case .image: EncodedImage.readableTypes
        case .file: [.pdf]
        case .audio: Set(MediaFormat.audio.map(\.type))
        case .video: Set(MediaFormat.video.map(\.type))
        default: []
        }
    }

    /// The input kind whose attachments carry data of a kind, or `nil` when none does.
    ///
    /// - Parameter type: The kind of data, such as `UTType.mp3`.
    init?(carrying type: UTType) {
        let input = [Self.text, .image, .file, .audio, .video].first { input in
            input.contentTypes.contains { type.conforms(to: $0) }
        }
        guard let input else { return nil }
        self = input
    }
}
