import LanguageModels

extension OpenAILanguageModel {
    /// How the model's requests reach OpenAI: its session and authentication, with the timeouts of a request
    /// executor's configuration, retrying as the official SDKs do.
    func connection(_ configuration: RequestExecutor.Configuration) -> ProviderConnection {
        ProviderConnection(
            session: session, authentication: auth.requestAuthentication, idleTimeout: configuration.idleTimeout,
            retryPolicy: API.retryPolicy(delay: configuration.retryDelay))
    }
}
