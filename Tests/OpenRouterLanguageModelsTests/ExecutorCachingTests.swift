import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: prompt caching")
struct ExecutorCachingTests {
    @Test func `the next request starts with the previous request's messages, byte for byte`() async throws {
        let stub = HTTPStub(
            events(call(id: "call_1", arguments: #"{"food":"egg"}"#), done("tool_calls")),
            events(text("An egg has 100 kcal."), done()),
            events(text("Rice too."), done())
        )
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()], instructions: "Answer with tools.")

        _ = try await session.respond(to: "Calories in an egg?")
        _ = try await session.respond(to: "And rice?")

        let bodies = stub.requests.map { String(decoding: $0.body, as: UTF8.self) }
        try #require(bodies.count == 3)
        for (earlier, later) in zip(bodies, bodies.dropFirst()) {
            let messages = try #require(messagesText(earlier))
            #expect(later.contains("\"messages\":[\(messages),"))
        }
        let sessionIDs = try (0..<3).map { try body(stub, $0)["session_id"]?.stringValue }
        #expect(Set(sessionIDs).count == 1)
        #expect(sessionIDs.first??.isEmpty == false)
    }

    @Test func `no cache control sends no markers`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        _ = try await LanguageModelSession(model: model(stub), instructions: "Be brief.").respond(to: "Hi")

        let body = try body(stub)
        #expect(body["cache_control"] == nil)
        #expect(messages(body).first?["content"] == "Be brief.")
    }

    @Test(arguments: [
        (OpenRouterCacheControl.ephemeral, JSONValue.object(["type": "ephemeral"])),
        (.ephemeral(timeToLive: .oneHour), .object(["type": "ephemeral", "ttl": "1h"])),
    ])
    func `a cache control marks the request and the end of the instructions`(cacheControl: OpenRouterCacheControl, marker: JSONValue)
        async throws
    {
        let stub = HTTPStub(events(text("Hi"), done()))

        _ = try await LanguageModelSession(model: model(stub, cacheControl: cacheControl), instructions: "Be brief.").respond(to: "Hi")

        let body = try body(stub)
        #expect(body["cache_control"] == marker)
        #expect(messages(body).first?["content"] == [["cache_control": marker, "text": "Be brief.", "type": "text"]])
        #expect(messages(body).last?["content"] == "Hi")
    }

    /// The text between `"messages":[` and the array's end in a request body.
    private func messagesText(_ body: String) -> String? {
        guard let start = body.range(of: "\"messages\":["),
            let end = body.range(of: "],\"stream\":", range: start.upperBound..<body.endIndex)
        else { return nil }
        return String(body[start.upperBound..<end.lowerBound])
    }

    private func call(id: String, arguments: String) -> JSONValue {
        let function: JSONValue = ["name": "lookUpFood", "arguments": .string(arguments)]
        return chunk(["tool_calls": [["index": 0, "id": .string(id), "type": "function", "function": function]]])
    }
}
