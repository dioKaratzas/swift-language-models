import ChatCompletionsAPI
import Foundation
import FoundationModels
import LanguageModels

/// OpenRouter as a Chat Completions provider: the fallback models, routing, plugins, server tools, session id and
/// cache marks its requests add, the parameters its models list, the headers that authenticate requests and name the
/// app, and the reasoning, images, costs and errors its chunks carry.
///
/// The request executor builds one for each request, from the model and its fallbacks, and hands it to the format's
/// executor, which does the rest.
struct OpenRouterChatCompletions: ChatCompletionsProvider {
    /// The model and its fallbacks.
    let model: OpenRouterLanguageModel<ContextOptions.ReasoningLevel>

    /// The model's details narrowed to what each fallback also supports.
    let details: OpenRouterModel<ContextOptions.ReasoningLevel>

    /// Where requests go and how they name the app.
    let configuration: OpenRouterLanguageModel<ContextOptions.ReasoningLevel>.RequestExecutor.Configuration

    /// - Parameters:
    ///   - model: The model and its fallbacks.
    ///   - details: The model's details narrowed to what each fallback also supports.
    ///   - configuration: Where requests go and how they name the app.
    init<Effort: ModelEffort>(
        model: OpenRouterLanguageModel<Effort>,
        details: OpenRouterModel<ContextOptions.ReasoningLevel>,
        configuration: OpenRouterLanguageModel<Effort>.RequestExecutor.Configuration
    ) {
        self.model = OpenRouterLanguageModel(model)
        self.details = details
        self.configuration = .init(configuration)
    }

    var name: String { "OpenRouter" }

    var baseURL: URL {
        get throws { try API.baseURL(configuration.baseURL) }
    }

    var modelID: String { model.routing.modelID(for: model.details.id) }

    var reasoningOrigin: ReasoningOrigin { .openRouter }

    /// The authentication's headers, then the response cache's settings, the session id while the cache is on, the
    /// request for router metadata, and the app's name, address, categories and visibility.
    func headers(for request: LanguageModelExecutorGenerationRequest) async throws -> [String: String] {
        var headers = model.responseCache?.headers(sessionID: Self.sessionID(of: request)) ?? [:]
        headers[API.Header.routerMetadata] = model.options.includesRouterMetadata ? "enabled" : nil
        let app = configuration.app
        let categories = app.categories.prefix(OpenRouterApp.categoryLimit).map(\.rawValue)
        headers[API.Header.referer] = app.url?.absoluteString
        headers[API.Header.appTitle] = app.name
        headers[API.Header.appCategories] = categories.isEmpty ? nil : categories.joined(separator: ",")
        headers[API.Header.appVisibility] = app.isHidden ? "hidden" : nil
        return try await model.auth.requestHeaders().merging(headers) { $1 }
    }

