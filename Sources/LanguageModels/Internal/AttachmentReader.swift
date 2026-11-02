package import Foundation
package import FoundationModels
import ImageIO
package import UniformTypeIdentifiers

/// Reads a transcript's attachments into what a provider sends: images upright as JPEG, or at their web address, text
/// as text, PDFs with a file name, and any other kind as its data. The same attachment gives the same bytes every time.
package struct AttachmentReader {
    /// What an attachment holds, ready for a provider's content part.
    package enum Content: Equatable {
        /// An image's pixels, upright and scaled down to the reader's longest side, as JPEG.
        case jpeg(Data)
        /// An image at an http or https address, already upright.
        case imageURL(URL)
        case text(String)
        /// A PDF document, with a file name that ends in `.pdf`.
        case pdf(Data, fileName: String)
        /// Data of another kind, such as audio or video.
        case data(Data, type: UTType)
    }

    /// The longest side, in pixels, of an image sent as data. A larger image is scaled down to it.
    package let maximumImageSide: Int

    /// The provider's name, for the errors.
    private let provider: String

    /// - Parameters:
    ///   - provider: The provider's name, as the errors name it.
    ///   - maximumImageSide: The longest side, in pixels, of an image sent as data. 2,048 is the largest image that
    ///     OpenAI's models see in full detail, and close to what other providers keep.
    package init(provider: String, maximumImageSide: Int = 2_048) {
        self.provider = provider
        self.maximumImageSide = maximumImageSide
    }

    /// An image attachment's content: its web address, or its pixels upright as JPEG.
    ///
    /// A file is read here rather than through the attachment's pixels, which a missing file has none of.
    ///
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` for an image that can't be read, or at an address
    ///   that isn't http or https, or that isn't upright.
    package func content(of image: Transcript.ImageAttachment, in entry: Transcript.Entry) throws -> Content {
        switch image.url {
        case let url? where url.isFileURL:
            return try jpeg(EncodedImage(contentsOf: url, orientation: image.orientation, maximumSide: maximumImageSide), in: entry)
        case let url?:
            guard ["http", "https"].contains(url.scheme?.lowercased()) else {
                throw LanguageModelError.unsupported(entry, "\(provider) takes images only at http and https addresses.")
            }
            guard image.orientation == .up else {
                throw LanguageModelError.unsupported(
                    entry, "\(provider) can't turn an image at a web address upright; attach the image itself instead.")
            }
            return .imageURL(url)
        case nil:
            return try jpeg(EncodedImage(image.cgImage, orientation: image.orientation, maximumSide: maximumImageSide), in: entry)
        }
    }

    /// A data attachment's content: text decoded, an image as JPEG, a PDF named by its label, and any other kind as its
    /// data.
    ///
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` for text or an image that can't be read.
    package func content(of data: Data, type: UTType, label: String?, in entry: Transcript.Entry) throws -> Content {
        if type.conforms(to: .plainText) {
            guard let text = String(data: data, encoding: Self.textEncoding(of: data, type: type)) else {
                throw LanguageModelError.unsupported(entry, "The text attachment isn't valid \(type.identifier).")
            }
            return .text(text)
        }
        if EncodedImage.readableTypes.contains(where: { type.conforms(to: $0) }) {
            return try jpeg(EncodedImage(data: data, maximumSide: maximumImageSide), in: entry)
        }
        if type.conforms(to: .pdf) {
            let name = label ?? "document"
            return .pdf(data, fileName: name.lowercased().hasSuffix(".pdf") ? name : "\(name).pdf")
        }
        return .data(data, type: type)
    }

    /// The encoding of a text attachment: UTF-16 for the UTF-16 kinds, in the byte order its byte-order mark names, or
    /// without one, native order for the plain kind and big-endian for the external kind; UTF-8 for every other kind.
    private static func textEncoding(of data: Data, type: UTType) -> String.Encoding {
        let hasByteOrderMark = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
        if type.conforms(to: .utf16ExternalPlainText) { return .utf16 }
        if type.conforms(to: .utf16PlainText) { return hasByteOrderMark ? .utf16 : .utf16LittleEndian }
        return .utf8
    }

    /// An encoded image's JPEG content.
    ///
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` when the image couldn't be read or encoded.
    private func jpeg(_ image: EncodedImage?, in entry: Transcript.Entry) throws -> Content {
        guard let image else { throw LanguageModelError.unsupported(entry, "The image couldn't be read or encoded as JPEG.") }
        return .jpeg(image.data)
    }
}
