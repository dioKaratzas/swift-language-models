import Foundation
import LanguageModels

/// Facts about OpenRouter's API that its dialect and the info calls rely on. They live outside the dialect because a
/// generic type can't store static values.
enum API {
    /// OpenRouter's name, as the log and error messages name it.
    static let name = "OpenRouter"

    /// The wait before the shared retry policy's first retry.
    static let retryDelay: Duration = .milliseconds(500)

    /// The most times a request is sent again, matching OpenAI's maximum.
    static let retryLimit = 2

    /// When a request that fails is sent again: after a failed connection or a status from 500 up, up to `retries`
    /// times, with the shared provider retry policy.
    ///
    /// A retry waits the `retry-after-ms` or `Retry-After` that OpenRouter asks for, when that's more than zero, or
    /// otherwise `delay`, doubled for each retry before it up to 16 times `delay`, cut by up to a quarter at random.
    /// A request that asks to wait more than 2 minutes fails at once.
    ///
    /// - Parameters:
    ///   - delay: The wait the backoff grows from, such as ``retryDelay``.
    ///   - retries: The most times a request is sent again, such as ``retryLimit``.
    /// - Returns: The policy.
    static func retryPolicy(
        delay: Duration, retries: Int = retryLimit
    ) -> ProviderHTTP.RetryPolicy {
        .standardBackoff(retries: retries, statuses: { (500..<600).contains($0) }, delay: delay)
    }

    /// Where OpenRouter's API lives. `URL(string:)` makes it optional, although it never fails.
    static let defaultBaseURL = URL(string: "https://openrouter.ai/api/v1/")

    /// Where a request goes: the authentication's base URL, or OpenRouter's.
    ///
    /// - Parameter baseURL: The authentication's base URL, or `nil` for OpenRouter's.
    /// - Returns: The base URL.
    /// - Throws: `OpenRouterError` with `invalidRequest` when there's no valid base URL.
    static func baseURL(_ baseURL: URL?) throws(OpenRouterError) -> URL {
        guard let base = baseURL ?? defaultBaseURL else {
            throw OpenRouterError(message: "The base URL isn't valid.", code: .invalidRequest)
        }
        return base
    }

    /// The paths of OpenRouter's API calls, under the base URL.
    enum Path {
        /// The details of one model, `GET /model/{author}/{slug}`.
        static func model(_ id: OpenRouterModelID) -> String {
            "model/\(id.rawValue)"
        }

        /// The endpoints of one model, `GET /models/{author}/{slug}/endpoints`.
        static func endpoints(of id: OpenRouterModelID) -> String {
            "models/\(id.rawValue)/endpoints"
        }
    }

    /// The names of OpenRouter's own HTTP headers.
    enum Header {
        static let appCategories: HTTPHeaderName = "X-OpenRouter-Categories"
        static let appTitle: HTTPHeaderName = "X-OpenRouter-Title"
        static let appVisibility: HTTPHeaderName = "X-OpenRouter-App-Visibility"
        static let cache: HTTPHeaderName = "X-OpenRouter-Cache"
        static let cacheAge: HTTPHeaderName = "X-OpenRouter-Cache-Age"
        static let cacheClear: HTTPHeaderName = "X-OpenRouter-Cache-Clear"
        static let cacheSourceID: HTTPHeaderName = "X-OpenRouter-Cache-Source-Id"
        static let cacheStatus: HTTPHeaderName = "X-OpenRouter-Cache-Status"
        static let cacheTimeToLive: HTTPHeaderName = "X-OpenRouter-Cache-TTL"
        static let rateLimitReset: HTTPHeaderName = "X-RateLimit-Reset"
        static let referer: HTTPHeaderName = "HTTP-Referer"
        static let routerMetadata: HTTPHeaderName = "X-OpenRouter-Metadata"
        static let sessionID: HTTPHeaderName = "X-Session-Id"
    }
}
