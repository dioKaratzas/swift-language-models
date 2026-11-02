import Foundation
import FoundationModels
import LanguageModels

extension ChatCompletionRequest {
    /// A transcript as the format's `messages`.
    ///
    /// Instructions become `system` messages and prompts `user` messages. The reasoning, response text and tool calls
    /// of one answer become one `assistant` message, with a reasoning block that the model wrote in its answer's text
    /// back at the start of that text, and each tool output a `tool` message. The provider adds the reasoning it sends
    /// back to the assistant message. Prompts and tool outputs carry their attachments as content parts; generated
    /// data and an answer's attachments aren't sent back. Every entry turns into the same JSON each time, so a
    /// provider's prompt cache stays valid from one request to the next.
    struct Messages {
        private(set) var messages: [JSONValue] = []

        /// Whether a message carries a PDF.
        private(set) var carriesPDF = false

        /// The transcript entries whose messages carry an image, which a host's rejection of an image names.
        private(set) var imageEntries: [Transcript.Entry] = []

        private let attachments: ChatCompletionRequest.AttachmentParts

        /// The provider's name, for the errors.
        private let provider: String

        /// Whether a reasoning entry goes back.
        private let replays: (Transcript.Reasoning) -> Bool

        /// The assistant message's members for the reasoning it sends back.
        private let assistantMembers: ([Transcript.Reasoning]) -> JSONObject

        /// The messages for a transcript.
        ///
        /// A prompt that recorded a response schema, which Foundation Models does when the schema belongs in the
        /// prompt, carries the schema as text after its own, so every request writes it the same way.
        ///
        /// - Throws: `LanguageModelError.unsupportedTranscriptContent` for content the format or a model can't take,
        ///   and the provider's errors for an attachment a model doesn't take.
        init(_ transcript: some Sequence<Transcript.Entry>, provider: some ChatCompletionsProvider) throws {
            attachments = ChatCompletionRequest.AttachmentParts(provider: provider.name, check: provider.check, part: provider.contentPart)
            self.provider = provider.name
            replays = provider.replays
            assistantMembers = provider.assistantMembers(replaying:)
            for turn in try TranscriptTurn.turns(of: transcript, provider: self.provider) { try append(turn) }
        }

        private mutating func append(_ turn: TranscriptTurn) throws {
            switch turn {
            case .instructions(let instructions, let entry):
                // A session without instructions still has an empty instructions entry, which hosts reject.
                let parts = try textParts(instructions.segments, of: entry)
                guard !parts.isEmpty else { return }
                messages.append(["role": Role.system.json, "content": Self.content(parts)])
            case .prompt(let prompt, let entry):
                var parts = try parts(prompt.segments, of: entry)
                if case .schema(let schema)? = prompt.responseFormat?.kind {
                    parts.append(.textPart(try schema.promptInstructions()))
                }
                guard !parts.isEmpty else { return }
                messages.append(["role": Role.user.json, "content": Self.content(parts)])
            case .answer(let entries):
                var answer = AssistantTurn()
                for entry in entries { append(entry, to: &answer) }
                appendAssistantMessage(answer)
            case .toolOutput(let output, let entry):
                let parts = try parts(output.segments, of: entry)
                let texts = parts.compactMap { $0.partType == .text ? $0["text"]?.stringValue : nil }
                // Text alone goes as one string, a line per part, so a label doesn't run into its text; attachments need
                // the parts.
                let content: JSONValue = texts.count == parts.count ? .string(texts.joined(separator: "\n")) : .array(parts)
                messages.append(["role": Role.tool.json, "tool_call_id": .string(output.id), "content": content])
            }
        }

        /// Adds one of an answer's reasoning, response or tool-call entries to its assistant message.
        private mutating func append(_ entry: Transcript.Entry, to turn: inout AssistantTurn) {
            switch entry {
            case .reasoning(let reasoning):
                // Reasoning that another provider wrote is in its own format, so only the provider's own goes back.
                guard replays(reasoning) else { return }
                // A block the model wrote in its answer's text goes back there, as it was written: MiniMax M2 needs its
                // `<think>` blocks back within a tool loop, Nova's tool loop takes its `<thinking>` text back, and a chat
                // template that drops older blocks finds them by their tags.
                turn.text = (TaggedReasoning.block(of: reasoning) ?? "") + turn.text
                turn.reasoning.append(reasoning)
            case .response(let response):
                // An answer's attachments aren't sent back, since the format's assistant messages take only text.
                turn.text += response.segments.compactMap(\.text).joined()
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
            default:
                return
            }
        }

