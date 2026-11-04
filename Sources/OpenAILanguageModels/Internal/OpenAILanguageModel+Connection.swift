import LanguageModels

extension OpenAILanguageModel {
    /// How the model's requests reach OpenAI: its session and authentication, with the timeout and retries of its
    /// configuration, retrying the statuses the official SDKs retry.
    func connection(_ configuration: OpenAIConfiguration) -> ProviderConnection {
        ProviderConnection(
            session: session, authentication: auth.requestAuthentication, idleTimeout: configuration.idleTimeout,
            retryPolicy: configuration.retries.policy(statuses: API.retriesStatus))
    }
}
