// snippet.hide
import FoundationModels
import OpenAILanguageModels

func parameters() {
    // snippet.show
    // snippet.parameters
    let model = OpenAIModel.gpt5_4Mini2026_03_17
    print(model.supportedParameters.contains(.temperature))
    print(model.reasoningEfforts.map(\.rawValue))
    // snippet.end
}

func pinned() async throws {
    // snippet.show
    // snippet.pinned
    let model = OpenAILanguageModel(
        .gpt5_4Mini2026_03_17,
        options: OpenAIOptions(serviceTier: .default),
        auth: .apiKey { try await keyStore.openAIKey() }
    )
    // The same level on every run. `.off` also lets the sampling settings reach the model.
    let contextOptions = ContextOptions(reasoningLevel: model.reasoningLevel(.off))
    let response = try await LanguageModelSession(model: model).respond(
        to: "Suggest one recipe in under 150 words.",
        contextOptions: contextOptions
    )
    // snippet.end
    // snippet.hide
    _ = response
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openAIKey() async throws -> String { "" }
}

let keyStore = KeyStore()
