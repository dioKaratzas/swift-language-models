import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

/// Requests to real models through OpenRouter, for what only a provider can show: which schemas it accepts, how it
/// caches, what it needs replayed and how it fails. A full run costs about a cent.
@Suite(
    "Live: OpenRouter",
    .tags(.live),
    .requiresAPIKey("OPENROUTER_API_KEY"),
    .serialized,
    .timeLimit(.minutes(2))
)
struct LiveTests {
    /// A response limit for answers of a few words.
    static let short = GenerationOptions(maximumResponseTokens: 16)

    @Suite("Text")
    struct Text {
        @Test func `a cheap model answers with its usage, cost and host`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            let response = try await session.respond(to: "Reply with the single word: hello", options: LiveTests.short)

            record(response, named: "response.txt")
            #expect(response.content.localizedCaseInsensitiveContains("hello"))
            #expect(response.usage.input.totalTokenCount > 0)
            #expect(response.usage.output.totalTokenCount > 0)
            #expect((metadataNumber(response.usage.metadata, OpenRouterMetadataKey.cost) ?? 0) > 0)
            let answer = try #require(lastAnswer(in: response.transcriptEntries))
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.model)?.hasPrefix("openai/gpt-4.1-nano") == true)
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.provider) != nil)
            #expect(metadataString(answer.metadata, OpenRouterMetadataKey.generationID)?.hasPrefix("gen-") == true)
        }

        @Test func `a streamed answer grows with each snapshot`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            var snapshots: [String] = []
            let stream = session.streamResponse(
                to: "Count from 1 to 10, separated by spaces.",
                options: GenerationOptions(maximumResponseTokens: 64)
            )
            for try await snapshot in stream {
                snapshots.append(snapshot.content)
            }

            let answer = try #require(snapshots.last)
            #expect(answer.contains("10"))
            #expect(snapshots.allSatisfy { answer.hasPrefix($0) })
        }

        @Test func `a session remembers its earlier turns`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            _ = try await session.respond(to: "My favorite color is teal. Reply with OK.", options: LiveTests.short)
            let response = try await session.respond(to: "What is my favorite color? Reply with one word.", options: LiveTests.short)

            #expect(response.content.localizedCaseInsensitiveContains("teal"))
        }

        @Test func `an answer cut short by the token limit keeps its text`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            let response = try await session.respond(to: "Count from 1 to 200, separated by spaces.", options: LiveTests.short)

            #expect(!response.content.isEmpty)
            #expect(response.usage.output.totalTokenCount <= 16)
        }
    }

    @Suite("Guided generation")
    struct GuidedGeneration {
        /// Models with strict structured outputs, and one with only JSON mode.
        static let models = [
            LiveModel(.openaiGpt4_1Nano),
            LiveModel(.anthropicClaudeHaiku5_5),
            LiveModel(.googleGemini2_5FlashLite),
            LiveModel(.deepseekDeepseekV4Flash),
            LiveModel(.qwenQwen3_7Flash),
        ]

        @Test(arguments: models)
        func `the provider accepts the schema and its answer decodes`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel)

            let trip = try await session.respond(to: "Plan a short trip to Lisbon.", generating: Trip.self).content

            record(trip, named: "trip.txt")
            #expect(trip.activities.count == 3)
            #expect((1...14).contains(trip.days))
            #expect(trip.activities.allSatisfy { (1...12).contains($0.hours) })
        }
    }

    @Suite("Caching")
    struct Caching {
        /// Models that cache on their own or with markers, but don't promise a hit.
        static let bestEffortModels = [
            LiveModel(.openaiGpt4_1Nano),
            LiveModel(.googleGemini2_5FlashLite, cacheControl: .ephemeral),
            LiveModel(.deepseekDeepseekV4Flash),
            LiveModel(.qwenQwen3_7Flash, cacheControl: .ephemeral),
        ]

        @Test func `a marked prompt is written on the first turn and read on the next`() async throws {
            let model = LiveModel(.anthropicClaudeHaiku5_5, cacheControl: .ephemeral)
            let session = LanguageModelSession(model: model.languageModel, instructions: longInstructions(tokens: 2_500))

            let first = try await session.respond(to: "Reply with OK.", options: LiveTests.short)
            let second = try await session.respond(to: "Reply with OK again.", options: LiveTests.short)

            record([first.usage, second.usage], named: "usage.txt")
            #expect(first.usage.input.cachedTokenCount == 0)
            #expect((metadataNumber(first.usage.metadata, OpenRouterMetadataKey.cacheWriteTokenCount) ?? 0) > 0)
            #expect(second.usage.input.cachedTokenCount >= 2_000)
            #expect(second.usage.input.cachedTokenCount <= second.usage.input.totalTokenCount)
            let firstCost = try #require(metadataNumber(first.usage.metadata, OpenRouterMetadataKey.cost))
            let secondCost = try #require(metadataNumber(second.usage.metadata, OpenRouterMetadataKey.cost))
            #expect(secondCost < firstCost)
        }

        @Test(arguments: bestEffortModels)
        func `a later turn reads the cached prompt`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, instructions: longInstructions(tokens: 4_500))

            var turns: [LanguageModelSession.Response<String>] = []
            for turn in 1...3 {
                turns.append(try await session.respond(to: "Reply with OK for turn \(turn).", options: LiveTests.short))
                if turn > 1, turns[turn - 1].usage.input.cachedTokenCount > 0 { break }
                try await Task.sleep(for: .seconds(2))
            }

            record(turns.map(\.usage), named: "usage.txt")
            for response in turns {
                #expect(response.usage.input.cachedTokenCount <= response.usage.input.totalTokenCount)
            }
            withKnownIssue("This provider caches when it can, not on every request.", isIntermittent: true) {
                #expect(turns.dropFirst().contains { $0.usage.input.cachedTokenCount > 0 })
            }
        }

        /// Instructions of about the given length, starting with a value new to this run, so the first turn writes
        /// the cache instead of reading an earlier run's.
        private func longInstructions(tokens: Int) -> String {
            // Each rule is about 17 tokens.
            let rules = (1...(tokens / 17 + 1)).map { number in
                "Rule \(number): when asked about item \(number), answer with the code \(String(number, radix: 36).uppercased())."
            }
            return (["Run \(UUID().uuidString). Follow these rules."] + rules).joined(separator: "\n")
        }
    }

    @Suite("Reasoning")
    struct Reasoning {
        /// Models that reason, at a level that keeps them reasoning. Haiku 4.5 thinks on every request with reasoning
        /// on, where Haiku 5.5's adaptive thinking skips a simple turn.
        static let models = [
            LiveModel(.anthropicClaudeHaiku4_5, signsReasoning: true),
            LiveModel(.googleGemini3_1FlashLite, signsReasoning: true),
            LiveModel(.openaiGpt5Nano, signsReasoning: true),
            LiveModel(.deepseekDeepseekV4Flash, reasoningLevel: .deep),
        ]

        @Test(arguments: models)
        func `reasoning replays through a tool loop and the next turn`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel, tools: [WeatherTool()])
            let options = ContextOptions(reasoningLevel: model.reasoningLevel)

            let first = try await session.respond(to: "How warm is it in Lisbon right now? Use the tool.", contextOptions: options)
            let second = try await session.respond(to: "And in Porto? Use the tool.", contextOptions: options)

            record(session.transcript, named: "transcript.txt")
            #expect(first.content.contains("17"))
            #expect(second.content.contains("17"))
            let cities = try session.transcript.toolCalls.map { try $0.arguments.value(String.self, forProperty: "city") }
            #expect(cities.contains { $0.localizedCaseInsensitiveContains("Lisbon") })
            #expect(cities.contains { $0.localizedCaseInsensitiveContains("Porto") })

            let reasoning = try #require(
                first.transcriptEntries.compactMap { entry in if case .reasoning(let reasoning) = entry { reasoning } else { nil } }.first
            )
            guard case .array(let details) = try JSONValue(json: try #require(reasoning.signature)) else {
                Issue.record("The reasoning's signature isn't a list of details.")
                return
            }
            record(details, named: "reasoning-details.txt")
            #expect(!details.isEmpty)
            if model.signsReasoning {
                #expect(details.contains { $0["signature"]?.stringValue != nil || $0["data"]?.stringValue != nil })
            }
        }
    }

    @Suite("Errors")
    struct Errors {
        @Test func `a rejected key throws OpenRouter's 401`() async throws {
            let model = OpenRouterLanguageModel(.openaiGpt4_1Nano) { "sk-or-v1-not-a-key" }

            let error = try await #require(throws: OpenRouterError.self) {
                try await LanguageModelSession(model: model).respond(to: "Hi", options: LiveTests.short)
            }

            record(error, named: "error.txt")
            #expect(error.status == 401)
        }

        @Test func `an unknown model is rejected`() async throws {
            let details = OpenRouterModel<ContextOptions.ReasoningLevel>(
                id: "swift-language-models/no-such-model",
                displayName: "No such model",
                releaseDate: .now,
                supportedParameters: []
            )
            let model = LiveModel(details).languageModel

            let error = try await #require(throws: OpenRouterError.self) {
                try await LanguageModelSession(model: model).respond(to: "Hi")
            }

            record(error, named: "error.txt")
            #expect([400, 404].contains(error.status))
        }

        @Test func `a prompt longer than the context throws with both sizes`() async throws {
            let session = LanguageModelSession(model: LiveModel(.microsoftPhi4).languageModel)

            let error = try await #require(throws: LanguageModelError.self) {
                try await session.respond(to: String(repeating: "word ", count: 20_000), options: LiveTests.short)
            }

            record(error, named: "error.txt")
            guard case .contextSizeExceeded(let context) = error else {
                Issue.record("Expected the context size to be exceeded, got \(error)")
                return
            }
            #expect(context.contextSize == 16_384)
            #expect(context.tokenCount > 16_384)
        }
    }
}

