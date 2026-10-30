extension OpenRouterLanguageModel {
    /// The endpoints of the model's ``details``, as ``OpenRouterModel/providers(apiKey:session:baseURL:)`` lists them,
    /// with the model's key, session and base URL.
    ///
    /// With the key, OpenRouter reports each endpoint's latency and throughput too.
    ///
    /// - Returns: The endpoints, in OpenRouter's order.
    /// - Throws: What ``OpenRouterModel/providers(apiKey:session:baseURL:)`` throws, and any error the model's
    ///   `apiKey` closure throws.
    public func providers() async throws -> [OpenRouterProvider] {
        try await transport.providers(of: details.id, apiKey: apiKey())
    }

    /// What OpenRouter lists for the model's ``details`` now, as ``OpenRouterModel/currentDetails(apiKey:session:baseURL:)``
    /// reads it, with the model's key, session and base URL.
    ///
    /// - Returns: The model's current details.
    /// - Throws: What ``OpenRouterModel/currentDetails(apiKey:session:baseURL:)`` throws, and any error the model's
    ///   `apiKey` closure throws.
    public func currentDetails() async throws -> OpenRouterCurrentDetails {
        try await transport.currentDetails(of: details.id, apiKey: apiKey())
    }

    /// What OpenRouter charges for the model's ``details`` now, with the model's key, session and base URL.
    ///
    /// - Returns: The prices, or `nil` when the price depends on the request, as for a router.
    /// - Throws: What ``currentDetails()`` throws.
    public func currentPricing() async throws -> OpenRouterPricing? {
        try await currentDetails().pricing
    }

    /// The transport of the model's calls besides chat completions, with its session and base URL.
    var transport: APITransport {
        APITransport(session: session, baseURL: baseURL, retryDelay: executorConfiguration.retryDelay)
    }
}
