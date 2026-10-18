public import Foundation

/// A failure of an OpenRouter request that Foundation Models has no error for, such as a rejected API key or no
/// credits left.
///
/// Rate limits, an oversized context, content filters, refusals and timeouts throw `LanguageModelError` instead, so
/// they're handled the same way as with any other model.
public struct OpenRouterError: Error, Sendable, Equatable, LocalizedError {
    /// The HTTP status, such as 401 for a rejected key or 402 for no credits, or `nil` when the response wasn't
    /// valid.
    public let status: Int?

    /// What went wrong: the model host's own message when it gave one, otherwise OpenRouter's.
    public let message: String

    /// OpenRouter's kind of error, such as `authentication` or `payment_required`.
    public let errorType: String?

    /// The host that failed, such as `Anthropic`, when OpenRouter names one.
    public let providerName: String?

    /// How long to wait before retrying, when OpenRouter says.
    public let retryAfter: Duration?

    /// Creates an error.
    ///
    /// - Parameters:
    ///   - status: The HTTP status.
    ///   - message: What went wrong.
    ///   - errorType: OpenRouter's kind of error.
    ///   - providerName: The host that failed.
    ///   - retryAfter: How long to wait before retrying.
    public init(status: Int?, message: String, errorType: String? = nil, providerName: String? = nil, retryAfter: Duration? = nil) {
        self.status = status
        self.message = message
        self.errorType = errorType
        self.providerName = providerName
        self.retryAfter = retryAfter
    }

    /// The message, after the host's name when there is one.
    public var errorDescription: String? {
        providerName.map { "[\($0)] \(message)" } ?? message
    }
}
