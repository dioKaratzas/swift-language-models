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

        /// Where the request executor sends requests and how it names the app, with the model's
        /// ``OpenRouterConfiguration``. It holds no secrets.
        ///
        /// The model makes it from its authentication's base URL, its app and its configuration, so an app sets
        /// ``OpenRouterLanguageModel/configuration`` rather than this.
        public struct Configuration: Sendable, Hashable {
            let baseURL: URL?
            let app: OpenRouterApp
            let settings: OpenRouterConfiguration

            init(baseURL: URL?, app: OpenRouterApp = OpenRouterApp(), settings: OpenRouterConfiguration) {
                self.baseURL = baseURL
                self.app = app
                self.settings = settings
            }

            /// The same configuration for a model with another effort type.
            init(_ other: OpenRouterLanguageModel<some ModelEffort>.RequestExecutor.Configuration) {
                self.init(baseURL: other.baseURL, app: other.app, settings: other.settings)
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
