// snippet.hide
import Foundation
import FoundationModels
import OpenAILanguageModels

func cacheKey() {
    // snippet.show
    // snippet.cacheKey
    let model = OpenAILanguageModel(
        .gpt6Luna,
        options: OpenAIOptions(cacheKey: .named("meal-planner-handbook")),
        auth: .apiKey { try await keyStore.openAIKey() }
    )
    // snippet.end
    // snippet.hide
    _ = model
}

func usage(model: OpenAILanguageModel<some ModelEffort>, handbook: String) async throws {
    // snippet.show
    // snippet.usage
    let session = LanguageModelSession(model: model, instructions: handbook)
    let response = try await session.respond(to: "What's the refund policy?")

    print("Input tokens:", response.usage.input.totalTokenCount)
    print("Read from the cache:", response.usage.input.cachedTokenCount)
    if let written = response.usage.openAI.cacheWriteTokenCount {
        print("Written to the cache:", written)
    }
    // snippet.end
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openAIKey() async throws -> String { "" }
}

let keyStore = KeyStore()
