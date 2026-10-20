import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: tools")
struct ExecutorToolTests {
    @Test func `a tool call runs the tool and sends its output back`() async throws {
        let stub = HTTPStub(
            events(
                toolCall(0, id: "call_1", name: "lookUpFood", arguments: #"{"fo"#),
                toolCall(0, arguments: #"od":"egg"}"#),
                done("tool_calls")
            ),
            events(text("An egg has 100 kcal."), done())
        )
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()], instructions: "Answer with tools.")

        let response = try await session.respond(to: "Calories in an egg?")

        #expect(response.content == "An egg has 100 kcal.")
        #expect(stub.requests.count == 2)
        let first = try body(stub, 0)
        let definitions = elements(first["tools"])
        try #require(definitions.count == 1)
        #expect(definitions[0]["function"]?["name"] == "lookUpFood")
        #expect(definitions[0]["function"]?["parameters"]?["properties"]?["food"]?["type"] == "string")
        #expect(first["provider"]?["require_parameters"] == true)

        let second = messages(try body(stub, 1))
        try #require(second.count == 4)
        #expect(second[2]["role"] == "assistant")
        #expect(
            second[2]["tool_calls"] == [
                ["function": ["arguments": #"{"food":"egg"}"#, "name": "lookUpFood"], "id": "call_1", "type": "function"]
            ])
        #expect(second[3] == ["content": "egg: 100 kcal", "role": "tool", "tool_call_id": "call_1"])
    }

    @Test func `parallel calls in one answer make one round and one follow-up request`() async throws {
        let stub = HTTPStub(
            events(
                toolCall(0, id: "call_egg", name: "lookUpFood", arguments: #"{"food":"egg"}"#),
                toolCall(1, id: "call_rice", name: "lookUpFood", arguments: #"{"food":"rice"}"#),
                done("tool_calls")
            ),
            events(text("Egg and rice: 200 kcal."), done())
        )
        let session = LanguageModelSession(model: model(stub, parameters: chatParameters.union([.parallelToolCalls])), tools: [FoodTool()])

        let response = try await session.respond(to: "Calories in an egg and rice?")

        #expect(response.content == "Egg and rice: 200 kcal.")
        #expect(stub.requests.count == 2)
        #expect(try body(stub, 0)["parallel_tool_calls"] == true)
        let second = messages(try body(stub, 1))
        let assistant = second.filter { $0["role"] == "assistant" }
        try #require(assistant.count == 1)
        #expect(elements(assistant[0]["tool_calls"]).map { $0["id"] } == ["call_egg", "call_rice"])
        let outputs = second.filter { $0["role"] == "tool" }
        #expect(outputs.map { $0["tool_call_id"] } == ["call_egg", "call_rice"])
        #expect(outputs.map { $0["content"] } == ["egg: 100 kcal", "rice: 100 kcal"])
    }

    @Test func `a model that doesn't list parallel calls gets no such field, but still its tools`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()])

        _ = try await session.respond(to: "Hi")

        let body = try body(stub)
        #expect(body["parallel_tool_calls"] == nil)
        #expect(body["tools"] != nil)
    }

    @Test(arguments: [(GenerationOptions.ToolCallingMode.allowed, JSONValue.string("auto")), (.required, "required")])
    func `a tool-calling mode becomes the tool choice of every round`(mode: GenerationOptions.ToolCallingMode, choice: JSONValue)
        async throws
    {
        let stub = HTTPStub(
            events(toolCall(0, id: "call_1", name: "lookUpFood", arguments: #"{"food":"egg"}"#), done("tool_calls")),
            events(text("An egg has 100 kcal."), done())
        )
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()])

        let response = try await session.respond(to: "Calories in an egg?", options: GenerationOptions(toolCallingMode: mode))

        #expect(response.content == "An egg has 100 kcal.")
        #expect(try body(stub, 0)["tool_choice"] == choice)
        #expect(try body(stub, 1)["tool_choice"] == choice)
        let output = messages(try body(stub, 1)).first { $0["role"] == "tool" }
        #expect(output?["content"] == "egg: 100 kcal")
    }

    @Test func `when tools are disallowed, Foundation Models sends none, so no tool choice goes out`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()])

        _ = try await session.respond(to: "Hi", options: GenerationOptions(toolCallingMode: .disallowed))

        let body = try body(stub)
        #expect(body["tools"] == nil)
        #expect(body["tool_choice"] == nil)
    }

    @Test func `a call without arguments gets an empty object`() async throws {
        let stub = HTTPStub(
            events(toolCall(0, id: "call_1", name: "readClock"), done("tool_calls")),
            events(text("Done."), done())
        )
        let session = LanguageModelSession(model: model(stub), tools: [ClockTool()])

        _ = try await session.respond(to: "What time is it?")

        let assistant = try #require(try assistantMessages(stub, 1).first)
        #expect(assistant["tool_calls"]?[0]?["function"]?["arguments"] == "{}")
    }

    @Test func `argument text that arrives before the call's name joins the call`() async throws {
        let stub = HTTPStub(
            events(
                toolCall(0, arguments: #"{"fo"#),
                toolCall(0, id: "call_1", name: "lookUpFood", arguments: #"od":"#),
                toolCall(0, arguments: #""egg"}"#),
                done("tool_calls")
            ),
            events(text("Done."), done())
        )
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()])

        _ = try await session.respond(to: "Calories in an egg?")

        let assistant = try #require(try assistantMessages(stub, 1).first)
        #expect(assistant["tool_calls"]?[0]?["function"]?["arguments"] == #"{"food":"egg"}"#)
        #expect(messages(try body(stub, 1)).last == ["content": "egg: 100 kcal", "role": "tool", "tool_call_id": "call_1"])
    }

    @Test func `a call without an id gets one, and its output answers that id`() async throws {
        let stub = HTTPStub(
            events(toolCall(0, name: "lookUpFood", arguments: #"{"food":"egg"}"#), done("tool_calls")),
            events(text("Done."), done())
        )
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()])

        _ = try await session.respond(to: "Calories in an egg?")

        let assistant = try #require(try assistantMessages(stub, 1).first)
        let id = try #require(assistant["tool_calls"]?[0]?["id"]?.stringValue)
        #expect(id.hasPrefix("call_"))
        let output = messages(try body(stub, 1)).first { $0["role"] == "tool" }
        #expect(output?["tool_call_id"]?.stringValue == id)
    }

    @Test func `a call that never gets a name throws`() async throws {
        let stub = HTTPStub(events(toolCall(0, id: "call_1", arguments: #"{"food":"egg"}"#), done("tool_calls")))
        let session = LanguageModelSession(model: model(stub), tools: [FoodTool()])

        let error = try await #require(throws: OpenRouterError.self) {
            try await session.respond(to: "Calories in an egg?")
        }

        #expect(error.code == .invalidResponse)
        #expect(stub.requests.count == 1)
    }
}

/// A tool without arguments.
private struct ClockTool: Tool {
    let name = "readClock"
    let description = "Reads the time."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        "09:00"
    }
}
