import Foundation
import FoundationModels

/// What OpenRouter's response cache reported about an answer, in the headers of its response.
struct ResponseCacheStatus {
    /// Whether the cache served the answer, rather than a host that the cache then kept it from.
    let isHit: Bool

    /// How long the cache had kept the answer, in seconds, on a hit.
    let age: Int?

    /// The generation id of the answer the cache kept, on a hit.
    let sourceID: String?

    /// The status that a response's headers report, or `nil` when they report none, as when the cache is off.
    init?(_ response: HTTPURLResponse?) {
        guard let response, let status = response.value(forHTTPHeaderField: "X-OpenRouter-Cache-Status") else { return nil }
        switch status.uppercased() {
        case "HIT": isHit = true
        case "MISS": isHit = false
        default: return nil
        }
        age = response.value(forHTTPHeaderField: "X-OpenRouter-Cache-Age").flatMap { Int($0) }
        sourceID = response.value(forHTTPHeaderField: "X-OpenRouter-Cache-Source-Id")
    }

    /// The status as metadata of the entry that ends the answer.
    var metadata: [String: any ConvertibleToGeneratedContent] {
        var metadata: [String: any ConvertibleToGeneratedContent] = [OpenRouterMetadataKey.responseCacheHit: isHit]
        metadata[OpenRouterMetadataKey.responseCacheAge] = age
        metadata[OpenRouterMetadataKey.responseCacheSourceID] = sourceID
        return metadata
    }
}
