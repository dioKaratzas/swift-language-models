import Foundation
import FoundationModels
import LanguageModels
import Testing

@testable import OpenRouterLanguageModels

/// A failed response: its status, the `metadata` of its error, the message, and the error it should become, by the
/// kind that the log names.
private let failures: [(status: Int, metadata: JSONValue?, message: String, kind: String)] = [
    (400, ["error_type": "context_length_exceeded"], "Too long.", "LanguageModelError.contextSizeExceeded"),
    (400, ["error_type": "token_limit_exceeded"], "Too long.", "LanguageModelError.contextSizeExceeded"),
    (400, nil, "This model's maximum context length is 200000 tokens.", "LanguageModelError.contextSizeExceeded"),
    (400, nil, "Bad request.", "OpenRouterError"),
    (429, nil, "Slow down.", "LanguageModelError.rateLimited"),
    (400, ["error_type": "rate_limit_exceeded"], "Slow down.", "LanguageModelError.rateLimited"),
    (402, ["limit_source": "openrouter_in_flight_budget"], "Too many at once.", "LanguageModelError.rateLimited"),
    (402, nil, "No credits.", "OpenRouterError"),
    (403, ["flagged_input": "…"], "Flagged.", "LanguageModelError.guardrailViolation"),
    (403, nil, "Not allowed.", "OpenRouterError"),
    (400, ["error_type": "content_policy_violation"], "Flagged.", "LanguageModelError.guardrailViolation"),
    (400, ["error_type": "refusal"], "I can't help with that.", "LanguageModelError.refusal"),
    (408, nil, "Timed out.", "LanguageModelError.timeout"),
    (524, nil, "Timed out.", "LanguageModelError.timeout"),
    (500, ["error_type": "timeout"], "Timed out.", "LanguageModelError.timeout"),
    (500, nil, "Failed.", "OpenRouterError"),
    (503, nil, "No host.", "OpenRouterError"),
    // An error type that names a case wins over the body's flags, which win over any other error type.
    (402, ["error_type": "refusal", "limit_source": "openrouter_in_flight_budget"], "No.", "LanguageModelError.refusal"),
    (403, ["error_type": "permission_denied", "reasons": ["violence"]], "Flagged.", "LanguageModelError.guardrailViolation"),
]

@Suite("OpenRouter failure")
struct OpenRouterFailureTests {
    @Test(arguments: failures)
    func `a failure becomes the language model error for its code, or an OpenRouter error`(
        failure: (status: Int, metadata: JSONValue?, message: String, kind: String)
    ) {
        let body = OpenRouterErrorResponse(message: failure.message, metadata: failure.metadata)

        let error = OpenRouterFailure(status: failure.status, body: body, retryAfter: nil).error(contextSize: nil)

        #expect(LoggedError(error).kind == failure.kind)
    }

    @Test func `an oversized prompt's error keeps its status and code in its metadata`() throws {
        let body = OpenRouterErrorResponse(message: "This model's maximum context length is 16384 tokens.", metadata: nil)

        let error = try #require(OpenRouterFailure(status: 400, body: body, retryAfter: nil).error(contextSize: nil) as? LanguageModelError)

        guard case .contextSizeExceeded(let info) = error else {
            Issue.record("Expected the context size to be exceeded, got \(error)")
            return
        }
        #expect(info.metadata[OpenRouterMetadataKey.status] as? Int == 400)
        #expect(info.metadata[OpenRouterMetadataKey.errorCode] as? String == "context_length_exceeded")
    }

    @Test func `an error in a stream without a status or code is a host failing while it generates`() throws {
        let body = OpenRouterErrorResponse(code: "server_error", message: "Overloaded.", metadata: nil)

        let error = try #require(OpenRouterFailure(streamError: body, provider: "Vendor").error(contextSize: nil) as? OpenRouterError)

        #expect(error == OpenRouterError(message: "Overloaded.", code: "server_error", providerName: "Vendor"))
    }
}
