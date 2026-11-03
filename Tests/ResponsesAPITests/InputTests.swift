import APIFormat
import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import ResponsesAPI

@Suite("Input")
struct InputTests {
    @Test func `instructions, prompts, answers and tool outputs become messages, function calls and their outputs`() throws {
        let call = Transcript.ToolCall(id: "call_1", toolName: "lookUp", arguments: GeneratedContent(properties: ["word": "egg"]))
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [text("Be brief.")], toolDefinitions: [])),
            prompt(text("Define egg.")),
            .response(Transcript.Response(assetIDs: [], segments: [text("Looking it up.")])),
            .toolCalls(Transcript.ToolCalls([call])),
            .toolOutput(Transcript.ToolOutput(id: "call_1", toolName: "lookUp", segments: [text("egg:"), text("an oval")])),
        ]

        let items = input(try ResponsesRequest(generationRequest(entries), dialect: TestDialect()).body)

        #expect(
            items == [
                ["role": "developer", "content": "Be brief."],
                ["role": "user", "content": "Define egg."],
                ["role": "assistant", "content": "Looking it up."],
                ["type": "function_call", "call_id": "call_1", "name": "lookUp", "arguments": #"{"word":"egg"}"#],
                ["type": "function_call_output", "call_id": "call_1", "output": "egg:\nan oval"],
            ])
    }

    @Test func `the instructions go in the dialect's role`() throws {
        var setup = TestModel.Setup()
        setup.instructionsRole = .system
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [text("Be brief.")], toolDefinitions: [])), prompt(text("Hi")),
        ]

        let items = input(try ResponsesRequest(generationRequest(entries), dialect: TestDialect(setup)).body)

        #expect(items.first == ["role": "system", "content": "Be brief."])
    }

    @Test func `the provider's own reasoning items go back before the message, with its phase, and another's don't`() throws {
        let reasoningItem: JSONValue = [
            "type": "reasoning", "id": "rs_1", "summary": [["type": "summary_text", "text": "Think."]], "encrypted_content": "blob",
        ]
        let own = Transcript.Reasoning(
            metadata: [ReasoningOrigin.metadataKey: "test-responses"], segments: [text("Think.")],
            signature: JSONValue.array([reasoningItem]).data)
        let other = Transcript.Reasoning(
            metadata: [ReasoningOrigin.metadataKey: "openrouter"], segments: [text("Other.")],
            signature: JSONValue.array([["type": "reasoning", "id": "rs_0"]]).data)
        let entries: [Transcript.Entry] = [
            prompt(text("Hi")), .reasoning(other), .reasoning(own),
            .response(Transcript.Response(metadata: ["test.phase": "final_answer"], segments: [text("Hello.")])),
        ]

        let items = input(try ResponsesRequest(generationRequest(entries), dialect: TestDialect()).body)

        #expect(Array(items.dropFirst()) == [reasoningItem, ["role": "assistant", "content": "Hello.", "phase": "final_answer"]])
    }

    @Test func `a request the provider doesn't store sends back only reasoning items with their reasoning encrypted`() throws {
        let encrypted: JSONValue = ["type": "reasoning", "id": "rs_1", "summary": [], "encrypted_content": "blob"]
        let stored: JSONValue = ["type": "reasoning", "id": "rs_2", "summary": []]
        let reasoning = Transcript.Reasoning(
            metadata: [ReasoningOrigin.metadataKey: "test-responses"], segments: [],
            signature: JSONValue.array([encrypted, stored]).data)
        let entries: [Transcript.Entry] = [
            prompt(text("Hi")), .reasoning(reasoning), .response(Transcript.Response(assetIDs: [], segments: [text("Hello.")])),
            prompt(text("Again.")),
        ]
        var setup = TestModel.Setup()
        setup.plan = { _ in
            var plan = BodyPlan<JSONValue>(extras: [:])
            plan.storage = .notStored
            return plan
        }

        let notStored = input(try ResponsesRequest(generationRequest(entries), dialect: TestDialect(setup)).body)
        let automatic = input(try ResponsesRequest(generationRequest(entries), dialect: TestDialect()).body)

        #expect(notStored.filter { $0["type"] == "reasoning" } == [encrypted])
        #expect(automatic.filter { $0["type"] == "reasoning" } == [encrypted, stored])
    }

    @Test func `an answer that ends in tool calls keeps its message's phase on its first call`() throws {
        let call = Transcript.ToolCall(
            id: "call_1", metadata: ["test.phase": "commentary"], toolName: "lookUp",
            arguments: GeneratedContent(properties: ["word": "egg"]))
        let entries: [Transcript.Entry] = [
            prompt(text("Define egg.")), .response(Transcript.Response(assetIDs: [], segments: [text("Looking it up.")])),
            .toolCalls(Transcript.ToolCalls([call])),
        ]

        let items = input(try ResponsesRequest(generationRequest(entries), dialect: TestDialect()).body)

        #expect(items[1] == ["role": "assistant", "content": "Looking it up.", "phase": "commentary"])
    }

    @Test func `a labeled image goes as its label, then an image the model sees at the detail it picks`() throws {
        let image = Transcript.ImageAttachment(try #require(TestImage.halves(width: 8, height: 4)))
        let entries = [prompt(text("What's this?"), .attachment(.init(content: .image(image), label: "Photo")))]

        let sent = try ResponsesRequest(generationRequest(entries), dialect: TestDialect())
        let content = input(sent.body).first?["content"]

        #expect(content?[0] == ["type": "input_text", "text": "What's this?"])
        #expect(content?[1] == ["type": "input_text", "text": "Photo"])
        #expect(keys(content?[2]) == ["type", "image_url", "detail"])
        #expect(content?[2]?["image_url"]?.stringValue?.hasPrefix("data:image/jpeg;base64,") == true)
        #expect(content?[2]?["detail"] == "auto")
        #expect(sent.imageEntries.map(\.id) == entries.map(\.id))
    }
}
