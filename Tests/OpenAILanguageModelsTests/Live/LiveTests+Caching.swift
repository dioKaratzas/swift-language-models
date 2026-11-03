import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenAILanguageModels
import Testing

extension LiveTests {
    @Suite("Caching")
    struct Caching {
        @Test(arguments: [LiveModel.nano, .luna])
        func `a repeated long prefix with a cache key reads from OpenAI's cache`(model: LiveModel) async throws {
            let run = UUID().uuidString
            let instructions = "Run \(run). " + String(repeating: "Answer in one short sentence, and stay polite. ", count: 300)
            let options = OpenAIOptions(cacheKey: .named(run), endUserID: "live-tests")
            var cached: [Int] = []

            for attempt in 1...3 {
                let session = LanguageModelSession(model: try model.languageModel(options: options), instructions: instructions)
                let response = try await session.respond(
                    to: "Say hello.", options: GenerationOptions(maximumResponseTokens: 32), contextOptions: model.quickContext)
                cached.append(response.usage.input.cachedTokenCount)
                if response.usage.input.cachedTokenCount > 0 { break }
                if attempt < 3 { try await Task.sleep(for: .seconds(2)) }
            }

            record(cached, named: "cached.txt")
            #expect(cached.first == 0)
            withKnownIssue("OpenAI's cache doesn't always serve a prefix this soon.", isIntermittent: true) {
                #expect(cached.dropFirst().contains { $0 >= 1_024 })
            }
        }
    }
}
