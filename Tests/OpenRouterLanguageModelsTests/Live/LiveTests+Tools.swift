import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
    @Suite("Tools")
    struct Tools {
        /// Models that call tools in parallel. Gemini can send parallel calls that share an index or an id.
        static let parallelModels = [LiveModel(.openaiGpt4_1Nano), LiveModel(.googleGemini2_5FlashLite)]

        /// Models that may leave out the arguments of a tool without parameters, or reject its empty schema.
        static let noArgumentModels = [LiveModel(.googleGemini2_5FlashLite), LiveModel(.anthropicClaudeHaiku4_5)]

        /// Also probes risk 4: calls that share an index would merge into one call with both arguments.
        @Test(arguments: parallelModels)
        func `calls for three cities get one call each with its own id`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, tools: [WeatherTool()])

            let response = try await session.respond(
                to: "How warm is it in Lisbon, Porto and Madrid right now? Use the tool once for each city."
            )

            record(session.transcript, named: "transcript.txt")
            // A model may call the tool one city at a time, so the calls are counted across rounds.
            let calls = session.transcript.toolCalls
            #expect(Set(calls.map(\.id)).count == calls.count)
            let cities = try session.transcript.weatherCities()
            for city in ["Lisbon", "Porto", "Madrid"] {
                #expect(cities.contains { $0.localizedCaseInsensitiveContains(city) }, "No call for \(city)")
            }
            #expect(response.content.contains("17"))
        }

        @Test(arguments: noArgumentModels)
        func `a tool without arguments runs and its answer reaches the reply`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, tools: [AccessCodeTool()])

            let response = try await session.respond(to: "What is today's access code? Use the tool.")

            record(session.transcript, named: "transcript.txt")
            #expect(session.transcript.toolCalls.contains { $0.toolName == "getAccessCode" })
            #expect(response.content.contains("K7Q2"))
        }

        /// The backslash sits inside the text, since a model tends to mangle a trailing one.
        @Test func `tool arguments keep their Unicode and escapes, and the stream ends with the answer`() async throws {
            let text = #"Grüße 👋🏽 日本語 "q" \ 🇵🇹 end"#
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel, tools: [EchoTool()])

            var snapshots: [String] = []
            let stream = session.streamResponse(
                to: "Call the echo tool once with exactly this text, then reply with what it returned: \(text)"
            )
            for try await snapshot in stream {
                snapshots.append(snapshot.content)
            }

            record(session.transcript, named: "transcript.txt")
            let call = try #require(session.transcript.toolCalls.first { $0.toolName == "echo" })
            let echoed = try call.arguments.value(String.self, forProperty: "text")
            #expect(echoed.precomposedStringWithCanonicalMapping == text.precomposedStringWithCanonicalMapping)
            // Each round of a tool loop streams anew, so only the last snapshot has to be the answer.
            let answer = try #require(lastAnswer(in: session.transcript))
            #expect(snapshots.last == plainText(answer.segments))
        }

        @Test func `a required tool call comes even for a prompt that needs none`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel, tools: [InterruptingWeatherTool()])

            let response = try await respondUntilToolCall(session, to: "Say hello.", options: GenerationOptions(toolCallingMode: .required))

            record(session.transcript, named: "transcript.txt")
            #expect(response == nil, "The model answered without calling the tool: \(response?.content ?? "")")
            #expect(session.transcript.toolCalls.contains { $0.toolName == "getWeather" })
        }
    }
}

/// A tool without arguments, whose answer the model can't know.
private struct AccessCodeTool: Tool {
    let name = "getAccessCode"
    let description = "Gets today's access code. It takes no arguments."

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        "Today's access code is K7Q2."
    }
}

/// A tool that returns its text, for checking how arguments survive the trip.
private struct EchoTool: Tool {
    let name = "echo"
    let description = "Returns the given text unchanged."

    @Generable
    struct Arguments {
        @Guide(description: "The text to return, exactly as given.")
        var text: String
    }

    func call(arguments: Arguments) async throws -> String {
        arguments.text
    }
}
