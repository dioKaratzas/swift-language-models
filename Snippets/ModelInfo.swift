// snippet.hide
import Foundation
import FoundationModels
import OpenRouterLanguageModels

func endpoints() async throws {
    // snippet.show
    // snippet.providers
    let endpoints = try await OpenRouterModel.anthropicClaudeHaiku5_5.endpoints()
    for endpoint in endpoints {
        let price = endpoint.pricing.map { "\($0.prompt * 1_000_000) USD per million prompt tokens" } ?? "price depends on the request"
        print("\(endpoint.tag): \(price), up \(endpoint.uptimeLastDay ?? 0)% of the last day")
    }
    // snippet.end
    // snippet.hide
}

func routeToEurope() async throws -> OpenRouterLanguageModel<Efforts.Of<OpenRouterCatalog.AnthropicClaudeHaiku5_5>> {
    // snippet.show
    // snippet.route
    let europe = try await OpenRouterModel.anthropicClaudeHaiku5_5.endpoints()
        .filter { $0.tag.rawValue.hasSuffix("/europe") || $0.tag.rawValue.hasSuffix("/eu-west-1") }
        .map(\.tag)
    let model = OpenRouterLanguageModel(
        .anthropicClaudeHaiku5_5,
        routing: OpenRouterRouting(order: europe, allowsFallbackProviders: false),
        auth: .apiKey { try await keyStore.openRouterKey() }
    )
    // snippet.end
    // snippet.hide
    return model
}

func pricing() async throws {
    // snippet.show
    // snippet.pricing
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, auth: .apiKey { try await keyStore.openRouterKey() })
    if let pricing = try await model.currentPricing() {
        let prices = pricing.prices(forPromptTokens: 3_000)
        let estimate = prices.prompt * 3_000 + prices.completion * 500
        print("About \(estimate) USD for 3,000 tokens in and 500 out")
    }
    let details = try await model.currentDetails()
    print(details.maximumOutputTokens ?? 0, details.supportedParameters.contains(.tools))
    // snippet.end
    // snippet.hide
}

/// Stands in for the app's own Keychain wrapper.
struct KeyStore {
    func openRouterKey() async throws -> String { "" }
}

let keyStore = KeyStore()
