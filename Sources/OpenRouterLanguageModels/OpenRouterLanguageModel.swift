public import Foundation
public import FoundationModels
public import LanguageModels

/// A model on OpenRouter, for Foundation Models sessions.
///
/// Pass a model from the catalog, and how its requests authenticate, such as with an API key read on every request:
///
/// ```swift
/// let model = OpenRouterLanguageModel(.anthropicClaudeSonnet4_6, auth: .apiKey { try await keyStore.openRouterKey() })
/// let session = LanguageModelSession(model: model, instructions: "Plan the week's meals.")
/// ```
///
/// Everything else is Foundation Models: prompts, tools, guided generation, profiles, reasoning levels, attachments
/// and generation options. A request sends only the settings that the model and each of its ``fallbacks`` list, so a
/// host never rejects one, and a debug build shows a runtime warning in Xcode for each setting left out.
///
/// What only OpenRouter has is in the articles: authentication and the app's name in <doc:GettingStarted>, fallback models
/// and hosts in <doc:RoutingAndFallbacks>, and then <doc:ServerTools>, <doc:Caching>, <doc:Attachments> and
/// <doc:ErrorsAndMetadata>.
public struct OpenRouterLanguageModel<Effort: ModelEffort>: DetailedLanguageModel {
    /// What OpenRouter reports about the model, the first one a request tries.
    public let details: OpenRouterModel<Effort>

    /// The models to try in order when the model fails, with their efforts in their open form.
    ///
    /// A request lists them after the model, and OpenRouter moves on to the next one on any error. Set them on the
    /// model's initializer to list catalog models of any effort type, or here for models picked at runtime.
    public var fallbacks: [OpenRouterModel<ContextOptions.ReasoningLevel>]

    /// Tools that OpenRouter runs for the model while it answers, such as a web search, next to the session's own
    /// tools.
    ///
    /// A request sends them unless its generation options disallow tool calls, and throws
    /// `LanguageModelError.unsupportedCapability` before sending anything when the model or a fallback doesn't take
    /// tools.
    public var serverTools: [OpenRouterServerTool]

    /// Which of the model's hosts OpenRouter may use.
    public var routing: OpenRouterRouting

    /// Request settings that only OpenRouter has.
    public var options: OpenRouterOptions

    /// How requests mark prompts for caching: ``OpenRouterCacheControl/automatic`` unless the model was created with
    /// another, or `nil` to send no marks.
    public var cacheControl: OpenRouterCacheControl?

    /// OpenRouter's response cache, which answers a repeated request with its earlier answer at no cost, or `nil` to
    /// leave it off.
    public var responseCache: OpenRouterResponseCache?

    /// The URL session that sends requests: `.shared` unless the model was created with another.
    ///
    /// A session of your own brings its configuration, such as a proxy or protocol classes, but the package still sets
    /// these on each request:
    ///
    /// - The headers: those of ``auth``, the app's attribution in `HTTP-Referer` and the
    ///   `X-OpenRouter-Title`, `X-OpenRouter-Categories` and `X-OpenRouter-App-Visibility` headers, `User-Agent`,
    ///   `Content-Type`, `Accept`, and the headers of the response cache and router metadata. Each replaces a header of
    ///   the same name in the configuration's `httpAdditionalHeaders`.
    /// - The timeout: with ``idleTimeout`` set, each request waits that long for the next data, instead of the
    ///   configuration's `timeoutIntervalForRequest`.
    /// - Redirects only to the same host, through a delegate of each request's own. A background session doesn't
    ///   support a request's own delegate, so there the session's own redirect policy applies.
    public let session: URLSession

    /// How requests authenticate, and where they go.
    public let auth: OpenRouterAuthentication

    /// Where requests go, how they name the app, and how long they wait.
    public let executorConfiguration: RequestExecutor.Configuration

    /// How requests name the app to OpenRouter.
    public var app: OpenRouterApp { executorConfiguration.app }

