import Foundation
import FoundationModels
import LanguageModels
import Testing

@testable import OpenRouterLanguageModels

@Suite("Answer facts")
struct AnswerFactsTests {
    @Test func `a fact that a chunk reports replaces the earlier one, and one it leaves out keeps its value`() throws {
        var facts = AnswerFacts(responseCache: nil)

        facts.update(with: try chunk(["id": "gen-1", "model": "vendor/model", "provider": "Vendor", "service_tier": "flex"]))
        facts.update(
            with: try chunk([
                "model": "vendor/model-2026-10-01",
                "choices": [["delta": [:], "finish_reason": "length"]],
                "usage": ["prompt_tokens": 12, "completion_tokens": 5, "cost": 0.000_1],
            ]))
        facts.update(with: try chunk(["choices": [["delta": [:]]]]))

        #expect(facts.responseID == "gen-1")
        #expect(facts.model == "vendor/model-2026-10-01")
        #expect(facts.provider == "Vendor")
        #expect(facts.serviceTier == .flex)
        #expect(facts.finishReason == .length)
        #expect(facts.usage?.input.totalTokenCount == 12)
        #expect(facts.usage?.output.totalTokenCount == 5)
        #expect(facts.usage.map { metadataNumber($0.metadata.mapValues(\.generatedContent), OpenRouterMetadataKey.cost) } == 0.000_1)
    }

    @Test func `the metadata names the answer's facts, with the response cache's status and the router's report`() throws {
        let url = try #require(URL(string: "https://openrouter.ai/api/v1/chat/completions"))
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["X-OpenRouter-Cache-Status": "MISS"])
        var facts = AnswerFacts(responseCache: ResponseCacheStatus(response))

        facts.update(
            with: try chunk([
                "id": "gen-1", "model": "vendor/model", "provider": "Vendor", "service_tier": "priority",
                "choices": [["delta": [:], "finish_reason": "stop"]],
                "openrouter_metadata": ["strategy": "price", "generation_time": 1_500],
            ]))
        let metadata = facts.metadata.mapValues(\.generatedContent)

        #expect(metadataString(metadata, OpenRouterMetadataKey.model) == "vendor/model")
        #expect(metadataString(metadata, OpenRouterMetadataKey.provider) == "Vendor")
        #expect(metadataString(metadata, OpenRouterMetadataKey.responseID) == "gen-1")
        #expect(metadataString(metadata, OpenRouterMetadataKey.finishReason) == "stop")
        #expect(metadataString(metadata, OpenRouterMetadataKey.serviceTier) == "priority")
        #expect(metadataBool(metadata, OpenRouterMetadataKey.responseCacheHit) == false)
        #expect(metadataString(metadata, OpenRouterMetadataKey.routingStrategy) == "price")
        #expect(metadataNumber(metadata, OpenRouterMetadataKey.generationTime) == 1.5)
    }

    @Test func `facts that no chunk reported are left out of the metadata`() {
        #expect(AnswerFacts(responseCache: nil).metadata.isEmpty)
    }
}

/// A chunk with the given members.
private func chunk(_ members: JSONValue) throws -> ChatCompletionChunk {
    try JSONDecoder().decode(ChatCompletionChunk.self, from: members.data)
}
