import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

/// Prompt and tool-output attachments as OpenRouter's content parts.
///
/// A label goes first, as a text part of its own, so the model can name the attachment, as an `ImageReference` does.
/// Images go as JPEG data URLs in `image_url` parts, or as their web address when they have one. Data attachments go
/// by kind: text as text, images as images, PDFs as `file` parts, audio as `input_audio` with its format, and video as
/// `video_url` data URLs. The same attachment gives the same bytes every time.
struct AttachmentParts {
    /// The input kinds that every model a request may reach takes as attachments.
    let inputs: Set<OpenRouterInputModality>

    private let reader = AttachmentReader(provider: "OpenRouter")

    /// The parts for one attachment: its label, when it has one, then the attachment.
    ///
    /// - Throws: As Foundation Models does before a request, `LanguageModelError.unsupportedCapability` with `.vision`
    ///   for an image attachment when a model doesn't take images, and `LanguageModelError.unsupportedTranscriptContent`
    ///   for a data attachment a model doesn't take, images included. It also throws the latter for an attachment that
    ///   can't be read.
    func parts(for segment: Transcript.AttachmentSegment, in entry: Transcript.Entry) throws -> [JSONValue] {
        let label = segment.label.flatMap { $0.isEmpty ? nil : $0 }
        let part: JSONValue
        switch segment.content {
        case .image(let image):
            guard inputs.contains(.image) else {
                throw LanguageModelError.unsupported(.vision, "The model or one of its fallbacks doesn't take images.")
            }
            part = try Self.part(for: reader.content(of: image, in: entry), in: entry)
        default:
            #if canImport(FoundationModels, _version: 2.1.14)
            if #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *), case .data(let attachment) = segment.content {
                part = try dataPart(attachment, label: label, in: entry)
                break
            }
            #endif
            throw LanguageModelError.unsupported(entry, "OpenRouter can't take this kind of attachment.")
        }
        return (label.map { [.textPart($0)] } ?? []) + [part]
    }

    #if canImport(FoundationModels, _version: 2.1.14)
    /// A data attachment as the part for its kind, when every model takes that kind.
    @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
    private func dataPart(_ attachment: Transcript.DataAttachment, label: String?, in entry: Transcript.Entry) throws -> JSONValue {
        let type = attachment.contentType
        guard let input = OpenRouterInputModality(carrying: type) else {
            throw LanguageModelError.unsupported(entry, "OpenRouter takes no attachments of type \(type.identifier).")
        }
        // As Foundation Models refuses a data attachment that `supportsDataAttachmentType` doesn't take, an image too.
        guard inputs.contains(input) else {
            throw LanguageModelError.unsupported(
                entry, "The model or one of its fallbacks doesn't take \(input) attachments, such as \(type.identifier).")
        }
        return try Self.part(for: reader.content(of: attachment.content, type: type, label: label, in: entry), in: entry)
    }
    #endif

    /// The content part for an attachment's content: text, an `image_url`, a PDF `file`, `input_audio` with its format,
    /// or a `video_url` data URL.
    private static func part(for content: AttachmentReader.Content, in entry: Transcript.Entry) throws -> JSONValue {
        switch content {
        case .text(let text):
            return .textPart(text)
        case .jpeg(let data):
            return .imagePart(DataURL(mediaType: "image/jpeg", data: data).text)
        case .imageURL(let url):
            return .imagePart(url.absoluteString)
        case .pdf(let data, let fileName):
            let fileData = DataURL(mediaType: "application/pdf", data: data).text
            return ["type": "file", "file": ["filename": .string(fileName), "file_data": .string(fileData)]]
        case .data(let data, let type):
            if let format = MediaFormat.audioFormat(of: type) {
                return ["type": "input_audio", "input_audio": ["data": .string(data.base64EncodedString()), "format": .string(format)]]
            }
            if let mediaType = MediaFormat.videoMediaType(of: type) {
                return ["type": "video_url", "video_url": ["url": .string(DataURL(mediaType: mediaType, data: data).text)]]
            }
            throw LanguageModelError.unsupported(entry, "OpenRouter takes no attachments of type \(type.identifier).")
        }
    }
}

extension JSONValue {
    /// A text part of a message's content.
    static func textPart(_ text: String) -> JSONValue {
        ["type": "text", "text": .string(text)]
    }

    /// An image part of a message's content, at a web address or in a data URL.
    fileprivate static func imagePart(_ url: String) -> JSONValue {
        ["type": "image_url", "image_url": ["url": .string(url)]]
    }
}
