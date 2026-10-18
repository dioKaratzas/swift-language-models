import Foundation
import FoundationModels
import LanguageModels

/// A transcript as OpenRouter's `messages`.
///
/// Instructions become `system` messages and prompts `user` messages. The reasoning, response text and tool calls
/// of one answer become one `assistant` message, and each tool output a `tool` message. Every entry turns into the
/// same JSON each time, so a provider's prompt cache stays valid from one request to the next.
struct ChatMessages {
    private(set) var messages: [JSONValue] = []
    private var turn = AssistantTurn()
    private var sentDetails: Set<Data> = []
    private var lastInstructionsIndex: Int?

    /// The text that asks for JSON matching a schema, added to the prompt that asked for the schema, or `nil` when the
    /// provider is told the schema another way.
    private let schemaInstructions: (GenerationSchema) throws -> String?

    /// The messages for a transcript.
    ///
    /// - Parameters:
    ///   - transcript: The entries to send.
    ///   - cacheControl: When set, the last instructions carry a cache marker, so the tools and instructions before it
    ///     are cached for every later request that starts the same way.
    ///   - schemaInstructions: The text that asks for JSON matching a schema, or `nil` for none.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` for content OpenRouter can't take yet.
    init(
        _ transcript: some Sequence<Transcript.Entry>,
        cacheControl: OpenRouterCacheControl?,
        schemaInstructions: @escaping (GenerationSchema) throws -> String?
    ) throws {
        self.schemaInstructions = schemaInstructions
        for entry in transcript { try append(entry) }
        endTurn()
        if let cacheControl, let index = lastInstructionsIndex { markForCaching(at: index, cacheControl) }
    }

    private mutating func append(_ entry: Transcript.Entry) throws {
        switch entry {
        case .instructions(let instructions):
            endTurn()
            lastInstructionsIndex = messages.count
            messages.append(["role": "system", "content": Self.content(try Self.parts(instructions.segments, of: entry))])
        case .prompt(let prompt):
            endTurn()
            var parts = try Self.parts(prompt.segments, of: entry)
            if case .schema(let schema)? = prompt.responseFormat?.kind, let text = try schemaInstructions(schema) {
                parts.append(["type": "text", "text": .string(text)])
            }
            messages.append(["role": "user", "content": Self.content(parts)])
        case .reasoning(let reasoning):
            guard let details = ReasoningDetails.replayed(from: reasoning) else { return }
            let unsent = details.filter { sentDetails.insert($0.data).inserted }
            turn.reasoningDetails += unsent
            if !unsent.isEmpty { turn.reasoningText += Self.text(of: reasoning.segments) }
        case .response(let response):
            turn.text += try Self.parts(response.segments, of: entry).compactMap { $0["text"]?.stringValue }.joined()
        case .toolCalls(let toolCalls):
            turn.toolCalls += toolCalls.map { call in
                [
                    "id": .string(call.id),
                    "type": "function",
                    "function": [
                        "name": .string(call.toolName),
                        "arguments": .string(String(decoding: JSONValue(call.arguments).data, as: UTF8.self)),
                    ],
                ]
            }
        case .toolOutput(let output):
            endTurn()
            let text = try Self.parts(output.segments, of: entry).compactMap { $0["text"]?.stringValue }.joined()
            messages.append(["role": "tool", "tool_call_id": .string(output.id), "content": .string(text)])
        default:
            throw Self.unsupported(entry, "OpenRouter can't take this kind of transcript entry yet.")
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
                "reasoning_details": turn.reasoningDetails.isEmpty ? nil : .array(turn.reasoningDetails),
                "tool_calls": turn.toolCalls.isEmpty ? nil : .array(turn.toolCalls),
            ]
        )
    }

    private mutating func markForCaching(at index: Int, _ cacheControl: OpenRouterCacheControl) {
        guard case .object(var message) = messages[index] else { return }
        var parts: [JSONValue] =
            switch message["content"] {
            case .array(let parts)?: parts
            case .string(let text)?: [["type": "text", "text": JSONValue.string(text)]]
            default: []
            }
        guard case .object(var last)? = parts.last else { return }
        last["cache_control"] = cacheControl.json
        parts[parts.count - 1] = JSONValue.object(last)
        message["content"] = .array(parts)
        messages[index] = .object(message)
    }

    /// Text and structure segments as text parts.
    ///
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` for attachments.
    private static func parts(_ segments: [Transcript.Segment], of entry: Transcript.Entry) throws -> [JSONValue] {
        try segments.map { segment in
            switch segment {
            case .text(let text):
                return ["type": "text", "text": .string(text.content)]
            case .structure(let structure):
                return ["type": "text", "text": .string(String(decoding: JSONValue(structure.content).data, as: UTF8.self))]
            case .attachment:
                throw unsupported(entry, "OpenRouter attachments aren't supported yet.")
            @unknown default:
                throw unsupported(entry, "OpenRouter can't take this kind of segment yet.")
            }
        }
    }

    /// A message's content: a plain string for one text part, otherwise the parts.
    private static func content(_ parts: [JSONValue]) -> JSONValue {
        if parts.count == 1, let text = parts[0]["text"]?.stringValue { .string(text) } else { .array(parts) }
    }

    private static func text(of segments: [Transcript.Segment]) -> String {
        segments.compactMap { segment in
            if case .text(let text) = segment { text.content } else { nil }
        }.joined()
    }

    private static func unsupported(_ entry: Transcript.Entry, _ description: String) -> LanguageModelError {
        .unsupportedTranscriptContent(.init(unsupportedContent: [entry], debugDescription: description))
    }
}

/// The parts of one answer that become one `assistant` message.
private struct AssistantTurn {
    var text = ""
    var reasoningText = ""
    var reasoningDetails: [JSONValue] = []
    var toolCalls: [JSONValue] = []

    var isEmpty: Bool {
        text.isEmpty && reasoningDetails.isEmpty && toolCalls.isEmpty
    }
}