    /// Adds OpenRouter's members to the body, in the order its requests have always had them, and leaves out each
    /// setting that the model or a fallback doesn't list.
    ///
    /// A model's list holds every parameter any of its hosts takes, so with tools or a schema, when the request asks for
    /// hosts that take all it sends, each setting sent also narrows its hosts.
    ///
    /// - Throws: `LanguageModelError.unsupportedCapability` when tool calls are required and a model doesn't take
    ///   `tool_choice`, when there are server tools and a model doesn't take tools, and for a schema when a model
    ///   doesn't take structured outputs.
    func transformBody(_ body: inout Body, for request: LanguageModelExecutorGenerationRequest) throws {
        let options = model.options
        var members = body.members
        // A model that doesn't take tools gets none of the session's, and requiring a call needs `tool_choice`, the
        // only way to require one.
        let sendsSessionTools = members[Member.tools] != nil && lists(Member.tools)
        if !sendsSessionTools {
            members[Member.tools] = nil
            members[Member.toolChoice] = nil
        } else if request.generationOptions.toolCallingMode?.kind == .required, !lists(Member.toolChoice) {
            let description = "The model or one of its fallbacks doesn't take tool_choice, so it can't be made to call a tool."
            throw LanguageModelError.unsupported(.toolCalling, description)
        }
        // The parallel calls concern only the session's tools.
        members[Member.parallelToolCalls] = sendsSessionTools ? Self.json(options.parallelToolCalls) : nil
        let serverTools = try serverTools(for: request)
        if !serverTools.isEmpty {
            let sessionTools = if case .array(let tools)? = members[Member.tools] { tools } else { [JSONValue]() }
            members[Member.tools] = .array(sessionTools + serverTools)
        }
        if members[Member.responseFormat] != nil, !details.supportedParameters.contains(.structuredOutputs) {
            let description = "The model or one of its fallbacks doesn't take structured outputs, so it can't hold its answer to a schema."
            throw LanguageModelError.unsupported(.guidedGeneration, description)
        }
        // The token limit goes as `max_tokens` to models that don't list `max_completion_tokens`.
        if let limit = members[Member.maxCompletionTokens], !lists(Member.maxCompletionTokens) {
            members[Member.maxCompletionTokens] = nil
            members[Member.maxTokens] = limit
        }
        let needsParameters = members[Member.tools] != nil || request.schema != nil
        let sampling = Sampling(request.generationOptions, temperatureRange: 0...2)
        // A request with tools or a schema needs hosts that take every parameter it sends, so greedy sampling's `top_k`
        // 1 goes only with requests that have neither, to models that list it.
        let greedyTopK = sampling.isGreedy && !needsParameters && lists(Member.topK) ? 1 : nil
        let reasoning = Self.reasoning(request.contextOptions.reasoningLevel, details: details)
        let fallbackIDs = model.fallbacks.map { JSONValue.string(model.routing.modelID(for: $0.id)) }
        members[Member.models] = fallbackIDs.isEmpty ? nil : .array(fallbackIDs)
        members[Member.modalities] = Self.modalities(details.outputModalities, schema: request.schema)
        members[Member.reasoning] = reasoning.setting
        members[Member.topK] = (sampling.topK ?? greedyTopK).map(JSONValue.integer)
        members[Member.frequencyPenalty] = options.frequencyPenalty.map(JSONValue.number)
        members[Member.presencePenalty] = options.presencePenalty.map(JSONValue.number)
        members[Member.repetitionPenalty] = options.repetitionPenalty.map(JSONValue.number)
        members[Member.minP] = options.minP.map(JSONValue.number)
        members[Member.topA] = options.topA.map(JSONValue.number)
        members[Member.stop] = options.stopSequences.map { .array($0.map(JSONValue.string)) }
        members[Member.logitBias] = options.logitBias.map(Self.json(logitBias:))
        members[Member.verbosity] = options.verbosity.map(\.json)
        members[Member.serviceTier] = options.serviceTier.map(\.json)
        members[Member.user] = options.endUserID.map(JSONValue.string)
        members[Member.provider] = model.routing.json(needsParameters: needsParameters)
        members[Member.plugins] = Self.plugins(for: model.modelIDs, options: options, carriesPDF: body.carriesPDF)
        // The response cache compares the whole body, and the session id differs for every session, so it goes in a
        // header while the cache is on, and new sessions can repeat an earlier request.
        members[Member.sessionID] = model.responseCache == nil ? Self.sessionID(of: request).map(JSONValue.string) : nil
        members[Member.cacheControl] = model.requestCacheControl?.json
        body.members = members.ordered(by: Member.order)
        body.leaveOut(Member.listed, unlessListed: lists)
        if let moved = reasoning.movedEffort {
            body.noteMovedEffort(requested: moved.requested, sent: moved.sent)
        }
        // A request that may reach a model whose structured outputs reject constraints sends the portable schema from
        // the start. Other hosts get the full schema, and the portable one only if they reject it. Either way, the
        // model's executor checks the answer against the full schema.
        if model.modelIDs.contains(where: \.rejectsSchemaConstraints) {
            try body.sendPortableSchema()
        }
        // The cache mark on the last instructions caches the tools and instructions before it on the host, for the
        // session's later requests and for another session's that reach the same host.
        if let cacheControl = model.requestCacheControl {
            body.markLastInstructions(with: [Member.cacheControl: cacheControl.json])
        }
    }

    func replays(_ reasoning: Transcript.Reasoning) -> Bool {
        ReasoningOrigin(of: reasoning) == .openRouter && model.replaysReasoning(writtenBy: reasoning.writer)
    }

    /// Whether the model and each fallback list a parameter, which OpenRouter names as the body does.
    private func lists(_ parameter: String) -> Bool {
        details.supportedParameters.contains(OpenRouterParameter(rawValue: parameter))
    }

    /// The server tools' entries, or none when tool calls are disallowed.
    ///
    /// - Throws: `LanguageModelError.unsupportedCapability` when there are server tools to send and the model or a
    ///   fallback doesn't take tools.
    private func serverTools(for request: LanguageModelExecutorGenerationRequest) throws -> [JSONValue] {
        guard !model.serverTools.isEmpty, request.generationOptions.toolCallingMode?.kind != .disallowed else { return [] }
        guard lists(Member.tools) else {
            let description = "The model or one of its fallbacks doesn't take tools, so it can't call server tools."
            throw LanguageModelError.unsupported(.toolCalling, description)
        }
        return model.serverTools.map(\.json)
    }

    /// The session's id: its first prompt's, up to the longest OpenRouter takes, or `nil` before the first prompt.
    private static func sessionID(of request: LanguageModelExecutorGenerationRequest) -> String? {
        request.transcript.firstPromptID.map { String($0.prefix(sessionIDLimit)) }
    }

    /// The longest session id OpenRouter takes.
    private static let sessionIDLimit = 256

    /// The `parallel_tool_calls` value, or `nil` to leave the choice to the host.
    private static func json(_ parallelToolCalls: OpenRouterOptions.ParallelToolCalls) -> JSONValue? {
        switch parallelToolCalls {
        case .automatic: nil
        case .allowed: true
        case .disallowed: false
        }
    }

    /// The logit bias as an object keyed by token id, sorted by key, so it gives the same bytes every time.
    private static func json(logitBias: [Int: Double]) -> JSONValue {
        .object(JSONObject(logitBias.map { .init(key: String($0.key), value: .number($0.value)) }).sortedByKey())
    }

