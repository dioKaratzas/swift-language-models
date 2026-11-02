package import UniformTypeIdentifiers

/// The kind of an attachment that a dialect's ``ChatCompletionsDialect/check(_:in:)`` checks its models take.
package enum AttachmentKind: Sendable, Equatable {
    /// An image attachment.
    case image

    /// A data attachment of a content type, such as a PDF or audio.
    case data(UTType)
}
