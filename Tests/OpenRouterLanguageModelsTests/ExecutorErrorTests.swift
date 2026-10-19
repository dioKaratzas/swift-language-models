import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTesting
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

@Suite("Executor: retries")
struct ExecutorRetryTests {
    private static let gatewayStatuses = [502, 503, 504, 529]

    @Test(arguments: gatewayStatuses)
    func `a gateway failure is retried once`(status: Int) async throws {
        let stub = HTTPStub(failure(status), events(text("Hi"), done()))

        #expect(try await respond(stub) == "Hi")
        #expect(stub.requests.count == 2)
    }

    @Test(arguments: gatewayStatuses)
    func `a second gateway failure isn't retried`(status: Int) async throws {
        let stub = HTTPStub(failure(status), failure(status), events(text("Hi"), done()))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.status == status)
        #expect(stub.requests.count == 2)
    }

    @Test(arguments: [400, 500])
    func `a failure that isn't the gateway's isn't retried`(status: Int) async throws {
        let stub = HTTPStub(failure(status), events(text("Hi"), done()))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.status == status)
        #expect(stub.requests.count == 1)
    }

    @Test func `a gateway status in the stream isn't retried, since the answer already started`() async throws {
        let streamError: JSONValue = ["error": ["code": 503, "message": "Provider overloaded"]]
        let stub = HTTPStub(events(text("Hi"), streamError), events(text("Hello"), done()))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.status == 503)
        #expect(stub.requests.count == 1)
    }

    @Test func `a dropped stream isn't retried`() async throws {
        let stub = HTTPStub(
            unfinishedEvents(text("Hel")).droppingConnection(with: URLError(.networkConnectionLost)),
            events(text("Hello"), done())
        )

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.code == .connectionFailed)
        #expect(stub.requests.count == 1)
    }

    private func failure(_ status: Int) -> StubResponse {
        .json(#"{"error":{"code":\#(status),"message":"Unavailable"}}"#, status: status)
    }
}

@Suite("Executor: connection failures")
struct ExecutorConnectionTests {
    /// What a failed connection surfaces as.
    enum Outcome: Sendable {
        case connectionFailed
        case timeout
        case cancellation

        func matches(_ error: (any Error)?) -> Bool {
            switch self {
            case .connectionFailed:
                guard let error = error as? OpenRouterError else { return false }
                return error.code == .connectionFailed && error.status == nil
            case .timeout:
                guard case .timeout? = error as? LanguageModelError else { return false }
                return true
            case .cancellation:
                return error is CancellationError
            }
        }
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, Outcome.connectionFailed),
        (.cannotFindHost, .connectionFailed),
        (.cannotConnectToHost, .connectionFailed),
        (.secureConnectionFailed, .connectionFailed),
        (.timedOut, .timeout),
        (.cancelled, .cancellation),
    ])
    func `a connection that fails before a response throws the matching error, without a retry`(code: URLError.Code, outcome: Outcome)
        async throws
    {
        let stub = HTTPStub(.failure(URLError(code)), events(text("Hi"), done()))

        let error = await #expect(throws: (any Error).self) { try await respond(stub) }

        #expect(outcome.matches(error), "Got \(String(describing: error))")
        #expect(stub.requests.count == 1)
    }

    @Test(arguments: [(URLError.Code.networkConnectionLost, Outcome.connectionFailed), (.timedOut, .timeout)])
    func `a connection that drops mid-stream throws the matching error`(code: URLError.Code, outcome: Outcome) async throws {
        let stub = HTTPStub(unfinishedEvents(text("Hel"), text("lo")).droppingConnection(with: URLError(code)))

        let error = await #expect(throws: (any Error).self) { try await respond(stub) }

        #expect(outcome.matches(error), "Got \(String(describing: error))")
    }
}
