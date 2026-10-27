import Foundation
import FoundationModels
import LanguageModels

/// The body of OpenRouter's `POST /chat/completions` for one Foundation Models request, and the headers that go with
/// it.
///
/// The body names the model and lists its fallbacks after it. Any of them may answer, so a setting is sent only when
/// each of them lists its parameter, and a host never sees a parameter its model doesn't take. Every part is written
/// the same way each time, so a provider's prompt cache stays valid across requests.
struct ChatCompletionRequest {
    let body: JSONValue

    /// The same body with its response schema in portable form, to send instead when a host rejects a constraint of
    /// the full schema, or `nil` when the request has no strict schema or already sends the portable one.
    let portableSchemaBody: JSONValue?

    /// The response cache's settings, the session id while the cache is on, and the request for router metadata.
    let headers: [String: String]

    /// What the request leaves out or changes from what the app asked for, so that its models and OpenRouter take it.
    let adjustments: [RequestAdjustment]

    /// The request for a model and its fallbacks.
    ///
    /// - Parameters:
    ///   - request: What Foundation Models asks for.
    ///   - model: The model, its fallbacks and its settings.
    ///   - details: The model's details narrowed to what each fallback also supports.
    /// - Throws: `LanguageModelError` when the models can't take the transcript or the tools, and an encoding error
    ///   when the response schema can't be encoded.
    init<Effort>(
        _ request: LanguageModelExecutorGenerationRequest,
        model: OpenRouterLanguageModel<Effort>,
        details: OpenRouterModel<ContextOptions.ReasoningLevel>
    ) throws {
        var listed = ListedParameters(details.supportedParameters)
        let schema = request.schema
        let usesStructuredOutputs = schema != nil && listed.contains(.structuredOutputs)
        let messages = try ChatMessages(
            request.transcript,
            cacheControl: model.cacheControl,
            attachmentInputs: details.attachmentInputs(pdfEngine: model.options.pdfEngine),
            replaysReasoning: model.replaysReasoning(writtenBy:),
            // Without structured outputs, the prompt is the only place the model learns the schema.
            requiredSchema: usesStructuredOutputs ? nil : schema,
            schemaInstructions: Self.instructions(for:)
        )

        let options = request.generationOptions
        let sessionTools = try Self.sessionTools(request, parameters: listed.parameters)
        let tools = (sessionTools ?? []) + (try Self.serverTools(model.serverTools, options: options, parameters: listed.parameters))
        let sampling = Sampling(options, parameters: listed.parameters)
        let openRouterOptions = model.options
        let sessionID = Self.sessionID(of: request.transcript)
        // Anthropic documents the constraints its structured outputs reject, so a request that may reach it sends the
        // portable schema from the start. Other hosts get the full schema, and the portable one only if they reject it.
        let sendsPortableSchema = model.modelIDs.contains(where: \.isAnthropic)
        let reasoning = Self.reasoning(request.contextOptions.reasoningLevel, details: details)
        let tokenLimit = Self.tokenLimit(requested: options.maximumResponseTokens, modelLimit: details.maximumOutputTokens)
        let metadata = Self.metadata(request.metadata)
        let generation: JSONObject = [
            "model": .string(model.routing.modelID(for: model.details.id)),
            "models": model.fallbacks.isEmpty ? nil : .array(model.fallbacks.map { .string(model.routing.modelID(for: $0.id)) }),
            "messages": .array(messages.messages),
            "modalities": Self.modalities(details.outputModalities, schema: schema),
            "stream": true,
            "tools": tools.isEmpty ? nil : .array(tools),
            // The tool choice and parallel calls concern only the session's tools.
            "tool_choice": sessionTools == nil ? nil : listed.value(of: .toolChoice, Self.toolChoice(options.toolCallingMode)),
            "parallel_tool_calls": sessionTools == nil || !listed.contains(.parallelToolCalls) ? nil : true,
            "response_format": try Self.responseFormat(
                schema, structured: usesStructuredOutputs, portable: sendsPortableSchema, parameters: listed.parameters),
            "reasoning": reasoning.setting,
            "temperature": listed.value(of: .temperature, sampling.temperature.map(JSONValue.number)),
            "top_p": listed.value(of: .topP, sampling.topP.map(JSONValue.number)),
            "top_k": listed.value(of: .topK, sampling.topK.map(JSONValue.integer)),
            "seed": listed.value(of: .seed, sampling.seed.map(Sampling.json(seed:))),
            "max_completion_tokens": listed.contains(.maxCompletionTokens) ? tokenLimit : nil,
            "max_tokens": listed.contains(.maxCompletionTokens) ? nil : listed.value(of: .maxTokens, tokenLimit),
        ]
        let handling: JSONObject = [
            "provider": model.routing.json(needsParameters: !tools.isEmpty || schema != nil),
            "plugins": Self.plugins(for: model.modelIDs, options: openRouterOptions, carriesPDF: messages.carriesPDF),
            // The response cache compares the whole body, and the session id differs for every session, so it goes in
            // a header while the cache is on, and new sessions can repeat an earlier request.
            "session_id": model.responseCache == nil ? sessionID.map(JSONValue.string) : nil,
            "metadata": metadata.json,
            "cache_control": model.cacheControl?.json,
        ]
        var body = JSONObject(generation.members + openRouterOptions.json(listedIn: &listed).members + handling.members)
        self.body = .object(body)
        if let schema, usesStructuredOutputs, !sendsPortableSchema {
            body["response_format"] = try Self.jsonSchemaFormat(schema, portable: true)
            portableSchemaBody = .object(body)
        } else {
            portableSchemaBody = nil
        }
        var headers = model.responseCache?.headers(sessionID: sessionID) ?? [:]
        headers["X-OpenRouter-Metadata"] = openRouterOptions.includesRouterMetadata ? "enabled" : nil
        self.headers = headers
        adjustments = [
            listed.unlisted.isEmpty ? nil : .unlistedParameters(listed.unlisted),
            metadata.droppedKeys.isEmpty ? nil : .droppedMetadata(keys: metadata.droppedKeys),
            reasoning.adjustment,
        ].compactMap(\.self)
    }

