/// The keys of the metadata that an OpenRouter answer, or an error it ends in, carries in a Foundation Models session.
///
/// The response or tool-calls entry that ends an answer carries facts about the answer: the model, host, response id,
/// finish reason and service tier, what the response cache did, and the router's report when
/// ``OpenRouterOptions/includesRouterMetadata`` asks for it. The response entry also carries the pages a web search
/// found that the answer cites. The answer's usage carries what it cost and counted: the cost and its parts, whether
/// the account's own key paid the host, the cache write tokens and the server tools' calls. A `LanguageModelError`
/// that an OpenRouter failure becomes carries the HTTP status, OpenRouter's error code and the host that failed. A key
/// is left out when OpenRouter didn't report its value.
///
/// `Transcript.Response.openRouter` and `LanguageModelSession.Usage.openRouter` read the values of a response entry and
/// a usage as ``OpenRouterResponseMetadata`` and ``OpenRouterUsageMetadata``, with a property for each key:
///
/// ```swift
/// let response = try await session.respond(to: "Plan dinner.")
/// let cost = response.usage.openRouter.cost
/// ```
///
/// Each key is one of two kinds, and its documentation says which:
///
/// - A shared key names a fact that every model's answers have, such as the model or the cost. It has no prefix, and
///   every language model in this package spells it the same way, so code that reads it works with any of them.
/// - An OpenRouter key names a fact that only OpenRouter reports, such as its routing report. It starts with
///   `openRouter.`, so it never collides with another language model's keys.
///
/// Saved transcripts keep the keys, so their spellings never change.
public enum OpenRouterMetadataKey {
    /// The model that answered, such as `anthropic/claude-sonnet-4.6`, which can differ from the one asked for when
    /// OpenRouter routes the request or a fallback answers.
    ///
    /// The request is billed at this model's price. The answer's reasoning entry carries it too, so the reasoning goes
    /// back on later turns only when the model that wrote it isn't a fallback. A shared key.
    public static let model = "model"

    /// The host that served the answer, such as `Anthropic`, as an ``OpenRouterProviderName`` raw value. On the
    /// metadata of a `LanguageModelError`, the host that failed, when OpenRouter names one.
    ///
    /// OpenRouter calls the companies that serve its models, such as Anthropic or Together, providers, and the key
    /// keeps OpenRouter's word: it names the host, never OpenRouter itself. A shared key.
    public static let provider = "provider"

    /// OpenRouter's id for the answer, such as `gen-…`, which its generation statistics are looked up by. A shared key.
    public static let responseID = "responseID"

    /// Why the answer ended, as OpenRouter's `finish_reason` names it: `stop` when the model finished, `tool_calls`
    /// when it called tools, or `length` when it reached its token limit and its text is cut short.
    ///
    /// ``OpenRouterResponseMetadata/finishReason`` reads it as an ``OpenRouterFinishReason``. A shared key.
    public static let finishReason = "finishReason"

    /// The processing tier that served the answer, as an ``OpenRouterServiceTier`` raw value such as `default`, `flex`
    /// or `priority`, which the answer is billed at.
    ///
    /// It can differ from ``OpenRouterOptions/serviceTier``, such as `priority` for a request that asked for
    /// `ultrafast` from a model without that tier. A shared key.
    public static let serviceTier = "serviceTier"

    /// Whether the ``OpenRouterResponseCache`` served the answer: `true` for an answer it kept from an earlier request,
    /// at no cost, and `false` for a new answer that it now keeps. An OpenRouter key.
    public static let responseCacheHit = "openRouter.responseCacheHit"

    /// How long the ``OpenRouterResponseCache`` had kept the answer, in seconds, when it served it. An OpenRouter key.
    public static let responseCacheAge = "openRouter.responseCacheAge"

    /// The response id of the answer that the ``OpenRouterResponseCache`` kept and served again, such as `gen-…`.
    ///
    /// The answer's own ``responseID`` is new for each answer the cache serves. An OpenRouter key.
    public static let responseCacheSourceID = "openRouter.responseCacheSourceID"

    /// How OpenRouter picked the model and host, such as `direct`, `fallback`, `alias`, `auto` or `free`, in the
    /// router's report. An OpenRouter key.
    public static let routingStrategy = "openRouter.routingStrategy"

    /// Which attempt answered, from 1, in the router's report. More than 1 means that earlier hosts or models failed.
    /// An OpenRouter key.
    public static let routingAttempt = "openRouter.routingAttempt"