/// A catalog model under test, with what the tests need to know about it.
struct LiveModel: Sendable, CustomTestStringConvertible {
    /// The model's details, with its efforts as reasoning levels.
    let details: OpenRouterModel<ContextOptions.ReasoningLevel>

    /// How long marked prompts stay cached, for a model that caches only marked prompts.
    let cacheControl: OpenRouterCacheControl?

    /// A level that keeps the model reasoning at little cost.
    let reasoningLevel: ContextOptions.ReasoningLevel

    /// Whether the model's reasoning comes back signed or encrypted, for the provider to check when it's replayed.
    let signsReasoning: Bool

    init(
        _ details: OpenRouterModel<some ModelEffort>,
        cacheControl: OpenRouterCacheControl? = nil,
        reasoningLevel: ContextOptions.ReasoningLevel = .light,
        signsReasoning: Bool = false
    ) {
        self.details = OpenRouterModel(details)
        self.cacheControl = cacheControl
        self.reasoningLevel = reasoningLevel
        self.signsReasoning = signsReasoning
    }

    var testDescription: String { details.id.rawValue }

    /// The model, reading the key from the environment.
    var languageModel: OpenRouterLanguageModel<ContextOptions.ReasoningLevel> {
        OpenRouterLanguageModel(details, cacheControl: cacheControl, appName: "swift-language-models tests") {
            ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""
        }
    }
}

