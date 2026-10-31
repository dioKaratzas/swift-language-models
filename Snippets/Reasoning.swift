// snippet.hide
import FoundationModels
import OpenRouterLanguageModels

func reasoning() async throws {
    // snippet.show
    // snippet.reasoning
    let model = OpenRouterLanguageModel(.deepseekDeepseekV4Flash, apiKey: { try await keyStore.openRouterKey() })
    print(model.details.reasoning)  // optional(enabledByDefault: false)
    print(model.details.reasoningEfforts.map { "\($0)" })  // ["xhigh", "high", "none"]

    let session = LanguageModelSession(model: model)
    let response = try await session.respond(
        to: "Is 1,001 prime?",
        contextOptions: ContextOptions(reasoningLevel: model.reasoningLevel(.high))
    )

    for case .reasoning(let reasoning) in response.transcriptEntries {
        for case .text(let text) in reasoning.segments {
            print(text.content)
        }
    }
    print("Reasoning tokens:", response.usage.output.reasoningTokenCount)
    // snippet.end
    // snippet.hide
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openRouterKey() async throws -> String { "" }
}

let keyStore = KeyStore()