    /// The reasoning setting: the nearest effort the model accepts, or for a model whose effort can't be chosen,
    /// whether to reason at all. `off` turns off the reasoning of a model that can stop reasoning even when `none`
    /// isn't among its efforts; a model that always reasons gets its nearest effort instead.
    ///
    /// - Returns: The setting, and the level asked for with the effort sent, when that effort isn't the level's own or
    ///   none is.
    private static func reasoning(
        _ level: ContextOptions.ReasoningLevel?,
        details: OpenRouterModel<some ModelEffort>
    ) -> (setting: JSONValue?, movedEffort: (requested: String, sent: String?)?) {
        guard let level, details.reasoning.isSupported else { return (nil, nil) }
        let turnsOff = level == .off
        if details.reasoningEfforts.isEmpty {
            return (turnsOff && !details.reasoning.canBeTurnedOff ? nil : ["enabled": .bool(!turnsOff)], nil)
        }
        if turnsOff, details.reasoning.canBeTurnedOff, !details.reasoningEfforts.contains(where: { $0.reasoningLevel == .off }) {
            return (["enabled": false], nil)
        }
        let effort = level.providerEffort(supporting: details.reasoningEfforts)
        let requested = level.effortWord.flatMap { $0 == effort ? nil : $0 }
        return (effort.map { ["effort": .string($0)] }, requested.map { ($0, effort) })
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
        var plugins: [JSONValue] = [["id": OpenRouterPlugin.contextCompression.json, "enabled": false]]
        if carriesPDF, let engine = options.pdfEngine {
            plugins.append(["id": OpenRouterPlugin.fileParser.json, "pdf": ["engine": engine.json]])
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
        switch id {
        case .autoRouter: options.autoRouter?.json(plugin: .autoRouter)
        case .autoBetaRouter: options.autoRouter?.json(plugin: .autoBetaRouter)
        case .paretoCodeRouter: options.paretoRouter?.json
        default: nil
        }
    }
}

extension OpenRouterChatCompletions {
    /// The keys of the body's members, and the order OpenRouter's requests have always sent them in, which a host's
    /// prompt cache and OpenRouter's response cache depend on.
    enum Member {
        static let model = "model"
        static let models = "models"
        static let messages = "messages"
        static let modalities = "modalities"
        static let stream = "stream"
        static let tools = "tools"
        static let toolChoice = "tool_choice"
        static let parallelToolCalls = "parallel_tool_calls"
        static let responseFormat = "response_format"
        static let reasoning = "reasoning"
        static let reasoningDetails = "reasoning_details"
        static let temperature = "temperature"
        static let topP = "top_p"
        static let topK = "top_k"
        static let seed = "seed"
        static let maxCompletionTokens = "max_completion_tokens"
        static let maxTokens = "max_tokens"
        static let frequencyPenalty = "frequency_penalty"
        static let presencePenalty = "presence_penalty"
        static let repetitionPenalty = "repetition_penalty"
        static let minP = "min_p"
        static let topA = "top_a"
        static let stop = "stop"
        static let logitBias = "logit_bias"
        static let verbosity = "verbosity"
        static let serviceTier = "service_tier"
        static let user = "user"
        static let provider = "provider"
        static let plugins = "plugins"
        static let sessionID = "session_id"
        static let metadata = "metadata"
        static let cacheControl = "cache_control"

        /// The order of the body's members.
        static let order = [
            model, models, messages, modalities, stream, tools, toolChoice, parallelToolCalls, responseFormat, reasoning, temperature,
            topP, topK, seed, maxCompletionTokens, maxTokens, frequencyPenalty, presencePenalty, repetitionPenalty, minP, topA, stop,
            logitBias, verbosity, serviceTier, user, provider, plugins, sessionID, metadata, cacheControl,
        ]

        /// The members that go out only when the model and each fallback list them.
        static let listed: Set<String> = [
            toolChoice, parallelToolCalls, temperature, topP, topK, seed, maxTokens, frequencyPenalty, presencePenalty,
            repetitionPenalty, minP, topA, stop, logitBias, verbosity,
        ]
    }
}

extension OpenRouterModelID {
    /// The router models that take settings.
    fileprivate static let autoRouter: Self = "openrouter/auto"
    fileprivate static let autoBetaRouter: Self = "openrouter/auto-beta"
    fileprivate static let paretoCodeRouter: Self = "openrouter/pareto-code"
}

extension OpenRouterLanguageModel.RequestExecutor {
    /// Sends one request to OpenRouter through the Chat Completions format and streams its answer.
    ///
    /// The request executor calls this with Foundation Models' request and gets Foundation Models' answer back, so
    /// moving OpenRouter to another format replaces only this folder.
    func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: OpenRouterLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws -> DetailedLanguageModelAnswer {
        let provider = OpenRouterChatCompletions(model: model, details: model.sharedDetails, configuration: configuration)
        let executor = ChatCompletionsExecutor(
            provider, session: model.session, idleTimeout: configuration.idleTimeout, retryDelay: configuration.retryDelay)
        return try await executor.respond(to: request, streamingInto: channel)
    }
}
