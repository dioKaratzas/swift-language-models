import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: prompt caching")
struct ExecutorCachingTests {
    @Test func `the next request starts with the previous request's messages, byte for byte`() async throws {
        let stub = HTTPStub(
            events(toolCall(0, id: "call_1", name: "lookUpFood", arguments: #"{"food":"egg"}"#), done("tool_calls")),
            events(text("An egg has 100 kcal."), done()),
            events(text("Rice too."), done())
        )
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()], instructions: "Answer with tools.")

        _ = try await session.respond(to: "Calories in an egg?")
        _ = try await session.respond(to: "And rice?")

        let messages = try stub.requests.map { try #require(messagesText(in: $0.body)) }
        try #require(messages.count == 3)
        for (earlier, later) in zip(messages, messages.dropFirst()) {
            #expect(later.starts(with: earlier.dropLast() + Array(",".utf8)))
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

    /// The bytes of the top-level `messages` array in a request body, from its `[` to its `]`.
    ///
    /// The body is walked as JSON, so the same text inside a string or a nested object doesn't count.
    private func messagesText(in body: Data) -> ArraySlice<UInt8>? {
        let bytes = Array(body)
        let key = Array(#""messages":"#.utf8)
        var depth = 0
        var isInString = false
        var isEscaped = false
        var start: Int?
        for (index, byte) in bytes.enumerated() {
            if isInString {
                if isEscaped {
                    isEscaped = false
                } else if byte == UInt8(ascii: "\\") {
                    isEscaped = true
                } else if byte == UInt8(ascii: "\"") {
                    isInString = false
                }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                if depth == 1, start == nil, bytes[index...].starts(with: key) { start = index + key.count }
                isInString = true
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                depth += 1
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                depth -= 1
                if depth == 1, let start { return bytes[start...index] }
            default:
                break
            }
        }
        return nil
    }
}
