public import LanguageModels

/// How an OpenRouter model's requests are sent: how long they wait, how they retry, how their images are encoded,
/// and how long model info stays fresh.
///
/// Options, such as ``OpenRouterOptions``, are what a request asks OpenRouter for. The configuration is how the
/// package sends the request, so OpenRouter never sees it. Set it when creating the model, or change it later:
///
/// ```swift
/// // Fail fast on an interactive screen.
/// let model = OpenRouterLanguageModel(
///     .anthropicClaudeHaiku5_5,
///     configuration: OpenRouterConfiguration(idleTimeout: .seconds(60), retries: RequestRetries(limit: 1)),
///     auth: .apiKey { try await keyStore.openRouterKey() }
/// )
///
/// // Prices that are never more than 10 seconds old.
/// var pricing = model
/// pricing.configuration.infoCacheLifetime = .seconds(10)
/// ```
public struct OpenRouterConfiguration: Sendable, Hashable, RetryingConfiguration, ImageEncodingConfiguration {
    /// The longest time to wait for the next data, from sending the request to the end of the answer, or `nil` for
    /// the URL session's own timeout. OpenRouter sends keep-alive comments while a model thinks, so this doesn't limit
    /// a long answer.
    public var idleTimeout: Duration?

    /// How a request that fails before any data arrives is sent again: after a failed connection or any status from
    /// 500 up, or whatever status when `x-should-retry` is `true`, but never when it's `false`. Model info calls retry
    /// the same way.
    public var retries: RequestRetries

    /// How image attachments are encoded before they're sent.
    public var images: ImageEncoding

    /// How long an answer of a model info call, such as ``OpenRouterLanguageModel/endpoints()``, is reused before it's
    /// fetched again. Answers are shared by every model that calls with the same authentication. Zero or less fetches
    /// every time.
    public var infoCacheLifetime: Duration

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - idleTimeout: The longest time to wait for the next data, or `nil` for the URL session's own timeout.
    ///   - retries: How a failed request is sent again. The default retries up to twice.
    ///   - images: How image attachments are encoded.
    ///   - infoCacheLifetime: How long an answer of a model info call is reused. The default is a minute.
    public init(
        idleTimeout: Duration? = nil,
        retries: RequestRetries = .standard,
        images: ImageEncoding = .standard,
        infoCacheLifetime: Duration = .seconds(60)
    ) {
        self.idleTimeout = idleTimeout
        self.retries = retries
        self.images = images
        self.infoCacheLifetime = infoCacheLifetime
    }
}