    /// The longest time to wait for the next data, from sending the request to the end of the answer, or `nil` for
    /// the session's own timeout.
    public var idleTimeout: Duration? { executorConfiguration.idleTimeout }

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - details: The model, usually from the catalog, such as `.anthropicClaudeSonnet4_6`.
    ///   - fallbacks: The models to try in order when the model fails, such as `.openaiGpt5Nano, .googleGemini3_1FlashLite`.
    ///     Each can have its own effort type.
    ///   - serverTools: Tools that OpenRouter runs for the model while it answers, such as `.webSearch()`.
    ///   - routing: Which of the model's hosts OpenRouter may use.
    ///   - options: Request settings that only OpenRouter has.
    ///   - cacheControl: How requests mark prompts for caching, or `nil` to send no marks. The default marks them only
    ///     when every model a request may reach caches only marked prompts, such as Claude.
    ///   - responseCache: OpenRouter's response cache, which answers a repeated request with its earlier answer at no
    ///     cost, or `nil` to leave it off.
    ///   - app: How requests name the app to OpenRouter, which credits the app's usage in its rankings.
    ///   - session: The URL session that sends requests. The package still sets each request's headers, its timeout
    ///     when `idleTimeout` is set, and its redirect policy, as ``session`` describes.
    ///   - idleTimeout: The longest time to wait for the next data, from sending the request to the end of the answer,
    ///     or `nil` for the session's own timeout. OpenRouter sends keep-alive comments while a model thinks, so this
    ///     doesn't limit a long answer.
    ///   - auth: How requests authenticate, and where they go: ``OpenRouterAuthentication/apiKey(_:)`` to OpenRouter,
    ///     or ``OpenRouterAuthentication/proxied(baseURL:headers:)`` to a server of your own.
    public init<each FallbackEffort: ModelEffort>(
        _ details: OpenRouterModel<Effort>,
        fallbacks: repeat OpenRouterModel<each FallbackEffort>,
        serverTools: [OpenRouterServerTool] = [],
        routing: OpenRouterRouting = OpenRouterRouting(),
        options: OpenRouterOptions = OpenRouterOptions(),
        cacheControl: OpenRouterCacheControl? = .automatic,
        responseCache: OpenRouterResponseCache? = nil,
        app: OpenRouterApp = OpenRouterApp(),
        session: URLSession = .shared,
        idleTimeout: Duration? = nil,
        auth: OpenRouterAuthentication
    ) {
        var bridgedFallbacks: [OpenRouterModel<ContextOptions.ReasoningLevel>] = []
        for fallback in repeat each fallbacks {
            bridgedFallbacks.append(OpenRouterModel(fallback))
        }
        self.init(
            details: details,
            fallbacks: bridgedFallbacks,
            serverTools: serverTools,
            routing: routing,
            options: options,
            cacheControl: cacheControl,
            responseCache: responseCache,
            session: session,
            auth: auth,
            configuration: RequestExecutor.Configuration(baseURL: auth.baseURL, app: app, idleTimeout: idleTimeout)
        )
    }

    init(
        details: OpenRouterModel<Effort>,
        fallbacks: [OpenRouterModel<ContextOptions.ReasoningLevel>],
        serverTools: [OpenRouterServerTool],
        routing: OpenRouterRouting,
        options: OpenRouterOptions,
        cacheControl: OpenRouterCacheControl?,
        responseCache: OpenRouterResponseCache?,
        session: URLSession,
        auth: OpenRouterAuthentication,
        configuration: RequestExecutor.Configuration
    ) {
        self.details = details
        self.fallbacks = fallbacks
        self.serverTools = serverTools
        self.routing = routing
        self.options = options
        self.cacheControl = cacheControl
        self.responseCache = responseCache
        self.session = session
        self.auth = auth
        executorConfiguration = configuration
    }
}

extension OpenRouterLanguageModel where Effort == ContextOptions.ReasoningLevel {
    /// The same model with its efforts in their open form, so models with different effort types fit in one list.
    ///
    /// - Parameter typed: A model created from the catalog.
    public init(_ typed: OpenRouterLanguageModel<some ModelEffort>) {
        self.init(
            details: OpenRouterModel(typed.details),
            fallbacks: typed.fallbacks,
            serverTools: typed.serverTools,
            routing: typed.routing,
            options: typed.options,
            cacheControl: typed.cacheControl,
            responseCache: typed.responseCache,
            session: typed.session,
            auth: typed.auth,
            configuration: RequestExecutor.Configuration(typed.executorConfiguration)
        )
    }
}
