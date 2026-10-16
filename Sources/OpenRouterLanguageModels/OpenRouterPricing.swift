public import Foundation

/// What OpenRouter charges for a model, in US dollars per token.
public struct OpenRouterPricing: Sendable, Hashable {
    /// The price of one prompt token.
    public let prompt: Decimal

    /// The price of one generated token.
    public let completion: Decimal
}
