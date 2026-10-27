import UniformTypeIdentifiers

/// An audio or video format OpenRouter takes: the kind of data that carries it, and OpenRouter's name for it.
struct MediaFormat {
    /// The kinds of audio OpenRouter takes, each with its `input_audio` format.
    static let audio =
        [MediaFormat(.wav, "wav"), MediaFormat(.mp3, "mp3"), MediaFormat(.aiff, "aiff"), MediaFormat(.mpeg4Audio, "m4a")]
        + known(["public.aac-audio": "aac", "org.xiph.flac": "flac", "org.xiph.ogg-audio": "ogg"])

    /// The kinds of movie OpenRouter takes, each with the media type of its `video_url` data URL, as OpenRouter names
    /// them.
    static let video =
        [MediaFormat(.mpeg4Movie, "video/mp4"), MediaFormat(.mpeg, "video/mpeg"), MediaFormat(.quickTimeMovie, "video/mov")]
        + known(["org.webmproject.webm": "video/webm"])

    let contentType: UTType

    /// OpenRouter's name for the format.
    let name: String

    private init(_ contentType: UTType, _ name: String) {
        self.contentType = contentType
        self.name = name
    }

    /// The `input_audio` format of a kind of audio, or `nil` for one OpenRouter doesn't take.
    static func audioFormat(of type: UTType) -> String? {
        audio.first { type.conforms(to: $0.contentType) }?.name
    }

    /// The media type of a kind of movie in a `video_url`, or `nil` for one OpenRouter doesn't take.
    static func videoMediaType(of type: UTType) -> String? {
        video.first { type.conforms(to: $0.contentType) }?.name
    }

    /// The formats of the kinds of data the system knows by these identifiers, each with OpenRouter's name for it.
    private static func known(_ formats: KeyValuePairs<String, String>) -> [MediaFormat] {
        formats.compactMap { identifier, name in UTType(identifier).map { MediaFormat($0, name) } }
    }
}
