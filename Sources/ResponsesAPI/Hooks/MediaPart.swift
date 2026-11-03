package import UniformTypeIdentifiers

/// A kind of data a provider takes beyond the format's, and the input part it goes in.
package struct MediaPart: Sendable {
    /// The kind of data, which the attachment's content type conforms to.
    let contentType: UTType

    /// The media type of the data URL the data goes in.
    let mediaType: String

    /// Data of a kind, sent as an `input_file` with a data URL of the media type, as the format sends a PDF.
    package static func file(_ contentType: UTType, mediaType: String) -> Self {
        Self(contentType: contentType, mediaType: mediaType)
    }
}
