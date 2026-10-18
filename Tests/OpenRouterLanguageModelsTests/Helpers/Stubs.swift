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
    parameters: Set<OpenRouterParameter> = chatParameters,
    reasoning: OpenRouterReasoning = .optional(enabledByDefault: false),
    efforts: [Effort] = [],
    cacheControl: OpenRouterCacheControl? = nil,
    options: OpenRouterOptions = OpenRouterOptions()
) -> OpenRouterLanguageModel<Effort> {
    var model = OpenRouterLanguageModel(
        OpenRouterModel(
            id: "vendor/model",
            displayName: "Vendor: Model",
            releaseDate: .distantPast,
            contextSize: 200_000,
            maximumOutputTokens: 8_192,
            supportedParameters: parameters,
            reasoning: reasoning,
            reasoningEfforts: efforts
        ),
        options: options,
        cacheControl: cacheControl,
        appName: "Coach",
        baseURL: stub.baseURL,
        session: stub.session,
        apiKey: { "sk-or-test" }
    )
    model.executorConfiguration.retryDelay = .zero
    return model
}

/// A model without reasoning efforts to choose from.
func model(
    _ stub: HTTPStub,
    parameters: Set<OpenRouterParameter> = chatParameters,
    cacheControl: OpenRouterCacheControl? = nil,
    options: OpenRouterOptions = OpenRouterOptions()
) -> OpenRouterLanguageModel<Efforts.Unsupported> {
    model(stub, parameters: parameters, efforts: [Efforts.Unsupported](), cacheControl: cacheControl, options: options)
}

/// A string value in an entry's metadata.
func metadataString(_ metadata: [String: GeneratedContent], _ key: String) -> String? {
    if case .string(let text)? = metadata[key]?.kind { text } else { nil }
}

/// A streamed answer made of the given chunks, then `[DONE]`.
func events(_ chunks: JSONValue...) -> StubResponse {
    let lines = [": OPENROUTER PROCESSING"] + chunks.map { "data: \(String(decoding: $0.data, as: UTF8.self))" } + ["data: [DONE]"]
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

/// The final chunk, with usage.
func done(_ finishReason: String = "stop", prompt: Int = 12, cached: Int = 0, completion: Int = 5, reasoning: Int = 0) -> JSONValue {
    let promptDetails: JSONValue = ["cached_tokens": .integer(cached)]
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
    if case .array(let messages)? = body["messages"] { messages } else { [] }
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
