import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: errors")
struct ExecutorErrorTests {
    @Test func `a rate limit throws rateLimited with the reset date from Retry-After`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":429,"message":"Rate limit exceeded"}}"#, status: 429, headers: ["Retry-After": "30"]))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .rateLimited(let info) = error else {
            Issue.record("Expected a rate limit, got \(error)")
            return
        }
        let wait = try #require(info.resetDate).timeIntervalSinceNow
        #expect((25...31).contains(wait))
    }

    @Test func `a Retry-After date sets the rate limit's reset date`() async throws {
        let resetDate = Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 + 120).rounded(.down))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        let header = formatter.string(from: resetDate)
        let stub = HTTPStub(
            .json(#"{"error":{"code":429,"message":"Rate limit exceeded"}}"#, status: 429, headers: ["Retry-After": header]))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .rateLimited(let info) = error else {
            Issue.record("Expected a rate limit, got \(error)")
            return
        }
        #expect(abs(try #require(info.resetDate).timeIntervalSince(resetDate)) < 2)
    }

    @Test func `without Retry-After, a rate limit takes its reset date from X-RateLimit-Reset`() async throws {
        let resetDate = Date.now.addingTimeInterval(60)
        let milliseconds = String(Int(resetDate.timeIntervalSince1970 * 1_000))
        let stub = HTTPStub(
            .json(#"{"error":{"code":429,"message":"Rate limit exceeded"}}"#, status: 429, headers: ["X-RateLimit-Reset": milliseconds]))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .rateLimited(let info) = error else {
            Issue.record("Expected a rate limit, got \(error)")
            return
        }
        #expect(abs(try #require(info.resetDate).timeIntervalSince(resetDate)) < 2)
    }

    @Test func `an OpenRouter error carries the Retry-After wait`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":500,"message":"Internal error"}}"#, status: 500, headers: ["Retry-After": "15"]))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.retryAfter == .seconds(15))
    }

    @Test func `a rejected key throws an OpenRouter error with the status and message`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":401,"message":"No auth credentials found"}}"#, status: 401))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error == OpenRouterError(status: 401, message: "No auth credentials found", code: .authentication))
    }

    @Test(arguments: [
        (400, OpenRouterError.Code.invalidRequest),
        (401, .authentication),
        (402, .paymentRequired),
        (403, .permissionDenied),
        (404, .notFound),
        (413, .payloadTooLarge),
        (422, .unprocessable),
        (500, .server),
    ])
    func `an error without an error type takes its code from the status`(status: Int, code: OpenRouterError.Code) async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":\#(status),"message":"Failed"}}"#, status: status))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.code == code)
        #expect(error.status == status)
    }

    @Test func `an error type wins over the status`() async throws {
        let body = #"{"error":{"code":400,"message":"Image too large","metadata":{"error_type":"image_too_large"}}}"#
        let stub = HTTPStub(.json(body, status: 400))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.code == .imageTooLarge)
    }

    @Test func `a 400 for a prompt longer than the context throws contextSizeExceeded with both sizes`() async throws {
        let message =
            "This endpoint's maximum context length is 8192 tokens. However, you requested about 9000 tokens "
            + "(8000 of text input, 1000 in the output). Please reduce the length of either one."
        let stub = HTTPStub(.json(JSONValue.object(["error": ["code": 400, "message": .string(message)]]).text, status: 400))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .contextSizeExceeded(let info) = error else {
            Issue.record("Expected an oversized context, got \(error)")
            return
        }
        #expect(info.contextSize == 8_192)
        #expect(info.tokenCount == 9_000)
    }

    @Test func `a 400 in the stream that mentions the context throws contextSizeExceeded with the model's context size`() async throws {
        let streamError: JSONValue = ["error": ["code": 400, "message": "Input exceeds the context window."]]
        let stub = HTTPStub(events(text("Hi"), streamError))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .contextSizeExceeded(let info) = error else {
            Issue.record("Expected an oversized context, got \(error)")
            return
        }
        #expect(info.contextSize == 200_000)
    }

    @Test func `a 400 about a context setting stays an invalid request`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":400,"message":"Invalid value for context_management."}}"#, status: 400))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.code == .invalidRequest)
    }

    @Test func `an OpenRouter error carries its code and host`() async throws {
        let body =
            #"{"error":{"code":402,"message":"Insufficient credits","metadata":{"error_type":"payment_required","provider_name":"Anthropic"}}}"#
        let stub = HTTPStub(.json(body, status: 402))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.code == .paymentRequired)
        #expect(error.providerName == "Anthropic")
        #expect(error.status == 402)
    }

    @Test func `a host's own message replaces OpenRouter's generic one`() async throws {
        let body =
            #"{"error":{"code":400,"message":"Provider returned error","metadata":{"provider_name":"Anthropic","raw":"{\"error\":{\"message\":\"messages: text content blocks must be non-empty\"}}"}}}"#
        let stub = HTTPStub(.json(body, status: 400))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.message == "messages: text content blocks must be non-empty")
        #expect(error.errorDescription == "[Anthropic] messages: text content blocks must be non-empty")
    }

    @Test func `an error in the stream throws the matching error`() async throws {
        let message = "This endpoint's maximum context length is 200000 tokens. However, you requested about 250000 tokens."
        let streamError: JSONValue = [
            "error": ["code": 400, "message": .string(message), "metadata": ["error_type": "context_length_exceeded"]]
        ]
        let stub = HTTPStub(events(text("Hi"), streamError))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .contextSizeExceeded(let info) = error else {
            Issue.record("Expected an oversized context, got \(error)")
            return
        }
        #expect(info.contextSize == 200_000)
        #expect(info.tokenCount == 250_000)
    }

    @Test func `an error in the stream with a text code throws that code and the chunk's host, without a status`() async throws {
        let message = "The server had an error while processing your request."
        let streamError: JSONValue = ["error": ["code": "server_error", "message": .string(message)], "provider": "openai"]
        let stub = HTTPStub(events(text("Hi"), streamError))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error == OpenRouterError(message: message, code: "server_error", providerName: "openai"))
    }

    @Test func `an error in the stream takes the host its metadata names before the chunk's`() async throws {
        let streamError: JSONValue = [
            "error": ["code": 502, "message": "Provider returned error", "metadata": ["provider_name": "Anthropic"]],
            "provider": "openai",
        ]
        let stub = HTTPStub(events(text("Hi"), streamError))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.status == 502)
        #expect(error.code == .providerUnavailable)
        #expect(error.providerName == "Anthropic")
    }

    @Test func `an error in the stream without a code is a server failure of the host an earlier chunk named`() async throws {
        let stub = HTTPStub(events(text("Hi"), ["error": ["message": "Generation failed."]]))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error == OpenRouterError(message: "Generation failed.", code: .server, providerName: "Vendor"))
    }

    @Test func `a rate limit in the stream keeps the chunk's host in its metadata`() async throws {
        let streamError: JSONValue = [
            "error": ["code": 429, "message": "Rate limit exceeded", "metadata": ["error_type": "rate_limit_exceeded"]],
            "provider": "openai",
        ]
        let stub = HTTPStub(events(text("Hi"), streamError))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .rateLimited(let info) = error else {
            Issue.record("Expected a rate limit, got \(error)")
            return
        }
        #expect(info.metadata["providerName"] as? String == "openai")
        #expect(info.metadata["status"] as? Int == 429)
    }

    @Test func `a refusal throws refusal with the model's explanation`() async throws {
        let stub = HTTPStub(events(chunk(["refusal": "I can't help with that."]), done()))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .refusal = error else {
            Issue.record("Expected a refusal, got \(error)")
            return
        }
    }

    @Test func `a content filter throws a guardrail violation`() async throws {
        let stub = HTTPStub(events(text("Partial"), done("content_filter")))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .guardrailViolation = error else {
            Issue.record("Expected a guardrail violation, got \(error)")
            return
        }
    }

    @Test(arguments: [408, 524])
    func `a timeout status throws timeout`(status: Int) async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":\#(status),"message":"Request timed out"}}"#, status: status))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .timeout = error else {
            Issue.record("Expected a timeout, got \(error)")
            return
        }
    }
}
