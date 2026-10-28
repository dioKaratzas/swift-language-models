import LanguageModels

/// How requests mark prompts for caching, and how long a cached prompt lasts.
///
/// Some providers, Anthropic for Claude and Alibaba for Qwen, cache a prompt only when the request marks it. Others,
/// such as OpenAI, Google, DeepSeek and xAI, cache long prompts on their own, with or without marks. A marked request
/// asks for caching of the whole prompt and marks the end of the instructions.
///
/// ``automatic``, the model's default, marks a request only when every model it may reach, fallbacks included, caches
/// only marked prompts. ``always`` marks every request, such as for Claude with another vendor's fallback, or for
/// Gemini, where a mark switches implicit caching to explicit caching, which bills storage.
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

    /// Whether every request is marked, whatever models it may reach.
    let marksEveryModel: Bool

    /// Five-minute caching, marked only when every model a request may reach caches only marked prompts.
    public static let automatic = Self.automatic(timeToLive: .fiveMinutes)

    /// Five-minute caching, marked on every request.
    public static let always = Self.always(timeToLive: .fiveMinutes)

    /// Caching that lasts for the given time, marked only when every model a request may reach caches only marked
    /// prompts: Claude, and the Qwen models whose pricing lists a cache write price.
    ///
    /// - Parameter timeToLive: How long a cached prompt lasts.
    /// - Returns: The cache control.
    public static func automatic(timeToLive: TimeToLive) -> Self {
        Self(timeToLive: timeToLive, marksEveryModel: false)
    }

    /// Caching that lasts for the given time, marked on every request.
    ///
    /// - Parameter timeToLive: How long a cached prompt lasts.
    /// - Returns: The cache control.
    public static func always(timeToLive: TimeToLive) -> Self {
        Self(timeToLive: timeToLive, marksEveryModel: true)
    }

    /// The `cache_control` directive in OpenRouter's request.
    var json: JSONValue {
        ["type": "ephemeral", "ttl": timeToLive == .fiveMinutes ? nil : .string(timeToLive.rawValue)]
    }
}

extension OpenRouterLanguageModel {
    /// The cache control a request sends: the model's own, unless it's automatic and a model the request may reach
    /// caches prompts without marks.
    var requestCacheControl: OpenRouterCacheControl? {
        guard let cacheControl else { return nil }
        let needsMarks = details.cachesOnlyMarkedPrompts && fallbacks.allSatisfy(\.cachesOnlyMarkedPrompts)
        return cacheControl.marksEveryModel || needsMarks ? cacheControl : nil
    }
}

extension OpenRouterModel {
    /// Whether the model's hosts cache a prompt only when the request marks it: Anthropic's for Claude, and Alibaba's
    /// for the Qwen models that list a cache write price.
    fileprivate var cachesOnlyMarkedPrompts: Bool {
        id.isAnthropic || (id.isQwen && pricing?.cacheWrite != nil)
    }
}
