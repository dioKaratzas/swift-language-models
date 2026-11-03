import Foundation
import FoundationModels
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
            /// The wait before the one retry of a brief failure.
            var retryDelay = API.retryDelay

            init(baseURL: URL?, app: OpenRouterApp = OpenRouterApp(), idleTimeout: Duration?, retryDelay: Duration = API.retryDelay) {
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

        /// Where requests go, how they name the app and how long they wait, which OpenRouter's dialect reads.
        let configuration: Configuration

        /// Creates a request executor.
        ///
        /// - Parameter configuration: Where to send requests and how to name the app.
        public init(configuration: Configuration) {
            self.configuration = configuration
        }
    }
}
