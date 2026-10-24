import OpenRouterLanguageModels
import Testing

/// Each key with its spelling: bare for a fact every model reports, and prefixed for one only OpenRouter has.
private let spellings: [(key: String, spelling: String)] = [
    (OpenRouterMetadataKey.model, "model"),
    (OpenRouterMetadataKey.provider, "provider"),
    (OpenRouterMetadataKey.responseID, "responseID"),
    (OpenRouterMetadataKey.finishReason, "finishReason"),
    (OpenRouterMetadataKey.serviceTier, "serviceTier"),
    (OpenRouterMetadataKey.citations, "citations"),
    (OpenRouterMetadataKey.cost, "cost"),
    (OpenRouterMetadataKey.cacheWriteTokenCount, "cacheWriteTokenCount"),
    (OpenRouterMetadataKey.status, "status"),
    (OpenRouterMetadataKey.responseCacheHit, "openRouter.responseCacheHit"),
    (OpenRouterMetadataKey.responseCacheAge, "openRouter.responseCacheAge"),
    (OpenRouterMetadataKey.responseCacheSourceID, "openRouter.responseCacheSourceID"),
    (OpenRouterMetadataKey.routingStrategy, "openRouter.routingStrategy"),
    (OpenRouterMetadataKey.routingAttempt, "openRouter.routingAttempt"),
    (OpenRouterMetadataKey.routingAttempts, "openRouter.routingAttempts"),
    (OpenRouterMetadataKey.routingEndpoints, "openRouter.routingEndpoints"),
    (OpenRouterMetadataKey.routingPipeline, "openRouter.routingPipeline"),
    (OpenRouterMetadataKey.region, "openRouter.region"),
    (OpenRouterMetadataKey.generationTime, "openRouter.generationTime"),
    (OpenRouterMetadataKey.isBYOK, "openRouter.isBYOK"),
    (OpenRouterMetadataKey.upstreamInferenceCost, "openRouter.upstreamInferenceCost"),
    (OpenRouterMetadataKey.upstreamInferencePromptCost, "openRouter.upstreamInferencePromptCost"),
    (OpenRouterMetadataKey.upstreamInferenceCompletionCost, "openRouter.upstreamInferenceCompletionCost"),
    (OpenRouterMetadataKey.serverToolCost, "openRouter.serverToolCost"),
    (OpenRouterMetadataKey.requestedServerToolCallCount, "openRouter.requestedServerToolCallCount"),
    (OpenRouterMetadataKey.executedServerToolCallCount, "openRouter.executedServerToolCallCount"),
    (OpenRouterMetadataKey.webSearchCount, "openRouter.webSearchCount"),
    (OpenRouterMetadataKey.errorCode, "openRouter.errorCode"),
]

@Suite("Metadata keys")
struct OpenRouterMetadataKeyTests {
    @Test(arguments: spellings)
    func `each key keeps the spelling that saved transcripts keep`(key: String, spelling: String) {
        #expect(key == spelling)
    }

    @Test func `no two keys share a spelling`() {
        #expect(Set(spellings.map(\.key)).count == spellings.count)
    }
}
