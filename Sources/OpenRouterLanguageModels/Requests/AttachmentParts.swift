import Foundation
import FoundationModels
import ImageIO
import LanguageModels
import UniformTypeIdentifiers

/// Prompt and tool-output attachments as OpenRouter's content parts.
///
/// A label goes first, as a text part of its own, so the model can name the attachment, as an `ImageReference` does.
/// Images go as JPEG data URLs in `image_url` parts, or as their web address when they have one. Data attachments go
/// by kind: text as text, images as images, PDFs as `file` parts, audio as `input_audio` with its format, and video as
/// `video_url` data URLs. The same attachment gives the same bytes every time.
struct AttachmentParts {
    /// The longest side, in pixels, of an image sent as data. A larger image is scaled down to it.
    ///
    /// It's the largest image that OpenAI's models see in full detail, and close to what other providers keep: an
    /// image well above it would only cost upload time before the provider scaled it down.
    static let maximumImageSide = 2_048

    /// The input kinds that every model a request may reach takes as attachments.
    let inputs: Set<OpenRouterInputModality>

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
            part = try imagePart(image, in: entry)
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

    /// An image attachment as an `image_url` part: its web address, or its pixels upright as a JPEG data URL.
    ///
    /// A file is read here rather than through the attachment's pixels, which a missing file has none of.
    private func imagePart(_ image: Transcript.ImageAttachment, in entry: Transcript.Entry) throws -> JSONValue {
        guard inputs.contains(.image) else {
            let description = "The model or one of its fallbacks doesn't take images."
            throw LanguageModelError.unsupportedCapability(.init(capability: .vision, debugDescription: description))
        }
        switch image.url {
        case let url? where url.isFileURL:
            return try Self.jpegPart(
                EncodedImage(contentsOf: url, orientation: image.orientation, maximumSide: Self.maximumImageSide), in: entry)
        case let url?:
            guard ["http", "https"].contains(url.scheme?.lowercased()) else {
                throw LanguageModelError.unsupported(entry, "OpenRouter takes images only at http and https addresses.")
            }
            guard image.orientation == .up else {
                throw LanguageModelError.unsupported(
                    entry, "OpenRouter can't turn an image at a web address upright; attach the image itself instead.")
            }
            return .imagePart(url.absoluteString)
        case nil:
            return try Self.jpegPart(
                EncodedImage(image.cgImage, orientation: image.orientation, maximumSide: Self.maximumImageSide), in: entry)
        }
    }

    #if canImport(FoundationModels, _version: 2.1.14)
    /// A data attachment as the part for its kind.
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
        let data = attachment.content
        switch input {
        case .text:
            guard let text = String(data: data, encoding: type.conforms(to: .utf16PlainText) ? .utf16 : .utf8) else {
                throw LanguageModelError.unsupported(entry, "The text attachment isn't valid \(type.identifier).")
            }
            return .textPart(text)
        case .image:
            return try Self.jpegPart(EncodedImage(data: data, maximumSide: Self.maximumImageSide), in: entry)
        case .file:
            let name = label ?? "document"
            let fileName = name.lowercased().hasSuffix(".pdf") ? name : "\(name).pdf"
            let fileData = DataURL(mediaType: "application/pdf", data: data).text
            return ["type": "file", "file": ["filename": .string(fileName), "file_data": .string(fileData)]]
        case .audio:
            guard let format = MediaFormat.audioFormat(of: type) else { break }
            return ["type": "input_audio", "input_audio": ["data": .string(data.base64EncodedString()), "format": .string(format)]]
        case .video:
            guard let mediaType = MediaFormat.videoMediaType(of: type) else { break }
            return ["type": "video_url", "video_url": ["url": .string(DataURL(mediaType: mediaType, data: data).text)]]
        default:
            break
        }
        throw LanguageModelError.unsupported(entry, "OpenRouter takes no attachments of type \(type.identifier).")
    }
    #endif

    /// An encoded image as an `image_url` part with a JPEG data URL.
    ///
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` when the image couldn't be read or encoded.
    private static func jpegPart(_ image: EncodedImage?, in entry: Transcript.Entry) throws -> JSONValue {
        guard let image else { throw LanguageModelError.unsupported(entry, "The image couldn't be read or encoded as JPEG.") }
        return .imagePart(DataURL(mediaType: "image/jpeg", data: image.data).text)
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

extension LanguageModelError {
    /// The error for transcript content OpenRouter can't take.
    static func unsupported(_ entry: Transcript.Entry, _ description: String) -> LanguageModelError {
        .unsupportedTranscriptContent(.init(unsupportedContent: [entry], debugDescription: description))
    }
}
