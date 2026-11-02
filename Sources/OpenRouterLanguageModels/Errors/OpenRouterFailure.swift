import Foundation
import FoundationModels
import LanguageModels

/// A failure OpenRouter reported, before it becomes the error a session throws.
///
/// Failures Foundation Models has a case for throw `LanguageModelError`, so apps handle them the same way for every
/// model. The rest throw `OpenRouterError`.
struct OpenRouterFailure: Sendable {
    /// The HTTP status, or for an error in a stream, which arrives with HTTP 200, the status its code names, if the
    /// code is a number.
    let status: Int?
    let body: OpenRouterErrorResponse
    /// How long OpenRouter asks to wait, from the `Retry-After` or `X-RateLimit-Reset` header.
    let retryAfter: Duration?
    /// The kind of failure.
    let code: OpenRouterError.Code
    /// The host that failed: the one the body names, or for an error in a stream, the one its chunk names.
    let providerName: OpenRouterProviderName?

    /// A failed response.
    ///
    /// - Parameters:
    ///   - status: The response's HTTP status.
    ///   - body: Its error, or `nil` when the body wasn't OpenRouter's JSON, such as a gateway's HTML page; the
    ///     status's own text stands in for it.
    ///   - retryAfter: How long the response asks to wait.
    init(status: Int, body: OpenRouterErrorResponse?, retryAfter: Duration?) {
        let body = body ?? OpenRouterErrorResponse(message: HTTPURLResponse.localizedString(forStatusCode: status))
        self.status = status
        self.body = body
        self.retryAfter = retryAfter
        code = Self.code(of: body, status: status) ?? .unmapped
        providerName = body.providerName
    }

    /// A failed response, with the delay its `Retry-After` or `X-RateLimit-Reset` header asks for.
    init(_ failure: ProviderHTTP.Failure) {
        self.init(
            status: failure.status,
            body: try? API.decoder.decode(OpenRouterErrorResponse.Envelope.self, from: failure.body).error,
            retryAfter: failure.retryAfter
                ?? Duration(rateLimitReset: failure.response?.value(forHTTPHeaderField: API.Header.rateLimitReset))
        )
    }

    /// An error event in a stream, which arrives after the response's HTTP 200.
    ///
    /// An error that names neither an error type nor a code is the host failing while it generates, so its code is
    /// `server`.
    ///
    /// - Parameters:
    ///   - body: The event's error.
    ///   - provider: The host the event's chunk names.
    init(streamError body: OpenRouterErrorResponse, provider: OpenRouterProviderName?) {
        status = body.status
        self.body = body
        retryAfter = nil
        code = Self.code(of: body, status: body.status) ?? .server
        providerName = body.providerName ?? provider
    }

    /// The error to throw.
    ///
    /// - Parameters:
    ///   - contextSize: The model's context size, for an oversized prompt.
    ///   - imageEntries: The request's entries that carry an image, which an error for an image the host rejects names.
    ///   - now: The time a rate limit's reset date counts from.
    /// - Returns: `LanguageModelError` when Foundation Models has a case for the failure, otherwise `OpenRouterError`.
    func error(contextSize: Int?, imageEntries: [Transcript.Entry] = [], now: Date = .now) -> any Error {
        let message = body.bestMessage
        let metadata = self.metadata
        let failure: LanguageModelError.ProviderFailure
        switch kind {
        case .contextSizeExceeded:
            let sizes = Self.sizes(in: message)
            failure = .contextSizeExceeded(contextSize: sizes.limit ?? contextSize ?? 0, tokenCount: sizes.requested ?? 0)
        case .rateLimited:
            failure = .rateLimited(resetDate: body.budgetResetDate ?? retryAfter.map { now.addingTimeInterval($0 / .seconds(1)) })
        case .guardrailViolation:
            failure = .guardrailViolation
        case .refusal:
            failure = .refusal
        case .timeout:
            failure = .timeout
        case .unsupportedImage:
            failure = .unsupportedContent(imageEntries)
        case .openRouterError:
            return OpenRouterError(status: status, message: message, code: code, providerName: providerName, retryAfter: retryAfter)
        }
        return LanguageModelError(failure, message: message, metadata: metadata)
    }

