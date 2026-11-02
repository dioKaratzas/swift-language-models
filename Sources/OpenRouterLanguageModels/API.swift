import Foundation

/// Facts about OpenRouter's API that the executor and the info calls rely on. They live outside the executor because a
/// generic type can't store static values.
enum API {
    /// Where OpenRouter's API lives. `URL(string:)` makes it optional, although it never fails.
    static let defaultBaseURL = URL(string: "https://openrouter.ai/api/v1/")

    /// Where a request goes: the authentication's base URL, or OpenRouter's.
    ///
    /// - Parameter baseURL: The authentication's base URL, or `nil` for OpenRouter's.
    /// - Returns: The base URL.
    /// - Throws: `OpenRouterError` with `invalidRequest` when there's no valid base URL.
    static func baseURL(_ baseURL: URL?) throws -> URL {
        guard let base = baseURL ?? defaultBaseURL else {
            throw OpenRouterError(message: "The base URL isn't valid.", code: .invalidRequest)
        }
        return base
    }

    /// The statuses of a briefly unavailable gateway or host, which are retried once.
    static let gatewayStatuses: Set<Int> = [502, 503, 504, 529]

    /// The decoder of every chunk and response body, which requests share, since `JSONDecoder` is `Sendable`.
    static let decoder = JSONDecoder()

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
        static let appCategories = "X-OpenRouter-Categories"
        static let appTitle = "X-OpenRouter-Title"
        static let appVisibility = "X-OpenRouter-App-Visibility"
        static let cache = "X-OpenRouter-Cache"
        static let cacheAge = "X-OpenRouter-Cache-Age"
        static let cacheClear = "X-OpenRouter-Cache-Clear"
        static let cacheSourceID = "X-OpenRouter-Cache-Source-Id"
        static let cacheStatus = "X-OpenRouter-Cache-Status"
        static let cacheTimeToLive = "X-OpenRouter-Cache-TTL"
        static let rateLimitReset = "X-RateLimit-Reset"
        static let referer = "HTTP-Referer"
        static let routerMetadata = "X-OpenRouter-Metadata"
        static let sessionID = "X-Session-Id"
    }
}
