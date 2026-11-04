public import LanguageModels

/// How an OpenAI model's requests are sent: how long they wait, how they retry, and how their images are encoded.
///
/// Options, such as ``OpenAIOptions``, are what a request asks OpenAI for. The configuration is how the package sends
/// the request, so OpenAI never sees it. Set it when creating the model, or change it later:
///
/// ```swift
/// // Fail fast on an interactive screen.
/// let model = OpenAILanguageModel(
///     .gpt6Luna,
///     configuration: OpenAIConfiguration(idleTimeout: .seconds(60), retries: RequestRetries(limit: 1)),
///     auth: .apiKey { try await keyStore.openAIKey() }
/// )
///
/// // Smaller images, for fewer input tokens.
/// var batch = model
/// batch.configuration.images.maximumSide = 1_024
/// ```
public struct OpenAIConfiguration: Sendable, Hashable, RetryingConfiguration, ImageEncodingConfiguration {
    /// The longest time to wait for the next data, from sending the request to the end of the answer, or `nil` for
    /// the URL session's own timeout.
    public var idleTimeout: Duration?

    /// How a request that fails before any data arrives is sent again: after a failed connection, a 408, 409 or 429,
    /// or any status from 500 up, as OpenAI's own SDKs retry it, or whatever status when `x-should-retry` is `true`,
    /// but never when it's `false`.
    public var retries: RequestRetries

    /// How image attachments are encoded before they're sent.
    public var images: ImageEncoding

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - idleTimeout: The longest time to wait for the next data, or `nil` for the URL session's own timeout. The
    ///     default is 10 minutes, as in OpenAI's own SDKs, since a model that reasons hard may send nothing for a
    ///     while.
    ///   - retries: How a failed request is sent again. The default retries up to twice, as OpenAI's own SDKs do.
    ///   - images: How image attachments are encoded.
    public init(idleTimeout: Duration? = .seconds(600), retries: RequestRetries = .standard, images: ImageEncoding = .standard) {
        self.idleTimeout = idleTimeout
        self.retries = retries
        self.images = images
    }
}
