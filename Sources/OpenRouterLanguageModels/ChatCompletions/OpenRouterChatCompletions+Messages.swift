import ChatCompletionsAPI
import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

extension OpenRouterChatCompletions {
    /// The input kinds that every model a request may reach takes as attachments, with the model's PDF engine.
    private var attachmentInputs: Set<OpenRouterInputModality> {
        details.attachmentInputs(pdfEngine: model.options.pdfEngine)
    }

    /// Checks that every model takes an attachment, as Foundation Models does before a request.
    ///
    /// - Throws: `LanguageModelError.unsupportedCapability` with `.vision` for an image attachment when a model doesn't
    ///   take images, and `LanguageModelError.unsupportedTranscriptContent` for a data attachment a model doesn't take,
    ///   images included, as `supportsDataAttachmentType` refuses it.
    func check(_ attachment: Transcript.AttachmentSegment, in entry: Transcript.Entry) throws {
        switch attachment.content {
        case .image:
            guard attachmentInputs.contains(.image) else {
                throw LanguageModelError.unsupported(.vision, "The model or one of its fallbacks doesn't take images.")
            }
        default:
            #if canImport(FoundationModels, _version: 2.1.14)
            if #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *), case .data(let data) = attachment.content {
                let type = data.contentType
                guard let input = OpenRouterInputModality(carrying: type) else {
                    throw LanguageModelError.unsupported(entry, "OpenRouter takes no attachments of type \(type.identifier).")
                }
                guard attachmentInputs.contains(input) else {
                    throw LanguageModelError.unsupported(
                        entry, "The model or one of its fallbacks doesn't take \(input) attachments, such as \(type.identifier).")
                }
            }
            #endif
        }
    }

    /// Audio in a format only OpenRouter takes, as `input_audio` with its format, or a movie, as a `video_url` data URL.
    func contentPart(for data: Data, type: UTType, in entry: Transcript.Entry) -> JSONValue? {
        if let format = Self.name(of: type, in: OpenRouterInputModality.audioTypes, named: Self.audioNames) {
            return ["type": "input_audio", "input_audio": ["data": .string(data.base64EncodedString()), "format": .string(format)]]
        }
        if let mediaType = Self.name(of: type, in: OpenRouterInputModality.videoTypes, named: Self.videoNames) {
            return ["type": "video_url", "video_url": ["url": .string(DataURL(mediaType: mediaType, data: data).text)]]
        }
        return nil
    }

    /// OpenRouter's `input_audio` format for each kind of audio it takes beyond WAV and MP3, which the format names.
    private static let audioNames: [UTType?: String] = [
        .aiff: "aiff", .mpeg4Audio: "m4a", OpenRouterInputModality.UnnamedType.aacAudio: "aac",
        OpenRouterInputModality.UnnamedType.flacAudio: "flac", OpenRouterInputModality.UnnamedType.oggAudio: "ogg",
    ]

    /// The media type OpenRouter names each kind of movie by in a `video_url` data URL.
    private static let videoNames: [UTType?: String] = [
        .mpeg4Movie: "video/mp4", .mpeg: "video/mpeg", .quickTimeMovie: "video/mov",
        OpenRouterInputModality.UnnamedType.webMMovie: "video/webm",
    ]

    /// The name of the first of OpenRouter's kinds that a kind of data conforms to and that has a name, in the kinds'
    /// order.
    private static func name(of type: UTType, in kinds: [UTType], named names: [UTType?: String]) -> String? {
        kinds.lazy.compactMap { kind in type.conforms(to: kind) ? names[kind] : nil }.first
    }

    /// The assistant message's `reasoning` and `reasoning_details` for the reasoning it sends back.
    ///
    /// The details go back as OpenRouter sent them, and the text of the reasoning that came with them, since text
    /// without them would reach the host unsigned. Reasoning that came as text alone goes back as text, as OpenRouter
    /// takes it from models that return only raw reasoning. A block the model wrote in its answer's text already goes
    /// back there, so its text isn't sent again. Some models send an empty list of details when they didn't reason,
    /// and expect it back.
    func assistantMembers(replaying reasoning: [Transcript.Reasoning]) -> JSONObject {
        var signedText = ""
        var plainText = ""
        var details: [JSONValue]?
        for entry in reasoning {
            let text = TaggedReasoning.block(of: entry) == nil ? entry.segments.compactMap(\.text).joined() : ""
            if let replayed = ReasoningDetails.replayed(from: entry) {
                details = (details ?? []) + replayed
                if !replayed.isEmpty { signedText += text }
            }
            if ReasoningDetails.isTextAlone(entry) { plainText += text }
        }
        let text = ((details ?? []).isEmpty ? "" : signedText) + plainText
        return [
            Member.reasoning: text.isEmpty ? nil : .string(text),
            Member.reasoningDetails: details.map(JSONValue.array),
        ]
    }
}
