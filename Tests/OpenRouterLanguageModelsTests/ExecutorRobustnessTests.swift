import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: robustness")
struct ExecutorRobustnessTests {
    @Test(arguments: ["\u{2028}", "\u{2029}", "\u{85}"])
    func `a Unicode line break inside an answer doesn't split its event`(separator: String) async throws {
        let stub = HTTPStub(events(text("a\(separator)b"), done()))

        let response = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")

        #expect(response.content == "a\(separator)b")
    }

    @Test func `an empty data line is skipped`() async throws {
        let stream = "data: \n\ndata: \(String(decoding: text("Hi").data, as: UTF8.self))\n\ndata: [DONE]\n\n"
        let stub = HTTPStub(.eventStream(Data(stream.utf8)))

        #expect(try await LanguageModelSession(model: model(stub)).respond(to: "Hi").content == "Hi")
    }

    @Test func `a stream cut off before it finished throws`() async throws {
        let stream = "data: \(String(decoding: text("Hel").data, as: UTF8.self))\n\n"
        let stub = HTTPStub(.eventStream(Data(stream.utf8)))

        await #expect(throws: OpenRouterError.self) {
            try await LanguageModelSession(model: model(stub)).respond(to: "Hi")
        }
    }

    @Test func `a failed connection throws an OpenRouter error`() async throws {
        let stub = HTTPStub()

        let error = await #expect(throws: OpenRouterError.self) {
            try await LanguageModelSession(model: model(stub)).respond(to: "Hi")
        }
        #expect(error?.status == nil)
    }

    @Test func `two calls with the same id both run`() async throws {
        let stub = HTTPStub(
            events(
                call(0, id: "call_1", arguments: #"{"food":"egg"}"#),
                call(1, id: "call_1", arguments: #"{"food":"rice"}"#),
                done("tool_calls")
            ),
            events(text("Done."), done())
        )

        _ = try await LanguageModelSession(model: model(stub), tools: [FoodTool()]).respond(to: "Egg and rice?")

        let outputs = messages(try body(stub, 1)).filter { $0["role"] == "tool" }
        #expect(outputs.map(\.["content"]) == ["egg: 100 kcal", "rice: 100 kcal"])
        #expect(Set(outputs.compactMap { $0["tool_call_id"]?.stringValue }).count == 2)
    }

    @Test func `calls without an index start a new call when their id changes`() async throws {
        let stub = HTTPStub(
            events(
                call(nil, id: "call_a", arguments: #"{"food":"egg"}"#),
                call(nil, id: "call_b", arguments: #"{"food":"rice"}"#),
                done("tool_calls")
            ),
            events(text("Done."), done())
        )

        _ = try await LanguageModelSession(model: model(stub), tools: [FoodTool()]).respond(to: "Egg and rice?")

        let outputs = messages(try body(stub, 1)).filter { $0["role"] == "tool" }
        #expect(outputs.map(\.["tool_call_id"]) == ["call_a", "call_b"])
    }

    @Test func `a session with tools and no instructions sends no empty system message`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        _ = try await LanguageModelSession(model: model(stub), tools: [FoodTool()]).respond(to: "Hi")

        #expect(messages(try body(stub)).map(\.["role"]) == ["user"])
    }

    @Test func `JSON mode gets the schema even when the prompt doesn't include it`() async throws {
        let stub = HTTPStub(events(text(#"{"name":"Soup"}"#), done()))
        let session = LanguageModelSession(model: model(stub, parameters: [.responseFormat]))

        _ = try await session.respond(to: "A dish.", generating: Dish.self, includeSchemaInPrompt: false)

        let prompt = try #require(messages(try body(stub)).last)
        #expect(prompt["content"]?[1]?["text"]?.stringValue?.hasPrefix("Respond with JSON that matches this JSON Schema:") == true)
    }

    @Test func `an earlier prompt keeps its schema text when a later request leaves its schema out`() async throws {
        let stub = HTTPStub(events(text(#"{"name":"Soup"}"#), done()), events(text(#"{"name":"Stew"}"#), done()))
        let session = LanguageModelSession(model: model(stub))

        _ = try await session.respond(to: "A dish.", generating: Dish.self)
        _ = try await session.respond(to: "Another.", generating: Dish.self, includeSchemaInPrompt: false)

        let first = try #require(messages(try body(stub, 0)).last)
        let replayed = try #require(messages(try body(stub, 1)).first { $0["role"] == "user" })
        #expect(replayed == first)
    }

    @Test func `an empty reasoning list goes back on the next turn`() async throws {
        let stub = HTTPStub(events(chunk(["reasoning_details": []]), text("Hi"), done()), events(text("Again."), done()))
        let session = LanguageModelSession(model: model(stub))

        _ = try await session.respond(to: "Hi")
        _ = try await session.respond(to: "Again?")

        let assistant = try #require(messages(try body(stub, 1)).first { $0["role"] == "assistant" })
        #expect(assistant["reasoning_details"] == [])
        #expect(assistant["reasoning"] == nil)
    }

    @Test func `unsigned reasoning text without a format isn't sent back`() async throws {
        let stub = HTTPStub(
            events(chunk(["reasoning_details": [["type": "reasoning.text", "text": "Unsigned."]]]), text("Hi"), done()),
            events(text("Again."), done())
        )
        let session = LanguageModelSession(model: model(stub))

        _ = try await session.respond(to: "Hi")
        _ = try await session.respond(to: "Again?")

        let assistant = try #require(messages(try body(stub, 1)).first { $0["role"] == "assistant" })
        #expect(assistant["reasoning_details"] == [])
    }

    @Test func `metadata within OpenRouter's limits is passed through, sorted`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        var metadata: [String: any ConvertibleToGeneratedContent] = ["b": "2", "a": "1", "count": 3]
        metadata[String(repeating: "k", count: 65)] = "too long a key"
        metadata["long"] = String(repeating: "v", count: 513)

        _ = try await LanguageModelSession(model: model(stub)).respond(to: "Hi", metadata: metadata)

        #expect(try body(stub)["metadata"] == ["a": "1", "b": "2"])
    }

    @Test func `a 402 for too many requests in flight is a rate limit`() async throws {
        let body = #"{"error":{"code":402,"message":"Too many in flight","metadata":{"limit_source":"openrouter_in_flight_budget"}}}"#
        let stub = HTTPStub(.json(body, status: 402, headers: ["Retry-After": "2"]))

        do {
            _ = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")
            Issue.record("The request didn't fail.")
        } catch LanguageModelError.rateLimited(let info) {
            #expect(info.resetDate != nil)
        }
    }

    private func call(_ index: Int?, id: String, arguments: String) -> JSONValue {
        let function: JSONValue = ["name": "lookUpFood", "arguments": .string(arguments)]
        let fragment: JSONValue = ["index": index.map(JSONValue.integer), "id": .string(id), "type": "function", "function": function]
        return chunk(["tool_calls": [fragment]])
    }
}

@Suite("Retry delay")
struct RetryDelayTests {
    private static let now = Date(timeIntervalSince1970: 1_793_000_000)

    @Test(arguments: [("30", 30.0), ("1.5", 1.5), ("-4", 0), ("inf", 86_400), ("1e300", 86_400)])
    func `a number of seconds is clamped to a day`(header: String, seconds: Double) {
        #expect(Duration(retryAfter: header, now: Self.now) == .seconds(seconds))
    }

    @Test func `an HTTP date is the time until then`() {
        #expect(Duration(retryAfter: "Tue, 27 Oct 2026 06:13:50 GMT", now: Date(timeIntervalSince1970: 1_793_081_600)) == .seconds(30))
    }

    @Test(arguments: [nil, "", "soon", "nan"])
    func `a header that isn't a delay gives none`(header: String?) {
        #expect(Duration(retryAfter: header, now: Self.now) == nil)
    }

    @Test(arguments: [("1793000030000", 30.0), ("1793000030", 30.0), ("1792999990", 0)])
    func `a rate limit reset is the time until then, in milliseconds or seconds`(header: String, seconds: Double) {
        #expect(Duration(rateLimitReset: header, now: Self.now) == .seconds(seconds))
    }
}

@Generable
private struct Dish {
    var name: String
}
