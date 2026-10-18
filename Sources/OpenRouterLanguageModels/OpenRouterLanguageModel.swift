public import Foundation
import FoundationModels
public import LanguageModels

/// A model on OpenRouter, for Foundation Models sessions.
///
/// Pass a model from the catalog, and the API key as a closure that's read on every request:
///
/// ```swift
/// let model = OpenRouterLanguageModel(.anthropicClaudeSonnet4_6, apiKey: { try keychain.key(for: .openRouter) })
/// let session = LanguageModelSession(model: model, instructions: "Plan the week's meals.")
/// ```
///
/// Everything else is Foundation Models: prompts, tools, guided generation, profiles, reasoning levels and
/// generation options. A request sends only the parameters the model lists, so a setting the model doesn't take is
/// left out.
public struct OpenRouterLanguageModel<Effort: ModelEffort>: DetailedLanguageModel {
    /// What OpenRouter reports about the model.
    public let details: OpenRouterModel<Effort>

    /// Which of the model's hosts OpenRouter may use.
    public let routing: OpenRouterRouting

    /// Request settings that only OpenRouter has.
    public let options: OpenRouterOptions

    /// How long marked prompts stay cached, or `nil` to send no cache markers.
    public let cacheControl: OpenRouterCacheControl?

    /// The session that sends requests.
    let session: URLSession

    /// Returns the API key, on every request.
    let apiKey: @Sendable () async throws -> String

    public internal(set) var executorConfiguration: Executor.Configuration

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
    ///   - responseStartTimeout: How long to wait for the response to start, or `nil` for the session's own timeout.
    ///   - apiKey: Returns the OpenRouter API key. It's called for every request and never stored.
    public init(
        _ details: OpenRouterModel<Effort>,
        routing: OpenRouterRouting = OpenRouterRouting(),
        options: OpenRouterOptions = OpenRouterOptions(),
        cacheControl: OpenRouterCacheControl? = nil,
        appName: String? = nil,
        appURL: URL? = nil,
        baseURL: URL? = nil,
        session: URLSession = .shared,
        responseStartTimeout: Duration? = nil,
        apiKey: @escaping @Sendable () async throws -> String
    ) {
        self.details = details
        self.routing = routing
        self.options = options
        self.cacheControl = cacheControl
        self.session = session
        self.apiKey = apiKey
        executorConfiguration = Executor.Configuration(
            baseURL: baseURL,
            appName: appName,
            appURL: appURL,
            responseStartTimeout: responseStartTimeout
        )
    }
}
