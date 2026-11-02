/// The keys of the metadata facts that only OpenRouter reports about an answer, which start with `openRouter.`, so
/// they never collide with another provider's keys.
///
/// The response or tool-calls entry that ends an answer carries what the response cache did, and the router's report
/// when ``OpenRouterOptions/includesRouterMetadata`` asks for it. The answer's usage carries the parts of its cost,
/// whether the account's own key paid the host, and the server tools' calls. The facts every provider reports, such as
/// the model, the cost and an error's status, use the bare keys of `LanguageModelMetadataKey`. A key is left out when
/// OpenRouter didn't report its value.
///
/// `Transcript.Response.openRouter` and `LanguageModelSession.Usage.openRouter` read a response entry's and a usage's
/// facts, under both kinds of key, as ``OpenRouterResponseMetadata`` and ``OpenRouterUsageMetadata``:
///
/// ```swift
/// let response = try await session.respond(to: "Plan dinner.")
/// let cost = response.usage.openRouter.cost
/// ```
///
/// Saved transcripts keep the keys, so their spellings never change.
public enum OpenRouterMetadataKey {
    /// Whether the ``OpenRouterResponseCache`` served the answer: `true` for an answer it kept from an earlier request,
    /// at no cost, and `false` for a new answer that it now keeps.
    public static let isResponseCacheHit = "openRouter.isResponseCacheHit"

    /// How long the ``OpenRouterResponseCache`` had kept the answer, in seconds, when it served it.
    public static let responseCacheAge = "openRouter.responseCacheAge"

    /// The response id of the answer that the ``OpenRouterResponseCache`` kept and served again, such as `gen-…`.
    ///
    /// The answer's own response id is new for each answer the cache serves.
    public static let responseCacheSourceID = "openRouter.responseCacheSourceID"

    /// How OpenRouter picked the model and host, such as `direct`, `fallback`, `alias`, `auto` or `free`, in the
    /// router's report.
    public static let routingStrategy = "openRouter.routingStrategy"

    /// Which attempt answered, from 1, in the router's report. More than 1 means that earlier hosts or models failed.
    public static let routingAttempt = "openRouter.routingAttempt"

    /// The hosts and models OpenRouter tried, in order, in the router's report.
    ///
    /// Each is a structure with the host's `provider`, the `model` and the HTTP `status` it answered with.
    public static let routingAttempts = "openRouter.routingAttempts"

    /// The endpoints OpenRouter could pick from, in the router's report.
    ///
    /// Each is a structure with the host's `provider`, the `model`, and whether it was `selected`.
    public static let routingEndpoints = "openRouter.routingEndpoints"

    /// The plugins that changed the request or the answer, such as context compression or a guardrail, in the
    /// router's report.
    ///
    /// Each is a structure with the stage's `type`, such as `guardrail`, the plugin's `name`, such as
    /// `content-filter`, and a `summary` of what it did when OpenRouter wrote one.
    public static let routingPipeline = "openRouter.routingPipeline"

    /// The OpenRouter edge region that handled the request, such as `iad`, in the router's report.
    public static let region = "openRouter.region"

    /// How long the host took, in seconds, from OpenRouter sending it the request until its answer ended, in the
    /// router's report.
    ///
    /// The output tokens divided by it give the host's throughput.
    public static let generationTime = "openRouter.generationTime"

    /// Whether the request used the account's own key for the host, rather than OpenRouter's, so the host billed that
    /// key.
    ///
    /// When it's `true`, the answer's cost is only OpenRouter's fee, and the host bills the account's own key for
    /// ``upstreamInferenceCost``.
    public static let isBYOK = "openRouter.isBYOK"

    /// What the host charged for the answer, in US dollars, when OpenRouter reports it, as for a request that used the
    /// account's own key.
    public static let upstreamInferenceCost = "openRouter.upstreamInferenceCost"

    /// The part of the host's charge for the prompt, in US dollars.
    public static let upstreamInferencePromptCost = "openRouter.upstreamInferencePromptCost"

    /// The part of the host's charge for the output, in US dollars.
    public static let upstreamInferenceCompletionCost = "openRouter.upstreamInferenceCompletionCost"

    /// What server tools that are billed by use cost, in US dollars, such as the time a sandbox ran; 0 when they ran
    /// for free.
    public static let serverToolCost = "openRouter.serverToolCost"

    /// The server-tool calls the model asked for, of every kind, such as ``OpenRouterServerTool`` web searches and
    /// fetches. A host's own web search isn't counted.
    ///
    /// The shared web search count also counts a search by ``OpenRouterServerTool``, so don't add the two together.
    public static let requestedServerToolCallCount = "openRouter.requestedServerToolCallCount"

    /// The server-tool calls that ran and gave the model a result.
    public static let executedServerToolCallCount = "openRouter.executedServerToolCallCount"
}
