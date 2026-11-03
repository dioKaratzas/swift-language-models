import Foundation
import FoundationModels
import LanguageModels

extension OpenAILanguageModel {
    /// Sends a model's requests to OpenAI and streams each answer into Foundation Models.
    ///
    /// The model's executor, a `DetailedLanguageModelExecutor` of this request executor, creates it and calls it for
    /// each answer. It keeps no state between answers.
    public struct RequestExecutor: DetailedLanguageModelRequestExecutor {
        /// The model the request executor sends requests for.
        public typealias Model = OpenAILanguageModel

        /// Where the request executor sends requests and how long it waits. It holds no secrets.
        public struct Configuration: Sendable, Hashable {
            let baseURL: URL?
            let idleTimeout: Duration?
            /// The wait before the one retry of a gateway failure.
            var retryDelay = API.retryDelay

            init(baseURL: URL?, idleTimeout: Duration?, retryDelay: Duration = API.retryDelay) {
                self.baseURL = baseURL
                self.idleTimeout = idleTimeout
                self.retryDelay = retryDelay
            }

            /// The same configuration for a model with another effort type.
            init(_ other: OpenAILanguageModel<some ModelEffort>.RequestExecutor.Configuration) {
                self.init(baseURL: other.baseURL, idleTimeout: other.idleTimeout, retryDelay: other.retryDelay)
            }
        }

        /// Where requests go and how long they wait, which OpenAI's dialect reads.
        let configuration: Configuration

        /// Creates a request executor.
        ///
        /// - Parameter configuration: Where to send requests.
        public init(configuration: Configuration) {
            self.configuration = configuration
        }
    }
}
