package import Foundation

/// Follows a redirect only to the scheme, host and port the request went to, so its credentials never reach another
/// server.
///
/// A redirect elsewhere isn't followed, and the redirect response itself comes back, as a failed request.
package final class SameHostRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    // `@concurrent`, because the compiler crashes building the Objective-C thunk of a `nonisolated(nonsending)`
    // delegate method (Swift 6.4.2).
    @concurrent
    package func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let original = task.originalRequest?.url, let target = request.url else { return nil }
        let isSameHost = original.scheme == target.scheme && original.host() == target.host() && original.port == target.port
        return isSameHost ? request : nil
    }
}
