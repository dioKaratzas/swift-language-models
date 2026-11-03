import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenAILanguageModels
import Testing

extension LiveTests {
    @Suite("Tools")
    struct Tools {
        /// A prompt that needs the weather in three cities.
        static let threeCities = "What's the temperature in Lisbon, Porto and Madrid? Use the tool for each city."

        @Test(arguments: [LiveModel.nano, .luna])
        func `parallel tool calls form rounds, and the answer uses every output`(model: LiveModel) async throws {
            let session = LanguageModelSession(
                model: try model.languageModel(options: OpenAIOptions(parallelToolCalls: .allowed)), tools: [WeatherTool()])

            let response = try await session.respond(to: Self.threeCities, contextOptions: model.quickContext)

            #expect(Set(try session.transcript.weatherCities()) == ["Lisbon", "Porto", "Madrid"])
            let ids = session.transcript.toolCalls.map(\.id)
            #expect(Set(ids).count == ids.count)
            #expect(response.content.contains("17"))
        }

        @Test func `calls that aren't parallel come one per round`() async throws {
            let session = LanguageModelSession(
                model: try LiveModel.nano.languageModel(options: OpenAIOptions(parallelToolCalls: .disallowed)), tools: [WeatherTool()])

            let response = try await session.respond(to: Self.threeCities, contextOptions: LiveModel.nano.quickContext)

            for case .toolCalls(let calls) in session.transcript { #expect(calls.count == 1) }
            #expect(Set(try session.transcript.weatherCities()) == ["Lisbon", "Porto", "Madrid"])
            #expect(response.content.contains("17"))
        }

        @Test(
            arguments: [
                (LiveModel.nano, OpenAIOptions.Storage.notStored), (.nano, .automatic), (.luna, .notStored), (.luna, .automatic),
            ] as [(LiveModel, OpenAIOptions.Storage)])
        func `reasoning items go back on later turns, encrypted, whether or not OpenAI keeps the response`(
            model: LiveModel, storage: OpenAIOptions.Storage
        ) async throws {
            let session = LanguageModelSession(
                model: try model.languageModel(options: OpenAIOptions(storage: storage)), tools: [WeatherTool()])

            let first = try await session.respond(
                to: "What's the temperature in Lisbon and Porto?", contextOptions: ContextOptions(reasoningLevel: .light))
            let second = try await session.respond(to: "And in Madrid?", contextOptions: ContextOptions(reasoningLevel: .light))

            #expect(first.content.contains("17"))
            #expect(second.content.contains("17"))
            let items = try reasoningEntries(in: session.transcript).flatMap { reasoning -> [JSONValue] in
                guard let signature = reasoning.signature, case .array(let items) = try JSONValue(json: signature) else { return [] }
                return items
            }
            // GPT-5 nano always reasons; GPT-6 Luna may not reason at all for easy calls.
            if model.quickLevel != .off { #expect(!items.isEmpty) }
            #expect(items.allSatisfy { $0["type"] == "reasoning" && $0["encrypted_content"]?.stringValue?.isEmpty == false })
            record(lastAnswer(in: session.transcript)?.metadata ?? [:], named: "metadata.txt")
        }

        @Test func `a session switched from stored to not stored responses still answers`() async throws {
            var model = try LiveModel.nano.languageModel()
            let first = LanguageModelSession(model: model, tools: [WeatherTool()])
            _ = try await first.respond(to: "What's the temperature in Lisbon?", contextOptions: ContextOptions(reasoningLevel: .light))
            model.options.storage = .notStored
            let second = LanguageModelSession(model: model, tools: [WeatherTool()], transcript: first.transcript)

            let response = try await second.respond(to: "And in Porto?", contextOptions: ContextOptions(reasoningLevel: .light))

            #expect(response.content.contains("17"))
        }

        @Test func `a required tool call is made`() async throws {
            let session = LanguageModelSession(model: try LiveModel.nano.languageModel(), tools: [InterruptingWeatherTool()])

            let response = try await respondUntilToolCall(
                session, to: "Say hello.", options: GenerationOptions(toolCallingMode: .required))

            #expect(response == nil)
            #expect(session.transcript.toolCalls.first?.toolName == "getWeather")
        }

        @Test func `a tool without arguments is called with an empty object`() async throws {
            let session = LanguageModelSession(model: try LiveModel.nano.languageModel(), tools: [AccessCodeTool()])

            let response = try await session.respond(
                to: "Get the access code with the tool, then reply with it only.", contextOptions: LiveModel.nano.quickContext)

            #expect(response.content.contains("K7Q2"))
        }
    }
}

/// A tool that takes no arguments, whose answer the model can't know.
private struct AccessCodeTool: Tool {
    let name = "getAccessCode"
    let description = "Gets today's access code."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        "The access code is K7Q2."
    }
}
