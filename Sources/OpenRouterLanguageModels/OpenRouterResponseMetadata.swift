public import FoundationModels

/// What OpenRouter reported about an answer, read from the metadata of its response entry, or about a request that
/// ended in tool calls, read from its first call.
///
/// `Transcript.Response.openRouter` and `Transcript.ToolCalls.openRouter` read it. The response entry that ends an
/// answer carries the facts, and one that tool calls follow carries only the ``citations``. A fact OpenRouter didn't report is `nil`, and a list it didn't
/// report is empty:
///
/// ```swift
/// let response = try await session.respond(to: "Plan dinner.")
/// if case .response(let answer)? = response.transcriptEntries.last {
///     print("\(answer.openRouter.provider ?? "A host") answered.")
///     if answer.openRouter.finishReason == .length {
///         print("The answer was cut short at its token limit.")
///     }
/// }
/// ```
///
/// Each fact comes from an ``OpenRouterMetadataKey`` key, such as ``isResponseCacheHit`` from
/// ``OpenRouterMetadataKey/responseCacheHit``. The keys of ``model``, ``provider``, ``responseID``, ``finishReason``,
/// ``serviceTier`` and ``citations`` are shared, so another language model's answer reads too, in that model's own
/// words. The routing facts come from the router's report, which ``OpenRouterOptions/includesRouterMetadata`` asks for.
public struct OpenRouterResponseMetadata: Sendable, Hashable {
    /// The model that answered, which can differ from the one asked for when OpenRouter routes the request or a
    /// fallback answers. The request is billed at this model's price.
    public let model: OpenRouterModelID?

    /// The host that served the answer, such as `Anthropic`, as an ``OpenRouterProviderName`` raw value.
    ///
    /// OpenRouter calls the hosts that serve its models providers, and the name keeps OpenRouter's word: it names the
    /// host, never OpenRouter itself.
    public let provider: String?

    /// OpenRouter's id for the answer, such as `gen-…`, which its generation statistics are looked up by.
    public let responseID: String?

    /// Why the answer ended, such as ``OpenRouterFinishReason/length`` when it reached its token limit.
    ///
    /// An answer cut off at its token limit doesn't throw, so its reason is the way to tell.
    public let finishReason: OpenRouterFinishReason?

    /// The processing tier that served the answer, which it's billed at.
    ///
    /// It can differ from ``OpenRouterOptions/serviceTier``, such as ``OpenRouterServiceTier/priority`` for a request
    /// that asked for ``OpenRouterServiceTier/ultrafast`` from a model without that tier.
    public let serviceTier: OpenRouterServiceTier?

    /// The web pages the answer cites, in the order OpenRouter listed them, from the ``OpenRouterServerTool`` web
    /// search.
    ///
    /// Citations point into the answer's text, so they're on the response entry even when tool calls end the answer.
    public let citations: [OpenRouterCitation]

    /// Whether the ``OpenRouterResponseCache`` served the answer: `true` for an answer it kept from an earlier request,
    /// at no cost, `false` for a new answer that it now keeps, and `nil` when the cache is off.
    public let isResponseCacheHit: Bool?

    /// How long the ``OpenRouterResponseCache`` had kept the answer when it served it, to the second.
    public let responseCacheAge: Duration?

    /// The response id of the answer that the ``OpenRouterResponseCache`` kept and served again, such as `gen-…`.
    ///
    /// The answer's own ``responseID`` is new for each answer the cache serves.
    public let responseCacheSourceID: String?

    /// How OpenRouter picked the model and host, such as `direct`, `fallback`, `alias`, `auto` or `free`.
    public let routingStrategy: String?

    /// Which attempt answered, from 1. More than 1 means that earlier hosts or models failed.
    public let routingAttempt: Int?

    /// The hosts and models OpenRouter tried, in order.
    public let routingAttempts: [Attempt]

    /// The endpoints OpenRouter could pick from.
    public let routingEndpoints: [Endpoint]

    /// The plugins that changed the request or the answer, such as context compression or a guardrail.
    public let routingPipeline: [PipelineStage]

    /// The OpenRouter edge region that handled the request, such as `iad`.
    public let region: String?

    /// How long the host took, from OpenRouter sending it the request until its answer ended.
    ///
    /// The output tokens divided by it give the host's throughput.
    public let generationTime: Duration?

    /// What OpenRouter reported about the request's cost and counts, such as its cost in US dollars.
    ///
    /// A response's own `usage` has only its last request's facts, so a response whose tool calls ran reads each
    /// earlier request's here, on the tool calls it asked for. Adding up the ``OpenRouterUsageMetadata/cost`` of each
    /// entry that ends a request gives what the whole response cost.
    public let usage: OpenRouterUsageMetadata

