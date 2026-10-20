import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: response cache")
struct ExecutorResponseCacheTests {
    @Test func `without a response cache, a request sends no cache headers and keeps the session id in the body`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        try await respond(stub)

        let request = try #require(stub.requests.first)
        for header in ["X-OpenRouter-Cache", "X-OpenRouter-Cache-TTL", "X-OpenRouter-Cache-Clear", "X-Session-Id"] {
            #expect(request.request.value(forHTTPHeaderField: header) == nil)
        }
        #expect(try body(request)["session_id"]?.stringValue?.isEmpty == false)
    }

    @Test(arguments: [
        (OpenRouterResponseCache(), 300),
        (OpenRouterResponseCache(timeToLive: .seconds(3_600)), 3_600),
        (OpenRouterResponseCache(timeToLive: .milliseconds(1_500)), 1),
        (OpenRouterResponseCache(timeToLive: .milliseconds(400)), 1),
        (OpenRouterResponseCache(timeToLive: .seconds(-10)), 1),
        (OpenRouterResponseCache(timeToLive: .seconds(86_400)), 86_400),
        (OpenRouterResponseCache(timeToLive: .seconds(100_000)), 86_400),
    ])
    func `a response cache turns the cache on for its time to live, in whole seconds from 1 second to 24 hours`(
        cache: OpenRouterResponseCache,
        seconds: Int
    ) async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        _ = try await LanguageModelSession(model: model(stub, responseCache: cache)).respond(to: "Hi")

        let request = try #require(stub.requests.first).request
        #expect(cache.timeToLive == .seconds(seconds))
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Cache") == "true")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Cache-TTL") == String(seconds))
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Cache-Clear") == nil)
    }

    @Test func `a refreshing cache asks OpenRouter to replace the kept answer`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        var cache = OpenRouterResponseCache(timeToLive: .seconds(60))
        cache.refreshes = true

        _ = try await LanguageModelSession(model: model(stub, responseCache: cache)).respond(to: "Hi")

        let request = try #require(stub.requests.first).request
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Cache") == "true")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Cache-TTL") == "60")
        #expect(request.value(forHTTPHeaderField: "X-OpenRouter-Cache-Clear") == "true")
    }

    @Test func `with the cache on, the session id goes in a header, so new sessions that ask the same send the same body`()
        async throws
    {
        let stub = HTTPStub(events(text("Hi"), done()), events(text("Hi"), done()), events(text("Again"), done()))
        let cached = model(stub, responseCache: OpenRouterResponseCache())

        _ = try await LanguageModelSession(model: cached, instructions: "Be brief.").respond(to: "Hi")
        let second = LanguageModelSession(model: cached, instructions: "Be brief.")
        _ = try await second.respond(to: "Hi")
        _ = try await second.respond(to: "Again?")

        let requests = stub.requests
        try #require(requests.count == 3)
        #expect(requests[0].body == requests[1].body)
        #expect(try body(requests[0])["session_id"] == nil)
        let sessionIDs = requests.map { $0.request.value(forHTTPHeaderField: "X-Session-Id") }
        #expect(sessionIDs.allSatisfy { $0?.isEmpty == false })
        #expect(sessionIDs[0] != sessionIDs[1])
        #expect(sessionIDs[1] == sessionIDs[2])
    }

    @Test(arguments: [
        (
            ["X-OpenRouter-Cache-Status": "HIT", "X-OpenRouter-Cache-Age": "12", "X-OpenRouter-Cache-Source-Id": "gen-abc123"],
            JSONValue?.some(true), JSONValue?.some(12), JSONValue?.some("gen-abc123")
        ),
        (["X-OpenRouter-Cache-Status": "MISS", "X-OpenRouter-Cache-TTL": "300"], false, nil, nil),
        (["X-OpenRouter-Cache-Status": "BYPASS"], nil, nil, nil),
        ([:], nil, nil, nil),
    ])
    func `the cache status, age and source id in the response's headers reach the answer's entry`(
        headers: [String: String],
        hit: JSONValue?,
        age: JSONValue?,
        sourceID: JSONValue?
    ) async throws {
        let stub = HTTPStub(events(headers: headers, text("Hi"), done()))

        let response = try await LanguageModelSession(model: model(stub, responseCache: OpenRouterResponseCache())).respond(to: "Hi")

        let metadata = try lastResponse(of: response).metadata
        #expect(try metadataJSON(metadata, OpenRouterMetadataKey.responseCacheHit) == hit)
        #expect(try metadataJSON(metadata, OpenRouterMetadataKey.responseCacheAge) == age)
        #expect(try metadataJSON(metadata, OpenRouterMetadataKey.responseCacheSourceID) == sourceID)
        #expect(metadataString(metadata, OpenRouterMetadataKey.generationID) == "gen-1")
    }
}
