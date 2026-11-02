import UniformTypeIdentifiers

extension ChatCompletionRequest {
    /// An audio format that `input_audio` takes: the kind of data that carries it, and the format's name for it.
    struct MediaFormat {
        /// The kinds of audio `input_audio` takes, WAV and MP3, each with its name.
        static let audio = [MediaFormat(.wav, "wav"), MediaFormat(.mp3, "mp3")]

        let contentType: UTType

        /// The format's name for the kind.
        let name: String

        init(_ contentType: UTType, _ name: String) {
            self.contentType = contentType
            self.name = name
        }

        /// The name of the first of the formats that a kind of data conforms to, or `nil` when it conforms to none.
        static func name(of type: UTType, in formats: [MediaFormat]) -> String? {
            formats.first { type.conforms(to: $0.contentType) }?.name
        }
    }
}
