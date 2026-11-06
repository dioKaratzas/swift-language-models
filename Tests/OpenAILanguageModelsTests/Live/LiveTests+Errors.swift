import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import OpenAILanguageModels
import Testing

@diagnose(DeprecatedDeclaration, as: warning)
extension LiveTests {
    @Suite("Errors")
    struct Errors {
        @Test func `a rejected key throws OpenAI's error with its status and code`() async throws {
            let session = LanguageModelSession(model: try LiveModel.nano.languageModel(auth: .apiKey { "sk-not-a-key" }))

            let error = try await #require(throws: OpenAIError.self) {
                _ = try await session.respond(to: "Say hello.", options: LiveTests.short)
            }

            record(error, named: "error.txt")
            #expect(error.status == 401)
            #expect(error.code == .invalidAPIKey)
            #expect(error.errorType == .invalidRequest)
            #expect(!error.message.isEmpty)
        }

        @Test func `an unknown model throws OpenAI's error`() async throws {
            let key = APIKeyTrait.current ?? ""
            let details = OpenAIModel<ContextOptions.ReasoningLevel>(
                id: "swift-language-models-no-such-model", displayName: "None", supportedParameters: [.maxOutputTokens])
            let session = LanguageModelSession(model: OpenAILanguageModel(details, auth: .apiKey { key }))

            let error = try await #require(throws: OpenAIError.self) {
                _ = try await session.respond(to: "Say hello.", options: LiveTests.short)
            }

            record(error, named: "error.txt")
            #expect([400, 404].contains(error.status))
        }

        @Test func `a prompt longer than the context throws an oversized context`() async throws {
            let session = LanguageModelSession(model: try LiveModel.mini.languageModel())
            let prompt = String(repeating: "word ", count: 140_000)

            let error = try await #require(throws: LanguageModelError.self) {
                _ = try await session.respond(to: prompt, options: GenerationOptions(maximumResponseTokens: 16))
            }

            record(error, named: "error.txt")
            guard case .contextSizeExceeded(let context) = error else {
                Issue.record("The answer ended with \(error)")
                return
            }
            #expect(context.contextSize > 0)
        }

        @Test func `an idle timeout too short for any answer throws a timeout`() async throws {
            let key = APIKeyTrait.current ?? ""
            let details = try #require(OpenAIModel(catalogID: LiveModel.nano.id))
            let configuration = OpenAIConfiguration(idleTimeout: .milliseconds(1), retries: .disabled)
            let session = LanguageModelSession(model: OpenAILanguageModel(details, configuration: configuration, auth: .apiKey { key }))

            await #expect(throws: LanguageModelError.self) {
                _ = try await session.respond(to: "Say hello.", options: LiveTests.short)
            }
        }
    }
}
