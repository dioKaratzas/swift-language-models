// snippet.hide
import Foundation
// snippet.show
// snippet.session
import FoundationModels
import OpenRouterLanguageModels

func planMonday() async throws -> String {
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, apiKey: { try await keyStore.openRouterKey() })
    let session = LanguageModelSession(model: model, instructions: "Plan the week's meals.")
    let plan = try await session.respond(to: "Something light for Monday.")
    return plan.content
}
// snippet.end

// snippet.hide
func developmentKey() {
    // snippet.show
    // snippet.environment
    let model = OpenRouterLanguageModel(
        .anthropicClaudeHaiku5_5,
        apiKey: { ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? "" }
    )
    // snippet.end
    // snippet.hide
    _ = model
}

func proxy() {
    // snippet.show
    // snippet.proxy
    let model = OpenRouterLanguageModel(
        .anthropicClaudeHaiku5_5,
        baseURL: URL(string: "https://api.example.com/openrouter/"),
        apiKey: { try await account.shortLivedToken() }
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
        apiKey: { try await keyStore.openRouterKey() }
    )
    // snippet.end
    // snippet.hide
    _ = model
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openRouterKey() async throws -> String { "" }
}

/// Stands in for the app's own account, which gets tokens from the app's server.
struct Account {
    func shortLivedToken() async throws -> String { "" }
}

let keyStore = KeyStore()
let account = Account()