    /// The facts in a response entry's metadata.
    init(_ metadata: [String: GeneratedContent]) {
        let values = MetadataValues(metadata)
        model = values.string(OpenRouterMetadataKey.model).map(OpenRouterModelID.init(rawValue:))
        provider = values.string(OpenRouterMetadataKey.provider)
        responseID = values.string(OpenRouterMetadataKey.responseID)
        finishReason = values.string(OpenRouterMetadataKey.finishReason).map(OpenRouterFinishReason.init(rawValue:))
        serviceTier = values.string(OpenRouterMetadataKey.serviceTier).map(OpenRouterServiceTier.init(rawValue:))
        citations = values.array(OpenRouterMetadataKey.citations).compactMap(OpenRouterCitation.init(metadataValue:))
        isResponseCacheHit = values.bool(OpenRouterMetadataKey.responseCacheHit)
        responseCacheAge = values.duration(OpenRouterMetadataKey.responseCacheAge)
        responseCacheSourceID = values.string(OpenRouterMetadataKey.responseCacheSourceID)
        routingStrategy = values.string(OpenRouterMetadataKey.routingStrategy)
        routingAttempt = values.integer(OpenRouterMetadataKey.routingAttempt)
        routingAttempts = values.structures(OpenRouterMetadataKey.routingAttempts).map(Attempt.init)
        routingEndpoints = values.structures(OpenRouterMetadataKey.routingEndpoints).map(Endpoint.init)
        routingPipeline = values.structures(OpenRouterMetadataKey.routingPipeline).map(PipelineStage.init)
        region = values.string(OpenRouterMetadataKey.region)
        generationTime = values.duration(OpenRouterMetadataKey.generationTime)
        usage = OpenRouterUsageMetadata(metadata)
    }
}

extension OpenRouterResponseMetadata {
    /// A host and model that OpenRouter tried, in the router's report.
    public struct Attempt: Sendable, Hashable {
        /// The host, such as `Anthropic`, as an ``OpenRouterProviderName`` raw value.
        public let provider: String?

        /// The model asked of the host.
        public let model: OpenRouterModelID?

        /// The HTTP status the host answered with, such as 503 for a host that was down.
        public let status: Int?

        fileprivate init(_ values: MetadataValues) {
            provider = values.string(Field.provider)
            model = values.string(Field.model).map(OpenRouterModelID.init(rawValue:))
            status = values.integer(Field.status)
        }
    }

    /// An endpoint that OpenRouter could pick from, in the router's report.
    public struct Endpoint: Sendable, Hashable {
        /// The host, such as `Anthropic`, as an ``OpenRouterProviderName`` raw value.
        public let provider: String?

        /// The model the host serves.
        public let model: OpenRouterModelID?

        /// Whether OpenRouter picked the endpoint.
        public let isSelected: Bool?

        fileprivate init(_ values: MetadataValues) {
            provider = values.string(Field.provider)
            model = values.string(Field.model).map(OpenRouterModelID.init(rawValue:))
            isSelected = values.bool(Field.selected)
        }
    }

    /// A plugin that changed the request or the answer, in the router's report.
    public struct PipelineStage: Sendable, Hashable {
        /// The stage, such as `guardrail`.
        public let type: String?

        /// The plugin, such as `content-filter`.
        public let name: String?

        /// What the plugin did, when OpenRouter wrote it down.
        public let summary: String?

        fileprivate init(_ values: MetadataValues) {
            type = values.string(Field.type)
            name = values.string(Field.name)
            summary = values.string(Field.summary)
        }
    }
}

extension Transcript.Response {
    /// What OpenRouter reported about the answer, such as the model and host that served it and why it ended.
    public var openRouter: OpenRouterResponseMetadata {
        OpenRouterResponseMetadata(metadata)
    }
}

extension Transcript.ToolCalls {
    /// What OpenRouter reported about the request that asked for these tool calls, such as the model and host that
    /// served it.
    ///
    /// Foundation Models keeps no readable metadata on the tool-calls entry itself, so the request's facts sit on its
    /// first call, and this reads them from there. A request that asked for several calls has one set of facts.
    public var openRouter: OpenRouterResponseMetadata {
        OpenRouterResponseMetadata(first?.metadata ?? [:])
    }
}

extension ChatCompletionChunk.RouterMetadata {
    /// The router's report as metadata of the entry that ends the answer, with the generation time in seconds.
    var metadata: [String: any ConvertibleToGeneratedContent] {
        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[OpenRouterMetadataKey.routingStrategy] = strategy
        metadata[OpenRouterMetadataKey.routingAttempt] = attempt
        metadata[OpenRouterMetadataKey.routingAttempts] = attempts?.map { attempt in
            GeneratedContent(properties: [Field.provider: attempt.provider, Field.model: attempt.model, Field.status: attempt.status])
        }
        metadata[OpenRouterMetadataKey.routingEndpoints] = endpoints?.available?.map { endpoint in
            GeneratedContent(properties: [
                Field.provider: endpoint.provider, Field.model: endpoint.model, Field.selected: endpoint.selected,
            ])
        }
        metadata[OpenRouterMetadataKey.routingPipeline] = pipeline?.map { stage in
            GeneratedContent(properties: [Field.type: stage.type, Field.name: stage.name, Field.summary: stage.summary])
        }
        metadata[OpenRouterMetadataKey.region] = region
        metadata[OpenRouterMetadataKey.generationTime] = generationTime.map { $0 / 1_000 }
        return metadata
    }
}

extension MetadataValues {
    /// The structures in a list, skipping any element that isn't one.
    fileprivate func structures(_ key: String) -> [MetadataValues] {
        array(key).compactMap(MetadataValues.init)
    }
}

/// The names of the fields of the router report's structures in an entry's metadata.
private enum Field {
    static let provider = "provider"
    static let model = "model"
    static let status = "status"
    static let selected = "selected"
    static let type = "type"
    static let name = "name"
    static let summary = "summary"
}
