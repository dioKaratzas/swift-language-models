import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenRouterLanguageModels
import Testing

extension LiveTests {
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

    /// Probes of the ways the executor may break on some models, each named after its risk. A probe that fails today
    /// runs in a known issue, so it reports once the risk is fixed. A probe of a risk that OpenRouter turned out to
    /// handle stays as a regression test. Risk 4 is probed by the parallel calls in Tools.
}
