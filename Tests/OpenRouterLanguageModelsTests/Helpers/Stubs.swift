import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting

@testable import OpenRouterLanguageModels

/// The parameters of a typical chat model with tools, structured outputs and reasoning.
let chatParameters: Set<OpenRouterParameter> = [
    .maxTokens, .reasoning, .responseFormat, .seed, .structuredOutputs, .temperature, .toolChoice, .tools, .topK, .topP,
]

/// A model served by a stub, with no wait before a retry.
func model<Effort: ModelEffort>(
    _ stub: HTTPStub,
    id: OpenRouterModelID = "vendor/model",
    parameters: Set<OpenRouterParameter> = chatParameters,
    reasoning: OpenRouterReasoning = .optional(enabledByDefault: false),
    efforts: [Effort] = [],
    routing: OpenRouterRouting = OpenRouterRouting(),
    cacheControl: OpenRouterCacheControl? = nil,
    options: OpenRouterOptions = OpenRouterOptions()
) -> OpenRouterLanguageModel<Effort> {
    OpenRouterLanguageModel(
        details: OpenRouterModel(
            id: id,
            displayName: "Vendor: Model",
            releaseDate: .distantPast,
            contextSize: 200_000,
            maximumOutputTokens: 8_192,
            supportedParameters: parameters,
            reasoning: reasoning,
            reasoningEfforts: efforts
        ),
        routing: routing,
        options: options,
        cacheControl: cacheControl,
        session: stub.session,
        apiKey: { "sk-or-test" },
        configuration: .init(baseURL: stub.baseURL, appName: "Coach", appURL: nil, idleTimeout: nil, retryDelay: .zero)
    )
}

/// A model without reasoning efforts to choose from.
func model(
    _ stub: HTTPStub,
    id: OpenRouterModelID = "vendor/model",
    parameters: Set<OpenRouterParameter> = chatParameters,
    routing: OpenRouterRouting = OpenRouterRouting(),
    cacheControl: OpenRouterCacheControl? = nil,
    options: OpenRouterOptions = OpenRouterOptions()
) -> OpenRouterLanguageModel<Efforts.Unsupported> {
    model(
        stub, id: id, parameters: parameters, efforts: [Efforts.Unsupported](), routing: routing, cacheControl: cacheControl,
        options: options)
}

/// A string value in an entry's metadata.
func metadataString(_ metadata: [String: GeneratedContent], _ key: String) -> String? {
    if case .string(let text)? = metadata[key]?.kind { text } else { nil }
}

/// A number value in an entry's or usage's metadata.
func metadataNumber(_ metadata: [String: GeneratedContent], _ key: String) -> Double? {
    if case .number(let number)? = metadata[key]?.kind { number } else { nil }
}

/// The text of an entry's text segments, joined.
func plainText(_ segments: [Transcript.Segment]) -> String {
    segments.compactMap { segment in
        if case .text(let text) = segment { text.content } else { nil }
    }.joined()
}

/// A streamed answer made of the given chunks, then `[DONE]`.
func events(_ chunks: JSONValue...) -> StubResponse {
    eventStream(chunks, isComplete: true)
}

/// The start of a streamed answer: the given chunks, without the `[DONE]` that ends it.
func unfinishedEvents(_ chunks: JSONValue...) -> StubResponse {
    eventStream(chunks, isComplete: false)
}

private func eventStream(_ chunks: [JSONValue], isComplete: Bool) -> StubResponse {
    let data = chunks.map { "data: \(String(decoding: $0.data, as: UTF8.self))" }
    let lines = [": OPENROUTER PROCESSING"] + data + (isComplete ? ["data: [DONE]"] : [])
    return .eventStream(Data(lines.map { "\($0)\n\n" }.joined().utf8))
}

/// A chunk whose delta is the given object.
func chunk(_ delta: JSONValue, finishReason: String? = nil, usage: JSONValue? = nil) -> JSONValue {
    let choice: JSONValue = ["index": 0, "delta": delta, "finish_reason": finishReason.map(JSONValue.string) ?? .null]
    return ["id": "gen-1", "model": "vendor/model", "provider": "Vendor", "choices": [choice], "usage": usage]
}

/// A chunk of answer text.
func text(_ text: String, finishReason: String? = nil) -> JSONValue {
    chunk(["content": .string(text)], finishReason: finishReason)
}

/// A chunk with one tool-call fragment. A fragment without an index leaves the field out.
func toolCall(_ index: Int?, id: String? = nil, name: String? = nil, arguments: String? = nil) -> JSONValue {
    let function: JSONValue = ["name": name.map(JSONValue.string), "arguments": arguments.map(JSONValue.string)]
    let fragment: JSONValue = [
        "index": index.map(JSONValue.integer), "id": id.map(JSONValue.string), "type": "function", "function": function,
    ]
    return chunk(["tool_calls": [fragment]])
}

/// A chunk of reasoning details.
func reasoning(_ details: JSONValue...) -> JSONValue {
    chunk(["reasoning_details": .array(details)])
}

/// The final chunk, with usage.
func done(
    _ finishReason: String = "stop",
    prompt: Int = 12,
    cached: Int = 0,
    cacheWrite: Int? = nil,
    completion: Int = 5,
    reasoning: Int = 0
) -> JSONValue {
    let promptDetails: JSONValue = ["cached_tokens": .integer(cached), "cache_write_tokens": cacheWrite.map(JSONValue.integer)]
    let completionDetails: JSONValue = ["reasoning_tokens": .integer(reasoning)]
    let usage: JSONValue = [
        "prompt_tokens": .integer(prompt),
        "completion_tokens": .integer(completion),
        "total_tokens": .integer(prompt + completion),
        "prompt_tokens_details": promptDetails,
        "completion_tokens_details": completionDetails,
        "cost": .number(0.000_25),
    ]
    return chunk([:], finishReason: finishReason, usage: usage)
}

/// The JSON body of a recorded request.
func body(_ request: RecordedRequest) throws -> JSONValue {
    try JSONValue(json: request.body)
}

/// The JSON body of the stub's request at an index.
func body(_ stub: HTTPStub, _ index: Int = 0) throws -> JSONValue {
    let requests = stub.requests
    guard requests.indices.contains(index) else { throw MissingRequest(index: index, count: requests.count) }
    return try body(requests[index])
}

/// The stub received fewer requests than a test reads.
struct MissingRequest: Error, CustomStringConvertible {
    let index: Int
    let count: Int

    var description: String { "Request \(index) was read, but the stub received \(count)." }
}

/// The messages of a request body.
func messages(_ body: JSONValue) -> [JSONValue] {
    elements(body["messages"])
}

/// The elements of a JSON array, or none when the value isn't one.
func elements(_ value: JSONValue?) -> [JSONValue] {
    if case .array(let elements)? = value { elements } else { [] }
}

/// The assistant messages of the stub's request at an index.
func assistantMessages(_ stub: HTTPStub, _ index: Int = 0) throws -> [JSONValue] {
    messages(try body(stub, index)).filter { $0["role"] == "assistant" }
}

/// Sends one prompt through a new session with the stub's model.
///
/// - Returns: The answer's text.
@discardableResult
func respond(_ stub: HTTPStub, to prompt: String = "Hi") async throws -> String {
    try await LanguageModelSession(model: model(stub)).respond(to: prompt).content
}

/// A tool that looks up a food's calories.
struct FoodTool: Tool {
    let name = "lookUpFood"
    let description = "Looks up a food's calories."

    @Generable
    struct Arguments {
        var food: String
    }

    func call(arguments: Arguments) async throws -> String {
        "\(arguments.food): 100 kcal"
    }
}
