import APIFormat
import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

extension ResponsesRequest {
    /// Prompt and tool-output attachments as the format's input parts.
    ///
    /// A label goes first, as a text part of its own, so the model can name the attachment, as an `ImageReference`
    /// does. Images go as JPEG data URLs in `input_image` parts, or as their web address when they have one. Data
    /// attachments go by kind: text as text, images as images, PDFs as `input_file` parts, and the kinds the dialect
    /// adds as files of their media type. The format has no part for audio or video. The dialect first checks that its
    /// models take the attachment. The same attachment gives the same bytes every time.
    struct AttachmentParts {
        /// The provider's name, for the errors.
        private let provider: String

        private let reader: AttachmentReader

        /// Checks that every model takes an attachment.
        private let check: (AttachmentKind, Transcript.Entry) throws(LanguageModelError) -> Void

        /// The kinds of data the dialect adds as files, in the order they're matched.
        private let media: [MediaPart]

        init<Dialect: ResponsesDialect>(dialect: Dialect) {
            provider = Dialect.name
            reader = AttachmentReader(provider: provider)
            check = { (attachment, entry) throws(LanguageModelError) in try dialect.check(attachment, in: entry) }
            media = Dialect.extraMedia
        }

        /// The parts for one attachment: its label, when it has one, then the attachment.
        ///
        /// - Throws: The dialect's errors for an attachment a model doesn't take, and
        ///   `LanguageModelError.unsupportedTranscriptContent` for one that can't be read or that neither the format
        ///   nor the dialect has a part for.
        func parts(for segment: Transcript.AttachmentSegment, in entry: Transcript.Entry) throws -> [Part] {
            let content = try reader.content(of: segment, in: entry) { (kind) throws(LanguageModelError) in try check(kind, entry) }
            let label = segment.givenLabel
            return (label.map { [.text($0)] } ?? []) + [try part(for: content, label: label, in: entry)]
        }

        /// The input part for an attachment's content: text, an `input_image`, a PDF `input_file`, or a file of the
        /// first kind the dialect adds that it conforms to.
        private func part(for content: AttachmentReader.Content, label: String?, in entry: Transcript.Entry) throws -> Part {
            switch content {
            case .text(let text):
                return .text(text)
            case .jpeg(let data):
                return .image(url: DataURL(mediaType: MediaType.jpeg, data: data).text)
            case .imageURL(let url):
                return .image(url: url.absoluteString)
            case .pdf(let data, let fileName):
                return .file(name: fileName, data: DataURL(mediaType: MediaType.pdf, data: data).text)
            case .data(let data, let type):
                guard let file = media.first(where: { type.conforms(to: $0.contentType) }) else {
                    throw LanguageModelError.unsupported(entry, "\(provider) takes no attachments of type \(type.identifier).")
                }
                return .file(name: Self.fileName(label, type: type), data: DataURL(mediaType: file.mediaType, data: data).text)
            }
        }

        /// A file's name: its label, with the extension of its kind when the label has none, or `file` with it.
        private static func fileName(_ label: String?, type: UTType) -> String {
            let name = label ?? "file"
            guard let ext = type.preferredFilenameExtension, !name.lowercased().hasSuffix(".\(ext)") else { return name }
            return "\(name).\(ext)"
        }
    }
}
