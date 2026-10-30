import Foundation

/// Facts about OpenRouter's API that the executor and the info calls rely on. They live outside the executor because a
/// generic type can't store static values.
enum API {
    /// Where OpenRouter's API lives. `URL(string:)` makes it optional, although it never fails.
    static let defaultBaseURL = URL(string: "https://openrouter.ai/api/v1/")

    /// The statuses of a briefly unavailable gateway or host, which are retried once.
    static let gatewayStatuses: Set<Int> = [502, 503, 504, 529]

    /// The most bytes of a failed response's body to read.
    static let errorBodyLimit = 1 << 20

    /// The most app categories OpenRouter takes on one request.
    static let appCategoryLimit = 2

    /// The decoder of every chunk and response body, which requests share, since `JSONDecoder` is `Sendable`.
    static let decoder = JSONDecoder()
}
