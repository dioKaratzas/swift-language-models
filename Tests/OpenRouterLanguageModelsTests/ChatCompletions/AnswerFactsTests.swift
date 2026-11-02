import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import ChatCompletionsAPI
@testable import OpenRouterLanguageModels

@Suite("Answer facts")
struct AnswerFactsTests {
    @Test func `a fact that a chunk reports replaces the earlier one, and one it leaves out keeps its value`() throws {
        let provider = provider()
        var stream = provider.stream(for: nil)

        _ = try provider.observe(
            chunk(["id": "gen-1", "model": "vendor/model", "provider": "Vendor", "service_tier": "flex"]), in: &stream)
        _ = try provider.observe(
            chunk([
                "model": "vendor/model-2026-10-01",
                "choices": [["delta": [:], "finish_reason": "length"]],
                "usage": ["prompt_tokens": 12, "completion_tokens": 5, "cost": 0.000_1],
            ]), in: &stream)
        _ = try provider.observe(chunk(["choices": [["delta": [:]]]]), in: &stream)
        let facts = provider.facts(of: stream)

        #expect(facts.host == "Vendor")
        #expect(metadataNumber(facts.usageMetadata.mapValues(\.generatedContent), LanguageModelMetadataKey.cost) == 0.000_1)
    }

    @Test func `the metadata names the host, with the response cache's status and the router's report`() throws {
        let url = try #require(URL(string: "https://openrouter.ai/api/v1/chat/completions"))
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["X-OpenRouter-Cache-Status": "MISS"])
        let provider = provider()
        var stream = provider.stream(for: response)

        _ = try provider.observe(
            chunk([
                "id": "gen-1", "model": "vendor/model", "provider": "Vendor", "service_tier": "priority",
                "choices": [["delta": [:], "finish_reason": "stop"]],
                "openrouter_metadata": ["strategy": "price", "generation_time": 1_500],
            ]), in: &stream)
        let metadata = provider.facts(of: stream).metadata.mapValues(\.generatedContent)

        #expect(metadataString(metadata, LanguageModelMetadataKey.provider) == "Vendor")
        #expect(metadataString(metadata, OpenRouterMetadataKey.responseCacheStatus) == "MISS")
        #expect(metadataString(metadata, OpenRouterMetadataKey.routingStrategy) == "price")
        #expect(metadataNumber(metadata, OpenRouterMetadataKey.generationTime) == 1.5)
    }

    @Test func `facts that no chunk reported are left out of the metadata`() {
        let provider = provider()
        let facts = provider.facts(of: provider.stream(for: nil))

        #expect(facts.metadata.isEmpty)
        #expect(facts.usageMetadata.isEmpty)
    }

    @Test(arguments: [
        (ChatCompletionsExecutor<OpenRouterChatCompletions>.Failure.Problem.toolCallWithoutName, OpenRouterProviderName?.some("Vendor")),
        (.incompleteToolArguments(toolName: "order"), "Vendor"),
        (.cutOff, "Vendor"),
        (.unreadableEvent("bad JSON"), nil),
    ])
    func `a response the format can't use throws an invalid response, naming the host unless an event couldn't be read`(
        problem: ChatCompletionsExecutor<OpenRouterChatCompletions>.Failure.Problem,
        host: OpenRouterProviderName?
    ) throws {
        let provider = provider()
        var stream = provider.stream(for: nil)
        _ = try provider.observe(chunk(["provider": "Vendor"]), in: &stream)

        let failure = OpenRouterChatCompletions.Failure(
            .unusableResponse(problem), stream: stream, provider: provider.name, imageEntries: [])
        let error = try #require(provider.error(for: failure) as? OpenRouterError)

        #expect(error.code == .invalidResponse)
        #expect(error.providerName == host)
        #expect(error.message == problem.message(provider: "OpenRouter"))
    }
}

/// OpenRouter as a provider, for a stub model.
private func provider() -> OpenRouterChatCompletions {
    let model: OpenRouterLanguageModel<Efforts.Unsupported> = model(HTTPStub())
    return OpenRouterChatCompletions(model: model, details: model.sharedDetails, configuration: model.executorConfiguration)
}

/// A chunk with the given members.
private func chunk(_ members: JSONValue) -> OpenRouterChatCompletions.Chunk {
    OpenRouterChatCompletions.Chunk(data: members.data)
}
