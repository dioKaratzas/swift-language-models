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

        /// Where the request executor sends requests, with the model's ``OpenAIConfiguration``. It holds no secrets.
        ///
        /// The model makes it from its authentication's base URL and its configuration, so an app sets
        /// ``OpenAILanguageModel/configuration`` rather than this.
        public struct Configuration: Sendable, Hashable {
            let baseURL: URL?
            let settings: OpenAIConfiguration

            init(baseURL: URL?, settings: OpenAIConfiguration) {
                self.baseURL = baseURL
                self.settings = settings
            }

            /// The same configuration for a model with another effort type.
            init(_ other: OpenAILanguageModel<some ModelEffort>.RequestExecutor.Configuration) {
                self.init(baseURL: other.baseURL, settings: other.settings)
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
