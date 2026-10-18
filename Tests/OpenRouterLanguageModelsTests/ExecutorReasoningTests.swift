import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: reasoning")
struct ExecutorReasoningTests {
    @Test func `a typed effort becomes the effort OpenRouter sends`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let model: OpenRouterLanguageModel<Efforts.HighMediumLow> = model(stub, efforts: [.high, .medium, .low])
        let profile = LanguageModelSession.Profile { Instructions("Think.") }.model(model, effort: .high)

        _ = try await LanguageModelSession(profile: profile).respond(to: "Hi")

        #expect(try body(stub)["reasoning"] == ["effort": "high"])
    }

    @Test(arguments: [
        (ContextOptions.ReasoningLevel.deep, "high"),
        (.custom("max"), "high"),
        (.light, "low"),
    ])
    func `a level moves to the nearest effort the model accepts`(level: ContextOptions.ReasoningLevel, effort: String) async throws {
        let stub = HTTPStub(events(text("Hi"), done()))
        let model: OpenRouterLanguageModel<Efforts.HighMediumLow> = model(stub, efforts: [.high, .medium, .low])

        _ = try await LanguageModelSession(model: model).respond(to: "Hi", contextOptions: ContextOptions(reasoningLevel: level))

        #expect(try body(stub)["reasoning"] == ["effort": .string(effort)])
    }

    @Test(arguments: [(ContextOptions.ReasoningLevel.deep, true), (.off, false)])
    func `a model whose effort can't be chosen is told whether to reason`(level: ContextOptions.ReasoningLevel, enabled: Bool) async throws
    {
        let stub = HTTPStub(events(text("Hi"), done()))

        _ = try await LanguageModelSession(model: model(stub)).respond(to: "Hi", contextOptions: ContextOptions(reasoningLevel: level))

        #expect(try body(stub)["reasoning"] == ["enabled": .bool(enabled)])
    }

    @Test func `no reasoning level sends no reasoning setting`() async throws {
        let stub = HTTPStub(events(text("Hi"), done()))

        _ = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")

        #expect(try body(stub)["reasoning"] == nil)
    }

    @Test func `streamed reasoning becomes a reasoning entry and goes back on the next turn`() async throws {
        let stub = HTTPStub(
            events(
                reasoning(["type": "reasoning.text", "text": "Eggs are ", "format": "anthropic-claude-v1", "index": 0]),
                reasoning(["type": "reasoning.text", "text": "light.", "index": 0]),
                reasoning(["type": "reasoning.text", "signature": "sig-1", "index": 0]),
                reasoning(["type": "reasoning.encrypted", "data": "blob", "index": 1]),
                text("About 70 kcal."),
                done(reasoning: 12)
            ),
            events(text("Yes."), done())
        )
        let session = LanguageModelSession(model: model(stub))

        let first = try await session.respond(to: "Calories in an egg?")
        _ = try await session.respond(to: "Sure?")

        let reasoningEntry = first.transcriptEntries.compactMap { entry -> Transcript.Reasoning? in
            if case .reasoning(let reasoning) = entry { reasoning } else { nil }
        }.first
        #expect(reasoningEntry?.segments.count ?? 0 >= 1)
        let assistant = try #require(messages(try body(stub, 1)).first { $0["role"] == "assistant" })
        #expect(assistant["content"] == "About 70 kcal.")
        #expect(assistant["reasoning"] == "Eggs are light.")
        #expect(
            assistant["reasoning_details"] == [
                ["format": "anthropic-claude-v1", "index": 0, "signature": "sig-1", "text": "Eggs are light.", "type": "reasoning.text"],
                ["data": "blob", "index": 1, "type": "reasoning.encrypted"],
            ]
        )
    }

    @Test func `reasoning another provider wrote isn't sent back`() async throws {
        let stub = HTTPStub(events(text("Yes."), done()))
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(segments: [.text(.init(content: "Calories in an egg?"))])),
            .reasoning(Transcript.Reasoning(segments: [.text(.init(content: "Thinking."))], signature: Data("opaque".utf8))),
            .response(Transcript.Response(assetIDs: [], segments: [.text(.init(content: "About 70 kcal."))])),
        ])
        let session = LanguageModelSession(model: model(stub), transcript: transcript)

        _ = try await session.respond(to: "Sure?")

        let assistant = try #require(messages(try body(stub)).first { $0["role"] == "assistant" })
        #expect(assistant == ["content": "About 70 kcal.", "role": "assistant"])
    }

    private func reasoning(_ detail: JSONValue) -> JSONValue {
        chunk(["reasoning_details": [detail]])
    }
}
