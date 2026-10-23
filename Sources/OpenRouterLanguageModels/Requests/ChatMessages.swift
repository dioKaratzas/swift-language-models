import Foundation
import FoundationModels
import LanguageModels

/// A transcript as OpenRouter's `messages`.
///
/// Instructions become `system` messages and prompts `user` messages. The reasoning, response text and tool calls
/// of one answer become one `assistant` message, and each tool output a `tool` message. Prompts and tool outputs carry
/// their attachments as content parts; generated data and an answer's attachments aren't sent back. Every entry turns
/// into the same JSON each time, so a provider's prompt cache stays valid from one request to the next.
struct ChatMessages {
    private(set) var messages: [JSONValue] = []

    /// Whether a message carries a PDF.
    private(set) var carriesPDF = false

    private let attachments: AttachmentParts
    private var turn = AssistantTurn()
    private var sentDetails: Set<Data> = []
    private var lastInstructionsIndex: Int?
    private var lastPrompt: (index: Int, hasSchema: Bool)?

    /// Whether reasoning that the named model wrote goes back.
    private let replaysReasoning: (_ writer: String?) -> Bool

    /// The text that asks for JSON matching a schema.
    private let schemaInstructions: (GenerationSchema) throws -> String

    /// The messages for a transcript.
    ///
    /// A prompt that recorded a response schema, which Foundation Models does when the schema belongs in the prompt,
    /// carries the schema as text after its own, so every request writes it the same way.
    ///
    /// - Parameters:
    ///   - transcript: The entries to send.
    ///   - cacheControl: When set, the last instructions carry a cache marker, so the tools and instructions before it
    ///     are cached on the host for the session's later requests, and for another session's that reach the same host.
    ///   - attachmentInputs: The input kinds that every model the request may reach takes as attachments.
    ///   - replaysReasoning: Whether reasoning goes back, given the model that wrote it as its answer named it, or `nil`
    ///     when that isn't known. Reasoning that doesn't go back is left out as if another provider wrote it.
    ///   - requiredSchema: A schema the last prompt must carry even if it didn't record it, because the model can't be
    ///     told the schema another way.
    ///   - schemaInstructions: The text that asks for JSON matching a schema.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` for content OpenRouter or a model can't take, and
    ///   `LanguageModelError.unsupportedCapability` for an image when a model doesn't take images.
    init(
        _ transcript: some Sequence<Transcript.Entry>,
        cacheControl: OpenRouterCacheControl?,
        attachmentInputs: Set<OpenRouterInputModality>,
        replaysReasoning: @escaping (_ writer: String?) -> Bool,
        requiredSchema: GenerationSchema?,
        schemaInstructions: @escaping (GenerationSchema) throws -> String
    ) throws {
        self.attachments = AttachmentParts(inputs: attachmentInputs)
        self.replaysReasoning = replaysReasoning
        self.schemaInstructions = schemaInstructions
        for entry in transcript { try append(entry) }
        endTurn()
        if let requiredSchema, let lastPrompt, !lastPrompt.hasSchema {
            let text = try schemaInstructions(requiredSchema)
            updateParts(ofMessageAt: lastPrompt.index) { $0.append(.textPart(text)) }
        }
        if let cacheControl, let index = lastInstructionsIndex {
            updateParts(ofMessageAt: index) { parts in
                guard case .object(var last)? = parts.last else { return }
                last["cache_control"] = cacheControl.json
                parts[parts.count - 1] = .object(last)
            }
        }
    }

    private mutating func append(_ entry: Transcript.Entry) throws {
        switch entry {
        case .instructions(let instructions):
            endTurn()
            // A session without instructions still has an empty instructions entry, which providers reject.
            let parts = try Self.textParts(instructions.segments, of: entry)
            guard !parts.isEmpty else { return }
            lastInstructionsIndex = messages.count
            messages.append(["role": "system", "content": Self.content(parts)])
        case .prompt(let prompt):
            endTurn()
            var parts = try parts(prompt.segments, of: entry)
            var hasSchema = false
            if case .schema(let schema)? = prompt.responseFormat?.kind {
                parts.append(.textPart(try schemaInstructions(schema)))
                hasSchema = true
            }
            guard !parts.isEmpty else { return }
            lastPrompt = (messages.count, hasSchema)
            messages.append(["role": "user", "content": Self.content(parts)])
        case .reasoning(let reasoning):
            guard let details = ReasoningDetails.replayed(from: reasoning), replaysReasoning(ReasoningDetails.writer(of: reasoning)) else {
                return
            }
            let unsent = details.filter { sentDetails.insert($0.data).inserted }
            turn.reasoningDetails += unsent
            turn.hasReasoningDetails = true
            if !unsent.isEmpty { turn.reasoningText += Self.texts(of: reasoning.segments).joined() }
        case .response(let response):
            // An answer's attachments aren't sent back, as OpenRouter's AI SDK provider leaves out an answer's files.
            turn.text += Self.texts(of: response.segments).joined()
        case .toolCalls(let toolCalls):
            turn.toolCalls += toolCalls.map { call in
                [
                    "id": .string(call.id),
                    "type": "function",
                    "function": [
                        "name": .string(call.toolName),
                        "arguments": .string(JSONValue(call.arguments).text),
                    ],
                ]
            }
        case .toolOutput(let output):
            endTurn()
            let parts = try parts(output.segments, of: entry)
            let texts = parts.compactMap { $0["type"] == "text" ? $0["text"]?.stringValue : nil }
            // Text alone goes as one string; attachments need the parts.
            let content: JSONValue = texts.count == parts.count ? .string(texts.joined()) : .array(parts)
            messages.append(["role": "tool", "tool_call_id": .string(output.id), "content": content])
        default:
            // Generated data, such as an image, stays in the transcript but isn't sent back, as OpenRouter's AI SDK
            // provider leaves out generated files, so it isn't billed again as input on every later request.
            if #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *), case .data = entry { return }
            throw LanguageModelError.unsupported(entry, "OpenRouter can't take this kind of transcript entry yet.")
        }
    }

