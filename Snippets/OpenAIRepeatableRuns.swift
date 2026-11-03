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

func pinned() {
    // snippet.show
    // snippet.pinned
    let model = OpenAILanguageModel(
        .gpt5_4Mini2026_03_17,
        options: OpenAIOptions(serviceTier: .default),
        auth: .apiKey { try await keyStore.openAIKey() }
    )
    // snippet.end
    // snippet.hide
    _ = model
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openAIKey() async throws -> String { "" }
}

let keyStore = KeyStore()
