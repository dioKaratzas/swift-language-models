// snippet.hide
import FoundationModels
import OpenAILanguageModels

func level() async throws {
    // snippet.show
    // snippet.level
    let model = OpenAILanguageModel(.gpt6Luna, auth: .apiKey { try await keyStore.openAIKey() })
    print(model.details.reasoning == .onByDefault)  // true
    print(model.details.reasoningEfforts.map(\.rawValue))  // ["max", "xhigh", "high", "medium", "low", "none"]

    let session = LanguageModelSession(model: model)
    let response = try await session.respond(
        to: "Is 1,001 prime?",
        contextOptions: ContextOptions(reasoningLevel: model.reasoningLevel(.high))
    )
    print("Reasoning tokens:", response.usage.output.reasoningTokenCount)
    // snippet.end
    // snippet.hide
}

func summary() async throws {
    // snippet.show
    // snippet.summary
    let model = OpenAILanguageModel(
        .gpt6Luna,
        options: OpenAIOptions(reasoningSummary: .auto),
        auth: .apiKey { try await keyStore.openAIKey() }
    )
    let response = try await LanguageModelSession(model: model).respond(to: "Is 1,001 prime?")

    for case .reasoning(let reasoning) in response.transcriptEntries {
        for case .text(let text) in reasoning.segments {
            print(text.content)
        }
    }
    // snippet.end
    // snippet.hide
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openAIKey() async throws -> String { "" }
}

let keyStore = KeyStore()
