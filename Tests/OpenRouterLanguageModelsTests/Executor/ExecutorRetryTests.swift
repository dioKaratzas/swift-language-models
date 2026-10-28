import Foundation
import FoundationModels
import LanguageModels
import LanguageModelsTestSupport
import Testing

@testable import OpenRouterLanguageModels

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
