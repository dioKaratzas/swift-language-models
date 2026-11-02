import Foundation
import FoundationModels

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
        init?(_ response: HTTPURLResponse?) {
            guard let response, let status = response.value(forHTTPHeaderField: "X-OpenRouter-Cache-Status"), !status.isEmpty
            else { return nil }
            self.status = Status(rawValue: status.uppercased())
            age = response.value(forHTTPHeaderField: "X-OpenRouter-Cache-Age").flatMap { Int($0) }
            sourceID = response.value(forHTTPHeaderField: "X-OpenRouter-Cache-Source-Id")
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