    /// The hosts and models OpenRouter tried, in order, in the router's report.
    ///
    /// Each is a structure with the host's `provider`, the `model` and the HTTP `status` it answered with. An
    /// OpenRouter key.
    public static let routingAttempts = "openRouter.routingAttempts"

    /// The endpoints OpenRouter could pick from, in the router's report.
    ///
    /// Each is a structure with the host's `provider`, the `model`, and whether it was `selected`. An OpenRouter key.
    public static let routingEndpoints = "openRouter.routingEndpoints"

    /// The plugins that changed the request or the answer, such as context compression or a guardrail, in the
    /// router's report.
    ///
    /// Each is a structure with the stage's `type`, such as `guardrail`, the plugin's `name`, such as
    /// `content-filter`, and a `summary` of what it did when OpenRouter wrote one. An OpenRouter key.
    public static let routingPipeline = "openRouter.routingPipeline"

    /// The OpenRouter edge region that handled the request, such as `iad`, in the router's report. An OpenRouter key.
    public static let region = "openRouter.region"

    /// How long the host took, in seconds, from OpenRouter sending it the request until its answer ended, in the
    /// router's report.
    ///
    /// The output tokens divided by it give the host's throughput. An OpenRouter key.
    public static let generationTime = "openRouter.generationTime"

    /// The web pages the answer cites, on its response entry, when the ``OpenRouterServerTool`` web search found them.
    ///
    /// Each is a structure with the page's `url`, and its `title`, `excerpt`, `startIndex` and `endIndex` when known.
    /// ``OpenRouterResponseMetadata/citations`` reads them as ``OpenRouterCitation`` values. A shared key.
    public static let citations = "citations"

    /// What the answer cost, in US dollars, from the account's OpenRouter credits.
    ///
    /// When ``isBYOK`` is `true`, it's only OpenRouter's fee, and the host bills the account's own key for
    /// ``upstreamInferenceCost``. A shared key.
    public static let cost = "cost"

    /// The prompt tokens written to the host's prompt cache. A shared key.
    public static let cacheWriteTokenCount = "cacheWriteTokenCount"

    /// Whether the request used the account's own key for the host, rather than OpenRouter's, so the host billed that
    /// key. An OpenRouter key.
    public static let isBYOK = "openRouter.isBYOK"

    /// What the host charged for the answer, in US dollars, when OpenRouter reports it, as for a request that used the
    /// account's own key. An OpenRouter key.
    public static let upstreamInferenceCost = "openRouter.upstreamInferenceCost"

    /// The part of the host's charge for the prompt, in US dollars. An OpenRouter key.
    public static let upstreamInferencePromptCost = "openRouter.upstreamInferencePromptCost"

    /// The part of the host's charge for the output, in US dollars. An OpenRouter key.
    public static let upstreamInferenceCompletionCost = "openRouter.upstreamInferenceCompletionCost"

    /// What server tools that are billed by use cost, in US dollars, such as the time a sandbox ran; 0 when they ran
    /// for free. An OpenRouter key.
    public static let serverToolCost = "openRouter.serverToolCost"

    /// The server-tool calls the model asked for, of every kind, such as ``OpenRouterServerTool`` web searches and
    /// fetches. A host's own web search isn't counted. An OpenRouter key.
    public static let requestedServerToolCallCount = "openRouter.requestedServerToolCallCount"

    /// The server-tool calls that ran and gave the model a result. An OpenRouter key.
    public static let executedServerToolCallCount = "openRouter.executedServerToolCallCount"

    /// The web searches that ran, by ``OpenRouterServerTool`` or by the host's own search.
    ///
    /// A search by ``OpenRouterServerTool`` also counts in ``requestedServerToolCallCount``, so don't add the two
    /// together. An OpenRouter key.
    public static let webSearchCount = "openRouter.webSearchCount"

    /// The HTTP status of the failed request, on the metadata of a `LanguageModelError`, such as 429 for a rate limit.
    ///
    /// An error in a stream arrives after HTTP 200, so it has the status its code names, and none when its code isn't
    /// a number. A shared key.
    public static let status = "status"

    /// OpenRouter's code for the failure, as an ``OpenRouterError/Code`` raw value such as `rate_limit_exceeded`, on the
    /// metadata of a `LanguageModelError`. An OpenRouter key.
    public static let errorCode = "openRouter.errorCode"
}
