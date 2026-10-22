public import Foundation

/// What OpenRouter charges for a model, in US dollars: per token, and per request, image or search for the fees that
/// some models charge on top.
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

    /// The price of one prompt token written to the prompt cache for an hour, when the model can cache that long.
    public let cacheWriteOneHour: Decimal?

    /// The price of one reasoning token, when the model prices reasoning apart from ``completion``.
    public let reasoning: Decimal?

    /// The price of one audio token in the prompt, when audio costs other than text.
    public let audio: Decimal?

    /// The price of one image in the prompt, when images cost other than text.
    public let image: Decimal?

    /// The fee for each request, on top of its tokens, when the model charges one.
    public let request: Decimal?

    /// The price of one web search that the model or its host runs, such as the search that Perplexity's Sonar models
    /// run for every request, or a host's own search for an ``OpenRouterServerTool`` web search.
    public let webSearch: Decimal?

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
    ///   - cacheWriteOneHour: The price of one prompt token written to the prompt cache for an hour.
    ///   - reasoning: The price of one reasoning token, when it isn't the price of a generated token.
    ///   - audio: The price of one audio token in the prompt.
    ///   - image: The price of one image in the prompt.
    ///   - request: The fee for each request, on top of its tokens.
    ///   - webSearch: The price of one web search.
    ///   - overrides: Prices that replace these while their conditions hold, a later one winning.
    public init(
        prompt: Decimal,
        completion: Decimal,
        cacheRead: Decimal? = nil,
        cacheWrite: Decimal? = nil,
        cacheWriteOneHour: Decimal? = nil,
        reasoning: Decimal? = nil,
        audio: Decimal? = nil,
        image: Decimal? = nil,
        request: Decimal? = nil,
        webSearch: Decimal? = nil,
        overrides: [Override] = []
    ) {
        self.prompt = prompt
        self.completion = completion
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.cacheWriteOneHour = cacheWriteOneHour
        self.reasoning = reasoning
        self.audio = audio
        self.image = image
        self.request = request
        self.webSearch = webSearch
        self.overrides = overrides
    }

    /// The prices for one request, with the overrides that apply to it.
    ///
    /// - Parameters:
    ///   - promptTokens: The request's prompt length, in tokens.
    ///   - date: When the request is sent.
    /// - Returns: The prices, with no overrides left. The fees that no override changes, such as ``request`` and
    ///   ``webSearch``, carry over.
    public func prices(forPromptTokens promptTokens: Int, at date: Date = .now) -> OpenRouterPricing {
        let moment = Moment(date)
        let applying = overrides.filter { $0.condition.holds(promptTokens: promptTokens, at: moment) }
        return applying.reduce(withoutOverrides) { prices, override in
            OpenRouterPricing(
                prompt: override.prompt ?? prices.prompt,
                completion: override.completion ?? prices.completion,
                cacheRead: override.cacheRead ?? prices.cacheRead,
                cacheWrite: override.cacheWrite ?? prices.cacheWrite,
                cacheWriteOneHour: override.cacheWriteOneHour ?? prices.cacheWriteOneHour,
                reasoning: prices.reasoning,
                audio: override.audio ?? prices.audio,
                image: prices.image,
                request: prices.request,
                webSearch: prices.webSearch
            )
        }
    }

    /// The base prices, with no overrides.
    private var withoutOverrides: OpenRouterPricing {
        OpenRouterPricing(
            prompt: prompt,
            completion: completion,
            cacheRead: cacheRead,
            cacheWrite: cacheWrite,
            cacheWriteOneHour: cacheWriteOneHour,
            reasoning: reasoning,
            audio: audio,
            image: image,
            request: request,
            webSearch: webSearch
        )
    }
}
