import LanguageModels

extension OpenRouterLanguageModel {
    /// How the model's requests reach OpenRouter: its session and authentication, with the timeouts of a request
    /// executor's configuration. Chat requests and info calls both go through it.
    func connection(_ configuration: RequestExecutor.Configuration) -> ProviderConnection {
        ProviderConnection(
            session: session, authentication: auth.requestAuthentication, idleTimeout: configuration.idleTimeout,
            retryDelay: configuration.retryDelay)
    }
}
