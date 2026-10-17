public import Foundation

/// What OpenRouter charges for a model, in US dollars per token.
///
/// The base prices apply by default. Overrides replace some of them for some requests, such as those with a long
/// prompt or those sent at an off-peak hour, and ``prices(forPromptTokens:at:)`` applies the ones that match a
/// request. These prices are for estimates before a request; a response reports what the request actually cost.
public struct OpenRouterPricing: Sendable, Hashable {
    /// The price of one prompt token.
    public let prompt: Decimal

    /// The price of one generated token.
    public let completion: Decimal

    /// The price of one prompt token read from the prompt cache, when the model caches prompts.
    public let cacheRead: Decimal?

    /// The price of one prompt token written to the prompt cache, when writing costs extra.
    public let cacheWrite: Decimal?

    /// Prices that replace the base prices while their conditions hold. Where several apply, a later one wins for
    /// each price it sets.
    public let overrides: [Override]

    /// Creates a model's pricing.
    ///
    /// - Parameters:
    ///   - prompt: The price of one prompt token.
    ///   - completion: The price of one generated token.
    ///   - cacheRead: The price of one prompt token read from the prompt cache.
    ///   - cacheWrite: The price of one prompt token written to the prompt cache.
    ///   - overrides: Prices that replace these while their conditions hold, a later one winning.
    public init(
        prompt: Decimal,
        completion: Decimal,
        cacheRead: Decimal? = nil,
        cacheWrite: Decimal? = nil,
        overrides: [Override] = []
    ) {
        self.prompt = prompt
        self.completion = completion
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.overrides = overrides
    }

    /// The prices for one request, with the overrides that apply to it.
    ///
    /// - Parameters:
    ///   - promptTokens: The request's prompt length, in tokens.
    ///   - date: When the request is sent.
    /// - Returns: The prices, with no overrides left.
    public func prices(forPromptTokens promptTokens: Int, at date: Date = .now) -> OpenRouterPricing {
        let moment = Moment(date)
        let base = OpenRouterPricing(prompt: prompt, completion: completion, cacheRead: cacheRead, cacheWrite: cacheWrite)
        return overrides.filter { $0.condition.holds(promptTokens: promptTokens, at: moment) }.reduce(base) { prices, override in
            OpenRouterPricing(
                prompt: override.prompt ?? prices.prompt,
                completion: override.completion ?? prices.completion,
                cacheRead: override.cacheRead ?? prices.cacheRead,
                cacheWrite: override.cacheWrite ?? prices.cacheWrite
            )
        }
    }
}
