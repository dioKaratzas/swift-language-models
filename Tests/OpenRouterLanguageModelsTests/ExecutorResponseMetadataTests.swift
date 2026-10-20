import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

/// The final chunk's usage with every part of the cost and every server-tool count.
private let detailedUsage: JSONValue = [
    "prompt_tokens": 12,
    "completion_tokens": 5,
    "total_tokens": 17,
    "cost": 0.000_1,
    "is_byok": true,
    "cost_details": [
        "upstream_inference_cost": 0.002, "upstream_inference_prompt_cost": 0.000_5, "upstream_inference_completions_cost": 0.001_5,
        "server_tool_cost": 0.01,
    ],
    "server_tool_use_details": ["tool_calls_requested": 3, "tool_calls_executed": 2, "web_search_requests": 1],
]

@Suite("Executor: response metadata")
struct ExecutorResponseMetadataTests {
    /// Each usage key with its value from ``detailedUsage``.
    private static let usageValues: [(String, JSONValue)] = [
        (OpenRouterMetadataKey.isBYOK, true),
        (OpenRouterMetadataKey.cost, 0.000_1),
        (OpenRouterMetadataKey.upstreamInferenceCost, 0.002),
        (OpenRouterMetadataKey.upstreamInferencePromptCost, 0.000_5),
        (OpenRouterMetadataKey.upstreamInferenceCompletionCost, 0.001_5),
        (OpenRouterMetadataKey.serverToolCost, 0.01),
        (OpenRouterMetadataKey.requestedServerToolCallCount, 3),
        (OpenRouterMetadataKey.executedServerToolCallCount, 2),
        (OpenRouterMetadataKey.webSearchCount, 1),
    ]

    @Test(arguments: [(JSONValue.string("flex"), String?.some("flex")), ("priority", "priority"), (.null, nil)])
    func `the service tier that served the answer reaches its entry`(tier: JSONValue, expected: String?) async throws {
        let stub = HTTPStub(events(text("Hi"), adding(["service_tier": tier], to: done())))

        let response = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")

        #expect(metadataString(try lastResponse(of: response).metadata, OpenRouterMetadataKey.serviceTier) == expected)
    }

    @Test(arguments: usageValues)
    func `each part of the cost and each server-tool count reaches the answer's usage`(key: String, value: JSONValue) async throws {
        let stub = HTTPStub(events(text("Hi"), chunk([:], finishReason: "stop", usage: detailedUsage)))

        let response = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")

        #expect(try metadataJSON(response.usage.metadata, key) == value)
        #expect(try metadataJSON(lastResponse(of: response).metadata, key) == nil)
    }

    @Test func `usage without cost details or server-tool counts leaves their keys out`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        let response = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")

        let keys = [
            OpenRouterMetadataKey.isBYOK, OpenRouterMetadataKey.upstreamInferenceCost, OpenRouterMetadataKey.upstreamInferencePromptCost,
            OpenRouterMetadataKey.upstreamInferenceCompletionCost, OpenRouterMetadataKey.serverToolCost,
            OpenRouterMetadataKey.requestedServerToolCallCount, OpenRouterMetadataKey.executedServerToolCallCount,
            OpenRouterMetadataKey.webSearchCount,
        ]
        #expect(keys.allSatisfy { response.usage.metadata[$0] == nil })
        #expect(metadataNumber(response.usage.metadata, OpenRouterMetadataKey.cost) == 0.000_25)
    }

    @Test func `a null upstream cost and null server-tool counts are left out`() async throws {
        let usage: JSONValue = [
            "prompt_tokens": 12, "completion_tokens": 5, "total_tokens": 17, "is_byok": false,
            "cost_details": [
                "upstream_inference_cost": .null, "upstream_inference_prompt_cost": 0, "upstream_inference_completions_cost": 0,
            ],
            "server_tool_use_details": .null,
        ]
        let stub = HTTPStub(events(text("Hi"), chunk([:], finishReason: "stop", usage: usage)))

        let response = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")

        let metadata = response.usage.metadata
        #expect(try metadataJSON(metadata, OpenRouterMetadataKey.isBYOK) == false)
        #expect(metadata[OpenRouterMetadataKey.upstreamInferenceCost] == nil)
        #expect(try metadataJSON(metadata, OpenRouterMetadataKey.upstreamInferencePromptCost) == 0)
        #expect(metadata[OpenRouterMetadataKey.webSearchCount] == nil)
    }
}
