package import Foundation

/// Sends a provider's HTTP requests: with the package's `User-Agent`, following redirects only to the same host, and
/// retrying once a status that means a briefly unavailable gateway or host.
///
/// The retry waits the longer of the retry delay and the response's `Retry-After`. A `Retry-After` past
/// ``longestRetryWait`` fails the request at once instead, with the wait on its error, so the app can retry later.
package struct ProviderHTTP: Sendable {
    /// The longest `Retry-After` that the one retry waits for.
    package static let longestRetryWait: Duration = .seconds(10)

    /// The statuses of a briefly unavailable gateway or host, which every provider's requests retry once.
    package static let gatewayStatuses: Set<Int> = [502, 503, 504, 529]

    /// The decoder of every response body and streamed chunk, which requests share, since `JSONDecoder` is
    /// `Sendable`.
    package static let decoder = JSONDecoder()

    private let session: URLSession

    /// The statuses that are retried once, such as 502, 503 and 504.
    private let retryStatuses: Set<Int>

    /// The shortest wait before the one retry.
    private let retryDelay: Duration

    /// The most bytes of a failed response's body to read, which holds its error.
    private let errorBodyLimit = 1 << 20

    package init(session: URLSession, retryStatuses: Set<Int>, retryDelay: Duration) {
        self.session = session
        self.retryStatuses = retryStatuses
        self.retryDelay = retryDelay
    }

    /// A response whose status isn't a success, with the start of its body and the delay it asks to wait.
    package struct Failure: Error {
        /// The HTTP status, or 0 for a response that isn't HTTP.
        package let status: Int
        package let body: Data
        package let response: HTTPURLResponse?

        /// The wait the response's `Retry-After` header asks for.
        package var retryAfter: Duration? {
            Duration(retryAfter: response?.value(forHTTPHeaderField: HTTPHeaderName.retryAfter.rawValue))
        }
    }

    /// A request with the authentication's headers, then the given headers, then the package's `User-Agent` and the
    /// content types, each taking precedence over a header of the same name before it.
    ///
    /// - Parameters:
    ///   - url: Where the request goes.
    ///   - method: The HTTP method, such as `POST`.
    ///   - body: The JSON body, or `nil` for none.
    ///   - accept: The `Accept` header, such as `text/event-stream`.
    ///   - authHeaders: The headers that authenticate the request.
    ///   - headers: The provider's own headers.
    ///   - idleTimeout: How long to wait for the next data, or `nil` for the session's default.
    /// - Returns: The request.
    package static func request(
        url: URL,
        method: String = HTTPMethod.get,
        body: Data? = nil,
        accept: String = MediaType.json,
        authHeaders: [HTTPHeaderName: String],
        headers: [HTTPHeaderName: String] = [:],
        idleTimeout: Duration? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (name, value) in authHeaders.merging(headers, uniquingKeysWith: { $1 }) {
            request.setValue(value, forHTTPHeaderField: name.rawValue)
        }
        if body != nil { request.setValue(MediaType.json, forHTTPHeaderField: HTTPHeaderName.contentType.rawValue) }
        request.setValue(accept, forHTTPHeaderField: HTTPHeaderName.accept.rawValue)
        request.setValue(UserAgent.current, forHTTPHeaderField: HTTPHeaderName.userAgent.rawValue)
        if let idleTimeout { request.timeoutInterval = idleTimeout / .seconds(1) }
        return request
    }

    /// Opens a response stream.
    ///
    /// - Parameters:
    ///   - request: The request.
    ///   - retrying: Called with the status and the wait before the one retry, such as to log them.
    /// - Returns: The stream and its response.
    /// - Throws: ``Failure`` for a status that isn't a success, after the retry; and what a session's request throws,
    ///   with a `URLError` mapped the way a failed connection's is.
    package func stream(_ request: URLRequest, retrying: (Int, Duration) -> Void = { _, _ in }) async throws -> (
        URLSession.AsyncBytes, HTTPURLResponse?
    ) {
        var hasRetried = false
        while true {
            let (bytes, response): (URLSession.AsyncBytes, URLResponse)
            do {
                (bytes, response) = try await session.bytes(for: request, delegate: SameHostRedirects())
            } catch let error as URLError {
                throw error.thrownError
            }
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if (200..<300).contains(status) { return (bytes, http) }
            if !hasRetried, retryStatuses.contains(status), let wait = retryWait(for: http) {
                bytes.task.cancel()
                hasRetried = true
                retrying(status, wait)
                try await Task.sleep(for: wait)
                continue
            }
            let body = try await prefix(of: bytes)
            // A body longer than the limit would otherwise keep downloading.
            bytes.task.cancel()
            throw Failure(status: status, body: body, response: http)
        }
    }

    /// Reads a response's body.
    ///
    /// - Parameters:
    ///   - request: The request.
    ///   - retrying: Called with the status and the wait before the one retry, such as to log them.
    /// - Returns: The body and its response.
    /// - Throws: ``Failure`` for a status that isn't a success, after the retry; and what a session's request throws,
    ///   with a `URLError` mapped the way a failed connection's is.
    package func data(_ request: URLRequest, retrying: (Int, Duration) -> Void = { _, _ in }) async throws -> (Data, HTTPURLResponse?) {
        var hasRetried = false
        while true {
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: request, delegate: SameHostRedirects())
            } catch let error as URLError {
                throw error.thrownError
            }
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if (200..<300).contains(status) { return (data, http) }
            if !hasRetried, retryStatuses.contains(status), let wait = retryWait(for: http) {
                hasRetried = true
                retrying(status, wait)
                try await Task.sleep(for: wait)
                continue
            }
            throw Failure(status: status, body: data.prefix(errorBodyLimit), response: http)
        }
    }

    /// The wait before the one retry of a response: the retry delay, or its `Retry-After` when that's longer, or `nil`
    /// when its `Retry-After` is past ``longestRetryWait``.
    private func retryWait(for response: HTTPURLResponse?) -> Duration? {
        guard let asked = Duration(retryAfter: response?.value(forHTTPHeaderField: HTTPHeaderName.retryAfter.rawValue)) else {
            return retryDelay
        }
        return asked <= Self.longestRetryWait ? Swift.max(asked, retryDelay) : nil
    }

    /// The start of a failed response's body, which holds its error.
    private func prefix(of bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count >= errorBodyLimit { break }
        }
        return data
    }
}
