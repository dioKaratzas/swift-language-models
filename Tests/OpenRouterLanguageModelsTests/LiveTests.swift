import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
import OpenRouterLanguageModels
import Testing

@Suite("Live: OpenRouter", .tags(.live), .requiresAPIKey("OPENROUTER_API_KEY"))
struct LiveTests {
    @Test func `a cheap model answers a short prompt`() async throws {
        let model = OpenRouterLanguageModel(.openaiGpt4_1Nano, appName: "swift-language-models tests") {
            ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""
        }
        let session = LanguageModelSession(model: model)

        let response = try await session.respond(
            to: "Reply with the single word: hello",
            options: GenerationOptions(maximumResponseTokens: 16)
        )

        Testing.Attachment.record(response.content, named: "response.txt")
        #expect(!response.content.isEmpty)
        #expect(response.usage.input.totalTokenCount > 0)
    }
}
