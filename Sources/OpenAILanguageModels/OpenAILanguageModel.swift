public import Foundation
public import FoundationModels
public import LanguageModels

/// One of OpenAI's models, for Foundation Models sessions, through OpenAI's Responses API.
///
/// Pass a model from the catalog, and how its requests authenticate, such as with an API key read on every request:
///
/// ```swift
/// let model = OpenAILanguageModel(.gpt6Luna, auth: .apiKey { try await keyStore.openAIKey() })
/// let session = LanguageModelSession(model: model, instructions: "Plan the week's meals.")
/// ```
///
/// Everything else is Foundation Models: prompts, tools, guided generation, profiles, reasoning levels, attachments and
/// generation options. A request sends a per-model setting, such as `temperature` or `tools`, only to a model that
/// takes it, and a debug build shows a runtime warning in Xcode for each setting left out.
///
/// What only OpenAI has is in the articles: authentication in <doc:GettingStarted> and <doc:Authentication>, then
/// <doc:Reasoning>, <doc:Caching>, <doc:Attachments> and <doc:ErrorsAndMetadata>.
public struct OpenAILanguageModel<Effort: ModelEffort>: DetailedLanguageModel {
    /// What the catalog records about the model.
    public let details: OpenAIModel<Effort>

    /// The models OpenAI tries when this one fails: none, since OpenAI has no fallbacks.
    public var fallbacks: [OpenAIModel<ContextOptions.ReasoningLevel>] { [] }

    /// Request settings that only OpenAI has.
    public var options: OpenAIOptions

    /// The URL session that sends requests: `.shared` unless the model was created with another.
    let session: URLSession

    /// How requests authenticate, and where they go.
    let auth: OpenAIAuthentication

    /// How requests are sent: how long they wait, how they retry, and how their images are encoded. A change applies
    /// to the next request.
    public var configuration: OpenAIConfiguration

    /// Where requests go, with the model's ``configuration``, as Foundation Models hands them to the request executor.
    public var executorConfiguration: RequestExecutor.Configuration {
        RequestExecutor.Configuration(baseURL: auth.baseURL, settings: configuration)
    }

    /// The longest time to wait for the next data, from sending the request to the end of the answer, or `nil` for
    /// the session's own timeout, as the ``configuration`` sets it.
    public var idleTimeout: Duration? { configuration.idleTimeout }

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - details: The model, usually from the catalog, such as `.gpt6Luna`.
    ///   - options: Request settings that only OpenAI has.
    ///   - session: The URL session that sends requests. Its configuration applies, but the package still sets each
    ///     request's headers, its timeout when the configuration's `idleTimeout` is set, and redirects only to the
    ///     same host.
    ///   - configuration: How requests are sent: how long they wait, how they retry, and how their images are encoded.
    ///   - auth: How requests authenticate, and where they go: ``OpenAIAuthentication/apiKey(organization:project:_:)``
    ///     to OpenAI, ``OpenAIAuthentication/apiKey(baseURL:organization:project:_:)`` to another server that speaks
    ///     its API, or ``OpenAIAuthentication/proxied(baseURL:headers:)`` to a server of your own.
    public init(
        _ details: OpenAIModel<Effort>,
        options: OpenAIOptions = OpenAIOptions(),
        session: URLSession = .shared,
        configuration: OpenAIConfiguration = OpenAIConfiguration(),
        auth: OpenAIAuthentication
    ) {
        self.init(details: details, options: options, session: session, auth: auth, configuration: configuration)
    }

    /// Creates a model with an idle timeout.
    ///
    /// - Parameters:
    ///   - details: The model, usually from the catalog, such as `.gpt6Luna`.
    ///   - options: Request settings that only OpenAI has.
    ///   - session: The URL session that sends requests.
    ///   - idleTimeout: The longest time to wait for the next data, or `nil` for the session's own timeout.
    ///   - auth: How requests authenticate, and where they go.
    @available(*, deprecated, message: "Pass the idle timeout in an OpenAIConfiguration: configuration: OpenAIConfiguration(idleTimeout:)")
    public init(
        _ details: OpenAIModel<Effort>,
        options: OpenAIOptions = OpenAIOptions(),
        session: URLSession = .shared,
        idleTimeout: Duration?,
        auth: OpenAIAuthentication
    ) {
        self.init(details, options: options, session: session, configuration: OpenAIConfiguration(idleTimeout: idleTimeout), auth: auth)
    }

    init(
        details: OpenAIModel<Effort>,
        options: OpenAIOptions,
        session: URLSession,
        auth: OpenAIAuthentication,
        configuration: OpenAIConfiguration
    ) {
        self.details = details
        self.options = options
        self.session = session
        self.auth = auth
        self.configuration = configuration
    }
}

extension OpenAILanguageModel: ConfigurableLanguageModel {}

extension OpenAILanguageModel where Effort == ContextOptions.ReasoningLevel {
    /// The same model with its efforts in their open form, so models with different effort types fit in one list.
    ///
    /// - Parameter typed: A model created from the catalog.
    public init(_ typed: OpenAILanguageModel<some ModelEffort>) {
        self.init(
            details: OpenAIModel(typed.details),
            options: typed.options,
            session: typed.session,
            auth: typed.auth,
            configuration: typed.configuration
        )
    }
}