    /// Whether the host rejected a constraint of the response schema: a 400 whose message names a constraint keyword,
    /// one the portable schema moves into descriptions, and says it isn't supported, permitted or allowed. Seed sends
    /// "Keyword 'maxItems' is not supported for type 'array'", and Cohere "received non-supported constraint for type:
    /// 'array'. constraint: 'minItems'".
    var rejectsSchemaConstraint: Bool {
        guard status == 400 else { return false }
        let message = body.bestMessage
        let constraint =
            #/
            \b(minItems | maxItems | uniqueItems | minimum | maximum | exclusiveMinimum | exclusiveMaximum | multipleOf
            | minLength | maxLength | pattern)\b
            /#
        return message.contains(constraint) && message.contains(/(?i)not supported|non-supported|unsupported|not permitted|not allowed/)
    }

    /// What the failure becomes: the `LanguageModelError` case for its code, or for a 402 or 403 that the body shows to
    /// be a rate limit or a moderation flag, otherwise an `OpenRouterError`. A status that stands for one of these
    /// cases already gave the failure its code.
    private var kind: Kind {
        switch (code, status) {
        case (.contextLengthExceeded, _): .contextSizeExceeded
        case (.rateLimitExceeded, _): .rateLimited
        case (.contentPolicyViolation, _): .guardrailViolation
        case (.refusal, _): .refusal
        case (.timeout, _): .timeout
        // The host can't use an image, as for one the package can't send; one it can't download stays OpenRouter's.
        case (.unsupportedImageFormat, _), (.invalidImage, _), (.imageTooLarge, _), (.imageTooSmall, _): .unsupportedImage
        // Too much is in flight at once; it clears as requests finish, like a rate limit.
        case (_, 402?) where body.isInFlightBudget: .rateLimited
        // A spending budget that resets clears at its reset date, like a rate limit.
        case (.budgetExceeded, _) where body.budgetResetDate != nil: .rateLimited
        case (_, 403?) where body.isModeration: .guardrailViolation
        default: .openRouterError
        }
    }

    /// The metadata of a `LanguageModelError`: the status, the code, the host that failed and the budget it ran into.
    private var metadata: [String: any Sendable] {
        var metadata = LanguageModelError.failureMetadata(status: status, code: code.rawValue, provider: providerName?.rawValue)
        metadata[OpenRouterMetadataKey.limitSource] = body.limitSource?.rawValue
        return metadata
    }

    /// The kind of failure: the error type the body names, then the type its status stands for, then the code the body
    /// names as text, such as a host's `server_error`. A 400 whose message names the context's length or window is an
    /// oversized prompt, which OpenRouter rejects itself before any host sees it.
    ///
    /// - Returns: The code, or `nil` when neither the body nor the status names one.
    private static func code(of body: OpenRouterErrorResponse, status: Int?) -> OpenRouterError.Code? {
        if let type = body.errorType { return type }
        if status == 400, body.bestMessage.contains(/(?i)context (length|window)/) { return .contextLengthExceeded }
        if status == 403, body.limitSource != nil { return .budgetExceeded }
        if let status, let code = codesByStatus[status] { return code }
        return body.textCode.map(OpenRouterError.Code.init(rawValue:))
    }

    /// The error type each status stands for, for a body that doesn't name one. OpenRouter's own 502 and 503 mean no
    /// host could serve the request, a 504 or 524 is a gateway that timed out, and a 529 is an overloaded host.
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
        504: .timeout,
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
    fileprivate static let contextLengthExceeded: Self = "context_length_exceeded"
    fileprivate static let rateLimitExceeded: Self = "rate_limit_exceeded"
    fileprivate static let contentPolicyViolation: Self = "content_policy_violation"
    fileprivate static let refusal: Self = "refusal"
    fileprivate static let timeout: Self = "timeout"
}

extension OpenRouterFailure {
    /// What a failure becomes: the `LanguageModelError` case of the same name, or an `OpenRouterError`.
    private enum Kind {
        case contextSizeExceeded
        case rateLimited
        case guardrailViolation
        case refusal
        case timeout
        case unsupportedImage
        case openRouterError
    }
}
