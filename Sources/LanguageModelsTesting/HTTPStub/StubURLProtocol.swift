import Foundation
import Synchronization

/// Serves the responses an ``HTTPStub`` registered for a request's host, and records each request.
final class StubURLProtocol: URLProtocol {
    private struct Host {
        var responses: [StubResponse]
        var requests: [RecordedRequest] = []
    }

    private static let hosts = Mutex<[String: Host]>([:])

    static func register(_ host: String, responses: [StubResponse]) {
        hosts.withLock { $0[host] = Host(responses: responses) }
    }

    static func unregister(_ host: String) {
        _ = hosts.withLock { $0.removeValue(forKey: host) }
    }

    static func requests(for host: String) -> [RecordedRequest] {
        hosts.withLock { $0[host]?.requests ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client else { return }
        switch nextResponse() {
        case .success(let (response, url)):
            guard
                let httpResponse = HTTPURLResponse(
                    url: url,
                    statusCode: response.status,
                    httpVersion: "HTTP/1.1",
                    headerFields: response.headers
                )
            else {
                client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            for chunk in response.chunks {
                client.urlProtocol(self, didLoad: chunk)
            }
            client.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private func nextResponse() -> Result<(StubResponse, URL), URLError> {
        guard let url = request.url, let host = url.host() else { return .failure(URLError(.badURL)) }
        let recorded = RecordedRequest(request: request, body: Self.body(of: request))
        return Self.hosts.withLock { hosts in
            guard var entry = hosts[host] else { return .failure(URLError(.cannotFindHost)) }
            entry.requests.append(recorded)
            let response = entry.responses.isEmpty ? nil : entry.responses.removeFirst()
            hosts[host] = entry
            return response.map { .success(($0, url)) } ?? .failure(URLError(.resourceUnavailable))
        }
    }

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            // `InputStream.read` writes through a pointer into `buffer`, which outlives the call.
            let count = unsafe stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            body.append(contentsOf: buffer[..<count])
        }
        return body
    }
}
