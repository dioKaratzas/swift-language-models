/// The keys of the metadata an OpenRouter answer carries in a Foundation Models session.
///
/// The response or tool-calls entry that ends an answer carries facts about the answer: the model, host, generation
/// id, finish reason and service tier, what the response cache did, and the router's report when
/// ``OpenRouterOptions/includesRouterMetadata`` asks for it. The response entry also carries the pages a web search
/// found that the answer cites. The answer's usage carries what it cost and counted: the cost and its parts, whether
/// the account's own key paid the host, the cache write tokens and the server tools' calls. A key is left out when
/// OpenRouter didn't report its value:
///
/// ```swift
/// let response = try await session.respond(to: "Plan dinner.")
/// let cost = response.usage.metadata[OpenRouterMetadataKey.cost]
/// ```
public enum OpenRouterMetadataKey {
    /// The model that answered, such as `anthropic/claude-sonnet-4.6`, which can differ from the one asked for when
    /// OpenRouter routes the request or a fallback answers.
    ///
    /// The request is billed at this model's price. The answer's reasoning entry carries it too, so the reasoning goes
    /// back on later turns only when the model that wrote it isn't a fallback.
    public static let model = "model"

    /// The host that served the answer, such as `Anthropic`.
    public static let provider = "provider"

    /// OpenRouter's id for the answer, such as `gen-…`, for looking up its statistics later.
    public static let generationID = "generationID"

    /// Why the answer ended, as OpenRouter's `finish_reason` names it: `stop` when the model finished, `tool_calls`
    /// when it called tools, or `length` when it reached its token limit and its text is cut short.
    public static let finishReason = "finishReason"

    /// The processing tier that served the answer, as an ``OpenRouterServiceTier`` raw value such as `default`, `flex`
    /// or `priority`, which the answer is billed at.
    ///
    /// It can differ from ``OpenRouterOptions/serviceTier``, such as `priority` for a request that asked for
    /// `ultrafast` from a model without that tier.
    public static let serviceTier = "serviceTier"

    /// Whether the ``OpenRouterResponseCache`` served the answer: `true` for an answer it kept from an earlier request,
    /// at no cost, and `false` for a new answer that it now keeps.
    public static let responseCacheHit = "responseCacheHit"

    /// How long the ``OpenRouterResponseCache`` had kept the answer, in seconds, when it served it.
    public static let responseCacheAge = "responseCacheAge"

    /// The generation id of the answer that the ``OpenRouterResponseCache`` kept and served again, such as `gen-…`.
    ///
    /// The answer's own ``generationID`` is new for each answer the cache serves.
    public static let responseCacheSourceID = "responseCacheSourceID"

    /// How OpenRouter picked the model and host, such as `direct`, `fallback`, `alias`, `auto` or `free`, in the
    /// router's report.
    public static let routingStrategy = "routingStrategy"

    /// Which attempt answered, from 1, in the router's report. More than 1 means that earlier hosts or models failed.
    public static let routingAttempt = "routingAttempt"

    /// The hosts and models OpenRouter tried, in order, in the router's report.
    ///
    /// Each is a structure with the host's `provider`, the `model` and the HTTP `status` it answered with.
    public static let routingAttempts = "routingAttempts"

    /// The endpoints OpenRouter could pick from, in the router's report.
    ///
    /// Each is a structure with the host's `provider`, the `model`, and whether it was `selected`.
    public static let routingEndpoints = "routingEndpoints"

    /// The plugins that changed the request or the answer, such as context compression or a guardrail, in the
    /// router's report.
    ///
    /// Each is a structure with the stage's `type`, such as `guardrail`, the plugin's `name`, such as
    /// `content-filter`, and a `summary` of what it did when OpenRouter wrote one.
    public static let routingPipeline = "routingPipeline"

    /// The OpenRouter edge region that handled the request, such as `iad`, in the router's report.
    public static let region = "region"

    /// How long the host took, in seconds, from OpenRouter sending it the request until its answer ended, in the
    /// router's report.
    ///
    /// The output tokens divided by it give the host's throughput.
    public static let generationTime = "generationTime"

    /// The web pages the answer cites, on its response entry, when the ``OpenRouterServerTool`` web search found them.
    ///
    /// Each is a structure with the page's `url`, and its `title`, `excerpt`, `startIndex` and `endIndex` when known.
    /// `Transcript.Response.openRouterCitations` reads them as ``OpenRouterCitation`` values.
    public static let citations = "citations"

    /// What the answer cost, in US dollars, from the account's OpenRouter credits.
    ///
    /// When ``isBYOK`` is `true`, it's only OpenRouter's fee, and the host bills the account's own key for
    /// ``upstreamInferenceCost``.
    public static let cost = "cost"

    /// The prompt tokens written to the host's prompt cache.
    public static let cacheWriteTokenCount = "cacheWriteTokenCount"

    /// Whether the request used the account's own key for the host, rather than OpenRouter's, so the host billed that
    /// key.
    public static let isBYOK = "isBYOK"

    /// What the host charged for the answer, in US dollars, when OpenRouter reports it, as for a request that used the
    /// account's own key.
    public static let upstreamInferenceCost = "upstreamInferenceCost"

    /// The part of the host's charge for the prompt, in US dollars.
    public static let upstreamInferencePromptCost = "upstreamInferencePromptCost"

    /// The part of the host's charge for the output, in US dollars.
    public static let upstreamInferenceCompletionCost = "upstreamInferenceCompletionCost"

    /// What server tools that are billed by use cost, in US dollars, such as the time a sandbox ran; 0 when they ran
    /// for free.
    public static let serverToolCost = "serverToolCost"

    /// The server-tool calls the model asked for, of every kind, such as ``OpenRouterServerTool`` web searches and
    /// fetches. A host's own web search isn't counted.
    public static let requestedServerToolCallCount = "requestedServerToolCallCount"

    /// The server-tool calls that ran and gave the model a result.
    public static let executedServerToolCallCount = "executedServerToolCallCount"

    /// The web searches that ran, by ``OpenRouterServerTool`` or by the host's own search.
    ///
    /// A search by ``OpenRouterServerTool`` also counts in ``requestedServerToolCallCount``, so don't add the two
    /// together.
    public static let webSearchCount = "webSearchCount"
}
