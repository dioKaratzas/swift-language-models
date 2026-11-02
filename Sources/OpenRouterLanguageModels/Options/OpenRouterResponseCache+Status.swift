import LanguageModels

extension OpenRouterResponseCache {
    /// Whether the response cache served an answer, in the cache's own word for it, such as `HIT`.
    public struct Status: ProviderVocabulary {
        /// The cache served an answer it kept from an earlier request, at no cost.
        public static let hit: Self = "HIT"

        /// The cache had no answer for the request, so a host answered, and the cache now keeps the answer.
        public static let miss: Self = "MISS"

        /// The status's word in OpenRouter's response headers.
        public let rawValue: String

        /// Creates a status from its word in OpenRouter's response headers.
        ///
        /// - Parameter rawValue: The word, such as `"HIT"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
