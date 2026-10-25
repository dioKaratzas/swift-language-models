import FoundationModels

/// What the log says about an error a request throws: its type, and the HTTP status, error code and host it came
/// from, so the log shows how a failure was mapped.
struct LoggedError: Equatable {
    /// The error's type, and its case for a `LanguageModelError`, such as `LanguageModelError.rateLimited`.
    let kind: String
    let status: Int?
    let code: String?
    let host: String?
    /// What went wrong, which may quote the request, so the log keeps it private.
    let message: String

    /// Where the error came from, such as `HTTP 429, rate_limit_exceeded, host Vendor`, with only the parts known.
    var origin: String {
        [status.map { "HTTP \($0)" }, code, host.map { "host \($0)" }].compactMap(\.self).joined(separator: ", ")
    }
}

extension LoggedError {
    /// The parts of an error: an `OpenRouterError`'s own, a `LanguageModelError`'s from its metadata, and only the type
    /// and description of any other error.
    init(_ error: any Error) {
        switch error {
        case let error as OpenRouterError:
            self.init(
                kind: "OpenRouterError", status: error.status, code: error.code.rawValue, host: error.providerName?.rawValue,
                message: error.message)
        case let error as LanguageModelError:
            let (name, message, metadata) = error.parts
            self.init(
                kind: "LanguageModelError.\(name)",
                status: metadata[OpenRouterMetadataKey.status] as? Int,
                code: metadata[OpenRouterMetadataKey.errorCode] as? String,
                host: metadata[OpenRouterMetadataKey.provider] as? String,
                message: message
            )
        default:
            self.init(kind: String(reflecting: type(of: error)), status: nil, code: nil, host: nil, message: String(describing: error))
        }
    }
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
