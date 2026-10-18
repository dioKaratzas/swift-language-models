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

        let error = try await failure(of: stub)

        guard case .rateLimited(let info)? = error as? LanguageModelError else {
            Issue.record("Expected a rate limit, got \(error)")
            return
        }
        let wait = try #require(info.resetDate).timeIntervalSinceNow
        #expect((25...31).contains(wait))
    }

    @Test func `a rejected key throws an OpenRouter error with the status and message`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":401,"message":"No auth credentials found"}}"#, status: 401))

        let error = try await failure(of: stub)

        #expect(error as? OpenRouterError == OpenRouterError(status: 401, message: "No auth credentials found"))
    }

    @Test func `a host's own message replaces OpenRouter's generic one`() async throws {
        let body =
            #"{"error":{"code":400,"message":"Provider returned error","metadata":{"provider_name":"Anthropic","raw":"{\"error\":{\"message\":\"messages: text content blocks must be non-empty\"}}"}}}"#
        let stub = HTTPStub(.json(body, status: 400))

        let error = try await failure(of: stub)

        let openRouter = try #require(error as? OpenRouterError)
        #expect(openRouter.message == "messages: text content blocks must be non-empty")
        #expect(openRouter.errorDescription == "[Anthropic] messages: text content blocks must be non-empty")
    }

    @Test func `an error in the stream throws the matching error`() async throws {
        let message = "This endpoint's maximum context length is 200000 tokens. However, you requested about 250000 tokens."
        let streamError: JSONValue = [
            "error": ["code": 400, "message": .string(message), "metadata": ["error_type": "context_length_exceeded"]]
        ]
        let stub = HTTPStub(events(text("Hi"), streamError))

        let error = try await failure(of: stub)

        guard case .contextSizeExceeded(let info)? = error as? LanguageModelError else {
            Issue.record("Expected an oversized context, got \(error)")
            return
        }
        #expect(info.contextSize == 200_000)
        #expect(info.tokenCount == 250_000)
    }

    @Test func `a refusal throws refusal with the model's explanation`() async throws {
        let stub = HTTPStub(events(chunk(["refusal": "I can't help with that."]), done()))

        let error = try await failure(of: stub)

        guard case .refusal? = error as? LanguageModelError else {
            Issue.record("Expected a refusal, got \(error)")
            return
        }
    }

    @Test func `a content filter throws a guardrail violation`() async throws {
        let stub = HTTPStub(events(text("Partial"), done("content_filter")))

        let error = try await failure(of: stub)

        guard case .guardrailViolation? = error as? LanguageModelError else {
            Issue.record("Expected a guardrail violation, got \(error)")
            return
        }
    }

    @Test func `a gateway failure is retried once`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":503,"message":"No available provider"}}"#, status: 503), events(text("Hi"), done()))

        let response = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")

        #expect(response.content == "Hi")
        #expect(stub.requests.count == 2)
    }

    @Test func `a second gateway failure isn't retried`() async throws {
        let failure = StubResponse.json(#"{"error":{"code":502,"message":"Provider returned error"}}"#, status: 502)
        let stub = HTTPStub(failure, failure, events(text("Hi"), done()))

        let error = try await self.failure(of: stub)

        #expect((error as? OpenRouterError)?.status == 502)
        #expect(stub.requests.count == 2)
    }

    @Test func `a timeout throws timeout`() async throws {
        let stub = HTTPStub(.json(#"{"error":{"code":524,"message":"Request timed out"}}"#, status: 524))

        let error = try await failure(of: stub)

        guard case .timeout? = error as? LanguageModelError else {
            Issue.record("Expected a timeout, got \(error)")
            return
        }
    }

    private func failure(of stub: HTTPStub) async throws -> any Error {
        do {
            _ = try await LanguageModelSession(model: model(stub)).respond(to: "Hi")
        } catch {
            return error
        }
        throw NoError()
    }
}

private struct NoError: Error {}
