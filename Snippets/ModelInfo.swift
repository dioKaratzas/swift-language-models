// snippet.hide
import Foundation
import FoundationModels
import OpenRouterLanguageModels

func providers() async throws {
    // snippet.show
    // snippet.providers
    let providers = try await OpenRouterModel.anthropicClaudeHaiku5_5.providers()
    for provider in providers {
        let price = provider.pricing.map { "\($0.prompt * 1_000_000) USD per million prompt tokens" } ?? "price depends on the request"
        print("\(provider.tag): \(price), up \(provider.uptimeLastDay ?? 0)% of the last day")
    }
    // snippet.end
    // snippet.hide
}

func routeToEurope() async throws -> OpenRouterLanguageModel<Efforts.Of<OpenRouterModels.AnthropicClaudeHaiku5_5>> {
    // snippet.show
    // snippet.route
    let europe = try await OpenRouterModel.anthropicClaudeHaiku5_5.providers()
        .filter { $0.tag.rawValue.hasSuffix("/europe") || $0.tag.rawValue.hasSuffix("/eu-west-1") }
        .map(\.tag)
    let model = OpenRouterLanguageModel(
        .anthropicClaudeHaiku5_5,
        routing: OpenRouterRouting(order: europe, allowsFallbacks: false),
        apiKey: { try await keyStore.openRouterKey() }
    )
    // snippet.end
    // snippet.hide
    return model
}

func pricing() async throws {
    // snippet.show
    // snippet.pricing
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, apiKey: { try await keyStore.openRouterKey() })
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
