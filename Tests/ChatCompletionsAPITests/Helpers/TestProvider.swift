import ChatCompletionsAPI
import Foundation
import FoundationModels
import LanguageModels
import UniformTypeIdentifiers

/// A provider that adds only what a test gives it, so the format's own behavior shows.
struct TestProvider: ChatCompletionsProvider {
    /// The provider's base URL, such as a stub's.
    var url = URL(fileURLWithPath: "/")

    /// Changes the provider makes to the finished body.
    var transform: @Sendable (inout Body) throws -> Void = { _ in }

    /// The key under which an assistant message carries the text of the reasoning it sends back, or `nil` to send none.
    var reasoningMember: String?

    var name: String { "Test" }

    var baseURL: URL { url }

    var modelID: String { "vendor/model" }

    func headers(for request: LanguageModelExecutorGenerationRequest) async throws -> [String: String] { ["X-Test": "yes"] }

    func transformBody(_ body: inout Body, for request: LanguageModelExecutorGenerationRequest) throws {
        try transform(&body)
    }

    func assistantMembers(replaying reasoning: [Transcript.Reasoning]) -> JSONObject {
        guard let reasoningMember else { return [:] }
        return [reasoningMember: .string(reasoning.map { $0.segments.compactMap(\.text).joined() }.joined())]
    }

    func stream(for response: HTTPURLResponse?) -> Stream { Stream() }

    func observe(_ chunk: Chunk, in stream: inout Stream) throws -> ChunkOutput {
        let extras = try chunk.decode(Extras.self)
        stream.host = extras.host ?? stream.host
        return ChunkOutput(reasoning: extras.choices?.first?.delta?.reasoning)
    }

    func facts(of stream: Stream) -> Facts {
        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[LanguageModelMetadataKey.provider] = stream.host
        return Facts(host: stream.host, metadata: metadata)
    }
}

extension TestProvider {
    /// The host the chunks named.
    struct Stream: Sendable {
        var host: String?
    }

    /// The members of a chunk only the test provider reads: the host, and plain reasoning text in the delta.
    struct Extras: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let reasoning: String?
            }

            let delta: Delta?
        }

        let host: String?
        let choices: [Choice]?
    }
}

/// What Foundation Models asks the executor for.
func generationRequest(
    _ entries: [Transcript.Entry],
    tools: [Transcript.ToolDefinition] = [],
    schema: GenerationSchema? = nil,
    options: GenerationOptions = GenerationOptions(),
    metadata: [String: any ConvertibleToGeneratedContent] = [:]
) -> LanguageModelExecutorGenerationRequest {
    LanguageModelExecutorGenerationRequest(
        id: UUID(), transcript: Transcript(entries: entries), enabledTools: tools, schema: schema, generationOptions: options,
        contextOptions: ContextOptions(), metadata: metadata)
}

/// A prompt entry with the given segments.
func prompt(_ segments: Transcript.Segment...) -> Transcript.Entry {
    .prompt(Transcript.Prompt(segments: segments))
}

/// A text segment.
func text(_ content: String) -> Transcript.Segment {
    .text(.init(content: content))
}

/// The messages of a request body.
func messages(_ body: JSONValue) -> [JSONValue] {
    if case .array(let messages)? = body["messages"] { messages } else { [] }
}

/// The keys of an object, in order.
func keys(_ value: JSONValue?) -> [String] {
    if case .object(let object)? = value { object.members.map(\.key) } else { [] }
}
