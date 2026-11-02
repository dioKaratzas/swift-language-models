import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

extension ChatCompletionRequest {
    /// Prompt and tool-output attachments as the format's content parts.
    ///
    /// A label goes first, as a text part of its own, so the model can name the attachment, as an `ImageReference`
    /// does. Images go as JPEG data URLs in `image_url` parts, or as their web address when they have one. Data
    /// attachments go by kind: text as text, images as images, PDFs as `file` parts, WAV and MP3 audio as
    /// `input_audio` with its format, and any other kind as the provider's part for it. The provider first checks that
    /// its models take the attachment. The same attachment gives the same bytes every time.
    struct AttachmentParts {
        /// The provider's name, for the errors.
        private let provider: String

        private let reader: AttachmentReader

        /// Checks that every model takes an attachment.
        private let check: (Transcript.AttachmentSegment, Transcript.Entry) throws -> Void

        /// The provider's part for data of a kind the format has no part for.
        private let part: (Data, UTType, Transcript.Entry) -> JSONValue?

        init(
            provider: String,
            check: @escaping (Transcript.AttachmentSegment, Transcript.Entry) throws -> Void,
            part: @escaping (Data, UTType, Transcript.Entry) -> JSONValue?
        ) {
            self.provider = provider
            reader = AttachmentReader(provider: provider)
            self.check = check
            self.part = part
        }

        /// The parts for one attachment: its label, when it has one, then the attachment.
        ///
        /// - Throws: The provider's errors for an attachment a model doesn't take, and
        ///   `LanguageModelError.unsupportedTranscriptContent` for one that can't be read or that neither the format
        ///   nor the provider has a part for.
        func parts(for segment: Transcript.AttachmentSegment, in entry: Transcript.Entry) throws -> [JSONValue] {
            try check(segment, entry)
            let label = segment.label.flatMap { $0.isEmpty ? nil : $0 }
            let part: JSONValue
            switch segment.content {
            case .image(let image):
                part = try self.part(for: reader.content(of: image, in: entry), in: entry)
            default:
                #if canImport(FoundationModels, _version: 2.1.14)
                if #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *), case .data(let attachment) = segment.content {
                    let content = try reader.content(of: attachment.content, type: attachment.contentType, label: label, in: entry)
                    part = try self.part(for: content, in: entry)
                    break
                }
                #endif
                throw LanguageModelError.unsupported(entry, "\(provider) can't take this kind of attachment.")
            }
            return (label.map { [.textPart($0)] } ?? []) + [part]
        }

        /// The content part for an attachment's content: text, an `image_url`, a PDF `file`, `input_audio` with its
        /// format, or the provider's part for any other kind.
        private func part(for content: AttachmentReader.Content, in entry: Transcript.Entry) throws -> JSONValue {
            switch content {
            case .text(let text):
                return .textPart(text)
            case .jpeg(let data):
                return .imagePart(DataURL(mediaType: MediaType.jpeg, data: data).text)
            case .imageURL(let url):
                return .imagePart(url.absoluteString)
            case .pdf(let data, let fileName):
                let fileData = DataURL(mediaType: MediaType.pdf, data: data).text
                return [
                    "type": PartType.file.json,
                    "file": ["filename": .string(fileName), "file_data": .string(fileData)],
                ]
            case .data(let data, let type):
                if let format = MediaFormat.name(of: type, in: MediaFormat.audio) {
                    return .audioPart(data, format: format)
                }
                if let part = part(data, type, entry) { return part }
                throw LanguageModelError.unsupported(entry, "\(provider) takes no attachments of type \(type.identifier).")
            }
        }
    }
}

extension JSONValue {
    /// A text part of a message's content.
    static func textPart(_ text: String) -> JSONValue {
        ["type": ChatCompletionRequest.PartType.text.json, "text": .string(text)]
    }

    /// An image part of a message's content, at a web address or in a data URL.
    fileprivate static func imagePart(_ url: String) -> JSONValue {
        ["type": ChatCompletionRequest.PartType.image.json, "image_url": ["url": .string(url)]]
    }

    /// An `input_audio` part of a message's content: the audio as Base64, and its format's name.
    fileprivate static func audioPart(_ data: Data, format: String) -> JSONValue {
        [
            "type": ChatCompletionRequest.PartType.audio.json,
            "input_audio": ["data": .string(data.base64EncodedString()), "format": .string(format)],
        ]
    }
}

extension ChatCompletionRequest {
    /// The `type` of a message's content part.
    struct PartType: ProviderVocabulary {
        static let text: Self = "text"
        static let image: Self = "image_url"
        static let file: Self = "file"
        static let audio: Self = "input_audio"

        let rawValue: String
    }
}

extension JSONValue {
    /// The `type` of a content part, or `nil` when the value isn't one.
    var partType: ChatCompletionRequest.PartType? {
        self["type"]?.stringValue.map(ChatCompletionRequest.PartType.init(rawValue:))
    }
}
