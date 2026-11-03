// snippet.hide
import Foundation
// snippet.show
// snippet.session
import FoundationModels
import OpenAILanguageModels

func planMonday() async throws -> String {
    let model = OpenAILanguageModel(.gpt6Luna, auth: .apiKey { try await keyStore.openAIKey() })
    let session = LanguageModelSession(model: model, instructions: "Plan the week's meals.")
    let plan = try await session.respond(to: "Something light for Monday.")
    return plan.content
}
// snippet.end

// snippet.hide
func apiKey() {
    // snippet.show
    // snippet.apiKey
    // During development, from the scheme's environment, which stays out of git when the scheme isn't shared.
    let model = OpenAILanguageModel(
        .gpt6Luna,
        auth: .apiKey {
            ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        })
    // snippet.end
    // snippet.hide
    _ = model
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openAIKey() async throws -> String { "" }
}

let keyStore = KeyStore()
