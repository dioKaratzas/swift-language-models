import Foundation
import FoundationModels
import LanguageModels

/// The body of OpenRouter's `POST /chat/completions` for one Foundation Models request.
///
/// A setting is sent only when the model lists its parameter, so a host never sees a parameter the model doesn't
/// take. Every part is written the same way each time, so a provider's prompt cache stays valid across requests.
struct ChatCompletionRequest {
    let body: JSONValue

    init<Effort>(_ request: LanguageModelExecutorGenerationRequest, model: OpenRouterLanguageModel<Effort>) throws {
        let details = model.details
        let parameters = details.supportedParameters
        func listed(_ parameter: OpenRouterParameter, _ value: JSONValue?) -> JSONValue? {
            parameters.contains(parameter) ? value : nil
        }

        let schema = request.schema
        let usesStructuredOutputs = schema != nil && parameters.contains(.structuredOutputs)
        let messages = try ChatMessages(
            request.transcript,
            cacheControl: model.cacheControl,
            // Without structured outputs, the prompt is the only place the model learns the schema.
            requiredSchema: usesStructuredOutputs ? nil : schema,
            schemaInstructions: Self.instructions(for:)
        )

        let tools = try Self.tools(request, parameters: parameters)
        let options = request.generationOptions
        let sampling = Sampling(options, parameters: parameters)
        let extra = model.options
        body = [
            "model": .string(details.id.rawValue),
            "messages": .array(messages.messages),
            "stream": true,
            "tools": tools.map(JSONValue.array),
            "tool_choice": tools == nil ? nil : listed(.toolChoice, Self.toolChoice(options.toolCallingMode)),
            "parallel_tool_calls": tools == nil ? nil : listed(.parallelToolCalls, true),
            "response_format": try Self.responseFormat(schema, structured: usesStructuredOutputs, parameters: parameters),
            "reasoning": Self.reasoning(request.contextOptions.reasoningLevel, details: details),
            "temperature": sampling.temperature.flatMap { listed(.temperature, .number($0)) },
            "top_p": sampling.topP.flatMap { listed(.topP, .number($0)) },
            "top_k": sampling.topK.flatMap { listed(.topK, .integer($0)) },
            "seed": sampling.seed.flatMap { seed in Int(exactly: seed).flatMap { listed(.seed, .integer($0)) } },
            "max_completion_tokens": Self.maximumTokens(options, details: details, key: .maxCompletionTokens),
            "max_tokens": parameters.contains(.maxCompletionTokens) ? nil : Self.maximumTokens(options, details: details, key: .maxTokens),
            "frequency_penalty": extra.frequencyPenalty.flatMap { listed(.frequencyPenalty, .number($0)) },
            "presence_penalty": extra.presencePenalty.flatMap { listed(.presencePenalty, .number($0)) },
            "repetition_penalty": extra.repetitionPenalty.flatMap { listed(.repetitionPenalty, .number($0)) },
            "min_p": extra.minP.flatMap { listed(.minP, .number($0)) },
            "top_a": extra.topA.flatMap { listed(.topA, .number($0)) },
            "stop": extra.stopSequences.flatMap { listed(.stop, .array($0.map(JSONValue.string))) },
            "logit_bias": extra.logitBias.flatMap { bias in
                listed(
                    .logitBias,
                    .object(JSONObject(bias.sorted { $0.key < $1.key }.map { .init(key: String($0.key), value: .number($0.value)) })))
            },
            "service_tier": extra.serviceTier.map { .string($0.rawValue) },
            "user": extra.user.map(JSONValue.string),
            "provider": model.routing.json(requiresParameters: tools != nil || schema != nil),
            "session_id": Self.sessionID(of: request.transcript),
            "metadata": Self.metadata(request.metadata),
            "cache_control": model.cacheControl?.json,
        ]
    }

