import Foundation
import LanguageModels
import LanguageModelsTestSupport
import Testing

@Suite("Provider HTTP")
struct ProviderHTTPTests {
    @Test func `a redirect to another host isn't followed and comes back as a failure`() async throws {
        let other = HTTPStub(.json("{}"))
        let stub = HTTPStub(.redirect(to: other.baseURL.appending(path: "v1/chat").absoluteString))

        let failure = try await #require(throws: ProviderHTTP.Failure.self) {
            try await http(stub).data(request(stub))
        }

        #expect(failure.status == 307)
        #expect(other.requests.isEmpty)
    }

    @Test func `a redirect to the same host is followed with the request's authorization`() async throws {
        let stub = HTTPStub(.redirect(to: "/v2/chat"), .json("{}"))

        _ = try await http(stub).data(request(stub))

        let followed = try #require(stub.requests.last)
        #expect(followed.request.url?.path() == "/v2/chat")
        #expect(followed.request.value(forHTTPHeaderField: HTTPHeader.authorization) == "Bearer key")
    }

    @Test(arguments: [(nil, Duration.milliseconds(10)), ("1", .seconds(1))])
    func `the one retry waits the longer of the retry delay and a short Retry-After`(header: String?, wait: Duration) async throws {
        let stub = HTTPStub(.json("{}", status: 503, headers: header.map { [HTTPHeader.retryAfter: $0] } ?? [:]), .json("{}"))
        var waited: Duration?

        _ = try await http(stub, retryDelay: .milliseconds(10)).data(request(stub)) { _, wait in waited = wait }

        #expect(waited == wait)
        #expect(stub.requests.count == 2)
    }

    @Test func `a Retry-After past the longest wait fails at once, without the retry`() async throws {
        let stub = HTTPStub(.json("{}", status: 503, headers: [HTTPHeader.retryAfter: "60"]), .json("{}"))

        let failure = try await #require(throws: ProviderHTTP.Failure.self) {
            try await http(stub).data(request(stub))
        }

        #expect(failure.retryAfter == .seconds(60))
        #expect(stub.requests.count == 1)
    }

    @Test func `cancelling during the wait before the retry throws a cancellation and sends nothing more`() async throws {
        let stub = HTTPStub(.json("{}", status: 503), .json("{}"))
        let http = http(stub, retryDelay: .seconds(60))
        let request = request(stub)

        let task = Task { try await http.data(request) }
        for await _ in stub.sentResponses { break }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(stub.requests.count == 1)
    }

    private func http(_ stub: HTTPStub, retryDelay: Duration = .zero) -> ProviderHTTP {
        ProviderHTTP(session: stub.session, retryStatuses: [503], retryDelay: retryDelay)
    }

    private func request(_ stub: HTTPStub) -> URLRequest {
        ProviderHTTP.request(url: stub.baseURL.appending(path: "v1/chat"), authHeaders: [HTTPHeader.authorization: "Bearer key"])
    }
}