        /// Adds an answer's assistant message, unless the answer left nothing to send back.
        private mutating func appendAssistantMessage(_ turn: AssistantTurn) {
            let reasoning = turn.reasoning.isEmpty ? [:] : assistantMembers(turn.reasoning)
            let carriesReasoning = reasoning.members.contains { !$0.value.isEmpty }
            guard !turn.text.isEmpty || carriesReasoning || !turn.toolCalls.isEmpty else { return }
            let members: [JSONObject.Member] =
                [JSONObject.Member(key: "role", value: Role.assistant.json)]
                + (turn.text.isEmpty ? [] : [JSONObject.Member(key: "content", value: .string(turn.text))])
                + reasoning.members
                + (turn.toolCalls.isEmpty ? [] : [JSONObject.Member(key: "tool_calls", value: .array(turn.toolCalls))])
            messages.append(.object(JSONObject(members)))
        }

        /// Text, structure and attachment segments as content parts, in their order.
        ///
        /// - Throws: The attachments' errors, and `LanguageModelError.unsupportedTranscriptContent` for a kind of
        ///   segment the format can't take.
        private mutating func parts(_ segments: [Transcript.Segment], of entry: Transcript.Entry) throws -> [JSONValue] {
            var parts: [JSONValue] = []
            for segment in segments {
                guard case .attachment(let attachment) = segment else {
                    parts += try textParts([segment], of: entry)
                    continue
                }
                let attachmentParts = try attachments.parts(for: attachment, in: entry)
                carriesPDF = carriesPDF || attachmentParts.contains { $0.partType == .file }
                if attachmentParts.contains(where: { $0.partType == .image }), !imageEntries.contains(where: { $0.id == entry.id }) {
                    imageEntries.append(entry)
                }
                parts += attachmentParts
            }
            return parts
        }

        /// Text and structure segments as text parts.
        ///
        /// - Throws: `LanguageModelError.unsupportedTranscriptContent` for attachments, which `system` messages don't
        ///   take, and for a kind of segment the format can't take.
        private func textParts(_ segments: [Transcript.Segment], of entry: Transcript.Entry) throws -> [JSONValue] {
            try segments.map { segment in
                if let text = segment.text { return .textPart(text) }
                if case .attachment = segment {
                    throw LanguageModelError.unsupported(entry, "\(provider)'s system messages take only text, not attachments.")
                }
                throw LanguageModelError.unsupported(entry, "\(provider) can't take this kind of segment yet.")
            }
        }

        /// A message's content: a plain string for one text part, otherwise the parts.
        private static func content(_ parts: [JSONValue]) -> JSONValue {
            if parts.count == 1, let text = parts[0]["text"]?.stringValue { .string(text) } else { .array(parts) }
        }
    }
}

extension ChatCompletionRequest.Messages {
    /// The parts of one answer that become one `assistant` message.
    private struct AssistantTurn {
        var text = ""
        /// The reasoning entries that go back, in their order.
        var reasoning: [Transcript.Reasoning] = []
        var toolCalls: [JSONValue] = []
    }

    /// Who wrote a message: the instructions, the person, the model or a tool.
    struct Role: ProviderVocabulary {
        static let system: Self = "system"
        static let user: Self = "user"
        static let assistant: Self = "assistant"
        static let tool: Self = "tool"

        let rawValue: String
    }
}

extension JSONValue {
    /// Whether the value is an empty list, an empty text or `null`, which carries nothing.
    fileprivate var isEmpty: Bool {
        switch self {
        case .null: true
        case .string(let text): text.isEmpty
        case .array(let elements): elements.isEmpty
        default: false
        }
    }
}
