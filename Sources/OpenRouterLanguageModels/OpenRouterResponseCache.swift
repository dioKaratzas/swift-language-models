import LanguageModels
import os

/// OpenRouter's response cache, which answers a request that repeats an earlier one with the earlier answer, at no
/// cost.
///
/// With a response cache set, OpenRouter keeps each successful answer, and a later request with the same API key and
/// the same body gets the kept answer back at once, streamed as before, without reaching a host:
///
/// ```swift
/// var model = OpenRouterLanguageModel(.openaiGpt5Mini, apiKey: { try await keyStore.openRouterKey() })
/// model.responseCache = OpenRouterResponseCache(timeToLive: .seconds(3_600))
/// ```
///
/// A hit bills nothing: its usage is zero tokens and its cost zero. It has a response id of its own, and its entry
/// names the answer it repeats under ``OpenRouterMetadataKey/responseCacheSourceID``.
/// ``OpenRouterMetadataKey/responseCacheHit`` says whether the cache served an answer.
///
/// - A hit repeats the kept answer as it is, whatever the temperature, sampling mode or seed, so sampling with
///   randomness gives the same answer each time. Set ``refreshes`` to replace kept answers with new ones.
/// - A request repeats another only when every part of its body does: the model and its fallbacks, the transcript,
///   tools, schema and options, the request metadata and ``OpenRouterOptions/endUserID``. Each request sends the
///   session's transcript so far, so a hit needs a session that has gone the same way, such as a new session with the
///   same instructions and first prompt, or a workflow that runs again after it failed.
/// - The session id that keeps a session's requests on the host that cached its prompt differs for every session, so
///   while the cache is on it goes in the `X-Session-Id` header, which the cache doesn't compare, instead of the body.
///   A session's requests still go to one host.
/// - OpenRouter keeps only successful answers, tool calls included, and may drop one before it expires. Two identical
///   requests sent at once both miss, and both are billed.
/// - The cache belongs to the API key: another key, even of the same account, starts empty. OpenRouter turns the cache
///   off for an account that enforces zero data retention.
public struct OpenRouterResponseCache: Sendable, Hashable {
    /// How long OpenRouter keeps an answer, in whole seconds from 1 second to 24 hours.
    public let timeToLive: Duration

    /// Whether each request replaces the answer kept for it with a new one, which is kept for ``timeToLive``.
    ///
    /// The request reaches a host and is billed like one without the cache. Set it on a copy of the model for the
    /// requests whose kept answers are stale.
    public var refreshes: Bool

    /// Creates a response cache.
    ///
    /// - Parameters:
    ///   - timeToLive: How long OpenRouter keeps an answer. A fraction of a second is dropped, and the rest is clamped
    ///     to 1 second through 24 hours.
    ///   - refreshes: Whether each request replaces the answer kept for it with a new one.
    public init(timeToLive: Duration = .seconds(300), refreshes: Bool = false) {
        let kept = Self.timeToLive(clamping: timeToLive)
        self.timeToLive = kept
        self.refreshes = refreshes
        guard kept != timeToLive else { return }
        let requested = Double(timeToLive.components.seconds) + Double(timeToLive.components.attoseconds) / 1e18
        let message = """
            OpenRouter's response cache keeps answers for whole seconds from 1 second to 24 hours, so a time to live of \
            \(requested) s becomes \(kept.components.seconds) s.
            """
        PackageLogger.openRouter(.info)?.info("\(message, privacy: .public)")
    }

    /// A time to live in whole seconds from 1 second to 24 hours, as OpenRouter takes it.
    static func timeToLive(clamping requested: Duration) -> Duration {
        .seconds(min(max(requested.components.seconds, 1), 86_400))
    }

    /// The request headers that turn the cache on, set how long an answer is kept and replace the kept answer when
    /// refreshing, with the session id, which the cache doesn't compare.
    ///
    /// - Parameter sessionID: The id that keeps a session's requests on one host, or `nil` when there's none.
    /// - Returns: The headers by name.
    func headers(sessionID: String?) -> [String: String] {
        var headers = ["X-OpenRouter-Cache": "true", "X-OpenRouter-Cache-TTL": String(timeToLive.components.seconds)]
        headers["X-OpenRouter-Cache-Clear"] = refreshes ? "true" : nil
        headers["X-Session-Id"] = sessionID
        return headers
    }
}
