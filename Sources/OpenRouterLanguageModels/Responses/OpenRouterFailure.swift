import Foundation
import FoundationModels
import LanguageModels

/// A failure OpenRouter reported, before it becomes the error a session throws.
///
/// Failures Foundation Models has a case for throw `LanguageModelError`, so apps handle them the same way for every
/// model. The rest throw `OpenRouterError`.
struct OpenRouterFailure: Sendable {
    /// The HTTP status, or the code an error in the stream carries.
    let status: Int?
    let body: OpenRouterErrorBody?
    /// How long OpenRouter asks to wait, from the `Retry-After` header.
    let retryAfter: Duration?

    /// The error to throw.
    ///
    /// - Parameter contextSize: The model's context size, for an oversized prompt.
    func error(contextSize: Int?) -> any Error {
        let message = body?.bestMessage ?? status.map { HTTPURLResponse.localizedString(forStatusCode: $0) } ?? "The response wasn't valid."
        let metadata = self.metadata
        switch body?.errorType {
        case "context_length_exceeded", "token_limit_exceeded":
            let sizes = Self.sizes(in: message)
            return LanguageModelError.contextSizeExceeded(
                .init(
                    contextSize: sizes.limit ?? contextSize ?? 0,
                    tokenCount: sizes.requested ?? 0,
                    debugDescription: message,
                    metadata: metadata
                )
            )
        case "rate_limit_exceeded":
            return rateLimited(message, metadata)
        case "content_policy_violation":
            return LanguageModelError.guardrailViolation(.init(debugDescription: message, metadata: metadata))
        case "refusal":
            return LanguageModelError.refusal(.init(explanation: message, debugDescription: message, metadata: metadata))
        case "timeout":
            return LanguageModelError.timeout(.init(debugDescription: message, metadata: metadata))
        default:
            break
        }
        switch status {
        case 429?:
            return rateLimited(message, metadata)
        case 408?, 524?:
            return LanguageModelError.timeout(.init(debugDescription: message, metadata: metadata))
        case 403? where isModeration:
            return LanguageModelError.guardrailViolation(.init(debugDescription: message, metadata: metadata))
        default:
            return OpenRouterError(
                status: status,
                message: message,
                errorType: body?.errorType,
                providerName: body?.providerName,
                retryAfter: retryAfter
            )
        }
    }

    private func rateLimited(_ message: String, _ metadata: [String: any Sendable]) -> LanguageModelError {
        let resetDate = retryAfter.map { Date.now.addingTimeInterval(TimeInterval($0.components.seconds)) }
        return .rateLimited(.init(resetDate: resetDate, debugDescription: message, metadata: metadata))
    }

    /// Whether a 403 comes from OpenRouter's moderation or a guardrail, which name what they flagged, rather than from
    /// the key's permissions.
    private var isModeration: Bool {
        ["reasons", "flagged_input", "patterns"].contains { body?.metadata?[$0] != nil }
    }

    private var metadata: [String: any Sendable] {
        var metadata: [String: any Sendable] = [:]
        metadata["status"] = status
        metadata["errorType"] = body?.errorType
        metadata["providerName"] = body?.providerName
        return metadata
    }

    /// The context limit and the requested size in a message such as "maximum context length is 200000 tokens.
    /// However, you requested about 250000 tokens".
    private static func sizes(in message: String) -> (limit: Int?, requested: Int?) {
        let limit = message.firstMatch(of: /maximum context length is (\d+)/).flatMap { Int($0.1) }
        let requested = message.firstMatch(of: /requested (?:about )?(\d+)/).flatMap { Int($0.1) }
        return (limit, requested)
    }
}

extension Duration {
    /// The delay in a `Retry-After` header: a number of seconds, or an HTTP date.
    init?(retryAfter header: String?, now: Date = .now) {
        guard let header = header?.trimmingCharacters(in: .whitespaces), !header.isEmpty else { return nil }
        if let seconds = Double(header), seconds >= 0 {
            self = .milliseconds(Int64(seconds * 1_000))
            return
        }
        let strategy = Date.ParseStrategy(
            format:
                "\(weekday: .abbreviated), \(day: .twoDigits) \(month: .abbreviated) \(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) GMT",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: .gmt
        )
        guard let date = try? Date(header, strategy: strategy) else { return nil }
        self = .milliseconds(Int64(max(date.timeIntervalSince(now), 0) * 1_000))
    }
}
