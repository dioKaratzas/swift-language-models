import Foundation
import Synchronization

/// Serves the responses an ``HTTPStub`` registered for a request's host, and records each request.
final class StubURLProtocol: URLProtocol {
    private struct Host {
        var responses: [StubResponse]
        var requests: [RecordedRequest] = []
        let sent: AsyncStream<Void>.Continuation
    }

    private static let hosts = Mutex<[String: Host]>([:])

    static func register(_ host: String, responses: [StubResponse], sent: AsyncStream<Void>.Continuation) {
        hosts.withLock { $0[host] = Host(responses: responses, sent: sent) }
    }

    static func unregister(_ host: String) {
        hosts.withLock { $0.removeValue(forKey: host) }?.sent.finish()
    }

    static func requests(for host: String) -> [RecordedRequest] {
        hosts.withLock { $0[host]?.requests ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client else { return }
        guard let url = request.url, let host = url.host() else {
            client.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (response, sent) = nextResponse(for: host)
        defer { sent?.yield() }
        switch response {
        case .success(let response):
            send(response, from: url, to: client)
        case .failure(let error):
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private func send(_ response: StubResponse, from url: URL, to client: any URLProtocolClient) {
        switch response.ending {
        case .failedBeforeResponse(let error):
            client.urlProtocol(self, didFailWithError: error)
        case .finished:
            guard sendHeadAndChunks(of: response, from: url, to: client) else { return }
            client.urlProtocolDidFinishLoading(self)
        case .droppedConnection(let error):
            guard sendHeadAndChunks(of: response, from: url, to: client) else { return }
            client.urlProtocol(self, didFailWithError: error)
        case .openConnection:
            sendHeadAndChunks(of: response, from: url, to: client)
        }
    }

    /// Sends the response's status, headers and chunks, or fails the request when they don't make a response.
    @discardableResult
    private func sendHeadAndChunks(of response: StubResponse, from url: URL, to client: any URLProtocolClient) -> Bool {
        guard
            let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: response.status,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )
        else {
            client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return false
        }
        client.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        for chunk in response.chunks {
            client.urlProtocol(self, didLoad: chunk)
        }
        return true
    }

    /// Records the request and takes the host's next response, with the continuation to signal once it's sent.
    private func nextResponse(for host: String) -> (Result<StubResponse, URLError>, AsyncStream<Void>.Continuation?) {
        let recorded = RecordedRequest(request: request, body: Self.body(of: request))
        return Self.hosts.withLock { hosts in
            guard var entry = hosts[host] else { return (.failure(URLError(.cannotFindHost)), nil) }
            entry.requests.append(recorded)
            let response = entry.responses.isEmpty ? nil : entry.responses.removeFirst()
            hosts[host] = entry
            return (response.map { .success($0) } ?? .failure(URLError(.resourceUnavailable)), entry.sent)
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
