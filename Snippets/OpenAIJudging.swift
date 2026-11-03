// snippet.hide
import FoundationModels
import OpenAILanguageModels

func models() {
    // snippet.show
    // snippet.models
    let evaluationAuth = OpenAIAuthentication.apiKey(project: "proj_evaluations") {
        try await keyStore.openAIKey()
    }
    let judge = OpenAILanguageModel(.gpt5_5_2026_04_23, auth: evaluationAuth)
    let generator = OpenAILanguageModel(.gpt5_4Mini2026_03_17, auth: evaluationAuth)
    // snippet.end
    // snippet.hide
    _ = generator
    // snippet.show
    // snippet.capabilities
    print(judge.capabilities.contains(.guidedGeneration))  // true: it lists `structured_outputs`
    // snippet.end
    // snippet.hide
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openAIKey() async throws -> String { "" }
}

let keyStore = KeyStore()
