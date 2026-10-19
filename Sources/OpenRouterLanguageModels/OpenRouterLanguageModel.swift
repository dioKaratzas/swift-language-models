public import Foundation
public import FoundationModels
public import LanguageModels

/// A model on OpenRouter, for Foundation Models sessions.
///
/// Pass a model from the catalog, and the API key as a closure that's read on every request:
///
/// ```swift
/// let model = OpenRouterLanguageModel(.anthropicClaudeSonnet4_6, apiKey: { try await keyStore.openRouterKey() })
/// let session = LanguageModelSession(model: model, instructions: "Plan the week's meals.")
/// ```
///
/// Everything else is Foundation Models: prompts, tools, guided generation, profiles, reasoning levels and
/// generation options. A request sends only the parameters the model lists, so a setting the model doesn't take is
/// left out.
///
/// ## Keys
///
/// Never ship an OpenRouter key inside an app, where anyone can extract it. Instead:
///
/// - Let the person enter their own key, keep it in the Keychain, and return it from `apiKey`. A Keychain read
///   blocks, so do it away from the main actor.
/// - During development, read it from an environment variable.
/// - In production, send requests through your own server with `baseURL`, and return a short-lived token for that
///   server from `apiKey`. Requests follow redirects only to the same host, so the token never reaches another one.
///
/// ## Response metadata
///
/// The entry that ends an answer carries the model that answered, its host, OpenRouter's generation id and why the
/// answer ended, and the answer's usage carries its cost. ``OpenRouterMetadataKey`` names the keys. An answer cut off
/// at its token limit doesn't throw; its finish reason is `length`:
///
/// ```swift
/// let response = try await session.respond(to: "Plan the week.", options: GenerationOptions(maximumResponseTokens: 200))
/// if case .response(let answer)? = response.transcriptEntries.last,
///     answer.metadata[OpenRouterMetadataKey.finishReason]?.kind == .string("length")
/// {
///     // The plan was cut short.
/// }
/// ```
public struct OpenRouterLanguageModel<Effort: ModelEffort>: DetailedLanguageModel {
    /// What OpenRouter reports about the model.
    public let details: OpenRouterModel<Effort>

    /// Which of the model's hosts OpenRouter may use.
    public var routing: OpenRouterRouting

    /// Request settings that only OpenRouter has.
    public var options: OpenRouterOptions

    /// How long marked prompts stay cached, or `nil` to send no cache markers.
    public var cacheControl: OpenRouterCacheControl?

    /// The session that sends requests.
    let session: URLSession

    /// Returns the API key, on every request.
    let apiKey: @Sendable () async throws -> String

    /// Where requests go, how they name the app, and how long they wait.
    public let executorConfiguration: Executor.Configuration

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - details: The model, usually from the catalog, such as `.anthropicClaudeSonnet4_6`.
    ///   - routing: Which of the model's hosts OpenRouter may use.
    ///   - options: Request settings that only OpenRouter has.
    ///   - cacheControl: How long marked prompts stay cached. Providers that cache only marked prompts, such as
    ///     Anthropic, cache nothing without it.
    ///   - appName: The app's name, shown in OpenRouter's rankings.
    ///   - appURL: The app's website, which OpenRouter's rankings link to.
    ///   - baseURL: Where OpenRouter's API lives, for a proxy; `nil` for OpenRouter itself.
    ///   - session: The session that sends requests.
    ///   - idleTimeout: The longest time to wait for the next data, from sending the request to the end of the answer,
    ///     or `nil` for the session's own timeout. OpenRouter sends keep-alive comments while a model thinks, so this
    ///     doesn't limit a long answer.
    ///   - apiKey: Returns the OpenRouter API key, or a token for the server at `baseURL`. It's called for every
    ///     request and never stored.
    public init(
        _ details: OpenRouterModel<Effort>,
        routing: OpenRouterRouting = OpenRouterRouting(),
        options: OpenRouterOptions = OpenRouterOptions(),
        cacheControl: OpenRouterCacheControl? = nil,
        appName: String? = nil,
        appURL: URL? = nil,
        baseURL: URL? = nil,
        session: URLSession = .shared,
        idleTimeout: Duration? = nil,
        apiKey: @escaping @Sendable () async throws -> String
    ) {
        self.init(
            details: details,
            routing: routing,
            options: options,
            cacheControl: cacheControl,
            session: session,
            apiKey: apiKey,
            configuration: Executor.Configuration(baseURL: baseURL, appName: appName, appURL: appURL, idleTimeout: idleTimeout)
        )
    }

    init(
        details: OpenRouterModel<Effort>,
        routing: OpenRouterRouting,
        options: OpenRouterOptions,
        cacheControl: OpenRouterCacheControl?,
        session: URLSession,
        apiKey: @escaping @Sendable () async throws -> String,
        configuration: Executor.Configuration
    ) {
        self.details = details
        self.routing = routing
        self.options = options
        self.cacheControl = cacheControl
        self.session = session
        self.apiKey = apiKey
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
            routing: typed.routing,
            options: typed.options,
            cacheControl: typed.cacheControl,
            session: typed.session,
            apiKey: typed.apiKey,
            configuration: Executor.Configuration(typed.executorConfiguration)
        )
    }
}
