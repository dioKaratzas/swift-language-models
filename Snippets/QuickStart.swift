// snippet.hide
import Foundation
// snippet.show
// snippet.session
import FoundationModels
import OpenRouterLanguageModels

func planMonday() async throws -> String {
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, auth: .apiKey { try await keyStore.openRouterKey() })
    let session = LanguageModelSession(model: model, instructions: "Plan the week's meals.")
    let plan = try await session.respond(to: "Something light for Monday.")
    return plan.content
}
// snippet.end

// snippet.hide
func apiKey() {
    // snippet.show
    // snippet.apiKey
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, auth: .apiKey { "..." })
    // snippet.end
    // snippet.hide
    _ = model
}

func proxy() {
    // swift-format-ignore: NeverForceUnwrap
    // snippet.show
    // snippet.proxy
    let model = OpenRouterLanguageModel(
        .anthropicClaudeHaiku5_5,
        auth: .proxied(
            baseURL: URL(string: "https://api.yourapp.com/openrouter/")!,
            headers: { ["X-App-Token": "..."] }
        )
    )
    // snippet.end
    // snippet.hide
    _ = model
}

func attribution() {
    // snippet.show
    // snippet.attribution
    let model = OpenRouterLanguageModel(
        .anthropicClaudeHaiku5_5,
        app: OpenRouterApp(name: "Meal Planner", url: URL(string: "https://example.com"), categories: [.personalAgent]),
        auth: .apiKey { try await keyStore.openRouterKey() }
    )
    // snippet.end
    // snippet.hide
    _ = model
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openRouterKey() async throws -> String { "" }
}

let keyStore = KeyStore()
