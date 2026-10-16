public import Foundation

/// What OpenRouter charges for a model, in US dollars per token.
///
/// These are base prices, for estimates before a request. A response reports what the request actually cost.
public struct OpenRouterPricing: Sendable, Hashable {
    /// The price of one prompt token.
    public let prompt: Decimal

    /// The price of one generated token.
    public let completion: Decimal

    /// The price of one prompt token read from the prompt cache, when the model caches prompts.
    public let cacheRead: Decimal?

    /// The price of one prompt token written to the prompt cache, when writing costs extra.
    public let cacheWrite: Decimal?
}
