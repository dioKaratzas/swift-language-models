public import Foundation
public import LanguageModels

/// A failure of an OpenRouter request that Foundation Models has no error for, such as a rejected API key or no
/// credits left.
///
/// Rate limits, an oversized context, content filters, refusals and timeouts throw `LanguageModelError` instead, so
/// they're handled the same way as with any other model.
public struct OpenRouterError: Error, Sendable, Equatable, LocalizedError {
    /// The HTTP status, such as 401 for a rejected key or 402 for no credits, or for an error in the stream, the status
    /// its code names. `nil` when there was no response, the response wasn't usable, or an error in the stream has a
    /// code that isn't a number.
    public let status: Int?

    /// What went wrong: the model host's own message when it gave one, otherwise OpenRouter's.
    public let message: String

    /// What kind of failure it was, such as `authentication` or `paymentRequired`: OpenRouter's error type, or when
    /// the response doesn't name one, the type its HTTP status stands for, then the host's own code, such as
    /// `server_error`. When none of them says, `server` for an error in the stream and `unmapped` otherwise.
    public let code: Code

    /// The host that failed, such as `Anthropic`, when OpenRouter names one.
    ///
    /// OpenRouter calls the hosts that serve its models providers, and the name keeps OpenRouter's word: it names the
    /// host, never OpenRouter itself.
    public let providerName: OpenRouterProviderName?

    /// How long to wait before retrying, when OpenRouter says.
    public let retryAfter: Duration?

    /// Creates an error.
    ///
    /// - Parameters:
    ///   - status: The HTTP status.
    ///   - message: What went wrong.
    ///   - code: What kind of failure it was.
    ///   - providerName: The host that failed.
    ///   - retryAfter: How long to wait before retrying.
    public init(
        status: Int? = nil,
        message: String,
        code: Code = .unmapped,
        providerName: OpenRouterProviderName? = nil,
        retryAfter: Duration? = nil
    ) {
        self.status = status
        self.message = message
        self.code = code
        self.providerName = providerName
        self.retryAfter = retryAfter
    }

    /// The message, after the host's name when there is one.
    public var errorDescription: String? {
        providerName.map { "[\($0.rawValue)] \(message)" } ?? message
    }
}

extension OpenRouterError {
    /// A kind of failure: one of OpenRouter's error types, or one the package reports itself.
    public struct Code: ProviderVocabulary {
        /// The API key is missing or rejected.
        public static let authentication: Self = "authentication"

        /// The key may not do this, such as use a model it's limited from.
        public static let permissionDenied: Self = "permission_denied"

        /// The account has no credits left, or the key reached its limit.
        public static let paymentRequired: Self = "payment_required"

        /// The request asked for more output tokens than the model allows.
        public static let maxTokensExceeded: Self = "max_tokens_exceeded"

        /// A text in the request is longer than the host allows.
        public static let stringTooLong: Self = "string_too_long"

        /// The host is overloaded.
        public static let providerOverloaded: Self = "provider_overloaded"

        /// No host can serve the model now.
        public static let providerUnavailable: Self = "provider_unavailable"

        /// The request isn't valid.
        public static let invalidRequest: Self = "invalid_request"

        /// The prompt isn't valid for the model.
        public static let invalidPrompt: Self = "invalid_prompt"

        /// The model or another resource doesn't exist.
        public static let notFound: Self = "not_found"

        /// A precondition of the request isn't met.
        public static let preconditionFailed: Self = "precondition_failed"

        /// The request is too large.
        public static let payloadTooLarge: Self = "payload_too_large"

        /// The request is well formed but can't be processed.
        public static let unprocessable: Self = "unprocessable"

        /// An image in the request isn't valid.
        public static let invalidImage: Self = "invalid_image"

        /// An image is larger than the host allows.
        public static let imageTooLarge: Self = "image_too_large"

        /// An image is smaller than the host allows.
        public static let imageTooSmall: Self = "image_too_small"

        /// An image's format isn't supported.
        public static let unsupportedImageFormat: Self = "unsupported_image_format"

        /// An image URL leads nowhere.
        public static let imageNotFound: Self = "image_not_found"

        /// An image URL couldn't be downloaded.
        public static let imageDownloadFailed: Self = "image_download_failed"

        /// OpenRouter or the host failed.
        public static let server: Self = "server"

        /// A failure that neither OpenRouter's error type nor the HTTP status classifies.
        public static let unmapped: Self = "unmapped"

        /// The package's own code for a response it couldn't use, such as a stream cut off before its end.
        public static let invalidResponse: Self = "invalid_response"

        /// The package's own code for a request that never got a response, such as without a network connection.
        public static let connectionFailed: Self = "connection_failed"

        /// The code's name, as OpenRouter's `error_type` spells it.
        public let rawValue: String

        /// Creates a code from its name.
        ///
        /// - Parameter rawValue: The name, such as `"authentication"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
