import Foundation
import FoundationModels

/// What an answer's response and chunks report about it: the model that answered, its host, the response id, the
/// service tier, the usage, the router's report, the response cache's status and why the answer ended.
///
/// Chunks repeat some facts and leave out others, so a fact that a chunk reports replaces the earlier one, and one it
/// leaves out keeps its earlier value.
struct AnswerFacts {
    /// What the response cache reported in the response's headers, or `nil` when the cache is off.
    let responseCache: ResponseCacheStatus?

    /// The model that answered, as the answer names it.
    private(set) var model: String?

    /// The host that served the answer.
    private(set) var provider: OpenRouterProviderName?

    /// The answer's generation id.
    private(set) var responseID: String?

    private(set) var serviceTier: OpenRouterServiceTier?

    /// The usage as Foundation Models' running totals.
    private(set) var usage: UsageTotals?

    /// How OpenRouter routed the request, when the request asked for it.
    private(set) var routerReport: ChatCompletionChunk.RouterMetadata?

    private(set) var finishReason: OpenRouterFinishReason?

    /// The facts of an answer before its first chunk.
    ///
    /// - Parameter responseCache: What the response cache reported in the response's headers.
    init(responseCache: ResponseCacheStatus?) {
        self.responseCache = responseCache
    }

    /// Takes the facts that a chunk reports.
    mutating func update(with chunk: ChatCompletionChunk) {
        responseID = chunk.id ?? responseID
        model = chunk.model ?? model
        if let provider = chunk.provider {
            self.provider = OpenRouterProviderName(rawValue: provider)
        }
        serviceTier = chunk.serviceTier ?? serviceTier
        if let usage = chunk.usage {
            self.usage = UsageTotals(usage)
        }
        routerReport = chunk.routerMetadata ?? routerReport
        finishReason = chunk.choices?.first?.finishReason ?? finishReason
    }

    /// The facts as metadata of the entry that ends the answer; the usage goes with the entry's usage instead.
    var metadata: [String: any ConvertibleToGeneratedContent] {
        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[OpenRouterMetadataKey.model] = model
        metadata[OpenRouterMetadataKey.provider] = provider?.rawValue
        metadata[OpenRouterMetadataKey.responseID] = responseID
        metadata[OpenRouterMetadataKey.finishReason] = finishReason?.rawValue
        metadata[OpenRouterMetadataKey.serviceTier] = serviceTier?.rawValue
        metadata.merge(responseCache?.metadata ?? [:]) { $1 }
        metadata.merge(routerReport?.metadata ?? [:]) { $1 }
        return metadata
    }
}

/// The usage OpenRouter reported, as Foundation Models' running totals, with the cost, its parts and the server tools'
/// counts in the metadata.
struct UsageTotals {
    let input: LanguageModelExecutorGenerationChannel.Usage.Input
    let output: LanguageModelExecutorGenerationChannel.Usage.Output
    let metadata: [String: any ConvertibleToGeneratedContent]

    init(_ usage: ChatCompletionChunk.Usage) {
        input = .init(totalTokenCount: usage.promptTokens ?? 0, cachedTokenCount: usage.promptTokensDetails?.cachedTokens ?? 0)
        output = .init(
            totalTokenCount: usage.completionTokens ?? 0,
            reasoningTokenCount: usage.completionTokensDetails?.reasoningTokens ?? 0
        )
        var metadata: [String: any ConvertibleToGeneratedContent] = [:]
        metadata[OpenRouterMetadataKey.cost] = usage.cost
        metadata[OpenRouterMetadataKey.cacheWriteTokenCount] = usage.promptTokensDetails?.cacheWriteTokens
        metadata[OpenRouterMetadataKey.isBYOK] = usage.isBYOK
        let costs = usage.costDetails
        metadata[OpenRouterMetadataKey.upstreamInferenceCost] = costs?.upstreamInferenceCost
        metadata[OpenRouterMetadataKey.upstreamInferencePromptCost] = costs?.upstreamInferencePromptCost
        metadata[OpenRouterMetadataKey.upstreamInferenceCompletionCost] = costs?.upstreamInferenceCompletionsCost
        metadata[OpenRouterMetadataKey.serverToolCost] = costs?.serverToolCost
        let serverTools = usage.serverToolUseDetails
        metadata[OpenRouterMetadataKey.requestedServerToolCallCount] = serverTools?.toolCallsRequested
        metadata[OpenRouterMetadataKey.executedServerToolCallCount] = serverTools?.toolCallsExecuted
        metadata[OpenRouterMetadataKey.webSearchCount] = serverTools?.webSearchRequests
        self.metadata = metadata
    }
}