/// A tool whose answer the model can't know, so an answer with it shows the tool ran.
private struct WeatherTool: Tool {
    let name = "getWeather"
    let description = "Gets the current temperature in a city, in degrees Celsius."

    @Generable
    struct Arguments {
        @Guide(description: "The city's name.")
        var city: String
    }

    func call(arguments: Arguments) async throws -> String {
        "It is 17 degrees in \(arguments.city)."
    }
}

/// A plan with the schema features providers differ on: a nested type, an enum, an exact count, ranges and an
/// optional property.
@Generable
private struct Trip {
    @Guide(description: "The city to visit.")
    var city: String

    var season: Season

    @Guide(description: "Three things to do.", .count(3))
    var activities: [Activity]

    @Guide(description: "How many days to stay.", .range(1...14))
    var days: Int

    var note: String?
}

@Generable
private enum Season {
    case spring, summer, autumn, winter
}

@Generable
private struct Activity {
    var name: String

    @Guide(description: "How many hours it takes.", .range(1...12))
    var hours: Int
}

extension Transcript {
    /// Every tool call in the transcript, in order.
    fileprivate var toolCalls: [Transcript.ToolCall] {
        flatMap { entry -> [Transcript.ToolCall] in
            if case .toolCalls(let calls) = entry { Array(calls) } else { [] }
        }
    }
}

/// The last answer among the entries.
private func lastAnswer(in entries: some Sequence<Transcript.Entry>) -> Transcript.Response? {
    entries.compactMap { entry in if case .response(let answer) = entry { answer } else { nil } }.last
}

/// Attaches a value to the test's results, for reading what a provider returned.
private func record(_ value: Any, named name: String) {
    Attachment.record(String(describing: value), named: name)
}
