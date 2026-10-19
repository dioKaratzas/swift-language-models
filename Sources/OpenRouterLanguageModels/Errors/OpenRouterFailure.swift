import Foundation
import FoundationModels
import LanguageModels

/// A failure OpenRouter reported, before it becomes the error a session throws.
///
/// Failures Foundation Models has a case for throw `LanguageModelError`, so apps handle them the same way for every
/// model. The rest throw `OpenRouterError`.
struct OpenRouterFailure: Sendable {
    /// The HTTP status, or for an error in a stream, which arrives with HTTP 200, the status its code names.
    let status: Int
    let body: OpenRouterErrorResponse
    /// How long OpenRouter asks to wait, from the `Retry-After` or `X-RateLimit-Reset` header.
    let retryAfter: Duration?

    /// A failed response.
    ///
    /// - Parameters:
    ///   - status: The response's HTTP status.
    ///   - body: Its error, or `nil` when the body wasn't OpenRouter's JSON, such as a gateway's HTML page; the
    ///     status's own text stands in for it.
    ///   - retryAfter: How long the response asks to wait.
    init(status: Int, body: OpenRouterErrorResponse?, retryAfter: Duration?) {
        self.status = status
        self.body = body ?? OpenRouterErrorResponse(message: HTTPURLResponse.localizedString(forStatusCode: status))
        self.retryAfter = retryAfter
    }

    /// An error event in a stream.
    init(streamError body: OpenRouterErrorResponse) {
        status = body.status ?? 200
        self.body = body
        retryAfter = nil
    }

    /// The error to throw.
    ///
    /// - Parameters:
    ///   - contextSize: The model's context size, for an oversized prompt.
    ///   - now: The time a rate limit's reset date counts from.
    /// - Returns: `LanguageModelError` when Foundation Models has a case for the failure, otherwise `OpenRouterError`.
    func error(contextSize: Int?, now: Date = .now) -> any Error {
        let message = body.bestMessage
        let code = self.code
        let metadata = self.metadata
        switch code {
        case .contextLengthExceeded, .tokenLimitExceeded:
            let sizes = Self.sizes(in: message)
            // Foundation Models takes numbers here; 0 stands for a size neither the message nor the model gives.
            return LanguageModelError.contextSizeExceeded(
                .init(
                    contextSize: sizes.limit ?? contextSize ?? 0,
                    tokenCount: sizes.requested ?? 0,
                    debugDescription: message,
                    metadata: metadata
                )
            )
        case .rateLimitExceeded:
            return rateLimited(message, metadata, now: now)
        case .contentPolicyViolation:
            return LanguageModelError.guardrailViolation(.init(debugDescription: message, metadata: metadata))
        case .refusal:
            return LanguageModelError.refusal(.init(explanation: message, debugDescription: message, metadata: metadata))
        case .timeout:
            return LanguageModelError.timeout(.init(debugDescription: message, metadata: metadata))
        default:
            break
        }
        switch status {
        case 429:
            return rateLimited(message, metadata, now: now)
        case 402 where body.isInFlightBudget:
            // Too much is in flight at once; it clears as requests finish, like a rate limit.
            return rateLimited(message, metadata, now: now)
        case 408, 524:
            return LanguageModelError.timeout(.init(debugDescription: message, metadata: metadata))
        case 403 where body.isModeration:
            return LanguageModelError.guardrailViolation(.init(debugDescription: message, metadata: metadata))
        default:
            return OpenRouterError(
                status: status,
                message: message,
                code: code,
                providerName: body.providerName,
                retryAfter: retryAfter
            )
        }
    }

    private func rateLimited(_ message: String, _ metadata: [String: any Sendable], now: Date) -> LanguageModelError {
        let resetDate = retryAfter.map { now.addingTimeInterval($0 / .seconds(1)) }
        return .rateLimited(.init(resetDate: resetDate, debugDescription: message, metadata: metadata))
    }

    private var metadata: [String: any Sendable] {
        var metadata: [String: any Sendable] = [:]
        metadata["status"] = status
        metadata["code"] = code.rawValue
        metadata["providerName"] = body.providerName?.rawValue
        return metadata
    }

    /// The kind of failure: the error type the body names, or for a body without one, the type its status stands for.
    /// A 400 whose message names the context's length or window is an oversized prompt, which OpenRouter rejects
    /// itself before any host sees it.
    private var code: OpenRouterError.Code {
        if let type = body.errorType { return type }
        if status == 400, body.bestMessage.contains(/(?i)context (length|window)/) { return .contextLengthExceeded }
        return Self.codesByStatus[status] ?? .unmapped
    }

    /// The error type each status stands for, for a body that doesn't name one. OpenRouter's own 502 and 503 mean no
    /// host could serve the request, and a 529 is an overloaded host.
    private static let codesByStatus: [Int: OpenRouterError.Code] = [
        400: .invalidRequest,
        401: .authentication,
        402: .paymentRequired,
        403: .permissionDenied,
        404: .notFound,
        408: .timeout,
        412: .preconditionFailed,
        413: .payloadTooLarge,
        422: .unprocessable,
        429: .rateLimitExceeded,
        500: .server,
        502: .providerUnavailable,
        503: .providerUnavailable,
        524: .timeout,
        529: .providerOverloaded,
    ]

    /// The context limit and the requested size in a message such as "maximum context length is 200000 tokens.
    /// However, you requested about 250000 tokens".
    private static func sizes(in message: String) -> (limit: Int?, requested: Int?) {
        let limit = message.firstMatch(of: /maximum context length is (\d+)/).flatMap { Int($0.1) }
        let requested = message.firstMatch(of: /requested (?:about )?(\d+)/).flatMap { Int($0.1) }
        return (limit, requested)
    }
}

extension OpenRouterError.Code {
    // OpenRouter's error types that become `LanguageModelError`, so they never reach an `OpenRouterError`.
    static let contextLengthExceeded: Self = "context_length_exceeded"
    static let tokenLimitExceeded: Self = "token_limit_exceeded"
    static let rateLimitExceeded: Self = "rate_limit_exceeded"
    static let contentPolicyViolation: Self = "content_policy_violation"
    static let refusal: Self = "refusal"
    static let timeout: Self = "timeout"
}
