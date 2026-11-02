import Foundation
public import FoundationModels
import LanguageModels

extension OpenRouterLanguageModel {
    /// Sends a model's requests to OpenRouter and streams each answer into Foundation Models.
    ///
    /// The model's executor, a `DetailedLanguageModelExecutor` of this request executor, creates it and calls it for
    /// each answer. It keeps no state between answers.
    public struct RequestExecutor: DetailedLanguageModelRequestExecutor {
        /// The model the request executor sends requests for.
        public typealias Model = OpenRouterLanguageModel

        /// Where the request executor sends requests, how it names the app and how long it waits. It holds no
        /// secrets.
        public struct Configuration: Sendable, Hashable {
            let baseURL: URL?
            let app: OpenRouterApp
            let idleTimeout: Duration?
            /// The wait before the one retry of a gateway failure.
            var retryDelay: Duration = .seconds(1)

            init(baseURL: URL?, app: OpenRouterApp = OpenRouterApp(), idleTimeout: Duration?, retryDelay: Duration = .seconds(1)) {
                self.baseURL = baseURL
                self.app = app
                self.idleTimeout = idleTimeout
                self.retryDelay = retryDelay
            }

            /// The same configuration for a model with another effort type.
            init(_ other: OpenRouterLanguageModel<some ModelEffort>.RequestExecutor.Configuration) {
                self.init(baseURL: other.baseURL, app: other.app, idleTimeout: other.idleTimeout, retryDelay: other.retryDelay)
            }
        }

        /// Where requests go, how they name the app and how long they wait, which the adapter reads.
        let configuration: Configuration

        /// Creates a request executor.
        ///
        /// - Parameter configuration: Where to send requests and how to name the app.
        public init(configuration: Configuration) {
            self.configuration = configuration
        }

        /// Sends one request and streams its answer.
        ///
        /// A failed request is retried once, only before any data arrives, when OpenRouter or the host is briefly
        /// unavailable and its `Retry-After`, if any, asks for 10 seconds or less. A request whose schema has a
        /// constraint the host rejects is sent once more with the portable schema, which carries its constraints in
        /// descriptions.
        ///
        /// - Parameters:
        ///   - request: The transcript, tools, schema and options to send.
        ///   - model: The model to answer with.
        ///   - channel: Where the answer's events go.
        /// - Returns: The answer's response text, which the model's executor checks against the request's schema.
        /// - Throws: `LanguageModelError` for failures Foundation Models has a case for, `OpenRouterError` for the
        ///   rest, and `CancellationError` when the task is cancelled. An error that the model's authentication
        ///   throws passes through as it is, unless it's a `URLError`, which maps as a failed connection's does.
        public func execute(
            _ request: LanguageModelExecutorGenerationRequest,
            model: OpenRouterLanguageModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
        ) async throws -> DetailedLanguageModelAnswer {
            try await respond(to: request, model: model, streamingInto: channel)
        }
    }
}
