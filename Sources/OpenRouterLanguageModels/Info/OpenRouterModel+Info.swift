public import Foundation

extension OpenRouterModel {
    /// The model's endpoints: each provider that serves it, once for each region, tier or precision it serves the model at,
    /// with its limits, prices and recent health.
    ///
    /// ```swift
    /// let providers = try await OpenRouterModel.anthropicClaudeHaiku5_5.providers()
    /// let healthy = providers.filter { ($0.uptimeLast30Minutes ?? 0) > 99 }.map(\.tag)
    /// ```
    ///
    /// The call needs no key, but OpenRouter reports each endpoint's latency and throughput only to a call with one.
    /// Answers from the last minute are reused, so calling this often, such as from a list, doesn't fetch them again.
    ///
    /// - Parameters:
    ///   - apiKey: The OpenRouter API key, or `nil` to call without one.
    ///   - session: The URL session that sends the request.
    ///   - baseURL: Where OpenRouter's API lives, for a proxy; `nil` for OpenRouter itself.
    /// - Returns: The endpoints, in OpenRouter's order; none for an alias, such as `~anthropic/claude-haiku-latest`,
    ///   whose endpoints are those of the model it points to.
    /// - Throws: `OpenRouterError` with `notFound` for a model OpenRouter doesn't list, and otherwise what a session's
    ///   request throws when OpenRouter can't be reached or fails.
    public func providers(apiKey: String? = nil, session: URLSession = .shared, baseURL: URL? = nil) async throws -> [OpenRouterProvider] {
        try await APITransport(session: session, baseURL: baseURL).providers(of: id, apiKey: apiKey)
    }

    /// What OpenRouter lists for the model now: its prices, limits and parameters.
    ///
    /// The catalog keeps no prices, since OpenRouter changes them often, so this is where they come from. Answers from
    /// the last minute are reused.
    ///
    /// - Parameters:
    ///   - apiKey: The OpenRouter API key, or `nil` to call without one.
    ///   - session: The URL session that sends the request.
    ///   - baseURL: Where OpenRouter's API lives, for a proxy; `nil` for OpenRouter itself.
    /// - Returns: The model's current details.
    /// - Throws: `OpenRouterError` with `notFound` for a model OpenRouter doesn't list, and otherwise what a session's
    ///   request throws when OpenRouter can't be reached or fails.
    public func currentDetails(apiKey: String? = nil, session: URLSession = .shared, baseURL: URL? = nil) async throws
        -> OpenRouterCurrentDetails
    {
        try await APITransport(session: session, baseURL: baseURL).currentDetails(of: id, apiKey: apiKey)
    }

    /// What OpenRouter charges for the model now, from ``currentDetails(apiKey:session:baseURL:)``.
    ///
    /// ```swift
    /// if let pricing = try await OpenRouterModel.anthropicClaudeHaiku5_5.currentPricing() {
    ///     let estimate = pricing.prices(forPromptTokens: 2_000).prompt * 2_000
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - apiKey: The OpenRouter API key, or `nil` to call without one.
    ///   - session: The URL session that sends the request.
    ///   - baseURL: Where OpenRouter's API lives, for a proxy; `nil` for OpenRouter itself.
    /// - Returns: The prices, or `nil` when the price depends on the request, as for a router.
    /// - Throws: What ``currentDetails(apiKey:session:baseURL:)`` throws.
    public func currentPricing(apiKey: String? = nil, session: URLSession = .shared, baseURL: URL? = nil) async throws
        -> OpenRouterPricing?
    {
        try await currentDetails(apiKey: apiKey, session: session, baseURL: baseURL).pricing
    }
}
