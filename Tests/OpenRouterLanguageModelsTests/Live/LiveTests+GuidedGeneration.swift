import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
    @Suite("Guided generation")
    struct GuidedGeneration {
        /// Models with strict structured outputs. The Anthropic alias shows that a schema written for Anthropic also
        /// goes to a model named through `~`.
        static let models = [
            LiveModel(.openaiGpt4_1Nano),
            LiveModel(.anthropicClaudeHaiku5_5),
            LiveModel(.anthropicClaudeHaikuLatest),
            LiveModel(.googleGemini2_5FlashLite),
            LiveModel(.deepseekDeepseekV4Flash),
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

        @Test func `a streamed list of forty items grows to all of them`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            var counts: [Int] = []
            var last: GeneratedContent?
            let stream = session.streamResponse(to: "List forty things to pack for a week of hiking.", generating: PackingList.self)
            for try await snapshot in stream {
                counts.append(snapshot.content.items?.count ?? 0)
                last = snapshot.rawContent
            }
            let list = try PackingList(try #require(last))

            record(list.items, named: "items.txt")
            #expect(list.items.count == 40)
            #expect(counts.count > 1)
            #expect(counts == counts.sorted())
        }

        /// How many times each model answers the same request, to see how often its answers decode.
        static let tries = 5

        /// Models with strict structured outputs, whose host holds the answer to the schema.
        static let strictModels = [LiveModel(.openaiGpt4_1Nano), LiveModel(.googleGemini2_5FlashLite)]

        /// Models with only JSON mode, which can't hold their answers to a schema.
        static let jsonModeModels = [LiveModel(.qwenQwen3_7Flash), LiveModel(.inclusionaiLing3_0Flash)]

        @Test(arguments: strictModels)
        func `a strict schema's answer decodes on every try`(model: LiveModel) async throws {
            var trips: [Trip] = []
            for _ in 0..<Self.tries {
                let session = LanguageModelSession(model: model.languageModel)
                trips.append(try await session.respond(to: "Plan a short trip to Lisbon.", generating: Trip.self).content)
            }

            record(trips, named: "trips.txt")
            #expect(trips.count == Self.tries)
            #expect(trips.allSatisfy { $0.activities.count == 3 && (1...14).contains($0.days) })
        }

        @Test(arguments: jsonModeModels)
        func `a model with only JSON mode is refused before any request`(model: LiveModel) async throws {
            let session = LanguageModelSession(model: model.languageModel)

            let error = try await #require(throws: LanguageModelError.self) {
                try await session.respond(to: "Plan a short trip to Lisbon.", generating: Trip.self)
            }

            record(error, named: "error.txt")
            guard case .unsupportedCapability = error else {
                Issue.record("Expected an unsupported capability, got \(error)")
                return
            }
        }

        @Test func `an answer cut off inside its JSON throws the parsing error`() async throws {
            let session = LanguageModelSession(model: LiveModel(.openaiGpt4_1Nano).languageModel)

            let error = try await #require(throws: GeneratedContent.ParsingError.self) {
                try await session.respond(
                    to: "Plan a short trip to Lisbon.", generating: Trip.self, options: GenerationOptions(maximumResponseTokens: 8))
            }

            record(error, named: "error.txt")
        }

        @Test func `a model with neither structured outputs nor JSON mode is refused before any request`() async throws {
            let session = LanguageModelSession(model: LiveModel(.metaLlamaLlama3_2_1bInstruct).languageModel)

            let error = try await #require(throws: LanguageModelError.self) {
                try await session.respond(to: "Plan a short trip to Lisbon.", generating: Trip.self)
            }

            record(error, named: "error.txt")
            guard case .unsupportedCapability = error else {
                Issue.record("Expected an unsupported capability, got \(error)")
                return
            }
        }
    }
}

/// A list long enough to stream in many snapshots.
@Generable
private struct PackingList {
    @Guide(description: "Forty short items, each a few words.", .count(40))
    var items: [String]
}
