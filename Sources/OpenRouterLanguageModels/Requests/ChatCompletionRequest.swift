import Foundation
import FoundationModels
import LanguageModels

/// The body of OpenRouter's `POST /chat/completions` for one Foundation Models request.
///
/// The body names the model and lists its fallbacks after it. Any of them may answer, so a setting is sent only when
/// each of them lists its parameter, and a host never sees a parameter its model doesn't take. Every part is written
/// the same way each time, so a provider's prompt cache stays valid across requests.
struct ChatCompletionRequest {
    let body: JSONValue

    init<Effort>(_ request: LanguageModelExecutorGenerationRequest, model: OpenRouterLanguageModel<Effort>) throws {
        let details = model.sharedDetails
        let parameters = details.supportedParameters
        func listed(_ parameter: OpenRouterParameter, _ value: JSONValue?) -> JSONValue? {
            parameters.contains(parameter) ? value : nil
        }

        let schema = request.schema
        let usesStructuredOutputs = schema != nil && parameters.contains(.structuredOutputs)
        let messages = try ChatMessages(
            request.transcript,
            cacheControl: model.cacheControl,
            replaysReasoning: model.replaysReasoning(writtenBy:),
            // Without structured outputs, the prompt is the only place the model learns the schema.
            requiredSchema: usesStructuredOutputs ? nil : schema,
            schemaInstructions: Self.instructions(for:)
        )

        let tools = try Self.tools(request, parameters: parameters)
        let options = request.generationOptions
        let allTools = (tools ?? []) + (try Self.serverTools(model.serverTools, options: options, parameters: parameters))
        let sampling = Sampling(options, parameters: parameters)
        let extra = model.options
        body = [
            "model": .string(model.routing.modelID(for: model.details.id)),
            "models": model.fallbacks.isEmpty ? nil : .array(model.fallbacks.map { .string(model.routing.modelID(for: $0.id)) }),
            "messages": .array(messages.messages),
            "stream": true,
            "tools": allTools.isEmpty ? nil : .array(allTools),
            // The tool choice and parallel calls concern only the session's tools.
            "tool_choice": tools == nil ? nil : listed(.toolChoice, Self.toolChoice(options.toolCallingMode)),
            "parallel_tool_calls": tools == nil ? nil : listed(.parallelToolCalls, true),
            "response_format": try Self.responseFormat(
                schema, structured: usesStructuredOutputs, isAnthropic: model.modelIDs.contains(where: \.isAnthropic),
                parameters: parameters),
            "reasoning": Self.reasoning(request.contextOptions.reasoningLevel, details: details),
            "temperature": listed(.temperature, sampling.temperature.map(JSONValue.number)),
            "top_p": listed(.topP, sampling.topP.map(JSONValue.number)),
            "top_k": listed(.topK, sampling.topK.map(JSONValue.integer)),
            "seed": listed(.seed, sampling.seed.flatMap { Int(exactly: $0) }.map(JSONValue.integer)),
            "max_completion_tokens": Self.maximumTokens(options, details: details, key: .maxCompletionTokens),
            "max_tokens": parameters.contains(.maxCompletionTokens) ? nil : Self.maximumTokens(options, details: details, key: .maxTokens),
            "frequency_penalty": listed(.frequencyPenalty, extra.frequencyPenalty.map(JSONValue.number)),
            "presence_penalty": listed(.presencePenalty, extra.presencePenalty.map(JSONValue.number)),
            "repetition_penalty": listed(.repetitionPenalty, extra.repetitionPenalty.map(JSONValue.number)),
            "min_p": listed(.minP, extra.minP.map(JSONValue.number)),
            "top_a": listed(.topA, extra.topA.map(JSONValue.number)),
            "stop": listed(.stop, extra.stopSequences.map { .array($0.map(JSONValue.string)) }),
            "logit_bias": extra.logitBias.flatMap { bias in
                listed(
                    .logitBias,
                    .object(JSONObject(bias.map { .init(key: String($0.key), value: .number($0.value)) }).sortedByKey()))
            },
            "verbosity": listed(.verbosity, extra.verbosity.map { .string($0.rawValue) }),
            "service_tier": extra.serviceTier.map { .string($0.rawValue) },
            "user": extra.endUserID.map(JSONValue.string),
            "provider": model.routing.json(needsParameters: !allTools.isEmpty || schema != nil),
            "plugins": Self.plugins(for: model.modelIDs, options: extra),
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

    /// The server tools' entries, after the session's tools, or none when tool calls are disallowed.
    ///
    /// - Throws: `LanguageModelError.unsupportedCapability` when there are server tools to send and the model or a
    ///   fallback doesn't take tools.
    private static func serverTools(
        _ serverTools: [OpenRouterServerTool],
        options: GenerationOptions,
        parameters: Set<OpenRouterParameter>
    ) throws -> [JSONValue] {
        guard !serverTools.isEmpty, options.toolCallingMode?.kind != .disallowed else { return [] }
        guard parameters.contains(.tools) else {
            let description = "The model or one of its fallbacks doesn't take tools, so it can't call server tools."
            throw LanguageModelError.unsupportedCapability(.init(capability: .toolCalling, debugDescription: description))
        }
        return serverTools.map(\.json)
    }

    /// Structured outputs when the model takes them, otherwise JSON mode, with the schema in the prompt.
    ///
    /// Anthropic's structured outputs reject constraints such as `minimum`, `maxItems` and `pattern`, and OpenRouter
    /// passes the schema on as it is, so for a request that may reach an Anthropic model they move into the
    /// description, as Anthropic's SDKs send them.
    private static func responseFormat(
        _ schema: GenerationSchema?,
        structured: Bool,
        isAnthropic: Bool,
        parameters: Set<OpenRouterParameter>
    ) throws -> JSONValue? {
        guard let schema else { return nil }
        if structured {
            let json = try JSONValue(schema, strict: true)
            return [
                "type": "json_schema",
                "json_schema": ["name": .string(name(of: schema)), "strict": true, "schema": isAnthropic ? json.anthropicSchema : json],
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

    /// OpenRouter's plugins for a request: context compression, then the settings of each router among the models,
    /// once each, in the order the models are tried.
    ///
    /// Context compression is off for every request, so the model sees the whole transcript, and one that doesn't fit
    /// throws `LanguageModelError.contextSizeExceeded`. Otherwise OpenRouter turns it on for hosts with 8,192 tokens of
    /// context or less, which a model listing more can still use, and for accounts that enable it, and it silently
    /// drops the middle of the transcript.
    private static func plugins(for ids: [OpenRouterModelID], options: OpenRouterOptions) -> JSONValue {
        let contextCompression: JSONValue = ["id": "context-compression", "enabled": false]
        var seen: Set<OpenRouterModelID> = []
        let routers = ids.filter { seen.insert($0).inserted }.compactMap { router($0, options: options) }
        return .array([contextCompression] + routers)
    }

    /// The settings of a router model, under the plugin id that router reads, or `nil` for any other model or when
    /// the router has no settings. Each router silently ignores settings under another router's id.
    ///
    /// Routers are matched by id rather than by catalog entry, so a catalog update that retires one doesn't break
    /// the build.
    private static func router(_ id: OpenRouterModelID, options: OpenRouterOptions) -> JSONValue? {
        switch id.rawValue {
        case "openrouter/auto": options.autoRouter?.json(pluginID: "auto-router")
        case "openrouter/auto-beta": options.autoRouter?.json(pluginID: "auto-beta-router")
        case "openrouter/pareto-code": options.minimumCodingScore.map { ["id": "pareto-router", "min_coding_score": .number($0)] }
        default: nil
        }
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
        let limited = JSONObject(members).sortedByKey().members.prefix(MetadataLimit.pairs)
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

extension OpenRouterModelID {
    /// Whether the id names an Anthropic model, or an alias of one, such as `~anthropic/claude-haiku-latest`.
    fileprivate var isAnthropic: Bool {
        rawValue.drop { $0 == "~" }.hasPrefix("anthropic/")
    }
}

extension JSONValue {
    /// The keywords Anthropic's structured outputs take. A `minItems` of 0 or 1 is taken too.
    private static let anthropicKeywords: Set<String> = [
        "$defs", "$ref", "additionalProperties", "allOf", "anyOf", "const", "description", "enum", "items", "properties",
        "required", "title", "type",
    ]

    /// The schema with every keyword Anthropic doesn't take moved into its description, as `{key: value, …}` after a
    /// blank line, so the model still reads the constraint.
    fileprivate var anthropicSchema: JSONValue {
        guard case .object(let schema) = self else { return self }
        var kept = JSONObject()
        var moved: [String] = []
        for member in schema.members {
            switch member.key {
            case "properties", "$defs":
                kept[member.key] = member.value.mappingObject(\.anthropicSchema)
            case "items":
                kept[member.key] = member.value.anthropicSchema
            case "anyOf", "allOf":
                kept[member.key] = member.value.mappingArray(\.anthropicSchema)
            case "minItems" where member.value == 0 || member.value == 1:
                kept[member.key] = member.value
            case let key where Self.anthropicKeywords.contains(key):
                kept[key] = member.value
            default:
                moved.append("\(member.key): \(member.value.text)")
            }
        }
        if !moved.isEmpty {
            let constraints = "{\(moved.joined(separator: ", "))}"
            kept["description"] = .string(kept["description"]?.stringValue.map { "\($0)\n\n\(constraints)" } ?? constraints)
        }
        return .object(kept)
    }

    /// The object with each member's value transformed, or the value unchanged when it isn't an object.
    private func mappingObject(_ transform: (JSONValue) -> JSONValue) -> JSONValue {
        guard case .object(let object) = self else { return self }
        return .object(JSONObject(object.members.map { JSONObject.Member(key: $0.key, value: transform($0.value)) }))
    }

    /// The array with each element transformed, or the value unchanged when it isn't an array.
    private func mappingArray(_ transform: (JSONValue) -> JSONValue) -> JSONValue {
        guard case .array(let elements) = self else { return self }
        return .array(elements.map(transform))
    }
}
