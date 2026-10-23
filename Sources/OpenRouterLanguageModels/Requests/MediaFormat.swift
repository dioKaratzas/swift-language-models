import UniformTypeIdentifiers

/// The audio and video formats OpenRouter takes, each with the kind of data that carries it.
enum MediaFormat {
    /// The `input_audio` format of each kind of audio OpenRouter takes.
    static let audio: [(type: UTType, format: String)] =
        [(.wav, "wav"), (.mp3, "mp3"), (.aiff, "aiff"), (.mpeg4Audio, "m4a")]
        + known([("public.aac-audio", "aac"), ("org.xiph.flac", "flac"), ("org.xiph.ogg-audio", "ogg")])

    /// The media type in a `video_url` data URL for each kind of movie OpenRouter takes, as OpenRouter names them.
    static let video: [(type: UTType, mediaType: String)] =
        [(.mpeg4Movie, "video/mp4"), (.mpeg, "video/mpeg"), (.quickTimeMovie, "video/mov")]
        + known([("org.webmproject.webm", "video/webm")])

    /// The `input_audio` format of a kind of audio, or `nil` for one OpenRouter doesn't take.
    static func audioFormat(of type: UTType) -> String? {
        audio.first { type.conforms(to: $0.type) }?.format
    }

    /// The media type of a kind of movie in a `video_url`, or `nil` for one OpenRouter doesn't take.
    static func videoMediaType(of type: UTType) -> String? {
        video.first { type.conforms(to: $0.type) }?.mediaType
    }

    /// The kinds of data the system knows by these identifiers, each with its word.
    private static func known(_ identifiers: [(String, String)]) -> [(UTType, String)] {
        identifiers.compactMap { identifier, word in UTType(identifier).map { ($0, word) } }
    }
}