    /// The session's tools, or `nil` when the request has none or the model doesn't take them.
    ///
    /// Foundation Models sends no tools when tool calling is disallowed, so there's nothing to forbid here.
    ///
    /// - Throws: `LanguageModelError.unsupportedCapability` when tool calls are required and the model or a fallback
    ///   doesn't take `tool_choice`, the only way to require them, since the model could then answer without a call.
    private static func sessionTools(_ request: LanguageModelExecutorGenerationRequest, parameters: Set<OpenRouterParameter>) throws
        -> [JSONValue]?
    {
        guard !request.enabledToolDefinitions.isEmpty, parameters.contains(.tools) else { return nil }
        guard request.generationOptions.toolCallingMode?.kind != .required || parameters.contains(.toolChoice) else {
            let description = "The model or one of its fallbacks doesn't take tool_choice, so it can't be made to call a tool."
            throw LanguageModelError.unsupportedCapability(.init(capability: .toolCalling, debugDescription: description))
        }
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
    private static func responseFormat(
        _ schema: GenerationSchema?,
        structured: Bool,
        portable: Bool,
        parameters: Set<OpenRouterParameter>
    ) throws -> JSONValue? {
        guard let schema else { return nil }
        if structured { return try jsonSchemaFormat(schema, portable: portable) }
        return parameters.contains(.responseFormat) ? ["type": "json_object"] : nil
    }

    /// Structured outputs with a strict schema, in full or in portable form.
    ///
    /// Some hosts reject constraints such as `minimum`, `maxItems` and `pattern`, and OpenRouter passes the schema on
    /// as it is, so the portable form moves them into the description, where the model still reads them.
    private static func jsonSchemaFormat(_ schema: GenerationSchema, portable: Bool) throws -> JSONValue {
        let json = try JSONValue(schema, strict: true)
        return [
            "type": "json_schema",
            "json_schema": ["name": .string(name(of: schema)), "strict": true, "schema": portable ? json.portableSchema : json],
        ]
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
    ///
    /// - Returns: The setting, and the change from the level asked for when the effort sent isn't its own or none is.
    private static func reasoning(
        _ level: ContextOptions.ReasoningLevel?,
        details: OpenRouterModel<some ModelEffort>
    ) -> (setting: JSONValue?, adjustment: RequestAdjustment?) {
        guard let level, details.reasoning != .unsupported else { return (nil, nil) }
        if details.reasoningEfforts.isEmpty {
            let turnsOff = level == .off
            return (turnsOff && details.reasoning == .mandatory ? nil : ["enabled": .bool(!turnsOff)], nil)
        }
        let effort = level.providerEffort(supporting: details.reasoningEfforts)
        var adjustment: RequestAdjustment?
        if let requested = level.effortWord, requested != effort {
            adjustment = .movedEffort(requested: requested, sent: effort)
        }
        return (effort.map { ["effort": .string($0)] }, adjustment)
    }

    /// The most tokens to generate: the number the request asks for, no more than the model's own limit, or `nil` when
    /// the request sets none.
    private static func tokenLimit(requested: Int?, modelLimit: Int?) -> JSONValue? {
        guard let requested else { return nil }
        guard let modelLimit else { return .integer(requested) }
        return .integer(min(requested, modelLimit))
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

    /// The output kinds to ask for: images and text when every model generates images and the request has no schema,
    /// so their images come back as data entries; otherwise none, which means text.
    ///
    /// Before the OS version that has data entries, and in a build with an SDK before Xcode 27.2's, images aren't
    /// asked for, since they couldn't reach the session.
    private static func modalities(_ outputs: Set<OpenRouterOutputModality>, schema: GenerationSchema?) -> JSONValue? {
        #if canImport(FoundationModels, _version: 2.1.14)
        guard #available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *), schema == nil, outputs.contains(.image) else {
            return nil
        }
        return outputs.contains(.text) ? ["image", "text"] : ["image"]
        #else
        return nil
        #endif
    }

    /// OpenRouter's plugins for a request: context compression, then the PDF engine when a message carries a PDF, then
    /// the settings of each router among the models, once each, in the order the models are tried.
    ///
    /// Context compression is off for every request, so the model sees the whole transcript, and one that doesn't fit
    /// throws `LanguageModelError.contextSizeExceeded`. Otherwise OpenRouter turns it on for hosts with 8,192 tokens of
    /// context or less, which a model listing more can still use, and for accounts that enable it, and it silently
    /// drops the middle of the transcript.
    private static func plugins(for ids: [OpenRouterModelID], options: OpenRouterOptions, carriesPDF: Bool) -> JSONValue {
        var plugins: [JSONValue] = [["id": "context-compression", "enabled": false]]
        if carriesPDF, let engine = options.pdfEngine {
            plugins.append(["id": "file-parser", "pdf": ["engine": .string(engine.rawValue)]])
        }
        var seen: Set<OpenRouterModelID> = []
        plugins += ids.filter { seen.insert($0).inserted }.compactMap { router($0, options: options) }
        return .array(plugins)
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
    private static func sessionID(of transcript: Transcript) -> String? {
        for case .prompt(let prompt) in transcript {
            return String(prompt.id.prefix(sessionIDLimit))
        }
        return nil
    }

    /// The request's string metadata, sorted by key, within OpenRouter's limits: 16 pairs, keys up to 64 characters
    /// and values up to 512. Pairs past the limits are left out, since OpenRouter rejects the whole request for them.
    ///
    /// - Returns: The metadata to send, or `nil` when none is left, and the keys of the pairs left out, sorted.
    static func metadata(_ metadata: [String: GeneratedContent]) -> (json: JSONValue?, droppedKeys: [String]) {
        let members = metadata.compactMap { key, value -> JSONObject.Member? in
            guard key.count <= MetadataLimit.keyLength, case .string(let text) = value.kind, text.count <= MetadataLimit.valueLength
            else { return nil }
            return .init(key: key, value: .string(text))
        }
        let limited = JSONObject(members).sortedByKey().members.prefix(MetadataLimit.pairs)
        let keptKeys = Set(limited.map(\.key))
        let droppedKeys = metadata.keys.filter { !keptKeys.contains($0) }.sorted()
        return (limited.isEmpty ? nil : .object(JSONObject(Array(limited))), droppedKeys)
    }
}

extension OpenRouterModelID {
    /// Whether the id names an Anthropic model, or an alias of one, such as `~anthropic/claude-haiku-latest`.
    fileprivate var isAnthropic: Bool {
        rawValue.drop { $0 == "~" }.hasPrefix("anthropic/")
    }
}
