package import Foundation

/// A canned HTTP response that an ``HTTPStub`` serves.
package struct StubResponse: Sendable {
    /// The HTTP status code.
    package let status: Int

    /// The response headers.
    package let headers: [String: String]

    /// The body, delivered to the client one chunk at a time.
    package let chunks: [Data]

    /// Creates a response that delivers its body in the given chunks.
    ///
    /// - Parameters:
    ///   - status: The HTTP status code.
    ///   - headers: The response headers.
    ///   - chunks: The body, split into the pieces the client receives.
    package init(status: Int = 200, headers: [String: String] = [:], chunks: [Data]) {
        self.status = status
        self.headers = headers
        self.chunks = chunks
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
