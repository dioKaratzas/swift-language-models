import Foundation
import LanguageModels

/// Facts about OpenAI's API that its dialect relies on. They live outside the dialect because a generic type can't
/// store static values.
enum API {
    /// OpenAI's name, as the log and error messages name it.
    static let name = "OpenAI"

    /// The shortest wait before the one retry of a briefly unavailable gateway or host.
    static let retryDelay: Duration = .seconds(1)

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
