import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

@Suite("Executor: retries")
struct ExecutorRetryTests {
    private static let retriedStatuses = [408, 500, 502, 503, 504, 529]

    @Test(arguments: retriedStatuses)
    func `a timeout, server or gateway failure is retried once`(status: Int) async throws {
        let stub = HTTPStub(failure(status), events(text("Hi"), done()))

        #expect(try await respond(stub) == "Hi")
        #expect(stub.requests.count == 2)
    }

    // A second 408 or 504 throws the timeout, which `ExecutorErrorTests` covers.
    @Test(arguments: retriedStatuses.filter { $0 != 408 && $0 != 504 })
    func `a second failure isn't retried`(status: Int) async throws {
        let stub = HTTPStub(failure(status), failure(status), events(text("Hi"), done()))

        let error = try await #require(throws: OpenRouterError.self) { try await respond(stub) }

        #expect(error.status == status)
        #expect(stub.requests.count == 2)
    }

    @Test(arguments: [400, 501])
    func `a failure that isn't brief isn't retried`(status: Int) async throws {
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

        let error = try await #require(throws: URLError.self) { try await respond(stub) }

        #expect(error.code == .networkConnectionLost)
        #expect(stub.requests.count == 1)
    }

    private func failure(_ status: Int) -> StubResponse {
        .json(#"{"error":{"code":\#(status),"message":"Unavailable"}}"#, status: status)
    }
}
