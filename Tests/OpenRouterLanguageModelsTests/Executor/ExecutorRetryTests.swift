import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

/// OpenRouter's requests retry a failed connection and any status from 500 up, with the stubs' models waiting for
/// nothing between retries.
@Suite("Executor: retries")
struct ExecutorRetryTests {
    private static let retriedStatuses = [500, 501, 502, 503, 504, 524, 529, 599, 600]

    @Test(arguments: retriedStatuses)
    func `a server failure is retried twice, until it succeeds`(status: Int) async throws {
        let rejection = failure(status)
        let stub = HTTPStub(rejection, rejection, events(text("Hi"), done()))

        #expect(try await respond(stub) == "Hi")
        #expect(stub.requests.count == 3)
    }

    @Test(arguments: [400, 408, 409, 429])
    func `a non-server failure isn't retried`(status: Int) async throws {
        let stub = HTTPStub(failure(status), events(text("Hi"), done()))

        await #expect(throws: (any Error).self) { try await respond(stub) }
        #expect(stub.requests.count == 1)
    }

    @Test(arguments: [URLError.Code.timedOut, .cannotConnectToHost, .networkConnectionLost])
    func `a failed connection is retried until it succeeds`(code: URLError.Code) async throws {
        let failure = StubResponse.failure(URLError(code))
        let stub = HTTPStub(failure, failure, events(text("Hi"), done()))

        #expect(try await respond(stub) == "Hi")
        #expect(stub.requests.count == 3)
    }

    @Test func `x-should-retry true retries a status that isn't retried otherwise`() async throws {
        let stub = HTTPStub(failure(400, headers: ["x-should-retry": "true"]), events(text("Hi"), done()))

        #expect(try await respond(stub) == "Hi")
        #expect(stub.requests.count == 2)
    }

    @Test func `x-should-retry false fails at once`() async throws {
        let stub = HTTPStub(failure(503, headers: ["x-should-retry": "false"]), events(text("Hi"), done()))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.status == 503)
        #expect(stub.requests.count == 1)
    }

    @Test func `a rate limit that asks to wait more than 2 minutes fails at once, with the wait`() async throws {
        let stub = HTTPStub(failure(429, headers: ["Retry-After": "300", "x-should-retry": "true"]), events(text("Hi"), done()))

        let error = try await #require(throws: LanguageModelError.self) { try await respond(stub) }

        guard case .rateLimited(let context) = error, let reset = context.resetDate else {
            Issue.record("Threw \(error)")
            return
        }
        #expect(reset.timeIntervalSinceNow > 290)
        #expect(stub.requests.count == 1)
    }

    @Test(arguments: [
        (HTTPHeaderName.retryAfter, "90", Duration.seconds(90)),
        (.retryAfter, "120", .seconds(120)),
        (.retryAfterMilliseconds, "1500", .milliseconds(1_500)),
    ])
    func `a retry waits as long as OpenRouter asks, up to 2 minutes`(header: HTTPHeaderName, value: String, wait: Duration) throws {
        let url = try #require(URL(string: "https://openrouter.ai/api/v1/chat/completions"))
        let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: [header.rawValue: value])

        #expect(RequestRetries.standard.policy(statuses: API.retriesStatus).retry(1, status: 503, response: response)?.wait == wait)
    }

    @Test func `the configuration's retry limit caps the retries`() async throws {
        let rejection = failure(503)
        let stub = HTTPStub(rejection, rejection, events(text("Hi"), done()))
        var limited = model(stub)
        limited.configuration.retries.limit = 1

        let error = try await #require(throws: OpenRouterError.self) {
            try await LanguageModelSession(model: limited).respond(to: "Hi")
        }

        #expect(error.status == 503)
        #expect(stub.requests.count == 2)
    }

    @Test func `disabled retries send a failed request once`() async throws {
        let stub = HTTPStub(failure(503), events(text("Hi"), done()))
        var model = model(stub)
        model.configuration.retries = .disabled

        await #expect(throws: OpenRouterError.self) { try await LanguageModelSession(model: model).respond(to: "Hi") }

        #expect(stub.requests.count == 1)
    }

    @Test func `a wait past the configuration's longest server wait fails at once, with the wait`() async throws {
        let stub = HTTPStub(failure(503, headers: ["Retry-After": "10"]), events(text("Hi"), done()))
        var model = model(stub)
        model.configuration.retries.longestServerWait = .seconds(5)

        let error = try await #require(throws: OpenRouterError.self) {
            try await LanguageModelSession(model: model).respond(to: "Hi")
        }

        #expect(error.retryAfter == .seconds(10))
        #expect(stub.requests.count == 1)
    }

    @Test func `a model's default configuration retries twice, without an idle timeout`() {
        let configuration = OpenRouterLanguageModel(.anthropicClaudeHaiku5_5, auth: .apiKey { "" }).configuration

        #expect(configuration.retries == .standard)
        #expect(configuration.idleTimeout == nil)
        #expect(configuration.images == .standard)
        #expect(configuration.infoCacheLifetime == .seconds(60))
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

        let error = try await #require(throws: URLError.self) { try await respond(stub) }

        #expect(error.code == .networkConnectionLost)
        #expect(stub.requests.count == 1)
    }

    private func failure(_ status: Int, headers: [String: String] = [:]) -> StubResponse {
        .json(#"{"error":{"code":\#(status),"message":"Unavailable"}}"#, status: status, headers: headers)
    }
}
