import Foundation
import FoundationModels
import LanguageModels

/// The body of a Chat Completions `POST` for one Foundation Models request, after the provider changed it.
///
/// The format writes its members in a fixed order, then the provider adds its own, leaves out what its models don't
/// take and orders them. Every part is written the same way each time, so a provider's prompt cache stays valid across
/// requests.
struct ChatCompletionRequest {
    let body: JSONValue

    /// The same body with its response schema in portable form, to send instead when a host rejects a constraint of
    /// the full schema, or `nil` when the request has no schema or already sends the portable one.
    let portableSchemaBody: JSONValue?

    /// What the request leaves out or changes from what the app asked for, so that its models and the provider take
    /// it: settings the models don't list, then metadata past the limits, then a moved reasoning effort.
    let adjustments: [APIFormat.Adjustment]

    /// The transcript entries that carry an image, which an error for an image the host rejects names.
    let imageEntries: [Transcript.Entry]

    /// The request for Foundation Models' request to a provider.
    ///
    /// - Throws: `LanguageModelError` when the format or the provider can't take the transcript, the tools or the
    ///   schema, and the provider's errors.
    init<Provider: ChatCompletionsProvider>(_ request: LanguageModelExecutorGenerationRequest, provider: Provider) throws {
        let schema = request.schema
        let messages = try ChatCompletionRequest.Messages(request.transcript, provider: provider)
        let options = request.generationOptions
        let tools = try Self.tools(request)
        let sampling = Sampling(options, temperatureRange: 0...2)
        let metadata = APIFormat.metadata(request.metadata)
        let members: JSONObject = [
            Key.model: .string(provider.modelID),
            Key.messages: .array(messages.messages),
            Key.stream: true,
            Key.tools: tools.map(JSONValue.array),
            Key.toolChoice: tools == nil ? nil : Self.toolChoice(options.toolCallingMode),
            Key.responseFormat: try schema.map { try Self.jsonSchemaFormat($0, portable: false) },
            Key.temperature: sampling.temperature.map(JSONValue.number),
            Key.topP: sampling.topP.map(JSONValue.number),
            Key.seed: sampling.seed.map(Sampling.json(seed:)),
            // The token limit goes out as the request asks: a host that routes it picks a model that answers that long.
            Key.maxCompletionTokens: options.maximumResponseTokens.map(JSONValue.integer),
            Key.metadata: metadata.json,
        ]
        var body = ChatCompletionsExecutor<Provider>.Body(
            members: members, carriesPDF: messages.carriesPDF,
            adjustments: metadata.droppedKeys.isEmpty ? [] : [.droppedMetadata(keys: metadata.droppedKeys)], schema: schema)
        try provider.transformBody(&body, for: request)
        self.body = .object(body.members)
        if let schema, !body.sendsPortableSchema, body.members[Key.responseFormat] != nil {
            var portable = body.members
            portable[Key.responseFormat] = try Self.jsonSchemaFormat(schema, portable: true)
            portableSchemaBody = .object(portable)
        } else {
            portableSchemaBody = nil
        }
        imageEntries = messages.imageEntries
        adjustments = body.adjustments.sorted { $0.rank < $1.rank }
    }

    /// The session's tools as functions, or `nil` when the request has none.
    ///
    /// Foundation Models sends no tools when tool calling is disallowed, so there's nothing to forbid here.
    private static func tools(_ request: LanguageModelExecutorGenerationRequest) throws -> [JSONValue]? {
        guard !request.enabledToolDefinitions.isEmpty else { return nil }
        return try request.enabledToolDefinitions.map { tool in
            [
                "type": "function",
                "function": [
                    "name": .string(tool.name),
                    "description": .string(tool.description),
                    "parameters": try JSONValue(tool.parameters, strict: false),
                ],
            ]
        }
    }

    /// Structured outputs with a strict schema, in full or in portable form.
    ///
    /// Some hosts reject constraints such as `minimum`, `maxItems` and `pattern`, so the portable form moves them into
    /// the description, where the model still reads them.
    static func jsonSchemaFormat(_ schema: GenerationSchema, portable: Bool) throws -> JSONValue {
        let json = try JSONValue(schema, strict: true)
        return [
            "type": "json_schema",
            "json_schema": ["name": .string(schema.wireName), "strict": true, "schema": portable ? json.portableSchema : json],
        ]
    }

    private static func toolChoice(_ mode: GenerationOptions.ToolCallingMode?) -> JSONValue? {
        let choice: ToolChoice? =
            switch mode?.kind {
            case .allowed?: .auto
            case .required?: .required
            case .disallowed?: ToolChoice.none
            case nil: nil
            @unknown default: nil
            }
        return choice?.json
    }
}

extension ChatCompletionRequest {
    /// The keys of the members the format writes.
    enum Key {
        static let model = "model"
        static let messages = "messages"
        static let stream = "stream"
        static let tools = "tools"
        static let toolChoice = "tool_choice"
        static let responseFormat = "response_format"
        static let temperature = "temperature"
        static let topP = "top_p"
        static let seed = "seed"
        static let maxCompletionTokens = "max_completion_tokens"
        static let metadata = "metadata"
    }

    /// Whether the model may or must call the session's tools, as `tool_choice` spells it.
    fileprivate struct ToolChoice: ProviderVocabulary {
        static let auto: Self = "auto"
        static let required: Self = "required"
        static let none: Self = "none"

        let rawValue: String
    }
}

extension APIFormat.Adjustment {
    /// The adjustment's place in the log: settings left out, then metadata, then the reasoning effort.
    fileprivate var rank: Int {
        switch self {
        case .unlistedParameters: 0
        case .droppedMetadata: 1
        case .movedEffort: 2
        }
    }
}
