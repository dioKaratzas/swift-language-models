import LanguageModels

/// How long a provider keeps a prompt cached when requests mark the prompt for caching.
///
/// Some providers, such as Anthropic and Alibaba's Qwen, cache a prompt only when the request marks it. With a cache
/// control set, each request asks for caching of the whole prompt and marks the end of the instructions. Each host
/// keeps its own cache, and a model can have several, such as Claude on Anthropic, Amazon Bedrock and Google Vertex.
/// A session's later requests go back to the host that cached its prompt, so they read it; another session that starts
/// the same way reads it only when OpenRouter sends it to that host too. Providers that cache on their own, such as
/// OpenAI, Google, DeepSeek and xAI, cache with or without it.
///
/// Writing a marked cache costs more than a normal prompt, and reading it costs much less. A prompt shorter than the
/// provider's minimum, such as 1,024 tokens, isn't cached at all.
public struct OpenRouterCacheControl: Sendable, Hashable {
    /// How long a cached prompt lasts after its last use.
    public enum TimeToLive: String, Sendable, Hashable {
        /// Five minutes, the providers' default.
        case fiveMinutes = "5m"

        /// One hour, which costs more to write. Providers without it use their default.
        case oneHour = "1h"
    }

    /// How long a cached prompt lasts.
    public let timeToLive: TimeToLive

    /// Caching that lasts five minutes after the prompt's last use.
    public static let ephemeral = Self.ephemeral(timeToLive: .fiveMinutes)

    /// Caching that lasts for the given time after the prompt's last use.
    ///
    /// - Parameter timeToLive: How long a cached prompt lasts.
    /// - Returns: The cache control.
    public static func ephemeral(timeToLive: TimeToLive) -> Self {
        Self(timeToLive: timeToLive)
    }

    /// The `cache_control` directive in OpenRouter's request.
    var json: JSONValue {
        ["type": "ephemeral", "ttl": timeToLive == .fiveMinutes ? nil : .string(timeToLive.rawValue)]
    }
}
