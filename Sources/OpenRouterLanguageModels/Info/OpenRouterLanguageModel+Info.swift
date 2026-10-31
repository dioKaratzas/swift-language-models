extension OpenRouterLanguageModel {
    /// The endpoints of the model's ``details``, as ``OpenRouterModel/providers(auth:session:)`` lists them, with the
    /// model's authentication and session.
    ///
    /// With an API key, OpenRouter reports each endpoint's latency and throughput too.
    ///
    /// - Returns: The endpoints, in OpenRouter's order.
    /// - Throws: What ``OpenRouterModel/providers(auth:session:)`` throws, and any error the model's authentication
    ///   throws.
    public func providers() async throws -> [OpenRouterProvider] {
        try await transport.providers(of: details.id, headers: auth.requestHeaders())
    }

    /// What OpenRouter lists for the model's ``details`` now, as ``OpenRouterModel/currentDetails(auth:session:)``
    /// reads it, with the model's authentication and session.
    ///
    /// - Returns: The model's current details.
    /// - Throws: What ``OpenRouterModel/currentDetails(auth:session:)`` throws, and any error the model's
    ///   authentication throws.
    public func currentDetails() async throws -> OpenRouterCurrentDetails {
        try await transport.currentDetails(of: details.id, headers: auth.requestHeaders())
    }

    /// What OpenRouter charges for the model's ``details`` now, with the model's authentication and session.
    ///
    /// - Returns: The prices, or `nil` when the price depends on the request, as for a router.
    /// - Throws: What ``currentDetails()`` throws.
    public func currentPricing() async throws -> OpenRouterPricing? {
        try await currentDetails().pricing
    }

    /// The transport of the model's calls besides chat completions, with its session and its authentication's base
    /// URL.
    var transport: APITransport {
        APITransport(session: session, baseURL: auth.baseURL, retryDelay: executorConfiguration.retryDelay)
    }
}
