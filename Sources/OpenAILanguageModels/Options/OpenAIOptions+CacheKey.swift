extension OpenAIOptions {
    /// The key that groups requests whose prompts start the same, so OpenAI's prompt cache serves their shared start
    /// more often. It goes out as `prompt_cache_key`.
    public struct CacheKey: Sendable, Hashable {
        /// Each session's own key: the id of its first prompt, which stays the same for the whole session.
        public static let session = Self(kind: .session)

        /// A key of the app's own, such as one for every session that shares the same long instructions.
        ///
        /// - Parameter key: The key.
        /// - Returns: The cache key.
        public static func named(_ key: String) -> Self {
            Self(kind: .named(key))
        }

        enum Kind: Sendable, Hashable {
            case session
            case named(String)
        }

        let kind: Kind
    }
}