    /// The tools, or `nil` when the request has none or the model doesn't take them.
    ///
    /// Foundation Models sends no tools when tool calling is disallowed, so there's nothing to forbid here.
    private static func tools(_ request: LanguageModelExecutorGenerationRequest, parameters: Set<OpenRouterParameter>) throws
        -> [JSONValue]?
    {
        guard !request.enabledToolDefinitions.isEmpty, parameters.contains(.tools) else { return nil }
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

    /// Structured outputs when the model takes them, otherwise JSON mode, with the schema in the prompt.
    private static func responseFormat(
        _ schema: GenerationSchema?,
        structured: Bool,
        parameters: Set<OpenRouterParameter>
    ) throws -> JSONValue? {
        guard let schema else { return nil }
        if structured {
            return [
                "type": "json_schema",
                "json_schema": ["name": .string(name(of: schema)), "strict": true, "schema": try JSONValue(schema, strict: true)],
            ]
        }
        return parameters.contains(.responseFormat) ? ["type": "json_object"] : nil
    }

    private static func toolChoice(_ mode: GenerationOptions.ToolCallingMode?) -> JSONValue? {
        switch mode?.kind {
        case .allowed?: "auto"
        case .required?: "required"
        case .disallowed?: "none"
        case nil: nil
        @unknown default: nil
        }
    }

    /// The reasoning setting: the nearest effort the model accepts, or for a model whose effort can't be chosen,
    /// whether to reason at all.
    private static func reasoning(_ level: ContextOptions.ReasoningLevel?, details: OpenRouterModel<some ModelEffort>) -> JSONValue? {
        guard let level, details.reasoning != .unsupported else { return nil }
        if details.reasoningEfforts.isEmpty {
            let turnsOff = level == .off
            return turnsOff && details.reasoning == .mandatory ? nil : ["enabled": .bool(!turnsOff)]
        }
        return level.providerEffort(supporting: details.reasoningEfforts).map { ["effort": .string($0)] }
    }

    /// The most tokens to generate, no more than the model's own limit, under the parameter name the model lists.
    private static func maximumTokens(
        _ options: GenerationOptions,
        details: OpenRouterModel<some ModelEffort>,
        key: OpenRouterParameter
    ) -> JSONValue? {
        guard let requested = options.maximumResponseTokens, details.supportedParameters.contains(key) else { return nil }
        return .integer(details.maximumOutputTokens.map { min(requested, $0) } ?? requested)
    }

    /// The schema's name, in the letters, digits, `_` and `-` that OpenRouter allows, up to 64 characters.
    private static func name(of schema: GenerationSchema) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        let name = String(schema.name.map { allowed.contains($0) ? $0 : "_" }.prefix(64))
        return name.isEmpty ? "response" : name
    }

    /// The text that asks for JSON matching a schema.
    private static func instructions(for schema: GenerationSchema) throws -> String {
        let json = try JSONValue(schema, strict: false).text
        return "Respond with JSON that matches this JSON Schema:\n\(json)"
    }

    /// The longest session id OpenRouter takes.
    private static let sessionIDLimit = 256

    /// OpenRouter's limits on request metadata.
    private enum MetadataLimit {
        static let pairs = 16
        static let keyLength = 64
        static let valueLength = 512
    }

    /// The id of the transcript's first prompt, which stays the same for the whole session, so OpenRouter keeps
    /// sending it to the host that cached its prompt.
    private static func sessionID(of transcript: Transcript) -> JSONValue? {
        for case .prompt(let prompt) in transcript {
            return .string(String(prompt.id.prefix(sessionIDLimit)))
        }
        return nil
    }

    /// The request's string metadata, sorted by key, within OpenRouter's limits: 16 pairs, keys up to 64 characters
    /// and values up to 512. Pairs past the limits are left out, since OpenRouter rejects the whole request for them.
    private static func metadata(_ metadata: [String: GeneratedContent]) -> JSONValue? {
        let members = metadata.compactMap { key, value -> JSONObject.Member? in
            guard key.count <= MetadataLimit.keyLength, case .string(let text) = value.kind, text.count <= MetadataLimit.valueLength
            else { return nil }
            return .init(key: key, value: .string(text))
        }
        let limited = JSONObject(members).sorted { $0.key < $1.key }.members.prefix(MetadataLimit.pairs)
        return limited.isEmpty ? nil : .object(JSONObject(Array(limited)))
    }
}

/// Foundation Models' sampling options as OpenRouter's parameters.
private struct Sampling {
    var temperature: Double?
    var topP: Double?
    var topK: Int?
    var seed: UInt64?

    /// Greedy sampling becomes temperature 0, and also `top_k` 1 when the model takes it. Temperatures are clamped to
    /// OpenRouter's 0 to 2, and probability thresholds to 0 to 1.
    init(_ options: GenerationOptions, parameters: Set<OpenRouterParameter>) {
        temperature = options.temperature.map { min(max($0, 0), 2) }
        switch options.samplingMode?.kind {
        case .greedy?:
            temperature = 0
            topK = parameters.contains(.topK) ? 1 : nil
        case .randomTopK(let k, let seed)?:
            topK = k
            self.seed = seed
        case .randomProbabilityThreshold(let threshold, let seed)?:
            topP = min(max(threshold, 0), 1)
            self.seed = seed
        case nil:
            break
        @unknown default:
            break
        }
    }
}
