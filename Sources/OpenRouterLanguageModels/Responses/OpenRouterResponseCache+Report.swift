import Foundation
import FoundationModels
import LanguageModels

extension OpenRouterResponseCache {
    /// What OpenRouter's response cache reported about an answer, in the headers of its response.
    struct Report {
        /// Whether the cache served the answer or kept a new one.
        let status: Status

        /// How long the cache had kept the answer, in seconds, on a hit.
        private let age: Int?

        /// The generation id of the answer the cache kept, on a hit.
        private let sourceID: String?

        /// The report that a response's headers hold, or `nil` when they hold none, as when the cache is off.
        ///
        /// - Parameter header: The value of one of the response's headers, or `nil` when it has none.
        init?(header: (HTTPHeaderName) -> String?) {
            guard let status = header(API.Header.cacheStatus), !status.isEmpty else { return nil }
            self.status = Status(rawValue: status.uppercased())
            age = header(API.Header.cacheAge).flatMap { Int($0) }
            sourceID = header(API.Header.cacheSourceID)
        }

        /// The report as metadata of the entry that ends the answer.
        var metadata: [String: any ConvertibleToGeneratedContent] {
            var metadata: [String: any ConvertibleToGeneratedContent] = [OpenRouterMetadataKey.responseCacheStatus: status.rawValue]
            metadata[OpenRouterMetadataKey.responseCacheAge] = age
            metadata[OpenRouterMetadataKey.responseCacheSourceID] = sourceID
            return metadata
        }
    }
}
