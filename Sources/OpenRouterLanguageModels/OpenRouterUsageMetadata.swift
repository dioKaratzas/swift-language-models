public import Foundation
public import FoundationModels

/// What OpenRouter reported about an answer's cost and counts, read from its usage's metadata.
///
/// `LanguageModelSession.Usage.openRouter` reads it. Amounts are in US dollars, as `Decimal` values without binary
/// rounding noise, such as exactly `0.000012345` rather than `0.000012344999…`, and a fact OpenRouter didn't report is
/// `nil`:
///
/// ```swift
/// let response = try await session.respond(to: "Plan dinner.")
/// if let cost = response.usage.openRouter.cost {
///     print("It cost $\(cost).")
/// }
/// ```
///
/// The facts are those of one request. A response whose tool calls ran has the last request's, and a session's own
/// `usage`, which adds up the token counts, keeps no metadata, so its facts are all `nil`. Each request's facts are
/// also on the transcript entry that ends it, which ``OpenRouterResponseMetadata/usage`` reads, so adding up their
/// costs gives what a response with tool calls cost:
///
/// ```swift
/// let cost = response.transcriptEntries.reduce(Decimal.zero) { total, entry in
///     switch entry {
///     case .toolCalls(let calls): total + (calls.openRouter.usage.cost ?? 0)
///     case .response(let answer): total + (answer.openRouter.usage.cost ?? 0)
///     default: total
///     }
/// }
/// ```
///
/// Each fact comes from the ``OpenRouterMetadataKey`` key of its name. The keys of ``cost`` and
/// ``cacheWriteTokenCount`` are shared, so another language model's usage reads too.
public struct OpenRouterUsageMetadata: Sendable, Hashable {
    /// What the answer cost, in US dollars, from the account's OpenRouter credits.
    ///
    /// When ``isBYOK`` is `true`, it's only OpenRouter's fee, and the host bills the account's own key for
    /// ``upstreamInferenceCost``.
    public let cost: Decimal?

    /// The prompt tokens written to the host's prompt cache.
    public let cacheWriteTokenCount: Int?

    /// Whether the request used the account's own key for the host, rather than OpenRouter's, so the host billed that
    /// key.
    public let isBYOK: Bool?

    /// What the host charged for the answer, in US dollars, when OpenRouter reports it, as for a request that used the
    /// account's own key.
    public let upstreamInferenceCost: Decimal?

    /// The part of the host's charge for the prompt, in US dollars.
    public let upstreamInferencePromptCost: Decimal?

    /// The part of the host's charge for the output, in US dollars.
    public let upstreamInferenceCompletionCost: Decimal?

    /// What server tools that are billed by use cost, in US dollars, such as the time a sandbox ran; 0 when they ran
    /// for free.
    public let serverToolCost: Decimal?

    /// The server-tool calls the model asked for, of every kind, such as ``OpenRouterServerTool`` web searches and
    /// fetches. A host's own web search isn't counted.
    public let requestedServerToolCallCount: Int?

    /// The server-tool calls that ran and gave the model a result.
    public let executedServerToolCallCount: Int?

    /// The web searches that ran, by ``OpenRouterServerTool`` or by the host's own search.
    ///
    /// A search by ``OpenRouterServerTool`` also counts in ``requestedServerToolCallCount``, so don't add the two
    /// together.
    public let webSearchCount: Int?

    /// The facts in a usage's metadata.
    init(_ metadata: [String: GeneratedContent]) {
        let values = MetadataValues(metadata)
        cost = values.decimal(OpenRouterMetadataKey.cost)
        cacheWriteTokenCount = values.integer(OpenRouterMetadataKey.cacheWriteTokenCount)
        isBYOK = values.bool(OpenRouterMetadataKey.isBYOK)
        upstreamInferenceCost = values.decimal(OpenRouterMetadataKey.upstreamInferenceCost)
        upstreamInferencePromptCost = values.decimal(OpenRouterMetadataKey.upstreamInferencePromptCost)
        upstreamInferenceCompletionCost = values.decimal(OpenRouterMetadataKey.upstreamInferenceCompletionCost)
        serverToolCost = values.decimal(OpenRouterMetadataKey.serverToolCost)
        requestedServerToolCallCount = values.integer(OpenRouterMetadataKey.requestedServerToolCallCount)
        executedServerToolCallCount = values.integer(OpenRouterMetadataKey.executedServerToolCallCount)
        webSearchCount = values.integer(OpenRouterMetadataKey.webSearchCount)
    }
}

extension LanguageModelSession.Usage {
    /// What OpenRouter reported about the answer's cost and counts, such as its cost in US dollars.
    public var openRouter: OpenRouterUsageMetadata {
        OpenRouterUsageMetadata(metadata)
    }
}
