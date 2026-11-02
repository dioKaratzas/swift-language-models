import FoundationModels

/// What the log says about an error a request throws: its type, and the HTTP status, error code and host it came
/// from, so the log shows how a failure was mapped.
package struct LoggedError: Equatable {
    /// The error's type, and its case for a `LanguageModelError`, such as `LanguageModelError.rateLimited`.
    package let kind: String
    package let status: Int?
    package let code: String?
    package let host: String?
    /// What went wrong, which may quote the request, so the log keeps it private.
    package let message: String

    package init(kind: String, status: Int?, code: String?, host: String?, message: String) {
        self.kind = kind
        self.status = status
        self.code = code
        self.host = host
        self.message = message
    }

    /// Where the error came from, such as `HTTP 429, rate_limit_exceeded, host Vendor`, with only the parts known.
    package var origin: String {
        [status.map { "HTTP \($0)" }, code, host.map { "host \($0)" }].compactMap(\.self).joined(separator: ", ")
    }
}

extension LoggedError {
    /// The parts of an error: a provider error's own, a `LanguageModelError`'s from its metadata, and only the type and
    /// description of any other error.
    package init(_ error: any Error) {
        switch error {
        case let error as any LoggableError:
            self = error.loggedError
        case let error as LanguageModelError:
            let (name, message, metadata) = error.parts
            self.init(
                kind: "LanguageModelError.\(name)",
                status: metadata[LanguageModelMetadataKey.status] as? Int,
                code: metadata[LanguageModelMetadataKey.errorCode] as? String,
                host: metadata[LanguageModelMetadataKey.provider] as? String,
                message: message
            )
        default:
            self.init(kind: String(reflecting: type(of: error)), status: nil, code: nil, host: nil, message: String(describing: error))
        }
    }
}

/// A provider's own error, which says what the log shows about it.
package protocol LoggableError: Error {
    /// The error's type, HTTP status, code, host and message.
    var loggedError: LoggedError { get }
}

extension LanguageModelError {
    /// The case's name, and its description and metadata.
    fileprivate var parts: (name: String, message: String, metadata: [String: any Sendable]) {
        switch self {
        case .contextSizeExceeded(let context): ("contextSizeExceeded", context.debugDescription, context.metadata)
        case .rateLimited(let context): ("rateLimited", context.debugDescription, context.metadata)
        case .guardrailViolation(let context): ("guardrailViolation", context.debugDescription, context.metadata)
        case .refusal(let context): ("refusal", context.debugDescription, context.metadata)
        case .unsupportedCapability(let context): ("unsupportedCapability", context.debugDescription, context.metadata)
        case .unsupportedTranscriptContent(let context): ("unsupportedTranscriptContent", context.debugDescription, context.metadata)
        case .unsupportedGenerationGuide(let context): ("unsupportedGenerationGuide", context.debugDescription, context.metadata)
        case .unsupportedLanguageOrLocale(let context): ("unsupportedLanguageOrLocale", context.debugDescription, context.metadata)
        case .timeout(let context): ("timeout", context.debugDescription, context.metadata)
        @unknown default: ("unknown", String(describing: self), [:])
        }
    }
}
