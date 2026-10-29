import Foundation
import FoundationModels
import OpenRouterLanguageModels

extension Terminal {
    /// Prints what went wrong, in words for the person running the showcase.
    ///
    /// Foundation Models' `LanguageModelError` covers what every model can run into, such as rate limits, and
    /// `OpenRouterError` the rest, such as a rejected key.
    static func report(_ error: any Error) {
        printError(message(for: error))
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case LanguageModelError.rateLimited(let limit):
            "OpenRouter is limiting requests. Try again \(limit.resetDate.map { "after \($0.formatted(date: .omitted, time: .standard))" } ?? "soon")."
        case LanguageModelError.contextSizeExceeded(let exceeded):
            "The conversation needs \(exceeded.tokenCount.formatted()) tokens, and the model takes \(exceeded.contextSize.formatted())."
        case LanguageModelError.guardrailViolation, LanguageModelError.refusal:
            "The model or its host declined to answer."
        case LanguageModelError.unsupportedCapability(let unsupported):
            "The model can't do this: \(unsupported.debugDescription)"
        case LanguageModelError.unsupportedTranscriptContent(let unsupported):
            "The model can't take this: \(unsupported.debugDescription)"
        case LanguageModelError.timeout:
            "The request timed out."
        case let error as OpenRouterError where error.code == .authentication:
            "OpenRouter rejected the API key. Check OPENROUTER_API_KEY."
        case let error as OpenRouterError where error.code == .paymentRequired:
            "The OpenRouter account is out of credits. Add some at https://openrouter.ai/settings/credits."
        case let error as OpenRouterError where error.code == .connectionFailed:
            "OpenRouter can't be reached. Check the network connection."
        default:
            error.localizedDescription
        }
    }
}

/// A command run the wrong way, such as without an argument it needs.
struct UsageError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
        errorDescription = message
    }
}
