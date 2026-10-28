import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
    @Suite(
        "Free models",
        .enabled(
            if: ProcessInfo.processInfo.environment["LIVE_FREE"]?.isEmpty == false,
            "Set LIVE_FREE to spend the account's daily free requests"
        )
    )
    struct FreeModels {
        @Test func `a free model answers at no cost`() async throws {
            let session = LanguageModelSession(model: LiveModel(.nvidiaNemotron3_5LightningFree).languageModel)

            do {
                let response = try await session.respond(
                    to: "Reply with the single word: hello",
                    options: GenerationOptions(maximumResponseTokens: 64),
                    contextOptions: ContextOptions(reasoningLevel: .off)
                )
                record(answerMetadata(response), named: "metadata.txt")
                #expect(!response.content.isEmpty)
                #expect(metadataNumber(response.usage.metadata, OpenRouterMetadataKey.cost) == 0)
            } catch let error as LanguageModelError {
                guard case .rateLimited = error else { throw error }
                record(error, named: "error.txt")
                try Test.cancel("The free model is rate limited: \(error)")
            }
        }
    }
}
