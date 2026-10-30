// snippet.hide
import Foundation
import FoundationModels
import OpenRouterLanguageModels

func providers() async throws {
    // snippet.show
    // snippet.providers
    let providers = try await OpenRouterModel.anthropicClaudeHaiku5_5.providers()
    for provider in providers {
        let price = provider.pricing.map { "\($0.prompt * 1_000_000) USD per million prompt tokens" } ?? "priced per request"
        print("\(provider.tag): \(price), up \(provider.uptimeLastDay ?? 0)% of the last day")
    }
    // snippet.end
    // snippet.hide
}

func routeToEurope(key: String) async throws -> OpenRouterLanguageModel<Efforts.MaxXhighHighMediumLowOff> {
    // snippet.show
    // snippet.route
    let europe = try await OpenRouterModel.anthropicClaudeHaiku5_5.providers()
        .filter { $0.tag.rawValue.hasSuffix("/europe") || $0.tag.rawValue.hasSuffix("/eu-west-1") }
        .map(\.tag)
    let model = OpenRouterLanguageModel(
        .anthropicClaudeHaiku5_5,
        routing: OpenRouterRouting(order: europe, allowsFallbacks: false),
        apiKey: { key }
    )
    // snippet.end
    // snippet.hide
    return model
}

func pricing(key: String) async throws {
    // snippet.show
    // snippet.pricing
    let model = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, apiKey: { key })
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