    /// Ends the assistant turn in progress, if any, as one message.
    private mutating func endTurn() {
        defer { turn = AssistantTurn() }
        guard !turn.isEmpty else { return }
        messages.append(
            [
                "role": "assistant",
                "content": turn.text.isEmpty ? nil : .string(turn.text),
                // Reasoning text without its details would reach the provider unsigned, so it's sent only with them.
                "reasoning": turn.reasoningDetails.isEmpty || turn.reasoningText.isEmpty ? nil : .string(turn.reasoningText),
                // Some models send an empty list when they didn't reason, and expect it back.
                "reasoning_details": turn.hasReasoningDetails ? .array(turn.reasoningDetails) : nil,
                "tool_calls": turn.toolCalls.isEmpty ? nil : .array(turn.toolCalls),
            ]
        )
    }

    /// Changes the content parts of a message, turning plain-string content into one text part first.
    private mutating func updateParts(ofMessageAt index: Int, _ update: (inout [JSONValue]) -> Void) {
        guard case .object(var message) = messages[index] else { return }
        var parts: [JSONValue] =
            switch message["content"] {
            case .array(let parts)?: parts
            case .string(let text)?: [.textPart(text)]
            default: []
            }
        update(&parts)
        message["content"] = .array(parts)
        messages[index] = .object(message)
    }

    /// Text, structure and attachment segments as content parts, in their order.
    ///
    /// - Throws: The attachments' errors, and `LanguageModelError.unsupportedTranscriptContent` for a kind of segment
    ///   OpenRouter can't take.
    private mutating func parts(_ segments: [Transcript.Segment], of entry: Transcript.Entry) throws -> [JSONValue] {
        var parts: [JSONValue] = []
        for segment in segments {
            guard case .attachment(let attachment) = segment else {
                parts += try Self.textParts([segment], of: entry)
                continue
            }
            let attachmentParts = try attachments.parts(for: attachment, in: entry)
            carriesPDF = carriesPDF || attachmentParts.contains { $0["type"] == "file" }
            parts += attachmentParts
        }
        return parts
    }

    /// Text and structure segments as text parts.
    ///
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` for attachments, which OpenRouter's `system` messages
    ///   don't take, and for a kind of segment OpenRouter can't take.
    private static func textParts(_ segments: [Transcript.Segment], of entry: Transcript.Entry) throws -> [JSONValue] {
        try segments.map { segment in
            switch segment {
            case .text(let text):
                return .textPart(text.content)
            case .structure(let structure):
                return .textPart(JSONValue(structure.content).text)
            case .attachment:
                throw LanguageModelError.unsupported(entry, "OpenRouter's system messages take only text, not attachments.")
            @unknown default:
                throw LanguageModelError.unsupported(entry, "OpenRouter can't take this kind of segment yet.")
            }
        }
    }

    /// The text of each text and structure segment, leaving attachments out.
    private static func texts(of segments: [Transcript.Segment]) -> [String] {
        segments.compactMap { segment in
            switch segment {
            case .text(let text): text.content
            case .structure(let structure): JSONValue(structure.content).text
            default: nil
            }
        }
    }

    /// A message's content: a plain string for one text part, otherwise the parts.
    private static func content(_ parts: [JSONValue]) -> JSONValue {
        if parts.count == 1, let text = parts[0]["text"]?.stringValue { .string(text) } else { .array(parts) }
    }

}

/// The parts of one answer that become one `assistant` message.
private struct AssistantTurn {
    var text = ""
    var reasoningText = ""
    var reasoningDetails: [JSONValue] = []
    var hasReasoningDetails = false
    var toolCalls: [JSONValue] = []

    var isEmpty: Bool {
        text.isEmpty && reasoningDetails.isEmpty && toolCalls.isEmpty
    }
}
