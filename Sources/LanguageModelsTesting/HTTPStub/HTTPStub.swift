package import Foundation

/// A fake HTTP host for one test.
///
/// Requests sent through ``session`` to ``baseURL`` get the stub's responses, in order, and the stub records each one.
/// Every stub has its own random host, so tests with different stubs run in parallel. A request after the last
/// response fails with `URLError.resourceUnavailable`.
package final class HTTPStub: Sendable {
    /// The stub's base URL, such as `https://<random>.test`.
    package let baseURL: URL

    /// A session that sends its requests to the stub.
    package let session: URLSession

    private let host: String

    /// Creates a stub that serves the given responses, in order.
    ///
    /// - Parameter responses: The responses, one for each request.
    package init(_ responses: StubResponse...) {
        host = "\(UUID().uuidString.lowercased()).test"
        baseURL = URL(string: "https://\(host)")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)
        StubURLProtocol.register(host, responses: responses)
    }

    deinit {
        session.invalidateAndCancel()
        StubURLProtocol.unregister(host)
    }

    /// The requests the stub received, oldest first.
    package var requests: [RecordedRequest] {
        StubURLProtocol.requests(for: host)
    }
}
