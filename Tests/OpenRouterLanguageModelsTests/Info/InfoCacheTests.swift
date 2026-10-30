import Foundation
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Info: cache")
struct InfoCacheTests {
    @Test func `a second call while the answer is fresh reads the cache`() async throws {
        let stub = HTTPStub(try fixtureResponse("model-endpoints.json"), try fixtureResponse("model-endpoints.json"))
        let calls = transport(stub)

        let first = try await calls.providers(of: "anthropic/claude-haiku-5.5", apiKey: nil)
        let second = try await calls.providers(of: "anthropic/claude-haiku-5.5", apiKey: nil)

        #expect(first == second)
        #expect(stub.requests.count == 1)
    }

    @Test func `the public calls share a cache`() async throws {
        let stub = HTTPStub(try fixtureResponse("model.json"), try fixtureResponse("model.json"))

        _ = try await OpenRouterModel.anthropicClaudeHaiku5_5.currentDetails(session: stub.session, baseURL: stub.baseURL)
        _ = try await OpenRouterModel.anthropicClaudeHaiku5_5.currentPricing(session: stub.session, baseURL: stub.baseURL)

        #expect(stub.requests.count == 1)
    }

    @Test func `an answer is kept apart for each key`() async throws {
        let stub = HTTPStub(
            try fixtureResponse("model-endpoints.json"), try fixtureResponse("model-endpoints-keyed.json"),
            try fixtureResponse("model-endpoints-keyed.json"))
        let calls = transport(stub)

        let keyless = try await calls.providers(of: "anthropic/claude-haiku-5.5", apiKey: nil)
        let keyed = try await calls.providers(of: "anthropic/claude-haiku-5.5", apiKey: "sk-or-a")
        let otherKey = try await calls.providers(of: "anthropic/claude-haiku-5.5", apiKey: "sk-or-b")
        let keyedAgain = try await calls.providers(of: "anthropic/claude-haiku-5.5", apiKey: "sk-or-a")

        #expect(keyless.first?.latencyLast30Minutes == nil)
        #expect(keyed.first?.latencyLast30Minutes != nil)
        #expect(otherKey == keyed)
        #expect(keyedAgain == keyed)
        #expect(stub.requests.count == 3)
    }

    @Test func `an answer is kept apart for each model`() async throws {
        let stub = HTTPStub(try fixtureResponse("model.json"), try fixtureResponse("model-router.json"))
        let calls = transport(stub)

        let haiku = try await calls.currentDetails(of: "anthropic/claude-haiku-5.5", apiKey: nil)
        let router = try await calls.currentDetails(of: "openrouter/auto", apiKey: nil)

        #expect(haiku.id != router.id)
        #expect(stub.requests.count == 2)
    }

    @Test func `an expired answer is fetched again`() async throws {
        let stub = HTTPStub(try fixtureResponse("model-endpoints.json"), try fixtureResponse("model-endpoints.json"))
        let calls = transport(stub, cacheLifetime: .zero)

        _ = try await calls.providers(of: "anthropic/claude-haiku-5.5", apiKey: nil)
        _ = try await calls.providers(of: "anthropic/claude-haiku-5.5", apiKey: nil)

        #expect(stub.requests.count == 2)
    }

    @Test func `a failure isn't kept`() async throws {
        let stub = HTTPStub(
            .json(#"{"error":{"message":"Internal Server Error","code":500}}"#, status: 500), try fixtureResponse("model.json"))
        let calls = transport(stub)

        await #expect(throws: OpenRouterError.self) { try await calls.currentDetails(of: "anthropic/claude-haiku-5.5", apiKey: nil) }
        let details = try await calls.currentDetails(of: "anthropic/claude-haiku-5.5", apiKey: nil)

        #expect(details.id == "anthropic/claude-haiku-5.5")
        #expect(stub.requests.count == 2)
    }

    @Test func `an entry expires after its lifetime`() throws {
        let cache = InfoCache()
        let key = InfoCache.Key(url: try #require(URL(string: "https://example.test/model/a/b")), apiKey: nil)
        let now = ContinuousClock.now

        cache.store("answer", for: key, lifetime: .seconds(60), now: now)

        #expect(cache.value(for: key, as: String.self, now: now + .seconds(59)) == "answer")
        #expect(cache.value(for: key, as: String.self, now: now + .seconds(60)) == nil)
    }

    @Test func `the cache keeps a digest of the key, never the key`() throws {
        let url = try #require(URL(string: "https://example.test/model/a/b"))

        let key = InfoCache.Key(url: url, apiKey: "sk-or-secret")

        #expect(key.account?.contains("sk-or-secret") == false)
        #expect(key != InfoCache.Key(url: url, apiKey: "sk-or-other"))
        #expect(key == InfoCache.Key(url: url, apiKey: "sk-or-secret"))
        #expect(InfoCache.Key(url: url, apiKey: nil).account == nil)
    }
}
