import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
    @Suite("Guided generation")
    struct GuidedGeneration {
        /// Models with strict structured outputs, and one with only JSON mode. The Anthropic alias shows that a schema
        /// written for Anthropic also goes to a model named through `~`.
        static let models = [
            LiveModel(.openaiGpt4_1Nano),
            LiveModel(.anthropicClaudeHaiku5_5),
            LiveModel(.anthropicClaudeHaikuLatest),
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
    }
}

/// A list long enough to stream in many snapshots.
@Generable
private struct PackingList {
    @Guide(description: "Forty short items, each a few words.", .count(40))
    var items: [String]
}
