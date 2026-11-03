package import UniformTypeIdentifiers

/// The kind of an attachment that the `check(_:in:)` hook of each API format's dialect checks its models take.
package enum AttachmentKind: Sendable, Equatable {
    /// An image attachment.
    case image

    /// A data attachment of a content type, such as a PDF or audio.
    case data(UTType)
}
