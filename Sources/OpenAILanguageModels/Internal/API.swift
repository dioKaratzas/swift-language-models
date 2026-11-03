import Foundation
import LanguageModels

/// Facts about OpenAI's API that its dialect relies on. They live outside the dialect because a generic type can't
/// store static values.
enum API {
    /// OpenAI's name, as the log and error messages name it.
    static let name = "OpenAI"

    /// The wait before the first retry, which doubles for each retry after it, as the official SDKs wait.
    static let retryDelay: Duration = .milliseconds(500)

    /// When a request that fails is sent again, as the official SDKs retry it: up to twice, after a failed connection
    /// or a 408, 409, 429 or any status from 500 up, or whatever status when `x-should-retry` is `true`, but never when
    /// it's `false`.
    ///
    /// A retry waits the `retry-after-ms` or `Retry-After` that OpenAI asks for when that's more than zero and at most
    /// 2 minutes, as openai-python does, and otherwise `delay`, doubled for each retry before it up to 16 times `delay`,
    /// cut by up to a quarter at random. A request that OpenAI asks to wait more than 2 minutes fails at once.
    ///
    /// - Parameter delay: The wait before the first retry, such as ``retryDelay``.
    /// - Returns: The policy.
    static func retryPolicy(delay: Duration) -> ProviderHTTP.RetryPolicy {
        .standardBackoff(statuses: { [408, 409, 429].contains($0) || $0 >= 500 }, delay: delay)
    }

    /// Where OpenAI's API lives. `URL(string:)` makes it optional, although it never fails.
    static let defaultBaseURL = URL(string: "https://api.openai.com/v1/")

    /// Where a request goes: the authentication's base URL, or OpenAI's.
    ///
    /// - Parameter baseURL: The authentication's base URL, or `nil` for OpenAI's.
    /// - Returns: The base URL.
    /// - Throws: `OpenAIError` with `invalidRequest` when there's no valid base URL.
    static func baseURL(_ baseURL: URL?) throws(OpenAIError) -> URL {
        guard let base = baseURL ?? defaultBaseURL else {
            throw OpenAIError(message: "The base URL isn't valid.", code: .invalidRequest)
        }
        return base
    }

    /// The names of OpenAI's own HTTP headers.
    enum Header {
        static let organization: HTTPHeaderName = "OpenAI-Organization"
        static let project: HTTPHeaderName = "OpenAI-Project"
        static let rateLimitResetRequests: HTTPHeaderName = "x-ratelimit-reset-requests"
        static let rateLimitResetTokens: HTTPHeaderName = "x-ratelimit-reset-tokens"
    }
}
