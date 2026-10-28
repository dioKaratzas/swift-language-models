import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
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
            let cities = try session.transcript.weatherCities()
            #expect(cities.contains { $0.localizedCaseInsensitiveContains("Lisbon") })
            #expect(cities.contains { $0.localizedCaseInsensitiveContains("Porto") })

            let reasoning = try #require(reasoningEntries(in: first.transcriptEntries).first)
            let details = try reasoningDetails(of: reasoning)
            record(details, named: "reasoning-details.txt")
            #expect(!details.isEmpty)
            if model.signsReasoning {
                #expect(details.contains { $0["signature"]?.stringValue != nil || $0["data"]?.stringValue != nil })
            }
        }
    }
}
