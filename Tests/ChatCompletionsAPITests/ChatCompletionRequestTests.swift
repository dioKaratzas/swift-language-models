import Foundation
import FoundationModels
import LanguageModels
import Testing

@testable import ChatCompletionsAPI

@Suite("Chat completion request")
struct ChatCompletionRequestTests {
    @Test func `the format writes its members in a fixed order`() throws {
        let options = GenerationOptions(
            samplingMode: .random(probabilityThreshold: 0.5, seed: 1), temperature: 0.2, maximumResponseTokens: 10)
        let request = generationRequest([prompt(text("Hi"))], options: options, metadata: ["team": "coach"])

        let body = try ChatCompletionRequest(request, provider: TestProvider()).body

        #expect(keys(body) == ["model", "messages", "stream", "temperature", "top_p", "seed", "max_completion_tokens", "metadata"])
        #expect(body["model"] == "vendor/model")
        #expect(body["stream"] == true)
    }

    @Test func `the provider changes the finished body, and orders its members`() throws {
        var provider = TestProvider()
        provider.transform = { body in
            body.members["models"] = ["vendor/fallback"]
            body.members["plugins"] = []
            body.members = body.members.ordered(by: ["model", "models", "messages"])
        }

        let body = try ChatCompletionRequest(generationRequest([prompt(text("Hi"))]), provider: provider).body

        #expect(keys(body) == ["model", "models", "messages", "stream", "plugins"])
    }

    @Test func `members the models don't list are left out and noted in body order, before metadata left out`() throws {
        var provider = TestProvider()
        provider.transform = { body in
            body.noteMovedEffort(requested: "medium", sent: "low")
            body.leaveOut(["temperature", "max_completion_tokens", "top_p"], unlessListed: { $0 == "top_p" })
        }
        let options = GenerationOptions(
            samplingMode: .random(probabilityThreshold: 0.5, seed: 1), temperature: 0.2, maximumResponseTokens: 10)
        let request = generationRequest([prompt(text("Hi"))], options: options, metadata: ["count": 3])

        let completion = try ChatCompletionRequest(request, provider: provider)

        #expect(keys(completion.body) == ["model", "messages", "stream", "top_p", "seed"])
        #expect(
            completion.adjustments == [
                .unlistedParameters(["temperature", "max_completion_tokens"]), .droppedMetadata(keys: ["count"]),
                .movedEffort(requested: "medium", sent: "low"),
            ])
    }

    @Test func `a schema goes as strict structured outputs, with a portable body for a host that rejects a constraint`() throws {
        let request = generationRequest([prompt(text("Rate it."))], schema: Rating.generationSchema)

        let completion = try ChatCompletionRequest(request, provider: TestProvider())

        let format = try #require(completion.body["response_format"])
        #expect(format["type"] == "json_schema")
        #expect(format["json_schema"]?["name"] == "Rating")
        #expect(format["json_schema"]?["strict"] == true)
        #expect(format["json_schema"]?["schema"]?["properties"]?["stars"]?["maximum"] == 5)
        let portable = try #require(completion.portableSchemaBody?["response_format"]?["json_schema"]?["schema"])
        #expect(portable["properties"]?["stars"]?["maximum"] == nil)
    }

    @Test func `a provider that sends the portable schema from the start has no body to retry with`() throws {
        var provider = TestProvider()
        provider.transform = { body in try body.sendPortableSchema() }
        let request = generationRequest([prompt(text("Rate it."))], schema: Rating.generationSchema)

        let completion = try ChatCompletionRequest(request, provider: provider)

        #expect(completion.body["response_format"]?["json_schema"]?["schema"]?["properties"]?["stars"]?["maximum"] == nil)
        #expect(completion.portableSchemaBody == nil)
    }

    @Test func `tools go as functions, with the tool choice the options ask for`() throws {
        let request = generationRequest(
            [prompt(text("Hi"))], tools: [Transcript.ToolDefinition(tool: LookUpTool())],
            options: GenerationOptions(toolCallingMode: .required))

        let body = try ChatCompletionRequest(request, provider: TestProvider()).body

        #expect(body["tools"]?[0]?["type"] == "function")
        #expect(body["tools"]?[0]?["function"]?["name"] == "lookUp")
        #expect(body["tool_choice"] == "required")
    }

    @Test func `the last instructions' last part carries the provider's marks`() throws {
        var provider = TestProvider()
        provider.transform = { body in body.markLastInstructions(with: ["cache_control": ["type": "ephemeral"]]) }
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [text("Be brief.")], toolDefinitions: [])), prompt(text("Hi")),
        ]

        let sent = messages(try ChatCompletionRequest(generationRequest(entries), provider: provider).body)

        #expect(sent.first?["content"] == [["type": "text", "text": "Be brief.", "cache_control": ["type": "ephemeral"]]])
    }
}

/// A rating whose stars have a range, which the portable schema moves into the description.
@Generable
struct Rating {
    @Guide(.range(1...5))
    var stars: Int
}

/// A tool that looks up a word.
struct LookUpTool: Tool {
    let name = "lookUp"
    let description = "Looks up a word."

    @Generable
    struct Arguments {
        var word: String
    }

    func call(arguments: Arguments) async throws -> String {
        arguments.word
    }
}
