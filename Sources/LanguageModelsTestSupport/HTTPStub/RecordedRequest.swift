package import Foundation

/// A request that reached an ``HTTPStub``, with its body read out of the request's stream.
package struct RecordedRequest: Sendable {
    /// The request as the stub received it.
    package let request: URLRequest

    /// The request body.
    package let body: Data
}
