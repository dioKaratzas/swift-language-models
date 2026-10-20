package import Foundation

/// A canned HTTP response that an ``HTTPStub`` serves.
package struct StubResponse: Sendable {
    /// How a request ends.
    enum Ending: Sendable {
        /// The body ends after its last chunk.
        case finished

        /// The request fails before any response arrives, as when the host can't be reached.
        case failedBeforeResponse(URLError)

        /// The body stops with an error after its last chunk, as when the connection drops mid-stream.
        case droppedConnection(URLError)

        /// The connection stays open after the last chunk and sends nothing more, so the client waits until it
        /// cancels.
        case openConnection
    }

    /// The HTTP status code.
    package let status: Int

    /// The response headers.
    package let headers: [String: String]

    /// The body, delivered to the client one chunk at a time.
    package let chunks: [Data]

    /// How the request ends.
    let ending: Ending

    /// Creates a response that delivers its body in the given chunks.
    ///
    /// - Parameters:
    ///   - status: The HTTP status code.
    ///   - headers: The response headers.
    ///   - chunks: The body, split into the pieces the client receives.
    package init(status: Int = 200, headers: [String: String] = [:], chunks: [Data]) {
        self.init(status: status, headers: headers, chunks: chunks, ending: .finished)
    }

    private init(status: Int, headers: [String: String], chunks: [Data], ending: Ending) {
        self.status = status
        self.headers = headers
        self.chunks = chunks
        self.ending = ending
    }

    /// A request that fails with an error before any response arrives, as when the host can't be reached.
    ///
    /// - Parameter error: The error the request fails with, such as `URLError(.notConnectedToInternet)`.
    /// - Returns: The response.
    package static func failure(_ error: URLError) -> Self {
        StubResponse(status: 0, headers: [:], chunks: [], ending: .failedBeforeResponse(error))
    }

    /// This response with its body cut off by an error after the last chunk, as when the connection drops mid-stream.
    ///
    /// The chunks and the error reach `URLSession` at once, so it may report the error before the client reads any
    /// chunk.
    ///
    /// - Parameter error: The error the body ends with, such as `URLError(.networkConnectionLost)`.
    /// - Returns: The response.
    package func droppingConnection(with error: URLError) -> Self {
        StubResponse(status: status, headers: headers, chunks: chunks, ending: .droppedConnection(error))
    }

    /// This response with its connection left open after the last chunk, as when a server stops sending, so the client
    /// waits for more until it cancels.
    ///
    /// Give the response a `Content-Type` such as `text/event-stream`, as ``eventStream(_:chunkSize:status:)`` does.
    /// Without one, or with `text/plain`, `URLSession` holds the response back while it guesses the type, so the client
    /// gets nothing.
    ///
    /// - Returns: The response.
    package func keepingConnectionOpen() -> Self {
        StubResponse(status: status, headers: headers, chunks: chunks, ending: .openConnection)
    }

    /// A JSON response delivered in one piece.
    ///
    /// - Parameters:
    ///   - body: The JSON text.
    ///   - status: The HTTP status code.
    ///   - headers: Headers added to `Content-Type: application/json`.
    /// - Returns: The response.
    package static func json(_ body: String, status: Int = 200, headers: [String: String] = [:]) -> Self {
        StubResponse(
            status: status,
            headers: ["Content-Type": "application/json"].merging(headers) { $1 },
            chunks: [Data(body.utf8)]
        )
    }

    /// A server-sent event stream delivered in small chunks, so lines arrive split across reads.
    ///
    /// - Parameters:
    ///   - body: The raw event stream, such as a recorded fixture.
    ///   - chunkSize: The most bytes in one chunk.
    ///   - status: The HTTP status code.
    /// - Returns: The response.
    package static func eventStream(_ body: Data, chunkSize: Int = 16, status: Int = 200) -> Self {
        let chunks = stride(from: 0, to: body.count, by: chunkSize).map { start in
            body.subdata(in: start..<min(start + chunkSize, body.count))
        }
        return StubResponse(status: status, headers: ["Content-Type": "text/event-stream"], chunks: chunks)
    }
}
