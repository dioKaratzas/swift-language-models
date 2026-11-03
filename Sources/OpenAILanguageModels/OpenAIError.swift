public import Foundation
public import LanguageModels

/// A failure of an OpenAI request that Foundation Models has no error for, such as a rejected API key or no quota left.
///
/// Rate limits, an oversized context, content filters, refusals, timeouts and images OpenAI rejects throw
/// `LanguageModelError` instead, so they're handled the same way as with any other model, and a connection that fails,
/// such as without a network, throws its `URLError`.
public struct OpenAIError: Error, Sendable, Equatable, LocalizedError {
    /// The HTTP status, such as 401 for a rejected key, or `nil` for a failure in the stream, which arrives after the
    /// response's HTTP 200, or when there was no usable response.
    public let status: Int?

    /// What went wrong, as OpenAI said it.
    public let message: String

    /// What kind of failure it was: OpenAI's own code, such as `invalid_api_key`, or when it gives none, its error
    /// type, such as `invalid_request_error`, or the kind its HTTP status stands for, such as `authentication`.
    public let code: Code

    /// OpenAI's error type, such as `invalid_request_error` or `insufficient_quota`, when it names one, whatever the
    /// code.
    public let errorType: Code?

    /// The request setting the failure concerns, such as `model`, when OpenAI names one.
    public let parameter: String?

    /// OpenAI's id for the request, which its support asks for.
    public let requestID: String?

    /// How long to wait before retrying, when OpenAI says.
    public let retryAfter: Duration?

    /// Whether the account, organization or project ran out of quota or credits, or reached its spending limit,
    /// whatever OpenAI's code for it, such as `insufficient_quota` or `credit_balance_exhausted`. Only adding credits
    /// or raising the limit clears it; waiting and retrying don't.
    public let isQuotaExhausted: Bool

    /// Creates an error.
    ///
    /// - Parameters:
    ///   - status: The HTTP status.
    ///   - message: What went wrong.
    ///   - code: What kind of failure it was.
    ///   - parameter: The request setting the failure concerns.
    ///   - requestID: OpenAI's id for the request.
    ///   - retryAfter: How long to wait before retrying.
    ///   - isQuotaExhausted: Whether the account, organization or project ran out of quota or credits.
    public init(
        status: Int? = nil,
        message: String,
        code: Code = .unmapped,
        parameter: String? = nil,
        requestID: String? = nil,
        retryAfter: Duration? = nil,
        isQuotaExhausted: Bool = false
    ) {
        self.init(
            status: status, message: message, code: code, errorType: nil, parameter: parameter, requestID: requestID,
            retryAfter: retryAfter, isQuotaExhausted: isQuotaExhausted)
    }

    /// Creates an error with OpenAI's error type.
    ///
    /// - Parameters:
    ///   - status: The HTTP status.
    ///   - message: What went wrong.
    ///   - code: What kind of failure it was.
    ///   - errorType: OpenAI's error type, or `nil` when it names none.
    ///   - parameter: The request setting the failure concerns.
    ///   - requestID: OpenAI's id for the request.
    ///   - retryAfter: How long to wait before retrying.
    ///   - isQuotaExhausted: Whether the account, organization or project ran out of quota or credits.
    public init(
        status: Int? = nil,
        message: String,
        code: Code = .unmapped,
        errorType: Code?,
        parameter: String? = nil,
        requestID: String? = nil,
        retryAfter: Duration? = nil,
        isQuotaExhausted: Bool = false
    ) {
        self.status = status
        self.message = message
        self.code = code
        self.errorType = errorType
        self.parameter = parameter
        self.requestID = requestID
        self.retryAfter = retryAfter
        self.isQuotaExhausted = isQuotaExhausted
    }

    /// The message.
    public var errorDescription: String? {
        message
    }
}

extension OpenAIError {
    /// A kind of failure: one of OpenAI's codes or error types, or one the package reports itself.
    public struct Code: ProviderVocabulary {
        /// The API key is missing, rejected or revoked.
        public static let invalidAPIKey: Self = "invalid_api_key"

        /// The account or project has no quota left. OpenAI has more codes for credits and spending limits that ran
        /// out, which ``OpenAIError/isQuotaExhausted`` covers all of.
        public static let insufficientQuota: Self = "insufficient_quota"

        /// The model doesn't exist, or the key may not use it.
        public static let modelNotFound: Self = "model_not_found"

        /// OpenAI failed while it handled the request.
        public static let serverError: Self = "server_error"

        /// The request isn't valid.
        public static let invalidRequest: Self = "invalid_request_error"

        /// The package's code for an HTTP 401 without a code of OpenAI's: the request didn't authenticate.
        public static let authentication: Self = "authentication"

        /// The package's code for an HTTP 403 without a code of OpenAI's: the key may not do this, such as from an
        /// unsupported region.
        public static let permissionDenied: Self = "permission_denied"

        /// The package's code for an HTTP 404 without a code of OpenAI's: what the request names doesn't exist.
        public static let notFound: Self = "not_found"

        /// The package's code for an HTTP 409 without a code of OpenAI's: the request conflicts with another.
        public static let conflict: Self = "conflict"

        /// The package's code for an HTTP 422 without a code of OpenAI's: the request is well formed but can't be
        /// handled.
        public static let unprocessable: Self = "unprocessable"

        /// The package's code for an HTTP 5xx without a code of OpenAI's: OpenAI failed or is overloaded.
        public static let server: Self = "server"

        /// The package's code for a response it couldn't use, such as a stream cut off before its end.
        public static let invalidResponse: Self = "invalid_response"

        /// A failure that neither OpenAI's code nor the HTTP status classifies.
        public static let unmapped: Self = "unmapped"

        /// The code's name.
        public let rawValue: String

        /// Creates a code from its name.
        ///
        /// - Parameter rawValue: The name, such as `"invalid_api_key"`.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
